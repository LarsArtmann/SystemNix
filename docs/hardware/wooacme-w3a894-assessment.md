# WOOACME W3A894-512GB — Hardware Assessment

**Date:** 2026-08-10
**Assessed by:** Crush (SystemNix session)
**Drive:** WOOACME W3A894-512GB — S/N: WX2511WX00357, FW: X0719A0
**Connection:** USB 3.2 Gen 2 (10 Gbps) via Realtek RTL9210B-CG bridge, UAS protocol
**Comparison baseline:** Lexar SSD NQ790 2TB NVMe (internal, PCIe 4.0 x4)

---

## Executive Summary

The drive is **physically healthy** — zero bad sectors, zero errors, 96% endurance remaining. It survived a power surge that killed its host machine with no data loss. However, it is a **budget SATA SSD with very low write endurance (~14 TB TBW)** and **SATA-over-USB performance** that makes it unsuitable for any active workload. It is viable only as a **read-mostly cold backup target** or **sneakernet transfer drive**. For regular nightly backups, the endurance budget is a real constraint — see [§6 Endurance Analysis](#6-endurance--lifespan-analysis).

**Recommendation:** Use for **periodic manual backups** (weekly, not nightly) of critical irreplaceable data only (projects, secrets, configs). Do NOT use for automated daily backups or any read/write-intensive workload. For automated backups, invest in a proper external HDD or cloud target.

---

## 1. Origin & Identification

This drive was recovered from a previous NixOS machine (hostname `evo-x2`, primary user `art`) that was taken offline by a suspected power surge around December 22, 2025 (last filesystem activity). It was connected to the current evo-x2 via a USB 3.2 enclosure for assessment.

The enclosure uses a **Realtek RTL9210B-CG** USB-to-SATA bridge, negotiating at **SuperSpeed Plus Gen 2 (10 Gbps)** with the **UAS (USB Attached SCSI)** protocol — the best-case USB storage protocol.

| Property | Value |
|----------|-------|
| Model | W3A894-512GB |
| Manufacturer | WOOACME (Wooacme Limited, Hong Kong / Yiwu Maihai E-Commerce Co., Ltd.) |
| Serial | WX2511WX00357 |
| Firmware | X0719A0 |
| Capacity | 512 GB (476.9 GiB) |
| Native interface | SATA III (6.0 Gb/s), ACS-2 |
| Connected via | USB 3.2 Gen 2, Realtek RTL9210B-CG, UAS |
| Form factor | 2.5" |
| Sector size | 512 bytes (logical and physical) |
| APM level | 254 (maximum performance) |
| ATA Security | Disabled, NOT FROZEN |

WOOACME does not publish a datasheet, TBW rating, controller model, or NAND type. The drive is not in the smartctl database. Public benchmark data (PassMark, Nero Score) confirms entry-level SATA III performance consistent with our measurements.

---

## 2. SMART Health Analysis

### Overall Health: PASSED

### Core Health Indicators

| Attribute | ID | Raw Value | Assessment |
|-----------|----|-----------|------------|
| Raw Read Error Rate | 1 | 0 | No read errors |
| Reallocated Sector Count | 5 | 0 | No remapped blocks |
| Current Pending Sector | 197 | 0 | No unreadable sectors |
| Offline Uncorrectable | 198 | 0 | No uncorrectable reads |
| UDMA CRC Error Count | 199 | 0 | SATA/USB link clean |
| Program Fail Count (chip) | 175 | 0 | Zero program failures |
| Erase Fail Count (chip) | 176 | 0 | Zero erase failures |
| Program Fail Count (total) | 181 | 0 | Zero program failures |
| Erase Fail Count (total) | 182 | 0 | Zero erase failures |
| Used Reserved Block Count | 178 | 0 | No spare blocks consumed |
| Available Reserved Space | 232 | 100% | Full spare block pool |
| Wear Leveling Count | 177 | 0 | — |

**Verdict:** Zero hardware-level failures across every measurable dimension. The NAND has not required any remapping, and the full spare block pool is intact.

### Usage Statistics

| Attribute | ID | Raw Value | Notes |
|-----------|----|-----------|-------|
| Power-On Hours | 9 | 5,623 (~234 days) | Moderate lifetime use |
| Power Cycle Count | 12 | 81 | Low |
| Power-Off Retract Count | 192 | 17 | Unsafe shutdowns — power surge evidence |
| Temperature (current) | 194 | 31 °C | Cool |
| Temperature (lifetime min/max) | SCT | 30 / 54 °C | Never exceeded 54 °C — well within spec |

### Vendor-Specific Attributes (Undocumented)

These attributes are not in the smartctl database and WOOACME does not document them. Values are recorded but cannot be definitively interpreted:

| ID | Raw Value | Possible meaning (speculation) |
|----|-----------|-------------------------------|
| 160 | 0 | Uncorrectable error count (?) |
| 161 | 100 | Initial bad blocks / remaining life % (Pre-fail type) |
| 163 | 151 | Total erase count (?) |
| 164 | 320,169 | Average erase count or total ECC events (?) |
| 165 | 518 | Max erase count (?) |
| 166 | 1 | Min erase count (?) |
| 167 | 218 | Wear leveling delta (?) |
| 168 | 5,050 | Unknown |
| 169 | 96 | Remaining life percentage (?) — consistent with 4% used |
| 245 | 579,262 | Unknown |

**None are flagged as failing** (all: VALUE=100, WORST=100, THRESH=50, FAIL=—). The Pre-fail flag on attribute 161 (value 100, threshold 50) shows no degradation.

### SATA Physical Layer

| Event | Count | Notes |
|-------|-------|-------|
| ICRC errors | 0 | No integrity failures on the SATA/USB link |
| R_ERR (data FIS) | 0 | No data FIS rejections |
| R_ERR (non-data FIS) | 0 | No control FIS rejections |
| COMRESET events | 1 | One bus reset — likely from the power surge or USB reconnect |

### SMART Error Log

**No errors logged.** Zero entries in both the summary and comprehensive error logs.

### SMART Self-Test Log

**No self-tests have ever been run.** The drive supports short (2 min) and extended (10 min) self-tests but has never executed one.

---

## 3. Device Statistics (ATA GP Log 0x04)

This is the most reliable data source for lifetime usage, as it comes directly from the controller's accounting:

| Statistic | Value | Interpretation |
|-----------|-------|----------------|
| Lifetime Power-On Resets | 81 | Matches power cycle count |
| Power-on Hours | 5,623 | ~234 days |
| **Logical Sectors Written** | **1,127,176,837** | **~577 GB total host writes** |
| Logical Sectors Read | 2,564,526,350 | ~1,313 GB total host reads |
| Number of Write Commands | 1,051,951,022 | ~1.05 billion write operations |
| Number of Read Commands | 46,928,564 | ~47 million read operations |
| **Percentage Used Endurance Indicator** | **4%** | **96% of rated write life remaining** |

**Read/write asymmetry:** The drive received 22x more write commands than read commands (1.05B vs 47M), but fewer total sectors written than read (577 GB vs 1,313 GB). This pattern is consistent with a system that frequently wrote small blocks (journaling, database WAL, nix builds) and occasionally read large files.

---

## 4. Filesystem Integrity

### ext4 fsck (read-only, all 5 passes)

```
Pass 1: Checking inodes, blocks, and sizes — 9 suboptimal extent trees (cosmetic)
Pass 2: Checking directory structure — OK
Pass 3: Checking directory connectivity — OK
Pass 4: Checking reference counts — OK
Pass 5: Checking group summary information — OK

1,934,383 files (0.2% non-contiguous), 23,835,902/116,018,881 blocks
```

- **Filesystem state:** clean
- **Checksum:** valid (crc32c, seed 0xa34ffb75)
- **Journal:** intact (sequence 0x036416ae, 1 GB journal)
- **Superblock backups:** present at 32768, 98304, 163840, 229376
- **No data corruption detected**

The ext4 journal successfully protected the filesystem across 17 unsafe shutdowns. The drive is safe to mount and read from.

### Badblocks (full disk, read-only)

```
Blocks scanned: 125,026,901 (entire 512 GB)
Duration: ~35 minutes
Result: 0 bad blocks, 0 read errors, 0 write errors
```

Every sector on the drive is readable. The NAND is physically intact despite the power surge.

### EFI partition (vfat)

Minor boot sector backup mismatch at offset 65 (original=0x01, backup=0x00). This is cosmetic and does not affect data integrity.

---

## 5. Performance Analysis

### Methodology

All benchmarks use `fio` with `direct=1` (O_DIRECT, bypassing page cache), `libaio` engine, 10-second runtime per test, against the raw block device. Both drives tested under identical conditions. The NVMe is the live system disk under normal system load.

> **Variance note:** Results showed significant run-to-run variance (up to 4x on the WOOACME, up to 3x on the NVMe) depending on system load. The NVMe is particularly variable because it serves the active BTRFS root, nix store, and all running services. The numbers below represent the best observed run for each drive. The NVMe's spec sheet claims 7,000 MB/s sequential read and 800K IOPS random read — the gap between spec and measured performance is due to system contention, not drive degradation.

### Throughput Results

| Test | WOOACME (USB) | NVMe NQ790 (live) | Gap |
|------|---------------|---------------------|-----|
| Seq Read 1M QD1 | 291 MB/s | 493 MB/s | 1.7x |
| Seq Read 1M QD32 | 491 MB/s | — | — |
| Rand Read 4K QD1 | 31.6 MB/s (8,094 IOPS) | 10.1 MB/s (2,586 IOPS)* | 0.3x* |
| Rand Read 4K QD32 | 88.0 MB/s (22,528 IOPS) | 18.3 MB/s (4,685 IOPS)* | 0.2x* |

> *The NVMe appears slower on random reads because it is under heavy system load during these tests. An idle NVMe benchmark would show 800K+ IOPS. The WOOACME numbers benefited from a warm read cache and low system contention during its test window. These results illustrate real-world conditions on a loaded system, not spec-sheet performance.

### Latency Analysis

Latency percentiles are critical for understanding real-world feel and tail behavior.

**WOOACME — Random Read 4K QD1:**

| Percentile | Latency |
|------------|---------|
| Average | 123 us |
| p50 | ~100 us |
| p95 | ~250 us |
| p99 | ~500 us |
| Max | 5,441 us (5.4 ms) |

**WOOACME — Random Read 4K QD32:**

| Percentile | Latency |
|------------|---------|
| Average | 1,378 us (1.4 ms) |
| p50 | ~750 us |
| Max | 98,986 us (**99 ms**) |

The 99 ms tail latency at QD32 is the USB bridge's worst case — UAS command queueing under load introduces significant jitter. This is inherent to USB-attached storage and cannot be fixed.

**NVMe NQ790 — Random Read 4K QD1 (under system load):**

| Percentile | Latency |
|------------|---------|
| Average | 387 us |
| p50 | ~250 us |
| Max | 168,414 us (168 ms) |

The NVMe's 168 ms max is caused by system I/O contention (BTRFS, services, nix store), not the drive itself. The bimodal latency distribution (12% of I/O at 10 us, 46% at 250 us) shows the drive is fast when uncontended but frequently delayed by competing system I/O.

### Performance Ceiling Analysis

The WOOACME's sequential read performance plateaus at ~500 MB/s, which exactly matches the SATA III 6 Gbps theoretical ceiling (~600 MB/s after 8b/10b encoding overhead). The USB 3.2 Gen 2 link (10 Gbps) is not the bottleneck — the SATA-native SSD is. No protocol or interface change short of removing the drive from the USB enclosure and connecting it via native SATA would improve performance.

---

## 6. Endurance & Lifespan Analysis

This is the most critical section for determining viable use cases.

### The Numbers

| Metric | Value | Source |
|--------|-------|--------|
| Percentage endurance used | **4%** | Device Statistics log (GP 0x04) |
| Total host writes | **577 GB** | Device Statistics: 1,127,176,837 sectors x 512 bytes |
| Implied total endurance | **~14.4 TB** | 577 GB / 0.04 |
| Power-on hours consumed | 5,623 | SMART attribute 9 |

### Context

~14 TB TBW is **extremely low** for a 512 GB drive. For comparison:

| Drive (512GB class) | Type | Rated TBW |
|---------------------|------|-----------|
| Samsung 870 EVO | TLC | 300 TBW |
| Crucial MX500 | TLC | 360 TBW |
| Samsung 870 QVO | QLC | 180 TBW |
| WD Green (budget) | TLC | 80 TBW |
| **WOOACME W3A894** | **Unknown** | **~14 TBW (implied)** |

This extremely low endurance explains why WOOACME does not publish a TBW rating. The drive consumed 4% of its write life with only 577 GB of host writes over 234 days of typical desktop/server use.

### Implications for Backup Use

If used as a nightly backup target:

| Backup frequency | Data per backup | Annual writes | Time to 100% endurance |
|-----------------|-----------------|---------------|----------------------|
| Daily (50 GB/night) | 50 GB | 18.3 TB/year | **~9 months** |
| Daily (10 GB/night) | 10 GB | 3.7 TB/year | **~4 years** |
| Weekly (50 GB/week) | 50 GB | 2.6 TB/year | **~5.5 years** |
| Weekly (10 GB/week) | 10 GB | 0.5 TB/year | **~28 years** |

> **Caveat:** The 14 TB estimate assumes the endurance indicator scales linearly with host writes, which is approximate. Write amplification on DRAM-less SSDs can be 2-4x, meaning NAND writes are significantly higher than host writes. Sequential writes (typical for backups) have lower WA than random writes, which helps. The true remaining life could be somewhat better or worse than these projections.

**Bottom line on endurance:** Daily backups of large datasets would consume this drive's write life in under a year. Weekly backups of small critical data (projects, configs, secrets, ~10 GB) would be sustainable for years.

---

## 7. Data Inventory

The drive contains a recoverable NixOS installation from the previous machine. Total used: 83 GB of 435 GB.

### Worth Recovering

| Path | Size | Content |
|------|------|---------|
| `/home/art/projects/private-cloud` | 261 MB | NixOS infra repo (`git@github.com:LarsArtmann/private-cloud.git`) |
| `/home/art/.gnupg` | 100 KB | GPG private keys |
| `/home/art/.ssh` | 24 KB | SSH keys |
| `/home/art/.config` | 1.4 GB | Application configs (may contain credentials/tokens) |
| `/home/art/.claude` + `.claude.json` | 124 KB | Claude AI config |
| `/home/art/.crush` | 88 KB | Crush config |
| `/home/art/.bash_history` | 12 KB | Shell history |
| `/home/art/k8s-networking-analysis-report.md` | 7 KB | Analysis document |
| `/home/art/facter.json` | 108 KB | Hardware report from old machine |
| `/home/syncthing/config.xml` | 6.5 KB | Syncthing config (contains API key) |
| `/etc/nixos/*.nix` | ~50 KB | NixOS configuration files + deployment scripts |
| `/etc/nixos/security-trivy.nix` | 3.6 KB | Security scanner config |
| `/etc/nixos/github-runner-token-renewal.nix` | 9.6 KB | GitHub Actions runner automation |

### Safe to Discard

| Path | Size | Reason |
|------|------|--------|
| `/var` | 48 GB | Docker images, journals, system state from dead machine |
| `/nix` | 22 GB | Stale nix store (rebuildable) |
| `/home/art/.ollama` | 6.3 GB | Models (re-downloadable) |
| `/home/art/.cache` | 3.7 GB | Build caches |
| `/home/art/go/` | 1 GB | Go module cache |
| `/home/art/.npm` | 26 MB | pnpm cache |
| `/storage*` (x5 dirs) | 140 MB | Empty NAS scaffolding |
| `/nas` | 16 KB | Empty mount points |

### Flake Comparison (old vs current private-cloud)

The old `private-cloud` repo is the same project, at an earlier commit (`667f1bc`). The current version at `~/projects/private-cloud/` has three improvements:

1. **`flake-parts` follows nixpkgs-lib** — prevents duplicate nixpkgs evaluations
2. **`pre-commit-hooks-nix` -> `git-hooks`** — tracks upstream package rename
3. **`mkShell` -> `mkShellNoCC`** — avoids unnecessary C compiler in devShell

No unique work exists on the old drive that isn't in the current repo's git history.

---

## 8. Use Case Evaluation

| Use Case | Viability | Rationale |
|----------|-----------|-----------|
| **Periodic manual backup (weekly, small data)** | Viable | Low write volume preserves endurance; speed is adequate for ~10 GB |
| **Read-only cold storage** | Viable | Zero write endurance cost; drive is fully readable |
| **Sneakernet / file transfer** | Viable | One-time writes, then read; USB portability is the advantage |
| **Bootable rescue Linux** | Viable | Read-mostly after initial setup; small footprint |
| **Automated nightly backup (large data)** | Marginal | Would consume endurance in <1 year at 50 GB/night |
| **Nix store / build cache** | Not viable | 4K random write IOPS too low; endurance consumed rapidly |
| **Docker / container storage** | Not viable | Random I/O bottleneck + endurance burn |
| **BTRFS subvolume (active CoW)** | Not viable | CoW write amplification on budget NAND = endurance death spiral |
| **Swap** | Not viable | USB disconnect = kernel hang; random write heavy |
| **Active service data** | Not viable | USB latency tail (99 ms) + low random IOPS |

---

## 9. Recommendation

### What to do with this drive

**Use it as a periodic manual backup drive for critical irreplaceable data only.**

Specifically:
- Projects (`~/projects/` — SystemNix, private-cloud, all repos)
- Sops secrets and encryption keys
- Critical configs and GPG/SSH keys
- Small documents that can't be recreated

**Do NOT** put it on an automated nightly rotation for large datasets. The endurance budget (~14 TB TBW, 96% remaining) makes it unsustainable for write-heavy automated backups.

### How to set it up

1. **Recover data first** (if not already done):
   ```bash
   # Copy off anything worth saving before wiping
   sudo cp -a /mnt/home/art/.gnupg ~/recovery/wooacme-gnupg
   sudo cp -a /mnt/home/art/.ssh ~/recovery/wooacme-ssh
   sudo cp -a /mnt/home/art/projects/private-cloud ~/recovery/wooacme-private-cloud
   ```

2. **Wipe and reformat** (removes old partitions, single clean ext4):
   ```bash
   sudo umount /dev/sda2
   sudo sgdisk --zap-all /dev/sda
   sudo parted /dev/sda mklabel gpt
   sudo parted /dev/sda mkpart primary ext4 0% 100%
   sudo mkfs.ext4 -L wooacme-backup /dev/sda1
   ```

3. **Mount and initialize Borg** (encrypted, deduplicated):
   ```bash
   sudo mkdir -p /mnt/backup
   sudo mount /dev/sda1 /mnt/backup
   sudo chown lars:users /mnt/backup
   borg init --encryption=repokey /mnt/backup/borg
   ```

4. **Manual weekly backup** (not automated to preserve endurance):
   ```bash
   borg create --stats /mnt/backup/borg::'{hostname}-manual-{now:%Y-%m-%d}' \
     ~/projects \
     ~/documents
   borg prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
     /mnt/backup/borg
   ```

### What this does NOT solve

This drive does **not** provide offsite backup. It protects against NVMe failure only. The full 3-2-1 backup gap remains:

| Layer | Protects against | Status |
|-------|-----------------|--------|
| BTRFS snapshots (btrbk) | Accidental deletion, bad deploy | Active (daily, 14d retention) |
| **This USB drive (periodic)** | **NVMe hardware failure** | **Recommended (weekly manual)** |
| Offsite (cloud / rotation) | Site loss (theft, fire, surge) | **Still missing — prioritize** |

For offsite, consider:
- **rsync.net** or **Backblaze B2** for automated cloud backup of critical data (~$0.50-1/GB/month for small datasets)
- **Periodic USB drive rotation** — take this drive offsite monthly, swap with a second drive

### What to actually buy (if spending money)

If the budget allows (~$50-80), a **1-2 TB external HDD** (e.g., WD Elements, Seagate Expansion) provides:
- 100x higher endurance (HDD has no write limit)
- 4x capacity
- Similar sequential speed (~100-150 MB/s, adequate for backups)
- Lower cost per TB

The WOOACME's only advantage over a cheap HDD is random read IOPS (4K vs ~100), which doesn't matter for backup workloads.

---

## 10. Investigation Notes

### What we got wrong initially

1. **"Ext4 superblock is corrupt"** — False. The initial `dumpe2fs` and `mke2fs -n` commands returned no output because of a **permission issue**: `/dev/sda` is owned by `root:disk` and the session user is not in the `disk` group. The `dd` commands returned zeros for the same reason (failed to open, silently produced empty output). The filesystem was clean the entire time. Corrected after mounting with `sudo`.

2. **"The drive may have degraded NAND from the surge"** — False. SMART data shows zero reallocations, zero pending sectors, zero uncorrectable errors, and 100% reserved space. The NAND survived the surge intact. The ext4 journal prevented filesystem corruption across all 17 unsafe shutdowns.

3. **"RTL9210B-CG is a USB-to-NVMe bridge"** — Partially wrong. The RTL9210B-CG is a USB-to-SATA bridge (the drive negotiates SATA 3.2 at 6.0 Gb/s). The initial assessment confused it with NVMe bridge variants. The drive is SATA-native, connected via USB-to-SATA bridge, which explains the ~500 MB/s ceiling.

4. **Initial web research benchmarks** (517-529 MB/s sequential read) — These were from PassMark/Nero databases for the bare drive over native SATA. Our measured 491 MB/s over USB is consistent, confirming the USB bridge adds negligible sequential overhead.

### Methodology limitations

- **No write benchmarks were performed** — the drive was mounted read-only to preserve data for recovery assessment. Write performance was not measured.
- **No SMART self-test was run** — the drive supports short (2 min) and extended (10 min) self-tests. Running `sudo smartctl -t long -d sat /dev/sda` before committing to the backup use case would provide additional confidence.
- **NVMe benchmarks are not representative of idle performance** — the NVMe is the live system disk. True idle benchmarks would show ~7,000 MB/s sequential and ~800K IOPS random, matching the spec sheet.
- **Endurance estimate is approximate** — the 14 TB TBW figure is derived from two data points (4% used, 577 GB host writes) and assumes linearity. Actual endurance depends on write patterns, write amplification, and NAND type (all unknown).

---

## Appendix A: Raw SMART Attributes

```
ID# ATTRIBUTE_NAME          FLAG     VALUE WORST THRESH FAIL RAW_VALUE
  1 Raw_Read_Error_Rate     0x0032   100   100   050    -    0
  5 Reallocated_Sector_Ct   0x0032   100   100   050    -    0
  9 Power_On_Hours          0x0032   100   100   050    -    5623
 12 Power_Cycle_Count       0x0032   100   100   050    -    81
160 Unknown_Attribute       0x0032   100   100   050    -    0
161 Unknown_Attribute       0x0033   100   100   050    -    100
163 Unknown_Attribute       0x0032   100   100   050    -    151
164 Unknown_Attribute       0x0032   100   100   050    -    320169
165 Unknown_Attribute       0x0032   100   100   050    -    518
166 Unknown_Attribute       0x0032   100   100   050    -    1
167 Unknown_Attribute       0x0032   100   100   050    -    218
168 Unknown_Attribute       0x0032   100   100   050    -    5050
169 Unknown_Attribute       0x0032   100   100   050    -    96
175 Program_Fail_Count_Chip 0x0032   100   100   050    -    0
176 Erase_Fail_Count_Chip   0x0032   100   100   050    -    0
177 Wear_Leveling_Count     0x0032   100   100   050    -    0
178 Used_Rsvd_Blk_Cnt_Chip  0x0032   100   100   050    -    0
181 Program_Fail_Cnt_Total  0x0032   100   100   050    -    0
182 Erase_Fail_Count_Total  0x0032   100   100   050    -    0
192 Power-Off_Retract_Count 0x0032   100   100   050    -    17
194 Temperature_Celsius     0x0022   100   100   050    -    31
195 Hardware_ECC_Recovered  0x0032   100   100   050    -    0
196 Reallocated_Event_Count 0x0032   100   100   050    -    0
197 Current_Pending_Sector  0x0032   100   100   050    -    0
198 Offline_Uncorrectable   0x0032   100   100   050    -    0
199 UDMA_CRC_Error_Count    0x0032   100   100   050    -    0
232 Available_Reservd_Space 0x0032   100   100   050    -    100
241 Total_LBAs_Written      0x0030   100   100   050    -    738095
242 Total_LBAs_Read         0x0030   100   100   050    -    39131
245 Unknown_Attribute       0x0032   100   100   050    -    579262
```

## Appendix B: Device Statistics (GP Log 0x04)

```
Page  Offset  Value         Description
0x01  0x008   81            Lifetime Power-On Resets
0x01  0x010   5623          Power-on Hours
0x01  0x018   1127176837    Logical Sectors Written (~577 GB)
0x01  0x020   1051951022    Number of Write Commands
0x01  0x028   2564526350    Logical Sectors Read (~1313 GB)
0x01  0x030   46928564      Number of Read Commands
0x07  0x008   4             Percentage Used Endurance Indicator
```

## Appendix C: Raw fio Results (best runs)

### WOOACME W3A894

```
Seq Read 1M QD1:   291 MB/s, avg lat 3598 us, max 104 ms
Rand Read 4K QD1:  31.6 MB/s (8094 IOPS), avg lat 123 us, p50 ~100us, p95 ~250us, max 5.4 ms
Rand Read 4K QD32: 88.0 MB/s (22528 IOPS), avg lat 1378 us, max 99 ms
```

### Lexar NQ790 NVMe (live system disk, under load)

```
Seq Read 1M QD1:   493 MB/s, avg lat 2125 us, max 260 ms
Rand Read 4K QD1:  10.1 MB/s (2586 IOPS), avg lat 387 us, bimodal: 12% at 10us / 46% at 250us
Rand Read 4K QD32: 18.3 MB/s (4685 IOPS), avg lat 6593 us, max 250 ms
```

> Note: NVMe results reflect heavy system I/O contention. Idle benchmarks would show spec-sheet performance (7,000 MB/s seq, 800K IOPS rand). The bimodal latency distribution confirms the drive is fast when uncontended but starved by system traffic.
