{lib, ...}: let
  theme = import ./theme.nix;
in {
  options.preferences = {
    appearance = {
      variant = lib.mkOption {
        type = lib.types.enum ["dark" "light"];
        default = "dark";
        description = "System-wide color variant — affects GTK, Qt, portals, browsers, and macOS";
      };

      accent = lib.mkOption {
        type = lib.types.enum ["rosewater" "flamingo" "pink" "mauve" "red" "maroon" "peach" "yellow" "green" "teal" "sky" "sapphire" "blue" "lavender"];
        default = theme.accent;
        description = "Accent color for theme variants";
      };

      density = lib.mkOption {
        type = lib.types.enum ["standard" "compact"];
        default = theme.density;
        description = "UI density — standard or compact";
      };

      gtkThemeName = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = theme.gtkThemeName;
        description = "Full GTK theme name (must match installed theme)";
      };

      iconTheme = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = theme.iconTheme;
        description = "Icon theme name";
      };

      cursorTheme = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = theme.cursorTheme;
        description = "Cursor theme name";
      };

      cursorSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = theme.cursorSize;
        description = "Cursor size in pixels";
      };

      font = {
        name = lib.mkOption {
          type = lib.types.nonEmptyStr;
          default = theme.font.name;
          description = "Default UI font";
        };
        size = lib.mkOption {
          type = lib.types.ints.positive;
          default = theme.font.size;
          description = "Default UI font size";
        };
        mono = lib.mkOption {
          type = lib.types.nonEmptyStr;
          default = theme.font.mono;
          description = "Monospace font";
        };
        monoSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = theme.font.monoSize;
          description = "Monospace font size";
        };
      };
    };
  };
}
