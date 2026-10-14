{ pkgs, ... }: {
  # AMD GPU Support (Critical for Ryzen AI Max+)
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Use latest Mesa for best performance with Wayland compositors
    package = pkgs.mesa;
    package32 = pkgs.pkgsi686Linux.mesa;
    # Note: amdvlk has been deprecated, RADV is now the default driver
    # OpenCL support via ROCm
    extraPackages = [
      pkgs.rocmPackages.clr.icd # OpenCL support
      pkgs.rocmPackages.rocblas # BLAS operations for AI/ML
      pkgs.rocmPackages.rocminfo # GPU detection and topology
      # amdvlk removed - RADV is now the default AMD Vulkan driver
      # hipblaslt removed - optional rocblas optimization, fails to build from source
      pkgs.libva # Video acceleration API
      pkgs.libvdpau-va-gl # VDPAU backend for video acceleration
    ];
  };

  # AMD GPU performance environment variables
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    AMD_VULKAN_ICD = "RADV";
    MESA_VK_WSI_PRESENT_MODE = "immediate";
  };

  # KFD/DRM udev rules for GPU compute access + force high performance for AI workloads
  # + IO scheduler: bfq for responsive desktop under heavy disk pressure
  services.udev.extraRules = ''
    SUBSYSTEM=="kfd", GROUP="render", MODE="0660"
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="render", MODE="0660"
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", GROUP="render", MODE="0660"
    # Force GPU to high performance DPM state (fixes 10-15% perf loss from power saving)
    SUBSYSTEM=="drm", KERNEL=="card[0-9]", ATTR{device/power_dpm_force_performance_level}="high"
    # IO scheduler: bfq prioritizes interactive I/O over bulk writers (ClickHouse, nix-optimise)
    # Falls back to mq-deadline (kernel default) if bfq module unavailable
    ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", TEST=="queue/scheduler", ATTR{queue/scheduler}="bfq"
    ACTION=="add|change", KERNEL=="sd[a-z]*|vd[a-z]*|dm-[0-9]*", TEST=="queue/scheduler", ATTR{queue/scheduler}="bfq"
  '';

  # Add essential system packages for AMD GPU monitoring and control
  environment.systemPackages = [
    # AMD GPU monitoring and control
    pkgs.amdgpu_top # GPU monitoring tool
    pkgs.corectrl # AMD CPU control
    pkgs.vulkan-tools # Vulkan utilities
    pkgs.mesa-demos # GPU testing tools
    pkgs.libva-utils # VA-API diagnostics (vainfo)
    # ROCm monitoring
    pkgs.rocmPackages.rocm-smi # Detailed GPU stats, clocks, memory usage
    pkgs.nvtopPackages.amd # htop-like GPU monitor
  ];
}
