#!/usr/bin/env bash
# Kith CRM OIDC readiness smoke — post-deploy §20 (fixture-tested by
# scripts/test-crm-oidc-smoke.sh and the crm-oidc-smoke-selftest flake
# check). Extracted from the inline post-deploy-check.sh block
# (2026-10-12 §b.2): shipped with only the PASS branch live-exercised —
# a FAIL rehearsal would need Pocket ID actually down, so the fixture
# harness is the only cheap exercise the negative branches get.
#
# The verdict is the LAST `oidc sign-in` line since boot (restart heals,
# so tail -1): enabled → PASS, disabled → FAIL (passkey-only degrade,
# legacy binaries only), flags deployed but no line → WARN (restart-loop
# on OIDC init — since 2026-10-17 `-passkeys=false` makes discovery
# boot-fatal, this is the realistic bad state), OIDC not provisioned or
# unit absent → SKIP.
#
# Callers provide the verdict callbacks (single message argument):
#   CRM_PASS CRM_FAIL CRM_WARN CRM_SKIP
# plus CRM_JOURNALCTL (default: journalctl) so fixtures can feed canned
# boot journals without touching the live one.

crm_oidc_smoke() {
  # $1 = deployed crm-server unit file path
  local unit_path="$1"
  local journal_cmd="${CRM_JOURNALCTL:-journalctl}"
  local crm_oidc_line

  if [ ! -f "$unit_path" ]; then
    "$CRM_SKIP" "Kith CRM OIDC - crm-server unit absent (service not deployed)"
    return 0
  fi
  if ! grep -q '\-oidc-issuer' "$unit_path"; then
    "$CRM_SKIP" "Kith CRM OIDC - OIDC not provisioned (passkey-only unit by design)"
    return 0
  fi

  crm_oidc_line="$("$journal_cmd" -u crm-server -b --no-pager 2>/dev/null | grep 'oidc sign-in' | tail -1 || true)"
  case "$crm_oidc_line" in
  *"oidc sign-in enabled"*)
    "$CRM_PASS" "Kith CRM OIDC - Pocket ID sign-in enabled (last start: $crm_oidc_line)"
    ;;
  *"oidc sign-in disabled"*)
    "$CRM_FAIL" "Kith CRM OIDC - sign-in DISABLED (passkey-only degrade live) — restart crm-server once auth.home.lan DNS+Pocket ID are up (run: journalctl -u crm-server -b | grep 'oidc sign-in')"
    ;;
  "")
    "$CRM_WARN" "Kith CRM OIDC - OIDC flags deployed but no readiness line since boot — with -passkeys=false this usually means the unit is restart-looping on OIDC init (run: journalctl -u crm-server -b | tail -20)"
    ;;
  *)
    "$CRM_WARN" "Kith CRM OIDC - unrecognized readiness line: $crm_oidc_line"
    ;;
  esac
}
