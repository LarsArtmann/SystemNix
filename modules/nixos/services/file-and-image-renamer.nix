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
        description = "Directory to watch for new screenshots";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/home/${cfg.user}/.zai_api_key";
        defaultText = "/home/<user>/.zai_api_key";
        description = "Path to the ZAI API key file";
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
        "d ${cfg.logDirectory} 0750 ${cfg.user} users -"
      ];

      home-manager.users.${cfg.user} = {
        systemd.user.services.file-and-image-renamer = {
          Unit = {
            Description = "File and Image Renamer Watcher";
            After = ["network.target" "graphical-session.target"];
            Wants = ["network.target"];
            PartOf = ["graphical-session.target"];
            StartLimitIntervalSec = 600;
            StartLimitBurst = 5;
          };

          Service =
            sd.serviceDefaultsUser {RestartSec = "10";}
            // {
              Type = "simple";
              ExecStart = "${cfg.package}/bin/file-renamer watch";
              WorkingDirectory = cfg.watchDirectory;
              KillMode = "mixed";
              TimeoutStopSec = "30";
              StandardOutput = "journal";
              StandardError = "journal";

              Environment = [
                "DESKTOP_PATH=${cfg.watchDirectory}"
                "ZAI_API_KEY_FILE=${cfg.apiKeyFile}"
              ];
            };

          Install = {
            WantedBy = ["graphical-session.target"];
          };
        };
      };
    };
  };
}
