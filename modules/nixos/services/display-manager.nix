# SDDM display manager with Catppuccin theme and niri session
_: {
  flake.nixosModules.display-manager = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.display-manager-config;
  in {
    options.services.display-manager-config = {
      enable = lib.mkEnableOption "SDDM display manager with niri session";
    };

    config = lib.mkIf cfg.enable {
      services = {
        xserver = {
          enable = true;
          xkb = {
            layout = "us";
            variant = "";
          };
        };
        displayManager.defaultSession = "niri";
      };

      programs.silentSDDM = {
        enable = true;
        theme = "catppuccin-mocha";
      };
    };
  };
}
