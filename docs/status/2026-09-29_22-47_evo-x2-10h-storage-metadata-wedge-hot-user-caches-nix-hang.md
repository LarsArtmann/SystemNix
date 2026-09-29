# 2026-09-29 — evo-x2 10-Hour Storage-Metadata Wedge: System-Hang Diagnosis

**Session window:** 2026-09-29 ~11:38 CEST → 22:47 CEST (with an ~8.5 h gap while the user was away)
**Author:** Crush session (diagnostic only — zero repo/deploy changes made by this session)
**Scope:** Live diagnosis of "nix / the system hangs, but IO, CPU and RAM look fine". No fixes were deployed; the host was still wedged at last check (20:14).
**Current date-time at authoring:** 2026-09-29 22:47 CEST

---

## TL;DR Verdict

The box suffered a **Samsung-TLC btrfs filesystem metadata wedge beginning ~09:58:06**, on the **first boot after `hot-user-caches.nix` changed** (last pre-boot change `0a55103f`, 2026-09-28 23:05). The loudest stuck unit is `hot-user-caches-nix-bootstrap` (its start is the last journal line it ever emitted), which wedged inside a btrfs subvolume operation on the hot disk. One wedged btrfs transaction took down the **entire Samsung filesystem metadata path** (`/mnt/hot` **and** `/nix`), and with it:

- every `nix` command (eval cache lives behind the nested `~/.cache/nix` automount; store access rides `/nix`),
- the **boot transaction** (`multi-user.target` job 191 and `graphical.target` job 190 sat "waiting" for hours),
- **75–82 processes in D-state** (collectors, guard, sev1-bridge, flm, llama-vlm, dms, btop, ~10 foreign nix processes),
- the **entire self-defense stack simultaneously** (memory-emergency-guard, sev1-escalation, every textfile collector, OnFailure cascade) — because they all live on the wedged host.

The user's instinct ("seems to be nix eval related?") was half right: nix is the most visible **victim**, not the cause. The "IO is fine" perception was correct at the disk-activity level (≤21 % busy) — the 83 % IO-PSI was **phantom pressure** from tasks blocked on metadata, not bandwidth.

**Confidence:** HIGH on mechanism and blast radius; MEDIUM on the bootstrap being the *seed* vs. its first *victim* (no kernel stack captured — `hung_task` never fired because these are killable sleeps; see §d). **Still wedged at last probe (20:14): `ls ~/.cache/nix` rc=124 for the 10th hour.**

---

## Evidence Timeline (2026-09-29)

| Time | Event | Source |
|---|---|---|
| 09:56:43–47 | Boot. tmpfiles "mounting anyway" warnings for `~/.cache`, `/mnt/hot`, `~/.cache/nix` (nested automounts all set up) | journalctl |
| 09:56:49 | `BTRFS error (device sda): open_ctree failed: -4` (EINTR) — a btrfs mount attempt on a DAS disk failed at boot; **sda identity this boot unresolved** | journalctl -k |
| 09:57:12–09:58:06 | `pool-usb-recovery` converged pool consumers (atticd, atticd-bootstrap, immich-server, paperless-web, bank-sync, discordsync); DAS SMART counters all zero | journalctl |
| 09:58:05 | `home-lars-.cache-nix.automount: Got automount request for /home/lars/.cache/nix, triggered by 10071 (btop)` — **no mount start/failure line ever follows** | journalctl |
| 09:58:06 | `systemd[1]: Starting Idempotently create the nix cache subvolume on the hot disk...` (`hot-user-caches-nix-bootstrap`) — **terminal journal line of the unit; never completed** | journalctl |
| ~09:58:06–09:59 | D-state wave, all started in the same minute: btop(10071), discordsync-attachments-migrate(10132), hot-user-caches-nix-bootstrap(10158), sev1-bridge(10576), psi-metrics(10711, state D since 09:58:40 with **cpu_ticks=0**, `/proc/10711/stat`), discordsync-io-metrics(11015), display-watchdog(12848), niri-health(12849), gpu-active(15445), nvme-metrics(15749), cadvisor(16609); plus flm(563970), llama-vlm-cap/e4b, dms (`autofs_wait`) | ps + /proc |
| ~10:04 | ~10 nix processes start from **other sessions** — ALL wedge in D: `nix flake check` ×2 (parent = **`crush` pid 42589** = parallel agent session), an orphaned `nh os switch` toplevel build (`/tmp/nh-osUR6DNd`, ppid=1), 5× orphaned `nix build .#checks...css-drift` retries, `nix run nixpkgs#lychee`, `shellcheck`, `nix flake metadata nixpkgs` | ps -o user,ppid,etime |
| 10:32:08 | `usb 3-2: USB disconnect` — **checked: "USB Gaming Keyboard". NOT storage.** | journalctl -k + /sys |
| 11:38 | Session start. Load **80.9**; IO-PSI some avg10 **83.1** / avg60 **81.9**, full avg10 **77.5**; CPU-PSI ≈ 0; mem-PSI ≈ 0. Disk busy over 3 s: nvme1n1p2 (QLC root) **1.3 %**, nvme0n1p6 (Samsung /nix) **21 %**, DAS **0 %** | /proc/pressure, /proc/diskstats |
| 11:38 | `ls ~/.cache/nix` → **timeout rc=124 (unkillable D)**; every other mount (buildcache, hot, pool, data, cache, btrfs-root, nix) answers rc=0 | findmnt + timed probes |
| 11:40 | `busctl … ListJobs`: 60+ jobs; **multi-user.target (job 191) + graphical.target (job 190) "waiting" 1 h 45 m post-boot**; boot-transaction jobs pending: forgejo-generate-token(447), forgejo-ssh-keys(446), clickhouse(453), twenty-fix-collation(487), signoz*(457–460), pool-usb-recovery(866, running since boot), home-lars-.cache-nix.mount(36894, waiting), fastflowlm@54/55/56 connection instances queued | busctl |
| 11:40 | `/var/lib/node_exporter` **does not exist at all** (mktemp ENOENT); root-fs write (`/var/tmp`) rc=0; `sync` rc=0; `/run/binfmt` EXISTS (tmpfiles mostly ran — this is a *different* gap than 2026-09-24's cycle-breaker; **zero "ordering cycle" lines this boot**) | probes |
| 11:41 | `hung_task_panic=1`, `hung_task_timeout_secs=120` — armed, yet **no panic and zero hung-task warnings across 10 h** (consistent with TASK_KILLABLE exemption from hung-task checks) | /proc/sys |
| 20:14 | Re-sample: load **86.8**, **82 D-state**, IO-PSI 83 %, `ls ~/.cache/nix` **still rc=124**, `/var/lib/node_exporter` **still missing**, job queue drained to 1 waiting/running (units timed out over the day — the wedge itself persists) | probes |
| 22:47 | Authoring time. No further probes taken; box presumed unchanged. | date |

**Module history (git):** `hot-user-caches.nix` last changed **2026-09-28 23:05** (`0a55103f`, +1/−1) → the 09:56 boot was **the first boot carrying it**. A **parallel session changed it again mid-incident** (477f9c8f, today 13:22, **+40/−1**) — not authored or reviewed by this session (concurrent-session doctrine: flagged, not touched). The auto-commit daemon kept committing during the wedge (git is local; root-fs ops were fine) — 13:22 and 20:18 commits landed.

---

## a) FULLY DONE

*(verifiable, with evidence)*

| # | Item | Evidence |
|---|---|---|
| 1 | **Hang mechanism + blast radius diagnosed** — Samsung btrfs metadata wedge from ~09:58:06; not CPU/RAM/bandwidth (CPU-PSI 0.04 avg60, mem-PSI 0.00, disks ≤21 % busy) | timeline above; probes reproducible |
| 2 | **Nix hang pinned to a concrete path** — `ls ~/.cache/nix` times out (rc=124), twice, 8.5 h apart; the nested autofs (`systemd-1`, untriggered) is owned by `hot-user-caches.nix:76-77`; every stuck nix process is D-state | timed probes + findmnt |
| 3 | **10 h nix pileup attributed to foreign sessions, not this one** — 2× `flake check` parented by `crush` (pid 42589); orphaned `nh os switch` deploy attempt; 5× orphaned css-drift builds; lychee/shellcheck/metadata runs | ps -o user,ppid,etime,args |
| 4 | **DAS/pool hardware exonerated** — all 3 disks on usb8-1, pool subtrees answer, SMART error counters zero at 09:57:12; the 10:32 USB disconnect was the keyboard | journalctl + /sys |
| 5 | **Boot-transaction stall proven** — multi-user/graphical targets "waiting" for hours behind 60+ jobs (busctl, job IDs captured) | busctl ListJobs |
| 6 | **Monitoring-plane blackout discovered** — `/var/lib/node_exporter` missing entirely; psi/system-health/pool/niri/gpu/nvme collectors, memory-emergency-guard, sev1-bridge all D-stuck → no Zone-6 trip, no sev1 page, nothing in Discord from the guard path | probes + ps + job list |
| 7 | **hung_task defense proven inert for this class** — armed (panic=1, 120 s) yet silent for 10 h; killable-sleep exemption is the leading explanation (unverified kernel-side) | /proc/sys/kernel/hung_task_* |
| 8 | **First-boot linkage established** — module changed 23:05 the night before the boot; wedge began 2 min into first boot of the new shape | git log |

## b) PARTIALLY DONE

| # | Item | Works / remains open | Blocker | Effort |
|---|---|---|---|---|
| 1 | **Root-cause pinning** | Narrowed to Samsung btrfs metadata wedge seeded at/coincident with the bootstrap's first op | No kernel stack captured (needs `sysrq-t`/`w` or `/proc/<pid>/stack` as root — **only available pre-reboot**); bootstrap seed-vs-victim unresolved; why non-Samsung units (psi-metrics) wedged is unexplained | Root access; S once stacks captured |
| 2 | **`XDG_CACHE_HOME=/tmp/...` bypass for nix** | Proposed as user-facing workaround | Verification attempt itself hung (probe `timeout` lacked `-k`, D-state child ignored TERM; background shell dangled 8 h, killed 20:20) — **bypass UNVERIFIED**; may be moot if `/nix` itself is wedged | S (retry post-wedge-clear) |
| 3 | **Recovery plan** | Drafted: (optional) stop bootstrap → record boot identity → sysrq stack dump → reboot → verify | All root/systemctl actions are blocked in my sandbox — user must execute | S |
| 4 | **`open_ctree failed: -4` on sda (09:56:49)** | Observed + timestamped | Which filesystem sda carried this boot and which unit attempted the mount — unresolved | S/M |
| 5 | **`/var/lib/node_exporter` gap** | Existence failure proven (ENOENT); different class than the 2026-09-24 cycle-breaker (no ordering-cycle lines) | Owning tmpfiles rule + why it skipped this boot unknown | S |

## c) NOT STARTED

*(planned, zero work done — waiting on owner/reboot)*

1. **Runtime recovery** (reboot + post-boot verification) — user-gated, root-only.
2. **hot-user-caches fix** — harden (bounded timeout, fail-open, off the boot-critical path) or disable on evo-x2. Owner decision pending (see §g).
3. **AGENTS.md memory updates** for this incident's lessons (phantom-IO-PSI signature, busctl-not-systemctl, killable-sleep hung_task gap, first-boot linkage).
4. **TODO_LIST / domain-file harvest** of §f — **deliberately deferred** per the owner's explicit "write the report, then wait" instruction (docs-health HARVEST to run on go-ahead).
5. **Hang-forensics runbook/script** (`scripts/hang-forensics.sh`) so the next hang starts with a stack capture instead of ending with one.
6. **VM/regression coverage** for "bootstrap hangs ⇒ boot transaction must not stall".
7. **Gatus/Discord audit** — did ANY alert path fire during 09:58→20:14? Never checked.
8. **Boot-identity check** — which generation/snapshot is actually running (reboot-revert class unchecked).

## d) TOTALLY FUCKED UP

1. **The host itself.** 10+ hours wedged (verified unchanged at 20:14; still true at authoring). Severity: **total on the primary dev box** — no builds, no `flake check`, no deploys, nix unusable; every parallel session's local CI-equivalent work stalled (the 10 h nix pileup IS that evidence). Root cause: Samsung btrfs metadata wedge (mechanism high-confidence, kernel-level proof pending). Mitigation: none except reboot — D-state processes are unkillable.
2. **The entire self-defense stack went blind simultaneously.** memory-emergency-guard (no Zone 6), sev1-escalation (no desktop page), every textfile collector, the OnFailure→Discord cascade, and the monitoring textfile directory itself — all dead from one wedge. **The user found a 10-hour total hang by hand.** The layers were designed for "system is wedged" and all of them live *on* the wedged system. Root cause: architectural — observability shares fate with the thing it observes. Mitigation: §e/§f items (out-of-band detection).
3. **`hung_task_panic=1` did not defend.** Armed at 120 s with panic enabled, silent for 10 h. Leading explanation: these are TASK_KILLABLE sleeps, which the hung-task detector exempts — unverified. Consequence: the documented "a 120 s+ D-state will panic the box" assumption is **false for this class**.
4. **Retry storm with no single-flight gate.** Five orphaned duplicate `css-drift` builds (ppid=1) plus an orphaned `nh os switch` deploy attempt from ~10:04 whose *intent is unknown* — there may be an **owed deploy** nobody has accounted for.
5. **A parallel session edited `hot-user-caches.nix` (+40/−1) mid-incident** (477f9c8f, 13:22) and a 1-line change landed the night before (0a55103f, 23:05) — neither reviewed by this session, so the exact unit shape that booted at 09:56 is not pinned. Attribute-before-touch doctrine was honored (nothing reverted), but the change content is unexamined.
6. **My own probe hygiene.** Launched a verification probe with TERM-only `timeout` against a D-state child → the background shell dangled for ~8 h until the user returned; killed on return. Cost: noise, and the bypass answer stayed unknown for 8 h.

## e) WHAT WE SHOULD IMPROVE

**What I forgot (session-level):**
- **Kernel stack capture FIRST.** `sysrq-t`/`sysrq-w` (or `sudo cat /proc/<pid>/stack`) within the first minutes would have named the exact blocked kernel path and turned a 10 h mystery into a 10-minute diagnosis. I reached for it conceptually only near the end — and it is still available pre-reboot (§f item 1).
- **Gatus/Discord audit** — I never checked whether the one alerting path that might survive a local wedge (Gatus → Discord) actually fired.
- **Boot-identity check** (`readlink /run/booted-system` vs profile) — the reboot-revert class is standard doctrine here and I skipped it.
- **`timeout -k` for anything that might enter D-state**, and not leaving a probe dangling.
- **Bounding the `/var/lib` gap** — one `ls /var/lib` would have shown whether anything else vanished.
- **Memory doctrine** — lessons should have gone to AGENTS.md at discovery; deferred per the wait instruction, tracked in §f.

**What I did wrong:**
- First diskstats delta used `paste`+`awk` with misaligned fields → displayed impossible numbers (io_ticks delta ≫ wall-clock). Caught and corrected next batch — but I should have unit-sanity-checked before showing.
- One kernel-log probe was an unfiltered `tail -40` → returned pure docker-veth noise; wasted a batch.
- Two probe batches partially dead-ended (`systemctl` sandbox-banned; `/proc/<pid>/stack`/`syscall` unreadable) before I reached the tools that actually worked (busctl, per-unit journal, timed path probes). The working toolkit should have been first.
- I framed the bypass as promising **before** verifying it, then left the verification dangling.
- The git-log check that established the first-boot linkage — the single strongest causal fact — was done only at report time, not during diagnosis.

**What we should improve (system/design):**
- **Boot-critical-path containment:** any bootstrap/oneshot that can wedge (btrfs ops on a hot-tier disk) must carry an explicit `TimeoutStartSec`, fail OPEN, and never be required for `multi-user.target`. A cache-relocation nicety held an entire boot transaction hostage for 10 h.
- **Out-of-band detection:** at least one hang detector whose alert path does not share the wedge's filesystem (Gatus-side absence alerting on a textfile that stops updating — and verification that this path actually fires; plus research into a boot-timeout watchdog that reaches Discord directly).
- **Killable-sleep monitoring:** a userspace D-state-count watchdog with a remote-verifiable signal, since `hung_task` provably does not cover this class here.
- **Single-flight for heavy checks** (existing `heavy-job`) so 5 duplicate orphaned builds can't pile up.
- **Codified hang runbook:** load ~80 + CPU/mem-PSI ~0 + IO-PSI high + disks idle ⇒ metadata wedge; step 1 `busctl ListJobs`, step 2 D-census, step 3 automount-trigger journal lines, step 4 **stack capture** — before any theorizing.
- **Nested-automount policy:** `~/.cache/nix` is an autofs nested inside the `~/.cache` autofs, backed by the same Samsung fs as `/nix` — two fragile couplings (nix's eval cache + hot tier) in one mount chain. Revisit placement (§f 26).

## f) Top 50 things we should get done next

*(ranked by impact; Critical/High/Medium/Low · S <30 min / M 30 min–2 h / L >2 h · Category)*

### P0 — before/with the reboot

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 1 | **Capture kernel stacks pre-reboot:** `sudo sh -c 'echo t > /proc/sysrq-trigger; echo w > /proc/sysrq-trigger'`, then read `journalctl -k` — names the exact blocked path for every D task; lost forever after reboot | Critical | S | Forensics |
| 2 | Optional cheap experiment first: `sudo systemctl stop hot-user-caches-nix-bootstrap.service`, watch `multi-user.target` 5 min — may unjam the boot without reboot | High | S | Triage |
| 3 | Record boot identity: `readlink /run/booted-system /nix/var/nix/profiles/system` (reboot-revert / snapshot-boot check) | High | S | Triage |
| 4 | Reboot the host (owner decision, see §g) | Critical | S | Recovery |
| 5 | Post-boot verify: `timeout 3 ls ~/.cache/nix`, `ls /var/lib/node_exporter/textfile_collector`, load < 5, D-count < 5, quick `nix eval` | Critical | S | Recovery |
| 6 | Read the sysrq stack dump from the journal → name the exact wedge (btrfs transaction? subvol lookup? autofs?) → file the root cause | Critical | S | Forensics |
| 7 | Verify monitoring recovery: textfile .prom mtimes fresh, `node_textfile_scrape_error 0`, Gatus green, guard/sev1 alive | Critical | S | Recovery |
| 8 | New-boot journal sweep: did `hot-user-caches-nix-bootstrap` start AND finish? If it hangs again → disable `services.hot-user-caches` immediately | Critical | S | Triage |
| 9 | Identify the 10:04 `nh os switch` intent (`/tmp/nh-osUR6DNd`) and whether a deploy is owed post-reboot | High | S | Triage |
| 10 | Determine sda identity this boot (`lsblk -o NAME,MODEL,SERIAL /dev/sda`) + which unit attempted btrfs mount → explain `open_ctree -4` | Medium | S | Forensics |

### P1 — repo fixes (post-reboot, then deploy)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 11 | Harden `hot-user-caches` bootstrap: explicit `TimeoutStartSec`, bounded btrfs op, fail-open + loud journal on failure | Critical | M | Bug |
| 12 | Move the bootstrap off the boot-critical path: its failure must never hold `multi-user.target`; automount degrades to "cache stays on root fs" | Critical | M | Feature |
| 13 | Owner decision + implement: harden-and-keep vs disable `services.hot-user-caches` on evo-x2 (see §g) | Critical | S | Decision |
| 14 | Fix `/var/lib/node_exporter` creation: find owning tmpfiles rule, why it skipped this boot, make unconditional + eval-time assertion tying textfile writers to an existing dir rule | High | M | Bug |
| 15 | Post-deploy gate: assert textfile dir exists + `node_textfile_scrape_error 0` after every switch | High | S | Quality |
| 16 | With post-reboot stacks: explain why psi-metrics/sev1-bridge/guard (non-Samsung units) wedged; fix the shared dependency | High | M | Forensics |
| 17 | Audit Gatus during the wedge (did "monitoring stale"/scrape-error checks reach Discord?) and fix any silent path | High | M | Quality |
| 18 | Document killable-sleep `hung_task` exemption; add a D-state-count watchdog whose alert survives a local fs wedge | High | M | Feature |
| 19 | Write `scripts/hang-forensics.sh` (sysrq capture instructions, D census, busctl ListJobs, PSI, disk busy) — the runbook this session lacked | High | S | Documentation |
| 20 | Codify the diagnostic order in AGENTS.md (the §e runbook signature) | High | S | Documentation |
| 21 | Re-review `hot-user-caches.nix` ordering vs the 2026-09-25 cycle-breaker fix; VM-assert tmpfiles-setup runs | High | M | Quality |
| 22 | VM regression test: bootstrap hanging must NOT stall the boot transaction nor D-hang the nix CLI | High | L | Quality |
| 23 | Research `x-systemd.mount-timeout=` (and automount timeout semantics) so a wedged backing fs fails fast instead of D-hanging forever | Medium | M | Feature |
| 24 | Samsung health audit: nvme0 SMART + kernel nvme0 errors this boot — was the device stalling (bootstrap = victim not seed)? | High | S | Forensics |
| 25 | Audit ALL nested automounts (`findmnt \| grep autofs`), document topology + failure modes; add gotcha against nesting automounts | Medium | S | Documentation |
| 26 | nix eval-cache placement decision: drop the `nix` entry from `hot-user-caches.caches` default (back to `@cache-home`) or XDG-relocate with verification | High | S | Decision |
| 27 | Single-flight wrapper for heavy checks (`heavy-job`) so orphaned duplicate builds can't pile up | Medium | M | Quality |
| 28 | system-health: detect + report orphaned (ppid=1) duplicate nix builds (report, not auto-kill) | Low | S | Feature |
| 29 | Review the two unexamined module changes (`0a55103f` +1/−1, `477f9c8f` +40/−1) — what did the parallel session change mid-incident? | High | S | Review |
| 30 | AGENTS.md hot-user-caches section: this incident (10 h wedge, first-boot linkage, killable-sleep gap, phantom-IO-PSI signature) | High | S | Documentation |
| 31 | Gotchas archive: "phantom IO-PSI from metadata wedge" telemetry signature (load 80, cpu/mem PSI 0, disks idle) | Medium | S | Documentation |
| 32 | Record `busctl` as the sandbox-safe systemctl alternative for diagnosis (memory + AGENTS) | Medium | S | Documentation |
| 33 | Post-reboot: did discordsync-db-heal / crush-hot-db-migrate run 09:57–09:58 (freeze-6 crash-recovery readers) and interact with the wedge? | Medium | S | Forensics |
| 34 | Post-reboot: verify flm/llama-vlm recover (flm D-corpse 563970 + queued @54/55/56 instances die with reboot); watch EADDRINUSE corpse class | Medium | S | Triage |
| 35 | Verify the user's desktop recovered (dms sat in `autofs_wait` — the user's own shell was affected) | Medium | S | Triage |
| 36 | Architecture review: should `multi-user.target` ever wait hours on optional oneshots? Re-classify collectors out of the boot-critical chain (After= only) | Medium | M | Architecture |
| 37 | Extend `systemd-shape-audit`: any oneshot ordered before a target must carry explicit `TimeoutStartSec` | Medium | M | Quality |
| 38 | tmpfiles completeness gate: post-boot check for known-critical artifacts (`/run/binfmt`, `/run/systemnix/sev1`, textfile dir) | Medium | S | Quality |
| 39 | Explain the one-minute D-wave across non-Samsung units (09:58:06–09:59) — shared dependency (mnt-hot.mount? transaction ordering?) via post-reboot stacks | High | M | Forensics |
| 40 | Root-cause the node_exporter dir gap specifically — this boot had NO ordering-cycle lines, so it is a different failure mode than 2026-09-24 | High | S | Forensics |
| 41 | Research nix upstream support for daemon-side eval-cache placement (XDG relocation is user-side only) | Low | M | Research |
| 42 | Harvest §f into TODO_LIST.md + `docs/todo/{stability,monitoring}.md` on owner go-ahead (deliberately deferred today) | High | S | Process |
| 43 | Add sysrq-w/t capture step to the freeze/hang runbooks (capture BEFORE reboot — doctrine) | High | S | Documentation |
| 44 | Research a boot-timeout watchdog: if multi-user.target unreached after N min → out-of-band alert independent of the stuck chain | Medium | M | Feature |
| 45 | Post-reboot: coordinate parallel sessions to re-run their stalled work (css-drift/docs-drift checks, the deploy) without a repeat pileup | Medium | S | Process |
| 46 | AGENTS.md: sandboxed sessions cannot systemctl/sudo — diagnosis uses busctl/journalctl/procfs; root actions are handed to the user as exact commands (today's working pattern) | Low | S | Documentation |
| 47 | Post-reboot: re-verify pool-recovery convergence (atticd/immich/paperless/bank-sync/discordsync healthy) | Medium | S | Triage |
| 48 | DAS runbook: note "keyboard USB disconnect ≠ storage event" (usb 3-2 = keyboard, verified today) | Low | S | Documentation |
| 49 | After un-wedge: `systemctl start home-lars-.cache-nix.mount` once to confirm the subvol mounts at all — if broken, `btrfs` check the Samsung `users/lars/cache/nix` subvol | High | S | Triage |
| 50 | Consider a "wedge-active" marker convention so parallel sessions don't hot-path-edit a suspect module mid-incident (the 13:22 edit went unflagged for hours) | Low | M | Process |

## g) Questions I cannot answer myself

1. **Reboot authorization + timing.** The only recovery path I can see is a controlled reboot (D-states are unkillable; the wedge has held 10+ h). Do you want to (a) first run item #1 (sysrq stack capture) and optionally #2 (stop the bootstrap, give it 5 min), or (b) reboot immediately? I can't execute root/systemctl actions from this sandbox — this is your call, and the sysrq capture is lost forever after reboot.
2. **The 10:04 deploy attempt.** An `nh os switch` (out-link `/tmp/nh-osUR6DNd`) started ~10:04 and has been wedged since — whose session was it (yours or an agent's), and was there an intended change that we must re-run after recovery? Attribution of a foreign session's *intent* is not recoverable from the box; a profile-anchor check after reboot will tell us *what* landed but not *what was meant to*.
3. **`hot-user-caches` disposition.** Harden-and-keep (bounded timeout + fail-open + off the boot-critical path) or disable on evo-x2 until root-caused? This trades the Samsung hot-tier benefit (QLC write-amplification relief) against a demonstrated boot-wedge risk on a freeze-prone box, and gates items #11–#13/#26 — only you can weigh it.

---

## Harvest Note (docs-health doctrine)

Per AGENTS.md, status reports must self-harvest their §f follow-ups into `TODO_LIST.md` + the matching domain library at authoring time. **This report deliberately defers the harvest**: the owner's instruction for this session was "write the report, then WAIT FOR INSTRUCTIONS". Item #42 tracks the harvest; run docs-health → HARVEST on go-ahead.
