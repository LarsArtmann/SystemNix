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
# 2026-08-31 16:34 freeze (incident #3, the Zone 4 motivation): the box
# froze with zram EMPTY (~0%), MemAvailable healthy and NO oomd kills —
# every existing zone was blinded. The driver was pure sustained memory-PSI
# stall (gatus "Memory pressure CRITICAL" flapped for ~2 h straight) caused
# by FOUR stacked full-disk readers on the single QLC NVMe: the btrbk-data
# 9-day-outage full re-send, weekly autoScrub on / AND /data (Persistent
# catch-up fired at boot), and flm cold-loading 21.6 GB four times (the
# v1.0.2 heap bug core-dumped every attempt; each restart re-paid the read,
# stretched from 2-5 min to 27-43 min under contention). By 16:33 even the
# guard itself and the PSI collector stopped completing their 30 s cycles;
# journal cut at 16:34:42 mid-entry; hard reset at 16:36. Zone 3's
# zram>=80% gate is what blinded it — this freeze class never touches zram.
# Fix: Zone 4 trips on SUSTAINED memory-PSI alone (some avg60 >= threshold).
# avg60 (a full-minute average of ALL tasks stalled on memory) resists the
# legitimate avg10 bursts a big nix build produces.
#
# 2026-08-24 crash #3 (the Zone 6 motivation): a manual btrfs balance at 0%
# chunk-unalloc, stacked on zram 85% + ClickHouse merge churn, drove I/O PSI
# to ~99% and the kernel froze in 2.5 min — a scheduler livelock with
# HEALTHY-looking memory gauges (docs/status/2026-08-24_08-00_crash3-*). The
# memory zones cannot see this class: the stall axis is I/O, not memory.
# Zone 6 trips on SUSTAINED io-pressure some avg60 — but ONLY when real disk
# activity corroborates it (per-disk io_ticks delta vs the previous guard
# run): D-state tasks parked on dead automounts produce phantom 80-99% I/O
# PSI with IDLE disks (the 2026-08-24 ln lesson), and tripping the guard on
# that phantom would needlessly sacrifice flm. On trip the guard stops the
# resumable churn sources (btrbk sends, btrfs balance + scrub) IN ADDITION
# to the flm sacrifice — btrbk resumes incrementally from its next timer
# fire, balance/scrub timers re-fire on schedule; nothing is lost.
#
# The guard closes that gap: stop the flm backend BEFORE the cliff. flm is
# the designated sacrifice (stateless, socket-activated, self-heals on the
# next connection with a 1-3 min cold load — OOMScoreAdjust=300 already
# encodes this philosophy for the kernel OOM killer; this guard acts
# earlier, deterministically, without waiting for global exhaustion).
#
# Metric freshness: the .prom file is rewritten on EVERY run (atomic
# mktemp+mv). If the guard itself dies, the file FREEZES at its last
# content — node_exporter keeps serving stale text, so a Gatus presence
# pat alone can NEVER see a dead guard (the 2026-09-15 gap). Two layers
# close it: this script stamps memory_emergency_guard_last_run_timestamp
# _seconds on every run, and system-health derives the
# system_memory_guard_metrics_fresh composite from the textfile mtime
# (a frozen file flips it to 0 and the Gatus check fires).
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
          # mktemp + trap per the repo textfile doctrine: the 1777 sticky dir
          # eventually collects foreign-owned leftovers, and a fixed $OUT.tmp
          # wedges the rename even for root without CAP_FOWNER (the caps
          # below defeat the sticky-bit rule, but the unique-tmp form needs
          # no caps and keeps the audit exception list empty).
          TMP=$(mktemp "''${OUT}.XXXXXX")
          chmod 644 "$TMP"
          trap 'rm -f "$TMP"' EXIT
          COUNT_FILE="${stateDir}/tripped.count"
          LAST_TRIP_FILE="${stateDir}/last-trip"
          RESTORED_COUNT_FILE="${stateDir}/restored.count"
          CHURN_STOPPED_FILE="${stateDir}/churn-stopped"
          CHURN_REARM_FILE="${stateDir}/churn-rearm.count"
          SOCKET_UNITS="${lib.concatStringsSep " " cfg.socketUnits}"
          MAX_RESTORES_PER_DAY=${toString cfg.maxRestoresPerDay}

          # Kernel data sources, env-overridable for the VM regression test
          # (tests/test-memory-emergency-guard.nix fakes them to exercise the
          # trip zones + restore state machine). Production always reads the
          # real files — the systemd unit never sets these.
          MEMINFO_SRC="''${MEMINFO_SRC:-/proc/meminfo}"
          ZRAM_MM_STAT_SRC="''${ZRAM_MM_STAT_SRC:-/sys/block/zram0/mm_stat}"
          ZRAM_DISKSIZE_SRC="''${ZRAM_DISKSIZE_SRC:-/sys/block/zram0/disksize}"
          PSI_SRC="''${PSI_SRC:-/proc/pressure/memory}"
          IO_PSI_SRC="''${IO_PSI_SRC:-/proc/pressure/io}"
          DISKSTATS_SRC="''${DISKSTATS_SRC:-/proc/diskstats}"

          now=$(date +%s)
          CHURN_UNITS="${lib.concatStringsSep " " cfg.ioChurnUnits}"

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

          # SUSTAINED memory stall (some avg60): the Zone 4 signal. avg10
          # flaps on legitimate bursts; a full minute with >=50% of tasks
          # stalled on memory is never healthy, whatever zram/MemAvailable
          # claim (2026-08-31: both looked healthy while the kernel died of
          # refault/writeback stalls against a saturated QLC NVMe).
          psi_some_avg60=-1
          if [ -r "$PSI_SRC" ]; then
            psi_some_avg60=$(awk '/^some/ { for (i = 1; i <= NF; i++) if ($i ~ /^avg60=/) { sub(/^avg60=/, "", $i); print $i; exit } }' "$PSI_SRC" 2>/dev/null) || psi_some_avg60=-1
            psi_some_avg60="''${psi_some_avg60:--1}"
          fi

          # SUSTAINED I/O stall (some avg60): the Zone 6 signal. Same logic
          # as Zone 4 but on the io axis — memory gauges stay healthy while
          # stacked full-disk readers livelock the scheduler (crash #3).
          io_psi_some_avg60=-1
          if [ -r "$IO_PSI_SRC" ]; then
            io_psi_some_avg60=$(awk '/^some/ { for (i = 1; i <= NF; i++) if ($i ~ /^avg60=/) { sub(/^avg60=/, "", $i); print $i; exit } }' "$IO_PSI_SRC" 2>/dev/null) || io_psi_some_avg60=-1
            io_psi_some_avg60="''${io_psi_some_avg60:--1}"
          fi

          tripped_total=0
          if [ -f "$COUNT_FILE" ]; then
            tripped_total=$(cat "$COUNT_FILE" 2>/dev/null) || tripped_total=0
          fi
          tripped_total="''${tripped_total:-0}"

          # Per-zone trip counters + trip history. trips_last_hour is the
          # CHURN signal: trip -> restore -> an alert-driven consumer re-wakes
          # flm (21.6 GB cold load) -> re-trip is a different failure class
          # from a single bounded trip (live 2026-09-02: the re-wake loop
          # re-filled memory within ~40 min per cycle).
          ZONE_FILE="${stateDir}/zone-counts"
          HISTORY_FILE="${stateDir}/trip-history"
          zone1=0
          zone2=0
          zone3=0
          zone4=0
          zone5=0
          zone6=0
          if [ -f "$ZONE_FILE" ]; then
            read -r zone1 zone2 zone3 zone4 zone5 zone6 < "$ZONE_FILE" 2>/dev/null || true
          fi
          zone1="''${zone1:-0}"
          zone2="''${zone2:-0}"
          zone3="''${zone3:-0}"
          zone4="''${zone4:-0}"
          zone5="''${zone5:-0}"
          zone6="''${zone6:-0}"

          # Episodic-stall leaky bucket (Zone 5): CALIBRATED AGAINST THE REAL
          # 2026-08-31 boot -1 telemetry — node_psi_memory_some_avg60 never
          # exceeded 3.93% in the whole crashed boot (SigNoz, 5-min samples;
          # last readable sample 0.49% at 16:30, four minutes before the
          # freeze). The pressure was EPISODIC avg10 spiking (>50% episodes
          # with recovery gaps — gatus CRITICAL flapped for ~2 h), and the
          # terminal collapse was minutes-fast with collectors already dead.
          # A 60s-average trip can NEVER see this class. Instead: count
          # episode runs (avg10 >= psiSomeThresholdPercent) with decay on
          # clean runs — the leading indicator that WAS present from 14:56.
          EPISODES_FILE="${stateDir}/psi-episodes"
          psi_episodes=0
          if [ -f "$EPISODES_FILE" ]; then
            psi_episodes=$(cat "$EPISODES_FILE" 2>/dev/null) || psi_episodes=0
          fi
          psi_episodes="''${psi_episodes:-0}"
          if awk -v p="$psi_some_avg10" 'BEGIN { exit !(p >= ${toString cfg.psiSomeThresholdPercent}) }'; then
            psi_episodes=$((psi_episodes + 1))
          elif [ "$psi_episodes" -gt 0 ]; then
            psi_episodes=$((psi_episodes - 1))
          fi
          echo "$psi_episodes" > "$EPISODES_FILE"

          # Disk-busy corroboration for Zone 6 (the phantom-PSI filter):
          # per-disk io_ticks (ms, /proc/diskstats field 13) delta vs the
          # PREVIOUS guard run, as percent busy, MAX across real disks
          # (whole sd*/nvme devices only — no partitions/loop/zram).
          # D-state tasks on dead automounts saturate io PSI with IDLE disks
          # (2026-08-24 ln class) — without this gate the guard would
          # sacrifice flm on a phantom. -1 when unknown (first run, elapsed
          # 0, or diskstats unreadable): treated as CORROBORATED (fail-safe
          # toward protecting the kernel; the phantom state is persistent,
          # so every run after the first has a known value).
          TICKS_STATE="${stateDir}/io-ticks"
          TICKS_EPOCH="${stateDir}/io-ticks.epoch"
          TICKS_CUR="${stateDir}/io-ticks.cur"
          disk_busy_max=-1
          cur_ticks=""
          if [ -r "$DISKSTATS_SRC" ]; then
            cur_ticks=$(awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+)$/ { print $3, $13 }' "$DISKSTATS_SRC" 2>/dev/null) || cur_ticks=""
          fi
          if [ -n "$cur_ticks" ]; then
            printf '%s\n' "$cur_ticks" > "$TICKS_CUR"
            prev_epoch=0
            if [ -f "$TICKS_EPOCH" ]; then
              prev_epoch=$(cat "$TICKS_EPOCH" 2>/dev/null) || prev_epoch=0
            fi
            prev_epoch="''${prev_epoch:-0}"
            elapsed=$((now - prev_epoch))
            if [ "$prev_epoch" -gt 0 ] && [ "$elapsed" -gt 0 ] && [ -f "$TICKS_STATE" ]; then
              disk_busy_max=$(awk -v e="$elapsed" '
                BEGIN { m = -1 }
                NR == FNR { ticks[$1] = $2; next }
                ($1 in ticks) {
                  pct = ($2 - ticks[$1]) / (e * 10.0)
                  if (pct > 100) pct = 100
                  if (pct > m) m = pct
                }
                END { print (m == -1 ? -1 : sprintf("%.1f", m)) }
              ' "$TICKS_STATE" "$TICKS_CUR" 2>/dev/null) || disk_busy_max=-1
              disk_busy_max="''${disk_busy_max:--1}"
            fi
            {
              cat "$TICKS_CUR"
            } > "$TICKS_STATE.tmp" 2>/dev/null && mv "$TICKS_STATE.tmp" "$TICKS_STATE" || true
            echo "$now" > "$TICKS_EPOCH"
          fi

          # --- Trip decision ---
          # Zone 1 (absolute): MemAvailable below the hard floor — freeze is
          #   imminent regardless of zram state (2026-08-22 22:25: ~4-5%).
          # Zone 2 (combined): low MemAvailable AND zram nearly full — the
          #   shmem-unevictable trap forming (flm model pages cannot evict
          #   once swap is exhausted).
          # Zone 3 (thrash): PSI some avg10 high AND zram mostly full — the
          #   05:49 refault-freeze mode: MemAvailable can look healthy while
          #   the kernel dies of zram decompression CPU burn.
          # Zone 4 (sustained stall): PSI some avg60 high ALONE — the
          #   slow-burn variant. CALIBRATION WARNING (2026-08-31 data): the
          #   actual 16:34 freeze NEVER lifted avg60 above ~4% — Zone 4
          #   covers a hypothetical slow burn, NOT the observed fast-collapse
          #   class; Zone 5 below is the one calibrated against the incident.
          # Zone 5 (episodic stall): the leaky bucket of avg10 episodes
          #   overflowed — the REAL 2026-08-31 16:34 signature (episodes
          #   every few minutes for 2 h, avg60 damped to single digits,
          #   terminal collapse in minutes).
          # Zone 6 (sustained I/O stall): io-pressure some avg60 high AND
          #   real disk activity corroborates (per-disk io_ticks delta — the
          #   phantom-PSI filter). The crash #3 class: memory zones blind,
          #   scheduler livelock from stacked full-disk readers.
          trip=0
          zone=0
          reason=""
          if awk -v p="$avail_pct" 'BEGIN { exit !(p < ${toString cfg.absoluteMemAvailableThresholdPercent}) }'; then
            trip=1
            zone=1
            reason="MemAvailable=''${avail_pct}% below absolute floor"
          elif
            awk -v p="$avail_pct" 'BEGIN { exit !(p < ${toString cfg.memAvailableThresholdPercent}) }' &&
              awk -v z="$zram_pct" 'BEGIN { exit !(z >= ${toString cfg.zramFillThresholdPercent}) }'
          then
            trip=1
            zone=2
            reason="MemAvailable=''${avail_pct}% AND zram=''${zram_pct}% (shmem-unevictable trap: model pages cannot evict with full zram)"
          elif
            awk -v p="$psi_some_avg10" 'BEGIN { exit !(p >= ${toString cfg.psiSomeThresholdPercent}) }' &&
              awk -v z="$zram_pct" 'BEGIN { exit !(z >= ${toString cfg.zramPsiFillThresholdPercent}) }'
          then
            trip=1
            zone=3
            reason="PSI some avg10=''${psi_some_avg10}% AND zram=''${zram_pct}% (refault-thrash freeze mode — MemAvailable stays high while the kernel starves on zram decompression)"
          elif
            awk -v p="$psi_some_avg60" 'BEGIN { exit !(p >= ${toString cfg.psiSomeAvg60ThresholdPercent}) }'
          then
            trip=1
            zone=4
            reason="PSI some avg60=''${psi_some_avg60}% sustained stall with zram=''${zram_pct}% and MemAvailable=''${avail_pct}% (slow-burn refault/writeback stall — the zram-gated zones never fire)"
          elif [ "$psi_episodes" -ge ${toString cfg.psiEpisodeTripCount} ]; then
            trip=1
            zone=5
            reason="PSI episodic stall: ''${psi_episodes} leaky-bucket episodes of avg10 >= ${toString cfg.psiSomeThresholdPercent}% (avg10=''${psi_some_avg10}%, avg60=''${psi_some_avg60}% stayed LOW — the calibrated 2026-08-31 16:34 signature: episodic spikes for ~2 h, then minutes-fast collapse the averages never saw)"
          elif
            awk -v p="$io_psi_some_avg60" 'BEGIN { exit !(p >= ${toString cfg.ioPsiSomeAvg60ThresholdPercent}) }' &&
              {
                [ "$disk_busy_max" = "-1" ] ||
                  awk -v b="$disk_busy_max" 'BEGIN { exit !(b >= ${toString cfg.ioDiskBusyThresholdPercent}) }'
              }
          then
            trip=1
            zone=6
            reason="I/O PSI some avg60=''${io_psi_some_avg60}% sustained (max disk busy ''${disk_busy_max}%, MemAvailable=''${avail_pct}% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)"
          fi

          # Last-trip age, computed for BOTH branches (trip gating + socket
          # restore gating below).
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

          # Are any sacrifice sockets currently active? (restore candidate).
          # An empty socketUnits list means NOTHING is managed, hence nothing
          # is sacrificed — report restored (=1), never "emergency active".
          sacrifice_socket_active=0
          if [ -z "$SOCKET_UNITS" ]; then
            sacrifice_socket_active=1
          else
            for unit in $SOCKET_UNITS; do
              if systemctl is-active --quiet "$unit" 2>/dev/null; then
                sacrifice_socket_active=1
              fi
            done
          fi

          # Daily restore budget (default 3): every restore re-arms the flm
          # cold load, and 2026-09-02 measured the re-wake loop (trip ->
          # restore -> enricher/PMA reconnect -> 21.6 GB cold load -> re-trip
          # within ~40 min). Past the cap the socket STAYS DOWN and the
          # restore_capped metric tells the bridge to hand the restart to a
          # human. 0 disables the cap (unlimited self-healing).
          restored_total=0
          if [ -f "$RESTORED_COUNT_FILE" ]; then
            restored_total=$(cat "$RESTORED_COUNT_FILE" 2>/dev/null) || restored_total=0
          fi
          restored_total="''${restored_total:-0}"
          today=$(date +%Y%m%d)
          RESTORE_TODAY_FILE="${stateDir}/restores-''${today}"
          restores_today=0
          if [ -f "$RESTORE_TODAY_FILE" ]; then
            restores_today=$(cat "$RESTORE_TODAY_FILE" 2>/dev/null) || restores_today=0
          fi
          restores_today="''${restores_today:-0}"
          restores_today_plus=$((restores_today + 1))
          restore_capped=0
          if
            [ "$sacrifice_socket_active" = "0" ] &&
              [ -n "$SOCKET_UNITS" ] &&
              [ "$MAX_RESTORES_PER_DAY" -gt 0 ] &&
              [ "$restores_today" -ge "$MAX_RESTORES_PER_DAY" ]
          then
            restore_capped=1
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
              # Zone 6's real mitigation: stop the resumable churn sources
              # (btrbk sends, balance, scrub). The post-storm drain path
              # below RE-ARMS them once sustained io PSI falls back under
              # the trip threshold — without that re-arm a mid-receive stop
              # cost the nightly pool send a full +24h (the timers had
              # already fired; the freshness threshold is 3 days, so a
              # second storm in the window would FAIL the backup check).
              # Stopping an inactive unit is a no-op.
              if [ -n "$CHURN_UNITS" ]; then
                # Record WHICH units were actually ACTIVE before the stop
                # (post-trip forensics must be a prom read, not a journal
                # dig — 2026-09-15) so the churn-stopped state file lists
                # only real stops, never no-ops. The file's first line is
                # the trip epoch; the drain-clear below removes it once
                # sustained io PSI falls back under the trip threshold.
                churn_stopped_now=""
                for cu in $CHURN_UNITS; do
                  if systemctl is-active --quiet "$cu" 2>/dev/null; then
                    churn_stopped_now="$churn_stopped_now $cu"
                  fi
                done
                if [ -n "$churn_stopped_now" ]; then
                  {
                    echo "$now"
                    # deliberate word splitting over the captured units
                    # shellcheck disable=SC2086
                    for cu in $churn_stopped_now; do
                      echo "$cu"
                    done
                  } > "$CHURN_STOPPED_FILE.tmp"
                  mv "$CHURN_STOPPED_FILE.tmp" "$CHURN_STOPPED_FILE"
                fi
                # deliberate word splitting over the unit list
                # shellcheck disable=SC2086
                systemctl stop $CHURN_UNITS 2>/dev/null || true
              fi
              # Attribution capture at trap time (2026-09-14): the trip says
              # "I/O stalled", not WHO stalled it. The forensics bundle
              # (cgroup io.stat + top offenders + D-state stacks) is the
              # evidence gate for every "X is the driver" claim. Transient
              # unit so the capture survives this oneshot's exit; best-effort
              # — a failed capture must never fail the trip itself.
              systemd-run --collect "${lib.getExe ioPsiForensics}" "zone''${zone}-trip" 2>/dev/null || true
              echo "$now" > "$LAST_TRIP_FILE"
              tripped_total=$((tripped_total + 1))
              echo "$tripped_total" > "$COUNT_FILE"
              case "$zone" in
                1) zone1=$((zone1 + 1)) ;;
                2) zone2=$((zone2 + 1)) ;;
                3) zone3=$((zone3 + 1)) ;;
                4) zone4=$((zone4 + 1)) ;;
                5) zone5=$((zone5 + 1)) ;;
                6) zone6=$((zone6 + 1)) ;;
              esac
              echo "$zone1 $zone2 $zone3 $zone4 $zone5 $zone6" > "$ZONE_FILE"
              echo "$now" >> "$HISTORY_FILE"
              echo "MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #''${tripped_total}, zone ''${zone})" >&2
            fi
          elif
            [ "$sacrifice_socket_active" = "0" ] &&
              [ -n "$SOCKET_UNITS" ] &&
              [ "$last_trip_age" -ge ${toString cfg.actionCooldownSeconds} ] &&
              awk -v p="$avail_pct" 'BEGIN { exit !(p >= ${toString cfg.restoreMemAvailableThresholdPercent}) }' &&
              awk -v p="$psi_some_avg10" 'BEGIN { exit !(p >= 0 && p < ${toString cfg.restorePsiSomeThresholdPercent}) }' &&
              awk -v p="$psi_some_avg60" 'BEGIN { exit !(p >= 0 && p < ${toString cfg.restorePsiSomeAvg60ThresholdPercent}) }' &&
              [ "$psi_episodes" -lt ${toString (cfg.psiEpisodeTripCount / 2)} ]
          then
            # Self-heal: the emergency has drained (pressure margins + episode
            # bucket + cooldown elapsed). NO zram gate, deliberately
            # (2026-09-02 live lockout): stopping the sacrifice CANNOT drain
            # zram — its 28 GiB of swapped pages belong to OTHER processes
            # and only fault back lazily, so a zram-gated restore kept the
            # socket down for hours on a machine with 53% MemAvailable and
            # 0.26% PSI while the sev1 overlay re-armed on the stale trip.
            # Relapse protection is the trip zones themselves: every zram
            # zone COMBINES zram with pressure, so a cold load that
            # re-deteriorates memory re-trips within one 30 s tick.
            # Bring the socket back so flm
            # cold-loads on the next real client connection, and clear any
            # start-limit the repeated stops may have left behind —
            # UNLESS the daily restore budget is spent, in which case the
            # socket stays down and restore_capped hands the restart to a
            # human (a capped state with healthy memory must never look
            # like a silently working self-heal loop).
            if [ "$restore_capped" = "1" ]; then
              echo "MEMORY EMERGENCY restore capped (''${restores_today} restores today >= $MAX_RESTORES_PER_DAY) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start $SOCKET_UNITS" >&2
            else
              systemctl reset-failed ${
                lib.concatMapStringsSep " " (u: "'${u}'") cfg.sacrificeUnits
              } 2>/dev/null || true
              systemctl start $SOCKET_UNITS 2>/dev/null || true
              restored_total=$((restored_total + 1))
              echo "$restored_total" > "$RESTORED_COUNT_FILE"
              echo "$((restores_today + 1))" > "$RESTORE_TODAY_FILE"
              echo "MEMORY EMERGENCY cleared (MemAvailable=''${avail_pct}%, zram=''${zram_pct}%, PSI some avg10=''${psi_some_avg10}%, PSI some avg60=''${psi_some_avg60}%, ''${last_trip_age}s since last trip, restore #''${restored_total} today: ''${restores_today_plus}) — sacrifice sockets restored" >&2
            fi
          fi

          # trips_last_hour: the churn gauge the bridge appends to its trip
          # page (>=2 = a consumer is re-waking flm after every restore).
          # Prune the history file to the window while we are here.
          trips_last_hour=0
          if [ -f "$HISTORY_FILE" ]; then
            cutoff=$((now - 3600))
            trips_last_hour=$(awk -v c="$cutoff" 'BEGIN { n = 0 } $1 >= c { n++ } END { print n }' "$HISTORY_FILE")
            trips_last_hour="''${trips_last_hour:-0}"
            awk -v c="$cutoff" '$1 >= c' "$HISTORY_FILE" > "''${HISTORY_FILE}.tmp" || true
            mv "''${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null || true
          fi

          # last_trip_recent: 1 if a trip happened within the last 30 min —
          # the Gatus-visible "guard fired" signal (a raw counter would alert
          # forever after a single trip).
          last_trip_recent=0
          if [ "$last_trip" -gt 0 ] && [ "$last_trip_age" -lt 1800 ]; then
            last_trip_recent=1
          fi

          # Churn-stop forensics state (written at trip action, see above):
          # emitted on every run while the drain window lasts; once
          # sustained io PSI falls back under the trip threshold the
          # stopped units are RE-ARMED (systemctl start, best-effort — each
          # unit's own pre-start guards decide whether it is safe to run
          # again, and a relapse re-trips within one 30 s tick) and the
          # state file is removed. The clear runs BEFORE the read so the
          # metrics vanish on the very run that observes the drain (no
          # stale final emission).
          churn_block=""
          churn_ts_line=""
          churn_rearm_total=$(cat "$CHURN_REARM_FILE" 2>/dev/null || echo 0)
          churn_rearm_total="''${churn_rearm_total:-0}"
          if [ -f "$CHURN_STOPPED_FILE" ] && [ "$io_psi_some_avg60" != "-1" ] && awk -v p="$io_psi_some_avg60" 'BEGIN { exit !(p < ${toString cfg.ioPsiSomeAvg60ThresholdPercent}) }'; then
            # deliberate word splitting over the recorded units
            # shellcheck disable=SC2086
            for cu in $(awk 'NR>1 && NF' "$CHURN_STOPPED_FILE" 2>/dev/null); do
              systemctl start "$cu" 2>/dev/null || true
            done
            churn_rearm_total=$((churn_rearm_total + 1))
            echo "$churn_rearm_total" > "$CHURN_REARM_FILE"
            echo "MEMORY EMERGENCY io drained (io PSI some avg60=''${io_psi_some_avg60}% < ${toString cfg.ioPsiSomeAvg60ThresholdPercent}%) — churn units re-armed (re-arm #''${churn_rearm_total})" >&2
            rm -f "$CHURN_STOPPED_FILE"
          fi
          if [ -f "$CHURN_STOPPED_FILE" ]; then
            churn_epoch=$(awk 'NR==1 { print; exit }' "$CHURN_STOPPED_FILE" 2>/dev/null) || churn_epoch=0
            churn_epoch="''${churn_epoch:-0}"
            if [ "$churn_epoch" -gt 0 ]; then
              churn_ts_line="memory_emergency_guard_churn_stopped_timestamp_seconds ''${churn_epoch}"
              churn_block=$(awk 'NR>1 && NF { print "memory_emergency_guard_churn_units_stopped{unit=\"" $0 "\"} 1" }' "$CHURN_STOPPED_FILE" 2>/dev/null) || churn_block=""
            fi
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

            echo "# HELP memory_emergency_guard_psi_some_avg60_percent PSI memory some avg60 stall percent — the sustained-stall (Zone 4) signal (-1 when PSI is unreadable)"
            echo "# TYPE memory_emergency_guard_psi_some_avg60_percent gauge"
            echo "memory_emergency_guard_psi_some_avg60_percent ''${psi_some_avg60}"

            echo "# HELP memory_emergency_guard_psi_episodes Leaky-bucket count of avg10 stall episodes (increment per episode run, decay per clean run) — the episodic-stall (Zone 5) signal calibrated against the 2026-08-31 freeze"
            echo "# TYPE memory_emergency_guard_psi_episodes gauge"
            echo "memory_emergency_guard_psi_episodes ''${psi_episodes}"

            echo "# HELP memory_emergency_guard_io_psi_some_avg60_percent PSI io some avg60 stall percent — the sustained-I/O-stall (Zone 6) signal (-1 when io PSI is unreadable)"
            echo "# TYPE memory_emergency_guard_io_psi_some_avg60_percent gauge"
            echo "memory_emergency_guard_io_psi_some_avg60_percent ''${io_psi_some_avg60}"

            echo "# HELP memory_emergency_guard_io_disk_busy_percent_max Max per-disk busy percent over the previous guard interval (io_ticks delta) — the Zone 6 phantom-PSI filter (-1 when unknown)"
            echo "# TYPE memory_emergency_guard_io_disk_busy_percent_max gauge"
            echo "memory_emergency_guard_io_disk_busy_percent_max ''${disk_busy_max}"

            echo "# HELP memory_emergency_guard_sacrifice_socket_active 1 when any sacrifice socket is accepting, 0 when sacrificed"
            echo "# TYPE memory_emergency_guard_sacrifice_socket_active gauge"
            echo "memory_emergency_guard_sacrifice_socket_active ''${sacrifice_socket_active}"

            echo "# HELP memory_emergency_guard_tripped_total Total emergency stops performed since first deploy"
            echo "# TYPE memory_emergency_guard_tripped_total counter"
            echo "memory_emergency_guard_tripped_total ''${tripped_total}"

            echo "# HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise"
            echo "# TYPE memory_emergency_guard_last_trip_recent gauge"
            echo "memory_emergency_guard_last_trip_recent ''${last_trip_recent}"

            echo "# HELP memory_emergency_guard_restored_total Total sacrifice-socket restores performed since first deploy"
            echo "# TYPE memory_emergency_guard_restored_total counter"
            echo "memory_emergency_guard_restored_total ''${restored_total}"

            echo "# HELP memory_emergency_guard_trips_last_hour Emergency stops in the last hour — >=2 is the CHURN class (trip -> restore -> consumer re-wakes flm -> re-trip)"
            echo "# TYPE memory_emergency_guard_trips_last_hour gauge"
            echo "memory_emergency_guard_trips_last_hour ''${trips_last_hour}"

            echo "# HELP memory_emergency_guard_restore_capped 1 when the socket is down AND the daily restore budget is spent — restart requires manual action (systemctl start <socket>)"
            echo "# TYPE memory_emergency_guard_restore_capped gauge"
            echo "memory_emergency_guard_restore_capped ''${restore_capped}"

            echo "# HELP memory_emergency_guard_churn_rearms_total Total churn-unit re-arms performed after io-PSI drain since first deploy"
            echo "# TYPE memory_emergency_guard_churn_rearms_total counter"
            echo "memory_emergency_guard_churn_rearms_total ''${churn_rearm_total}"

            echo "# HELP memory_emergency_guard_zone1_trips_total Trips from Zone 1 (MemAvailable below absolute floor)"
            echo "# TYPE memory_emergency_guard_zone1_trips_total counter"
            echo "memory_emergency_guard_zone1_trips_total ''${zone1}"

            echo "# HELP memory_emergency_guard_zone2_trips_total Trips from Zone 2 (low MemAvailable AND full zram — the shmem-unevictable trap)"
            echo "# TYPE memory_emergency_guard_zone2_trips_total counter"
            echo "memory_emergency_guard_zone2_trips_total ''${zone2}"

            echo "# HELP memory_emergency_guard_zone3_trips_total Trips from Zone 3 (PSI thrash AND mostly-full zram)"
            echo "# TYPE memory_emergency_guard_zone3_trips_total counter"
            echo "memory_emergency_guard_zone3_trips_total ''${zone3}"

            echo "# HELP memory_emergency_guard_zone4_trips_total Trips from Zone 4 (sustained PSI avg60 stall)"
            echo "# TYPE memory_emergency_guard_zone4_trips_total counter"
            echo "memory_emergency_guard_zone4_trips_total ''${zone4}"

            echo "# HELP memory_emergency_guard_zone5_trips_total Trips from Zone 5 (episodic avg10 leaky bucket — the calibrated 2026-08-31 signature)"
            echo "# TYPE memory_emergency_guard_zone5_trips_total counter"
            echo "memory_emergency_guard_zone5_trips_total ''${zone5}"

            echo "# HELP memory_emergency_guard_zone6_trips_total Trips from Zone 6 (sustained I/O PSI stall with disk-busy corroboration — the crash #3 class)"
            echo "# TYPE memory_emergency_guard_zone6_trips_total counter"
            echo "memory_emergency_guard_zone6_trips_total ''${zone6}"

            echo "# HELP memory_emergency_guard_last_run_timestamp_seconds Epoch of this guard run — freshness signal; a frozen value means the guard is DEAD (node_exporter serves the stale textfile forever, so presence pats alone can never see guard death — the 2026-09-15 gap)"
            echo "# TYPE memory_emergency_guard_last_run_timestamp_seconds gauge"
            echo "memory_emergency_guard_last_run_timestamp_seconds ''${now}"

            if [ -n "$churn_ts_line" ]; then
              echo "# HELP memory_emergency_guard_churn_stopped_timestamp_seconds Epoch of the last trip action that stopped resumable I/O churn units (absent when no churn-stop window is active)"
              echo "# TYPE memory_emergency_guard_churn_stopped_timestamp_seconds gauge"
              echo "$churn_ts_line"
              echo "# HELP memory_emergency_guard_churn_units_stopped Churn units the guard actually stopped (were active pre-stop) at the last trip action, emitted while the io-drain window lasts — post-trip forensics as a prom read"
              echo "# TYPE memory_emergency_guard_churn_units_stopped gauge"
              # churn_block may be empty (epoch line only) — never fail the
              # emission on a no-op test
              # shellcheck disable=SC2015
              [ -n "$churn_block" ] && printf '%s\n' "$churn_block" || true
            fi
          } > "$TMP"
          mv "$TMP" "$OUT"
        '';
      };

      # Attribution capture at trap time: per-cgroup io.stat, top offenders,
      # D-state stacks. Spawned as a TRANSIENT unit on every trip action —
      # the guard's own cgroup reaps backgrounded children when this oneshot
      # exits, so the capture cannot simply be `&`-backgrounded here. Source
      # of truth: scripts/io-psi-forensics.sh (also a flake app for manual
      # runs, so the guard and the operator capture identically).
      ioPsiForensics = pkgs.writeShellApplication {
        name = "io-psi-forensics";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.procps
          pkgs.gawk
          pkgs.gnugrep
          pkgs.findutils
          pkgs.systemd
        ];
        text = builtins.readFile ../../../scripts/io-psi-forensics.sh;
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

        psiSomeAvg60ThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 50;
          description = "SUSTAINED PSI memory some avg60 stall percentage at or above which the Zone 4 trip fires ALONE (no zram/MemAvailable gate). CALIBRATION WARNING: the real 2026-08-31 16:34 freeze never lifted avg60 above ~4% (episodic avg10 collapse) — this zone covers slow-burn stalls only; the episodic class is Zone 5's psiEpisodeTripCount";
        };

        psiEpisodeTripCount = lib.mkOption {
          type = lib.types.int;
          default = 8;
          description = "Leaky-bucket episode count at which the Zone 5 episodic-stall trip fires: +1 per guard run with PSI some avg10 >= psiSomeThresholdPercent, -1 per clean run (floor 0), trip at this count. Default 8 = net 4 min of episode-runs within the decay horizon (~8 min at 30s cadence). CALIBRATED against 2026-08-31 boot -1: avg10 episodes recurred every few minutes for ~2 h while avg60 stayed <=4% — this, not any average, was the observable pre-freeze signal (first episode 14:56, freeze 16:34)";
        };

        ioPsiSomeAvg60ThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 40;
          description = "SUSTAINED PSI io some avg60 stall percentage at or above which the Zone 6 trip fires (requires disk-busy corroboration unless unknown). The crash #3 class: a manual balance at 0% unalloc + zram 85% drove io PSI to ~99% and froze the kernel in 2.5 min while every memory gauge looked healthy";
        };

        ioDiskBusyThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 20;
          description = "Max per-disk busy percent (io_ticks delta vs the previous guard run) at or above which io PSI is treated as REAL for the Zone 6 trip. D-state tasks parked on dead automounts saturate io PSI with idle disks (the 2026-08-24 phantom-PSI class) — without this filter the guard would sacrifice flm on a phantom";
        };

        ioChurnUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "btrbk-root.service"
            "btrbk-data.service"
            "btrbk-pool.service"
            "btrfs-balance-metadata.service"
            "btrfs-balance-data.service"
            "btrfs-scrub--.service"
            "btrfs-scrub-data.service"
            "btrfs-scrub-mnt-pool.service"
          ];
          description = "Resumable I/O churn units stopped on ANY trip (Zone 6's real mitigation: crash #3 was stacked full-disk readers). RE-ARMED (systemctl start, best-effort) by the guard once sustained io PSI drains under the trip threshold — without the re-arm a mid-receive stop pushed the nightly btrbk send a full +24h (the timer had already fired), and a second storm in the 3-day freshness window FAILED the backup check (2026-09-16 23:00 trip #299 class). Each unit's own pre-start guards decide whether it is safe to run; an interrupted receive is healed by btrbk-pool-clean. Stopping an inactive unit is a no-op";
        };

        actionCooldownSeconds = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = "Minimum seconds between two emergency stop actions (prevents flapping while pressure drains)";
        };

        maxRestoresPerDay = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = "Daily budget of sacrifice-socket restores. Every restore re-arms the 21.6 GB flm cold load, and the 2026-09-02 re-wake loop (trip -> restore -> enricher/PMA reconnect -> re-trip within ~40 min) turned unlimited self-healing into an I/O churn engine. Past the cap the socket STAYS DOWN (restore_capped metric = 1) and restart becomes a manual human action; 0 disables the cap";
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
          description = "MemAvailable percentage at or above which (plus the PSI/episode restore margins and the elapsed cooldown) the sacrifice sockets are started again. zram fill is deliberately NOT a restore gate — stopping the sacrifice cannot drain zram (its pages belong to other processes), so a zram-gated restore locks the socket down long after the emergency has passed (2026-09-02 lockout)";
        };

        restorePsiSomeThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "PSI some avg10 percentage below which the sacrifice sockets may be restored";
        };

        restorePsiSomeAvg60ThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "PSI some avg60 percentage below which the sacrifice sockets may be restored (the sustained-stall axis must have fully drained — restoring into a lingering avg60 stall would immediately re-trip)";
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
