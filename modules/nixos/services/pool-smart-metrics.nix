# Pool drive SMART metrics — textfile collector for the HDD pool members.
#
# smartd alerts on health/realloc/temp thresholds, but its channels are
# sendmail-to-root (dead until the Resend domain is verified) + local
# wall/notify — a dying pool drive currently alerts nowhere remote. This
# collector closes that gap with Prometheus metrics (SigNoz dashboards,
# Gatus Discord alerts) and adds the vibration/shock telemetry smartd does
# not cover: G-Sense (191) and Disk_Shift (220) deltas via a state file.
#
# Metric doctrine (matches scripts/hdd-vibration-check.sh):
#   - All SMART raw counters are LIFETIME totals since manufacture — only
#     same-drive DELTAS between runs are meaningful (the *_increased flags
#     carry them; the baseline lives in AGENTS.md, 2026-09-12).
#   - Disk_Shift raw is vendor-packed 48-bit on the MG08s (millions-scale
#     while normalized sits at 100) — exposed for delta forensics only.
#   - Zero drives present (whole-DAS outage) keeps all_healthy=1: that
#     failure class is owned by the "Pool Mounted" / DAS-link Gatus checks;
#     duplicating it here would be alert noise.
#
# Runs as root (SAT passthrough needs it), buildcache-metrics pattern:
# mktemp in the sticky textfile dir + CAP_FOWNER (the mail-relay
# 2026-09-02..06 foreign-owned-prom class), CAP_SYS_ADMIN/CAP_SYS_RAWIO
# for smartctl.
{
  flake.nixosModules.pool-smart-metrics =
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

      cfg = config.services.pool-smart-metrics;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
    in
    {
      options.services.pool-smart-metrics = {
        enable = lib.mkEnableOption "SMART metrics collector for the HDD pool members (textfile → node_exporter)";

        drives = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A005FWTG"
            "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A0ZUFWTG"
          ];
          description = ''
            Whole-disk by-id devices to query via smartctl -d sat. by-id
            survives the sd-letter reshuffles on every DAS replug — never
            /dev/sdX.
          '';
        };

        tempThresholdCelsius = lib.mkOption {
          type = lib.types.int;
          default = 50;
          description = "Temperature at which pool_smart_temp_over flips to 1 (MG08 rated to 60C).";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "5min";
          description = "Collection interval (OnUnitActiveSec).";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.pool-smart-metrics = {
          description = "Pool drive SMART metrics collector (textfile)";
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.smartmontools
            pkgs.gawk
            pkgs.gnugrep
            pkgs.coreutils
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              StateDirectory = "pool-smart-metrics";
            }
            (harden {
              ReadWritePaths = [ textfileDir ];
              # CAP_SYS_ADMIN/SYS_RAWIO for SMART via SAT; CAP_FOWNER for the
              # sticky-dir rename over a foreign-owned prom (mail-relay class).
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_SYS_RAWIO CAP_FOWNER";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            OUT="${textfileDir}/pool-smart.prom"
            mkdir -p "${textfileDir}"
            TMP="$(mktemp "${textfileDir}/pool-smart.prom.XXXXXX")"
            chmod 644 "$TMP"
            STATE_DIR="''${STATE_DIRECTORY:-/var/lib/pool-smart-metrics}"
            STATE="$STATE_DIR/state"
            STATE_TMP="$(mktemp)"
            METRICS="$(mktemp)"
            trap 'rm -f "$TMP" "$STATE_TMP" "$METRICS"' EXIT
            TEMP_THRESHOLD=${toString cfg.tempThresholdCelsius}

            scrape_errors=0
            all_healthy=1
            drives_present=0
            media_flag=0
            media_increased=0
            temp_over=0
            gsense_increased=0

            old_val() {
              [ -f "$STATE" ] || return 0
              awk -v s="$1" -v a="$2" '$1 == s && $2 == a { print $3; exit }' "$STATE" 2>/dev/null || true
            }

            grew() {
              local old
              old="$(old_val "$1" "$2")"
              if [ -n "$old" ] && [ -n "''${3:-}" ] && [ "$3" -gt "$old" ] 2>/dev/null; then
                echo 1
              else
                echo 0
              fi
            }

            for dev in ${lib.escapeShellArgs cfg.drives}; do
              base="$(basename "$dev")"
              serial="''${base##*_}"
              if [ ! -e "$dev" ]; then
                echo "pool_smart_present{serial=\"$serial\"} 0" >> "$METRICS"
                continue
              fi
              drives_present=$((drives_present + 1))
              echo "pool_smart_present{serial=\"$serial\"} 1" >> "$METRICS"

              health_ok=0
              if smartctl -d sat -H "$dev" 2>/dev/null | grep -q "PASSED"; then
                health_ok=1
              else
                all_healthy=0
              fi
              echo "pool_smart_health_ok{serial=\"$serial\"} $health_ok" >> "$METRICS"

              attrs="$(smartctl -d sat -A "$dev" 2>/dev/null || true)"
              # Fail-closed on a SAT bridge that swallows the attribute table.
              if ! printf '%s\n' "$attrs" | grep -qE '^ 5 |^194 '; then
                scrape_errors=1
                all_healthy=0
                continue
              fi

              raw_of() {
                printf '%s\n' "$attrs" | awk -v id="$1" '$1 == id { print $NF; exit }'
              }

              realloc="$(raw_of 5)"
              revents="$(raw_of 196)"
              pending="$(raw_of 197)"
              uncorr="$(raw_of 198)"
              crc="$(raw_of 199)"
              gsense="$(raw_of 191)"
              shiftv="$(raw_of 220)"
              poh="$(raw_of 9)"
              tempraw="$(raw_of 194)"
              # Raw is "current/max" on these drives — the current value is the
              # first number ("21/39" -> 21; a plain "33" stays 33).
              temp="''${tempraw%%/*}"
              case "$temp" in
                '' | *[!0-9]*) temp="" ;;
              esac

              [ -n "$temp" ] && echo "pool_smart_temperature_celsius{serial=\"$serial\"} $temp" >> "$METRICS"
              echo "pool_smart_power_on_hours{serial=\"$serial\"} ''${poh:-0}" >> "$METRICS"
              for pair in \
                "reallocated:$realloc" \
                "reallocated_events:$revents" \
                "pending:$pending" \
                "uncorrectable:$uncorr" \
                "crc:$crc" \
                "gsense:$gsense" \
                "disk_shift:$shiftv"
              do
                key="''${pair%%:*}"
                val="''${pair#*:}"
                if [ -n "$val" ]; then
                  echo "pool_smart_attribute_raw{serial=\"$serial\",attr=\"$key\"} $val" >> "$METRICS"
                  echo "$serial $key $val" >> "$STATE_TMP"
                fi
              done

              for v in "$realloc" "$revents" "$pending" "$uncorr"; do
                if [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null; then
                  media_flag=1
                fi
              done
              [ "$(grew "$serial" gsense "$gsense")" = 1 ] && gsense_increased=1 || true
              for pair in "reallocated:$realloc" "reallocated_events:$revents" "pending:$pending" "uncorrectable:$uncorr"; do
                key="''${pair%%:*}"
                val="''${pair#*:}"
                if [ "$(grew "$serial" "$key" "$val")" = 1 ]; then
                  media_increased=1
                fi
              done
              [ -n "$temp" ] && [ "$temp" -ge "$TEMP_THRESHOLD" ] 2>/dev/null && temp_over=1 || true
            done

            {
              echo "# HELP pool_smart_present Per-drive presence via by-id enumeration; a whole-DAS outage shows 0 everywhere and is owned by the Pool Mounted check"
              echo "# TYPE pool_smart_present gauge"
              echo "# HELP pool_smart_health_ok Per-drive SMART overall-health PASSED flag"
              echo "# TYPE pool_smart_health_ok gauge"
              echo "# HELP pool_smart_temperature_celsius Current drive temperature (Celsius)"
              echo "# TYPE pool_smart_temperature_celsius gauge"
              echo "# HELP pool_smart_power_on_hours Power-on hours (context: raw counters are lifetime totals)"
              echo "# TYPE pool_smart_power_on_hours gauge"
              echo "# HELP pool_smart_attribute_raw Raw SMART value per attribute; lifetime counters, only same-drive deltas are meaningful (disk_shift raw is vendor-packed)"
              echo "# TYPE pool_smart_attribute_raw gauge"
              cat "$METRICS"
              echo "# HELP pool_smart_drives_present How many configured pool drives are enumerated"
              echo "# TYPE pool_smart_drives_present gauge"
              echo "pool_smart_drives_present $drives_present"
              echo "# HELP pool_smart_all_healthy Stays at its value of one when every present drive reports PASSED; zero drives present leaves it untouched (whole-DAS outage owned by Pool Mounted)"
              echo "# TYPE pool_smart_all_healthy gauge"
              echo "pool_smart_all_healthy $all_healthy"
              echo "# HELP pool_smart_scrape_errors Nonzero when a present drive fails its SMART read or the SAT bridge hides the attribute table (fail-closed)"
              echo "# TYPE pool_smart_scrape_errors gauge"
              echo "pool_smart_scrape_errors $scrape_errors"
              echo "# HELP pool_smart_media_flag Set when any present drive has nonzero reallocated, reallocated_events, pending, or uncorrectable sectors"
              echo "# TYPE pool_smart_media_flag gauge"
              echo "pool_smart_media_flag $media_flag"
              echo "# HELP pool_smart_media_increased Set when any media counter grew since the previous run (the leading death indicator)"
              echo "# TYPE pool_smart_media_increased gauge"
              echo "pool_smart_media_increased $media_increased"
              echo "# HELP pool_smart_temp_over Set when any drive temperature meets the configured threshold"
              echo "# TYPE pool_smart_temp_over gauge"
              echo "pool_smart_temp_over $temp_over"
              echo "# HELP pool_smart_gsense_increased Set when the G-Sense shock counter grew since the previous run (physical shock event forensics)"
              echo "# TYPE pool_smart_gsense_increased gauge"
              echo "pool_smart_gsense_increased $gsense_increased"
            } > "$TMP"
            mv "$TMP" "$OUT"
            mv "$STATE_TMP" "$STATE"
          '';
        };

        systemd.timers.pool-smart-metrics = {
          description = "Collect pool drive SMART metrics every 5 minutes";
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
