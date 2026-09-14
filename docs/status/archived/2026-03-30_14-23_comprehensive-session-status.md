# Comprehensive Project Status Report

**Date**: 2026-03-30 14:23
**Session**: Continuation — DNS LAN, block page TLS, lint fixes, cleanup

---

## Project Metrics

| Metric                             | Value         |
| ---------------------------------- | ------------- |
| Total `.nix` files                 | 93            |
| Shell scripts                      | 54            |
| Scripts with `set -euo pipefail`   | 49/54 (90.7%) |
| Flake inputs                       | 16            |
| NixOS services (dendritic modules) | 8             |
| `docs/status/` files               | 133           |
| `flake.nix` lines                  | 340           |
| Inline TODOs in `.nix` source      | 2             |
| `nix flake check`                  | PASS          |
| `statix check`                     | PASS          |
| `alejandra`                        | PASS          |

---

## A) FULLY DONE

### Overlay DRY Consolidation

- Go 1.26.1, aw-watcher-utilization, dnsblockd overlays extracted to `let` bindings in flake.nix
- Eliminated copy-paste across darwinConfigurations and nixosConfigurations
- Removed redundant Go overlay from darwinConfigurations (darwin/default.nix handles it + golangci-lint)

### Dead Code Removal (17 files, -1800 lines)

- `platforms/nixos/services/` — entire directory (10 files) superseded by `modules/nixos/services/`
- `pkgs/go-1.26.nix` — never imported
- `platforms/darwin/minimal-test.nix`, `test-minimal.nix` — test artifacts
- `scripts/verify-hyprland.sh`, `verify-xwayland.sh`, `archive/setup-animated-wallpapers.sh`

### DNS LAN Access Rewrite (comprehensive)

- DNS blocker: bind to LAN interface (0.0.0.0 with 192.168.1.0/24 access)
- Block IP: 127.0.0.2 → 192.168.1.163 on enp1s0
- Block ports: 8080/8443 → 80/443 for transparent blocking
- Caddy: bind virtual hosts to 192.168.1.162 for LAN access
- TLS certificate generation for HTTPS block page
- Waybar DNS stats: URL updated to 127.0.0.1:9090
- Service health check URLs updated
- dnsblockd Go: fallback domain fix

### Statix W20 Fix (immich.nix)

- Consolidated 4 repeated `systemd` key assignments into single `systemd = { ... }` block
- All pre-commit hooks now pass cleanly

### Home Manager XXXX Issue Resolved

- Replaced placeholder with actual issue #6036 at `darwin/default.nix:85`
- Issue: darwin user home dir requirement when using home-manager as module

### Root Directory Cleanup

- Moved root-level markdown files to `docs/` (CRUSH-UPDATE-GUIDE, HARDCORE_REVIEW, etc.)
- Consolidated guides/ directory into main docs/

---

## B) PARTIALLY DONE

### Script Strict Mode: 49/54 (90.7%)

- **49 scripts have `set -euo pipefail`** (complete)
- **7 scripts have NO `set` at all** (need full addition after shebang):
  - `scripts/apply-config.sh`
  - `scripts/health-dashboard.sh`
  - `scripts/nix-diagnostic.sh`
  - `scripts/shell-context-detector.sh`
  - `scripts/smart-fix.sh`
  - `scripts/test-nixos-config.sh`
  - `scripts/test-nixos.sh`

### Overlay Consolidation: 1 duplication remains

- `dnsblockdOverlay` defined as `let` binding but perSystem packages still use inline `callPackage`
- Acceptable trade-off: perSystem can't conditionally include Linux-only overlays

---

## C) NOT STARTED

### Ghost Systems Type Safety (14 items)

- Import core/Types.nix, State.nix, Validation.nix in flake
- Enable TypeSafetySystem
- Consolidate user/path config
- Enable SystemAssertions, ModuleAssertions
- Split large files (system.nix 397 lines → 3 files)

### Desktop Improvements (~55 items across 3 phases)

- Phase 1 (22 items): hot-reload, privacy, productivity scripts, monitoring, window management
- Phase 2 (19 items): keyboard/input, audio/media, dev tools, desktop env
- Phase 3 (43 items): backup/config, gaming, window rules, AI integration

### Security Hardening (2 items blocked)

- Re-enable audit daemon (blocked by NixOS bug #483085)
- Re-enable audit kernel module (AppArmor conflicts)

---

## D) ISSUES FOUND

### Hyprland + Niri Dual Compositor

- `platforms/nixos/users/home.nix:15` imports `hyprland.nix` alongside `niri-wrapped.nix`
- Both compositors active simultaneously — unclear which is primary
- Hyprland packages still installed: hyprpaper, hyprlock, hypridle, hyprpicker, hyprsunset
- Hyprland config files still exist (~480 lines in hyprland.nix)
- 3+ scripts still reference Hyprland: validate-deployment.sh, optimize-system.sh, test-config.sh
- Waybar module `hyprland/workspaces` references Hyprland

### 133 Status Report Files (7.9 MB)

- Massive accumulation of one-time session summaries
- Most never referenced again
- Should be archived or pruned

### TODO_LIST.md Summary Counts Wrong

- Phase 1: says 21, actually 22
- Phase 2: says 21, actually 19
- Phase 3: says 13, actually 43
- Bluetooth section missing from summary table

---

## E) WHAT WE SHOULD IMPROVE

### Code Quality

1. Add `set -euo pipefail` to remaining 7 scripts
2. Resolve Hyprland vs Niri dual compositor
3. Fix TODO_LIST.md summary counts

### Architecture

4. Ghost Systems type safety (14 items)
5. Split large files (system.nix 397 lines)
6. Consolidate dnsblockd packages (overlay vs perSystem)

### Documentation

7. Archive old status reports (133 files)
8. Clean up stale docs/planning/ files

---

## F) Top 25 Next Actions

| #  | Task                                                                     | Effort  | Impact   |
| -- | ------------------------------------------------------------------------ | ------- | -------- |
| 1  | **Resolve Hyprland vs Niri** — pick one, remove dead code                | 2h      | Critical |
| 2  | **Add `set -euo pipefail` to 7 remaining scripts**                       | 15min   | Medium   |
| 3  | **Fix TODO_LIST.md summary counts**                                      | 5min    | Low      |
| 4  | **Import core/Types.nix in flake** (Ghost Systems)                       | 15min   | High     |
| 5  | **Import core/State.nix in flake** (Ghost Systems)                       | 15min   | High     |
| 6  | **Import core/Validation.nix in flake** (Ghost Systems)                  | 15min   | High     |
| 7  | **Enable TypeSafetySystem in flake**                                     | 30min   | High     |
| 8  | **Add Waybar GPU temperature module** (AMD GPU)                          | 1.5h    | Medium   |
| 9  | **Add Waybar CPU usage module**                                          | 1.5h    | Medium   |
| 10 | **Add hot-reload for Niri config** (Ctrl+Alt+R)                          | 10min   | High     |
| 11 | **Add Waybar memory/network/disk modules**                               | 4.5h    | Medium   |
| 12 | **Create Quake Terminal dropdown** (F12)                                 | 2h      | Medium   |
| 13 | **Create Clipboard History Viewer**                                      | 2h      | Medium   |
| 14 | **Consolidate user config** (eliminate split brain)                      | 45min   | High     |
| 15 | **Consolidate path config**                                              | 30min   | High     |
| 16 | **Enable SystemAssertions**                                              | 30min   | High     |
| 17 | **Archive old status reports** (133 files)                               | 1h      | Low      |
| 18 | **Monitor NixOS bug #483085** for audit daemon                           | Ongoing | Medium   |
| 19 | **Research audit kernel module** AppArmor compatibility                  | 2-4h    | Medium   |
| 20 | **Optimize keyboard repeat rate**                                        | 20min   | Low      |
| 21 | **Map Caps Lock to Escape/Control**                                      | 20min   | Low      |
| 22 | **Split system.nix** (397 lines → 3 files)                               | 90min   | Medium   |
| 23 | **Remove Hyprland scripts** (validate-deployment.sh, optimize-system.sh) | 30min   | Medium   |
| 24 | **Add workspace naming persistence**                                     | 30min   | Low      |
| 25 | **Bluetooth setup** (pair Nest Audio)                                    | 30min   | Low      |

---

## G) Top #1 Question

**Is Hyprland actually being used on evo-x2, or has Niri fully replaced it?**

Evidence for Niri as primary: niri-wrapped.nix imported, niri flake input, niri overlay in nixosConfigurations.
Evidence for Hyprland still active: hyprland.nix imported "RE-ENABLED", full Hyprland package set, hyprlock/hypridle/hyprpicker/hyprsunset.

**Why it matters**: Resolving this determines whether we delete ~600 lines of Hyprland config, 10+ packages, and 3+ scripts — or keep maintaining dual compositor support. This is the single biggest cleanup opportunity in the project.

---

## Build Verification

| Check                        | Status            |
| ---------------------------- | ----------------- |
| `nix flake check --no-build` | PASS              |
| `statix check .`             | PASS (0 warnings) |
| `alejandra --check .`        | PASS              |
| `deadnix`                    | PASS              |
| `gitleaks`                   | PASS              |
| Working tree                 | CLEAN             |
