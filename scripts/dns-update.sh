#!/usr/bin/env bash
set -euo pipefail

BLOCKLIST_FILE="platforms/common/dns-blocklists.nix"
HAGEZI_RAW_PREFIX="https://raw.githubusercontent.com/hagezi/dns-blocklists"
HAGEZI_REPO="https://github.com/hagezi/dns-blocklists.git"
SB_REPO="https://github.com/StevenBlack/hosts.git"

usage() {
  cat <<'EOF'
usage: scripts/dns-update.sh [--hashes-only | --bump-hagezi <latest | 40-hex commit> | --selftest]

  (no flag)               advance the StevenBlack pin to upstream HEAD, then re-hash every list
  --hashes-only           re-hash against the pins the file already carries (repair pass)
  --bump-hagezi TARGET    move the HaGeZi pin to TARGET, then re-hash (one list family per change)
  --selftest              offline self-tests: no network, no repo file required

Every mode edits a COPY and replaces the file in one rename, and only when
every list hashed: a failed run leaves the tree exactly as it was.
EOF
}

# Two list families, one update model each:
#   - StevenBlack: commit-pinned raw.githubusercontent.com URLs. Advance the
#     pin to upstream HEAD, then re-hash.
#   - HaGeZi: GitHub PINNED-COMMIT raw URLs (since 2026-11-24) rendered
#     through the file's own `hagezi` helper. The base URL, commit included,
#     is READ FROM THE FILE (extract_hagezi_base): the fixed-output
#     derivations fetch exactly that URL, so the hash must come from exactly
#     those bytes.
#
# NEVER hash a URL the file does not fetch (2026-11-25 deploy bomb): the base
# used to be hardcoded to the MOVING GitLab-mirror main branch. After the
# source of truth moved to the pinned GitHub commit, the nightly
# dns-blocklist-drift workflow kept re-hashing GitLab HEAD and wrote those
# hashes under the pinned URLs; six lists no longer matched their immutable
# bytes and every deploy died at the HaGeZi FODs (c7fb34007, 05:36 CET, until
# repaired the same evening). At a pinned commit a hash diff means the FILE
# was wrong, never that upstream moved: moving the lists is a deliberate
# commit bump plus re-hash in one change (--bump-hagezi does exactly that).
#
# NEVER rewrite HaGeZi URLs. The pre-2026-09-29 version of this script
# grep'd for raw.githubusercontent.com/hagezi (which matched nothing once the
# GitLab migration landed), then blind-sed'd a foreign commit prefix into
# every helper argument, breaking every HaGeZi fetch at build time.
#
# ALL-OR-NOTHING (2026-11-25): the tree is auto-committed every few minutes,
# so a half-updated file is a deploy bomb waiting for the next commit (the
# StevenBlack pin advance used to be sed'd in BEFORE the hashing, and a run
# that died on one fetch left the new pin under the old hash). Every mode now
# works on a copy and publishes it in one rename, only when nothing failed.

MODE="advance"
BUMP_TARGET=""
case "${1:-}" in
"") ;;
--hashes-only)
  MODE="hashes"
  ;;
--bump-hagezi)
  MODE="bump"
  BUMP_TARGET="${2:-}"
  ;;
--selftest)
  MODE="selftest"
  ;;
-h | --help)
  usage
  exit 0
  ;;
*)
  echo "ERROR: unknown argument: $1" >&2
  usage >&2
  exit 2
  ;;
esac
# An extra or misspelled argument must never widen the run: the script used
# to start the StevenBlack pin advance on ANY argument it did not recognise.
if [[ $MODE == bump && $# -gt 2 || $MODE != bump && $# -gt 1 ]]; then
  echo "ERROR: unexpected argument: ${*: -1}" >&2
  usage >&2
  exit 2
fi
if [[ $MODE != selftest && ! -f $BLOCKLIST_FILE ]]; then
  echo "ERROR: $BLOCKLIST_FILE not found. Run from repo root."
  exit 1
fi

extract_sb_pin() {
  # The [a-f0-9]{40} anchor is load-bearing (2026-10-01 incident): the old
  # regex stopped the capture after "StevenBlack/" and captured the "hosts"
  # path segment instead of the commit, and the global sed then rewrote every
  # "hosts" substring in the file — corrupting all 15 hagezi "hosts/…" URLs.
  grep -oP "raw\.githubusercontent\.com/StevenBlack/hosts/\K[a-f0-9]{40}" "$1" | head -1 || true
}

extract_hagezi_base() {
  # Full base INCLUDING the 40-hex commit, from the `hagezi` helper's code
  # line (comment lines are dropped first). Anything unpinned (a branch name,
  # another host) extracts empty on purpose: the caller fails loud instead of
  # silently hashing bytes the file never fetches.
  sed '/^[[:space:]]*#/d' "$1" | grep -oP 'https://raw\.githubusercontent\.com/hagezi/dns-blocklists/[a-f0-9]{40}' | head -1 || true
}

# Upstream HEAD of a PUBLIC repository, over plain HTTPS. The owner's global
# git config rewrites https://github.com/ to SSH (url.<ssh>.insteadOf) and
# the weekly blocklist-auto-update timer runs with no ssh on PATH: its
# 2026-11-23 run died exit 128 on that rewrite ("cannot run ssh").
# GIT_CONFIG_GLOBAL=/dev/null keeps personal rewrites out of this lookup.
public_head() {
  GIT_CONFIG_GLOBAL=/dev/null git ls-remote "$1" HEAD 2>/dev/null | awk '{print $1}' || true
}

# Prints the pinned base a --bump-hagezi TARGET resolves to, or explains the
# refusal on stderr and returns 1. A branch or a short SHA is rejected on
# purpose: raw.githubusercontent.com serves an immutable tree only at a FULL
# commit SHA, which is the whole point of pinning.
resolve_hagezi_bump() {
  local target="${1:-}" sha
  if [[ -z $target ]]; then
    echo "ERROR: --bump-hagezi needs a target: 'latest' or a full 40-hex commit SHA" >&2
    return 1
  fi
  if [[ $target == latest ]]; then
    sha=$(public_head "$HAGEZI_REPO")
    if [[ ! $sha =~ ^[a-f0-9]{40}$ ]]; then
      echo "ERROR: could not resolve the HaGeZi upstream HEAD commit (got '${sha}')" >&2
      return 1
    fi
  elif [[ $target =~ ^[a-f0-9]{40}$ ]]; then
    sha=$target
  else
    echo "ERROR: --bump-hagezi target '${target}' is neither 'latest' nor a full 40-hex commit SHA" >&2
    return 1
  fi
  printf '%s/%s' "$HAGEZI_RAW_PREFIX" "$sha"
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
    *'hash = "'*)
      printf '%s\n' "$i"
      return 0
      ;;
    *) return 0 ;;
    esac
  done
  return 0
}

FAILED=0
# The working copy. Global on purpose: the EXIT trap reads it after
# run_update has returned and its locals are gone.
WORK=""

# Replaces the blocklist file with the finished copy $WORK in ONE rename.
# The staged file is created in the same directory (same filesystem, so mv is
# an atomic rename): concurrent readers (nix evals in sibling sessions, the
# auto-commit daemon) see either the old or the new file, never a torn one.
publish_work() {
  local staged
  staged=$(mktemp "${BLOCKLIST_FILE}.XXXXXX") || return 1
  if ! cat "$WORK" >"$staged"; then
    rm -f "$staged"
    return 1
  fi
  chmod --reference="$BLOCKLIST_FILE" "$staged" || true
  mv -f "$staged" "$BLOCKLIST_FILE"
}

# One transaction over a COPY of the blocklist file. Sets FAILED to the number
# of lists that did not hash and publishes only when it is zero.
run_update() {
  local base new_base line entry fragment url b32 sri hline old new_sb current_sb
  WORK=$(mktemp) || return 1
  trap 'rm -f "$WORK"' EXIT
  cp "$BLOCKLIST_FILE" "$WORK" || return 1

  # The HaGeZi base is resolved BEFORE anything is decided: a file whose
  # helper lost its pinned commit must fail here, not half-updated.
  base=$(extract_hagezi_base "$WORK")
  if [[ -z $base ]]; then
    echo "ERROR: could not extract the pinned HaGeZi base from $BLOCKLIST_FILE"
    echo "       (expected the hagezi helper to carry a raw.githubusercontent.com/hagezi/dns-blocklists/<40-hex>/ URL)"
    echo "       Refusing to hash a URL the file does not fetch."
    return 1
  fi

  if [[ $MODE == bump ]]; then
    new_base=$(resolve_hagezi_bump "$BUMP_TARGET") || return 1
    if [[ $new_base == "$base" ]]; then
      echo "=== HaGeZi pin unchanged ($new_base) ==="
    else
      # Only the helper's CODE line is rewritten; a comment that quotes the
      # old URL keeps quoting it.
      line=$(grep -n -F "$base" "$WORK" | grep -v -E '^[0-9]+:[[:space:]]*#' | head -1 | cut -d: -f1 || true)
      if [[ -z $line ]]; then
        echo "ERROR: the pinned base $base appears only in comments; there is no helper line to bump"
        return 1
      fi
      sed -i "${line}s|${base}|${new_base}|" "$WORK" || return 1
      if [[ $(extract_hagezi_base "$WORK") != "$new_base" ]]; then
        echo "ERROR: the pin rewrite did not take (the helper still extracts another base)"
        return 1
      fi
      echo "=== HaGeZi pin: ${base##*/} -> ${new_base##*/} ==="
    fi
    base=$new_base
    echo "=== Skipping the StevenBlack commit-pin advance (--bump-hagezi moves one list family) ==="
  else
    echo "=== HaGeZi base (pinned, read from the file): $base ==="
    if [[ $MODE == hashes ]]; then
      echo "=== Skipping the StevenBlack commit-pin advance (--hashes-only) ==="
    else
      echo "=== Advancing the StevenBlack commit pin ==="
      new_sb=$(public_head "$SB_REPO")
      if [[ -z $new_sb ]]; then
        echo "ERROR: could not fetch StevenBlack HEAD"
        return 1
      fi
      current_sb=$(extract_sb_pin "$WORK")
      if [[ -z $current_sb ]]; then
        echo "ERROR: could not extract current StevenBlack commit pin (expected hosts/<40-hex>/ URL shape)"
        return 1
      fi
      if [[ $current_sb != "$new_sb" ]]; then
        sed -i "s/${current_sb}/${new_sb}/g" "$WORK" || return 1
        echo "  StevenBlack: $current_sb -> $new_sb"
      else
        echo "  StevenBlack: pin unchanged ($new_sb)"
      fi
    fi
  fi

  echo ""
  echo "=== Refreshing SRI hashes ==="
  # Each entry: <grep-able file fragment>|<fetchable URL>. The hash is always
  # the `hash = "..."` line directly BELOW the fragment's line.
  local entries=()
  while IFS= read -r sub; do
    entries+=("hagezi \"${sub}\"|${base}/${sub}")
  done < <(grep -oP 'hagezi "\K[^"]+' "$WORK")
  while IFS= read -r url; do
    entries+=("${url}|${url}")
  done < <(grep -oP 'url = "\K[^"]+(?=")' "$WORK" | grep -v '^hagezi' || true)

  for entry in "${entries[@]}"; do
    fragment="${entry%%|*}"
    url="${entry#*|}"
    printf "  %-46s " "${fragment:0:46}"
    b32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -1 || true)
    if [[ -z $b32 ]]; then
      echo "FAILED (nix-prefetch-url)"
      FAILED=$((FAILED + 1))
      continue
    fi
    sri=$(nix hash convert --hash-algo sha256 --to sri "$b32" 2>/dev/null || true)
    if [[ -z $sri ]]; then
      echo "FAILED (nix hash convert)"
      FAILED=$((FAILED + 1))
      continue
    fi
    line=$(grep -nF "$fragment" "$WORK" | head -1 | cut -d: -f1)
    hline=""
    [[ -n $line ]] && hline=$(find_hash_line "$WORK" "$line")
    if [[ -z $hline ]]; then
      echo "FAILED (no hash line below fragment)"
      FAILED=$((FAILED + 1))
      continue
    fi
    old=$(sed -n "${hline}p" "$WORK" | sed 's/.*hash = "//;s/".*//')
    if [[ $old == "$sri" ]]; then
      echo "unchanged"
    else
      sed -i "${hline}s|.*|      hash = \"$sri\";|" "$WORK" || return 1
      echo "updated"
    fi
  done

  echo ""
  if [[ $FAILED -gt 0 ]]; then
    echo "Done with $FAILED FAILED entries; $BLOCKLIST_FILE is UNCHANGED (the partial copy was discarded)."
    echo "Review network/mirror state, then re-run."
    return 1
  fi
  publish_work || {
    echo "ERROR: could not publish the refreshed $BLOCKLIST_FILE (left unchanged)"
    return 1
  }
  echo "Done. $BLOCKLIST_FILE replaced in one piece."
  echo "Review changes: git diff $BLOCKLIST_FILE"
  echo "Prove the fetches: nix build .#checks.x86_64-linux.blocklist-fetches --no-link"
  echo "Apply:            nix run .#deploy"
}

if [[ $MODE == selftest ]]; then
  # Proves the SHIPPED logic (the functions above) against fixture blocklist
  # files — no network, no repo-root requirement.
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

  # extract_hagezi_base: the hash must come from the URL the file FETCHES
  # (2026-11-25 deploy bomb: GitLab-HEAD hashes under pinned-GitHub URLs).
  hagezi_commit=4efe36574890b5ceacfb0ca8c693fee5c7395fb6
  cat >"$tmp/hagezi-helper.nix" <<EOF
  # the pinned commit lives in the helper's code line, not here
  hagezi =
    subpath:
    "https://raw.githubusercontent.com/hagezi/dns-blocklists/${hagezi_commit}/\${subpath}";
  {
    url = hagezi "dnsmasq/tif.txt";
EOF
  got=$(extract_hagezi_base "$tmp/hagezi-helper.nix")
  if [[ $got == "https://raw.githubusercontent.com/hagezi/dns-blocklists/$hagezi_commit" ]]; then
    ok "hagezi helper fixture extracts the pinned base"
  else
    bad "hagezi base returned '$got'"
  fi

  printf "hagezi = subpath: \"https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/\${subpath}\";\n" >"$tmp/moving-ref.nix"
  got=$(extract_hagezi_base "$tmp/moving-ref.nix")
  if [[ -z $got ]]; then
    ok "a moving-ref helper (GitLab main) extracts empty (the 2026-11-25 class)"
  else
    bad "moving-ref helper matched '$got'"
  fi

  printf 'url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/dnsmasq/tif.txt";\n' >"$tmp/unpinned.nix"
  got=$(extract_hagezi_base "$tmp/unpinned.nix")
  if [[ -z $got ]]; then ok "an unpinned GitHub ref extracts empty"; else bad "unpinned ref matched '$got'"; fi

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
  if [[ $got == 3 ]]; then ok "a comment mentioning a hash is never picked up"; else bad "decoy-comment returned '$got' (want 3)"; fi

  cat >"$tmp/missing-hash.nix" <<'NIX'
      url = hagezi "dnsmasq/gambling.txt";
    }
NIX
  got=$(find_hash_line "$tmp/missing-hash.nix" 1)
  if [[ -z $got ]]; then ok "entry without a hash line returns empty"; else bad "missing-hash returned '$got' (want empty)"; fi

  # resolve_hagezi_bump: the target is 'latest' or a FULL commit SHA.
  new_commit=1111111111111111111111111111111111111111
  got=$(resolve_hagezi_bump "$new_commit") || got=""
  if [[ $got == "$HAGEZI_RAW_PREFIX/$new_commit" ]]; then
    ok "a full commit SHA resolves to the pinned base"
  else
    bad "full SHA returned '$got'"
  fi
  for bad_target in "" main abc "${hagezi_commit}1"; do
    if resolve_hagezi_bump "$bad_target" >/dev/null 2>&1; then
      bad "bump target '${bad_target:-<empty>}' was accepted"
    else
      ok "bump target '${bad_target:-<empty>}' rejected"
    fi
  done

  # Stubbed network tools for the flow tests below. Every stub is POSIX sh so
  # the selftest also runs inside a bare nix build sandbox.
  mkdir -p "$tmp/bin"
  cat >"$tmp/bin/git" <<'GIT'
#!/bin/sh
# git ls-remote <repo> HEAD: one line shaped like the real one. StevenBlack
# answers a new HEAD; the HaGeZi answer is chosen by the test (repo argument).
case "$1" in
*StevenBlack*) printf '%s\tHEAD\n' "2222222222222222222222222222222222222222" ;;
*) printf '%s\tHEAD\n' "$HAGEZI_STUB_HEAD" ;;
esac
GIT
  cat >"$tmp/bin/nix-prefetch-url" <<'PREFETCH'
#!/bin/sh
# nix-prefetch-url --type sha256 <url>: store path, then a hash derived from
# the arguments. Fails for a URL under the "removed" commit or naming a list
# that upstream no longer ships (the 404 cases).
case "$*" in
*3333333333333333333333333333333333333333* | *missing*) exit 1 ;;
esac
printf '/nix/store/fake\n%052d\n' "$(printf '%s' "$*" | cksum | cut -d' ' -f1)"
PREFETCH
  cat >"$tmp/bin/nix" <<'NIX'
#!/bin/sh
# nix hash convert --hash-algo sha256 --to sri <b32>
for last; do :; done
printf 'sha256-%s=\n' "$last"
NIX
  chmod +x "$tmp/bin/git" "$tmp/bin/nix-prefetch-url" "$tmp/bin/nix"
  export HAGEZI_STUB_HEAD=2222222222222222222222222222222222222222
  got=$(PATH="$tmp/bin:$PATH" resolve_hagezi_bump latest)
  if [[ $got == "$HAGEZI_RAW_PREFIX/2222222222222222222222222222222222222222" ]]; then
    ok "'latest' resolves through git ls-remote"
  else
    bad "'latest' returned '$got'"
  fi
  export HAGEZI_STUB_HEAD=""
  if PATH="$tmp/bin:$PATH" resolve_hagezi_bump latest >/dev/null 2>&1; then
    bad "'latest' was accepted although HEAD could not be resolved"
  else
    ok "'latest' refuses when HEAD does not resolve to a commit"
  fi
  export HAGEZI_STUB_HEAD=2222222222222222222222222222222222222222

  # run_update end to end against a fixture blocklist file.
  repo=$tmp/repo
  mkdir -p "$repo/platforms/common"
  fixture=$repo/platforms/common/dns-blocklists.nix
  cat >"$fixture" <<NIX
let
  hagezi =
    subpath:
    "https://raw.githubusercontent.com/hagezi/dns-blocklists/${hagezi_commit}/\${subpath}";
  # a comment quoting the old pin must survive a bump untouched:
  # https://raw.githubusercontent.com/hagezi/dns-blocklists/${hagezi_commit}/dnsmasq/tif.txt
in
{
  blocklists = [
    {
      name = "HaGeZi-tif";
      url = hagezi "dnsmasq/tif.txt";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    }
    {
      name = "StevenBlack-everything";
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/${commit}/alternates/fakenews-gambling-porn-social/hosts";
      hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    }
  ];
}
NIX
  cp "$fixture" "$tmp/pristine.nix"

  # Runs one update against the fixture: $1 = MODE, $2 = BUMP_TARGET. The
  # relative BLOCKLIST_FILE is what the real run uses, so it needs cwd = repo.
  run_flow() {
    (
      cd "$repo" || exit 1
      BLOCKLIST_FILE="platforms/common/dns-blocklists.nix"
      MODE="$1"
      BUMP_TARGET="${2:-}"
      FAILED=0
      PATH="$tmp/bin:$PATH"
      run_update
    )
  }
  count_of() {
    grep -c -F "$1" "$fixture" || true
  }

  if run_flow hashes >"$tmp/flow.log" 2>&1 \
    && [[ $(count_of AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA) == 0 ]] \
    && [[ $(count_of BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB) == 0 ]] \
    && [[ $(count_of "$commit") == 1 ]]; then
    ok "--hashes-only rewrites stale hashes and leaves the pins alone"
  else
    bad "--hashes-only did not repair the fixture: $(tail -3 "$tmp/flow.log" | tr '\n' ' ')"
  fi

  # The all-or-nothing contract: one unreachable list must leave the file
  # byte-identical, including the lists that DID hash.
  # The same file plus one list upstream no longer ships (fetch fails).
  cat >"$tmp/pristine-gone.nix" <<NIX
let
  hagezi =
    subpath:
    "https://raw.githubusercontent.com/hagezi/dns-blocklists/${hagezi_commit}/\${subpath}";
in
{
  blocklists = [
    {
      name = "HaGeZi-tif";
      url = hagezi "dnsmasq/tif.txt";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    }
    {
      name = "HaGeZi-gone";
      url = hagezi "dnsmasq/missing.txt";
      hash = "sha256-DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=";
    }
    {
      name = "StevenBlack-everything";
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/${commit}/alternates/fakenews-gambling-porn-social/hosts";
      hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    }
  ];
}
NIX
  if [[ $(grep -c 'HaGeZi-gone' "$tmp/pristine-gone.nix") == 1 ]]; then
    ok "the gone-list fixture carries the unreachable entry"
  else
    bad "the gone-list fixture is malformed"
  fi
  cp "$tmp/pristine-gone.nix" "$fixture"
  if run_flow hashes >"$tmp/flow-fail.log" 2>&1; then
    bad "a run with an unreachable list still succeeded"
  elif cmp -s "$tmp/pristine-gone.nix" "$fixture"; then
    ok "an unreachable list leaves the file byte-identical"
  else
    bad "a failed run changed the file"
  fi
  if grep -q 'UNCHANGED' "$tmp/flow-fail.log"; then
    ok "the failure report says the file is unchanged"
  else
    bad "the failure report does not mention UNCHANGED"
  fi

  cp "$tmp/pristine.nix" "$fixture"
  if run_flow bump "$new_commit" >"$tmp/flow-bump.log" 2>&1 \
    && [[ $(count_of "$new_commit") == 1 ]] \
    && [[ $(count_of "$hagezi_commit") == 1 ]] \
    && grep -q "\"$HAGEZI_RAW_PREFIX/$new_commit/" "$fixture" \
    && [[ $(count_of AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA) == 0 ]] \
    && [[ $(count_of "$commit") == 1 ]]; then
    ok "--bump-hagezi rewrites the helper line, re-hashes, and leaves StevenBlack alone"
  else
    bad "--bump-hagezi did not land: $(tail -3 "$tmp/flow-bump.log" | tr '\n' ' ')"
  fi

  # A bump onto a commit that serves nothing must not move the pin.
  cp "$tmp/pristine.nix" "$fixture"
  gone_commit=3333333333333333333333333333333333333333
  if run_flow bump "$gone_commit" >"$tmp/flow-bump-fail.log" 2>&1; then
    bad "a bump onto an empty commit still succeeded"
  elif cmp -s "$tmp/pristine.nix" "$fixture"; then
    ok "a bump onto a commit that serves nothing leaves the pin and the file untouched"
  else
    bad "a failed bump changed the file"
  fi

  # The default mode advances the StevenBlack pin and hashes in one piece.
  cp "$tmp/pristine.nix" "$fixture"
  if run_flow advance >"$tmp/flow-advance.log" 2>&1 \
    && [[ $(count_of 2222222222222222222222222222222222222222) == 1 ]] \
    && [[ $(count_of BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB) == 0 ]] \
    && [[ $(count_of "$hagezi_commit") == 2 ]]; then
    ok "the default mode advances the StevenBlack pin and re-hashes"
  else
    bad "the default mode did not land: $(tail -3 "$tmp/flow-advance.log" | tr '\n' ' ')"
  fi

  # The same mode with one unreachable list moves nothing: the pin advance
  # used to be written to the tree before a single hash was checked.
  cp "$tmp/pristine-gone.nix" "$fixture"
  if run_flow advance >"$tmp/flow-advance-fail.log" 2>&1 \
    || grep -q 'could not extract current StevenBlack' "$tmp/flow-advance-fail.log" \
    || ! grep -q 'FAILED (nix-prefetch-url)' "$tmp/flow-advance-fail.log"; then
    bad "the default mode succeeded with an unreachable list"
  elif cmp -s "$tmp/pristine-gone.nix" "$fixture"; then
    ok "the default mode with an unreachable list leaves the pin and the file untouched"
  else
    bad "a failed default-mode run changed the file"
  fi

  # The published file keeps the mode of the file it replaced.
  if [[ $(stat -c %a "$fixture") == "$(stat -c %a "$tmp/pristine.nix")" ]]; then
    ok "the published file keeps the original mode"
  else
    bad "published mode $(stat -c %a "$fixture") differs from $(stat -c %a "$tmp/pristine.nix")"
  fi

  # A helper that lost its pin fails loud before anything is fetched.
  cp "$tmp/pristine.nix" "$fixture"
  sed -i "s|dns-blocklists/${hagezi_commit}/|dns-blocklists/main/|" "$fixture"
  if run_flow hashes >"$tmp/flow-nopin.log" 2>&1; then
    bad "an unpinned helper was accepted"
  elif grep -q 'could not extract the pinned HaGeZi base' "$tmp/flow-nopin.log"; then
    ok "an unpinned helper fails loud before fetching"
  else
    bad "the unpinned-helper run failed for another reason: $(tail -3 "$tmp/flow-nopin.log" | tr '\n' ' ')"
  fi

  echo "dns-update offline selftest: $pass passed, $fail failed"
  if [[ $fail -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi

run_update
