# SystemNix — Comprehensive Status Report

**Date:** 2026-05-02 20:36
**Session:** 15
**Author:** Crush AI
**Branch:** master (2 commits ahead of origin)

---

## Executive Summary

SystemNix is a mature, cross-platform Nix configuration managing two machines (macOS + NixOS) through a single flake with 54 inputs, 29 service modules, 27 custom packages, and ~130 justfile recipes. The codebase is in **good shape** — 65% of all tracked TODOs are complete, zero TODO/FIXME comments remain in code, all services have flake-parts modules, and the Catppuccin Mocha theme is consistently applied across all UI components. The primary blocker for remaining work is **physical access to evo-x2** for deployment and testing.

### Key Metrics

| Metric                      | Value                                         |
| --------------------------- | --------------------------------------------- |
| Flake inputs                | 54                                            |
| NixOS service modules       | 29                                            |
| Custom packages             | 27                                            |
| Common program modules      | 14                                            |
| Justfile recipes            | ~130                                          |
| ADRs                        | 5 (all Accepted)                              |
| Status reports              | 55+ (172 in archive)                          |
| MASTER_TODO_PLAN completion | 62/95 (65%)                                   |
| Unpushed commits            | 2                                             |
| Unstaged changes            | 1 (niri-wrapped.nix — Prism Launcher opacity) |

---

## A) FULLY DONE ✅

### Infrastructure Architecture

- **Flake-parts modular architecture** — 29 self-contained NixOS service modules, each with its own `options` + `config`, imported via `flake.nix` and wired into evo-x2
- **Cross-platform Home Manager** — 14 shared program modules in `platforms/common/`, both platforms import `home-base.nix` (Darwin + NixOS)
- **Centralized AI model storage** (`modules/nixos/services/ai-models.nix`) — `/data/ai/` tree with all tool-specific paths, env vars, systemd tmpfiles
- **DNS blocking stack** — Unbound + dnsblockd + dnsblockd-processor, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream
- **SigNoz observability** — Full stack (Query Service, OTel Collector, ClickHouse, node_exporter, cAdvisor), journald log collection, Prometheus scraping
- **Sops-nix secrets management** — Age-encrypted via SSH host key, declarative templates, merged `.env` files
- **Systemd hardening library** — `lib/systemd.nix` (harden) + `lib/systemd/service-defaults.nix` (restart policies), 7 services using harden, 1 using serviceDefaults

### Desktop Environment (NixOS / Niri)

- **Niri compositor** — Full config: keybinds (terminals, windows, focus, workspaces, launchers, screenshots, volume, media, brightness), input devices (keyboard, touchpad, mouse, trackball, tablet), animations, environment
- **Session save/restore** — Systemd timer (60s interval), JSON snapshots, kitty state capture, workspace-aware restore, floating state, column widths, focus order, fallback apps, 7-day max age
- **14 window rules** — Per-app workspace assignment (Firefox→browser, Kitty→main, Emacs→dev, Slack/Discord/Telegram/Signal→chat, Spotify→media), floating rules (PiP, pavucontrol, KeePassXC), fullscreen for Steam, opacity overrides (Prism Launcher, Steam)
- **Waybar** — 16 modules (workspaces, window, clock, media, camera, DNS stats, disk, weather, audio, network, CPU, memory, temperature, clipboard, tray, power), Catppuccin Mocha inline CSS
- **Rofi** — 5-column icon grid, Catppuccin Mocha, JetBrainsMono, drun/run/window modes
- **Swaylock** — Effects variant, Catppuccin Mocha ring colors
- **wlogout** — 6 actions with inline SVG icons, Catppuccin Mocha
- **Wallpaper system** — `awww-daemon` systemd service, `awww-wallpaper` one-shot, wallpapers via flake input, Mod+W keybind
- **Screenshots** — grim + slurp + swappy (area/full/output), Mod+F11 keybinds
- **Idle management** — swayidle (12h → suspend, before-sleep → lock)

### Shell & CLI (Cross-Platform)

- **Fish, Zsh, Bash** — Shared aliases via `shell-aliases.nix`, history config, autosuggestions, carapace completions, starship prompt
- **Git** — GPG signing, LFS, credential helper, git-town aliases, HTTPS→SSH rewrite
- **Taskwarrior 3** — Catppuccin Mocha theme, TaskChampion sync, deterministic client IDs, agent tracking protocol, daily backup timer
- **FZF** — Themed from colorScheme, ripgrep integration
- **Tmux** — 256-color, plugins (resurrect, yank), SystemNix dev session, themed status bar
- **Yazi** — File manager with image preview, Catppuccin Mocha, shell keybinds
- **Zellij** — Terminal multiplexer with tmux keybinds, Catppuccin Mocha, dev + monitoring layouts
- **Pre-commit** — Shared hooks config (large files, YAML/JSON/TOML, nixpkgs-fmt, shellcheck, markdownlint)

### Services (NixOS)

- **Caddy** — Reverse proxy with TLS via sops, SNI-based routing, Prometheus metrics, sd_notify watchdog
- **Gitea** — Git hosting, GitHub mirror sync, systemd hardening, sd_notify watchdog
- **Immich** — Photo/video management, ML workers, Redis, PostgreSQL
- **Homepage** — Service dashboard with Catppuccin theme, Docker integration
- **Hermes** — AI agent gateway (Discord bot, cron, messaging), sops secrets, system-level service
- **Minecraft** — Server (custom JDK 25 + ZGC package) + client options (Prism Launcher declarative options.txt)
- **Twenty CRM** — Docker-based CRM
- **PhotoMap** — AI photo exploration
- **Voice Agents** — LiveKit + Whisper ASR
- **ComfyUI** — AI image generation
- **Authelia** — SSO/authentication
- **TaskChampion** — Taskwarrior sync server
- **SDDM** — Silent theme, Catppuccin Mocha
- **Chromium policies** — YouTube Shorts Blocker, security policies

### Custom Packages (27 total)

- **23 Go packages** via `mkGoTool` shared builder: art-dupl, auto-deduplicate, branching-flow, buildflow, code-duplicate-analyzer, dnsblockd, dnsblockd-processor, file-and-image-renamer, go-auto-upgrade, go-functional-fixer, go-structure-linter, golangci-lint-auto-configure, hierarchical-errors, library-policy, md-go-validator, modernize, mr-sync, project-meta, projects-management-automation, template-readme, terraform-diagrams-aggregator, terraform-to-d2
- **2 Rust packages**: monitor365, netwatch
- **1 Python package**: aw-watcher-utilization
- **1 Node.js package**: jscpd
- **1 AppImage**: openaudible
- All packages have real hashes (no placeholders), all wired into flake.nix overlays + packages

### Hardware (NixOS)

- **AMD GPU** — amdgpu driver, ROCm compute, 32-bit Mesa, monitoring tools (amdgpu_top, rocm-smi, nvtop)
- **AMD NPU** — XDNA driver (kernel 6.14+), XRT runtime with Boost workaround
- **Bluetooth** — PipeWire audio, Google Nest Audio casting
- **EMEET PIXY** — External flake input with NixOS module, auto-tracking/auto-privacy, Waybar integration, SigNoz monitoring
- **Boot** — systemd-boot, BTRFS (zstd root + zstd:3 /data), ZRAM swap

### Darwin (macOS)

- **Homebrew** — Declarative via nix-homebrew
- **LaunchAgents** — ActivityWatch, SublimeText sync, Crush updates
- **Security** — TouchID, Keychain, PAM
- **Chrome policies** — YouTube Shorts Blocker, security policies
- **Shell configs** — Platform-specific Fish/Zsh/Bash with Homebrew PATH

### Security

- **Systemd hardening** — 7 services hardened (gitea, homepage, immich, signoz, twenty, hermes, minecraft)
- **SSH hardening** — No password auth, fail2ban, restricted ciphers
- **Disk encryption** — LUKS via boot config
- **SOPS** — Age-encrypted secrets for all services
- **Chromium policies** — HTTPS-only, no signin, Manifest V2 blocked

### Documentation

- **5 ADRs** — All Accepted (Home Manager cross-platform, shell alias architecture, OpenZFS macOS ban, sops-nix, niri session restore)
- **55+ status reports** — 172 in archive
- **MASTER_TODO_PLAN** — 95 items tracked, 62 complete (65%)
- **AGENTS.md** — Comprehensive project guide (current and maintained)

---

## B) PARTIALLY DONE ⚠️

### Service Hardening Coverage

- **7 of 29** service modules use `harden()` — gitea, homepage, immich, signoz, twenty, hermes, minecraft
- **1 of 29** uses `serviceDefaults()` — photomap only
- **21 modules** have neither — authelia, caddy, gitea-repos, sops, taskchampion, voice-agents, monitor365, comfyui, dns-failover, display-manager, audio, niri-config, security-hardening, ai-models, ai-stack, monitoring, multi-wm, chromium-policies, steam, file-and-image-renamer, default-services
- Many of these are config-only modules (not running daemons), but some could benefit (taskchampion, comfyui, voice-agents, file-and-image-renamer)

### EMEET PIXY Daemon

- **Functional** but has a **vendorHash workaround** in flake.nix — upstream repo has stale vendor directory
- Overlay patches around it locally, but upstream needs `go mod vendor` + `vendorHash` update
- 20 Go lint warnings in upstream repo (low priority)
- No CI in upstream repo

### NixOS Services — Observability

- SigNoz is deployed but **missing metrics for ~10 services** (per MASTER_TODO_PLAN #65)
- Caddy, Authelia, node_exporter, cAdvisor are scraped
- Services lacking metrics: hermes, comfyui, voice-agents, minecraft, photomap, homepage, taskchampion, twenty, gitea-repos, file-and-image-renamer

### MASTER_TODO_PLAN — 33 Items Remaining

- **4 P1 Security items** — Taskwarrior encryption to sops, VRRP auth to sops, Docker image digest pinning (Voice Agents + PhotoMap)
- **1 P5 Deploy** — `just switch` to apply all pending changes to evo-x2
- **27 items blocked on evo-x2 physical access**

---

## C) NOT STARTED ⏳

### DNS Failover Cluster

- Module exists (`modules/nixos/services/dns-failover.nix`) — Keepalived VRRP
- evo-x2 config (primary, priority 100) defined
- rpi3-dns config (backup, priority 50) defined in `nixosConfigurations.rpi3-dns`
- **Not enabled** on either host — Pi 3 hardware not provisioned
- VRRP auth password not in sops yet (P1 security item)

### Pi 3 DNS Backup Node

- `nixosConfigurations.rpi3-dns` exists in flake.nix
- Image build recipe exists in justfile
- **Never built, flashed, or tested**

### Hermes Health Check Endpoint

- MASTER_TODO_PLAN #62 — needs Hermes code change (Go)
- No implementation started

### Authelia SMTP Notifications

- MASTER_TODO_PLAN #66 — needs SMTP credentials
- No configuration started

### Immich & Twenty Backup Restore Tests

- MASTER_TODO_PLAN #67-68 — verify backups actually restore
- Backup scripts exist (`just immich-backup`) but restore never tested

### Docker Image Digest Pinning

- Voice Agents and PhotoMap use `latest` image tags
- MASTER_TODO_PLAN #9, #10 — pin to specific digests for supply chain security

### Unbound DNS-over-QUIC

- Overlay code exists in flake.nix but **commented out** (lines 411-432)
- Disabled because it overrides unbound build flags, cascading to 40+ min rebuilds of ffmpeg/linux/pipewire

---

## D) TOTALLY FUCKED UP 💥

### mr-sync Package — Missing from perSystem

- Package definition exists in `pkgs/mr-sync.nix`
- Wired into `sharedOverlays` (works via `base.nix` systemPackages)
- **NOT in `perSystem` overlays or packages** — `nix build .#mr-sync` will fail
- Fix: Add to perSystem overlays + packages in flake.nix

### NixOS shells.nix — Missing Common Shell Imports

- Darwin `shells.nix` imports `../../common/programs/fish.nix` and `../../common/programs/bash.nix`
- NixOS `shells.nix` does **NOT** import these common shell configs
- This means NixOS may be missing common Fish/Bash settings that Darwin gets
- Could be intentional (NixOS has its own Fish/Bash init) or an oversight

### EMEET PIXY vendorHash Workaround

- Not "fucked up" per se, but a **fragile workaround** that breaks if upstream changes
- Root cause: upstream `go.mod` dependencies diverged from committed `vendor/`
- Fix: push `go mod vendor` fix upstream (5 min task)

### dnsblockd Staticcheck Warning

- `platforms/nixos/programs/dnsblockd/main.go:481` — QF1001: could apply De Morgan's law
- Minor code quality issue, not functional

---

## E) WHAT WE SHOULD IMPROVE 🔧

### High Priority

1. **Service hardening coverage** — 22 modules without `harden()`. Non-daemon modules (config-only) are fine, but taskchampion, comfyui, voice-agents, file-and-image-renamer should be hardened.

2. **serviceDefaults adoption** — Only photomap uses it. All daemons with `Restart=always` should use `serviceDefaults {}` for consistency.

3. **Docker image pinning** — Voice Agents and PhotoMap float on `latest`. Pin digests for reproducibility and security.

4. **Secrets to sops** — Taskwarrior encryption secret and VRRP auth password are deterministic hashes, not in sops. Move them for proper secret management.

5. **mr-sync perSystem wiring** — Add to `perSystem` overlays + packages so `nix build .#mr-sync` works.

6. **NixOS shells.nix divergence** — Audit whether NixOS is missing common Fish/Bash settings that Darwin gets. Consolidate or document the difference.

### Medium Priority

7. **Observability gaps** — 10+ services lack SigNoz metrics. Add Prometheus exporters or OTLP instrumentation.

8. **Backup restore testing** — Immich and Twenty backups exist but have never been restored. Test them before they're needed.

9. **EMEET PIXY upstream fix** — Push `go mod vendor` fix to eliminate the flake.nix vendorHash overlay hack.

10. **Hermes health check** — Add `/healthz` endpoint for proper liveness probing.

11. **Authelia SMTP** — Configure email notifications for auth events.

12. **Pi 3 DNS failover** — Provision hardware, build image, test failover.

### Lower Priority

13. **Unbound DoQ** — Currently disabled due to binary cache cascade. Investigate if upstream has resolved the build flag conflict.

14. **dnsblockd staticcheck** — Apply De Morgan's law at line 481.

15. **EMEET PIXY CI** — Add GitHub Actions for the upstream repo.

16. **Waybar theme centralization** — Currently hardcoded CSS. Consider using `catppuccin` NixOS module for consistency.

17. **Status report cleanup** — 55+ status reports in docs/status/, 172 in archive. Consider archiving older ones.

---

## F) Top 25 Things We Should Get Done Next

### Immediate (AI-actionable, no evo-x2 needed)

| #   | Task                                                                                           | Effort | Impact            |
| --- | ---------------------------------------------------------------------------------------------- | ------ | ----------------- |
| 1   | Fix mr-sync perSystem wiring in flake.nix                                                      | 5 min  | Build works       |
| 2   | Audit NixOS shells.nix vs Darwin shells.nix divergence                                         | 15 min | Consistency       |
| 3   | Push emeet-pixyd vendor fix upstream                                                           | 5 min  | Remove workaround |
| 4   | Fix dnsblockd staticcheck (De Morgan's)                                                        | 2 min  | Code quality      |
| 5   | Add Hermes health check endpoint                                                               | 30 min | Reliability       |
| 6   | Harden remaining daemon services (taskchampion, comfyui, voice-agents, file-and-image-renamer) | 1 hr   | Security          |
| 7   | Adopt serviceDefaults across all daemon services                                               | 30 min | Consistency       |
| 8   | Move Taskwarrior encryption secret to sops-nix                                                 | 30 min | Security          |
| 9   | Move VRRP auth password to sops-nix                                                            | 15 min | Security          |
| 10  | Add catppuccin theme module for Waybar (replace hardcoded CSS)                                 | 30 min | Maintainability   |

### Requires evo-x2 Physical Access

| #   | Task                                                     | Effort | Impact            |
| --- | -------------------------------------------------------- | ------ | ----------------- |
| 11  | `just switch` — deploy all pending changes               | 30 min | Everything        |
| 12  | Pin Docker image digests for Voice Agents                | 10 min | Security          |
| 13  | Pin Docker image digests for PhotoMap                    | 10 min | Security          |
| 14  | Test Immich backup restore                               | 30 min | Disaster recovery |
| 15  | Test Twenty CRM backup restore                           | 30 min | Disaster recovery |
| 16  | Verify all hardened services start correctly post-deploy | 15 min | Reliability       |
| 17  | Add SigNoz metrics for missing services                  | 2 hr   | Observability     |
| 18  | Configure Authelia SMTP notifications                    | 30 min | Security          |
| 19  | Test niri session restore on real reboot                 | 10 min | Reliability       |
| 20  | Verify Prism Launcher opacity fix                        | 2 min  | Visual            |

### Longer Term / Infrastructure

| #   | Task                                                               | Effort | Impact            |
| --- | ------------------------------------------------------------------ | ------ | ----------------- |
| 21  | Build Pi 3 SD image and test DNS failover                          | 4 hr   | High availability |
| 22  | Investigate Unbound DoQ re-enablement                              | 2 hr   | Privacy           |
| 23  | Add GitHub Actions CI to emeet-pixyd repo                          | 1 hr   | Quality           |
| 24  | Centralize all Catppuccin Mocha colors into a shared Nix let block | 2 hr   | DRY               |
| 25  | Archive old status reports (pre-2026-04-25)                        | 15 min | Cleanliness       |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Is the NixOS `shells.nix` intentionally NOT importing `common/programs/fish.nix` and `common/programs/bash.nix`?**

Darwin's `platforms/darwin/programs/shells.nix` explicitly imports both:

```nix
imports = [ ../../common/programs/fish.nix ../../common/programs/bash.nix ];
```

NixOS's `platforms/nixos/programs/shells.nix` does NOT. However, NixOS gets Fish and Bash config through `home-base.nix` → `common/home-base.nix` which imports all 14 program modules including fish.nix and bash.nix. So both platforms DO get the common shell configs — just through different import paths.

**Clarification needed:** Is this intentional design (Darwin imports common shells directly in shells.nix, NixOS gets them via home-base.nix) or should NixOS shells.nix also explicitly import them for consistency? The end result is the same (both get the config), but the divergent import paths are confusing.

---

## File Inventory

### Core Files

| File                                        | Lines | Purpose                              |
| ------------------------------------------- | ----- | ------------------------------------ |
| `flake.nix`                                 | 959   | Entry point (flake-parts, 54 inputs) |
| `justfile`                                  | 1,978 | ~130 recipes                         |
| `platforms/nixos/programs/niri-wrapped.nix` | 872   | Niri compositor + session management |
| `AGENTS.md`                                 | ~600  | Project guide for AI agents          |

### Module Count

| Category               | Count      |
| ---------------------- | ---------- |
| NixOS service modules  | 29         |
| Custom packages        | 27         |
| Common program modules | 14         |
| Desktop configs        | 1 (waybar) |
| Hardware configs       | 4          |
| NixOS program configs  | 8          |
| Darwin configs         | 13         |
| ADRs                   | 5          |

### Git State

```
Branch: master (2 commits ahead of origin)
Unpushed: 05ccd90, aea82ce (session 14 status docs)
Unstaged: platforms/nixos/programs/niri-wrapped.nix (Prism Launcher opacity rule)
```

---

## Session History (Recent)

| Date       | Session       | Key Events                                                                     |
| ---------- | ------------- | ------------------------------------------------------------------------------ |
| 2026-05-02 | **15** (this) | Prism Launcher opacity fix, comprehensive status audit                         |
| 2026-05-01 | 14            | Wallpaper fix, awww-daemon startup ordering                                    |
| 2026-05-01 | 13            | Post-reboot recovery, 6 crashed services fixed, systemd hardening refactor     |
| 2026-05-01 | 12            | Build fixes (photomap, gitea-repos, golangci-lint-auto-configure, emeet-pixyd) |
| 2026-05-01 | 11            | Papermark integration research                                                 |
| 2026-05-01 | 10            | AutoMode enum, Go tool refactoring, niri nproc fix                             |
| 2026-05-01 | 9             | Go tool mass integration (16 tools), mkGoTool shared builder                   |
| 2026-04-30 | 7-8           | Netwatch, service reliability hardening                                        |
| 2026-04-30 | 2-5           | Self-reflection fixes, direnv fix, niri BindsTo incident, cleanup sprint       |

---

_Generated by Crush AI — 2026-05-02 20:36_
