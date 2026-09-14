# Hyprland + AMD GPU Optimization Summary

## Overview

This document summarizes the optimizations applied to the NixOS configuration for optimal Hyprland performance on AMD hardware (Ryzen AI Max+).

## Questions Answered

### 1. Is Hyprland using Home Manager?

**YES** - And this is the recommended approach:

- **System Level** (`programs.hyprland`): Core package, Xwayland, portal integration
- **User Level** (`wayland.windowManager.hyprland`): Window manager configuration, keybindings, rules

### 2. Is OpenGL enabled?

**YES** - OpenGL is enabled via `hardware.graphics.enable = true` with AMD-specific optimizations

## Applied Optimizations

### 1. Enhanced Graphics Packages (dotfiles/nixos/configuration.nix)

```nix
hardware.graphics = {
  enable = true;
  enable32Bit = true;
  extraPackages = with pkgs; [
    rocmPackages.clr.icd  # OpenCL support
    amdvlk                # AMD Vulkan driver
    libva                 # Video acceleration API
    libvdpau-va-gl       # VDPAU backend for video acceleration
  ];
};
```

### 2. AMD Kernel Parameters (dotfiles/nixos/configuration.nix)

```nix
boot.kernelParams = [
  "amdgpu.ppfeaturemask=0xfffd7fff"  # Enable all GPU features
  "amdgpu.deepfl=1"                  # Enable deep frequency control
  "amd_pstate=guided"                # Performance mode for AMD CPUs
  "processor.max_cstate=1"           # C-state optimization
];
```

### 3. Performance Environment Variables (dotfiles/nixos/configuration.nix)

```nix
environment.sessionVariables = {
  # Graphics driver settings
  __GLX_VENDOR_LIBRARY_NAME = "mesa";
  LIBVA_DRIVER_NAME = "radeonsi";
  AMD_VULKAN_ICD = "RADV";
  # Wayland/Hyprland specific
  WLR_RENDERER_ALLOW_SOFTWARE = "1";
  WLR_NO_HARDWARE_CURSORS = "1";
  # Performance optimization
  MESA_VK_WSI_PRESENT_MODE = "fifo";
};
```

### 4. Monitoring Tools Added (dotfiles/nixos/configuration.nix)

```nix
environment.systemPackages = with pkgs; [
  # AMD GPU monitoring and control
  amdgpu_top     # GPU monitoring tool
  corectrl       # AMD CPU control
  vulkan-tools   # Vulkan utilities
  mesa-demos     # GPU testing tools
  # ... (previous packages)
];
```

### 5. Hyprland Rendering Optimizations (platforms/nixos/desktop/hyprland.nix)

```nix
misc = {
  force_default_wallpaper = 0;
  # Performance optimizations
  disable_hyprland_logo = true;
  disable_splash_rendering = true;
  mouse_refocus = false;
  new_window_takes_over_fullscreen = true;
};

render = {
  explicit_sync = true;
  direct_scanout = true;
};
```

### 6. User-level Monitoring Tools (platforms/nixos/desktop/hyprland.nix)

```nix
home.packages = with pkgs; [
  # ... (previous packages)
  # Additional monitoring tools
  nvtopPackages.amd  # AMD GPU/process monitor
  radeontop           # AMD GPU specific monitor
];
```

## Verification Tools Created

### verify-hyprland.sh

A comprehensive script that checks:

- AMD GPU driver status
- OpenGL/Vulkan support
- Kernel parameters
- Environment variables
- Hyprland configuration
- Monitoring tools availability
- Optional GPU benchmarking

## Usage Instructions

### To Apply Changes

```bash
sudo nixos-rebuild switch --flake .#evo-x2
```

### To Verify Optimizations

```bash
./verify-hyprland.sh
```

### To Monitor GPU Performance

```bash
# Real-time GPU monitoring
amdgpu_top

# GPU process monitoring (AMD specific)
nvtop

# AMD GPU specific monitoring
radeontop

# AMD CPU control
corectrl
```

## Expected Benefits

1. **Better GPU Utilization**: AMD-specific drivers and optimizations
2. **Improved Performance**: Kernel parameters and environment variables
3. **Enhanced Stability**: Proper 32-bit support for compatibility
4. **Better Monitoring**: Real-time visibility into GPU/CPU performance
5. **Optimized Rendering**: Direct scanout and explicit sync for smoother visuals

## Troubleshooting

### If GPU driver not loaded:

- Check hardware compatibility
- Verify amdgpu is in kernel modules
- Run `lspci -nnk | grep -i vga`

### If Vulkan not working:

- Verify installation with `vulkaninfo`
- Check that AMD_VULKAN_ICD=RADV is set
- Ensure proper GPU drivers are installed

### If Hyprland performance issues:

- Check that user is in 'video' and 'input' groups
- Verify Wayland environment variables
- Test with minimal Hyprland config

## Resources

- [AMDGPU Linux Documentation](https://www.kernel.org/doc/html/latest/gpu/amdgpu.html)
- [Hyprland Configuration](https://wiki.hyprland.org/Configuring/)
- [NixOS Hardware Configuration](https://nixos.org/manual/nixos/stable/index.html#sec-hardware-configuration)
