#!/usr/bin/env bash
# internet-diagnostic.sh — Run on evo-x2 to diagnose internet connectivity
set -euo pipefail

source "$(dirname "$0")/lib.sh"

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
ip route show | head -20 || true
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
  ok "dnsblockd (127.0.0.1) resolves google.com"
else
  fail "dnsblockd (127.0.0.1) CANNOT resolve google.com — local zones + *.home.lan are dark too"
fi

if host google.com 9.9.9.9 >/dev/null 2>&1; then
  ok "Quad9 (9.9.9.9) resolves google.com"
else
  fail "Quad9 (9.9.9.9) CANNOT resolve google.com — WAN may be down"
fi
echo

# 7. Failover + DNS services (wifi-failover replaced the retired dual-WAN
#    stack; dnsblockd replaced unbound as the sole resolver on :53)
echo "--- Failover + DNS Services ---"
if systemctl is-active wifi-failover >/dev/null 2>&1; then ok "wifi-failover: active"; else fail "wifi-failover: NOT active (eno1→wlan0 standby dead — cable-pull failover will blackhole)"; fi
if systemctl is-active dnsblockd >/dev/null 2>&1; then ok "dnsblockd: active"; else fail "dnsblockd: NOT active (sole DNS resolver down — *.home.lan unresolvable)"; fi
echo

# 8. MPTCP endpoints
echo "--- MPTCP Endpoints ---"
ip mptcp endpoint show 2>/dev/null || warn "MPTCP not supported or no endpoints"
echo

# 9. WiFi state
echo "--- WiFi State (NetworkManager) ---"
nmcli device status 2>/dev/null || warn "NetworkManager not running"
echo

# 10. Failover daemon recent logs
echo "--- wifi-failover (last 10 logs) ---"
timeout 15 journalctl -u wifi-failover --no-pager -n 10 2>/dev/null || true
echo

# 11. dnsblockd status
echo "--- dnsblockd DNS ---"
systemctl is-active dnsblockd >/dev/null 2>&1 && ok "dnsblockd: active" || fail "dnsblockd: NOT active"
echo

# 12. Summary diagnosis
echo "=========================================="
echo "  DIAGNOSIS SUMMARY"
echo "=========================================="

# Reuse the gateway PARSED in §4 — the old `GATEWAY` var was never set, so the
# summary always pinged the hardcoded 192.168.1.1 (wrong box on hotspot
# failover, this host's actual failure mode, while §4 had found the real one).
GATEWAY="$GW"

if ip route show default | grep -q "dev wlan0"; then
  warn "Default route rides wlan0 (metric-100 fallback) — eno1 is down or evicted; check carrier + wifi-failover journal"
fi

if [ -z "$GATEWAY" ] || [ "$GATEWAY" = "NONE" ]; then
  fail "No default gateway — nothing to re-ping (see §4)"
else
  if ! ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
    fail "Gateway $GATEWAY unreachable — router may be down or cable disconnected"
  fi

  if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    if ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
      fail "Gateway reachable but no internet — ISP outage. WiFi failover should have evicted the pinned eno1 route (check wifi-failover journal for FAILOVER marker)."
    fi
  fi
fi

echo
summary

echo
echo "Emergency commands:"
echo "  ip route show default                        # metric 0 = eno1 primary, metric 100 = wlan0 standby"
echo "  sudo journalctl -u wifi-failover -f          # Watch carrier state + FAILOVER/RESTORE markers"
echo "  sudo systemctl restart wifi-failover          # Restart the failover daemon (kernel routes untouched)"
echo "  dig cache.home.lan @127.0.0.1 +short          # Verify dnsblockd answers before blaming DNS"
