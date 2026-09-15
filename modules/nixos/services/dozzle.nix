# Dozzle — Lightweight Docker container log tailing web UI
_: {
  flake.nixosModules.dozzle =
    {
      config,
      options,
      lib,
      ...
    }:
    let
      cfg = config.services.dozzle;
      inherit (lib) mkEnableOption mkOption types;
      inherit (import ../../../lib/default.nix lib) ports images;
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
          image = images.dozzle.ref;
          ports = [ "127.0.0.1:${toString cfg.port}:8080" ];
          volumes = [
            "/var/run/docker.sock:/var/run/docker.sock:ro"
          ];
          environment = {
            # DOZZLE_TAILSIZE removed 2026-08-31: Dozzle v10.6.6 rejects it
            # ("Unexpected environment variable") and 300 is the default anyway.
            DOZZLE_FILTER = "status=running";
          };
          extraOptions = [
            "--memory=256m"
            "--memory-swap=256m"
            # NO --log-driver override: the daemon default is journald
            # (default-services.nix), which feeds SigNoz. An explicit
            # json-file + log-opts here (2026-08-22 regression) silently
            # removed dozzle container logs from SigNoz — duplicate
            # --log-driver flags made json-file win.
            "--security-opt=no-new-privileges:true"
            "--cap-drop=ALL"
          ];
        };

        # Service-integration registry entry: the Dozzle homepage tile and
        # the logs vHost (Layer 2 — gated on the container existing, same
        # predicate as the old hasContainer check in homepage.nix/caddy.nix).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          dozzle = {
            enable = cfg.enable;
            subdomain = "logs";
            port = dozzlePort;
            vHost.layer = "protected";
            homepage = {
              name = "Dozzle";
              group = "Monitoring";
              description = "Docker Log Viewer";
              icon = "docker.png";
            };
          };
        };
      };
    };
}
