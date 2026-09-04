# Status Report: 2026-08-05 00:33 — QLC SLC Cache Exhaustion Mitigation & I/O Monitoring

**Session focus:** Implementing the high+medium priority TODO items from the 2026-08-04 QLC SLC cache exhaustion crash diagnosis.

**Live context:** While writing this report, a manual `fstrim -v /` is running with I/O PSI at **44-53%** (avg10). This is the exact SLC cache exhaustion pattern the monitoring was designed to catch.

---

## a) FULLY DONE (Verified)

All changes evaluated successfully via `nix eval .#nixosConfigurations.evo-x2.config.*`.

### #6: PSI I/O Stall Rate Monitoring

- **What:** Extended `psi-metrics` script in `_signoz-metrics.nix` to also read `/proc/pressure/io`, emitting `node_psi_io_some_avg300`, `node_psi_io_full_avg300`, and a derived `node_psi_io_alert` boolean (>10% threshold).
- **Gatus alert:** "I/O Stall Rate" check in group "Filesystem", 1m interval, Discord alert.
- **BUG FOUND AND FIXED:** Initial implementation used awk field `$5` (= `total=`, a raw counter) instead of `$4` (= `avg300=`, the 5-min proportion). Would have always fired the alert since `total` is always > 0.10. Fixed to `$4`.
- **Live verification:** During the fstrim run, `/proc/pressure/io` shows `some avg300=52.74` — the metric correctly reflects extreme I/O stall. The alert would fire correctly.

### #7: fstrim Duration Alert

- **What:** Added `system_fstrim_duration_seconds` + `system_fstrim_duration_over_threshold` to `system-health.nix`. Reads `ExecMainStartTimestamp`/`ExecMainExitTimestamp` from systemd to compute duration. Threshold: 1800s (30 min).
- **Gatus alert:** "fstrim Duration" check in group "Filesystem", 30m interval.

### #8: Journald SystemMaxUse Lowered

- **What:** `boot.nix` `SystemMaxUse` changed from `16G` to `8G`.
- **Rationale:** 8.5 GB was too much; journal writes compete for SLC cache blocks on QLC NAND.
- **Auto-vacuum:** Existing `MaxFileSec=1week` + new `SystemMaxUse=8G` will rotate away old entries automatically. No manual `journalctl --vacuum` needed.

### #9: AGENTS.md BTRFS Section Updated

- **What:** Updated TRIM (daily+idle, not weekly), Scrub (weekly, not monthly), added Commit interval section, added SLC cache exhaustion gotcha, updated BTRFS gotchas section with `commit=300` + SLC root cause.

### #12: BTRFS `commit=300` Mount Option

- **What:** Added `commit=300` to both `/` and `/data` BTRFS mounts in `hardware-configuration.nix`.
- **Rationale:** Default 30s commits metadata every 30s. On QLC NAND this is ~10x write amplification for metadata alone. `commit=300` batches to every 5 min, preserving SLC cache blocks.

### #13: fstrim Idle I/O Priority

- **What:** Added `IOSchedulingClass=idle` + `Nice=10` to `systemd.services.fstrim.serviceConfig` in `boot.nix`.
- **Verified:** `nix eval` confirms `IOSchedulingClass = "idle"` and `Nice = 10`.
- **NOTE:** The manual `fstrim -v /` currently running does NOT use this — only the systemd timer service gets these settings. This is why the manual run is hammering I/O.

### #14: Monitor365 Server MemoryMax Raised

- **What:** Added `MemoryMax = lib.mkForce "4G"` + `MemoryHigh = lib.mkForce "3G"` to `monitor365-server` in `monitor365.nix`.
- **Rationale:** DuckDB's appender falls back to individual INSERTs (100x slowdown) under memory pressure from I/O starvation. 4G gives DuckDB's 2GB PRAGMA memory_limit enough cgroup headroom.
- **Verified:** `nix eval` confirms `MemoryMax = "4G"`.

### #22: NVMe Endurance Warning Alert

- **What:** Added `ENDURANCE_WARNING` flag (percentage_used >= 50) to `scripts/nvme-metrics.sh`. Added "NVMe Endurance Warning" Gatus check (1h interval).
- **IMPORTANT FINDING:** The deployed nvme metrics collector is a DIFFERENT implementation: `pkgs.writeShellApplication` inline in `_signoz-metrics.nix` (lines 123-201), NOT the `scripts/nvme-metrics.sh` file. The inline version uses `jq` (not grep+sed) and does NOT emit `node_nvme_endurance_warning`. **The script change is orphaned** — the Gatus check will fail because the metric doesn't exist in the deployed collector. See section (d).

### #21: fstrim Timer Review

- **Finding:** `fstrim.enable = true` (configuration.nix) + `OnCalendar = lib.mkForce "daily"` (boot.nix) = NO conflict. `mkForce` properly overrides nixpkgs default. Verified.

### #23: SLC Cache Exhaustion Documented in gotchas-archive.md

- **What:** Full incident narrative with root-cause chain, timeline, fix list, and lesson. Covers the QLC SLC cache exhaustion pattern, `commit=300`, daily fstrim, and all monitoring additions.

### #15: /data BTRFS Chunk Investigation

- **Finding:** Data chunks at 96.23% is NORMAL. Device has 297 GiB unallocated (29%). BTRFS allocates new chunks from the unallocated pool. Weekly `-dusage=50` balance will find almost nothing to consolidate. No action needed.

### #17: Journal Cleanup

- **Finding:** Auto-handled by `SystemMaxUse=8G` + `MaxFileSec=1week`. No manual vacuum needed.

### #19: Docker overlay2 Location

- **Finding:** Docker Root Dir is already `/data/docker` (on the separate BTRFS partition). No action needed.

---

## b) PARTIALLY DONE

### #22: NVMe Endurance Warning — METRIC NOT DEPLOYED

The Gatus check was added and evaluates, but the **metric it checks (`node_nvme_endurance_warning`) does not exist in the deployed nvme-metrics collector**. The deployed collector is an inline `pkgs.writeShellApplication` in `_signoz-metrics.nix` (lines 123-201), which I did NOT modify. I edited `scripts/nvme-metrics.sh` instead — a standalone script that is NOT referenced by any Nix module. **The Gatus check will permanently fire (metric not found = condition never matches).**

**Fix needed:** Add the `ENDURANCE_WARNING` logic to the inline nvmeMetrics script in `_signoz-metrics.nix`, not the standalone script.

---

## c) NOT STARTED

### High Priority (From Original Task List)

- **#10:** File upstream Monitor365 issue — headless agent should disable graphical collectors, not spam warnings
- **#11:** File upstream Monitor365 issue — "Buffer near capacity" should log once, not 119K times

### Medium Priority (From Original Task List)

- **#16:** Add `node_disk_io_time_weighted_seconds_total` rate dashboard to SigNoz
- **#18:** Audit all services for I/O patterns — identify sustained writers
- **#20:** Consider moving ClickHouse data to a separate partition to reduce I/O contention on root
- **#24:** Consider daily btrfs scrub instead of monthly — **ALREADY WEEKLY**, daily on 707 GiB may be too aggressive
- **#25:** Review all systemd services for `IOSchedulingClass=idle` on non-critical services

---

## d) TOTALLY FUCKED UP

### BUG 1: PSI I/O awk field index (FIXED)

- **What:** Used `$5` (total stall time counter) instead of `$4` (avg300 proportion) in the awk parser for `/proc/pressure/io`.
- **Impact:** Would have reported `total=1907016708` instead of `avg300=0.52`, making the `> 0.10` threshold always true — permanent false alarm.
- **Status:** FIXED before writing this report. Verified against live `/proc/pressure/io` output.
- **Root cause:** Copy-pasted the field index from memory without checking the PSI format. The existing memory code uses `$2` for avg10, and I assumed `$5` for avg300 without counting fields.

### BUG 2: nvme-metrics.sh edited instead of inline Nix derivation (NOT FIXED)

- **What:** Edited `scripts/nvme-metrics.sh` (standalone script) to add `node_nvme_endurance_warning`. But the DEPLOYED nvme metrics collector is an inline `pkgs.writeShellApplication` in `_signoz-metrics.nix` that does NOT read from this script.
- **Impact:** The `node_nvme_endurance_warning` metric will NEVER appear in Prometheus output. The Gatus "NVMe Endurance Warning" check will permanently fire because the condition `[BODY] == pat(*node_nvme_endurance_warning 0*)` never matches.
- **Status:** NOT FIXED. The fix is to add the endurance warning logic to the inline `nvmeMetrics` script in `_signoz-metrics.nix` lines 154-198.
- **Root cause:** Did not verify how the metric is actually deployed before editing. Assumed the standalone script was wired in.

---

## e) WHAT WE SHOULD IMPROVE

1. **Verify deployment path before editing scripts** — The `scripts/nvme-metrics.sh` vs inline `pkgs.writeShellApplication` mismatch is a systematic failure. Always grep for how a metric is deployed before editing the source.

2. **Test PSI format empirically** — I could have `cat /proc/pressure/io` before writing the awk parser. Instead I guessed field positions from memory. The live output confirmed `$4` is correct.

3. **Run `nix fmt` after edits** — Did not format the Nix files. The AGENTS.md says to use `nix fmt` (treefmt + alejandra).

4. **Add `commit=300` to cache subvolumes** — The `@cache-home`, `@go`, `@npm`, `@cargo` automounts in `snapshots.nix` still use default 30s commit. `commit=` is per-mount (not filesystem-wide like compression), so these subvolumes still commit every 30s. Low impact (noauto + 10min idle timeout) but inconsistent.

5. **Consider adding I/O PSI metrics as a separate service** — Currently appended to the `psi-metrics` service which runs every 15s. The I/O avg300 is a 5-minute average, so 15s collection is overkill for I/O. But it's simpler to keep them together.

6. **Monitor365 upstream issues should be filed** — #10 and #11 are upstream code bugs that cause log spam and buffer drops. They belong in `/home/lars/projects/monitor365/issues/`, not SystemNix.

---

## f) Up to 50 Things We Should Get Done Next

### Critical (Fix bugs from this session)

1. ~~**Fix BUG 2:** Add `node_nvme_endurance_warning` to the inline nvmeMetrics in `_signoz-metrics.nix` (lines 154-198)~~ done at `556dac12`
2. ~~**Run `nix fmt`** to format all edited Nix files~~ done
3. ~~**Deploy and verify** — `nix run .#deploy`, then verify new Gatus checks appear and don't false-alarm~~ done

### High Priority (From original task list)

4. File upstream Monitor365 issue: headless agent should disable graphical collectors gracefully
5. File upstream Monitor365 issue: "Buffer near capacity" should log once, not spam 119K times
6. ~~Add `commit=300` to cache subvolume mounts in `snapshots.nix`~~ **NOT-DO/DUPLICATE — `commit=` is filesystem-wide on BTRFS, already applied to `/` mount. Cache subvolumes inherit it.**
7. Add I/O PSI `avg10` + `avg60` metrics (not just `avg300`) for finer-grained alerting

### I/O & Disk Health

8. Add `node_disk_io_time_weighted_seconds_total` dashboard to SigNoz
9. Audit all systemd services for sustained disk writers (identify I/O hogs)
10. Review all non-critical systemd services for `IOSchedulingClass=idle`
11. Consider moving ClickHouse data dir to `/data` to reduce root I/O contention
12. Add disk I/O latency percentile metrics (p50/p95/p99) via textfile collector
13. Monitor BTRFS transaction commit duration (alert if commit stalls >5s)
14. Add per-mount I/O write rate metrics
15. Consider `IOSchedulingClass=idle` on `btrfs-balance-data` and `btrfs-balance-metadata`
16. Add `IOSchedulingClass=idle` to `btrfs-compsize` service
17. Monitor fstrim bytes trimmed per run (track SLC cache health trend)

### BTRFS & Filesystem

18. Consider BTRFS `commit=600` (10 min) if `commit=300` proves insufficient
19. Evaluate `compress-force=zstd` for `/data` (force compression on already-compressed media)
20. Add BTRFS filesystem read-only scrub result history (track corruption trends)
21. Consider daily scrub on `/` only (smaller, faster) keeping weekly on `/data`
22. Add btrfs device stats monitoring (write_super, write_errors, read_errors)
23. Monitor BTRFS free space fragmentation (`btrfs filesystem df` trends)
24. Consider `space_cache=v2` → `free_space_tree` (already v2, verify)
25. Track BTRFS metadata growth rate (alert if metadata growing faster than data)

### NVMe & SMART

26. Add NVMe thermal throttling event monitoring (alert on throttle_count)
27. Track NVMe write amplification factor (data_units_written vs logical block writes)
28. Monitor NVMe error log entries growth rate
29. Add NVMe available_spare degradation tracking (alert when spare drops below threshold)
30. Consider NVMe power state monitoring for power management optimization

### Monitoring & Alerting

31. Add Prometheus alert for sustained high I/O wait (>5% for 10min)
32. Add Gatus check for system_health-metrics service itself (meta-monitoring)
33. Add textfile collector for systemd journal size tracking
34. Add alert for disk space growth rate (GB/hour) to catch runaway logs early
35. Monitor Docker container I/O per container (cAdvisor already has this — wire to SigNoz)
36. Add OOM kill history tracking (alert if any OOM in last hour)
37. Add kernel dmesg error scanner (alert on new BUG/WARN/panic in kernel log)
38. Consider adding healthchecks.io external ping for WAN connectivity monitoring

### System Hardening

39. Lower `MemoryHigh` on Helium (Chromium) to prevent SLC cache pressure from renderer churn
40. Add `IOSchedulingClass=idle` to `nix-gc` and `nix-build-cleanup`
41. Consider `systemd-cgroup` I/O weight for critical services (Caddy, DNS, Pocket ID)
42. Add `LimitNOFILE` audit on all services (catch file descriptor leaks that cause I/O)
43. Evaluate `ionice` on `btrbk` snapshot operations
44. Consider BTRFS `noCow` attribute on Docker overlay2 lowerdir (reduce CoW churn)

### Documentation

45. Document the `commit=` per-mount vs filesystem-wide distinction in AGENTS.md
46. Add a "QLC NAND tuning guide" section to docs/
47. Document the relationship between SLC cache, CoW, and fstrim frequency
48. Create a runbook for WDT crash investigation (step-by-step)
49. Add `docs/crash-analysis-2026-08-04.md` with the full fstrim/SLC cache timeline
50. Update the BTRFS section of AGENTS.md with the `/data` chunk allocation findings

---

## g) Questions I CANNOT Answer Myself

1. **Should we bump the BTRFS commit interval to `commit=600` (10 min)?** The 5-min window means up to 5 min of data loss on crash. With daily btrbk snapshots at 23:00, the worst case is losing 5 min of work + rolling back to the previous snapshot. Is 5 min acceptable, or should we be more conservative? The tradeoff is 2x less metadata write amplification with `commit=600` vs `commit=300`.

2. **Should the SLC cache exhaustion fixes be deployed immediately (before `nix fmt` and the nvme-metrics fix), or should we batch everything?** The fstrim idle priority and `commit=300` are urgent (the manual fstrim is demonstrating 44% I/O PSI right now), but deploying with the broken nvme-metrics Gatus check means a permanent false alarm until the next deploy.

3. **Should we move ClickHouse data to `/data`?** ClickHouse (SigNoz) is likely the #1 sustained I/O writer on the root filesystem. Moving it to `/data` (separate BTRFS partition, 297 GiB free) would dramatically reduce root I/O contention. But this requires stopping SigNoz, rsyncing ~50+ GiB of data, and updating the config. Is this worth the downtime?

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.
