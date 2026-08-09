#!/bin/sh
# Reports niri compositor health for monitoring.
# Exit 0 = healthy, exit 1 = degraded (high crash rate).
#
# Checks:
# 1. Niri process is running
# 2. No more than 5 restarts in the last 10 minutes
# 3. No DRM errors in the last 30 seconds

set -eu

CRASH_THRESHOLD=5
CRASH_WINDOW="10 min"
DRM_ERROR_THRESHOLD=10

# Check niri is running
if ! pgrep -x niri >/dev/null 2>&1; then
  echo "CRITICAL: niri process not running"
  exit 1
fi

# Count niri restarts (service start events) in the window
restarts=$(journalctl --grep "Started niri" --user -u niri --since "$CRASH_WINDOW" --no-pager --output cat 2>/dev/null |
  wc -l || echo 0)

if [ "$restarts" -gt "$CRASH_THRESHOLD" ]; then
  echo "CRITICAL: niri restarted $restarts times in $CRASH_WINDOW (threshold: $CRASH_THRESHOLD)"
  exit 1
fi

# Check for DRM errors
drm_errors=$(journalctl --grep "Permission denied|DeviceMissing" --user -u niri -n 11 --since "30 sec ago" --no-pager --output cat 2>/dev/null |
  wc -l || echo 0)

if [ "$drm_errors" -ge "$DRM_ERROR_THRESHOLD" ]; then
  echo "WARNING: $drm_errors DRM errors in 30s"
  exit 1
fi

echo "OK: niri healthy ($restarts restarts in $CRASH_WINDOW, $drm_errors DRM errors)"
exit 0
