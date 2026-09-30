# Hot-DB Service-DB Waves: Vehicle Rebuilt, Armed, and Monitored (2026-09-30 00:55)

Owner ask: move the Pocket ID, dnsblockd, Gatus, Browser-History, and
DiscordSync DBs into their own BTRFS subvolumes onto the Samsung SSD, **one
by one**. Outcome: the ratified-but-dormant `services.hot-db` mechanism is
now LIVE and wave-ready — every piece an agent could land without sudo is
landed; the five migrations themselves are owner windows.

## a. What ran

1. Recon: journal-hot pattern (`platforms/nixos/system/journal-hot.nix`,
   `scripts/migrate-journal-hot.sh`), the dormant Phase-2 module
   (`modules/nixos/services/hot-db.nix` + `scripts/migrate-hot-db.sh` +
   `tests/test-hot-db.nix` + the assertions test), the 2026-09-21 fsync
   matrix report (verdicts + verified unit lists), live mount/dataDir
   probes (findmnt, /var/lib layout, Samsung 786G free).
2. `scripts/migrate-hot-db.sh` REWRITTEN: registry of the five services
   (name → real dataDir + stop-set incl. sidecar timers) + warm-prepare /
   cutover / finalize / status flow + generic `<name> <dataDir> <unit>`
   escape for the future postgres wave.
3. All four documented vehicle defects (storage.md row 157) fixed — see §b.
4. T14 monitoring in `hot-db.nix`: `hot-db-metrics` fail-closed collector
   - per-entry anchored Gatus checks via the `gatus-config.extraEndpoints`
     seam (the withPapIngest pass).
5. DiscordSync dump-only RPO leg: `discordsync-db-backup` (02:30, gzipped
   online sqlite `.backup` → `/mnt/pool/backups/discordsync`) + pool leaf
   creator (deploy.sh provisioner list) + backup-coordination row + restic
   path.
6. `configuration.nix`: `services.hot-db.enable = true; entries = { }`
   (ZERO mounts ship — entries land one per wave), discordsync
   `dbBackup.enable = true`.
7. Tests: `scripts/test-migrate-hot-db.sh` (21 assertions [superseded 2026-09-30
   re-dispatch: 22 PASS assertion sites, see storage.md row 36], PATH-stubbed
   btrfs/chattr/systemctl/mountpoint + real rsync) wired as
   `checks.migrate-hot-db-fixture`; `tests/test-hot-db.nix` extended with
   collector assertions.
8. Docs: runbook `docs/services/hot-db.md` (the five waves with verified
   entry snippets, rollback, shadow policy), storage.md rows 34/35/36/157
   closed, AGENTS.md state updated (module no longer dormant + new
   Hot-DB Service Tier section + discordsync dump bullet), CHANGELOG.

## b. The four vehicle defects (row 157) — fixed by flow replacement

The old staging-dir flow stopped the service at `prepare` and left it
stopped through the BUILD + deploy + finalize (minutes-to-hours of DNS/SSO
outage per wave). The rewrite makes the stop window cutover→switch only:

1. **`/mnt/hot/hot` gate contradiction** → `prepare` runs `mkdir -p` on the
   parent; no pre-gate.
2. **finalize verified NOTHING** → two gates: biggest-file floor (the
   cutover marker records the largest file's path+size — the small-tree
   gate; a ±2 count tolerance alone is vacuous on gatus's 2-3-file dir,
   found live by the fixture test) + file-count-vs-marker with the WAL/-shm
   ±2 tolerance.
3. **`--dry-run prepare` crashed at verify** → dry-run mutates nothing and
   skips all verification (fixture-pinned).
4. **procedural stop window** → per-service stop-sets
   (`browser-history-agent.timer` + agent + token-provision; pocket-id +
   provision) and the parallel-deploy restart hazard printed at cutover
   AND documented in the runbook.

Flow shape per wave (runbook §"The wave procedure"): add entry →
`prepare` (LIVE warm rsync, nothing stopped) → pre-build closure →
`cutover` (stop-set, quiesced delta `--delete`, EXACT count+size verify,
marker) → deploy (mounts the POPULATED subvol; RequiresMountsFor orders
the restart after the mount) → `finalize` (verify + restart + functional
probes).

## c. Decisions worth recording

- **All five entries `cow = true`** — the 2026-09-21 measurement doctrine
  (nodatacow worthless on TLC; checksums free). Only the future postgres
  wave stays `cow = false` (large-file fragmentation rationale).
- **The user's five supersede the 2026-09-21 "STAY" verdicts** for
  gatus/browser-history — owner's QLC-churn evacuation decision
  (2026-09-30 wave table + direct instruction). Trade accepted + runbook
  documents it: both leave `@` snapshot coverage; both have pool dump legs
  (gatus is regenerable stats).
- **DynamicUser services mount the REAL `/var/lib/private/<name>` dir** —
  `/var/lib/gatus` is a symlink; the public paths keep working through the
  mountpoint.
- **gatus/browser-history DB readers deliberately NOT anti-shadow-wired
  when they're shared collectors**: system-health (wiring it would dark
  the whole fleet's `system_*` metrics on a detached Samsung) fails
  closed via its own scrape handling; the dedicated
  browser-history-agent-metrics collector IS unwired-by-choice for the
  same reason and fails via scrape_errors. Direct readers/writers
  (backup units, provision oneshots, db-heal) ARE wired.
- **discordsync dump added in-scope**: option C doctrine says dump-only
  RPO; Turso is plan-blocked; without the dump the wave would strip the
  event store's last backup.

## d. Verification

- `nix flake check --no-build` (x86_64-linux AND `--all-systems`): all
  checks passed, post-formatting.
- `checks.x86_64-linux.migrate-hot-db-fixture` BUILT GREEN in-sandbox
  (21/21 assertions [superseded 2026-09-30 re-dispatch: 22 PASS assertion
  sites, see storage.md row 36]; local run exit 0 too).
- Eval renders: `hot-db-metrics` ExecStart + 5min timer;
  `extraEndpoints` 108→109 (exactly the one tier check, entries = {});
  `discordsync-db-backup` OnCalendar `*-*-* 02:30:00`, TimeoutStartSec
  30min; evo-x2 toplevel drvPath evaluates.
- Formatter: treefmt pass applied to the touched files; post-format
  `bash -n` + fixture re-run + flake check all re-verified.

## e. NOT done / deferred

- **The five migration windows themselves** — owner sudo (runbook:
  `docs/services/hot-db.md`; storage.md row 34 carries the [blocked:user]
  state). Wave order: gatus → dnsblockd → pocket-id → browser-history →
  discordsync.
- **`tests/test-hot-db.nix` VM re-run** — extended with collector
  assertions but NOT executed: IO PSI some avg10 was 79% during the
  session (active storm; heavy-job doctrine defers VM boots). The test
  change is eval-covered by flake check; the runtime leg rides the next
  quiet window. (Deliberately not a TODO_LIST row — it is a [watch]-grade
  item folded into row 34's remaining-work note.)
- **First deploy of this batch** — user-run; activates the collector +
  the tier Gatus check + the discordsync backup units (first dump lands
  at the next 02:30 window; the `Hot Tier Mounted` check goes green once
  the collector's first textfile lands).

## f. Follow-ups harvested

1. storage.md row 34 updated in place (VEHICLE READY, remaining = the five
   user windows). ✓ at authoring
2. Rows 35 (T14), 36 (fixture test), 157 (vehicle defects) → `[x]` DONE. ✓
3. AGENTS.md: crush-hot-db INTERIM paragraph corrected (module LIVE) + new
   "Hot-DB Service Tier" section + discordsync dump bullet. ✓
4. CHANGELOG entry. ✓

## g. Files changed

- `scripts/migrate-hot-db.sh` (rewritten), `scripts/test-migrate-hot-db.sh`
  (new), `flake.nix` (fixture check),
  `modules/nixos/services/hot-db.nix` (T14 collector + checks),
  `modules/nixos/services/discordsync.nix` (dbBackup leg),
  `modules/nixos/services/restic-app-dumps.nix` (path),
  `scripts/deploy.sh` (provisioner list), `platforms/nixos/system/
  configuration.nix` (enable + dbBackup), `tests/test-hot-db.nix`
  (collector assertions), `docs/services/hot-db.md` (new runbook),
  `docs/todo/storage.md`, `AGENTS.md`, `CHANGELOG.md`.
