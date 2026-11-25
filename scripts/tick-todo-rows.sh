#!/usr/bin/env bash
# tick-todo-rows.sh — flip open TODO rows to done, by exact title, on every
# surface they live on (2026-11-25, the masterplan v6 sweeps).
#
# A row is paired by design: one line in TODO_LIST.md (the queue) and one in
# its docs/todo/<domain>.md library. Hand-ticking both for a 25-row wave is
# ~50 full-line edits with a drift risk each; this is the single-writer pass.
#
# Contract:
#   * Titles come from stdin or --titles <file>, one per line: the exact bold
#     span of the row, without the lifecycle tag and without the asterisks.
#   * DRY-RUN by default: reports what would flip, writes nothing. --apply flips.
#   * Exact title equality (the gate's own title extraction, check-todo-system.sh
#     duplicate_check) — a prefix or a reworded title is NOT-FOUND, never a guess.
#   * Idempotent: an already-ticked row reports ALREADY and is left as is.
#   * Exit 1 when any title is NOT-FOUND, in both modes, and --apply then
#     refuses to write anything: a typo in a verdict list stops before the
#     commit instead of silently skipping a row.
#   * A title found on ONE surface only says QUEUE-ONLY or LIB-ONLY:<library>:
#     the other surface drifted (a row lost, or a library-only row) — read it.
#   * MIXED: one surface of the pair is done, the other still open.
#
# Usage:
#   scripts/tick-todo-rows.sh < titles.txt             # dry-run report
#   scripts/tick-todo-rows.sh --apply < titles.txt     # flip on every surface
#   scripts/tick-todo-rows.sh --apply --note " — done <rev>" < titles.txt
#   scripts/tick-todo-rows.sh --selftest
#   scripts/tick-todo-rows.sh --help
set -uo pipefail

REPO_ROOT="${TICK_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TODO="$REPO_ROOT/TODO_LIST.md"
APPLY=0
NOTE=""
TITLES_FILE=""
MODE_SELFTEST=0
SCRATCH="$HOME/.cache/tick-todos-$$"
mkdir -p "$SCRATCH" || exit 2

usage() {
  sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# Reads the titles file, then the targets. One line per title:
# "<STATE>\t<surfaces>\t<title>\t<open rows>" with STATE one of
# OPEN, MIXED, ALREADY, NOT-FOUND.
report() {
  awk -v titlesfile="$1" -v root="$REPO_ROOT/" '
    BEGIN {
      while ((getline line < titlesfile) > 0) {
        sub(/\r$/, "", line)
        if (line != "" && !(line in want)) order[++n] = line
        if (line != "") want[line] = 1
      }
    }
    {
      if (!match($0, /^- \[[ x]\] (\[[^]]*\] )?\*\*[^*]+\*\*/)) next
      t = substr($0, RSTART, RLENGTH)
      sub(/^- \[[ x]\] */, "", t)
      sub(/^\[[^]]*\] */, "", t)
      sub(/^\*\*/, "", t)
      sub(/\*\*$/, "", t)
      if (!(t in want)) next
      if (FILENAME ~ /TODO_LIST\.md$/) onq[t] = 1
      else {
        f = FILENAME
        sub(root, "", f)
        libs[t] = (libs[t] == "" ? f : libs[t] "+" f)
      }
      rows[t]++
      if ($0 ~ /^- \[ \]/) open[t]++
    }
    END {
      for (i = 1; i <= n; i++) {
        t = order[i]
        if (!(t in rows)) { printf "NOT-FOUND\t-\t%s\t0\n", t; continue }
        l = ""
        j = split(libs[t], p, "+")
        for (k = 1; k <= j; k++) { sub(/^docs\/todo\//, "", p[k]); sub(/\.md$/, "", p[k]); l = l (k > 1 ? "+" : "") p[k] }
        if (onq[t] && j) label = "QUEUE+" l
        else if (onq[t]) label = "QUEUE-ONLY"
        else label = "LIB-ONLY:" l
        state = (!(t in open)) ? "ALREADY" : ((open[t] == rows[t]) ? "OPEN" : "MIXED")
        printf "%s\t%s\t%s\t%d\n", state, label, t, open[t] + 0
      }
    }
  ' "${@:2}"
}

selftest() {
  local root out rc before me
  me="$(basename "${BASH_SOURCE[0]}")"
  root="$SCRATCH/selftest"
  mkdir -p "$root/docs/todo" "$root/scripts"
  cp "${BASH_SOURCE[0]}" "$root/scripts/"
  printf '# Queue\n\n### a\n\n- [ ] [ready] **Alpha row** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n- [ ] [ready] **Alpha row longer title** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n- [x] **Gamma row** — done long ago\n- [ ] [blocked:user] **Delta row** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n- [ ] [ready] **Epsilon queue-only row** — body\n- [ ] [ready] **Zeta half-done row** — body\n' >"$root/TODO_LIST.md"
  printf '# Lib\n\n- [ ] [ready] **Alpha row** — body\n- [ ] [ready] **Alpha row longer title** — body\n- [ ] [ready] **Beta library-only row** — body\n- [ ] [blocked:user] **Delta row** — body\n- [x] **Zeta half-done row** — body\n' >"$root/docs/todo/pipeline.md"
  printf 'Alpha row\nGamma row\nDelta row\nBeta library-only row\nEpsilon queue-only row\nZeta half-done row\nAlpha row longer\n' >"$SCRATCH/titles.txt"
  before=$(md5sum "$root/TODO_LIST.md" "$root/docs/todo/pipeline.md")
  expect_line() {
    if ! printf '%s\n' "$out" | grep -qE "$1"; then
      echo "SELFTEST FAIL: $2"
      echo "$out"
      exit 1
    fi
  }
  out=$(TICK_REPO_ROOT="$root" bash "$root/scripts/$me" --titles "$SCRATCH/titles.txt" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST FAIL: an unknown title must exit 1 in dry-run"
    exit 1
  fi
  expect_line '^OPEN[[:space:]]+QUEUE\+pipeline[[:space:]]+2[[:space:]]+Alpha row$' 'a paired open row reports OPEN QUEUE+pipeline'
  expect_line '^OPEN[[:space:]]+QUEUE\+pipeline[[:space:]]+2[[:space:]]+Delta row$' 'a tagged (blocked) row must be found by its title'
  expect_line '^ALREADY[[:space:]]+QUEUE-ONLY[[:space:]]+0[[:space:]]+Gamma row$' 'a queue-only done row reports ALREADY QUEUE-ONLY'
  expect_line '^MIXED[[:space:]]+QUEUE\+pipeline[[:space:]]+1[[:space:]]+Zeta half-done row$' 'a half-ticked pair reports MIXED'
  expect_line '^OPEN[[:space:]]+QUEUE-ONLY[[:space:]]+1[[:space:]]+Epsilon queue-only row$' 'a queue-only open row reports QUEUE-ONLY'
  expect_line '^OPEN[[:space:]]+LIB-ONLY:pipeline[[:space:]]+1[[:space:]]+Beta library-only row$' 'a library-only open row reports LIB-ONLY'
  expect_line '^NOT-FOUND[[:space:]]+-[[:space:]]+0[[:space:]]+Alpha row longer$' 'a prefix title must be NOT-FOUND, never matched to a longer title'
  expect_line '^SUMMARY: 7 row\(s\) to flip, 1 title\(s\) already done, 1 title\(s\) not found$' 'the dry-run summary must count open rows, done and not-found titles'
  [ "$before" = "$(md5sum "$root/TODO_LIST.md" "$root/docs/todo/pipeline.md")" ] || {
    echo "SELFTEST FAIL: dry-run wrote to a target"
    exit 1
  }
  out=$(TICK_REPO_ROOT="$root" bash "$root/scripts/$me" --apply --titles "$SCRATCH/titles.txt" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ] || [ "$before" != "$(md5sum "$root/TODO_LIST.md" "$root/docs/todo/pipeline.md")" ]; then
    echo "SELFTEST FAIL: --apply with a NOT-FOUND title must refuse and write nothing"
    exit 1
  fi
  printf 'Alpha row\nDelta row\nZeta half-done row\n' >"$SCRATCH/apply.txt"
  out=$(TICK_REPO_ROOT="$root" bash "$root/scripts/$me" --apply --note " — done selftest" --titles "$SCRATCH/apply.txt" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "SELFTEST FAIL: --apply with known titles must exit 0"
    echo "$out"
    exit 1
  fi
  local want_q='^- \[x\] \[ready\] \*\*Alpha row\*\* — body → \[docs/todo/pipeline.md\]\(docs/todo/pipeline.md\) — done selftest$'
  local want_l='^- \[x\] \[ready\] \*\*Alpha row\*\* — body — done selftest$'
  if ! grep -qE "$want_q" "$root/TODO_LIST.md" || ! grep -qE "$want_l" "$root/docs/todo/pipeline.md"; then
    echo "SELFTEST FAIL: --apply must flip the titled row on the queue AND the library, note appended"
    exit 1
  fi
  if ! grep -qE '^- \[ \] \[ready\] \*\*Alpha row longer title\*\*' "$root/TODO_LIST.md"; then
    echo "SELFTEST FAIL: --apply flipped a row whose title only shares a prefix"
    exit 1
  fi
  if ! grep -qE '^- \[x\] \[blocked:user\] \*\*Delta row\*\* — body → \[docs/todo/pipeline.md\]\(docs/todo/pipeline.md\) — done selftest' "$root/TODO_LIST.md" ||
    ! grep -qE '^- \[x\] \[blocked:user\] \*\*Delta row\*\* — body — done selftest' "$root/docs/todo/pipeline.md"; then
    echo "SELFTEST FAIL: --apply must flip a blocked row on both surfaces"
    exit 1
  fi
  if ! grep -qE '^- \[ \] \[ready\] \*\*Epsilon queue-only row\*\*' "$root/TODO_LIST.md"; then
    echo "SELFTEST FAIL: --apply flipped an untitled row"
    exit 1
  fi
  out=$(TICK_REPO_ROOT="$root" bash "$root/scripts/$me" --titles "$SCRATCH/apply.txt" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "SELFTEST FAIL: a second run must exit 0 (idempotent)"
    exit 1
  fi
  expect_line '^ALREADY[[:space:]]+QUEUE\+pipeline[[:space:]]+0[[:space:]]+Alpha row$' 'a second run must report the pair ALREADY'
  expect_line '^SUMMARY: 0 row\(s\) to flip, 3 title\(s\) already done, 0 title\(s\) not found$' 'the second run summary must count zero flips'
  out=$(printf 'Alpha row\n' | TICK_REPO_ROOT="$root" bash "$root/scripts/$me" 2>&1) && rc=0 || rc=$?
  expect_line '^ALREADY[[:space:]]+QUEUE\+pipeline[[:space:]]+0[[:space:]]+Alpha row$' 'titles must be accepted on stdin'
  echo "SELFTEST OK: dry-run writes nothing, exact-title only, queue+library flip, note appended, MIXED seen, NOT-FOUND refuses --apply, idempotent, stdin form"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
  --apply) APPLY=1 ;;
  --selftest) MODE_SELFTEST=1 ;;
  --note)
    NOTE="$2"
    shift
    ;;
  --titles)
    TITLES_FILE="$2"
    shift
    ;;
  --help | -h) usage ;;
  *)
    echo "unknown arg: $1 (see --help)" >&2
    exit 2
    ;;
  esac
  shift
done

[ "$MODE_SELFTEST" -eq 1 ] && selftest

if [ -n "$TITLES_FILE" ]; then
  [ -f "$TITLES_FILE" ] || {
    echo "titles file not found: $TITLES_FILE" >&2
    exit 2
  }
elif [ ! -t 0 ]; then
  TITLES_FILE="$SCRATCH/stdin-titles.txt"
  cat >"$TITLES_FILE"
else
  usage
fi

# Targets: the queue plus every library, fixed order so the report is stable.
targets=("$TODO")
for lib in "$REPO_ROOT"/docs/todo/[a-z0-9-]*.md; do
  [ -f "$lib" ] && targets+=("$lib")
done

report "$TITLES_FILE" "${targets[@]}" >"$SCRATCH/report.tsv"

flipping=0 already=0 missing=0
while IFS=$'\t' read -r state label title open_rows; do
  case "$state" in
  OPEN | MIXED)
    flipping=$((flipping + open_rows))
    ;;
  ALREADY) already=$((already + 1)) ;;
  NOT-FOUND)
    missing=$((missing + 1))
    ;;
  esac
  printf '%-10s %-28s %3s  %s\n' "$state" "$label" "$open_rows" "$title"
done <"$SCRATCH/report.tsv"
echo "SUMMARY: $flipping row(s) to flip, $already title(s) already done, $missing title(s) not found"

if [ "$APPLY" -eq 0 ]; then
  echo "DRY-RUN: nothing written — add --apply to flip"
  [ "$missing" -eq 0 ]
  exit $?
fi
if [ "$missing" -gt 0 ]; then
  echo "REFUSED: $missing title(s) not found — fix the list, nothing was written"
  exit 1
fi
if [ "$flipping" -eq 0 ]; then
  echo "APPLIED 0: every titled row is already done"
  exit 0
fi
for target in "${targets[@]}"; do
  out="$SCRATCH/out.$$"
  awk -v titlesfile="$TITLES_FILE" -v note="$NOTE" '
    BEGIN {
      while ((getline line < titlesfile) > 0) {
        sub(/\r$/, "", line)
        if (line != "") want[line] = 1
      }
    }
    {
      if (!match($0, /^- \[ \] (\[[^]]*\] )?\*\*[^*]+\*\*/)) {
        print
        next
      }
      t = substr($0, RSTART, RLENGTH)
      sub(/^- \[ \] /, "", t)
      sub(/^\[[^]]*\] /, "", t)
      sub(/^\*\*/, "", t)
      sub(/\*\*$/, "", t)
      if (t in want) {
        sub(/^- \[ \]/, "- [x]")
        if (note != "") $0 = $0 note
      }
      print
    }
  ' "$target" >"$out"
  if ! cmp -s "$out" "$target"; then
    cat "$out" >"$target"
    printf 'WROTE     %s\n' "${target#"$REPO_ROOT"/}"
  fi
  rm -f "$out"
done
echo "APPLIED $flipping row(s) ticked${NOTE:+ ($NOTE)}"
