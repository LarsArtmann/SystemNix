#!/usr/bin/env bash
# paperless-decision-bench.sh — benchmark decision models (Cloudflare Clef, TypeSafe Jev)
# against REAL paperless-ngx documents (receipts, invoices, general scans).
#
# Corpus + ground truth come from live paperless metadata (owner-curated tags,
# document types). Page-1 images are rendered from the ORIGINALS (no OCR) —
# this measures PRE-OCR triage: classification + confidence calibration.
#
# PRIVACY: the image arm sends page-1 scans of receipts/invoices/general scans
# to Cloudflare and TypeSafe (document images LEAVE THE LAN — owner-sanctioned
# for exactly these classes). Bank statements tagged `encrypted` are excluded
# from the image arm; the text arm sends only extracted text.
#
# Secrets: platforms/nixos/secrets/decision-bench.yaml (cloudflare_account_id,
# cloudflare_api_token, typesafe_api_key), created by --setup-secrets with
# PLACEHOLDER values; or env vars TYPESAFE_API_KEY / CLOUDFLARE_API_TOKEN /
# CLOUDFLARE_ACCOUNT_ID.
#
# Usage:
#   scripts/paperless-decision-bench.sh --probe
#   scripts/paperless-decision-bench.sh --corpus [--n N]
#   scripts/paperless-decision-bench.sh --bench clef,jev [--also-text]
#   scripts/paperless-decision-bench.sh --score
#   scripts/paperless-decision-bench.sh --setup-secrets
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"
WORK_DIR="${HOME}/.cache/paperless-decision-bench"
mkdir -p "$WORK_DIR"
PAPERLESS_URL="http://127.0.0.1:2892"
SOPS_FILE="${REPO_ROOT}/platforms/nixos/secrets/decision-bench.yaml"
CLEF_MODEL="@cf/cloudflare/clef"
JEV_MODEL="jev-latest"

ENCRYPTED_TAG="encrypted"
BILL_DTYPE="Bill"

die() {
  echo "ERROR: $*" >&2
  exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
need curl
need jq
need pdftoppm
need od

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then bash -c "$1"; else sudo bash -c "$1"; fi
}

manage_py() {
  local pyfile="$1"
  as_root "runuser -u paperless -- /run/current-system/sw/bin/paperless-manage shell < '${pyfile}'" | grep -vE 'objects imported automatically|^Wrote '
}

mint_token() {
  local py tmp token
  py='from django.contrib.auth.models import User
from allauth.socialaccount.models import SocialAccount
from rest_framework.authtoken.models import Token
sa = SocialAccount.objects.first()
user = sa.user if sa else User.objects.filter(is_superuser=True).order_by("id").first()
t, _ = Token.objects.get_or_create(user=user)
print(user.username)
print(t.key)
'
  tmp="$(mktemp "${WORK_DIR}/.mint.XXXXXX.py")"
  printf '%s' "$py" >"$tmp"
  token="$(manage_py "$tmp" | grep -oE '\b[a-f0-9]{40}\b' | tail -1)"
  rm -f "$tmp"
  [[ -n $token ]] || die "DRF token mint failed"
  printf '%s' "$token"
}

api() { curl --silent --fail-with-body -H "Authorization: Token ${1}" "${PAPERLESS_URL}${2}"; }

probe() {
  local py tmp
  py='from documents.models import Document, Tag, DocumentType, CustomField
print("TOTAL", Document.objects.count())
for t in Tag.objects.all().order_by("id"):
    print("TAG", t.id, t.name, Document.objects.filter(tags=t).count())
for d in DocumentType.objects.all().order_by("id"):
    print("DTYPE", d.id, d.name, Document.objects.filter(document_type=d).count())
for c in CustomField.objects.all().order_by("id"):
    print("CFIELD", c.id, c.name, c.data_type)
'
  tmp="$(mktemp "${WORK_DIR}/.probe.XXXXXX.py")"
  printf '%s' "$py" >"$tmp"
  manage_py "$tmp" | grep -v __paperless_write_test
  rm -f "$tmp"
}

build_corpus() {
  local n="${1:-10}"
  mkdir -p "${WORK_DIR}/images"
  local token
  token="$(mint_token)"
  echo "staging corpus (${n}/class) into ${WORK_DIR}"
  local py tmp
  py="from django.db.models import Q
from documents.models import Document, Tag, DocumentType
new = Tag.objects.filter(name=\"new\").values_list(\"id\", flat=True).first()
enc = Tag.objects.filter(name=\"${ENCRYPTED_TAG}\").values_list(\"id\", flat=True).first()
bill = DocumentType.objects.filter(name=\"${BILL_DTYPE}\").values_list(\"id\", flat=True).first()
invoice_like = Q(title__icontains=\"invoice\") | Q(title__icontains=\"faktura\") | Q(title__icontains=\"Faktura\")
receipt_ids = set(Document.objects.filter(document_type=bill).values_list(\"id\", flat=True)) if bill else set()
invoice_ids = set(Document.objects.filter(invoice_like).exclude(id__in=receipt_ids).values_list(\"id\", flat=True))
encrypted_ids = set(Document.objects.filter(tags__id=enc).values_list(\"id\", flat=True)) if enc else set()
general = (Document.objects.filter(document_type__isnull=True, tags__id=new)
           .exclude(invoice_like).exclude(content=\"\")
           .exclude(id__in=receipt_ids | invoice_ids | encrypted_ids).order_by(\"-created\"))
def emit(cls, ids):
    print(\"CLASS\", cls, list(ids))
emit(\"receipt\", sorted(receipt_ids)[:${n}])
emit(\"invoice\", sorted(invoice_ids)[:${n}])
emit(\"general\", list(general.values_list(\"id\", flat=True)[:${n}]))
emit(\"encrypted\", sorted(encrypted_ids)[:${n}])
print(\"META counts receipt/invoice/general/encrypted\", len(receipt_ids), len(invoice_ids), general.count(), len(encrypted_ids))
"
  tmp="$(mktemp "${WORK_DIR}/.corpus.XXXXXX.py")"
  printf '%s' "$py" >"$tmp"
  manage_py "$tmp" >"${WORK_DIR}/classes.raw"
  rm -f "$tmp"
  cat "${WORK_DIR}/classes.raw"

  printf 'doc_id\tclass\ttitle\tfile\n' >"${WORK_DIR}/corpus.tsv"
  local line class ids id docjson title imgpath
  while IFS= read -r line; do
    [[ $line == "CLASS "* ]] || continue
    class="${line#CLASS }"
    class="${class%% *}"
    ids="$(cut -d' ' -f3- <<<"$line" | tr -d '[],')"
    for id in $ids; do
      [[ $id =~ ^[0-9]+$ ]] || continue
      docjson="$(api "$token" "/api/documents/${id}/")" || {
        echo "WARN: api fetch failed for ${id}" >&2
        continue
      }
      title="$(jq -r '.title' <<<"$docjson")"
      if imgpath="$(stage_image "$token" "$id")"; then
        printf '%s\t%s\t%s\t%s\n' "$id" "$class" "$title" "${imgpath#"${WORK_DIR}"/}" >>"${WORK_DIR}/corpus.tsv"
      else
        printf '%s\t%s\t%s\tMISSING\n' "$id" "$class" "$title" >>"${WORK_DIR}/corpus.tsv"
      fi
    done
  done <"${WORK_DIR}/classes.raw"

  echo "--- corpus.tsv ---"
  cat "${WORK_DIR}/corpus.tsv"
  echo "next: $0 --bench clef,jev"
}

sniff_kind() {
  local magic
  magic="$(od -An -tx1 -N4 "$1" | tr -d ' \n')"
  case "$magic" in
  25504446*) echo application/pdf ;;
  ffd8ff*) echo image/jpeg ;;
  89504e47*) echo image/png ;;
  *) echo application/octet-stream ;;
  esac
}

stage_image() {
  local token="$1" id="$2" out="${WORK_DIR}/images/${2}"
  if compgen -G "${out}.jpg" >/dev/null || compgen -G "${out}.png" >/dev/null; then
    find "$out.jpg" "$out.png" -maxdepth 0 2>/dev/null | head -1
    return 0
  fi
  local tmp
  tmp="$(mktemp "${WORK_DIR}/.orig-${id}.XXXXXX")"
  api "$token" "/api/documents/${id}/download/" >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  local kind
  kind="$(sniff_kind "$tmp")"
  case "$kind" in
  application/pdf) pdftoppm -jpeg -r 100 -scale-to 1400 -f 1 -l 1 -singlefile "$tmp" "$out" ;;
  image/jpeg) cp "$tmp" "${out}.jpg" ;;
  image/png) cp "$tmp" "${out}.png" ;;
  *)
    rm -f "$tmp"
    return 1
    ;;
  esac
  rm -f "$tmp"
  if [[ -s "${out}.jpg" ]]; then echo "${out}.jpg"; elif [[ -s "${out}.png" ]]; then echo "${out}.png"; else return 1; fi
}

load_secrets() {
  local models="$1"
  local need_jev=false need_clef=false
  [[ $models == *jev* ]] && need_jev=true
  [[ $models == *clef* ]] && need_clef=true
  local have_env=true
  [[ -z ${TYPESAFE_API_KEY:-} ]] && have_env=false
  if $have_env; then
    return
  fi
  [[ -f $SOPS_FILE ]] || die "no env vars and no ${SOPS_FILE}; run: $0 --setup-secrets"
  local age_key
  age_key="$(as_root "cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key")"
  export SOPS_AGE_KEY="${age_key}"
  TYPESAFE_API_KEY="$(sops -d --extract '["typesafe_api_key"]' "$SOPS_FILE")"
  CLOUDFLARE_API_TOKEN="$(sops -d --extract '["cloudflare_api_token"]' "$SOPS_FILE")"
  CLOUDFLARE_ACCOUNT_ID="$(sops -d --extract '["cloudflare_account_id"]' "$SOPS_FILE")"
  export TYPESAFE_API_KEY CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
  unset SOPS_AGE_KEY
  if $need_jev; then
    [[ $TYPESAFE_API_KEY != PLACEHOLDER* && -n $TYPESAFE_API_KEY ]] ||
      die "typesafe_api_key in ${SOPS_FILE} is still PLACEHOLDER"
  fi
  if $need_clef; then
    [[ $CLOUDFLARE_API_TOKEN != PLACEHOLDER* && $CLOUDFLARE_ACCOUNT_ID != PLACEHOLDER* ]] ||
      die "cloudflare keys in ${SOPS_FILE} are still PLACEHOLDER (owner: dash.cloudflare.com account id + Workers AI Read+Run token)"
  fi
}

questions_json() {
  cat <<'JSON'
{
  "doc_class": {
    "type": "choice",
    "instructions": "What kind of document is this page?",
    "criteria": {
      "receipt": "A store or POS receipt (paragon): narrow thermal paper, itemized purchases, total paid",
      "invoice": "An invoice (faktura): a formal bill requesting payment with invoice number, seller, buyer, amounts, VAT",
      "bank_statement": "A bank or card account statement listing transactions over a period",
      "letter_or_other": "Any other document: letter, contract, manual, note, form, photo"
    }
  },
  "is_accounting": {
    "type": "noul",
    "instructions": "This document is an accounting document (an invoice or a receipt for goods or services).",
    "criteria": {
      "true": "An invoice, faktura, or itemized purchase receipt",
      "false": "A letter, statement, contract, manual, or any non-accounting document"
    }
  }
}
JSON
}

doc_row() { grep -P "^${1}\t" "${WORK_DIR}/corpus.tsv"; }

jev_call() {
  local arm="$1" doc_id="$2" token="$3" req
  if [[ $arm == "image" ]]; then
    local img fmt ref b64f
    img="$(doc_row "$doc_id" | cut -f4)"
    fmt="jpg"
    [[ $img == *.png ]] && fmt="png"
    b64f="$(mktemp "${WORK_DIR}/.b64-${doc_id}.XXXXXX")"
    base64 -w0 "${WORK_DIR}/${img}" >"$b64f"
    ref="img-${doc_id}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    req="$(jq -n --rawfile b64 "$b64f" --arg ref "$ref" --arg fmt "$fmt" --slurpfile q <(questions_json) '{
      model: "'"${JEV_MODEL}"'",
      state: {document_page: $ref},
      assets: {($ref): {type: "image", format: $fmt, data_base64: $b64}},
      questions: $q[0]
    }')"
    rm -f "$b64f"
    printf '%s' "$req" | curl --silent --fail-with-body --max-time 120 \
      https://api.typesafe.ai/v1/systemone \
      -H "Authorization: Bearer ${TYPESAFE_API_KEY}" \
      -H "TypeSafe-Danger-Zone-Images: true" \
      -H "Content-Type: application/json" \
      --data-binary @-
  else
    local content
    content="$(api "$token" "/api/documents/${doc_id}/" | jq -r '.content[0:8000]')"
    req="$(jq -n --arg s "$content" --slurpfile q <(questions_json) '{model:"'"${JEV_MODEL}"'", state:$s, questions:$q[0]}')"
    printf '%s' "$req" | curl --silent --fail-with-body --max-time 60 \
      https://api.typesafe.ai/v1/systemone \
      -H "Authorization: Bearer ${TYPESAFE_API_KEY}" \
      -H "Content-Type: application/json" \
      --data-binary @-
  fi
}

clef_call() {
  local arm="$1" doc_id="$2" token="$3" req
  if [[ $arm == "image" ]]; then
    local img mime b64f
    img="$(doc_row "$doc_id" | cut -f4)"
    mime="image/jpeg"
    [[ $img == *.png ]] && mime="image/png"
    b64f="$(mktemp "${WORK_DIR}/.b64-${doc_id}.XXXXXX")"
    base64 -w0 "${WORK_DIR}/${img}" >"$b64f"
    req="$(jq -n --rawfile b64 "$b64f" --arg mime "$mime" --slurpfile q <(questions_json) '{
      model: "clef",
      state: [{type: "image_url", image_url: {url: ("data:" + $mime + ";base64," + $b64)}}],
      questions: $q[0]
    }')"
    rm -f "$b64f"
  else
    local content
    content="$(api "$token" "/api/documents/${doc_id}/" | jq -r '.content[0:8000]')"
    req="$(jq -n --arg s "$content" --slurpfile q <(questions_json) '{model: "clef", state: $s, questions: $q[0]}')"
  fi
  printf '%s' "$req" | curl --silent --fail-with-body --max-time 120 \
    "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/ai/run/${CLEF_MODEL}" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary @-
}

run_arm() {
  local model="$1" arm="$2" token="$3"
  local out="${WORK_DIR}/results-${model}-${arm}.jsonl"
  : >"$out"
  local doc_id class title img t0 t1 resp meta
  while IFS=$'\t' read -r doc_id class title img; do
    [[ $doc_id == "doc_id" ]] && continue
    [[ $class == "encrypted" && $arm == "image" ]] && continue
    if [[ $arm == "image" && (! -s "${WORK_DIR}/${img}" || $img == "MISSING") ]]; then
      echo "  skip ${doc_id}: no staged image"
      continue
    fi
    t0=$(date +%s.%N)
    if resp="$(jev_call "$arm" "$doc_id" "$token" 2>&1)"; then :; else resp="$(printf '%s' "$resp" | jq -R -s '{http_error: .}')"; fi
    t1=$(date +%s.%N)
    meta="$(jq -cn --argjson doc "$doc_id" --arg truth "$class" --arg model "$model" --arg arm "$arm" \
      --argjson lat "$(awk "BEGIN{print ${t1} - ${t0}}")" \
      '{doc_id:$doc, truth:$truth, model:$model, arm:$arm, latency_s:$lat}')"
    printf '%s' "$resp" | jq -c "$meta + {raw: .}" >>"$out" 2>/dev/null ||
      printf '%s\n' "${meta}" | jq -c '. + {parse_error: true}' >>"$out"
    echo "  ${model}/${arm} doc=${doc_id} truth=${class} $(date +%H:%M:%S)"
  done <"${WORK_DIR}/corpus.tsv"
  echo "wrote ${out}"
}

score() {
  echo "=== paperless-decision-bench score (${WORK_DIR}) ==="
  local f
  for f in "${WORK_DIR}"/results-*.jsonl; do
    [[ -e $f ]] || {
      echo "no results yet — run --bench first"
      return
    }
    echo
    echo "--- $(basename "$f") per-doc (truth, guess, conf, MARGIN, noul, latency, tokens) ---"
    jq -r '
      (.raw.result // .raw) as $r |
      ($r.answers.doc_class.choice // "ERR") as $c |
      ($r.answers.doc_class.confidence // "-") as $cf |
      ($r.answers.doc_class.probabilities // null | if . == null then "-" else (to_entries | sort_by(-.value) | (.[0].value - .[1].value) * 1000 | round / 1000 | tostring) end) as $m |
      ($r.answers.is_accounting.noul // "-") as $n |
      ($r.usage.input_tokens // $r.result.usage.input_tokens // "-") as $t |
      [.truth, $c, ($cf | tostring), ($m | tostring), ($n | tostring), ((.latency_s * 1000) | round | tostring) + "ms", ($t | tostring)] | @tsv
    ' "$f" 2>/dev/null | column -t
    jq -r '
      (.raw.result // .raw) as $r |
      [($r.answers.doc_class.choice // "ERR"), ($r.answers.doc_class.confidence // 0), ($r.usage.input_tokens // $r.result.usage.input_tokens // 0), (.latency_s * 1000)] | @tsv
    ' "$f" 2>/dev/null | awk -F'\t' -v name="$(basename "$f")" '
      { n++; lat[NR]=$4; totlat+=$4; if ($4>max) max=$4; tok+=$3 }
      NR==1 { asort_idx=0 }
      {
        guess[NR]=$1; conf[NR]=$2
      }
      END {
        for (i=1;i<=n;i++) { lats[i]=lat[i] }
        # sort latencies for p50
        for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (lats[j]<lats[i]) { tmp=lats[i]; lats[i]=lats[j]; lats[j]=tmp }
        printf "%s: n=%d tokens=%d p50lat=%.0fms maxlat=%.0fms\n", name, n, tok, lats[int((n+1)/2)], max
      }
    ' 2>/dev/null || true
  done
  echo
  echo "accuracy + gate simulation (auto-apply at confidence >= 0.9 OR top-2 probability margin >= 0.6 — the paperless-triage gate signal; confidence saturates near 1.0 on right AND wrong answers, margin does not):"
  for f in "${WORK_DIR}"/results-*.jsonl; do
    [[ -e $f ]] || continue
    paste <(jq -r '(.raw.result // .raw).answers.doc_class.choice // "ERR"' "$f" 2>/dev/null) \
      <(jq -r '(.raw.result // .raw).answers.doc_class.confidence // 0' "$f" 2>/dev/null) \
      <(jq -r '(.raw.result // .raw).answers.doc_class.probabilities // null | if . == null then -1 else (to_entries | sort_by(-.value) | (.[0].value - .[1].value)) end' "$f" 2>/dev/null) \
      <(jq -r '.truth | sub("^general$"; "letter_or_other")' "$f" 2>/dev/null) |
      awk -F'\t' -v name="$(basename "$f")" '
        {
          n++
          if ($1==$4) correct++
          if ($2>=0.9) { cg++; if ($1==$4) cg_correct++ }
          if ($3>=0.6) { mg++; if ($1==$4) mg_correct++ }
          if ($1==$4) cs+=$2; else ws+=$2
          if ($1==$4) csm+=$3; else wsm+=$3
          nc[$1]++
        }
        END {
          printf "  %s: acc=%d/%d (%.0f%%) | conf>=0.9: %d docs, %d correct (%.1f%% err inside gate) | margin>=0.6: %d docs, %d correct (%.1f%% err inside gate) | mean-conf correct=%.2f wrong=%.2f | mean-margin correct=%.2f wrong=%.2f\n", \
            name, correct, n, 100*correct/n, cg, cg_correct, (cg ? 100*(cg-cg_correct)/cg : 0), mg, mg_correct, (mg ? 100*(mg-mg_correct)/mg : 0), \
            (correct ? cs/correct : 0), ((n-correct) ? ws/(n-correct) : 0), (correct ? csm/correct : 0), ((n-correct) ? wsm/(n-correct) : 0)
          for (g in nc) printf "    guess %-16s %d\n", g, nc[g]
        }'
  done
}

setup_secrets() {
  need sops
  if [[ ! -f $SOPS_FILE ]]; then
    local plain
    plain="$(mktemp "${WORK_DIR}/.secrets.XXXXXX.yaml")"
    chmod 600 "$plain"
    printf 'cloudflare_account_id: PLACEHOLDER-owner-paste\ncloudflare_api_token: PLACEHOLDER-owner-paste\ntypesafe_api_key: PLACEHOLDER-owner-paste\n' >"$plain"
    mv "$plain" "$SOPS_FILE"
    sops --encrypt --in-place "$SOPS_FILE"
    echo "created ${SOPS_FILE} with PLACEHOLDER values (creation rule from .sops.yaml)"
  fi
  cat <<EOF
Owner: paste real values via
  SOPS_AGE_KEY=\$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops ${SOPS_FILE}

  cloudflare_account_id  dash.cloudflare.com -> any domain -> Overview -> Account ID (right sidebar)
  cloudflare_api_token   dash.cloudflare.com -> My Profile -> API Tokens -> Create Token -> Workers AI (Read + Run)
  typesafe_api_key       console.typesafe.ai/keys
EOF
}

main() {
  local mode="${1:-}"
  case "$mode" in
  --probe) probe ;;
  --corpus)
    shift
    local n=10
    [[ ${1:-} == "--n" ]] && n="${2:-10}"
    build_corpus "$n"
    ;;
  --bench)
    shift
    local models="${1:-clef,jev}"
    shift || true
    local also_text=false
    [[ ${1:-} == "--also-text" ]] && also_text=true
    mkdir -p "$WORK_DIR"
    load_secrets "$models"
    local token
    token="$(mint_token)"
    local m
    IFS=',' read -ra ms <<<"$models"
    for m in "${ms[@]}"; do
      run_arm "$m" image "$token"
      $also_text && run_arm "$m" text "$token"
    done
    score
    ;;
  --score) score ;;
  --setup-secrets) setup_secrets ;;
  *)
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
  esac
}

main "$@"
