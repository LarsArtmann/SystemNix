# Dozzle — Lightweight Docker container log tailing web UI
_: {
  flake.nixosModules.dozzle =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.dozzle;
      inherit (lib) mkEnableOption mkOption types;
      inherit (import ../../../lib/default.nix lib) ports;
      dozzlePort = ports.dozzle;
    in
    {
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
          ports = [ "127.0.0.1:${toString cfg.port}:8080" ];
          volumes = [
            "/var/run/docker.sock:/var/run/docker.sock:ro"
          ];
          environment = {
            DOZZLE_TAILSIZE = "300";
            DOZZLE_FILTER = "status=running";
          };
          extraOptions = [
            "--memory=256m"
            "--memory-swap=256m"
            "--log-driver=json-file"
            "--log-opt=max-size=5m"
            "--log-opt=max-file=3"
            "--security-opt=no-new-privileges:true"
            "--cap-drop=ALL"
          ];
        };
      };
    };
}
