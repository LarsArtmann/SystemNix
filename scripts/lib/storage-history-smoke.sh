#!/usr/bin/env bash
# Storage-history (restic-storage-history) smoke logic shared by
# pre-deploy-check §14 and post-deploy-check §19 (fixture-tested by
# scripts/test-storage-history-smoke.sh and the
# storage-history-smoke-selftest flake check). Extracted from the inline
# blocks so the fixture exercises the SAME code the deploy gates run —
# never trust a fixture that greps its own copy of the messages.
#
# Callers provide the verdict callbacks (single message argument):
#   pre:  STH_PASS STH_FAIL
#   post: STH_PASS STH_FAIL STH_WARN
# plus STH_SYSTEMCTL (default: systemctl) so fixtures can stub the live
# timer/bootstrap queries, and jq + sed + grep on PATH.

# Classify a §14 eval failure from its raw nix stderr (file argument).
# Echoes "disabled" ONLY for the known attribute-missing shape of the
# storage-history backup unit path — with the storage-collector module's
# mkIf cfg.enable wrapping, a disabled collector is simply absent from
# systemd.services, so the legit disabled case surfaces as an eval error
# naming this exact attribute. Anything else (nix daemon restart, store
# hiccup, real config error, substituter noise) is an "anomaly" and the
# caller must FAIL LOUD instead of blind-skipping the gate (a gate that
# treats every eval failure as "disabled" skips precisely the config
# regression it exists to catch).
sh_classify_eval_error() {
  if grep -q "does not provide attribute.*restic-backups-storage-history\.serviceConfig" "$1"; then
    echo "disabled"
  else
    echo "anomaly"
  fi
}

sh_pre_deploy() {
  # $1 = services.restic.backups.storage-history options JSON
  # $2 = restic-backups-storage-history serviceConfig JSON
  # $3 = restic-backups-storage-history unitConfig JSON
  # $4 = restic-storage-history-setup serviceConfig JSON
  local opts_json="$1" svc_json="$2" unit_json="$3" setup_json="$4"
  local prune_n repo path0 cal persist jitter marker io_class io_prio mem mounts setup_exec setup_state

  prune_n=$(printf '%s' "$opts_json" | jq -r '.pruneOpts // [] | length')
  if [ "$prune_n" = "0" ]; then
    "$STH_PASS" "indefinite retention preserved (pruneOpts empty — the design invariant)"
  else
    "$STH_FAIL" "restic.backups.storage-history has $prune_n pruneOpts — the history tier is INDEFINITE by design; pruning silently destroys the year-scale trend record (owner decision pending on a 10y safety prune, docs/todo/storage.md)"
  fi

  repo=$(printf '%s' "$opts_json" | jq -r '.repository // ""')
  if [ "$repo" = "/mnt/pool/backups/restic-storage-history" ]; then
    "$STH_PASS" "repo on the HDD pool ($repo)"
  else
    "$STH_FAIL" "storage-history repository is '$repo', not /mnt/pool/backups/restic-storage-history — the pool RAID1 tier, not a QLC-root shadow"
  fi

  path0=$(printf '%s' "$opts_json" | jq -r '.paths[0] // ""')
  if [ "$path0" = "/var/lib/private/storage-collector" ]; then
    "$STH_PASS" "targets the REAL StateDirectory (/var/lib/private/storage-collector — restic does not follow a symlinked target dir)"
  else
    "$STH_FAIL" "storage-history paths[0] is '$path0', not /var/lib/private/storage-collector — the private/ real dir is load-bearing"
  fi

  cal=$(printf '%s' "$opts_json" | jq -r '.timerConfig.OnCalendar // ""')
  persist=$(printf '%s' "$opts_json" | jq -r '.timerConfig.Persistent // ""')
  jitter=$(printf '%s' "$opts_json" | jq -r '.timerConfig.RandomizedDelaySec // ""')
  if [ "$cal" = "*-*-* 04:20:00" ] && [ "$persist" = "true" ] && [ "$jitter" = "10m" ]; then
    "$STH_PASS" "timer shape wired (04:20 nightly, Persistent, 10m jitter — clear of the dump windows)"
  else
    "$STH_FAIL" "storage-history timer is '$cal/P=$persist/J=$jitter', not 04:20 + Persistent + 10m jitter"
  fi

  marker=$(printf '%s' "$svc_json" | jq -r '.ExecStartPost // ""')
  if printf '%s' "$marker" | grep -q '/mnt/pool/backups/restic-storage-history/.last_success'; then
    "$STH_PASS" "freshness marker wired (ExecStartPost touches .last_success)"
  else
    "$STH_FAIL" "restic-backups-storage-history has no .last_success marker (ExecStartPost) — backup-coordination pages stale forever with no path to green (cv-backup silent-no-op class)"
  fi

  io_class=$(printf '%s' "$svc_json" | jq -r '.IOSchedulingClass // ""')
  io_prio=$(printf '%s' "$svc_json" | jq -r '.IOSchedulingPriority // ""')
  if [ "$io_class" = "best-effort" ] && [ "$io_prio" = "6" ]; then
    "$STH_PASS" "IO tier wired (IOSchedulingClass=best-effort, IOSchedulingPriority=6 — ioTier.background)"
  else
    "$STH_FAIL" "restic-backups-storage-history IO tier is '${io_class:-absent}/${io_prio:-absent}', not best-effort/6 — nixpkgs' idle class STARVES on this box"
  fi

  mem=$(printf '%s' "$svc_json" | jq -r '.MemoryMax // ""')
  if [ "$mem" = "1G" ]; then
    "$STH_PASS" "MemoryMax=1G wired (restic on a 128G box must not eat the night)"
  else
    "$STH_FAIL" "restic-backups-storage-history MemoryMax is '${mem:-absent}', not 1G"
  fi

  mounts=$(printf '%s' "$unit_json" | jq -r '.RequiresMountsFor // [] | join(" ")')
  if printf '%s' "$mounts" | grep -qw '/mnt/pool'; then
    "$STH_PASS" "mount gate wired (RequiresMountsFor=/mnt/pool — no shadow-dir writes on a detached DAS)"
  else
    "$STH_FAIL" "restic-backups-storage-history lacks RequiresMountsFor=/mnt/pool — with the pool detached restic writes into the shadow dir (split brain)"
  fi

  setup_exec=$(printf '%s' "$setup_json" | jq -r '.ExecStart // ""')
  setup_state=$(printf '%s' "$setup_json" | jq -r '.StateDirectory // ""')
  if printf '%s' "$setup_exec" | grep -q 'restic-storage-history-password-setup' && [ "$setup_state" = "restic-storage-history" ]; then
    "$STH_PASS" "password bootstrap unit wired (restic-storage-history-setup, StateDirectory restic-storage-history)"
  else
    "$STH_FAIL" "restic-storage-history-setup is not the password bootstrap (ExecStart='${setup_exec:-absent}', StateDirectory='${setup_state:-absent}') — the first backup dies asking for a password"
  fi
}

sh_post_deploy() {
  # $1 = deployed unit path, $2 = deployed timer path, $3 = backups.prom path
  local unit_path="$1" timer_path="$2" prom_path="$3"
  local systemctl_cmd="${STH_SYSTEMCTL:-systemctl}"
  local enabled_state setup_state ever

  if [ ! -e "$unit_path" ] || [ ! -e "$timer_path" ]; then
    "$STH_FAIL" "Storage history - deployed unit/timer missing (config ships the history tier enabled; enabled+absent = the switch did not carry it)"
    return 0
  fi

  if grep -q 'ExecStartPost=.*restic-storage-history/.last_success' "$unit_path"; then
    "$STH_PASS" "Storage history - .last_success freshness marker wired (ExecStartPost)"
  else
    "$STH_FAIL" "Storage history - .last_success marker missing from deployed unit - backup-coordination pages stale forever with no path to green (cv-backup silent-no-op class)"
  fi

  if grep -q '^RequiresMountsFor=/mnt/pool' "$unit_path"; then
    "$STH_PASS" "Storage history - mount gate wired (RequiresMountsFor=/mnt/pool)"
  else
    "$STH_FAIL" "Storage history - RequiresMountsFor=/mnt/pool missing - with the pool detached restic writes into the shadow dir (split brain)"
  fi

  if grep -q '^IOSchedulingClass=best-effort' "$unit_path" && grep -q '^IOSchedulingPriority=6' "$unit_path"; then
    "$STH_PASS" "Storage history - IO tier wired (best-effort/6 - ioTier.background)"
  else
    "$STH_FAIL" "Storage history - IO tier not best-effort/6 in the deployed unit - nixpkgs' idle class starves on this box"
  fi

  if grep -q '^OnCalendar=\*-\*-\* 04:20:00' "$timer_path" && grep -q '^Persistent=true' "$timer_path" && grep -q '^RandomizedDelaySec=10m' "$timer_path"; then
    "$STH_PASS" "Storage history - timer shape landed (04:20 nightly, Persistent, 10m jitter)"
  else
    "$STH_FAIL" "Storage history - timer shape wrong in deployed .timer (expected 04:20 + Persistent=true + 10m jitter)"
  fi

  enabled_state=$("$systemctl_cmd" is-enabled restic-backups-storage-history.timer 2>/dev/null || echo "")
  if [ "$enabled_state" = "enabled" ]; then
    "$STH_PASS" "Storage history - timer enabled"
  else
    "$STH_FAIL" "Storage history - timer not enabled ('${enabled_state:-unknown}') - the nightly window never fires"
  fi

  setup_state=$("$systemctl_cmd" is-active restic-storage-history-setup.service 2>/dev/null || echo "")
  if [ "$setup_state" = "active" ]; then
    "$STH_PASS" "Storage history - password bootstrap active (restic-storage-history-setup)"
  else
    "$STH_FAIL" "Storage history - restic-storage-history-setup is '${setup_state:-unknown}', not active - no password means the first backup dies asking for one"
  fi

  if [ -f "$prom_path" ]; then
    if grep -q '^backup_ever_succeeded{backup="storage-history"} ' "$prom_path"; then
      ever=$(sed -n 's/^backup_ever_succeeded{backup="storage-history"} //p' "$prom_path")
      if [ "$ever" = "0" ]; then
        "$STH_WARN" "Storage history - first 04:20 window not completed yet (backup_ever_succeeded=0): backup_healthy/backup_all_healthy stay 0 and the aggregate check stays amber BY DESIGN until the first successful run - re-check after the window (restic first-run row, docs/todo/storage.md)"
      elif grep -q '^backup_healthy{backup="storage-history"} 1' "$prom_path"; then
        "$STH_PASS" "Storage history - backup fresh (backup_healthy=1, marker < 25h)"
      else
        "$STH_FAIL" "Storage history - backup STALE (ever succeeded but older than 25h) - check restic-backups-storage-history journal + /mnt/pool attachment"
      fi
    else
      "$STH_WARN" "Storage history - no backup-coordination row yet in backups.prom (5-min tick pending; still absent after a tick = registry row broke)"
    fi
  else
    "$STH_FAIL" "Storage history - backups.prom missing (backup-health-metrics unit failing; ALL backup freshness unmonitored)"
  fi
}
