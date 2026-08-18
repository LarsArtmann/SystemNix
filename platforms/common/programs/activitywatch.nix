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
      timeout_s="''${AW_WAYLAND_GATE_TIMEOUT:-0}"
      # <=0 (default) waits indefinitely: at a lingering boot there is no
      # Wayland socket until the user actually logs in via SDDM, which can be
      # hours later. Failing after a timeout trips StartLimitBurst and leaves
      # the watcher dead for the whole session.
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
        if [ "$timeout_s" -gt 0 ] && [ "$waited" -ge "$timeout_s" ]; then
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
    enable = pkgs.stdenv.hostPlatform.isLinux;
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

  systemd.user.services = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    activitywatch-watcher-aw-watcher-window-wayland = {
      Unit = {
        After = lib.mkAfter [
          "graphical-session.target"
          "niri.service"
        ];
        # NEVER add Wants=graphical-session.target here. This unit is enabled
        # via activitywatch.target -> default.target, so Wants= pulls
        # graphical-session.target into the user-manager BOOT transaction
        # (lingering starts it before SDDM exists). The target then starts
        # niri-session-manager (Requires=niri.service) -> a headless zombie
        # niri, and SDDM's niri-session exits "A niri session is already
        # running" -> black screen on login (2026-08-18 incident). The gate
        # wrapper above already waits for the compositor socket, so no Wants
        # is needed for the deploy-time ordering case either.
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
