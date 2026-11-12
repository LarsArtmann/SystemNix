# Runbook: docs/services/wifi-failover.md
# WiFi standby failover — carrier-based default-route guard for eno1.
#
# DELEGATED to the collection module (inputs.nixos-modules.nixosModules.
# wifi-failover, repo github:LarsArtmann/nixos-modules — VM-tested in the
# collection's own checks.wifi-failover-vm): options, the watch script, unit
# definition, hardening, the gateway-resolution option, and the dual-wan
# conflict assertion all live upstream. This file layers ONLY the
# SystemNix-specific concerns (collection-delegation recipe,
# docs/agents/integration-registry.md):
#   - gateway feed from networking.local.gateway (the fleet's local-network
#     option; upstream falls back to networking.defaultGateway when unset)
#   - integration-registry entry (unit-state monitoring only — the daemon
#     has no HTTP surface, vHost, tile, or backup)
{ inputs, ... }: {
  flake.nixosModules.wifi-failover =
    {
      config,
      options,
      lib,
      ...
    }:
    let
      cfg = config.services.wifi-failover;
    in
    {
      imports = [ inputs.nixos-modules.nixosModules.wifi-failover ];

      config = lib.mkIf cfg.enable {
        # Fleet gateway truth (platforms/nixos/system/local-network.nix);
        # plain priority — the upstream null default never contests it.
        services.wifi-failover.gateway = config.networking.local.gateway;

        # Service-integration registry entry: unit-state monitoring only (the
        # daemon has no HTTP surface, vHost, tile, or backup). Lives HERE,
        # not upstream: an `options ? services.integration` guard cannot
        # survive the enclosing mkIf cfg.enable with enable=true against an
        # undeclared option (2026-09-15 lesson) — the delegation layer is
        # always co-evaluated with integration.nix on this fleet.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          wifi-failover = {
            inherit (cfg) enable;
            vHost.layer = "none";
            monitored = true;
          };
        };
      };
    };
}
