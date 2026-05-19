# Session 60 — Comprehensive Status: Forgejo Migration Complete, WatchdogSec Bug Fixed

**Date:** 2026-05-19 20:14 CEST
**Session Focus:** Forgejo post-migration audit, critical WatchdogSec bug discovery, stale reference cleanup

---

## Executive Summary

The Gitea→Forgejo migration is **code-complete and deployed**. This session discovered and fixed a **critical WatchdogSec bug** that would have killed Forgejo every 30 seconds after deployment, cleaned up all remaining stale Gitea references across the codebase, and performed a comprehensive audit of the entire project.

**Deployed but needs user action on evo-x2:**
- Runner token regeneration (service fails without valid token)
- Old backup cleanup (`/var/lib/gitea.pre-forgejo-migration`)

---

## A) FULLY DONE ✅

### Forgejo Migration (Sessions 52-60)

| Component | Status | Details |
|-----------|--------|---------|
| `forgejo.nix` module | ✅ Complete | 537 lines, LTS package, Actions runner, admin auto-setup, token generation |
| `forgejo-repos.nix` module | ✅ Complete | 302 lines, declarative repo mirroring, daily sync timer |
| Data migration | ✅ Complete | `/var/lib/gitea` → `/var/lib/forgejo`, SQLite intact |
| Sops key rename | ✅ Complete | `gitea_token` → `forgejo_token` via migration script |
| DNS subdomain | ✅ Complete | `gitea.home.lan` → `forgejo.home.lan` everywhere |
| Caddy vhost | ✅ Complete | `forgejo.${domain}` protected vhost |
| Authelia OIDC | ✅ Complete | `client_id = "forgejo"`, callback updated |
| Homepage entry | ✅ Complete | Forgejo with `forgejo.png` icon |
| Gatus health check | ✅ Complete | `/api/v1/version` endpoint |
| SigNoz log collection | ✅ Complete | `forgejo.service` journald receiver |
| DNS records | ✅ Complete | Unbound local-data for `forgejo.home.lan` |
| Federation | ✅ Enabled | `federation.ENABLED = true` |
| Push mirrors | ✅ Configured | Forgejo→GitHub auto-sync on push for owned repos |
| Runner package | ✅ Switched | `pkgs.forgejo-runner` v12.10.1 |
| Tmpfiles Z rule | ✅ Active | Recursive ownership fix for migrated state dir |
| Old modules removed | ✅ Done | `gitea.nix` and `gitea-repos.nix` deleted |
| All 12 referencing files updated | ✅ Done | Caddy, sops, gatus, signoz, homepage, authelia, flake, configuration, justfile |
| WatchdogSec bug fix | ✅ Fixed | Removed `WatchdogSec = 30` — Forgejo only sends READY=1, not WATCHDOG=1 |
| Stale reference cleanup | ✅ Done | README.md (4), FEATURES.md (1), service-defaults.nix (1), AGENTS.md (3) |

### Project Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| NixOS service modules | ✅ 36 modules | 6,794 total lines, 30 enabled, 3 disabled, 2 sub-modules |
| Custom overlays | ✅ 21 packages | 15 shared + 6 Linux-only, all building |
| Shared lib helpers | ✅ 12 functions | harden, serviceDefaults, mkDockerServiceFactory, mkPreparedSource, etc. |
| Cross-platform programs | ✅ 15 modules | Fish, Zsh, Bash, Starship, Git, tmux, FZF, etc. |
| Justfile | ✅ 69 recipes | 9 categories, comprehensive task coverage |
| Pre-commit hooks | ✅ 9 hooks | gitleaks, deadnix, statix, alejandra, shellcheck, etc. |
| Flake inputs | ✅ 47 inputs | 72 lock nodes, 8 source-only (flake=false) |
| Custom packages | ✅ 5 packages | jscpd, govalid, netwatch, openaudible, aw-watcher-utilization |
| Operational scripts | ✅ 19 scripts | DNS, GPU recovery, health checks, wallpaper, dual-WAN |
| Darwin config | ✅ 13 .nix files | MacBook Air aarch64-darwin, shared overlays |

---

## B) PARTIALLY DONE 🔧

| Item | Status | What's Left |
|------|--------|-------------|
| Forgejo Actions runner | 🔧 Deployed, needs token | `gitea-runner-evo-x2.service` fails — token from old Gitea is stale. Needs: `sudo rm -f /var/lib/forgejo/.runner-token && sudo systemctl restart forgejo-runner-token && sleep 3 && sudo systemctl restart gitea-runner-evo-x2` |
| Forgejo push mirrors | 🔧 Configured, untested | Push mirrors set up for owned repos (LarsArtmann/*) but never verified end-to-end |
| DNS failover cluster | 🔧 Module ready, hardware not | Pi 3 backup DNS node — `dns-failover.nix` module complete, Pi 3 not provisioned yet. TODO in `rpi3/default.nix:140` for sops + age identity setup |

---

## C) NOT STARTED ⏳

| # | Item | Priority | Details |
|---|------|----------|---------|
| 1 | Runner token regeneration on evo-x2 | HIGH | One-liner, needs SSH to evo-x2 |
| 2 | Old backup cleanup | MED | `sudo rm -rf /var/lib/gitea.pre-forgejo-migration` after verification |
| 3 | Pi 3 hardware provisioning | MED | DNS failover cluster needs physical Pi 3 setup |
| 4 | Forgejo federation testing | LOW | Federation enabled but no ActivityPub interactions tested |
| 5 | Push mirror verification | LOW | Verify Forgejo→GitHub push on actual commit |

---

## D) TOTALLY FUCKED UP 💥 (Bugs Found This Session)

### 1. WatchdogSec on Forgejo — **CRITICAL** (FIXED, not yet deployed)

**What:** `WatchdogSec = 30` was set on `forgejo.service` in `forgejo.nix:328`. Forgejo uses `Type = "notify"` and sends `READY=1` via sd_notify, but does **NOT** send periodic `WATCHDOG=1` keepalives. Systemd would kill Forgejo 30 seconds after every successful startup.

**Root cause:** Same anti-pattern as the Caddy WatchdogSec bug (fixed in `949191b9`). Forgejo was incorrectly listed in AGENTS.md as a service that "supports sd_notify" and is "safe for WatchdogSec". In reality, it only sends `READY=1` (startup notification) — it never sends `WATCHDOG=1` (periodic heartbeat).

**Impact:** If deployed with this setting, Forgejo would enter a crash loop: start → READY=1 → 30s pass → no WATCHDOG=1 → SIGTERM → restart → repeat.

**Fix:** Removed `WatchdogSec = lib.mkForce "30"` from `forgejo.nix`. Reclassified Forgejo in AGENTS.md from "safe for WatchdogSec" to "READY=1 only, do NOT use WatchdogSec".

**Commit:** `b63ceca0` — not yet deployed to evo-x2.

**Lesson:** `Type = "notify"` ≠ safe for `WatchdogSec`. Always verify the service sends `WATCHDOG=1` keepalives, not just `READY=1`. Currently **NO services** in this project are verified safe for WatchdogSec.

### 2. Stale Gitea References — Documentation Drift (FIXED)

**What:** After the Gitea→Forgejo migration (Session 58), 7 stale references remained in user-facing documentation:
- `README.md`: Service table row still said "Gitea", directory comment, justfile example
- `FEATURES.md`: DNS records list had `gitea` instead of `forgejo`
- `lib/systemd/service-defaults.nix`: Comment referenced "Gitea" as WatchdogSec-safe example

**Root cause:** Migration focused on functional code (modules, configs) but missed documentation and comments.

**Fix:** All 7 references updated in commit `b63ceca0`.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture & Code Quality

1. **Hardcoded ports in voice-agents.nix** — `localhost:7880` (LiveKit) is hardcoded in Caddy proxy instead of using a module option. Violates the "config-derived URLs" pattern documented in AGENTS.md.

2. **Hardcoded ports in signoz.nix** — `127.0.0.1:2019` (Caddy admin API) and `127.0.0.1:8090` (emeet-pixyd metrics) are hardcoded in OTel collector scrape configs.

3. **Hardcoded port in homepage.nix** — `localhost:8090` for emeet-pixyd metrics in siteMonitor.

4. **`assets/avatar.png` is 4.2MB** — The only large file in the repo. Should use Git LFS or compress.

5. **`docs/migration-gitea-to-forgejo.md` is stale** — References deleted `gitea.nix`/`gitea-repos.nix` files. Should be archived or updated to post-migration state.

6. **`scripts/lib.sh` missing `set -euo pipefail`** — Library file sourced by other scripts but has no safety flags.

7. **`scripts/usb-diagnostic.sh` has unquoted variables** — `$pid` and array expansions without quotes.

8. **`docs/architecture/nix-visualize-integration.md`** references `../architecture/Setup-Mac-Darwin.png` which doesn't exist (gitignored).

9. **No services currently verified for WatchdogSec** — The sd_notify section in AGENTS.md should be updated when we find services that actually send `WATCHDOG=1`.

### Operational

10. **No automated deployment verification** — After `just switch`, there's no automated check that all services started correctly. Could add a post-switch health check.

11. **Runner token is ephemeral** — Generated on first boot, but if Forgejo's DB is reset or token expires, runner fails silently. Consider token refresh mechanism.

12. **Docs sprawl** — 350+ files in `docs/`, including many historical status reports. Consider archiving older status docs.

---

## F) TOP 25 THINGS TO DO NEXT 🎯

Ranked by impact × urgency:

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Deploy WatchdogSec fix to evo-x2** (`just switch`) | CRITICAL | 5min | Deploy |
| 2 | **Regenerate runner token** on evo-x2 | HIGH | 2min | Deploy |
| 3 | **Verify Forgejo fully operational** (API, web UI, repos) | HIGH | 5min | Verify |
| 4 | **Test push mirrors** — push a commit, verify it reaches GitHub | HIGH | 10min | Verify |
| 5 | **Remove old backup** `/var/lib/gitea.pre-forgejo-migration` | MED | 1min | Cleanup |
| 6 | **Extract LiveKit port to module option** in `voice-agents.nix` | MED | 15min | Code quality |
| 7 | **Extract hardcoded ports** in `signoz.nix` (2019, 8090) | MED | 15min | Code quality |
| 8 | **Extract hardcoded port** in `homepage.nix` (8090) | MED | 5min | Code quality |
| 9 | **Archive migration doc** `docs/migration-gitea-to-forgejo.md` | LOW | 2min | Docs |
| 10 | **Add `set -euo pipefail` to `scripts/lib.sh`** | LOW | 2min | Code quality |
| 11 | **Fix unquoted variables in `scripts/usb-diagnostic.sh`** | LOW | 5min | Code quality |
| 12 | **Compress avatar.png** or move to Git LFS | LOW | 5min | Repo hygiene |
| 13 | **Provision Pi 3** for DNS failover cluster | MED | 2hr | Infra |
| 14 | **Add post-switch health check** to justfile | MED | 30min | Automation |
| 15 | **Archive old status docs** (move 2025 reports to archive/) | LOW | 10min | Docs |
| 16 | **Add Forgejo backup verification** to justfile | MED | 15min | Reliability |
| 17 | **Test Forgejo federation** with another Forgejo instance | LOW | 1hr | Features |
| 18 | **Add runner token refresh** mechanism | LOW | 30min | Reliability |
| 19 | **Fix dead image link** in `nix-visualize-integration.md` | LOW | 5min | Docs |
| 20 | **Review Gatus monitoring coverage** — any missing endpoints? | MED | 15min | Monitoring |
| 21 | **Update AGENTS.md** — remove Gitea-specific gotchas that are now resolved | LOW | 10min | Docs |
| 22 | **Consider Forgejo email notifications** for push mirror failures | LOW | 30min | Features |
| 23 | **Add Forgejo repo count to Gatus** — alert if repos < expected | LOW | 15min | Monitoring |
| 24 | **Test dual-WAN failover** with Forgejo push mirrors active | MED | 20min | Reliability |
| 25 | **Audit all tmpfiles rules** for correctness and necessity | LOW | 15min | Code quality |

---

## G) TOP #1 QUESTION ❓

**Is Forgejo currently stable on evo-x2 or has the WatchdogSec bug been causing crash loops?**

The WatchdogSec was added in the initial module creation (commit `04e9cced`) and has been present in every deployment since Session 58. If Forgejo was deployed with `Type = "notify"` + `WatchdogSec = 30`, it would be killed every 30 seconds. The context says "Forgejo is running successfully" — but this may have been observed during the brief window between `READY=1` and the 30-second watchdog timeout.

The fix (commit `b63ceca0`) has NOT been deployed yet — it's 2 commits ahead of origin/master. **Deploying this fix is the single highest-priority action.**

---

## Project Metrics

| Metric | Value |
|--------|-------|
| Total commits | 2,496 |
| Total .nix files | ~106 |
| Service module lines | 6,794 (36 modules) |
| Flake inputs | 47 (72 lock nodes) |
| Overlay packages | 21 (15 shared + 6 Linux) |
| Justfile recipes | 69 (9 categories) |
| Operational scripts | 19 |
| Custom packages | 5 |
| Pre-commit hooks | 9 |
| Docs files | ~350+ |
| Commits ahead of origin | 2 (unpushed) |

---

## Commits This Session

| Commit | Message | Files |
|--------|---------|-------|
| `b63ceca0` | `fix(forgejo): remove dangerous WatchdogSec and clean up stale Gitea references` | 5 files, +11 -10 |

---

## Previous Session Context

| Session | Summary |
|---------|---------|
| 52-53 | Forgejo migration Phase 1 (code), Phase 2 (data) |
| 54-55 | Go ecosystem fixes (gogenfilter v3, build fixes) |
| 56 | art-dupl stats bug, branch migration |
| 57 | Unsloth removal, comprehensive status |
| 58 | Forgejo subdomain rename, service startup fixes, Caddy WatchdogSec removal |
| 59 | Forgejo admin password ownership fix |
| **60** | **WatchdogSec bug discovery + fix, stale reference cleanup, comprehensive audit** |
