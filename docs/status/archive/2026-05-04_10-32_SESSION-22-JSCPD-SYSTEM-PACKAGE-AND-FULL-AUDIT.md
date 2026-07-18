# SystemNix — Comprehensive Status Report

**Date:** 2026-05-04 10:32 CEST
**Session:** 22
**Scope:** Full system audit — all services, packages, modules, config, and infrastructure

---

## Executive Summary

SystemNix is a **mature, production-stable** cross-platform Nix configuration managing two machines (macOS `Lars-MacBook-Air` + NixOS `evo-x2`) through a single flake with **102 .nix files, 13,153 lines of Nix code**, and **31 flake inputs**. The system has **30 service modules** (via flake-parts), **104 system packages**, ~100 justfile recipes, and **5 Architecture Decision Records**.

**Overall Health: 🟢 STABLE & PRODUCTION-READY**

The last 30 commits focused on: systemd watchdog fixes, overlay consolidation, shared lib extraction, DNS privacy overhaul, niri session save/restore, and Go overlay cleanup. The codebase is clean — zero TODOs, FIXMEs, HACKs, or XXXs in .nix files.

**This session's change:** Moved `jscpd` from devShell-only to system package (sharedOverlays + base.nix).

---

## a) FULLY DONE ✅

### Core Infrastructure

| Component                        | Status      | Details                                                                                         |
| -------------------------------- | ----------- | ----------------------------------------------------------------------------------------------- |
| Flake architecture (flake-parts) | ✅ Complete | 31 inputs, 734-line flake.nix, 30 nixosModules                                                  |
| Cross-platform Home Manager      | ✅ Complete | ~80% shared via `platforms/common/`, 14 program modules                                         |
| Shared overlays system           | ✅ Complete | `sharedOverlays` (6 overlays) + `linuxOnlyOverlays` (6 overlays)                                |
| Secrets (sops-nix)               | ✅ Complete | age-encrypted, SSH host key as master, all secrets accounted for                                |
| Justfile task runner             | ✅ Complete | ~100 recipes covering all operations                                                            |
| Formatter (treefmt + alejandra)  | ✅ Complete | `just format`, pre-commit integration                                                           |
| Lib helpers                      | ✅ Complete | `lib/systemd.nix` (harden), `lib/systemd/service-defaults.nix`, `lib/types.nix`, `lib/rocm.nix` |
| Health check system              | ✅ Complete | `just health` — cross-platform diagnostics                                                      |
| ADR documentation                | ✅ Complete | 5 ADRs in `docs/architecture/`                                                                  |
| FEATURES.md                      | ✅ Complete | 493-line comprehensive feature inventory (2026-05-03)                                           |

### NixOS Services (Production)

| Service            | Module                   | Status       | Notes                                                             |
| ------------------ | ------------------------ | ------------ | ----------------------------------------------------------------- |
| Docker             | `default.nix`            | ✅ Running   | Always-on when module imported, prune timer                       |
| Caddy              | `caddy.nix`              | ✅ Running   | Reverse proxy, TLS via sops, WatchdogSec (sd_notify capable)      |
| Gitea              | `gitea.nix`              | ✅ Running   | Git hosting + GitHub mirror, WatchdogSec                          |
| Homepage           | `homepage.nix`           | ✅ Running   | Service dashboard                                                 |
| Immich             | `immich.nix`             | ✅ Running   | Photo/video management                                            |
| TaskChampion       | `taskchampion.nix`       | ✅ Running   | Taskwarrior sync server, deterministic client IDs                 |
| SigNoz             | `signoz.nix`             | ✅ Running   | Full observability stack (741 lines — largest module)             |
| Hermes             | `hermes.nix`             | ✅ Running   | AI agent gateway (Discord, cron), render group for GPU            |
| Authelia           | `authelia.nix`           | ✅ Running   | SSO/OIDC provider                                                 |
| SOPS config        | `sops.nix`               | ✅ Running   | Secrets decryption, template merging                              |
| AI Models          | `ai-models.nix`          | ✅ Running   | Centralized /data/ai/ storage structure                           |
| AI Stack           | `ai-stack.nix`           | ✅ Running   | Ollama, Whisper, Unsloth Studio                                   |
| Voice Agents       | `voice-agents.nix`       | ✅ Running   | LiveKit, OpenWakeWord                                             |
| ComfyUI            | `comfyui.nix`            | ✅ Running   | Image generation pipeline                                         |
| Security Hardening | `security-hardening.nix` | ✅ Active    | Kernel hardening, sysctl, umask, auditd (disabled — upstream bug) |
| Monitoring Tools   | `monitoring.nix`         | ✅ Running   | node_exporter, cAdvisor                                           |
| Audio              | `audio.nix`              | ✅ Running   | PipeWire, WirePlumber, noise suppression                          |
| Niri Desktop       | `niri-config.nix`        | ✅ Running   | Wayland compositor, session save/restore                          |
| Display Manager    | `display-manager.nix`    | ✅ Running   | SDDM + silent-sddm theme                                          |
| Chromium Policies  | `chromium-policies.nix`  | ✅ Active    | Enterprise policies for browser                                   |
| Steam              | `steam.nix`              | ✅ Active    | Gaming platform                                                   |
| Disk Monitor       | `disk-monitor.nix`       | ✅ Running   | BTRFS/disk monitoring                                             |
| SSH Server         | (via nix-ssh-config)     | ✅ Running   | External flake input                                              |
| Fail2Ban           | (configuration.nix)      | ✅ Running   | Intrusion prevention                                              |
| Smartd             | (configuration.nix)      | ✅ Running   | Disk health monitoring                                            |
| Multi-WM           | `multi-wm.nix`           | ✅ Available | Multi-window-manager support                                      |
| Scheduled Tasks    | `scheduled-tasks.nix`    | ✅ Running   | Automated backup, flake update, dns blocklist refresh             |
| DNS Blocker        | `dns-blocker-config.nix` | ✅ Running   | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains                 |

### Cross-Platform Programs

| Category                                     | Count | Status                               |
| -------------------------------------------- | ----- | ------------------------------------ |
| Shell (fish, zsh, bash)                      | 3     | ✅ All configured                    |
| Editor (micro, neovim)                       | 2     | ✅ All configured                    |
| Terminal tools (ripgrep, fd, eza, bat, etc.) | 40+   | ✅ All configured                    |
| Development (Go, Node.js, Terraform, Docker) | 30+   | ✅ All configured                    |
| Taskwarrior                                  | 1     | ✅ Synced across platforms + Android |

### Desktop (NixOS)

| Component                     | Status                                       |
| ----------------------------- | -------------------------------------------- |
| Niri (Wayland compositor)     | ✅ Wrapped with config, session save/restore |
| Waybar                        | ✅ Full config (410 lines)                   |
| Rofi                          | ✅ Configured                                |
| Swaylock / wlogout            | ✅ Configured                                |
| Yazi (file manager)           | ✅ Full config (441 lines)                   |
| Zellij (terminal multiplexer) | ✅ Full config (239 lines)                   |
| EMEET PIXY webcam             | ✅ Daemon running, Waybar integration        |
| Catppuccin Mocha theme        | ✅ Universal across all apps                 |

### Custom Packages (10 total)

| Package                | Language | Status                                               |
| ---------------------- | -------- | ---------------------------------------------------- |
| jscpd                  | Node.js  | ✅ System package (moved from devShell this session) |
| aw-watcher-utilization | Python   | ✅ Shared overlay                                    |
| dnsblockd              | Go       | ✅ Linux overlay                                     |
| dnsblockd-processor    | Go       | ✅ Linux overlay                                     |
| modernize              | Go       | ✅ perSystem package                                 |
| monitor365             | Rust     | ✅ Linux overlay (service disabled)                  |
| netwatch               | Rust     | ✅ Linux overlay                                     |
| openaudible            | AppImage | ✅ Linux overlay                                     |
| emeet-pixyd            | Go       | ✅ External flake input                              |
| file-and-image-renamer | Go       | ✅ Linux overlay                                     |

---

## b) PARTIALLY DONE ⚠️

| Component               | Status                    | What's Missing                                                                                     |
| ----------------------- | ------------------------- | -------------------------------------------------------------------------------------------------- |
| DNS Failover Cluster    | ⚠️ Module exists          | RPi3 hardware not provisioned; VRRP untested in production                                         |
| PhotoMap                | ⚠️ Module exists          | Service disabled in configuration.nix (`services.photomap.enable` not set)                         |
| Twenty CRM              | ⚠️ Module exists          | Service disabled in configuration.nix (`services.twenty.enable` present but likely not functional) |
| Monitor365              | ⚠️ Module + overlay exist | Service explicitly `enable = false` in configuration.nix                                           |
| Gitea GitHub Sync       | ⚠️ Module exists          | Auth mechanism may be broken (token-based, documented in earlier sessions)                         |
| Minecraft               | ⚠️ Module exists          | Server + client modules present, may need runtime verification                                     |
| SigNoz                  | ⚠️ Running                | Built from source (Go 1.25) — significant build time, no version pinning                           |
| Authelia                | ⚠️ Running                | Hardcoded bcrypt client secret in module source (line 20) instead of sops                          |
| Default services module | ⚠️ No enable gate         | Docker always applied when module imported, hardcodes user `lars`                                  |
| SSH config              | ⚠️ External               | 6 hardcoded IPs in ssh-config.nix — not configurable via options                                   |

---

## c) NOT STARTED 📋

| Item                             | Description                                      | Priority |
| -------------------------------- | ------------------------------------------------ | -------- |
| LUKS disk encryption             | No full-disk encryption on evo-x2                | HIGH     |
| TPM2 support                     | Not enabled for measured boot                    | HIGH     |
| fwupd firmware updates           | Not configured                                   | MEDIUM   |
| RPi3 provisioning                | Hardware not acquired, SD image build exists     | MEDIUM   |
| CI/CD pipeline                   | No GitHub Actions or equivalent                  | MEDIUM   |
| jscpd in pre-commit              | Automated copy/paste detection in CI             | LOW      |
| Pre-commit nix flake check       | Automated flake validation                       | LOW      |
| TODO_LIST.md                     | No centralized TODO tracking document            | LOW      |
| CONTEXT.md                       | No domain context document                       | LOW      |
| Automated testing                | No nixos-tests or VM tests for service modules   | LOW      |
| Cross-platform sync verification | No automated test that Darwin + NixOS both build | LOW      |
| Documentation site               | No auto-generated docs from Nix modules          | LOW      |

---

## d) TOTALLY FUCKED UP 💥

**Nothing is catastrophically broken.** The system is stable and production-running. However, there are cleanliness issues:

| Issue                       | Severity | File                                                               | Details                                                                                                  |
| --------------------------- | -------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| Stale commented-out imports | Medium   | `configuration.nix:23-30`                                          | 7 comments reference dead path `platforms/nixos/services/` — services moved to `modules/nixos/services/` |
| Stale cert files            | Low      | `platforms/nixos/secrets/dnsblockd-ca.crt`, `dnsblockd-server.crt` | Raw cert files not referenced by any .nix — sops-encrypted `dnsblockd-certs.yaml` is used instead        |
| Hardcoded bcrypt secret     | Medium   | `modules/nixos/services/authelia.nix:20`                           | Client secret should be in sops, not in module source                                                    |
| Hardcoded user paths        | Low      | `comfyui.nix`, `file-and-image-renamer.nix`                        | Default paths tied to `/home/lars/projects/...`                                                          |
| Implicit module deps        | Low      | `photomap.nix` → immich, `voice-agents.nix` → ai-models            | Eval-time reads without explicit dependency declarations                                                 |
| Stale comment refs          | Low      | `security-hardening.nix:58`, `gitea.nix:15`                        | Comments point to old service paths                                                                      |

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Architecture & Code Quality

1. **Add enable gate to default.nix** — Docker module has no `enable` option; it's always-on when imported. Should follow the pattern of all other modules.

2. **Move Authelia client secret to sops** — Hardcoded bcrypt hash in module source is a security anti-pattern, even if it's "just" a hashed value.

3. **Parameterize hardcoded paths** — comfyui defaults, file-and-image-renamer postPatch, and scheduled-tasks WorkingDirectory should use module options.

4. **Add explicit module dependencies** — `photomap.nix` and `voice-agents.nix` should assert their dependencies at eval time using `lib.asserts` or `mkIf` guards.

5. **Remove stale artifacts** — Dead commented-out imports in configuration.nix, stale cert files in secrets/, stale comment paths in security-hardening.nix and gitea.nix.

6. **SSH config parameterization** — 6 hardcoded IPs in ssh-config.nix should be configurable options, especially since the network already has `networking.local.*` options.

### Infrastructure & Security

7. **LUKS disk encryption** — evo-x2 has no full-disk encryption. With 128GB RAM and sensitive services (Gitea, Authelia, secrets), this is the highest-priority gap.

8. **fwupd + firmware updates** — No firmware update mechanism configured for the AMD Ryzen AI Max+ 395 hardware.

9. **TPM2 measured boot** — Not enabled. Would pair well with LUKS for automatic decryption.

### Testing & Reliability

10. **Service module tests** — No `passthru.tests` or nixos VM tests for any of the 30 service modules.

11. **CI pipeline** — No automated `nix flake check`, format verification, or build testing on push.

12. **Build time optimization** — SigNoz built from source is the biggest build bottleneck. Consider binary cache or pre-built OCI images.

### Documentation & Organization

13. **TODO_LIST.md** — No centralized TODO tracking. Should be generated from codebase analysis.

14. **Module option documentation** — Service modules lack generated option docs (could use nmd or similar).

15. **CONCEPT/domain doc** — No CONTEXT.md explaining the "why" behind architectural decisions for new contributors.

---

## f) TOP 25 THINGS WE SHOULD GET DONE NEXT

**Sorted by impact (Pareto principle: 20% effort → 80% value)**

| #   | Task                                   | Category       | Impact   | Effort | Rationale                                         |
| --- | -------------------------------------- | -------------- | -------- | ------ | ------------------------------------------------- |
| 1   | **LUKS disk encryption**               | Security       | CRITICAL | 2h     | No encryption on production machine with secrets  |
| 2   | **Move Authelia secret to sops**       | Security       | HIGH     | 15min  | Hardcoded secret in source code                   |
| 3   | **Clean stale imports/comments**       | Cleanup        | MEDIUM   | 10min  | Dead references in configuration.nix              |
| 4   | **Remove stale cert files**            | Cleanup        | LOW      | 2min   | `dnsblockd-ca.crt`, `dnsblockd-server.crt` unused |
| 5   | **Add enable gate to default.nix**     | Architecture   | HIGH     | 15min  | Docker module should be disableable               |
| 6   | **Parameterize hardcoded user paths**  | Architecture   | MEDIUM   | 30min  | comfyui, file-and-image-renamer defaults          |
| 7   | **Add implicit dependency assertions** | Architecture   | MEDIUM   | 20min  | photomap → immich, voice-agents → ai-models       |
| 8   | **fwupd firmware updates**             | Security       | MEDIUM   | 30min  | No firmware update mechanism                      |
| 9   | **SSH config parameterization**        | Architecture   | MEDIUM   | 30min  | 6 hardcoded IPs → configurable options            |
| 10  | **Create TODO_LIST.md**                | Documentation  | MEDIUM   | 1h     | Centralized task tracking                         |
| 11  | **CI pipeline (GitHub Actions)**       | Reliability    | HIGH     | 2h     | Automated flake check + format on push            |
| 12  | **SigNoz binary cache**                | Performance    | HIGH     | 2h     | Built from source every time — huge bottleneck    |
| 13  | **Service module tests**               | Testing        | HIGH     | 3h     | No automated testing for 30 modules               |
| 14  | **Monitor365 enable + verify**         | Feature        | LOW      | 30min  | Module exists but service disabled                |
| 15  | **PhotoMap enable + verify**           | Feature        | LOW      | 1h     | Module exists but service disabled                |
| 16  | **Gitea GitHub sync auth fix**         | Feature        | MEDIUM   | 1h     | Token auth may be broken                          |
| 17  | **RPi3 provisioning**                  | Infrastructure | MEDIUM   | 4h     | Hardware needed + SD image deployment             |
| 18  | **DNS failover testing**               | Infrastructure | MEDIUM   | 2h     | VRRP cluster untested in production               |
| 19  | **Twenty CRM verification**            | Feature        | LOW      | 1h     | Module present, runtime unverified                |
| 20  | **TPM2 + measured boot**               | Security       | HIGH     | 3h     | Requires LUKS first                               |
| 21  | **Pre-commit hook for jscpd**          | Quality        | LOW      | 30min  | Automated copy/paste detection                    |
| 22  | **Module option documentation**        | Documentation  | MEDIUM   | 2h     | Generated docs for service options                |
| 23  | **CONTEXT.md**                         | Documentation  | LOW      | 30min  | Domain context for new contributors               |
| 24  | **Minecraft runtime verification**     | Feature        | LOW      | 30min  | Module exists, untested at runtime                |
| 25  | **Build time profiling**               | Performance    | MEDIUM   | 1h     | Identify and optimize slow derivations            |

---

## g) TOP 1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**Is the Authelia bcrypt client secret (hardcoded in `authelia.nix:20`) still the correct/active secret, or has it been rotated since it was committed?**

The hash is sitting in plain text in the module source. I can't determine if:

- It matches the current production secret
- It has been superseded by a sops-managed value
- It should be migrated to `authelia-secrets.yaml` alongside the other Authelia secrets

This is a security question that only someone with access to the running Authelia instance can answer.

---

## Codebase Metrics

| Metric                  | Value                        |
| ----------------------- | ---------------------------- |
| Total .nix files        | 102                          |
| Total lines of Nix code | 13,153                       |
| Flake inputs            | 31                           |
| NixOS service modules   | 30                           |
| System packages         | 104                          |
| Justfile recipes        | ~100                         |
| ADRs                    | 5                            |
| Largest module          | signoz.nix (741 lines)       |
| Largest config          | niri-wrapped.nix (602 lines) |
| Flake.nix size          | 734 lines                    |

## Top 10 Largest Files (by line count)

| Rank | File                                        | Lines | Purpose                   |
| ---- | ------------------------------------------- | ----- | ------------------------- |
| 1    | `modules/nixos/services/signoz.nix`         | 741   | Observability stack       |
| 2    | `flake.nix`                                 | 734   | Entry point               |
| 3    | `platforms/nixos/programs/niri-wrapped.nix` | 602   | Wayland compositor config |
| 4    | `modules/nixos/services/gitea.nix`          | 551   | Git hosting               |
| 5    | `modules/nixos/services/minecraft.nix`      | 454   | Minecraft server/client   |
| 6    | `platforms/nixos/programs/yazi.nix`         | 441   | File manager config       |
| 7    | `platforms/nixos/desktop/waybar.nix`        | 410   | Status bar config         |
| 8    | `platforms/nixos/users/home.nix`            | 406   | Home Manager (NixOS)      |
| 9    | `platforms/nixos/modules/dns-blocker.nix`   | 352   | DNS blocking config       |
| 10   | `modules/nixos/services/gitea-repos.nix`    | 309   | GitHub→Gitea sync         |

## Session 22 Changes

| File                                 | Change                                                                                  |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| `flake.nix`                          | Moved `jscpdOverlay` to `sharedOverlays`; removed from perSystem; removed from devShell |
| `platforms/common/packages/base.nix` | Added `jscpd` to system packages (Code quality section)                                 |

---

_Generated by Crush — Session 22_
