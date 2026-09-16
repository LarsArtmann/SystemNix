#!/usr/bin/env bash
# Check that Docker images pinned in lib/images.nix are on their latest version.
#
# Policy: images are ALWAYS kept on latest (user directive). Reproducibility
# comes from pinning (tag + digest), not from floating stale tags.
#
# Rules per entry:
#   - digest-pinned  : current registry digest of the pinned tag must match
#   - semver tag     : highest published semver tag must match (leading v optional)
#   - floating, unpinned (e.g. "16-alpine" without digest): skipped — tracks
#     latest at pull time by design; convert to digest pinning if drift matters
#
# Exit 0 = all current. Exit 1 = outdated or uncheckable (CI opens an issue).
#
# Usage: scripts/check-image-updates.sh [path/to/images.nix]

set -euo pipefail

IMAGES_NIX="${1:-$(dirname "$0")/../lib/images.nix}"

if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then
  echo "ERROR: requires curl and jq" >&2
  exit 1
fi

hub() {
  # hub <repo> <path-and-query> — Docker Hub v2 API (public, unauthenticated).
  # Official images (no slash) live under library/
  local repo="$1" query="$2"
  case "$repo" in
  */*) ;;
  *) repo="library/$repo" ;;
  esac
  curl -fsSL --max-time 30 "https://hub.docker.com/v2/repositories/${repo}/${query}"
}

sort_versions() {
  # Sort semantic versions (with optional leading v) oldest → newest
  sed -E 's/^v?//' | sort -t. -k1,1n -k2,2n -k3,3n
}

current_tag_digest() {
  # Digest of a specific tag (the multi-arch index digest)
  hub "$1" "tags/$2" | jq -r '.digest // empty'
}

latest_semver_tag() {
  # Highest x.y.z tag published for a repo. Hub tags come back ordered by
  # last_updated (NOT version) and page 1 caps at 100 — an active repo's
  # releases can fall off page 1 entirely, making a STALE tag look "latest"
  # (postgres/immich publish hundreds). Walk up to 5 pages (500 tags).
  local repo="$1" collected="" page names next url="tags?page_size=100&name="
  for _ in 1 2 3 4 5; do
    page=$(hub "$repo" "$url") || break
    names=$(printf '%s' "$page" | jq -r '.results[].name // empty' 2>/dev/null || true)
    [ -n "$names" ] && collected="${collected}${names}"$'\n'
    next=$(printf '%s' "$page" | jq -r '.next // empty' 2>/dev/null || true)
    [ -n "$next" ] || break
    url="${next#*/${repo}/}"
  done
  printf '%s' "$collected" | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort_versions | tail -1
}

failures=0
checked=0

# Parse entries: blocks of image/tag(/digest) attr lines
image="" tag="" digest=""
flush() {
  [ -z "$image" ] && return 0
  checked=$((checked + 1))
  local label="$image:$tag"
  if [ -n "$digest" ]; then
    live="$(current_tag_digest "$image" "$tag" || true)"
    if [ -z "$live" ]; then
      echo "ERROR: $label — could not query tag digest (repo gone? renamed?)"
      failures=$((failures + 1))
    elif [ "$live" != "$digest" ]; then
      echo "OUTDATED (digest drift): $label"
      echo "  pinned:  $digest"
      echo "  current: $live"
      failures=$((failures + 1))
    else
      echo "OK: $label (digest pinned)"
    fi
  elif echo "$tag" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    latest="$(latest_semver_tag "$image" || true)"
    if [ -z "$latest" ]; then
      echo "ERROR: $image — could not determine latest semver tag"
      failures=$((failures + 1))
    elif [ "$latest" != "$tag" ] && [ "${latest#v}" != "${tag#v}" ]; then
      echo "OUTDATED: $image $tag → $latest"
      failures=$((failures + 1))
    else
      echo "OK: $label (latest)"
    fi
  else
    echo "SKIP: $label (floating tag, unpinned — tracks latest at pull time)"
  fi
  image=""
  tag=""
  digest=""
}

while IFS= read -r line; do
  case "$line" in
  *'image = "'*)
    flush
    image=$(echo "$line" | sed -E 's/.*image = "([^"]+)".*/\1/')
    ;;
  *'tag = "'*) tag=$(echo "$line" | sed -E 's/.*tag = "([^"]+)".*/\1/') ;;
  *'digest = "'*) digest=$(echo "$line" | sed -E 's/.*digest = "([^"]+)".*/\1/') ;;
  esac
done <"$IMAGES_NIX"
flush

echo
echo "Checked: $checked, failures: $failures"
# checked==0 must FAIL: a parser drift (images.nix format change) used to
# exit 0 while validating NOTHING.
if [ "$checked" -eq 0 ]; then
  echo "ERROR: checked NOTHING — images.nix parse drift? (no 'image = \"…\"' lines in $IMAGES_NIX)"
  exit 1
fi
if [ "$failures" -gt 0 ]; then
  echo "Bump lib/images.nix (see docs: images must always be on latest)."
  exit 1
fi
