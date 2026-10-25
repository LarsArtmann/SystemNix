#!/usr/bin/env bash
# Repair monitor365-server's tenant projection after a WAL-loss half-state
# (2026-10-25 13:27 class): an unclean deploy-restart left
# projection_checkpoints ahead of the tenants rows it had not checkpointed —
# the heal script's WAL removal reverted the tenants table while the
# api_keys row (and the checkpoint) stayed. Bootstrap then takes the
# fresh-DB provisioning path and dies on the api_key UNIQUE constraint.
#
# Fix: mark the tenant projection dirty (is_dirty = TRUE) — the server's
# OWN check_and_rebuild_projections() then rebuilds it from the (small)
# CQRS event store on next start (server_cmd.rs Phase 7.6), bootstrap takes
# the existing-tenant rotate path, zero monitoring-data loss.
#
# Run: sudo scripts/monitor365-projection-repair.sh   (or bare — self-elevates)
# Safety: verify-only mode with MONITOR365_REPAIR_DRY_RUN=1 (inspects, no writes)
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
  exec "$SUDO" env PATH="$PATH" bash "$0" "$@"
fi

echo "=== monitor365 projection repair (tenant is_dirty → replay) ==="

if [ ! -f "$DB" ]; then
  echo "✗ DB not found: $DB"
  exit 1
fi

sql() { runuser -u "$SERVICE_USER" -- duckdb "$DB" -noheader -list -c "$1"; }

echo "--- pre-state"
TENANTS=$(sql "SELECT COUNT(*) FROM tenants;" || echo "ERR")
DEVICES=$(sql "SELECT COUNT(*) FROM devices;" || echo "ERR")
EVENTS=$(sql "SELECT COUNT(*) FROM domain_events;" || echo "ERR")
echo "tenants=$TENANTS devices=$DEVICES domain_events=$EVENTS"
sql "SELECT projection_name, tenant_id, last_sequence, is_dirty FROM projection_checkpoints ORDER BY projection_name;"

if [ "$TENANTS" != "0" ]; then
  echo "✗ tenants table is NOT empty ($TENANTS rows) — this is not the 2026-10-25 half-state; refusing to touch a healthy DB"
  exit 2
fi
if [ "$EVENTS" = "0" ] || [ "$EVENTS" = "ERR" ]; then
  echo "✗ domain_events empty/unreadable ($EVENTS) — nothing to replay from; restore from backup instead (docs/services/monitor365.md rollback ladder)"
  exit 3
fi

if [ "${MONITOR365_REPAIR_DRY_RUN:-0}" = "1" ]; then
  echo "dry-run: would set is_dirty = TRUE on the tenant projection and restart $SERVER"
  exit 0
fi

echo "--- pausing watchdog + ensuring server stopped"
systemctl stop "$WATCHDOG_TIMER" 2>/dev/null || true
systemctl stop "$SERVER" 2>/dev/null || true

echo "--- marking tenant projection dirty"
sql "UPDATE projection_checkpoints SET is_dirty = TRUE, updated_at = now() WHERE projection_name = 'tenant';"
sql "SELECT projection_name, tenant_id, last_sequence, is_dirty FROM projection_checkpoints WHERE projection_name = 'tenant';"

echo "--- resetting failed state + starting server"
systemctl reset-failed "$SERVER" 2>/dev/null || true
systemctl start "$SERVER"

echo "--- waiting for /health (up to 120s)"
ok=0
for _ in $(seq 1 60); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then ok=1; break; fi
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
sql "SELECT COUNT(*) AS tenants FROM tenants;"
journalctl -u "$SERVER" --since '-3 min' --no-pager | grep -E 'Dirty projection|rebuilding|Bootstrap|re-synced|provisioned' | tail -8 || true
echo "✓ monitor365-server healthy after projection replay — verify SSE device count in ~2 min (agent reconnect grace window, docs/services/monitor365.md)"
