#!/usr/bin/env bash
# takeout-watch.sh — guarded Gate-G1 auto-fire for the Takeout pipeline.
#
# Part of the Google account retirement pipeline (plan:
# docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md).
#
# The download `rapt` token is minted by real-browser JS at click time; the
# owner produces it via Ctrl+S ("Webpage, Complete") of the manage-archives
# page saved as links.html into the staging root. This watcher fires the
# download the moment that file lands — guarded so a wrong/partial save can
# never burn link fetches:
#   1. quiescence wait (size stable across checks),
#   2. exactly 23 data-download-uri attrs,
#   3. (size, filename) multiset must equal the frozen manifest
#      parts.tsv.known (snapshot BEFORE arming the watcher),
#   4. scripts/takeout-probe.sh must come back GREEN,
#   only then: scripts/takeout-download.sh <root> start (supervised here).
# Any refusal logs and EXITS (no retry loop by design — re-arm manually).
#
# Usage (detached, survives sessions):
#   systemd-run --user --collect --unit=takeout-g1-watch \
#     bash scripts/takeout-watch.sh
# Env: WATCH_ROOT (staging root), DRY_STOP=1 (validate-only self-test mode).
set -euo pipefail

ROOT=${WATCH_ROOT:-/mnt/pool/archive/google-takeout/racedriver8k-2026-11-10}
REPO=$(cd "$(dirname "$0")/.." && pwd)
KNOWN=${ROOT}/parts.tsv.known
STAMP=${ROOT}/watcher.stamp
LOG=${ROOT}/logs/watcher.log
DRY_STOP=${DRY_STOP:-0}

log() { echo "[$(date '+%F %T')] $*" >>"$LOG"; }

validate() {
  # $1 = links.html candidate; prints sorted size<TAB>filename multiset
  local html=$1
  paste -d'\t' \
    <(grep -o 'data-size="[^"]*"' "$html" | sed 's/^data-size="//; s/"$//') \
    <(grep -o 'data-filename="[^"]*"' "$html" | sed 's/^data-filename="//; s/"$//') |
    sort
}

known_multiset() {
  awk -F'\t' 'NF && !/^#/ { print $2 "\t" $3 }' "$KNOWN" | sort
}

main() {
  [ -f "$KNOWN" ] || {
    log "FATAL: no frozen manifest $KNOWN"
    exit 1
  }
  date '+%F %T' >"$STAMP"
  log "watching $ROOT for a links.html newer than $(cat "$STAMP") (probe: $REPO/scripts/takeout-probe.sh)"
  while :; do
    sleep 20
    [ -f "$ROOT/links.html" ] || continue
    [ "$ROOT/links.html" -nt "$STAMP" ] || continue
    log "candidate links.html detected — waiting for quiescence"
    local s1 s2
    s1=$(stat -c %s "$ROOT/links.html")
    sleep 10
    s2=$(stat -c %s "$ROOT/links.html")
    [ "$s1" = "$s2" ] || {
      log "still writing (size drift) — next cycle"
      continue
    }
    local n
    n=$(grep -c 'data-download-uri=' "$ROOT/links.html" || true)
    [ "$n" -eq 23 ] || {
      log "REFUSED: $n data-download-uri attrs (want 23) — not a valid page save; fix and re-save, watcher exiting"
      exit 2
    }
    if ! diff -q <(validate "$ROOT/links.html") <(known_multiset) >/dev/null; then
      log "REFUSED: size/filename multiset mismatch vs frozen manifest — watcher exiting"
      exit 3
    fi
    log "validation GREEN (23 triplets, exact multiset) — ingesting"
    [ "$DRY_STOP" = 1 ] && {
      log "DRY_STOP: would ingest+probe+start here"
      exit 0
    }
    bash "$REPO/scripts/takeout-download.sh" "$ROOT" ingest-html >>"$LOG" 2>&1
    if ! diff -q <(awk -F'\t' 'NF && !/^#/ { print $2 "\t" $3 }' "$ROOT/parts.tsv" | sort) <(known_multiset) >/dev/null; then
      log "FATAL: post-ingest manifest drifted vs known — watcher exiting"
      exit 4
    fi
    chmod 600 "$ROOT/urls.txt" "$ROOT/parts.tsv" "$ROOT/links.html"
    log "ingested; probing part 12"
    if bash "$REPO/scripts/takeout-probe.sh" "$ROOT" >>"$LOG" 2>&1; then
      log "probe GREEN — starting download (G1)"
    else
      log "probe RED — NOT starting; watcher exiting (see probe output above)"
      exit 5
    fi
    date '+%F %T' >"$ROOT/watcher.started"
    log "start: takeout-download.sh start (supervised by this watcher, unit takeout-g1-watch)"
    if bash "$REPO/scripts/takeout-download.sh" "$ROOT" start >>"$ROOT/logs/download-driver.log" 2>&1; then
      log "download script exited 0 (all parts in band — run takeout-verify.sh next)"
    else
      log "download script exited rc=$? — check logs/download-driver.log"
    fi
    log "watcher done"
    exit 0
  done
}

main "$@"
