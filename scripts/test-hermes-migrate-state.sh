#!/usr/bin/env bash
# Behavioral fixture for hermes-migrate-state (the ExecStartPre script,
# store-extracted via the evaluated evo-x2 config by
# checks.hermes-migrate-fixture). Covers the WAL-gated integrity branches
# of the 2026-10-06 restructure (the only zero-coverage branch per
# docs/todo/pipeline.md row 944) PLUS the 2026-10-19 start-budget rework:
# the bounded census, its integrity-pending marker, and every convergence
# path. sqlite3 is sed-rewritten onto an env-switched stub; rsync stays
# real (the legacy-migration leg exercises it).
#
# Usage: test-hermes-migrate-state.sh <extracted-migrate-script> <old-state-dir-placeholder-assert>
set -euo pipefail

MIGRATE_BIN="${1:?usage: test-hermes-migrate-state.sh <extracted-script>}"
OLD_STATE_ASSERT="${2-}"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
STATE="$scratch/state"
mkdir -p "$STATE"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# 1MB threshold used by the script's existing-state skip.
make_db() {
  head -c 2097152 /dev/zero >"$STATE/state.db"
}

# Env-switched sqlite3 stub; every invocation is journaled for asserts.
cat >"$scratch/sqlite3-stub" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${SQLITE_STUB_LOG:?}"
case "${SQLITE_STUB_MODE:-ok}" in
  ok) echo "ok" ;;
  corrupt)
    echo "Page 4: never used"
    exit 1
    ;;
  timeout) exit 124 ;;
  *) echo "unknown stub mode" >&2; exit 70 ;;
esac
EOF
chmod +x "$scratch/sqlite3-stub"

# Render a runnable copy: bake the scratch state dir over the interpolated
# NEW= and point both sqlite3 call sites at the stub. The cfg.user/group
# substitutions only fire on a RAW Nix-text extraction (the store copy
# has them baked) — they keep the script runnable in both modes.
render() {
  sed -e "s|^NEW=.*|NEW=\"$STATE\"|" \
    -e "s|\${cfg.user}|hermes|g" -e "s|\${cfg.group}|hermes|g" \
    -e "s|sqlite3 \"|$scratch/sqlite3-stub \"|g" "$MIGRATE_BIN"
}
RENDERED="$scratch/migrate.sh"
render >"$RENDERED"

assert_no_marker() {
  [ ! -e "$STATE/state.db.integrity-pending" ] || fail "marker present: $1"
}
assert_marker() {
  [ -e "$STATE/state.db.integrity-pending" ] || fail "marker missing: $1"
}

# --- leg 1: clean shutdown (no -wal) + existing state -> census skipped.
# Row 944's clean-shutdown leg: the integrity path must NOT fire.
make_db
SQLITE_STUB_LOG="$scratch/log1"
: >"$SQLITE_STUB_LOG"
SQLITE_STUB_LOG="$SQLITE_STUB_LOG" bash "$RENDERED" >"$scratch/out1" 2>&1
grep -q "skipping migration" "$scratch/out1" || fail "leg1: expected skip, got: $(cat "$scratch/out1")"
[ ! -s "$SQLITE_STUB_LOG" ] || fail "leg1: census ran on a clean shutdown"
assert_no_marker "leg1"

# --- leg 2: unclean shutdown (-wal present) + ok census -> proceeds,
# pragma re-assert ran. Row 944's unclean-signal leg.
make_db
: >"$STATE/state.db-wal"
SQLITE_STUB_LOG="$scratch/log2"
: >"$SQLITE_STUB_LOG"
SQLITE_STUB_LOG="$SQLITE_STUB_LOG" bash "$RENDERED" >"$scratch/out2" 2>&1
grep -q "skipping migration" "$scratch/out2" || fail "leg2: expected skip after ok census, got: $(cat "$scratch/out2")"
grep -q "journal_mode=WAL" "$SQLITE_STUB_LOG" || fail "leg2: pragma re-assert did not run"
assert_no_marker "leg2"

# --- leg 3: unclean shutdown + census exceeds the start budget ->
# marker dropped, gateway start proceeds (exit 0), db untouched.
make_db
: >"$STATE/state.db-wal"
SQLITE_STUB_LOG="$scratch/log3"
: >"$SQLITE_STUB_LOG"
SQLITE_STUB_MODE=timeout SQLITE_STUB_LOG="$SQLITE_STUB_LOG" \
  bash "$RENDERED" >"$scratch/out3" 2>&1
grep -q "deferred to hermes-db-health" "$scratch/out3" || fail "leg3: no deferral line, got: $(cat "$scratch/out3")"
assert_marker "leg3"
ls "$STATE"/state.db.malformed-* >/dev/null 2>&1 && fail "leg3: malformed backup on a mere timeout"

# --- leg 4: unclean shutdown + malformed verdict -> backup + wals removed
# (the pre-existing fail-closed-to-fresh contract, unchanged).
make_db
: >"$STATE/state.db-wal"
: >"$STATE/state.db-shm"
SQLITE_STUB_LOG="$scratch/log4"
: >"$SQLITE_STUB_LOG"
SQLITE_STUB_MODE=corrupt SQLITE_STUB_LOG="$SQLITE_STUB_LOG" \
  bash "$RENDERED" >"$scratch/out4" 2>&1
grep -q "malformed" "$scratch/out4" || fail "leg4: no malformed line, got: $(cat "$scratch/out4")"
ls "$STATE"/state.db.malformed-* >/dev/null 2>&1 || fail "leg4: no malformed backup"
[ ! -e "$STATE/state.db-wal" ] || fail "leg4: wal not removed"
[ ! -e "$STATE/state.db-shm" ] || fail "leg4: shm not removed"
assert_no_marker "leg4"

# --- leg 5: pending marker + calm re-attempt -> census completes, marker
# cleared (the boot-after convergence path).
make_db
: >"$STATE/state.db.integrity-pending"
SQLITE_STUB_LOG="$scratch/log5"
: >"$SQLITE_STUB_LOG"
SQLITE_STUB_LOG="$SQLITE_STUB_LOG" bash "$RENDERED" >"$scratch/out5" 2>&1
assert_no_marker "leg5"

# --- leg 6: pending marker + storm again -> marker survives, start
# proceeds (convergence may take several boot cycles).
make_db
: >"$STATE/state.db.integrity-pending"
SQLITE_STUB_LOG="$scratch/log6"
: >"$SQLITE_STUB_LOG"
SQLITE_STUB_MODE=timeout SQLITE_STUB_LOG="$SQLITE_STUB_LOG" \
  bash "$RENDERED" >"$scratch/out6" 2>&1
assert_marker "leg6"

# --- leg 7: stale marker with no db (fresh state) -> marker cleared.
rm -f "$STATE"/state.db*
: >"$STATE/state.db.integrity-pending"
SQLITE_STUB_LOG="$scratch/log7"
: >"$SQLITE_STUB_LOG"
SQLITE_STUB_LOG="$SQLITE_STUB_LOG" bash "$RENDERED" >"$scratch/out7" 2>&1
assert_no_marker "leg7"

# --- leg 8: legacy migration path still works (real rsync).
OLDSTATE="$scratch/oldstate"
mkdir -p "$OLDSTATE"
echo payload >"$OLDSTATE/legacy.txt"
sed -e "s|for OLD in .*; do|for OLD in \"$OLDSTATE\"; do|" \
  -e "s|\${cfg.user}|hermes|g" -e "s|\${cfg.group}|hermes|g" \
  "$RENDERED" >"$scratch/migrate-old.sh"
rm -f "$STATE"/state.db*
bash "$scratch/migrate-old.sh" >"$scratch/out8" 2>&1
grep -q "migration complete" "$scratch/out8" || fail "leg8: migration did not complete, got: $(cat "$scratch/out8")"
[ -e "$STATE/legacy.txt" ] || fail "leg8: rsync did not land the legacy file"
[ -e "$STATE/state.db" ] || fail "leg8: legacy db not migrated"

# --- eval-side pin: the OLD list interpolation must remain a single `for
# OLD in` line (leg 8's sed depends on it) and the marker/budget seams
# must exist in the extracted text.
grep -q "integrity-pending" "$MIGRATE_BIN" || fail "extracted script lost the marker"
grep -q 'HERMES_DB_CHECK_BUDGET' "$MIGRATE_BIN" || fail "extracted script lost the budget seam"
grep -q 'timeout "$CHECK_BUDGET"' "$MIGRATE_BIN" || fail "extracted script lost the bounded census"
[ -z "$OLD_STATE_ASSERT" ] || grep -q "for OLD in" "$MIGRATE_BIN" || fail "OLD list shape drifted"

echo "hermes-migrate-state fixture: all legs green"
