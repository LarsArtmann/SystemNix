# Pocket ID Declarative Configuration Plan

**Goal:** Make Pocket ID as reproducible as possible via Nix. Maximize declarative config, minimize manual `/setup` steps.

**Constraint:** Passkey/YubiKey registration requires physical device interaction → always manual. Everything else should be Nix-declared.

---

## Current State

| What | Status | Where |
|------|--------|-------|
| Service config (ports, proxy, analytics) | ✅ Declarative | `modules/nixos/services/pocket-id.nix` |
| Encryption key | ✅ Declarative | `sops secrets.pocket_id_encryption_key` |
| oauth2-proxy client secret | ✅ Declarative | `sops secrets.oauth2_proxy_client_secret` |
| oauth2-proxy cookie secret | ✅ Declarative | `sops secrets.oauth2_proxy_cookie_secret` |
| immich OAuth client secret | ✅ Declarative | `sops secrets.immich_oauth_client_secret` |
| Admin user (username, email, name) | ❌ Manual | Created at `/setup` interactive page |
| Avatar | ❌ Manual | Uploaded via web UI |
| OIDC client records in Pocket ID DB | ❌ Manual | Created via admin UI |
| Passkeys / YubiKey | ❌ Manual | Physical device ceremony via browser |
| Backup/restore workflow | ❌ Missing | No `just` recipes |

---

## Plan: All Tasks Sorted by Priority

Priority formula: `(Impact × CustomerValue) / Effort` — higher is better.

| # | Task | Impact | Effort | Value | Priority | Phase | Deps |
|---|------|--------|--------|-------|----------|-------|------|
| 1 | Add `STATIC_API_KEY` to sops secrets | 10 | 2 | 10 | **50.0** | Foundation | — |
| 2 | Wire `STATIC_API_KEY` into pocket-id module | 10 | 2 | 10 | **50.0** | Foundation | #1 |
| 3 | Add missing env vars (LOG_LEVEL, VERSION_CHECK_DISABLED, AUDIT_LOG_RETENTION_DAYS) | 5 | 3 | 6 | **10.0** | Config | — |
| 4 | Pin `DB_CONNECTION_STRING` and `UPLOAD_PATH` explicitly | 6 | 2 | 7 | **21.0** | Config | — |
| 5 | Research Pocket ID API: user create, OIDC client create, avatar upload endpoints | 9 | 6 | 9 | **13.5** | Research | #2 |
| 6 | Create `pocket-id-provision` systemd service skeleton | 8 | 4 | 8 | **16.0** | Provision | #2, #5 |
| 7 | Implement admin user creation via API in provision service | 9 | 6 | 9 | **13.5** | Provision | #5, #6 |
| 8 | Implement OIDC client creation (oauth2-proxy, immich) via API in provision service | 9 | 6 | 9 | **13.5** | Provision | #5, #6 |
| 9 | Implement avatar seeding (copy `assets/avatar.png` → upload path) in provision service | 6 | 4 | 7 | **10.5** | Provision | #4, #6 |
| 10 | Make provision service idempotent (check-before-create) | 7 | 5 | 8 | **11.2** | Provision | #6–9 |
| 11 | Add `just pocket-id-export` recipe | 5 | 2 | 6 | **15.0** | Backup | — |
| 12 | Add `just pocket-id-restore` recipe | 5 | 2 | 6 | **15.0** | Backup | — |
| 13 | Add assertion: `STATIC_API_KEY` required when `provision.enable` | 4 | 2 | 5 | **10.0** | Safety | #6 |
| 14 | Add `dataDir` + tmpfiles rule explicitly in module | 4 | 2 | 5 | **10.0** | Config | — |
| 15 | Update `just auth-bootstrap` to use provision service | 6 | 3 | 7 | **14.0** | UX | #6–10 |
| 16 | Update AGENTS.md with full declarative workflow | 5 | 4 | 7 | **8.8** | Docs | #11–15 |
| 17 | Test compilation: `just test-fast` | 3 | 3 | 5 | **5.0** | Test | #1–4, #13–14 |
| 18 | Test provision service on live system | 8 | 8 | 9 | **9.0** | Test | #6–10 |
| 19 | Verify OIDC auth works end-to-end after provision | 7 | 5 | 8 | **11.2** | Test | #18 |
| 20 | Verify avatar renders correctly | 4 | 3 | 5 | **6.7** | Test | #9, #18 |

---

## Phase Breakdown

### Phase 1: Foundation (Tasks 1–2, 11 min)
Add `STATIC_API_KEY` — this is the keystone. It creates a synthetic admin "Static API User" that can call all Pocket ID APIs. Without this, nothing else in Phase 2 is possible.

**Task 1.1** (5 min): Add `pocket_id_static_api_key` to `platforms/nixos/secrets/pocket-id.yaml`
**Task 1.2** (3 min): Wire it into `modules/nixos/services/pocket-id.nix` via `credentials.STATIC_API_KEY`
**Task 1.3** (3 min): Add `restartUnits = ["pocket-id.service"]` in sops.nix

### Phase 2: Configuration Hardening (Tasks 3–4, 13–14, 17 min)
Make the service config explicit and reproducible.

**Task 2.1** (8 min): Add to `pocket-id.nix` settings:
- `LOG_LEVEL = "info"`
- `VERSION_CHECK_DISABLED = true`
- `AUDIT_LOG_RETENTION_DAYS = "90"`
- `DB_CONNECTION_STRING = "data/pocket-id.db"`
- `UPLOAD_PATH = "data/uploads"`

**Task 2.2** (5 min): Add explicit `dataDir` option in `pocket-id.nix` and wire to upstream module
**Task 2.3** (4 min): Add assertion that `provision.enable` → `STATIC_API_KEY` is set

### Phase 3: API Research (Task 5, 12 min)
Fetch and document the Pocket ID OpenAPI spec. We need exact endpoints for:
- `POST /api/users` — create admin user
- `POST /api/oidc/clients` — create OIDC client
- `POST /api/users/{id}/avatar` — upload avatar
- `GET /api/users/me` — check if admin exists (idempotency)
- `GET /api/oidc/clients` — list existing clients (idempotency)

**Deliverable:** Document endpoints, request bodies, and auth headers in a comment block.

### Phase 4: Provisioning Service (Tasks 6–10, 33 min)
Create a `pocket-id-provision` systemd one-shot (pattern: `signoz-provision`, `forgejo-admin-setup`).

**Task 4.1** (4 min): Skeleton service definition in `pocket-id.nix` — `Type = "oneshot"`, `after = ["pocket-id.service"]`, `wantedBy = ["pocket-id.service"]`
**Task 4.2** (6 min): `preStart` — wait for Pocket ID health (`curl http://127.0.0.1:1411/healthz`)
**Task 4.3** (6 min): Admin user creation — check if user exists, if not `POST /api/users` with username/email/firstName/lastName from Nix options
**Task 4.4** (6 min): OIDC client creation — check if client exists, if not `POST /api/oidc/clients` with name/secret/callback URLs from Nix options
**Task 4.5** (4 min): Avatar seeding — copy `assets/avatar.png` to `/var/lib/pocket-id/data/uploads/` with correct ownership, or POST to avatar endpoint
**Task 4.6** (5 min): Idempotency — grep existing users/clients before creating; skip if present; log actions
**Task 4.7** (2 min): Wire `provision.enable` option in `pocket-id.nix`

### Phase 5: Backup/Restore (Tasks 11–12, 10 min)

**Task 5.1** (5 min): Add `just pocket-id-export` — runs `pocket-id export --path ~/backups/pocket-id-$(date).zip`
**Task 5.2** (5 min): Add `just pocket-id-restore` — stops service, runs `pocket-id import --yes --path <zip>`, restarts

### Phase 6: UX & Documentation (Tasks 15–16, 14 min)

**Task 6.1** (5 min): Update `just auth-bootstrap` — remove manual OIDC client instructions; instead say "run `just switch` then `just pocket-id-export` to backup"
**Task 6.2** (4 min): Update `just auth-status` — add provision service status
**Task 6.3** (5 min): Update AGENTS.md — document the full declarative flow, what is/isn't reproducible, backup/restore procedure

### Phase 7: Testing (Tasks 17–20, 26 min)

**Task 7.1** (5 min): `just test-fast` — syntax check
**Task 7.2** (10 min): `just switch` on evo-x2 — verify service starts, provision runs
**Task 7.3** (8 min): Test OAuth flow — visit protected service, verify redirect to Pocket ID works
**Task 7.4** (3 min): Verify avatar renders on profile page

---

## What Will Still Be Manual

| Item | Why | Mitigation |
|------|-----|------------|
| Passkey/YubiKey registration | WebAuthn requires physical device cryptographic ceremony | One-time at `/setup`; subsequent passkeys can be added in profile settings |
| Avatar re-upload after restore | File upload is a multipart form, not easily API-seeded | Copy file to upload path in provision service; backup captures it |
| API key generation for external tools | Requires admin UI interaction | Use `STATIC_API_KEY` for automation; document manual step |

---

## Nix Options to Add

```nix
options.services.pocket-id-config = {
  provision = {
    enable = mkEnableOption "automatic provisioning of admin user, OIDC clients, and avatar";
    adminUser = mkOption {
      type = types.submodule {
        options = {
          username = mkOption { type = types.str; };
          email = mkOption { type = types.str; };
          firstName = mkOption { type = types.str; };
          lastName = mkOption { type = types.str; };
        };
      };
    };
    oidcClients = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption { type = types.str; };
          clientId = mkOption { type = types.str; };
          callbackURLs = mkOption { type = types.listOf types.str; };
          secretFile = mkOption { type = types.path; };
        };
      });
      default = [
        {
          name = "oauth2-proxy";
          clientId = "oauth2-proxy";
          callbackURLs = [ "https://auth.${domain}/oauth2/callback" ];
          secretFile = config.sops.secrets.oauth2_proxy_client_secret.path;
        }
        {
          name = "immich";
          clientId = "immich";
          callbackURLs = [ "https://immich.${domain}/api/auth/callback" ];
          secretFile = config.sops.secrets.immich_oauth_client_secret.path;
        }
      ];
    };
    avatarFile = mkOption {
      type = types.path;
      default = ../../../assets/avatar.png;
      description = "Path to avatar image to seed for admin user";
    };
  };
};
```

---

## Risk: API Unavailability

If Pocket ID's API does **not** support creating users or OIDC clients via REST, we fall back to:

1. **DB seeding**: Create a pre-populated SQLite DB with the correct schema, encrypted with the `ENCRYPTION_KEY`, and copy it on first boot.
2. **CLI scripting**: Use Pocket ID's Go CLI commands directly if they expose admin/OIDC creation.

The provision service will be written defensively: if API calls fail, it logs warnings and exits 0 (non-blocking). The `auth-bootstrap` just recipe remains as a manual fallback.
