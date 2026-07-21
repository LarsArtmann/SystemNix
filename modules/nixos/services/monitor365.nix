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
            # Display discovery: the start script reads the primary user's
            # compositor PID via pgrep, extracts DISPLAY/WAYLAND_DISPLAY/etc
            # from /proc/<pid>/environ, and exports them before exec. This
            # enables clipboard/screenshot/AFK collectors from the system
            # service — no separate graphical-helper user service needed.
            # The agent has CAP_SYS_PTRACE (set upstream) to read other
            # users' /proc environ despite ProtectProc=invisible.
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

        # Restart both agent and server when the sops secret changes.
        (lib.mkIf (systemAgentCfg.enable || serverCfg.enable) {
          systemd.services.monitor365.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
          ];
          systemd.services.monitor365-server.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
          ];
        })

        # Display discovery: the upstream module's inline pgrep/heredoc approach
        # in the start script is fragile (the export vars don't survive into the
        # exec'd binary in some systemd/cgroup configurations). This ExecStartPre
        # discovers the display env and writes it to a file that systemd loads
        # via EnvironmentFile — more robust than bash export in a subshell.
        # Also relaxes ProtectProc from "invisible" to "default" so pgrep can
        # see the primary user's processes (the service already has CAP_SYS_PTRACE
        # for process monitoring, making ProtectProc redundant defense-in-depth).
        (lib.mkIf (systemAgentCfg.enable && systemAgentCfg.displayUser != null) {
          systemd.services.monitor365 =
            let
              displayDiscover = pkgs.writeShellApplication {
                name = "monitor365-discover-display";
                runtimeInputs = [ pkgs.procps pkgs.coreutils ];
                text = ''
                  ENV_FILE="/run/monitor365/display.env"
                  DISPLAY_USER="${systemAgentCfg.displayUser}"
                  DISPLAY_PID="$(pgrep -u "$DISPLAY_USER" "niri|sway|gnome-shell|weston|kwin_wayland|Xorg|Labwc|hyprland" 2>/dev/null | head -1)"
                  if [ -z "$DISPLAY_PID" ]; then
                    DISPLAY_PID="$(pgrep -u "$DISPLAY_USER" 2>/dev/null | head -1)"
                  fi
                  if [ -n "$DISPLAY_PID" ] && [ -r "/proc/$DISPLAY_PID/environ" ]; then
                    tr '\0' '\n' < "/proc/$DISPLAY_PID/environ" 2>/dev/null \
                      | grep -E '^(DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XKB_DEFAULT_)=' \
                      > "$ENV_FILE" || true
                    echo "monitor365: discovered display env from $DISPLAY_USER (PID $DISPLAY_PID)" >&2
                  else
                    : > "$ENV_FILE"
                    echo "monitor365: no graphical session found for $DISPLAY_USER — clipboard/screenshot collectors will skip" >&2
                  fi
                '';
              };
            in
            {
              serviceConfig = {
                ProtectProc = lib.mkForce "default";
                ExecStartPre = [
                  "${pkgs.coreutils}/bin/mkdir -p /run/monitor365"
                  "+${lib.getExe displayDiscover}"
                ];
                EnvironmentFile = "-/run/monitor365/display.env";
              };
            };
        })

      ];
    };
}
