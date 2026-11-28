# Freeze #66 status 2026-11-28 14:10: watchdog resets without dumps, our circuit breakers and resume retries

**Created:** 2026-11-28 14:28 CET · agent session (crush, glm-5.4) · basis: this session's own commands and artifacts only

Session status + self-review for the question "Why did we crash ~20 minutes ago?" (asked 10:57, cut at 10:43:28) and the follow-up questions on watchdog resets, gates, breakers and retries. Autopsy of the cut: `docs/status/2026-11-28_12-15_freeze-66-llama-chat-idle-ttl-engine-panic-last-pre-fix-capture-cut.md` (called "the autopsy" below). Ledger row #66: `docs/agents/stability.md`. Repo state described: `git rev-parse --short HEAD` = `d1e6e2270` (14:23:16); `TODO_LIST.md` carried uncommitted edits of this session at report time (the auto-commit daemon picks them up).

## Scope line

**Verified here (command + artifact, 2026-11-28 10:57-14:26 CET, all on recovery boot `56ba232e`, gen-1033):** `journalctl --list-boots`; reset reason in boot 0's kernel log (`0x02000800`); the dying boot's kernel cmdline from its own kernel log; `scripts/crash-triage.sh --boots 6`; the EFI pstore archive of the cut (16 records, both `dmesg.txt` read with `sudo -n cat`, copies in `~/.cache/crash-20261128/`); `scripts/boot-evidence-pull.sh -b -1` (rc 0, 2.1 MB file under `docs/status/tasks/`); one JSON dump of the dying boot's last 74 minutes (126,133 lines) plus unit-scoped journal reads for llama-chat, llama-vlm-cap, the thermal guard and the idle checks; the idle-check script of the running generation (line 34); the deploy logs `/var/log/systemnix-deploys/2026-11-28_{09-30-16,09-33-12,11-26-54}.log`; the boot anchor; live kernel and watchdog settings (`/proc/sys/kernel/*`, `/sys/class/watchdog/watchdog0/*`, `/sys/kernel/kexec_crash_{size,loaded}`, the live `watchdogd.conf`); `modules/nixos/services/{llama-chat,_llama-idle-activity,kdump-capture-path}.nix` (read, not changed); `scripts/check-todo-system.sh` before the TODO edits (3 WARN lines, "structure clean").

**NOT verified here:** the main kernel's panic reason (no artifact exists); the four clients polling llama-chat every 30 s; which process read the 110 GB under `user.slice` at 10:00-10:11; which collector causes the 10-minute stalls; what the Forgejo CI jobs were or whether their workflows gate themselves; what `watchdogd` does at its meminfo "critical" level; whether the in-tree idle fix behaves under the real timer (deployed nowhere); whether the post-fix capture boot fits in 512 MiB (never run); whether the soft-lockup and hung-task detectors actually get starved in this box's livelocks (the docs say so, I measured nothing); inherited statements I quoted without re-running them (the ledger's reset classes for #34-#65, "gen-1033 deployed 2026-11-27 10:27", "capture-path fix in gen-1032 since 2026-11-26 06:50").

## TL;DR

1. The box panicked at about 10:43:29 on a 60-minute IO storm that our own llama-chat idle check manufactured: it unloaded a 23.4 GB model under live clients 11-15 min after every load, six loads 09:07-10:33, each reload 14-23 GB of QLC reads, three of them killed by the start contract and restarted from byte 0. Memory was healthy throughout (49-54 % available); IO and heat (98-99 °C for the last 59 min) were the killers.
2. The reset reads "hardware watchdog" only because the kdump capture kernel died before it could reboot itself. The panic text and the vmcore are lost, as in every panic-class cut since 2026-11-17.
3. The engine is still live at 14:25: 13 llama-chat loads and 22 failed idle-check probes on this boot, 9 guard trips, 38 throttle ENTERs. The fix is in tree (`2818c0751`) and undeployed; both deploy attempts today were refused (eval breaks at 09:33, trip recency at 11:26).
4. Why watchdog resets without dumps: hang-class cuts never panic, and the hardware watchdog (90 s) is faster than every detector that could produce a panic; panic-class cuts panic, but the capture kernel cannot boot a whole NixOS system inside 512 MiB. Both are configuration, not fate.

## Q1: Why do we always end up in hardware watchdog reboots without kernel dumps?

Live values read at 14:05 (`/proc/sys/kernel/*`, `watchdogd.conf`, `watchdog0`):

| Setting                                   | Live value                        |
| ----------------------------------------- | --------------------------------- |
| Hardware watchdog (`watchdog0`)           | SP5100 TCO timer, timeout 90 s, `watchdogd` pats every 10 s |
| `kernel.panic`                            | 10                                |
| `kernel.hung_task_timeout_secs` / `hung_task_panic` | 120 / 1                |
| `kernel.watchdog_thresh` / `softlockup_panic` / `hardlockup_panic` | 20 / 1 / 1 |
| `kexec_crash_size` / `kexec_crash_loaded` | 512 MiB / 1                       |

Three independent reasons, in order of importance:

1. **Hang-class cuts have nothing to dump.** The ledger's WDT cuts (`0x02000800`, pstore empty: #34-#51, #53, #60, #63) end with the journal cut mid-traffic and no panic. kdump only runs on a panic. The watchdog fires at 90 s without a pat; the hung-task detector needs 120 s and the soft-lockup detector 40 s (2 x `watchdog_thresh`, by the kernel's rule) of a CPU stuck in one kernel loop. A box that is thrashing (every CPU busy, every task slow, nothing stuck for 40 s in one place) trips neither, and the docs record that the detector threads get starved too. Result: reset by hardware, zero kernel evidence. The watchdog is the fastest actor on the stage, so it always wins.
2. **Panic-class cuts panic, and the dump dies in the capture kernel.** #52, #55, #56, #59, #61, #62, #64, #65 (ledger) and #66: the main kernel panics, kexec jumps into the capture kernel, and that kernel boots the same initrd and the same systemd into 512 MiB. In #66 it had 509 free pages at 7.3 s, killed `mount`, then journald, and panicked `System is deadlocked on memory` at 9.477 s. No vmcore. In #66 it also never applied its own auto-reboot sysctl, so the watchdog, not software, reset the box. This cut is the first one that shows the capture boot failing at a *default* watermark (`min:2432kB`, not the inherited 2 GiB one): about 370 MiB were simply in use (shmem 129 + slab 102 + btrfs 67 + iommu 44 + execmem 29 MiB). The sysctl fix that is live for the first time in this boot addresses the watermark, not the size.
3. **The main kernel's panic text never reached pstore** on any of them, because the pre-fix kernels kexec before the kmsg dump. The dying boot (booted 2026-11-25 11:06:51) had no `crash_kexec_post_notifiers`. This boot has it. Untested.

What is not the cause: RAM. 123 GiB, 49-54 % free while it died. And not "modern Linux crashes": every retained cut of the ledger is our own load (this one: a broken idle check; earlier ones: scrubs, agent build batteries, CI, cold-load re-arms) on a board that sits at its thermal ceiling under that load.

## Q2: Recommended improvements

Ranked by effect per effort. Basis in brackets.

1. **Deploy the idle-activity fix** (`2818c0751`, in tree). Removes the engine measured in the death window. [verified: script line 34 of the running generation, 83 + 22 failed probes]
2. **Decide llama-chat's residency.** Resident costs 32.9 GB (27 % of RAM); every cold load costs 23.4 GB of QLC reads, about 9 min unavailability under load, and heat. The 60-min keep-alive still reloads whenever usage is burstier than an hour. [verified numbers; the trade-off is yours, question 1]
3. **Raise the capture cage to 2 GiB** (`boot.crashDump.reservedMemory`), 1.6 % of RAM, and test with one deliberate crash. [#66's capture-kernel memory profile]
4. **Let a panic come before the watchdog:** hung-task 30 s, `watchdog_thresh` 10, watchdog timeout 120-180 s. Each converts some hangs into captured panics; each can turn a recoverable stall into a reboot. [live values; trade-off is yours, question 3]
5. **Gate the host Forgejo runner.** `forgejo.nix` sets `MemoryMax` on its units and has no PSI or admission gate (grep for psi / heavy-job / admission / cargo-gate: no match). The runner logged `[CI/buildflow]` nix jobs while nix-daemon took 43 / 94 / 431 / 188 build-user connections per 10 minutes from 10:00. [verified presence; unverified whether the workflows gate themselves]
6. **`system-health-metrics` is a top reader and the guard keeps pausing it:** 21, 157, 141 and 2 x 35 MB/s in 5 of the 7 death-window trips, SIGSTOPped in 4 of them, each pause a stale-monitoring window. PSI-gate its heavy legs and take it out of the pause set. [verified in the guard lines; #56 had already named it an amplifier]
7. **Stagger the 10-minute collector pile.** About 20 timers start in the same second at :x9 and :x19; crm's 0.50 ms median shows 3.0-5.7 s maxima at 09:49, 09:59, 10:09, 10:10, 10:20, 10:30 and 10:40. Coincidence measured, cause not. [verified coincidence]
8. **Reload budget for llama-chat:** at most N cold loads per hour, then stay down and raise SEV1 instead of a 15th remap.
9. **Resume by condition, not by clock:** the guard's hard cap SIGCONTinued 12 paused groups at 10:12:15 into a 43 % storm.

## Q3: Do our gates trigger lots of I/O pressure?

**The gates themselves, no. The things around them, yes.**

- Deploy entry gates: correct and cheap; they refused twice today (09:30 exit 12 at io PSI 37 %, 11:26 exit 12 on trip recency).
- `psi-wait-gate`: a sleep-poll, no IO. It held llama-vlm-cap for 13 checks to the cut. But it admits on one avg10 sample under 30 %: llama-chat was admitted at 24.14 % (09:36:17), 24.29 % (10:19:47) and 24.50 % (10:33:34), while the guard heartbeats of the same hour read avg60 42-50 % with the disk at 100 %.
- Collectors do: `system-health-metrics` (above), the 10-minute pile, and the deployed idle checks until 2026-11-26 read 1.9-2.4 GB of journal per run (72 GB once, per the TODO row, not re-measured).
- The deadlock that matters: the gates refuse the deploy that carries the fix while the unfixed unit keeps the storm going. Fix in tree at 03:09; deploys refused at 09:33 and 11:26. The escape hatches are to shed load first (calm window) or to force (`DEPLOY_FORCE_PRESSURE=2`, the pattern that killed #40 and #49).

## Q4: Do we kill the wrong thing at the wrong time?

Yes, four times in this one cut:

| Killed / stopped                 | When                                  | Verdict                                                     |
| -------------------------------- | ------------------------------------- | ----------------------------------------------------------- |
| llama-chat backend (idle check)  | 11-15 min after each load, 4 clients polling | wrong thing, wrong time: probe error treated as "idle" |
| llama-chat load (start contract, curl 400 retries) | about 13.3 min into a load | wrong time: 3 of 5 loads were 60-100 % read, then remapped |
| `system-health-metrics` (IO-PAUSE) | 4 of 7 trips                         | wrong thing: the monitoring, not the engine; llama-chat's page-in was skipped as "not I/O-stalled" |
| 12 paused process groups (IO-RESUME at the 3600 s cap) | 10:12:15, into io PSI avg60 43 % | wrong time: time-based resume |

Not killed when it mattered: nothing. Zero OOM kills in the window, 49-54 % of RAM free. The system spent IO, the scarce resource, to save memory, the abundant one.

## Q5: Do we have circuit breakers?

| Breaker                                    | State (this session)                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------------ |
| Deploy pressure gate, 2 tiers + trip recency | WORKS: exit 12 twice today                                                           |
| `psi-wait-gate` (refuse after 900 s)       | WORKS as admission control; entry-sample only; a refuse is followed by a restart 10 s later |
| memory-emergency-guard IO-PAUSE            | TRIPS BUT OPENS NOTHING: 576 trip lines in the boot, 516 of them without a pausable target, 60 with a SIGSTOP; the engine was never pausable |
| thermal-pstate-guard                       | CYCLES: 354 deep-caps and 315 guided episodes in the boot; cannot close a standing deficit |
| llama-chat start contract + `Restart=on-failure` | KILLS a slow load, retries with backoff on paper (see Q6)                         |
| Idle TTL                                   | NO BREAKER on unload/reload frequency; the 10-min floor is the only hysteresis     |
| `llama-chat.socket` (4 connections)        | DROPS the fifth ("Too many incoming connections (4)")                                |
| Host Forgejo runner                        | NONE in `forgejo.nix`                                                                |
| `watchdogd` checks                        | `meminfo` enabled (warning 0.95, critical 0.98); `filenr` and `loadavg` disabled; no repair action configured |

Missing: a reload budget, a condition-based resume, a CI and build-battery admission gate on this host, and a pre-reset action from `watchdogd` (its repair hook is installed and unused).

## Q6: Smart or stupid resume retries?

- `Restart=on-failure`, `RestartSec=10`, `RestartSteps=5`, `RestartMaxDelaySec=15min`: a real backoff that never escalates, because every "successful" start resets the step counter and the idle bug guaranteed the next start within minutes. Observed restart counters: 1, 1, 2.
- `psi-wait-gate` refuse: the unit fails and systemd retries 10 s later. A breaker that recloses in 10 s; only the gate's own 900 s wait slows the loop.
- Socket activation: any client connection restarts the load at once; no cool-down after a failed load. The per-connection bridges wait up to 30 min and then fail (the failed-instance pile of the existing ai-stack row).
- Clients: four pollers at 30 s keep the engine alive; I did not check what the bridge answers them.
- CI: the runner logged nix invocations about every 2 minutes through the storm (10:26, 10:27, 10:29, 10:31, 10:33, 10:35, 10:36). Separate jobs or retries: not determined.

## a) FULLY DONE

- Crash class, mechanism and drivers of the 10:43:28 cut. Evidence: the autopsy report §0-§3, the evidence file, pstore copies in `~/.cache/crash-20261128/`.
- Evidence pull for the dying boot: `docs/status/tasks/2026-11-28_11-04_boot-0737ecd7-evidence-pull.md` (rc 0).
- Ledger row #66 in `docs/agents/stability.md`; two errors of the first draft corrected at 14:1x ("longest since #59", thermal counters).
- TODO updates: `docs/todo/stability.md` rows "Deploy the llama idle-check fix and verify…" and "Make kdump capture one cut" (UPDATE clauses), a new `[decision]` library row "Make hangs leave a dump…", `TODO_LIST.md` NOW bullets 5 and 8 rewritten, the kdump queue line updated, one new queue line for the idle fix. Evidence: the files; `scripts/check-todo-system.sh` re-run after the edits (result in §Artifacts).
- Live settings read for Q1 (watchdog, kernel detectors, crash cage).

## b) PARTIALLY DONE

- Death-window attribution: llama-chat and llama-vlm-cap named from unit lines; nix builds, forgejo's 187 MB/s at 10:11, the 110 GB under `user.slice`, and the collector stalls are measured, not attributed. Blocker: none, time. Effort: M.
- TODO harvest of this report's §f: items 1-3 landed in rows; the rest are recorded as candidates with reasons. Effort to finish after your ruling: M.

## c) NOT STARTED

- Naming the four llama-chat pollers (one `ss`/caddy-log read on this boot would do). Priority: high, it decides question 1.
- Isolating the 10-minute stall (stagger the timers, re-measure crm p95). Priority: medium.
- ClickHouse telemetry for the death window (load1, per-device busy, zram): the journal carried enough for the class; not pulled.
- Any change to `kdump-capture-path.nix`, `boot.crashDump.reservedMemory`, detector sysctls, `forgejo.nix`, `system-health-metrics`: owner decisions first.

## d) TOTALLY FUCKED UP

| What | Severity | Root cause | Mitigation |
| ---- | -------- | ---------- | ---------- |
| llama-chat idle check stops a backend under live traffic | HIGH: the storm behind a kernel panic, still live (13 loads on this boot) | `templateActivity` spliced as a store directory; probe error falls through to `systemctl stop` | in-tree fix `2818c0751`; undeployed; deploy refused by gates |
| Every panic since 2026-11-17 lost its vmcore and panic text | HIGH: no vmcore on record for any cut through #66 | capture boot = full NixOS boot in 512 MiB; kexec before kmsg dump | fix live and unproven; cage size unaddressed |
| Hang-class cuts can never leave a dump | HIGH | watchdog 90 s < hung-task 120 s; thrash trips no lockup detector | decision row added |
| IO-PAUSE trips mostly without a target (516 of 576) | MEDIUM | pausable set excludes the real engines (page-ins, CI, collectors) | existing IO-PAUSE DISARMED alert; no fix here |
| The fix for the storm was refused at the deploy gate while the storm ran | MEDIUM | gates protect against deploy load; no "fix under storm" path | owner: calm window or socket stop |
| My interim answer came 31 min after the question | LOW (process) | census run before the five class probes; three broken awk one-liners | nothing to mitigate now |
| Ledger row #66 first draft carried two false statements and was auto-committed | LOW | I trusted a memory (#52) and mislabeled counters | corrected in place at 14:1x |
| Stability text says watchdog "30 s"; live is 90 s | LOW (doc drift) | config changed, docs not | flagged, not edited |

## Self-review (the twelve questions, short)

1. **Forgot:** `scripts/session-start-probe.sh` at session start; the kdump runbook (read the module instead); the pre-vacuum gate after the evidence pull; a second look for parallel sessions on this crash until 13:59 (none found); to name the four pollers; and for about two hours the TODO edits the 12-15 report already claimed (done now).
2. **Stupid we still do:** fail-closed idle probes; saving memory by spending IO on an IO-starved box; a capture kernel that boots an entire OS in 512 MiB; a watchdog faster than every detector; a guard that trips 577 times a boot and mostly finds nothing to pause; 2.1 MB evidence files with 12,103 guard lines.
3. **Could have done better:** five cheap probes, interim answer, census. Python for the journal instead of awk. Finish harvested rows before writing "harvested".
4. **Can still improve:** the (c) list; the script improvements in (e).
5. **Did I lie?** No. Two false sentences sat in the first ledger draft and one claim ("harvested") in the 12-15 report was ahead of the work; all three corrected the same day, the ledger ones after the daemon had committed the draft.
6. **Less stupid:** fail-open probes everywhere; reload budgets; condition-based resumes; detector timeouts below the watchdog; one deliberate crash as acceptance for any capture-path change.
7. **Ghost systems:** `watchdogd` has a repair hook and warning-level checks; `meminfo` is enabled, `loadavg` and `filenr` disabled, no repair configured, so the daemon pats the dog through every storm and never acts. `psi-wait-gate` exists for llama-chat but its refuse is undone by `Restart` 10 s later. Value of wiring: a pre-reset shed action is the only automated actor with RT priority I know of on this box; worth evaluating, not wiring blind.
8. **Scope creep:** none into other code; the TODO work after the diagnosis took longer than the diagnosis.
9. **Removed something useful?** Nothing removed.
10. **Split brains:** watchdog timeout (docs 30 s, live 90 s); the idle-check row said "deployed" for a version that was broken; NOW bullet 5 described the pre-reboot state after the reboot (both fixed); evidence file names use UTC (11-04) while reports use CET (12-15).
11. **Tests:** the getExe defect is pinned by `tests/test-llama-chat-accelerator.nix` per the module comment (not read here). No test exercises "idle check must keep a backend that has a live bridge" or "start contract under a slow load". Add a VM leg with a bridge alive at the check instant.
12. **Inherited claims re-verified:** the watchdog timeout (re-run, differs); the crm latency baseline (ledger #39 says 20 µs, live median 0.50 ms; original not annotated); everything else in the NOT-verified list was quoted, not re-run.

## e) WHAT WE SHOULD IMPROVE

- `scripts/crash-triage.sh`: print the five class-deciding probes first, the 6-boot census after.
- `scripts/boot-evidence-pull.sh`: one line saying whether the dying boot's cmdline has `crash_kexec_post_notifiers`; and stop inlining every guard line (keep counts and the last 200).
- Idle checks: fail open by construction (a probe that errors is activity), plus a reload budget.
- IO-RESUME: by condition; at the cap, stay paused and alert.
- `system-health-metrics`: PSI-gate its heavy legs; never SIGSTOP the monitoring.
- A single owner-visible place for the live watchdog contract (the doc says 30 s, the box runs 90 s).

## f) Next tasks (17 real ones; the other 33 of "up to 50" would be padding)

Harvest state per item. Tag and location are named where it is in the TODO system.

1. Deploy the idle-activity fix, then run the six verification checks. Critical, S. `[ready]` row "Deploy the llama idle-check fix and verify: sub-second idle checks, no failed-bridge pile, keep-alive honored" (`docs/todo/stability.md` + queue line + NOW bullet 8). HARVESTED (row updated).
2. Run the deliberate crash test on this boot. Critical, S. `[blocked:user]` row "Make kdump capture one cut" (library + queue + NOW bullet 5). HARVESTED (row updated).
3. Decide and apply: capture cage 2 GiB, detector timeouts below the watchdog. Critical, S. `[decision]` library row "Make hangs leave a dump…". HARVESTED (new library row).
4. Name the four llama-chat pollers. High, S. NOT HARVESTED: it is a step inside question 1, not a row.
5. Decide llama-chat residency (resident / longer keep-alive / status quo). High, decision. NOT HARVESTED: question 1.
6. Gate the host Forgejo runner's builds (PSI or admission), or move CI off the box. High, M. NOT HARVESTED: premise check open (do the workflows self-gate?).
7. `system-health-metrics`: PSI-gate heavy legs, leave the IO-PAUSE set. High, M. NOT HARVESTED: check for an existing #56 amplifier row first.
8. Stagger the 10-minute collector pile and re-measure crm p95. Medium, S. NOT HARVESTED: cause unattributed.
9. Reload budget for llama-chat (N loads per hour, then down + SEV1). High, M. NOT HARVESTED: availability trade-off, decision.
10. IO-RESUME by condition; stay paused at the cap and alert. Medium, M. NOT HARVESTED: may overlap the guard round-3/4 rows; check first.
11. Start contract: do not kill a load past the curl budget under a storm. Medium, S. NOT HARVESTED: task 1 removes the trigger; re-check after the deploy.
12. `crash-triage.sh`: class probes before the census. Medium, S. NOT HARVESTED: tooling nicety; say the word.
13. `boot-evidence-pull.sh`: `crash_kexec_post_notifiers` line + bounded guard section. Medium, S. NOT HARVESTED: same.
14. Fix the watchdog-contract drift (30 s vs 90 s) where the canonical value lives. Low, S. NOT HARVESTED: I do not know which doc is canonical for you.
15. Annotate ledger #39's crm baseline (20 µs vs 0.50 ms live). Low, S. NOT HARVESTED: doc hygiene.
16. Evaluate `watchdogd`'s warning-level repair hook for a pre-reset shed action. Medium, M. NOT HARVESTED: decision, and I have not read what critical level does.
17. VM test leg: idle check with a live bridge keeps the backend. Medium, S. NOT HARVESTED: fold into task 1's verification or mint after.

## g) Questions only you can answer

1. **llama-chat residency:** should llama-chat stay resident (32.9 GB of 123 GiB, zero reload IO), get a keep-alive of several hours, or keep the 60-min idle unload? I can measure the pollers, not your memory budget.
2. **Two owner steps:** (a) when do you want the idle-fix deploy run, and may I first ask you to stop `llama-chat.socket` for about 30 minutes so the pressure and trip-recency gates pass without forcing? (b) when will you run the deliberate crash test on this boot?
3. **Trade stability for evidence?** May I (after your yes) reserve 2 GiB for the capture kernel and shorten the hung-task and lockup timeouts below the watchdog, accepting that a false-positive detector hit becomes a reboot?

## Artifacts

- `docs/status/2026-11-28_12-15_freeze-66-llama-chat-idle-ttl-engine-panic-last-pre-fix-capture-cut.md` (autopsy)
- `docs/status/tasks/2026-11-28_11-04_boot-0737ecd7-evidence-pull.md`
- `docs/agents/stability.md` row #66
- `docs/todo/stability.md` rows updated + 1 decision row; `TODO_LIST.md` NOW 5 and 8, queue lines
- `~/.cache/crash-20261128/` (triage, pstore copies, JSON dump, thermal and idle-check reads, TODO gate output)
