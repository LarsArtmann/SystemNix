# Evaluation Warnings Fix

**Date:** 2026-04-03
**Scope:** `nh os switch .` evaluation warnings

## Fixed (3/4)

| Warning                                                                         | Root Cause                            | Fix                                                             | File                                                                                         |
| ------------------------------------------------------------------------------- | ------------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `'swww' has been renamed to 'awww'`                                             | Package renamed upstream              | `swww` → `awww`                                                 | `platforms/common/packages/base.nix:175`, `platforms/nixos/programs/niri-wrapped.nix:19,218` |
| `programs.kitty.theme changed to programs.kitty.themeFile`                      | HM option renamed with different type | `theme = "Catppuccin-Mocha"` → `themeFile = "Catppuccin-Mocha"` | `platforms/nixos/users/home.nix:27`                                                          |
| `'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'` (local) | `builtins.hasAttr "system" pkgs`      | `pkgs.stdenv.hostPlatform.system != null`                       | `platforms/common/core/security.nix:20`                                                      |

Additional: migrated `flake.nix` from deprecated `system = "..."` parameter to `nixpkgs.hostPlatform = "..."` in module config for both NixOS and Darwin systems.

## Remaining (upstream, cannot fix)

```
evaluation warning: 'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'
```

**Cause:** nixpkgs `nixos/modules/misc/nixpkgs.nix:73` — the `legacyOptionsDefined` assertion evaluates `opt.system` to check whether the deprecated option was set by the user. Reading `opt.system` triggers its default value, which throws the deprecation warning. This fires regardless of whether `hostPlatform` is properly configured.

**Source trace:** `legacyOptionsDefined` → `opt.system` → `default` (throws warning) → `assertion = legacyOptionsDefined == []` → always evaluated.

**Upstream issue:** nixpkgs `nixos/modules/misc/nixpkgs.nix` should guard `opt.system` evaluation behind an `isDefined` check or lazy evaluation. No workaround exists from consumer config.

## Build Verification

- `nh os build .` — passes
- `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` — 1 upstream warning only
