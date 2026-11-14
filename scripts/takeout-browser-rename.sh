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
#   --selftest runs the synthetic fixture battery (no pool writes).
set -euo pipefail

# Selftest legs: dry-run, clean promote, SAME-SIZE corruption (the CRC leg —
# a truncated zip would be caught earlier as a size mismatch, so the fixture
# corrupts bytes in place), CRC-marker persistence, size mismatch, leftover.
selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-rename-selftest
  local rc=0 leg
  if ! command -v zip >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    echo "SELFTEST SKIP: needs zip + unzip on PATH"
    return 0
  fi
  check() { # name expected actual
    if [ "$2" = "$3" ]; then echo "leg $1: OK ($3)"; else
      echo "leg $1: FAIL (expected '$2', got '$3')"
      rc=1
    fi
  }
  mk_fixture() {
    rm -rf "$fx"
    mkdir -p "$fx/zips" "$fx/src/Takeout/Drive"
    printf 'takeout payload for the fold fixture\n' >"$fx/src/Takeout/Drive/a.txt"
    (cd "$fx/src" && zip -qr "$fx/zips/Google-Takeout-1.zip" Takeout/Drive)
    cp "$fx/zips/Google-Takeout-1.zip" "$fx/zips/Google-Takeout-2.zip"
    cp "$fx/zips/Google-Takeout-1.zip" "$fx/zips/Google-Takeout-3.zip"
    local s1 s2 s3
    s1=$(stat -c %s "$fx/zips/Google-Takeout-1.zip")
    s2=$(stat -c %s "$fx/zips/Google-Takeout-2.zip")
    s3=$(stat -c %s "$fx/zips/Google-Takeout-3.zip")
    {
      printf '# part\texpected-bytes\tfilename\n'
      printf '1\t%s\tGoogle-Takeout-1.zip\n' "$s1"
      printf '2\t%s\tGoogle-Takeout-2.zip\n' "$s2"
      # deliberately wrong expectation for part 3 (a still-downloading part)
      printf '3\t%s\tGoogle-Takeout-3.zip\n' "$((s3 + 1))"
    } >"$fx/parts.tsv"
  }

  leg=dryrun
  mk_fixture
  if bash "$0" "$fx" >"$fx/leg-dryrun.log" 2>&1 &&
    grep -q 'DRY RUN' "$fx/leg-dryrun.log" &&
    [ -f "$fx/zips/Google-Takeout-1.zip" ] && [ ! -f "$fx/zips/part-01.zip" ]; then
    echo "PASS: $leg (nothing renamed without --apply)"
  else
    echo "FAIL: $leg (see $fx/leg-dryrun.log)"
    rc=1
  fi

  leg=promote
  mk_fixture
  # corrupt part 2 IN PLACE (same size) so it reaches the CRC leg
  printf 'XXXX' | dd of="$fx/zips/Google-Takeout-2.zip" bs=1 seek=20 conv=notrunc status=none
  printf 'unmapped\n' >"$fx/zips/stray.bin"
  local want_size
  want_size=$(stat -c %s "$fx/zips/Google-Takeout-1.zip")
  bash "$0" "$fx" --apply >"$fx/leg-promote.log" 2>&1 || true
  check promote-part1-bytes "$want_size" "$(stat -c %s "$fx/zips/part-01.zip" 2>/dev/null || echo missing)"
  check promote-part1-mode 600 "$(stat -c %a "$fx/zips/part-01.zip")"
  if grep -q 'CRC FAIL' "$fx/leg-promote.log" && [ ! -f "$fx/zips/part-02.zip" ] &&
    [ -f "$fx/zips/.crc-failed-Google-Takeout-2.zip" ]; then
    echo "PASS: leg promote-part2-crc (same-size corruption caught, marker dropped, not renamed)"
  else
    echo "FAIL: leg promote-part2-crc (see $fx/leg-promote.log)"
    rc=1
  fi
  if grep -q 'SIZE MISMATCH' "$fx/leg-promote.log" && [ ! -f "$fx/zips/part-03.zip" ]; then
    echo "PASS: leg promote-part3-size (wrong byte count not renamed)"
  else
    echo "FAIL: leg promote-part3-size (see $fx/leg-promote.log)"
    rc=1
  fi
  if grep -q 'unmapped leftover: stray.bin' "$fx/leg-promote.log"; then
    echo "PASS: leg leftover-reported"
  else
    echo "FAIL: leg leftover-reported (see $fx/leg-promote.log)"
    rc=1
  fi

  leg=marker-persist
  bash "$0" "$fx" --apply >"$fx/leg-marker.log" 2>&1 || true
  if grep -q 'CRC PREVIOUSLY FAILED' "$fx/leg-marker.log"; then
    echo "PASS: $leg (no re-read of a known-bad part every cycle)"
  else
    echo "FAIL: $leg (see $fx/leg-marker.log)"
    rc=1
  fi

  if [ "$rc" -eq 0 ]; then
    rm -rf "$fx"
    echo "SELFTEST GREEN"
  else
    echo "SELFTEST RED (fixture kept at $fx)"
  fi
  return "$rc"
}

if [ "${1:-}" = "--selftest" ]; then
  selftest
  exit $?
fi

root=${1:?usage: takeout-browser-rename.sh <staging-root> [--apply]}
apply=${2:-}
zips=$root/zips
[ -d "$zips" ] || {
  echo "no $zips"
  exit 1
}

mapped=0
renamed=0
skipped=0
while IFS=$'\t' read -r part expected filename; do
  case $part in '' | '#'*) continue ;; esac
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
    # Size alone proves the download finished; CRC proves the bytes survived.
    # A 50 GB part is only tested once (post-fold it counts as present), so a
    # failed test drops a marker to avoid re-reading it every 5-min cycle.
    crc_marker=$zips/.crc-failed-$filename
    if [ -f "$crc_marker" ]; then
      echo "part $part: CRC PREVIOUSLY FAILED ($filename) — delete the file and download this part again"
      continue
    fi
    if ! unzip -t "$src" >/dev/null 2>&1; then
      : >"$crc_marker"
      echo "part $part: CRC FAIL $filename — zip test failed, NOT renamed (re-download this part)"
      continue
    fi
    rm -f "$crc_marker"
    mv -f "$src" "$dst"
    chmod 600 "$dst"
    renamed=$((renamed + 1))
  fi
  echo "part $part: OK $filename ($size bytes)${apply:+ → renamed}"
done <"$root/parts.tsv"

echo "---"
echo "parts mapped: $mapped, already present: $skipped, renamed now: $renamed$([ "$apply" != "--apply" ] && echo ' (DRY RUN — pass --apply to rename)')"
for f in "$zips"/*; do
  [ -f "$f" ] || continue
  case $(basename "$f") in
  part-[0-9][0-9].zip | *.crdownload | *.part) ;;
  *) echo "unmapped leftover: $(basename "$f")" ;;
  esac
done
