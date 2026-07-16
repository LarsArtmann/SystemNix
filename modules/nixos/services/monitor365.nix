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
      inherit (import ../../../lib/default.nix lib)
        ports
        harden
        serviceOneshotDefaults
        ;
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

            # NOTE: corsOrigins intentionally NOT set here.  The upstream module
            # emits it as MONITOR365_SERVER__CORS_ORIGINS (comma-separated string),
            # but the server's Rust config parser expects a TOML sequence, not a
            # string — causing a fatal parse error on startup.  CORS is unnecessary
            # anyway: the WASM dashboard and API are served from the same origin
            # behind Caddy (monitor.<domain>).  Fix the upstream module to use a
            # config file for sequence types if CORS is ever needed.

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

          # Grant pocket-id group to server user for SSO secret access
          users.users.monitor365-server.extraGroups = lib.optional (
            serverCfg.sso.enable && (config.services.pocket-id.enable or false)
          ) "pocket-id";
        })

        # ── API Key Sync ───────────────────────────────────────────
        # The upstream bootstrap is idempotent — it reads the API key
        # from sops ONLY on first boot (when no tenants exist). If the
        # sops secret is rotated or was initially empty, the server's DB
        # retains a stale key hash while the agent sends the current
        # value, causing 401 Unauthorized on every request.
        #
        # This oneshot runs before the server starts and re-syncs the
        # sops secret's SHA-256 hash into the tenants table so the agent
        # and server always agree on the key.
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-api-key-sync = {
            description = "Sync monitor365 API key from sops to DuckDB";
            wantedBy = [ "monitor365-server.service" ];
            before = [ "monitor365-server.service" ];

            path = [
              pkgs.duckdb
              pkgs.coreutils
              pkgs.gnused
              pkgs.gnugrep
            ];

            serviceConfig = lib.mkMerge [
              (harden { })
              (serviceOneshotDefaults { })
              {
                User = "monitor365-server";
                Group = "monitor365-server";
                StateDirectory = "monitor365-server";
              }
            ];

            script = ''
              DB="${serverCfg.stateDir}/monitor365.duckdb"
              SECRET="${config.sops.secrets.cloud_auth_token.path}"

              # Skip if DB doesn't exist yet (first boot — bootstrap handles it)
              if [ ! -f "$DB" ]; then
                echo "Database not found, skipping API key sync (first boot)"
                exit 0
              fi

              # Skip if secret file isn't readable
              if [ ! -r "$SECRET" ]; then
                echo "Secret file not readable, skipping API key sync"
                exit 0
              fi

              # Read and trim the token to match upstream Rust String::trim().
              # sed strips leading/trailing whitespace (including \r from CRLF);
              # $() strips the trailing newline. Matches the server's
              # bootstrap read_secret_with_retry() + trim().
              TOKEN=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$SECRET")

              # Guard against empty token — writing SHA256("") recreates the
              # original desync bug (server stores empty hash, agent sends real key).
              if [ -z "$TOKEN" ]; then
                echo "WARNING: cloud_auth_token is empty — skipping sync to avoid writing SHA256(\"\")"
                echo "Fix the sops secret and redeploy"
                exit 0
              fi

              # Compute SHA-256 hash matching the server's ApiKeyHash::from_key().
              # printf '%s' avoids adding a trailing newline (matches Rust's exact bytes).
              HASH=$(printf '%s' "$TOKEN" | sha256sum | cut -d' ' -f1)

              # Validate hash format before SQL interpolation (defense-in-depth).
              # SHA-256 hex is always 64 lowercase hex chars — anything else is a bug.
              if ! printf '%s' "$HASH" | grep -qE '^[0-9a-f]{64}$'; then
                echo "ERROR: Computed hash has unexpected format (expected 64 hex chars, got $(printf '%s' "$HASH" | wc -c) chars)"
                exit 1
              fi

              # Check if key is already in sync — skip unnecessary writes.
              EXISTING=$(duckdb "$DB" -c "SELECT api_key FROM tenants LIMIT 1;" 2>&1 || echo "")
              if echo "$EXISTING" | grep -q "$HASH"; then
                echo "API key already in sync — no update needed"
                exit 0
              fi

              echo "Syncing API key hash to DuckDB..."

              # Update all tenants' API key hash (single-tenant deployment = 1 row).
              # Non-fatal on failure — the server starts with the existing key.
              if duckdb "$DB" -c "UPDATE tenants SET api_key = '$HASH';"; then
                # Verify the update took effect by reading back the hash.
                VERIFY=$(duckdb "$DB" -c "SELECT api_key FROM tenants LIMIT 1;" 2>&1 || echo "")
                if echo "$VERIFY" | grep -q "$HASH"; then
                  echo "API key synced and verified successfully"
                else
                  echo "WARNING: UPDATE returned success but verification mismatch — server may use stale key"
                fi
              else
                echo "WARNING: Failed to update API key in DuckDB (non-fatal — server starts with existing key)"
                exit 0
              fi
            '';
          };
        })
      ];
    };
}
