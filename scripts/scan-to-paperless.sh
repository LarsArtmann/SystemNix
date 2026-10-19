#!/usr/bin/env bash
# ADS-1800W → Paperless-ngx intake.
#
# SANE's scanimage always emits PNM regardless of the --batch filename
# extension; Paperless-ngx rejects mime image/x-portable-pixmap (live failure
# 2026-10-19, doc attempt on test-receipt-biedronka.png). This wrapper stages
# the raw frames under ~/.cache, converts to REAL PNG (receipts, per sheet)
# or REAL multi-page PDF (invoices/watch, per sheet: duplex frames paired
# front+back), then drops results into the consume directory.
#
# Usage:
#   scan-to-paperless.sh watch            NON-STOP intake: duplex, one 2-page
#                                         PDF per sheet, auto-delivered whenever
#                                         the ADF has paper. Stop: touch
#                                         ~/.cache/scan-to-paperless/STOP
#   scan-to-paperless.sh receipts [--dry-run]   simplex, one PNG per sheet
#   scan-to-paperless.sh invoices [--dry-run]   duplex, one 2-page PDF per sheet
#   scan-to-paperless.sh status                 consume dir, scanner, duplicates
#
# Blank-page handling: thermal roll leaders, missed prints and folded
# letter-backs scan as near-uniform frames. Every frame gets ImageMagick
# brightness stats and BLANK-SUSPECT is flagged; frames are never dropped on
# their own (--drop-blank opts in, simplex only — dropping duplex frames
# would break front/back pairing).
#
# Small-doc seating: push sheets (receipts especially) into the ADF until the
# rollers catch and set the guide snug; the watch loop's retry cycle grabs a
# sheet the moment it is seated far enough. rc=4 is the feeder-sensor state
# ("sane_start: Invalid argument": paper sits at the feeder but the pick
# rollers have not engaged) and is handled as a soft retry.
#
# Loop durability (2026-10-19 10:01 incident): the scanner dropped off the USB
# bus mid-scan, scanimage blocked in the kernel for 29 min, `timeout` returned
# rc=124 with a header-only truncated PNM, and the resulting copy failure
# killed the entire watch process — the operator fed paper for 50 min into a
# dead loop. Nothing on the batch path may exit the process now: truncated
# frames are trimmed, every product is verified before delivery, delivery
# failures are logged, and polling continues.
set -euo pipefail

DEVICE="brother5:bus6;dev1"
CONSUME="/mnt/pool/services/paperless/consume"
STAGING="${HOME}/.cache/scan-to-paperless"
RESOLUTION=300
SCAN_TIMEOUT=300
SCAN_KILL_GRACE=20
WATCH_EMPTY_SLEEP=4
WATCH_FAIL_SLEEP=2
WATCH_FAIL_SLEEP_MAX=15
# Staging GC: raw batch dirs and undelivered products older than this are swept
# at startup. Each batch dir is additionally removed the moment it is done with.
STALE_MIN=60
# A real 300 dpi frame of the smallest supported document (50.8 x 70 mm) is
# ~1.5 MB; anything at or below this is the PNM header of an aborted scan.
MIN_FRAME_BYTES=1024
# Brightness mean/stddev thresholds: a blank 300 dpi color page is near-white
# with almost no variance. Values tuned on live receipts 2026-10-19.
BLANK_MEAN=0.93
BLANK_STDDEV=0.06

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
# Soft counterpart of die(): reports and leaves the caller to keep control.
# Deliberately returns 0 so it can never trip errexit inside a branch body.
fail() { log "ERROR: $*"; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
for bin in scanimage magick awk timeout date stat find du; do need "$bin"; done

mode=""
dry_run=0
drop_blank=0
for arg in "$@"; do
  case "$arg" in
  watch | receipts | invoices) mode="$arg" ;;
  --dry-run) dry_run=1 ;;
  --drop-blank) drop_blank=1 ;;
  status) mode="status" ;;
  *) die "unknown argument: $arg (want: watch|receipts|invoices|status)" ;;
  esac
done

status() {
  log "consume dir: $(find "$CONSUME" -type f 2>/dev/null | wc -l) file(s)"
  find "$CONSUME" -type f -exec ls -la {} \; 2>/dev/null | tail -5
  if scanimage -L 2>/dev/null | grep -qF "$DEVICE"; then
    log "scanner: $DEVICE present"
  else
    log "scanner: $DEVICE NOT on the bus — unplug/replug the USB cable"
  fi
  log "staging: raw=$(du -sh "$STAGING/raw" 2>/dev/null | cut -f1) ($(find "$STAGING/raw" -mindepth 1 -maxdepth 1 -type d | wc -l) batch dir(s)), out=$(find "$STAGING/out" -mindepth 1 -maxdepth 1 -type f | wc -l) file(s)"
  local watch_pids
  watch_pids=$(pgrep -fc 'scan-to-paperless.sh watch' 2>/dev/null || true)
  log "watch: ${watch_pids:-0} process(es), stop-flag: $([ -f "$STAGING/STOP" ] && echo SET || echo absent)"
  log "duplicate policy: PAPERLESS_CONSUMER_DELETE_DUPLICATES=true (jam re-feeds are silently dropped by hash)"
}

[ -d "$CONSUME" ] || die "consume dir missing: $CONSUME"
case "$STAGING" in
"$HOME"/.cache/*) ;;
*) die "refusing to run: STAGING is not under \$HOME/.cache ($STAGING)" ;;
esac
if [ "$mode" = "status" ]; then status; exit 0; fi
[ -n "$mode" ] || die "usage: scan-to-paperless.sh watch|receipts|invoices [--dry-run]"

duplex=0
prefix="doc"
case "$mode" in
receipts)
  source="Automatic Document Feeder(left aligned)"
  duplex=0
  prefix="receipt"
  ;;
invoices)
  source="Automatic Document Feeder(left aligned,Duplex)"
  duplex=1
  prefix="invoice"
  ;;
watch)
  source="Automatic Document Feeder(left aligned,Duplex)"
  duplex=1
  prefix="doc"
  ;;
esac

mkdir -p "$STAGING/raw" "$STAGING/out" "$STAGING/skipped"

staging_gc() {
  local n
  n=$(find "$STAGING/raw" -mindepth 1 -maxdepth 1 -type d -mmin +"$STALE_MIN" | wc -l)
  if [ "$n" -gt 0 ]; then
    find "$STAGING/raw" -mindepth 1 -maxdepth 1 -type d -mmin +"$STALE_MIN" -exec rm -rf {} +
    log "gc: reclaimed $n stale raw batch dir(s) older than ${STALE_MIN}min"
  fi
  n=$(find "$STAGING/out" -mindepth 1 -maxdepth 1 -type f -mmin +"$STALE_MIN" | wc -l)
  if [ "$n" -gt 0 ]; then
    find "$STAGING/out" -mindepth 1 -maxdepth 1 -type f -mmin +"$STALE_MIN" -delete
    log "gc: removed $n stale staged product(s) older than ${STALE_MIN}min"
  fi
}

blank_flag() {
  awk -v m="$1" -v s="$2" -v bm="$BLANK_MEAN" -v bs="$BLANK_STDDEV" \
    'BEGIN {print (m >= bm && s <= bs) ? 1 : 0}'
}

frame_stats() {
  local meanstd mean std
  meanstd=$(magick "$1" -colorspace gray -format "%[fx:mean] %[fx:standard_deviation]" info:)
  mean=${meanstd%% *}
  std=${meanstd#* }
  printf '%s mean=%s std=%s' "$( [ "$(blank_flag "$mean" "$std")" -eq 1 ] && echo BLANK-SUSPECT || echo ok)" "$mean" "$std"
}

frame_is_blank() {
  local meanstd mean std
  meanstd=$(magick "$1" -colorspace gray -format "%[fx:mean] %[fx:standard_deviation]" info:)
  mean=${meanstd%% *}
  std=${meanstd#* }
  blank_flag "$mean" "$std"
}

# Scans one ADF batch into a fresh staging dir. Globals set: batch_rc,
# batch_dir, frames (array). Never dies on scanimage failure.
scan_batch() {
  batch_dir=$(mktemp -d "$STAGING/raw/batch-XXXXXX")
  set +e
  timeout -k "$SCAN_KILL_GRACE" "$SCAN_TIMEOUT" scanimage \
    -d "$DEVICE" \
    --mode "24bit Color[Fast]" \
    --resolution "$RESOLUTION" \
    --source "$source" \
    --AutoDocumentSize=yes \
    --AutoDeskew=yes \
    --batch="$batch_dir/frame-%04d.pnm" 2>"$batch_dir/scanimage.err"
  batch_rc=$?
  set -e
  shopt -s nullglob
  frames=("$batch_dir"/frame-*.pnm)
}

cleanup_batch() {
  case "${batch_dir:-}" in
  "$STAGING"/raw/batch-*) rm -rf "$batch_dir" ;;
  esac
}

device_present() { scanimage -L 2>/dev/null | grep -qF "$DEVICE"; }

# Trims the frame list at the first unusable frame: a scan cut short by the
# timeout leaves a header-only PNM, and everything after it is suspect too.
# The valid prefix is kept, so a stalled 20-sheet load still delivers the
# sheets that did scan.
verify_frames() {
  local f magic size dropped
  local -a kept=()
  for f in "${frames[@]}"; do
    magic=$(head -c 2 "$f" | od -An -c | tr -d ' \n')
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    if [ "$magic" = "P6" ] && [ "$size" -gt "$MIN_FRAME_BYTES" ]; then
      kept+=("$f")
    else
      break
    fi
  done
  dropped=$(( ${#frames[@]} - ${#kept[@]} ))
  if [ "$dropped" -gt 0 ]; then
    log "WARN: dropped $dropped unusable frame(s) — truncated PNM, scan aborted (rc=$batch_rc)"
  fi
  frames=()
  if [ "${#kept[@]}" -gt 0 ]; then
    frames=("${kept[@]}")
  fi
  if [ "${#frames[@]}" -eq 0 ]; then
    fail "no usable frames in this batch (every staged frame was truncated or empty)"
    return 1
  fi
  return 0
}

pdf_page_count() {
  grep -a -o "/Count [0-9]*" "$1" 2>/dev/null | awk '{print $2}' | sort -n | tail -1
}

# Output contract, checked before anything reaches consume: the product exists,
# it is not raw PNM (the mime Paperless rejects), and — when a page count is
# expected — the PDF page tree agrees. $2 empty means "do not count pages".
verify_product() {
  local name="$1" expect="${2:-}" magic pages
  if [ ! -s "$STAGING/out/$name" ]; then
    fail "product $name missing or empty — conversion failed"
    return 1
  fi
  magic=$(head -c 4 "$STAGING/out/$name" | od -An -c | tr -d ' \n')
  case "$magic" in
  P6*)
    fail "product $name is still raw PNM — Paperless would reject image/x-portable-pixmap"
    return 1
    ;;
  esac
  if [ -n "$expect" ]; then
    pages=$(pdf_page_count "$STAGING/out/$name")
    if [ -z "$pages" ]; then
      log "WARN: $name: no /Count marker found, page count unverified"
    elif [ "$pages" -ne "$expect" ]; then
      fail "product $name has $pages page(s), expected $expect"
      return 1
    fi
  fi
  return 0
}

# Copies only the named products (never a directory glob — re-delivering a
# leftover file is silently discarded by the duplicate policy) and drops each
# one from staging once it is safely in consume. The explicit chmod matters:
# the consumer runs as another user, and a delivered file without read
# permission is skipped silently and forever (a mode-600 phone photo sat
# unread in consume for 2h20m on 2026-10-19).
deliver_out() {
  local f rc=0
  for f in "$@"; do
    if cp "$STAGING/out/$f" "$CONSUME/" && chmod 0644 "$CONSUME/$f"; then
      rm -f "$STAGING/out/$f"
    else
      fail "failed copying $f into consume (ACL/group write?)"
      rc=1
    fi
  done
  return $rc
}

process_batch() {
  local start_s n i sheet s1 s2 elapsed batch_bad=0 f out_name meanstd mean std verdict
  local -a products=()
  [ "${#frames[@]}" -eq 0 ] && return 1
  verify_frames || return 1
  log "-- ${#frames[@]} frame(s) captured (scanimage rc=$batch_rc; 0 = ok, 7 = drained, 124 = timed out)"
  start_s=$(date +%s)
  n=0
  if [ "$duplex" -eq 0 ]; then
    for f in "${frames[@]}"; do
      n=$((n + 1))
      out_name="receipt-$ts-$(printf '%02d' "$n").png"
      if ! magick "$f" "$STAGING/out/$out_name" || ! verify_product "$out_name"; then
        batch_bad=1
        continue
      fi
      meanstd=$(magick "$STAGING/out/$out_name" -colorspace gray -format "%[fx:mean] %[fx:standard_deviation]" info: || true)
      mean=${meanstd%% *}
      std=${meanstd#* }
      s1="$( [ "$(blank_flag "$mean" "$std")" -eq 1 ] && echo BLANK-SUSPECT || echo ok)"
      verdict=" (mean=$mean std=$std)"
      if [ "$s1" = "BLANK-SUSPECT" ]; then
        verdict=" <== BLANK-SUSPECT (mean=$mean std=$std)"
        if [ "$drop_blank" -eq 1 ]; then
          mv "$STAGING/out/$out_name" "$STAGING/skipped/$out_name"
          log "   $out_name$verdict -> skipped"
          continue
        fi
      fi
      products+=("$out_name")
      log "   $out_name$verdict"
    done
  else
    if [ $(( ${#frames[@]} % 2 )) -ne 0 ]; then
      log "WARN: odd frame count ${#frames[@]} in duplex mode — last frame emitted as single-page PDF (possible multifeed: ADF multi-feed detection is inactive on this device)"
    fi
    i=0
    while [ $i -lt ${#frames[@]} ]; do
      n=$((n + 1))
      sheet="$prefix-$ts-$(printf '%02d' "$n").pdf"
      if [ $((i + 1)) -lt ${#frames[@]} ]; then
        first=${frames[$i]}
        second=${frames[$((i + 1))]}
        s1=$(frame_stats "$first")
        s2=$(frame_stats "$second")
        b1=$(frame_is_blank "$first")
        b2=$(frame_is_blank "$second")
        note=""
        if [ "$b1" -eq 1 ] && [ "$b2" -eq 0 ]; then
          first=${frames[$((i + 1))]}
          second=${frames[$i]}
          note=" [reordered: blank face moved to page 2]"
        fi
        if magick "$first" "$second" "$STAGING/out/$sheet" && verify_product "$sheet" 2; then
          products+=("$sheet")
        else
          batch_bad=1
        fi
        log "   $sheet (frames $((i + 1))+$((i + 2))): face1=$s1 face2=$s2$note"
      else
        if magick "${frames[$i]}" "$STAGING/out/$sheet" && verify_product "$sheet" 1; then
          products+=("$sheet")
        else
          batch_bad=1
        fi
        s1=$(frame_stats "${frames[$i]}")
        log "   $sheet (frame $((i + 1)), single): face1=$s1"
      fi
      i=$((i + 2))
    done
  fi
  elapsed=$(( $(date +%s) - start_s ))
  if [ "${#products[@]}" -eq 0 ]; then
    fail "nothing deliverable in this batch (${#frames[@]} frame(s) scanned, conversion or verification failed)"
    return 1
  fi
  if [ "$dry_run" -eq 1 ]; then
    log "== DRY RUN: output staged in $STAGING/out (nothing consumed)"
  elif deliver_out "${products[@]}"; then
    log "== delivered ${#products[@]} document(s) to $CONSUME (convert+deliver ${elapsed}s)"
  else
    fail "delivery incomplete — ${#products[@]} product(s) still staged in $STAGING/out, check $CONSUME permissions"
    return 1
  fi
  if [ "$batch_bad" -eq 1 ]; then
    fail "batch incomplete: ${#products[@]} product(s) good, at least one conversion rejected (see log above)"
  fi
  return 0
}

staging_gc

case "$mode" in
watch)
  total_docs=0
  consec_fail=0
  empty_streak=0
  log "== WATCH mode start $(date +%H:%M:%S) duplex=1 dry_run=$dry_run — feed paper any time; stop: touch $STAGING/STOP"
  while true; do
    [ -f "$STAGING/STOP" ] && {
      log "== STOP flag found — watch ends after $total_docs document(s)"
      exit 0
    }
    ts=$(date +%Y%m%d-%H%M%S)
    scan_batch || true
    if [ "${#frames[@]}" -gt 0 ]; then
      if process_batch; then
        total_docs=$((total_docs + 1))
      fi
      cleanup_batch
      consec_fail=0
      empty_streak=0
      sleep 2
    elif [ "$batch_rc" -eq 7 ] || [ "$batch_rc" -eq 0 ]; then
      cleanup_batch
      empty_streak=$((empty_streak + 1))
      if [ $((empty_streak % 15)) -eq 1 ]; then
        log "idle: ADF empty rc=$batch_rc (empty streak #$empty_streak since last capture)"
      fi
      sleep "$WATCH_EMPTY_SLEEP"
    elif [ "$batch_rc" -eq 124 ]; then
      cleanup_batch
      consec_fail=$((consec_fail + 1))
      log "WARN: scan timed out after ${SCAN_TIMEOUT}s (consecutive #$consec_fail) — the device stopped answering; brscan5 stays blocked until the kernel drops it"
      if device_present; then
        log "WARN: $DEVICE is still on the bus — check the ADF for a jam and push the sheet in again"
      else
        log "WARN: $DEVICE is GONE from the bus — unplug/replug the scanner USB cable to re-enumerate"
      fi
      sleep 10
    else
      err_line=$(tail -1 "$batch_dir/scanimage.err" 2>/dev/null || true)
      cleanup_batch
      consec_fail=$((consec_fail + 1))
      log "WARN: scan attempt failed rc=$batch_rc (consecutive #$consec_fail, empty_streak was #$empty_streak) sane says: ${err_line:-<no stderr>}; rc=4 = paper at the feeder with the pick rollers not yet engaged — push the sheet in until it stops"
      if [ "$batch_rc" -eq 4 ]; then
        sleep 3
      else
        sleep "$(( WATCH_FAIL_SLEEP * consec_fail < WATCH_FAIL_SLEEP_MAX ? WATCH_FAIL_SLEEP * consec_fail : WATCH_FAIL_SLEEP_MAX ))"
      fi
    fi
  done
  ;;
*)
  ts=$(date +%Y%m%d-%H%M%S)
  log "== batch $ts mode=$mode duplex=$duplex dry_run=$dry_run"
  log "-- scanning ADF (load up to 20 sheets; drains until empty)..."
  scan_batch
  if [ "${#frames[@]}" -eq 0 ]; then
    [ "$batch_rc" -eq 7 ] && die "ADF empty: no sheets scanned (exit 7 = SANE_STATUS_NO_DOCS). Load paper and retry."
    die "scanimage failed rc=$batch_rc with no frames written"
  fi
  if process_batch; then
    cleanup_batch
  else
    log "raw frames kept for inspection: $batch_dir"
    exit 1
  fi
  ;;
esac
