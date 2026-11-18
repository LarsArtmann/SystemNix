{
  lib,
  stdenv,
  runCommand,
  patchelf,
  vulkan-loader,
  glibc,
  bash,
  qmd,
}:
# qmd with a WORKING Vulkan backend on evo-x2 (the iGPU path for the
# GGUF embed/expansion/rerank models).
#
# WHY THIS EXISTS (root-caused live 2026-11-17; every claim probed against
# the qmd-2.8.3 store tree):
#
# Upstream qmd runs GGUF inference through node-llama-cpp, whose Linux
# backends are CPU / CUDA / Vulkan — no ROCm. The Vulkan prebuilt is broken
# in three stacked ways, and every failure is silently swallowed (NDEBUG →
# silent=true in ggml_backend_load_best), so qmd's "GPU auto-probe" quietly
# degrades to CPU and `qmd embed` burns up to ~13.5 cores.
#
# Layer 1 — broken prebuilt artifact: libggml-vulkan.so (both 3.20.0 AND
#   latest 3.22.3, tarball-probed) fatals on dlopen with
#   `undefined symbol: ggml_backend_score`. The backend loader dlsyms that
#   symbol per plugin and the CPU plugins export it (libggml-cpu-zen4.so);
#   the vulkan plugin does not → NoBinaryFoundError. FIX here: compile a
#   zero-dependency shim (`int ggml_backend_score(void){return 1;}`,
#   -nostdlib) into the plugin dir and patchelf --add-needed it onto the
#   plugin so the symbol resolves through the plugin's own dep chain.
# Layer 2 — the upstream wrapper's LD_LIBRARY_PATH pins sqlite + glibc-2.42
#   + gcc and has NO libvulkan.so.1 at all. FIX here: add vulkan-loader.
# Layer 3 — RADV (system mesa) pulls libLLVM.so.21.1 which requires
#   GLIBC_2.44, but bun runs inside the wrapper's glibc-2.42 process → the
#   whole ICD chain fails to load → zero Vulkan devices. FIX here: run bun
#   through the SYSTEM glibc (pkgs.glibc, 2.44) — bun is built against
#   2.42 and glibc is forward-compatible; the reverse (new binary on old
#   libc) is what breaks.
# Layer 4 — node-llama-cpp's compat test forks process.execPath directly,
#   so the loader must be fixed INSIDE the bun binary: an `ld.so bun`
#   invocation fixes the parent but forked children still use bun's 2.42
#   PT_INTERP → GLIBC_PRIVATE mismatch. FIX here: patchelf
#   --set-interpreter on a copy of bun — every process in the tree gets
#   the 2.44 loader.
#
# The whole qmd lib tree is COPIED (not referenced) so the patches land on
# our copy; the flake input stays untouched (no vendorHash churn). The
# binding packages resolve binsDir runtime-relative, so the copied tree
# self-resolves (live-verified). The bin/qmd wrapper replicates the
# upstream wrapper's mcp log-quieting line verbatim and points exec at the
# patched bun + copied CLI entry.
#
# Verification gates (re-run after any upstream qmd bump):
#   GGML_LOG_LEVEL=info probe against the binding → `loaded Vulkan backend`
#   `QMD_LLAMA_GPU=vulkan qmd vsearch x` → no `falling back to CPU` warning
#   `qmd embed` → /sys/class/drm/card*/device/gpu_busy_percent spikes
#     (idle 1-2%), host CPU near-zero during inference (offload signature).
#
# Upstream rows: docs/todo/upstream.md (the broken vulkan prebuilt itself —
# this package is the site workaround, not the upstream fix).

runCommand "qmd-${lib.getVersion qmd}-gpu"
  {
    inherit qmd;
    nativeBuildInputs = [ patchelf ];
    dontStrip = true;
    meta.platforms = [ "x86_64-linux" ];
  }
  ''
    mkdir -p $out/bin
    cp -r ${qmd}/lib $out/lib
    chmod -R u+w $out/lib

    # Layer 1: score shim + patched vulkan plugin (writable copy above)
    vd=$out/lib/qmd/node_modules/@node-llama-cpp/linux-x64-vulkan/bins/linux-x64-vulkan
    printf 'int ggml_backend_score(void) { return 1; }\n' > shim.c
    ${stdenv.cc}/bin/cc -shared -fPIC -nostdlib -o $vd/libggml-score-shim.so shim.c
    chmod u+w $vd/libggml-vulkan.so
    patchelf --add-needed '$ORIGIN/libggml-score-shim.so' $vd/libggml-vulkan.so

    # Layers 3+4: bun copy on the system loader (forks inherit the interp)
    bunPath=$(awk -F'"' '/^exec/ {print $2; exit}' ${qmd}/bin/qmd)
    cp $bunPath $out/lib/bun
    chmod u+w $out/lib/bun
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 $out/lib/bun

    # Layer 2: LD_LIBRARY_PATH = system glibc + vulkan-loader + the
    # upstream wrapper's non-glibc entries (sqlite, gcc) kept verbatim.
    oldLdl=$(awk -F"'" '/^export LD_LIBRARY_PATH=/ {print $2; exit}' ${qmd}/bin/qmd)
    kept=$(printf '%s' "$oldLdl" | tr ':' '\n' | grep -v glibc- | paste -sd:)

    # mcp log-quieting line from the upstream wrapper, copied verbatim
    mcpLine=$(grep -F 'if [ "$1" = mcp ]' ${qmd}/bin/qmd || true)

    # RADV ICD pinned explicitly: this box boot-mirrors and the loader's
    # default ICD discovery must not depend on live boot state.
    {
      echo '#!${bash}/bin/bash -e'
      ldlBase="${glibc}/lib:${vulkan-loader}/lib"
      if [ -n "$kept" ]; then
        echo "export LD_LIBRARY_PATH='$ldlBase:$kept'"
      else
        echo "export LD_LIBRARY_PATH='$ldlBase'"
      fi
      echo 'export VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json'
      printf '%s\n' "$mcpLine"
      echo "exec \"$out/lib/bun\" \"$out/lib/qmd/src/cli/qmd.ts\" \"\$@\""
    } > $out/bin/qmd
    chmod +x $out/bin/qmd
  ''
