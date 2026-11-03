#!/usr/bin/env bash
# Fixture tests for the sops pre-deploy gate (pre-deploy §19).
#
# These fixtures invoke scripts/sops-predeploy-gate.sh itself through stub
# nix/ssh-to-age/sops/sudo binaries and assert its verdict stream + exit
# codes (§15/§18 pattern — never a grep of the gate's own copy). The
# 2026-08-18 20:03 class (declared key absent from the encrypted file) and
# the host-key rotation drift class MUST fail; the sudo-skip path MUST warn
# visibly and never fail; the attrpath contract (manifest build via
# system.build.sops-nix-manifest) is pinned through the stubbed nix args.
#
# Fixtures prove each branch:
#   all green (nix ok, recipient bound, sudo cached, decrypt ok) -> rc 0, 3x PASS
#   manifest build red                                        -> rc 1, FAIL manifest
#   live recipient absent from .sops.yaml                     -> rc 1, FAIL rotation drift
#   ssh-to-age derive failure                                 -> rc 1, FAIL cannot derive
#   sudo not cached                                           -> rc 0, WARN visible, legs 1+2 only
#   one sops file fails to decrypt                            -> rc 1, FAIL names the file
#   nix called with the manifest attrpath                     -> pinned via stub arg log
# Run: bash scripts/test-predeploy-sops.sh
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GATE="$REPO_ROOT/scripts/sops-predeploy-gate.sh"

TEST_FAILURES=0
CASE_N=0

expect() {
  local want_desc="$1" got="$2" want="$3"
  CASE_N=$((CASE_N + 1))
  if [ "$got" = "$want" ]; then
    echo "  ok   [case $CASE_N] $want_desc"
  else
    echo "  FAIL [case $CASE_N] $want_desc (want: $want, got: $got)"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

expect_contains() {
  local want_desc="$1" haystack="$2" needle="$3"
  CASE_N=$((CASE_N + 1))
  if printf '%s' "$haystack" | grep -q "$needle"; then
    echo "  ok   [case $CASE_N] $want_desc"
  else
    echo "  FAIL [case $CASE_N] $want_desc (missing: $needle)"
    echo "------- output was -------"
    printf '%s\n' "$haystack" | sed 's/^/  /'
    echo "--------------------------"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

RECIPIENT="age1testrecipientaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
FAKE_HOST_KEY="-----BEGIN OPENSSH PRIVATE KEY-----fixture"

# make_fixtures <sops_yaml_has_recipient:0|1>
# Sets up scratch dir + stub bin dir. Echoes the scratch dir path.
make_fixtures() {
  local has_recipient="$1"
  local scratch
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/sops-gate-test.XXXXXX")
  mkdir -p "$scratch/bin" "$scratch/secrets"
  printf 'fixture-secret: ENC[AES256_GCM,data:aaa,a:aaa]\nsops:\n    age:\n        - recipient: %s\n          enc: |\n            aaa\n' "$RECIPIENT" >"$scratch/secrets/one.yaml"
  printf 'other-secret: ENC[AES256_GCM,data:bbb,a:bbb]\nsops:\n    age:\n        - recipient: %s\n          enc: |\n            bbb\n' "$RECIPIENT" >"$scratch/secrets/two.yaml"

  if [ "$has_recipient" = "1" ]; then
    printf 'keys:\n  - &evo-x2 %s\ncreation_rules:\n  - path_regex: x\n    key_groups:\n      - age:\n          - *evo-x2\n' "$RECIPIENT" >"$scratch/.sops.yaml"
  else
    printf 'keys:\n  - &other age1otherkeycccccccccccccccccccccccccccccc\ncreation_rules:\n  - path_regex: x\n    key_groups:\n      - age:\n          - *other\n' >"$scratch/.sops.yaml"
  fi

  cat >"$scratch/bin/nix" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\$NIX_ARG_LOG"
if [ "\${NIX_RC:-0}" = "0" ]; then
  echo "/nix/store/fixture-manifest.json"
  exit 0
fi
echo "error: fixture manifest build failure (missing key name in encrypted file)"
exit 1
EOF
  cat >"$scratch/bin/ssh-to-age" <<EOF
#!/usr/bin/env bash
if [ "\$#" = "0" ]; then
  if [ "\${SSH_TO_AGE_RC:-0}" != "0" ]; then exit 1; fi
  echo "$RECIPIENT"
  exit 0
fi
if [ "\$1" = "-private-key" ]; then
  input=\$(cat)
  if [ "\$input" = "$FAKE_HOST_KEY" ]; then
    echo "AGE-SECRET-KEY-1FIXTURE"
    exit 0
  fi
  exit 1
fi
exit 1
EOF
  cat >"$scratch/bin/sops" <<EOF
#!/usr/bin/env bash
printf 'sops %s\n' "\$*" >> "\$SOPS_CALL_LOG"
exit "\${SOPS_RC:-0}"
EOF
  cat >"$scratch/bin/sudo" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "-n" ] && [ "\$2" = "true" ]; then
  exit "\${SUDO_RC:-0}"
fi
if [ "\$1" = "-n" ] && [ "\$2" = "cat" ]; then
  if [ -f "\$3" ]; then cat "\$3"; exit 0; fi
  exit 1
fi
exit 1
EOF
  printf '%s' "$FAKE_HOST_KEY" >"$scratch/host_key"
  printf '%s' "$FAKE_HOST_KEY" >"$scratch/host_key.pub"
  chmod +x "$scratch/bin/"*
  echo "$scratch"
}

echo "== sops-predeploy-gate fixtures =="

# Case 1: all green
scratch=$(make_fixtures 1)
export NIX_ARG_LOG="$scratch/nix_args.log"
export SOPS_CALL_LOG="$scratch/sops_calls.log"
: >"$NIX_ARG_LOG"
: >"$SOPS_CALL_LOG"
GATE_OUT=""
GATE_RC=0
GATE_OUT=$(
  SOPS_GATE_NIX="$scratch/bin/nix" SOPS_GATE_BIN_DIR="$scratch/bin" \
    SOPS_GATE_SOPS_YAML="$scratch/.sops.yaml" SOPS_GATE_SECRETS_DIR="$scratch/secrets" \
    SOPS_GATE_HOST_KEY_PUB="$scratch/host_key.pub" SOPS_GATE_HOST_KEY="$scratch/host_key" \
    bash "$GATE" 2>&1
) || GATE_RC=$?
expect "all-green exit code" "$GATE_RC" "0"
expect "all-green: three PASS legs" "$(printf '%s\n' "$GATE_OUT" | grep -c '^PASS:')" "3"
expect "all-green: zero FAIL legs" "$(printf '%s\n' "$GATE_OUT" | grep -c '^FAIL:')" "0"
expect_contains "all-green: decrypt smoke covered both files" "$(cat "$SOPS_CALL_LOG")" "one.yaml"
expect_contains "all-green: decrypt smoke covered two.yaml" "$(cat "$SOPS_CALL_LOG")" "two.yaml"
expect_contains "attrpath pin: manifest attr via nix build" "$(cat "$NIX_ARG_LOG")" "nixosConfigurations.evo-x2.config.system.build.sops-nix-manifest"
rm -rf "$scratch"

# Case 2: manifest build red
scratch=$(make_fixtures 1)
GATE_OUT=""
GATE_RC=0
GATE_OUT=$(
  NIX_RC=1 SOPS_GATE_NIX="$scratch/bin/nix" SOPS_GATE_BIN_DIR="$scratch/bin" \
    SOPS_GATE_SOPS_YAML="$scratch/.sops.yaml" SOPS_GATE_SECRETS_DIR="$scratch/secrets" \
    SOPS_GATE_HOST_KEY_PUB="$scratch/host_key.pub" SOPS_GATE_HOST_KEY="$scratch/host_key" \
    bash "$GATE" 2>&1
) || GATE_RC=$?
expect "manifest-red exit code" "$GATE_RC" "1"
expect_contains "manifest-red: FAIL names the manifest build" "$GATE_OUT" "FAIL: sops manifest build failed"
rm -rf "$scratch"

# Case 3: live recipient absent from .sops.yaml (host-key rotation drift)
scratch=$(make_fixtures 0)
GATE_OUT=""
GATE_RC=0
GATE_OUT=$(
  SOPS_GATE_NIX="$scratch/bin/nix" SOPS_GATE_BIN_DIR="$scratch/bin" \
    SOPS_GATE_SOPS_YAML="$scratch/.sops.yaml" SOPS_GATE_SECRETS_DIR="$scratch/secrets" \
    SOPS_GATE_HOST_KEY_PUB="$scratch/host_key.pub" SOPS_GATE_HOST_KEY="$scratch/host_key" \
    bash "$GATE" 2>&1
) || GATE_RC=$?
expect "recipient-drift exit code" "$GATE_RC" "1"
expect_contains "recipient-drift: FAIL names the drift" "$GATE_OUT" "NOT in"
rm -rf "$scratch"

# Case 4: ssh-to-age derive failure
scratch=$(make_fixtures 1)
GATE_OUT=""
GATE_RC=0
GATE_OUT=$(
  SSH_TO_AGE_RC=1 SOPS_GATE_NIX="$scratch/bin/nix" SOPS_GATE_BIN_DIR="$scratch/bin" \
    SOPS_GATE_SOPS_YAML="$scratch/.sops.yaml" SOPS_GATE_SECRETS_DIR="$scratch/secrets" \
    SOPS_GATE_HOST_KEY_PUB="$scratch/host_key.pub" SOPS_GATE_HOST_KEY="$scratch/host_key" \
    bash "$GATE" 2>&1
) || GATE_RC=$?
expect "derive-fail exit code" "$GATE_RC" "1"
expect_contains "derive-fail: FAIL names derivation" "$GATE_OUT" "cannot derive the live age recipient"
rm -rf "$scratch"

# Case 5: sudo not cached — visible WARN, legs 1+2 still run, never fail
scratch=$(make_fixtures 1)
GATE_OUT=""
GATE_RC=0
GATE_OUT=$(
  SUDO_RC=1 SOPS_GATE_NIX="$scratch/bin/nix" SOPS_GATE_BIN_DIR="$scratch/bin" \
    SOPS_GATE_SOPS_YAML="$scratch/.sops.yaml" SOPS_GATE_SECRETS_DIR="$scratch/secrets" \
    SOPS_GATE_HOST_KEY_PUB="$scratch/host_key.pub" SOPS_GATE_HOST_KEY="$scratch/host_key" \
    bash "$GATE" 2>&1
) || GATE_RC=$?
expect "sudo-skip exit code (warn-only)" "$GATE_RC" "0"
expect "sudo-skip: exactly one WARN" "$(printf '%s\n' "$GATE_OUT" | grep -c '^WARN:')" "1"
expect "sudo-skip: legs 1+2 still PASS" "$(printf '%s\n' "$GATE_OUT" | grep -c '^PASS:')" "2"
expect_contains "sudo-skip: WARN is visible, names sudo" "$GATE_OUT" "WARN: sudo not cached"
rm -rf "$scratch"

# Case 6: one sops file fails to decrypt
scratch=$(make_fixtures 1)
GATE_OUT=""
GATE_RC=0
GATE_OUT=$(
  SOPS_RC=1 SOPS_GATE_NIX="$scratch/bin/nix" SOPS_GATE_BIN_DIR="$scratch/bin" \
    SOPS_GATE_SOPS_YAML="$scratch/.sops.yaml" SOPS_GATE_SECRETS_DIR="$scratch/secrets" \
    SOPS_GATE_HOST_KEY_PUB="$scratch/host_key.pub" SOPS_GATE_HOST_KEY="$scratch/host_key" \
    bash "$GATE" 2>&1
) || GATE_RC=$?
expect "decrypt-fail exit code" "$GATE_RC" "1"
expect_contains "decrypt-fail: FAIL names the file" "$GATE_OUT" "does not decrypt with the live host key"
rm -rf "$scratch"

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "sops-predeploy-gate fixtures: $TEST_FAILURES FAILURE(S) out of $CASE_N"
  exit 1
fi
echo "sops-predeploy-gate fixtures: all $CASE_N green"
