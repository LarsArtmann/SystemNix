# Immich photo/video management: OAuth, PostgreSQL, automated backups
_: {
  flake.nixosModules.immich = {
    config,
    lib,
    ...
  }: let
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      serviceOneshotDefaults
      onFailure
      ports
      ;
    provisionEnabled = config.services.pocket-id-config.provision.enable or false;
    clientSecretPath =
      if provisionEnabled
      then "${config.services.pocket-id.dataDir}/client-secrets/immich"
      else config.sops.secrets.immich_oauth_client_secret.path;
  in {
    config = lib.mkIf config.services.immich.enable {
      services = {
        immich = {
          port = ports.immich;
          host = "127.0.0.1";
          openFirewall = false;
          mediaLocation = "/mnt/pool/services/immich";

          accelerationDevices = ["/dev/dri/renderD128"];

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
            (serviceDefaults {})
          ];
          immich-machine-learning.serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "4G";
              CPUQuota = "300%"; # ML inference (face detection, CLIP) can spike multi-core
              ProtectHome = lib.mkForce false;
              ProtectSystem = lib.mkForce false;
            })
            (serviceDefaults {RestartSec = "10s";})
            {
              Environment = lib.mkForce "HOME=/var/lib/immich";
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
            path = [config.services.postgresql.package];
            after = [
              "postgresql.service"
              "immich-server.service"
            ];
            requires = ["postgresql.service"];
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "256M";
                ProtectHome = false;
                ReadWritePaths = ["${config.services.immich.mediaLocation}/database-backup"];
              })
              (serviceOneshotDefaults {})
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
        };
        timers.immich-db-backup = {
          description = "Daily Immich database backup";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* 01:00:00";
            Persistent = true;
            RandomizedDelaySec = "10m";
          };
        };
      };
    };
  };
}
