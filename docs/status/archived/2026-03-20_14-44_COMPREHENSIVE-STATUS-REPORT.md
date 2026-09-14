# SystemNix Comprehensive Status Report

**Date:** 2026-03-20 14:44
**Branch:** master
**Status:** ✅ PRODUCTION STABLE WITH PENDING HARDWARE FIXES

---

## Executive Summary

The SystemNix project continues to evolve towards declarative perfection. Over the last three days (since March 17), the focus shifted heavily towards **AI integration (Ollama, GLM-4.7-Flash, AMD XDNA NPU)**, **security (KeePassXC)**, and **stability (Waybar, Hyprland 0.54 syntax, pre-commit hooks)**.

The system is highly functional, though some bleeding-edge hardware features (AMD NPU via XRT) are temporarily blocked by upstream compilation issues.

---

## a) FULLY DONE (Recent Achievements)

### Desktop Environment & UX

- **Hyprland 0.54 Compatibility:** Window rules completely updated to the new 0.54 syntax, resolving deprecation warnings and layout bugs.
- **Waybar Stability:** Resolved recurring Waybar crashes, injected UTF-8 fonts for icons, and relaxed idle timeouts for better daily usability.
- **Browser Extensions:** Declarative YouTube Shorts blocker extension management fully implemented across platforms.

### Security & Password Management

- **KeePassXC Integration:**
  - Implemented KeePassXC Hyprland window rules for seamless popup behavior.
  - Added `kop` shell alias for quick access.
  - Split and simplified native messaging manifests for Chromium and Helium browsers.
  - Fixed an infinite recursion bug in the KeePassXC wrapper.

### AI Stack & Hardware Enablement

- **Ollama Vulkan Backend:** Successfully switched Ollama to the Vulkan backend, bypassing previous compute issues.
- **Benchmarks:** Added comprehensive GLM-4.7-Flash quantisation benchmark suite.
- **AMD XDNA NPU:** Added driver support and AI monitoring scripts.
- **SSH Configuration:** Fixed SSH key pathing issues to properly deploy the root key to `authorized_keys.d`.

### CI & Tooling

- **Git Hooks:** Updated pre-commit-hooks from v4.4.0 to v6.0.0. Added flake.lock validation and a robust merge conflict detection recipe.
- **Health Scripts:** Refactored the health script for better accuracy and removed stale inline TODOs.
- **JSCPD:** Converted the jscpd function to a lightweight shell alias for `bunx`.

---

## b) PARTIALLY DONE

- **ActivityWatch Ecosystem:** 4 of 5 buckets working. Input watcher still suffers from permissions issues on macOS.
- **Homebrew Migration:** Still lingering on the Intel-era `/usr/local` prefix on Apple Silicon. Migration to `/opt/homebrew` is documented but pending a final execution decision.
- **File Organization:** Pre-commit hooks now catch conflicts, but the repository root still contains miscellaneous Python benchmark scripts (`test_speed.py`, `download_glm_model.py`) that belong in `dev/` or `scripts/`.

---

## c) NOT STARTED

- **Repo Split into Sub-projects:** The monolithic repository architecture identified in `HARDCORE_REVIEW.md` remains intact.
- **Library Extraction:** `nix-error-lib` and `nix-types-lib` have not yet been extracted into standalone reusable flakes.
- **Go Overlay Scoping:** The Go 1.26.1 global override still risks breaking unrelated nixpkgs derivations.
- **Automated CI Testing Framework:** No continuous integration beyond pre-commit and flake checking.

---

## d) TOTALLY FUCKED UP

- **AMD NPU XRT Build Failures:** The `amd-npu` module had to be explicitly disabled because the upstream XRT build fails against Boost 1.89.0. This blocks native hardware AI acceleration until NixOS upstream resolves the dependency clash.
- **Documentation Bloat:** The `docs/status/` directory is overflowing with historical, unread AI-generated markdown files, cluttering IDE searches and artificially inflating the repo size.
- **Pre-commit `oxfmt` Panics:** The `oxfmt` tool currently panics on `gomod2nix.toml`, causing all standard `git commit` commands to fail unless bypassed with `--no-verify`.

---

## e) WHAT WE SHOULD IMPROVE

1. **Pre-commit Resilience:** Exclude non-Go or incompatible files (like `gomod2nix.toml`) from `oxfmt` to restore standard `git commit` functionality without needing `--no-verify`.
2. **Docs Graveyard Purge:** Archive all status reports older than February 2026 into a compressed tarball or a separate `system-docs-archive` repository.
3. **Root Directory Cleanup:** Move the GLM-4.7 benchmark scripts and leftover test files into a dedicated `scripts/ai/` or `dev/benchmarks/` folder.
4. **NPU Upstream Tracking:** Set up a tracking issue or cron script to monitor the NixOS XRT/Boost 1.89.0 compatibility so the AMD NPU can be re-enabled ASAP.

---

## f) TOP 25 THINGS WE SHOULD GET DONE NEXT

_(Prioritized list of actionable tasks)_

1. [P0] Fix the `oxfmt` pre-commit hook panic on `gomod2nix.toml`.
2. [P0] Track and wait for upstream fix for XRT vs Boost 1.89.0.
3. [P1] Deduplicate the Go 1.26.1 overlay in `flake.nix` (currently triplicated).
4. [P1] Archive old status reports to reduce documentation bloat.
5. [P1] Execute the Homebrew `/usr/local` to `/opt/homebrew` migration on macOS.
6. [P1] Resolve ActivityWatch input watcher permission errors on macOS.
7. [P2] Move root Python scripts (`download_glm_model.py`, `test_speed.py`) to `scripts/ai/`.
8. [P2] Extract `nix-error-lib` into a reusable component.
9. [P2] Extract `nix-types-lib` into a reusable component.
10. [P2] Align `stateVersion` between `home-base.nix` and `configuration.nix`.
11. [P2] Complete Phase 1 of the Desktop Improvement Roadmap (audio visualizers, advanced window rules).
12. [P2] Add automated build verification to GitHub Actions.
13. [P2] Delete stale `copilot/fix-*` remote branches.
14. [P2] Implement `niri` keybindings and layout config (currently just a stub).
15. [P2] Add VS Code Nix integration (LSP, formatter).
16. [P2] Test NixOS Bluetooth on physical EVO-X2 hardware.
17. [P2] Re-enable `ublock-filters.nix` or remove the dead code.
18. [P2] Add `deadnix` checks to the `justfile`.
19. [P3] Update `TODO_LIST.md` to reflect recent KeePassXC and AI hardware completions.
20. [P3] Update `TODO-STATUS.md` with accurate code-level task states.
21. [P3] Fix `netbandwidth` Waybar module (currently displays IP, not bandwidth).
22. [P3] Add error handling (`set -euo pipefail`) to all inline Waybar shell scripts.
23. [P3] Implement Program Discovery System.
24. [P3] Implement a `just organize` recipe for automated repository cleanup.
25. [P3] Document why `allowBroken = false` must always be false in `flake.nix`.

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**When should we re-enable the AMD NPU module?**

I had to disable the `amd-npu` module because of the upstream XRT build failure with Boost 1.89.0. I cannot predict when NixOS upstream will patch this package. Do we want to temporarily pin Boost to an older version (e.g., 1.87) via an overlay just to get the NPU working, or should we patiently wait for the official upstream fix?
