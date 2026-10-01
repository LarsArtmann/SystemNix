# twenty (CRM, Docker Compose)

**Service:** `services.twenty` — `modules/nixos/services/twenty.nix` via `mkDockerService` (`lib/docker.nix`). Port 3200 (`lib/ports.nix`), loopback; compose stack = server + worker + postgres sidecar + redis. URL: `crm.<domain>` (**Layer 2 protected** — Twenty's native OIDC/SAML is billing-gated upstream; workspace config is GraphQL/UI, not env). DNS `crm`.

Images are digest-relevant: `twenty` (app), `twenty-postgres`, `twenty-redis` in `lib/images.nix`; the app image is the one entry still WITHOUT a digest pin (decision row open). **A v2.32.0 → v2.43.0 bump is queued (docs/todo/services.md) — DB-backed app: read the 11 minors of release notes for breaking migrations BEFORE bumping.**

## What it serves

| Route      | Auth                          | What                                        |
| ---------- | ----------------------------- | ------------------------------------------- |
| `/`        | forward-auth / open LAN       | CRM web app                                 |
| `/healthz` | none (loopback)               | Compose healthcheck + Gatus "Twenty CRM"    |

## Ops

- **Compose shape** — server 1G (`NODE_OPTIONS=--max-old-space-size=768`), worker 2G (`--max-old-space-size=1536` — the cap keeps V8 GC ahead of the limit; without it the worker was the #1 systemd-oomd target), db 2G, redis 256m (`noeviction`). Every service `restart = "always"` (a DB sidecar without it stays dead after a docker restart — the manifest incident). Worker starts only after the server reports healthy (`depends_on.service_healthy`) — a temporarily "Created" worker is normal during boot.
- **Secrets (sops `platforms/nixos/secrets/twenty.yaml`)** — `twenty_app_secret`, `twenty_db_password` → `twenty-env` template (root-owned 0400; EnvironmentFile of the compose unit). Rotation restarts `twenty.service`.
- **Unit flavor is DETACHED** — the unit runs `docker compose up -d`; it rides through docker daemon restarts (dozzle's attach flavor does not — see its runbook).
- **`twenty-fix-collation`** (oneshot after twenty.service) — `ALTER DATABASE … REFRESH COLLATION VERSION` for every DB after the postgres sidecar image moves (silences the collation-version warnings); idempotent.
- **Backup** — 02:00 nightly via the mkDockerService `backup` leg: `docker-compose exec db pg_dump` → `/mnt/pool/backups/twenty/*.sql`, 30d retention, mount-gated, registered in backup-coordination (maxAge 31h). Live DB is the Docker volume on `/data/docker` (QLC) — the pool dump is the safety net.
- **Monitoring** — Gatus "Twenty CRM" (`/healthz`, registry check) + Homepage tile `crm`.

## Related

- [twenty-POST-SETUP.md](./twenty-POST-SETUP.md) + [twenty-FREELANCE-PROJECTS.md](./twenty-FREELANCE-PROJECTS.md) — workspace content docs
- [docs/agents/systemd.md#docker--containers](../agents/systemd.md#docker--containers) — mkDockerService semantics, oomd/mem_limit doctrine
- [docs/agents/storage.md](../agents/storage.md) — pool backup tier
