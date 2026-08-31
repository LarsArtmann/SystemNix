{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc,
  curl,
  util-linux,
  fftw,
  boost183,
  protobuf_32,
}:
# FastFlowLM — AMD XDNA NPU LLM runtime (ROCm org).
#
# v1.0.1 ships a portable Linux tarball that includes:
#   - `flm`        — bash wrapper that sets XILINX_XRT + LD_LIBRARY_PATH
#   - `flm-real`   — the actual binary (ELF, links against bundled NPU libs)
#   - `lib/`       — bundled NPU engine libs (.so with $ORIGIN RUNPATH)
#   - `xclbins/`   — NPU firmware bitstreams
#   - `model_info.json`, `model_list.json` — model catalog
#
# The bash wrapper is replaced with a nix-native wrapper that uses the
# deterministic $out path as XILINX_XRT. `autoPatchelfHook` rewrites the ELF
# interpreter + rpath so flm-real finds the nix-built libstdc++ / libgcc /
# libgomp / libuuid / libcurl / libfftw instead of the host's /lib paths
# (NixOS's stub-ld blocks `/lib64/ld-linux-x86-64.so.2`).
#
# Model files are NOT packaged — they're mmapped from `/data/ai/models/fastflowlm/`
# at runtime and pulled imperatively via `flm pull`. 13.6 GB binaries do not
# belong in the nix store.
#
# v1.0.3 (2026-08-27): re-quantized Qwen3.5 + Qwen3.6-MoE weights (Q4_1 →
# Q4_K). REQUIRES a one-time `flm pull qwen3.6-moe:35b-a3b` after deploy —
# old v1.0.2 weight files hash-mismatch the new manifest and `flm pull`
# overwrites them in place (same dance as v1.0.1→v1.0.2). The release notes
# do NOT claim a fix for the v1.0.2 prefill core-dump (4× in one boot,
# 2026-08-31) — the crash-loop containment is the guard's Zone 4, not this
# bump; treat the bump as accuracy + best-effort.
#
# Output: a single derivation exposing `flm` (the wrapper) on $PATH.
stdenv.mkDerivation (finalAttrs: {
  pname = "fastflowlm";
  version = "1.0.3";

  src = fetchurl {
    url = "https://github.com/ROCm/FastFlowLM/releases/download/v${finalAttrs.version}/fastflowlm_${finalAttrs.version}_linux.tar.gz";
    hash = "sha256-9yElTmoeBsvXKYg+ikvVg/o5aq3nYdWbtDM86o9Z69E=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    gcc.cc.lib
    curl
    util-linux
    fftw
    boost183
    protobuf_32
  ];

  # The tarball extracts to a flat layout (flm, flm-real, lib/, model_info.json,
  # model_list.json, xclbins/ at root). Keep that tree at $out verbatim — flm-real
  # resolves xclbins/ and model_*.json relative to its own location, and XRT
  # resolves lib/x86_64-linux-gnu/ relative to $XILINX_XRT=$out. Only the wrapper
  # moves: it is installed as $out/bin/flm so lib.getExe / meta.mainProgram = "flm"
  # are honest (2026-08-17: the flat-only layout made the unit's ExecStart point
  # at a nonexistent $out/bin/flm → status=203/EXEC → start-limit-hit).
  dontConfigure = true;
  dontBuild = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r . $out/
    chmod +x $out/flm-real
    # Drop the upstream bash wrapper (replaced below — it hardcodes /lib64
    # paths blocked by NixOS stub-ld) and the stdenv env-vars leak from cp -r .
    rm -f $out/flm $out/env-vars

    # FastFlowLM's bundled XRT libs (libxrt_swemu.so.2.21.75, libxrt_hwemu.so.2.21.75)
    # link against libprotobuf.so.32. nixpkgs' protobuf_32 ships libprotobuf.so.32.1.0
    # but no libprotobuf.so.32 symlink. Copy the protobuf library into $out/lib
    # so autoPatchelf's rpath resolver can find it (the symlink target needs to
    # be a real file in the same dir, not a store path reference).
    cp -L ${protobuf_32}/lib/libprotobuf.so.32.1.0 $out/lib/
    cp -L ${protobuf_32}/lib/libprotobuf.so $out/lib/ 2>/dev/null || true
    cp -L ${protobuf_32}/lib/libutf8_range.so.32.1.0 $out/lib/ 2>/dev/null || true
    cp -L ${protobuf_32}/lib/libutf8_range.so $out/lib/ 2>/dev/null || true
    cp -L ${protobuf_32}/lib/libprotoc.so.32.1.0 $out/lib/ 2>/dev/null || true
    ln -sf libprotobuf.so.32.1.0 $out/lib/libprotobuf.so.32
    ln -sf libutf8_range.so.32.1.0 $out/lib/libutf8_range.so.32 2>/dev/null || true

    # Replace the upstream bash wrapper with a nix-native one at $out/bin/flm
    # (nix convention; ExecStart uses lib.getExe). The wrapper sets XILINX_XRT
    # to the derivation's output path so XRT can find ./lib/x86_64-linux-gnu/
    # (the multiarch dir ships complete in the tarball — the store is
    # read-only, so no runtime symlink creation is needed or possible).
    cat > $out/bin/flm <<'WRAPPER'
    #!/bin/sh
    FLM_HOME="@out@"
    export XILINX_XRT="$FLM_HOME"
    export LD_LIBRARY_PATH="$FLM_HOME/lib:''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec "$FLM_HOME/flm-real" "$@"
    WRAPPER
    substituteInPlace $out/bin/flm --subst-var out
    chmod +x $out/bin/flm

    # Layout self-check: meta.mainProgram promises bin/flm. Guards against
    # future layout drift reproducing the 203/EXEC deploy failure.
    test -x $out/bin/flm
    test -x $out/flm-real
    test -d $out/lib/x86_64-linux-gnu

    runHook postInstall
  '';

  # FastFlowLM's flm-real is a hand-patched ELF that does not have a valid
  # .note.gnu.build-id section. autoPatchelfHook will warn about this; we
  # disable the warning so the build doesn't fail on cosmetic checks.
  dontStrip = false;

  # libxrt_swemu.so.2.21.75 + libxrt_hwemu.so.2.21.75 (XRT software/hardware
  # emulation libs) link against libprotobuf.so.32 which autoPatchelf cannot
  # resolve (nixpkgs' protobuf_32 ships libprotobuf.so.32.1.0 with no SONAME
  # symlink). These emulation libs are only used when targeting the swemu/hwemu
  # XRT platforms — NEVER on real NPU hardware (the XDNA plugin path). Safe to
  # ignore. The real device libraries (libxrt_coreutil.so.2, libxrt_driver_xdna.so.2.21.75)
  # resolve cleanly.
  autoPatchelfIgnoreMissingDeps = [
    "libprotobuf.so.32"
  ];

  meta = {
    description = "AMD XDNA NPU LLM runtime (Qwen3.6-35B-A3B on Strix Halo)";
    homepage = "https://github.com/ROCm/FastFlowLM";
    license = lib.licenses.unfree; # No LICENSE file ships with v1.0.1
    platforms = [ "x86_64-linux" ];
    mainProgram = "flm";
  };
})
