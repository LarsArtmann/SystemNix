# systemd-timer-monitor: read-only audit of systemd services+timers, served
# as a static HTML page. Zero-dep Python (cappy-dev/systemd-timer-monitor),
# runs every 5 minutes via a systemd timer, output lands in StateDirectory
# which Caddy serves via file_server.
#
# Review tool — exposed on LAN only (no auth). Disabled by default.
_: {
  flake.nixosModules.systemd-timer-monitor =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        mkStateDir
        ;

      cfg = config.services.systemd-timer-monitor;
      stateDir = "/var/lib/systemd-timer-monitor";
      reportPath = "${stateDir}/report.html";
      jsonPath = "${stateDir}/status.json";

      auditScript = pkgs.writeShellApplication {
        name = "systemd-audit-run";
        runtimeInputs = [
          pkgs.systemd-timer-monitor
          pkgs.coreutils
          pkgs.python3
        ];
        text = ''
          set -eu
          mkdir -p "${stateDir}"
          # Run as root for accurate failed-unit counts (most reads work as
          # the service user too). The script is read-only: --quiet suppresses
          # stdout. Exit code 1 = "issues found" (expected for a monitoring
          # tool) — the report is always written before the exit. Suppress the
          # non-zero exit so systemd doesn't mark the oneshot as failed.
          systemd-audit \
            --quiet \
            --timeout 30 \
            -o "${reportPath}" \
            --json "${jsonPath}" || true
          # Refresh mtime for liveness checks (Caddy file_server serves the
          # latest snapshot on every request; mtime is the freshness signal).
          : > "${stateDir}/.last-run"
        '';
      };
    in
    {
      options.services.systemd-timer-monitor = {
        enable = lib.mkEnableOption "systemd-timer-monitor (read-only services+timers audit, static HTML)";
        interval = lib.mkOption {
          type = lib.types.str;
          default = "5min";
          description = "How often to re-run the audit. Default 5min matches Gatus cadence.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.systemd-timer-monitor-audit = {
          description = "systemd-timer-monitor: write HTML audit of services and timers";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-timer.target" ];
          inherit onFailure;

          # Timer-driven oneshot: the timer IS the retry mechanism. Restart=no
          # + a generous short-window burst keeps one failed run from blocking
          # the next scheduled fire (see systemd gotcha on Restart racing timers).
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = lib.getExe auditScript;
              User = "root";
              Group = "root";
              StateDirectory = "systemd-timer-monitor";
              WorkingDirectory = stateDir;
            }
            (harden { })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.systemd-timer-monitor-audit = {
          description = "Periodic systemd services+timers audit";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
            AccuracySec = "5s";
          };
        };

        # The HTML file + JSON are served as a plain static directory by
        # caddy.nix. No service needed for serving — file_server on the
        # state dir is the only reader.
        systemd.tmpfiles.rules = [
          (mkStateDir stateDir "0755" "root" "root")
        ];

        # Service-integration registry entry: the Gatus check and homepage
        # tile. The timers vHost STAYS hand-written in caddy.nix — it is a
        # file_server over the state dir, not a reverse_proxy (the registry
        # seam only renders proxy vHosts). Replaces rows in gatus-config.nix
        # / homepage.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          systemd-timer-monitor = {
            enable = cfg.enable;
            subdomain = "timers";
            vHost.layer = "none";
            checks = [
              {
                name = "systemd-timer-monitor";
                group = "Review Tools";
                url = "https://timers.home.lan/";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*<!DOCTYPE html*)"
                ];
                alert = "systemd-timer-monitor report down — timers.home.lan unreachable or stale";
              }
            ];
            homepage = {
              name = "systemd-timer-monitor";
              group = "Review Tools";
              description = "Systemd Services & Timers Audit";
              icon = "mdi-timer-outline";
            };
          };
        };
      };
    };
}
