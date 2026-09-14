# Home Manager Bug Report: users.users.<name>.home Requirement

## Issue Summary

Home Manager for nix-darwin (macOS) appears to require explicit `config.users.users.<name>.home` definition to be set in system configuration (darwin configuration), otherwise certain functionality fails or produces errors.

## Environment

- **Operating System**: macOS (nix-darwin)
- **Architecture**: aarch64-darwin
- **Nix Version**: 2.18.0 (2025-01-01)
- **Home Manager Version**: unstable/master branch
- **nix-darwin Version**: latest/master branch

## Problem Description

When using Home Manager with nix-darwin without explicitly defining `users.users.<name>.home` in the system-level Darwin configuration, Home Manager may fail to properly resolve user home directory paths or may throw assertion errors related to missing user home directory configuration.

### Current Workaround

The workaround in `platforms/darwin/default.nix`:

```nix
# Define users for Home Manager (workaround for nix-darwin/common.nix import issue)
users.users.larsartmann = {
  name = "larsartmann";
  home = "/Users/larsartmann";
};
```

This workaround is referenced in:

- `platforms/darwin/services/launchagents.nix` (line 5):
  ```nix
  userHome = config.users.users.larsartmann.home or "/Users/larsartmann";
  ```

### Issue with Workaround

The workaround comment states: "workaround for nix-darwin/common.nix import issue"

However, this import does not exist in the current configuration:

- No file `nixos/common.nix` is imported by darwin configuration
- No cross-reference to such file exists

This suggests the workaround may be based on:

1. A misunderstanding or obsolete issue
2. An issue that has since been fixed in Home Manager
3. An architectural confusion between nix-darwin and NixOS user management

## Expected Behavior

Home Manager should be able to infer and use the user home directory without requiring explicit system-level user configuration when:

- Home Manager is configured via `home-manager.users.<name>.home = import ./path/to/home.nix`
- The user configuration is already imported in the Home Manager module
- User name is specified in the Home Manager configuration

## Actual Behavior

Home Manager (or nix-darwin) requires explicit `config.users.users.<name>.home` definition to be set, otherwise:

- LaunchAgent working directory resolution fails
- Path resolution for `userHome` in nix-darwin modules requires fallback
- System-level user configuration must be duplicated (once in Home Manager, once in nix-darwin)

## Reproduction Steps

1. Create nix-darwin configuration with Home Manager integration:

   ```nix
   {
     config,
     ...
   }:
   {
     home-manager = {
       useGlobalPkgs = true;
       useUserPackages = true;
       users.larsartmann = import ./platforms/darwin/home.nix;
     };
   }
   ```

2. Create nix-darwin module that references `userHome`:

   ```nix
   {config, ...}: let
     userHome = config.users.users.larsartmann.home or "/Users/larsartmann";
   in {
     environment.userLaunchAgents = {
       "example.service.plist" = {
         enable = true;
         text = ''
           <key>WorkingDirectory</key>
           <string>${userHome}</string>
         '';
       };
     };
   }
   ```

3. Remove explicit users definition from nix-darwin config:

   ```nix
   # Remove this:
   # users.users.larsartmann = {
   #   name = "larsartmann";
   #   home = "/Users/larsartmann";
   # };
   ```

4. Build configuration:
   ```bash
   darwin-rebuild switch --flake .
   ```

## Expected Result

Configuration should build successfully without requiring explicit system-level user definition, since:

- User is already specified in Home Manager configuration
- Home Manager manages user configuration
- User home directory should be inferred from current system

## Actual Result

Configuration fails or produces errors related to missing user home directory definition (exact error depends on Home Manager version).

## Impact

- **Code Duplication**: User must be defined twice (Home Manager + system config)
- **Maintainability**: Workaround adds confusion about what's actually required
- **Portability**: Workaround makes configuration less portable across platforms
- **Documentation**: Comment references non-existent import, adding confusion

## Related Files

- `platforms/darwin/default.nix` (lines 24-27) - workaround definition
- `platforms/darwin/services/launchagents.nix` (line 5) - references userHome
- `flake.nix` (lines 94-107) - Home Manager configuration for Darwin
- `platforms/darwin/home.nix` - imported by Home Manager

## Questions for Home Manager Team

1. **Is explicit `users.users.<name>.home` definition actually required** for nix-darwin + Home Manager, or is the workaround obsolete?

2. **If required**, is this documented in Home Manager for nix-darwin? If so, where?

3. **If not required**, what's the proper way to configure user home directory in nix-darwin modules?

4. **What's the source of the "nix-darwin/common.nix import issue"** mentioned in the workaround comment? Does this refer to a known issue?

## Suggested Fix Options

### Option 1: Infer User Home Directory from Environment

Home Manager should infer user home directory from:

- Current system user (determined by whoami or similar)
- Standard macOS home directory path (/Users/username)
- Environment variables

### Option 2: Provide Explicit Configuration Option

Add Home Manager option for nix-darwin:

```nix
home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  users.larsartmann = import ./home.nix;
  nix-darwin = {
    userHome = "/Users/larsartmann"; # Explicit override
  };
}
```

### Option 3: Document Requirement

If the workaround is actually required, document it clearly in:

- Home Manager for nix-darwin documentation
- Migration guide from NixOS to nix-darwin
- Cross-platform configuration best practices

## Additional Context

This issue was discovered during a comprehensive codebase audit and anti-pattern remediation process (2026-01-13).

The Setup-Mac project uses:

- flake-parts for modular architecture
- Home Manager for cross-platform user configuration
- Shared modules in `platforms/common/` for both macOS and NixOS

The workaround was added at an unknown date, but the comment referencing non-existent import suggests it may be based on outdated information.

## Next Steps

- Test whether removing the workaround actually breaks the build
- If workaround is obsolete, remove it and update documentation
- If workaround is required, file this report with Home Manager team
- Update documentation to clarify user configuration requirements

---

**Report Date**: 2026-01-13
**Reporter**: Lars Artmann (Setup-Mac project)
**Priority**: Medium (workaround exists, but unclear if actually needed)
**Status**: Awaiting verification (needs build test without workaround)
