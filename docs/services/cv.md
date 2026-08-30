# CV — Service Runbook

Resume/CV generator (`cv serve`, Go + Typst) from the private
[CV repo](https://github.com/LarsArtmann/CV). Public site at
**https://cv.home.lan**.

## Layout

| Concern           | Where                                                                                         |
| ----------------- | --------------------------------------------------------------------------------------------- |
| Service           | `cv-server.service` (upstream module: CV repo `nix/nixos-module.nix`)                         |
| SystemNix wrapper | `modules/nixos/services/cv.nix`                                                               |
| Port              | `8098` (`lib/ports.nix`), loopback only; Caddy `protectedVHost` front                         |
| State dir         | `/var/lib/cv` (owned `cv:cv`, 0700)                                                           |
| Config            | generated `config.yaml` symlinked into the state dir from `services.cv-server.settings`       |
| Secrets           | sops `platforms/nixos/secrets/cv.yaml` → template `cv-env` (`CV_API_KEY`), owned `cv:cv` 0400 |
| Persistence       | `/var/lib/cv/data/pipeline.sqlite` (event store; `pipeline.event_store_driver=sqlite`)        |
| Backups           | `/mnt/pool/backups/cv/pipeline-<ts>.sqlite`, nightly 03:17 (`cv-backup.timer`)                |
| Scan automation    | `cv-scan.timer` every 6h (:23): POST `/api/pipeline/scan` + `/evaluate-tracked` (X-API-Key)    |
| Monitoring        | Gatus: `CV` (liveness 60s), `CV Page Renders` (/cv HTML 5m), `CV PDF Export` (%PDF body 5m)   |
| Tracing           | OTLP-HTTP → localhost:4318, service `cv-application` (SigNoz)                                 |
| Upstream pin      | flake input `cv` (rev-locked, git+ssh; no `follows` — vendorHash stability)                   |

## State dir contract

- `assets/` and the 8 `data/<content>/` subdirs are **wiped and re-copied**
  from the package on every start (ExecStartPre `cv-server-content-sync`).
  Never store anything mutable there.
- `data/` ROOT files (`pipeline.sqlite`, `dead-portals.json`,
  `graphrag.sqlite`) are runtime-mutable and never touched by the sync.

## Continuous funnel automation

`cv-scan.timer` fires every 6 hours and drives the server over HTTP with
the same `CV_API_KEY` the server reads (sops `cv-env` template):

1. `POST /api/pipeline/scan` — empty body scans ALL portals from
   `pipeline.portals` in `cv.nix` settings (the generated config.yaml IS
   the whole config — keep that list in sync with the CV repo's
   config.yaml). Every newly discovered job is evaluated inline (score +
   recommendation + ANÜ/eligibility blockers land in the same pass).
2. `POST /api/pipeline/evaluate-tracked` — no-force pass that only picks
   up rows whose scan-time evaluation failed (idempotent otherwise).

Both endpoints are async + 409-guarded, so an overlap with a
dashboard-triggered run is harmless. Failures (non-200/409, e.g. a wrong
key after rotation) fail the unit → onFailure alert.

**Forced re-scoring is manual** — when criteria change (keywords, CV data,
blockers like the 2026-08-29 eligibility axis), run once:

```bash
key=$(sudo cat /run/secrets/cv-env 2>/dev/null | cut -d= -f2)   # or read from sops
curl -s -X POST -H "X-API-Key: $key" -H 'Content-Type: application/json' \
  -d '{"force":true,"workers":8}' http://localhost:8098/api/pipeline/evaluate-tracked
```

A periodic force pass is deliberately NOT timer-driven: it appends one
`job.evaluated` event per tracked application per run even when verdicts
are identical — pure event-store bloat.

**Deploy-order dependency**: the timer's POSTs need a CV package whose
server skips CSRF for `X-API-Key`-bearing requests (CV repo 2026-08-29+).
Older packages answer 403 `csrf_invalid`. Bump the `cv` flake input in the
same deploy that activates this timer.

## Common operations

```bash
systemctl status cv-server
journalctl -u cv-server -f

# After editing settings in cv.nix (or any new CV rev):
nix flake lock --update-input cv   # only for upstream revs
nix run .#deploy                   # switch restarts changed units

# Verify (no root needed):
curl -s http://localhost:8098/health/live   # {"status":"pass","version":"<rev>",...}
curl -s http://localhost:8098/export/pdf | head -c8   # %PDF-1.7

# Trigger a funnel scan out-of-band (same path the 6h timer uses):
systemctl start cv-scan.service && journalctl -u cv-scan -n 5
journalctl -u cv-server --since "-10 min" | grep -E 'scan completed|bulk evaluation'
```

## Incident playbook

- **`/export/pdf` 404 while `/cv` renders**: the typst template
  (`/var/lib/cv/assets/typst/cv.typ`) went missing under the running
  process (happened 2026-08-27). `systemctl restart cv-server` — the
  content sync re-copies assets. The `CV PDF Export` Gatus check catches
  this class; the HTML check cannot.
- **`concurrency conflict: app <id> version N` on pipeline writes**: a
  CLI process opened the same sqlite store. One writer per file — stop
  one, or drive writes through HTTP.
- **`StoreLeaseHeldError`**: another process holds
  `<dsn>.lease`. Find the pid in the error; stop that process first.

## Pending root-gated proofs (paste into ONE root shell)

Open claims from the 2026-08-27 deployment that a non-root session cannot
verify — `/var/lib/cv` is 0700 `cv:cv` and unit control is root-gated. Run
as root on evo-x2; each block is independent, failures are informative, not
destructive.

```bash
# 1. Persistence: the event store actually exists on disk (not inferential)
ls -la /var/lib/cv/data/

# 2. First REAL backup artifact (the machinery has never produced a .sqlite)
systemctl start cv-backup
ls -la /mnt/pool/backups/cv/
journalctl -u cv-backup --since "-5 min" --no-pager

# 3. Asset-vanishing incident forensics (2026-08-27, ~10:15–10:45 window):
#    the journal names exactly what vanished; journalctl is NOT volatile
journalctl -u cv-server --since "2026-08-27 10:15" --until "2026-08-27 11:00" --no-pager

# 4. Restart-drill persistence proof (the actual product claim):
#    a tracked application written via HTTP survives a full restart.
curl -s http://localhost:8098/health/live        # baseline healthy
systemctl restart cv-server && sleep 8
curl -s http://localhost:8098/health/live        # back up, same version
#    then compare tracked applications before/after via the dashboard
#    (or POST a scan event first if the store is still empty).

# 5. First PDF-export RSS under MemoryMax=1G / GOMEMLIMIT=768MiB
curl -s -o /dev/null http://localhost:8098/export/pdf
systemctl status cv-server --no-pager | grep -E 'Memory|Tasks'
journalctl -u cv-server --since "-10 min" | grep -iE 'oom|killed|memory'
```

After the 03:17 timer (no root needed to ASK, root to answer): confirm
`pipeline-*.sqlite` exists in `/mnt/pool/backups/cv` and that no
backup-coordination staleness alert fired for the empty-dir era. Also
observe one full Gatus `CV PDF Export` cycle (5m) and the
`cv-application` service in SigNoz traces (traces.home.lan, last 1h) —
both were config-level-verified only.

## Restore drill

```bash
systemctl stop cv-server
cp /mnt/pool/backups/cv/pipeline-<ts>.sqlite /var/lib/cv/data/pipeline.sqlite
chown cv:cv /var/lib/cv/data/pipeline.sqlite && chmod 600 /var/lib/cv/data/pipeline.sqlite
systemctl start cv-server   # rehydration replays events, no snapshot needed
```

## Rotating `CV_API_KEY`

1. Generate: `openssl rand -hex 32`.
2. Edit the value in `platforms/nixos/secrets/cv.yaml` via sops
   (`--input-type yaml`!), keeping the key name `cv_api_key`.
3. Deploy — `restartUnits` on the `cv-env` template rolls the service.
4. Present as `X-API-Key` on guarded routes (`/api/pipeline/*`, `/metrics`, …).

## Deliberate non-features

- **`cv` CLI not on PATH**: the sqlite event store takes one writer per
  file; CLI + server on the same DSN fail-fast (lease) by design. Server
  writes go through HTTP; bulk CLI work happens in the dev checkout.
- **GraphRAG/CRM/AI coaching off**: 503-with-hint until their config keys
  are set (each would need its own sops entry).
