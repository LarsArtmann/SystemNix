lib: let
  inherit (import ./systemd/service-defaults.nix lib) serviceDefaults serviceDefaultsUser;
in {
  harden = import ./systemd.nix {inherit lib;};
  inherit serviceDefaults serviceDefaultsUser;
  serviceTypes = import ./types.nix lib;
}
