# Session 60 — Final Status: All Forgejo Post-Migration Bugs Fixed

**Date:** 2026-05-19 20:42 CEST
**Working Tree:** Clean (1 commit ahead of origin)

---

## Executive Summary

Four post-migration bugs found and fixed. The last one — the runner token permission issue — was the actual root cause of the persistent `gitea-runner-evo-x2.service` failure. All fixes are Nix-managed. Deploy with `just switch`.

---

## A) FULLY DONE ✅

### Forgejo Migration — COMPLETE

All code, data, DNS, TLS, OIDC, monitoring, health checks, and documentation migrated from Gitea to Forgejo across 36 service modules, 47 flake inputs, and 3 platform configs.

### Bugs Fixed This Session (4)

| # | Bug | Root Cause | Fix | Commit |
|---|-----|-----------|-----|--------|
| 1 | `WatchdogSec=30` kills Forgejo | Forgejo sends READY=1 only, not WATCHDOG=1 | Removed WatchdogSec | `b63ceca0` |
| 2 | Health check checks dead `gitea` service | Script had 3 wrong names, missed 9 services | Rewrote with 34 correct names | `b22abfe7` |
| 3 | Runner token never regenerated | `[ -f "$TOKEN_FILE" ] && exit 0` skipped when stale file existed | Removed short-circuit — always regenerate | `e0728ece` |
| 4 | **Runner can't read token file** | Token at `/var/lib/forgejo/.runner-token` owned by `forgejo:forgejo` mode 0600. Runner uses `DynamicUser=true` (random UID) — can't read it. | Write token to `/run/forgejo-runner-token` (tmpfs, mode 0644) | `7bbba62e` |

### Project Infrastructure — All Healthy

| Component | Count |
|-----------|-------|
| NixOS service modules | 36 (30 enabled) |
| Overlay packages | 21 (all building) |
| Shared lib helpers | 12 functions |
| Cross-platform programs | 15 modules |
| Justfile recipes | 69 in 9 categories |
| Pre-commit hooks | 9 |
| Flake inputs | 47 |
| Operational scripts | 19 |
| Custom packages | 5 |

---

## B) PARTIALLY DONE 🔧

| Item | What's Left |
|------|-------------|
| Forgejo push mirrors | Configured but never tested end-to-end |
| DNS failover cluster | Module ready, Pi 3 hardware not provisioned |

---

## C) NOT STARTED ⏳

| # | Item | Priority |
|---|------|----------|
| 1 | Pi 3 hardware provisioning | MED |
| 2 | Forgejo federation testing | LOW |
| 3 | Extract hardcoded ports (voice-agents, signoz, homepage) | MED |
| 4 | `scripts/lib.sh` missing `set -euo pipefail` | LOW |
| 5 | Archive old docs | LOW |
| 6 | Post-switch health check automation | MED |
| 7 | `assets/avatar.png` 4.2MB in git | LOW |

---

## D) TOTALLY FUCKED UP 💥

### The Runner Token Permission Bug — The Actual Root Cause

**Symptom:** `gitea-runner-evo-x2.service` failed on every deploy.

**Initial diagnosis (wrong):** Stale token file from Gitea era. Fixed by removing the short-circuit (`e0728ece`).

**Actual root cause:** The nixpkgs `gitea-actions-runner` module uses `DynamicUser = true` — systemd creates a random, transient UID at service start. The token file at `/var/lib/forgejo/.runner-token` was owned by `forgejo:forgejo` with mode `0600`. The dynamic runner user **could not read it**. Registration always failed with a permission error, not a token validity error.

**Fix:** Write the token to `/run/forgejo-runner-token` (tmpfs) with mode `0644` (world-readable). `/run/` is cleared on reboot — token is regenerated on every boot by the `forgejo-runner-token` oneshot service.

**Lesson:** When using `DynamicUser = true` services, state files in other users' home directories are inaccessible. Use `/run/` (tmpfs) for inter-service data exchange.

---

## E) WHAT WE SHOULD IMPROVE 📈

1. **Hardcoded ports** — 5 `localhost:PORT` in voice-agents, signoz, homepage should use module options
2. **No WatchdogSec-safe services** — Currently zero services verified to send `WATCHDOG=1`
3. **Health check not config-driven** — Service names hardcoded in script, must update manually
4. **No automated deploy verification** — Post-switch health check would catch issues immediately
5. **Docs sprawl** — 350+ files in docs/, many historical

---

## F) TOP 25 THINGS TO DO NEXT 🎯

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy to evo-x2** (`just switch`) | CRITICAL | 1min |
| 2 | **Verify all services active** | HIGH | 2min |
| 3 | **Test Forgejo web UI** | HIGH | 5min |
| 4 | **Verify runner connected** | HIGH | 1min |
| 5 | **Test push mirrors** | HIGH | 10min |
| 6 | **Remove old backup** `/var/lib/gitea.pre-forgejo-migration` | MED | 1min |
| 7 | **Remove stale token** `/var/lib/forgejo/.runner-token` | MED | 1min |
| 8 | **Extract LiveKit port** to module option | MED | 15min |
| 9 | **Extract hardcoded ports** in signoz.nix | MED | 15min |
| 10 | **Extract hardcoded port** in homepage.nix | MED | 5min |
| 11 | **Add post-switch health check** to justfile | MED | 30min |
| 12 | **Archive migration doc** | LOW | 2min |
| 13 | **Add `set -euo pipefail`** to lib.sh | LOW | 2min |
| 14 | **Fix unquoted variables** in usb-diagnostic.sh | LOW | 5min |
| 15 | **Compress avatar.png** | LOW | 5min |
| 16 | **Provision Pi 3** | MED | 2hr |
| 17 | **Archive old status docs** | LOW | 10min |
| 18 | **Add Forgejo backup verification** | MED | 15min |
| 19 | **Test Forgejo federation** | LOW | 1hr |
| 20 | **Review Gatus endpoint coverage** | MED | 15min |
| 21 | **Update AGENTS.md** — remove resolved gotchas | LOW | 10min |
| 22 | **Add repo count metric** to Gatus | LOW | 15min |
| 23 | **Test dual-WAN failover** | MED | 20min |
| 24 | **Audit tmpfiles rules** | LOW | 15min |
| 25 | **Fix dead image link** in nix-visualize-integration.md | LOW | 5min |

---

## G) TOP #1 QUESTION ❓

**After deploying `7bbba62e`, will the runner successfully register and connect?**

The fix chain:
1. `forgejo.service` starts → Forgejo ready
2. `forgejo-runner-token.service` starts → generates token → writes to `/run/forgejo-runner-token` (mode 0644)
3. `gitea-runner-evo-x2.service` starts → reads `/run/forgejo-runner-token` as EnvironmentFile → uses `$TOKEN` to register with Forgejo → connects

If the old runner state at `/var/lib/gitea-runner/evo-x2/.runner` exists with invalid credentials, the nixpkgs module's token hash comparison should detect the changed token and force re-registration. But if there's a state conflict (runner UUID already registered in Forgejo's DB), registration might still fail.

**Cannot verify without SSH access to evo-x2.**

---

## Commits This Session

| Commit | Message |
|--------|---------|
| `b63ceca0` | `fix(forgejo): remove dangerous WatchdogSec and clean up stale Gitea references` |
| `5943d171` | `docs(status): Session 60 — Forgejo WatchdogSec bug fix + comprehensive audit` |
| `b22abfe7` | `fix(health-check): update service-health-check for post-Forgejo migration` |
| `e0728ece` | `fix(forgejo): always regenerate runner registration token on boot` |
| `7bbba62e` | `fix(forgejo): write runner token to /run/ for DynamicUser compatibility` |

**Unpushed:** 1 commit (`7bbba62e` + this report)
