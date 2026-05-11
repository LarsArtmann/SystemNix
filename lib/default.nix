lib: let
  inherit (import ./systemd/service-defaults.nix lib) serviceDefaults serviceDefaultsUser;
in {
  harden = import ./systemd.nix {inherit lib;};
  hardenUser = import ./user-harden.nix {inherit lib;};
  mkGraphicalUserService = import ./graphical-user-service.nix {inherit lib;};
  inherit serviceDefaults serviceDefaultsUser;
  serviceTypes = import ./types.nix lib;
}
