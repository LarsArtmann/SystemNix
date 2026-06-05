{pkgs, ...}: let
  theme = import ../../common/theme.nix;
in {
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      # Background
      color = "1e1e2e";

      # Indicator (the ring you type into)
      indicator = true;
      indicator-radius = 100;
      indicator-thickness = 10;

      # Colors - Catppuccin Mocha
      key-hl-color = "89b4fa"; # Blue ring on key press
      bs-hl-color = "f38ba8"; # Pink ring on backspace
      caps-lock-key-hl-color = "fab387"; # Orange when caps
      caps-lock-bs-hl-color = "eba0ac";

      # Inside the ring
      inside-color = "313244"; # Dark inner circle
      inside-clear-color = "313244";
      inside-caps-lock-color = "313244";
      inside-ver-color = "313244";
      inside-wrong-color = "313244";

      # Ring colors
      ring-color = "585b70"; # Inactive ring
      ring-clear-color = "89b4fa"; # Clearing
      ring-caps-lock-color = "fab387"; # Caps on
      ring-ver-color = "a6e3a1"; # Verifying (green)
      ring-wrong-color = "f38ba8"; # Wrong (pink)

      # Text
      text-color = "cdd6f4";
      text-clear-color = "cdd6f4";
      text-caps-lock-color = "cdd6f4";
      text-ver-color = "cdd6f4";
      text-wrong-color = "cdd6f4";

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
