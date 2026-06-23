#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Pre-Deploy Validation ==="
if bash "$SCRIPT_DIR/pre-deploy-check.sh"; then
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
