# Comprehensive Project Status Report

**Date**: 2026-03-30 11:18
**Session**: Overlay consolidation + dead code cleanup
**Last Commit**: `59ea476` — refactor(flake): extract overlay definitions to reduce duplication

---

## Project Metrics

| Metric                             | Value         |
| ---------------------------------- | ------------- |
| Total `.nix` files                 | 101           |
| Shell scripts in `scripts/`        | 54            |
| Flake inputs                       | 16            |
| NixOS services (dendritic modules) | 8             |
| `docs/status/` files               | 127           |
| `docs/planning/` files             | 21            |
| `docs/` total size                 | 7.8 MB        |
| Project size (excl. .git)          | 205 MB        |
| `flake.nix` lines                  | 338           |
| Scripts with `set -euo pipefail`   | 35/54 (64.8%) |
| Inline TODOs in .nix source        | 3             |

---

## A) FULLY DONE

### 1. Overlay DRY Consolidation (this session)

- Extracted Go 1.26.1 overlay into named `let` binding `goOverlay` in flake.nix
- Extracted `awWatcherOverlay` into named `let` binding
- Extracted `dnsblockdOverlay` into named `let` binding
- Removed redundant Go overlay from `darwinConfigurations` (darwin/default.nix already handles it + golangci-lint fix)
- **Before**: Go overlay copy-pasted in 3 locations, aw-watcher in 3 locations, dnsblockd in 2 locations
- **After**: Each overlay defined once in `let` bindings, referenced by name

### 2. Dead Code Removal — 17 files deleted (-1,800 lines)

- `platforms/nixos/services/` — entire directory (10 files: caddy, gitea, grafana, homepage, immich, monitoring, sops, ssh, default, dashboards/overview.json)
  - All superseded by `modules/nixos/services/` (dendritic pattern migration)
  - Imports in `configuration.nix` were already commented out
- `pkgs/go-1.26.nix` — never imported anywhere (dead since overlay was inline)
- `platforms/darwin/minimal-test.nix` — test artifact
- `platforms/darwin/test-minimal.nix` — test artifact
- `scripts/verify-hyprland.sh` — references removed Hyprland verification (189 lines)
- `scripts/verify-xwayland.sh` — references removed Xwayland verification (147 lines)
- `scripts/archive/setup-animated-wallpapers.sh` — archived wallpaper script (261 lines)

### 3. Justfile Bug Fixes

- Fixed 7 broken recipe calls in `perf-full-analysis` and `automation-setup`:
  - `just benchmark-all` → `just benchmark all`
  - `just perf-benchmark` → `just perf benchmark`
  - `just context-analyze` → `just context analyze`
  - `just context-recommend` → `just context recommend`
  - `just perf-report` → `just perf report`
  - `just perf-setup` → `just perf setup`
  - `just context-setup` → `just context setup`

### 4. Flake Health

- `nix flake check --no-build` passes cleanly
- No evaluation errors
- Both `darwinConfigurations.Lars-MacBook-Air` and `nixosConfigurations.evo-x2` evaluate successfully
- All 9 nixosModules evaluate successfully

---

## B) PARTIALLY DONE

### 1. Overlay Consolidation — dnsblockd still duplicated

- `dnsblockdOverlay` is defined as a `let` binding in flake.nix (used by nixosConfigurations)
- But `perSystem.packages` still has inline `callPackage` for dnsblockd/dnsblockd-processor (needed because perSystem overlays can't conditionally include dnsblockd for Linux-only)
- **Status**: Acceptable trade-off — perSystem needs direct callPackage since dnsblockd is Linux-only

### 2. Go Overlay — Still in darwin/default.nix

- `platforms/darwin/default.nix:64-73` still has an inline Go overlay
- This is intentional — it includes a `golangci-lint` override that uses `buildGo126Module`
- Cannot be removed because darwin/default.nix runs in a different module context than flake.nix `let` bindings
- **Status**: Minimal duplication, acceptable

### 3. Script Quality — 35% missing strict mode

- 19 of 54 scripts still missing `set -euo pipefail`
- 35 scripts have it (64.8% coverage)
- **Status**: Ongoing improvement

---

## C) NOT STARTED

### From TODO_LIST.md (75+ items tracked)

**Desktop Improvements Phase 1** (22 items, 0 done):

- Hot-reload capability (Ctrl+Alt+R)
- Privacy & Locking (7 items: blur, privacy mode, screenshot detection, etc.)
- Productivity Scripts (5 items: Quake terminal, OCR, color picker, clipboard, app spawner)
- Monitoring modules (5 items: GPU temp, CPU, memory, network, disk)
- Window Management (4 items: scratchpad, floating rules, focus follows mouse, auto back-and-forth)

**Desktop Improvements Phase 2** (21 items):

- Keyboard & Input (4), Audio & Media (7), Dev Tools (4), Desktop Environment (4)

**Desktop Improvements Phase 3** (13 items):

- Backup & Config (4), Gaming (4), Window Rules (4)

**Nix Architecture — Ghost Systems** (14 items):

- Import core/Types.nix, State.nix, Validation.nix in flake
- Enable TypeSafetySystem
- Consolidate user/path config
- Enable SystemAssertions, ModuleAssertions
- Split large files (system.nix 397 lines → 3 files)
- Replace bool with State/LogLevel enums

**Security Hardening** (2 items):

- Re-enable audit daemon (blocked by NixOS bug #483085)
- Re-enable audit kernel module (AppArmor conflicts)

**Bluetooth Setup** (8 items):

- Rebuild, reboot, pair Nest Audio, set default, test, auto-connect, range test, A2DP check

---

## D) TOTALLY FUCKED UP

### 1. Hyprland + Niri Dual Compositor Confusion

- `platforms/nixos/users/home.nix:15` imports `../desktop/hyprland.nix` with comment "RE-ENABLED for desktop functionality"
- Line 14 also imports `../programs/niri-wrapped.nix` (Niri)
- **Both compositors are active simultaneously** — unclear which is actually being used
- Hyprland packages still in `home.packages`: hyprpaper, hyprlock, hypridle, hyprpicker, hyprsunset, dunst, grimblast
- Hyprland config files still exist: `hyprland.nix` (~480 lines), `hyprland-config.nix`, `hyprland-animated-wallpaper.nix`
- Scripts still reference Hyprland: `validate-deployment.sh`, `optimize-system.sh`, `test-config.sh`
- **Impact**: Wasted packages, confused config, unclear system state

### 2. Home Manager Issue XXXX Placeholder

- `platforms/darwin/default.nix:85`: `# See: https://github.com/nix-community/home-manager/issues/XXXX`
- This has been here for months — nobody has filled in the actual issue number
- **Impact**: Dead reference, can't track the upstream bug

### 3. Root Directory Clutter

- `test_speed.py` — one-off benchmark, should be in `dev/testing/`
- `download_glm_model.py` — one-off download script, should be in `dev/testing/`
- `README.test.md` — test readme, not needed in root
- `HARDCORE_REVIEW.md` — one-time review doc, belongs in `docs/`
- `PROJECT_SPLIT_EXECUTIVE_REPORT.md` — one-time report, belongs in `docs/`
- `PARTS.md` — unclear purpose
- `CRUSH-UPDATE-GUIDE.md` — operational guide, belongs in `docs/guides/`
- `scripts/ublock-origin-setup (1).sh` — **duplicate** with space in filename

### 4. 127 Status Report Files (7.8 MB)

- Massive accumulation of status documents
- Most are one-time session summaries never referenced again
- Should be archived or pruned

---

## E) WHAT WE SHOULD IMPROVE

### Code Quality

1. **Resolve Hyprland/Niri dual compositor** — pick one, remove the other's dead code
2. **Fill in Home Manager XXXX issue** — or remove the dead reference
3. **Add `set -euo pipefail`** to remaining 19 scripts
4. **Clean root directory** — move misplaced files to proper locations
5. **Remove `scripts/ublock-origin-setup (1).sh`** — duplicate with space in filename

### Architecture

6. **Ghost Systems type safety** — 14 items tracked, none started
7. **Split large files** — `system.nix` at 397 lines, `home.nix` at 309 lines
8. **Consolidate dnsblockd packages** — still defined twice (overlay + perSystem)

### Documentation

9. **Archive old status reports** — 127 files, most stale
10. **Update TODO_LIST.md** — Phase counts don't match (says 21, actually 22)

### Security

11. **Monitor NixOS bug #483085** for audit daemon re-enablement
12. **Research AppArmor/audit kernel module compatibility**

---

## F) Top 25 Things We Should Get Done Next

### Critical (Do Now)

| # | Task                                                                                                                               | Effort | Impact |
| - | ---------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 1 | **Resolve Hyprland vs Niri** — decide which compositor to use, remove dead one's config, packages, and scripts                     | 2h     | High   |
| 2 | **Fill in Home Manager issue XXXX** or remove the dead reference at `darwin/default.nix:85`                                        | 15min  | Low    |
| 3 | **Remove duplicate `scripts/ublock-origin-setup (1).sh`**                                                                          | 1min   | Low    |
| 4 | **Move root clutter to proper locations** (`test_speed.py`, `download_glm_model.py`, `README.test.md`, `HARDCORE_REVIEW.md`, etc.) | 30min  | Medium |

### High Impact (This Week)

| #  | Task                                                  | Effort | Impact |
| -- | ----------------------------------------------------- | ------ | ------ |
| 5  | **Add `set -euo pipefail` to 19 scripts** missing it  | 30min  | Medium |
| 6  | **Import Ghost Systems core/Types.nix** in flake      | 15min  | High   |
| 7  | **Import Ghost Systems core/State.nix** in flake      | 15min  | High   |
| 8  | **Import Ghost Systems core/Validation.nix** in flake | 15min  | High   |
| 9  | **Enable TypeSafetySystem** in flake                  | 30min  | High   |
| 10 | **Add Waybar GPU temperature module** (AMD GPU)       | 1.5h   | Medium |
| 11 | **Add Waybar CPU usage module** (per-core)            | 1.5h   | Medium |

### Medium Impact (Next 2 Weeks)

| #  | Task                                                     | Effort | Impact |
| -- | -------------------------------------------------------- | ------ | ------ |
| 12 | **Add Waybar memory/network/disk modules**               | 4.5h   | Medium |
| 13 | **Create Quake Terminal dropdown script** (F12)          | 2h     | Medium |
| 14 | **Create Clipboard History Viewer**                      | 2h     | Medium |
| 15 | **Add hot-reload for Hyprland/Niri config** (Ctrl+Alt+R) | 10min  | High   |
| 16 | **Consolidate user config** (eliminate split brain)      | 45min  | High   |
| 17 | **Consolidate path config**                              | 30min  | High   |
| 18 | **Enable SystemAssertions**                              | 30min  | High   |
| 19 | **Optimize keyboard repeat rate**                        | 20min  | Low    |
| 20 | **Map Caps Lock to Escape/Control**                      | 20min  | Low    |

### Lower Priority (Next Month)

| #  | Task                                                    | Effort  | Impact |
| -- | ------------------------------------------------------- | ------- | ------ |
| 21 | **Split system.nix** (397 lines → 3 files)              | 90min   | Medium |
| 22 | **Archive old status reports** (127 files)              | 1h      | Low    |
| 23 | **Fix TODO_LIST.md phase counts** (says 21, is 22)      | 5min    | Low    |
| 24 | **Monitor NixOS bug #483085** for audit daemon          | Ongoing | Medium |
| 25 | **Research audit kernel module** AppArmor compatibility | 2-4h    | Medium |

---

## G) Top Question I Cannot Figure Out Myself

**Is Hyprland actually being used on evo-x2, or has it been fully replaced by Niri?**

Evidence for Niri being primary:

- `niri-wrapped.nix` imported in home.nix
- Niri flake input added (`sodiboo/niri-flake`)
- Niri overlay in nixosConfigurations (`inputs.niri.overlays.niri`)

Evidence for Hyprland still active:

- `hyprland.nix` imported in home.nix with "RE-ENABLED for desktop functionality"
- Full Hyprland package set still installed (hyprpaper, hyprlock, hypridle, hyprpicker, hyprsunset)
- Hyprland config files exist (~480 lines in hyprland.nix alone)
- Waybar shared between both

**Why it matters**: Resolving this determines whether we delete ~600 lines of Hyprland config, 10+ packages, and 3 more scripts — or keep maintaining dual compositor support.

---

## Build & Verification Status

| Check                                   | Status            |
| --------------------------------------- | ----------------- |
| `nix flake check --no-build`            | PASS              |
| `darwinConfigurations.Lars-MacBook-Air` | Evaluates OK      |
| `nixosConfigurations.evo-x2`            | Evaluates OK      |
| All 9 `nixosModules`                    | Evaluate OK       |
| All `perSystem.packages`                | Evaluate OK       |
| `devShells.default`                     | Evaluates OK      |
| Working tree                            | CLEAN (committed) |

---

## Session Stats

- **Files changed**: 18
- **Lines added**: 44
- **Lines removed**: 1,800
- **Net reduction**: -1,756 lines
- **Dead files deleted**: 17
- **Overlays consolidated**: 3 (Go, aw-watcher, dnsblockd)
- **Justfile bugs fixed**: 7 recipe calls
