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
# sheet the moment it is seated far enough. Sensor flap while half-seated
# surfaces as scanimage rc=4 "Invalid argument" — handled as a soft retry.
set -euo pipefail

DEVICE="brother5:bus6;dev1"
CONSUME="/mnt/pool/services/paperless/consume"
STAGING="${HOME}/.cache/scan-to-paperless"
RESOLUTION=300
SCAN_TIMEOUT=300
WATCH_EMPTY_SLEEP=4
WATCH_FAIL_SLEEP=2
WATCH_FAIL_SLEEP_MAX=15
# Brightness mean/stddev thresholds: a blank 300 dpi color page is near-white
# with almost no variance. Values tuned on live receipts 2026-10-19.
BLANK_MEAN=0.93
BLANK_STDDEV=0.06

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
for bin in scanimage magick awk timeout date; do need "$bin"; done

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
  log "scanner: $(scanimage -L 2>/dev/null | grep -c brother5) brother5 device(s)"
  log "watch stop-flag: $([ -f "$STAGING/STOP" ] && echo SET || echo absent)"
  log "duplicate policy: PAPERLESS_CONSUMER_DELETE_DUPLICATES=true (jam re-feeds are silently dropped by hash)"
}

[ -d "$CONSUME" ] || die "consume dir missing: $CONSUME"
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

# Scans one ADF batch into a fresh staging dir. Globals set: batch_rc,
# batch_dir, frames (array). Never dies on scanimage failure.
scan_batch() {
  batch_dir=$(mktemp -d "$STAGING/raw/batch-XXXXXX")
  set +e
  timeout "$SCAN_TIMEOUT" scanimage \
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

verify_pnm() {
  local f magic
  for f in "${frames[@]}"; do
    magic=$(head -c 2 "$f" | od -An -c | tr -d ' \n')
    [ "$magic" = "P6" ] || die "staged frame $f is not PNM raw (magic '$magic') — scanimage contract changed"
  done
}

deliver_out() {
  local f
  for f in "$@"; do
    cp "$STAGING/out/$f" "$CONSUME/" || die "failed copying $f into consume (ACL/group write?)"
  done
}

process_batch() {
  local start_s n i sheet s1 s2 elapsed
  local -a products=()
  [ "${#frames[@]}" -eq 0 ] && return 1
  verify_pnm
  log "-- ${#frames[@]} frame(s) captured (scanimage rc=$batch_rc; 0 = ok, 7 = drained)"
  start_s=$(date +%s)
  n=0
  if [ "$duplex" -eq 0 ]; then
    local f out_name meanstd mean std
    for f in "${frames[@]}"; do
      n=$((n + 1))
      out_name="receipt-$ts-$(printf '%02d' "$n").png"
      products+=("$out_name")
      magick "$f" "$STAGING/out/$out_name"
      meanstd=$(magick "$STAGING/out/$out_name" -colorspace gray -format "%[fx:mean] %[fx:standard_deviation]" info:)
      mean=${meanstd%% *}
      std=${meanstd#* }
      s1="$( [ "$(blank_flag "$mean" "$std")" -eq 1 ] && echo BLANK-SUSPECT || echo ok)"
      verdict=" (mean=$mean std=$std)"
      if [ "$s1" = "BLANK-SUSPECT" ]; then
        verdict=" <== BLANK-SUSPECT (mean=$mean std=$std)"
        if [ "$drop_blank" -eq 1 ]; then
          mv "$STAGING/out/$out_name" "$STAGING/skipped/$out_name"
          verdict="$verdict -> skipped"
        fi
      fi
      log "   $out_name$verdict"
    done
  else
    if [ $((${#frames[@]} % 2)) -ne 0 ]; then
      log "WARN: odd frame count ${#frames[@]} in duplex mode — last frame emitted as single-page PDF (possible multifeed: ADF multi-feed detection is inactive on this device)"
    fi
    i=0
    while [ $i -lt ${#frames[@]} ]; do
      n=$((n + 1))
      sheet="$prefix-$ts-$(printf '%02d' "$n").pdf"
      products+=("$sheet")
      if [ $((i + 1)) -lt ${#frames[@]} ]; then
        magick "${frames[$i]}" "${frames[$((i + 1))]}" "$STAGING/out/$sheet"
        s1=$(frame_stats "${frames[$i]}")
        s2=$(frame_stats "${frames[$((i + 1))]}")
        log "   $sheet (frames $((i + 1))+$((i + 2))): face1=$s1 face2=$s2"
      else
        magick "${frames[$i]}" "$STAGING/out/$sheet"
        s1=$(frame_stats "${frames[$i]}")
        log "   $sheet (frame $((i + 1)), single): face1=$s1"
      fi
      i=$((i + 2))
    done
  fi
  elapsed=$(( $(date +%s) - start_s ))
  if [ "$dry_run" -eq 1 ]; then
    log "== DRY RUN: output staged in $STAGING/out (nothing consumed)"
  else
    deliver_out "${products[@]}"
    log "== delivered $n document(s) to $CONSUME (convert+deliver ${elapsed}s)"
  fi
  return 0
}

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
      process_batch && total_docs=$((total_docs + 1))
      consec_fail=0
      empty_streak=0
      sleep 2
    elif [ "$batch_rc" -eq 7 ] || [ "$batch_rc" -eq 0 ]; then
      empty_streak=$((empty_streak + 1))
      if [ $((empty_streak % 15)) -eq 1 ]; then
        log "idle: ADF empty rc=$batch_rc (empty streak #$empty_streak since last capture)"
      fi
      sleep "$WATCH_EMPTY_SLEEP"
    else
      consec_fail=$((consec_fail + 1))
      err_line=$(tail -1 "$batch_dir/scanimage.err" 2>/dev/null || true)
      log "WARN: scan attempt failed rc=$batch_rc (consecutive #$consec_fail, empty_streak was #$empty_streak) sane says: ${err_line:-<no stderr>}; half-seated sheets flap the sensor (rc=4 is this class)"
      sleep "$(( WATCH_FAIL_SLEEP * consec_fail < WATCH_FAIL_SLEEP_MAX ? WATCH_FAIL_SLEEP * consec_fail : WATCH_FAIL_SLEEP_MAX ))"
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
  process_batch
  ;;
esac
