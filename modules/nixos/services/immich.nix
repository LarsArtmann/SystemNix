# Immich photo/video management: OAuth, PostgreSQL, automated backups
_: {
  flake.nixosModules.immich = {
    config,
    lib,
    ...
  }: let
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure ports;
    provisionEnabled = config.services.pocket-id-config.provision.enable or false;
    clientSecretPath =
      if provisionEnabled
      then "${config.services.pocket-id.dataDir}/client-secrets/immich"
      else config.sops.secrets.immich_oauth_client_secret.path;
  in {
    config = lib.mkIf config.services.immich.enable {
      services.immich = {
        port = ports.immich;
        host = "127.0.0.1";
        openFirewall = false;
        mediaLocation = "/var/lib/immich";

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
          oauth = {
            enabled = true;
            issuerUrl = "https://auth.${config.networking.domain}";
            clientId = "immich";
            clientSecret._secret = clientSecretPath;
            scope = "openid profile email";
            autoLaunch = false;
            autoRegister = true;
            buttonText = "Login with Pocket ID";
          };
        };
      };

      users.users.immich.extraGroups = ["video" "render"];

      # PostgreSQL tuning for Immich workload
      services.postgresql.settings = {
        shared_buffers = "512MB";
        effective_cache_size = "2GB";
        work_mem = "16MB";
        maintenance_work_mem = "256MB";
        max_connections = 100;
        checkpoint_completion_target = "0.9";
        random_page_cost = "1.1";
      };

      systemd = {
        services = {
          immich-server.serviceConfig =
            harden {
              MemoryMax = "2G";
              ProtectHome = lib.mkForce false;
              ProtectSystem = lib.mkForce false;
            }
            // serviceDefaults {};
          immich-machine-learning.serviceConfig =
            harden {
              MemoryMax = "4G";
              ProtectHome = lib.mkForce false;
              ProtectSystem = lib.mkForce false;
            }
            // serviceDefaults {RestartSec = "10s";}
            // {
              Environment = lib.mkForce "HOME=/var/lib/immich";
            };
          immich-server = {
            after = lib.optional provisionEnabled "pocket-id-provision.service";
            wants = lib.optional provisionEnabled "pocket-id-provision.service";
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };
          immich-machine-learning = {
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };
          immich-db-backup = {
            description = "Immich PostgreSQL database backup";
            inherit onFailure;
            path = [config.services.postgresql.package];
            after = ["postgresql.service" "immich-server.service"];
            requires = ["postgresql.service"];
            serviceConfig = {
              Type = "oneshot";
              User = "immich";
              Group = "immich";
            };
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
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
    };
  };
}
