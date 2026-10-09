# SSO / OIDC & Reverse Proxy — Agent Reference

> Migrated verbatim from AGENTS.md on 2026-10-01 (restructure).
> **Read when:** touching Pocket ID, oauth2-proxy, any vHost auth layer (Layer 0/1/2 decisions), Caddy config, or debugging double-auth/redirect-loop/`invalid_client` issues. DNS (dnsblockd) specifics live in [docs/services/dnsblockd.md](../services/dnsblockd.md).

## Index

- [SSO / OIDC Architecture (layers, adding Layer 1, Pocket ID facts)](#sso--oidc-architecture)
- [Caddy & Reverse Proxy gotchas](#caddy--reverse-proxy)
- [SSO / OIDC gotchas](#sso--oidc)
- [Misc vHost exemptions](#misc-vhost-exemptions)

## SSO / OIDC Architecture

Two SSO layers, both backed by **Pocket ID** (passkey-only OIDC IdP at `auth.<domain>`):

| Layer                                   | How                                                                                                                                                                       | Services                                                                           |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **Layer 0 — No auth (LAN-only)**        | Read-only public data, no auth needed. Caddy uses plain `reverse_proxy` or `file_server`. No SSO integration                                                              | **systemd-graph**, **systemd-timer-monitor**                                       |
| **Layer 1 — Native OIDC**               | App integrates directly with Pocket ID (in-app login button). Provisioned as OIDC clients in `pocket-id.nix`; Caddy uses **plain `reverse_proxy`** (NOT `protectedVHost`) | Forgejo, **Gatus**, **Browser History**, **Paperless**, **CV**                     |
| **Layer 2 — oauth2-proxy forward-auth** | App has no native auth; Caddy `protectedVHost` gates external access behind a Pocket ID login. LAN access is open                                                         | Homepage, Taskchampion, OpenSEO†, Crush Daily, Monitor365, **SearXNG**, **SigNoz** |

> **SigNoz** runs in impersonation mode (every request = root admin, no internal auth). OIDC is Enterprise-only ($4k/mo). Uses standard Layer 2 `protectedVHost`: LAN bypass (direct proxy), external forward-auth via oauth2-proxy. The previous unconditional forward-auth (no LAN bypass) caused 500 errors for ALL users when oauth2-proxy hiccuped — `protectedVHost` fixes this by keeping LAN traffic off the oauth2-proxy path entirely.

> **†** OpenSEO uses a **hand-rolled Caddy vHost** (not `protectedVHost`) to exempt `/api/gsc/oauth/callback` from forward-auth — see gotcha table. All other paths follow standard Layer 2 behavior (forward-auth for external clients, LAN bypass).

> **Immich** is a deliberate HYBRID (runbook: `docs/services/immich.md`): native OIDC in-app (password login disabled, auto-launch) but routed via the registry's **Layer 2 protected** vHost. External browsers pass forward-auth first, then the auto-launch OIDC flow reuses the live `auth.<domain>` session; LAN + the mobile app (`app.immich:///oauth-callback` — a native OIDC flow that cannot carry forward-auth cookies) bypass forward-auth entirely. It is the ONE sanctioned exception to the "native OIDC ⇒ plain reverse_proxy" rule.

**Adding Layer 1 (native OIDC) to a service** — follow the gatus/paperless pattern:

1. Register the OIDC client in `pocket-id.nix` `provision.oidcClients` (clientId, callbackURLs)
2. The provisioner writes the client secret to `/var/lib/pocket-id/client-secrets/<clientId>` (owned `pocket-id:pocket-id`, 640)
3. The service reads it: either via upstream `_secret` (immich), a runtime script `cat` (forgejo), or systemd `LoadCredential` (gatus — needed because gatus is a **DynamicUser** that can't own files)
4. Order the service `after`/`wants` `pocket-id-provision.service`
5. **In Caddy, use plain `reverse_proxy`** (like Forgejo/Gatus), NOT `protectedVHost` — a service with native OIDC behind `protectedVHost` causes a **double-auth** conflict

**Native OIDC is NOT free for most services** — verify upstream support before assuming:

- Homepage: no built-in auth at all (proxy-only by design)
- SigNoz: OIDC Enterprise-only ($4k/mo). Runs in impersonation mode (no internal auth). Uses Layer 2 `protectedVHost` — LAN bypass + external forward-auth
- Twenty: SSO gated behind a billing entitlement
- Custom LarsArtmann Go services: require upstream OIDC code in their repos

**Pocket ID `email_verified` is PER-USER and DEFAULTS TO FALSE (fleet-wide fact, 2026-09-30).** Pocket ID emits the `email` + `email_verified` claims whenever the client holds the `email` scope (source-verified claims_service.go), but `email_verified` is a per-user DB column added by migration `20260109090200` with `DEFAULT FALSE` — only Pocket ID's own SMTP verification flow or an admin toggle in the Users UI sets it true. ANY relying party whose allow-list matches on "verified email" (GeoMetrikks `OIDC_ALLOWED_USERS`, upstream `check_allow_list`: subject always, email only when `email_verified is True` strict boolean, else groups) therefore rejects EVERY login until either the user flips verified in the Pocket ID admin UI or the allow-list also carries the subject id (`sub` = the `users.id` UUID). GeoMetrikks auto-resolves the subs at bridge time (see its section); miniflux links by sub (`miniflux-oidc-setup`). Never trust an email-shaped allow-list entry against Pocket ID without checking `email_verified`.

**Pocket ID `groups` claim REQUIRES the `groups` scope (fleet-wide fact, 2026-10-01).** Pocket ID emits the `groups` claim **only when the requesting client holds the `groups` scope** (source-verified `claims_service.go`: `if slices.Contains(scopes, "groups")`) — without the scope the claim is simply absent, not empty. A relying party that maps IdP membership to local roles must (a) add `groups` to the client's requested scope (allauth `SCOPE`, oauth2-proxy `scope`, …) and (b) declare the group via `services.pocket-id-config.provision.userGroups` (provisioner Step 4 creates it and authoritatively `PUT`s membership). The group name must match the consumer's expected literal exactly; paperless maps it FAIL CLOSED (`PAPERLESS_SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP`, demotes on a missing/empty claim) — see `docs/services/paperless.md`.

**Single Logout (SLO) is partial, not coordinated.** Layer 2 apps share the oauth2-proxy session cookie (`.${domain}`) — logging out via oauth2-proxy's `/oauth2/sign_out` clears them together. Layer 1 apps (Forgejo, Immich, Gatus) each keep their **own** session cookie and do NOT participate in coordinated logout — visiting them after an IdP logout may still show the cached app session until it expires or the user explicitly logs out per-app. Pocket ID supports RP-initiated logout, but wiring it into every Layer 1 app's logout flow is per-app work and not currently done.

**CIMD (Client ID Metadata Documents) — deliberately DISABLED (decision 2026-09-17).** Pocket ID 2.13.0+ (#1526, MCP-driven) lets an OAuth client self-register by using an HTTPS URL as its `client_id`; the IdP fetches that URL for the client's metadata (name, redirect URIs). It solves "clients we have no relationship with" — a problem our setup does not have: every client is first-party and preregistered via `pocket-id-config.provision` with pinned callbacks + provisioned secrets. Enabling it would add a phishing vector (client name/logo are self-asserted, draft §6.4), an SSRF surface on the IdP (§6.5), and — because Pocket ID does NOT enforce any redirect-URI↔client_id-URL relationship (only wildcard/js/data-scheme rejection) — the allowlist is the ONLY scope control. Facts for future sessions: the gate is the app-config key `cimdUrlAllowlist` (default `"[]"` = block all, fail-closed; `backend/internal/appconfig/model.go`; our module runs `UI_CONFIG_DISABLED = true` (app config is ENV-ONLY — the "Application Configuration" admin UI is inert), so the pin IS declarative: the module carries `CIMD_URL_ALLOWLIST = "[]"` since 2026-09-17 (commit 51cb393a, upstream-default-drift insurance; runtime-IDENTICAL to leaving it UNSET at the fail-closed `"[]"` default — both stances valid, an earlier same-day doc note preferred UNSET; pick one stance on the next docs pass). The well-known endpoint advertises `client_id_metadata_document_supported` = `len(allowlist) > 0` (verified live `false` on 2.14.0 — MCP clients see no support). Revisit trigger ONLY when an MCP-style OAuth consumer appears (e.g. Hermes mcp extras against a Pocket-ID-fronted MCP server) — then enable with EXACT metadata-document URLs (never wildcards), the draft §6.10 pre-registration pattern; live check: `curl -s https://auth.home.lan/.well-known/oauth-authorization-server | jq '."client_id_metadata_document_supported"'`.

## Caddy & Reverse Proxy

- **`handle_path` STRIPS prefix** — Use `handle` when backend expects full path.
- **`${commonConfig}` required on ALL vhosts** — Security headers, compression, `-Server` suppression. Auto-applied by `protectedVHost`; manual vhosts must include explicitly.
- **`proxyTo` is canonical** — ALL `reverse_proxy` directives use `${proxyTo PORT}`. Never bare `reverse_proxy` — it omits `X-Real-IP`.
- **`auto_https off`** — `:80` catch-all vhost handles HTTP→HTTPS redirect. TLS certs are sops-managed, not ACME.
- **`tlsConfig`** — Enforces TLS 1.2+. `strict_sni_host on` prevents serving certs for unrecognized hostnames.
- **Admin API (port 2019) intentionally unauthenticated** — Firewalled out (only 80/443 open). `admin off` would kill `/metrics`.
- **Native OIDC services use plain `reverse_proxy`** — NOT `protectedVHost`. Forward-auth + native OIDC = double-auth loop.

## SSO / OIDC

- **Native OIDC is NOT free** — Verify upstream support: Homepage (no auth), SigNoz (Enterprise-only, impersonation mode + Layer 2), Twenty (billing-gated), SearXNG (no accounts). All four stay on Layer 2 forward-auth.
- **SigNoz Layer 2 — never use unconditional forward-auth** — SigNoz uses `protectedVHost` (LAN bypass + external forward-auth). The previous unconditional forward-auth (no LAN bypass) caused 500 errors for ALL users when oauth2-proxy hiccuped. `protectedVHost` keeps LAN traffic off the oauth2-proxy path entirely, so oauth2-proxy failures only affect external access.
- **Gatus native OIDC + DynamicUser** — Secret via `LoadCredential` (can't own files). Self-health probe must use `[STATUS] < 400` (302 redirect when OIDC on).
- **Forgejo OIDC** — Native OIDC via `forgejo-oidc-setup` oneshot. Auth source name ("PocketID") IS the URL slug — no spaces. `ENABLE_AUTO_REGISTRATION = true`.
- **Pocket ID client-secret desync** — Declarative recovery: `pocket-id-config.provision.regenerateSecretsFor = [ "clientId" ]`. `RemainAfterExit=true` makes `start` a no-op — use `RESTART`.
- **Pocket ID provisioner secret generation uses the MULTI-SECRET API (fixed 2026-09-02): `POST /api/oidc/clients/{id}/secrets` (PLURAL, optional body, 201 returns `.secret` exactly once)** — the old singular `/secret` route 404s on current pocket-id. Symptom of the stale route: client created/updated fine, then `ERROR: Failed to generate secret for 'X'` every provision run — every client FIRST provisioned after the pocket-id bump silently got no secret (Paperless was the first new client since the bump; forgejo/gatus/dnsblockd secret files predated it).
- **A value-less metric line ("`metric` + empty var") makes node_exporter reject the WHOLE textfile (live 2026-09-02)** — the system-health forgejo journal-scan failure path emptied only `FORGEJO_MIRROR_ERRORS_30M`/`ERRORING` while the emission block was gated on the non-empty `LAST_SYNC_AGE`, emitting `system_forgejo_mirror_errors_30m` with no value: invalid exposition syntax, so ALL 38 system_* metrics went dark at once (gatus red fleet-wide, every deploy blocked at pre-deploy §10). Rule: EVERY conditionally-computed metric must be emitted only when its OWN variable is non-empty (fail-closed absence), and sibling metrics set/emptied TOGETHER must be gated TOGETHER. **State-file round-trips defeat per-site helpers (2026-09-20)**: the nrestarts state WRITER bypassed `systemctl_value`'s `[not set]` guard, persisted literal `[not set]` rows, and the emitter re-served them raw — node_exporter rejected system_health.prom whole (node_textfile_scrape_error=1, seven system_* metrics dark across deploys) while every eval stayed green. Sanitize at BOTH sides of any persisted round-trip (integer `case "$v" in *[!0-9]*)` guards at write AND emit), never assume a guard at one call site covers another. The §10 gate now keys on positive infra signals instead of hard-failing: `node_textfile_scrape_error=1` (whole textfile rejected → absent metrics are warnings + the offending value-less lines are printed) and `system_forgejo_mirror_scrape_errors=1` (journal scan failed → its pair absent BY DESIGN).
- **oauth2-proxy `--whitelist-domain=.${domain}` REQUIRED** — Without it, post-login redirect fails with 500.
- **oauth2-proxy `partOf` pocket-id-provision** — `LoadCredential` secrets need service restart when regenerated.

## Misc vHost exemptions

- **OpenSEO GSC callback** — Hand-rolled Caddy vHost (NOT `protectedVHost`) to exempt `/api/gsc/oauth/callback` from forward-auth. Do NOT simplify.
