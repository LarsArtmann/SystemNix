#!/usr/bin/env bash
# Fixture selftest for scripts/lib/memory-throttle-sweep.sh (post-deploy
# §17): feeds synthetic cgroupfs trees through the SAME function
# post-deploy-check.sh sources — a throttle must never go silent, and a
# calm tree must never WARN. Exits non-zero on the first violated
# expectation. Wired as checks.<system>.post-deploy-memory-throttle-selftest.
set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/memory-throttle-sweep.sh"
# shellcheck source=lib/memory-throttle-sweep.sh disable=SC1091
source "$LIB"

VERDICTS=()
report_pass() { VERDICTS+=("PASS $*"); }
report_warn() { VERDICTS+=("WARN $*"); }
report_skip() { VERDICTS+=("SKIP $*"); }

fail() { echo "SELFTEST FAIL: $*"; exit 1; }
expect_one() {
  local kind="$1" pattern="$2"
  [ "${#VERDICTS[@]}" -eq 1 ] || fail "expected exactly 1 verdict, got ${#VERDICTS[@]}: ${VERDICTS[*]:-none}"
  [[ "${VERDICTS[0]}" == "$kind"* ]] || fail "expected $kind verdict, got: ${VERDICTS[0]}"
  grep -qE "$pattern" <<<"${VERDICTS[0]}" || fail "verdict '${VERDICTS[0]}' lacks pattern '$pattern'"
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# 1. calm tree: units exist, zero high-counter movement -> exactly one PASS
mkdir -p "$scratch/healthy/a.service" "$scratch/healthy/b.service"
printf 'low 0\nhigh 0\nmax 0\n' >"$scratch/healthy/a.service/memory.events"
printf 'low 0\nhigh 0\nmax 0\n' >"$scratch/healthy/b.service/memory.events"
VERDICTS=()
systemnix_memory_throttle_sweep "$scratch/healthy" 1000
expect_one PASS "no service hit its MemoryHigh"

# 2. loud: count >= threshold -> per-unit WARN naming unit AND count
mkdir -p "$scratch/loud/llama-chat.service"
printf 'low 0\nhigh 46000\nmax 0\n' >"$scratch/loud/llama-chat.service/memory.events"
VERDICTS=()
systemnix_memory_throttle_sweep "$scratch/loud" 1000
expect_one WARN "llama-chat\.service.*46000"

# 3. small: sub-threshold counts -> ONE compact advisory line unit=count
mkdir -p "$scratch/small/btrbk.service"
printf 'high 5\n' >"$scratch/small/btrbk.service/memory.events"
VERDICTS=()
systemnix_memory_throttle_sweep "$scratch/small" 1000
expect_one WARN "sub-threshold.*btrbk\.service=5"

# 4. boundary: count == threshold warns per-unit (>= semantics)
mkdir -p "$scratch/boundary/x.service"
printf 'high 1000\n' >"$scratch/boundary/x.service/memory.events"
VERDICTS=()
systemnix_memory_throttle_sweep "$scratch/boundary" 1000
expect_one WARN "x\.service.*1000"

# 5. mixed loud + small: exactly 2 WARN verdicts, both units surfaced
mkdir -p "$scratch/mixed/big.service" "$scratch/mixed/tiny.service"
printf 'high 20000\n' >"$scratch/mixed/big.service/memory.events"
printf 'high 3\n' >"$scratch/mixed/tiny.service/memory.events"
VERDICTS=()
systemnix_memory_throttle_sweep "$scratch/mixed" 1000
[ "${#VERDICTS[@]}" -eq 2 ] || fail "mixed: expected 2 verdicts, got ${#VERDICTS[@]}: ${VERDICTS[*]}"
joined="${VERDICTS[*]}"
grep -q "big\.service.*20000" <<<"$joined" || fail "mixed: big.service WARN missing: $joined"
grep -q "tiny\.service=3" <<<"$joined" || fail "mixed: tiny.service advisory missing: $joined"

# 6. missing slice dir -> SKIP (unreadable surface must never read as green)
VERDICTS=()
systemnix_memory_throttle_sweep "$scratch/does-not-exist" 1000
expect_one SKIP "not available"

echo "post-deploy-memory-throttle selftest: all fixtures green"
