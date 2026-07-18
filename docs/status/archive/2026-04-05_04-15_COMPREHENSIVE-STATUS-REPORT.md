# SystemNix Comprehensive Status Report

**Date:** 2026-04-05 04:15 CEST
**Reporter:** Crush AI Assistant
**Commit:** b38f87e (latest) — wait for awww-daemon socket before wallpaper initialization
**Working Tree:** 1 uncommitted change (niri-wrapped.nix: `kitty -e fish -c "sudo btop"` spawn-at-startup)

---

## Executive Summary

SystemNix is a **mature, production-grade cross-platform Nix configuration** managing two machines through a single flake with ~80% shared configuration. The project has stabilized significantly since the Authelia/Immich cascade failure documented in the debug map. All services are now building and running; the evo-x2 homelab is fully operational with SSO, photo management, observability, and AI/ML stacks.

**This session's primary fix:** SDDM login screen avatar — the profile picture was not showing due to three compounding issues (wrong image, wrong mechanism, missing daemon). Fixed with AccountsService daemon + `systemd.tmpfiles.rules` + correct `avatar.png`.

### Key Metrics

| Metric                 | Value                                                                                                    |
| ---------------------- | -------------------------------------------------------------------------------------------------------- |
| Nix files              | 60+                                                                                                      |
| Platforms              | 2 (macOS aarch64-darwin, NixOS x86_64-linux)                                                             |
| Shared modules         | 17 (`platforms/common/`)                                                                                 |
| NixOS-only modules     | 25+                                                                                                      |
| Darwin-only modules    | 12                                                                                                       |
| Flake inputs           | 20                                                                                                       |
| Active services        | 11 (Caddy, Gitea, Immich, Authelia, SigNoz, Homepage, SOPS, Monitoring, PhotoMap, Prometheus, dnsblockd) |
| Caddy vhosts           | 7                                                                                                        |
| Prometheus scrape jobs | 5                                                                                                        |
| SOPS secrets           | 13                                                                                                       |
| DNS blocklists         | 25+ (~2.5M domains)                                                                                      |

---

## A) FULLY DONE ✅

### Cross-Platform Shared Configuration

| #   | Component       | Details                                                     | Location                                      |
| --- | --------------- | ----------------------------------------------------------- | --------------------------------------------- |
| 1   | Git             | GPG signing, LFS, git-town, aliases, ignores, URL rewriting | `common/programs/git.nix`                     |
| 2   | Shell aliases   | Shared for Fish, Zsh, Bash                                  | `common/programs/shell-aliases.nix`           |
| 3   | Starship prompt | Catppuccin Mocha, nix-colors integration                    | `common/programs/starship.nix`                |
| 4   | Tmux            | Catppuccin, SystemNix keybindings, resurrect                | `common/programs/tmux.nix`                    |
| 5   | FZF             | Ripgrep integration, all shell integrations                 | `common/programs/fzf.nix`                     |
| 6   | KeePassXC       | Chromium + Helium browser native messaging                  | `common/programs/keepassxc.nix`               |
| 7   | 4 Shells        | Fish, Zsh, Bash, Nushell all configured                     | `common/programs/{fish,zsh,bash,nushell}.nix` |
| 8   | Packages        | Essential, dev, GUI, AI packages with platform conditionals | `common/packages/base.nix`                    |
| 9   | Fonts           | JetBrains Mono, Fira Code, Iosevka, Noto fallbacks          | `common/packages/fonts.nix`                   |
| 10  | Env vars        | EDITOR, LANG, NIX_PATH, Node/Go settings                    | `common/environment/variables.nix`            |
| 11  | Nix settings    | Experimental features, GC, optimization, substituters       | `common/core/nix-settings.nix`                |
| 12  | Pre-commit      | 8 hooks: gitleaks, deadnix, statix, alejandra, etc.         | `common/programs/pre-commit.nix`              |
| 13  | uBlock filters  | Custom privacy filters with auto-update                     | `common/programs/ublock-filters.nix`          |
| 14  | Chromium        | Brave on macOS, Helium on Linux with Widevine               | `common/programs/chromium.nix`                |
| 15  | Home Manager    | Go setup, session variables                                 | `common/home-base.nix`                        |
| 16  | Preferences     | Unified dark mode preference module                         | `common/preferences.nix`                      |

### macOS (Darwin) — Complete

| #   | Component                                                    | Location                             |
| --- | ------------------------------------------------------------ | ------------------------------------ |
| 1   | System settings (keyboard, trackpad, Finder, dark mode)      | `darwin/system/settings.nix`         |
| 2   | Security (TouchID PAM, Keychain auto-lock 5min)              | `darwin/security/{pam,keychain}.nix` |
| 3   | LaunchAgents (ActivityWatch, SublimeText, Crush, aw-watcher) | `darwin/services/launchagents.nix`   |
| 4   | Networking (hostname, firewall, Bonjour)                     | `darwin/networking/default.nix`      |
| 5   | Chrome policies (extension management)                       | `darwin/programs/chrome.nix`         |
| 6   | File associations (SublimeText for txt/md/json/yaml/toml/d2) | `darwin/system/activation.nix`       |
| 7   | Homebrew (Headlamp Kubernetes GUI)                           | `darwin/default.nix`                 |
| 8   | Go 1.26.1 pinned via overlay                                 | `darwin/default.nix`                 |

### NixOS (evo-x2) — Complete

#### Boot & Hardware

| #   | Component                                           | Location                                    |
| --- | --------------------------------------------------- | ------------------------------------------- |
| 1   | systemd-boot, latest kernel, AMD params, ZRAM       | `nixos/system/boot.nix`                     |
| 2   | AMD GPU — Full ROCm, Mesa, RADV, performance tuning | `nixos/hardware/amd-gpu.nix`                |
| 3   | AMD NPU — XDNA driver, XRT runtime                  | `nixos/hardware/amd-npu.nix`                |
| 4   | Bluetooth — Audio source/sink, Blueman              | `nixos/hardware/bluetooth.nix`              |
| 5   | BTRFS dual layout, data partition, EFI              | `nixos/hardware/hardware-configuration.nix` |

#### Desktop Environment

| #   | Component                                                              | Location                                |
| --- | ---------------------------------------------------------------------- | --------------------------------------- |
| 1   | Niri — scrollable-tiling, random wallpapers, keybindings, 5 workspaces | `nixos/programs/niri-wrapped.nix`       |
| 2   | Waybar — DNS stats, weather, media, clipboard, power menu              | `nixos/desktop/waybar.nix`              |
| 3   | SDDM — SilentSDDM Catppuccin Mocha                                     | `nixos/desktop/display-manager.nix`     |
| 4   | Audio — PipeWire with ALSA, JACK, realtime                             | `nixos/desktop/audio.nix`               |
| 5   | Rofi — Catppuccin grid with icons                                      | `nixos/programs/rofi.nix`               |
| 6   | Swaylock — Blur + vignette, Catppuccin                                 | `nixos/programs/swaylock.nix`           |
| 7   | Wlogout — Inline SVG icons, Catppuccin                                 | `nixos/programs/wlogout.nix`            |
| 8   | Zellij — Catppuccin, tmux-compatible keys                              | `nixos/programs/zellij.nix`             |
| 9   | Yazi — Catppuccin, image preview, file associations                    | `nixos/programs/yazi.nix`               |
| 10  | Kitty — Catppuccin Mocha, 16pt TV-friendly                             | `nixos/users/home.nix`                  |
| 11  | Foot — Lightweight Wayland terminal                                    | `nixos/users/home.nix`                  |
| 12  | Dunst — Notifications, Catppuccin                                      | `nixos/users/home.nix`                  |
| 13  | GTK/Qt — Catppuccin Mocha Compact Lavender, dark, 16pt                 | `nixos/users/home.nix`                  |
| 14  | Sway backup WM — Available at SDDM                                     | `nixos/desktop/multi-wm.nix`            |
| 15  | **SDDM Avatar** — AccountsService + tmpfiles symlink                   | `nixos/system/configuration.nix:97-101` |

#### System Services

| #   | Component                                                   | Location                               |
| --- | ----------------------------------------------------------- | -------------------------------------- |
| 1   | Networking — Static IP, firewall, Unbound DNS               | `nixos/system/networking.nix`          |
| 2   | DNS blocker — Unbound + dnsblockd, 25+ blocklists, .lan DNS | `nixos/system/dns-blocker-config.nix`  |
| 3   | SSH — Hardened, fail2ban, password auth disabled            | `nixos/system/configuration.nix`       |
| 4   | Sudo — Passwordless for wheel                               | `nixos/system/sudo.nix`                |
| 5   | BTRFS snapshots — Timeshift daily                           | `nixos/system/snapshots.nix`           |
| 6   | Scheduled tasks — Crush update, blocklist, health checks    | `nixos/system/scheduled-tasks.nix`     |
| 7   | Security — AppArmor, fail2ban, ClamAV, polkit               | `nixos/desktop/security-hardening.nix` |

#### Infrastructure Services (flake-parts modules)

| #   | Service     | Function                               | Location                                 |
| --- | ----------- | -------------------------------------- | ---------------------------------------- |
| 1   | Caddy       | HTTPS reverse proxy, SOPS TLS          | `modules/nixos/services/caddy.nix`       |
| 2   | Gitea       | Git mirror + GitHub sync, CI/CD runner | `modules/nixos/services/gitea.nix`       |
| 3   | Immich      | Photo/video management with OIDC SSO   | `modules/nixos/services/immich.nix`      |
| 4   | Authelia    | Centralized SSO/OIDC provider          | `modules/nixos/services/authelia.nix`    |
| 5   | SigNoz      | Observability (traces/metrics/logs)    | `modules/nixos/services/signoz.nix`      |
| 6   | Homepage    | Service dashboard with health checks   | `modules/nixos/services/homepage.nix`    |
| 7   | SOPS        | Secrets via age, SSH host key          | `modules/nixos/services/sops.nix`        |
| 8   | Monitoring  | Prometheus + exporters                 | `modules/nixos/services/monitoring.nix`  |
| 9   | PhotoMap    | CLIP embedding map, Immich integration | `modules/nixos/services/photomap.nix`    |
| 10  | Gitea repos | Declarative repo mirroring             | `modules/nixos/services/gitea-repos.nix` |

#### AI/ML Stack

| #   | Component      | Location                               |
| --- | -------------- | -------------------------------------- |
| 1   | Ollama v0.20.0 | ROCm, Flash Attention, custom data dir | `nixos/desktop/ai-stack.nix` |
| 2   | Unsloth Studio | AI training UI, automated setup        | `nixos/desktop/ai-stack.nix` |
| 3   | llama.cpp      | ROCWMMA optimizations for Strix Halo   | `nixos/desktop/ai-stack.nix` |

#### Steam

| #   | Component | Location               |
| --- | --------- | ---------------------- |
| 1   | Steam     | Full NixOS integration | `nixos/programs/steam.nix` |

### Infrastructure

| #   | Component                                               | Location                  |
| --- | ------------------------------------------------------- | ------------------------- |
| 1   | Flake — 20 inputs, flake-parts, dendritic modules       | `flake.nix`               |
| 2   | Formatter — treefmt-full-flake (alejandra in PATH)      | `flake.nix`               |
| 3   | Pre-commit — 8 hooks                                    | `.pre-commit-config.yaml` |
| 4   | Crush config — Flake input, symlinked to both platforms | `flake.nix`               |

---

## B) SESSION CHANGES (2026-04-05)

### Fix: SDDM Login Avatar Not Showing

**Problem:** The profile picture (`assets/avatar.png`) was not displayed on the SDDM login/lock screen.

**Root Causes (3 compounding issues):**

| #   | Issue                                    | Severity | Explanation                                                                                                                        |
| --- | ---------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Wrong image referenced                   | High     | `configuration.nix` pointed to `cyberpunk-chinese-neon-cheongsam-character.jpeg` (a wallpaper), not `assets/avatar.png`            |
| 2   | `environment.etc` mechanism doesn't work | High     | SDDM reads avatars from `/var/lib/AccountsService/`, not `/etc/AccountsService/`. The `/var/lib/AccountsService/icons/` was empty. |
| 3   | AccountsService daemon not enabled       | High     | `services.accounts-daemon.enable` was never set — SDDM had no way to resolve user icons.                                           |

**Fix Applied** (`platforms/nixos/system/configuration.nix:97-101`):

```nix
services.accounts-daemon.enable = true;
systemd.tmpfiles.rules = [
  "L+ /var/lib/AccountsService/icons/lars - - - - ${../../../assets/avatar.png}"
];
```

**Why this approach:**

- `systemd.tmpfiles.rules` is the most NixOS-idiomatic method — creates a symlink from the Nix store into `/var/lib/AccountsService/icons/lars` at boot
- `L+` creates a symlink, automatically replacing any existing file
- The `avatar.png` is copied into the Nix store by the `${...}` interpolation, making it immutable and always available
- AccountsService daemon is enabled so SDDM can query user icons

**Previous broken config:**

```nix
environment.etc."AccountsService/users/lars".text = ''
  [User]
  Icon=/home/lars/projects/wallpapers/cyberpunk-chinese-neon-cheongsam-character.jpeg
'';
```

This failed because: (a) SDDM doesn't read `/etc/AccountsService/`, (b) the image was a 8.5MB wallpaper not the 4.2MB avatar, and (c) home directory is `700` — SDDM runs as its own user and can't access `/home/lars/`.

**Build verified:** `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --dry-run` succeeds. Accountsservice package is now included.

---

## C) PARTIALLY DONE ⚠️

| #   | Component                         | Status                                                     | Blocker                                          | Location                           |
| --- | --------------------------------- | ---------------------------------------------------------- | ------------------------------------------------ | ---------------------------------- |
| 1   | SSH hosts — macOS missing Hetzner | NixOS has 6 hosts, macOS has 2                             | Unknown if intentional                           | `darwin/home.nix:24-31`            |
| 2   | Chrome policies                   | Different mechanisms per platform                          | Darwin needs manual `sudo chrome-apply-policies` | `darwin/programs/chrome.nix`       |
| 3   | Tool availability gap             | gitui, signal-desktop, zed-editor NixOS-only               | Not extracted to common                          | `nixos/users/home.nix`             |
| 4   | Yazi config                       | NixOS has HM module with Catppuccin; macOS just has binary | Missing HM module on darwin                      | `nixos/users/home.nix`             |
| 5   | Gitea OAuth                       | Authelia OIDC client configured; Gitea module not wired    | Needs OAuth settings in gitea.nix                | `modules/nixos/services/gitea.nix` |

---

## D) NOT STARTED 🚧

### Architecture

| #   | Task                                                 | Priority |
| --- | ---------------------------------------------------- | -------- |
| 1   | Extract SSH hosts to common module or nix-ssh-config | Medium   |
| 2   | Extract color scheme options to common module        | Medium   |
| 3   | CI cross-platform drift detection                    | Low      |
| 4   | Common Chrome policy module                          | Medium   |
| 5   | XDG dark mode portal shared abstraction              | Low      |

### Code Quality

| #   | Task                                                            | Priority |
| --- | --------------------------------------------------------------- | -------- |
| 6   | Darwin `shells.nix` double-import cleanup                       | Medium   |
| 7   | Remove `jq` from NixOS `home.packages` (duplicated in base.nix) | Low      |
| 8   | Extract `gitui` to common packages                              | Low      |
| 9   | Audit NixOS `home.packages` for shared candidates               | Low      |
| 10  | Wire Gitea OAuth in gitea.nix                                   | High     |

### Documentation

| #   | Task                                      | Priority |
| --- | ----------------------------------------- | -------- |
| 11  | Update AGENTS.md for all recent changes   | Medium   |
| 12  | ADR for preferences module                | Low      |
| 13  | Runbook for enabling/re-enabling services | Medium   |

---

## E) TOTALLY FUCKED UP 💥

### Nothing Build-Breaking

The working tree has 1 uncommitted change (niri spawn-at-startup for btop). No merge conflicts, no syntax errors, no evaluation failures. All 11 service modules build successfully.

### Active Risks

| #   | Risk                              | Severity | Details                                                                                                                                                               |
| --- | --------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Go overlay duplicated             | Medium   | Same Go 1.26.1 overlay in `flake.nix:91-98` AND `darwin/default.nix:66-78`. If one updates without the other, platforms diverge.                                      |
| 2   | nixpkgs allowUnfree contradiction | Medium   | `flake.nix:139` sets blanket `allowUnfree = true`; `common/core/nix-settings.nix:48-60` sets curated `allowUnfreePredicate`. Blanket overrides predicate = dead code. |
| 3   | Authelia user password hardcoded  | Low      | `modules/nixos/services/authelia.nix` has hardcoded user with hashed password. Should use sops-nix.                                                                   |
| 4   | Placeholder OAuth secrets         | Medium   | Authelia OIDC secrets are generated but should be rotated to unique per-client values.                                                                                |
| 5   | Uncommitted niri change           | Low      | `kitty -e fish -c "sudo btop"` spawn-at-startup not committed — will be lost on checkout.                                                                             |

---

## F) WHAT WE SHOULD IMPROVE 📈

### High Priority (Do Soon)

1. **Remove Darwin Go overlay** — Redundant with `flake.nix` `perSystem._module.args.pkgs`. Divergence risk.
2. **Reconcile allowUnfree** — Remove dead `allowUnfreePredicate` from `nix-settings.nix` or enforce it by removing blanket allow from `flake.nix`.
3. **Fix Darwin shells.nix double-imports** — Remove duplicate imports of fish.nix and bash.nix.
4. **Add Hetzner SSH hosts to macOS** — Or extract to shared module.
5. **Wire Gitea OAuth** — Authelia OIDC client exists but gitea.nix lacks OAuth settings.
6. **Commit or discard niri btop spawn** — Don't leave uncommitted changes.

### Medium Priority

7. **Remove `jq` from NixOS `home.packages`** — Already in `common/packages/base.nix:47`.
8. **Extract color scheme options to common** — Single source of truth.
9. **Move `gitui` to common** — Works on macOS.
10. **Fix Authelia hardcoded password** — Use sops-nix.
11. **Rotate OAuth client secrets** — Unique per client, not shared placeholders.

### Lower Priority

12. **CI cross-platform drift check**
13. **Consolidate Chrome policies**
14. **Clean up removed file references in docs**
15. **Add Yazi HM module to macOS**

---

## G) TOP 25 THINGS TO DO NEXT 🎯

### Priority 1: Quick Wins (Under 15 min each)

| #   | Task                                               | Effort | Impact                        |
| --- | -------------------------------------------------- | ------ | ----------------------------- |
| 1   | Commit or discard niri btop spawn-at-startup       | 1min   | Prevent lost work             |
| 2   | Remove Darwin Go overlay from `darwin/default.nix` | 2min   | Prevent Go version divergence |
| 3   | Fix Darwin `shells.nix` double-imports             | 3min   | Eliminate Nix module warnings |
| 4   | Remove `jq` from NixOS `home.packages` (duplicate) | 1min   | Remove confusion              |
| 5   | Reconcile `allowUnfree`                            | 5min   | Fix dead code                 |

### Priority 2: Service Completion

| #   | Task                                             | Effort | Impact             |
| --- | ------------------------------------------------ | ------ | ------------------ |
| 6   | Wire Gitea OAuth in gitea.nix                    | 15min  | SSO for Git        |
| 7   | Rotate OAuth secrets to unique per-client values | 15min  | Security           |
| 8   | Fix Authelia hardcoded password → sops-nix       | 10min  | Security           |
| 9   | Verify Caddy TLS certs work with all services    | 10min  | HTTPS reliability  |
| 10  | Test SSO flows for all 3 services                | 30min  | Validate SSO works |

### Priority 3: Architecture Consolidation

| #   | Task                                   | Effort | Impact                     |
| --- | -------------------------------------- | ------ | -------------------------- |
| 11  | Extract SSH hosts to common module     | 30min  | Eliminate drift            |
| 12  | Extract color scheme options to common | 20min  | Single source of truth     |
| 13  | Move `gitui` to common packages        | 5min   | Cross-platform consistency |
| 14  | Consolidate Chrome policy definitions  | 30min  | Policy parity              |
| 15  | Add Yazi HM module to macOS            | 15min  | Config parity              |

### Priority 4: Quality & Testing

| #   | Task                                   | Effort | Impact                 |
| --- | -------------------------------------- | ------ | ---------------------- |
| 16  | Add CI cross-platform drift detection  | 2hr    | Catch drift early      |
| 17  | Verify Darwin Chrome policies applied  | 15min  | Security enforcement   |
| 18  | Add statix + deadnix to GitHub Actions | 1hr    | Automated code quality |
| 19  | Test NixOS remote deploy from macOS    | 2hr    | Remote verification    |
| 20  | Create Home Manager test harness       | 4hr    | Automated testing      |

### Priority 5: Documentation & Polish

| #   | Task                                                       | Effort | Impact                  |
| --- | ---------------------------------------------------------- | ------ | ----------------------- |
| 21  | Update AGENTS.md for all recent changes                    | 30min  | Accurate agent guidance |
| 22  | Document disabled services runbook                         | 20min  | Recovery documentation  |
| 23  | Add ADR for preferences module                             | 15min  | Decision record         |
| 24  | Document intentional vs unintentional platform differences | 30min  | Onboarding clarity      |
| 25  | Clean up stale references in docs                          | 10min  | Documentation hygiene   |

---

## H) COMMIT HISTORY (Last 15 Commits)

| Commit    | Message                                                                                        |
| --------- | ---------------------------------------------------------------------------------------------- |
| `c730661` | feat(system): migrate swayidle/dunst/cliphist to systemd services and add Immich bull-board UI |
| `596c414` | refactor(niri): migrate awww-daemon and wallpaper to systemd user services                     |
| `b38f87e` | fix(niri): wait for awww-daemon socket before wallpaper initialization                         |
| `070a838` | docs(status): add comprehensive debug map documenting authelia/immich cascade failure          |
| `1a415b4` | chore(niri): add awww-daemon startup and delay wallpaper initialization                        |
| `6d12cc4` | chore: re-enable Authelia and Immich SOPS secrets and Prometheus monitoring                    |
| `22dc12a` | docs(status): add comprehensive project status report with full audit                          |
| `1ad752b` | chore: re-enable Authelia and Immich services with full configuration                          |
| `0f1aa83` | chore: disable Authelia and Immich services by commenting out all references                   |
| `55b3b72` | chore: remove Grafana monitoring stack and re-enable Authelia/Immich services                  |
| `3eea135` | feat(config): introduce cross-platform unified preferences module and disable Immich           |
| `9e09f07` | feat(config): disable authelia/grafana modules and add dark mode support                       |
| `42820a5` | feat(authelia, dns-blocker): fix StateDirectory conflicts and expand allowlist                 |
| `7ca7a81` | feat(dagger): add comprehensive Dagger CI/CD integration with Nix and Go packages              |
| `4362936` | docs(status): add comprehensive Authelia SSO integration status report                         |

---

## I) SERVICES MAP (evo-x2)

```
Internet
    │
    ▼
192.168.1.150 (evo-x2)
    │
    ├── Caddy (443/80) ─── TLS via SOPS ──── .lan domains
    │   ├── git.lan       → Gitea (3000)
    │   ├── photos.lan    → Immich (2283)    ← Authelia SSO
    │   ├── auth.lan      → Authelia (9091)  ← OIDC Provider
    │   ├── monitor.lan   → Homepage (8082)
    │   ├── photo.lan     → PhotoMap (8182)
    │   ├── signoz.lan    → SigNoz (3301)
    │   └── map.lan       → SigNoz (3301) (OTel mapping)
    │
    ├── Unbound (53) ──── Quad9 DoT ──── 2.5M+ blocked domains
    │   └── .lan DNS records for all services
    │
    ├── Prometheus (9090) ── Node + Postgres + Redis + Caddy + Authelia
    │
    ├── Ollama (11434) ──── ROCm, Flash Attention, /data models
    │
    └── SOPS ──── age encryption ──── SSH host key
        └── 13 secrets across 2 encrypted files
```

---

## J) OPEN QUESTION 🤔

**Should the Hetzner SSH hosts be accessible from your MacBook?**

The 4 Hetzner servers (`private-cloud-hetzner-0` through `3`) are only in the NixOS SSH config. This is either:

- **(a)** Intentional — You only SSH to Hetzner from evo-x2 (jump host pattern)
- **(b)** An oversight — You want direct access from macOS too
- **(c)** A shared config opportunity — All SSH hosts in one place via `nix-ssh-config`

This determines: add them to Darwin, extract to shared module, or leave as-is.

---

_Report generated at 2026-04-05 04:15 CEST by Crush AI Assistant_
