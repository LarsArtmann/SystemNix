#!/usr/bin/env bash
# Relative-link checker for living docs (F54 rewrite of the 2026-08-31
# audit session's buggy ad-hoc checker, which false-BROKEN'd every
# relative link via a wrong sed).
#
# Checks markdown links [text](target) in the LIVING docs only (frozen
# snapshots under docs/status/ and docs/planning/ keep their historical
# paths by repo policy). Relative targets are resolved against the
# linking file's directory; #anchors, http(s)://, mailto:, and <>-style
# autolinks are ignored. Exits 1 listing every broken target.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

LIVING_DOCS=(
  README.md
  TODO_LIST.md
  FEATURES.md
  ROADMAP.md
  CHANGELOG.md
  AGENTS.md
  docs/CONTRIBUTING.md
  docs/gotchas-archive.md
  docs/services/*.md
)

broken=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  dir=$(dirname "$f")
  # Extract link targets: [text](target) — drop images too (same syntax),
  # keep only targets that look like repo-relative paths (no scheme, no
  # anchor-only). Pure-bash loop with word splitting disabled.
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    case "$target" in
    http://* | https://* | mailto:* | \#*) continue ;;
    esac
    # Strip a trailing #anchor (but keep a bare '#' handled above).
    path=${target%%#*}
    [ -n "$path" ] || continue
    if [ ! -e "$dir/$path" ]; then
      echo "BROKEN: $f -> $target"
      broken=1
    fi
  done < <(
    grep -oE '\[[^]]*\]\([^)]+\)' "$f" |
      sed -E 's/^\[[^]]*\]\(//; s/\)$//' |
      sed -E 's/ /%20/g' |
      grep -vE '^(https?:|mailto:)' || true
  )
done < <(ls "${LIVING_DOCS[@]}" 2>/dev/null || true)

if [ "$broken" -ne 0 ]; then
  echo "FAIL: broken relative links above."
  exit 1
fi
echo "OK: no broken relative links in living docs."
