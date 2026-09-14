# Nix Configuration File Dependency Graph

## Entry Point

```
flake.nix (ROOT)
│
├── Description: Main flake entry point that defines system configuration
├── Imports: All system modules
└── Output: darwinConfigurations."Lars-MacBook-Air"
```

## Module Loading Order (flake.nix lines 82-148)

### 1. Base Configuration

```
base (system config revision)
│
└── Provides: system.configurationRevision = self.rev or self.dirtyRev or null
```

### 2. Custom Packages Overlay

```
heliumOverlay
│
├── ./dotfiles/nix/packages/helium.nix
│   └── Provides: helium package definition
└── Applied via: nixpkgs.overlays = [ heliumOverlay ]
```

### 3. Core System Modules

```
./dotfiles/nix/core.nix
│
├── Validates: macOS compatibility
├── Configures:
│   ├── security.pam.services (Touch ID sudo)
│   ├── security.pki (certificate authorities)
│   ├── time.timezone (null = auto)
│   ├── nix.settings (flakes, caches, sandboxing)
│   ├── nix.gc (automatic cleanup)
│   ├── nix.optimise (store optimization)
│   └── nixpkgs.config (unfree packages, platform)
└── Dependencies: lib (from nixpkgs)
```

### 4. System Preferences

```
./dotfiles/nix/system.nix
│
├── Configures:
│   ├── system.defaults (macOS system preferences)
│   ├── launchd.daemons (background services)
│   ├── services (system services)
│   └── system.keyboard (keyboard settings)
└── Dependencies: pkgs, lib
```

### 5. Environment & Packages

```
./dotfiles/nix/environment.nix
│
├── Imports:
│   ├── ./core/UserConfig.nix (user configuration)
│   └── ./core/PathConfig.nix (path utilities)
├── Configures:
│   ├── environment.shells (fish, zsh, bash)
│   ├── environment.variables (EDITOR, LANG, etc.)
│   └── environment.systemPackages (Nix packages list)
└── Dependencies: nix-ai-tools, lib, inputs
```

### 6. Programs Configuration

```
./dotfiles/nix/programs.nix
│
├── Configures:
│   ├── programs.fish (shell setup, aliases, initialization)
│   ├── programs.zsh (fallback shell)
│   └── programs.bash (compatibility)
├── Dependencies: pkgs, lib
└── Key Feature: Fish shell integration with Homebrew
```

### 7. Application Integration

```
./dotfiles/nix/activitywatch.nix
│
├── Imports: ./activitywatch-home.nix (home directory integration)
└── Configures: launchd.agent for ActivityWatch auto-start
```

### 8. Community Packages

```
./dotfiles/nix/nur.nix
│
└── Configures: NUR (Nix User Repository) integration
```

### 9. Homebrew Integration

```
./dotfiles/nix/homebrew.nix + nix-homebrew module
│
├── Configures:
│   ├── homebrew.enable
│   ├── homebrew.taps (additional repositories)
│   ├── homebrew.brews (CLI tools like gh, mas)
│   ├── homebrew.casks (GUI applications)
│   └── homebrew.masApps (Mac App Store apps)
└── nix-homebrew.darwinModules.nix-homebrew provides:
    ├── enableRosetta (Intel prefix support)
    └── user ownership
```

### 10. Network Configuration

```
./dotfiles/nix/networking.nix
│
└── Configures: networking settings
```

### 11. User Management

```
./dotfiles/nix/users.nix
│
├── Configures: users.users.larsartmann
└── Imports: UserConfig.nix for user data
```

### 12. macOS Integration

```
mac-app-util.darwinModules.default
│
└── Provides: Spotlight integration for Nix-installed apps
```

## Core Support Files

### User Configuration

```
./core/UserConfig.nix
│
├── Provides: defaultUser { username, home, shell, ... }
└── Used by: environment.nix, users.nix
```

### Path Configuration

```
./core/PathConfig.nix
│
├── Provides: mkPathConfig function
├── Returns: { home, goPath, ... }
└── Used by: environment.nix
```

### Validation Framework

```
./core/Validation.nix
./core/ConfigAssertions.nix
./core/SystemAssertions.nix
./core/TypeAssertions.nix
./core/ModuleAssertions.nix
│
└── Provide: Configuration validation functions
```

### Wrappers System

```
./wrappers/default.nix
├── ./wrappers/applications/ (GUI app wrappers)
│   ├── sublime-text.nix
│   ├── bat.nix
│   ├── kitty.nix
│   └── activitywatch.nix
├── ./wrappers/shell/ (shell tool wrappers)
│   ├── starship.nix
│   └── fish.nix
└── Dependencies: lassulus/wrappers input
```

## Module Dependency Flow

```
flake.nix
    │
    ├── core.nix (base system)
    ├── system.nix (macOS preferences)
    ├── environment.nix (packages + env vars)
    │   ├── imports core/UserConfig.nix
    │   └── imports core/PathConfig.nix
    ├── programs.nix (shell configuration)
    ├── homebrew.nix (package management)
    │   └── enhanced by nix-homebrew module
    ├── activitywatch.nix (application auto-start)
    │   └── imports activitywatch-home.nix
    ├── nur.nix (community packages)
    ├── networking.nix (network settings)
    ├── users.nix (user configuration)
    │   └── imports core/UserConfig.nix
    └── mac-app-util (app integration)
```

## Key External Inputs

```
Inputs from flake.nix:
├── nixpkgs (package repository)
├── nix-darwin (macOS system management)
├── home-manager (user configuration - currently disabled)
├── nix-homebrew (declarative Homebrew)
├── nix-ai-tools (crush AI assistant)
├── mac-app-util (Spotlight integration)
├── nur (community packages)
├── treefmt-nix (code formatting)
├── wrappers (software wrapping system)
└── Additional repositories (helium, nh, etc.)
```

## Current Issue: Homebrew PATH Integration

The GitHub CLI (`gh`) issue stems from:

1. **Homebrew Integration**: nix-homebrew adds `brew shellenv` to `/etc/zshrc`
2. **Fish Shell**: Uses separate configuration in programs.nix
3. **Missing Bridge**: Fish doesn't automatically inherit zsh environment
4. **Solution Applied**: Added `eval (/opt/homebrew/bin/brew shellenv)` to Fish shellInit

## Configuration Validation

The system includes comprehensive validation:

- Module assertions in core.nix
- Configuration validation in environment.nix
- Path validation in PathConfig.nix
- Type validation in TypeAssertions.nix

This ensures system reliability before deployment.
