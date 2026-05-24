# ADR-007: Authelia → Pocket ID Migration

**Date:** 2026-05-24
**Status:** Accepted

## Context

SystemNix used Authelia as its sole identity provider since the project's inception. Authelia provided two roles in one service:

1. **OIDC Provider** — OAuth2/OpenID Connect issuer for Immich, Forgejo, and any future OIDC clients
2. **Forward-Auth Proxy** — Caddy's `forward_auth` directive called Authelia's `/api/authz/forward-auth` to gate external access to all protected vhosts

Authelia's configuration was file-based (YAML `users_database.yml`, inline Nix settings), required manual bcrypt hashing for client secrets, and supported multiple 2FA methods (TOTP + WebAuthn) — over-engineered for a single-user homelab.

Pocket ID is a passkey-only OIDC provider (Go backend, SQLite, web UI). It does NOT include a forward-auth endpoint, requiring a separate component for Caddy integration.

## Decision

Replace Authelia with Pocket ID + oauth2-proxy:

| Role | Before | After |
|------|--------|-------|
| OIDC Provider | Authelia | Pocket ID |
| Forward Auth | Authelia `/api/authz/forward-auth` | oauth2-proxy `/oauth2/auth` |
| User Backend | YAML file (`users_database.yml`) | Pocket ID SQLite (web UI) |
| 2FA | TOTP + WebAuthn (configurable) | Passkey-only (WebAuthn/FIDO2) |
| Client Management | Nix declarative (`mkClient`) | Pocket ID web UI / REST API |
| Session | Authelia cookie (1h / 5min inactivity) | oauth2-proxy cookie (domain-wide) |

### Architecture

```
External Request → Caddy
  → forward_auth localhost:4180 { uri /oauth2/auth }
  → oauth2-proxy validates session cookie
  → (if no cookie) returns 401
  → (if valid) injects X-Auth-Request-User/Email headers
  → reverse_proxy to backend service
```

oauth2-proxy acts as OIDC client to Pocket ID (`provider = "oidc"`, `oidcIssuerUrl = "https://auth.${domain}"`). Cookie domain is `.${domain}` so one login covers all subdomains.

### Ports

- Pocket ID: 1411 (matches upstream default)
- oauth2-proxy: 4180 (standard)

## Alternatives Considered

- **Keep Authelia**: Works but over-engineered. File-based user management, no web UI, hardcoded bcrypt secrets, TOTP complexity unnecessary for single user.
- **Authentik**: Full IAM with visual flow builder. Too heavy (~600MB-1GB RAM), Python-based (slow startup), SAML/federation not needed.
- **Keycloak**: Enterprise-grade IAM. Extreme overkill (400MB-2GB+ RAM), steep learning curve, Java-based.
- **Pocket ID + caddy-security plugin**: Would require custom Caddy build with plugin.oauth2-proxy is already in nixpkgs with a NixOS module, no custom builds needed.
- **Pocket ID only (no forward-auth)**: Would require every backend service to implement OIDC natively. Most self-hosted apps (Homepage, SigNoz, Manifest, etc.) don't support OIDC natively.

## Consequences

### Positive

- **Passkey-only**: Eliminates passwords, TOTP secrets, and password management entirely
- **Web UI**: User and client management through Pocket ID's admin UI instead of editing YAML
- **Lighter**: Go binary + SQLite vs Authelia's heavier stack
- **REST API**: Pocket ID exposes API (`/api/oidc/clients`) for future declarative client provisioning
- **Security**: Upstream NixOS module already includes comprehensive systemd hardening

### Negative

- **Extra dependency**: Two services (Pocket ID + oauth2-proxy) where Authelia was one
- **No auto-redirect**: oauth2-proxy `/oauth2/auth` returns 401 (not 302) for unauthenticated requests. Users must visit `auth.${domain}` first to establish a session. Authelia auto-redirected browsers.
- **Manual client management**: OIDC clients created via web UI, not declarative in Nix. Authelia's `mkClient` was GitOps-friendly.
- **Header divergence**: `X-Auth-Request-User/Email` vs Authelia's `Remote-User/Groups/Email/Name`. Currently no service uses `Remote-Groups` or `Remote-Name`, but future services might need adaptation.
- **Staged deployment required**: Cannot deploy in one shot. Must bootstrap Pocket ID → create clients → enable oauth2-proxy.

### Mitigations

- Forward-auth UX: Document that users must visit `auth.${domain}` first. Cookie persists across all subdomains.
- Client management: Pocket ID REST API exists for future declarative provisioning script (follows SigNoz `signoz-provision` pattern).
- Headers: Caddy's `copy_headers` can be extended if services need additional claims.
