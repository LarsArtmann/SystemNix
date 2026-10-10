# NetBird mesh VPN client — outbound WireGuard tunnel joining this host to
# the self-hosted NetBird control plane on the pbx server
# (netbird.larsartmann.cloud). Split-horizon remote access plan:
# docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md
#
# PHASE GATE (deliberate): stays disabled until the Phase-2 setup key exists
# in sops (platforms/nixos/secrets/netbird.yaml → netbird_setup_key). Enabling
# without that file fails activation by design — fail-closed, no placeholder
# secrets. The login oneshot handles enrollment automatically; no inbound
# ports are opened beyond the P2P WireGuard port (51820/udp).
_: {
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
        # Pinned-nixpkgs surface (2026-09-28): services.netbird.clients.<name>
        # with automated setup-key login — no interactive browser flow on a
        # headless server, ever. The login oneshot picks the key up from the
        # sops-rendered file via LoadCredential.
        services.netbird = {
          clients.evox2 = {
            port = ports.netbird;
            # Management URL goes via ENV, never the `config` JSON fragment:
            # netbird >=0.80 serializes ManagementURL as a nested url.URL
            # OBJECT in config.json — a string fragment crashes the daemon at
            # startup ("json: cannot unmarshal string into Go struct field
            # Config.ManagementURL of type url.URL"; bit us on the 2026-10-06
            # phase-2 flip deploy). Sanctioned path: the wrapper maps NB_* env
            # vars onto CLI flags (NB_MANAGEMENT_URL -> --management-url), and
            # `netbird up` forwards it in the LoginRequest — the daemon then
            # persists the correctly-shaped object itself.
            environment.NB_MANAGEMENT_URL = cfg.managementURL;
            login = {
              enable = true;
              setupKeyFile = config.sops.secrets.netbird_setup_key.path;
              systemdDependencies = [ "sops-install-secrets.service" ];
            };
            # openFirewall (default) opens 51820/udp for direct P2P;
            # openInternalFirewall (default) trusts the tunnel interface.
          };

          # Routing-peer role: evo-x2 forwards VPN traffic into the LAN
          # (192.168.1.0/24 — the network route itself is MANAGEMENT-SIDE:
          # dashboard "Networks" picks evo-x2 as routing peer; NetBird has
          # no client-side route-advertise CLI, verified against
          # docs.netbird.io/manage/network-routes). nixpkgs semantics:
          #   "server" arm → net.ipv4/ip_forward + net.ipv6 forwarding
          #   "client" arm → firewall checkReversePath "loose" (needed here
          #     too: LAN-local peers reach evo-x2's 100.x address with
          #     sources that strict rp_filter would drop on the LAN iface)
          useRoutingFeatures = "both";
        };

        sops.secrets.netbird_setup_key = {
          sopsFile = ../../../platforms/nixos/secrets/netbird.yaml;
          key = "netbird_setup_key";
        };

        # Boot-safe enqueue (2026-10-10): nixpkgs pulls the login oneshot
        # ONLY via netbird-evox2.service.wants, and systemd 261.3 NEVER
        # QUEUED it that way — across four boots (2026-10-07) the unit has
        # zero journal entries while its parent started cleanly every time
        # (manager-level skips are debug-logged in 261, so it fails
        # SILENTLY; the daemon then sits credential-less forever retrying
        # "no peer auth method provided" against the management service).
        # Sibling units wanted the same way but shaped Before=<parent>
        # (cv-oidc-env, dnsblockd-oidc-secret) DO start — the
        # Requires+After-back-on-the-wanter shape is the one that never
        # fires on this box. multi-user.target.wants enqueues the oneshot
        # directly at boot; its own Requires=/After=netbird-evox2.service
        # still order it behind the daemon, and the script is a
        # NeedsLogin-guarded no-op once enrolled. deploy.sh's converger
        # loop re-runs it after every deploy (stale-key re-enrollment
        # path).
        systemd.services."netbird-evox2-login".wantedBy = [ "multi-user.target" ];

        # State hygiene (2026-10-06): the phase-2 deploy's string-form
        # "ManagementUrl" fragment poisoned /var/lib/netbird-evox2/config.json,
        # and the nixpkgs preStart jq fragment-merge never REMOVES keys — purge
        # string-typed management-URL keys ourselves. Object-typed values were
        # written by netbird itself and must survive. mkAfter because the
        # nixpkgs preStart is what exports $NB_CONFIG and the jq PATH.
        systemd.services.netbird-evox2.preStart = lib.mkAfter ''
          if [ -f "$NB_CONFIG" ] && jq -e '
              (.ManagementUrl | type) == "string" or (.ManagementURL | type) == "string"
            ' "$NB_CONFIG" >/dev/null 2>&1; then
            jq '
                if (.ManagementUrl | type) == "string" then del(.ManagementUrl) else . end
                | if (.ManagementURL | type) == "string" then del(.ManagementURL) else . end
              ' "$NB_CONFIG" > "$NB_CONFIG.purged"
            mv "$NB_CONFIG.purged" "$NB_CONFIG"
            echo "netbird: purged string-form management URL from $NB_CONFIG (netbird >=0.80 requires url.URL object form)"
          fi
        '';

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
