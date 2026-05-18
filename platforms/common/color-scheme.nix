{lib, ...}: let
  theme = import ./theme.nix;
in {
  options.colorScheme = lib.mkOption {
    type = lib.types.attrs;
    default = theme.colorScheme;
    description = "Color scheme for the system";
  };
}
