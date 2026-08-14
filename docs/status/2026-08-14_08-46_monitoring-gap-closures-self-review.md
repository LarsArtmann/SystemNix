# Status: Monitoring Gap Closures — Self-Review

**Date:** 2026-08-14 08:46
**Session goal:** Implement all 7 Priority 1 monitoring gaps from TODO_LIST.md
**Result:** 6 implemented, 1 already existed. All pass `nix flake check --no-build` + full eval. Several issues identified in self-review.

---

## A) FULLY DONE (Working + Verified)

### 1. `node_textfile_scrape_error` Gatus meta-check
- **File:** `gatus-config.nix` — "Textfile Collector Health" check
- **What:** Alerts when `node_textfile_scrape_error != 0` — catches invalid `.prom` files that silently drop ALL textfile metrics
- **Why it matters:** 14 Gatus checks went permanently RED because of this, and there was no meta-check to catch it
- **Verified:** `nix flake check --no-build` passes. Pattern `pat(*node_textfile_scrape_error 0*)` passes gatus-pattern-lint

### 2. Disk usage textfile metric + Gatus alert
- **Files:** `system-health.nix` (collector), `gatus-config.nix` (alert)
- **What:** `system_disk_usage_percent` + `system_disk_usage_over_threshold` (85% threshold) + "Root Disk Usage" Gatus alert
- **Why it matters:** Root filesystem at 90-93% was a chronic issue across 5+ reports with no proactive alerting
- **New module option:** `collectDiskUsage` (default true)

### 3. Crash-loop detector textfile metric + Gatus alert
- **Files:** `system-health.nix` (collector), `gatus-config.nix` (alert)
- **What:** `system_service_crash_loop{service=...}` per-service + `system_any_service_crash_loop` aggregate, tracking NRestarts delta per 2min interval (threshold 3 restarts). Gatus "Service Crash Loop" alert
- **Why it matters:** browser-history 520-restart loop and Twenty 235-restart loop went completely undetected
- **Added browser-history + browser-history-agent to `monitoredServices`** — they were missing entirely

### 4. PMA daemon health Gatus check
- **Files:** `gatus-config.nix` (check), `lib/ports.nix` (port)
- **What:** "PMA Daemon Health" check hitting `http://127.0.0.1:9190/readyz` (K8s-style readiness probe — 503 if auto-commit or discovery daemon fails). Conditional on `projects-management-automation.enable`. Added `pma-health = 9190` to `lib/ports.nix` for collision detection
- **Why it matters:** PMA daemon was failing silently — the 3 existing PMA Gatus checks only checked Prometheus textfile metrics (indirect), not the HTTP health endpoint

### 5. I/O PSI Gatus alert (ALREADY EXISTED)
- **File:** `gatus-config.nix` line 716-726
- **What:** "I/O Stall Rate" check was already present, alerting on `node_psi_io_alert 0` (PSI I/O stall >10%)
- **Action:** Marked as done in TODO_LIST.md with "ALREADY EXISTED" note. No code changes needed.

### 6. TODO_LIST.md + CHANGELOG.md updated
- All 7 Priority 1 items marked `[x]` with implementation details
- CHANGELOG.md entry added under `[Unreleased] > Added`
- TODO_LIST.md header updated to reflect this session

---

## B) PARTIALLY DONE (Implemented but with gaps)

### 7. `system_oomd_kills_total` textfile metric + Gatus alert
- **Files:** `system-health.nix` (collector), `gatus-config.nix` (alert)
- **What:** `system_oomd_kills_total`, `_recent`, `_alert` from `journalctl -u systemd-oomd --grep "Killed"` with delta tracking. Gatus "OOMD Kills" alert
- **ISSUE 1 (potential):** The `journalctl --grep "Killed"` query scans the ENTIRE oomd journal since boot every 2 minutes. Over time (weeks of uptime), this could grow large. Unlike the niri-health-metrics gotcha (which was fixed by adding `-n` for early termination), this query needs to count ALL matches so `-n` can't help. However, systemd-oomd should have relatively few log entries compared to niri (which logs every 30s). **Risk: LOW** but should monitor.
- **ISSUE 2 (unverified):** The exact systemd-oomd log message format was not verified at runtime. I used `--grep "Killed"` based on the TODO description, but systemd-oomd might use different wording (e.g., "Memory pressure reached... Killing", "oomd kill"). The `--grep` flag does substring matching so "Killed" should match "Killed process..." but this is UNVERIFIED on the actual system.
- **→ VERIFIED LIVE (08-14):** the pattern matches real events — `system_oomd_kills_total 2408` in the running collector output.
- **New module option:** `collectOomdKills` (default true)

### 8. Docker container restart count monitoring
- **Files:** `system-health.nix` (collector), `gatus-config.nix` (alert)
- **What:** `docker_container_restart_count{name=...}`, `_alert` per-container + `system_any_docker_container_restart_alert` aggregate, using `docker inspect --format '{{.RestartCount}}'` with delta tracking. Gatus "Docker Container Restarts" alert. Auto-disabled when Docker off.
- **ISSUE 1 (unverified):** Never run on the actual system. The collector script is syntactically valid (nix eval passes) but the bash has not been executed to verify it produces valid Prometheus text format.
- **ISSUE 2 (word splitting):** `for cname in $(docker ps --format '{{.Names}}')` is subject to word splitting. Container names rarely have spaces, but it's technically incorrect. Should use `while read` pattern.
- **ISSUE 3 (no timeout):** `docker inspect` has no timeout. If the Docker daemon hangs, the collector will hang. The systemd service has no per-command timeout.
- **ISSUE 4 (MemoryMax):** Added `pkgs.docker` to runtimeInputs but MemoryMax is still 128M. Running docker commands + journalctl queries could exceed this under load.
- **New module option:** `collectDockerRestarts` (default true, auto-disabled when Docker off)
- **→ VERIFIED LIVE (08-14):** restart metrics emit correctly for all 7 containers (dozzle, mnfst-*, twenty-*), all 0. The word-splitting (§f.17), timeout (§f.18), and MemoryMax (§f.20) concerns remain OPEN.

---

## C) NOT STARTED

### 9. VM test for new Gatus patterns
- The project has `tests/test-gatus-patterns.nix` that validates Gatus `pat()` patterns against a mock metrics server. I added 6 new patterns but added ZERO test cases.
- **Patterns needing test coverage:**
  - `pat(*system_disk_usage_over_threshold 0*)`
  - `pat(*system_any_service_crash_loop 0*)`
  - `pat(*system_oomd_kills_alert 0*)`
  - `pat(*system_any_docker_container_restart_alert 0*)`
  - `pat(*node_textfile_scrape_error 0*)`

### 10. pre-deploy-check.sh phantom metric whitelist
- Section 10 of `pre-deploy-check.sh` validates that Gatus-referenced metrics exist in `/metrics`. New phantom metrics were added that are conditionally emitted:
  - `system_any_docker_container_restart_alert` — only emitted when Docker is enabled AND containers are running
  - `docker_container_restart_count` / `docker_container_restart_alert` — same
  - `system_disk_usage_over_threshold` — always emitted (disk is always present)
  - `system_any_service_crash_loop` — always emitted
  - `system_oomd_kills_alert` — always emitted
- The Docker metrics are the phantom risk: on a fresh deploy before containers start, these metrics won't exist → pre-deploy-check will FAIL them as phantom metrics. They need to be added to the `KNOWN_NEW_METRICS` whitelist.

### 11. AGENTS.md update
- AGENTS.md documents the system-health collector extensively (all metrics listed in the "Prevention Layers" table). I added 4 new collectors with ~15 new metrics but didn't update AGENTS.md.
- Should document: new `collectDiskUsage`/`collectOomdKills`/`collectDockerRestarts` options, new metrics, new state files

### 12. Runtime verification of collector output
- The collector script was never run to verify it produces valid Prometheus text format. `nix flake check` validates Nix syntax but NOT bash correctness. The entire `node_textfile_scrape_error` alert exists BECAUSE of invalid .prom files — irony if we ship a new one.
- **→ RESOLVED (08-14):** verified live via node_exporter `/metrics` — `system_health.prom` serves disk/oomd/docker metrics in valid text format.

---

## D) TOTALLY FUCKED UP (Nothing)

No catastrophic errors. All changes pass `nix flake check --no-build`, full eval, and Gatus pattern lint. No data loss risk, no security issues, no broken existing functionality.

---

## E) WHAT WE SHOULD IMPROVE

### Critical (before deploy)

1. **Add Docker metrics to `KNOWN_NEW_METRICS` in pre-deploy-check.sh** — Without this, `nix run .#pre-deploy-check` will FAIL on the new Docker phantom metrics before any container starts. This blocks deploy.

2. ~~**Run the collector script locally** — Execute `system-health-metrics` manually to verify it produces valid `.prom` output. This is especially important for the Docker collector (word splitting, docker inspect output format) and the oomd collector (journalctl grep pattern).~~ done — verified live 08-14 via node_exporter `/metrics`

3. ~~**Verify systemd-oomd journal message format** — Run `journalctl -u systemd-oomd --grep "Killed" -n 5` on evo-x2 to confirm the grep pattern matches actual kill events. If the wording is different, the counter will always be 0 and the alert will never fire.~~ done — pattern verified live (`system_oomd_kills_total 2408`)

### Important (post-deploy)

4. **Add VM test cases for new Gatus patterns** — Extend `tests/test-gatus-patterns.nix` with the 5 new patterns. The mock server needs to serve the new metrics.

5. **Increase MemoryMax** — 128M is tight for a collector that now runs `docker inspect`, `journalctl`, `systemctl show` (12+ services × 5 calls each), and `curl`. Consider 256M.

6. **Add timeout to docker commands** — `timeout 5 docker inspect ...` prevents a hanging Docker daemon from blocking the collector.

7. **Fix word splitting in Docker container loop** — Use `docker ps --format '{{.Names}}' | while IFS= read -r cname; do ...` instead of `for cname in $(...)`.

8. **Optimize NRestarts triple-read** — The crash-loop detector reads `systemctl show -p NRestarts` three times per service: once in `emit_service()`, once in the restart state tracking, and once in the crash-loop output. Should reuse the value.

### Nice to have

9. **AGENTS.md update** — Document the new collectors, options, and metrics.

10. **Gatus pattern test for `pat(*node_textfile_scrape_error 0*)`** — This pattern matches a built-in node_exporter metric, not a textfile metric. Verify it appears in `/metrics` output.

11. **Consider `journalctl --since` for oomd** — Instead of scanning the entire boot journal, use `--since "-5min"` and maintain a running total in the state file. More efficient on long-uptime systems.

---

## F) Up to 50 Things to Get Done Next

### Immediate (blocks correct deploy)
1. Add Docker phantom metrics to `KNOWN_NEW_METRICS` in `pre-deploy-check.sh`
2. ~~Run `system-health-metrics` locally to verify valid `.prom` output~~ done — live `/metrics` verified 08-14
3. ~~Verify `journalctl -u systemd-oomd --grep "Killed"` matches actual kill events~~ done — 2408 matches counted live
4. ~~Verify `docker inspect --format '{{.RestartCount}}'` output format on evo-x2~~ done — restart metrics live for all 7 containers
5. Verify PMA `/readyz` endpoint responds on `127.0.0.1:9190`

### Deploy + Verify
6. ~~Deploy to evo-x2: `nix run .#deploy`~~ done — deployed in the 09:30 session (`7afab3f8`)
7. ~~Verify `system_health.prom` contains all new metrics: `grep -E 'system_disk|crash_loop|oomd|docker_container' /var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom`~~ done — verified live 08-14
8. Verify new Gatus checks appear in dashboard (all should be GREEN)
9. ~~Wait 2min and verify `system_disk_usage_percent` has a real value~~ done — live value observed (86) on 08-14
10. Verify `node_textfile_scrape_error` is present and equals 0
11. Check Gatus "PMA Daemon Health" check is GREEN (not 503)
12. Check Gatus "Textfile Collector Health" check is GREEN

### Testing
13. Extend `tests/test-gatus-patterns.nix` with 5 new pattern assertions
14. Add `tests/test-system-health.nix` VM test for the collector script
15. Test crash-loop detection by deliberately restarting a service 3+ times
16. Test Docker restart alert by restarting a container rapidly

### Code Quality
17. Fix word splitting: `for cname in $(docker ps...)` → `while IFS= read -r cname`
18. Add `timeout 5` to `docker inspect` and `docker ps` calls
19. Optimize NRestarts triple-read to single read per service
20. Increase MemoryMax from 128M to 256M for the expanded collector
21. Add `--since` optimization to oomd journalctl query
22. Add `pkgs.util-linux` to runtimeInputs for `timeout` command (if not already available)

### Documentation
23. Update AGENTS.md with new system-health collectors and metrics
24. Update AGENTS.md "Prevention Layers" table with new Gatus checks
25. Update AGENTS.md monitored services list to include browser-history
26. Document `pma-health = 9190` port in AGENTS.md
27. ~~Add oomd journalctl pattern to AGENTS.md gotchas if it differs from "Killed"~~ done (moot) — pattern confirmed live as `Killed` (2408 matches); nothing to document

### Monitoring (next gaps)
28. Add `system_textfile_collector_parse_errors` per-file metric (which .prom file failed)
29. Add network connectivity meta-check (can Gatus reach Discord webhook?)
30. Add zram fill ratio metric (`/sys/block/zram0/mm_stat`) — currently only documented in AGENTS.md
31. Add zram swap usage vs disk swap fallback metric
32. Add BTRFS commit stall metric (time spent in `btrfs_commit_transaction`)
33. Add SLC cache health metric (NVMe write latency percentiles)
34. Add nix-daemon build queue depth metric
35. Add systemd journal size + drop rate metric
36. Add Caddy upstream response time percentiles
37. Add DNS resolution latency metric (dnsblockd query time)
38. Add ClickHouse merge queue depth metric
39. Add Docker image disk usage metric (`docker system df`)
40. Add per-container CPU/memory metric (cAdvisor already provides this — wire to Gatus)

### Architecture
41. Extract system-health collector into per-collector scripts (modular vs monolithic)
42. Add a "collector health" meta-check (did system-health-metrics run in the last 5min?)
43. Add systemd timer failure alert (timer not firing = stale metrics)
44. Consider Prometheus alertmanager as alternative to Gatus for metric-based alerts
45. Add Grafana dashboard for system-health metrics (visual vs alert-only)
46. Add rate-based alerting (restarts/min) instead of delta-per-interval
47. Add anomaly detection (unusual restart patterns, not just threshold)
48. Add auto-remediation: crash-loop detector triggers `systemctl reset-failed`
49. Add oomd kill context: which service was killed, memory pressure at time
50. Add Docker container age metric (detect long-running stale containers)

---

## G) Questions (Cannot Figure Out Myself)

### 1. Should the oomd collector use `--grep "Killed"` or a broader pattern?

~~I based the grep pattern on the TODO description ("journalctl -u systemd-oomd --grep 'killed'"). But systemd-oomd log messages might say "Killing" (not "Killed"), or use "oomd killed" lowercase, or have a different format entirely. I cannot verify this without access to evo-x2's journal. Should I:~~ **answered (08-14):** option (b) was correct — `Killed` matches real events (2408 counted live); no broader pattern needed.
- (a) Use `--grep "Killed|killed|Killing|killed process"` (broader)?
- (b) Keep `"Killed"` and verify post-deploy?
- (c) Use a case-insensitive grep equivalent?

### 2. Should I deploy now or fix the pre-deploy-check phantom metric issue first?

~~The Docker metrics (`docker_container_restart_count`, `docker_container_restart_alert`, `system_any_docker_container_restart_alert`) won't exist until containers are running post-deploy. This means `nix run .#pre-deploy-check` will FAIL them as phantom metrics. Should I:~~ **answered by history:** the deploy proceeded anyway (09:30 session, `7afab3f8`) and the metrics went live — but the whitelist gap (§f.1) is STILL OPEN and will bite the next fresh-deploy pre-deploy check.
- (a) Fix pre-deploy-check.sh first, then deploy?
- (b) Deploy directly (pre-deploy-check is a warning tool, not a hard gate)?
- (c) Add the whitelist entry AND deploy in one step?

### 3. Should the system-health collector be split into per-concern scripts?

The collector is now 700+ lines emitting ~40 metrics across 10+ concerns (service state, CPU, memory, memory.events, disk, oomd, docker, GPUActive, tmpfs, fstrim, gatus health, EMEET, SigNoz rules, Monitor365 buffer). It runs as a single oneshot every 2min. If any section fails, the entire `.prom` file is lost (the exact `node_textfile_scrape_error` problem we're now monitoring for). Should I:
- (a) Split into per-concern scripts (modular, one failure doesn't kill all metrics)?
- (b) Keep monolithic but add per-section error handling (try/catch per section)?
- (c) Leave as-is (the `systemctl_value()` sanitizer already handles most failure modes)?
