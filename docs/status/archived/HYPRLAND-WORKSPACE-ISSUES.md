# Hyprland Workspace Issues & Solutions

**Date:** 2025-12-31
**Problem:** Multiple virtual desktops not working correctly

- Everything stays same after switching workspaces
- Everything disappears when switching workspaces

---

## 🔍 Root Cause Analysis

### Issue 1: 200% Monitor Scaling

**File:** `platforms/nixos/desktop/hyprland.nix:25`

```nix
monitor = "HDMI-A-1,preferred,auto,2";  # 2x scaling for TV
```

**Problem:** 200% scaling can cause:

- Windows to render off-screen or in wrong positions
- Workspace switching visual glitches
- Incorrect window size calculations
- Focus issues when switching workspaces

**Impact:** HIGH - Likely primary cause of workspace issues

---

### Issue 2: No Workspace Window Rules

**File:** `platforms/nixos/desktop/hyprland.nix:47-77`

**Problem:** No persistent window rules for applications

- Applications don't remember which workspace they belong to
- Every new window opens on current workspace
- No logical workspace organization

**Current state:** Only has window rules for background consoles (htop-bg, logs-bg, nvim-bg)

**Impact:** HIGH - Makes workspace switching ineffective

---

### Issue 3: Slow Workspace Animation

**File:** `platforms/nixos/desktop/hyprland.nix:116`

```nix
"workspaces, 1, 4, default, slidefadevert"
```

**Problem:** 4-second animation duration makes workspace switching feel broken:

- User thinks nothing is happening during animation
- Visual confusion during long transition
- Hard to tell if workspace actually changed

**Impact:** MEDIUM - UX issue

---

### Issue 4: Missing Workspace Management Plugins

**Problem:** No advanced workspace plugins installed

- No `hyprsplit` plugin for better multi-monitor support
- No `virtual-desktops` plugin for desktop-level organization
- Standard Hyprland workspaces are monitor-specific, not global

**Impact:** MEDIUM - Limits workspace functionality

---

### Issue 5: No Explicit Workspace on Monitor Rules

**Problem:** Workspaces can span across monitors unpredictably

- Hyprland default behavior: workspace 1 appears on first monitor
- Switching to workspace 1 switches the first monitor
- Second monitor stays on previous workspace
- Can cause windows to disappear from view

**Impact:** HIGH - Confusing workspace behavior

---

## ✅ Recommended Solutions

### Solution 1: Fix Monitor Scaling (PRIORITY 1)

**Option A: Reduce scaling to 150%**

```nix
monitor = "HDMI-A-1,preferred,auto,1.5";  # 150% scaling
```

**Option B: Reduce scaling to 125%**

```nix
monitor = "HDMI-A-1,preferred,auto,1.25";  # 125% scaling
```

**Option C: Disable scaling temporarily**

```nix
monitor = "HDMI-A-1,preferred,auto,1";  # 100% scaling
```

**Recommendation:** Try 125% first, adjust based on visibility needs.

**Why this helps:**

- Reduces window positioning bugs
- Eliminates off-screen rendering issues
- Improves workspace switching performance
- Better window size calculations

---

### Solution 2: Add Persistent Workspace Window Rules (PRIORITY 2)

**Add window rules for common applications:**

```nix
windowrulev2 = [
  # Existing background console rules...
  "float,class:^(htop-bg)$"
  "nofocus,class:^(htop-bg)$"
  # ... more htop-bg rules ...

  # NEW: Terminal windows on workspace 1
  "workspace 1,class:^(kitty)$"
  "workspace 1,class:^(alacritty)$"
  "workspace 1,class:^(ghostty)$"

  # NEW: Browser windows on workspace 2
  "workspace 2,class:^(firefox)$"
  "workspace 2,class:^(chromium)$"

  # NEW: File manager on workspace 3
  "workspace 3,class:^(dolphin)$"
  "workspace 3,class:^(thunar)$"
  "workspace 3,class:^(nautilus)$"

  # NEW: Editor windows on workspace 4
  "workspace 4,class:^(nvim)$"
  "workspace 4,class:^(code)$"
  "workspace 4,class:^(codium)$"

  # NEW: Communication apps on workspace 5
  "workspace 5,class:^(signal)$"
  "workspace 5,class:^(discord)$"
  "workspace 5,class:^(Element)$"

  # Keep background consoles visible on all workspaces
  "noborder,class:^(htop-bg)$"
  "noborder,class:^(logs-bg)$"
  "noborder,class:^(nvim-bg)$"
];
```

**Why this helps:**

- Applications open on designated workspaces
- Workspace switching shows different sets of windows
- Logical workspace organization
- Easier workflow management

---

### Solution 3: Speed Up Workspace Animation (PRIORITY 3)

**Reduce animation duration from 4s to 0.5s:**

```nix
animations = {
  enabled = true;
  bezier = "myBezier, 0.25, 0.46, 0.45, 0.94";
  animation = [
    "windows, 1, 3, myBezier, slide"
    "windowsOut, 1, 2, default, popin 90%"
    "border, 1, 5, default"
    "borderangle, 1, 6, default"
    "fade, 1, 3, default"
    "workspaces, 1, 0.5, default, slidefadevert"  # Changed from 4 to 0.5
    "specialWorkspace, 1, 0.5, default, slidefadevert"  # Changed from 4 to 0.5
  ];
};
```

**Alternative: Disable workspace animations entirely**

```nix
animation = [
  "windows, 1, 3, myBezier, slide"
  "windowsOut, 1, 2, default, popin 90%"
  "border, 1, 5, default"
  "borderangle, 1, 6, default"
  "fade, 1, 3, default"
  "workspaces, 1, 0, default"  # Instant switching, no animation
  "specialWorkspace, 1, 0, default"
];
```

**Why this helps:**

- Instant workspace switching
- Clear visual feedback
- Eliminates "stuck" feeling
- Better responsiveness

---

### Solution 4: Enable Workspace on Monitor Rules (PRIORITY 4)

**Force specific workspaces on specific monitors:**

```nix
# After monitor definition
workspace = 1, monitor:HDMI-A-1, default:true
workspace = 2, monitor:HDMI-A-1, default:true
workspace = 3, monitor:HDMI-A-1, default:true
workspace = 4, monitor:HDMI-A-1, default:true
workspace = 5, monitor:HDMI-A-1, default:true
```

**Alternative: Use monitor-specific workspace naming**

```nix
monitor = "HDMI-A-1,preferred,auto,1.25"

# All workspaces explicitly on this monitor
bind = $mod, 1, focusworkspaceoncurrentmonitor, 1
bind = $mod, 2, focusworkspaceoncurrentmonitor, 2
bind = $mod, 3, focusworkspaceoncurrentmonitor, 3
# ... etc
```

**Why this helps:**

- Workspaces stay on correct monitor
- Predictable workspace behavior
- No windows disappearing to wrong monitor
- Better multi-monitor support

---

### Solution 5: Add Hyprsplit Plugin (PRIORITY 5 - Optional)

**Install hyprsplit plugin for better workspace management:**

```nix
# In platforms/nixos/desktop/hyprland.nix
wayland.windowManager.hyprland = {
  enable = true;

  plugins = with pkgs; [
    hyprlandPlugins.hyprwinwrap
    hyprlandPlugins.hyprsplit  # ADD THIS
  ];

  settings = {
    plugin = {
      hyprwinwrap = {
        class = "btop-bg";
      };

      hyprsplit = {
        num_workspaces = 10
        persistent_workspaces = true
      }
    };
  };
};
```

**Update workspace bindings to use hyprsplit:**

```nix
bind = [
  # Use hyprsplit workspace commands
  "$mod, 1, split:workspace, 1"
  "$mod, 2, split:workspace, 2"
  "$mod, 3, split:workspace, 3"
  # ... etc

  # Add keybind to grab rogue windows
  "$mod, G, split:grabroguewindows"
];
```

**Why this helps:**

- Better multi-monitor workspace support
- Recover lost windows easily
- More predictable workspace behavior
- Advanced workspace features

---

### Solution 6: Add Virtual Desktops Plugin (PRIORITY 6 - Optional)

**For true virtual desktop behavior (windows persist across desktops):**

```nix
wayland.windowManager.hyprland = {
  enable = true;

  plugins = with pkgs; [
    hyprlandPlugins.hyprwinwrap
    hyprlandPlugins.hyprsplit
    hyprlandPlugins.virtual-desktops  # ADD THIS
  ];

  settings = {
    plugin = {
      hyprwinwrap = {
        class = "btop-bg";
      };

      hyprsplit = {
        num_workspaces = 10
        persistent_workspaces = true
      }

      virtual-desktops = {
        names = 1:main, 2:work, 3:media, 4:comm
        rememberlayout = size
        cycleworkspaces = 1
      }
    };
  };

  # Add virtual desktop bindings
  bind = [
    "$mod, TAB, vdesk, next"      # Switch to next virtual desktop
    "$mod SHIFT, TAB, vdesk, prev"  # Switch to previous virtual desktop
    "$mod, grave, lastdesk"         # Go to last visited desktop
  ];
};
```

**Why this helps:**

- True virtual desktop behavior (like GNOME/KDE)
- Windows stay on their virtual desktops
- Remembers layouts across desktop switches
- More traditional desktop experience

---

## 🎯 Implementation Priority

### Phase 1: Quick Fixes (Do Immediately)

1. **Reduce monitor scaling** - Try 125% or 150%
2. **Speed up workspace animation** - Change 4s to 0.5s
3. **Test workspace switching** - Verify fixes work

### Phase 2: Persistent Rules (Do Next)

4. **Add workspace window rules** - For terminal, browser, file manager, etc.
5. **Enable workspace on monitor rules** - Force workspaces to monitor

### Phase 3: Advanced Features (Do If Needed)

6. **Add hyprsplit plugin** - For better multi-monitor support
7. **Add virtual-desktops plugin** - For true virtual desktop behavior

---

## 🧪 Testing Checklist

After implementing fixes, test:

### Basic Workspace Switching

- [ ] Press $mod+1 to go to workspace 1
- [ ] Press $mod+2 to go to workspace 2
- [ ] Verify windows appear/disappear correctly
- [ ] Check no off-screen windows

### Application Workspace Rules

- [ ] Open terminal (kitty) - should go to workspace 1
- [ ] Open browser (firefox) - should go to workspace 2
- [ ] Open file manager (dolphin) - should go to workspace 3
- [ ] Open editor (nvim) - should go to workspace 4

### Multi-Monitor Behavior

- [ ] Workspaces stay on correct monitor
- [ ] No windows disappear when switching
- [ ] Background consoles visible on all workspaces

### Animation and Responsiveness

- [ ] Workspace switching feels instant
- [ ] No visual glitches during switch
- [ ] Clear feedback when workspace changes

---

## 🔧 Debugging Commands

If issues persist, use these commands:

```bash
# Check current workspace state
hyprctl workspaces

# Check active clients (windows)
hyprctl clients

# Check monitor configuration
hyprctl monitors

# Check for errors in logs
journalctl -u hyprland -f

# Reload configuration
hyprctl reload

# Kill and restart Hyprland
pkill Hyprland
```

---

## 📊 Expected Results

After implementing Phase 1 (Scaling + Animation):

- ✅ Workspace switching works instantly
- ✅ No windows disappear or stay stuck
- ✅ Clear visual feedback when switching
- ✅ All windows visible on correct workspace

After implementing Phase 2 (Window Rules):

- ✅ Applications open on designated workspaces
- ✅ Each workspace has different set of windows
- ✅ Logical workspace organization
- ✅ Predictable workspace behavior

After implementing Phase 3 (Plugins):

- ✅ Advanced multi-monitor support
- ✅ Lost window recovery
- ✅ True virtual desktop behavior (if desired)

---

## 📝 Notes

- **Monitor scaling is likely the root cause** - Start there
- **Workspace animation is too slow** - Fix to 0.5s or disable
- **No window rules** - Makes workspaces ineffective
- **Hyprland workspaces are monitor-specific** - Not global by default
- **Plugins can enhance functionality** - But not strictly necessary

---

**End of Document**
