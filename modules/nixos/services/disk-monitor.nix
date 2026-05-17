# Btrfs disk usage monitoring with desktop notifications
_: {
  flake.nixosModules.disk-monitor = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.disk-monitor;
    inherit (config.users) primaryUser;
    inherit (import ../../../lib/default.nix lib) harden onFailure;
    uid = builtins.toString config.users.users.${cfg.user}.uid;

    checkScript = pkgs.writeShellScript "disk-monitor-check" ''
      set -euo pipefail

      STATE_DIR="$HOME/.local/state/disk-monitor"
      mkdir -p "$STATE_DIR"

      THRESHOLDS=(${lib.concatStringsSep " " (map toString cfg.thresholds)})
      MOUNT_POINTS=(${lib.concatStringsSep " " cfg.fileSystems})

      notify() {
        local urgency="$1" mount="$2" pct="$3" size_info="$4"
        ${pkgs.libnotify}/bin/notify-send \
          -u "$urgency" \
          -a "disk-monitor" \
          -i "drive-harddisk" \
          "Disk $pct% full: $mount" \
          "$size_info" 2>/dev/null || true
      }

      for mount in "''${MOUNT_POINTS[@]}"; do
        if ! mountpoint -q "$mount" 2>/dev/null; then
          continue
        fi

        read -r total used avail pct_raw _ < <(df -B1 --output=size,used,avail,pct,target "$mount" | tail -1)
        pct=''${pct_raw%\%}

        total_gb=$(numfmt --to=iec --suffix=B "$total")
        avail_gb=$(numfmt --to=iec --suffix=B "$avail")
        size_info="$avail_gb free of $total_gb"

        state_file="$STATE_DIR/$(systemd-escape "$mount")"

        # Find highest triggered threshold
        triggered=""
        for t in "''${THRESHOLDS[@]}"; do
          if [ "$pct" -ge "$t" ]; then
            triggered="$t"
          fi
        done

        if [ -z "$triggered" ]; then
          # Below all thresholds — clear any previous notification state
          if [ -f "$state_file" ]; then
            rm -f "$state_file"
          fi
          continue
        fi

        # Check if we already notified for this threshold
        if [ -f "$state_file" ]; then
          last_notified=$(cat "$state_file" 2>/dev/null || echo "0")
          if [ "$last_notified" = "$triggered" ]; then
            continue
          fi
          # Usage climbed to a new higher threshold — notify again
        fi

        # Determine urgency
        if [ "$triggered" -ge 97 ]; then
          urgency="critical"
        elif [ "$triggered" -ge 90 ]; then
          urgency="normal"
        else
          urgency="low"
        fi

        notify "$urgency" "$mount" "$pct" "$size_info"
        echo "$triggered" > "$state_file"

        ${pkgs.util-linux}/bin/logger -t "disk-monitor" \
          "[$mount] usage at $pct% (threshold: $triggered%) — $size_info"
      done
    '';
  in {
    options.services.disk-monitor = {
      enable = lib.mkEnableOption "Btrfs disk usage monitoring with desktop notifications";

      fileSystems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["/" "/data"];
        description = "List of mount points to monitor";
      };

      thresholds = lib.mkOption {
        type = lib.types.listOf lib.types.ints.unsigned;
        default = [80 85 90 95 97 98 99];
        description = "Percentage thresholds that trigger notifications";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "5min";
        description = "Systemd timer interval for disk checks";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User to send desktop notifications to";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd = {
        timers.disk-monitor = {
          description = "Periodic Btrfs disk usage check";
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
          };
          wantedBy = ["timers.target"];
        };

        services.disk-monitor = {
          description = "Check disk usage and notify on threshold breaches";
          inherit onFailure;
          serviceConfig =
            {
              Type = "oneshot";
              User = cfg.user;
              Environment = [
                "DISPLAY=:0"
                "WAYLAND_DISPLAY=wayland-1"
                "XDG_RUNTIME_DIR=/run/user/${uid}"
              ];
              ExecStart = checkScript;
              StandardOutput = "journal";
              StandardError = "journal";
            }
            // harden {
              ProtectHome = false;
              NoNewPrivileges = false;
            };
        };
      };
    };
  };
}
