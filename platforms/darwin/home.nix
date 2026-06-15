{
  nix-ssh-config,
  colorScheme,
  lib,
  config,
  pkgs,
  ...
}: let
  theme = import ../common/theme.nix;
in {
  imports = [
    ../common/home-base.nix
    ./programs/shells.nix
    nix-ssh-config.homeManagerModules.ssh
    ../common/programs/zellij.nix
    ../common/programs/yazi.nix
    ../common/programs/zed.nix
  ];

  home = {
    # macOS-specific session variables
    sessionVariables = {
      # Dark mode preference — respected by many apps and browsers
      GTK_THEME = "${theme.gtkThemeName}:dark";

      # Cursor theme
      XCURSOR_THEME = theme.cursorTheme;
      XCURSOR_SIZE = toString theme.cursorSize;
    };
  };

  # XDG configuration (macOS with limited support)
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig = {
        PROJECTS = "${config.home.homeDirectory}/projects";
      };
      setSessionVariables = false;
    };
  };
}
