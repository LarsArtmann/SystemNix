#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploying NixOS config to evo-x2 ==="
nh os switch . 2>&1

echo ""
echo "=== Waiting 5s for services to settle ==="
sleep 5

echo ""
echo "=== dnsblockd status ==="
systemctl status dnsblockd --no-pager 2>/dev/null || true

echo ""
echo "=== Failed units ==="
systemctl --failed --no-pager 2>/dev/null || true
