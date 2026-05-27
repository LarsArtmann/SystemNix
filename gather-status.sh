#!/usr/bin/env bash
set -euo pipefail

echo "=== FAILED SERVICES ==="
sudo systemctl list-units --state=failed --no-pager 2>&1 || true

echo ""
echo "=== ALL CUSTOM SERVICES STATUS ==="
for svc in niri-health-metrics oauth2-proxy pocket-id caddy forgejo immich-server homepage-dashboard hermes signoz clickhouse gatus taskchampion-sync dnsblockd unbound display-watchdog amdgpu-metrics nvme-metrics manifest twenty monitor365 monitor365-server; do
  status=$(systemctl is-active "${svc}.service" 2>/dev/null || echo "not-found")
  echo "  ${svc}: ${status}"
done

echo ""
echo "=== DISK USAGE ==="
df -h / /data /home 2>/dev/null | tail -4

echo ""
echo "=== SWAP ==="
free -h | grep -i swap

echo ""
echo "=== MEMORY ==="
free -h | grep -i mem
