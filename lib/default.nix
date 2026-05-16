lib: let
  harden = import ./systemd.nix {inherit lib;};
  inherit (import ./systemd/service-defaults.nix lib) serviceDefaults serviceDefaultsUser;
in {
  inherit harden;
  hardenUser = args: harden (args // {mode = "user";});
  mkGraphicalUserService = import ./graphical-user-service.nix {inherit lib;};
  inherit serviceDefaults serviceDefaultsUser;
  serviceTypes = import ./types.nix lib;
}
