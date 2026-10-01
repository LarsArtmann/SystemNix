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

`services.hot-db.enable = true; entries = { }` (configuration.nix). Entries
are added **ONE PER WAVE** — an entry deployed before its
`prepare`/`cutover` mounts an EMPTY subvol over the live dataDir and
shadow-splits the service. The five waves below are ordered
risk-ascending (regenerable stats first, the 11 GB event store last):

| Wave | Entry             | dataDir (REAL path)                                                                | Stop window blip                                                 | Backup leg                                                                                        |
| ---- | ----------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| 1    | `gatus`           | `/var/lib/private/gatus`                                                           | monitoring blind ~1-3 min (every check reds once, then resolves) | none — self-pruning stats, regenerable                                                            |
| 2    | `dnsblockd`       | `/var/lib/dnsblockd` (~2.5 GB incl. the stale `dnsblockd_tracking.db` legacy file) | LAN DNS blip; gatus "DNS Resolver" pages once + resolves         | none — self-pruning tracking stats                                                                |
| 3    | `pocket-id`       | `/var/lib/pocket-id`                                                               | SSO blip                                                         | `pocket-id-backup` (04:00 sqlite .backup, pool)                                                   |
| 4    | `browser-history` | `/var/lib/private/browser-history`                                                 | ingest retries on next 5-min tick                                | `browser-history-backup` (02:15, pool)                                                            |
| 5    | `discordsync`     | `/var/lib/discordsync` (~11 GB — the longest delta+verify)                         | Discord capture gap ≈ any restart; keep tight                    | `discordsync-db-backup` (02:30 gzipped dump, pool — the dump-only RPO leg, Turso is plan-blocked) |

DynamicUser services (gatus, browser-history) mount the REAL dir behind the
`/var/lib/<name> -> private/<name>` symlink — mounting the symlink path
itself would not work. All five entries are `cow = true` (measurement
doctrine above).

## The wave procedure (per service)

```bash
# 1. Add the entry (snippet below) to services.hot-db.entries — enable = true,
#    DO NOT deploy yet. Keep the window tight after this point.
# 2. Warm copy (service keeps RUNNING; ~min for the 11 GB leg):
sudo nix run .#migrate-hot-db -- prepare <name>
# 3. Pre-build the closure so the deploy switch is seconds, not minutes:
nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel
# 4. Quiesce + delta + verify (units STOPPED from here until the deploy):
sudo nix run .#migrate-hot-db -- cutover <name>
# 5. Deploy (mounts the populated subvol AT the dataDir, restarts the service
#    onto it via RequiresMountsFor):
nix run .#deploy
# 6. Verify + restart everything + functional probes:
sudo nix run .#migrate-hot-db -- finalize <name>
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

| Service          | Settings carrying the trap                                        | Consequence at cutover                                   |
| ---------------- | ----------------------------------------------------------------- | -------------------------------------------------------- |
| gatus            | `StateDirectory=gatus` + `RuntimeDirectory=gatus`                 | hard-requires `var-lib-gatus.mount`                      |
| dnsblockd        | `StateDirectory=dnsblockd` + `WorkingDirectory=/var/lib/dnsblockd` | hard-requires `var-lib-dnsblockd.mount`                  |
| pocket-id        | `WorkingDirectory=/var/lib/pocket-id`                             | hard-requires `var-lib-pocket-id.mount`                  |
| browser-history  | `StateDirectory=browser-history` + `WorkingDirectory=/var/lib/browser-history` | hard-requires `var-lib-browser-history.mount` |
| discordsync      | none (`ReadWritePaths` is path-based, not mount-required)         | degrades gracefully like caddy                            |

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

Future wave — postgres cluster (ratified; decide the paperless pg_dump gap
first — see `docs/status/2026-09-21_00-25_*` §e):

```nix
entries.postgres = {
  path = "/var/lib/postgresql";
  cow = false; # ratified: large-file fragmentation rationale
  unit = "postgresql.service";
  extraUnits = [ "immich-db-backup.service" "miniflux-backup.service" ];
};
```

## Rollback

Remove the entry from the config, deploy, `sudo systemctl start <units>`.
The QLC original sits shadowed under the mountpoint with everything up to
the cutover (post-cutover writes live only in the subvol) — flip back SOON
after a bad wave to minimize divergence. `nix run .#migrate-hot-db --
status` + `findmnt <dataDir>` tell you which side is live.

## Shadow-dir policy

Keep the shadowed QLC originals as rollback insurance until each wave's
soak ends (journal-hot doctrine). When cleaning: remove the CONTENTS, keep
the DIRECTORY — systemd never creates mountpoints, and the mount unit needs
the dir to exist at boot. Space frees as the `@` snapshots pinning the old
bytes expire (root pin window = 2w sharp, calendar-anchored).

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

Per-service BTRFS subvols on the Samsung, mounted AT each dataDir (`docs/services/hot-db.md` is the runbook — waves gatus → dnsblockd → pocket-id → browser-history → discordsync, one entry per maintenance window). `enable = true` with `entries = { }` ships ZERO mounts; adding an entry without running `migrate-hot-db.sh prepare/cutover` first mounts an EMPTY subvol over live data (shadow-split) — the runbook's 6-step window is mandatory. Vehicle (2026-09-30): `migrate-hot-db.sh` warm-prepare/cutover/finalize flow (registry of the five with stop-sets; stop window = cutover→switch only; finalize verifies via biggest-file floor + count-vs-marker; fixture-tested as `checks.migrate-hot-db-fixture`), T14 monitoring (`hot-db-metrics` fail-closed collector → `hot_db_entry_mounted{name}` + one anchored Gatus check per entry via the `gatus-config.extraEndpoints` seam; REVIEW-HARDENED 2026-09-30: "fail-closed" is EMISSION semantics — metric absence covers only the never-ran case, collector DEATH is owned by `onFailure` → `notify-failure@` + `hot-db-metrics` in `system-health.extraMonitoredServices` (`65e93b80`); the VM test asserts the entry-gauge-0 failure transition, not just the happy snapshot, `f2edc387`), and the discordsync dump-only RPO leg (`discordsync-db-backup` 02:30 gzipped sqlite `.backup` → `/mnt/pool/backups/discordsync`, registered in backup-coordination + restic — with Turso plan-blocked it is the event store's only backup once it leaves `@`). All five entries are `cow = true` (2026-09-21 measurement: nodatacow worthless on TLC, checksums free). DynamicUser services mount the REAL `/var/lib/private/<name>` dir behind the public symlink. Postgres wave (ratified, `cow = false`) rides the same vehicle via the script's generic `<name> <dataDir> <unit>` form.
