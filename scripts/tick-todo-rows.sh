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
#     duplicate_check) — a prefix or a reworded title is NOT FOUND, never a guess.
#   * Idempotent: an already-ticked row reports ALREADY and is left as is.
#   * Exit 1 when any title is NOT FOUND, in both modes, so a typo in a verdict
#     list stops before the commit instead of silently skipping a row.
#   * A title found on ONE surface only reports QUEUE-ONLY or LIB-ONLY: the
#     other surface drifted (a row lost, or a library-only row) — read it.
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
SCRATCH="$HOME/.cache/tick-todos-$$"
mkdir -p "$SCRATCH" || exit 2

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
  --apply) APPLY=1 ;;
  --selftest) selftest ;;
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

# titles_file targets… → per-title state table: "<title>\t<surface>\t<open|done>"
survey() {
  local titles="$1"
  shift
  awk '
    BEGIN {
      while ((getline line < titlesfile) > 0) {
        sub(/\r$/, "", line)
        if (line != "") want[line] = 1
      }
      ord = 0
    }
    FNR == 1 { ord++; name[ord] = FILENAME }
    /^- \[[ x]\] / {
      if (match($0, /^- \[[ x]\] (\[[^]]*\] )?\*\*[^*]+\*\*/)) {
        t = substr($0, RSTART, RLENGTH)
        sub(/^- \[[ x]\] */, "", t)
        sub(/^\[[^]]*\] */, "", t)
        sub(/^\*\*/, "", t)
        sub(/\*\*$/, "", t)
        if (t in want) {
          surface = (FILENAME ~ /TODO_LIST\.md$/) ? "QUEUE" : FILENAME
          state = ($0 ~ /^- \[ \]/) ? "open" : "done"
          key = t SUBSEP surface
          seen[key] = (seen[key] == "" ? state : (seen[key] == "open" || state == "open" ? "open" : "done"))
        }
      }
    }
    END {
      for (t in want) {
        n = 0
        for (k in seen) {
          split(k, p, SUBSEP)
          if (p[1] == t) {
            n++
            printf "%s\t%s\t%s\n", t, p[2], seen[k]
          }
        }
        if (n == 0) printf "%s\t-\t-\n", t
      }
    }
  ' titlesfile="$titles" "$@"
}

selftest() {
  local root out rc
  root="$SCRATCH/selftest"
  mkdir -p "$root/docs/todo" "$root/scripts"
  cp "${BASH_SOURCE[0]}" "$root/scripts/"
  printf '# Queue\n\n### a\n\n- [ ] [ready] **Alpha row** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n- [ ] [ready] **Alpha row longer title** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n- [x] **Gamma row** — done long ago\n- [ ] [blocked:user] **Delta row** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n- [ ] [ready] **Epsilon queue-only row** — body\n' >"$root/TODO_LIST.md"
  printf '# Lib\n\n- [ ] [ready] **Alpha row** — body\n- [ ] [ready] **Alpha row longer title** — body\n- [ ] [ready] **Beta library-only row** — body\n- [ ] [blocked:user] **Delta row** — body\n' >"$root/docs/todo/pipeline.md"
  printf 'Alpha row\nGamma row\nDelta row\nBeta library-only row\nEpsilon queue-only row\nAlpha row longer\n' >"$SCRATCH/titles.txt"
  local before
  before=$(md5sum "$root/TODO_LIST.md" | cut -d' ' -f1)
  out=$(TICK_REPO_ROOT="$root" bash "$root/scripts/$(basename "${BASH_SOURCE[0]}")" --titles "$SCRATCH/titles.txt" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST FAIL: an unknown title must exit 1 in dry-run"
    exit 1
  fi
  if ! printf '%s\n' "$out" | grep -q '^Alpha row.*QUEUE.*open' || ! printf '%s\n' "$out" | grep -q '^Alpha row.*docs/todo/pipeline.md.*open'; then
    echo "SELFTEST FAIL: dry-run must list the queue and the library state of a paired row"
    exit 1
  fi
  if printf '%s\n' "$out" | grep -q '^Alpha row longer\b'; then
    echo "SELFTEST FAIL: a prefix title must never match a longer title"
    exit 1
  fi
  if ! printf '%s\n' "$out" | grep -q '^Epsilon queue-only row.*QUEUE-ONLY' || ! printf '%s\n' "$out" | grep -q '^Beta library-only row.*LIB-ONLY'; then
    echo "SELFTEST FAIL: single-surface rows must report QUEUE-ONLY / LIB-ONLY"
    exit 1
  fi
  if [ "$(md5sum "$root/TODO_LIST.md" | cut -d' ' -f1)" != "$before" ]; then
    echo "SELFTEST FAIL: dry-run wrote to the queue"
    exit 1
  fi
  printf 'Alpha row\nDelta row\n' >"$SCRATCH/apply.txt"
  out=$(TICK_REPO_ROOT="$root" bash "$root/scripts/$(basename "${BASH_SOURCE[0]}")" --apply --note " — done selftest" --titles "$SCRATCH/apply.txt" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "SELFTEST FAIL: --apply with known titles must exit 0"
    exit 1
  fi
  if [ "$(grep -c '^- \[x\] \[ready\] \*\*Alpha row\*\* — body — done selftest' "$root/TODO_LIST.md" "$root/docs/todo/pipeline.md" | cut -d: -f2 | tr '\n' ' ')" != "1 1 " ] ||
    ! grep -q '^- \[ \] \[ready\] \*\*Alpha row longer title\*\*' "$root/TODO_LIST.md" ||
    [ "$(grep -c '^- \[x\] \[blocked:user\] \*\*Delta row\*\* — body — done selftest' "$root/TODO_LIST.md")" != "1" ]; then
    echo "SELFTEST FAIL: --apply must flip exactly the titled rows on every surface"
    exit 1
  fi
  out=$(TICK_REPO_ROOT="$root" bash "$root/scripts/$(basename "${BASH_SOURCE[0]}")" --titles "$SCRATCH/apply.txt" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ] || ! printf '%s\n' "$out" | grep -q 'ALREADY 2' ; then
    echo "SELFTEST FAIL: a second run must report the rows ALREADY ticked and exit 0"
    exit 1
  fi
  echo "SELFTEST OK: dry-run writes nothing, exact-title only, queue+library flip, note appended, idempotent, unknown title exits 1"
  exit 0
}

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

survey "$TITLES_FILE" "${targets[@]}" | sort >"$SCRATCH/survey.tsv"

missing=0 flipping=0 already=0
while IFS=$'\t' read -r title surface state; do
  label="LIB"
  case "$surface" in
  QUEUE) label="QUEUE" ;;
  docs/todo/*) label="${surface#docs/todo/}" ;;
  esac
  case "$state" in
  open)
    flipping=$((flipping + 1))
    printf 'OPEN    %-28s %s\n' "$label" "$title"
    ;;
  done)
    already=$((already + 1))
    printf 'ALREADY %-28s %s\n' "$label" "$title"
    ;;
  -)
    missing=$((missing + 1))
    printf 'NOT-FOUND %s\n' "$title"
    ;;
  esac
done <"$SCRATCH/survey.tsv"

awk -F'\t' '{ n[$1]++; if ($3 == "open") o[$1]++; if ($2 == "QUEUE") q[$1]++; else if ($2 != "-") l[$1]++ }
  END { for (t in n) if (n[t] && (o[t] + 0) > 0 && ((q[t] + l[t]) == 1)) print "SINGLE-SURFACE " t }' "$SCRATCH/survey.tsv" |
  while IFS= read -r line; do printf '%s\n' "$line"; done

if [ "$APPLY" -eq 1 ] && [ "$flipping" -gt 0 ]; then
  if [ "$missing" -gt 0 ]; then
    echo "REFUSED: $missing title(s) not found — fix the list, nothing was written"
    exit 1
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
        if ($0 ~ /^- \[ \] / && match($0, /^- \[ \] (\[[^]]*\] )?\*\*[^*]+\*\*/)) {
          t = substr($0, RSTART, RLENGTH)
          sub(/^- \[ \] */, "", t)
          sub(/^\[[^]]*\] */, "", t)
          sub(/^\*\*/, "", t)
          sub(/\*\*$/, "", t)
          if (t in want) {
            sub(/^- \[ \]/, "- [x]")
            if (note != "") $0 = $0 note
          }
        }
        print
      }
    ' "$target" >"$out"
    if ! cmp -s "$out" "$target"; then
      cat "$out" >"$target"
      printf 'WROTE   %s\n' "${target#"$REPO_ROOT"/}"
    fi
    rm -f "$out"
  done
  echo "APPLIED: $flipping row(s) ticked ($NOTE)"
else
  [ "$missing" -gt 0 ] && echo "DRY-RUN: $flipping row(s) would flip, $already already done, $missing not found"
  [ "$missing" -eq 0 ] && echo "DRY-RUN: $flipping row(s) would flip, $already already done — add --apply to write"
fi
[ "$missing" -eq 0 ]
