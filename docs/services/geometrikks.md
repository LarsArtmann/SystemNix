# GeoMetrikks (geo.home.lan)

Reverse-proxy access-log ingestion + geo-location analytics: tails every Caddy
per-vhost JSON access log, geolocates each request (MaxMind GeoLite2), stores
geo-events in TimescaleDB (+PostGIS), and serves a live MapLibre world map +
searchable log database. Upstream: github:GilbN/geometrikks.
**Native Nix service since 2026-09-29** (Docker→Nix migration; the former
`mkDockerService` deployment with the timescaledb-ha sidecar is gone — plan:
`docs/planning/2026-09-29_21-41_GEOMETRIKKS-NATIVE-NIX-MIGRATION.md`).

## Architecture

- **Package**: `pkgs/geometrikks.nix` — builds from source at the pinned tag
  (v0.19.0):
  - Python venv via **uv2nix** from `uv.lock` (wheel-preferred; two legacy
    sdists get setuptools injected via `resolveBuildSystem`)
  - Frontend via a hand-rolled **bun FOD** (nixpkgs has no fetchBunDeps): the
    FOD tars `node_modules` as ONE deterministic file — bun rewrites
    `#!/usr/bin/env X` shebangs to sandbox store paths (playwright-core .sh
    class) and some packages ship flake.lock store pins; both are scrubbed
    inside the FOD (a directory output trips the FOD no-store-refs check even
    with clean bytes — the tar sidesteps it), then `bun run build` runs the
    vite build with `patchShebangs`-ed bins
  - Layout mirrors the upstream Dockerfile: `$out/bin/geometrikks-{server,cli}`
    wrappers + `$out/share/geometrikks/{public,migrations,alembic.ini}`
  - `nix build .#geometrikks` for dep-drift probing; bumping = new tag + 2
    hashes (src, bunDeps) via the got-hash loop
- **Module**: `modules/nixos/services/geometrikks.nix` — native
  `geometrikks.service` (same unit name the docker wrapper had → the flip was
  atomic). ExecStartPre stamp-gates a copy of `public/` + `migrations/` +
  `alembic.ini` into `/var/lib/geometrikks` (the app writes `.litestar.json`
  and logs there; alembic resolves `migrations/` relative to CWD).
- **Port**: `127.0.0.1:8102` (`ports.geometrikks`); the litestar/granian
  server binds loopback via the wrapper's `GEOMETRIKKS_HOST/PORT`.
- **vHost**: `geo.home.lan`, **Layer 1 plain** `reverse_proxy` — SSO is native
  Pocket ID OIDC (auth-code + PKCE, confidential client). Behind
  protectedVHost it would double-auth (doctrine).
- **SSO**: `services.integration.geometrikks.oidc` registers the client;
  `geometrikks-oidc-env` bridges the provisioner-owned secret
  (`LoadCredential` as PID 1 → `/var/lib/geometrikks-oidc/oidc.env`, written
  with ALL OIDC vars together). Allow-list: the configured
  `services.geometrikks.oidc.allowedUsers` emails PLUS every enabled Pocket
  ID user's subject id, auto-resolved at bridge time by the unit's
  `+`ExecStartPre `geometrikks-oidc-subs` (reads Pocket ID's SQLite,
  stages `/var/lib/geometrikks-oidc/allowed-subs`). The sub append is
  load-bearing: upstream matches an email only when the provider sends
  `email_verified: true`, and Pocket ID's per-user `email_verified` defaults
  to FALSE — the email-only list rejected every login (live 2026-09-30).
  New/removed/renamed Pocket ID users converge on the next bridge run (boot
  - deploy). The `admin` password login stays as break-glass while
    `APP_ADMIN_PASSWORD` is set (provider-down fallback).
- **DB**: the host's **shared PostgreSQL cluster** (PG17) with
  `timescaledb` + `postgis` extensions (`services.postgresql.extensions`),
  `shared_preload_libraries += timescaledb`, `max_worker_processes = 48`
  (global headroom). `geometrikks-db-provision` (User=postgres, peer auth)
  sets the role password from sops, pre-creates both extensions
  (superuser-only) and applies per-DB tuning
  (`timescaledb.max_background_workers=32`, `max_parallel_workers=8` —
  upstream's container values 40/8/51 minus the POSTMASTER-level part).
  App connects via TCP 127.0.0.1 + the sops `geometrikks_db_password`.
- **Alembic**: `DB_MIGRATE_ON_STARTUP=true` (upstream default) — the app
  migrates at startup in a worker thread; `DB_STARTUP_WAIT_SECONDS=60` rides
  out a postgres boot race, degraded-then-recover otherwise.
- **Logs**: Caddy's per-vhost `access-<host>.log` files read at their HOST
  paths (`/var/log/caddy/...`) — the unit carries `AmbientCapabilities` +
  `CapabilityBoundingSet = CAP_DAC_READ_SEARCH` (dir `0750 caddy:caddy`,
  files `0600`; AmbientCapabilities is what GRANTS the cap to the non-root
  unit — BoundingSet alone only limits, the 2026-09-06 mail-relay lesson;
  missing it meant zero ingested events since the 2026-09-29 flip, fixed
  2026-10-07) and reads them read-only under `ProtectSystem=full`. `LOGPARSER_LOG_PATHS`
  is a JSON list derived at EVAL time from
  `config.services.caddy.virtualHosts` — new services are tracked
  automatically. The tailer polls (`LOGPARSER_POLL_INTERVAL=1.0`).
- **X-Forwarded-For**: `APP_TRUSTED_PROXIES=127.0.0.1` (Caddy proxies from
  loopback — README's same-host nginx guidance).

## Migration notes (from the Docker era)

- **No data migration was needed**: the docker DB was empty (the service ran
  geo-degraded since bring-up — ingestion never starts without a GeoLite2
  database). The schema is created fresh by alembic on first start.
- The docker named volumes (`geometrikks_geometrikks_timescale_data`,
  `geometrikks_geoip_data` on /data/docker) are retained for ≥48h green as
  the rollback window; removal is manual:
  `docker volume rm geometrikks_geometrikks_timescale_data geometrikks_geometrikks_geoip_data`
- Rollback = revert the flip commit + redeploy (the docker module and image
  pins return; containers re-create from the volumes).

## Monitoring

- Gatus "GeoMetrikks" (`/health/ready`, registry check — liveness only; the
  ingestion is verified via the UI's live tail).
- `geometrikks.service` in system-health `monitoredServices` (registry
  `monitored = true` — state/restart-churn metrics).
- Homepage tile: "GeoMetrikks" (Infrastructure group, `mdi-earth`).
- Backup: nightly 05:15 `geometrikks-db-backup` pg_dump (peer auth as
  postgres) -> `/mnt/pool/backups/geometrikks/*.sql` (14d retention),
  registered in backup-coordination (maxAge 31h). Restore into any
  timescaledb+postgis-enabled cluster (`CREATE EXTENSION` first, then
  `psql -f dump.sql`).

## Login + secrets

- Admin password + DB password + MaxMind/CARTO keys live in sops
  `platforms/nixos/secrets/geometrikks.yaml` (rendered into the root-owned
  `geometrikks-env` template; rotation restarts `geometrikks.service`).
- Retrieve the admin password (Sops + Age one-liner, as your user, from the
  repo root):
  `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops -d platforms/nixos/secrets/geometrikks.yaml`
- SSO login: "Sign in with Pocket ID" button (every enabled Pocket ID user
  passes the allow-list via its auto-resolved subject id; the configured
  email entries are the verified-email fallback).
- OIDC lockout fallback: the `admin` + sops password login stays available.

## Go-live steps (user-gated)

1. **First SSO login**: https://geo.home.lan → "Sign in with Pocket ID" →
   passkey → map. The subject-id auto-resolve (`geometrikks-oidc-subs`)
   lets every enabled Pocket ID user pass the allow-list; if a login is
   STILL rejected, check `journalctl -u geometrikks` for
   `reason=not_allowed` and compare the logged subject against
   `/var/lib/geometrikks-oidc/allowed-subs` — a stale file means the bridge
   has not re-run since the Pocket ID change (`sudo systemctl restart
   geometrikks-oidc-env geometrikks` converges it).
2. **MaxMind GeoLite2** (free): sign up at maxmind.com/en/geolite2/signup,
   then paste `MAXMINDDB_USER_ID` + `MAXMINDDB_LICENSE_KEY` into the sops file
   (`sops platforms/nixos/secrets/geometrikks.yaml` with the same one-liner)
   and `sudo systemctl restart geometrikks`. Until then ingestion is DEAD —
   the journal shows `Cannot start ingestion: failed to create GeoIP2 reader
   ... GeoLite2-City.mmdb: FileNotFoundError` (live 2026-10-01) — so the map
   AND the log DB stay empty; the earlier "geo-degraded, ingestion + log
   search still work" claim was falsified live.
3. **CARTO basemap key** (optional, free tier at carto.com/basemaps/apikey):
   paste `MAP_CARTO_API_KEY`. Keyless tiles work today but CARTO may cut them
   off at any time.

## Gotchas

- **The app REFUSES to start without `APP_ADMIN_PASSWORD` unless OIDC is
  configured** (upstream design) — the sops key must never be empty.
- **Bun FOD scrub is load-bearing**: bun silently rewrites `#!/usr/bin/env`
  shebangs of package scripts to PATH-resolved interpreters. Inside the FOD
  sandbox that means /nix/store paths → "fixed-output derivations must not
  reference store paths". The scrub restores portable shebangs and a
  self-test fails the FOD if any store path remains (rc-gated so a broken
  grep can't phantom-green it).
- **Phase shells are NOT bash** — `read -d` and process substitution broke
  here during bring-up; keep installPhase helpers POSIX (`find -exec sh -c`).
- Rotated Caddy logs (`*.log.gz`) are NOT backfilled; only live files are
  tailed. Historical import exists upstream:
  `sudo -u geometrikks env $(systemctl show geometrikks -p Environment | ...) geometrikks-cli import-logs <file>`
  (or run `geometrikks-cli` with the unit's env from a root shell).
- The Banned-IPs/CrowdSec views are inert (no CrowdSec on this host).
- Upstream ships no license file — the package declares `licenses.unfree`
  (personal-use posture).

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### GeoMetrikks (access-log geo analytics, NATIVE since 2026-09-29)

**Module:** `modules/nixos/services/geometrikks.nix` (`services.geometrikks`) — **fully native Nix service** (the 2026-09-29 Docker→Nix migration; the mkDockerService deployment + timescaledb-ha sidecar are GONE). Tails every Caddy per-vhost JSON access log, geolocates via MaxMind GeoLite2, stores geo-events in TimescaleDB+PostGIS on the **shared PG17 cluster**, UI at `geo.home.lan` (**Layer 1 plain** vHost — native Pocket ID OIDC, auth-code + PKCE), port 8102, DNS `geo`. Plan: `docs/planning/2026-09-29_21-41_GEOMETRIKKS-NATIVE-NIX-MIGRATION.md`; runbook: `docs/services/geometrikks.md`.

- **Package** `pkgs/geometrikks.nix` (pinned tag v0.19.0, exposed as `.#geometrikks`): Python venv via **uv2nix** (inputs `uv2nix`/`pyproject-nix`/`pyproject-build-systems` at `pyproject-nix/*`; wheel-preferred — geohash2/ipy legacy sdists need `resolveBuildSystem` setuptools injection) + **bun FOD** (nixpkgs has NO fetchBunDeps): bun rewrites `#!/usr/bin/env` shebangs to sandbox store paths (playwright-core .sh class) and packages ship flake.lock store pins — the FOD scrubs both and self-tests rc-gated (a broken grep cannot phantom-green it); the FOD outputs a DETERMINISTIC TAR (a directory output tripped the FOD no-store-refs check even with clean bytes). Frontend build patchShebangs the bins (sandbox has no /usr/bin/env). Bump = tag + 2 hashes.
- **Runtime layout mirrors the Dockerfile**: ExecStartPre stamp-gated copy of `share/geometrikks/{public,migrations,alembic.ini}` into `/var/lib/geometrikks` (app writes `.litestar.json` + logs in CWD; alembic resolves `migrations/` relative to CWD; `DB_MIGRATE_ON_STARTUP=true` runs migrations in-app at startup).
- **Shared-cluster DB wiring**: `services.postgresql.extensions = ps: [timescaledb timescaledb_toolkit postgis]` (extraPlugins was RENAMED to extensions) + `shared_preload_libraries += timescaledb` + global `max_worker_processes = 48`; `geometrikks-db-provision` (User=postgres, peer auth; provisioner-loop converged) sets the role password from sops (charset-guarded inline literal — psql 17 does NOT interpolate :'var' in -c), pre-creates ALL THREE extensions (superuser-only; the alembic migration's `CREATE EXTENSION postgis` and server/timescale.py expect them) and applies per-DB tuning (`timescaledb.max_background_workers=32` — upstream's POSTMASTER-level 51 became global headroom instead). One postgres restart on the flip deploy bounced paperless/immich/miniflux once — expected, self-retried.
- **`timescaledb_toolkit` is REQUIRED and lives ONLY under `postgresql.pkgs`** (fixed + deployed 2026-09-30, system-804): app 0.19.0's startup migration runs `CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit CASCADE`; the Docker-era `timescaledb-ha` image bundled the toolkit, native nixpkgs does NOT (absent at top level, present as `postgresql.pkgs.timescaledb_toolkit` = 1.23.0, a pgrx/cargo build — one-time heavy FOD, now pre-built in the store so future deploys substitute). Its absence was the 09-29/30 outage: worker dies at migration (`CREATE EXTENSION` fails) → granian exits → unit failed since the native migration. The package-level `extensions` wiring is the LOAD-BEARING fix — the toolkit control file carries **`trusted = true`**, so once it ships in the PG bundle the DB-owner app's own startup migration self-creates the extension (live-proven 05:50:49: app started green); the provision unit's explicit `CREATE EXTENSION` line stays as belt-and-braces for fresh DBs.
- **OIDC secret bridge**: `geometrikks-oidc-env` (ConditionPathExists on `/var/lib/pocket-id/client-secrets/geometrikks` — the paperless first-deploy chicken-and-egg pattern; wantedBy=geometrikks.service → INDIRECT unit, deploy.sh carries a dedicated is-active-gated block on the DAEMON restarting bridge+daemon). Writes ALL OIDC vars together into `/var/lib/geometrikks-oidc/oidc.env` (LoadCredential as PID 1; all-or-none — the browser-history Validate() crash-loop lesson). Allow-list: `services.geometrikks.oidc.allowedUsers` (REQUIRED non-empty by upstream) PLUS every enabled Pocket ID user's subject id, auto-resolved at bridge time by the unit's `+`ExecStartPre `geometrikks-oidc-subs` (miniflux phase-1 pattern: reads Pocket ID's sqlite `users` table, charset-guards, stages `/var/lib/geometrikks-oidc/allowed-subs`). WHY the sub append is load-bearing: upstream matches an email ONLY when the provider sends `email_verified: true` (strict boolean — a string "true" does not count), and Pocket ID's email_verified is a PER-USER column DEFAULTING TO FALSE (migration 20260109090200; set only by its SMTP verification flow or an admin toggle) — the email-only allow list rejected every login (live 2026-09-30: `login_failed reason=not_allowed` with the email claim present; token+userinfo had succeeded). Resolver failure is FATAL (exit 1, OnFailure) because email-only = every login rejected; resolver retries 5×2s for sqlite transients. Convergence: user add/remove/rename lands on the next bridge run (boot + deploy.sh's bridge+daemon block).
- **Log tailing is eval-derived** (unchanged): `LOGPARSER_LOG_PATHS` from `config.services.caddy.virtualHosts` (+ global `access.log`), filenames `/`+space→`_`. Host paths now (`/var/log/caddy/...`); the unit reads the 0600 `caddy:caddy` files via `CAP_DAC_READ_SEARCH` (cv-backup precedent) — the docker era needed a root container for exactly this. Polling tailer (1s), no inotify. `APP_TRUSTED_PROXIES=127.0.0.1` (Caddy same-host).
- **No data migration was needed**: the docker DB was EMPTY (geo-degraded since bring-up — ingestion never starts without a GeoLite2 database; MaxMind keys still user-gated). Docker volumes retained ≥48h green as rollback (removal todo in docs/todo/services.md); rollback = revert commit + redeploy.
- **Phase shells are NOT bash**: `read -d` and `< <(...)` broke inside the FOD installPhase during bring-up — keep installPhase helpers POSIX (`find -exec sh -c`).
- App refuses to start without `APP_ADMIN_PASSWORD` unless OIDC configured (upstream) — sops key never empty; password login stays as break-glass. MaxMind/CARTO ship EMPTY (geo-degraded = banner, no crash). Backup: nightly 05:15 native pg_dump (peer auth) → `/mnt/pool/backups/geometrikks`, 14d retention; restore into any timescaledb+postgis cluster. Upstream has no license file → `licenses.unfree`.
