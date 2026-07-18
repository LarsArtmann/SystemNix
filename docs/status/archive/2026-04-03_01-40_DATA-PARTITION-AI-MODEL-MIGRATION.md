# Data Partition & AI Model Migration — Status Report

**Date:** 2026-04-03
**Host:** evo-x2 (GMKtec AMD Ryzen AI Max+ 395)
**Disk:** Lexar SSD NQ790 2TB (`/dev/nvme0n1`)

---

## Summary

Created a dedicated 800GB BTRFS partition (`/data`) for AI models and large datasets, migrating 222GB off the root partition. Root filesystem recovered from 39GB free (93% used) to 193GB free (62% used).

---

## What Changed

### New Partition

| Property      | Value                                                      |
| ------------- | ---------------------------------------------------------- |
| Device        | `/dev/nvme0n1p8`                                           |
| Size          | 800 GB                                                     |
| Filesystem    | BTRFS                                                      |
| Label         | `data`                                                     |
| UUID          | `046ea663-da55-48b7-b516-0dcdb87ba710`                     |
| Mount point   | `/data`                                                    |
| Mount options | `compress=zstd:3,noatime,ssd,discard=async,space_cache=v2` |
| No snapshots  | Intentionally excluded from Timeshift                      |

### Data Migrated

| Source                       | Destination                               | Size        |
| ---------------------------- | ----------------------------------------- | ----------- |
| `~/projects/wan-i2v/models/` | `/data/models/`                           | 213 GB      |
| — Wan2.1-I2V-14B-480P        | `/data/models/Wan2.1-I2V-14B-480P/`       | 84 GB       |
| — LTX-Video-0.9.7-distilled  | `/data/models/LTX-Video-0.9.7-distilled/` | 45 GB       |
| — HunyuanVideo1.5-I2V        | `/data/models/HunyuanVideo1.5-I2V/`       | 36 GB       |
| — Wan2.2-TI2V-5B-Diffusers   | `/data/models/Wan2.2-TI2V-5B-Diffusers/`  | 32 GB       |
| — CogVideoX-5b-I2V           | `/data/models/CogVideoX-5b-I2V/`          | 17 GB       |
| `~/.ollama/models/`          | `/data/ollama/models/`                    | 3.8 GB      |
| `~/.cache/huggingface/`      | `/data/cache/huggingface/`                | 4.4 GB      |
| **Total migrated**           |                                           | **~222 GB** |

### Symlinks Created

| Symlink                     | Target                    |
| --------------------------- | ------------------------- |
| `~/projects/wan-i2v/models` | `/data/models`            |
| `~/.ollama/models`          | `/data/ollama/models`     |
| `~/.cache/huggingface`      | `/data/cache/huggingface` |

### NixOS Config Changes

- `platforms/nixos/hardware/hardware-configuration.nix` — added `fileSystems."/data"` entry
- `platforms/nixos/system/snapshots.nix` — added `/data` to btrfs auto-scrub targets

---

## Disk Layout After

```
[p7 2G EFI] [p1 2G EFI] [p6 512G ROOT /] [p8 800G /data] [p3 31G old] [p2 10G swap] [p5 4G old] [p4 1.2G WinRec]
```

| Partition   | Size  | Type  | Mount   | Status               |
| ----------- | ----- | ----- | ------- | -------------------- |
| `nvme0n1p7` | 2G    | EFI   | `/boot` | Active               |
| `nvme0n1p1` | 2G    | EFI   | —       | Unused (old?)        |
| `nvme0n1p6` | 512G  | BTRFS | `/`     | 62% used (193G free) |
| `nvme0n1p8` | 800G  | BTRFS | `/data` | 22% used (630G free) |
| `nvme0n1p3` | 31.3G | ext4  | —       | Unused (old root?)   |
| `nvme0n1p2` | 10G   | swap  | [SWAP]  | Active               |
| `nvme0n1p5` | 4G    | BTRFS | —       | Unused               |
| `nvme0n1p4` | 1.2G  | NTFS  | —       | Windows recovery     |

---

## Action Required

**Run `just switch` (or `sudo nixos-rebuild switch --flake .#evo-x2`)** to persist the `/data` mount across reboots. Currently mounted manually — will not survive reboot without rebuild.

---

## Future Considerations

- **Unused partitions** (p1: 2G, p3: 31.3G, p5: 4G) — 37GB reclaimable at end of disk, but trapped behind active swap. Would require live USB to rearrange.
- **Monitor365** (40G in `~/projects/`) — Rust build cache, could benefit from `/data` relocation.
- **`~/.cache/pip`** (9G) and **`~/.cache/go-build`** (1.7G) — safe to clean periodically.
- **Nix generations** — 20 generations in 3 days. Consider `nix-collect-garbage -d` to prune old ones.
