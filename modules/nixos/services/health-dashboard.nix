# health-dashboard — federated go-health hub (health.home.lan).
#
# Runs upstream's health-hub binary (github:LarsArtmann/go-health-dashboard,
# packages.health-hub): one dashboard federating every service's existing
# go-health endpoint over HTTP (go-health federation). Remote checks land
# namespaced "name/check" (worst-of across remotes), one card per remote
# (GroupBySource); a dark remote renders a "name/reachable" FAIL row instead
# of silently freezing at its last state.
#
#   - Binds 127.0.0.1:${ports.health-dashboard} (HEALTH_HUB_ADDR). The vHost
#     is Layer 2 protected — oauth2-proxy gates external access via Pocket
#     ID; go-health documents expose internal check names and error strings,
#     so the raw port must not reach the LAN (mr-sync posture).
#   - Stateless: no StateDirectory, no sops, no backup entry. The hub is
#     merge-on-read — every dashboard tick and probe fetches the remotes
#     fresh; its only memory is the in-process trend ring (opt-in).
#   - Remotes are deployment configuration (services.health-dashboard.
#     remotes): validated name=url pairs passed through HEALTH_HUB_REMOTES;
#     the binary fails fast at startup when an entry is malformed.
{ inputs, ... }:
{
  flake.nixosModules.health-dashboard =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.health-dashboard;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        ports
        ;
    in
    {
      # Platform-truth catalog entry (ADR-008): unconditional — the health
      # hub exists platform-wide even where this host has it disabled.
      imports = [
        {
          services.catalog = lib.optionalAttrs (options ? services.catalog) {
            health-dashboard = {
              subdomain = "health";
              port = ports.health-dashboard;
              description = "Federated go-health hub dashboard";
              healthPath = "/healthz";
            };
          };
        }
      ];

      options.services.health-dashboard = {
        enable = lib.mkEnableOption "federated go-health hub dashboard";

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.go-health-dashboard.packages.${pkgs.system}.default;
          defaultText = lib.literalExpression "inputs.go-health-dashboard.packages.${pkgs.system}.default";
          description = "The health-hub package (github:LarsArtmann/go-health-dashboard).";
        };

        remotes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Federated upstreams as name=url pairs, fetched fresh on every
            read. Names namespace checks (name/check) and must be unique,
            non-empty, and free of "/". URLs are absolute http(s) endpoints
            answering GET with a go-health JSON document (a bare probe's
            readiness handler, or any go-health-dashboard route — the hub
            always sends Accept: application/json).
          '';
          example = [ "cv=http://127.0.0.1:8098/health" ];
        };

        trend = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable the trend sparkline + timeline card (in-memory ring,
            ~1h of samples at the 2s push cadence). Purely additive — no
            persistence, no wire-contract change.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.remotes != [ ];
            message = "services.health-dashboard.remotes must list at least one name=url pair — a federation of nothing has no surface to serve (upstream ErrNoRemotes fails the unit at startup anyway; this fails the eval instead).";
          }
        ];

        systemd.services.health-dashboard = {
          description = "Federated go-health hub (health.home.lan)";
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "simple";
              # Stateless network daemon: no home, no state dir, no secrets.
              DynamicUser = true;
              ExecStart = "${lib.getExe cfg.package}";
              Environment = lib.concatStringsSep " " (
                [
                  "HEALTH_HUB_ADDR=127.0.0.1:${toString ports.health-dashboard}"
                  "HEALTH_HUB_REMOTES=${lib.concatStringsSep "," cfg.remotes}"
                ]
                ++ lib.optional cfg.trend "HEALTH_HUB_TREND=1"
              );
            }
            (harden { MemoryMax = "256M"; })
            (serviceDefaults { })
          ];
        };

        # Service-integration registry entry (modules/nixos/services/
        # integration.nix): ONE declaration fans out to the Caddy vHost
        # (Layer 2 protected), the Gatus checks, the dashboard tile, and
        # system-health monitoring. No backup (stateless), no OIDC client
        # (the protected layer owns external auth), no OTel (the binary
        # carries none — miniflux doctrine).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          health-dashboard = {
            subdomain = "health";
            port = ports.health-dashboard;
            vHost.layer = "protected";
            checks = [
              {
                # Liveness: the hub's own probe surface (federation-free —
                # answers once the process is up, even while a remote is
                # dark). Liveness + functional pair per the Gatus doctrine.
                name = "Health Hub";
                group = "Monitoring";
                path = "/healthz";
                interval = "1m";
                conditions = [ "[STATUS] == 200" ];
                alert = "health-hub down — the federated health hub at health.home.lan is unreachable. Check: systemctl status health-dashboard, journalctl -u health-dashboard -n 100.";
              }
              {
                # Readiness IS the federation: go-health readiness merges
                # every remote and 503s when any federated service reports
                # fail (or is dark — the name/reachable row). This is the
                # aggregate pager the hub exists to provide: a critical
                # check ANYWHERE pages here, even when the owning service's
                # own 200-liveness stays green.
                name = "Health Hub Federation";
                group = "Monitoring";
                path = "/readyz";
                interval = "1m";
                conditions = [
                  "[STATUS] == 200"
                  # Worst case: every remote burns its own 5s fetch deadline
                  # before the merge completes. Must stay under the client
                  # timeout below.
                  "[RESPONSE_TIME] < 8000"
                ];
                client = {
                  timeout = "15s";
                };
                alert = "health-hub federation degraded — a federated service reports fail or is dark (worst-of across remotes). Open health.home.lan for the name/reachable row; the owning service's own checks carry the specifics.";
              }
            ];
            homepage = {
              name = "health";
              group = "Monitoring";
              description = "Federated go-health hub";
              icon = "mdi-heart-pulse";
            };
            monitored = true;
          };
        };
      };
    };
}
