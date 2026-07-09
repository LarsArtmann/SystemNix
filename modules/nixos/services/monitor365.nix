# Monitor365: thin SystemNix wrapper around upstream NixOS modules.
#
# Heavy lifting (TOML generation, systemd services, hardening, collector
# schema, bootstrap/SSO) is in the monitor365 flake:
#   nix/module.nix       → services.monitor365 (agent)
#   nix/server-module.nix → services.monitor365-server (control plane)
#
# This file only adds SystemNix-specific defaults: port wiring, sops
# secret wiring, desktop runtime deps, and pocket-id SSO integration.
#
# ── Auth Model ──────────────────────────────────────────────
# The server bootstrap generates (or reads from sops) ONE tenant-level
# API key.  This key is shared by all agents in the tenant — it proves
# tenant membership, not device identity.  Per-device identity is
# established via hardware fingerprint headers (x-device-fingerprint,
# x-hardware-fingerprint, x-host-id) sent alongside the API key.
#
# The same sops secret value (monitor365_api_key) is materialised as
# two separate sops entries with different owners:
#   1. monitor365_api_key → owned by monitor365-server (bootstrap.apiKeyFile)
#   2. cloud_auth_token   → owned by primaryUser (agent environmentFile)
#
# In a multi-machine deployment each machine would have its own sops
# file but with the same tenant key value.  If a machine is compromised
# the admin rotates the key in sops and redeploys.
{inputs, ...}: {
  flake.nixosModules.monitor365 = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (config.users) primaryUser;
    ports = (import ../../../lib/default.nix lib).ports;
    domain = config.networking.domain;

    agentCfg = config.services.monitor365;
    serverCfg = config.services.monitor365-server;

    # Desktop monitoring deps — CLI tools the agent shells out to.
    desktopDeps = with pkgs; [
      xdotool
      xprintidle
      scrot
      networkmanager
      lm_sensors
      bluez
      util-linux
      coreutils
      procps
    ];
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
          runtimeDeps = lib.mkDefault desktopDeps;

          # Agent reads the tenant API key from a sops-managed env file.
          # The env file sets MONITOR365__CLOUD__AUTH_TOKEN which the
          # config crate picks up via env-var layering.
          environmentFile = lib.mkDefault config.sops.templates."monitor365-agent-env".path;

          settings = {
            device = {
              name = lib.mkDefault config.networking.hostName;
              type = lib.mkDefault "desktop";
            };

            storage = {
              path = lib.mkDefault "/home/${primaryUser}/.local/share/monitor365";
              encryption = lib.mkDefault true;
              encryption_key_file = lib.mkDefault "/home/${primaryUser}/.config/monitor365/storage_key";
              max_size_mb = lib.mkDefault (30 * 1024);
            };

            logging.level = lib.mkDefault "warn";
            metrics = {
              enabled = lib.mkDefault true;
              bind_address = lib.mkDefault "127.0.0.1:${toString ports.monitor365-metrics}";
            };
            activitywatch = lib.mkDefault null;

            # Agent syncs to local server — endpoint only, no authTokenFile.
            # The token is injected via environmentFile (sops template).
            cloud = lib.mkIf serverCfg.enable {
              endpoint = lib.mkDefault "http://localhost:${toString ports.monitor365-server}";
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

          jwtSecretFile = lib.mkDefault config.sops.secrets.server_jwt_secret.path;
          environmentFile = lib.mkDefault config.sops.templates."monitor365-server-env".path;

          bootstrap = {
            enable = lib.mkDefault true;
            # Pre-provisioned tenant API key from sops — both server and
            # agent read the same underlying value.
            apiKeyFile = lib.mkDefault config.sops.secrets.monitor365_api_key.path;
          };

          sso = lib.mkIf (config.services.pocket-id.enable or false) {
            issuer = lib.mkDefault "https://auth.${domain}";
            clientSecretFile = lib.mkDefault "${config.services.pocket-id.dataDir or "/var/lib/pocket-id"}/client-secrets/monitor365";
            redirectUri = lib.mkDefault "https://monitor.${domain}/v1/auth/sso/callback";
          };
        };

        # Grant pocket-id group to both agent user and server user when SSO is enabled
        users.users.${primaryUser}.extraGroups =
          lib.optional (serverCfg.sso.enable && (config.services.pocket-id.enable or false)) "pocket-id";
        users.users.monitor365-server.extraGroups =
          lib.optional (serverCfg.sso.enable && (config.services.pocket-id.enable or false)) "pocket-id";
      })
    ];
  };
}
