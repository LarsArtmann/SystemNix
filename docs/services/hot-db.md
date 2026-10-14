# Hot-DB Service Tier (`services.hot-db`)

Per-service BTRFS subvolumes on the Samsung 970 EVO Plus TLC (`tlc` label,
`/mnt/hot` toplevel mount), mounted **AT each service's existing dataDir** —
the service configs themselves stay untouched. Doctrine C
(`docs/planning/2026-09-15_per-service-btrfs-subvolumes-analysis.md`):
unsnapshotted, CoW (the 2026-09-21 fsync matrix measured nodatacow worthless
on TLC — cow keeps btrfs checksums for free, the /data silent-corruption
doctrine), dump-only RPO.

- Module: `modules/nixos/services/hot-db.nix` (mounts + `hot-db-bootstrap`
  subvol creator + anti-shadow `RequiresMountsFor`/`ConditionPathIsMountPoint`
  wiring on every consumer unit + eval-time btrbk landmine scan)
- Migration vehicle: `scripts/migrate-hot-db.sh` (fixture-tested:
  `nix build .#checks.x86_64-linux.migrate-hot-db-fixture`)
- Monitoring: `hot-db-metrics` collector (5 min, fail-closed) →
  `hot_tier_mounted` + `hot_db_entry_mounted{name}` → one anchored Gatus
  check per entry + the tier toplevel (group "Storage")

## Current state

`services.hot-db.enable = true`; entries in configuration.nix:
**`discordsync` LIVE since 2026-10-12 (wave 5 done, out of order — owner chose
it first for downtime tolerance)**, **`gatus` + `browser-history` LIVE
since 2026-10-14 (waves 1+4, ONE combined owner-directed window — both
prepared AND cut over before the entry deploy, so the shadow-split landmine
below was structurally unreachable; owner override ran the window through an
active Zone-6 IO storm via the documented force escapes:
`NIX_HEAVY_GATE_FORCE=1` + `MIGRATE_PSI_FILE=/dev/null` +
`DEPLOY_FORCE_PRESSURE=1`; the first var died with the no-heavy-builds
gate's removal 2026-10-14 — the current equivalent escape is the last two).
Verified: byte-exact cutover (gatus 3 files /
19,940,064 B; browser-history 3 files / 204,124,160 B), finalize biggest-file
floor + count gates green, `hot_db_entry_mounted{name}` = 1 for both, gatus
`:9110` 200 + browser-history `/health` 200, clean journals, boot anchored
at system-885. Rollback insurance: the original QLC stores (20 MB / 204 MB,
pre-cutover) still sit hidden under the mountpoints — keep them until the
soak ends (owner call, suggest ≥1 week), then reclaim per the finalize
output.**, and **`pocket-id` LIVE since 2026-10-14 (wave 3, evening window —
but this wave is the SHADOW-SPLIT RECOVERY CASE: a parallel session deployed
the tree mid-window (the daemon had swept the prepared entry into their
commit), mounting the STALE warm copy over the live dataDir at 17:34 BEFORE
the quiesced cutover ran — service served 71 min on the torn copy. Repaired
18:45 same day per the discordsync 2026-10-12 playbook: stop → umount →
script `cutover` (byte-exact 25 files / 5,314,305 B from the clean
through-17:34 QLC store) → remount → finalize. Loss: SSO sessions created
17:34→18:45 (re-login). `hot_db_entry_mounted{name="pocket-id"}` = 1,
healthz/OIDC-discovery 200, provision + secret-bridge converged (the crm
secret double-rotation self-healed via the partOf bridge chain, ~2.5 min
window). Rollback insurance: the QLC store sits shadowed as always.**, and
**`dnsblockd` LIVE since 2026-10-14 (wave 2, night window — the HARD-DOWN
MEASUREMENT CASE: stop 21:35:45 → first clean functional proof 22:16,
~40 min vs the 2–3.5 min target — the quiesced "delta" rsync moved 4.06 GB
because dnsblockd's stop path checkpoint-rewrites tracking.db (2.37 GB), so
the delta ∝ dirty pages, not the plan's 10–60 s; the deploy's substituter
then needed the DOWN resolver for `cache.home.lan`. Queued fixes: pre-stop
`PRAGMA wal_checkpoint(TRUNCATE)` per DB + an outcome-aware window
post-deploy branch.) Verified: byte-exact cutover (9 files /
4,823,594,355 B), finalize floor+count gates green,
`hot_db_entry_mounted{name="dnsblockd"}` = 1, dig ×3 + `/health` 200 + live
LAN client blocks in the journal. The deploy ACTIVATED the wave but exited 3
(post-check DNS transient + UNANCHORED gate) and the window's abort branch
fired on a HEALTHY service — R1 was correctly skipped, and the 22:43
parallel-session deploy anchored the wave (subvol rows verifiable in the
active generation's fstab). The window also surfaced the bootstrap guard
bug: `btrfs subvolume show` EACCES on the 0700 discordsync subvol root
(CAP_DAC_OVERRIDE dropped) misread it as missing → "File exists" on every
activation since 2026-10-12 — fixed same night in the module's bounding
set. Rollback insurance: the QLC store (4.82 GB, largest of the six) sits
shadowed as always.** Remaining wave: storage-collector. Entries
are added **ONE PER WAVE** — an entry deployed before its `prepare`/`cutover`
mounts an EMPTY subvol over the live dataDir and shadow-splits the service.
**That landmine sprang once: 2026-10-12 14:31, the discordsync entry rode a
parallel session's deploy before any `prepare` — the service crash-looped
onto an empty subvol (fresh DB) while the real 994 MB store sat hidden under
the mountpoint; recovered same day via stop → umount → prepare → cutover
(byte-exact 5,744,992,552) → mount → start. Between an entry landing in the
tree and its cutover, the tree MUST NOT be deployed (daemon commits sweep
in-flight edits — see AGENTS.md multi-agent rules).** Waves are ordered
risk-ascending (regenerable stats first; wave 6 is the lowest-risk of all
and may jump the queue):

### Pre-flight verified (2026-10-04, agent session — tree untouched, throwaway extendModules)

- **All six snippets eval-green** (2026-10-04: the five waves + postgres;
  wave 6 + the refreshed postgres snippet re-verified 2026-10-12, same
  method): every entry below (+ the postgres future
  wave) applied to evo-x2 via `extendModules` — zero failed assertions
  (incl. the btrbk landmine scan), mounts render (`subvol=hot/<name>`,
  `nofail`, device `/dev/disk/by-label/tlc`; postgres carries `nodatacow`),
  anti-shadow `RequiresMountsFor`/`ConditionPathIsMountPoint` land on every
  unit AND merge with pre-existing pool gating (discordsync: attachments
  path + dataDir both wired; browser-history-backup: pool backup dir +
  dataDir), bootstrap `wantedBy` carries all six systemd-escaped mount unit
  names, 7 anchored Gatus checks render ("Hot Tier Mounted" + per entry).
- **Vehicle green**: `checks.x86_64-linux.migrate-hot-db-fixture` builds rc=0.
- **Tier live**: `hot_tier_mounted 1`, `hot_db_scrape_errors 0`, Samsung
  `/mnt/hot` has ~768 GB free.
- **GATE (wave 5)**: the discordsync dump leg FAILED 11 consecutive nights
  2026-10-03..13. Stage 1 (fixed 2026-10-11): the CLI had busy_timeout=0;
  `.timeout 30000` + 3-attempt retry deployed. Stage 2: the GCS-URL
  reconcile pass (02:00 sharp, 77+ min span, ~12 DB writes/sec) held locks
  across the old 02:30 slot — timer moved to 03:45 + journal quiet-gate.
  Stage 3 (2026-10-13): the first 03:45 run STILL lost after 90 s WHILE the
  quiet-gate PASSED on 3-min reconcile silence — the holder is a different,
  silent writer (post-shadow-split re-backfill after the 2026-10-12 21:52
  restart is the prime suspect). Hardening (2026-10-13, eval-verified, rides
  next deploy): catch-up windows 05:15 + 06:45 (Persistent re-runs MISSED
  activations, never FAILED runs; the script's already-today guard makes
  post-success catch-ups no-ops), pre-visibility `quick_check` gate on the
  raw dump, upfront stale-intermediate cleanup, idempotency guard. The
  10-01 dump itself was RESTORE-DRILLED 2026-10-13 (381 MB, quick_check ok,
  43,617 messages, newest message 02:26 — the leg DID work until Oct 1).
  Full narrative: `docs/status/2026-10-13_20-45_discordsync-backup-drill-and-catchup-windows.md`.
- **GATE (all waves)**: IO PSI avg10 was 54% at verification (Zone-6 storm,
  5 memory-guard trips/h) — no window until quiescence (the script's own
  ≥ 20% refusal fires anyway).
- Known flake-gate hazard (not wave-specific): the `hermes-python-source`
  IFD orphan can brick `nix flake check --no-build` after a GC — see
  `docs/todo/pipeline.md` "orphan" row; build `.#checks.x86_64-linux.hermes`
  once to re-realize the path.

| Wave | Entry               | dataDir (REAL path)                                                                     | Stop window blip                                                 | Backup leg                                                                                                    |
| ---- | ------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1    | `gatus`             | `/var/lib/private/gatus` — **LIVE on tlc since 2026-10-14**                                                            | monitoring blind ~1-3 min (every check reds once, then resolves; ACTUAL 2026-10-14: ~48 min — the cutover→deploy gap stretched by a shared-tree build blocker, see docs/status/2026-10-14_16-20) | none — self-pruning stats, regenerable                                                                        |
| 2    | `dnsblockd`         | `/var/lib/dnsblockd` — **LIVE on tlc since 2026-10-14** (4.82 GB actual; the old "~2.5 GB" was a stale estimate — tracking.db is 2.37 GB of it) | LAN DNS blip (ACTUAL 2026-10-14: ~40 min hard-down, 21:35:45 stop → 22:16 clean proof — checkpoint-on-stop inflated the delta to 4.06 GB, see Current state) | none — self-pruning tracking stats                            |
| 3    | `pocket-id`         | `/var/lib/pocket-id` — **LIVE on tlc since 2026-10-14** (via shadow-split recovery, see Current state)                  | SSO blip (ACTUAL 2026-10-14: the parallel-deploy mount at 17:34 + the 18:45 repair = ~71 min on a torn warm copy, then a clean restart; SSO sessions from the split window require re-login) | `pocket-id-backup` (04:00 sqlite .backup, pool)                                                               |
| 4    | `browser-history`   | `/var/lib/private/browser-history` — **LIVE on tlc since 2026-10-14**                                                   | ingest retries on next 5-min tick (ACTUAL 2026-10-14: ~48 min stall, same window)                                 | `browser-history-backup` (02:15, pool)                                                                        |
| 5    | `discordsync`       | `/var/lib/discordsync` (~380 MB event store — drill-verified 2026-10-13; the old "~11 GB" was a stale estimate — the longest delta+verify)  | Discord capture gap ≈ any restart; keep tight                    | `discordsync-db-backup` (03:45 + 05:15/06:45 catch-up gzipped dump, pool — the dump-only RPO leg, Turso is plan-blocked)             |
| 6    | `storage-collector` | `/var/lib/private/storage-collector` (~60 MB today; flips to a 1 GiB window at cutover) | monitoring gap ~1 min (textfile gauges stall, Gatus reds once)   | `restic-storage-history` (04:20 nightly, no-prune pool repo — LANDED 2026-10-12, history survives regardless) |

DynamicUser services (gatus, browser-history, storage-collector) mount the
REAL dir behind the `/var/lib/<name> -> private/<name>` symlink — mounting
the symlink path itself would not work. All six entries are `cow = true`
(measurement doctrine above). Wave 6 fail-closed note: the service carries
`StateDirectory` → implicit `RequiresMountsFor`; a detached Samsung stops
the collector (clean restart on remount; the pool history tier is
unaffected) — accepted for a monitoring store, per the Pre-cutover check.

## The wave procedure (per service)

```bash
# 1. Add the entry (snippet below) to services.hot-db.entries — enable = true,
#    DO NOT deploy yet. Keep the window tight after this point.
# 2. Warm copy (service keeps RUNNING; ~min for the 11 GB leg):
sudo nix run .#migrate-hot-db -- prepare <name>
# 3. Pre-build the closure so the deploy switch is seconds, not minutes:
nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel
# 4. Quiesce + delta + verify (units STOPPED from here until the deploy):
#    BIG-SQLITE CAVEAT (2026-10-14 dnsblockd wave): a service whose stop path
#    checkpoint-rewrites its main DB makes the quiesced delta GB-scale, not
#    seconds — pre-stop each DB with
#    `sqlite3 <db> "PRAGMA wal_checkpoint(TRUNCATE)"` while the service is
#    still up (queued as a migrate-hot-db cutover step).
sudo nix run .#migrate-hot-db -- cutover <name>
# 5. Deploy (mounts the populated subvol AT the dataDir, restarts the service
#    onto it via RequiresMountsFor):
nix run .#deploy
# 6. Verify + restart everything + functional probes:
sudo nix run .#migrate-hot-db -- finalize <name>
#    Then confirm monitoring sees the mount (node_exporter textfile, fail-closed
#    = an ABSENT metric means the collector failed, never phantom-green):
#    curl -s --compressed http://127.0.0.1:9100/metrics | grep -F 'hot_db_entry_mounted{name="<name>"} 1'
```

`migrate-hot-db.sh status` prints per-entry subvol/mountpoint/marker state.
Generic escape for future waves (postgres): `prepare <name> <dataDir> <unit>
[more units...]`.

**Parallel-deploy hazard:** between cutover and the deploy, any OTHER
session's deploy can restart the stopped units back onto the un-mounted QLC
dir; a mount-over then shadow-splits the running process. Do not run waves
while other sessions deploy.

## Pre-cutover check: `*Directory=` implicit RequiresMountsFor (2026-10-01)

systemd.exec "Automatic Dependencies": ANY of `WorkingDirectory=`,
`StateDirectory=`, `RuntimeDirectory=`, `LogsDirectory=`, `CacheDirectory=`,
`ConfigurationDirectory=` (plus RootDirectory/RootImage) gains an implicit
`Requires=` + `After=` on every mount unit needed to reach the path —
equivalent to `RequiresMountsFor=`. A service whose dataDir carries such a
setting therefore HARD-REQUIRES the hot-db mount: a detached Samsung fails
the unit instead of degrading it (VM-test-proven on caddy's
`LogsDirectory=` — `tests/test-caddy-logs-hot.nix`, degraded node; fix
pattern there = `serviceConfig.<X>Directory = mkForce []` + tmpfiles
existence + `+`-prefixed ExecStartPre chown). Rendered-config sweep of the
five wave services (evo-x2, 2026-10-01):

| Service         | Settings carrying the trap                                                     | Consequence at cutover                        |
| --------------- | ------------------------------------------------------------------------------ | --------------------------------------------- |
| gatus           | `StateDirectory=gatus` + `RuntimeDirectory=gatus`                              | hard-requires `var-lib-gatus.mount`           |
| dnsblockd       | `StateDirectory=dnsblockd` + `WorkingDirectory=/var/lib/dnsblockd`             | hard-requires `var-lib-dnsblockd.mount`       |
| pocket-id       | `WorkingDirectory=/var/lib/pocket-id`                                          | hard-requires `var-lib-pocket-id.mount`       |
| browser-history | `StateDirectory=browser-history` + `WorkingDirectory=/var/lib/browser-history` | hard-requires `var-lib-browser-history.mount` |
| discordsync     | none (`ReadWritePaths` is path-based, not mount-required)                      | degrades gracefully like caddy                |

Decision framing per wave (do NOT silently inherit either way): for
DATABASE-backed services the implicit hard-require is arguably CORRECT
fail-closed semantics — a DB must never keep writing into the QLC shadow
dir through the mount (silent split-brain), so let the unit fail on a
detached Samsung (monitoring already owns the alert). For anything that
must survive Samsung absence, apply the caddy treatment. The wave's entry
comment in `services.hot-db.entries` should record which stance was chosen.

## Entry snippets (unit lists verified in-tree)

Wave 1 — gatus:

```nix
entries.gatus = {
  path = "/var/lib/private/gatus";
  cow = true;
  unit = "gatus.service";
};
```

Wave 2 — dnsblockd:

```nix
entries.dnsblockd = {
  path = "/var/lib/dnsblockd";
  cow = true;
  unit = "dnsblockd.service";
};
```

Wave 3 — pocket-id (unit lists verified 2026-09-21, §i addendum of the
fsync-matrix report):

```nix
entries.pocket-id = {
  path = "/var/lib/pocket-id";
  cow = true;
  unit = "pocket-id.service";
  # pocket-id-backup reads the sqlite file directly;
  # pocket-id-provision WRITES client-secrets/ under the dataDir — without
  # the anti-shadow wiring a detached Samsung would let it shadow-write
  # OIDC client secrets onto the root fs (the 2026-08-22 secret-desync
  # class, self-inflicted by the tier).
  extraUnits = [ "pocket-id-backup.service" "pocket-id-provision.service" ];
};
```

Wave 4 — browser-history:

```nix
entries.browser-history = {
  path = "/var/lib/private/browser-history";
  cow = true;
  unit = "browser-history.service";
  # token-provision writes the DB; the backup reads it directly. The
  # agent-metrics collector is deliberately NOT wired (ConditionPathIsMountPoint
  # on the shared system-health collector would dark the whole fleet's
  # metrics on a detached Samsung; the dedicated agent-metrics collector
  # fails closed via its own scrape_errors instead).
  extraUnits = [
    "browser-history-agent-token-provision.service"
    "browser-history-backup.service"
  ];
};
```

Wave 5 — discordsync (unit list verified 2026-09-21 §i; db-heal gets the
clean condition-skip instead of a 226 on a detached Samsung):

```nix
entries.discordsync = {
  path = "/var/lib/discordsync";
  cow = true;
  unit = "discordsync.service";
  extraUnits = [ "discordsync-db-heal.service" ];
};
```

Wave 6 — storage-collector (eval-verified 2026-10-12 via throwaway
extendModules: 0 failed assertions, mount renders `subvol=hot/storage-collector`,
the daemon flags flip to `--max-file-mb 50 --keep-files 20`, anti-shadow
wiring lands on the service AND the verify unit). Flip BOTH blocks in
configuration.nix at the window — the knobs grow the rotation bound to
1 GiB ONLY once the dataDir sits on the subvol (until then the 60 MiB
bound stays on the QLC root on purpose):

```nix
entries.storage-collector = {
  path = "/var/lib/private/storage-collector";
  cow = true;
  unit = "storage-collector.service";
  extraUnits = [ "storage-collector-verify.service" ];
};
```

```nix
services.storage-collector = {
  maxFileMb = 50; # with keepFiles = 20 → 1 GiB ≈ 27 d full-res hot window
  keepFiles = 20;
};
```

Future wave — postgres cluster (ratified; the paperless pg_dump gap that
originally gated it CLOSED 2026-09-21 — `paperless-db-backup.timer` nightly
dump):

```nix
entries.postgres = {
  path = "/var/lib/postgresql";
  cow = false; # ratified: large-file fragmentation rationale
  unit = "postgresql.service";
  # every pg_dump leg on the cluster gets the protective condition-skip
  # wiring (paperless-db-backup + geometrikks-db-backup joined the two
  # originals, 2026-10-11; bank-sync + paperless-gpt ride plain
  # postgresql.service ordering — no dataDir file access)
  extraUnits = [
    "immich-db-backup.service"
    "miniflux-backup.service"
    "paperless-db-backup.service"
    "geometrikks-db-backup.service"
  ];
};
```

## Rollback

Remove the entry from the config, deploy, `sudo systemctl start <units>`.
The QLC original sits shadowed under the mountpoint with everything up to
the cutover (post-cutover writes live only in the subvol) — flip back SOON
after a bad wave to minimize divergence. `nix run .#migrate-hot-db --
status` + `findmnt <dataDir>` tell you which side is live.
**SECRET-STORE CAVEAT (pocket-id class): the shadow's `client-secrets/`
freezes at cutover while rotations continue on the subvol — after ANY
post-cutover secret rotation, a QLC rollback reinstates the OLD secret
against consumers holding the NEW one (instant desync). Before rolling a
secret-store back, re-run the provisioner's rotation for every client
rotated since the cutover (or accept the consumer restarts).**

**OUTCOME-AWARE ABORT RULE (2026-10-14 wave-2 lesson): a deploy exit-3 is
NOT "service down" — verify `findmnt <dataDir>` + `systemctl is-active` +
a functional probe BEFORE routing to R1. The wave-2 window aborted
pre-finalize on a healthy migrated service because the deploy's own
post-check (DNS transient + UNANCHORED gate) tripped the failure branch.
R1 was preserved as a manual paste, which is the only reason a destructive
rollback didn't fire.**

R1 quick-rollback card (abort back onto the untouched QLC shadow; entry
removal from configuration.nix happens at leisure):

```bash
if mountpoint -q /var/lib/dnsblockd; then
  umount /var/lib/dnsblockd && echo "R1: subvol unmounted"
else
  echo "R1: not mounted — nothing to unmount (deploy failed pre-switch)"
fi
systemctl start dnsblockd.service
sleep 2
systemctl is-active dnsblockd.service
dig @127.0.0.1 home.lan +time=2 +tries=1 +short || true
echo "R1 done — dnsblockd back on QLC. Diagnose offline before re-windowing."
```

## Shadow-dir policy

Keep the shadowed QLC originals as rollback insurance until each wave's
soak ends (journal-hot doctrine). When cleaning: remove the CONTENTS, keep
the DIRECTORY — systemd never creates mountpoints, and the mount unit needs
the dir to exist at boot. Space frees as the `@` snapshots pinning the old
bytes expire (root pin window = 3d since 2026-10-08, was 2w sharp, calendar-anchored).

## Why gatus/browser-history moved despite the 2026-09-21 "STAY" verdicts

The fsync matrix verdicts kept them on the QLC for latency reasons — but
the owner's 2026-09-30 QLC-churn evacuation decision (the freeze-era
doctrine: every always-on writer that can leave the QLC should) supersedes
them. The trade accepted: both leave `@` snapshot coverage (both have
pool-side dump legs; gatus history is regenerable stats).

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Hot-DB Service Tier (`services.hot-db`, waves armed 2026-09-30)

Per-service BTRFS subvols on the Samsung, mounted AT each dataDir (`docs/services/hot-db.md` is the runbook — waves gatus → dnsblockd → pocket-id → browser-history → discordsync, one entry per maintenance window). `enable = true` with `entries = { }` ships ZERO mounts; adding an entry without running `migrate-hot-db.sh prepare/cutover` first mounts an EMPTY subvol over live data (shadow-split) — the runbook's 6-step window is mandatory. Vehicle (2026-09-30): `migrate-hot-db.sh` warm-prepare/cutover/finalize flow (registry of the five with stop-sets; stop window = cutover→switch only; finalize verifies via biggest-file floor + count-vs-marker; fixture-tested as `checks.migrate-hot-db-fixture`), T14 monitoring (`hot-db-metrics` fail-closed collector → `hot_db_entry_mounted{name}` + one anchored Gatus check per entry via the `gatus-config.extraEndpoints` seam; REVIEW-HARDENED 2026-09-30: "fail-closed" is EMISSION semantics — metric absence covers only the never-ran case, collector DEATH is owned by `onFailure` → `notify-failure@` + `hot-db-metrics` in `system-health.extraMonitoredServices` (`65e93b80`); the VM test asserts the entry-gauge-0 failure transition, not just the happy snapshot, `f2edc387`), and the discordsync dump-only RPO leg (`discordsync-db-backup` 03:45 gzipped sqlite `.backup` → `/mnt/pool/backups/discordsync`, registered in backup-coordination + restic — with Turso plan-blocked it is the event store's only backup once it leaves `@`). All five entries are `cow = true` (2026-09-21 measurement: nodatacow worthless on TLC, checksums free). DynamicUser services mount the REAL `/var/lib/private/<name>` dir behind the public symlink. Postgres wave (ratified, `cow = false`) rides the same vehicle via the script's generic `<name> <dataDir> <unit>` form.
