#!/usr/bin/env bash
# Regression test for the smart direnv library (direnv-smart-lib.sh).
#
# Tests use_go_env detection paths (flake.nix fast path, grep fallback with
# vendor exclusion, GOPRIVATE detection, env-respect) and _nix_add_gcroot
# symlink correctness.
#
# Usage: scripts/test-direnv-smart-lib.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../platforms/common/programs/direnv-smart-lib.sh"

if [[ ! -f $LIB ]]; then
  echo "FAIL: library not found at $LIB" >&2
  exit 1
fi

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}
fail() {
  echo "  FAIL: $1" >&2
  FAIL=$((FAIL + 1))
}

# Stub direnv-specific functions so the library sources cleanly outside direnv
log_error() { :; }
log_status() { :; }
_nix() { :; }

# Source the library — defines _nix_add_gcroot and use_go_env
# shellcheck source=/dev/null
source "$LIB"

# Verify functions loaded
if ! declare -f use_go_env >/dev/null 2>&1; then
  echo "FAIL: use_go_env not defined after sourcing library" >&2
  exit 1
fi
if ! declare -f _nix_add_gcroot >/dev/null 2>&1; then
  echo "FAIL: _nix_add_gcroot not defined after sourcing library" >&2
  exit 1
fi

run_in_dir() {
  local dir="$1"
  (
    cd "$dir" || exit 1
    unset GOEXPERIMENT GOPRIVATE
    use_go_env
    echo "GOEXPERIMENT=${GOEXPERIMENT:-UNSET}"
    echo "GOPRIVATE=${GOPRIVATE:-UNSET}"
  )
}

run_with_existing() {
  local dir="$1"
  local ge="$2"
  local gp="$3"
  (
    cd "$dir" || exit 1
    export GOEXPERIMENT="$ge"
    export GOPRIVATE="$gp"
    use_go_env
    echo "GOEXPERIMENT=${GOEXPERIMENT:-UNSET}"
    echo "GOPRIVATE=${GOPRIVATE:-UNSET}"
  )
}

echo "=== use_go_env regression tests ==="
echo ""

# --- Test 1: flake.nix fast path ---
tmpdir=$(mktemp -d)
printf 'GOEXPERIMENT=jsonv2\n' >"$tmpdir/flake.nix"
printf 'module test\n' >"$tmpdir/go.mod"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'GOEXPERIMENT=jsonv2'; then
  pass "flake.nix fast path sets GOEXPERIMENT=jsonv2"
else
  fail "flake.nix fast path did not set GOEXPERIMENT (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 2: grep fallback (source files import json/v2, flake.nix does not mention it) ---
tmpdir=$(mktemp -d)
printf '{ outputs = ...: { }; }\n' >"$tmpdir/flake.nix"
printf 'module test\n' >"$tmpdir/go.mod"
mkdir -p "$tmpdir/cmd"
printf 'package main\n\nimport "encoding/json/v2"\n\nfunc main() {}\n' >"$tmpdir/cmd/main.go"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'GOEXPERIMENT=jsonv2'; then
  pass "grep fallback detects encoding/json/v2 in source files"
else
  fail "grep fallback did not detect json/v2 import (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 3: vendor/ excluded from grep (the performance bug we fixed) ---
tmpdir=$(mktemp -d)
printf '{ outputs = ...: { }; }\n' >"$tmpdir/flake.nix"
printf 'module test\n' >"$tmpdir/go.mod"
mkdir -p "$tmpdir/vendor/encoding/json/v2"
printf 'package jsonv2\n\nimport "encoding/json/v2"\n\nfunc Encode() {}\n' >"$tmpdir/vendor/encoding/json/v2/encoder.go"
printf 'package main\n\nfunc main() {}\n' >"$tmpdir/main.go"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'GOEXPERIMENT=UNSET'; then
  pass "vendor/ excluded from grep — no false positive from vendored deps"
else
  fail "vendor/ not excluded — false positive (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 4: negative case (no json/v2 anywhere) ---
tmpdir=$(mktemp -d)
printf '{ outputs = ...: { }; }\n' >"$tmpdir/flake.nix"
printf 'module test\n' >"$tmpdir/go.mod"
printf 'package main\n\nfunc main() {}\n' >"$tmpdir/main.go"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'GOEXPERIMENT=UNSET'; then
  pass "negative case: no json/v2 → GOEXPERIMENT not set"
else
  fail "negative case: GOEXPERIMENT set without json/v2 (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 5: no flake.nix, no go.mod (non-Go project) ---
tmpdir=$(mktemp -d)
printf 'hello\n' >"$tmpdir/README.md"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'GOEXPERIMENT=UNSET'; then
  pass "non-Go project: no env vars set"
else
  fail "non-Go project: env vars incorrectly set (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 6: GOPRIVATE detection from go.mod (lowercase larsartmann) ---
tmpdir=$(mktemp -d)
printf 'module github.com/larsartmann/test\n' >"$tmpdir/go.mod"
printf 'package main\n\nfunc main() {}\n' >"$tmpdir/main.go"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'GOPRIVATE=github.com/larsartmann/\*'; then
  pass "GOPRIVATE auto-detected from go.mod (larsartmann)"
else
  fail "GOPRIVATE not detected for larsartmann module (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 7: GOPRIVATE detection from go.mod (mixed-case LarsArtmann) ---
tmpdir=$(mktemp -d)
printf 'module github.com/LarsArtmann/test\n' >"$tmpdir/go.mod"
printf 'package main\n\nfunc main() {}\n' >"$tmpdir/main.go"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'LarsArtmann/\*'; then
  pass "GOPRIVATE includes LarsArtmann pattern for mixed-case module"
else
  fail "GOPRIVATE missing LarsArtmann pattern (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 8: GOPRIVATE not set for non-larsartmann modules ---
tmpdir=$(mktemp -d)
printf 'module github.com/example/test\n' >"$tmpdir/go.mod"
printf 'package main\n\nfunc main() {}\n' >"$tmpdir/main.go"
result=$(run_in_dir "$tmpdir")
if echo "$result" | grep -q 'GOPRIVATE=UNSET'; then
  pass "GOPRIVATE not set for non-larsartmann modules"
else
  fail "GOPRIVATE incorrectly set for non-larsartmann module (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 9: existing GOEXPERIMENT respected ---
tmpdir=$(mktemp -d)
printf 'GOEXPERIMENT=jsonv2\n' >"$tmpdir/flake.nix"
printf 'module test\n' >"$tmpdir/go.mod"
result=$(run_with_existing "$tmpdir" "custom_value" "")
if echo "$result" | grep -q 'GOEXPERIMENT=custom_value'; then
  pass "existing GOEXPERIMENT value respected (not overwritten)"
else
  fail "existing GOEXPERIMENT overwritten (got: $result)"
fi
rm -rf "$tmpdir"

# --- Test 10: existing GOPRIVATE respected ---
tmpdir=$(mktemp -d)
printf 'module github.com/larsartmann/test\n' >"$tmpdir/go.mod"
result=$(run_with_existing "$tmpdir" "" "custom_private")
if echo "$result" | grep -q 'GOPRIVATE=custom_private'; then
  pass "existing GOPRIVATE value respected (not overwritten)"
else
  fail "existing GOPRIVATE overwritten (got: $result)"
fi
rm -rf "$tmpdir"

echo ""
echo "=== _nix_add_gcroot override tests ==="
echo ""

# --- Test 11: symlink for /nix/store/* path ---
storepath="/nix/store/abc123fake-test-pkg"
tmpdir=$(mktemp -d)
symlink="$tmpdir/test-gcroot"
_nix_add_gcroot "$storepath" "$symlink"
if [[ -L $symlink ]]; then
  target=$(readlink "$symlink")
  if [[ $target == "$storepath" ]]; then
    pass "_nix_add_gcroot creates correct symlink for /nix/store/* path"
  else
    fail "_nix_add_gcroot symlink target mismatch: $target (expected $storepath)"
  fi
else
  fail "_nix_add_gcroot did not create a symlink for /nix/store/* path"
fi
rm -rf "$tmpdir"

# --- Test 12: symlink overwrites existing ---
storepath="/nix/store/new456fake-test-pkg"
tmpdir=$(mktemp -d)
symlink="$tmpdir/test-gcroot"
ln -s "/nix/store/old123-test-pkg" "$symlink"
_nix_add_gcroot "$storepath" "$symlink"
if [[ -L $symlink ]]; then
  target=$(readlink "$symlink")
  if [[ $target == "$storepath" ]]; then
    pass "_nix_add_gcroot overwrites existing symlink correctly"
  else
    fail "_nix_add_gcroot did not update symlink: $target (expected $storepath)"
  fi
else
  fail "_nix_add_gcroot clobbered symlink type after overwrite"
fi
rm -rf "$tmpdir"

echo ""
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "REGRESSION DETECTED — $FAIL test(s) failed"
  exit 1
fi

echo "All tests passed."
exit 0
