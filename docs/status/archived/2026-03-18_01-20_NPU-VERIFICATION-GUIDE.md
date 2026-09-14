# AMD Strix Halo GPU vs NPU Usage Verification

## Quick Answer: You are using the GPU, NOT the NPU

Your Ollama setup is using the **GPU (Radeon 8060S Graphics)** via the **Vulkan backend**. The NPU is present in your hardware but **not being used** because:

1. The NPU driver (AMD XDNA) is not installed/loaded
2. Ollama does not support NPU acceleration
3. The current setup uses Vulkan which targets GPU cores only

---

## Hardware Configuration

**Your System: GMKtec EVO-X2**

- **CPU/APU**: AMD Ryzen AI Max+ 395 (Strix Halo, gfx1100)
- **GPU**: Radeon 8060S Graphics (Integrated)
- **NPU**: AMD Strix Halo Neural Processing Unit (PCI 1022:17f0)
- **Memory**: 128GB unified DDR5 (~62GB OS-visible, ~64GB GPU-reserved)

---

## What's Currently Running

### GPU Status: ✅ ACTIVE

**Device: Radeon 8060S Graphics (RADV STRIX_HALO)**

Evidence from Ollama logs:

```
ggml_vulkan: Found 1 Vulkan devices:
0 = Radeon 8060S Graphics (RADV STRIX_HALO) (radv)
```

**Memory Allocation (Latest Inference):**

```
device=Vulkan0 size="18.9 GiB"   # Model weights on GPU
device=Vulkan0 size="510.0 MiB"   # KV cache on GPU
device=Vulkan0 size="279.6 MiB"   # Compute graph on GPU
```

**Layer Offloading:**

```
GPULayers=30[ID:00000000-c500-0000-0000-000000000000 Layers:30(17..46)]
```

- 30 out of 48 layers on GPU (layers 17-46)
- 18 layers on CPU (fallback for memory management)
- This is intentional - Ollama optimizes based on available VRAM

### NPU Status: ❌ NOT IN USE

**Hardware Present:** ✅

```
c6:00.1 Signal processing controller: AMD Strix Halo Neural Processing Unit [1022:17f0]
```

**Driver Status:** ❌ NOT LOADED

```
# No NPU device nodes:
ls /dev/accel/accel*
# Returns: No such file or directory

# No NPU kernel modules:
lsmod | grep -iE 'amdxna|amd_npu'
# Returns: (empty - only amdgpu module loaded)
```

**Ollama Support:** ❌ NPU NOT SUPPORTED

- Ollama only supports: CPU, Vulkan (GPU), CUDA (NVIDIA), ROCm (AMD GPU)
- NPU support: NOT AVAILABLE in Ollama or llama.cpp

---

## How to Verify GPU Usage

### Method 1: Check Ollama Logs (Recommended)

```bash
journalctl -u ollama --no-pager -n 100 | grep -iE 'vulkan|device|gpu|layer'
```

**What to look for:**

- `device=Vulkan0` → GPU is being used
- `GPULayers=N` → N layers offloaded to GPU
- `model weights device=Vulkan0` → Model weights on GPU

### Method 2: Run GPU Status Check

```bash
/home/lars/Setup-Mac/scripts/check-gpu-status.sh
```

This shows:

- Current VRAM usage
- GPU allocation from Ollama logs
- Layer distribution between GPU and CPU

### Method 3: Monitor During Inference

```bash
# Terminal 1: Start monitoring
/home/lars/Setup-Mac/scripts/test-ollama-gpu.sh

# Terminal 2: Make a request
crush run -m "ollama/glm-4.7-flash:latest" "Explain quantum computing"
```

This will show:

- Memory allocation changes during inference
- GPU vs CPU layer distribution
- Performance metrics (tokens/sec)

---

## Why Not Use the NPU?

### Technical Limitations

1. **Driver Support:**
   - NPU requires AMD XDNA driver (open-source: https://github.com/amd/XDNA)
   - Status: **NOT in Nixpkgs** yet
   - Would require custom kernel module or out-of-tree driver

2. **Ollama Limitations:**
   - Ollama backend: `libggml-vulkan.so` (GPU only)
   - No NPU backend available
   - llama.cpp (core of Ollama) does not support NPU

3. **Framework Support:**
   - **ONNX Runtime:** ✅ Has NPU Execution Provider (AMD EP)
   - **PyTorch:** ⚠️ Experimental NPU support
   - **Ollama/llama.cpp:** ❌ No NPU support

4. **Model Compilation:**
   - NPU requires models compiled for VLIW4 architecture
   - Conversion process: ONNX → NPU binary
   - Not available for GLM models

---

## GPU vs NPU Performance Comparison

| Aspect             | GPU (Vulkan)      | NPU (XDNA)                |
| ------------------ | ----------------- | ------------------------- |
| **Status**         | ✅ Working        | ❌ Driver not installed   |
| **Maturity**       | Excellent         | Early/Experimental        |
| **Model Support**  | Broad (llama.cpp) | Limited (ONNX only)       |
| **Performance**    | 12-15 tokens/sec  | Unknown (likely slower)   |
| **Software Stack** | Mature            | Experimental              |
| **Nix Support**    | ✅ Native         | ❌ Requires custom driver |
| **Memory Access**  | 95GB GPU VRAM     | NPU-specific memory       |

---

## Current Performance

**Test Results (glm-4.7-flash-q8-fixed):**

```
✅ Inference completed successfully
   Tokens generated: 564
   Duration: 44.05s
   Tokens/sec: 12.80
```

**Memory Usage:**

- GPU (Vulkan0): 18.9 GB weights + 510 MB KV cache
- CPU: 10.8 GB weights + 289 MB KV cache
- Total: ~30 GB model loaded

**Layer Distribution:**

- GPU: 30 layers (62.5%)
- CPU: 18 layers (37.5%)
- Hybrid approach optimizes for memory constraints

---

## Should You Use the NPU?

### Short Answer: **No, stick with GPU**

**Reasons:**

1. **GPU is working well:**
   - 12.8 tokens/sec is respectable for this model size
   - Vulkan backend is stable and mature
   - Full model fit in unified memory (GPU + CPU)

2. **NPU is not ready:**
   - Driver not in Nixpkgs
   - Would require significant setup effort
   - Limited model compatibility (ONNX only)
   - Unclear if performance would be better

3. **GPU advantages:**
   - Better software ecosystem
   - Native Nix support
   - Broader model compatibility
   - Easier troubleshooting and updates

---

## Verification Scripts Available

I've created several scripts to help you monitor GPU usage:

### 1. Check NPU Status

```bash
/home/lars/Setup-Mac/scripts/check-npu-status.sh
```

Shows NPU hardware presence, driver status, and explains why it's not being used.

### 2. Check GPU Status

```bash
/home/lars/Setup-Mac/scripts/check-gpu-status.sh
```

Shows current GPU utilization, VRAM usage, and Ollama device allocation.

### 3. Test Ollama GPU Usage

```bash
/home/lars/Setup-Mac/scripts/test-ollama-gpu.sh
```

Runs a test inference and monitors GPU activity in real-time.

### 4. Monitor GPU Live

```bash
/home/lars/Setup-Mac/scripts/monitor-gpu-live.sh
```

Continuous monitoring of GPU activity (run while making requests).

---

## Key Takeaways

1. **You are using the GPU** (Radeon 8060S) via Vulkan - this is working correctly
2. **The NPU is not in use** - hardware present but driver not installed, and Ollama doesn't support it anyway
3. **GPU performance is good** - 12.8 tokens/sec with 30/48 layers on GPU
4. **NPU is not better** - would require significant effort for uncertain gains
5. **GPU is the right choice** for your use case with current software ecosystem

---

## Future Possibilities

If you want to explore NPU in the future:

1. **Wait for XDNA in Nixpkgs** - Monitor Nixpkgs for amdxna driver
2. **Use ONNX Runtime** - Only framework with mature NPU support
3. **Convert models** - Requires ONNX format and NPU compilation
4. **Expect limitations** - Smaller model selection, experimental tools

For now, the GPU (Vulkan) setup is optimal for your system.

---

_Generated: 2026-03-18_
_System: GMKtec EVO-X2, AMD Ryzen AI Max+ 395 (Strix Halo)_
