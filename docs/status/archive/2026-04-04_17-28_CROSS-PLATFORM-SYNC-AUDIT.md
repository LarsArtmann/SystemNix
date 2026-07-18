# Comprehensive Cross-Platform Sync Audit & Project Status

**Date:** 2026-04-04 17:28
**Author:** Crush AI Agent
**Scope:** Full macOS (Darwin) vs NixOS configuration sync audit
**Working Tree:** Clean (no uncommitted changes)

---

## Executive Summary

The SystemNix project has achieved a solid cross-platform architecture with ~80% configuration shared via `platforms/common/`. However, this audit uncovered **1 resolved-but-previously-broken issue**, **5 unintended drift areas**, **4 code duplication issues**, and **several opportunities for improvement**. The codebase is functional but has accumulated technical debt from rapid feature development.

---

## A) FULLY DONE ✅

### Cross-Platform Architecture

- **Home Manager shared modules** — `platforms/common/home-base.nix` properly imports all shared program configs
- **Git configuration** — Single source in `common/programs/git.nix` with aliases, signing, LFS, git-town, and ignores
- **Shell parity** — Fish, Zsh, Bash all use `shell-aliases.nix` for shared aliases with platform-specific `lib.mkAfter` overrides
- **Starship prompt** — Identical Catppuccin Mocha theme, performance-optimized, with nix-colors integration
- **Tmux** — Cross-platform config with Catppuccin colors, resurrect plugin, SystemNix keybindings
- **FZF** — Cross-platform with rg integration, all shell integrations enabled
- **Package management** — `common/packages/base.nix` with `lib.optionals stdenv.isLinux/isDarwin` for platform scoping
- **Fonts** — `common/packages/fonts.nix` with nerd fonts, noto fonts, Linux-only bibata cursors
- **Nix settings** — `common/core/nix-settings.nix` with Darwin override only for sandbox=false
- **KeePassXC** — Full cross-platform support with Chromium AND Helium browser native messaging manifests
- **SSH config** — Migrated to `nix-ssh-config` flake input with Home Manager module
- **Chrome extension management** — YT Shorts Blocker force-installed on both platforms (different mechanisms)
- **uBlock filters** — Cross-platform filter management with LaunchAgent (Darwin) and systemd timer (NixOS)
- **Pre-commit config** — Shared validation hooks for Nix, shell, and dependency conflicts
- **Go toolchain** — Go 1.26.1 overlay applied in flake.nix, available on both platforms
- **Crush AI config** — Deployed via flake input to both platforms via `home.file`

### NixOS-Specific (Complete)

- Niri scrollable-tiling compositor with declarative config
- Waybar status bar with Catppuccin Mocha theme
- Kitty + Foot terminals with Catppuccin themes
- GTK/Qt theming (Catppuccin Mocha Compact Lavender)
- Dunst notification daemon with Catppuccin colors
- BTRFS snapshots via Timeshift
- AMD GPU + NPU drivers
- DNS blocker with unbound
- SigNoz observability platform
- Gitea repository mirroring
- Immich photo management
- Caddy reverse proxy
- SOPS secrets management
- SDDM display manager with SilentSDDM theme

### Darwin-Specific (Complete)

- TouchID PAM for sudo with tmux reattach
- Keychain auto-lock (5 min inactivity)
- LaunchAgents: ActivityWatch, SublimeText sync, Crush update, aw-watcher-utilization
- macOS Application Firewall enabled
- Homebrew integration via nix-homebrew
- File associations via duti activation scripts
- Finder settings (list view, status bar, path bar)

---

## B) PARTIALLY DONE ⚠️

### 1. SSH Host Configuration

- **Status:** NixOS has 6 hosts, macOS has 2 hosts
- **What works:** Both platforms have `onprem` and `evo-x2`
- **What's missing:** macOS lacks `private-cloud-hetzner-0` through `private-cloud-hetzner-3`
- **Impact:** Cannot SSH to Hetzner servers by name from macOS
- **Fix:** Extract SSH hosts to common module or duplicate in Darwin home.nix

### 2. Chrome Policy Management

- **Status:** Both platforms force-install YT Shorts Blocker with similar security policies
- **What's different:** NixOS has `RestoreOnStartup`, `BookmarkBarEnabled`, `DefaultBrowserSettingEnabled`
- **Darwin gap:** Policy file at `/etc/chrome/policies/managed/` requires manual `sudo chrome-apply-policies`
- **Impact:** Darwin Chrome policies may not be consistently applied

### 3. Cross-Platform Tool Availability

- **gitui** (terminal git TUI) — NixOS only
- **signal-desktop** — NixOS only (may be intentional — no macOS Nix package)
- **zed-editor** — NixOS only (may be intentional — desktop Linux)
- **zellij** — NixOS only in `home.packages` (but also in `linuxUtilities` in base.nix)

---

## C) NOT STARTED ❌

### Potential Improvements Not Yet Addressed

1. **Common color scheme module** — Both platforms define identical `colorScheme`/`colorSchemeLib` options
2. **SSH hosts consolidation** — No shared SSH host list exists
3. **Darwin shells.nix cleanup** — Double-imports of `fish.nix` and `bash.nix` that are already in `home-base.nix`
4. **jq package duplication** — In both `common/packages/base.nix` and NixOS `home.packages`
5. **Flake-level `allowUnfree` vs curated predicate** — Contradictory policies not reconciled
6. **Go overlay deduplication** — Same overlay defined in flake.nix AND darwin/default.nix

---

## D) TOTALLY FUCKED UP 💥

### Nothing Currently Broken

The working tree is clean, no merge conflicts exist, and the last build was successful (per recent commit history). The SSH migration that caused issues earlier this session has been resolved — `nix-ssh-config.sshKeys.lars` is properly used in `configuration.nix`.

**However**, there is a **latent risk**:

1. **Go overlay duplication** — If someone updates one without the other, Darwin and NixOS could get different Go versions. Currently both point to 1.26.1 but they're maintained independently.

2. **nixpkgs config contradiction** — `flake.nix` sets `allowUnfree = true` (blanket), while `common/core/nix-settings.nix` sets `allowUnfreePredicate` (curated list). The flake.nix blanket overrides the curated list, making the predicate dead code. This means the curated list gives a **false sense of security**.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Extract SSH hosts to `nix-ssh-config` or common module** — Eliminates the macOS/NixOS drift entirely
2. **Extract color scheme options to common module** — Single source of truth
3. **Remove Darwin Go overlay** — Already handled by flake.nix `perSystem._module.args.pkgs`
4. **Reconcile nixpkgs allowUnfree** — Pick ONE approach (blanket or curated) and use it everywhere
5. **Fix Darwin shells.nix double-imports** — Remove the `imports` list since `home-base.nix` already handles it

### Code Quality

6. **Remove `jq` from NixOS `home.packages`** — Already in `common/packages/base.nix`
7. **Consider moving `gitui` to `common/packages/base.nix`** — Works on both platforms
8. **Audit all `home.packages` in both platforms** for tools that should be shared
9. **Create a cross-platform sync test** — CI check that compares key config aspects

### Documentation

10. **Update AGENTS.md** — Reflect current `nix-ssh-config` migration status
11. **Add ADR for SSH configuration approach** — Document why flake input vs inline
12. **Document intentional vs unintentional platform differences**

---

## F) TOP 25 THINGS TO DO NEXT 🎯

### Priority 1: Fix Unintended Drift (High Impact, Low Effort)

| #   | Task                                                                                 | Effort | Impact |
| --- | ------------------------------------------------------------------------------------ | ------ | ------ |
| 1   | Add Hetzner SSH hosts to macOS `home.nix` or extract to common                       | 15min  | High   |
| 2   | Remove Darwin Go overlay from `darwin/default.nix` (redundant with flake.nix)        | 5min   | Medium |
| 3   | Fix Darwin `shells.nix` double-imports of fish.nix and bash.nix                      | 5min   | Medium |
| 4   | Remove `jq` from NixOS `home.packages` (duplicate of base.nix)                       | 2min   | Low    |
| 5   | Reconcile `allowUnfree` — remove dead `allowUnfreePredicate` or enforce curated list | 10min  | Medium |

### Priority 2: Consolidation & Deduplication

| #   | Task                                                                      | Effort | Impact |
| --- | ------------------------------------------------------------------------- | ------ | ------ |
| 6   | Extract `colorScheme`/`colorSchemeLib` options to common module           | 20min  | Medium |
| 7   | Move `gitui` from NixOS-only to `common/packages/base.nix`                | 5min   | Low    |
| 8   | Create common SSH hosts list (or use nix-ssh-config for all hosts)        | 30min  | High   |
| 9   | Audit NixOS `home.packages` for other tools that should be cross-platform | 20min  | Medium |
| 10  | Unify Chrome policy configuration approach across platforms               | 30min  | Medium |

### Priority 3: Architecture Improvements

| #   | Task                                                                        | Effort | Impact |
| --- | --------------------------------------------------------------------------- | ------ | ------ |
| 11  | Add CI check for cross-platform config drift (automated sync audit)         | 2hr    | High   |
| 12  | Extract Darwin Chrome policies from etc to proper nix-darwin module         | 1hr    | Medium |
| 13  | Move signal-desktop to common packages (if macOS Nix package available)     | 15min  | Low    |
| 14  | Standardize terminal multiplexer (zellij vs tmux — both installed on NixOS) | 30min  | Medium |
| 15  | Add statix + deadnix to CI pipeline for automated Nix linting               | 1hr    | Medium |

### Priority 4: Quality of Life

| #   | Task                                                                       | Effort | Impact |
| --- | -------------------------------------------------------------------------- | ------ | ------ |
| 16  | Create `just sync-audit` command to run this analysis on demand            | 1hr    | High   |
| 17  | Add NixOS-only packages to `linuxUtilities` instead of `home.packages`     | 20min  | Low    |
| 18  | Document all intentional platform differences in AGENTS.md                 | 30min  | Medium |
| 19  | Verify Darwin Chrome policies are actually applied (test)                  | 15min  | Medium |
| 20  | Add shell alias `ssh-hetzner` as cross-platform alternative to named hosts | 10min  | Low    |

### Priority 5: Long-term

| #   | Task                                                                   | Effort | Impact |
| --- | ---------------------------------------------------------------------- | ------ | ------ |
| 21  | Migrate darwin/default.nix to use flake-parts perSystem like NixOS     | 3hr    | Medium |
| 22  | Create home-manager test harness for cross-platform validation         | 4hr    | High   |
| 23  | Investigate nix-darwin native Chrome policy support                    | 1hr    | Medium |
| 24  | Consider merging darwin/nixos shell init into common with conditionals | 2hr    | Medium |
| 25  | Build NixOS config from macOS (remote deploy testing)                  | 2hr    | Medium |

---

## G) TOP QUESTION I CANNOT ANSWER 🤔

**#1: Should the Hetzner SSH hosts be accessible from your MacBook?**

The 4 Hetzner servers (`private-cloud-hetzner-0` through `3`) are only in the NixOS config. I cannot determine if this is:

- **Intentional** — You only SSH to Hetzner from evo-x2 (jump host pattern)
- **An oversight** — You want direct access from macOS too

This determines whether to:

- (a) Add them to Darwin's SSH config
- (b) Extract to a shared module
- (c) Leave as NixOS-only

---

## File Inventory: What Changed

This report is new — no files were modified during this audit.

## Audit Methodology

1. Read all 40+ configuration files across `platforms/common/`, `platforms/darwin/`, and `platforms/nixos/`
2. Compared Home Manager imports, packages, programs, services, session variables
3. Checked flake.nix for overlay and module wiring
4. Verified no merge conflict markers exist
5. Ran `nix flake check --no-build` for syntax validation
6. Cross-referenced with AGENTS.md documented architecture

---

_Audit completed at 2026-04-04 17:28 by Crush AI Agent_
