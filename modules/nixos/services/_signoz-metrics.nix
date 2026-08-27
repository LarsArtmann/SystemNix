# SigNoz node_exporter + textfile collectors (AMD GPU, NVMe SMART, PSI)
# Extracted from signoz.nix to keep the module focused on service configuration.
{
  cfg,
  pkgs,
  lib,
  harden,
  onFailure,
  ports,
  mkStateDir,
}:
lib.mkIf cfg.components.nodeExporter {
  services.prometheus.exporters.node = {
    enable = true;
    port = ports.signoz-node-exporter;
    listenAddress = "127.0.0.1";
    enabledCollectors = [
      "cpu"
      "diskstats"
      "filesystem"
      "loadavg"
      "meminfo"
      "netdev"
      "stat"
      "systemd"
      "time"
      "vmstat"
      "hwmon"
      "pressure"
    ];
    extraFlags = [
      "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/k3s/.+).+$"
      "--collector.netdev.device-exclude=^(veth.*|br-.*|docker.*).+$"
      "--collector.textfile.directory=/var/lib/prometheus-node-exporter/textfile_collectors"
    ];
  };

  systemd = lib.mkMerge [
    {
      tmpfiles.rules = [
        (mkStateDir "/var/lib/prometheus-node-exporter/textfile_collectors" "1777" "nobody" "nogroup")
      ];
    }
    {
      services.amdgpu-metrics = {
        description = "AMD GPU metrics collector for node_exporter textfile";
        inherit onFailure;
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            let
              amdgpuMetrics = pkgs.writeShellApplication {
                name = "amdgpu-metrics";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.gawk
                ];
                text = ''
                  OUT="/var/lib/prometheus-node-exporter/textfile_collectors/amdgpu.prom"
                  TMP="''${OUT}.tmp"

                  {
                    for card in /sys/class/drm/card*/device/gpu_busy_percent; do
                      if [ -f "$card" ]; then
                        pct=$(cat "$card" | tr -d '%\n')
                        card_name="''${card#/sys/class/drm/}"; card_name="''${card_name%%/*}"
                        echo "node_amdgpu_gpu_busy_percent{card=\"''${card_name}\"} ''${pct}"
                      fi
                    done

                    for mem in /sys/class/drm/card*/device/mem_busy_percent; do
                      if [ -f "$mem" ]; then
                        pct=$(cat "$mem" | tr -d '%\n')
                        card_name="''${mem#/sys/class/drm/}"; card_name="''${card_name%%/*}"
                        echo "node_amdgpu_mem_busy_percent{card=\"''${card_name}\"} ''${pct}"
                      fi
                    done

                    for temp in /sys/class/drm/card*/device/gpu_temp; do
                      if [ -f "$temp" ]; then
                        millideg=$(cat "$temp" | tr -d '\n')
                        card_name="''${temp#/sys/class/drm/}"; card_name="''${card_name%%/*}"
                        echo "node_amdgpu_gpu_temp_celsius{card=\"''${card_name}\"} $(awk "BEGIN{printf \"%.1f\", ''${millideg}/1000}")"
                      fi
                    done

                    for vram in /sys/class/drm/card*/device/mem_info_vram_total /sys/class/drm/card*/device/mem_info_vram_used; do
                      if [ -f "$vram" ]; then
                        bytes=$(cat "$vram" | tr -d '\n')
                        card_name="''${vram#/sys/class/drm/}"; card_name="''${card_name%%/*}"
                        metric=$(echo "$vram" | awk -F/ '{print $NF}')
                        echo "node_amdgpu_''${metric}_bytes{card=\"''${card_name}\"} ''${bytes}"
                      fi
                    done
                  } > "$TMP"

                  mv "$TMP" "$OUT"
                '';
              };
            in
            lib.getExe amdgpuMetrics;
        };
      };

      timers.amdgpu-metrics = {
        description = "Collect AMD GPU metrics every 30s";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "10s";
          OnUnitActiveSec = "30s";
        };
      };
    }
    {
      services.nvme-metrics = {
        description = "NVMe SMART metrics collector for node_exporter textfile";
        inherit onFailure;
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            ExecStart =
              let
                nvmeMetrics = pkgs.writeShellApplication {
                  name = "nvme-metrics";
                  runtimeInputs = [
                    pkgs.nvme-cli
                    pkgs.coreutils
                    pkgs.jq
                  ];
                  text = ''
                    OUT="/var/lib/prometheus-node-exporter/textfile_collectors/nvme.prom"
                    TMP="''${OUT}.tmp"
                    DEVICE="/dev/nvme0n1"

                    if ! command -v nvme &>/dev/null; then
                      echo "nvme-cli not found, skipping" >&2
                      exit 0
                    fi

                    SMART=$(nvme smart-log -o json "$DEVICE" 2>/dev/null) || {
                      echo "Failed to read SMART log from $DEVICE" >&2
                      exit 1
                    }

                    DEV_NAME=$(basename "$DEVICE")
                    MISSING_KEYS=0

                    # extract <key>: print the numeric value, or return 1 when
                    # the key is missing/non-numeric. NEVER default to 0 — a
                    # phantom zero fed the "NVMe Spare Blocks Low" false alert
                    # for weeks (nvme-cli 2.16 JSON keys are avail_spare /
                    # percent_used; the old `// 0` fallback masked the rename).
                    extract() {
                      echo "$SMART" | jq -er --arg key "$1" '.[$key] | numbers' 2>/dev/null || {
                        echo "nvme-metrics: smart-log key '$1' not found — available keys: $(echo "$SMART" | jq -r 'keys | join(",")')" >&2
                        MISSING_KEYS=1
                        return 1
                      }
                    }

                    TEMP_KELVIN=$(extract temperature) || true
                    CRITICAL_WARNING=$(extract critical_warning) || true
                    AVAIL_SPARE=$(extract avail_spare) || true
                    SPARE_THRESH=$(extract spare_thresh) || true
                    PCT_USED=$(extract percent_used) || true
                    DATA_UNITS_READ=$(extract data_units_read) || true
                    DATA_UNITS_WRITTEN=$(extract data_units_written) || true
                    POWER_CYCLES=$(extract power_cycles) || true
                    POWER_ON_HOURS=$(extract power_on_hours) || true
                    UNSAFE_SHUTDOWNS=$(extract unsafe_shutdowns) || true
                    MEDIA_ERRORS=$(extract media_errors) || true
                    ERR_LOG_ENTRIES=$(extract num_err_log_entries) || true

                    # emit <metric> <type> <value> <help> — skips metrics whose
                    # key was missing (absent sample > lying zero).
                    emit() {
                      local metric="$1" mtype="$2" value="$3" help="$4"
                      [ -n "$value" ] || return 0
                      echo "# HELP $metric $help"
                      echo "# TYPE $metric $mtype"
                      echo "$metric{device=\"''${DEV_NAME}\"} $value"
                    }

                    TEMP_CELSIUS=""
                    if [ -n "$TEMP_KELVIN" ]; then
                      TEMP_CELSIUS=$((TEMP_KELVIN - 273))
                    fi

                    # Endurance warning: 1 when percentage_used >= 50%
                    ENDURANCE_WARNING=0
                    if [ -n "$PCT_USED" ] && [ "''${PCT_USED}" -ge 50 ] 2>/dev/null; then
                      ENDURANCE_WARNING=1
                    fi

                    {
                      emit node_nvme_temperature_celsius gauge "$TEMP_CELSIUS" "NVMe SSD temperature in Celsius"

                      emit node_nvme_critical_warning gauge "$CRITICAL_WARNING" "NVMe critical warning flags (0 = none)"

                      emit node_nvme_available_spare_percent gauge "$AVAIL_SPARE" "NVMe available spare as percentage (smart-log key: avail_spare)"

                      emit node_nvme_spare_threshold_percent gauge "$SPARE_THRESH" "NVMe available spare threshold as percentage (smart-log key: spare_thresh)"

                      emit node_nvme_percentage_used gauge "$PCT_USED" "NVMe endurance used percentage (0-100, 100 = worn out; smart-log key: percent_used)"

                      echo "# HELP node_nvme_endurance_warning NVMe endurance boolean: 1 when percentage_used >= 50%"
                      echo "# TYPE node_nvme_endurance_warning gauge"
                      echo "node_nvme_endurance_warning{device=\"''${DEV_NAME}\"} ''${ENDURANCE_WARNING}"

                      emit node_nvme_data_units_read_total counter "$DATA_UNITS_READ" "NVMe data units read (1 unit = 512 bytes)"

                      emit node_nvme_data_units_written_total counter "$DATA_UNITS_WRITTEN" "NVMe data units written (1 unit = 512 bytes)"

                      emit node_nvme_power_cycles_total counter "$POWER_CYCLES" "NVMe power cycle count"

                      emit node_nvme_power_on_hours_total counter "$POWER_ON_HOURS" "NVMe power-on hours"

                      emit node_nvme_unsafe_shutdowns_total counter "$UNSAFE_SHUTDOWNS" "NVMe unsafe shutdown count"

                      emit node_nvme_media_errors_total counter "$MEDIA_ERRORS" "NVMe media and data integrity errors"

                      emit node_nvme_error_log_entries_total counter "$ERR_LOG_ENTRIES" "NVMe error log entry count"

                      echo "# HELP node_nvme_collector_keys_missing 1 if smart-log JSON keys were missing (renamed upstream?) — check journalctl -u nvme-metrics"
                      echo "# TYPE node_nvme_collector_keys_missing gauge"
                      echo "node_nvme_collector_keys_missing{device=\"''${DEV_NAME}\"} ''${MISSING_KEYS}"
                    } > "$TMP"

                    mv "$TMP" "$OUT"

                    # Exit 0 on missing keys: the partial .prom keeps the other
                    # metrics flowing and Gatus alerts on the keys_missing flag
                    # (failing the unit every minute would spam instead).
                    if [ "$MISSING_KEYS" -ne 0 ]; then
                      echo "nvme-metrics: wrote partial .prom — missing keys flagged via node_nvme_collector_keys_missing" >&2
                    fi
                  '';
                };
              in
              "${nvmeMetrics}/bin/nvme-metrics";
          }
          (harden {
            CapabilityBoundingSet = "CAP_SYS_ADMIN";
          })
        ];
      };

      timers.nvme-metrics = {
        description = "Collect NVMe SMART metrics every 60s";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "60s";
        };
      };
    }
    {
      services.psi-metrics = {
        description = "Memory + I/O pressure (PSI) metrics for node_exporter textfile";
        inherit onFailure;
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            ExecStart =
              let
                psiMetrics = pkgs.writeShellApplication {
                  name = "psi-metrics";
                  runtimeInputs = [ pkgs.gawk ];
                  text = ''
                    OUT="/var/lib/prometheus-node-exporter/textfile_collectors/psi.prom"
                    TMP="''${OUT}.tmp"

                    PSI="/proc/pressure/memory"
                    [ -f "$PSI" ] || exit 0

                    some_avg10=$(awk '/^some/ {split($2, a, "="); print a[2]}' "$PSI")
                    full_avg10=$(awk '/^full/ {split($2, a, "="); print a[2]}' "$PSI")
                    some_avg60=$(awk '/^some/ {split($3, a, "="); print a[2]}' "$PSI")
                    some_avg60="''${some_avg60:-0}"

                    # Derived alert: 1 when >50% of tasks stalled on memory (10s avg),
                    # or >10% fully stalled — early warning before OOM cascade.
                    alert=0
                    awk "BEGIN{exit !($some_avg10 > 0.50)}" && alert=1
                    awk "BEGIN{exit !($full_avg10 > 0.10)}" && alert=1

                    # Warning tier (2026-08-22): the CRITICAL alert fired 17s
                    # before the 05:49 freeze and 43min before the 00:27 one —
                    # nobody was watching Discord. The WARNING tier catches the
                    # storm FORMING (sustained 1-min stall >= 20%) while there is
                    # still time to act. Alert-only by user decision: NO automated
                    # action, no overlay — Discord + the SEV1 escalation bridge's
                    # notification path handle the human loop; the memory
                    # emergency guard remains the only automated actor.
                    warning=0
                    awk "BEGIN{exit !($some_avg60 >= 0.20)}" && warning=1

                    # ── I/O pressure ────────────────────────────────────────────
                    # avg300 = proportion of last 300s (5 min) where tasks stalled
                    # on I/O. Equivalent to rate(node_pressure_io_stalled_seconds_total[5m]).
                    # Alert at >0.10 (10% of wall-clock time stalled) — indicates
                    # SLC cache exhaustion or sustained I/O starvation.
                    io_some_avg300=0
                    io_full_avg300=0
                    io_alert=0
                    IO_PSI="/proc/pressure/io"
                    if [ -f "$IO_PSI" ]; then
                      io_some_avg300=$(awk '/^some/ {split($4, a, "="); print a[2]}' "$IO_PSI")
                      io_full_avg300=$(awk '/^full/ {split($4, a, "="); print a[2]}' "$IO_PSI")
                      io_some_avg300="''${io_some_avg300:-0}"
                      io_full_avg300="''${io_full_avg300:-0}"
                      awk "BEGIN{exit !($io_some_avg300 > 0.10)}" && io_alert=1
                    fi

                    {
                      echo "# HELP node_psi_memory_some_avg10 Proportion of last 10s where some tasks stalled on memory"
                      echo "# TYPE node_psi_memory_some_avg10 gauge"
                      echo "node_psi_memory_some_avg10 ''${some_avg10}"
                      echo "# HELP node_psi_memory_full_avg10 Proportion of last 10s where all tasks stalled on memory"
                      echo "# TYPE node_psi_memory_full_avg10 gauge"
                      echo "node_psi_memory_full_avg10 ''${full_avg10}"
                      echo "# HELP node_psi_memory_some_avg60 Proportion of last 60s where some tasks stalled on memory (the storm-forming window)"
                      echo "# TYPE node_psi_memory_some_avg60 gauge"
                      echo "node_psi_memory_some_avg60 ''${some_avg60}"
                      echo "# HELP node_psi_memory_warning Derived boolean: 1 when sustained memory stall (some avg60) >= 20% — storm forming, act now; alert-only, no automated action (user decision 2026-08-22)"
                      echo "# TYPE node_psi_memory_warning gauge"
                      echo "node_psi_memory_warning ''${warning}"
                      echo "# HELP node_psi_memory_alert Derived boolean: 1 when pressure exceeds early-warning threshold"
                      echo "# TYPE node_psi_memory_alert gauge"
                      echo "node_psi_memory_alert ''${alert}"
                      echo "# HELP node_psi_io_some_avg300 Proportion of last 5min where some tasks stalled on I/O"
                      echo "# TYPE node_psi_io_some_avg300 gauge"
                      echo "node_psi_io_some_avg300 ''${io_some_avg300}"
                      echo "# HELP node_psi_io_full_avg300 Proportion of last 5min where all tasks stalled on I/O"
                      echo "# TYPE node_psi_io_full_avg300 gauge"
                      echo "node_psi_io_full_avg300 ''${io_full_avg300}"
                      echo "# HELP node_psi_io_alert Derived boolean: 1 when I/O stall rate exceeds 10% (5min avg)"
                      echo "# TYPE node_psi_io_alert gauge"
                      echo "node_psi_io_alert ''${io_alert}"
                    } > "$TMP"

                    mv "$TMP" "$OUT"
                  '';
                };
              in
              "${psiMetrics}/bin/psi-metrics";
          }
          (harden {
            ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
          })
        ];
      };

      timers.psi-metrics = {
        description = "Collect memory and I/O pressure metrics every 15s";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5s";
          OnUnitActiveSec = "15s";
        };
      };
    }
  ];
}
