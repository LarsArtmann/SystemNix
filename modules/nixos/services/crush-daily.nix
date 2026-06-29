# crush-daily — SystemNix hardening overlay for the crush-daily service
_: {
  flake.nixosModules.crush-daily = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.crush-daily;
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      onFailure
      ports
      ;
  in {
    config = lib.mkIf cfg.enable {
      services.crush-daily.port = lib.mkDefault ports.crush-daily;

      systemd.services.crush-daily = {
        inherit onFailure;
        path = [pkgs.crush];
        startLimitBurst = 3;
        startLimitIntervalSec = 60;
        serviceConfig =
          harden {
            ReadWritePaths = [cfg.dataDir];
          }
          // serviceDefaults {};
      };
    };
  };
}
