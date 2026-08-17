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
# Output: a single derivation exposing `flm` (the wrapper) on $PATH.
stdenv.mkDerivation (finalAttrs: {
  pname = "fastflowlm";
  version = "1.0.1";

  src = fetchurl {
    url = "https://github.com/ROCm/FastFlowLM/releases/download/v${finalAttrs.version}/fastflowlm_${finalAttrs.version}_linux.tar.gz";
    hash = "sha256-vTk2yyyLCZpLkLTSC9j2KuZpOlQg464JWVEgGyv70co=";
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
  # model_list.json, xclbins/ at root). Wrap installPhase to copy this tree
  # into $out as-is.
  dontConfigure = true;
  dontBuild = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out/
    chmod +x $out/flm-real

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

    # Replace the upstream bash wrapper with a nix-native one. The wrapper
    # sets XILINX_XRT to the derivation's output path so XRT can find
    # ./lib/x86_64-linux-gnu/ (the wrapper creates the multiarch symlinks
    # on first run if absent).
    cat > $out/flm <<'WRAPPER'
    #!/bin/sh
    FLM_HOME="@out@"
    export XILINX_XRT="$FLM_HOME"
    export LD_LIBRARY_PATH="$FLM_HOME/lib:''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    # XRT constructs library paths as $XILINX_XRT/lib/x86_64-linux-gnu/<lib>.
    # The symlinks in the tarball already point at the bundled libs under
    # ./lib/, so the multiarch directory is created on first run by the
    # bash wrapper logic copied below.
    MULTIARCH_DIR="$FLM_HOME/lib/x86_64-linux-gnu"
    if [ ! -d "$MULTIARCH_DIR" ]; then
      mkdir -p "$MULTIARCH_DIR"
      for lib in $FLM_HOME/lib/libxrt*.so* $FLM_HOME/lib/libxrt++.so*; do
        [ -f "$lib" ] || [ -L "$lib" ] || continue
        ln -sf "../$(basename "$lib")" "$MULTIARCH_DIR/$(basename "$lib")" 2>/dev/null || true
      done
    fi
    exec "$FLM_HOME/flm-real" "$@"
    WRAPPER
    substituteInPlace $out/flm --subst-var out
    chmod +x $out/flm

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
