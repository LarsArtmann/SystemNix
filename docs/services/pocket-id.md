# pocket-id (passkey-only OIDC IdP)

**Service:** `services.pocket-id-config` — `modules/nixos/services/pocket-id.nix` (wrapper over nixpkgs `services.pocket-id`). Port 1411 (`lib/ports.nix` `pocket-id`), Prometheus metrics on 9464 (`pocket-id-metrics`, loopback). URL: `auth.<domain>` — a **hand-written** Caddy vHost in `caddy.nix` (`vHost.layer = "none"` in the registry) that splits `/oauth2/*` to oauth2-proxy (:4180) and everything else to :1411. DNS `auth` in `platforms/common/dns-local.nix`.

The SSO backbone: every Layer 1 (native OIDC) and Layer 2 (forward-auth) consumer trusts it. Pocket ID down ⇒ no new logins fleet-wide (existing app sessions keep working). Layer semantics, CIMD decision, `email_verified`/`groups` claim facts live in [docs/agents/sso-dns.md](../agents/sso-dns.md).

## What it serves

| Route            | Auth                                | What                                                                    |
| ---------------- | ----------------------------------- | ----------------------------------------------------------------------- |
| `/`              | Pocket ID session (passkey)         | Admin UI (users, clients, groups) — READ-ONLY: `UI_CONFIG_DISABLED` env |
| `/healthz`       | none                                | Liveness (ExecStartPost gate, Gatus)                                    |
| `/metrics`       | none (port 9464)                    | Prometheus: pocket-id self-metrics                                      |
| `/.well-known/*` | none                                | OAuth2/OIDC discovery — the consumer gate probes this                   |
| `/oauth2/*`      | none (Caddy routes to oauth2-proxy) | The oauth2-proxy leg of `auth.<domain>`                                 |
| `/api/*`         | `STATIC_API_KEY` (provisioner only) | Provisioning API                                                        |

## Ops

- **Declarative provisioner** — `pocket-id-provision` (oneshot, `RemainAfterExit=true`, root, `after`/`wantedBy` pocket-id; deploy.sh restarts it every deploy). Seeds the admin user + avatar, creates/updates OIDC clients (`oidcClients` default = `oauth2-proxy` only; every other client fans in via `services.integration.<name>.oidc` → `extraOidcClients`), and `PUT`-replaces **user group membership authoritatively** (a member missing from the list is removed — membership edits belong in the module, not the UI). Re-run manually: `sudo systemctl restart pocket-id-provision` (`start` is a no-op while `RemainAfterExit` holds).
- **Client secrets: multi-secret API, PLURAL** — `POST /api/oidc/clients/{id}/secrets` returns the secret exactly once (old singular `/secret` route 404s on pocket-id ≥ 2.x — the 2026-09-02 incident where every newly-provisioned client silently got no secret). Secrets land in `/var/lib/pocket-id/client-secrets/<clientId>` (0640 `pocket-id:pocket-id`, atomic mktemp+mv).
- **Secret desync recovery** — stale secret file vs DB: set `services.pocket-id-config.provision.regenerateSecretsFor = [ "<clientId>" ]`, deploy (provision run rotates + rewrites the file), then **clear the list** (or it rotates every deploy). Consumers binding the secret via `LoadCredential`/env-file need a unit RESTART after rotation — the deploy.sh secret-bridge blocks own that ordering.
- **"Client does not exist" ≠ secret desync** — probe `GET /authorize?client_id=…`: 302 to `/interaction` = client row OK (suspect the secret); error redirect = the client ROW vanished. SQLITE_BUSY crash chains can drop rows (2026-08-22); the provisioner self-heals by recreating. Distinguish before touching secrets.
- **SQLITE_BUSY storms** — Pocket ID's SQLite locks under machine-wide IO pressure (zram-full evenings). `system_pocket_id_busy_*` metrics (system-health) + Gatus "Pocket ID SQLite Health" page when the storm is sustained; it drains with the pressure — do not restart into a storm, the WAL clear in ExecStartPre makes restarts cheap but does not fix the cause.
- **Config is ENV-ONLY** (`UI_CONFIG_DISABLED=true`) — the admin UI "Application Configuration" page is read-only; all app config (SMTP, passkeys, CIMD) comes from the module env. SMTP facts: `SMTP_*` env vars are read ONLY in env-mode (else every send fails `SMTP host is not configured`); the password rides the sops credential via systemd-creds (`systemd-creds cat` at start) and never enters the sqlite DB or its backups. **A bad SMTP env value fails `validateEnvConfig` at boot = IdP down = fleet-wide SSO outage — check `journalctl -u pocket-id` right after any `smtp.*` change.**
- **CIMD stays disabled** — `CIMD_URL_ALLOWLIST = "[]"` pin (owner decision 2026-09-17; rationale + revisit trigger in sso-dns.md).
- **Units** — `pocket-id` (ExecStartPre `+`clearStaleWal + `+`checkEncryptionKey, ExecStartPost healthz poll, 180s timeout, MemoryMax 1G / GOMEMLIMIT 768MiB, StartLimit 5/600s); `pocket-id-secret-rotation` (1h timer; 90d freshness over the client-secret files → `secret_rotation_all_fresh` textfile metric; Gatus "Secret Rotation Health" — does NOT auto-rotate); `pocket-id-backup` (04:00 nightly, WAL-safe `sqlite3 ".backup"` → `/mnt/pool/backups/pocket-id`, 14d retention, backup-coordination row maxAge 25h).
- **Secrets (sops `platforms/nixos/secrets/pocket-id.yaml`)** — `pocket_id_encryption_key`, `pocket_id_smtp_password`, `pocket_id_static_api_key` (the last is REQUIRED by an eval assertion when provision is enabled). Rotation of the encryption key invalidates all client secrets + sessions — treat as break-glass.
- **Paperless SSO-only eval assertion** — the module asserts the `paperless` OIDC client exists with PKCE + the exact callback whenever paperless is enabled (paperless has password login disabled; a missing client would lock everyone out with no fallback).

## Related

- [docs/agents/sso-dns.md](../agents/sso-dns.md) — layer architecture, CIMD decision, `email_verified` (per-user, defaults FALSE) and `groups`-scope claim facts
- [oauth2-proxy.md](./oauth2-proxy.md) — the Layer 2 consumer side; its client secret comes from this provisioner
- [docs/agents/secrets.md](../agents/secrets.md) — sops workflow for the three keys above
- Pocket ID facts for consumers (client-row vanish, secret desync narratives): `docs/gotchas-archive.md` "Pocket ID" bullets
