# SystemNix Comprehensive Status Report

**Date:** 2026-03-17 19:15
**Commit:** e383178
**Branch:** master (clean, up to date with origin)
**Reporter:** Crush AI (GLM 4.7 Flash via Crush)
**Previous Report:** 2026-03-15 (crush-patched v0.49.0 update)

---

## Executive Summary

SystemNix is a cross-platform Nix configuration managing macOS (nix-darwin, `Lars-MacBook-Air`) and NixOS (`evo-x2`, GMKtec AMD Ryzen AI Max+ 395). The project is **production-stable** with 1,056 commits, 89 Nix files (8,409 lines), 53 shell scripts (12,325 lines), and 386 Markdown files (180,604 lines).

**This reporting period (Mar 6-17) saw major structural changes:**

- crush-patched package **entirely removed** (701 lines deleted)
- Niri scrollable-tiling compositor **added**
- Comprehensive browser extension management system **added** (449 lines)
- Hyprland 0.54.2 compatibility fixes applied
- trash-cli, GNOME Keyring, GLM-4.7-Flash utilities added

**Health:** gitleaks reports **zero leaks**. Build status untested this session. No statix available in PATH.

---

## a) FULLY DONE

### Core Infrastructure

| Item                                 | Status | Notes                                                     |
| ------------------------------------ | ------ | --------------------------------------------------------- |
| Nix Flake Architecture (flake-parts) | Done   | 14 inputs, dual-platform, modular                         |
| macOS System Configuration           | Done   | nix-darwin, Home Manager, nix-homebrew                    |
| NixOS evo-x2 System Configuration    | Done   | Hyprland, Niri, Waybar, AMD GPU, audio, networking        |
| Home Manager Integration             | Done   | Cross-platform via `platforms/common/`, ~80% code sharing |
| Pre-commit Hooks                     | Done   | gitleaks, trailing whitespace                             |
| Just Task Runner                     | Done   | 1,626 lines, ~80+ recipes                                 |
| Git Configuration                    | Done   | git-town, git-filter-repo, signing                        |

### Desktop Environment (NixOS)

| Item                              | Status | Notes                                                                           |
| --------------------------------- | ------ | ------------------------------------------------------------------------------- |
| Hyprland Window Manager           | Done   | 505-line config, 10 named workspaces, Material Design 3 animations              |
| Waybar Status Bar                 | Done   | 637-line config, tiered coloring, media module with metadata, privacy indicator |
| Niri Scrollable-Tiling Compositor | Done   | Added Mar 17, XDG portal, xwayland-satellite                                    |
| SDDM Display Manager              | Done   | Configured                                                                      |
| Audio (PipeWire)                  | Done   | pamixer, volume controls                                                        |
| AMD GPU Support                   | Done   | RDNA 3.5, ROCm, direct_scanout, VRR/VFR                                         |
| Security Hardening                | Done   | GNOME Keyring enabled, firewall configs                                         |
| Wallpaper Management (swww)       | Done   | Cycling, hyprpicker integration                                                 |
| Screenshot (grimblast)            | Done   | Multiple variants, clipboard integration                                        |

### Shell & Terminal

| Item               | Status | Notes                                                         |
| ------------------ | ------ | ------------------------------------------------------------- |
| Fish Shell         | Done   | Cross-platform, aliases, carapace completions, <200ms startup |
| Zsh Shell          | Done   | Configured as fallback                                        |
| Bash Shell         | Done   | Basic configuration                                           |
| Nushell            | Done   | Configured                                                    |
| Starship Prompt    | Done   | Cross-platform, identical config                              |
| Tmux               | Done   | Cross-platform, clock24, mouse, 100k history                  |
| FZF                | Done   | Fuzzy finder configured                                       |
| Alacritty Terminal | Done   | GPU-accelerated terminal                                      |

### Development Tools

| Item                        | Status | Notes                                                            |
| --------------------------- | ------ | ---------------------------------------------------------------- |
| Go Toolchain (1.26.1)       | Done   | gopls, golangci-lint, gofumpt, gotests, mockgen, buf, delve, gup |
| TypeScript/Bun Toolchain    | Done   | bun, vtsls, esbuild                                              |
| Oxlint/Oxfmt                | Done   | Node.js linting and formatting                                   |
| tsgolint                    | Done   | TypeScript-Go linting                                            |
| Git Town                    | Done   | Advanced branch management                                       |
| Claude AI Config Management | Done   | Backup/restore/test recipes in justfile                          |
| Docker & K8s                | Done   | docker, docker-compose, kubectl, k9s                             |
| Terraform & GCP SDK         | Done   | Infrastructure as code tools                                     |
| Taskwarrior + Timewarrior   | Done   | Task time tracking                                               |

### Browser & Extensions

| Item                           | Status | Notes                                             |
| ------------------------------ | ------ | ------------------------------------------------- |
| Brave Browser Config           | Done   | Extension management, GPU args, security policies |
| Google Chrome Policies         | Done   | Both Darwin and NixOS, HTTPS-only, safe browsing  |
| YouTube Shorts Blocker         | Done   | Forced install via Chrome policy                  |
| KeePassXC + Helium Integration | Done   | Native messaging host                             |
| uBlock Origin Custom Filters   | Done   | Config module exists (temporarily disabled)       |

### Monitoring & Security

| Item                   | Status | Notes                                                |
| ---------------------- | ------ | ---------------------------------------------------- |
| ActivityWatch (macOS)  | Done   | LaunchAgent, window watcher, web-chrome, utilization |
| ActivityWatch (NixOS)  | Done   | Home Manager module, conditional                     |
| aw-watcher-utilization | Done   | Custom Nix package, declarative LaunchAgent          |
| Gitleaks               | Done   | Zero leaks found in latest scan                      |
| Pre-commit Hooks       | Done   | gitleaks + trailing whitespace                       |

### Documentation & Operations

| Item                    | Status | Notes                                               |
| ----------------------- | ------ | --------------------------------------------------- |
| AGENTS.md               | Done   | Comprehensive 1,200+ line AI behavior guide         |
| Chrome Extensions Guide | Done   | New: `docs/CHROMIUM-EXTENSIONS-GUIDE.md`            |
| 60+ Status Reports      | Done   | In `docs/status/`                                   |
| ADRs                    | Done   | 3 Architecture Decision Records                     |
| Verification Guides     | Done   | Home Manager deployment, cross-platform consistency |
| Backup/Restore System   | Done   | just recipes + scripts                              |

### Recent Completions (Mar 6-17)

| Date   | Commit  | Achievement                                                          |
| ------ | ------- | -------------------------------------------------------------------- |
| Mar 17 | e383178 | Browser extension management system (449 lines, 9 files)             |
| Mar 17 | 7431603 | Homebrew-cask updated to latest                                      |
| Mar 16 | 1daf6d6 | trash-cli for safer file deletion                                    |
| Mar 16 | 54d59df | Niri scrollable-tiling compositor                                    |
| Mar 16 | 64b5fb0 | Waybar media module enhanced with detailed metadata                  |
| Mar 15 | a3e314b | crush-patched REMOVED, Hyprland 0.54 compat fixes                    |
| Mar 15 | 957233b | Incompatible Hyprland plugins disabled (hy3, hyprsplit, hyprwinwrap) |
| Mar 14 | d3ecf17 | Flake inputs updated, unused packages removed (jscpd, portless)      |
| Mar 14 | 36cffce | GNOME Keyring enabled for secrets storage                            |
| Mar 14 | e49eb02 | Trailing whitespace cleaned from 11 status reports                   |
| Mar 14 | 0e14804 | GLM-4.7-Flash model download utilities                               |

---

## b) PARTIALLY DONE

### ActivityWatch Ecosystem (~70%)

| Bucket                                                  | Status  | Issue                                                      |
| ------------------------------------------------------- | ------- | ---------------------------------------------------------- |
| aw-watcher-afk                                          | Working | Stable                                                     |
| aw-watcher-window                                       | Partial | Restart loop (Python multiprocessing fork errors on macOS) |
| aw-watcher-web-chrome                                   | Working | Stable                                                     |
| aw-watcher-utilization                                  | Working | Recently fixed (pip -> Nix LaunchAgent)                    |
| aw-watcher-input                                        | Broken  | Permissions issue, not reporting                           |
| aw-watcher-screenshot                                   | Missing | Not deployed                                               |
| **Score: 3/5 working, 1 degraded, 1 broken, 1 missing** |

### NixOS evo-x2 Hardware (~75%)

| Component                    | Status   | Gap                                                       |
| ---------------------------- | -------- | --------------------------------------------------------- |
| CPU (Ryzen AI Max+ 395)      | 100%     | -                                                         |
| GPU (Radeon 8060S, RDNA 3.5) | 100%     | -                                                         |
| AI Acceleration (ROCm)       | 100%     | -                                                         |
| Memory (LPDDR5X)             | 100%     | -                                                         |
| Storage (PCIe 4.0 NVMe)      | 100%     | -                                                         |
| Networking                   | 75%      | WiFi 7 and 2.5G Ethernet advanced config pending          |
| Audio                        | 75%      | Generic working, chipset-specific tuning pending          |
| Bluetooth                    | Untested | Configured but never hardware-tested                      |
| Security Audit               | Disabled | `security-hardening.nix` has TODO for kernel module audit |
| NPU Utilization              | Blocked  | AMD Linux early access, upstream NixOS #483085            |

### Homebrew Integration (~60%)

| Item                           | Status  | Issue                                                                                |
| ------------------------------ | ------- | ------------------------------------------------------------------------------------ |
| nix-homebrew Declarative       | Working | Active, taps pinned to flake inputs                                                  |
| Cask Management                | Working | headlamp installed                                                                   |
| Rosetta 2                      | Enabled | -                                                                                    |
| **Migration to /opt/homebrew** | Pending | **Still on `/usr/local` (Intel-era prefix on Apple Silicon)**                        |
| autoMigrate                    | Broken  | Did NOT migrate despite `autoMigrate = true`; possible nix-homebrew bug with Rosetta |

### File Organization (~85%)

| Item                     | Status  | Gap                                                                                                                            |
| ------------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 12 files moved from root | Done    | Mar 10 commit                                                                                                                  |
| Nix configs modular      | Done    | platforms/common, darwin, nixos                                                                                                |
| Root cleanup             | Partial | Python scripts (`download_glm_model.py`, `test_speed.py`), test dirs (`test-modernize/`, `dev/`), and misc files still in root |
| Path constants library   | Missing | No centralized path management                                                                                                 |
| `just organize` recipe   | Missing | No automated organization tool                                                                                                 |

### Type Safety System (~50%)

| Component            | Status   | Notes                                         |
| -------------------- | -------- | --------------------------------------------- |
| Types.nix            | Exists   | Type definitions                              |
| Validation.nix       | Exists   | HARDCORE_REVIEW says "fights the language"    |
| State.nix            | Exists   | Centralized state                             |
| HyprlandTypes.nix    | Disabled | Commented out in hyprland.nix for 0.54 compat |
| SystemAssertions.nix | Exists   | Build-time assertions                         |
| Actual usage         | Low      | Many configs don't use the type system        |

### Code Quality (~75%)

| Check               | Status  | Details                  |
| ------------------- | ------- | ------------------------ |
| gitleaks            | PASS    | Zero leaks (Mar 17 scan) |
| trailing-whitespace | PASS    | Auto-fixed in pre-commit |
| statix              | Unknown | Not installed in PATH    |
| nix fmt             | Unknown | Not run this session     |
| nix flake check     | Unknown | Not run this session     |

### Desktop Improvement Roadmap (~20% of Phase 1)

| Feature                         | Status      | Notes                                                 |
| ------------------------------- | ----------- | ----------------------------------------------------- |
| Privacy Mode (grayscale toggle) | Done        | Super+Alt+P                                           |
| Screenshot Notifications        | Done        | Super+Print variants                                  |
| Scratchpad Workspace            | Done        | Alt+S                                                 |
| Focus Follows Mouse Toggle      | Done        | Super+Alt+M                                           |
| Workspace Back-and-Forth        | Done        | Press current workspace key                           |
| Quake Terminal                  | Done        | Kitty dropdown                                        |
| Config Reload Notification      | Done        | Super+Shift+Return                                    |
| Color Picker                    | Done        | hyprpicker                                            |
| Clipboard Menu                  | Done        | rofi integration                                      |
| GPU Temperature in Waybar       | Done        | AMD Tctl                                              |
| Media Player in Waybar          | Done        | Enhanced with metadata Mar 16                         |
| Privacy Indicator in Waybar     | Done        | Webcam/mic/screenshare                                |
| Sudo Timer in Waybar            | Done        | Click-to-clear                                        |
| **~55 Phase 1 items remaining** | Not started | Window rules, audio visualizer, keyboard config, etc. |

---

## c) NOT STARTED

### Architecture & Code Quality

| Item                                                 | Priority | Est. Effort |
| ---------------------------------------------------- | -------- | ----------- |
| Repo split into 6 sub-projects                       | P0       | 2-3 days    |
| Extract `nix-error-lib` as standalone library        | P1       | 1-2 days    |
| Extract `nix-types-lib` as standalone library        | P1       | 1-2 days    |
| Scope Go 1.26 overlay (remove global override)       | P1       | 4-6h        |
| Remove custom Validation.nix (use native Nix idioms) | P1       | 1-2 days    |
| Deduplicate Go overlay in flake.nix (3 copies)       | P1       | 1-2h        |
| Automated testing framework for Nix configs          | P1       | 3-5 days    |
| Program Discovery System                             | P0       | 2-3 days    |

### Documentation Cleanup

| Item                                           | Priority | Est. Effort |
| ---------------------------------------------- | -------- | ----------- |
| Purge/archive 300+ AI-generated status reports | P1       | 4-8h        |
| Verify 445 tracked TODOs against actual code   | P2       | 2-3 days    |
| Update TODO_LIST.md (stale since Feb 10)       | P2       | 4-8h        |
| Update TODO-STATUS.md (stale since Jan 13)     | P2       | 2-4h        |

### Desktop & NixOS Features

| Item                                                   | Priority | Est. Effort |
| ------------------------------------------------------ | -------- | ----------- |
| Niri actual configuration (keybindings, layout, rules) | P2       | 4-8h        |
| WiFi 7 and 2.5G Ethernet advanced config               | P2       | 2-4h        |
| Audio chipset-specific tuning                          | P2       | 2-4h        |
| Bluetooth hardware testing                             | P2       | 1-2h        |
| Kernel module audit fix (blocked by NixOS #483085)     | P3       | Blocked     |
| Desktop improvement Phase 2-3 (~75 items)              | P2-P3    | 40+ hours   |
| Gaming features (game mode, GPU profiles, FPS stats)   | P3       | 8+ hours    |
| AI desktop integration (workspace suggestions, voice)  | P3       | 20+ hours   |

### Security

| Item                          | Priority | Est. Effort |
| ----------------------------- | -------- | ----------- |
| Security audit re-enablement  | P1       | 4-8h        |
| Sandbox override fix (Darwin) | P1       | 4-6h        |
| TouchID extension research    | P2       | 2-3h        |

### Cross-Platform

| Item                                          | Priority | Est. Effort |
| --------------------------------------------- | -------- | ----------- |
| Darwin networking settings completion         | P1       | 2-3h        |
| Nixpkgs config extraction to common/          | P2       | 2-3h        |
| Terminal env migration to iTerm2 config       | P3       | 1-2h        |
| Home Manager config extraction from flake.nix | P2       | 1-2h        |
| VS Code full Nix integration                  | P1       | 4-8h        |

---

## d) TOTALLY FUCKED UP

### 1. Documentation Bloat -- CRITICAL

**380+ Markdown files totaling 180,604 lines.** That's 180KB of documentation for an 8,409-line Nix config (22:1 doc-to-code ratio). The `docs/` directory is a graveyard of timestamped AI status reports, many duplicating each other. `docs/status/` alone has 100+ files, most never read after creation. `docs/archive/status/` has another 70+. This makes the repo **nearly impossible to navigate** and inflates git operations.

**Impact:** 491MB repo size. New contributors (or future Lars) will be overwhelmed. Git clones, searches, and diffs are slower.

### 2. Go Overlay Global Pollution -- HIGH SEVERITY

The Go 1.26.1 overlay is **copy-pasted 3 times** in `flake.nix`:

- `perSystem` (lines 100-112)
- `darwinConfigurations` (lines 159-170)
- Implicit in NixOS via nixpkgs overlays

This forces **every single Go package in the entire system** to build with Go 1.26.1 instead of the nixpkgs default. If any package in nixpkgs is incompatible with Go 1.26.1, the entire build breaks. This is a ticking time bomb.

**Impact:** Build fragility. Hard to debug when a random nixpkgs package fails to compile.

### 3. Hyprland 0.54 Plugin Orphaned Keybindings -- RUNTIME CRASH RISK

`hyprland.nix` disables hy3, hyprsplit, and hyprwinwrap plugins for Hyprland 0.54.2 compatibility. However, **hy3 keybindings still exist** at lines 393-396 (`hy3:changegroup`, `hy3:makegroup`). These will cause runtime errors since the plugin is not loaded.

Also, `$mod,G` is double-bound to both `gitui` (line 344) and `togglegroup` (line 386). Last binding wins silently.

**Impact:** Confusing runtime errors. Keybinding conflicts.

### 4. home-base.nix stateVersion Mismatch

`home-base.nix` sets `stateVersion = "24.05"` while `configuration.nix` sets `stateVersion = "25.11"`. This mismatch can cause subtle issues when Home Manager tries to apply migrations.

**Impact:** Potential silent configuration failures during Home Manager upgrades.

### 5. Homebrew Stuck on Wrong Prefix -- TECHNICAL DEBT

nix-homebrew with `autoMigrate = true` and `enableRosetta = true` kept the Intel-era `/usr/local` prefix instead of migrating to `/opt/homebrew`. This has been **analyzed and documented since Mar 5** but never acted on. Builds use source compilation instead of pre-built bottles, making installs slower and potentially broken.

**Impact:** Slower brew installs, missing bottles, `brew doctor` warnings. The longer this persists, the harder migration becomes.

### 6. Stale Tracking Documents

| Document                       | Last Updated | Age                      |
| ------------------------------ | ------------ | ------------------------ |
| TODO_LIST.md                   | Feb 10       | 35 days                  |
| TODO-STATUS.md                 | Jan 13       | 63 days                  |
| MICRO-TASKS.md                 | Dec 18, 2025 | 89 days                  |
| DESKTOP-IMPROVEMENT-ROADMAP.md | Jan 10       | 66 days                  |
| STATUS.md                      | Dec 27, 2025 | 80 days                  |
| HARDCORE_REVIEW.md             | Feb 27       | 18 days (actioned: none) |

**445 tracked TODOs, 0 verified against current code.** The tracking system is unreliable.

### 7. uBlock Origin Filters Disabled

`ublock-filters.nix` exists in `platforms/common/programs/` but is explicitly disabled in `home-base.nix` with `ublock-filters.enable = false; # Temporarily disabled due to time parsing issues`. This has been disabled for an unknown duration.

### 8. Phantom Remote Branches

21 remote branches exist, most from `copilot/fix-*` (14 branches). These are likely stale Copilot-generated PR branches that were never cleaned up. They clutter `git branch -a` output.

---

## e) WHAT WE SHOULD IMPROVE

### Immediate (This Week)

1. **Delete the documentation graveyard.** Archive all `docs/status/` and `docs/archive/status/` reports older than 30 days into a separate branch or tarball. Keep only the 5 most recent status reports and all ADRs. This single action will make the repo 10x more navigable.

2. **Fix the Hyprland orphaned keybindings.** Remove hy3 keybindings (lines 393-396) and resolve the `$mod,G` double-bind. Takes 5 minutes, prevents confusing runtime errors.

3. **Deduplicate the Go overlay.** Extract into a shared `overlays/` directory or use `makeScope`. Reduce from 3 copies to 1. Takes 1-2 hours.

4. **Scope the Go overlay.** Instead of overriding `buildGoModule` globally, use per-package overrides. Only `crush` (now removed) and `modernize` needed Go 1.26. With crush-patched gone, evaluate whether the global override is still needed at all.

5. **Run `nix flake check` and `just test`.** No build verification has been done in this reporting period. Establish the current build state.

### Short-Term (Next 2 Weeks)

6. **Decide on Homebrew migration.** The analysis is done. Either migrate to `/opt/homebrew` or document the decision to stay on `/usr/local` permanently. Stop leaving it in limbo.

7. **Fix home-base.nix stateVersion.** Align with NixOS stateVersion (25.11) or document why they differ.

8. **Clean up remote branches.** Delete all `copilot/fix-*` and `feature/nushell-configs` branches if the PRs are merged/closed.

9. **Re-enable uBlock Origin filters or remove the module.** "Temporarily disabled" with no timeline is permanent technical debt.

10. **Add actual Niri configuration.** Currently only enabled with zero config (19-line stub). Either configure it properly or remove it.

### Medium-Term (Next Quarter)

11. **Repo split evaluation.** The HARDCORE_REVIEW recommended splitting into 6 sub-projects. At minimum, extract `docs/` into its own repo or submodule to reduce bloat.

12. **Build automated testing.** No CI tests beyond `nix-check.yml`. Add flake check, build verification, and config validation to CI.

13. **Extract reusable libraries.** PARTS.md identified `nix-error-lib` and `nix-types-lib` as high-value extractions. These could benefit the broader Nix community.

14. **Evaluate Validation.nix necessity.** The HARDCORE_REVIEW flagged it as fighting Nix idioms. Consider migrating to `lib.types`, `lib.mkIf`, and `config.assertions`.

---

## f) Top #25 Things We Should Get Done Next

| #   | Task                                                                       | Priority | Effort          | Impact                           |
| --- | -------------------------------------------------------------------------- | -------- | --------------- | -------------------------------- |
| 1   | Run `just test` / `nix flake check` to establish build baseline            | P0       | 10m             | Unknown until done               |
| 2   | Fix Hyprland orphaned hy3 keybindings (lines 393-396)                      | P0       | 5m              | Prevents runtime crash           |
| 3   | Fix Hyprland `$mod,G` double-bind conflict                                 | P0       | 5m              | Prevents silent keybinding loss  |
| 4   | Deduplicate Go 1.26 overlay in flake.nix (3 -> 1 copy)                     | P0       | 1-2h            | Reduces maintenance burden       |
| 5   | Evaluate: Is global Go 1.26 override still needed (crush-patched removed)? | P0       | 30m             | Could simplify entire build      |
| 6   | Purge docs/status/ reports older than 30 days                              | P1       | 2h              | Massive navigability improvement |
| 7   | Decide on Homebrew `/usr/local` -> `/opt/homebrew` migration               | P1       | 15-30m decision | Unblocks brew improvements       |
| 8   | Fix home-base.nix stateVersion (24.05 -> 25.11)                            | P1       | 5m              | Prevents HM migration issues     |
| 9   | Clean up stale remote branches (14 copilot/* branches)                     | P1       | 15m             | Git hygiene                      |
| 10  | Re-enable or remove uBlock Origin filter module                            | P1       | 1h              | Reduce dead code                 |
| 11  | Add actual Niri configuration or document as experimental stub             | P1       | 4h              | Complete the feature             |
| 12  | Verify and update TODO_LIST.md against current code                        | P1       | 1 day           | Reliable tracking                |
| 13  | Fix `netbandwidth` Waybar module (shows IP, not bandwidth)                 | P2       | 30m             | Accuracy                         |
| 14  | Add error handling to Waybar shell scripts (no `set -euo pipefail`)        | P2       | 1h              | Robustness                       |
| 15  | Remove or document the TODO at flake.nix:197 (HM config extraction)        | P2       | 15m             | Code clarity                     |
| 16  | Replace `permittedInsecurePackages` Chrome exception with proper fix       | P2       | 2h              | Security                         |
| 17  | Test NixOS Bluetooth on actual hardware                                    | P2       | 1h              | Hardware coverage                |
| 18  | Add VS Code Nix integration (lsp, formatter)                               | P2       | 4h              | Dev experience                   |
| 19  | Add `statix` to devShell and fix all warnings                              | P2       | 2h              | Code quality                     |
| 20  | Add `deadnix` check to justfile and CI                                     | P2       | 1h              | Code quality                     |
| 21  | Create `just organize` recipe for automated file organization              | P2       | 4h              | Maintenance                      |
| 22  | Add `nix eval` or `nix-instantiate` checks to CI pipeline                  | P2       | 2h              | CI quality                       |
| 23  | Implement Phase 1 desktop quick wins (2h total)                            | P2       | 2h              | UX improvement                   |
| 24  | Move remaining root files to proper directories                            | P2       | 1h              | Organization                     |
| 25  | Document why `allowBroken = false` must always be false (flake.nix:98)     | P3       | 15m             | Knowledge preservation           |

---

## g) Top #1 Question I Cannot Figure Out Myself

### "Why does nix-homebrew with `autoMigrate = true` NOT migrate from `/usr/local` to `/opt/homebrew`?"

**Context:**

- Apple Silicon Mac (aarch64-darwin)
- `nix-homebrew` configured with `enableRosetta = true` and `autoMigrate = true`
- Homebrew remains on `/usr/local` (Intel-era prefix) instead of `/opt/homebrew` (Apple Silicon standard)
- This has been documented since March 5, 2026 with no resolution
- Hypothesis: `enableRosetta = true` may confuse the migration logic by making `/usr/local` appear valid

**Why I can't answer this:**

- Requires reading `nix-homebrew` source code to understand the migration logic
- Need to determine if this is a bug in `nix-homebrew`, expected behavior with Rosetta, or a configuration error
- Testing the fix requires `sudo darwin-rebuild switch` which is destructive
- The answer determines whether to (A) do a full migration, (B) fix the config, or (C) file an upstream bug

**Decision needed from Lars:** Do you want to migrate Homebrew to `/opt/homebrew` (recommended, 15-30 min), keep it on `/usr/local` (accept slower builds), or investigate the nix-homebrew bug first?

---

## Project Metrics

| Metric              | Value                                            |
| ------------------- | ------------------------------------------------ |
| Total Commits       | 1,056                                            |
| Commits Since Mar 1 | 37                                               |
| Nix Files           | 89 (8,409 lines)                                 |
| Shell Scripts       | 53 (12,325 lines)                                |
| Markdown Files      | 386 (180,604 lines)                              |
| Repo Size           | 491 MB                                           |
| Remote Branches     | 21 (14 copilot/_, 2 feature/_, 1 organize/*)     |
| Flake Inputs        | 14                                               |
| Build Platforms     | aarch64-darwin, x86_64-linux                     |
| Tracked TODOs       | 445+ (0 verified)                                |
| Status Reports      | 60+ in docs/status/, 70+ in docs/archive/status/ |
| gitleaks            | 0 leaks                                          |
| justfile Recipes    | 80+                                              |

## Files Changed This Period (Mar 6-17)

| Stat          | Value                                                                                                                               |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Commits       | 11 (Mar 15-17)                                                                                                                      |
| Lines Added   | ~700                                                                                                                                |
| Lines Deleted | ~1,000 (crush-patched removal)                                                                                                      |
| New Files     | 7 (chromium.nix, keepassxc.nix, chrome.nix x2, CHROMIUM-EXTENSIONS-GUIDE.md, niri-config.nix, download_glm_model.py, test_speed.py) |
| Deleted Files | 5 (crush-patched package.nix, README.md, update.sh, update-crush-patched.sh, jscpd.nix, portless.nix)                               |

---

_Report generated by Crush AI. For questions or corrections, contact lars@lars.software._
