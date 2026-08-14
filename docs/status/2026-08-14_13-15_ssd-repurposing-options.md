# Repurposing Two 240 GB SanDisk SSDs — Options Analysis

## 2026-08-14

## Drive Context

| | Detail |
|---|---|
| **Model** | SanDisk SDSSDA240G (SSD Plus line) |
| **Controller** | SandForce (DRAM-less, DuraWrite compression, AES-128) |
| **Capacity** | 240 GB each (223.6 GiB) |
| **Endurance** | 60 TBW (terabytes written over lifetime) — ~55 GB/day over 3 years |
| **Current health** | SMART PASSED, 0 bad blocks, 100% reserve space, 0 GiB written |
| **Age** | ~15,852 power-on hours (~1.8 years 24/7), 10+ years since manufacture |
| **Attachment** | USB 3.0 enclosures (USB3.0 DISK01/DISK02 bridge chips) |
| **Write cache** | Kernel reports `write through` (correct for DRAM-less SandForce) |
| **Power loss history** | 34 of 35 power cycles were unexpected |
| **Formatted as** | SSD 1 (serial 174444471311) = ext4, SSD 2 (serial 174244451713) = btrfs+compress=zstd |
| **Benchmarked speed** | ext4 write 136 MB/s, btrfs write 342 MB/s, both read ~410 MB/s |

---

## What 60 TBW Means

**TBW = Terabytes Written** — the total amount of data the drive can write over its lifetime before the NAND flash is expected to wear out.

- 60 TBW = 60,000 GB of writes before end of warranty
- SanDisk's warranty: 3 years or 60 TBW, whichever comes first
- Equivalent to ~55 GB/day sustained writes over 3 years
- These drives show 0 GiB written (counters likely reset by secure erase) — flash is effectively unused
- For comparison: the evo-x2 NVMe (Lexar NQ790 2TB) has ~1200 TBW (20x more endurance)
- Writing continuously at 136 MB/s, 60 TBW lasts ~5 days of 24/7 writes

**Practical implication:** these drives are fine for read-heavy workloads (nix store, Docker images, cached data) but will die quickly under sustained write workloads (VM disks, databases, build caches that churn constantly).

---

## Key Constraints

1. **USB 3.0 attachment adds latency** — 503 us random read latency vs <100 us for direct SATA/NVMe. This eliminates latency-sensitive use cases (ZFS SLOG, ZFS L2ARC).
2. **60 TBW endurance** — low. Eliminates write-heavy workloads (VM disks, active databases, build cache churn).
3. **10+ year old hardware** — reliability is the primary concern, not NAND wear. SandForce SF-2000 controllers have known age-related failure modes (BSOD, controller death, firmware bugs). Sudden failure is more likely than wear-out.
4. **DRAM-less** — no DRAM write-back cache. Write performance is lower than DRAM-equipped SSDs, especially for small random writes.
5. **USB bridge doesn't expose cache mode page** — kernel defaults to `write through`. This is approximately correct for DRAM-less SandForce (data reaches NAND within milliseconds via SRAM buffer).
6. **No power-loss protection** — no capacitor/supercap. Data in the SRAM buffer may be lost on power loss. Not suitable for write-integrity-critical workloads (SLOG, database journals).
7. **NAND charge loss when unpowered** — SSDs lose data slowly when shelved. Severe data loss after 1-3 years unpowered. Never use as offline/cold backup.

---

## Use Case Analysis

### 1. Scratch / Temp Build Storage

**Fit: Excellent**

Use for ephemeral data that can be rebuilt or re-downloaded:
- `nix-shell` build sandboxes (`TMPDIR=/mnt/scratch`)
- Download staging area
- Transcode working directory
- `ccache` / `cargo` cache that can be rebuilt
- Compiler output directories (`target/`, `build/`)

| Aspect | Assessment |
|---|---|
| Endurance impact | High writes, but data is ephemeral — if drive dies, rebuild |
| Performance benefit | Fast writes speed up builds and transcodes |
| Data loss risk | Low impact — data is disposable by definition |
| Recommendation | **Top choice for SSD 1 (ext4)** |

**Setup:** Mount ext4 with `noatime,data=writeback` (data is disposable, journal overhead is waste). Run `fstrim.timer`.

### 2. Nix Store / Build Cache (Read-Only Cache)

**Fit: Excellent**

240 GB comfortably fits a full NixOS store (typical: 20-80 GB, worst case ~180 GB with many generations). Mount `noatime`.

| Aspect | Assessment |
|---|---|
| Endurance impact | Low writes (read-mostly after populate) |
| Performance benefit | Faster `nix build` and `nix-shell` when store is warm |
| Data loss risk | Low impact — store rebuilds from cache.nixos.org |
| Recommendation | **Top choice for SSD 2 (btrfs)** |

**Setup:** Could act as a local binary cache proxy or a warm copy of frequently-used store paths. btrfs `compress=zstd` helps with compressible package data (binaries, text configs).

### 3. Docker / Container Storage

**Fit: Good**

240 GB fits dozens of containers (typical: 8-20 GB for images + build cache). Fast layer operations and image pulls.

| Aspect | Assessment |
|---|---|
| Endurance impact | Moderate writes (build churn, image pulls, layer operations) |
| Performance benefit | Fast container starts, image pulls, layer operations |
| Data loss risk | Medium — container rebuild if drive dies, but images are re-pullable |
| Inode risk | ext4 pre-allocates 14M inodes — sufficient. btrfs allocates dynamically. |
| Recommendation | **Good for SSD 2 (btrfs)** alongside nix store |

**Setup:** Move Docker data-root to `/mnt/ssd-btrfs/docker` via `services.docker.storageOpt` or daemon config. btrfs snapshots give rollback safety for container state.

### 4. Powered Backup Target (Online)

**Fit: Good**

Fast rsync/restic/borg target for config backups, git repo mirrors, small dataset snapshots. 240 GB is plenty for config/repo backups (typically 1-10 GB).

| Aspect | Assessment |
|---|---|
| Endurance impact | Low writes (scheduled, usually daily) |
| Performance benefit | Fast backup and restore operations |
| Data loss risk | Low — this is a backup, not the only copy |
| Retention | Must remain powered — NAND loses charge when unpowered |
| Recommendation | **Good secondary use for either drive** |

**Setup:** Use as a `restic` or `borg` repository target. Keep powered 24/7. Do NOT unplug and shelve — unpowered NAND loses data in 1-3 years.

### 5. Log Storage (`/var/log` Isolation)

**Fit: Fair**

Isolates log floods from the OS disk. 240 GB gives years of retention headroom. Logs don't need SSD speed, but the isolation is useful.

| Aspect | Assessment |
|---|---|
| Endurance impact | Low-moderate writes (journald, service logs) |
| Performance benefit | Minimal — logs are rarely read |
| Data loss risk | Low — logs are not critical data |
| Value | Low — logs don't benefit from SSD speed, only isolation |
| Recommendation | **Possible but low-value** |

**Setup:** Mount with `noatime`. Cap journald: `SystemMaxUse=500M`, `SyncIntervalSec=5m`, `Compress=yes`. Set log rotation.

### 6. Swap (Secondary)

**Fit: Marginal**

Better than zram overflow for page-in latency. Only used under RAM pressure — evo-x2 has 128 GB RAM so swap is rarely hit.

| Aspect | Assessment |
|---|---|
| Endurance impact | Bursty writes (only under RAM pressure) |
| Performance benefit | Better than HDD swap for page-in latency |
| Data loss risk | None — swap data is by definition disposable |
| Value | Very low — evo-x2 has 128 GB RAM + 30 GB zram. Swap almost never used |
| Recommendation | **Optional secondary role (small partition)** |

**Setup:** 8-16 GB swap partition, not the whole drive. Low priority.

### 7. ZFS L2ARC (DAS Read Cache)

**Fit: Poor — USB latency kills it**

L2ARC is a second-level read cache between RAM and the HDD pool. It needs low-latency reads to be effective.

| Aspect | Assessment |
|---|---|
| Endurance impact | Moderate (continuous cache cycling, ~0.7 TB/day at default feed rate) |
| Performance benefit | **Negligible** — USB 3.0 adds 503 us random read latency. L2ARC needs <100 us. |
| Data loss risk | None — L2ARC is read-only, harmless if drive dies |
| RAM cost | L2ARC costs ARC RAM (~1.6 GB per 1 TB L2ARC). evo-x2 has 128 GB RAM so this is fine. |
| Recommendation | **No** — USB latency defeats the purpose. DAS already has 2x14TB HDDs + 128 GB ARC. |

**Why not:** The whole point of L2ARC is to be faster than HDDs (6-10 ms) but slower than RAM (nanoseconds). At 503 us random read latency via USB, it's faster than HDDs but the USB bridge adds enough overhead that the benefit is marginal compared to the 128 GB ARC already in place.

### 8. ZFS SLOG (ZFS Intent Log)

**Fit: Dangerous — data integrity risk**

SLOG accelerates synchronous writes (NFS, iSCSI, databases) by providing a low-latency write target for the ZIL.

| Aspect | Assessment |
|---|---|
| Endurance impact | High (sync writes hit the SLOG, then the pool) |
| Performance benefit | None — USB latency (503 us) is worse than writing directly to the HDD pool |
| Data loss risk | **High** — no power-loss protection. USB bridge prevents FLUSH_CACHE barriers. 34 dirty shutdowns. |
| Recommendation | **No** — data corruption risk on power loss. Consumer drive without PLP. |

**Why not:** SLOG needs: (1) low latency (<100 us), (2) power-loss protection (capacitor/supercap), (3) high write endurance. This drive has none of these. Using it as SLOG risks data corruption on power loss because the kernel can't guarantee writes are flushed to NAND before a crash.

### 9. VM Disk Images

**Fit: Poor — endurance and latency**

240 GB fits several lightweight Linux VMs or 1-2 heavier ones. But the write workload is the most endurance-intensive common use case.

| Aspect | Assessment |
|---|---|
| Endurance impact | Very high (guest memory dumps, boot storms, updates) — 60 TBW would be consumed in months |
| Performance benefit | USB latency (503 us random read) is too high for good VM performance |
| Data loss risk | Medium — VM state is lost if drive dies, but VMs should be snapshotted to bulk storage |
| Recommendation | **No** — USB latency + 60 TBW + old drive = poor performance and reliability |

### 10. Cold / Offline Backup Archive

**Fit: Disqualified**

| Aspect | Assessment |
|---|---|
| Data retention | **Severe data loss after 1-3 years unpowered** — NAND flash slowly loses charge |
| Recommendation | **Never** — use HDDs or tape for offline archives |

**Why not:** Multiple studies (Tom's Hardware,_HWLab) have found severe data loss on SSDs shelved for 1-3 years. Flash memory requires periodic power to refresh charge. HDDs and tape do not have this problem.

---

## Recommended Configuration

### SSD 1 (ext4, serial 174444471311) — Scratch / Temp Storage

Mount at `/mnt/scratch` with `noatime,data=writeback`:
- `nix-shell` build sandboxes (`TMPDIR=/mnt/scratch`)
- Download staging area
- Transcode working directory
- `ccache` / `cargo` cache (rebuildable)
- Compiler output directories

**Why ext4:** Scratch data is disposable. ext4 with `data=writeback` eliminates the journal double-write penalty (136 MB/s → expected ~280 MB/s). No need for checksums or snapshots on disposable data.

### SSD 2 (btrfs, serial 174244451713) — Docker + Nix Auxiliary Store

Mount at `/mnt/ssd-btrfs` (already done) with `compress=zstd,noatime`:
- Docker data-root (`/mnt/ssd-btrfs/docker`)
- Nix auxiliary store / binary cache proxy
- btrfs snapshots for container state rollback

**Why btrfs:** Docker images are compressible (base OS layers, binaries). btrfs snapshots give rollback safety for container state. `compress=zstd` saves 15-30% on Docker image layers.

### Why This Combination

- Scratch (ext4) maximizes write speed for ephemeral data (journal overhead eliminated with `data=writeback`)
- btrfs (compress=zstd) saves space on Docker images (many are compressible)
- Neither use case cares about data loss — if a 10-year-old SSD dies, rebuild images and re-download nix store
- 60 TBW is plenty for read-mostly workloads (Docker images, nix store) and acceptable for scratch (ephemeral data)
- Both drives remain powered 24/7 (no NAND charge loss concern)

---

## What NOT to Do

| Don't | Why |
|---|---|
| Put irreplaceable data on these drives | 10+ year old hardware, sudden failure possible |
| Use as ZFS SLOG | USB prevents FLUSH barriers, no PLP, 34 dirty shutdowns |
| Use as ZFS L2ARC | USB latency (503 us) defeats the purpose (<100 us needed) |
| Use for VM disk images | 60 TBW consumed in months, USB latency too high |
| Use for databases with frequent writes | 60 TBW + USB latency + no PLP |
| Use as cold/offline backup | NAND loses charge unpowered — data loss in 1-3 years |
| Use without `fstrim.timer` | TRIM extends SandForce controller life and maintains write performance |
| Expect high reliability | SandForce SF-2000 has known age-related failure modes (BSOD, controller death, firmware bugs) |

---

## Summary Ranking

| Rank | Use Case | Fit | Endurance | Data Loss Risk | USB Latency Impact |
|---|---|---|---|---|---|
| 1 | Scratch / temp build storage | Excellent | High writes (disposable) | Low (ephemeral) | Low (sequential) |
| 2 | Nix store mirror (read-only) | Excellent | Low writes | Low (rebuildable) | Low (read-mostly) |
| 3 | Docker / container storage | Good | Moderate writes | Medium (rebuildable) | Low-moderate |
| 4 | Powered backup target | Good | Low writes | Low (backup copy) | Low (sequential) |
| 5 | Log storage | Fair | Low-moderate | Low | None |
| 6 | Swap (secondary) | Marginal | Bursty | None | Moderate (random) |
| 7 | ZFS L2ARC | Poor | Moderate | None | **Kills it** (503 us) |
| 8 | ZFS SLOG | Dangerous | High | **High** (no PLP) | **Kills it** (503 us) |
| 9 | VM disk images | Poor | Very high | Medium | High (random R/W) |
| 10 | Cold/offline backup | Disqualified | None | **Extreme** (charge loss) | N/A |

---

## fstab / NixOS Configuration

### SSD 1: Scratch (ext4)

```nix
# configuration.nix
fileSystems."/mnt/scratch" = {
  device = "/dev/disk/by-uuid/<ext4-uuid>";
  fsType = "ext4";
  options = [ "noatime" "data=writeback" ];
};
```

### SSD 2: Docker + Nix (btrfs)

```nix
# configuration.nix
fileSystems."/mnt/ssd-btrfs" = {
  device = "/dev/disk/by-uuid/<btrfs-uuid>";
  fsType = "btrfs";
  options = [ "noatime" "compress=zstd" ];
};

# Move Docker data-root
virtualisation.docker.daemon.settings = {
  data-root = "/mnt/ssd-btrfs/docker";
};
```

### Both: Enable TRIM

```nix
# Already enabled on evo-x2
services.fstrim.enable = true;
```

---

## Endurance Budget

| Workload | Writes/day | 60 TBW lifespan |
|---|---|---|
| Read-only (nix store, Docker images) | ~0.5 GB/day | ~300+ years |
| Scratch builds (nix-shell, cargo, ccache) | ~5-10 GB/day | ~16-33 years |
| Docker build churn (daily image rebuilds) | ~2-5 GB/day | ~33-82 years |
| Log storage (journald + service logs) | ~1-3 GB/day | ~55-164 years |
| Powered backup target (daily rsync) | ~1-5 GB/day | ~33-164 years |
| VM disk images (continuous R/W) | ~20-50 GB/day | ~3-8 years |
| Database writes (continuous) | ~10-30 GB/day | ~5-16 years |
| SLOG (sync writes) | ~50-100 GB/day | ~1.5-3 years |

**Note:** These are endurance-only calculations. The drives are 10+ years old — hardware failure is more likely than NAND wear-out. The SandForce controller, firmware, and PCB components age regardless of write load.

---

## Research Sources

- [Wikipedia: SandForce](https://en.wikipedia.org/wiki/SandForce) — DRAM-less design, DuraWrite compression, AES-128, RAISE
- [Wikipedia: Write amplification](https://en.wikipedia.org/wiki/Write_amplification) — SandForce WA of 0.5-0.14, factors affecting WA
- [OpenZFS docs: Caching](https://openzfs.github.io/openzfs-docs/Basic%20Concepts/Pool%20Structure/Caching.html) — L2ARC sizing, SLOG requirements
- [TrueNAS docs: SLOG](https://www.truenas.com/docs/references/slog/) — SLOG sizing, PLP requirements
- [NixOS Wiki: Storage optimization](https://wiki.nixos.org/wiki/Storage_optimization) — `/nix/store` sizing, GC, optimisation
- [NixOS Discourse: How much storage?](https://discourse.nixos.org/t/how-much-storage-does-nixos-need/8805) — Real-world store sizes
- [SanDisk product page](https://www.sandisk.com/en-ap/products/ssd/internal-ssd/sandisk-ssd-plus-sata-iii-ssd) — 60 TBW endurance, 3-year warranty
- [Tom's Hardware: Unpowered SSD endurance](https://www.tomshardware.com/pc-components/storage/unpowered-ssd-endurance-investigation-finds-severe-data-loss-and-performance-issues-reminds-us-of-the-importance-of-refreshing-backups) — Data loss on shelved SSDs
- [SSD Wiki: SandForce SF-2281](https://www.ssdwiki.com/controller/sandforce-sf-2281/) — Age-related failures, firmware bugs
- [Reddit: SanDisk SDSSDA-240G DRAM-less confirmation](https://www.reddit.com/r/buildapcsales/comments/7nmxy3/) — "TLC DRAMless SSD like the 120 and 240GB models"
