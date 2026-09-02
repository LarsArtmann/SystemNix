# Paperless-ngx Runbook (SSO-only)

`paperless.home.lan` · port 2892 (`lib/ports.nix`) · module `modules/nixos/services/paperless.nix` · vHost in `caddy.nix` (plain `reverse_proxy` — Layer 1, see below)

**State since 2026-09-02: SSO-ONLY login via Pocket ID.** User decision: "I do not like password logins." Regular (username/password) login is disabled while the OIDC bridge is healthy and AUTOMATICALLY restored as break-glass when it degrades.

---

## Architecture

| Piece | What / Where |
|---|---|
| App | nixpkgs `services.paperless` 3.x, PostgreSQL backend (peer-auth, shared with Immich), `dataDir = /mnt/pool/services/paperless` |
| Identity | Pocket ID (`auth.home.lan`), client id `paperless`, PKCE S256 both sides, callback `https://paperless.home.lan/accounts/oidc/pocket-id/login/callback/` (allauth-fixed path) — registered in `pocket-id.nix` `oidcClients` default |
| Secret bridge | `paperless-oidc-setup.service` oneshot: reads the Pocket ID client secret via `LoadCredential`, writes the allauth provider JSON (single-line via `jq -c`) + `PAPERLESS_DISABLE_REGULAR_LOGIN=true` + `PAPERLESS_REDIRECT_LOGIN_TO_SSO=true` into `/var/lib/paperless-oidc/oidc.env` |
| Env attach | `EnvironmentFile = ["-/var/lib/paperless-oidc/oidc.env"]` — attached DIRECTLY via systemd, **never** via the nixpkgs `environmentFile` option (bash `source` strips JSON quotes — the reason the bridge exists) |
| Caddy | plain `reverse_proxy` (native OIDC ⇒ `protectedVHost` would double-auth). `/admin/*` AND exact `/admin` → 403 |
| Sidecars | Tika (:9998) + Gotenberg (:3199) for Office/E-Mail consume; paperless-ai on FastFlowLM + llama-rag embeddings |
| Deploy ordering | deploy.sh restarts `paperless-oidc-setup` BEFORE `paperless-web` (env file read at process start only) |

## SSO-only semantics (the non-obvious parts)

- `PAPERLESS_REDIRECT_LOGIN_TO_SSO` is a **client-side JS auto-submit**, NOT a 302. The login page answers **HTTP 200** and auto-submits the first provider form. Anything asserting a redirect status is wrong (the Gatus check asserts the body instead).
- `PAPERLESS_DISABLE_REGULAR_LOGIN` hides the password form on the WEB login. It does **NOT** cover:
  - the Django admin (`/admin/…`) — that is why Caddy hard-blocks it (nobody uses it; `paperless-manage` covers admin operations)
  - the REST API: existing API tokens keep working; username/password auth on the API is a SEPARATE surface (see API caveat below)
- **Logout bounce-back is ACCEPTED** (user decision 2026-09-02): logging out of Paperless while the Pocket ID session is alive auto-bounces you straight back in on the next page load. Single Logout is partial by architecture (see AGENTS SSO section). If this ever needs to change: shorter `SESSION_COOKIE_AGE` / Pocket ID RP-initiated logout — do not "fix" silently.

## Break-glass (how to get in when Pocket ID is down)

**Automatic:** the SSO flags ride in the SAME env file as the provider JSON. If the Pocket ID secret is missing (provisioner hasn't run / degraded), the bridge writes an empty-providers file WITHOUT the disable flags ⇒ the password login form comes back by itself. SSO fully on or fully off — never a locked-out middle state.

**Manual:** `sudo systemctl restart paperless-oidc-setup.service` (re-runs the bridge), or check the condition gate: `journalctl -u paperless-oidc-setup -n 20`.

**Admin password** lives in sops `platforms/nixos/secrets/paperless.yaml` → `paperless_admin_password` (read by the nixpkgs module via `LoadCredential`).

## Admin-password rotation (the DB-first nuance)

The sops value only **seeds bootstrap** (the nixpkgs scheduler's `superuser-state`). A bare sops rotation is a phantom — the live DB password is unchanged. Correct order:

1. Change the LIVE password in the DB (interactive, on the box — never paste the value into shell history/docs; the Resend-leak class):
   ```bash
   sudo -u paperless paperless-manage changepassword <admin-username>
   # (Django's interactive changepassword prompts for the new value)
   ```
2. Update sops to MATCH: `sudo sops platforms/nixos/secrets/paperless.yaml` (edit `paperless_admin_password`).
3. Deploy (`nix run .#deploy`) and verify the OLD password is rejected on the login form (break-glass path) — expect a login failure, not a lockout (SSO is unaffected).

## Monitoring

| Signal | Where | Meaning |
|---|---|---|
| Gatus "Paperless" | `http://localhost:2892/accounts/login/` | `[STATUS]==200` + body has `oidc/pocket-id` + `getElementById` + NO `type="password"` — catches BOTH the bridge degrading (password form back = visible) and the SSO flow breaking |
| Gatus "Pocket ID SQLite Health" | `:9100/metrics` | `system_pocket_id_busy_*` — SQLITE_BUSY storm on the auth SPOF (this app's ONLY login path) |
| Gatus Tika/Gotenberg | `:9998/`, `:3199/health` | consume-path sidecars |
| Post-deploy smoke | login body + both sidecars | functional, not liveness |

Definitive gatus state (root): `sudo sqlite3 -readonly /var/lib/private/gatus/gatus.db 'select name,status from endpoints;'` — the gatus HTTP API sits behind OIDC and 401s plain curl.

## API caveat (T13 pending user decision)

`PAPERLESS_DISABLE_REGULAR_LOGIN` also blocks username/password API-token acquisition (mobile app password login); **existing API tokens keep working**. The REST API itself still accepts username/password for session auth in some paths — closing that is a separate change gated on the "do you use API clients?" question (2026-09-02: answer pending, research-only). Paperless-ai uses a token; the web UI uses the session.

## Known traps (pointers)

- Engine-switch bootstrap (sqlite→PG `src-version`/`superuser-state` survival) — AGENTS Paperless section
- UI-saved values override env (`app_config.x or settings.X`) — settings-UI writes beat deploys
- v3 filename format needs double-curly; trash dir via tmpfiles
- VM test: `nix build .#checks.x86_64-linux.paperless --no-link --print-out-paths`
