# Draft — Syllo/nvtop issue — release request (APU per-process fixes unreleased)

**Title:** `Please cut a release: APU per-process GPU memory fixes from Jul/Sep are still unreleased (3.3.2 shows ~0 per-process memory on Strix Halo)`

**Verified against:** nvtop 3.3.2 (tag commit `76890233`, dated 2026-02-08) and master `71094a9` (2026-10-04), built and run live on an AMD Radeon 8060S Graphics (gfx1151 / Strix Halo, Ryzen AI Max+ 395), NixOS, kernel 7.2.10.

---

> [!NOTE]
> This filing was drafted by GLM-5.3-flash via Crush from an AI-run investigation, not at my request.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

TL;DR: three months of APU process-monitoring fixes are sitting on master while every distro package ships 3.3.2, where per-process GPU memory on APUs reads the 1 GiB BIOS carveout instead of GTT — i.e. ~0 for the processes people actually care about. Requesting a 3.4.0 (or any) release so downstream can pick it up. Master `71094a9` is built and verified working on Strix Halo below.

## Problem

On APUs, amdgpu reports process memory through `drm-memory-gtt` in fdinfo, while `drm-memory-vram` is only the small carveout. 3.3.2's per-process accounting reads vram only (`src/extract_gpuinfo_amdgpu.c` in 3.3.2 parses `drm-memory-vram` and sets `gpu_memory_usage` from it), so on a Strix Halo laptop the process list is effectively empty even while an 800 MiB embedding model sits in GTT. The bar is fine (16e0f1d8, 2025-12-13, vram+gtt sum for iGPUs — shipped in 3.3.2); the per-process fix postdates it:

| Commit | Date | What |
| --- | --- | --- |
| `d3f91f78` | 2026-07-13 | count GTT in per-process memory usage |
| `fbd4fe52` | 2026-09-19 | only count GTT on integrated GPUs (#492) |
| `eafc5ec7` | 2026-09-19 | read device architecture from the KFD topology |

Latest release is still 3.3.2 (2026-02-08), so nixpkgs, the Ubuntu PPA and Debian all ship the pre-`d3f91f78` behavior.

## Live numbers (same box, minutes apart)

llama.cpp ROCm server holding an 808752 KiB bge-m3 model in GTT (per `/proc/<pid>/fdinfo`):

| | nvtop 3.3.2 | nvtop master `71094a9` |
| --- | --- | --- |
| `gpu_mem_bytes_alloc` | 1,925,120 (~1.8 MiB) | 819,884,032 (~782 MiB) |

nsfw-classifier holding 4510756 KiB in GTT: 3.3.2 shows 8,138,752 (~7.8 MiB); master shows 4,627,083,264 (~4.3 GiB). Master's figures match fdinfo within the expected per-fd double-counting of shared buffers. Both builds run with `-DAMDGPU_SUPPORT=ON`; no issues found on this hardware.

## Ask

Cut a release so distros can move off 3.3.2 for APU users. Happy to test a release candidate on this box.

💘 Generated with Crush
