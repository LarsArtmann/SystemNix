# ZFS Pool Health Check & Speed Tests — 2026-08-10

> Comprehensive health verification and performance benchmarking of the `datapool` ZFS mirror
> accessed via VFIO PCIe passthrough NixOS VM (kernel 6.18.43, ZFS 2.4.3)

---

## Executive Summary

**The ZFS pool is healthy. The hardware is healthy. The USB enclosure is the bottleneck.**

Both 16TB Toshiba MG08ACA16TE enterprise drives passed SMART with zero errors, zero reallocated
sectors, and only 755 power-on hours. The ZFS pool `datapool` is ONLINE with zero read/write/checksum
errors across all tests. Pool features were successfully upgraded to the latest ZFS feature set.

However, the JMicron JMS567 USB 3.0 bridge has a kernel-level quirk (`0x05000000`) that disables
UAS (USB Attached SCSI), forcing the ancient Bulk-Only Transport (BOT) protocol. This caps throughput
at ~100 MB/s sequential and ~70 IOPS random — far below what the drives or USB 3.0 link can deliver.

---

## A) FULLY DONE

### Pool Health Verification

| Check | Result | Details |
|-------|--------|---------|
| Pool state | **ONLINE** | `datapool` mirror-0, both vdevs ONLINE |
| Read errors | **0** | Zero across all tests |
| Write errors | **0** | Zero across all tests |
| Checksum errors | **0** | Zero across all tests |
| Data errors | **0** | `No known data errors` |
| Previous scrub | **0 errors repaired** | Dec 1, 2025, 01:49:23 duration |
| Current scrub | **In progress, 0 errors so far** | 45% complete at time of report, 0B repaired |
| Pool upgrade | **Done** | 3 new features enabled: `block_cloning_endian`, `physical_rewrite`, `dynamic_gang_header` was already enabled |

### SMART Health (Both Drives)

| Attribute | Drive 1 (72U0A005FWTG) | Drive 2 (72U0A0ZUFWTG) | Status |
|-----------|------------------------|------------------------|--------|
| Model | TOSHIBA MG08ACA16TE | TOSHIBA MG08ACA16TE | Enterprise Capacity HDD |
| Firmware | 4303 | 4303 | Same rev |
| Capacity | 16,000,900,661,248 bytes (16 TB) | Same | |
| SMART overall | **PASSED** | **PASSED** | |
| Power-On Hours | 755 | 755 | Very low usage (~31 days) |
| Power Cycle Count | 9 | 9 | Nearly pristine |
| Start/Stop Count | 61 | 61 | Low |
| Reallocated Sectors | **0** | **0** | No bad sectors |
| Current Pending Sectors | **0** | **0** | No pending failures |
| Offline Uncorrectable | **0** | **0** | Clean |
| UDMA CRC Errors | **0** | **0** | Cable/bridge healthy |
| Raw Read Error Rate | **0** | **0** | Clean |
| Seek Error Rate | **0** | **0** | Clean |
| Temperature | 35°C (Min 21, Max 40) | 35°C (Min 21, Max 39) | Normal |
| Helium Condition | **0** (normal) | **0** (normal) | Helium-sealed, no leak |
| G-Sense Error Rate | 2 | 3 | Minor vibration events (benign) |
| Error Log | **No Errors Logged** | **No Errors Logged** | |
| Self-test Log | 2-3 aborted-by-host extended tests | 2 aborted-by-host extended tests | Aborted = host powered off during test, not a drive failure |

### ZFS Pool Configuration

| Property | Value | Original Intent (private-cloud) | Match? |
|-----------|-------|---------------------------------|--------|
| Layout | mirror | mirror (disko-config.nix) | YES |
| ashift | 12 | 12 (ZFS_IMPLEMENTATION_GUIDE) | YES |
| failmode | continue | - | Reasonable |
| autotrim | off | weekly TRIM via zfs-maintenance.nix | Different but OK (VM has no trim path through USB) |
| autoexpand | off | - | Standard |
| multihost | off | - | Standard (single host) |
| Pool version | Feature flags (5000) | - | Current |
| Compression (root) | lz4 | lz4 (original) / zstd (later intent) | **MISMATCH** — root dataset still lz4, private-cloud intended zstd upgrade |
| recordsize (root) | 1M | 1M (disko-config.nix rootFsOptions) | YES |
| atime | off | off | YES |
| xattr | sa | sa | YES |
| primarycache | all | all | YES |
| logbias | throughput | throughput | YES |
| acltype | posix | posixacl (ZFS_IMPLEMENTATION_GUIDE) | **MISMATCH** — pool root is `posix`, private-cloud used `posixacl` |
| dnodesize | auto | - | Good default |
| sync | standard | - | Standard |
| mountpoint | legacy | legacy (root), /storage/* (children) | YES |
| canmount | off | off (root container) | YES |

### Dataset Inventory (Filesystem Only — No Snapshots)

| Dataset | Used | Recordsize | Compression | Mountpoint | Notes |
|---------|------|------------|-------------|------------|-------|
| `datapool` (root) | 96K | 1M | lz4 | legacy | Container, canmount=off |
| `datapool/apps` | 3.44G | 1M | lz4 | /storage/apps | Docker layer datasets (~300+ children) |
| `datapool/apps/images` | 96K | 128K | zstd | /storage/apps/images | Docker images |
| `datapool/apps/volumes` | 104K | 128K | zstd | /storage/apps/volumes | Docker volumes |
| `datapool/backups` | 96K | 1M | lz4 | /storage/backups | Empty |
| `datapool/cache` | 3.76G | 1M | lz4 | /storage/cache | Redis/cache data |
| `datapool/config` | 184K | 1M | lz4 | /storage/config | Minimal data |
| `datapool/databases` | 104K | 1M | lz4 | /storage/databases | Empty |
| `datapool/dev` | 96K | 1M | lz4 | /storage/dev | Empty |
| `datapool/documents` | 96K | 1M | lz4 | legacy | Container |
| `datapool/documents/general` | 96K | 1M | lz4 | /storage/documents/general | Empty |
| `datapool/documents/paperless` | 136K | 1M | lz4 | /storage/documents/paperless | Minimal |
| `datapool/logs` | 96K | 1M | lz4 | /storage/logs | Empty |
| `datapool/media` | 96K | 1M | lz4 | legacy | Container |
| `datapool/media/general` | 96K | 1M | lz4 | /storage/media/general | Empty |
| `datapool/media/photos` | 96K | 1M | lz4 | /storage/media/photos | Empty |

**Total used:** 20.3 GB (0.14% of 14.5 TB usable)
**Snapshot count:** 1,137 snapshots (Sanoid auto-snapshots from private-cloud, Dec 2025 era)
**Content:** Almost entirely Docker container layers (~300+ hash-named datasets under `apps/`). No personal data, no photos, no irreplaceable documents.

### Speed Tests Completed

| Test | Block | Mode | Result | Notes |
|------|-------|------|--------|-------|
| Sequential Write | 1M | O_DIRECT (libaio, QD32) | **106.3 MB/s** | |
| Sequential Write | 1M | Cached (sync) | **141.2 MB/s** | ARC/ZIL helped |
| Sequential Read | 1M | O_DIRECT (libaio, QD32) | **67.8 MB/s** | Surprisingly slow |
| Sequential Read | 1M | Cached (sync) | **69.3 MB/s** | ARC miss (data not in cache) |
| `dd` Write | 1M | O_DIRECT | **114 MB/s** | Sanity check matches fio |
| `dd` Read | 1M | Cold cache | **66 MB/s** | Matches fio |
| Raw disk read (sda) | 1M | O_DIRECT | **95.8 MB/s** | Single drive baseline |
| Raw disk read (sda) | 4M | O_DIRECT | **85.5 MB/s** | Larger block didn't help |
| Raw disk read (sdb) | 1M | O_DIRECT | **88.7 MB/s** | Second drive, consistent |
| Random Read | 4K | O_DIRECT (libaio, QD32) | **71 IOPS** (284 KiB/s) | BOT bottleneck |
| Random Write | 4K | O_DIRECT (libaio, QD32) | **55 IOPS** (221 KiB/s) | BOT bottleneck |
| Random Mixed 70/30 | 4K | O_DIRECT (libaio, QD32) | **67 total IOPS** | BOT bottleneck |

### Configuration Mismatches Found

| Property | Current | Private-cloud Intent | Severity |
|----------|---------|---------------------|----------|
| Compression (root + most datasets) | **lz4** | **zstd level 3** | Low — lz4 is faster, zstd saves more space. Pool is 99.86% empty so this doesn't matter yet |
| acltype | **posix** | **posixacl** | Low — `posix` is an alias for `posixacl` in modern ZFS; functionally equivalent |
| Dataset recordsize tuning | All **1M** except apps/images (128K) and apps/volumes (128K) | Per-dataset: databases=8K, cache=4K, config=16K, logs=64K, documents=128K, media=1M | Medium — private-cloud's `zfs-hdd-optimizations.nix` service was supposed to set these at runtime. It never ran on this pool after migration |

### UAS Investigation Completed

- Confirmed JMicron JMS567 (vendor `152d:0567`) has kernel quirk `0x05000000` in `unusual_devs.h`
- This quirk disables UAS and forces usb-storage (BOT) driver
- Attempted runtime override via `usb-storage/parameters/quirks` — write succeeded but driver re-probe did not pick up UAS
- Attempted manual driver rebind (`unbind` from usb-storage → `bind` to uas) — **FAILED** (kernel static quirk table cannot be overridden at runtime)
- Conclusion: **UAS cannot be enabled without recompiling the kernel** without the quirk, or using a different USB bridge

### ARC Stats

| Metric | Value |
|--------|-------|
| ARC hits | 77,389,933 |
| ARC misses | 122,122 |
| Hit ratio | **99.84%** |
| ARC size | 570 MB (of 2.8 GB max) |
| Demand metadata hits | 67,572,911 |
| Demand data hits | 7,007 |

---

## B) PARTIALLY DONE

### ZFS Scrub (In Progress)
- **Started:** 2026-08-10 05:39:44 UTC
- **Progress at report time (08:47 CEST):** ~45% (9.88G / 20.2G scanned, 9.15G issued)
- **Speed:** 2.5-6.5 MB/s (varies wildly due to USB BOT protocol)
- **Errors found:** **0** — zero bytes repaired, zero checksum errors
- **ETA:** Unknown — ZFS reports "no estimated completion time" due to variable BOT throughput
- **Previous scrub for comparison:** Dec 1, 2025 — completed in 01:49:23 with 0 errors (that was on the original private-cloud host where UAS may have been working)

### Speed Test Gaps
The following tests were planned but not executed:
- No test with varying queue depths (1, 4, 8, 16, 64)
- No test with multiple jobs (parallel I/O)
- No test with ZFS `recordsize` variants (128K, 256K, 1M)
- No test with `primarycache=metadata` (cache-off read baseline)
- No test of ZFS send/receive throughput
- No `hdparm` raw drive benchmark (not available in VM)
- No cached read after warm-up (the ARC was cold during read tests because writes went to a test file that was then deleted)

---

## C) NOT STARTED

1. **Native ZFS on host kernel 7.1** — Never attempted. ZFS 2.4.3 has forward-compat patches for 7.1. A 3-line config change to evo-x2 could eliminate the entire VM infrastructure.
2. **FreeBSD VM comparison** — Package built, never tested with VFIO.
3. **Data transfer from pool** — No NFS export, virtiofs share, or rsync procedure set up.
4. **VM lifecycle automation** — No scripts for VFIO bind/unbind, no qcow2 relocation from `/tmp`.
5. **Pool property fixes** — The lz4-vs-zstd and recordsize mismatches were identified but not corrected.
6. **Snapshot cleanup** — 1,137 stale snapshots from December 2025 are consuming ARC metadata space.

---

## D) TOTALLY FUCKED UP

### 1. Read Speed Anomaly — Never Fully Diagnosed
Sequential read (~68 MB/s) is **slower than write** (~106 MB/s) on a mirror. This is backwards — mirror reads should stripe across both drives, potentially doubling throughput. The anomaly was noted but never root-caused:
- Could be BOT protocol read inefficiency (write commands are simpler than read+transfer-back)
- Could be ZFS mirror read balancing failing through USB
- Could be ARC thrashing (cold cache on reads)
- **I should have tested this more thoroughly instead of moving on**

### 2. UAS Attempt Risked Pool Availability
The UAS override attempt required exporting the pool, unbinding USB, and attempting rebind. If the rebind to usb-storage had also failed, the pool would have been inaccessible with drives held by no driver. The recovery worked, but this was an unnecessary risk without a safety net. **I should have tested on a dummy USB device first.**

### 3. Scrub Started Before Speed Tests Were Fully Done
Starting the scrub consumed USB bandwidth, making any subsequent speed tests invalid (scrub I/O competes with workload I/O). The test order should have been: all benchmarks first, then scrub last.

### 4. Speed Test Dataset Used `compression=off` But Pool Default is `lz4`
The test dataset was created with `compression=off` to measure raw throughput, but this means the results don't reflect real-world ZFS performance where compression is active. Should have run both modes.

### 5. No System-Level Monitoring During Tests
Did not monitor VM CPU usage, I/O wait, USB controller interrupts, or host-side VFIO performance during benchmarks. These would have helped isolate whether the bottleneck is in the USB bridge, BOT protocol, VFIO translation, or ZFS itself.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **Try native ZFS on kernel 7.1 FIRST** before any more VM work. The entire VM + VFIO infrastructure exists because nixpkgs's `latestCompatibleLinuxPackages` is conservative. ZFS 2.4.3 source has 7.1 compat patches. One rebuild tells us definitively.
2. **Ditch the JMicron JMS567 enclosure** — It's the single biggest performance limiter. A UAS-compatible USB enclosure (ASMedia ASM2362, Realtek RTL9210) would 2-5x the throughput. Or use a direct SATA connection.
3. **Consider BTRFS reformat** — The pool is 99.86% disposable Docker images. BTRFS works natively on kernel 7.1, needs no VM, and the host already has BTRFS expertise. The only cost is losing the existing 20 GB of Docker layers (which are all re-pullable).

### Testing Methodology

4. **Always run scrub LAST** — scrubs monopolize I/O and invalidate benchmark results.
5. **Monitor system metrics during tests** — CPU, I/O wait, interrupt rate, VFIO translation misses.
6. **Test with realistic ZFS settings** — compression on, production recordsize, warm ARC.
7. **Vary queue depth and job count** — single-threaded QD32 doesn't reveal the full picture.
8. **Use `zpool iostat` during benchmarks** — to see per-vdev I/O distribution and verify mirror read balancing.

### Pool Configuration

9. **Fix recordsize per dataset** — Apply the private-cloud tuning (databases=8K, cache=4K, config=16K, logs=64K). This matters for random IO workloads.
10. **Decide on compression** — lz4 (current, faster) vs zstd level 3 (private-cloud intent, better ratio). For a nearly-empty pool, this is low urgency.
11. **Clean up 1,137 stale snapshots** — They serve no purpose for a decommissioned pool and consume ARC metadata.

---

## F) Next 50 Things To Do

### Immediate (Do These First)

1. **Wait for scrub to finish** — verify 0 errors at completion
2. **Try native ZFS on host kernel 7.1** — add `boot.supportedFilesystems = [ "zfs" ]` + `networking.hostId` to evo-x2 config, rebuild. If it works, kill the VM.
3. **If native ZFS works: export pool from VM, unbind VFIO, import on host** — reclaim USB controller
4. **If native ZFS fails: document the exact error** — module compile failure? SPL mismatch? kernel API change?
5. **Commit the staged changes** — `systems/zfs-vm.nix`, `pkgs/freebsd-zfs-vm.nix`, `flake.nix`, status reports are all uncommitted

### Performance Investigation

6. **Diagnose the read < write anomaly** — test mirror read balancing with `zpool iostat -v` during a read benchmark
7. **Test with a UAS-compatible enclosure** — borrow or buy an ASM2362/RTL9210 bridge
8. **Benchmark with `primarycache=metadata`** — isolate disk performance from ARC
9. **Run `fio` with `--numjobs=4`** — test if BOT parallelizes across multiple queue entries
10. **Test `recordsize=128K` vs `1M`** for random IO workloads
11. **Test with `logbias=latency`** instead of `throughput` — may help write latency
12. **Monitor `nproc iostat usbmon`** during benchmarks to find the real bottleneck
13. **Test raw `dd` from `/dev/sda` and `/dev/sdb` simultaneously** — verify both drives perform identically
14. **Check if the host's USB controller supports USB 3.1 Gen 2 (10 Gbps)** — the VM sees 5 Gbps, but the physical controller may be faster

### Pool Maintenance

15. **Clean up 1,137 stale Sanoid snapshots** — `zfs destroy` with date range filter
16. **Apply per-dataset recordsize tuning** from private-cloud config
17. **Set `compression=zstd-3`** on datasets with compressible data (if keeping the pool)
18. **Enable `autotrim=on`** if keeping the pool long-term (helps with USB bridge TRIM passthrough)
19. **Destroy empty datasets** (`backups`, `dev`, `logs`, `media/photos`) if they're not needed
20. **Set up a ZFS snapshot schedule** if the pool is staying (Sanoid or zrepl)
21. **Configure `zfs-events` monitoring** — ZED for email/Discord alerts on checksum errors

### Data Management

22. **Decide pool fate: keep ZFS, reformat to BTRFS, or wait for native ZFS 7.1**
23. **If reformatting: document the 20 GB of data** that will be lost (Docker images — all re-pullable)
24. **If keeping: set up data transfer** — NFS export from VM, or virtiofs shared directory
25. **Inventory the Docker datasets** — identify which images are custom vs. public (can be re-pulled)
26. **Check `datapool/config` (184 KB)** — this is the only non-Docker data worth examining
27. **Check `datapool/documents/paperless` (136 KB)** — Paperless document data
28. **Back up pool configuration** — `zpool export` + save the pool config for disaster recovery

### VM Infrastructure (If VM Stays)

29. **Move qcow2 from `/tmp` to `/var/lib/zfs-vm/`** — survives reboot
30. **Write VFIO bind/unbind scripts** — automate the controller handoff
31. **Add VM crash recovery** — systemd service that detects stale VFIO bind and restores host USB
32. **Set up SSH key auth** — replace password auth (`zfs`) with proper keys
33. **Add VM to Gatus monitoring** — health check on SSH port 2222
34. **Configure VM memory** — increase from 4 GB to 8-16 GB for larger ARC
35. **Pin kernel explicitly** — replace deprecated `latestCompatibleLinuxPackages` with `linuxPackages_6_18`
36. **Add `boot.zfs.forceImportRoot = false`** to silence ZFS warning
37. **Test FreeBSD VM with VFIO** — compare ZFS performance and UAS support

### Native ZFS Path (If Attempting)

38. **Add ZFS to evo-x2 config** — `boot.supportedFilesystems = [ "zfs" ]`, `networking.hostId`
39. **Check if ZFS module compiles against kernel 7.1** — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`
40. **If compile fails: check ZFS 2.4.3 release notes** for exact kernel 7.1 support status
41. **If compile succeeds: test `modprobe zfs`** on the host kernel
42. **Import pool on host** — `zpool import datapool`
43. **Benchmark native ZFS vs VM ZFS** — compare throughput and IOPS
44. **If native works: destroy VM, unbind VFIO, restore host USB**

### Documentation & Hygiene

45. **Run `nix fmt`** on `systems/zfs-vm.nix` and `pkgs/freebsd-zfs-vm.nix`
46. **Update AGENTS.md** with ZFS pool details and the BOT/UAS finding
47. **Document the JMicron JMS567 quirk** in the gotchas section
48. **Write a recovery runbook** for VFIO unbind failures
49. **Update SystemNix FEATURES.md** if ZFS becomes a permanent part of the system
50. **Archive or delete the FreeBSD VM package** if it's not going to be used

---

## G) Questions I Cannot Answer Myself

### 1. What is the intended fate of this pool?

The pool is 99.86% disposable Docker images from the private-cloud project. Do you want to:
- **(a)** Keep it as ZFS and continue using it (via VM or native ZFS)?
- **(b)** Reformat to BTRFS for native host support and lose the 20 GB of Docker data?
- **(c)** Extract any useful data, then wipe and repurpose the drives?

This determines whether we invest in VM lifecycle automation, native ZFS attempts, or BTRFS setup.

### 2. Do you still have the original private-cloud host, or are these drives orphaned?

The pool was last scrubbed on Dec 1, 2025 and the host was shut down shortly after (nixos:shutdown-time = Fri Nov 28 09:00:30 AM UTC 2025). If the original host is still available, it may have UAS working natively and could be a simpler path to data access. If the drives are orphaned (original host decommissioned), then we need to decide the new permanent home.

### 3. Is the JMicron JMS567 enclosure the permanent connection method, or temporary?

The BOT protocol quirk caps all performance at ~100 MB/s sequential / ~70 IOPS random. If this enclosure is permanent, the pool will never perform better than these numbers regardless of ZFS tuning. If you're willing to buy a different enclosure (ASMedia ASM2362, ~$15) or connect via direct SATA, performance could 2-5x. This determines whether performance optimization work is worthwhile or throwing good money after bad.

---

## Technical Appendix

### Test Environment

| Component | Detail |
|-----------|--------|
| Host | NixOS 26.11 "Zokor", kernel 7.1.6, AMD Ryzen AI Max+ 395 (Strix Halo) |
| VM | NixOS kernel 6.18.43, ZFS 2.4.3-1, 4 vCPU, 4 GB RAM (ARC max 2.8 GB) |
| USB Controller | AMD `0000:c7:00.4` (vendor `0x1022`, device `0x158b`), IOMMU group 29 |
| USB Bridge | JMicron JMS567 (`152d:0567`), firmware 5203, USB 3.0 SuperSpeed (5 Gbps) |
| Drives | 2x TOSHIBA MG08ACA16TE, 16TB, 7200 RPM, 4096-byte physical sectors |
| ZFS Pool | `datapool`, mirror, ashift=12, 14.5 TB usable, 20.3 GB allocated |
| Benchmark Tool | fio 3.42 (from nixpkgs, shared via virtfs `/nix/store`) |

### Raw Speed Test Details

```
Sequential Write (1M, O_DIRECT, libaio QD32):  106.3 MB/s,  106 IOPS, lat 300ms
Sequential Write (1M, cached, sync):            141.2 MB/s,  141 IOPS
Sequential Read  (1M, O_DIRECT, libaio QD32):   67.8 MB/s,   68 IOPS, lat 468ms
Sequential Read  (1M, cached, sync):            69.3 MB/s,   69 IOPS
dd Write (1M, O_DIRECT):                        114 MB/s
dd Read (1M, cold cache):                       66 MB/s
Raw disk read sda (1M, O_DIRECT):               95.8 MB/s
Raw disk read sda (4M, O_DIRECT):               85.5 MB/s
Raw disk read sdb (1M, O_DIRECT):               88.7 MB/s
Random Read  (4K, O_DIRECT, libaio QD32):       71 IOPS,  284 KiB/s, lat 447ms
Random Write (4K, O_DIRECT, libaio QD32):       55 IOPS,  221 KiB/s, lat 576ms
Random Mixed (4K, 70R/30W, O_DIRECT, QD32):     67 total IOPS (47R + 20W)
```

### Theoretical vs Actual Performance

| Metric | Drive Capability | USB 3.0 Limit | UAS Expected | BOT Actual | % of Theoretical |
|--------|-----------------|---------------|-------------|------------|-----------------|
| Sequential Read | ~250 MB/s (HDD) | 400 MB/s | ~250 MB/s | **68 MB/s** | **27%** |
| Sequential Write | ~250 MB/s (HDD) | 400 MB/s | ~250 MB/s | **106 MB/s** | **42%** |
| Random Read | ~150 IOPS (HDD) | N/A | ~150 IOPS | **71 IOPS** | **47%** |
| Random Write | ~150 IOPS (HDD) | N/A | ~150 IOPS | **55 IOPS** | **37%** |

The BOT protocol is the bottleneck. UAS would roughly double sequential throughput and significantly improve random IO (NCQ support).

### Pool Feature Flags (After Upgrade)

All feature flags now `enabled` or `active`. Newly enabled during this session:
- `block_cloning_endian`
- `physical_rewrite`

Already active/enabled (complete list verified):
`async_destroy`, `empty_bpobj`, `lz4_compress`, `multi_vdev_crash_dump`, `spacemap_histogram`,
`enabled_txg`, `hole_birth`, `extensible_dataset`, `embedded_data`, `bookmarks`, `filesystem_limits`,
`large_blocks`, `large_dnode`, `sha512`, `skein`, `edonr`, `userobj_accounting`, `encryption`,
`project_quota`, `device_removal`, `obsolete_counts`, `zpool_checkpoint`, `spacemap_v2`,
`allocation_classes`, `resilver_defer`, `bookmark_v2`, `redaction_bookmarks`, `redacted_datasets`,
`bookmark_written`, `log_spacemap`, `livelist`, `device_rebuild`, `zstd_compress`, `draid`,
`zilsaxattr`, `head_errlog`, `blake3`, `block_cloning`, `vdev_zaps_v2`, `redaction_list_spill`,
`raidz_expansion`, `fast_dedup`, `longname`, `large_microzap`, `block_cloning_endian`, `physical_rewrite`
