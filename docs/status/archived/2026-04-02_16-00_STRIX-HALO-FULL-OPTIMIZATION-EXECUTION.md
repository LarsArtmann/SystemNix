# Strix Halo Full GPU/NPU Optimization — Execution Report

**Date:** 2026-04-02 16:00
**Hardware:** GMKtec EVO-X2 — AMD Ryzen AI Max+ 395 (Strix Halo, gfx1151, RDNA 3.5)
**OS:** NixOS 26.05 (Yarara), kernel 6.19.10
**Source:** [Gygeek/Framework-strix-halo-llm-setup](https://github.com/Gygeek/Framework-strix-halo-llm-setup)

---

## Summary

Applied comprehensive Strix Halo optimizations across 4 files based on community research from Gygeek, pablo-ross, and kyuz0 repos. All changes pass `nix flake check --no-build`.

---

## Changes Applied

### 1. `platforms/nixos/system/boot.nix` — Kernel & Memory

| Setting                       | Before              | After                                                     | Why                                        |
| ----------------------------- | ------------------- | --------------------------------------------------------- | ------------------------------------------ |
| `amdgpu.gttsize`              | Not set             | `131072` (128GB)                                          | Enable full GTT allocation for GPU compute |
| `ttm.pages_limit`             | `29360128` (~112GB) | `31457280` (~120GB)                                       | Increase TTM page pool for AI workloads    |
| `amd_iommu=off`               | Not set             | Added                                                     | ~6% memory read improvement                |
| `extraModprobeConfig`         | Not set             | `gttsize=122800, ttm pages_limit/page_pool_size=31457280` | Persistent modprobe config for TTM pool    |
| `vm.swappiness`               | Default (60)        | `10`                                                      | Keep model data in RAM                     |
| `vm.dirty_ratio`              | Default (20)        | `15`                                                      | Earlier writeback on BTRFS                 |
| `vm.dirty_background_ratio`   | Default (10)        | `5`                                                       | Background writeback starts sooner         |
| `vm.min_free_kbytes`          | Default             | `1048576` (1GB)                                           | Reserve for GTT allocations                |
| `vm.max_map_count`            | Default             | `2147483642`                                              | Large model memory maps                    |
| `vm.compaction_proactiveness` | Default             | `20`                                                      | Proactive hugepage compaction              |

### 2. `platforms/nixos/hardware/amd-gpu.nix` — GPU Libraries & Udev

| Setting                  | Before        | After                                      | Why                                      |
| ------------------------ | ------------- | ------------------------------------------ | ---------------------------------------- |
| `rocmPackages.rocblas`   | Not installed | Added                                      | BLAS operations for AI/ML                |
| `rocmPackages.hipblaslt` | Not installed | Added                                      | Enables `ROCBLAS_USE_HIPBLASLT=1`        |
| `rocmPackages.rocminfo`  | Not installed | Added                                      | GPU detection and topology               |
| GPU DPM high udev rule   | Not set       | `power_dpm_force_performance_level="high"` | Fixes 10-15% perf loss from power saving |
| `rocmPackages.rocm-smi`  | Not installed | Added                                      | GPU stats, clocks, memory                |
| `nvtopPackages.amd`      | Not installed | Added                                      | htop-like GPU monitor                    |

### 3. `platforms/nixos/desktop/ai-stack.nix` — AI Stack Overhaul

| Setting                    | Before            | After                                   | Why                                             |
| -------------------------- | ----------------- | --------------------------------------- | ----------------------------------------------- |
| Ollama backend             | `ollama-vulkan`   | `ollama-rocm`                           | hipBLASLt for optimized GEMM                    |
| `OLLAMA_FLASH_ATTENTION`   | `"1"`             | `"1"`                                   | Unchanged                                       |
| `ROCBLAS_USE_HIPBLASLT`    | Not in Ollama env | Added to Ollama env                     | Enable batched GEMM in Ollama                   |
| `security.pam.loginLimits` | Not set           | `memlock unlimited` (soft+hard)         | ROCm needs unlimited for large GTT buffers      |
| `llama-cpp`                | Generic build     | `llama-cpp-rocwmma` (custom derivation) | rocWMMA + MFMA cmake flags                      |
| `GGML_HIP_ROCWMMA_FATTN`   | Not set           | `ON`                                    | 2x prompt processing speed                      |
| `GGML_HIP_MMQ_MFMA`        | Not set           | `ON`                                    | Matrix fused multiply-add for quantized kernels |
| `ROCBLAS_USE_HIPBLASLT`    | Already set       | Unchanged                               | Session-level env var                           |

### 4. Previous Commit (`a354b23`) — Already Applied

| Setting                            | File                   | Status                    |
| ---------------------------------- | ---------------------- | ------------------------- |
| `"render"` group for `lars`        | `configuration.nix:76` | Committed, pending reboot |
| `HSA_OVERRIDE_GFX_VERSION` removed | `ai-stack.nix:37`      | Committed, pending reboot |
| `amd_iommu=off` kernel param       | `boot.nix:25`          | Updated in this commit    |
| KFD/DRM udev rules                 | `amd-gpu.nix:34-38`    | Committed, pending reboot |
| NPU enabled (`false` → `true`)     | `amd-npu.nix:7`        | Committed, pending reboot |

---

## Expected Performance Impact

| Optimization                            | Expected Impact                                      |
| --------------------------------------- | ---------------------------------------------------- |
| rocWMMA Flash Attention                 | **2x prompt processing** (871 t/s vs ~435 t/s on 7B) |
| GPU DPM high                            | **10-15% token generation** improvement              |
| `amd_iommu=off`                         | **~6% memory read** improvement                      |
| `hipblaslt` + `ROCBLAS_USE_HIPBLASLT=1` | **Optimized batched GEMM** for prompt processing     |
| `amdgpu.gttsize=131072`                 | **Full 128GB GTT** access (was capped at 31GB)       |
| memlock unlimited                       | **Eliminates OOM** on large model loads              |
| VM sysctl tuning                        | **Reduced stalls** during model loading/switching    |

---

## Post-Reboot Verification Checklist

```bash
# 1. Verify kernel params applied
cat /proc/cmdline | grep -o "amdgpu.gttsize=[0-9]*"
cat /proc/cmdline | grep -o "amd_iommu=off"
cat /proc/cmdline | grep -o "amdgpu.ttm.pages_limit=[0-9]*"

# 2. Verify GTT is now full size
cat /sys/class/drm/card*/device/mem_info_gtt_total
# Expected: ~137438953472 (128GB) or close

# 3. Verify render group
id lars | grep render

# 4. Verify IOMMU disabled (should return nothing)
journalctl -k | grep "AMD-Vi: IOMMU"

# 5. Verify GPU DPM high
cat /sys/class/drm/card*/device/power_dpm_force_performance_level
# Expected: high

# 6. Verify sysctls
sysctl vm.swappiness vm.dirty_ratio vm.min_free_kbytes vm.max_map_count

# 7. Verify memlock
ulimit -l
# Expected: unlimited

# 8. Verify ROCm sees GPU
rocminfo | grep gfx1151

# 9. Verify llama-cpp has ROCm support
llama-cli --version

# 10. Benchmark
llama-bench -m <model.gguf> -mmp 0 -ngl 99 -p 512 -n 128 -r 3
```

---

## Remaining Future Work

| Item                                        | Priority | Notes                                            |
| ------------------------------------------- | -------- | ------------------------------------------------ |
| BIOS UMA → 512MB + GTT approach             | P4       | Tradeoff: less dedicated VRAM, more flexible GTT |
| PyTorch ROCm setup                          | P3       | Distrobox with kyuz0 container is easiest path   |
| `amd_pstate=active` benchmarking            | P3       | Test vs current `guided` mode                    |
| Boot performance analysis                   | P3       | `systemd-analyze critical-chain`                 |
| GPU crash root cause (Mar 31 kitty timeout) | P2       | Monitor for recurrence after GFX version fix     |
