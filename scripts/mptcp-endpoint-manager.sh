#!/bin/bash
# mptcp-endpoint-manager — Manages MPTCP subflow endpoints
#
# Modes:
#   startup    — Add eno1 endpoint + detect existing WiFi (one-shot, for systemd)
#   wifi-up    — Called by NM dispatcher when WiFi connects
#   wifi-down  — Called by NM dispatcher when WiFi disconnects
#
# NM dispatcher provides env vars: IP4_ADDRESS_0, DEVICE_IFACE, NM_DISPATCHER_ACTION

set -euo pipefail

ENO1_IP="${ENO1_IP:-192.168.1.150}"
ENO1_IF="${ENO1_IF:-eno1}"
WIFI_IF="${WIFI_IF:-wlan0}"
LOG_TAG="mptcp-endpoint-manager"

log() { logger -t "$LOG_TAG" "$@"; }

add_endpoint() {
  local dev="$1" addr="$2"
  if ip mptcp endpoint show 2>/dev/null | grep -q "$addr"; then
    log "endpoint $addr on $dev already exists"
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

MODE="${1:-startup}"

case "$MODE" in
startup)
  # Add eno1 endpoint (static, always present)
  add_endpoint "$ENO1_IF" "$ENO1_IP"

  # Detect current WiFi connection and add endpoint if connected
  WIFI_STATE=$(nmcli -t -f GENERAL.STATE device show "$WIFI_IF" 2>/dev/null | cut -d: -f2 || echo "")
  if echo "$WIFI_STATE" | grep -q "connected"; then
    WIFI_IP=$(nmcli -t -f IP4.ADDRESS device show "$WIFI_IF" 2>/dev/null | cut -d: -f2 | cut -d/ -f1 || echo "")
    if [ -n "$WIFI_IP" ]; then
      add_endpoint "$WIFI_IF" "$WIFI_IP"
    fi
  fi

  log "startup complete (eno1=$ENO1_IP, wifi=$WIFI_IF)"
  ;;

wifi-up)
  # Called by NM dispatcher on WiFi connect
  # NM provides: DEVICE_IFACE, IP4_ADDRESS_0 (e.g. "10.79.119.35/24")
  IFACE="${DEVICE_IFACE:-$WIFI_IF}"
  WIFI_IP=$(echo "${IP4_ADDRESS_0:-}" | cut -d/ -f1)
  if [ -n "$WIFI_IP" ]; then
    add_endpoint "$IFACE" "$WIFI_IP"
  else
    log "wifi-up: no IP4_ADDRESS_0 for $IFACE, querying nmcli"
    WIFI_IP=$(nmcli -t -f IP4.ADDRESS device show "$IFACE" 2>/dev/null | cut -d: -f2 | cut -d/ -f1 || echo "")
    if [ -n "$WIFI_IP" ]; then
      add_endpoint "$IFACE" "$WIFI_IP"
    fi
  fi
  ;;

wifi-down)
  # Called by NM dispatcher on WiFi disconnect
  IFACE="${DEVICE_IFACE:-$WIFI_IF}"
  CURRENT=$(ip mptcp endpoint show 2>/dev/null | grep "dev $IFACE" | awk '{print $2}' || echo "")
  if [ -n "$CURRENT" ]; then
    remove_endpoint "$CURRENT"
  fi
  ;;

*)
  log "unknown mode: $MODE (expected: startup, wifi-up, wifi-down)"
  exit 1
  ;;
esac
