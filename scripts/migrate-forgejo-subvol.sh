#!/usr/bin/env bash
# migrate-forgejo-subvol.sh — move /var/lib/forgejo (QLC @ root) onto the
# dedicated Samsung-TLC subvolume (subvol=hot/forgejo) that
# services.forgejo.dedicatedSubvolume mounts at the same path.
#
# Plan: docs/planning/2026-09-18_16-44_FORGEJO-PRIMARY-STAGED-FOUNDATION.md (gate G1)
#
# USAGE (root):
#   sudo ./scripts/migrate-forgejo-subvol.sh prepare            # live pre-rsync
#   sudo ./scripts/migrate-forgejo-subvol.sh finalize           # stop, delta, verify, swap
#   sudo ./scripts/migrate-forgejo-subvol.sh finalize --dry-run # print the plan only
#
# ORDER (all four steps):
#   0. Deploy the module code INERT (dedicatedSubvolume OFF) first.
#   1. `prepare`  — creates the subvol (idempotent) + LIVE pre-rsync (no --delete).
#   2. BUILD the next generation BEFORE finalize (see below), then `finalize` —
#      stops the forgejo family, delta rsync (--delete), verifies, renames the
#      QLC dir to a safety copy, leaves an empty mountpoint.
#   3. Enable `services.forgejo.dedicatedSubvolume = true;` (configuration.nix)
#      and `nix run .#deploy` — the mount activates, forgejo comes up on the subvol.
#   4. After burn-in: trash the safety copy /var/lib/forgejo.qlc-pre-subvol.
#
# WHY BUILD BEFORE FINALIZE: finalize deliberately leaves forgejo DOWN —
# restarting it before the mount is enabled would run against the EMPTY dir
# and mint fresh state. The deploy right after finalize must therefore be
# activation-quick:
#   nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel
#
# ABORT (if step 3 goes wrong before activation):
#   sudo rmdir /var/lib/forgejo        # the empty placeholder, if present
#   sudo mv /var/lib/forgejo.qlc-pre-subvol /var/lib/forgejo
#   sudo systemctl start forgejo
#
# Guards (verschlimmbessern defense):
#   - refuses `finalize` unless `prepare` ran (target non-empty)
#   - refuses `finalize` while any forgejo family unit is active
#   - verifies entry counts + apparent size + sampled checksums BEFORE renaming
#   - never deletes the source: rename-only, safety copy stays until burn-in
set -euo pipefail

# Env overrides exist ONLY for the fixture test (flake check
# migrate-forgejo-subvol-fixture); production runs never set them.
STATE_DIR="${MIGRATE_FORGEJO_STATE_DIR:-/var/lib/forgejo}"
SUBVOL="${MIGRATE_FORGEJO_SUBVOL:-/mnt/hot/hot/forgejo}"
SAFETY="${STATE_DIR}.qlc-pre-subvol"

# sudo's secure PATH hides user-profile tools — resolve every binary up front
# (the migrate-clickhouse-xfs sgdisk lesson), preferring the running system env.
resolve_tool() {
  local t="$1" c
  for c in "$(command -v "$t" 2>/dev/null || true)" \
    "/run/current-system/sw/bin/$t" \
    "/usr/bin/$t"; do
    if [ -n "$c" ] && [ -x "$c" ]; then
      printf '%s' "$c"
      return 0
    fi
  done
  echo "ERROR: required tool '$t' not found (PATH, /run/current-system/sw/bin, /usr/bin)" >&2
  exit 1
}

BTRFS=$(resolve_tool btrfs)
RSYNC=$(resolve_tool rsync)
SYSTEMCTL=$(resolve_tool systemctl)
FIND=$(resolve_tool find)
DU=$(resolve_tool du)
SHA256SUM=$(resolve_tool sha256sum)
SORT=$(resolve_tool sort)
WC=$(resolve_tool wc)

FAMILY_UNITS=(
  forgejo.service
  forgejo-github-sync.service
  forgejo-github-sync.timer
  forgejo-backup.service
  forgejo-backup.timer
  forgejo-generate-token.service
  forgejo-ssh-keys.service
)

die() { echo "ERROR: $*" >&2; exit 1; }

mount_check() {
  "$SYSTEMCTL" is-active --quiet mnt-hot.mount \
    || die "/mnt/hot is not mounted — forgejo-subvol-bootstrap needs it (Samsung present?)"
}

ensure_subvol() {
  mount_check
  if "$BTRFS" subvolume show "$SUBVOL" >/dev/null 2>&1; then
    echo "subvol already exists: $SUBVOL"
  else
    mkdir -p "$(dirname "$SUBVOL")"
    "$BTRFS" subvolume create "$SUBVOL"
    echo "created subvol: $SUBVOL"
  fi
  chown forgejo:forgejo "$SUBVOL"
  chmod 0750 "$SUBVOL"
}

cmd="${1:-}"
case "$cmd" in
  prepare)
    ensure_subvol
    echo "==> live pre-rsync (forgejo keeps running; no --delete)"
    # -H: hardlinks (git object store), -A/-X: ACLs/xattrs, --partial: resumable
    "$RSYNC" -aHAX --partial --info=stats1 "$STATE_DIR/" "$SUBVOL/"
    echo "==> prepare done. Next: build the toplevel, then: sudo $0 finalize"
    ;;

  finalize)
    dry_run="${2:-}"
    mount_check
    "$BTRFS" subvolume show "$SUBVOL" >/dev/null 2>&1 \
      || die "subvol $SUBVOL missing — run '$0 prepare' first"
    entries=$("$FIND" "$SUBVOL" -mindepth 1 | "$WC" -l)
    [ "$entries" -gt 5 ] || die "subvol has only $entries entries — run '$0 prepare' first"

    for u in "${FAMILY_UNITS[@]}"; do
      "$SYSTEMCTL" is-active --quiet "$u" && die "$u is still active — stop the family first (or re-run without units running)"
    done

    if [ "$dry_run" = "--dry-run" ]; then
      echo "DRY RUN: would stop family, delta-rsync $STATE_DIR → $SUBVOL (--delete), verify, then:"
      echo "  mv $STATE_DIR $SAFETY && mkdir $STATE_DIR"
      exit 0
    fi

    for u in "${FAMILY_UNITS[@]}"; do
      "$SYSTEMCTL" stop "$u" 2>/dev/null || true
    done

    echo "==> delta rsync (family stopped)"
    "$RSYNC" -aHAX --delete --info=stats1 "$STATE_DIR/" "$SUBVOL/"

    echo "==> verifying"
    src_n=$("$FIND" "$STATE_DIR" | "$WC" -l)
    dst_n=$("$FIND" "$SUBVOL" | "$WC" -l)
    [ "$src_n" -eq "$dst_n" ] || die "entry count mismatch: src=$src_n dst=$dst_n — NOT swapping"
    src_sz=$("$DU" -s --apparent-size "$STATE_DIR" | cut -f1)
    dst_sz=$("$DU" -s --apparent-size "$SUBVOL" | cut -f1)
    [ "$src_sz" -eq "$dst_sz" ] || die "apparent-size mismatch: src=$src_sz dst=$dst_sz — NOT swapping"

    # Deterministic sampled checksums: first 10 + every 1000th file.
    mapfile -t sample < <("$FIND" "$STATE_DIR" -type f -print0 | "$SORT" -z \
      | awk 'BEGIN{RS="\0"} NR<=10 || NR%1000==0 {print}')
    for f in "${sample[@]}"; do
      rel="${f#"$STATE_DIR"}"
      a=$("$SHA256SUM" "$STATE_DIR$rel" | cut -d' ' -f1)
      b=$("$SHA256SUM" "$SUBVOL$rel" | cut -d' ' -f1)
      [ "$a" = "$b" ] || die "checksum mismatch on $rel — NOT swapping"
    done
    echo "    $src_n entries, ${#sample[@]} sampled checksums: OK"

    echo "==> swapping source aside (rename-only, nothing deleted)"
    mv "$STATE_DIR" "$SAFETY"
    mkdir "$STATE_DIR"
    chown forgejo:forgejo "$STATE_DIR"
    chmod 0750 "$STATE_DIR"

    cat <<'NEXT'
==> finalize DONE. Forgejo is DOWN by design. The ONLY sanctioned next action:

  1. Edit configuration.nix: services.forgejo.dedicatedSubvolume = true;
  2. nix run .#deploy   (toplevel prebuilt — activation-quick)
  3. Verify: systemctl status forgejo; findmnt /var/lib/forgejo;
     gatus "Forgejo" + "Forgejo Mirror Sync" green; one mirror sync in the journal.
  4. After burn-in (≥2 btrbk legs + one mirror cycle): trash the safety copy:
       sudo trash /var/lib/forgejo.qlc-pre-subvol

ABORT (before activation): see header of this script.
NEXT
    ;;

  *)
    cat >&2 <<EOF
Usage: sudo $0 prepare | finalize [--dry-run]
Plan: docs/planning/2026-09-18_16-44_FORGEJO-PRIMARY-STAGED-FOUNDATION.md
EOF
    exit 1
    ;;
esac
