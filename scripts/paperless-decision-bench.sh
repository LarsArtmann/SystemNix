#!/usr/bin/env bash
# paperless-decision-bench.sh — benchmark decision models (Cloudflare Clef, TypeSafe Jev)
# against REAL paperless-ngx documents (receipts, invoices, general scans).
#
# Corpus + ground truth come from the live paperless metadata (owner-curated tags,
# document types, custom fields). Page-1 images are rendered from the ORIGINALS
# (no OCR) — this measures PRE-OCR triage: classification + confidence calibration.
#
# Data flow: paperless (loopback :2892, runtime-minted DRF token) -> page-1 JPEG
# -> cloud decision APIs (document images LEAVE THE LAN: owner-sanctioned for
# receipts/invoices/general scans; bank statements tagged `encrypted` are
# text-arm-only and excluded from the image arm).
#
# Secrets: platforms/nixos/secrets/decision-bench.yaml (cloudflare_account_id,
# cloudflare_api_token, typesafe_api_key) via `--setup-secrets`; or env vars.
#
# Usage:
#   scripts/paperless-decision-bench.sh --probe                 # corpus stats
#   scripts/paperless-decision-bench.sh --corpus [--n N]        # stage corpus + images
#   scripts/paperless-decision-bench.sh --bench clef,jev        # run both arms
#   scripts/paperless-decision-bench.sh --bench jev --also-text # add text arm
#   scripts/paperless-decision-bench.sh --score                 # summarize
#   scripts/paperless-decision-bench.sh --setup-secrets         # placeholder sops file
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${HOME}/.cache/paperless-decision-bench"
PAPERLESS_URL="http://127.0.0.1:2892"
SOPS_FILE="${REPO_ROOT}/platforms/nixos/secrets/decision-bench.yaml"
COST_PER_M_CLEF_INPUT="0.24"

INVOICE_TAG_NAME="faktura"
ACCOUNTING_TAG_NAME="Accounting"
ENCRYPTED_TAG_NAME="encrypted"
BILL_DTYPE_NAME="Bill"

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1 (PATH=$PATH)"; }
need curl; need jq; need pdftoppm

self_elevating_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then bash -c "$*"; else sudo bash -c "$*"; fi
}

manage_as_paperless() {
  self_elevating_sudo "runuser -u paperless -- /run/current-system/sw/bin/paperless-manage shell -c $1"
}

resolve_owner() {
  manage_as_paperless "'from documents.models import *; from allauth.socialaccount.models import SocialAccount; sa=SocialAccount.objects.first(); print(sa.user.username if sa else \\\"admin\\\")'"
}

mint_token() {
  local owner token
  owner="$(resolve_owner | tail -1 | tr -d '\r')"
  [[ -n "$owner" ]] || die "could not resolve paperless owner"
  token="$(manage_as_paperless "'from django.contrib.auth.models import User; from rest_framework.authtoken.models import Token; t,_=Token.objects.get_or_create(user=User.objects.get(username=\\\"${owner}\\\")); print(t.key)'" | grep -oE '[a-f0-9]{40}' | tail -1)"
  [[ -n "$token" ]] || die "token mint failed for '${owner}'"
  printf '%s' "$token"
}

api() {
  local token="$1" path="$2"
  curl --silent --fail-with-body -H "Authorization: Token ${token}" "${PAPERLESS_URL}${path}"
}

probe() {
  manage_as_paperless "'from documents.models import *
print(\\\"TOTAL\\\", Document.objects.count())
for t in Tag.objects.all().order_by(\\\"id\\\"): print(\\\"TAG\\\", t.id, t.name, Document.objects.filter(tags=t).count())
for d in DocumentType.objects.all().order_by(\\\"id\\\"): print(\\\"DTYPE\\\", d.id, d.name, Document.objects.filter(document_type=d).count())
for c in CustomField.objects.all().order_by(\\\"id\\\"): print(\\\"CFIELD\\\", c.id, c.name, c.data_type)'"
}

build_corpus() {
  local n_per_class="${1:-10}"
  mkdir -p "${WORK_DIR}/images"
  local token; token="$(mint_token)"
  echo "owner token minted; building corpus (n=${n_per_class}/class) via ORM + API"

  manage_as_paperless "'from documents.models import *
inv=Tag.objects.filter(name=\\\"${INVOICE_TAG_NAME}\\\").first()
acc=Tag.objects.filter(name=\\\"${ACCOUNTING_TAG_NAME}\\\").first()
enc=Tag.objects.filter(name=\\\"${ENCRYPTED_TAG_NAME}\\\").first()
bill=DocumentType.objects.filter(name=\\\"${BILL_DTYPE_NAME}\\\").first()
def qs(q):
    return list(q.values(\\\"id\\\",\\\"title\\\",\\\"content\\\",\\\"created\\\",\\\"created__year\\\")[:${n_per_class}]) if q else []
invoice_ids=[d.id for d in Document.objects.filter(tags=inv)] if inv else []
accounting_ids=[d.id for d in Document.objects.filter(tags=acc)] if acc else []
encrypted_ids=[d.id for d in Document.objects.filter(tags=enc)] if enc else []
bill_ids=[d.id for d in Document.objects.filter(document_type=bill)] if bill else []
receipt_ids=[i for i in bill_ids if i not in invoice_ids]
general_q=Document.objects.exclude(id__in=invoice_ids+receipt_ids+encrypted_ids).filter(document_type__isnull=True).order_by(\\\"-created\\\")
print(\\\"CLASS invoice\\\", invoice_ids[:${n_per_class}])
print(\\\"CLASS receipt\\\", receipt_ids[:${n_per_class}])
print(\\\"CLASS general\\\", [d.id for d in general_q.values_list(\\\"id\\\", flat=True)[:${n_per_class}]])
print(\\\"CLASS encrypted\\\", encrypted_ids[:${n_per_class}])
print(\\\"META counts\\\", len(invoice_ids), len(receipt_ids), len(encrypted_ids), Document.objects.exclude(id__in=invoice_ids+receipt_ids+encrypted_ids).filter(document_type__isnull=True).count())'" > "${WORK_DIR}/classes.raw"

  : > "${WORK_DIR}/corpus.tsv"
  printf 'doc_id\tclass\ttitle\tmime\timage\n' >> "${WORK_DIR}/corpus.tsv"
  local line class ids id title mime img
  while IFS= read -r line; do
    class="$(awk '{print $2}' <<<"$line")"
    ids="$(cut -d' ' -f3- <<<"$line" | tr -d '[],')"
    [[ "$class" == "META" ]] && { echo "$line"; continue; }
    for id in $ids; do
      title="$(api "$token" "/api/documents/${id}/" | jq -r '.title')"
      mime="$(api "$token" "/api/documents/${id}/" | jq -r '.original_file_name // ""')"
      img="images/${id}.jpg"
      if stage_image "$token" "$id"; then
        printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$class" "$title" "$mime" "$img" >> "${WORK_DIR}/corpus.tsv"
      else
        printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$class" "$title" "$mime" "MISSING" >> "${WORK_DIR}/corpus.tsv"
      fi
    done
  done < "${WORK_DIR}/classes.raw"

  echo "--- corpus.tsv ---"
  column -t -s$'\t' "${WORK_DIR}/corpus.tsv" 2>/dev/null || cat "${WORK_DIR}/corpus.tsv"
  echo "next: scripts/paperless-decision-bench.sh --bench clef,jev"
}

stage_image() {
  local token="$1" id="$2" out="${WORK_DIR}/images/${2}.jpg"
  [[ -s "$out" ]] && { need_file_in_jev_bounds "$out" && return 0 || return 0; }
  local tmp; tmp="$(mktemp -u "${WORK_DIR}/images/.orig-${id}.XXXXXX")"
  api "$token" "/api/documents/${id}/download/" > "$tmp" || { rm -f "$tmp"; return 1; }
  local kind; kind="$(file -b --mime-type "$tmp")"
  case "$kind" in
    application/pdf)
      pdftoppm -jpeg -r 100 -scale-to 1400 -f 1 -l 1 -singlefile "$tmp" "${out%.jpg}" || { rm -f "$tmp"; return 1; }
      ;;
    image/jpeg) cp "$tmp" "$out" ;;
    image/png)  cp "$tmp" "${out%.jpg}.png"; out="${out%.jpg}.png" ;;
    *) rm -f "$tmp"; return 1 ;;
  esac
  rm -f "$tmp"
  [[ -s "$out" ]]
}

need_file_in_jev_bounds() { :; }

load_secrets() {
  if [[ -n "${TYPESAFE_API_KEY:-}" && -n "${CLOUDFLARE_API_TOKEN:-}" && -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    return
  fi
  [[ -f "$SOPS_FILE" ]] || die "no env vars and no ${SOPS_FILE}; run --setup-secrets and paste real keys"
  local age_key
  age_key="$(self_elevating_sudo "cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key")"
  export SOPS_AGE_KEY="$age_key"
  eval "$(sops -d --extract '["typesafe_api_key"]' "$SOPS_FILE" | sed 's/^/TYPESAFE_API_KEY=/' )"
  eval "$(sops -d --extract '["cloudflare_api_token"]' "$SOPS_FILE" | sed 's/^/CLOUDFLARE_API_TOKEN=/' )"
  export TYPESAFE_API_KEY CLOUDFLARE_API_TOKEN
  CLOUDFLARE_ACCOUNT_ID="$(sops -d --extract '["cloudflare_account_id"]' "$SOPS_FILE")"
  export CLOUDFLARE_ACCOUNT_ID
  unset SOPS_AGE_KEY age_key
  [[ "$CLOUDFLARE_API_TOKEN" != PLACEHOLDER* && "$TYPESAFE_API_KEY" != PLACEHOLDER* ]] \
    || die "sops keys are still PLACEHOLDER — paste real keys: SOPS_AGE_KEY=\$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops ${SOPS_FILE}"
}

questions_json() {
  cat <<'JSON'
{
  "doc_class": {
    "type": "choice",
    "instructions": "What kind of document is this?",
    "criteria": {
      "receipt": "A store/POS receipt or paragon: narrow thermal paper, itemized purchases, total paid",
      "invoice": "An invoice or faktura: a formal bill requesting payment, with invoice number, seller/buyer, amounts, VAT",
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

run_arm() {
  local model="$1" state_kind="$2" token="$3"
  local out="${WORK_DIR}/results-${model}-${state_kind}.jsonl"
  : > "$out"
  while IFS=$'\t' read -r doc_id class title _mime img; do
    [[ "$doc_id" == "doc_id" ]] && continue
    [[ "$class" == "encrypted" && "$state_kind" == "image" ]] && continue
    local t0 t1 body state_json resp
    if [[ "$state_kind" == "image" ]]; then
      [[ -s "${WORK_DIR}/${img}" ]] || { echo "skip ${doc_id}: no image" >&2; continue; }
    fi
    t0=$(date +%s.%N)
    if [[ "$model" == "jev" ]]; then
      resp="$(jev_call "$state_kind" "$doc_id" "$token")"
    else
      resp="$(clef_call "$state_kind" "$doc_id" "$token")"
    fi
    t1=$(date +%s.%N)
    jq -c --argjson meta "{\"doc_id\":${doc_id},\"truth\":\"${class}\",\"model\":\"${model}\",\"arm\":\"${state_kind}\",\"latency_s\":$(awk "BEGIN{print ${t1}-${t0}}")}" \
      '. as $r | $meta + {ok: ($r.errors == null and $r.detail == null), raw: $r}' <<<"$resp" >> "$out" 2>/dev/null \
      || jq -c --argjson meta "{\"doc_id\":${doc_id},\"truth\":\"${class}\",\"model\":\"${model}\",\"arm\":\"${state_kind}\",\"latency_s\":$(awk "BEGIN{print ${t1}-${t0}}")}" '{ok:false, error: .}' <<<"$resp" >> "$out"
    echo "  ${model}/${state_kind} ${doc_id} (${class}) done"
  done < "${WORK_DIR}/corpus.tsv"
  echo "wrote ${out}"
}

jev_call() {
  local kind="$1" doc_id="$2" token="$3" req
  local state
  if [[ "$kind" == "image" ]]; then
    local img; img="$(grep -P "^${doc_id}\t" "${WORK_DIR}/corpus.tsv" | cut -f5)"
    local fmt="jpg"; [[ "$img" == *.png ]] && fmt="png"
    local ref; ref="img-${doc_id}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    req="$(jq -n --rawfile b64 "${WORK_DIR}/${img}" --arg ref "$ref" --arg fmt "$fmt" --slurpfile q <(questions_json) '{
      model: "jev-latest",
      state: {document_page: $ref},
      assets: {($ref): {type: "image", format: $fmt, data_base64: $b64}},
      questions: $q[0]
    }')"
    curl --silent --fail-with-body --max-time 120 \
      https://api.typesafe.ai/v1/systemone \
      -H "Authorization: Bearer ${TYPESAFE_API_KEY}" \
      -H "TypeSafe-Danger-Zone-Images: true" \
      -H "Content-Type: application/json" \
      --data-binary "$req"
  else
    local content; content="$(api "$token" "/api/documents/${doc_id}/" | jq -r '.content')"
    req="$(jq -n --arg s "$content" --slurpfile q <(questions_json) '{model:"jev-latest", state:$s, questions:$q[0]}')"
    curl --silent --fail-with-body --max-time 60 \
      https://api.typesafe.ai/v1/systemone \
      -H "Authorization: Bearer ${TYPESAFE_API_KEY}" \
      -H "Content-Type: application/json" \
      --data-binary "$req"
  fi
}

clef_call() {
  local kind="$1" doc_id="$2" token="$3" req
  if [[ "$kind" == "image" ]]; then
    local img; img="$(grep -P "^${doc_id}\t" "${WORK_DIR}/corpus.tsv" | cut -f5)"
    local mime="image/jpeg"; [[ "$img" == *.png ]] && mime="image/png"
    req="$(jq -n --rawfile b64 "${WORK_DIR}/${img}" --arg mime "$mime" --slurpfile q <(questions_json) '{
      model: "clef",
      state: [{type:"image_url", image_url:{url: ("data:" + $mime + ";base64," + $b64)}}],
      questions: $q[0]
    }')"
  else
    local content; content="$(api "$token" "/api/documents/${doc_id}/" | jq -r '.content')"
    req="$(jq -n --arg s "$content" --slurpfile q <(questions_json) '{model:"clef", state:$s, questions:$q[0]}')"
  fi
  curl --silent --fail-with-body --max-time 120 \
    "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/ai/run/@cf/cloudflare/clef" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary "$req"
}

score() {
  local f
  echo "=== paperless-decision-bench score ==="
  for f in "${WORK_DIR}"/results-*.jsonl; do
    [[ -e "$f" ]] || continue
    jq -rs '
      map(.ok == true) as $oks |
      map(select(.ok)) |
      {
        file: input_filename,
        calls: ($oks | length),
        ok: (map(select(.)) | length),
        doc_class_correct: (map(select(.raw.result.answers.doc_class.choice != null or .raw.answers.doc_class.choice != null)) | length)
      }
    ' "$f" 2>/dev/null || echo "(unparsed: $f)"
  done
  echo
  echo "per-question detail:"
  for f in "${WORK_DIR}"/results-*.jsonl; do
    [[ -e "$f" ]] || continue
    jq -r '
      [.raw.result.answers.doc_class // .raw.answers.doc_class // empty] as $dc |
      ($dc[0].choice // "ERROR") as $choice |
      ($dc[0].confidence // "-") as $conf |
      [.raw.answers.is_accounting.noul // .raw.result.answers.is_accounting.noul // "-"] as $noul |
      [.truth, $choice, ($conf|tostring), ($noul[0]|tostring), (.latency_s*1000|round|tostring)+"ms", (.raw.usage.input_tokens // .raw.result.usage.input_tokens // 0)] |
      @tsv' "$f" 2>/dev/null | awk -v f="$(basename "$f")" -F'\t' '
        { total++;
          guess[$2]++; truth[$1]++;
          if ($2==$1) { correct++; conf_correct+=$3 } else { wrong++; conf_wrong+=$3 }
          if ($3>=0.9) { high++; if ($2==$1) high_correct++ }
          lat=$5+0; if (lat>maxlat) maxlat=lat; totlat+=lat
          tok+=$6 }
        END {
          printf "%s: n=%d acc=%.0f%% | gate@0.9: auto=%d/%d err=%.1f%% | conf(correct)=%.2f conf(wrong)=%.2f | p50lat~%dms max=%dms | tokens=%d\n",
            f, total, 100*correct/(total?total:1), high, total, 100*(high-high_correct+0.0001)/(high?high:1),
            (correct?conf_correct/correct:0), (wrong?conf_wrong/wrong:0), totlat/(total?total:1), maxlat, tok
        }'
  done
}

setup_secrets() {
  need sops; need ssh-to-age
  if [[ ! -f "$SOPS_FILE" ]]; then
    local age_key recipient
    age_key="$(self_elevating_sudo "cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key")"
    recipient="$(self_elevating_sudo "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age")"
    SOPS_AGE_KEY="$age_key" sops --encrypt --age "$recipient" --pgp "" --input-type binary /dev/null >/dev/null 2>&1 || true
    printf 'cloudflare_account_id: PLACEHOLDER-owner-paste\ncloudflare_api_token: PLACEHOLDER-owner-paste\ntypesafe_api_key: PLACEHOLDER-owner-paste\n' \
      | SOPS_AGE_KEY="$age_key" sops --encrypt --age "$recipient" --input-type yaml --output "${SOPS_FILE}" /dev/stdin
    echo "created ${SOPS_FILE} with PLACEHOLDER values"
  fi
  echo "owner: paste real values with:"
  echo "  SOPS_AGE_KEY=\$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops ${SOPS_FILE}"
  echo "  cloudflare_account_id: dash.cloudflare.com -> account id (right sidebar)"
  echo "  cloudflare_api_token: dash.cloudflare.com -> My Profile -> API Tokens -> Workers AI (read+run)"
  echo "  typesafe_api_key: console.typesafe.ai/keys"
}

main() {
  local mode="${1:-}"; shift || true
  case "$mode" in
    --probe) probe ;;
    --corpus) build_corpus "${1:-10}" ;;
    --bench)
      local models="${1:-clef,jev}"; shift || true
      local also_text=false
      [[ "${1:-}" == "--also-text" ]] && also_text=true
      load_secrets
      local token; token="$(mint_token)"
      IFS=',' read -ra ms <<<"$models"
      for m in "${ms[@]}"; do
        run_arm "$m" image "$token"
        $also_text && run_arm "$m" text "$token"
      done
      score
      ;;
    --score) score ;;
    --setup-secrets) setup_secrets ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//;1d'; exit 1 ;;
  esac
}

main "$@"
