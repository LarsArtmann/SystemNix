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
{inputs, ...}: {
  flake.nixosModules.visionreviewd = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (import ../../../lib/default.nix lib) ports;

    # Absent until the input revision ships the module (see header note).
    upstream = inputs.vision-review-agent.nixosModules.visionreviewd or null;
  in {
    imports = lib.optionals (upstream != null) [upstream];

    # Defaults apply only once the upstream module (and its options) exist;
    # mkIf filters the definitions away otherwise, keeping hosts without the
    # module importable at any input revision.
    config = lib.mkIf (upstream != null) {
      services.vision-review-agent = {
        package = lib.mkDefault inputs.vision-review-agent.packages.${pkgs.stdenv.hostPlatform.system}.visionreviewd;
        llamaServer.port = lib.mkDefault ports.visionreviewd-llama;
      };
    };
  };
}
