# Session 23 — Display Watchdog Self-Healing + Full Status

**Date:** 2026-05-16 23:30
**Session type:** Self-healing display recovery + comprehensive status audit
**Trigger:** Display went "No Signal" — niri stopped driving output, monitor dead, user had to physically press Ctrl+Alt+F1/F2

---

## Executive Summary

The evo-x2 display went completely dark ("No Signal") because niri stopped running while the DRM output was left in `enabled=disabled + dpms=Off`. **No existing healthcheck caught this** — niri-drm-healthcheck only runs when niri IS running, so the gap was a dead display with no compositor to notice.

**Built `display-watchdog`** — a system service that runs every 30s, detects connected-but-dead displays, and self-recovers through a 3-stage ladder: restart display-manager → VT switch → GPU recovery. Also fixed `niri-health-metrics` permission denied (textfile collector dir owned by `nobody`).

**Health:** 🟢 Niri running | 🟢 Display recovered | 🔴 3 system services failed (Caddy, niri-health-metrics, service-health-check) | 🟡 Root disk 88%

---

## The Incident

### What happened

1. Niri stopped running (unclear exact cause — may have been killed during `just switch` or crashed)
2. DRM connector `card1-DP-2` entered `enabled=disabled, dpms=Off`
3. Monitor showed "No Signal"
4. SDDM's X server was alive on tty2 but NOT driving the DP-2 connector
5. **Nothing self-healed** because:
   - `niri-drm-healthcheck` has `pgrep -x niri || exit 0` — skips entirely when niri is down
   - `gpu-recovery` requires manual trigger or drm-healthcheck escalation
   - SDDM doesn't reclaim outputs it wasn't configured for
   - Kernel doesn't spontaneously re-enable dead DRM outputs

### How user fixed it manually

Pressed **Ctrl+Alt+F1** then **Ctrl+Alt+F2** — kernel VT switch forced DRM/KMS to reprogram the CRTC, set DPMS to On, monitor detected signal.

### Why this matters

This is a **blind spot** in the entire self-healing stack. The system has:
- GPU driver hang detection (niri-drm-healthcheck + gpu-recovery)
- Wallpaper self-healing (awww-daemon crash recovery)
- OOM protection for niri
- Dual-WAN failover
- DNS failover cluster (planned)

...but **nothing was watching for "display is connected but nobody is driving it."**

---

## A) FULLY DONE

### This Session

| # | Item | Details |
|---|------|---------|
| 1 | **Display watchdog script** | `scripts/display-watchdog.sh` — detects connected+disabled+dpms-Off connectors when no compositor running. 3-stage recovery ladder: display-manager restart → VT switch → GPU recovery. Runs every 30s. |
| 2 | **Display watchdog service** | `modules/nixos/services/niri-config.nix` — system service + timer, hardened (`MemoryMax=512M`, `ReadWritePaths`), `OOMScoreAdjust=-500` |
| 3 | **niri-health-metrics permission fix** | Added tmpfiles rule `d ... textfile_collectors 1777 root root` — fixes `Permission denied` writing metrics. Dir was `nobody:nogroup 755` (DynamicUser from node_exporter). |
| 4 | **Build validated** | `just test-fast` passes clean. All NixOS modules check. |
| 5 | **Diagnosed display incident root cause** | Full analysis: DRM output left dead, kernel needs VT switch trigger to re-enable CRTC. Documented for future reference. |

### Previously Completed (Cumulative — Sessions 1–22)

| # | Item | Since |
|---|------|-------|
| 6 | **govalid Nix package** (last go install tool) | Session 22 |
| 7 | **~/go/bin sessionPath eliminated** | Session 22 |
| 8 | **projects-management-automation as 10th shared overlay** | Session 21 |
| 9 | **Caddy ReadWritePaths fix** (11h crash loop) | Session 20 |
| 10 | **Hermes upgrade to v2026.5.7** | Session 19 |
| 11 | **All 10 flake-input overlays via mkPackageOverlay** | Sessions 19,21 |
| 12 | **6 missing overlay tools added to home.packages** | Session 18 |
| 13 | **Shell script formatting normalized** | Session 17 |
| 14 | **Dual-WAN ECMP+MPTCP active-active failover** | Sessions 11-12 |
| 15 | **GPU OOM multi-layer defense** (OLLAMA_MAX_LOADED_MODELS=1, OOMScoreAdjust) | Session 13 |
| 16 | **Niri DRM healthcheck + GPU recovery** (consecutive failure counter) | Session 10 |
| 17 | **DNS blocker stack** (Unbound + dnsblockd, 2.5M+ domains) | Session 8 |
| 18 | **EMEET PIXY webcam daemon** (call detection, auto-tracking) | Session 5 |
| 19 | **Centralized AI model storage** (/data/ai/ hierarchy) | Session 7 |
| 20 | **Wallpaper self-healing** (PartOf, not BindsTo) | Session 9 |
| 21 | **Taskwarrior + TaskChampion cross-platform sync** | Session 6 |
| 22 | **lib/ shared helpers** (harden, hardenUser, serviceDefaults, types, mkGraphicalUserService, rocm) | Session 8 |
| 23 | **Pre-commit hooks** (statix, deadnix, treefmt+alejandra, shellcheck) | Session 4 |
| 24 | **SigNoz observability pipeline** (6 dashboards, journald, Prometheus scraping) | Sessions 13-15 |
| 25 | **Gatus health monitoring** (26+ endpoints, Discord alerting) | Session 14 |
| 26 | **OpenSEO, Monitor365, file-and-image-renamer** services | Sessions 12-16 |
| 27 | **flake-parts modular architecture** (41 service modules) | Session 1 |
| 28 | **Cross-platform Home Manager** (14 programs, 70+ packages) | Session 1 |
| 29 | **All path: inputs → git+ssh: URLs** | Session 5 |
| 30 | **Pipe operators enabled** | Session 7 |
| 31 | **primaryUser module** (eliminated 15 hardcoded refs) | Session 9 |
| 32 | **Overlay extraction to overlays/ directory** | Session 13 |
| 33 | **Helium restore-last-session wrapper** | Session 13 |
| 34 | **WiFi interface naming fix** (wlan0 not wlp195s0) | Session 11-12 |
| 35 | **resolvconf nameserver fix** (127.0.0.1 only) | Session 11-12 |
| 36 | **awww-daemon crash loop mitigation** (StartLimitBurst, Wayland check) | Session 13 |

---

## B) PARTIALLY DONE

| # | Item | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | **DNS failover cluster** | Module written (`dns-failover.nix`), Keepalived VRRP configured, evo-x2 + rpi3 configs in flake.nix | Pi 3 hardware not provisioned. Untested in production. |
| 2 | **ComfyUI service** | Module exists, Caddy vhost, Gatus endpoint | WorkingDirectory doesn't exist — zombie service. Should disable. |
| 3 | **Photomap service** | Module exists, Caddy vhost, Gatus endpoint | Disabled — podman permission issue. |
| 4 | **OpenSEO** | Deployed, Docker, Caddy + Authelia | Requires active DataForSEO API key. Needs real usage test. |
| 5 | **Voice agents** | Whisper ASR + LiveKit configured, Caddy vhosts | LiveKit untested in production. |
| 6 | **SigNoz alert rules** | `signoz-alerts.nix` has mkRule helper, rules defined in Nix | Not loaded into SigNoz API. Rules exist as files but SigNoz doesn't read them. |
| 7 | **Twenty CRM** | Module deployed, Docker running | Needs post-setup configuration. Has its own docs (`twenty-POST-SETUP.md`). |
| 8 | **TODO_LIST.md** | Exists with tasks | **11 days stale** (May 11). Many items already completed. Needs full rebuild. |
| 9 | **Display watchdog** | Script + service + timer built, validated | **Not deployed yet** (`just switch` not run). Will be active after next deploy. |
| 10 | **niri-health-metrics** | Permission fix in nix config | **Not deployed yet**. Currently failing every 30s with Permission denied. |

---

## C) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | **Backup automation** | 🔴 CRITICAL | No automated backups for Immich DB, Gitea, Taskwarrior. Manual commands only (`just immich-backup`, `just task-backup`). No restore testing. |
| 2 | **Caddy log rotation** | 🟡 High | No logrotate for `/var/log/caddy/`. Risk of disk fill on busy proxy. Was down 11h in session 20. |
| 3 | **Automated nix GC timer** | 🟡 High | No periodic GC. Root at 88%. Darwin at 90-95%. Risk of build failures. |
| 4 | **TLS certificate auto-renewal** | 🟡 Medium | dnsblockd CA cert is static. Gatus checks expiry but no auto-renewal mechanism. |
| 5 | **CI/CD pipeline** | 🟡 Medium | No automated builds on push. All testing manual. Gitea Actions runner exists but not wired to this repo. |
| 6 | **Disk space monitoring alert** | 🟡 Medium | No alert when disk exceeds 85%. Root at 88% right now. |
| 7 | **Caddy actual-proxy health check** | 🟡 Medium | Gatus checks `/metrics` not actual proxy pipeline. Would have caught the 11h outage in minutes. |
| 8 | **NixOS integration tests** | 🟢 Low | `just test-fast` = syntax only. No service-level tests. |
| 9 | **Home Manager Darwin tests** | 🟢 Low | No automated macOS build test. |
| 10 | **Minecraft server** | 🟢 Low | Module exists, disabled. |
| 11 | **Distributed builds** (Darwin → evo-x2) | 🟢 Low | MacBook Air disk exhaustion (229 GB, 90-95%). |
| 12 | **Service catalog documentation** | 🟢 Low | No port map / dependency diagram. AGENTS.md has partial list. |
| 13 | **go-auto-upgrade golangci-lint fix** | 🟢 Low | `gomodguard_v2` unknown linter. External repo. |
| 14 | **AGENTS.md cleanup** | 🟢 Low | 921 lines. Many gotchas are documented bugs that should be fixed instead. |
| 15 | **docs/ directory cleanup** | 🟢 Low | 80+ files, many stale/duplicate. Needs archival. |

---

## D) TOTALLY FUCKED UP

| # | Item | Severity | Details | Status |
|---|------|----------|---------|--------|
| 1 | **Caddy is FAILED right now** | 🔴 CRITICAL | `caddy.service` is in failed state. All virtual hosts (`*.home.lan`) are down. Unknown how long — potentially since session 20's ReadWritePaths fix wasn't deployed. | **Needs immediate `just switch`** |
| 2 | **niri-health-metrics failing every 30s** | 🟡 HIGH | Permission denied writing to textfile collector dir (nobody:nogroup 755). Fix written but not deployed. | **Fix staged, awaiting deploy** |
| 3 | **service-health-check is FAILED** | 🟡 MEDIUM | Likely depends on Caddy being up. Cascading failure. | **Will resolve with Caddy fix** |
| 4 | **Disk at 88% on evo-x2 root** | 🟡 ONGOING | 435G/512G used. 60G free. No automated cleanup. /nix/store alone is 83G. | **Needs GC + nix-collect-garbage** |
| 5 | **Swap at 40% usage** (10G/25G) | 🟡 WARNING | 49G/62G RAM used. Heavy services (ClickHouse 750M, Hermes 328M, Ollama, llama-server 970M). Swap pressure suggests memory overcommit. | **Monitor** |
| 6 | **ComfyUI zombie service** | 🟡 LOW | Enabled but path doesn't exist. ExecCondition skips gracefully but systemd still attempts startup. Gatus fails. | **Should disable** |
| 7 | **Display was dead for unknown duration** | 🟢 FIXED | No signal until user manually VT-switched. display-watchdog built to prevent recurrence. | **Fix built, not yet deployed** |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture — Critical Gaps

1. **Self-healing coverage is incomplete** — The display incident revealed that the existing healthcheck stack has blind spots. The new display-watchdog closes one gap, but the pattern is: we build reactive fixes AFTER incidents, not proactive coverage of all failure modes. Should systematically enumerate all single points of failure and ensure each has automated recovery.

2. **Caddy is a SPOF with no auto-recovery** — ALL `*.home.lan` services depend on Caddy. It's currently FAILED. There's no Caddy-specific watchdog. The `service-health-check` service also depends on Caddy, creating a circular dependency. Need independent Caddy liveness check.

3. **Deploy gap** — Changes are built and validated but not always deployed immediately. The Caddy ReadWritePaths fix from session 20 might not have been deployed, leaving Caddy down for potentially days.

### Process

4. **No deploy verification** — After `just switch`, no automated check that critical services (Caddy, niri, DNS) are actually running. Should add `just deploy` that runs `just switch` then verifies health.

5. **No backup automation or restore testing** — Immich DB, Gitea repos, Taskwarrior data are all at risk. `just immich-backup` and `just task-backup` exist but are manual.

6. **TODO_LIST.md is 11 days stale** — Last updated May 11. Several items completed since then. Needs full rebuild.

7. **docs/ directory is a dump** — 80+ files, many stale or duplicate. `archive/` exists but unused. Should triage.

8. **Flake input updates are manual** — No weekly automated update+build cycle. Last update was session 21 (today).

### Code Quality

9. **AGENTS.md at 921 lines** — Excellent documentation but has grown organically. Should be restructured: reference sections extracted to separate files, gotchas converted to actual fixes.

10. **No integration tests** — `just test-fast` only validates Nix syntax. No verification that systemd units are correct, services start, or configurations are valid.

11. **Multiple zombie/disabled services generating noise** — ComfyUI, photomap, and potentially others. Gatus reports failures for services that are known-disabled. Should conditionally include endpoints.

---

## F) Top 25 Things To Get Done Next

### P0 — Immediate (Next Deploy)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy to evo-x2** (`just switch`) — ships display-watchdog, niri-health-metrics fix, and all session 20-23 work | All pending fixes | 10 min |
| 2 | **Restart Caddy** — it's FAILED right now. All `*.home.lan` services down | Critical — all web services | 1 min |
| 3 | **Run `nix-collect-garbage --delete-older-than 7d`** on evo-x2 | Reclaim disk (88% → ~75%) | 10 min |
| 4 | **Verify display-watchdog works** — stop niri, wait 30-60s, confirm display self-recovers | Validate self-healing | 5 min |

### P1 — High Priority (This Sprint)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 5 | **Fix Caddy health check in Gatus** — test actual vhost proxy, not just /metrics | Prevents future silent 11h outages | 30 min |
| 6 | **Disable ComfyUI service** (dead path reference) | Clean up zombie + monitoring noise | 5 min |
| 7 | **Set up automated backup schedule** (Immich DB, Gitea, Taskwarrior) via systemd timers | Data loss prevention | 2h |
| 8 | **Add Caddy access log rotation** (logrotate) | Prevent disk fill | 30 min |
| 9 | **Add periodic nix GC timer** (weekly, 7d threshold) | Prevent disk exhaustion | 30 min |
| 10 | **Deploy SigNoz alert rules** from signoz-alerts.nix | Active monitoring instead of passive | 1h |

### P2 — Medium Priority (Next Sprint)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 11 | **Add disk space monitoring alert** (85%+ threshold via Gatus/custom) | Early warning | 30 min |
| 12 | **Add deploy verification** — `just switch` + health check pass | Confidence in deploys | 1h |
| 13 | **Refresh TODO_LIST.md** against current codebase | Accurate planning | 1h |
| 14 | **Fix photomap service** (podman permission issue) | Re-enable photo exploration | 2h |
| 15 | **Clean up docs/ directory** — archive stale files, consolidate | Reduce clutter (80+ files) | 1h |
| 16 | **Test voice agents** end-to-end | Validate deployment | 1h |
| 17 | **Audit all ReadWritePaths** for harden{} services | Prevent caddy-class bugs | 1h |

### P3 — Nice To Have (Backlog)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 18 | **Set up Gitea Actions CI** for this repo | Automated build testing | 3h |
| 19 | **Provision Pi 3** for DNS failover cluster | HA DNS | 4h |
| 20 | **Set up distributed builds** (Darwin → evo-x2) | Faster macOS builds | 3h |
| 21 | **Implement TLS cert auto-renewal** | Prevent cert expiry | 3h |
| 22 | **Configure Twenty CRM** production setup | Business tool | 2h |
| 23 | **Create NixOS integration test framework** | Automated quality | 4h |
| 24 | **Document services in catalog** (port map, deps, healthcheck mapping) | Operational clarity | 2h |
| 25 | **Restructure AGENTS.md** — extract reference sections to separate files | Maintainability (921 lines) | 2h |

---

## G) Top #1 Question I Cannot Answer

**Is Caddy's failure related to the ReadWritePaths fix from session 20 not being deployed, or is there a new issue?**

The health check shows `caddy.service` in failed state. Session 20 added `/var/log/caddy` to ReadWritePaths, but that fix might not have been deployed to this running system. If it WAS deployed and Caddy is still failing, there's a new root cause we need to investigate. If it WASN'T deployed, then deploying now (`just switch`) will fix it. I cannot determine which case this is without checking the deployed generation vs. the git state.

**Action:** After `just switch`, check if Caddy starts cleanly. If not, `journalctl -u caddy -n 50` for root cause.

---

## Self-Healing Coverage Matrix

| Failure Mode | Detection | Recovery | Status |
|---|---|---|---|
| GPU driver hang | niri-drm-healthcheck (60s) | gpu-recovery (amdgpu rebind + reboot) | ✅ Active |
| Niri DRM zombie errors | niri-drm-healthcheck (consecutive counter) | gpu-recovery after 3 consecutive | ✅ Active |
| Display no signal (no compositor) | **display-watchdog** (30s) | display-manager restart → VT switch → GPU recovery | 🆕 Built, not deployed |
| Wallpaper daemon crash | systemd `Restart=always` | PartOf propagates restart to wallpaper | ✅ Active |
| Ollama GPU OOM | OOMScoreAdjust=500, MAX_LOADED_MODELS=1 | OOM killer prefers niri (-1000) | ✅ Active |
| awww-daemon BrokenPipe panic | systemd Restart + StartLimitBurst | Auto-restart, Wayland check gate | ✅ Active |
| Dual-WAN ISP failure | route-health-monitor (2s) | ECMP weight shift → WiFi failover | ✅ Active |
| DNS upstream failure | Unbound DoT to Quad9 | Cloudflare fallback | ✅ Active |
| **Caddy crash** | **None — only Gatus /metrics check** | **Manual restart only** | ❌ GAP |
| **Disk exhaustion** | **None** | **None** | ❌ GAP |
| **Service config drift** | **None** | **Manual `just switch`** | ❌ GAP |

---

## System State Snapshot

| Metric | Value |
|--------|-------|
| **Hostname** | evo-x2 |
| **Kernel** | 7.0.1 (NixOS SMP PREEMPT_DYNAMIC) |
| **Nix** | 2.34.6 |
| **Niri** | Running, display enabled, DPMS On |
| **Root disk** | 88% (435G/512G, 60G free) |
| **Data disk** | 80% (819G/1T, 206G free) |
| **/nix/store** | 83G |
| **Memory** | 49G/62G used (79%), swap 10G/25G |
| **Failed services** | Caddy, niri-health-metrics, service-health-check |

## Project Stats

| Metric | Count |
|--------|-------|
| Nix files | ~110 |
| Shell scripts | 22 (was 21, +display-watchdog) |
| NixOS service modules | 41 |
| Cross-platform programs | 14 |
| Custom packages (pkgs/) | 7 |
| Flake inputs | 39 |
| Shared overlays (mkPackageOverlay) | 10 |
| Local package overlays | 4 |
| Linux-only overlays | 6 |
| Justfile recipes | 78 |
| lib/ helpers | 7 (default, systemd, user-harden, service-defaults, types, rocm, graphical-user-service) |
| ADRs | 6 |
| AGENTS.md | 921 lines |
| Status reports | 35+ (including this one) |
| `go install` tools remaining | **0** |

## Changed Files This Session

| File | Change |
|------|--------|
| `scripts/display-watchdog.sh` | New — display dead-output detection + 3-stage recovery |
| `modules/nixos/services/niri-config.nix` | Added displayWatchdog derivation, display-watchdog service + timer, tmpfiles rules for display-watchdog state dir + textfile collectors 1777 |
