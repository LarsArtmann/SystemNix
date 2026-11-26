#!/usr/bin/env bash
# check-todo-bulk.sh — refuse a staged queue diff that adds too many open
# rows in one commit.
#
# One bulk harvest added 1,538 open rows to TODO_LIST.md on 2026-11-07; 42 %
# of the open queue was still that day's harvest on 2026-11-26 (plan v6 T03
# ruling pack). This guard makes the next such commit stop at the hook: a
# staged diff of the queue that ADDS more than LIMIT lines of the open-row
# shape fails the commit.
#
# What counts: added lines that start with `- [ ] `. Ticked rows
# (`- [x] `) do not count, and removed rows never offset added ones (a
# commit that swaps 1,500 old rows for 1,500 new ones is still a bulk
# harvest). Only TODO_LIST.md is read; the libraries are not a dispatch
# surface.
#
# The override is the owner's: TODO_BULK_HARVEST_OK=1 (non-empty) lets the
# commit through and prints why it was allowed. Agents do not set it.
#
# Usage:
#   bash scripts/check-todo-bulk.sh             # gate: reads the STAGED diff
#   bash scripts/check-todo-bulk.sh --selftest  # proves 50 pass and 51 fail
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE="TODO_LIST.md"
LIMIT=50
OVERRIDE="TODO_BULK_HARVEST_OK"

staged_open_additions() {
  git -C "$REPO_ROOT" diff --cached -U0 -- "$QUEUE" 2>/dev/null | grep -c '^+- \[ \] ' || true
}

selftest() {
  # A commit hook exports the committing repository's git environment
  # (GIT_INDEX_FILE names the index being committed). Inherited by the
  # scratch repo, `git add` writes the scratch queue into THAT index and
  # the scratch commits die on objects the scratch object store never had,
  # so every commit through the hook failed a selftest leg and was refused
  # with a bogus count (2026-11-26, 60 rows against a 3-line tick).
  unset GIT_INDEX_FILE GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR \
    GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE \
    GIT_INDEX_VERSION GIT_PREFIX
  local scratch out rc
  scratch=$(mktemp -d)
  mkdir -p "$scratch/repo/scripts"
  cp "${BASH_SOURCE[0]}" "$scratch/repo/scripts/"
  git -C "$scratch/repo" init -q
  git -C "$scratch/repo" -c user.name=selftest -c user.email=selftest@example.invalid commit -q --allow-empty -m base
  printf '# Queue\n\n' >"$scratch/repo/$QUEUE"
  local n
  for n in $(seq 1 10); do
    printf -- '- [ ] [ready] **Base row %s** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n' "$n" >>"$scratch/repo/$QUEUE"
  done
  git -C "$scratch/repo" add "$QUEUE"
  git -C "$scratch/repo" -c user.name=selftest -c user.email=selftest@example.invalid commit -q -m "base queue"
  local guard
  guard="$scratch/repo/scripts/$(basename "${BASH_SOURCE[0]}")"

  add_rows() {
    # $1 = count, $2 = state (space or x), $3 = first index
    local i
    for i in $(seq "$3" $((("$3" + "$1") - 1))); do
      printf -- '- [%s] [ready] **Staged row %s** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n' "$2" "$i" >>"$scratch/repo/$QUEUE"
    done
    git -C "$scratch/repo" add "$QUEUE"
  }

  reset_queue() {
    git -C "$scratch/repo" restore --staged --worktree "$QUEUE"
  }

  expect() {
    # $1 = wanted rc, $2 = description, $3 = output
    if [ "$rc" -ne "$1" ]; then
      echo "SELFTEST FAIL: $2 (rc=$rc, wanted $1)"
      echo "$3"
      rm -rf "$scratch"
      exit 1
    fi
  }

  out=$(bash "$guard" 2>&1) && rc=0 || rc=$?
  expect 0 "no staged queue diff passes" "$out"
  add_rows "$LIMIT" " " 1
  out=$(bash "$guard" 2>&1) && rc=0 || rc=$?
  expect 0 "exactly $LIMIT staged open rows pass" "$out"
  reset_queue
  add_rows $(("$LIMIT" + 1)) " " 1
  out=$(env -u "$OVERRIDE" bash "$guard" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -q "51 staged open rows in $QUEUE exceed the limit of $LIMIT"; then
    echo "SELFTEST FAIL: 51 staged open rows must fail with the count and the limit"
    echo "$out"
    rm -rf "$scratch"
    exit 1
  fi
  out=$(env "$OVERRIDE=1" bash "$guard" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ] || ! printf '%s\n' "$out" | grep -q "$OVERRIDE"; then
    echo "SELFTEST FAIL: the owner override must pass and name itself"
    echo "$out"
    rm -rf "$scratch"
    exit 1
  fi
  reset_queue
  add_rows $(("$LIMIT" + 1)) x 1
  out=$(env -u "$OVERRIDE" bash "$guard" 2>&1) && rc=0 || rc=$?
  expect 0 "ticked rows never count" "$out"
  reset_queue
  sed -i '1,6d' "$scratch/repo/$QUEUE"
  add_rows 3 " " 1
  git -C "$scratch/repo" add "$QUEUE"
  out=$(env -u "$OVERRIDE" bash "$guard" 2>&1) && rc=0 || rc=$?
  expect 0 "removed rows never offset added ones, and a small addition passes" "$out"
  reset_queue
  add_rows 30 " " 1
  add_rows 30 " " 31
  out=$(env -u "$OVERRIDE" bash "$guard" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST FAIL: two adds of 30 rows each are 60 staged rows and must fail"
    rm -rf "$scratch"
    exit 1
  fi
  rm -rf "$scratch"
  echo "SELFTEST OK: 0 and $LIMIT staged open rows pass, $((LIMIT + 1)) fail with count and limit, the owner override passes and names itself, ticked rows and removed rows never count, two adds sum"
  exit 0
}

case "${1:-}" in
--selftest) selftest ;;
-*)
  echo "check-todo-bulk: unknown option $1" >&2
  exit 2
  ;;
esac

count=$(staged_open_additions)
if [ "$count" -gt "$LIMIT" ]; then
  if [ -n "${!OVERRIDE:-}" ]; then
    echo "check-todo-bulk: $count staged open rows in $QUEUE exceed the limit of $LIMIT, allowed by $OVERRIDE"
    exit 0
  fi
  echo "FAIL: $count staged open rows in $QUEUE exceed the limit of $LIMIT in one commit."
  echo "       A bulk harvest cannot enter the queue through a commit (1,538 rows arrived this way on 2026-11-07)."
  echo "       Split the work, or let the owner set $OVERRIDE=1 for this commit."
  exit 1
fi
