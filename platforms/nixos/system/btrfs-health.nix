# BTRFS chunk allocation health monitoring + GC guard + proactive maintenance.
#
# Prevents the 2026-06-26 crash mode: nightly nix-gc timer fires metadata
# transactions on a filesystem with zero device-unallocated space → metadata
# ENOSPC → I/O deadlock → hardware watchdog reset.
#
# Five components:
#   1. btrfs-health.service — collects Prometheus metrics every 5 min
#   2. ExecStartPre guard on nix-gc + nix-build-cleanup — aborts reclamation
#      when device-unallocated is below an absolute GiB floor (metadata
#      churn headroom) or metadata utilization is >90% (the real ENOSPC
#      precursor). NEVER gate on a % of the device: 10% of a 723 GiB device
#      is 72 GiB — a level GC itself cannot restore (deleting files frees
#      extents WITHIN allocated chunks; only balance returns chunks), so a
#      %-gate deadlocks exactly when reclamation is most needed (live
#      2026-08-17..21: GC blocked 5 nights at 3% unalloc = 21 GiB idle).
#   3. btrfs-balance-metadata.timer — weekly metadata chunk consolidation
#   4. btrfs-balance-data.timer — weekly bounded data chunk consolidation
#   5. btrfs-emergency-reserve.service — 10 GiB fallocated recovery reserve
#
# See docs/crash-analysis-2026-06-26.md for full forensic analysis.
{
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

  textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
  stateDir = "/var/lib/btrfs-health";

  # GC needs a few GiB of device-unallocated for its metadata (extent-tree)
  # churn — the same 5 GiB floor the balance jobs in this module use.
  gcMinUnallocBytes = 5 * 1024 * 1024 * 1024;

  # Metadata utilization above this is the actual 2026-06-26 crash precursor:
  # block GC before metadata-pool ENOSPC, independent of unallocated bytes.
  gcMetaBlockPct = 90;

  # ── Shared parser: btrfs filesystem usage → KEY=VALUE pairs on stdout ──────
  # Used by both the metrics collector and the GC guard.
  # Always exits 0 (fail-open on errors). Diagnostics go to stderr.
  btrfsChunkCheck = pkgs.writeShellApplication {
    name = "btrfs-chunk-check";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.gawk
      pkgs.coreutils
    ];
    text = ''
      set -uo pipefail
      MOUNT="''${1:-/}"

      # --raw gives integer bytes directly — no IEC string parsing needed.
      USAGE=$(btrfs filesystem usage --raw "$MOUNT" 2>/dev/null) || {
        echo "btrfs-chunk-check: btrfs filesystem usage failed (not BTRFS or error) — failing open" >&2
        echo "DEVICE_SIZE_BYTES=0"
        echo "UNALLOC_BYTES=0"
        echo "ALLOC_BYTES=0"
        echo "META_SIZE_BYTES=0"
        echo "META_USED_BYTES=0"
        echo "UNALLOC_PCT=100"
        echo "ALLOC_PCT=0"
        echo "META_PCT=0"
        exit 0
      }

      DEVICE_SIZE_BYTES=$(echo "$USAGE" | awk '/Device size:/ {print $3}')
      UNALLOC_BYTES=$(echo "$USAGE" | awk '/Device unallocated:/ {print $3}')
      ALLOC_BYTES=$(echo "$USAGE" | awk '/Device allocated:/ {print $3}')

      if [ "$DEVICE_SIZE_BYTES" -eq 0 ] 2>/dev/null; then
        echo "btrfs-chunk-check: device size is zero or unparseable — failing open" >&2
        echo "DEVICE_SIZE_BYTES=0"
        echo "UNALLOC_BYTES=0"
        echo "ALLOC_BYTES=0"
        echo "META_SIZE_BYTES=0"
        echo "META_USED_BYTES=0"
        echo "UNALLOC_PCT=100"
        echo "ALLOC_PCT=0"
        echo "META_PCT=0"
        exit 0
      fi

      UNALLOC_PCT=$(( UNALLOC_BYTES * 100 / DEVICE_SIZE_BYTES ))
      ALLOC_PCT=$(( ALLOC_BYTES * 100 / DEVICE_SIZE_BYTES ))

      # Parse Metadata utilization (handles Metadata,DUP and Metadata,single).
      # match() with capture group extracts the integer value precisely.
      META_LINE=$(echo "$USAGE" | awk '/^Metadata/')
      META_SIZE_BYTES=0
      META_USED_BYTES=0
      META_PCT=0
      if [ -n "$META_LINE" ]; then
        META_SIZE_BYTES=$(echo "$META_LINE" | awk '{match($0, /Size:([0-9]+)/, a); print a[1]}')
        META_USED_BYTES=$(echo "$META_LINE" | awk '{match($0, /Used:([0-9]+)/, a); print a[1]}')
        if [ "$META_SIZE_BYTES" -gt 0 ] 2>/dev/null; then
          META_PCT=$(( META_USED_BYTES * 100 / META_SIZE_BYTES ))
        fi
      fi

      echo "DEVICE_SIZE_BYTES=$DEVICE_SIZE_BYTES"
      echo "UNALLOC_BYTES=$UNALLOC_BYTES"
      echo "ALLOC_BYTES=$ALLOC_BYTES"
      echo "META_SIZE_BYTES=$META_SIZE_BYTES"
      echo "META_USED_BYTES=$META_USED_BYTES"
      echo "UNALLOC_PCT=$UNALLOC_PCT"
      echo "ALLOC_PCT=$ALLOC_PCT"
      echo "META_PCT=$META_PCT"
    '';
  };

  # ── GC guard: exits 1 (block GC) if device-unallocated < threshold ──────────
  btrfsGcGuard = pkgs.writeShellApplication {
    name = "btrfs-gc-guard";
    runtimeInputs = [ btrfsChunkCheck ];
    text = ''
      set -uo pipefail
      # timeout: same ioctl-wedge class as the metrics collector (2026-08-31);
      # on timeout the UNALLOC_BYTES default of 0 makes the guard ABORT GC —
      # fail-closed (no GC on unknown chunk headroom), never a hang on nix-gc.
      eval "$(timeout 30 btrfs-chunk-check / 2>/dev/null)"
      : "''${UNALLOC_BYTES:=0}"
      : "''${UNALLOC_PCT:=100}"
      : "''${META_PCT:=0}"

      if [ "$UNALLOC_BYTES" -lt ${toString gcMinUnallocBytes} ]; then
        echo "BTRFS GUARD: ABORT — device-unallocated at ''${UNALLOC_BYTES} bytes (''${UNALLOC_PCT}%), below the ${toString gcMinUnallocBytes}-byte floor. GC metadata churn risks ENOSPC." >&2
        echo "Chunk-headroom recovery runbook (in order):" >&2
        echo "  1. Free extents: rm /btrfs-emergency-reserve (instant 10 GiB), let old btrbk snapshots expire" >&2
        echo "  2. Wait for QUIET: zram <80% AND low IO pressure. Balance during pressure FROZE the machine (2026-08-24)" >&2
        echo "  3. One bounded balance at idle IO: sudo ionice -c 3 btrfs balance start -dusage=5 -dlimit=2 /" >&2
        echo "  4. Re-provision the reserve: sudo systemctl start btrfs-emergency-reserve" >&2
        echo "NEVER 'btrfs balance start' without step 1: with no freed extents there is no relocation write room and the IO livelock freezes the box (2026-08-24 crash #3: manual balance at 0% unalloc + zram 85%, dead in 2.5 min)." >&2
        exit 1
      fi

      if [ "$META_PCT" -gt ${toString gcMetaBlockPct} ]; then
        echo "BTRFS GUARD: ABORT — metadata utilization at ''${META_PCT}% (> ${toString gcMetaBlockPct}%), the 2026-06-26 ENOSPC precursor. Run 'sudo systemctl start btrfs-balance-metadata.service' BEFORE reclaiming." >&2
        exit 1
      fi

      if [ "$META_PCT" -gt 85 ]; then
        echo "BTRFS GUARD: WARNING — metadata at ''${META_PCT}% — GC proceeding but may increase metadata pressure" >&2
      else
        echo "BTRFS GUARD: OK — device-unallocated=''${UNALLOC_PCT}% (''${UNALLOC_BYTES} bytes) metadata=''${META_PCT}%"
      fi
    '';
  };

  # ── Metrics collector: writes Prometheus textfile + logs state transitions ──
  btrfsHealthMetrics = pkgs.writeShellApplication {
    name = "btrfs-health-metrics";
    runtimeInputs = [
      btrfsChunkCheck
      pkgs.btrfs-progs
      pkgs.gawk
      pkgs.coreutils # stat for emergency reserve check
    ];
    text = ''
      set -uo pipefail
      METRICS_FILE="${textfileDir}/btrfs.prom"
      TMP_FILE="''${METRICS_FILE}.tmp"
      STATE_FILE="${stateDir}/state"

      mkdir -p "${textfileDir}" "${stateDir}"

      # timeout: `btrfs filesystem usage` is the same wedge-prone ioctl
      # family as scrub status (2026-08-31). Bounded here too — on timeout
      # the defaults below apply and the cycle degrades instead of hanging.
      eval "$(timeout 30 btrfs-chunk-check / 2>/dev/null)"
      : "''${DEVICE_SIZE_BYTES:=0}"
      : "''${UNALLOC_BYTES:=0}"
      : "''${ALLOC_BYTES:=0}"
      : "''${META_SIZE_BYTES:=0}"
      : "''${META_USED_BYTES:=0}"
      : "''${UNALLOC_PCT:=100}"
      : "''${ALLOC_PCT:=0}"
      : "''${META_PCT:=0}"

      # Health classification — single source of truth, used by BOTH the
      # metrics emit (btrfs_health_critical/warning booleans for Gatus, which
      # cannot compare numbers via pat()) and the state log below.
      # CRITICAL = metadata-ENOSPC precursor (2026-06-26 crash class):
      # device-unallocated <5% or metadata pool >90% used.
      classify_btrfs_health() {
        if [ "$UNALLOC_PCT" -lt 5 ] || [ "$META_PCT" -gt 90 ]; then
          echo CRITICAL
        elif [ "$UNALLOC_PCT" -lt 10 ] || [ "$META_PCT" -gt 85 ]; then
          echo WARNING
        else
          echo OK
        fi
      }

      {
        echo "# HELP btrfs_device_size_bytes Total BTRFS device size"
        echo "# TYPE btrfs_device_size_bytes gauge"
        echo "btrfs_device_size_bytes $DEVICE_SIZE_BYTES"
        echo "# HELP btrfs_device_unallocated_bytes Raw space not yet assigned to any chunk"
        echo "# TYPE btrfs_device_unallocated_bytes gauge"
        echo "btrfs_device_unallocated_bytes $UNALLOC_BYTES"
        echo "# HELP btrfs_device_unallocated_pct Percentage of device not allocated to chunks"
        echo "# TYPE btrfs_device_unallocated_pct gauge"
        echo "btrfs_device_unallocated_pct $UNALLOC_PCT"
        echo "# HELP btrfs_device_allocated_bytes Space already carved into chunks"
        echo "# TYPE btrfs_device_allocated_bytes gauge"
        echo "btrfs_device_allocated_bytes $ALLOC_BYTES"
        echo "# HELP btrfs_device_allocated_pct Percentage of device carved into chunks"
        echo "# TYPE btrfs_device_allocated_pct gauge"
        echo "btrfs_device_allocated_pct $ALLOC_PCT"
        echo "# HELP btrfs_metadata_size_bytes BTRFS metadata pool size"
        echo "# TYPE btrfs_metadata_size_bytes gauge"
        echo "btrfs_metadata_size_bytes $META_SIZE_BYTES"
        echo "# HELP btrfs_metadata_used_bytes BTRFS metadata pool used"
        echo "# TYPE btrfs_metadata_used_bytes gauge"
        echo "btrfs_metadata_used_bytes $META_USED_BYTES"
        echo "# HELP btrfs_metadata_utilization_pct BTRFS metadata pool utilization"
        echo "# TYPE btrfs_metadata_utilization_pct gauge"
        echo "btrfs_metadata_utilization_pct $META_PCT"

        # Composite health booleans for Gatus. Absence fails the pat()
        # conditions fail-closed (collector always writes the file).
        HEALTH_STATE=$(classify_btrfs_health)
        echo "# HELP btrfs_health_critical 1 = unalloc<5% or metadata>90% (metadata-ENOSPC precursor, 2026-06-26 crash class)"
        echo "# TYPE btrfs_health_critical gauge"
        if [ "$HEALTH_STATE" = "CRITICAL" ]; then
          echo "btrfs_health_critical 1"
        else
          echo "btrfs_health_critical 0"
        fi
        echo "# HELP btrfs_health_warning 1 = unalloc<10% or metadata>85%"
        echo "# TYPE btrfs_health_warning gauge"
        if [ "$HEALTH_STATE" = "OK" ]; then
          echo "btrfs_health_warning 0"
        else
          echo "btrfs_health_warning 1"
        fi

        # ── Scrub metrics ────────────────────────────────────────────────────
        # Status codes: 0=never 1=running 2=finished 3=interrupted/aborted
        echo "# HELP btrfs_scrub_status BTRFS scrub status (0=never 1=running 2=finished 3=interrupted)"
        echo "# TYPE btrfs_scrub_status gauge"
        echo "# HELP btrfs_scrub_errors_total Total errors found by last scrub"
        echo "# TYPE btrfs_scrub_errors_total gauge"
        echo "# HELP btrfs_scrub_duration_seconds Duration of last completed scrub in seconds"
        echo "# TYPE btrfs_scrub_duration_seconds gauge"
        echo "# HELP btrfs_scrub_error_free Composite: 1=all mounts finished+error-free 0=errors or not finished"
        echo "# TYPE btrfs_scrub_error_free gauge"
        scrub_total_errors=0
        scrub_all_finished=1
        for scrub_mnt in / /data; do
          scrub_out=$(timeout 30 btrfs scrub status "$scrub_mnt" 2>/dev/null) || continue
          scrub_err=$(echo "$scrub_out" | awk '
            /no errors found/ {e=0}
            /with [0-9]+ error/ {match($0, /with ([0-9]+)/, a); e=a[1]}
            /found [0-9]+ error/ {match($0, /found ([0-9]+)/, a); e=a[1]}
            /Error summary/ {
              getline
              if (match($0, /Uncorrectable:[[:space:]]*([0-9]+)/, a)) e=a[1]
            }
            END {print e+0}
          ')
          : "''${scrub_err:=0}"
          scrub_total_errors=$(( scrub_total_errors + scrub_err ))
          echo "$scrub_out" | awk -v mnt="$scrub_mnt" -v err="$scrub_err" '
            BEGIN {status=3; duration=0; never=0}
            /no scrub.*started/ {never=1}
            /still running|Status:.*running/ {status=1}
            /finished|Status:.*finished/ {if(status!=1) status=2}
            /interrupted|Status:.*interrupted/ {if(status!=1 && status!=2) status=3}
            /finished after/ {
              if (match($0, /([0-9]+):([0-9]+):([0-9]+)/, t)) duration=t[1]*3600+t[2]*60+t[3]
            }
            /Duration:/ {
              h=0; mn=0; sc=0
              if (match($0, /([0-9]+)h/, a)) h=a[1]
              if (match($0, /([0-9]+)m/, b)) mn=b[1]
              if (match($0, /([0-9]+)s/, c)) sc=c[1]
              if (h+mn+sc > 0) duration=h*3600+mn*60+sc
              else if (match($0, /([0-9]+):([0-9]+):([0-9]+)/, t)) duration=t[1]*3600+t[2]*60+t[3]
            }
            END {
              if (never) status=0
              print "btrfs_scrub_status{mount=\"" mnt "\"} " status
              print "btrfs_scrub_errors_total{mount=\"" mnt "\"} " err
              print "btrfs_scrub_duration_seconds{mount=\"" mnt "\"} " duration
            }
          '
          # Only consider error-free if the scrub actually FINISHED (status=2)
          if [ "$scrub_err" -eq 0 ] && echo "$scrub_out" | grep -q 'Status:.*finished'; then
            : # this mount is finished and error-free
          else
            scrub_all_finished=0
          fi
        done
        if [ "$scrub_all_finished" -eq 1 ] && [ "$scrub_total_errors" -eq 0 ]; then
          echo "btrfs_scrub_error_free 1"
        else
          echo "btrfs_scrub_error_free 0"
        fi

        # ── Emergency reserve ──────────────────────────────────────────────────
        echo "# HELP btrfs_emergency_reserve_present Emergency BTRFS space reserve file exists"
        echo "# TYPE btrfs_emergency_reserve_present gauge"
        echo "# HELP btrfs_emergency_reserve_bytes Size of emergency reserve file"
        echo "# TYPE btrfs_emergency_reserve_bytes gauge"
        if [ -f /btrfs-emergency-reserve ]; then
          echo "btrfs_emergency_reserve_present 1"
          echo "btrfs_emergency_reserve_bytes $(stat -c %s /btrfs-emergency-reserve 2>/dev/null || echo 0)"
        else
          echo "btrfs_emergency_reserve_present 0"
          echo "btrfs_emergency_reserve_bytes 0"
        fi
      } > "$TMP_FILE"
      mv "$TMP_FILE" "$METRICS_FILE"

      STATE=$(classify_btrfs_health)

      PREV_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
      echo "$STATE" > "$STATE_FILE"

      if [ "$STATE" != "$PREV_STATE" ]; then
        echo "BTRFS health: $PREV_STATE -> $STATE (unalloc=''${UNALLOC_PCT}% meta=''${META_PCT}% alloc=''${ALLOC_PCT}%)"
      else
        echo "BTRFS health: $STATE (unalloc=''${UNALLOC_PCT}% meta=''${META_PCT}%)"
      fi
    '';
  };

  # ── Metadata balance: consolidates underused metadata chunks ──────────────
  # Runs weekly. Metadata chunks are small (256 MiB each), so this is fast
  # and safe. Reclaims allocated-but-underused metadata space back to the
  # unallocated pool, preventing the metadata ENOSPC crash (2026-06-26).
  btrfsBalanceMetadata = pkgs.writeShellApplication {
    name = "btrfs-balance-metadata";
    runtimeInputs = [
      btrfsChunkCheck
      pkgs.btrfs-progs
      pkgs.gawk
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      set -uo pipefail
      MOUNT="${""}/"

      # Guard 1: skip if a balance is already running
      STATUS=$(btrfs balance status "$MOUNT" 2>&1)
      if ! echo "$STATUS" | grep -qi "No balance found"; then
        echo "btrfs-balance-metadata: balance already in progress, skipping"
        echo "$STATUS"
        exit 0
      fi

      # Guard 0: never balance under IO or zram pressure
      # (2026-08-24: a manual balance at 99% IO PSI + zram 85% froze the machine solid)
      PSI_IO_SOME=$(awk '/^some/ {for (i = 2; i <= NF; i++) if ($i ~ /^avg10=/) {sub(/^avg10=/, "", $i); printf "%d", $i; exit}}' /proc/pressure/io)
      : "''${PSI_IO_SOME:=0}"
      ZRAM_ORIG=$(awk '{print $1}' /sys/block/zram0/mm_stat 2>/dev/null)
      : "''${ZRAM_ORIG:=0}"
      ZRAM_SIZE=$(cat /sys/block/zram0/disksize 2>/dev/null)
      : "''${ZRAM_SIZE:=1}"
      ZRAM_PCT=$(( ZRAM_ORIG * 100 / ZRAM_SIZE ))
      if [ "$PSI_IO_SOME" -ge 20 ] || [ "$ZRAM_PCT" -ge 80 ]; then
        echo "btrfs-balance-metadata: skipping — IO PSI some avg10=''${PSI_IO_SOME}% (>=20) or zram ''${ZRAM_PCT}% full (>=80); balance during pressure froze the machine (2026-08-24)"
        exit 0
      fi

      # Guard 2: need >= 5 GiB unallocated as bounce room
      eval "$(btrfs-chunk-check "$MOUNT" 2>/dev/null)"
      : "''${UNALLOC_BYTES:=0}"
      : "''${META_PCT:=0}"
      if [ "$UNALLOC_BYTES" -lt 5368709120 ]; then
        echo "btrfs-balance-metadata: insufficient unallocated ($((UNALLOC_BYTES / 1073741824)) GiB < 5 GiB), skipping"
        echo "If chunk headroom is needed: rm /btrfs-emergency-reserve first (frees extents), then on a QUIET system run 'sudo ionice -c 3 btrfs balance start -dusage=5 -dlimit=2 /'. NEVER balance while IO pressure is high or zram >=80% (2026-08-24 freeze)"
        exit 0
      fi

      echo "btrfs-balance-metadata: starting -musage=50 on $MOUNT (meta at ''${META_PCT}%)"
      btrfs balance start -musage=50 "$MOUNT"
      echo "btrfs-balance-metadata: completed"
      btrfs-chunk-check "$MOUNT" 2>/dev/null
    '';
  };

  # ── Data balance: consolidates underused data chunks (bounded) ─────────────
  # Runs weekly. -dlimit caps the number of chunks rewritten per run, preventing
  # runaway IO. Each data chunk is up to 1 GiB; -dlimit=10 means <= 10 GiB
  # relocated per run. Staggered AFTER metadata balance.
  btrfsBalanceData = pkgs.writeShellApplication {
    name = "btrfs-balance-data";
    runtimeInputs = [
      btrfsChunkCheck
      pkgs.btrfs-progs
      pkgs.gawk
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      set -uo pipefail
      MOUNT="${""}/"

      # Guard 1: skip if a balance is already running
      STATUS=$(btrfs balance status "$MOUNT" 2>&1)
      if ! echo "$STATUS" | grep -qi "No balance found"; then
        echo "btrfs-balance-data: balance already in progress, skipping"
        echo "$STATUS"
        exit 0
      fi

      # Guard 0: never balance under IO or zram pressure
      # (2026-08-24: a manual balance at 99% IO PSI + zram 85% froze the machine solid)
      PSI_IO_SOME=$(awk '/^some/ {for (i = 2; i <= NF; i++) if ($i ~ /^avg10=/) {sub(/^avg10=/, "", $i); printf "%d", $i; exit}}' /proc/pressure/io)
      : "''${PSI_IO_SOME:=0}"
      ZRAM_ORIG=$(awk '{print $1}' /sys/block/zram0/mm_stat 2>/dev/null)
      : "''${ZRAM_ORIG:=0}"
      ZRAM_SIZE=$(cat /sys/block/zram0/disksize 2>/dev/null)
      : "''${ZRAM_SIZE:=1}"
      ZRAM_PCT=$(( ZRAM_ORIG * 100 / ZRAM_SIZE ))
      if [ "$PSI_IO_SOME" -ge 20 ] || [ "$ZRAM_PCT" -ge 80 ]; then
        echo "btrfs-balance-data: skipping — IO PSI some avg10=''${PSI_IO_SOME}% (>=20) or zram ''${ZRAM_PCT}% full (>=80); balance during pressure froze the machine (2026-08-24)"
        exit 0
      fi

      # Guard 2: need >= 10 GiB unallocated as bounce room
      eval "$(btrfs-chunk-check "$MOUNT" 2>/dev/null)"
      : "''${UNALLOC_BYTES:=0}"
      if [ "$UNALLOC_BYTES" -lt 10737418240 ]; then
        echo "btrfs-balance-data: insufficient unallocated ($((UNALLOC_BYTES / 1073741824)) GiB < 10 GiB), skipping"
        echo "If chunk headroom is needed: rm /btrfs-emergency-reserve first (frees extents), then on a QUIET system run 'sudo ionice -c 3 btrfs balance start -dusage=5 -dlimit=2 /'. NEVER balance while IO pressure is high or zram >=80% (2026-08-24 freeze)"
        exit 0
      fi

      echo "btrfs-balance-data: starting -dusage=50 -dlimit=10 on $MOUNT"
      btrfs balance start -dusage=50 -dlimit=10 "$MOUNT"
      echo "btrfs-balance-data: completed"
      btrfs-chunk-check "$MOUNT" 2>/dev/null
    '';
  };

  # ── Emergency reserve: pre-allocated space for BTRFS recovery ──────────────
  # A fallocated file at /btrfs-emergency-reserve. Delete it for instant free
  # space when you need to run balance, repair, or survive metadata ENOSPC.
  # The file is NOT recreated automatically after deletion. Re-provision with:
  #   sudo systemctl start btrfs-emergency-reserve
  btrfsEmergencyReserve = pkgs.writeShellApplication {
    name = "btrfs-emergency-reserve";
    runtimeInputs = [
      pkgs.util-linux # fallocate
      pkgs.coreutils # stat, df, chmod
      pkgs.gawk
    ];
    text = ''
      set -uo pipefail
      RESERVE_FILE="/btrfs-emergency-reserve"
      RESERVE_SIZE="10G"
      RESERVE_BYTES=$((10 * 1024 * 1024 * 1024))

      if [ -f "$RESERVE_FILE" ]; then
        CURRENT_SIZE=$(stat -c %s "$RESERVE_FILE" 2>/dev/null || echo 0)
        echo "btrfs-emergency-reserve: already exists ($((CURRENT_SIZE / 1073741824)) GiB)"
        exit 0
      fi

      # Check free space (reserve + 5 GiB headroom)
      FREE_BYTES=$(df -B1 / | awk 'NR==2 {print $4}')
      MIN_FREE=$((RESERVE_BYTES + 5368709120))
      if [ "$FREE_BYTES" -lt "$MIN_FREE" ]; then
        echo "btrfs-emergency-reserve: insufficient free space ($((FREE_BYTES / 1073741824)) GiB available, need $((MIN_FREE / 1073741824)) GiB)"
        exit 1
      fi

      echo "btrfs-emergency-reserve: creating ''${RESERVE_SIZE} reserve..."
      fallocate -l "$RESERVE_SIZE" "$RESERVE_FILE"
      chmod 644 "$RESERVE_FILE"
      echo "btrfs-emergency-reserve: created at $RESERVE_FILE"
      echo "  To free emergency space: rm $RESERVE_FILE"
      echo "  To re-provision after use: sudo systemctl start btrfs-emergency-reserve"
    '';
  };

  # ── Compsize metrics: compression ratio (runs hourly — compsize is slow) ────
  btrfsCompsizeMetrics = pkgs.writeShellApplication {
    name = "btrfs-compsize-metrics";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.compsize
      pkgs.gawk
      pkgs.coreutils
    ];
    text = ''
      set -uo pipefail
      METRICS_FILE="${textfileDir}/btrfs-compression.prom"
      TMP_FILE="''${METRICS_FILE}.tmp"

      mkdir -p "${textfileDir}"

      {
        echo "# HELP btrfs_compression_ratio_pct BTRFS compression ratio percentage"
        echo "# TYPE btrfs_compression_ratio_pct gauge"

        for comp_mnt in / /data; do
          compsize_out=$(compsize "$comp_mnt" 2>/dev/null) || continue
          echo "$compsize_out" | awk -v mnt="$comp_mnt" '
            /^TOTAL/ {
              pct = $2; gsub(/%/, "", pct)
              print "btrfs_compression_ratio_pct{mount=\"" mnt "\"} " pct
            }
          '
        done
      } > "$TMP_FILE"
      mv "$TMP_FILE" "$METRICS_FILE"
    '';
  };
in
{
  systemd = {
    # ── State directories ────────────────────────────────────────────────────
    tmpfiles.rules = [
      (mkStateDir stateDir "0755" "root" "root")
    ];

    services = {
      # ── Metrics collector service ───────────────────────────────────────────
      btrfs-health = {
        description = "BTRFS chunk allocation health monitor";
        inherit onFailure;
        startLimitBurst = 5;
        startLimitIntervalSec = 300;
        serviceConfig = lib.mkMerge [
          (serviceOneshotDefaults { })
          (harden {
            MemoryMax = "128M";
            CapabilityBoundingSet = "CAP_SYS_ADMIN";
            ReadWritePaths = [
              textfileDir
              stateDir
            ];
          })
          {
            Type = "oneshot";
            ExecStart = lib.getExe btrfsHealthMetrics;
            # 2026-08-31: `btrfs scrub status /` hung 1h+ with no unit-level
            # timeout (the global DefaultTimeoutStartSec was NOT live on the
            # deployed system — /etc/systemd/system.conf.d/ empty). Fail a
            # wedged collection into onFailure alerting instead of pinning
            # "activating" forever and staling btrfs.prom.
            TimeoutStartSec = "3min";
          }
        ];
      };

      # ── GC guard: ExecStartPre on nix-gc ────────────────────────────────────
      # Gates (fixed 2026-08-21, was the 5-night deadlock): absolute
      # device-unallocated floor (< 5 GiB) + metadata >90% hard block. The
      # old "<10% of device" gate demanded 72 GiB of chunk-level unalloc that
      # GC itself can never restore (only balance returns chunks). On abort
      # the guard exits 1 → systemd marks nix-gc as failed → OnFailure
      # triggers notify-failure (desktop notification). This PREVENTS the
      # 2026-06-26 crash: GC on a metadata-starved filesystem.
      nix-gc = {
        inherit onFailure;
        serviceConfig = {
          ExecStartPre = lib.getExe btrfsGcGuard;
        };
      };

      # ── Build cleanup guard ─────────────────────────────────────────────────
      # nix-build-cleanup does rm -rf on build sandboxes — also metadata-intensive.
      nix-build-cleanup = {
        serviceConfig = {
          ExecStartPre = lib.getExe btrfsGcGuard;
        };
      };

      # ── Compsize metrics collector (hourly — compsize walks the extent tree) ─
      btrfs-compsize = {
        description = "BTRFS compression ratio metrics collector";
        inherit onFailure;
        startLimitBurst = 5;
        startLimitIntervalSec = 300;
        serviceConfig = lib.mkMerge [
          (serviceOneshotDefaults { })
          (harden {
            MemoryMax = "2G";
            CapabilityBoundingSet = "CAP_SYS_ADMIN";
            ReadWritePaths = [ textfileDir ];
          })
          {
            Type = "oneshot";
            ExecStart = lib.getExe btrfsCompsizeMetrics;
            TimeoutStartSec = 120;
          }
        ];
      };

      # ── Metadata balance: weekly chunk consolidation ────────────────────────
      # Consolidates underused metadata chunks back to the unallocated pool.
      # Fast and safe: metadata chunks are 256 MiB each.
      btrfs-balance-metadata = {
        description = "BTRFS metadata balance (consolidate underused metadata chunks)";
        inherit onFailure;
        startLimitBurst = 1;
        startLimitIntervalSec = 86400;
        serviceConfig = lib.mkMerge [
          (serviceOneshotDefaults { })
          (harden {
            MemoryMax = "256M";
            CapabilityBoundingSet = "CAP_SYS_ADMIN";
            ProtectSystem = false;
          })
          {
            Type = "oneshot";
            ExecStart = lib.getExe btrfsBalanceMetadata;
            TimeoutStartSec = "1h";
          }
        ];
      };

      # ── Data balance: weekly bounded chunk consolidation ─────────────────────
      # -dlimit=10 caps relocation to <= 10 chunks per run. Staggered after
      # metadata balance (Mon 05:00, metadata runs at Mon 04:00).
      btrfs-balance-data = {
        description = "BTRFS data balance (consolidate underused data chunks, bounded)";
        inherit onFailure;
        startLimitBurst = 1;
        startLimitIntervalSec = 86400;
        serviceConfig = lib.mkMerge [
          (serviceOneshotDefaults { })
          (harden {
            MemoryMax = "256M";
            CapabilityBoundingSet = "CAP_SYS_ADMIN";
            ProtectSystem = false;
          })
          {
            Type = "oneshot";
            ExecStart = lib.getExe btrfsBalanceData;
            TimeoutStartSec = "2h";
          }
        ];
      };

      # ── Emergency reserve: pre-allocated space for recovery ──────────────────
      # Creates a 10 GiB fallocated file at /btrfs-emergency-reserve on boot.
      # Delete it for instant free space when you need to run balance, repair,
      # or survive metadata ENOSPC. Re-provision: systemctl start btrfs-emergency-reserve
      btrfs-emergency-reserve = {
        description = "BTRFS emergency space reserve (10 GiB fallocated file)";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = lib.mkMerge [
          (serviceOneshotDefaults { })
          (harden {
            MemoryMax = "64M";
            ProtectSystem = false;
          })
          {
            Type = "oneshot";
            ExecStart = lib.getExe btrfsEmergencyReserve;
            RemainAfterExit = true;
          }
        ];
      };
    };

    timers = {
      btrfs-health = {
        description = "BTRFS health check every 5 minutes";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "5min";
          AccuracySec = "30s";
        };
      };

      btrfs-compsize = {
        description = "BTRFS compression ratio check every 6 hours";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "6h";
          AccuracySec = "5m";
        };
      };

      # ── Balance timers (weekly, staggered before nix-gc at 00:00) ───────────────
      # Metadata at Mon 04:00, Data at Mon 05:00. Both guarded by chunk-check.
      btrfs-balance-metadata = {
        description = "Weekly BTRFS metadata balance (consolidate chunks)";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Mon 04:00";
          AccuracySec = "30m";
          Persistent = true;
        };
      };

      btrfs-balance-data = {
        description = "Weekly BTRFS data balance (bounded chunk consolidation)";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Mon 05:00";
          AccuracySec = "30m";
          Persistent = true;
        };
      };
    };
  };
}
