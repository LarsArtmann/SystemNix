# Allow Unfree Packages Fix for NixOS Configuration

## Problem

The error `nixpkgs.config.allowUnfree = true` should be set at the flake level, not in the NixOS configuration module.

## Solution

1. **Removed from NixOS config**: The line was already removed from `dotfiles/nixos/configuration.nix`
2. **Added to flake**: Added `config.allowUnfree = true` to the `pkgsCross` definition in `flake.nix`

## Fixed Code

```nix
# In flake.nix, around line 82:
pkgsCross = import nixpkgs {
  system = "aarch64-darwin";
  crossSystem = "x86_64-linux";
  config.allowUnsupportedSystem = true;
  config.allowUnfree = true;  # ← Added this line
};
```

## Cross-Compilation Limitation

Note: Building NixOS from macOS requires cross-compilation, which has limitations:

- Some packages require pre-generated configuration files
- Complex packages like Samba/TDB may fail to cross-compile
- Full system builds should be done on a Linux system or using proper NixOS infrastructure

## Alternative Approaches

1. Build on Linux system or VM
2. Use NixOS ISO generation tools
3. Use remote build services
4. Validate configuration syntax without full builds

The main fix (allowUnfree configuration) has been implemented correctly.
