{
  pkgs,
  lib,
  ...
}: {
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
    activitywatch-theme = {
      Unit = {
        Description = "Set ActivityWatch theme to dark";
        After = ["activitywatch.service"];
        PartOf = ["activitywatch.service"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.curl}/bin/curl --retry 5 --retry-delay 2 --retry-connrefused -X POST -H 'Content-Type: application/json' -d '\"dark\"' http://localhost:5600/api/0/settings/theme";
        RemainAfterExit = true;
      };
      Install.WantedBy = ["activitywatch.target"];
    };
  };
}
