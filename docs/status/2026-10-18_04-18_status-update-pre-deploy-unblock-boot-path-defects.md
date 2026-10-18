# STATUS UPDATE — Deploy Unblock, Two Boot-Path Defects, and the Night's Third Freeze

**When:** 2026-10-18 04:18 CEST (02:18 UTC) · **Instance:** single session, started 03:32 CEST
**Scope of this report:** ONLY this session's run (the pre-deploy unblock) plus what it directly observed. No unrelated research.
**Trigger:** owner pasted `DEPLOY_FORCE_PRESSURE=1 NIX_HEAVY_GATE_FORCE=1 nix run .#deploy`, which aborted at pre-deploy §15 (`101 passed, 6 warnings, 1 failed`), with the standing instruction to break it down, fix and verify step by step until everything works.
**Companion docs:** narrative/evidence report [2026-10-18_04-02 pre-deploy unblock + two boot-path defects](2026-10-18_04-02_pre-deploy-unblock-and-two-boot-path-defects.md) (commit `1aa26619b`) · evidence bundle [docs/status/tasks/2026-10-18_01-32_boot-daecca67-evidence-pull.md](tasks/2026-10-18_01-32_boot-daecca67-evidence-pull.md)

## TL;DR

The one blocking failure is **gone and verified**: the exposed boot `daecca67` is pulled canonically and committed, and the full pre-deploy battery now reads **104 passed / 6 warnings / 0 failed — "✅ Pre-deploy checks passed — safe to deploy"** (was `1 failed`), with §10's stale metric-loan warning also retired. The actual deploy was **not executed** (storm + owner's call) — it is ready to run.

Verifying it uncovered **two real defects and one fully-identified incident**:

1. **`boot-metrics-emit` exited 127 on exactly the boots it was built for** — the `open_age_secs` helper was defined *below* the retry loop that calls it, so `transaction_open` never got written when `systemd-analyze` refuses. **Fixed** (hoisted), reproduced and proven both ways with a fixture.
2. **`systemd-bless-boot` fails on EVERY boot** — a sub-second ordering race with `boot-mirror-sync`: bless reads `/boot` (the *non-booted* ESP) 150 ms after the sync starts and 19 s before the sync reverse-propagates the loader's boot-counter rename into it. **Root-caused with sub-second evidence, queued, deliberately NOT patched** (unverifiable without a reboot). Exposure: the counter decrements unblessed → after 2 more boots gen 929 is marked bad and the loader silently rolls back a generation.
3. **`daecca67` was the night's third freeze-class boot end** (hardware-watchdog reset, no shutdown sequence anywhere in the boot), with the storm still live during this session (guard trips `#3491`–`#3493`).

---

## a) FULLY DONE (verifiable; every item cites evidence)

| # | Item | Evidence |
| --- | --- | --- |
| a1 | **§15 blocker cleared** — `daecca67` (2026-10-18 00:42:21 → 03:03:38) pulled through `scripts/boot-evidence-pull.sh` into a 406-line canonical bundle (boot boundary, census, OOM/guard/thermal/panic sections) | `docs/status/tasks/2026-10-18_01-32_boot-daecca67-evidence-pull.md`, commit `13d65f6b7` |
| a2 | **Gate verified green** — all 10 exposed boots report `guarded`, `pre-vacuum gate: pass` (exit 0); vacuum clock 7.9G vs SystemMaxUse 8G | `bash scripts/pre-vacuum-evidence-gate.sh`; battery log `~/.cache/bootmetrics/pre-deploy-run.log` §15 |
| a3 | **Full pre-deploy battery green: 104 passed / 6 warnings / 0 failed**, "safe to deploy" (was 101/6/1) | same log, §Summary; run 03:52–03:57 |
| a4 | **`boot-metrics-emit` 127 root-caused and fixed** — helper hoisted above its call site; comment records why | `modules/nixos/services/boot-metrics.nix:151` (def), calls at `:176`, `:277`; commit `534b37b26`; `bash -n` clean on the rendered script |
| a5 | **Fix proven BOTH ways** — refusing `systemd-analyze` stub + `systemctl` stub + scratch textfile dir → `transaction_open 1`, `scrape_errors 1`, exit 0; same script with the helper stripped → exit 127, `open_age_secs: command not found`, no textfile | `~/.cache/bootmetrics/run-fixture.sh` (fixture) + `~/.cache/bootmetrics/script.sh` (rendered unit script) |
| a6 | **§10 stale loan retired** — `signoz_logs_pipeline_stale` was live but still listed as a one-deploy loan ("masks phantom regressions") | `scripts/pre-deploy-check.sh` `KNOWN_NEW_METRICS=""`; commit `bb2569d0b`; `--section-10-only` = **63 passed / 0 warnings / 0 failed** |
| a7 | **"First reboot under boot counting" [watch] row ANSWERED** (open since 2026-10-17) — counter rename live (`LoaderBootCountPath …+2-1.conf`), reverse-prop's first live branch = progress-rename, sync green (50 entries / 249M), boot source still the Samsung (`BootOrder` starts `000C`, `BootCurrent` `000C`, `LoaderDevicePartUUID` `023F66C0-…`), and bless-boot ran-but-FAILED (split out as a defect) | `docs/todo/stability.md` + `TODO_LIST.md` rows (commits `952cd4245`, `9f979c8cf`) |
| a8 | **bless race root-caused with sub-second evidence** and queued with the proposed fix + fallback exposure + manual mitigation | sub-second journal: `03:06:18.169` bless starts → `.242` sync starts → `.319` bless dies → `03:06:37.407` sync finishes; rows on both surfaces |
| a9 | **bless pull-in verified for the fix's blast radius** — `/run/systemd/generator.early/basic.target.wants/systemd-bless-boot.service`, `FragmentPath /etc/systemd/system/systemd-bless-boot.service`, `UnitFileState enabled-runtime`, `After=boot-complete.target` | `find /run/systemd -name '*bless*'` + `busctl get-property … Unit` |
| a10 | **`daecca67` freeze characterized + attributed to a WDT reset** (next boot's kernel: `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired`); autopsy row queued | evidence bundle + `docs/todo/stability.md` [ready] row |
| a11 | **AGENTS.md live-probe rule gained the `journalctl -b` trap** (8-char prefix → invalid + silently empty dump; an empty read is never evidence) | `AGENTS.md` (commit `9f979c8cf`) |
| a12 | **CHANGELOG entry** for the whole session (blocker, both fixes, boot-counting verification, freeze context) | `CHANGELOG.md` (commit `f4b61d4a5`) |
| a13 | **Status/evidence report written** and cross-linked from the queue surfaces | `docs/status/2026-10-18_04-02_…md`; commits `1aa26619b` + `0c46b4c06` |
| a14 | **Daemon-swept lint legs re-run standalone** (the pre-commit hook skipped them): deadnix clean, statix clean, `fmt-cached` 0 changed on `boot-metrics.nix`; shellcheck `--severity=warning` clean on `pre-deploy-check.sh` | commands in transcript, all rc=0 |
| a15 | **Post-amend secret scan clean** | `nix run nixpkgs#gitleaks -- detect --log-opts="HEAD~1..HEAD"` → "no leaks found" |
| a16 | **TODO-system integrity unchanged by my rows** — no new drift; the report is cited from both queue surfaces | `bash scripts/check-todo-system.sh` → `OK: TODO queue/library structure clean`; unharvested count went 67 → 66 |
| a17 | **Two stray §6 findings cleared on the way** — `boot-metrics-emit` is no longer in the failed-unit list (the post-boot re-emit succeeds; only the hung-boot path was broken) | battery §6 at 03:57 lists 5 units, not including `boot-metrics-emit` |
| a18 | **Working tree clean, all work committed** (7 commits: 5 mine + 2 daemon sweeps carrying exactly my files) | `git status --short` empty; `git log --oneline -7` |

## b) PARTIALLY DONE (what works, what is missing, blocker, effort)

| # | Item | What works now | What is missing | Blocker | Effort |
| --- | --- | --- | --- | --- | --- |
| b1 | **The deliverable itself: a deploy that completes** | Battery green, gates explained, blocker gone, deploy command known | The deploy was never executed — gen 929 is still running and the tile-logos/monitor365/boot-metrics changes are undeployed | Owner go-ahead + storm (IO PSI 21.7%, 3 trips in the last hour); ENTRY gates need `DEPLOY_FORCE_PRESSURE=1` until ≈04:32 | S |
| b2 | **`daecca67` autopsy** | Evidence pulled; death classified (WDT reset, 15 guard trips, never-exiting thermal ENTER, `MemAvailable 32.9%` at trip #3490); architected as a stability row | The actual driver (which readers pushed the GBs named in the guard's `system.slice/io.stat +104118MB` line) is unidentified | None (needs ClickHouse/cgroup-delta forensics) | L |
| b3 | **Fixture coverage for `boot-metrics`** | Ad-hoc fixture proves fix + bug both ways, on demand | It lives in `~/.cache/bootmetrics/` (volatile, not in the repo) and is not a CI/negative-test leg | None | M |
| b4 | **§6 failed-unit triage** | `systemd-bless-boot` explained (mine); `bank-sync-paperless`, `ci-watchdog`, `inboxclean-sync`, `service-health-check` enumerated | Whether the other four are storm casualties or regressions (count went 2 → 5 during the storm) | Needs a focused log pass | S |
| b5 | **The storm itself** | Live-measured: IO PSI 21.7% avg10 (was 73% at the deploy attempt), CPU PSI some avg10 95%, user-1000 app.slice `io.pressure full ≈ 91%`, 0 D-state tasks, top process writer 0.6 MB/s (i.e. writeback-class, not a live reader) | The periodic (~10-min, matching the trip cadence) writer that produces the guard's GB-scale `io.stat` deltas is still unnamed | Needs per-cgroup delta forensics + ClickHouse | L |
| b6 | **Canonical docs for the counter/bless flow** | Queue + library rows carry the full mechanism, evidence and fix | `docs/agents/systemd.md` boot-mirror section (the canonical home) was NOT updated with the race, and neither was the mirror runbook | None | S |
| b7 | **Memory/AGENTS.md updates** | The `journalctl -b` trap landed | The bless race + counter exposure + the stale nvme device mapping are not recorded in project memory yet | None | S |
| b8 | **Counter exposure mitigation** | Documented, exact command known, converges across the next sync | Not run (root action; the entry is at `+2-1`) | Owner (sudo) or my explicit go-ahead | S |

## c) NOT STARTED (planned, no code written, with priority)

| # | Item | Why not started | Still wanted? |
| --- | --- | --- | --- |
| c1 | The one-line bless ordering fix (`systemd.services.systemd-bless-boot.after = [ "boot-mirror-sync.service" ]` + wants) | Deliberate: unverifiable without a reboot, no fixture for the counter flow, and the box froze twice tonight | Yes — highest-value boot fix; needs the owner's reboot window |
| c2 | `CASES=bootmetrics` negative-test/CI leg in `scripts/negative-test-lints.sh` | Out of the deploy-unblock scope; fixture exists ad-hoc | Yes (queued) |
| c3 | `CASES=bootmirror` counter-propagation fixture legs | Carried over from the 2026-10-17 boot-order session; not mine tonight | Yes (queued upstream of me) |
| c4 | Manual counter mitigation (`systemd-bless-boot good` after a sync) | Needs root; deferring to the owner | Yes, optional |
| c5 | §8 stale build sandbox cleanup | Needs sudo (`systemctl start nix-build-cleanup.service`); agent-blocked | Yes (owner) |
| c6 | Repairing the truncated journal file `system@00065dd5ffec988d-…journal~` (warns on EVERY journalctl call, 100 MB span Oct 10 → Oct 15 unreachable) | Existing `[blocked:user]` row from an earlier session | Yes (owner) |
| c7 | Harvesting this report's (f) list into `TODO_LIST.md`/`ROADMAP.md` | Deliberate: the user's instruction was "write the report, THEN WAIT"; a 50-item list is brainstorm-grade and needs HARVEST routing rigor | Yes, on instruction |
| c8 | Re-checking the 68 queue↔library drifts + 66 unharvested §f reports surfaced by `check-todo-system.sh` | Pre-existing backlog, outside this session | Yes (separate pass) |
| c9 | Retrying/inspecting the other 4 failed units | Scope | Yes |

## d) TOTALLY FUCKED UP! (radical honesty; the most valuable section)

| # | What is broken | Severity | Root cause | Mitigation |
| --- | --- | --- | --- | --- |
| d1 | **`systemd-bless-boot` fails on EVERY boot and nothing noticed for ~2 days.** Boot counting went live 2026-10-17 23:55; the first counting reboot was 2026-10-18 00:42 and every boot since has failed the bless step. Consequence: the loader's `tries` counter never resets, so after 2 more unblessed boots **gen 929 is marked bad and the box silently rolls back to gen 928** — an unattended reboot could land you on an older generation without any error visible to you. | **HIGH** — silent behavioural change on reboot; can strand you on an older generation mid-incident | Not a systemd quirk: `bless-boot` reads `/boot` (the QLC ESP) while the loader's counter rename only exists on the booted Samsung ESP until `boot-mirror-sync` reverse-propagates it; both units start in the same 200 ms window and bless loses. The 2026-10-17 session explicitly deferred the live check that would have caught it ("still owed post-first-boot"). | Queued fix (order bless after the sync); manual `systemd-bless-boot good` after a sync; alert gap is its own (f) item |
| d2 | **A feature shipped broken in exactly the scenario it was built for, and its own output was the only "test".** `boot-metrics-emit` died with 127 on any boot where `systemd-analyze` refuses — the hung-boot class the `transaction_open` gauge was added for (2026-10-17). The gauge therefore never appeared on any real hang. | **MEDIUM-HIGH** — the invisible-hang class stays invisible, the metric that was supposed to prove the feature works was the broken thing | Shell helper defined *below* the retry loop that calls it; on a healthy boot the loop body never runs, so every local/CI check passed. `set -e` converted the 127 into unit failure. | **Fixed tonight** + fixture both ways; standing CI leg queued |
| d3 | **The deploy gate was the only thing standing between a 3×-freezing box and a heavy build, and the standing plan was to override it.** IO PSI was 73% with all four physical devices at ~100% `io_ticks` busy and 5 guard trips inside the hour when the deploy was attempted; the box had already ended two boots abruptly in the previous 2h23m. The override is a bare env var — nothing records *who* forced it or *why*. | **HIGH** — a freeze during activation is the documented exit-14/unanchored class | Episodic IO storm with an unidentified writer; the override path is intentionally frictionless and unlogged | I did NOT run the deploy; it is ready with the gate explained (post-≈04:32 the trip-recency leg self-clears). Audit-trail improvement is an (f) item |
| d4 | **I asserted a conclusion from an EMPTY read.** My first `daecca67` probes ran `journalctl -b daecca67` (an 8-char prefix `-b` rejects with `Invalid argument`) and produced zero lines; I briefly treated that emptiness as "0 shutdown markers — abrupt end" before re-running with the full 32-hex id. | **MEDIUM (methodology)** — precisely the phantom-green class this repo bans; a false autopsy verdict was one step away | `journalctl -b` prefix behaviour is silent-empty rather than loud-fail | Full-id re-run overturned it; the conclusion happened to hold (verified via absence of a shutdown *sequence*, not a grep count); rule now in AGENTS.md |
| d5 | **`AGENTS.md`'s NVMe↔device mapping is stale/inverted.** The boot-mirror paragraph says "currently Samsung = nvme1n1, Lexar = nvme0n1" and pins `LoaderDevicePartUUID 023f66c0 = Samsung`; this boot the live truth is **nvme0n1 = Samsung 970 EVO Plus** (= `023f66c0` = `/boot-mirror`) and **nvme1n1 = Lexar NQ790** (= `/boot`, which is also the device the non-root `bless-boot status` probe opened). Anyone trusting the parenthetical while debugging the boot chain will invert ESP↔device. | **MEDIUM** — wrong documentation on the boot chain during exactly the incidents where it matters | The paragraph itself warns enumeration flips; the "currently" parenthetical was never re-pinned after the flip | Cheap doc fix (an (f) item); the by-id/by-partuuid discipline the same file mandates is what saved this analysis |
| d6 | **Silent unit failures have no monitoring surface.** The bless failure appeared ONLY in pre-deploy §6's "review before deploying" list; nothing pages on "an unexpected unit is failed". A boot-critical unit failed ~5× overnight with zero alerts. | **MEDIUM-HIGH** — the class that outlives the session that should have caught it | §6 is a deploy-time warning; the 5 failures are separately surfaced only if a human reads the battery output | Add unexpected-failed-unit detection (an (f) item); no patch tonight |
| d7 | **Monitoring/queue hygiene is drifting at scale.** `check-todo-system.sh` reports **68 queue↔library drifts** (rows whose Source reports/entries don't resolve) and **66 unharvested §f-bearing reports** — the "queue one-liners and their library entries must not drift" rule is being violated continuously, and the checker only WARNs. | **MEDIUM** — every drift is a dispatch that can burn a full cycle on a wrong premise | Gate is warn-only by deliberate decision ("CHECK_TODO_PAIRING=strict" pending); the corpus is huge | Not mine tonight; recorded as (f) items |
| d8 | **The journal is running at 99% of its cap (7.9G / 8G).** Every deploy happens within ~100 MB of a vacuum that can eat an unpulled freeze boot; the pre-vacuum gate is the only defence, and it fires only for boots that an OPEN stability row happens to cite (date-granularity match). | **MEDIUM** — evidence loss class, by design under-provisioned | SystemMaxUse = 8G vs a corpus that needs multi-week retention | Gate works (it fired tonight and did its job); sizing/alerting is an (f) item |
| d9 | **Two reports for one session, written 16 minutes apart.** The 04-02 report and this 04-18 status update overlap heavily; the second exists because the owner asked for the standard a–g shape after the fact. | **LOW (process)** — reviewer confusion, duplicated maintenance surface | No session-level rule about "status report vs narrative report" coexistence | Cross-linked here; docs-health ANNOTATE can consolidate later |

## e) WHAT WE SHOULD IMPROVE!

1. **No silent-failure class may exist for a boot-critical unit.** Concretely: a textfile collector that emits `systemd_unit_failed{unit=…} 1` for any unit not on an expected-down allowlist, plus a Gatus check. This one change would have caught the bless failure within one boot instead of 2 days. (Impact: hours of forensics per incident; tonight's bless finding came from reading a warning list, not from alerting.)
2. **Never let an instrument be its own verification.** The `transaction_open` gauge's only proof was the gauge. Rule to adopt: any inline unit script with a conditional branch (the branch that runs only in the disaster case) needs a fixture that forces that branch. The repo already has the harness culture (`negative-test-lints.sh` `build_case`, `CASES=…` families) — the gap is applying it to inline Nix-embedded scripts.
3. **Generalise tonight's bug into a lint.** "Function called before its definition in an inline unit script" is mechanically detectable (awk/AST over the rendered script) and cheap. It is a whole class of copy-paste-shaped 127s.
4. **Write down the mirror rule as doctrine, not as a comment.** *Loader-owned state (counters, blessings) lives only on the ESP the loader boots; every consumer that reads it by convention (`/boot`) must be ordered AFTER the reverse-propagation.* The module comment already implies this; nothing enforces it, and bless-boot (a system unit we do not control) is a consumer.
5. **Make empty reads loud, everywhere.** `journalctl -b <prefix>` returning nothing is indistinguishable from "no events". Adopt either a wrapper (`boot_read()` that fails on 0 lines) or the discipline of asserting a non-zero expectation per query. The pre-vacuum gate already does `FAIL-LOUD` on a failed `--list-boots` — extend that posture.
6. **Record pressure-gate overrides with attribution.** `DEPLOY_FORCE_PRESSURE=1` should log the forcing session (pid/user/cwd, like the sudo-log forensics pattern this repo already relies on) into a deploy-forensics file. Right now the only trace is the terminal that ran it.
7. **Make the trip-free window smarter.** "≥60 min without a trip" is coarse; add the PSI avg60 trend and the top-IO driver identity to the gate, so "quiet because the driver finished" is distinguishable from "quiet between storm bursts".
8. **Automate the "first reboot under X" verification.** Three consecutive sessions have queued `[watch]` rows that depend on a reboot (boot counting, counter-prop branch, bless). A post-boot verification runner (timer that fires once after boot, executes the queued post-reboot checks, and writes its verdict into the journal + a textfile) closes this systemic handoff hole.
9. **Size (or split) the journal deliberately.** 7.9G/8G with a gate that exists to protect evidence means the system is one heavy log night from losing a freeze boot. Either raise `SystemMaxUse`, tier the journal to the Samsung hot subvol (the repo already has the pattern), or add a usage alert before the vacuum.
10. **Give the mirror sync one more consumer:** a "did the loader's state actually change and did we mirror it" line per boot (counter/path + hash), so a silent regression in the reverse-prop is visible without reading 50 filenames.
11. **Fix the multi-session edit-loss class for docs.** I watched my own CHANGELOG edit vanish off disk (mtime untouched by my write) while a parallel session rewrote the same file. At minimum: re-verify bytes immediately before commit (I did, after discovering it) and prefer small, single-file commits; better: a docs-file ownership convention for concurrent sessions.
12. **Correct the NVMe↔ESP mapping in project memory** and prefer the by-id/by-partuuid forms exclusively in prose (the "currently nvmeN" pattern is guaranteed to rot; tonight it did).

## f) Top 50 things we should get done next (ranked by impact; brainstorm-grade — see HARVEST note)

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | Ship the bless-after-sync ordering fix and verify on the next reboot | Critical | S | Bug |
| 2 | Add unexpected-failed-unit detection (collector + Gatus) so no boot-critical unit fails silently again | Critical | M | Quality |
| 3 | Attribute the `daecca67` freeze driver: top-5 IO readers across trips `#3488`–`#3490` (cgroup `io.stat` deltas + ClickHouse) | Critical | L | Bug |
| 4 | Resolve the ~10-min-cadence storm writer (guard `system.slice/io.stat +104 GB` deltas vs 0.6 MB/s live process writes = writeback of earlier buffered writers) | Critical | L | Bug |
| 5 | Land the `boot-metrics` retry-path fixture as a `CASES=bootmetrics` leg (in-repo, not `~/.cache`) | High | M | Quality |
| 6 | Land the mirror counter-propagation fixture legs (`CASES=bootmirror`) — the missing safety net that made the bless race shippable | High | M | Quality |
| 7 | Add an emitting check for "entry blessed after boot complete" (`boot_blessed` textfile or a Gatus journal-based check) | High | M | Feature |
| 8 | Raise/rework `SystemMaxUse` (and add a pre-vacuum usage alert) so unpulled evidence isn't 100 MB from deletion | High | S | Bug |
| 9 | Add a lint: helper function called before its definition in inline unit scripts (tonight's 127 class) | High | M | Quality |
| 10 | Add a post-reboot verification runner for queued `[watch]`-style checks | High | L | Feature |
| 11 | Triage the 4 unexplained failed units (`bank-sync-paperless`, `ci-watchdog`, `inboxclean-sync`, `service-health-check`) | High | S | Bug |
| 12 | Fix the stale NVMe↔ESP mapping in `AGENTS.md` (Samsung = `nvme0n1`, Lexar = `nvme1n1`, by-id forms in prose) | High | S | Documentation |
| 13 | Decide the counter policy while bless is broken: raise `tries`, or disable boot counting until the fix lands | High | S | Decision |
| 14 | Run the deploy (with go-ahead) and verify gen 930 anchors (`readlink /run/current-system` = newest `system-*-link`) | High | S | Feature |
| 15 | Extend the guard's top-IO attribution from `system.slice` aggregate to top-5 child units | High | M | Quality |
| 16 | Gate the `nsfw-classifier --all` ensemble behind the maintenance/PSI admission gate (CPU PSI sat at ~95% during this session) | High | M | Quality |
| 17 | Add a `journalctl` wrapper that fails loudly on an empty read (empty-read guard) and use it in every probe script | Medium | S | Quality |
| 18 | Add a `boot-id-resolve` helper (prefix → full id via `--list-boots`) and use it wherever `-b <id>` appears | Medium | S | Quality |
| 19 | Make `boot-evidence-pull.sh` capture the WDT reset-reason line + per-boot guard-trip census in its canonical sections | Medium | S | Quality |
| 20 | Make `boot-evidence-pull.sh` fail loudly when the resolved boot yields 0 lines | Medium | S | Bug |
| 21 | Log pressure-gate overrides with attribution (who forced it, from where) into a deploy-forensics file | Medium | S | Feature |
| 22 | Add CPU PSI + top-driver identity to the deploy ENTRY gates (IO PSI + disk busy alone missed a 96% CPU-PSI window) | Medium | S | Quality |
| 23 | Update `docs/agents/systemd.md` boot-mirror section with the bless race, the ordering rule, and the new evidence | Medium | S | Documentation |
| 24 | Update the boot-mirror runbook with "consumer tools must run after the reverse-prop" + the manual bless remedy | Medium | S | Documentation |
| 25 | Add the counter/bless exposure to project memory (AGENTS.md boot paragraph) with the rollback risk spelled out | Medium | S | Documentation |
| 26 | Automate the pre-vacuum evidence pull: a nightly/per-boot job that pulls any exposed boot cited by an open row | Medium | M | Feature |
| 27 | Add a `transaction_open` alert (observe-only wired today) so a truly hung boot pages | Medium | S | Feature |
| 28 | Investigate why §6 grew 2 → 5 failed units inside the storm window (correlate with trips `#3491`–`#3493`) | Medium | M | Bug |
| 29 | Add boot-source invariants (`BootOrder`/`BootCurrent`/`LoaderDevicePartUUID`) to a textfile collector so a silent NVRAM flip alerts | Medium | M | Feature |
| 30 | Add a pre-deploy assertion that `LoaderBootCountPath` names the generation being deployed | Medium | S | Quality |
| 31 | Add a post-deploy probe for boot-metrics freshness + entry-bless state (extends §17's sweep discipline) | Medium | S | Quality |
| 32 | Add an alert for "counter decremented twice without a bless" (detects this race even if messages change) | Medium | M | Feature |
| 33 | Re-check the "user-1000 slice `io.pressure full` ~91% with idle disks + 0 D-tasks" claim on this boot (possible corrupted PSI accounting, prior session's open question) | Medium | M | Bug |
| 34 | Retry/verify `boot-mirror-sync` green after the next deploy (gen 930) and record the counters line | Medium | S | Quality |
| 35 | Consider a "storm mode" that suppresses non-critical timer/restart traffic during trip windows | Medium | L | Feature |
| 36 | Document the manual counter mitigation (`systemd-bless-boot good` post-sync) in the boot runbook with verification steps | Medium | S | Documentation |
| 37 | Work the 68 queue↔library drifts reported by `check-todo-system.sh` | Medium | L | Cleanup |
| 38 | Work the 66 unharvested §f-bearing reports (docs-health HARVEST/ANNOTATE) | Medium | L | Documentation |
| 39 | Decide gate hardness: flip `CHECK_TODO_PAIRING`/`CHECK_TODO_HARVEST` to blocking (or define the ratchet) | Medium | S | Decision |
| 40 | Repair the truncated journal file `system@00065dd5ffec988d-…journal~` (owner; warns on every call) | Medium | M | Bug |
| 41 | Clean the 1 stale build sandbox (`systemctl start nix-build-cleanup.service`, owner/sudo) | Low | S | Cleanup |
| 42 | Fix the recurring §12 "ExecStart binary not built yet" warnings (`network-local-commands`, `pocket-id-provision`) | Medium | M | Bug |
| 43 | Owner: prune ~10 dead EFI/NVRAM entries + pin explicit Samsung→QLC ordering (carried from the boot-order report) | Low | M | Cleanup |
| 44 | Move the ad-hoc fixture harness from `~/.cache/bootmetrics/` into a durable repo location | Medium | S | Quality |
| 45 | Add the night's crash chain (00:40:44 power cut → 03:03:38 WDT) to `docs/gotchas-archive.md` / the stability runbook timeline | Medium | S | Documentation |
| 46 | Add a "gate-first triage" checklist to the deploy runbook (the 45-minute path from blocked deploy → root cause, so the next one is 15) | Low | S | Documentation |
| 47 | Normalise the report citations I added in queue rows to the house `**Source:**` shape in a later docs pass | Low | S | Cleanup |
| 48 | Consolidate the two same-session reports (04-02 + this) via docs-health ANNOTATE | Low | S | Cleanup |
| 49 | Add `boot-metrics` and `bless-state` checks to `post-deploy-check.sh` (make the boot chain a first-class post-deploy surface) | Medium | M | Quality |
| 50 | Re-run the §11 FOD/vendorHash preview and full battery once the boot-metrics change is in the toplevel (confirm no FOD churn) | Medium | S | Quality |

**HARVEST note (explicit):** the three direct follow-ups of this session are ALREADY harvested before this report (`TODO_LIST.md` + `docs/todo/stability.md`: bless race, `CASES=bootmetrics` leg, `daecca67` autopsy). The 50 items above are **deliberately NOT harvested yet** because the owner's instruction was "write the report, THEN WAIT FOR INSTRUCTIONS", and a 50-item list is brainstorm-grade — the skill's own rule is that most extra items are ROADMAP fuel and need HARVEST routing rigor (items 1–14 are queue-worthy; the rest mostly route to the domain libraries or ROADMAP).

## g) Questions I CANNOT answer myself (max 3)

1. **Deploy go-ahead and timing?** The battery is green and the deploy is ready, but the box is 3 freezes deep tonight and IO PSI sits at ~21.7% (3 guard trips in the last hour; the trip-recency leg self-clears ≈04:32). Do you want me to run `nix run .#deploy` now, wait for the trip-free window, or hold until you have shed the heavy job? I cannot judge whether tonight's risk profile is acceptable to you — it is your machine and your data, and I have no way to know whether the ongoing work depends on staying up.
2. **Green-light the bless ordering fix as a shipped-but-unverified-until-reboot change?** It is one line (`after`/`wants` on `systemd-bless-boot`), the failure mode if my ordering is wrong is a delayed/skipped bless (i.e. today's status quo), and the only honest verification is the next reboot. Alternatively I build the fixture legs first and ship it verified-without-a-reboot. I cannot decide your appetite for unverified boot-tooling changes.
3. **Do you want the counter exposure defused now (`sudo systemd-bless-boot good` after a sync), or accept the rollback risk until the ordering fix lands?** Blessing strips the `+2-1` on `/boot` and the next sync carries it to the booted ESP, which stops the countdown; not doing it leaves gen 929 two boots from being marked bad. This is a root action on boot state, so it is your call.
