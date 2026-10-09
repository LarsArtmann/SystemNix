# pbx-backup-pull — Pull-Side PBX Backup (rsync snapshots onto the pool)

**Module:** `modules/nixos/services/pbx-backup-pull.nix` (`services.pbx-backup-pull`, enabled in `platforms/nixos/system/configuration.nix`)
**Source of truth for the script:** the pbx-artmann repo (`backups/evo-x2/pbx-backup-pull.sh` — embedded verbatim; that repo's `internal/backuppull` Go tests pin its `--check` contract)
**Deployed:** 2026-10-02 (first enable; the first pull fires immediately on the enabling deploy — `Persistent=true`)

---

## What it is

The evo-x2 leg of the pbx.artmann.tech backup doctrine: every 6 hours a
system unit running as the primary user sshes to `root@pbx.artmann.tech`
(the PBX's ONLY authorized root key is `lars@evo-x2` — no new credentials
exist anywhere for this) and rsyncs the PBX's `/var/lib/backup-staging/`
into a NEW timestamped dir under `/mnt/pool/backups/pbx/`.

```
pbx (stages nightly: CDR, voicemail db, webhook log, secrets,
     recordings, stalwart-store.tgz, netbird-mgmt.tgz, dex.db)
        │  ssh+rsync pull (BatchMode, lars identity), every 6h at :15
        ▼
/mnt/pool/backups/pbx/<UTC-stamp>/<stamp>/…   (new dir per run,
     newest 56 kept ≈ 2 weeks)
```

PULL direction by design: the PBX holds zero credentials for this
machine — a compromised PBX cannot delete or corrupt received snapshots.
Machine recovery for the PBX is a flake rebuild, not a restore; the
quarterly restore drill lives in the pbx-artmann repo
(`docs/runbooks/backup-restore.md`).

## Units

| Unit                      | Shape                                                           |
| ------------------------- | --------------------------------------------------------------- |
| `pbx-backup-pull.service` | oneshot, `User=lars`, `RequiresMountsFor=/mnt/pool`, 20min cap  |
| `pbx-backup-pull.timer`   | `OnCalendar=*-*-* 00,06,12,18:15:00`, `Persistent=true`, ±5m    |
| tmpfiles rule             | `d /mnt/pool/backups/pbx 0755 lars users` (boot + every deploy) |

Monitoring: the module's integration entry declares the
`backup-coordination` freshness row (`maxAgeHours = 25`) — Gatus pages
Discord when the pool copy is more than a day stale (four skipped
windows). No port, no vHost, no DNS presence.

## Operations

```console
# pre-flight (pulls nothing): dest mount + ssh reachability + staging content
sudo /run/current-system/sw/bin/pbx-backup-pull --check

# manual pull + result
sudo systemctl start pbx-backup-pull.service
journalctl -u pbx-backup-pull.service -n 20

# newest snapshots / restore drill short form
ls -1t /mnt/pool/backups/pbx | head -3
```

## Traps

- **Never point `PBX_BACKUP_DEST` off the pool mount** — the `--check`
  pre-flight and the unit's `RequiresMountsFor` both guard the
  land-on-root-fs class (the historical `/pool` incident), but a
  same-fs override silently defeats both.
- **The unit fails loudly on ssh problems** (BatchMode cannot prompt):
  an unknown host key or a rotated `lars@evo-x2` key shows as a failed
  unit + a stale-backup Gatus page within 25h — do not silence the
  alert, fix the key.
- **First-enable deploy runs the first pull synchronously** (Persistent
  timer): a multi-hundred-MB backlog (many staged snapshots + all
  recordings) can hold activation ~minutes — the 20min TimeoutStartSec
  is the ceiling, and the timer self-heals on the next window anyway.
