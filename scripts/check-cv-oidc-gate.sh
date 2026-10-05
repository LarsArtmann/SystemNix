#!/usr/bin/env bash
# cv-oidc-gate contract test (selftesting) — locks the deploy.sh cv-server
# anti-replay gate against regression: when the OIDC env secret did NOT
# rotate, deploy output must carry the byte-stable line
#   "cv OIDC env unchanged — cv-server NOT restarted (avoids CRM replay duplication)"
# and cv-server must NOT be restarted (the function returns skip). A reverted
# or weakened gate silently re-duplicates CRM opportunities on EVERY deploy
# (10,489 dups, 2026-10-03 16:17) — this check fails on both the decision
# logic and the deploy.sh wiring.
#
# Selftesting (house pattern: check-buildcache-known-parity): --selftest runs
# the check against the real files AND against deliberately-drifted copies,
# asserting the guard FAILS on each drift shape (inverted decision, unwired
# deploy call, missing function).
#
# Usage: check-cv-oidc-gate.sh [--selftest] [cv-oidc-gate.sh deploy.sh]
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
default_gate_lib="$repo_root/scripts/lib/cv-oidc-gate.sh"
default_deploy="$repo_root/scripts/deploy.sh"

UNCHANGED_LINE="cv OIDC env unchanged — cv-server NOT restarted (avoids CRM replay duplication)"
RESTART_LINE="Restarting cv-oidc-env.service + cv-server.service (OIDC client secret changed)"

selftest=false
positional=()
for arg in "$@"; do
  case $arg in
  --selftest) selftest=true ;;
  *) positional+=("$arg") ;;
  esac
done

fail() {
  echo "CV-OIDC-GATE FAIL: $*" >&2
  exit 1
}

run_check() {
  local gate_lib="$1" deploy_sh="$2"
  [ -f "$gate_lib" ] || fail "gate lib not found: $gate_lib"
  [ -f "$deploy_sh" ] || fail "deploy.sh not found: $deploy_sh"

  # shellcheck source=scripts/lib/cv-oidc-gate.sh
  source "$gate_lib"
  [ "$(type -t cv_oidc_gate_decide)" = "function" ] || fail "gate lib defines no cv_oidc_gate_decide function"

  local out rc
  probe() {
    out="$(cv_oidc_gate_decide "$1" "$2")" && rc=0 || rc=1
  }

  # The anti-replay contract: same sha → unchanged line + skip.
  probe "abc123  /var/lib/cv-oidc/client-secret.env" "abc123  /var/lib/cv-oidc/client-secret.env"
  [ "$out" = "$UNCHANGED_LINE" ] || fail "unchanged sha pair printed '$out' (want the byte-stable unchanged line)"
  [ "$rc" -eq 1 ] || fail "unchanged sha pair must return skip (1), got $rc — cv-server would restart on every deploy"

  # Rotation → restart line + go.
  probe "abc123  /var/lib/cv-oidc/client-secret.env" "def456  /var/lib/cv-oidc/client-secret.env"
  [ "$out" = "$RESTART_LINE" ] || fail "rotated sha pair printed '$out' (want the restart line)"
  [ "$rc" -eq 0 ] || fail "rotated sha pair must return restart (0), got $rc"

  # File appearing / vanishing across the converge restart is a change.
  probe "absent" "def456  /var/lib/cv-oidc/client-secret.env"
  [ "$rc" -eq 0 ] || fail "absent→hash must return restart (0), got $rc"
  probe "abc123  /var/lib/cv-oidc/client-secret.env" "absent"
  [ "$rc" -eq 0 ] || fail "hash→absent must return restart (0), got $rc"

  # Wiring: deploy.sh must actually source the lib, call the function with
  # the before/after shas, keep the sha plumbing, and restart cv-server only
  # inside the gate's then-branch (grep-level lock — a deleted gate is the
  # regression class this row exists for).
  grep -q "lib/cv-oidc-gate.sh" "$deploy_sh" || fail "deploy.sh no longer sources lib/cv-oidc-gate.sh"
  grep -q 'cv_oidc_gate_decide "\$cv_before" "\$cv_after"' "$deploy_sh" || fail 'deploy.sh no longer calls cv_oidc_gate_decide $cv_before $cv_after'
  grep -q 'cv_before=.*sha256sum "\$cv_env"' "$deploy_sh" || fail "deploy.sh lost the cv_before sha256sum plumbing"
  grep -q 'cv_after=.*sha256sum "\$cv_env"' "$deploy_sh" || fail "deploy.sh lost the cv_after sha256sum plumbing"

  echo "CV-OIDC-GATE OK: decision contract holds (unchanged→skip, rotated→restart, absent-edge→restart) and deploy.sh wiring intact"
}

expect_fail() {
  local label="$1"
  shift
  # Subshell: fail() exits, and that exit must be contained to the probe.
  if (run_check "$@") >/dev/null 2>&1; then
    fail "selftest: guard did NOT detect drift shape '$label' — the guard is dead"
  fi
  echo "selftest: guard correctly rejected drift shape '$label'"
}

gate_lib="${positional[0]:-$default_gate_lib}"
deploy_sh="${positional[1]:-$default_deploy}"

if ! $selftest; then
  run_check "$gate_lib" "$deploy_sh"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat "$gate_lib" >"$work/gate.sh"
cat "$deploy_sh" >"$work/deploy.sh"

echo "selftest: positive control (real files)"
run_check "$work/gate.sh" "$work/deploy.sh"

echo "selftest: drift shape 1 — inverted decision (unchanged pair restarts)"
sed -i 's/if \[ "\$1" != "\$2" \]; then/if [ "$1" = "$2" ]; then/' "$work/gate.sh"
expect_fail "inverted decision" "$work/gate.sh" "$work/deploy.sh"
cat "$gate_lib" >"$work/gate.sh"

echo "selftest: drift shape 2 — unchanged line reworded"
sed -i "s|cv OIDC env unchanged — cv-server NOT restarted (avoids CRM replay duplication)|cv oidc env same|" "$work/gate.sh"
if (run_check "$work/gate.sh" "$work/deploy.sh") >/dev/null 2>&1; then
  fail "selftest: guard did NOT detect drift shape 'unchanged line reworded'"
fi
echo "selftest: guard correctly rejected drift shape 'unchanged line reworded'"
cat "$gate_lib" >"$work/gate.sh"

echo "selftest: drift shape 3 — deploy.sh gate unwired (call removed)"
sed -i 's|if cv_oidc_gate_decide "\$cv_before" "\$cv_after"; then|if true; then  # gate reverted|' "$work/deploy.sh"
expect_fail "gate unwired" "$work/gate.sh" "$work/deploy.sh"

echo "selftest: drift shape 4 — function deleted from lib"
sed -i '/^cv_oidc_gate_decide() {$/,/^}$/d' "$work/gate.sh"
expect_fail "function deleted" "$work/gate.sh" "$work/deploy.sh"
