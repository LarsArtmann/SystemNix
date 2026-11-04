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

# pass/fail counters live in files, not shell vars: the guard tests run in
# SUBSHELLS (env isolation), and a subshell's variable increment never
# reaches this parent — the 2026-11-04 session watched a FAIL line print
# while the summary said "All tests passed" (lying-green harness).
RESULTS_DIR=$(mktemp -d)
trap 'rm -rf "$RESULTS_DIR"' EXIT
: >"$RESULTS_DIR/passed"
: >"$RESULTS_DIR/failed"

pass() {
  echo "  PASS: $1"
  echo "$1" >>"$RESULTS_DIR/passed"
}
fail() {
  echo "  FAIL: $1" >&2
  echo "$1" >>"$RESULTS_DIR/failed"
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

# ─── Dead Automount Guard ────────────────────────────────────────────────────
echo ""
echo "=== Dead Mount Guard ==="

# Test: no cache vars pointing at the mount -> fast path, values untouched.
(
  export GOCACHE="/some/other/place"
  _bf_dead_mount_guard
  if [[ $GOCACHE == "/some/other/place" ]]; then
    pass "guard: no automount vars -> untouched"
  else
    fail "guard: rewrote an unrelated GOCACHE ($GOCACHE)"
  fi
)

# Test: probe answers instantly (healthy mount or fast ENOENT) -> no rewrite.
(
  export BF_DEAD_MOUNT_PATH="/tmp/bf-healthy-probe-$$"
  export GOCACHE="/tmp/bf-healthy-probe-$$/gocache"
  _bf_dead_mount_guard
  if [[ $GOCACHE == "/tmp/bf-healthy-probe-$$/gocache" ]]; then
    pass "guard: fast probe -> no rewrite"
  else
    fail "guard: rewrote on an instantly-answering path ($GOCACHE)"
  fi
)

# Test: stalled probe (simulated D-state) -> rewrites all four vars to the
# local fallbacks within the poll bound.
(
  export BF_DEAD_MOUNT_PATH="/mnt/buildcache"
  export BF_DEAD_MOUNT_POLLS=2
  export GOCACHE="/mnt/buildcache/go-build"
  export GOMODCACHE="/mnt/buildcache/go-mod"
  export GOLANGCI_LINT_CACHE="/mnt/buildcache/golangci"
  export npm_config_cache="/mnt/buildcache/npm"
  _bf_dead_mount_probe() { sleep 3; } # simulate a D-state stall
  _bf_dead_mount_guard
  local_ok=1
  [[ $GOCACHE == "/tmp/bc-fallback/go-cache" ]] || local_ok=0
  [[ $GOMODCACHE == "$HOME/go/pkg/mod" ]] || local_ok=0
  [[ $GOLANGCI_LINT_CACHE == "/tmp/bc-fallback/go-lint" ]] || local_ok=0
  [[ $npm_config_cache == "/tmp/npm-cache-home" ]] || local_ok=0
  if [[ $local_ok == 1 ]]; then
    pass "guard: stalled probe -> all four vars rewritten to fallbacks"
  else
    fail "guard: rewrite incomplete: GOCACHE=$GOCACHE GOMODCACHE=$GOMODCACHE GOLANGCI=$GOLANGCI_LINT_CACHE npm=$npm_config_cache"
  fi

  # Test: the rewrite disarms the guard (second run is a no-op fast path).
  _bf_dead_mount_probe() { sleep 3; }
  _bf_dead_mount_guard
  if [[ $GOCACHE == "/tmp/bc-fallback/go-cache" ]]; then
    pass "guard: rewrite disarms the guard on re-run"
  else
    fail "guard: re-run touched the already-rewritten value ($GOCACHE)"
  fi
)

# Test: the guard never fires for a var pointing elsewhere while others stall.
(
  export BF_DEAD_MOUNT_PATH="/mnt/buildcache"
  export BF_DEAD_MOUNT_POLLS=2
  export GOCACHE="/custom/gocache"
  export GOMODCACHE="/mnt/buildcache/go-mod"
  _bf_dead_mount_probe() { sleep 3; }
  _bf_dead_mount_guard
  if [[ $GOCACHE == "/custom/gocache" && $GOMODCACHE == "$HOME/go/pkg/mod" ]]; then
    pass "guard: rewrites only the automount-pointing vars"
  else
    fail "guard: wrong selectivity: GOCACHE=$GOCACHE GOMODCACHE=$GOMODCACHE"
  fi
)

echo ""
echo "=== Agent Per-Task Cache Guard ==="

# Fixture HOME + mount so $HOME/.cache paths stay inside the temp tree and the
# mount-identity check has a real mountpoint to confirm.
af_home=$(mktemp -d)
af_mount=$(mktemp -d)
mkdir -p "$af_home/.cache/vra-gocache" "$af_home/.cache/gopls"
ln -s "$af_mount/go-build" "$af_home/.cache/go-build"

# Test: real dir under ~/.cache + healthy mount -> rewritten to agent-caches/.
(
  export HOME="$af_home" BF_DEAD_MOUNT_PATH="$af_mount"
  unset GOLANGCI_LINT_CACHE
  export GOCACHE="$af_home/.cache/vra-gocache"
  # Fixture tmpdirs are not mountpoints — stub the identity check (the
  # non-stubbed identity behavior is asserted by the ENOENT test below).
  _bf_target_is_mount() { return 0; }
  _bf_agent_cache_guard
  expected="$af_mount/agent-caches/vra-gocache"
  if [[ $GOCACHE == "$expected" && -d $expected ]]; then
    pass "agent guard: real ~/.cache dir redirected to mount agent-caches/"
  else
    fail "agent guard: GOCACHE=$GOCACHE (expected $expected + dir created)"
  fi
)

# Test: symlink target under ~/.cache -> untouched (mechanism-independent).
(
  export HOME="$af_home" BF_DEAD_MOUNT_PATH="$af_mount"
  unset GOLANGCI_LINT_CACHE
  export GOCACHE="$af_home/.cache/go-build"
  _bf_target_is_mount() { return 0; }
  _bf_agent_cache_guard
  if [[ $GOCACHE == "$af_home/.cache/go-build" ]]; then
    pass "agent guard: symlink target untouched"
  else
    fail "agent guard: rewrote a symlink target ($GOCACHE)"
  fi
)

# Test: blessed real dir (gopls) -> untouched (NVMe by design).
(
  export HOME="$af_home" BF_DEAD_MOUNT_PATH="$af_mount"
  unset GOLANGCI_LINT_CACHE
  export GOCACHE="$af_home/.cache/gopls"
  _bf_target_is_mount() { return 0; }
  _bf_agent_cache_guard
  if [[ $GOCACHE == "$af_home/.cache/gopls" ]]; then
    pass "agent guard: blessed name (gopls) untouched"
  else
    fail "agent guard: rewrote blessed gopls ($GOCACHE)"
  fi
)

# Test: path outside ~/.cache -> untouched.
(
  export HOME="$af_home" BF_DEAD_MOUNT_PATH="$af_mount"
  unset GOLANGCI_LINT_CACHE
  export GOCACHE="/custom/gocache"
  _bf_target_is_mount() { return 0; }
  _bf_agent_cache_guard
  if [[ $GOCACHE == "/custom/gocache" ]]; then
    pass "agent guard: non-.cache target untouched"
  else
    fail "agent guard: rewrote unrelated GOCACHE ($GOCACHE)"
  fi
)

# Test: mount path NOT a real mountpoint (ENOENT answers the probe) ->
# untouched AND nothing created at the fake path (root-fs contamination class).
(
  export HOME="$af_home"
  export BF_DEAD_MOUNT_PATH="$af_home/no-such-mount"
  unset GOLANGCI_LINT_CACHE
  export GOCACHE="$af_home/.cache/vra-gocache"
  _bf_agent_cache_guard
  if [[ $GOCACHE == "$af_home/.cache/vra-gocache" && ! -e $af_home/no-such-mount ]]; then
    pass "agent guard: nonexistent mount path -> untouched, nothing created"
  else
    fail "agent guard: contaminated non-mount path: GOCACHE=$GOCACHE exists=$(test -e "$af_home/no-such-mount" && echo yes || echo no)"
  fi
)

# Test: idempotent — second run leaves the already-redirected value alone.
(
  export HOME="$af_home" BF_DEAD_MOUNT_PATH="$af_mount"
  unset GOLANGCI_LINT_CACHE
  export GOCACHE="$af_mount/agent-caches/vra-gocache"
  _bf_target_is_mount() { return 0; }
  _bf_agent_cache_guard
  if [[ $GOCACHE == "$af_mount/agent-caches/vra-gocache" ]]; then
    pass "agent guard: idempotent on already-redirected value"
  else
    fail "agent guard: re-run mutated the redirected value ($GOCACHE)"
  fi
)

rm -rf "$af_home" "$af_mount"

echo ""
echo "=== Summary ==="
PASS=$(wc -l <"$RESULTS_DIR/passed")
FAIL=$(wc -l <"$RESULTS_DIR/failed")
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "REGRESSION DETECTED — $FAIL test(s) failed"
  exit 1
fi

echo "All tests passed."
exit 0
