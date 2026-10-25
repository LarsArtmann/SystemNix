# Runbook: docs/services/taskchampion.md
# TaskChampion sync server for Taskwarrior task management
_: {
  flake.nixosModules.taskchampion =
    {
      config,
      options,
      lib,
      ...
    }:
    let
      cfg = config.services.taskchampion-config;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        serviceTypes
        ports
        ;
    in
    {
      options.services.taskchampion-config = {
        enable = lib.mkEnableOption "TaskChampion sync server with SystemNix configuration";
        port = serviceTypes.servicePort ports.taskchampion "Port for TaskChampion sync server";
      };

      config = lib.mkIf cfg.enable {
        services.taskchampion-sync-server = {
          enable = true;
          host = "127.0.0.1";
          inherit (cfg) port;
          openFirewall = false;
          snapshot = {
            versions = 100;
            days = 14;
          };
        };

        # Integration registry entry (2026-10-25 §g.2 answer: subdomain ⇒
        # dashboard). vHost.layer "none": the tasks vHost stays hand-written
        # in caddy.nix; the tcp sync check stays hand-written in gatus-config.nix
        # (registry checks fan out through mkHttpCheck, HTTP-only).
        services.integration.taskchampion-sync-server = lib.optionalAttrs (options ? services.integration) {
          enable = true;
          subdomain = "tasks";
          inherit (cfg) port;
          vHost.layer = "none";
          monitored = true;
          homepage = {
            name = "Taskwarrior";
            group = "Productivity";
            description = "Task Sync Server (TaskChampion)";
            icon = "taskcafe.png";
          };
        };

        systemd.services.taskchampion-sync-server = {
          inherit onFailure;
          startLimitBurst = 3;
          startLimitIntervalSec = 60;
          serviceConfig = lib.mkMerge [
            (harden { })
            (serviceDefaults { })
          ];
        };
      };
    };
}
