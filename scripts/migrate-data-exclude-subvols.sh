#!/usr/bin/env bash
# migrate-data-exclude-subvols — convert /data/ai, /data/SteamLibrary and
# /data/gcs-staging from plain directories into NESTED SUBVOLUMES so the
# btrbk-data "." snapshot (and any future pool send) EXCLUDES them.
# btrbk has no per-directory exclude; nested subvols are skipped by both
# `btrfs subvolume snapshot` and `btrfs send` (migrate-nix-subvol
# precedent). Owner doctrine 2026-11-03: NEVER pool-backup re-downloadable
# AI models (docs/status/2026-11-03_20-44_storage-decisions-purge-qa.md).
# Companion to the exclude-rot guard in scripts/btrbk-data-gate.sh
# (btrbk-data.service ExecStartPre): until this migration runs, the gate
# logs an EXCLUDE-ROT WARNING nightly while the EIO gate holds, and HARD-
# FAILS the send once /data/.repair-done exists (T-05).
#
# Zero data IO: the bulk copy is `cp -a --reflink=always` (extent-shared,
# metadata-only — rsync has NO --reflink flag). The OLD tree is kept as
# <name>.pre-subvol rollback insurance; it shares extents with the new
# subvol, so it costs ~nothing. After the soak window (default owner
# patience: a few days):
#   trash /data/<name>.pre-subvol
# (plain dirs — no root needed). Deleting it frees ~0 immediately BY
# DESIGN (the extents live on in the subvol copy).
#
# Runs UNPRIVILEGED (verified live 2026-11-03: subvol create needs only
# write perms on /data; subvol DELETE would need root but this script
# never deletes subvols). Gates itself on PSI (storm doctrine) and on
# Steam being closed (the library must be quiescent for exact parity
# verification). Idempotent: paths already subvolumes are skipped.
#
# Residue note: /data/.subvol-create-probe (empty subvol from the
# 2026-11-03 permission probe) needs root to delete —
#   sudo btrfs subvolume delete /data/.subvol-create-probe
#
# Usage: migrate-data-exclude-subvols.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
elif [ $# -gt 0 ]; then
  echo "usage: migrate-data-exclude-subvols.sh [--dry-run]" >&2
  exit 2
fi

psi() {
  awk -v which="$1" '
    $1 == "some" {
      for (i = 2; i <= NF; i++)
        if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); printf "%d", $i; exit }
    }' "/proc/pressure/$1"
}

io_psi=$(psi io)
cpu_psi=$(psi cpu)
[ "$io_psi" -lt 20 ] || { echo "refusing: IO PSI $io_psi >= 20 (storm doctrine — rerun in a calm window)" >&2; exit 1; }
[ "$cpu_psi" -lt 20 ] || { echo "refusing: CPU PSI $cpu_psi >= 20 (rerun in a calm window)" >&2; exit 1; }
if pgrep -x steam >/dev/null 2>&1; then
  echo "refusing: steam is running — close it first (library must be quiescent for parity verify)" >&2
  exit 1
fi

for name in ai SteamLibrary gcs-staging; do
  src="/data/$name"
  old="/data/$name.pre-subvol"
  if btrfs subvolume show "$src" >/dev/null 2>&1; then
    echo "SKIP $src (already a subvolume)"
    continue
  fi
  if [ -e "$old" ]; then
    echo "refusing $src: $old exists from an earlier attempt — inspect before rerunning" >&2
    exit 1
  fi
  echo "== $src"
  if [ "$DRY_RUN" = "1" ]; then
    echo "  dry-run: mv $src -> $old"
    echo "  dry-run: btrfs subvolume create $src"
    echo "  dry-run: ionice -c3 nice -n19 cp -a --reflink=always $old/. -> $src/"
    echo "  dry-run: verify exact file-count + apparent-size parity"
    continue
  fi
  mv "$src" "$old"
  btrfs subvolume create "$src"
  ionice -c3 nice -n19 cp -a --reflink=always "$old/." "$src/"
  old_n=$(find "$old" | wc -l)
  new_n=$(find "$src" | wc -l)
  if [ "$old_n" -ne "$new_n" ]; then
    echo "FAIL $src: file count $old_n (old) vs $new_n (new) — both trees kept; inspect $old vs $src" >&2
    exit 1
  fi
  old_b=$(du -sb --apparent-size "$old" | cut -f1)
  new_b=$(du -sb --apparent-size "$src" | cut -f1)
  if [ "$old_b" -ne "$new_b" ]; then
    echo "FAIL $src: apparent size $old_b (old) vs $new_b (new) — both trees kept; inspect" >&2
    exit 1
  fi
  echo "  OK: $new_n entries, $new_b bytes apparent — rollback insurance at $old (extent-shared)"
done

echo "done."
[ "$DRY_RUN" = "1" ] || echo "the btrbk-data-gate EXCLUDE-ROT warning clears on the next nightly run (23:30)."
