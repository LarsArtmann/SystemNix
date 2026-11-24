#!/usr/bin/env bash
# adjudicate-smoke-baseline.sh — remove adjudicated FAIL lines from the
# post-deploy smoke fail baseline, with a rationale log.
#
# The smoke (scripts/post-deploy-check.sh) rewrites
# ~/.local/state/systemnix/smoke-fail-baseline.txt on every FAIL>0 run,
# so a FAIL that was transient or has since been FIXED persists until some
# later FAIL>0 run happens to drop it — and "NEW failures vs baseline"
# mislabels re-runs of the same stale line for that whole window (the
# 2026-10-04 04:29 report: "deploy-exit-3 baseline rots instantly; there
# is no command for 'adjudicate these FAILs as transient/fixed, reset
# baseline'"). This is that command: remove named lines explicitly and
# log the rationale to a sidecar file the next baseline rewrite cannot
# eat, so the decision survives.
#
# Usage:
#   adjudicate-smoke-baseline.sh list
#       Print the current baseline lines with line numbers.
#   adjudicate-smoke-baseline.sh remove <substring> --reason "<why>"
#       Remove every baseline line containing <substring> (fixed string,
#       not regex) and append one rationale line to
#       smoke-fail-baseline-adjudications.log.
#
# Adjudication is for lines whose underlying condition you have VERIFIED
# is fixed or transient — not for silencing a real regression (the smoke
# prints NEW-failure names at exit 3 precisely so they get triaged).
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/systemnix"
baseline="${state_dir}/smoke-fail-baseline.txt"
log="${state_dir}/smoke-fail-baseline-adjudications.log"

usage() {
  echo "usage: adjudicate-smoke-baseline.sh list" >&2
  echo "       adjudicate-smoke-baseline.sh remove <substring> --reason <why>" >&2
  exit 64
}

mode="${1:-}"
[ -n "$mode" ] || usage

case "$mode" in
list)
  if [ ! -f "$baseline" ]; then
    echo "no baseline file at ${baseline} (smoke has not FAILed yet — nothing to adjudicate)"
    exit 0
  fi
  nl -ba "$baseline"
  ;;
remove)
  shift
  pattern="${1:-}"
  [ -n "$pattern" ] || usage
  shift
  [ "${1:-}" = "--reason" ] || usage
  reason="${2:-}"
  [ -n "$reason" ] || usage

  if [ ! -f "$baseline" ]; then
    echo "no baseline file at ${baseline} — nothing to adjudicate"
    exit 0
  fi

  before=$(wc -l <"$baseline")
  # grep exits 1 when nothing matches; that is a legitimate outcome here.
  tmp="$(mktemp "${state_dir}/.smoke-baseline-adjudicate.XXXXXX")"
  grep -vF -- "$pattern" "$baseline" >"$tmp" || true
  after=$(wc -l <"$tmp")

  if [ "$after" -eq "$before" ]; then
    rm -f "$tmp"
    echo "no baseline line contains: ${pattern} (nothing removed)"
    exit 1
  fi

  mv "$tmp" "$baseline"
  removed=$((before - after))
  printf '%s | removed %d line(s) matching: %s | reason: %s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$removed" "$pattern" "$reason" >>"$log"
  echo "removed ${removed} baseline line(s) matching: ${pattern}"
  echo "rationale logged to: ${log}"
  ;;
*)
  usage
  ;;
esac
