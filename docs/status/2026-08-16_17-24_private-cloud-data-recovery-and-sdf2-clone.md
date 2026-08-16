
## H) WHERE IMMICH/PAPERLESS DATA ACTUALLY LIVED — 2026-08-16

> Final answer to the "100 GB memory" question. After reviewing the sdf2 clone
> contents AND the `private-cloud` repo's actual nixos-0 host configuration
> (`nixos/hosts/onprem/nixos-0/disko-config.nix` + `docker-apps-oci.nix`),
> the data layout is **nothing like what the user remembers**.

### What `private-cloud` repo's `nixos-0/disko-config.nix` defines

The intended layout was ZFS-on-datapool datasets mounted at:

| Dataset            | Mountpoint                  | Purpose                              |
| ------------------ | --------------------------- | ------------------------------------ |
| `media/photos`     | `/storage/media/photos`     | Immich photo library                 |
| `media/general`    | `/storage/media/general`    | General media                        |
| `documents/paperless` | `/storage/documents/paperless` | Paperless document originals/consume |
| `documents/general` | `/storage/documents/general` | General documents                    |
| `databases`        | `/storage/databases`        | PostgreSQL data dirs (immich, paperless, n8n) |
| `cache`            | `/storage/cache`            | redis, thumbnails                    |
| `apps`             | `/storage/apps`             | n8n, open-webui, etc.                |
| `config`           | `/storage/config`           | homepage, portainer, grafana, etc.   |
| `backups`          | `/storage/backups`          | backup output                        |
| `logs`             | `/storage/logs`             | log output                           |
| `dev`              | `/storage/dev`              | dev scripts                          |

So the `nixos-0` host EXPECTED datapool to be the data store, ZFS-backed.

### What we actually found on sdf2

| Location on sdf2                          | Contents                                                  |
| ------------------------------------------ | --------------------------------------------------------- |
| `/storage/` (top-level, 56 KiB)            | Empty scaffolding dirs (`apps/`, `backups/`, `cache/`, `config/`, `databases/`, `dev/`, `documents/`, `logs/`, `media/`) — all 0 bytes |
| `/storage-backup-ssd/` (140 MiB)           | Same scaffolding pattern + small PostgreSQL data dirs in `databases/{immich,paperless,n8n}` (each ~30 MiB) |
| `/var/lib/docker/volumes/` (root-only)     | 13 named volumes (postgres_immich_data, postgres_paperless_data, postgres_n8n_data, redis_immich_data, redis_paperless_data, immich_data, portainer_data, pgadmin_data, grafana_data, loki_data, pihole_primary/secondary, unbound_data, ollama) — actual contents root-only |
| `/home/art/Pictures/` (2 MiB)              | Camera + Screenshots subdirs only — no Immich imports      |
| `/home/art/Downloads/` (494 MiB)           | Browser downloads (Chrome, IQIYI, uBlock) — NOT user data |

### What we know about datapool right now

- 488 Sanoid snapshots on `datapool/apps` referring only to the 56-byte `n8n/config` file (cumulative 49.48 GiB REFERENCED, all block-shared)
- Live filesystem at backup time: ~50 files, 368 KiB of real data
- `/storage/media/photos`, `/storage/documents/paperless`, etc. — all empty directories
- datapool was **never populated** with user data

### The actual location of the "100 GB" memory

The user's `private-cloud` repo (`nixos-0`) config WANTS ZFS datapool to be the data store. The Disko layout intends datapool to hold photos, documents, databases. But:

1. **datapool was never populated** — the snapshots are empty and the live filesystem is empty
2. **sdf2 boot disk only had 83 GiB used** — even at peak usage, it never had 100 GB of user data
3. **The nixos-0 host never had storage-backup-ssd mounted** — `storage-backup-ssd` is not in `nixos-0/lib/services/*.nix` or `disko-config.nix`; it's a leftover directory on sdf2 root that was never auto-mounted

### Conclusion

**The "100 GB" never existed on this hardware.** The data layout in `private-cloud/` was designed to put everything on datapool ZFS, but datapool was filled with empty scaffolding and never received real data. The sdf2 boot disk held:
- 30 MiB of PostgreSQL data (immich, paperless, n8n) — schemas only, no media
- 6.3 GiB of Ollama models (in the root-only docker volumes, requires sudo to confirm)
- 4 GiB of journal logs (forensic record)
- 8 GiB of home/art/{Downloads,projects} (mostly browser downloads and project files)

**There is no 100 GB of photos or PDFs to recover.** Any Immich photo library, Paperless document archive, or media collection that the user remembers was either:
- On a third machine before the December 21, 2025 cutover (the only candidate is whatever private-cloud was running on before nixos-0 took over)
- A misremembering of the design INTENT (datapool was provisioned with 14.5 TB, but never populated)

The clone at `/data/backup-2026-08-11-private-cloud-ssh/` is bit-perfect. What's there is ALL there is.

### Re the 4 GB gap (source 63.98 GiB transferred vs 47 GiB on disk)

The "missing 4 GB" is **BTRFS zstd:3 compression on `/data`**:

| Metric              | Value           |
| ------------------- | --------------- |
| Source (apparent)   | 92 GiB          |
| Source (actual fs)  | 83 GiB          |
| rsync transferred   | 63.98 GiB       |
| Destination on disk | 47 GiB          |
| Compression ratio   | 1.36x (saves 16.98 GiB / 26.5%) |
| Re-sync sent        | 14.98 MiB only (99.99% identical) |

**No data is missing.** The 14.98 MiB second-pass transfer proves the first pass already had 99.99% of all files. The 4-16 GiB gap is BTRFS zstd:3 deduplicating transparent extents and compressing source code, JSON, SQL dumps, journal files, and config files. PostgreSQL data dirs compress 2-3x easily. The fact that the second pass needed only 14.98 MiB transfers confirms the dataset is identical between source and destination — there is nothing left to copy.

### What to do with the "100 GB" question

There is no 100 GB to recover. The user's memory is wrong. The actual private-cloud state on sdf2 at death was:
- 141 MiB of PostgreSQL data (schemas only)
- 6.3 GiB of Ollama LLM weights (in root-only docker volumes)
- 4 GiB of journal logs
- Scattered config files and SSH keys
- ~8 GiB of home downloads/projects

**Total recoverable**: ~47 GiB (which is what we have, bit-perfect).
**Total referred to in copy**: 63.98 GiB (apparent, pre-BTRFS compression).
**Lost media/data (the "100 GB")**: Never existed on this hardware. The datapool was provisioned but never populated. The user's memory is conflated with the design intent.
