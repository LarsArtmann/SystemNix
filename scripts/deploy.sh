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
  set +e
  nh os switch . 2>&1
  switch_exit=$?
  set -e

  if [ "$switch_exit" -ne 0 ]; then
    echo ""
    echo "⚠ nh os switch returned exit code $switch_exit"
    echo "  (exit code 4 = some services failed during activation, but config IS activated)"
    echo "  Resetting start-limit-hit and retrying failed units..."
    sudo systemctl reset-failed 2>/dev/null || true
    systemctl --user reset-failed 2>/dev/null || true
  fi

  echo ""
  echo "=== Waiting 10s for services to settle ==="
  sleep 10

  echo ""
  echo "=== Failed units ==="
  systemctl --failed --no-pager 2>/dev/null || true

  echo ""
  echo "=== Post-Deploy Smoke Test ==="
  if nix run .#post-deploy-check; then
    echo "✅ Post-deploy smoke test passed"
  else
    echo "⚠ Some smoke checks failed — review above"
  fi
else
  echo ""
  echo "❌ Deploy aborted — fix pre-deploy failures first"
  exit 1
fi
