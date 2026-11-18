# Draft issue — withcatai/node-llama-cpp

**Proposed title:** linux-x64-vulkan prebuilt: `libggml-vulkan.so` missing the `ggml_backend_score` export — Vulkan backend never registers, silently (3.20.0 + 3.22.3)

**Repro status:** verified-before-filing gates run 2026-11-18; readelf A/B + live `QMD_LLAMA_GPU=vulkan` probe + GGML_LOG_LEVEL=info silence probe all fresh this session. 3.22.3 tarball probe recorded 2026-11-17 (see docs/todo/upstream.md qmd row).

---

> [!NOTE]
> This filing was drafted by GLM-5.3 via Crush from an AI-run investigation, not at my request.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

**TL;DR:** The `@node-llama-cpp/linux-x64-vulkan` package ships a `libggml-vulkan.so` that does not export `ggml_backend_score`, which the ggml plugin loader requires from every backend plugin — all CPU plugins export it, only the vulkan package is missing it, and in release builds every diagnostic around the failure is compiled out. Adding the missing one-line export to the shipped plugin makes Vulkan work end-to-end on this machine; please export it in the build.

## Environment

- node-llama-cpp 3.20.0 as bundled by qmd 2.8.3; `@node-llama-cpp/linux-x64-vulkan` 3.22.3 probed directly from the npm tarball (2026-11-17) — same missing export
- Linux x86_64, AMD Radeon 8060S iGPU (Strix Halo, gfx1150), RADV (mesa Vulkan)

## Problem

`getLlama({ gpu: "vulkan" })` fails with `NoBinaryFoundError` and `gpu: "auto"` silently lands on CPU. `libggml-vulkan.so` in the vulkan package has no `ggml_backend_score` anywhere in its dynamic symbols, while every CPU plugin in the same tree exports it:

```
$ readelf --dyn-syms libggml-vulkan.so | grep ggml_backend_score
(no output)

$ readelf --dyn-syms libggml-cpu-zen4.so | grep ' ggml_backend_score$'
575: 0000000000016a80  1295 FUNC    GLOBAL DEFAULT   14 ggml_backend_score
```

All 14 `libggml-cpu-*.so` variants export it (`GLOBAL FUNC`); none of the vulkan-package libraries reference it at all (`libggml.vulkan.b10361.so`, `libllama.vulkan.b10361.so`, `libggml-base.so`: zero hits).

The loader requires the symbol per plugin. From `ggml/src/ggml-backend-reg.cpp` at the bundled llama.cpp (b10361), `ggml_backend_load_best()` scores every `libggml-vulkan-*.so` candidate through it:

```cpp
auto score_fn = (ggml_backend_score_t) dl_get_sym(handle.get(), "ggml_backend_score");
...
} else {
    if (!silent) {
        GGML_LOG_INFO("%s: failed to find ggml_backend_score in %s\n", __func__, path_str(entry.path()).c_str());
    }
}
```

and `ggml_backend_load_all_from_path()` compiles the diagnostics away in release builds:

```cpp
#ifdef NDEBUG
    bool silent = true;
#else
    bool silent = false;
#endif
```

Verified live: against qmd 2.8.3, `QMD_LLAMA_GPU=vulkan qmd vsearch` fails with `NoBinaryFoundError` while `GGML_LOG_LEVEL=info` produces zero backend-loader output — the reason (missing export) is unreachable at any log level.

## Proof the missing export is the only blocker

A one-symbol shim next to the plugin, wired into its dependency chain:

```c
int ggml_backend_score(void) { return 1; }  /* cc -shared -fPIC -nostdlib */
```

(`patchelf --add-needed` onto `libggml-vulkan.so`) makes the exact same shipped artifacts work end-to-end: the backend registers as Vulkan and embeddings run on the iGPU — `gpu_busy_percent` spikes from ~1-2% idle to 45% under embed with host CPU near zero. `libggml-vulkan.so` already exports `ggml_backend_init`; the score symbol is the only missing piece.

Same-class precedent: #579 fixed a broken link chain in the b8179 vulkan prebuilt (`ggml_build_forward_select`); the current packages fail at a different link — the score export the loader itself dlsyms.

## Ask

Build the linux-x64-vulkan plugin so it defines/exports `ggml_backend_score` the way the CPU plugins do (and audit the other linux prebuilt packages for the same export). If it is cheap, consider not gating the plugin-load diagnostics entirely behind `NDEBUG` — today a release user with a broken backend sees nothing at any log level.

💘 Generated with Crush
