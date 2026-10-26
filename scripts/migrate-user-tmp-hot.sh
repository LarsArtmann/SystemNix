#!/usr/bin/env bash
# migrate-user-tmp-hot — one-time relocation of /home/lars/tmp from the QLC
# root `@` onto the Samsung TLC (`users/lars/tmp` subvolume, unsnapshotted).
# Companion to modules/nixos/services/hot-user-caches.nix (the E6 fix,
# 2026-10-26: tmp sat inside snapshotted @, so agent/cache churn double-billed
# the QLC root through the 3d snapshot pin window).
#
# Order is MANDATORY — prepare BEFORE the deploy carrying the mount:
# deploying the mount first would mount an EMPTY subvol over the live dir
# (shadow-split: open fds keep writing the QLC shadow under the mount).
#
#   1. sudo bash scripts/migrate-user-tmp-hot.sh prepare
#      PSI-gates (entry gate refuses while e.g. a btrfs balance storms the
#      box), creates the subvol, double-pass rsyncs (NO service to stop —
#      agent sessions write here; the second pass converges their deltas),
#      verifies EXACT file count + apparent size.
#   2. nix run .#deploy
#      hot-user-caches mounts the subvol AT /home/lars/tmp (automount).
#   3. sudo bash scripts/migrate-user-tmp-hot.sh finalize
#      Verifies the mount answers + lars can write onto it.
#
# GAP WINDOW: files created between prepare's final rsync and the deploy land
# on the QLC shadow dir and are hidden (not lost) when the mount shadows it —
# they survive in the shadow as rollback insurance. Keep the window short.
#
#   4. sudo bash scripts/migrate-user-tmp-hot.sh shadow-cleanup
#      At soak end (or owner override): archives the QLC shadow dir to
#      /mnt/pool/backups/home-lars-tmp, verifies the archive (exact file
#      count), then deletes the shadow CONTENTS through an auxiliary
#      subvol=@ mount — the live Samsung mount is never touched and the
#      mountpoint dir itself is kept. REFUSES if /home/lars/tmp is not on a
#      different device than the QLC root (detached Samsung = the shadow dir
#      IS the live tmp; deleting it would destroy live work).
#
# NOTE: deliberately NO chattr +C — this is the hot-user-caches family
# (CoW + compress=zstd, like users/lars/cache/nix), not the doctrine-C
# nodatacow log family.
#
# DRY RUN: --dry-run prints every action without executing.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

usage() {
  echo "usage: migrate-user-tmp-hot.sh [--dry-run] prepare|finalize|shadow-cleanup" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ACTION=$1

# Fixture hooks (scripts/test-migrate-user-tmp-hot.sh overrides these — same
# pattern as migrate-caddy-logs-hot.sh; production uses the defaults).
SRC=${TMP_MIGRATE_SRC:-/home/lars/tmp}
SUBVOL=${TMP_MIGRATE_SUBVOL:-/mnt/hot/users/lars/tmp}
USER=${TMP_MIGRATE_USER:-lars}

run() {
  echo "+ $*"
  [ "$DRY_RUN" = "1" ] || "$@"
}

if [ "$DRY_RUN" != "1" ]; then
  [ "$(id -u)" -eq "${TMP_MIGRATE_ROOT_UID:-0}" ] || {
    echo "must run as root (sudo)" >&2
    exit 1
  }
fi

# ── Entry gate (freeze #19/#20/#21 class — see pkgs/maintenance-entry-gate.nix)
# One migrate-* at a time (flock held for this script's lifetime) + refuse to
# start into a tripped box (30% band + guard-trip recency). This is also what
# keeps this script OUT of a running btrfs balance window. Dry-run stays
# ungated (read-only).
if [ "$DRY_RUN" != "1" ]; then
  MAINT_LOCK_DIR="${MAINT_ENTRY_GATE_LOCK_DIR:-/run/lock/systemnix-heavy}"
  mkdir -p "$MAINT_LOCK_DIR" 2>/dev/null || true
  exec 8>>"$MAINT_LOCK_DIR/systemnix-maintenance.lock" || {
    echo "ERROR: cannot open maintenance lock in $MAINT_LOCK_DIR" >&2
    exit 1
  }
  flock -n 8 || {
    echo "ERROR: another migrate-* script holds $MAINT_LOCK_DIR/systemnix-maintenance.lock — serialize maintenance, never stack it" >&2
    exit 1
  }
  maintenance-entry-gate --name migrate-user-tmp-hot --psi-max 30 || {
    echo "ERROR: entry gate refused (see above) — a refused migration is free, a migration into a storm is freeze #19. (A running btrfs balance trips this gate.)" >&2
    exit 1
  }
fi

# Pressure gate (deploy-pressure doctrine).
# Read-only gate: survives PSI-disabled kernels (missing /proc/pressure/io).
PSI=$(awk 'NR==1 {print $2}' "${TMP_MIGRATE_PSI_FILE:-/proc/pressure/io}" 2>/dev/null || true)
PSI="${PSI#avg10=}"
PSI="${PSI:-0}"
if awk -v p="$PSI" 'BEGIN { exit !(p >= 80) }'; then
  echo "REFUSED: IO PSI some avg10 = ${PSI}% (>= 80%). Wait for a quiet window." >&2
  exit 1
fi

if ! mountpoint -q /mnt/hot; then
  echo "/mnt/hot is not a mountpoint — detached Samsung. Refusing." >&2
  exit 1
fi

case "$ACTION" in
prepare)
  if mountpoint -q "$SRC"; then
    echo "$SRC is already a mountpoint — already migrated?" >&2
    exit 1
  fi
  if [ -e "$SUBVOL" ] && [ -n "$(ls -A "$SUBVOL" 2>/dev/null || true)" ]; then
    echo "$SUBVOL is not empty — refusing to overwrite (rm its contents first if this is a restart of a failed window)" >&2
    exit 1
  fi
  echo "== prepare: subvol, double-pass rsync (PSI avg10 ${PSI}%)"
  echo "-- top consumers of $SRC (decide BEFORE migrating: work products"
  echo "   (wevisone-spike class) lose ALL backup on the unsnapshotted subvol;"
  echo "   move anything precious to ~/projects first):"
  timeout 120 ionice -c3 nice -n19 du -h -d1 "$SRC" 2>/dev/null | sort -rh | head -6 || true
  if ! btrfs subvolume show "$SUBVOL" >/dev/null 2>&1; then
    run btrfs subvolume create "$SUBVOL"
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: rsync skipped"
  else
    # No service to quiesce — agent sessions write here. Two passes: the
    # second converges deltas written during the first; the verify below
    # then compares an (approximately) settled source. A still-churning
    # source fails the retry and says so honestly.
    verify_pass() {
      run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --info=stats2 "$SRC"/ "$SUBVOL"/
      SRC_COUNT=$(find "$SRC" -xdev -type f | wc -l)
      DST_COUNT=$(find "$SUBVOL" -type f | wc -l)
      SRC_SIZE=$(du -sb --apparent-size "$SRC" | awk '{print $1}')
      DST_SIZE=$(du -sb --apparent-size "$SUBVOL" | awk '{print $1}')
      echo "files: src=$SRC_COUNT dst=$DST_COUNT  bytes: src=$SRC_SIZE dst=$DST_SIZE"
      [ "$SRC_COUNT" = "$DST_COUNT" ] && [ "$SRC_SIZE" = "$DST_SIZE" ]
    }
    if ! verify_pass; then
      echo "first pass differs (live writers?) — converging with a second pass"
      if ! verify_pass; then
        echo "VERIFY FAILED twice — source is churning under active sessions." >&2
        echo "Re-run prepare when ~/tmp-writing sessions are idle." >&2
        exit 1
      fi
    fi
    chown "$USER":users "$SUBVOL" || true
  fi
  echo "prepare OK. Now: nix run .#deploy  — then:  sudo $0 finalize"
  echo "WARNING: files written from here until the deploy land on the QLC shadow dir."
  ;;
finalize)
  mountpoint -q "$SRC" || {
    echo "$SRC is not a mountpoint — deploy the hot-user-caches tmp mount first" >&2
    exit 1
  }
  echo "== finalize: verify the mount answers + $USER can write onto it"
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: skipping verification"
    exit 0
  fi
  EXISTING=$(find "$SUBVOL" -type f | wc -l)
  if [ "$EXISTING" -eq 0 ]; then
    echo "VERIFY FAILED: no files on the mount at all — rsynced content missing." >&2
    exit 1
  fi
  PROBE="$SRC/.migrate-finalize-probe"
  runuser -u "$USER" -- touch "$PROBE" || {
    echo "VERIFY FAILED: $USER cannot write onto the mount (ownership?)" >&2
    exit 1
  }
  [ -f "$SUBVOL/.migrate-finalize-probe" ] || {
    echo "VERIFY FAILED: probe written at $SRC is not on $SUBVOL — mount mismatch." >&2
    exit 1
  }
  rm -f "$PROBE"
  echo "finalize OK: ~/tmp lives on the Samsung ($EXISTING files)."
  echo "Keep the QLC shadow dir under the mountpoint as rollback insurance until the soak ends."
  ;;
shadow-cleanup)
  # The root partition is derived from the RUNNING root at runtime — kernel
  # nvmeX names flip across boots on this box (by-id trap), but findmnt is
  # always self-consistent within one boot.
  ROOT_PART=$(findmnt -no SOURCE /)
  ROOT_PART=${ROOT_PART%%\[*}
  LIVE_SRC=$(findmnt -no SOURCE "$SRC" || true)
  LIVE_BASE=${LIVE_SRC%%\[*}

  mountpoint -q "$SRC" || {
    echo "$SRC is not a mountpoint — nothing to clean up (or the mount regressed)." >&2
    exit 1
  }
  if [ "$LIVE_BASE" = "$ROOT_PART" ]; then
    echo "REFUSED: $SRC is on the QLC root device ($LIVE_BASE) — the Samsung is" >&2
    echo "detached and the shadow dir IS the live tmp. Deleting it would" >&2
    echo "destroy live work. Re-attach the Samsung first." >&2
    exit 1
  fi
  mountpoint -q /mnt/pool || {
    echo "/mnt/pool is not a mountpoint — archive target missing. Refusing." >&2
    exit 1
  }

  AUX=${TMP_MIGRATE_AUX:-/run/user-tmp-shadow-view}
  AUX_SHADOW=$AUX/home/lars/tmp
  ARCHIVE_DIR=${TMP_MIGRATE_ARCHIVE_DIR:-/mnt/pool/backups/home-lars-tmp}
  ARCHIVE=$ARCHIVE_DIR/tmp-shadow-final-$(date +%Y-%m-%d).tar.zst

  if [ "$DRY_RUN" = "1" ]; then
    echo "plan: aux-mount $ROOT_PART (subvol=@, ro) at $AUX"
    echo "plan: tar --zstd $AUX_SHADOW -> $ARCHIVE (verify exact file count)"
    echo "plan: remount rw, delete CONTENTS of $AUX_SHADOW (mountpoint dir kept)"
    echo "plan: live mount at $SRC ($LIVE_SRC) is never touched"
    exit 0
  fi

  cleanup_aux() {
    umount "$AUX" 2>/dev/null || true
    rmdir "$AUX" 2>/dev/null || true
  }
  trap cleanup_aux INT TERM EXIT

  mkdir -p "$AUX" "$ARCHIVE_DIR"
  run mount -o subvol=@,ro "$ROOT_PART" "$AUX"
  # The shadow must be a PLAIN dir in this view — a mountpoint here would mean
  # the wrong universe got mounted (would delete through to something live).
  if mountpoint -q "$AUX_SHADOW"; then
    echo "REFUSED: $AUX_SHADOW is a mountpoint in the aux view — wrong view." >&2
    exit 1
  fi
  [ -d "$AUX_SHADOW" ] || {
    echo "shadow dir not found at $AUX_SHADOW — nothing to archive." >&2
    exit 1
  }

  FILES=$(find "$AUX_SHADOW" -type f | wc -l)
  SIZE=$(du -sb --apparent-size "$AUX_SHADOW" | awk '{print $1}')
  echo "shadow: files=$FILES bytes=$SIZE"
  if [ "$FILES" -eq 0 ]; then
    echo "shadow is already empty — nothing to do." >&2
    exit 0
  fi

  run tar -C "$AUX/home/lars" --zstd -cf "$ARCHIVE" tmp
  TFILES=$(tar --zstd -tf "$ARCHIVE" | grep -vc '/$')
  if [ "$TFILES" != "$FILES" ]; then
    echo "ARCHIVE VERIFY FAILED: tar=$TFILES files vs src=$FILES — shadow NOT deleted." >&2
    exit 1
  fi
  echo "archive verified: $TFILES files -> $ARCHIVE ($(stat -c%s "$ARCHIVE") bytes)"

  run umount "$AUX"
  run mount -o subvol=@ "$ROOT_PART" "$AUX"
  run find "$AUX_SHADOW" -mindepth 1 -delete
  run umount "$AUX"
  trap - EXIT
  cleanup_aux
  echo "shadow-cleanup OK: insurance archived to the pool + QLC shadow emptied."
  echo "QLC freed ~$SIZE bytes (visible space settles as @ snapshots holding them expire)."
  ;;
*)
  usage
  ;;
esac
