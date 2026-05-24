# Session 87 — Full Comprehensive Status: Post-Migration Audit

**Date:** 2026-05-24 18:31 CEST
**Branch:** `master` (clean, pushed)
**Build:** ✅ `just test-fast` passes, zero warnings
**Sessions today:** 85–86 (7 commits)

---

## Executive Summary

Authelia → Pocket ID + oauth2-proxy migration is **code-complete** across 3 rounds of reflection and polish. All modules, health checks, hardening, Caddy forward-auth, metrics, documentation, and ADR are in place. **Not yet deployed** — blocked on manual sops secret creation.

---

## a) FULLY DONE ✅

### Migration: Authelia → Pocket ID + oauth2-proxy (Sessions 85–86)

Complete code-level migration across 14 files, 3 reflection rounds:

| Component | Status | Details |
|-----------|--------|---------|
| Pocket ID module | ✅ | `pocket-id.nix` — passkey OIDC, `/healthz` check, metrics port 9464, OTEL exporter |
| oauth2-proxy module | ✅ | `oauth2-proxy.nix` — forward-auth bridge, `harden {}` + `serviceDefaults {}`, `/ping` check |
| Caddy forward-auth | ✅ | `forward_auth → /oauth2/auth` + `handle_response` redirect 401 → login page |
| Caddy auth vhost | ✅ | `auth.${domain}` routes `/oauth2/*` → proxy, `/*` → Pocket ID |
| Port registry | ✅ | `pocket-id: 1411`, `oauth2-proxy: 4180`, `metricsPort: 9464` |
| SOPS secrets | ✅ | Replaced 4 Authelia secrets → 4 Pocket ID/oauth2-proxy secrets in `pocket-id.yaml` |
| Health checks | ✅ | Gatus (Pocket ID `/healthz`, oauth2-proxy `/ping`), ExecStartPost, homepage siteMonitor |
| SigNoz scraper | ✅ | Pocket ID metrics on dedicated OTEL port 9464, journald for both services |
| systemd hardening | ✅ | Both services hardened + serviceDefaults + onFailure + health checks |
| Documentation | ✅ | AGENTS.md (gotchas, Caddy pattern, build failures), FEATURES.md, ADR-007 |
| Authelia removal | ✅ | Module deleted, all references purged from active code |

### Recent Commits (Sessions 82–86)

| Commit | What |
|--------|------|
| `b17ad1bd` | Authelia → Pocket ID + oauth2-proxy (14 files, -306/+77 lines) |
| `8f9aeb6e` | Health endpoint `/healthz`, oauth2-proxy hardening, health checks |
| `8097d21c` | ADR-007: Authelia → Pocket ID migration |
| `83514fd9` | AGENTS.md bootstrapping gotcha |
| `b331d698` | Forward-auth 401 → login redirect, Pocket ID OTEL metrics port |
| `dde0d0f8` | BTRFS btrbk snapshots replacing Timeshift |
| `21ac978f` | Niri portal fix (wlr → native) |
| `e5ed623f` | Vendor hash cascade fix (all Go overlays) |
| `e7b591c5` | Watchdog auto-reboot removal |
| `08283e01` | Re-enabled all 4 disabled Go packages |

---

## b) PARTIALLY DONE 🟡

| Task | Status | What's Left |
|------|--------|-------------|
| Pocket ID deployment | 🟡 Code 100%, deploy 0% | Create sops file → deploy → register passkey → create OIDC clients → enable oauth2-proxy → reconfigure Immich/Forgejo |
| Docker `latest` tag pinning | 🟡 Identified but not fixed | twenty, manifest, openseo all use `mkDockerService` with default tags |
| TODO_LIST.md accuracy | 🟡 Stale | Still references Authelia-era tasks; doesn't reflect Pocket ID migration |
| FEATURES.md accuracy | 🟡 Partially updated | Pocket ID entries added, but broader accuracy pass needed |

---

## c) NOT STARTED ❌

| # | Task | Impact | Effort | Source |
|---|------|--------|--------|--------|
| 1 | Create `pocket-id.yaml` sops secrets file | 🔴 Critical | XS | Deploy blocker |
| 2 | Deploy Pocket ID + register passkey + create clients | 🔴 Critical | S | Deploy blocker |
| 3 | Enable oauth2-proxy + verify forward-auth + redirect | 🔴 Critical | S | Deploy blocker |
| 4 | Reconfigure Immich OAuth to Pocket ID | 🔴 High | XS | Auth breaks |
| 5 | Reconfigure Forgejo OAuth to Pocket ID | 🔴 High | XS | Auth breaks |
| 6 | Pin Docker `latest` tags (twenty, manifest, openseo) | 🟠 Security | XS | Session 78 plan |
| 7 | Consolidate GPU config via `lib/rocm.nix` | 🟡 Quality | S | Session 78 plan |
| 8 | Add swap-specific alert rule to SigNoz | 🟡 Monitoring | XS | Session 78 plan |
| 9 | Write Pocket ID client provisioning script | 🟡 Automation | M | Restore GitOps |
| 10 | Convert `/data` to `@data` BTRFS subvolume | 🟡 Safety | M | AGENTS.md gotcha |
| 11 | Configure Hermes secondary LLM provider | 🟡 Resilience | M | TODO_LIST.md |
| 12 | Hermes SSH deploy key for git access | 🟡 Automation | S | TODO_LIST.md |
| 13 | Deploy Dozzle at `logs.home.lan` | 🟢 Observability | S | Dozzle evaluation |
| 14 | nix-colors integration | 🟢 Visual | L (6h) | TODO_LIST.md |
| 15 | Provision Pi 3 for DNS failover cluster | 🟢 Hardware | L | TODO_LIST.md |
| 16 | Investigate swap exhaustion (13Gi/13Gi) | 🟡 Performance | M | TODO_LIST.md |
| 17 | Flake inputs audit (47 inputs) | 🟡 Maintenance | M | TODO_LIST.md |
| 18 | Auditd enablement | 🟢 Security | S | Blocked by NixOS bug |
| 19 | AppArmor enablement | 🟢 Security | M | Currently commented out |
| 20 | Consolidate voice-agents Caddy vHost | 🟡 Code | S | TODO_LIST.md |
| 21 | Per-threshold SigNoz channel routing | 🟡 Alerting | S | TODO_LIST.md |
| 22 | Trash `authelia-secrets.yaml` after deploy | 🟢 Cleanup | XS | Post-deploy |
| 23 | Update TODO_LIST.md for current state | 🟡 Docs | S | Accuracy |
| 24 | Convert go-auto-upgrade `path:` inputs to SSH | 🟡 Maintenance | S | TODO_LIST.md |
| 25 | Verify voice agents (LiveKit + Whisper) | 🟡 Verification | S | FEATURES.md gap |

---

## d) TOTALLY FUCKED UP 💥

**Nothing is broken in the code.** Build passes clean, zero warnings.

### Pre-Deploy Risks (Not Broken Yet)

| Risk | Severity | Mitigation |
|------|----------|------------|
| `pocket-id.yaml` sops file doesn't exist → deploy fails | 🔴 | Create before `just switch` |
| OIDC clients don't exist in Pocket ID → oauth2-proxy fails | 🔴 | Staged deploy: Pocket ID first, create clients, then oauth2-proxy |
| Immich/Forgejo OAuth breaks during transition | 🟠 | Keep Authelia running until Pocket ID clients verified |
| `pocket-id.png` icon may not exist in Homepage's icon pack | 🟢 | Minor visual issue |
| `authelia-secrets.yaml` still on disk | 🟢 | Harmless encrypted file, trash after deploy |

### What Went Wrong During Migration (Retrospective)

| Mistake | Could Have Been | Impact |
|---------|----------------|--------|
| Assumed `/api/health` endpoint | Check Pocket ID docs first | ExecStartPost would have failed on every boot |
| Assumed Pocket ID exposes metrics on app port | Check OTEL configuration | SigNoz scraper would get 404s forever |
| Dismissed 401 UX as "acceptable" | Included `handle_response` from start | Users would see blank pages instead of login redirect |
| oauth2-proxy had no hardening | Compare against other modules | Service ran with minimal systemd sandboxing |
| No ADR initially | Write ADR with the decision | Future sessions wouldn't know why the choice was made |

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Architecture

1. **OIDC client management is manual** — Authelia had declarative `mkClient` in Nix. Pocket ID uses web UI. Should write a provisioning script using Pocket ID's REST API (`POST /api/oidc/clients` with `X-API-KEY` header), following the existing SigNoz `signoz-provision` pattern.

2. **`pocket-id.yaml` sops file doesn't exist yet** — The entire auth stack is blocked on this one manual step. Could be semi-automated with a `just bootstrap-auth` command.

3. **`harden {}` vs upstream hardening inconsistency** — Pocket ID upstream has 30+ systemd hardening keys (more comprehensive than our `harden {}`). Our wrapper applies `serviceDefaults` only, which is correct but means Pocket ID and oauth2-proxy have different hardening profiles. Should document which services rely on upstream hardening vs our `harden {}`.

### Type Safety

4. **No `metricsPort` type in `serviceTypes`** — Added `metricsPort` as a raw `servicePort` option. Could create a `serviceMetricsPort` type with a standard default (9464 for OTEL) to avoid repeating this pattern.

5. **No OIDC client type** — OAuth configuration is duplicated inline in each service (Immich, oauth2-proxy). A shared `serviceTypes.oidcClient` could standardize `issuerUrl`, `clientId`, `scope`, etc.

6. **Docker `latest` tag type exists but isn't enforced** — `serviceTypes.dockerImageTag` rejects `"latest"` but twenty, manifest, and openseo may not use it. Should audit and apply.

### Observability

7. **No oauth2-proxy metrics** — oauth2-proxy exposes `/metrics` on its main port but we don't scrape it. Should add a SigNoz job.

8. **No swap alert** — Identified in session 78 but not implemented. SigNoz has 16 rules but none for swap.

### Documentation

9. **TODO_LIST.md is stale** — Still references Authelia, doesn't mention Pocket ID at all.

10. **signoz-alerts.nix not in serviceModules** — Exists as a file but imported by `signoz.nix`, not listed independently. Should document this pattern or add it.

---

## f) Top 25 Things to Do Next (Pareto-Sorted)

### Tier 1: Deploy or Die 🔴 (blocking everything)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Create `platforms/nixos/secrets/pocket-id.yaml` sops file | 5 min | 🔴 Unblock deploy |
| 2 | Deploy Pocket ID standalone (`oauth2-proxy-config.enable = false`) | 2 min | 🔴 Get OIDC running |
| 3 | Register admin passkey + create `oauth2-proxy`, `immich`, `forgejo` OIDC clients | 15 min | 🔴 Bootstrap identity |
| 4 | Add client secrets to sops, enable oauth2-proxy, deploy | 10 min | 🔴 Restore forward-auth |
| 5 | Reconfigure Immich + Forgejo OAuth | 10 min | 🔴 Restore service auth |
| 6 | Verify all 12 protected vhosts redirect correctly | 5 min | 🔴 End-to-end validation |

### Tier 2: Quick Wins 🟠 (high impact, low effort)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 7 | Pin Docker `latest` tags (twenty, manifest, openseo) | 10 min | 🟠 Supply chain security |
| 8 | Trash `authelia-secrets.yaml` | 1 min | 🟢 Cleanup |
| 9 | Add swap alert rule to SigNoz | 5 min | 🟡 Proactive monitoring |
| 10 | Add oauth2-proxy metrics to SigNoz scraper | 5 min | 🟡 Observability |
| 11 | Consolidate GPU config via `lib/rocm.nix` | 20 min | 🟡 Code quality |

### Tier 3: Should Do 🟡 (medium impact)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 12 | Write Pocket ID OIDC client provisioning script | 45 min | 🟡 Restore GitOps |
| 13 | Update TODO_LIST.md for current state | 20 min | 🟡 Docs accuracy |
| 14 | Update FEATURES.md accuracy pass | 20 min | 🟡 Docs accuracy |
| 15 | Configure Hermes secondary LLM provider | 30 min | 🟡 Resilience |
| 16 | Hermes SSH deploy key | 15 min | 🟡 Automation |
| 17 | Consolidate voice-agents Caddy vHost | 15 min | 🟡 Code quality |
| 18 | Flake inputs audit (47 → ~30?) | 60 min | 🟡 Maintenance |

### Tier 4: Nice to Have 🟢

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 19 | Deploy Dozzle at `logs.home.lan` | 20 min | 🟢 Live container logs |
| 20 | Convert `/data` to `@data` BTRFS subvolume | 45 min | 🟢 Snapshot safety |
| 21 | Verify voice agents (LiveKit + Whisper) | 20 min | 🟢 Feature verification |
| 22 | Per-threshold SigNoz channel routing | 30 min | 🟢 Alert quality |
| 23 | nix-colors integration | 6 hr | 🟢 Visual polish |
| 24 | Provision Pi 3 for DNS failover | 2+ hr | 🟢 HA DNS |
| 25 | Convert go-auto-upgrade `path:` inputs to SSH | 15 min | 🟢 Cleanup |

---

## g) Top #1 Question I Cannot Answer 🤔

**Should `authelia-secrets.yaml` be deleted before or after the first Pocket ID deploy?**

If kept: provides rollback path (re-enable Authelia config, `just switch`, back to working state).
If deleted: forces forward momentum, no temptation to revert.

My recommendation: **Keep until Pocket ID is verified working end-to-end** (all 12 vhosts authenticated, Immich + Forgejo OAuth functional). Then trash it. But this is your call.

---

## Codebase Metrics

| Metric | Value |
|--------|-------|
| Service modules | 36 `.nix` files |
| serviceModules in flake.nix | 35 entries |
| Total `.nix` files | 113 |
| SOPS secret files | 9 (8 active + 1 stale `authelia-secrets.yaml`) |
| ADRs | 8 |
| Status reports | 25+ in `docs/status/` |
| Flake inputs | 49 |
| Commits today (2026-05-24) | 7 (sessions 85–86) |
| Build status | ✅ PASS (zero warnings) |
| Branch | `master`, pushed to origin |

## Auth Architecture (Current)

```
External → Caddy (443)
  → forward_auth oauth2-proxy:4180/oauth2/auth
    → 2xx (cookie valid): pass through → backend
    → 401 (no cookie): redirect → auth.<domain>/oauth2/sign_in
      → Pocket ID (1411): passkey authentication
      → oauth2-proxy: OIDC callback → set cookie (.${domain})
      → redirect back to original URL

Metrics: Pocket ID OTEL → SigNoz scraper (port 9464)
Health: Pocket ID /healthz (204) + oauth2-proxy /ping (200)
Logs: journald → SigNoz collector
Secrets: sops pocket-id.yaml (4 keys)
Hardening: Pocket ID (upstream 30+ keys) + oauth2-proxy (our harden {} 13 keys)
```
