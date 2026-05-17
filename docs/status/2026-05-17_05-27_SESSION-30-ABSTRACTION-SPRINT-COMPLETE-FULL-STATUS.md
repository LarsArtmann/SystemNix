# Session 30 — Abstraction Sprint Complete + Full Status

**Date:** 2026-05-17 05:27
**Session type:** Abstraction sprint completion + comprehensive status
**Trigger:** User requested full status after multi-session deduplication sprint

---

## Executive Summary

Completed the "Do More With Less" abstraction plan from `docs/planning/2026-05-16_less-code-more-system.md`. All 5 items assessed, 3 fully executed, 2 correctly deferred. Across sessions 24–30 (external + my work), the codebase lost **~290 net lines** while gaining stronger reuse patterns.

**Build:** 🟢 `just test-fast` passes clean | **Health:** 🔴 Caddy failed, disk 91% | **Undeployed:** 8 sessions of changes

---

## A) FULLY DONE

### "Do More With Less" Plan — Execution Status

| # | Abstraction | Status | Impact |
|---|-------------|--------|--------|
| 1 | **mkDockerService factory** | ✅ DONE | 3/4 Docker services refactored (openseo, manifest, twenty). photomap skipped (disabled). `lib/docker.nix` = 99-line factory. |
| 2 | **mkHttpCheck helper** | ✅ DONE | 15/26 Gatus endpoints use helper. Special endpoints (DNS, TCP, body patterns) stay explicit. `discordAlert` + `nodePort` aliases added. |
| 3 | **Consecutive-failure lib.sh** | ✅ DONE | `state_init/state_hit/state_reset` in lib.sh. Both watchdog scripts refactored. |
| 4 | **Caddy vhosts as data** | ⏭️ DEFERRED | `protectedVHost` helper already exists. Exception vhosts (auth, tasks, comfyui) have legitimate reasons not to be data-driven. Marginal benefit. |
| 5 | **Service self-registration** | ⏭️ DEFERRED | Architecture change, not refactor. Requires service modules to export `{ port, healthPath, virtualHost, needsAuth }` options. Too invasive for this sprint. |

### This Session (30) — My Work

| # | Item | Details |
|---|------|---------|
| 1 | **twenty.nix → mkDockerService** | 188 → 145 lines (-43). Last active Docker service with inline boilerplate. |
| 2 | **gatus-config.nix → mkHttpCheck** | 283 → 237 lines (-46). 15 HTTP endpoints collapsed, `discordAlert` helper. |
| 3 | **Consecutive-failure lib.sh** | niri-drm-healthcheck: 53 → 36, display-watchdog: 103 → 82, lib.sh: +33. Net -38. |

### Sessions 24–29 — External Agent Work

| # | Item | Session |
|---|------|---------|
| 4 | **Deduplication sprint** (-196 net lines, 28 files) | 24 |
| 5 | **mkDockerService factory + openseo/manifest refactoring** | 24 |
| 6 | **harden/hardenUser unified** (deleted user-harden.nix) | 24 |
| 7 | **serviceModules list in flake.nix** (single source of truth) | 24 |
| 8 | **colorScheme shared module** | 24 |
| 9 | **browser-policies module** (absorbed Firefox policies from dns-blocker) | 24 |
| 10 | **8 offensive security tools removed** | 24 |
| 11 | **GPG → SSH git signing** | 24 |
| 12 | **Dead code removal** (monitoring.nix, user-harden.nix, chromium-policies, auditd, allowUnfreePredicate) | 24 |
| 13 | **onFailure standardization** (21 service files) | 24 |
| 14 | **Fix ClamAV onFailure** (explicit, not inherited) | 26 |
| 15 | **Signoz port options → serviceTypes.servicePort** | 28 |
| 16 | **mkStateDir helper** for tmpfiles boilerplate | 28 |
| 17 | **Delete dead graphical-user-service.nix** | 28 |
| 18 | **Remove duplicate fail2ban config** from configuration.nix | 28 |
| 19 | **todo-list-ai npmDeps hash fix** | 29 |
| 20 | **shellcheck directive fixes** for lib.sh-sourced scripts | 29 |
| 21 | **Flake input updates** (3 separate dep bumps, 37+ inputs total) | 24–29 |
| 22 | **AGENTS.md updates** (lib helpers, mkStateDir, patterns) | 28 |

### Session 23 — My Work

| # | Item | Details |
|---|------|---------|
| 23 | **Display watchdog self-healing** | `scripts/display-watchdog.sh` — 3-stage recovery for dead display |
| 24 | **niri-health-metrics permission fix** | tmpfiles 1777 for textfile collector dir |

### Cumulative (Sessions 1–22) — Still Done

All items from previous status reports remain done: zero `go install` tools, GPU OOM defense, DRM healthcheck, dual-WAN, DNS blocker, EMEET PIXY, centralized AI storage, wallpaper self-healing, Taskwarrior sync, lib/ shared helpers, pre-commit hooks, SigNoz, Gatus, OpenSEO, etc.

---

## B) PARTIALLY DONE

| # | Item | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | **Deploy** | All changes built, validated, committed | **8 sessions of undeployed changes**. Caddy down since session 20. Display watchdog not active. |
| 2 | **onFailure standardization** | 21 files use `inherit onFailure` or factory-included | 1 file still has inline `onFailure` (security-hardening ClamAV — intentional, fixed in session 26) |
| 3 | **photomap.nix** | Exists as Docker service | Not refactored to mkDockerService — disabled service, not worth touching |
| 4 | **SigNoz alert rules** | `signoz-alerts.nix` has mkRule helper, rules defined | Not loaded into SigNoz API |
| 5 | **TODO_LIST.md** | Exists | Stale since session 21 (May 11). Many items completed since. |

---

## C) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | **Deploy all accumulated changes** | 🔴 CRITICAL | 8 sessions, ~290 lines of improvements sitting undeployed. Caddy DOWN. |
| 2 | **Automated backup** (Immich, Gitea, Taskwarrior) | 🔴 CRITICAL | No scheduled backups. Only manual commands. |
| 3 | **nix GC timer** (weekly) | 🟡 HIGH | Root at 91%. /nix/store at 88G. No auto-cleanup. |
| 4 | **Caddy log rotation** | 🟡 HIGH | No logrotate. Risk of disk fill. |
| 5 | **Caddy actual-proxy health check** | 🟡 HIGH | Gatus checks /metrics not proxy pipeline. |
| 6 | **Fix Timeshift snapshot service** | 🟡 MEDIUM | Both backup + verify services failed. |
| 7 | **Disk space alerting** (85%+) | 🟡 MEDIUM | No early warning. Already at 91%. |
| 8 | **TLS cert auto-renewal** | 🟡 MEDIUM | Static cert. Gatus checks expiry but no renewal. |
| 9 | **CI/CD pipeline** | 🟡 MEDIUM | No automated builds. Gitea Actions runner exists. |
| 10 | **Service self-registration** | 🟢 LOW | Deferred — architecture change, too invasive for sprint. |
| 11 | **Caddy vhosts as data** | 🟢 LOW | Deferred — `protectedVHost` already works. Marginal benefit. |
| 12 | **Provision Pi 3** for DNS failover | 🟢 LOW | Module written, hardware not provisioned. |
| 13 | **docs/ cleanup** | 🟢 LOW | 80+ files, many stale. |

---

## D) TOTALLY FUCKED UP

| # | Item | Severity | Details |
|---|------|----------|---------|
| 1 | **🔴 Caddy FAILED** | CRITICAL | All `*.home.lan` services down. Likely undeployed since session 20 (ReadWritePaths fix). **8 sessions of accumulated fixes not deployed.** |
| 2 | **🔴 Root disk 91%** | CRITICAL | 449G/512G used. Only 48G free. /nix/store 88G. Went from 88% → 91% since last report. Needs GC immediately. |
| 3 | **Timeshift FAILED** | HIGH | Both backup and verify services failed. BTRFS snapshots not running. |
| 4 | **niri-health-metrics FAILED** | MEDIUM | Permission denied writing metrics. Fix built in session 23, never deployed. |
| 5 | **service-health-check FAILED** | MEDIUM | Cascading failure from Caddy being down. |
| 6 | **Flake lock dirty** | LOW | External process updated flake.lock but it wasn't staged/committed. |

---

## E) WHAT WE SHOULD IMPROVE

### Critical — Deploy Gap

1. **8 sessions without a deploy.** The build is green, all changes validated, but nothing is running. This is the single biggest risk — Caddy has been down for potentially a full day. The display watchdog and niri-health-metrics fix from session 23 are still not active.

2. **No deploy verification.** Even after `just switch`, there's no automated check that Caddy, niri, and DNS are actually running. Should add `just deploy` = `just switch` + health check.

### Architecture

3. **Abstraction plan is complete.** The 3 high-value items from the plan are done. The 2 deferred items are correctly deferred (marginal benefit vs. effort). The remaining improvements are operational (backups, GC, alerting), not code structure.

4. **290 lines removed across ~40 files** with stronger patterns. Adding a new Docker service is now ~30 lines. Adding a Gatus endpoint is now ~5 lines. The `state_*` helper eliminates a class of state-file bugs.

### Process

5. **Root disk went from 88% → 91%** in one session window. /nix/store grew from 83G → 88G (5G in one session from builds). Auto-GC is essential.

6. **AGENTS.md at 927 lines.** Still growing. The "gotchas" section is a code smell — each gotcha should ideally be fixed, not documented.

---

## F) Top 25 Things To Get Done Next

### P0 — IMMEDIATE

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **`just switch` — deploy 8 sessions of changes** | Caddy restored, display watchdog active, all fixes live | 10 min |
| 2 | **`nix-collect-garbage --delete-older-than 3d`** | Reclaim ~15G (91% → ~80%) | 10 min |
| 3 | **Stage + commit flake.lock + shellcheck fixes** | Clean working tree | 2 min |
| 4 | **Verify critical services after deploy** (Caddy, niri, DNS) | Confirm deployment worked | 2 min |

### P1 — HIGH PRIORITY

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 5 | **Add nix GC timer** (weekly, 3d threshold) | Prevent disk exhaustion permanently | 30 min |
| 6 | **Fix Caddy health check in Gatus** — test actual proxy | Prevents future silent outages | 30 min |
| 7 | **Fix Timeshift snapshot service** | BTRFS backups running | 30 min |
| 8 | **Set up backup automation** (Immich, Gitea, Taskwarrior) | Data loss prevention | 2h |
| 9 | **Add disk space alert** (85%+ threshold) | Early warning | 30 min |
| 10 | **Add Caddy log rotation** | Prevent disk fill | 30 min |

### P2 — MEDIUM PRIORITY

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 11 | **Deploy SigNoz alert rules** from signoz-alerts.nix | Active monitoring | 1h |
| 12 | **Disable ComfyUI zombie service** | Clean monitoring noise | 5 min |
| 13 | **Refresh TODO_LIST.md** against codebase | Accurate planning | 1h |
| 14 | **Add deploy verification** (`just switch` + health check) | Deploy confidence | 1h |
| 15 | **Clean up docs/ directory** — archive stale files | Reduce clutter (80+ files) | 1h |
| 16 | **Implement TLS cert auto-renewal** | Prevent cert expiry | 3h |
| 17 | **Restructure AGENTS.md** — extract reference sections | Maintainability (927 lines) | 2h |

### P3 — BACKLOG

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 18 | **Service self-registration** (caddy + gatus auto-wiring) | New service = 4 steps not 7 | 3h |
| 19 | **Caddy vhosts as data-driven list** | 15 → 1 line per vhost | 1h |
| 20 | **Set up Gitea Actions CI** for this repo | Automated build testing | 3h |
| 21 | **Provision Pi 3** for DNS failover cluster | HA DNS | 4h |
| 22 | **Create NixOS integration test framework** | Automated quality | 4h |
| 23 | **Configure Twenty CRM** production setup | Business tool | 2h |
| 24 | **Distributed builds** (Darwin → evo-x2) | Faster macOS builds | 3h |
| 25 | **Photomap service fix** (podman permissions) | Re-enable photo exploration | 2h |

---

## G) Top #1 Question I Cannot Answer

**Is it safe to deploy all 8 sessions of changes in one `just switch`, or should we do it incrementally?**

We have ~18 commits of undeployed changes touching ~40 files:
- Session 23: display-watchdog, niri-health-metrics permission fix
- Session 24: mkDockerService, harden merge, dead code, security tools, SSH signing, browser-policies, colorScheme, serviceModules
- Sessions 25–30: bug fixes, mkHttpCheck, mkDockerService adoption, consecutive-failure DRY, flake updates

All have been validated with `just test-fast` (syntax check). But `just test-fast` only checks Nix evaluation — it doesn't verify that services actually start, configs are valid, or ports don't conflict. A full `nixos-rebuild switch` is the real test.

**My recommendation:** Deploy it all. The changes are well-structured (abstractions, dead code removal, bug fixes) and the build passes. But after deploy, immediately verify: Caddy up, niri running, DNS resolving, display-watchdog timer active.

---

## Self-Healing Coverage Matrix (Current State)

| Failure Mode | Detection | Recovery | Deployed? |
|---|---|---|---|
| GPU driver hang | niri-drm-healthcheck (60s) | gpu-recovery (amdgpu rebind) | ✅ Active |
| Niri DRM zombie errors | niri-drm-healthcheck (consecutive) | gpu-recovery after 3 hits | ✅ Active |
| Display no signal | display-watchdog (30s) | display-manager restart → VT switch → GPU recovery | ❌ Not deployed |
| Wallpaper daemon crash | systemd Restart=always | PartOf propagation | ✅ Active |
| Ollama GPU OOM | MAX_LOADED_MODELS=1, OOM scoring | OOM killer prefers niri | ✅ Active |
| Dual-WAN ISP failure | route-health-monitor (2s) | ECMP weight shift | ✅ Active |
| DNS upstream failure | Unbound DoT to Quad9 | Cloudflare fallback | ✅ Active |
| **Caddy crash** | **None** | **Manual restart only** | ❌ GAP |
| **Disk exhaustion** | **None** | **None** | ❌ GAP |

---

## System State Snapshot

| Metric | Value | Trend |
|--------|-------|-------|
| **Hostname** | evo-x2 | — |
| **Kernel** | 7.0.1 (NixOS) | — |
| **Niri** | Running, display active | ✅ Stable |
| **Root disk** | **91%** (449G/512G, 48G free) | 🔴 ↑ from 88% |
| **/nix/store** | 88G | ↑ from 83G |
| **Data disk** | 80% (819G/1T, 206G free) | Stable |
| **Memory** | 44G/62G (70%), swap 11G/25G | ✅ Better than last (was 79%) |
| **Failed services** | Caddy, niri-health-metrics, service-health-check, timeshift-backup, timeshift-verify | 🔴 Same as last report |

## Project Stats

| Metric | Count |
|--------|-------|
| NixOS service modules | ~36 |
| Docker services on mkDockerService | 3 of 4 (photomap disabled) |
| Gatus endpoints on mkHttpCheck | 15 of 26 |
| Scripts using state_* helper | 2 (display-watchdog, niri-drm-healthcheck) |
| Flake inputs | 39 |
| Shared overlays (mkPackageOverlay) | 11 |
| lib/ helpers | 6 (default, docker, systemd, types, rocm, systemd/service-defaults) |
| AGENTS.md | 927 lines |
| Undeployed commits | 18 |
| Commits since session 23 | 18 |
