#!/usr/bin/env bash
# Repair monitor365-server after the 2026-10-25 13:27 index-desync class:
# an unclean deploy-restart + the heal script's WAL removal desynced the
# tenants table from idx_tenants_api_key (schema.sql:536, UNIQUE on
# tenants.api_key). Every bootstrap's rotate (UPDATE tenants SET api_key =
# <same hash>, tenant.rs:302) then dies "Duplicate key api_key: …" because
# DuckDB's UPDATE = delete+re-insert collides with the stale index entry.
#
# Fix: drop EVERY droppable index in the DB (duckdb_indexes()), CHECKPOINT,
# and let the server's own schema.sql (CREATE ... IF NOT EXISTS everywhere)
# rebuild them fresh from coherent table data at boot. A plain UPDATE or a
# single-index DROP cannot win: the WAL deletion desynced MANY indexes
# (live 2026-10-25: tenants.api_key + the alert-projection table), and even
# the indexes' own delete paths fail ("Failed to delete all rows from index.
# Only deleted 0 out of N rows"). Constraint-owned (PRIMARY KEY/UNIQUE
# constraint) indexes are not DROP-able and are reported as skipped.
# Zero monitoring-data loss; the agent key VALUE never changes.
#
# Run: scripts/monitor365-apikey-desync-repair.sh   (self-elevates to root)
# Inspect-only: MONITOR365_REPAIR_DRY_RUN=1
set -euo pipefail

SERVER="monitor365-server.service"
WATCHDOG_TIMER="monitor365-server-watchdog.timer"
SERVICE_USER="monitor365-server"
DB="/var/lib/monitor365-server/monitor365.duckdb"
HEALTH_URL="http://127.0.0.1:3001/health"

if [ "$(id -u)" -ne 0 ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "✗ needs root (service control + $DB) and no sudo was found"
    exit 1
  fi
  exec "$SUDO" env PATH="$PATH" MONITOR365_REPAIR_DRY_RUN="${MONITOR365_REPAIR_DRY_RUN:-0}" bash "$0" "$@"
fi

echo "=== monitor365 api_key index-desync repair ==="

if [ ! -f "$DB" ]; then
  echo "✗ DB not found: $DB"
  exit 1
fi

sql() { runuser -u "$SERVICE_USER" -- duckdb "$DB" -noheader -list -c "$1"; }

# Stop FIRST (pre-state queries need the DuckDB single-writer lock; the
# crash-cycling server holds it between restart attempts).
echo "--- pausing watchdog + ensuring server stopped"
systemctl stop "$WATCHDOG_TIMER" 2>/dev/null || true
systemctl stop "$SERVER" 2>/dev/null || true

lock_ok=0
for _ in $(seq 1 15); do
  if sql "SELECT 1;" >/dev/null 2>&1; then
    lock_ok=1
    break
  fi
  sleep 2
done
if [ "$lock_ok" != "1" ]; then
  echo "✗ DB lock still held after 30s — another monitor365-server process is alive (pgrep -af monitor365-server)"
  exit 6
fi

echo "--- pre-state"
TENANTS=$(sql "SELECT COUNT(*) FROM tenants;" || echo "ERR")
DEVICES=$(sql "SELECT COUNT(*) FROM devices;" || echo "ERR")
EVENTS=$(sql "SELECT COUNT(*) FROM domain_events;" || echo "ERR")
echo "tenants=$TENANTS devices=$DEVICES domain_events=$EVENTS"
sql "SELECT id, api_key, status FROM tenants;"

if [ "$TENANTS" = "0" ] || [ "$TENANTS" = "ERR" ]; then
  echo "✗ tenants table empty/unreadable ($TENANTS) — not the 2026-10-25 desync state; see docs/services/monitor365.md rollback ladder"
  exit 2
fi
if [ "$EVENTS" = "ERR" ]; then
  echo "✗ domain_events unreadable — DB integrity problem beyond this repair"
  exit 3
fi

if [ "${MONITOR365_REPAIR_DRY_RUN:-0}" = "1" ]; then
  echo "dry-run: would DROP every droppable index + CHECKPOINT — then restart $SERVER (schema.sql re-creates indexes at boot; no row data changes)"
  systemctl start "$WATCHDOG_TIMER" 2>/dev/null || true
  systemctl start "$SERVER" 2>/dev/null || true
  exit 0
fi

echo "--- rebuilding ALL indexes (DROP every droppable + CHECKPOINT; server schema.sql re-CREATEs them fresh at boot)"
INDEXES=$(sql "SELECT index_name FROM duckdb_indexes() ORDER BY index_name;" || echo "ERR")
if [ "$INDEXES" = "ERR" ]; then
  echo "✗ cannot enumerate indexes (duckdb_indexes() failed)"
  exit 5
fi
echo "dropping: $INDEXES"
for idx in $INDEXES; do
  sql "DROP INDEX IF EXISTS \"$idx\";" || echo "  (skip $idx — constraint-owned, not droppable)"
done
sql "CHECKPOINT;"
sql "SELECT index_name FROM duckdb_indexes() ORDER BY index_name;" || true

echo "--- resetting failed state + starting server"
systemctl reset-failed "$SERVER" 2>/dev/null || true
systemctl start "$SERVER"

echo "--- waiting for /health (up to 120s)"
ok=0
for _ in $(seq 1 60); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 2
done

echo "--- resuming watchdog timer"
systemctl start "$WATCHDOG_TIMER" 2>/dev/null || true

if [ "$ok" != "1" ]; then
  echo "✗ server did not pass /health within 120s — journal tail:"
  journalctl -u "$SERVER" -n 25 --no-pager || true
  exit 4
fi

echo "--- post-state"
sql "SELECT id, api_key FROM tenants;"
journalctl -u "$SERVER" --since '-3 min' --no-pager | grep -E 'Bootstrap|re-synced|provisioned|server listening|listening' | tail -8 || true
echo "✓ monitor365-server healthy after api_key index-desync repair — verify SSE device count in ~2 min (agent reconnect grace window, docs/services/monitor365.md)"
