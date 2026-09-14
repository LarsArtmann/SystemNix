# Crash Analysis & Status Report — 2026-08-11 20:30 WDT Reset

**Date:** 2026-08-11 21:10 CEST
**Crash Time:** 20:30:05 CEST (boot -1 ended abruptly, boot 0 started 20:34:04)
**Crash Mode:** Hardware watchdog timer (sp5100-tco) reset — kernel freeze
**Previous Reset Reason:** `[0x02000800]: hardware watchdog timer expired`
**Current Boot:** 0:36 minutes, I/O PSI at 92% (critical)

---

## Executive Summary

The system crashed because **two services were in continuous crash loops for 40+ hours** on a **90%-full QLC NVMe drive**, generating sustained I/O that exhausted the SLC write cache, causing the kernel to freeze and the hardware watchdog to fire.

The fix for these crash loops was **committed at 14:18 today but never deployed** — the running system was built on Aug 7 (`f13ff45`). A deploy attempt at 20:57 failed due to a **vendorHash mismatch** in the upstream browser-history flake.

---

# FULLY DONE

1. **Root cause identified** — browser-history server crash-looping with `server.create_user_service` (exit 69) every ~35s since Aug 10 00:00. Agent crash-looping with 502 every ~18s. Combined: 3677 server crashes + 1335 agent crashes per boot.
2. **Crash mode confirmed** — sp5100-tco WDT reset (60s heartbeat). Journal ends abruptly with no shutdown sequence, no kernel panic, no OOM-kill. Classic kernel freeze.
3. **Upstream bug root-caused** — `usermgmt.NewService()` fails because projection host workers die on `SQLITE_BUSY` errors. Root cause: **SQLite DSN uses `mattn/go-sqlite3` params (`_journal_mode=WAL`, `_busy_timeout=5000`) but the project imports `modernc.org/sqlite`** which uses `_pragma=` syntax. WAL mode and busy timeout are **silently ignored**. With `MaxOpenConns(1)` and 6 projection workers sharing one connection, any lock contention returns immediate `SQLITE_BUSY` → fatal worker error → `WorkerFailed` after 5 restarts → `startProjectionHost` returns error → `create_user_service` wraps it → exit 69.
4. **Deploy attempted** — `nix run .#deploy` failed: `browser-history-server-f97aeb8-go-modules` vendorHash mismatch (specified `sha256-n5YB...` got `sha256-EEXC...`). Build aborted, old config still active.
5. **browser-history server stopped** — Hit systemd start-limit (`StartLimitBurst=3/60s`) at ~20:56. No longer crash-looping.

---

# PARTIALLY DONE

1. **Crash-loop protection (commit a1223f22)** — Code written and committed (`RestartSec=2min`, `StartLimitBurst=3/600s` for server; `RestartSec=5min`, `StartLimitBurst=2/1800s` + health-gate for agent). **NOT DEPLOYED** — build failed on vendorHash.
2. **Upstream browser-history investigation** — Identified the DSN bug, the missing `CheckpointStore`, the `MaxOpenConns(1)` bottleneck. **Fix not yet written.**
3. **I/O pressure analysis** — Identified 90% disk fullness + crash loops as the cause. Current I/O PSI at 92% — **system at risk of another crash**.

---

# NOT STARTED

1. **Fix the upstream browser-history DSN bug** — Replace `_journal_mode=WAL&_busy_timeout=5000` with `_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)` in `api/storage.go`
2. **Fix the upstream vendorHash** — Update `vendorHash` in browser-history flake.nix to `sha256-EEXC/fJbQTXRagF9R+hrT2PDEpYDq4JP2jJ7AmgLqZw=`
3. **Fix broken prometheus textfiles** — `niri.prom` has bare `0` lines (invalid metric names); `system_health.prom` has `[not set]` for discordsync and PMA memory (services not running / cgroup empty)
4. **Fix OTel URL parse error** — `parse "127.0.0.1:4317": first path segment in URL cannot contain colon` — needs `http://` scheme for gRPC endpoint
5. **Update AGENTS.md** with this crash pattern
6. **Bump browser-history flake input** in SystemNix after upstream fix
7. **Monitor365 DuckDB OOM** — Server hitting "1.8 GiB/1.8 GiB used" repeatedly. Memory limit too low or query patterns need tuning.
8. **Emergency disk cleanup** — 90% full (636G/723G) on QLC NAND is a crash risk factor

---

# TOTALLY FUCKED UP

1. **The crash-loop fix was committed 6 hours before the crash but NEVER DEPLOYED.** Commit `a1223f22` at 14:18 added `RestartSec=2min` and `StartLimitBurst=3/600s`. The crash happened at 20:30 — 6 hours and 12 minutes later. If the deploy had been run after the commit, the crash loops would have been throttled and the WDT reset would NOT have happened. **This is the single biggest failure.**

2. **The browser-history server has been broken since Aug 10 00:00 — over 40 hours.** 3677 crash cycles. Nobody noticed because the monitoring was also broken:
   - `niri.prom` has invalid metrics (node_exporter can't parse it)
   - `system_health.prom` has `[not set]` values (node_exporter can't parse it)
   - The Gatus "Memory Pressure" check was failing but the alert was just a Discord message that got lost in noise

3. **The deploy failed and I didn't verify it.** I started `nix run .#deploy` in the background, moved on to other investigation, and didn't check the result until prompted. The deploy failed on vendorHash mismatch — if I had checked sooner, I could have fixed the hash and re-deployed immediately.

4. **I investigated the upstream bug for 30+ minutes while the system was still actively crash-looping.** The agent was doing 17 failures per 5 minutes. I should have **stopped the crash loops FIRST** (by disabling the services or masking them), THEN investigated. Safety first — a crashing system is an emergency, not a research opportunity.

5. **The error logging in browser-history is fundamentally broken.** `errorfamily.HandleError()` calls `os.Exit()` which doesn't flush buffered log writers. The `logger.Error("server startup failed", "cause", errors.Unwrap(err))` call's output never reaches journald because the slog JSON handler buffers output and `os.Exit` kills the process before the flush. **Every crash just prints `Error: server.create_user_service` with no cause.** This made diagnosis 10x harder.

6. **The upstream SQLite DSN bug has been present since the project started using `modernc.org/sqlite`.** The `_journal_mode=WAL` and `_busy_timeout=5000` DSN parameters have NEVER worked. Every production deployment of browser-history has been running without WAL mode and without busy timeout. This is a latent corruption/performance bomb that only manifests under concurrent load (6 projection workers sharing 1 connection).

---

# IMPROVEMENTS

### Preventive

1. **Deploy after EVERY commit that fixes a crash-related issue.** A commit that's not deployed is a commit that doesn't exist. Add a CI check or git hook that warns when crash-loop protection changes are committed but the system generation hash doesn't change.

2. **Add a "crash loop detector" to system-health.** Count service restarts per 10-minute window. Emit a metric `system_service_crash_loop{service=X}` when restarts > threshold. Gatus alert on it. This would have caught the 3677-crash browser-history loop within 10 minutes.

3. **Add `systemd-analyze verify` to pre-deploy-check.sh.** Verify unit files for start-limit feasibility: if `RestartSec × StartLimitBurst < average runtime`, the service can bypass the start limit. The old config had `5s × 3 = 15s` but the service ran for 35s — the start limit was mathematically unreachable.

4. **Fix browser-history error logging upstream.** Either:
   - Flush the slog handler before `os.Exit` (`logger.Sync()` / `io.Sync()`)
   - Or use `fmt.Fprintf(os.Stderr, "%+v\n", err)` for the errorfamily verbose format before calling `HandleError`

5. **Add a `ConditionPathExists` or health-gate to browser-history-agent.** The agent should not start if the server isn't healthy. The health-gate exists in the module (commit a1223f22) but isn't deployed.

6. **Increase Monitor365 DuckDB memory limit.** "1.8 GiB/1.8 GiB used" is too tight for the analytical queries the server runs. Either raise the DuckDB `memory_limit` or reduce concurrent background tasks.

### Monitoring

7. **Fix niri.prom generation.** The script outputs bare `0` values as separate lines. Need to prefix them with metric names or suppress empty output.

8. **Fix system_health.prom generation.** When `MemoryCurrent` is empty (service not running), output `0` or skip the metric entirely — never output `[not set]`.

9. **Add disk usage alert.** 90% on QLC NAND should alert at 85%. The SLC cache shrinks as the drive fills, making crashes more likely.

10. **Add I/O PSI alert.** Current I/O PSI is 92% — this should be a Gatus alert. The `psi-metrics` service already collects the data but there's no Gatus check on it.

---

# NEXT 50 THINGS (Priority Order)

### Immediate (do NOW — system at risk)

1. Stop browser-history-agent crash loop (it's still going — 54 restarts, ~18s cycle)
2. Fix upstream browser-history vendorHash → re-deploy SystemNix → activate crash-loop protection
3. Investigate current 92% I/O pressure — is the system about to crash again?
4. Check if nix build leftover processes are causing I/O pressure

### Short-term (today)

5. Fix upstream browser-history DSN bug (`_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)`)
6. Add persistent `CheckpointStore` to browser-history `ServiceConfig` to avoid full replay on every restart
7. Fix upstream browser-history error logging (flush before `os.Exit`)
8. Bump browser-history flake input in SystemNix
9. Deploy working browser-history (no more crash loop)
10. Fix niri.prom textfile collector (bare `0` lines)
11. Fix system_health.prom textfile collector (`[not set]` values)
12. Add I/O PSI Gatus health check
13. Add disk usage Gatus health check (alert at 85%)
14. Free disk space (nix-collect-garbage, trash old generations)
15. Check Monitor365 DuckDB memory limit — raise if needed

### Medium-term (this week)

16. Add crash-loop detector metric to system-health collector
17. Add `systemd-analyze verify` start-limit feasibility check to pre-deploy-check.sh
18. Deploy the "deploy after crash-fix commit" CI guard
19. Fix OTel URL parse error in browser-history (add `http://` scheme)
20. Review ALL services for start-limit feasibility (`RestartSec × StartLimitBurst < avg runtime`)
21. Audit all crash-loop-capable services for proper backoff
22. Add browser-history SQLite integrity check on startup
23. Consider switching browser-history from `modernc.org/sqlite` to `mattn/go-sqlite3` (or vice versa) for DSN consistency
24. Review Monitor365 background task concurrency (pool acquire failures)
25. Add Gatus alert for browser-history server health (not just agent)
26. Review if the 128GB→93GB RAM gap is expected (GPU allocation?) or a BIOS misconfiguration
27. Add emergency disk space cleanup script (`nix-collect-garbage -d`, trash journals older than 7d)
28. Review BTRFS balance schedule — metadata ENOSPC could recur with 90% fullness
29. Check if daily fstrim is actually running (last seen Aug 11 00:35)
30. Add WDT reset counter to system-health metrics (count reboots per day)

### Long-term (this month)

31. Add integration test for browser-history startup (catch DSN bugs before deploy)
32. Consider SQLite WAL mode + busy_timeout for ALL Go services using SQLite (audit discordsync, qmd, etc.)
33. Add `nix flake check` guard for vendorHash staleness (detect upstream dependency changes)
34. Review ALL upstream LarsArtmann flakes for the same DSN driver mismatch pattern
35. Add system-reboot detection to Gatus (alert if uptime resets)
36. Consider adding a kernel panic parameter (`panic=10`) to auto-reboot instead of WDT
37. Review BFQ I/O tier assignments — browser-history should be `ioTier.background` (it is in the module but undeployed)
38. Add a "system generation age" metric — alert if generation > 7 days old
39. Create a runbook for "system crashed" — step-by-step diagnostic procedure
40. Review if sp5100-tco heartbeat (60s) is appropriate — maybe increase to 120s for build-heavy workloads
41. Add deploy automation that blocks commits until the system generation matches HEAD
42. Consider a staging/canary deploy for crash-loop-prone services
43. Add health-check-based rollback (if service crash-loops after deploy, auto-rollback)
44. Review all `DynamicUser` services for StateDirectory isolation correctness
45. Add a "service restart budget" metric — total restarts across all services per hour
46. Consider using `systemd-oomd` `DefaultMemoryPressureDurationSec` for faster OOM response
47. Add a "QLC NAND health" dashboard (SLC cache size estimation, write amplification tracking)
48. Review if `commit=300` is still appropriate with 90% disk fullness
49. Document the browser-history DSN bug in the upstream repo's AGENTS.md
50. Celebrate — the system is stable, the bug is fixed, the monitoring catches it next time

---

# 3 QUESTIONS

1. **Why was the crash-loop fix (commit a1223f22, 14:18) never deployed?** The system was running a generation from Aug 7 (`f13ff45`). Was the deploy forgotten, did it fail silently, or was it intentionally deferred? The commit message says "prevent browser-history crash loop from triggering WDT reset" — it was written specifically to prevent this crash, but the prevention never reached the running system.

2. **Why has the browser-history SQLite DSN bug gone unnoticed for so long?** The project uses `modernc.org/sqlite` but the DSN has `mattn/go-sqlite3` parameters (`_journal_mode=WAL`, `_busy_timeout=5000`). These are **silently ignored**. Every production deployment has been running without WAL mode and without busy timeout. Was this a copy-paste from a `mattn/go-sqlite3` project? Are there integration tests that verify SQLite journal mode?

3. **Is the 93 GiB total RAM (vs expected 128 GB) expected?** The AGENTS.md says "128GB RAM" but `free -h` shows 93 GiB total. The 35 GiB gap could be GPU allocation (AMD Ryzen AI Max+ 395 with configurable VRAM), but it significantly reduces the memory headroom for a system running ~30 services. Was this a deliberate BIOS configuration?
