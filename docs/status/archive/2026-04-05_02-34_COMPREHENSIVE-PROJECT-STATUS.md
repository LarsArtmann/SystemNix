# SystemNix Comprehensive Project Status Report

**Date:** 2026-04-05 02:34
**Author:** Crush AI Agent
**Working Tree:** Clean (no uncommitted changes)
**Commit:** 3eea135 (latest) — cross-platform preferences module + Immich disabled

---

## Executive Summary

SystemNix is a **mature, production-grade cross-platform Nix configuration** managing a MacBook Air (macOS/aarch64-darwin) and evo-x2 (NixOS/x86_64-linux). The codebase comprises ~732 lines of Nix configuration across 60+ files. Working tree is clean with no merge conflicts. Three services are intentionally disabled (Authelia, Immich, Grafana) due to missing secrets. The cross-platform architecture is solid with ~80% shared configuration.

**Key metrics:**

- Nix files: 60+ | Total lines: ~732 (core config only, excluding docs/scripts)
- Platforms: 2 (macOS aarch64-darwin, NixOS x86_64-linux)
- Shared modules: 17 (in `platforms/common/`)
- NixOS-only modules: 25+ (system, desktop, hardware, services)
- Darwin-only modules: 12 (system, security, services, networking)
- Flake inputs: 20 (nixpkgs, home-manager, niri, sops-nix, etc.)

---

## A) FULLY DONE ✅

### Cross-Platform Shared Configuration

- **Git** — Complete config: GPG signing, LFS, git-town, aliases, ignores, URL rewriting (`git@github.com:` instead of `https://github.com/`) — `common/programs/git.nix`
- **Shell aliases** — Shared via `shell-aliases.nix` for Fish, Zsh, Bash — `common/programs/shell-aliases.nix`
- **Starship prompt** — Catppuccin Mocha, performance-optimized with nix-colors — `common/programs/starship.nix`
- **Tmux** — Cross-platform with Catppuccin colors, SystemNix keybindings, resurrect plugin — `common/programs/tmux.nix`
- **FZF** — Ripgrep integration, all shell integrations — `common/programs/fzf.nix`
- **KeePassXC** — Cross-platform with Chromium AND Helium browser native messaging — `common/programs/keepassxc.nix`
- **Fish/Zsh/Bash/Nushell** — All 4 shells configured, shared aliases, platform-specific rebuild commands — `common/programs/{fish,zsh,bash,nushell}.nix`
- **Packages** — Essential, development, GUI, AI packages with platform conditionals — `common/packages/base.nix`
- **Fonts** — JetBrains Mono, Fira Code, Iosevka nerd fonts, noto fallbacks — `common/packages/fonts.nix`
- **Environment variables** — EDITOR, LANG, NIX_PATH, Node/Go settings — `common/environment/variables.nix`
- **Nix settings** — Experimental features, garbage collection, optimization, substituters — `common/core/nix-settings.nix`
- **Pre-commit config** — Validation hooks for Nix, shell, dependencies — `common/programs/pre-commit.nix`
- **uBlock filters** — Custom privacy filters with LaunchAgent/systemd auto-update — `common/programs/ublock-filters.nix`
- **Chromium** — Brave on macOS with extension management, Helium on Linux with Widevine — `common/programs/chromium.nix`
- **Home Manager** — `home-manager.enable`, Go setup, session variables — `common/home-base.nix`
- **Cross-platform preferences** — New unified dark mode preference module — `common/preferences.nix`

### macOS (Darwin) — Complete

- **System settings** — Keyboard repeat, trackpad, Finder list view, dark mode — `darwin/system/settings.nix`
- **Security** — TouchID PAM for sudo with tmux reattach, Keychain auto-lock (5min) — `darwin/security/{pam,keychain}.nix`
- **LaunchAgents** — ActivityWatch, SublimeText sync, Crush update, aw-watcher-utilization — `darwin/services/launchagents.nix`
- **Networking** — Hostname, firewall, Bonjour — `darwin/networking/default.nix`
- **Chrome policies** — Extension management via /etc/chrome policies — `darwin/programs/chrome.nix`
- **File associations** — Sublime Text for txt/md/json/yaml/toml/d2 via duti — `darwin/system/activation.nix`
- **Homebrew** — Headlamp Kubernetes GUI — `darwin/default.nix`
- **Go 1.26.1** — Pinned via overlay — `darwin/default.nix`

### NixOS — Complete

#### Boot & Hardware

- **Boot** — systemd-boot, latest kernel, AMD GPU/NPU kernel params, ZRAM — `nixos/system/boot.nix`
- **AMD GPU** — Full ROCm stack, Mesa, RADV, performance tuning, udev rules — `nixos/hardware/amd-gpu.nix`
- **AMD NPU** — XDNA driver, XRT runtime with Boost 1.87 fix — `nixos/hardware/amd-npu.nix`
- **Bluetooth** — Audio source/sink, Blueman — `nixos/hardware/bluetooth.nix`
- **Hardware config** — BTRFS root, data partition, EFI boot, Realtek/MediaTek — `nixos/hardware/hardware-configuration.nix`

#### Desktop Environment

- **Niri** — Scrollable-tiling compositor with random wallpapers, swayidle, keybindings, window rules, 5 named workspaces — `nixos/programs/niri-wrapped.nix`
- **Waybar** — Status bar with DNS stats, weather, media, clipboard, power menu — `nixos/desktop/waybar.nix`
- **SDDM** — SilentSDDM with Catppuccin Mocha theme — `nixos/desktop/display-manager.nix`
- **Audio** — PipeWire with ALSA, JACK, realtime scheduling — `nixos/desktop/audio.nix`
- **Rofi** — Catppuccin grid theme with icon view — `nixos/programs/rofi.nix`
- **Swaylock** — Blur + vignette effects, Catppuccin colors — `nixos/programs/swaylock.nix`
- **Wlogout** — Power menu with inline SVG icons, Catppuccin — `nixos/programs/wlogout.nix`
- **Zellij** — Catppuccin theme, tmux-compatible keybindings, dev/monitoring layouts — `nixos/programs/zellij.nix`
- **Yazi** — Catppuccin theme, image preview, file associations — `nixos/programs/yazi.nix`
- **Kitty** — Catppuccin Mocha, TV-friendly font size (16pt) — `nixos/users/home.nix`
- **Foot** — Lightweight Wayland terminal, Catppuccin colors — `nixos/users/home.nix`
- **Dunst** — Notification daemon with Catppuccin colors — `nixos/users/home.nix`
- **GTK/Qt** — Catppuccin Mocha Compact Lavender, dark mode, font size 16 — `nixos/users/home.nix`
- **Sway backup WM** — Available at SDDM login screen — `nixos/desktop/multi-wm.nix`

#### System Services

- **Networking** — Static IP (192.168.1.150), firewall, unbound DNS — `nixos/system/networking.nix`
- **DNS blocker** — Unbound + dnsblockd, 25+ blocklists (~2.5M domains), LAN DNS records — `nixos/system/dns-blocker-config.nix`
- **SSH** — Hardened via nix-ssh-config, fail2ban, password auth disabled — `nixos/system/configuration.nix`
- **Sudo** — Passwordless for wheel group — `nixos/system/sudo.nix`
- **Snapshots** — BTRFS snapshots via Timeshift, daily timer — `nixos/system/snapshots.nix`
- **Scheduled tasks** — Crush update, blocklist update, health checks — `nixos/system/scheduled-tasks.nix`
- **Security hardening** — AppArmor, fail2ban, ClamAV, polkit, security tools — `nixos/desktop/security-hardening.nix`

#### Infrastructure Services (via flake-parts modules)

- **Caddy** — HTTPS reverse proxy with SOPS-managed TLS certs — `modules/nixos/services/caddy.nix`
- **Gitea** — Git mirror with GitHub sync, admin setup, CI/CD runner — `modules/nixos/services/gitea.nix`
- **Gitea repos** — Declarative repo mirroring for dnsblockd, BuildFlow — `modules/nixos/services/gitea-repos.nix`
- **SigNoz** — Full observability platform (ClickHouse + OTel collector) — `modules/nixos/services/signoz.nix`
- **Homepage** — Service dashboard with health checks — `modules/nixos/services/homepage.nix`
- **SOPS** — Secrets management via age, ssh host key — `modules/nixos/services/sops.nix`
- **Monitoring** — Prometheus + node/postgres/redis/caddy exporters — `modules/nixos/services/monitoring.nix`
- **PhotoMap** — CLIP embedding vector map, Immich integration — `modules/nixos/services/photomap.nix`

#### AI/ML Stack

- **Ollama** — v0.20.0 with ROCm, Flash Attention, custom data dir — `nixos/desktop/ai-stack.nix`
- **Unsloth Studio** — AI model training UI, automated setup — `nixos/desktop/ai-stack.nix`
- **llama.cpp** — With ROCWMMA optimizations for Strix Halo — `nixos/desktop/ai-stack.nix`

#### Steam

- **Steam** — Added to NixOS configuration — `nixos/programs/steam.nix`

### Infrastructure

- **Flake** — 20 inputs, flake-parts architecture, dendritic modules — `flake.nix`
- **Formatter** — treefmt-full-flake (alejandra in PATH) — `flake.nix`
- **Pre-commit** — 8 hooks: gitleaks, trailing whitespace, deadnix, statix, alejandra, nix-check, flake-lock-validate, merge-conflicts — `.pre-commit-config.yaml`
- **Crush config** — Deployed as flake input, symlinked to both platforms — `flake.nix`

---

## B) PARTIALLY DONE ⚠️

### 1. SSH Host Configuration — macOS Missing Hetzner Hosts

- **Status:** NixOS has 6 hosts, macOS has 2 hosts
- **What works:** `onprem` and `evo-x2` on both platforms
- **What's missing:** macOS lacks `private-cloud-hetzner-0` through `private-cloud-hetzner-3`
- **Impact:** Cannot SSH to Hetzner servers by name from MacBook
- **Location:** `platforms/darwin/home.nix:24-31` vs `platforms/nixos/users/home.nix:30-47`

### 2. Chrome/Chromium Policy Management

- **Both platforms:** Force-install YT Shorts Blocker, security policies
- **NixOS only:** `RestoreOnStartup`, `BookmarkBarEnabled`, `DefaultBrowserSettingEnabled`
- **Darwin gap:** Policy file requires manual `sudo chrome-apply-policies` to install
- **Location:** `platforms/darwin/programs/chrome.nix` vs `platforms/nixos/programs/chrome.nix`

### 3. Cross-Platform Tool Availability

- **gitui** (terminal git TUI) — NixOS only (`platforms/nixos/users/home.nix:127`)
- **signal-desktop** — NixOS only (`platforms/nixos/users/home.nix:113`)
- **zed-editor** — NixOS only (`platforms/nixos/users/home.nix:141`)
- **yazi** — NixOS via HM module with Catppuccin theme; macOS has yazi binary from base.nix but no HM module config

### 4. Disabled Services (Awaiting Secrets)

- **Authelia** — Module exists but disabled in `flake.nix:265` with comment: "secrets not configured"
- **Immich** — Module exists but disabled in `flake.nix:271` with comment: "secrets not configured"
- **Grafana** — Module exists but disabled in `flake.nix:268` with comment: "secrets not configured"
- **Impact:** SSO, photo management, and monitoring dashboards unavailable until secrets are added to `platforms/nixos/secrets/secrets.yaml`

---

## C) NOT STARTED ❌

### Architecture Improvements

1. **SSH hosts consolidation** — No shared SSH host list; each platform duplicates the common 2 hosts
2. **Color scheme options extraction** — Both platforms define identical `colorScheme`/`colorSchemeLib` options
3. **CI cross-platform drift check** — No automated verification of config parity
4. **Common Chrome policy module** — Different mechanisms per platform, no shared policy definitions
5. **XDG dark mode portal config** — NixOS has it `xdg-desktop-portal/config`, macOS has preferences module, no shared abstraction

### Code Quality

6. **Darwin shells.nix double-import cleanup** — `platforms/darwin/programs/shells.nix:3-5` re-imports `fish.nix` and `bash.nix` already loaded by `home-base.nix`
7. **Remove `jq` from NixOS `home.packages`** — Duplicated in `common/packages/base.nix:47`
8. **Extract `gitui` to common packages** — Works on macOS too, currently NixOS-only
9. **Audit NixOS `home.packages`** — Many packages could potentially be shared

### Documentation

10. **Update AGENTS.md** — Reflect: `nix-ssh-config` migration, disabled services, preferences module, removed files (UserConfig.nix, PathConfig.nix, security.nix)
11. **ADR for preferences module** — Document the new cross-platform dark mode approach
12. **Document disabled services** — Create runbook for enabling Authelia/Immich/Grafana when secrets are ready

---

## D) TOTALLY FUCKED UP 💥

### Nothing Currently Build-Breaking

The working tree is clean, no merge conflicts exist, no syntax errors detected. The previous SSH merge conflict has been resolved.

### Active Risks

| #   | Risk                                  | Severity | Details                                                                                                                                                                         |
| --- | ------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Go overlay duplicated**             | Medium   | Same Go 1.26.1 overlay in `flake.nix:91-98` AND `darwin/default.nix:66-78`. If one updates without the other, platforms diverge.                                                |
| 2   | **nixpkgs allowUnfree contradiction** | Medium   | `flake.nix:139` sets blanket `allowUnfree = true`; `common/core/nix-settings.nix:48-60` sets curated `allowUnfreePredicate`. Blanket overrides predicate = dead code.           |
| 3   | **Disabled services rotting**         | Low      | Authelia, Immich, Grafana modules exist but are disabled. Code could drift from API changes without anyone noticing.                                                            |
| 4   | **SOPS secrets incomplete**           | Medium   | `gitea_token`, `github_token`, `github_user` secrets exist. `grafana_*`, `authelia_*`, `immich_*` secrets are commented out. Services can't be enabled until secrets are added. |
| 5   | **Authelia user database hardcoded**  | Low      | `modules/nixos/services/authelia.nix` has a hardcoded user "lars" with a hashed password. This should use sops-nix.                                                             |

---

## E) WHAT WE SHOULD IMPROVE 📈

### High Priority (Do Soon)

1. **Remove Darwin Go overlay** — Already handled by `flake.nix` `perSystem._module.args.pkgs`. The `darwin/default.nix` overlay is redundant and a divergence risk.

2. **Reconcile allowUnfree** — Either remove the dead `allowUnfreePredicate` from `nix-settings.nix` or enforce the curated list by removing blanket allow from `flake.nix`.

3. **Fix Darwin shells.nix double-imports** — Remove `imports = [../../common/programs/fish.nix ... bash.nix]` from `darwin/programs/shells.nix:3-5` since `home-base.nix` already imports them. NixOS correctly does NOT re-import.

4. **Add Hetzner SSH hosts to macOS** — Either duplicate in `darwin/home.nix` or extract to common module.

### Medium Priority

5. **Remove `jq` from NixOS `home.packages`** — Already in `common/packages/base.nix:47`.

6. **Extract color scheme options to common module** — Single source of truth for `colorScheme`/`colorSchemeLib`.

7. **Move `gitui` to common packages** — Works on macOS, currently NixOS-only.

8. **Enable disabled services** — Add missing secrets to `secrets.yaml` and enable Authelia/Immich/Grafana.

9. **Fix Authelia hardcoded password** — Use sops-nix instead of hardcoded hash.

### Lower Priority

10. **Create CI cross-platform drift check** — Automated comparison of key config aspects.

11. **Consolidate Chrome policies** — Shared policy definitions between platforms.

12. **Clean up removed files** — `security.nix`, `PathConfig.nix`, `UserConfig.nix` were removed from `common/core/` but references may linger in docs.

---

## F) TOP 25 THINGS TO DO NEXT 🎯

### Priority 1: Quick Wins (Under 15 min each)

| #   | Task                                                           | Effort | Impact | Risk if skipped                   |
| --- | -------------------------------------------------------------- | ------ | ------ | --------------------------------- |
| 1   | Remove Darwin Go overlay from `darwin/default.nix`             | 2min   | Medium | Go version divergence             |
| 2   | Fix Darwin `shells.nix` double-imports                         | 3min   | Medium | Nix module warnings               |
| 3   | Remove `jq` from NixOS `home.packages` (duplicate of base.nix) | 1min   | Low    | Confusion                         |
| 4   | Reconcile `allowUnfree` (remove dead predicate OR enforce it)  | 5min   | Medium | False security confidence         |
| 5   | Add Hetzner SSH hosts to macOS `home.nix`                      | 5min   | High   | Can't access servers from MacBook |

### Priority 2: Service Enablement (Requires secrets)

| #   | Task                                                     | Effort | Impact | Risk if skipped          |
| --- | -------------------------------------------------------- | ------ | ------ | ------------------------ |
| 6   | Add Authelia secrets to `secrets.yaml` and enable module | 30min  | High   | No SSO                   |
| 7   | Add Immich OAuth secret and enable module                | 15min  | High   | No photo management      |
| 8   | Add Grafana secrets and enable module                    | 15min  | Medium | No monitoring dashboards |
| 9   | Fix Authelia hardcoded password → use sops-nix           | 10min  | Medium | Security risk            |
| 10  | Verify Caddy TLS certs work with enabled services        | 10min  | High   | HTTPS broken             |

### Priority 3: Architecture Consolidation

| #   | Task                                                   | Effort | Impact | Risk if skipped       |
| --- | ------------------------------------------------------ | ------ | ------ | --------------------- |
| 11  | Extract SSH hosts to common module (or nix-ssh-config) | 30min  | High   | Ongoing drift         |
| 12  | Extract color scheme options to common module          | 20min  | Medium | Divergence            |
| 13  | Move `gitui` to `common/packages/base.nix`             | 5min   | Low    | Missing tool on macOS |
| 14  | Consolidate Chrome policy definitions                  | 30min  | Medium | Policy drift          |
| 15  | Create `just sync-audit` command                       | 1hr    | High   | Manual audits only    |

### Priority 4: Quality & Testing

| #   | Task                                               | Effort | Impact | Risk if skipped       |
| --- | -------------------------------------------------- | ------ | ------ | --------------------- |
| 16  | Add CI cross-platform drift detection workflow     | 2hr    | High   | Silent drift          |
| 17  | Verify Darwin Chrome policies are actually applied | 15min  | Medium | Unenforced policies   |
| 18  | Add statix + deadnix to GitHub Actions             | 1hr    | Medium | Catch issues late     |
| 19  | Test NixOS build from macOS (remote deploy)        | 2hr    | Medium | Can't verify remotely |
| 20  | Create Home Manager test harness                   | 4hr    | High   | Manual testing only   |

### Priority 5: Documentation & Polish

| #   | Task                                                       | Effort | Impact | Risk if skipped        |
| --- | ---------------------------------------------------------- | ------ | ------ | ---------------------- |
| 21  | Update AGENTS.md for removed files and new modules         | 30min  | Medium | Stale documentation    |
| 22  | Document disabled services runbook                         | 20min  | Medium | Can't enable services  |
| 23  | Add ADR for preferences module                             | 15min  | Low    | Undocumented decisions |
| 24  | Document intentional vs unintentional platform differences | 30min  | Medium | Confusion              |
| 25  | Clean up `common/core/` references in docs                 | 10min  | Low    | Broken references      |

---

## G) TOP QUESTION I CANNOT ANSWER 🤔

**#1: Should the Hetzner SSH hosts be accessible from your MacBook?**

The 4 Hetzner servers (`private-cloud-hetzner-0` through `3`) are only in the NixOS config. I cannot determine if:

- **(a)** This is intentional — You only SSH to Hetzner from evo-x2 (jump host pattern, Hetzner servers are in a private network only accessible from your LAN)
- **(b)** This is an oversight — You want direct access from macOS too
- **(c)** You want a shared config — All SSH hosts in one place via `nix-ssh-config`

This determines: add them to Darwin, extract to shared module, or leave as-is.

---

## Changes Since Last Audit (2026-04-04 17:28)

| Change                                                     | Location                              | Status              |
| ---------------------------------------------------------- | ------------------------------------- | ------------------- |
| Cross-platform `preferences.nix` module                    | `common/preferences.nix`              | ✅ New              |
| Dark mode driven by preferences                            | `darwin/system/settings.nix`          | ✅ New              |
| Steam added to NixOS                                       | `nixos/programs/steam.nix`            | ✅ New              |
| Authelia module (disabled)                                 | `modules/nixos/services/authelia.nix` | ✅ New              |
| Helium Widevine CDM wrapping                               | `common/packages/base.nix`            | ✅ New              |
| Dagger CI/CD tool added                                    | `common/packages/base.nix`            | ✅ New              |
| Crush config as flake input                                | `flake.nix`                           | ✅ New              |
| treefmt-full-flake as formatter                            | `flake.nix`                           | ✅ New              |
| `UserConfig.nix`, `PathConfig.nix`, `security.nix` removed | `common/core/`                        | ✅ Cleaned          |
| Authelia, Immich, Grafana disabled                         | `flake.nix`                           | ⚠️ Awaiting secrets |
| `TODO_LIST.md` removed                                     | Root                                  | ✅ Cleaned          |
| PrimaryUser inlined in activation                          | `darwin/system/activation.nix`        | ✅ Simplified       |

---

_Audit completed at 2026-04-05 02:34 by Crush AI Agent_
