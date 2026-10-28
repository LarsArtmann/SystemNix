#!/usr/bin/env bash
# Fixture tests for the post-deploy §22 dnsblockd CA-parity block
# (scripts/lib/ca-parity-smoke.sh). The check exists because the same CA sits
# in two places — a PEM inlined into security.pki.certificates and the sops
# secret the block-page proxy terminates with — and nothing enforced parity.
# Live, both sides agree, so the FAIL and WARN branches have no rehearsal
# path that does not deliberately break real browser trust. These fixtures are
# the only exercise those branches get.
#
# The lib is SOURCED, not re-implemented (the metrics-gate lesson: never trust
# a fixture that greps its own copy of the messages), and the certificates are
# REAL openssl output, so a change in openssl's subject/fingerprint formatting
# fails here instead of silently weakening prod.
#
# Fixtures prove each verdict branch:
#   sops CA file absent                        -> SKIP
#   trust bundle absent                        -> SKIP
#   sops file is not a certificate              -> FAIL
#   CA trusted but a DIFFERENT CA served       -> FAIL (retired key keeps trust)
#   CA served but NOT in the bundle            -> FAIL (trust side lost rotation)
#   identical, single entry, healthy           -> PASS
#   identical but appended twice               -> WARN (two writers, one PEM)
#   identical but expiring within 90 days      -> WARN (trust cliff)
# Run: bash scripts/test-ca-parity-smoke.sh   (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/ca-parity-smoke.sh disable=SC1091
source "$REPO_ROOT/scripts/lib/ca-parity-smoke.sh"

EVENTS=()
ca_pass() { EVENTS+=("PASS"); }
ca_fail() { EVENTS+=("FAIL"); }
ca_warn() { EVENTS+=("WARN"); }
ca_skip() { EVENTS+=("SKIP"); }
# shellcheck disable=SC2034 # CA_* are read inside the sourced lib via indirection
CA_PASS=ca_pass CA_FAIL=ca_fail CA_WARN=ca_warn CA_SKIP=ca_skip

TEST_FAILURES=0
expect() {
  local want="$1" desc="$2"
  if [ "${EVENTS[*]:-}" = "$want" ]; then
    echo "  ok   [$want] $desc"
  else
    echo "  FAIL [$want] $desc (got: ${EVENTS[*]:-none})"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}
reset() { EVENTS=(); }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Two REAL certificate authorities. The "old" one plays the rotated-away key.
mk_ca() {
  local name="$1" days="$2"
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
    -keyout "$SCRATCH/$name.key" -out "$SCRATCH/$name.pem" \
    -days "$days" -subj "/O=DNS Blocker/CN=dnsblockd-CA" >/dev/null 2>&1
  [ -s "$SCRATCH/$name.pem" ]
}
# A third party so the bundle is not trivially just our CA.
openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
  -keyout "$SCRATCH/other.key" -out "$SCRATCH/other.pem" \
  -days 3650 -subj "/O=Unrelated/CN=other-root" >/dev/null 2>&1 || {
  echo "FATAL: cannot generate fixture certificates" >&2
  exit 1
}
mk_ca current 3650 || {
  echo "FATAL: cannot generate the fixture CA" >&2
  exit 1
}
mk_ca expired_soon 1 || {
  echo "FATAL: cannot generate the near-expiry fixture CA" >&2
  exit 1
}

echo "§22 dnsblockd CA parity — verdict branch fixtures"

# 1. sops CA missing (dnsblockd not provisioned / sops not rendered)
reset
CA_PARITY_BUNDLE="$SCRATCH/other-bundle.pem" \
  CA_PARITY_SOPS="$SCRATCH/absent.pem" \
  dnsblockd_ca_parity_smoke
expect SKIP "sops CA absent -> SKIP"

# 2. trust bundle missing
reset
CA_PARITY_BUNDLE="$SCRATCH/absent-bundle.pem" \
  CA_PARITY_SOPS="$SCRATCH/current.pem" \
  dnsblockd_ca_parity_smoke
expect SKIP "trust bundle absent -> SKIP"

# 3. sops file is not a certificate
printf 'not a certificate\n' >"$SCRATCH/garbage.pem"
reset
CA_PARITY_BUNDLE="$SCRATCH/other.pem" \
  CA_PARITY_SOPS="$SCRATCH/garbage.pem" \
  dnsblockd_ca_parity_smoke
expect FAIL "sops file is not a certificate -> FAIL"

# 4. the bundle trusts a DIFFERENT dnsblockd-CA than the proxy serves
cat "$SCRATCH/other.pem" "$SCRATCH/expired_soon.pem" >"$SCRATCH/bundle-stale.pem"
reset
CA_PARITY_BUNDLE="$SCRATCH/bundle-stale.pem" \
  CA_PARITY_SOPS="$SCRATCH/current.pem" \
  dnsblockd_ca_parity_smoke
expect FAIL "retired CA still trusted while a new one is served -> FAIL"

# 5. the proxy serves a CA the host does not trust at all
reset
CA_PARITY_BUNDLE="$SCRATCH/other.pem" \
  CA_PARITY_SOPS="$SCRATCH/current.pem" \
  dnsblockd_ca_parity_smoke
expect FAIL "served CA absent from the trust bundle -> FAIL"

# 6. healthy: identical, single entry, far from expiry
cat "$SCRATCH/other.pem" "$SCRATCH/current.pem" >"$SCRATCH/bundle-ok.pem"
reset
CA_PARITY_BUNDLE="$SCRATCH/bundle-ok.pem" \
  CA_PARITY_SOPS="$SCRATCH/current.pem" \
  dnsblockd_ca_parity_smoke
expect PASS "single identical entry -> PASS"

# 7. identical but appended twice (the live 2026-10-28 state: two writers)
cat "$SCRATCH/other.pem" "$SCRATCH/current.pem" "$SCRATCH/current.pem" \
  >"$SCRATCH/bundle-dup.pem"
reset
CA_PARITY_BUNDLE="$SCRATCH/bundle-dup.pem" \
  CA_PARITY_SOPS="$SCRATCH/current.pem" \
  dnsblockd_ca_parity_smoke
expect WARN "identical CA appended twice -> WARN (split-brain signature)"

# 8. identical but inside the 90-day expiry window
cat "$SCRATCH/other.pem" "$SCRATCH/expired_soon.pem" >"$SCRATCH/bundle-expiring.pem"
reset
CA_PARITY_BUNDLE="$SCRATCH/bundle-expiring.pem" \
  CA_PARITY_SOPS="$SCRATCH/expired_soon.pem" \
  dnsblockd_ca_parity_smoke
expect WARN "identical CA expiring <90d -> WARN"

echo ""
if [ "$TEST_FAILURES" -eq 0 ]; then
  echo "PASS: all 8 dnsblockd CA-parity fixture legs"
  exit 0
fi
echo "FAIL: $TEST_FAILURES dnsblockd CA-parity fixture leg(s)"
exit 1
