# Deep Research: AMD Ryzen AI Max+ 395 (Strix Halo) + Linux 7

**Date:** 2026-05-11
**Purpose:** Understand the SoC/GPU/CPU architecture, Linux 7 features, and GPU memory protection options to prevent niri starvation by AI workloads

---

## 1. SoC Architecture: AMD Ryzen AI Max+ 395 "Strix Halo"

### CPU

| Spec | Value |
|------|-------|
| **Architecture** | Zen 5 (cpu family 26) |
| **Cores/Threads** | 16C/32T |
| **Base/Boost** | 625 MHz / 5,187 MHz |
| **L3 Cache** | 64 MiB (2 × 32 MiB CCDs) |
| **TDP** | 45-120W configurable |
| **Instruction Set** | AVX-512, BFloat16 |
| **NUMA** | Single node |

### GPU — Radeon 8060S (RDNA 3.5)

| Spec | Value | Source |
|------|-------|--------|
| **Architecture** | RDNA 3.5 (gfx1105) | KFD topology: `gfx_target_version 110501` |
| **Compute Units** | 80 CU (4 arrays × 10 CU/array) | KFD: `simd_count 80, array_count 4, cu_per_simd_array 10` |
| **SIMD per CU** | 2 | KFD: `simd_per_cu 2` |
| **PCI Device ID** | `1002:1586` (subsystem `2014:801D`) | sysfs uevent |
| **VRAM (carveout)** | **64 GiB** (68,719,476,736 bytes) | `mem_info_vram_total` |
| **Visible VRAM** | **64 GiB** (same as VRAM — full aperture) | `mem_info_vis_vram_total` |
| **GTT (system RAM mapped to GPU)** | **32 GiB** (34,359,738,368 bytes) | `mem_info_gtt_total` |
| **GPU Busy** | 100% (wedged state) | `gpu_busy_percent` |
| **DPM State** | performance | `power_dpm_state` |

### Critical Memory Layout

```
Total System RAM:      62 GiB (65,465,708 KiB)
GPU VRAM Carveout:     64 GiB (from 128 GiB LPDDR5X package)
GTT (GTT Total):       32 GiB (system RAM accessible by GPU)

Actual usage (current wedged state):
  VRAM used:           57 GiB (61,269,889,024 bytes)  ← Ollama models
  GTT used:            60 MB  (63,021,056 bytes)
  Visible VRAM used:   57 GiB (same as VRAM)
  Preemptible:         527 MiB (566,493,184 bytes)
```

**Key insight:** This is an **APU** (integrated GPU). The 128 GiB LPDDR5X is shared between CPU and GPU. The BIOS carves out 64 GiB for VRAM, leaving ~64 GiB for the CPU. GTT allows the GPU to access an additional 32 GiB of system RAM. When Ollama loads two model runners at 0.45 fraction each (0.9 × 64 GiB = ~58 GiB), it leaves only ~6 GiB for the compositor, Wayland buffers, and display output — and that's before ComfyUI or other GPU users.

### NPU — AMD XDNA 2 (AIE2p)

- Integrated NPU for AI inference
- Supported via `nix-amd-npu` flake input
- Linux driver upstreamed for kernel 6.12+
- **SR-IOV support coming in Linux 7.2** for next-gen AIE4 NPUs (Phoronix, May 7 2026)
- Not used by Ollama — Ollama uses the iGPU (RDNA 3.5) for inference

---

## 2. Linux Kernel Status

### Current System: Linux 7.0.1

```
$ uname -r
7.0.1
```

### Kernel Release Timeline

| Version | Status | Date |
|---------|--------|------|
| 6.12.87 | Longterm (LTS) | Active maintenance |
| 6.18.29 | Longterm | Active maintenance |
| 6.19.14 | EOL | End of life |
| **7.0.6** | **Stable** | **2026-05-11** |
| 7.1-rc3 | Mainline (development) | 2026-05-10 |
| 7.2 | Merge window June 2026 | Upcoming |

### Linux 7.0 Highlights (from Phoronix coverage)

- Major version bump from 6.x → 7.0 (significant architectural changes)
- Continued AMD GPU support improvements
- `amdgpu` driver maturity for RDNA 3.5 (gfx1105)

### Linux 7.1 Features (from Phoronix "Linux 7.1 Features" article)

- **New NTFS driver** — improved NTFS support
- **New Intel + AMD hardware support**
- **Performance optimizations and modernization**
- Phase out of i486 CPU support (starting point)
- Networking subsystem got ~1/3 of all patches

### Linux 7.2 Upcoming (from Phoronix articles)

| Feature | Relevance |
|---------|-----------|
| **AMDGPU DC Power Module** | Better power management aligned with Windows behavior — may help with GPU scheduling fairness |
| **SR-IOV for Ryzen AI NPUs** | Virtual NPU partitioning — doesn't help with iGPU VRAM but good for NPU workloads |
| **RadeonSI code reorganization** | Multimedia-only driver builds — cleaner separation of compute vs display |
| **dm-inlinecrypt** | Inline block device encryption |
| **Realtek RTL8159 10GbE** | 10GbE USB Ethernet support |

### Dirty Frag Vulnerability (2026-05-07)

Critical local privilege escalation affecting ALL Linux distributions. Published before patches were ready. **Action: Ensure kernel is updated to latest 7.0.x patch level.**

---

## 3. amdgpu Memory Management on APUs

### How VRAM Works on Strix Halo

The Ryzen AI Max+ 395 is unique: it has **128 GiB LPDDR5X** shared between CPU and GPU. The firmware configures a **64 GiB VRAM carveout** visible to the GPU as dedicated VRAM. This is NOT discrete GPU VRAM — it's unified memory.

**TTM (Translation Table Manager)** manages three memory domains:

| Domain | Description | Size on evo-x2 |
|--------|-------------|---------------|
| **VRAM** | Dedicated GPU-local memory (LPDDR5X carveout) | 64 GiB |
| **GTT** (Graphics Translation Table) | System RAM mapped into GPU address space | 32 GiB |
| **System** | CPU-only system RAM | ~32 GiB (62 GiB total - 32 GiB GTT) |

### sysfs Memory Info

```
/sys/class/drm/card1/device/
├── mem_info_vram_total       = 68,719,476,736  (64 GiB)
├── mem_info_vram_used        = 61,269,889,024  (57 GiB used)
├── mem_info_vis_vram_total   = 68,719,476,736  (64 GiB, full aperture)
├── mem_info_vis_vram_used    = 61,269,889,024  (57 GiB used)
├── mem_info_gtt_total        = 34,359,738,368  (32 GiB)
├── mem_info_gtt_used         = 63,021,056      (60 MiB used)
└── mem_info_preempt_used     = 566,493,184     (527 MiB)
```

### GTT Limit Configuration

The 32 GiB GTT limit was raised from the default in commit `62d5de0f`:

```nix
# platforms/nixos/hardware/amd-gpu.nix
"amdgpu.gttsize" = "112";  # 112 GiB (raised from 32 GiB)
```

This allows the GPU to address more system RAM for large model loads, but doesn't increase VRAM.

### Per-Process VRAM Limits

**There is NO per-process or per-cgroup VRAM limit mechanism on AMD GPUs in Linux 7.0.** This is the core problem.

- NVIDIA has `nvidia-cgroup` for container GPU limits
- AMD has **no equivalent** — `amdgpu` doesn't enforce per-process VRAM budgets
- `PYTORCH_CUDA_ALLOC_CONF=per_process_memory_fraction:0.45` is a **user-space hint** that PyTorch/Mesa respects voluntarily — but the driver cannot enforce it
- Ollama's memory fraction is also user-space — the driver will allow allocations beyond the "hint" during model loading

---

## 4. GPU Scheduling / Priority on AMD iGPU

### The Fundamental Problem

AMD APUs **do not have MPS (Multi-Process Service)** equivalent. NVIDIA MPS allows time-slicing GPU compute between processes with priority. AMD has no such mechanism:

| Feature | NVIDIA | AMD (RDNA 3.5) |
|---------|--------|-----------------|
| Per-process VRAM limits | ✅ nvidia-cgroup | ❌ Not available |
| Compute priority (MPS) | ✅ CUDA MPS | ❌ No equivalent |
| GPU time-slicing | ✅ Time-slice + MPS | ❌ Cooperative only |
| cgroup GPU controller | ❌ Not merged | ❌ Not available |
| DRM scheduler priority | ✅ Some support | ⚠️ `drm/sched` exists but no user-space control |

### What IS Available

1. **`drm/sched` (DRM Scheduler)** — The kernel has a GPU job scheduler, but it manages command submission ordering, not VRAM allocation. It cannot prevent one process from consuming all VRAM.

2. **`amdgpu.gpu_recovery=1`** — Already configured in boot.nix. Recovers from GPU hangs via driver reset.

3. **`systemd OOMScoreAdjust`** — Controls which process the kernel OOM killer targets first. This is about **system RAM**, not VRAM. But it helps when VRAM exhaustion cascades to system OOM.

4. **`systemd MemoryMax`** — Controls system RAM per service. Doesn't limit VRAM.

5. **`earlyoom --prefer/--avoid`** — Userspace OOM killer that prefers killing Ollama over niri. Again, system RAM only.

### cgroup v2 GPU Controller Status

**No GPU memory cgroup controller exists in Linux 7.0 or 7.1.** There have been discussions on LKML about a `memory.gpu` controller, but nothing has been merged. The DRM subsystem maintains its own memory management via TTM.

---

## 5. Ollama GPU Memory Controls

### Environment Variables (from Sourcegraph code analysis)

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_MAX_LOADED_MODELS` | Auto (based on VRAM) | **Maximum number of models loaded simultaneously** |
| `OLLAMA_NUM_PARALLEL` | 1 | Parallel request processing per runner |
| `OLLAMA_GPU_OVERHEAD` | 0 | Reserve extra VRAM (bytes) beyond model size |
| `OLLAMA_SCHED_SPREAD` | false | Spread models across available GPUs |
| `OLLAMA_FLASH_ATTENTION` | false | Enable flash attention (reduces VRAM) |
| `OLLAMA_KV_CACHE_TYPE` | "f16" | KV cache quantization ("q8_0" uses less VRAM) |
| `OLLAMA_KEEP_ALIVE` | "5m" | How long to keep models loaded after last request |

### How Ollama Decides Runner Count

Ollama's scheduler (`ollama/scheduler.go`) decides how many GPU runners to create based on:
1. Available VRAM reported by the driver
2. Model size (weights + KV cache)
3. `OLLAMA_MAX_LOADED_MODELS` (if set)
4. `OLLAMA_NUM_PARALLEL` (affects KV cache sizing)

**When `OLLAMA_MAX_LOADED_MODELS` is not set**, Ollama will load as many models as fit in VRAM. This is what caused the dual-runner incident: two models fit in 64 GiB, but each runner's `per_process_memory_fraction:0.45` = 0.9 × 64 = 57.6 GiB, leaving only ~6 GiB for niri.

### The `OLLAMA_MAX_LOADED_MODELS=1` Fix

Setting `OLLAMA_MAX_LOADED_MODELS=1` is the **single most effective protection**:

- Only one model loaded at a time
- Second request queues until first model is evicted (or uses CPU)
- Guaranteed VRAM headroom for niri
- Trade-off: no parallel inference across different models

### Current Configuration (ai-stack.nix)

```nix
OLLAMA_FLASH_ATTENTION = "1";
OLLAMA_NUM_PARALLEL = "2";
OLLAMA_KV_CACHE_TYPE = "q8_0";
OLLAMA_KEEP_ALIVE = "1h";
PYTORCH_CUDA_ALLOC_CONF = "per_process_memory_fraction:0.45";
```

**Missing:**
- `OLLAMA_MAX_LOADED_MODELS = "1"` ← **CRITICAL — not set**
- `OLLAMA_GPU_OVERHEAD` ← not set (should reserve headroom)

---

## 6. DRM Healthcheck / GPU Hang Recovery

### Current Architecture

```
niri-drm-healthcheck.timer (every 60s)
    → niri-drm-healthcheck.service (oneshot)
        → If niri is running AND has DeviceMissing errors
            → SIGKILL niri (restart loop begins)
    → If niri is NOT running for >5 min
        → Trigger gpu-recovery.service
            → Stop niri → unbind amdgpu → rebind → start niri
```

### Problem Analysis

The healthcheck **SIGKILLs niri** when it detects DRM errors, but:
1. It doesn't detect "GPU is truly wedged" vs "transient glitch"
2. It creates a **crash loop** — niri restarts into the same broken state 638 times
3. The `gpu-recovery.service` (unbind/rebind) is only triggered when niri hasn't been running for >5 minutes, but the healthcheck keeps restarting it

### Improved Architecture

```
niri-drm-healthcheck.timer (every 60s)
    → Count consecutive DeviceMissing errors
    → If < 3 errors → do nothing (transient)
    → If 3-5 errors → trigger gpu-recovery (unbind/rebind)
    → If > 5 errors OR rebind fails → trigger SYSTEM REBOOT
```

---

## 7. Dirty Frag Vulnerability

Published 2026-05-07 — local privilege escalation affecting ALL Linux distributions. Embargo broken early, patches not yet available in all distros.

**Action for evo-x2:**
- Ensure kernel 7.0.6 or later is running (7.0.1 may be vulnerable)
- Check: `uname -r` → currently 7.0.1
- Update when patched kernel lands in nixpkgs unstable

---

## 8. Actionable Recommendations

### Tier 1: Immediate (prevent re-occurrence)

| # | Action | File | Effort |
|---|--------|------|--------|
| 1 | Set `OLLAMA_MAX_LOADED_MODELS = "1"` | `modules/nixos/services/ai-stack.nix` | 1 min |
| 2 | Set `OLLAMA_GPU_OVERHEAD = "8589934592"` (8 GiB reserve) | `modules/nixos/services/ai-stack.nix` | 1 min |
| 3 | Raise niri `OOMScoreAdjust` to `-1000` | `modules/nixos/services/niri-config.nix` | 1 min |
| 4 | Add `OOMScoreAdjust = 500` to Ollama | `modules/nixos/services/ai-stack.nix` | 1 min |

### Tier 2: DRM Healthcheck Fix

| # | Action | File | Effort |
|---|--------|------|--------|
| 5 | Rewrite healthcheck: count consecutive errors, don't SIGKILL | `scripts/niri-drm-healthcheck.sh` | 30 min |
| 6 | Add auto-reboot on unrecoverable GPU state | `scripts/gpu-recovery.sh` | 15 min |

### Tier 3: Kernel / System

| # | Action | Effort |
|---|--------|--------|
| 7 | Update kernel to 7.0.6+ (Dirty Frag fix) | `nixpkgs` bump |
| 8 | Consider `amdgpu.gttsize` reduction (currently 112 GiB, maybe 64 GiB to limit GTT abuse) | 5 min |

### Architecture Reality

**There is no kernel-level mechanism to protect niri's GPU memory from AI workloads on AMD APUs.** The protection must come from userspace:
- `OLLAMA_MAX_LOADED_MODELS=1` (prevents dual-runner)
- `OLLAMA_GPU_OVERHEAD=8G` (reserves headroom)
- `per_process_memory_fraction:0.45` (existing, limits single runner)
- OOM priority (`OOMScoreAdjust`)
- `earlyoom` prefer/avoid lists

These layers together provide defense-in-depth. No single layer is sufficient.
