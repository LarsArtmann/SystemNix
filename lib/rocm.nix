{
  pkgs,
  gfxVersion ? "11.5.1",
}:
let
  runtimeLibs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.zstd
    pkgs.rocmPackages.clr
    pkgs.rocmPackages.rocminfo
    pkgs.rocmPackages.rocrand
    pkgs.rocmPackages.rocblas
    pkgs.rocmPackages.rocm-runtime
    pkgs.rocmPackages.rocm-comgr
  ];
in
{
  inherit runtimeLibs;

  env = {
    HSA_OVERRIDE_GFX_VERSION = gfxVersion;
    HSA_ENABLE_SDMA = "0";
  };

  makeLdLibraryPath = lib: lib.makeLibraryPath runtimeLibs;

  # llama.cpp with the HIP backend, built from the CALLER's nixpkgs. The same
  # expression under the same pkgs is ONE derivation, so every consumer on
  # the root nixpkgs (ai-stack's llama-server-rocm, the llama-chat unit)
  # shares a single store path. No -DGGML_HIP_MMQ_MFMA override belongs
  # here: it changes nothing on RDNA 3.5 and only defeats the binary cache
  # (rationale in ai-stack.nix).
  llamaCppHip = pkgs.llama-cpp.override { rocmSupport = true; };

  # Device-cgroup fragment for ROCm services. Allows ONLY the GPU nodes.
  #
  # The XDNA NPU node (/dev/accel/accel0, root:video 0660) is group-reachable
  # and gets OPENED by libdrm device enumeration during ROCm init. When the
  # amdxdna driver is wedged (post-crash firmware state, 2026-09-04 incident)
  # that open() blocks FOREVER inside the kernel: the process lands in
  # D-state with a pending, undeliverable SIGKILL, never binds its port, and
  # every service restart strands another unkillable corpse (systemd: "Unit
  # process ... remains running after unit stopped"). The cgroup BPF filter
  # rejects the open with EPERM before it ever reaches the driver, making
  # ROCm services immune to NPU-driver wedges. Merge into serviceConfig.
  deviceCgroup = {
    DevicePolicy = "strict";
    DeviceAllow = [
      "/dev/null"
      "/dev/zero"
      "/dev/full"
      "/dev/random"
      "/dev/urandom"
      # char-drm pattern, NOT "/dev/dri/" — systemd 258+ hard-errors directory
      # paths at unit load ("DeviceAllow= requires device node or pattern";
      # first proven live 2026-10-04 on the very first soak-harness execution).
      # The pattern matches the drm subsystem (card0, renderD128) while accel
      # nodes stay subsystem "accel", so the NPU-exclusion intent above holds.
      "char-drm"
      "/dev/dri/renderD128"
      "/dev/kfd"
    ];
  };
}
