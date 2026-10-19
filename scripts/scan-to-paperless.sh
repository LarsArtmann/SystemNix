#!/usr/bin/env bash
# ADS-1800W → Paperless-ngx intake.
#
# SANE's scanimage always emits PNM regardless of the --batch filename
# extension; Paperless-ngx rejects mime image/x-portable-pixmap (live failure
# 2026-10-19, doc attempt on test-receipt-biedronka.png). This wrapper stages
# the raw frames under ~/.cache, converts to REAL PNG (receipts, per sheet)
# or REAL multi-page PDF (invoices, per sheet: duplex frames paired
# front+back), then drops results into the consume directory.
#
# Usage:
#   scan-to-paperless.sh receipts [--dry-run]   simplex, one PNG per sheet
#   scan-to-paperless.sh invoices [--dry-run]   duplex, one 2-page PDF per sheet
#   scan-to-paperless.sh status                 consume dir, scanner, duplicates
#
# Blank-page handling: thermal roll leaders and missed prints scan as near-
# uniform frames. The wrapper prints ImageMagick brightness stats per frame
# and flags suspects; it never drops frames on its own (--drop-blank opts in).
set -euo pipefail

DEVICE="brother5:bus6;dev1"
CONSUME="/mnt/pool/services/paperless/consume"
STAGING="${HOME}/.cache/scan-to-paperless"
RESOLUTION=300
# Brightness mean/stddev thresholds: a blank 300 dpi color page is near-white
# with almost no variance. Values tuned on live receipts 2026-10-19.
BLANK_MEAN=0.93
BLANK_STDDEV=0.06

log() { printf '%s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
for bin in scanimage magick stat date; do need "$bin"; done

profile=""
dry_run=0
drop_blank=0
for arg in "$@"; do
  case "$arg" in
  receipts | invoices) profile="$arg" ;;
  --dry-run) dry_run=1 ;;
  --drop-blank) drop_blank=1 ;;
  status) profile="status" ;;
  *) die "unknown argument: $arg (want: receipts|invoices|status)" ;;
  esac
done

status() {
  log "consume dir: $(find "$CONSUME" -type f 2>/dev/null | wc -l) file(s)"
  find "$CONSUME" -type f -exec ls -la {} \; 2>/dev/null | tail -5
  log "scanner: $(scanimage -L 2>/dev/null | grep -c brother5) brother5 device(s)"
  log "duplicate policy: PAPERLESS_CONSUMER_DELETE_DUPLICATES=true (jam re-feeds are silently dropped by hash)"
}

[ -d "$CONSUME" ] || die "consume dir missing: $CONSUME"
if [ "$profile" = "status" ]; then status; exit 0; fi
[ -n "$profile" ] || die "usage: scan-to-paperless.sh receipts|invoices [--dry-run]"

duplex=0
case "$profile" in
receipts)
  source="Automatic Document Feeder(left aligned)"
  duplex=0
  ;;
invoices)
  source="Automatic Document Feeder(left aligned,Duplex)"
  duplex=1
  ;;
esac

mkdir -p "$STAGING/raw" "$STAGING/out" "$STAGING/skipped"
raw_dir=$(mktemp -d "$STAGING/raw/batch-XXXXXX")
ts=$(date +%Y%m%d-%H%M%S)
log "== batch $ts profile=$profile duplex=$duplex dry_run=$dry_run"

log "-- scanning ADF (load up to 20 sheets; drains until empty)..."
set +e
scanimage \
  -d "$DEVICE" \
  --mode "24bit Color[Fast]" \
  --resolution "$RESOLUTION" \
  --source "$source" \
  --AutoDocumentSize=yes \
  --AutoDeskew=yes \
  --batch="$raw_dir/frame-%04d.pnm"
rc=$?
set -e

shopt -s nullglob
frames=("$raw_dir"/frame-*.pnm)
if [ "${#frames[@]}" -eq 0 ]; then
  [ "$rc" -eq 7 ] && die "ADF empty: no sheets scanned (exit 7 = SANE_STATUS_NO_DOCS). Load paper and retry."
  die "scanimage failed rc=$rc with no frames written"
fi
log "-- ${#frames[@]} frame(s) captured (scanimage rc=$rc; 7 = drained, expected)"

for f in "${frames[@]}"; do
  magic=$(head -c 2 "$f" | od -An -c | tr -d ' \n')
  [ "$magic" = "P6" ] || die "staged frame $f is not PNM raw (magic '$magic') — scanimage contract changed"
done

convert_one() {
  frame=$1 out_name=$2
  magick "$frame" "$STAGING/out/$out_name"
  meanstd=$(magick "$STAGING/out/$out_name" -colorspace gray -format "%[fx:mean] %[fx:standard_deviation]" info:)
  mean=${meanstd%% *}
  std=${meanstd#* }
  verdict=""
  blank=$(awk -v m="$mean" -v s="$std" -v bm="$BLANK_MEAN" -v bs="$BLANK_STDDEV" \
    'BEGIN {print (m >= bm && s <= bs) ? 1 : 0}')
  if [ "$blank" -eq 1 ]; then
    verdict=" <== BLANK-SUSPECT (mean=$mean std=$std)"
    if [ "$drop_blank" -eq 1 ]; then
      mv "$STAGING/out/$out_name" "$STAGING/skipped/$out_name"
      verdict="$verdict -> skipped"
    fi
  else
    verdict=" (mean=$mean std=$std)"
  fi
  log "   $out_name$verdict"
}

start_s=$(date +%s)
n=0
if [ "$duplex" -eq 0 ]; then
  for f in "${frames[@]}"; do
    n=$((n + 1))
    convert_one "$f" "receipt-$ts-$(printf '%02d' "$n").png"
  done
else
  if [ $((${#frames[@]} % 2)) -ne 0 ]; then
    log "WARN: odd frame count ${#frames[@]} in duplex mode — last frame emitted as single-page PDF"
  fi
  i=0
  while [ $i -lt ${#frames[@]} ]; do
    n=$((n + 1))
    sheet="invoice-$ts-$(printf '%02d' "$n").pdf"
    if [ $((i + 1)) -lt ${#frames[@]} ]; then
      magick "${frames[$i]}" "${frames[$((i + 1))]}" "$STAGING/out/$sheet"
    else
      magick "${frames[$i]}" "$STAGING/out/$sheet"
    fi
    log "   $sheet (frames $((i + 1))+$((i + 2)))"
    i=$((i + 2))
  done
fi

if [ "$dry_run" -eq 1 ]; then
  log "== DRY RUN: output staged in $STAGING/out (nothing consumed)"
  exit 0
fi

elapsed=$(( $(date +%s) - start_s ))
for out in "$STAGING/out"/*; do
  cp "$out" "$CONSUME/" || die "failed copying $out into consume (ACL/group write?)"
done
log "== delivered $n document(s) to $CONSUME in ${elapsed}s (convert+deliver)"
[ "${#frames[@]}" -gt 0 ] && log "== feed-rate note: scanning dominates; use journal timestamps for per-doc OCR latency"
