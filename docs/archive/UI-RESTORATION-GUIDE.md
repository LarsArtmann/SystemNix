# 🚨 evo-x2 UI Restoration Guide

**Last Updated:** 2025-12-17
**Issue:** No UI after NixOS update
**Solution:** Hyprland desktop environment was disabled

---

## 🎯 QUICK FIX (5 minutes)

### 1. Pull Latest Changes

```bash
# SSH into your evo-x2
ssh lars@evo-x2

# Navigate to SystemNix
cd ~/projects/SystemNix  # Adjust path as needed

# Pull the UI fixes
git pull
```

### 2. Apply UI Configuration

```bash
# Rebuild with Hyprland enabled
sudo nixos-rebuild switch --flake .#evo-x2

# After rebuild completes, reboot to see UI
sudo reboot
```

---

## 🔍 VERIFICATION (Optional but Recommended)

After system boots into UI, verify everything works:

### Run Verification Script

```bash
# Execute the comprehensive verification
~/projects/SystemNix/scripts/verify-hyprland.sh
```

### Test Basic Functionality

1. **SDDM Login:** Should see graphical login screen
2. **Hyprland Desktop:** Wayland compositor should launch
3. **Waybar:** Status bar should appear at top
4. **Terminal:** Open with Super+Q (should be Kitty)
5. **App Launcher:** Open with Super+R (should be Rofi)

---

## 🛠️ WHAT WAS FIXED

### Root Cause

- Hyprland configuration was commented out in `platforms/nixos/users/home.nix`
- System lacked desktop environment, leaving only TTY access

### Comprehensive Improvements Applied

1. **Re-enabled Hyprland** in Home Manager configuration
2. **Fixed systemd conflicts** between UWSM and Home Manager
3. **Added Hyprland Cachix** for faster binary cache downloads
4. **Configured AMD GPU** optimizations for Ryzen AI Max+
5. **Added ecosystem tools** (hyprpaper, hyprlock, hypridle, etc.)
6. **Implemented polkit agents** for authentication
7. **Created verification script** for troubleshooting

---

## 🚀 ADVANCED TIPS

### Performance Monitoring

```bash
# Real-time GPU monitoring
amdgpu_top

# CPU+GPU monitoring
nvtop

# System resource usage
btop
```

### Useful Keybindings

- `Super+Q`: Open terminal (Kitty)
- `Super+R`: App launcher (Rofi)
- `Super+V`: Toggle floating window
- `Super+F`: Toggle fullscreen
- `Super+Shift+Number`: Move window to workspace
- `Super+Mouse_Drag`: Move/resize windows

### Wallpaper Management

```bash
# Set wallpaper
hyprctl dispatch wallpaper /path/to/image

# Animated wallpapers
swww img /path/to/image --transition-type random
```

---

## 🆘 TROUBLESHOOTING

### If UI Still Doesn't Appear

1. Check boot log: `journalctl -b -u systemd-logind`
2. Verify SDDM: `systemctl status sddm.service`
3. Check GPU: `lsmod | grep amdgpu`

### If Windows Don't Render

1. Check Hyprland: `journalctl --user -u hyprland`
2. Verify Wayland: `echo $XDG_SESSION_TYPE`
3. Test GPU: `glxinfo | grep "OpenGL renderer"`

### If Performance is Poor

1. Run verification script for recommendations
2. Check CPU scaling: `cpupower frequency-info`
3. Monitor thermals: `sensors`

---

## 📊 SYSTEM HEALTH

After applying fixes, your system should have:

- ✅ **Bootloader:** systemd-boot (100% functional)
- ✅ **Display Manager:** SDDM with Wayland support
- ✅ **Compositor:** Hyprland with Xwayland compatibility
- ✅ **GPU:** AMD Radeon with RADV Vulkan driver
- ✅ **Audio:** PipeWire with PulseAudio compatibility
- ✅ **Authentication:** Polkit agents configured
- ✅ **Monitoring:** Comprehensive GPU/CPU tools

---

## 🔄 MAINTENANCE

### Weekly Commands

```bash
# Update packages
sudo nix flake update && sudo nixos-rebuild switch --flake .

# Clean old generations
sudo nix-collect-garbage -d

# Verify configuration
~/projects/SystemNix/scripts/verify-hyprland.sh
```

### Monthly Commands

```bash
# Deep clean
sudo nix-collect-garbage

# Check for issues
sudo nixos-rebuild check --flake .
```

---

## 📞 IF ISSUES PERSIST

1. **Check Status:** Run verification script
2. **Review Logs:** `journalctl -b -p err`
3. **Rollback if needed:** `sudo nixos-rebuild switch --rollback`
4. **Emergency recovery:** Use backup configuration

---

_This guide restores the full graphical desktop environment on evo-x2 with all 2025 best practices implemented._
