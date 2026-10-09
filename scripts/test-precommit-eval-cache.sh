#!/usr/bin/env bash
# Selftest for scripts/lib/precommit-eval-cache.sh (flake check:
# precommit-eval-cache-selftest). Fixture-repo based — proves the properties
# the memo's safety model rests on:
#   1. key determinism (same tree => same key)
#   2. MODULE-EDIT INSENSITIVITY — the whole point: module-only commits hit
#      the memo and skip the eval
#   3. sensitivity to flake.nix / flake.lock / overlays/ / lib/ /
#      flake/parts/ edits and to same-content renames (path identity is keyed)
#   4. unreadable input => key MISS (never a partial/stale key)
#   5. the memo only serves EXISTING store paths (GC gate) and rejects
#      non-store paths
#   6. PRECOMMIT_EVAL_CACHE=0 disables lookups
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/lib/precommit-eval-cache.sh
source "$here/lib/precommit-eval-cache.sh"

fail=0
pass() { echo "PASS: $1"; }
flunk() {
  echo "FAIL: $1"
  fail=1
}

fixture=$(mktemp -d)
state=$(mktemp -d)
trap 'rm -rf "$fixture" "$state"' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.email selftest@invalid
git -C "$fixture" config user.name selftest
mkdir -p "$fixture/lib" "$fixture/overlays" "$fixture/modules" "$fixture/flake/parts"
echo '{ }' >"$fixture/flake.nix"
echo '{ "nodes": { } }' >"$fixture/flake.lock"
echo 'a = 1;' >"$fixture/lib/a.nix"
echo 'o = 1;' >"$fixture/overlays/o.nix"
echo 'p = 1;' >"$fixture/flake/parts/p.nix"
echo 'm = 1;' >"$fixture/modules/m.nix"
git -C "$fixture" add -A
git -C "$fixture" commit -qm fixture

# Test isolation: memoize into the fixture state dir + a writable
# "store-like" prefix (production: /nix/store).
export PRECOMMIT_EVAL_CACHE_STATE_DIR="$state"
export _PEC_STORE_PREFIX="$fixture/store"
mkdir -p "$fixture/store"

key_in_fixture() { (cd "$fixture" && precommit_formatter_key); }
cached_in_fixture() { (cd "$fixture" && precommit_formatter_cached_path); }
store_in_fixture() { (cd "$fixture" && precommit_formatter_store_path "$1"); }

# 1. determinism
k1=$(key_in_fixture) || flunk "key computation failed on a healthy tree"
k2=$(key_in_fixture) || flunk "key computation failed on retry"
[ -n "$k1" ] && [ "$k1" = "$k2" ] && pass "key deterministic" || flunk "key not deterministic ('$k1' vs '$k2')"

# 2. module-edit insensitivity (the perf property)
echo 'm = 2; # module churn' >>"$fixture/modules/m.nix"
k3=$(key_in_fixture) || flunk "key failed after module edit"
[ "$k3" = "$k1" ] && pass "module edit does NOT move the key (memo HIT for module commits)" ||
  flunk "module edit moved the key — memo would miss (no perf win)"

# 3. sensitivity to every keyed input
mutate_expect_change() { # <desc> <file> <content-append>
  echo "$3" >>"$fixture/$2"
  local k
  k=$(key_in_fixture) || flunk "key failed after $1 mutation"
  [ "$k" != "$k_prev" ] && pass "$1 edit moves the key (safe MISS)" ||
    flunk "$1 edit did NOT move the key — STALE FORMATTER RISK"
  k_prev=$k
}
k_prev=$k3
mutate_expect_change "flake.nix" flake.nix '# churn'
mutate_expect_change "flake.lock" flake.lock '# churn'
mutate_expect_change "overlays/" overlays/o.nix '# churn'
mutate_expect_change "lib/" lib/a.nix '# churn'
mutate_expect_change "flake/parts/" flake/parts/p.nix '# churn (2026-10-09: parts now eval-relevant — key must cover them)'

# rename with identical content still moves the key (path identity keyed).
# NOTE: the rename is STAGED — git ls-files follows the INDEX, and an
# index-listed but worktree-missing file makes the key MISS by design
# (unreadable input, safe direction).
cp "$fixture/lib/a.nix" "$fixture/lib/b.nix"
rm "$fixture/lib/a.nix"
git -C "$fixture" add -A
k=$(key_in_fixture) || flunk "key failed after rename"
[ "$k" != "$k_prev" ] && pass "same-content rename moves the key" ||
  flunk "rename with identical content did NOT move the key"
k_prev=$k

# 4. unreadable tracked input => MISS (never a partial key)
rm "$fixture/flake.lock"
if key_in_fixture 2>/dev/null; then
  flunk "key computed despite unreadable flake.lock — PARTIAL KEY (phantom-stale class)"
else
  pass "unreadable tracked input yields key MISS"
fi
echo '{ "nodes": { } }' >"$fixture/flake.lock"

# 5. memo roundtrip + GC gate + store-prefix guard
fake_store="$fixture/store/zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz-treefmt"
mkdir -p "$fake_store/bin"
: >"$fake_store/bin/treefmt"
store_in_fixture "$fake_store" || flunk "store_path failed on a valid path"
got=$(cached_in_fixture) || flunk "cached_path MISS despite fresh store"
[ "$got" = "$fake_store" ] && pass "memo roundtrip serves stored path" ||
  flunk "memo roundtrip returned '$got' != '$fake_store'"

rm -rf "$fake_store"
if cached_in_fixture 2>/dev/null; then
  flunk "memo served a GC'd path (store-presence gate broken)"
else
  pass "GC'd path => MISS"
fi

store_in_fixture "/tmp/not-a-store-path" || flunk "store_path errored on non-store path"
if cached_in_fixture 2>/dev/null; then
  flunk "memo served a non-store path (prefix guard broken)"
else
  pass "non-store path rejected"
fi

# 6. escape hatch
mkdir -p "$fake_store/bin"
: >"$fake_store/bin/treefmt"
store_in_fixture "$fake_store" || true
if (cd "$fixture" && PRECOMMIT_EVAL_CACHE=0 precommit_formatter_cached_path 2>/dev/null); then
  flunk "lookup succeeded with PRECOMMIT_EVAL_CACHE=0"
else
  pass "PRECOMMIT_EVAL_CACHE=0 disables lookups"
fi

if [ "$fail" = 0 ]; then
  echo "ALL PASS"
else
  echo "SELFTEST FAILED"
  exit 1
fi
