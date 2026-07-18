# SystemNix: Debug Map

**Date:** 2026-04-25 | **Commit:** 0a3c318
**Status:** Resolved — all fixes applied

## The ONE Root Cause

```
AI session (commit 9e09f07) disabled authelia/immich modules
        │
        ▼
sops.nix still referenced authelia_*/immich_* secrets
        │
        ▼
secrets.yaml did NOT contain those keys (never had them)
        │
        ▼
sops-install-secrets fails at build time:
  "the key 'authelia_jwt_secret' cannot be found"
        │
        ▼
CASCADE: everything downstream fails
  ├── Caddy references config.services.immich.port → undefined
  ├── Photomap references config.services.immich.mediaLocation → undefined
  ├── Monitoring references authelia scrape job → no target
  └── Homepage lists auth/immich/photomap cards → dead links
```

## What Was Broken (commit chain)

| Commit    | What it did                                               | What it broke                                                                        |
| --------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `9e09f07` | Disabled authelia, grafana, immich modules                | Left sops.nix, caddy.nix, homepage.nix, monitoring.nix referencing disabled services |
| `55b3b72` | Re-enabled authelia/immich, removed grafana               | sops secrets still missing from secrets.yaml → build fails                           |
| `0f1aa83` | Commented out authelia/immich/photomap to make build pass | Nuked half the infrastructure instead of fixing the root cause                       |

## What I Fixed

1. **Created `platforms/nixos/secrets/authelia-secrets.yaml`** — encrypted with the same age key from `.sops.yaml`. Contains:
   - `authelia_jwt_secret`
   - `authelia_storage_encryption_key`
   - `authelia_oidc_hmac_secret`
   - `authelia_oidc_issuer_private_key`
   - `immich_oauth_client_secret`

2. **`sops.nix`** — each authelia/immich secret now points to the new file via `sopsFile`

3. **Restored all services** — uncommented authelia, immich, photomap in flake.nix, caddy.nix, monitoring.nix

4. **Grafana removal** — already done in previous session (module deleted, caddy vhost removed, homepage card removed, monitoring datasource removed, sops secrets removed, DNS record removed)

## Current State: BUILD PASSES ✅

- `nh os build .` succeeds
- `nix fmt` — 0 changes needed
- All 11 service modules active
- All 7 caddy vhosts active
- All 5 prometheus scrape jobs active
- All 13 sops secrets defined with valid encrypted files
- Zero commented-out code

## Files Changed

| File                                            | Change                                            |
| ----------------------------------------------- | ------------------------------------------------- |
| `platforms/nixos/secrets/authelia-secrets.yaml` | **NEW** — encrypted secrets for authelia + immich |
| `modules/nixos/services/sops.nix`               | Authelia/immich secrets point to new file         |
| `flake.nix`                                     | All service imports and nixosModules re-enabled   |
| `modules/nixos/services/caddy.nix`              | auth.lan and immich.lan vhosts restored           |
| `modules/nixos/services/monitoring.nix`         | authelia scrape job restored                      |

## Deploy

```bash
just switch
```

> Note: Authelia user passwords are placeholder hashes. You may want to set real credentials after deploy via `authelia crypto hash generate argon2` and updating `/var/lib/authelia-main/users_database.yml`.
