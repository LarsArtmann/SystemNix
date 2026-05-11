#!/bin/sh
# Detects niri DRM zombie state and triggers GPU recovery.
#
# Design: counts consecutive failures across invocations via a state file.
# Only triggers gpu-recovery after CONSEC_THRESHOLD consecutive failures.
# This prevents the old behavior of SIGKILLing niri in a crash loop when
# the GPU driver is truly wedged (requires reboot, not more SIGKILLs).
#
# State file: /tmp/niri-drm-healthcheck.state (persists across invocations)
# Reset: automatically reset when niri is not running or DRM errors clear.

set -eu

STATE_FILE="/tmp/niri-drm-healthcheck.state"
CONSEC_THRESHOLD=3

# Only run if niri is actually running
pgrep -x niri >/dev/null 2>&1 || {
  rm -f "$STATE_FILE"
  exit 0
}

# Count DRM errors in the last 30 seconds
drm_errors=$(journalctl --user -u niri --no-pager -n 20 --since "30 sec ago" 2>/dev/null |
  grep -cE "Permission denied|DeviceMissing" || true)

if [ "$drm_errors" -ge 10 ]; then
  # Increment consecutive failure count
  count=0
  if [ -f "$STATE_FILE" ]; then
    count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
  fi
  count=$((count + 1))
  echo "$count" > "$STATE_FILE"

  if [ "$count" -ge "$CONSEC_THRESHOLD" ]; then
    echo "niri DRM zombie confirmed ($count consecutive checks with errors). Triggering GPU recovery."
    rm -f "$STATE_FILE"
    systemctl start gpu-recovery.service 2>/dev/null || {
      echo "gpu-recovery.service failed. System reboot required."
      systemctl reboot 2>/dev/null || true
    }
  else
    echo "niri DRM errors detected ($drm_errors in 30s, check $count/$CONSEC_THRESHOLD). Waiting for confirmation."
  fi
else
  # No errors — reset consecutive counter
  if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
  fi
fi
