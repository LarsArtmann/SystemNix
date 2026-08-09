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
  echo "=== Backing up DMS settings (if user-modified) ==="
  # DMS may replace the HM-managed settings.json symlink with a real file
  # containing runtime state + user UI customizations. nh os switch overwrites
  # it with the symlink, losing those changes. Back up first if it's a real file.
  dms_config_dir="$HOME/.config/DankMaterialShell"
  for f in settings.json plugin_settings.json; do
    target="$dms_config_dir/$f"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      backup="$dms_config_dir/${f}.pre-deploy.$(date +%Y%m%d%H%M%S).bak"
      cp "$target" "$backup"
      echo "  Backed up $f (was real file, not symlink) → $(basename "$backup")"
    fi
  done

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
  if systemctl is-enabled --quiet monitor365.service 2>/dev/null && ! systemctl is-active --quiet monitor365.service 2>/dev/null; then
    echo "Starting monitor365.service (was enabled but inactive)..."
    sudo systemctl start monitor365.service 2>/dev/null || true
  fi

  # Restart Caddy after every deploy. The harden() helper sets PrivateTmp=true
  # which blocks systemd's mount-namespace reload path — switch-to-configuration
  # silently fails to reload Caddy (exit code 4), leaving new vHosts unloaded.
  if systemctl is-enabled --quiet caddy.service 2>/dev/null; then
    echo "Restarting caddy.service (reload broken by PrivateTmp hardening)..."
    sudo systemctl restart caddy.service 2>/dev/null || true
  fi

  # Restart provisioner oneshots that switch-to-configuration skips.
  # Type=oneshot + RemainAfterExit=true services stay in "active (exited)" state
  # after their first run. switch-to-configuration does NOT restart them even
  # when restartTriggers change. This means provisioning fixes deployed to the
  # Nix store never re-run without an explicit restart.
  for provisioner in signoz-provision pocket-id-provision browser-history-oidc-setup forgejo-generate-token forgejo-oidc-setup forgejo-ssh-keys twenty-fix-collation dnsblockd-attach-ip monitor365-schema-migrate; do
    if systemctl is-enabled --quiet "$provisioner.service" 2>/dev/null; then
      echo "Restarting provisioner: $provisioner.service"
      sudo systemctl restart "$provisioner.service" 2>/dev/null || true
    fi
  done

  # Restart browser-history AFTER browser-history-oidc-setup so it picks up the
  # freshly-written OAuth2 env file. Without this, browser-history keeps running
  # with stale (or missing) OAuth2 config from a prior boot.
  if systemctl is-enabled --quiet browser-history.service 2>/dev/null; then
    echo "Restarting browser-history.service (reload OAuth2 env file)"
    sudo systemctl restart browser-history.service 2>/dev/null || true
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
