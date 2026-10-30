#!/usr/bin/env bash
# Repair documents whose OCR produced NO text, because paperless refuses to
# OCR signed or encrypted PDFs.
#
# Background (2026-10-29 audit): 382 of 1,793 documents had empty content.
# 83 of them are signed bank receipts (Qonto/Wise) where paperless's parser
# catches DigitalSignatureError and logs "This file is encrypted and/or
# signed, OCR is impossible" (paperless/parsers/tesseract.py) — the PDF is
# never OCR'd and no archive file is produced. Rewriting the PDF through
# Ghostscript drops the signature field, after which OCR works normally
# (verified: 2,179 characters recovered from a Qonto invoice).
#
# Per document the script:
#   1. copies the original out of the paperless dataDir,
#   2. sanitizes it with ghostscript (removes signature/interactive form),
#   3. OCRs it with the SAME ocrmypdf/tesseract build paperless uses,
#   4. requires a minimum character yield (--min-chars, default 32),
#   5. uploads the result through /api/documents/post_document/ with the
#      original title / created date / correspondent / document type / tags
#      / archive serial number,
#   6. waits for the consumption task, re-reads the new document and
#      confirms it has text,
#   7. ONLY THEN deletes the original (it lands in the 30-day trash).
#
# Skipped classes (reported, never modified): password-protected PDFs (no
# password available to this script) and images (a photo with no text has
# nothing to recover; pass --include-images to OCR them anyway).
#
# Usage:
#   sudo scripts/paperless-repair-empty-content.sh                 # dry run
#   sudo scripts/paperless-repair-empty-content.sh --apply
#   sudo scripts/paperless-repair-empty-content.sh --apply --limit 5
#   sudo scripts/paperless-repair-empty-content.sh --apply --doc-ids "1000949 1000950"
#
# Exit codes: 0 = every candidate handled or correctly skipped, 1 = at least
# one document failed (rerun is safe: repaired docs are no longer candidates).
set -euo pipefail

PORT="${PAPERLESS_PORT:-2892}"
BASE="http://127.0.0.1:${PORT}"
DATA_DIR="${PAPERLESS_DATA_DIR:-/mnt/pool/services/paperless}"
MANAGE="${PAPERLESS_MANAGE:-/run/current-system/sw/bin/paperless-manage}"
GS_BIN="${PAPERLESS_GS_BIN:-$(command -v gs || true)}"
OCR_BIN="${PAPERLESS_OCRMYPDF_BIN:-$(command -v ocrmypdf || true)}"

APPLY=0
LIMIT=0
MIN_CHARS=32
INCLUDE_IMAGES=0
DOC_IDS=""

while [ $# -gt 0 ]; do
  case "$1" in
  --apply) APPLY=1 ;;
  --limit)
    LIMIT="$2"
    shift
    ;;
  --min-chars)
    MIN_CHARS="$2"
    shift
    ;;
  --include-images) INCLUDE_IMAGES=1 ;;
  --doc-ids)
    DOC_IDS="$2"
    shift
    ;;
  -h | --help)
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    exit 64
    ;;
  esac
  shift
done

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root (reads originals from ${DATA_DIR}, mints a token as the paperless user)" >&2
  exit 77
fi

# /tmp is volatile on this box (mid-session wipe class) — keep the workspace
# on the cache filesystem.
WORK_ROOT="${XDG_CACHE_HOME:-/root/.cache}/paperless-repair"
mkdir -p "$WORK_ROOT"
WORK="$(mktemp -d "${WORK_ROOT}/run.XXXXXX")"
TOKEN_FILE="$WORK/token"
trap 'rm -rf "$WORK"' EXIT

# --- locate the tools paperless itself uses -------------------------------
# The OCR result must come from the same tesseract language set paperless
# has; the system PATH usually lacks ocrmypdf, so fall back to the python
# environment the paperless package exposes.
find_ocrmypdf() {
  if [ -n "$OCR_BIN" ] && [ -x "$OCR_BIN" ]; then return 0; fi
  local cand
  cand="$(find /nix/store -maxdepth 3 -path '*-python*o*ocrmypdf-*/bin/ocrmypdf' -print 2>/dev/null | head -n1)"
  if [ -n "$cand" ] && [ -x "$cand" ]; then
    OCR_BIN="$cand"
    return 0
  fi
  echo "could not locate ocrmypdf (set PAPERLESS_OCRMYPDF_BIN)" >&2
  return 1
}
find_gs() {
  if [ -n "$GS_BIN" ] && [ -x "$GS_BIN" ]; then return 0; fi
  local cand
  cand="$(find /nix/store -maxdepth 3 -path '*-ghostscript-*/bin/gs' -print 2>/dev/null | head -n1)"
  if [ -n "$cand" ] && [ -x "$cand" ]; then
    GS_BIN="$cand"
    return 0
  fi
  echo "could not locate ghostscript (set PAPERLESS_GS_BIN)" >&2
  return 1
}
find_gs
find_ocrmypdf
OCR_LANG="${PAPERLESS_OCR_LANGUAGE:-deu+eng}"

# --- token -----------------------------------------------------------------
# drf_create_token as the paperless OS user (peer-auth PG); the token lives
# only in this workspace file, never in argv, an env var or the journal.
if ! runuser -u paperless -- "$MANAGE" drf_create_token admin >"$TOKEN_FILE" 2>/dev/null; then
  echo "token mint failed (is $MANAGE present and postgresql running?)" >&2
  exit 1
fi
TOKEN="$(grep -oE '[0-9a-f]{40}' "$TOKEN_FILE" | head -n1)"
if ! printf '%s' "$TOKEN" | grep -qE '^[0-9a-f]{40}$'; then
  echo "token extraction failed (unexpected drf_create_token output)" >&2
  exit 1
fi
chmod 600 "$TOKEN_FILE"

api() { # api METHOD PATH [JSON]
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS --fail-with-body --max-time 120 \
      -H "Authorization: Token $TOKEN" -H 'Accept: application/json' \
      -H 'Content-Type: application/json' -X "$method" -d "$body" "$BASE$path"
  else
    curl -sS --fail-with-body --max-time 120 \
      -H "Authorization: Token $TOKEN" -H 'Accept: application/json' \
      -X "$method" "$BASE$path"
  fi
}

# --- candidate list (ORM: exact, and this script already runs as root) -----
LIST_PY="$WORK/list.py"
cat >"$LIST_PY" <<'PY'
from django.db.models import Q
from documents.models import Document

qs = Document.objects.filter(Q(content="") | Q(content__isnull=True)).order_by("id")
for d in qs:
    print("\t".join([
        str(d.id),
        d.mime_type or "",
        d.filename or "",
        (d.title or "").replace("\t", " "),
        d.created.isoformat() if d.created else "",
        str(d.correspondent_id or ""),
        str(d.document_type_id or ""),
        ",".join(str(t.id) for t in d.tags.all()),
        str(d.archive_serial_number or ""),
    ]))
PY
runuser -u paperless -- "$MANAGE" shell <"$LIST_PY" 2>/dev/null |
  grep -E '^[0-9]+\t' >"$WORK/candidates.tsv" || true

if [ -n "$DOC_IDS" ]; then
  : >"$WORK/selected.tsv"
  for want in $DOC_IDS; do
    grep -P "^${want}\t" "$WORK/candidates.tsv" >>"$WORK/selected.tsv" || true
  done
  mv "$WORK/selected.tsv" "$WORK/candidates.tsv"
fi

total=$(wc -l <"$WORK/candidates.tsv" | tr -d ' ')
echo "paperless-repair: ${total} document(s) with empty content"
echo "paperless-repair: mode=$([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN) limit=${LIMIT:-none} min_chars=$MIN_CHARS ocr_lang=$OCR_LANG"
echo "paperless-repair: gs=$GS_BIN"
echo "paperless-repair: ocrmypdf=$OCR_BIN"

processed=0
repaired=0
failed=0
skipped_enc=0
skipped_notext=0
skipped_img=0

while IFS=$'\t' read -r id mime filename title created corr dtype tags asn; do
  [ -n "$id" ] || continue
  if [ "$LIMIT" -gt 0 ] && [ "$processed" -ge "$LIMIT" ]; then
    echo "paperless-repair: limit reached (${LIMIT})"
    break
  fi
  processed=$((processed + 1))

  if [ "$mime" != "application/pdf" ]; then
    if [ "$INCLUDE_IMAGES" -eq 0 ]; then
      skipped_img=$((skipped_img + 1))
      continue
    fi
  fi

  src="$DATA_DIR/media/documents/originals/$filename"
  if [ ! -f "$src" ]; then
    echo "FAIL id=$id original missing: $src" >&2
    failed=$((failed + 1))
    continue
  fi

  w="$WORK/$id"
  mkdir -p "$w"
  cp "$src" "$w/orig.pdf"

  # Password-protected: no password here, and guessing is not our business.
  if pdfinfo "$w/orig.pdf" >/dev/null 2>&1; then :; else
    skipped_enc=$((skipped_enc + 1))
    echo "skip id=$id encrypted/password-protected (needs the bank password)"
    continue
  fi

  sigs=$(pdfsig "$w/orig.pdf" 2>/dev/null | grep -c "Signature #" || true)
  "$GS_BIN" -q -o "$w/clean.pdf" -sDEVICE=pdfwrite "$w/orig.pdf" >/dev/null 2>&1 || {
    echo "FAIL id=$id ghostscript rewrite failed" >&2
    failed=$((failed + 1))
    continue
  }

  if ! "$OCR_BIN" -f -l "$OCR_LANG" --output-type pdf --optimize 0 \
    "$w/clean.pdf" "$w/ocr.pdf" >"$w/ocr.log" 2>&1; then
    echo "FAIL id=$id ocrmypdf failed: $(tail -n1 "$w/ocr.log")" >&2
    failed=$((failed + 1))
    continue
  fi

  chars=$(pdftotext "$w/ocr.pdf" - 2>/dev/null | tr -d '[:space:]' | wc -c | tr -d ' ')
  if [ "$chars" -lt "$MIN_CHARS" ]; then
    skipped_notext=$((skipped_notext + 1))
    echo "skip id=$id no recoverable text (chars=$chars, signatures=$sigs)"
    rm -rf "$w"
    continue
  fi

  echo "candidate id=$id signatures=$sigs chars=$chars title='${title:0:60}'"

  if [ "$APPLY" -eq 0 ]; then
    continue
  fi

  # --- upload the repaired file with the ORIGINAL metadata ----------------
  args=(-sS --fail-with-body --max-time 300 -X POST
    -H "Authorization: Token $TOKEN" -H 'Accept: application/json'
    -F "document=@$w/ocr.pdf;type=application/pdf"
    -F "title=$title"
    -F "created=$created")
  [ -n "$corr" ] && args+=(-F "correspondent=$corr")
  [ -n "$dtype" ] && args+=(-F "document_type=$dtype")
  [ -n "$asn" ] && args+=(-F "archive_serial_number=$asn")
  if [ -n "$tags" ]; then
    IFS=',' read -r -a tag_arr <<<"$tags"
    for t in "${tag_arr[@]}"; do
      [ -n "$t" ] && args+=(-F "tags=$t")
    done
  fi

  if ! task="$(curl "${args[@]}" "$BASE/api/documents/post_document/" 2>"$w/up.err")"; then
    echo "FAIL id=$id upload failed: $(tail -n1 "$w/up.err")" >&2
    failed=$((failed + 1))
    continue
  fi
  task_id="$(printf '%s' "$task" | tr -d '"')"

  # --- wait for consumption, then verify the replacement has text ---------
  new_id=""
  for _ in $(seq 1 60); do
    sleep 5
    row="$(api GET "/api/tasks/?page_size=50" |
      jq -r --arg t "$task_id" 'first(.results[]? | select(.task_id == $t)) | "\(.status) \(.related_document // "")"')"
    st="${row%% *}"
    nd="${row##* }"
    case "$st" in
    success)
      new_id="$nd"
      break
      ;;
    failure | revoked)
      echo "FAIL id=$id consume task ${st}" >&2
      break
      ;;
    esac
  done

  if [ -z "$new_id" ]; then
    echo "FAIL id=$id replacement not confirmed (task ${task_id:-unknown})" >&2
    failed=$((failed + 1))
    continue
  fi

  new_len="$(api GET "/api/documents/$new_id/" | jq -r '.content | length')"
  if [ "${new_len:-0}" -lt "$MIN_CHARS" ]; then
    echo "FAIL id=$id replacement $new_id has no text (len=$new_len) - original kept" >&2
    failed=$((failed + 1))
    continue
  fi

  api DELETE "/api/documents/$id/" >/dev/null || {
    echo "FAIL id=$id replacement $new_id OK but deleting the original failed" >&2
    failed=$((failed + 1))
    continue
  }
  echo "repaired id=$id -> $new_id (chars=$new_len, original -> trash)"
  repaired=$((repaired + 1))
  rm -rf "$w"
done <"$WORK/candidates.tsv"

echo "paperless-repair: done - considered=$processed repaired=$repaired failed=$failed skipped_encrypted=$skipped_enc skipped_no_text=$skipped_notext skipped_images=$skipped_img"
[ "$failed" -eq 0 ]
