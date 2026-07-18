# Setup-Mac Full Project Status Report

**Date:** 2026-03-30 17:55
**Report Type:** Comprehensive Full-Stack Audit — All Workstreams
**Total Commits:** 1,256 | **Nix Files:** 94 | **Lines of Nix:** 9,416 | **Shell Scripts:** 56
**Status Reports:** 137 | **Project Size:** ~307 MB
**Working Tree:** CLEAN | **Branch:** master (up to date with origin)

---

## Executive Summary

Setup-Mac is a **production-grade, cross-platform Nix configuration** managing two machines:

- **evo-x2** (NixOS) — GMKtec Mini PC: AMD Ryzen AI Max+ 395, 128 GB RAM, Radeon 8060S
- **MacBook Air** (macOS/aarch64-darwin)

March 2026 has been the most active month with **230+ commits**, including DNS blocking infrastructure, Immich ML optimization, display manager migration, security hardening, and comprehensive cleanup. The project is in **STRONG** health with zero broken imports, all services operational, and clean builds.

**Key Achievement This Session Block (6 commits since last Immich report):**

- Immich AI models upgraded (+23% search quality)
- SDDM → greetd/ReGreet display manager migration with Catppuccin Mocha theme
- DNS blocker interface fix (enp1s0 → eno1) + PostHog US blocklist addition
- Script strict mode completed (56/56 scripts now have `set -euo pipefail`)
- Hyprland animated wallpaper `wallpaperDir` fix
- 2 deployment scripts added (local + remote)

---

## A) FULLY DONE ✅

### Session Block: Immich AI Model Optimization (Commits 0d6c148, 0223647)

| Setting                 | Before                            | After                                      | Impact                                             |
| ----------------------- | --------------------------------- | ------------------------------------------ | -------------------------------------------------- |
| CLIP Smart Search       | `ViT-B-32__openai` (69.9% recall) | `ViT-SO400M-16-SigLIP2-384__webli` (86.0%) | **+23% search quality**                            |
| Face Recognition        | `buffalo_l`                       | `antelopev2`                               | Latest-gen, best accuracy                          |
| Duplicate Detection     | `maxDistance: 0.001` (broken)     | `maxDistance: 0.03`                        | Now functional                                     |
| Video Resolution        | 720p                              | 1080p                                      | Modern display quality                             |
| FFmpeg Preset           | `ultrafast`                       | `fast`                                     | Better quality encoding                            |
| SmartSearch Concurrency | 2                                 | 1                                          | Prevents OOM (~3.8 GB/model)                       |
| OCR                     | `PP-OCRv5_server`                 | unchanged                                  | Already best available                             |
| **GLM-OCR Research**    | —                                 | **Researched, NOT viable**                 | Immich hardcodes PaddleOCR; GLM-OCR needs 8GB+ GPU |

### Session Block: Display Manager Migration (Commit 9530c05)

- Replaced SDDM with greetd/regreet (GTK4 greeter)
- Custom Catppuccin Mocha CSS theme (235 lines)
- ReGreet configured with Hyprland + Niri session entries
- Autologin user option available but not enabled

### Session Block: Script Hardening (Commit d4ecb21)

- **56/56 scripts** now have `set -euo pipefail` (was 49/56)
- 7 scripts fixed: apply-config, health-dashboard, nix-diagnostic, shell-context-detector, smart-fix, test-nixos-config, test-nixos

### Session Block: DNS Blocker Fixes (Commits 6b4d4f0, 0363327)

- Corrected network interface: `enp1s0` → `eno1`
- Added PostHog US analytics endpoint to blocklist
- Fixed dnsblockd systemd service capabilities for privileged port binding

### Session Block: Hyprland Wallpaper Fix (Commit 0223647)

- Replaced hardcoded `$HOME/.local/share/wallpapers` with `cfg.wallpaperDir`
- Added `wallpaperDir = "/home/lars/projects/wallpapers"` in home.nix

### Infrastructure (Previously Completed, Verified)

| Component                    | File(s)                                   | Status                       |
| ---------------------------- | ----------------------------------------- | ---------------------------- |
| **Cross-platform Nix flake** | `flake.nix` (16 inputs, 2 systems)        | Production-ready             |
| **DNS Blocker**              | `modules/nixos/dns-blocker.nix`           | 15 blocklists, ~1.9M domains |
| **DNS Block Page (HTTPS)**   | Self-signed CA + server cert              | Working on LAN               |
| **Caddy Reverse Proxy**      | `modules/nixos/services/caddy.nix`        | 5 virtual hosts `*.lan`      |
| **Immich**                   | `modules/nixos/services/immich.nix`       | Running, PostgreSQL tuned    |
| **Gitea**                    | `modules/nixos/services/gitea.nix`        | SQLite, GitHub sync 6h       |
| **Grafana + Prometheus**     | 4 exporters, auto-provisioned             | Running                      |
| **Homepage Dashboard**       | `modules/nixos/services/homepage.nix`     | All LAN services visible     |
| **PhotoMap AI**              | OCI container, Immich mount               | Running                      |
| **sops-nix Secrets**         | SSH host key decryption                   | Working                      |
| **SSH Hardening**            | Key-only, restricted ciphers              | Working                      |
| **Ollama**                   | Vulkan backend on AMD GPU                 | Running                      |
| **KeePassXC**                | Browser integration (Brave + Helium)      | Working                      |
| **AMD GPU**                  | VAAPI, ROCm env vars                      | Working                      |
| **Audio (PipeWire)**         | Full PulseAudio/JACK compat               | Working                      |
| **Bluetooth**                | Blueman enabled                           | Working                      |
| **BTRFS Snapshots**          | Timeshift daily + autoScrub               | Working                      |
| **Pre-commit Hooks**         | Gitleaks, trailing whitespace, Nix syntax | All passing                  |
| **Security**                 | AppArmor, fail2ban, ClamAV, GPG signing   | Working                      |

### Desktop Environment

| Component                        | Status                                    |
| -------------------------------- | ----------------------------------------- |
| Hyprland (Wayland compositor)    | Working, some plugins disabled for 0.54.2 |
| Niri (scrollable-tiling)         | Working                                   |
| Waybar                           | Shared by both compositors                |
| greetd/ReGreet (display manager) | Migrated from SDDM, Catppuccin themed     |
| Rofi launcher                    | Catppuccin themed                         |
| Hyprlock / Hypridle / Wlogout    | All Catppuccin themed                     |
| Dunst notifications              | TV-friendly (2m viewing)                  |
| Zellij / Kitty + Foot terminals  | Both working                              |
| Animated Wallpaper (Hyprland)    | Fixed: configurable `wallpaperDir`        |
| Fish shell + Starship prompt     | Cross-platform                            |
| Catppuccin Mocha theming         | Consistent across all components          |

---

## B) PARTIALLY DONE 🔄

| Component                         | Status                                                  | What's Left                                                                  |
| --------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **Immich config import**          | Config file updated at `~/Downloads/immich-config.json` | Needs importing into running Immich instance                                 |
| **Immich ML re-index**            | Models chosen, config ready                             | Must re-run Smart Search + Face Detection + Dup Detection on ALL assets      |
| **Immich GPU acceleration**       | Researched (CPU-only ML identified as waste)            | Would need Docker+ROCm or custom Nix overlay — significant effort            |
| **AI Stack (Ollama)**             | Running on Vulkan                                       | No web UI; no model pre-pulling; Vulkan < ROCm perf                          |
| **AMD NPU (XDNA2, 50 TOPS)**      | Kernel module loaded                                    | Disabled in config; requires kernel 6.14+ for full functionality             |
| **DNS Blocklist hashing**         | Working                                                 | Pinned SHA256 hashes break when upstream files change; auto-updater fragile  |
| **Security hardening**            | Strong                                                  | auditd disabled (NixOS bug #483085); audit kernel module (AppArmor conflict) |
| **Monitoring stack**              | Prometheus+Grafana+exporters working                    | No custom dashboards beyond overview.json; no alerting rules                 |
| **PhotoMap**                      | Running                                                 | Uses `latest` tag (non-reproducible); pin to specific hash                   |
| **docs/STATUS.md**                | Exists                                                  | Last updated 2025-12-27 — 3 months stale                                     |
| **docs/TODO-STATUS.md**           | Exists                                                  | Last updated 2026-01-13 — items resolved but not marked                      |
| **Hyprland 0.54.2 compatibility** | Working but degraded                                    | hy3, hyprsplit, hyprwinwrap plugins disabled; scroll animation removed       |
| **Ghost Systems type safety**     | Core files written                                      | Types.nix, State.nix, Validation.nix NOT imported in flake (0/14 tasks)      |
| **Desktop Improvements Roadmap**  | Planned                                                 | 0/55 items completed (Phase 1: 0/21, Phase 2: 0/21, Phase 3: 0/13)           |
| **ReGreet display manager**       | Code merged, CSS themed                                 | Awaiting live deploy/test on evo-x2 hardware                                 |

---

## C) NOT STARTED ⬜

### High Value, Not Started

1. **Import immich-config.json** into running Immich instance (5 min)
2. **Re-run Smart Search** on ALL assets — new CLIP model (hours)
3. **Re-run Face Detection** on ALL assets — antelopev2 (hours)
4. **Re-run Duplicate Detection** — fixed maxDistance (hours)
5. **SMTP notifications** for Immich alerts
6. **Immich external domain / remote access** (`server.externalDomain = ""`)
7. **OAuth/SSO** for Immich (`oauth.enabled = false`)
8. **Open WebUI or chat frontend** for Ollama
9. **Grafana alerting rules** — no alerts configured
10. **Custom Grafana dashboards** — only 1 overview
11. **Bluetooth Nest Audio pairing** — 7 steps in TODO_LIST.md, none executed
12. **Offsite backup strategy** — DB backup is local only

### Architecture Not Started (14 Ghost Systems Items)

- Import core/Types.nix in flake (15 min)
- Import core/State.nix in flake (15 min)
- Import core/Validation.nix in flake (15 min)
- Enable TypeSafetySystem in flake (30 min)
- Consolidate user config — eliminate "split brain" (45 min)
- Consolidate path config (30 min)
- Enable SystemAssertions (30 min)
- Enable ModuleAssertions (30 min)
- Split system.nix (397 lines → 3 files) (90 min)
- Replace bool with State enum (60 min)
- Replace debug bool with LogLevel enum (45 min)
- Split BehaviorDrivenTests.nix (60 min)
- Split ErrorManagement.nix (60 min)
- Add ConfigAssertions integration (45 min)

### Desktop Not Started (55 Items Across 3 Phases)

**Phase 1 (21 items):** Hot-reload, 7 privacy/locking, 5 productivity scripts, 5 monitoring modules, 4 window management
**Phase 2 (21 items):** 4 keyboard/input, 7 audio/media, 4 dev tools, 4 desktop env
**Phase 3 (13 items):** 4 backup/config, 4 gaming, 4 window rules, 4 AI integration

---

## D) TOTALLY FUCKED UP 💥

### Fixed This Session

| Issue                                                         | Severity | Status                           |
| ------------------------------------------------------------- | -------- | -------------------------------- |
| **Duplicate Detection NON-FUNCTIONAL** (`maxDistance: 0.001`) | CRITICAL | ✅ Fixed to 0.03                 |
| **CLIP model rank #46 of 60+**                                | HIGH     | ✅ Upgraded to #1 Pareto-optimal |
| **7 scripts missing `set -euo pipefail`**                     | MEDIUM   | ✅ All 56 scripts now compliant  |
| **Hyprland wallpaper hardcoded path**                         | MEDIUM   | ✅ Fixed to use cfg.wallpaperDir |
| **DNS blocker wrong interface** (enp1s0)                      | HIGH     | ✅ Fixed to eno1                 |

### Still Fucked Up

| Issue                                    | Severity | Impact                                                                                         |
| ---------------------------------------- | -------- | ---------------------------------------------------------------------------------------------- |
| **docs/STATUS.md 3 months stale**        | HIGH     | Misleads anyone reading project status — shows Home Manager as "pending" in Dec 2025           |
| **docs/TODO-STATUS.md 2.5 months stale** | HIGH     | Items resolved but not marked                                                                  |
| **137 status report files** (7.9 MB)     | MEDIUM   | Massive accumulation of one-time session summaries, most never referenced again                |
| **Hyprland audio uses pactl** not wpctl  | LOW      | Works via PulseAudio compat but suboptimal for PipeWire                                        |
| **TODO_LIST.md summary counts wrong**    | LOW      | Phase 1: says 21 (actually 22), Phase 2: says 21 (actually 19), Phase 3: says 13 (actually 43) |
| **PhotoMap uses `latest` tag**           | MEDIUM   | Non-reproducible Nix build                                                                     |

### No Critical Breakages

- Zero broken imports across 94 .nix files
- All services operational
- Clean build (`nix flake check` PASS, `statix` PASS, `alejandra` PASS, `deadnix` PASS)
- Git working tree CLEAN

---

## E) WHAT WE SHOULD IMPROVE 📈

### Immediate High-Impact

1. **GPU-accelerated ML for Immich** — Ryzen AI Max+ 395 iGPU sits idle for ML. CPU-only is wasteful. Could be 5-10x faster with ROCm.
2. **NPU (XDNA2, 50 TOPS)** — Near-zero power cost for face detection/CLIP. Check kernel 6.14+.
3. **Stale documentation** — `docs/STATUS.md` and `docs/TODO-STATUS.md` are months out of date. First files anyone reads.
4. **PhotoMap reproducibility** — Pin `latest` to specific image hash.
5. **Hyprland audio** — Switch `pactl` → `wpctl` for PipeWire consistency.

### Architecture

6. **Ghost Systems type safety activation** — Core Types/State/Validation exist but unused. 14 tasks.
7. **User config consolidation** — "Split brain" between multiple files.
8. **CI/CD pipeline** — GitHub Actions exists but may need updating.
9. **DNS blocklist hash management** — Pinned SHA256 requires manual updates.
10. **Monitoring alerting** — No Prometheus alerting rules.

### Documentation

11. **Update docs/STATUS.md** — Reflects Dec 2025, not March 2026.
12. **Update docs/TODO-STATUS.md** — Items resolved but unmarked.
13. **Archive old status reports** — 137 files, many redundant.
14. **AGENTS.md accuracy** — May reference outdated patterns.

---

## F) TOP 25 THINGS TO DO NEXT 🎯

| #   | Task                                                   | Priority | Est. Time | Category      |
| --- | ------------------------------------------------------ | -------- | --------- | ------------- |
| 1   | **Import immich-config.json into running Immich**      | CRITICAL | 5min      | Immich        |
| 2   | **Re-run Smart Search on ALL assets** (new CLIP model) | CRITICAL | Hours     | Immich        |
| 3   | **Re-run Face Detection on ALL assets** (antelopev2)   | CRITICAL | Hours     | Immich        |
| 4   | **Re-run Duplicate Detection** (fixed maxDistance)     | HIGH     | Hours     | Immich        |
| 5   | **Update docs/STATUS.md** to March 2026 reality        | HIGH     | 30min     | Documentation |
| 6   | **Update docs/TODO-STATUS.md** with resolved items     | HIGH     | 30min     | Documentation |
| 7   | **Fix TODO_LIST.md summary counts**                    | HIGH     | 5min      | Documentation |
| 8   | **Research Immich GPU ML via Docker+ROCm**             | HIGH     | 4h        | Immich        |
| 9   | **Enable NPU** (check kernel 6.14+ availability)       | HIGH     | 2h        | Hardware      |
| 10  | **Deploy ReGreet on evo-x2** (test live hardware)      | HIGH     | 30min     | Desktop       |
| 11  | **Pin PhotoMap image** to specific hash                | MED      | 10min     | Services      |
| 12  | **Migrate Hyprland audio** from pactl to wpctl         | MED      | 30min     | Desktop       |
| 13  | **Add GPU temp to Waybar** (AMD GPU)                   | MED      | 1.5h      | Desktop P1    |
| 14  | **Add CPU usage to Waybar** (per-core)                 | MED      | 1.5h      | Desktop P1    |
| 15  | **Add memory usage to Waybar**                         | MED      | 1.5h      | Desktop P1    |
| 16  | **Add Hyprland/Niri hot-reload** (Ctrl+Alt+R)          | MED      | 10min     | Desktop P1    |
| 17  | **Set up SMTP for Immich notifications**               | MED      | 1h        | Immich        |
| 18  | **Add Prometheus alerting rules**                      | MED      | 2h        | Monitoring    |
| 19  | **Import core/Types.nix in flake**                     | MED      | 15min     | Architecture  |
| 20  | **Import core/State.nix + Validation.nix in flake**    | MED      | 30min     | Architecture  |
| 21  | **Consolidate user config** (eliminate split brain)    | MED      | 45min     | Architecture  |
| 22  | **Archive old status reports** (137 files)             | LOW      | 1h        | Documentation |
| 23  | **Set up Bluetooth + Nest Audio**                      | LOW      | 1h        | Hardware      |
| 24  | **Configure Immich external domain** (remote access)   | LOW      | 2h        | Immich        |
| 25  | **Create Quake Terminal dropdown** (F12)               | LOW      | 2h        | Desktop P1    |

---

## G) TOP #1 QUESTION ❓

**What language(s) do you primarily search in for Immich Smart Search?**

The chosen CLIP model (`ViT-SO400M-16-SigLIP2-384__webli`) is #1 for English (86.0% recall). But for multilingual search:

| Language | Current Model | Best Multilingual (`nllb-clip-large-siglip__v1`) | Delta      |
| -------- | ------------- | ------------------------------------------------ | ---------- |
| English  | 86.0%         | 83.2%                                            | -2.8%      |
| German   | 87.2%         | 87.1%                                            | -0.1%      |
| Dutch    | 79.7%         | 79.3%                                            | -0.4%      |
| French   | 86.5%         | 86.1%                                            | -0.4%      |
| Danish   | 82.3%         | 87.2%                                            | **+4.9%**  |
| Finnish  | 62.3%         | 84.3%                                            | **+22.0%** |
| Greek    | 60.6%         | 71.3%                                            | **+10.7%** |

**If you only search in English/German/Dutch/French:** Current model is optimal — stick with it.

**If you search in Danish/Finnish/Greek/Czech/Croatian:** Switch to `nllb-clip-large-siglip__v1` for dramatically better multilingual recall.

**This question must be answered BEFORE the Smart Search re-index** — changing models after re-index requires re-running the entire job again (hours of processing).

---

## Service Inventory

| Service     | Port      | URL            | Status  |
| ----------- | --------- | -------------- | ------- |
| Immich      | 2283      | `immich.lan`   | Running |
| Gitea       | 3000      | `gitea.lan`    | Running |
| Grafana     | 3001      | `grafana.lan`  | Running |
| Homepage    | 8082      | `home.lan`     | Running |
| PhotoMap    | 8050      | `photomap.lan` | Running |
| Prometheus  | 9091      | localhost      | Running |
| Ollama      | 11434     | localhost      | Running |
| DNS Blocker | 53/80/443 | 192.168.1.163  | Running |
| SSH         | 22        | 192.168.1.162  | Running |
| Caddy       | 80/443    | 192.168.1.162  | Running |

## Scheduled Tasks

| Task                    | Schedule         | File                     |
| ----------------------- | ---------------- | ------------------------ |
| Crush provider update   | Daily 00:00      | `scheduled-tasks.nix`    |
| Blocklist hash update   | Weekly Mon 04:00 | `scheduled-tasks.nix`    |
| Service health check    | Every 15min      | `scheduled-tasks.nix`    |
| Immich DB backup        | Daily            | `immich.nix`             |
| Gitea GitHub sync       | Every 6h         | `gitea.nix`              |
| Docker auto-prune       | Weekly           | `default.nix`            |
| BTRFS autoScrub         | Monthly          | `snapshots.nix`          |
| Timeshift backup        | Daily            | `snapshots.nix`          |
| ClamAV signature update | Daily            | `security-hardening.nix` |

## Hardware Context (evo-x2 / GMKtec)

| Component | Spec                                           | NixOS Status                |
| --------- | ---------------------------------------------- | --------------------------- |
| CPU       | AMD Ryzen AI Max+ 395 (16C/32T, 5.19 GHz)      | Fully working               |
| RAM       | 128 GiB LPDDR5X (62 GiB OS, ~64 GiB GPU)       | Working                     |
| GPU       | AMD Radeon 8060S (RDNA 3.5, gfx1151)           | VAAPI working, ROCm env set |
| NPU       | AMD XDNA2 (50 TOPS)                            | Module loaded, **disabled** |
| Storage   | NVMe PCIe 4.0, BTRFS + zstd                    | Working, snapshots active   |
| Display   | TV via DP-3 (4K@30 or 1080p@120, kanshi)       | Working                     |
| Swap      | 41 GiB (31.2 GiB ZRAM + 10 GiB NVMe partition) | Working                     |

## Project Metrics

| Metric                                 | Value                             |
| -------------------------------------- | --------------------------------- |
| Total commits                          | 1,256                             |
| Nix files                              | 94                                |
| Lines of Nix code                      | 9,416                             |
| Shell scripts                          | 56 (all with `set -euo pipefail`) |
| Flake inputs                           | 16                                |
| Services managed                       | 15+                               |
| DNS blocklists                         | 15 (~1.9M domains)                |
| Custom packages                        | 7                                 |
| Justfile recipes                       | 90+                               |
| Documentation files                    | 200+                              |
| Status reports                         | 137                               |
| Desktop improvement items planned      | 55                                |
| Architecture refactoring items planned | 14                                |
| Active TODOs in source                 | 2 (auditd-related)                |
| Stale documentation files              | 2 (STATUS.md, TODO-STATUS.md)     |
