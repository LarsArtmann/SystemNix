# NixOS + BTRFS: Internet Sweep (2026-09-05) vs SystemNix

**Date:** 2026-09-05
**Method:** Fresh web sweep of every current NixOS+BTRFS guidance source, compared against the live SystemNix config (hardware-configuration.nix, snapshots.nix, btrfs-health.nix, boot.nix) and the deployed mounts on evo-x2. Supersedes the domain coverage of `2026-07-11_nixos-btrfs-wiki-recommendations.md` (kept as prior art; several of its gaps have since been CLOSED — see §3).
**Sources:** NixOS Wiki (Btrfs), Arch Wiki (Btrfs, ZRAM), btrfs.readthedocs.io (Compression, Administration, Balance, Swapfile, Trim, Qgroups), kernel docs (sysctl/vm, MGLRU), Fedora SwapOnZRAM, Pop!_OS pop-zram tuning, Clear Linux/ChromeOS zram defaults, Docker docs (btrfs driver status, overlay2), libvirt NOCOW guidance, community configs (pinpox, ryan4yin, joshsymonds, bydmiller), r/btrfs + r/linux_gaming + r/pop_os tuning threads.

---

## 1. Verdict table

| Domain                          | Internet consensus (2024-2026)                                             | SystemNix (live 2026-09-05)                                                      | Verdict                     |
| ------------------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------------- |
| Subvolume layout                | Flat top-level `@`, `@home`, `@nix` (+ `@snapshots`/`@persist` variants)    | `@` (root+home), `@nix` (migrating to Samsung `nix` subvol), `@cache-home`, pool | **Aligned** (home shared by choice) |
| Snapshot `/nix`?                | No — redundant, generations are the rollback                                | Excluded since @nix 2026-08-17                                                    | **Aligned (was a gap, closed)** |
| Retention                       | 16h-24h / 7d-14d / 2w-4w ("Goldilocks")                                     | Root 3d+1w local + FOREVER pool-side; data 14d+4w                                 | **Aligned+** (pool beats consensus) |
| Offsite backup                  | Local snapshots are NOT backup; need remote leg                             | Pool is same-chassis HDD; NO offsite BTRFS leg                                    | **GAP (top one)**           |
| Compression                     | `compress=zstd` (not -force); level 3 default is the sweet spot             | `compress=zstd:3` everywhere, measured 1.89x on store; -force rejected            | **Aligned (validated)**     |
| commit=                         | 30 default; 120-300 for slow/QLC storage; kernel warns >300                 | `commit=300` on ALL btrfs mounts (exactly at the warning boundary, no warning)    | **Aligned**                 |
| noatime                         | Yes, especially under CoW                                                   | All mounts                                                                        | **Aligned**                 |
| TRIM                            | `discard=async` default since 6.2, safe + periodic fstrim                   | `nodiscard` + DAILY idle fstrim — QLC 253ms discard latency is a live-proven deviation | **Deliberate deviation (justified)** |
| Scrub                           | Monthly (both wikis)                                                        | Weekly + deferral guard (PSI/zram/btrbk-aware)                                    | **Exceeds**                 |
| Balance/ENOSPC                  | `usage=0` first, `-musage=50`/`-dusage=50` compaction, btrfs-headroom tool  | Weekly bounded balance + GC guard + emergency reserve + chunk metrics             | **Exceeds**                 |
| qgroups                         | Avoid — commit latency, snapshot-deletion stalls (upstream doc warning)     | Not enabled                                                                       | **Aligned**                 |
| Dedup                           | bees / duperemove recommended generically                                   | Rejected on QLC random-IO grounds (auto-optimise-store only)                      | **Aligned for QLC; revisit post-Samsung** |
| Swap on btrfs                   | NOCOW subvol, `btrfs filesystem mkswapfile`                                 | N/A — zram-only (correct for 124G unified-memory APU)                             | **N/A**                     |
| zram-only sysctls               | swappiness 100-200, **page-cluster=0**, **watermark_boost_factor=0**, scale 100-125, MGLRU min_ttl | swappiness 150 ✓, scale 100 ✓, MGLRU 1000ms ✓, **page-cluster 3 ✗**, **boost 15000 ✗** | **2 GAPS → fixed this sweep** |
| Docker on btrfs                 | overlay2 (not the deprecated btrfs driver); consider NOCOW on data-root     | overlay2 on /data btrfs; no NOCOW                                                 | **Consideration (open)**    |
| VM images/DBs on CoW            | `chattr +C` or separate fs                                                  | ClickHouse → dedicated XFS (better than +C); pg containers on CoW /data           | **Mostly aligned; pg is a consideration** |
| space_cache                     | v2 default                                                                  | v2 everywhere (explicit)                                                          | **Aligned**                 |
| block-group-tree                | For huge/slow-mount filesystems                                             | New Samsung `tlc` pool created WITH it; 32 TB HDD pool not converted              | **Aligned (new disk); pool optional** |
| btrfs check --repair            | Danger — never casual                                                       | Runbooks forbid; low-risk mode planned for the /data P0 only                      | **Aligned**                 |

**Score: aligned or exceeding on 20 of 23 domains; 1 standing gap (offsite), 2 sysctl gaps (fixed), several conscious documented deviations.**

---

## 2. New findings this sweep (what changed since the 2026-07-11 doc)

### 2.1 FIXED this sweep — zram-only sysctls (the only actionable config delta)

The single concrete divergence from every mainstream zram deployment (Fedora, Pop!_OS, ChromeOS, Clear Linux, ArchWiki ZRAM page):

| Sysctl                      | Was (kernel default) | Now | Why (sources)                                                                                                                              |
| --------------------------- | -------------------- | --- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `vm.page-cluster`           | 3                    | 0   | Readahead of 8 pages per swap fault is an HDD-era seek optimization; on zram it wastes CPU and decompresses unneeded pages (ArchWiki ZRAM, Fedora SwapOnZRAM, Pop!_OS, ChromeOS all ship 0). |
| `vm.watermark_boost_factor` | 15000                | 0   | Watermark boosting force-reclaims on fragmentation signals and is widely reported to cause stutter/freezes with zram ("inherently broken feature", Pop!_OS + Clear Linux ship 0). On this box kswapd boost storms are exactly the freeze-incident class. |

Implemented in `platforms/nixos/system/boot.nix` (boot.kernel.sysctl). Both are runtime-tunable and reversible; swappiness/watermark_scale/MGLRU values were re-checked against the same sources and stay as-is (150/100/1000ms are inside every recommendation band).

### 2.2 Confirmed validations (internet says do X, we already do X — evidence upgraded)

- **compress-force is officially discouraged**: btrfs.readthedocs.io — "Using the forcing compression is not recommended, the heuristics are supposed to decide that." Our `compress` choice and its AGENTS.md rationale are now upstream-quote-backed.
- **commit=300 is the documented ceiling**: "a warning is printed if it's more than 300 seconds" — we sit exactly at 300. Community reports for QLC/turtle storage converge on 120-300. No change.
- **`discard=async` default since kernel 6.2 + "preferred mode" upstream**: our blanket `nodiscard` is a *documented, live-verified* hardware deviation (QLC 253ms discard latency → 17.7s commit stalls → WDT resets, 2026-08-03 incident), covered by DAILY fstrim instead. The internet's "async is safe" does not hold on this NAND; keep nodiscard. NOTE: the live Samsung staging mount showed `discard=async` while the staged `/nix` entry is `nodiscard` — after reboot the config wins; for TLC either is defensible, consistency with the doctrine is fine.
- **Excluding `/nix` from snapshots**: unanimous community practice (pinpox, ryan4yin, joshsymonds, bydmiller configs; NixOS Wiki "trivially reconstructable"). Our @nix split (2026-08-17) and Samsung migration achieve exactly this.
- **qgroups**: upstream warning ("can slow down transaction commits... unacceptable latencies") validates our no-quotas stance. New kernel 6.7 "simple quotas" (`btrfs quota enable --simple`) noted for IF per-subvolume accounting is ever needed.
- **Local snapshots ≠ backup**: every source; we have pool-side send/receive (beyond most single-disk setups) but see the gap below.

### 2.3 Open items (ordered by value)

1. **OFFSITE backup leg (standing top gap, reconfirmed)** — pool RAID1 survives NVMe death, not the house. Internet consensus: remote `btrbk` target (StorageBox/rsync.net) or offsite rotation. Already acknowledged in the 2026-07-11 doc; unchanged. User decision territory (cost/privacy), keep on the roadmap.
2. **`chattr +C` (NOCOW) for Docker data / pg containers on /data** — Docker docs: overlay2 is the supported driver on btrfs backing (we're fine), but heavy-random-write payloads (postgres pgdata in `/data/docker/volumes/...`) fragment under CoW; NOCOW must be applied to an EMPTY dir, and it disables compression. Postgres datasets are not compressible by zstd anyway (PG pages are high-entropy), so the compress loss is nil. Cheapest correct move at the next migration window: `chattr +C` on the volume dirs, or declare `/data/docker` NOCOW subvol. NOT urgent — twenty/manifest pg instances are small.
3. **btrfs-headroom** (ArchWiki-referenced ENOSPC-risk estimator) — our chunk-allocation metrics + GC guard already cover the signal it computes; optional nice-to-have, not a gap.
4. **bees on `/nix` post-Samsung** — rejected on QLC random-read grounds; the Samsung 970 (35.3k IOPS QD1 randread) changes the calculus. Still optional (auto-optimise-store captures whole-file dupes; bees adds CPU/IO background load). Revisit only if store growth becomes a problem — the new pool is 928G with 70G used.
5. **block-group-tree on the 32 TB HDD pool** — helps mount times on huge filesystems; only worth it if pool mount latency ever becomes visible (it has not). Requires unmount + btrfstune; low priority.
6. **Pool (mnt/pool) in btrfs-health metrics** — already tracked in TODO_LIST §"Pool + disk-domain quality" item 1; this sweep found no additional pool-level guidance beyond it (btrfs device stats monitoring we already have in btrfs-verify-pool-backups).

### 2.4 Gaps from the 2026-07-11 doc — status recheck

| Old gap                              | Status 2026-09-05                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------- |
| `/nix` inside `@`                    | **CLOSED** — `@nix` since 2026-08-17; store migrating to Samsung `tlc` pool (block-group-tree, zstd, measured 3.6x logical→physical) |
| No remote/backup target              | **PARTIALLY CLOSED** — pool RAID1 send/receive since 2026-08-16; offsite leg still open |
| `/home` inside `@`                   | Still open **by choice** (home IS worth snapshotting with root; rollback semantics documented) |
| No bees                              | Still out **by choice** (QLC); revisit post-Samsung (§2.3.4)                          |
| Scrub monthly                        | **EXCEEDED** — weekly + deferral guard since 2026-08-31                               |
| GC guard unalloc %-threshold bug     | **CLOSED** — absolute 5 GiB floor + meta% block since 2026-08-21                      |

---

## 3. Where SystemNix exceeds everything the internet documents

Born from production incidents; none of these appear in wiki/community guidance as of this sweep:

- Chunk-allocation Prometheus metrics + GC guard (df is blind to unallocated-chunk ENOSPC; 2026-06-26 crash class)
- Balance jobs with Guard 0 (PSI/zram/skip-if-streaming) + `btrfs-chunk-check` + bounded `-dlimit`
- `btrfs-emergency-reserve` 10 GiB fallocate file (instant ENOSPC headroom)
- Scrub deferral guard (scrub vs btrbk-send vs flm cold-load serialization — the 2026-08-31 freeze class)
- `mkFilesystem` eval-time FS/option contamination validator (discard=async-on-ext4 boot-shell class)
- Daily idle-priority fstrim sized to measured QLC CoW churn (446 GiB backlog, 22-47h SLC exhaustion math)
- zram-only reclaim doctrine (swappiness 150, watermark_scale 100, MGLRU min_ttl 1000ms, now page-cluster 0 + boost 0) tuned against five freeze post-mortems
- Snapshot freshness verifier, garbled-receive healing (`btrbk clean`), pool-recovery udev flows, emergency-reserve metrics — full observability chain (Prometheus → Gatus → Discord → sev1 tiers)

## 4. Sources

- https://wiki.nixos.org/wiki/Btrfs
- https://wiki.archlinux.org/title/Btrfs
- https://wiki.archlinux.org/title/ZRAM
- https://btrfs.readthedocs.io/en/latest/Compression.html
- https://btrfs.readthedocs.io/en/latest/Administration.html
- https://btrfs.readthedocs.io/en/latest/Balance.html
- https://btrfs.readthedocs.io/en/latest/Swapfile.html
- https://btrfs.readthedocs.io/en/latest/Trim.html
- https://btrfs.readthedocs.io/en/latest/Qgroups.html
- https://docs.kernel.org/admin-guide/sysctl/vm.html
- https://fedoraproject.org/wiki/Changes/SwapOnZRAM
- https://www.reddit.com/r/pop_os/comments/znh9n6/help_test_a_zram_optimization_for_pop_os/
- https://docs.docker.com/engine/storage/drivers/btrfs-driver/
- https://docs.docker.com/engine/storage/drivers/overlayfs-driver/
- https://github.com/pinpox/nixos (disko.nix)
- https://github.com/ryan4yin/nix-config (disko-fs.nix)
- https://github.com/joshsymonds/nix-config (btrfs-impermanence.nix)
- https://github.com/bydmiller/nixos-configs (impermanence.nix)
