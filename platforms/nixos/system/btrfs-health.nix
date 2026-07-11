# BTRFS chunk allocation health monitoring + GC guard.
#
# Prevents the 2026-06-26 crash mode: nightly nix-gc timer fires metadata
# transactions on a filesystem with zero device-unallocated space → metadata
# ENOSPC → I/O deadlock → hardware watchdog reset.
#
# Two components:
#   1. btrfs-health.service — collects Prometheus metrics every 5 min
#   2. ExecStartPre guard on nix-gc + nix-build-cleanup — aborts reclamation
#      when device-unallocated < 10% (the deadlock threshold)
#
# See docs/crash-analysis-2026-06-26.md for full forensic analysis.
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
    mkStateDir
    ;

  textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
  stateDir = "/var/lib/btrfs-health";

  # Below this % of device-unallocated, GC is blocked (metadata ENOSPC risk).
  gcBlockThreshold = 10;

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
      eval "$(btrfs-chunk-check / 2>/dev/null)"
      : "''${UNALLOC_PCT:=100}"
      : "''${META_PCT:=0}"

      if [ "$UNALLOC_PCT" -lt ${toString gcBlockThreshold} ]; then
        echo "BTRFS GUARD: ABORT — device-unallocated at ''${UNALLOC_PCT}% (threshold ${toString gcBlockThreshold}%). GC would cause metadata ENOSPC deadlock." >&2
        echo "Free space first: grow partition, delete old snapshots, or run 'btrfs balance start -musage=50 /'" >&2
        exit 1
      fi

      if [ "$META_PCT" -gt 85 ]; then
        echo "BTRFS GUARD: WARNING — metadata at ''${META_PCT}% — GC proceeding but may increase metadata pressure" >&2
      else
        echo "BTRFS GUARD: OK — device-unallocated=''${UNALLOC_PCT}% metadata=''${META_PCT}%"
      fi
    '';
  };

  # ── Metrics collector: writes Prometheus textfile + logs state transitions ──
  btrfsHealthMetrics = pkgs.writeShellApplication {
    name = "btrfs-health-metrics";
    runtimeInputs = [
      btrfsChunkCheck
      pkgs.btrfs-progs
    ];
    text = ''
      set -uo pipefail
      METRICS_FILE="${textfileDir}/btrfs.prom"
      TMP_FILE="''${METRICS_FILE}.tmp"
      STATE_FILE="${stateDir}/state"

      mkdir -p "${textfileDir}" "${stateDir}"

      eval "$(btrfs-chunk-check / 2>/dev/null)"
      : "''${DEVICE_SIZE_BYTES:=0}"
      : "''${UNALLOC_BYTES:=0}"
      : "''${ALLOC_BYTES:=0}"
      : "''${META_SIZE_BYTES:=0}"
      : "''${META_USED_BYTES:=0}"
      : "''${UNALLOC_PCT:=100}"
      : "''${ALLOC_PCT:=0}"
      : "''${META_PCT:=0}"

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

        # ── Scrub metrics ────────────────────────────────────────────────────
        echo "# HELP btrfs_scrub_status BTRFS scrub status (0=never 1=running 2=finished)"
        echo "# TYPE btrfs_scrub_status gauge"
        echo "# HELP btrfs_scrub_errors_total Total errors found by last scrub"
        echo "# TYPE btrfs_scrub_errors_total gauge"
        echo "# HELP btrfs_scrub_duration_seconds Duration of last completed scrub in seconds"
        echo "# TYPE btrfs_scrub_duration_seconds gauge"
        echo "# HELP btrfs_scrub_error_free Composite: 1=all mounts error-free 0=errors found"
        echo "# TYPE btrfs_scrub_error_free gauge"
        scrub_total_errors=0
        for scrub_mnt in / /data; do
          scrub_out=$(btrfs scrub status "$scrub_mnt" 2>/dev/null) || continue
          scrub_err=$(echo "$scrub_out" | awk '
            /no errors found/ {e=0}
            /with [0-9]+ error/ {match($0, /with ([0-9]+)/, a); e=a[1]}
            /found [0-9]+ error/ {match($0, /found ([0-9]+)/, a); e=a[1]}
            END {print e+0}
          ')
          : "''${scrub_err:=0}"
          scrub_total_errors=$(( scrub_total_errors + scrub_err ))
          echo "$scrub_out" | awk -v mnt="$scrub_mnt" -v err="$scrub_err" '
            BEGIN {status=3; duration=0; never=0}
            /no scrub.*started/ {never=1}
            /still running|Status:.*running/ {status=1}
            /finished|Status:.*finished/ {if(status!=1) status=2}
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
        done
        if [ "$scrub_total_errors" -eq 0 ]; then
          echo "btrfs_scrub_error_free 1"
        else
          echo "btrfs_scrub_error_free 0"
        fi
      } > "$TMP_FILE"
      mv "$TMP_FILE" "$METRICS_FILE"

      if [ "$UNALLOC_PCT" -lt 5 ] || [ "$META_PCT" -gt 90 ]; then
        STATE="CRITICAL"
      elif [ "$UNALLOC_PCT" -lt 10 ] || [ "$META_PCT" -gt 85 ]; then
        STATE="WARNING"
      else
        STATE="OK"
      fi

      PREV_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
      echo "$STATE" > "$STATE_FILE"

      if [ "$STATE" != "$PREV_STATE" ]; then
        echo "BTRFS health: $PREV_STATE -> $STATE (unalloc=''${UNALLOC_PCT}% meta=''${META_PCT}% alloc=''${ALLOC_PCT}%)"
      else
        echo "BTRFS health: $STATE (unalloc=''${UNALLOC_PCT}% meta=''${META_PCT}%)"
      fi
    '';
  };

  # ── Compsize metrics: compression ratio (runs hourly — compsize is slow) ────
  btrfsCompsizeMetrics = pkgs.writeShellApplication {
    name = "btrfs-compsize-metrics";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.compsize
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
          }
        ];
      };

      # ── GC guard: ExecStartPre on nix-gc ────────────────────────────────────
      # If device-unallocated < 10%, the guard exits 1 → systemd marks nix-gc
      # as failed → OnFailure triggers notify-failure (desktop notification).
      # This PREVENTS the 2026-06-26 crash: GC on a metadata-starved filesystem.
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
        serviceConfig = lib.mkMerge [
          (serviceOneshotDefaults { })
          (harden {
            MemoryMax = "256M";
            CapabilityBoundingSet = "CAP_SYS_ADMIN";
            ReadWritePaths = [ textfileDir ];
          })
          {
            Type = "oneshot";
            ExecStart = lib.getExe btrfsCompsizeMetrics;
          }
        ];
      };
    };

    timers.btrfs-health = {
      description = "BTRFS health check every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "5min";
        AccuracySec = "30s";
      };
    };

    timers.btrfs-compsize = {
      description = "BTRFS compression ratio check every 6 hours";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "6h";
        AccuracySec = "5m";
      };
    };
  };
}
