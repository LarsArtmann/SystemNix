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

      # Crush session pressure: concurrent crush TUI sessions above which a
      # sustained-pressure alert fires. 2026-08-22 freeze census ran ~12
      # sessions (52 crush + 50 bun procs) as a major memory consumer;
      # 6 is roughly double a normal heavy day (user decision: monitor-only).
      crushSessionAlertThreshold = 6;

      # Forgejo mirror staleness: freshest pull-mirror sync older than this
      # flags the sync pipeline as stalled. Mirrors run on an 8h interval
      # with a 30m update_mirrors cron — healthy freshest age is minutes;
      # 10h = one full interval + slack (2026-08-22 dead-queue outage was
      # discovered only via frozen mirror.updated_unix).
      forgejoMirrorStalenessSeconds = 10 * 3600;

      # Forgejo mirror journal-error threshold per 30 min window. The ENOENT
      # era logged ~100 errors/30min; a single transient git failure should
      # not page. >=3 = a systematic failure retrying every cron round.
      forgejoMirrorErrorThreshold = 3;

      # Slow-churn detection: CUMULATIVE NRestarts since the last explicit
      # (deploy/manual) start. Catches restart chains that never trip the
      # per-interval threshold above — e.g. hermes' exit-75 drain-timeout
      # chain (RestartForceExitStatus=75) restarting once every few minutes
      # indefinitely while every liveness probe stays green. NRestarts resets
      # to 0 on every systemctl restart (deploys), so deploy churn itself
      # cannot accumulate here.
      restartChurnThreshold = 5;

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
            RULE_COUNT=$(curl -sf --compressed --max-time 5 http://127.0.0.1:${toString cfg.signoz.port}/api/v1/rules 2>/dev/null | jq '.data.rules | length' 2>/dev/null) || RULE_COUNT=0
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

          # === dnsblockd stats-API wedge probe ===
          # The :9090 stats API can wedge while DNS stays healthy (2026-08-27:
          # every HTTP handler stuck mid-request, CLOSE_WAIT pileup, process
          # idle). The SigNoz scrape-staleness rule catches it via
          # count(up{service_name="dnsblockd"}); this probe gives Gatus an
          # INDEPENDENT tripwire that does not depend on dnsblockd's
          # self-reported OTel labels. 1 = answered HTTP 200 within 5s,
          # 0 = wedged or unreachable. Emitted ONLY when the probe ran —
          # absence fails the Gatus anchored presence check fail-closed.
          collect_dnsblockd_stats=${lib.boolToString cfg.collectDnsblockdStats}
          DNSBLOCKD_STATS_FRESH=""
          if [ "$collect_dnsblockd_stats" = "true" ]; then
            DNSBLOCKD_HTTP_CODE=$(curl -s --compressed --max-time 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${toString cfg.dnsblockdStatsPort}/metrics" 2>/dev/null) || DNSBLOCKD_HTTP_CODE="000"
            if [ "$DNSBLOCKD_HTTP_CODE" = "200" ]; then
              DNSBLOCKD_STATS_FRESH=1
            else
              DNSBLOCKD_STATS_FRESH=0
            fi
          fi

          # === Forgejo pull-mirror sync health ===
          # Reads forgejo's sqlite DB directly (readonly, gatus pattern):
          # the API is auth-gated and the journal alone is blind to the
          # silent failure class. Mirror outages come in two shapes
          # (2026-08-18..22 incident), each needing its own signal:
          # 1. ACTIVE failures (forgejo 15.0.6 AddAuthCredentialHelper
          #    aborting every credentialed sync with ENOENT for 2.5 days;
          #    DNS-dead allowlist rechecks logging "not allowed") produce
          #    Error journal lines every cron round — caught by the error
          #    count. TouchMirror advances mirror.updated_unix on FAILURE
          #    too, so the DB age alone cannot see this class.
          # 2. The SILENT dead-queue class: after the 2026-08-22 hard
          #    freeze every restarted forgejo process had a wedged mirror
          #    queue — the update_mirrors cron (30m) pushes dedup-skip at
          #    Trace level and NOTHING is logged; only updated_unix stops
          #    advancing. Caught by the freshest-sync age. Fail-closed: on
          #    any read error only system_forgejo_mirror_scrape_errors=1 is
          #    emitted and the Gatus pat() presence checks go red.
          collect_forgejo_mirrors=${lib.boolToString cfg.collectForgejoMirrors}
          FORGEJO_MIRROR_SCRAPE_ERRORS=1
          FORGEJO_MIRROR_LAST_SYNC_AGE=""
          FORGEJO_MIRROR_STALLED=""
          FORGEJO_MIRROR_ERRORS_30M=""
          FORGEJO_MIRROR_ERRORING=""
          if [ "$collect_forgejo_mirrors" = "true" ] && [ -r "${cfg.forgejo.dbPath}" ]; then
            # .timeout: forgejo's DB is hot (action_runner heartbeats every
            # ~2s) — without a busy-timeout the readonly query dies on the
            # first SQLITE_BUSY and the check fail-closes permanently.
            # stderr is captured so failures are diagnosable via
            # journalctl -u system-health-metrics.
            FORGEJO_LAST_SYNC=$(sqlite3 -readonly "${cfg.forgejo.dbPath}" ".timeout 5000" "SELECT MAX(updated_unix) FROM mirror" 2>&1) || FORGEJO_LAST_SYNC=""
            if ! echo "$FORGEJO_LAST_SYNC" | grep -qE '^[0-9]+$'; then
              echo "system-health: forgejo mirror query failed: $FORGEJO_LAST_SYNC" >&2
              FORGEJO_LAST_SYNC=""
            fi
            if [ -n "$FORGEJO_LAST_SYNC" ]; then
              FORGEJO_MIRROR_SCRAPE_ERRORS=0
              FORGEJO_MIRROR_LAST_SYNC_AGE=$((NOW_EPOCH - FORGEJO_LAST_SYNC))
              if [ "$FORGEJO_MIRROR_LAST_SYNC_AGE" -lt 0 ] 2>/dev/null; then
                FORGEJO_MIRROR_LAST_SYNC_AGE=0
              fi
              FORGEJO_MIRROR_STALLED=0
              if [ "$FORGEJO_MIRROR_LAST_SYNC_AGE" -ge ${toString forgejoMirrorStalenessSeconds} ] 2>/dev/null; then
                FORGEJO_MIRROR_STALLED=1
              fi
              FORGEJO_MIRROR_ERRORS_30M=$(journalctl -u forgejo.service --since "-30 min" --grep "AddAuthCredentialHelperForRemote Error|failed to update mirror repository|pull mirror failed to meet migration URL requirements|failed to get remote address" --output cat --no-pager 2>/dev/null | wc -l) || FORGEJO_MIRROR_ERRORS_30M=0
              FORGEJO_MIRROR_ERRORS_30M="''${FORGEJO_MIRROR_ERRORS_30M:-0}"
              FORGEJO_MIRROR_ERRORING=0
              if [ "$FORGEJO_MIRROR_ERRORS_30M" -ge ${toString forgejoMirrorErrorThreshold} ] 2>/dev/null; then
                FORGEJO_MIRROR_ERRORING=1
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

          # === Crush agent session census (admission-control monitor) ===
          # 2026-08-22 freeze census: ~12 concurrent crush sessions (52 crush
          # + 50 bun procs) were a major RAM consumer. User decision:
          # monitor-only (no enforcement) — alert when sustained session
          # pressure exceeds the threshold. Each session = one `crush`
          # process (TUI); MCP/bun children are excluded by -x.
          CRUSH_SESSIONS=$(pgrep -x crush 2>/dev/null | wc -l) || CRUSH_SESSIONS=0
          CRUSH_SESSIONS="''${CRUSH_SESSIONS:-0}"
          CRUSH_SESSIONS_OVER=0
          if [ "$CRUSH_SESSIONS" -gt ${toString crushSessionAlertThreshold} ] 2>/dev/null; then
            CRUSH_SESSIONS_OVER=1
          fi

          # === Top-N cgroup memory census ===
          # The 2026-08-22 freeze postmortem could not answer "who held the
          # ~30 GiB that kept zram pinned at 98.6% for 2h across 7 guard
          # trips" without kernel OOM-dump archaeology. This emits the top
          # cgroups by memory.current with anon/shmem/unevictable breakdown
          # (memory.stat) — the question becomes a dashboard glance.
          CENSUS_ENTRIES=$(
            ${pkgs.findutils}/bin/find /sys/fs/cgroup -xdev -maxdepth 4 -name memory.current 2>/dev/null |
            while read -r f; do
              cg=$(dirname "$f")
              name="''${cg#/sys/fs/cgroup}"
              name="''${name#/}"
              [ -n "$name" ] || name=root
              cur=$(cat "$f" 2>/dev/null) || continue
              echo "$cur $name"
            done | sort -rn | head -8
          )

          # === LAN NIC presence (bus-level disappearance) ===
          # 2026-08-22: after a hard crash the RTL8125 NIC was absent from
          # PCI enumeration entirely; r8125 had nothing to probe and the
          # static-IP stack (networking.interfaces.eno1) never ran — no IP,
          # SSH dead. Emitted only when lanInterface is set (empty string =
          # disabled); the matching Gatus check is gated on the SAME
          # condition — otherwise a NIC-less host would emit a permanent 1
          # (phantom green).
          LAN_IF="${cfg.lanInterface}"
          LAN_NIC_PRESENT=1
          if [ -n "$LAN_IF" ] && [ ! -e "/sys/class/net/$LAN_IF" ]; then
            LAN_NIC_PRESENT=0
          fi

          # === DAS USB link presence (single-link topology root cause) ===
          # ALL four external disks (2x pool Toshiba, 2x SanDisk incl.
          # buildcache) share ONE USB link. When it drops without a
          # reconnect (2026-08-22 00:59), buildcache + pool + SSDs vanish
          # simultaneously and only consequence alerts fire. This metric
          # alerts on the CAUSE. Emitted only when dasUsbPath is set (empty
          # string = disabled); the matching Gatus check is gated identically.
          DAS_USB_PATH="${cfg.dasUsbPath}"
          DAS_LINK_PRESENT=1
          if [ -n "$DAS_USB_PATH" ] && [ ! -e "/sys/bus/usb/devices/$DAS_USB_PATH" ]; then
            DAS_LINK_PRESENT=0
          fi

          # === running-system profile anchor (manual-activation detector) ===
          # Activations outside `nix run .#deploy` (switch-to-configuration
          # by hand — the banned pattern from the 2026-08-18 google-sync
          # incident; recurred 2026-08-22 when the ClickHouse XFS migration
          # was activated with no numbered profile) leave /run/current-system
          # pointing at a store path no system-N-link references: the next
          # reboot silently reverts to the last REAL generation and nothing
          # warns. 1 = anchored to a profile, 0 = revert-on-reboot risk.
          # Emitted unconditionally (fail-closed).
          SYSTEM_PROFILED=0
          RUN_SYS=$(readlink -f /run/current-system 2>/dev/null) || RUN_SYS=""
          if [ -n "$RUN_SYS" ] && readlink -f /nix/var/nix/profiles/system-*-link 2>/dev/null | grep -qxF "$RUN_SYS"; then
            SYSTEM_PROFILED=1
          fi

          # === systemd-oomd kills tracking ===
          # systemd-oomd kills (nix-daemon, Twenty worker) went completely
          # undetected. This counts kill events from the journal in the
          # trailing 24h and tracks the delta since last collection to catch
          # new kills.
          #
          # BOTH bounds are load-bearing (2026-08-31 live incident): the
          # original unbounded scan (no --since) walked the ENTIRE 7.2G
          # journal under this unit's 128M MemoryMax — page cache charged to
          # the cgroup thrashed in reclaim and a single run took 11-28 MIN
          # against a 2min timer interval. The textfile was stale most of
          # the time and sev1 paged "system_health metrics missing/stale"
          # on the desktop all afternoon. A 24h window measures ~10s;
          # `timeout 60` is the hard ceiling so a degraded journal walk can
          # never wedge the collector again. On timeout/failure we fail
          # CLOSED via system_oomd_kills_scrape_errors=1 (Gatus asserts it
          # 0) and keep the previous total: no phantom delta, no phantom
          # reset.
          collect_oomd=${lib.boolToString cfg.collectOomdKills}
          OOMD_KILLS_TOTAL=0
          OOMD_KILLS_RECENT=0
          OOMD_ALERT=0
          OOMD_SCRAPE_ERRORS=0
          if [ "$collect_oomd" = "true" ]; then
            prev_oomd=0
            if [ -f "$OOMD_STATE" ]; then
              prev_oomd=$(cat "$OOMD_STATE" 2>/dev/null) || prev_oomd=0
            fi
            prev_oomd="''${prev_oomd:-0}"
            OOMD_KILLS_TOTAL=$prev_oomd
            if oomd_out=$(timeout 60 journalctl -u systemd-oomd --since "-24h" --grep "Marked.*for killing" --output cat --no-pager 2>/dev/null | wc -l); then
              OOMD_KILLS_TOTAL="''${oomd_out:-0}"
              echo "$OOMD_KILLS_TOTAL" > "''${OOMD_STATE}.tmp"
              mv "''${OOMD_STATE}.tmp" "$OOMD_STATE"
            else
              OOMD_SCRAPE_ERRORS=1
            fi
            if [ "$OOMD_KILLS_TOTAL" -gt "$prev_oomd" ] 2>/dev/null; then
              OOMD_KILLS_RECENT=$((OOMD_KILLS_TOTAL - prev_oomd))
              OOMD_ALERT=1
            fi
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

            if [ "$collect_dnsblockd_stats" = "true" ]; then
              echo "# HELP system_dnsblockd_metrics_fresh dnsblockd stats API answered HTTP 200 within the probe timeout (yes=1, wedged or unreachable=0)"
              echo "# TYPE system_dnsblockd_metrics_fresh gauge"
              echo "system_dnsblockd_metrics_fresh ''${DNSBLOCKD_STATS_FRESH}"
            fi

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

            if [ "$collect_forgejo_mirrors" = "true" ]; then
              echo "# HELP system_forgejo_mirror_scrape_errors Scrape status of the forgejo mirror sqlite read: 0 = OK, 1 = DB unreadable or mirror table empty (fail-closed)"
              echo "# TYPE system_forgejo_mirror_scrape_errors gauge"
              echo "system_forgejo_mirror_scrape_errors ''${FORGEJO_MIRROR_SCRAPE_ERRORS}"
            fi
            if [ -n "$FORGEJO_MIRROR_LAST_SYNC_AGE" ]; then
              echo "# HELP system_forgejo_mirror_last_sync_age_seconds Age of the freshest pull-mirror sync (now - MAX(mirror.updated_unix)). TouchMirror advances updated_unix on failure too, so this goes stale ONLY when nothing runs at all (dead queue / dead scheduler)"
              echo "# TYPE system_forgejo_mirror_last_sync_age_seconds gauge"
              echo "system_forgejo_mirror_last_sync_age_seconds ''${FORGEJO_MIRROR_LAST_SYNC_AGE}"

              echo "# HELP system_forgejo_mirror_sync_stalled Stall flag for the freshest pull-mirror sync: 1 when older than ${toString forgejoMirrorStalenessSeconds}s (one 8h interval + slack), 0 otherwise"
              echo "# TYPE system_forgejo_mirror_sync_stalled gauge"
              echo "system_forgejo_mirror_sync_stalled ''${FORGEJO_MIRROR_STALLED}"

              echo "# HELP system_forgejo_mirror_errors_30m Forgejo mirror-sync Error journal lines in the last 30 minutes (credential-helper aborts, allowlist rejections, fetch failures)"
              echo "# TYPE system_forgejo_mirror_errors_30m gauge"
              echo "system_forgejo_mirror_errors_30m ''${FORGEJO_MIRROR_ERRORS_30M}"

              echo "# HELP system_forgejo_mirror_erroring Error flag: 1 when >=${toString forgejoMirrorErrorThreshold} mirror-sync Error lines hit the forgejo journal within 30 minutes, 0 otherwise"
              echo "# TYPE system_forgejo_mirror_erroring gauge"
              echo "system_forgejo_mirror_erroring ''${FORGEJO_MIRROR_ERRORING}"
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

            if [ -n "$LAN_IF" ]; then
              echo "# HELP system_lan_nic_present 1 if the primary LAN NIC (${cfg.lanInterface}) exists in /sys/class/net, 0 if it fell off the bus"
              echo "# TYPE system_lan_nic_present gauge"
              echo "system_lan_nic_present ''${LAN_NIC_PRESENT}"
            fi

            if [ -n "$DAS_USB_PATH" ]; then
              echo "# HELP system_das_link_present 1 if the DAS USB link (${cfg.dasUsbPath}) exists in /sys/bus/usb/devices, 0 if it dropped"
              echo "# TYPE system_das_link_present gauge"
              echo "system_das_link_present ''${DAS_LINK_PRESENT}"
            fi

            echo "# HELP system_crush_sessions Concurrent crush agent sessions (main TUI processes, MCP children excluded)"
            echo "# TYPE system_crush_sessions gauge"
            echo "system_crush_sessions ''${CRUSH_SESSIONS}"

            echo "# HELP system_crush_sessions_over_threshold 1 if crush sessions exceed ${toString crushSessionAlertThreshold} (sustained session pressure — 2026-08-22 freeze contributing load), 0 otherwise"
            echo "# TYPE system_crush_sessions_over_threshold gauge"
            echo "system_crush_sessions_over_threshold ''${CRUSH_SESSIONS_OVER}"

            echo "# HELP system_cgroup_mem_bytes memory.current of the top cgroups by usage (who is holding RAM)"
            echo "# TYPE system_cgroup_mem_bytes gauge"
            echo "# HELP system_cgroup_mem_anon_bytes anonymous memory (memory.stat anon) of the same top cgroups"
            echo "# TYPE system_cgroup_mem_anon_bytes gauge"
            echo "# HELP system_cgroup_mem_shmem_bytes shared/tmpfs/shmem memory (memory.stat shmem — the unevictable-under-full-swap class) of the same top cgroups"
            echo "# TYPE system_cgroup_mem_shmem_bytes gauge"
            echo "# HELP system_cgroup_mem_unevictable_bytes mlocked/unevictable memory (memory.stat unevictable) of the same top cgroups"
            echo "# TYPE system_cgroup_mem_unevictable_bytes gauge"
            if [ -n "$CENSUS_ENTRIES" ]; then
              echo "$CENSUS_ENTRIES" | while read -r cur name; do
                [ -n "$name" ] || continue
                label=$(echo "$name" | tr '/' '_')
                cgdir="/sys/fs/cgroup/$name"
                anon=$(awk '$1 == "anon" {print $2}' "$cgdir/memory.stat" 2>/dev/null) || anon=0
                shmem=$(awk '$1 == "shmem" {print $2}' "$cgdir/memory.stat" 2>/dev/null) || shmem=0
                unevict=$(awk '$1 == "unevictable" {print $2}' "$cgdir/memory.stat" 2>/dev/null) || unevict=0
                echo "system_cgroup_mem_bytes{cgroup=\"$label\"} ''${cur:-0}"
                echo "system_cgroup_mem_anon_bytes{cgroup=\"$label\"} ''${anon:-0}"
                echo "system_cgroup_mem_shmem_bytes{cgroup=\"$label\"} ''${shmem:-0}"
                echo "system_cgroup_mem_unevictable_bytes{cgroup=\"$label\"} ''${unevict:-0}"
              done
            fi

            echo "# HELP system_current_system_profiled 1 if /run/current-system matches a numbered nix profile generation (deployed via nix run .#deploy), 0 if manually activated (reboot would revert to the last real generation)"
            echo "# TYPE system_current_system_profiled gauge"
            echo "system_current_system_profiled ''${SYSTEM_PROFILED}"

            echo "# HELP system_service_crash_loop 1 if service restarted >=${toString crashLoopRestartThreshold} times since last collection, 0 otherwise"
            echo "# TYPE system_service_crash_loop gauge"

            ANY_CRASH_LOOP=0
            ANY_CHURN=0
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
              churn=0
              if [ "$cur_r" -ge ${toString restartChurnThreshold} ] 2>/dev/null; then
                churn=1
                ANY_CHURN=1
              fi
              echo "system_service_restart_churn{service=\"$svc\"} ''${churn}"
            '') cfg.monitoredServices}

            echo "# HELP system_any_service_crash_loop 1 if ANY monitored service is crash-looping (>=${toString crashLoopRestartThreshold} restarts per interval), 0 otherwise"
            echo "# TYPE system_any_service_crash_loop gauge"
            echo "system_any_service_crash_loop ''${ANY_CRASH_LOOP}"

            echo "# HELP system_any_service_restart_churn 1 if ANY monitored service accumulated >=${toString restartChurnThreshold} automatic restarts since its last explicit start (slow churn under the crash-loop radar), 0 otherwise"
            echo "# TYPE system_any_service_restart_churn gauge"
            echo "system_any_service_restart_churn ''${ANY_CHURN}"

            echo "# HELP system_oomd_kills_total systemd-oomd kill events in the trailing 24h (bounded scan, see collector)"
            echo "# TYPE system_oomd_kills_total gauge"
            echo "system_oomd_kills_total ''${OOMD_KILLS_TOTAL}"

            echo "# HELP system_oomd_kills_recent systemd-oomd kill events since last collection"
            echo "# TYPE system_oomd_kills_recent gauge"
            echo "system_oomd_kills_recent ''${OOMD_KILLS_RECENT}"

            echo "# HELP system_oomd_kills_alert 1 if oomd killed a process since last collection, 0 otherwise"
            echo "# TYPE system_oomd_kills_alert gauge"
            echo "system_oomd_kills_alert ''${OOMD_ALERT}"

            echo "# HELP system_oomd_kills_scrape_errors 1 if the bounded oomd journal scan failed or timed out (totals held at last-known values), 0 otherwise"
            echo "# TYPE system_oomd_kills_scrape_errors gauge"
            echo "system_oomd_kills_scrape_errors ''${OOMD_SCRAPE_ERRORS}"

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
      lanNicWatchdog = pkgs.writeShellApplication {
        name = "lan-nic-watchdog-check";
        text = ''
          IF="${cfg.lanInterface}"
          if [ ! -e "/sys/class/net/$IF" ]; then
            echo "LAN NIC '$IF' ABSENT — the PCIe device fell off the bus (2026-08-22: after a hard crash the RTL8125 [10ec:8125] was missing from PCI enumeration entirely; the SDHCI reader shifted into its slot c1:00.0). A warm reboot does NOT reliably retrain it: POWER-CYCLE the machine (shut down, wait ~10s, power on). Until then there is NO wired networking — the static LAN IP is unreachable and SSH is dead." >&2
            exit 1
          fi
          echo "LAN NIC '$IF' present"
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
            "hermes"
            "homepage-dashboard"
            "lan-nic-watchdog"
            "llama-embeddings"
            "llama-reranker"
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

        collectForgejoMirrors = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Collect forgejo pull-mirror sync health: freshest-sync age from
            the forgejo sqlite DB (catches the silent dead-queue class where
            the update_mirrors cron logs nothing) plus mirror-sync Error
            journal rate (catches active aborts — credential-helper ENOENT,
            allowlist rejections). Auto-disabled on hosts without forgejo.
          '';
        };

        collectDnsblockdStats = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Probe the dnsblockd stats API (/metrics) for wedge detection —
            catches the 2026-08-27 class where DNS stays healthy but every
            HTTP handler on the stats port hangs. Emits
            system_dnsblockd_metrics_fresh (1 = answered HTTP 200 within 5s,
            0 = wedged/unreachable). Auto-disabled on hosts without
            dns-blocker.
          '';
        };

        dnsblockdStatsPort = lib.mkOption {
          type = lib.types.port;
          default = 9090;
          description = "Port of the dnsblockd stats API to probe (mirrors services.dns-blocker.statsPort)";
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

        lanInterface = lib.mkOption {
          type = lib.types.str;
          default = "eno1";
          description = ''
            Primary LAN NIC to watch for bus-level disappearance. When the
            interface is absent from /sys/class/net, system_lan_nic_present
            emits 0 and the lan-nic-watchdog unit fails (2026-08-22: after a
            hard crash the RTL8125 fell off the PCIe bus entirely — PCI
            enumeration showed no 10ec:8125, the SDHCI reader shifted into
            its slot, and a WARM reboot did not retrain it; only the second
            reboot brought it back). Set to "" to disable.
          '';
        };

        dasUsbPath = lib.mkOption {
          type = lib.types.str;
          default = "8-1";
          description = ''
            USB bus path of the DAS link that carries all external disks
            (pool members + buildcache + spare SSDs). When absent from
            /sys/bus/usb/devices, system_das_link_present emits 0 and the
            Gatus "DAS USB Link" check alerts on the root cause instead of
            N consequence alerts (2026-08-22: link dropped without a single
            reconnect attempt for 22+ min while buildcache/pool checks were
            the only signals). Set to "" to disable.
          '';
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

        forgejo.dbPath = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/forgejo/data/forgejo.db";
          description = "Host path to the forgejo sqlite DB (read readonly for mirror sync staleness)";
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
          // (lib.optionalAttrs (options ? services.forgejo) {
            collectForgejoMirrors = lib.mkDefault (config.services.forgejo.enable or false);
            forgejo.dbPath = lib.mkDefault (config.services.forgejo.stateDir + "/data/forgejo.db");
          })
          // (lib.optionalAttrs (options ? services.dns-blocker) {
            collectDnsblockdStats = lib.mkDefault (config.services.dns-blocker.enable or false);
            dnsblockdStatsPort = lib.mkDefault (config.services.dns-blocker.statsPort or 9090);
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
                # CAP_DAC_READ_SEARCH: the collector runs as root but harden{}
                # strips all caps — without this it cannot traverse forgejo's
                # 0700 stateDir to read the mirror-sync sqlite (the -r gate
                # silently fail-closes system_forgejo_mirror_scrape_errors=1,
                # 2026-08-22). Same pattern as atticd-storage-dir.
                CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                ExecStart = lib.getExe systemHealthMetrics;
                ReadWritePaths = [ textfileDir ];
                # Explicit ceiling (2026-08-31): the deployed system's
                # /etc/systemd/system.conf.d/ is EMPTY — the global
                # DefaultTimeoutStartSec=3min from timeout-audit.nix was
                # NOT live, so a wedged collection (unbounded oomd journal
                # scan) sat in "activating" for 11-28 min with nothing
                # killing it. A collection that cannot finish in 3min is
                # wedged: fail it into onFailure alerting instead.
                TimeoutStartSec = "3min";
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

          # Fails loudly (systemctl --failed + notify-failure) when the LAN
          # NIC is absent — either at boot (PCIe vanish after hard crash,
          # 2026-08-22) or at runtime (the DAS USB link dropped the same
          # night while running). The Gatus check on system_lan_nic_present
          # is the alerting path; this unit makes the failure visible on the
          # host itself.
          services.lan-nic-watchdog = lib.mkIf (cfg.lanInterface != "") {
            description = "LAN NIC presence watchdog (fails when ${cfg.lanInterface} falls off the bus — power-cycle required)";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "32M";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                ExecStart = lib.getExe lanNicWatchdog;
              }
            ];
          };

          timers.lan-nic-watchdog = lib.mkIf (cfg.lanInterface != "") {
            description = "Check LAN NIC presence every 10 minutes (first check 90s after boot)";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "90s";
              OnUnitActiveSec = "10min";
            };
          };
        };
      };
    };
}
