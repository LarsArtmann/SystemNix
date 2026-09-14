# Unsloth Studio & Podman Photomap — Outstanding Issues

**Date:** 2026-04-03
**Status:** Services running, three issues remain

---

## 1. GPU Not Detected — `torch.cuda.is_available()` Returns False

**Severity:** High — defeats the purpose of running on AMD Strix Halo
**Service:** `unsloth-studio.service`
**File:** `platforms/nixos/desktop/ai-stack.nix:193-196`

### Problem

The service starts and logs:

```
Hardware detected: CPU (no GPU backend available)
```

PyTorch ROCm 6.3 was installed via pip (`--index-url https://download.pytorch.org/whl/rocm6.3`), but `torch.cuda.is_available()` returns False at runtime. The detection logic in `studio/backend/utils/hardware/hardware.py:76-122` checks:

1. `torch.cuda.is_available()` → CUDA/ROCm
2. `torch.xpu.is_available()` → Intel XPU
3. `is_apple_silicon()` and `_has_mlx()` → Apple
4. Fallback → CPU

It falls through to CPU. Detection order has no AMD/ROCm-specific path — ROCm is exposed through the CUDA compatibility layer, so `torch.cuda.is_available()` must return True.

### Root Cause

The `LD_LIBRARY_PATH` only includes `stdenv.cc.cc.lib` (for `libstdc++.so.6`):

```nix
environment = {
  HOME = unslothDataDir;
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
};
```

The pip-installed PyTorch ROCm wheel ships its own ROCm runtime but needs additional system libraries:

- `libzstd.so.1` — required by torch's C extensions, not in `stdenv.cc.cc.lib`
- ROCm runtime libraries (`libamdhip64.so`, `libhsa-runtime64.so`, etc.) — may need Nix ROCm packages in `LD_LIBRARY_PATH`

Testing from a shell with only `LD_LIBRARY_PATH=/nix/store/...-gcc-15.2.0-lib/lib` fails:

```
ImportError: libzstd.so.1: cannot open shared object file
```

Inside the systemd unit, torch imports successfully (systemd provides additional implicit library paths) but `torch.cuda.is_available()` still returns False, meaning the ROCm HIP runtime can't find the GPU.

### Fix

Add ROCm runtime libraries and `zstd` to `LD_LIBRARY_PATH` in the `unsloth-studio` service:

```nix
environment = {
  HOME = unslothDataDir;
  LD_LIBRARY_PATH = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zstd
    pkgs.rocmPackages.clr
    pkgs.rocmPackages.rocminfo
    pkgs.rocmPackages.rocrand
    pkgs.rocmPackages.rocblas
  ];
};
```

Also verify the pip-installed PyTorch ROCm wheel actually bundles ROCm 6.3 runtime or if it expects system ROCm. If the wheel bundles its own runtime, the issue is purely missing system libs like `libzstd`. If not, the Nix ROCm packages above are essential.

### Verification

After fix, the service log should show:

```
Hardware detected: CUDA — AMD Radeon AI Max+ 395
```

Test from shell:

```bash
LD_LIBRARY_PATH="..." /var/lib/unsloth/venv/bin/python -c "
import torch
print(torch.cuda.is_available())
print(torch.cuda.get_device_properties(0).name)
"
```

---

## 2. Frontend Build Fails on Clean Install — Missing `sh` in PATH

**Severity:** Medium — breaks first-time setup, requires manual intervention
**Service:** `unsloth-setup.service`
**File:** `platforms/nixos/desktop/ai-stack.nix:89-91`

### Problem

Phase 3 of `unsloth-setup` runs `pnpm run build`, which executes `tsc -b && vite build`. The `tsc` (TypeScript compiler) spawns child processes using `sh`, which is not in the service's `path`.

The setup log from the initial install:

```
pnpm error enoent spawn sh ENOENT
pnpm error enoent This is related to pnpm not being able to find a file.
```

The script has `set -euo pipefail` but the pnpm build failure didn't cause the script to exit because it was a child process exit code. The setup continued to `date -Iseconds > ${setupDone}` and wrote the marker file despite the frontend never being built.

This is why the first switch showed:

```
[WARNING] Frontend not found at .../studio/frontend/dist
```

### Root Cause

The `path` for `unsloth-setup` is:

```nix
path = with pkgs; [
  python313 git gcc gnumake cmake ninja cacert
  nodejs_22 coreutils
];
```

Missing: `bash` (provides `sh`). NixOS systemd services don't inherit the system PATH — only what's explicitly listed. While `coreutils` is there, `bash` is not, so `sh` is unavailable to pnpm's child process spawning.

### Fix

Add `bash` to the setup service's `path`:

```nix
path = with pkgs; [
  bashInteractive  # provides /bin/sh for pnpm child processes
  python313 git gcc gnumake cmake ninja cacert
  nodejs_22 coreutils
];
```

Use `bashInteractive` (not `bash`) to avoid pulling in the full bash package with extras. Alternatively, `pkgs.bash` works too.

### Verification

After a clean install (delete venv + marker, restart setup):

```
journalctl -u unsloth-setup.service --no-pager -f
```

Should show:

```
✓ built in Xms
Studio setup complete.
```

And `dist/` directory should exist:

```bash
ls /var/lib/unsloth/venv/lib/python3.13/site-packages/studio/frontend/dist/index.html
```

### Workaround for Current Install

The frontend was built manually and is in place. This fix only matters for the next clean install. To test the fix without a full reinstall:

```bash
rm /var/lib/unsloth/.studio-setup-done
rm -rf /var/lib/unsloth/venv/lib/python3.13/site-packages/studio/frontend/dist
sudo systemctl restart unsloth-setup.service
# Setup will skip Phase 1 (venv exists) and Phase 2 (deps installed)
# but will re-run Phase 3 (frontend build)
```

---

## 3. Deprecated `system` Parameter in flake.nix

**Severity:** Low — warning only, no functional impact
**File:** `flake.nix:278`

### Problem

Every `nh os switch` shows:

```
evaluation warning: 'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'
```

### Root Cause

`flake.nix:278` has:

```nix
nixosConfigurations."evo-x2" = nixpkgs.lib.nixosSystem {
  system = null;           # ← line 278, deprecated parameter
  specialArgs = { ... };
  modules = [
    {
      nixpkgs.hostPlatform = "x86_64-linux";  # ← line 292, correct modern form
      ...
    }
    ...
  ];
};
```

The `system` parameter to `nixosSystem` is a legacy input. Nixpkgs internally accesses `pkgs.system` which triggers the deprecation warning. The modern `nixpkgs.hostPlatform` is already set on line 292.

### Fix

Remove line 278 entirely:

```nix
nixosConfigurations."evo-x2" = nixpkgs.lib.nixosSystem {
  specialArgs = { ... };
  modules = [
    {
      nixpkgs.hostPlatform = "x86_64-linux";
      ...
    }
    ...
  ];
};
```

### Verification

```bash
nh os switch . 2>&1 | grep -i "warning.*system"
# Should produce no output
```

---

## Completed Fixes (Reference)

These were resolved during this session and are documented for context.

### podman-photomap SQLite Path Mismatch

- **Cause:** `virtualisation.containers.storage.settings.storage.graphroot = "/data/containers/storage"` in `modules/nixos/services/default.nix` conflicted with podman's compiled-in default path
- **Fix:** Removed the entire `storage.settings.storage` block. Podman now uses default `/var/lib/containers/storage`
- **File:** `modules/nixos/services/default.nix`

### ConditionPathExists in Wrong systemd Section

- **Cause:** `ConditionPathExists` was set in `serviceConfig` (maps to `[Service]`) instead of `unitConfig` (maps to `[Unit]`). Systemd silently ignores unknown directives in `[Service]`
- **Fix:** Moved to `unitConfig.ConditionPathExists`
- **File:** `platforms/nixos/desktop/ai-stack.nix:198-200`

### ExecStartPre Podman DB Cleanup Hack

- **Cause:** Workaround script deleting `/data/containers/storage/libpod` on every start was masking the real issue
- **Fix:** Removed `ExecStartPre` block entirely since root cause (custom graphroot) was fixed
- **File:** `modules/nixos/services/photomap.nix:57-60`

### Orphaned Podman Storage

- **Location:** `/data/containers/`
- **Action needed:** `sudo rm -rf /data/containers/` (manual, when convenient)
- **Impact:** None — podman now uses `/var/lib/containers/storage`
