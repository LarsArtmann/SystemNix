# Memory emergency guard.
#
# Converts the memory-thrash kernel-freeze death spiral into a controlled
# degradation by proactively sacrificing the socket-activated LLM backend
# (FastFlowLM, ~25 GB unevictable shmem once its mmap'd model is fully
# resident) when the system enters the pre-freeze zone.
#
# 2026-08-22 incident (the class this guards): the machine froze solid at
# 00:27 after a chain that started at 22:25 with zram swap at 100%
# (Free swap = 0 kB of 29.5 GB), flm's model locked in as ~25 GB UNEVICTABLE
# shmem (shmem eviction requires swap space — with zram full there is none),
# ~56 GB anon, page cache evicted to ~0.6 GB. The kernel OOM killer cascaded
# (flm killed 4x, ollama 2x) and after midnight the combination of nightly
# btrbk sends + nix-gc deletes + zram refault CPU burn (ClickHouse reported
# "100% busy for 600s" — zram page-fault decompression storm) froze the
# kernel completely: journal stops 00:27:09, no panic, no shutdown, WDT
# would have fired at 10 min; the user power-cycled at 00:31. Gatus had
# ALREADY alerted "Memory pressure CRITICAL" to Discord at 23:44 — the
# warning existed, the automated action did not.
#
# The guard closes that gap: stop the flm backend BEFORE the cliff. flm is
# the designated sacrifice (stateless, socket-activated, self-heals on the
# next connection with a 1-3 min cold load — OOMScoreAdjust=300 already
# encodes this philosophy for the kernel OOM killer; this guard acts
# earlier, deterministically, without waiting for global exhaustion).
#
# Fail-closed metrics: the .prom file is written on EVERY run; if the guard
# itself dies, the metrics go stale and the Gatus presence condition fails.
_: {
  flake.nixosModules.memory-emergency-guard =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        mkStateDir
        ;

      cfg = config.services.memory-emergency-guard;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      stateDir = "/var/lib/memory-emergency-guard";

      guardScript = pkgs.writeShellApplication {
        name = "memory-emergency-guard-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.systemd
        ];
        text = ''
          set -euo pipefail

          OUT="${textfileDir}/memory-emergency-guard.prom"
          TMP="''${OUT}.tmp"
          COUNT_FILE="${stateDir}/tripped.count"
          LAST_TRIP_FILE="${stateDir}/last-trip"

          mem_available_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
          mem_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
          mem_available_kb="''${mem_available_kb:-0}"
          mem_total_kb="''${mem_total_kb:-1}"

          avail_pct=$(awk -v a="$mem_available_kb" -v t="$mem_total_kb" 'BEGIN { printf "%.1f", a * 100.0 / t }')

          # zram fill: orig_data_size / disksize. -1 when zram is absent or
          # unreadable (treated as "not full" — the absolute threshold below
          # still catches zram-less emergencies).
          zram_pct=-1
          if [ -r /sys/block/zram0/mm_stat ] && [ -r /sys/block/zram0/disksize ]; then
            zram_orig=$(awk '{print $1}' /sys/block/zram0/mm_stat 2>/dev/null) || zram_orig=0
            zram_disksize=$(cat /sys/block/zram0/disksize 2>/dev/null) || zram_disksize=0
            zram_orig="''${zram_orig:-0}"
            zram_disksize="''${zram_disksize:-0}"
            if [ "$zram_disksize" -gt 0 ] 2>/dev/null; then
              zram_pct=$(awk -v o="$zram_orig" -v d="$zram_disksize" 'BEGIN { printf "%.1f", o * 100.0 / d }')
            fi
          fi

          tripped_total=0
          if [ -f "$COUNT_FILE" ]; then
            tripped_total=$(cat "$COUNT_FILE" 2>/dev/null) || tripped_total=0
          fi
          tripped_total="''${tripped_total:-0}"

          # --- Trip decision ---
          # Zone 1 (absolute): MemAvailable below the hard floor — freeze is
          #   imminent regardless of zram state (2026-08-22 22:25: ~4-5%).
          # Zone 2 (combined): low MemAvailable AND zram nearly full — the
          #   shmem-unevictable trap forming (flm model pages cannot evict
          #   once swap is exhausted).
          trip=0
          reason=""
          if awk -v p="$avail_pct" 'BEGIN { exit !(p < ${toString cfg.absoluteMemAvailableThresholdPercent}) }'; then
            trip=1
            reason="MemAvailable=''${avail_pct}% below absolute floor"
          elif
            awk -v p="$avail_pct" 'BEGIN { exit !(p < ${toString cfg.memAvailableThresholdPercent}) }' &&
              awk -v z="$zram_pct" 'BEGIN { exit !(z >= ${toString cfg.zramFillThresholdPercent}) }'
          then
            trip=1
            reason="MemAvailable=''${avail_pct}% AND zram=''${zram_pct}% (shmem-unevictable trap: model pages cannot evict with full zram)"
          fi

          if [ "$trip" = "1" ]; then
            now=$(date +%s)
            last_trip=0
            if [ -f "$LAST_TRIP_FILE" ]; then
              last_trip=$(cat "$LAST_TRIP_FILE" 2>/dev/null) || last_trip=0
            fi
            last_trip="''${last_trip:-0}"
            age=$((now - last_trip))

            if [ "$last_trip" -gt 0 ] && [ "$age" -lt ${toString cfg.actionCooldownSeconds} ]; then
              echo "MEMORY EMERGENCY still active (''${reason}) but action cooldown active (''${age}s < ${toString cfg.actionCooldownSeconds}s) — skipping repeat stop"
            else
              echo "MEMORY EMERGENCY: ''${reason} — stopping ${
                lib.concatMapStringsSep " " (u: "'${u}'") cfg.sacrificeUnits
              } to prevent kernel freeze (2026-08-22 incident class). flm self-heals on next connection (1-3 min cold load)." >&2
              systemctl stop ${
                lib.concatMapStringsSep " " (u: "'${u}'") cfg.sacrificeUnits
              } 2>/dev/null || true
              echo "$now" > "$LAST_TRIP_FILE"
              tripped_total=$((tripped_total + 1))
              echo "$tripped_total" > "$COUNT_FILE"
              echo "MEMORY EMERGENCY action taken: sacrifice units stopped (trip #''${tripped_total})" >&2
            fi
          fi

          # last_trip_recent: 1 if a trip happened within the last 30 min —
          # the Gatus-visible "guard fired" signal (a raw counter would alert
          # forever after a single trip).
          last_trip_recent=0
          if [ -f "$LAST_TRIP_FILE" ]; then
            lt=$(cat "$LAST_TRIP_FILE" 2>/dev/null) || lt=0
            lt="''${lt:-0}"
            now=$(date +%s)
            if [ "$lt" -gt 0 ] && [ $((now - lt)) -lt 1800 ]; then
              last_trip_recent=1
            fi
          fi

          {
            echo "# HELP memory_emergency_guard_avail_percent MemAvailable as percent of MemTotal"
            echo "# TYPE memory_emergency_guard_avail_percent gauge"
            echo "memory_emergency_guard_avail_percent ''${avail_pct}"

            echo "# HELP memory_emergency_guard_zram_fill_percent zram swap fill percent (-1 when zram is absent)"
            echo "# TYPE memory_emergency_guard_zram_fill_percent gauge"
            echo "memory_emergency_guard_zram_fill_percent ''${zram_pct}"

            echo "# HELP memory_emergency_guard_tripped_total Total emergency stops performed since first deploy"
            echo "# TYPE memory_emergency_guard_tripped_total counter"
            echo "memory_emergency_guard_tripped_total ''${tripped_total}"

            echo "# HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise"
            echo "# TYPE memory_emergency_guard_last_trip_recent gauge"
            echo "memory_emergency_guard_last_trip_recent ''${last_trip_recent}"
          } > "$TMP"
          mv "$TMP" "$OUT"
        '';
      };
    in
    {
      options.services.memory-emergency-guard = {
        enable = lib.mkEnableOption "Memory emergency guard: stops the socket-activated LLM backend when MemAvailable/zram enter the pre-freeze zone (2026-08-22 incident class)";

        checkInterval = lib.mkOption {
          type = lib.types.str;
          default = "1min";
          description = "Timer interval for the guard check (the 2026-08-22 freeze went from PSI-CRITICAL alert to kernel death in ~40 min; 1 min leaves room to act)";
        };

        memAvailableThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "MemAvailable percentage below which the combined-threshold trip fires (requires zram fill above its threshold too)";
        };

        zramFillThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 92;
          description = "zram fill percentage at or above which the combined-threshold trip fires (100% makes shmem unevictable — the flm model trap)";
        };

        absoluteMemAvailableThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "MemAvailable percentage below which the guard trips unconditionally (freeze imminent regardless of zram)";
        };

        actionCooldownSeconds = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = "Minimum seconds between two emergency stop actions (prevents flapping while pressure drains)";
        };

        sacrificeUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "fastflowlm@*.service"
            "fastflowlm.service"
          ];
          description = "Units stopped when the guard trips. Must be self-healing (socket-activated or auto-restarting) — stopping them must degrade, not break. The fastflowlm socket stays up so the next connection cold-loads the model again";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.memory-emergency-guard = {
            description = "Memory emergency guard: sacrifice FastFlowLM before the thrash-freeze cliff (MemAvailable/zram thresholds)";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "64M";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                StateDirectory = "memory-emergency-guard";
                ExecStart = lib.getExe guardScript;
                ReadWritePaths = [ textfileDir ];
                # systemctl stop talks to PID 1 via /run/systemd/private —
                # works under harden{} (system-health collector precedent).
              }
            ];
          };

          timers.memory-emergency-guard = {
            description = "Run the memory emergency guard check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = cfg.checkInterval;
            };
          };
        };
      };
    };
}
