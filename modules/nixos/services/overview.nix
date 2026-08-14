# Overview — SystemNix wrapper around the upstream overview module.
#
# Two problems make Overview return HTTP 503 after every deploy:
#   1. Overview runs project discovery exactly ONCE at startup and never retries.
#   2. Its discovery request to the PMA project-discovery daemon times out
#      (~2 min) whenever PMA is mid-scan on restart (PMA re-scans ~293 projects,
#      which is slow). Overview then caches a nil result and 503s forever.
#
# Mitigations layered here:
#   - ExecStartPre gate: wait for the daemon socket to answer before starting.
#     Fails (exit 1) with a clear warning if the daemon is not available,
#     preventing overview from starting and immediately crashing with exit 69.
#   - Eval-time assertion: if daemon mode is enabled but PMA is not, fail the
#     build with an actionable message instead of deploying a crash-loop.
#   - partOf PMA: restart Overview whenever PMA restarts (re-discover after PMA
#     recovers).
#   - discovery-watchdog timer: if Overview is 503 while the daemon is healthy
#     (PMA's scan finished), restart Overview so it re-discovers successfully.
#     This converges on its own once PMA settles, with no extra deploy.
#   - StartLimitBurst/StartLimitIntervalSec: placed at the top-level (maps to
#     [Unit] section) because upstream sets them in serviceConfig ([Service])
#     where systemd 261+ silently ignores them, causing infinite crash-loops.
{ inputs, ... }:
{
  flake.nixosModules.overview =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.overview;
      pmaCfg = config.services.projects-management-automation;
      inherit (import ../../../lib/default.nix lib) ports;
      daemonSock = "/run/project-discovery/daemon.sock";
      daemonMode = cfg.daemonSocket != "";
      waitDaemonReady = pkgs.writeShellApplication {
        name = "overview-wait-daemon";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          end=$((SECONDS + 60))
          while [ $SECONDS -lt $end ]; do
            if curl -sf --max-time 2 --unix-socket ${daemonSock} \
              http://localhost/v1/health >/dev/null 2>&1; then
              exit 0
            fi
            sleep 1
          done
          echo "overview: project-discovery daemon not available at ${daemonSock} after 60s — not starting overview." >&2
          echo "Enable services.projects-management-automation or set services.overview.daemonSocket = \"\" for in-process discovery." >&2
          exit 1
        '';
      };
      # Overview caches a failed discovery and never retries. If it is 503 while
      # the daemon is healthy (PMA finished its startup scan), restart Overview
      # so it re-discovers. Runs as root so it can call systemctl restart.
      discoveryWatchdog = pkgs.writeShellApplication {
        name = "overview-discovery-watchdog";
        runtimeInputs = [
          pkgs.curl
          pkgs.systemd
        ];
        text = ''
          set -u
          ov_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1:8083/ 2>/dev/null || echo 000)
          # Only act on an explicit 503. Other codes (200, 000/down, redirects)
          # mean Overview is fine or not worth restarting.
          [ "$ov_status" = "503" ] || exit 0
          if ! curl -sf --max-time 3 --unix-socket ${daemonSock} http://localhost/v1/health >/dev/null 2>&1; then
            # Daemon not healthy either — restart would not help. Wait.
            exit 0
          fi
          echo "overview is 503 but the discovery daemon is healthy — restarting overview to re-discover"
          systemctl restart overview.service
        '';
      };
    in
    {
      imports = [ inputs.overview.nixosModules.default ];

      config = lib.mkIf cfg.enable {
        assertions = lib.optional daemonMode {
          assertion = pmaCfg.enable;
          message = ''
            overview.service is configured with daemonSocket = "${cfg.daemonSocket}"
            but services.projects-management-automation.enable is false.
            The project-discovery daemon is provided by PMA — either:
              1. Enable PMA: services.projects-management-automation.enable = true
              2. Use in-process discovery: services.overview.daemonSocket = ""
          '';
        };

        systemd = {
          services.overview = {
            after = [ "projects-management-automation.service" ];
            wants = [ "projects-management-automation.service" ];
            partOf = [ "projects-management-automation.service" ];
            # Fix: upstream sets these in serviceConfig ([Service] section)
            # where systemd 261+ silently ignores them. Top-level options
            # map to [Unit] where they actually take effect.
            # NOTE: do NOT try to null out the upstream serviceConfig entries —
            # nixpkgs renders null as an empty key ("StartLimitBurst="), which
            # systemd rejects with a parse warning. Upstream moved them to the
            # top level (see LarsArtmann/overview module.nix); once the flake
            # input is bumped past ac307aa8 the stale [Service] copies vanish.
            startLimitBurst = 3;
            startLimitIntervalSec = 60;
            serviceConfig.ExecStartPre = lib.mkIf daemonMode "+${lib.getExe waitDaemonReady}";
            serviceConfig.TimeoutStartSec = "3min";
            environment = {
              OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
            };
          };

          services.overview-discovery-watchdog = {
            description = "Restart Overview when it is 503 but the discovery daemon is healthy";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe discoveryWatchdog;
            };
          };

          timers.overview-discovery-watchdog = {
            description = "Periodically recover Overview from a stale 503 discovery failure";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "3min";
              OnUnitActiveSec = "2min";
              AccuracySec = "30s";
            };
          };
        };
      };
    };
}
