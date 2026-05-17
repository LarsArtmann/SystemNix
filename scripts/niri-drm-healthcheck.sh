#!/bin/sh
# Detects niri DRM zombie state and triggers GPU recovery.
#
# Design: counts consecutive failures across invocations via a state file.
# Only triggers gpu-recovery after CONSEC_THRESHOLD consecutive failures.
# This prevents the old behavior of SIGKILLing niri in a crash loop when
# the GPU driver is truly wedged (requires reboot, not more SIGKILLs).

# shellcheck source=./lib.sh
set -eu

# shellcheck disable=SC1091
. "$(dirname "$0")/lib.sh"

state_init "/var/lib/niri-drm-healthcheck" "state" 3

pgrep -x niri >/dev/null 2>&1 || {
  state_reset
  exit 0
}

drm_errors=$(journalctl --user -u niri --no-pager -n 20 --since "30 sec ago" 2>/dev/null |
  grep -cE "Permission denied|DeviceMissing" || true)

if [ "$drm_errors" -ge 10 ]; then
  if state_hit; then
    # shellcheck disable=SC2154
    echo "niri DRM zombie confirmed ($state_count consecutive checks with errors). Triggering GPU recovery."
    state_reset
    systemctl start gpu-recovery.service 2>/dev/null || {
      echo "gpu-recovery.service failed. System reboot required."
      systemctl reboot 2>/dev/null || true
    }
  else
    # shellcheck disable=SC2154
    echo "niri DRM errors detected ($drm_errors in 30s, check $state_count/$state_threshold). Waiting for confirmation."
  fi
else
  state_reset
fi
