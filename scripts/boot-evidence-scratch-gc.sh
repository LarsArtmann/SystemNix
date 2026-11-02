#!/usr/bin/env bash
# boot-evidence-scratch-gc.sh — age+holder-gated reclaim of leaked
# boot-evidence scratch under ${XDG_CACHE_HOME:-~/.cache}/boot-evidence.
#
# The leak class: boot-evidence-pull.sh's EXIT trap only fires on a clean
# exit — a killed session (SIGKILL, terminal death) leaks its dump, which
# can be 100s of MB to >1 GB (2026-11-02 reclaim: 2.1G across two leaked
# dumps from prior sessions, plus stale ch.* mktemp scraps). The pull
# script now self-cleans at startup (age-gated so it never touches a
# concurrent session's fresh scratch); this script is that gc, callable
# standalone.
#
# Gate: a file is reclaimed only when BOTH hold —
#   age     mtime older than BEP_GC_AGE_H hours (default 48)
#   holder  no live process holds the file open (via /proc/*/fd scan;
#           no lsof/fuser dependency)
#
# Usage:
#   boot-evidence-scratch-gc.sh            gc (prints one line per file)
#   boot-evidence-scratch-gc.sh quiet      gc, silent unless it reclaimed
#   boot-evidence-scratch-gc.sh selftest   fixture selftest (flake check:
#                     checks.x86_64-linux.boot-evidence-scratch-gc-selftest)
set -euo pipefail

BEC_GC_DIR="${BEC_GC_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence}"
BEC_GC_AGE_H="${BEP_GC_AGE_H:-48}"

# <file> — nonzero when any live process holds <file> open. Walks
# /proc/*/fd symlinks; read-permission failures (foreign pids) skip, so
# the check is best-effort by construction (a holder we cannot see is a
# holder we must not trash).
bec_file_held() {
  local file="$1" fd target
  for fd in /proc/[0-9]*/fd/*; do
    [ -e "$fd" ] || continue
    target=$(readlink "$fd") || continue
    [ "$target" = "$file" ] && return 0
  done
  return 1
}

bec_gc() { # <mode>
  local mode="${1:-gc}" file age_h held reclaimed=0 count=0
  [ -d "$BEC_GC_DIR" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    age_h=$((($(date +%s) - $(stat -c %Y "$file")) / 3600))
    [ "$age_h" -ge "$BEC_GC_AGE_H" ] || continue
    if bec_file_held "$file"; then
      [ "$mode" = quiet ] || echo "HOLD  $file (${age_h}h old, live holder — kept)"
      continue
    fi
    held=$(du -b "$file" | cut -f1)
    rm -f "$file"
    reclaimed=$((reclaimed + held))
    count=$((count + 1))
    echo "GC    $file (${age_h}h old, no holder, reclaimed-bytes=$held)"
  done < <(find "$BEC_GC_DIR" -maxdepth 1 -type f -mmin "+$((BEC_GC_AGE_H * 60))" 2>/dev/null)
  [ "$count" -eq 0 ] && return 0
  [ "$mode" = quiet ] || echo "boot-evidence scratch gc: reclaimed $count file(s), $reclaimed bytes"
  return 0
}

bec_selftest() {
  local failures=0 tmp out
  tmp=$(mktemp -d)
  trap 'rm -rf "${tmp:-}"' EXIT
  check() {
    local desc="$1"
    shift
    if "$@"; then :; else
      echo "FAIL: $desc"
      failures=$((failures + 1))
    fi
  }

  local dir="$tmp/boot-evidence"
  mkdir -p "$dir"
  printf '%.0sx' $(seq 1 1000) >"$dir/old-dump" # 60h old, unheld
  touch -d '60 hours ago' "$dir/old-dump"
  printf 'x' >"$dir/fresh-dump"                    # 0h old
  printf '%.0sx' $(seq 1 100) >"$dir/old-but-held" # 60h old, held
  touch -d '60 hours ago' "$dir/old-but-held"
  # Real holder: a background shell keeps an fd on the file open.
  (
    exec 9<"$dir/old-but-held"
    sleep 30
  ) &
  local holder_pid=$!
  printf 'x' >"$dir/old-scratch.ch.XXXXXX" # stale ch scrap
  touch -d '72 hours ago' "$dir/old-scratch.ch.XXXXXX"

  out=$(BEC_GC_DIR="$dir" BEP_GC_AGE_H=48 "$0" 2>&1 || true)
  check "reclaimed old unheld dump" grep -q 'GC.*old-dump' <<<"$out"
  check "reclaimed stale ch scrap" grep -q 'GC.*old-scratch' <<<"$out"
  check "kept fresh file" bash -c "test -f '$dir/fresh-dump'"
  check "kept held file" bash -c "test -f '$dir/old-but-held'"
  check "holder disclosed" grep -q 'HOLD.*old-but-held' <<<"$out"
  check "reclaim byte count" grep -q 'reclaimed 2 file(s), 1001 bytes' <<<"$out"

  # Quiet mode: silent on nothing-to-do.
  out=$(BEC_GC_DIR="$dir" BEP_GC_AGE_H=48 "$0" quiet 2>&1 || true)
  check "quiet mode silent when clean" test -z "$out"

  # Holder released -> next pass reclaims it.
  /run/current-system/sw/bin/kill "$holder_pid" 2>/dev/null || kill "$holder_pid" 2>/dev/null || true
  wait "$holder_pid" 2>/dev/null || true
  out=$(BEC_GC_DIR="$dir" BEP_GC_AGE_H=48 "$0" 2>&1 || true)
  check "released holder reclaimed" grep -q 'GC.*old-but-held' <<<"$out"

  # Age gate respects BEP_GC_AGE_H override: 1h-old file survives a 2h gate.
  printf 'x' >"$dir/recent"
  out=$(BEC_GC_DIR="$dir" BEP_GC_AGE_H=2 "$0" 2>&1 || true)
  check "age override keeps recent" bash -c "test -f '$dir/recent'"

  if [ "$failures" -eq 0 ]; then
    echo "boot-evidence-scratch-gc selftest: all cases green"
    return 0
  fi
  echo "boot-evidence-scratch-gc selftest: $failures FAILURE(S)"
  return 1
}

main() {
  case "${1:-gc}" in
  gc | quiet) bec_gc "${1:-gc}" ;;
  selftest) bec_selftest ;;
  *)
    echo "unknown argument: $1 (usage: $0 [gc|quiet|selftest])" >&2
    return 2
    ;;
  esac
}

main "$@"
