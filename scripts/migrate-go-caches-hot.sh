#!/usr/bin/env bash
# migrate-go-caches-hot — one-time relocation of the three Go caches
# (go-build, go-mod, golangci-lint) from the USB buildcache SSD
# (/mnt/buildcache) onto the Samsung TLC hot tier (users/lars/cache/*
# subvolumes, compress=zstd). Companion to
# modules/nixos/services/hot-user-caches.nix (the 2026-11-05 go-build
# un-parking; see the module header for the 2026-09-20 blocker history).
#
# Order is MANDATORY — prepare BEFORE the deploy carrying the mounts:
# deploying first would automount EMPTY subvols over the cache paths
# (shadow-split: builds keep writing the USB shadow under the mount).
#
#   1. sudo bash scripts/migrate-go-caches-hot.sh prepare
#      PSI-gates, creates go-mod + golangci-lint subvols (go-build exists
#      since 2026-09-20), double-pass rsyncs each cache, reports the
#      churn delta as information (cache entries are REBUILDABLE — deltas
#      lost between passes are honest recompiles, never data loss; unlike
#      migrate-user-tmp-hot.sh there is no exact-match verify).
#   2. nix run .#deploy
#      hot-user-caches automounts the subvols AT ~/.cache/go-build etc.;
#      home.nix repoints GOCACHE/GOMODCACHE/GOLANGCI_LINT_CACHE and drops
#      the .cache/go-build HM symlink (same change — required: systemd
#      canonicalizes mount units through symlinks).
#   3. sudo bash scripts/migrate-go-caches-hot.sh finalize
#      Verifies all three mounts answer + lars can write onto them.
#
# Soak, then reclaim the USB:
#
#   4. sudo bash scripts/migrate-go-caches-hot.sh reclaim-usb
#      Refuses unless all three live caches are on the tlc device; then
#      rm -rf's the abandoned USB trees (~126G on the 85%-full drive).
#      rm (not trash) is deliberate: trashing would COPY 126G onto the
#      QLC root trash — the exact churn this relocation exists to remove
#      (same reasoning as buildcache-gc's rm-on-stale-targets comment).
#
# DRY RUN: --dry-run prints every action without executing.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

usage() {
  echo "usage: migrate-go-caches-hot.sh [--dry-run] prepare|finalize|reclaim-usb" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ACTION=$1

# Fixture hooks (test scripts override these; production uses the defaults).
BC=${GO_CACHE_MIGRATE_BC:-/mnt/buildcache}
HOT=${GO_CACHE_MIGRATE_HOT:-/mnt/hot/users/lars/cache}
USER=${GO_CACHE_MIGRATE_USER:-lars}
CACHES=${GO_CACHE_MIGRATE_CACHES:-"go-build go-mod golangci-lint"}

run() {
  echo "+ $*"
  [ "$DRY_RUN" = "1" ] || "$@"
}

if [ "$DRY_RUN" != "1" ]; then
  [ "$(id -u)" -eq "${GO_CACHE_MIGRATE_ROOT_UID:-0}" ] || {
    echo "must run as root (sudo)" >&2
    exit 1
  }
fi

# ── Entry gate (same shape as migrate-user-tmp-hot.sh — one migrate-* at a
# time, refuse to start into a tripped box; keeps us out of balance windows).
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
  maintenance-entry-gate --name migrate-go-caches-hot --psi-max 30 || {
    echo "ERROR: entry gate refused (see above) — a refused migration is free, a migration into a storm is freeze #19." >&2
    exit 1
  }
fi

# Pressure gate (read-only; survives PSI-disabled kernels).
PSI=$(awk 'NR==1 {print $2}' "${GO_CACHE_MIGRATE_PSI_FILE:-/proc/pressure/io}" 2>/dev/null || true)
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
if ! mountpoint -q "$BC"; then
  echo "$BC is not a mountpoint — detached buildcache SSD; the source trees are unreachable. Refusing." >&2
  exit 1
fi

# The 2026-09-20 blocker, closed at the ONLY point where ordering is
# guaranteed: systemd canonicalizes mount units through symlinks, so the
# old HM out-of-store symlink at ~/.cache/go-build must be GONE before the
# deploy loads the automount (HM would remove it at activation, but the
# automount start is not ordered after home-manager-lars.service — the
# parked note's boot-order requirement, satisfied by operator sequencing).
# Until the deploy, env'd shells keep using $BC/go-build (old env); env-less
# go processes may recreate a real ~/.cache/go-build dir on the QLC — the
# existing reap surfaces (buildcache-reap-names, deploy.sh sweep) handle it.
HM_LINK="/home/$USER/.cache/go-build"
if [ -L "$HM_LINK" ]; then
  case "$(readlink "$HM_LINK")" in
  "$BC"/go-build*) run rm -f "$HM_LINK" ;;
  *)
    echo "REFUSED: $HM_LINK is a symlink to $(readlink "$HM_LINK"), not $BC/go-build — inspect by hand" >&2
    exit 1
    ;;
  esac
fi

case "$ACTION" in
prepare)
  for c in $CACHES; do
    SRC="$BC/$c"
    DST="$HOT/$c"
    [ -d "$SRC" ] || {
      echo "SKIP $c: no source dir $SRC" >&2
      continue
    }
    if ! btrfs subvolume show "$DST" >/dev/null 2>&1; then
      [ -e "$DST" ] && {
        echo "REFUSED $c: $DST exists but is not a subvolume — inspect by hand" >&2
        exit 1
      }
      run btrfs subvolume create "$DST"
    fi
    echo "== prepare $c: double-pass rsync $SRC -> $DST (PSI avg10 ${PSI}%)"
    if [ "$DRY_RUN" = "1" ]; then
      echo "dry run: rsync skipped"
      continue
    fi
    # Two passes like the tmp migration: the second converges deltas
    # written by live builds during the first. Unlike tmp there is NO
    # exact-match gate: a build storm mid-copy means a nonzero delta
    # forever, and every delta byte is a REBUILDABLE cache entry.
    run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --info=stats1 "$SRC"/ "$DST"/
    run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --info=stats1 "$SRC"/ "$DST"/
    SRC_COUNT=$(find "$SRC" -xdev -type f | wc -l)
    DST_COUNT=$(find "$DST" -type f | wc -l)
    SRC_SIZE=$(du -sb --apparent-size "$SRC" | awk '{print $1}')
    DST_SIZE=$(du -sb --apparent-size "$DST" | awk '{print $1}')
    if [ "$DST_COUNT" -eq 0 ]; then
      echo "VERIFY FAILED $c: destination empty after rsync — aborting before any deploy" >&2
      exit 1
    fi
    echo "$c: files src=$SRC_COUNT dst=$DST_COUNT (delta=$((SRC_COUNT - DST_COUNT)) lost-rebuildable)  bytes src=$SRC_SIZE dst=$DST_SIZE"
    chown "$USER":users "$DST" || true
  done
  echo "prepare OK. Now: nix run .#deploy  — then:  sudo $0 finalize"
  echo "WARNING: cache entries written from here until the deploy land on the USB shadow and are lost (rebuildable)."
  ;;
finalize)
  FAILED=0
  for c in $CACHES; do
    SRC="$BC/$c"
    MNT="/home/$USER/.cache/$c"
    DST="$HOT/$c"
    if ! mountpoint -q "$MNT"; then
      echo "VERIFY FAILED $c: $MNT is not a mountpoint — deploy the hot-user-caches mounts first" >&2
      FAILED=1
      continue
    fi
    EXISTING=$(find "$DST" -type f | wc -l)
    if [ "$EXISTING" -eq 0 ]; then
      echo "VERIFY FAILED $c: no files on the mount — rsynced content missing" >&2
      FAILED=1
      continue
    fi
    PROBE="$MNT/.migrate-finalize-probe"
    runuser -u "$USER" -- touch "$PROBE" || {
      echo "VERIFY FAILED $c: $USER cannot write onto the mount (ownership?)" >&2
      FAILED=1
      continue
    }
    [ -f "$DST/.migrate-finalize-probe" ] || {
      echo "VERIFY FAILED $c: probe written at $MNT is not on $DST — mount mismatch" >&2
      FAILED=1
      continue
    }
    rm -f "$PROBE"
    echo "finalize $c OK: live on the Samsung ($EXISTING files)"
  done
  [ "$FAILED" -eq 0 ] || exit 1
  echo "finalize OK. Keep the USB trees as rollback insurance until the soak ends, then: sudo $0 reclaim-usb"
  ;;
reclaim-usb)
  FAILED=0
  for c in $CACHES; do
    MNT="/home/$USER/.cache/$c"
    SRC="$BC/$c"
    if ! mountpoint -q "$MNT"; then
      echo "REFUSED $c: $MNT is not a mountpoint — finalize first" >&2
      FAILED=1
      continue
    fi
    # The live cache MUST be on the tlc disk (kernel nvme names flip —
    # compare against the Samsung label mount, not a device name).
    LIVE_SRC=$(findmnt -no SOURCE "$MNT" || true)
    case "$LIVE_SRC" in
    *[/]users/lars/cache/"$c"*) ;;
    *)
      echo "REFUSED $c: $MNT resolves to '$LIVE_SRC', not the Samsung cache subvol — the USB tree may still be LIVE. Do not delete." >&2
      FAILED=1
      continue
      ;;
    esac
    if [ "$DRY_RUN" = "1" ]; then
      echo "dry run: would rm -rf $SRC"
      continue
    fi
    BEFORE=$(df -h "$BC" | awk 'NR==2 {print $4}')
    rm -rf "$SRC"
    AFTER=$(df -h "$BC" | awk 'NR==2 {print $4}')
    echo "reclaimed $c: $SRC gone (buildcache free: $BEFORE -> $AFTER)"
  done
  [ "$FAILED" -eq 0 ] || exit 1
  echo "reclaim-usb OK: buildcache SSD keeps pnpm/playwright/npm/pip only."
  ;;
*)
  usage
  ;;
esac
