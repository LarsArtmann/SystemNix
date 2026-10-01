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

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Miniflux (RSS Reader, 2026-09-10)

**Module:** `modules/nixos/services/miniflux.nix` — wraps the nixpkgs `services.miniflux` module (Go 2.3.3 + local PostgreSQL, `createDatabaseLocally` peer auth). Enabled on evo-x2; `rss.home.lan` (Layer 1 plain reverse_proxy — native OIDC, NEVER protectedVHost), port 8101, DNS `rss`. Runbook: `docs/services/miniflux.md`. Picked over FreshRSS/TT-RSS after research: single Go binary, `<50MB` RAM, native OIDC + Google-grade minimalism; FreshRSS only wins on PHP extensions/XPath scraping.

- **Static system user, NOT DynamicUser (fixed 2026-09-17)**: upstream sets `DynamicUser = true` + `User = miniflux`, and postgres peer auth then resolves miniflux's DYNAMIC uid — **which only works while nsncd is alive** (`system.nssModules` is documented "Only works with nscd!": glibc loads `libnss_systemd` only in the nscd/nsncd process via its `LD_LIBRARY_PATH = nssModulesPath`; in every other process the dlopen silently fails and getpwuid falls through to files-only). The VM test proved the failure class live: nsncd lost a boot race (3× `Error: Read-only file system` → start-limit-hit), postgres logged `could not look up local user ID 64274: user does not exist`, and miniflux crash-looped `pq: Peer authentication failed` on EVERY restart — deterministic, looks exactly like a pg_hba/role bug, and NOTHING in the miniflux or postgres config is wrong. The wrapper now declares `users.users.miniflux` (isSystemUser) + `DynamicUser = mkForce false` — peer auth is a pure /etc/passwd lookup, immune to nscd death; the app is stateless so the uid switch is transparent. Miniflux was the ONLY DynamicUser+peer-auth service in the fleet (paperless/immich are static users). The nsncd EROFS boot race itself is an upstream flake, still live in VMs — expect it in VM logs and IGNORE it unless a DynamicUser+peer service exists.

- **Zero-bridge OIDC**: Miniflux supports `OAUTH2_CLIENT_SECRET_FILE`, so the Pocket ID provisioner's secret reaches the service via systemd `LoadCredential` + `%d` — NO env-file bridge oneshot (unlike forgejo/paperless). **OIDC discovery is LAZY** (per-login request context, non-fatal when `auth.home.lan` is unreachable — verified in `internal/oauth2/manager.go`), so `mkOidcGate` only gates the boot transaction; the service itself starts through IdP outages. First Pocket ID login auto-creates the user (`OAUTH2_USER_CREATION=1`) — UNLESS the OIDC username collides with an existing local user (see the linking bullet). **`OAUTH2_REDIRECT_URL` MUST be set EXPLICITLY (fixed 2026-09-11): it defaults to EMPTY upstream — miniflux does NOT derive it from `BASE_URL`** — without it the authorize request carries no `redirect_uri` and Pocket ID answers `The 'redirect_uri' parameter is required when using OpenID Connect 1.0`; the value must match the `pocket-id.nix` callbackURL byte-for-byte (`https://rss.<domain>/oauth2/oidc/callback`). Verified live post-fix: `/oauth2/oidc/redirect` → 302 to `/authorize?...redirect_uri=...` → `/interaction` (passkey screen), and the authorize request carries PKCE (S256).
- **First OIDC login 400s "This user already exists." (fixed 2026-09-11, source-verified v2.3.3)**: miniflux NEVER links by username — the unauthenticated callback resolves the user ONLY via `openid_connect_id` (the Pocket ID `sub` UUID; column set by `PopulateUserWithProfileID`), and with `OAUTH2_USER_CREATION=1` a collision with the pre-seeded break-glass admin (`lars` from `ADMIN_USERNAME` at first start) hard-fails HTTP 400 `error.user_already_exists`. Fix is upstream's designed link flow (zero SQL, zero sudo): break-glass password login → Settings "Link your Pocket ID account" (= GET `/oauth2/oidc/redirect`; that handler has NO auth check, works from any authenticated session) → passkey → the callback's authenticated branch writes `openid_connect_id` and flashes "account linked". Afterwards SSO login works AND the `disableLocalAuth` go-live gate (one proven live SSO login) is satisfiable. Upstream refuses unlinking once `DISABLE_LOCAL_AUTH=1`. Runbook: `docs/services/miniflux.md`.
- **The 400 recurred 2026-09-17 post-redirect-fix — the collision persists until the LINK itself exists (no config bug):** reaching "This user already exists." PROVES the code exchange + userinfo succeeded (those precede user resolution) — the only missing state was `users.openid_connect_id = NULL`. **`sub` == Pocket ID `users.id`** (source-verified pocket-id v2.14.0: `authorization_service.go` `buildAuthorizedSession` → `NewAuthenticatedSession(req.userID)`; `jwt_service.go` `GenerateAccessToken` → `Subject(user.ID)`), which is what makes the declarative link below equivalent to upstream's interactive flow. **PRIMARY FIX (2026-09-17, deployed): `services.miniflux.oidcLink`** — a `miniflux-oidc-setup` converger oneshot: phase 1 (root `+` ExecStartPre) resolves the Pocket ID user id from Pocket ID's SQLite (`dataDir/data/pocket-id.db`, explicit `username` option or auto = exactly ONE user per side, else loud failure printing both tables); phase 2 (User=postgres, peer auth) converges `users.openid_connect_id` with a bounded wait (15×2s) for miniflux's first-start CREATE_ADMIN. Idempotent ("already linked" no-op), re-links automatically if Pocket ID's DB is recreated (fresh subs — the 2026-08-22 SQLITE_BUSY class), `restartUnits`-free by design: deploy.sh's provisioner loop restarts it (matches the `-setup$` converger pattern in deploy-restart-audit). Wrong sub fails safe (SSO lookup misses → same collision error, never lockout; password login unaffected). Do NOT flip `disableLocalAuth` until one SSO login is proven live. MANUAL EMERGENCY FALLBACK (no deploy needed): derive the id from Pocket ID's SQLite and `UPDATE users SET openid_connect_id='<sub>' WHERE username='lars' AND openid_connect_id IS NULL` in PG — same end state as `PopulateUserWithProfileID`, no miniflux restart. Two SQL traps burned in the VM: **psql without `-d` connects to the database named after the invoking USER** (as postgres you land in the `postgres` DB and get `relation "users" does not exist` while the table is fine in `miniflux` — upstream's dbsetup runs `psql "miniflux"` for the same reason), and **psql 17 does NOT interpolate `:'var'` meta-variables inside `-c`** (literal hits the server → syntax error at ":") — the script charset-guards both values (sub `[A-Za-z0-9-]`, username `[A-Za-z0-9@._-]`) and inlines single-quoted literals, which is injection-safe by construction.
- **Break-glass admin**: `platforms/nixos/secrets/miniflux.yaml` `miniflux_admin_credentials` (env-file format `ADMIN_USERNAME=lars`/`ADMIN_PASSWORD=<random, nobody knows it>`; retrieve via the Sops + Age one-liner). The password form is deliberately NOT disabled (unlike paperless) — it is the fallback when Pocket ID is down. **ADMIN_PASSWORD env rotation is INERT for an existing user (2026-09-11)** — miniflux seeds the admin only when the users table is empty (journal: `Skipping admin user creation because it already exists` every start); real rotation = log in → Settings → change password.
- **Backup**: `miniflux-backup.timer` 02:45 → `pg_dump --format=custom` as `postgres` (peer auth) → `/mnt/pool/backups/miniflux/miniflux-*.dump`, 14d retention, registered in backup-coordination (maxAge 25h). The dir is created by the mount-gated `miniflux-backup-dir` oneshot (cv-backup-dir pattern: ReadWritePaths on the MOUNT ROOT, `chown postgres` via `CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE"` in the harden args — the dumper runs AS postgres over the pre-existing dir, so the 226 class cannot recur); `miniflux-backup-dir` is in the deploy.sh provisioner restart list, and deploy.sh restarts `miniflux` after pocket-id-provision so a rotated client secret re-binds (LoadCredential is bound at process start).
- **Monitoring**: Gatus "Miniflux" (`/healthcheck` = real DB round-trip, 503 on DB failure) + "Miniflux Login Renders"; `miniflux` in system-health `monitoredServices`. No OTel env (binary lacks OTel — nothing registered in signoz-coverage, per doctrine).
- **VM test**: `tests/test-miniflux.nix` (real PG + real mounted pool via `virtualisation.fileSystems`; asserts healthcheck, admin API auth through the env-file chain, OAUTH2/LoadCredential unit wiring, PGDMP dump, and step 5: the oidc-setup link — auto-resolves the fixture Pocket ID user `vmadmin` (deliberately ≠ miniflux admin `admin`, proving resolution by uniqueness not name), asserts the converged `openid_connect_id` via `psql -d miniflux`, and idempotent re-run logs "already linked"). The test NEUTERS the OIDC gate ExecStartPre (`auth.home.lan` unresolvable in VM) and overrides the sops secret path to an etc file (empty mock file would fail CREATE_ADMIN — admin credentials are mandatory at first start). Nix-parsing trap: `(import f) { }.flake.nixosModules.miniflux` does NOT parse as apply-then-select — the one-liner handed the OUTER flake-parts module to the VM's imports (`nodes.machine.flake does not exist`); use the test-paperless two-statement form.

