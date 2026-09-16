#!/usr/bin/env bash
# ⚠ RETIRED STACK (banner 2026-09-16): Mullvad is REMOVED from this host — the
# `inet mullvad` nft table no longer exists (the first command always errors).
# The TCP/ICMP probes below test plain connectivity, nothing Mullvad-specific.
sudo "$(command -v nft || echo nft)" list table inet mullvad 2>&1
echo "=== TCP TEST ==="
curl -sS --connect-timeout 5 https://ifconfig.me 2>&1 || echo "CURL FAILED"
echo ""
echo "=== ICMP TEST ==="
ping -c 2 -W 3 1.1.1.1 2>&1
