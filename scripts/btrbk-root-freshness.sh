#!/usr/bin/env bash
# btrbk-root-freshness: first ExecCondition leg of btrbk-root.service
# (platforms/nixos/system/snapshots.nix, btrbkRootFreshness).
#
# Why (2026-11-28): 23:00 was the only slot of the root snapshot + pool
# send, and the second leg (btrbk-admission) refuses it during an IO storm
# or within 60 min of a memory-emergency-guard trip. A refusal is a clean
# skip (no OnFailure, the unit is not failed), so a refused night has no
# snapshot and no pool backup until the next 23:00. Refused eight nights in
# a row (2026-11-20..27), the root snapshot and its pool copy went 12 days
# stale; the only signal was the next morning's btrfs-verify-* units.
#
# Contract: btrbk-root-catchup.timer offers the same service every 30
# minutes (00..22 h). This leg answers "has the most recent nightly slot
# been served?" so an extra slot never makes a second snapshot on a night
# that already has one (snapshot_preserve_min = 2d: every extra snapshot
# pins extents for two days on the space-tight QLC root). Served means a
# root snapshot AND a received pool backup stamped at or after the slot
# (a send that died after the snapshot leaves the pool copy unserved).
#   exit 0  run owed: a leg is older than the slot, missing or unparseable
#   exit 1  skip: both legs are at or after the slot
#   exit 64  usage error
# The slot is the most recent --slot wall-clock instant (23:00 by default,
# the nightly timer's own slot): the nightly fire itself is always owed
# unless a catch-up already served that night, and a refused 23:00 is
# first retried at 23:15.
#
# Ages are parsed from the NAME (btrbk `@.YYYYMMDDTHHMM`, received subvols
# keep the snapshot name), never from stat: a snapshot inherits the source
# directory's mtime (docs/agents/storage.md).
#
# Fixture-tested via checks.btrbk-root-freshness-fixture (the dirs point at
# fixture dirs and --now pins the clock; no stubs needed).
set -euo pipefail

SNAPSHOT_DIR="/mnt/btrfs-root/.snapshots"
TARGET_DIR="/mnt/pool/backups/root"
SLOT="23:00"
NOW=""
UNIT="btrbk-root"
GLOB='@.*'

usage() {
    echo "usage: btrbk-root-freshness [--snapshot-dir DIR] [--target-dir DIR] [--slot HH:MM] [--now EPOCH]" >&2
    echo "  exit 0 = run owed, exit 1 = skip (nightly slot served), exit 64 = usage error" >&2
    exit 64
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --snapshot-dir)
            [ "$#" -ge 2 ] || usage
            SNAPSHOT_DIR=$2
            shift 2
            ;;
        --target-dir)
            [ "$#" -ge 2 ] || usage
            TARGET_DIR=$2
            shift 2
            ;;
        --slot)
            [ "$#" -ge 2 ] || usage
            SLOT=$2
            shift 2
            ;;
        --now)
            [ "$#" -ge 2 ] || usage
            NOW=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done
if [ -z "$NOW" ]; then
    NOW=$(date +%s)
fi
case "$NOW" in
    '' | *[!0-9]*)
        echo "btrbk-root-freshness: --now wants an epoch, got '$NOW'" >&2
        exit 64
        ;;
esac

# Prints the creation epoch of the newest "@.<timestamp>" entry of a
# directory. Prints nothing and fails when there is none, or when its name
# does not carry a parseable timestamp: unknown is never served.
newest_epoch() {
    local dir="$1" latest name stamp
    latest="$(find "$dir" -maxdepth 1 -mindepth 1 -type d -name "$GLOB" 2>/dev/null | sort | tail -n 1)" || latest=""
    [ -n "$latest" ] || return 1
    name="$(basename "$latest")"
    stamp="${name#*.}"
    case "$stamp" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9]) ;;
        *) return 1 ;;
    esac
    date -d "${stamp:0:4}-${stamp:4:2}-${stamp:6:2} ${stamp:9:2}:${stamp:11:2}:00" +%s 2>/dev/null || return 1
}

# The most recent nightly slot at or before NOW (wall clock, DST-safe).
today=$(date -d "@$NOW" +%Y-%m-%d)
slot_today=$(date -d "$today $SLOT" +%s)
if [ "$NOW" -ge "$slot_today" ]; then
    slot=$slot_today
else
    slot=$(date -d "$today yesterday $SLOT" +%s)
fi

snapshot_epoch=""
snapshot_epoch="$(newest_epoch "$SNAPSHOT_DIR")" || snapshot_epoch=""
target_epoch=""
target_epoch="$(newest_epoch "$TARGET_DIR")" || target_epoch=""

# served <epoch>: known, and stamped at or after the slot.
served() {
    [ -n "$1" ] && [ "$1" -ge "$slot" ]
}

# when <epoch>: one leg's newest entry for the journal line.
when() {
    if [ -z "$1" ]; then
        printf 'none'
    else
        date -d "@$1" '+%Y-%m-%d %H:%M'
    fi
}

slot_text=$(date -d "@$slot" '+%Y-%m-%d %H:%M')
if served "$snapshot_epoch" && served "$target_epoch"; then
    echo "SKIP: $UNIT - root snapshot $(when "$snapshot_epoch"), pool backup $(when "$target_epoch"): the nightly slot $slot_text is served"
    exit 1
fi
echo "RUN OWED: $UNIT - root snapshot $(when "$snapshot_epoch"), pool backup $(when "$target_epoch"): the nightly slot $slot_text is not served"
exit 0
