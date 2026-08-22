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
# DATA-SAFETY CONTRACT (2026-08-22, after the "NEVER lose data" directive):
#   prepare:  never writes to the source; copies with rsync -aHAX; verifies
#             CONTENT (checksum dry-run delta == 0) + exact entry count.
#   finalize: refuses to delete unless the XFS fs is live AND ClickHouse is
#             healthy AND a part-file tripwire passes — and takes a readonly
#             CoW snapshot of @ FIRST, so the exact pre-deletion bytes are
#             recoverable even if the XFS copy turns out bad later.
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
STATE_FILE=".systemnix-migration-state"
MIN_FREE_GIB=90              # the tail must be at least this big to proceed
BTRFS_ROOT="/mnt/btrfs-root" # subvolid=5 automount (snapshots.nix)

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

# Root under sudo gets a minimal secure PATH — make sure the system
# environment (and its nix) is always reachable for tool resolution.
export PATH="/run/current-system/sw/bin:$PATH"

# Resolve a binary: PATH → system env → nix build against THIS flake's
# pinned nixpkgs (registry-free, instant when already in the store).
# NOTE: nix build --print-out-paths emits ONE LINE PER OUTPUT (out, man, …) —
# verified live 2026-08-22: a single-line "$out/bin/$bin" test silently fails
# on the embedded newline. Iterate every printed store path instead.
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

  # ── Tool preflight (BEFORE stopping anything) ─────────────────────────
  # gptfdisk (sgdisk) and parted (partprobe) are NOT in the system
  # environment (verified live 2026-08-22: the first prepare run stopped
  # the stack and THEN died at sgdisk — command not found under sudo's
  # secure PATH). A missing tool must fail BEFORE the stack goes down,
  # never after. partx (util-linux) replaces partprobe.
  SGDISK=$(resolve_bin sgdisk gptfdisk) || die "sgdisk unavailable (PATH / system env / nix build of gptfdisk all failed) — fix tooling BEFORE the stack stops"
  PARTX=$(resolve_bin partx util-linux) || die "partx unavailable"
  MKFS_XFS=$(resolve_bin mkfs.xfs xfsprogs) || die "mkfs.xfs unavailable"
  RSYNC=$(resolve_bin rsync rsync) || die "rsync unavailable"
  MODPROBE=$(resolve_bin modprobe kmod) || die "modprobe unavailable"
  info "tools resolved: sgdisk=$SGDISK partx=$PARTX mkfs.xfs=$MKFS_XFS rsync=$RSYNC modprobe=$MODPROBE"

  # ── Preflight ─────────────────────────────────────────────────────────
  [ -b "$DISK" ] || die "$DISK is not a block device"
  # NOTE: p9 already existing is NOT fatal — the partition+filesystem step
  # below is resumable (stale-signature aware). A rerun after a failed run
  # continues where it left off instead of demanding manual surgery.
  if findmnt -n "$SRC" >/dev/null 2>&1; then
    die "$SRC is already a mountpoint — the XFS migration appears already active"
  fi
  [ -d "$SRC" ] || die "$SRC does not exist (no data to migrate?)"

  # Free tail: last partition end vs disk size (512b sectors). Only gates
  # partition CREATION — when p9 exists this script created it earlier over
  # verified-free space, and the tail is naturally ~0 now.
  P9_EXISTS=false
  [ -b "$PART" ] && P9_EXISTS=true
  if [ "$P9_EXISTS" = false ]; then
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
  else
    P9_GIB=$(($(cat "/sys/block/nvme0n1/nvme0n1p9/size") / 2 / 1024 / 1024))
    info "p9 already exists (${P9_GIB} GiB) — resuming interrupted prepare"
  fi

  stop_stack

  # ── Source metrics — MUST be counted on the quiesced source ──────────
  # Counting before stop_stack races ClickHouse's background merges: run 5
  # (2026-08-22) failed the final entry-count gate 299214 vs 299215 — one
  # part file was merged away between the preflight count and the stop,
  # while the checksum gate (authoritative) proved content parity. Counts
  # taken post-stop compare apples-to-apples with DST below, and the
  # stamped tripwire reflects the quiesced state finalize re-checks.
  SRC_SIZE=$(du -sb "$SRC" | cut -f1)
  SRC_FILES=$(find "$SRC" | wc -l)
  SRC_PARTS=$(find "$SRC/store" -name '*.bin' -type f 2>/dev/null | wc -l)
  info "Source: $SRC — $((SRC_SIZE / 1024 / 1024 / 1024)) GiB, ${SRC_FILES} entries, ${SRC_PARTS} part bin-files"
  [ "$SRC_SIZE" -gt 0 ] || die "source is empty — nothing to migrate (fresh ClickHouse? start the stack first)"

  # ── Partition + filesystem (resumable, stale-signature aware) ────────
  if [ "$P9_EXISTS" = false ]; then
    info "Creating partition 9 spanning the free tail (sgdisk -n 9:0:0)"
    "$SGDISK" -n 9:0:0 -t 9:8300 "$DISK"
    "$PARTX" -u "$DISK"
    udevadm settle
    [ -b "$PART" ] || die "$PART did not appear after partx -u"
  fi

  P9_FSTYPE=$(lsblk -no FSTYPE "$PART" 2>/dev/null | head -n1)
  P9_LABEL=$(lsblk -no LABEL "$PART" 2>/dev/null | head -n1)
  if [ "$P9_FSTYPE" = "xfs" ] && [ "$P9_LABEL" = "$LABEL" ]; then
    # Partial or complete prior run: NEVER re-mkfs a labeled fs — rsync
    # below is incremental and resumes/refreshes the copy idempotently.
    info "p9 already holds the XFS fs '${LABEL}' — resuming (rsync continues where it stopped)"
  else
    if [ -n "$P9_FSTYPE" ]; then
      # Expected residue: the retired /rust-cache ext4 lived at this exact
      # offset; deleting its partition entry (2026-08-17) erased NOTHING —
      # the old superblock still sits on the platters and blkid reports it.
      # Its contents moved to /mnt/buildcache long ago; this is dead bytes,
      # not live data. Only THIS known signature is auto-wiped; anything
      # else is unexpected and aborts (live-data protection).
      if [ "$P9_FSTYPE" = "ext4" ] && [ "$P9_LABEL" = "rust-cache" ]; then
        WIPEFS=$(resolve_bin wipefs util-linux) || die "wipefs unavailable"
        info "wiping stale '${P9_LABEL}' ${P9_FSTYPE} signature (retired rust-cache; partition-entry deletion does not erase bytes)"
        "$WIPEFS" -a "$PART" || die "wipefs failed on $PART"
        udevadm settle
      else
        die "$PART carries an unexpected ${P9_FSTYPE} fs '${P9_LABEL:-unlabeled}' — refusing to destroy; inspect manually: blkid $PART"
      fi
    fi
    info "Creating XFS filesystem with label '${LABEL}'"
    "$MKFS_XFS" -L "$LABEL" "$PART"
  fi

  # ── Copy + verify ─────────────────────────────────────────────────────
  # Load the xfs kernel module EXPLICITLY. No XFS fs existed on this box
  # before, so the module was never loaded; util-linux mount (without -t)
  # probes /proc/filesystems, misses xfs, tries to exec /sbin/modprobe
  # ITSELF (does not exist on NixOS) and aborts with "wrong fs type /
  # missing helper program" BEFORE the mount(2) syscall that would have
  # triggered the kernel's (correctly configured) request_module autoload
  # — verified live 2026-08-22. Explicit modprobe + -t xfs sidesteps both
  # the probe and the userspace helper path.
  "$MODPROBE" xfs || die "modprobe xfs failed — check dmesg"
  mkdir -p "$MNT"
  mount -t xfs "$PART" "$MNT"
  # Never leak the temp mount if a later step dies — the migration must be
  # re-runnable without manual cleanup.
  trap 'umount "$MNT" 2>/dev/null || true' EXIT
  info "rsyncing $SRC -> $MNT (this is the data copy; NVMe->NVMe)"
  # --delete keeps the copy an EXACT mirror of the quiesced source across
  # reruns: ClickHouse merges may have removed part files between attempts,
  # and without --delete those linger in the copy and fail the entry-count
  # gate below as EXTRANEOUS files (checksum parity does not flag extras).
  # Scoped to $MNT (a dedicated mount of the copy) — the source is never
  # touched, and the state stamp is simply re-written after the count.
  "$RSYNC" -aHAX --delete --numeric-ids --info=progress2 "$SRC"/ "$MNT"/

  # Verification: a CHECKSUM dry-run delta MUST report zero files
  # transferred. Without --checksum rsync only compares size+mtime — a
  # corrupted-in-flight write with intact metadata would pass silently.
  # 26 GiB of NVMe checksums costs seconds; this is THE integrity gate.
  info "Verifying: rsync checksum dry-run delta (must be 0 transferred)"
  STATS=$("$RSYNC" -aHAX --numeric-ids --checksum --dry-run --stats "$SRC"/ "$MNT"/)
  XFERRED=$(echo "$STATS" | awk '/^Number of regular files transferred:/ {print $NF}')
  [ "${XFERRED:-1}" -eq 0 ] || die "verification failed: ${XFERRED} files differ by CONTENT — DO NOT DEPLOY yet; inspect $MNT"

  DST_SIZE=$(du -sb "$MNT" | cut -f1)
  DST_FILES=$(find "$MNT" | wc -l)
  info "Copied: $((DST_SIZE / 1024 / 1024 / 1024)) GiB, ${DST_FILES} entries (source: ${SRC_FILES})"
  [ "$DST_FILES" -eq "$SRC_FILES" ] || die "entry count differs (${DST_FILES} vs ${SRC_FILES}) — copy incomplete despite checksum pass; investigate before deploying"
  [ "$DST_SIZE" -ge "$SRC_SIZE" ] || warn "byte size shrunk (${DST_SIZE} < ${SRC_SIZE}) — sparse files likely; the checksum delta above is authoritative"

  # Stamp a tripwire finalize re-checks on the LIVE fs: the live XFS must
  # still hold >= half of these data files when originals are deleted
  # (merges can legitimately drop part files; a near-zero count means the
  # wrong/empty filesystem is mounted). Dotfile at the fs root — ClickHouse
  # ignores unknown files in its data root.
  cat >"$MNT/$STATE_FILE" <<STAMP
timestamp=$(date -Is)
source_bytes=$SRC_SIZE
source_entries=$SRC_FILES
source_part_bin_files=$SRC_PARTS
STAMP
  info "stamped migration state: $SRC_PARTS part bin-files"

  umount "$MNT"
  trap - EXIT
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
     (snapshots @, THEN deletes the old shadowed originals — do this only
      after step 2 is green)

The OLD data stays safely shadowed under the mount until finalize, and is
additionally pinned by btrbk root snapshots (3d+1w local, forever pool-side).
EOF
}

finalize() {
  require_root

  BTRFS=$(resolve_bin btrfs btrfs-progs) || die "btrfs CLI unavailable (PATH / system env / nix build of btrfs-progs all failed)"
  CH_CLIENT=$(resolve_bin clickhouse-client clickhouse) || die "clickhouse-client unavailable — cannot verify data health before deletion; refusing to finalize"

  # ── Health gates: only delete originals when the new fs is live ────────
  [ "$(findmnt -no FSTYPE "$SRC" 2>/dev/null || true)" = "xfs" ] ||
    die "$SRC is not the XFS mount — deploy first, then finalize"
  findmnt -n -o TARGET "$SRC" | grep -qx "$SRC" || die "$SRC not a mountpoint"
  timeout 15 ls -A "$SRC" >/dev/null 2>&1 || die "$SRC mount is EIO-dead — do NOT finalize"

  info "Probing ClickHouse health"
  "$CH_CLIENT" --query "SELECT 1" >/dev/null 2>&1 ||
    die "clickhouse-client cannot SELECT 1 — service unhealthy, do NOT finalize"
  TABLES=$("$CH_CLIENT" --query "SELECT count() FROM system.tables WHERE database NOT IN ('system')" 2>/dev/null || echo 0)
  info "non-system tables present: ${TABLES}"
  [ "${TABLES:-0}" -gt 0 ] || die "zero non-system tables — the live fs does not hold your data; do NOT finalize"

  # ── Part-file tripwire (stamped at prepare time) ───────────────────────
  STAMPED_PARTS=$(awk -F= '/^source_part_bin_files=/ {print $2}' "$SRC/$STATE_FILE" 2>/dev/null || true)
  if [ -n "${STAMPED_PARTS:-}" ] && [ "${STAMPED_PARTS}" -gt 0 ]; then
    LIVE_PARTS=$(find "$SRC/store" -name '*.bin' -type f 2>/dev/null | wc -l)
    info "part bin-files: live=${LIVE_PARTS} stamped-at-prepare=${STAMPED_PARTS}"
    # Merges legitimately replace N parts with 1; anything below half means
    # the wrong filesystem is mounted (empty/partial copy).
    [ "${LIVE_PARTS:-0}" -ge $((STAMPED_PARTS / 2)) ] ||
      die "live fs holds ${LIVE_PARTS} part files (< 50% of the ${STAMPED_PARTS} stamped at prepare) — wrong or empty filesystem mounted; do NOT finalize"
  else
    warn "no migration state stamp found on the live fs (pre-hardening prepare?) — relying on snapshot + health gates only"
  fi

  # ── Pre-deletion snapshot of @ (the zero-risk recovery point) ──────────
  # The nightly btrbk snapshot may be hours stale; this readonly CoW
  # snapshot pins the EXACT pre-deletion bytes. Cost is ~zero: the extents
  # are already pinned by the 3d+1w retention snapshots until they expire.
  # Placed OUTSIDE .snapshots so btrbk retention never touches it.
  mount "$BTRFS_ROOT" 2>/dev/null || true
  findmnt -t btrfs -n "$BTRFS_ROOT" >/dev/null 2>&1 ||
    die "$BTRFS_ROOT not mounted (subvolid=5 automount) — cannot snapshot; refusing to finalize"
  SNAP="${BTRFS_ROOT}/clickhouse-predelete-$(date +%Y%m%d-%H%M%S)"
  if [ -e "$SNAP" ]; then
    die "$SNAP already exists (two finalizes in one second?)"
  fi
  info "Creating readonly pre-deletion snapshot: $SNAP"
  "$BTRFS" subvolume snapshot -r "${BTRFS_ROOT}/@" "$SNAP" ||
    die "snapshot creation FAILED — do NOT delete anything; investigate btrfs health first"
  [ -d "$SNAP/var/lib/clickhouse" ] ||
    die "snapshot does not contain /var/lib/clickhouse — snapshot source was wrong; ABORT (nothing deleted)"

  # ── Delete the shadowed originals through a bind view of / ────────────
  # bind (not rbind) exposes ONLY the @ filesystem — the XFS mount at
  # /var/lib/clickhouse is NOT visible through this view, so the live data
  # is unreachable by the rm.
  VIEW="/mnt/clickhouse-xfs-rootview"
  mkdir -p "$VIEW"
  mount --bind / "$VIEW"
  OLD="$VIEW/var/lib/clickhouse"
  if [ -d "$OLD" ]; then
    OLD_SIZE=$(du -sb "$OLD" | cut -f1)
    info "Deleting shadowed originals ($((OLD_SIZE / 1024 / 1024 / 1024)) GiB) via bind view"
    # rm the whole DIRECTORY (not $OLD/* — a glob silently skips dotfiles).
    # rm (not trash): terabyte-scale telemetry on a 96%-full root, already
    # preserved byte-exact in $SNAP + btrbk snapshots.
    # --one-file-system: belt against any stray bind under $OLD.
    rm -rf --one-file-system "$OLD"
  else
    warn "no shadowed originals found at $OLD — already cleaned?"
  fi
  umount "$VIEW"
  rmdir "$VIEW"

  cat <<EOF

${GREEN}FINALIZE COMPLETE.${NC} Root-fs space frees GRADUALLY as the 3d+1w
btrbk root snapshots referencing those extents expire (and pool-side
receives keep their copies forever, per retention policy).

RECOVERY POINT: the exact pre-deletion state of the old data is preserved
in the READONLY snapshot:
  $SNAP
Recover with (stop the stack first):
  rsync -aHAX --numeric-ids --checksum -n --stats \\
    "$SNAP/var/lib/clickhouse"/ /var/lib/clickhouse/   # preview delta
  rsync -aHAX --numeric-ids "$SNAP/var/lib/clickhouse"/ /var/lib/clickhouse/

After a soak period (1-2 weeks, once the XFS copy is proven in daily use),
delete the snapshot to release the pinned extents:
  "$BTRFS" subvolume delete "$SNAP"
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
