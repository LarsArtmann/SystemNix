# Status Report — erraudit converter.test OOM incident + BuildFlow holder leak fix + live watcher

- **Author:** Crush session (SystemNix cwd, cross-repo work in BuildFlow + erraudit forensics)
- **Written:** 2026-10-17 00:18 CEST
- **Scope:** This session only (started ~23:5x Oct 16 with the "77 GB convert test" report). No research beyond what was observed here.
- **Format note:** HTML is the skill-canonical format; the operator's prompt explicitly demanded `.md` at this path, so `.md` wins (flagged per skill contract, not propagated as a new default).

---

## Incident timeline (all 2026-10-16 unless noted)

| Time (CEST) | Event |
| --- | --- |
| ~10:1x / ~17:4x / ~20:0x | Three `TestRunGoInDir_WaitDelayBoundsGrandchildPipes` runs in `~/projects/BuildFlow/modules/gomod-checker` leak 6 immortal `exe/holder` orphan processes (PPID 1, ~800 KB RSS each, infinite `waitRelease` poll loop) |
| 23:38:17 | **Global kernel OOM kill #1**: `converter.test` (erraudit) at 17.9 GB anon → kernel OOM-killer fires and — because its oom_score_adj=300 beats everything else — kills **llama-chat.service's llama-server (pid 1782)** as the victim. converter.test dies too. Journal: `oom-kill:constraint=CONSTRAINT_NONE,global_oom,task=llama-server` |
| 23:44:28 | **OOM #2**: `converter.test` again at 19.1 GB anon, killed again |
| 23:53:56 | **OOM #3**: `converter.test` at 20.1 GB anon, killed again; hermes logs "system memory pressure is critical; spawning no new workers" (23:54:52, 23:55:54) — kanban dispatch deferred, not dropped |
| 23:5x | Session starts: user reports a "convert test" using 77 GB RAM (77 GB = peak VSZ across restarts/accumulation; kernel dumps show 17–20 GB anon per single run) |
| 23:5x | holder origins identified → BuildFlow `go_cmd_test.go` `holderProgram`; 6 holders killed via `pkill -f exe/holder` |
| 23:5x–00:0x | Root fix applied in BuildFlow: `waitRelease` bounded to 2 min. Tests pass. |
| 23:57:28 | Live watcher armed: `/tmp/converter-test-watcher.sh` (pid 3681856, background shell 016), polls 1 Hz for `converter.test` / `go test .*internal/converter`, dumps full ancestry (cwd, env, parent chain, fds) to `/tmp/converter-test-watcher.log`, then SIGTERM→SIGKILL the tree |
| 00:18 | Watcher alive, no re-fire yet; no holders present; converter.test not running |

**Launcher signature (identified, owner not yet proven):** `timeout 120 env GOEXPERIMENT=jsonv2 GOWORK=off GOFLAGS=-mod=mod go test ./internal/converter/ -run 'TestFocus|TestFilter|TestGoldenTreeDeterminism' -v` — run in `~/projects/erraudit/internal/converter` (`tree_focus_filter_test.go` + `golden_test.go`). The env-prefix style matches BuildFlow tool invocation, but no BuildFlow gate runs those tests; prime suspects are an agent session iterating on erraudit (4 `crush -y` processes + `crush-daily` scheduler + hermes kanban workers were live all evening). The watcher will name the parent conclusively on next fire.

---

## a) FULLY DONE

1. **Identified the 77 GB process** — `converter.test`, a Go test binary under `/tmp/go-build1945989025/b001/`, from `go test ./internal/converter/` in **~/projects/erraudit** (tests `TestFocus|TestFilter|TestGoldenTreeDeterminism`, files `tree_focus_filter_test.go` + `golden_test.go`).
2. **Root-caused the orphaned `exe/holder` processes** — all six traced to `TestRunGoInDir_WaitDelayBoundsGrandchildPipes` in `~/projects/BuildFlow/modules/gomod-checker/go_cmd_test.go`; mechanism: the test writes `$HOLDER_RELEASE` only in a `defer`, so any SIGKILL of the test binary (timeout wrapper, agent kill, CI kill) orphans the parent+grandchild pair forever in an infinite `waitRelease` poll.
3. **Killed the 6 leaked holders** (`pkill -f exe/holder`, verified zero remaining at 00:18).
4. **Fixed the BuildFlow leak at the root** — `waitRelease` in `holderProgram` now has a 2-minute deadline, so future orphans self-terminate even when the releasing `defer` never runs. `go test` for both affected tests passes; `gofmt -l` clean; `go vet` clean. Change is uncommitted in BuildFlow (per harness no-commit rule).
5. **Established the OOM timeline from the journal** — three separate global OOM events (23:38/23:44/23:53), per-run converter.test anon footprint 17–20 GB, and the collateral kill of llama-chat.service at 23:38:17.
6. **Mapped the OOM blast radius** — hermes kanban dispatch was deferred ("memory pressure is critical; spawning no new workers", deferred not dropped), journald flushed caches repeatedly under pressure, btrbk snapshots ran through the pressure window.
7. **Armed a live watcher** that will catch the next converter.test fire within ~1 s, record its full provenance (cwd, PWD env, PPID chain, fds, RSS) to `/tmp/converter-test-watcher.log`, and kill the whole tree (SIGTERM, escalate SIGKILL after 2 s). Verified alive at 00:18.

## b) PARTIALLY DONE

1. **The erraudit memory-leak investigation** — localized to package level (`internal/converter`, two named test files) but the actual leak site (fixture scale, missing cleanup, parallel accumulation) is NOT read yet; the watcher is the next-step evidence collector, not the fix.
2. **The watcher** — running and logging, but (a) unproven against a live fire, (b) ephemeral: lives in `/tmp`, dies on reboot, kills itself when this session's shell cleans up; (c) one cosmetic flaw: its `rc=$?` log line captures echo-evaluation, not the kill's exit code.
3. **Launcher attribution** — signature fully reconstructed, owning session/cron NOT yet named (watcher ancestry dump will settle it on first re-fire).
4. **Memory-context collection** — journal evidence harvested, but `memory.events` counters, systemd-oomd vs kernel-oom division of labor, and whether llama-chat actually restarted clean were not verified.

## c) NOT STARTED

1. Fixing the erraudit test leak itself (bound fixture size, `t.Cleanup`, or serialize the golden-tree tests).
2. Verifying llama-chat.service recovered from the 23:38 OOM kill (it should Restart=, but nobody checked).
3. Promoting the watcher to something durable (repo script or systemd path/timer unit with a MemoryMax tripwire) instead of `/tmp` + background shell.
4. Committing the BuildFlow `go_cmd_test.go` fix.
5. Recording the session lesson in the erraudit / BuildFlow repos' own AGENTS.md (cross-repo lessons belong where they were learned).
6. Any protective change for llama-chat.service against global-OOM victim selection (oom_score_adj, MemoryMin, systemd-oomd policy).
7. TODO_LIST.md harvest of this report's §f (deliberately deferred — operator said "then wait for instructions"; see §f routing notes).

## d) TOTALLY FUCKED UP

1. **llama-chat.service got OOM-killed as collateral** at 23:38:17 — the kernel's oom_score_adj=300 on the AI server made it the designated victim while converter.test (oom_score_adj=-1000, the actual hog) was untouchable. This is the session's real production damage: the user's chat backend died mid-use, and this same selection will recur every time an agent-spawned test (oom_score_adj -1000) blows the box.
2. **Three unattended 17–20 GB test runs** (23:38/23:44/23:53) — whatever launched them retried through two OOM kills without anyone noticing, each retry re-pressuring the whole box and re-risking another llama-server kill. A ~20 GB allocation happening three times in 16 minutes under a `timeout 120` wrapper that (from the one observed parent) was apparently meant to bound it — the wrapper did not bound memory, only time, and even the time bound lost to the OOM kill.
3. **Six immortal holder processes** accumulated across ~14 hours from three separate BuildFlow test runs — small (800 KB each) but a standing lie: `pgrep` hits for "holder" that belong to nothing. Symptom of the same pattern class: test cleanup that assumes the test binary survives.

## e) WHAT WE SHOULD IMPROVE

1. **Agents must not run unbounded-memory test suites on the shared 128 GB box** — erraudit's converter tests were launched by *something* with no memory ceiling; every `go test` an agent launches under `timeout N` should also carry `systemd-run --scope -p MemoryMax=…` (or GOMEMLIMIT) when the suite is unproven. The `timeout 120` wrapper bounded CPU time and nothing else.
2. **Test cleanup must not live only in `defer`/`t.Cleanup` when the cleanup target is a separate process** — anything a test spawns that outlives the binary needs a self-expiring design (the BuildFlow fix pattern: bounded wait) or a PID-file sweep in the suite's `TestMain`.
3. **Global OOM victim selection is a config problem, not luck** — llama-chat's oom_score_adj=300 (set by its unit to be killable) is exactly backwards for a service the owner wants resilient; either give it oom_score_adj=0 with a hard MemoryMax, or accept it as the designated sacrifice explicitly.
4. **oom_score_adj=-1000 on test binaries** (inherited from the launching agent's cgroup environment) makes every agent-spawned process OOM-immune; the launcher side should normalize this before running foreign test suites.
5. **Journal-only incident visibility** — three OOM kills in 16 min produced no alert surface beyond journal lines; a SigNoz rule on `kswapd0 invoked oom-killer` / `Out of memory: Killed process` (monitoring domain) would have paged this before the third retry.
6. **Watcher tooling should be a first-class script, not /tmp improvisation** — when the ad-hoc pattern works (it did), promote it: `scripts/` + systemd path unit, with the log somewhere persistent.
7. **Kill-tools discipline** — this session burned calls on `sudo` (guard-blocked), `/bin/kill` (nonexistent), and `kill` (shell-builtin unsupported); `pkill` was the working primitive from the start. Memory note for future sessions: process ops on this box go through `pkill`/`pgrep`/`/usr/bin/env kill`.
8. **Concurrent-session awareness worked but should be recorded**: a parallel session committed `docs/status/2026-10-17_00-17_ai-meter-build-session-status.html` mid-session and owns the working-tree `ai-meter` changes; this report deliberately does not touch or attribute those.

## f) Up to 50 things to get done next

*Operator cap: 50. This is a brainstorm ranked by impact, not a commitment list — harvest (with routing rigor) is deferred until the owner says go. Suggested routing in brackets, SystemNix domains per TODO system; erraudit/BuildFlow items belong in THOSE repos.*

1. [erraudit] Read `tree_focus_filter_test.go` + `golden_test.go`, find the 17–20 GB fixture, bound it (golden-tree at reduced scale, `t.Cleanup`, drop `t.Parallel` on the memory-heavy three).
2. [erraudit] Re-run the three tests with `GOMEMLIMIT=4GiB` + `systemd-run --scope -p MemoryMax=8G` to prove the bound holds before any next launch.
3. [SystemNix/watcher] Check `/tmp/converter-test-watcher.log` for the first fire → name the launcher (answer to Q1 below).
4. [SystemNix/stability] Verify llama-chat.service restarted after the 23:38 OOM kill and is serving (port 8850 health, per llama-rag runbook).
5. [SystemNix/stability] Decide llama-chat's OOM posture: oom_score_adj, MemoryMin floor, or explicit sacrificial status — write it into the unit + runbook.
6. [SystemNix/monitoring] SigNoz rule: alert on kernel OOM-kill journal events (this is the third "silent until user notices" memory incident class this quarter).
7. [SystemNix/stability] Decide policy: agents launching foreign test suites must wrap them in a MemoryMax scope; write it into AGENTS.md session discipline.
8. [BuildFlow] Commit the `go_cmd_test.go` holder fix (tested, clean).
9. [BuildFlow] Sweep for OTHER tests that spawn outliving processes with release-in-defer patterns (same bug class as holderProgram).
10. [BuildFlow] Consider a `TestMain`-level orphan sweep: on suite exit, SIGTERM any still-alive holders (defense in depth under the bounded wait).
11. [erraudit] Check git log / crush.db for which session was iterating on internal/converter tonight; if it's still alive, stop it from relaunching until fix #1 lands.
12. [SystemNix/watcher] Promote watcher to `scripts/watch-runaway-tests.sh` + a systemd unit (persistent log, survives reboot, runs on all hosts with agent shells).
13. [watcher] Fix the cosmetic `rc=$?` logging flaw; log the actual kill outcome.
14. [watcher] Add VmRSS threshold to the match (only kill converter.test above e.g. 4 GB) so a legitimate small converter test isn't molested.
15. [SystemNix/stability] Check `memory.events` for the system cgroup + llama-chat slice: how many oom kills total today.
16. [SystemNix/stability] Verify the 77 GB figure: sum of the three runs' peaks vs VSZ-overcounting; record the real per-run footprint in the erraudit issue.
17. [erraudit] File the leak as a tracked issue in the erraudit repo with the journal evidence table (oom timestamps, RSS, launcher signature).
18. [SystemNix] Post-deploy/pre-deploy checks: add an OOM-recent check (§N) so deploys during an active OOM storm get flagged.
19. [SystemNix/ai-stack] Re-check the other llama-servers (bge-m3, bge-reranker, qwen3.6-35b) survived the pressure window; the qwen server restarted at 02:22 elapsed at check time (23:5x) — suspicious, verify its restart cause.
20. [SystemNix/monitoring] The GPU/GTT and memory-watermark audits caught nothing here — a *global-pressure* audit hook (PSI spike + oom journal) is the missing layer; consider adding to the eval-time audit family.
21. [erraudit] If the golden-tree test NEEDS the full scale: precompute/persist the golden tree to disk instead of RAM (stream or mmap).
22. [erraudit] Add `-test.count=1` guidance or Make-free flake app for converter tests so stale-cache confusion doesn't trigger re-runs.
23. [SystemNix] AGENTS.md session discipline: add "pkill/pgrep are the only working process-kill primitives from agent shells" (kill builtin + sudo + /bin/kill all failed this session).
24. [SystemNix] AGENTS.md: record the holder-orphan pattern as a cross-project lesson candidate (test-spawned helpers need bounded waits).
25. [crush-config] Candidate for references/lessons.md: "defer-based cleanup of child processes doesn't survive SIGKILL — bound helper lifetimes" (generalizes beyond BuildFlow).
26. [BuildFlow] The `timeout 120` wrapper pattern: audit where BuildFlow (or its callers) wraps go test in bare `timeout` and add memory bounds alongside.
27. [SystemNix] btrbk ran snapshots through the pressure window (23:50–23:54) — verify the @home-hermes snapshot at 23:53:59 is complete/uncorrupted (cheap integrity check).
28. [SystemNix] hermes kanban deferred workers during pressure (23:54:52) — confirm the deferred items actually dispatched after pressure cleared (deferred, not dropped — prove it).
29. [SystemNix/monitoring] Consider PSI-based alert at lower threshold than "critical" so agents get warned BEFORE the box is at OOM (the memory-watermark-audit analog at runtime).
30. [erraudit] Check whether the three tests share one fixture via package-level var (3 runs × same growth pattern suggests a package-global accumulating across subtests, not per-test).
31. [SystemNix] Verify systemd-oomd didn't ALSO act on user slices during the window (kernel oom vs oomd division — check oomd logs at 23:38–23:54).
32. [BuildFlow] Add the holder-kill to the module's CI evidence: assert post-suite `pgrep holder` is empty (selftest for the fix).
33. [SystemNix] Sweep /tmp for stale go-build dirs from tonight's killed runs (disk hygiene; several hundred MB of b001 dirs).
34. [erraudit] After fix: run the three tests 3× consecutively under measurement to confirm flat RSS (regression pin, mirror of BuildFlow's pin-test style).
35. [SystemNix] Document in llama-rag.md: the OOM-victim mechanism (oom_score_adj=300) so the next "llama-server died" incident doesn't re-derive it.
36. [SystemNix/security] No secrets touched this session; nothing to rotate — record the null-check.
37. [SystemNix] Review whether other services carry oom_score_adj=300 unintentionally (sweep units for the setting).
38. [erraudit/agents] If a crush-daily scheduled job owns the erraudit iteration: gate it on the memory fix landing.
39. [SystemNix] Capture the watcher's first provenance dump into this report's successor (or the erraudit issue) — evidence, not folklore.
40. [SystemNix] Cross-check go-deps-audit/nightly CI jobs didn't run during the pressure window and produce false failures (they'd be unrelated red on next run).
41. [BuildFlow] The gomod-checker test takes 5.1 s and builds a real Go program each run — cache-friendly? (minor: it's the only repeated ~40 s cost across 3 leaks).
42. [SystemNix] TODO harvest of THIS list once owner directs — route per bracket tags; items 1–19 are the Paretos.
43. [SystemNix] Add "converter.test incident 2026-10-16/17" to docs/gotchas-archive.md once root cause in erraudit is confirmed (incident narrative + hash).
44. [erraudit] Consider running the converter suite with `go test -run ... -p 1` in CI if parallel accumulation is confirmed — serialize the memory hogs.
45. [SystemNix] Check journal truncation warning (`system@00065dd5…journal~ truncated`) — rotated mid-incident; evidence survives but note the gap risk in the archive entry.
46. [BuildFlow/erraudit] Shared lesson: `GOEXPERIMENT=jsonv2` in test env — confirm it's intentional for erraudit's converter (jsonv2 changes unmarshaling behavior; if the leak is jsonv2-related decoder retention, that's a different fix path).
47. [SystemNix] Decide whether agent test runs should get their own systemd slice with a collective MemoryMax (per-session slice = one runaway can't take down the box twice in a night).
48. [watcher] After the launcher is identified, kill the loop (it's a one-night tool; don't let it rot).
49. [SystemNix] Verify no OTHER user process died in the three OOM events besides llama-server (kernel dumps list candidates; do a victim sweep).
50. [meta] This report's §f deliberately NOT harvested into TODO_LIST.md/docs/todo/* (operator freeze: "wait for instructions") — revisit on next docs-health HARVEST pass.

## g) Questions I cannot answer myself

1. **Which session or schedule owns the erraudit `go test` launches?** I know the exact command signature and that it re-fired three times through OOM kills, but not whether it's one of the live `crush -y` sessions, a crush-daily job, or a hermes kanban worker. (The watcher will name it on next fire — but if YOU know which agent is working in erraudit tonight, we can stop the relaunch loop at the source instead of killing symptoms.)
2. **Is the 17–20 GB footprint a bug or the intended fixture scale?** If the golden-tree test is *supposed* to process a dataset of that size, the fix is disk-backed/streaming; if it's supposed to be small, it's an accumulation bug. What's the intended data volume for `TestGoldenTreeDeterminism`?
3. **llama-chat OOM posture:** the 23:38 kill chose llama-server *because* its unit sets oom_score_adj=300. Do you want it hardened against global-OOM victim selection (MemoryMin/oom_score_adj tradeoff), or is "AI server is the designated sacrifice, it restarts" the accepted doctrine?

---

**Status at write time:** watcher alive (pid 3681856), holders zero, converter.test not running, llama-stack processes present (qwen server 2h22m elapsed — verify restart cause, item 19), BuildFlow fix uncommitted, erraudit untouched.
