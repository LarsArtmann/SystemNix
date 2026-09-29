#!/usr/bin/env bash
# migrate-journal-hot — one-time relocation of /var/log/journal from the QLC
# root `@` onto the Samsung TLC (`journal` subvolume, nodatacow, unsnapshotted
# — doctrine C). Companion to platforms/nixos/system/journal-hot.nix.
#
# Order is MANDATORY — prepare BEFORE the deploy carrying the mount:
# deploying the mount first would mount an EMPTY subvol over the live journal
# (split brain: open fds keep writing the QLC shadow, new files land in the
# subvol).
#
#   1. sudo bash scripts/migrate-journal-hot.sh prepare
#      PSI-gates, creates the subvol + chattr +C, quiesces the /var journal
#      (journalctl --relinquish-var → journald logs to /run only), rsyncs,
#      verifies EXACT file count + apparent size (the source is static while
#      quiesced — an exact verify is only possible in this state).
#   2. nix run .#deploy
#      Mounts the subvol AT /var/log/journal; the journald unit change
#      (after/wants wiring) restarts journald onto the mount.
#   3. sudo bash scripts/migrate-journal-hot.sh finalize
#      journalctl --flush (merges the /run window entries into the mount),
#      verifies the ACTIVE journal file lives on the mount.
#   4. Reboot at the next convenient window (nix run .#pre-reboot-check
#      first) — verifies the boot-ordering path. Keep the QLC shadow dir
#      under the mountpoint as rollback insurance until the soak ends.
#
# ABANDONED WINDOW: if you prepare but do NOT deploy, run
# `journalctl --flush` to hand logging back to /var (prepare leaves journald
# in volatile mode; /run entries would be lost at reboot).
#
# DRY RUN: --dry-run prints every action without executing.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

usage() {
  echo "usage: migrate-journal-hot.sh [--dry-run] prepare|finalize" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ACTION=$1

SRC=/var/log/journal
SUBVOL=/mnt/hot/journal

run() {
  echo "+ $*"
  [ "$DRY_RUN" = "1" ] || "$@"
}

[ "$(id -u)" -eq 0 ] || {
  echo "must run as root (sudo)" >&2
  exit 1
}

# Pressure gate (deploy-pressure doctrine): the rsync is a full read of the
# journal on the QLC + a full write on the Samsung — never during an IO storm.
PSI=$(awk 'NR==1 {print $2}' /proc/pressure/io)
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
  if [ -n "$(ls -A "$SUBVOL" 2>/dev/null || true)" ]; then
    echo "$SUBVOL is not empty — refusing to overwrite (rm its contents first if this is a restart of a failed window)" >&2
    exit 1
  fi
  echo "== prepare: subvol + chattr +C, quiesce /var journal, rsync (PSI avg10 ${PSI}%)"
  if ! btrfs subvolume show "$SUBVOL" >/dev/null 2>&1; then
    run btrfs subvolume create "$SUBVOL"
  fi
  # Fresh-subvolume inheritance does NOT carry +C — set explicitly so
  # every journal file created below is nodatacow (doctrine C).
  run chattr +C "$SUBVOL"
  # Quiesce: journald closes /var and logs to /run only → the source tree
  # is static → an EXACT count/size verify is meaningful.
  run journalctl --rotate
  run journalctl --relinquish-var
  sleep 1
  run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --info=stats2 "$SRC"/ "$SUBVOL"/
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: skipping verification"
  else
    SRC_COUNT=$(find "$SRC" -xdev -type f | wc -l)
    DST_COUNT=$(find "$SUBVOL" -type f | wc -l)
    SRC_SIZE=$(du -sb --apparent-size "$SRC" | awk '{print $1}')
    DST_SIZE=$(du -sb --apparent-size "$SUBVOL" | awk '{print $1}')
    echo "files: src=$SRC_COUNT dst=$DST_COUNT  bytes: src=$SRC_SIZE dst=$DST_SIZE"
    if [ "$SRC_COUNT" != "$DST_COUNT" ] || [ "$SRC_SIZE" != "$DST_SIZE" ]; then
      echo "VERIFY FAILED — counts/sizes differ. journald left in VOLATILE mode:" >&2
      echo "  run 'journalctl --flush' to restore /var logging, inspect $SUBVOL" >&2
      exit 1
    fi
  fi
  echo "prepare OK. Now: nix run .#deploy  — then:  sudo $0 finalize"
  echo "WARNING: journald is in VOLATILE mode (/run only) until the deploy — keep the window short."
  ;;
finalize)
  mountpoint -q "$SRC" || {
    echo "$SRC is not a mountpoint — deploy the journal-hot mount first" >&2
    exit 1
  }
  echo "== finalize: flush /run window entries into the mount, verify"
  run journalctl --flush
  sleep 2
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: skipping verification"
    exit 0
  fi
  MID=$(cat /etc/machine-id)
  # sed -n 1p, NOT head -1: head exits after line 1, ls eats SIGPIPE, and
  # pipefail turns that 141 into a silent mid-verify abort (2026-09-29:
  # finalize died here right after a successful flush).
  NEWEST=$(ls -t "$SRC/$MID/" | sed -n '1p')
  TARGET=$(findmnt -T "$SRC/$MID/$NEWEST" -n -o TARGET)
  if [ "$TARGET" != "$SRC" ]; then
    echo "VERIFY FAILED: active journal file ($NEWEST) lives on '$TARGET', not the mount" >&2
    exit 1
  fi
  systemd-cat -t migrate-journal-hot echo "finalize marker $(date +%s)"
  sleep 2
  # No grep -q: it exits on first match, journalctl eats SIGPIPE, pipefail
  # then reports a spurious VERIFY FAILED on a successful roundtrip.
  journalctl -t migrate-journal-hot -b --no-pager | grep "finalize marker" >/dev/null || {
    echo "VERIFY FAILED: marker roundtrip through the mounted journal failed" >&2
    exit 1
  }
  echo "finalize OK: journal live on the Samsung ($NEWEST on the mount)."
  echo "Next: reboot in a quiet window after 'nix run .#pre-reboot-check' to verify the boot path."
  ;;
*)
  usage
  ;;
esac
