#!/usr/bin/env bash
# migrate-caddy-logs-hot — one-time relocation of /var/log/caddy from the QLC
# root `@` onto the Samsung TLC (`caddy-logs` subvolume, nodatacow,
# unsnapshotted — doctrine C). Companion to
# platforms/nixos/system/caddy-logs-hot.nix.
#
# Order is MANDATORY — prepare BEFORE the deploy carrying the mount:
# deploying the mount first would mount an EMPTY subvol over the live logs
# (shadow-split: caddy keeps writing the QLC shadow dir through its open fd).
#
#   1. sudo bash scripts/migrate-caddy-logs-hot.sh prepare
#      PSI-gates, creates the subvol + chattr +C, briefly STOPS caddy (the
#      quiesce equivalent of journalctl --relinquish-var), rsyncs, verifies
#      EXACT file count + apparent size, restarts caddy.
#   2. nix run .#deploy
#      Mounts the subvol AT /var/log/caddy.
#   3. sudo bash scripts/migrate-caddy-logs-hot.sh finalize
#      Verifies caddy is writing onto the mount.
#
# LOG-GAP WINDOW: entries written between prepare's caddy restart and the
# deploy land on the QLC shadow dir and are hidden (not lost) when the mount
# shadows it — they survive in the shadow as rollback insurance. Keep the
# prepare→deploy window short.
#
#   4. sudo bash scripts/migrate-caddy-logs-hot.sh shadow-cleanup
#      At soak end (or owner override): archives the QLC shadow dir (the
#      log-gap insurance) to /mnt/pool/backups/caddy, verifies the archive
#      (exact file count), then deletes the shadow CONTENTS through an
#      auxiliary subvol=@ mount — the live Samsung mount is never touched
#      and the mountpoint dir itself is kept. REFUSES if /var/log/caddy is
#      not on a different device than the QLC root (detached Samsung =
#      the shadow dir IS the live log store; deleting it would destroy
#      live logs).
#
# DRY RUN: --dry-run prints every action without executing.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

usage() {
  echo "usage: migrate-caddy-logs-hot.sh [--dry-run] prepare|finalize|shadow-cleanup" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ACTION=$1

SRC=/var/log/caddy
SUBVOL=/mnt/hot/caddy-logs

run() {
  echo "+ $*"
  [ "$DRY_RUN" = "1" ] || "$@"
}

if [ "$DRY_RUN" != "1" ]; then
  [ "$(id -u)" -eq 0 ] || {
    echo "must run as root (sudo)" >&2
    exit 1
  }
fi

# Pressure gate (deploy-pressure doctrine).
# Read-only gate: survives PSI-disabled kernels (missing /proc/pressure/io).
PSI=$(awk 'NR==1 {print $2}' /proc/pressure/io 2>/dev/null || true)
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
  echo "== prepare: subvol + chattr +C, stop caddy, rsync (PSI avg10 ${PSI}%)"
  if ! btrfs subvolume show "$SUBVOL" >/dev/null 2>&1; then
    run btrfs subvolume create "$SUBVOL"
  fi
  # Fresh-subvolume inheritance does NOT carry +C — set explicitly so
  # every log file created below is nodatacow (doctrine C).
  run chattr +C "$SUBVOL"
  # Quiesce: caddy closes the access-log fds → the source tree is static →
  # an EXACT count/size verify is meaningful. Brief vhost outage by design.
  # Crash-safe quiesce: if ANYTHING dies (set -e) while caddy is stopped,
  # restart it on the way out — never leave the vhosts down.
  trap '[ "$DRY_RUN" = "1" ] || systemctl start caddy || true' EXIT
  run systemctl stop caddy
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: rsync skipped"
  else
    run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --info=stats2 "$SRC"/ "$SUBVOL"/
    SRC_COUNT=$(find "$SRC" -xdev -type f | wc -l)
    DST_COUNT=$(find "$SUBVOL" -type f | wc -l)
    SRC_SIZE=$(du -sb --apparent-size "$SRC" | awk '{print $1}')
    DST_SIZE=$(du -sb --apparent-size "$SUBVOL" | awk '{print $1}')
    echo "files: src=$SRC_COUNT dst=$DST_COUNT  bytes: src=$SRC_SIZE dst=$DST_SIZE"
    if [ "$SRC_COUNT" != "$DST_COUNT" ] || [ "$SRC_SIZE" != "$DST_SIZE" ]; then
      echo "VERIFY FAILED — counts/sizes differ." >&2
      systemctl start caddy || true
      exit 1
    fi
  fi
  run systemctl start caddy
  trap - EXIT
  echo "prepare OK. Now: nix run .#deploy  — then:  sudo $0 finalize"
  echo "WARNING: log entries written from here until the deploy land on the QLC shadow dir."
  ;;
finalize)
  mountpoint -q "$SRC" || {
    echo "$SRC is not a mountpoint — deploy the caddy-logs-hot mount first" >&2
    exit 1
  }
  echo "== finalize: verify caddy writes onto the mount"
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: skipping verification"
    exit 0
  fi
  BEFORE=$(find "$SUBVOL" -type f -mmin -2 | wc -l)
  sleep 35
  AFTER=$(find "$SUBVOL" -type f -mmin -2 | wc -l)
  echo "recently-touched files: before=$BEFORE after=$AFTER"
  if [ "$AFTER" -eq 0 ]; then
    echo "VERIFY FAILED: no log file touched on the mount in 35s — is caddy running?" >&2
    exit 1
  fi
  echo "finalize OK: caddy logs live on the Samsung."
  echo "Next: reboot in a quiet window after 'nix run .#pre-reboot-check' to verify the boot path."
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
    echo "detached and the shadow dir IS the live log store. Deleting it would" >&2
    echo "destroy live logs. Re-attach the Samsung first." >&2
    exit 1
  fi
  mountpoint -q /mnt/pool || {
    echo "/mnt/pool is not a mountpoint — archive target missing. Refusing." >&2
    exit 1
  }

  AUX=/run/caddy-shadow-view
  AUX_SHADOW=$AUX/var/log/caddy
  ARCHIVE_DIR=/mnt/pool/backups/caddy
  ARCHIVE=$ARCHIVE_DIR/caddy-logs-shadow-final-$(date +%Y-%m-%d).tar.zst

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
  trap cleanup_aux EXIT

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

  run tar -C "$AUX/var/log" --zstd -cf "$ARCHIVE" caddy
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
