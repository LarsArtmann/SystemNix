_: {
  flake.nixosModules.taskchampion = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.taskchampion-config;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;
  in {
    options.services.taskchampion-config = {
      enable = lib.mkEnableOption "TaskChampion sync server with SystemNix configuration";
      port = serviceTypes.servicePort 10222 "Port for TaskChampion sync server";
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
        onFailure = ["notify-failure@%n.service"];
        startLimitBurst = 3;
        startLimitIntervalSec = 60;
        serviceConfig =
          harden {}
          // serviceDefaults {};
      };
    };
  };
}
