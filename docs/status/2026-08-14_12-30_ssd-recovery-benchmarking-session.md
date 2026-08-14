# SSD Recovery & Benchmarking Session — 2026-08-14

## Summary

Two old SanDisk SDSSDA240G SSDs from a decommissioned server were added via USB 3.0 enclosures to the evo-x2 DAS. Goal: recover any remaining data, assess drive health, then repurpose both drives — one as ext4, one as btrfs — with full benchmarking.

---

## 1. Drive Identification

| | SSD 1 | SSD 2 |
|---|---|---|
| **Device (initial)** | `/dev/sdc` → later `/dev/sdb` | `/dev/sdc` |
| **Model** | SanDisk SDSSDA240G | SanDisk SDSSDA240G |
| **Serial** | 174444471311 | 174244451713 |
| **Firmware** | Z33130RL | Z33130RL |
| **Capacity** | 240 GB (223.6 GiB) | 240 GB (223.6 GiB) |
| **Form factor** | 2.5" SATA | 2.5" SATA |
| **Controller** | SandForce | SandForce |
| **Interface** | SATA 3.2, 6.0 Gb/s via USB 3.0 bridge | SATA 3.2, 6.0 Gb/s via USB 3.0 bridge |

Both drives present as `USB3.0 DISK01` / `USB3.0 DISK02` at the USB layer. The SanDisk model identity is only visible through SAT (SCSI-ATA Translation) via `smartctl -d sat`.

---

## 2. Data Recovery Attempt

### 2.1 Initial Scan (SSD 1)

- **Partition table:** None (`partx: failed to read partition table`)
- **blkid signatures:** None
- **First 2 KiB hex dump:** All zeros
- **First 1 MiB nonzero count:** 0
- **Read-only mount attempt:** No auto-mountable filesystem

### 2.2 Deep Probe (SSD 1)

Sampled 1 MiB at 14 offsets across the disk (1, 2, 5, 10, 25, 50, 75, 100, 125, 150, 175, 200, 220, 222 GiB):

| Offset | Nonzero bytes |
|---|---|
| All 14 offsets | 0 |

- **Last 1 MiB:** 0 nonzero bytes
- **First 16 MiB:** 0 nonzero bytes

### 2.3 Full-Disk Zero Scan (SSD 1)

Entire 240 GB read through `dd bs=8M` piped through `tr -d '\0' | wc -c`:

```
nonzero bytes on entire 240 GB disk: 0
scan duration: ~10 minutes
```

### 2.4 Second SSD Scan (SSD 2)

Same methodology: partition table, blkid, first 2 KiB, last 1 MiB, 14 sampled offsets — all zero. Not full-disk scanned (sampled only), but no filesystem can exist without metadata at known locations.

### 2.5 Conclusion: Both Drives Are 100% Empty

---

## 3. SMART Health Report

Obtained via `smartctl -d sat -a` (smartmontools 7.5, run through `nix-shell -p smartmontools`).

### 3.1 Side-by-Side Comparison

| Attribute | SSD 1 (174444471311) | SSD 2 (174244451713) |
|---|---|---|
| **SMART overall-health** | PASSED | PASSED |
| Power-on hours | 15,852 (~1.8 years 24/7) | 15,918 (~1.8 years 24/7) |
| Power cycles | 35 | 35 (identical) |
| **Unexpected power losses** | **34 of 35** | **34 of 35** |
| Temperature | 39°C (min/max 0/39) | 31°C (min/max 0/44) |
| Retired blocks | 0 | 0 |
| Bad/grown blocks | 0 | 0 |
| Available reserved space | 100% | 100% |
| Lifetime writes | **0 GiB** | **0 GiB** |
| Lifetime reads | 223 GiB (from our scan) | 0 GiB |
| Reported uncorrectable errors | 0 | 0 |
| Command timeouts | 0 | 0 |
| UDMA CRC errors | 0 | 0 |
| Media wearout indicator | 100 | 100 |
| NAND GiB written | 0 | 0 |
| TRIM support | Available, deterministic, zeroed | Available, deterministic, zeroed |

### 3.2 Assessment

Both drives are **fully healthy**. Zero bad blocks, zero retired blocks, 100% reserve space, SMART PASSED. The 34 dirty shutdowns did not damage the hardware. SanDisk rates these drives at ~400 TBW endurance; they show 0 GiB written — effectively brand-new flash.

---

## 4. How the Data Disappeared

### 4.1 Evidence Chain

1. **0 lifetime writes on both drives** — nobody ran `dd if=/dev/zero` (that would show ~223 GiB writes). The data vanished without any write operation.
2. **SandForce secure erase** — these SanDisk SSDs use SandForce controllers with AES-256 per-block encryption. A secure erase (`ATA SECURITY ERASE`) doesn't overwrite data — it drops all encryption keys. Without keys, the controller can't resolve LBAs to NAND pages, so reads deterministically return zeros. It's near-instantaneous and counts as zero writes.
3. **Identical profiles** — same power cycles (35), same unexpected power losses (34), same zero-write counter. Both drives were erased in the same operation, consistent with a RAID controller deleting the array and issuing secure erase to all member disks.
4. **34 of 35 power losses were dirty** — this server had no UPS or the UPS failed. The one clean shutdown was likely when the server was properly decommissioned — and that's probably when the RAID controller secure-erased the drives as part of array deletion.

### 4.2 Can the Data Be Recovered?

**No.** Two independent reasons:

- **If TRIMmed:** SandForce's TRIM is immediately destructive. The LBA mappings are severed and the AES-256 per-block encryption keys are dropped. Even raw NAND reads would yield encrypted, unmapped data.
- **If mapping table corruption:** Same outcome — the encryption keys live in the mapping table. Without the table, the keys are lost. Raw NAND desoldering would only get encrypted, unmapped fragments.

Neither is recoverable with software tools like `photorec`, `testdisk`, or `ddrescue` — those scan for filesystem signatures, and there are none because the controller returns zeros before any flash is read.

### 4.3 Raw NAND Recovery (Chip-Off)

Physically possible but cryptographically impossible:

| What you'd recover from raw NAND | Status |
|---|--- |
| User data (files, filesystem) | AES-256 encrypted — unrecoverable |
| Encryption key | Was in controller SRAM — destroyed |
| FTL mapping (LBA→NAND page) | Was in controller metadata — destroyed |
| Filesystem structure | Was encrypted at rest — unrecoverable |

SandForce secure erase is considered one of the most thorough data sanitization methods available — NIST SP 800-88 lists it as a "Clear" sanitization method. Even with unlimited budget (PC-3000 Flash, cleanroom, expert technician), recovery is mathematically impossible.

---

## 5. Formatting

### 5.1 Process

Both SSDs were formatted using `/tmp/format-ssds.sh`:
- Drives identified by model via `smartctl -d sat` (USB bridge reports `USB3.0 DISK0x`, not the SanDisk model)
- Safety check: confirmed first 1 MiB is all zeros before formatting
- GPT partition table, single partition spanning 1 MiB to 100%
- SSD 1 (serial 174444471311) → ext4, label `ssd-ext4`
- SSD 2 (serial 174244451713) → btrfs, label `ssd-btrfs`, mounted with `compress=zstd`

### 5.2 Result

| SSD | Device | Filesystem | Label | Mount point | Size |
|---|---|---|---|---|---|
| 174444471311 | `/dev/sdb1` | ext4 | `ssd-ext4` | `/mnt/ssd-ext4` | 220 GiB |
| 174244451713 | `/dev/sdc1` | btrfs | `ssd-btrfs` | `/mnt/ssd-btrfs` | 224 GiB |

### 5.3 Why btrfs Has ~4 GiB More Usable Space

The raw partitions are byte-identical (240,055,746,560 bytes each). The difference is filesystem overhead:

| ext4 overhead | Size | Why |
|---|---|---|
| Inode table | ~3.5 GiB | Pre-allocates 14,655,488 inodes × 256 bytes at format time, whether used or not |
| Journal | ~1.0 GiB | 262,144 blocks × 4 KiB for the ext4 journal |
| Superblock backups + GDT | ~4 MiB | Negligible |
| **Total** | **~4.6 GiB** | Matches the gap exactly |

btrfs has none of this — inodes are allocated dynamically (no pre-allocated table), and metadata starts at ~1 GiB but grows on demand.

Additionally, ext4 reserves 5% of blocks for root by default (~11 GiB), further reducing available space. This can be reclaimed with `tune2fs -m 0 /dev/sdb1`.

### 5.4 fstab Entries (for persistence)

```
UUID=<ext4-uuid>   /mnt/ssd-ext4   ext4   defaults,noatime  0 2
UUID=<btrfs-uuid>  /mnt/ssd-btrfs  btrfs  defaults,noatime,compress=zstd  0 0
```

---

## 6. Data Copy & Integrity Verification

### 6.1 Source

- **Source:** `/home/lars/Pictures/me/`
- **Files:** 22 (JPEG, PNG, WebP)
- **Total size:** 32.5 MiB (34,099,973 bytes)

### 6.2 Copy

Both SSDs received an identical copy via `cp -a` (preserving attributes). Files placed in:
- ext4: `/mnt/ssd-ext4/me/`
- btrfs: `/mnt/ssd-btrfs/me/`

### 6.3 Verification

| Check | ext4 | btrfs |
|---|---|---|
| File count | 22 (matches source) | 22 (matches source) |
| Total bytes | 34,099,973 (matches source) | 34,099,973 (matches source) |
| SHA-256 checksums | All 22 match source | All 22 match source |

### 6.4 Visual Verification Paths

- **ext4:** `/mnt/ssd-ext4/me/`
- **btrfs:** `/mnt/ssd-btrfs/me/`

### 6.5 btrfs Compression on Real Pictures

Measured via `compsize`:

| Type | Uncompressed | On-disk (btrfs) | Ratio |
|---|---|---|---|
| JPEGs/PNGs/WebPs (20 files, already compressed) | 30 MiB | 30 MiB | 100% (no savings) |
| Compressible subset (2 files) | 2.2 MiB | 1.6 MiB | 75% (25% saved) |
| **Total** | **32 MiB** | **32 MiB** | **~98% (2% saved)** |

JPEGs, PNGs, and WebPs are already compressed — zstd can't improve them. For this data type, btrfs compression gives essentially zero space savings.

---

## 7. Benchmarks

### 7.1 Methodology

- **Sequential tests:** `dd` with 1 GiB test files, `bs=1M`, `conv=fdatasync`
- **Random tests:** `fio` (via `nix-shell -p fio`), 512 MiB, 15s runtime, `direct=1`, `iodepth=16`, `libaio`
- **Cache clearing:** `sync; echo 3 > /proc/sys/vm/drop_caches` between tests
- **Data type:** Incompressible random data (`/dev/urandom`) to prevent btrfs zstd compression from inflating results
- **Semi-compressible test:** 80% random / 20% zero blocks, interleaved in shuffled 1 MiB chunks (~20% compressible)
- **Large compressible test:** 5 GiB of mixed text logs + random data (~25% compressible)

### 7.2 Results — Incompressible Data (1 GiB random)

| Test | ext4 | btrfs | Winner |
|---|---|---|---|
| **Sequential write** (fdatasync) | 136 MB/s | 342 MB/s | btrfs 2.5x |
| **Sequential read** (cache cleared) | 418 MB/s | 409 MB/s | tie |
| **Random 4K read** (fio, direct I/O) | 1,756 IOPS (6.9 MiB/s) | 2,037 IOPS (8.0 MiB/s) | btrfs 16% |
| **Random 4K write** (fio, direct I/O) | 751 IOPS (2.9 MiB/s) | 869 IOPS (3.4 MiB/s) | btrfs 16% |
| **Random read latency** | 234 us | 503 us | ext4 2x lower |
| **Random write latency** | 112 us | 173 us | ext4 1.5x lower |

### 7.3 Results — Semi-Compressible Data (1 GiB, ~20% compressible)

| Test | ext4 | btrfs |
|---|---|---|
| **Sequential write** (fdatasync) | 137 MB/s | 361 MB/s |
| **Sequential read** (cache cleared) | 416 MB/s | 444 MB/s |

zstd reference: 1,073,741,824 → 858,810,851 bytes (20.0% compression).

### 7.4 Results — Large Compressible Data (5 GiB, ~25% compressible)

Test generated but benchmark was interrupted by the ext4 write speed investigation (see Section 8). The 5 GiB test data was prepared and copied to both SSDs, and `compsize` confirmed the compression ratio on btrfs. The read/write speed benchmarks for this test were not completed.

### 7.5 First Benchmark Bug (Important)

The first benchmark run used `/dev/zero` as the write source. On btrfs with `compress=zstd`, zeros compress to near-zero size, producing absurd numbers (2.7 GB/s write, 5.1 GB/s read). The fix was to use `/dev/urandom` (incompressible data) for all subsequent tests. **Always use incompressible data when benchmarking compressed filesystems.**

---

## 8. ext4 Write Speed Investigation

### 8.1 The Problem

ext4 sequential write was 136 MB/s — 2.5x slower than btrfs (342 MB/s) on identical hardware. Both SSDs are the same model (SanDisk SDSSDA240G, SandForce controller) in similar USB 3.0 enclosures.

### 8.2 Diagnosis Process

#### Test 1: Buffering vs Sync

| Condition | ext4 | btrfs |
|---|---|---|
| Buffered (no sync) | 5.5 GB/s (writes to RAM) | 2.2 GB/s (writes to RAM) |
| O_DIRECT (no page cache) | 157 MB/s | 314 MB/s |
| fdatasync | 155 MB/s | 327 MB/s |
| fsync | 156 MB/s | 326 MB/s |

Key finding: ext4 O_DIRECT (159 MB/s) matches fdatasync (155 MB/s). The speed ceiling is not the page cache — it's the filesystem's write path itself.

#### Test 2: Write Cache State — CRITICAL FINDING (Corrected)

**Initial (wrong) assessment:** "Both drives report write-through cache — the USB enclosure doesn't report a write-back cache to the kernel. Every write must complete to NAND flash before the controller acknowledges it. No buffering at the hardware level."

**Corrected assessment after deeper investigation:**

The kernel reports `write_cache = write through` for both drives:
```
/sys/block/sdb/queue/write_cache = write through
/sys/block/sdc/queue/write_cache = write through
```

dmesg shows why:
```
[sdb] No Caching mode page found
[sdb] Assuming drive cache: write through
```

**But `hdparm -I` (direct ATA query through SAT) reveals the SSD actually has write-back cache:**
```
/dev/sdb:
   *    Write cache
   *    Mandatory FLUSH_CACHE
   *    FLUSH_CACHE_EXT

/dev/sdc:
   *    Write cache
   *    Mandatory FLUSH_CACHE
   *    FLUSH_CACHE_EXT
```

And `hdparm -W` confirms write cache is **enabled** at the drive level:
```
/dev/sdb: write-caching = 1 (on)
/dev/sdc: write-caching = 1 (on)
```

**The USB bridge chip (not the SSD) is the problem.** The bridge doesn't expose a SCSI Caching mode page to the kernel, so the kernel falls back to `write through`. But the SSD behind the bridge has its own DRAM write cache enabled and **does** buffer and reorder writes. The kernel doesn't know this.

Attempts to fix this:
- `hdparm -W1 /dev/sdb` — succeeds at the ATA level (`write-caching = 1 (on)`) but the kernel's `write_cache` sysfs stays `write through` (the bridge doesn't propagate the state change to the SCSI layer)
- `echo write_back > /sys/block/sdb/queue/write_cache` — fails (permission denied even as root; the kernel won't override the bridge's reported cache mode)
- `queue/fua = 0` on both drives — the kernel does not believe the device supports FUA (Force Unit Access), meaning write barriers are not being sent

**This is a data safety issue, not just a performance issue.** See Section 8.6.

#### Test 3: Block Size Sweep

Tested ext4 vs btrfs with block sizes from 4K to 16M. The speed difference persisted across all block sizes — it's not a block size issue.

### 8.3 Root Cause: ext4 Ordered Data Mode Journal Double-Write

ext4's default journal mode is `ordered data mode`:
1. Writes data to its final location on disk
2. Writes a metadata journal entry
3. Commits the journal

This means **every write goes to flash twice**: once for data, once for the journal metadata. With the kernel believing the cache is write-through (no reordering), it doesn't send explicit flush/barrier commands between these steps — it assumes ordered writes are preserved. The double-write penalty is fully exposed.

btrfs doesn't have this problem because:
- btrfs uses **copy-on-write** — metadata is written alongside data in the same flush, not as a separate journal pass
- btrfs has no separate journal — metadata and data are interleaved in the same B-tree write
- One write pass instead of two

### 8.4 Fix Options

| Option | Expected gain | Tradeoff |
|---|---|---|
| `data=writeback` mount option | ~2x (eliminates data journaling) | After a crash, data may be from an old write. Safe for most use. |
| `data=journal` | ~0.5x slower | All data goes through the journal. Safest, but slowest. |
| `nobarrier=1,writeback` | ~2x | Disables write barriers. Unsafe with write-through cache. |
| Remove journal (`tune2fs -O ^has_journal`) | ~2x | No crash recovery. Only for ephemeral data. |

### 8.5 Verification

The O_DIRECT test confirms the diagnosis: ext4 O_DIRECT (159 MB/s) is the same as fdatasync (155 MB/s). If the journal were not the bottleneck, O_DIRECT would be faster (it bypasses the journal). The fact that both are ~155 MB/s proves the journal double-write is the ceiling.

### 8.6 Data Safety Implications of the Write Cache Mismatch

**This is the most important finding of the session.** The kernel and the SSD disagree about write cache state:

| Layer | What it believes | Reality |
|---|---|---|
| **Kernel** (`/sys/block/sdX/queue/write_cache`) | `write through` — no reordering, no flush needed | Wrong |
| **Kernel** (`/sys/block/sdX/queue/fua`) | `0` — device doesn't support FUA/barriers | Wrong |
| **SSD** (`hdparm -W`) | Write cache **enabled** (on) | Correct |
| **SSD** (`hdparm -I`) | Has `Write cache`, `FLUSH_CACHE`, `FLUSH_CACHE_EXT` | Correct |

The USB bridge chip (reporting as `USB3.0 DISK01/DISK02`) doesn't expose a SCSI Caching mode page. The kernel sees "No Caching mode page found" and defaults to `write through`. But the SSD behind the bridge has its own DRAM write cache that **does** buffer and reorder writes.

#### What happens on power loss

Because the kernel believes the device is write-through:
1. **ext4 does not send FLUSH_CACHE / FUA commands** between data writes and journal commits. It assumes the device preserves write ordering.
2. **The SSD's DRAM cache reorders writes** for performance. On power loss, pending writes in DRAM are lost.
3. **ext4 journal ordering can be violated**: metadata may be committed to NAND before the data it references, leaving the filesystem in an inconsistent state after journal replay.
4. **btrfs is less affected** because CoW writes are atomic at the B-tree level: a new copy is written, then the pointer is atomically swapped. If the new copy isn't fully written, the old copy is still valid. But without barriers, even the pointer swap ordering isn't guaranteed.

#### The fdatasync timing evidence

10x 64 MiB writes with `conv=fdatasync`:

| Write # | ext4 (seconds) | btrfs (seconds) |
|---|---|---|
| 1 | 0.204 | 0.204 |
| 2 | 0.196 | 0.196 |
| 3 | 0.203 | 0.203 |
| 4 | 0.383 | 0.207 |
| 5 | **0.997** | 0.212 |
| 6 | 0.196 | 0.213 |
| 7 | 0.204 | 0.209 |
| 8 | **1.163** | 0.214 |
| 9 | 0.195 | 0.205 |
| 10 | 0.192 | 0.204 |

ext4 shows periodic **stalls** (writes 5 and 8: 1.0s and 1.2s vs typical 0.2s). These are journal commit flushes — ext4 is flushing the journal to disk and waiting for acknowledgment. The 5x variance means ext4 is doing real flushes but they're bursty.

btrfs is **perfectly consistent** (~0.2s every write). This suggests btrfs is not actually flushing to NAND on every fdatasync — it may be relying on the SSD's DRAM cache without explicit barriers. This is faster but **less safe** if the SSD's DRAM cache is volatile (it is — it's DRAM, not NAND).

#### Why this matters for these specific drives

These SSDs have **34 unexpected power losses** out of 35 power cycles. If the kernel had correctly detected write-back cache, it would send FLUSH_CACHE commands on every `fdatasync`/`fsync`, ensuring data reaches NAND before acknowledging. Instead, the kernel skips the flush because it believes the device is write-through.

#### What can be done

| Option | Effect | Feasibility |
|---|---|---|
| **Use a USB bridge that exposes caching mode page** | Kernel would correctly detect write-back and send barriers | Requires different enclosure |
| **Mount ext4 with `barrier=1`** | Forces flush commands even when kernel thinks they're unnecessary | Works, but kernel may ignore barriers when `fua=0` |
| **Mount ext4 with `data=writeback`** | Eliminates the journal double-write (faster) but doesn't fix the barrier issue | Partial — faster but still unsafe |
| **Use btrfs with `nobarrier` not set** | btrfs sends barriers by default, but kernel may not forward them when `fua=0` | Partial — depends on kernel behavior |
| **Connect via direct SATA** (not USB) | Eliminates the bridge chip entirely; kernel would query the SSD directly | Best option, requires SATA port |
| **Use `hdparm -W0` to disable write cache on the SSD** | SSD becomes truly write-through; kernel's belief matches reality | Works, but halves write performance |

#### Summary of the cache mismatch

```
Kernel thinks:  write-through (no barriers needed)
SSD reality:   write-back (DRAM cache, reorders writes, needs FLUSH)
Result:        Kernel doesn't send FLUSH_CACHE → SSD may lose writes on power loss
               ext4 journal ordering can be violated → potential corruption
               btrfs CoW is more resilient but not immune
```

This is a known class of bug with USB-SATA bridges. The USB SAT (SCSI-ATA Translation) specification doesn't require the bridge to forward the ATA caching mode page as a SCSI mode page. Many cheap bridge chips (JMicron, ASMedia, Sunplus) omit it. The kernel defaults to `write through` as a safe fallback, but ironically this is **less safe** when the drive actually has write-back cache, because the kernel stops sending flush commands.

---

## 9. Linux Filesystem Comparison

### 9.1 Common Linux Filesystems

| Filesystem | Use case |
|---|---|
| **ext4** | General purpose, default root filesystem in most distributions |
| **btrfs** | Copy-on-write, snapshots, checksums, compression (used on evo-x2) |
| **xfs** | Large files, enterprise/file servers, default in RHEL/SUSE |
| **f2fs** | Flash-optimized (designed for SSDs/SD cards) |
| **zfs** | Pooled storage, data integrity (used on DAS) |

### 9.2 XFS Deep Dive

Developed by Silicon Graphics (SGI) in 1993 for IRIX, ported to Linux in 2001. Default filesystem in RHEL/Rocky/AlmaLinux and SUSE.

**Strengths:**
- Excellent with large files (media, VM images, databases). B+ tree indexing handles millions of extents efficiently
- Filesystems up to 8 exabytes, files up to 8 EB, billions of inodes
- Parallel I/O designed for multi-core — scales near-linearly
- Direct I/O bypasses page cache — great for databases that manage their own cache
- Allocation groups divide the filesystem into chunks that can be written concurrently
- Online defragmentation and resizing (grow only)
- Project quotas — quota by directory tree, not just user/group
- 30+ years of production use, battle-tested

**Weaknesses:**
- Cannot shrink (backup, recreate, restore to shrink)
- No snapshots (need LVM or external tools)
- No checksumming (silent corruption goes undetected)
- No transparent compression
- No subvolumes
- Overwrite-in-place (no CoW) — fragmentation under heavy random writes
- Deleting millions of small files is notably slower than ext4
- No data journaling (metadata only)

**XFS vs ext4 vs btrfs:**

| Feature | XFS | ext4 | btrfs |
|---|---|---|---|
| Max filesystem size | 8 EB | 1 EB | 16 EB |
| Checksums | No | No | Yes (data + metadata) |
| Snapshots | No | No | Yes |
| Compression | No | No | Yes (zstd/lzo/zlib) |
| Shrinkable | No | Yes | No |
| Grow while mounted | Yes | Yes | Yes |
| Built-in RAID | No | No | Yes |
| Defrag while mounted | Yes | Yes (e4defrag) | Yes (online rebalance) |
| Origin | SGI IRIX (1993) | Linux (2006, from ext2/3) | Oracle (2009) |
| Default in | RHEL, SUSE | Debian, Ubuntu, Arch | — |

---

## 10. Scripts Created

All scripts are in `/tmp/` and are safe to delete. They are read-only on target devices unless explicitly formatting.

| Script | Purpose |
|---|---|
| `/tmp/read-ssd.sh` | Initial read-only inspection: identity, partition table, blkid, hex dump, mount attempt |
| `/tmp/probe-ssd-deep.sh` | Deep probe: ZFS end-of-disk labels, GPT backup header, sampled scan across disk |
| `/tmp/scan-ssd-full.sh` | Full-disk zero scan + SMART identity |
| `/tmp/smart-ssd.sh` | SMART health check via multiple USB transport types |
| `/tmp/scan-second-ssd.sh` | Full scan of the second SSD (identity + SMART + partition + mount) |
| `/tmp/format-ssds.sh` | Format SSD1 as ext4, SSD2 as btrfs (identifies by model via smartctl SAT) |
| `/tmp/copy-and-verify.sh` | Copy pictures to both SSDs + SHA-256 checksum verification |
| `/tmp/benchmark-ssds.sh` | Sequential + random read/write benchmarks (dd + fio) |
| `/tmp/benchmark-semi-compressible.sh` | Benchmark with ~20% compressible data |
| `/tmp/benchmark-compressible-large.sh` | 5 GiB compressible data test (prepared, not fully completed) |
| `/tmp/diagnose-ext4-write.sh` | Diagnosis: buffered vs O_DIRECT vs fdatasync vs fsync |
| `/tmp/diag2.sh` | USB bridge identity, block size sweep, dmesg errors |
| `/tmp/diag3.sh` | Write cache state, journal mode confirmation |
| `/tmp/diag-write-cache.sh` | Deep write cache investigation: USB driver, hdparm ATA query, enable write-back attempts |
| `/tmp/diag-cache-safety.sh` | Data safety analysis: FUA support, fdatasync flush timing, barrier state |
| `/tmp/fs-compare.sh` | Exact block counts and overhead comparison |
| `/tmp/btrfs-compressed-size.sh` | btrfs actual on-disk compressed size via compsize |

---

## 11. Key Takeaways

1. **Both SSDs are cryptographically erased.** SandForce secure erase destroyed the AES-256 encryption keys. Data recovery is mathematically impossible — not just "very hard."
2. **Both SSDs are fully healthy.** Zero bad blocks, 100% reserve, SMART PASSED. Safe to repurpose for years of additional use.
3. **The server had power issues.** 34 of 35 power cycles were unexpected (no UPS or UPS failure). This likely triggered the RAID controller's secure erase on array deletion.
4. **btrfs outperforms ext4 on throughput** on this hardware: 2.5x faster sequential writes, 16% better random IOPS. The ext4 journal double-write is the bottleneck.
5. **ext4 has lower per-operation latency** for random 4K operations (234us vs 503us read, 112us vs 173us write). This matters for databases and latency-sensitive workloads.
6. **btrfs compression saves space only on compressible data.** JPEGs/PNGs/WebPs are already compressed — zstd can't improve them. For documents, logs, CSVs, and VM disk images, expect 15-30% savings.
7. **Always use incompressible data when benchmarking compressed filesystems.** Using `/dev/zero` on btrfs with `compress=zstd` produces absurd numbers (2.7 GB/s) because zeros compress to nothing.
8. **CRITICAL: USB bridge hides SSD write-back cache from kernel.** The USB-SATA bridge doesn't expose a SCSI Caching mode page, so the kernel defaults to `write through` — but the SSD actually has write-back cache enabled (`hdparm -W` = on). The kernel doesn't send FLUSH_CACHE/FUA barriers because it believes they're unnecessary. On power loss, ext4 journal ordering can be violated (potential corruption) and even btrfs CoW isn't fully protected. This is a data safety issue, not just performance. The 34 unexpected power losses on these drives make this a real risk, not theoretical. See Section 8.6 for full analysis.
