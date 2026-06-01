# Projects Management Automation — thin wiring into SystemNix
# The actual NixOS module lives in the PMA flake (nixosModules.default).
# This file passes SystemNix-specific config: sops secrets, primary user.
{inputs, ...}: {
  flake.nixosModules.projects-management-automation = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.projects-management-automation;
    primaryUser = config.users.primaryUser;
    pmaModule = inputs.projects-management-automation.nixosModules.default;
    sopsEnvPath = config.sops.templates."pma-env".path;
  in {
    imports = [pmaModule];

    config = lib.mkIf cfg.enable {
      services.projects-management-automation = {
        package = pkgs.projects-management-automation;
        user = primaryUser;
        group = "users";
        home = "/home/${primaryUser}";
        environmentFile = sopsEnvPath;
      };
    };
  };
}
