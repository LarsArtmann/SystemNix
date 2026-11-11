#!/usr/bin/env bash
# Archive the full Qonto document corpus (statements, transaction
# attachments, fee invoices) into Paperless-ngx and wire it to bank-sync.
#
# This is the convergent reconciliation pass for the pre-Wise Qonto era:
#
#   * every document carries canonical metadata (correspondent "Qonto",
#     statement/receipt/invoice document type, tags bank-sync + qonto),
#   * every attachment/invoice that can be matched to a bank-sync
#     transaction carries a bank-sync provenance custom field
#     (qonto/receipt/<transaction-uuid>), i.e. document -> transaction,
#   * every matched transaction is recorded in the bank-sync ledger
#     (paperless_receipt_uploads / paperless_uploads), i.e.
#     transaction -> document,
#   * statements are recorded per (balance, month) in paperless_uploads.
#
# Matching is deterministic and local (no bank APIs):
#   * attachments: filename date (Europe/Berlin calendar day, +/- 1 day),
#     absolute amount, then counterparty text; ties resolve least-used so
#     same-day/same-amount receipts spread across their transactions,
#   * fee invoices: "Bezahlter Betrag" extracted with pdftotext, matched to
#     the month's Qonto fee transactions,
#   * statements: org directory + YYYY-MM.
#
# Idempotence:
#   * documents are looked up by SHA-256 checksum before upload (Paperless
#     dedup is the authority), so re-runs never duplicate,
#   * metadata patches are diffed first; a converged run issues no writes,
#   * ledger inserts are INSERT OR IGNORE on the ledger primary keys.
#
# Usage:
#   archive-qonto-corpus.sh [--staging DIR] [--db PATH] [--url URL]
#     [--token-file PATH] [--source DRIVE_EXTRACT_ROOT] [--only KIND]
#     [--limit N] [--dry-run]
#
# --source stages the owner's extracted Google-Drive export into the
# staging tree first (the durable copy under the bank-sync dataDir is the
# normal operating state; a fresh host re-stages from the export).
set -euo pipefail

DEFAULT_STAGING="/mnt/pool/services/bank-sync/qonto-corpus"
DEFAULT_DB="/mnt/pool/services/bank-sync/data.db"
DEFAULT_URL="http://127.0.0.1:2892"
DEFAULT_TOKEN_FILE="/run/bank-sync-paperless/env"

STAGING=$DEFAULT_STAGING
DB=$DEFAULT_DB
URL=$DEFAULT_URL
TOKEN_FILE=$DEFAULT_TOKEN_FILE
SOURCE=""
ONLY="all"
LIMIT=0
DRY_RUN=0

usage() {
  sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'
}

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }
warn() { log "WARN: $*"; }
die() {
  log "ERROR: $*"
  exit 1
}

while (($#)); do
  case "$1" in
    --staging) STAGING=${2:?}; shift 2 ;;
    --db) DB=${2:?}; shift 2 ;;
    --url) URL=${2:?}; shift 2 ;;
    --token-file) TOKEN_FILE=${2:?}; shift 2 ;;
    --source) SOURCE=${2:?}; shift 2 ;;
    --only) ONLY=${2:?}; shift 2 ;;
    --limit) LIMIT=${2:?}; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

case "$ONLY" in
  all | statements | attachments | invoices) ;;
  *) die "--only must be one of: all statements attachments invoices" ;;
esac
[[ -r $DB ]] || die "database not readable: $DB"
command -v curl >/dev/null || die "curl not found"
command -v jq >/dev/null || die "jq not found"
command -v sqlite3 >/dev/null || die "sqlite3 not found"
command -v sha256sum >/dev/null || die "sha256sum not found"
command -v pdftotext >/dev/null || die "pdftotext not found"

TMPDIR_RUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_RUN"' EXIT

TOKEN=""
if ((DRY_RUN == 0)); then
  [[ -r $TOKEN_FILE ]] || die "paperless token file not readable: $TOKEN_FILE"
  TOKEN=$(sed -n 's/^BANK_SYNC_PAPERLESS_TOKEN=//p' "$TOKEN_FILE")
  [[ -n $TOKEN ]] || die "no BANK_SYNC_PAPERLESS_TOKEN in $TOKEN_FILE"
  # Never place the token in curl's argv (process list); -K - reads the
  # header from stdin instead.
  curl() {
    command curl -K - "$@"
  }
fi

# curl_with_token <curl args...>: stdin carries the auth header config.
curl_with_token() {
  printf 'header = "Authorization: Token %s"\n' "$TOKEN" | curl "$@"
}

API_CODE=""
API_BODY=""

api_call() {
  local method=$1 path=$2 data=${3-}
  local out="$TMPDIR_RUN/body" code
  local args=(-sS -o "$out" -w '%{http_code}' -X "$method" "$URL$path")
  if [[ -n $data ]]; then
    args+=(--data-binary "$data" -H 'Content-Type: application/json')
  fi
  code=$(curl_with_token "${args[@]}")
  API_CODE=$code
  API_BODY=$(<"$out")
}

urlencode() { jq -rn --arg v "$1" '$v | @uri'; }

sql_quote() { printf "'%s'" "${1//\'/\'\'}"; }

normalize_text() {
  tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/ /g; s/^ +//; s/ +$//'
}

human_amount() {
  # cents -> "1234.56"
  local cents=$1
  printf '%d.%02d' $((cents / 100)) $((cents % 100))
}

# ── staging ──────────────────────────────────────────────────────────────

stage_from_source() {
  local src=$1
  local d
  for d in \
    "$src/Artmann Technologies/Qonto AT/2024" \
    "$src/Artmann Technologies/Qonto AT/2025" \
    "$src/Artmann Holding/statements"; do
    [[ -d $d ]] || die "source tree missing: $d"
  done
  local tech_archive="$src/Artmann Technologies/Qonto AT/2025-02-24 Export AT"
  local hold_archive="$src/Artmann Holding/2025-02-24 Export"
  local tech_archive_dir hold_archive_dir
  tech_archive_dir=$(find "$tech_archive" -maxdepth 1 -type d -name '*_qonto_archive' | head -n1)
  hold_archive_dir=$(find "$hold_archive" -maxdepth 1 -type d -name '*_qonto_archive' | head -n1)
  [[ -n $tech_archive_dir ]] || die "no *_qonto_archive under: $tech_archive"
  [[ -n $hold_archive_dir ]] || die "no *_qonto_archive under: $hold_archive"

  mkdir -p \
    "$STAGING/statements/technologies" \
    "$STAGING/statements/holding" \
    "$STAGING/attachments/technologies" \
    "$STAGING/attachments/holding"
  rsync -a "$src/Artmann Technologies/Qonto AT/2024/" "$STAGING/statements/technologies/2024/"
  rsync -a "$src/Artmann Technologies/Qonto AT/2025/" "$STAGING/statements/technologies/2025/"
  rsync -a "$src/Artmann Holding/statements/" "$STAGING/statements/holding/"
  rsync -a "$tech_archive_dir/" "$STAGING/attachments/technologies/"
  rsync -a "$hold_archive_dir/" "$STAGING/attachments/holding/"
  log "staged corpus from $src into $STAGING"
}

if [[ -n $SOURCE ]]; then
  if ((DRY_RUN == 0)); then
    stage_from_source "$SOURCE"
  else
    log "dry-run: would stage corpus from $SOURCE into $STAGING"
  fi
fi

for d in "$STAGING/statements/technologies" "$STAGING/statements/holding" \
  "$STAGING/attachments/technologies" "$STAGING/attachments/holding"; do
  [[ -d $d ]] || die "staging tree missing: $d"
done

# ── transactions ─────────────────────────────────────────────────────────

BIZ_PROFILE=346886142562832858
HOLDING_PROFILE=177464864807216081
BIZ_BALANCE=54255095370649615
HOLDING_BALANCE=8342493570783497676

declare -A TX_KEY=()
declare -A TX_MONTH=()
declare -A TX_DATE=()
declare -A TX_LINKS=()

load_transactions() {
  local id ts amount desc merchant pid day norm key month
  while IFS=$'\t' read -r id ts amount desc merchant pid; do
    [[ -n $id ]] || continue
    day=$(TZ=Europe/Berlin date -d "$ts" +%F)
    norm=$(printf '%s %s' "$desc" "$merchant" | normalize_text)
    key="$pid|$day|$amount"
    TX_KEY["$key"]+="$id"$'\t'"$norm"$'\n'
    TX_DATE["$id"]=$ts
    month=$(TZ=Europe/Berlin date -d "$ts" +%Y-%m)
    if [[ $norm == *qonto* ]]; then
      key="$pid|$month|$amount"
      TX_MONTH["$key"]+="$id"$'\n'
    fi
  done < <(sqlite3 -readonly -separator $'\t' "$DB" \
    "select id,date,amount_value,coalesce(description,''),coalesce(merchant_name,''),profile_id
       from transactions where provider='qonto';")
}

load_transactions

pick_candidate() {
  # pick_candidate <newline-separated id<TAB>text> <counterparty-normalized>
  local blob=$1 cp=$2
  local ids=() id text n best best_count
  while IFS=$'\t' read -r id text; do
    [[ -n $id ]] || continue
    ids+=("$id")
  done <<<"$blob"
  ((${#ids[@]})) || return 1
  if ((${#ids[@]} == 1)); then
    printf '%s' "${ids[0]}"
    return 0
  fi
  if [[ -n $cp ]]; then
    local hits=()
    while IFS=$'\t' read -r id text; do
      [[ -n $id ]] || continue
      if [[ $text == *"$cp"* ]] || [[ $cp == *"$text"* ]]; then
        hits+=("$id")
      fi
    done <<<"$blob"
    if ((${#hits[@]} == 1)); then
      printf '%s' "${hits[0]}"
      return 0
    fi
    ((${#hits[@]} > 1)) && ids=("${hits[@]}")
  fi
  # Least-used tie-break: spreads same-day/same-amount receipts across
  # their transactions instead of piling every document on the first id.
  best=""
  best_count=0
  for id in "${ids[@]}"; do
    n=${TX_LINKS[$id]:-0}
    if [[ -z $best ]] || ((n < best_count)) || { ((n == best_count)) && [[ $id < $best ]]; }; then
      best=$id
      best_count=$n
    fi
  done
  printf '%s' "$best"
}

find_tx() {
  # find_tx <profile> <YYYY-MM-DD> <amount-cents> <counterparty>
  local pid=$1 day=$2 amount=$3 cp=$4
  local d cands id
  for d in "$day"; do
    cands=${TX_KEY["$pid|$d|$amount"]-}
    if [[ -n $cands ]]; then
      id=$(pick_candidate "$cands" "$cp") || true
      [[ -n $id ]] && {
        printf '%s' "$id"
        return 0
      }
    fi
  done
  local prev next
  prev=$(date -d "$day -1 day" +%F)
  next=$(date -d "$day +1 day" +%F)
  for d in "$prev" "$next"; do
    cands=${TX_KEY["$pid|$d|$amount"]-}
    if [[ -n $cands ]]; then
      id=$(pick_candidate "$cands" "$cp") || true
      [[ -n $id ]] && {
        printf '%s' "$id"
        return 0
      }
    fi
  done
  return 1
}

find_invoice_tx() {
  # find_invoice_tx <profile> <YYYY-MM> <amount-cents>
  local pid=$1 month=$2 amount=$3
  local cands=${TX_MONTH["$pid|$month|$amount"]-}
  [[ -n $cands ]] || return 1
  pick_candidate "$cands" ""
}

# ── plan ─────────────────────────────────────────────────────────────────

PLAN="$TMPDIR_RUN/plan.tsv"
: >"$PLAN"

add_plan() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >>"$PLAN"; }

sha_of() { sha256sum "$1" | cut -d' ' -f1; }

enumerate_statements() {
  local f base month org entity bal sha wstart wend fname
  while IFS= read -r -d '' f; do
    base=${f##*/}
    month=${base:0:7}
    [[ $month =~ ^[0-9]{4}-[0-9]{2}$ ]] || {
      warn "statement without YYYY-MM prefix: $f"
      continue
    }
    case "$f" in
      */statements/technologies/*)
        org=technologies
        entity="Artmann Technologies GmbH"
        bal=$BIZ_BALANCE
        ;;
      */statements/holding/*)
        org=holding
        entity="Artmann Holding GmbH"
        bal=$HOLDING_BALANCE
        ;;
      *)
        warn "statement outside a known org tree: $f"
        continue
        ;;
    esac
    sha=$(sha_of "$f")
    wstart="${month}-01"
    wend=$(date -d "$wstart +1 month -1 day" +%F)
    fname=${f##*/}
    add_plan statement "$org" "$f" "$sha" "$wstart" \
      "Qonto Statement - $entity - $month" bank_sync_statement \
      "qonto/$bal/$month" "Bank Statement" - - "$bal" "$wstart" "$wend" "$fname" ""
  done < <(find "$STAGING/statements" -type f -name '*.pdf' -print0 | sort -z)
}

enumerate_attachments() {
  local org profile f base date cp cur whole frac amt hash tx txdate sha entity
  local cp_title cp_norm
  while IFS= read -r -d '' f; do
    base=${f##*/}
    case "$f" in
      */attachments/technologies/*)
        org=technologies
        profile=$BIZ_PROFILE
        ;;
      */attachments/holding/*)
        org=holding
        profile=$HOLDING_PROFILE
        ;;
      *) continue ;;
    esac
    if [[ $ONLY != invoices ]] && [[ $base =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})\ -\ (.*)\ -\ ([A-Z]{3})\ ([0-9.]+)[_,]([0-9]{2})\ -\ ([0-9a-f]{8})\.(pdf|png)$ ]]; then
      date=${BASH_REMATCH[1]}
      cp=${BASH_REMATCH[2]}
      cur=${BASH_REMATCH[3]}
      whole=${BASH_REMATCH[4]//./}
      frac=${BASH_REMATCH[5]}
      hash=${BASH_REMATCH[6]}
      [[ $cur == EUR ]] || {
        warn "non-EUR attachment skipped for linking (still archived): $base"
      }
      amt=$((10#$whole * 100 + 10#$frac))
      cp_title=${cp//_/ }
      cp_title=$(printf '%s' "$cp_title" | sed -E 's/ +/ /g; s/^ +//; s/ +$//')
      cp_norm=$(printf '%s' "$cp" | normalize_text)
      tx=$(find_tx "$profile" "$date" "$amt" "$cp_norm") || tx=""
      if [[ -n $tx ]]; then
        TX_LINKS["$tx"]=$((${TX_LINKS["$tx"]:-0} + 1))
        txdate=${TX_DATE["$tx"]}
        add_plan attachment "$org" "$f" "$(sha_of "$f")" "$date" \
          "$date - $cp_title - $cur $(human_amount "$amt")" bank_sync_receipt \
          "qonto/receipt/$tx" "Bank Receipt" "$tx" "$txdate" - - - "$base" ""
      else
        add_plan attachment "$org" "$f" "$(sha_of "$f")" "$date" \
          "$date - $cp_title - $cur $(human_amount "$amt")" bank_sync_receipt \
          "qonto/receipt-local/$hash" "Bank Receipt" - "$date 00:00:00+00:00" - - - "$base" \
          "bank-sync-unmatched"
      fi
    elif [[ $ONLY != attachments ]] && [[ $base =~ ^([0-9]{4})-([0-9]{2})\ -\ Qonto\ -\ ([0-9a-f]{8})\.pdf$ ]]; then
      # Qonto fee invoice: only the month is in the name; the paid total
      # inside the PDF identifies the fee transaction.
      local month="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
      hash=${BASH_REMATCH[3]}
      amt=$(pdftotext -layout "$f" - 2>/dev/null |
        grep -A1 'Bezahlter Betrag' | tail -n1 |
        grep -oE '€ ?[0-9.]+,[0-9]{2}' | tail -n1 |
        sed -E 's/€ ?//; s/\.//g; s/,//' || true)
      if [[ -n $amt ]]; then
        amt=$((10#$amt))
        tx=$(find_invoice_tx "$profile" "$month" "$amt") || tx=""
      else
        tx=""
      fi
      case "$org" in
        technologies) entity="Artmann Technologies GmbH" ;;
        holding) entity="Artmann Holding GmbH" ;;
      esac
      if [[ -n $tx ]]; then
        TX_LINKS["$tx"]=$((${TX_LINKS["$tx"]:-0} + 1))
        txdate=${TX_DATE["$tx"]}
        add_plan invoice "$org" "$f" "$(sha_of "$f")" "${month}-01" \
          "Qonto Rechnung - $entity - $month" bank_sync_receipt \
          "qonto/receipt/$tx" "Invoice" "$tx" "$txdate" - - - "$base" ""
      else
        add_plan invoice "$org" "$f" "$(sha_of "$f")" "${month}-01" \
          "Qonto Rechnung - $entity - $month" bank_sync_receipt \
          "qonto/invoice/$hash" "Invoice" - "${month}-01 00:00:00+00:00" - - - "$base" \
          "bank-sync-unmatched"
      fi
    else
      SKIPPED_DATA=$((SKIPPED_DATA + 1))
      log "skipping non-document corpus file: $base"
    fi
  done < <(find "$STAGING/attachments" -type f -print0 | sort -z)
}

SKIPPED_DATA=0
case "$ONLY" in
  all)
    enumerate_statements
    enumerate_attachments
    ;;
  statements) enumerate_statements ;;
  attachments | invoices) enumerate_attachments ;;
esac

if [[ ! -s $PLAN ]]; then
  die "no documents planned - check --staging ($STAGING)"
fi

log "plan built: $(( $(wc -l <"$PLAN") )) documents, $SKIPPED_DATA non-document files skipped"
if ((DRY_RUN == 1)); then
  awk -F'\t' '
    { n[$1]++; if ($10 != "-") linked[$1]++ }
    END {
      for (k in n) printf "  %s: %d documents, %d transaction-linked\n", k, n[k], linked[k] + 0
    }' "$PLAN" >&2
  cut -f1,5,6,7,8,10 "$PLAN" | sed 's/\t/ | /g' | head -n 12
  log "dry-run complete (no API or DB writes)"
  exit 0
fi

# ── Paperless metadata registry ──────────────────────────────────────────

ensure_named() {
  local endpoint=$1 name=$2 create_extra=${3:-'{}'}
  local id
  api_call GET "/api/$endpoint/?name__iexact=$(urlencode "$name")"
  [[ $API_CODE == 200 ]] || die "GET /api/$endpoint/ -> HTTP $API_CODE: $API_BODY"
  id=$(jq -r '.results[0].id // empty' <<<"$API_BODY")
  if [[ -z $id ]]; then
    local payload
    payload=$(jq -nc --arg n "$name" --argjson extra "$create_extra" \
      '{name: $n} + $extra')
    api_call POST "/api/$endpoint/" "$payload"
    [[ $API_CODE == 201 ]] || die "POST /api/$endpoint/ ($name) -> HTTP $API_CODE: $API_BODY"
    id=$(jq -r '.id' <<<"$API_BODY")
    log "created $endpoint '$name' (id $id)"
  fi
  case "$id" in
    "" | *[!0-9]*) die "non-numeric id for $endpoint '$name': '$id'" ;;
  esac
  printf '%s' "$id"
}

CORR=$(ensure_named correspondents Qonto)
DOCTYPE_STATEMENT=$(ensure_named document_types "Bank Statement")
DOCTYPE_RECEIPT=$(ensure_named document_types "Bank Receipt")
DOCTYPE_INVOICE=$(ensure_named document_types Invoice)
TAG_BS=$(ensure_named tags bank-sync)
TAG_QONTO=$(ensure_named tags qonto)
TAG_UNMATCHED=$(ensure_named tags bank-sync-unmatched)
FIELD_STATEMENT=$(ensure_named custom_fields bank_sync_statement '{"data_type":"string"}')
FIELD_RECEIPT=$(ensure_named custom_fields bank_sync_receipt '{"data_type":"string"}')

log "metadata: correspondent=$CORR statement_type=$DOCTYPE_STATEMENT receipt_type=$DOCTYPE_RECEIPT invoice_type=$DOCTYPE_INVOICE tags=$TAG_BS,$TAG_QONTO,$TAG_UNMATCHED fields=$FIELD_STATEMENT,$FIELD_RECEIPT"

find_doc_by_sha() {
  api_call GET "/api/documents/?checksum__iexact=$1&fields=id"
  [[ $API_CODE == 200 ]] || die "checksum lookup -> HTTP $API_CODE: $API_BODY"
  jq -r '.results[0].id // empty' <<<"$API_BODY"
}

wait_task() {
  local task=$1 i status docid
  for ((i = 0; i < 300; i++)); do
    sleep 2
    api_call GET "/api/tasks/?task_id=$task"
    status=$(jq -r '.results[0].status // empty' <<<"$API_BODY")
    case "$status" in
      success)
        docid=$(jq -r '.results[0].result_data.document_id // (.results[0].related_document_ids[0] // empty)' <<<"$API_BODY")
        [[ -n $docid ]] || die "task $task succeeded without a document id"
        printf '%s' "$docid"
        return 0
        ;;
      failure)
        docid=$(jq -r '.results[0].result_data.duplicate_of // empty' <<<"$API_BODY")
        if [[ -n $docid ]]; then
          printf '%s' "$docid"
          return 0
        fi
        warn "task $task failed: $(jq -c '.results[0].result_data // {}' <<<"$API_BODY")"
        return 1
        ;;
    esac
  done
  warn "task $task did not finish within 10 minutes"
  return 1
}

upload_document() {
  # upload_document <file> <title> <created> <doctype> <fieldid> <value> <extra-tag|"">
  local file=$1 title=$2 created=$3 doctype=$4 fieldid=$5 value=$6 extra=${7-}
  local out="$TMPDIR_RUN/upload-body" code task
  local args=(-sS -o "$out" -w '%{http_code}' -X POST
    "$URL/api/documents/post_document/"
    -F "document=@$file"
    -F "title=$title"
    -F "created=$created"
    -F "correspondent=$CORR"
    -F "document_type=$doctype"
    -F "tags=$TAG_BS"
    -F "tags=$TAG_QONTO")
  [[ -n $extra ]] && args+=(-F "tags=$extra")
  args+=(-F "custom_fields={\"$fieldid\":\"$value\"}")
  code=$(curl_with_token "${args[@]}")
  if [[ $code != 200 ]]; then
    warn "upload failed for $file (HTTP $code): $(<"$out")"
    return 1
  fi
  task=$(jq -r '.' <"$out")
  [[ -n $task && $task != null ]] || {
    warn "upload for $file returned no task id: $(<"$out")"
    return 1
  }
  wait_task "$task"
}

patch_document() {
  # patch_document <docid> <title> <created> <doctype> <fieldid> <value> <extra-tag|"">
  local docid=$1 title=$2 created=$3 doctype=$4 fieldid=$5 value=$6 extra=${7-}
  local current tags_json cf_json payload
  api_call GET "/api/documents/$docid/?fields=id,tags,custom_fields,title,created,correspondent,document_type"
  [[ $API_CODE == 200 ]] || {
    warn "GET document $docid -> HTTP $API_CODE"
    return 1
  }
  current=$API_BODY
  tags_json=$(jq -c --argjson bs "$TAG_BS" --argjson q "$TAG_QONTO" --argjson u "${extra:-0}" \
    '[.tags[]?, $bs, $q, (if $u == 0 then empty else $u end)] | unique' <<<"$current")
  cf_json=$(jq -c --argjson fid "$fieldid" --arg val "$value" '
    (.custom_fields // []) as $cf
    | (($cf | map(select(.field != $fid))) + [{"field": $fid, "value": $val}])
    | sort_by(.field)' <<<"$current")
  if [[ $(jq -c '.tags // [] | sort' <<<"$current") == "$(jq -c 'sort' <<<"$tags_json")" ]] &&
    [[ $(jq -c '(.custom_fields // []) | sort_by(.field)' <<<"$current") == "$cf_json" ]] &&
    [[ $(jq -r '.title' <<<"$current") == "$title" ]] &&
    [[ $(jq -r '.created' <<<"$current") == "$created" ]] &&
    [[ $(jq -r '.correspondent // 0' <<<"$current") == "$CORR" ]] &&
    [[ $(jq -r '.document_type // 0' <<<"$current") == "$doctype" ]]; then
    return 2 # already canonical
  fi
  payload=$(jq -nc \
    --arg title "$title" --arg created "$created" \
    --argjson corr "$CORR" --argjson dtype "$doctype" \
    --argjson tags "$tags_json" --argjson cf "$cf_json" \
    '{title: $title, created: $created, correspondent: $corr,
      document_type: $dtype, tags: $tags, custom_fields: $cf}')
  api_call PATCH "/api/documents/$docid/" "$payload"
  [[ $API_CODE == 200 ]] || {
    warn "PATCH document $docid -> HTTP $API_CODE: $API_BODY"
    return 1
  }
}

ledger_statement() {
  # ledger_statement <balance> <window_start> <window_end> <checksum> <docid> <filename>
  local bal=$1 ws=$2 we=$3 sha=$4 docid=$5 fname=$6
  sqlite3 -batch "$DB" ".timeout 15000
    INSERT OR IGNORE INTO paperless_uploads
      (provider, balance_id, window_start, window_end, currency, checksum,
       document_id, duplicate, filename, uploaded_at)
    VALUES ('qonto', $bal, $(sql_quote "$ws 00:00:00+00:00"),
            $(sql_quote "$we 00:00:00+00:00"), 'EUR',
            $(sql_quote "$sha"), $docid, 0, $(sql_quote "$fname"),
            strftime('%Y-%m-%d %H:%M:%S+00:00','now'));"
}

ledger_receipt() {
  # ledger_receipt <txid> <checksum> <docid> <filename> <txdate>
  local txid=$1 sha=$2 docid=$3 fname=$4 txdate=$5
  local txdate_sql=null
  [[ -n $txdate && $txdate != - ]] && txdate_sql=$(sql_quote "$txdate")
  sqlite3 -batch "$DB" ".timeout 15000
    INSERT OR IGNORE INTO paperless_receipt_uploads
      (provider, external_id, kind, checksum, document_id, duplicate,
       filename, tx_date, uploaded_at)
    VALUES ('qonto', $(sql_quote "$txid"), 'receipt', $(sql_quote "$sha"),
            $docid, 0, $(sql_quote "$fname"), $txdate_sql,
            strftime('%Y-%m-%d %H:%M:%S+00:00','now'));"
}

# ── execute ──────────────────────────────────────────────────────────────

COUNT_PLANNED=$(wc -l <"$PLAN")
COUNT_UPLOADED=0
COUNT_PRESENT=0
COUNT_PATCHED=0
COUNT_CANONICAL=0
COUNT_LINKED=0
COUNT_UNLINKED=0
COUNT_FAILURES=0
COUNT_STATEMENTS=0
COUNT_ATTACHMENTS=0
COUNT_INVOICES=0
COUNT_LEDGER=0

while IFS=$'\t' read -r kind org path sha created title fieldname fieldvalue doctype txid txdate bal wstart wend fname extra; do
  if ((LIMIT > 0 && COUNT_UPLOADED >= LIMIT)); then
    log "limit reached ($LIMIT uploads); stopping - re-run to continue"
    break
  fi
  case "$kind" in
    statement) COUNT_STATEMENTS=$((COUNT_STATEMENTS + 1)) ;;
    attachment) COUNT_ATTACHMENTS=$((COUNT_ATTACHMENTS + 1)) ;;
    invoice) COUNT_INVOICES=$((COUNT_INVOICES + 1)) ;;
  esac

  fieldid=$FIELD_RECEIPT
  [[ $kind == statement ]] && fieldid=$FIELD_STATEMENT

  # The plan carries the human document-type name; the API needs the id.
  case "$doctype" in
    "Bank Statement") dtype_id=$DOCTYPE_STATEMENT ;;
    "Bank Receipt") dtype_id=$DOCTYPE_RECEIPT ;;
    Invoice) dtype_id=$DOCTYPE_INVOICE ;;
    *) die "unknown document type in plan: $doctype" ;;
  esac

  extra_tag=""
  [[ $extra == bank-sync-unmatched ]] && extra_tag=$TAG_UNMATCHED

  docid=$(find_doc_by_sha "$sha")
  if [[ -n $docid ]]; then
    COUNT_PRESENT=$((COUNT_PRESENT + 1))
  else
    docid=$(upload_document "$path" "$title" "$created" "$dtype_id" "$fieldid" "$fieldvalue" "$extra_tag") || {
      COUNT_FAILURES=$((COUNT_FAILURES + 1))
      continue
    }
    COUNT_UPLOADED=$((COUNT_UPLOADED + 1))
    log "uploaded $kind $fname -> document $docid"
  fi

  patch_rc=0
  patch_document "$docid" "$title" "$created" "$dtype_id" "$fieldid" "$fieldvalue" "$extra_tag" || patch_rc=$?
  case "$patch_rc" in
    0) COUNT_PATCHED=$((COUNT_PATCHED + 1)) ;;
    2) COUNT_CANONICAL=$((COUNT_CANONICAL + 1)) ;;
    *) COUNT_FAILURES=$((COUNT_FAILURES + 1)) ;;
  esac

  if [[ $kind == statement ]]; then
    ledger_statement "$bal" "$wstart" "$wend" "$sha" "$docid" "$fname"
    COUNT_LEDGER=$((COUNT_LEDGER + 1))
  elif [[ -n $txid && $txid != - ]]; then
    ledger_receipt "$txid" "$sha" "$docid" "$fname" "$txdate"
    COUNT_LEDGER=$((COUNT_LEDGER + 1))
    COUNT_LINKED=$((COUNT_LINKED + 1))
  else
    COUNT_UNLINKED=$((COUNT_UNLINKED + 1))
  fi

  if ((COUNT_UPLOADED % 25 == 0 && COUNT_UPLOADED > 0)); then
    log "progress: uploaded=$COUNT_UPLOADED present=$COUNT_PRESENT patched=$COUNT_PATCHED failures=$COUNT_FAILURES"
  fi
done <"$PLAN"

cat >&2 <<SUMMARY
qonto corpus archive complete
  documents_planned=$COUNT_PLANNED
  statements=$COUNT_STATEMENTS attachments=$COUNT_ATTACHMENTS invoices=$COUNT_INVOICES
  already_present=$COUNT_PRESENT uploaded=$COUNT_UPLOADED
  metadata_patched=$COUNT_PATCHED already_canonical=$COUNT_CANONICAL
  linked_transactions=$COUNT_LINKED unlinked_documents=$COUNT_UNLINKED
  ledger_rows_written=$COUNT_LEDGER
  skipped_data_files=$SKIPPED_DATA
  failures=$COUNT_FAILURES
SUMMARY

if ((COUNT_FAILURES > 0)); then
  exit 1
fi
