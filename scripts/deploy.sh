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

  # Start critical services that deploy may have left in inactive/dead state.
  # reset-failed only clears the failure counter — it does NOT start the service.
  # The monitor365 agent in particular dies on start-limit-hit and never recovers
  # without an explicit start (the agent-watchdog timer covers this too, but
  # starting here avoids waiting up to 5 minutes).
  for svc in monitor365.service; do
    if systemctl is-enabled --quiet "$svc" 2>/dev/null && ! systemctl is-active --quiet "$svc" 2>/dev/null; then
      echo "Starting $svc (was enabled but inactive)..."
      sudo systemctl start "$svc" 2>/dev/null || true
    fi
  done

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
