#!/usr/bin/env bash
# Behavioral fixture for hermes-db-health (the deferred-census converger,
# store-extracted via the evaluated evo-x2 config by
# checks.hermes-migrate-fixture). Covers: the no-marker fast path, the
# PSI calm-wait loop (seamed file + zero poll interval), the ok
# convergence, the malformed hot-swap (backup + marker clear + hermes
# restart via a stubbed systemctl), and the cannot-complete retry path.
#
# Usage: test-hermes-db-health.sh <extracted-db-health-script>
set -euo pipefail

HEALTH_BIN="${1:?usage: test-hermes-db-health.sh <extracted-script>}"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
STATE="$scratch/state"
mkdir -p "$STATE"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_db() {
  head -c 2097152 /dev/zero >"$STATE/state.db"
}

cat >"$scratch/sqlite3-stub" <<'EOF'
#!/usr/bin/env bash
case "${SQLITE_STUB_MODE:-ok}" in
  ok) echo "ok" ;;
  corrupt)
    echo "Page 4: never used"
    exit 1
    ;;
  locked)
    echo "Error: database is locked" >&2
    exit 1
    ;;
  *) echo "unknown stub mode" >&2; exit 70 ;;
esac
EOF
chmod +x "$scratch/sqlite3-stub"

cat >"$scratch/systemctl-stub" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${SYSTEMCTL_LOG:?}"
EOF
chmod +x "$scratch/systemctl-stub"

# Render a runnable copy: scratch state dir, stubbed sqlite3, stubbed
# systemctl (both forms: the baked store path of a real extraction AND the
# literal ${pkgs.systemd} of a raw Nix-text extraction), seamed PSI file.
PSI_FILE="$scratch/psi"
render() {
  sed -E -e "s|^NEW=.*|NEW=\"$STATE\"|" \
    -e "s|sqlite3 \"|$scratch/sqlite3-stub \"|g" \
    -e "s|/nix/store/[a-z0-9]+-systemd-[^\"]*/bin/systemctl|$scratch/systemctl-stub|g" \
    -e "s|\\\$\{pkgs\.systemd\}/bin/systemctl|$scratch/systemctl-stub|g" \
    "$HEALTH_BIN"
}
RENDERED="$scratch/db-health.sh"
render >"$RENDERED"

run() {
  HERMES_DB_HEALTH_PSI_FILE="$PSI_FILE" \
    HERMES_DB_HEALTH_POLL_SEC="${POLL_SEC:-0}" \
    HERMES_DB_HEALTH_WAIT_CYCLES="${WAIT_CYCLES:-12}" \
    HERMES_DB_HEALTH_PSI_LIMIT="${PSI_LIMIT:-20}" \
    SYSTEMCTL_LOG="$scratch/systemctl-calls" \
    SQLITE_STUB_MODE="${SQLITE_STUB_MODE:-ok}" \
    bash "$RENDERED"
}

psi() {
  printf 'some avg10=%s avg60=0.00 avg300=0.00 total=1\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=1\n' "$1" >"$PSI_FILE"
}

# --- leg 1: no pending marker -> fast no-op regardless of pressure.
psi 95.00
run >"$scratch/out1" 2>&1
grep -q "nothing to do" "$scratch/out1" || fail "leg1: expected fast exit, got: $(cat "$scratch/out1")"

# --- leg 2: marker + calm PSI -> census runs immediately, ok clears the
# marker, no restart.
make_db
: >"$STATE/state.db.integrity-pending"
psi 5.00
: >"$scratch/systemctl-calls"
run >"$scratch/out2" 2>&1
grep -q "converged ok" "$scratch/out2" || fail "leg2: no convergence, got: $(cat "$scratch/out2")"
[ ! -e "$STATE/state.db.integrity-pending" ] || fail "leg2: marker not cleared"
[ ! -s "$scratch/systemctl-calls" ] || fail "leg2: restart on a healthy db"

# --- leg 3: marker + storm PSI -> waits out the cycles (zero poll sec),
# then runs anyway and converges.
make_db
: >"$STATE/state.db.integrity-pending"
psi 92.00
WAIT_CYCLES=3 run >"$scratch/out3" 2>&1
grep -q "io calm after 3 of 3 wait cycles" "$scratch/out3" || fail "leg3: wait loop did not burn the cap, got: $(cat "$scratch/out3")"
grep -q "converged ok" "$scratch/out3" || fail "leg3: census did not run after the cap"
[ ! -e "$STATE/state.db.integrity-pending" ] || fail "leg3: marker not cleared"

# --- leg 4: marker + PSI recovering below the limit mid-loop -> converges
# (the loop must break on calm, not exhaust the cap). Deterministic flip:
# poll interval 0.2s, calm lands at 0.05s, so cycle 2 reads the calm file.
make_db
: >"$STATE/state.db.integrity-pending"
psi 88.00
(
  sleep 0.05
  psi 3.00
) &
flip=$!
POLL_SEC=0.2 WAIT_CYCLES=12 run >"$scratch/out4" 2>&1
wait "$flip"
grep -q "io calm after 1 of 12 wait cycles" "$scratch/out4" || fail "leg4: loop did not break on calm, got: $(cat "$scratch/out4")"

# --- leg 5: marker + malformed verdict -> backup, wals/marker cleared,
# hermes restarted via systemctl (reset-failed then restart).
make_db
: >"$STATE/state.db-wal"
: >"$STATE/state.db-shm"
: >"$STATE/state.db.integrity-pending"
psi 5.00
: >"$scratch/systemctl-calls"
SQLITE_STUB_MODE=corrupt run >"$scratch/out5" 2>&1
grep -q "malformed" "$scratch/out5" || fail "leg5: no malformed line, got: $(cat "$scratch/out5")"
ls "$STATE"/state.db.malformed-* >/dev/null 2>&1 || fail "leg5: no malformed backup"
[ ! -e "$STATE/state.db-wal" ] || fail "leg5: wal not removed"
[ ! -e "$STATE/state.db.integrity-pending" ] || fail "leg5: marker not cleared"
grep -q "reset-failed hermes.service" "$scratch/systemctl-calls" || fail "leg5: no reset-failed"
grep -q "restart hermes.service" "$scratch/systemctl-calls" || fail "leg5: no restart"

# --- leg 6: stale marker, db gone (fresh state) -> marker cleared, no
# census, no restart.
: >"$STATE/state.db.integrity-pending"
psi 5.00
: >"$scratch/systemctl-calls"
run >"$scratch/out6" 2>&1
grep -q "clearing stale marker" "$scratch/out6" || fail "leg6: stale marker not cleared, got: $(cat "$scratch/out6")"
[ ! -e "$STATE/state.db.integrity-pending" ] || fail "leg6: marker survives"

# --- leg 7: census hits a lock window (live gateway checkpoint) ->
# transient class: marker kept, NO restart, unit fails (retry next start).
make_db
: >"$STATE/state.db-wal"
: >"$STATE/state.db-shm"
: >"$STATE/state.db.integrity-pending"
psi 5.00
: >"$scratch/systemctl-calls"
if SQLITE_STUB_MODE=locked run >"$scratch/out7" 2>&1; then
  fail "leg7: expected nonzero exit"
fi
grep -q "lock window" "$scratch/out7" || fail "leg7: no lock-window line, got: $(cat "$scratch/out7")"
[ -e "$STATE/state.db.integrity-pending" ] || fail "leg7: marker not kept"
[ -e "$STATE/state.db" ] || fail "leg7: db must survive a lock window"
[ ! -s "$scratch/systemctl-calls" ] || fail "leg7: restart on a lock window"

echo "hermes-db-health fixture: all legs green"
