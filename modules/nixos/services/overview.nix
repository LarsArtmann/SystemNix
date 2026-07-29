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
#   - partOf PMA: restart Overview whenever PMA restarts (re-discover after PMA
#     recovers).
#   - discovery-watchdog timer: if Overview is 503 while the daemon is healthy
#     (PMA's scan finished), restart Overview so it re-discovers successfully.
#     This converges on its own once PMA settles, with no extra deploy.
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
      daemonSock = "/run/project-discovery/daemon.sock";
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
          echo "overview: project-discovery daemon not ready after 60s — proceeding anyway (discovery may fail)" >&2
          exit 0
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
        systemd.services.overview = {
          after = [ "projects-management-automation.service" ];
          wants = [ "projects-management-automation.service" ];
          partOf = [ "projects-management-automation.service" ];
          serviceConfig.ExecStartPre = "+${lib.getExe waitDaemonReady}";
        };

        systemd.services.overview-discovery-watchdog = {
          description = "Restart Overview when it is 503 but the discovery daemon is healthy";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe discoveryWatchdog;
          };
        };

        systemd.timers.overview-discovery-watchdog = {
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
}
