# CV — Service Runbook

Resume/CV generator (`cv serve`, Go + Typst) from the private
[CV repo](https://github.com/LarsArtmann/CV). Public site at
**https://cv.home.lan**.

## Layout

| Concern          | Where                                                                |
| ---------------- | -------------------------------------------------------------------- |
| Service          | `cv-server.service` (upstream module: CV repo `nix/nixos-module.nix`) |
| SystemNix wrapper| `modules/nixos/services/cv.nix`                                      |
| Port             | `8098` (`lib/ports.nix`), loopback only; Caddy `protectedVHost` front |
| State dir        | `/var/lib/cv` (owned `cv:cv`, 0700)                                  |
| Config           | generated `config.yaml` symlinked into the state dir from `services.cv-server.settings` |
| Secrets          | sops `platforms/nixos/secrets/cv.yaml` → template `cv-env` (`CV_API_KEY`), owned `cv:cv` 0400 |
| Persistence      | `/var/lib/cv/data/pipeline.sqlite` (event store; `pipeline.event_store_driver=sqlite`) |
| Backups          | `/mnt/pool/backups/cv/pipeline-<ts>.sqlite`, nightly 03:17 (`cv-backup.timer`) |
| Monitoring       | Gatus: `CV` (liveness 60s), `CV Page Renders` (/cv HTML 5m), `CV PDF Export` (%PDF body 5m) |
| Tracing          | OTLP-HTTP → localhost:4318, service `cv-application` (SigNoz)        |
| Upstream pin     | flake input `cv` (rev-locked, git+ssh; no `follows` — vendorHash stability) |

## State dir contract

- `assets/` and the 8 `data/<content>/` subdirs are **wiped and re-copied**
  from the package on every start (ExecStartPre `cv-server-content-sync`).
  Never store anything mutable there.
- `data/` ROOT files (`pipeline.sqlite`, `dead-portals.json`,
  `graphrag.sqlite`) are runtime-mutable and never touched by the sync.

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
