{
  config,
  lib,
  pkgs,
  dankMaterialShell,
  colorScheme,
  ...
}: let
  cfg = config.programs.systemnix-quickshell;
in {
  imports = [
    dankMaterialShell.homeModules.niri
    dankMaterialShell.homeModules.dank-material-shell
  ];

  options.programs.systemnix-quickshell = {
    enable = lib.mkEnableOption "Quickshell desktop shell via DankMaterialShell (replaces Waybar, Dunst, Wlogout, polkit_gnome)";

    package = lib.mkOption {
      type = lib.types.package;
      default = dankMaterialShell.packages.${pkgs.system}.default;
      description = "The DankMaterialShell package";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.dank-material-shell = {
      enable = true;

      enableSystemMonitoring = true;
      enableDynamicTheming = true;
      enableAudioWavelength = true;
      enableCalendarEvents = false;
    };

    # DMS handles its own systemd service via the upstream HM module.
    # The upstream module binds to config.wayland.systemd.target which
    # niri-flake sets to niri.service — so the shell starts with niri.
  };
}
