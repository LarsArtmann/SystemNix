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

## Roles → superuser/staff via Pocket ID groups (2026-10-01)

Pocket ID emits a `groups` OIDC claim **only when the client requests the `groups` scope** (`claims_service.go`), which the paperless client now does (appended to the provider `SCOPE`). On each login django-allauth fires `social_account_updated`, and paperless's handler (`signals.py`) maps the claim to Django roles:

| Setting                                         | Value              | Effect                      |
| ----------------------------------------------- | ------------------ | --------------------------- |
| `PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS_CLAIM`    | `groups`           | which claim to read         |
| `PAPERLESS_SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP` | `paperless-admins` | membership ⟺ `is_superuser` |
| `PAPERLESS_SOCIAL_ACCOUNT_SYNC_STAFF_GROUP`     | `paperless-admins` | membership ⟺ `is_staff`     |

- **Single source of truth:** `oidcAdminGroup = "paperless-admins"` in `paperless.nix` drives the requested scope, both env mappings, AND the group declaration in Pocket ID (`services.pocket-id-config.provision.userGroups`; provisioner Step 4 creates the group and authoritatively `PUT`s membership). An eval assertion fails if the mapped group is not declared — a rename cannot silently demote every login.
- **FAIL CLOSED:** the handler sets `is_superuser = <group> in <claim>` on every login, so a missing/empty claim **demotes**. A broken IdP can never leave stale privilege behind. Corollary: a manual `paperless-manage shell -c "...update(is_superuser=True)"` is now **transient** — the next login overwrites it. Grant admin by adding your Pocket ID user to `paperless-admins` (declaratively via `memberUsernames`).
- **First-login gap (known, upstream):** allauth fires `social_account_added` only when _linking_ an account; on auto-signup neither social signal fires, and paperless connects **only** `social_account_updated`. A brand-new user is therefore promoted on their **second** login, not the first. The single SSO user already has an account, so this does not affect them.

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
# Everything except the paperless secrets is pulled from the DEPLOYED unit
# file. All five extracted vars are REQUIRED (gate-tested against the live
# CLI 2026-09-12): INBOXCLEAN_CONFIG (the accounts TOML — without it the
# CLI sees only the main account and work-account ledger rows resolve no
# source email, the 2026-08-29 auth-runbook trap), LLM_PROVIDER (the CLI's
# global config gate exits config.api_key_required BEFORE dispatch without
# it — the default provider is openai, the unit runs ollama),
# GMAIL_CREDENTIALS_FILE/GMAIL_TOKEN_FILE (the MAIN account's client for
# --decrypt-repair source re-fetch is built from these; the TOML only
# covers extra accounts), DB_PATH, and PATH (carries qpdf).
sudo -u inboxclean env \
  $(grep -oP '(GMAIL_CREDENTIALS_FILE|GMAIL_TOKEN_FILE|INBOXCLEAN_CONFIG|DB_PATH|LLM_PROVIDER)=\S+' /etc/systemd/system/inboxclean-sync.service) \
  PATH="$(grep -oP '^Environment="PATH=\K[^"]+' /etc/systemd/system/inboxclean-sync.service)" \
  PAPERLESS_URL=http://127.0.0.1:2892 \
  PAPERLESS_TOKEN="$(sudo grep -oP 'PAPERLESS_TOKEN=\K\S+' /run/secrets/rendered/inboxclean-paperless-env)" \
  PAPERLESS_DECRYPT_PASSWORD="$(sudo sed -n 's/^PAPERLESS_DECRYPT_PASSWORD=//p' /run/secrets/rendered/inboxclean-paperless-env)" \
  /run/current-system/sw/bin/inboxclean paperless --backfill --prune
```

The sed (not `grep -oP '\S+'`) for the decrypt password preserves embedded
spaces; PAPERLESS_TOKEN is a single token so the cheaper grep is safe.

## Retro-decrypt repair (existing encrypted statements)

The four 2026-09-03 statements were archived BEFORE the password existed:
their stored bytes ARE the encrypted originals, so re-uploading decrypted
copies cannot dedup against them (different bytes). Repair them in place
with the upstream `--backfill --decrypt-repair` (InboxClean ≥ 2026-09-12 —
needs a flake bump after the upstream push; the deployed c65c797 build does
NOT have it yet):

```bash
# same env reconstruction as above; add --decrypt-repair and preview first:
… inboxclean paperless --backfill --decrypt-repair --dry-run   # preview
… inboxclean paperless --backfill --decrypt-repair             # repair
```

Per encrypted document it re-fetches the source attachment (verified
against the ledger checksum — a mismatched or missing source is skipped
with a reason), decrypts with qpdf, uploads the plaintext with the old
document's metadata, and on a settled consumption task deletes the
encrypted original and repoints the ledger row at the replacement. A
duplicate refusal converges (the pre-existing decrypted copy survives).
Failures are per-document counters; the encrypted original stays in place
and a corrected re-run converges. Requires the corrected env
reconstruction above: INBOXCLEAN_CONFIG for the work-account rows,
GMAIL_CREDENTIALS_FILE/GMAIL_TOKEN_FILE for the main account's source
re-fetch, LLM_PROVIDER for the config gate, and PATH with qpdf.

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

## Declarative dashboards (saved views)

Paperless v3 dashboards are per-user SAVED VIEWS whose visibility lives in
`UiSettings.settings.saved_views.{dashboard,sidebar}_views_visible_ids`
(migration `0014_savedview_visibility_to_ui_settings`) — env vars cannot
reach them. SystemNix provisions them via the `paperless-dashboard-provision`
oneshot (`services.paperless-dashboard`, enabled in configuration.nix):

- **Mechanism**: mints a DRF token as the paperless OS user
  (`drf_create_token`, peer-auth DB), then drives the REST API. Visibility
  rides the **API v9 legacy fields** (`Accept: application/json; version=9`):
  `SavedViewSerializer.create()` merges them ADDITIVELY into the owner's
  `dashboard_views_visible_ids`. The v10 `ui_settings` POST is a WHOLESALE
  settings replacement (dark mode, language, everything) and is never used
  for writes — only read for the in-provisioner end-to-end assertion.
- **Owner**: `services.paperless-dashboard.owner`, null (default) =
  auto-resolve the single Pocket-ID-linked (allauth SocialAccount) user,
  fallback `admin`. The resolved owner prints in the journal.
- **Create-only**: same-name views are NEVER modified or deleted — manual
  UI edits and widget reordering survive every deploy. Changing a view's
  rules = rename it (or delete it in the UI) and re-run
  `sudo systemctl restart paperless-dashboard-provision.service`.
- **Defaults**: "Gmail Archive" (has-tag `gmail`) and "Encrypted (needs
  attention)" (has-tag `encrypted`). Tag names resolve at runtime; an
  unresolvable tag DROPS that rule with a WARN, and a view with zero
  resolvable rules is skipped entirely (a rule-less view shows ALL
  documents — never provisioned implicitly).
- **appTitle** (optional): PATCHes `/api/config/` with the admin token
  (browser title / login page header).

Adding a view (declarative):

```nix
services.paperless-dashboard.savedViews = [
  {
    name = "Statements";
    icon = "bank";
    filterRules = [ { ruleType = 6; tagName = "encrypted"; } ];
  }
];
```

Icon enum + rule-type ids are validated at eval time
(`documents/models.py` source lists; common rule types: 5 = inbox,
6 = has tag, 17 = not tag, 19 = title/content contains, 43-46 = added /
created from-to). Verify live:

```bash
journalctl -u paperless-dashboard-provision.service -o cat --no-pager | tail -20
# created=N skipped_existing=... dashboard_assertions=N  <- every created
# view was confirmed present in dashboard_views_visible_ids
```

## Known traps (pointers)

- Engine-switch bootstrap (sqlite→PG `src-version`/`superuser-state` survival) — AGENTS Paperless section
- UI-saved values override env (`app_config.x or settings.X`) — settings-UI writes beat deploys
- v3 filename format needs double-curly; trash dir via tmpfiles
- VM test: `nix build .#checks.x86_64-linux.paperless --no-link --print-out-paths`

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Paperless-ngx (v3 "superb" config)

**Module:** `modules/nixos/services/paperless.nix` — wraps the nixpkgs paperless module (3.1.1 live) at port 2892 (`paperless.home.lan`, Layer 1 plain reverse_proxy), `dataDir = /mnt/pool/services/paperless`. VM test: `tests/test-paperless.nix`. **Runbook: `docs/services/paperless.md`** (SSO-only ops, break-glass semantics, DB-first password rotation, classifier/auto-matching semantics, monitoring map).

- **"Train Classifier" hourly task failures — the empty-vocabulary incident (root-caused 2026-09-06):** paperless's `train_classifier` task only SUCCEEDS trivially when NO auto-matching label exists ("No automatic matching items, not training"). One AUTO tag + zero non-inbox docs → "No training data available."; AUTO tag + non-inbox docs whose content is ALL empty → sklearn `CountVectorizer` raises "empty vocabulary; perhaps the documents only contain stop words" → hourly FAILED tasks (the vectorizer runs unconditionally BEFORE any classifier fit, regardless of labels). Trigger chain live Sep 3-4 2026: InboxClean papersync created the `gmail` tag with matching_algorithm=6 (AUTO) + 4 password-protected Polish bank statements (Wyciąg) archived with EMPTY content (pdftotext exit 1 "invalid password", ocrmypdf "encrypted and/or signed, OCR is impossible" → "content will be empty") → 22 h of red tasks until an OCR-able JPG arrived and provided vocabulary. Fixes: (1) upstream InboxClean creates tags with NONE + self-heals legacy AUTO tags via PATCH (correspondents deliberately KEEP auto — predicting senders on manual scans is the useful ML); (2) statement decryption (see InboxClean section). With no auto labels the task is green — ML matching is opt-in per label in the UI, never a default
- **`PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` (2026-09-06):** paperless's DEFAULT only WARNS on duplicate content and stores it anyway — the same bank statement mailed to two mailboxes arrived via InboxClean's PER-ACCOUNT ledgers within seconds and every byte-identical copy was archived (journal: "Consuming duplicate … 1 existing document(s) share the same content", then succeeded with a NEW document_id). Rejection at the door is correct for an automated archive; papersync's fire-and-forget upload already ledgered the task, so a rejected duplicate never re-uploads. Cleanup of the 2 dupes: `inboxclean paperless --backfill --prune` (keeps oldest per checksum)
- **Layer 1 SSO (native OIDC via Pocket ID, 2026-09-02):** django-allauth `openid_connect` provider; client `paperless` registered in `pocket-id.nix` (callback `/accounts/oidc/pocket-id/login/callback/`, PKCE both sides — allauth URL routing fixes the callback path). `PAPERLESS_SOCIAL_AUTO_SIGNUP=true` provisions the user on first login (first passkey login verified live 2026-09-02). **SSO-ONLY (user decision: "I do not like password logins"):** `PAPERLESS_DISABLE_REGULAR_LOGIN=true` + `PAPERLESS_REDIRECT_LOGIN_TO_SSO=true` ride in the SAME runtime env file as the client secret — a degraded bridge (secret missing → condition-skip → file absent) AUTOMATICALLY restores the password form as break-glass; SSO fully on or fully off, never a locked-out middle. **`REDIRECT_LOGIN_TO_SSO` is a CLIENT-SIDE redirect** — the login template auto-submits the first provider form via JS; there is NO 302. The login page answers 200 with provider form + `getElementById` auto-submit script and NO `type="password"` input — exactly the Gatus + post-deploy smoke signals (a password field reappearing = bridge degraded = break-glass serving). `DISABLE_REGULAR_LOGIN` does NOT cover the Django admin nor API password login: Caddy hard-blocks `/admin/*` (403, live-verified); the REST API keeps password auth for mobile-app compatibility. The provider JSON carries the client secret, so the `paperless-oidc-setup` oneshot (LoadCredential → jq injection) writes `/var/lib/paperless-oidc/pocket-id.env`, attached to all 4 paperless units via `EnvironmentFile = [-...]`. **The env file must NEVER go through the nixpkgs module's `environmentFile` option** — the `paperless-manage` wrapper bash-`source`s that file, and bash strips the inner quotes of raw JSON (`{"a":"b"}` → `{a:b}`, verified) which then fails `json.loads` in Django settings and breaks every manage command incl. the daily exporter; systemd's EnvironmentFile parser takes unquoted values literally, hence direct unit attachment. `server_url` is the BARE issuer (allauth's `wk_server_url` appends `/.well-known/openid-configuration` when the URL lacks `/.well-known/`); `token_auth_method = client_secret_basic` pinned per the paperless v3 migration note. Break-glass without redeploy (root): `rm /var/lib/pocket-id/client-secrets/paperless && systemctl restart paperless-oidc-setup paperless-web` → password form returns; restore via `systemctl restart pocket-id-provision paperless-oidc-setup paperless-web`.
- **PostgreSQL backend** (`database.createLocally`, shared with Immich, peer-auth unix socket — no password secret). **The engine-switch bootstrap trap (live incident 2026-08-18):** the nixpkgs scheduler preStart gates `manage.py migrate` on `${dataDir}/src-version` and `manage_superuser` on `${dataDir}/superuser-state` — BOTH survive an engine swap and match (same package version/password), so a fresh PG DB gets NO tables and NO admin: scheduler crash-loops `UndefinedTable: relation "auth_user" does not exist` and web/consumer/task-queue fail as dependencies. `paperless-sqlite-to-pg-migration` oneshot (ConditionPathExists on legacy `db.sqlite3`) drops BOTH files so the bootstrap re-runs once; remove `db.sqlite3*` after PG proves stable to self-neutralize it
- **Paperless AI on the NPU LLM:** `PAPERLESS_AI_LLM_*` → FastFlowLM (`:52625/v1`, model from `config.services.fastflowlm.model`), dummy API key `fastflowlm-local-no-auth` (llama-index requires a key; flm ignores Authorization entirely — binary-verified). `PAPERLESS_AI_LLM_REQUEST_TIMEOUT = 480` because socket-activation cold-loads 21.6 GB (2-5 min; raised from 300s with v1.0.2 — the old value sat exactly at the worst-case boundary). **UI-saved values OVERRIDE env vars** (`paperless/config.py`: `app_config.x or settings.X` — DB rows beat env), so env-var changes appear dead if the settings UI ever saved a value. **AI capability audit + adoption roadmap (2026-10-02): `docs/research/2026-10-02_paperless-ngx-ai-deep-dive.html`** — adoption score 42/100; the actionable items are queued in TODO_LIST.md/docs/todo/services.md (workflow automation, paperless-gpt extraction, env hygiene, vision OCR); Azure remote OCR + clusterzx/paperless-ai were evaluated and rejected there (finding #7)
- **Embeddings (RAG semantic search) on llama-server (GPU):** `PAPERLESS_AI_LLM_EMBEDDING_*` → llama-server embeddings instance (`:8848/v1`, model `bge-m3`), dummy API key `llama-server-no-auth`. Served by the `llama-rag` module — two lightweight llama-server instances (embeddings + reranker) on the GPU (ROCm). See the llama-rag section below. **llama-rag config-DISABLED 2026-09-16** (mid-load spin regression, see the llama-rag section) — these env vars now point at a dead endpoint; paperless-ai disables RAG gracefully until the module is re-enabled
- **Outbound email rides the mail relay (2026-09-02):** `PAPERLESS_EMAIL_*` → `127.0.0.1:25` when `services.mail-relay` is enabled (VM tests / relay-less hosts omit the block entirely — Django keeps its inert localhost default). Share links + account mails; see the Mail Relay section. **Inbound mail consumption is UI-configured** (Settings → Mail accounts/rules; poll cron `PAPERLESS_EMAIL_TASK_CRON`, default */10) — needs a mailbox decision, nothing to deploy
- **Every `paperless-manage` invocation runs a deployment WRITE-PROBE into DATA_DIR (2026-09-16):** paperless-ngx 3.1.x `src/paperless/checks.py:33` writes `__paperless_write_test_<pid>__` into DATA_DIR on EVERY manage call — any unit that execs `paperless-manage` under `ProtectSystem=strict` needs `ReadWritePaths = [ cfg.dataDir ]` (+ `unitConfig.RequiresMountsFor`, which also satisfies mount-gating-audit). Symptom when missing: `OSError: [Errno 30] Read-only file system: …__paperless_write_test_…` killing every manage call downstream — the 2026-09-16 `paperless-dashboard-provision` failure (`token mint failed for 'admin'` was pure collateral: the mint rides the same manage wrapper)
- **Tika (9998) + Gotenberg (3199)** via `configureTika` — Office/E-Mail consume path. Ports in `lib/ports.nix` (gotenberg default 3000 collides with forgejo). Resource-tiered (2G MemoryMax, ioTier.background). **Gotenberg 8.36 OTel autoexport trap:** its always-on metrics uploader defaults to `https://localhost:4318` (TLS error against plaintext collector, every 60s) and its autoexport path parses the endpoint as a URL — schemeless `localhost:4318` becomes `https:///v1/metrics` ("no Host"). Unlike code-configured Go otlp*http, it REQUIRES the scheme: `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318`
- **PG-level dump (2026-09-21):** `paperless-db-backup.timer` (nightly 02:00 + jitter, Persistent) runs `pg_dump --format=custom` as postgres (peer auth) onto `/mnt/pool/backups/paperless` (14d retention; pool leaf via the mount-gated `paperless-db-backup-dir` oneshot, deploy.sh provisioner-restarted); backup-coordination watches the dump via the separate `paperless-db` registry entry (the document-exporter manifest check stays independent). miniflux-backup pattern; this is the paperless DR path once the postgres hot-db wave moves the cluster off `@` snapshot coverage.
- **v3 features wired:** `PAPERLESS_TRASH_DIR = ${dataDir}/trash` (30d; tmpfiles rule creates it), barcode splitting (`ENABLE_BARCODES` + `ENABLE_ASN_BARCODE`, PATCHT + Code-39 ASN), `CONSUMER_RECURSIVE`, filename format `{{ created_year }}/{{ correspondent }}/{{ title }}` — v3 REQUIRES double-curly (single-curly still auto-converts via `convert_format_str_to_template_format` but warns on every start; the VM test caught this)
- **Monitoring:** Gatus login-page body check (`pat(*Paperless-ngx sign in*)` + `pat(*oidc/pocket-id*)` SSO button when Pocket ID is enabled — functional, not just 200) + Tika `:9998/` + Gotenberg `:3199/health`, all Discord-alerting; 6 services in system-health `monitoredServices`; deploy smoke in `post-deploy-check.sh` (login body + SSO button + both sidecars). **The mail-wiring smoke was a permanent phantom-RED until 2026-09-05:** it grepped `/var/lib/paperless/paperless.conf`, a file NOTHING generates — the nixpkgs module renders `services.paperless.settings` as `Environment=` directives in the deployed unit (verified live), and `/var/lib/paperless` is the legacy pre-pool dataDir anyway. The check now greps `/etc/systemd/system/paperless-web.service` (symlink to the store unit) and has been PASSING continuously since the 2026-09-05 fix — current status: mail wiring verified, no action pending. Rule: probe the surface the config actually lands on — verify the delivery mechanism before writing a file-path assertion
- **Old SQLite data:** pre-PG export sits in `/mnt/pool/services/paperless/export`; recover via `document_importer` if wanted (user decision pending). Old traps still true: flakes only see TRACKED files (`git add` new modules at write time); hardened oneshots get scratch space from `mktemp -d`, never host paths under `ReadWritePaths` (status 226)

## AI enrichment bridge: paperless-gpt (2026-10-02, AI-max plan A8)

`services.paperless-gpt` (module `paperless-gpt.nix`, loopback :8106, NO vHost —
the embedded UI has no auth) adds what native paperless AI cannot do: custom-field
extraction (Append/Update/Replace write modes) and tag-gated background
processing (`paperless-gpt-auto` → `paperless-gpt-auto-complete`; retry cap 3 →
`paperless-gpt-failed`). Package: `pkgs/paperless-gpt.nix` from the tag-pinned
`paperless-gpt-src` input (v0.28.0, MIT). Token: runtime-minted
(`paperless-gpt-token` oneshot, bank-sync pattern — zero sops). LLM: FastFlowLM
(qwen3.6-moe) via the OpenAI-compatible path; suggestion language pinned German.
Safe defaults: `CREATE_NEW_TAGS=false` (existing vocabulary only) +
`PRESERVE_EXISTING_METADATA=true`. Vision OCR options exist but stay OFF
(`ocrProvider = "off"`) until the B56 eval — and note the CONSTRAINT: the openai
vision provider shares OPENAI_BASE_URL with the main LLM, so llama-vlm is NOT
reachable as paperless-gpt's vision backend; the viable path is the ollama
provider (qwen2.5vl:3b is already pulled).

**Stage-0 eval (A3):** `sudo scripts/paperless-ai-stage0-eval.sh` renders the
per-field suggestion-quality table for 10 representative docs via
`GET /api/documents/<id>/ai_suggestions/` (read-only — computes, never applies).
Includes the reasoning-burn check (empty suggestions = the qwen3.6-moe
think-token signature). Run it before enabling the Apply-AI-suggestions
workflow (A4 gate).

**Quarterly re-audit (A24):** re-run the adoption audit
(`docs/research/2026-10-02_paperless-ngx-ai-deep-dive.html` baseline, score
42/100) every quarter — next due 2027-01-02. Check: native AI version delta
(new suggestion targets?), paperless-gpt release notes (upstream is ACTIVE),
flm consumer count vs the connection budget in `docs/services/fastflowlm.md`.

## llama-vlm live verification (A15, 2026-10-02)

First verified inferences since system-796: :8128 (Qwen3-VL-8B captioner) —
correct image description in 100s/image, cold load 5m07s, 8.9 GB RSS.
:8127 (Gemma-4-E4B) — text-only works (35s for a 5-token answer), but the
VISION path exceeds 10 MINUTES per 32x32 image (mmproj processing as
configured; n_slots=4 CPU split suspected) — do NOT wire it into any vision
pipeline without a slot/parallelism retune; the captioner is the vision
workhorse. Both sockets survived sustained load without wedge (24 min soak).
