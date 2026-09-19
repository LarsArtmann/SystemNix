# Miniflux (RSS Reader)

`rss.home.lan` — minimalist self-hosted RSS reader (Go + PostgreSQL), Layer 1
native OIDC via Pocket ID. Wraps the nixpkgs `services.miniflux` module
(`modules/nixos/services/miniflux.nix`).

## Architecture

| Piece        | Value                                                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| UI/API       | `https://rss.home.lan` (plain Caddy `reverse_proxy` — NEVER protectedVHost, it has native OIDC)                                |
| Listen       | `127.0.0.1:8101` (`lib/ports.nix` `miniflux`)                                                                                  |
| Database     | local PostgreSQL `miniflux` (peer auth, `createDatabaseLocally`)                                                               |
| Service user | static system user `miniflux` (wrapper overrides upstream's DynamicUser — see below)                                           |
| Daily auth   | Pocket ID OIDC — the `miniflux-oidc-setup` provisioner links the account declaratively                                         |
| Break-glass  | local admin `lars` — password in sops (below)                                                                                  |
| Monitoring   | Gatus "Miniflux" (`/healthcheck` = DB round-trip) + "Miniflux Login Renders"; `miniflux` in system-health `monitoredServices`  |
| Backup       | `miniflux-backup.timer` 02:45 → `pg_dump -Fc` → `/mnt/pool/backups/miniflux/` (14d retention, backup-coordination, maxAge 25h) |

The client secret travels WITHOUT a bridge oneshot: the Pocket ID provisioner
writes `/var/lib/pocket-id/client-secrets/miniflux`, the unit binds it via
`LoadCredential`, and Miniflux reads it from `OAUTH2_CLIENT_SECRET_FILE=%d/…`.
OIDC discovery is lazy (per login, non-fatal — `internal/oauth2/manager.go`),
so the service starts even while `auth.home.lan` is briefly unreachable; the
`mkOidcGate` probe (300s) only gates the boot transaction.

**Static service user (2026-09-17):** upstream sets `DynamicUser = true`, which
makes postgres peer auth depend on nsncd being alive (glibc can only load
`libnss_systemd` inside the nscd process — `system.nssModules` "Only works with
nscd!"). When nsncd wedges, postgres answers `could not look up local user ID:
user does not exist` and miniflux crash-loops `Peer authentication failed` —
reproduced in the VM. The wrapper declares a static `users.users.miniflux` +
`DynamicUser = mkForce false`; peer auth is then a plain /etc/passwd lookup.

## Go-live / credentials

Admin password (random, generated at file creation — nobody knows it):

```bash
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops -d platforms/nixos/secrets/miniflux.yaml
```

**Rotation caveat (journal-proven 2026-09-11):** the `ADMIN_*` env only seeds
the admin on FIRST start (empty users table — miniflux logs `Skipping admin
user creation because it already exists username=lars` on every subsequent
start). A sops edit + redeploy does NOT change the password of an EXISTING
user. Real rotation: log in (OIDC once linked, or with the current password) →
Settings → change password. The sops value is only the first-boot seed.

Daily login: `rss.home.lan` → "Sign in with Pocket ID". If Pocket ID is
unreachable, the lazy OIDC init logs an error and the login button fails —
use the admin break-glass (password form stays enabled by design).

**First login 400s "This user already exists." — PRIMARY FIX: the declarative
link (2026-09-17):** Miniflux never links an OIDC identity by username — the
unauthenticated callback resolves the user ONLY by `openid_connect_id` (= the
Pocket ID `sub` UUID; source-verified v2.3.3 `internal/ui/oauth2_callback.go`)
and, with `OAUTH2_USER_CREATION=1`, refuses on a username collision with the
pre-seeded `lars` break-glass admin (HTTP 400 `error.user_already_exists`).
`services.miniflux.oidcLink.enable = true` (set on evo-x2) deploys the
`miniflux-oidc-setup` oneshot which converges the link declaratively:

- **Resolution**: phase 1 (root `+` ExecStartPre) reads Pocket ID's SQLite
  (`/var/lib/pocket-id/data/pocket-id.db`) and resolves the user id — explicit
  `services.miniflux.oidcLink.username`, or auto mode: exactly ONE user on
  each side is required, otherwise the unit fails LOUDLY printing both user
  tables (never guesses).
- **Convergence**: phase 2 (runs as `postgres`, peer auth, `psql -d miniflux`)
  writes `users.openid_connect_id` after a bounded wait (15×2s) for miniflux's
  first-start CREATE_ADMIN; already-linked = no-op; a Pocket ID DB recreation
  (fresh subs) re-links automatically on the next run.
- **When it runs**: every boot (`wantedBy = multi-user.target`) + every deploy
  (deploy.sh provisioner loop restarts it — `-setup` converger pattern).
- **Failure semantics**: wrong/missing sub → loud unit failure + OnFailure
  alert; SSO keeps failing with the SAME 400 (never lockout, password login
  unaffected).

Journal check: `journalctl -u miniflux-oidc-setup` → `linked miniflux user
'lars' -> Pocket ID sub <uuid>` or `already linked`.

**Manual emergency fallback (no deploy):** derive the sub from Pocket ID's
SQLite and guarded-UPDATE miniflux directly — same end state as upstream's
`PopulateUserWithProfileID`, no restart needed:

```bash
# 1. sub (root reads pocket-id's 0700 data dir)
sudo sqlite3 /var/lib/pocket-id/data/pocket-id.db \
  "SELECT id, username FROM users;"
# 2. link (IS-NULL guard = idempotent; wrong sub fails safe: lookup misses →
#    same 400, no lockout)
sudo -u postgres psql -d miniflux -c \
  "UPDATE users SET openid_connect_id='<sub-from-step-1>' WHERE username='lars' AND openid_connect_id IS NULL;"
```

**Upstream interactive alternative (no SQL):** break-glass password login →
Settings → "Link your Pocket ID account" (= GET `/oauth2/oidc/redirect` — that
handler has no auth check, works from any session) → passkey ceremony → the
callback's authenticated branch writes `openid_connect_id`. Journal proof of
success either way: `User authenticated successfully using OAuth2 …
username=lars`. That first live SSO login also satisfies the
`disableLocalAuth` go-live gate below.

**psql traps (both burned in the VM test 2026-09-17):** without `-d miniflux`,
psql connects to the database named after the invoking USER (postgres →
`relation "users" does not exist` while the table is fine), and psql 17 does
NOT interpolate `:'var'` meta-variables inside `-c` (literal hits the server).

**Login-page URL fact (live-verified 2026-09-11, miniflux 2.3.3):** the
sign-in page is served at `/` for unauthenticated sessions. `/login` is the
POST target only — `GET /login` answers **405 Method Not Allowed**. Any
probe/check must hit `/` and assert the `/oauth2/oidc/redirect` href (the
OIDC sign-in link only renders when the OAUTH2_* wiring is live).

**SSO-only posture (`services.miniflux.disableLocalAuth`, default false):**
sets `DISABLE_LOCAL_AUTH=1`, removing the password form entirely. GO-LIVE
GATE: flip only AFTER one successful live SSO login — enabling it in the
same deploy as an unproven OIDC callback risks total lockout (this is the
paperless lesson; SSO fully on or fully off, never a locked-out middle).
Break-glass when enabled: set the option back to false (one line) and
redeploy; the admin account stays in the database regardless.

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
OAUTH2/LoadCredential wiring in the unit, a PGDMP-magic dump landing in
`/mnt/pool/backups/miniflux`, and the declarative link (step 5: fixture Pocket
ID user `vmadmin` ≠ miniflux admin `admin` proves resolution by uniqueness;
converged `openid_connect_id` asserted via `psql -d miniflux`; idempotent
re-run logs "already linked"). The OIDC gate curl probe is neutered in the VM
(no `auth.home.lan` there).
