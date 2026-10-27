# Status Report: /var Storage-Tier Audit — SSD vs HDD Pool Usage

**Trigger:** owner question 2026-10-27 "Do we use storage stupidly? E.g. /var/lib/forgejo/dump?? SSDs vs HDD pool?" + a full `/var` du (516G) pasted with it.
**Method:** storage.md routing pre-read + forgejo runbook; live probes via throwaway read-only harnesses (findmnt/df/`btrfs filesystem usage`/du/ls + unit journals); nixpkgs dump-module semantics source-verified; planning pre-read (2026-10-25 QLC report + TODO grep) before queueing. NO deletes, NO config flips.

## Headline

The QLC root `/` is at **1.00 MiB device-unallocated** (allocated 722.52GiB of 722.52GiB; data 673.45GiB, used 671.99) — the 2026-06-26 metadata-ENOSPC precursor, one metadata transaction from the emergency reserve (present, 10G, re-provisioned 10-26 22:55). Meanwhile the HDD pool sits at 3.1/15T (22%) and the Samsung hot tier at 545/928G (60%). The 2026-10-25 root-space session was **perms-blind on /var** (estimated ~45G; reality 516G) — this audit extends its root-cause work into the /var layer.

## Tier map (live findmnt)

| Path | Tier | Verdict |
| --- | --- | --- |
| `/var/lib/forgejo` | Samsung `hot/forgejo` subvol | Correct tier; CONTENT mis-managed (F1) |
| `/var/lib/clickhouse` | dedicated XFS 37G/100G | Correct by design |
| `/var/log/journal` 7.8G, `/var/log/caddy` 1.7G | Samsung hot subvols | Correct |
| `/var/lib/{discordsync,dnsblockd,pocket-id,postgres,browser-history,gatus}` | Samsung hot subvols | Correct |
| `/var/lib/monitor365-server` (190G), `/var/lib/monitor365/buffer` (32G), discordsync residue, `/var/tmp` (17G), `/var/lib/containers` (4.9G), `/var/lib/private/gitea-runner` (14G), `/var/lib/inboxclean` (14.5G), `/var/lib/gitea.pre-forgejo-migration` (5G) | QLC root `@` | The problem layer (F2/F3/F5) |
| `/mnt/pool` | HDD RAID1, 12T free | Underused for exactly the things strangling the root |

## Findings

**F1 — forgejo: a redundant, retention-free third backup leg (123G on Samsung, +27G/wk).**
`services.forgejo.dump.enable = true; interval = "weekly"` (forgejo.nix:268) renders the nixpkgs `forgejo-dump` unit whose `backupDir` defaults to `<stateDir>/dump` and which has **NO pruning** (source-verified against nixpkgs gitea.nix: oneshot + WorkingDirectory=backupDir, nothing else). Inventory: 7 weekly zips 09-07→10-26, growing 3.9G→27G (mirrors/games-org growth). Fully redundant: (a) daily `forgejo-backup` 03:30 pool zip — **live-verified healthy** (10-27 03:38 wrote 27G; 8×27G on `/mnt/pool/backups/forgejo`, `find -mtime +7` retention); (b) 8h btrbk subvol leg to pool (Set-B); (c) Sunday restore drill (currently red — F4). At +27G/wk the Samsung fills in ~13 weeks.

**F2 — monitor365-server: DB + 7 full backup copies live on the 1MiB-unalloc root (190G logical).**
36G live DuckDB + 7 nightly reflink copies (KEEP=7, `find -t prune` at monitor365.nix:259-260), incl. 3 known COPY-FROM-DATABASE corpses (row services.md:596). The nightly retention **VACUUM is blocked for headroom** (10-27 journal: "headroom 11881238528 < needed 42936053760; retries next window") — the fs is too full for the DB to reclaim itself. Off-NVMe safety copy exists (T04, pool archive). The hot-tier migration row (services.md:560) fixes the tier AND, post-migration, lets `btrfs snapshot -r` + btrbk replace the 7×file-copy retention with ~free CoW snapshots (the reflink dance exists only because the state dir is a plain dir in `@`).

**F3 — monitor365 collector buffer: 32G, 2,310,842 segment files, newest 2026-07-30 13:49.**
Frozen ~3 months on the full root; disposition forks on the owner-fork row (services.md:558) — flagged, not queued for deletion unilaterally.

**F4 — forgejo-restore-drill is DAC-blind and has failed BOTH legs ≥2 Sundays (10-18 + 10-25 OnFailure pages).**
`User = "root"` + `harden{}`'s empty CapabilityBoundingSet (forgejo.nix:1182-1188) cannot traverse forgejo's 0700 dirs → "NO zip found in /mnt/pool/backups/forgejo" (8 zips present) and "NO repos found" in a populated received subvol. Exact forgejo-mirror-health class (same fix pair `CAP_FOWNER CAP_DAC_READ_SEARCH`, forgejo.md 2026-10-16 section; forgejo-subvol-backup-metrics precedent). While red, it cannot vouch for any leg — including the daily leg F1's disable relies on.

**F5 — root residue, ~60G verified-dead + 13G wiring-check:**
discordsync pre-restore copies ×4 = 23G (10-14 incident, restore succeeded 13 days ago); `/var/tmp` agent debris ≈15G (v13-rehearsal 4.3G, inboxclean-io-probe 2.9G, go-build 2.3G, 4×boot-evidence 2.2G, inboxclean-visual 1.5G, rehearsal 865M, wise-go 396M, restore scratch ×2 0.7G — 30d tmpfiles lag self-heals too slowly here); `/var/lib/containers/storage` 4.9G (overlay last written April–June, containers-storage orphaned since the Docker removal); `/var/lib/gitea.pre-forgejo-migration` 5G (April; forgejo live since September); runner `.cache/go-build` 13G despite the `/mnt/buildcache/ci-runner-cache` tmpfiles wiring (forgejo.nix:1402-1405) — wiring check before judging (runner state also owned by today's gen-955 row).

**F6 — correct-tier confirmations (not stupid):** clickhouse XFS; hot-tier subvols; pool forgejo zips + restic + clickhouse-db-backup; inboxclean corpus 13G is the evidence layer with its own pool backup chain (04:30 tar.zst, 14d) — placement review is low-priority, no row.

## Deliberately NOT touched

Nothing deleted, nothing flipped: the dumps ARE backup artifacts (deletion irreversible, owner-gated), and monitor365 config sits inside an active parallel-session storm (live cargo/libduckdb-sys build of the monitor365 repo observed during the audit; 08:24 deploy-abort + gen-955 rows adjacent).

## Harvest (self-harvest rule)

- F1 → TODO_LIST.md + services.md: disable redundant weekly dump leg + owner trash of 123G.
- F4 → TODO_LIST.md + services.md: drill CAP_DAC_READ_SEARCH fix.
- F5 (+F3 gated) → TODO_LIST.md + storage.md: /var residue sweep batch [blocked:user].
- F2 → services.md rows 560/596 updated in place (current sizes, VACUUM block, snapshot-based retention note, interim KEEP 7→2 lever).
- Row drift fixes: "verify weekly dump" rows (TODO_LIST:540 / services.md:465) repointed at the daily pool dump.
