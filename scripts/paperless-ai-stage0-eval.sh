#!/usr/bin/env bash
# Paperless AI Stage-0 evaluation (AI-max plan A3, 2026-10-02).
#
# Renders the per-field suggestion quality table for 10 representative
# documents: current metadata vs the native AI's suggestions, side by side,
# so a human can calibrate the Apply-AI-suggestions workflow (A4) with DATA
# instead of hope. Catches the internet's #1 native-AI failure mode as a
# byproduct: qwen3.6-moe reasoning-token burn produces EMPTY suggestions.
#
# Usage (root — the token mint needs the paperless OS user):
#   sudo scripts/paperless-ai-stage0-eval.sh [--doc-ids "1 2 3"]
#
# What it does:
#   1. Mints a DRF token as the paperless user (peer-auth PG, tmpfs-only).
#   2. Selects 10 representative docs (or the --doc-ids override): a spread
#      across correspondents + the newest + the oldest with content.
#   3. GETs /api/documents/<id>/ai_suggestions/ per doc (READ-ONLY — the
#      endpoint computes suggestions, it never applies them).
#   4. Prints a markdown table: doc id/title vs suggested
#      title/tags/correspondent/type/dates + latency per call.
#
# First call may cold-load the 21.6 GB flm model (2-5 min) — per-doc timeout
# is 480s (matches PAPERLESS_AI_LLM_REQUEST_TIMEOUT).
set -euo pipefail

PORT="${PAPERLESS_PORT:-2892}"
BASE="http://127.0.0.1:${PORT}"
DOC_IDS=()
TIMEOUT=480
MANAGE="$(command -v paperless-manage || echo /run/current-system/sw/bin/paperless-manage)"

while [ $# -gt 0 ]; do
  case "$1" in
  --doc-ids)
    read -r -a DOC_IDS <<<"$2"
    shift 2
    ;;
  *)
    echo "usage: $0 [--doc-ids \"1 2 3\"]" >&2
    exit 64
    ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root (token mint runs as the paperless user via runuser)" >&2
  exit 77
fi

TOKEN_FILE=$(mktemp /tmp/paperless-stage0-token.XXXXXX)
trap 'rm -f "$TOKEN_FILE"' EXIT
chmod 600 "$TOKEN_FILE"

# Mint as the paperless OS user (peer auth); token never touches argv of
# other processes — only this file, which the trap removes.
runuser -u paperless -- "$MANAGE" drf_create_token admin |
  grep -oE '[0-9a-f]{40}' | head -n1 >"$TOKEN_FILE"
TOKEN=$(cat "$TOKEN_FILE")
if ! printf '%s' "$TOKEN" | grep -qE '^[0-9a-f]{40}$'; then
  echo "token mint failed" >&2
  exit 1
fi

api() {
  # Prints "<seconds>\t<body>"; body is "null" on failure.
  local path="$1" t0 t1
  t0=$(date +%s)
  body=$(curl -sf --max-time "$TIMEOUT" -H "Authorization: Token $TOKEN" \
    -H 'Accept: application/json' "$BASE$path" 2>/dev/null || echo null)
  t1=$(date +%s)
  printf '%s\t%s' "$((t1 - t0))" "$body"
}

# Representative selection when no ids given: 10 docs WITH content, spread
# across correspondents (DISTINCT ON), plus newest and oldest.
if [ "${#DOC_IDS[@]}" -eq 0 ]; then
  mapfile -t DOC_IDS < <(runuser -u paperless -- "$MANAGE" shell -c "
from documents.models import Document
qs = Document.objects.exclude(content='').order_by('-created')
ids = list(qs.values_list('id', flat=True)[:1])                # newest
ids += list(qs.order_by('created').values_list('id', flat=True)[:1])  # oldest
seen_correspondents = set()
for d in qs.select_related('correspondent').prefetch_related('tags')[:200]:
    c = d.correspondent_id
    if c in seen_correspondents:
        continue
    seen_correspondents.add(c)
    ids.append(d.id)
    if len(ids) >= 10:
        break
print(' '.join(str(i) for i in ids[:10]))
" | tail -1)
fi

echo "# Stage-0 AI suggestion eval — $(date -Iseconds)"
echo
echo "| doc | current | suggested | latency | verdict columns |"
echo "| --- | --- | --- | --- | --- |"

EMPTY_COUNT=0
for id in "${DOC_IDS[@]}"; do
  META_ROW=$(api "/api/documents/$id/?format=json")
  SUG_ROW=$(api "/api/documents/$id/ai_suggestions/?format=json")
  LAT=$(printf '%s' "$SUG_ROW" | cut -f1)
  META=$(printf '%s' "$META_ROW" | cut -f2-)
  SUG=$(printf '%s' "$SUG_ROW" | cut -f2-)

  CUR_TITLE=$(printf '%s' "$META" | jq -r '.title // "?"')
  CUR_TAGS=$(printf '%s' "$META" | jq -r '[.tags[]] | join(",")')
  CUR_CORR=$(printf '%s' "$META" | jq -r '.correspondent // "—"')
  CUR_TYPE=$(printf '%s' "$META" | jq -r '.document_type // "—"')

  S_TITLE=$(printf '%s' "$SUG" | jq -r '.title // "∅"')
  S_TAGS=$(printf '%s' "$SUG" | jq -r '.suggested_tags // [] | join(",")')
  S_CORR=$(printf '%s' "$SUG" | jq -r '.suggested_correspondents // [] | join(",")')
  S_TYPE=$(printf '%s' "$SUG" | jq -r '.suggested_document_types // [] | join(",")')

  if [ "$S_TITLE" = "∅" ] && [ -z "$S_TAGS" ] && [ -z "$S_CORR" ]; then
    EMPTY_COUNT=$((EMPTY_COUNT + 1))
  fi

  echo "| $id | t:${CUR_TITLE:0:40}<br>tags:${CUR_TAGS:0:30}<br>c:${CUR_CORR} ty:${CUR_TYPE} | t:${S_TITLE:0:40}<br>tags:${S_TAGS:0:30}<br>c:${S_CORR} ty:${S_TYPE} | ${LAT}s | compare above |"
done

echo
echo "## Reasoning-burn check"
if [ "$EMPTY_COUNT" -gt 0 ]; then
  echo "**${EMPTY_COUNT}/${#DOC_IDS[@]} docs returned EMPTY suggestions** — the qwen3.6-moe reasoning-token burn signature (llama-index think-flag class). If latency was also >120s with no cold load, gate the A4 workflow go-live on a model/prompt fix."
else
  echo "All ${#DOC_IDS[@]} docs returned non-empty suggestions — no reasoning-burn signature."
fi
echo
echo "Manual calibration verdict (fill in): field whitelist = title/tags/correspondent (drop document_type?), language consistency, any systematic misses."
