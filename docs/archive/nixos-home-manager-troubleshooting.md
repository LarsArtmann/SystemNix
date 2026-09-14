# NixOS evo-x2 Home Manager Error Troubleshooting Guide

## Quick Start

1. **Run the diagnostic script** on evo-x2:

   ```bash
   ./nixos-diagnostic.sh
   ```

2. **If diagnostics pass**, run:

   ```bash
   sudo nixos-rebuild switch --flake .#evo-x2
   ```

3. **If errors occur**, see specific fixes below.

## Common Issues and Solutions

### Issue 1: Home Manager Profile Corruption

**Symptoms:**

- `home-manager switch` fails with profile errors
- Broken symlinks in ~/.nix-profile

**Solution:**

```bash
# Clean up old generations
nix-env --delete-generations old --profile /nix/var/nix/profiles/per-user/$USER/home-manager

# If still broken
nix-env --delete-generations +999 --profile /nix/var/nix/profiles/per-user/$USER/home-manager

# Rebuild configuration
sudo nixos-rebuild switch --flake .#evo-x2
```

### Issue 2: Nix Store Corruption

**Symptoms:**

- "Nar hash mismatch" errors
- "Bad nar archive" messages
- Build failures with hash mismatches

**Solution:**

```bash
# Clean up store
sudo nix-collect-garbage -d

# Repair store if needed
sudo nix-store --verify --check-contents --repair

# Rebuild
sudo nixos-rebuild switch --flake .#evo-x2
```

### Issue 3: Insufficient Disk Space

**Symptoms:**

- Build fails during download or extraction
- Out of space errors

**Solution:**

```bash
# Check space
df -h /nix

# Clean up
sudo nix-collect-garbage -d

# Remove old generations
sudo nixos-rebuild delete-generations +10
sudo nixos-rebuild switch --flake .#evo-x2
```

### Issue 4: Nix Daemon Issues

**Symptoms:**

- Permission denied errors
- "nix-daemon not running" messages
- Build failures during fetch phase

**Solution:**

```bash
# Check daemon status
sudo systemctl status nix-daemon

# Restart if needed
sudo systemctl restart nix-daemon

# Fix permissions
sudo chown -R $USER:users ~/.nix-defexpr

# Rebuild
sudo nixos-rebuild switch --flake .#evo-x2
```

### Issue 5: Input/Output or Network Errors

**Symptoms:**

- "Connection refused" during fetch
- "Input/output error" during build
- Partial downloads

**Solution:**

```bash
# Clean downloads
sudo rm -rf /tmp/nix-*

# Update flake inputs
nix flake update

# Rebuild
sudo nixos-rebuild switch --flake .#evo-x2
```

## Advanced Troubleshooting

### Recovering from Broken Generation

If system boots into a broken generation:

```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous working generation
sudo nixos-rebuild switch --profile-name nixos-system-hdgsjfi3819...

# Or boot into previous generation from GRUB
# (Select older generation in bootloader)
```

### Resetting Home Manager Completely

```bash
# WARNING: This removes ALL Home Manager configurations
# Only use as last resort

# Remove home-manager profile
nix-env --delete-generations +999 --profile /nix/var/nix/profiles/per-user/$USER/home-manager

# Clean up home directory
rm -rf ~/.nix-profile
rm -rf ~/.nix-defexpr

# Rebuild from scratch
sudo nixos-rebuild switch --flake .#evo-x2
```

## Getting Help

### Collect Debug Information

```bash
# Create debug report
sudo nixos-rebuild build --flake .#evo-x2 --show-trace 2>&1 > nixos-build.log 2>&1

# Collect system info
nix-info -m > system-info.log

# Home Manager debug info
home-manager --version > hm-version.log
```

### Common Places to Look for Clues

1. **System logs**: `journalctl -xe`
2. **Nix logs**: `journalctl -u nix-daemon`
3. **Build logs**: In the error output (use --show-trace)
4. **Home Manager logs**: `journalctl --user -u home-manager`

## Prevention Tips

1. **Regular maintenance**:

   ```bash
   # Run weekly
   sudo nix-collect-garbage -d
   ```

2. **Test before applying**:

   ```bash
   sudo nixos-rebuild test --flake .#evo-x2
   sudo nixos-rebuild switch --flake .#evo-x2
   ```

3. **Keep working generations**:

   ```bash
   # Don't delete all old generations immediately
   sudo nixos-rebuild delete-generations +10  # Keep last 10
   ```

4. **Backup before major changes**:
   ```bash
   # Export current generation
   nix-env --export > backup.nix
   ```

## What Was Fixed in This Configuration

The issue in your configuration was a parameter mismatch:

1. **File**: `dotfiles/nixos/home.nix`
2. **Problem**: Expected `Validation` parameter that wasn't passed
3. **Solution**: Removed `Validation` from parameter list
4. **Why**: In `flake.nix` line 243, `Validation` is commented out due to Darwin-specific code

This mismatch would cause Home Manager to fail during evaluation with an "undefined variable" error.
