# Miniflux (RSS Reader)

`rss.home.lan` — minimalist self-hosted RSS reader (Go + PostgreSQL), Layer 1
native OIDC via Pocket ID. Wraps the nixpkgs `services.miniflux` module
(`modules/nixos/services/miniflux.nix`).

## Architecture

| Piece      | Value                                                              |
| ---------- | ------------------------------------------------------------------ |
| UI/API     | `https://rss.home.lan` (plain Caddy `reverse_proxy` — NEVER protectedVHost, it has native OIDC) |
| Listen     | `127.0.0.1:8101` (`lib/ports.nix` `miniflux`)                       |
| Database   | local PostgreSQL `miniflux` (peer auth, `createDatabaseLocally`)    |
| Daily auth | Pocket ID OIDC — first login auto-creates the user (`OAUTH2_USER_CREATION=1`) |
| Break-glass| local admin `lars` — password in sops (below)                        |
| Monitoring | Gatus "Miniflux" (`/healthcheck` = DB round-trip) + "Miniflux Login Renders"; `miniflux` in system-health `monitoredServices` |
| Backup     | `miniflux-backup.timer` 02:45 → `pg_dump -Fc` → `/mnt/pool/backups/miniflux/` (14d retention, backup-coordination, maxAge 25h) |

The client secret travels WITHOUT a bridge oneshot: the Pocket ID provisioner
writes `/var/lib/pocket-id/client-secrets/miniflux`, the unit binds it via
`LoadCredential`, and Miniflux reads it from `OAUTH2_CLIENT_SECRET_FILE=%d/…`.
OIDC discovery is lazy (per login, non-fatal — `internal/oauth2/manager.go`),
so the service starts even while `auth.home.lan` is briefly unreachable; the
`mkOidcGate` probe (300s) only gates the boot transaction.

## Go-live / credentials

Admin password (random, generated at file creation — nobody knows it):

```bash
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops -d platforms/nixos/secrets/miniflux.yaml
```

Change it: `sops` edit the same file (keep the `ADMIN_USERNAME=lars` /
`ADMIN_PASSWORD=…` env-file format), then `nix run .#deploy` — sops rotation
restarts the unit via `restartUnits`.

Daily login: `rss.home.lan` → "Sign in with Pocket ID". If Pocket ID is
unreachable, the lazy OIDC init logs an error and the login button fails —
use the admin break-glass (password form stays enabled by design).

## Operations

- **Feed health**: Miniflux refreshes internally (no cron unit); per-feed
  errors surface in the UI and `/v1/entries?status=error`-style API queries.
- **Backup restore**: `pg_restore --clean --dbname=miniflux <dump>` (as
  `postgres`); dumps are custom-format, PGDMP magic.
- **Secret rotation of the OIDC client**: run `regenerateSecretsFor` in
  pocket-id.nix if the file/DB desyncs — deploy.sh restarts miniflux after
  pocket-id-provision to re-bind the LoadCredential.
- **Unit changed?** `switch-to-configuration` restarts miniflux on unit-file
  change (it is a normal service, not a RemainAfterExit oneshot).

## VM test

`tests/test-miniflux.nix` (registered in `tests/default.nix`): boots the
module with mock sops + fake Pocket ID secret against a real PostgreSQL and a
real mounted pool; asserts `/healthcheck`, login-page HTML, admin API auth,
OAUTH2/LoadCredential wiring in the unit, and a PGDMP-magic dump landing in
`/mnt/pool/backups/miniflux`. The OIDC gate curl probe is neutered in the VM
(no `auth.home.lan` there).
