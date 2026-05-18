# Session 41 — Full Comprehensive Status Report

**Date:** 2026-05-18 20:51 CEST
**Session Focus:** Full ecosystem audit — code quality, security, infrastructure, services, scripts, and strategic roadmap
**Commits Since Last Report:** 3 (networking trust LAN, session 40 status updates, flake.lock)

---

## Executive Summary

SystemNix is in **strong overall health**. All 111 `.nix` files evaluate cleanly (`nix flake check --no-build` passes). 29 out of 33 service modules are enabled on evo-x2. 28 enabled services use `harden {}` from shared lib. Zero TODOs, zero debug traces, zero assertions in the codebase. The system is production-stable with active monitoring (Gatus 26+ endpoints, SigNoz observability, GPU self-healing).

**Key risks:** 2 services have secrets in plaintext Nix options (monitor365), 1 service has zero hardening (unsloth-studio), 6 scripts have error handling gaps, and the DNS stack is a single point of failure (Pi 3 unprovisioned).

---

## a) FULLY DONE ✅

### Infrastructure & Core
- **Cross-platform Nix flake** — 3 systems: macOS (aarch64-darwin), NixOS desktop (x86_64-linux), Raspberry Pi 3 (aarch64-linux, planned)
- **flake-parts modular architecture** — 33 service modules registered via `serviceModules` single source of truth
- **35+ flake inputs** — all LarsArtmann repos use SSH URLs, no `path:` inputs remain
- **Home Manager** — 14 shared program modules cross-platform (fish, zsh, bash, git, tmux, fzf, starship, taskwarrior, etc.)
- **`lib/` shared helpers** — 10 exports: `harden`, `hardenUser`, `serviceDefaults`, `serviceDefaultsUser`, `onFailure`, `serviceTypes`, `mkDockerServiceFactory`, `mkStateDir`, `mkPreparedSource`, `mkHttpCheck`
- **13-field systemd hardening** — `harden {}` from `lib/systemd.nix` used by 28/29 enabled services
- **Overlay architecture** — 15 shared overlays + 6 Linux-only, all using `mkPackageOverlay` pattern
- **`_local_deps` pattern** — 5 private Go repos with prepared source + vendor hash management
- **Catppuccin Mocha theme** — universal across all apps, terminals, bars, login screen

### Secrets & Security
- **sops-nix** — age-encrypted secrets using SSH host key, central `modules/nixos/services/sops.nix`
- **Authelia SSO** — forward auth protecting all web services behind Caddy
- **DNS-over-TLS** — Quad9 upstream via Unbound, 2.5M+ domains blocked
- **Security hardening module** — kernel params, sysctl, USBGuard, OOM protection
- **Gitleaks pre-commit** — secret detection on every commit

### Networking & Connectivity
- **Caddy reverse proxy** — 10+ virtual hosts, TLS via sops-managed certs, forward auth
- **DNS blocking stack** — Unbound + dnsblockd, 25 blocklists, `.home.lan` local records
- **Dual-WAN ECMP+MPTCP** — active-active failover with route health monitoring
- **Firewall** — LAN-trusted via `trustedInterfaces`, explicit port rules for non-LAN
- **Static IP** — `192.168.1.150` on eno1, gateway, subnet all derived from `local-network.nix`

### Observability
- **SigNoz** — full observability (traces, metrics, logs) via OTel Collector + ClickHouse
- **Gatus** — 26+ endpoint health checks, Discord alerting, SQLite storage
- **node_exporter + cAdvisor** — system + container metrics
- **GPU metrics** — VRAM/busy/temp via textfile collector
- **Niri health metrics** — compositor running/restarts/DRM errors

### AI/ML Stack
- **Ollama** — ROCm GPU acceleration, model management, `OLLAMA_MAX_LOADED_MODELS=1` defense
- **AI model storage** — centralized `/data/ai/` with 18 subdirectories, all services reference it
- **gpu-python wrapper** — controlled GPU memory allocation for ad-hoc scripts
- **ComfyUI** — module exists, currently disabled (prefer code-based AI directly)
- **Voice agents** — LiveKit + Whisper ASR module (enabled, ROCm pipeline)

### Desktop (NixOS)
- **Niri Wayland compositor** — wrapped config, 80+ keybindings, OOM-protected
- **Niri session manager** — automatic window save/restore across reboots
- **GPU self-healing** — DRM healthcheck every 60s, GPU recovery with auto-reboot
- **Wallpaper self-healing** — awww daemon + PartOf restart propagation
- **EMEET PIXY webcam** — Go daemon, auto face tracking, call detection, Waybar integration
- **Waybar** — Catppuccin themed, custom modules for camera, network, GPU
- **SDDM** — silent-sddm theme, Catppuccin styling

### Services (Production)
- **Immich** — photo/video management, daily DB backup, OAuth via Authelia
- **Gitea** — self-hosted Git + GitHub mirror sync
- **Homepage** — service dashboard, Catppuccin themed
- **Hermes** — AI agent gateway (Discord bot), 6 sops secrets, SQLite auto-recovery
- **Twenty CRM** — Docker-based, sops secrets
- **OpenSEO** — SEO suite, DataForSEO API integration
- **Manifest** — smart LLM router
- **Monitor365** — device monitoring agent
- **Minecraft** — module exists, currently disabled
- **TaskChampion** — cross-platform task sync, zero-config client setup

### Quality Tooling
- **Pre-commit hooks** — gitleaks, deadnix, statix, alejandra, flake check
- **Justfile** — 90+ recipes in 10 groups
- **Scripts** — 17 scripts (deploy, diagnostics, health checks, GPU recovery)
- **Zero TODOs** — no TODO/FIXME/HACK/XXX in any `.nix` file

---

## b) PARTIALLY DONE 🔄

| Area | What's Done | What's Missing | Priority |
|------|-------------|----------------|----------|
| **SSH config migration** | Uses `nix-ssh-config` flake input | Still uses deprecated `matchBlocks`/`extraOptions` — 4 HM warnings on every build | Medium |
| **Darwin build verification** | Evaluates cleanly | Full `nix build` not verified from MacBook in recent sessions | Low |
| **photomap module** | Complete module exists | Disabled due to podman permission issue — dead code | Low (decide: fix or remove) |
| **Voice agents** | Module enabled, LiveKit configured | Whisper ROCm pipeline unverified at runtime | Medium |
| **Voice agents docker pattern** | Uses `mkDockerService` | Imports `docker.nix` directly instead of factory pattern | Low |
| **`lib/rocm.nix`** | Working, imported by 2 modules | Not exported from `lib/default.nix` — breaks the pattern | Low |
| **DNS failover cluster** | Module complete, VRRP configured | Pi 3 hardware not provisioned — DNS is SPOF | High |
| **SigNoz alert routing** | 26+ endpoints monitored, Discord alerts | No per-threshold routing (critical vs warning channels) | Low |
| **Disk monitoring** | Module enabled, alerts configured | `/data` at 81%, root at 86% — proactive cleanup needed | Medium |
| **Status report hygiene** | 57+ reports in `docs/status/` | No archive policy, no cleanup, many old/stale reports | Low |
| **Home Manager SSH** | Works functionally | 4 deprecation warnings on every `just switch` | Medium |
| **Hardcoded ports** | Most services derive from config options | 7 hardcoded ports remain (Ollama 11434, LiveKit 7880, Node Exporter 9100, Immich 2283, etc.) | Low |

---

## c) NOT STARTED ❌

| Area | Description | Effort | Impact |
|------|-------------|--------|--------|
| **Cachix binary cache** | No binary cache — every build rebuilds from source | 2 hrs | High (saves 30+ min per rebuild) |
| **GitHub Actions CI** | No CI pipeline for `nix flake check` on push | 1 hr | High (catches eval errors before deploy) |
| **AppArmor enablement** | Mentioned in known gaps, never started | 4 hrs | Medium |
| **Auditd re-enablement** | Blocked by nixpkgs #483085 | Blocked | Medium |
| **Automated vendor hash updater** | Manual process for 5 Go repos | 3 hrs | Medium |
| **Dependency graph visualization** | No visual map of flake input relationships | 2 hrs | Low |
| **nix-colors Home Manager migration** | 17+ hardcoded colors could use `nix-colors` scheme | 3 hrs | Low |
| **Dozzle deployment** | Container log tailing (mentioned in TODO_LIST) | 1 hr | Low |
| **Distributed Darwin builds** | MacBook builds could offload to evo-x2 | 4 hrs | Medium |
| **mk-pnpm-package.nix helper** | Extract pnpm package pattern for reuse | 1 hr | Low |
| **Lock file for scripts** | `gpu-recovery.sh` and `route-health-monitor.sh` have no concurrency protection | 1 hr | Medium |
| **Signal handling in daemons** | `route-health-monitor.sh` lacks SIGTERM trap | 30 min | Low |

---

## d) TOTALLY FUCKED UP 🔥

### Critical Security Issues

| Issue | File | Severity | Details |
|-------|------|----------|---------|
| **monitor365 secrets in Nix store** | `modules/nixos/services/monitor365.nix` | 🔴 HIGH | `authToken` and `jwtSecret` are plaintext Nix options → world-readable in `/nix/store`. Must migrate to sops. |
| **unsloth-studio zero hardening** | `modules/nixos/services/ai-stack.nix` | 🔴 HIGH | Service runs with no `harden {}`, no `serviceDefaults {}`, no `MemoryMax`, no `PrivateTmp` — completely uncontained. |
| **Authelia OIDC client secret hardcoded** | `modules/nixos/services/authelia.nix:22` | 🟡 MEDIUM | Client secret is a hardcoded bcrypt hash in the module, not sops-managed. Not rotatable without code change. |
| **Gitea admin password in plaintext file** | `modules/nixos/services/gitea.nix:351-352` | 🟡 MEDIUM | Auto-generated admin password written to `/var/lib/gitea/.admin-password`. Token generation fails silently. |
| **Twenty secrets outside sops module** | `modules/nixos/services/twenty.nix:120-135` | 🟡 MEDIUM | Secrets defined locally in the module instead of central `sops.nix` — breaks single-source-of-truth pattern. Uses `:latest` Docker tag. |

### System Health Concerns

| Issue | Severity | Details |
|-------|----------|---------|
| **DNS single point of failure** | 🔴 HIGH | Pi 3 unprovisioned — if evo-x2 dies, all LAN devices lose DNS. All `.home.lan` services unreachable. |
| **Root disk 86% full** | 🟡 MEDIUM | 73G free. Needs `just clean` or proactive cleanup. |
| **`/data` disk 81% full** | 🟡 MEDIUM | AI models, Docker volumes, Immich photos. Growing. |
| **10 security overrides** | 🟡 MEDIUM | `lib.mkForce false` on `NoNewPrivileges`, `ProtectHome`, `ProtectSystem` across 5 modules — each needs review for necessity. |

### Script Robustness Issues

| Script | Issue | Severity |
|--------|-------|----------|
| `route-health-monitor.sh` | State machine can drift from actual routes (mode advances even if `set_route_*` fails) | 🟡 |
| `gpu-recovery.sh` | `systemctl --user` called from root context without `$SUDO_USER` | 🟡 |
| `gpu-recovery.sh` | Hardcoded `DRM_CARD="/sys/class/drm/card1"` — breaks on multi-GPU | 🟡 |
| `wallpaper-set.sh` | No `command -v awww` check — errors every second for 60s if missing | 🟡 |
| `validate.sh` | No `cd` to project root — depends on invocation directory | 🟢 |
| `health-check.sh` | Suppresses all `nix flake check` output on failure | 🟢 |
| `route-health-monitor.sh` | No PID file or flock — dual instances fight over route table | 🟡 |
| `route-health-monitor.sh` | No SIGTERM handler for clean systemd stop | 🟢 |

---

## e) WHAT WE SHOULD IMPROVE 💡

### Architecture

1. **Secret centralization** — All secrets should flow through `sops.nix`. monitor365 and twenty break this pattern. Create a linter rule that flags `string` types near `secret`/`token`/`password`/`key` in module options.
2. **Docker image pinning** — Twenty uses `:latest` tag. All Docker images should pin to a specific SHA or version tag. Create a `just hash-check` variant for Docker image staleness.
3. **Port derivation completeness** — 7 hardcoded ports remain. Every service should expose a `port` option that Caddy references.
4. **Factory pattern consistency** — `voice-agents.nix` bypasses `mkDockerServiceFactory`. All Docker services should use the factory.
5. **`lib/rocm.nix` export** — Should be re-exported from `lib/default.nix` for consistency with other lib modules.

### Security

6. **monitor365 sops migration** — Move `authToken`/`jwtSecret` from Nix options to sops secrets. These are in the Nix store world-readable.
7. **unsloth hardening** — Add `harden {}` + `serviceDefaults {}` to the unsloth-studio service. It's a Python GPU process with zero containment.
8. **Security override audit** — Review all 10 `mkForce false` overrides. Document WHY each is necessary with inline comments. Remove any that are stale.
9. **Gitea admin password** — Migrate to sops or at minimum restrict file permissions beyond what systemd hardening provides.

### Operations

10. **Disk space policy** — Set up automated cleanup: `nix.gc` is configured but `/data` growth (Docker, Immich, AI models) has no guardrails. Add a `disk-threshold` alert in Gatus for `/data > 90%`.
11. **CI pipeline** — `nix flake check --no-build` on every push would catch eval errors before they reach evo-x2. GitHub Actions with Nix installer.
12. **Cachix** — Binary cache would cut rebuild times from 30+ min to <5 min. Critical for developer experience.
13. **Status report cleanup** — 57+ reports with no archive policy. Auto-archive anything older than 30 days.

### Code Quality

14. **Script concurrency** — Add `flock` to `gpu-recovery.sh` and `route-health-monitor.sh` to prevent dual execution.
15. **Script signal handling** — Add SIGTERM traps to long-running daemon scripts.
16. **route-health-monitor state integrity** — Only advance state machine if route operations succeed.
17. **gpu-recovery user context** — Use `$SUDO_USER` for `systemctl --user` calls when run as root.

---

## f) Top #25 Things to Get Done Next

| # | Task | Effort | Impact | Category |
|---|------|--------|--------|----------|
| 1 | **Migrate monitor365 secrets to sops** | 1 hr | 🔴 Critical | Security |
| 2 | **Add hardening to unsloth-studio** | 30 min | 🔴 Critical | Security |
| 3 | **Provision Pi 3 for DNS failover** | 3 hrs | 🔴 Critical | Infrastructure |
| 4 | **Run `just clean` — disk at 86%** | 10 min | 🟡 High | Operations |
| 5 | **Migrate SSH config to `programs.ssh.settings`** | 15 min | 🟡 High | Quality |
| 6 | **Set up GitHub Actions CI for `nix flake check`** | 1 hr | 🟡 High | Operations |
| 7 | **Set up Cachix binary cache** | 2 hrs | 🟡 High | Operations |
| 8 | **Pin Twenty Docker image to specific version** | 15 min | 🟡 High | Security |
| 9 | **Move twenty secrets to central sops.nix** | 30 min | 🟡 High | Architecture |
| 10 | **Fix route-health-monitor state drift** | 1 hr | 🟡 High | Reliability |
| 11 | **Add flock to gpu-recovery + route-health-monitor** | 1 hr | 🟡 Medium | Reliability |
| 12 | **Fix gpu-recovery DRM_CARD auto-detection** | 30 min | 🟡 Medium | Reliability |
| 13 | **Fix gpu-recovery root/user context** | 30 min | 🟡 Medium | Reliability |
| 14 | **Archive old status reports (>30 days)** | 10 min | 🟢 Low | Housekeeping |
| 15 | **Add `/data > 90%` disk threshold to Gatus** | 30 min | 🟡 Medium | Monitoring |
| 16 | **Derive 7 remaining hardcoded ports to options** | 1 hr | 🟢 Low | Architecture |
| 17 | **Fix voice-agents to use mkDockerServiceFactory** | 30 min | 🟢 Low | Architecture |
| 18 | **Export rocm.nix from lib/default.nix** | 5 min | 🟢 Low | Consistency |
| 19 | **Add SIGTERM trap to route-health-monitor** | 15 min | 🟢 Low | Reliability |
| 20 | **Verify Whisper ROCm pipeline at runtime** | 1 hr | 🟡 Medium | AI Stack |
| 21 | **Decide on photomap: fix, enable, or remove** | 10 min | 🟢 Low | Cleanup |
| 22 | **Verify Darwin build from MacBook** | 30 min | 🟢 Low | Cross-platform |
| 23 | **Create `just stale-images` recipe for Docker tags** | 30 min | 🟢 Low | Operations |
| 24 | **Document all `mkForce false` security overrides** | 1 hr | 🟡 Medium | Documentation |
| 25 | **Add `command -v` guards to wallpaper-set.sh** | 15 min | 🟢 Low | Reliability |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Is the monitor365 `authToken` / `jwtSecret` in actual active use?**

The module has extensive options (`services.monitor365.cloud.authToken`, `services.monitor365.server.jwtSecret`) defined as plaintext `types.str`. If these are currently set to real values in `configuration.nix`, they're sitting in the world-readable Nix store. But if the module is enabled with default/empty values and monitor365 is just running locally (no cloud connection), the risk is lower.

**Why I can't determine this:** I can read the module code but not the actual deployed configuration values (which may be in a separate config or set differently on the live system). The severity of the sops migration depends on whether real secrets are being passed.

**Recommended action:** Check `services.monitor365` settings in the live configuration. If real tokens are set, this is a 🔴 P0 fix. If empty/default, it can wait but should still be migrated as defense-in-depth.

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total `.nix` files | 111 |
| Service modules | 33 |
| Enabled services | 29 |
| Disabled services | 4 (photomap, comfyui, minecraft, one other) |
| Docker-based services | 5 (twenty, manifest, openseo, voice-agents, one other) |
| Services using `harden {}` | 28/29 |
| Services using sops secrets | 22/29 |
| Hardcoded ports remaining | 7 |
| Security overrides (`mkForce false`) | 10 |
| TODO/FIXME/HACK/XXX | 0 |
| Flake inputs | 35+ |
| Custom overlays | 21 (15 shared + 6 Linux) |
| Justfile recipes | 90+ |
| Scripts | 17 |
| Gatus monitored endpoints | 26+ |
| ADRs | 7 |
| Status reports | 57+ (needs cleanup) |
| `nix flake check --no-build` | ✅ PASS |
| Known issues tracked | 14 |

---

## Commit History (Last 5)

| Hash | Message |
|------|---------|
| `11dbb83` | feat(networking): trust all LAN traffic on eno1 via firewall trustedInterfaces |
| `1277573` | docs(status): Session 40 — full comprehensive status update |
| `961629e` | docs(status): session 40 — systemd dependency fixes, comprehensive status report |
| `974b507` | fix(services): add unbound.service and sops-nix.service dependencies |
| `5aefb10` | feat(packages): install netwatch in linuxUtilities |

---

_Generated by Crush — Session 41_
