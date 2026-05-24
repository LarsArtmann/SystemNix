# Session 86 — Post-Migration Polish: Health Endpoints, Hardening, UX Redirect

**Date:** 2026-05-24 17:43 CEST
**Branch:** `master` (clean)
**Commits since session 85:** 3

---

## Summary

Three rounds of reflection on the Authelia → Pocket ID migration uncovered and fixed 5 issues. All found through deep research into upstream documentation, not runtime testing.

---

## What Was Found and Fixed

### Round 1 (commit `8f9aeb6e`)

| Issue | Severity | Fix |
|-------|----------|-----|
| Pocket ID health endpoint is `/healthz` (HTTP 204), not `/api/health` | 🔴 Would break startup | Fixed in ExecStartPost, gatus, homepage |
| oauth2-proxy had zero systemd hardening | 🟠 Security gap | Added `harden {}` + `serviceDefaults {}` |
| oauth2-proxy had no health monitoring | 🟡 Observability gap | Added ExecStartPost `/ping` + gatus endpoint |

### Round 2 (commits `8097d21c`, `83514fd9`)

| Issue | Severity | Fix |
|-------|----------|-----|
| Missing ADR for architectural decision | 🟡 Documentation | Created ADR-007 |
| AGENTS.md missing sops bootstrapping gotcha | 🟡 Documentation | Added to Build Failures table |

### Round 3 (commit `b331d698`)

| Issue | Severity | Fix |
|-------|----------|-----|
| `forward_auth` passes 401 to browser as blank page | 🟠 UX regression | Added `handle_response @unauth` → redirect to login |
| Pocket ID metrics scraper targeting wrong port | 🟡 Wrong config | Added `metricsPort` option (9464), enabled OTEL exporter |

---

## Reflection: What I Could Have Done Better

### 1. Research before implementing
The health endpoint and metrics port were discoverable from Pocket ID documentation. I assumed `/api/health` based on Authelia's pattern instead of verifying against Pocket ID's actual API.

### 2. UX regression awareness
The 401-vs-302 difference between oauth2-proxy and Authelia was identified in the initial migration plan but dismissed as "acceptable for single-user." In practice, it makes the system feel broken to any external visitor. The `handle_response` fix was trivially simple — should have been included from the start.

### 3. Hardening consistency
oauth2-proxy was the only service module without `harden {}` + `serviceDefaults {}`. This should have been caught by comparing against the established pattern in every other module.

### 4. Upstream module compatibility
Verified that `harden {}` uses `mkDefault` (priority 1000) and never sets `User`/`Group`. This means it safely layers on top of upstream NixOS modules. `serviceDefaults {}` uses `mkForce` (priority 50) for `Restart` and `RestartSec` only. No conflicts exist with either Pocket ID or oauth2-proxy upstream modules.

---

## Remaining Work (Sorted by Impact)

### Must Do Before Deploy 🔴

| # | Task | Effort |
|---|------|--------|
| 1 | Create `pocket-id.yaml` sops file with 4 secrets | XS |
| 2 | Deploy Pocket ID (oauth2-proxy disabled) | XS |
| 3 | Register admin passkey + create OIDC clients | S |
| 4 | Deploy oauth2-proxy + verify forward-auth + redirect | S |
| 5 | Reconfigure Immich + Forgejo OAuth | XS |

### Should Do 🟠

| # | Task | Effort |
|---|------|--------|
| 6 | Pin Docker `latest` tags (twenty, manifest, openseo) | XS |
| 7 | Consolidate GPU config via `lib/rocm.nix` | S |
| 8 | Add swap alert rule to SigNoz | XS |
| 9 | Write Pocket ID OIDC client provisioning script | M |
| 10 | Convert `/data` to `@data` subvolume | M |

### Nice to Have 🟡

| # | Task | Effort |
|---|------|--------|
| 11 | Configure Hermes secondary LLM | M |
| 12 | Deploy Dozzle at `logs.home.lan` | S |
| 13 | Flake inputs audit (47 inputs) | M |
| 14 | nix-colors integration | L (6h) |
| 15 | Provision Pi 3 for DNS failover | L |

---

## Architecture Notes

### `harden {}` Priority System (verified)

| Helper | Priority | Keys | Conflicts? |
|--------|----------|------|------------|
| `harden {}` | `mkDefault` (1000) | 13 security keys (PrivateTmp, ProtectSystem, etc.) | No — upstream modules don't set these, or use plain values |
| `serviceDefaults {}` | `mkForce` (50) | 2 keys (Restart, RestartSec) | No — upstream uses plain values, mkForce wins correctly |

Neither helper sets `User`, `Group`, `WorkingDirectory`, `ExecStart`, or `EnvironmentFile` — all critical keys that upstream NixOS modules own exclusively.

### Caddy Auth Flow (after fix)

```
External user → Caddy protected vhost
  → forward_auth oauth2-proxy:4180/oauth2/auth
  → 2xx: pass through (authenticated)
  → 401: handle_response → 302 redirect to auth.<domain>/oauth2/sign_in?rd=<original>
  → User authenticates with Pocket ID passkey
  → oauth2-proxy sets cookie (domain=.<domain>)
  → 302 back to original URL
  → Cookie present → forward_auth returns 2xx → backend served
```

---

## Build Status

- `just test-fast`: ✅ all checks passed
- Zero warnings (pre-existing ZFS `forceImportRoot` on rpi3-dns only)
- Pre-commit hooks: gitleaks ✅, deadnix ✅, statix ✅, alejandra ✅, flake check ✅
