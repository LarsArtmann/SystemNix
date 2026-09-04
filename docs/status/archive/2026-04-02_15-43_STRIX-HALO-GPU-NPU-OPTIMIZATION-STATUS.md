# Strix Halo GPU/NPU Optimization — Comprehensive Status Report

**Date:** 2026-04-02 15:43
**Hardware:** GMKtec EVO-X2 — AMD Ryzen AI Max+ 395 (Strix Halo, gfx1151, RDNA 3.5)
**OS:** NixOS 26.05.20260328.b63fe7f (Yarara), kernel 6.19.10
**Source:** [Framework-strix-halo-llm-setup](https://github.com/Gygeek/Framework-strix-halo-llm-setup) + community repos

---

## System State (Live Audit)

| Metric                              | Value                                                                                               |
| ----------------------------------- | --------------------------------------------------------------------------------------------------- |
| RAM installed                       | 128 GB                                                                                              |
| RAM visible to OS                   | 62 GB (64GB reserved for GPU VRAM by BIOS)                                                          |
| GPU VRAM                            | 64 GB (dedicated, BIOS-allocated)                                                                   |
| GPU GTT (dynamic compute)           | 31 GB                                                                                               |
| GFX architecture                    | gfx1151 (RDNA 3.5), 40 CUs, 80 SIMDs                                                                |
| Kernel params (current, pre-switch) | `amdgpu.ppfeaturemask=0xfffd7fff amdgpu.deepfl=1 amd_pstate=guided amdgpu.ttm.pages_limit=29360128` |
| IOMMU                               | Currently ON (amd_iommu=off NOT yet applied — requires rebuild+reboot)                              |
| `lars` groups                       | users wheel audio video docker input (**missing `render`** — pending rebuild)                       |
| NPU module (`amdxdna`)              | Loaded in kernel, but `hardware.amd-npu.enable` was `false` (now `true` in config)                  |
| KFD/DRM udev rules                  | NOT present on disk yet (pending rebuild)                                                           |
| Ollama                              | Vulkan backend (`ollama-vulkan`)                                                                    |
| llama.cpp                           | Installed (generic build, no rocWMMA)                                                               |
| HSA_OVERRIDE_GFX_VERSION            | Was `gfx1100` (WRONG for gfx1151), now removed in config                                            |

---

## A) FULLY DONE (Committed in `a354b23`)

| # | Change                                           | File                   | Status    |
| - | ------------------------------------------------ | ---------------------- | --------- |
| 1 | Added `"render"` group to user `lars`            | `configuration.nix:76` | Committed |
| 2 | Removed wrong `HSA_OVERRIDE_GFX_VERSION=gfx1100` | `ai-stack.nix:37`      | Committed |
| 3 | Added `amd_iommu=off` kernel parameter           | `boot.nix:25`          | Committed |
| 4 | Added KFD/DRM udev rules (0666 for compute)      | `amd-gpu.nix:34-38`    | Committed |
| 5 | Enabled NPU module (`false` → `true`)            | `amd-npu.nix:7`        | Committed |
| 6 | `nix flake check --no-build` passes clean        | —                      | Verified  |

**All changes are committed. `git status` is clean. Requires `just switch` + reboot to take effect.**

---

## B) PARTIALLY DONE (Research Complete, Implementation Pending)

| # | Item                              | What's Done                                                                         | What's Missing                                                 |
| - | --------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| 1 | **GTT memory optimization**       | Research says add `amdgpu.gttsize=131072` + bump `ttm.pages_limit=31457280`         | Not yet added to `boot.nix` — would give full 128GB GTT access |
| 2 | **ROCm math libraries**           | Research says add `rocblas`, `hipblaslt` to `extraPackages`                         | Not added to `amd-gpu.nix`                                     |
| 3 | **GPU performance DPM**           | Research says add udev rule `ATTR{device/power_dpm_force_performance_level}="high"` | Not added to `amd-gpu.nix` udev rules                          |
| 4 | **System-wide memlock unlimited** | NPU module sets it for NPU only                                                     | Need `security.pam.loginLimits` for system-wide ROCm           |
| 5 | **Ollama ROCm backend**           | Research says switch `ollama-vulkan` → `ollama-rocm`                                | Not changed in `ai-stack.nix`                                  |
| 6 | **ROCm monitoring tools**         | Research says add `rocm-smi`, `nvtopPackages.amd`, `rocminfo`                       | Not added to packages                                          |

---

## C) NOT STARTED

| #  | Item                                     | Priority | Impact                                                                                                                            |
| -- | ---------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 1  | **llama.cpp with rocWMMA build flags**   | Critical | 2x prompt processing speed. Requires custom Nix derivation or overlay with `GGML_HIP_ROCWMMA_FATTN=ON` and `GGML_HIP_MMQ_MFMA=ON` |
| 2  | **PyTorch with ROCm on NixOS**           | High     | Non-trivial on NixOS. Options: pip venv with ROCm wheel, distrobox container, or custom derivation                                |
| 3  | **`boot.extraModprobeConfig` for TTM**   | High     | `options amdgpu gttsize=122800` + `options ttm pages_limit=31457280 page_pool_size=31457280`                                      |
| 4  | **CPU power governor tuning**            | Medium   | `amd_pstate=active` vs `guided`, EPP settings, boost control                                                                      |
| 5  | **VM sysctl tuning for AI workloads**    | Medium   | `vm.swappiness`, `vm.dirty_ratio`, `vm.min_free_kbytes`, transparent hugepages                                                    |
| 6  | **NVMe/BTRFS IO scheduler**              | Low      | `none` scheduler for NVMe, BTRFS commit interval tuning                                                                           |
| 7  | **Boot performance analysis**            | Low      | `systemd-analyze critical-chain`, `systemd-analyze blame`                                                                         |
| 8  | **Distrobox/OCI container for ROCm env** | Medium   | kyuz0 pre-built containers with rocWMMA support                                                                                   |
| 9  | **GPU crash investigation**              | High     | `dmesg` showed gfx ring timeout from kitty on Mar 31 — device wedged but recovered                                                |
| 10 | **FastFlowLM / NPU practical usage**     | Low      | NPU only useful for tiny models (<4B), not worth major investment for LLM                                                         |

---

## D) TOTALLY FUCKED UP / CONCERNS

| # | Issue                              | Severity | Details                                                                                                                                                                                   |
| - | ---------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **OS only sees 62GB of 128GB**     | Critical | 64GB locked as VRAM by BIOS. This is intentional per user but limits OS memory. Reference repo recommends 512MB UMA + GTT for more usable memory                                          |
| 2 | **GTT only 31GB**                  | High     | With `ttm.pages_limit=29360128` (~112GB theoretical), actual GTT is only 31GB. The `amdgpu.gttsize` kernel param is NOT set, which limits GTT allocation                                  |
| 3 | **GPU gfx ring timeout crash**     | High     | `dmesg` shows `ring gfx_0.0.0 timeout` from kitty process on Mar 31. Device wedged and recovered. The wrong `HSA_OVERRIDE_GFX_VERSION=gfx1100` (now fixed in config) may have contributed |
| 4 | **`render` group not applied yet** | Medium   | Config committed but `just switch` not yet run. `lars` still missing render group on live system                                                                                          |
| 5 | **IOMMU still active**             | Low      | `amd_iommu=off` committed but not yet rebooted. IOMMU still showing in `dmesg`                                                                                                            |

---

## E) WHAT WE SHOULD IMPROVE

### Infrastructure

1. **Add `amdgpu.gttsize` kernel param** — Without it, GTT is capped at 31GB regardless of `ttm.pages_limit`. This is the single biggest missing piece.
2. **Build custom llama.cpp with rocWMMA** — The nixpkgs `llama-cpp` doesn't include `GGML_HIP_ROCWMMA_FATTN=ON`. This is the #1 performance win for LLM inference on Strix Halo.
3. **Add ROCm math libraries** — `rocblas` and `hipblaslt` are required for `ROCBLAS_USE_HIPBLASLT=1` to actually work.
4. **System-wide memlock** — ROCm needs `unlimited` memlock for large GTT allocations. NPU module only covers NPU.
5. **Investigate GPU crash** — The kitty gfx ring timeout needs root cause analysis. Could be driver bug, memory pressure, or wrong GFX version.

### Monitoring

6. **Add `nvtopPackages.amd`** — htop-like GPU monitoring, essential for watching VRAM/GTT usage during inference.
7. **Add `rocmPackages.rocm-smi`** — Detailed GPU stats, clock speeds, memory usage.
8. **Benchmark baseline** — Run `llama-bench` with current setup BEFORE making rocWMMA changes, to measure actual improvement.

### Architecture Decisions

9. **BIOS UMA frame buffer size** — Currently 64GB dedicated. Consider 512MB + 115GB GTT (reference approach) for more flexible allocation. Tradeoff: dedicated VRAM has lower latency, GTT is dynamic.
10. **Ollama backend** — Vulkan vs ROCm. ROCm wins prompt processing with hipBLASLt, Vulkan wins some token gen benchmarks. Test both on this hardware.

---

## F) TOP 25 THINGS TO DO NEXT

| #  | Task                                                          | File/Action                     | Priority | Effort                |
| -- | ------------------------------------------------------------- | ------------------------------- | -------- | --------------------- |
| 1  | Run `just switch` + reboot to apply committed changes         | CLI                             | P0       | 5 min                 |
| 2  | Verify `render` group applied after reboot                    | `id lars`                       | P0       | 1 min                 |
| 3  | Verify `amd_iommu=off` in `/proc/cmdline` after reboot        | CLI                             | P0       | 1 min                 |
| 4  | Verify KFD/DRM udev rules active                              | `ls /etc/udev/rules.d/`         | P0       | 1 min                 |
| 5  | Verify NPU module loaded with XRT                             | `lsmod \| grep xdna`            | P0       | 2 min                 |
| 6  | Add `amdgpu.gttsize=131072` to kernel params                  | `boot.nix`                      | P1       | 5 min                 |
| 7  | Bump `ttm.pages_limit` from `29360128` to `31457280`          | `boot.nix`                      | P1       | 2 min                 |
| 8  | Add `boot.extraModprobeConfig` for TTM pool                   | `ai-stack.nix` or new file      | P1       | 5 min                 |
| 9  | Add `rocblas` + `hipblaslt` to `extraPackages`                | `amd-gpu.nix`                   | P1       | 5 min                 |
| 10 | Add GPU DPM `high` udev rule                                  | `amd-gpu.nix`                   | P1       | 3 min                 |
| 11 | Add system-wide `security.pam.loginLimits` for memlock        | new file or `configuration.nix` | P1       | 5 min                 |
| 12 | Run `llama-bench` baseline BEFORE rocWMMA changes             | CLI                             | P1       | 15 min                |
| 13 | Create custom llama.cpp derivation with rocWMMA flags         | new nix derivation              | P2       | 1-2 hrs               |
| 14 | Switch Ollama to `ollama-rocm`                                | `ai-stack.nix`                  | P2       | 5 min                 |
| 15 | Add `nvtopPackages.amd` + `rocm-smi` + `rocminfo` to packages | `amd-gpu.nix` / `ai-stack.nix`  | P2       | 5 min                 |
| 16 | Investigate GPU gfx ring timeout crash from Mar 31            | `dmesg`, kernel logs            | P2       | 30 min                |
| 17 | Run `llama-bench` AFTER rocWMMA build to compare              | CLI                             | P2       | 15 min                |
| 18 | Test 70B model with `-ngl 99 --no-mmap`                       | CLI                             | P2       | 20 min                |
| 19 | Consider `amd_pstate=active` vs `guided` benchmarking         | `boot.nix`                      | P3       | 30 min                |
| 20 | Tune VM sysctls for AI workloads (swappiness, dirty_ratio)    | new file                        | P3       | 15 min                |
| 21 | Set up PyTorch ROCm environment (distrobox or pip venv)       | `ai-stack.nix`                  | P3       | 1 hr                  |
| 22 | Run `systemd-analyze critical-chain` for boot optimization    | CLI                             | P3       | 15 min                |
| 23 | Test Ollama Vulkan vs ROCm benchmark comparison               | CLI                             | P3       | 30 min                |
| 24 | Evaluate BIOS UMA change (512MB + GTT vs 64GB dedicated)      | BIOS                            | P4       | Requires reboot cycle |
| 25 | Set up Distrobox with kyuz0 ROCm+rocWMMA container            | CLI                             | P4       | 30 min                |

---

## G) TOP QUESTION I CANNOT ANSWER MYSELF

**Why is GTT only 31GB when `ttm.pages_limit=29360128` should theoretically allow ~112GB?**

The kernel param `amdgpu.ttm.pages_limit=29360128` is present in `/proc/cmdline`, yet `cat /sys/class/drm/card*/device/mem_info_gtt_total` returns only 33518612480 bytes (~31GB). The reference repo uses `amdgpu.gttsize=117760` (in MB) alongside `ttm.pages_limit`. We are missing the `amdgpu.gttsize` parameter entirely — it's possible that `ttm.pages_limit` alone is insufficient and `gttsize` is the actual controlling parameter. This needs verification after adding `amdgpu.gttsize=131072` (or `117760` for 115GB) to kernel params and rebooting.

---

## Files Modified This Session

| File                                                                     | Change                             | Committed       |
| ------------------------------------------------------------------------ | ---------------------------------- | --------------- |
| `platforms/nixos/system/configuration.nix:76`                            | Added `"render"` to extraGroups    | Yes (`a354b23`) |
| `platforms/nixos/system/boot.nix:25`                                     | Added `amd_iommu=off`              | Yes (`a354b23`) |
| `platforms/nixos/hardware/amd-gpu.nix:34-38`                             | Added KFD/DRM udev rules           | Yes (`a354b23`) |
| `platforms/nixos/hardware/amd-npu.nix:7`                                 | `enable = false` → `true`          | Yes (`a354b23`) |
| `platforms/nixos/desktop/ai-stack.nix:37`                                | Removed `HSA_OVERRIDE_GFX_VERSION` | Yes (`a354b23`) |
| `docs/status/2026-04-02_15-43_STRIX-HALO-GPU-NPU-OPTIMIZATION-STATUS.md` | This report                        | Pending         |

## References

- [Gygeek/Framework-strix-halo-llm-setup](https://github.com/Gygeek/Framework-strix-halo-llm-setup) — Reference setup guide
- [pablo-ross/strix-halo-gmktec-evo-x2](https://github.com/pablo-ross/strix-halo-gmktec-evo-x2) — Benchmarks + roadmap
- [kyuz0/amd-strix-halo-gfx1151-toolboxes](https://github.com/kyuz0/amd-strix-halo-gfx1151-toolboxes) — Pre-built ROCm+rocWMMA containers
