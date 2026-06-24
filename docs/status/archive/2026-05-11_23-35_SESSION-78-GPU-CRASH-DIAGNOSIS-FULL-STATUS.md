# SystemNix — Full Comprehensive Status Report

**Date:** 2026-05-11 23:35 CEST
**Session:** 78 — Post-Incident GPU Crash Diagnosis & Recovery Analysis
**System:** evo-x2 (NixOS 26.05 unstable, Linux 7.x, AMD Ryzen AI Max+ 395, 128GB)
**Uptime:** 54 min (fresh reboot after GPU crash cascade)
**Platform:** NixOS x86_64-linux + macOS aarch64-darwin (Lars-MacBook-Air)

---

## Executive Summary

System recovered from a **GPU DRM zombie state** at ~22:26 CEST that caused two failed GPU recovery attempts and an involuntary reboot. Root cause: amdgpu driver entered `Error::DeviceMissing` state, and the `gpu-recovery.sh` script's single-shot rebind failed. A **clickhouse log directory** (`/var/log/clickhouse-server`) was also missing since the last switch, causing cascading service failures (SigNoz, Gatus).

Both fixes are **committed but NOT yet deployed** — `just switch` + reboot is needed to apply them. The system is currently running on the last generation with the sops fix from session 76 applied, but clickhouse and gatus are still broken until the next switch.

### System Health: 🟡 DEGRADED

| Metric | Value |
|--------|-------|
| Boot count today | 3+ (multiple GPU crash recoveries) |
| Disk `/` | 80% used (394G/512G) |
| Disk `/data` | 80% used (819G/1.0T) |
| Load average | 3.47, 2.48, 3.02 |
| Uncommitted changes | None (working tree clean) |
| Pending deployment | clickhouse tmpfiles fix, GPU recovery retries |

---

## A) FULLY DONE ✅

### Infrastructure & Core Services

| Component | Status | Notes |
|-----------|--------|-------|
| **Niri Wayland compositor** | ✅ Running | Session manager, wallpaper self-healing, DRM healthcheck |
| **Caddy reverse proxy** | ✅ Running | TLS via sops, all `*.home.lan` domains |
| **Authelia SSO** | ✅ Running | Forward auth protecting all services |
| **Gitea** | ✅ Running | Git hosting + GitHub mirror sync |
| **Homepage dashboard** | ✅ Running | Service overview at `home.lan` |
| **TaskChampion sync** | ✅ Running | Cross-platform task sync at `tasks.home.lan` |
| **DNS blocking stack** | ✅ Running | Unbound + dnsblockd, 2.5M+ domains blocked |
| **Docker** | ✅ Running | All containers healthy |
| **SOPS secrets** | ✅ Fixed | Owner fix deployed in session 76 |
| **GPU defense in depth** | ✅ Committed | OLLAMA_MAX_LOADED_MODELS=1, GPU overhead, OOMScoreAdjust |
| **Pipe operators** | ✅ Complete | All modules migrated from `builtins` chains to `|>` |

### Monitoring & Observability

| Component | Status | Notes |
|-----------|--------|-------|
| **SigNoz (partial)** | ⚠️ Collector running | ClickHouse down (log dir missing) |
| **Gatus health checks** | ⚠️ Down | Env file missing (needs reboot to regenerate) |
| **node_exporter** | ✅ Running | System metrics on :9100 |
| **cAdvisor** | ✅ Running | Container metrics on :9110 |
| **GPU metrics** | ✅ Running | VRAM/busy/temp via textfile collector |
| **Niri health metrics** | ⚠️ Permission issue | Textfile dir ownership wrong |

### Cross-Platform Configuration

| Component | Status | Notes |
|-----------|--------|-------|
| **Darwin (macOS)** | ✅ Complete | nix-darwin + Home Manager, shared overlays |
| **NixOS (evo-x2)** | ✅ Mostly complete | 30+ services enabled |
| **rpi3-dns** | ✅ Code complete | Pi 3 not yet provisioned |
| **Flake architecture** | ✅ Clean | flake-parts, no TODOs, no commented-out code |
| **Overlays extraction** | ✅ Complete | shared.nix + linux.nix, all private repos via SSH |
| **Shared lib/** | ✅ Well-adopted | harden (65+ uses), serviceDefaults (50+ uses) |

### Desktop & Hardware

| Component | Status | Notes |
|-----------|--------|-------|
| **Niri compositor** | ✅ Running | Wrapped config, session save/restore |
| **Waybar** | ✅ Running | Catppuccin Mocha theme |
| **SDDM login** | ✅ Running | silent-sddm theme |
| **AMD GPU** | ✅ Running | ROCm, VRAM metrics, amdgpu recovery |
| **AMD NPU** | ✅ Configured | XDNA driver via nix-amd-npu input |
| **Bluetooth** | ✅ Running | |
| **EMEET PIXY webcam** | ✅ Running | Auto-tracking, privacy mode, Waybar indicator |
| **Dual-WAN** | ✅ Running | MPTCP + route health monitoring |
| **Steam/gaming** | ✅ Configured | Steam + gamemode + gamescope + mangohud |
| **Minecraft server** | ✅ Configured | Full module with whitelist, hardening, Prism Launcher |

### Development & Tooling

| Component | Status | Notes |
|-----------|--------|-------|
| **Shell config (fish/zsh/bash)** | ✅ Complete | Cross-platform aliases, starship prompt |
| **Git config** | ✅ Complete | Shared across platforms |
| **tmux** | ✅ Complete | |
| **fzf** | ✅ Complete | |
| **Taskwarrior** | ✅ Complete | Synced across all devices including Android |
| **pre-commit** | ✅ Complete | treefmt + alejandra + statix |
| **SSH config** | ✅ External | Via `nix-ssh-config` flake input |
| **Chromium policies** | ✅ Complete | Dark mode, restore session flags |

---

## B) PARTIALLY DONE ⚠️

| Component | Status | What's Missing |
|-----------|--------|---------------|
| **ClickHouse** | ⚠️ Down | `/var/log/clickhouse-server` missing — tmpfiles fix committed but not deployed |
| **Gatus** | ⚠️ Down | `gatus-env` env file missing — needs reboot to regenerate from sops template |
| **SigNoz** | ⚠️ Degraded | Collector running but can't write to ClickHouse (down) |
| **Niri DRM healthcheck** | ⚠️ False positives | `DeviceMissing` errors since boot -2 (~410K per boot) — healthcheck triggers recovery too eagerly |
| **monitor365** | ⚠️ Disabled | `enable = false` in configuration.nix — "high RAM usage" |
| **PhotoMap** | ⚠️ Disabled | Commented out — "podman config permission issue" |
| **nix-colors** | ⚠️ Partially integrated | 17+ hardcoded colors not migrated to scheme |
| **DNS failover cluster** | ⚠️ Code complete | rpi3-dns config exists but Pi 3 hardware not provisioned |

---

## C) NOT STARTED 📋

| Item | Description |
|------|------------|
| **Pi 3 hardware provisioning** | rpi3-dns config is complete but no physical Pi 3 deployed |
| **Dozzle log viewer** | Planned at `logs.home.lan` — not started |
| **SigNoz channel routing** | Per-threshold alert routing (e.g., critical → Discord, warning → log) |
| **dns-failover secret migration** | VRRP `authPassword` still plaintext in rpi3 config |
| **Cross-platform preferences** | nix-colors full integration across all apps |
| **Voice agents verification** | `voice-agents.nix` enabled but untested (LiveKit + Whisper) |
| **Benchmark scripts** | `benchmark-system.sh`, `performance-monitor.sh` referenced in FEATURES.md but don't exist |
| **storage-cleanup.sh** | Referenced in FEATURES.md but doesn't exist |
| **shell-context-detector.sh** | Referenced in FEATURES.md but doesn't exist |
| **OpenZFS on macOS** | Explicitly banned (ADR-003) — will never start |

---

## D) TOTALLY FUCKED UP 💥

### 1. GPU DRM Zombie State (RECURRING)

**Severity:** CRITICAL — caused involuntary reboots today
**File:** `scripts/gpu-recovery.sh`
**Problem:** amdgpu driver enters `Error::DeviceMissing` state. GPU recovery script's single-shot rebind failed twice, forcing reboots.
**Fix:** Committed (retry logic with 3 attempts + 5s delay), but NOT YET DEPLOYED.
**Impact:** Desktop frozen, all GUI apps killed, 3+ reboots today.

### 2. ClickHouse Log Directory Missing (ACTIVE)

**Severity:** HIGH — SigNoz observability pipeline down
**File:** `modules/nixos/services/signoz.nix`
**Problem:** `/var/log/clickhouse-server` not created by nixpkgs module. Hardened service requires it in `ReadWritePaths` → service fails with NAMESPACE error.
**Fix:** Committed (added `systemd.tmpfiles.rules`), but NOT YET DEPLOYED.
**Impact:** No metrics/traces/logs ingestion. All monitoring blind.

### 3. Gatus Environment File Missing (ACTIVE)

**Severity:** MEDIUM — health check dashboard down
**Problem:** `gatus-env` sops template not regenerated after last boot (needs sops-nix activation on fresh boot).
**Fix:** Will auto-resolve on next `just switch` + reboot.
**Impact:** No external health monitoring. Discord alerts not firing.

### 4. Niri DeviceMissing Spam (CHRONIC)

**Severity:** LOW (non-functional but noisy)
**Problem:** ~410K `Error::DeviceMissing` warnings per boot in niri journal. Triggers DRM healthcheck false positives.
**Fix:** None yet — needs investigation into whether these are benign DRM import errors or real issues.
**Impact:** Floods journal, triggers unnecessary GPU recovery attempts.

### 5. Hardcoded User Paths in Modules (TECH DEBT)

**Severity:** MEDIUM — limits portability
**Files:** `hermes.nix`, `comfyui.nix`, `authelia.nix`, `homepage.nix`
**Problem:** 7+ instances of hardcoded `lars`, `/home/lars`, `user:lars` in service modules.
**Fix:** None started. Should use `config.users.primaryUser` or module options.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Architecture & Code Quality

1. **Extract hardcoded user paths** — Replace `lars`/`/home/lars` with `primaryUser`/`config.users.users.${primaryUser}.home` in hermes.nix, comfyui.nix, authelia.nix, homepage.nix
2. **Remove dead code** — `mkGraphicalUserService` in lib/ is never used
3. **Remove unused overlays** — `hierarchicalErrorsOverlay` and `art-dupl` overlays are exported but never consumed by any config
4. **Fix niri-health-metrics permissions** — textfile collector dir ownership issue
5. **Move VRRP authPassword to sops** — plaintext in rpi3/default.nix
6. **Migrate hardcoded SSH key** — rpi3 should use `nix-ssh-config` input like evo-x2

### Reliability & Resilience

7. **Investigate DeviceMissing root cause** — 410K errors/boot is abnormal. May be a niri bug with early import or a driver issue.
8. **Add clickhouse readiness check** — SigNoz collector should wait for ClickHouse, not spam retries
9. **Rate-limit GPU recovery** — Current healthcheck triggers recovery after 3 consecutive checks (3 min). Consider requiring 5+ or adding a cooldown.
10. **Fix monitor365** — Either fix the RAM issue and re-enable, or remove the module
11. **Fix photomap** — Podman permission issue blocking a shipped module

### Documentation & Process

12. **Create TODO_LIST.md** — Doesn't exist. Should be generated from codebase audit.
13. **Create FEATURES.md update** — Current FEATURES.md references 4 scripts that don't exist
14. **Add ADR-007** — GPU recovery retry strategy
15. **Clean up status reports** — 18 status files in docs/status/ (should archive old ones)

### Performance & Storage

16. **Disk cleanup** — Both `/` and `/data` at 80%. Need `just clean` or manual cleanup.
17. **Nix store optimization** — `nix-store --optimise` or `nix-collect-garbage -d`

---

## F) Top 25 Things We Should Get Done Next

### Priority 1 — Immediate (System Health)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 1 | **`just switch` + reboot** to deploy clickhouse tmpfiles fix + GPU recovery retries | 10 min | 🔴 CRITICAL — restores SigNoz, Gatus, all monitoring |
| 2 | **Verify all services start clean** after reboot (`systemctl --failed`) | 5 min | 🔴 Validates fix |
| 3 | **Investigate DeviceMissing spam** — determine if 410K errors/boot are benign or driver bug | 30 min | 🟡 Reduces false positive GPU recoveries |
| 4 | **Fix niri-health-metrics permissions** — textfile dir ownership | 10 min | 🟡 Restores compositor metrics |

### Priority 2 — Short Term (This Week)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 5 | **Extract hardcoded user paths** in hermes, comfyui, authelia, homepage modules | 1 hr | 🟡 Portability, maintainability |
| 6 | **Remove dead `mkGraphicalUserService`** from lib/ | 5 min | 🟢 Code hygiene |
| 7 | **Remove unused overlays** (hierarchicalErrors, art-dupl) or add to packages | 15 min | 🟢 Build time reduction |
| 8 | **Fix or remove monitor365** — disabled module is dead code | 30 min | 🟢 Code hygiene |
| 9 | **Fix or remove photomap** — disabled with podman bug | 1 hr | 🟡 Shipped module should work |
| 10 | **Move VRRP authPassword to sops** in rpi3 config | 15 min | 🟡 Security |
| 11 | **Disk cleanup** — `just clean` + manual review of large files | 30 min | 🟡 Both disks at 80% |
| 12 | **Create TODO_LIST.md** from this audit | 30 min | 🟢 Process |

### Priority 3 — Medium Term (Next 2 Weeks)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 13 | **Provision Pi 3 hardware** for DNS failover cluster | 2 hr | 🟡 HA DNS |
| 14 | **Deploy Dozzle** at `logs.home.lan` for container log viewing | 1 hr | 🟢 Observability |
| 15 | **Add SigNoz channel routing** — per-threshold Discord alerts | 1 hr | 🟢 Alert quality |
| 16 | **Migrate hardcoded colors to nix-colors** — 17+ instances | 2 hr | 🟢 Theme consistency |
| 17 | **Verify voice-agents** — LiveKit + Whisper integration test | 1 hr | 🟡 Shipped but untested |
| 18 | **Update FEATURES.md** — remove references to non-existent scripts | 30 min | 🟢 Documentation accuracy |

### Priority 4 — Long Term (Nice to Have)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 19 | **Archive old status reports** — move 15+ old files to archive/ | 15 min | 🟢 Clean docs |
| 20 | **Write ADR-007** — GPU recovery retry strategy | 15 min | 🟢 Documentation |
| 21 | **rpi3 SSH key migration** — use nix-ssh-config input | 15 min | 🟢 Consistency |
| 22 | **Add clickhouse readiness probe** for SigNoz collector | 30 min | 🟢 Faster recovery |
| 23 | **Rate-limit GPU recovery** — increase consecutive check threshold | 15 min | 🟢 Fewer false positives |
| 24 | **Create benchmark/performance scripts** referenced in FEATURES.md | 2 hr | 🟢 Feature completeness |
| 25 | **Investigate watchdogd nixpkgs bugs** — file upstream issues | 1 hr | 🟢 Community contribution |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Why does amdgpu produce ~410K `Error::DeviceMissing` DRM errors per boot?**

The niri compositor logs `error doing early import: Error::DeviceMissing` at a rate of ~2 per second continuously. This happens even when the desktop is working perfectly. The DRM healthcheck counts these as "errors" and can trigger GPU recovery unnecessarily.

I cannot determine:
- Is this a **niri bug** (trying to import DRM buffers that don't exist yet on startup)?
- Is this an **amdgpu driver issue** specific to the Ryzen AI Max+ 395 (Strix Halo)?
- Is this **expected behavior** that the healthcheck should ignore?
- Does the **upstream niri issue tracker** have a matching bug report?

The answer determines whether we need to: (a) filter these specific errors from the healthcheck, (b) file a niri bug, (c) file a kernel/driver bug, or (d) adjust the amdgpu module parameters.

---

## Incident Timeline (Today)

| Time | Event |
|------|-------|
| 11:00–11:49 | Multiple `just switch` attempts — sops/gatus env files broken during iterations |
| 11:44 | Gatus enters crash loop (env file missing), nix-daemon activity spikes |
| 21:59 | ClickHouse starts failing (`/var/log/clickhouse-server` missing) |
| 22:25 | GPU DRM `Error::DeviceMissing` flood begins (20+ errors per 30s) |
| 22:26:25 | `niri-drm-healthcheck` confirms zombie state (3/3 checks failed) |
| 22:26:50 | **gpu-recovery.service FAILED** — single-shot amdgpu rebind unsuccessful |
| 22:29:47 | Second round of DRM zombie detection, recovery fails again |
| 22:30:39 | `switch-to-configuration boot` running — triggered reboot |
| 22:31:21 | Boot -2 ends, boot -1 begins |
| 22:32:49 | Niri starts cleanly on fresh boot |
| 22:40:34 | User-initiated reboot (services still broken from sops cascade) |
| 22:41:13 | Current boot begins (boot 0) — system running |
| 23:33 | Session 78: Diagnosed crash chain, both fixes already committed |

---

## Codebase Statistics

| Metric | Value |
|--------|-------|
| Service modules | 39 files in `modules/nixos/services/` |
| Platform modules | 4 hardware, 6 programs, 2 desktop |
| Common programs | 14 cross-platform configs |
| Scripts | 16 operational scripts |
| Overlays | 12 shared + 6 Linux-only |
| ADRs | 6 architecture decisions |
| Status reports | 18 (including this one) |
| Lib helpers | 6 (harden, hardenUser, serviceDefaults, serviceDefaultsUser, serviceTypes, rocm) + 1 unused (mkGraphicalUserService) |
| Enabled services | 30+ in configuration.nix |
| Total flake inputs | 30+ |

---

_Report generated by Crush AI (session 78)_
