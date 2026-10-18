#!/usr/bin/env bash
# plan-marker.sh — write/update the EXECUTING tombstone in a plan file's header.
#
# The twin-executor guard (2026-10-18): two instances of the same conversation
# executed one plan in parallel for ~3h because nothing answered "is anyone on
# this?". The tombstone line in the plan header is that answer. See AGENTS.md
# Session Discipline "Plan-execution tombstone".
#
# Usage:
#   scripts/plan-marker.sh docs/planning/<file>.md start [instance-note]
#   scripts/plan-marker.sh docs/planning/<file>.md done  [instance-note]
set -euo pipefail

[ $# -ge 2 ] || {
  echo "usage: $0 <plan-file> start|done [instance-note]" >&2
  exit 2
}
plan=$1
mode=$2
note=${3:-instance-?}
[ -f "$plan" ] || {
  echo "plan file not found: $plan" >&2
  exit 1
}

ts=$(date +"%Y-%m-%d %H:%M %Z")
short=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")

marker_re='^\*\*EXECUT(ING|ED) '
line_start="**EXECUTING (instance ${note}, ${ts}, HEAD \`${short}\`):** executing (see AGENTS.md plan-execution tombstone)"
line_done="**EXECUTED (instance ${note}, ${ts}, HEAD \`${short}\`):** execution finished"

if grep -qE "$marker_re" "$plan"; then
  tmp=$(mktemp)
  # NB: '@' delimiter — the marker regex itself contains '|' (the ING|ED
  # alternation), which would terminate a '|'-delimited s expression.
  if [ "$mode" = "start" ]; then
    sed -E "s@${marker_re}.*@${line_start}@" "$plan" >"$tmp"
  else
    sed -E "s@${marker_re}.*@${line_done}@" "$plan" >"$tmp"
  fi
  mv "$tmp" "$plan"
else
  # No tombstone yet: insert right after the **Created:** header line
  # (every plan in docs/planning/ carries one; refuse loudly otherwise —
  # a marker appended to an arbitrary body position is worse than none).
  if ! grep -q '^\*\*Created:\*\*' "$plan"; then
    echo "refusing: $plan has no '**Created:**' header line to anchor the marker" >&2
    exit 1
  fi
  if [ "$mode" = "start" ]; then
    tmp=$(mktemp)
    sed -E "0,/^(\*\*Created:\*\*.*)$/s||\\1\n${line_start}|" "$plan" >"$tmp"
    mv "$tmp" "$plan"
  else
    tmp=$(mktemp)
    sed -E "0,/^(\*\*Created:\*\*.*)$/s||\\1\n${line_done}|" "$plan" >"$tmp"
    mv "$tmp" "$plan"
  fi
fi

echo "marker written to $plan — COMMIT it now (the marker only guards if it is on disk for the next reader)"
