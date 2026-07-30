# System health textfile collector for node_exporter.
#
# Reports systemd service state (active/failed), restart counts, and
# start-limit-hit status for critical services. Also reports user-1000.slice
# memory usage with a threshold flag, and monitor365 DuckDB buffer pressure.
#
# Gatus 5.36.0 cannot do numeric comparison on Prometheus text metrics — it
# uses pat() which is presence-only. Therefore this collector pre-computes
# boolean threshold flags (0=ok, 1=alert) that Gatus checks via
# `[BODY] == pat(*metric 0*)`.
#
# See AGENTS.md rule 9: every service MUST be monitored.
_: {
  flake.nixosModules.system-health =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        mkStateDir
        ;

      cfg = config.services.system-health;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      # 40 GiB in bytes — user-1000.slice threshold (AGENTS.md: MemoryHigh=56G, MemoryMax=64G)
      userSliceThreshold = 40 * 1024 * 1024 * 1024;

      # 60 GiB in kB — GPUActive threshold (AGENTS.md: GPUActive can consume 51+ GiB)
      gpuActiveThresholdKb = 60 * 1024 * 1024;

      # monitor365 DuckDB buffer pressure: alert when DB exceeds 80% of server MemoryMax (2G default)
      monitor365BufferThreshold = 1600000000; # ~1.6 GB

      # CPU alert threshold: average CPU% over collection interval that triggers alert
      cpuAlertThreshold = 150;

      # /tmp tmpfs usage alert threshold (percentage). /tmp is capped at 48 GiB
      # (boot.nix static systemd mount). 80% ≈ 38 GiB — catches runaway builds
      # (go-build caches, dev temp files) before hitting the ceiling.
      tmpfsThreshold = 80;

      systemHealthMetrics = pkgs.writeShellApplication {
        name = "system-health-metrics";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
          pkgs.systemd
          pkgs.curl
          pkgs.jq
        ];
        text = ''
          OUT="${textfileDir}/system_health.prom"
          TMP="''${OUT}.tmp"
          CPU_STATE="${textfileDir}/.system_health_cpu_state"
          NOW_EPOCH=$(date +%s)

          emit_service() {
            local svc="''${1?}"
            local active_val=0
            local nrestarts=0
            local limit_hit=0

            if systemctl is-active --quiet "$svc" 2>/dev/null; then
              active_val=1
            fi

            nrestarts=$(systemctl show "$svc" -p NRestarts --value 2>/dev/null) || nrestarts=0
            nrestarts="''${nrestarts:-0}"

            local result
            result=$(systemctl show "$svc" -p Result --value 2>/dev/null) || result=""
            if [ "$result" = "start-limit-hit" ]; then
              limit_hit=1
            fi

            echo "system_service_active{service=\"''${svc}\"} ''${active_val}"
            echo "system_service_nrestarts{service=\"''${svc}\"} ''${nrestarts}"
            echo "system_service_start_limit_hit{service=\"''${svc}\"} ''${limit_hit}"
          }

          # CPU tracking: read previous CPUUsageNSec per service from state file,
          # compute delta / elapsed to get average CPU% since last collection.
          declare -A prev_cpu_nsec prev_cpu_ts
          if [ -f "$CPU_STATE" ]; then
            while IFS=' ' read -r s n t; do
              [ -n "$s" ] && prev_cpu_nsec["$s"]="$n" && prev_cpu_ts["$s"]="$t"
            done < "$CPU_STATE"
          fi

          # Write new state for next run
          : > "''${CPU_STATE}.tmp"
          for svc in ${lib.concatMapStringsSep " " (s: "'${s}'") cfg.monitoredServices}; do
            cpu_nsec=$(systemctl show "$svc" -p CPUUsageNSec --value 2>/dev/null) || cpu_nsec=0
            cpu_nsec="''${cpu_nsec:-0}"
            echo "$svc $cpu_nsec $NOW_EPOCH" >> "''${CPU_STATE}.tmp"
          done
          mv "''${CPU_STATE}.tmp" "$CPU_STATE"

          # === User-1000.slice memory (desktop-only) ===
          collect_user_slice=${lib.boolToString cfg.collectUserSlice}
          SLICE_OVER=0
          SLICE_MEM=0
          if [ "$collect_user_slice" = "true" ]; then
            SLICE_MEM=$(systemctl show user-1000.slice -p MemoryCurrent --value 2>/dev/null) || SLICE_MEM=0
            SLICE_MEM="''${SLICE_MEM:-0}"
            [ "$SLICE_MEM" -gt ${toString userSliceThreshold} ] 2>/dev/null && SLICE_OVER=1
          fi

          # === GPUActive threshold (Strix Halo only) ===
          collect_gpu_active=${lib.boolToString cfg.collectGpuActive}
          GPU_ACTIVE_KB=0
          GPU_OVER=0
          if [ "$collect_gpu_active" = "true" ]; then
            GPU_ACTIVE_KB=$(grep "^GPUActive:" /proc/meminfo 2>/dev/null | awk '{print $2}') || GPU_ACTIVE_KB=0
            GPU_ACTIVE_KB="''${GPU_ACTIVE_KB:-0}"
            [ "$GPU_ACTIVE_KB" -gt ${toString gpuActiveThresholdKb} ] 2>/dev/null && GPU_OVER=1
          fi

          # === monitor365 DuckDB buffer pressure ===
          collect_monitor365=${lib.boolToString cfg.collectMonitor365}
          DUCKDB_SIZE=0
          BUFFER_PRESSURE=0
          if [ "$collect_monitor365" = "true" ]; then
            DUCKDB_PATH="${cfg.monitor365.stateDir}/monitor365.duckdb"
            if [ -f "$DUCKDB_PATH" ]; then
              DUCKDB_SIZE=$(stat -c %s "$DUCKDB_PATH" 2>/dev/null) || DUCKDB_SIZE=0
              DUCKDB_SIZE="''${DUCKDB_SIZE:-0}"
              if [ "$DUCKDB_SIZE" -gt ${toString monitor365BufferThreshold} ] 2>/dev/null; then
                BUFFER_PRESSURE=1
              fi
            fi
          fi

          # === SigNoz alert rules count ===
          collect_signoz_rules=${lib.boolToString cfg.collectSignozRules}
          RULE_COUNT=0
          RULES_HEALTHY=0
          if [ "$collect_signoz_rules" = "true" ]; then
            RULE_COUNT=$(curl -sf --max-time 5 http://127.0.0.1:${toString cfg.signoz.port}/api/v1/rules 2>/dev/null | jq '.data.rules | length' 2>/dev/null) || RULE_COUNT=0
            RULE_COUNT="''${RULE_COUNT:-0}"
            if [ "$RULE_COUNT" -gt 15 ] 2>/dev/null; then
              RULES_HEALTHY=1
            fi
          fi

          # === /tmp tmpfs usage ===
          TMPFS_USAGE=0
          TMPFS_OVER=0
          if df /tmp >/dev/null 2>&1; then
            TMPFS_USAGE=$(df --output=pcent /tmp 2>/dev/null | tail -1 | tr -dc '0-9') || TMPFS_USAGE=0
            TMPFS_USAGE="''${TMPFS_USAGE:-0}"
            [ "$TMPFS_USAGE" -ge ${toString tmpfsThreshold} ] 2>/dev/null && TMPFS_OVER=1
          fi

          {
            echo "# HELP system_service_active 1 if systemd service is active, 0 otherwise"
            echo "# TYPE system_service_active gauge"

            echo "# HELP system_service_nrestarts Number of times the service has restarted since boot"
            echo "# TYPE system_service_nrestarts gauge"

            echo "# HELP system_service_start_limit_hit 1 if service hit systemd start rate limit, 0 otherwise"
            echo "# TYPE system_service_start_limit_hit gauge"

            ${lib.concatMapStrings (svc: ''
              emit_service "${svc}"
            '') cfg.monitoredServices}

            echo "# HELP system_service_cpu_percent Average CPU percentage since last collection interval"
            echo "# TYPE system_service_cpu_percent gauge"

            echo "# HELP system_service_cpu_over_threshold 1 if service CPU exceeds ${toString cpuAlertThreshold}% average, 0 otherwise"
            echo "# TYPE system_service_cpu_over_threshold gauge"

            ANY_CPU_OVER=0
            ${lib.concatMapStrings (svc: ''
              svc="${svc}"
              cur_nsec="''${prev_cpu_nsec[$svc]:-0}"
              # Re-read current value from state we just wrote
              cur_nsec=$(grep "^$svc " "$CPU_STATE" 2>/dev/null | awk '{print $2}') || cur_nsec=0
              cur_nsec="''${cur_nsec:-0}"
              prev_nsec="''${prev_cpu_nsec[$svc]:-0}"
              prev_ts="''${prev_cpu_ts[$svc]:-0}"
              cpu_pct="0"
              cpu_over="0"
              if [ "$prev_ts" -gt 0 ] 2>/dev/null; then
                elapsed=$((NOW_EPOCH - prev_ts))
                if [ "$elapsed" -gt 0 ] && [ "$cur_nsec" -ge "$prev_nsec" ] 2>/dev/null; then
                  cpu_delta=$((cur_nsec - prev_nsec))
                  cpu_pct=$(awk "BEGIN { printf \"%.1f\", ($cpu_delta / ($elapsed * 1000000000.0)) * 100 }")
                  if awk "BEGIN { exit !($cpu_pct > ${toString cpuAlertThreshold}) }"; then
                    cpu_over="1"
                    ANY_CPU_OVER=1
                  fi
                fi
              fi
              echo "system_service_cpu_percent{service=\"$svc\"} ''${cpu_pct}"
              echo "system_service_cpu_over_threshold{service=\"$svc\"} ''${cpu_over}"
            '') cfg.monitoredServices}

            echo "# HELP system_any_service_cpu_over_threshold 1 if ANY monitored service exceeds ${toString cpuAlertThreshold}% CPU average, 0 otherwise"
            echo "# TYPE system_any_service_cpu_over_threshold gauge"
            echo "system_any_service_cpu_over_threshold ''${ANY_CPU_OVER}"

            echo "# HELP system_user_slice_memory_bytes Memory usage of user-1000.slice in bytes"
            echo "# TYPE system_user_slice_memory_bytes gauge"
            echo "system_user_slice_memory_bytes ''${SLICE_MEM}"

            echo "# HELP system_user_slice_memory_over_threshold 1 if user-1000.slice exceeds 40G, 0 otherwise"
            echo "# TYPE system_user_slice_memory_over_threshold gauge"
            echo "system_user_slice_memory_over_threshold ''${SLICE_OVER}"

            echo "# HELP system_gpu_active_over_threshold 1 if GPUActive exceeds 60G, 0 otherwise"
            echo "# TYPE system_gpu_active_over_threshold gauge"
            echo "system_gpu_active_over_threshold ''${GPU_OVER}"

            echo "# HELP system_gpu_active_kb GPUActive memory from /proc/meminfo in kB"
            echo "# TYPE system_gpu_active_kb gauge"
            echo "system_gpu_active_kb ''${GPU_ACTIVE_KB}"

            echo "# HELP system_monitor365_duckdb_bytes Size of monitor365 DuckDB database in bytes"
            echo "# TYPE system_monitor365_duckdb_bytes gauge"
            echo "system_monitor365_duckdb_bytes ''${DUCKDB_SIZE}"

            echo "# HELP system_monitor365_buffer_pressure 1 if DuckDB exceeds buffer threshold, 0 otherwise"
            echo "# TYPE system_monitor365_buffer_pressure gauge"
            echo "system_monitor365_buffer_pressure ''${BUFFER_PRESSURE}"

            echo "# HELP system_signoz_alert_rules_total Number of SigNoz alert rules provisioned"
            echo "# TYPE system_signoz_alert_rules_total gauge"
            echo "system_signoz_alert_rules_total ''${RULE_COUNT}"

            echo "# HELP system_signoz_alert_rules_healthy 1 if SigNoz has >15 alert rules, 0 otherwise"
            echo "# TYPE system_signoz_alert_rules_healthy gauge"
            echo "system_signoz_alert_rules_healthy ''${RULES_HEALTHY}"
          } > "$TMP"
          mv "$TMP" "$OUT"
        '';
      };
    in
    {
      options.services.system-health = {
        enable = lib.mkEnableOption "System health textfile collector (service state, memory thresholds, buffer pressure)";

        interval = lib.mkOption {
          type = lib.types.str;
          default = "2min";
          description = "Interval at which the collector runs";
        };

        monitoredServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "caddy"
            "dnsblockd"
            "discordsync"
            "forgejo"
            "gatus"
            "homepage-dashboard"
            "monitor365"
            "monitor365-server"
            "pocket-id"
            "projects-management-automation"
            "signoz"
          ];
          description = "Systemd services to monitor for state, restart count, and start-limit-hit";
        };

        collectUserSlice = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect user-1000.slice memory metrics (disable on non-desktop hosts)";
        };

        collectGpuActive = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect GPUActive metrics from /proc/meminfo (Strix Halo / amdgpu only)";
        };

        collectMonitor365 = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect monitor365 DuckDB buffer pressure metrics";
        };

        collectSignozRules = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect SigNoz alert rules count (disable on hosts without SigNoz)";
        };

        signoz.port = lib.mkOption {
          type = lib.types.int;
          default = 8080;
          description = "SigNoz query service port for alert rules API";
        };

        monitor365.stateDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/monitor365-server";
          description = "Directory containing monitor365.duckdb (used for buffer-pressure metrics)";
        };
      };

      config = lib.mkIf cfg.enable {
        # Auto-disable collectors that target resources not present on this host.
        # These use mkDefault so user configuration can override.
        services.system-health =
          (lib.optionalAttrs (options ? services.monitor365-server) {
            collectMonitor365 = lib.mkDefault (config.services.monitor365-server.enable or false);
            monitor365.stateDir = lib.mkDefault (
              config.services.monitor365-server.stateDir or "/var/lib/monitor365-server"
            );
          })
          // (lib.optionalAttrs (options ? services.signoz) {
            collectSignozRules = lib.mkDefault (config.services.signoz.enable or false);
            signoz.port = lib.mkDefault (config.services.signoz.settings.queryService.port or 8080);
          });

        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.system-health-metrics = {
            description = "System health metrics collector for node_exporter textfile";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "128M";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                ExecStart = lib.getExe systemHealthMetrics;
                ReadWritePaths = [ textfileDir ];
              }
            ];
          };

          timers.system-health-metrics = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "30s";
              OnUnitActiveSec = cfg.interval;
            };
          };
        };
      };
    };
}
