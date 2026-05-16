#!/usr/bin/env bash
set -euo pipefail

BLOCKLIST_FILE="platforms/common/dns-blocklists.nix"

if [[ ! -f $BLOCKLIST_FILE ]]; then
  echo "ERROR: $BLOCKLIST_FILE not found. Run from repo root."
  exit 1
fi

declare -A REPO_URLS=(
  ["hagezi"]="https://github.com/hagezi/dns-blocklists.git"
  ["StevenBlack"]="https://github.com/StevenBlack/hosts.git"
)

declare -A CURRENT_COMMITS
declare -A NEW_COMMITS

echo "=== Fetching latest commits ==="
for repo in "${!REPO_URLS[@]}"; do
  url="${REPO_URLS[$repo]}"
  new_commit=$(git ls-remote "$url" HEAD | awk '{print $1}')
  if [[ -z $new_commit ]]; then
    echo "ERROR: Could not fetch HEAD for $repo"
    exit 1
  fi
  NEW_COMMITS["$repo"]="$new_commit"
  echo "  $repo: $new_commit"
done

echo ""
echo "=== Extracting current commits ==="
for repo in "${!REPO_URLS[@]}"; do
  url="${REPO_URLS[$repo]}"
  url_escaped="${url//\//\\/}"
  url_escaped="${url_escaped//\./\\.}"
  current=$(grep -oP "raw\.githubusercontent\.com/${repo}/[^/]+" "$BLOCKLIST_FILE" | head -1 | sed "s|raw\.githubusercontent\.com/${repo}/||")
  if [[ -n $current ]]; then
    CURRENT_COMMITS["$repo"]="$current"
    echo "  $repo: $current → ${NEW_COMMITS[$repo]}"
  fi
done

has_changes=false
for repo in "${!REPO_URLS[@]}"; do
  if [[ ${CURRENT_COMMITS[$repo]:-} != "${NEW_COMMITS[$repo]}" ]]; then
    has_changes=true
  fi
done

if [[ $has_changes == "false" ]]; then
  echo ""
  echo "All blocklists are up to date. No changes needed."
  exit 0
fi

echo ""
echo "=== Updating commit hashes in URLs ==="
for repo in "${!REPO_URLS[@]}"; do
  old="${CURRENT_COMMITS[$repo]:-}"
  new="${NEW_COMMITS[$repo]}"
  if [[ -n $old && $old != "$new" ]]; then
    sed -i "s/${old}/${new}/g" "$BLOCKLIST_FILE"
    echo "  $repo: replaced $old → $new"
  fi
done

echo ""
echo "=== Computing new SRI hashes ==="
urls=$(grep -oP 'url = "[^"]+"' "$BLOCKLIST_FILE" | sed 's/url = "//;s/"//')
total=$(echo "$urls" | wc -l)
count=0

while IFS= read -r url; do
  count=$((count + 1))
  name=$(grep -B2 "$url" "$BLOCKLIST_FILE" | grep 'name =' | sed 's/.*name = "//;s/".*//')
  printf "  [%2d/%d] %-40s " "$count" "$total" "$name"

  base32_hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -1)
  if [[ -z $base32_hash ]]; then
    echo "FAILED (nix-prefetch-url)"
    continue
  fi

  sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$base32_hash" 2>/dev/null)
  if [[ -z $sri_hash ]]; then
    echo "FAILED (nix hash convert)"
    continue
  fi

  url_escaped="${url//\//\\/}"
  url_escaped="${url_escaped//\./\\.}"
  old_hash=$(grep -A1 "$url" "$BLOCKLIST_FILE" | grep 'hash =' | sed 's/.*hash = "//;s/".*//')

  if [[ -n $old_hash && $old_hash != "$sri_hash" ]]; then
    sed -i "s/${old_hash}/${sri_hash}/g" "$BLOCKLIST_FILE"
    echo "OK"
  elif [[ $old_hash == "$sri_hash" ]]; then
    echo "unchanged"
  else
    echo "SKIP (could not find old hash)"
  fi
done <<<"$urls"

echo ""
echo "=== Done ==="
echo "Review changes: git diff $BLOCKLIST_FILE"
echo "Validate:       just test-fast"
echo "Apply:          just switch"
