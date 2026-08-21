# Secondary SSD (Samsung 990 PRO) Setup Proposal

> Brainstorm: adding a Samsung 990 PRO 1TB as a secondary drive to evo-x2, offloading write-heavy workloads off the QLC Lexar NQ790.

---

## Why the current drive (Lexar NQ790 QLC) is problematic

evo-x2 boots from a **Lexar NQ790** NVMe — a **QLC NAND** drive. QLC stores 4 bits per cell (vs 3 in TLC), which means:

- **16 voltage states per cell** → narrower margins, longer programming time
- **3-5x lower sustained write throughput** — once the pSLC cache fills, writes collapse to ~100-200 MB/s (slower than a mechanical HDD)
- **~1,000 P/E cycles per cell** vs 3,000 for TLC, 10,000 for MLC (lower endurance)
- **Worse random I/O** — QLC dies hard on small random writes

### Documented incidents caused by QLC on this machine

| Incident                           | Root cause                                                                                                                          | Reference                                                |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| WDT hard resets (2026-06)          | `discard=async` on QLC NAND caused 253ms discard latencies → 17.7s BTRFS commit freezes → watchdog reset                            | `AGENTS.md` gotcha table                                 |
| BTRFS metadata ENOSPC (2026-06-26) | Nightly `nix-gc` triggered metadata transactions on a full filesystem → I/O deadlock → WDT reset                                    | `docs/troubleshooting/btrfs-metadata-enospc-recovery.md` |
| Chronic GPUActive memory pressure  | HMB (Host Memory Buffer) borrows system RAM for the SSD's FTL map because the NQ790 has no DRAM — competes with GPUActive's 51+ GiB | `AGENTS.md` Strix Halo section                           |

---

## SSD comparison (verified specs)

Sources: Samsung official datasheet, Crucial official spec sheet, Tom's Hardware, TechPowerUp, Guru3D, SSD Wiki.

| Spec                            | Lexar NQ790 (current)    | Crucial P3 Plus 1TB       | Samsung 990 PRO 1TB                      |
| ------------------------------- | ------------------------ | ------------------------- | ---------------------------------------- |
| **NAND**                        | QLC                      | QLC (Micron 176-layer)    | **TLC (Samsung V7, 176-layer)**          |
| **Controller**                  | Maxio MAP1602            | Phison PS5021-E21T        | **Samsung Pascal (8nm)**                 |
| **DRAM**                        | HMB (borrows system RAM) | None (HMB only, 64 MB)    | **1 GB LPDDR4**                          |
| **Seq Read**                    | ~7,000 MB/s              | 5,000 MB/s                | **7,450 MB/s**                           |
| **Seq Write**                   | ~6,000 MB/s              | 3,600 MB/s (1TB)          | **6,900 MB/s**                           |
| **Sustained Write (post-pSLC)** | Drops sharply (QLC)      | ~100-200 MB/s (QLC cliff) | ~3,000+ MB/s (TLC, no cliff)             |
| **Random Read IOPS**            | ~1,000K                  | ~650K (unofficial)        | **1,200K**                               |
| **Random Write IOPS**           | ~800K                    | ~800K (unofficial)        | **1,550K**                               |
| **Endurance (TBW)**             | ~600 TBW                 | **220 TBW**               | 600 TBW                                  |
| **Warranty**                    | 5y                       | 5y                        | 5y                                       |
| **Form Factor**                 | M.2 2280                 | M.2 2280                  | M.2 2280                                 |
| **Interface**                   | PCIe 4.0 x4              | PCIe 4.0 x4               | PCIe 4.0 x4                              |
| **Encryption**                  | AES-256 (no Opal)        | None                      | **AES-256, Opal 2.0, IEEE 1667, eDrive** |
| **Price (approx, new)**         | ~$70-90                  | ~$70-85                   | ~$120-150                                |

### Key takeaways

- **NQ790 vs P3 Plus:** Both QLC, but the NQ790 is faster. The P3 Plus is the budget pick — DRAM-less, 1/3 the endurance, brutal QLC write cliff. A downgrade despite similar price.
- **NQ790 vs 990 PRO:** The 990 PRO is the only TLC drive. Same 600 TBW on paper, but TLC sustains real-world writes where QLC collapses. DRAM + better controller = much lower latency under load.
- **990 PRO vs P3 Plus:** Different class. 2x endurance, 40% better seq read, 90% better seq write, 2x random write IOPS, real DRAM, full hardware encryption.

---

## Hardware encryption (relevant to 990 PRO)

The 990 PRO has the **full Opal stack**:

- **AES-256** — hardware encryption of every byte written to NAND, zero CPU cost
- **Opal 2.0 (TCG)** — the standard for self-encrypting drives. Lets software (BitLocker, `sedutil`, Linux `cryptsetup`) manage the key: lock/unlock, pre-boot auth, secure erase
- **IEEE 1667** — Microsoft credential passthrough
- **eDrive** — BitLocker delegation protocol (encrypt on the drive, not the CPU)

### Why it matters

1. **Secure erase is instant** — "erase the key" makes all data unrecoverable
2. **Performance is free** — CPU-based encryption (LUKS) costs ~2-5% throughput; hardware encryption is zero overhead
3. **Stolen drive = unreadable** — even if someone mounts the NVMe on another machine, they get ciphertext

> **Current state:** evo-x2 has **no disk encryption**. No LUKS, no Opal/SED. All data (`/`, `/nix`, `/home`, `/data`) is plaintext at rest. The sops age key is derivable from `/etc/ssh/ssh_host_ed25519_key`, so a stolen drive exposes all secrets. This has been flagged as a high-priority security gap in multiple status reports (2026-05-02, 2026-05-03, 2026-05-04) but never implemented.

---

## Proposed setup: 990 PRO as secondary drive

### Physical

The evo-x2 board (Strix Halo, AMD Ryzen AI Max+ 395) has **2 M.2 slots**, both PCIe 4.0 x4.

| Slot  | Drive                     | Role                                 |
| ----- | ------------------------- | ------------------------------------ |
| M.2_1 | Lexar NQ790 (QLC)         | Boot (`/`), `/home`, `/data` (stays) |
| M.2_2 | **Samsung 990 PRO (TLC)** | Write-heavy workloads                |

### The Windows problem

The 990 PRO may have an old Windows install. Options:

1. **Wipe entirely** → fresh BTRFS/ext4 (recommended — NixOS is the only OS in use)
2. **Shrink Windows partition** → dual-boot (not useful — NixOS is the sole OS)
3. **Mount read-only** → salvage files first, then wipe

**Recommendation:** Option 3 → Option 1. Mount Windows read-only, copy off any wanted files, then wipe.

### Strategy: put hot, write-heavy workloads on TLC

The highest-value move is moving the workloads that caused the QLC pain points:

| Workload                       | Current (NQ790 QLC) | Proposed (990 PRO TLC)  | Why                                    |
| ------------------------------ | ------------------- | ----------------------- | -------------------------------------- |
| `/nix` store                   | Root `@` subvol     | Separate `@nix` subvol  | Millions of small writes during builds |
| Go/Cargo/NPM caches            | NQ790 subvols       | 990 PRO                 | Sustained write pressure, no QLC cliff |
| `/rust-cache` (`target/` dirs) | ext4 on NQ790       | ext4 on 990 PRO         | 85K+ small files, heavy random IO      |
| monitor365 DuckDB              | `/data` on NQ790    | Move to 990 PRO         | WAL writes, DB checkpointing           |
| Docker volumes                 | `/data` on NQ790    | Consider for ClickHouse | Random write sensitivity               |
| Root `/`                       | NQ790               | Stays on NQ790          | Avoids reinstall; not write-hot        |
| `/home` media, photos          | NQ790               | Stays on NQ790          | Mostly sequential reads                |

### Proposed config

```nix
# hardware-configuration.nix — NEW 990 PRO mounts
fileSystems = {
  # Keep root @ on the NQ790 (don't want to reinstall)
  "/" = mkFilesystem { /* unchanged */ };

  # Move /nix to the 990 PRO — biggest win
  # Nix store = millions of small files, heavy write IO during builds
  "/nix" = mkFilesystem {
    device = "/dev/disk/by-uuid/<990-pro-uuid>";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" "ssd" "space_cache=v2" "nofail" ];
  };

  # Move build caches to the 990 PRO — no QLC write cliff during cargo build / go build
  "/fast" = mkFilesystem {
    device = "/dev/disk/by-uuid/<990-pro-uuid>";
    fsType = "btrfs";
    options = [ "subvol=@fast" "compress=zstd" "noatime" "ssd" "space_cache=v2" "nofail" ];
  };

  # /data stays on NQ790 for now (large, mostly sequential reads — AI models, photos)
};
```

Re-point the hot cache paths:

```nix
# snapshots.nix — redirect caches to the TLC drive
cacheSubvolumes = {
  "@go"    = "/fast/go";         # was /home/lars/go
  "@cargo" = "/fast/cargo";      # was /home/lars/.cargo
  "@npm"   = "/fast/npm";        # was /home/lars/.npm
  "@cache-home" = "/fast/cache"; # was /home/lars/.cache
};

# /rust-cache → now on the 990 PRO too (ext4, separate partition)
"/rust-cache" = mkFilesystem {
  device = "/dev/disk/by-partlabel/rust-cache-tlc";
  fsType = "ext4";
  options = [ "noatime" "nofail" "x-systemd.automount" "x-systemd.idle-timeout=10min" ];
};
```

### Expected wins

1. **No more QLC write cliff during builds** — `cargo build`, `go build`, `nix build` no longer collapse to 100-200 MB/s after pSLC cache fills
2. **DRAM-backed FTL** — 990 PRO has 1 GB LPDDR4; NQ790 borrows from system RAM via HMB (which is already under pressure from GPUActive eating 51+ GiB)
3. **2x random write IOPS** — matters for BTRFS CoW, Docker overlay writes, DuckDB WAL
4. **Real `discard` behavior** — TLC handles async TRIM without the 253ms latency death spiral that caused WDT resets
5. **Hardware encryption option** — 990 PRO's full Opal stack could enable disk encryption without CPU overhead (future work)

### The catch

`/` cannot be migrated without a reinstall (or a complex offline `btrfs replace`). The clean path:

1. Install the 990 PRO physically into M.2_2
2. Boot NixOS (still on NQ790)
3. Partition the 990 PRO, format subvolumes (`@nix`, `@fast`, ext4 for rust-cache)
4. `rsync` the caches + `/nix` over to the new drive
5. Update `hardware-configuration.nix` and `snapshots.nix`
6. Deploy
7. Clear the old caches from the NQ790 to reclaim space

### Future: LUKS / disk encryption

If the 990 PRO eventually hosts `/nix` and caches with sensitive build artifacts, consider:

- **LUKS2 + TPM auto-unlock** via `systemd-cryptenroll` (already noted in `boot.nix:52`)
- **Opal SED** via `sedutil` (zero CPU cost, but less flexible than LUKS)
- The 990 PRO's hardware encryption makes either path lower-overhead than on the NQ790

---

## Open questions

- [ ] Is the old 990 PRO still functional? (Verify before relying on it)
- [ ] What's on the Windows install worth salvaging?
- [ ] Should Docker volumes (`/data`) move too, or stay on NQ790 (large, mostly sequential)?
- [ ] Should we enable disk encryption on the new drive from the start?
