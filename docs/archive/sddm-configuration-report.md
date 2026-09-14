# SDDM Configuration Report for NixOS with Hyprland

**Generated:** 2025-12-18
**Target System:** NixOS with AMD Ryzen AI Max+ 395 + Hyprland
**Current Status:** Basic SDDM configuration with Wayland support enabled

---

## 🔍 Current Configuration Analysis

### Current SDDM Setup

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;     # ⚠️  POTENTIAL STABILITY ISSUE
  theme = "sddm-sugar-dark";
};
```

### Critical Findings

1. **Experimental Wayland Enabled** - May cause stability issues with AMD GPU
2. **Missing Important Options** - No autoNumlock, enableHidpi, or extraPackages
3. **Theme Package Correctly Added** - Good setup in systemPackages
4. **Hyprland Integration** - Properly configured with UWSM and systemd support

---

## 📋 Complete SDDM Options Analysis

### 🔧 CORE DISPLAY MANAGER OPTIONS

#### **`services.displayManager.sddm.enable`**

- **Purpose:** Enables SDDM as the system display manager
- **Current:** `true` ✅
- **Recommendation:** Keep `true` - essential for login screen
- **Priority:** CRITICAL

#### **`services.displayManager.sddm.wayland.enable`**

- **Purpose:** Enables experimental Wayland support for SDDM itself
- **Current:** `true` ⚠️
- **Recommendation:** Set to `false` for stability
- **Priority:** HIGH
- **Reasoning:**
  - Experimental and known to cause black screens
  - AMD GPU compatibility issues
  - Hyprland works fine with SDDM in X11 mode
  - Wayland in SDDM ≠ Wayland in Hyprland

#### **`services.displayManager.sddm.wayland.compositor`**

- **Purpose:** Compositor for SDDM's own interface when in Wayland mode
- **Current:** Not set (defaults to "weston")
- **Recommendation:** Not needed when `wayland.enable = false`
- **Priority:** LOW

### 🎨 VISUAL AND THEMING OPTIONS

#### **`services.displayManager.sddm.theme`**

- **Purpose:** Sets the visual theme for login screen
- **Current:** `"sddm-sugar-dark"` ✅
- **Recommendation:** Keep current theme
- **Priority:** MEDIUM
- **Alternatives:** `"breeze"`, `"maldives"`, custom themes

#### **`services.displayManager.sddm.enableHidpi`**

- **Purpose:** Automatic HiDPI scaling for high-resolution displays
- **Current:** Not set (defaults to `true`)
- **Recommendation:** Keep default `true`
- **Priority:** MEDIUM
- **Note:** Important for 4K+ displays

### 📦 PACKAGE MANAGEMENT OPTIONS

#### **`services.displayManager.sddm.package`**

- **Purpose:** Which SDDM package to use
- **Current:** Not set (uses default `pkgs.kdePackages.sddm`)
- **Recommendation:** Keep default package
- **Priority:** LOW

#### **`services.displayManager.sddm.extraPackages`**

- **Purpose:** Additional Qt plugins/QML libraries
- **Current:** Not set (empty list)
- **Recommendation:** Add theme-specific packages if needed
- **Priority:** LOW

### ⚙️ BEHAVIORAL OPTIONS

#### **`services.displayManager.sddm.autoNumlock`**

- **Purpose:** Enables numlock at login screen
- **Current:** Not set (defaults to `false`)
- **Recommendation:** Set to `true` for usability
- **Priority:** LOW

#### **`services.displayManager.sddm.stopScript`**

- **Purpose:** Script executed when stopping display server
- **Current:** Not set
- **Recommendation:** Keep empty unless specific cleanup needed
- **Priority:** LOW

#### **`services.displayManager.sddm.setupScript`**

- **Purpose:** Script executed when starting display server (DEPRECATED)
- **Current:** Not set
- **Recommendation:** Use alternatives like `services.xserver.displayManager.setupCommands`
- **Priority:** LOW

### 🔧 ADVANCED CONFIGURATION OPTIONS

#### **`services.displayManager.sddm.settings`**

- **Purpose:** Fine-tuned SDDM configuration overrides
- **Current:** Not set (empty attrset)
- **Recommendation:** Add for optimal performance and security
- **Priority:** MEDIUM

#### **`services.displayManager.sddm.autoLogin.relogin`**

- **Purpose:** Auto-login again after session logout
- **Current:** Not set (defaults to `false`)
- **Recommendation:** Keep `false` for security
- **Priority:** SECURITY

#### **`services.displayManager.sddm.autoLogin.minimumUid`**

- **Purpose:** Minimum user ID for auto-login eligibility
- **Current:** Not set (defaults to `1000`)
- **Recommendation:** Keep default
- **Priority:** LOW

---

## 🎯 OPTIMAL CONFIGURATION FOR YOUR SETUP

### **Recommended Stable Configuration**

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = false;  # CRITICAL: Disable for stability
  theme = "sddm-sugar-dark";
  enableHidpi = true;
  autoNumlock = true;

  settings = {
    # General settings
    General = {
      HaltCommand = "/run/current-system/sw/bin/shutdown -h now";
      RebootCommand = "/run/current-system/sw/bin/reboot";
      Numlock = "on";  # Complements autoNumlock option
    };

    # Theme settings
    Theme = {
      Current = "sddm-sugar-dark";
      FacesDir = "/run/current-system/sw/share/sddm/faces";
      ThemeDir = "/run/current-system/sw/share/sddm/themes/sddm-sugar-dark";
    };

    # X11 settings (for display manager itself)
    X11 = {
      DisplayCommand = "";  # Let Hyprland handle display setup
      DisplayStopCommand = "";
      SessionCommand = "/run/current-system/sw/bin/startplasma-x11";  # Should be adjusted for Hyprland
      SessionDir = "/run/current-system/sw/share/sddm/sessions";
      SessionLogFile = "/var/log/sddm.log";
    };
  };

  # Ensure theme package is available
  extraPackages = with pkgs; [
    sddm-sugar-dark
    # Add additional QML components if theme requires
  ];
};
```

### **Alternative: Minimal Stable Configuration**

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = false;  # Keep SDDM in X11 for stability
  theme = "sddm-sugar-dark";
  enableHidpi = true;
  autoNumlock = true;
};
```

---

## ⚠️ CRITICAL WARNINGS FOR AMD GPU + HYPRLAND

### **1. Wayland Compatibility Issues**

- **Problem:** SDDM Wayland mode has known issues with AMD GPUs
- **Solution:** Keep `wayland.enable = false` for SDDM
- **Impact:** SDDM runs in X11 mode, but Hyprland still runs in Wayland

### **2. Session Registration**

- **Requirement:** Ensure Hyprland session is properly registered
- **Solution:** Verify `/share/wayland-sessions/hyprland.desktop` exists

### **3. Theme Rendering**

- **Issue:** Some themes may not render correctly with AMD drivers
- **Solution:** Test themes; fallback to basic theme if issues occur

### **4. Performance Optimization**

- **GPU Variables:** AMD-specific variables already configured in `amd-gpu.nix`
- **Display Scaling:** Configure both in SDDM and Hyprland for consistency

---

## 🔒 SECURITY CONSIDERATIONS

### **Auto-Login Security**

- **Current:** Not configured
- **Recommendation:** Keep disabled for security
- **If Needed:** Only for development/kiosk systems

### **Session Isolation**

- **Important:** SDDM should not interfere with Hyprland's security model
- **Configuration:** Minimize SDDM customizations to avoid conflicts

### **Authentication**

- **Current:** Polkit properly configured
- **Recommendation:** Keep current authentication setup

---

## 🚀 IMPLEMENTATION PRIORITY

### **Phase 1: Critical Fixes (Immediate)**

1. **Disable SDDM Wayland** (`wayland.enable = false`)
2. **Add autoNumlock** for better usability
3. **Verify enableHidpi** for your display

### **Phase 2: Optimization (Short-term)**

1. **Add settings section** for fine-tuned control
2. **Configure session paths** properly
3. **Test theme compatibility** with AMD GPU

### **Phase 3: Advanced (Optional)**

1. **Add custom stopScript** if cleanup needed
2. **Explore alternative themes** for better aesthetics
3. **Configure auto-login** only if required for specific use case

---

## 📊 TESTING AND VERIFICATION

### **Pre-Implementation Tests**

```bash
# Test current configuration
sudo nixos-rebuild test --flake .#evo-x2

# Check available SDDM sessions
ls /run/current-system/sw/share/sddm/sessions/
```

### **Post-Implementation Verification**

```bash
# Apply changes
sudo nixos-rebuild switch --flake .#evo-x2

# Verify SDDM is running
systemctl status sddm

# Check logs for errors
journalctl -u sddm -f
```

### **Performance Monitoring**

```bash
# Monitor GPU usage during login
amdgpu_top

# Check display server startup time
systemd-analyze blame | grep sddm
```

---

## 🎯 FINAL RECOMMENDATIONS

### **Immediate Action Required**

1. **Set `wayland.enable = false`** - This is the most critical fix for stability
2. **Add `autoNumlock = true`** - Improves user experience
3. **Keep current theme** - `sddm-sugar-dark` works well

### **Long-term Considerations**

1. **Monitor SDDM Wayland development** - May become stable in future
2. **Backup working configuration** - Before making experimental changes
3. **Test thoroughly** after each change

### **Hardware-Specific Notes**

- **AMD GPU:** Current configuration in `amd-gpu.nix` is optimal
- **High DPI:** Ensure consistent scaling between SDDM and Hyprland
- **Performance:** SDDM has minimal impact on Hyprland performance

---

## 📝 IMPLEMENTATION CHECKLIST

### **Before Making Changes**

- [ ] Create system backup
- [ ] Test current configuration
- [ ] Document current SDDM behavior

### **Implementation Steps**

- [ ] Disable SDDM Wayland support
- [ ] Add autoNumlock configuration
- [ ] Verify HiDPI settings
- [ ] Test theme functionality
- [ ] Verify session registration
- [ ] Apply and test configuration

### **Post-Implementation**

- [ ] Verify login screen works
- [ ] Test Hyprland session launch
- [ ] Check for errors in logs
- [ ] Monitor GPU behavior
- [ ] Document any issues

---

## 🆘 TROUBLESHOOTING

### **Common Issues and Solutions**

#### **Black Screen on Login**

- **Cause:** SDDM Wayland mode with AMD GPU
- **Solution:** Set `wayland.enable = false`

#### **Session Not Appearing in SDDM**

- **Cause:** Missing session file
- **Solution:** Verify Hyprland session registration

#### **Theme Not Loading**

- **Cause:** Missing theme package or incorrect path
- **Solution:** Verify theme package installation

#### **Performance Issues**

- **Cause:** GPU driver conflicts
- **Solution:** Review AMD GPU configuration

---

_This report is tailored specifically for your AMD Ryzen AI Max+ 395 system with Hyprland. The recommendations prioritize stability and security while maintaining optimal performance._
