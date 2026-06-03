# Dozzle — Lightweight Docker container log tailing web UI
_: {
  flake.nixosModules.dozzle = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.dozzle;
    inherit (lib) mkEnableOption mkOption types;
    inherit (import ../../../lib/default.nix lib) ports;
    dozzlePort = ports.dozzle;
  in {
    options.services.dozzle = {
      enable = mkEnableOption "Dozzle Docker log viewer";

      port = mkOption {
        type = types.port;
        default = dozzlePort;
        description = "Port for Dozzle web UI";
      };
    };

    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.dozzle = {
        autoStart = true;
        image = "amir20/dozzle:latest";
        ports = ["127.0.0.1:${toString cfg.port}:8080"];
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ];
        environment = {
          DOZZLE_TAILSIZE = "300";
          DOZZLE_FILTER = "status=running";
        };
      };
    };
  };
}
