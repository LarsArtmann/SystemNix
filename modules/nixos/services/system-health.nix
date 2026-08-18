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

      # Per-service memory alert threshold: 90% of the unit's OWN MemoryMax,
      # read at collection time via systemctl. Units without a MemoryMax
      # (infinity) fall back to this flat threshold. Thresholds must derive
      # from the ceiling they guard — a flat 5G against PMA's
      # MemoryHigh=12G/MemoryMax=16G (retuned 2026-08-14) made "PMA Memory
      # Pressure" flap on every legitimate repo-discovery scan.
      serviceMemoryThresholdFallback = 5 * 1024 * 1024 * 1024; # 5 GiB

      # /tmp tmpfs usage alert threshold (percentage). /tmp is capped at 48 GiB
      # (boot.nix static systemd mount). 80% ≈ 38 GiB — catches runaway builds
      # (go-build caches, dev temp files) before hitting the ceiling.
      tmpfsThreshold = 80;

      # memory.events max threshold: when a service's cgroup hits MemoryMax this
      # many times, flag it. The PMA page-cache death-loop hit max 27,312 times
      # in minutes. A healthy service should be 0. >100 indicates a thrash loop.
      memoryEventsMaxThreshold = 100;

      # fstrim duration alert threshold (seconds). Daily fstrim on QLC NAND
      # should take 10-15 min after the initial 446 GiB backlog is cleared.
      # >30 min indicates either a huge backlog (SLC cache churn) or the trim
      # is competing with heavy host I/O.
      fstrimDurationThreshold = 1800;

      # Disk usage alert threshold (percentage). Root filesystem fill (90-93%)
      # has been a chronic issue across multiple reports. 85% gives early
      # warning before the critical zone.
      diskUsageThreshold = 85;

      # zram swap fill alert threshold (percentage of the zram device capacity
      # consumed). With zram-only swap (no disk fallback), a full zram forces
      # the kernel into page-cache reclaim — the BTRFS I/O storm precursor.
      # Alert at 90% to leave headroom before the 100% cliff.
      zramFillThreshold = 90;

      # Crash-loop detection: restarts per collection interval (2min) that
      # indicate a crash loop. The browser-history 520-restart loop had ~26
      # restarts per 2min. 3 restarts in 2 minutes is definitely a crash loop.
      crashLoopRestartThreshold = 3;

      # Docker container restart alert: restarts per collection interval (2min).
      # The Twenty 235-restart loop had ~12 restarts per 2min. 3 catches rapid loops.
      dockerRestartAlertThreshold = 3;

      systemHealthMetrics = pkgs.writeShellApplication {
        name = "system-health-metrics";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
          pkgs.systemd
          pkgs.curl
          pkgs.jq
          pkgs.procps
          pkgs.docker
          pkgs.sqlite
        ];
        text = ''
          OUT="${textfileDir}/system_health.prom"
          TMP="''${OUT}.tmp"
          CPU_STATE="${textfileDir}/.system_health_cpu_state"
          RESTART_STATE="${textfileDir}/.system_health_restart_state"
          OOMD_STATE="${textfileDir}/.system_health_oomd_state"
          DOCKER_STATE="${textfileDir}/.system_health_docker_state"
          NOW_EPOCH=$(date +%s)

          # systemctl show --value returns literal "[not set]" on stdout
          # (exit 0) for stopped/inactive services. This sanitizes it to 0
          # so node_exporter doesn't reject the entire textfile.
          systemctl_value() {
            local val
            val=$(systemctl show "$@" --value 2>/dev/null) || val=0
            if [ -z "$val" ] || [ "$val" = "[not set]" ]; then
              val=0
            fi
            printf '%s' "$val"
          }

          emit_service() {
            local svc="''${1?}"
            local active_val=0
            local failed_val=0
            local nrestarts=0
            local limit_hit=0

            if systemctl is-active --quiet "$svc" 2>/dev/null; then
              active_val=1
            fi

            # Failed state (crashed / dead-with-error) — distinct from
            # start-limit-hit below. Inactive (idle/stopped) is NOT failed.
            if systemctl is-failed --quiet "$svc" 2>/dev/null; then
              failed_val=1
            fi

            nrestarts=$(systemctl_value "$svc" -p NRestarts)
            nrestarts="''${nrestarts:-0}"

            local result
            result=$(systemctl show "$svc" -p Result --value 2>/dev/null) || result=""
            if [ "$result" = "start-limit-hit" ]; then
              limit_hit=1
            fi

            echo "system_service_active{service=\"''${svc}\"} ''${active_val}"
            echo "system_service_state_failed{service=\"''${svc}\"} ''${failed_val}"
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
            cpu_nsec=$(systemctl_value "$svc" -p CPUUsageNSec)
            cpu_nsec="''${cpu_nsec:-0}"
            echo "$svc $cpu_nsec $NOW_EPOCH" >> "''${CPU_STATE}.tmp"
          done
          mv "''${CPU_STATE}.tmp" "$CPU_STATE"

          # === Crash-loop detection: track restart count deltas per service ===
          declare -A prev_restarts
          if [ -f "$RESTART_STATE" ]; then
            while IFS=' ' read -r s n; do
              [ -n "$s" ] && prev_restarts["$s"]="$n"
            done < "$RESTART_STATE"
          fi
          : > "''${RESTART_STATE}.tmp"
          for svc in ${lib.concatMapStringsSep " " (s: "'${s}'") cfg.monitoredServices}; do
            cur_r=$(systemctl_value "$svc" -p NRestarts)
            echo "$svc ''${cur_r:-0}" >> "''${RESTART_STATE}.tmp"
          done
          mv "''${RESTART_STATE}.tmp" "$RESTART_STATE"

          # === User-1000.slice memory (desktop-only) ===
          collect_user_slice=${lib.boolToString cfg.collectUserSlice}
          SLICE_OVER=0
          SLICE_MEM=0
          if [ "$collect_user_slice" = "true" ]; then
            SLICE_MEM=$(systemctl_value user-1000.slice -p MemoryCurrent)
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
          collect_tmpfs=${lib.boolToString cfg.collectTmpfs}
          TMPFS_USAGE=0
          TMPFS_OVER=0
          if [ "$collect_tmpfs" = "true" ] && df /tmp >/dev/null 2>&1; then
            TMPFS_USAGE=$(df --output=pcent /tmp 2>/dev/null | tail -1 | tr -dc '0-9') || TMPFS_USAGE=0
            TMPFS_USAGE="''${TMPFS_USAGE:-0}"
            [ "$TMPFS_USAGE" -ge ${toString tmpfsThreshold} ] 2>/dev/null && TMPFS_OVER=1
          fi

          # === fstrim last-run duration ===
          FSTRIM_DURATION=0
          FSTRIM_OVER=0
          FSTRIM_START=$(systemctl show fstrim -p ExecMainStartTimestamp --value 2>/dev/null || echo "")
          FSTRIM_EXIT=$(systemctl show fstrim -p ExecMainExitTimestamp --value 2>/dev/null || echo "")
          if [ -n "$FSTRIM_START" ] && [ -n "$FSTRIM_EXIT" ] && [ "$FSTRIM_START" != "n/a" ] && [ "$FSTRIM_EXIT" != "n/a" ]; then
            FSTRIM_START_EPOCH=$(date -d "$FSTRIM_START" +%s 2>/dev/null || echo 0)
            FSTRIM_EXIT_EPOCH=$(date -d "$FSTRIM_EXIT" +%s 2>/dev/null || echo 0)
            if [ "$FSTRIM_START_EPOCH" -gt 0 ] && [ "$FSTRIM_EXIT_EPOCH" -ge "$FSTRIM_START_EPOCH" ] 2>/dev/null; then
              FSTRIM_DURATION=$((FSTRIM_EXIT_EPOCH - FSTRIM_START_EPOCH))
              [ "$FSTRIM_DURATION" -gt ${toString fstrimDurationThreshold} ] 2>/dev/null && FSTRIM_OVER=1
            fi
          fi

          # === EMEET PIXY session-aware gate ===
          # emeet-pixyd is a graphical-session user service — it only runs
          # when someone is logged into the niri desktop. Only flag as
          # unexpected-down when niri IS running but the daemon is NOT.
          NIRI_RUNNING=$(pgrep -x niri >/dev/null 2>&1 && echo 1 || echo 0)
          EMEET_RUNNING=$(pgrep -x emeet-pixyd >/dev/null 2>&1 && echo 1 || echo 0)
          EMEET_EXPECTED_DOWN=0
          if [ "$NIRI_RUNNING" = "1" ] && [ "$EMEET_RUNNING" = "0" ]; then
            EMEET_EXPECTED_DOWN=1
          fi

          # === memory.events max counter (death-loop detection) ===
          # The PMA page-cache death-loop hit MemoryMax 27,312 times without a
          # single oom_kill (page cache is reclaimable). This counter catches
          # that pattern: high max events = thrashing against the memory ceiling.
          #
          # Sandbox note: this service runs as root with ProtectSystem=full.
          # "full" only mounts /usr, /boot, /efi, /etc read-only — /sys/fs/cgroup
          # is NOT affected, so memory.events is readable without additional grants.

          # === Gatus self-monitoring meta-check ===
          # Reads gatus's sqlite DB directly (readonly): the HTTP API sits
          # behind OIDC and 401s unauthenticated curl — the old curl-based
          # check always fell back to a phantom 0 (permanently green).
          # Gatus self-prunes result retention, so an endpoint with ZERO
          # successes in the whole table has been failing for the entire
          # retained window. Staleness = db/wal mtime: gatus writes results
          # at least every few minutes; >15 min without a write means gatus
          # itself is wedged or dead. Fail-closed: on any error the value
          # metrics are NOT emitted — gatus pat() presence checks go red.
          collect_gatus=${lib.boolToString cfg.collectGatusHealth}
          GATUS_META_ERRORS=1
          GATUS_ENDPOINTS_LONG_FAIL=""
          GATUS_RESULTS_STALE=""
          if [ "$collect_gatus" = "true" ] && [ -r "${cfg.gatus.dbPath}" ]; then
            GATUS_ENDPOINTS_LONG_FAIL=$(sqlite3 -readonly "${cfg.gatus.dbPath}" "SELECT COUNT(*) FROM endpoints e WHERE EXISTS (SELECT 1 FROM endpoint_results r WHERE r.endpoint_id = e.endpoint_id) AND NOT EXISTS (SELECT 1 FROM endpoint_results r WHERE r.endpoint_id = e.endpoint_id AND r.success = 1)" 2>/dev/null) || GATUS_ENDPOINTS_LONG_FAIL=""
            if [ -n "$GATUS_ENDPOINTS_LONG_FAIL" ]; then
              GATUS_META_ERRORS=0
              GATUS_FRESH_EPOCH=$(stat -c %Y "${cfg.gatus.dbPath}" 2>/dev/null) || GATUS_FRESH_EPOCH=0
              GATUS_WAL_EPOCH=$(stat -c %Y "${cfg.gatus.dbPath}-wal" 2>/dev/null) || GATUS_WAL_EPOCH=0
              if [ "$GATUS_WAL_EPOCH" -gt "$GATUS_FRESH_EPOCH" ] 2>/dev/null; then
                GATUS_FRESH_EPOCH=$GATUS_WAL_EPOCH
              fi
              GATUS_RESULTS_STALE=0
              if [ $((NOW_EPOCH - GATUS_FRESH_EPOCH)) -ge 900 ]; then
                GATUS_RESULTS_STALE=1
              fi
            fi
          fi

          # === Root disk usage ===
          collect_disk_usage=${lib.boolToString cfg.collectDiskUsage}
          DISK_USAGE=0
          DISK_OVER=0
          if [ "$collect_disk_usage" = "true" ] && df / >/dev/null 2>&1; then
            DISK_USAGE=$(df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9') || DISK_USAGE=0
            DISK_USAGE="''${DISK_USAGE:-0}"
            [ "$DISK_USAGE" -ge ${toString diskUsageThreshold} ] 2>/dev/null && DISK_OVER=1
          fi

          # === zram swap fill (zram-only swap hosts) ===
          # mm_stat fields: orig_data_size compr_data_size mem_used_total ...
          # "fill" = orig_data_size / disksize = how full the zram SWAP device
          # is. When it hits 100%, the kernel falls back to page-cache reclaim
          # (disk I/O) — the BTRFS I/O storm precursor on zram-only hosts.
          # Metrics are ONLY emitted when /sys is readable: an absent metric
          # makes the Gatus pat() condition fail (fail-closed), never a
          # phantom green from zero defaults.
          collect_zram=${lib.boolToString cfg.collectZram}
          ZRAM_FILL=""
          if [ "$collect_zram" = "true" ] && [ -r /sys/block/zram0/mm_stat ] && [ -r /sys/block/zram0/disksize ]; then
            ZRAM_ORIG=$(awk '{print $1}' /sys/block/zram0/mm_stat 2>/dev/null) || ZRAM_ORIG=0
            ZRAM_MEM_USED=$(awk '{print $3}' /sys/block/zram0/mm_stat 2>/dev/null) || ZRAM_MEM_USED=0
            ZRAM_DISKSIZE=$(cat /sys/block/zram0/disksize 2>/dev/null) || ZRAM_DISKSIZE=0
            ZRAM_ORIG="''${ZRAM_ORIG:-0}"
            ZRAM_MEM_USED="''${ZRAM_MEM_USED:-0}"
            ZRAM_DISKSIZE="''${ZRAM_DISKSIZE:-0}"
            if [ "$ZRAM_DISKSIZE" -gt 0 ] 2>/dev/null; then
              ZRAM_FILL=$(awk -v o="$ZRAM_ORIG" -v d="$ZRAM_DISKSIZE" 'BEGIN { printf "%.1f", o * 100.0 / d }')
              ZRAM_OVER=0
              if awk -v f="$ZRAM_FILL" 'BEGIN { exit !(f >= ${toString zramFillThreshold}) }'; then
                ZRAM_OVER=1
              fi
            fi
          fi

          # === systemd-oomd kills tracking ===
          # systemd-oomd kills (nix-daemon, Twenty worker) went completely
          # undetected. This counts kill events from the journal since boot
          # and tracks the delta since last collection to catch new kills.
          collect_oomd=${lib.boolToString cfg.collectOomdKills}
          OOMD_KILLS_TOTAL=0
          OOMD_KILLS_RECENT=0
          OOMD_ALERT=0
          if [ "$collect_oomd" = "true" ]; then
            OOMD_KILLS_TOTAL=$(journalctl -u systemd-oomd --grep "Marked.*for killing" --output cat --no-pager 2>/dev/null | wc -l) || OOMD_KILLS_TOTAL=0
            OOMD_KILLS_TOTAL="''${OOMD_KILLS_TOTAL:-0}"
            prev_oomd=0
            if [ -f "$OOMD_STATE" ]; then
              prev_oomd=$(cat "$OOMD_STATE" 2>/dev/null) || prev_oomd=0
            fi
            prev_oomd="''${prev_oomd:-0}"
            if [ "$OOMD_KILLS_TOTAL" -gt "$prev_oomd" ] 2>/dev/null; then
              OOMD_KILLS_RECENT=$((OOMD_KILLS_TOTAL - prev_oomd))
              OOMD_ALERT=1
            fi
            echo "$OOMD_KILLS_TOTAL" > "''${OOMD_STATE}.tmp"
            mv "''${OOMD_STATE}.tmp" "$OOMD_STATE"
          fi

          # === Docker container restart count monitoring ===
          # Docker container restart counts are not exported as Prometheus
          # metrics by default. The Twenty 235-restart loop went unnoticed.
          # This collector tracks restart count deltas per container.
          collect_docker=${lib.boolToString cfg.collectDockerRestarts}
          DOCKER_ANY_ALERT=0
          declare -A prev_docker_restarts
          if [ "$collect_docker" = "true" ] && [ -f "$DOCKER_STATE" ]; then
            while IFS=' ' read -r n r; do
              [ -n "$n" ] && prev_docker_restarts["$n"]="$r"
            done < "$DOCKER_STATE"
          fi

          {
            echo "# HELP system_service_active 1 if systemd service is active, 0 otherwise"
            echo "# TYPE system_service_active gauge"

            echo "# HELP system_service_state_failed 1 if systemd unit is in failed state, 0 otherwise (inactive ≠ failed)"
            echo "# TYPE system_service_state_failed gauge"

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

            echo "# HELP system_service_memory_bytes Cgroup memory.current for monitored services"
            echo "# TYPE system_service_memory_bytes gauge"

            echo "# HELP system_service_memory_threshold_bytes Per-service alert threshold: 90% of the unit's MemoryMax (fallback: ${toString serviceMemoryThresholdFallback} bytes when unlimited)"
            echo "# TYPE system_service_memory_threshold_bytes gauge"

            echo "# HELP system_service_memory_over_threshold 1 if service cgroup memory exceeds 90% of its MemoryMax, 0 otherwise"
            echo "# TYPE system_service_memory_over_threshold gauge"

            ${lib.concatMapStrings (svc: ''
              svc="${svc}"
              mem_bytes=$(systemctl_value "$svc" -p MemoryCurrent)
              mem_bytes="''${mem_bytes:-0}"
              mem_max=$(systemctl show "$svc" -p MemoryMax --value 2>/dev/null || echo "")
              mem_threshold=${toString serviceMemoryThresholdFallback}
              if [ -n "$mem_max" ] && [ "$mem_max" != "infinity" ] && [ "$mem_max" -gt 0 ] 2>/dev/null; then
                mem_threshold=$((mem_max * 90 / 100))
              fi
              echo "system_service_memory_bytes{service=\"$svc\"} ''${mem_bytes}"
              echo "system_service_memory_threshold_bytes{service=\"$svc\"} ''${mem_threshold}"
              mem_over=0
              if [ "$mem_bytes" -gt "$mem_threshold" ] 2>/dev/null; then
                mem_over=1
              fi
              echo "system_service_memory_over_threshold{service=\"$svc\"} ''${mem_over}"
            '') cfg.monitoredServices}

            echo "# HELP system_service_memory_events_max Cgroup memory.events max counter (times service hit MemoryMax)"
            echo "# TYPE system_service_memory_events_max gauge"

            echo "# HELP system_service_memory_events_high 1 if service memory.events max exceeds ${toString memoryEventsMaxThreshold}, 0 otherwise"
            echo "# TYPE system_service_memory_events_high gauge"

            any_events_high=0
            ${lib.concatMapStrings (svc: ''
              svc="${svc}"
              events_file="/sys/fs/cgroup/system.slice/''${svc}.service/memory.events"
              max_events=0
              if [ -f "$events_file" ]; then
                max_events=$(awk '/^max / {print $2}' "$events_file" 2>/dev/null) || max_events=0
              fi
              max_events="''${max_events:-0}"
              echo "system_service_memory_events_max{service=\"$svc\"} ''${max_events}"
              events_high=0
              if [ "$max_events" -gt ${toString memoryEventsMaxThreshold} ] 2>/dev/null; then
                events_high=1
              fi
              echo "system_service_memory_events_high{service=\"$svc\"} ''${events_high}"
              if [ "$events_high" = "1" ]; then any_events_high=1; fi
            '') cfg.monitoredServices}

            echo "# HELP system_memory_events_any_high 1 if ANY monitored service exceeds the memory.events max threshold, 0 otherwise"
            echo "# TYPE system_memory_events_any_high gauge"
            echo "system_memory_events_any_high ''${any_events_high}"

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

            echo "# HELP system_tmpfs_tmp_usage_percent /tmp tmpfs usage percentage (0-100)"
            echo "# TYPE system_tmpfs_tmp_usage_percent gauge"
            echo "system_tmpfs_tmp_usage_percent ''${TMPFS_USAGE}"

            echo "# HELP system_tmpfs_tmp_over_threshold 1 if /tmp tmpfs exceeds ${toString tmpfsThreshold}% usage, 0 otherwise"
            echo "# TYPE system_tmpfs_tmp_over_threshold gauge"
            echo "system_tmpfs_tmp_over_threshold ''${TMPFS_OVER}"

            echo "# HELP system_fstrim_duration_seconds Duration of last fstrim run in seconds"
            echo "# TYPE system_fstrim_duration_seconds gauge"
            echo "system_fstrim_duration_seconds ''${FSTRIM_DURATION}"

            echo "# HELP system_fstrim_duration_over_threshold 1 if last fstrim took >${toString fstrimDurationThreshold}s, 0 otherwise"
            echo "# TYPE system_fstrim_duration_over_threshold gauge"
            echo "system_fstrim_duration_over_threshold ''${FSTRIM_OVER}"

            echo "# HELP system_emeet_pixyd_expected_down 1 if niri is running but emeet-pixyd is not (unexpected), 0 otherwise"
            echo "# TYPE system_emeet_pixyd_expected_down gauge"
            echo "system_emeet_pixyd_expected_down ''${EMEET_EXPECTED_DOWN}"

            if [ "$collect_gatus" = "true" ]; then
              echo "# HELP system_gatus_meta_scrape_errors 1 if the gatus sqlite meta-check failed (DB unreadable or query error), 0 otherwise"
              echo "# TYPE system_gatus_meta_scrape_errors gauge"
              echo "system_gatus_meta_scrape_errors ''${GATUS_META_ERRORS}"
            fi
            if [ -n "$GATUS_ENDPOINTS_LONG_FAIL" ]; then
              echo "# HELP system_gatus_endpoints_in_error_long Count of Gatus endpoints with sustained failures (zero successes in the entire retained result window)"
              echo "# TYPE system_gatus_endpoints_in_error_long gauge"
              echo "system_gatus_endpoints_in_error_long ''${GATUS_ENDPOINTS_LONG_FAIL}"

              echo "# HELP system_gatus_results_stale 1 if the gatus result DB has had no writes for >15 minutes, 0 otherwise"
              echo "# TYPE system_gatus_results_stale gauge"
              echo "system_gatus_results_stale ''${GATUS_RESULTS_STALE}"
            fi

            echo "# HELP system_disk_usage_percent Root filesystem usage percentage (0-100)"
            echo "# TYPE system_disk_usage_percent gauge"
            echo "system_disk_usage_percent ''${DISK_USAGE}"

            echo "# HELP system_disk_usage_over_threshold 1 if root filesystem exceeds ${toString diskUsageThreshold}% usage, 0 otherwise"
            echo "# TYPE system_disk_usage_over_threshold gauge"
            echo "system_disk_usage_over_threshold ''${DISK_OVER}"

            if [ -n "$ZRAM_FILL" ]; then
              echo "# HELP system_zram_swap_fill_percent zram swap fill: orig_data_size / disksize from mm_stat (percent)"
              echo "# TYPE system_zram_swap_fill_percent gauge"
              echo "system_zram_swap_fill_percent ''${ZRAM_FILL}"

              echo "# HELP system_zram_swap_orig_data_bytes Uncompressed bytes currently stored in zram (mm_stat orig_data_size)"
              echo "# TYPE system_zram_swap_orig_data_bytes gauge"
              echo "system_zram_swap_orig_data_bytes ''${ZRAM_ORIG}"

              echo "# HELP system_zram_swap_disksize_bytes zram device capacity (disksize)"
              echo "# TYPE system_zram_swap_disksize_bytes gauge"
              echo "system_zram_swap_disksize_bytes ''${ZRAM_DISKSIZE}"

              echo "# HELP system_zram_mem_used_bytes Physical RAM consumed by zram (mm_stat mem_used_total)"
              echo "# TYPE system_zram_mem_used_bytes gauge"
              echo "system_zram_mem_used_bytes ''${ZRAM_MEM_USED}"

              echo "# HELP system_zram_fill_over_threshold 1 if zram swap fill exceeds ${toString zramFillThreshold}%, 0 otherwise"
              echo "# TYPE system_zram_fill_over_threshold gauge"
              echo "system_zram_fill_over_threshold ''${ZRAM_OVER}"
            fi

            echo "# HELP system_service_crash_loop 1 if service restarted >=${toString crashLoopRestartThreshold} times since last collection, 0 otherwise"
            echo "# TYPE system_service_crash_loop gauge"

            ANY_CRASH_LOOP=0
            ${lib.concatMapStrings (svc: ''
              svc="${svc}"
              cur_r=$(systemctl_value "$svc" -p NRestarts)
              cur_r="''${cur_r:-0}"
              prev_r="''${prev_restarts[$svc]:-0}"
              r_delta=0
              if [ "$cur_r" -gt "$prev_r" ] 2>/dev/null; then
                r_delta=$((cur_r - prev_r))
              fi
              crash_loop=0
              if [ "$r_delta" -ge ${toString crashLoopRestartThreshold} ] 2>/dev/null; then
                crash_loop=1
                ANY_CRASH_LOOP=1
              fi
              echo "system_service_crash_loop{service=\"$svc\"} ''${crash_loop}"
            '') cfg.monitoredServices}

            echo "# HELP system_any_service_crash_loop 1 if ANY monitored service is crash-looping (>=${toString crashLoopRestartThreshold} restarts per interval), 0 otherwise"
            echo "# TYPE system_any_service_crash_loop gauge"
            echo "system_any_service_crash_loop ''${ANY_CRASH_LOOP}"

            echo "# HELP system_oomd_kills_total Total systemd-oomd kill events since boot"
            echo "# TYPE system_oomd_kills_total gauge"
            echo "system_oomd_kills_total ''${OOMD_KILLS_TOTAL}"

            echo "# HELP system_oomd_kills_recent systemd-oomd kill events since last collection"
            echo "# TYPE system_oomd_kills_recent gauge"
            echo "system_oomd_kills_recent ''${OOMD_KILLS_RECENT}"

            echo "# HELP system_oomd_kills_alert 1 if oomd killed a process since last collection, 0 otherwise"
            echo "# TYPE system_oomd_kills_alert gauge"
            echo "system_oomd_kills_alert ''${OOMD_ALERT}"

            echo "# HELP docker_container_restart_count Total restart count per Docker container"
            echo "# TYPE docker_container_restart_count gauge"

            echo "# HELP docker_container_restart_alert 1 if container restarted >=${toString dockerRestartAlertThreshold} times since last collection, 0 otherwise"
            echo "# TYPE docker_container_restart_alert gauge"

            if [ "$collect_docker" = "true" ] && docker info >/dev/null 2>&1; then
              : > "''${DOCKER_STATE}.tmp"
              for cname in $(docker ps --format '{{.Names}}' 2>/dev/null); do
                cur_rc=$(docker inspect --format '{{.RestartCount}}' "$cname" 2>/dev/null) || cur_rc=0
                cur_rc="''${cur_rc:-0}"
                echo "$cname $cur_rc" >> "''${DOCKER_STATE}.tmp"
                prev_rc="''${prev_docker_restarts[$cname]:-0}"
                rc_delta=0
                if [ "$cur_rc" -gt "$prev_rc" ] 2>/dev/null; then
                  rc_delta=$((cur_rc - prev_rc))
                fi
                rc_alert=0
                if [ "$rc_delta" -ge ${toString dockerRestartAlertThreshold} ] 2>/dev/null; then
                  rc_alert=1
                  DOCKER_ANY_ALERT=1
                fi
                echo "docker_container_restart_count{name=\"$cname\"} ''${cur_rc}"
                echo "docker_container_restart_alert{name=\"$cname\"} ''${rc_alert}"
              done
              mv "''${DOCKER_STATE}.tmp" "$DOCKER_STATE"
            fi

            echo "# HELP system_any_docker_container_restart_alert 1 if ANY Docker container is rapidly restarting, 0 otherwise"
            echo "# TYPE system_any_docker_container_restart_alert gauge"
            echo "system_any_docker_container_restart_alert ''${DOCKER_ANY_ALERT}"
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
            "browser-history"
            "browser-history-agent"
            "caddy"
            "dnsblockd"
            "discordsync"
            "fastflowlm"
            "forgejo"
            "gatus"
            "gotenberg"
            "homepage-dashboard"
            "monitor365"
            "monitor365-server"
            "nix-daemon"
            "paperless-consumer"
            "paperless-scheduler"
            "paperless-task-queue"
            "paperless-web"
            "pocket-id"
            "projects-management-automation"
            "signoz"
            "tika"
          ];
          description = "Systemd services to monitor for state, restart count, crash-loop detection, and start-limit-hit";
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

        collectTmpfs = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect /tmp tmpfs usage metrics";
        };

        collectGatusHealth = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect Gatus endpoint failure meta-check (monitoring the monitor)";
        };

        collectDiskUsage = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect root filesystem usage percentage with threshold flag";
        };

        collectOomdKills = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect systemd-oomd kill events from journal";
        };

        collectDockerRestarts = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect Docker container restart count metrics (auto-disabled if Docker is not enabled)";
        };

        collectZram = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Collect zram swap fill metrics from /sys/block/zram0/mm_stat (auto-disabled without zramSwap)";
        };

        signoz.port = lib.mkOption {
          type = lib.types.int;
          default = 8080;
          description = "SigNoz query service port for alert rules API";
        };

        gatus.port = lib.mkOption {
          type = lib.types.int;
          default = 9110;
          description = "Gatus web port for the API";
        };

        gatus.dbPath = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/private/gatus/gatus.db";
          description = "Host path to the gatus sqlite DB (DynamicUser hides /var/lib/gatus behind /var/lib/private on the host)";
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
          })
          // (lib.optionalAttrs (options ? services.gatus) {
            collectGatusHealth = lib.mkDefault (config.services.gatus.enable or false);
          })
          // (lib.optionalAttrs (options ? virtualisation.docker) {
            collectDockerRestarts = lib.mkDefault (config.virtualisation.docker.enable or false);
          })
          // (lib.optionalAttrs (options ? services.zramSwap) {
            collectZram = lib.mkDefault (config.services.zramSwap.enable or false);
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
