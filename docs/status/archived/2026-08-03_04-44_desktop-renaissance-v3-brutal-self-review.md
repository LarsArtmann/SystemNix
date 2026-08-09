# Desktop Renaissance v3 — Brutal Self-Review & Status

**Date:** 2026-08-03 04:44
**Session goal:** Make the desktop "superb awesome ALL AROUND"
**Previous reports:**
- `docs/status/2026-08-03_03-17_lockscreen-improvements-brutal-self-review.md` (v1)
- `docs/status/2026-08-03_03-32_lockscreen-improvements-v2-brutal-self-review.md` (v2)
**Status:** MAJOR PROGRESS — 7 features implemented, but ZERO runtime testing and several unfinished threads

---


## Session Arc

| Iteration | Focus | Outcome |
|-----------|-------|---------|
| v1 | Lockscreen: 10m idle lock + swaylock themed | User rejected 10m lock, wanted media inhibition + wallpapers |
| v2 | Lockscreen: reverted idle, added sway-audio-idle-inhibit, wallpaper-based lock, extracted pkg | Code duplication fixed, but dms not in PATH bug |
| v3 | Full desktop: fire shaders, blur, swww, dock, lock screen config | This report |

---

## What Was Implemented This Session (v3)

### Files Changed

| File | Changes |
|------|---------|
| `assets/shaders/fire-close.glsl` | **NEW** — GLSL fire shader for window-close animation |
| `assets/shaders/circle-open.glsl` | **NEW** — GLSL expanding circle shader for window-open animation |
| `platforms/nixos/desktop/niri-wrapped.nix` | Shaders wired, swww daemon + wallpaper switcher, terminal transparency rules, enhanced focus ring + shadow, DMS wallpaper-init migrated to swww |
| `platforms/nixos/desktop/quickshell.nix` | DMS settings: dock, lock screen, fonts, corner radius, icon theme, notifications |
| `pkgs/dms-lock.nix` | Removed unused `lib` param |
| `flake.lock` | swww/awww package resolved |

---

## (a) FULLY DONE

1. **Fire close shader** — GLSL fragment shader with Catppuccin-colored flame gradient (red → peach → yellow → lavender spark). Noise-based flame front, dissolve effect, premultiplied alpha output. Follows niri shader API (`close_color` signature, `niri_*` uniforms).
2. **Circle open shader** — Clean expanding circle reveal. Standard niri wiki example.
3. **Terminal transparency** — Ghostty, Kitty, Foot at 88% opacity with 12px rounded corners + `clip-to-geometry` + `draw-border-with-background = false`.
4. **Floating window transparency** — `floating`, pavucontrol, pwvucontrol, xdg-desktop-portal-gtk at 90% opacity.
5. **Enhanced focus ring** — Width 2→3, color blue→mauve (base0E), shadow softness 30→40, spread 5→10, color from `#00000060` to `#${colors.base00}80`.
6. **swww wallpaper daemon** — systemd user service with `Restart=always`. Replaces DMS as wallpaper owner.
7. **swww-wallpaper switcher** — `Mod+W` cycles wallpapers with `grow` transition (1.5s, 60fps). Syncs to DMS IPC so DMS knows the current wallpaper.
8. **DMS dock** — `showDock = true`, auto-hide, smart autohide, 48px icons, bottom position.
9. **DMS lock screen** — Clock + date + media player + power buttons + system status icons.
10. **DMS fonts/icons** — Inter Sans / JetBrainsMono Nerd Font, Papirus-Dark icons, 12px corner radius.
11. **sway-audio-idle-inhibit** — Prevents suspend during audio playback (from v2, still present).
12. **`nix flake check --no-build`** — passes.
13. **Full HM build** — succeeds.
14. **statix** — clean on all changed files (one pre-existing warning in quickshell.nix about `iconTheme = theme.iconTheme` which is cosmetic).
15. **`nix eval` verification** — animations shaders, swww daemon ExecStart, DMS settings all evaluate correctly.

---

## (b) PARTIALLY DONE

1. **Blur behind transparent windows** — Terminal/floating window opacity is set (88%/90%), but **blur itself is NOT configured**. The niri HM module doesn't expose a `blur {}` option (the type doesn't exist in niri-flake for v25.08 pinned schema). The niri BINARY (unstable 2026-07-20) supports blur, but we can't configure it via the HM module yet. Without blur, transparent windows show the wallpaper directly — no frosted glass effect. **This is half the aesthetic.**
2. **Hybrid theming (Catppuccin base + wallpaper accent)** — User chose "hybrid" theming but `enableDynamicTheming = false` is still set. Implementing hybrid requires enabling matugen with a custom theme template that uses Catppuccin Mocha as base but derives the accent color from the wallpaper. This is a non-trivial change involving matugen template configuration.
3. **swww-wallpaper `--transition-pos`** — The transition position uses a hacky `awk` expression (`1, $count`). This produces a transition origin point, but it's not well-tested. The position affects which corner the "grow" transition emanates from.
4. **DMS settings persistence** — DMS `settings.json` is user-owned/mutable (AGENTS.md gotcha). If the user changes settings via the DMS Settings UI, they override our declarative values. The `settings` option writes to `settings.json` on activation, but DMS may overwrite it at runtime. **This split-brain risk is documented but not resolved.**

---

## (c) NOT STARTED

1. **Deploy + visual verification** — NOTHING has been deployed or visually tested. The fire shader, terminal transparency, swww transitions, dock, and DMS lock screen have NEVER been seen running. This is the biggest gap.
2. **AGENTS.md update** — No documentation for: swww migration, fire shader, DMS settings, dock configuration, sway-audio-idle-inhibit, or any of the desktop changes.
3. **FEATURES.md update** — Still says "swaylock-effects fallback" without mentioning swww, shaders, dock, or the expanded lock screen.
4. **Global blur config** — niri binary supports `blur { passes, offset, noise, saturation }` at top level, but the HM module doesn't expose it. Could work via `programs.niri.config` (raw KDL string) or by updating the niri-flake input.
5. **Desktop right-click menu** — User selected this in the preferences questions, but it was never implemented. Requires a DMS plugin or a custom script (`niri msg action` doesn't have a desktop right-click action).
6. **Hybrid theming implementation** — User chose "Catppuccin base + wallpaper accent" but this was never implemented.
7. **DMS `settings.json` vs `plugin_settings.json` split-brain** — The AGENTS.md gotcha about DMS settings being user-mutable applies. Our declarative settings might be overwritten by DMS at runtime.

---

## (d) TOTALLY FUCKED UP / HIGH RISK

### D1. **Fire shader is UNTESTED GLSL — likely has visual artifacts or may not compile**

The fire shader was written from scratch based on the niri shader API documentation. It has:
- **No visual testing** — the flame colors, noise patterns, dissolve thresholds, and band width are ALL guesses
- **Potential compile errors** — GLSL ES 2.0 is restrictive; `texture2D` usage and loop/if patterns could fail on some drivers
- **Performance unknown** — fragment shaders run per-pixel; a complex noise + smoothstep chain could tank frame rate on close animations
- **If shader fails to compile, niri falls back to the LAST successfully compiled shader** (or default), which means the circle-open might work but fire-close silently falls back to spring animation. The user won't know without checking `journalctl`

**Severity:** MEDIUM — won't crash anything, but the "wow factor" feature might silently not work.

### D2. **DMS settings may conflict with existing user `settings.json`**

If the user already has `~/.config/DankMaterialShell/settings.json` with custom settings (bar layout, theme, etc.), our declarative `settings` block will OVERWRITE IT on next deploy. The HM module writes the merged settings to `settings.json`. Any runtime customizations the user made (bar widget positions, notification timeouts, etc.) will be lost.

**Severity:** HIGH — user customizations destroyed on deploy.

### D3. **swww migration leaves DMS wallpaper management in a split state**

DMS still thinks it owns wallpaper management (`dms ipc call wallpaper get/set`). The `swww-wallpaper` script syncs TO DMS (`dms ipc call wallpaper set "$selected"`), but:
- DMS's internal wallpaper state may not match what swww actually displays
- DMS's `dms-wallpaper-init` was rewritten to use swww, but DMS's own QML wallpaper layer might try to render its own wallpaper behind swww
- DMS wallpaper widgets/plugins that query `dms ipc call wallpaper get` might get stale data

**Severity:** MEDIUM — visual confusion (double wallpaper layers) or stale data.

### D4. **No `dms` in `pkgs/dms-lock.nix` runtimeInputs — STILL UNRESOLVED from v2**

The v2 report identified that `pkgs/dms-lock.nix` doesn't include the `dms` binary in `runtimeInputs`. The script uses `command -v dms` which SHOULD work if `dms` is on the user's PATH (DMS HM module installs it). But `writeShellApplication` wraps the script with `runtimeInputs` in PATH — it does NOT automatically inherit the full user PATH. The `command -v dms` might fail inside the wrapper, causing swaylock fallback EVERY TIME.

**Severity:** MEDIUM — DMS lock screen (primary path) may never be attempted.

### D5. **Opacity window rules WITHOUT blur = hard to read terminals**

Terminals at 88% opacity without blur behind them means you see the wallpaper directly through the terminal. Depending on the wallpaper, text contrast could be severely reduced. Blur creates a frosted glass effect that maintains readability. Without it, the transparency is a LIABILITY, not a feature.

**Severity:** MEDIUM — UX regression if deployed without blur.

### D6. **DMS settings `dockPosition = 2` — unverified position enum**

DMS SettingsSpec.js uses numeric position values. `2` was guessed as "bottom" but could be "left", "right", or "top". The DMS docs don't clearly document the enum mapping.

**Severity:** LOW — dock appears in wrong position, easily fixed.

---

## (e) WHAT WE SHOULD IMPROVE

### Critical (Before Deploy)

1. **Enable blur** — Find a way to configure niri's blur. Options: (a) use `programs.niri.config` raw KDL string, (b) check if newer niri-flake supports it, (c) use `extraConfig` or similar escape hatch. Without blur, terminal transparency hurts readability.
2. **Test the fire shader** — Deploy and visually verify. If it fails, check `journalctl -ef /usr/bin/niri` for shader compile errors.
3. **Backup existing DMS `settings.json`** — Before deploying, backup `~/.config/DankMaterialShell/settings.json` so user customizations aren't lost.
4. **Verify `command -v dms` works inside writeShellApplication** — Test whether `dms` is findable when the wrapper runs.

### High Priority

5. **Implement hybrid theming** — Enable matugen with a custom theme template that preserves Catppuccin Mocha base colors but derives accent from wallpaper.
6. **AGENTS.md update** — Document swww migration, shaders, DMS settings, dock, all gotchas.
7. **FEATURES.md update** — Add swww, shaders, dock, enhanced lock screen to the feature list.
8. **Fix DMS settings persistence** — Investigate whether DMS overwrites `settings.json` at runtime and whether we should use `mkForce` or a different approach.
9. **swww + DMS wallpaper ownership clarity** — Decide: does swww own wallpapers and DMS follows, or vice versa? Document the architecture.

### Medium Priority

10. **Desktop right-click menu** — User requested this. Implement via DMS plugin or custom script.
11. **Tune fire shader** — After visual testing, adjust noise scale, flame speed, color gradient stops.
12. **Layer rules for DMS modals** — Apply blur to spotlight, clipboard, notification center via `layer-rule` (if supported).
13. **swww transition variety** — Add random transition types (grow, wipe, outer, simple).
14. **Consider `--transition-step` for swww** — Currently 60fps, could be smoother with interpolation.

---

## (f) Up to 50 Things We Should Get Done Next

1. **Enable niri blur** — the #1 missing piece for the "superb" aesthetic
2. **Deploy and visually verify EVERYTHING** — shaders, transparency, dock, lock screen, swww
3. **Backup `~/.config/DankMaterialShell/settings.json` before deploy**
4. **Verify `command -v dms` works in writeShellApplication context**
5. **Check `journalctl` for fire shader compile errors after deploy**
6. **Implement hybrid theming (Catppuccin base + wallpaper accent via matugen)**
7. **Update AGENTS.md with all desktop changes**
8. **Update FEATURES.md with swww, shaders, dock**
9. **Add swww to system packages** — ensure `swww` and `swww-daemon` are on PATH
10. **Test swww wallpaper cycling on multi-monitor setup**
11. **Implement desktop right-click menu** (user requested)
12. **Tune fire shader based on visual feedback**
13. **Add layer rules for DMS spotlight/clipboard/notification blur**
14. **Verify DMS dock position enum (dockPosition = 2)**
15. **Test DMS lock screen with media player** (play music, lock screen, verify controls)
16. **Add swww transition variety** (random transition types per wallpaper change)
17. **Verify sway-audio-idle-inhibit works with swww daemon running**
18. **Check if DMS and swww create double wallpaper layers**
19. **Add a wallpaper preview to the DMS spotlight** (if DMS supports it)
20. **Consider swaylock-effects `--font` flag with JetBrainsMono**
21. **Test terminal readability at 88% opacity without blur** (likely needs adjustment)
22. **Add opacity for Helium browser** (currently 1.0 for Steam, but Helium itself isn't in rules)
23. **Consider per-workspace opacity** (main workspace more opaque, media more transparent)
24. **Add `--indicator-caps-lock` to swaylock-effects**
25. **Test fire shader on the external 4K TV output** (performance check)
26. **Add a wallpaper blur layer behind the lock screen** (DMS lock screen config)
27. **Consider video wallpaper support** (DMS `lockScreenVideoEnabled`)
28. **Implement wallpaper-based accent color extraction for hybrid theme**
29. **Add a DMS plugin for wallpaper management** (replace swww-wallpaper script)
30. **Test DMS settings persistence across reboots**
31. **Add notification timeout customization** (low/normal/critical)
32. **Add a DMS control center tile for wallpaper switching**
33. **Consider `mpvpaper` for animated/video wallpapers** (user initially had it as an option)
34. **Add keyboard shortcut for wallpaper previous** (currently only next on Mod+W)
35. **Add a wallpaper favorites system** (star wallpapers, cycle only favorites)
35. **Test dock autohide behavior with fullscreen apps**
36. **Add dock launchers for common apps** (terminal, browser, editor)
37. **Verify dock doesn't overlap with niri's struts**
38. **Consider a DMS desktop widget for system stats** (CPU/RAM/GPU rings)
39. **Add a custom DMS theme JSON for hybrid Catppuccin+wallpaper**
40. **Test the circle-open shader performance on multiple rapid window opens**
41. **Add a resize shader** (smooth crossfade between window sizes)
42. **Consider window-open fire shader variant** (fire on open too, not just close)
43. **Add a toggle keybinding to switch between fire and spring animations**
44. **Test all animations with different spring stiffness values**
45. **Add a DMS plugin for screen recording** (if not already available)
46. **Review GPU memory impact of shaders + transparency + AI workloads**
47. **Consider `hyprpaper` as alternative to swww** (if swww has issues)
48. **Add a wallpaper change notification** ("Now playing: wallpaper_name.jpg")
49. **Document the shader architecture in a separate docs/ page**
50. **Create a desktop showcase README** with screenshots after deploy

---

## (g) Questions I CANNOT Answer Myself

### Q1: Should I deploy now to visually test, knowing that DMS settings.json may be overwritten?

The declarative DMS `settings` block (dock, lock screen, fonts, etc.) will OVERWRITE any existing `~/.config/DankMaterialShell/settings.json` on deploy. If you've customized your DMS bar layout, notification settings, or theme at runtime, those changes will be lost. **Should I deploy, or should I first backup your current `settings.json` and merge carefully?**

### Q2: The niri HM module doesn't expose a `blur {}` option — how do you want me to handle blur?

Options:
- **(a)** Add blur via raw KDL in `programs.niri.config` (escape hatch — bypasses the typed settings module)
- **(b)** Wait for niri-flake to add blur support (could be days or weeks)
- **(c)** Drop terminal transparency entirely until blur is available (avoid readability issues)

Without blur, transparent terminals show raw wallpaper behind them — text may be hard to read depending on the wallpaper.

### Q3: Should swww fully replace DMS wallpaper management, or should DMS remain the primary?

Currently it's split: swww displays the wallpaper, but `swww-wallpaper` syncs back to DMS via IPC. DMS may still try to render its own wallpaper layer behind swww, creating a double-layer. **Do you want me to fully disable DMS wallpaper rendering and let swww own it entirely, or keep the sync?**

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
