# Samsung 970 EVO Plus — Role Assignment from First Principles

_2026-08-31 · decision doc · Rev 2 · status: partition layout + hot-DB subvol RATIFIED in review; remaining open items listed at the bottom (reboot window, phase-ordering confirmation)_

## The question

What MUST be fast all the time (→ Samsung 1 TB TLC, currently blank, internal)? What can
stay on the 2 TB Lexar QLC? Answer from workload physics, not from "the QLC felt slow today".

## Filesystem decision for `/nix` — RESOLVED 2026-08-31: BTRFS + compress=zstd

Measured head-to-head on the actual Samsung (`scripts/bench-nix-fs.sh`, final valid run;
629 real store paths / 1.7 GiB sample; box under live load PSI 26–70%, load 3–6):

| Metric (file-based, on target) | ext4 | XFS (reflink=1) | BTRFS (zstd) |
|---|---|---|---|
| 4K randread QD1 | 18.1k IOPS / 55 µs | 17.0k / 58 µs | 17.9k / 55 µs |
| 4K randwrite QD1 | 65–71k / 14 µs | 35–38k / 27 µs | 38–42k / 25 µs |
| fsync-per-4K-write | ~338 IOPS (≈3 ms) | ~344 (≈2.9 ms) | ~315 (≈3.2 ms) |
| create 20k small files + sync | 7.7–13.7 s | 8.0–9.3 s | 7.6–11.2 s |
| delete 20k files | 0.36–0.66 s | 0.4–1.35 s | 0.6–1.4 s |
| copy real 1.7 G store sample | 4.7 s | 2.2 s | 1.9 s |
| **physical space (compsize)** | 1730 MiB | 1711 MiB | **913 MiB (1.89×)** |

Key findings:
- **Performance is a wash.** Run-to-run variance under load (±40%) exceeded every
  inter-filesystem difference. No fs separates for nix workloads on this hardware.
  (QD32 was CPU-contention-limited to ~19k IOPS in file mode; raw-device QD32 measured
  305k — submission-bound, not device-bound.)
- **Compression is the separator: measured 1.89×** (compsize: 64% of store data
  compresses to 29% of original; 36% correctly skipped by the heuristic). 129 G store
  → ~68 G physical. Halves the Samsung budget.
- Community data agrees: NixOS wiki recommends `compress=zstd,noatime` for /nix; nix
  release manager (vcunat) uses btrfs; nix disabled `preallocate-contents` by default
  specifically so btrfs compression works (PR #4094); danieldk reported 1.88× — matches
  our 1.89× almost exactly. ZFS txg-sync stalls sqlite (5 s) — excluded. f2fs eats open
  files on power loss — excluded. ext4 static inodes: non-issue at 0.7 M files.
- CoW cost is irrelevant for the store body (write-once immutable files); the nix db
  (670 M sqlite, `fsync-metadata = true`) measured equal-fsync across all three.

**Chosen: BTRFS, `noatime,compress=zstd`** (level default 3; NOT `compress-force` — the
heuristic skip of incompressible files is correct). Consistent with root-fs tooling
(btrbk, compsize, scrub doctrine). Hot-DB filesystem superseded later the same day:
they now ride a nodatacow subvol on the single BTRFS pool (see Revision 2 below).

Benchmark tooling: `scripts/bench-disk.sh` (raw device) and `scripts/bench-nix-fs.sh`
(fs comparison) — both guard against mounted devices and self-heal the fio store path.

## First principles

A machine with **128 GB RAM** has three storage tiers. Disk choice only matters where the
upper tiers cannot absorb the access:

| Tier | What it serves | Latency |
|---|---|---|
| RAM / page cache | Warm working sets (hot nix binaries, DB pages, project trees) | ~0 |
| **Samsung TLC** | **Synchronous cold path: exec, fsync, cache-miss refill** | 12–28 µs QD1 |
| QLC + HDD pool | Streaming bulk: models, games, media, telemetry, backups | 0.1–2 GB/s |

**The classifier for every workload: "who waits, synchronously, when this IO happens?"**

- A human keystroke/Enter (shell exec, editor, git status) → latency-critical
- An HTTP request handler (auth check, photo browse, git push) → latency-critical
- A background job that completes whenever (backup, build, model cold-load, telemetry
  ingest) → bandwidth-critical at worst

Second axis: **does the workload poison the tiers above it?** (cache eviction of hot pages,
queue saturation during internal GC). Retry-amplified streaming (flm re-loads after oomd
kills) is the classic poison.

## Measured facts (2026-08-31, all under live load — see AGENTS.md Samsung section)

| Metric | Samsung (raw) | Lexar root (BTRFS) | USB buildcache |
|---|---|---|---|
| 4K randread QD1 | 35,300 IOPS / 27.8 µs | 620 IOPS / 1.6 ms | 461 IOPS / 2.2 ms |
| 4K randwrite QD1 | 79,191 IOPS / 12.2 µs | 295 IOPS / 3.4 ms | 1,263 IOPS |
| 4K randread QD32 | 304,657 IOPS / 1.19 GB/s | 804 IOPS | 1,478 IOPS |
| fsync (per-write) | **0.78 ms** | **~200 ms** | 1.7 ms |
| 1M seq read/write | 2,423 / 2,671 MiB/s | (contended: unusable) | — |
| Link | PCIe 3.0 x4 (= drive max) | PCIe 4.0 x4 | USB 3.0 |
| Endurance budget | 600 TBW | unknown (budget QLC) | irrelevant (cache) |

Live pathology captured same day: device throughput 0.3 MB/s with PSI some=47–64%,
`flm-real` D-state in `blk_mq_get_tag`, `nix` in `folio_wait_bit_common`, btrfs
delayed-metadata kworkers stuck — the QLC in SLC/GC crunch completing nothing while
every exec queues behind it.

## Current occupancy (measured)

| Data | Size | Where today | Who waits on it |
|---|---|---|---|
| `/nix` store | 129 G | QLC root (`@nix` subvol, NOT snapshotted) | **Every process spawn, every shell Enter** |
| Sync DBs: pocket-id, postgres (immich+paperless), forgejo | est. ≤ 50 G (root-only dirs) | QLC `/var/lib` | **Every auth token, photo browse, git push** |
| `/home/lars` | 268 G | QLC `@` (snapshotted → pool) | Interactive dev (git, editors, browsers) |
| Go caches (go-build 65 G + go-mod 13 G + ~18 G aux) | ~96 G | USB SSD | Compile iteration waits (semi-interactive) |
| AI models (`/data/ai` 287 G, `/data/models` 210 G, `/data/llamacpp-models` 92 G) | **589 G** | QLC `/data` | Nobody synchronously — cold-load bandwidth |
| Steam | 106 G | QLC `/data` | Game launch only |
| ClickHouse telemetry | 32 G used / 100 G part (df, measured) | QLC p9 (XFS) | Nobody (analytics) |
| Backups, media, service data | 1.1 T used (df, measured) | HDD pool | Nobody |

Note (measured 2026-08-31): the `/data` category figures above sum to 695 G while df
reports 888 G used on p8; the ~193 G balance is unclassified dirs + snapshot-pinned
extents (`containers`/`cache` measured ~0, `tmp-crush-test` 380 M). The original "29 T"
pool figure and "~70 G" ClickHouse estimate in Rev 1 were wrong.

## The design

**Samsung = the synchronous disk. QLC = the streaming disk. RAM = the hot tier.**

### Samsung layout (931.5 G) — Rev 2, ratified in review

```
p1  EFI    4 G       # ef00, FAT32 label SAMSUNG-EFI, formatted now, UNMOUNTED.
                      # Reserved for a future boot migration (zero-repartition then).
                      # Mirrors the Lexar's own 4 G ESP (p7).
p2  BTRFS  ~927.5 G  # label `tlc`, to end of disk. The ONLY data partition.
                      # noatime, compress=zstd, commit 30 s (default; TLC).
                      # subvols:
                      #   nix    -> /nix            CoW+zstd, ~68 G (129 G raw)
                      #   hot    -> /var/lib/hot    mount -o nodatacow
                      #     /pocket-id /postgres /forgejo
                      #     (nested per-service subvol boundaries, chattr +C per root)
                      #   home   -> /home           (optional, Phase 3)
                      #   caches -> GOCACHE/GOMODCACHE (optional, Phase 4)
```

- **`/nix` (129 G → ~68 G, measured 1.89× zstd)**: the exec path. Every cache miss refills
  at 2.4 GB/s / 27 µs instead of queueing on the QLC. Also removes 129 G from QLC root
  → chunk-unalloc CRITICAL clears → balance/ENOSPC pressure resolves structurally.
- **Hot DBs on a nodatacow subvol (Rev 2, replaces the 64 G XFS p1)**: partition starts
  never move, BTRFS shrinks only from its end, XFS never shrinks. A mid-disk XFS sized
  64 G against ≤50 G of DBs would have been permanently un-growable. The subvol keeps
  full pool elasticity; fsync lands ~1–2 ms vs raw 0.78 ms (XFS would be ~1 ms; noise
  for auth checks and git pushes). Per-service subvol BOUNDARIES live inside ONE `hot`
  mount: surgical snapshots/deletes, zero extra mount units.
- **Future XFS, if ever needed**: carved fresh from p2's tail at the moment of need
  (online `btrfs resize -X` → `parted resizepart` end → `mkfs.xfs`). Never pre-carved.
- **NOT on Samsung**: models (589 G — doesn't fit, doesn't need latency), games, media,
  telemetry, backups, swap (zram covers it).

### QLC keeps — and this is a *role*, not a demotion

- `/data` models + Steam (695 G): big immutable files, read as streams. QLC sequential
  read on an otherwise-quiet disk is 1–3 GB/s — cold-load 10–20 s, exactly what the
  socket-activation TTL model wants. Post-separation the QLC finally GETS the quiet it
  needs for this to be true (the 13 MB/s measured today was co-tenancy + GC, not NAND).
- ClickHouse p9: 180 G/day of async telemetry writes — the endurance sacrificial disk.
- Root `@` remainder: service state, logs, `/home` (Phase-3 decision below), boot.

### Why models stay (the explicit call)

Bandwidth-bound, not latency-bound; zero synchronous waiter; 589 G. Moving 25 G of them
to Samsung would buy ~10 s on cold-load while spending capacity the home/caches phases
need. The REAL model problems are co-tenancy (fixed by this separation) and retry
storms (already mitigated: OOMScoreAdjust + restart backoff + memory-emergency-guard
stops the socket). Cache eviction from a 21.6 G stream stops hurting the shell the
moment exec-path misses refill from TLC at 2.4 GB/s.

### Mount options doctrine

- Samsung BTRFS pool: `noatime,compress=zstd` — **default commit interval** (30 s); the
  `commit=300` doctrine is a QLC/SLC-preservation measure, not needed on TLC.
- `hot` subvol: mount `-o nodatacow` + explicit `chattr +C` per nested subvol root (set
  by the storage-dir oneshot; do not rely on inheritance into fresh subvol roots).
  nodatacow = in-place data writes, no csums, no compression: the XFS-like data path on
  BTRFS CoW metadata (still no journal, crash consistency unchanged). fsync ~1–2 ms.
- Snapshot landmine: nodatacow holds only for extents not shared with a snapshot; one
  scheduled snapshot silently reverts touched extents to CoW. Policy: never schedule
  snapshots of `hot`; one-shot checkpoints around migrations, deleted after; eval-time
  assertion keyed on the `hot` prefix keeps it out of btrbk.
- gatus (if it joins) lives WITHOUT `+C`: tiny write volume, integrity detection beats
  fsync latency.
- qgroups: OFF (per-write metadata tax). TLC exempts this pool from the QLC doctrine,
  so they MAY be enabled later for per-service accounting.
- `nodiscard` + daily fstrim stays (repo doctrine; works for both disks).

## Migration phases (each independently valuable, each gated)

**Phase 0 — prerequisites (no hardware):** deploy the staged balance-fix; fix the
`/data` EIO inode (P0) so nightly btrbk stops walking 86 G into an abort; both reduce
QLC pressure immediately.

**Phase 1 — partitions + `/nix` → Samsung p2 subvol `nix`** (the big one):
1. `sgdisk`: p1 ef00 +4 G, p2 8300 rest. `mkfs.fat -F32 -n SAMSUNG-EFI` p1 (formatted,
   UNMOUNTED, reserved). `mkfs.btrfs -L tlc` p2 + `btrfs subvolume create` `nix`.
2. Initial `rsync -aH --delete` (live; store is mostly idle between builds)
3. Quiesce builds AND `auto-optimise-store` AND nix-gc timers (the optimiser rewrites
   hardlinks on every store add), final delta sync, add `fileSystems."/nix"` (by-label
   `tlc`, `subvol = "nix"`, `neededForBoot = true` — REQUIRED: stage-2 init lives in
   /nix/store; nofail OFF), deploy
4. Delta rsync AGAIN after deploy and BEFORE reboot: the deploy realizes new store
   paths onto the QLC after the sync; skipping this reboots into an incomplete closure
5. Reboot. Verify: `readlink /run/current-system` resolves, nixos-rebuild works, `fio`
   sanity on the new mount, shell-exec latency during a build storm (the acceptance test)
6. Rollback: boot into previous generation + remove fs entry. Old `@nix` subvol deleted
   only after 3-day soak — the delete frees 129 G IMMEDIATELY (sibling subvol, not
   snapshot-pinned since the 2026-08-17 migration; Rev 1's "frees as snapshots expire"
   was stale)

**Phase 2 — hot DBs → `hot` subvol, nodatacow (Rev 2: replaces the XFS p1 plan)** (per
service, one at a time): a mount-gated oneshot creates `hot` plus nested per-service
subvol boundaries (pocket-id, postgres, forgejo) and sets `chattr +C` per subvol root;
mount `/var/lib/hot` with `-o nodatacow`. Then per service: stop, rsync dataDir,
re-point, restart, gatus green; dump-style backups (already location-agnostic —
pocket-id-backup, forgejo dump, pg dumps) land on pool as before. **No btrbk/backup
topology change.** Checkpoints are ONE-SHOT btrfs snapshots, deleted after the
migration (scheduled snapshots would silently revert touched extents to CoW); an
eval-time assertion keyed on the `hot` prefix enforces the policy. Candidates by the
same classifier: dnsblockd (hottest write DB on root), papdashboard; gatus joins
WITHOUT `+C` (integrity over latency for a monitoring store). RPO note: these DBs
leave btrbk snapshot coverage, so nightly dumps become the sole recovery path;
postgres WAL archiving is a sensible Phase 2.5.

**Phase 3 — `/home` decision (268 G):** stays on QLC by default. Trigger to move: if
post-Phase-1/2 the QLC still feels slow for `git status`/editor opens during IO storms.
Fits on Samsung (~464 G cumulative of 927.5 G with everything else). `btrfs subvolume
create home`, no partition work. Cost: btrbk root-snapshot scope change + HM symlink
re-point + one offline window.

**Phase 4 — Go caches → Samsung p2 subvol `caches`** (optional): move
`GOCACHE`+`GOMODCACHE` only (~78 G); leave rust/pnpm/playwright on USB (cold, big).
Iteration latency for compiles goes 2.2 ms → 27 µs per cache-hit read. `btrfs subvolume
create caches`, no partition work.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Boot now requires Samsung | `nofail` OFF (must mount), `neededForBoot = true` explicit, rescue documented; store rebuildable from flake.lock + attic + upstreams; QLC boot partition untouched |
| Samsung failure loses `/nix` + hot DBs | `/nix` rebuildable; DBs have nightly dump backups on pool (14d/7d); reserved p1 is empty until boot-migration day, so the QLC boot path is unaffected by it |
| Partition geometry mistakes are unfixable in place | Starts never move: ESP carved day one (4 G), ONE BTRFS pool takes the rest, future XFS only ever carved fresh from p2's tail via online shrink |
| Snapshot landmine re-enables CoW on `hot` | No scheduled snapshots; one-shot checkpoints deleted after use; eval-time assertion keyed on the `hot` prefix (never in btrbk) |
| Endurance (600 TBW) | Projected ~100–250 G/day worst case → 6–16 years; monitored via the (fixed) by-id smartd/nvme-monitor |
| Migration writes stress the wedged QLC | Phase 0 first; deploy pressure gate; `--keep-going`; ionice the rsync |
| Parallel-session tree races | Run migrations from a quiesced tree; auto-commit daemon aware |

## Open decisions for the user

1. ~~Ratify layout~~ RESOLVED in review (Rev 2): 4 G ESP + single BTRFS pool `tlc` +
   nodatacow `hot` subvol. Supersedes BOTH Rev 1 options (the 64 G XFS p1, and
   "single-BTRFS-with-noCoW-dirs" as then framed: the pool is indeed single-BTRFS, but
   noCoW is a subvol mount with per-service boundaries, not plain directories)
2. Phase ordering (proposed: 0→1→2, then decide 3/4 from data)
3. Reboot window for Phase 1
4. Optional, decide at Phase 2: enable qgroups on the Samsung pool for per-service
   accounting (TLC exempts it from the QLC doctrine; the removed
   `btrfs_qgroup_referenced_bytes` collector is in git history for re-adding)
