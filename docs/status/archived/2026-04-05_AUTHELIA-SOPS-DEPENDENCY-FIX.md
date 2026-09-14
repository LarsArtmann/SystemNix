# Autelia Service Dependency Fix

**Date:** 2026-04-05
**Severity:** High (service failed to start)
**Status:** Fixed
**Files Changed:** `modules/nixos/services/authelia.nix`

## Summary

`authelia-main.service` failed to start during `nh os switch` with:

```
Failed to start authelia-main.service: Unit sops-nix.service not found.
```

## Root Cause

`authelia.nix` declared a hard dependency on `sops-nix.service`:

```nix
systemd.services.authelia-main = {
  after = ["sops-nix.service"];
  requires = ["sops-nix.service"];
};
```

This service unit **does not exist** at the NixOS system level. The `sops-nix` name is used by the **home-manager** sops-nix module (runs as a user-level systemd unit). At the system level, sops-nix provides:

- `system.activationScripts.setupSecrets` — default path (what this config uses)
- `systemd.services.sops-install-secrets` — only if `sops.useSystemdActivation = true`

Since this config does not enable `useSystemdActivation`, secrets are installed via activation scripts, which are guaranteed to complete before any systemd services start. The dependency was both incorrect and unnecessary.

## Fix

Removed the bogus `after` and `requires` directives:

```nix
systemd.services.authelia-main = {
  serviceConfig = {
    StateDirectory = lib.mkForce "authelia-main";
    StateDirectoryMode = lib.mkForce "0750";
  };
};
```

## Audit

Grepped the entire repo for `sops-nix.service` — no other active code references exist. Remaining matches are in `docs/` (recommendations/status reports only).

## Impact

- Authelia will now start correctly on next `just switch`
- No other services were affected by this same issue
- System was rolled back to generation 190 as a result of this failure
