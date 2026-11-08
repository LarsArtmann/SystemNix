# Runbook: docs/services/health-dashboard.md
# health-dashboard — federated go-health hub (health.home.lan).
#
# Runs upstream's health-hub binary (github:LarsArtmann/go-health-dashboard,
# packages.health-hub): one dashboard federating every service's existing
# go-health endpoint over HTTP (go-health federation). Remote checks land
# namespaced "name/check" (worst-of across remotes), one card per remote
# (GroupBySource); a dark remote renders a "name/reachable" FAIL row instead
# of silently freezing at its last state.
#
#   - Binds 127.0.0.1:${ports.health-dashboard}. The vHost is Layer 2
#     protected — oauth2-proxy gates external access via Pocket ID;
#     go-health documents expose internal check names and error strings,
#     so the raw port must not reach the LAN (mr-sync posture).
#   - Stateless: no StateDirectory, no sops, no backup entry.
#
# DELEGATED 2026-11-08 (own-project upstreaming wave): the hub unit +
# options (enable, package, remotes, addr, trend) live upstream —
# inputs.go-health-dashboard.nixosModules.default. SystemNix layers ONLY
# site specifics: the port-registry addr, the federation drift sweep (its
# candidate list is derived from THIS host's port registry), onFailure,
# the fleet harden bound, and the integration/catalog entries.
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
        serviceOneshotDefaults
        onFailure
        ports
        ;

      # Federation drift sweep candidates: every registry port EXCEPT the
      # hub itself (federating the hub with its own merged document would
      # recurse). Name=port pairs baked in at eval time — zero port literals
      # in the unit text (port-registry-audit reads Exec*/Environment only).
      candidates = lib.mapAttrsToList (name: p: "${name}=${toString p}") (
        lib.filterAttrs (n: _: n != "health-dashboard") ports
      );

      # The 2026-11-02 incident: the remotes list said only CV for five weeks
      # while four services silently adopted go-health v0.8.x — the
      # 2026-09-22 "nobody else speaks go-health" inventory was never
      # re-probed. This sweep is the runtime complement to the eval-time
      # list: every candidate port is probed on the three go-health paths; a
      # body that decodes as a go-health document (status pass/warn/fail/off
      # AND a checks object — custom {"status":"ok"}/{"status":"up"}/HTML
      # health JSON fails exactly this test) on an UNFEDERATED port fails the
      # unit with the exact remotes line to add. Connection-refused, 4xx/5xx
      # and undecodable bodies are skipped, so the only failure mode is
      # positive go-health evidence — no false-positive class exists by
      # construction.
      rediscover = pkgs.writeShellApplication {
        name = "health-dashboard-rediscover";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
        ];
        text = ''
          set -euo pipefail

          remotes="${lib.concatStringsSep "," cfg.remotes}"
          federated=$(printf '%s' "$remotes" | grep -oE ':[0-9]+' | tr -d ':' | sort -un)
          drift=0

          for pair in ${lib.concatStringsSep " " candidates}; do
            name=''${pair%%=*}
            port=''${pair##*=}
            if printf '%s\n' "$federated" | grep -qx "$port"; then
              continue
            fi
            for path in /health /readyz /healthz; do
              body=$(curl -sf -m 3 -H 'Accept: application/json' "http://127.0.0.1:''${port}''${path}" 2>/dev/null) || continue
              if printf '%s' "$body" | jq -e '((.status == "pass") or (.status == "warn") or (.status == "fail") or (.status == "off")) and (.checks | type == "object")' >/dev/null 2>&1; then
                echo "health-dashboard-rediscover: ''${name} (127.0.0.1:''${port}''${path}) serves a go-health document but is NOT federated." >&2
                echo "health-dashboard-rediscover: add \"''${name}=http://127.0.0.1:''${port}''${path}\" to services.health-dashboard.remotes (platforms/nixos/system/configuration.nix) and redeploy." >&2
                drift=1
                break
              fi
            done
          done

          exit ''${drift}
        '';
      };
    in
    {
      imports = [
        inputs.go-health-dashboard.nixosModules.default
        # Platform-truth catalog entry (ADR-008): unconditional — the health
        # hub exists platform-wide even where this host has it disabled.
        # Requires nixosModules.catalog (auto-discovered on evo-x2, imported
        # on rpi3); a missing import fails loudly at eval, which is the point.
        {
          services.catalog.health-dashboard = {
            subdomain = "health";
            port = ports.health-dashboard;
            description = "Federated go-health hub dashboard";
            healthPath = "/healthz";
          };
        }
      ];

      config = lib.mkIf cfg.enable {
        services.health-dashboard = {
          package = lib.mkDefault inputs.go-health-dashboard.packages.${pkgs.stdenv.hostPlatform.system}.health-hub;
          # Loopback from the port registry — never a literal (the raw
          # port must not reach the LAN; the protected vHost fronts it).
          addr = "127.0.0.1:${toString ports.health-dashboard}";
        };

        systemd.services.health-dashboard = {
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            (harden { MemoryMax = lib.mkForce "256M"; })
            (serviceDefaults { })
          ];
        };

        # Daily federation drift sweep — see the rediscover comment above for
        # the no-false-positive argument. Failing (drift found) pages through
        # onFailure like any service failure; the message carries the exact
        # remotes line to add.
        systemd.services.health-dashboard-rediscover = {
          description = "Health hub federation drift sweep (unfederated go-health speakers)";
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = lib.getExe rediscover;
              TimeoutStartSec = "5m";
              # Probe-only: no state, no secrets.
              DynamicUser = true;
            }
            (harden { MemoryMax = "128M"; })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.health-dashboard-rediscover = {
          description = "Health hub federation drift sweep cadence";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "15m";
            OnUnitActiveSec = "24h";
            Persistent = true;
          };
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
              icon = "beszel.png";
            };
            monitored = true;
          };
        };
      };
    };
}
