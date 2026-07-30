# Monitor365 CPU Hotfix + Flake Input Normalization

**Date:** 2026-07-29 14:55
**Session scope:** Diagnose monitor365 high CPU, fix root cause, normalize LarsArtmann flake inputs to `ref=master`

---

## a) FULLY DONE

1. **Root cause identified (295% CPU on monitor365 agent):** The cloud sync loop's early-flush optimization bypassed the backoff sleep whenever the segment buffer had ≥200 pending events (`flush_event_threshold`). With a massive backlog and the circuit breaker open (1.15M consecutive failures), every operation (upload, sync, config fetch) short-circuited in microseconds. The loop busy-spun at ~16Hz, consuming ~3 CPU cores for 22+ hours straight.

2. **Upstream fix implemented and tested (`monitor365` commit `750ff4c10`):** Extracted `should_early_flush(healthy, pending, threshold)` — early-flush only fires when sync is healthy AND buffer is at threshold. When sync is failing (`consecutive_sync_failures > 0`), the loop always sleeps the full backoff duration. Added 3 unit tests covering: healthy+full, healthy+below-threshold, failing+huge-backlog (the regression guard). All tests pass under `nix develop`.

3. **SystemNix flake inputs normalized to `ref=master`:**
   - `monitor365`: Was pinned to `06153013945baa16d83a81bd7497433537235240` (hardcoded commit hash). Now `ref=master`.
   - `go-commit`: Was pinned to `refs/tags/v0.4.0`. Now `ref=master`.
   - `flake.lock` updated for both inputs. `nix flake check --no-build` passes. `nix eval` of `evo-x2` toplevel passes.

---

## b) PARTIALLY DONE

1. **The CPU fix is NOT deployed and NOT pushed.** Commit `750ff4c10` exists only in the local `/home/lars/projects/monitor365` repo. The SystemNix `flake.lock` resolved to `8ac70ec13` (the last commit on `origin/master`), which is **pre-fix**. The monitor365 agent (PID 589624) is **still burning 295% CPU right now** (confirmed at 14:55, 23h47m elapsed). Deploying requires: (1) push the commit to GitHub, (2) `nix flake lock --update-input monitor365`, (3) `nix run .#deploy`, (4) `systemctl restart monitor365.service` to clear the in-memory circuit breaker.

2. **The libspa-sys build risk is unverified.** The original SystemNix pin to `0615301` was deliberate — `5ee717e3+` introduced `[patch.crates-io] libspa-sys = { path = "vendor-patches/libspa-sys" }` which produces empty bindgen output in the Nix sandbox (699 compilation errors). This `[patch.crates-io]` override is **still present on `origin/master`**. The `nix flake check --no-build` only validates Nix evaluation, NOT Rust compilation. A full `nix build .#monitor365` was started but killed before completion. **The Nix build may fail** when the lockfile eventually resolves to a commit with the broken bindgen path.

3. **go-commit unpin unverified.** The v0.4.0 tag pin was deliberate (AGENTS.md documents: "master source had a git config scope bug"). The lockfile resolved to `fd9a9664` (Jul 28). I did NOT verify whether this commit contains the `DefaultChainFromEnv()` fix (`d1d013d2`). If the fix is absent, PMA's auto-commit daemon will silently fail again.

---

## c) NOT STARTED

1. **Secondary root cause investigation — WHY is the circuit breaker open?** The server logs show `GET /api/v1/devices/evo-x2/config` returns **404** (device not registered) and `GET /api/v1/enrollment` returns **429** (rate-limited). The agent has been unable to sync for 22+ hours. The CPU fix stops the busy-loop, but sync will still fail — the device registration/enrollment problem is uninvestigated and unresolved.

2. **Immediate CPU mitigation.** The monitor365 agent could be restarted right now (`systemctl restart monitor365`) to clear the in-memory circuit breaker and reset the failure counter. Even without the code fix deployed, a restart would temporarily stop the CPU burn (until the CB opens again from the next sync failure).

3. **AGENTS.md documentation update.** The gotcha table entries for the monitor365 libspa-sys pin and go-commit v0.4.0 pin still describe the old pin rationale. They should be updated to reflect the `ref=master` switch and document the libspa-sys build risk if it materializes.

---

## d) TOTALLY FUCKED UP

1. **Started an unnecessary `nix build .#monitor365`** that ran for minutes before the user pointed out monitor365 "already runs." Wasted time and build resources on a verification step that wasn't needed for the task.

2. **Changed go-commit from a deliberate safety pin to `ref=master` without verifying the fix landed.** The AGENTS.md explicitly documents why the pin existed: `mkPreparedSource` overrides go.mod with the flake input source, so a master commit with the `DefaultChain()` bug would re-introduce the silent auto-commit failure. I should have checked the commit history BEFORE unpinning.

3. **Changed monitor365 to `ref=master` without verifying the Nix build works.** The libspa-sys bindgen issue was the explicit reason for the pin. `nix flake check --no-build` does NOT catch this — it only evaluates Nix, not Rust. The build may break on the next deploy.

4. **Never pushed the fix.** The entire point of the session was to fix monitor365's CPU usage. The fix exists only locally. The running service is unchanged. The CPU is still at 295%.

---

## e) WHAT WE SHOULD IMPROVE

1. **Investigate the 404/429 before deploying the CPU fix.** The CPU fix is a band-aid for the busy-loop; the actual problem is that sync can't reach the server. Deploying the fix without fixing the registration issue means the agent will back off correctly but still collect 0 data.

2. **Verify Nix builds after changing flake inputs.** `--no-build` is insufficient for Rust crates with bindgen/C dependency issues. Always run a full `nix build` before changing pins on repos with known native-dependency problems.

3. **Push before updating lockfiles.** The flake.lock can only resolve to pushed commits. Changing a pin to `ref=master` and running `nix flake lock` is a no-op if the fix isn't pushed yet.

4. **Immediate mitigation over perfect fixes.** The agent has been burning 3 CPU cores for 23 hours. A `systemctl restart monitor365` would have stopped the bleeding immediately while the code fix was being prepared.

5. **Read the AGENTS.md pin rationale BEFORE removing pins.** Every pin in `flake.nix` has a comment explaining WHY it exists. Removing the pin without addressing the documented reason is cargo-culting.

---

## f) Up to 50 Things to Do Next

### Critical (blocking — do first)
1. Push monitor365 commit `750ff4c10` to `origin/master`
2. `nix flake lock --update-input monitor365` to pick up the pushed fix
3. Verify `nix build .#monitor365` succeeds (libspa-sys bindgen risk)
4. If build fails: either fix the bindgen issue upstream OR restore the `0615301` pin with a merged-forward source
5. Deploy: `nix run .#deploy`
6. Restart monitor365 agent: `systemctl restart monitor365.service` (clears in-memory circuit breaker)
7. Verify CPU drops: `ps -p <pid> -o %cpu`
8. Verify go-commit `fd9a9664` contains the `DefaultChainFromEnv()` fix (`d1d013d2` or later)

### High Priority (sync root cause)
9. Investigate why `GET /api/v1/devices/evo-x2/config` returns 404 — device not registered on server
10. Investigate why `GET /api/v1/enrollment` returns 429 — rate limiter too aggressive?
11. Check if the monitor365 server's device table has `evo-x2` registered
12. Check if the agent's API key matches the server's tenant key (sops secret desync?)
13. Check DuckDB for device records: `SELECT * FROM devices WHERE device_id = 'evo-x2'`
14. Check if `monitor365-schema-migrate` ran successfully (the `max_events_per_day` UPDATE)
15. Verify the 597M event backlog is draining (if sync ever recovers)
16. Check if the server's rate limiter needs tuning for local agent traffic

### Medium Priority (hardening)
17. Add a Gatus alert for monitor365 agent CPU usage (alert when >50% for 5min)
18. Add a Gatus alert for monitor365 circuit breaker state (alert when open >1h)
19. Add an upstream metric: `cloud_sync_busy_loop_detected` (detect when CB open + buffer full)
20. Add systemd `CPUQuota=` to monitor365.service as defense-in-depth (e.g. 200%)
21. Consider a watchdog that restarts the agent when CPU >100% for >10min
22. Add upstream test: integration test that simulates CB-open + full buffer and asserts backoff sleep
23. Document the circuit breaker + early-flush interaction in monitor365's architecture docs
24. Add `monitor365 agent health` CLI command that reports CB state, buffer size, last sync time

### Flake Hygiene
25. Audit ALL LarsArtmann flake inputs for unnecessary pins (search for hardcoded commit hashes)
26. Audit all `refs/tags/*` pins — verify the fix has landed on master before unpinning
27. Consider a CI check that builds all LarsArtmann-dependent packages on input bumps
28. Document the libspa-sys bindgen issue status (fixed upstream or still broken?)
29. If libspa-sys is still broken: file an upstream issue tracking the bindgen sandbox failure
30. Add `vendorHash = ""` dry-run procedure to AGENTS.md for monitor365 vendor changes
31. Verify all `inputs.*.follows` chains are correct after the input changes

### Documentation
32. Update AGENTS.md monitor365 libspa-sys gotcha: "unpinned to master, build verified on <date>"
33. Update AGENTS.md go-commit gotcha: "unpinned to master after verifying fix"
34. Add AGENTS.md gotcha: "circuit breaker + early-flush busy-loop" root cause + fix
35. Add AGENTS.md gotcha: "always restart service after deploying agent fixes (CB is in-memory)"
36. Document the `should_early_flush` function and its rationale in cloud_sync.rs

### Monitoring & Observability
37. Add Prometheus metric: `cloud_sync_circuit_breaker_state` (0=closed, 1=open, 2=half-open)
38. Add Prometheus metric: `cloud_sync_cpu_burn_detected` (boolean: CB open AND buffer > threshold)
39. Add Gatus check: monitor365 agent `/metrics` endpoint health (port 9191)
40. Add Gatus check: monitor365 server `/health` endpoint (port 3001)
41. Add Gatus check: monitor365 server device count >0
42. Add a system-health collector for monitor365 sync failure duration

### Upstream Improvements
43. Make circuit breaker `reset_timeout` configurable via remote config
44. Add exponential backoff to the enrollment endpoint (currently spams 429s)
45. Add server-side device auto-registration on first sync (eliminate the 404 → re-register cycle)
46. Consider increasing `failure_threshold` from 5 to 20 for cloud sync (5 is too aggressive)
47. Add a `--once` flag to the sync loop for testing/debugging
48. Add structured logging for circuit breaker state transitions (currently only `info!`)
49. Consider a separate circuit breaker for config fetch vs upload (config 404 shouldn't block uploads)
50. Add a dead-man's switch: if CB open for >24h, force restart the agent process

---

## g) Questions I Cannot Answer Myself

1. **Should I push the monitor365 commit to GitHub?** My instructions say "NEVER PUSH TO REMOTE unless explicitly asked." But the fix is useless unpushed — the flake.lock can't resolve to it, and the agent keeps burning 295% CPU. Do you want me to push it?

2. **Should I restart the monitor365 service NOW as immediate mitigation?** Even without the code fix deployed, `systemctl restart monitor365` would clear the in-memory circuit breaker and stop the CPU burn temporarily (until the CB opens again from the next sync failure). The root sync issue would remain unfixed. Do you want me to restart it now?

3. **Should I restore the libspa-sys pin if the Nix build breaks?** The `[patch.crates-io] libspa-sys` override is still on master and produced 699 bindgen errors in the Nix sandbox historically. If the build fails on deploy, should I restore the `0615301` pin and cherry-pick the CPU fix onto that commit, or fix the bindgen issue upstream first?

---

## Resolution (2026-07-30)

All resolved. The CPU busy-loop fix was pushed upstream (`f72cf1073`) and deployed in `2026-07-29_16-58`. The REAL sync root cause was NOT 404/429 — it was a server-side DuckDB COALESCE NULL crash (`b900d3454`) in the `version` column. The server crash-looped, causing the agent's circuit breaker to open → busy-loop. Fixing the server crash resolved the sync failures entirely. The `CPUQuota=200%` defense-in-depth was added to `harden()`. The libspa-sys pin was NOT needed — `[patch.crates-io]` builds fine on master. monitor365 + go-commit both unpinned to `ref=master` successfully.

---

## Item Resolution (2026-07-30)

Monitor365 CPU busy-loop. Items 1-10 DONE (fix pushed f72cf1073, deployed 16-58). Items 11-53 REJECTED. Real root cause was server COALESCE crash, not 404/429. Resolution section at end corrects the root cause.
