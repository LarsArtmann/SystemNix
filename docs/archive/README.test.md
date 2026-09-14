# SystemNix

A comprehensive cross-platform development environment using Nix, supporting both macOS (nix-darwin) and NixOS with declarative configuration management.

## Overview

This repository provides a complete, reproducible development environment for macOS and Linux with:

- **Cross-Platform Nix**: Unified configurations for macOS (nix-darwin) and NixOS
- **Home Manager**: User-specific configurations and dotfiles
- **Go Development Stack**: Complete Go toolchain with templ, sqlc, and modern tools
- **Cloud & Kubernetes Tools**: AWS, GCP, kubectl, Helm, Terraform, and more
- **Homebrew Integration**: Managed through nix-homebrew for GUI applications (macOS)
- **Security Tools**: Gitleaks, Little Snitch, Lulu, age encryption
- **Performance Tools**: Hyperfine, htop, ncdu, and comprehensive monitoring
- **Niri Window Manager**: Wayland tiling compositor

## Home Manager Integration

### Architecture Overview

This configuration uses **Home Manager** for unified cross-platform user configuration with:

- **Shared Modules**: ~80% code reduction through `platforms/common/`
- **Platform-Specific**: Minimal overrides for Darwin (macOS) and NixOS (Linux)
- **Type Safety**: Enforced via Home Manager validation
- **Cross-Platform Consistency**: Identical configuration on both platforms

### Module Structure

```
platforms/
├── common/                    # Shared across platforms
│   ├── home-base.nix         # Shared Home Manager base config
│   ├── programs/
│   │   ├── fish.nix         # Cross-platform Fish shell config
│   │   ├── starship.nix      # Cross-platform Starship prompt
│   │   ├── tmux.nix          # Cross-platform Tmux config
│   │   └── activitywatch.nix # Platform-conditional (Linux only)
│   ├── packages/
│   │   ├── base.nix          # Cross-platform packages
│   │   └── fonts.nix         # Cross-platform fonts
│   └── core/
│       ├── nix-settings.nix  # Cross-platform Nix settings
│       └── nix-settings.nix  # Cross-platform Nix settings
├── darwin/                    # macOS (nix-darwin) specific
│   ├── default.nix            # Darwin system config
│   └── home.nix              # Darwin Home Manager overrides
└── nixos/                     # Linux (NixOS) specific
    ├── users/
    │   └── home.nix          # NixOS Home Manager overrides
    └── system/
        └── configuration.nix  # NixOS system config
```

### Shared Modules

**Fish Shell** (`platforms/common/programs/fish.nix`):

- Common aliases: `l` (list), `t` (tree)
- Platform-specific alias placeholders
- Fish greeting disabled (performance)
- Fish history settings configured

**Starship Prompt** (`platforms/common/programs/starship.nix`):

- Identical on both platforms
- Fish integration automatic
- Settings: `add_newline = false`, `format = "$all$character"`

**Tmux** (`platforms/common/programs/tmux.nix`):

- Identical on both platforms
- Clock24 enabled, mouse enabled
- Base index: 1, terminal: screen-256color
- History limit: 100000

**ActivityWatch** (`platforms/common/programs/activitywatch.nix`):

- Platform-conditional: `enable = pkgs.stdenv.isLinux`
- Darwin: DISABLED (not supported on macOS)
- NixOS: ENABLED (supported on Linux)

### Platform-Specific Overrides

**Darwin** (`platforms/darwin/home.nix`):

- Fish aliases: `nixup`, `nixbuild`, `nixcheck` (darwin-rebuild)
- Fish init: Homebrew integration, Carapace completions
- No Starship/Tmux overrides (uses shared modules)

**NixOS** (`platforms/nixos/users/home.nix`):

- Fish aliases: `nixup`, `nixbuild`, `nixcheck` (nixos-rebuild)
- Session variables: Wayland, Qt, NixOS_OZONE_WL
- Packages: pavucontrol (audio), xdg utils
- Desktop: Niri (Wayland tiling) window manager

### Configuration Workflow

1. **Edit shared configuration** (affects both platforms):
   - `platforms/common/programs/fish.nix` - Shared aliases and shell settings
   - `platforms/common/programs/starship.nix` - Shared prompt settings
   - `platforms/common/programs/tmux.nix` - Shared terminal settings
   - `platforms/common/packages/base.nix` - Shared packages

2. **Edit platform-specific overrides** (affects single platform):
   - `platforms/darwin/home.nix` - Darwin-specific overrides
   - `platforms/nixos/users/home.nix` - NixOS-specific overrides

3. **Validate configuration**:

   ```bash
   # Fast syntax check (no build)
   just test-fast

   # Full build verification
   just test
   ```

4. **Apply changes**:

   ```bash
   # Darwin (macOS)
   just switch

   # Or manual
   sudo darwin-rebuild switch --flake .

   # NixOS (Linux)
   sudo nixos-rebuild switch --flake .
   ```

5. **Open new terminal** (required for shell changes to take effect)

### Import Paths

**Darwin Home Manager** (`platforms/darwin/home.nix`):

```nix
imports = [
  ../common/home-base.nix  // Resolves to platforms/common/home-base.nix
];
```

**NixOS Home Manager** (`platforms/nixos/users/home.nix`):

```nix
imports = [
  ../../common/home-base.nix  // Resolves to platforms/common/home-base.nix
];
```

**Note**: Different relative paths due to directory structure, both resolve correctly.

### Known Issues

#### Home Manager Users Definition (Darwin)

**Issue**: Home Manager's `nix-darwin/default.nix` imports `../nixos/common.nix` (NixOS-specific file) which requires `config.users.users.<name>.home` to be defined.

**Workaround**: Added explicit user definition in `platforms/darwin/default.nix`:

```nix
users.users.lars = {
  name = "lars";
  home = "/Users/lars";
};
```

**Status**: ✅ WORKAROUND APPLIED - Build succeeds

**Note**: This may be a Home Manager architecture issue. Consider reporting if causes problems in future versions.

#### ActivityWatch Platform Support

**Issue**: ActivityWatch only supports Linux platforms, not Darwin (macOS).

**Workaround**: Made conditional - `enable = pkgs.stdenv.isLinux` in `platforms/common/programs/activitywatch.nix`.

**Status**: ✅ FIXED - Build succeeds on both platforms

### Troubleshooting

#### Starship Prompt Not Appearing

**Problem**: Default Fish prompt instead of Starship
**Solution**:

```bash
# Restart shell
exec fish

# Check Starship config
cat ~/.config/starship.toml

# Verify Starship is installed
which starship
```

#### Fish Aliases Not Working

**Problem**: `nixup` command not found
**Solution**:

```bash
# Reload Fish config
source ~/.config/fish/config.fish

# Check aliases
type nixup
# Should show: darwin-rebuild switch --flake .
```

#### Tmux Not Configured

**Problem**: Default Tmux config instead of custom
**Solution**:

```bash
# Check Tmux config
cat ~/.config/tmux/tmux.conf

# Restart Tmux
tmux kill-server && tmux new-session
```

#### Environment Variables Not Set

**Problem**: `EDITOR` or `LANG` not set
**Solution**:

```bash
# Check environment
echo $EDITOR
echo $LANG

# Restart shell
exec fish
```

### Documentation

For detailed information:

- **[Deployment Guide](./docs/verification/HOME-MANAGER-DEPLOYMENT-GUIDE.md)** - Step-by-step deployment and verification
- **[Verification Template](./docs/verification/HOME-MANAGER-VERIFICATION-TEMPLATE.md)** - Comprehensive checklist
- **[Cross-Platform Report](./docs/verification/CROSS-PLATFORM-CONSISTENCY-REPORT.md)** - Architecture analysis
- **[Build Verification](./docs/status/2025-12-26_23-45_HOME-MANAGER-BUILD-VERIFICATION.md)** - Build results

---

## Quick Start

### Prerequisites

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools: `xcode-select --install`
- Administrative access

### Installation

1. **Install Nix (Determinate Systems installer recommended):**

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Clone and apply configuration:**

   ```bash
   git clone https://github.com/LarsArtmann/SystemNix.git ~/projects/SystemNix
   cd ~/projects/SystemNix

   # Use Just commands (recommended)
   just setup              # Complete initial setup
   just switch             # Apply configuration changes

   # Or manual commands
   darwin-rebuild switch --flake .#Lars-MacBook-Air

   # Note: Do NOT use 'nh darwin switch' - it has issues with temporary files
   # See docs/troubleshooting/nh-darwin-switch-issue.md for details
   ```

3. **Restart your terminal** to load new environment.

### What You Get

After installation, you'll have access to 100+ development tools including:

**Languages & Runtimes:**

- Go (with templ, sqlc, go-tools)
- Node.js, Bun, pnpm
- Java (JDK 21), Kotlin
- .NET Core SDK, Ruby, Rust
- Python utilities (uv)

**Cloud & DevOps:**

- AWS CLI, Google Cloud SDK
- Kubernetes (kubectl, k9s, Helm)
- Terraform, Docker Buildx
- Infrastructure tools

**Development:**

- Git + GitHub CLI + Git Town
- JetBrains Toolbox
- VS Code, Sublime Text
- Database tools (Redis, Turso)

See the [complete setup guide](./docs/development/setup.md) for details.

## 🚀 Development Workflow

### Using Just Commands (Preferred)

The project uses **Just** as a task runner for all operations:

```bash
# Core commands
just setup          # Complete fresh installation
just switch         # Apply Nix configuration
just build          # Build without applying
```
