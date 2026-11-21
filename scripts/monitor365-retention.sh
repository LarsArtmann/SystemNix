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
#   RETENTION_BATCH_SIZE (default 5000000) rows per delete batch
#   RETENTION_MAX_BATCHES (default 8)   batches per fire (bounds the
#                                      quiesce window; next fire continues)
#   VACUUM_INTERVAL_S  (default 604800 = 7d) stamp-gated VACUUM cadence
#   VACUUM_HEADROOM_B  (default 5368709120 = 5 GiB) free space required
#                                      on top of the current DB size
#   RETENTION_COMPACT  (default 0)   one-shot stamp-gated rebuild-copy
#                                      compact (fires once, then never)
#
# duckdb stderr from failed statements is written IN FULL to
# $STATE_DIR/retention-stderr.log — the journal only carries a 5-line
# tail, which cut the OOM headline from the batch-20 failure evidence.
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

LOG_ERR() {
  # Full stderr capture to the state dir + a 5-line journal tail: the
  # journal line names the file, the file carries the headline line the
  # tail can cut (batch-20 lesson).
  printf '%s\n' "$1" >"$STATE_DIR/retention-stderr.log"
  printf '%s\n' "$1" | tail -n 5 | sed 's/^/monitor365-retention:   duckdb: /'
}

DB="$STATE_DIR/monitor365.duckdb"
if [ ! -s "$DB" ]; then
  echo "monitor365-retention: DB missing or empty — nothing to do"
  exit 0
fi

CUTOFF=$(date -d "-$RETENTION_DAYS days" '+%Y-%m-%d %H:%M:%S')
BEFORE=$(duckdb "$DB" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events WHERE try_cast(timestamp AS TIMESTAMP) < TIMESTAMP '$CUTOFF';" 2>/dev/null || echo "?")

# A single-transaction DELETE over the backlog era is unbounded: it OOM'd
# at 5.5 GiB (6G limit), still OOM'd with threads=2 +
# preserve_insertion_order=false, and SIGABRT'd at 9.3 GiB (10GB limit) —
# the working set scales with the limit because the whole delete set
# lives in one txn's undo structures (proven live 2026-11-11 on a
# reflink copy of the 39G export). Rowid-batched deletes of
# RETENTION_BATCH_SIZE rows fit at 6G (~4.5 min/batch); one fresh duckdb
# process per batch keeps allocator state from high-watering across
# batches (the index-rebuild lesson).
RETENTION_BATCH_SIZE=${RETENTION_BATCH_SIZE:-5000000}
RETENTION_MAX_BATCHES=${RETENTION_MAX_BATCHES:-8}
TOTAL_DELETED=0
BATCH_NO=0
DELETE_FAILED=0
while [ "$BATCH_NO" -lt "$RETENTION_MAX_BATCHES" ]; do
  BEFORE_BATCH=$(duckdb "$DB" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events;" 2>/dev/null || echo 0)
  ERR=$(duckdb "$DB" -c "$DUCK_SESSION DELETE FROM events WHERE rowid IN (SELECT rowid FROM events WHERE try_cast(timestamp AS TIMESTAMP) < TIMESTAMP '$CUTOFF' LIMIT $RETENTION_BATCH_SIZE);" 2>&1 >/dev/null) || DELETE_FAILED=1
  if [ "$DELETE_FAILED" -ne 0 ]; then
    echo "monitor365-retention: WARNING — DELETE batch $((BATCH_NO + 1)) failed (boundary count: $BEFORE; deleted so far: $TOTAL_DELETED; DB left consistent — the next fire continues); tonight's export is intact; full stderr: $STATE_DIR/retention-stderr.log"
    LOG_ERR "$ERR"
    break
  fi
  AFTER_BATCH=$(duckdb "$DB" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events;" 2>/dev/null || echo "$BEFORE_BATCH")
  DELETED=$((BEFORE_BATCH - AFTER_BATCH))
  if [ "$DELETED" -le 0 ]; then
    break
  fi
  BATCH_NO=$((BATCH_NO + 1))
  TOTAL_DELETED=$((TOTAL_DELETED + DELETED))
  echo "monitor365-retention: batch $BATCH_NO deleted $DELETED (total $TOTAL_DELETED)"
done
if [ "$DELETE_FAILED" -eq 0 ]; then
  echo "monitor365-retention: deleted events older than $CUTOFF (boundary count: $BEFORE; batches: $BATCH_NO; deleted: $TOTAL_DELETED; window ${RETENTION_DAYS}d)"
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
    if ERR=$(duckdb "$DB" -c "$DUCK_SESSION VACUUM;" 2>&1 >/dev/null); then
      date +%s >"$STAMP"
      echo "monitor365-retention: VACUUM done — file $DB_BYTES -> $(stat -c %s "$DB") bytes"
    else
      echo "monitor365-retention: WARNING — VACUUM failed (stamp NOT updated; retries next window); full stderr: $STATE_DIR/retention-stderr.log"
      LOG_ERR "$ERR"
    fi
  else
    echo "monitor365-retention: WARNING — VACUUM skipped, headroom $AVAIL_BYTES < needed $NEEDED_BYTES; retries next window"
  fi
fi

# ── One-shot rebuild-copy compact (RETENTION_COMPACT=1) ─────────────
# DuckDB never returns freed blocks to the OS: after a large convergence
# the file carries internal free space (13G file / 1.4M rows, 2026-11-12).
# Plain VACUUM reuses free blocks but never shrinks the file (proven live
# 2026-11-11: 0 bytes reclaimed). The rebuild-copy (ATTACH + COPY FROM
# DATABASE into a fresh file) lands the true floor; the proven 11G-shrink
# pattern from the 2026-11-11 session, stamp-gated so it runs ONCE.
# Count-gated: the swap only happens when the rebuilt row count equals the
# live count. Runs INSIDE the quiesce window by construction (called from
# the backup script after the export).
RETENTION_COMPACT=${RETENTION_COMPACT:-0}
COMPACT_STAMP="$STATE_DIR/.retention-compact-stamp"
if [ "$RETENTION_COMPACT" = "1" ] && [ ! -f "$COMPACT_STAMP" ]; then
  TMP="$DB.compact-tmp"
  rm -f "$TMP"
  COMPACT_OK=0
  if ERR=$(duckdb -c "$DUCK_SESSION ATTACH '$DB' AS src (READ_ONLY); ATTACH '$TMP' AS dst; COPY FROM DATABASE src TO dst;" 2>&1 >/dev/null); then
    LIVE_N=$(duckdb "$DB" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events;" 2>/dev/null || echo "?")
    NEW_N=$(duckdb "$TMP" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events;" 2>/dev/null || echo "?")
    if [ -n "$LIVE_N" ] && [ "$LIVE_N" != "?" ] && [ "$LIVE_N" = "$NEW_N" ]; then
      OWNER="$(stat -c '%u:%g' "$DB")"
      MODE="$(stat -c '%a' "$DB")"
      BEFORE_B=$(stat -c %s "$DB")
      mv -f "$TMP" "$DB"
      chown "$OWNER" "$DB"
      chmod "$MODE" "$DB"
      date +%s >"$COMPACT_STAMP"
      echo "monitor365-retention: compact done — file $BEFORE_B -> $(stat -c %s "$DB") bytes ($NEW_N rows preserved)"
      COMPACT_OK=1
    else
      echo "monitor365-retention: WARNING — compact count-gate FAILED (live $LIVE_N vs rebuilt $NEW_N) — original kept; diagnostics: $STATE_DIR/retention-stderr.log"
      LOG_ERR "count-gate mismatch at $(date -Is): live=$LIVE_N rebuilt=$NEW_N (rebuild exited 0; duckdb stderr was: ${ERR:-<empty>})"
    fi
  else
    echo "monitor365-retention: WARNING — compact rebuild failed — original kept, retries next window; full stderr: $STATE_DIR/retention-stderr.log"
    LOG_ERR "$ERR"
  fi
  [ "$COMPACT_OK" -eq 0 ] && rm -f "$TMP"
  echo "monitor365-retention: rows remaining: $(duckdb "$DB" -noheader -list -c "$DUCK_SESSION SELECT COUNT(*) FROM events;" 2>/dev/null || echo "?")"
fi
