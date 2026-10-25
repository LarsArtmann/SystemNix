#!/usr/bin/env bash
# monitor365-retention — nightly event retention + weekly VACUUM for the
# monitor365 DuckDB. Runs INSIDE the quiesced backup window (server
# stopped = the only single-writer slot), AFTER the export (that backup
# is the rollback copy). WARNs, never dies: the caller's EXIT trap
# restores the server either way.
#
# DuckDB never truncates the file after deletes — hence the weekly
# stamp-gated VACUUM, itself headroom-guarded (never ENOSPC the root at
# 03:00: the btrfs-gc-guard lesson).
#
# Env:
#   STATE_DIR          (required) monitor365-server state dir
#   RETENTION_DAYS     (default 90)   delete events older than this
#   VACUUM_INTERVAL_S  (default 604800 = 7d) stamp-gated VACUUM cadence
#   VACUUM_HEADROOM_B  (default 5368709120 = 5 GiB) free space required
#                                      on top of the current DB size
# Needs: duckdb + coreutils on PATH (writeShellApplication runtimeInputs
# in production; the fixture check provides them directly).
#
# Fixture: scripts/test-monitor365-retention.sh via
# checks.monitor365-retention-selftest — the 03:00 window must never be
# this script's first execution.
set -uo pipefail

STATE_DIR=${STATE_DIR:?STATE_DIR is required}
RETENTION_DAYS=${RETENTION_DAYS:-90}
VACUUM_INTERVAL_S=${VACUUM_INTERVAL_S:-604800}
VACUUM_HEADROOM_B=${VACUUM_HEADROOM_B:-5368709120}

# DuckDB session caps: this script runs inside the backup unit's cgroup
# (MemoryHigh 8G / MemoryMax 12G, monitor365.nix) but the duckdb CLI's
# default memory_limit is 80% of SYSTEM RAM — an uncapped DELETE/VACUUM on
# the 25 GB DB can push the whole unit past MemoryMax and get OOM-killed
# mid-fire (same class as the backup COPY's 2026-10-25 1.8 GiB OOM).
# threads=4 keeps per-thread allocation buffers inside the same budget.
DUCKDB_MEMORY_LIMIT=${DUCKDB_MEMORY_LIMIT:-6G}
DUCKDB_THREADS=${DUCKDB_THREADS:-4}
DUCK_SESSION="SET memory_limit='$DUCKDB_MEMORY_LIMIT'; SET threads=$DUCKDB_THREADS;"

DB="$STATE_DIR/monitor365.duckdb"
if [ ! -s "$DB" ]; then
  echo "monitor365-retention: DB missing or empty — nothing to do"
  exit 0
fi

CUTOFF=$(date -d "-$RETENTION_DAYS days" '+%Y-%m-%d %H:%M:%S')
BEFORE=$(duckdb "$DB" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events WHERE try_cast(timestamp AS TIMESTAMP) < TIMESTAMP '$CUTOFF';" 2>/dev/null || echo "?")
if duckdb "$DB" -c "$DUCK_SESSION DELETE FROM events WHERE try_cast(timestamp AS TIMESTAMP) < TIMESTAMP '$CUTOFF';" 2>/dev/null; then
  echo "monitor365-retention: deleted events older than $CUTOFF (boundary count: $BEFORE; window ${RETENTION_DAYS}d)"
else
  echo "monitor365-retention: WARNING — DELETE failed (DB left as-is; tonight's export is intact)"
fi
REMAINING=$(duckdb "$DB" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events;" 2>/dev/null || echo "?")
echo "monitor365-retention: rows remaining: $REMAINING"

STAMP="$STATE_DIR/.retention-vacuum-stamp"
NOW_S=$(date +%s)
LAST_S=$(cat "$STAMP" 2>/dev/null || echo 0)
if [ $((NOW_S - LAST_S)) -ge "$VACUUM_INTERVAL_S" ]; then
  DB_BYTES=$(stat -c %s "$DB")
  AVAIL_BYTES=$(df -B1 --output=avail "$STATE_DIR" | tail -1)
  NEEDED_BYTES=$((DB_BYTES + VACUUM_HEADROOM_B))
  if [ "$AVAIL_BYTES" -gt "$NEEDED_BYTES" ]; then
    if duckdb "$DB" -c "$DUCK_SESSION VACUUM;" 2>/dev/null; then
      date +%s >"$STAMP"
      echo "monitor365-retention: VACUUM done — file $DB_BYTES -> $(stat -c %s "$DB") bytes"
    else
      echo "monitor365-retention: WARNING — VACUUM failed (stamp NOT updated; retries next window)"
    fi
  else
    echo "monitor365-retention: WARNING — VACUUM skipped, headroom $AVAIL_BYTES < needed $NEEDED_BYTES; retries next window"
  fi
fi
