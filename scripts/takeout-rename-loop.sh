#!/usr/bin/env bash
# takeout-rename-loop.sh — generic wrapper that folds owner-browser-downloaded
# Takeout parts into part-NN.zip every cycle until the export is complete.
#
# Generalizes the hardcoded racedriver8k loop in ~/.cache/takeout-probe/
# (kept alive there until the owner's rapt window for that export closes):
# staging root is an argument and the expected part count is read from the
# root's parts.tsv, so any fleet account can run it unchanged.
#
# Usage:
#   bash scripts/takeout-rename-loop.sh <staging-root> [--interval SEC]
#                                       [--timeout SEC] [--once] [--selftest]
#
#   default: fold every --interval seconds (default 300) until parts.tsv is
#   fully present as part-NN.zip, then exit 0. --once runs a single fold pass
#   and exits nonzero unless complete. --timeout caps total wall time (exit 1
#   with a diagnostic on expiry). Progress logs to <root>/logs/rename-loop.log.
#   The fold itself is scripts/takeout-browser-rename.sh --apply (exact-size
#   + CRC verified; CRC failures drop a marker file and never rename).
set -uo pipefail

die() {
  echo "takeout-rename-loop: ERROR: $*" >&2
  exit 1
}

REPO=$(cd "$(dirname "$0")/.." && pwd)
RENAME=${TAKEOUT_RENAME:-$REPO/scripts/takeout-browser-rename.sh}
[ -f "$RENAME" ] || RENAME=$(cd "$(dirname "$0")" && pwd)/takeout-browser-rename.sh

expected_count() {
  awk 'NF && $1 !~ /^#/ { n++ } END { print n + 0 }' "$1/parts.tsv"
}

present_count() {
  local root=$1 n
  n=$(find "$root/zips" -maxdepth 1 -name 'part-[0-9][0-9].zip' 2>/dev/null | wc -l)
  echo "$n"
}

loop() {
  local root=$1 interval=$2 timeout=${3:-0} once=${4:-0}
  local start=$SECONDS expected
  expected=$(expected_count "$root")
  [ "$expected" -ge 1 ] || die "parts.tsv in $root has no part rows"
  mkdir -p "$root/logs"
  local log=$root/logs/rename-loop.log
  echo "[$(date '+%F %T')] rename-loop start: root=$root expected=$expected interval=${interval}s timeout=${timeout}s once=$once" >>"$log"

  while :; do
    bash "$RENAME" "$root" --apply >>"$log" 2>&1
    local n
    n=$(present_count "$root")
    echo "[$(date '+%F %T')] parts complete: $n/$expected" >>"$log"
    if [ "$n" -ge "$expected" ]; then
      echo "[$(date '+%F %T')] ALL $expected PRESENT — G1 green; next: takeout-verify.sh (G2)" >>"$log"
      echo "ALL $expected PRESENT"
      return 0
    fi
    [ "$once" -eq 1 ] && return 1
    if [ "$timeout" -gt 0 ] && [ "$((SECONDS - start))" -ge "$timeout" ]; then
      echo "[$(date '+%F %T')] TIMEOUT after ${timeout}s at $n/$expected — parts still arriving? rerun to resume" >>"$log"
      echo "TIMEOUT at $n/$expected" >&2
      return 1
    fi
    sleep "$interval"
  done
}

selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-rename-loop-selftest
  local rc=0
  if ! command -v zip >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    echo "SELFTEST SKIP: needs zip + unzip on PATH"
    return 0
  fi
  check() { # name expected actual
    if [ "$2" = "$3" ]; then
      echo "leg $1: OK ($3)"
    else
      echo "leg $1: FAIL (expected '$2', got '$3')"
      rc=1
    fi
  }
  # fixture: 3 declared parts, sources present; optionally corrupt one in place
  mk_fixture() {
    rm -rf "$fx"
    mkdir -p "$fx/root"/{zips,src/Takeout/Drive}
    printf 'takeout payload for the rename-loop fixture\n' >"$fx/root/src/Takeout/Drive/a.txt"
    for i in 1 2 3; do
      (cd "$fx/root/src" && zip -qr "$fx/root/zips/Google-Takeout-$i.zip" Takeout/Drive)
    done
    {
      printf '# part\texpected-bytes\tfilename\n'
      for i in 1 2 3; do
        printf '%d\t%s\tGoogle-Takeout-%d.zip\n' "$i" "$(stat -c %s "$fx/root/zips/Google-Takeout-$i.zip")" "$i"
      done
    } >"$fx/root/parts.tsv"
  }
  export TAKEOUT_RENAME=$REPO/scripts/takeout-browser-rename.sh

  # leg 1: --once with everything already foldable completes on the first pass
  mk_fixture
  bash "$0" "$fx/root" --once >/dev/null 2>&1
  check once-complete 0 "$?"
  check once-complete-count 3 "$(present_count "$fx/root")"

  # leg 2: --once with a missing part exits nonzero without looping forever
  mk_fixture
  mv "$fx/root/zips/Google-Takeout-2.zip" "$fx/root/zips/still-arriving.bin"
  bash "$0" "$fx/root" --once >/dev/null 2>&1
  check once-incomplete-nonzero 1 "$?"

  # leg 3: the loop reaches completion within a bounded timeout (--interval 1)
  mk_fixture
  bash "$0" "$fx/root" --interval 1 --timeout 20 >/dev/null 2>&1
  check loop-completes 0 "$?"

  # leg 4: CRC-corruption fixture — a same-size corrupt part is caught by the
  # fold's unzip -t (marker dropped, never renamed) so the loop can NOT reach
  # its count and times out honestly instead of exiting green
  mk_fixture
  printf 'XXXX' | dd of="$fx/root/zips/Google-Takeout-2.zip" bs=1 seek=20 conv=notrunc status=none
  bash "$0" "$fx/root" --interval 1 --timeout 5 >/dev/null 2>&1
  check crc-corrupt-times-out 1 "$?"
  check crc-marker-dropped yes "$([ -f "$fx/root/zips/.crc-failed-Google-Takeout-2.zip" ] && echo yes || echo no)"
  check crc-part-not-renamed no "$([ -f "$fx/root/zips/part-02.zip" ] && echo yes || echo no)"
  check crc-log-names-corruption yes "$(grep -q 'CRC FAIL' "$fx/root/logs/rename-loop.log" && echo yes || echo no)"

  if [ "$rc" -eq 0 ]; then
    rm -rf "$fx"
    echo "SELFTEST GREEN"
  else
    echo "SELFTEST RED (fixture kept at $fx)"
  fi
  return "$rc"
}

main() {
  [ $# -gt 0 ] || {
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
  }
  case ${1:-} in
  --selftest) selftest ;;
  esac
  case ${1:-} in
  --selftest) exit $? ;;
  esac

  local root=${1:-} interval=300 timeout=0 once=0
  shift || true
  while [ $# -gt 0 ]; do
    case $1 in
    --interval)
      interval=$2
      shift 2
      ;;
    --timeout)
      timeout=$2
      shift 2
      ;;
    --once)
      once=1
      shift
      ;;
    *) die "unknown argument: $1" ;;
    esac
  done
  [ -n "$root" ] || die "staging root is required"
  [ -f "$root/parts.tsv" ] || die "no parts.tsv in $root (run takeout-download.sh <root> init first)"
  [ -f "$RENAME" ] || die "fold script missing: $RENAME"
  loop "$root" "$interval" "$timeout" "$once"
}

main "$@"
