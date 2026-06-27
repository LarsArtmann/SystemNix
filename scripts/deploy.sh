#!/usr/bin/env bash
set -euo pipefail

echo "=== Pre-Deploy Validation ==="
if nix run .#pre-deploy-check; then
  echo ""
  echo "=== Resetting failed units ==="
  # Clear start-limit-hit state so switch-to-configuration can restart changed units.
  # Without this, units that crash-looped at boot block activation with exit code 4.
  sudo systemctl reset-failed 2>/dev/null || true
  systemctl --user reset-failed 2>/dev/null || true

  echo ""
  echo "=== Deploying NixOS config to evo-x2 ==="
  nh os switch . 2>&1

  echo ""
  echo "=== Waiting 10s for services to settle ==="
  sleep 10

  echo ""
  echo "=== Failed units ==="
  systemctl --failed --no-pager 2>/dev/null || true
else
  echo ""
  echo "❌ Deploy aborted — fix pre-deploy failures first"
  exit 1
fi
