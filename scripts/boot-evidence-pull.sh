#!/usr/bin/env bash
# boot-evidence-pull.sh — one-command boot-evidence pull (pre-vacuum remedy).
#
# The freeze-27/28 evidence pulls were bespoke journalctl sessions; every
# new boot autopsy re-invented the pipeline by hand. This script
# parameterizes it: resolve a boot selector, dump the boot journal ONCE,
# and emit the CANONICAL sections (boot-boundary lines, census, kernel
# OOM, memory-emergency-guard, thermal THROTTLE, kernel panic/BUG/oops)
# into a commit-ready evidence file under docs/status/tasks/ whose header
# cites the boot id8 in the hex-boundary form the pre-vacuum evidence
# gate greps for (scripts/pre-vacuum-evidence-gate.sh).
#
# journald auto-vacuums at SystemMaxUse (8G on evo-x2) — the journal is
# the only forensic source for a freeze boot; pull BEFORE anything else.
#
# Usage:
#   boot-evidence-pull.sh [-b <boot-spec>] [-o <file>|-]
#     -b <spec>   anything `journalctl -b` resolves: -1 (default), 0, -2,
#                 or a full/prefix boot id
#     -o <file>   output path ('-' = stdout). Default:
#                 docs/status/tasks/<UTC-date-time>_boot-<id8>-evidence-pull.md
#                 An existing target is NEVER overwritten (evidence files
#                 are append-only artifacts) — pick another path.
#   boot-evidence-pull.sh list       journalctl --list-boots
#   boot-evidence-pull.sh selftest   fixture selftest (flake check:
#                                    checks.x86_64-linux.boot-evidence-pull-selftest)
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TASKS_DIR="$REPO_ROOT/docs/status/tasks"

# ── pure helpers (fixture-tested by `selftest`) ──────────────────────────

bep_grep_oom() {
  grep -E 'invoked oom-killer|oom-kill:|Out of memory' "$1" || true
}

bep_grep_guard() {
  grep -F 'memory-emergency-guard' "$1" || true
}

bep_grep_thermal() {
  grep -F 'THERMAL THROTTLE' "$1" || true
}

bep_grep_panic() {
  grep -E 'kernel:.*(panic|BUG|oops)' "$1" || true
}

bep_fenced() {
  # <file> — print the file inside a fenced code block (sections are
  # always fenced even when empty, so the file is grep-stable).
  printf '```\n'
  cat "$1"
  printf '```\n'
}

bep_render() (
  # <journal-dump> <id8> <full-id> <first-ts> <last-ts> — canonical
  # evidence sections on stdout. Pure: reads only its arguments/files,
  # so the selftest can drive it without journalctl. Subshell body so
  # the temp-dir EXIT trap cannot reference a popped function local
  # (bash 5.3 destroys locals BEFORE a RETURN trap runs).
  local dump="$1" id8="$2" fullid="$3" first_ts="$4" last_ts="$5"
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  bep_grep_oom "$dump" >"$tmp/oom"
  bep_grep_guard "$dump" >"$tmp/guard"
  bep_grep_thermal "$dump" >"$tmp/thermal"
  bep_grep_panic "$dump" >"$tmp/panic"

  local n_oom n_guard n_thermal n_panic
  n_oom=$(wc -l <"$tmp/oom")
  n_guard=$(wc -l <"$tmp/guard")
  n_thermal=$(wc -l <"$tmp/thermal")
  n_panic=$(wc -l <"$tmp/panic")

  cat <<EOF
# Boot evidence pull: id8 $id8 (full: $fullid)

Pulled $(date -u '+%Y-%m-%d %H:%M UTC') by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: $first_ts -> $last_ts (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 $id8 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
$(bep_fenced <(head -n 3 "$dump"))

### Last 12 lines
$(bep_fenced <(tail -n 12 "$dump"))

## Census
- oom-lines: $n_oom
- guard-lines (memory-emergency-guard): $n_guard
- thermal-THROTTLE-lines: $n_thermal
- kernel panic/BUG/oops lines: $n_panic

## Kernel OOM lines (all)
$(bep_fenced "$tmp/oom")

## memory-emergency-guard lines (all)
$(bep_fenced "$tmp/guard")

## THERMAL THROTTLE lines
$(bep_fenced "$tmp/thermal")

## Kernel panic/BUG/oops lines
EOF
  if [ "$n_panic" -gt 100 ]; then
    {
      head -n 25 "$tmp/panic"
      echo "... TRUNCATED ($n_panic total; showing first 25 / last 25)"
      tail -n 25 "$tmp/panic"
    } >"$tmp/panic.bounded"
    bep_fenced "$tmp/panic.bounded"
  else
    bep_fenced "$tmp/panic"
  fi
)

bep_write() {
  # <target> — stdin to the target; '-' = stdout. Never overwrites an
  # existing evidence file (append-only artifact discipline).
  local target="$1"
  if [ "$target" = "-" ]; then
    cat
    return 0
  fi
  if [ -e "$target" ]; then
    echo "REFUSING to overwrite existing evidence file: $target (evidence files are append-only — pass -o with another path)" >&2
    return 1
  fi
  mkdir -p "$(dirname "$target")"
  cat >"$target"
  echo "evidence file written: $target" >&2
  echo "next: git add + commit it, then re-run scripts/pre-vacuum-evidence-gate.sh" >&2
}

# ── selftest (no journalctl; fixtures only) ──────────────────────────────

bep_selftest() (
  # Subshell body: scratch-dir EXIT trap + exit statuses stay scoped to
  # the selftest (same bash 5.3 RETURN-trap/locals hazard as bep_render).
  local failures=0 tmp out
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  check() { # <desc> <cmd...>
    local desc="$1"
    shift
    if "$@"; then
      :
    else
      echo "FAIL: $desc"
      failures=$((failures + 1))
    fi
  }

  # Fixture journal: filler + known signal lines.
  {
    for i in $(seq 1 30); do echo "Oct 11 12:00:0$i evo-x2 filler[$i]: noise $i"; done
    echo "Oct 11 23:00:01 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0"
    echo "Oct 11 23:00:01 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,task=nix,pid=1"
    echo "Oct 11 23:00:02 evo-x2 kernel: Out of memory: Killed process 1 (nix)"
    echo "Oct 11 23:05:00 evo-x2 memory-emergency-guard-check[9]: MEMORY EMERGENCY: zone 6 trip"
    echo "Oct 11 23:15:00 evo-x2 thermal-pstate-guard-check[9]: THERMAL THROTTLE ENTER: amd_pstate -> guided"
    echo "Oct 11 23:20:00 evo-x2 kernel: BUG: unable to handle page fault"
  } >"$tmp/journal"

  out=$(bep_render "$tmp/journal" "bf8a454c" "bf8a454cdeadbeef000000000000000000000000" "2026-10-11 11:09:43" "2026-10-12 13:04:01")
  printf '%s\n' "$out" >"$tmp/evidence.md"

  check "census oom count" grep -q '^- oom-lines: 3$' "$tmp/evidence.md"
  check "census guard count" grep -q '^- guard-lines (memory-emergency-guard): 1$' "$tmp/evidence.md"
  check "census thermal count" grep -q '^- thermal-THROTTLE-lines: 1$' "$tmp/evidence.md"
  check "census panic count" grep -q '^- kernel panic/BUG/oops lines: 1$' "$tmp/evidence.md"
  check "first line present" grep -q 'filler\[1\]: noise 1' "$tmp/evidence.md"
  check "last line present" grep -q 'BUG: unable to handle page fault' "$tmp/evidence.md"
  check "oom line preserved" grep -q 'invoked oom-killer' "$tmp/evidence.md"
  check "guard line preserved" grep -q 'MEMORY EMERGENCY: zone 6 trip' "$tmp/evidence.md"

  # Hex-boundary contract with the pre-vacuum gate: the header must cite
  # the id8 as a STANDALONE token (the gate greps (^|[^0-9a-f])id8([^0-9a-f]|$)).
  check "id8 standalone (gate grep hits)" \
    grep -qE '(^|[^0-9a-f])bf8a454c([^0-9a-f]|$)' "$tmp/evidence.md"
  # Negative control: a document that only embeds the id8 INSIDE the full
  # id must NOT match the gate grep (the phantom-green class the gate
  # exists to prevent).
  printf 'full: bf8a454cdeadbeef\n' >"$tmp/negative.md"
  if grep -qE '(^|[^0-9a-f])bf8a454c([^0-9a-f]|$)' "$tmp/negative.md"; then
    echo "FAIL: hex-boundary negative control must not match"
    failures=$((failures + 1))
  fi

  # Panic truncation: >100 kernel panic lines collapse to first 25 / last 25.
  {
    for i in $(seq 1 150); do echo "Oct 11 23:2$(printf '%02d' $((i % 10))):00 evo-x2 kernel: BUG: synthetic $i"; done
    for i in $(seq 1 5); do echo "Oct 11 23:30:0$i evo-x2 filler-trailing[$i]"; done
  } >"$tmp/journal.big"
  out=$(bep_render "$tmp/journal.big" "bf8a454c" "bf8a454cdeadbeef" "t1" "t2")
  printf '%s\n' "$out" >"$tmp/evidence.big.md"
  check "truncation marker" grep -q 'TRUNCATED (150 total; showing first 25 / last 25)' "$tmp/evidence.big.md"
  check "truncated head present" grep -q 'synthetic 1$' "$tmp/evidence.big.md"
  check "truncated tail present" grep -q 'synthetic 150$' "$tmp/evidence.big.md"
  check "middle elided" bash -c '! grep -q "synthetic 80\$" '"$tmp"'/evidence.big.md'
  check "big census panic count" grep -q '^- kernel panic/BUG/oops lines: 150$' "$tmp/evidence.big.md"

  # Write path: refuses to overwrite an existing evidence file.
  printf 'existing\n' >"$tmp/target.md"
  if printf 'new\n' | bep_write "$tmp/target.md" 2>/dev/null; then
    echo "FAIL: bep_write must refuse an existing target"
    failures=$((failures + 1))
  fi
  check "refusal kept original content" grep -q '^existing$' "$tmp/target.md"
  printf 'streamed\n' | bep_write "$tmp/ok.md" 2>/dev/null
  check "write to fresh target" grep -q '^streamed$' "$tmp/ok.md"

  if [ "$failures" -eq 0 ]; then
    echo "boot-evidence-pull selftest: all cases green"
    exit 0
  fi
  echo "boot-evidence-pull selftest: $failures FAILURE(S)"
  exit 1
)

# ── live path ────────────────────────────────────────────────────────────

BEP_ID=""
BEP_FIRST_TS=""
BEP_LAST_TS=""
BEP_DUMP=""

bep_resolve_boot() {
  # <spec> — resolve via --list-boots; sets BEP_ID/BEP_FIRST_TS/BEP_LAST_TS.
  local spec="$1" line
  line=$(journalctl --list-boots --no-pager --quiet 2>/dev/null | awk -v s="$spec" '$1 == s || $2 ~ "^"s {print; exit}')
  if [ -z "$line" ]; then
    echo "boot spec '$spec' not found in journalctl --list-boots (try: $0 list)" >&2
    return 1
  fi
  BEP_ID=$(printf '%s' "$line" | awk '{print $2}')
  BEP_FIRST_TS=$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}' | head -n 1)
  BEP_LAST_TS=$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}' | tail -n 1)
  [ -n "$BEP_FIRST_TS" ] && [ -n "$BEP_LAST_TS" ]
}

bep_usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

main() {
  local mode="pull"
  case "${1:-}" in
  list | selftest)
    mode="$1"
    shift
    ;;
  esac

  local spec="-1" out=""
  while getopts ":b:o:h" opt; do
    case $opt in
    b) spec=$OPTARG ;;
    o) out=$OPTARG ;;
    h)
      bep_usage
      return 0
      ;;
    \?)
      echo "unknown option: -$OPTARG" >&2
      bep_usage >&2
      return 2
      ;;
    esac
  done
  shift $((OPTIND - 1))

  case "$mode" in
  list)
    exec journalctl --list-boots --no-pager
    ;;
  selftest)
    bep_selftest
    ;;
  pull)
    if [ "$#" -gt 0 ]; then
      echo "unexpected argument: $1 (use -b <boot-spec>)" >&2
      bep_usage >&2
      return 2
    fi
    command -v journalctl >/dev/null 2>&1 || {
      echo "journalctl not found on PATH" >&2
      return 1
    }
    bep_resolve_boot "$spec"
    local id8
    id8=${BEP_ID:0:8}
    # Scratch lives under ~/.cache, NOT /var/tmp (2026-10-27 storage audit F5:
    # killed sessions leak their /var/tmp scratch — the EXIT trap below only
    # fires on a clean exit — and /tmp is wiped mid-session by tmpfiles; the
    # evidence boot dump can be 100s of MB and belongs on durable cache).
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence"
    BEP_DUMP=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/boot-evidence.XXXXXX")
    trap 'rm -f "$BEP_DUMP"' EXIT
    journalctl --quiet --no-pager -b "$BEP_ID" >"$BEP_DUMP"
    if [ -z "$out" ]; then
      out="$TASKS_DIR/$(date -u '+%Y-%m-%d_%H-%M')_boot-${id8}-evidence-pull.md"
    fi
    bep_render "$BEP_DUMP" "$id8" "$BEP_ID" "$BEP_FIRST_TS" "$BEP_LAST_TS" | bep_write "$out"
    ;;
  esac
}

main "$@"
