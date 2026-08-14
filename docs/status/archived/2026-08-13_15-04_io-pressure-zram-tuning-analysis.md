# Status Report: 2026-08-13 15:04 — Disk I/O Storm Investigation & ZRAM Tuning Analysis

**Session start:** ~10:36
**Report time:** 15:04
**Trigger:** User reported single CPU core at 100%

---

## Executive Summary

User reported a single CPU core pinned at 100%. Investigation revealed a BTRFS writeback storm (`kworker/5:2+inode_switch_wbs` at 100% CPU) compounded by severe I/O pressure (PSI `full avg10=79%`), an exhausted zram swap (98.4% full), and a concurrent `go build` adding write pressure. The session pivoted to analyzing zram/swap configuration for disk pressure relief. **No code changes were made** — the session was purely diagnostic. The user asked for a self-review and status before any implementation.

---

## a) FULLY DONE

1. **Diagnosed the 100% CPU core** — Identified `kworker/5:2+inode_switch_wbs` (PID 210672) as a BTRFS inode writeback-switching kernel thread stuck in a tight loop since 10:29. Root cause: BTRFS writeback congestion on QLC NAND, consistent with the known SLC cache exhaustion pattern documented in AGENTS.md.

2. **Identified contributing factors:**
   - 20+ `btrfs-endio` kworkers all active (normally idle)
   - NVMe write latency: 28ms (`w_await=27.82`)
   - I/O PSI `full avg10=56-79%` (over half the time, ALL tasks stalled on I/O)
   - zram swap 98.4% full (15.7G/16G), no disk swap fallback
   - BTRFS scrub health check failing for 2+ hours (Gatus `success=false`)
   - `go build ./...` spawned 4 parallel Go linkers adding ~80 MB/s write pressure
   - PMA consuming 6.5 GB RSS
   - zram swap nearly exhausted with no fallback

3. **Analyzed zram configuration in depth:**
   - Current: `memoryPercent=17` (~16 GiB), `zstd(level=1)`, `vm.swappiness=10`
   - Live compression ratio: 3.23x (8.1 GiB original → 2.5 GiB compressed, costing ~2.5 GiB physical RAM)
   - Top swap consumers identified (immich 207 MiB, MainThread 219 MiB, workerd 148 MiB, searxng 122 MiB)
   - Found critical misconfiguration: `vm.swappiness=10` is backwards for zram-only — it prefers disk page cache reclaim over zram swap, forcing BTRFS I/O instead of fast in-RAM compression

4. **Proposed 6 sysctl/zram changes** to reduce disk I/O pressure:
   - `vm.swappiness`: 10 → 150 (prefer zram over disk reclaim)
   - `zramSwap.memoryPercent`: 17 → 30 (~28 GiB zram device)
   - `vm.watermark_scale_factor`: 10 → 100 (earlier gradual reclaim)
   - `vm.vfs_cache_pressure`: 100 → 150 (prefer cheap dentry/inode reclaim)
   - `vm.dirty_ratio`: 10 → 5 (smaller writeback bursts)
   - `vm.dirty_background_ratio`: 3 → 1 (gentler background writeback)

---

## b) PARTIALLY DONE

Nothing — no implementation was started.

---

## c) NOT STARTED

1. ~~**Implementing the zram/sysctl changes** in `boot.nix` — proposed but not applied~~ done at `0bd8a272`
2. ~~**Verifying the BTRFS scrub failure** — Gatus reported `success=false` for 2+ hours but we never ran `btrfs scrub status /` to check if there are actual errors (requires sudo, which was blocked)~~ done (moot) — `btrfs-health-metrics` collects `btrfs scrub status` every 5 min (CAP_SYS_ADMIN override); scrub errors alert via Gatus "BTRFS Scrub Health"
3. ~~**Checking if a BTRFS balance is running** — couldn't run `btrfs balance status /` (requires sudo)~~ done (superseded) — weekly automated balance in `btrfs-health.nix` with `btrfs-chunk-check` guards (see AGENTS.md)
4. ~~**Checking disk space** — couldn't run `df -h /` with sudo context (df ran but we didn't capture it)~~ done (moot) — "Root Disk Space"/"Root Disk Usage" Gatus checks monitor continuously
5. ~~**Deploying and testing the changes** — not started~~ done at `0bd8a272`
6. ~~**Updating AGENTS.md** with the swappiness/zram findings~~ done — AGENTS.md "ZRAM & Memory Reclaim" section (`0bd8a272`-era)

---

## d) TOTALLY FUCKED UP

1. **Didn't check `df -h` early enough** — We saw the I/O storm and zram exhaustion but didn't explicitly check free disk space. Metadata ENOSPC could be the actual trigger for the `inode_switch_wbs` storm, and we should have verified this immediately.

2. **Didn't try `btrfs scrub status` or `btrfs balance status`** — The Gatus scrub health check was failing for 2+ hours. We noted it but never investigated further. sudo was blocked by the shell sandbox, but we should have asked the user to run it or tried alternative approaches.

3. **Forgot to check `watermark_scale_factor` initially** — The first sysctl dump included it (value=10) but I didn't call it out in the initial analysis. It's a critical parameter for gradual reclaim and I only caught it when doing the zram deep-dive.

4. **Didn't investigate whether the `go build` was user-initiated or a service** — We saw `go build ./...` (PID 669123) and 4 linker processes but never traced who started it. Could have been a forgejo-runner CI job, a dev session, or PMA. Knowing the source would help determine if it should be killed.

5. **Initial response was too narrow** — User said "single core 100%" and I focused on the kworker. Should have immediately checked ALL pressure indicators (PSI, swap, disk space, BTRFS status) in the first batch rather than iteratively discovering them.

6. **Didn't check `systemd-oomd` active kills** — With memory pressure this high (PSI memory `full avg10=10%`), oomd may be killing services. We never checked `journalctl -u systemd-oomd` for recent kills.

7. **Forgot the `zramSwap` `memoryPercent` interacts with GPU VRAM carveout** — The machine has 128 GiB physical but only ~94 GiB visible to Linux after the 34 GiB BIOS VRAM carveout. `memoryPercent = 30` would be 30% of 94 GiB = ~28 GiB zram, not 30% of 128 GiB. The calculation was correct in the proposal but the comment should document this.

---

## e) WHAT WE SHOULD IMPROVE

### ZRAM / Swap Configuration

1. ~~**`vm.swappiness = 10` is actively harmful with zram-only** — This is the biggest finding. The comment in `boot.nix` says "Use swap before OOM kills" but swappiness=10 does the OPPOSITE: it tells the kernel to prefer page cache reclaim (disk I/O) over swap (zram, which is in RAM). With zram-only swap, high swappiness (100-200) is correct because zram swap is faster than disk I/O. This single misconfiguration is likely a major contributor to disk I/O pressure.~~ done at `0bd8a272` (swappiness=150 + corrected comment)

2. ~~**zram device too small (16 GiB / 17%)** — At 3.23x compression, 16 GiB of zram only holds ~51 GiB of original data while costing ~5 GiB physical RAM. Increasing to 30% (~28 GiB) would hold ~90 GiB of original data at ~8.7 GiB physical cost — a good trade on a 94 GiB system with 58 GiB available.~~ done at `0bd8a272` (memoryPercent=30)

3. ~~**`vm.watermark_scale_factor = 10` is too low** — Default is 100. At 10, the kernel waits until memory is very low before starting background reclaim, then does aggressive "panic reclaim" — large synchronous I/O bursts that hammer BTRFS. Raising to 100 starts reclaim earlier and more gradually.~~ done at `0bd8a272`

4. ~~**`vm.dirty_ratio = 10` / `vm.dirty_background_ratio = 3` too high for QLC NAND** — 10% of 94 GiB = 9.4 GiB of dirty pages before the kernel forces writeback. On QLC NAND with slow writes, this creates huge writeback bursts. Lowering to 5% / 1% spreads writes more evenly.~~ done at `0bd8a272` (5% / 1%)

5. ~~**`vm.vfs_cache_pressure = 100` (default)** — Could be raised to 150 to prefer reclaiming dentry/inode cache (cheap, no disk I/O) over page cache (expensive, requires disk reads/writes).~~ done at `0bd8a272` (150)

### Broader System Issues Noticed

6. **PMA at 6.5 GB RSS is enormous** — Despite `MemoryMax=8G` and `MemoryHigh=6G`, PMA is sitting at the high watermark. The AGENTS.md documents the page-cache death-loop fix, but 6.5 GB for a commit automation service is still very high. Should investigate whether the 260+ repo discovery is loading too much into memory.

7. ~~**iotop running for 2+ days** — PID 13227, `iotop -aoP`, started Aug 11, 91 minutes of CPU time. This is a leftover diagnostic process that should be killed. It's not causing the problem but it's wasteful.~~ done (moot) — transient process; multiple reboots since

8. **~15 Crush instances running** — Multiple `crush -y` processes across many PTS sessions, consuming 1-6% CPU each. Cumulatively ~20-30% CPU. Should clean up idle sessions.

9. ~~**BTRFS scrub health check failing for 2+ hours** — Gatus consistently reports `success=false` for "BTRFS Scrub Health". This could be:
   - A real scrub finding errors (serious)
   - The scrub status script failing to run (sudo permissions?)
   - Stale metrics from the `btrfs-health-metrics` service
   This needs investigation before assuming it's benign.~~ done (moot) — did not persist; `btrfs-health-metrics` (every 5 min, CAP_SYS_ADMIN) feeds the Gatus scrub alerts

10. **Swap is 98.4% full with no disk swap fallback** — When zram fills completely, the kernel has NO swap left and must either OOM-kill or aggressively reclaim page cache (disk I/O). Adding a small disk swap as emergency fallback (even 4-8 GiB on the NVMe) would prevent the "zram full → disk I/O storm" cascade. This was explicitly removed in `hardware-configuration.nix` to free 10G — but the tradeoff was disk space vs. stability, and stability lost.

---

## f) NEXT 50 THINGS TO DO

### Immediate (today)

1. ~~Implement the 6 zram/sysctl changes in `boot.nix` (swappiness, memoryPercent, watermark_scale_factor, vfs_cache_pressure, dirty_ratio, dirty_background_ratio)~~ done at `0bd8a272`
2. ~~Run `df -h /` and `df -h /data` to check for disk space / metadata ENOSPC~~ done (moot) — Gatus "Root Disk Space"/"Root Disk Usage" monitor continuously
3. ~~Run `btrfs scrub status /` to verify whether scrub is actually finding errors~~ done (moot) — `btrfs-health-metrics` collects it every 5 min
4. ~~Run `btrfs balance status /` to check if a balance is running~~ done (superseded) — weekly automated balance with chunk-check guards
5. ~~Kill the stale `iotop` process (PID 13227, running since Aug 11)~~ done (moot) — transient; reboots since
6. ~~Identify and kill the `go build ./...` if it's not user-initiated~~ done (moot) — transient build; build I/O since classed via `ioTier.build` (BE/7)
7. Clean up idle Crush sessions (~15 instances running)
8. ~~Deploy the zram changes and monitor PSI / I/O for improvement~~ done at `0bd8a272`; PSI now monitored ("I/O Stall Rate", "Memory Pressure" Gatus checks, `004924be`)
9. ~~Check `journalctl -u systemd-oomd` for recent OOM kills under memory pressure~~ done (superseded) — "OOMD Kills" Gatus check added at `9b6590bf`

### Short-term (this week)

10. Add a small disk swap (4-8 GiB) as emergency fallback when zram is full
11. ~~Update the `boot.nix` comments to correctly explain why high swappiness is correct for zram-only~~ done at `0bd8a272` (comment block, `boot.nix:176-182`)
12. ~~Update AGENTS.md with the swappiness/zram finding — it's a non-obvious gotcha~~ done — AGENTS.md "ZRAM & Memory Reclaim" section
13. ~~Investigate the BTRFS scrub health check failure — is it real errors or a script issue?~~ done (moot) — did not persist; automated collection + Gatus alerting in place
14. Reduce PMA's memory footprint — 6.5 GB for commit automation is too high
15. Consider `vm.min_free_kbytes` increase (currently 2 GB) — with larger zram, may need more headroom
16. Add Gatus alert for zram fill > 90% — should warn before exhaustion
17. ~~Add Gatus alert for I/O PSI `full avg10 > 50%` — early warning of disk pressure~~ done at `004924be` ("I/O Stall Rate" on `node_psi_io_alert`)
18. ~~Review whether `zstd(level=1)` is still optimal with the larger zram device~~ done — documented in AGENTS.md: level 3 gains 1.7% ratio for 11.5% less speed; level 1 kept
19. ~~Consider `zramSwap.priority` — ensure zram has highest priority over any disk swap~~ done (moot) — zram is the only swap device
20. Check if `max_comp_streams` is set correctly for the 32-core CPU

### Medium-term (this month)

21. ~~Evaluate whether BTRFS `commit=300` should be lowered to `commit=120` — 5 min data loss window is large~~ **Won't implement — decision documented in AGENTS.md: 5-min window accepted (daily btrbk snapshots + CoW journaling); `commit=300` preserves SLC cache**
22. ~~Add a systemd timer that monitors zram fill and logs warnings at 80%, 90%, 95%~~ done (superseded) — system-health textfile collector + "Swap Metrics" Gatus check (`9b6590bf`); fill-level alerting still partial (see item 16)
23. Review all service `MemoryMax` limits — with larger zram, some may be too restrictive
24. Consider moving ClickHouse data to a separate filesystem to isolate its I/O
25. ~~Evaluate whether the Go build linkers should have I/O priority set (currently `ioTier.build` = BE/7)~~ done — `ioTier.build` (BE/7 + Nice=10) covers nix-daemon, forgejo-runner, PMA (see AGENTS.md BFQ tiers)
26. Add pre-deploy check for zram fill > 90% — don't deploy during memory pressure
27. Create a runbook for "I/O pressure diagnosis" — standard steps for when PSI spikes
28. Review whether `nix-daemon` should have `MemorySwapMax` set — it's the top memory consumer during builds
29. Evaluate z3fold/zbud allocator for zram — may give better compression than zsmalloc for this workload
30. Consider `vm.compaction_proactiveness` tuning — currently 20, may need adjustment with larger zram

### BTRFS-specific

31. ~~Verify BTRFS scrub is actually running weekly (timer may not be firing)~~ done — `autoScrub` weekly on `/` and `/data`; scrub freshness verified daily (alerts if >3 days old)
32. ~~Check BTRFS metadata allocation — `btrfs filesystem df /` for metadata chunk pressure~~ done — "BTRFS Chunk Health" Gatus check + weekly balance prevent the ENOSPC crash mode
33. ~~Consider enabling BTRFS qgroups for per-subvolume tracking (was disabled for performance)~~ **Won't implement — qgroup metadata overhead not worth it on QLC NAND; removed metrics deliberately (see AGENTS.md)**
34. ~~Review the emergency reserve file (`/btrfs-emergency-reserve`) — is it still present?~~ done — provisioned on boot by `btrfs-emergency-reserve.service`, tracked via metrics + "BTRFS Emergency Reserve" Gatus check
35. ~~Check if the weekly balance is completing or being interrupted by reboots~~ done (superseded) — weekly balance is guarded by `btrfs-chunk-check` and bounded (`-dlimit=10`)
36. ~~Evaluate moving to `commit=120` + `compress=zstd:1` (faster compression, more frequent commits)~~ **Won't implement — same decision as item 21; zstd level 1 already in use for zram, BTRFS keeps `commit=300`**
37. ~~Add monitoring for BTRFS metadata chunk allocation — `btrfs filesystem df /` metrics~~ done — "BTRFS Chunk Health" check

### Monitoring & Alerting

38. ~~Add node_exporter textfile collector for zram stats (mm_stat parsing)~~ done (superseded) — "Swap Metrics" check covers swap presence via node_exporter; system-health textfile collector handles the rest
39. ~~Add Gatus alert for PSI memory `full avg10 > 20%`~~ done at `004924be` ("Memory Pressure" on `node_psi_memory_alert`)
40. Add Gatus alert for zram compression ratio degradation (if ratio drops < 2x, something's wrong)
41. Add a Grafana/Prometheus dashboard for zram fill, compression ratio, and I/O PSI
42. Monitor `pages_compacted` and `huge_pages` from zram mm_stat for regression
43. Add alert for `go build` processes running during high I/O pressure
44. Add alert for swap usage > 90% (currently no alert until zram is full)

### Documentation

45. ~~Document the swappiness/zram gotcha in `docs/gotchas-archive.md` with full analysis~~ done (superseded) — documented in AGENTS.md "ZRAM & Memory Reclaim" (the right home for enduring rules; gotchas-archive holds incident narratives)
46. ~~Update the `boot.nix` zram comment block with the swappiness correction~~ done at `0bd8a272` (`boot.nix:176-182`)
47. ~~Add a "Memory Pressure Response" section to AGENTS.md~~ done (superseded) — AGENTS.md "ZRAM & Memory Reclaim" covers the territory
48. ~~Document the interaction between zram size, GPU VRAM carveout, and available RAM~~ done — AGENTS.md documents ~28 GiB zram on 94 GiB visible RAM
49. Create an ADR for the zram-only swap decision (pros/cons, fallback strategy)
50. ~~Add the zram tuning values to a reference table in `docs/` for quick lookup~~ done (superseded) — AGENTS.md "ZRAM & Memory Reclaim" lists every value with rationale

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Is the `go build ./...` (PID 669123) something you started, or is it from a service (forgejo-runner, PMA, etc.)?** If it's a CI job, we may want to add I/O pressure guards to the runner config. If you started it, we should wait for it to finish before deploying zram changes.

   > **Answered (2026-08-14):** Moot — transient process; build I/O is now classed at `ioTier.build` (BE/7) regardless of origin.

2. **Can you run `sudo btrfs scrub status /` and `sudo btrfs balance status /`?** The shell sandbox blocks sudo. The Gatus scrub health check has been failing for 2+ hours and I need to know if there are actual filesystem errors or if it's a monitoring/script issue.

   > **Answered (2026-08-14):** Superseded — `btrfs-health-metrics` (CAP_SYS_ADMIN, every 5 min) automates both; scrub errors and chunk health alert via Gatus.

3. **Are you comfortable adding a small disk swap (4-8 GiB) as an emergency fallback?** It was explicitly removed to free 10G of disk space, but the current zram-only setup has no safety net when zram fills up — the kernel falls back to aggressive page cache reclaim, which is what's causing the BTRFS I/O storm. The tradeoff is 4-8 GiB of disk space vs. eliminating the "zram full → disk I/O storm" cascade.

   > **Still open (2026-08-14):** No disk swap fallback exists; zram-only (30% ≈ 28 GiB) stands. Disk is at 97% — reclaiming 4-8 GiB for swap is currently not viable. Revisit after disk cleanup.

---

## System State Snapshot (15:04)

| Metric | Value | Status |
|--------|-------|--------|
| zram swap used | 15.0G / 16G (98.4%) | CRITICAL |
| zram compression ratio | 3.23x | Good |
| zram physical cost | ~2.5 GiB | Acceptable |
| I/O PSI full avg10 | 79.3% | CRITICAL |
| Memory PSI full avg10 | 10.2% | Elevated |
| Free RAM | 3.8 GiB | Low |
| Available RAM | 58 GiB | OK (buff/cache reclaimable) |
| BTRFS scrub health | FAILING (2+ hours) | Needs investigation |
| Top CPU | quickshell 7.5%, clickhouse 6.6% | No runaway process |
| PMA RSS | 6.5 GB | High but within limits |
| iotop stale process | 91 min CPU since Aug 11 | Should be killed |

---

*Report generated: 2026-08-13 15:04*
*Session duration: ~4.5 hours*
*Changes made: None (diagnostic session only)*
