#!/usr/bin/env bash
# check-todo-system.sh — structural gate for the TODO queue/library system.
#
# TODO_LIST.md is the DISPATCH QUEUE (one-line rows linking into the
# docs/todo/<domain>.md libraries). The 2026-09-19 library split exposed
# two decay classes this gate rejects:
#
#   1. Title-less queue rows (`- [ ] **Source:** → [docs/todo/x.md]`) —
#      harvest artifacts whose title was lost; they carry zero information
#      and every real library item already has a proper row (63 purged
#      2026-09-19).
#   2. Queue rows whose link target is not a library file, or library
#      files that do not exist.
#   3. Entry drift (2026-09-30): an OPEN queue row citing a Source report
#      filename that its linked library never mentions — the no-drift rule
#      ("queue one-liners and their library entries must not drift — edit
#      both") made mechanical. Default WARN (hardness is an open owner
#      decision, 2026-09-30_05-41 report §g2); CHECK_TODO_PAIRING=strict
#      (or --pairing-strict) fails the gate. [x] rows are exempt (their
#      completion narrative cites commits, not reports).
#
# Scope v1: grep-judgeable shapes only. Semantic dedup/priority are
# review work, not a grep gate.
#
# Usage:
#   bash scripts/check-todo-system.sh            # gate
#   bash scripts/check-todo-system.sh --selftest # prove the scanner detects
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TODO="$REPO_ROOT/TODO_LIST.md"
SCAN_TARGET="$TODO"
fail=0

check() {
  local desc="$1" pattern="$2"
  local hits
  hits=$(grep -nE "$pattern" "$SCAN_TARGET" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $desc"
    echo "$hits" | sed 's/^/  /'
    fail=1
  fi
}

selftest() {
  local tmp
  tmp=$(mktemp)
  cp "$TODO" "$tmp"
  printf -- '- [ ] **Source:** → [docs/todo/storage.md](docs/todo/storage.md)\n' >>"$tmp"
  printf -- '- [ ] **Broken link** → [docs/todo/nonexistent-lib.md](docs/todo/nonexistent-lib.md)\n' >>"$tmp"
  local out rc
  # out is a deliberate stdout+stderr swallow
  # shellcheck disable=SC2034
  out=$(TODO_FILE="$tmp" "$0" --scan-file "$tmp" 2>&1) && rc=0 || rc=$?
  rm -f "$tmp"
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST FAIL: scanner caught nothing on a seeded-broken file"
    exit 1
  fi
  # pairing leg: default mode must WARN (exit 0) and print the seeded drift row
  tmp=$(mktemp)
  cp "$TODO" "$tmp"
  printf -- '- [ ] **Selftest drift row: never-lands-anywhere** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: 1970-01-01_00-00_selftest-never-exists.md §z9)\n' >>"$tmp"
  out=$(TODO_FILE="$tmp" env -u CHECK_TODO_PAIRING "$0" --scan-file "$tmp" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ] || ! printf '%s\n' "$out" | grep -q 'WARN: .*entry drift'; then
    rm -f "$tmp"
    echo "SELFTEST FAIL: default pairing mode must warn-with-exit-0"
    exit 1
  fi
  # strict mode must FAIL on the same file
  out=$(TODO_FILE="$tmp" CHECK_TODO_PAIRING=strict "$0" --scan-file "$tmp" 2>&1) && rc=0 || rc=$?
  rm -f "$tmp"
  if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -q 'FAIL: .*entry drift'; then
    echo "SELFTEST FAIL: strict pairing mode must fail on seeded drift"
    exit 1
  fi
  echo "SELFTEST OK: scanner rejects title-less rows + dead library links + detects entry drift (warn default / strict fail)"
  exit 0
}

scan_file() {
  local f="$1"
  SCAN_TARGET="$f"
  fail=0
  check "title-less queue row (lost-harvest artifact — restore the title or delete the row)" \
    '^- \[ \] \*\*Source:\*\*'
  # verify every referenced library file exists
  local lib
  while IFS= read -r lib; do
    [ -f "$REPO_ROOT/$lib" ] || {
      echo "FAIL: queue links to missing library: $lib"
      fail=1
    }
  done < <(grep -oE 'docs/todo/[a-z0-9-]+\.md' "$f" | sort -u)
  pairing_check "$f"
  return $fail
}

# Entry pairing: an open queue row citing a Source report filename must be
# matched by >=1 citation of that filename in the linked library. Rows whose
# citation only exists in a DIFFERENT library are reported as wrong-link
# (the routing rule files the entry under the domain that owns the fix).
pairing_check() {
  local f="$1" pairing_fail=0 row lib src elsewhere
  [ "${CHECK_TODO_PAIRING:-}" = "strict" ] && pairing_fail=1
  local drift_count=0
  while IFS= read -r row; do
    lib=$(printf '%s\n' "$row" | grep -oE 'docs/todo/[a-z0-9-]+\.md' | head -1)
    [ -n "$lib" ] || continue
    while IFS= read -r src; do
      [ -n "$src" ] || continue
      if ! grep -qF "$src" "$REPO_ROOT/$lib" 2>/dev/null; then
        drift_count=$((drift_count + 1))
        elsewhere=""
        for other in "$REPO_ROOT"/docs/todo/[a-z0-9-]*.md; do
          [ "$other" = "$REPO_ROOT/$lib" ] && continue
          if grep -qF "$src" "$other" 2>/dev/null; then
            elsewhere="${other##*/}"
            break
          fi
        done
        if [ -n "$elsewhere" ]; then
          printf 'DRIFT (wrong-link): row cites %s but the entry lives in %s (fix the row link or move the entry)\n    %s\n' \
            "$src" "$elsewhere" "${row:0:160}"
        else
          printf 'DRIFT (no library entry): row cites %s, absent from %s and every other library\n    %s\n' \
            "$src" "${lib##*/}" "${row:0:160}"
        fi
      fi
    done < <(printf '%s\n' "$row" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}[A-Za-z0-9._-]*\.md' | sort -u)
  done < <(grep -E '^- \[ \] ' "$f" | grep 'docs/todo/[a-z0-9-]*\.md')
  if [ "$drift_count" -gt 0 ]; then
    if [ "$pairing_fail" -eq 1 ]; then
      echo "FAIL: $drift_count queue/library entry drift(s) — pair every cited Source with a library entry (CHECK_TODO_PAIRING=strict)"
      fail=1
    else
      echo "WARN: $drift_count queue/library entry drift(s) (gate-hardness decision pending; CHECK_TODO_PAIRING=strict fails)"
    fi
  fi
}

case "${1:-}" in
--selftest) selftest ;;
--scan-file) scan_file "$2" ;;
--pairing-strict) CHECK_TODO_PAIRING=strict scan_file "$TODO" ;;
*)
  scan_file "$TODO"
  if [ "$fail" -ne 0 ]; then
    echo "TODO system gate FAILED — fix TODO_LIST.md (queue rows must carry a title and link to an existing docs/todo/<lib>.md)"
    exit 1
  fi
  echo "OK: TODO queue/library structure clean"
  ;;
esac
