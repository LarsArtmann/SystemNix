# visionreviewd — SystemNix wrapper around upstream nixos-module.
#
# The upstream module (inputs.vision-review-agent.nixosModules.visionreviewd)
# provides every option (enable, package, configFile, llamaServer.{enable,
# package, model, port}) plus the hardened systemd units. This file layers
# only the SystemNix-specific concerns on top: the package from the flake
# input and the llama-server port from the central registry.
#
# LAZY by design: the upstream import is guarded with `or null` so SystemNix
# stays checkable even while the locked revision of vision-review-agent
# predates the module. Once the input is bumped to a revision that ships
# nixosModules.visionreviewd, hosts can enable the service:
#
#     imports = [ nixosModules.visionreviewd ];  # or via module list
#     services.vision-review-agent = {
#       enable = true;
#       configFile = "/etc/visionreviewd/config.json";
#       llamaServer.enable = true;  # pulls ~9-10 GB on first start
#     };
{ inputs, ... }: {
  flake.nixosModules.visionreviewd =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) ports;

      # Absent until the input revision ships the module (see header note).
      upstream = inputs.vision-review-agent.nixosModules.visionreviewd or null;
    in
    {
      imports = lib.optionals (upstream != null) [ upstream ];

      # optionalAttrs (not mkIf): mkIf still emits a definition envelope that
      # the module system type-checks against the (nonexistent) option —
      # breaking eval while the input predates the module. optionalAttrs
      # produces a literal `config = {}` — nothing to check, nothing to merge.
      config = lib.optionalAttrs (upstream != null) {
        services.vision-review-agent = {
          # Upstream flake exposes its package as `default` (no .visionreviewd attr).
          package =
            lib.mkDefault
              inputs.vision-review-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
          llamaServer.port = lib.mkDefault ports.visionreviewd-llama;
        };
      };
    };
}
