{
  pkgs,
  gfxVersion ? "11.5.1",
}:
rec {
  runtimeLibs = with pkgs; [
    stdenv.cc.cc.lib
    zstd
    rocmPackages.clr
    rocmPackages.rocminfo
    rocmPackages.rocrand
    rocmPackages.rocblas
    rocmPackages.rocm-runtime
    rocmPackages.rocm-comgr
  ];

  env = {
    HSA_OVERRIDE_GFX_VERSION = gfxVersion;
    HSA_ENABLE_SDMA = "0";
  };

  makeLdLibraryPath = lib: lib.makeLibraryPath runtimeLibs;
}
