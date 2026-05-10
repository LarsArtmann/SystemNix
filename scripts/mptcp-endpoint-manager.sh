#!/bin/bash
# mptcp-endpoint-manager — Keeps MPTCP endpoints in sync with live interfaces
#
# Adds/removes MPTCP subflow endpoints as interfaces come up/down.
# The kernel path manager (pm_type=0) will then create subflows for each endpoint,
# allowing a single TCP connection to span both ethernet and WiFi simultaneously.

set -euo pipefail

ENO1_IP="${ENO1_IP:-${1:-192.168.1.150}}"
ENO1_IF="${ENO1_IF:-eno1}"
WIFI_IF="${WIFI_IF:-wlp195s0}"
LOG_TAG="mptcp-endpoint-manager"

log() { logger -t "$LOG_TAG" "$@"; }

# Wait for ip command
command -v ip >/dev/null 2>&1 || { log "FATAL: ip command not found"; exit 1; }

add_endpoint() {
  local dev="$1" addr="$2"
  # Check if endpoint already exists
  if ip mptcp endpoint show 2>/dev/null | grep -q "$addr"; then
    log "endpoint $addr on $dev already exists, skipping"
    return 0
  fi
  if ip mptcp endpoint add dev "$dev" "$addr" subflow 2>/dev/null; then
    log "added endpoint $addr on $dev"
  else
    log "failed to add endpoint $addr on $dev"
    return 1
  fi
}

remove_endpoint() {
  local addr="$1"
  if ip mptcp endpoint show 2>/dev/null | grep -q "$addr"; then
    if ip mptcp endpoint delete "$addr" 2>/dev/null; then
      log "removed endpoint $addr"
    else
      log "failed to remove endpoint $addr"
    fi
  fi
}

# Add eno1 endpoint (always present, static IP)
add_endpoint "$ENO1_IF" "$ENO1_IP"

# Monitor WiFi via NetworkManager — add/remove endpoint on connect/disconnect
log "starting WiFi endpoint monitor"

# Track current WiFi IP to detect changes
CURRENT_WIFI_IP=""

while true; do
  # Get WiFi connection state and IP
  WIFI_STATE=$(nmcli -t -f GENERAL.STATE device show "$WIFI_IF" 2>/dev/null | cut -d: -f2 || echo "")
  WIFI_IP=""

  if echo "$WIFI_STATE" | grep -q "connected"; then
    WIFI_IP=$(nmcli -t -f IP4.ADDRESS device show "$WIFI_IF" 2>/dev/null | cut -d: -f2 | cut -d/ -f1 || echo "")
  fi

  if [ -n "$WIFI_IP" ] && [ "$WIFI_IP" != "$CURRENT_WIFI_IP" ]; then
    # WiFi IP changed or new connection
    [ -n "$CURRENT_WIFI_IP" ] && remove_endpoint "$CURRENT_WIFI_IP"
    add_endpoint "$WIFI_IF" "$WIFI_IP"
    CURRENT_WIFI_IP="$WIFI_IP"
  elif [ -z "$WIFI_IP" ] && [ -n "$CURRENT_WIFI_IP" ]; then
    # WiFi disconnected
    remove_endpoint "$CURRENT_WIFI_IP"
    CURRENT_WIFI_IP=""
  fi

  sleep 5
done
