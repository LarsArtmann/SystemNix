#!/usr/bin/env bash
# takeout-download.sh — manifest-driven Google Takeout bulk downloader.
#
# Part of the Google account retirement pipeline (plan:
# docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md).
# Downloads the 23-part 880 GB export into a pool staging root with
# per-part resume, stall detection, and a size-band sanity gate. The REAL
# integrity gate is `scripts/takeout-verify.sh` (unzip CRC + product
# coverage) — sizes here only catch grossly wrong fetches before we burn
# link re-downloads.
#
# Usage:
#   bash scripts/takeout-download.sh <staging-dir> init     # write manifests (idempotent)
#   bash scripts/takeout-download.sh <staging-dir> start    # download/resume all missing parts
#   bash scripts/takeout-download.sh <staging-dir> status   # per-part size-band report
#
# Owner handoff (D3): place into the staging root BEFORE start:
#   urls.txt     23 download links, one per line, in Takeout page order
#   cookies.txt  Netscape-format cookies for takeout.google.com (0600)
# Never paste cookies into a shell/chat. Links have a limited re-download
# count — this script resumes byte ranges and never re-fetches completed
# parts.
set -euo pipefail

readonly DEFAULT_ATTEMPTS=40

die() { echo "takeout-download: ERROR: $*" >&2; exit 1; }
log() { echo "[$(date '+%F %T')] $*"; }

# --- embedded export manifest (from the Takeout summary page 2026-11-10) ---
# part <space> expected-size-string (units as printed by Google; band-checked)
readonly PARTS_MANIFEST='
1 550.6 MB
2 43.34 GB
3 44.41 GB
4 41.83 GB
5 839 MB
6 50.01 GB
7 50 GB
8 50 GB
9 50 GB
10 49.62 GB
11 226.2 MB
12 LESS1MB
13 LESS1MB
14 49.97 GB
15 50 GB
16 49.96 GB
17 49.94 GB
18 50 GB
19 50 GB
20 49.98 GB
21 50 GB
22 50 GB
23 49 GB'

# expected-size-string -> bytes_lo bytes_hi (band is sanity-only; CRC is truth)
size_band() {
  local spec=$1 lo hi
  case $spec in
    LESS1MB) lo=1; hi=1600000 ;;
    *)
      local amount unit
      amount=$(echo "$spec" | awk '{print $1}')
      unit=$(echo "$spec" | awk '{print $2}')
      case $unit in
        GB) amount=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1000000000 }') ;;
        MB) amount=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1000000 }') ;;
        KB) amount=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1000 }') ;;
        *) die "unknown size unit in manifest: $spec" ;;
      esac
      lo=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 0.85 }')
      hi=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1.15 }')
      ;;
  esac
  echo "$lo $hi"
}

init_staging() {
  local root=$1
  mkdir -p "$root"/{zips,logs,extracted}
  chmod 700 "$root" "$root"/{zips,logs,extracted}
  if [ ! -f "$root/parts.tsv" ]; then
    printf '# part\texpected\n' > "$root/parts.tsv"
    while IFS= read -r mline; do
      [ -n "$mline" ] || continue
      echo "${mline/ /$'\t'}" >> "$root/parts.tsv"
    done <<< "$PARTS_MANIFEST"
  fi
  [ -f "$root/urls.txt" ] || printf '# one download link per line, Takeout page order (owner handoff)\n' > "$root/urls.txt"
  local nparts_total
  nparts_total=$(awk 'NF && !/^#/ { n++ } END { print n + 0 }' "$root/parts.tsv")
  log "staging ready at $root (parts.tsv: $nparts_total parts)"
}

cmd_status() {
  local root=$1 total=0 ok=0 spec lo hi size name state
  [ -d "$root/zips" ] || die "no staging at $root (run init first)"
  while IFS=$'\t' read -r part spec; do
    case $part in ''|'#'*) continue ;; esac
    total=$((total + 1))
    name=$(printf 'part-%02d.zip' "$part")
    size=0
    [ -f "$root/zips/$name" ] && size=$(stat -c %s "$root/zips/$name")
    read -r lo hi <<< "$(size_band "$spec")"
    if [ "$size" -ge "$lo" ] && [ "$size" -le "$hi" ]; then state=OK; ok=$((ok + 1))
    elif [ "$size" -eq 0 ]; then state=MISSING
    else state="IN-BAND? ($size bytes, band $lo..$hi)"; fi
    printf '%-14s %12s bytes  %s\n' "$name" "$size" "$state"
  done < "$root/parts.tsv"
  log "parts in band: $ok/$total"
  [ "$ok" -eq "$total" ]
}

cmd_start() {
  local root=$1 attempts=${2:-$DEFAULT_ATTEMPTS}
  local urls=$root/urls.txt cookies=$root/cookies.txt
  [ -f "$urls" ] || die "urls.txt missing in $root — owner handoff (D3) not done"
  local nurls
  nurls=$(grep -c '^[[:space:]]*https\?://' "$urls" || true)
  local nparts
  nparts=$(awk 'NF && !/^#/ { n++ } END { print n + 0 }' "$root/parts.tsv")
  [ "$nurls" -eq "$nparts" ] || die "urls.txt has $nurls links but manifest expects $nparts parts"
  local cookie_args=()
  if [ -f "$cookies" ]; then
    chmod 600 "$cookies"
    cookie_args=(-b "$cookies")
    log "using session cookies from $cookies"
  else
    log "WARN: no cookies.txt — proceeding WITHOUT auth (works only for pre-signed links)"
  fi

  local part spec name url attempt rc size lo hi
  while IFS=$'\t' read -r part spec; do
    case $part in ''|'#'*) continue ;; esac
    name=$(printf 'part-%02d.zip' "$part")
    url=$(sed -n '/^[[:space:]]*https\?:\/\//p' "$urls" | sed -n "${part}p")
    read -r lo hi <<< "$(size_band "$spec")"

    size=0
    [ -f "$root/zips/$name" ] && size=$(stat -c %s "$root/zips/$name")
    if [ "$size" -ge "$lo" ] && [ "$size" -le "$hi" ]; then
      log "$name already complete ($size bytes) — skip"
      continue
    fi
    log "$name: downloading (band $lo..$hi bytes) from part-$part link"
    attempt=1
    while [ "$attempt" -le "$attempts" ]; do
      if curl --fail --location --continue-at - \
        --connect-timeout 30 --speed-time 300 --speed-limit 10240 \
        --retry 5 --retry-delay 15 --retry-all-errors \
        --silent --show-error \
        -A 'Mozilla/5.0 (X11; Linux x86_64) Takeout-bulk-download' \
        "${cookie_args[@]}" \
        --output "$root/zips/$name.part" "$url" 2>> "$root/logs/download.log"; then
        rc=0
      else
        rc=$?
      fi
      # promote the .part file so resume continues from real bytes
      if [ -f "$root/zips/$name.part" ]; then
        mv -f "$root/zips/$name.part" "$root/zips/$name"
      fi
      size=0
      [ -f "$root/zips/$name" ] && size=$(stat -c %s "$root/zips/$name")
      if [ "$size" -ge "$lo" ] && [ "$size" -le "$hi" ]; then
        log "$name: complete ($size bytes)"
        break
      fi
      if [ "$rc" -eq 0 ] && [ "$size" -gt "$hi" ]; then
        die "$name: oversize ($size > band $hi) — refusing to re-fetch (link quota); inspect manually"
      fi
      log "$name: attempt $attempt/$attempts ended rc=$rc size=$size — resuming in 15s" >> "$root/logs/download.log"
      log "$name: attempt $attempt rc=$rc size=$size bytes; resuming"
      attempt=$((attempt + 1))
      sleep 15
    done
    size=0
    [ -f "$root/zips/$name" ] && size=$(stat -c %s "$root/zips/$name")
    if [ "$size" -lt "$lo" ] || [ "$size" -gt "$hi" ]; then
      die "$name: incomplete after $attempts attempts ($size bytes, band $lo..$hi) — rerun start to resume; if the link is exhausted, request a NEW export (plan Phase 1)"
    fi
  done < "$root/parts.tsv"
  log "all parts within size band — run scripts/takeout-verify.sh $root next"
  cmd_status "$root"
}

main() {
  [ $# -ge 2 ] || die "usage: $0 <staging-dir> init|start|status [--attempts N]"
  local root=$1 cmd=$2
  case $cmd in
    init) init_staging "$root" ;;
    start)
      local attempts=$DEFAULT_ATTEMPTS
      [ "${3:-}" = "--attempts" ] && attempts=${4:-$DEFAULT_ATTEMPTS}
      init_staging "$root"
      cmd_start "$root" "$attempts"
      ;;
    status) cmd_status "$root" ;;
    *) die "unknown command: $cmd (init|start|status)" ;;
  esac
}

main "$@"
