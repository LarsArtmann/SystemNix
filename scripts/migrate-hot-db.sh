#!/usr/bin/env bash
# migrate-hot-db — user-run migration of a service dataDir onto the Samsung
# hot-DB tier (services.hot-db). Clickhouse-XFS migration precedent.
#
# Flow (one maintenance window per service):
#   1. Agent-side (before the window): declare the entry in
#      `services.hot-db.entries` (enable = true) but DO NOT deploy yet.
#   2. `sudo migrate-hot-db.sh prepare <name> <unit> <dataDir>`
#      Pressure-gates, stops the unit, rsyncs dataDir into a staging dir on
#      /mnt/hot/hot/<name>.staging (ionice idle), verifies file count + size.
#   3. Deploy (mounts the fresh empty subvol AT dataDir — old data stays
#      hidden under the mountpoint until step 4).
#   4. `sudo migrate-hot-db.sh finalize <name> <unit> <dataDir>`
#      Ensures the unit is stopped, drains staging INTO the live subvol
#      (rsync --remove-source-files style), verifies, restarts the unit.
#   5. Verify the service (Gatus green + functional probe), then the agent
#      removes the staging dir and the shadowed old data is reclaimed when
#      snapshots allow (root fs: as btrbk retention expires).
#
# Rollback (never automated mid-incident): flip the entry back out of the
# config, deploy, then rsync staging (prepare-only case) or the dataDir
# contents (post-finalize) back from the shadowed original dir after
# unmounting.
#
# DRY RUN: pass --dry-run as the first argument to print every action.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

usage() {
  echo "usage: migrate-hot-db.sh [--dry-run] prepare|finalize <name> <unit> <dataDir>" >&2
  exit 2
}

[ $# -eq 4 ] || usage
ACTION=$1
NAME=$2
UNIT=$3
DATADIR=$4

STAGING="/mnt/hot/hot/${NAME}.staging"
TARGET="/mnt/hot/hot/${NAME}"

run() {
  echo "+ $*"
  [ "$DRY_RUN" = "1" ] || "$@"
}

# Pressure gate (deploy-pressure doctrine): never migrate during an IO
# storm — the rsync is a full read of the dataDir + full write to the SSD.
# /proc/pressure/io line 1: "some avg10=x.y avg60=... avg300=..." — field 2.
PSI=$(awk 'NR==1 {print $2}' /proc/pressure/io)
PSI="${PSI#avg10=}"
PSI="${PSI:-0}"
if awk -v p="$PSI" 'BEGIN { exit !(p >= 20) }'; then
  echo "REFUSED: IO PSI some avg10 = ${PSI}% (>= 20%). Wait for a quiet window or use DEPLOY_FORCE_PRESSURE semantics consciously." >&2
  exit 1
fi

# Gates valid for both actions.
[ -d /mnt/hot/hot ] || {
  echo "/mnt/hot/hot does not exist — is the Samsung mounted and services.hot-db deployed?" >&2
  exit 1
}
if ! mountpoint -q /mnt/hot; then
  echo "/mnt/hot is not a mountpoint — detached Samsung. Refusing." >&2
  exit 1
fi

case "$ACTION" in
prepare)
  [ -d "$DATADIR" ] || {
    echo "$DATADIR does not exist" >&2
    exit 1
  }
  echo "== prepare: stop $UNIT, stage $DATADIR → $STAGING (PSI avg10 ${PSI}%)"
  run systemctl stop "$UNIT"
  run mkdir -p "$STAGING"
  run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --info=stats2 "$DATADIR"/ "$STAGING"/
  # Verify: file count + byte size must match.
  SRC_COUNT=$(find "$DATADIR" -xdev -type f | wc -l)
  DST_COUNT=$(find "$STAGING" -type f | wc -l)
  SRC_SIZE=$(du -sb --apparent-size "$DATADIR" | awk '{print $1}')
  DST_SIZE=$(du -sb --apparent-size "$STAGING" | awk '{print $1}')
  echo "files: src=$SRC_COUNT dst=$DST_COUNT  bytes: src=$SRC_SIZE dst=$DST_SIZE"
  if [ "$SRC_COUNT" != "$DST_COUNT" ] || [ "$SRC_SIZE" != "$DST_SIZE" ]; then
    echo "VERIFY FAILED — counts/sizes differ. Unit left STOPPED; inspect before proceeding." >&2
    exit 1
  fi
  echo "prepare OK. Deploy the enabled services.hot-db entry now, then run: $0 finalize $NAME $UNIT $DATADIR"
  echo "NOTE: $UNIT is STOPPED. Keep the window short."
  ;;
finalize)
  [ -d "$STAGING" ] || {
    echo "$STAGING missing — nothing staged (already finalized?)" >&2
    exit 1
  }
  mountpoint -q "$DATADIR" || {
    echo "$DATADIR is not a mountpoint — deploy the enabled entry first" >&2
    exit 1
  }
  echo "== finalize: drain $STAGING → $TARGET (live subvol), restart $UNIT"
  run systemctl stop "$UNIT"
  run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --remove-source-files --info=stats2 "$STAGING"/ "$DATADIR"/
  DST_COUNT=$(find "$DATADIR" -xdev -type f | wc -l)
  echo "finalized files in live subvol: $DST_COUNT"
  run rmdir "$STAGING" 2>/dev/null || echo "WARNING: staging not empty — leftover dirs kept at $STAGING"
  run systemctl start "$UNIT"
  echo "finalize OK. Verify Gatus + a functional probe, then clean the shadowed original under the old (now unmounted) dataDir."
  ;;
*)
  usage
  ;;
esac
