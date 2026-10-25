#!/usr/bin/env bash
# Force-fire one monitor365 backup + retention window and capture the
# evidence the SUPERB plan's F19/F20 proofs need (2026-10-25):
#
#   F19: backup unit GREEN with the memory_limit actually applied — the
#        03:00 fire OOM'd at DuckDB's decimal-2GB default because the
#        wrapper's MONITOR365_SERVER__MEMORY_LIMIT="6G" failed upstream's
#        <digits>(KB|MB|GB|TB) shape check (silent WARN + fallback).
#        Fixed to "6GB" in monitor365.nix; this script proves one real run.
#   F20: retention first-fire journal lines + DB size delta across the
#        window (retention runs INSIDE the same quiesce slot, after export).
#
# Outage contract: identical to the nightly 03:00 window — server stopped
# for the duration (watchdog timer paused first by the unit itself).
#
# Run: scripts/monitor365-backup-fire.sh   (self-elevates to root)
set -euo pipefail

UNIT="monitor365-server-backup.service"
STATE_DIR="/var/lib/monitor365-server"

if [ "$(id -u)" -ne 0 ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "✗ needs root and no sudo was found"
    exit 1
  fi
  exec "$SUDO" env PATH="$PATH" bash "$0" "$@"
fi

echo "=== monitor365 backup + retention forced fire ($(date -Is)) ==="

echo "--- pre-state"
stat -c '%s %y %n' "$STATE_DIR"/monitor365.duckdb* 2>/dev/null || true
ls -lt "$STATE_DIR"/*.backup_* 2>/dev/null | head -5 || echo "  (no prior backups)"

started=$(date '+%Y-%m-%d %H:%M:%S')
echo "--- starting $UNIT (blocks through the quiesce window — minutes on the 25 GB DB)"
if ! systemctl start "$UNIT"; then
  echo "✗ $UNIT failed — journal:"
  journalctl -u "$UNIT" --since "$started" --no-pager | tail -30
  exit 1
fi

echo "--- post-state ($(date -Is))"
stat -c '%s %y %n' "$STATE_DIR"/monitor365.duckdb* 2>/dev/null || true
echo "--- backups now:"
ls -lt "$STATE_DIR"/*.backup_* 2>/dev/null | head -5 || echo "  (NONE — export did not land)"

echo "--- unit journal (memory_limit + retention evidence)"
journalctl -u "$UNIT" --since "$started" --no-pager | grep -Ei 'memory_limit|retention|vacuum|delete|backup complete|export|error|warn' | tail -25

echo "--- server restored?"
systemctl is-active monitor365-server.service || true
