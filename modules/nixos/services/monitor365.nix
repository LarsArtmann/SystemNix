# Monitor365: thin SystemNix wrapper around upstream NixOS modules.
#
# Heavy lifting (TOML generation, systemd services, hardening, collector
# schema, bootstrap/SSO) is in the monitor365 flake:
#   nix/module.nix         → services.monitor365 (system/headless agent)
#   nix/desktop-module.nix → services.monitor365-desktop (desktop/user agent)
#   nix/server-module.nix  → services.monitor365-server (control plane)
#
# This file only adds SystemNix-specific defaults: port wiring, sops
# secret wiring, runtime deps, and pocket-id SSO integration.
#
# ── Dual-Instance Architecture ──────────────────────────────
# Two agent instances run simultaneously on each monitored machine:
#
#   1. System instance (services.monitor365)
#      - systemd system service (multi-user.target, survives logout)
#      - Dedicated 'monitor365' system user
#      - Headless collectors: network, process, system_info, battery, etc.
#      - Auth via LoadCredential (reads sops secret as root)
#
#   2. Desktop instance (services.monitor365-desktop)
#      - systemd user service (graphical-session.target, stops at logout)
#      - Runs as primaryUser via home-manager
#      - Desktop collectors: screenshots, camera, keystrokes, etc.
#      - Auth via environmentFile (sops template owned by primaryUser)
#
# Both sync to the local server as separate devices under the same tenant.
#
# ── Auth Model ──────────────────────────────────────────────
# The server bootstrap generates (or reads from sops) ONE tenant-level
# API key.  This key is shared by all agents in the tenant — it proves
# tenant membership, not device identity.  Per-device identity is
# established via hardware fingerprint headers (x-device-fingerprint,
# x-hardware-fingerprint, x-host-id) sent alongside the API key.
#
# The same sops secret value is materialised with different owners:
#   1. monitor365_api_key → server (bootstrap.apiKeyFile)
#                           + system agent (LoadCredential via authTokenFile)
#   2. cloud_auth_token   → desktop agent (sops template env file)
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

    systemAgentCfg = config.services.monitor365;
    desktopAgentCfg = config.services.monitor365-desktop;
    serverCfg = config.services.monitor365-server;

    # Headless monitoring deps — CLI tools for system collectors.
    systemDeps = with pkgs; [
      procps
      util-linux
      coreutils
      lm_sensors
      networkmanager
      bluez
    ];

    # Desktop monitoring deps — GUI tools for desktop collectors.
    desktopDeps = with pkgs; [
      xdotool
      xprintidle
      scrot
      coreutils
      procps
    ];
  in {
    imports = [
      inputs.monitor365.nixosModules.monitor365
      inputs.monitor365.nixosModules.monitor365-desktop
      inputs.monitor365.nixosModules.monitor365-server
    ];

    config = lib.mkMerge [
      # ── System agent defaults (headless, survives logout) ──────
      (lib.mkIf systemAgentCfg.enable {
        services.monitor365 = {
          runtimeDeps = lib.mkDefault systemDeps;

          settings = {
            device = {
              name = lib.mkDefault "${config.networking.hostName} (system)";
              type = lib.mkDefault "server";
            };

            storage = {
              encryption = lib.mkDefault true;
              encryption_key_file = lib.mkDefault "/var/lib/monitor365/storage_key";
              max_size_mb = lib.mkDefault (30 * 1024);
            };

            logging.level = lib.mkDefault "warn";
            metrics = {
              enabled = lib.mkDefault true;
              bind_address = lib.mkDefault "127.0.0.1:${toString ports.monitor365-metrics}";
            };
            activitywatch = lib.mkDefault null;

            # System agent authenticates via LoadCredential — systemd reads
            # the sops secret as root and provisions it to the service.
            cloud = lib.mkIf serverCfg.enable {
              endpoint = lib.mkDefault "http://localhost:${toString ports.monitor365-server}";
              sync_interval_seconds = lib.mkDefault 60;
              authTokenFile = lib.mkDefault config.sops.secrets.monitor365_api_key.path;
            };
          };
        };
      })

      # ── Desktop agent defaults (graphical session) ────────────
      (lib.mkIf desktopAgentCfg.enable {
        services.monitor365-desktop = {
          user = lib.mkDefault primaryUser;
          group = lib.mkDefault "users";
          runtimeDeps = lib.mkDefault desktopDeps;

          # Desktop agent reads the tenant API key from a sops-managed
          # env file owned by the desktop user.
          environmentFile = lib.mkDefault config.sops.templates."monitor365-desktop-agent-env".path;

          settings = {
            device = {
              id = lib.mkDefault "${config.networking.hostName}-desktop";
              name = lib.mkDefault "${config.networking.hostName} (desktop)";
              type = lib.mkDefault "desktop";
            };

            storage = {
              path = lib.mkDefault "${config.users.users.${primaryUser}.home}/.local/share/monitor365-desktop";
              encryption = lib.mkDefault true;
              encryption_key_file = lib.mkDefault "${config.users.users.${primaryUser}.home}/.config/monitor365-desktop/storage_key";
              max_size_mb = lib.mkDefault (30 * 1024);
            };

            logging.level = lib.mkDefault "warn";
            metrics = {
              enabled = lib.mkDefault true;
              bind_address = lib.mkDefault "127.0.0.1:${toString ports.monitor365-desktop-metrics}";
            };
            activitywatch = lib.mkDefault null;

            # Desktop agent syncs to local server — token injected via
            # environmentFile (sops template).
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
            # Pre-provisioned tenant API key from sops — server, system agent,
            # and desktop agent all read the same underlying value.
            apiKeyFile = lib.mkDefault config.sops.secrets.monitor365_api_key.path;
          };

          sso = lib.mkIf (config.services.pocket-id.enable or false) {
            issuer = lib.mkDefault "https://auth.${domain}";
            clientSecretFile = lib.mkDefault "${config.services.pocket-id.dataDir or "/var/lib/pocket-id"}/client-secrets/monitor365";
            redirectUri = lib.mkDefault "https://monitor.${domain}/v1/auth/sso/callback";
          };
        };

        # Grant pocket-id group to server user for SSO secret access
        users.users.monitor365-server.extraGroups =
          lib.optional (serverCfg.sso.enable && (config.services.pocket-id.enable or false)) "pocket-id";
      })
    ];
  };
}
