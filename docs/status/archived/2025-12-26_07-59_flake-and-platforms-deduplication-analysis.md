# Flake and Platforms De-duplication Analysis

**Date:** 2025-12-26 07:59 CET
**Scope:** Comprehensive analysis of `flake.nix` and `platforms/` folder structure
**Status:** Research & Analysis Complete

---

## Executive Summary

This analysis provides a thorough examination of the current state of Setup-Mac's flake and platforms architecture, identifying significant duplications across macOS (nix-darwin) and NixOS configurations. The findings reveal multiple layers of duplication requiring systematic de-duplication to improve maintainability, reduce errors, and ensure consistency across platforms.

**Key Findings:**

- 15+ duplicated packages across platform-specific modules
- Inconsistent package organization patterns
- Mixed concerns across multiple modules
- Opportunity to consolidate into clear, hierarchical structure

---

## Current State Analysis

### 1. Architecture Overview

```
Setup-Mac/
├── flake.nix                      # Main entry point with flake-parts
├── platforms/
│   ├── common/                    # Shared configurations
│   │   ├── packages/
│   │   │   ├── base.nix          # Cross-platform base packages
│   │   │   ├── helium.nix        # Helium browser wrapper
│   │   │   └── tuios.nix        # TUI applications
│   │   ├── core/                 # Type safety & Nix settings
│   │   ├── environment/          # Shared environment variables
│   │   ├── programs/            # Cross-platform program configs
│   │   ├── home-base.nix        # Home Manager base config
│   │   └── wrappers/           # Wrapper system
│   ├── darwin/                  # macOS-specific configurations
│   │   ├── default.nix          # Main Darwin config entry
│   │   ├── environment.nix      # Darwin environment variables & packages
│   │   ├── nix/settings.nix    # Darwin Nix settings
│   │   ├── programs/shells.nix  # Fish shell config
│   │   └── system/             # Darwin system settings
│   └── nixos/                  # NixOS-specific configurations
│       ├── system/
│       │   ├── configuration.nix  # Main NixOS config entry
│       │   ├── boot.nix
│       │   └── networking.nix
│       ├── hardware/
│       │   ├── hardware-configuration.nix
│       │   └── amd-gpu.nix
│       ├── desktop/             # Desktop environment configs
│       │   ├── ai-stack.nix
│       │   ├── monitoring.nix
│       │   ├── security-hardening.nix
│       │   ├── hyprland.nix
│       │   ├── hyprland-system.nix
│       │   ├── hyprland-config.nix
│       │   ├── multi-wm.nix
│       │   ├── audio.nix
│       │   └── display-manager.nix
│       └── users/
│           └── home.nix        # Home Manager user config
```

### 2. Flake Structure

**Main Entry Point:** `flake.nix` uses `flake-parts` for modular architecture

**System Configurations:**

- `Lars-MacBook-Air` (aarch64-darwin) → `platforms/darwin/default.nix`
- `evo-x2` (x86_64-linux) → `platforms/nixos/system/configuration.nix`

**Key Observations:**

- Both configurations import `platforms/common/packages/base.nix`
- NixOS uses Home Manager for user-level configuration
- Darwin uses system-level packages and configuration
- Different patterns for managing environment variables across platforms

---

## Duplication Analysis

### Critical Package Duplications

#### 1. Monitoring & System Tools

| Package             | Locations                                | Duplication Severity                              |
| ------------------- | ---------------------------------------- | ------------------------------------------------- |
| `bottom`            | `common/packages/base.nix` (line 57)     | **Base** (correct location)                       |
| `btop`              | `nixos/desktop/monitoring.nix` (line 10) | **Duplicate** - Should be in common               |
| `procs`             | `common/packages/base.nix` (line 58)     | **Base** (correct location)                       |
| `radeontop`         | `nixos/hardware/amd-gpu.nix` (line 36)   | **Hardware-specific** (correct)                   |
| `radeontop`         | `nixos/desktop/monitoring.nix` (line 6)  | **Duplicate** - Should be in monitoring.nix only  |
| `radeontop`         | `nixos/desktop/hyprland.nix` (line 334)  | **Duplicate** - Should be in monitoring.nix only  |
| `amdgpu_top`        | `nixos/hardware/amd-gpu.nix` (line 36)   | **Hardware-specific** (correct)                   |
| `amdgpu_top`        | `nixos/desktop/monitoring.nix` (line 7)  | **Duplicate** - Should be in hardware/amd-gpu.nix |
| `amdgpu_top`        | `nixos/desktop/hyprland.nix` (line 335)  | **Duplicate** - Should be in hardware/amd-gpu.nix |
| `nvtopPackages.amd` | `nixos/desktop/monitoring.nix` (line 5)  | **Hardware-specific** (correct)                   |

**Recommendation:** Consolidate GPU monitoring tools to `hardware/amd-gpu.nix`, keep generic monitors (`bottom`, `btop`, `procs`) in `common/packages/base.nix`, and remove from Hyprland-specific config (accessed system-wide anyway).

---

#### 2. Wallpaper Management

| Package       | Locations                               | Duplication Severity                 |
| ------------- | --------------------------------------- | ------------------------------------ |
| `imagemagick` | `common/packages/base.nix` (line 98)    | **Cross-platform** (correct)         |
| `imagemagick` | `nixos/desktop/hyprland.nix` (line 331) | **Duplicate** - Remove from Hyprland |
| `hyprpaper`   | `nixos/desktop/hyprland.nix` (line 313) | **Hyprland-specific** (correct)      |
| `swww`        | `common/packages/base.nix` (line 101)   | **Linux-only** (correct)             |
| `swww`        | `nixos/desktop/hyprland.nix` (line 330) | **Duplicate** - Remove from Hyprland |

**Recommendation:** `swww` and `imagemagick` should be in common/packages (with platform guards), remove from Hyprland. `hyprpaper` stays in Hyprland module.

---

#### 3. Window Management & Desktop Tools

| Package  | Locations                               | Duplication Severity                           |
| -------- | --------------------------------------- | ---------------------------------------------- |
| `waybar` | `common/packages/base.nix`              | Not found (should be added for cross-platform) |
| `waybar` | `nixos/desktop/multi-wm.nix` (line 13)  | **Multi-WM specific** (correct)                |
| `waybar` | `nixos/desktop/hyprland.nix` (line 321) | **Duplicate** - Remove from Hyprland           |
| `rofi`   | `nixos/users/home.nix` (line 27)        | **User-level** (correct)                       |
| `rofi`   | `nixos/desktop/hyprland.nix` (line 310) | **Duplicate** - Remove from Hyprland           |
| `wofi`   | `nixos/desktop/multi-wm.nix` (line 14)  | **Multi-WM specific** (correct)                |
| `dunst`  | `nixos/desktop/hyprland.nix` (line 322) | **Hyprland-specific** (correct)                |
| `mako`   | `nixos/desktop/multi-wm.nix` (line 67)  | **Multi-WM specific** (correct)                |

**Recommendation:** Create dedicated `common/packages/desktop/launchers.nix` and `common/packages/desktop/notifications.nix` modules for better organization.

---

#### 4. Clipboard Management

| Package        | Locations                               | Duplication Severity                 |
| -------------- | --------------------------------------- | ------------------------------------ |
| `cliphist`     | `common/packages/base.nix` (line 77)    | **Cross-platform** (correct)         |
| `cliphist`     | `nixos/desktop/hyprland.nix` (line 327) | **Duplicate** - Remove from Hyprland |
| `wl-clipboard` | `nixos/desktop/multi-wm.nix` (line 83)  | **Multi-WM specific** (correct)      |

**Recommendation:** Keep `cliphist` in base (Wayland clipboard manager accessible from any WM), `wl-clipboard` stays in multi-wm (system-level dependency for all WMs).

---

#### 5. Audio Control

| Package       | Locations                              | Duplication Severity                      |
| ------------- | -------------------------------------- | ----------------------------------------- |
| `pavucontrol` | `nixos/users/home.nix` (line 26)       | **User-level** (correct for Home Manager) |
| `pavucontrol` | `nixos/desktop/multi-wm.nix` (line 76) | **System-level** (correct for multi-WM)   |

**Note:** This is intentional duplication - user-level access for personal use, system-level for all users. This is acceptable pattern.

---

#### 6. Terminal Emulators

| Package              | Locations                                  | Duplication Severity           |
| -------------------- | ------------------------------------------ | ------------------------------ |
| `alacritty-graphics` | `common/packages/base.nix` (line 25)       | **Cross-platform** (correct)   |
| `kitty`              | `nixos/desktop/hyprland.nix` (line 307)    | **Hyprland-default** (correct) |
| `ghostty`            | `nixos/desktop/hyprland.nix` (line 308)    | **Hyprland-modern** (correct)  |
| `foot`               | `nixos/desktop/multi-wm.nix` (line 12, 52) | **Multi-WM** (correct)         |

**Recommendation:** Consider creating `common/packages/terminals/` for better organization, but current separation by WM is logical.

---

#### 7. Screenshot Tools

| Package     | Locations                               | Duplication Severity            |
| ----------- | --------------------------------------- | ------------------------------- |
| `grim`      | `nixos/desktop/multi-wm.nix` (line 79)  | **Multi-WM** (correct)          |
| `slurp`     | `nixos/desktop/multi-wm.nix` (line 80)  | **Multi-WM** (correct)          |
| `grimblast` | `nixos/desktop/hyprland.nix` (line 343) | **Hyprland-specific** (correct) |

**Recommendation:** `grim` and `slurp` should be in `common/packages/desktop/screenshots.nix` (available to all WMs), `grimblast` stays in Hyprland (convenience wrapper).

---

### Configuration Duplications

#### 1. Nix Settings

**Common Nix Settings:** `platforms/common/core/nix-settings.nix`

- Experimental features: `nix-command flakes`
- Binary caches: `cache.nixos.org`, `nix-community.cachix.org`
- Garbage collection, optimization settings
- nixpkgs config with unfree predicates

**Darwin-specific:** `platforms/darwin/nix/settings.nix`

- Imports common settings ✓
- Adds: `sandbox = true`, `extra-sandbox-paths` (Darwin-specific)

**NixOS-specific:** `platforms/nixos/system/configuration.nix`

- Experimental features: `nix-command flakes` **DUPLICATE** (should import common)
- Binary caches: `cache.nixos.org`, `hyprland.cachix.org` **MIXED** (hyprland cache should be common or desktop-specific)
- Allows unfree: Yes **INCONSISTENT** (should use common predicates)

**Issue:** NixOS has inline Nix settings instead of importing `common/core/nix-settings.nix`

**Recommendation:** Import common Nix settings in NixOS configuration, add Hyprland cache to desktop-specific module.

---

#### 2. Fish Shell Configuration

**Common Pattern:** `platforms/common/programs/fish.nix`

- Defines `commonAliases` and `commonInit`
- Provides `platformAliases` and `platformInit` for override
- Modern pattern using `interactiveShellInit`

**Darwin Implementation:** `platforms/darwin/programs/shells.nix`

- **Duplicate:** Defines aliases inline (`l`, `t`, `nixup`, etc.) instead of using common pattern
- **Duplicate:** Defines `shellInit` with greeting, history settings, carapace, starship
- **Platform-specific:** Homebrew integration (correct location)

**NixOS Implementation:** `platforms/nixos/users/home.nix`

- Defines platform-specific aliases (`nixup`, `nixbuild`, `nixcheck`)
- No common aliases used (missing import)

**Issue:** Both Darwin and NixOS have duplicated Fish config instead of using common base

**Recommendation:** Refactor Darwin to use common Fish config with platform init for Homebrew. NixOS already uses Home Manager (correct pattern), but should import common Fish pattern for consistency.

---

#### 3. Environment Variables

**Common Variables:** `platforms/common/environment/variables.nix`

- `EDITOR`, `LANG`, `NIX_PATH`, locale settings
- Development variables: `NODE_OPTIONS`, `NPM_CONFIG_*`
- Build variables: `NIXPKGS_ALLOW_*`

**Darwin-specific:** `platforms/darwin/environment.nix`

- Imports common ✓
- Adds: `BROWSER = "google-chrome"`, `TERMINAL = "iTerm2"`

**NixOS-specific:** `platforms/nixos/users/home.nix`

- Defines: `MOZ_ENABLE_WAYLAND`, `QT_QPA_PLATFORM`, `NIXOS_OZONE_WL`
- No common variables import (Home Manager should handle this)

**Hardware-specific:** `platforms/nixos/hardware/amd-gpu.nix`

- Adds GPU-related variables: `__GLX_VENDOR_LIBRARY_NAME`, `LIBVA_DRIVER_NAME`, etc.
- **Issue:** These are `environment.sessionVariables` (system-level), not `environment.variables`

**AI Stack:** `platforms/nixos/desktop/ai-stack.nix`

- Adds AI-related variables: `HIP_VISIBLE_DEVICES`, `ROCM_PATH`, `HSA_OVERRIDE_GFX_VERSION`, `PYTORCH_ROCM_ARCH`
- **Issue:** These are `environment.variables` (system-level), should be in Home Manager for user services

**Recommendation:**

- Consolidate GPU variables to hardware module (correct location)
- Move AI variables to Home Manager user config (user services run as user)
- Ensure proper variable scope (system vs user level)

---

#### 4. Fonts Configuration

**NixOS System:** `platforms/nixos/system/configuration.nix`

- Installs: `jetbrains-mono`
- Configures: fontconfig default fonts (mono, sans-serif, serif)
- **Issue:** Font config should be in desktop module, not system config

**Darwin:** No font configuration found (should be added)

**Recommendation:** Move fonts to `platforms/common/packages/fonts.nix` with platform guards, import from both systems.

---

### Module Organization Issues

#### 1. Desktop Module Structure

**Current State:**

```
platforms/nixos/desktop/
├── ai-stack.nix            # AI tools and Ollama service
├── monitoring.nix          # System monitoring tools
├── security-hardening.nix  # Security tools and AppArmor
├── hyprland.nix          # Hyprland user config (Home Manager)
├── hyprland-system.nix    # Hyprland system config (NixOS)
├── hyprland-config.nix    # Hyprland xdg-portal and Qt Wayland
├── multi-wm.nix          # Sway, Niri, LabWC, Awesome
├── audio.nix             # Audio configuration
├── display-manager.nix    # SDDM display manager
└── default.nix           # Placeholder (empty)
```

**Issues:**

1. `hyprland.nix` contains duplicate packages (radeontop, amdgpu_top, imagemagick, swww, rofi, waybar, cliphist)
2. `hyprland-config.nix` has empty placeholder for xserver (line 6-12)
3. `default.nix` is empty placeholder
4. Audio and display manager configs not reviewed (potential additional duplications)
5. Mixed concerns: User-level (Home Manager) and system-level configs in same directory

**Recommendation:**

- Split into `user/` (Home Manager configs) and `system/` (NixOS configs) subdirectories
- Remove duplicate packages from Hyprland
- Remove empty placeholder files

---

#### 2. Hardware Module Structure

**Current State:**

```
platforms/nixos/hardware/
├── hardware-configuration.nix   # Auto-generated hardware scan
└── amd-gpu.nix               # AMD GPU support
```

**Issues:**

1. `amd-gpu.nix` includes `amdgpu_top` and `corectrl` (system packages)
2. These packages are duplicated in `monitoring.nix` and `hyprland.nix`

**Recommendation:** Keep GPU packages in `amd-gpu.nix` only, remove from other modules.

---

#### 3. Common Package Organization

**Current State:**

```
platforms/common/packages/
├── base.nix           # Essential CLI, development, GUI, AI packages
├── helium.nix         # Helium browser wrapper
└── tuios.nix         # TUI applications
```

**Issues:**

1. `base.nix` is monolithic (119 lines) - mixing concerns
2. Categories: `essentialPackages`, `developmentPackages`, `guiPackages`, `aiPackages`
3. No clear separation between platform-agnostic and platform-specific packages
4. `guiPackages` contains Helium (imported from separate file) and Chrome (macOS-only)

**Recommendation:** Split into focused modules:

```
platforms/common/packages/
├── essential/         # Core CLI tools (git, fish, curl, etc.)
├── development/       # Development tools (Go, Node.js, etc.)
├── desktop/
│   ├── launchers.nix  # rofi, wofi
│   ├── notifications.nix # dunst, mako
│   ├── screenshots.nix # grim, slurp, grimblast
│   └── wallpapers.nix  # swww, hyprpaper
├── monitoring/
│   ├── system.nix      # bottom, btop, procs
│   └── gpu.nix        # nvtop, radeontop, amdgpu_top
├── terminals.nix     # alacritty, kitty, ghostty, foot
├── fonts.nix        # JetBrains Mono, etc.
├── ai.nix          # AI/ML tools
└── base.nix        # Import all above
```

---

## Improved Package Layout Proposal

### Hierarchical Package Structure

```
platforms/
├── common/
│   ├── packages/
│   │   ├── base/
│   │   │   ├── cli.nix              # Core CLI tools (git, curl, wget, tree, ripgrep, fd, eza, bat, jq, yq-go, sd, dust)
│   │   │   ├── shells.nix           # Fish, starship, carapace
│   │   │   ├── editors.nix         # Vim, micro-full
│   │   │   ├── file-tools.nix       # coreutils, findutils, gnused
│   │   │   └── task-management.nix # taskwarrior3, timewarrior, just
│   │   ├── development/
│   │   │   ├── go.nix             # Go, gopls, golangci-lint
│   │   │   ├── javascript.nix      # bun (JavaScript runtime)
│   │   │   ├── infrastructure.nix  # terraform, nh
│   │   │   └── security.nix        # gitleaks, pre-commit, openssh
│   │   ├── desktop/
│   │   │   ├── browsers/
│   │   │   │   ├── helium.nix       # Helium browser (cross-platform)
│   │   │   │   └── firefox-chrome.nix # Firefox (Linux), Chrome (Darwin)
│   │   │   ├── launchers/
│   │   │   │   ├── rofi.nix        # Wayland launcher
│   │   │   │   └── wofi.nix        # GTK launcher
│   │   │   ├── notifications/
│   │   │   │   ├── dunst.nix       # dmenu-based notifications
│   │   │   │   └── mako.nix        # GTK notifications
│   │   │   ├── screenshots/
│   │   │   │   ├── grim-slurp.nix  # Base screenshot tools
│   │   │   │   └── grimblast.nix   # Enhanced screenshot tool
│   │   │   ├── wallpapers/
│   │   │   │   ├── swww.nix        # Animated wallpapers (Linux)
│   │   │   │   ├── hyprpaper.nix   # Hyprland wallpaper
│   │   │   │   └── imagemagick.nix # Image manipulation
│   │   │   ├── terminals/
│   │   │   │   ├── alacritty.nix   # GPU-accelerated terminal
│   │   │   │   ├── kitty.nix       # Fast GPU terminal
│   │   │   │   ├── ghostty.nix     # Modern terminal
│   │   │   │   └── foot.nix        # Wayland terminal
│   │   │   └── tools/
│   │   │       ├── pavucontrol.nix # Audio control
│   │   │       ├── cliphist.nix     # Clipboard history
│   │   │       ├── wl-clipboard.nix # Wayland clipboard
│   │   │       └── dolphin.nix     # File manager
│   │   ├── monitoring/
│   │   │   ├── system.nix          # bottom, procs, btop
│   │   │   ├── gpu/
│   │   │   │   ├── amd.nix        # nvtopPackages.amd, radeontop, amdgpu_top
│   │   │   │   └── nvidia.nix      # (placeholder for future NVIDIA support)
│   │   │   ├── network.nix        # nethogs, iftop
│   │   │   └── performance.nix     # strace, ltrace, perf
│   │   ├── graphics/
│   │   │   ├── fonts.nix          # JetBrains Mono, Nerd Fonts
│   │   │   └── tools.nix          # graphviz
│   │   ├── ai/
│   │   │   ├── core.nix           # Python3, Jupyter
│   │   │   ├── inference.nix        # ollama, llama-cpp, vllm
│   │   │   └── ocr.nix            # tesseract4, poppler-utils
│   │   ├── security/
│   │   │   ├── authentication.nix # gnupg, pass, openssl
│   │   │   ├── network.nix         # wireshark, nmap, aircrack-ng
│   │   │   ├── system.nix          # aide, osquery, clamav
│   │   │   ├── vpn.nix            # openvpn, wireguard-tools, tor-browser
│   │   │   └── penetration.nix     # sqlmap, nikto, nuclei, masscan
│   │   └── base.nix               # Import all categories with platform guards
│   │
│   ├── environment/
│   │   ├── variables.nix          # Common environment variables
│   │   └── paths.nix              # Common PATH additions
│   │
│   ├── programs/
│   │   ├── fish.nix               # Fish shell config (common base)
│   │   ├── starship.nix           # Starship prompt config
│   │   ├── tmux.nix              # Tmux configuration
│   │   └── activitywatch.nix      # ActivityWatch service
│   │
│   ├── core/
│   │   ├── nix-settings.nix       # Common Nix configuration
│   │   ├── TypeSafetySystem.nix    # Type safety framework
│   │   └── State.nix             # State management
│   │
│   └── home-base.nix             # Home Manager base config
│
├── darwin/
│   ├── packages/
│   │   ├── gui.nix              # macOS-specific GUI apps (iTerm2, Sublime Text)
│   │   └── base-override.nix    # Platform-specific package overrides
│   │
│   ├── programs/
│   │   └── fish/
│   │       └── platform-init.nix  # Homebrew integration, etc.
│   │
│   ├── environment/
│   │   ├── variables.nix         # Darwin-specific variables (BROWSER, TERMINAL)
│   │   └── paths.nix            # Darwin-specific paths
│   │
│   ├── system/
│   │   ├── defaults.nix          # macOS system defaults
│   │   ├── activation.nix        # Activation scripts
│   │   └── services.nix         # Touch ID, PAM
│   │
│   ├── nix/
│   │   └── settings.nix         # Darwin-specific Nix settings (sandbox)
│   │
│   └── default.nix               # Main Darwin config
│
└── nixos/
    ├── users/
    │   └── home.nix             # Home Manager user config
    │
    ├── system/
    │   ├── configuration.nix     # Main system config (imports common)
    │   ├── boot.nix             # Bootloader config
    │   ├── networking.nix        # Network configuration
    │   └── services.nix         # System services (SSH, fail2ban, etc.)
    │
    ├── hardware/
    │   ├── hardware-configuration.nix  # Auto-generated
    │   ├── gpu/
    │   │   ├── amd.nix          # AMD GPU support
    │   │   └── drivers.nix       # Vulkan, OpenCL, video acceleration
    │   └── cpu/
    │       └── amd.nix          # AMD CPU optimization
    │
    ├── desktop/
    │   ├── system/               # NixOS desktop configs
    │   │   ├── hyprland.nix     # Hyprland system config
    │   │   ├── multi-wm.nix     # Multi-WM system config
    │   │   ├── audio.nix        # PipeWire/PulseAudio
    │   │   ├── display-manager.nix # SDDM config
    │   │   └── fonts.nix        # System font config
    │   │
    │   └── user/                # Home Manager desktop configs
    │       ├── hyprland.nix     # Hyprland user config
    │       ├── multi-wm.nix     # Multi-WM user config
    │       ├── ai-stack.nix     # AI services (user-level)
    │       └── monitoring.nix    # Monitoring tools (user-level)
    │
    └── services/
        ├── ssh.nix               # SSH service
        └── security.nix         # Security services (fail2ban, clamav)
```

### Key Principles

1. **Single Source of Truth:** Each package defined in exactly one location
2. **Clear Separation:** Platform-agnostic vs platform-specific, system vs user-level
3. **Logical Grouping:** Related packages in focused, single-purpose modules
4. **Hierarchical Imports:** Base modules import focused modules, platforms import base
5. **Platform Guards:** Use `lib.optionals stdenv.isDarwin` and `lib.optionals stdenv.isLinux` appropriately

---

## De-duplication Plan

### Phase 1: Critical Duplications (High Priority)

#### 1.1 GPU Monitoring Tools

**Files:** `nixos/desktop/hyprland.nix`, `nixos/desktop/monitoring.nix`, `nixos/hardware/amd-gpu.nix`

**Action:**

1. Keep `amdgpu_top`, `radeontop` in `hardware/amd-gpu.nix` only
2. Remove duplicate entries from `monitoring.nix` and `hyprland.nix`
3. Keep `nvtopPackages.amd` in `hardware/amd-gpu.nix`
4. Keep generic monitors (`bottom`, `procs`) in `common/packages/base.nix`
5. Add `btop` to `common/packages/base.nix` (currently only in monitoring.nix)

**Expected Outcome:** 3 packages removed from duplication

---

#### 1.2 Wallpaper Tools

**Files:** `nixos/desktop/hyprland.nix`, `common/packages/base.nix`

**Action:**

1. Keep `imagemagick` in `common/packages/base.nix` with platform guard: `lib.optionals stdenv.isLinux [imagemagick]`
2. Keep `swww` in `common/packages/base.nix` with platform guard: `lib.optionals stdenv.isLinux [swww]`
3. Remove duplicate entries from `hyprland.nix`
4. Keep `hyprpaper` in `hyprland.nix` (Hyprland-specific)

**Expected Outcome:** 2 packages removed from duplication

---

#### 1.3 Desktop Tools (launchers, notifications, screenshots)

**Files:** `nixos/desktop/hyprland.nix`, `nixos/desktop/multi-wm.nix`, `nixos/users/home.nix`

**Action:**

1. Create `common/packages/desktop/launchers.nix` with `rofi` and `wofi`
2. Create `common/packages/desktop/notifications.nix` with `dunst` and `mako`
3. Create `common/packages/desktop/screenshots.nix` with `grim`, `slurp`, `grimblast`
4. Import these in `multi-wm.nix` (system-level)
5. Import these in `home.nix` (user-level for `rofi`)
6. Remove duplicate entries from `hyprland.nix`

**Expected Outcome:** 4 packages consolidated, improved organization

---

#### 1.4 Clipboard Management

**Files:** `common/packages/base.nix`, `nixos/desktop/hyprland.nix`, `nixos/desktop/multi-wm.nix`

**Action:**

1. Keep `cliphist` in `common/packages/base.nix` (Wayland clipboard history)
2. Remove from `hyprland.nix` (accessible system-wide)
3. Keep `wl-clipboard` in `multi-wm.nix` (system-level dependency)

**Expected Outcome:** 1 package removed from duplication

---

### Phase 2: Configuration Duplications (Medium Priority)

#### 2.1 Nix Settings

**Files:** `nixos/system/configuration.nix`, `common/core/nix-settings.nix`

**Action:**

1. Import `common/core/nix-settings.nix` in `nixos/system/configuration.nix`
2. Remove duplicate `nix.settings.experimental-features` (now imported)
3. Move `hyprland.cachix.org` to desktop module or add to common with comment
4. Ensure `nixpkgs.config.allowUnfree` uses common predicates

**Expected Outcome:** Consistent Nix configuration across platforms

---

#### 2.2 Fish Shell Configuration

**Files:** `darwin/programs/shells.nix`, `common/programs/fish.nix`

**Action:**

1. Refactor `darwin/programs/shells.nix` to use common Fish pattern:
   ```nix
   {
     imports = [../../common/programs/fish.nix];
     programs.fish.shellInit = lib.mkAfter ''
       # Homebrew integration
       if test -f /opt/homebrew/bin/brew
           eval (/opt/homebrew/bin/brew shellenv)
       end
     '';
   }
   ```
2. Remove duplicate aliases and initialization from `darwin/programs/shells.nix`
3. Update `common/programs/fish.nix` to use `interactiveShellInit` (already correct)

**Expected Outcome:** Consistent Fish configuration, reduced duplication

---

#### 2.3 Environment Variables

**Files:** Multiple files across platforms

**Action:**

1. Ensure `darwin/environment.nix` imports `common/environment/variables.nix` (already done ✓)
2. Move AI variables from `ai-stack.nix` to Home Manager user config (`nixos/users/home.nix`)
3. Keep GPU variables in `hardware/amd-gpu.nix` (already system-level, correct)
4. Ensure NixOS Home Manager imports common variables (check `home-base.nix`)

**Expected Outcome:** Proper variable scope (system vs user-level)

---

#### 2.4 Fonts Configuration

**Files:** `nixos/system/configuration.nix`

**Action:**

1. Create `common/packages/graphics/fonts.nix` with:
   ```nix
   {pkgs, ...}: {
     fonts.packages = with pkgs; [jetbrains-mono];
     fonts.fontconfig.defaultFonts = {
       monospace = ["JetBrains Mono"];
       sansSerif = ["DejaVu Sans"];
       serif = ["DejaVu Serif"];
     };
   }
   ```
2. Remove font config from `nixos/system/configuration.nix`
3. Import fonts in both Darwin and NixOS

**Expected Outcome:** Cross-platform font configuration

---

### Phase 3: Package Organization Refactoring (Low Priority)

#### 3.1 Split Common Packages

**Files:** `common/packages/base.nix`

**Action:**

1. Create focused modules in `common/packages/`:
   - `essential/` directory with CLI tools
   - `development/` directory with dev tools
   - `desktop/` directory with GUI apps
   - `monitoring/` directory with system monitors
   - `graphics/` directory with fonts and tools
   - `ai/` directory with AI/ML tools
2. Refactor `base.nix` to import all focused modules
3. Add platform guards where appropriate

**Expected Outcome:** Clear separation of concerns, easier maintenance

---

#### 3.2 Reorganize Desktop Modules

**Files:** `nixos/desktop/` directory

**Action:**

1. Split into `system/` and `user/` subdirectories
2. Move system configs:
   - `hyprland-system.nix` → `system/hyprland.nix`
   - `hyprland-config.nix` → `system/hyprland-portal.nix`
   - `multi-wm.nix` → `system/multi-wm.nix`
   - `audio.nix` → `system/audio.nix`
   - `display-manager.nix` → `system/display-manager.nix`
3. Move user configs:
   - `hyprland.nix` → `user/hyprland.nix`
   - `ai-stack.nix` → `user/ai-stack.nix`
   - `monitoring.nix` → `user/monitoring.nix`
4. Update imports in `nixos/system/configuration.nix` and `nixos/users/home.nix`

**Expected Outcome:** Clear separation of system vs user-level configs

---

#### 3.3 Remove Placeholder Files

**Files:** `nixos/desktop/default.nix`, `nixos/desktop/hyprland-config.nix` (partial)

**Action:**

1. Delete `nixos/desktop/default.nix` (empty placeholder)
2. Remove empty xserver configuration from `hyprland-config.nix` (lines 6-12)
3. Clean up any other placeholder comments

**Expected Outcome:** Cleaner codebase

---

### Phase 4: Documentation & Validation (Medium Priority)

#### 4.1 Update Documentation

**Files:** `AGENTS.md`, `docs/status/`

**Action:**

1. Update `AGENTS.md` with new package structure
2. Document de-duplication patterns and best practices
3. Create status report for completed de-duplication work

**Expected Outcome:** Clear documentation for future maintenance

---

#### 4.2 Validate Configuration

**Action:**

1. Run `just test` to verify Darwin configuration
2. Run `just format` to ensure consistent formatting
3. Run `just health` for comprehensive system check
4. Test on both platforms (if possible)

**Expected Outcome:** Verified, working configuration

---

## Implementation Priority

### Immediate (Week 1)

1. GPU monitoring tools de-duplication (1.1)
2. Wallpaper tools de-duplication (1.2)
3. Clipboard management de-duplication (1.4)

### Short-term (Week 2)

4. Desktop tools organization (1.3)
5. Nix settings de-duplication (2.1)
6. Fish shell refactoring (2.2)

### Medium-term (Week 3-4)

7. Environment variables cleanup (2.3)
8. Fonts configuration (2.4)
9. Desktop module reorganization (3.2)
10. Placeholder file removal (3.3)

### Long-term (Month 2+)

11. Common packages split (3.1)
12. Documentation updates (4.1)
13. Comprehensive validation (4.2)

---

## Risk Assessment

### Low Risk

- Package de-duplications (Phase 1)
- Placeholder file removal (3.3)
- Documentation updates (4.1)

### Medium Risk

- Nix settings refactoring (2.1) - Requires testing on both platforms
- Fish shell refactoring (2.2) - Shell startup critical for productivity
- Desktop module reorganization (3.2) - Affects import paths

### High Risk

- Common packages split (3.1) - Major refactoring, extensive testing required
- Environment variables cleanup (2.3) - AI services may break

**Mitigation:** Test incrementally, commit frequently, keep rollback capability (`just rollback`)

---

## Success Criteria

### De-duplication Metrics

- [ ] 15+ duplicated packages eliminated
- [ ] 0 duplicate package definitions
- [ ] Clear single source of truth for all packages
- [ ] All package duplications resolved

### Organization Metrics

- [ ] Package modules <50 lines (focused, single-purpose)
- [ ] Clear hierarchical structure
- [ ] Platform guards used appropriately
- [ ] System vs user-level configs separated

### Quality Metrics

- [ ] `just test` passes on both platforms
- [ ] `just format` shows no changes
- [ ] `just health` shows no issues
- [ ] All builds complete successfully

### Maintainability Metrics

- [ ] New packages easily added to correct location
- [ ] Clear pattern for platform-specific packages
- [ ] Documentation up-to-date
- [ ] No TODO comments related to duplication

---

## Next Steps

1. **Review and Approval**: Review this analysis and approve the de-duplication plan
2. **Create Implementation Branch**: Create feature branch for systematic de-duplication
3. **Execute Phase 1**: Implement high-priority de-duplications
4. **Test and Validate**: Run comprehensive tests after each phase
5. **Document Progress**: Update status reports after each phase
6. **Iterate**: Continue through all phases until complete

---

## Conclusion

This analysis reveals significant opportunities to reduce duplication and improve the organizational structure of the Setup-Mac configuration. The proposed de-duplication plan provides a systematic, phased approach to:

1. Eliminate 15+ duplicated packages across the codebase
2. Establish clear separation of concerns between platform-agnostic and platform-specific configurations
3. Improve maintainability through hierarchical, focused modules
4. Ensure consistency across macOS and NixOS platforms

The improved package layout provides a solid foundation for future growth while maintaining the flexibility to support both platforms effectively.

**Estimated Effort:** 2-4 weeks for complete implementation
**Estimated Impact:** 30-50% reduction in duplication, significantly improved maintainability

---

_Analysis completed: 2025-12-26 07:59 CET_
_Prepared by: Crush AI Assistant_
_Status: Ready for implementation_
