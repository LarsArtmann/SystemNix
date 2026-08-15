{
  pkgs,
  lib,
  ...
}:
let
  inherit ((import ../../../lib/default.nix lib)) ports;

  # The watcher hard-fails (panic, main.rs:38) when no Wayland display is
  # reachable: it tries $WAYLAND_DISPLAY, then falls back to "wayland-0".
  # On this machine niri frequently takes wayland-1 (SDDM's greeter held
  # wayland-0), so the name fallback never works, and at boot the user
  # manager's environment import lags the compositor. After= alone cannot
  # fix this: ordering is skipped unless the ordered unit has a pending job
  # in the same transaction (true at deploy-time restarts, false at boot).
  # The wrapper waits for a live socket on disk and re-resolves the name.
  aw-watcher-window-wayland-gate = pkgs.writeShellApplication {
    name = "aw-watcher-window-wayland-gate";
    text = ''
      timeout_s="''${AW_WAYLAND_GATE_TIMEOUT:-60}"
      waited=0
      while true; do
        sock=""
        if [ -n "''${WAYLAND_DISPLAY:-}" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
          sock="$WAYLAND_DISPLAY"
        else
          for candidate in "$XDG_RUNTIME_DIR"/wayland-[0-9]; do
            [ -S "$candidate" ] || continue
            sock="''${candidate##*/}"
            break
          done
        fi
        if [ -n "$sock" ]; then
          exec env WAYLAND_DISPLAY="$sock" "$@"
        fi
        if [ "$waited" -ge "$timeout_s" ]; then
          echo "aw-watcher-window-wayland: no wayland socket appeared within ''${timeout_s}s (XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-unset})" >&2
          exit 1
        fi
        sleep 1
        waited=$((waited + 1))
      done
    '';
  };
in
{
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
        After = lib.mkAfter [
          "graphical-session.target"
          "niri.service"
        ];
        # Wants= pulls the target into this unit's start transaction; without
        # it, After= is ignored whenever the target has no pending job (boot).
        Wants = lib.mkAfter [ "graphical-session.target" ];
        PartOf = lib.mkAfter [ "graphical-session.target" ];
        StartLimitBurst = 5;
        StartLimitIntervalSec = 300;
      };
      Service = {
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = lib.mkForce "${lib.getExe aw-watcher-window-wayland-gate} ${lib.getExe pkgs.aw-watcher-window-wayland}";
      };
    };

    activitywatch-theme = {
      Unit = {
        Description = "Set ActivityWatch theme to dark";
        After = [ "activitywatch.service" ];
        PartOf = [ "activitywatch.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.curl} --retry 5 --retry-delay 2 --retry-connrefused -X POST -H 'Content-Type: application/json' -d '\"dark\"' http://localhost:${toString ports.activitywatch}/api/0/settings/theme";
        RemainAfterExit = true;
      };
      Install.WantedBy = [ "activitywatch.target" ];
    };
  };
}
