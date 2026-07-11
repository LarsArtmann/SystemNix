# NixOS + Btrfs: Wiki Recommendations vs. SystemNix Reality

**Date:** 2026-07-11
**Sources:** NixOS Wiki (wiki.nixos.org), Arch Wiki, Disko docs, community guides (notashelf, Haseeb Majid, NixOS Discourse, Btrfs readthedocs.io)
**Scope:** Every Btrfs recommendation for NixOS, compared against what SystemNix (evo-x2) actually does, with gaps and risks identified.

---

## Master Comparison Table

### 1. Subvolume Layout

| Recommendation | Source | SystemNix Status | Notes |
|---|---|---|---|
| Use **flat (top-level) subvolumes** — not nested | NixOS Wiki, Arch Wiki | **Partial** — `@` is top-level, but `/nix` lives *inside* `@` (not its own `@nix`) | Flat subvols can be snapshotted/rolled back independently |
| `/` on its own subvolume (`@` or `@root`) | NixOS Wiki | **Done** — `@` at `/` | |
| `/home` on its own subvolume (`@home`) | NixOS Wiki, notashelf | **Not done** — lives inside `@` | If root is rolled back, `/home` rolls back too |
| `/nix` on its own subvolume (`@nix`) | NixOS Wiki: *"persistent but not worth backing up, trivially reconstructable"* | **Not done** — lives inside `@` | Btrbk snapshots of `@` include the full nix store (wasteful) |
| `/persist` subvolume for impermanence | notashelf, impermanence module | **Not done** — SystemNix does not use erase-your-darlings | Optional pattern; SystemNix uses generations instead |
| `/var/log` on its own subvolume | NixOS Wiki | **Not done** — lives inside `@` | Optional; helps with impermanence isolation |
| `/swap` subvolume with `nodatacow` | NixOS Wiki, Arch Wiki | **N/A** — uses zramSwap instead (no disk swap) | zramSwap (17% of 128G = ~16G compressed) is the sole swap |
| Mount `subvolid=5` for pool access (btrbk) | NixOS Wiki (Btrbk) | **Done** — `/mnt/btrfs-root` with `subvol=/` via automount | Used by btrbk for snapshot access to all subvolumes |
| Cache directories as separate subvolumes | Community configs | **Done** — `@cache-home`, `@go`, `@npm`, `@cargo` with automount + idle timeout | Beyond wiki guidance — prevents cache bloat from CoW fragmentation and snapshot pollution |
| Rust `target/` dirs on ext4 (not Btrfs) | — | **Done** — `/rust-cache` is ext4, symlinked into Rust projects | SystemNix innovation — avoids 85K+ small file COW fragmentation on Btrfs |

### 2. Mount Options

| Recommendation | Source | `/` (Btrfs) | `/data` (Btrfs) | `/rust-cache` (ext4) |
|---|---|---|---|---|
| `compress=zstd` (level 3 default) | NixOS Wiki, Arch Wiki, community consensus | **Done** | **Done** (`zstd:3` explicit) | N/A (ext4) |
| `noatime` | NixOS Wiki: *"reduces disk writes, improves performance"*; Arch Wiki: CoW makes atime especially expensive | **Done** | **Done** | **Done** |
| `ssd` | Arch Wiki (auto-detected on SSDs since kernel 4.x) | **Not set** (auto-detected) | **Done** (explicit) | N/A |
| `space_cache=v2` | Arch Wiki (default since btrfs-progs 5.15) | **Not set** (mkfs default) | **Done** (explicit) | N/A |
| `discard=async` | Arch Wiki (auto-enabled kernel 6.2+) | **Not set** — intentionally removed | **Not set** — intentionally removed | N/A |
| `nofail` on non-root mounts | SystemNix gotcha: boot emergency shell without it | Root (not applicable) | **Done** | **Done** |
| `subvol=path` (not `subvolid=`) | Arch Wiki: *"subvolid may change on snapshot restore → boot failure"* | **Done** (`subvol=@`) | N/A (toplevel) | N/A |
| `x-systemd.automount` + `idle-timeout` | Community pattern for lazy mounts | Not needed (root) | Not needed (always needed) | **Done** (10min idle) |

### 3. TRIM / Discard

| Recommendation | Source | SystemNix Status |
|---|---|---|
| Use `services.fstrim.enable` (periodic) over `discard` mount option | NixOS Wiki: *"continuous trimming can negatively impact SSD performance"* | **Done** — `services.fstrim.enable = true` |
| `discard=async` is safe on most SSDs (kernel 6.2+) | Arch Wiki | **Intentionally removed** — QLC NAND (Lexar NQ790) causes 253ms discard latency → 17.7s BTRFS commit stalls → WDT hard reset (2026-07-08 crash). SystemNix-specific hardware constraint not covered by wikis |
| Weekly fstrim cadence is sufficient | NixOS Wiki | **Done** — NixOS default weekly fstrim timer |

### 4. Compression

| Recommendation | Source | SystemNix Status |
|---|---|---|
| Use `compress=zstd` | NixOS Wiki, Arch Wiki, all community configs | **Done** — on `/` and `/data` |
| Level 3 (default) is the sweet spot | NixOS Discourse consensus | **Done** — `/` uses `compress=zstd` (default level 3), `/data` uses `compress=zstd:3` (explicit) |
| `compress-force=zstd` for extra savings (10-20%) | Arch Wiki: *"against official Btrfs guidelines"* | **Not used** — standard `compress` mode. Reasonable choice; `compress-force` is explicitly discouraged by upstream Btrfs docs |
| Compression applies to newly written data only | Arch Wiki, Btrfs docs | **Understood** — documented in AGENTS.md |
| Nix 2.4+ fixed `fallocate()` breaking compression | [nix PR #4094](https://github.com/NixOS/nix/pull/4094) | **N/A** — modern Nix, compression works correctly |
| Compression is filesystem-wide, not per-subvolume | Btrfs docs, Forza's reference | **Understood** — `compress=zstd` on `/` covers all `@` subvolumes |
| `compsize` to verify compression ratios | Arch Wiki | **Available** — not actively monitored |

### 5. Snapshots

| Recommendation | Source | SystemNix Status |
|---|---|---|
| Automated snapshots via btrbk or snapper | NixOS Wiki (Btrbk, Snapper pages) | **Done** — btrbk, daily at 23:00 (staggered before GC at 00:00) |
| Retention policy: 7d minimum, 14d + 4w extended | NixOS Wiki examples | **Done** — `snapshot_preserve_min = "7d"`, `snapshot_preserve = "14d 4w"` |
| Don't snapshot `/nix` separately | NixOS Discourse: *"trivially reconstructable"*, generations provide rollback | **Gap** — `@` (which includes `/nix`) IS snapshotted. CoW means only changed blocks are stored, so the overhead is incremental, not full duplication. But snapshots are larger than necessary |
| Snapshot only specific subvolumes, not root | NixOS Wiki (Btrbk) | **Partial** — only `@` is snapshotted. But `@` contains `/nix`, `/home`, `/var/log`, everything |
| Local snapshots are NOT backup | NixOS Wiki: *"If disk fails, snapshots are lost"* | **Gap** — no remote `btrbk send/receive` target configured. All snapshots are local-only |
| Verify snapshot freshness | — | **Done** — `btrfs-verify-snapshots` daily timer checks snapshots are <3 days old, alerts via `onFailure` |
| Stagger snapshots before GC | — | **Done** — btrbk at 23:00, nix-gc at 00:00. Expired snapshots free extents before GC runs (prevents the 2026-06-26 metadata ENOSPC crash) |

### 6. Data Integrity (Scrubbing)

| Recommendation | Source | SystemNix Status |
|---|---|---|
| Enable `services.btrfs.autoScrub` | NixOS Wiki | **Done** — monthly, on `/` and `/data` |
| Only need topmost subvolume for scrub | NixOS Wiki: nested subvols covered by parent | **Done correctly** — `/` covers `@`, `/data` covers its toplevel |
| Monthly cadence | NixOS Wiki default | **Done** — `interval = "monthly"` |

### 7. Nix Store Optimization

| Recommendation | Source | SystemNix Status |
|---|---|---|
| `auto-optimise-store = true` (incremental hardlink dedup) | Nix Manual: *"reclaims 25-35% of store"* | **Done** — `nix-settings.nix:34` |
| `nix.optimise.automatic = true` (periodic full optimise) | NixOS Wiki | **Done** — `nix-settings.nix:53` |
| `bees` block-level dedup | Arch Wiki, NixOS Wiki | **Not enabled** — optional. Bees finds identical blocks *within* different files (nix hardlinks only match whole identical files). Resource-intensive |
| Don't snapshot `/nix` | NixOS Discourse consensus | **Gap** — see Snapshots section above |
| `compress=zstd` on nix store | NixOS Wiki, community configs | **Done** — filesystem-wide via `/` mount |

### 8. Swap

| Recommendation | Source | SystemNix Status |
|---|---|---|
| Swap file on dedicated `nodatacow` subvolume | NixOS Wiki, Arch Wiki | **N/A** — no disk swap. Uses zramSwap instead |
| NixOS auto-disables CoW for swap files | NixOS Wiki | **N/A** |
| `resume_offset` for hibernation | NixOS Wiki | **N/A** — no hibernation, zramSwap is volatile |
| zramSwap as alternative | NixOS Wiki | **Done** — 17% of 128G (~16G virtual), zstd compressed (~6G physical). Swappiness=10 |

### 9. Monitoring & Health (Beyond Wiki Guidance)

| Capability | Source | SystemNix Status |
|---|---|---|
| Metadata ENOSPC prevention | — (not in any wiki) | **Done** — `btrfs-health.nix`: GC guard blocks reclamation when device-unallocated <10% |
| Prometheus metrics for chunk allocation | — (not in any wiki) | **Done** — 5-min metrics: device size, unallocated, allocated, metadata size/used/utilization % |
| Gatus health check + Discord alert | — (not in any wiki) | **Done** — alerts on device-unallocated % and metadata utilization % |
| DMS widget showing Btrfs health | — (not in any wiki) | **Done** — `systemnix-btrfs` plugin in Quickshell |
| Snapshot freshness verification | — (not in any wiki) | **Done** — daily timer, alerts if snapshots >3 days old |
| BTRFS build sandbox cleanup | — (not in any wiki) | **Done** — `nix-build-cleanup` timer (every 4h + on boot) for `/nix/var/nix/builds/` orphans |
| `/tmp` tmpfs size cap (16 GiB) | — (not in any wiki) | **Done** — prevents go-build cache accumulation. Uses `systemd.mounts` (NOT `fileSystems` — that caused deploy failure) |
| Hardware watchdog (sp5100-tco) | — | **Done** — 30s timeout, hard reset on complete unresponsiveness |

### 10. Filesystem Safety (Eval-Time Validation)

| Capability | Source | SystemNix Status |
|---|---|---|
| Cross-filesystem option contamination guard | — (not in any wiki) | **Done** — `lib/filesystems.nix` (`mkFilesystem`): throws at eval time if btrfs-only options (compress, subvol, discard=async, space_cache) are used on ext4/xfs. Caught the `discard=async` on ext4 boot emergency |
| `nofail` on all non-root mounts | SystemNix gotcha | **Done** — `/data` and `/rust-cache` both have `nofail` |
| Pre-deploy validation | — | **Done** — `nix run .#pre-deploy-check` catches boot-breaking issues before switch |

### 11. Boot & Initrd

| Recommendation | Source | SystemNix Status |
|---|---|---|
| `boot.supportedFilesystems = [ "btrfs" ]` | NixOS Wiki | **Done** — NixOS enables this automatically when root is btrfs |
| systemd initrd for rollback services | notashelf impermanence guide | **Done** — `boot.initrd.systemd.enable` (but no rollback service — not using erase-your-darlings) |
| `btrfs` hook in initrd for multi-device | Arch Wiki | **N/A** — single device |

---

## Gap Analysis: What's Missing or Could Be Improved

### High Priority

| Gap | Risk | Effort | Recommendation |
|---|---|---|---|
| **No remote backup of snapshots** | Total data loss if NVMe fails. All btrbk snapshots are local-only. NixOS Wiki: *"Local snapshots are not a backup solution alone."* | Medium — needs remote target (Hetzner StorageBox, rsync.net, etc.) | Add `btrbk` `target` for `btrfs send/receive` to a remote host. SystemNix already researched Hetzner StorageBox (see `docs/research/hetzner-storagebox-borgbackup.md`) |
| **`/nix` inside `@` (not its own subvolume)** | (1) Btrbk snapshots include the full nix store. (2) Cannot do erase-your-darlings without destroying `/nix`. (3) Snapshot rollback would roll back the nix store too | High — requires subvolume migration on live system | Create `@nix`, move `/nix` contents, update mounts, update btrbk config to exclude it. Invasive on live system; defer until next reinstall |

### Medium Priority

| Gap | Risk | Effort | Recommendation |
|---|---|---|---|
| **`/home` inside `@` (not its own subvolume)** | Cannot snapshot/rollback `/home` independently from root. Root rollback loses home data | High — requires subvolume migration | Same as above — flat subvols during reinstall |
| **No `bees` block-level dedup** | Nix store has cross-file block duplication that `auto-optimise-store` (whole-file hardlinks) can't catch | Low — `services.beesd.filesystems` with hashTableSizeMB = 2048 | Optional. Monitor CPU/IO impact. Most beneficial on `/nix/store` |

### Low Priority / By Design

| Gap | Reason | Notes |
|---|---|---|
| No `compress-force=zstd` | Against upstream Btrfs guidelines | Standard `compress` is the correct default. `compress-force` would save 10-20% more but violates Btrfs best practices |
| No impermanence (erase-your-darlings) | SystemNix uses generations, not root-wipe-on-boot | Valid architectural choice. Not a gap — just a different philosophy |
| No snapper | Using btrbk instead | btrbk is more flexible (supports remote backup targets). Correct choice |
| No disk swap | Using zramSwap | Correct for unified-memory APU (128G shared CPU+GPU). Disk swap would compete with GPUActive memory |

---

## SystemNix Innovations Beyond Wiki Guidance

These are things SystemNix does that NO wiki recommends — born from real production crashes:

| Innovation | What It Prevents | Source File |
|---|---|---|
| **BTRFS metadata ENOSPC GC guard** | Nightly `nix-gc` on zero-unallocated filesystem → metadata transaction deadlock → WDT hard reset (2026-06-26 crash) | `btrfs-health.nix` |
| **Chunk allocation Prometheus metrics** | `df` reports data-pool free space, NOT chunk-level allocation. Entire monitoring stack was blind to the allocation exhaustion | `btrfs-health.nix` |
| **Btrbk staggered before GC** | Concurrent btrbk + nix-gc prevents CoW-shared extent reclamation → metadata ratchet | `snapshots.nix` |
| **Snapshot freshness verifier** | Silent btrbk failure leaves stale snapshots with no alert | `snapshots.nix` |
| **Rust `target/` on ext4** | 85K+ small files in `target/` cause severe COW fragmentation on Btrfs | `snapshots.nix` + `hardware-configuration.nix` |
| **Cache subvolume automounts** | `.cache`, `.cargo`, `.npm`, `go/` get their own subvolumes with idle-timeout automount — keeps them out of snapshots and manages CoW fragmentation | `snapshots.nix` |
| **`mkFilesystem` eval-time validator** | `discard=async` on ext4 → `fsconfig() failed` → emergency shell. Catches at `nix flake check` time | `lib/filesystems.nix` |
| **`/tmp` tmpfs via `systemd.mounts`** | Using `fileSystems."/tmp"` generates a runtime fstab entry → `switch-to-configuration` tries to unmount `/tmp` → deploy failure | `boot.nix` |
| **BTRFS build sandbox cleanup** | OOM/hard-reset leaves orphaned build sandboxes in `/nix/var/nix/builds/` (100+ GB) | `scheduled-tasks.nix` |
| **DMS Btrfs health widget** | Desktop-visible chunk allocation % and metadata utilization — operational visibility without SSH | `pkgs/dms-plugins/systemnix-btrfs` |

---

## Summary Scorecard

| Category | Score | Detail |
|---|---|---|
| **Subvolume layout** | 6/10 | `@` works but `/nix` and `/home` should be separate. Cache subvols and ext4 Rust cache are excellent additions |
| **Mount options** | 9/10 | All correct. `discard=async` removal is hardware-specific, not a mistake |
| **Compression** | 10/10 | `compress=zstd` everywhere, correct level, filesystem-wide coverage |
| **Snapshots** | 7/10 | Excellent automation (btrbk + freshness checker + GC staggering). Gaps: no remote backup, snapshots include `/nix` |
| **Scrubbing** | 10/10 | Auto-scrub monthly on both filesystems |
| **Nix store optimization** | 9/10 | `auto-optimise-store` + `optimise.automatic`. Missing optional `bees` |
| **Monitoring** | 10/10 | Goes far beyond any wiki recommendation. Prometheus + Gatus + DMS widget + GC guard |
| **Safety validation** | 10/10 | `mkFilesystem` eval-time guard, pre-deploy checks, `nofail` everywhere |
| **Swap** | 10/10 | zramSwap is the correct choice for this hardware |
| **Overall** | **8.5/10** | Production-hardened beyond wiki guidance. Main gaps are structural (subvolume separation) and backup (no remote target) |

---

## Sources

- [NixOS Wiki — Btrfs](https://wiki.nixos.org/wiki/Btrfs)
- [NixOS Wiki — Btrbk](https://wiki.nixos.org/wiki/Btrbk)
- [NixOS Wiki — Filesystems](https://wiki.nixos.org/wiki/Filesystems)
- [NixOS Wiki — Impermanence / Erase Your Darlings](https://wiki.nixos.org/wiki/Impermanence)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [Btrfs Documentation — Compression](https://btrfs.readthedocs.io/en/latest/Compression.html)
- [Btrfs Documentation — Subvolumes](https://btrfs.readthedocs.io/en/latest/Subvolumes.html)
- [Disko — Btrfs and Subvolumes](https://deepwiki.com/nix-community/disko/3.8-btrfs-and-subvolumes)
- [notashelf — Impermanence Guide](https://www.notashelf.dev/posts/impermanence)
- [Haseeb Majid — Disko + LUKS + Btrfs on NixOS](https://haseebmajid.dev/posts/2024-07-30-how-i-setup-btrfs-and-luks-on-nixos-using-disko/)
- [NixOS Discourse — Optimizing Btrfs on SSDs](https://discourse.nixos.org/t/how-to-optimize-btrfs-on-ssds-checksum-zstandard-compression-discard/77599)
- [NixOS Discourse — Nix store and Btrfs snapshots](https://discourse.nixos.org/t/nix-store-and-btrfs-snapshots/32550)
- [nix PR #4094 — Disable preallocate-contents (fixes btrfs compression)](https://github.com/NixOS/nix/pull/4094)
- [nix issue #3550 — Btrfs compression ignored for substituted paths](https://github.com/NixOS/nix/issues/3550)
- [Forza's Ramblings — Btrfs Mount Options](https://wiki.tnonline.net/w/Btrfs/Mount_Options)
- [impermanence module](https://github.com/nix-community/impermanence)
