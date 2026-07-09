# Monitor365: thin SystemNix wrapper around upstream NixOS modules.
#
# Heavy lifting (TOML generation, systemd services, hardening, collector
# schema, bootstrap/SSO) is in the monitor365 flake:
#   nix/module.nix       → services.monitor365 (agent)
#   nix/server-module.nix → services.monitor365-server (control plane)
#
# This file only adds SystemNix-specific defaults: port wiring, sops
# secret paths, desktop runtime deps, and pocket-id SSO integration.
{inputs, ...}: {
  flake.nixosModules.monitor365 = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (config.users) primaryUser;
    ports = (import ../../../lib/ports.nix).ports;
    domain = config.networking.domain;

    agentCfg = config.services.monitor365;
    serverCfg = config.services.monitor365-server;
  in {
    imports = [
      inputs.monitor365.nixosModules.monitor365
      inputs.monitor365.nixosModules.monitor365-server
    ];

    config = lib.mkMerge [
      # ── Agent defaults (desktop monitoring) ───────────────────
      (lib.mkIf agentCfg.enable {
        services.monitor365 = {
          user = lib.mkDefault primaryUser;
          group = lib.mkDefault "users";
          serviceType = lib.mkDefault "user";

          settings = {
            device = {
              name = lib.mkDefault config.networking.hostName;
              type = lib.mkDefault "desktop";
            };

            storage = {
              path = lib.mkDefault "/home/${primaryUser}/.local/share/monitor365";
              encryption = lib.mkDefault true;
              max_size_mb = lib.mkDefault (30 * 1024);
            };

            logging.level = lib.mkDefault "warn";
            metrics = {
              enabled = lib.mkDefault true;
              bind_address = lib.mkDefault "127.0.0.1:${toString ports.monitor365-metrics}";
            };
            activitywatch = lib.mkDefault null;

            # Agent syncs to local server
            cloud = lib.mkIf serverCfg.enable {
              endpoint = lib.mkDefault "http://localhost:${toString ports.monitor365-server}";
              authTokenFile = lib.mkDefault config.sops.secrets.cloud_auth_token.path;
              sync_interval_seconds = lib.mkDefault 60;
            };
          };
        };
      })

      # ── Server defaults ────────────────────────────────────────
      (lib.mkIf serverCfg.enable {
        services.monitor365-server = {
          listenAddr = lib.mkDefault "0.0.0.0:${toString ports.monitor365-server}";
          port = lib.mkDefault ports.monitor365-server;
          dashboardUrl = lib.mkDefault "https://monitor.${domain}/ui/";
          corsOrigins = lib.mkDefault [
            "http://localhost:${toString ports.monitor365-server}"
            "https://monitor.${domain}"
          ];

          # JWT secret from sops
          jwtSecretFile = lib.mkDefault config.sops.secrets.server_jwt_secret.path;

          # Sops env file (for any extra MONITOR365_SERVER__* vars)
          environmentFile = lib.mkDefault config.sops.templates."monitor365-env".path;

          bootstrap = {
            enable = lib.mkDefault true;
          };

          # SSO via Pocket ID — defaults set unconditionally; user opts in via sso.enable
          sso = {
            issuer = lib.mkDefault "https://auth.${domain}";
            clientSecretFile = lib.mkDefault "${config.services.pocket-id.dataDir or "/var/lib/pocket-id"}/client-secrets/monitor365";
            redirectUri = lib.mkDefault "https://monitor.${domain}/v1/auth/sso/callback";
          };
        };

        # Allow the agent user to read Pocket ID client secrets when SSO is enabled
        users.users.${primaryUser}.extraGroups =
          lib.optional serverCfg.sso.enable "pocket-id";
      })
    ];
  };
}
