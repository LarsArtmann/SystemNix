# SSH Key Path Fix & XRT Build Failure Workaround

**Date:** 2026-03-20 12:54
**System:** evo-x2 (GMKtec AMD Ryzen AI Max+ 395)

## Problems

### 1. `nh os switch -v .` Build Failure

The NixOS rebuild failed during the `xrt-202610.2.21.21` build from the `nix-amd-npu` flake input:

```
CMake Error: Could not find a package configuration file provided by "boost_system"
(requested version 1.89.0) with any of the following names:
  boost_systemConfig.cmake
  boost_system-config.cmake
```

The AMD XRT (Xilinx Runtime) package cannot find `boost_system` during its CMake configure phase. This is an upstream issue in `github:robcohen/nix-amd-npu`.

### 2. SSH Authentication Failed

sshd was listening on port 22 with `openFirewall = true`, but authentication always failed. The root cause: the SSH public key path was incorrect.

## Root Causes

### XRT Build Failure

- **Location:** `flake.nix:275` imports `inputs.nix-amd-npu.nixosModules.default`
- **Dependency chain:** `xrt` → `xrt-amdxdna` → `system-path` → full build failure
- **Upstream issue:** Boost 1.89.0 CMake integration changed; `boost_system` is no longer a separate component in modern Boost (it's header-only since 1.73)

### SSH Key Path Mismatch

- **Config location:** `platforms/nixos/system/configuration.nix`
- **Old path:** `./ssh-keys/lars.pub` (resolves to `platforms/nixos/system/ssh-keys/lars.pub`)
- **Actual location:** `ssh-keys/lars.pub` (repo root)
- **Result:** `builtins.pathExists` returned `false`, so `authorizedKeys.keys` was an empty list
- **With `PasswordAuthentication = false`**: No authentication method available

## Solutions

### XRT Workaround

Disabled NPU module temporarily in `platforms/nixos/hardware/amd-npu.nix`:

```nix
hardware.amd-npu = {
  enable = false;  # Was: true
  enableDevTools = true;
  memlockLimit = "unlimited";
};
```

### SSH Key Path Fix

Corrected relative path in `platforms/nixos/system/configuration.nix`:

```nix
openssh.authorizedKeys.keys =
  lib.optional (builtins.pathExists ../../../ssh-keys/lars.pub)  # Was: ./ssh-keys/lars.pub
  (builtins.readFile ../../../ssh-keys/lars.pub);
```

## Verification

```bash
# Path resolves correctly
$ nix-instantiate --eval -E '(builtins.pathExists ../../../ssh-keys/lars.pub)'
true

# Build succeeds
$ nh os switch -v .
> ADDED: lars-authorized_keys

# SSH key installed
$ cat /etc/ssh/authorized_keys.d/lars
ssh-rsa AAAAB3... git@lars.software

# sshd config includes NixOS managed keys
$ grep AuthorizedKeysFile /etc/ssh/sshd_config
AuthorizedKeysFile %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
```

## Files Changed

| File                                       | Change                                             |
| ------------------------------------------ | -------------------------------------------------- |
| `platforms/nixos/hardware/amd-npu.nix`     | `enable = false` (workaround for XRT build)        |
| `platforms/nixos/system/configuration.nix` | Fixed SSH key path to `../../../ssh-keys/lars.pub` |

## Open Items

- **XRT build failure**: Needs upstream fix in `nix-amd-npu` for Boost 1.89.0 compatibility
- **NPU functionality**: Disabled until XRT builds successfully
