# Phase 2 Hot-DB Tier — fsync-Pain Measurement + Landmine Unblock (Task Queue)

**Date:** 2026-09-21 00:25 · **Task:** TODO_LIST storage "Phase 2: hot DBs off the QLC root" (`Task-Queue-ID: 000001a0c0d6f2c2d0f99808873c3e3fddf0`) · **Plan:** `docs/planning/2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md` (waves T9-T13) · **Mechanism (already landed 2026-09-20, dormant):** `modules/nixos/services/hot-db.nix` + `scripts/migrate-hot-db.sh` + `tests/test-hot-db.nix`

## a. What ran

New `scripts/fsync-bench.sh` (unprivileged by design — agent sessions have no sudo): SQLite/PG WAL-commit shape (4 KiB append + fsync per op, 300 samples idle / 150 loaded), `--nodatacow` simulates the hot-tier subvol flag on a user-owned scratch file, `--load` adds two bounded direct-write dd streams on the SAME filesystem (the snapshot-send/build-storm class). It never touches real DBs; scratch files are trapped-cleaned.

**Conditions disclosure:** the run rode the nightly maintenance window (nix-gc on the Samsung store + fstrim + backup timers): ambient IO PSI some avg10 57-66% the whole time, memory PSI ~6%. Device identification (enumeration flips on this box): `nvme0n1` = Lexar NQ790 2TB QLC (root `@`, where all five candidate DBs except bank-sync sit), `nvme1n1` = Samsung 970 EVO Plus (the `tlc` hot tier). The window's churn hits BOTH devices (fstrim sweeps every fs; nix-gc hammers the Samsung store itself), so the Samsung rows are conservatively polluted, not flattered. Absolute numbers are window-labeled; the verdicts below ride the 9-13x relative gaps, which no realistic correction flips.

## b. The matrix

| # | Filesystem (dir) | mode | load | mean | p50 | p90 | p99 | max | fsync/s | ambient PSI |
|---|------------------|------|------|------|-----|-----|-----|-----|---------|-------------|
| 1 | QLC root `@` (/var/tmp) | cow | - | 26.8 ms | 13.1 | 74.2 | 242.9 | 417.2 | 37 | ~62 |
| 2 | QLC root `@` | nodatacow | - | 25.2 ms | 13.9 | 65.1 | 169.8 | 214.9 | 40 | ~62 |
| 3 | Samsung `tlc` (/mnt/hot/crush) | cow | - | **2.92 ms** | 2.89 | 3.01 | **3.94** | 12.1 | 342 | ~57 |
| 4 | Samsung `tlc` | nodatacow | - | 3.25 ms | 2.88 | 2.99 | 11.0 | 58.6 | 308 | ~57 |
| 5 | QLC root `@` | cow | dd×2 | 66.3 ms | 10.1 | 182.1 | **799.5** | 954.2 | 15 | ~61 |
| 6 | Samsung `tlc` | nodatacow | dd×2 | 5.84 ms | 2.78 | 4.88 | 62.7 | 75.2 | 171 | ~61 |

Storm-sensitivity datapoint: during the window's heavier phase (PSI 66-69%) a short QLC probe measured mean 75.5 ms / p90 214 ms — the QLC penalty is storm-amplified, exactly the discordsync `database is locked` era's substrate.

## c. Findings

1. **The hot tier's case is proven, not vibes:** 9x mean / 13x p99 idle, 11x mean / 13x p99 loaded, and fsync/s 342 vs 37 — on the SAME night, SAME ambient window, with the Samsung taking its own nix-gc beating.
2. **The QLC pain is tail-shaped:** p50 ~13 ms but p99 243 ms idle → 800 ms-1 s under load. Periodic small writers (gatus ticks, 5-min ingests) mostly see the p50 and barely care; CONTINUOUS capture writers (discordsync) live in the tail — that is the whole verdict discriminator.
3. **nodatacow is worthless on the Samsung (and checksums are not):** cow ≈ nodatacow within noise (2.92 vs 3.25 ms mean; cow even had the better p99). At TLC latencies the CoW metadata cost is noise, so `cow = true` is the better default for hot-tier entries — it keeps btrfs checksums (the /data silent-corruption doctrine) for free. nodatacow stays justified only for large-file in-place rewrite fragmentation (postgres data files).
4. **Write CADENCE, not latency alone, decides "maybe they stay":** four of the five candidates are periodic small writers whose fsync pain is negligible; only discordsync's continuous capture actually suffers the QLC tail.
5. **Phase-2 enablement was BLOCKED by the hot-db landmine guard itself** (§f): the guard blanket-rejected ANY btrbk reference to `hot/`, and snapshots.nix legitimately btrbk-snapshots `hot/forgejo` (forgejo Set-B, landed 2026-09-20) — so the first entry enablement would have failed every eval. Fixed this run.

## d. Verdicts (the item's five + the ratified movers)

| DB | Path (fs today) | Write cadence | Verdict |
|----|-----------------|---------------|---------|
| gatus | /var/lib/gatus (`@` QLC) | per-check ticks (~tens of rows/min) | **STAYS** — p50-class writer, pain negligible; keeps `@` snapshot coverage; no new dump job needed |
| browser-history | /var/lib/browser-history (`@` QLC) | 5-min ingest batches | **STAYS** — batch cadence never sees the tail; `@` coverage retained |
| inboxclean | /var/lib/inboxclean (`@` QLC) | 30-min sync | **STAYS** — clear-cut |
| bank-sync | /mnt/pool/services/bank-sync (HDD RAID1 pool) | 5-min sync | **STAYS** — not on QLC at all; moving to the hot tier would trade btrbk-pool snapshot coverage for latency a 5-min sync does not need |
| discordsync | /var/lib/discordsync (`@` QLC) | CONTINUOUS capture (the 404k `database is locked` era) | **MOVES** (wave after postgres) — the only real fsync-pain DB among the five; `cow = true`; RPO = existing GCS backup leg + local-first turso posture |
| pocket-id | /var/lib/pocket-id (`@` QLC) | auth-path (login/SSO round-trips) | ratified mover; `cow = true` (finding 3 — checksums free); daily sqlite `.backup` dump exists (pocket-id-backup) |
| postgres (immich+paperless+miniflux cluster) | /var/lib/postgresql (`@` QLC) | photo-browse/paperless/miniflux WAL commits | ratified mover, biggest blast radius → second; `cow = false` per ratified layout (large-file fragmentation rationale; finding 3 makes `true` defensible if the owner prefers checksums) |
| forgejo | /var/lib/forgejo (`@` QLC) | git pushes | **SUPERSEDED** — its own landed Set-B design (services.forgejo.dedicatedSubvolume: `hot/forgejo` COW subvol + OWN 8h btrbk leg + weekly restore drill, snapshots.nix:334) already covers it; it must NOT also get a hot-db entry (a `forgejo`-named entry would trip the per-entry landmine against the Set-B leg — correct behavior) |
| docker data-root | /data/docker (QLC /data partition) | container churn | own user window, unchanged by this measurement (~20 G rsync + daemon.json data-root flip) |

## e. Per-wave window runbook (user sudo; entry snippets ready)

Each wave: declare the entry below (module validation REQUIRES `enable = true` — never commit entries without the window; an un-migrated deploy mounts an EMPTY subvol over the live dataDir) → `sudo nix run .#migrate-hot-db -- prepare <name> <unit> <dataDir>` → deploy (entry mounts) → `sudo nix run .#migrate-hot-db -- finalize <name> <unit> <dataDir>` → Gatus + functional probe → clean the shadowed original (reclaims as `@` snapshots expire).

Wave 1 — pocket-id (smallest, hottest auth path; ~30 min window):

```nix
services.hot-db = {
  enable = true;
  entries.pocket-id = {
    path = "/var/lib/pocket-id";
    cow = true;
    unit = "pocket-id.service";
    extraUnits = [ "pocket-id-backup.service" ]; # verify exact oneshot names in pocket-id.nix at window time
  };
};
```

Wave 2 — postgres (pre-req: decide the paperless PG-dump gap below; pre-dump immich+miniflux already exist):

```nix
entries.postgres = {
  path = "/var/lib/postgresql";
  cow = false;
  unit = "postgresql.service";
  extraUnits = [ "immich-db-backup.service" "miniflux-backup.service" ];
};
```

Wave 3 — discordsync (with the existing local-first turso posture; GCS backup covers RPO):

```nix
entries.discordsync = {
  path = "/var/lib/discordsync";
  cow = true;
  unit = "discordsync.service";
};
```

**RPO pre-req discovered (wave 2):** the PG cluster's paperless database has NO pg_dump (immich + miniflux do; paperless rides the document_exporter manifest). After the cluster leaves `@` snapshot coverage the exporter becomes the only paperless DR path — wire a paperless pg_dump job or record the owner decision that importer-based restore suffices (queued in storage.md).

## f. Landmine guard defect + fix (this run)

`hot-db.nix` rejected ANY btrbk string/attr-name matching a blanket `hot/` pattern — written before forgejo's Set-B leg existed. With `btrbk.instances."forgejo"` legitimately snapshotting `hot/forgejo` (snapshots.nix:334), `services.hot-db.enable = true` + ANY entry = eval failure ("BTRFS LANDMINE") on every host — Phase 2 was unimplementable. Fix: per-ENTRY matching only (an entry's mountpoint path or its `hot/<name>` subvol string), which is exactly the invariant that matters (a nodatacow ENTRY must never be snapshotted; a COW sibling subvol with its own leg is sanctioned). `tests/test-hot-db-assertions.nix` gained the coexistence case (`subvolume."hot/forgejo"` in a btrbk instance must NOT trip) and the entry-subvol case keeps firing; `nix flake check --no-build` green after the change.

## g. What remains

User windows only (queue line left BLOCKED): wave 1-3 executions (+ docker data-root window), the paperless-PG-dump pre-decision, and post-wave before/after PSI confirmation rides the existing `[watch]` rows (storage.md §Crush/PSI rows apply). Nothing else agent-side is open for this item.

## h. Files changed this run

- `scripts/fsync-bench.sh` (new — reusable before/after wave measurement, acceptance-criteria §2 vehicle)
- `modules/nixos/services/hot-db.nix` (landmine guard narrowed to per-entry; §f)
- `tests/test-hot-db-assertions.nix` (coexistence + renamed cases; header updated)
- `docs/todo/storage.md`, `TODO_LIST.md` (verdicts + BLOCKED state + one new follow-up)
- this report
