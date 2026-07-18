# Library Policy Documentation

**Last Updated:** 2026-03-27
**Status:** ✅ Implemented
**Scope:** Cross-platform Nix configuration system

---

## Overview

This document describes the library and package policy system implemented in the SystemNix configuration. The goal is to maintain a clean, consistent, and maintainable codebase through centralized configuration management.

## Policy Architecture

### 1. Package Management Policy

**Location:** `platforms/common/core/nix-settings.nix`

#### Allow Unfree Packages

The configuration uses a centralized `allowUnfreePredicate` function to control which unfree packages are permitted:

```nix
allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [
    "vault"           # BSL license
    "terraform"       # BSL license
    "cursor"          # Unfree
    "idea-ultimate"   # Unfree
    "webstorm"        # Unfree
    "goland"          # Unfree
    "rider"           # Unfree
    "google-chrome"   # Unfree
    "signal-desktop-bin"  # AGPL3
    "castlabs-electron"   # For tidal-hifi
    "grayjay"         # SFL license
  ];
```

**Rationale:**

- Explicit whitelist prevents accidental installation of unwanted unfree software
- Single source of truth for all platforms (Darwin and NixOS)
- Easy to audit and modify

#### Insecure Packages

Specific insecure package versions can be permitted when necessary:

```nix
permittedInsecurePackages = [
  "google-chrome-144.0.7559.97"  # Required for Chrome browser
];
```

**Policy:** Only permit insecure packages when:

1. No secure alternative exists
2. The package is essential for the workflow
3. The vulnerability is understood and accepted

### 2. Chrome/Chromium Extension Policy

**Locations:**

- Darwin: `platforms/darwin/programs/chrome.nix`
- NixOS: `platforms/nixos/programs/chrome.nix`

#### Extension Management

The system enforces a declarative extension management policy:

**Force-Installed Extensions:**

- YouTube Shorts Blocker (`ckagfhpboagdopichicnebandlofghbc`)
  - Rationale: Productivity enhancement
  - Source: Open source (https://github.com/umutseven92/shorts-blocker)

**Security Policies:**

```nix
BrowserSignin = 0;              # Disable browser sign-in
SyncDisabled = true;            # Disable sync
PasswordManagerEnabled = false; # Use external password manager
SafeBrowsingEnabled = true;     # Enable safe browsing
HttpsOnlyMode = "force_enabled"; # Force HTTPS
```

**Platform Differences:**

- **Darwin:** Uses `/etc/chrome/policies/managed/` + manual application script
- **NixOS:** Uses native `programs.chromium` module for full enterprise management

### 3. Path Management Policy

#### Centralized Path Configuration

**Location:** `platforms/common/core/PathConfig.nix`

**Purpose:** Eliminate hardcoded path fragmentation across the system

**Default Paths:**

```nix
defaultPaths = {
  home = "/Users/larsartmann";
  config = "/Users/larsartmann/.config";
  dotfiles = "/Users/larsartmann/projects/SystemNix/dotfiles";
  nixConfig = "/Users/larsartmann/projects/SystemNix/dotfiles/nix";
  core = "/Users/larsartmann/projects/SystemNix/dotfiles/nix/core";
};
```

**Usage:**

```nix
# Instead of:
somePath = "/Users/larsartmann/.config/app";

# Use:
somePath = "${paths.config}/app";
```

#### Shell Scripts Path Library

**Location:** `scripts/lib/paths.sh`

**Purpose:** Centralized path management for shell scripts

**Usage:**

```bash
#!/usr/bin/env bash
source scripts/lib/paths.sh

echo "Project root: $PROJECT_ROOT"
echo "User home: $USER_HOME"
cd "$DOTFILES_DIR"
```

**Available Variables:**

- `PROJECT_ROOT` - SystemNix repository root
- `DOTFILES_DIR` - Dotfiles directory
- `PLATFORMS_DIR` - Platform-specific configs
- `USER_HOME` - Current user's home directory
- `USER_CONFIG` - User's .config directory
- `COMMON_DIR`, `DARWIN_DIR`, `NIXOS_DIR` - Platform directories

**Helper Functions:**

- `get_platform_dir <platform> [subdir]` - Get platform-specific directory
- `resolve_path <relative_path>` - Resolve path relative to project root
- `is_darwin()` - Check if running on macOS
- `is_linux()` - Check if running on Linux
- `ensure_dir <path>` - Create directory if it doesn't exist

### 4. User Configuration Policy

**Location:** `platforms/common/core/UserConfig.nix`

**Purpose:** Single source of truth for user-specific configuration

**Schema:**

```nix
UserType = {
  username = "larsartmann";
  fullName = "Lars Artmann";
  email = "lars@larsartmann.de";
  homeDir = "/Users/larsartmann";  # Read-only
  configDir = "/Users/larsartmann/.config";  # Read-only
};
```

**Helper Functions:**

- `mkUserConfig <user>` - Create user config from partial data
- `validateUserConfig <user>` - Validate user configuration

## Implementation Guidelines

### DO ✅

1. **Use centralized configuration**

   ```nix
   # Good
   imports = [ ../common/core/nix-settings.nix ];

   # Bad
   nixpkgs.config.allowUnfree = true;  # Duplicates centralized config
   ```

2. **Use relative paths**

   ```nix
   # Good
   safe.directory = [ "~" "~/projects" ];

   # Bad
   safe.directory = [ "/Users/larsartmann/projects" ];
   ```

3. **Import common modules**
   ```nix
   imports = [
     ../common/core/nix-settings.nix    # Package policies
     ../common/core/PathConfig.nix      # Path management
     ../common/core/UserConfig.nix      # User configuration
   ];
   ```

### DON'T ❌

1. **Duplicate nixpkgs configuration**
   - Never add `allowUnfree` in platform-specific files
   - Always extend the centralized predicate instead

2. **Hardcode user paths**
   - Never use absolute paths like `/Users/larsartmann`
   - Use `~` or `config.home.homeDirectory` instead

3. **Create parallel configuration systems**
   - Don't create new configuration files for settings that already exist
   - Extend existing centralized modules instead

## Platform-Specific Considerations

### Darwin (macOS)

- **Sandbox:** Disabled due to macOS compatibility (`lib.mkForce false`)
- **Chrome Policy:** Requires manual application via script
- **User Paths:** Must handle both `/Users/` and potential future Linux paths

### NixOS (Linux)

- **Sandbox:** Enabled for security (`true`)
- **Chrome Policy:** Fully managed via `programs.chromium` module
- **User Paths:** Uses `/home/` prefix

## Verification and Testing

### Verify Package Policy

```bash
# Check that centralized config is being used
nix flake check --no-build

# Test configuration builds
just test

# Verify no duplicate configs
grep -r "allowUnfree" platforms/ --include="*.nix"
```

### Verify Path Configuration

```bash
# Test paths library
source scripts/lib/paths.sh
debug_paths  # Print all paths
validate_project_root  # Verify project root found correctly
```

### Verify Chrome Policy

```bash
# Darwin: Check policy file exists
ls -la /etc/chrome/policies/managed/extensions.json

# NixOS: Check Chromium configuration
nixos-option programs.chromium.extensions

# Browser: Navigate to chrome://policy
```

## Migration Guide

### Migrating Hardcoded Paths

1. **Identify the path**

   ```bash
   grep -r "/Users/larsartmann" --include="*.nix" platforms/
   ```

2. **Determine the replacement**
   - Home directory → `~` or `config.home.homeDirectory`
   - Project paths → Import and use `PathConfig.nix`
   - User-specific → Import and use `UserConfig.nix`

3. **Update the configuration**

   ```nix
   # Before
   path = "/Users/larsartmann/projects";

   # After
   path = "~/projects";
   ```

4. **Test the change**
   ```bash
   just test
   just switch
   ```

### Adding New Unfree Packages

1. **Edit centralized config**

   ```nix
   # platforms/common/core/nix-settings.nix
   allowUnfreePredicate = pkg:
     builtins.elem (lib.getName pkg) [
       # ... existing packages ...
       "new-package"  # Add your package
     ];
   ```

2. **Test the change**

   ```bash
   just test
   just switch
   ```

3. **Document the addition**
   - Add comment explaining why the package is needed
   - Note the license type

## Troubleshooting

### Issue: "allowUnfree" conflicts

**Symptom:** Build errors about duplicate `allowUnfree` configuration

**Solution:**

1. Check for duplicate `nixpkgs.config` in platform files
2. Remove duplicates and rely on `common/core/nix-settings.nix`
3. Rebuild with `just switch`

### Issue: Hardcoded paths breaking on different machines

**Symptom:** Configuration fails when cloned to different user account

**Solution:**

1. Find all hardcoded paths: `grep -r "/Users/$(whoami)" --include="*.nix"`
2. Replace with dynamic paths using `~` or `config.home.homeDirectory`
3. Update to use `PathConfig.nix` for project paths

### Issue: Chrome extensions not installing

**Symptom:** Force-installed extensions don't appear in browser

**Darwin Solution:**

```bash
# Run the policy application script
sudo chrome-apply-policies

# Restart Chrome
# Check chrome://policy
```

**NixOS Solution:**

```bash
# Rebuild system
sudo nixos-rebuild switch --flake .#evo-x2

# Check Chromium policy
chromium --policy
```

## Future Improvements

### Planned Enhancements

1. **Dynamic user detection** - Automatically detect username instead of hardcoded defaults
2. **Cross-platform path normalization** - Handle `/Users/` vs `/home/` automatically
3. **Policy validation tooling** - Automated checks for policy compliance
4. **Secret management integration** - Integrate with SOPS or similar for sensitive policies

### Known Limitations

1. **Darwin Chrome Policy:** Requires manual application (MDM limitation)
2. **User Detection:** Still requires manual configuration for new users
3. **Platform Detection:** Some files assume Darwin (macOS) default

## References

- [AGENTS.md](../AGENTS.md) - Project guidelines and coding standards
- [CHROMIUM-EXTENSIONS-GUIDE.md](./CHROMIUM-EXTENSIONS-GUIDE.md) - Chrome extension management
- [NixOS Manual: nixpkgs Config](https://nixos.org/manual/nixpkgs/stable/#sec-modify-via-config)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)

---

**Maintainer:** Lars Artmann
**Last Review:** 2026-03-27
**Next Review:** 2026-06-27
