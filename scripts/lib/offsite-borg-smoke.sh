#!/usr/bin/env bash
# Offsite Borg go-live smoke logic shared by pre-deploy-check §13 and
# post-deploy-check §16 (fixture-tested by scripts/test-offsite-borg-smoke.sh
# and the offsite-borg-smoke-selftest flake check). Extracted verbatim from
# the inline blocks so the fixture exercises the SAME code the deploy gates
# run — never trust a fixture that greps its own copy of the messages.
#
# Callers provide the verdict callbacks (single message argument):
#   pre:  OB_PASS OB_FAIL OB_SKIP
#   post: OB_PASS OB_FAIL OB_WARN OB_SKIP
# and jq + sed + grep on PATH.

# Classify a §13 eval failure from its raw nix stderr (file argument).
# Echoes "disabled" ONLY for the known attribute-missing shape of the
# borgbackup job path — with the module's mkIf cfg.enable wrapping, a
# disabled services.offsite-borg is simply absent from systemd.services,
# so the legit disabled case surfaces as an eval error naming this exact
# attribute. Anything else (nix daemon restart, store hiccup, real config
# error, substituter noise) is an "anomaly" and the caller must FAIL LOUD
# instead of blind-skipping the go-live gate (a gate that treats every
# eval failure as "disabled" skips precisely the deploy it exists to gate).
ob_classify_eval_error() {
  if grep -q "does not provide attribute.*borgbackup-job-hetzner\.serviceConfig" "$1"; then
    echo "disabled"
  else
    echo "anomaly"
  fi
}

ob_pre_deploy() {
  # $1 = rendered borgbackup-job-hetzner serviceConfig JSON ("" = disabled)
  local svc_json="$1" borg_pre borg_post borg_env
  if [ -z "$svc_json" ]; then
    "$OB_SKIP" "   services.offsite-borg disabled in the to-be-deployed config — units not rendered, skipped"
    return 0
  fi
  borg_pre=$(printf '%s' "$svc_json" | jq -r '.ExecStartPre // ""' 2>/dev/null || echo "")
  borg_post=$(printf '%s' "$svc_json" | jq -r '.ExecStartPost // ""' 2>/dev/null || echo "")
  borg_env=$(printf '%s' "$svc_json" | jq -r '.EnvironmentFile // ""' 2>/dev/null || echo "")
  if printf '%s' "$borg_pre" | grep -q 'borg-offsite-golive-check'; then
    "$OB_PASS" "go-live tripwire wired (ExecStartPre golive-check)"
  else
    "$OB_FAIL" "borgbackup-job-hetzner has no go-live tripwire on ExecStartPre — enabling with a PLACEHOLDER repo fails opaquely instead of pointing at docs/services/offsite-borg.md"
  fi
  if printf '%s' "$borg_post" | grep -q '/var/lib/borg-offsite/.last_success'; then
    "$OB_PASS" "freshness marker wired (ExecStartPost touches .last_success)"
  else
    "$OB_FAIL" "borgbackup-job-hetzner has no .last_success marker (ExecStartPost) — backup-coordination pages stale forever with no path to green (cv-backup silent-no-op class)"
  fi
  if printf '%s' "$borg_env" | grep -q 'borg-env'; then
    "$OB_PASS" "borg-env sops override wired (EnvironmentFile)"
  else
    "$OB_FAIL" "borgbackup-job-hetzner has no borg-env EnvironmentFile — BORG_REPO/BORG_RSH stay at the placeholder and the job dials the go-live.invalid dummy"
  fi
}

ob_post_deploy() {
  # $1 = deployed unit file path, $2 = backup-coordination textfile path
  local unit_path="$1" prom_path="$2" _borg_pre
  if [ ! -e "$unit_path" ]; then
    "$OB_SKIP" "Offsite Borg - not deployed (services.offsite-borg.enable = false)"
    return 0
  fi
  _borg_pre="$(sed -n 's/^ExecStartPre=//p' "$unit_path" | head -1)"
  case "$_borg_pre" in
  *borg-offsite-golive-check*)
    if [ -x "$_borg_pre" ]; then
      "$OB_PASS" "Offsite Borg - go-live tripwire wired and present ($_borg_pre)"
    else
      "$OB_FAIL" "Offsite Borg - tripwire binary not executable/missing ($_borg_pre)"
    fi
    ;;
  *)
    "$OB_FAIL" "Offsite Borg - go-live tripwire missing from ExecStartPre ('$_borg_pre') - enabling with a PLACEHOLDER repo fails opaquely instead of pointing at docs/services/offsite-borg.md"
    ;;
  esac

  if grep -q 'ExecStartPost=.*var/lib/borg-offsite/.last_success' "$unit_path"; then
    "$OB_PASS" "Offsite Borg - .last_success freshness marker wired (ExecStartPost)"
  else
    "$OB_FAIL" "Offsite Borg - .last_success marker wiring missing - backup-coordination pages stale forever with no path to green (cv-backup silent-no-op class)"
  fi

  if grep -q '^EnvironmentFile=/run/secrets/rendered/borg-env' "$unit_path"; then
    "$OB_PASS" "Offsite Borg - borg-env sops override wired (EnvironmentFile)"
  else
    "$OB_FAIL" "Offsite Borg - borg-env EnvironmentFile missing - BORG_REPO/BORG_RSH stay at the placeholder and the job dials the go-live.invalid dummy"
  fi

  if [ -f "$prom_path" ]; then
    if grep -q '^backup_ever_succeeded{backup="offsite-borg"} ' "$prom_path"; then
      "$OB_PASS" "Offsite Borg - backup-coordination row live (backup_ever_succeeded present)"
    else
      "$OB_WARN" "Offsite Borg - no backup-coordination row yet in backups.prom (5-min tick pending; still absent after a tick = registry row broke)"
    fi
  else
    "$OB_FAIL" "Offsite Borg - backups.prom missing (backup-health-metrics unit failing; ALL backup freshness unmonitored)"
  fi
}
