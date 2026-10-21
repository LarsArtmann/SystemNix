# USB flap-counter metrics — textfile collector for the DAS/USB link churn.
#
# The 2026-08-16 enclosure storm logged 11 re-enumerations in 3.5 h and the
# 2026-08-22 JMS567 wedge took the whole DAS offline for 9 days — but the
# flap RATE was only ever countable by hand from the kernel journal, so the
# "did the enclosure swap / udev fix actually help" question (status report
# 2026-08-16_19-12 §f.12) stayed unanswerable. This collector counts kernel
# USB disconnect events from the persistent journal into Prometheus metrics
# and adds a rolling-hour rate flag Gatus can page on:
#
#   usb_flap_disconnects_total          cumulative across boots (state file)
#   usb_flap_disconnects_delta          since the previous run
#   usb_flap_disconnects_last_hour      rolling 1h window (event timestamps)
#   usb_flap_rate_over_threshold 1|0   last_hour >= alertThreshold
#   usb_flap_last_disconnect_epoch      0 = never within the journal window
#
# Fail-closed: on any journalctl error the file still lands with
# usb_flap_scrape_errors 1 so the pre-deploy phantom-metric gate and Gatus
# see a broken collector, never a silently frozen one.
#
# mktemp in the sticky textfile dir + CAP_FOWNER (mail-relay 2026-09-02..06
# foreign-owned-prom class); journal read needs no extra caps (adm group via
# systemd-journal group membership is granted by running as root).
{
  flake.nixosModules.usb-flap-metrics =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ;

      cfg = config.services.usb-flap-metrics;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
    in
    {
      options.services.usb-flap-metrics = {
        enable = lib.mkEnableOption "USB flap-counter metrics (kernel journal → node_exporter textfile)";

        alertThreshold = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Disconnects within the rolling hour at which usb_flap_rate_over_threshold flips to 1 (the 2026-08-16 storm ran ~2/h steady with 9 in 36 min).";
        };

        windowSeconds = lib.mkOption {
          type = lib.types.int;
          default = 3600;
          description = "Rolling window for the rate metric, in seconds.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "5min";
          description = "Collection interval (OnUnitActiveSec).";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.usb-flap-metrics = {
          description = "USB flap-counter metrics collector (textfile)";
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.systemd
            pkgs.gawk
            pkgs.gnugrep
            pkgs.coreutils
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              StateDirectory = "usb-flap-metrics";
            }
            (harden {
              ReadWritePaths = [ textfileDir ];
              # CAP_FOWNER for the sticky-dir rename over a foreign-owned
              # prom (mail-relay class). No device access needed.
              CapabilityBoundingSet = "CAP_FOWNER";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            OUT="${textfileDir}/usb-flap.prom"
            mkdir -p "${textfileDir}"
            TMP="$(mktemp "${textfileDir}/usb-flap.prom.XXXXXX")"
            chmod 644 "$TMP"
            STATE_DIR="''${STATE_DIRECTORY:-/var/lib/usb-flap-metrics}"
            STATE="$STATE_DIR/state"
            STATE_TMP="$(mktemp)"
            trap 'rm -f "$TMP" "$STATE_TMP"' EXIT

            THRESHOLD=${toString cfg.alertThreshold}
            WINDOW=${toString cfg.windowSeconds}
            NOW="$(date +%s)"

            scrape_errors=0
            delta=0
            total=0
            last_epoch=0

            # Resume from the stored journal timestamp; first run reads only
            # the current boot so a fresh deployment does not replay the
            # entire persistent history into one giant delta.
            since=0
            if [ -f "$STATE" ]; then
              read -r total since < "$STATE" 2>/dev/null || true
              total="''${total:-0}"
              since="''${since:-0}"
            else
              since="$(journalctl -k --output=short-unix -n 1 2>/dev/null | tail -1 | awk '{ print $1 }' | cut -d. -f1 || true)"
              case "$since" in ""|*[!0-9]*) since="$NOW" ;; esac
            fi

            EVENTS="$(mktemp)"
            trap 'rm -f "$TMP" "$STATE_TMP" "$EVENTS"' EXIT
            # grep exits 1 on a zero-match window — healthy, not an error.
            journalctl -k --output=short-unix --since "@$since" --until "@$NOW" 2>/dev/null \
              | grep -E 'usb [0-9]+-[0-9.]+: USB disconnect' > "$EVENTS" || true
            # Fail-closed probe: journalctl itself must still answer.
            if ! journalctl -k -n 1 >/dev/null 2>&1; then
              scrape_errors=1
            fi
            delta="$(wc -l < "$EVENTS")"
            case "$delta" in *[!0-9]*) delta=0; scrape_errors=1 ;; esac

            if [ "$delta" -gt 0 ]; then
              last_epoch="$(head -1 "$EVENTS" | awk '{ print $1 }' | cut -d. -f1)"
              case "$last_epoch" in *[!0-9]*|"") last_epoch="$NOW" ;; esac
            fi

            # Rolling-hour window: event epochs, one per line, pruned each run.
            WINDOW_FILE="$STATE_DIR/window"
            WINDOW_TMP="$(mktemp)"
            trap 'rm -f "$TMP" "$STATE_TMP" "$EVENTS" "$WINDOW_TMP"' EXIT
            cat "$EVENTS" | awk '{ print $1 }' | cut -d. -f1 >> "$WINDOW_FILE" 2>/dev/null || true
            awk -v cutoff="$((NOW - WINDOW))" '$1 >= cutoff' "$WINDOW_FILE" > "$WINDOW_TMP" 2>/dev/null || true
            mv "$WINDOW_TMP" "$WINDOW_FILE"
            last_hour="$(wc -l < "$WINDOW_FILE")"
            case "$last_hour" in *[!0-9]*|"") last_hour=0; scrape_errors=1 ;; esac
            rate_over=0
            [ "$last_hour" -ge "$THRESHOLD" ] && rate_over=1 || true

            total=$((total + delta))

            {
              echo "# HELP usb_flap_disconnects_total Cumulative kernel USB disconnect events across boots (state-persisted)"
              echo "# TYPE usb_flap_disconnects_total counter"
              echo "usb_flap_disconnects_total $total"
              echo "# HELP usb_flap_disconnects_delta Disconnects observed since the previous collector run"
              echo "# TYPE usb_flap_disconnects_delta gauge"
              echo "usb_flap_disconnects_delta $delta"
              echo "# HELP usb_flap_disconnects_last_hour Disconnects inside the rolling ${toString cfg.windowSeconds}s window"
              echo "# TYPE usb_flap_disconnects_last_hour gauge"
              echo "usb_flap_disconnects_last_hour $last_hour"
              echo "# HELP usb_flap_rate_over_threshold 1 when the rolling-hour rate meets the alert threshold (the 2026-08-16 storm class)"
              echo "# TYPE usb_flap_rate_over_threshold gauge"
              echo "usb_flap_rate_over_threshold $rate_over"
              echo "# HELP usb_flap_last_disconnect_epoch Unix epoch of the most recent observed disconnect (0 = none in window)"
              echo "# TYPE usb_flap_last_disconnect_epoch gauge"
              echo "usb_flap_last_disconnect_epoch $last_epoch"
              echo "# HELP usb_flap_scrape_errors Nonzero when the journal read itself failed (fail-closed)"
              echo "# TYPE usb_flap_scrape_errors gauge"
              echo "usb_flap_scrape_errors $scrape_errors"
            } > "$TMP"
            mv "$TMP" "$OUT"
            echo "$total $NOW" > "$STATE_TMP"
            mv "$STATE_TMP" "$STATE"
          '';
        };

        systemd.timers.usb-flap-metrics = {
          description = "Collect USB flap-counter metrics every ${cfg.interval}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
          };
        };
      };
    };
}
