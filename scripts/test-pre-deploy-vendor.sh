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
# Glob match (flow verdicts carry prose the fixtures should not pin byte
# for byte). `want` is an unquoted shell glob.
expect_match() {
  local got="$1" want="$2" desc="$3"
  # Glob match is the point: `want` is a pattern.
  # shellcheck disable=SC2254
  case "$got" in
    $want) echo "  ok   $desc" ;;
    *)
      echo "  FAIL $desc"
      echo "       want glob: [$want]"
      echo "       got:       [$got]"
      TEST_FAILURES=$((TEST_FAILURES + 1))
      ;;
  esac
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

# Real dry-run eval failure, nix 2.35.6 (verbatim capture 2026-11-25:
# `nix build --dry-run --impure --expr 'builtins.abort …'`, exit 1): the
# nix >= 2.26 shape, a bare `error:` headline with the message on an
# indented line below.
FIX_EVAL_ERROR_BLOCK=$(
  cat <<'EOF'
error:
       … while calling the 'abort' builtin
         at «string»:1:1:
            1| builtins.abort "vf-probe real eval error"
             | ^

       error: evaluation aborted with the following error message: 'vf-probe real eval error'
EOF
)

# Substituter narinfo unreachability, the benign class check #1 tolerates
# (nix prints it as `error:` even when it falls back to building locally).
# The block form is a verbatim nix 2.35.6 capture (2026-11-25, a
# builtins.fetchurl against a closed port: the same `error: unable to
# download '…narinfo'` block); the single-line form is the pre-2.26
# wording. Each rides an otherwise healthy preview.
FIX_NARINFO_BLOCK=$(
  cat <<'EOF'
error:
       … while calling the 'fetchurl' builtin
         at «string»:1:1:
            1| builtins.fetchurl "https://127.0.0.1:9/00000000000000000000000000000000-dummy.narinfo"
             | ^

       error: unable to download 'https://127.0.0.1:9/00000000000000000000000000000000-dummy.narinfo': Could not connect to server (7) Failed to connect to 127.0.0.1:9 after 0 ms: Could not connect to server
EOF
)
FIX_NARINFO_SINGLE="error: unable to download 'https://cache.nixos.org/00000000000000000000000000000000-dummy.narinfo': Timeout was reached"
FOD_A=/nix/store/kbwg8d2lb5i5jxhbgnkmkg019ib4zpw0n-crush-daily-12bf69f398ab3309f39c54699d6ec34669107c32-go-modules.drv
FIX_NOISE_UNCACHED="this derivation will be built:
  $FOD_A
$FIX_NARINFO_SINGLE"
FIX_NOISE_CACHED="$FIX_CACHED
$FIX_NARINFO_SINGLE"
FIX_NOISE_BLOCK="$FIX_NARINFO_BLOCK

this derivation will be built:
  $FOD_A"
FIX_NOISE_AND_REAL="$FIX_NARINFO_SINGLE
$FIX_EVAL_ERROR_BLOCK"

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

# C eval-failure detection. A failed preview BLOCKS (it degraded to a
# context-free WARN until 2026-11-25; the 01:35 deploy then died on a stale
# library-policy vendorHash the gate never previewed).
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_EVAL_ERROR" 1 && echo yes)" "yes" "eval error detected"
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_EVAL_ERROR_BLOCK" 1 && echo yes)" "yes" "multi-line eval error detected (bare headline, message below)"
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_CACHED" 0 && echo yes || echo no)" "no" "cached preview not misread as eval error"
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_CACHED" && echo yes || echo no)" "no" "exit status argument is optional"

# C2 benign classes never fail a preview (infrastructure noise must not
# block the deploy that repairs it, the check-#1 doctrine): single-line and
# block forms, on an uncached and on a cached preview.
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_NOISE_UNCACHED" 0 && echo yes || echo no)" "no" "narinfo noise on an uncached preview: not a failure"
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_NOISE_CACHED" 0 && echo yes || echo no)" "no" "narinfo noise on a cached preview: not a failure"
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_NOISE_BLOCK" 1 && echo yes || echo no)" "no" "benign block plus a printed plan survives a non-zero exit"

# C3 fail closed: noise alone, non-zero exit, no plan printed; and noise
# never masks a real error.
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_NOISE_CACHED" 1 && echo yes || echo no)" "yes" "non-zero exit without a plan fails closed"
expect_eq "$(vendor_freshness_dryrun_errored "$FIX_NOISE_AND_REAL" 1 && echo yes || echo no)" "yes" "benign noise never masks a real error"

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

# G gate flow, end to end, against a stubbed `nix` (the preview and the
# FOD build) and a pinned tree: the verdict strings are what §11 prints.
vf_verdicts=""
vf_pass() { vf_verdicts="$vf_verdicts|PASS $1"; }
vf_fail() { vf_verdicts="$vf_verdicts|FAIL $1"; }
VENDOR_FRESHNESS_PASS=vf_pass
VENDOR_FRESHNESS_FAIL=vf_fail
vendor_freshness_tree_pin() { printf 'deadbee deadbee'; }
nix() {
  case " $* " in
    *" --dry-run "*) printf '%s\n' "$VF_STUB_DRYRUN_OUT"; return "$VF_STUB_DRYRUN_RC" ;;
    *) printf '%s\n' "$VF_STUB_BUILD_OUT"; return "$VF_STUB_BUILD_RC" ;;
  esac
}

# G1 noise + plan + clean FOD build: PASS, the noise disclosed.
VF_STUB_DRYRUN_OUT="$FIX_NOISE_UNCACHED"
VF_STUB_DRYRUN_RC=0
VF_STUB_BUILD_OUT=""
VF_STUB_BUILD_RC=0
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS 1 uncached go-modules FOD(s) built clean*\[tree deadbee\* (1 benign nix error line(s) ignored)\]" "flow: benign noise read past, FOD built clean, noise disclosed"

# G2 real eval failure: FAIL (never a blind WARN), raw error shown.
VF_STUB_DRYRUN_OUT="$FIX_EVAL_ERROR_BLOCK"
VF_STUB_DRYRUN_RC=1
vf_verdicts=""
vf_stdout_file=$(mktemp)
vendor_freshness_run_gate >"$vf_stdout_file" 2>&1
vf_stdout=$(cat "$vf_stdout_file")
rm -f "$vf_stdout_file"
expect_match "${vf_verdicts#|}" "FAIL toplevel --dry-run FAILED (exit 1) \[tree deadbee\*\]*refusing to deploy blind*" "flow: failed preview blocks the deploy"
expect_match "$vf_stdout" "*error: evaluation aborted with the following error message: 'vf-probe real eval error'" "flow: failed preview prints the raw error"

# G3 cached preview carrying noise: PASS.
VF_STUB_DRYRUN_OUT="$FIX_NOISE_CACHED"
VF_STUB_DRYRUN_RC=0
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS all deploy go-modules FODs cached*vendorHash proven by prior builds \[tree deadbee\* (1 benign nix error line(s) ignored)\]" "flow: cached preview with noise passes"

# G4 stale vendorHash: FAIL with the got-hash (the gate's reason to exist).
VF_STUB_DRYRUN_OUT="this derivation will be built:
  $FOD_A"
VF_STUB_DRYRUN_RC=0
VF_STUB_BUILD_OUT="$FIX_MISMATCH"
VF_STUB_BUILD_RC=1
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL vendorHash STALE*sha256-hod8/GFv8EN8FkWzs3sKxA4jb4k234/rMKqT1DzK1TQ=*\[tree deadbee\*\]" "flow: stale vendorHash FAILs with the got-hash"

# G5 noise alone, non-zero exit, no plan: fail closed.
VF_STUB_DRYRUN_OUT="$FIX_NOISE_CACHED"
VF_STUB_DRYRUN_RC=1
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL toplevel --dry-run FAILED (exit 1) \[tree deadbee\*\]*" "flow: unattributable non-zero exit fails closed"
unset -f nix

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "❌ $TEST_FAILURES fixture test(s) FAILED"
  exit 1
fi
echo "✅ all vendor-freshness fixture tests passed"
