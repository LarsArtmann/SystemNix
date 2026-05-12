# Steam gaming platform with gamemode performance tuning
_: {
  flake.nixosModules.steam = {
    lib,
    config,
    pkgs,
    ...
  }: let
    cfg = config.services.steam-config;
  in {
    options.services.steam-config = {
      enable = lib.mkEnableOption "Steam gaming platform with gamemode and gamescope";
    };

    config = lib.mkIf cfg.enable {
      programs = {
        steam = {
          enable = true;
          extest.enable = true;
          localNetworkGameTransfers.openFirewall = false;
          protontricks.enable = true;
        };

        gamemode = {
          enable = true;
          settings = {
            general = {
              renice = 10;
            };
            gpu = {
              gputempthreshold = 80;
            };
            cpu = {
              Governor = "performance";
            };
          };
        };

        gamescope = {
          enable = true;
          capSysNice = true;
        };
      };

      hardware.steam-hardware = {
        enable = true;
      };

      environment.systemPackages = with pkgs; [
        mangohud
      ];
    };
  };
}
