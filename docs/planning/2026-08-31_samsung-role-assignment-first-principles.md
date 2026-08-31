# Samsung 970 EVO Plus — Role Assignment from First Principles

_2026-08-31 · decision doc · status: PROPOSED (awaiting user ratification of layout + reboot window)_

## The question

What MUST be fast all the time (→ Samsung 1 TB TLC, currently blank, internal)? What can
stay on the 2 TB Lexar QLC? Answer from workload physics, not from "the QLC felt slow today".

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
| ClickHouse telemetry | ~70 G used / 100 G part | QLC p9 (XFS) | Nobody (analytics) |
| Backups, media, service data | 29 T | HDD pool | Nobody |

## The design

**Samsung = the synchronous disk. QLC = the streaming disk. RAM = the hot tier.**

### Samsung layout (931.5 G)

```
p1  XFS   64 G   /var/lib-hot    # sync DBs (pocket-id, postgres, forgejo) — no CoW, fsync 0.78 ms
p2  BTRFS ~860 G /               # subvol `nix` → mounted at /nix
                              # compress=zstd, noatime
```

- **`/nix` (129 G → ~80–90 G zstd-compressed)**: the exec path. Every cache miss refills
  at 2.4 GB/s / 27 µs instead of queueing on the QLC. Also removes 129 G from QLC root
  → chunk-unalloc CRITICAL clears → balance/ENOSPC pressure resolves structurally.
- **Hot DBs on XFS**: the fsync-bound crowd with humans on the request path. Follows the
  clickhouse-XFS precedent. Sized generously (they're tens of GB today) — 64 G leaves
  years of headroom.
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

- Samsung BTRFS: `noatime,compress=zstd` — **default commit interval** (30 s); the
  `commit=300` doctrine is a QLC/SLC-preservation measure, not needed on TLC.
- Samsung XFS: `noatime`.
- `nodiscard` + daily fstrim stays (repo doctrine; works for both disks).

## Migration phases (each independently valuable, each gated)

**Phase 0 — prerequisites (no hardware):** deploy the staged balance-fix; fix the
`/data` EIO inode (P0) so nightly btrbk stops walking 86 G into an abort; both reduce
QLC pressure immediately.

**Phase 1 — `/nix` → Samsung p2** (the big one):
1. Partition + mkfs + initial `rsync -aH --delete` (live; store is mostly idle between builds)
2. Quiesce builds, final sync, add `fileSystems."/nix"` (by-label `nix`,
   `neededForBoot = true` — verify NixOS default at implementation), deploy, reboot
3. Verify: `readlink /run/current-system` resolves, nixos-rebuild works, `fio` sanity on
   the new mount, shell-exec latency during a build storm (the acceptance test)
4. Rollback: boot into previous generation + remove fs entry. Old `@nix` subvol deleted
   only after 3-day soak (space frees as root snapshots expire; balances then run clean)

**Phase 2 — hot DBs → Samsung p1** (per service, one at a time):
pocket-id → postgres → forgejo. Each: stop, rsync dataDir, set dataDir/bind-mount,
restart, gatus green, dump-style backups (already location-agnostic — pocket-id-backup,
forgejo dump, pg dumps) land on pool as before. **No btrbk/backup topology change** —
that was the constraint that made pool-mounted DBs attractive in 2026-08; dump backups
make the XFS move free of it.

**Phase 3 — `/home` decision (268 G):** stays on QLC by default. Trigger to move: if
post-Phase-1/2 the QLC still feels slow for `git status`/editor opens during IO storms.
Fits on Samsung (525 G total with everything else). Cost: btrbk root-snapshot scope
change + HM symlink re-point + one offline window.

**Phase 4 — Go caches → Samsung p2** (optional): move `GOCACHE`+`GOMODCACHE` only
(~78 G); leave rust/pnpm/playwright on USB (cold, big). Iteration latency for compiles
goes 2.2 ms → 27 µs per cache-hit read.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Boot now requires Samsung | `nofail` OFF (must mount), rescue documented; store rebuildable from flake.lock + attic + upstreams; QLC boot partition untouched |
| Samsung failure loses `/nix` + hot DBs | `/nix` rebuildable; DBs have nightly dump backups on pool (14d/7d) |
| Endurance (600 TBW) | Projected ~100–250 G/day worst case → 6–16 years; monitored via the (fixed) by-id smartd/nvme-monitor |
| Migration writes stress the wedged QLC | Phase 0 first; deploy pressure gate; `--keep-going`; ionice the rsync |
| Parallel-session tree races | Run migrations from a quiesced tree; auto-commit daemon aware |

## Open decisions for the user

1. Ratify layout: 64 G XFS + 860 G BTRFS (vs. single-BTRFS-with-noCoW-dirs)
2. Phase ordering (proposed: 0→1→2, then decide 3/4 from data)
3. Reboot window for Phase 1
