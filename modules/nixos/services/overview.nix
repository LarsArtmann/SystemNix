# Overview — SystemNix wrapper around the upstream overview module.
#
# Imports the upstream nixosModules.default and layers a daemon-readiness gate.
# Overview performs project discovery exactly ONCE at startup and never retries:
# if it connects before the PMA project-discovery daemon is listening (a deploy
# race of a few seconds while both services restart), it caches a nil discovery
# result and returns HTTP 503 forever. The ExecStartPre gate below waits for the
# daemon to actually answer over its unix socket before overview starts, closing
# the race. Ordering overview after PMA makes the window deterministic.
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
      waitDaemonReady = pkgs.writeShellApplication {
        name = "overview-wait-daemon";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          end=$((SECONDS + 60))
          while [ $SECONDS -lt $end ]; do
            if curl -sf --max-time 2 --unix-socket /run/project-discovery/daemon.sock \
              http://localhost/v1/health >/dev/null 2>&1; then
              exit 0
            fi
            sleep 1
          done
          echo "overview: project-discovery daemon not ready after 60s — proceeding anyway (discovery may fail)" >&2
          exit 0
        '';
      };
    in
    {
      imports = [ inputs.overview.nixosModules.default ];

      config = lib.mkIf cfg.enable {
        systemd.services.overview = {
          after = [ "projects-management-automation.service" ];
          wants = [ "projects-management-automation.service" ];
          # Overview discovers exactly once at startup and never retries: if the
          # PMA discovery daemon dies (OOM, restart) during that window, Overview
          # caches a nil result and 503s forever. partOf restarts Overview
          # whenever PMA restarts, so after PMA recovers Overview re-discovers
          # against a healthy daemon (the ExecStartPre gate waits for it).
          partOf = [ "projects-management-automation.service" ];
          serviceConfig.ExecStartPre = "+${lib.getExe waitDaemonReady}";
        };
      };
    };
}
