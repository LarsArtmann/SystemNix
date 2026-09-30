# NetBird mesh VPN client — outbound WireGuard tunnel joining this host to
# the self-hosted NetBird control plane on the pbx server
# (netbird.larsartmann.cloud). Split-horizon remote access plan:
# docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md
#
# PHASE GATE (deliberate): stays disabled until the Phase-2 setup key exists
# in sops (platforms/nixos/secrets/netbird.yaml → netbird_env, format:
# NETBIRD_SETUP_KEY=<key>). Enabling without that file fails activation by
# design — fail-closed, no placeholder secrets. The tunnel interface is
# trusted (LAN-equivalent) once up; no inbound ports are opened.
_:
{
  flake.nixosModules.netbird =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.services.netbird-client;
      inherit (import ../../../lib/default.nix lib) ports;
      tunnelName = "wt0";
    in
    {
      # Unconditional catalog entry (ADR-008): "what exists" — no DNS
      # presence (outbound client), hence subdomain = null. Hosts importing
      # this module MUST co-import nixosModules.catalog (loud failure
      # otherwise — deliberate).
      imports = [
        {
          services.catalog = {
            netbird = {
              subdomain = null;
              port = ports.netbird;
              owner = "lars";
              description = "NetBird mesh VPN client — outbound WireGuard tunnel to the self-hosted control plane on the pbx server";
              healthPath = null;
            };
          };
        }
      ];

      options.services.netbird-client = {
        enable = lib.mkEnableOption "NetBird VPN client (outbound mesh tunnel to netbird.larsartmann.cloud)";
        managementURL = lib.mkOption {
          type = lib.types.str;
          default = "https://netbird.larsartmann.cloud";
          description = "NetBird management URL (self-hosted control plane)";
        };
      };

      config = lib.mkIf cfg.enable {
        services.netbird.tunnels.${tunnelName} = {
          enable = true;
          port = ports.netbird;
          environmentFile = config.sops.secrets.netbird_env.path;
        };

        sops.secrets.netbird_env = {
          sopsFile = ../../../platforms/nixos/secrets/netbird.yaml;
          restartUnits = [ "netbird-${tunnelName}.service" ];
        };

        # The tunnel carries only trusted mesh traffic (our own peers,
        # single-user ACLs) — LAN-equivalent trust, same as eno1.
        networking.firewall.trustedInterfaces = [ tunnelName ];

        # Service-integration registry entry: unit-state monitoring only
        # (no vHost — the client is not a web service; no port checks —
        # health = unit liveness).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          netbird = {
            enable = true;
            vHost.layer = "none";
            monitored = true;
          };
        };
      };
    };
}
