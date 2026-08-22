# Memory emergency guard.
#
# Converts the memory-thrash kernel-freeze death spiral into a controlled
# degradation by proactively sacrificing the socket-activated LLM backend
# (FastFlowLM, ~25 GB unevictable shmem once its mmap'd model is fully
# resident) when the system enters the pre-freeze zone.
#
# 2026-08-22 incident #1 (the class this guards): the machine froze solid at
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
# 2026-08-22 incident #2 (05:49, the SAME NIGHT, post-guard): the guard
# tripped 7x (03:32-04:53, MemAvail 5.4-9.7%, zram stuck at 98.6%) but the
# machine STILL froze at 05:49:56 — journal cut mid-write, no OOM dump, no
# shutdown. Three compounding design gaps, all fixed here:
#
#   1. THE FEEDBACK LOOP: stopping only fastflowlm.service leaves the
#      ACTIVATION SOCKET up by design ("self-heals on next connection").
#      Under the resulting alert storm every trip CAUSED gatus alerts →
#      PapDashboard ingest → the LLM insight enricher → a flm connection →
#      a fresh 21.6 GB cold load into a zram-full machine → re-trip ~10 min
#      later (flm's restart backoff cadence). The guard's own alerts woke
#      its sacrifice victim. Fix: trip ALSO stops fastflowlm.socket —
#      connections then fail FAST (ECONNREFUSED, enricher degrades
#      gracefully) instead of cold-loading the model; the guard restores
#      the socket once memory has recovered past a margin.
#
#   2. THE PSI BLIND SPOT: the final freeze was a refault-thrash death —
#      PSI some avg10 >50% (gatus "Memory pressure CRITICAL" fired at
#      05:49:39) while MemAvailable stayed ≥10% (51 GiB of page cache gave
#      the reclaim code headroom), so NEITHER trip zone fired at the 05:48:58
#      guard run. The kernel died of zram decompression CPU burn 17 s later.
#      Fix: Zone 3 trips on PSI some avg10 ≥40% AND zram ≥80% regardless of
#      MemAvailable.
#
#   3. CADENCE: the 60 s timer tick landed 2 s AFTER the kernel died.
#      Default interval is now 30 s (a 64M oneshot — cheap).
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
          SOCKET_UNITS="${lib.concatStringsSep " " cfg.socketUnits}"

          # Kernel data sources, env-overridable for the VM regression test
          # (tests/test-memory-emergency-guard.nix fakes them to exercise the
          # trip zones + restore state machine). Production always reads the
          # real files — the systemd unit never sets these.
          MEMINFO_SRC="''${MEMINFO_SRC:-/proc/meminfo}"
          ZRAM_MM_STAT_SRC="''${ZRAM_MM_STAT_SRC:-/sys/block/zram0/mm_stat}"
          ZRAM_DISKSIZE_SRC="''${ZRAM_DISKSIZE_SRC:-/sys/block/zram0/disksize}"
          PSI_SRC="''${PSI_SRC:-/proc/pressure/memory}"

          mem_available_kb=$(awk '/^MemAvailable:/ {print $2}' "$MEMINFO_SRC")
          mem_total_kb=$(awk '/^MemTotal:/ {print $2}' "$MEMINFO_SRC")
          mem_available_kb="''${mem_available_kb:-0}"
          mem_total_kb="''${mem_total_kb:-1}"

          avail_pct=$(awk -v a="$mem_available_kb" -v t="$mem_total_kb" 'BEGIN { printf "%.1f", a * 100.0 / t }')

          # zram fill: orig_data_size / disksize. -1 when zram is absent or
          # unreadable (treated as "not full" — the absolute threshold below
          # still catches zram-less emergencies).
          zram_pct=-1
          if [ -r "$ZRAM_MM_STAT_SRC" ] && [ -r "$ZRAM_DISKSIZE_SRC" ]; then
            zram_orig=$(awk '{print $1}' "$ZRAM_MM_STAT_SRC" 2>/dev/null) || zram_orig=0
            zram_disksize=$(cat "$ZRAM_DISKSIZE_SRC" 2>/dev/null) || zram_disksize=0
            zram_orig="''${zram_orig:-0}"
            zram_disksize="''${zram_disksize:-0}"
            if [ "$zram_disksize" -gt 0 ] 2>/dev/null; then
              zram_pct=$(awk -v o="$zram_orig" -v d="$zram_disksize" 'BEGIN { printf "%.1f", o * 100.0 / d }')
            fi
          fi

          # PSI memory stall (some avg10): the refault-thrash signal. During
          # the 05:49 freeze this was >50% while MemAvailable stayed >=10% —
          # the kernel was CPU-starved decompressing zram pages, not out of
          # pages. -1 when /proc/pressure/memory is unreadable.
          psi_some_avg10=-1
          if [ -r "$PSI_SRC" ]; then
            psi_some_avg10=$(awk '/^some avg10=/ { sub("avg10=","",$2); print $2; exit }' "$PSI_SRC" 2>/dev/null) || psi_some_avg10=-1
            psi_some_avg10="''${psi_some_avg10:--1}"
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
          # Zone 3 (thrash): PSI some avg10 high AND zram mostly full — the
          #   05:49 refault-freeze mode: MemAvailable can look healthy while
          #   the kernel dies of zram decompression CPU burn.
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
          elif
            awk -v p="$psi_some_avg10" 'BEGIN { exit !(p >= ${toString cfg.psiSomeThresholdPercent}) }' &&
              awk -v z="$zram_pct" 'BEGIN { exit !(z >= ${toString cfg.zramPsiFillThresholdPercent}) }'
          then
            trip=1
            reason="PSI some avg10=''${psi_some_avg10}% AND zram=''${zram_pct}% (refault-thrash freeze mode — MemAvailable stays high while the kernel starves on zram decompression)"
          fi

          # Last-trip age, computed for BOTH branches (trip gating + socket
          # restore gating below).
          now=$(date +%s)
          last_trip=0
          if [ -f "$LAST_TRIP_FILE" ]; then
            last_trip=$(cat "$LAST_TRIP_FILE" 2>/dev/null) || last_trip=0
          fi
          last_trip="''${last_trip:-0}"
          if [ "$last_trip" -gt 0 ]; then
            last_trip_age=$((now - last_trip))
          else
            last_trip_age=-1
          fi

          # Are any sacrifice sockets currently active? (restore candidate)
          sacrifice_socket_active=0
          if [ -n "$SOCKET_UNITS" ]; then
            for unit in $SOCKET_UNITS; do
              if systemctl is-active --quiet "$unit" 2>/dev/null; then
                sacrifice_socket_active=1
              fi
            done
          fi

          if [ "$trip" = "1" ]; then
            # Kill the ACTIVATION PATH FIRST, outside the cooldown: stopping
            # only the backend left the socket accepting, and every trip's
            # own gatus alerts re-woke flm via the PapDashboard insight
            # enricher — a 21.6 GB cold load into a zram-full machine
            # (2026-08-22 05:49 feedback loop). Socket stop is idempotent.
            if [ -n "$SOCKET_UNITS" ]; then
              systemctl stop $SOCKET_UNITS 2>/dev/null || true
            fi

            if [ "$last_trip" -gt 0 ] && [ "$last_trip_age" -lt ${toString cfg.actionCooldownSeconds} ]; then
              echo "MEMORY EMERGENCY still active (''${reason}) but action cooldown active (''${last_trip_age}s < ${toString cfg.actionCooldownSeconds}s) — socket stays down, skipping repeat service stop"
            else
              echo "MEMORY EMERGENCY: ''${reason} — stopping sockets + ${
                lib.concatMapStringsSep " " (u: "'${u}'") cfg.sacrificeUnits
              } to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore." >&2
              systemctl stop ${
                lib.concatMapStringsSep " " (u: "'${u}'") cfg.sacrificeUnits
              } 2>/dev/null || true
              echo "$now" > "$LAST_TRIP_FILE"
              tripped_total=$((tripped_total + 1))
              echo "$tripped_total" > "$COUNT_FILE"
              echo "MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #''${tripped_total})" >&2
            fi
          elif
            [ "$sacrifice_socket_active" = "0" ] &&
              [ -n "$SOCKET_UNITS" ] &&
              [ "$last_trip_age" -ge ${toString cfg.actionCooldownSeconds} ] &&
              awk -v p="$avail_pct" 'BEGIN { exit !(p >= ${toString cfg.restoreMemAvailableThresholdPercent}) }' &&
              awk -v z="$zram_pct" 'BEGIN { exit !(z >= 0 && z < ${toString cfg.zramFillThresholdPercent}) }' &&
              awk -v p="$psi_some_avg10" 'BEGIN { exit !(p >= 0 && p < ${toString cfg.restorePsiSomeThresholdPercent}) }'
          then
            # Self-heal: the emergency has drained (healthy margins on all
            # three axes + cooldown elapsed). Bring the socket back so flm
            # cold-loads on the next real client connection, and clear any
            # start-limit the repeated stops may have left behind.
            systemctl reset-failed ${
              lib.concatMapStringsSep " " (u: "'${u}'") cfg.sacrificeUnits
            } 2>/dev/null || true
            systemctl start $SOCKET_UNITS 2>/dev/null || true
            echo "MEMORY EMERGENCY cleared (MemAvailable=''${avail_pct}%, zram=''${zram_pct}%, PSI some avg10=''${psi_some_avg10}%, ''${last_trip_age}s since last trip) — sacrifice sockets restored" >&2
          fi

          # last_trip_recent: 1 if a trip happened within the last 30 min —
          # the Gatus-visible "guard fired" signal (a raw counter would alert
          # forever after a single trip).
          last_trip_recent=0
          if [ "$last_trip" -gt 0 ] && [ "$last_trip_age" -lt 1800 ]; then
            last_trip_recent=1
          fi

          {
            echo "# HELP memory_emergency_guard_avail_percent MemAvailable as percent of MemTotal"
            echo "# TYPE memory_emergency_guard_avail_percent gauge"
            echo "memory_emergency_guard_avail_percent ''${avail_pct}"

            echo "# HELP memory_emergency_guard_zram_fill_percent zram swap fill percent (-1 when zram is absent)"
            echo "# TYPE memory_emergency_guard_zram_fill_percent gauge"
            echo "memory_emergency_guard_zram_fill_percent ''${zram_pct}"

            echo "# HELP memory_emergency_guard_psi_some_avg10_percent PSI memory some avg10 stall percent (-1 when PSI is unreadable)"
            echo "# TYPE memory_emergency_guard_psi_some_avg10_percent gauge"
            echo "memory_emergency_guard_psi_some_avg10_percent ''${psi_some_avg10}"

            echo "# HELP memory_emergency_guard_sacrifice_socket_active 1 when any sacrifice socket is accepting, 0 when sacrificed"
            echo "# TYPE memory_emergency_guard_sacrifice_socket_active gauge"
            echo "memory_emergency_guard_sacrifice_socket_active ''${sacrifice_socket_active}"

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
          default = "30s";
          description = "Timer interval for the guard check. The 2026-08-22 05:49 freeze went from PSI-critical to kernel death in 17 s — the 60 s tick landed 2 s after the freeze; 30 s halves the blind window (a 64M oneshot is cheap to run twice as often)";
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

        psiSomeThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 40;
          description = "PSI memory some avg10 stall percentage at or above which the Zone 3 thrash trip fires (requires zram fill above zramPsiFillThresholdPercent). 2026-08-22 05:49: gatus PSI-critical (some avg10 >50%) fired 17 s before the kernel froze while MemAvailable stayed >=10%";
        };

        zramPsiFillThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 80;
          description = "zram fill percentage at or above which the Zone 3 thrash trip fires together with the PSI threshold (lower than the Zone 2 threshold: high PSI already proves the refault storm)";
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
          description = "Units stopped when the guard trips. Must be self-healing (socket-activated or auto-restarting) — stopping them must degrade, not break";
        };

        socketUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "fastflowlm.socket" ];
          description = "Activation sockets stopped when the guard trips and restored once memory recovers. Without this the socket keeps accepting: every trip's own gatus alerts woke the PapDashboard LLM enricher, which re-connected to flm and cold-loaded 21.6 GB into a zram-full machine (the 2026-08-22 05:49 feedback loop)";
        };

        restoreMemAvailableThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 15;
          description = "MemAvailable percentage at or above which (plus the other restore margins and the elapsed cooldown) the sacrifice sockets are started again";
        };

        restorePsiSomeThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "PSI some avg10 percentage below which the sacrifice sockets may be restored";
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
                # The textfile dir is a sticky 1777 shared directory. A stale
                # .prom owned by another user (e.g. a manual test run as the
                # desktop user) makes the atomic rename-over fail with EPERM
                # under an empty CapabilityBoundingSet — which would kill the
                # guard exactly when it is most needed. CAP_FOWNER +
                # CAP_DAC_OVERRIDE let the guard reclaim the file (same
                # pattern as bank-sync/buildcache textfile writers).
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
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
