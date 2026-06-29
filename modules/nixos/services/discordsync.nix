# DiscordSync — Continuous Discord backup with local SQLite + Turso cloud sync
{inputs, ...}: {
  flake.nixosModules.discordsync = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      onFailure
      serviceTypes
      ports
      ;
    cfg = config.services.discordsync;
    inherit (lib) types;
    discordsyncPkg = inputs.discordsync.packages.${pkgs.stdenv.hostPlatform.system}.default;
    sopsEnvPath = config.sops.templates."discordsync-env".path;
  in {
    options.services.discordsync = {
      enable = lib.mkEnableOption "DiscordSync continuous Discord backup";

      inherit
        (serviceTypes.systemdServiceIdentity {
          defaultUser = "discordsync";
          defaultStateDir = "/var/lib/discordsync";
        })
        user
        group
        stateDir
        ;

      restartSec = serviceTypes.restartDelay "10";

      timeoutStopSec = serviceTypes.stopTimeout "30";

      databasePath = lib.mkOption {
        type = types.str;
        default = "${cfg.stateDir}/discordsync.db";
        description = "Path to the local SQLite database file";
      };

      attachmentPath = lib.mkOption {
        type = types.str;
        default = "${cfg.stateDir}/attachments";
        description = "Path to store downloaded attachments";
      };

      gcsBucket = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "GCS bucket name for cloud attachment backup";
      };

      backfillOnStartup = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Backfill all historical messages on startup";
      };

      apiAddr = lib.mkOption {
        type = types.str;
        default = "127.0.0.1:${toString ports.discordsync-api}";
        description = "Listen address for the HTTP API (/metrics, /api/events/stream, /api/export). Localhost-only by default for security.";
      };
    };

    config = lib.mkIf cfg.enable {
      users.groups.${cfg.group} = {};

      users.users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.stateDir;
        createHome = true;
        description = "DiscordSync backup service";
      };

      system.activationScripts."discordsync-setup" =
        lib.stringAfter
        (["users"] ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets")
        ''
          mkdir -p ${cfg.stateDir}/attachments
          chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
          chmod 2770 ${cfg.stateDir} ${cfg.stateDir}/attachments
        '';

      systemd.services.discordsync = {
        description = "DiscordSync — Continuous Discord Backup";
        wantedBy = ["multi-user.target"];
        after = [
          "network-online.target"
          "sops-nix.service"
          "unbound.service"
        ];
        wants = [
          "network-online.target"
          "sops-nix.service"
          "unbound.service"
        ];
        inherit onFailure;
        startLimitIntervalSec = 300;
        startLimitBurst = 5;

        serviceConfig =
          {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            ExecStart = "${lib.getExe discordsyncPkg}";
            WorkingDirectory = cfg.stateDir;
            Environment =
              [
                "DB_BACKEND=turso-sync"
                "DATABASE_PATH=${cfg.databasePath}"
                "API_ADDR=${cfg.apiAddr}"
                "ATTACHMENT_STORAGE_PATH=${cfg.attachmentPath}"
                "BACKFILL_ON_STARTUP=${
                  if cfg.backfillOnStartup
                  then "true"
                  else "false"
                }"
              ]
              ++ lib.optional (cfg.gcsBucket != null) "GCS_BUCKET=${cfg.gcsBucket}"
              ++ lib.optional (
                cfg.gcsBucket != null
              ) "GOOGLE_APPLICATION_CREDENTIALS=${config.sops.secrets.discordsync_gcs_credentials.path}";
            EnvironmentFile = [sopsEnvPath];
            KillMode = "mixed";
            KillSignal = "SIGTERM";
            TimeoutStopSec = cfg.timeoutStopSec;
            StandardOutput = "journal";
            StandardError = "journal";
            UMask = "0026";
          }
          // serviceDefaults {
            Restart = "on-failure";
            RestartSec = cfg.restartSec;
          }
          // harden {
            MemoryMax = "2G";
            ReadWritePaths = [cfg.stateDir];
          };
      };
    };
  };
}
