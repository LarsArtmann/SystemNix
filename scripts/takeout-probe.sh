#!/usr/bin/env bash
# takeout-probe.sh — Takeout auth probe: fetch the smallest un-held REAL part
# with the handoff cookies; green (zip magic + exact expected size) installs it
# so the bulk downloader skips it (a probe fetch is never wasted budget).
#
# Part of the Google account retirement pipeline (plan:
# docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md).
#
# Usage: bash scripts/takeout-probe.sh <staging-root> [part-number]
#   <staging-root>  dir with urls.txt, parts.tsv, cookies.txt (0600)
#   [part-number]   manifest row to probe (default 12 — picked per export as
#                   the smallest part not yet held; part 12 of racedriver8k is
#                   176,785 B)
# Stdout carries ONLY http code / final host / size / magic — never URLs or
# cookie values.
#
# Rart-first diagnostic (step 1): a 302 whose Location carries `rart=` is the
# interactive re-auth interstitial — every non-browser client bounces on it
# identically (3 h of client arms-race proved this on racedriver8k, 2026-11-11;
# docs/status/2026-11-11_20-58_takeout-g1-auth-marathon-full-status.md §e3).
# The probe dumps the 302's Location param-names FIRST and short-circuits with
# that verdict instead of downloading a bounce page. Runbook:
# docs/services/takeout.md
set -euo pipefail

root=${1:?usage: takeout-probe.sh <staging-root> [part]}
part=${2:-12}

url=$(grep -E '^[[:space:]]*https://' "$root/urls.txt" | sed -n "${part}p")
expected=$(awk -F'\t' -v p="$part" '$1 == p { print $2 }' "$root/parts.tsv")
[ -n "$url" ] && [ -n "$expected" ] || {
  echo "PROBE: no line-$part url/expected in staging"
  exit 1
}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Step 1: rart-first diagnostic on the SAME url the bulk probe targets — a 302
# whose Location carries `rart=` is the interactive re-auth wall; say so and stop.
diag_rc=0
diag=$(curl -sS -o /dev/null -D - --max-redirs 0 --connect-timeout 30 --max-time 60 \
  -b "$root/cookies.txt" "$url" 2>/dev/null) || diag_rc=$?
if [ "$diag_rc" -ne 0 ]; then
  echo "PROBE: diag fetch failed rc=$diag_rc (network/cookies/timeout) — NOT evidence of no-redirect; continuing bulk probe"
else
  dcode=$(sed -n '1s/^HTTP[^ ]* \([0-9]*\).*/\1/p' <<<"$diag")
  dloc=$(awk 'tolower($1) == "location:" { print $2 }' <<<"$diag" | tr -d '\r')
  if [ "${dcode:-}" = "302" ]; then
    params=$(tr '?&' '\n\n' <<<"$dloc" | cut -d= -f1 | grep -v '^$' | sort -u | paste -sd,)
    if grep -q 'rart=' <<<"$dloc"; then
      echo "PROBE: RART WALL — 302 Location params: ${params:-none}"
      echo "PROBE: interactive re-auth required — non-browser clients will ALL bounce; use the owner-browser flow (docs/services/takeout.md)"
      exit 5
    fi
    echo "PROBE: 302 without rart (params: ${params:-none}) — continuing bulk probe"
  else
    echo "PROBE: diag http=${dcode:-?} (no redirect on part-$part url) — continuing bulk probe"
  fi
fi

meta=$(curl -sS -o "$tmp" -w '%{http_code}\t%{url_effective}\t%{size_download}' \
  --location --max-redirs 5 --connect-timeout 30 --max-time 300 \
  -A 'Mozilla/5.0 (X11; Linux x86_64) Takeout-bulk-download' \
  -b "$root/cookies.txt" "$url") || {
  echo "PROBE: curl failed rc=$?"
  exit 1
}
code=$(cut -f1 <<<"$meta")
host=$(cut -f2 <<<"$meta" | awk -F/ '{print $3}')
dl=$(cut -f3 <<<"$meta")
size=$(stat -c %s "$tmp")
magic=$(head -c 2 "$tmp" | od -An -c | tr -d ' \n')
echo "PROBE: http=$code final_host=$host bytes=$size (downloaded=$dl) magic='$magic'"
case $magic in
PK) echo "PROBE: zip magic OK" ;;
\<*)
  echo "PROBE: HTML body — auth page, cookies INSUFFICIENT"
  exit 2
  ;;
*)
  echo "PROBE: unexpected magic"
  exit 3
  ;;
esac
if [ "$size" -eq "$expected" ]; then
  install -m 600 "$tmp" "$root/zips/part-$(printf '%02d' "$part").zip"
  echo "PROBE: exact size match ($expected) — installed (bulk run will skip it)"
else
  echo "PROBE: size mismatch (expected $expected) — NOT installed"
  exit 4
fi
