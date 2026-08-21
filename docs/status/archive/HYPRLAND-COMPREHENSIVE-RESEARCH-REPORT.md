# 🔍 HYPRLAND COMPREHENSIVE RESEARCH REPORT

## Executive Summary

Your Hyprland setup on NixOS (evo-x2, AMD Ryzen AI Max+ 395) is **well-structured and partially optimized**, but has several critical issues and opportunities for improvement.

**Overall Status: 7/10** - Good foundation with fixable issues

---

## 📊 CURRENT SETUP ANALYSIS

### ✅ What's Working Well

1. **Hyprland Architecture**
   - Proper dual-level configuration (system + Home Manager)
   - Clean modular structure
   - systemd integration enabled
   - Xwayland support enabled

2. **Performance Optimizations**
   - AMD GPU specific variables configured (`LIBVA_DRIVER_NAME=radeonsi`, `AMD_VULKAN_ICD=RADV`)
   - Blur passes reduced to 1 (line 117)
   - Fast workspace animations (0.5s, line 139)
   - Logo/splash rendering disabled (lines 156-157)
   - Monitor scaling fixed to 125% (line 25)

3. **Keybindings**
   - Complete workspace management (1-10)
   - Window navigation (arrows + HJKL)
   - System controls (lock, power, screenshots)
   - Media controls (XF86 keys)
   - Special workspace support

4. **Window Rules**
   - Persistent workspace assignments (lines 48-72)
   - Background consoles configured (htop-bg, logs-bg, nvim-bg)
   - Workspace organization by application type

5. **Waybar Integration**
   - Comprehensive modules (workspaces, media, system monitoring)
   - Catppuccin-inspired styling
   - Glassmorphism effect

---

## 🚨 CRITICAL ISSUES FOUND

### Issue 1: Waybar Media Module Errors (HIGH PRIORITY)

**Error in logs:**

```
[error] custom/media: mixing manual and automatic argument indexing is no longer supported;
try replacing "{}" with "{text}" in your format specifier
```

**Location:** `platforms/nixos/desktop/waybar.nix:135`

```nix
exec = "playerctl metadata --format '{{artist}} - {{title}}' || echo 'Nothing playing'";
```

**Impact:** Waybar repeatedly logs errors every 5 seconds
**Fix Required:** Update format string (see recommendations below)

---

### Issue 2: Missing Security Script (HIGH PRIORITY)

**Error in logs:**

```
sh: line 1: /home/lars/.config/waybar/security-status.sh: No such file or directory
```

**Location:** `platforms/nixos/desktop/waybar.nix:151`

```nix
exec = "~/.config/waybar/security-status.sh";
```

**Impact:** Security status module doesn't work
**Fix Required:** Create script or remove module

---

### Issue 3: Ghost Wallpaper Module Not Integrated (MEDIUM)

**Location:** `platforms/nixos/desktop/hyprland.nix:34`

```nix
# Note: btop-bg is now handled by ghost-btop-wallpaper module
```

**Issue:** Comment exists but module is imported but not actually used. Still using inline background consoles.

**Impact:** Duplication, not leveraging modular architecture
**Fix Required:** Either integrate ghost-wallpaper module or remove comment

---

### Issue 4: Missing Workspace-on-Monitor Rules (MEDIUM)

**Current:** All workspaces on HDMI-A-1 (single monitor setup)

**Recommended:** Add explicit workspace-to-monitor mapping for multi-monitor support

**Impact:** Will cause issues when adding second monitor
**Fix Required:** Add workspace rules (see recommendations)

---

## 💡 RECOMMENDATIONS

### Priority 1: Fix Waybar Errors (Immediate)

**1. Fix Media Module Format String**

```nix
# platforms/nixos/desktop/waybar.nix:135
# Change from:
exec = "playerctl metadata --format '{{artist}} - {{title}}' || echo 'Nothing playing'";

# To:
exec = "playerctl metadata --format '{artist} - {title}' || echo 'Nothing playing'";
```

**2. Create Security Script or Remove Module**

Option A - Create script:

```bash
#!/usr/bin/env fish
# ~/.config/waybar/security-status.sh
if test (pgrep -c firewalld) -gt 0
    echo "Firewall"
else
    echo "No Firewall"
end
```

Option B - Remove module (if not needed):

```nix
# Comment out line 33 in waybar.nix
# "custom/security",
```

---

### Priority 2: Install Essential Hyprland Plugins

**Recommended Plugins:**

1. **Hyprland-hy3** (i3-like layout)

```nix
# platforms/nixos/desktop/hyprland.nix
plugins = [
  pkgs.hyprlandPlugins.hyprwinwrap
  pkgs.hyprlandPlugins.hy3  # Add this
];
```

2. **Hyprsplit** (multi-monitor workspace management)

```nix
# Add via flake input (recommended for stability)
```

**Benefits:**

- Better multi-monitor support
- i3-style layouts (many developers prefer)
- Improved workspace organization

---

### Priority 3: Enhance Keybindings for Development Workflows

**Add Development-Focused Keybindings:**

```nix
# Add to platforms/nixos/desktop/hyprland.nix

# Scratchpads (quick access windows)
"$mod, grave, togglespecialworkspace, magic"  # Already exists, good

# Quick launcher for development tools
"$mod, G, exec, gitui"                       # Git TUI
"$mod, H, exec, btop"                        # System monitor
"$mod, A, exec, nvim ~/todo.md"             # Quick notes
"$mod SHIFT, F, exec, firefox --new-window"  # New browser window

# Terminal with tmux session
"$mod CTRL, Return, exec, kitty tmux new-session -A -s dev"

# Move to special workspace with current window
"$mod SHIFT, grave, movetoworkspace, special:magic"

# Submap for window resizing (more precise than mouse)
"$mod, R, submap, resize"
# ... add resize keybindings
```

---

### Priority 4: Add Performance Optimizations

**Add to hyprland.nix:**

```nix
render = {
  direct_scanout = 1;           # Reduced latency
  explicit_sync = 1;            # Better frame timing
  new_render_scheduling = true; # Smoother animations
};

misc = {
  vrr = 1;                      # Variable refresh rate
  vfr = true;                   # Variable frame rate
  animate_manual_resizes = false; # Responsive resizing
  animate_mouse_windowdragging = false; # Responsive dragging
  enable_swallow = true;        # Reduce terminal memory
  render_ahead_of_time = true;  # Pre-render frames
};

input = {
  follow_mouse = 1;              # Better focus behavior
  repeat_delay = 250;           # Keyboard repeat
  repeat_rate = 40;             # Faster repeat rate
};
```

---

### Priority 5: Improve Workspace Organization

**Add Workspace Naming:**

```nix
workspace = 1, name:💻 Dev
workspace = 2, name:🌐 Web
workspace = 3, name:📁 Files
workspace = 4, name:📝 Edit
workspace = 5, name:💬 Chat
workspace = 6, name:🔧 Tools
workspace = 7, name:🎮 Games
workspace = 8, name:🎵 Media
workspace = 9, name:📊 Mon
workspace = 10, name:🌟 Misc
```

**Add Workspace-on-Monitor Rules (for future multi-monitor):**

```nix
workspace = 1, monitor:HDMI-A-1
workspace = 2, monitor:HDMI-A-1
# ... etc
```

---

### Priority 6: Window Rules Enhancements

**Add More Useful Rules:**

```nix
windowrulev2 = [
  # Dialogs should float
  "float, title:^(Open File|Save As|Choose File)"

  # Picture-in-Picture
  "float, title:^(Picture-in-Picture)"
  "pin, title:^(Picture-in-Picture)"

  # Password managers
  "float, class:^(org.keepassxc.KeePassXC)$"
  "center, class:^(org.keepassxc.KeePassXC)$"

  # Steam
  "float, class:^(steam)$, title:^(Friends|News)$"

  # System dialogs
  "float, class:^(nm-connection-editor|blueman-manager|pavucontrol)$"
  "center, class:^(nm-connection-editor|blueman-manager|pavucontrol)$"

  # No blur for terminals (performance)
  "noblur, class:^(kitty|ghostty|alacritty)$"
];
```

---

### Priority 7: Add Idle Management

**Create hypridle configuration:**

```nix
# platforms/nixos/desktop/hyprland.nix
services.hypridle = {
  enable = true;
  settings = {
    general = {
      lock_cmd = "hyprlock";
      before_sleep_cmd = "hyprlock";
    };
    listener = [
      {
        timeout = 300;
        on-timeout = "hyprlock";
      }
      {
        timeout = 600;
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "hyprctl dispatch dpms on";
      }
    ];
  };
};
```

---

### Priority 8: Consider Alternative Window Managers

**Based on research, here's comparison:**

| Window Manager | Pros                                  | Cons                     | For You?                            |
| -------------- | ------------------------------------- | ------------------------ | ----------------------------------- |
| **Hyprland**   | Modern, Wayland, fast, rich ecosystem | Newer, smaller community | ✅ **YES** - You have this, keep it |
| **i3**         | Mature, stable, huge community        | X11 only, no Wayland     | ❌ No - Hyprland better             |
| **Sway**       | i3-compatible, Wayland                | Less active development  | ⚠️ Maybe - If you want i3-style      |
| **bspwm**      | Lightweight, fast                     | Tiling only, no floating | ❌ No - Hyprland more features      |
| **awesome**    | Lua-configurable, very flexible       | Steeper learning curve   | ❌ No - Too complex                 |

**Recommendation:** **Stay with Hyprland** - It's best choice for 2025 with Wayland support and active development.

---

## 🎯 BEST PRACTICES FROM RESEARCH

### 1. Developer Workflow Optimizations

**Workspace Strategy:**

```
Workspace 1 (💻): Main terminal + IDE
Workspace 2 (🌐): Browser + docs
Workspace 3 (📁): File managers
Workspace 4 (📝): Editors (neovim, code)
Workspace 5 (💬): Communication (discord, signal)
Workspace 6 (🔧): System tools (htop, btop, logs)
Workspace 7 (🎮): Games/entertainment
Special Workspace (📋): Scratchpads (keepassxc, notes)
```

**Terminal Integration:**

- Use tmux for session management
- Set up different sessions: `dev`, `sys`, `ops`
- Quick access with keybindings

**Clipboard Management:**

- You have `cliphist` installed ✅
- Add keybinding to access history:

```nix
"$mod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
```

---

### 2. Performance Tuning (AMD GPU Specific)

**Your current setup is good** but add these:

```nix
environment.sessionVariables = {
  # Add these if missing
  GBM_BACKEND = "amd";  # Set GBM backend for AMD
  AMD_VULKAN_ICD = "RADV";  # Use RADV for Vulkan (faster than AMDVLK)
};
```

**Monitor GPU Performance:**

```bash
# Add to autostart
nvtop &  # GPU monitoring
```

---

### 3. Visual Enhancements

**Add swww for animated wallpapers:**

```nix
# Already have swww installed
# Add to exec-once in hyprland.nix
"exec-once = ["
  "swww-daemon &"
  "swww img ~/.config/wallpapers/current.png"
"];"
```

**Create wallpaper rotation script:**

```bash
#!/usr/bin/env fish
# ~/.local/bin/rotate-wallpaper
set wallpapers ~/.config/wallpapers/*
set random_wallpaper (random choice $wallpapers)
swww img $random_wallpaper --transition-type grow --transition-fps 60
```

---

## 📝 IMPLEMENTATION ROADMAP

### Phase 1: Critical Fixes (30 minutes)

1. ✅ Fix Waybar media module format string
2. ✅ Create security-status.sh or remove module
3. ✅ Test to verify errors are gone

### Phase 2: Plugin Installation (1 hour)

1. ✅ Add hy3 plugin
2. ✅ Test hy3 layout
3. ✅ Configure hy3 keybindings

### Phase 3: Enhanced Keybindings (1 hour)

1. ✅ Add development-focused shortcuts
2. ✅ Create resize submap
3. ✅ Add clipboard history shortcut

### Phase 4: Performance Optimizations (30 minutes)

1. ✅ Add render settings
2. ✅ Add misc optimizations
3. ✅ Test performance impact

### Phase 5: Visual Enhancements (1 hour)

1. ✅ Add workspace naming
2. ✅ Configure swww wallpapers
3. ✅ Create rotation script

### Phase 6: Advanced Features (optional, 2 hours)

1. ⚠️ Add hyprsplit for multi-monitor
2. ⚠️ Configure hypridle
3. ⚠️ Integrate ghost-wallpaper module properly

---

## 🚀 QUICK WINS (Implement Today)

1. **Fix Waybar errors** (5 minutes)
2. **Add workspace naming** (2 minutes)
3. **Add clipboard history keybinding** (2 minutes)
4. **Add dev tool keybindings** (5 minutes)
5. **Enable swww daemon** (2 minutes)

Total time: **~16 minutes** for immediate improvements

---

## 📈 SYSTEM HEALTH

### Current State

- ✅ AMD GPU: No errors in dmesg
- ✅ Hyprland: Starts successfully
- ✅ Waybar: Running but with errors
- ⚠️ Media module: Not working (format error)
- ⚠️ Security module: Not working (missing script)
- ✅ Performance: Good (optimizations applied)

### Monitor Commands

```bash
# Check Hyprland status
hyprctl systeminfo

# Check active workspaces
hyprctl workspaces

# Check monitors
hyprctl monitors

# Watch logs
journalctl -f -u hyprland* --user
```

---

## 🎓 KEY LEARNINGS FROM RESEARCH

1. **Hyprland is the right choice** - Best for 2025 with Wayland support
2. **AMD GPU optimizations are critical** - You have most, add GBM_BACKEND
3. **Keyboard-driven workflows are fastest** - Add more shortcuts
4. **Plugins enhance productivity** - hy3, hyprsplit worth installing
5. **Performance > aesthetics** - Your current balance is good
6. **Workspace organization matters** - Naming helps muscle memory
7. **Idle management important** - Add hypridle for security

---

## 🔗 USEFUL RESOURCES

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Hyprland GitHub](https://github.com/hyprwm/Hyprland)
- [Hyprland Plugins](https://github.com/hyprwm/hyprland-plugins)
- [r/unixporn](https://reddit.com/r/unixporn) - For inspiration
- [Hyprland rices](https://github.com/topics/hyprland-configuration)

---

## ✅ SUMMARY

**Your Hyprland setup is solid!** The main issues are:

1. Waybar errors (quick fix)
2. Missing plugins (medium effort)
3. Can enhance keybindings and visual polish

**Recommended approach:** Fix critical issues first, then gradually add enhancements based on your workflow preferences.

**Next step:** Fix Waybar media module format string - this will eliminate constant error logs and clean up your system.
