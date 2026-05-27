# NVMe SSD health monitoring with desktop notifications for critical events
_: {
  flake.nixosModules.nvme-health-monitor = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.nvme-health-monitor;
    inherit (config.users) primaryUser;
    inherit (import ../../../lib/default.nix lib) hardenUser onFailure;
    uid = builtins.toString config.users.users.${cfg.user}.uid;

    checkScript = pkgs.writeShellApplication {
      name = "nvme-health-check";
      runtimeInputs = [pkgs.nvme-cli pkgs.coreutils pkgs.gnugrep pkgs.libnotify pkgs.util-linux];
      text = ''
        STATE_DIR="$HOME/.local/state/nvme-health-monitor"
        mkdir -p "$STATE_DIR"

        DEVICE="${cfg.device}"

        notify() {
          local urgency="$1" title="$2" body="$3"
          notify-send \
            -u "$urgency" \
            -a "nvme-health-monitor" \
            -i "drive-harddisk" \
            "$title" \
            "$body" 2>/dev/null || true
        }

        needs_notify() {
          local key="$1" value="$2" state_file="$STATE_DIR/$key"
          local last=$(cat "$state_file" 2>/dev/null || echo "")
          if [ "$last" = "$value" ]; then
            return 1
          fi
          echo "$value" > "$state_file"
          return 0
        }

        # Read SMART data via nvme-cli
        if ! command -v nvme &>/dev/null; then
          exit 0
        fi

        SMART=$(nvme smart-log -o json "$DEVICE" 2>/dev/null) || exit 0

        extract() {
          local key="$1"
          echo "$SMART" | grep -oP "\"''${key}\"\s*:\s*\K[0-9]+"
        }

        CRITICAL_WARNING=$(extract "critical_warning")
        AVAILABLE_SPARE=$(extract "available_spare")
        PERCENTAGE_USED=$(extract "percentage_used")
        MEDIA_ERRORS=$(extract "media_errors")
        NUM_ERR_LOG=$(extract "num_err_log_entries")
        TEMP_KELVIN=$(echo "$SMART" | grep -oP '"temperature"\s*:\s*\K[0-9]+')
        TEMP_CELSIUS=$((TEMP_KELVIN - 273))

        # Critical warning — any non-zero value is urgent
        if [ "$CRITICAL_WARNING" -ne 0 ]; then
          if needs_notify "critical_warning" "$CRITICAL_WARNING"; then
            notify "critical" "NVMe Critical Warning!" \
              "Critical warning flags: $CRITICAL_WARNING on $(basename $DEVICE). Check SMART data immediately."
            logger -t "nvme-health-monitor" \
              "CRITICAL: warning flags=$CRITICAL_WARNING on $DEVICE"
          fi
        else
          needs_notify "critical_warning" "0" >/dev/null 2>&1 || true
        fi

        # Media errors — any non-zero is urgent
        if [ "$MEDIA_ERRORS" -ne 0 ]; then
          if needs_notify "media_errors" "$MEDIA_ERRORS"; then
            notify "critical" "NVMe Media Errors Detected!" \
          "$MEDIA_ERRORS media/data integrity errors on $(basename $DEVICE). Flash cells may be degrading."
            logger -t "nvme-health-monitor" \
              "CRITICAL: media_errors=$MEDIA_ERRORS on $DEVICE"
          fi
        else
          needs_notify "media_errors" "0" >/dev/null 2>&1 || true
        fi

        # Temperature check
        if [ "$TEMP_CELSIUS" -ge ${toString cfg.criticalTempThreshold} ]; then
          if needs_notify "temp_critical" "$TEMP_CELSIUS"; then
            notify "critical" "NVMe SSD Overheating!" \
              "Temperature: ''${TEMP_CELSIUS}°C (critical: ${toString cfg.criticalTempThreshold}°C) on $(basename $DEVICE)"
            logger -t "nvme-health-monitor" \
              "CRITICAL: temp=''${TEMP_CELSIUS}°C on $DEVICE"
          fi
        elif [ "$TEMP_CELSIUS" -ge ${toString cfg.warnTempThreshold} ]; then
          if needs_notify "temp_warn" "$TEMP_CELSIUS"; then
            notify "normal" "NVMe SSD Temperature High" \
              "Temperature: ''${TEMP_CELSIUS}°C (warning: ${toString cfg.warnTempThreshold}°C) on $(basename $DEVICE)"
            logger -t "nvme-health-monitor" \
              "WARN: temp=''${TEMP_CELSIUS}°C on $DEVICE"
          fi
        else
          needs_notify "temp_warn" "ok" >/dev/null 2>&1 || true
          needs_notify "temp_critical" "ok" >/dev/null 2>&1 || true
        fi

        # Endurance check
        if [ "$PERCENTAGE_USED" -ge 80 ]; then
          if needs_notify "endurance" "$PERCENTAGE_USED"; then
            notify "critical" "NVMe SSD Endurance Critical!" \
              "''${PERCENTAGE_USED}% of rated endurance consumed on $(basename $DEVICE). Replace drive soon."
            logger -t "nvme-health-monitor" \
              "CRITICAL: endurance=''${PERCENTAGE_USED}% on $DEVICE"
          fi
        elif [ "$PERCENTAGE_USED" -ge 50 ]; then
          if needs_notify "endurance" "$PERCENTAGE_USED"; then
            notify "normal" "NVMe SSD Endurance Warning" \
              "''${PERCENTAGE_USED}% of rated endurance consumed on $(basename $DEVICE). Plan for replacement."
            logger -t "nvme-health-monitor" \
              "WARN: endurance=''${PERCENTAGE_USED}% on $DEVICE"
          fi
        else
          needs_notify "endurance" "ok" >/dev/null 2>&1 || true
        fi

        # Available spare check
        if [ "$AVAILABLE_SPARE" -lt ${toString cfg.spareWarnThreshold} ]; then
          if needs_notify "spare" "$AVAILABLE_SPARE"; then
            notify "normal" "NVMe SSD Spare Blocks Low" \
              "Only ''${AVAILABLE_SPARE}% spare blocks remaining on $(basename $DEVICE). Drive is aging."
            logger -t "nvme-health-monitor" \
              "WARN: spare=''${AVAILABLE_SPARE}% on $DEVICE"
          fi
        else
          needs_notify "spare" "ok" >/dev/null 2>&1 || true
        fi
      '';
    };
  in {
    options.services.nvme-health-monitor = {
      enable = lib.mkEnableOption "NVMe SSD health monitoring with desktop notifications";

      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/nvme0n1";
        description = "NVMe device to monitor";
      };

      warnTempThreshold = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 65;
        description = "Temperature (°C) for warning notifications";
      };

      criticalTempThreshold = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 75;
        description = "Temperature (°C) for critical notifications";
      };

      spareWarnThreshold = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = "Available spare percentage below which to warn";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "2min";
        description = "Systemd timer interval for health checks";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User to send desktop notifications to";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd = {
        timers.nvme-health-monitor = {
          description = "Periodic NVMe SSD health check";
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
          };
          wantedBy = ["timers.target"];
        };

        services.nvme-health-monitor = {
          description = "Check NVMe SSD health and notify on critical events";
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
              ExecStart = lib.getExe checkScript;
              StandardOutput = "journal";
              StandardError = "journal";
            }
            // hardenUser {
              ProtectHome = false;
              NoNewPrivileges = false;
            };
        };
      };
    };
  };
}
