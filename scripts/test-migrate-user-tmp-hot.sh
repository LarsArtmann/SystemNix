#!/usr/bin/env bash
# test-migrate-user-tmp-hot — fixture test for
# scripts/migrate-user-tmp-hot.sh (storage-crisis plan S20: the E6 tmp
# migration shipped 2026-10-26 WITHOUT its ship-quality pair — an untested
# destructive script is the worst first contact; this closes it after the
# live window, same as test-migrate-caddy-logs-hot.sh did).
#
# Strategy (identical pattern): PATH-injected stubs for root-bound or
# system-touching binaries (mountpoint, btrfs, findmnt, mount, umount,
# runuser, ionice, nice, flock, maintenance-entry-gate) + REAL
# rsync/find/du/tar against a scratch fixture, via the script's
# TMP_MIGRATE_* env hooks.
#
# Covers: prepare happy path (subvol create + exact double-pass copy),
# already-mounted refusal, non-empty-subvol refusal, churning-source
# double-verify-fail, dry-run no-mutation, entry-gate refusal BEFORE any
# mutation, PSI refusal, finalize branches (not-mounted / no-files /
# happy via symlinked "mount"), and every shadow-cleanup guard
# (not-mounted, detached-Samsung same-device, pool-missing,
# archive-verify-fail leaves the shadow intact, happy path, dry-run).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT_UNDER_TEST=$HERE/migrate-user-tmp-hot.sh

FAILURES=0
ok() {
  echo "PASS: $1"
}
fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

# ── fixture scaffolding ─────────────────────────────────────────────────────
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
BIN="$SCRATCH/bin"
mkdir -p "$BIN"

REAL_RSYNC=$(command -v rsync)
REAL_TAR=$(command -v tar)

export TMP_MIGRATE_SRC="$SCRATCH/home/lars/tmp"
export TMP_MIGRATE_SUBVOL="$SCRATCH/hot/users/lars/tmp"
export TMP_MIGRATE_USER="$USER"
export TMP_MIGRATE_AUX="$SCRATCH/aux"
export TMP_MIGRATE_ARCHIVE_DIR="$SCRATCH/pool-backup"
export TMP_MIGRATE_PSI_FILE="$SCRATCH/psi-ok"
TMP_MIGRATE_ROOT_UID=$(id -u)
export TMP_MIGRATE_ROOT_UID
export FAKE_SUBVOLS="$SCRATCH/subvols.list"
export MOUNTPOINT_LIST="$SCRATCH/mountpoints.list"
export MOUNT_LOG="$SCRATCH/mount.log"
export FINDMNT_MAP="$SCRATCH/findmnt.map"
export FIXTURE_QLC_AT="$SCRATCH/qlc-at"

cat >"$BIN/mountpoint" <<'EOF'
#!/usr/bin/env bash
grep -qxF "$2" "$MOUNTPOINT_LIST" 2>/dev/null && exit 0 || exit 1
EOF
cat >"$BIN/btrfs" <<'EOF'
#!/usr/bin/env bash
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
cat >"$BIN/ionice" <<'EOF'
#!/usr/bin/env bash
shift 2 2>/dev/null || true
exec "$@"
EOF
cat >"$BIN/nice" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "-n" ] && shift 2
exec "$@"
EOF
cat >"$BIN/findmnt" <<'EOF'
#!/usr/bin/env bash
if [ "$2" = "SOURCE" ]; then
  awk -v p="$3" '$1 == p {print $2; found=1; exit} END {exit !found}' "$FINDMNT_MAP"
else
  exit 1
fi
EOF
# mount stub: an aux subvol=@ "mount" becomes a symlink to the fixture @
# tree — find/tar/delete then operate on real fixture files through it.
cat >"$BIN/mount" <<'EOF'
#!/usr/bin/env bash
echo "mount $*" >>"$MOUNT_LOG"
last="${@: -1}"
rmdir "$last" 2>/dev/null || true
ln -sfn "$FIXTURE_QLC_AT" "$last"
EOF
cat >"$BIN/umount" <<'EOF'
#!/usr/bin/env bash
echo "umount $*" >>"$MOUNT_LOG"
rm -f "${@: -1}"
EOF
# runuser stub: drop "-u USER --" and exec (the fixture runs as one user).
cat >"$BIN/runuser" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "-u" ] && shift 2
[ "${1:-}" = "--" ] && shift
exec "$@"
EOF
# rsync wrapper: RSYNC_MODE dispatches real / no-op / die (churn leg).
cat >"$BIN/rsync" <<EOF
#!/usr/bin/env bash
case "\${RSYNC_MODE:-real}" in
  real) exec "$REAL_RSYNC" "\$@" ;;
  none) exit 0 ;;
  die) exit 5 ;;
esac
EOF
# tar wrapper: TAR_MODE=truncated archives one file → count-mismatch verify
cat >"$BIN/tar" <<EOF
#!/usr/bin/env bash
if [ "\${TAR_MODE:-}" = "truncated" ] && [ "\$1" = "-C" ]; then
  exec "$REAL_TAR" -C "\$2" --zstd -cf "\$5" tmp/work-a.txt
fi
exec "$REAL_TAR" "\$@"
EOF
: >"$SCRATCH/gate.log"
echo admit >"$SCRATCH/gate-mode"
cat >"$BIN/maintenance-entry-gate" <<EOF
#!$BASH
echo "\$*" >>"$SCRATCH/gate.log"
if [ "\$(cat "$SCRATCH/gate-mode" 2>/dev/null || echo admit)" = "refuse" ]; then
  echo "REFUSE: migrate-user-tmp-hot — IO PSI some avg10=99.00% (>= 30% band)." >&2
  exit 1
fi
echo "OK: migrate-user-tmp-hot — IO PSI some avg10=1.0% (< 30), last guard trip: never"
EOF
cat >"$BIN/flock" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

# SANDBOX SHEBANG TRAP (forgejo-fixture lesson): rewrite every stub's
# interpreter to the bash running this test.
for stub in "$BIN"/*; do
  sed -i "1c #!$BASH" "$stub"
done
chmod +x "$BIN"/*
export PATH="$BIN:$PATH"
export MAINT_ENTRY_GATE_LOCK_DIR="$SCRATCH/lock"
mkdir -p "$MAINT_ENTRY_GATE_LOCK_DIR"

printf 'some avg10=1.0 avg60=1.0 avg300=1.0 total=0\n' >"$SCRATCH/psi-ok"
printf 'some avg10=99.0 avg60=80.0 avg300=60.0 total=999999\n' >"$SCRATCH/psi-bad"
SRC_F=$TMP_MIGRATE_SRC
SUBVOL_F=$TMP_MIGRATE_SUBVOL

mkfixture() {
  rm -rf "${SCRATCH:?}/home" "${SCRATCH:?}/hot" "${SCRATCH:?}/aux" "${SCRATCH:?}/pool-backup" "${SCRATCH:?}/qlc-at"
  : >"$FAKE_SUBVOLS"
  : >"$MOUNT_LOG"
  echo admit >"$SCRATCH/gate-mode"
  mkdir -p "$SRC_F/work" "$SCRATCH/pool-backup"
  echo "alpha" >"$SRC_F/work/work-a.txt"
  echo "beta" >"$SRC_F/work/work-b.txt"
  echo "top" >"$SRC_F/top.txt"
  # /mnt/hot is always mounted in the fixture universe.
  printf '/mnt/hot\n/mnt/pool\n' >"$MOUNTPOINT_LIST"
}

# ── Leg 1: prepare ──────────────────────────────────────────────────────────
mkfixture
if bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1; then
  COUNT=$(find "$SUBVOL_F" -type f | wc -l)
  [ "$COUNT" -eq 3 ] && ok "prepare: 3 files copied to subvol" || fail "prepare: expected 3 files, got $COUNT"
  grep -qxF "$SUBVOL_F" "$FAKE_SUBVOLS" && ok "prepare: subvol created+registered" || fail "prepare: subvol not registered"
else
  fail "prepare: happy path exited non-zero"
fi

mkfixture
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
if bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1; then
  fail "prepare: already-mounted SRC must refuse"
else
  ok "prepare: already-mounted SRC refused"
fi

mkfixture
mkdir -p "$SUBVOL_F"
echo "stale" >"$SUBVOL_F/leftover"
if bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1; then
  fail "prepare: non-empty subvol must refuse"
else
  ok "prepare: non-empty subvol refused (leftover survives: $(cat "$SUBVOL_F/leftover"))"
fi

mkfixture
if bash "$SCRIPT_UNDER_TEST" --dry-run prepare >/dev/null 2>&1; then
  [ -d "$SUBVOL_F" ] && fail "prepare: dry-run mutated the subvol path" || ok "prepare: dry-run no mutation"
else
  fail "prepare: dry-run exited non-zero"
fi

mkfixture
echo refuse >"$SCRATCH/gate-mode"
: >"$SCRATCH/gate.log"
if bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1; then
  fail "prepare: entry-gate refusal must fail the run"
else
  [ -d "$SUBVOL_F" ] && fail "prepare: entry-gate refusal mutated anyway" || ok "prepare: entry-gate refusal BEFORE any mutation"
fi

mkfixture
if TMP_MIGRATE_PSI_FILE="$SCRATCH/psi-bad" bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1; then
  fail "prepare: PSI>=80 must refuse"
else
  [ -d "$SUBVOL_F" ] && fail "prepare: PSI refusal mutated anyway" || ok "prepare: PSI>=80 refused before mutation"
fi

mkfixture
if RSYNC_MODE=die bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1; then
  fail "prepare: double rsync failure must fail the run"
else
  ok "prepare: churning source fails after second verify pass"
fi

# ── Leg 2: finalize ─────────────────────────────────────────────────────────
mkfixture
if bash "$SCRIPT_UNDER_TEST" finalize >/dev/null 2>&1; then
  fail "finalize: not-mounted SRC must refuse"
else
  ok "finalize: not-mounted SRC refused"
fi

# happy: a symlink plays the deployed mount (SRC IS the subvol view).
mkfixture
bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1
rm -rf "$SRC_F"
ln -s "$SUBVOL_F" "$SRC_F"
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
if bash "$SCRIPT_UNDER_TEST" finalize >/dev/null 2>&1; then
  ok "finalize: mount answers + user write probe verified"
else
  fail "finalize: happy path exited non-zero"
fi

mkfixture
bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1
find "$SUBVOL_F" -type f -delete
rm -rf "$SRC_F"
ln -s "$SUBVOL_F" "$SRC_F"
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
if bash "$SCRIPT_UNDER_TEST" finalize >/dev/null 2>&1; then
  fail "finalize: empty subvol must refuse"
else
  ok "finalize: no-files refusal"
fi

# ── Leg 3: shadow-cleanup ───────────────────────────────────────────────────
mkfixture
if bash "$SCRIPT_UNDER_TEST" shadow-cleanup >/dev/null 2>&1; then
  fail "shadow-cleanup: not-mounted SRC must refuse"
else
  ok "shadow-cleanup: not-mounted SRC refused"
fi

# detached-Samsung class: SRC on the SAME device as / → REFUSED.
mkfixture
bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1
rm -rf "$SRC_F"
ln -s "$SUBVOL_F" "$SRC_F"
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
printf '%s %s\n' / /dev/qlc-part "$SRC_F" /dev/qlc-part >"$FINDMNT_MAP"
if bash "$SCRIPT_UNDER_TEST" shadow-cleanup >/dev/null 2>&1; then
  fail "shadow-cleanup: same-device SRC must refuse"
else
  ok "shadow-cleanup: detached-Samsung same-device refused"
fi

# pool missing: archive target not a mountpoint.
mkfixture
bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1
rm -rf "$SRC_F"
ln -s "$SUBVOL_F" "$SRC_F"
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
printf '/mnt/pool\n' >"$MOUNTPOINT_LIST" # /mnt/pool absent now
printf '%s %s\n' / /dev/qlc-part "$SRC_F" /dev/samsung-subvol >"$FINDMNT_MAP"
if bash "$SCRIPT_UNDER_TEST" shadow-cleanup >/dev/null 2>&1; then
  fail "shadow-cleanup: missing pool must refuse"
else
  ok "shadow-cleanup: pool-missing refused"
fi

# archive-verify-fail must leave the shadow intact.
mkfixture
bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1
mkdir -p "$SCRATCH/qlc-at/home/lars/tmp/keep"
echo "insurance" >"$SCRATCH/qlc-at/home/lars/tmp/keep/shadow-file.txt"
rm -rf "$SRC_F"
ln -s "$SUBVOL_F" "$SRC_F"
printf '/mnt/hot\n/mnt/pool\n%s\n' "$SRC_F" >"$MOUNTPOINT_LIST"
printf '%s %s\n' / /dev/qlc-part "$SRC_F" /dev/samsung-subvol >"$FINDMNT_MAP"
if TAR_MODE=truncated bash "$SCRIPT_UNDER_TEST" shadow-cleanup >/dev/null 2>&1; then
  fail "shadow-cleanup: truncated archive must fail"
else
  [ -f "$SCRATCH/qlc-at/home/lars/tmp/keep/shadow-file.txt" ] \
    && ok "shadow-cleanup: verify-fail left the shadow intact" \
    || fail "shadow-cleanup: verify-fail DELETED the shadow anyway"
fi

# happy path: archive verified + shadow emptied + live mount untouched.
if bash "$SCRIPT_UNDER_TEST" shadow-cleanup >/dev/null 2>&1; then
  SHADOW_LEFT=$(find "$SCRATCH/qlc-at/home/lars/tmp" -type f | wc -l)
  ARCHIVE=$(find "$SCRATCH/pool-backup" -name '*.tar.zst' | head -1)
  [ "$SHADOW_LEFT" -eq 0 ] && ok "shadow-cleanup: shadow emptied" || fail "shadow-cleanup: $SHADOW_LEFT files left in shadow"
  [ -n "$ARCHIVE" ] && ok "shadow-cleanup: archive landed at $ARCHIVE" || fail "shadow-cleanup: no archive"
  [ -f "$SUBVOL_F/work/work-a.txt" ] && ok "shadow-cleanup: live Samsung mount untouched" || fail "shadow-cleanup: live mount damaged"
else
  fail "shadow-cleanup: happy path exited non-zero"
fi

# dry-run plans without mutating.
mkfixture
bash "$SCRIPT_UNDER_TEST" prepare >/dev/null 2>&1
rm -rf "$SRC_F"
ln -s "$SUBVOL_F" "$SRC_F"
printf '/mnt/hot\n/mnt/pool\n%s\n' "$SRC_F" >"$MOUNTPOINT_LIST"
printf '%s %s\n' / /dev/qlc-part "$SRC_F" /dev/samsung-subvol >"$FINDMNT_MAP"
if bash "$SCRIPT_UNDER_TEST" --dry-run shadow-cleanup >/dev/null 2>&1; then
  if compgen -G "$SCRATCH/pool-backup/tmp-shadow-final-*" >/dev/null; then
    fail "shadow-cleanup: dry-run wrote an archive"
  else
    ok "shadow-cleanup: dry-run no mutation"
  fi
else
  fail "shadow-cleanup: dry-run exited non-zero"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "test-migrate-user-tmp-hot: ALL PASS"
  exit 0
else
  echo "test-migrate-user-tmp-hot: $FAILURES FAILURE(S)" >&2
  exit 1
fi
