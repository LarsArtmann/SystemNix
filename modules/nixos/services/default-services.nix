# Default system services: Docker (auto-prune) + weekly Nix GC timer
_: {
  flake.nixosModules.default-services = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.default-services;
    inherit ((import ../../../lib/ports.nix)) ports;
  in {
    options.services.default-services = {
      enable =
        lib.mkEnableOption "Default system services (Docker + Nix GC timer)"
        // {
          default = true;
        };
    };

    config = lib.mkIf cfg.enable {
      virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
        storageDriver = "overlay2";
        daemon.settings = {
          data-root = "/data/docker";
          # Docker 29.x moved docker-proxy to the internal moby derivation,
          # which nixpkgs doesn't expose. Disable userland proxy — Docker
          # falls back to iptables rules for port forwarding, which is
          # the recommended production approach.
          userland-proxy = false;
          # Container stdout/stderr into the journal: the SigNoz collector
          # ingests the whole journal (all=true) and maps CONTAINER_NAME
          # entries to service.name=<container>. Existing containers keep
          # json-file until recreated (docker compose up / image update).
          log-driver = "journald";
          # Engine's own Prometheus endpoint — scraped by the SigNoz
          # collector (job=docker-engine, feeds the Docker Daemon Down alert).
          metrics-addr = "127.0.0.1:${toString ports.docker-engine-metrics}";
        };
      };

      # Docker should start early at multi-user.target, not block graphical.target
      systemd.services.docker.wantedBy = lib.mkForce ["multi-user.target"];

      # nix.gc is defined in platforms/common/nix-settings.nix (shared)
    };
  };
}
