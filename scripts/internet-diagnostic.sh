#!/bin/bash
# internet-diagnostic.sh — Run on evo-x2 to diagnose internet connectivity
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "[INFO] $*"; }

echo "=========================================="
echo "  evo-x2 Internet Connectivity Diagnostic"
echo "  $(date)"
echo "=========================================="
echo

# 1. Network interfaces
echo "--- Network Interfaces ---"
ip -br addr show | grep -E 'eno1|wl|enp' || true
echo

# 2. Default route (critical — shows ECMP if dual-WAN active)
echo "--- Default Route ---"
ip route show default
echo

# 3. All routes (for debugging)
echo "--- All Routes ---"
ip route show | head -20
echo

# 4. Gateway reachability
echo "--- Gateway Reachability ---"
GW=$(ip route show default | head -1 | grep -oP 'via \K[\d.]+' || echo "NONE")
if [ "$GW" = "NONE" ]; then
  fail "No default gateway configured!"
else
  info "Gateway: $GW"
  if ping -c 3 -W 2 "$GW" >/dev/null 2>&1; then
    ok "Gateway $GW reachable"
  else
    fail "Gateway $GW UNREACHABLE — this is a root cause"
  fi
fi
echo

# 5. External IP connectivity (bypasses DNS)
echo "--- External IP Connectivity ---"
for ip in 8.8.8.8 1.1.1.1 9.9.9.9; do
  if ping -c 2 -W 2 "$ip" >/dev/null 2>&1; then
    ok "$ip reachable"
  else
    fail "$ip UNREACHABLE"
  fi
done
echo

# 6. DNS resolution
echo "--- DNS Resolution ---"
cat /etc/resolv.conf
echo

info "Testing DNS resolution..."
if host google.com >/dev/null 2>&1; then
  ok "DNS resolution works (google.com)"
else
  fail "DNS resolution FAILED (google.com)"
fi

if host google.com 127.0.0.1 >/dev/null 2>&1; then
  ok "Unbound (127.0.0.1) resolves google.com"
else
  fail "Unbound (127.0.0.1) CANNOT resolve google.com"
fi

if host google.com 9.9.9.9 >/dev/null 2>&1; then
  ok "Quad9 (9.9.9.9) resolves google.com"
else
  fail "Quad9 (9.9.9.9) CANNOT resolve google.com — WAN may be down"
fi
echo

# 7. Dual-WAN services
echo "--- Dual-WAN Services ---"
systemctl is-active route-health-monitor >/dev/null 2>&1 && ok "route-health-monitor: active" || fail "route-health-monitor: NOT active"
systemctl is-active mptcp-endpoint-manager >/dev/null 2>&1 && ok "mptcp-endpoint-manager: active" || fail "mptcp-endpoint-manager: NOT active"
echo

# 8. MPTCP endpoints
echo "--- MPTCP Endpoints ---"
ip mptcp endpoint show 2>/dev/null || warn "MPTCP not supported or no endpoints"
echo

# 9. WiFi state
echo "--- WiFi State (NetworkManager) ---"
nmcli device status 2>/dev/null || warn "NetworkManager not running"
echo

# 10. Route health monitor recent logs
echo "--- Route Health Monitor (last 10 logs) ---"
journalctl -u route-health-monitor --no-pager -n 10 2>/dev/null || true
echo

# 11. Unbound status
echo "--- Unbound DNS ---"
systemctl is-active unbound >/dev/null 2>&1 && ok "unbound: active" || fail "unbound: NOT active"
echo

# 12. Summary diagnosis
echo "=========================================="
echo "  DIAGNOSIS SUMMARY"
echo "=========================================="

ROUTE_TYPE=$(ip route show default | head -1)
if echo "$ROUTE_TYPE" | grep -q "nexthop"; then
  warn "ECMP multipath route active (dual-WAN)"
fi

if ! ping -c 1 -W 2 192.168.1.1 >/dev/null 2>&1; then
  fail "Gateway 192.168.1.1 unreachable — router may be down or cable disconnected"
fi

if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  if ping -c 1 -W 2 192.168.1.1 >/dev/null 2>&1; then
    fail "Gateway reachable but no internet — ISP outage. WiFi failover should activate."
  fi
fi

echo
echo "Emergency commands:"
echo "  just wan-status                                # Check current dual-WAN state"
echo "  sudo journalctl -u route-health-monitor -f     # Watch failover in real-time"
echo "  sudo systemctl restart route-health-monitor    # Restart monitor (preserves route state)"
