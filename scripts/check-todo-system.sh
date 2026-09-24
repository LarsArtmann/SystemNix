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
fail=0

check() {
  local desc="$1" pattern="$2"
  local hits
  hits=$(grep -nE "$pattern" "$TODO" 2>/dev/null || true)
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
  echo "SELFTEST OK: scanner rejects title-less rows + dead library links"
  exit 0
}

scan_file() {
  local f="$1"
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
  return $fail
}

case "${1:-}" in
--selftest) selftest ;;
--scan-file) scan_file "$2" ;;
*)
  scan_file "$TODO"
  if [ "$fail" -ne 0 ]; then
    echo "TODO system gate FAILED — fix TODO_LIST.md (queue rows must carry a title and link to an existing docs/todo/<lib>.md)"
    exit 1
  fi
  echo "OK: TODO queue/library structure clean"
  ;;
esac
