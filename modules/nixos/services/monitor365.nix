# Monitor365: thin SystemNix wrapper around upstream NixOS modules.
#
# Heavy lifting (TOML generation, systemd services, hardening, collector
# schema, bootstrap/SSO) is in the monitor365 flake:
#   nix/module.nix         → services.monitor365 (unified agent with IPC)
#   nix/server-module.nix  → services.monitor365-server (control plane)
#
# This file only adds SystemNix-specific defaults: port wiring, sops
# secret wiring, runtime deps, and pocket-id SSO integration.
#
# ── Unified Agent Architecture ──────────────────────────────
# A single agent instance runs on each monitored machine:
#
#   services.monitor365 (system service, survives logout)
#      - Dedicated 'monitor365' system user with linger
#      - Headless collectors: network, process, system_info, battery, etc.
#      - Desktop collectors: screenshots, camera, keystrokes, etc.
#        Display env discovered from active sessions via the graphical helper;
#        skip gracefully if no session
#      - IPC socket at /run/monitor365/agent.sock for graphical helper
#      - Auth via LoadCredential (reads sops secret as root)
#      - graphicalUsers: login users granted IPC group access
#
# Both collectors sync to the local server as one device.
#
# ── Auth Model ──────────────────────────────────────────────
# The server bootstrap generates (or reads from sops) ONE tenant-level
# API key.  This key is shared by all agents in the tenant — it proves
# tenant membership, not device identity.  Per-device identity is
# established via hardware fingerprint headers (x-device-fingerprint,
# x-hardware-fingerprint, x-host-id) sent alongside the API key.
#
# The same sops secret value (cloud_auth_token) is materialised with
# different owners (desktop user vs monitor365-server system user) because
# sops-nix grants file ownership per entry.
#
# In a multi-machine deployment each machine would have its own sops
# file but with the same tenant key value.  If a machine is compromised
# the admin rotates the key in sops and redeploys.
{ inputs, ... }: {
  flake.nixosModules.monitor365 =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (config.users) primaryUser;
      inherit (import ../../../lib/default.nix lib) ports;
      domain = config.networking.domain;

      systemAgentCfg = config.services.monitor365;
      serverCfg = config.services.monitor365-server;

      # Runtime deps — CLI tools for system + desktop collectors.
      # Wired into the systemd service PATH by the upstream module.
      runtimeDeps = with pkgs; [
        procps
        util-linux
        coreutils
        lm_sensors
        networkmanager
        bluez
        xdotool
        xprintidle
        scrot
        wmctrl # Window collector dependency (upstream warns if missing)
      ];
    in
    {
      imports = [
        inputs.monitor365.nixosModules.monitor365
        inputs.monitor365.nixosModules.monitor365-server
      ];

      config = lib.mkMerge [
        # ── Unified agent defaults ────────────────────────────────
        (lib.mkIf systemAgentCfg.enable {
          services.monitor365 = {
            runtimeDeps = lib.mkDefault runtimeDeps;
            graphicalUsers = lib.mkDefault [ primaryUser ];
            # Display discovery: the upstream start script uses pgrep to find
            # the displayUser's compositor (niri), reads DISPLAY/WAYLAND_DISPLAY/
            # XAUTHORITY/etc from /proc/<pid>/environ, and exports them before
            # exec. ProtectProc is relaxed to "default" below so pgrep can see
            # niri's PID. See the detailed comment near the ProtectProc override
            # for the full timing + restart mechanism.
            displayUser = lib.mkDefault primaryUser;

            settings = {
              device = {
                name = lib.mkDefault "${config.networking.hostName}";
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

              # Agent authenticates via LoadCredential — systemd reads
              # the sops secret as root and provisions it to the service.
              cloud = lib.mkIf serverCfg.enable {
                endpoint = lib.mkDefault "http://localhost:${toString ports.monitor365-server}";
                sync_interval_seconds = lib.mkDefault 60;
                authTokenFile = lib.mkDefault config.sops.secrets.cloud_auth_token.path;
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

            # CORS is unnecessary for this deployment: the WASM dashboard and
            # API are served from the same origin behind Caddy (monitor.<domain>).
            # The upstream module CAN emit MONITOR365_SERVER__CORS_ORIGINS as a
            # comma-separated string — the Rust config parser uses figment's
            # with_list_parse_key to correctly parse it into Vec<String> (fixed
            # upstream 2026-05-08, commit 1a11bc034). Set corsOrigins here only
            # if the dashboard is served from a different origin than the API.

            jwtSecretFile = lib.mkDefault config.sops.secrets.server_jwt_secret.path;
            environmentFile = lib.mkDefault config.sops.templates."monitor365-server-env".path;

            bootstrap = {
              enable = lib.mkDefault true;
              # Pre-provisioned tenant API key from sops — server and agent
              # all read the same underlying value.
              apiKeyFile = lib.mkDefault config.sops.secrets.cloud_auth_token.path;
            };

            sso = lib.mkIf (config.services.pocket-id.enable or false) {
              issuer = lib.mkDefault "https://auth.${domain}";
              clientSecretFile = lib.mkDefault "${
                config.services.pocket-id.dataDir or "/var/lib/pocket-id"
              }/client-secrets/monitor365";
              redirectUri = lib.mkDefault "https://monitor.${domain}/v1/auth/sso/callback";
            };
          };

          users.users.monitor365-server.extraGroups = lib.optional (
            serverCfg.sso.enable && (config.services.pocket-id.enable or false)
          ) "pocket-id";
        })

        # Backup health metrics — AGENTS.md rule 9: every new service MUST be
        # monitored. Writes Prometheus textfile metrics for backup freshness so
        # Gatus can alert if the nightly backup stops producing files.
        (lib.mkIf (serverCfg.enable && serverCfg.backup.enable or false) {
          systemd.services.monitor365-backup-health = {
            description = "Monitor365 backup health metrics for Prometheus textfile";
            after = [ "monitor365-server.service" ];
            serviceConfig = {
              Type = "oneshot";
              User = "monitor365-server";
              Group = "monitor365-server";
              StateDirectory = "monitor365-server";
              ReadWritePaths = [
                "/var/lib/prometheus-node-exporter/textfile_collectors"
              ];
            };
            script = ''
              OUT="/var/lib/prometheus-node-exporter/textfile_collectors/monitor365-backup.prom"
              BACKUP_DIR="${serverCfg.stateDir}"
              LATEST="$(ls -t "$BACKUP_DIR"/*.backup_*.db 2>/dev/null | head -1)"
              NOW="$(${pkgs.coreutils}/bin/date +%s)"
              if [ -n "$LATEST" ]; then
                MTIME="$(${pkgs.coreutils}/bin/stat -c %Y "$LATEST")"
                AGE_HOURS=$(( (NOW - MTIME) / 3600 ))
                HEALTHY=1
                [ "$AGE_HOURS" -gt 25 ] && HEALTHY=0
              else
                MTIME=0
                AGE_HOURS=999
                HEALTHY=0
              fi
              cat > "$OUT" <<EOF
              monitor365_backup_last_success_timestamp $MTIME
              monitor365_backup_age_hours $AGE_HOURS
              monitor365_backup_healthy $HEALTHY
              EOF
            '';
          };
          systemd.timers.monitor365-backup-health = {
            description = "Collect Monitor365 backup health metrics";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5m";
              OnUnitActiveSec = "5m";
            };
          };
        })

        # Restart both agent and server when the sops secret changes.
        (lib.mkIf (systemAgentCfg.enable || serverCfg.enable) {
          systemd.services.monitor365.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
          ];
          systemd.services.monitor365-server.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
          ];
        })

        # Display discovery: the upstream module's start script uses pgrep to
        # find the displayUser's compositor PID, reads DISPLAY, WAYLAND_DISPLAY,
        # XAUTHORITY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS from
        # /proc/<pid>/environ, and exports them before exec. This is verified
        # working — the heredoc command-substitution correctly propagates exports
        # to the exec'd binary (the prior "subshell issue" diagnosis was wrong:
        # the real blockers were ProtectProc=invisible hiding niri's PID, now
        # fixed via mkForce "default", and the service starting before login).
        #
        # Graphical input collectors (keystroke, mouse) need /dev/input/event*
        # read access — the input group grants this. Camera needs the video group
        # for V4L2 device access.
        #
        # Timing: monitor365 starts at boot (default.target) before any graphical
        # session. Graphical collectors fail 3 times and are "permanently disabled"
        # for the process lifetime. A systemd path unit below restarts the agent
        # when the Wayland socket appears (user login), re-running display
        # discovery so collectors initialize correctly.
        (lib.mkIf (systemAgentCfg.enable && systemAgentCfg.displayUser != null) {
          systemd = {
            services.monitor365 = {
              serviceConfig.ProtectProc = lib.mkForce "default";
            };

            # Restart the agent when the user's Wayland session appears so
            # display discovery runs after login (the service starts at boot
            # before niri exists, leaving graphical collectors disabled until
            # restart). Uses uid 1000 — deterministic on evo-x2 (SDDM+niri,
            # primary user lars). Update if a multi-host deployment is added.
            paths.monitor365-graphical-restart = {
              description = "Restart Monitor365 agent when graphical session starts";
              wantedBy = [ "paths.target" ];
              pathConfig = {
                PathExists = "/run/user/1000/wayland-1";
                Unit = "monitor365-graphical-restart.service";
              };
            };

            services.monitor365-graphical-restart = {
              description = "Restart Monitor365 agent after graphical session starts";
              serviceConfig = {
                Type = "oneshot";
              };
              script = ''
                if ${pkgs.systemd}/bin/systemctl is-active --quiet monitor365.service; then
                  ${pkgs.systemd}/bin/systemctl restart monitor365.service
                fi
              '';
            };
          };

          # Grant device access for graphical input + camera collectors.
          users.users.monitor365.extraGroups = [
            "input" # keystroke + mouse (/dev/input/event*)
            "video" # camera (V4L2 /dev/video*)
          ];
        })
      ];
    };
}
