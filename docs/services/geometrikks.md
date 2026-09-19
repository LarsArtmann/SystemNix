# GeoMetrikks (geo.home.lan)

Reverse-proxy access-log ingestion + geo-location analytics: tails every Caddy
per-vhost JSON access log, geolocates each request (MaxMind GeoLite2), stores
geo-events in TimescaleDB, and serves a live MapLibre world map + searchable
log database. Upstream: github:GilbN/geometrikks (Docker-only).

## Architecture

- **Module**: `modules/nixos/services/geometrikks.nix` — `mkDockerService`
  pattern (manifest.nix is the reference): `geometrikks.service` runs
  `docker compose up` with two containers (`app` + `timescale_db`), sops env
  template, nightly pg_dump to the pool.
- **Port**: `127.0.0.1:8102` (`ports.geometrikks` in `lib/ports.nix`); the app
  listens on 8000 inside the container.
- **vHost**: `geo.home.lan`, Layer 2 `protectedVHost` (oauth2-proxy gates
  EXTERNAL access; LAN hits the app directly). The app ALSO has its own
  single-admin login (`APP_ADMIN_USER`/`APP_ADMIN_PASSWORD`) — external users
  pass both gates, LAN users only the app login.
- **Logs**: Caddy's per-vhost `access-<host>.log` files (nixpkgs caddy module
  default sinks — file output means Caddy's default encoder is **JSON** per
  caddyserver.com/docs/caddyfile/directives/log) are bind-mounted read-only at
  `/var/log/access` inside the container. `LOGPARSER_LOG_PATHS` is a JSON list
  derived at EVAL time from `config.services.caddy.virtualHosts` (+ the global
  `access.log`) — new services are tracked automatically. Filename rule
  replicates vhost-options.nix: `/` and ` ` -> `_` (hence
  `access-https:__*.home.lan.log`).
- **Container user**: `PUID=0` (root in-container). Caddy writes logs
  `caddy:caddy 0600` — only host root can read them, and the read-only bind
  mount contains the blast radius (same trust level as every other
  mkDockerService container on this host; PUID=0 also matches the upstream
  default flow of chown+drop in the entrypoint).
- **DB**: `timescale/timescaledb-ha:pg18` (digest-pinned in `lib/images.nix`)
  with upstream's tuned worker pool (`max_background_workers=40`,
  `max_worker_processes=51` — ~32 TimescaleDB background jobs + CAGG refreshes
  fire on the same tick). Data in named volume `geometrikks_timescale_data`
  (Docker data-root on /data). App state in `geometrikks_geoip_data`.
- **X-Forwarded-For**: the compose `frontend` network is subnet-pinned
  `172.32.0.0/24` (outside Docker's default pool) and
  `APP_TRUSTED_PROXIES=172.32.0.0/24`, so login logging sees real client IPs
  through the Caddy hop (userland-proxy is off, DNAT preserves Caddy's source
  = the bridge gateway).

## Monitoring

- Gatus "GeoMetrikks" (`/health/ready`, registry check — liveness only; the
  ingestion is verified via the UI's live tail).
- `geometrikks.service` in system-health `monitoredServices` (registry
  `monitored = true` — state/restart-churn metrics).
- Homepage tile: "GeoMetrikks" (Infrastructure group, `mdi-earth`).
- Backup: nightly 05:15 pg_dump -> `/mnt/pool/backups/geometrikks/*.sql`
  (14d retention), registered in backup-coordination (maxAge 31h).
  NOTE: restore needs TimescaleDB present (same image; plain pg_dump of
  hypertables is restoreable into a timescaledb-enabled cluster).

## Login + secrets

- Admin password + DB password + MaxMind/CARTO keys live in sops
  `platforms/nixos/secrets/geometrikks.yaml` (rendered into the root-owned
  `geometrikks-env` template; rotation restarts `geometrikks.service`).
- Retrieve the admin password (Sops + Age one-liner, as your user, from the
  repo root):
  `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops -d platforms/nixos/secrets/geometrikks.yaml`
- Username: `admin`.

## Go-live steps (user-gated)

1. **MaxMind GeoLite2** (free): sign up at maxmind.com/en/geolite2/signup,
   then paste `MAXMINDDB_USER_ID` + `MAXMINDDB_LICENSE_KEY` into the sops file
   (`sops platforms/nixos/secrets/geometrikks.yaml` with the same one-liner)
   and `sudo systemctl restart geometrikks`. Until then the app runs
   geo-DEGRADED (UI banner, no map pins) — ingestion + log search work.
2. **CARTO basemap key** (optional, free tier at carto.com/basemaps/apikey):
   paste `MAP_CARTO_API_KEY`. Keyless tiles work today but CARTO may cut them
   off at any time.
3. Log in at https://geo.home.lan with `admin` + the sops password; verify the
   map populates within a minute (gatus probes every service every 30s, so
   events flow immediately).

## Gotchas

- **The app REFUSES to start without `APP_ADMIN_PASSWORD`** (upstream design)
  — the sops key must never be empty.
- **`v0.16.0` is not a GHCR tag** — tags are unprefixed (`0.16.0`); the
  release tag has the `v`, the image tag does not (`v0.16.0` answers
  "manifest unknown").
- **TimeoutStartSec=15min** on the unit: first-ever start pulls the ~2.5 GB
  timescaledb-ha image; the global 3min default would kill it. Both images
  were pre-pulled at setup, so this only matters on a cold cache.
- Rotated Caddy logs (`*.log.gz`) are NOT backfilled; only live files are
  tailed. Historical import exists upstream (`litestar import-logs`) but is
  not wired here.
- The Banned-IPs/CrowdSec views are inert (no CrowdSec on this host).
