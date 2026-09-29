# GeoMetrikks — native Nix service (Docker→Nix migration, 2026-09-29).
# Access-log geo analytics (github:GilbN/geometrikks) built from source via
# pkgs/geometrikks.nix (uv2nix venv + bun frontend), served by a native
# systemd unit, DB on the host's shared PostgreSQL cluster (TimescaleDB +
# PostGIS), SSO via native Pocket ID OIDC (Layer 1 plain vHost).
# Plan + rationale: docs/planning/2026-09-29_21-41_GEOMETRIKKS-NATIVE-NIX-MIGRATION.md
{ inputs, ... }: {
  flake.nixosModules.geometrikks =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers)
        harden
        ioTier
        serviceOneshotDefaults
        onFailure
        serviceTypes
        ports
        ;

      cfg = config.services.geometrikks;
      secretsDir = ./../../../platforms/nixos/secrets;
      domain = config.networking.domain;

      pkg = import ../../../pkgs/geometrikks.nix {
        inherit pkgs lib;
        inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
      };

      stateDir = "/var/lib/geometrikks";
      oidcEnvFile = "/var/lib/geometrikks-oidc/oidc.env";
      poolBackupDir = "/mnt/pool/backups/geometrikks";

      # Tail every Caddy access-log sink (host paths now — no container
      # mount mapping anymore). The nixpkgs caddy module writes each vhost
      # to access-<host>.log (file output => Caddy's default encoder is
      # JSON per caddyserver.com/docs/caddyfile/directives/log), and the
      # global access.log only receives un-matched traffic — so the FULL
      # list (global + every vhost) is the complete traffic picture.
      # Filenames replicate vhost-options.nix's own derivation: "/" and
      # " " -> "_". Derived from config.services.caddy.virtualHosts at
      # eval time, so new services are tracked automatically.
      logPaths = builtins.toJSON (
        [ "/var/log/caddy/access.log" ]
        ++ map (
          host:
          "/var/log/caddy/access-${
            lib.replaceStrings
              [
                "/"
                " "
              ]
              [
                "_"
                "_"
              ]
              host
          }.log"
        ) (builtins.attrNames config.services.caddy.virtualHosts)
      );

      # Stamp-gated copy of the store-shipped runtime assets into the
      # writable state dir: the app writes .litestar.json next to public/
      # and alembic resolves migrations/ relative to CWD (Dockerfile layout).
      assetsPreStart = pkgs.writeShellScript "geometrikks-assets" ''
        set -euo pipefail
        if [ "$(cat ${stateDir}/.assets-stamp 2>/dev/null || true)" != "${pkg}" ]; then
          rm -rf ${stateDir}/public ${stateDir}/migrations
          cp -r ${pkg}/share/geometrikks/public ${stateDir}/public
          cp -r ${pkg}/share/geometrikks/migrations ${stateDir}/migrations
          cp ${pkg}/share/geometrikks/alembic.ini ${stateDir}/alembic.ini
          chmod -R u+w ${stateDir}/public ${stateDir}/migrations
          echo "${pkg}" > ${stateDir}/.assets-stamp
        fi
        mkdir -p ${stateDir}/logs ${stateDir}/geoip
      '';

      # OIDC secret bridge: the Pocket ID provisioner owns the client
      # secret (dynamic, regenerated on client recreation — never in
      # sops). systemd reads the 0750 pocket-id-owned secret file as PID
      # 1 via LoadCredential; the bridge writes ALL OIDC vars together
      # (all-present-or-all-absent, the browser-history Validate()
      # crash-loop lesson).
      oidcBridge = pkgs.writeShellScript "geometrikks-oidc-env" ''
        set -euo pipefail
        secret="$(cat "$CREDENTIALS_DIRECTORY/pocket-id-secret")"
        case "$secret" in
          *[!A-Za-z0-9+/_=-]*)
            echo "geometrikks-oidc-env: Pocket ID client secret has unexpected characters — refusing to write env file" >&2
            exit 1
            ;;
        esac
        umask 077
        {
          echo "OIDC_ISSUER=https://auth.${domain}"
          echo "OIDC_CLIENT_ID=geometrikks"
          echo "OIDC_CLIENT_SECRET=$secret"
          echo "OIDC_REDIRECT_URI=https://geo.${domain}/api/v1/auth/oidc/callback"
          echo "OIDC_ALLOWED_USERS=${lib.concatStringsSep "," cfg.oidc.allowedUsers}"
          echo "OIDC_PROVIDER_NAME=Pocket ID"
        } > ${oidcEnvFile}.tmp
        mv ${oidcEnvFile}.tmp ${oidcEnvFile}
        echo "geometrikks-oidc-env: wrote ${oidcEnvFile}"
      '';

      # DB provisioning on the shared cluster (User=postgres, peer auth):
      # role password from the sops-rendered env (systemd injects it as
      # PID 1 — the postgres user never reads the 0400 root file), plus
      # the superuser-only extension installs and per-DB GUC tuning.
      # Charset-guarded inline literal (psql 17 does NOT interpolate :var
      # inside -c — the miniflux-oidc-setup lesson).
      dbProvision = pkgs.writeShellScript "geometrikks-db-provision" ''
        set -euo pipefail
        # Function, NOT a "psql -v ..." variable: a quoted variable expands
        # to ONE word (spaces included) and exec fails with 127 "No such file
        # or directory" (the 2026-09-29 live failure — quotes parse at
        # definition time only in functions).
        psql() {
          "${config.services.postgresql.package}/bin/psql" -v ON_ERROR_STOP=1 "$@"
        }

        # Bounded wait for the cluster + ensure-* machinery (nixpkgs runs
        # ensureDatabases/ensureUsers in postgresql.service postStart).
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
          if psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='geometrikks';" | grep -q 1; then
            break
          fi
          sleep 2
        done

        pw="''${DB_PASSWORD:-}"
        case "$pw" in
          *[!A-Za-z0-9+/_=-]*)
            echo "geometrikks-db-provision: DB_PASSWORD has unexpected characters — refusing" >&2
            exit 1
            ;;
        esac
        if [ -z "$pw" ]; then
          echo "geometrikks-db-provision: DB_PASSWORD empty" >&2
          exit 1
        fi

        psql -d postgres -c "ALTER ROLE geometrikks WITH LOGIN PASSWORD '$pw';"
        # Both extensions are superuser-only to create; the app's alembic
        # migration runs CREATE EXTENSION IF NOT EXISTS postgis itself and
        # server/timescale.py applies the TimescaleDB objects — both find
        # the extension already present.
        psql -d geometrikks \
          -c "CREATE EXTENSION IF NOT EXISTS timescaledb;" \
          -c "CREATE EXTENSION IF NOT EXISTS postgis;" \
          -c "ALTER DATABASE geometrikks SET max_parallel_workers = '8';"
        echo "geometrikks-db-provision: role password set, extensions ensured, per-DB tuning applied"
      '';

      dbBackup = pkgs.writeShellScript "geometrikks-db-backup" ''
        set -euo pipefail
        ${config.services.postgresql.package}/bin/pg_dump -d geometrikks \
          > ${poolBackupDir}/$(date +%Y%m%d_%H%M%S).sql
        find ${poolBackupDir} -name "*.sql" -mtime +14 -delete
        echo "geometrikks-db-backup: dump landed in ${poolBackupDir}"
      '';
    in
    {
      # Platform-truth catalog entry (ADR-008): unconditional — GeoMetrikks
      # exists platform-wide even where this host has it disabled.
      imports = [
        {
          services.catalog.geometrikks = {
            subdomain = "geo";
            port = ports.geometrikks;
            description = "GeoMetrikks access-log geo analytics (native)";
            healthPath = "/health/ready";
          };
        }
      ];

      options.services.geometrikks = {
        enable = lib.mkEnableOption "GeoMetrikks access-log geo analytics (native Nix service)";

        port = serviceTypes.servicePort ports.geometrikks "Port for the GeoMetrikks UI";

        oidc.allowedUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "lars@larsartmann.cloud" ];
          description = ''
            Verified email addresses (or subject identifiers) allowed to sign
            in via Pocket ID (OIDC_ALLOWED_USERS — upstream REQUIRES a
            non-empty allow list). The admin password login stays available as
            break-glass while APP_ADMIN_PASSWORD is set.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.caddy.enable or false;
            message = "services.geometrikks needs services.caddy — it tails Caddy's access logs";
          }
          {
            assertion = cfg.oidc.allowedUsers != [ ];
            message = "services.geometrikks.oidc.allowedUsers must be non-empty — upstream refuses to start OIDC without an allow list";
          }
        ];

        users.users.geometrikks = {
          isSystemUser = true;
          group = "geometrikks";
          home = stateDir;
          description = "GeoMetrikks service user";
        };
        users.groups.geometrikks = { };

        # Shared PG cluster: TimescaleDB + PostGIS plugins, preload, and
        # worker headroom (upstream tunes 40 bg workers for ~32 TimescaleDB
        # jobs + CAGG refresh policies; max_worker_processes is the only
        # POSTMASTER-level knob, so it lands globally — harmless headroom
        # for the paperless/immich/miniflux co-tenants).
        services.postgresql = {
          enable = true;
          ensureDatabases = [ "geometrikks" ];
          ensureUsers = [
            {
              name = "geometrikks";
              ensureDBOwnership = true;
            }
          ];
          extensions = ps: [
            ps.timescaledb
            ps.postgis
          ];
          settings = {
            shared_preload_libraries = [ "timescaledb" ];
            max_worker_processes = 48;
            # POSTMASTER-class (same as max_worker_processes): PG17 rejects
            # `ALTER DATABASE SET` on it ("cannot be changed without restarting
            # the server" — live 2026-09-29, exit-4'd the activation), so it
            # lives HERE, not in the provision script. Quoted key: a bare
            # dotted name nests attrsets and fails the INI-flat settings type.
            "timescaledb.max_background_workers" = 32;
          };
        };

        sops = {
          secrets =
            lib.genAttrs
              [
                "geometrikks_admin_password"
                "geometrikks_db_password"
                "geometrikks_maxmind_user_id"
                "geometrikks_maxmind_license_key"
                "geometrikks_carto_api_key"
              ]
              (_: {
                sopsFile = lib.path.append secretsDir "geometrikks.yaml";
                owner = "root";
                group = "root";
                restartUnits = [ "geometrikks.service" ];
              });
          templates."geometrikks-env" = {
            owner = "root";
            group = "root";
            mode = "0400";
            content = ''
              APP_ADMIN_USER=admin
              APP_ADMIN_PASSWORD=${config.sops.placeholder.geometrikks_admin_password}
              APP_SESSION_SECURE=true
              # Caddy proxies from loopback on this host (plain reverse_proxy)
              APP_TRUSTED_PROXIES=127.0.0.1
              # Empty = geo-degraded (UI banner, no GeoLite2 download attempt)
              # — the go-live paste is user-gated (free maxmind.com signup).
              MAXMINDDB_USER_ID=${config.sops.placeholder.geometrikks_maxmind_user_id}
              MAXMINDDB_LICENSE_KEY=${config.sops.placeholder.geometrikks_maxmind_license_key}
              MAP_CARTO_API_KEY=${config.sops.placeholder.geometrikks_carto_api_key}
              DB_PASSWORD=${config.sops.placeholder.geometrikks_db_password}
            '';
          };
        };

        systemd = {
          services = {
            # The native service. Same unit name as the former Docker
            # wrapper — switch-to-configuration swaps it atomically.
            geometrikks = {
              description = "GeoMetrikks — access-log geo analytics (native)";
              documentation = [ "https://github.com/GilbN/geometrikks" ];
              wantedBy = [ "multi-user.target" ];
              after = [
                "network-online.target"
                "postgresql.service"
                "geometrikks-db-provision.service"
                "geometrikks-oidc-env.service"
              ];
              wants = [
                "network-online.target"
                "geometrikks-db-provision.service"
                "geometrikks-oidc-env.service"
              ];

              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "2G";
                  # Reads Caddy's 0600 caddy:caddy access logs (read-only
                  # under ProtectSystem=strict; DAC bypass for foreign
                  # ownership — cv-backup precedent).
                  CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
                })
                ioTier.background
                {
                  User = "geometrikks";
                  Group = "geometrikks";
                  StateDirectory = "geometrikks";
                  WorkingDirectory = stateDir;
                  EnvironmentFile = [
                    config.sops.templates."geometrikks-env".path
                    "-${oidcEnvFile}"
                  ];
                  ExecStartPre = [ "${assetsPreStart}" ];
                  ExecStart = "${pkg}/bin/geometrikks-server";
                  # Cold start: alembic migrations on a fresh DB + schema
                  # wait; granian teardown drains ingestion (15s kill
                  # timeout inside the wrapper).
                  TimeoutStartSec = "5min";
                  TimeoutStopSec = "45s";
                }
              ];
              environment = {
                GEOMETRIKKS_HOST = "127.0.0.1";
                GEOMETRIKKS_PORT = toString cfg.port;
                # Disable dotenv loading entirely — all config rides real
                # environment variables (upstream GEOMETRIKKS_ENV_FILE).
                GEOMETRIKKS_ENV_FILE = "";
                PYTHONUNBUFFERED = "1";
                DB_HOST = "127.0.0.1";
                DB_PORT = "5432";
                DB_USER = "geometrikks";
                DB_DATABASE = "geometrikks";
                DB_STARTUP_WAIT_SECONDS = "60";
                LOGPARSER_LOG_PATHS = logPaths;
                LOGPARSER_HOST_NAME = "evo-x2";
                LOG_DIR = "${stateDir}/logs";
                GEOIP_DB_PATH = "${stateDir}/geoip/GeoLite2-City.mmdb";
                GEOIP_ASN_DB_PATH = "${stateDir}/geoip/GeoLite2-ASN.mmdb";
                GEOIP_VALIDATE_DB_PATH = "false";
                VITE_DEV_MODE = "false";
              };
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              inherit onFailure;
            };

            # Role password + superuser extensions + per-DB tuning on the
            # shared cluster. Converger: re-runs via the deploy.sh
            # provisioner loop (matches the -provision pattern; the
            # deploy-restart-audit guard enforces the wiring).
            geometrikks-db-provision = {
              description = "GeoMetrikks DB provisioning (role, extensions, tuning)";
              wantedBy = [ "multi-user.target" ];
              after = [ "postgresql.service" ];
              wants = [ "postgresql.service" ];
              serviceConfig = lib.mkMerge [
                (serviceOneshotDefaults { })
                {
                  Type = "oneshot";
                  User = "postgres";
                  EnvironmentFile = [ config.sops.templates."geometrikks-env".path ];
                  ExecStart = "${dbProvision}";
                  RemainAfterExit = true;
                  TimeoutStartSec = "2min";
                }
              ];
            };

            # Pocket ID client secret → OIDC env file (indirect unit: the
            # provisioner loop's is-enabled gate skips it — deploy.sh carries
            # a dedicated is-active-gated block restarting bridge + daemon,
            # the dnsblockd-oidc-secret pattern).
            geometrikks-oidc-env = {
              description = "GeoMetrikks OIDC env bridge (Pocket ID client secret)";
              wantedBy = [ "geometrikks.service" ];
              after = [ "pocket-id-provision.service" ];
              wants = [ "pocket-id-provision.service" ];
              # Condition-gated like paperless-oidc-setup: on the FIRST deploy
              # carrying the OIDC client registration the Pocket ID
              # provisioner has not created the secret yet — a condition-skip
              # no-op beats a failed unit exit-4'ing the activation. deploy.sh
              # converges bridge+daemon after the provisioner loop.
              unitConfig.ConditionPathExists = [
                "${config.services.pocket-id.dataDir}/client-secrets/geometrikks"
              ];
              serviceConfig = lib.mkMerge [
                (serviceOneshotDefaults { })
                {
                  Type = "oneshot";
                  User = "geometrikks";
                  Group = "geometrikks";
                  StateDirectory = "geometrikks-oidc";
                  LoadCredential = [
                    "pocket-id-secret:${config.services.pocket-id.dataDir}/client-secrets/geometrikks"
                  ];
                  ExecStart = "${oidcBridge}";
                  RemainAfterExit = true;
                }
              ];
            };

            # Mount-gated pool leaf creator (miniflux-backup-dir pattern:
            # RequiresMountsFor + ReadWritePaths on the MOUNT ROOT so a
            # fresh pool's missing leaf cannot 226 the namespace; deploy.sh
            # provisioner-restarted).
            geometrikks-backup-dir = {
              description = "GeoMetrikks backup directory (pool leaf)";
              wantedBy = [ "multi-user.target" ];
              unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  User = "root";
                  RemainAfterExit = true;
                }
                (harden {
                  MemoryMax = "128M";
                  ReadWritePaths = [ "/mnt/pool" ];
                  CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
                })
                (serviceOneshotDefaults { })
              ];
              script = ''
                mkdir -p ${poolBackupDir}
                chown postgres:postgres ${poolBackupDir}
                chmod 0750 ${poolBackupDir}
              '';
            };

            # Nightly pg_dump on the native cluster (peer auth as postgres).
            geometrikks-db-backup = {
              description = "GeoMetrikks nightly pg_dump to the pool";
              after = [
                "geometrikks-backup-dir.service"
                "postgresql.target"
              ];
              wants = [
                "geometrikks-backup-dir.service"
                "postgresql.target"
              ];
              serviceConfig = lib.mkMerge [
                (serviceOneshotDefaults { })
                {
                  Type = "oneshot";
                  User = "postgres";
                  ExecStart = "${dbBackup}";
                  RequiresMountsFor = [ "/mnt/pool" ];
                  TimeoutStartSec = "10min";
                }
              ];
              onFailure = onFailure;
            };
          };

          timers.geometrikks-db-backup = {
            description = "GeoMetrikks nightly pg_dump";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 05:15:00";
              Persistent = true;
              RandomizedDelaySec = "10m";
            };
          };
        };

        # Service-integration registry entry: the geo tile, the geo vHost —
        # LAYER 1 PLAIN now (native OIDC behind protectedVHost would
        # double-auth), pg_dump backup freshness, unit-state monitoring,
        # and the Gatus health check.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          geometrikks = {
            inherit (cfg) enable;
            subdomain = "geo";
            inherit (cfg) port;
            vHost.layer = "plain";
            monitored = true;
            oidc = {
              name = "GeoMetrikks";
              clientId = "geometrikks";
              launchURL = "https://geo.${domain}";
              callbackURLs = [ "https://geo.${domain}/api/v1/auth/oidc/callback" ];
              # Upstream uses the authorization code flow WITH PKCE.
              pkceEnabled = true;
            };
            checks = [
              {
                name = "GeoMetrikks";
                group = "Monitoring";
                url = "http://localhost:${toString cfg.port}/health/ready";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "GeoMetrikks down — access-log geo analytics unreachable";
              }
            ];
            homepage = {
              name = "GeoMetrikks";
              group = "Infrastructure";
              description = "Access-log geo analytics (live world map)";
              icon = "mdi-earth";
            };
            backup = {
              directory = poolBackupDir;
              maxAgeHours = 31;
            };
          };
        };
      };
    };
}
