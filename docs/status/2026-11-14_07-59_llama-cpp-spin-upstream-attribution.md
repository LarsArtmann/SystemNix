# Status report — llama.cpp mid-load CPU-spin: upstream attribution (no bisect needed)

**Session window:** 2026-11-14 ~07:30-08:00 CET, task 000001a1d8cbc255e490e7655eec00000000 (item 3 of the ai-stack batch).
**Ask:** "Bisect the llama.cpp 0.3.0 mid-load CPU-spin upstream (ROCm runtime / kernel / GPU-state — upstream of llama.cpp)" — the gate for the paperless RAG item.

## Verdict

The bisect is ALREADY DONE upstream — our spin class matches an open, multi-party, cross-GPU upstream issue, and the layer attribution is established by reproducer evidence there. No local bisect adds information until the confirming live soak runs (owner-gated, quiet-IO window only).

## Upstream match

**Primary: ggml-org/llama.cpp #19482** (open, labels bug+RoCM, opened Feb 2026) — "larger model loading on ROCm hangs": 1-2 CPU cores pegged 94-99% in a busy-spin, `read_bytes` frozen, spin frames inside `libhsa-runtime64`/`libamdhip64` under `ggml_backend_cuda_buffer_set_tensor → load_all_data`. Confirmed on Strix Halo gfx1151 (multiple 128 GB users, ROCm 7.2.0/7.2.2/7.2.4) AND discrete gfx1100/gfx1201; IOMMU ruled out (`amd_iommu=off` identical). Exact fingerprint of our freeze-#5/#48 mid-load spin on the pinned 0.3.0 build.

**Secondary:** #29894 (Strix Halo gfx1151, HIP-only single-thread spin at init with `--load-mode mmap`; same model/flags fine via Vulkan RADV — the HIP path is the differentiator).

## Layer attribution (from the upstream evidence, not inference)

1. **ROCm/ROCr runtime — primary:** spin lives in HSA/HIP user-space; identical rocdb backtraces across GPUs; "the underlying ROCm userptr-registration pathology on large mappings is unchanged" across ROCm 7.2.4→7.14; a targeted llama.cpp fix PR (#25212, pinned staging buffers) was closed UNMERGED. Related ROCr-side spin: rocm-systems#12674 (AsyncEventsLoop busy-spin, fixes on main/10.1.0, not in 7.x releases).
2. **Kernel amdgpu/KFD — contributing:** instrumented Strix Halo report shows synchronized `svm_range_restore_work [amdgpu]` hogging CPU >10 ms + "SVM mapping failed, exceeds resident system memory limit" during the spin.
3. **llama.cpp — trigger only:** its HIP mmap/userptr registration of huge model buffers exercises the pathological path. NOT a llama.cpp regression 0.4.0-vs-0.3.0 in the backend sense — the load path is the trigger; the runtime is the pathology.

## Why the 0.4.0 bump broke us and how it ends

Our pinned nixpkgs rev ships llama.cpp 0.3.0 / ROCm 7.2.3 (live kernel 7.2.2); root nixpkgs now ships 0.9.0 / ROCm 7.2.4. No 0.4.0-0.9.x release note claims a HIP hang fix — what changed is llama.cpp's **`--load-mode auto` default** sidesteps the mmap-load path (per #19482 discussion), making the runtime pathology invisible on newer builds. Workarounds available on OUR 0.3.0 build TODAY: `--no-mmap`, `--direct-io`, or `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` (upstream-reported mitigations).

## Flip path (closes the input-drop watch row + re-enable gate)

1. Owner-gated quiet-window soak (existing row, `scripts/llama-rag-soak.sh`): A/B the pinned 0.3.0 build on the 23G chat model with default mmap (expect spin) vs `--no-mmap` (expect clean) — one run CONFIRMS the attribution locally. ~46G extra IO; quiet-IO window only, never mid-storm (the A/B was deliberately NOT run this session for that reason).
2. If confirmed: either flag `--no-mmap` on the llama-rag model-loading units (0.3.0-compatible, config-only) or unpin `nixpkgs-llama-rag` and re-soak on 0.9.0 with `--load-mode auto` (then drop the input per its watch row).

## Not done here (deliberate)

- The live A/B (above) — mid-storm IO discipline + root/owner gate.
- Vulkan-backend escape-hatch bench — already a separate owner-gated row (ai-stack Vulkan experiment); #29894 strengthens its premise (Vulkan unaffected).
