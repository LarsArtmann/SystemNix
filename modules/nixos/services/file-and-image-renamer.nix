# AI-powered file and screenshot renaming watcher daemon
_: {
  flake.nixosModules.file-and-image-renamer = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.file-and-image-renamer;
    inherit (config.users) primaryUser;
    sd = import ../../../lib/default.nix lib;
    inherit (sd) hardenUser mkStateDir;
  in {
    options.services.file-and-image-renamer = {
      enable = lib.mkEnableOption "File and Image Renamer — AI-powered screenshot renaming watcher";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.file-and-image-renamer;
        description = "The file-and-image-renamer package to use";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User account to run the watcher service as";
      };

      watchDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/${cfg.user}/Desktop";
        defaultText = "/home/<user>/Desktop";
        description = "Directory to watch for new screenshots (legacy, prefer watchPaths)";
      };

      watchPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Directories to watch for new screenshots (colon-separated into WATCH_PATHS)";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/home/${cfg.user}/.zai_api_key";
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

      logDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/${cfg.user}/.file-renamer/logs";
        defaultText = "/home/<user>/.file-renamer/logs";
        description = "Directory for watcher log files";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [cfg.package];

      systemd.tmpfiles.rules = [
        (mkStateDir cfg.logDirectory "0750" cfg.user "users")
      ];

      home-manager.users.${cfg.user} = {
        systemd.user.services.file-and-image-renamer = {
          Unit = {
            Description = "File and Image Renamer Watcher";
            After = [
              "network.target"
              "graphical-session.target"
            ];
            Wants = ["network.target"];
            PartOf = ["graphical-session.target"];
            StartLimitIntervalSec = 600;
            StartLimitBurst = 5;
          };

          Service =
            sd.serviceDefaultsUser {RestartSec = "10";}
            // hardenUser {MemoryMax = "512M";}
            // {
              Type = "simple";
              ExecStart = "${lib.getExe' cfg.package "file-renamer"} watch";
              WorkingDirectory = cfg.watchDirectory;
              KillMode = "mixed";
              TimeoutStopSec = "30";
              StandardOutput = "journal";
              StandardError = "journal";

              Environment =
                [
                  "DESKTOP_PATH=${cfg.watchDirectory}"
                  "ZAI_API_KEY_FILE=${cfg.apiKeyFile}"
                ]
                ++ lib.optional (
                  cfg.syntheticApiKeyFile != null
                ) "SYNTHETIC_API_KEY_FILE=${cfg.syntheticApiKeyFile}"
                ++ lib.optional (cfg.model != null) "GLM_MODEL=${cfg.model}"
                ++ lib.optional (cfg.syntheticModel != null) "SYNTHETIC_MODEL=${cfg.syntheticModel}"
                ++ lib.optional (cfg.watchPaths != []) "WATCH_PATHS=${lib.concatStringsSep ":" cfg.watchPaths}";
            };

          Install = {
            WantedBy = ["graphical-session.target"];
          };
        };
      };
    };
  };
}
