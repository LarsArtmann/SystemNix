# SDDM Configuration Implementation Steps

**Purpose:** Implement optimal SDDM configuration for NixOS with AMD GPU + Hyprland
**Target:** `/Users/larsartmann/projects/SystemNix/platforms/nixos/desktop/hyprland-system.nix`

---

## 🎯 IMPLEMENTATION STEPS

### **Step 1: Create Backup and Verify Current State**

```bash
# Create backup of current configuration
cp /Users/larsartmann/projects/SystemNix/platforms/nixos/desktop/hyprland-system.nix \
   /Users/larsartmann/projects/SystemNix/platforms/nixos/desktop/hyprland-system.nix.backup

# Test current configuration (safe, doesn't apply changes)
sudo nixos-rebuild test --flake .#evo-x2
```

### **Step 2: Apply Critical Stability Fix**

Replace the current SDDM configuration with the stable version:

**FROM:**

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;  # ⚠️ Experimental - causes stability issues
  theme = "sddm-sugar-dark";
};
```

**TO:**

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = false;  # ✅ Stable - recommended for AMD GPU
  theme = "sddm-sugar-dark";
  enableHidpi = true;
  autoNumlock = true;
};
```

### **Step 3: Apply Changes and Test**

```bash
# Test the configuration without applying
sudo nixos-rebuild test --flake .#evo-x2

# If test passes, apply the changes
sudo nixos-rebuild switch --flake .#evo-x2

# Verify SDDM status
systemctl status sddm

# Check for any errors
journalctl -u sddm --since "5 minutes ago"
```

### **Step 4: Advanced Configuration (Optional)**

For enhanced control, add settings section:

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = false;
  theme = "sddm-sugar-dark";
  enableHidpi = true;
  autoNumlock = true;

  settings = {
    General = {
      HaltCommand = "/run/current-system/sw/bin/shutdown -h now";
      RebootCommand = "/run/current-system/sw/bin/reboot";
      Numlock = "on";
    };

    Theme = {
      Current = "sddm-sugar-dark";
      FacesDir = "/run/current-system/sw/share/sddm/faces";
      ThemeDir = "/run/current-system/sw/share/sddm/themes/sddm-sugar-dark";
    };
  };
};
```

---

## 🔍 VERIFICATION CHECKLIST

### **After Step 2 (Critical Fixes)**

- [ ] Configuration test passes without errors
- [ ] SDDM service starts successfully
- [ ] Login screen appears without black screen
- [ ] Hyprland session is available in session list
- [ ] Numlock is enabled at login

### **After Step 4 (Advanced Config)**

- [ ] Theme loads correctly
- [ ] Session switching works properly
- [ ] No errors in system logs
- [ ] GPU performance is normal

---

## 🚨 EMERGENCY RECOVERY

### **If Login Screen Fails**

**Method 1: Rollback**

```bash
# Switch to previous generation
sudo nixos-rebuild switch --rollback

# Or rollback to specific generation
sudo nixos-rebuild switch --profile-name /nix/var/nix/profiles/system-XXX-link
```

**Method 2: TTY Recovery**

```bash
# Switch to TTY (Ctrl+Alt+F3)
# Restore backup configuration
sudo cp /Users/larsartmann/Desktop/Setup-Mac/platforms/nixos/desktop/hyprland-system.nix.backup \
     /Users/larsartmann/Desktop/Setup-Mac/platforms/nixos/desktop/hyprland-system.nix

# Rebuild and apply
sudo nixos-rebuild switch --flake .#evo-x2
```

**Method 3: Minimal Recovery**

```bash
# Create minimal working SDDM config
cat > /tmp/minimal-sddm.nix << 'EOF'
services.displayManager.sddm = {
  enable = true;
  wayland.enable = false;
};
EOF

# Apply minimal config
sudo cp /tmp/minimal-sddm.nix /etc/nixos/sddm-minimal.nix
# Add to configuration.nix imports and rebuild
```

---

## 📊 PERFORMANCE MONITORING

### **GPU Monitoring During Login**

```bash
# Monitor AMD GPU during login
watch -n 1 'cat /sys/class/drm/card0/device/gpu_busy_percent'

# Check VRAM usage
cat /sys/class/drm/card0/device/mem_info_vram_total
cat /sys/class/drm/card0/device/mem_info_vram_used
```

### **Display Server Performance**

```bash
# Check SDDM startup time
systemd-analyze blame | grep sddm

# Monitor display server processes
ps aux | grep -E "(sddm|Xorg|wayland)"
```

---

## 🧪 TROUBLESHOOTING GUIDE

### **Issue: Black Screen After Login**

```bash
# Check SDDM logs
journalctl -u sddm -f

# Verify X11 server is running
ps aux | grep Xorg

# Check GPU driver status
lspci -k | grep -A 2 -i vga
```

### **Issue: Hyprland Session Not Available**

```bash
# Check session files
ls -la /run/current-system/sw/share/wayland-sessions/
ls -la /run/current-system/sw/share/xsessions/

# Verify Hyprland installation
which Hyprland
hyprctl version
```

### **Issue: Theme Not Loading**

```bash
# Check theme installation
ls -la /run/current-system/sw/share/sddm/themes/

# Verify theme package
nix-store -q /run/current-system/sw/share/sddm/themes/sddm-sugar-dark
```

---

## 📈 EXPECTED IMPROVEMENTS

### **After Critical Fixes (Step 2)**

- ✅ Eliminate black screen issues
- ✅ Improve login reliability with AMD GPU
- ✅ Faster login screen startup
- ✅ Better overall system stability

### **After Advanced Configuration (Step 4)**

- ✅ Consistent numlock behavior
- ✅ Proper theme rendering
- ✅ Optimized session management
- ✅ Better integration with Hyprland

---

## 🎯 SUCCESS CRITERIA

### **Minimum Viable Configuration**

- Login screen appears consistently
- Hyprland session launches successfully
- No display crashes or black screens
- Stable GPU performance

### **Optimal Configuration**

- All of above plus:
- Numlock enabled at login
- Theme renders correctly
- Fast login screen startup (< 3 seconds)
- No error messages in logs
- Proper session switching

---

## 🔄 MAINTENANCE

### **Regular Checks (Monthly)**

```bash
# Verify SDDM configuration
sudo nixos-rebuild test --flake .#evo-x2

# Check for package updates
nix flake update

# Monitor GPU health
amdgpu_top
```

### **After System Updates**

```bash
# Rebuild and test after major updates
sudo nixos-rebuild test --flake .#evo-x2
sudo nixos-rebuild switch --flake .#evo-x2

# Verify everything still works
systemctl status sddm
```

---

## 📝 IMPLEMENTATION NOTES

### **Why Disable SDDM Wayland?**

- Experimental status causes instability
- AMD GPU compatibility issues
- Hyprland runs in Wayland regardless
- SDDM Wayland ≠ Compositor Wayland

### **Configuration Philosophy**

- Minimal changes for maximum stability
- AMD GPU-specific optimizations
- Clean separation between display manager and compositor
- Security-conscious defaults

### **Future Considerations**

- Monitor SDDM Wayland development
- May enable when stable for AMD GPUs
- Keep backup of working configuration
- Document any customizations for future reference

---

_This implementation prioritizes stability and security for your AMD GPU + Hyprland setup. Execute steps sequentially and verify each step before proceeding._
