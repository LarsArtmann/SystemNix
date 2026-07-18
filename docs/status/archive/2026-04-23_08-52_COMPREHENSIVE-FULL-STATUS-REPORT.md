# SystemNix Comprehensive Status Report

**Date:** 2026-04-23 08:52
**Branch:** master (1 commit ahead of origin)
**Working Tree:** Clean (no uncommitted changes)
**Recent Activity:** 100 commits in the last 4 days (2026-04-19 → 2026-04-23)
**Total Nix Files:** 92
**Key Files:** flake.nix (561 lines), justfile (1961 lines), AGENTS.md (437 lines)

---

## A) FULLY DONE ✅

These systems are production-ready, hardened, and working reliably:

### Core Infrastructure

| Component                       | Status      | Details                                                                |
| ------------------------------- | ----------- | ---------------------------------------------------------------------- |
| **Flake Architecture**          | ✅ Complete | flake-parts modular design, 20+ inputs, dual-platform outputs          |
| **NixOS evo-x2 Config**         | ✅ Complete | AMD Ryzen AI Max+ 395, 128GB, BTRFS, systemd-boot                      |
| **Darwin MacBook Air**          | ✅ Complete | Apple Silicon, nix-darwin + Homebrew integration                       |
| **Cross-Platform Home Manager** | ✅ Complete | 14 shared program modules via `common/home-base.nix`                   |
| **SOPS Secrets Management**     | ✅ Complete | age/SSH key, centralized `sops.nix` with helper functions, 20+ secrets |
| **DNS Blocker Stack**           | ✅ Complete | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, DoQ enabled         |
| **Go 1.26 Overlay**             | ✅ Complete | Pinned Go toolchain on both platforms                                  |
| **Justfile**                    | ✅ Complete | 130+ recipes covering all operations, well-organized                   |

### NixOS Services (Production-Ready)

| Service                  | Module             | Hardening | Health Check     | Notes                                                                    |
| ------------------------ | ------------------ | --------- | ---------------- | ------------------------------------------------------------------------ |
| **Authelia SSO**         | `authelia.nix`     | ✅ Full   | ✅ ExecStartPost | TOTP + WebAuthn, OIDC provider (Immich + Gitea), file-based auth         |
| **Caddy Reverse Proxy**  | `caddy.nix`        | ✅ Full   | ✅ WatchdogSec   | Custom TLS, forward-auth, 10+ virtual hosts                              |
| **Gitea**                | `gitea.nix`        | ✅ Full   | ✅ Implicit      | SQLite, GitHub mirror sync, Actions runner, auto-token generation        |
| **Immich**               | `immich.nix`       | ✅ Full   | ✅ WatchdogSec   | Native NixOS, PostgreSQL tuned, Redis, ML, OAuth, daily backups          |
| **SigNoz Observability** | `signoz.nix`       | ✅ Full   | ✅ ExecStartPost | Built from source, ClickHouse, OTel collector, 7 alert rules, dashboards |
| **TaskChampion Sync**    | `taskchampion.nix` | ✅ Full   | ✅ WatchdogSec   | Native NixOS, localhost-only, snapshot config                            |
| **Homepage Dashboard**   | `homepage.nix`     | ✅ Full   | ✅ WatchdogSec   | Dedicated user, Nix-managed configs, service monitoring                  |
| **Minecraft Server**     | `minecraft.nix`    | ✅ Full   | ✅ WatchdogSec   | JDK 25, ZGC, declarative properties, local-only firewall                 |
| **Hermes AI Gateway**    | `hermes.nix`       | ✅✅ Best | —                | Strictest sandboxing (ProtectSystem, ProtectHome, MemoryMax 4G, UMask)   |
| **Docker Base**          | `default.nix`      | N/A       | N/A              | overlay2, weekly prune, `/data/docker` data-root                         |
| **Gitea Repo Sync**      | `gitea-repos.nix`  | —         | ✅ Pre-start     | Declarative repo mirroring, sops token management                        |
| **Monitor365**           | `monitor365.nix`   | ✅ Full   | —                | 14 collector types, ActivityWatch integration, memory-limited            |

### Desktop & Programs

| Component                     | Status      | Notes                                                                     |
| ----------------------------- | ----------- | ------------------------------------------------------------------------- |
| **Niri Compositor**           | ✅ Complete | Wrapped with baked config, session save/restore, crash recovery           |
| **Waybar**                    | ✅ Complete | Catppuccin Mocha, service status, EMEET camera indicator, seconds display |
| **SDDM + Silent-SDDM**        | ✅ Complete | Catppuccin themed login screen                                            |
| **Rofi / Swaylock / Wlogout** | ✅ Complete | All themed with Catppuccin Mocha                                          |
| **Zellij / Yazi**             | ✅ Complete | Modern terminal multiplexer + file manager                                |
| **Chromium Policies**         | ✅ Complete | Helium browser proxy config, OneTab extension                             |
| **Starship Prompt**           | ✅ Complete | Catppuccin colors, performance-optimized                                  |
| **Tmux**                      | ✅ Complete | Resurrect, Catppuccin, SystemNix keybindings                              |
| **Git**                       | ✅ Complete | GPG signing, LFS, HTTPS→SSH rewrite, bat pager                            |
| **FZF**                       | ✅ Complete | Ripgrep backend, shell integrations                                       |
| **KeePassXC**                 | ✅ Complete | Browser integration, platform-conditional manifests                       |
| **Taskwarrior 3**             | ✅ Complete | TaskChampion sync, derived UUIDs, Catppuccin theme                        |
| **Steam/Gaming**              | ✅ Complete | Firejail sandbox, local-only network                                      |

### Hardware

| Component                | Status      | Notes                                                             |
| ------------------------ | ----------- | ----------------------------------------------------------------- |
| **AMD GPU (Strix Halo)** | ✅ Complete | ROCm, VAAPI, DRI3, AMDGPU metrics via custom timer                |
| **AMD NPU (XDNA)**       | ✅ Complete | nix-amd-npu driver module                                         |
| **Bluetooth**            | ✅ Complete | Dual-mode, auto-power-on                                          |
| **EMEET PIXY Webcam**    | ✅ Complete | Custom Go daemon, HID control, Waybar integration, call detection |

### Dev Tools & Packages

| Component                       | Status      | Notes                                                                                  |
| ------------------------------- | ----------- | -------------------------------------------------------------------------------------- |
| **Go Toolchain**                | ✅ Complete | Full dev workflow: lint, format, modernize, test, build, debug                         |
| **Node/Bun Toolchain**          | ✅ Complete | oxlint, oxfmt, tsgolint, auto-detect package manager                                   |
| **70+ Cross-Platform Packages** | ✅ Complete | `packages/base.nix` with platform-conditional logic                                    |
| **Fonts**                       | ✅ Complete | 3 Nerd Fonts, Noto family, Bibata cursors                                              |
| **Custom Packages**             | ✅ Complete | dnsblockd, dnsblockd-processor, emeet-pixyd, modernize, jscpd, monitor365, openaudible |

### Observability Pipeline

| Layer          | Status      | Details                                                                   |
| -------------- | ----------- | ------------------------------------------------------------------------- |
| **Metrics**    | ✅ Complete | node_exporter, cAdvisor, Caddy, Authelia, dnsblockd, emeet-pixyd, AMD GPU |
| **Logs**       | ✅ Complete | journald receiver → OTel collector → ClickHouse                           |
| **Traces**     | ✅ Complete | OTLP receiver on ports 4317/4318                                          |
| **Dashboards** | ✅ Complete | Overview + SigNoz dashboards provisioned                                  |
| **Alerts**     | ✅ Complete | 7 rules: disk, CPU, memory, systemd, GPU thermal, dnsblockd, emeet-pixyd  |

---

## B) PARTIALLY DONE ⚠️

### Twenty CRM (`twenty.nix`)

- **What works:** Docker Compose deployment, PostgreSQL + Redis, healthchecks, daily backup, sops secrets
- **What's missing:**
  - Runs entirely in Docker (not native NixOS) — loses hardening benefits
  - No backup rotation/cleanup — only creates new backups
  - Backup script uses hardcoded container name `twenty-db-1` (fragile)
  - Partial hardening (missing NoNewPrivileges, ProtectSystem, MemoryMax)

### Voice Agents (`voice-agents.nix`)

- **What works:** LiveKit SFU with RTC ports, Whisper ASR via Docker, sops-managed keys, Caddy integration
- **What's missing:**
  - `pipecatPort = 8500` defined but never used
  - Whisper ASR has no health check
  - Image pinned to `latest` tag (unstable)
  - PIDFile declared but never created
  - No memory limit on GPU workloads

### ComfyUI (`comfyui.nix`)

- **What works:** ROCm GPU acceleration, HuggingFace cache on `/data`, force-fp16 mode
- **What's missing:**
  - Hardcoded path to `/home/lars/projects/anime-comic-pipeline/ComfyUI` — not portable
  - Runs as user `lars` (not dedicated system user) — weaker isolation
  - No WatchdogSec, no memory limit
  - Minimal hardening

### PhotoMap (`photomap.nix`)

- **What works:** OCI container, Immich media mounts, config auto-seeding, container health check
- **What's missing:**
  - Image pinned to `latest` tag
  - No dedicated user/group
  - No NoNewPrivileges

### uBlock Filters (`ublock-filters.nix`)

- **What works:** Module structure, filter management, auto-update timer framework
- **What's missing:**
  - **Entirely disabled** (`enable = false`) due to "time parsing issues" in LaunchAgent timer config
  - Linux timer just echoes a message — doesn't actually update
  - No actual browser integration (manual copy-paste required)

### Preferences Module (`preferences.nix`)

- **What works:** Options declared for theme variant, colors, accent, GTK, icons, cursor, fonts
- **What's missing:**
  - **No config implementation** — defines options but nothing consumes them
  - `tmux.nix` and `starship.nix` hardcode Catppuccin Mocha instead of reading from preferences
  - Not wired to actual GTK/Qt/theme settings

### Git Config (`git.nix`)

- **What works:** Comprehensive git setup, GPG, LFS, bat pager, aliases
- **What's missing:**
  - `core.pager = "cat"` overrides `pager.diff = "bat"` — bat diff never used
  - Duplicate entries in global ignores (.so, *~, *.log, target/)
  - GPG program path `/run/current-system/sw/bin/gpg` — NixOS-only, breaks on Darwin

### Bash Config (`bash.nix`)

- **What works:** Shared aliases, basic setup
- **What's missing:**
  - Very minimal — no history config, no completion, no HISTCONTROL, no shopt
  - Compared to Zsh, this is bare-bones

---

## C) NOT STARTED 🔲

1. **Authelia ↔ NixOS PAM integration** — discussed but no implementation. Currently two separate password stores.
2. **lldap or Kanidm identity management** — not started. Would unify Authelia + PAM auth.
3. **Email/SMTP for Authelia notifications** — currently using filesystem notifier (writes to `notification.txt`). No email on 2FA setup, password reset, etc.
4. **WireGuard/Tailscale VPN** — no VPN configuration for remote access to `home.lan` services.
5. **Automated backup verification** — backups exist (Immich daily, Twenty daily) but no restore testing or verification pipeline.
6. **GPU passthrough to VMs** — no libvirt/QEMU VM setup despite powerful hardware.
7. **NixOS tests** — no `nixosTests` in the flake. Testing is manual (`just test` = build validation only).
8. **Darwin CI/CD** — no CI pipeline for the darwin configuration.
9. **Fontconfig tuning** — no hinting, antialiasing, or default font mapping beyond package installation.
10. **Home Manager `programs.ssh` migration** — `ssh-config.nix` uses custom module instead of standard HM `programs.ssh.matchBlocks`.
11. **Pre-commit modernization** — uses deprecated `nixpkgs-fmt` instead of `nixfmt-rfc-style`.
12. **DNS-over-HTTPS upstream** — Unbound uses DoT (Quad9) + DoQ but no DoH fallback.

---

## D) TOTALLY FUCKED UP 💥

### 1. Taskwarrior "Encryption" is Not Secret

- **File:** `platforms/common/programs/taskwarrior.nix`
- **Problem:** `syncEncryptionSecret` is derived from `sha256("taskchampion-sync-encryption-systemnix")` — this string is in the public repo. Anyone can decrypt synced tasks.
- **Impact:** Task data synced via TaskChampion is effectively unencrypted.
- **Fix:** Move the encryption secret to sops-nix.

### 2. SSH Host IPs in Plaintext

- **File:** `platforms/common/programs/ssh-config.nix`
- **Problem:** Hardcoded IP addresses for private cloud servers (onprem, evo-x2, Hetzner).
- **Impact:** Infrastructure exposure in public repo.
- **Fix:** Move IPs to sops secrets or use DNS names.

### 3. ComfyUI Hardcoded Local Paths

- **File:** `modules/nixos/services/comfyui.nix`
- **Problem:** Points to `/home/lars/projects/anime-comic-pipeline/ComfyUI` and its venv Python. Not reproducible, not portable.
- **Impact:** Breaks if directory moved or on another machine. Completely violates Nix philosophy.
- **Fix:** Package ComfyUI properly as a Nix derivation or use nix-shell/pip.

### 4. Gitea-Ensure-Repos Has Zero Hardening

- **File:** `modules/nixos/services/gitea-repos.nix`
- **Problem:** No PrivateTmp, NoNewPrivileges, ProtectSystem, MemoryMax — nothing. The only service module with zero hardening.
- **Impact:** If compromised, full system access.
- **Fix:** Add standard hardening directives like other services.

### 5. Docker Images Not Pinned (Twenty, Voice Agents, PhotoMap)

- **Files:** `twenty.nix`, `voice-agents.nix`, `photomap.nix`
- **Problem:** Images use `latest` tag or unpinned digests. No reproducibility.
- **Impact:** Silent breakage on redeployment. Cannot rollback.
- **Fix:** Pin to specific image digests.

### 6. `fonts.packages` Used Cross-Platform

- **File:** `platforms/common/packages/fonts.nix`
- **Problem:** Uses `fonts.packages` which is a NixOS-level option. May cause eval errors on darwin.
- **Impact:** Potential build failures on macOS.
- **Fix:** Guard with `lib.mkIf pkgs.stdenv.isLinux` or use platform-conditional import.

---

## E) WHAT WE SHOULD IMPROVE 📈

### High Priority

1. **Preferences Module → Actual Theming** — The `preferences.nix` options module is dead code. Wire it to GTK, Qt, cursor, icon, and font settings. Make `tmux.nix`, `starship.nix`, etc. read from it.

2. **Taskwarrior Encryption via sops** — The "encryption" secret is public. Move to sops immediately.

3. **Service Hardening Consistency** — `gitea-ensure-repos`, `twenty-db-backup`, `comfyui`, and `whisper-asr` have missing or minimal hardening. Standardize all services to the `hermes.nix` level.

4. **Docker Image Pinning** — All Docker-based services (Twenty, Voice Agents, PhotoMap) should pin to specific image digests, not `latest`.

5. **uBlock Filters Module** — Fix the time parsing bug and re-enable, or remove the dead module entirely.

6. **SSH Config Migration** — Move from custom `ssh-config.nix` to standard Home Manager `programs.ssh.matchBlocks`. Move IPs to sops.

### Medium Priority

7. **ComfyUI Packaging** — Replace hardcoded local paths with proper Nix derivation.

8. **Authelia Notifications** — Add SMTP (or at least gotify/pushover) so 2FA setup/password reset actually notifies users.

9. **Backup Verification** — Add restore testing. Immich and Twenty have backup scripts but no verification.

10. **Pre-commit Modernization** — Replace deprecated `nixpkgs-fmt` with `nixfmt-rfc-style`.

11. **Git Config Cleanup** — Fix `core.pager` vs `pager.diff` conflict, remove duplicate ignores, fix Darwin GPG path.

12. **Bash Config Enhancement** — Add history, completion, and shopt settings to match zsh quality.

13. **Justfile Deduplication** — `validate` ≈ `check-nix-syntax`, `switch` ≈ `deploy`, `dep-graph svg` ≈ `dep-graph darwin`. Consolidate.

14. **Monitor Package Cleanup** — 4 system monitors (`bottom`, `procs`, `btop`, `htop`). Pick 1-2.

15. **NixOS Tests** — Add `nixosTests` for at least the critical services (Authelia, Caddy, DNS blocker).

### Low Priority

16. **Fontconfig Configuration** — Add hinting, antialiasing, and default font mapping.

17. **Fish Shell Fixes** — `$GOPATH` may be empty at init time, `fish_history_size` is not a real variable.

18. **Environment Variable Cleanup** — Triple locale redundancy (`variables.nix`, `fish.nix`, `home-base.nix`).

19. **Shell Aliases Modernization** — `l = "ls -laSh"` should use `eza` since it's installed. `kop = "keepassxc &"` may not work in all shells.

20. **Documentation Cleanup** — 200+ status reports in `docs/status/` (archive + current). Many are redundant. Consider periodic pruning.

21. **Darwin `darwin-version` in justfile** — `check` and `info` recipes call `darwin-version` without platform guards.

22. **Allow Unsupported Systems** — `allowUnsupportedSystem = true` in nix-settings may mask real build issues.

23. **Netrc File** — `netrc-file = /etc/nix/netrc` referenced but never validated as existing.

24. **Unfree Allowlist Cleanup** — `signal-desktop-bin`, `castlabs-electron`, `cursor` in unfree list but not installed.

25. **LC_ALL Override** — `LC_ALL = "en_US.UTF-8"` overrides all other locale settings. Redundant with `LANG`.

---

## F) Top 25 Things to Do Next (Ranked by Impact × Effort)

| #   | Task                                                                              | Impact    | Effort | Category        |
| --- | --------------------------------------------------------------------------------- | --------- | ------ | --------------- |
| 1   | Wire `preferences.nix` to actual GTK/Qt/cursor/font theming                       | 🔴 High   | Medium | Consistency     |
| 2   | Move Taskwarrior encryption secret to sops-nix                                    | 🔴 High   | Low    | Security        |
| 3   | Add standard hardening to `gitea-ensure-repos` service                            | 🟡 Medium | Low    | Security        |
| 4   | Pin Docker image digests for Twenty, Voice Agents, PhotoMap                       | 🟡 Medium | Low    | Reproducibility |
| 5   | Fix `core.pager` vs `pager.diff` conflict in git.nix                              | 🟡 Medium | Low    | Quality         |
| 6   | Add WatchdogSec + memory limit to ComfyUI service                                 | 🟡 Medium | Low    | Reliability     |
| 7   | Remove dead `ublock-filters.nix` or fix and re-enable                             | 🟡 Medium | Medium | Cleanup         |
| 8   | Add Authelia SMTP notifications (or push notifications)                           | 🟡 Medium | Medium | UX              |
| 9   | Replace `nixpkgs-fmt` with `nixfmt-rfc-style` in pre-commit                       | 🟢 Low    | Low    | Modernization   |
| 10  | Consolidate duplicate justfile recipes (validate/check-nix-syntax, switch/deploy) | 🟢 Low    | Low    | Cleanup         |
| 11  | Move SSH host IPs to sops secrets                                                 | 🟡 Medium | Medium | Security        |
| 12  | Add backup rotation to Twenty CRM                                                 | 🟡 Medium | Low    | Reliability     |
| 13  | Remove or fix `fonts.packages` darwin compatibility                               | 🟡 Medium | Low    | Cross-platform  |
| 14  | Add `MANPAGER`, `VISUAL` environment variables                                    | 🟢 Low    | Low    | Quality         |
| 15  | Package ComfyUI as proper Nix derivation                                          | 🔴 High   | High   | Reproducibility |
| 16  | Trim system monitors from 4 to 2 (`btop` + one other)                             | 🟢 Low    | Low    | Cleanup         |
| 17  | Fix Fish `$GOPATH` init timing and fake history variables                         | 🟢 Low    | Low    | Quality         |
| 18  | Add `compinit` tuning and custom completions to zsh                               | 🟢 Low    | Medium | Quality         |
| 19  | Enhance bash config with history, completion, shopt                               | 🟢 Low    | Medium | Quality         |
| 20  | Add health check to Hermes service                                                | 🟡 Medium | Low    | Observability   |
| 21  | Add health check to Voice Agents whisper-asr                                      | 🟡 Medium | Low    | Observability   |
| 22  | Prune 200+ redundant status reports in docs/status/                               | 🟢 Low    | Low    | Cleanup         |
| 23  | Add basic NixOS tests for Authelia + Caddy + DNS blocker                          | 🟡 Medium | High   | Testing         |
| 24  | Clean up unfree allowlist (remove unused entries)                                 | 🟢 Low    | Low    | Cleanup         |
| 25  | Investigate lldap/Kanidm for unified Authelia + PAM auth                          | 🔴 High   | High   | Architecture    |

---

## G) Top #1 Question I Cannot Answer Myself

**What is the intended future of the `preferences.nix` module?**

It declares comprehensive options for theme variant, color scheme, accent, density, GTK theme, icon theme, cursor, and fonts — but **nothing consumes these options**. Meanwhile, `tmux.nix`, `starship.nix`, and other modules hardcode `catppuccin-mocha` directly. There are two possible paths:

1. **Wire it up properly** — Make all themed modules read from `config.preferences.appearance.*`. This would make the entire desktop theme switchable from a single location (e.g., swap to Catppuccin Latte for light mode). This is the "right" approach but requires touching 10+ files.

2. **Delete it** — If Catppuccin Mocha is the permanent theme, the options module is dead code adding complexity. Remove it and keep the hardcoded references.

Which direction do you want? This decision affects many downstream files and I don't want to start wiring without your intent.

---

## System Health Summary

```
Services:       17 modules (11 ✅ production, 4 ⚠️ partial, 2 utility)
Hardening:      13/15 hardened (2 gaps: gitea-ensure-repos, comfyui minimal)
Health Checks:  9/15 with health checks
Observability:  Full stack (SigNoz + metrics + logs + traces + alerts)
Security:       Good (sops-nix, 2FA, forward-auth, systemd sandboxing)
                Gaps: taskwarrior "encryption" is public, SSH IPs exposed
Cross-platform: Strong (~80% shared config)
Documentation:  Comprehensive (AGENTS.md, justfile 130+ recipes)
                Gap: 200+ status reports creating noise
Testing:        Manual only (just test = build validation)
```

---

_Generated by Crush AI Agent on 2026-04-23 at 08:52_
