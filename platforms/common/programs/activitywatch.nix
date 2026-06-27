{
  pkgs,
  lib,
  ...
}: let
  ports = (import ../../../lib/default.nix lib).ports;
in {
  services.activitywatch = {
    enable = pkgs.stdenv.isLinux;
    package = pkgs.activitywatch;
    watchers = {
      aw-watcher-window-wayland = {
        package = pkgs.aw-watcher-window-wayland;
      };
      aw-watcher-utilization = {
        package = pkgs.aw-watcher-utilization;
        settings = {
          aw-watcher-utilization = {
            poll_time = 5;
          };
        };
      };
    };
  };

  systemd.user.services = lib.optionalAttrs pkgs.stdenv.isLinux {
    activitywatch-watcher-aw-watcher-window-wayland = {
      Unit = {
        After = lib.mkAfter ["graphical-session.target"];
        PartOf = lib.mkAfter ["graphical-session.target"];
      };
      Service = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    activitywatch-theme = {
      Unit = {
        Description = "Set ActivityWatch theme to dark";
        After = ["activitywatch.service"];
        PartOf = ["activitywatch.service"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.curl} --retry 5 --retry-delay 2 --retry-connrefused -X POST -H 'Content-Type: application/json' -d '\"dark\"' http://localhost:${toString ports.activitywatch}/api/0/settings/theme";
        RemainAfterExit = true;
      };
      Install.WantedBy = ["activitywatch.target"];
    };
  };
}
