# TaskChampion sync server for Taskwarrior task management
_: {
  flake.nixosModules.taskchampion = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.taskchampion-config;
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      onFailure
      serviceTypes
      ports
      ;
  in {
    options.services.taskchampion-config = {
      enable = lib.mkEnableOption "TaskChampion sync server with SystemNix configuration";
      port = serviceTypes.servicePort ports.taskchampion "Port for TaskChampion sync server";
    };

    config = lib.mkIf cfg.enable {
      services.taskchampion-sync-server = {
        enable = true;
        host = "127.0.0.1";
        port = cfg.port;
        openFirewall = false;
        snapshot = {
          versions = 100;
          days = 14;
        };
      };

      systemd.services.taskchampion-sync-server = {
        inherit onFailure;
        startLimitBurst = 3;
        startLimitIntervalSec = 60;
        serviceConfig = harden {} // serviceDefaults {};
      };
    };
  };
}
