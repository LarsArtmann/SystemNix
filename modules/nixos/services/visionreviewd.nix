# visionreviewd — SystemNix wrapper around the upstream nixos-module.
#
# The upstream module (inputs.vision-review-agent.nixosModules.visionreviewd)
# provides every option (enable, package, configFile, llamaServer.{enable,
# package, model, port}) plus the hardened systemd units. This file layers
# only the SystemNix-specific concerns on top: the package from the flake
# input, the registered llama port, failure-alert routing, and the
# service-integration registry entry (system-health unit-state monitoring).
#
# No HTTP surface: the daemon writes markdown reviews and talks to the model
# endpoint over loopback, so the registry entry is monitored-only (no vHost,
# no Gatus check — probing llama-vlm's socket-activated captioner would
# defeat its idle-unload TTL by keeping the model permanently resident).
# Returned 2026-09-22 against an input rev that ships the module (the
# 2026-08-18 `or null` lazy guard from the first integration is gone by
# design — see bd580b96 for why the guard existed and was removed).
{ inputs, ... }: {
  flake.nixosModules.visionreviewd =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        onFailure
        ports
        ;
      cfg = config.services.vision-review-agent;
    in
    {
      imports = [ inputs.vision-review-agent.nixosModules.visionreviewd ];

      config = lib.mkIf cfg.enable {
        services.vision-review-agent = {
          package =
            lib.mkDefault
              inputs.vision-review-agent.packages.${pkgs.stdenv.hostPlatform.system}.visionreviewd;
          llamaServer.port = lib.mkDefault ports.visionreviewd-llama;
        };

        # Route unit failures into the notify-failure template (every other
        # long-running service does this; upstream ships no OnFailure).
        systemd.services.visionreviewd.serviceConfig.OnFailure = onFailure;

        services.integration = lib.optionalAttrs (options ? services.integration) {
          visionreviewd = {
            inherit (cfg) enable;
            vHost.layer = "none";
            monitored = true;
          };
        };
      };
    };
}
