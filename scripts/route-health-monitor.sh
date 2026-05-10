#!/bin/bash
# route-health-monitor — Dynamic dual-WAN route optimizer
#
# Monitors latency and packet loss on both gateways (eno1 + WiFi),
# adjusts route metrics and ECMP weights in real-time.
#
# With MPTCP, individual connections use BOTH paths simultaneously.
# This script controls which path gets new connections and adjusts
# the weight ratio for ECMP load distribution.

set -euo pipefail

ENO1_GW="${ENO1_GW:-192.168.1.1}"
WIFI_IF="${WIFI_IF:-wlp195s0}"
LOG_TAG="route-health-monitor"
PING_COUNT=3
PING_TIMEOUT=2
CHECK_INTERVAL=5
HISTORY_SIZE=6

log() { logger -t "$LOG_TAG" "$@"; }

# Rolling latency history (in ms, 9999 = unreachable)
# shellcheck disable=SC2034,SC2178
declare -a ENO1_HIST=()
# shellcheck disable=SC2034
declare -a WIFI_HIST=()

push_hist() {
  # shellcheck disable=SC2178
  local -n arr=$1
  local val=$2
  arr+=("$val")
  if (( ${#arr[@]} > HISTORY_SIZE )); then
    arr=("${arr[@]:1}")
  fi
}

avg_hist() {
  # shellcheck disable=SC2178
  local -n arr=$1
  local sum=0 count=0
  for v in "${arr[@]}"; do
    sum=$((sum + v))
    count=$((count + 1))
  done
  if (( count == 0 )); then echo 9999; else echo $((sum / count)); fi
}

loss_pct() {
  local output="$1"
  local tx rx
  tx=$(echo "$output" | grep -oP '\d+(?= packets transmitted)' || echo "0")
  rx=$(echo "$output" | grep -oP '\d+(?= received)' || echo "0")
  if (( tx == 0 )); then echo 100; else echo $(( (tx - rx) * 100 / tx )); fi
}

avg_latency() {
  local output="$1"
  # Extract avg from "rtt min/avg/max/mdev = X.Y/Z.Y/W.Y/V.Y ms"
  # Match: = <float>/<float>/<float>/<float> — capture second value (avg)
  echo "$output" | grep -oP '=\s*[\d.]+/[\d.]+/\K[\d.]+' || echo 9999
}

# Current state
CURRENT_ENO1_METRIC=100
CURRENT_WIFI_METRIC=200
CURRENT_MODE="dual"

set_route_dual() {
  local eno1_w="$1"
  local wifi_w="$2"
  local wifi_gw="$3"

  # Don't touch routes if no WiFi gateway
  [ -z "$wifi_gw" ] && return 1

  ip route replace default \
    nexthop via "$ENO1_GW" dev eno1 weight "$eno1_w" \
    nexthop via "$wifi_gw" dev "$WIFI_IF" weight "$wifi_w" \
    2>/dev/null
}

set_route_single() {
  local gw="$1"
  local dev="$2"
  ip route replace default via "$gw" dev "$dev" 2>/dev/null
}

log "starting dual-WAN route health monitor (eno1=${ENO1_GW})"
log "warming up (${HISTORY_SIZE} x ${CHECK_INTERVAL}s)..."

while true; do
  # --- Measure eno1 ---
  ENO1_OUT=$(ping -c $PING_COUNT -W $PING_TIMEOUT -I eno1 "$ENO1_GW" 2>&1 || true)
  ENO1_LAT=$(avg_latency "$ENO1_OUT")
  ENO1_LAT=${ENO1_LAT%.*}  # truncate to integer
  ENO1_LAT=${ENO1_LAT:-9999}
  ENO1_LOSS=$(loss_pct "$ENO1_OUT")
  push_hist ENO1_HIST "$ENO1_LAT"

  # --- Measure WiFi ---
  WIFI_GW=$(nmcli -t -f IP4.GATEWAY device show "$WIFI_IF" 2>/dev/null | cut -d: -f2 || echo "")
  WIFI_LAT=9999
  WIFI_LOSS=100

  if [ -n "$WIFI_GW" ]; then
    WIFI_OUT=$(ping -c $PING_COUNT -W $PING_TIMEOUT -I "$WIFI_IF" "$WIFI_GW" 2>&1 || true)
    WIFI_LAT=$(avg_latency "$WIFI_OUT")
    WIFI_LAT=${WIFI_LAT%.*}
    WIFI_LAT=${WIFI_LAT:-9999}
    WIFI_LOSS=$(loss_pct "$WIFI_OUT")
  fi
  push_hist WIFI_HIST "$WIFI_LAT"

  # --- Compute averages ---
  ENO1_AVG=$(avg_hist ENO1_HIST)
  WIFI_AVG=$(avg_hist WIFI_HIST)

  # --- Decision logic ---
  ENO1_OK=$(( ENO1_AVG < 500 && ENO1_LOSS < 50 ? 1 : 0 ))
  WIFI_OK=$(( WIFI_AVG < 500 && WIFI_LOSS < 50 ? 1 : 0 ))

  if (( ENO1_OK && WIFI_OK )); then
    ENO1_W=$(( 1000 / (ENO1_AVG == 0 ? 1 : ENO1_AVG) ))
    WIFI_W=$(( 1000 / (WIFI_AVG == 0 ? 1 : WIFI_AVG) ))
    ENO1_W=$(( ENO1_W > 20 ? 20 : ENO1_W ))
    ENO1_W=$(( ENO1_W < 1 ? 1 : ENO1_W ))
    WIFI_W=$(( WIFI_W > 20 ? 20 : WIFI_W ))
    WIFI_W=$(( WIFI_W < 1 ? 1 : WIFI_W ))

    if [ "$CURRENT_MODE" != "dual" ] || [ "$CURRENT_ENO1_METRIC" != "$ENO1_W" ] || [ "$CURRENT_WIFI_METRIC" != "$WIFI_W" ]; then
      if set_route_dual "$ENO1_W" "$WIFI_W" "$WIFI_GW"; then
        log "ECMP: eno1 weight=$ENO1_W (avg=${ENO1_AVG}ms) + wifi weight=$WIFI_W (avg=${WIFI_AVG}ms)"
        CURRENT_MODE="dual"
        CURRENT_ENO1_METRIC=$ENO1_W
        CURRENT_WIFI_METRIC=$WIFI_W
      fi
    fi

  elif (( ENO1_OK )) && ! (( WIFI_OK )); then
    if [ "$CURRENT_MODE" != "eno1-only" ]; then
      set_route_single "$ENO1_GW" eno1
      log "FAILOVER: WiFi down (avg=${WIFI_AVG}ms, loss=${WIFI_LOSS}%), eno1 only"
      CURRENT_MODE="eno1-only"
    fi

  elif (( WIFI_OK )) && ! (( ENO1_OK )); then
    if [ -n "$WIFI_GW" ] && [ "$CURRENT_MODE" != "wifi-only" ]; then
      set_route_single "$WIFI_GW" "$WIFI_IF"
      log "FAILOVER: eno1 down (avg=${ENO1_AVG}ms, loss=${ENO1_LOSS}%), WiFi only"
      CURRENT_MODE="wifi-only"
    fi

  else
    if [ "$CURRENT_MODE" != "both-down" ]; then
      set_route_single "$ENO1_GW" eno1
      log "CRITICAL: both paths degraded (eno1=${ENO1_AVG}ms/${ENO1_LOSS}%, wifi=${WIFI_AVG}ms/${WIFI_LOSS}%), trying eno1"
      CURRENT_MODE="both-down"
    fi
  fi

  sleep $CHECK_INTERVAL
done
