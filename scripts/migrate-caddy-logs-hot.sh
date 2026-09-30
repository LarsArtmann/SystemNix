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
# DRY RUN: --dry-run prints every action without executing.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

usage() {
  echo "usage: migrate-caddy-logs-hot.sh [--dry-run] prepare|finalize" >&2
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

[ "$(id -u)" -eq 0 ] || {
  echo "must run as root (sudo)" >&2
  exit 1
}

# Pressure gate (deploy-pressure doctrine).
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
  run systemctl stop caddy
  QUOTED=0
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
  BEFORE=$(find "$SUBVOL" -type f -newermt '-2 minutes' | wc -l)
  sleep 35
  AFTER=$(find "$SUBVOL" -type f -newermt '-2 minutes' | wc -l)
  echo "recently-touched files: before=$BEFORE after=$AFTER"
  if [ "$AFTER" -eq 0 ]; then
    echo "VERIFY FAILED: no log file touched on the mount in 35s — is caddy running?" >&2
    exit 1
  fi
  echo "finalize OK: caddy logs live on the Samsung."
  echo "Next: reboot in a quiet window after 'nix run .#pre-reboot-check' to verify the boot path."
  echo "Keep the QLC shadow dir under the mountpoint as rollback insurance until the soak ends."
  ;;
*)
  usage
  ;;
esac
