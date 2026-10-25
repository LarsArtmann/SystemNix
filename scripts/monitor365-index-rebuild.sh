#!/usr/bin/env bash
# Rebuild monitor365-server DuckDB indexes OUT-OF-BAND with a raised
# memory_limit (2026-10-25 crash-loop class).
#
# Context: the 2026-10-25 api_key index-desync repair (see
# monitor365-apikey-desync-repair.sh) dropped every droppable index so the
# server's schema.sql could re-CREATE them fresh from coherent table data.
# But schema init runs INSIDE the server, whose DuckDB PRAGMA memory_limit is
# the upstream default "2GB" (config.rs:111, decimal 2e9 = 1.86 GiB — the
# "1.8 GiB/1.8 GiB used" in every OOM). Building 8 indexes over the 25 GB
# events table + 8 over domain_events needs more than that, so every boot
# died "schema init failed: Out of Memory Error" and the unit crash-looped
# (journal 2026-10-25 14:57-15:00, restart counters 2/3/4, ~2G read + 1.6G
# written per ~40s attempt under an active IO storm).
#
# Fix: quiesce server + watchdog (single-writer lock), then run the exact
# schema.sql CREATE INDEX statements through the duckdb CLI as the service
# user with memory_limit raised (default 6GB) and threads capped, followed by
# CHECKPOINT so the rebuilt indexes land in the main DB file. Boot then finds
# every index present (IF NOT EXISTS no-ops) and the server starts clean.
# The durable fix (server env MONITOR365_SERVER__MEMORY_LIMIT + cgroup
# headroom) lives in modules/nixos/services/monitor365.nix.
#
# Run:    scripts/monitor365-index-rebuild.sh          (self-elevates to root)
# Inspect-only (leaves server STOPPED, watchdog timer stopped):
#         MONITOR365_REBUILD_DRY_RUN=1 scripts/monitor365-index-rebuild.sh
# Override the schema source (default = prepared source of the 2026-10-25
# build; find the current one next to the server package build):
#         MONITOR365_SCHEMA_SQL=/path/to/crates/db/src/schema.sql
set -euo pipefail

SERVER="monitor365-server.service"
WATCHDOG_TIMER="monitor365-server-watchdog.timer"
SERVICE_USER="monitor365-server"
DB="/var/lib/monitor365-server/monitor365.duckdb"
HEALTH_URL="http://127.0.0.1:3001/health"
SCHEMA_SQL="${MONITOR365_SCHEMA_SQL:-/nix/store/1m00cf3k9n7c9f75hf9i1rs44xg0paf0-monitor365-prepared-source/crates/db/src/schema.sql}"
MEM_LIMIT="${MONITOR365_REBUILD_MEM:-6GB}"
THREADS="${MONITOR365_REBUILD_THREADS:-2}"

if [ "$(id -u)" -ne 0 ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "✗ needs root (service control + $DB) and no sudo was found"
    exit 1
  fi
  exec "$SUDO" env PATH="$PATH" \
    MONITOR365_REBUILD_DRY_RUN="${MONITOR365_REBUILD_DRY_RUN:-0}" \
    MONITOR365_SCHEMA_SQL="$SCHEMA_SQL" \
    MONITOR365_REBUILD_MEM="$MEM_LIMIT" \
    MONITOR365_REBUILD_THREADS="$THREADS" \
    bash "$0" "$@"
fi

echo "=== monitor365 out-of-band index rebuild (memory_limit=$MEM_LIMIT threads=$THREADS) ==="

if [ ! -f "$DB" ]; then
  echo "✗ DB not found: $DB"
  exit 1
fi
if [ ! -f "$SCHEMA_SQL" ]; then
  echo "✗ schema.sql not found: $SCHEMA_SQL"
  echo "  (set MONITOR365_SCHEMA_SQL to the prepared source's crates/db/src/schema.sql)"
  exit 1
fi

sql() { runuser -u "$SERVICE_USER" -- duckdb "$DB" -noheader -list -c "$1"; }

# Stop FIRST: the single-writer DuckDB lock must be free, and the watchdog
# timer's is-active check auto-STARTS an inactive server (backup-wrapper
# pattern, monitor365.nix ~line 208).
echo "--- pausing watchdog + stopping server"
if ! systemctl stop "$WATCHDOG_TIMER"; then
  echo "✗ WATCHDOG PAUSE FAILED — aborting before touching anything"
  exit 1
fi
systemctl stop "$SERVER" 2>/dev/null || true

lock_ok=0
for _ in $(seq 1 15); do
  if sql "SELECT 1;" >/dev/null 2>&1; then lock_ok=1; break; fi
  sleep 2
done
if [ "$lock_ok" != "1" ]; then
  echo "✗ DB lock still held after 30s — another monitor365-server process is alive (pgrep -af monitor365-server)"
  systemctl start "$WATCHDOG_TIMER" 2>/dev/null || true
  exit 6
fi

# Always restore services, even when the build fails mid-batch (the crash
# loop is the pre-existing state; never leave the control plane down cold).
restore() {
  systemctl reset-failed "$SERVER" 2>/dev/null || true
  systemctl start "$SERVER" 2>/dev/null || echo "✗ CRITICAL — server RESTART FAILED; start $SERVER manually"
  systemctl start "$WATCHDOG_TIMER" 2>/dev/null || true
}
trap restore EXIT TERM INT

BEFORE=$(sql "SELECT COUNT(*) FROM duckdb_indexes();")
echo "--- indexes present before: $BEFORE"
echo "--- missing (present in schema.sql, absent in DB):"
MISSING=0
while IFS= read -r line; do
  name=$(printf '%s' "$line" | sed -E 's/^CREATE (UNIQUE )?INDEX IF NOT EXISTS ([a-z_]+).*/\2/')
  if ! sql "SELECT 1 FROM duckdb_indexes() WHERE index_name = '$name';" | grep -q 1; then
    echo "  $name"
    MISSING=$((MISSING + 1))
  fi
done < <(grep -E '^CREATE (UNIQUE )?INDEX' "$SCHEMA_SQL")
echo "--- missing count: $MISSING"

if [ "${MONITOR365_REBUILD_DRY_RUN:-0}" = "1" ]; then
  echo "dry-run: no DDL executed; server + watchdog timer left STOPPED"
  echo "  (start manually if abandoning: systemctl start $SERVER $WATCHDOG_TIMER)"
  trap - EXIT TERM INT
  exit 0
fi

if [ "$MISSING" = "0" ]; then
  echo "--- nothing to rebuild; restarting server as-is"
  exit 0
fi

echo "--- building (this can take many minutes on the 25 GB events table; IO-storm box: be patient)"
DDL=$(grep -E '^CREATE (UNIQUE )?INDEX' "$SCHEMA_SQL" | tr -d '\r')
sql "SET memory_limit='$MEM_LIMIT'; SET threads=$THREADS; SET preserve_insertion_order=false;
$DDL
CHECKPOINT;"

AFTER=$(sql "SELECT COUNT(*) FROM duckdb_indexes();")
echo "--- indexes present after: $AFTER (was $BEFORE)"

echo "--- starting server + waiting for /health (up to 300s)"
systemctl reset-failed "$SERVER" 2>/dev/null || true
systemctl start "$SERVER"
ok=0
for _ in $(seq 1 150); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then ok=1; break; fi
  sleep 2
done

if [ "$ok" != "1" ]; then
  echo "✗ server did not pass /health within 300s — journal tail:"
  journalctl -u "$SERVER" -n 25 --no-pager || true
  exit 4
fi

echo "--- post-state"
sql "SELECT COUNT(*) FROM duckdb_indexes();"
journalctl -u "$SERVER" --since '-4 min' --no-pager | grep -Ei 'listening|schema|bootstrap|error' | tail -8 || true
echo "✓ monitor365-server healthy after out-of-band index rebuild — verify SSE device count in ~2 min (agent reconnect grace window, docs/services/monitor365.md)"
