#!/bin/sh
# Detects niri DRM zombie state and triggers GPU recovery.
#
# Design: counts consecutive failures across invocations via a state file.
# Only triggers gpu-recovery after CONSEC_THRESHOLD consecutive failures.
# This prevents the old behavior of SIGKILLing niri in a crash loop when
# the GPU driver is truly wedged (requires reboot, not more SIGKILLs).

set -eu

# --- State persistence (inlined from lib.sh — writeShellApplication breaks relative sourcing) ---
_state_dir=""
_state_file=""
_state_threshold=0
_state_count=0

state_init() {
  _state_dir="$1"
  _state_file="$1/$2"
  _state_threshold="$3"
  _state_count=0
  mkdir -p "$_state_dir" 2>/dev/null || true
}

state_hit() {
  if [ -f "$_state_file" ]; then
    _state_count=$(cat "$_state_file" 2>/dev/null || echo 0)
  fi
  _state_count=$((_state_count + 1))
  echo "$_state_count" >"$_state_file"
  [ "$_state_count" -ge "$_state_threshold" ]
}

state_reset() {
  rm -f "$_state_file"
  _state_count=0
}

state_init "/var/lib/niri-drm-healthcheck" "state" 3

pgrep -x niri >/dev/null 2>&1 || {
  state_reset
  exit 0
}

drm_errors=$(journalctl --user -u niri --no-pager -n 20 --since "30 sec ago" 2>/dev/null |
  grep -cE "Permission denied|DeviceMissing" || true)

if [ "$drm_errors" -ge 10 ]; then
  if state_hit; then
    echo "niri DRM zombie confirmed ($_state_count consecutive checks with errors). Triggering GPU recovery."
    state_reset
    systemctl start gpu-recovery.service 2>/dev/null || {
      echo "gpu-recovery.service failed. System reboot required."
      systemctl reboot 2>/dev/null || true
    }
  else
    echo "niri DRM errors detected ($drm_errors in 30s, check $_state_count/$_state_threshold). Waiting for confirmation."
  fi
else
  state_reset
fi
