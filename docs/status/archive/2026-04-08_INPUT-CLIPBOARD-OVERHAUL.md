# Input & Clipboard Overhaul — 2026-04-08

**Session Date:** 2026-04-08
**Branch:** master
**Scope:** Mouse/input device configuration, clipboard stack, rofi UI
**Validation:** `just test-fast` passes cleanly

---

## Summary

Comprehensive audit and fix of all mouse, trackpad, trackball, cursor, and clipboard configuration across NixOS and macOS platforms. Multiple issues found: missing device configs, redundant packages, dead rofi theme code, and an installed-but-unused `wl-clip-persist` package.

---

## Changes Made

### 1. Niri Input Configuration (`platforms/nixos/programs/niri-wrapped.nix`)

| Change                                | Before                                 | After                                                             | Why                                                                                                    |
| ------------------------------------- | -------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Trackball `accel-profile`             | Missing (default: adaptive)            | `"flat"`                                                          | Raw input precision, consistent with mouse                                                             |
| Touchpad `drag`                       | Missing (default: null)                | `true`                                                            | Enables tap-and-drag (double-tap then move)                                                            |
| Touchpad `disabled-on-external-mouse` | Missing (default: false)               | `true`                                                            | Auto-disable touchpad when external mouse connected                                                    |
| Clipboard keybind (`Alt+C`)           | Basic rofi dmenu                       | Full UI with scrollbar, 12 lines, `Ctrl+Delete` to remove entries | Clipboard history was a bare list with no way to delete entries                                        |
| Cliphist service                      | Only `wl-paste --watch cliphist store` | Added `ExecStartPost = wl-clip-persist --clipboard regular`       | `wl-clip-persist` was installed but never wired in — clipboard content was lost when source app closed |

### 2. System-Level Libinput (`platforms/nixos/system/configuration.nix`)

| Change                                                                                                                                                          | Why                                                                                                                                                                                                      |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Added `services.libinput` block with `mouse.accelProfile = "flat"`, `touchpad.tapping`, `naturalScrolling`, `disableWhileTyping`, `clickMethod = "clickfinger"` | Niri handles input directly, but XWayland apps and non-Niri surfaces fall back to libinput defaults. These were completely unconfigured, meaning inconsistent behavior between native and XWayland apps. |

### 3. macOS Trackpad (`platforms/darwin/system/settings.nix`)

| Change            | Before                   | After                            | Why                                    |
| ----------------- | ------------------------ | -------------------------------- | -------------------------------------- |
| Trackpad speed    | `1.0` (slowest non-zero) | `2.0`                            | Standard responsiveness                |
| Tap-to-click      | Missing                  | `Clicking = true`                | Was not enabled despite being standard |
| Three-finger drag | Missing                  | `TrackpadThreeFingerDrag = true` | Window management via trackpad         |
| Right-click       | Missing                  | `TrackpadRightClick = true`      | Two-finger right-click                 |

### 4. Clipboard Stack Fixes

| Change                                                | File                 | Why                                                                                             |
| ----------------------------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------- |
| Deduplicated `cliphist` package                       | `home.nix` (removed) | Was in both `home.nix` and `base.nix` — kept shared location in `base.nix` (Linux-only section) |
| Waybar clipboard widget: JSON output with count       | `waybar.nix`         | Tooltip now shows item count and usage hints instead of raw text                                |
| Waybar clipboard widget: middle-click to wipe history | `waybar.nix`         | No way to clear clipboard history before this                                                   |
| Waybar clipboard widget: upgraded rofi picker         | `waybar.nix`         | Same improved UI as `Alt+C` keybind (scrollbar, delete support)                                 |

### 5. Rofi Theme Cleanup (`platforms/nixos/programs/rofi.nix`)

| Change                                                  | Why                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Removed dead `configuration {}` block from inline theme | `modi`, `show-icons`, `icon-theme`, `drun-display-format` were defined in both the theme's `configuration {}` block and `extraConfig`. The `extraConfig` wins at runtime, making the theme block dead code. Removed the theme block, consolidated all settings into `extraConfig`. Added missing `display-drun` to `extraConfig`. |

---

## Files Changed

| File                                        | Changes                                                                                  |
| ------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `platforms/nixos/programs/niri-wrapped.nix` | Trackball accel, touchpad drag/disable-on-ext-mouse, cliphist persist, clipboard rofi UI |
| `platforms/nixos/system/configuration.nix`  | System-level `services.libinput` configuration                                           |
| `platforms/nixos/desktop/waybar.nix`        | Clipboard widget overhaul (JSON, count, middle-click wipe, rofi picker upgrade)          |
| `platforms/nixos/programs/rofi.nix`         | Removed dead `configuration {}` block, consolidated into `extraConfig`                   |
| `platforms/nixos/users/home.nix`            | Removed duplicate `cliphist` package                                                     |
| `platforms/darwin/system/settings.nix`      | Trackpad speed bump, tap-to-click, three-finger drag, right-click                        |

---

## Issues Not Changed (Subjective / Tuning Required)

| Item                                                       | Reason                                                                                                                                    |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `accel-speed` on mouse/touchpad/trackball                  | Depends on specific mouse DPI and personal preference. With `flat` accel, values like `0.3`–`0.5` may feel better if movement is too slow |
| `scroll-factor` on mouse/touchpad                          | Only matters if scroll speed feels off — needs hands-on tuning                                                                            |
| Cursor size 96px                                           | Fine on hi-DPI laptop panel, oversized on external monitors. No change without knowing monitor setup                                      |
| `focus-follows-mouse` + `warp-mouse-to-focus` both enabled | Can cause cursor teleportation; disabling one is a UX preference                                                                          |
| Touchpad gestures (libinput-gestures)                      | Mentioned in architecture docs as a suggestion but not implemented. Would require new package + config — out of scope for this session    |
| No `trackpoint` section in Niri config                     | The `evo-x2` has no TrackPoint, so this is intentionally absent                                                                           |

---

## Available Niri Input Properties (Reference)

Discovered from the niri-flake schema — these are all configurable but currently unset:

### Mouse (`input.mouse`)

| Property             | Default | Notes                              |
| -------------------- | ------- | ---------------------------------- |
| `scroll-factor`      | null    | Float or `{horizontal, vertical}`  |
| `accel-speed`        | null    | Float, adjusts sensitivity         |
| `middle-emulation`   | false   | Middle-click emulation             |
| `scroll-button`      | null    | Button number for scroll-on-button |
| `scroll-button-lock` | false   | Toggle scroll mode                 |
| `left-handed`        | false   | Mirror buttons                     |

### Touchpad (`input.touchpad`)

| Property           | Default | Notes                             |
| ------------------ | ------- | --------------------------------- |
| `scroll-factor`    | null    | Float or `{horizontal, vertical}` |
| `accel-speed`      | null    | Float                             |
| `accel-profile`    | null    | `"flat"` or `"adaptive"`          |
| `drag-lock`        | false   | Lock drag mode until tap          |
| `middle-emulation` | false   | Middle-click emulation            |

### Trackball (`input.trackball`)

| Property             | Default | Notes                  |
| -------------------- | ------- | ---------------------- |
| `accel-speed`        | null    | Float                  |
| `natural-scroll`     | false   | Currently unset        |
| `middle-emulation`   | false   | Middle-click emulation |
| `scroll-button-lock` | false   | Toggle scroll mode     |

### Trackpoint (`input.trackpoint`) — not configured

All standard pointer properties available (`accel-profile`, `accel-speed`, `scroll-method`, etc.)
