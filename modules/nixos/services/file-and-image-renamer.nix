# AI-powered file and screenshot renaming watcher daemon + health dashboard
_: {
  flake.nixosModules.file-and-image-renamer =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.file-and-image-renamer;
      inherit (config.users) primaryUser;
      sd = import ../../../lib/default.nix lib;
      inherit (sd) hardenUser mkStateDir ports;
    in
    {
      options.services.file-and-image-renamer = {
        enable = lib.mkEnableOption "File and Image Renamer — AI-powered screenshot renaming watcher";

        package = lib.mkPackageOption pkgs "file-and-image-renamer" { };

        user = lib.mkOption {
          type = lib.types.str;
          default = primaryUser;
          description = "User account to run the watcher service as";
        };

        watchDirectory = lib.mkOption {
          type = lib.types.str;
          default = "${config.users.users.${cfg.user}.home}/Desktop";
          defaultText = "/home/<user>/Desktop";
          description = "Directory to watch for new screenshots (legacy, prefer watchPaths)";
        };

        watchPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Directories to watch for new screenshots (colon-separated into WATCH_PATHS)";
        };

        apiKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "${config.users.users.${cfg.user}.home}/.zai_api_key";
          defaultText = "/home/<user>/.zai_api_key";
          description = "Path to the ZAI API key file";
        };

        syntheticApiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to the Synthetic.new API key file (optional fallback provider)";
        };

        model = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override GLM model ID (env: GLM_MODEL)";
        };

        syntheticModel = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override Synthetic model ID (env: SYNTHETIC_MODEL)";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.users.users.${cfg.user}.home}/.file-renamer";
          defaultText = "/home/<user>/.file-renamer";
          description = "Base directory for file-renamer state (dead-letter, hashdb, history)";
        };

        logDirectory = lib.mkOption {
          type = lib.types.str;
          default = "${cfg.dataDir}/logs";
          defaultText = "<dataDir>/logs";
          description = "Directory for watcher log files";
        };

        healthAddr = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:${toString ports.file-and-image-renamer-health}";
          defaultText = "127.0.0.1:<port>";
          description = "Listen address for the health dashboard web server";
        };

        enableHealthDashboard = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Start the health dashboard web server alongside the watcher";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ cfg.package ];

        systemd.tmpfiles.rules = [
          (mkStateDir cfg.dataDir "0750" cfg.user "users")
          (mkStateDir cfg.logDirectory "0750" cfg.user "users")
        ];

        # Health dashboard — system service (Caddy-proxied web endpoint, must not depend on graphical session)
        systemd.services.file-and-image-renamer-health = lib.mkIf cfg.enableHealthDashboard {
          description = "File and Image Renamer Health Dashboard";
          after = [ "network.target" ];
          wants = [ "network.target" ];
          startLimitIntervalSec = 600;
          startLimitBurst = 5;
          serviceConfig =
            sd.serviceDefaults { RestartSec = "15"; }
            // sd.harden {
              MemoryMax = "256M";
              ProtectHome = "read-only";
              ReadWritePaths = [ cfg.dataDir ];
            }
            // {
              Type = "simple";
              User = cfg.user;
              ExecStart = "${lib.getExe' cfg.package "file-renamer"} health --addr ${cfg.healthAddr}";
              WorkingDirectory = cfg.dataDir;
              KillMode = "mixed";
              TimeoutStopSec = "15";
              StandardOutput = "journal";
              StandardError = "journal";
              Environment = [
                "DEAD_LETTER_PATH=${cfg.dataDir}/dead-letter.json"
                # Redirect history + hashdb state into the writable dataDir.
                # The health service runs under `ProtectHome = "read-only"` with
                # only dataDir in ReadWritePaths. Without these overrides the
                # binary defaults to ~/.renamer-history.json and
                # ~/.file-renamer-hashes.db, init fails, initServiceOrWarn
                # returns nil, and handlers nil-deref → HTTP 500.
                "HISTORY_FILE_PATH=${cfg.dataDir}/history.json"
                "HASHDB_PATH=${cfg.dataDir}/hashes.db"
              ];
            };
          wantedBy = [ "multi-user.target" ];
        };

        home-manager.users.${cfg.user} = {
          systemd.user.services = {
            # Core watcher — monitors directories and renames new screenshots via AI vision
            file-and-image-renamer = {
              Unit = {
                Description = "File and Image Renamer Watcher";
                After = [
                  "network.target"
                  "graphical-session.target"
                ];
                Wants = [ "network.target" ];
                PartOf = [ "graphical-session.target" ];
                StartLimitIntervalSec = 600;
                StartLimitBurst = 5;
              };

              Service = lib.mkMerge [
                (sd.serviceDefaultsUser { RestartSec = "10"; })
                (hardenUser { MemoryMax = "512M"; })
                {
                  Type = "simple";
                  ExecStart = "${lib.getExe' cfg.package "file-renamer"} watch";
                  WorkingDirectory = cfg.watchDirectory;
                  KillMode = "mixed";
                  TimeoutStopSec = "30";
                  StandardOutput = "journal";
                  StandardError = "journal";

                  Environment = [
                    "DESKTOP_PATH=${cfg.watchDirectory}"
                    "ZAI_API_KEY_FILE=${cfg.apiKeyFile}"
                    "DEAD_LETTER_PATH=${cfg.dataDir}/dead-letter.json"
                  ]
                  ++ lib.optional (
                    cfg.syntheticApiKeyFile != null
                  ) "SYNTHETIC_API_KEY_FILE=${cfg.syntheticApiKeyFile}"
                  ++ lib.optional (cfg.model != null) "GLM_MODEL=${cfg.model}"
                  ++ lib.optional (cfg.syntheticModel != null) "SYNTHETIC_MODEL=${cfg.syntheticModel}"
                  ++ lib.optional (cfg.watchPaths != [ ]) "WATCH_PATHS=${lib.concatStringsSep ":" cfg.watchPaths}";
                }
              ];

              Install = {
                WantedBy = [ "graphical-session.target" ];
              };
            };
          };
        };
      };
    };
}
