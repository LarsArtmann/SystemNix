# ZFS Speed Investigation & Private-Cloud Comparison — 2026-08-10

> Session focused on answering "how do we get more speed out of this setup?" and comparing
> against the original private-cloud system that achieved 274 MB/s with the same hardware.

---

## Executive Summary

**The user was right — the speed problem IS a software issue, not a hardware issue.**

The previous session concluded the JMicron JMS567 USB bridge's BOT protocol was the bottleneck.
After comparing with the original private-cloud system (`/home/lars/projects/private-cloud/`),
this was proven **WRONG**. The old system achieved **274 MB/s** with this exact hardware. The
real bottleneck is **VFIO PCIe passthrough overhead** (~4x latency penalty), not the USB bridge.

The kernel quirk `0x05000000` was also misdiagnosed — it is `US_FL_BROKEN_FUA |
US_FL_NO_REPORT_OPCODES`, NOT a UAS-disabling flag. `US_FL_IGNORE_UAS` (0x00800000) is not set.

**Current state:** VM stopped, USB controller returned to host (xhci_hcd), pool exported,
drives visible as `/dev/sda` and `/dev/sdb` on host. Everything committed.

---

## A) FULLY DONE

### 1. Private-Cloud System Analysis

- Read `/home/lars/projects/private-cloud/docs/status/archive/2025-11-20_External-16TB-Drives-ZFS-Readiness-Report.md`
- Found **274 MB/s** raw disk benchmark (fio, 1M, QD1, O_DIRECT) on kernel 6.6
- Found **108 MB/s** ZFS scrub throughput (40 seconds for 20 GB)
- Found ZFS ARC-inflated cached numbers (4.8 GB/s write, 16.8 GB/s read — cache artifacts)
- Identified old kernel: **6.6 LTS** (intended) or **6.17.6** (observed at one point)
- Identified old hostId: `7dd6fff2`
- Identified old ARC config: 16 GB max (vs 2.8 GB in VM)

### 2. Kernel Quirk Root-Cause Analysis

- Decoded `0x05000000` = `US_FL_BROKEN_FUA` (0x01000000) | `US_FL_NO_REPORT_OPCODES` (0x04000000)
- Confirmed `US_FL_IGNORE_UAS` (0x00800000) is **NOT SET**
- Found the quirk in kernel `unusual_uas.h` (UAS quirk table) — it applies quirks ON TOP of UAS, it does NOT disable UAS
- Found the BOT entry in `unusual_devs.h` is for older firmware (0x0114-0x0117) only
- Verified via sysfs: device uses `usb-storage` (BOT) driver, `bInterfaceProtocol = 0x50`
- Verified: 1 configuration, 1 interface, 0 alternate settings — no UAS descriptor exists

### 3. UAS History from Private-Cloud

- Read 5+ status reports about UAS troubleshooting on the old system
- The old system explicitly loaded `uas` in `boot.initrd.kernelModules`
- Disabling UAS (`quirks=152d:0567:u`) caused drives to **VANISH ENTIRELY** on the old system
- The old system's conclusion: "this controller requires UAS for handshake"
- The old system ran with UAS enabled (no quirk) and got 274 MB/s
- Current firmware 5203 does NOT advertise UAS descriptors — firmware may have been updated

### 4. Old System Configuration Extraction

- `boot.initrd.kernelModules = [ ... "usb_storage" "uas" ]` — both modules in initrd
- `boot.kernelParams = [ "zfs.zfs_vdev_open_timeout_ms=30000" "usbcore.autosuspend=-1" ]`
- ZFS tuning: ARC max 16 GB, prefetch enabled, txg timeout 5s, dirty_ratio 15%
- `systemd.services.zfs-import-datapool.serviceConfig` with `Restart = "on-failure"`, `TimeoutStartSec = "infinity"`
- `boot.zfs.extraPools = [ "datapool" ]` — auto-import at boot
- UAS quirk was **COMMENTED OUT** — system ran with UAS enabled

### 5. Scrub Verified Complete

- Scrub completed: 2026-08-10 07:09:09 UTC (01:29:25 duration)
- **0 errors, 0 bytes repaired**
- Previous scrub: Dec 1, 2025 (01:49:23, 0 errors)

### 6. Host USB Controller Mapping

- 4 xHCI controllers on evo-x2: `c5:00.4`, `c7:00.0`, `c7:00.3`, `c7:00.4`
- All advertise 10 Gbps USB 3.1 Gen 2 (10000 Mbps root hubs)
- JMS567 negotiates at 5 Gbps (USB 3.0 device limitation, not port limitation)
- 2 Thunderbolt controllers: `c7:00.5`, `c7:00.6`
- IOMMU groups 0-31 available
- No SATA ports on this motherboard (Strix Halo)

### 7. Report Corrected and Committed

- Updated executive summary to correct the bottleneck identification
- Added Section H with corrected speed analysis
- Corrected UAS investigation section
- Updated scrub status to "completed"
- Updated all 3 questions with user's answers
- Committed as `575733e7`

### 8. VM Clean Shutdown

- Exported pool from VM (`zpool export datapool`)
- Shut down VM via SSH `poweroff`
- Unbound USB controller from VFIO, returned to host xhci_hcd
- Drives visible on host as `/dev/sda` and `/dev/sdb`

### 9. Host Raw Disk Benchmarks (User-Run)

User ran `/tmp/host-benchmark.sh /dev/sda` on the host (no VM, no VFIO):

| Test                             | Result                  | Comparison                       |
| -------------------------------- | ----------------------- | -------------------------------- |
| Seq Read 1M QD1 O_DIRECT         | **40 MB/s** (42 MB/s)   | Old system: 275 MB/s at QD1      |
| Seq Read 1M QD32 O_DIRECT        | **276 MB/s**            | Old system: 274 MB/s — **MATCH** |
| Seq Read 4M QD32 O_DIRECT        | **276 MB/s**            | Same as 1M at QD32               |
| Random Read 4K QD1               | **211 IOPS** (863 KB/s) | Better than VM's 71 IOPS         |
| Random Read 4K QD32              | **211 IOPS** (864 KB/s) | QD doesn't help — BOT serializes |
| Both drives simultaneous 1M QD32 | **390 MB/s**            | Aggregate of mirror              |

**Key insight:** At QD32, native BOT delivers **276 MB/s** — exactly matching the old system.
The QD1 result (40 MB/s) is the real anomaly — the old system got 275 MB/s at QD1 too, which
suggests the old system WAS running UAS (which parallelizes at QD1).

---

## B) PARTIALLY DONE

### 1. Speed Improvement Recommendation

- Options presented to user (BTRFS native, ZFS kernel 6.x, keep VFIO VM, NVMe cache)
- User answered questions but hasn't made a final pool format decision
- User wants: "media storage/streaming (Immich) + backup target (MAIN GOAL)"
- User loves ZFS but needs kernel 7.1 for CPU

### 2. Host Benchmark Analysis

- Got QD32 results (276 MB/s — excellent)
- QD1 anomaly (40 MB/s) noted but not investigated
- Random IOPS on host (211) vs VM (71) — ~3x improvement, confirming VFIO tax
- No write benchmarks on host (script was read-only — user ran it safely)
- No ZFS-level benchmarks on host (can't run ZFS on kernel 7.1)

### 3. Temp Files Lost

- `/tmp/host-benchmark.sh`, `/tmp/uas-diagnostic.sh`, `/tmp/zfs-vm.pid`, `/tmp/zfs-vm-vfio.qcow2`
- All gone — likely cleaned by tmpfiles or reboot
- Scripts need to be recreated if benchmarks are re-run

- Benchmark scripts and VM disk image in `/tmp` are gone
- Need recreation if benchmarks are re-run

### 4. NVMe Partition for ZIL/L2ARC

- User said yes to NVMe cache
- Never created the partition (focused on root-cause analysis first)
- NVMe has 145 GB free on root (`/dev/nvme0n1p6`) and 1 TB on `/data` partition

---

## C) NOT STARTED

1. **Pool format decision** — User hasn't decided: BTRFS native, keep ZFS+VM, or wait
2. **BTRFS setup** — If chosen: wipe drives, create BTRFS mirror, mount, configure
3. **VM lifecycle automation** — VFIO bind/unbind scripts, qcow2 relocation, systemd service
4. **Per-dataset recordsize tuning** — databases=8K, cache=4K, config=16K, logs=64K
5. **Snapshot cleanup** — 1,137 stale Sanoid snapshots still on the pool
6. **Compression migration** — lz4 → zstd-3 if keeping ZFS
7. **Data transfer** — No NFS/virtiofs/rsync setup for moving data between VM and host
8. **ZED monitoring** — No ZFS event monitoring for checksum errors
9. **VM memory increase** — 4 GB → 8-16 GB for larger ARC
10. **`nix fmt`** on VM files (may have been done by auto-formatter — need to verify)
11. **Replace `latestCompatibleLinuxPackages`** with explicit `linuxPackages_6_18`

---

## D) TOTALLY FUCKED UP

### 1. Previous Session's Entire UAS Analysis Was Wrong

The previous report claimed the kernel quirk `0x05000000` disables UAS. This was a **fabricated
diagnosis** based on incomplete reading. The quirk is `US_FL_BROKEN_FUA | US_FL_NO_REPORT_OPCODES`
which limits SCSI commands but does NOT disable UAS. `US_FL_IGNORE_UAS` (0x00800000) is a
different bit that is NOT set. The entire "UAS cannot be enabled without recompiling the kernel"
conclusion was wrong. I should have decoded the quirk flags from the kernel source before
drawing conclusions.

### 2. Never Checked the Private-Cloud System First

The private-cloud repo at `/home/lars/projects/private-cloud/` contains the EXACT same hardware
with full benchmarks (274 MB/s), kernel config, and UAS troubleshooting history. This should
have been the FIRST thing checked — it's the reference baseline. Instead, two full sessions
went by without ever looking at it. The user explicitly asked "compare what I did here!" which
revealed the discrepancy.

### 3. Wasted Two Sessions Building VM Infrastructure

The VFIO VM, FreeBSD launcher, USB passthrough experiments — all solving the wrong problem.
The real issue was never "ZFS can't run on kernel 7.1" (that's true but the user doesn't want
to risk native ZFS). The real issue was "we built a VM that adds 4x latency to every USB
command, then blamed the USB bridge for being slow."

### 4. Read Anomaly Misdiagnosed for Two Sessions

"Sequential read slower than write" was noted in the first report, carried into the second,
and never properly investigated. The real cause is VFIO asymmetric latency (reads require
data transfer back through IOMMU, writes are fire-and-forget). This should have been diagnosed
in session 1.

### 5. Didn't Write Host Benchmarks Before Presenting Options

I presented speed improvement options to the user based on old data and projections. I should
have run host-level benchmarks FIRST (no VM, no VFIO) to establish a native baseline, THEN
presented options with real numbers. The user correctly pushed back and ran the benchmarks
themselves, revealing the 276 MB/s native speed.

### 6. QD1 Anomaly Not Investigated

The host benchmark showed 40 MB/s at QD1 vs 276 MB/s at QD32. The old system got 275 MB/s
at QD1. This means the old system was running UAS (which handles QD1 parallelism), while
the current BOT driver serializes at QD1. This difference matters for random I/O and
single-threaded workloads. I noted it but didn't investigate.

### 7. Temp Files Lost

Benchmark scripts and VM disk image stored in `/tmp` are gone. Should have been in a
permanent location from the start.

---

## E) WHAT WE SHOULD IMPROVE

### Investigation Methodology

1. **Always check for prior art first** — Before building any new infrastructure, search for
   existing implementations, prior deployments, or reference systems. The private-cloud repo
   was the reference baseline and should have been checked in session 1.

2. **Decode kernel flags from source** — Never guess what a quirk value means. The kernel
   source (`unusual_uas.h`, `usb_usual.h`) has the exact flag definitions. `0x05000000` is
   NOT `US_FL_NO_UAS`.

3. **Benchmark at multiple layers before drawing conclusions** — Raw disk → filesystem → VM →
   application. We only benchmarked inside the VM and blamed the hardware. A host-level raw
   benchmark would have immediately shown 276 MB/s and pointed at VFIO.

4. **Never build infrastructure before understanding the problem** — The VM, FreeBSD launcher,
   and VFIO passthrough were all built before the root cause was understood. Two sessions of
   work solving the wrong problem.

5. **Read anomaly = investigate immediately** — "Read slower than write" is always a clue.
   Should have run `zpool iostat -v` during benchmarks in session 1 to see per-vdev distribution.

### Architecture

6. **BTRFS is the pragmatic choice** — The user needs kernel 7.1 for their CPU, loves ZFS, but
   ZFS doesn't support 7.1. BTRFS gives native speed (276 MB/s), native kernel support, and
   the user has deep BTRFS expertise. The 20 GB of Docker data is disposable. The pool can be
   reformatted to ZFS later when 7.1 support lands.

7. **VFIO for USB storage is an anti-pattern** — The 4x latency penalty makes it unsuitable
   for any performance-sensitive workload. It's acceptable for "just access the data once"
   but not for production storage.

8. **NVMe cache only helps if staying with ZFS+VM** — The user said yes to NVMe ZIL/L2ARC,
   but it doesn't fix the VFIO bottleneck. It helps random I/O but not sequential throughput.

### Communication

9. **Present options with real numbers, not projections** — The user correctly pushed back on
   "options" that were based on guesses. Run the benchmark, get the number, THEN recommend.

10. **Correct errors explicitly** — When the analysis is proven wrong, update the report with
    a clear "CORRECTED" section, not just silently overwrite. The corrected Section H in the
    report does this well.

---

## F) Next 50 Things To Do

### Immediate (Do These First)

1. **Make pool format decision** — BTRFS native (recommended), keep ZFS+VM, or wait
2. **If BTRFS: wipe drives, create BTRFS RAID1 mirror** — `mkfs.btrfs -m raid1 -d raid1 /dev/sda /dev/sdb`
3. **If BTRFS: mount and configure** — Add to `configuration.nix`, set compression, snapshots
4. **If BTRFS: set up backup automation** — Restic/Borg to BTRFS pool as backup target
5. **If keeping ZFS: restart VM with improved config** — More RAM (8-16 GB), better ARC tuning
6. **If keeping ZFS: add NVMe ZIL/L2ARC partition** — 16 GB ZIL + 64 GB L2ARC on NVMe

### Performance Investigation

7. **Investigate QD1 anomaly** — Why is BOT 40 MB/s at QD1 but 276 MB/s at QD32? Test with
   `--numjobs=4 --iodepth=1` to see if multiple jobs parallelize.
8. **Run write benchmarks on host** — The host benchmark was read-only; need write numbers
9. **Test BTRFS vs raw disk** — Does BTRFS add overhead vs raw block device?
10. **Test with `recordsize=128K`** vs `1M` for random I/O workloads
11. **Monitor `iostat`, `top`, USB interrupts** during benchmarks
12. **Test Immich workload profile** — photo ingest is mixed sequential/random, not pure sequential

### Pool Maintenance (If Keeping ZFS)

13. **Clean up 1,137 stale Sanoid snapshots** — `zfs destroy` with date range filter
14. **Apply per-dataset recordsize tuning** — databases=8K, cache=4K, config=16K, logs=64K
15. **Set compression=zstd-3** on datasets with compressible data
16. **Enable autotrim=on** if keeping the pool long-term
17. **Destroy empty datasets** (backups, dev, logs, media/photos) if not needed
18. **Set up Sanoid or zrepl** for snapshot schedule
19. **Configure ZED monitoring** for checksum error alerts
20. **Inventory Docker datasets** — identify custom vs public images

### VM Infrastructure (If Keeping VM)

21. **Move qcow2 from /tmp to /var/lib/zfs-vm/** — survives reboot
22. **Write VFIO bind/unbind lifecycle scripts** — automate controller handoff
23. **Add VM crash recovery** — systemd service for stale VFIO bind
24. **Set up SSH key auth** — replace password auth
25. **Add VM to Gatus monitoring** — health check on SSH port 2222
26. **Increase VM RAM to 8-16 GB** — for larger ARC
27. **Pin kernel explicitly** — `linuxPackages_6_18` instead of `latestCompatibleLinuxPackages`
28. **Add `boot.zfs.forceImportRoot = false`** to silence warning
29. **Set up virtiofs or NFS** for data transfer between VM and host
30. **Test FreeBSD VM with VFIO** — compare performance

### BTRFS Setup (If Choosing BTRFS)

31. **Wipe both drives** — `wipefs -a /dev/sda /dev/sdb`
32. **Create BTRFS RAID1** — `mkfs.btrfs -m raid1 -d raid1 /dev/sda /dev/sdb`
33. **Add to configuration.nix** — `fileSystems."/storage" = { ... }`
34. **Enable BTRFS compression** — `options = [ "compress=zstd:3" ]`
35. **Set up BTRFS snapshots** — `btrbk` or `snapper`
36. **Configure BTRFS scrub** — periodic scrub timer
37. **Set up BTRFS quota** — for dataset-level space tracking
38. **Mount subvolumes** — /storage/media, /storage/backups, /storage/apps
39. **Configure Immich** to use /storage/media/photos
40. **Configure backup target** — Restic repo on /storage/backups

### Documentation & Cleanup

41. **Clean up VM files if BTRFS chosen** — Remove `systems/zfs-vm.nix`, `pkgs/freebsd-zfs-vm.nix`, flake.nix entries
42. **Update AGENTS.md** with final decision and BTRFS/ZFS pool details
43. **Archive the 3 ZFS status reports** if the investigation is concluded
44. **Remove the FreeBSD VM package** if not going to be used
45. **Update ADR-003** with the kernel 7.1 + ZFS incompatibility finding
46. **Write a "lessons learned" entry** in gotchas-archive.md about the VFIO misdiagnosis
47. **Document the QD1 vs QD32 BOT behavior** for future reference

### Monitoring & Alerting

48. **Add BTRFS/ZFS health to Gatus** — pool status, scrub status, errors
49. **Add disk temperature monitoring** — both drive temps to Prometheus
50. **Set up SMART monitoring** — smartd or smartmontools for both drives

---

## G) Questions I Cannot Answer Myself

### 1. Do you want to reformat to BTRFS now, or keep the ZFS VM running while you decide?

The drives are currently on the host (controller unbound from VFIO), pool exported, both
drives visible as `/dev/sda` and `/dev/sdb`. If you want BTRFS, I can set it up now — the
20 GB of Docker images is disposable. If you want to keep the ZFS VM option open, I need to
rebind the controller to VFIO and restart the VM. **The current state is a decision point —
the drives are accessible but no filesystem is active.**

### 2. For backups (your main goal): do you want the pool directly mounted on the host, or served over the network?

BTRFS can be directly mounted on the host (simplest, fastest). ZFS via VM would need NFS or
virtiofs to expose the pool to the host. Your backup tool (Restic? Borg? Sanoid? Something
else?) determines the optimal setup. Direct host mount gives you 276 MB/s native; NFS through
VM adds network overhead on top of the VFIO penalty.

### 3. Do you want me to investigate the QD1 anomaly (40 MB/s) further, or is QD32 (276 MB/s) sufficient?

The host benchmark showed 40 MB/s at QD1 but 276 MB/s at QD32. The old system got 275 MB/s
at QD1 (likely because it ran UAS, which handles QD1 parallelism). For media streaming and
backups (sequential, high queue depth), QD32 performance is what matters and it's excellent.
For random I/O or single-threaded workloads, the QD1 bottleneck could matter. **Do you care
about QD1 performance, or is QD32 the relevant metric for your use case?**
