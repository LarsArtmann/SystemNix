#!/usr/bin/env bash
# hot-db-shadow-guard — the fresh-create refusal gate for hot-db-bootstrap
# (modules/nixos/services/hot-db.nix embeds this file via writeShellScript
# and consults it whenever an entry's hot/<name> subvolume is MISSING —
# fixture-tested by scripts/test-hot-db-guard.sh).
#
# WHY (the 2026-10-12 discordsync shadow-split): an entry deployed before
# scripts/migrate-hot-db.sh ever ran gets an EMPTY subvolume created and
# mounted OVER its live dataDir — the server then recreates a fresh DB and
# the real store hides behind the mountpoint. That split was caught only
# because a human ran prepare and read the refusal (docs/status/
# 2026-10-12_15-55_wave5-discordsync-hotdb-shadowsplit-recovery.md §d/§e).
#
# Contract (called ONLY when the subvolume does not exist yet — the
# bootstrap owns that precondition check):
#   exit 0 + "CREATE (…)": fresh subvol is safe (dataDir absent or empty,
#                         no migrate marker).
#   exit 1 + "REFUSE (…)" on stderr: the bootstrap SKIPS the create and
#                         keeps converging the healthy entries; the
#                         refused entry's mount then fails naturally
#                         (nonexistent subvol → mount unit failed →
#                         consumer condition-skips or deps-fails → the
#                         anchored hot_db_entry_mounted{name} Gatus check
#                         alerts). No shared-unit blast radius, and the
#                         live dataDir is never covered.
#
# Refusal classes:
#   - migrate marker present (hot/.migrate-state/<name>, written by
#     `cutover` AFTER its verified sync): the marker says the data already
#     moved into a subvol that no longer exists (partially wiped tier?) —
#     a fresh create would shadow-split whatever still sits below.
#   - dataDir NON-EMPTY (ls -A, dotfiles included): live data a fresh
#     subvol would cover — run migrate prepare+cutover, or clear it
#     deliberately; never blind-mount.
#   - dataDir unreadable or not a directory: fail-closed; a human inspects.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: hot-db-shadow-guard.sh <dataDir> <markerPath> <entryName>" >&2
  exit 2
fi

data_dir=$1
marker=$2
entry=$3

if [ -f "$marker" ]; then
  echo "REFUSE ($entry): migrate marker $marker exists but the hot/$entry subvolume is missing — a cutover claimed the data already moved; a fresh create could shadow-split whatever still sits below $data_dir. Inspect the tier and $data_dir, then re-run the wave." >&2
  exit 1
fi

if [ ! -e "$data_dir" ]; then
  echo "CREATE ($entry): dataDir $data_dir absent — fresh entry."
  exit 0
fi

if [ ! -d "$data_dir" ]; then
  echo "REFUSE ($entry): $data_dir exists but is not a directory — refusing to mount a fresh subvol over it." >&2
  exit 1
fi

# Readability first, then emptiness: an unreadable dir is fail-closed
# refuse, never a misread-as-empty CREATE (CAP_DAC_OVERRIDE covers the
# 0700-root dataDirs inside the bootstrap unit).
if ! ls -A "$data_dir" >/dev/null 2>&1; then
  echo "REFUSE ($entry): cannot read dataDir $data_dir — fail-closed; a fresh subvol could shadow-split unread data." >&2
  exit 1
fi

if [ -n "$(ls -A "$data_dir")" ]; then
  echo "REFUSE ($entry): dataDir $data_dir is non-empty with no migrate marker — creating + mounting a fresh subvol would shadow-split the live store (2026-10-12 discordsync class). Run scripts/migrate-hot-db.sh prepare + cutover $entry, or clear $data_dir deliberately." >&2
  exit 1
fi

echo "CREATE ($entry): dataDir $data_dir empty — fresh entry safe."
exit 0
