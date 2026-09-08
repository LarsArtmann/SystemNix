# Paperless-ngx Runbook (SSO-only)

`paperless.home.lan` · port 2892 (`lib/ports.nix`) · module `modules/nixos/services/paperless.nix` · vHost in `caddy.nix` (plain `reverse_proxy` — Layer 1, see below)

**State since 2026-09-02: SSO-ONLY login via Pocket ID.** User decision: "I do not like password logins." Regular (username/password) login is disabled while the OIDC bridge is healthy and AUTOMATICALLY restored as break-glass when it degrades.

---

## Architecture

| Piece           | What / Where                                                                                                                                                                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| App             | nixpkgs `services.paperless` 3.x, PostgreSQL backend (peer-auth, shared with Immich), `dataDir = /mnt/pool/services/paperless`                                                                                                                                                       |
| Identity        | Pocket ID (`auth.home.lan`), client id `paperless`, PKCE S256 both sides, callback `https://paperless.home.lan/accounts/oidc/pocket-id/login/callback/` (allauth-fixed path) — registered in `pocket-id.nix` `oidcClients` default                                                   |
| Secret bridge   | `paperless-oidc-setup.service` oneshot: reads the Pocket ID client secret via `LoadCredential`, writes the allauth provider JSON (single-line via `jq -c`) + `PAPERLESS_DISABLE_REGULAR_LOGIN=true` + `PAPERLESS_REDIRECT_LOGIN_TO_SSO=true` into `/var/lib/paperless-oidc/oidc.env` |
| Env attach      | `EnvironmentFile = ["-/var/lib/paperless-oidc/oidc.env"]` — attached DIRECTLY via systemd, **never** via the nixpkgs `environmentFile` option (bash `source` strips JSON quotes — the reason the bridge exists)                                                                      |
| Caddy           | plain `reverse_proxy` (native OIDC ⇒ `protectedVHost` would double-auth). `/admin/*` AND exact `/admin` → 403                                                                                                                                                                        |
| Sidecars        | Tika (:9998) + Gotenberg (:3199) for Office/E-Mail consume; paperless-ai on FastFlowLM + llama-rag embeddings                                                                                                                                                                        |
| Deploy ordering | deploy.sh restarts `paperless-oidc-setup` BEFORE `paperless-web` (env file read at process start only)                                                                                                                                                                               |

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

| Signal                          | Where                                   | Meaning                                                                                                                                                                            |
| ------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Gatus "Paperless"               | `http://localhost:2892/accounts/login/` | `[STATUS]==200` + body has `oidc/pocket-id` + `getElementById` + NO `type="password"` — catches BOTH the bridge degrading (password form back = visible) and the SSO flow breaking |
| Gatus "Pocket ID SQLite Health" | `:9100/metrics`                         | `system_pocket_id_busy_*` — SQLITE_BUSY storm on the auth SPOF (this app's ONLY login path)                                                                                        |
| Gatus Tika/Gotenberg            | `:9998/`, `:3199/health`                | consume-path sidecars                                                                                                                                                              |
| Post-deploy smoke               | login body + both sidecars              | functional, not liveness                                                                                                                                                           |

Definitive gatus state (root): `sudo sqlite3 -readonly /var/lib/private/gatus/gatus.db 'select name,status from endpoints;'` — the gatus HTTP API sits behind OIDC and 401s plain curl.

## API auth surface (T13 research COMPLETE 2026-09-03, source+live-verified against 3.0.5 — implementation gated on user go)

**`PAPERLESS_DISABLE_REGULAR_LOGIN` does NOT close the REST API password surface.** Verified in source + live probe (supersedes an earlier claim in this file that it blocked token acquisition — it does not):

- The flag lives ONLY in allauth's login-view path (`paperless/adapter.py pre_authenticate` → the web login form).
- **HTTP Basic on `/api/*` stays open**: DRF's `PaperlessBasicAuthentication` subclasses `BasicAuthentication` → `user.check_password()` directly, no backend chain, no gate. Reachable EXTERNALLY (paperless is Layer-1 plain reverse_proxy — the app IS the auth boundary).
- **`/api/token/` obtain stays open**: `AuthTokenSerializer` calls `django.contrib.auth.authenticate()`; `ModelBackend` (plain password check) runs BEFORE allauth's gated backend, so correct credentials succeed. Live probe with bogus creds returns "Unable to log in", NOT "Regular login is disabled" — the gate is never reached.
- **API tokens keep working regardless** (`TokenAuthentication`): paperless-ai + InboxClean (token provisioned 2026-09-02) are the known consumers; no password-auth consumers exist on this box.

**Recommended closure (not yet implemented — needs user go, Q2 answer was "unsure"):** Caddy-level, zero app change — under `/api/*`, respond 403 when `Authorization` starts with `Basic` (header-prefix matcher), plus an exact block of `/api/token/`. Token consumers (`Authorization: Token …`) pass untouched. Side effect: the official mobile app's password login breaks (it uses `/api/token/`); if the mobile app matters, keep `/api/token/` open and accept Basic being closed only. Ask: "Do you use, or plan to use, the paperless mobile app or any password-based API client?"

## Classifier / auto-matching semantics (2026-09-06 incident)

The hourly **Train Classifier** task (`PAPERLESS_TRAIN_TASK_CRON`, default
`5 */1 * * *`) trains paperless's ML auto-matching from documents carrying
labels whose matching algorithm is **auto**:

- No auto labels at all → task SUCCEEDS ("No automatic matching items, not
  training") and any stale model file is deleted.
- Auto labels + zero non-inbox documents → fails "No training data available."
- Auto labels + documents whose content is ALL empty → fails with sklearn's
  **"empty vocabulary; perhaps the documents only contain stop words"** —
  the CountVectorizer runs unconditionally before any classifier fit.

Live chain Sep 3–4 2026: an older InboxClean papersync created the `gmail`
tag with matching **auto**, then four password-protected Polish bank
statements arrived with EMPTY content (pdftotext exit 1 "invalid password",
ocrmypdf "encrypted and/or signed, OCR is impossible" → "the content will
be empty") — 22 h of hourly red tasks until an OCR-able JPG provided
vocabulary. Fixes: InboxClean now creates tags with matching **none** and
self-heals legacy auto tags via PATCH on the next sync (correspondents
deliberately keep auto — sender prediction on manual scans is the useful
ML). ML matching is opt-in per label in the UI, never a default.

## Duplicate documents

`PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` (2026-09-06) rejects
byte-identical uploads at the door: the paperless default only WARNED and
stored every copy ("Consuming duplicate … 1 existing document(s) share the
same content", then succeeded with a new document id) — the same statement
mailed to two mailboxes arrived twice within seconds via InboxClean's
per-account ledgers. Repair the four 2026-09-03 documents (two are
duplicates):

```bash
# preview: sudo -u inboxclean … inboxclean paperless --backfill --dry-run
# repair (keeps the OLDEST document per checksum, deletes the rest):
sudo -u inboxclean env \
  PAPERLESS_URL=http://127.0.0.1:2892 \
  PAPERLESS_TOKEN="$(sudo grep -oP 'PAPERLESS_TOKEN=\K\S+' /run/secrets/rendered/inboxclean-paperless-env)" \
  INBOXCLEAN_TOKEN_FILE=/var/lib/inboxclean/token.json \
  DB_PATH=/var/lib/inboxclean/inboxclean.db \
  /run/current-system/sw/bin/inboxclean paperless --backfill --prune
```

## Encrypted bank statements

Bank statement PDFs (Polish banks) arrive password-protected. Without the
password paperless archives them with EMPTY content — unsearchable, invisible
to AI — tagged `encrypted` so the gap is visible. With the password set,
InboxClean decrypts them with qpdf BEFORE upload:

```bash
sudo sops platforms/nixos/secrets/inboxclean-decrypt.yaml
# set paperless_decrypt_password to the bank's PDF password, then deploy
```

A PLACEHOLDER value is inert by design (detection + tagging only). The
ledger records the DECRYPTED checksum, so the same statement via the second
mailbox dedups instead of re-uploading.

## Known traps (pointers)

- Engine-switch bootstrap (sqlite→PG `src-version`/`superuser-state` survival) — AGENTS Paperless section
- UI-saved values override env (`app_config.x or settings.X`) — settings-UI writes beat deploys
- v3 filename format needs double-curly; trash dir via tmpfiles
- VM test: `nix build .#checks.x86_64-linux.paperless --no-link --print-out-paths`
