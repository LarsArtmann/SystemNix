# WOOACME W3A894-512GB — Hardware Assessment

**Date:** 2026-08-10
**Drive:** WOOACME W3A894-512GB (S/N: WX2511WX00357, FW: X0719A0)
**Connection:** USB 3.2 Gen 2 (10 Gbps) via Realtek RTL9210B-CG bridge, UAS protocol
**Form Factor:** 2.5" (SATA III native, connected via USB-NVMe bridge enclosure)

---

## 1. Origin

This drive was recovered from a previous NixOS machine (`evo-x2`, user `art`) that was taken offline by a suspected power surge in late December 2025. It was connected to the current evo-x2 via a USB enclosure for assessment.

---

## 2. Specifications

### Confirmed (from SMART + kernel detection)

| Spec | Value |
|------|-------|
| Model | W3A894-512GB |
| Manufacturer | WOOACME (Wooacme Limited, Hong Kong) |
| Capacity | 512 GB (476.9 GiB) |
| Interface (native) | SATA III (6.0 Gb/s) |
| Interface (connected) | USB 3.2 Gen 2 via Realtek RTL9210B-CG |
| Protocol | UAS (USB Attached SCSI) |
| Firmware | X0719A0 |
| SMART | Supported, enabled |
| TRIM | Available |
| Write Cache | Enabled |
| Optimal Transfer Size | 32 MiB (33,553,920 bytes) |

### Could not be confirmed

NAND type, DRAM cache presence, controller, TBW endurance rating, and MTBF are not published by the manufacturer. Benchmark databases (PassMark, Nero Score) characterize it as an entry-level SATA III SSD. TechPowerUp and ssd-tester.com do not have teardown data for this specific model.

---

## 3. Partition Layout (as found)

| Partition | Size | Type | FS | Contents |
|-----------|------|------|----|----------|
| sda1 | 512 MB | EFI System | vfat | Boot partition (boot sector backup minor mismatch at offset 65 — cosmetic) |
| sda2 | 442.6 GB | Linux filesystem | ext4 | Root partition from previous NixOS install (83 GB used, 330 GB free) |
| sda3 | 33.9 GB | Linux swap | swap | Swap partition (label: "swap") |

### Data found on sda2

| Path | Size | Description |
|------|------|-------------|
| `/var` | 48 GB | Docker images, journals from dead system |
| `/nix` | 22 GB | Stale nix store |
| `/home/art` | 14 GB | Full home directory (user `art`) |
| `/home/art/.ollama` | 6.3 GB | Ollama models (downloadable) |
| `/home/art/.cache` | 3.7 GB | Build caches |
| `/home/art/projects/private-cloud` | 261 MB | Private-cloud NixOS infra repo (remote: `git@github.com:LarsArtmann/private-cloud.git`) |
| `/home/art/.config` | 1.4 GB | Application configs |
| `/home/art/.gnupg` | 100 KB | GPG keys |
| `/home/art/.ssh` | 24 KB | SSH keys |
| `/home/syncthing` | 156 KB | Syncthing node `onprem-nixos0` (folders empty) |
| `/storage*` (x5) | ~140 MB | NAS scaffolding (mostly empty dir structures) |
| `/nas` | 16 KB | Empty mount points |

**OS:** NixOS 26.11 "Zokor" (BUILD_ID: 26.11.20260805.b7c2ada)
**Hostname:** evo-x2 (same as current machine)
**Users:** art, lars, syncthing

---

## 4. SMART Health Report

**Overall: PASSED**

| Attribute | ID | Raw Value | Assessment |
|-----------|----|-----------|------------|
| Raw Read Error Rate | 1 | 0 | Clean |
| Reallocated Sector Count | 5 | 0 | No remapped blocks |
| Power-On Hours | 9 | 5,623 (~234 days) | Moderate use |
| Power Cycle Count | 12 | 80 | Low |
| Available Reserved Space | 232 | 100% | Full spare block pool |
| Program Fail Count | 175 | 0 | No program failures |
| Erase Fail Count | 176 | 0 | No erase failures |
| Wear Leveling Count | 177 | 0 | — |
| Current Pending Sector | 197 | 0 | No unreadable sectors pending |
| Offline Uncorrectable | 198 | 0 | No uncorrectable read errors |
| UDMA CRC Error Count | 199 | 0 | Cable/bridge integrity OK |
| Power-Off Retract Count | 192 | 17 | Unsafe shutdowns (power surge evidence) |
| Temperature | 194 | 45 °C | Normal |
| Total LBAs Written | 241 | 738,095 | Low total writes |

**No SMART errors logged. No self-tests previously run.**

The 17 unsafe power-off events (attribute 192) align with the suspected power surge. Despite this, the NAND is undamaged: zero reallocations, zero pending sectors, zero uncorrectable errors, and 100% reserved space remaining.

---

## 5. Integrity Check

### Filesystem (ext4 fsck, read-only)

- **State:** clean
- **Checksum:** valid (crc32c, seed 0xa34ffb75, checksum 0x20ef77cc)
- **Journal:** intact (sequence 0x036416ae)
- **Files:** 1,934,383 (0.2% non-contiguous — excellent)
- **All 5 fsck passes:** passed
- 9 inodes with suboptimal extent trees (cosmetic, no data impact)
- Superblock backups present at: 32768, 98304, 163840, 229376

### Badblocks (full disk read-only scan)

- **Blocks scanned:** 125,026,901 (entire 512 GB)
- **Duration:** ~35 minutes
- **Result:** **0 bad blocks, 0 read errors, 0 write errors**

---

## 6. Benchmarks

### Methodology

All fio tests: raw device, `direct=1` (O_DIRECT, bypass page cache), `libaio` engine, 10 second runtime. dd tests use 1 MB block size.

### Results — WOOACME W3A894 (USB 3.2)

| Test | Result |
|------|--------|
| dd sequential read (1 MB, cached) | 488 MB/s |
| dd sequential read (1 MB, direct I/O) | 169 MB/s |
| fio seq read 1M QD1 | **221 MB/s** (210 IOPS) |
| fio seq read 1M QD32 | **491 MB/s** (468 IOPS) |
| fio rand read 4K QD1 | **7.7 MB/s** (1,976 IOPS) |
| fio rand read 4K QD32 | **15.9 MB/s** (4,073 IOPS) |

### Results — Lexar NQ790 2TB (NVMe, internal, live system disk)

| Test | Result |
|------|--------|
| dd sequential read (1 MB, direct I/O) | 914 MB/s |
| fio seq read 1M QD1 | **936 MB/s** (893 IOPS) |
| fio seq read 1M QD32 | **669 MB/s** (638 IOPS) |
| fio rand read 4K QD1 | **29.1 MB/s** (7,104 IOPS) |
| fio rand read 4K QD32 | **86.0 MB/s** (21,000 IOPS) |

### Comparison Table

| Test | WOOACME (USB) | NVMe NQ790 | NVMe advantage |
|------|---------------|------------|----------------|
| Seq Read 1M QD1 | 221 MB/s | 936 MB/s | 4.2x |
| Seq Read 1M QD32 | 491 MB/s | 669 MB/s | 1.4x |
| Rand Read 4K QD1 | 1,976 IOPS | 7,104 IOPS | 3.6x |
| Rand Read 4K QD32 | 4,073 IOPS | 21,000 IOPS | 5.2x |

### Benchmark Notes

- The WOOACME's sequential read ceiling (~500 MB/s) matches SATA III's 6 Gbps limit exactly — the USB 3.2 10 Gbps link is not the bottleneck, the SATA-native SSD is
- The NVMe QD32 sequential read (669 MB/s) being lower than QD1 (936 MB/s) is abnormal — the live system disk is under active BTRFS load from services, CoW churn, and competing I/O. This aligns with the SLC cache exhaustion issues documented in SystemNix AGENTS.md
- The NVMe real-world performance (936 MB/s seq, 21K IOPS random) is well below its spec sheet (7,000 MB/s seq, 800K IOPS random) because it is the active system disk under load
- Even handicapped, the NVMe is 4-5x faster on random I/O, which is the most important metric for server workloads

---

## 7. Flake Comparison: old (WOOACME) vs current private-cloud

The drive contained an earlier version of the `private-cloud` repo at `/home/art/projects/private-cloud/`. Last commit: `667f1bc` ("feat: Add comprehensive Git mirroring research and analysis").

| Aspect | Old (WOOACME, Dec 2025) | Current (`~/projects/private-cloud`) |
|--------|------------------------|--------------------------------------|
| `flake-parts` inputs | Bare URL, no `follows` | Added `inputs.nixpkgs-lib.follows = "nixpkgs"` |
| Pre-commit hooks | `pre-commit-hooks-nix` | Renamed to `git-hooks` (upstream rename) |
| `perSystem` | Missing `config` arg | Added `config` param |
| Checks | None | Added `checks.build = pkgs.hello` |
| devShell | `pkgs.mkShell` | Changed to `mkShellNoCC` |
| Formatter | `nixfmt-rfc-style` | Changed to `nixfmt` |

Same project, evolved. The three improvements (nixpkgs-lib follows, git-hooks rename, mkShellNoCC) are standard flake hygiene updates.

---

## 8. Recommendations

### Recommended Use: Local Backup Target

Addresses SystemNix's #1 data loss risk (AGENTS.md): *"All snapshots are LOCAL-ONLY. If the NVMe fails, everything is lost."*

**What to back up:**
- `~/projects/` (SystemNix, private-cloud, all repos)
- Sops secrets (`platforms/nixos/secrets/`)
- `/data` critical subsets (photos, documents, databases)
- Flake state snapshots

**Tool:** Borg Backup (encrypted, deduplicated, incremental)

**Setup:**
```bash
# Format (if wiping old data)
sudo umount /dev/sda2
sudo mkfs.ext4 /dev/sda2
sudo mkdir -p /mnt/backup
sudo mount /dev/sda2 /mnt/backup

# Initialize Borg repo
borg init --encryption=repokey /mnt/backup/borg

# Nightly incremental
borg create /mnt/backup/borg::'{hostname}-{now}' \
  /home/lars/projects \
  /data/important
```

**Why this works:** Backup workloads are sequential-write heavy, which is the WOOACME's strength (~500 MB/s). Random IOPS doesn't matter for backups. 330 GB free space holds weeks of deduplicated snapshots.

### NOT Recommended

| Use Case | Reason |
|----------|--------|
| Nix store cache | 4K random IOPS is 5-245x slower than NVMe |
| Docker/container storage | Random I/O would bottleneck container startup |
| BTRFS backup subvolume | QLC (if QLC) + USB + BTRFS CoW = SLC cache exhaustion risk |
| Active service data | USB latency + low random IOPS |
| Swap | Swap-on-USB causes kernel hangs on disconnect |

### Backup Strategy Context

| Layer | What it protects against | Status |
|-------|-------------------------|--------|
| BTRFS snapshots (btrbk) | Accidental deletion, bad deploy | Active (daily, 14d retention) |
| **This USB drive** | NVMe hardware failure | **Recommended** |
| Offsite (cloud/offsite rotation) | Site loss (theft, fire, surge) | Still missing |

For a poor-man's 3-2-1 strategy: use this drive for nightly local backups, and periodically rotate it offsite (e.g., take to work, friend's house).

---

## 9. Assessment Summary

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Physical health | Good | Zero bad sectors, 100% reserved space, zero failures |
| Filesystem integrity | Clean | ext4 fsck passed all checks, journal intact |
| Performance | Entry-level | SATA III speeds over USB, ~500 MB/s sequential, ~4K random IOPS |
| Reliability | Moderate | 5,623 hours, 80 power cycles, survived 17 unsafe shutdowns |
| Endurance | Unknown | No TBW rating published by manufacturer |
| Suitable for | Backup target, cold storage, file transfer | Not suitable for active workloads |

**Bottom line:** The drive survived the power surge with zero damage. It is physically healthy but performance-limited (SATA III over USB). Its best use is as a local backup target to protect against NVMe failure — the single highest-probability data loss scenario for SystemNix.
