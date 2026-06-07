rec {
  variant = "mocha";
  accent = "lavender";
  density = "compact";

  gtkThemeName = "Catppuccin-${variant}-${density}-${accent}-Dark";
  iconTheme = "Papirus-Dark";
  cursorTheme = "Bibata-Modern-Classic";
  cursorSize = 96;

  font = {
    name = "Sans";
    size = 16;
    mono = "JetBrainsMono Nerd Font";
    monoSize = 16;
  };

  colorSchemeName = "catppuccin-mocha";

  colors = {
    rosewater = "f5e0dc";
    flamingo = "f2cdcd";
    pink = "f5c2e7";
    mauve = "cba6f7";
    red = "f38ba8";
    maroon = "eba0ac";
    peach = "fab387";
    yellow = "f9e2af";
    green = "a6e3a1";
    teal = "94e2d5";
    sky = "89dceb";
    sapphire = "74c7ec";
    blue = "89b4fa";
    lavender = "b4befe";
    text = "cdd6f4";
    subtext1 = "bac2de";
    subtext0 = "a6adc8";
    overlay2 = "9399b2";
    overlay1 = "7f849c";
    overlay0 = "6c7086";
    surface2 = "585b70";
    surface1 = "45475a";
    surface0 = "313244";
    base = "1e1e2e";
    mantle = "181825";
    crust = "11111b";
  };

  colorScheme = {
    slug = "catppuccin-mocha";
    name = "Catppuccin Mocha";
    author = "Catppuccin Org";
    inherit colors;
    palette =
      colors
      // {
        base00 = colors.base;
        base01 = colors.mantle;
        base02 = colors.surface0;
        base03 = colors.surface1;
        base04 = colors.surface2;
        base05 = colors.text;
        base06 = colors.rosewater;
        base07 = colors.lavender;
        base08 = colors.red;
        base09 = colors.peach;
        base0A = colors.yellow;
        base0B = colors.green;
        base0C = colors.teal;
        base0D = colors.blue;
        base0E = colors.mauve;
        base0F = colors.pink;
      };
  };
}
