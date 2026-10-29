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
#
# Multi-host ready (2026-10-29): every instance-suffix flows through
# services.netbird-client.name (unit names, state dir, config.d fragment
# path) so the next client (rpi3) enrolls by setting name + its own sops
# key — no module fork. The local Prometheus metrics endpoint
# (netbird >=0.67, loopback) + the NetBird Mesh Connection Gatus check close
# the 2026-10-17 blind spot: the daemon sat "running" for 8h while its
# management stream was dead and nothing could see it.
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
      inherit (import ../../../lib/default.nix lib)
        onFailure
        ports
        ;
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
        name = lib.mkOption {
          type = lib.types.str;
          default = "evox2";
          description = "Client instance name — suffixed into unit names (netbird-<name>), the state dir (/var/lib/netbird-<name>) and the config.d fragment path. A per-host declaration, NOT derived from networking.hostName: renaming an enrolled host would move its state dir and orphan the dashboard peer (fresh WireGuard identity, silent re-enrollment).";
        };
        metrics = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Expose the netbird client's local Prometheus /metrics endpoint (netbird >=0.67; off upstream by default, loopback-only). Scraped by SigNoz and asserted by the NetBird Mesh Connection Gatus check — the only visibility into daemon-alive-but-disconnected, the 2026-10-17 8h-outage blind spot.";
          };
          address = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1:${toString ports.netbird-metrics}";
            description = "Loopback listen address for the local metrics endpoint. Never the netbird default 9191 — ocis binds the whole 9100-9304 loopback band at startup.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # Pinned-nixpkgs surface (2026-09-28): services.netbird.clients.<name>
        # with automated setup-key login — no interactive browser flow on a
        # headless server, ever. The login oneshot picks the key up from the
        # sops-rendered file via LoadCredential.
        services.netbird = {
          clients.${cfg.name} = {
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

            # Local Prometheus endpoint (netbird >=0.67): config.d fragment
            # keys are the PascalCase Go field names of
            # profilemanager.Config — source-verified against v0.81.0
            # (json.MarshalIndent with no json tags on these fields). Plain
            # bool/string values only, so the url.URL ManagementUrl
            # string-fragment crash class cannot apply. The nixpkgs preStart
            # shallow-merges config.d/*.json into config.json on every
            # start, so the keys converge even after netbird rewrites the
            # file (they round-trip: the daemon serializes the whole
            # struct).
            config = {
              LocalMetricsEnabled = cfg.metrics.enable;
              LocalMetricsAddress = cfg.metrics.address;
            };
            login = {
              enable = true;
              setupKeyFile = config.sops.secrets.netbird_setup_key.path;
              # NO extra systemdDependencies (default []): this flake renders
              # sops secrets via the ACTIVATION script (no
              # sops-install-secrets.service unit exists) — the nixpkgs
              # doc-example value made the login unit Require a not-found
              # unit, so ANY start (boot enqueue or manual) died on the
              # dangling dep (discovered live 2026-10-15; sops files are
              # rendered before sysinit, so no ordering edge is needed).
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
        #
        # NEVER boot-blocking + finite start budget (2026-10-17 infinite-boot
        # incident): the nixpkgs login script waits in an UNGUARDED
        # `until netbird status | grep -q ': Connected\|NeedsLogin'; do
        # sleep 1` loop — while the daemon cycles Connecting/Disconnected
        # (control plane slow/unreachable) NEITHER pattern ever matches, and
        # get_status's `2>&1 || :` swallows exec errors, so a dead/missing
        # wrapper binary loops silently once per second forever. Type=oneshot
        # defaults TimeoutStartSec to INFINITY, and a multi-user.target.wants
        # unit with no After= on that target keeps its start job in the
        # target's wait set → multi-user.target + graphical.target + the
        # repo's own boot-metrics-emit sat "waiting" for 55+ min with the
        # desktop fully up, FinishTimestampMonotonic stayed 0 (systemd-analyze
        # plot refuses; the stuck unit never appears in blame — completed
        # units only), and deploy.sh's converger restart parked behind it.
        # Two bounds: After=multi-user.target moves the unit PAST the
        # target's job-completion set (canonical post-boot start), and a 2min
        # TimeoutStartSec turns a wedged login into a loud notify-failure +
        # converger retry instead of an immortal loop.
        systemd.services."netbird-${cfg.name}-login" = {
          # late-applications (2026-10-26 ordering-cycle class fix):
          # membership replaces after=multi-user.target — same canonical
          # post-boot start WITHOUT the backward edge that armed the
          # gitea-runner deleted-start-job class. The 2min bound below and
          # the deploy.sh unconditional converger restart are unchanged.
          wantedBy = [ "late-applications.target" ];
          # Unit-level (NOT serviceConfig): OnFailure is a [Unit] key —
          # serviceConfig.OnFailure renders under [Service] where systemd
          # silently ignores it (visionreviewd ships that latent no-op).
          inherit onFailure;
          serviceConfig.TimeoutStartSec = "2min";
        };

        # State hygiene (2026-10-06): the phase-2 deploy's string-form
        # "ManagementUrl" fragment poisoned /var/lib/netbird-evox2/config.json,
        # and the nixpkgs preStart jq fragment-merge never REMOVES keys — purge
        # string-typed management-URL keys ourselves. Object-typed values were
        # written by netbird itself and must survive. mkAfter because the
        # nixpkgs preStart is what exports $NB_CONFIG and the jq PATH.
        systemd.services."netbird-${cfg.name}" = {
          # A fragment-only change (metrics settings) never restarts the
          # daemon otherwise — nixpkgs wires NO restartTriggers for the
          # config.d file (source-verified, pinned rev) — so the daemon
          # would keep running on the OLD merged config until the next
          # manual restart.
          restartTriggers = [
            config.environment.etc."netbird-${cfg.name}/config.d/50-nixos.json".source
          ];

          preStart = lib.mkAfter ''
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
        };

        # Service-integration registry entry: unit-state monitoring + the
        # mesh-connection check (no vHost — the client is not a web service).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          netbird = {
            enable = true;
            vHost.layer = "none";
            monitored = true;
            checks = [
              {
                # Anchored pair per monitoring.md (2026-10-17 PapDashboard
                # worked example): the negative leg catches an explicit 0 at
                # a LINE START (\n before the name — no lookalike substring
                # can satisfy it), the positive leg demands presence with
                # value 1 — so BOTH absence (endpoint down / collector
                # stale) and value-0 (management stream lost) fail the
                # check. This is the 2026-10-17 8h-outage signal: the unit
                # stayed active/running the whole time.
                name = "NetBird Mesh Connection";
                group = "NetBird Control Plane";
                url = "http://127.0.0.1:${toString ports.netbird-metrics}/metrics";
                interval = "1m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\nnetbird_management_connected 1*)"
                  "[BODY] != pat(*\nnetbird_management_connected 0\n*)"
                ];
                alert = "NetBird client lost its management-plane connection (local metrics: netbird_management_connected != 1) — tunnels persist but no re-routes/enrollments/DNS updates; this stayed invisible for 8h on 2026-10-17. Check: journalctl -u netbird-${cfg.name}, netbird status";
              }
            ];
          };
        };
      };
    };
}
