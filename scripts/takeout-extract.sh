#!/usr/bin/env bash
# takeout-extract.sh - member-scoped extractor for a verified Google Takeout
# staging root (fleet plan X1:
# docs/planning/2026-11-13_19-27_takeout-fleet-completion-and-immich-key-converger.md).
#
# Contract:
#   - ONLY members rooted at Takeout/ are ever extracted (the default scope is
#     'Takeout/*'); --members patterns are unzip-style globs (* matches "/"
#     too) and MUST start with 'Takeout/'.
#   - Reuses logs/zip-entries.tsv (written by takeout-verify.sh G2.2) when
#     present, so the pipeline reads each zip's listing ONCE; regenerates the
#     listing only when absent. --dry-run never writes anything (not even the
#     listing): the listing goes to a temp file.
#   - Capacity gate BEFORE any write: free bytes on the destination filesystem
#     must be >= extract bytes * (1 + MARGIN_PCT/100) + HEADROOM.
#   - unzip exit code 11 (pattern matched nothing in THIS zip) is a skip,
#     never a failure: products span only a subset of the parts.
#   - Fail-closed reconciliation: the on-disk file set under the pattern roots
#     must EXACTLY equal the expected member set (missing AND extra both
#     fail), and total bytes must match. Zero matched members is never a pass.
#   - NOTHING here deletes or ingests; the zips stay ground truth (extract-
#     first doctrine). Run takeout-verify.sh (Gate G2) before trusting a root.
#
# Usage:
#   bash scripts/takeout-extract.sh <staging-dir> [--members 'Takeout/Google Photos/*']...
#          [--dest DIR] [--dry-run]
#   bash scripts/takeout-extract.sh --selftest
#
# Env overrides (selftest knobs; defaults are the fleet capacity rule):
#   TAKEOUT_EXTRACT_HEADROOM_BYTES  default 536870912000 (500 GiB)
#   TAKEOUT_EXTRACT_MARGIN_PCT      default 20 (i.e. need >= 1.2x extract)
#
# Exit codes: 0 = clean; 1 = usage / hard error; 2 = capacity gate, zip
# failure, or reconciliation failure (nothing downstream may proceed).
set -euo pipefail

die() {
  echo "takeout-extract: ERROR: $*" >&2
  exit 1
}
log() { echo "[$(date '+%F %T')] $*"; }

usage() {
  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# --- listing: reuse logs/zip-entries.tsv (verify's format: len<TAB>name,
# directory entries skipped); regenerate only when absent. DRY_RUN=1 keeps the
# regenerated listing in a temp file that run_main cleans up.
LISTING=
LISTING_TMP=
prepare_listing() {
  local root=$1 zip persistent
  persistent=$root/logs/zip-entries.tsv
  if [ -s "$persistent" ]; then
    LISTING=$persistent
    log "listing reused: $persistent (zips not re-listed)"
    return 0
  fi
  LISTING_TMP=$(mktemp)
  : >"$LISTING_TMP"
  for zip in "$root"/zips/*.zip; do
    [ -f "$zip" ] || continue
    unzip -l "$zip" | awk '
      NF >= 4 && $1 ~ /^[0-9]+$/ && $4 != "" {
        name = substr($0, index($0, $4))
        if (name !~ /\/$/) printf "%s\t%s\n", $1, name
      }' >>"$LISTING_TMP" || die "cannot list $zip (corrupt zip? run takeout-verify.sh first)"
  done
  if [ "$DRY_RUN" = "1" ]; then
    LISTING=$LISTING_TMP
  else
    mkdir -p "$root/logs"
    mv "$LISTING_TMP" "$persistent"
    LISTING=$persistent
    log "listing regenerated -> $persistent (run takeout-verify.sh to also prove CRC integrity)"
  fi
}

# glob -> anchored awk regex; only * and ? are wildcards, everything else
# (dots, parens, spaces, brackets) matches literally. ERE metachars are
# escaped one-by-one: a bracket-class sed idiom proved fragile here.
glob_to_re() {
  printf '%s' "$1" |
    sed -e 's/\\/\\\\/g' -e 's/\*/@STAR@/g' -e 's/?/@QUEST@/g' \
      -e 's/\./\\./g' -e 's/\$/\\$/g' -e 's/\^/\\^/g' -e 's/\+/\\+/g' \
      -e 's/(/\\(/g' -e 's/)/\\)/g' -e 's/{/\\{/g' -e 's/}/\\}/g' \
      -e 's/\[/\\[/g' -e 's/\]/\\]/g' -e 's/|/\\|/g' \
      -e 's/@STAR@/.*/g' -e 's/@QUEST@/./g'
}

# Build the expected member set (patterns -> EXPECTED: name<TAB>size) and
# totals. Fails closed when nothing matches.
EXPECTED=
EXP_COUNT=0
EXP_BYTES=0
build_expected() {
  local patfile totals
  patfile=$(mktemp)
  local p
  for p in "${PATTERNS[@]}"; do printf '%s\n' "$(glob_to_re "$p")" >>"$patfile"; done
  EXPECTED=$(mktemp)
  totals=$(mktemp)
  awk -F'\t' -v OFS='\t' -v out="$EXPECTED" '
    NR == FNR { pats[++np] = "^" $0 "$"; next }
    {
      for (i = 1; i <= np; i++)
        if ($2 ~ pats[i]) {
          if (!($2 in seen)) {
            seen[$2] = 1
            print $2, $1 >> out
            cnt++
            bytes += $1
          }
          break
        }
    }
    END { printf "%d\t%d\n", cnt + 0, bytes + 0 > "/dev/stderr" }
  ' "$patfile" "$LISTING" 2>"$totals"
  read -r EXP_COUNT EXP_BYTES <"$totals"
  rm -f "$patfile" "$totals"
  [ "$EXP_COUNT" -gt 0 ] || {
    echo "takeout-extract: ERROR: no members matched the given patterns (${PATTERNS[*]}) - wrong scope or wrong staging root" >&2
    exit 2
  }
}

# First existing ancestor of $1 (df targets must exist).
df_target() {
  local t=$1
  while [ ! -e "$t" ]; do t=$(dirname "$t"); done
  printf '%s' "$t"
}

capacity_gate() {
  # resolved HERE (not at startup) so per-invocation env overrides work
  local headroom=${TAKEOUT_EXTRACT_HEADROOM_BYTES:-536870912000}
  local margin_pct=${TAKEOUT_EXTRACT_MARGIN_PCT:-20}
  local dest=$1 free need
  free=$(df -B1 --output=avail "$(df_target "$dest")" | tail -1)
  need=$((EXP_BYTES + EXP_BYTES * margin_pct / 100 + headroom))
  log "capacity: need >= $need bytes ($EXP_BYTES extract + ${margin_pct}% margin + $headroom headroom), free: $free bytes"
  if [ "$free" -lt "$need" ]; then
    echo "takeout-extract: ERROR: CAPACITY INSUFFICIENT - free $free < required $need; free space or narrow --members" >&2
    exit 2
  fi
}

# Pattern roots (prefix before the first wildcard; dirname for literal
# patterns): the reconciliation walk is bounded to these directories so a
# previously extracted OTHER product under extracted/Takeout/ never counts as
# "extra" for this run.
pattern_roots() {
  local p r
  for p in "${PATTERNS[@]}"; do
    r=${p%%\**}
    if [ "$r" = "$p" ]; then r=$(dirname "$p"); fi
    r=${r%/}
    printf '%s\n' "$r"
  done | LC_ALL=C sort -u
}

run_extract() {
  local root=$1 dest=$2 zip zlog rc failed=0 skipped=0
  mkdir -p "$dest"
  for zip in "$root"/zips/*.zip; do
    [ -f "$zip" ] || continue
    zlog=$root/logs/extract-$(basename "$zip").log
    if unzip -o -qq "$zip" "${PATTERNS[@]}" -d "$dest" >"$zlog" 2>&1; then
      log "extracted $(basename "$zip")"
    else
      rc=$?
      if [ "$rc" -eq 11 ]; then
        skipped=$((skipped + 1))
        log "skip $(basename "$zip") (rc 11: no matching members)"
      else
        failed=$((failed + 1))
        echo "takeout-extract: ERROR: $(basename "$zip") failed with unzip rc=$rc (see $zlog)" >&2
      fi
    fi
  done
  log "unzip pass done: failures=$failed, no-member skips=$skipped"
  if [ "$failed" -gt 0 ]; then
    echo "takeout-extract: ERROR: EXTRACT FAILED - $failed zip(s) errored; extracted tree is INCOMPLETE, do not import" >&2
    exit 2
  fi
}

# Exact-set + byte reconciliation against the listing expectation.
reconcile() {
  local dest=$1 diskset expset r missing extra disk_count disk_bytes
  diskset=$(mktemp)
  expset=$(mktemp)
  cut -f1 "$EXPECTED" | LC_ALL=C sort >"$expset"
  : >"$diskset"
  while IFS= read -r r; do
    (cd "$dest" && find "$r" -type f -printf '%p\n' 2>/dev/null) >>"$diskset" || true
  done < <(pattern_roots)
  LC_ALL=C sort -o "$diskset" "$diskset"
  missing=$(comm -23 "$expset" "$diskset" | wc -l)
  extra=$(comm -13 "$expset" "$diskset" | wc -l)
  disk_count=$(wc -l <"$diskset")
  disk_bytes=$(
    while IFS= read -r r; do
      (cd "$dest" && find "$r" -type f -printf '%s\n' 2>/dev/null)
    done < <(pattern_roots) | awk '{ s += $1 } END { printf "%.0f", s + 0 }'
  )
  rm -f "$diskset" "$expset"
  log "reconcile: expected $EXP_COUNT files / $EXP_BYTES bytes; disk $disk_count files / $disk_bytes bytes (missing $missing, extra $extra)"
  if [ "$missing" -gt 0 ] || [ "$extra" -gt 0 ] || [ "$disk_bytes" -ne "$EXP_BYTES" ]; then
    echo "takeout-extract: ERROR: RECONCILE FAILED - missing $missing, extra $extra, bytes disk=$disk_bytes vs expected=$EXP_BYTES; do not import" >&2
    exit 2
  fi
  log "RECONCILE: OK ($EXP_COUNT files / $EXP_BYTES bytes exact)"
}

run_main() {
  local root=$1 dest p
  dest=${DEST:-$1/extracted}
  [ -d "$root/zips" ] || die "no $root/zips staging root (takeout-download.sh init first)"
  ls "$root"/zips/*.zip >/dev/null 2>&1 || die "no zips under $root/zips (both part-NN.zip and raw browser takeout-*.zip names are accepted)"
  for p in "${PATTERNS[@]}"; do
    case $p in
    Takeout/*) ;;
    *) die "--members pattern must be rooted at Takeout/ (got: $p)" ;;
    esac
  done
  prepare_listing "$root"
  build_expected
  log "scope: ${PATTERNS[*]} -> $EXP_COUNT members / $EXP_BYTES bytes"
  capacity_gate "$dest"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY-RUN extract: $EXP_COUNT members / $EXP_BYTES bytes (patterns: ${PATTERNS[*]})"
    echo "DRY-RUN: capacity OK, nothing written"
    [ -n "$LISTING_TMP" ] && rm -f "$LISTING_TMP"
    return 0
  fi
  run_extract "$root" "$dest"
  reconcile "$dest"
  {
    echo "# takeout-extract report $(date '+%F %T')"
    printf 'patterns\tfiles\tbytes\n'
    printf '%s\t%s\t%s\n' "${PATTERNS[*]}" "$EXP_COUNT" "$EXP_BYTES"
  } >"$root/logs/extract-report.tsv"
  log "EXTRACT: OK - $EXP_COUNT files / $EXP_BYTES bytes -> $dest"
  log "next: takeout-dedup.sh index --from-extract $dest --account <acct> --cycle <YYYY-MM-DD>, then plan, then 'balance --preflight'"
}

# --- selftest (hermetic fixtures under XDG_CACHE_HOME; needs zip + unzip) ---
selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-extract-selftest
  local rc=0 leg
  rm -rf "$fx"
  mkdir -p "$fx"
  # the 500 GiB fleet headroom would fail every real-run leg on a small test
  # filesystem; pin it tiny here (the capacity-block leg overrides it to huge)
  export TAKEOUT_EXTRACT_HEADROOM_BYTES=1024

  build_fixture() {
    rm -rf "$fx"/zips "$fx/logs" "$fx/extracted"
    mkdir -p "$fx"/zips "$fx/logs"
    (
      cd "$fx" &&
        mkdir -p tk/Takeout/Drive tk/'Takeout/Google Photos' tk/Takeout/Mail &&
        printf 'pdf-a\n' >'tk/Takeout/Drive/a file.pdf' &&
        printf 'pdf-b\n' >tk/Takeout/Drive/b.pdf &&
        printf 'imgjpg\n' >'tk/Takeout/Google Photos/IMG_0001.jpg' &&
        printf '{}\n' >'tk/Takeout/Google Photos/IMG_0001.jpg.json' &&
        printf 'hello\n' >tk/Takeout/Mail/mbox.txt &&
        (cd tk && zip -qr "$fx/zips/part-01.zip" Takeout/Drive 'Takeout/Google Photos') &&
        (cd tk && zip -qr "$fx/zips/part-02.zip" Takeout/Mail) &&
        rm -rf tk
    )
  }
  # 5 members / 28 bytes total (Takeout/*); Drive alone = 2 files / 12 bytes.
  # Every call is a SUBSHELL with plain assignments: run_main's die()/exit-2
  # on negative legs must never kill the selftest driver, and array variables
  # cannot ride an env-prefix assignment (PATTERNS=(...) cmd is a syntax
  # error) - set them as statements instead.

  leg=dry-run-no-write
  build_fixture
  if (PATTERNS=('Takeout/*'); DRY_RUN=1; run_main "$fx") >"$fx/leg-$leg.log" 2>&1 &&
    grep -q 'DRY-RUN extract: 5 members / 28 bytes' "$fx/leg-$leg.log" &&
    [ ! -e "$fx/extracted" ] && [ ! -s "$fx/logs/zip-entries.tsv" ]; then
    echo "PASS: $leg (totals correct, zero writes, listing not persisted)"
  else
    echo "FAIL: $leg (see $fx/leg-$leg.log)"
    rc=1
  fi

  leg=capacity-block
  build_fixture
  if (PATTERNS=('Takeout/*'); DRY_RUN=1; export TAKEOUT_EXTRACT_HEADROOM_BYTES=999999999999999; run_main "$fx") >"$fx/leg-$leg.log" 2>&1; then
    echo "FAIL: $leg (huge headroom passed)"
    rc=1
  elif grep -q 'CAPACITY INSUFFICIENT' "$fx/leg-$leg.log" &&
    [ ! -e "$fx/extracted" ] && [ ! -s "$fx/logs/zip-entries.tsv" ]; then
    echo "PASS: $leg (gate blocks before any write, exit 2)"
  else
    echo "FAIL: $leg (wrong failure mode - see $fx/leg-$leg.log)"
    rc=1
  fi

  leg=members-root-guard
  build_fixture
  if (PATTERNS=('Drive/*'); DRY_RUN=1; run_main "$fx") >"$fx/leg-$leg.log" 2>&1; then
    echo "FAIL: $leg (unrooted pattern accepted)"
    rc=1
  elif grep -q 'rooted at Takeout/' "$fx/leg-$leg.log"; then
    echo "PASS: $leg (unrooted pattern refused)"
  else
    echo "FAIL: $leg (wrong failure mode - see $fx/leg-$leg.log)"
    rc=1
  fi

  leg=extract-happy
  build_fixture
  if (PATTERNS=('Takeout/*'); run_main "$fx") >"$fx/leg-$leg.log" 2>&1 &&
    grep -q 'EXTRACT: OK - 5 files / 28 bytes' "$fx/leg-$leg.log" &&
    grep -q 'pdf-a' "$fx/extracted/Takeout/Drive/a file.pdf" &&
    grep -q 'RECONCILE: OK' "$fx/leg-$leg.log" &&
    [ -s "$fx/logs/extract-report.tsv" ]; then
    echo "PASS: $leg (full-scope extract + exact reconciliation)"
  else
    echo "FAIL: $leg (see $fx/leg-$leg.log)"
    rc=1
  fi

  leg=member-scope
  build_fixture
  if (PATTERNS=('Takeout/Drive/*'); run_main "$fx") >"$fx/leg-$leg.log" 2>&1 &&
    grep -q 'EXTRACT: OK - 2 files / 12 bytes' "$fx/leg-$leg.log" &&
    [ -f "$fx/extracted/Takeout/Drive/b.pdf" ] &&
    [ ! -e "$fx/extracted/Takeout/Mail" ] &&
    [ ! -e "$fx/extracted/Takeout/Google Photos" ]; then
    echo "PASS: $leg (only Drive extracted, other products untouched)"
  else
    echo "FAIL: $leg (see $fx/leg-$leg.log)"
    rc=1
  fi

  leg=rc11-skip
  if grep -q 'skip part-02.zip (rc 11: no matching members)' "$fx/leg-member-scope.log"; then
    echo "PASS: $leg (Mail-only zip skipped, not a failure)"
  else
    echo "FAIL: $leg (see $fx/leg-member-scope.log)"
    rc=1
  fi

  leg=corrupt-zip-fail
  build_fixture
  (PATTERNS=('Takeout/*'); run_main "$fx") >/dev/null 2>&1 || true
  truncate -s 40 "$fx/zips/part-02.zip"
  rm -rf "$fx/extracted"
  if (PATTERNS=('Takeout/*'); run_main "$fx") >"$fx/leg-$leg.log" 2>&1; then
    echo "FAIL: $leg (corrupt zip passed)"
    rc=1
  elif grep -q 'EXTRACT FAILED' "$fx/leg-$leg.log" && grep -q 'part-02.zip' "$fx/leg-$leg.log"; then
    echo "PASS: $leg (corrupt zip fails closed, exit 2, no import)"
  else
    echo "FAIL: $leg (wrong failure mode - see $fx/leg-$leg.log)"
    rc=1
  fi

  leg=reconcile-extra-fail
  build_fixture
  (PATTERNS=('Takeout/*'); run_main "$fx") >/dev/null 2>&1 || true
  printf 'stray\n' >"$fx/extracted/Takeout/Mail/stray.txt"
  if (PATTERNS=('Takeout/*'); run_main "$fx") >"$fx/leg-$leg.log" 2>&1; then
    echo "FAIL: $leg (stray extra file passed)"
    rc=1
  elif grep -q 'RECONCILE FAILED' "$fx/leg-$leg.log" && grep -q 'extra 1' "$fx/leg-$leg.log"; then
    echo "PASS: $leg (stray on-disk file fails the exact-set reconciliation)"
  else
    echo "FAIL: $leg (wrong failure mode - see $fx/leg-$leg.log)"
    rc=1
  fi

  leg=listing-reuse
  build_fixture
  (PATTERNS=('Takeout/*'); run_main "$fx") >/dev/null 2>&1 || true
  touch -d '@946684800' "$fx/logs/zip-entries.tsv"
  if (PATTERNS=('Takeout/*'); run_main "$fx") >"$fx/leg-$leg.log" 2>&1 &&
    [ "$(stat -c %Y "$fx/logs/zip-entries.tsv")" = "946684800" ]; then
    echo "PASS: $leg (zip-entries.tsv reused, zips not re-listed)"
  else
    echo "FAIL: $leg (listing was regenerated - see $fx/leg-$leg.log)"
    rc=1
  fi

  if [ "$rc" -eq 0 ]; then
    rm -rf "$fx"
    echo "SELFTEST GREEN"
  else
    echo "SELFTEST RED (fixture kept at $fx for inspection)"
  fi
  return "$rc"
}

PATTERNS=()
DRY_RUN=0
DEST=

main() {
  if [ "${1:-}" = "--selftest" ]; then
    command -v zip >/dev/null || die "selftest needs zip on PATH (nix shell nixpkgs#zip)"
    command -v unzip >/dev/null || die "selftest needs unzip on PATH"
    selftest
    return
  fi
  local root=""
  while [ $# -gt 0 ]; do
    case $1 in
    --members)
      shift
      [ $# -gt 0 ] || die "--members needs a pattern argument (e.g. 'Takeout/Google Photos/*')"
      PATTERNS+=("$1")
      ;;
    --members=*) PATTERNS+=("${1#*=}") ;;
    --dest)
      shift
      [ $# -gt 0 ] || die "--dest needs a directory argument"
      DEST=$1
      ;;
    --dest=*) DEST=${1#*=} ;;
    --dry-run) DRY_RUN=1 ;;
    -h | --help) usage ;;
    -*) die "unknown option: $1" ;;
    *)
      [ -z "$root" ] || die "unexpected argument: $1"
      root=$1
      ;;
    esac
    shift
  done
  [ -n "$root" ] || die "usage: $0 <staging-dir> [--members 'Takeout/<product>/*'] [--dest DIR] [--dry-run] | --selftest"
  [ "${#PATTERNS[@]}" -gt 0 ] || PATTERNS=('Takeout/*')
  run_main "$root"
}

main "$@"
