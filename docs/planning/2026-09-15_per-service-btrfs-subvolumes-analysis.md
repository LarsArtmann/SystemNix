# Per-Service BTRFS Subvolumes — Decision Analysis

**Date:** 2026-09-15 · **Status:** ANALYSIS — no immediate action; decision framework for service onboarding and the Samsung Phase-2 waves
**Scope:** Whether (and when) each service's state on evo-x2 should live in its own BTRFS subvolume instead of plain directories under a snapshotted parent. Covers QLC root `@`, `/data`, Samsung `tlc`, and the HDD pool.
**Sources:** This repo's BTRFS doctrine (AGENTS.md BTRFS section) · `docs/research/2026-09-05_btrfs-internet-sweep-vs-systemnix.md` (qgroup/nodatacow/CoW consensus rows) · `docs/planning/2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md` (ratified Rev-2 `nodatacow` hot tier — this doc's "Set C" already half-decided) · incident history: engine-switch bootstrap trap, google-sync/cv-backup/atticd 226 class, btrbk "exists, but is not a receive target", 2026-09-12 glob-delete incident, five completed per-service relocations.

---

## 1. The question

Today most service state lives as plain directories under snapshotted trees:

| Tree                         | Snapshot regime                                       | Service state living there                                               |
| ---------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------ |
| `@` (QLC root, `/var/lib/*`) | btrbk daily 23:00, 3d+1w local, **FOREVER pool-side** | CV, gatus, pocket-id, discordsync, browser-history, crush session DBs, … |
| `/data` (QLC toplevel)       | daily 23:30, 14d+4w + pool                            | docker data-root, AI models, Steam                                       |
| Samsung `tlc` (`/n`)         | none (rebuildable)                                    | nix store                                                                |
| HDD pool `services/*`        | btrbk-pool 23:45 per subvol                           | immich, paperless, atticd, monitor365, …                                 |

The pool already runs the per-service-subvolume model successfully. The question is whether to generalize it — in particular onto the QLC root, where state currently rides `@` snapshots implicitly.

## 2. Mechanics that decide everything

Six facts of BTRFS carry the whole analysis. Everything else is consequences.

1. **Snapshots can only be taken of subvolumes.** A plain directory cannot be snapshotted. Want _any_ per-service snapshot? The state must be a subvol first.
2. **Nested subvols are EXCLUDED from parent snapshots.** This is dual-use: it is the silent-coverage-loss trap (a service dropped from `@` backups with zero error) AND the only mechanism to deliberately exclude a path from `@` (see fact 4).
3. **Nested subvols need no fstab entry.** They are visible through the parent mount at their path. Separate `fileSystems` entries are only needed for distinct VFS options (noatime etc.) — the mount/226 incident surface applies only to the separately-mounted flavor, not the nested one.
4. **`nodatacow` is defeated by snapshots.** A reflink (snapshot) forces CoW on writes to `+C` files to preserve the snapshot. A `chattr +C` DB under the daily-snapshotted `@` silently reverts to CoW after the first snapshot. `+C` only _sticks_ in a subvol that is never snapshotted.
5. **Compression is filesystem-wide; subvols are not mount options and not boundaries.** No per-service `compress=zstd` tuning, no security/DAC isolation (systemd namespaces own that), no space enforcement (qgroups deliberately disabled on QLC — observation via `compsite`/`btrfs fi du` still works, enforcement does not).
6. **One snapshot = one atomic instant for everything under it.** A single `@` snapshot captures all service state at one moment. Independent per-subvol snapshots are staggered instants — cross-service consistency is lost (rarely matters; see §5 shared-infra boundary).

## 3. PRO

- **Retention independence**: 14d of CV pipeline history but 3d of volatile caches, instead of one root policy. _(Counterpoint in §6: the common retention motive is already servable at the dump layer.)_
- **Atomic whole-service rollback**: restore one service's entire state to an instant — paired with a nix generation rollback ("restore CV's state to what its deployed config expects"). Today that requires rolling ALL services back via `@`.
- **nodatacow actually works** (fact 4): an unsnapshotted nested subvol is the only place `+C` is effective — a direct write-amplification lever for hot SQLite on QLC that root snapshots currently block. **This is the ratified Samsung Phase-2 design** (`hot` subvol, `chattr +C`).
- **Native migration unit**: `btrfs send | receive` a service's data + atomic swap. The repo's own track record is the evidence — five per-service relocations to date, each rsync + self-neutralizing migration-unit surgery:
  | Relocation                     | Year        | Mechanism used                              |
  | ------------------------------ | ----------- | ------------------------------------------- |
  | `/nix` → Samsung `tlc`         | 2026-08/09  | reflink rsync + `migrate-nix-subvol.sh`     |
  | ClickHouse → XFS p9            | 2026-08-22  | quiesce-rsync script + shadow cleanup       |
  | docker data-root → `/data`     | pre-2026-08 | manual                                      |
  | activitywatch → pool           | 2026-08-18  | `activitywatch-data-to-pool` migration unit |
  | crush session DBs → `/mnt/hot` | 2026-09-15  | `crush-hot-db-migrate` (interim, symlink)   |
- **Flexible sizing**: subvols have no size at all. The XFS p9 partition is fixed forever ("XFS cannot shrink") — a trap the subvol approach structurally avoids.
- **Pool retention economics**: root receives are kept FOREVER pool-side (`target_preserve_min = "all"`), pinning every extent ever written to `@`. Per-service sends would let volatile services expire instead of pinning indefinitely.
- **Targeted surgery**: delete/recreate one wedged service's state (discordsync resync class) without entangling other services' snapshots; defrag/scrub-adjacent maintenance scoped per service.

## 4. CONTRA

- **The exclusion trap cuts both ways, silently** (fact 2): moving `/var/lib/cv` into a nested subvol drops it from every existing `@` snapshot with no error. Same mechanism in the disaster-recovery direction: a root-snapshot restore silently stops restoring that service's state. Both the backup gap and the rollback semantic change are invisible until needed.
- **Selective restore is already possible today**: mount an `@` snapshot read-only, rsync one service's dir back. The "independent restore" pro is therefore weaker than it looks — the genuinely new capabilities are only retention independence and atomic whole-service rollback.
- **CoW DBs + snapshots = write amplification** — the exact reason ClickHouse went to XFS. A busy SQLite under daily snapshots writes new extents pinned until retention expires; on QLC this is the SLC-exhaustion class. Snapshotted per-service subvols for hot DBs would be the anti-pattern; the correct treatment for hot DBs is Set C (no snapshots, `+C`, dump-only), i.e. placement — which Samsung Phase 2 already owns.
- **btrbk config and failure surface scale with subvol count**: per-subvol snapshot+send+retention entries, more "exists, but is not a receive target" garbled-receive blocks (healed only by `btrbk-pool-clean`), more rescue-tier/canary paths to protect after the 2026-09-12 glob-delete incident.
- **No enforcement**: qgroups stay disabled (deliberate, QLC IO tax) — subvols observe but cannot bound a runaway service.
- **Dumps already exist and are transaction-consistent**: `sqlite3 .backup`, `pg_dump`, `forgejo dump` are cleaner restores than crash-consistent snapshots of live DBs (SQLite WAL replay from a crash-consistent copy is safe in practice, but dumps remain the primary path).
- **Separately-mounted flavor multiplies the 226/mount-gating surface**: every fstab entry adds `nofail` + `RequiresMountsFor`/`ConditionPathIsMountPoint` + ReadWritePaths wiring (google-sync-dirs, cv-backup-dir, atticd-storage-dir were all this class). Nested flavor avoids this entirely — but then inherits parent mount options.
- **It polishes the wrong layer on the QLC root**: the actual pain is _placement_ (hot DBs on TLC, bulk state on pool). Partitioning `@` into subvols does not move a single IO off the QLC die.

## 5. Boundary constraints

- **Shared infrastructure cannot be split per-service.** One PostgreSQL cluster serves immich, paperless, miniflux, twenty, manifest — per-service subvols cannot give each app its own DB instance; the cluster moves (or stays) as a unit.
- **Cross-service atomicity** (fact 6): only matters where state must be consistent _across_ services at one instant; nothing in the current inventory demands it, but the property is lost silently if state is split into staggered snapshot sets.

## 6. The reframe: three snapshot sets, chosen per service

The decision is not "subvol per service: yes/no" — it is **which snapshot set each service's state belongs to**:

| Set                                               | Shape                                                                | Snapshot regime                               | Backup                                                                                       | For                                                                                                     |
| ------------------------------------------------- | -------------------------------------------------------------------- | --------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **A — stay in `@`**                               | plain dir under snapshotted parent                                   | rides `@` daily snapshots (crash-consistent)  | dumps as today                                                                               | DEFAULT: small, cold, crash-tolerant state (gatus config-ish, small state dirs)                         |
| **B — own subvol + own btrbk entry**              | nested or separately-mounted subvol                                  | own btrbk snapshot/send config, own retention | dumps stay                                                                                   | Long-retention state (CV pipeline), known migration ahead, services wanting atomic whole-state rollback |
| **C — own subvol, NO snapshots, `+C`, dump-only** | nested subvol, `chattr +C`, mounted at dataDir (Phase-2 Rev-3 shape) | none — that is the point (`+C` sticks)        | dumps via backup-coordination become the ONLY path — freshness alerting is then load-bearing | Hot SQLite on QLC/TLC boundary: crush DBs, pocket-id, gatus DB, discordsync                             |

Rules that fall out:

1. **Membership must be declared and enforced.** The exclusion trap (fact 2) is only safe if "which set is this service in" is machine-checked. Doctrine: an eval-time guard asserting every `/var/lib` nested subvol declares exactly one set (A dirs are invisible to it by construction; B entries must appear in a btrbk config; C entries must appear in the no-snapshot allowlist with a dump registered in backup-coordination). Samsung Phase 2 already plans "eval-time assertions (btrbk exclusion)" — generalize it repo-wide when that lands.
2. **Set C forfeits snapshots by design** — its dump cadence IS the RPO. Register in backup-coordination with `maxAgeHours` tighter than the dump timer interval; Gatus freshness becomes the only gap detector.
3. **Default is A.** Blanket per-service subvols on the QLC root are a net negative: they add btrbk surface and exclusion traps while solving nothing the Samsung/pool placement doesn't already solve. Adopt B/C selectively, driven by the triggers below.

## 7. Decision triggers (when to leave set A)

| Trigger                                                                     | Move to                                             | Rationale                                               |
| --------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------- |
| Sustained fsync-bound writes on QLC root (crush-class IO storm evidence)    | **C** on Samsung `hot`                              | the ratified Phase-2 criterion                          |
| Retention need > root's 3d+1w AND dump size/cost makes dumps alone too slow | **B**                                               | retention independence                                  |
| Migration planned within N weeks (disk reshuffles keep happening)           | **B**                                               | `btrfs send \| receive` beats rsync surgery             |
| State is a hot DB but must stay on QLC (no TLC budget)                      | **C in place** (unsnapshotted nested subvol + `+C`) | fact 4 — `+C` finally sticks; accept QLC endurance cost |
| Service wants deploy-paired state rollback                                  | **B**                                               | atomic whole-service rollback                           |
| Everything else                                                             | **A**                                               | zero new surface                                        |

## 8. Verdict

- **Do not blanket-adopt per-service subvols on the QLC root.** The QLC pain is placement; Samsung Phase 2 and the pool already own the placement fixes.
- **The pool's `services/*` pattern is Set B proven** — keep it, extend per new pool service.
- **Samsung Phase 2's `hot` tier is Set C realized** — proceed as planned; this analysis adds only the repo-wide framing (set taxonomy + the eval-time membership guard + "dumps are the RPO" alerting rule).
- **When the guard lands**, the exclusion trap converts from a silent gap into a `nix flake check` failure — the SystemNix prevention-layer doctrine applied to snapshot topology.
