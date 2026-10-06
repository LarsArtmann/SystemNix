# Decision: dedicate the spare 240 GB SSD to the Rust build cache

**Date:** 2026-10-06
**Status:** Ratified (user direction) — config landed, awaiting the maintenance-window setup
**Supersedes:** the 2026-09-22 decision to merge both SanDisk SDSSDA240G SSDs into one btrfs filesystem at `/mnt/buildcache`

## Decision

The empty second SanDisk SDSSDA240G (serial `174244451713`, the former
`ssd-btrfs` Docker earmark) becomes a **dedicated Rust build cache** at
`/mnt/rust-cache` (`services.rust-cache`, btrfs `compress=zstd:1`, single
profile). It holds `CARGO_HOME`, `SCCACHE_DIR`, and product `target/` dirs. The
Go/JS/Python caches stay on `/mnt/buildcache` (`services.buildcache`).

## Why

- **Rust target/ trees are the single largest, churn-heaviest cache** (121 GB of
  targets measured 2026-09-22) and are pure write amplification. Giving them
  their own filesystem keeps Go/JS/Python caches from competing for buildcache
  capacity and takes Rust's write pressure off that disk (freeze-#12 mitigation:
  the 2-day IO storm ran its floor through the shared USB link).
- **btrfs + zstd:1 fits the workload**: debuginfo/DWARF objects compress
  ~2-2.5×, and cargo does NOT content-hash-verify its cache the way Go does — a
  torn write (SandForce SF-2000, no PLP) becomes a btrfs checksum EIO = clean
  cache-miss rebuild instead of a silently-served corrupt object.
- **The merge offered no isolation**: both disks already shared one USB link +
  JMS567 enclosure, so the merge's only wins were capacity and compression —
  both of which the dedicated Rust disk also delivers, plus per-workload GC and
  monitoring.

## What changed in the tree

- New module `modules/nixos/services/rust-cache.nix` (mount, `rust-cache-init`,
  `rust-cache-usb-recovery`, `rust-cache-metrics`, `rust-cache-gc`, integration
  Gatus checks).
- `platforms/nixos/users/home.nix`: `SCCACHE_DIR`/`CARGO_HOME` → `/mnt/rust-cache`,
  `.cargo/registry` symlink → `/mnt/rust-cache/cargo/registry`, activation reap.
- `platforms/nixos/system/snapshots.nix`: rust target symlinks →
  `/mnt/rust-cache/rust/<project>`.
- `modules/nixos/services/buildcache.nix`: rust/sccache/cargo dirs removed (now
  owned by rust-cache).
- New `scripts/migrate-rust-cache.sh` + `nix run .#migrate-rust-cache`.
- `scripts/das-link-recovery-check.sh`: the spare disk is no longer "frozen" —
  it is checked as `/mnt/rust-cache` (btrfs).
- `scripts/buildcache-btrfs-convert.sh`: marked SUPERSEDED / do-not-run.

## Setup (maintenance window)

```bash
nix run .#migrate-rust-cache   # format btrfs, mount, move rust/sccache/cargo
nix run .#deploy               # persistent mount, env vars, symlinks, monitoring
```

Expect a few days of cold rust/sccache rebuilds (the cargo registry is moved,
not re-fetched; target/ + sccache repopulate).
