# Projects Management Automation — thin wiring into SystemNix
# The actual NixOS module lives in the PMA flake (nixosModules.default).
# This file passes SystemNix-specific config: sops secrets, primary user.
{ inputs, ... }: {
  flake.nixosModules.projects-management-automation =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.projects-management-automation;
      primaryUser = config.users.primaryUser;
      pmaModule = inputs.projects-management-automation.nixosModules.default;
      sopsEnvPath = config.sops.templates."pma-env".path;
    in
    {
      imports = [ pmaModule ];

      config = lib.mkIf cfg.enable {
        services.projects-management-automation = {
          package = inputs.projects-management-automation.packages.${pkgs.stdenv.hostPlatform.system}.default;
          user = primaryUser;
          group = "users";
          home = "/home/${primaryUser}";
          environmentFile = sopsEnvPath;
        };

        # The upstream NixOS module sets Type=notify + WatchdogSec=30s (commit
        # 6cdf05e5 "enable systemd notify"), but the Go binary never calls
        # sd_notify(READY=1). Result: systemd waits the full TimeoutStartSec
        # (90s), times out, kills the service, Restart=on-failure cycles it
        # forever. Override to Type=exec so systemd considers it started once
        # execve succeeds. WatchdogSec is inert without READY=1, zeroed for
        # clarity. Remove this override once upstream adds sd_notify support.
        systemd.services.projects-management-automation.serviceConfig = {
          Type = lib.mkForce "exec";
          WatchdogSec = lib.mkForce "0";
        };
      };
    };
}
