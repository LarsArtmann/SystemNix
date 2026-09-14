# Desktop UX Overhaul — Status Report

**Date:** 2026-04-01 (early hours)
**Session Scope:** Comprehensive desktop UX/UX improvements for Niri + Waybar + system tools
**Build Status:** PARTIALLY COMMITTED — known bugs need fixing before `just switch`
**Commits:** 4+ commits (8830be8..e398f72), pushed to origin/master

---

## A. COMPLETED CHANGES

### 1. Rofi — Grid Launcher (adi1090x Type 3 Style 1)

| File                                | Change                                                                                                         |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `platforms/nixos/programs/rofi.nix` | Complete rewrite: 5×3 icon grid, 56px icons, Catppuccin Mocha colors, rounded corners, vertical element layout |

**Keybindings:** `Mod+D` and `Mod+Space`

### 2. Waybar — Minimal Restyle

| File                                 | Change                                                   |
| ------------------------------------ | -------------------------------------------------------- |
| `platforms/nixos/desktop/waybar.nix` | Removed 7 redundant modules, flat styling, weather added |

**Removed modules:**

- `idle_inhibitor` (eye button — useless on desktop)
- `custom/netbandwidth` (duplicate IP info with `network`)
- `custom/gpu` (duplicate temp with `temperature`)
- `backlight` (no internal display)
- `battery` (no battery)
- `custom/privacy` (clutter)
- `custom/sudo` (clutter)

**Added:** Weather module via `wttr.in` (updates every 30min)

**Fixed:** Temperature sensor `hwmon4` (WiFi chip) → `hwmon2` (k10temp AMD CPU)

**Style:** Flat bar, no colored module backgrounds, monochrome Catppuccin text, 42px height (was 55px)

### 3. Swaylock — Blur + Catppuccin

| File                                    | Change                                                                             |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| `platforms/nixos/programs/swaylock.nix` | NEW: swaylock-effects with gaussian blur, vignette, clock, Catppuccin Mocha colors |
| `platforms/nixos/desktop/multi-wm.nix`  | Changed `swaylock` → `swaylock-effects`                                            |

### 4. Yazi — Terminal File Manager

| File                                | Change                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------- |
| `platforms/nixos/programs/yazi.nix` | NEW: Catppuccin Mocha theme, image/video preview deps, smart open rules, vim-like navigation |
| `platforms/nixos/users/home.nix`    | Added import + package                                                                       |

**Keybindings added to yazi:** `<C-c>` copy, `<C-x>` cut, `<C-v>` paste, `<C-s>` search, `g h/p/c` quick nav

### 5. Dunst — Notification Restyle

| File                                      | Change                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------- |
| `platforms/nixos/users/home.nix` (inline) | Glass-morphism, semi-transparent, repositioned top-right, smaller icons, cleaner separators |

### 6. Niri Keybindings — New Shortcuts

| Key             | Action                                  | File                   |
| --------------- | --------------------------------------- | ---------------------- |
| `F11`           | Toggle fullscreen                       | `niri-wrapped.nix:218` |
| `Mod+F11`       | Screenshot screen → swappy + clipboard  | `niri-wrapped.nix:221` |
| `Mod+Shift+F11` | Screenshot area → swappy + clipboard    | `niri-wrapped.nix:220` |
| `Mod+Ctrl+F11`  | Screenshot monitor → swappy + clipboard | `niri-wrapped.nix:222` |
| `Mod+Space`     | App launcher (rofi)                     | `niri-wrapped.nix:203` |
| `Mod+C`         | Clipboard history (cliphist + rofi)     | `niri-wrapped.nix:204` |
| `Mod+.`         | Emoji picker (rofi-emoji)               | `niri-wrapped.nix:205` |
| `Mod+Shift+C`   | Calculator (rofi-calc)                  | `niri-wrapped.nix:206` |
| `Mod+Shift+N`   | Notification history (dunstctl + rofi)  | `niri-wrapped.nix:207` |
| `Mod+Z`         | Zed editor                              | `niri-wrapped.nix:208` |
| `Mod+Shift+F`   | Floating file manager (yazi in kitty)   | `niri-wrapped.nix:209` |
| `Mod+Shift+/`   | Show keybinding list                    | `niri-wrapped.nix:204` |

### 7. Niri Window Rules

| Rule             | Change                                        |
| ---------------- | --------------------------------------------- |
| Terminal opacity | `0.95` transparency on tiled windows          |
| Floating class   | `floating` app-id opens centered, 50%×70%     |
| Terminal widths  | kitty/foot/helium default to 75% column width |

### 8. Monitor Brightness — DDC/CI

| File                                        | Change                                                      |
| ------------------------------------------- | ----------------------------------------------------------- |
| `platforms/nixos/system/boot.nix`           | Added `i2c-dev` kernel module                               |
| `platforms/nixos/system/configuration.nix`  | Added `i2c` group to user                                   |
| `platforms/nixos/users/home.nix`            | Added `ddcutil` package                                     |
| `platforms/nixos/programs/niri-wrapped.nix` | Brightness keys use `ddcutil` with `brightnessctl` fallback |

### 9. Zed Editor — Configuration

| File                                         | Change                                                                                     |
| -------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `platforms/nixos/programs/zed/settings.json` | NEW: Catppuccin Mocha theme, vim mode, JetBrainsMono, 14pt font, inline blame, inlay hints |

### 10. New Packages

- `zed-editor` — Modern Rust-based code editor
- `yazi` — Terminal file manager (Rust, async)
- `rofi-calc` — Live calculator in rofi
- `rofi-emoji` — Emoji picker in rofi
- `bemoji` — Emoji database for rofi-emoji
- `ddcutil` — External monitor brightness control
- `pwvucontrol` — Native PipeWire volume control (replaced pavucontrol)

---

## B. KNOWN BUGS (need fixing before `just switch`)

### Critical

| # | Bug                                      | Impact                                                      | File                       | Fix                            |
| - | ---------------------------------------- | ----------------------------------------------------------- | -------------------------- | ------------------------------ |
| 1 | **`wl-clipboard` removed from home.nix** | Clipboard completely broken — `wl-copy`/`wl-paste` missing  | `home.nix:132-135`         | Restore `wl-clipboard` package |
| 2 | **Screenshots use `tee >()`**            | Process substitution is bash-only, niri spawns with `sh -c` | `niri-wrapped.nix:220-222` | Use temp file approach instead |

### Minor

| # | Bug                        | Impact                                                                        | File                         | Fix                                   |
| - | -------------------------- | ----------------------------------------------------------------------------- | ---------------------------- | ------------------------------------- |
| 3 | **`bemoji` redundant**     | `rofi-emoji` includes its own emoji database                                  | `home.nix:135`               | Remove `bemoji`                       |
| 4 | **Zed settings not wired** | `settings.json` exists but Home Manager doesn't deploy it to `~/.config/zed/` | `programs/zed/settings.json` | Add `xdg.configFile` or HM zed module |

---

## C. NOT DONE (intentionally skipped)

| Item                             | Reason                                                                                                |
| -------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Idle toggle (`Mod+Shift+I`)      | **Too dangerous** — killing swayidle would permanently break auto-lock. Needs proper toggle approach. |
| System menu (rofi wifi/bt/audio) | **Too complex** for marginal value. pavucontrol, blueman already accessible via app launcher.         |
| Wallpaper rotation timer         | Not yet implemented. Would need a systemd user timer cycling swww every 30min.                        |

---

## D. FILES CHANGED (this session)

```
platforms/nixos/desktop/multi-wm.nix          # swaylock → swaylock-effects
platforms/nixos/desktop/waybar.nix             # Complete rewrite
platforms/nixos/programs/niri-wrapped.nix      # 12+ keybindings, window rules, opacity
platforms/nixos/programs/rofi.nix              # Complete rewrite (grid theme)
platforms/nixos/programs/swaylock.nix          # NEW (blur + Catppuccin)
platforms/nixos/programs/yazi.nix              # NEW (Catppuccin theme)
platforms/nixos/programs/zed/settings.json     # NEW (editor config)
platforms/nixos/system/boot.nix               # i2c-dev kernel module
platforms/nixos/system/configuration.nix       # i2c group
platforms/nixos/users/home.nix                # Packages, imports, dunst config
```

---

## E. NEXT STEPS

1. **Fix critical bugs** — restore `wl-clipboard`, fix screenshot commands
2. **Wire zed settings** into Home Manager
3. **Test with `just switch`** — requires reboot for i2c-dev + i2c group
4. **Add wallpaper rotation timer** if desired
5. **Verify DDC/CI** — `ddcutil detect` after reboot
