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

                    extract() {
                      echo "$SMART" | jq -r --arg key "$1" '.[$key] // 0'
                    }

                    TEMP_KELVIN=$(echo "$SMART" | jq -r '.temperature // 0')
                    TEMP_CELSIUS=$((TEMP_KELVIN - 273))

                    {
                      echo "# HELP node_nvme_temperature_celsius NVMe SSD temperature in Celsius"
                      echo "# TYPE node_nvme_temperature_celsius gauge"
                      echo "node_nvme_temperature_celsius{device=\"''${DEV_NAME}\"} ''${TEMP_CELSIUS}"

                      echo "# HELP node_nvme_critical_warning NVMe critical warning flags (0 = none)"
                      echo "# TYPE node_nvme_critical_warning gauge"
                      echo "node_nvme_critical_warning{device=\"''${DEV_NAME}\"} $(extract critical_warning)"

                      echo "# HELP node_nvme_available_spare_percent NVMe available spare as percentage"
                      echo "# TYPE node_nvme_available_spare_percent gauge"
                      echo "node_nvme_available_spare_percent{device=\"''${DEV_NAME}\"} $(extract available_spare)"

                      echo "# HELP node_nvme_percentage_used NVMe endurance used percentage (0-100, 100 = worn out)"
                      echo "# TYPE node_nvme_percentage_used gauge"
                      echo "node_nvme_percentage_used{device=\"''${DEV_NAME}\"} $(extract percentage_used)"

                      echo "# HELP node_nvme_data_units_read_total NVMe data units read (1 unit = 512 bytes)"
                      echo "# TYPE node_nvme_data_units_read_total counter"
                      echo "node_nvme_data_units_read_total{device=\"''${DEV_NAME}\"} $(extract data_units_read)"

                      echo "# HELP node_nvme_data_units_written_total NVMe data units written (1 unit = 512 bytes)"
                      echo "# TYPE node_nvme_data_units_written_total counter"
                      echo "node_nvme_data_units_written_total{device=\"''${DEV_NAME}\"} $(extract data_units_written)"

                      echo "# HELP node_nvme_power_cycles_total NVMe power cycle count"
                      echo "# TYPE node_nvme_power_cycles_total counter"
                      echo "node_nvme_power_cycles_total{device=\"''${DEV_NAME}\"} $(extract power_cycles)"

                      echo "# HELP node_nvme_power_on_hours_total NVMe power-on hours"
                      echo "# TYPE node_nvme_power_on_hours_total counter"
                      echo "node_nvme_power_on_hours_total{device=\"''${DEV_NAME}\"} $(extract power_on_hours)"

                      echo "# HELP node_nvme_unsafe_shutdowns_total NVMe unsafe shutdown count"
                      echo "# TYPE node_nvme_unsafe_shutdowns_total counter"
                      echo "node_nvme_unsafe_shutdowns_total{device=\"''${DEV_NAME}\"} $(extract unsafe_shutdowns)"

                      echo "# HELP node_nvme_media_errors_total NVMe media and data integrity errors"
                      echo "# TYPE node_nvme_media_errors_total counter"
                      echo "node_nvme_media_errors_total{device=\"''${DEV_NAME}\"} $(extract media_errors)"

                      echo "# HELP node_nvme_error_log_entries_total NVMe error log entry count"
                      echo "# TYPE node_nvme_error_log_entries_total counter"
                      echo "node_nvme_error_log_entries_total{device=\"''${DEV_NAME}\"} $(extract num_err_log_entries)"
                    } > "$TMP"

                    mv "$TMP" "$OUT"
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

                    # Derived alert: 1 when >50% of tasks stalled on memory (10s avg),
                    # or >10% fully stalled — early warning before OOM cascade.
                    alert=0
                    awk "BEGIN{exit !($some_avg10 > 0.50)}" && alert=1
                    awk "BEGIN{exit !($full_avg10 > 0.10)}" && alert=1

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
                      io_some_avg300=$(awk '/^some/ {split($5, a, "="); print a[2]}' "$IO_PSI")
                      io_full_avg300=$(awk '/^full/ {split($5, a, "="); print a[2]}' "$IO_PSI")
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
