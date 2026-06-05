{
  pkgs,
  lib,
  ...
}: {
  fonts = lib.mkIf pkgs.stdenv.isLinux {
    packages = [
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.iosevka

      # Unicode fallback fonts for full UTF-8 coverage
      pkgs.noto-fonts
      pkgs.noto-fonts-color-emoji
      pkgs.noto-fonts-cjk-sans

      # Cursor theme
      pkgs.bibata-cursors
    ];
  };
}
