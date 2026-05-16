{
  config,
  lib,
  nix-colors,
  ...
}: {
  options.colorScheme = lib.mkOption {
    type = lib.types.attrs;
    default = nix-colors.colorSchemes.catppuccin-mocha;
    description = "Color scheme for the system";
  };

  options.colorSchemeLib = lib.mkOption {
    type = lib.types.attrs;
    default = nix-colors.lib;
    description = "nix-colors library functions";
  };
}
