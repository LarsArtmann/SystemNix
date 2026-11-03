#!/usr/bin/env bash
# test-hot-db-guard — fixture test for scripts/hot-db-shadow-guard.sh
# (the superb-v3 S-0038 storage row: the shadow-split guard's refusal
# branches get real coverage BEFORE they ever guard a production wave).
#
# Strategy: pure filesystem fixtures — the guard only uses coreutils
# (test/ls), so no PATH stubs are needed; every refusal class is a real
# scratch dir in a known state. The SUBVOL-MISSING precondition is the
# bootstrap's job (VM-tested in tests/test-hot-db.nix); here the contract
# under test is the fresh-create DECISION.
#
# Covers: fresh-entry CREATE (absent + empty dataDir), the two refusal
# classes (non-empty dataDir incl. dotfile-only, marker-without-subvol),
# fail-closed (unreadable dir), non-directory dataDir, usage, and the
# journal-grep-ability message contract (every REFUSE names the entry).
# Self-verifying assertion count: emitted PASS lines == anchored ok-call
# sites (the 21→22→23 hand-count drift class flips red here).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT_UNDER_TEST=$HERE/hot-db-shadow-guard.sh

FAILURES=0
PASS_COUNT=0
ok() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}
fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

guard() {
  "$SCRIPT_UNDER_TEST" "$@"
}

# ── 1. usage contract ───────────────────────────────────────────────────────
out=$(guard 2>&1) && fail "no-args invocation exited 0" || {
  grep -q "usage:" <<<"$out" && ok "wrong arity prints usage" || fail "no-args exit printed no usage: $out"
}
rc=0; guard a b c d >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok "wrong arity exits 2" || fail "wrong arity rc=$rc (want 2)"

# ── 2. fresh-entry CREATE paths ─────────────────────────────────────────────
out=$(guard "$SCRATCH/absent-dir" "$SCRATCH/absent-marker" alpha) && {
  grep -q "CREATE (alpha)" <<<"$out" && ok "absent dataDir → CREATE" || fail "absent dataDir verdict malformed: $out"
} || fail "absent dataDir refused: rc=$?"
mkdir -p "$SCRATCH/empty-dir"
out=$(guard "$SCRATCH/empty-dir" "$SCRATCH/empty-marker" beta) && {
  grep -q "CREATE (beta)" <<<"$out" && ok "empty dataDir → CREATE" || fail "empty dataDir verdict malformed: $out"
} || fail "empty dataDir refused"

# ── 3. the incident class: populated dataDir, no marker ────────────────────
mkdir -p "$SCRATCH/live-dir"
echo "live sqlite bytes" >"$SCRATCH/live-dir/discordsync.db"
out=$(guard "$SCRATCH/live-dir" "$SCRATCH/live-marker" discordsync 2>&1) && fail "populated dataDir got CREATE" || {
  rc=$?
  [ "$rc" -eq 1 ] && ok "populated dataDir refuses rc=1" || fail "populated dataDir rc=$rc (want 1)"
}
refusal=$(guard "$SCRATCH/live-dir" "$SCRATCH/live-marker" discordsync 2>&1 >/dev/null) || true
grep -q "REFUSE (discordsync)" <<<"$refusal" && grep -q "shadow-split" <<<"$refusal" && grep -q "migrate-hot-db" <<<"$refusal" \
  && ok "refusal names entry + shadow-split + remediation" \
  || fail "refusal message lost the contract fields: $refusal"

# dotfiles are data too (ls -A, not bare ls)
mkdir -p "$SCRATCH/dot-dir"
touch "$SCRATCH/dot-dir/.gitkeep"
out=$(guard "$SCRATCH/dot-dir" "$SCRATCH/dot-marker" gamma 2>&1) && fail "dotfile-only dir got CREATE" || {
  grep -q "REFUSE (gamma)" <<<"$out" && ok "dotfile-only dataDir refuses" || fail "dotfile-only refusal malformed: $out"
}

# ── 4. marker-without-subvol: ambiguous tier state ─────────────────────────
mkdir -p "$SCRATCH/marker-home"
printf 'FILES=3\nBYTES=42\n' >"$SCRATCH/marker-home/delta"
out=$(guard "$SCRATCH/absent-dir2" "$SCRATCH/marker-home/delta" delta 2>&1) && fail "marker+missing subvol got CREATE" || {
  grep -q "REFUSE (delta)" <<<"$out" && grep -q "marker" <<<"$out" \
    && ok "marker with missing subvol refuses" \
    || fail "marker refusal malformed: $out"
}
mkdir -p "$SCRATCH/empty-dir2"
out=$(guard "$SCRATCH/empty-dir2" "$SCRATCH/marker-home/delta" epsilon 2>&1) && fail "marker beats empty dataDir" || {
  grep -q "REFUSE (epsilon)" <<<"$out" && ok "marker refuses even on empty dataDir" || fail "marker-on-empty refusal malformed: $out"
}

# ── 5. fail-closed + non-directory ──────────────────────────────────────────
mkdir -p "$SCRATCH/locked-dir"
touch "$SCRATCH/locked-dir/secret"
chmod 000 "$SCRATCH/locked-dir"
out=$(guard "$SCRATCH/locked-dir" "$SCRATCH/locked-marker" zeta 2>&1) && fail "unreadable dir got CREATE" || {
  grep -q "fail-closed" <<<"$out" && ok "unreadable dataDir refuses fail-closed" || fail "unreadable refusal malformed: $out"
}
chmod 755 "$SCRATCH/locked-dir"
echo not-a-dir >"$SCRATCH/plain-file"
out=$(guard "$SCRATCH/plain-file" "$SCRATCH/file-marker" eta 2>&1) && fail "file dataDir got CREATE" || {
  grep -q "REFUSE (eta)" <<<"$out" && grep -q "not a directory" <<<"$out" \
    && ok "non-directory dataDir refuses" \
    || fail "non-directory refusal malformed: $out"
}

# ── self-verifying assertion count ─────────────────────────────────────────
SELF=${BASH_SOURCE[0]}
ANCHOR_RE='&& ok "|[|][|] ok "'
anchored=$(grep -E "$ANCHOR_RE" "$SELF" | grep -cv '^ANCHOR_RE=' || true)
anchored=${anchored:-0}
# +1: THIS check's own site is in the anchored count but emits only after
# the comparison passes — the success invariant is PASS_COUNT+1 == anchored.
[ "$anchored" -eq "$((PASS_COUNT + 1))" ] && ok "self-count ($((PASS_COUNT + 1)) emitted incl. this == $anchored anchored call sites)" || fail "assertion count drift: $((PASS_COUNT + 1)) emitted vs $anchored anchored call sites"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "ALL hot-db-shadow-guard fixture tests passed"
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED"
  exit 1
fi
