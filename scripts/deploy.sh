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

  # Wedged switch-to-configuration detection (2026-08-18 incident):
  # nixpkgs' Rust switch-to-configuration can complete all activation work,
  # print its final report, and then HANG forever (missed dbus JobRemoved
  # signal) while holding /run/nixos/switch-to-configuration.lock. Every
  # subsequent deploy then dies with exit 11 "Could not acquire lock" until
  # the zombie is killed or the machine reboots. Default: detect + print the
  # recovery command (killing root processes on an age heuristic must stay a
  # human decision — a legitimately long activation, e.g. restarting a unit
  # with a 6h TimeoutStartSec, would match a naive age-only check). Opt in to
  # automatic cleanup with DEPLOY_KILL_WEDGED_STC=1 (kills stc processes
  # older than 30 min).
  stc_lock=/run/nixos/switch-to-configuration.lock
  if [ -e "$stc_lock" ]; then
    stc_pids=$(pgrep -f 'switch-to-configuration' || true)
    wedged=""
    for pid in $stc_pids; do
      etimes=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
      if [ -n "$etimes" ] && [ "$etimes" -gt 1800 ]; then
        wedged="$wedged $pid"
      fi
    done
    if [ -n "$wedged" ]; then
      if [ "${DEPLOY_KILL_WEDGED_STC:-0}" = "1" ]; then
        echo "⚠ Killing wedged switch-to-configuration (PIDs:$wedged, >30 min old):"
        for pid in $wedged; do
          sudo kill "$pid" || true
        done
        sleep 2
      else
        echo "❌ switch-to-configuration appears WEDGED (PIDs:$wedged, >30 min old)."
        echo "   It holds $stc_lock; this deploy will fail with 'Could not acquire lock'."
        echo "   Verify no deploy is legitimately activating, then either run:"
        echo "     sudo kill $wedged"
        echo "   or re-run with:  DEPLOY_KILL_WEDGED_STC=1 nix run .#deploy"
        exit 11
      fi
    fi
  fi

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
  echo "=== Reaping displaced buildcache cache dirs ==="
  # While the buildcache mount is dead, env-less tools recreate ~/.cache/<name>
  # as REAL dirs where home.file expects out-of-store symlinks. Those both move
  # build churn back onto the NVMe and abort the NEXT home-manager activation
  # (checkLinkTargets "Existing file ... in the way") — so they must be reaped
  # BEFORE nh os switch. Cache data only, exact names, symlink occupants kept;
  # rm (not trash) because trashing gigabytes of rebuildable cache writes them
  # onto the NVMe this whole setup exists to protect. Mirrors the reap loop in
  # buildcache-usb-recovery.service.
  for d in goimports go go-build; do
    if [ -e "$HOME/.cache/$d" ] && [ ! -L "$HOME/.cache/$d" ]; then
      sudo rm -rf -- "$HOME/.cache/$d"
      echo "  Reaped ~/.cache/$d (real dir had displaced the HM symlink)"
    fi
  done
  # 2026-08-16 incident debris: root-owned cache trees created by an env-less
  # root shell (GOTOOLCHAIN=auto pulled a go1.26.6 toolchain into
  # ~/.cache/go-mod-fallback) while the buildcache mount was dead. Cache data
  # only; safe to remove with sudo since the owner session is long gone.
  for d in go-build-fallback go-build-override go-mod-fallback golangci-lint-override; do
    if [ -e "$HOME/.cache/$d" ]; then
      sudo rm -rf -- "$HOME/.cache/$d"
      echo "  Reaped incident debris ~/.cache/$d"
    fi
  done

  echo ""
  echo "=== Deploying NixOS config to evo-x2 ==="
  set +e
  nh_output="$(nh os switch . 2>&1 | tee /dev/stderr)"
  switch_exit=$?
  set -e

  if [ "$switch_exit" -ne 0 ]; then
    # nh wraps switch-to-configuration's exit 4 (activation completed, but some
    # units failed) as its OWN exit 1 — the exit code alone cannot distinguish
    # "activated with failed units" (recoverable) from "activation aborted".
    # set -o pipefail (top of script) preserves nh's status through the tee
    # capture; match the wrapped ExitStatus(4) in nh's output to keep the
    # post-switch recovery path reachable.
    if [ "$switch_exit" -eq 4 ] || echo "$nh_output" | grep -q "Exited(4)"; then
      echo ""
      echo "⚠ nh os switch: activation completed with failed units (exit code 4)"
      echo "  (some services failed during activation, but config IS activated)"
      echo "  Resetting start-limit-hit and retrying failed units..."
      sudo systemctl reset-failed 2>/dev/null || true
      systemctl --user reset-failed 2>/dev/null || true
    else
      echo ""
      echo "❌ nh os switch FAILED (exit $switch_exit) — config NOT activated. Aborting."
      exit "$switch_exit"
    fi
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
  for provisioner in signoz-provision pocket-id-provision browser-history-oidc-setup forgejo-generate-token forgejo-oidc-setup forgejo-ssh-keys twenty-fix-collation dnsblockd-attach-ip monitor365-schema-migrate atticd-storage-dir bank-sync-storage-dir google-sync-dirs; do
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

  # Reap zombie buildcache mounts + re-verify real I/O after switch. The unit is
  # ConditionPathExists-gated on the by-id device node: no-ops safely when the
  # USB SSD is unplugged, heals the mount when it is present.
  if systemctl cat buildcache-usb-recovery.service >/dev/null 2>&1; then
    echo "Running buildcache-usb-recovery.service (zombie reaper + remount)"
    sudo systemctl start buildcache-usb-recovery.service 2>/dev/null || true
  fi

  # Run the buildcache GC after recovery so every deploy verifies the prune
  # path end-to-end (a silent pnpm failure hid here for a week) and reclaims
  # incident debris without waiting for the weekly Sun 05:00 timer.
  if systemctl cat buildcache-gc.service >/dev/null 2>&1; then
    echo "Running buildcache-gc.service (prune verification + reclaim)"
    sudo systemctl start buildcache-gc.service 2>/dev/null || true
  fi

  # One-time /data → pool migration (atticd, monitor365, monitor365-archive).
  # --no-block: the copy can take ~10-45 min; the deploy must not wait on it.
  # ConditionPathExists-gated: starts instantly as a no-op once migrated.
  # Failures surface via the unit's onFailure Discord alert + failed-unit list.
  if systemctl cat data-to-pool-migration.service >/dev/null 2>&1; then
    echo "Starting data-to-pool-migration.service (no-block, copy + verify + source cleanup)"
    sudo systemctl start --no-block data-to-pool-migration.service 2>/dev/null || true
  fi

  # One-time ActivityWatch data → pool migration with symlink cutover.
  # Same model as above: --no-block, ConditionPathIsDirectory-gated (skips
  # once the source is a symlink), onFailure Discord alert on failure.
  if systemctl cat activitywatch-data-to-pool.service >/dev/null 2>&1; then
    echo "Starting activitywatch-data-to-pool.service (no-block, copy + verify + symlink cutover)"
    sudo systemctl start --no-block activitywatch-data-to-pool.service 2>/dev/null || true
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
