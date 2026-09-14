# Fix Ollama GPU Acceleration & Benchmark Script

**Date:** 2026-03-18 00:40
**Commit:** `7fb8905`

## Problem

Ollama was running **CPU-only** on the GMKtec EVO-X2 despite `ollama-rocm` being installed. All 48 transformer layers were offloaded to CPU (`offloaded 0/48 layers to GPU` in logs). This resulted in ~20 t/s generation speed instead of expected GPU-accelerated performance.

## Root Cause

The Ryzen AI Max+ 395 (Strix Halo, gfx1100/gfx1101) is too new for ROCm in nixpkgs. While `/dev/kfd` exists and ROCm device libs are in the Nix store, `rocminfo` was not even in the system PATH and the ROCm runtime could not initialise the GPU. Ollama silently fell back to CPU with zero indication of failure.

## Fix

### Nix: `platforms/nixos/desktop/ai-stack.nix`

- **`ollama-rocm` -> `ollama-vulkan`**: Nixpkgs has a first-class `pkgs.ollama-vulkan` package that compiles llama.cpp with Vulkan backend and sets `OLLAMA_VULKAN=1` at runtime. Vulkan via RADV is confirmed working on this system (GPU visible in `vulkaninfo`).
- **Removed** `rocmOverrideGfx`, `HIP_VISIBLE_DEVICES`, `ROCM_PATH`, `PYTORCH_ROCM_ARCH` -- all ROCm-specific, irrelevant for Vulkan.
- **`OLLAMA_NUM_PARALLEL`: `"10"` -> `"1"`**: The unified memory architecture splits 128 GB into ~62 GiB OS-visible and ~64 GiB GPU-reserved. BF16 model is 60 GiB. Running 10 parallel requests on BF16 would require ~600 GiB.

### Script: `dev/testing/benchmark_glm_flash_all.py`

Three bugs fixed:

1. **Zero tokens returned**: The word-repetition prompt (`"test test test..."`) produced nothing because GLM-4.7-Flash is a reasoning model that outputs to the `thinking` field. Replaced with a substantive prompt.
2. **Model eviction between runs**: No `keep_alive` was set, causing the model to unload and reload every request. Now sets `keep_alive="10m"`.
3. **Load time mixed into inference**: First request always includes ~8-9s model load. Warmup now absorbs this; load time reported separately.

## Files Changed

| File                                           | Change                                    |
| ---------------------------------------------- | ----------------------------------------- |
| `platforms/nixos/desktop/ai-stack.nix`         | Switch to ollama-vulkan, fix parallelism  |
| `dev/testing/benchmark_glm_flash_all.py`       | Fix prompt, keep_alive, timing extraction |
| `dev/testing/benchmark_glm_flash_findings.md`  | New: root cause analysis and learnings    |
| `dev/testing/glm_flash_benchmark_results.json` | Updated with second run data              |

## Verification

- `nix flake check --no-build` -- passed
- Python syntax check -- passed
- All pre-commit hooks passed (gitleaks, deadnix, statix, alejandra)

## Next Steps

1. `sudo nixos-rebuild switch --flake .#evo-x2` to apply Vulkan change
2. Check Ollama logs for GPU layer offloading: `journalctl -u ollama -f`
3. Expected: `offloaded 48/48 layers to GPU` instead of `0/48`
4. Re-run benchmark: `python3 dev/testing/benchmark_glm_flash_all.py`
