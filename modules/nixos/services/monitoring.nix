# System monitoring CLI tools (radeontop, strace, nethogs, etc.)
_: {
  flake.nixosModules.monitoring = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.monitoring-tools;
  in {
    options.services.monitoring-tools = {
      enable = lib.mkEnableOption "System and network monitoring tools";
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        radeontop # AMD GPU specific monitor (CLI, lightweight)
        # nvtopPackages.amd moved to hardware/amd-gpu.nix (alongside other GPU tools)
        # amdgpu_top moved to hardware/amd-gpu.nix (available system-wide)

        # System monitoring
        # btop moved to base.nix (available cross-platform)

        # System monitoring and debugging
        strace # System call tracer
        ltrace # Library call tracer

        # Network monitoring
        nethogs # Network process monitoring
        iftop # Network bandwidth
        netwatch # Real-time network diagnostics TUI
      ];
    };
  };
}
