#!/usr/bin/env bash
# test-migrate-caddy-logs-hot — fixture test for
# scripts/migrate-caddy-logs-hot.sh (the storage.md fixture row: an untested
# destructive script is the worst first contact — this closes it AFTER the
# 2026-10-01→10-04 live window, which exercised no failure branch).
#
# Strategy (test-migrate-hot-db.sh pattern): PATH-injected stubs for
# everything root-bound or system-touching (mountpoint, btrfs, chattr,
# systemctl, ionice, nice, findmnt, mount, umount, sleep) + REAL
# rsync/find/du/tar against /tmp fixtures, via the script's CADDY_MIGRATE_*
# env hooks. mount/umount stubs fake the aux subvol=@ view with a symlink.
#
# Covers: prepare happy path (subvol, chattr +C, quiesce order, exact copy),
# verify-fail branch (caddy restarted + exit 1), EXIT-trap restart on
# mid-rsync death, real SIGINT mid-rsync (the INT TERM trap), PSI /
# already-mounted / non-empty-subvol refusals, dry-run no-mutation, the
# hardened finalize branches (not-mounted / no-files / quiet-window / happy),
# and every shadow-cleanup guard (not-mounted, detached-Samsung same-device,
# pool-missing, archive-verify-fail leaves the shadow intact, happy path,
# dry-run).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT_UNDER_TEST=$HERE/migrate-caddy-logs-hot.sh

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
REAL_SLEEP=$(command -v sleep)

export CADDY_MIGRATE_SRC="$SCRATCH/var/log/caddy"
export CADDY_MIGRATE_SUBVOL="$SCRATCH/hot/caddy-logs"
export CADDY_MIGRATE_AUX="$SCRATCH/aux"
export CADDY_MIGRATE_ARCHIVE_DIR="$SCRATCH/pool-backup"
export CADDY_MIGRATE_PSI_FILE="$SCRATCH/psi-ok"
CADDY_MIGRATE_ROOT_UID=$(id -u)
export CADDY_MIGRATE_ROOT_UID
export FAKE_SUBVOLS="$SCRATCH/subvols.list"
export SYSTEMCTL_LOG="$SCRATCH/systemctl.log"
export MOUNTPOINT_LIST="$SCRATCH/mountpoints.list"
export CHATTR_LOG="$SCRATCH/chattr.log"
export MOUNT_LOG="$SCRATCH/mount.log"
export FINDMNT_MAP="$SCRATCH/findmnt.map"
export FIXTURE_QLC_AT="$SCRATCH/qlc-at"

cat >"$BIN/mountpoint" <<'EOF'
#!/usr/bin/env bash
# fixture stub: YES iff the path is listed in $MOUNTPOINT_LIST
grep -qxF "$2" "$MOUNTPOINT_LIST" 2>/dev/null && exit 0 || exit 1
EOF
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
# fixture stub: log and succeed (+C is inode state the sandbox cannot set)
echo "$*" >>"$CHATTR_LOG"
exit 0
EOF
cat >"$BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
# fixture stub: log and succeed
echo "$*" >>"$SYSTEMCTL_LOG"
exit 0
EOF
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
# findmnt stub: `findmnt -no SOURCE <path>` answers from $FINDMNT_MAP
cat >"$BIN/findmnt" <<'EOF'
#!/usr/bin/env bash
# fixture stub
if [ "$2" = "SOURCE" ]; then
  awk -v p="$3" '$1 == p {print $2; found=1} END {exit !found}' "$FINDMNT_MAP"
else
  exit 1
fi
EOF
# mount stub: the aux subvol=@ "mount" becomes a symlink to the fixture @
# tree — find/tar/delete then operate on the real fixture files through it.
cat >"$BIN/mount" <<'EOF'
#!/usr/bin/env bash
# fixture stub
echo "mount $*" >>"$MOUNT_LOG"
last="${@: -1}"
rmdir "$last" 2>/dev/null || true
ln -sfn "$FIXTURE_QLC_AT" "$last"
EOF
cat >"$BIN/umount" <<'EOF'
#!/usr/bin/env bash
# fixture stub
echo "umount $*" >>"$MOUNT_LOG"
rm -f "${@: -1}"
EOF
# sleep stub: finalize's 35s window — FIXTURE_SLEEP_TOUCH simulates caddy's
# write during the window (set = live traffic, empty = quiet window).
cat >"$BIN/sleep" <<'EOF'
#!/usr/bin/env bash
# fixture stub
[ -n "${FIXTURE_SLEEP_TOUCH:-}" ] && touch "$FIXTURE_SLEEP_TOUCH"
exit 0
EOF
# rsync wrapper: RSYNC_MODE dispatches real / no-op / die / slow (signal test)
cat >"$BIN/rsync" <<EOF
#!/usr/bin/env bash
# fixture stub
case "\${RSYNC_MODE:-real}" in
  real) exec "$REAL_RSYNC" "\$@" ;;
  none) exit 0 ;;
  die) exit 5 ;;
  slow) "$REAL_SLEEP" 2; exit 5 ;;
esac
EOF
# tar wrapper: TAR_MODE=truncated archives one file → count-mismatch verify
cat >"$BIN/tar" <<EOF
#!/usr/bin/env bash
# fixture stub
if [ "\${TAR_MODE:-}" = "truncated" ]; then
  exec "$REAL_TAR" -C "\$2" --zstd -cf "\$5" caddy/access-a.log
fi
exec "$REAL_TAR" "\$@"
EOF

# SANDBOX SHEBANG TRAP (forgejo-fixture lesson): /usr/bin/env may not resolve
# inside the nix build sandbox — rewrite every stub's interpreter to the bash
# running this test.
for stub in "$BIN"/*; do
  sed -i "1c #!$BASH" "$stub"
done
chmod +x "$BIN"/*
export PATH="$BIN:$PATH"

printf 'some avg10=1.0 avg60=1.0 avg300=1.0 total=0\n' >"$SCRATCH/psi-ok"
printf 'some avg10=99.0 avg60=80.0 avg300=60.0 total=999999\n' >"$SCRATCH/psi-bad"
SRC_F=$CADDY_MIGRATE_SRC
SUBVOL_F=$CADDY_MIGRATE_SUBVOL

mkshadow() {
  rm -rf "${SCRATCH:?}/var" "$SUBVOL_F" "$CADDY_MIGRATE_AUX" "$CADDY_MIGRATE_ARCHIVE_DIR"
  : >"$FAKE_SUBVOLS"
  : >"$SYSTEMCTL_LOG"
  : >"$CHATTR_LOG"
  : >"$MOUNT_LOG"
  mkdir -p "$SRC_F/nested" "$CADDY_MIGRATE_ARCHIVE_DIR"
  echo log-a >"$SRC_F/access-a.log"
  echo log-b >"$SRC_F/access-b.log"
  echo log-c >"$SRC_F/nested/old.log"
}

# tier + pool gates pass by default (stub answers from the list)
: >"$MOUNTPOINT_LIST"
echo /mnt/hot >>"$MOUNTPOINT_LIST"
echo /mnt/pool >>"$MOUNTPOINT_LIST"

run_migrate() {
  bash "$SCRIPT_UNDER_TEST" "$@"
}

# ── 1. prepare happy path ───────────────────────────────────────────────────
mkshadow
out=$(run_migrate prepare 2>&1) || {
  fail "prepare exited non-zero: $out"
  exit 1
}
grep -qxF "$SUBVOL_F" "$FAKE_SUBVOLS" && ok "prepare created the subvol" || fail "prepare did not create subvol"
grep -q "+C $SUBVOL_F" "$CHATTR_LOG" && ok "prepare chattr +C the subvol" || fail "prepare did not chattr +C: $(cat "$CHATTR_LOG")"
diff -r "$SRC_F" "$SUBVOL_F" >/dev/null && ok "prepare copied the tree exactly" || fail "prepare copy differs"
stop_line=$(grep -n "stop caddy" "$SYSTEMCTL_LOG" | cut -d: -f1 | head -1)
start_line=$(grep -n "start caddy" "$SYSTEMCTL_LOG" | cut -d: -f1 | head -1)
[ -n "$stop_line" ] && [ -n "$start_line" ] && [ "$stop_line" -lt "$start_line" ] &&
  ok "prepare quiesced (stop) before restart (start)" || fail "prepare systemctl order wrong: $(cat "$SYSTEMCTL_LOG")"

# ── 2. prepare refusal: IO PSI storm ────────────────────────────────────────
mkshadow
out=$(CADDY_MIGRATE_PSI_FILE="$SCRATCH/psi-bad" run_migrate prepare 2>&1) && fail "prepare ran during IO storm" || {
  grep -q "REFUSED: IO PSI" <<<"$out" && ok "prepare refuses on IO PSI" || fail "prepare failed for wrong reason: $out"
}

# ── 3. prepare refusal: already migrated ────────────────────────────────────
mkshadow
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
out=$(run_migrate prepare 2>&1) && fail "prepare ran on an already-mounted src" || {
  grep -q "already a mountpoint" <<<"$out" && ok "prepare refuses already-migrated" || fail "prepare failed for wrong reason: $out"
}
grep -vxF "$SRC_F" "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"

# ── 4. prepare refusal: non-empty subvol ────────────────────────────────────
mkshadow
mkdir -p "$SUBVOL_F"
echo stale >"$SUBVOL_F/stale.log"
out=$(run_migrate prepare 2>&1) && fail "prepare ran onto a non-empty subvol" || {
  grep -q "not empty" <<<"$out" && ok "prepare refuses non-empty subvol" || fail "prepare failed for wrong reason: $out"
}

# ── 5. prepare verify-fail: rsync copied nothing → caddy RESTARTED + exit 1 ─
mkshadow
: >"$SYSTEMCTL_LOG"
out=$(RSYNC_MODE=none run_migrate prepare 2>&1) && fail "prepare passed with a failed copy" || {
  grep -q "VERIFY FAILED" <<<"$out" && ok "prepare fails on count/size mismatch" || fail "prepare failed for wrong reason: $out"
}
grep -q "start caddy" "$SYSTEMCTL_LOG" && ok "verify-fail branch restarted caddy" || fail "verify-fail left caddy stopped"

# ── 6. prepare mid-rsync death: EXIT trap restarts caddy ────────────────────
mkshadow
: >"$SYSTEMCTL_LOG"
out=$(RSYNC_MODE=die run_migrate prepare 2>&1) && fail "prepare survived rsync death" || true
grep -q "start caddy" "$SYSTEMCTL_LOG" && ok "EXIT trap restarted caddy after mid-rsync death" || fail "EXIT trap did not restart caddy"

# ── 7. real SIGINT mid-rsync: INT TERM trap covers the interrupt path ───────
mkshadow
: >"$SYSTEMCTL_LOG"
RSYNC_MODE=slow run_migrate prepare >/dev/null 2>&1 &
mig_pid=$!
"$REAL_SLEEP" 1
kill -INT "$mig_pid"
wait "$mig_pid" 2>/dev/null || true
grep -q "start caddy" "$SYSTEMCTL_LOG" && ok "INT trap restarted caddy after Ctrl-C mid-rsync" || fail "INT trap did not restart caddy"

# ── 8. dry-run prepare: no mutation ─────────────────────────────────────────
mkshadow
run_migrate --dry-run prepare >/dev/null 2>&1 || fail "dry-run prepare exited non-zero"
[ ! -s "$FAKE_SUBVOLS" ] && ok "dry-run created no subvol" || fail "dry-run created a subvol"
[ ! -e "$SUBVOL_F" ] && ok "dry-run copied nothing" || fail "dry-run mutated the subvol path"
[ ! -s "$SYSTEMCTL_LOG" ] && ok "dry-run touched no units" || fail "dry-run ran systemctl"
[ ! -s "$CHATTR_LOG" ] && ok "dry-run ran no chattr" || fail "dry-run ran chattr"

# ── 9. finalize refusal: not a mountpoint ───────────────────────────────────
mkshadow
out=$(run_migrate finalize 2>&1) && fail "finalize ran before the deploy" || {
  grep -q "not a mountpoint" <<<"$out" && ok "finalize refuses pre-deploy" || fail "finalize failed for wrong reason: $out"
}

# ── 10. finalize refusal: no files on the mount at all ──────────────────────
mkshadow
mkdir -p "$SUBVOL_F"
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
out=$(run_migrate finalize 2>&1) && fail "finalize passed with an empty subvol" || {
  grep -q "no log files" <<<"$out" && ok "finalize fails on empty mount" || fail "finalize failed for wrong reason: $out"
}

# ── 11. finalize refusal: quiet window (no write during the 35s) ────────────
mkshadow
grep -vxF "$SRC_F" "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"
run_migrate prepare >/dev/null 2>&1
: >"$SYSTEMCTL_LOG"
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
out=$(FIXTURE_SLEEP_TOUCH='' run_migrate finalize 2>&1) && fail "finalize passed a quiet window" || {
  grep -q "during the 35s window" <<<"$out" && ok "finalize fails on quiet window (new -newermt gate)" || fail "finalize failed for wrong reason: $out"
}

# ── 12. finalize happy: write during the window ─────────────────────────────
out=$(FIXTURE_SLEEP_TOUCH="$SUBVOL_F/access-a.log" run_migrate finalize 2>&1) || {
  fail "finalize exited non-zero: $out"
  exit 1
}
grep -q "finalize OK" <<<"$out" && ok "finalize passes with live writes" || fail "finalize happy path missing OK: $out"
grep -vxF "$SRC_F" "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"

# ── 13. shadow-cleanup refusal: not a mountpoint ────────────────────────────
mkshadow
out=$(run_migrate shadow-cleanup 2>&1) && fail "shadow-cleanup ran pre-deploy" || {
  grep -q "not a mountpoint" <<<"$out" && ok "shadow-cleanup refuses pre-deploy" || fail "shadow-cleanup failed for wrong reason: $out"
}

# ── 14. shadow-cleanup refusal: detached Samsung (same-device guard) ────────
mkshadow
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
printf '%s %s\n' "/" "/dev/fixture-rootp6[/@]" >"$FINDMNT_MAP"
printf '%s %s\n' "$SRC_F" "/dev/fixture-rootp6[/caddy-logs]" >>"$FINDMNT_MAP"
out=$(run_migrate shadow-cleanup 2>&1) && fail "shadow-cleanup ran with caddy on the QLC root" || {
  grep -q "REFUSED" <<<"$out" && ok "shadow-cleanup refuses same-device (detached Samsung)" || fail "shadow-cleanup failed for wrong reason: $out"
}

# ── 15. shadow-cleanup refusal: pool archive target missing ─────────────────
printf '%s %s\n' "$SRC_F" "/dev/fixture-samsungp2[/caddy-logs]" >>"$FINDMNT_MAP"
grep -vxF /mnt/pool "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"
out=$(run_migrate shadow-cleanup 2>&1) && fail "shadow-cleanup ran without the pool" || {
  grep -q "archive target missing" <<<"$out" && ok "shadow-cleanup refuses missing pool" || fail "shadow-cleanup failed for wrong reason: $out"
}
echo /mnt/pool >>"$MOUNTPOINT_LIST"

# ── 16. shadow-cleanup: archive verify-fail leaves the shadow intact ────────
QLC_SHADOW=$FIXTURE_QLC_AT/var/log/caddy
rm -rf "$FIXTURE_QLC_AT"
mkdir -p "$QLC_SHADOW/nested"
echo gap-a >"$QLC_SHADOW/access-a.log"
echo gap-b >"$QLC_SHADOW/access-b.log"
echo gap-c >"$QLC_SHADOW/nested/old.log"
out=$(TAR_MODE=truncated run_migrate shadow-cleanup 2>&1) && fail "shadow-cleanup passed a bad archive" || {
  grep -q "ARCHIVE VERIFY FAILED" <<<"$out" && ok "shadow-cleanup fails on archive count mismatch" || fail "shadow-cleanup failed for wrong reason: $out"
}
[ "$(find "$QLC_SHADOW" -type f | wc -l)" -eq 3 ] && ok "failed verify left the shadow intact" || fail "failed verify deleted shadow files"
[ ! -e "$CADDY_MIGRATE_AUX" ] && ok "failed verify unmounted the aux view (crash-safe trap)" || fail "aux view leaked after failure"

# ── 17. shadow-cleanup happy path ───────────────────────────────────────────
out=$(run_migrate shadow-cleanup 2>&1) || {
  fail "shadow-cleanup exited non-zero: $out"
  exit 1
}
archive=$(find "$CADDY_MIGRATE_ARCHIVE_DIR" -name '*.tar.zst' | head -1)
[ -n "$archive" ] && ok "archive written to the pool fixture" || fail "no archive written"
tfiles=$("$REAL_TAR" --zstd -tf "$archive" | grep -vc '/$')
[ "$tfiles" -eq 3 ] && ok "archive carries all 3 shadow files" || fail "archive file count wrong: $tfiles"
[ -d "$QLC_SHADOW" ] && [ -z "$(ls -A "$QLC_SHADOW")" ] &&
  ok "shadow emptied but mountpoint dir kept" || fail "shadow dir state wrong after cleanup"
[ ! -e "$CADDY_MIGRATE_AUX" ] && ok "aux view unmounted" || fail "aux view leaked"
grep -vxF "$SRC_F" "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"

# ── 18. dry-run shadow-cleanup: no mutation ─────────────────────────────────
rm -rf "$FIXTURE_QLC_AT"
mkdir -p "$QLC_SHADOW"
echo still-here >"$QLC_SHADOW/access-a.log"
echo "$SRC_F" >>"$MOUNTPOINT_LIST"
run_migrate --dry-run shadow-cleanup >/dev/null 2>&1 || fail "dry-run shadow-cleanup exited non-zero"
[ ! -e "$CADDY_MIGRATE_AUX" ] && ok "dry-run mounted no aux view" || fail "dry-run created aux view"
[ "$(find "$CADDY_MIGRATE_ARCHIVE_DIR" -name '*.tar.zst' | wc -l)" -eq 1 ] &&
  ok "dry-run wrote no new archive" || fail "dry-run wrote an archive"
[ -f "$QLC_SHADOW/access-a.log" ] && ok "dry-run deleted nothing" || fail "dry-run deleted shadow files"
grep -vxF "$SRC_F" "$MOUNTPOINT_LIST" >"$MOUNTPOINT_LIST.tmp" || true
mv "$MOUNTPOINT_LIST.tmp" "$MOUNTPOINT_LIST"

# ── 19. usage: unknown action ───────────────────────────────────────────────
out=$(run_migrate bogus 2>&1) && fail "unknown action exited zero" || {
  grep -q "usage:" <<<"$out" && ok "unknown action prints usage + exits non-zero" || fail "unknown action failed oddly: $out"
}

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "ALL migrate-caddy-logs-hot fixture tests passed"
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED"
  exit 1
fi
