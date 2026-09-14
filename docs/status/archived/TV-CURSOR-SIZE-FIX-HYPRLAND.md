# TV Cursor Size Fix for Hyprland (Wayland)

## Problem

**Cursor is ~8px (tiny)** when viewing TV from 2 meters away on Hyprland.

## Root Cause

In Wayland (Hyprland), cursor size **cannot be set via environment variables**:

- ❌ `XCURSOR_SIZE` = X11 only, doesn't work in Wayland
- ❌ `gtk.cursorTheme.size` = Only affects GTK apps, not compositor
- ❌ No Hyprland setting for cursor scaling

**Cursor size is determined ONLY by the cursor theme's built-in sizes.**

## Solution

Use a cursor theme with **extra-large (XL) cursor variants** built-in.

## Changes Made

### File: `platforms/nixos/users/home.nix`

#### 1. Install Bibata Cursor Theme

```nix
home.packages = with pkgs; [
  bibata-cursors  # Has XL size (96px)
];
```

**Bibata includes sizes**: 16, 24, 32, 48, 64, **96**

#### 2. Set Cursor Theme

```nix
home.sessionVariables = {
  XCURSOR_THEME = "Bibata-Modern-Classic";
  # XCURSOR_SIZE = "96";  # Optional: For X11 apps only
};
```

#### 3. Removed Ineffective Settings

```nix
# REMOVED - Doesn't work in Wayland:
# gtk.cursorTheme.size = "384";
# XCURSOR_SIZE = "384";
```

## Apply Changes

```bash
# Rebuild
sudo nixos-rebuild switch --flake .

# Restart Hyprland session (REQUIRED for cursor changes)
# Mod + Shift + E → logout
# Login again
```

## Available Bibata Variants

Choose any of these by changing `XCURSOR_THEME`:

- `Bibata-Modern-Classic` (default)
- `Bibata-Modern-Ice`
- `Bibata-Modern-Pink`
- `Bibata-Modern-Amber`
- `Bibata-Modern-Original`
- `Bibata-Original-Classic`
- `Bibata-Original-Ice`
- `Bibata-Original-Pink`
- `Bibata-Original-Amber`
- `Bibata-Original-Original`

**All have XL size (96px) built-in.**

## Expected Cursor Size

- **Bibata XL**: 96 pixels
- **Previously**: ~8 pixels
- **Improvement**: 12x larger

This should be **clearly visible** from 2 meters away.

## Alternative XL Cursor Themes

If Bibata isn't large enough, try these:

### Phinger Cursors

```nix
home.packages = [ phinger-cursors ];
home.sessionVariables = {
  XCURSOR_THEME = "phinger-cursors";
};
```

- Sizes: 18, 24, 36, 48, 64, 72, 96

### Volantes Cursors

```nix
home.packages = [ volantes-cursors ];
home.sessionVariables = {
  XCURSOR_THEME = "Volantes";
};
```

- Sizes: 18, 24, 36, 48, 72

### Capitaine Cursors

```nix
home.packages = [ capitaine-cursors ];
home.sessionVariables = {
  XCURSOR_THEME = "capitaine-cursors";
};
```

- Sizes: 24, 30, 36, 48, 60, 72

## Test After Applying

```bash
# Verify cursor theme
echo $XCURSOR_THEME

# Should show:
# Bibata-Modern-Classic

# Check if cursor file exists
ls ~/.local/share/icons/Bibata-Modern-Classic/cursors/left_ptr
```

## If Still Too Small

### Option 1: Use Largest Available Theme

Try `phinger-cursors` - has **96px and 108px** variants.

### Option 2: Scale Entire Display (Affects Everything)

Increase DPI scaling in Hyprland:

```nix
# In hyprland.nix
wayland.windowManager.hyprland.settings = {
  general = {
    border_size = 2;
    # DPI scaling
    "env:XCURSOR_SIZE" = 96;  # Doesn't work in Wayland
  };
};
```

**Note**: No direct DPI setting in Hyprland. Would need to use GPU scaling.

### Option 3: Create Custom XL Cursor Theme

Use Bibata as base and scale to 128-192px manually.

## Why Previous Attempts Failed

### XCURSOR_SIZE Variable

```bash
export XCURSOR_SIZE=384  # ❌ X11 only, Wayland ignores this
```

### GTK Cursor Size

```nix
gtk.cursorTheme.size = 384  # ❌ Only affects GTK apps, not compositor cursor
```

### Environment Variable Location

```nix
# ❌ System-level doesn't help if compositor doesn't support it
environment.sessionVariables.XCURSOR_SIZE = "384";
```

## Wayland Cursor Architecture

```
┌─────────────────────────────────────┐
│  Hyprland Compositor (Wayland)    │
│                                 │
│  Reads: XCURSOR_THEME             │
│  Uses: Cursor theme's built-in    │
│         sizes (cannot scale)        │
│                                 │
│  Renders: System cursor (global)    │
└─────────────────────────────────────┘
         ↓
    Uses XL variant (96px)
```

## Key Takeaway

**In Hyprland (Wayland):**

- ❌ Cannot scale cursor
- ❌ Cannot set cursor size via config
- ✅ Must use cursor theme with XL variants built-in
- ✅ Cursor theme determines all cursor sizes

---

_Last updated: January 14, 2026_
