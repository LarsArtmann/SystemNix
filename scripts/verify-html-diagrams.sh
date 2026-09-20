#!/usr/bin/env bash
# verify-html-diagrams.sh — headless-render verification for self-contained
# HTML reports with inline mermaid.js (the 2026-09-20 disk-layout precedent).
#
# Renders each given HTML file in headless Chromium and asserts:
#   1. every declared mermaid container produced an SVG with no error-bombs
#   2. every internal anchor (href="#x") resolves to an id in the rendered DOM
# A file that declares diagrams but renders none AND references a remote
# script is reported as NOT self-contained (offline-unverifiable) — that is
# a failure under the house pattern (html-report-kit: single file, zero
# dependencies, no CDN).
#
# Usage: bash scripts/verify-html-diagrams.sh docs/planning/<file>.html [...]
# Env:   VERIFY_HTML_BROWSER (default helium), VERIFY_HTML_BUDGET_MS (25000)
#
# The 2026-09-20 formatter incident context: this script exists so any future
# edit of a big-HTML artifact (mystery formatter, parallel session, splice
# repair) gets a cheap render-proof gate instead of hand-rolled dump-dom
# dances (status report 2026-09-20 §e.4).
set -euo pipefail

browser="${VERIFY_HTML_BROWSER:-helium}"
budget="${VERIFY_HTML_BUDGET_MS:-25000}"
command -v "$browser" >/dev/null 2>&1 || {
  echo "FAIL: browser '$browser' not found (set VERIFY_HTML_BROWSER)" >&2
  exit 2
}

overall_fail=0

verify_one() {
  local file="$1"
  local fail=0

  [ -f "$file" ] || {
    echo "FAIL: $file: not a file"
    overall_fail=1
    return
  }

  local dom user_data
  dom="$(mktemp /tmp/verify-html-dom.XXXXXX)"
  user_data="$(mktemp -d /tmp/verify-html-profile.XXXXXX)"
  trap 'rm -f "$dom"; rm -rf "$user_data"' RETURN

  "$browser" --headless=new --disable-gpu --no-sandbox \
    --disable-dev-shm-usage --user-data-dir="$user_data" \
    --virtual-time-budget="$budget" \
    --dump-dom "file://$(readlink -f "$file")" >"$dom" 2>/dev/null || true

  # Declared diagram containers in the SOURCE (pre-render). The || true
  # guards matter: a HEALTHY file has zero error-bombs / zero remote
  # scripts, and a zero-match grep under pipefail would silently kill the
  # whole gate (the "dies without a verdict" class).
  local declared
  declared="$(grep -o 'class="mermaid"' "$file" | wc -l || true)"

  # Rendered artifacts in the DOM.
  local svgs bombs
  svgs="$(grep -o '<svg id="mermaid-' "$dom" | wc -l || true)"
  bombs="$(grep -o 'class="error-bomb"' "$dom" | wc -l || true)"

  # Remote script references (CDN) — violates the self-contained pattern.
  local cdn
  cdn="$(grep -coE 'src="https?://[^"]+"' "$file" || true)"

  if [ "$declared" -gt 0 ]; then
    if [ "$svgs" -ne "$declared" ]; then
      if [ "$svgs" -eq 0 ] && [ "$cdn" -gt 0 ]; then
        echo "FAIL: $file: 0/$declared diagrams rendered and the file references remote scripts — NOT self-contained (offline-unverifiable)"
        overall_fail=1
        return
      fi
      echo "FAIL: $file: rendered $svgs/$declared mermaid SVGs"
      fail=1
    fi
    if [ "$bombs" -gt 0 ]; then
      echo "FAIL: $file: $bombs mermaid error-bomb(s) in rendered DOM"
      fail=1
    fi
  fi

  # Internal anchors must resolve in the rendered DOM.
  local broken=0 anchor id
  for anchor in $(grep -o 'href="#[^"]*"' "$dom" | sed 's/^href="#//; s/"$//' | sort -u || true); do
    [ -n "$anchor" ] || continue
    if ! grep -q "id=\"$anchor\"" "$dom"; then
      echo "FAIL: $file: anchor '#$anchor' has no id in rendered DOM"
      broken=1
    fi
  done
  [ "$broken" -eq 0 ] || fail=1

  if [ "$fail" -eq 0 ]; then
    echo "PASS: $file (${declared} diagram(s), ${svgs} SVG(s), 0 error-bombs, anchors OK)"
  else
    overall_fail=1
  fi
}

[ "$#" -ge 1 ] || {
  echo "usage: $0 <file.html> [...]" >&2
  exit 2
}

for f in "$@"; do
  verify_one "$f"
done

exit "$overall_fail"
