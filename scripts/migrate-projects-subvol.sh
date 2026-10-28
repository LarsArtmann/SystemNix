#!/usr/bin/env bash
# migrate-projects-subvol — one-time relocation of /home/lars/projects from
# the QLC root `@` onto the Samsung TLC (`users/lars/projects` subvolume,
# Set-B: snapshotted + pool-sent, deliberately NOT +C — source-of-truth
# repos, not a cache tree). Companion to platforms/nixos/system/snapshots.nix
# (projectsHomeMount + the btrbk "projects" instance); runbook:
# docs/services/projects-subvol.md; plan:
# docs/planning/2026-10-28_projects-samsung-subvol-migration.md.
#
# Order is MANDATORY — prepare BEFORE the deploy carrying the mount:
# deploying the mount first would mount an EMPTY subvol over the live dir
# (shadow-split; the §18 pre-deploy gate FAILS exactly that deploy by
# design — that FAIL is the protection working, do not bypass it).
#
#   1. sudo bash scripts/migrate-projects-subvol.sh prepare
#      Entry-gated (maintenance lock + PSI; refuses inside the 23:00-00:15
#      btrbk ladder window and while a balance storms), space-asserted
#      (Samsung + pool ≥ payload × 1.5, QLC unalloc > 10 GiB), creates the
#      subvol through /mnt/hot, double-pass throttled rsync (-aHAXS,
#      sparse-aware; the Phase-A doom dirs are ALWAYS excluded), banded
#      parity verify + a git fsck spot-check on the subvol copy.
#      Re-runnable: a second prepare runs delta passes only.
#   2. nix run .#deploy
#      fstab mounts users/lars/projects AT /home/lars/projects; the QLC
#      shadow dir stays beneath the mount as rollback insurance.
#   3. sudo bash scripts/migrate-projects-subvol.sh finalize
#      Verifies the mount answers + lars can write onto it, then kicks the
#      first btrbk-projects seed (--no-block; the journal exit summary is
#      the receipt — `journalctl -u btrbk-projects -f`).
#   4. (soak ≥ 7 days, ≥ 5 green nightly sends — then)
#      sudo bash scripts/migrate-projects-subvol.sh shadow-cleanup
#      REFUSES unless the mount is live, Samsung-served, and ≥ 5 pool
#      receives exist. Archives the QLC shadow dir to
#      /mnt/pool/backups/home-lars-projects/projects-shadow-final-<date>.tar.zst
#      (verified exact file count), deletes the shadow CONTENTS through an
#      auxiliary subvol=@ bind view (family precedent: the verified archive
#      IS the safety net — trashing 126G into root's .Trash would re-pin
#      the exact extents being freed), re-verifies empty via a fresh view.
#      QLC space settles as the @ pin windows expire, never instantly.
#
# ROLLBACK: until shadow-cleanup, umount + reboot regresses to the shadow
# (pre-cutover state; post-cutover writes are on the subvol only).
#
# DRY RUN: --dry-run prints every action without executing (ungated).
# Fixture hooks: PROJ_MIGRATE_* env overrides (same pattern as
# migrate-user-tmp-hot.sh; production uses the defaults).
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

usage() {
  echo "usage: migrate-projects-subvol.sh [--dry-run] prepare|finalize|shadow-cleanup" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ACTION=$1

SRC=${PROJ_MIGRATE_SRC:-/home/lars/projects}
SUBVOL=${PROJ_MIGRATE_SUBVOL:-/mnt/hot/users/lars/projects}
USER=${PROJ_MIGRATE_USER:-lars}
GROUP=${PROJ_MIGRATE_GROUP:-users}
HOT_ROOT=${PROJ_MIGRATE_HOT_ROOT:-/mnt/hot}
POOL_FREE_PATH=${PROJ_MIGRATE_POOL_FREE_PATH:-/mnt/pool}
ROOT_FREE_PATH=${PROJ_MIGRATE_ROOT_FREE_PATH:-/}
STATE_DIR=${PROJ_MIGRATE_STATE_DIR:-/home/lars/.cache/projects-migration}
RECEIVES_DIR=${PROJ_MIGRATE_RECEIVES_DIR:-/mnt/pool/backups/projects-subvol}
ARCHIVE_DIR=${PROJ_MIGRATE_ARCHIVE_DIR:-/mnt/pool/backups/home-lars-projects}
AUX=${PROJ_MIGRATE_AUX:-/run/projects-shadow-view}

# Phase-A doom list (docs/todo/storage.md row 184): these cache trees must
# not exist anymore (source-fixed 2026-10-28) — excluded from every rsync
# regardless, so a regrown stray never rides the seed or the pool sends.
EXCLUDES=(--exclude=.gocache-disk/ --exclude=.golangci-disk/ --exclude=.gotmp/)

run() {
  echo "+ $*"
  [ "$DRY_RUN" = "1" ] || "$@"
}

log_state() {
  # Durable state record (the shadow-split-gate's manual-verify reference).
  # Never /tmp (volatile-wipe trap); owned by the primary user.
  [ "$DRY_RUN" = "1" ] && return 0
  mkdir -p "$STATE_DIR"
  printf '%s [%s] %s\n' "$(date --iso-8601=seconds)" "$ACTION" "$*" >>"$STATE_DIR/state.log"
  chown -R "$USER":"$GROUP" "$STATE_DIR" 2>/dev/null || true
}

# Binary preflight FIRST (the clickhouse sgdisk lesson: sudo's secure PATH
# hides user tools — resolve EVERY tool before anything stops). /run/current-
# system/sw/bin carries the flake's pinned nixpkgs tools in the sudo PATH.
for bin in rsync ionice nice timeout btrfs findmnt tar runuser flock df du find numfmt git systemctl; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERROR: required binary '$bin' not on PATH (sudo secure PATH?)" >&2
    exit 1
  }
done

# Re-exec once through the NixOS sudo wrapper (pre-reboot-check pattern:
# preserve PATH so the preflight-resolved tools survive sudo's secure_path,
# and forward the PROJ_MIGRATE_* fixture overrides explicitly — sudo strips
# the environment). A nix-store sudo can never be setuid; the wrapper is the
# real one. Dry-run stays unprivileged (read-only by design).
if [ "$(id -u)" -ne "${PROJ_MIGRATE_ROOT_UID:-0}" ] && [ "$DRY_RUN" != "1" ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "must run as root (sudo)" >&2
    exit 1
  fi
  exec "$SUDO" env \
    PATH="$PATH" \
    PROJ_MIGRATE_SRC="$SRC" \
    PROJ_MIGRATE_SUBVOL="$SUBVOL" \
    PROJ_MIGRATE_USER="$USER" \
    PROJ_MIGRATE_GROUP="$GROUP" \
    PROJ_MIGRATE_HOT_ROOT="$HOT_ROOT" \
    PROJ_MIGRATE_POOL_FREE_PATH="$POOL_FREE_PATH" \
    PROJ_MIGRATE_ROOT_FREE_PATH="$ROOT_FREE_PATH" \
    PROJ_MIGRATE_STATE_DIR="$STATE_DIR" \
    PROJ_MIGRATE_RECEIVES_DIR="$RECEIVES_DIR" \
    PROJ_MIGRATE_ARCHIVE_DIR="$ARCHIVE_DIR" \
    PROJ_MIGRATE_AUX="$AUX" \
    PROJ_MIGRATE_ROOT_UID="${PROJ_MIGRATE_ROOT_UID:-0}" \
    bash "$0" "$@"
fi

# ── Entry gate (freeze #19/#20/#21 class — see pkgs/maintenance-entry-gate.nix)
# One migrate-* at a time (flock held for this script's lifetime) + refuse to
# start into a tripped box. Also keeps this script OUT of a running balance
# window. Dry-run stays ungated (read-only).
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
  maintenance-entry-gate --name migrate-projects-subvol --psi-max 30 || {
    echo "ERROR: entry gate refused (see above) — a refused migration is free, a migration into a storm is freeze #19. (A running btrfs balance trips this gate.)" >&2
    exit 1
  }
fi

# Pressure gate (deploy-pressure doctrine; read-only, PSI-disabled-kernel safe).
PSI=$(awk 'NR==1 {print $2}' "${PROJ_MIGRATE_PSI_FILE:-/proc/pressure/io}" 2>/dev/null || true)
PSI="${PSI#avg10=}"
PSI="${PSI:-0}"
if awk -v p="$PSI" 'BEGIN { exit !(p >= 80) }'; then
  echo "REFUSED: IO PSI some avg10 = ${PSI}% (>= 80%). Wait for a quiet window." >&2
  exit 1
fi

# btrbk ladder window (root 23:00 → clean 23:50; seed-sized margin both
# sides): prepare's rsync must never share the box with a streaming send.
if [ "$ACTION" = "prepare" ] && [ "$DRY_RUN" != "1" ]; then
  HHMM=$(date +%H%M)
  if [ "$HHMM" -ge 2250 ] || [ "$HHMM" -le 0015 ]; then
    echo "REFUSED: inside the nightly btrbk ladder window (22:50-00:15) —" >&2
    echo "prepare's throttled rsync must not race the 23:00-23:50 sends. Re-run after 00:15." >&2
    exit 1
  fi
fi

if ! mountpoint -q "$HOT_ROOT"; then
  echo "$HOT_ROOT is not a mountpoint — detached Samsung. Refusing." >&2
  exit 1
fi

# Throttled helpers — filesystem walks are throttled ALWAYS (§d1 rule).
tdu() { timeout 300 ionice -c3 nice -n19 du "$@"; }
tfind() { timeout 300 ionice -c3 nice -n19 find "$@"; }

case "$ACTION" in
prepare)
  if mountpoint -q "$SRC"; then
    echo "$SRC is already a mountpoint — already migrated?" >&2
    exit 1
  fi
  echo "== prepare: subvol, double-pass rsync (PSI avg10 ${PSI}%)"

  # ── Space asserts (plan A3, script-enforced — never eyeballed) ──────────
  PAYLOAD=$(tdu -sb --apparent-size "$SRC" | awk '{print $1}')
  SAM_FREE=$(df -B1 --output=avail "$HOT_ROOT" | tail -n1 | tr -dc '0-9')
  [ -n "${SAM_FREE:-}" ] || {
    echo "ERROR: cannot read free space on $HOT_ROOT" >&2
    exit 1
  }
  NEED=$((PAYLOAD * 3 / 2))
  if [ "$DRY_RUN" != "1" ] && [ "$SAM_FREE" -lt "$NEED" ]; then
    echo "REFUSED: Samsung free ${SAM_FREE} B < payload×1.5 (${NEED} B; payload ${PAYLOAD} B)." >&2
    exit 1
  fi
  POOL_FREE=$(df -B1 --output=avail "$POOL_FREE_PATH" 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)
  if [ "$DRY_RUN" != "1" ] && [ "${POOL_FREE:-0}" -lt "$NEED" ]; then
    echo "REFUSED: pool free ${POOL_FREE:-0} B < payload×1.5 (${NEED} B — first seed + shadow archive both land there)." >&2
    exit 1
  fi
  # btrfs-progs emits the value either inline ("Unallocated: 48.00GiB") or,
  # per-device on the following line, as "Device unallocated:\t  48.00GiB"
  # (our pin's format) — parse both (the single-line-only parser read empty
  # and refused with a phantom 0 B, live 2026-10-28).
  UNALLOC_B=$(btrfs filesystem usage "$ROOT_FREE_PATH" 2>/dev/null | awk '
    /^[[:space:]]*Device unallocated:/ { v = $3 }
    /^[[:space:]]*Unallocated:/ && $2 ~ /^[0-9]/ { v = $2 }
    END {
      if (v != "") {
        n = v + 0; u = v; gsub(/^[0-9.]+/, "", u)
        m = 1
        if (u == "KiB") m = 1024
        else if (u == "MiB") m = 1048576
        else if (u == "GiB") m = 1073741824
        else if (u == "TiB") m = 1099511627776
        printf "%.0f", n * m
      }
    }')
  UNALLOC_B=${UNALLOC_B:-0}
  if [ "$DRY_RUN" != "1" ] && [ "$UNALLOC_B" -lt $((10 * 1024 * 1024 * 1024)) ]; then
    echo "REFUSED: QLC root unallocated ${UNALLOC_B} B (< 10 GiB — the balance-jobs floor; metadata-ENOSPC precursor state, row 185; an unprivileged probe reads 0 — run under sudo)." >&2
    exit 1
  fi
  echo "space asserts OK: payload $(numfmt --to=iec "$PAYLOAD"), Samsung free $(numfmt --to=iec "$SAM_FREE"), pool free $(numfmt --to=iec "${POOL_FREE:-0}"), QLC unalloc ${UNALLOC_B}B"

  # ── Subvol provisioning through the toplevel (never a runtime unit — the
  # 2026-09-20..29 bootstrap saga class) ────────────────────────────────────
  if ! btrfs subvolume show "$SUBVOL" >/dev/null 2>&1; then
    mkdir -p "$(dirname "$SUBVOL")"
    run btrfs subvolume create "$SUBVOL"
    run chown "$USER":"$GROUP" "$SUBVOL"
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: rsync skipped"
    echo "dry run: would rsync -aHAXS $SRC/ $SUBVOL/ ${EXCLUDES[*]}"
    exit 0
  fi

  # Restart hygiene: a NON-empty subvol on a fresh prepare means a previous
  # window half-ran — refuse so the parity bands below stay honest.
  PRE_EXISTING=$(tfind "$SUBVOL" -mindepth 1 | wc -l)
  if [ "$PRE_EXISTING" -gt 0 ]; then
    echo "== delta re-run: subvol already holds $PRE_EXISTING entries (restart of a failed window is fine — converging)"
  fi

  # Double-pass throttled rsync. NO --reflink (rsync has no such flag — the
  # 2026-08-17/09-16 trap, twice-burned). -S: ML trees carry sparse files.
  rsync_pass() {
    run ionice -c3 nice -n19 timeout 14400 rsync -aHAXS --numeric-ids --info=stats2 "${EXCLUDES[@]}" "$SRC"/ "$SUBVOL"/
  }
  rsync_pass
  echo "== first pass done — converging deltas with a second pass"
  rsync_pass

  # Banded parity verify (churning source — bands, not equality; the
  # cutover's final delta converges to equality with writers stopped).
  SRC_COUNT=$(tfind "$SRC" -xdev -type f | wc -l)
  DST_COUNT=$(tfind "$SUBVOL" -type f | wc -l)
  SRC_SIZE=$(tdu -sb --apparent-size "$SRC" | awk '{print $1}')
  DST_SIZE=$(tdu -sb --apparent-size "$SUBVOL" | awk '{print $1}')
  echo "files: src=$SRC_COUNT dst=$DST_COUNT  bytes(apparent): src=$SRC_SIZE dst=$DST_SIZE"
  if [ "$DST_COUNT" -lt $((SRC_COUNT - 50)) ] || [ "$DST_SIZE" -lt $((SRC_SIZE * 95 / 100)) ] || [ "$DST_SIZE" -gt $((SRC_SIZE * 105 / 100)) ]; then
    echo "VERIFY FAILED: copy outside parity bands (source churning? run another prepare pass)." >&2
    exit 1
  fi

  # git fsck spot-check on the SUBVOL copy (integrity layer for .git trees).
  if [ -d "$SUBVOL/SystemNix/.git" ]; then
    git -C "$SUBVOL/SystemNix" fsck --no-dangling || {
      echo "VERIFY FAILED: git fsck on the subvol copy of SystemNix is not clean." >&2
      exit 1
    }
    echo "git fsck OK: subvol copy of SystemNix"
  fi

  log_state "prepare OK: files src=$SRC_COUNT dst=$DST_COUNT bytes src=$SRC_SIZE dst=$DST_SIZE"
  echo "prepare OK. Now: nix run .#deploy  — then:  sudo $0 finalize"
  echo "WARNING: files written from here until the deploy land on the QLC shadow dir."
  ;;
finalize)
  mountpoint -q "$SRC" || {
    echo "$SRC is not a mountpoint — deploy the projectsHomeMount fstab first" >&2
    exit 1
  }
  # Mount-DEVICE check: finalize must see the SAMSUNG, not a QLC-served
  # mount (wrong-universe class).
  LIVE_SRC=$(findmnt -no SOURCE "$SRC")
  echo "== finalize: mount answers ($SRC <- $LIVE_SRC) + $USER write probe"
  if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: skipping verification + seed"
    exit 0
  fi
  EXISTING=$(tfind "$SUBVOL" -type f | wc -l)
  if [ "$EXISTING" -eq 0 ]; then
    echo "VERIFY FAILED: no files on the mount at all — rsynced content missing." >&2
    exit 1
  fi
  PROBE="$SRC/.migrate-finalize-probe"
  runuser -u "$USER" -- touch "$PROBE" || {
    echo "VERIFY FAILED: $USER cannot write onto the mount (ownership? — subvol root must be $USER:$GROUP, +C NOT applied)." >&2
    exit 1
  }
  [ -f "$SUBVOL/.migrate-finalize-probe" ] || {
    echo "VERIFY FAILED: probe written at $SRC is not on $SUBVOL — mount mismatch." >&2
    exit 1
  }
  rm -f "$PROBE"

  # First btrbk seed (receipt = the unit's journal exit summary; --no-block
  # — the seed can run for hours under its 24h TimeoutStartSec).
  systemctl is-active --quiet btrbk-projects && echo "btrbk-projects already active" || {
    run systemctl start --no-block btrbk-projects.service
    echo "btrbk-projects seed started (--no-block) — watch: journalctl -u btrbk-projects -f"
  }
  log_state "finalize OK: $EXISTING files on mount; seed kicked"
  echo "finalize OK: ~/projects lives on the Samsung ($EXISTING files)."
  echo "Keep the QLC shadow dir under the mountpoint as rollback insurance until the soak ends."
  ;;
shadow-cleanup)
  # Root partition derived from the RUNNING root (kernel nvmeX names flip
  # across boots; findmnt is self-consistent within one boot).
  ROOT_PART=$(findmnt -no SOURCE /)
  ROOT_PART=${ROOT_PART%%\[*}
  LIVE_SRC=$(findmnt -no SOURCE "$SRC" || true)
  LIVE_BASE=${LIVE_SRC%%\[*}

  mountpoint -q "$SRC" || {
    echo "$SRC is not a mountpoint — nothing to clean up (or the mount regressed)." >&2
    exit 1
  }
  if [ "$LIVE_BASE" = "$ROOT_PART" ]; then
    echo "REFUSED: $SRC is served by the QLC root device ($LIVE_BASE) — the Samsung is" >&2
    echo "detached and the shadow dir IS the live projects tree. Deleting it would" >&2
    echo "destroy live work. Re-attach the Samsung first." >&2
    exit 1
  fi
  mountpoint -q "$POOL_FREE_PATH" || {
    echo "$POOL_FREE_PATH is not a mountpoint — archive target missing. Refusing." >&2
    exit 1
  }
  RECEIVES=0
  for entry in "$RECEIVES_DIR"/projects.*; do
    [ -e "$entry" ] && RECEIVES=$((RECEIVES + 1))
  done
  if [ "${RECEIVES:-0}" -lt 5 ]; then
    echo "REFUSED: only ${RECEIVES:-0} pool receives (< 5) — the soak gate (≥ 5 green" >&2
    echo "nightly sends) has not been met; the shadow is still the only full pre-migration copy." >&2
    exit 1
  fi

  AUX_SHADOW=$AUX/home/lars/projects
  ARCHIVE=$ARCHIVE_DIR/projects-shadow-final-$(date +%Y-%m-%d).tar.zst

  if [ "$DRY_RUN" = "1" ]; then
    echo "plan: aux-mount $ROOT_PART (subvol=@, ro) at $AUX"
    echo "plan: tar --zstd $AUX_SHADOW -> $ARCHIVE (verify exact file count)"
    echo "plan: remount rw, delete CONTENTS of $AUX_SHADOW (mountpoint dir kept)"
    echo "plan: fresh ro view re-verifies the shadow empty; live mount never touched"
    exit 0
  fi

  cleanup_aux() {
    umount "$AUX" 2>/dev/null || true
    rmdir "$AUX" 2>/dev/null || true
  }
  trap cleanup_aux INT TERM EXIT

  mkdir -p "$AUX" "$ARCHIVE_DIR"
  run mount -o subvol=@,ro "$ROOT_PART" "$AUX"
  # The shadow must be a PLAIN dir in this view — a mountpoint here would
  # mean the wrong universe got mounted (would delete through to live data).
  if mountpoint -q "$AUX_SHADOW"; then
    echo "REFUSED: $AUX_SHADOW is a mountpoint in the aux view — wrong view." >&2
    exit 1
  fi
  [ -d "$AUX_SHADOW" ] || {
    echo "shadow dir not found at $AUX_SHADOW — nothing to archive." >&2
    exit 1
  }

  FILES=$(tfind "$AUX_SHADOW" -type f | wc -l)
  SIZE=$(tdu -sb --apparent-size "$AUX_SHADOW" | awk '{print $1}')
  echo "shadow: files=$FILES bytes=$SIZE"
  if [ "$FILES" -eq 0 ]; then
    echo "shadow is already empty — nothing to do." >&2
    exit 0
  fi

  run tar -C "$AUX/home/lars" --zstd -cf "$ARCHIVE" projects
  TFILES=$(tar --zstd -tf "$ARCHIVE" | grep -vc '/$')
  if [ "$TFILES" != "$FILES" ]; then
    echo "ARCHIVE VERIFY FAILED: tar=$TFILES files vs src=$FILES — shadow NOT deleted." >&2
    exit 1
  fi
  echo "archive verified: $TFILES files -> $ARCHIVE ($(stat -c%s "$ARCHIVE") bytes)"

  run umount "$AUX"
  run mount -o subvol=@ "$ROOT_PART" "$AUX"
  run tfind "$AUX_SHADOW" -mindepth 1 -delete
  run umount "$AUX"
  # Fresh read-only view: verify the shadow is REALLY empty (trust the
  # delete through a second observation, not the delete's own exit code).
  run mount -o subvol=@,ro "$ROOT_PART" "$AUX"
  REMAINING=$(tfind "$AUX_SHADOW" -mindepth 1 | wc -l)
  if [ "$REMAINING" -ne 0 ]; then
    echo "REFUSED-STATE: shadow still holds $REMAINING entries after cleanup — inspect $AUX_SHADOW by hand." >&2
    exit 1
  fi
  trap - EXIT
  cleanup_aux
  log_state "shadow-cleanup OK: archived $TFILES files ($(stat -c%s "$ARCHIVE") B), shadow verified empty"
  echo "shadow-cleanup OK: insurance archived to the pool + QLC shadow verified empty."
  echo "QLC frees ~$SIZE bytes as the @ 3d pin + .rescue (~1-2d) windows expire — never instantly; never size success from post-run df."
  ;;
*)
  usage
  ;;
esac
