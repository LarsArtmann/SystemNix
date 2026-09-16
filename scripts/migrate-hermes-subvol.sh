#!/usr/bin/env bash
# migrate-hermes-subvol.sh — move /home/hermes onto the dedicated
# @home-hermes BTRFS subvolume (toplevel), mounted at /home/hermes.
#
# WHY: hermes state (sessions, skills, memories, cron, logs, LSP binaries,
# workspace clones) lived inside the root @ subvolume — every nightly
# btrbk-root send carried its delta to the pool with target_preserve_min=all
# (FOREVER), hoarding deleted agent-workspace bytes on the HDDs, and rolling
# back @ always reverted hermes state with it. Plan + decisions:
# docs/planning/2026-09-15_19-59_HERMES-HOME-SUBVOLUME-MIGRATION.md
#
# ORDER MATTERS: run `prepare` BEFORE the deploy that introduces the
# fileSystems."/home/hermes" entry. Deploy-before-prepare is SAFE but loud:
# the mount fails (nofail keeps boot going) and hermes.service's
# RequiresMountsFor fails the unit into OnFailure alerting — no data is at
# risk (the original directory is untouched until finalize).
#
# STORM GATE: `prepare` REFUSES to start while io PSI some avg10 >= 20%
# (the deploy pressure gate's bar) and wipes its own partial staging on
# retry. 2026-09-16 live lesson: a launch into a storm (avg60 ~60%, 40
# concurrent crush sessions + a VM-test nix build) sat the rsync D-state at
# 100% QLC disk busy for 25+ min with no bounded ETA — the guard tripped
# Zone 6 and sacrificed the flm socket for the duration.
#
# DATA-SAFETY CONTRACT (same shape as migrate-clickhouse-xfs.sh):
#   prepare:  NEVER writes to the source; plain rsync copy (rsync has NO
#             --reflink flag — that is cp syntax, the 2026-08-17 @nix v1
#             incident class; hermes state is ~1 GB so a full copy is
#             trivial); verifies CONTENT (rsync --dry-run delta == 0)
#             before swapping; the swap is mv-aside (recoverable), never a
#             delete.
#   finalize: refuses unless the subvol mount is LIVE, hermes is active,
#             and at least one @home-hermes btrbk snapshot exists; trashes
#             (never rm) the shadowed original.
#
# Usage (sudo, on evo-x2):
#   sudo bash scripts/migrate-hermes-subvol.sh prepare
#   nix run .#deploy                                    # activates home-hermes.mount
#   sudo systemctl start btrbk-root.service            # seeds first full pool send
#   sudo bash scripts/migrate-hermes-subvol.sh status
#   ...days later, after settling...
#   sudo bash scripts/migrate-hermes-subvol.sh finalize
set -euo pipefail

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

QUIESCED=0
prepare_exit_hint() {
  local rc=$?
  if [ "$QUIESCED" -eq 1 ] && [ "$rc" -ne 0 ]; then
    warn 'prepare failed AFTER quiescing hermes — hermes stays stopped. If you are not retrying right away, restart it:
  sudo systemctl start hermes.service "user@$(id -u hermes).service"'
  fi
}
trap prepare_exit_hint EXIT

SRC="/home/hermes"
SUBVOL="@home-hermes"
BTRFS_ROOT="/mnt/btrfs-root" # subvolid=5 automount (snapshots.nix)
DST="$BTRFS_ROOT/$SUBVOL"
OLD="${SRC}.old"
SNAP_DIR="$BTRFS_ROOT/.snapshots"
POOL_ROOT="/mnt/pool/backups/root"
# The hermes uid is pinned (975) in hermes.nix — group name is stable too.
HERMES_USER="hermes"
HERMES_GROUP="hermes"

require_root() {
  [ "$(id -u)" -eq 0 ] || die "must run as root (sudo)"
}

# Root under sudo gets a minimal secure PATH — keep the system environment
# reachable (same trap as migrate-clickhouse-xfs.sh: resolve tools BEFORE
# stopping anything).
export PATH="/run/current-system/sw/bin:$PATH"

require_bins() {
  local missing=""
  for bin in btrfs rsync ionice du findmnt systemctl find sort stat date; do
    command -v "$bin" >/dev/null 2>&1 || missing="$missing $bin"
  done
  [ -z "$missing" ] || die "required binaries not found:$missing (PATH=$PATH)"
}

btrbk_window_warning() {
  local hour
  hour=$(date +%H%M)
  if [ "$hour" -ge "2230" ] || [ "$hour" -le "0045" ]; then
    warn "it is $(date +%H:%M) — inside the 23:00-00:45 btrbk/nix-gc window; rsync churn stacked on nightly sends is the exact IO-storm class this box freezes on. Prefer a quiet window."
  fi
}

ensure_btrfs_root_mounted() {
  # automount triggers on access
  ls "$BTRFS_ROOT" >/dev/null 2>&1 || die "cannot access $BTRFS_ROOT (toplevel automount)"
}

psi_preflight_check() {
  # Same bar as the deploy pressure gate (deploy.sh exit 12): never stack a
  # copy onto an IO storm — the copy is bounded, the storm is not, and this
  # box freezes in exactly that regime (crash #3/#4 class).
  local line avg10 avg60
  line=$(awk '/^some/{print $2, $3}' /proc/pressure/io)
  avg10=${line%% *}
  avg10=${avg10#avg10=}
  avg60=${line##* }
  avg60=${avg60#avg60=}
  if awk -v a="$avg10" 'BEGIN{exit !(a>=20)}'; then
    die "io PSI some avg10=${avg10}% avg60=${avg60}% — the box is in an IO storm (same 20% bar as the deploy pressure gate). Let it drain, then retry prepare."
  fi
  if awk -v a="$avg10" 'BEGIN{exit !(a>=10)}'; then
    warn "io PSI some avg10=${avg10}% is elevated — the copy runs at idle IO priority and will crawl while this lasts"
  fi
  return 0
}

hermes_mounted_subvol() {
  # Prints 'yes' when /home/hermes is already the @home-hermes mount
  if findmnt -n "$SRC" 2>/dev/null | grep -q '@home-hermes'; then
    echo yes
  else
    echo no
  fi
}

cmd_prepare() {
  require_root
  require_bins
  psi_preflight_check
  btrbk_window_warning
  ensure_btrfs_root_mounted

  [ -d "$SRC" ] || die "$SRC does not exist"
  [ "$(hermes_mounted_subvol)" = "yes" ] && die "$SRC is already mounted from $SUBVOL — nothing to prepare"
  if [ -e "$OLD" ]; then
    die "$OLD already exists — a previous prepare either COMPLETED (run the deploy next, not prepare) or died mid-swap. Inspect both dirs before continuing."
  fi
  if [ -e "$DST" ]; then
    local first_entry
    first_entry=$(find "$DST" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)
    if [ -n "$first_entry" ]; then
      warn "$DST holds a PARTIAL copy (prepare aborted mid-copy; prepare never touches the source). Wiping staging, starting fresh:"
      btrfs subvolume delete "$DST"
    else
      warn "$DST exists and is empty (aborted prepare) — reusing it"
    fi
  fi
  if [ ! -e "$DST" ]; then
    info "creating subvolume $DST"
    btrfs subvolume create "$DST"
  fi

  local src_size
  src_size=$(du -sh "$SRC" 2>/dev/null | cut -f1 || true)
  info "source size: ${src_size:-unknown} (file COUNT dominates the copy time on this box, not bytes)"

  info "seed pass 1/2 (hermes may keep running; idle IO priority — yields to everything)"
  ionice -c 3 nice -n 19 rsync -aHAX --info=progress2,stats2 "$SRC/" "$DST/"

  info "quiescing hermes (gateway + its user manager so cron scopes drain)"
  QUIESCED=1
  systemctl stop hermes.service || true
  systemctl stop "user@$(id -u "$HERMES_USER").service" 2>/dev/null || true
  sleep 2

  info "seed pass 2/2 (delta after quiesce)"
  ionice -c 3 nice -n 19 rsync -aHAX --delete --info=stats2 "$SRC/" "$DST/"

  info "verifying content parity (rsync dry-run delta must be empty)"
  local delta
  delta=$(rsync -aHAX --dry-run --itemize-changes "$SRC/" "$DST/" || true)
  if [ -n "$delta" ]; then
    die "content parity check FAILED — dry-run delta is not empty:
$delta
$DST was left in place; the source was never modified. Re-run prepare after inspecting."
  fi

  # Belt: the perms walk on every hermes start heals this anyway.
  chown "$HERMES_USER:$HERMES_GROUP" "$DST"
  chmod 2770 "$DST"

  info "swapping mountpoint aside (recoverable mv, never a delete)"
  mv "$SRC" "$OLD"
  install -d -m 0755 "$SRC" # placeholder mountpoint; overmounted by the deploy

  info "prepare DONE. Next steps:"
  echo "  1. nix run .#deploy                       # mounts $SUBVOL at $SRC, restarts hermes"
  echo "  2. sudo systemctl start btrbk-root.service # seeds the first full pool send"
  echo "  3. sudo bash $0 status                     # verify"
  echo "  4. after settling (days): sudo bash $0 finalize"
  echo "  rollback before deploy: sudo mv $OLD \$( [ -d $SRC ] && rmdir $SRC; echo $SRC )"
}

cmd_finalize() {
  require_root
  require_bins
  [ -e "$OLD" ] || die "$OLD not found — nothing to finalize"

  [ "$(hermes_mounted_subvol)" = "yes" ] || die "$SRC is NOT mounted from $SUBVOL — refusing to touch $OLD"
  systemctl is-active --quiet hermes.service || die "hermes.service is not active — refusing to finalize"
  local latest_snap
  latest_snap=$(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@home-hermes.*' 2>/dev/null | sort | tail -1) || true
  [ -n "$latest_snap" ] || die "no @home-hermes snapshots in $SNAP_DIR — btrbk has not covered the subvol yet; refusing to finalize"

  if [ -d "$POOL_ROOT" ] && find "$POOL_ROOT" -maxdepth 1 -mindepth 1 -type d -name '@home-hermes.*' 2>/dev/null | grep -q .; then
    info "pool receive for @home-hermes confirmed"
  else
    warn "no @home-hermes receive found in $POOL_ROOT (pool detached or first send not run) — local snapshots exist, proceeding on the local tier only"
  fi

  info "trashing $OLD (house rule: trash, never rm)"
  if command -v trash >/dev/null 2>&1; then
    trash "$OLD"
  elif command -v trash-put >/dev/null 2>&1; then
    trash-put "$OLD"
  else
    die "no trash CLI on PATH — leave $OLD in place and run: sudo trash $OLD"
  fi

  info "finalize DONE. NOTE: the old bytes stay pinned by @ snapshots for up to 3d/1w (retention), then free as snapshots expire."
}

cmd_status() {
  require_root
  require_bins
  echo "== $SRC mount =="
  findmnt -n "$SRC" 2>/dev/null || echo "  (not a mountpoint)"
  echo "== subvolume =="
  btrfs subvolume show "$DST" 2>/dev/null | head -3 || echo "  $DST absent"
  echo "== shadowed original =="
  [ -e "$OLD" ] && du -sh "$OLD" 2>/dev/null || echo "  $OLD absent (finalized or never prepared)"
  echo "== latest local btrbk snapshots =="
  for prefix in @ @home-hermes; do
    local latest
    latest=$(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name "$prefix.*" 2>/dev/null | sort | tail -1) || true
    echo "  ${latest:-<none for $prefix>}"
  done
  echo "== latest pool receives =="
  for prefix in @ @home-hermes; do
    local latest
    latest=$(find "$POOL_ROOT" -maxdepth 1 -mindepth 1 -type d -name "$prefix.*" 2>/dev/null | sort | tail -1) || true
    echo "  ${latest:-<none for $prefix>}"
  done
  echo "== hermes =="
  systemctl is-active hermes.service || true
}

case "${1:-}" in
prepare) cmd_prepare ;;
finalize) cmd_finalize ;;
status) cmd_status ;;
*)
  echo "usage: $0 {prepare|finalize|status}"
  echo "  prepare  — create subvol, seed, verify, swap mountpoint (before deploy)"
  echo "  finalize — trash the shadowed original (days after, gated)"
  echo "  status   — show mount/snapshot/receive state"
  exit 1
  ;;
esac
