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
      # X11 tools (xdotool, xprintidle, scrot, wmctrl) are kept for upstream
      # compatibility but are non-functional on niri (Wayland-only).
      # Wayland equivalents (grim, slurp, wtype) are provided for the
      # screenshot/keyboard collectors once upstream supports them.
      runtimeDeps = with pkgs; [
        procps
        util-linux
        coreutils
        lm_sensors
        networkmanager
        bluez
        # X11 (legacy — evo-x2 runs Wayland-only niri)
        xdotool
        xprintidle
        scrot
        wmctrl
        # Wayland (functional on niri)
        grim
        slurp
        wtype
      ];

      schemaMigrateScript = pkgs.writeShellApplication {
        name = "monitor365-schema-migrate";
        runtimeInputs = [ pkgs.duckdb ];
        text = ''
          DB="${serverCfg.stateDir}/monitor365.duckdb"
          if [ -f "$DB" ] && [ -s "$DB" ]; then
            duckdb "$DB" -c \
              "ALTER TABLE tenants ADD COLUMN IF NOT EXISTS version INTEGER;"

            # Raise the daily event upload limit to 1B so the 597M-event
            # backlog from the integrity-hash fix can drain in ~1 day
            # instead of ~163 years (10K/day default from upstream
            # crates/api-types/src/tenant.rs:39).
            duckdb "$DB" -c \
              "UPDATE tenants SET max_events_per_day = 1000000000;" \
              && echo "monitor365-schema-migrate: max_events_per_day set to 1B" \
              || echo "monitor365-schema-migrate: WARNING — could not update max_events_per_day"

            echo "monitor365-schema-migrate: migrations complete"
          else
            echo "monitor365-schema-migrate: DB not found or empty, skipping"
          fi
        '';
      };

      # Heal DuckDB before the server starts: remove a stale WAL from an
      # unclean shutdown (DuckDB checkpoints + deletes the WAL on graceful
      # exit, so a present WAL always means a crash) and restore the main DB
      # from the newest nightly backup if it is missing or empty.
      duckdbHealScript = pkgs.writeShellApplication {
        name = "monitor365-duckdb-heal";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          DB_DIR="${serverCfg.stateDir}"
          WAL="$DB_DIR/monitor365.duckdb.wal"
          MAIN_DB="$DB_DIR/monitor365.duckdb"

          if [ -f "$WAL" ]; then
            echo "monitor365-duckdb-heal: WAL from unclean shutdown found, removing to prevent replay crash"
            rm -f "$WAL"
          fi

          # If the main DB is missing or empty, restore from the most
          # recent nightly backup before the server starts.
          if [ ! -f "$MAIN_DB" ] || [ ! -s "$MAIN_DB" ]; then
            LATEST_BACKUP="$(
              find "$DB_DIR" -maxdepth 1 -name '*.backup_*.db' -printf '%T@\t%p\n' 2>/dev/null \
                | sort -rn | cut -f2- | head -1
            )"
            if [ -n "$LATEST_BACKUP" ]; then
              echo "monitor365-duckdb-heal: main DB missing/empty, restoring from backup: $LATEST_BACKUP"
              cp "$LATEST_BACKUP" "$MAIN_DB"
            else
              echo "monitor365-duckdb-heal: main DB missing/empty, no backup found — server will create fresh DB"
            fi
          fi
        '';
      };
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

        # Restart both agent and server when the sops secret or package changes.
        # Package triggers ensure services restart after flake updates even if
        # switch-to-configuration doesn't detect the unit-file change.
        (lib.mkIf (systemAgentCfg.enable || serverCfg.enable) {
          systemd.services.monitor365.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
            systemAgentCfg.package
          ];
          systemd.services.monitor365-server.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
            serverCfg.package
          ];
        })

        # DuckDB WAL corruption self-healing — same defensive pattern as the
        # SigNoz migration-lock clear. When the server crashes mid-write (OOM,
        # WDT reset, power loss), the WAL file can end up corrupt: DuckDB's
        # replay fails with "Failure while replaying WAL file … Calling
        # DatabaseManager::GetDefaultDatabase with no default database set"
        # (an INTERNAL/assertion error). The server crash-loops indefinitely
        # (291+ restarts observed), leaving port 3001 unreachable — the
        # agent's circuit breaker opens (220K+ consecutive failures), all
        # telemetry accumulates in the disk buffer, and events are dropped.
        #
        # DuckDB checkpoints the WAL into the main DB on graceful shutdown and
        # deletes the .wal file. A .wal present at startup ALWAYS means the
        # previous shutdown was unclean. Always removing it eliminates this
        # crash class entirely. The data loss is limited to events from the
        # last uncheckpointed session (acceptable for a monitoring dashboard).
        # If the main DB is also gone, restore from the nightly backup.
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-server = {
            serviceConfig = {
              ExecStartPre = lib.mkBefore [
                (lib.getExe duckdbHealScript)
              ];
            };
          };
        })

        # Schema migration: add 'version' column to tenants table for existing DBs.
        # Upstream bug at pinned commit 0615301: schema.sql includes
        # 'version INTEGER NOT NULL DEFAULT 0' in CREATE TABLE IF NOT EXISTS
        # tenants, but no ALTER TABLE migration exists for DBs created before
        # the column was added. Every SELECT using COLUMNS (which has
        # COALESCE(tenants.version, 0)) fails with a Binder Error.
        #
        # This runs as a SEPARATE service because the monitor365-server's
        # hardened SystemCallFilter=@system-service blocks the duckdb CLI's
        # C++ thread creation (clone3 syscall). ExecStartPre inherits the
        # service's sandbox, so the migration must run outside it.
        # NOTE: DuckDB ALTER TABLE does not support NOT NULL or DEFAULT
        # constraints — use bare INTEGER. The Rust COALESCE handles NULLs.
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-schema-migrate = {
            description = "Monitor365 DuckDB schema migration";
            before = [ "monitor365-server.service" ];
            wantedBy = [ "multi-user.target" ];
            restartTriggers = [ (lib.getExe schemaMigrateScript) ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = "monitor365-server";
              Group = "monitor365-server";
              StateDirectory = "monitor365-server";
            };
            script = lib.getExe schemaMigrateScript;
          };
          systemd.services.monitor365-server = {
            after = [ "monitor365-schema-migrate.service" ];
            requires = [ "monitor365-schema-migrate.service" ];
          };
        })

        # ── Agent resilience: start-limit + self-healing ──────────────
        # The upstream module doesn't set StartLimitBurst/StartLimitIntervalSec,
        # so systemd defaults (5/10s) apply. When the agent exits rapidly
        # (e.g. niri restart triggering graphical-restart path unit multiple
        # times in 1 second), the default limit is hit immediately and the
        # agent stays dead until the next deploy. Set generous limits so
        # transient crashes self-heal.
        (lib.mkIf systemAgentCfg.enable {
          systemd.services.monitor365 = {
            startLimitBurst = 10;
            startLimitIntervalSec = 300;
          };
        })

        # Agent health watchdog: periodically verify the agent is running,
        # its metrics endpoint responds, and the server sees it as a connected
        # device. If any check fails, reset start-limit and restart the agent.
        # This breaks the circuit-breaker deadlock (CB is in-memory; restart
        # clears it) and ensures the agent recovers from crashes that deploy.sh
        # misses (deploy only does reset-failed, not start).
        (lib.mkIf (systemAgentCfg.enable && serverCfg.enable) {
          systemd.services.monitor365-agent-watchdog = {
            description = "Monitor365 agent health watchdog";
            after = [
              "monitor365-server.service"
              "monitor365.service"
            ];
            serviceConfig = {
              Type = "oneshot";
              # Must run as root — the watchdog calls `systemctl start/restart`
              # on system services, which requires root. The monitor365 user
              # cannot start system services.
              NoNewPrivileges = true;
              PrivateTmp = true;
            };
            path = with pkgs; [
              systemd
              curl
              jq
            ];
            script = ''
              AGENT_METRICS="http://localhost:${toString ports.monitor365-metrics}/metrics"
              SERVER_HEALTH="http://localhost:${toString ports.monitor365-server}/health"

              # 1. Is the agent process alive?
              if ! systemctl is-active --quiet monitor365.service; then
                echo "monitor365-agent-watchdog: agent is NOT active — resetting start-limit and starting"
                systemctl reset-failed monitor365.service 2>/dev/null || true
                systemctl start monitor365.service || true
                exit 0
              fi

              # 2. Is the agent's metrics endpoint responding?
              if ! curl -sf -m 5 "$AGENT_METRICS" >/dev/null 2>&1; then
                echo "monitor365-agent-watchdog: agent metrics endpoint unreachable — restarting"
                systemctl restart monitor365.service || true
                exit 0
              fi

              # 3. Does the server see the agent as a connected device?
              # This catches the circuit-breaker deadlock: agent is alive and
              # metrics respond, but it can't upload to the server (CB open
              # with 700K+ failures). Restarting clears the in-memory CB.
              REALTIME=$(curl -sf -m 5 "$SERVER_HEALTH" 2>/dev/null \
                | jq -r '.realtime // empty' 2>/dev/null || echo "")
              if [ -n "$REALTIME" ] && echo "$REALTIME" | grep -q "connected (0 devices)"; then
                echo "monitor365-agent-watchdog: server reports 0 devices — circuit breaker deadlock, restarting agent"
                systemctl restart monitor365.service || true
                exit 0
              fi

              echo "monitor365-agent-watchdog: agent healthy (process active, metrics responding, server connected)"
            '';
          };

          systemd.timers.monitor365-agent-watchdog = {
            description = "Periodic Monitor365 agent health check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = "5min";
            };
          };
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
            #
            # PathChanged (not PathExists!) is CRITICAL: PathExists re-fires in
            # a tight loop during deploy — the file already exists, the service
            # exits 0, systemd re-evaluates the condition, fires again → 8
            # starts in 1 second → start-limit-hit on both the service AND the
            # path unit. PathChanged only fires when the file is CREATED or
            # MODIFIED, not when the path unit starts with the file already
            # present. During deploy (user logged in), the socket doesn't change
            # → no trigger. After boot (user logs in), the socket is created →
            # triggers once → agent restarts with display discovery.
            #
            # The oneshot script adds a 60s debounce to handle niri bouncing
            # the Wayland socket during DRM zombie recovery.
            paths.monitor365-graphical-restart = {
              description = "Restart Monitor365 agent when graphical session starts";
              wantedBy = [ "paths.target" ];
              pathConfig = {
                PathChanged = "/run/user/1000/wayland-1";
                Unit = "monitor365-graphical-restart.service";
              };
            };

            services.monitor365-graphical-restart = {
              description = "Restart Monitor365 agent after graphical session starts";
              serviceConfig = {
                Type = "oneshot";
              };
              script = ''
                # Skip if the service is not running (start-limit-hit, dead, etc.)
                if ! ${pkgs.systemd}/bin/systemctl is-active --quiet monitor365.service; then
                  echo "monitor365-graphical-restart: agent not active, skipping restart (watchdog will recover)"
                  exit 0
                fi

                # Skip if the agent was started less than 60s ago (debounce:
                # prevents rapid-restart storm during niri Wayland socket bounce)
                AGENT_UPTIME=$(${pkgs.systemd}/bin/systemctl show -p ActiveEnterTimestamp --value monitor365.service 2>/dev/null)
                if [ -n "$AGENT_UPTIME" ]; then
                  NOW=$(${pkgs.coreutils}/bin/date +%s)
                  STARTED=$(${pkgs.coreutils}/bin/date -d "$AGENT_UPTIME" +%s 2>/dev/null || echo 0)
                  if [ "$STARTED" -gt 0 ]; then
                    ELAPSED=$((NOW - STARTED))
                    if [ "$ELAPSED" -lt 60 ]; then
                      echo "monitor365-graphical-restart: agent started ''${ELAPSED}s ago, skipping (debounce <60s)"
                      exit 0
                    fi
                  fi
                fi

                echo "monitor365-graphical-restart: restarting agent for display discovery"
                ${pkgs.systemd}/bin/systemctl restart monitor365.service
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
