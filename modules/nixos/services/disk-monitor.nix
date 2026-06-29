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
    inherit (import ../../../lib/default.nix lib) hardenUser mkDesktopNotifyService;
    uid = builtins.toString config.users.users.${cfg.user}.uid;

    checkScript = ''
      STATE_DIR="$HOME/.local/state/disk-monitor"
      mkdir -p "$STATE_DIR"

      THRESHOLDS=(${lib.concatStringsSep " " (map toString cfg.thresholds)})
      MOUNT_POINTS=(${lib.concatStringsSep " " cfg.fileSystems})

      notify() {
        local urgency="$1" mount="$2" pct="$3" size_info="$4"
        notify-send \
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

        read -r total _ avail pct_raw _ < <(df -B1 --output=size,used,avail,pcent,target "$mount" | tail -1)
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

        logger -t "disk-monitor" \
          "[$mount] usage at $pct% (threshold: $triggered%) — $size_info"
      done
    '';

    notifyService = mkDesktopNotifyService pkgs {
      name = "disk-monitor";
      description = "Check disk usage and notify on threshold breaches";
      inherit checkScript;
      runtimeInputs = [
        pkgs.libnotify
        pkgs.util-linux
        pkgs.coreutils
        pkgs.systemd
      ];
      user = cfg.user;
      inherit uid;
      interval = cfg.interval;
      bootDelay = "2min";
      hardenFn = hardenUser;
    };
  in {
    options.services.disk-monitor = {
      enable = lib.mkEnableOption "Btrfs disk usage monitoring with desktop notifications";

      fileSystems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "/"
          "/data"
        ];
        description = "List of mount points to monitor";
      };

      thresholds = lib.mkOption {
        type = lib.types.listOf lib.types.ints.unsigned;
        default = [
          80
          85
          90
          95
          97
          98
          99
        ];
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
        timers.disk-monitor = notifyService.timer;
        services.disk-monitor = notifyService.service;
      };
    };
  };
}
