# SystemNix Comprehensive Status Report: Authelia SSO Implementation

**Date:** 2026-04-05 00:30 CEST
**Reporter:** Crush AI Assistant
**Focus:** Authelia SSO Integration & OAuth Wiring

---

## Executive Summary

Successfully implemented Authelia as the centralized identity provider for the evo-x2 homelab. All core infrastructure is in place with SQLite storage, OIDC provider, Caddy forward_auth integration, and Prometheus metrics. OAuth wired for Immich and Grafana; Gitea OIDC client configured but not yet wired in Gitea module.

**System Health:** ✅ All flake checks pass
**Security Status:** ⚠️ Placeholder secrets in use (deployment required)
**Deployment Status:** 🔄 Ready for evo-x2 deployment

---

## a) FULLY DONE ✅

| #  | Component               | Details                                                                                     |
| -- | ----------------------- | ------------------------------------------------------------------------------------------- |
| 1  | **Authelia Foundation** | Complete flake-parts module with SQLite storage, TOTP/WebAuthn 2FA, file-based user backend |
| 2  | **Sops Secrets**        | 6 secrets declared: 4 Authelia internal + 2 OAuth client secrets (Grafana, Immich)          |
| 3  | **Caddy Integration**   | forward_auth on all 7 protected vhosts; auth.lan portal vhost; TLS via dnsblockd certs      |
| 4  | **DNS Records**         | auth.lan → 192.168.1.150 in Unbound local-data                                              |
| 5  | **Prometheus Port Fix** | Changed from 9091 (conflicted) to 9090                                                      |
| 6  | **Grafana OIDC**        | auth.generic_oauth wired to Authelia; root_url fixed to HTTPS                               |
| 7  | **Immich OIDC**         | settings.oauth enabled with autoRegister; _secret sops integration                          |
| 8  | **Homepage Updates**    | Authelia service card added; Prometheus health check port fixed to 9090                     |
| 9  | **Authelia Metrics**    | Telemetry enabled on 127.0.0.1:9959; Prometheus scrape job added                            |
| 10 | **Dagger CI/CD**        | Full module with Nix check, format, lint, and build pipelines                               |

---

## b) PARTIALLY DONE ⚠️

| Component        | Status                                                           | Blocker                                          |
| ---------------- | ---------------------------------------------------------------- | ------------------------------------------------ |
| **Gitea OAuth**  | Authelia OIDC client configured; Gitea module lacks OAuth wiring | Needs Gitea `oauth` settings in gitea.nix        |
| **Sops Secrets** | Declared in Nix; actual values need encryption on evo-x2         | Requires physical access to evo-x2 to run `sops` |

---

## c) NOT STARTED 🚧

| #  | Task                                                         | Priority      |
| -- | ------------------------------------------------------------ | ------------- |
| 1  | Deploy to evo-x2 (`just switch`)                             | P0 - Critical |
| 2  | Add 6 secrets to sops.yaml on evo-x2                         | P0 - Critical |
| 3  | Generate unique OIDC client secrets (not shared placeholder) | P1 - High     |
| 4  | Generate Argon2id hash for user password                     | P1 - High     |
| 5  | Wire Gitea OAuth in gitea.nix                                | P1 - High     |
| 6  | Test SSO flows for all 3 services                            | P1 - High     |
| 7  | Verify forward_auth on all 7 services                        | P1 - High     |
| 8  | Configure SMTP for password reset                            | P2 - Medium   |
| 9  | Set up TOTP backup codes procedure                           | P2 - Medium   |
| 10 | Test WebAuthn/Passkey registration                           | P2 - Medium   |

---

## d) TOTALLY FUCKED UP ❌

Nothing critical. All flake checks pass. No broken builds.

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Security & Operations

1. **Unique OIDC Secrets** — Each client should have its own secret (currently sharing placeholder hash)
2. **User Password Management** — Current `writeText` puts hash in world-readable Nix store; use sops template instead
3. **Session Secret Rotation** — No policy defined; should rotate annually
4. **Authelia HA** — Currently SQLite + local sessions; consider Redis for session storage if scaling
5. **Backup Strategy** — Authelia SQLite DB not in backup rotation yet

### Code Quality

6. **DRY Caddy Config** — 7 vhosts with identical forward_auth pattern; extract helper function
7. **Consistent Naming** — `authelia_*` vs `*_oauth_client_secret` naming conventions vary
8. **Health Check Consistency** — Some services use HTTPS, others HTTP; standardize

### Documentation & Runbooks

9. **SSO Onboarding Guide** — Document how to add new users, reset passwords, handle 2FA
10. **Incident Response** — Runbook for SSO outage, fallback auth procedures
11. **OIDC Client Rotation** — Procedure for rotating secrets without downtime

### Monitoring

12. **Authelia Down Alert** — Prometheus alert for auth service availability
13. **Failed Login Monitoring** — Alert on brute force attempts (via Authelia logs)
14. **Session Metrics** — Track active sessions, login latency

---

## f) Top #25 Things To Get Done Next 📋

### Immediate (P0 - This Week)

1. Deploy to evo-x2: `just switch`
2. Add 6 secrets to sops.yaml on evo-x2 (4 Authelia + 2 OAuth)
3. Generate unique OIDC client secrets for each service
4. Generate Argon2id password hash for initial user
5. Wire Gitea OAuth in gitea.nix

### Short-term (P1 - Next 2 Weeks)

6. Test Immich SSO end-to-end
7. Test Grafana SSO end-to-end
8. Test Gitea SSO end-to-end
9. Verify forward_auth protecting all 7 services
10. Add Authelia SQLite to backup rotation
11. Configure SMTP for password reset emails
12. Test TOTP enrollment and backup codes
13. Test WebAuthn/Passkey registration
14. Add Authelia health check to Prometheus alerts
15. Verify Caddy metrics scrape target works

### Medium-term (P2 - Next Month)

16. Refactor Caddy vhost config with helper function
17. Document SSO onboarding procedure
18. Create incident response runbook
19. Test SSO session timeout behavior
20. Configure Authelia remember_me duration
21. Add Authelia version pinning
22. Create OIDC client rotation procedure
23. Evaluate Redis for session storage
24. Implement secret rotation policy
25. Full SSO disaster recovery test

---

## g) Top #1 Question I Cannot Figure Out Myself ❓

**How should we handle the initial user password for Authelia?**

### Current Situation

- `users_database.yml` is generated via `pkgs.writeText` (world-readable Nix store)
- Contains a placeholder password hash (`$pbkdf2-sha512$310000$c8p78n7pUMln0jzvd4aK4Q$...`)
- User `lars` needs a real password on first login

### Options Considered

| Option                           | Pros                                                 | Cons                                                        |
| -------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------- |
| **A. Sops Template**             | Secure (encrypted), declarative, versioned           | Complex to generate Argon2id hash externally                |
| **B. Hash on Target**            | Use real `authelia hash-password` tool               | Manual step after deployment, not fully declarative         |
| **C. Placeholder + Force Reset** | Simple deployment, user sets password on first login | Requires SMTP for reset email, or manual admin intervention |
| **D. Bootstrap User**            | Create user via Authelia CLI after deployment        | Manual step, not in Nix config                              |

### Recommendation Needed

What's the preferred approach for a single-user homelab where:

- The user has SSH access to evo-x2
- SMTP might not be configured initially
- We want minimal manual steps post-deployment
- Security is important but not enterprise-grade

Should we:

1. Use a sops template with a pre-generated hash (run `authelia hash-password` locally, encrypt output)?
2. Deploy with placeholder and require manual `authelia hash-password` + config edit?
3. Set up SMTP first, then use "forgot password" flow on first login?
4. Something else entirely?

---

## Recent Commits (Last 6)

```
c0d277f feat(ci): add Dagger module for Nix flake CI/CD pipelines
47f45ad feat(authelia,monitoring): enable Authelia metrics and add Prometheus scrape target
92e441c feat(homepage): add Authelia service card and fix Prometheus health port
c8e88f9 feat(immich): add Authelia OIDC SSO for Immich
567b083 feat(grafana): add Authelia OIDC SSO and fix root_url to HTTPS
0bf647e fix(monitoring): change Prometheus port from 9091 to 9090
```

---

## Files Modified (Recent Session)

| File                                            | Changes                                    |
| ----------------------------------------------- | ------------------------------------------ |
| `modules/nixos/services/authelia.nix`           | Complete module with OIDC, SQLite, metrics |
| `modules/nixos/services/sops.nix`               | +6 secret declarations                     |
| `modules/nixos/services/caddy.nix`              | +forward_auth on all vhosts, +auth.lan     |
| `modules/nixos/services/grafana.nix`            | +OIDC config, fix root_url HTTPS           |
| `modules/nixos/services/immich.nix`             | +OAuth settings with sops secret           |
| `modules/nixos/services/homepage.nix`           | +Authelia card, fix Prometheus port        |
| `modules/nixos/services/monitoring.nix`         | Port 9091→9090, +Authelia scrape job       |
| `platforms/nixos/system/dns-blocker-config.nix` | +auth.lan DNS record                       |
| `dagger.json`, `dagger/`                        | New CI/CD module                           |

---

## Validation Status

```bash
$ nix flake check --no-build
✅ All checks passed

$ nix eval .#nixosConfigurations.evo-x2.config.services.authelia.instances.main.enable
true

$ nix eval .#nixosConfigurations.evo-x2.config.services.grafana.settings."auth.generic_oauth".enabled
true

$ nix eval .#nixosConfigurations.evo-x2.config.services.immich.settings.oauth.enabled
true
```

---

## Next Action Required

**User decision needed on:** Initial Authelia user password strategy (see Section g)

Once decided, proceed with:

1. Generate required secrets
2. Add to sops.yaml on evo-x2
3. Deploy with `just switch`
4. Test SSO flows

---

_💀 Generated with Crush_

_Assisted-by: GLM-5.1 via Crush <crush@charm.land>_
