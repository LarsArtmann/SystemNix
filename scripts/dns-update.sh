#!/usr/bin/env bash
set -euo pipefail

BLOCKLIST_FILE="platforms/common/dns-blocklists.nix"

if [[ ! -f $BLOCKLIST_FILE ]]; then
  echo "ERROR: $BLOCKLIST_FILE not found. Run from repo root."
  exit 1
fi

HASHES_ONLY=0
if [[ ${1:-} == "--hashes-only" ]]; then
  HASHES_ONLY=1
fi

# Two list families, two update models:
#   - StevenBlack: commit-pinned raw.githubusercontent.com URLs. Advance the
#     pin to upstream HEAD, then re-hash.
#   - HaGeZi: UNPINNED GitLab-mirror main-branch URLs (github.com/hagezi is
#     repeatedly locked by GitHub fraud detection) rendered through the
#     `hagezi` helper. The URL never changes; only the SRI hash drifts.
#
# NEVER rewrite HaGeZi URLs. The pre-2026-09-29 version of this script
# grep'd for raw.githubusercontent.com/hagezi (which matched nothing once the
# GitLab migration landed), then blind-sed'd a foreign commit prefix into
# every helper argument, breaking every HaGeZi fetch at build time.
#
# Flags:
#   --hashes-only  skip the StevenBlack pin advance and only re-hash. Use when
#                  upstream list content drifted and a build fix must not
#                  bundle an unrelated StevenBlack list refresh with it.
#   --selftest     run the offline extraction/hash-lookup self-tests.
HAGEZI_BASE="https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists"
SB_REPO="https://github.com/StevenBlack/hosts.git"

extract_sb_pin() {
  # The [a-f0-9]{40} anchor is load-bearing (2026-10-01 incident): the old
  # regex stopped the capture after "StevenBlack/" and captured the "hosts"
  # path segment instead of the commit, and the global sed then rewrote every
  # "hosts" substring in the file — corrupting all 15 hagezi "hosts/…" URLs.
  grep -oP "raw\.githubusercontent\.com/StevenBlack/hosts/\K[a-f0-9]{40}" "$1" | head -1 || true
}

# Entries may carry rationale comments between the url line and the hash line
# (hoster 2026-10-14, dyndns 2026-10-16). The lookup therefore scans forward
# over comment/blank lines instead of assuming the hash is the very next line —
# that line+1 assumption reported those entries as FAILED instead of updating
# them. Scanning stops at the next structural line (url/name/bracket).
HASH_LOOKAHEAD=15
find_hash_line() {
  local file=$1 start=$2 i line
  for ((i = start + 1; i <= start + HASH_LOOKAHEAD; i++)); do
    line=$(sed -n "${i}p" "$file")
    case "$line" in
      '' | *'#'*) continue ;;
      *'hash = "'*) printf '%s\n' "$i"; return 0 ;;
      *) return 0 ;;
    esac
  done
  return 0
}

if [[ ${1:-} == "--selftest" ]]; then
  # Proves the SHIPPED extraction (the function above) against fixture
  # blocklist files — no network, no repo-root requirement.
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  pass=0
  fail=0
  ok() {
    echo "  ok: $1"
    pass=$((pass + 1))
  }
  bad() {
    echo "FAIL: $1"
    fail=$((fail + 1))
  }

  commit=21605ccaecf26941005d4a7a3c1267af234599cf

  cat >"$tmp/healthy.nix" <<EOF
      name = "StevenBlack-everything";
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/${commit}/alternates/fakenews-gambling-porn-social/hosts";
EOF
  got=$(extract_sb_pin "$tmp/healthy.nix")
  if [[ $got == "$commit" ]]; then ok "healthy fixture extracts the commit"; else bad "healthy fixture returned '$got' (want $commit)"; fi
  if [[ $got != "hosts" ]]; then ok "never returns the 'hosts' path segment (2026-10-01 class)"; else bad "returned 'hosts' — the 2026-10-01 corruption class"; fi

  printf 'url = "https://raw.githubusercontent.com/StevenBlack/hosts//alternates/hosts";\n' >"$tmp/corrupt.nix"
  got=$(extract_sb_pin "$tmp/corrupt.nix")
  if [[ -z $got ]]; then ok "commit-less URL extracts empty (main path errors out)"; else bad "commit-less URL returned '$got' (want empty)"; fi

  printf 'url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/tif";\n' >"$tmp/decoy.nix"
  got=$(extract_sb_pin "$tmp/decoy.nix")
  if [[ -z $got ]]; then ok "hagezi hosts/ decoy never matches"; else bad "hagezi decoy matched '$got'"; fi

  # find_hash_line: re-pin comments sit between the url and hash lines.
  cat >"$tmp/comment-between.nix" <<'NIX'
      url = hagezi "dnsmasq/hoster.txt";
      # Re-pinned 2026-10-14: upstream content update broke the build.
      hash = "sha256-ehhA9Nf/7hBMIInGC5OCqYuEbmUA6l/Mwu0Asn5gY+w=";
NIX
  got=$(find_hash_line "$tmp/comment-between.nix" 1)
  if [[ $got == 3 ]]; then ok "hash lookup skips a comment between url and hash"; else bad "comment-between returned '$got' (want 3)"; fi

  cat >"$tmp/blank-between.nix" <<'NIX'
      url = hagezi "dnsmasq/nsfw.txt";

      hash = "sha256-8PKZR3KneG5ri8/fqNuEN2AJdT50SVXByl30J5uyt8U=";
NIX
  got=$(find_hash_line "$tmp/blank-between.nix" 1)
  if [[ $got == 3 ]]; then ok "hash lookup skips a blank line"; else bad "blank-between returned '$got' (want 3)"; fi

  cat >"$tmp/decoy-comment.nix" <<'NIX'
      url = hagezi "dnsmasq/tif.txt";
      # the old hash = "sha256-0OgTrZjwVPEpZ93v0xECxZ27DIIbozu/iWf6Xk99zEE=" went stale
      hash = "sha256-ReEh7Mum9YsCeQJLCymUXErvpVlyRsG6EA92cjpKCWQ=";
NIX
  got=$(find_hash_line "$tmp/decoy-comment.nix" 1)
  if [[ $got == 3 ]]; then ok "a comment mentioning a hash is never picked up"; else bad "decoy comment returned '$got' (want 3)"; fi

  cat >"$tmp/missing-hash.nix" <<'NIX'
      url = hagezi "dnsmasq/gambling.txt";
    }
NIX
  got=$(find_hash_line "$tmp/missing-hash.nix" 1)
  if [[ -z $got ]]; then ok "entry without a hash line returns empty"; else bad "missing-hash returned '$got' (want empty)"; fi

  echo "dns-update offline selftest: $pass passed, $fail failed"
  if [[ $fail -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi

if [[ $HASHES_ONLY == 1 ]]; then
  echo "=== Skipping the StevenBlack commit-pin advance (--hashes-only) ==="
else
  echo "=== Advancing the StevenBlack commit pin ==="
  new_sb=$(git ls-remote "$SB_REPO" HEAD | awk '{print $1}')
  if [[ -z $new_sb ]]; then
    echo "ERROR: could not fetch StevenBlack HEAD"
    exit 1
  fi
  current_sb=$(extract_sb_pin "$BLOCKLIST_FILE")
  if [[ -z $current_sb ]]; then
    echo "ERROR: could not extract current StevenBlack commit pin (expected hosts/<40-hex>/ URL shape)"
    exit 1
  fi
  if [[ $current_sb != "$new_sb" ]]; then
    sed -i "s/${current_sb}/${new_sb}/g" "$BLOCKLIST_FILE"
    echo "  StevenBlack: $current_sb -> $new_sb"
  else
    echo "  StevenBlack: pin unchanged ($new_sb)"
  fi
fi

echo ""
echo "=== Refreshing SRI hashes ==="
# Each entry: <grep-able file fragment>|<fetchable URL>. The hash is always
# the `hash = "..."` line directly BELOW the fragment's line.
entries=()
while IFS= read -r sub; do
  entries+=("hagezi \"${sub}\"|${HAGEZI_BASE}/${sub}")
done < <(grep -oP 'hagezi "\K[^"]+' "$BLOCKLIST_FILE")
while IFS= read -r url; do
  entries+=("${url}|${url}")
done < <(grep -oP 'url = "\K[^"]+(?=")' "$BLOCKLIST_FILE" | grep -v '^hagezi' || true)

failed=0
for entry in "${entries[@]}"; do
  fragment="${entry%%|*}"
  url="${entry#*|}"
  printf "  %-46s " "${fragment:0:46}"
  b32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -1 || true)
  if [[ -z $b32 ]]; then
    echo "FAILED (nix-prefetch-url)"
    failed=$((failed + 1))
    continue
  fi
  sri=$(nix hash convert --hash-algo sha256 --to sri "$b32" 2>/dev/null || true)
  if [[ -z $sri ]]; then
    echo "FAILED (nix hash convert)"
    failed=$((failed + 1))
    continue
  fi
  line=$(grep -nF "$fragment" "$BLOCKLIST_FILE" | head -1 | cut -d: -f1)
  hline=""
  [[ -n $line ]] && hline=$(find_hash_line "$BLOCKLIST_FILE" "$line")
  if [[ -z $hline ]]; then
    echo "FAILED (no hash line below fragment)"
    failed=$((failed + 1))
    continue
  fi
  old=$(sed -n "${hline}p" "$BLOCKLIST_FILE" | sed 's/.*hash = "//;s/".*//')
  if [[ $old == "$sri" ]]; then
    echo "unchanged"
  else
    sed -i "${hline}s|.*|      hash = \"$sri\";|" "$BLOCKLIST_FILE"
    echo "updated"
  fi
done

echo ""
if [[ $failed -gt 0 ]]; then
  echo "Done with $failed FAILED entries — review network/mirror state before deploying."
  exit 1
fi
echo "Done."
echo "Review changes: git diff $BLOCKLIST_FILE"
echo "Validate:       nix flake check --no-build"
echo "Apply:          nix run .#deploy"
