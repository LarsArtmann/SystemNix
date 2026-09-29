#!/usr/bin/env bash
# test-migrate-hot-db — fixture test for scripts/migrate-hot-db.sh (the
# 2026-09-30 storage.md row: an untested destructive script is the worst
# first contact — this ran BEFORE any user migration window).
#
# Strategy: PATH-injected stubs for everything that needs root or touches
# the real system (btrfs, chattr, systemctl, mountpoint, ionice, nice) +
# REAL rsync/find/du against /tmp fixtures, via the script's env overrides
# (MIGRATE_TOPLEVEL / MIGRATE_PSI_FILE / MIGRATE_ROOT_UID) and its generic
# `<name> <dataDir> <unit...>` registry-escape form.
#
# Covers: warm prepare (no stop), cutover stop-set + delta + --delete +
# exact verify + marker, finalize verify + restart, dry-run no-mutation
# (the old script crashed at its verify step on a never-created staging
# tree), and the refusal gates (PSI, already-mounted, missing subvol).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT_UNDER_TEST=$HERE/migrate-hot-db.sh

FAILURES=0
ok() {
  echo "PASS: $1"
}
fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}
assert_contains() {
  if grep -qF -- "$2" "$1"; then
    ok "$3"
  else
    fail "$3 (expected '$2' in '$1')"
  fi
}

# ── fixture scaffolding ─────────────────────────────────────────────────────
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
BIN="$SCRATCH/bin"
mkdir -p "$BIN"

export MIGRATE_TOPLEVEL="$SCRATCH/hot"
export MIGRATE_PSI_FILE="$SCRATCH/psi-ok"
export MIGRATE_ROOT_UID=$(id -u)
export FAKE_SUBVOLS="$SCRATCH/subvols.list"
export SYSTEMCTL_LOG="$SCRATCH/systemctl.log"
export MOUNTPOINT_LIST="$SCRATCH/mountpoints.list"

# mountpoint stub: YES iff the path is listed in $MOUNTPOINT_LIST
cat >"$BIN/mountpoint" <<'EOF'
#!/usr/bin/env bash
# fixture stub
grep -qxF "$2" "$MOUNTPOINT_LIST" 2>/dev/null && exit 0 || exit 1
EOF
# btrfs stub: subvolume create/show against $FAKE_SUBVOLS (marker OUTSIDE
# the tree — an inside marker would break the count verify)
cat >"$BIN/btrfs" <<'EOF'
#!/usr/bin/env bash
# fixture stub
set -e
if [ "$1" = "subvolume" ] && [ "$2" = "show" ]; then
  grep -qxF "$3" "$FAKE_SUBVOLS" 2>/dev/null || exit 1
elif [ "$1" = "subvolume" ] && [ "$2" = "create" ]; then
  mkdir -p "$3"
  echo "$3" >>"$FAKE_SUBVOLS"
else
  echo "fixture btrfs stub: unsupported args: $*" >&2
  exit 3
fi
EOF
cat >"$BIN/chattr" <<'EOF'
#!/usr/bin/env bash
# fixture stub: no-op (cow=true entries never chattr anyway)
exit 0
EOF
cat >"$BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
# fixture stub: log and succeed
echo "$*" >>"$SYSTEMCTL_LOG"
exit 0
EOF
# ionice/nice pass-throughs: the sandbox has no scheduler classes to set
cat >"$BIN/ionice" <<'EOF'
#!/usr/bin/env bash
# fixture stub
shift 2 2>/dev/null || true
exec "$@"
EOF
cat >"$BIN/nice" <<'EOF'
#!/usr/bin/env bash
# fixture stub
[ "$1" = "-n" ] && shift 2
exec "$@"
EOF
# SANDBOX SHEBANG TRAP (forgejo-fixture lesson): /usr/bin/env does not
# exist inside the nix build sandbox — rewrite every stub's interpreter
# line to the bash RUNNING THIS TEST ($BASH), so the stubs exec there too.
for stub in "$BIN"/*; do
  sed -i "1c #!$BASH" "$stub"
done
chmod +x "$BIN"/*
export PATH="$BIN:$PATH"

printf 'some avg10=1.0 avg60=1.0 avg300=1.0 total=0\n' >"$SCRATCH/psi-ok"
printf 'some avg10=99.0 avg60=80.0 avg300=60.0 total=999999\n' >"$SCRATCH/psi-bad"
: >"$FAKE_SUBVOLS"
: >"$SYSTEMCTL_LOG"
: >"$MOUNTPOINT_LIST"
mkdir -p "$MIGRATE_TOPLEVEL"
echo "$MIGRATE_TOPLEVEL" >"$MOUNTPOINT_LIST" # tier_gate passes by default

DATA="$SCRATCH/varlib/fixture"
SUBVOL="$MIGRATE_TOPLEVEL/hot/fixture-name"
STATE="$MIGRATE_TOPLEVEL/hot/.migrate-state/fixture-name"
mkfixture() {
  rm -rf "$DATA" "$SUBVOL"
  : >"$FAKE_SUBVOLS"
  mkdir -p "$DATA/nested"
  echo "seed-data" >"$DATA/main.db"
  echo "wal" >"$DATA/main.db-wal"
  echo "deep" >"$DATA/nested/other.db"
}

# The script's generic form (registry escape): name dataDir unit [units...]
run_migrate() {
  bash "$SCRIPT_UNDER_TEST" "$@"
}

# ── 1. prepare: warm copy, service NOT stopped ─────────────────────────────
mkfixture
out=$(run_migrate prepare fixture-name "$DATA" fixture.service extra.timer 2>&1) || {
  fail "prepare exited non-zero: $out"
  exit 1
}
grep -qxF "$SUBVOL" "$FAKE_SUBVOLS" && ok "prepare created the subvol" || fail "prepare did not create subvol"
diff -r "$DATA" "$SUBVOL" >/dev/null && ok "prepare copied the tree verbatim" || fail "prepare copy differs"
[ ! -s "$SYSTEMCTL_LOG" ] && ok "prepare stopped NOTHING (warm)" || fail "prepare stopped units: $(cat "$SYSTEMCTL_LOG")"
[ ! -f "$STATE" ] && ok "prepare wrote no marker" || fail "prepare wrote a marker early"

# ── 2. prepare refusal: IO PSI storm ───────────────────────────────────────
mkfixture
out=$(MIGRATE_PSI_FILE="$SCRATCH/psi-bad" run_migrate prepare fixture-name "$DATA" fixture.service 2>&1) && fail "prepare ran during IO storm" || {
  grep -q "REFUSED: IO PSI" <<<"$out" && ok "prepare refuses on IO PSI" || fail "prepare failed for wrong reason: $out"
}
grep -qxF "$SUBVOL" "$FAKE_SUBVOLS" && fail "stormed prepare still created the subvol" || ok "stormed prepare created nothing"

# ── 3. prepare refusal: dataDir already a mountpoint ───────────────────────
mkfixture
mkdir -p "$SUBVOL" # ensure subvol side exists so the mount check is the only gate
echo "$SUBVOL" >>"$FAKE_SUBVOLS"
echo "$DATA" >>"$MOUNTPOINT_LIST"
out=$(run_migrate prepare fixture-name "$DATA" fixture.service 2>&1) && fail "prepare ran on an already-mounted dataDir" || {
  grep -q "already a mountpoint" <<<"$out" && ok "prepare refuses already-mounted" || fail "prepare failed for wrong reason: $out"
}
grep -vxF "$DATA" "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"

# ── 4. cutover: stop-set, delta, --delete, exact verify, marker ──────────────
mkfixture
run_migrate prepare fixture-name "$DATA" fixture.service extra.timer >/dev/null 2>&1
# drift after the warm pass: one new file, one removed
echo "post-warm write" >"$DATA/main.db"
rm "$DATA/nested/other.db"
: >"$SYSTEMCTL_LOG"
out=$(run_migrate cutover fixture-name "$DATA" fixture.service extra.timer 2>&1) || {
  fail "cutover exited non-zero: $out"
  exit 1
}
grep -q "stop fixture.service" "$SYSTEMCTL_LOG" && ok "cutover stopped the main unit" || fail "cutover did not stop fixture.service"
grep -q "stop extra.timer" "$SYSTEMCTL_LOG" && ok "cutover stopped the sidecar timer" || fail "cutover did not stop extra.timer"
grep -q "systemctl start" "$SYSTEMCTL_LOG" && fail "cutover started units early" || ok "cutover left units stopped"
diff -r "$DATA" "$SUBVOL" >/dev/null && ok "cutover delta synced exactly (--delete removed the stale file)" || fail "cutover trees differ: $(diff -r "$DATA" "$SUBVOL" || true)"
[ -f "$STATE" ] && ok "cutover wrote the marker" || fail "cutover wrote no marker"
grep -q "^FILES=2$" "$STATE" && ok "marker carries the file count" || fail "marker file count wrong: $(cat "$STATE")"

# ── 5. cutover refusal: missing subvol ──────────────────────────────────────
out=$(run_migrate cutover no-such-entry "$DATA" x.service 2>&1) && fail "cutover ran without a prepared subvol" || {
  grep -q "missing — run prepare first" <<<"$out" && ok "cutover refuses unprepared entry" || fail "cutover failed for wrong reason: $out"
}

# ── 6. finalize: verify + restart ───────────────────────────────────────────
echo "$DATA" >>"$MOUNTPOINT_LIST"
: >"$SYSTEMCTL_LOG"
out=$(run_migrate finalize fixture-name "$DATA" fixture.service extra.timer 2>&1) || {
  fail "finalize exited non-zero: $out"
  exit 1
}
grep -q "start fixture.service" "$SYSTEMCTL_LOG" && ok "finalize restarted the main unit" || fail "finalize did not start fixture.service"
grep -q "start extra.timer" "$SYSTEMCTL_LOG" && ok "finalize restarted the sidecar timer" || fail "finalize did not start extra.timer"
# finalize verify: fewer files than marker must FAIL (defect 2 — old finalize
# verified nothing). Drop files behind the stubbed mountpoint and re-run.
find "$DATA" -type f -delete
out=$(run_migrate finalize fixture-name "$DATA" fixture.service extra.timer 2>&1) && fail "finalize passed with a gutted dataDir" || {
  grep -q "VERIFY FAILED" <<<"$out" && ok "finalize fails on missing files" || fail "finalize failed for wrong reason: $out"
}
grep -vxF "$DATA" "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"

# ── 7. finalize refusal: not a mountpoint ───────────────────────────────────
out=$(run_migrate finalize fixture-name "$DATA" fixture.service 2>&1) && fail "finalize ran before the deploy" || {
  grep -q "not a mountpoint" <<<"$out" && ok "finalize refuses pre-deploy" || fail "finalize failed for wrong reason: $out"
}

# ── 8. dry-run: no mutation (defect 3 regression) ───────────────────────────
mkfixture
: >"$FAKE_SUBVOLS"
: >"$SYSTEMCTL_LOG"
run_migrate --dry-run prepare fixture-name "$DATA" fixture.service >/dev/null 2>&1 || fail "dry-run prepare exited non-zero"
[ ! -s "$FAKE_SUBVOLS" ] && ok "dry-run created no subvol" || fail "dry-run created a subvol"
[ ! -e "$SUBVOL" ] && ok "dry-run copied nothing" || fail "dry-run mutated the subvol path"
[ ! -s "$SYSTEMCTL_LOG" ] && ok "dry-run touched no units" || fail "dry-run ran systemctl"

# ── 9. status: prints the registry ──────────────────────────────────────────
out=$(run_migrate status 2>&1)
grep -qF "gatus: dataDir=/var/lib/private/gatus" <<<"$out" && ok "status lists the registry" || fail "status output missing gatus: $out"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "ALL migrate-hot-db fixture tests passed"
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED"
  exit 1
fi
