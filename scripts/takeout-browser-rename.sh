#!/usr/bin/env bash
# takeout-browser-rename.sh — fold browser-downloaded Takeout parts into the
# pipeline's part-NN.zip naming so takeout-download.sh status/start and
# takeout-verify.sh see them.
#
# Part of the Google account retirement pipeline (plan:
# docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md).
#
# When the owner's real browser downloads the parts (Google blocks every
# non-browser client — see plan intake log), files land in <staging>/zips
# under Google's export filenames (parts.tsv column 3). This maps each to
# part-NN.zip, verifying the EXACT expected byte size before promoting.
#
# Usage: bash scripts/takeout-browser-rename.sh <staging-root> [--apply]
#   default is a DRY RUN (reports, renames nothing); --apply renames +
#   chmods 600. Unmapped files and size mismatches are reported, never moved.
set -euo pipefail

root=${1:?usage: takeout-browser-rename.sh <staging-root> [--apply]}
apply=${2:-}
zips=$root/zips
[ -d "$zips" ] || { echo "no $zips"; exit 1; }

mapped=0
renamed=0
skipped=0
while IFS=$'\t' read -r part expected filename; do
  case $part in ''|'#'*) continue ;; esac
  src=$zips/$filename
  dst=$(printf '%s/part-%02d.zip' "$zips" "$part")
  mapped=$((mapped + 1))
  if [ -f "$dst" ]; then
    echo "part $part: already present as $(basename "$dst")"
    skipped=$((skipped + 1))
    continue
  fi
  if [ ! -f "$src" ]; then
    echo "part $part: MISSING (waiting for $filename)"
    continue
  fi
  size=$(stat -c %s "$src")
  if [ "$size" -ne "$expected" ]; then
    echo "part $part: SIZE MISMATCH $filename has $size, expected $expected — NOT renamed (still downloading?)"
    continue
  fi
  if [ "$apply" = "--apply" ]; then
    mv -f "$src" "$dst"
    chmod 600 "$dst"
    renamed=$((renamed + 1))
  fi
  echo "part $part: OK $filename ($size bytes)${apply:+ → renamed}"
done < "$root/parts.tsv"

echo "---"
echo "parts mapped: $mapped, already present: $skipped, renamed now: $renamed$([ "$apply" != "--apply" ] && echo ' (DRY RUN — pass --apply to rename)')"
for f in "$zips"/*; do
  [ -f "$f" ] || continue
  case $(basename "$f") in
    part-[0-9][0-9].zip|*.crdownload|*.part) ;;
    *) echo "unmapped leftover: $(basename "$f")" ;;
  esac
done
