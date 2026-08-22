#!/usr/bin/env bash
# migrate-clickhouse-xfs.sh — move ClickHouse telemetry data onto the
# dedicated XFS partition (nvme0n1p9, ~100 GiB NVMe tail left when the old
# p9 /rust-cache was deleted).
#
# WHY: root @ was 96% full with ClickHouse merge/TTL churn living on BTRFS
# CoW (QLC write amplification) and pinning extents into btrbk root
# snapshots that are kept FOREVER pool-side. XFS is the reference fs for
# ClickHouse. Plan: docs/planning/2026-08-22_02-38_clickhouse-xfs-migration.md
#
# ORDER MATTERS: run `prepare` BEFORE the deploy that introduces the
# fileSystems."/var/lib/clickhouse" entry. Deploy-before-prepare is SAFE
# (mount fails, nofail keeps boot going, clickhouse.service's
# ConditionPathIsMountPoint blocks startup — no data lands on the root fs)
# but leaves observability down until prepare + redeploy.
#
# Usage (sudo, on evo-x2):
#   sudo bash scripts/migrate-clickhouse-xfs.sh prepare   # partition+mkfs+copy
#   nix run .#deploy                                       # activates the mount
#   sudo bash scripts/migrate-clickhouse-xfs.sh finalize  # delete shadowed originals
set -euo pipefail

DISK="/dev/nvme0n1"
PART="${DISK}p9"
LABEL="clickhouse" # XFS labels are capped at 12 chars
SRC="/var/lib/clickhouse"
MNT="/mnt/clickhouse-xfs-migration"
MIN_FREE_GIB=90 # the tail must be at least this big to proceed

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $1"; }
die() {
  echo -e "${RED}FAIL:${NC} $1" >&2
  exit 1
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die "must run as root (sudo)"
}

stop_stack() {
  info "Stopping the SigNoz stack (telemetry ingestion pauses; Gatus will alert)"
  systemctl stop signoz.target 2>/dev/null || true
  systemctl stop clickhouse.service 2>/dev/null || true
  # Wait up to 60s for the clickhouse process to fully exit (parts flush)
  for _ in $(seq 1 30); do
    pgrep -x clickhouse-serv >/dev/null 2>&1 || {
      info "clickhouse-serv exited"
      return 0
    }
    sleep 2
  done
  die "clickhouse-serv still running after 60s — aborting (data must be quiesced for rsync)"
}

prepare() {
  require_root

  # Root under sudo gets a minimal secure PATH — make sure the system
  # environment (and its nix) is always reachable for the resolution below.
  export PATH="/run/current-system/sw/bin:$PATH"

  # ── Tool preflight (BEFORE stopping anything) ─────────────────────────
  # gptfdisk (sgdisk) and parted (partprobe) are NOT in the system
  # environment (verified live 2026-08-22: the first prepare run stopped
  # the stack and THEN died at sgdisk — command not found under sudo's
  # secure PATH). Resolve every tool up front: PATH → system env → a
  # nix build against THIS flake's pinned nixpkgs (registry-free, instant
  # when already in the store). A missing tool must fail BEFORE the stack
  # goes down, never after. partx (util-linux) replaces partprobe.
  resolve_bin() {
    local bin=$1 nixattr=$2
    if command -v "$bin" >/dev/null 2>&1; then
      command -v "$bin"
      return 0
    fi
    if [ -x "/run/current-system/sw/bin/$bin" ]; then
      echo "/run/current-system/sw/bin/$bin"
      return 0
    fi
    # nix build --print-out-paths emits ONE LINE PER OUTPUT (out, man, …) —
    # verified live 2026-08-22: gptfdisk prints two lines and a single-line
    # "$out/bin/$bin" test silently fails on the embedded newline. Iterate
    # every printed store path instead.
    local out line
    out=$(nix build --no-link --print-out-paths \
      "/home/lars/projects/SystemNix#nixosConfigurations.evo-x2.pkgs.${nixattr}" 2>/dev/null) || out=""
    while IFS= read -r line; do
      if [ -n "$line" ] && [ -x "$line/bin/$bin" ]; then
        echo "$line/bin/$bin"
        return 0
      fi
    done <<<"$out"
    return 1
  }
  SGDISK=$(resolve_bin sgdisk gptfdisk) || die "sgdisk unavailable (PATH / system env / nix build of gptfdisk all failed) — fix tooling BEFORE the stack stops"
  PARTX=$(resolve_bin partx util-linux) || die "partx unavailable"
  MKFS_XFS=$(resolve_bin mkfs.xfs xfsprogs) || die "mkfs.xfs unavailable"
  RSYNC=$(resolve_bin rsync rsync) || die "rsync unavailable"
  info "tools resolved: sgdisk=$SGDISK partx=$PARTX mkfs.xfs=$MKFS_XFS rsync=$RSYNC"

  # ── Preflight ─────────────────────────────────────────────────────────
  [ -b "$DISK" ] || die "$DISK is not a block device"
  if lsblk -no NAME "$DISK" | grep -qx "nvme0n1p9"; then
    die 'nvme0n1p9 already exists — refusing to touch the partition table. \
If this is a RERUN after a failed copy: the fs may already hold data; inspect \
(blkid / lsblk -f) and continue manually instead of re-partitioning.'
  fi
  if findmnt -n "$SRC" >/dev/null 2>&1; then
    die "$SRC is already a mountpoint — the XFS migration appears already active"
  fi
  [ -d "$SRC" ] || die "$SRC does not exist (no data to migrate?)"

  # Free tail: last partition end vs disk size (512b sectors)
  DISK_SECTORS=$(cat "/sys/block/nvme0n1/size")
  LAST_END=0
  for p in /sys/block/nvme0n1/nvme0n1p*; do
    end=$(($(cat "$p/start") + $(cat "$p/size")))
    [ "$end" -gt "$LAST_END" ] && LAST_END=$end
  done
  FREE_SECTORS=$((DISK_SECTORS - LAST_END))
  FREE_GIB=$((FREE_SECTORS / 2 / 1024 / 1024))
  info "Unallocated tail after last partition: ${FREE_GIB} GiB"
  [ "$FREE_GIB" -ge "$MIN_FREE_GIB" ] || die "free tail is only ${FREE_GIB} GiB (< ${MIN_FREE_GIB} GiB) — partition table is not what this script expects"

  SRC_SIZE=$(du -sb "$SRC" | cut -f1)
  SRC_FILES=$(find "$SRC" | wc -l)
  info "Source: $SRC — $((SRC_SIZE / 1024 / 1024 / 1024)) GiB, ${SRC_FILES} entries"
  [ "$SRC_SIZE" -gt 0 ] || warn "source is empty — nothing to copy (fresh ClickHouse?)"

  stop_stack

  # ── Partition + filesystem ────────────────────────────────────────────
  info "Creating partition 9 spanning the free tail (sgdisk -n 9:0:0)"
  "$SGDISK" -n 9:0:0 -t 9:8300 "$DISK"
  "$PARTX" -u "$DISK"
  udevadm settle
  [ -b "$PART" ] || die "$PART did not appear after partx -u"
  if lsblk -no FSTYPE "$PART" | grep -q .; then
    die "$PART already contains a filesystem — aborting to avoid destroying data"
  fi

  info "Creating XFS filesystem with label '${LABEL}'"
  "$MKFS_XFS" -L "$LABEL" "$PART"

  # ── Copy + verify ─────────────────────────────────────────────────────
  mkdir -p "$MNT"
  mount "$PART" "$MNT"
  info "rsyncing $SRC -> $MNT (this is the data copy; NVMe->NVMe)"
  "$RSYNC" -aHAX --numeric-ids --info=progress2 "$SRC"/ "$MNT"/

  # Verification: a dry-run delta MUST report zero files transferred.
  info "Verifying: rsync dry-run delta (must be 0 transferred)"
  STATS=$("$RSYNC" -aHAX --numeric-ids --dry-run --stats "$SRC"/ "$MNT"/)
  XFERRED=$(echo "$STATS" | awk '/^Number of regular files transferred:/ {print $NF}')
  [ "${XFERRED:-1}" -eq 0 ] || die "verification failed: ${XFERRED} files still differ — DO NOT DEPLOY yet; inspect $MNT"

  DST_SIZE=$(du -sb "$MNT" | cut -f1)
  DST_FILES=$(find "$MNT" | wc -l)
  info "Copied: $((DST_SIZE / 1024 / 1024 / 1024)) GiB, ${DST_FILES} entries (source: ${SRC_FILES})"
  [ "$DST_FILES" -eq "$SRC_FILES" ] || warn "entry count differs (${DST_FILES} vs ${SRC_FILES}) — check hardlink/special handling"
  [ "$DST_SIZE" -ge "$SRC_SIZE" ] || warn "byte size shrunk (${DST_SIZE} < ${SRC_SIZE}) — XFS overhead accounting differs; dry-run delta above is authoritative"

  umount "$MNT"
  rmdir "$MNT"

  cat <<EOF

${GREEN}PREPARE COMPLETE.${NC} The XFS filesystem is ready and populated.

NEXT STEPS:
  1. nix run .#deploy
     (activates fileSystems."/var/lib/clickhouse" and restarts clickhouse
      onto the new fs — the stack was left stopped by this script)
  2. Verify: findmnt -no FSTYPE /var/lib/clickhouse   # must print: xfs
             curl -sf http://127.0.0.1:8123/ping      # must print: Ok.
             nix run .#post-deploy-check
  3. sudo bash scripts/migrate-clickhouse-xfs.sh finalize
     (deletes the old shadowed originals on the root fs — do this only
      after step 2 is green)

The OLD data stays safely shadowed under the mount until finalize, and is
additionally pinned by tonight's btrbk root snapshots (3d+1w local,
forever pool-side) — double safety net.
EOF
}

finalize() {
  require_root

  # ── Health gates: only delete originals when the new fs is live ────────
  [ "$(findmnt -no FSTYPE "$SRC" 2>/dev/null || true)" = "xfs" ] ||
    die "$SRC is not the XFS mount — deploy first, then finalize"
  findmnt -n -o TARGET "$SRC" | grep -qx "$SRC" || die "$SRC not a mountpoint"
  timeout 15 ls -A "$SRC" >/dev/null 2>&1 || die "$SRC mount is EIO-dead — do NOT finalize"

  info "Probing ClickHouse health"
  if command -v clickhouse-client >/dev/null 2>&1; then
    clickhouse-client --query "SELECT 1" >/dev/null 2>&1 ||
      die "clickhouse-client cannot SELECT 1 — service unhealthy, do NOT finalize"
    TABLES=$(clickhouse-client --query "SELECT count() FROM system.tables WHERE database NOT IN ('system')" 2>/dev/null || echo 0)
    info "non-system tables present: ${TABLES}"
    [ "${TABLES:-0}" -gt 0 ] || warn "zero non-system tables — data may not have migrated; double-check before proceeding"
  else
    warn "clickhouse-client not on PATH — skipping SQL probe"
  fi

  # ── Delete the shadowed originals through a bind view of / ────────────
  VIEW="/mnt/clickhouse-xfs-rootview"
  mkdir -p "$VIEW"
  mount --bind / "$VIEW"
  OLD="$VIEW/var/lib/clickhouse"
  if [ -d "$OLD" ]; then
    OLD_SIZE=$(du -sb "$OLD" | cut -f1)
    info "Deleting shadowed originals ($((OLD_SIZE / 1024 / 1024 / 1024)) GiB) via bind view"
    # rm (not trash): the copies are terabytes-scale telemetry on a 96%-full
    # root; they are ALSO pinned in btrbk snapshots until retention expires.
    rm -rf --one-file-system "$OLD"/*
    rmdir "$OLD" 2>/dev/null || true
  else
    warn "no shadowed originals found at $OLD — already cleaned?"
  fi
  umount "$VIEW"
  rmdir "$VIEW"

  cat <<EOF

${GREEN}FINALIZE COMPLETE.${NC} Root-fs space frees GRADUALLY as the 3d+1w
btrbk root snapshots referencing those extents expire (and pool-side
receives keep their copies forever, per retention policy).

Expected effect: root @ usage drops by the deleted size over the next
week; pool-side root receives stop growing from CH churn immediately.
EOF
}

case "${1:-}" in
prepare) prepare ;;
finalize) finalize ;;
*)
  echo "usage: $0 {prepare|finalize}" >&2
  exit 64
  ;;
esac
