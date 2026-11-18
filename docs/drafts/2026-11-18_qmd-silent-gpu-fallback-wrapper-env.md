# Draft issue — tobi/qmd

**Proposed title:** GPU fallback on Linux is undiagnosable: `NoBinaryFoundError` without a reason, and `qmd doctor` says "install/configure Vulkan" while the shipped Vulkan backend itself is broken

**Repro status:** verified-before-filing gates run 2026-11-18; all quotes below captured live this session against qmd 2.8.3 (flake install) on the affected machine.

---

> [!NOTE]
> This filing was drafted by GLM-5.3 via Crush from an AI-run investigation, not at my request.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

**TL;DR:** When the bundled Vulkan backend fails to load on Linux, qmd falls back to CPU with a warning that names no cause, and `qmd doctor` advises "install/configure Metal, CUDA, or Vulkan" on a machine where Vulkan is installed and working system-wide — the bundled backend package is what fails to register. Ask: report the backend-load failure reason in doctor and in the fallback warning, and fix the flake wrapper's environment, which independently breaks Vulkan and newer-glibc binaries.

## Environment

- qmd 2.8.3 via the flake, NixOS, Linux x86_64; AMD Radeon 8060S iGPU (RADV, working via `vulkaninfo`)
- bundled node-llama-cpp 3.20.0 — the backend defect itself is upstream: `libggml-vulkan.so` lacks the `ggml_backend_score` export the ggml loader dlsyms (filed at withcatai/node-llama-cpp, same missing export confirmed in 3.22.3)

## Problem

Three layers stack so the user can neither see nor fix the failure:

1. **The fallback warning names no cause.** `QMD_LLAMA_GPU=vulkan qmd vsearch` prints:

   ```
   QMD Warning: GPU init failed for QMD_LLAMA_GPU=vulkan (NoBinaryFoundError), falling back to CPU.
   ```

   `NoBinaryFoundError` is node-llama-cpp's "no usable binary" — but nothing says WHY the binary was rejected. In default `auto` mode the failed backend is not named at all; `qmd doctor` reports only:

   ```
   ⚠ device probe: running on CPU (16 math cores). Next: install/configure Metal, CUDA, or Vulkan for faster embeddings, or set QMD_FORCE_CPU=1 to make CPU mode explicit
   ```

   On this machine that advice is unactionable: Vulkan is installed and functioning system-wide — it is the `@node-llama-cpp/linux-x64-vulkan` package that fails to register. The doctor sends the user to reinstall the thing that is already installed.

2. **The underlying reason is compiled out.** The bundled ggml is a release build, so the plugin loader's diagnostics are gated behind `NDEBUG` (`silent = true` in `ggml-backend-reg.cpp`, `ggml_backend_load_all_from_path`). With `GGML_LOG_LEVEL=info` the vulkan load produces zero loader output. The actual defect (missing `ggml_backend_score` export in `libggml-vulkan.so`, present in every CPU plugin) is invisible at every log level — only the shim/probe work surfaced it.

3. **The flake wrapper's environment breaks the backend independently.** The wrapper sets:

   ```bash
   export LD_LIBRARY_PATH='<sqlite>/lib:<glibc-2.42>/lib:<gcc-15.2.0-lib>/lib'
   ```

   No `libvulkan.so.1` anywhere — the vulkan plugin's dependency chain cannot resolve even with a healthy artifact (adding a system vulkan-loader + RADV ICD alone still ends in `NoBinaryFoundError`; live-verified). The injected glibc-2.42 additionally breaks newer-glibc PATH binaries qmd spawns — `qmd doctor` itself trips over it on this host:

   ```
   uname: /nix/store/...-glibc-2.42-47/lib/libc.so.6: version `GLIBC_2.43' not found (required by uname)
   ```

   The MCP path is quieter still: the wrapper sets `GGML_BACKEND_SILENT=1` and `LLAMA_LOG_LEVEL=error` for `qmd mcp`, and the MCP is how editor/agent integrations run qmd — those sessions get no signal at all.

## Ask

- `qmd doctor`: attempt the backend load and report WHY the GPU is unused ("vulkan backend failed: <error>") instead of generic install advice.
- Include the failing backend and its reason in the auto-mode CPU fallback warning.
- Wrapper: add the vulkan loader to `LD_LIBRARY_PATH`, and stop injecting an older glibc into the child environment (or pin a coherent set) — the `uname` failure above comes from qmd's own wrapper env.

Related: #739 (backend selection order on non-NVIDIA machines), #957 (embedding-path CPU fallback asymmetry). The prebuilt defect is tracked upstream at withcatai/node-llama-cpp.

💘 Generated with Crush
