#!/usr/bin/env bash
set -euo pipefail

echo "=== DNS Services ==="
systemctl is-active unbound dnsblockd 2>/dev/null || true
echo ""
echo "=== DNS Resolution ==="
dig google.com +short | head -1
echo ""
echo "=== DNS Blocking ==="
dig doubleclick.net +short | head -1
echo ""
echo "=== dnsblockd Stats ==="
curl -s http://127.0.0.1:9090/stats 2>/dev/null || echo "Stats unavailable"
