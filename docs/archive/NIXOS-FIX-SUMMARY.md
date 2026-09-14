# NixOS evo-x2 Home Manager Fix Summary

## Issue Identified

Home Manager error was caused by parameter mismatch in `dotfiles/nixos/home.nix`:

- Expected `Validation` parameter that wasn't passed from `flake.nix`
- `Validation` is commented out in flake.nix due to Darwin-specific code

## Fix Applied

✅ Removed `Validation` from parameter list in `dotfiles/nixos/home.nix`

## How to Apply the Fix on evo-x2

1. **Transfer the fixed file to evo-x2**:

   ```bash
   # On macOS, create a tarball of the fixed files
   tar -czf nixos-fix.tar.gz \
       dotfiles/nixos/home.nix \
       nixos-diagnostic.sh \
       docs/nixos-home-manager-troubleshooting.md

   # Transfer to evo-x2 (choose one method):
   # Option A: scp
   scp nixos-fix.tar.gz lars@evo-x2:/home/lars/

   # Option B: USB drive
   # Copy to USB, then copy to evo-x2
   ```

2. **On evo-x2, extract and apply**:

   ```bash
   # Extract files
   cd /home/lars/Setup-Mac  # Or wherever your repo is
   tar -xzf ~/nixos-fix.tar.gz

   # Run diagnostic to verify fix
   ./nixos-diagnostic.sh

   # If diagnostics pass, apply configuration
   sudo nixos-rebuild switch --flake .#evo-x2
   ```

3. **Quick test without diagnostic script**:

   ```bash
   # Test build without applying
   sudo nixos-rebuild check --flake .#evo-x2

   # If check passes, apply
   sudo nixos-rebuild switch --flake .#evo-x2
   ```

## What If Errors Still Occur?

1. **Check the diagnostic output** for specific error messages
2. **Review the troubleshooting guide** at `docs/nixos-home-manager-troubleshooting.md`
3. **Try the recovery steps** in the troubleshooting guide

## Files Created/Modified

1. **Modified**: `dotfiles/nixos/home.nix` - Removed Validation parameter
2. **Created**: `nixos-diagnostic.sh` - Comprehensive diagnostic tool
3. **Created**: `docs/nixos-home-manager-troubleshooting.md` - Detailed troubleshooting guide

## Success Indicators

✅ Configuration builds without errors
✅ Home Manager activates successfully
✅ Hyprland and desktop environment start correctly
✅ All user configurations are applied
