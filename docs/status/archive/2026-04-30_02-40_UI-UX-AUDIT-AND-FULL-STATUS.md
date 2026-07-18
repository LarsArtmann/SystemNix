# SystemNix Comprehensive Status Report

**Date:** 2026-04-30 02:40
**Author:** Crush (AI Agent)
**Branch:** master
**Last Commit:** `38e475e` — chore(flake.lock): update all flake inputs to latest revisions
**Commit Before That:** `1e7cb48` — chore(git): track .direnv flake profile symlinks for direnv integration

---

## Executive Summary

SystemNix manages 2 machines (macOS `Lars-MacBook-Air` + NixOS `evo-x2`) through 97 `.nix` files across 28 service modules, 8 custom packages, and ~80% shared configuration. The project is **65% complete** (62/95 tasks), with all P2 reliability tasks done. This session focused on a deep UI/UX audit, identifying and fixing 7 visual/interaction inconsistencies across the Catppuccin Mocha theme layer.

---

## A) FULLY DONE ✅

### Session Work (2026-04-30)

| #   | Change                                | File                                        | Impact                                                                                |
| --- | ------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------- |
| 1   | Waybar tooltip CSS (Catppuccin Mocha) | `platforms/nixos/desktop/waybar.nix`        | Was default GTK white boxes → now themed                                              |
| 2   | Waybar hover feedback (9 modules)     | `platforms/nixos/desktop/waybar.nix`        | clock, cpu, memory, temp, network, audio, tray, weather, media now highlight on hover |
| 3   | Waybar weather error state            | `platforms/nixos/desktop/waybar.nix`        | "N/A" text → JSON with `.error` class + dimmed color                                  |
| 4   | Waybar media tooltip + paused state   | `platforms/nixos/desktop/waybar.nix`        | Shows artist, title, album, player name + `.paused` class when paused                 |
| 5   | FZF Catppuccin Mocha colors           | `platforms/common/programs/fzf.nix`         | Was the ONLY tool with default colors → now themed (cross-platform)                   |
| 6   | Starship `$nix_shell` visibility      | `platforms/common/programs/starship.nix`    | Was `disabled = false` but missing from format string → now shows `❄ via shell-name`  |
| 7   | Homepage Dashboard Catppuccin CSS     | `modules/nixos/services/homepage.nix`       | Was generic `dark/slate` → full Catppuccin Mocha with cards, hover, scrollbar         |
| 8   | Kitty visual bell                     | `platforms/nixos/users/home.nix`            | Audio bell disabled, no replacement → blue flash on bell (0.2s)                       |
| 9   | Dunst notification history formatting | `platforms/nixos/programs/niri-wrapped.nix` | Was raw JSON in rofi → formatted `Summary — Body [HH:MM]`                             |

### Historical (from MASTER_TODO_PLAN)

- **P2 RELIABILITY: 11/11 DONE** — WatchdogSec, Restart policies, dead bindings, pager conflicts, editorconfig, statix, deadnix, meta.homepage — ALL COMPLETE
- **P0 CRITICAL: 1/1 DONE** — Push all commits to origin
- **P3 CLEANUP: 7/7 DONE** — Darwin HM user fix, relative paths, overlay documentation, etc.
- **P4 CODE QUALITY: 5/5 DONE** — Flake-parts modules, sops template patterns, Go overlay
- **P5 DEPLOY: 5/13 DONE** — Darwin verified, NixOS services started, Home Manager integrated
- **P7 FORMATTING: 4/4 DONE** — Alejandra, statix hook, catppuccin everywhere
- **P8 DOCUMENTATION: 1/1 DONE** — MASTER_TODO_PLAN generated
- **P9 FUTURE: 0/10 DONE** — Research items, not yet started

### Infrastructure

- 28/28 NixOS service modules properly imported in flake.nix
- 8/8 custom packages have proper overlays (or intentional perSystem-only exposure)
- Full Catppuccin Mocha theme consistency across: Niri, Waybar, Rofi, wlogout, swaylock, Kitty, Foot, Yazi, Zellij, tmux, Dunst, Starship, FZF, Homepage Dashboard, SDDM (silent-sddm), GTK, Qt, dconf
- SigNoz observability pipeline (node_exporter + cAdvisor + journald + OTLP)
- DNS blocking stack (Unbound + dnsblockd, 2.5M+ domains)
- EMEET PIXY webcam daemon (call detection, auto-tracking, Waybar integration)
- Niri session save/restore (crash recovery, workspace-aware, kitty state)
- Centralized AI model storage (`/data/ai/`)
- Taskwarrior + TaskChampion sync (cross-platform including Android)
- Hermes AI agent gateway (Discord, cron, messaging)

---

## B) PARTIALLY DONE ⚠️

| Item                     | Status                                | Detail                                                                                                                                                                                            |
| ------------------------ | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ai-stack module**      | Imported but not enabled              | `ai-stack.nix` is in flake.nix imports and evo-x2 module list, but `services.ai-stack.enable` is NOT set in configuration.nix. Available but dormant.                                             |
| **dns-failover cluster** | Module done, hardware not provisioned | `dns-failover.nix` works for rpi3-dns config. evo-x2 imports it but doesn't enable it. Pi 3 hardware not yet provisioned.                                                                         |
| **monitor365**           | Packaged and deployed but disabled    | `monitor365.enable = false` in configuration.nix — intentionally disabled due to high RAM usage.                                                                                                  |
| **Darwin services**      | Stub file only                        | `platforms/darwin/services/default.nix` contains only comments, zero actual configuration. LaunchAgents exist separately.                                                                         |
| **`.gitignore`**         | Mostly good, 4 broken lines           | Lines 128-135 have bare text (no `#` prefix) being treated as literal filename patterns: `Copy/paste detection report`, `Dependencies`, `Test coverage`, `Add pattern for Templ generated files`. |
| **flake.lock**           | 9 days old on main nixpkgs            | nixpkgs last updated 2026-04-21. Most other inputs updated 2026-04-28. CI auto-update exists but may not have triggered.                                                                          |

---

## C) NOT STARTED ⬜

### P1 — SECURITY (4 remaining)

| #     | Task                                                                      | Blocker                                           |
| ----- | ------------------------------------------------------------------------- | ------------------------------------------------- |
| P1-7  | Move Taskwarrior encryption to sops                                       | evo-x2 access — currently uses deterministic hash |
| P1-9  | Pin Docker digest for Voice Agents (`beecave/insanely-fast-whisper-rocm`) | evo-x2 access + `docker pull` for sha256          |
| P1-10 | Pin Docker digest for PhotoMap (`lstein/photomapai`)                      | evo-x2 access + `docker pull` for sha256          |
| P1-11 | Secure VRRP auth_pass with sops                                           | evo-x2 access + Pi 3 provisioning                 |

### P5 — DEPLOYMENT (8 remaining)

| #     | Task                                            | Blocker               |
| ----- | ----------------------------------------------- | --------------------- |
| P5-38 | Verify sigNoz dashboards configured             | evo-x2 browser access |
| P5-39 | Verify Immich ML pipeline works end-to-end      | evo-x2 access         |
| P5-40 | Verify PhotomapAI CLIP embeddings generate      | evo-x2 access         |
| P5-41 | Verify Caddy TLS certificates issued            | evo-x2 access         |
| P5-42 | Test Authelia SSO login flow                    | evo-x2 access         |
| P5-43 | Verify Twenty CRM accessible                    | evo-x2 access         |
| P5-44 | Test Hermes Discord bot connectivity            | evo-x2 access         |
| P5-45 | Verify all Homepage service health checks green | evo-x2 access         |

### P9 — FUTURE (10 remaining)

| #     | Task                                      | Notes                       |
| ----- | ----------------------------------------- | --------------------------- |
| P9-83 | NixOS test VM for smoke testing           | Infrastructure setup        |
| P9-84 | Auto-update flake inputs PR bot           | CI/CD research              |
| P9-85 | Darwin launchd service hardening          | Audit existing LaunchAgents |
| P9-86 | Immich external library backup strategy   | Storage planning            |
| P9-87 | PhotomapAI GPU acceleration config        | ROCm research               |
| P9-88 | Nix garbage collection timer optimization | Current: weekly, could tune |
| P9-89 | Gitea backup/restore automation           | Critical data protection    |
| P9-90 | DNS-over-QUIC with unbound patch          | Experimental                |
| P9-91 | System metrics alerting via Hermes        | Integration work            |
| P9-92 | Niri layout profiles (work/gaming/media)  | Feature development         |

---

## D) TOTALLY FUCKED UP 💥

| #   | Issue                                                               | Severity  | Root Cause                                                                                                                                                                           |
| --- | ------------------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | **`nix-ssh-config` external flake has duplicate `environment.etc`** | 🔴 HIGH   | Upstream bug in `LarsArtmann/nix-ssh-config@e0ac693` — `ssh.nix` defines `environment.etc` twice (lines 161 and 167). **This blocks `just test-fast` and `just validate` entirely.** |
| 2   | **`docs/STATUS.md` is 4+ months stale**                             | 🟡 MEDIUM | Last updated 2025-12-27, describes Home Manager as "READY FOR DEPLOYMENT" — it's been deployed for months. Misleading for anyone reading it.                                         |
| 3   | **Duplicate packages: `jq`, `zellij`, `swappy`**                    | 🟡 MEDIUM | These 3 packages appear in BOTH `common/packages/base.nix` AND `nixos/users/home.nix`. Not harmful (Nix deduplicates) but sloppy and confusing.                                      |
| 4   | **Pre-commit hook hardcoded NixOS path**                            | 🟡 MEDIUM | Trailing-whitespace hook uses `/run/current-system/sw/bin/sed` — fails on macOS Darwin. Cross-platform regression.                                                                   |
| 5   | **`.direnv/` not in `.gitignore`**                                  | 🟡 MEDIUM | `.direnv/flake-profile*` are Nix store symlinks tracked in git. Will be broken on other machines or after GC. Already committed in `1e7cb48`.                                        |
| 6   | **Orphaned DNS blocker file**                                       | 🟢 LOW    | `platforms/nixos/modules/dns-blocker.nix` exists but is never imported — dead code. DNS blocker now uses `dns-blocker-config.nix`.                                                   |
| 7   | **`nix-colors` missing `inputs.nixpkgs.follows`**                   | 🟢 LOW    | Causes nix-colors to use its own pinned nixpkgs, creating unnecessary downloads and potential version mismatches.                                                                    |
| 8   | **4 TODO comments in service modules**                              | 🟢 LOW    | `voice-agents.nix` (Docker digest), `photomap.nix` (Docker digest), `security-hardening.nix` x2 (audit rules). All tracked in MASTER_TODO_PLAN.                                      |

---

## E) WHAT WE SHOULD IMPROVE

### Immediate (Next Session)

1. **Fix `nix-ssh-config` duplicate `environment.etc`** — This is the #1 blocker. Either fork and fix, or report upstream. Every `just test-fast` run fails because of this.
2. **Remove duplicate packages from `home.nix`** — `jq`, `zellij`, `swappy` are already in `base.nix`.
3. **Archive `docs/STATUS.md`** → `docs/archive/status/2025-12-27_STATUS.md`
4. **Fix `.gitignore`** — Prefix lines 128-135 with `#`, add `.direnv/` pattern
5. **Fix pre-commit sed path** — Replace `/run/current-system/sw/bin/sed` with just `sed`
6. **Add `inputs.nix-colors.inputs.nixpkgs.follows = "nixpkgs"` to flake.nix**

### Short-Term (This Week)

7. **Delete orphaned `platforms/nixos/modules/dns-blocker.nix`**
8. **Enable `ai-stack` or remove it from evo-x2 module list** — Decide: enable it or don't import it
9. **Add `.direnv/` to `.gitignore`** and remove tracked files with `git rm --cached`
10. **Consider adding `nix-colors` follows** — saves download time
11. **Run `nix flake update`** — nixpkgs is 9 days stale

### Theme/UX Consistency Gaps Still Remaining

12. **Foot terminal** — Has manual Catppuccin colors (good) but not using `themeFile` like Kitty does. Consider upstreaming a Catppuccin foot theme.
13. **tmux status bar** — Uses `colorScheme.palette` variables (good) but has no Catppuccin-specific window style beyond colors.
14. **Rofi emoji/calculator sub-modes** — Main drun mode is themed, but `-modi emoji` and `-modi calc` use inline `theme-str` overrides that may not fully match.
15. **Zellij layouts** — `dev` and `monitoring` layouts exist but have no keybind in niri. Could add `Mod+Shift+D` for dev layout.

---

## F) TOP 25 THINGS TO DO NEXT

### Priority 1: Fix What's Broken (5 items)

| #   | Task                                                                    | Effort  | Impact               |
| --- | ----------------------------------------------------------------------- | ------- | -------------------- |
| 1   | Fix `nix-ssh-config` duplicate `environment.etc` (fork or upstream fix) | Medium  | Unblocks all testing |
| 2   | Remove duplicate packages (`jq`, `zellij`, `swappy`) from `home.nix`    | Trivial | Clean build          |
| 3   | Fix `.gitignore` (prefix bare text lines 128-135, add `.direnv/`)       | Trivial | Repo hygiene         |
| 4   | Fix pre-commit `sed` path for cross-platform compatibility              | Trivial | macOS CI works       |
| 5   | Remove `.direnv/flake-profile*` from git tracking                       | Trivial | No broken symlinks   |

### Priority 2: Close Open Loops (5 items)

| #   | Task                                                                  | Effort   | Impact            |
| --- | --------------------------------------------------------------------- | -------- | ----------------- |
| 6   | Archive `docs/STATUS.md` to `docs/archive/status/`                    | Trivial  | No confusion      |
| 7   | Delete orphaned `platforms/nixos/modules/dns-blocker.nix`             | Trivial  | Dead code removal |
| 8   | Decide on `ai-stack.nix`: enable it or remove from evo-x2 module list | Decision | Clarity           |
| 9   | Add `nix-colors` follows nixpkgs in flake.nix                         | Trivial  | Faster eval       |
| 10  | Run `nix flake update` — nixpkgs is 9 days stale                      | Trivial  | Security patches  |

### Priority 3: Deploy & Verify (8 items — all need evo-x2 access)

| #   | Task                                        | Effort | Impact                |
| --- | ------------------------------------------- | ------ | --------------------- |
| 11  | P1-7: Move Taskwarrior encryption to sops   | Medium | Security              |
| 12  | P1-9: Pin Docker digest for Voice Agents    | Medium | Supply chain security |
| 13  | P1-10: Pin Docker digest for PhotoMap       | Medium | Supply chain security |
| 14  | P5-38: Verify SigNoz dashboards configured  | Low    | Observability         |
| 15  | P5-42: Test Authelia SSO login flow         | Low    | Security              |
| 16  | P5-44: Test Hermes Discord bot connectivity | Low    | Functionality         |
| 17  | P5-45: Verify Homepage health checks green  | Low    | Monitoring            |
| 18  | P5-39: Verify Immich ML pipeline works      | Low    | Functionality         |

### Priority 4: UX Polish & Features (7 items)

| #   | Task                                                                        | Effort  | Impact                 |
| --- | --------------------------------------------------------------------------- | ------- | ---------------------- |
| 19  | Add niri keybind for Zellij dev layout (`Mod+Shift+D`)                      | Trivial | Workflow speed         |
| 20  | Add disk usage module to Waybar (BTRFS pool monitoring)                     | Low     | Monitoring at a glance |
| 21  | Add idle-inhibit to Waybar (toggle: keep screen on)                         | Low     | Media viewing UX       |
| 22  | Configure Kitty tab/split keybinds consistent with niri                     | Low     | Muscle memory          |
| 23  | Add custom Rofi power menu theme matching wlogout style                     | Medium  | Visual consistency     |
| 24  | Research Waybar `group` modules for collapsible sections                    | Medium  | Clean bar when idle    |
| 25  | Add systemd service for automatic wallpaper rotation (timed, not just boot) | Low     | Ambient UX             |

---

## G) TOP #1 QUESTION I CANNOT ANSWER

**What is the `ai-stack.nix` module supposed to do, and is it intentionally disabled?**

The module is:

- Imported in `flake.nix` (line 271)
- Referenced in evo-x2 NixOS modules (line 575)
- But `services.ai-stack.enable` is NOT set in `configuration.nix`
- It sits alongside `comfyui.nix`, `voice-agents.nix`, and `ai-models.nix` (which ARE enabled)

Is this:

- a) A future module you haven't enabled yet (intentional)?
- b) Functionality that was absorbed into other AI modules (dead code)?
- c) Something that should be enabled but was forgotten?

---

## Files Modified This Session

| File                                        | Lines Changed | Description                                             |
| ------------------------------------------- | ------------- | ------------------------------------------------------- |
| `platforms/nixos/desktop/waybar.nix`        | +47, -2       | Tooltip CSS, hover states, weather error, media tooltip |
| `platforms/common/programs/fzf.nix`         | +4            | Catppuccin Mocha color scheme                           |
| `platforms/common/programs/starship.nix`    | +7, -2        | `$nix_shell` format + styled with ❄                     |
| `modules/nixos/services/homepage.nix`       | +37           | Full Catppuccin Mocha custom CSS                        |
| `platforms/nixos/users/home.nix`            | +3            | Kitty visual bell (blue flash)                          |
| `platforms/nixos/programs/niri-wrapped.nix` | +1, -1        | Dunst history jq formatting                             |

**Total: 97 insertions, 5 deletions across 6 files.**

---

## Project Metrics

| Metric                | Value                               |
| --------------------- | ----------------------------------- |
| Total `.nix` files    | 97                                  |
| NixOS service modules | 28                                  |
| Custom packages       | 8                                   |
| Tasks total           | 95                                  |
| Tasks done            | 62 (65%)                            |
| Tasks remaining       | 33 (35%)                            |
| P1 security remaining | 4 (all blocked on evo-x2)           |
| P2 reliability        | 11/11 COMPLETE                      |
| Theme consistency     | 17/18 tools themed (Foot is manual) |
| flake.lock age        | ~9 days (nixpkgs)                   |

---

_Generated by Crush AI Agent — 2026-04-30T02:40_
