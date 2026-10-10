#!/usr/bin/env bash
# Fixture tests for the pre-deploy §11 vendorHash-freshness parsers
# (scripts/lib/vendor-freshness.sh). §11 FAILs block the deploy, so a
# parser that silently matches nothing must be impossible — the greps it
# replaced matched output nix never produces and warned "unable to
# determine status" on every run for two months while the stale-vendorHash
# class broke two deploys (2026-08).
#
# Fixtures are REAL captured nix output (2026-10-04, evo-x2): the
# uncached/cached toplevel dry-run shapes and a genuine FOD hash mismatch
# (bogus outputHash override, wording verbatim).
# Run: bash scripts/test-pre-deploy-vendor.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/vendor-freshness.sh
source "$REPO_ROOT/scripts/lib/vendor-freshness.sh"

TEST_FAILURES=0
expect_eq() {
  local got="$1" want="$2" desc="$3"
  if [ "$got" = "$want" ]; then
    echo "  ok   $desc"
  else
    echo "  FAIL $desc"
    echo "       want: [$want]"
    echo "       got:  [$got]"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

# --- Fixtures: REAL nix output, captured 2026-10-04 (see lib header) ---

# Uncached: batch dry-run of three go packages whose FODs were never built
# since the last lock move (verbatim, incl. the non-FOD drvs a real
# preview lists — the extractor must pick ONLY the FODs).
FIX_UNCACHED=$(
  cat <<'EOF'
these 6 derivations will be built:
  /nix/store/8wa0f1mkmhpzmrvhh7h9a2g11cl11n7i-crush-daily-prepared-source-12bf69f398ab3309f39c54699d6ec34669107c32.drv
  /nix/store/kbwg8d2lb5i5jxhbgnkm0g19ib4zpw0n-crush-daily-12bf69f398ab3309f39c54699d6ec34669107c32-go-modules.drv
  /nix/store/z2rlmwmcrwcz4zba44b6bakx42rnc3rn-file-and-image-renamer-prepared-source-0bd519b.drv
  /nix/store/sf4z4j5446a11slf1g9zhldrnlhnqkvh-file-and-image-renamer-0bd519b-go-modules.drv
  /nix/store/svwpx4wn23w97c8ab2q0pbpcvv0mjbc3-dnsblockd-base-prepared-source-1ffa8ff.drv
  /nix/store/sh7879dld10ifjp84q1lj7vg465xlyps-dnsblockd-1ffa8ff-go-modules.drv
EOF
)

# Cached: a fully-warm preview prints nix notices only.
FIX_CACHED=$(
  cat <<'EOF'
Using saved setting for 'extra-experimental-features = nix-command flakes pipe-operators' from ~/.local/share/nix/trusted-settings.json.
Using saved setting for 'warn-dirty = false' from ~/.local/share/nix/trusted-settings.json.
EOF
)

# Genuine FOD hash mismatch, produced by a bogus outputHash override
# (dnsblockd, verbatim wording and exit semantics).
FIX_MISMATCH=$(
  cat <<'EOF'
this derivation will be built:
  /nix/store/b2sqmvvrvsgmp6vhzjq1cxpk1qz7h8wz-dnsblockd-1ffa8ff-go-modules.drv
building '/nix/store/b2sqmvvrvsgmp6vhzjq1cxpk1qz7h8wz-dnsblockd-1ffa8ff-go-modules.drv'...
error: hash mismatch in fixed-output derivation '/nix/store/b2sqmvvrvsgmp6vhzjq1cxpk1qz7h8wz-dnsblockd-1ffa8ff-go-modules.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-hod8/GFv8EN8FkWzs3sKxA4jb4k234/rMKqT1DzK1TQ=
EOF
)

# Eval failure: the preview degrades to a stderr error blob.
FIX_EVAL_ERROR="error: attribute 'system' missing"

echo "vendor-freshness fixture tests"

# A uncached preview → exactly the 3 go-modules FODs (never the
# prepared-source / base drvs that share the listing).
expect_eq "$(vendor_freshness_extract_fods "$FIX_UNCACHED" | wc -l)" "3" "uncached preview: 3 FODs extracted"
expect_eq "$(vendor_freshness_extract_fods "$FIX_UNCACHED" | grep -c 'prepared-source' || true)" "0" "non-FOD drvs never match"

# B cached preview → nothing to build.
expect_eq "$(vendor_freshness_extract_fods "$FIX_CACHED")" "" "cached preview: zero FODs"

# Phantom-green anchor: a COPIED (substituter-cached) FOD store path has no
# .drv suffix and must never be treated as a build candidate — copying it
# proves the hash valid.
expect_eq "$(vendor_freshness_extract_fods 'these 1 paths will be copied:
  /nix/store/kbwg8d2lb5i5jxhbgnkm0g19ib4zpw0n-crush-daily-go-modules')" "" "copied store path is not a build candidate"

# C eval-failure detection (degraded-WARN branch).
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_EVAL_ERROR" && echo yes)" "yes" "eval error detected"
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_CACHED" && echo yes || echo no)" "no" "cached preview not misread as eval error"

# D got-hash parse (the value nix-hash-fix consumes).
expect_eq "$(vendor_freshness_parse_got_hash "$FIX_MISMATCH")" "sha256-hod8/GFv8EN8FkWzs3sKxA4jb4k234/rMKqT1DzK1TQ=" "got-hash parsed verbatim"
expect_eq "$(vendor_freshness_parse_got_hash 'error: build of ... failed')" "" "no got-hash invented for non-mismatch failure"

# E build verdict classification.
expect_eq "$(vendor_freshness_classify_build "$FIX_MISMATCH" 1)" "mismatch" "hash mismatch verdict"
expect_eq "$(vendor_freshness_classify_build "$FIX_CACHED" 0)" "ok" "clean build verdict"
expect_eq "$(vendor_freshness_classify_build 'error: cannot connect to nix daemon' 100)" "error" "non-hash failure verdict"

# F tree-state binding (the 2026-10-09 22:31 / 2026-10-10 misread class:
# a §11 verdict must be auditable against the tree it evaluated and void
# when that tree mutates mid-gate). Fake-rev fixtures are deterministic
# in a repo AND in the git-less selftest sandbox (fail-closed branch).
expect_eq "$(vendor_freshness_tree_pin | grep -qE '^(no-git|[0-9a-f]{7,40}) (clean|[0-9a-f]{64}|-)$' && echo shape-ok)" "shape-ok" "tree pin shape (repo or sandbox)"
expect_eq "$(vendor_freshness_tree_stamp 'abcdef1234567890 clean')" "abcdef1" "stamp: short rev, clean tree"
expect_eq "$(vendor_freshness_tree_stamp 'abcdef1234567890 e3b0c44298')" "abcdef1*" "stamp: dirty tree gets *"
expect_eq "$(vendor_freshness_tree_stamp 'no-git -')" "no-git" "stamp: no-git outside a repo"
expect_eq "$(vendor_freshness_tree_changed 'abc1234 clean' 'abc1234 clean' && echo changed || echo same)" "same" "identical pins: no change"
expect_eq "$(vendor_freshness_tree_changed 'abc1234 clean' 'abc1234 deadbeef' && echo changed || echo same)" "changed" "same rev, tree content moved: change"
expect_eq "$(vendor_freshness_tree_changed 'aaaaaaaa clean' 'bbbbbbbb clean' && echo changed || echo same)" "changed" "rev move, eval delta unresolvable: fail closed"

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "❌ $TEST_FAILURES fixture test(s) FAILED"
  exit 1
fi
echo "✅ all vendor-freshness fixture tests passed"
