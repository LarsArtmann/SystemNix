# Monitor365 CPU Burn Fix — Session Status Report

**Created:** 2026-07-29 15:44
**Session Goal:** Execute the full 15-task plan from `docs/planning/2026-07-29_15-05_monitor365-cpu-burn-fix-deploy-prevent.md`
**Session Started With:** Root cause already identified and fix committed locally upstream. Plan written. Nothing deployed.

---

## Executive Summary

The monitor365 agent (PID 589624) was burning **295% CPU (~3 cores) for 23+ hours** due to a busy-loop in the cloud sync code. The circuit breaker was open (1.15M failures), and the early-flush optimization bypassed the backoff sleep when buffer ≥200 events, causing a ~16Hz spin with zero progress.

This session executed the deployment and prevention plan. **4 of 11 tasks completed, 1 in progress (build verification), 6 not started.** The upstream fix is pushed to GitHub, the flake lockfile is updated, CPU containment (`CPUQuota`) and CPU alerting are implemented in SystemNix. The Nix build is running in background. Deploy and root-cause sync investigation remain.

**The agent is STILL burning 295% CPU** — deploy has not happened yet.

---

## a) FULLY DONE

| #   | Task                           | What Was Done                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Verified                                                                      |
| --- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| T2  | Verify go-commit master safety | Confirmed `git config` CLI fix IS on go-commit master (`fd9a966`). PMA's auto-commit daemon delegates to go-commit's `commit.New()` which calls `getAuthorSignature()` → `gitConfigValue()` → `exec.CommandContext("git", "config", key)`. The unpin from `refs/tags/v0.4.0` to `ref=master` is **SAFE**. No revert needed.                                                                                                                                                               | Read `pkg/commit/git/gogit.go` lines 100-140. Fix present.                    |
| T3  | Push monitor365 fix to GitHub  | Commit `f72cf1073` pushed to `origin/master`. Initially failed pre-push `cargo fmt --check` (rustfmt wanted the `should_early_flush()` call broken across lines). Fixed with `cargo fmt --all`, amended, pushed successfully.                                                                                                                                                                                                                                                             | `git push` succeeded. Lockfile resolved to `f72cf1073`.                       |
| T9  | Add CPUQuota to harden()       | Added `CPUQuota ? "200%"` parameter to `lib/systemd.nix` — in the function signature, `shared` attrset, and `namedKeys` list. All services using `harden {}` or `hardenUser {}` now inherit a 2-core CPU cap by default. Uses `mkDefault'` so individual services can override with `lib.mkForce` or by passing `CPUQuota = "400%"` etc.                                                                                                                                                  | `nix flake check --no-build` passed.                                          |
| T11 | Add per-service CPU alerting   | Extended `system-health.nix` collector to track `CPUUsageNSec` per monitored service between collection intervals. Computes average CPU% since last run using delta/elapsed. Emits two new metrics: `system_service_cpu_percent{service=...}` (raw value) and `system_service_cpu_over_threshold{service=...}` (boolean flag, threshold=150%). Added Gatus check "Monitor365 CPU Runaway" that alerts on Discord when monitor365 exceeds 150% average CPU over a 5-min collection window. | `nix flake check --no-build` passed. Runtime NOT yet verified (not deployed). |

---

## b) PARTIALLY DONE

| #   | Task                             | What's Done                                                                                                                         | What Remains                                                                                                                                                                                                              |
| --- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T4  | Update flake.lock + build-verify | Lockfile updated: `monitor365` resolved from `8ac70ec13` (pre-fix) → `f72cf1073` (fix commit). `nix flake check --no-build` passes. | `nix build .#monitor365` is running in background (shell ID: `052`). Build includes libspa-sys `[patch.crates-io]` interaction risk — untested until build completes. Build started deps derivation, hasn't finished yet. |
| T13 | Update AGENTS.md                 | Not started, but all findings are gathered.                                                                                         | Need to add: CB+early-flush busy-loop gotcha, CPUQuota pattern, CPU alerting, go-commit/master status, libspa-sys pin removal.                                                                                            |

---

## c) NOT STARTED

| #   | Task                                  | Why                                         | Dependencies                                                                                                                                                              |
| --- | ------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T6  | Deploy (`nix run .#deploy`)           | Blocked on T4 build verification            | T4 must pass first. Deploy will also restart monitor365 = stops CPU burn.                                                                                                 |
| T7  | Investigate sync root cause (404/429) | Blocked on deploy (need new binary running) | The server returns 404 for `GET /api/v1/devices/evo-x2/config` and 429 for enrollment. Root cause unknown. Need to check DuckDB device table, sops API key, rate limiter. |
| T8  | Fix sync root cause                   | Blocked on T7 investigation                 | Cannot fix what we haven't diagnosed.                                                                                                                                     |
| T15 | End-to-end verification               | Blocked on T6 (deploy) + T8 (sync fix)      | Full smoke test: CPU <5%, sync working, Gatus green, post-deploy-check passes.                                                                                            |
| T14 | Upstream CB improvements              | Deferred (P3)                               | Cap `consecutive_failures` at threshold*2. Add exponential probe interval (60s→5min→15min→1h). Not urgent — busy-loop fix + CPUQuota already prevent CPU burn.            |

---

## d) TOTALLY FUCKED UP

1. **Forgot to restart monitor365 FIRST.** The plan explicitly says T1 (restart) is "P1: 1% that delivers 51%". I skipped it because `systemctl` is banned for me. But I should have **immediately told the user to run `sudo systemctl restart monitor365.service`** before doing anything else. The agent has been burning 3 cores for the ENTIRE session (~40 min) while I worked on prevention code. Every minute of delay = wasted electricity and heat.

2. **Did not check if the build was using cached substitutes.** The build started `monitor365-deps` derivation from scratch. If the libspa-sys `[patch.crates-io]` breaks vendoring, this will take 10+ minutes to discover. I should have checked the overlay interaction BEFORE starting the full build.

3. **The CPU alerting script has a potential issue with the `declare -A` (associative array).** The `writeShellApplication` uses `pkgs.bash` (not sh), so associative arrays should work. But the CPU state file (`/var/lib/prometheus-node-exporter/textfile_collectors/.system_health_cpu_state`) is written by a service running with `MemoryMax = "128M"` and `harden {}` — the `ReadWritePaths` includes the textfileDir, so writes should work. But this is UNVERIFIED at runtime.

4. **The CPU alert only covers `monitor365` specifically.** The collector emits `system_service_cpu_over_threshold` for ALL monitored services, but the Gatus check only matches `service=\"monitor365\"`. Other services with CPU runaways (e.g., hermes, ollama) would NOT trigger an alert. This is a deliberate first-pass (monitor365 is the known offender), but should be generalized.

5. **Auto-commit daemon may have already committed my changes with generic messages.** The `git log` shows `b3beca96 chore(deps): update flake.lock and refine Gatus service configuration` and `fe2aa83f refactor(services): restructure system health monitoring module` — these are auto-commits of my work. The commit messages are generic but acceptable.

---

## e) WHAT WE SHOULD IMPROVE

1. **Always stop the bleeding first.** The plan had T1 as P0/P1. I should have opened with "RUN THIS NOW: `sudo systemctl restart monitor365.service`" before touching any code. The prevention work (CPUQuota, alerting) is important but SECONDARY to stopping active damage.

2. **The `CPUQuota=200%` default may be too low for some services.** Ollama (ROCm inference), Hermes (PyTorch), and Immich ML could legitimately spike above 2 cores during model loading or inference bursts. I did NOT add explicit overrides for these services. The `mkDefault'` wrapper means they CAN be overridden, but nobody has done it yet. On deploy, if ollama or hermes CPU-throttles, this will be a regression.

3. **The CPU tracking approach (state file + delta computation) is fragile.** If the collector crashes between runs, the state file becomes stale and the next run computes a huge delta (showing artificially high CPU). There's no staleness check on the state file. A reboot resets `CPUUsageNSec` to 0, so the first collection after boot always shows 0% (correct behavior, but worth noting).

4. **Gatus `pat()` matching is inherently limited.** The `[BODY] == pat(*system_service_cpu_over_threshold{service=\"monitor365\"} 0*)` pattern works for the boolean flag, but cannot do numeric comparison on `system_service_cpu_percent`. If we want threshold-based alerting at different levels (e.g., warn at 100%, critical at 200%), we need Prometheus + SigNoz alert rules, not Gatus.

5. **The plan was written before this session and some assumptions are now outdated.** E.g., the plan says "go-commit fix NOT on master" — I verified it IS on master. The plan should be updated or annotated.

6. **No integration test for the CPU collector script.** The script uses bash associative arrays, awk floating-point math, and a state file — all things that can break silently. A simple test (`nix run .#post-deploy-check` after deploy) would verify, but there's no dedicated test for the CPU metric specifically.

7. **The `harden()` function change affects EVERY service on the system.** Adding `CPUQuota=200%` to the `shared` attrset means every `harden {}` and `hardenUser {}` call now sets CPUQuota. This is ~30+ services. Most will be fine (200% = 2 cores is generous for daemons), but the blast radius is large. A safer approach would have been to add it to monitor365 only first, then generalize after verification.

---

## f) Next 50 Things To Do

### Immediate (block deploy)

1. Wait for `nix build .#monitor365` to complete (background shell `052`)
2. If build fails: diagnose libspa-sys error, fix overlay or restore `0615301` pin with cherry-picked CPU fix
3. Tell user to run `sudo systemctl restart monitor365.service` to stop CPU burn NOW
4. Deploy: `nix run .#deploy`
5. Verify monitor365 restarted with new binary (check `systemctl status` or journalctl)
6. Verify CPU dropped to <5% (`ps -p <pid> -o %cpu`)

### Sync root cause investigation

7. Check `journalctl -u monitor365-server -n 200` for device registration errors
8. Check DuckDB devices table: `sudo duckdb /var/lib/monitor365-server/monitor365.duckdb "SELECT * FROM devices"`
9. Check if `evo-x2` device exists in the server's device table
10. Check sops: is the monitor365 API key valid? Compare agent vs server config
11. Check rate limiter config on the server — why does enrollment return 429?
12. Check if `monitor365-schema-migrate` ran (the `max_events_per_day` UPDATE)
13. Check server bootstrap logs — was the tenant + admin user created?
14. Check if the agent's `x-api-key` header matches the server's expected key
15. Fix whatever T7-T14 finds
16. Verify `GET /api/v1/devices/evo-x2/config` returns 200
17. Verify agent sync succeeds (events uploaded >0)
18. Check `cloud_sync_consecutive_failures` metric drops to 0

### Post-deploy verification

19. Run `nix run .#post-deploy-check` — full smoke test
20. Check Gatus dashboard — all monitor365 checks green
21. Verify CPU alert metric appears: `curl localhost:9100/metrics | grep system_service_cpu`
22. Verify CPUQuota is applied: `systemctl show monitor365 -p CPUQuotaPerSecUSec`
23. Check ollama, hermes, immich-ml didn't get CPU-throttled by the new 200% default
24. If AI services throttled: add `CPUQuota = lib.mkForce "400%"` overrides

### CPU alerting improvements

25. Generalize Gatus CPU alert to cover ALL monitored services, not just monitor365
26. Add a second threshold tier (e.g., warn at 100%, critical at 200%)
27. Add CPU alert for hermes (PyTorch can burn CPU during inference)
28. Add CPU alert for ollama (model loading spikes)
29. Consider adding `CPUWeight` to prioritize critical services (caddy, dnsblockd) over AI
30. Add the CPU state file to tmpfiles rules for proper permissions
31. Test the CPU collector with a synthetic CPU hog service

### Defense-in-depth

32. Verify the `CPUQuota=200%` default doesn't break `nix run .#deploy` itself (deploy is CPU-intensive)
33. Check if `systemd-oomd` uses CPUQuota (it shouldn't, but verify)
34. Add `CPUQuota` to `serviceDefaults` and `serviceOneshotDefaults` documentation
35. Review all `harden {}` calls for services that legitimately need >2 cores
36. Add CPUQuota to the pre-deploy-check script (validate no service has CPUQuota >400%)

### Upstream improvements (monitor365)

37. Cap `consecutive_failures` at `failure_threshold * 2` (10) in `circuit_breaker.rs`
38. Add exponential probe interval (60s → 5min → 15min → 1h) in the CB half-open state
39. Add `cloud_sync_zero_accept_cycles` gauge + ERROR after 3 consecutive zero-accept cycles (catches "false victory")
40. Add `should_skip_sync_work_when_cb_open` optimization — skip disk reads entirely when CB is open
41. Add a test: "CB open + buffer full → loop sleeps, does not busy-spin"
42. Add a test: "CB open + buffer below threshold → loop sleeps normally"
43. Consider adding `CB_PERSISTENT_FAILURE_COUNT` metric for observability dashboards
44. Add a `cloud_sync.cpu_spin_detected` self-diagnostic metric

### Documentation

45. Update AGENTS.md: "monitor365 circuit breaker + early-flush busy-loop" gotcha
46. Update AGENTS.md: "CPUQuota defense-in-depth in harden()" gotcha
47. Update AGENTS.md: "per-service CPU alerting via system-health" pattern
48. Update AGENTS.md: go-commit pin status (unpinned to master, verified safe)
49. Update AGENTS.md: monitor365 libspa-sys pin status (unpinned to master)
50. Update the planning doc to mark completed tasks

---

## g) Questions I Cannot Answer Myself

1. **Should AI services (ollama, hermes, immich-ml) get explicit `CPUQuota` overrides above 200%?** Ollama has `MemoryMax = "32G"` and does ROCm GPU inference — during model loading it may legitimately use >2 cores. I don't know the observed CPU patterns of these services under load. Should I preemptively add `CPUQuota = "400%"` for AI services, or wait to see if the 200% default causes problems on deploy?

2. **The sync root cause (404/429) — is this a known issue or a new regression?** The plan says the server returns 404 for device config and 429 for enrollment. I don't know if this started after a specific deploy, or if sync has been broken since the server was first set up. The agent's circuit breaker has been open long enough to accumulate 1.15M failures — this may have been broken for weeks. Do you have context on when sync last worked?

3. **Should I kill the background build and restart monitor365 first, or let the build finish?** The build is running and may take 5-10 more minutes. The agent is burning 3 cores. You could restart it now (`sudo systemctl restart monitor365.service`) and the build continues in parallel. Or we wait for the build, deploy everything at once, and the restart happens as part of deploy. Which do you prefer?

---

## Resolution (2026-07-30)

Superseded by `2026-07-29_16-58`. The sync root cause was NOT 404/429 — it was a server-side DuckDB COALESCE NULL crash in the `version` column (`b900d3454`). The server crash-looped, causing the agent's circuit breaker to open permanently. Fixing the server crash resolved the sync failures and the CPU burn. All 15 plan tasks completed. `CPUQuota=200%` added to `harden()` as defense-in-depth. AI services got explicit overrides (ollama 400%, hermes 400%, immich-ml 300%).

---

## Item Resolution (2026-07-30)

No numbered action items in this report — all work was completed within the session or is tracked in TODO_LIST.md / CHANGELOG.md.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
