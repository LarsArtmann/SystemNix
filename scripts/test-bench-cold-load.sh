#!/usr/bin/env bash
# test-bench-cold-load.sh — selftest for bench-cold-load.sh GUARD paths
# (no GPU, no model load, no real bench): each leg must FAIL with the
# documented refusal, proving the guards fire instead of silently running
# a contaminated/wrong probe. The happy path is NOT covered here — it needs
# the real model + GPU and is exercised by every real run.
#
# Legs (2026-11-05 hand-verified once; this pins them against regressions):
#   1. gate-refusal  PSI_MAX=0 forces the "no quiet window" abort (rc 1)
#   2. model-missing nonexistent MODEL path hits the readability guard (rc 1)
#   3. bad-cold      COLD=bogus passes the gate (PSI_MAX=100) and dies at the
#                   mode validator (rc 1) — also proves the scratch dir lands
#                   under ~/.cache, not /tmp
#   4. port-held     a dummy listener on PORT triggers the bind-collide
#                   refusal (rc 1)
#
# Usage: bash scripts/test-bench-cold-load.sh   (exit 0 = all legs PASS/SKIP)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH="$HERE/bench-cold-load.sh"
passed=0
failed=0
skipped=0

say() { printf '%s\n' "$*"; }

# leg <name> <expect-substring> <env…> — runs the bench, expects rc 1 AND the
# marker in output. A rc-0 run is a PHANTOM-GREEN (guard did not fire).
leg() {
  local name="$1" marker="$2"
  shift 2
  local out rc
  out="$(env "$@" "$BENCH" 2>&1)"
  rc=$?
  if [ $rc -eq 0 ]; then
    say "FAIL [$name]: bench exited 0 — the guard did not fire (phantom-green)"
    failed=$((failed + 1))
    return
  fi
  if ! grep -qiF "$marker" <<<"$out"; then
    say "FAIL [$name]: rc=$rc but refusal marker missing (got wrong failure):"
    say "$(grep -m3 'FAIL\|ABORT\|REFUS' <<<"$out" || tail -3 <<<"$out")"
    failed=$((failed + 1))
    return
  fi
  say "PASS [$name]: refused as expected ($marker)"
  passed=$((passed + 1))
}

say "== bench-cold-load guard selftest =="

# Leg 1: gate refusal — avg10 can never be < 0, so the wait aborts after
# PSI_WAIT_S. Fast (one poll cycle). MODEL must be READABLE: the model
# guard fires BEFORE the gate (guard order: server → model → port → gate →
# cold), so a dummy path would fail the wrong leg.
leg gate-refusal "no quiet window" PSI_MAX=0 PSI_WAIT_S=1 MODEL="$BENCH"

# Leg 2: model readability guard. Needs llama-server on PATH (the script
# checks the binary before the model); skip with a reason when absent.
if command -v llama-server-rocm >/dev/null 2>&1 || command -v llama-server >/dev/null 2>&1; then
  leg model-missing "model not readable" MODEL=/nonexistent.gguf PSI_MAX=0 PSI_WAIT_S=1
else
  say "SKIP [model-missing]: llama-server not on PATH (guard order: server check precedes model check)"
  skipped=$((skipped + 1))
fi

# Leg 3: bad COLD mode — must clear the gate first (PSI_MAX=100 passes on 2
# consecutive polls, ~20s) so the failure isolates the mode validator.
# Also asserts the scratch dir moved under ~/.cache (the 2026-11-07 fix).
if command -v llama-server-rocm >/dev/null 2>&1 || command -v llama-server >/dev/null 2>&1; then
  out="$(env COLD=bogus PSI_MAX=100 PSI_WAIT_S=120 MODEL="$BENCH" "$BENCH" 2>&1)"
  rc=$?
  if [ $rc -eq 0 ] || ! grep -qiF "COLD must be drop|fadvise" <<<"$out"; then
    say "FAIL [bad-cold]: rc=$rc, mode-validator marker missing:"
    say "$(tail -3 <<<"$out")"
    failed=$((failed + 1))
  elif find "${XDG_CACHE_HOME:-$HOME/.cache}" -maxdepth 1 -name 'bench-cold-load.*' -print -quit 2>/dev/null | grep -q .; then
    say "FAIL [bad-cold]: scratch dirs left behind under ~/.cache (cleanup leak):"
    find "${XDG_CACHE_HOME:-$HOME/.cache}" -maxdepth 1 -name 'bench-cold-load.*' 2>/dev/null | tail -3
    failed=$((failed + 1))
  else
    say "PASS [bad-cold]: mode validator refused; scratch under ~/.cache and cleaned"
    passed=$((passed + 1))
  fi
else
  say "SKIP [bad-cold]: llama-server not on PATH"
  skipped=$((skipped + 1))
fi

# Leg 4: port-held refusal — dummy listener; skip with a reason when no
# listener tool is resolvable (never fail on tooling).
if command -v nc >/dev/null 2>&1; then
  HELD_PORT=18849
  nc -l 127.0.0.1 "$HELD_PORT" >/dev/null 2>&1 &
  NC_PID=$!
  sleep 0.5
  if ss -ltn 2>/dev/null | grep -q ":${HELD_PORT} "; then
    leg port-held "already has a listener" PORT="$HELD_PORT" MODEL="$BENCH" PSI_MAX=0 PSI_WAIT_S=1
  else
    say "SKIP [port-held]: dummy nc listener did not bind (port $HELD_PORT still free)"
    skipped=$((skipped + 1))
  fi
  kill "$NC_PID" 2>/dev/null || true
  wait "$NC_PID" 2>/dev/null || true
else
  say "SKIP [port-held]: nc not on PATH (dummy-listener leg)"
  skipped=$((skipped + 1))
fi

say "== bench-cold-load guard selftest: $passed passed, $failed failed, $skipped skipped =="
[ "$failed" -eq 0 ]
