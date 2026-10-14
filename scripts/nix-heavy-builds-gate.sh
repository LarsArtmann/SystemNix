#!/usr/bin/env bash
# No-heavy-builds admission gate — the ENFORCEMENT leg for the written gate
# the freeze-14→#25 autopsy chain kept catching violated (docs/todo/
# stability.md). Mirrors deploy.sh's IO-pressure + guard-trip-recency veto:
# when the box is stalling (io PSI some avg10 at/over threshold) or the
# memory-emergency-guard tripped within the window, nix eval/build-class
# invocations are REFUSED with a what/why/fix/escape message instead of
# feeding the next thermal/IO death.
#
# Wired as a `nix` PATH shim by modules/nixos/services/
# nix-heavy-builds-gate.nix (real nix is baked by store path — no recursion).
# Escape hatch: NIX_HEAVY_GATE_FORCE=1 (the deploy gate's
# DEPLOY_FORCE_PRESSURE=1 pattern — deploying/building the FIX under
# pressure is sometimes exactly right, it must remain possible, loudly).
#
# Env overrides (selftest harness only):
#   NIX_HEAVY_GATE_PROC      pressure file      (default /proc/pressure/io)
#   NIX_HEAVY_GATE_HISTORY   guard trip history (default <stateDir>/trip-history)
#   NIX_GATE_NOW             epoch override     (default now)
#   NIX_GATE_REAL_NIX        command the gate execs (default the baked store path)
#
# Exit codes: 0/real-nix's own codes passthrough; 12 = gate refusal (the
# deploy.sh pressure-gate code, so scripts can share handling).
set -uo pipefail

PSI_THRESHOLD="${NIX_HEAVY_GATE_PSI:-20}"
TRIP_WINDOW="${NIX_HEAVY_GATE_TRIP_WINDOW:-3600}"
PROC_FILE="${NIX_HEAVY_GATE_PROC:-/proc/pressure/io}"
HISTORY_FILE="${NIX_HEAVY_GATE_HISTORY:-/var/lib/memory-emergency-guard/trip-history}"

if [ "${1:-}" = "selftest" ]; then
  SELFTEST=1
  shift
else
  SELFTEST=0
fi

# The eval/build-class subcommands — the freeze-22 death stack was "just"
# flake evals; eval belongs next to build/check. Everything else (search,
# profile, path-info, --version, …) passes through ungated.
is_gated() {
  local first="$1" second="${2:-}"
  case "$first" in
  build | check | eval | develop | run | shell) return 0 ;;
  flake)
    case "$second" in
    check | build | show) return 0 ;;
    esac
    ;;
  esac
  return 1
}

gate_reason() {
  local psi_avg10 trips now cutoff
  psi_avg10="$(awk '$1 == "some" { for (i = 2; i <= NF; i++) { split($i, kv, "="); if (kv[1] == "avg10") print kv[2] } }' "$PROC_FILE" 2>/dev/null)"
  psi_avg10="${psi_avg10:--1}"
  now="${NIX_GATE_NOW:-$(date +%s)}"
  trips=0
  if [ -f "$HISTORY_FILE" ]; then
    cutoff=$((now - TRIP_WINDOW))
    trips="$(awk -v c="$cutoff" '$1 >= c { n++ } END { print n + 0 }' "$HISTORY_FILE" 2>/dev/null)"
    trips="${trips:-0}"
  fi
  if [ "${psi_avg10%%.*}" -ge "$PSI_THRESHOLD" ] 2>/dev/null; then
    echo "io PSI some avg10 ${psi_avg10}% (threshold ${PSI_THRESHOLD}%)"
    return 0
  fi
  if [ "$trips" -ge 1 ] 2>/dev/null; then
    echo "memory-emergency-guard tripped ${trips}× in the last $((TRIP_WINDOW / 60)) min (episodic IO-storm window, freeze #5/#25 class)"
    return 0
  fi
  return 1
}

if [ "$SELFTEST" -eq 1 ]; then
  selftest() {
    local tmp fails=0
    tmp="$(mktemp -d)"
    local proc="$tmp/pressure" hist="$tmp/trip-history"
    local real="$tmp/real-nix"
    # no /usr/bin/env in the build sandbox — bake the running bash's path
    printf '#!%s\necho REAL-NIX-EXECUTED\n' "$(command -v bash)" >"$real"
    chmod +x "$real"

    run_gate() {
      NIX_HEAVY_GATE_PROC="$proc" NIX_HEAVY_GATE_HISTORY="$hist" \
        NIX_GATE_NOW=1700000000 NIX_GATE_REAL_NIX="$real" \
        bash "$0" "$@"
    }

    # clean box → passes through to real nix
    printf 'some avg10=5.00 avg60=3.00 avg300=2.00 total=1\nfull avg10=1.00 avg60=1.00 avg300=1.00 total=1\n' >"$proc"
    : >"$hist"
    out="$(run_gate build hello 2>&1)"
    rc=$?
    if [ "$rc" -ne 0 ] || [ "$out" != "REAL-NIX-EXECUTED" ]; then
      echo "FAIL: clean box must pass through (rc=$rc out=$out)" >&2
      fails=$((fails + 1))
    fi

    # high PSI → gated nix build refused with exit 12, real nix NOT exec'd
    printf 'some avg10=64.10 avg60=50.00 avg300=40.00 total=1\nfull avg10=30.00 avg60=30.00 avg300=30.00 total=1\n' >"$proc"
    out="$(run_gate build hello 2>&1)"
    rc=$?
    if [ "$rc" -ne 12 ] || [ "$out" = "REAL-NIX-EXECUTED" ]; then
      echo "FAIL: high PSI must refuse build with rc 12 (rc=$rc out=$out)" >&2
      fails=$((fails + 1))
    fi
    case "$out" in
    *"io PSI some avg10"*) : ;;
    *)
      echo "FAIL: refusal must name the PSI reading (out=$out)" >&2
      fails=$((fails + 1))
      ;;
    esac

    # force override → passes through DESPITE high PSI
    out="$(NIX_HEAVY_GATE_FORCE=1 run_gate build hello 2>&1)"
    if [ "$out" != "REAL-NIX-EXECUTED" ]; then
      echo "FAIL: NIX_HEAVY_GATE_FORCE=1 must pass through under pressure (out=$out)" >&2
      fails=$((fails + 1))
    fi

    # PSI-calm but recent trip → gated (the freeze-25 class: dips get raced)
    printf 'some avg10=5.00 avg60=3.00 avg300=2.00 total=1\nfull avg10=1.00 avg60=1.00 avg300=1.00 total=1\n' >"$proc"
    printf '1699999400 6\n1699999300 6\n' >"$hist"
    out="$(run_gate flake check 2>&1)"
    rc=$?
    if [ "$rc" -ne 12 ]; then
      echo "FAIL: recent guard trip must refuse flake check (rc=$rc out=$out)" >&2
      fails=$((fails + 1))
    fi
    case "$out" in
    *"memory-emergency-guard tripped"*) : ;;
    *)
      echo "FAIL: refusal must name the guard trips (out=$out)" >&2
      fails=$((fails + 1))
      ;;
    esac

    # old trips (outside window) → passes
    printf '1690000000 6\n' >"$hist"
    out="$(run_gate flake check 2>&1)"
    if [ "$out" != "REAL-NIX-EXECUTED" ]; then
      echo "FAIL: out-of-window trips must pass (out=$out)" >&2
      fails=$((fails + 1))
    fi

    # non-gated subcommand passes under FULL storm pressure
    printf 'some avg10=99.00 avg60=99.00 avg300=99.00 total=1\nfull avg10=99.00 avg60=99.00 avg300=99.00 total=1\n' >"$proc"
    printf '1700000000 6\n' >"$hist"
    out="$(run_gate search hello 2>&1)"
    if [ "$out" != "REAL-NIX-EXECUTED" ]; then
      echo "FAIL: non-gated subcommand must pass under pressure (out=$out)" >&2
      fails=$((fails + 1))
    fi
    out="$(run_gate --version 2>&1)"
    if [ "$out" != "REAL-NIX-EXECUTED" ]; then
      echo "FAIL: flag-only invocation must pass under pressure (out=$out)" >&2
      fails=$((fails + 1))
    fi

    # missing pressure file → fail-open for the PSI leg (the file can be
    # unreadable in odd sandboxes; the gate must not brick nix), and a
    # missing history file means the guard is absent — no trip leg.
    rm -f "$proc" "$hist"
    out="$(run_gate eval --raw x 2>&1)"
    if [ "$out" != "REAL-NIX-EXECUTED" ]; then
      echo "FAIL: missing proc/history must fail-open (out=$out)" >&2
      fails=$((fails + 1))
    fi

    rm -rf "$tmp"
    if [ "$fails" -gt 0 ]; then
      echo "nix-heavy-builds-gate selftest: $fails failure(s)" >&2
      exit 1
    fi
    echo "nix-heavy-builds-gate selftest: OK (clean pass, PSI block, trip block, force, window, passthrough, fail-open)"
  }
  selftest
  exit $?
fi

# --- live gate path ---
REAL_NIX="${NIX_GATE_REAL_NIX:-@realNix@}"

# Resolve the first non-flag argument as the subcommand.
SUB=""
NEXT_IS_SUB=1
for arg in "$@"; do
  case "$arg" in
  -*) continue ;;
  *)
    if [ "$NEXT_IS_SUB" = "1" ]; then
      SUB="$arg"
      SECOND_PENDING=1
      NEXT_IS_SUB=0
      continue
    elif [ "${SECOND_PENDING:-0}" = "1" ] && [ "$SUB" = "flake" ]; then
      SECOND="$arg"
      SECOND_PENDING=0
    fi
    ;;
  esac
done

if is_gated "${SUB:-}" "${SECOND:-}" &&
  [ "${NIX_HEAVY_GATE_FORCE:-0}" != "1" ]; then
  reason="$(gate_reason)" || reason=""
  if [ -n "$reason" ]; then
    {
      echo "✗ nix ${SUB}${SECOND:+ $SECOND} REFUSED by the no-heavy-builds gate: $reason"
      echo "  WHY: heavy eval/build load into a stalled box is the freeze-14→#25 death class (IO/thermal livelock, no warning)."
      echo "  FIX: wait for the storm to drain (watch /proc/pressure/io, avg10 < ${PSI_THRESHOLD}%, and 60 min past the last guard trip), then re-run."
      echo "  ESCAPE: the gate is cooperative — NIX_HEAVY_GATE_FORCE=1 nix ${SUB}${SECOND:+ $SECOND} bypasses it (building the FIX under pressure is sometimes exactly right; say so out loud when you do)."
    } >&2
    exit 12
  fi
fi

exec "$REAL_NIX" "$@"
