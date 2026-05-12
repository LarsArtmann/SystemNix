# Sway backup window manager alongside Niri with Wayland utilities
_: {
  flake.nixosModules.multi-wm = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.multi-wm;
  in {
    options.services.multi-wm = {
      enable = lib.mkEnableOption "Sway backup window manager alongside Niri";
    };

    config = lib.mkIf cfg.enable {
      # Backup window manager alongside Niri
      # This allows switching between different WMs at SDDM login screen

      programs = {
        # Sway - i3 successor for stable tiling (backup WM)
        sway = {
          enable = true;
          wrapperFeatures.gtk = true; # So that GTK applications work properly
          extraPackages = with pkgs; [
            swayidle # Idle management daemon
            foot # Terminal
          ];
        };
      };

      services = {
        xserver = {
          xkb = {
            layout = "us";
            variant = "";
          };
        };
      };

      # Additional packages needed for Sway backup WM
      environment.systemPackages = with pkgs; [
        # Application launcher for all WMs
        rofi

        # File manager
        kdePackages.dolphin

        # Notification daemon - dunst configured via Home Manager (home.nix)
        # mako removed to avoid duplicate notification daemons

        # Screenshot tools
        grim
        slurp

        # Clipboard
        wl-clipboard
      ];
    };
  };
}
