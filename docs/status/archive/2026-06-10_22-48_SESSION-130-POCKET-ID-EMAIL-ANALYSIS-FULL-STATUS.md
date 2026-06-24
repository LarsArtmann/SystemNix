# SystemNix — Comprehensive Status Report

**Date:** 2026-06-10 22:48
**Session:** 130
**Trigger:** User-requested full status audit
**Author:** Crush (assisted)
**Previous Report:** Session 129 (2026-06-10 21:23)

---

## Executive Summary

SystemNix is a cross-platform Nix configuration managing **2 machines** (NixOS `evo-x2` desktop + macOS `Lars-MacBook-Air` laptop) with **40 service modules**, **35 port definitions**, **5 custom packages**, and **~16,500 lines of Nix**. The codebase is in **excellent shape**: zero FIXME/HACK/WORKAROUND markers, all ports centralized, lib/ helper layer complete with zero dead code, 94 justfile recipes, and GitHub Actions CI.

**This session** updated Pocket ID admin email from `larsartmann.com` → `larsartmann.cloud` and investigated Pocket ID's email capabilities (it has full SMTP support but none configured here yet).

**Key metric:** 46 services enabled, 4 disabled, 177 non-archived status reports, 15 commits in the last 48 hours.

---

## a) FULLY DONE

### Build & Quality Infrastructure

- ✅ `nix flake check` passes on both platforms (Darwin + NixOS)
- ✅ `just test-fast` passes (statix, deadnix, alejandra, eval)
- ✅ Pre-commit hooks: gitleaks, trailing whitespace, deadnix, statix, alejandra, nix flake check
- ✅ Zero FIXME / HACK / WORKAROUND / XXX markers in any .nix file (only 2 benign TODOs)
- ✅ GitHub Actions CI: `nix-check.yml` (push/PR) + `flake-update.yml` (weekly auto-PR)
- ✅ 94 justfile recipes covering build, test, deploy, diagnostics
- ✅ NixOS tests: `exec-start-paths.nix` validates ExecStart binary existence

### Architecture

- ✅ flake-parts modular architecture with 40 auto-discovered service modules
- ✅ Cross-platform flake: Darwin (aarch64) + NixOS (x86_64) — 80% shared via `platforms/common/`
- ✅ `lib/` helper layer complete and fully adopted (0 dead helpers):
  - `harden` / `hardenUser` — systemd security hardening (~20+ modules)
  - `serviceDefaults` / `serviceDefaultsUser` — standard defaults with `mkForce`
  - `onFailure` — centralized failure notification via `notify-failure@%n`
  - `serviceTypes` — eval-time option validators (reject `latest` tags)
  - `mkDockerServiceFactory` — Docker Compose systemd scaffolding
  - `mkStateDir` / `mkSecretCheck` / `mkDesktopNotifyService` / `mkHttpCheck`
  - `ports` — 35 ports with collision detection
  - `images` — pinned container image references (7 images, 2 with SHA256 digests)
  - `rocm` — GPU runtime helpers
- ✅ Port centralization: ALL service modules reference `ports.*`, zero hardcoded ports
- ✅ Overlay architecture: `mkPackageOverlay` for platform-safe overlays
- ✅ `flake.nix` at 735 lines — single entry point, auto-discovery, clean structure

### Core Infrastructure Services (Enabled & Running)

| Service | Module | Lines | Status |
|---------|--------|-------|--------|
| Caddy (reverse proxy) | `caddy.nix` | 153 | ✅ 10+ vhosts, TLS, forward auth, metrics |
| Pocket ID (OIDC) | `pocket-id.nix` | 385 | ✅ Passkey auth, declarative provisioning |
| oauth2-proxy | `oauth2-proxy.nix` | 107 | ✅ Forward-auth bridge Caddy ↔ Pocket ID |
| SOPS secrets | `sops.nix` | 226 | ✅ Age-encrypted via SSH host key, 4 sops files |
| Docker | `default-services.nix` | 53 | ✅ Auto-enable, weekly prune |
| DNS Blocker | `dns-blocker.nix` | 353 | ✅ Unbound + dnsblockd + block page |

### Self-Hosted Applications (Enabled & Running)

| Service | Module | Lines | Status |
|---------|--------|-------|--------|
| Forgejo (Git forge) | `forgejo.nix` | 583 | ✅ SQLite, LFS, Actions runner, push mirrors |
| Forgejo repos | `forgejo-repos.nix` | 310 | ✅ Declarative mirroring (2 repos) + daily timer |
| Immich (photos) | `immich.nix` | 128 | ✅ PostgreSQL + Redis, VA-API transcoding, GPU ML |
| SigNoz (observability) | `signoz.nix` | 705 | ✅ Traces/metrics/logs, ClickHouse, 7 alert rules |
| Homepage Dashboard | `homepage.nix` | 373 | ✅ 6 categories, mkGroup/mkService pattern |
| Twenty CRM | `twenty.nix` | 144 | ✅ Docker Compose, daily DB backup |
| Hermes (AI gateway) | `hermes.nix` | 226 | ✅ Discord bot, cron, messaging |
| Gatus (uptime) | `gatus-config.nix` | 323 | ✅ 30+ health checks |
| OpenSEO | `openseo.nix` | 102 | ✅ SEO suite |
| TaskChampion | `taskchampion.nix` | 82 | ✅ Taskwarrior sync |
| Crush Daily | `crush-daily.nix` | 79 | ✅ AI-powered dev insights |
| Monitor365 | `monitor365.nix` | 716 | ✅ Device monitoring, privacy-filtered collectors |
| Disk Monitor | `disk-monitor.nix` | 134 | ✅ Daily growth alerts, BTRFS checks |
| NVMe Health Monitor | `nvme-health-monitor.nix` | 198 | ✅ SSD health + temperature alerts |
| Dozzle (Docker logs) | inline | — | ✅ Inline config (module eval issue workaround) |
| Manifest (LLM router) | `manifest.nix` | 153 | ✅ AI cost optimization, auth-protected |
| Overview (project dashboard) | flake-parts | — | ✅ Discovers git repos, shows activity |
| Discord Sync | `discordsync.nix` | 80 | ✅ Discord channel sync |
| Projects Automation | `projects-management-automation.nix` | 110 | ✅ AI commit messages, watches ~/projects |

### Desktop (Fully Functional)

- ✅ Niri (scrolling-tiling Wayland) — 80+ keybindings, session save/restore
- ✅ Waybar — 15+ modules (DNS stats, weather, camera, GPU, etc.)
- ✅ Ghostty (primary) + Kitty (backup) + Foot (sway fallback)
- ✅ Rofi — Catppuccin Mocha, plugins (calc, emoji)
- ✅ SDDM — SilentSDDM, Catppuccin theme
- ✅ PipeWire audio — ALSA + PulseAudio + JACK compat
- ✅ Full Catppuccin Mocha theming (nix-colors, 164 colors migrated)
- ✅ Swaylock, Wlogout, Dunst, Cliphist, Swayidle
- ✅ Yazi (446 lines of config), Zellij (252 lines)

### Hardware Support (evo-x2)

- ✅ AMD GPU (ROCm/VA-API) — Ollama, llama.cpp, gpu-python
- ✅ AMD NPU (XDNA) — configured
- ✅ Realtek 2.5G Ethernet + MediaTek WiFi/BT
- ✅ EMEET PIXY webcam daemon — auto-tracking
- ✅ BTRFS snapshots via btrbk (daily, 14d + 4w retention)
- ✅ ZRAM swap, AMD virtualization, DDC/CI brightness
- ✅ Dual-WAN with MPTCP and route health monitoring

### Cross-Platform (Shared)

- ✅ Home Manager: Fish/Zsh/Bash (ADR-002 shared aliases), Starship, Git, Tmux, Fzf
- ✅ ActivityWatch (both platforms)
- ✅ KeePassXC, Chromium policies, Taskwarrior 3, SSH config (7 hosts)
- ✅ Catppuccin Mocha global theme, Bibata cursor, JetBrainsMono, Papirus icons
- ✅ Security hardening: fail2ban, ClamAV, 30+ tools
- ✅ Pre-commit hooks, Gitleaks, Statix, Deadnix

### DNS Stack (930-line custom Go app)

- ✅ `dnsblockd` — custom DNS blocking daemon
- ✅ Unbound resolver + dynamic TLS cert generation
- ✅ 10-category blocklist (2.5M+ domains)
- ✅ Temp-allow API, false positive reporting, Prometheus metrics
- ✅ Firefox policy integration

### Darwin (macOS)

- ✅ nix-darwin + declarative Homebrew
- ✅ macOS firewall, Touch ID sudo (tmux fix), Chrome enterprise policies
- ✅ GPG signing, LaunchAgents (ActivityWatch, SublimeText sync, Crush update)
- ✅ File associations (duti), Spotlight indexing

---

## b) PARTIALLY DONE

| Area | What's Done | What's Missing |
|------|-------------|----------------|
| **Pocket ID email** | Admin user created, passkey auth works, declarative provisioning | No SMTP configured — email verification/login notifications disabled. SES infrastructure exists in `domains` repo |
| **Hermes AI gateway** | Discord bot, cron, messaging, 4G memory limit | OpenAI API key not yet in sops (`hermes_openai_api_key` TODO in sops.nix), fallback model not set |
| **Voice agents** | Docker ROCm pipeline exists, LiveKit + Whisper configured | Disabled (`enable = false`) — never deployed |
| **Multi-WM (Sway)** | Module exists | Disabled — may have bitrot, untested |
| **Nix sandbox (macOS)** | Everything else works | Explicitly disabled — macOS compatibility tradeoff |
| **Dep graph commands** | Justfile recipes exist | Depends on `nix-visualize`, can be slow |
| **Shared flake-parts template** | Created | Not pushed to `go-nix-helpers` yet |

---

## c) NOT STARTED

| Task | Notes | Priority |
|------|-------|----------|
| **Pocket ID SMTP via SES** | Full SMTP support in Pocket ID (`SMTP_HOST`, `SMTP_PORT`, etc.), SES infra in `domains` repo, just needs wiring | High |
| **Raspberry Pi 3 DNS failover** | `rpi3/default.nix` exists, `dns-failover.nix` exists — hardware not provisioned | Medium |
| **Hermes OpenAI fallback** | Just needs sops secret + model config | Medium |
| **Shared flake-parts template push** | Created, needs push to `go-nix-helpers` | Low |
| **File & Image Renamer** | Disabled: charm.land/fantasy@v0.25.0 requires Go 1.26.3, nixpkgs has 1.26.2 | Blocked on nixpkgs |
| **PhotoMap** | Port conflict resolved (moved to 8051), still disabled — podman config permission issue | Low |
| **AppArmor** | Commented out in `security-hardening.nix` | Low |
| **DNS-over-QUIC** | Overlay disabled — unbound not compiled with ngtcp2, breaks binary cache (40+ min builds) | Low |

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Details |
|-------|----------|---------|
| **177 non-archived status reports** | 🟡 Medium | Massive docs/status/ bloat. Archive system exists but most reports are in the active directory. Makes finding current state harder. |
| **Dozzle module eval bug** | 🟡 Medium | Creating `modules/nixos/services/dozzle.nix` with options causes `nix flake check` failure while `nix eval` works. Working around with inline config in configuration.nix. Root cause unknown. |
| **Auditd blocked by NixOS bug** | 🟡 Medium | `security.auditd.enable` broken in NixOS 26.05 — upstream issue #483085. No workaround. |
| **Monitor365 module is 716 lines** | 🟡 Code smell | Largest service module by far. Likely has extraction opportunities. |
| **`file-and-image-renamer` blocked** | 🟡 Low | Disabled due to Go version mismatch (needs 1.26.3, nixpkgs has 1.26.2). Waiting on nixpkgs update. |
| **DNS-over-QUIC disabled** | 🟢 Low | Would require custom unbound build, 40+ min compile. Not worth it. |
| **Pocket ID provision — not yet deployed** | 🟢 Low | Admin email + API fixes committed in session 128-129 but not yet deployed to evo-x2. |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Extract Pocket ID SMTP configuration** — SES credentials in `domains` repo, just need sops secrets + env vars
2. **Split `monitor365.nix` (716 lines)** — likely has extractable sub-modules
3. **Split `signoz.nix` (705 lines)** — alert rules, dashboards, collector config could be separate files
4. **Split `forgejo.nix` (583 lines)** — runner config, repo mirroring, federation could be extracted
5. **Investigate Dozzle module eval bug** — workaround is fine but the root cause should be understood
6. **Archive old status reports** — 177 is excessive; move pre-session-100 to archive

### Security

7. **Enable Pocket ID email verification** — prevents unauthorized passkey registration
8. **Enable Pocket ID login notifications** — alerts on new device logins
9. **AppArmor** — currently commented out, should be enabled when NixOS bug is fixed
10. **Auditd** — blocked by upstream, track the issue

### Operations

11. **Wire Hermes OpenAI fallback** — just a sops secret + config
12. **Provision Pi 3 for DNS failover** — hardware exists, config exists
13. **Push shared flake-parts template** to `go-nix-helpers`
14. **Consider Resend vs SES** for Pocket ID SMTP — SES already in the `domains` repo

### Code Quality

15. **Reduce status report bloat** — 177 files is noise. Archive aggressively.
16. **Consider extracting `scheduled-tasks.nix` (465 lines)** — likely has consolidation opportunities
17. **Consider extracting `niri-wrapped.nix` (520 lines)** and `waybar.nix` (474 lines) — large desktop configs

---

## f) Top 25 Things to Do Next

### P0 — High Impact, Immediate

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy session 128-129 changes to evo-x2** | All committed work is untested in prod | `just switch` |
| 2 | **Wire Pocket ID SMTP via SES** | Email verification + login notifications | Small |
| 3 | **Add SES SMTP credentials to sops** (`pocket-id.yaml`) | Unblocks email features | Manual |
| 4 | **Archive status reports (pre-session 100)** | Reduces noise from 177 → ~30 files | Trivial |
| 5 | **Verify all 30+ Gatus endpoints are healthy** | Confidence in prod state | `just verify` |

### P1 — High Impact, This Week

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 6 | **Wire Hermes OpenAI fallback** (sops secret + model config) | AI gateway resilience | Small |
| 7 | **Push shared flake-parts template to `go-nix-helpers`** | Go ecosystem standardization | Small |
| 8 | **Investigate Dozzle module eval bug** | Clean architecture, remove workaround | Medium |
| 9 | **Split `monitor365.nix` into sub-modules** | Maintainability | Medium |
| 10 | **Verify BTRFS snapshot health** (daily timer running, retention working) | Disaster recovery confidence | Trivial |

### P2 — Medium Impact, This Month

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 11 | **Provision Pi 3 for DNS failover cluster** | Network resilience | Medium |
| 12 | **Split `signoz.nix` — extract alert rules + dashboards** | Maintainability | Medium |
| 13 | **Split `forgejo.nix` — extract runner + federation config** | Maintainability | Medium |
| 14 | **Enable AppArmor** (when NixOS bug fixed) | Security hardening | Small |
| 15 | **Consider Nix flake migration for `domains` repo** | Infrastructure-as-code consistency | Large |
| 16 | **Extract `scheduled-tasks.nix` sub-timers** | Code organization | Medium |
| 17 | **Add `emailVerificationEnabled` option to Pocket ID module** | Declarative email config | Small |

### P3 — Nice to Have

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 18 | **Enable PhotoMap** (port conflict resolved) | Photo AI features | Medium |
| 19 | **Re-enable file-and-image-renamer** (when Go 1.26.3 lands in nixpkgs) | Desktop automation | Waiting |
| 20 | **Voice agents — evaluate if still needed** | Clean disabled code | Small |
| 21 | **Multi-WM (Sway) — test or remove** | Reduce bitrot risk | Medium |
| 22 | **DNS-over-QUIC — re-evaluate** | Privacy | Low priority |
| 23 | **Add container image digests to all images in `lib/images.nix`** | Supply chain security | Small |
| 24 | **Minecraft server — evaluate if still wanted** | Clean disabled code | Trivial |
| 25 | **Consider consolidating `overview` into `homepage`** | Reduce service count | Large |

---

## g) Top #1 Question I Cannot Answer Myself

**Do you already have SES SMTP credentials generated for `larsartmann.cloud`, or do we need to create them in AWS?**

The `domains` repo has SES configured for `larsartmann.com` (eu-west-1 + us-east-1) with SPF/DKIM/DMARC records, and there's a Resend DKIM record for the `cloud` subdomain. But I can't tell if:
- SES SMTP credentials already exist and are stored somewhere accessible
- The Resend DKIM record means you've already chosen Resend over SES for `cloud`
- We should create new SES credentials specifically for Pocket ID's SMTP needs

This is the single blocker for wiring Pocket ID email — once we know the SMTP provider and have credentials, it's a 15-minute job.

---

## Project Stats at a Glance

| Metric | Value |
|--------|-------|
| Total Nix LOC | ~16,500 |
| Service modules | 40 |
| Enabled services | 46 |
| Disabled services | 4 |
| Port definitions | 35 |
| Pinned container images | 7 |
| Custom packages | 5 |
| Justfile recipes | 94 |
| Lib helpers | 9 files |
| Overlay packages | 25 |
| Cross-platform programs | ~40 |
| Status reports (active) | 177 |
| Commits (last 48h) | 15 |
| TODO/FIXME markers | 2 (both benign) |
| Machines managed | 2 (NixOS + Darwin) |

---

_Generated by Crush — Session 130_
