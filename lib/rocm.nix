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
      "/dev/dri/"
      "/dev/dri/renderD128"
      "/dev/kfd"
    ];
  };
}
