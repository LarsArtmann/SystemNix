# Runbook: docs/services/immich.md
# Immich photo/video management: OAuth, PostgreSQL, automated backups
_: {
  flake.nixosModules.immich =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        ioTier
        mkImmichApiKeyProvision
        onFailure
        ports
        ;
      cfg = config.services.immich;
      keyDir = "/var/lib/immich-api-keys";
      provisionEnabled = config.services.pocket-id-config.provision.enable or false;
      clientSecretPath =
        if provisionEnabled then
          "${config.services.pocket-id.dataDir}/client-secrets/immich"
        else
          config.sops.secrets.immich_oauth_client_secret.path;
    in
    {
      options.services.immich.apiKeys = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                permissions = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [
                    "asset.read"
                    "asset.upload"
                  ];
                  description = ''
                    Immich Permission enum values inserted verbatim into the
                    generated key's api_key.permissions. Scope each consumer as
                    tightly as its job allows; "all" is accepted by Immich but
                    stays exceptional.
                  '';
                };
                keyFile = lib.mkOption {
                  type = lib.types.str;
                  default = "${keyDir}/${name}.env";
                  defaultText = lib.literalExpression ''"${keyDir}/<name>.env"'';
                  description = ''
                    Rendered secret, 0400. Carries IMMICH_URL + IMMICH_API_KEY
                    when `url` is set (env-file format), otherwise the bare
                    token — which fits tools that take the key as an argument.
                  '';
                };
                owner = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                  description = "Owner of the rendered key file.";
                };
                group = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                  description = "Group of the rendered key file.";
                };
                url = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Immich base URL baked into env-file format keys. null =
                    plain token file.
                  '';
                };
                restartUnits = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = ''
                    Units try-restarted after a FRESH mint only (a converged
                    key never restarts consumers).
                  '';
                };
              };
            }
          )
        );
        default = { };
        description = ''
          Immich API keys managed by the root converger
          (`immich-api-key-provision`): minted directly into Immich's api_key
          table via peer-auth postgres (Immich is OIDC-only, so no API-level
          bootstrap exists) and rendered to a 0400 file. Key material never
          lives in a sops file, a data directory, or a command line.
          Rotation: rm the key file + restart immich-api-key-provision.
        '';
      };

      config = lib.mkIf config.services.immich.enable {
        services = {
          immich = {
            port = ports.immich;
            host = "127.0.0.1";
            openFirewall = false;
            mediaLocation = "/mnt/pool/services/immich";

            accelerationDevices = [ "/dev/dri/renderD128" ];

            database.enable = true;
            redis.enable = true;
            machine-learning.enable = true;

            environment = {
              NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt";
              LIBVA_DRIVER_NAME = "radeonsi";
            };

            settings = {
              ffmpeg = {
                accel = "vaapi";
                accelDecode = true;
              };
              image.progressiveJpeg.enabled = true;
              metadata.faces.import = true;
              passwordLogin.enabled = false;
              oauth = {
                enabled = true;
                issuerUrl = "https://auth.${config.networking.domain}";
                clientId = "immich";
                clientSecret._secret = clientSecretPath;
                scope = "openid profile email";
                autoLaunch = true;
                autoRegister = true;
                buttonText = "Login with Pocket ID";
              };
            };
          };

          # Immich's redis defaults to a unix socket only (port 0), which the
          # Gatus tcp://127.0.0.1:<port> health check cannot reach. Enable a
          # localhost-only TCP listener IN ADDITION to the socket: immich still
          # connects over the (faster) unix socket via REDIS_SOCKET, while Gatus
          # can verify the cache is actually accepting connections. Redis listens
          # on both transports natively when both are configured.
          immich.redis.port = ports.redis;
          redis.servers.immich.bind = lib.mkForce "127.0.0.1";

          # PostgreSQL tuning for Immich workload
          postgresql.settings = {
            shared_buffers = "512MB";
            effective_cache_size = "2GB";
            work_mem = "16MB";
            maintenance_work_mem = "256MB";
            max_connections = 100;
            checkpoint_completion_target = "0.9";
            random_page_cost = "1.1";
          };
        };

        users.users.immich.extraGroups = [
          "video"
          "render"
        ];

        systemd = {
          services = {
            immich-server.serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "2G";
                ProtectHome = lib.mkForce false;
                ProtectSystem = lib.mkForce false;
              })
              (serviceDefaults { })
            ];
            immich-machine-learning.serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "4G";
                CPUQuota = "300%"; # ML inference (face detection, CLIP) can spike multi-core
                ProtectHome = lib.mkForce false;
                ProtectSystem = lib.mkForce false;
              })
              (serviceDefaults { RestartSec = "10s"; })
              # BE/5 heavyDB: bulk ONNX model loads at boot (the llama-chat
              # page-in class) then latency-sensitive inference serving.
              ioTier.heavyDB
              {
                Environment = lib.mkForce [ "HOME=/var/lib/immich" ];
              }
            ];
            immich-server = {
              after = lib.optional provisionEnabled "pocket-id-provision.service";
              wants = lib.optional provisionEnabled "pocket-id-provision.service";
              unitConfig.RequiresMountsFor = "/mnt/pool/services/immich";
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
            };
            immich-machine-learning = {
              unitConfig.RequiresMountsFor = "/mnt/pool/services/immich";
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
            };
            immich-db-backup = {
              description = "Immich PostgreSQL database backup";
              inherit onFailure;
              # ReadWritePaths targets the pool mediaLocation — gate on the
              # mount (mount-gating-audit class): a detached DAS must fail
              # loudly (226/NAMESPACE otherwise — the script's own mkdir runs
              # only AFTER namespace setup, too late to create the path).
              unitConfig.RequiresMountsFor = "/mnt/pool/services/immich";
              path = [ config.services.postgresql.package ];
              after = [
                "postgresql.service"
                "immich-server.service"
              ];
              requires = [ "postgresql.service" ];
              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "256M";
                  ProtectHome = false;
                  ReadWritePaths = [ "${config.services.immich.mediaLocation}/database-backup" ];
                })
                (serviceOneshotDefaults { })
                {
                  Type = "oneshot";
                  User = "immich";
                  Group = "immich";
                }
              ];
              script = ''
                set -euo pipefail
                backupDir="${config.services.immich.mediaLocation}/database-backup"
                mkdir -p "$backupDir"
                stamp="$(date +%Y%m%d-%H%M%S)"
                pg_dump --host=/run/postgresql --clean --if-exists --dbname=${config.services.immich.database.name} \
                  > "$backupDir/immich-$stamp.sql"
                find "$backupDir" -name "immich-*.sql" -mtime +7 -delete
                echo "immich-db-backup: completed -> immich-$stamp.sql"
              '';
            };

            # Root converger for every declared `services.immich.apiKeys.<name>`
            # (lib/immich-api-key-provision.nix): Immich is OIDC-only, so the
            # key is inserted straight into api_key via peer-auth postgres and
            # rendered to a 0400 file — key material never lands in a sops
            # file, a data directory, or a command line. One unit converges all
            # keys so a new consumer needs no unit/timer/deploy.sh churn.
            # Boot + daily timer cover DB-restore healing; the deploy.sh
            # provisioner loop re-converges on every deploy.
            immich-api-key-provision = lib.mkIf (cfg.apiKeys != { }) {
              description = "Immich API-key converger (direct api_key table insert via peer-auth postgres)";
              after = [ "postgresql.service" ];
              wants = [ "postgresql.service" ];
              wantedBy = [ "multi-user.target" ];
              inherit onFailure;
              serviceConfig = lib.mkMerge [
                (harden { MemoryMax = "128M"; })
                (serviceOneshotDefaults { })
                {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = lib.getExe (
                    mkImmichApiKeyProvision {
                      inherit pkgs config;
                      keys = cfg.apiKeys;
                    }
                  );
                  TimeoutStartSec = "2min";
                  # Root BY DESIGN: peer-auth postgres via runuser (no secret
                  # exists to authenticate with), key-file writes for other
                  # owners, and try-restart of the declared consumer units.
                  # NoNewPrivileges stays OFF — runuser is setuid.
                  NoNewPrivileges = false;
                  ProtectSystem = "strict";
                  ReadWritePaths = lib.unique (
                    [ keyDir ] ++ lib.mapAttrsToList (_: spec: builtins.dirOf spec.keyFile) cfg.apiKeys
                  );
                  PrivateTmp = true;
                }
                ioTier.background
              ];
            };
          };
          timers.immich-db-backup = {
            description = "Daily Immich database backup";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 01:00:00";
              Persistent = true;
              RandomizedDelaySec = "10m";
            };
          };
          immich-api-key-provision = lib.mkIf (cfg.apiKeys != { }) {
            description = "Daily Immich API-key convergence (DB-restore self-heal)";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "daily";
              Persistent = true;
              RandomizedDelaySec = "6h";
            };
          };
        };
        services.integration = lib.optionalAttrs (options ? services.integration) {
          immich = {
            enable = config.services.immich.enable;
            subdomain = "immich";
            port = config.services.immich.port;
            vHost.layer = "protected";
            # Caught by the tile-coverage assertion 2026-10-25: web-facing
            # since the registry entry exists but never carried a tile.
            homepage = {
              name = "Immich";
              group = "Media";
              description = "Photo & Video Library (SSO via vHost)";
              icon = "immich.png";
            };
            backup = {
              # mediaLocation moved to the mirrored pool 2026-08-16; the DB
              # backup timer writes next to the media it protects.
              directory = "/mnt/pool/services/immich/database-backup";
              maxAgeHours = 25;
            };
            oidc = {
              name = "Immich";
              clientId = "immich";
              launchURL = "https://immich.${config.networking.domain}";
              callbackURLs = [
                "https://immich.${config.networking.domain}/auth/login"
                "https://immich.${config.networking.domain}/user-settings"
                "app.immich:///oauth-callback"
              ];
              logoutCallbackURLs = [ "https://immich.${config.networking.domain}" ];
              pkceEnabled = true;
              logoFile = ../../../assets/immich-logo.svg;
            };
          };
        };
      };
    };
}
