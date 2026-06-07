{
  pkgs,
  colorScheme,
  ...
}: let
  theme = import ../../common/theme.nix;
  colors = colorScheme.palette;
in {
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      # Background
      color = colors.base00;

      # Indicator (the ring you type into)
      indicator = true;
      indicator-radius = 100;
      indicator-thickness = 10;

      # Colors - Catppuccin Mocha
      key-hl-color = colors.base0D; # Blue ring on key press
      bs-hl-color = colors.base08; # Pink ring on backspace
      caps-lock-key-hl-color = colors.base09; # Orange when caps
      caps-lock-bs-hl-color = colors.maroon;

      # Inside the ring
      inside-color = colors.base02; # Dark inner circle
      inside-clear-color = colors.base02;
      inside-caps-lock-color = colors.base02;
      inside-ver-color = colors.base02;
      inside-wrong-color = colors.base02;

      # Ring colors
      ring-color = colors.base04; # Inactive ring
      ring-clear-color = colors.base0D; # Clearing
      ring-caps-lock-color = colors.base09; # Caps on
      ring-ver-color = colors.base0B; # Verifying (green)
      ring-wrong-color = colors.base08; # Wrong (pink)

      # Text
      text-color = colors.base05;
      text-clear-color = colors.base05;
      text-caps-lock-color = colors.base05;
      text-ver-color = colors.base05;
      text-wrong-color = colors.base05;

      # Separators
      separator-color = "00000000"; # Transparent

      # Layout
      font = theme.font.mono;
      font-size = 24;

      # Grace period (seconds where no password needed after waking)
      grace = 0;
    };
  };
}
