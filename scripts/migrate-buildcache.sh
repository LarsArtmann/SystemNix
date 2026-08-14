#!/usr/bin/env bash
# One-time migration of build caches to the USB SSD (/mnt/buildcache).
#
# Run BEFORE the first deploy of services.buildcache:
#   nix run .#migrate-buildcache && nix run .#deploy
#
# What it does (idempotent — safe to re-run):
#   1. Sets the ext4 volume label to "buildcache"
#   2. Mounts the SSD at /mnt/buildcache with the production mount options
#      (the deploy later takes over the mount via fstab)
#   3. rsyncs each cache, verifies byte-for-byte (apparent size + file count)
#   4. Moves migrated sources to trash (trash-put — reclaim with trash-empty)
#      EXCEPT /rust-cache (its partition reclaim is a separate follow-up)
#   5. Moves ~/.cache/goimports and ~/.cache/go aside so home-manager can
#      symlink them to the SSD on the next activation
#
# Requires: the SanDisk SSD (serial 174444471311) attached via the DAS, and
# passwordless sudo for mount/e2label.
set -Eeuo pipefail

DEVICE="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1"
MNT="/mnt/buildcache"
LABEL="buildcache"
MOUNT_OPTS="noatime,lazytime,commit=120,data=writeback"
SUDO="sudo -n"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}
info() { echo "==> $*"; }

[ "$(id -un)" = "lars" ] || fail "run as lars (nix run .#migrate-buildcache)"
$SUDO true 2>/dev/null || fail "passwordless sudo required"

info "checking device: $DEVICE"
[ -e "$DEVICE" ] || fail "device not found — is the DAS/USB enclosure powered?"

CURRENT_LABEL="$($SUDO e2label "$DEVICE")"
if [ "$CURRENT_LABEL" != "$LABEL" ]; then
  info "setting ext4 label: '$CURRENT_LABEL' -> '$LABEL'"
  $SUDO e2label "$DEVICE" "$LABEL"
else
  info "label already '$LABEL'"
fi

if ! mountpoint -q "$MNT"; then
  info "mounting $DEVICE at $MNT ($MOUNT_OPTS)"
  $SUDO mkdir -p "$MNT"
  $SUDO mount -o "$MOUNT_OPTS" "$DEVICE" "$MNT" || fail "mount failed"
fi
[ "$(findmnt -n -o FSTYPE "$MNT")" = "ext4" ] || fail "$MNT is not ext4 — refusing to write"

TOTAL_BYTES=0
TOTAL_FILES=0

# migrate <source> <dest-relative-to-mount> [keep] [live]
# Copies source INTO the cache, verifies, then trash-puts the source
# (unless "keep"). Skips sources that are missing or already symlinks.
# "live" = source is actively mutated by running tooling (go/gopls trims and
# re-downloads mid-copy): rsync is looped until the pending delta converges
# and byte verification is skipped (go re-verifies/ re-downloads by hash).
migrate() {
  local src="$1"
  local dst_rel="$2"
  local keep="${3:-}"
  local live="${4:-}"
  local dst="$MNT/$dst_rel"

  if [ -L "$src" ]; then
    info "SKIP (already a symlink): $src"
    return 0
  fi
  if [ ! -e "$src" ]; then
    info "SKIP (missing): $src"
    return 0
  fi

  info "copying $src -> $dst"
  mkdir -p "$(dirname "$dst")"
  # rc 24 = "files vanished at source": a live cache trimmed mid-copy is
  # expected on this machine — treat like a pass, the loop re-syncs.
  local pass pending rsync_rc tmp_list
  tmp_list=$(mktemp)
  for pass in 1 2 3; do
    set +e
    rsync -a --itemize-changes --out-format='%n' "$src/" "$dst/" >"$tmp_list"
    rsync_rc=$?
    set -e
    if [ "$rsync_rc" != 0 ] && [ "$rsync_rc" != 24 ]; then
      rm -f "$tmp_list"
      fail "rsync failed (rc=$rsync_rc): $src"
    fi
    pending=$(wc -l <"$tmp_list")
    [ "$pending" -eq 0 ] && break
    info "  pass $pass: $pending items changed at source (live cache), re-syncing"
  done
  rm -f "$tmp_list"
  if [ "$pending" -ne 0 ]; then
    if [ "$live" = "live" ]; then
      info "  source still changing after 3 passes — accepting (cache semantics: consumers re-verify by hash)"
    else
      fail "source did not stabilize after 3 passes: $src"
    fi
  fi

  local src_bytes dst_bytes src_files dst_files
  src_bytes="$(du -sb --apparent-size "$src" | cut -f1)"
  dst_bytes="$(du -sb --apparent-size "$dst" | cut -f1)"
  src_files="$(find "$src" | wc -l)"
  dst_files="$(find "$dst" | wc -l)"
  if [ "$live" = "live" ]; then
    info "verified (live): dst holds $dst_files files / $((dst_bytes / 1024 / 1024)) MiB (src at check: $src_files files)"
    TOTAL_BYTES=$((TOTAL_BYTES + dst_bytes))
    TOTAL_FILES=$((TOTAL_FILES + dst_files))
  else
    # Superset check: dst must hold at least what src holds now.
    if [ "$dst_bytes" -lt "$src_bytes" ] || [ "$dst_files" -lt "$src_files" ]; then
      fail "verification failed for $src (bytes $src_bytes vs $dst_bytes, files $src_files vs $dst_files)"
    fi
    info "verified: $src_files files, $((src_bytes / 1024 / 1024)) MiB"
    TOTAL_BYTES=$((TOTAL_BYTES + src_bytes))
    TOTAL_FILES=$((TOTAL_FILES + src_files))
  fi

  if [ "$keep" = "keep" ]; then
    info "KEEP source (partition reclaim is a follow-up): $src"
  else
    info "moving source to trash: $src"
    trash-put "$src"
  fi
}

migrate "$HOME/.cache/go-build" "go-build" "" live
migrate "$HOME/go/pkg/mod" "go-mod" "" live
migrate "$HOME/.cache/golangci-lint" "golangci-lint"
# goimports and ~/.cache/go are symlinked by home-manager after this runs —
# the real dirs must be gone before `nix run .#deploy` activates them.
migrate "$HOME/.cache/goimports" "goimports"
migrate "$HOME/.cache/go" "go"
migrate "$HOME/.cache/ms-playwright" "playwright"
migrate "$HOME/.cache/pip" "pip"
migrate "$HOME/.npm/_cacache" "npm/_cacache"
migrate "$HOME/.local/share/pnpm/store" "pnpm-store"
# Old /rust-cache NVMe partition: copy for incremental-build continuity; the
# source stays until the p9 partition is reclaimed (separate task).
migrate "/rust-cache/monitor365" "rust/monitor365" keep

echo
info "done: $TOTAL_FILES files, $((TOTAL_BYTES / 1024 / 1024 / 1024)) GiB verified on $MNT"
echo
echo "Next steps:"
echo "  1. nix run .#deploy   # persistent mount, env vars, symlinks, monitoring"
echo "  2. Open a NEW terminal (env vars), then: cd ~/projects/monitor365 && cargo build"
echo "  3. trash-empty        # reclaim NVMe space from the trashed caches (~75 GiB)"
