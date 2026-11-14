# Status: buildflow fleet-toolchain declarative install — blocked by a boot-metrics livelock + I/O storm

**2026-11-14 12:08 CET · session scope: buildflow triple-install diagnosis → declarative base.nix install → deploy gate forensics**

**Verified this session (command/artifact cited):** all three buildflow copies' versions (`buildflow version` ×3); PATH resolution order (`which -a`); all 6 tool attrs + versions in the LOCKED nixpkgs (single `nix eval …getFlake` JSON); base.nix diff (treefmt clean, exactly +10 lines, only my file); both toplevels eval green (`nix eval …drvPath` → `ggpyq15m…` evo-x2 / `260ppyk…` darwin); gen-1006 anchor equality (`readlink` = `xfbd8lvr…` both sides); the parallel deploy's failure legs (tail of `/var/log/systemnix-deploys/2026-11-14_11-43-00.log`); the livelock (`busctl ListJobs` + `journalctl -u 'boot-metrics*'`); fuzz-swarm self-exit (`pgrep -fc` = 0); textfile state (`boot-metrics.prom` exists, ZERO phase lines).

**NOT verified / not attempted:** no deploy executed (blocked, see §b); post-deploy state of the 6 tools on PATH; whether boot_phase_duration_seconds EVER exists in the TSDB all-time (`metric-exists.sh` only runs inside the watcher); who owns the 12:05 fuzz swarm and the 11:43 parallel deploy session (processes gone/unattributed); the `M AGENTS.md` tree change present at session start (not mine, not investigated); none of §f's ROADMAP items.

---

## Session arc

1. User pasted `whereis buildflow` → three copies at three versions. Diagnosed: `~/.local/bin/buildflow` = stray `dev (commit unknown)` (built 02:56 today, 95 MB, from the webphone session); user nix profile (`pnvglq…-profile`) = `7e4ca72`; system path (`zz4496…-system-path` → `/run/current-system/sw`) = `32f3f56`. PATH resolves the stray first → typed `buildflow` runs the `dev` binary. Exact recurrence of the 2026-09-22 shadowing incident (`docs/agents/shell-devtools.md:35`).
2. User: "Should we install something permanently via nix on evo-x2??" (profile list: cue, dprint, gci, ruff, tailwindcss_4, typos on **4 different nixpkgs lock revs**). Answered: yes, but declaratively in the flake. Decisive evidence: BuildFlow resolves tools from PATH first and only falls back to per-call `nix run nixpkgs#<pkg>` (`~/projects/buildflow/tools/providers/nix_resolver.go` — incl. the `tailwindcss → tailwindcss_4` override map), so PATH-resident declarative copies kill the per-invocation nix-eval latency; and the imperative profile violates the empty-profile doctrine.
3. User: "Find the right place to add them!" → `platforms/common/packages/base.nix` `developmentPackages`, grouped by the file's existing sections: `tailwindcss_4` under JS/TS, `gci` under Go (next to gofumpt), and `cue`/`dprint`/`ruff`/`typos` as a commented "BuildFlow fleet toolchain" block under Code quality. All 6 verified present in the locked nixpkgs (cue 0.17.1, dprint 0.64.3, gci 0.14.0, ruff **0.17.4** — profile stale at 0.17.3, tailwindcss_4 **4.3.4** — profile stale at 4.3.3, typos 1.51.1; `tailwindcss` unprefixed is 3.4.17, which is exactly why the `_4` attr matters). Trashed the stray `~/go/bin/cue` (doctrine).
4. Verification: `nix fmt -- <file>` clean (10 insertions, zero churn elsewhere); **both** toplevels eval green (base.nix feeds evo-x2 AND Lars-MacBook-Air via `platforms/{nixos/system/configuration.nix:42, darwin/default.nix:19}`).
5. `nix run .#deploy` → **flock-refused**: a parallel session's deploy had been running since 11:43. Watched it: **it FAILED pre-deploy at 11:59:26 (986 s)** on three gate legs — all box-state, none config: (a) zram fill 97.6 % + PSI some 8.92 % (pre-freeze zone), (b) I/O PSI 32.77 % + disk busy 101.4 % (storm), (c) **phantom metric `boot_phase_duration_seconds` ABSENT** from the TSDB.
6. Gen-1006 mystery solved: an EARLIER deploy (pre-edit tree) had already landed and is properly anchored (`current-system` = `system-1006-link` = `xfbd8lvr…`). My tools are NOT on the box.
7. Phantom metric root cause (the interesting one): **boot-metrics-emit is in a self-hold livelock.** The boot's startup transaction has been open 90–94+ min past graphical; `journalctl` shows the collector retrying "boot unfinished (attempt n/12)" every 2 min; `busctl ListJobs` names **its own pending start job (1718846) as the ONLY pending job in the whole systemd manager**. The collector's own running start job is what keeps "boot unfinished" true — it is waiting on a condition it is itself holding open. It self-heals by design budget: retries exhaust ~12:24, the transaction closes, the ~12:30 re-fire (OnUnitActiveSec 30 min) finally emits the phases.
8. 12:05 flare: a `httputil.test -test.fuzzworker` swarm (parallel session's Go fuzzing) pushed load to **1095** (1511 processes); by 12:07 it had self-exited (pgrep 0). Load-1095 was mostly D-state I/O backlog — the io storm (PSI avg300 ≈ 49 %) predates it.
9. Placed watcher `01A` (background): fires when io PSI avg10 < 20 % AND `boot_phase_duration_seconds{` appears in `boot-metrics.prom` AND `scripts/metric-exists.sh boot_phase_duration_seconds` exits 0 — then I deploy, then profile cleanup.

## a) FULLY DONE

| Item | Evidence |
|---|---|
| buildflow triple-install diagnosis + which copy wins | `which -a`, 3× `buildflow version` |
| Declarative home chosen per doctrine (`base.nix`, not `nix profile`) | `docs/agents/shell-devtools.md:35` + file structure survey |
| 6 tools added to `base.nix`, grouped, commented with versions + provenance | git diff: +10 lines, 3 insertion points |
| Both hosts eval-green on the change | `nix eval …toplevel.drvPath` ×2 |
| Locked-nixpkgs attr + version verification (incl. staleness proof for the profile copies) | single `nix eval` JSON |
| `~/go/bin/cue` stray trashed | `ls ~/go/bin | grep -c cue` → 0 |
| Parallel deploy's failure root-caused (3 gate legs, box-state) | `…/2026-11-14_11-43-00.log` lines 4-5, 133 |
| gen-1006 anchor verified (no UNANCHORED exposure) | readlink equality check |
| Liveloock root-caused with the sanctioned probe | `busctl ListJobs` (one job: itself) |
| Fuzz swarm identified, NOT killed, confirmed self-exited | `pgrep -fc httputil.test` → 0 |

## b) PARTIALLY DONE

1. **The actual install** — declared, eval-green, in-tree; NOT on evo-x2 (deploy blocked on gate legs, watcher 01A waiting). macOS parity likewise eval-green only.
2. **Profile cleanup** — `nix profile remove cue dprint gci ruff tailwindcss_4 typos` correctly sequenced AFTER the deploy; not executed.
3. **`~/.local/bin/buildflow` stray** — diagnosed (shadows the pinned `32f3f56`), NOT trashed; doctrine fix offered but overtaken by the declarative plan.
4. **boot-metrics livelock** — root-caused; not fixed, not filed.
5. **Prom tmp-orphan cleanup** — ~60 orphan `*.prom.<tmp>` / `*.prom.tmp.*` files observed in `/var/lib/prometheus-node-exporter/textfile_collectors/` (vm-top ×16, psi ×7, crowdsec ×12, memory-emergency-guard ×8…); not cleaned, no guard exists.
6. **Doc updates** (shell-devtools doctrine row, CHANGELOG) — pending the deploy landing.

## c) NOT STARTED

- Post-deploy verification battery (which -a ×6, versions, buildflow resolution order, `buildflow doctor` binary-freshness).
- macOS deploy of the same change.
- I/O-storm source attribution (the 11:2x–12:0x storm predates the fuzz; per-cgroup `io.pressure` forensics not run).
- The 94-min-open transaction: confirming FinishTimestamp actually sets after ~12:24 (my self-heal theory is inference from systemd semantics + the module's documented convergence path, not yet observed).
- `docs/gotchas-archive.md` narrative for today's storm (freeze-#53 precursor class?).

## d) TOTALLY FUCKED UP (incl. "what did you forget")

Nothing in the tree is broken by me — but the honest list of my own failures:

1. **Forgot the session-start parallel-session pre-reads.** Doctrine (AGENTS.md, 2026-10-23) demands `rg -il <topic> docs/status/` + `ls -t docs/status/ | head` + a live-session probe BEFORE working. I did none: four yolo crush sessions were live the entire time and one was mid-deploy — I discovered all of this only via the flock refusal. A 10-second `pgrep -af 'nh os'` at session start would have changed my sequencing completely.
2. **Fired the deploy without an immediate pre-flight quiescence probe.** My nh/switch pgrep ran ~15 min before the deploy attempt; the parallel session's deploy started in between. The flock guard saved me, but the check order was wrong.
3. **Ran two heavyweight toplevel evals during an active I/O storm** (io PSI avg300 ≈ 49 %, disk busy 101 %). Necessary verifications, wrong moment — exactly the load the 2026-10-25 heat-check discipline exists to schedule around.
4. **The `rg -rn ""` hook trip.** I shipped a command containing the exact third-strike trap the repo has a named rule and a BLOCKING hook for (2026-10-23). Zero excuse — the rule is in AGENTS.md verbatim.
5. **Deploy-log conflation:** my first `ls -t | head -1` + tail read mixed two log files' signals and I briefly mis-narrated who deployed gen-1006; took a second round to untangle (capture-once-then-grep would have avoided it).
6. **Inconsistent stray application:** the diagnosis found THREE buildflow copies; I trashed one stray (`~/go/bin/cue`) and left the OTHER stray (`~/.local/bin/buildflow`) untouched — the original trigger of this whole session still shadows the pinned binary.
7. **Box-state blindness:** I sequenced a system-changing task on a box that was 40 min out of a zram-97.6 % pre-freeze brush, without reading PSI first. The gate caught everything — but the gate shouldn't have been the discovery mechanism.

Box-level fucked-up observed (not caused by me, flagged): boot transaction open 94+ min (livelock), load-1095 event, zram 97.6 %, ~60 prom tmp orphans. All queued in §f.

## e) WHAT WE SHOULD IMPROVE

1. **Codify the pre-deploy pre-flight** (pgrep `nh os|switch-to-configuration` + flock-holder scan + PSI probe) as a tiny script or deploy.sh preamble — the 2026-10-25 heat-check exists as prose; this session proves it isn't muscle memory for agents.
2. **Session-start probe ritual**: extend the existing doctrine with the flock-holder check (`/tmp/.systemnix-deploy.lock` + `/proc` fd scan) — it names the blocking session instantly.
3. **Pair stray-trash with ALL strays found**: one diagnosis, N copies → N decisions in the same session.
4. **boot-metrics design fix**: the emitter must never be a member of the transaction it waits on (trigger via a plain timer that starts post-`multi-user.target`, or gate its retry loop on a condition excluding its own job). Also audit other OnBootSec oneshots for the same class.
5. **Deploy-log self-identification**: each log should name its own attempt (the ls -t + tail conflation class).
6. **Gate attribution hint**: pre-deploy-check's zram/PSI legs should hint "expected during concurrent deploys/builds" — today's blocker text didn't point at the obvious cause (the other deploy's own flake check).
7. **Prom tmp janitor**: tmpfiles rule or collector-side trap cleanup for `*.prom.*` orphans in the sticky dir.
8. **PSI-probe before heavyweight evals** as a personal rule: one `cat /proc/pressure/io` before any multi-minute eval during business hours on this box.

## f) Up to 50 things to get done next (brainstorm; ROADMAP fuel marked)

*Session-direct:*

1. Deploy base.nix fleet-toolchain to evo-x2 once watcher-01A conditions pass (PSI < 20 % + phases emitted + metric in TSDB).
2. Post-deploy: `nix profile remove cue dprint gci ruff tailwindcss_4 typos` → verify profile empty (doctrine restored).
3. Trash `~/.local/bin/buildflow` (restore pinned `32f3f56` as the resolved binary) — owner policy call, §g.3.
4. Fix boot-metrics.nix self-hold (transaction-independent emission design).
5. Verify the self-heal: after ~12:30, confirm phases in `boot-metrics.prom` + TSDB + the Gatus boot check goes green.
6. macOS deploy for fleet parity.
7. CHANGELOG entry for the base.nix addition.
8. Update the shell-devtools.md:35 doctrine row (fleet toolchain now declarative; profile empty again post-cleanup).
9. `buildflow doctor` binary-freshness green after the system copy lands.
10. Notify/attribute the parallel deploy session — its 11:43 attempt died on box-state; it may retry blind into my deploy (flock protects, but churn).

*Box-state observed:*

11. Confirm the boot transaction actually closes ~12:24 (FinishTimestamp sets) — if not, escalate to the stability runbook.
12. Attribute the 11:2x–12:0x I/O storm (per-cgroup io.pressure; predates the fuzz swarm).
13. zram 97.6 % pre-freeze brush — stability row; freeze-#53 risk assessment.
14. Load-1095 event evidence capture (PSI/load/timestamps) per freeze-forensics convention.
15. Purge ~60 prom tmp orphans in the textfile_collectors sticky dir.
16. tmpfiles/janitor guard so orphans can't re-accumulate (worst: crowdsec-counts ×12, vm-top ×16).
17. Gatus "boot userspace > 180s" check: verify it flips green after the first good emission (it was designed to stay red until a good boot).
18. `metric-exists.sh boot_phase_duration_seconds` all-time sweep — did ANY past boot ever emit, or is this its first real boot and the livelock is brand-new?
19. Post-storm pre-deploy battery re-run evidence → appendix to this report.
20. Unattributed `M AGENTS.md` in the tree at session start — identify owner (daemon/parallel session), verify intent.

*Doctrine/process:*

21. Pre-deploy pre-flight script (see §e.1).
22. Session-start ritual incl. lock-holder scan (§e.2).
23. pre-deploy-check.sh: attribution hints on the zram/PSI legs (§e.6).
24. Deploy-log self-identification (§e.5).
25. Prom tmp janitor unit (§e.7).
26. Audit other OnBootSec oneshots for the self-hold class.
27. PSI-before-eval personal rule → candidate for AGENTS.md session discipline.
28. Verify the daemon attributed the base.nix commit correctly (pathspec/daemon-race hygiene).
29. Add `httputil.test`-style fuzz etiquette: nice/ionice or GOMAXPROCS cap when a deploy window is plausible.
30. Flock-holder UX in deploy.sh: print holder age + tty for faster owner contact.

*Fleet/tools:*

31. `~/go/bin` re-accumulated strays audit (golangci-lint, actionlint, art-dupl, cmdguard-lint, cqrs-lint, govalid, go-finding, benchstat, brandid-lint visible this session) — trash-vs-keep per doctrine.
32. gci 0.14.0 nixpkgs pin vs buildflow doctor's `go install …@latest` hint — pick one policy.
33. Confirm `nixPackageOverrides` tailwindcss→tailwindcss_4 still matches nixpkgs after the next lock float.
34. DevShell vs base.nix duplication audit for fleet tools.
35. Confirm dprint/ruff/tailwindcss_4 are hydra-cached on aarch64-darwin (no >10 min source builds on the 256 GB SSD).
36. Post-deploy `which -a` ×6 + version proof table (assert WHICH binary serves, per the land-the-replacement rule).
37. Watcher escalation path: if boot-metrics hasn't converged by ~12:45, stop waiting and escalate (§11).
38. Reconcile `boot_userspace_regression` threshold (180 s) against today's storm-boot data once emitted.
39. SigNoz boot-phase dashboard panel: verify it isn't a dotted-suffix phantom (store-truth sweep applies).
40. Extend `checks`/negative tests for the new base.nix block? (probably none needed — plain package list — confirm no pin-audit interaction.)

*ROADMAP fuel:*

41. boot-metrics v2: systemd-analyze polling from a timer that is never a boot-transaction member.
42. A first-class "boot finished" metric (manager-state composite) as the gate leg instead of textfile presence.
43. Pre-freeze active mitigation: zram+PSI combined condition already fires as a check — evaluate an automatic response (oomd policy review) instead of observe-only.
44. Phantom-metric gate: allowlist window for "collector pending boot" (metric legitimately absent for N minutes post-boot) so deploys don't block during boot windows.
45. Fork-storm guard: load-1095 event → pids-max tuning on the user slice.
46. Untracked-status-report warning hook at session start (doctrine exists; no automation).
47. Deploy-window coordination: a tiny "deploy intent" file sessions write before starting (beyond flock).
48. gotchas-archive entry for the self-hold livelock class once confirmed.
49. boot-metrics: consider emitting `systemd-manager transaction_open` via D-Bus diff instead of scraping analyze output.
50. Re-derive the 2026-09-22 shadowing-doctrine row into a checklist agents run after ANY `go install` (the doctrine text exists; recurrence proves adoption gap — two recurrences in 8 weeks).

**Harvest record (AGENTS.md TODO System):** items 1–10 are session-direct follow-ups. 1–2 are in-flight under watcher 01A (deliberately not queued — a live executor owns them; the report IS their record). 3 → owner decision (§g.3), recorded in pipeline.md as `[decision]`. 4 → harvested to `docs/todo/monitoring.md` + queue. 5–6 ride the deploy (blocked:deploy, library only). 8 → harvested (pipeline.md, ready). 9–10 fold into 1's close-out. Items 11–20 observed box-state: 11/17/18 harvested to monitoring.md (watch/ready), 12–16 to stability.md-flavored rows where actionable (15–16 harvested to monitoring.md ready; 13–14 deliberately not harvested — stability narratives belong in status reports + gotchas, not the queue, per "no system-state narratives in the todo files"). Items 21–30 are process proposals (ROADMAP/AGENTS.md candidates — deliberately not harvested; they need owner ratification first). 31 harvested (pipeline.md, ready). 32–40 deliberately not harvested: policy confirmations or sub-checks of items already harvested. 41–50 are ROADMAP fuel by the skill's brainstorm rule.

## g) Questions I cannot figure out myself

1. **Is the 12:05 `httputil.test` fuzz swarm yours or a parallel session's — and is fuzzing during deploy windows acceptable, or should it be PSI/nice-gated?** The processes are gone; fish history writes only on shell exit; /proc forensics found nothing. I can't attribute it, and the load-1095 event materially worsened the storm that blocked two deploys.
2. **The 11:43 parallel deploy session: will it re-attempt after fixing what it thinks broke, or should I own the deploy?** I can't see its intent — only its dead log. If it re-fires mid-window we get churn (flock prevents damage, but one of us wastes a 16-min battery).
3. **buildflow policy: do you want the pinned system copy (`32f3f56`) as THE buildflow on PATH (trash `~/.local/bin/buildflow`), or do you deliberately keep a go-built dev copy for webphone iteration?** This decides whether I trash the stray or leave it as your dev override.
