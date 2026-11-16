#!/usr/bin/env bash
# Freshness-composite regression fixtures for the system-health collector's
# sibling-textfile freshness gauges
# (modules/nixos/services/system-health.nix):
#   system_memory_guard_metrics_fresh   (memory-emergency-guard.prom, 2026-09-15)
#   system_niri_metrics_fresh           (niri.prom, 2026-08-24)
#   system_thermal_guard_metrics_fresh  (thermal-pstate-guard.prom, 2026-10-19)
#   system_psi_metrics_fresh            (psi.prom, 2026-11-13)
#
# WHY: every freshness composite shipped fixture-less (the thermal sibling
# was hand-tested at three states during the 2026-10-19 stability trio; the
# other three never). node_exporter serves a textfile's LAST content
# forever, so these mtime composites are the ONLY collector-death detector
# their consumers have — a semantics regression (<=/</age sign/missing-file
# default) silently re-opens the phantom-green class they exist to close
# (freeze #29's 3h20m starved-silent thermal guard is the costed precedent).
#
# What is pinned, per composite, by driving the REAL block extracted from
# the staged module (never a hand-copied twin — the ${textfileDir} seam is
# a plain shell var in the source, so the block runs unmodified):
#   fresh (mtime now)          → 1
#   boundary 300s exactly      → 1 (the budget is `-le 300`, inclusive)
#   boundary 301s              → 0
#   stale (400s)               → 0
#   missing file               → 0 (default-before-if; emission then omits the
#                                line entirely — gatus pat absence fails closed)
#   future mtime (age < 0)     → 0 (the `-ge 0` clock-skew guard: a file
#                                stamped ahead of wall time must NOT read fresh)
# Static wiring pins: each gauge name + the 300-second budget literal must
# stay present in the module.
set -uo pipefail

MODULE="${1:?usage: test-system-health-freshness.sh <path/to/system-health.nix>}"

PASS_CNT=0
FAIL_CNT=0
ok() { PASS_CNT=$((PASS_CNT + 1)); }
bad() {
  echo "FAIL: $1" >&2
  FAIL_CNT=$((FAIL_CNT + 1))
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Extract the REAL freshness blocks from the staged module ────────────
extract_block() { # extract_block <VAR=0-anchor> → dedented shell source on stdout
  local anchor=$1 block
  block="$(sed -n "/^          ${anchor}=0\$/,/^          fi\$/p" "$MODULE")"
  [ -n "$block" ] || {
    bad "wiring: freshness block for ${anchor%%_FRESH} not found in $(basename "$MODULE") — block moved, renamed, or refactored past extraction"
    return 1
  }
  printf '%s\n' "$block" | sed 's/^          //'
}

declare -A BLOCKS
declare -A FILES=(
  [GUARD_FRESH]=memory-emergency-guard.prom
  [NIRI_FRESH]=niri.prom
  [THERMAL_GUARD_FRESH]=thermal-pstate-guard.prom
  [PSI_FRESH]=psi.prom
)
for var in GUARD_FRESH NIRI_FRESH THERMAL_GUARD_FRESH PSI_FRESH; do
  if BLOCKS[$var]="$(extract_block "$var")"; then
    ok
  fi
done

run_block() { # run_block <VAR> <mtime-spec|missing> → prints the gauge value
  local var=$1 mtime=$2 fx prom
  fx="$WORK/state$$"
  prom="$fx/${FILES[$var]}"
  rm -rf "$fx"
  mkdir -p "$fx"
  case "$mtime" in
  missing) ;;
  *)
    echo dummy >"$prom"
    touch -d "$mtime" "$prom"
    ;;
  esac
  textfileDir="$fx" bash -c "${BLOCKS[$var]}"'
    echo "$'"$var"'"
  '
}

assert_val() { # assert_val <desc> <got> <want>
  if [ "$2" = "$3" ]; then ok; else bad "$1: got '$2', want '$3'"; fi
}

for var in GUARD_FRESH NIRI_FRESH THERMAL_GUARD_FRESH PSI_FRESH; do
  [ -n "${BLOCKS[$var]:-}" ] || continue
  assert_val "$var fresh (mtime now)" "$(run_block "$var" "now")" 1
  assert_val "$var boundary 300s exactly (inclusive budget)" "$(run_block "$var" "@$(($(date +%s) - 300))")" 1
  assert_val "$var boundary 301s" "$(run_block "$var" "@$(($(date +%s) - 301))")" 0
  assert_val "$var stale (400s)" "$(run_block "$var" "400 seconds ago")" 0
  assert_val "$var missing file" "$(run_block "$var" "missing")" 0
  assert_val "$var future mtime (clock-skew guard)" "$(run_block "$var" "@$(($(date +%s) + 120))")" 0
done

# ── Static wiring pins: gauge names + the 300s budget stay in the module ──
for gauge in system_memory_guard_metrics_fresh system_niri_metrics_fresh \
  system_thermal_guard_metrics_fresh system_psi_metrics_fresh; do
  if grep -qF "$gauge" "$MODULE"; then ok; else bad "wiring: gauge $gauge missing from module emission"; fi
done
if grep -q '\-le 300' "$MODULE"; then ok; else bad "wiring: the 300s freshness budget literal vanished"; fi

echo "$PASS_CNT passed, $FAIL_CNT failed"
[ "$FAIL_CNT" -eq 0 ] || exit 1
