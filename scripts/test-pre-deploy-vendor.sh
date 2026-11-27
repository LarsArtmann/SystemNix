#!/usr/bin/env bash
# Fixture tests for the pre-deploy §11 vendorHash-freshness parsers and
# gate flow (scripts/lib/vendor-freshness.sh). §11 FAILs block the deploy,
# so a parser that silently matches nothing must be impossible — the greps
# it replaced matched output nix never produces and warned "unable to
# determine status" on every run for two months while the stale-vendorHash
# class broke two deploys (2026-08).
#
# Fixtures are REAL captured nix output (evo-x2): the uncached/cached
# toplevel dry-run shapes and a genuine FOD hash mismatch (2026-10-04,
# bogus outputHash override, wording verbatim); the cached-FOD audit
# shapes — deriver records, check-mode rebuild pass and mismatch, a
# derivation-closure excerpt (2026-11-27, the go-taskqueue/journal deploy).
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
# Assert a command succeeds (file-state checks after a flow).
expect_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  ok   $desc"
  else
    echo "  FAIL $desc"
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

# --- Fixtures: the cached-FOD audit (REAL nix output, 2026-11-27) ---
#
# The 12:0x deploy: §11 printed "20 uncached FODs built clean", the preview
# listed no go-modules FOD, and the build died on go-taskqueue. Its FOD
# output path was valid — built by the derivation of the PREVIOUS lock rev
# (d4bfcc86), so the store names cavivn0c… as deriver while the closure
# holds 3pgfc344… (the af5b6ec5 source).
FOD_TQ=/nix/store/3pgfc344wpwh7d9az7kmnil3x1xfj2bn-go-taskqueue-0.4.2-go-modules.drv
FOD_TQ_OUT=/nix/store/0n0p2vmv9al9qcjii9dgg1rzhadx35vd-go-taskqueue-0.4.2-go-modules
FOD_TQ_OLD_DERIVER=/nix/store/cavivn0cwr0wj53hb8y0q2hrhrf7krg0-go-taskqueue-0.4.2-go-modules.drv
# `nix-store -q --deriver` on a path that is not in the store (stderr, rc 1).
FIX_DERIVER_INVALID="error: path '/nix/store/h6ww26b5jirwlmh39z4xv6j6m37hcf9n-bank-sync-b16fe03d68cc5ec263a7f6561061d0b1fc50fbcd-go-modules' is not valid"

# A building preview that lists NO go-modules FOD: the stale ones are cached
# (excerpt of the 2026-11-27 12:0x deploy preview — 211 "will be built"
# lines, none a FOD; the last line is the toplevel drv).
FIX_PREVIEW_NO_FOD="these 211 derivations will be built:
  /nix/store/0kdlh4w3c3j0nhs0d5calqri7wy436az-go-taskqueue-0.4.2.drv
  /nix/store/wl5jy3vknp4xcdr45yivs65v2zk73ir2-crush.drv
  /nix/store/327wk58qriq8bvj10zsn37hryzp30kmj-nixos-system-evo-x2-26.11.20261121.2786a2a.drv"
FIX_TOP_DRV=/nix/store/327wk58qriq8bvj10zsn37hryzp30kmj-nixos-system-evo-x2-26.11.20261121.2786a2a.drv
FOD_JOURNAL=/nix/store/hvrvr7zzgbxqwissll1zyig6f43c4q9q-journal-f32e70c2ff4f5c2c2102bd68cce062e26cd09fd6-go-modules.drv
# journal's output is NOT in the store (the nix-store stub answers rc 1).
FOD_JOURNAL_OUT=/nix/store/00000000000000000000000000000000-journal-f32e70c2ff4f5c2c2102bd68cce062e26cd09fd6-go-modules
FOD_AB=/nix/store/2cm4syk9yzpaarf5d4yllj1v1y7ywhkj-audiblesync-0.1.1-go-modules.drv
FOD_AB_OUT=/nix/store/sq2ax1minj70q71wpy9mmq561cij3df4-audiblesync-0.1.1-go-modules

# `nix-store -qR <toplevel.drv>` excerpt (34,226 lines live; only the
# *-go-modules.drv lines are FODs — the rest must not match).
FIX_CLOSURE="/nix/store/l622p70vy8k5sh7y5wizi5f2mic6ynpg-source-stdenv.sh
/nix/store/0kdlh4w3c3j0nhs0d5calqri7wy436az-go-taskqueue-0.4.2.drv
$FOD_TQ
$FOD_JOURNAL
/nix/store/4f88azrddc8lkgszmyf56hwmhqvcj846-go-1.27.4.drv
$FOD_AB"

# `nix-store --realise --check <drv>` on the stale go-taskqueue FOD: the
# rebuild runs against the NEW source and the daemon reports the mismatch
# (verbatim, rc 1). Plain `--realise` on the same drv: rc 0, no rebuild.
FIX_CHECK_MISMATCH=$(
  cat <<'EOF'
checking outputs of '/nix/store/3pgfc344wpwh7d9az7kmnil3x1xfj2bn-go-taskqueue-0.4.2-go-modules.drv'...
Running phase: unpackPhase
unpacking source archive /nix/store/rdfq7dbcrinj0sw7s6hkbphrgml9l2xy-source
source root is source
Running phase: patchPhase
Running phase: updateAutotoolsGnuConfigScriptsPhase
Running phase: configurePhase
Running phase: buildPhase
Running phase: installPhase
error: hash mismatch in fixed-output derivation '/nix/store/3pgfc344wpwh7d9az7kmnil3x1xfj2bn-go-taskqueue-0.4.2-go-modules.drv':
         specified: sha256-+JIm293yLjRrZGzaZV2d+OEjfyDyL0judEoReC1Ir+Q=
            got:    sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=
EOF
)

# Same command on a reused FOD that reproduces (verbatim, rc 0): a
# derivation change that did NOT move the module set.
FIX_CHECK_OK=$(
  cat <<'EOF'
checking outputs of '/nix/store/2cm4syk9yzpaarf5d4yllj1v1y7ywhkj-audiblesync-0.1.1-go-modules.drv'...
Running phase: unpackPhase
unpacking source archive /nix/store/sdma5yw3dmfbf21p8x0ndv18mww5vch2-source
source root is source
Running phase: patchPhase
Running phase: updateAutotoolsGnuConfigScriptsPhase
Running phase: configurePhase
Running phase: buildPhase
Running phase: installPhase
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/sq2ax1minj70q71wpy9mmq561cij3df4-audiblesync-0.1.1-go-modules
EOF
)

# A keep-going build of TWO independent stale FODs: both mismatch blocks
# are verbatim daemon text (2026-11-27); both got-hashes must surface.
FIX_MISMATCH_DOUBLE="building '$FOD_TQ'...
error: hash mismatch in fixed-output derivation '$FOD_TQ':
         specified: sha256-+JIm293yLjRrZGzaZV2d+OEjfyDyL0judEoReC1Ir+Q=
            got:    sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=
building '$FOD_JOURNAL'...
error: hash mismatch in fixed-output derivation '$FOD_JOURNAL':
         specified: sha256-9M6laArsh7t+0oKDml4cp2wKKaBtkxVLiPditM0D7So=
            got:    sha256-2piQtqwofrGHq5IsRjyH5MFQasYLZikjE50O0+WQV6c="

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
expect_eq "$(vendor_freshness_classify_build "$FIX_CHECK_MISMATCH" 1)" "mismatch" "check-mode rebuild verdict: mismatch"
expect_eq "$(vendor_freshness_classify_build "$FIX_CHECK_OK" 0)" "ok" "check-mode rebuild verdict: reproduces"

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

# H cached-FOD audit primitives.
expect_eq "$(vendor_freshness_dryrun_builds "$FIX_PREVIEW_NO_FOD" && echo yes || echo no)" "yes" "preview that builds is detected"
expect_eq "$(vendor_freshness_dryrun_builds "$FIX_CACHED" && echo yes || echo no)" "no" "fully cached preview builds nothing"
expect_eq "$(vendor_freshness_dryrun_builds "these 2 paths will be fetched:
  /nix/store/00000000000000000000000000000000-x" && echo yes || echo no)" "no" "substitute-only preview builds nothing"

expect_eq "$(vendor_freshness_top_drv_from_dryrun "$FIX_PREVIEW_NO_FOD")" "$FIX_TOP_DRV" "toplevel drv read off a building preview"
expect_eq "$(vendor_freshness_top_drv_from_dryrun "this derivation will be built:
  $FOD_A")" "" "preview without the toplevel line yields no drv"

expect_eq "$(vendor_freshness_classify_cached "$FOD_TQ" 0 "$FOD_TQ")" "proven" "deriver == drv is proven"
expect_eq "$(vendor_freshness_classify_cached "$FOD_TQ_OLD_DERIVER" 0 "$FOD_TQ")" "reused" "another derivation as deriver is reused"
expect_eq "$(vendor_freshness_classify_cached "unknown-0n0p2vmv9al9qcjii9dgg1rzhadx35vd" 0 "$FOD_TQ")" "reused" "unknown deriver is reused (fail closed)"
expect_eq "$(vendor_freshness_classify_cached "" 1 "$FOD_TQ")" "uncached" "output not valid is uncached"

expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_MISMATCH")" $'dnsblockd-1ffa8ff-go-modules\tsha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\tsha256-hod8/GFv8EN8FkWzs3sKxA4jb4k234/rMKqT1DzK1TQ=' "one stale FOD → one fod-hash-diff pair"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_MISMATCH_DOUBLE" | wc -l)" "2" "two stale FODs → two pairs (domino enumeration)"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_MISMATCH_DOUBLE" | cut -f1 | tr '\n' ' ')" "go-taskqueue-0.4.2-go-modules journal-f32e70c2ff4f5c2c2102bd68cce062e26cd09fd6-go-modules " "pairs carry their drv names"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_MISMATCH_DOUBLE" | cut -f3 | tail -n 1)" "sha256-2piQtqwofrGHq5IsRjyH5MFQasYLZikjE50O0+WQV6c=" "each pair carries its OWN got-hash"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_CHECK_OK")" "" "a clean check yields no pair"
expect_eq "$(vendor_freshness_drv_name "$FOD_TQ")" "go-taskqueue-0.4.2-go-modules" "drv name drops the store hash"
expect_eq "$(vendor_freshness_drv_name "$FOD_JOURNAL")" "journal-f32e70c2ff4f5c2c2102bd68cce062e26cd09fd6-go-modules" "drv name keeps the embedded rev"

vf_receipt_dir=$(mktemp -d)
VENDOR_FRESHNESS_RECEIPT_DIR="$vf_receipt_dir"
expect_eq "$(vendor_freshness_receipt_valid "$FOD_TQ" && echo yes || echo no)" "no" "no receipt for an unverified drv"
vendor_freshness_receipt_write "$FOD_TQ"
expect_eq "$(vendor_freshness_receipt_valid "$FOD_TQ" && echo yes || echo no)" "yes" "written receipt validates its drv"
expect_eq "$(vendor_freshness_receipt_valid "$FOD_JOURNAL" && echo yes || echo no)" "no" "a receipt never covers another drv"
expect_eq "$(cat "$vf_receipt_dir/3pgfc344wpwh7d9az7kmnil3x1xfj2bn")" "$FOD_TQ" "receipt is keyed by the drv hash"
# A receipt is bound to ONE exact derivation: a tampered marker (content
# not naming the drv) must not vouch for anything.
printf '%s\n' "$FOD_JOURNAL" >"$vf_receipt_dir/3pgfc344wpwh7d9az7kmnil3x1xfj2bn"
expect_eq "$(vendor_freshness_receipt_valid "$FOD_TQ" && echo yes || echo no)" "no" "receipt whose content names another drv is void"
# Pruning removes only markers whose drv left the store.
vendor_freshness_receipt_write "$FOD_TQ"
printf '%s\n' /nix/store/00000000000000000000000000000000-gone-go-modules.drv >"$vf_receipt_dir/00000000000000000000000000000000"
printf 'keep\n' >"$vf_receipt_dir/keep-me"
vendor_freshness_receipt_prune
expect_ok "live receipt survives pruning" test -e "$vf_receipt_dir/3pgfc344wpwh7d9az7kmnil3x1xfj2bn"
expect_ok "receipt for a gone drv is pruned" test ! -e "$vf_receipt_dir/00000000000000000000000000000000"
expect_ok "foreign file in the store is untouched" test -e "$vf_receipt_dir/keep-me"
rm -rf "$vf_receipt_dir"

# G gate flow, end to end, against stubbed `nix` (preview, drvPath eval,
# FOD build) and `nix-store` (closure, outputs, deriver, check mode), and a
# pinned tree: the verdict strings are what §11 prints.
# The callbacks are read inside the sourced gate lib.
# shellcheck disable=SC2034,SC2329
vf_verdicts=""
vf_pass() { vf_verdicts="$vf_verdicts|PASS $1"; }
vf_fail() { vf_verdicts="$vf_verdicts|FAIL $1"; }
VENDOR_FRESHNESS_PASS=vf_pass
VENDOR_FRESHNESS_FAIL=vf_fail
vendor_freshness_tree_pin() { printf 'deadbee deadbee'; }
VF_STUB_TOP_DRV="$FIX_TOP_DRV"
VF_STUB_TOP_RC=0
VF_STUB_CLOSURE=""
VF_STUB_CLOSURE_RC=0
VF_STUB_CLOSURE_CALLS=0
declare -A VF_STUB_OUTPUTS=() VF_STUB_OUTPUTS_RC=() VF_STUB_DERIVERS=() VF_STUB_DERIVERS_RC=()
VF_STUB_CHECK_OUT=""
VF_STUB_CHECK_RC=0
vf_receipt_root=$(mktemp -d)
vf_receipt_runs=0
# Counters live in FILES: the stubs run inside $(…) subshells, where a
# shell-variable increment is lost.
vf_check_log="$vf_receipt_root/check-calls"
: >"$vf_check_log"
vf_check_calls() { wc -l <"$vf_check_log" | tr -d ' '; }
nix() {
  case " $* " in
    *" --dry-run "*) printf '%s\n' "$VF_STUB_DRYRUN_OUT"; return "$VF_STUB_DRYRUN_RC" ;;
    *" eval --raw "*) printf '%s' "$VF_STUB_TOP_DRV"; return "$VF_STUB_TOP_RC" ;;
    *) printf '%s\n' "$VF_STUB_BUILD_OUT"; return "$VF_STUB_BUILD_RC" ;;
  esac
}
nix-store() {
  case "${1-} ${2-}" in
    "-qR "*)
      VF_STUB_CLOSURE_CALLS=$((VF_STUB_CLOSURE_CALLS + 1))
      printf '%s\n' "$VF_STUB_CLOSURE"
      return "$VF_STUB_CLOSURE_RC"
      ;;
    "-q --outputs")
      printf '%s\n' "${VF_STUB_OUTPUTS[$3]-}"
      return "${VF_STUB_OUTPUTS_RC[$3]-0}"
      ;;
    "-q --deriver")
      printf '%s\n' "${VF_STUB_DERIVERS[$3]-}"
      return "${VF_STUB_DERIVERS_RC[$3]-0}"
      ;;
    "--realise --check")
      printf 'x\n' >>"$vf_check_log"
      printf '%s\n' "$VF_STUB_CHECK_OUT"
      return "$VF_STUB_CHECK_RC"
      ;;
    *)
      echo "nix-store stub: unexpected call: $*" >&2
      return 99
      ;;
  esac
}
# A fresh receipt store per flow (the real one is a per-user cache dir).
vf_fresh_receipts() {
  vf_receipt_runs=$((vf_receipt_runs + 1))
  VENDOR_FRESHNESS_RECEIPT_DIR="$vf_receipt_root/run$vf_receipt_runs"
}
VF_STUB_OUTPUTS=([$FOD_AB]=$FOD_AB_OUT [$FOD_TQ]=$FOD_TQ_OUT [$FOD_JOURNAL]=$FOD_JOURNAL_OUT)
# Audit inputs: go-taskqueue built by its own derivation (PROVEN),
# audiblesync's valid output naming an older derivation (REUSED, no
# receipt yet), journal's output not in the store (UNCACHED — the preview
# leg owns it).
vf_proven_and_reused() {
  VF_STUB_CLOSURE="$FIX_CLOSURE"
  VF_STUB_DERIVERS=([$FOD_AB_OUT]=/nix/store/f24fbri7k5r3nsxdmx490gjz2d5xi0zi-audiblesync-0.1.1-go-modules.drv [$FOD_TQ_OUT]=$FOD_TQ [$FOD_JOURNAL_OUT]="$FIX_DERIVER_INVALID")
  VF_STUB_DERIVERS_RC=([$FOD_JOURNAL_OUT]=1)
}
# Audit input: only go-taskqueue, REUSED across the lock float (its output
# names the previous rev's derivation) — the stale-FOD shape.
vf_reused_tq() {
  VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_TQ
"
  VF_STUB_DERIVERS=([$FOD_TQ_OUT]=$FOD_TQ_OLD_DERIVER)
}

# G1 noise + plan + clean FOD build: PASS, the noise disclosed.
VF_STUB_DRYRUN_OUT="$FIX_NOISE_UNCACHED"
VF_STUB_DRYRUN_RC=0
VF_STUB_BUILD_OUT=""
VF_STUB_BUILD_RC=0
vf_fresh_receipts
VF_STUB_CLOSURE_CALLS=0
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_AB
$FOD_TQ
"
VF_STUB_DERIVERS=([$FOD_AB_OUT]=$FOD_AB [$FOD_TQ_OUT]=$FOD_TQ)
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — 1 uncached go-modules FOD(s) built clean + 2 cached FOD(s) verified (2 by deriver identity, 0 re-verified by check-mode rebuild, 0 by prior receipt) \[tree deadbee\* (1 benign nix error line(s) ignored)\]" "flow: benign noise read past, FOD built clean, cached FODs verified, noise disclosed"
expect_eq "$(vf_check_calls)" "0" "flow: FODs built by their own derivation are not re-verified"

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

# G3 fully cached preview carrying noise: PASS without consulting the
# store — nothing is built, so no compile can hit a stale FOD. (Until
# 2026-11-27 this verdict read "vendorHash proven by prior builds".)
VF_STUB_DRYRUN_OUT="$FIX_NOISE_CACHED"
VF_STUB_DRYRUN_RC=0
vf_fresh_receipts
vf_verdicts=""
VF_STUB_CLOSURE_CALLS=0
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — nothing to build locally (the preview substitutes or is fully cached, so no compile consults a FOD) \[tree deadbee\* (1 benign nix error line(s) ignored)\]" "flow: cached preview with noise passes"
expect_eq "$VF_STUB_CLOSURE_CALLS" "0" "flow: a non-building preview skips the audit"

# G4 stale vendorHash on an UNCACHED FOD: FAIL with the got-hash.
VF_STUB_DRYRUN_OUT="this derivation will be built:
  $FOD_A"
VF_STUB_DRYRUN_RC=0
VF_STUB_BUILD_OUT="$FIX_MISMATCH"
VF_STUB_BUILD_RC=1
vf_fresh_receipts
VF_STUB_CLOSURE=""
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL vendorHash STALE — FOD hash mismatch in dnsblockd-1ffa8ff-go-modules: specified sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=, got sha256-hod8/GFv8EN8FkWzs3sKxA4jb4k234/rMKqT1DzK1TQ=*\[tree deadbee\*\]" "flow: stale vendorHash FAILs with specified and got"

# G5 noise alone, non-zero exit, no plan: fail closed.
VF_STUB_DRYRUN_OUT="$FIX_NOISE_CACHED"
VF_STUB_DRYRUN_RC=1
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL toplevel --dry-run FAILED (exit 1) \[tree deadbee\*\]*" "flow: unattributable non-zero exit fails closed"

# G6 THE 2026-11-27 SHAPE: the preview lists no go-modules FOD (every FOD
# is cached), one cached FOD names another derivation, and its check-mode
# rebuild reproduces → re-verified once, PASS, receipt written.
VF_STUB_DRYRUN_OUT="$FIX_PREVIEW_NO_FOD"
VF_STUB_DRYRUN_RC=0
vf_fresh_receipts
vf_proven_and_reused
VF_STUB_CHECK_OUT="$FIX_CHECK_OK"
VF_STUB_CHECK_RC=0
vf_verdicts=""
vf_stdout_file=$(mktemp)
vendor_freshness_run_gate >"$vf_stdout_file" 2>&1
vf_stdout=$(cat "$vf_stdout_file")
rm -f "$vf_stdout_file"
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — 2 cached FOD(s) verified (1 by deriver identity, 1 re-verified by check-mode rebuild, 0 by prior receipt) \[tree deadbee\*\]" "flow: reused FOD that reproduces is re-verified and passes"
expect_eq "$(vf_check_calls)" "1" "flow: exactly the reused FOD is re-verified (the proven and the uncached one are not)"
expect_match "$vf_stdout" "*re-verifying cached FOD (the store names another derivation as its builder): audiblesync-0.1.1-go-modules*" "flow: the re-verification is announced"
expect_ok "flow: PASS writes the receipt" test -s "$VENDOR_FRESHNESS_RECEIPT_DIR/2cm4syk9yzpaarf5d4yllj1v1y7ywhkj"

# G7 the receipt converges: the next run over the same closure does not
# rebuild again.
: >"$vf_check_log"
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — 2 cached FOD(s) verified (1 by deriver identity, 0 re-verified by check-mode rebuild, 1 by prior receipt) \[tree deadbee\*\]" "flow: a receipted FOD is not re-verified"
expect_eq "$(vf_check_calls)" "0" "flow: receipted FOD costs no rebuild"

# G8 the deploy-killer: the reused FOD is STALE → FAIL naming the drv and
# the got-hash, with the verbatim mismatch block in the gate's output (a
# §11 log is a scripts/fod-hash-diff.sh input as-is).
vf_fresh_receipts
vf_reused_tq
VF_STUB_CHECK_OUT="$FIX_CHECK_MISMATCH"
VF_STUB_CHECK_RC=1
vf_verdicts=""
vf_stdout_file=$(mktemp)
vendor_freshness_run_gate >"$vf_stdout_file" 2>&1
vf_stdout=$(cat "$vf_stdout_file")
rm -f "$vf_stdout_file"
expect_match "${vf_verdicts#|}" "FAIL vendorHash STALE on a CACHED FOD — go-taskqueue-0.4.2-go-modules:*sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=*fod-hash-diff.sh*" "flow: a stale CACHED FOD FAILs with its got-hash"
expect_eq "$(vendor_freshness_mismatch_pairs "$vf_stdout" | cut -f3)" "sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=" "flow: the gate output carries the verbatim block fod-hash-diff parses"
expect_ok "flow: a mismatch writes no receipt" test ! -e "$VENDOR_FRESHNESS_RECEIPT_DIR/3pgfc344wpwh7d9az7kmnil3x1xfj2bn"

# G9 a reused FOD whose rebuild fails for a non-hash reason blocks too.
vf_fresh_receipts
vf_proven_and_reused
VF_STUB_CHECK_OUT="error: cannot connect to nix daemon"
VF_STUB_CHECK_RC=100
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL cached go-modules FOD re-verify FAILED (non-hash error) — audiblesync-0.1.1-go-modules;*" "flow: non-hash re-verify failure FAILs"

# G10 the audit itself failing fails closed.
vf_fresh_receipts
VF_STUB_CLOSURE="error: path '…' is not valid"
VF_STUB_CLOSURE_RC=1
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL cannot enumerate the toplevel derivation closure (nix-store -qR exit 1)*refusing to deploy blind*" "flow: a failed closure query FAILs closed"

# G11 no toplevel drv in the preview and the eval fallback fails: FAIL.
VF_STUB_CLOSURE_RC=0
VF_STUB_DRYRUN_OUT="this derivation will be built:
  /nix/store/0kdlh4w3c3j0nhs0d5calqri7wy436az-go-taskqueue-0.4.2.drv"
VF_STUB_TOP_DRV="error: attribute 'system' missing"
VF_STUB_TOP_RC=1
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL cannot resolve the toplevel derivation (drvPath lookup exit 1) \[tree deadbee\*\]*a stale CACHED FOD is invisible to the preview*" "flow: unresolvable toplevel drv FAILs closed"

# G12 two independent stale UNCACHED FODs in one keep-going build: one
# FAIL each, each with its OWN got-hash.
VF_STUB_TOP_DRV="$FIX_TOP_DRV"
VF_STUB_DRYRUN_OUT="these 2 derivations will be built:
  $FOD_TQ
  $FOD_JOURNAL
$FIX_TOP_DRV"
VF_STUB_BUILD_OUT="$FIX_MISMATCH_DOUBLE"
VF_STUB_BUILD_RC=1
VF_STUB_CLOSURE=""
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'FAIL vendorHash STALE — FOD hash mismatch in [^:]*' | tr '\n' ';')" "FAIL vendorHash STALE — FOD hash mismatch in go-taskqueue-0.4.2-go-modules;FAIL vendorHash STALE — FOD hash mismatch in journal-f32e70c2ff4f5c2c2102bd68cce062e26cd09fd6-go-modules;" "flow: every stale uncached FOD is reported"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'got sha256-' | wc -l)" "2" "flow: two stale FODs carry two got-hashes"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=' | wc -l)" "1" "flow: first got-hash appears once"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'sha256-2piQtqwofrGHq5IsRjyH5MFQasYLZikjE50O0+WQV6c=' | wc -l)" "1" "flow: second got-hash appears once"

# G13 the tree moving during the audit voids the verdict (the 2026-10-09
# 22:31 class): no PASS on a tree that changed under the gate.
vf_fresh_receipts
VF_STUB_DRYRUN_OUT="$FIX_PREVIEW_NO_FOD"
VF_STUB_TOP_DRV="$FIX_TOP_DRV"
vf_proven_and_reused
VF_STUB_CHECK_OUT="$FIX_CHECK_OK"
VF_STUB_CHECK_RC=0
vf_pins="$vf_receipt_root/pins"
: >"$vf_pins"
vendor_freshness_tree_pin() {
  printf 'x\n' >>"$vf_pins"
  if [ "$(wc -l <"$vf_pins")" -lt 2 ]; then printf 'deadbee deadbee'; else printf 'cafe cafe'; fi
}
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
vendor_freshness_tree_pin() { printf 'deadbee deadbee'; }
expect_match "${vf_verdicts#|}" "FAIL eval-relevant tree MUTATED during §11 (deadbee\* → cafe\*)*cached-FOD verdict is void*" "flow: tree mutation during the audit voids the PASS"

unset -f nix nix-store
rm -rf "$vf_receipt_root"

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "❌ $TEST_FAILURES fixture test(s) FAILED"
  exit 1
fi
echo "✅ all vendor-freshness fixture tests passed"
