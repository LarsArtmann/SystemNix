#!/usr/bin/env bash
# prune-done-todos.sh — scriptified completed-TODO prune (2026-10-25 10-38 session).
#
# Prunes `- [x]` rows from TODO_LIST.md + docs/todo/*.md (continuation-aware:
# indented follow-on lines ride the parent row) and emits the CHANGELOG entry
# block (grouped per-file headers, counts, verbatim-truncated titles with
# pre-prune line numbers) for manual paste into CHANGELOG.md.
#
# Safety contract:
#   * DRY-RUN by default — nothing is written; --apply prunes in place.
#   * Rev-pinned baseline: HEAD + target-file dirtiness recorded up front;
#     --apply aborts if either moved between baseline and write (the 10-38
#     session's first WARN A/B ran against a stale HEAD — that class dies here).
#   * WARN A/B: check-todo-system.sh WARN counts captured before AND after.
#     A prune UNMASKS pairing/harvest WARNs (2026-10-25: 163->221, +34
#     unharvested) because done rows' Source citations were masking open-row
#     drift — a RISE is expected; recount it into the drift row, don't panic
#     (AGENTS.md TODO-System note, 2026-10-25).
#   * Scratch lives under ~/.cache/ (never /tmp — volatile-tmpfs lesson).
#
# Usage:
#   scripts/prune-done-todos.sh              # dry-run: counts + entry block
#   scripts/prune-done-todos.sh --apply      # prune + WARN B + entry block
#   scripts/prune-done-todos.sh --help
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TODO="$REPO_ROOT/TODO_LIST.md"
GATE="$REPO_ROOT/scripts/check-todo-system.sh"
SCRATCH="$HOME/.cache/todopruned-$(date +%Y%m%d-%H%M%S)"
TITLE_CHARS=110
APPLY=0

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

for arg in "$@"; do
  case "$arg" in
  --apply) APPLY=1 ;;
  --help | -h) usage ;;
  *)
    echo "unknown arg: $arg (see --help)" >&2
    exit 2
    ;;
  esac
done

[ -f "$TODO" ] || {
  echo "TODO_LIST.md not found at $TODO" >&2
  exit 1
}
mkdir -p "$SCRATCH"

# --- Rev-pinned baseline -----------------------------------------------------
BASE_REV=$(git -C "$REPO_ROOT" rev-parse HEAD)
baseline_dirty() {
  git -C "$REPO_ROOT" status --short -- TODO_LIST.md docs/todo 2>/dev/null || true
}
BASE_DIRTY=$(baseline_dirty)

warn_counts() {
  # gate WARN taxonomy: pairing drift + unharvested (WARN-class, exit 0)
  local out
  out=$(bash "$GATE" 2>&1) || true
  printf '%s\n' "$out" >"$SCRATCH/$1"
  printf '%s\n' "$out" | grep -c 'DRIFT' || true
}

# --- Extract: FILENAME \t FNR \t TITLE for every done row --------------------
extract() { # $1 = file
  awk -v file="${1#"$REPO_ROOT"/}" '
    /^- \[x\]/ {
      t = $0
      sub(/^- \[x\] /, "", t)
      sub(/[ \t]+$/, "", t)
      printf "%s\t%d\t%s\n", file, FNR, t
    }' "$1"
}

# --- Prune: drop done rows + indented continuations, collapse double blanks --
prune_stream() {
  awk '
    BEGIN { indrop = 0; dropped = 0; prevblank = 0 }
    /^- \[x\]/ { indrop = 1; dropped = 1; next }
    indrop && /^[ \t]+[^ \t]/ { next }
    {
      indrop = 0
      if ($0 ~ /^[ \t]*$/) {
        if (dropped && prevblank) next
        prevblank = 1
        print
        next
      }
      dropped = 0
      prevblank = 0
      print
    }'
}

# --- Render: grouped headers + counts + truncated titles ---------------------
render() { # stdin = TSV
  LC_ALL=C.UTF-8 awk -v TC="$TITLE_CHARS" 'BEGIN { FS = "\t" }
    $1 != file {
      if (file != "") {
        printf "  - **%s** (%d)\n", file, fcount
        printf "%s", buf
      }
      file = $1; fcount = 0; buf = ""
    }
    {
      fcount++
      title = $3
      if (length(title) > TC) title = substr(title, 1, TC) " …"
      buf = buf "    - " title " (line " $2 ")\n"
    }
    END {
      if (file != "") {
        printf "  - **%s** (%d)\n", file, fcount
        printf "%s", buf
      }
    }'
}

TARGETS=("$TODO" "$REPO_ROOT"/docs/todo/[a-z0-9-]*.md)

echo "== baseline pinned at $BASE_REV"
[ -n "$BASE_DIRTY" ] && echo "== NOTE: targets already dirty pre-prune:" && printf '%s\n' "$BASE_DIRTY"
PRE_DRIFT=$(warn_counts pre-warns.txt)
echo "== WARN A (pre):  DRIFT lines = $PRE_DRIFT"

: >"$SCRATCH/raw.tsv"
total=0
for f in "${TARGETS[@]}"; do
  n=$(extract "$f" | tee -a "$SCRATCH/raw.tsv" | wc -l)
  total=$((total + n))
done

if [ "$total" -eq 0 ]; then
  echo "== no [x] rows found — nothing to do"
  exit 0
fi

ENTRY_BLOCK=$(render <"$SCRATCH/raw.tsv")

echo
echo "== $total done rows across ${#TARGETS[@]} files; CHANGELOG entry block follows:"
printf '%s\n' "$ENTRY_BLOCK"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "== DRY-RUN (no files written). Re-run with --apply to prune."
  exit 0
fi

# --- Apply: abort if the baseline moved --------------------------------------
CUR_REV=$(git -C "$REPO_ROOT" rev-parse HEAD)
CUR_DIRTY=$(baseline_dirty)
if [ "$CUR_REV" != "$BASE_REV" ] || [ "$CUR_DIRTY" != "$BASE_DIRTY" ]; then
  echo "ABORT: tree moved since baseline (rev $BASE_REV -> $CUR_REV, or target dirtiness changed) — re-baseline and retry" >&2
  exit 3
fi

for f in "${TARGETS[@]}"; do
  prune_stream <"$f" >"$SCRATCH/pruned.tmp"
  if ! cmp -s "$f" "$SCRATCH/pruned.tmp"; then
    cat "$SCRATCH/pruned.tmp" >"$f"
    echo "pruned: $f"
  fi
done

POST_DRIFT=$(warn_counts post-warns.txt)
echo
echo "== WARN B (post): DRIFT lines = $POST_DRIFT (pre: $PRE_DRIFT)"
echo "== a RISE is expected unmasking (see header note); recount into the drift row."
echo "== next: paste the entry block into CHANGELOG.md, recount the drift row, pathspec-commit."
