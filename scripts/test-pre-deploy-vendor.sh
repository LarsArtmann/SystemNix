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
# derivation-closure excerpt (2026-11-27, the go-taskqueue/journal deploy);
# the realising build, one keep-going call over three tiny FODs of which
# two were stale, and a clean single realise (2026-11-27).
# Run: bash scripts/test-pre-deploy-vendor.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# VF_LIB lets the mutation legs at the end source a mutated copy.
VF_LIB="${VF_LIB:-$REPO_ROOT/scripts/lib/vendor-freshness.sh}"
# shellcheck source=scripts/lib/vendor-freshness.sh
source "$VF_LIB"

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
FOD_A=/nix/store/kbwg8d2lb5i5jxhbgnkm0g19ib4zpw0n-crush-daily-12bf69f398ab3309f39c54699d6ec34669107c32-go-modules.drv
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

# --- Fixtures: the realising build (REAL nix output, 2026-11-27 22:5x) ---
#
# Tiny throwaway FODs through the real daemon, the live proof of the hollow
# leg: `nix build <drv> --keep-going` returned 0 on these three and built
# nothing, `nix-store --realise --keep-going` built the correct one and
# failed both stale ones in one call. The plan header is the dry-run's own
# shape; both mismatch blocks and the rc are verbatim.
FOD_TGOOD=/nix/store/s9cq0w633psw7nhp6s5b91k9gbm6mp20-vf-leg1-225614-good-go-modules.drv
FOD_TGOOD_OUT=/nix/store/7272ciyj5gy7ih7l821825wf3ji67f4f-vf-leg1-225614-good-go-modules
FOD_TBAD1=/nix/store/gvdgxc3xhyxh7yc6xq3n2pp7q0iy9jni-vf-leg1-225614-bad1-go-modules.drv
FOD_TBAD1_OUT=/nix/store/xp5x0s31mwv4n5hzzrxyl7xk7840i46i-vf-leg1-225614-bad1-go-modules
FOD_TBAD2=/nix/store/j9hw8xahf7cfkyags65mxkxzvlbhmn27-vf-leg1-225614-bad2-go-modules.drv
FOD_TBAD2_OUT=/nix/store/i36l274537xcggqshq5i2f6a42yihr0h-vf-leg1-225614-bad2-go-modules
FIX_REALISE_DOUBLE="these 3 derivations will be built:
  $FOD_TBAD1
  $FOD_TBAD2
  $FOD_TGOOD
building '$FOD_TBAD1'...
building '$FOD_TBAD2'...
building '$FOD_TGOOD'...
error: hash mismatch in fixed-output derivation '$FOD_TBAD2':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-mOpuTyFvL7S2n/+bOkSELDhobKaF8/VdxIxdP7EQe+Q=
error: hash mismatch in fixed-output derivation '$FOD_TBAD1':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-mOpuTyFvL7S2n/+bOkSELDhobKaF8/VdxIxdP7EQe+Q=
error: build of '$FOD_TBAD1', '$FOD_TBAD2' failed"

# A clean single realise of a fourth FOD (verbatim, rc 0): after it the
# store names that drv as the output's deriver.
FOD_VF=/nix/store/hyc1ib48fqcfjc5fqv2jgknb8bnsk41v-vf-leg1-good2-go-modules.drv
FOD_VF_OUT=/nix/store/2smyq0zhj5zjg3qn39brl9ji3n1gqbna-vf-leg1-good2-go-modules
FIX_REALISE_CLEAN="this derivation will be built:
  $FOD_VF
building '$FOD_VF'...
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
$FOD_VF_OUT"

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

# H2 the realising build's own shapes (2026-11-27 captures).
expect_eq "$(vendor_freshness_extract_fods "$FIX_REALISE_DOUBLE" | wc -l)" "3" "realise plan: its FOD drvs extract like a dry-run's"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_REALISE_DOUBLE" | wc -l)" "2" "real keep-going log: two stale FODs → two pairs"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_REALISE_DOUBLE" | cut -f1 | sort | tr '\n' ' ')" "vf-leg1-225614-bad1-go-modules vf-leg1-225614-bad2-go-modules " "real keep-going log: pairs name their drvs"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_REALISE_DOUBLE" | cut -f3 | sort -u)" "sha256-mOpuTyFvL7S2n/+bOkSELDhobKaF8/VdxIxdP7EQe+Q=" "real keep-going log: both pairs carry the real got-hash"
expect_eq "$(vendor_freshness_classify_build "$FIX_REALISE_DOUBLE" 1)" "mismatch" "real keep-going log: mismatch verdict"
expect_eq "$(vendor_freshness_classify_build "$FIX_REALISE_CLEAN" 0)" "ok" "real clean realise: ok verdict"
expect_eq "$(vendor_freshness_mismatch_pairs "$FIX_REALISE_CLEAN")" "" "real clean realise: no pair"

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
# Pruning keeps receipts whose drv is in the audited closure and drops the
# rest (GC'd derivations, packages that left the config).
vendor_freshness_receipt_write "$FOD_TQ"
vendor_freshness_receipt_write "$FOD_JOURNAL"
printf 'not a drv\n' >"$vf_receipt_dir/00000000000000000000000000000000"
printf 'keep\n' >"$vf_receipt_dir/keep-me"
vendor_freshness_receipt_prune "$FIX_TOP_DRV
$FOD_TQ
"
expect_ok "receipt of an audited drv survives pruning" test -e "$vf_receipt_dir/3pgfc344wpwh7d9az7kmnil3x1xfj2bn"
expect_ok "receipt of a drv outside the closure is pruned" test ! -e "$vf_receipt_dir/hvrvr7zzgbxqwissll1zyig6f43c4q9q"
expect_ok "marker holding no drv path is untouched" test -e "$vf_receipt_dir/00000000000000000000000000000000"
expect_ok "foreign file in the store is untouched" test -e "$vf_receipt_dir/keep-me"
rm -rf "$vf_receipt_dir"

# G gate flow, end to end, against stubbed `nix` (preview, drvPath eval)
# and `nix-store` (closure, outputs, deriver, realising build, check
# mode), and a pinned tree: the verdict strings are what §11 prints.
# The callbacks are read inside the sourced gate lib (so shellcheck sees the
# two variables and the two functions as unused here).
vf_verdicts=""
# shellcheck disable=SC2329
vf_pass() { vf_verdicts="$vf_verdicts|PASS $1"; }
# shellcheck disable=SC2329
vf_fail() { vf_verdicts="$vf_verdicts|FAIL $1"; }
# shellcheck disable=SC2034
VENDOR_FRESHNESS_PASS=vf_pass
# shellcheck disable=SC2034
VENDOR_FRESHNESS_FAIL=vf_fail
vendor_freshness_tree_pin() { printf 'deadbee deadbee'; }
VF_STUB_TOP_DRV="$FIX_TOP_DRV"
VF_STUB_TOP_RC=0
VF_STUB_DRYRUN_OUT=""
VF_STUB_DRYRUN_RC=0
VF_STUB_CLOSURE=""
VF_STUB_CLOSURE_RC=0
declare -A VF_STUB_OUTPUTS=() VF_STUB_OUTPUTS_RC=() VF_STUB_VALID=() VF_STUB_DERIVERS=()
VF_STUB_CHECK_OUT=""
VF_STUB_CHECK_RC=0
# Leg 1's build, as the stub store answers `nix-store --realise --keep-going`:
# VF_STUB_BUILD_RC is its exit status, VF_STUB_BUILD_OUT its log, and what
# it did to the requested outputs is one of
#   VF_STUB_BUILD_MODE=hollow   a success that changes nothing (the
#                              `nix build <drv>` class: rc 0, no build)
#   otherwise, a keep-going build: every requested drv whose NAME is not
#   in VF_STUB_BUILD_FAILED becomes valid, and VF_STUB_BUILD_DERIVER (the
#   drv itself unless set) is recorded as its builder, whatever the rc.
VF_STUB_BUILD_OUT=""
VF_STUB_BUILD_RC=0
VF_STUB_BUILD_MODE=build
VF_STUB_BUILD_DERIVER=""
VF_STUB_BUILD_FAILED=""
vf_receipt_root=$(mktemp -d)
vf_receipt_runs=0
# Counters live in FILES: the stubs run inside $(…) subshells, where a
# shell-variable increment is lost.
vf_check_log="$vf_receipt_root/check-calls"
vf_realise_log="$vf_receipt_root/realise-calls"
vf_closure_log="$vf_receipt_root/closure-calls"
vf_stray_log="$vf_receipt_root/stray-calls"
# One redirection per command (several on one `:` line trip SC2261).
vf_truncate() {
  local file
  for file in "$@"; do : >"$file"; done
}
vf_truncate "$vf_check_log" "$vf_realise_log" "$vf_closure_log" "$vf_stray_log"
vf_check_calls() { wc -l <"$vf_check_log" | tr -d ' '; }
vf_closure_calls() { wc -l <"$vf_closure_log" | tr -d ' '; }
vf_receipt_name() {
  local base="${1##*/}"
  printf '%s' "${base%%-*}"
}
vf_realised() { sort "$vf_realise_log"; }
vf_stray_calls() { wc -l <"$vf_stray_log" | tr -d ' '; }
vf_fail_count() { printf '%s' "$vf_verdicts" | grep -o '|FAIL ' | wc -l; }
nix() {
  case " $* " in
  *" --dry-run "*)
    printf '%s\n' "$VF_STUB_DRYRUN_OUT"
    return "$VF_STUB_DRYRUN_RC"
    ;;
  *" eval --raw "*)
    printf '%s' "$VF_STUB_TOP_DRV"
    return "$VF_STUB_TOP_RC"
    ;;
  *)
    # Any other nix call inside the gate is a regression: the verb that
    # realises is `nix-store --realise`, and a raw .drv installable is
    # exactly what made leg 1 hollow for 54 days.
    printf 'nix %s\n' "$*" >>"$vf_stray_log"
    return 99
    ;;
  esac
}
nix-store() {
  local drv out
  case "${1-} ${2-}" in
  "-qR "*)
    printf 'x\n' >>"$vf_closure_log"
    printf '%s\n' "$VF_STUB_CLOSURE"
    return "$VF_STUB_CLOSURE_RC"
    ;;
  "-q --outputs")
    printf '%s\n' "${VF_STUB_OUTPUTS[$3]-}"
    return "${VF_STUB_OUTPUTS_RC[$3]-0}"
    ;;
  "-q --deriver")
    if [ -n "${VF_STUB_VALID[$3]-}" ]; then
      printf '%s\n' "${VF_STUB_DERIVERS[$3]-}"
      return 0
    fi
    printf '%s\n' "$FIX_DERIVER_INVALID" >&2
    return 1
    ;;
  "--realise --keep-going")
    for drv in "$@"; do
      case "$drv" in *.drv) printf '%s\n' "$drv" >>"$vf_realise_log" ;; esac
    done
    printf '%s\n' "$VF_STUB_BUILD_OUT"
    if [ "$VF_STUB_BUILD_MODE" != hollow ] && [ "$VF_STUB_BUILD_RC" -ne 0 ]; then
      :
    fi
    if [ "$VF_STUB_BUILD_MODE" != hollow ]; then
      for drv in "$@"; do
        case "$drv" in
        *.drv) ;;
        *) continue ;;
        esac
        out=${VF_STUB_OUTPUTS[$drv]-}
        [ -n "$out" ] || continue
        if grep -qxF -- "$(vendor_freshness_drv_name "$drv")" <<<"$VF_STUB_BUILD_FAILED"; then continue; fi
        VF_STUB_VALID[$out]=1
        VF_STUB_DERIVERS[$out]=${VF_STUB_BUILD_DERIVER:-$drv}
      done
    fi
    return "$VF_STUB_BUILD_RC"
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
# Reset the stub store and the gate's knobs before a flow: no output is
# valid, a build succeeds and builds, check mode reproduces. The stray-call
# log is NOT reset: it is asserted empty once, over all flows.
vf_empty_store() {
  VF_STUB_VALID=()
  VF_STUB_DERIVERS=()
  VF_STUB_BUILD_OUT=""
  VF_STUB_BUILD_RC=0
  VF_STUB_BUILD_MODE=build
  VF_STUB_BUILD_DERIVER=""
  VF_STUB_BUILD_FAILED=""
  VF_STUB_CHECK_OUT=""
  VF_STUB_CHECK_RC=0
  VF_STUB_TOP_DRV="$FIX_TOP_DRV"
  VF_STUB_TOP_RC=0
  VF_STUB_CLOSURE_RC=0
  VF_STUB_DRYRUN_RC=0
  vf_truncate "$vf_check_log" "$vf_realise_log" "$vf_closure_log"
  vf_verdicts=""
}
vf_valid() {
  VF_STUB_VALID[$1]=1
  VF_STUB_DERIVERS[$1]=$2
}
# Every FOD the stub store knows, with its output path.
VF_STUB_OUTPUTS=([$FOD_AB]=$FOD_AB_OUT [$FOD_TQ]=$FOD_TQ_OUT [$FOD_JOURNAL]=$FOD_JOURNAL_OUT)
VF_STUB_OUTPUTS+=([$FOD_VF]=$FOD_VF_OUT [$FOD_TGOOD]=$FOD_TGOOD_OUT [$FOD_TBAD1]=$FOD_TBAD1_OUT [$FOD_TBAD2]=$FOD_TBAD2_OUT)
# Audit input: go-taskqueue built by its own derivation (PROVEN),
# audiblesync's valid output naming an older derivation (REUSED, no
# receipt yet), journal's output not in the store.
vf_proven_and_reused() {
  VF_STUB_CLOSURE="$FIX_CLOSURE"
  vf_valid "$FOD_AB_OUT" /nix/store/f24fbri7k5r3nsxdmx490gjz2d5xi0zi-audiblesync-0.1.1-go-modules.drv
  vf_valid "$FOD_TQ_OUT" "$FOD_TQ"
}
# Audit input: only go-taskqueue, REUSED across the lock float (its output
# names the previous rev's derivation): the stale-FOD shape.
vf_reused_tq() {
  VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_TQ
"
  vf_valid "$FOD_TQ_OUT" "$FOD_TQ_OLD_DERIVER"
}

# G1 noise + plan + one FOD that is not valid: the gate realises exactly
# that FOD (the deploy build's own work, done now), the store names its
# derivation as the builder, and the audit counts every FOD of the closure:
# PASS, the noise disclosed.
vf_empty_store
vf_fresh_receipts
vf_valid "$FOD_AB_OUT" "$FOD_AB"
vf_valid "$FOD_TQ_OUT" "$FOD_TQ"
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_AB
$FOD_TQ
$FOD_VF
"
VF_STUB_DRYRUN_OUT="this derivation will be built:
  $FOD_VF
$FIX_NARINFO_SINGLE"
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — 1 go-modules FOD(s) realised (built or fetched now, output paths valid) + 3 go-modules FOD(s) of the closure verified (3 by deriver identity, 0 re-verified by check-mode rebuild, 0 by prior receipt) \[tree deadbee\* (1 benign nix error line(s) ignored)\]" "flow: benign noise read past, the FOD that was not valid is realised, every closure FOD verified, noise disclosed"
expect_eq "$(vf_realised)" "$FOD_VF" "flow: leg 1 realises exactly the FOD whose output was not valid"
expect_eq "$(vf_closure_calls)" "1" "flow: the closure is enumerated once for both legs"
expect_eq "$(vf_check_calls)" "0" "flow: FODs built by their own derivation are not re-verified"
expect_eq "$(vf_stray_calls)" "0" "flow: the gate never calls nix build (a raw .drv installable builds nothing)"

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
# store: nothing is built, so no compile can hit a stale FOD. (Until
# 2026-11-27 this verdict read "vendorHash proven by prior builds".)
vf_empty_store
vf_fresh_receipts
VF_STUB_DRYRUN_OUT="$FIX_NOISE_CACHED"
VF_STUB_DRYRUN_RC=0
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — nothing to build locally (the preview substitutes or is fully cached, so no compile consults a FOD) \[tree deadbee\* (1 benign nix error line(s) ignored)\]" "flow: cached preview with noise passes"
expect_eq "$(vf_closure_calls)" "0" "flow: a non-building preview skips both legs"
expect_eq "$(vf_realised)" "" "flow: a non-building preview realises nothing"

# G4 THE REAL 2026-11-27 CAPTURE: one keep-going realise of three FODs,
# two stale. One FAIL per stale FOD with its own got-hash, and no second
# verdict for the two the failed build already reported.
vf_empty_store
vf_fresh_receipts
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_TGOOD
$FOD_TBAD1
$FOD_TBAD2
"
VF_STUB_DRYRUN_OUT="these 4 derivations will be built:
  $FOD_TBAD1
  $FOD_TBAD2
  $FOD_TGOOD
$FIX_TOP_DRV"
VF_STUB_BUILD_OUT="$FIX_REALISE_DOUBLE"
VF_STUB_BUILD_RC=1
VF_STUB_BUILD_FAILED="vf-leg1-225614-bad1-go-modules
vf-leg1-225614-bad2-go-modules"
vf_stdout_file=$(mktemp)
vendor_freshness_run_gate >"$vf_stdout_file" 2>&1
vf_stdout=$(cat "$vf_stdout_file")
rm -f "$vf_stdout_file"
vf_stale_names() {
  printf '%s' "$vf_verdicts" | grep -o 'FAIL vendorHash STALE — FOD hash mismatch in [^:]*' | sort | tr '\n' ';'
}
expect_eq "$(vf_stale_names)" \
  "FAIL vendorHash STALE — FOD hash mismatch in vf-leg1-225614-bad1-go-modules;FAIL vendorHash STALE — FOD hash mismatch in vf-leg1-225614-bad2-go-modules;" \
  "flow: every stale FOD of the real log is reported, whatever order the daemon failed them in"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'specified sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=, got sha256-mOpuTyFvL7S2n/+bOkSELDhobKaF8/VdxIxdP7EQe+Q=' | wc -l)" "2" "flow: each FAIL carries specified and got verbatim"
expect_eq "$(vf_fail_count)" "2" "flow: two stale FODs are two FAILs, no third for the outputs left invalid"
expect_eq "$(printf '%s' "$vf_stdout" | grep -c 'hash mismatch in fixed-output derivation')" "2" "flow: the gate output carries both verbatim blocks fod-hash-diff parses"
expect_eq "$(vendor_freshness_mismatch_pairs "$vf_stdout" | wc -l)" "2" "flow: the §11 log is a batch-repair input as-is"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -c 'NOT REALISED')" "0" "flow: a FOD whose failed build was reported is not reported twice"

# G5 noise alone, non-zero exit, no plan: fail closed.
VF_STUB_DRYRUN_OUT="$FIX_NOISE_CACHED"
VF_STUB_DRYRUN_RC=1
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL toplevel --dry-run FAILED (exit 1) \[tree deadbee\*\]*" "flow: unattributable non-zero exit fails closed"

# G6 THE 2026-11-27 SHAPE: the preview lists no go-modules FOD as "will be
# built", one FOD of the closure is not valid, one cached FOD names another
# derivation, and its check-mode rebuild reproduces: the FOD is realised,
# the reused one re-verified once, PASS, receipt written.
vf_empty_store
vf_fresh_receipts
vf_proven_and_reused
VF_STUB_DRYRUN_OUT="$FIX_PREVIEW_NO_FOD"
VF_STUB_CHECK_OUT="$FIX_CHECK_OK"
VF_STUB_CHECK_RC=0
# A receipt for a drv outside this closure (e.g. since GC'd): the audit
# must drop it. Asserted present first: until 2026-11-27 this check named
# a file that had never been written (the fixture drv carried a 33-char
# hash, which the receipt store wrote and the prune step, rightly, skips).
vendor_freshness_receipt_write "$FOD_A"
expect_ok "setup: the out-of-closure receipt exists before the gate runs" test -s "$VENDOR_FRESHNESS_RECEIPT_DIR/$(vf_receipt_name "$FOD_A")"
vf_stdout_file=$(mktemp)
vendor_freshness_run_gate >"$vf_stdout_file" 2>&1
vf_stdout=$(cat "$vf_stdout_file")
rm -f "$vf_stdout_file"
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — 1 go-modules FOD(s) realised (built or fetched now, output paths valid) + 3 go-modules FOD(s) of the closure verified (2 by deriver identity, 1 re-verified by check-mode rebuild, 0 by prior receipt) \[tree deadbee\*\]" "flow: the FOD that was not valid is realised, the reused FOD that reproduces is re-verified, PASS"
expect_eq "$(vf_realised)" "$FOD_JOURNAL" "flow: only the FOD without a valid output is realised"
expect_eq "$(vf_check_calls)" "1" "flow: exactly the reused FOD is re-verified (the proven and the just-built one are not)"
expect_match "$vf_stdout" "*re-verifying FOD (the store names another derivation as its builder): audiblesync-0.1.1-go-modules*" "flow: the re-verification is announced"
expect_ok "flow: PASS writes the receipt" test -s "$VENDOR_FRESHNESS_RECEIPT_DIR/2cm4syk9yzpaarf5d4yllj1v1y7ywhkj"
expect_ok "flow: a receipt outside the audited closure is pruned" test ! -e "$VENDOR_FRESHNESS_RECEIPT_DIR/$(vf_receipt_name "$FOD_A")"

# G7 the receipt converges: the next run over the same closure neither
# builds nor re-verifies.
vf_truncate "$vf_check_log" "$vf_realise_log"
vf_verdicts=""
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — 3 go-modules FOD(s) of the closure verified (2 by deriver identity, 0 re-verified by check-mode rebuild, 1 by prior receipt) \[tree deadbee\*\]" "flow: a receipted FOD is not re-verified"
expect_eq "$(vf_check_calls)" "0" "flow: receipted FOD costs no rebuild"
expect_eq "$(vf_realised)" "" "flow: a closure of valid outputs realises nothing"

# G8 the deploy-killer: the reused FOD is STALE: FAIL naming the drv and
# the got-hash, with the verbatim mismatch block in the gate's output (a
# §11 log is a scripts/fod-hash-diff.sh input as-is).
vf_empty_store
vf_fresh_receipts
vf_reused_tq
VF_STUB_CHECK_OUT="$FIX_CHECK_MISMATCH"
VF_STUB_CHECK_RC=1
vf_stdout_file=$(mktemp)
vendor_freshness_run_gate >"$vf_stdout_file" 2>&1
vf_stdout=$(cat "$vf_stdout_file")
rm -f "$vf_stdout_file"
expect_match "${vf_verdicts#|}" "FAIL vendorHash STALE on a REUSED FOD: go-taskqueue-0.4.2-go-modules:*got sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=*fod-hash-diff.sh*" "flow: a stale REUSED FOD FAILs with its got-hash"
expect_eq "$(vendor_freshness_mismatch_pairs "$vf_stdout" | cut -f3)" "sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=" "flow: the gate output carries the verbatim block fod-hash-diff parses"
expect_ok "flow: a mismatch writes no receipt" test ! -e "$VENDOR_FRESHNESS_RECEIPT_DIR/3pgfc344wpwh7d9az7kmnil3x1xfj2bn"

# G9 a reused FOD whose rebuild fails for a non-hash reason blocks too.
vf_empty_store
vf_fresh_receipts
vf_proven_and_reused
VF_STUB_CHECK_OUT="error: cannot connect to nix daemon"
VF_STUB_CHECK_RC=100
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL go-modules FOD re-verify FAILED (non-hash error): audiblesync-0.1.1-go-modules;*" "flow: non-hash re-verify failure FAILs"

# G10 the closure query failing fails closed: nothing is built, nothing
# passes.
vf_empty_store
vf_fresh_receipts
VF_STUB_CLOSURE="error: path '…' is not valid"
VF_STUB_CLOSURE_RC=1
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL cannot enumerate the toplevel derivation closure (nix-store -qR exit 1)*the FOD gate is unavailable*refusing to deploy blind*" "flow: a failed closure query FAILs closed"
expect_eq "$(vf_fail_count)" "1" "flow: a failed closure query yields exactly one FAIL"
expect_eq "$(vf_realised)" "" "flow: nothing is built on a failed closure query"

# G11 no toplevel drv in the preview and the eval fallback fails: FAIL.
vf_empty_store
VF_STUB_DRYRUN_OUT="this derivation will be built:
  /nix/store/0kdlh4w3c3j0nhs0d5calqri7wy436az-go-taskqueue-0.4.2.drv"
VF_STUB_TOP_DRV="error: attribute 'system' missing"
VF_STUB_TOP_RC=1
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL cannot resolve the toplevel derivation (drvPath lookup exit 1) \[tree deadbee\*\]*the FOD gate is unavailable*a stale CACHED FOD is invisible to the preview*" "flow: unresolvable toplevel drv FAILs closed"

# G12 two independent stale FODs of the 10:34 lock wave in one keep-going
# build: one FAIL each, each with its OWN got-hash.
vf_empty_store
vf_fresh_receipts
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_TQ
$FOD_JOURNAL
"
VF_STUB_DRYRUN_OUT="these 3 derivations will be built:
  $FOD_TQ
  $FOD_JOURNAL
$FIX_TOP_DRV"
VF_STUB_BUILD_OUT="$FIX_MISMATCH_DOUBLE"
VF_STUB_BUILD_RC=1
VF_STUB_BUILD_FAILED="$(vendor_freshness_mismatch_pairs "$FIX_MISMATCH_DOUBLE" | cut -f1)"
vendor_freshness_run_gate >/dev/null
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'FAIL vendorHash STALE — FOD hash mismatch in [^:]*' | tr '\n' ';')" "FAIL vendorHash STALE — FOD hash mismatch in go-taskqueue-0.4.2-go-modules;FAIL vendorHash STALE — FOD hash mismatch in journal-f32e70c2ff4f5c2c2102bd68cce062e26cd09fd6-go-modules;" "flow: every stale FOD is reported"
expect_eq "$(vf_fail_count)" "2" "flow: exactly one FAIL per stale FOD"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'sha256-HqHkPDVQzCzGP5GlaRy4wpumugJTLb2nEZt9UQlEIH0=' | wc -l)" "1" "flow: first got-hash appears once"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -o 'sha256-2piQtqwofrGHq5IsRjyH5MFQasYLZikjE50O0+WQV6c=' | wc -l)" "1" "flow: second got-hash appears once"

# G13 THE HOLLOW LEG (2026-10-04 to 2026-11-27): the realising command
# returns success and changes nothing, the `nix build <drv>` class. The
# exit code says built; the store says otherwise, and the gate blocks.
vf_empty_store
vf_fresh_receipts
vf_proven_and_reused
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_AB
$FOD_TQ
$FOD_VF
"
VF_STUB_DRYRUN_OUT="this derivation will be built:
  $FOD_VF
$FIX_TOP_DRV"
VF_STUB_BUILD_OUT="$FOD_VF"
VF_STUB_BUILD_RC=0
VF_STUB_BUILD_MODE=hollow
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL go-modules FOD NOT REALISED: vf-leg1-good2-go-modules:*still not valid after the gate's \`nix-store --realise\`*refusing to deploy blind*" "flow: a realise that returns success without building FAILs"
expect_eq "$(vf_fail_count)" "1" "flow: the unrealised FOD is exactly one FAIL"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -c '|PASS ')" "0" "flow: no PASS is printed over an output that was never built"

# G14 a FOD the realising command FETCHED (a substituter built it): the
# output is valid, the store names another derivation, so the audit
# re-verifies it in check mode before the gate passes.
vf_empty_store
vf_fresh_receipts
vf_valid "$FOD_AB_OUT" "$FOD_AB"
vf_valid "$FOD_TQ_OUT" "$FOD_TQ"
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_AB
$FOD_TQ
$FOD_VF
"
VF_STUB_CHECK_OUT="$FIX_CHECK_OK"
VF_STUB_BUILD_DERIVER="$FOD_TQ_OLD_DERIVER"
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "PASS vendorHash valid — 1 go-modules FOD(s) realised (built or fetched now, output paths valid) + 3 go-modules FOD(s) of the closure verified (2 by deriver identity, 1 re-verified by check-mode rebuild, 0 by prior receipt) \[tree deadbee\*\]" "flow: a fetched FOD passes only after its check-mode rebuild"
expect_eq "$(vf_check_calls)" "1" "flow: exactly the fetched FOD is re-verified"

# G15 the build itself fails for a non-hash reason: the gate blocks, names
# the error, and names the FOD that did not get built.
vf_empty_store
vf_fresh_receipts
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_VF
"
VF_STUB_DRYRUN_OUT="this derivation will be built:
  $FOD_VF
$FIX_TOP_DRV"
VF_STUB_BUILD_OUT="error: cannot connect to nix daemon"
VF_STUB_BUILD_RC=100
VF_STUB_BUILD_FAILED="vf-leg1-good2-go-modules"
vf_stdout_file=$(mktemp)
vendor_freshness_run_gate >"$vf_stdout_file" 2>&1
vf_stdout=$(cat "$vf_stdout_file")
rm -f "$vf_stdout_file"
expect_match "${vf_verdicts#|}" "FAIL go-modules FOD build FAILED (non-hash error)*last lines: \[tree deadbee\*\]*" "flow: a non-hash build failure FAILs"
expect_match "$vf_stdout" "*error: cannot connect to nix daemon*" "flow: the build error is shown"
expect_match "${vf_verdicts#|}" "*NOT REALISED: vf-leg1-good2-go-modules*" "flow: the FOD the failed build left invalid is named"

# G16 the tree moving under the gate voids the verdict (the 2026-10-09
# 22:31 class): no PASS on a tree that changed, whether the move is seen
# after the build or after the audit.
vf_empty_store
vf_fresh_receipts
vf_valid "$FOD_JOURNAL_OUT" "$FOD_JOURNAL"
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_AB
$FOD_TQ
$FOD_VF
"
VF_STUB_CHECK_OUT="$FIX_CHECK_OK"
VF_STUB_DRYRUN_OUT="this derivation will be built:
  $FOD_VF
$FIX_TOP_DRV"
vf_pins="$vf_receipt_root/pins"
: >"$vf_pins"
vendor_freshness_tree_pin() {
  printf 'x\n' >>"$vf_pins"
  if [ "$(wc -l <"$vf_pins")" -lt 2 ]; then printf 'deadbee deadbee'; else printf 'cafe cafe'; fi
}
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL eval-relevant tree MUTATED during §11 (deadbee\* → cafe\*)*the FOD verdict is void for the new tree*" "flow: a tree mutation after the build voids the verdict"
expect_eq "$(vf_fail_count)" "1" "flow: the mutation is reported once"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -c '|PASS ')" "0" "flow: no PASS on a moved tree"
vf_truncate "$vf_pins" "$vf_realise_log"
vf_verdicts=""
VF_STUB_CLOSURE="$FIX_CLOSURE"
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL eval-relevant tree MUTATED during §11 (deadbee\* → cafe\*)*the FOD verdict is void for the new tree*" "flow: a tree mutation after the audit voids the verdict"
expect_eq "$(vf_realised)" "" "flow: the audit-only run had nothing to build"
vendor_freshness_tree_pin() { printf 'deadbee deadbee'; }

# G17 a closure FOD whose output path cannot be resolved is unknown
# state: FAIL, never skipped.
vf_empty_store
vf_fresh_receipts
VF_STUB_CLOSURE="$FIX_TOP_DRV
$FOD_A
"
VF_STUB_CHECK_OUT="$FIX_CHECK_OK"
VF_STUB_DRYRUN_OUT="this derivation will be built:
  $FOD_A
$FIX_TOP_DRV"
VF_STUB_OUTPUTS_RC=([$FOD_A]=1)
vendor_freshness_run_gate >/dev/null
expect_match "${vf_verdicts#|}" "FAIL cannot resolve the output path of crush-daily-12bf69f398ab3309f39c54699d6ec34669107c32-go-modules (nix-store -q --outputs failed): its state is unknown*refusing to deploy blind*" "flow: an unresolvable output path FAILs closed"
expect_eq "$(vf_fail_count)" "1" "flow: an unresolvable output path is exactly one FAIL"
expect_eq "$(printf '%s' "$vf_verdicts" | grep -c '|PASS ')" "0" "flow: no PASS over an unknown FOD"

# Over every flow above: the gate asked `nix` for the preview and the
# drvPath eval only.
expect_eq "$(vf_stray_calls)" "0" "flow: across all flows the gate never calls nix build or any other nix verb"

unset -f nix nix-store
rm -rf "$vf_receipt_root"

# --- M Mutation legs (2026-11-27) ---
# Each regression this gate already lived through is re-applied to a copy
# of the lib, and this suite must FAIL against it (the copy is sourced by
# a child run of this script). A suite that passes against the bug it
# exists for is the hollow-leg lesson: these fixtures were green for 54
# days while the gate built nothing.
vf_mut_dir=$(mktemp -d)
if [ "${VF_MUTATION_CHILD:-0}" = 0 ] && [ "$TEST_FAILURES" -eq 0 ]; then
  while IFS=$'\t' read -r vf_mut_name vf_mut_sed; do
    [ -n "$vf_mut_name" ] || continue
    vf_mut_lib="$vf_mut_dir/$vf_mut_name.sh"
    sed "$vf_mut_sed" "$VF_LIB" >"$vf_mut_lib"
    if [ "$(sha256sum <"$VF_LIB")" = "$(sha256sum <"$vf_mut_lib")" ]; then
      echo "  FAIL mutation $vf_mut_name did not apply (its sed matched nothing in the lib)"
      TEST_FAILURES=$((TEST_FAILURES + 1))
    elif VF_MUTATION_CHILD=1 VF_LIB="$vf_mut_lib" bash "${BASH_SOURCE[0]}" >/dev/null 2>&1; then
      echo "  FAIL mutation $vf_mut_name SURVIVED: this suite passes against the regression"
      TEST_FAILURES=$((TEST_FAILURES + 1))
    else
      echo "  ok   mutation $vf_mut_name is caught"
    fi
  done <<'EOF'
hollow-verb	s|nix-store --realise --keep-going \$to_build|nix build $to_build --keep-going|
audit-skips-unrealised	/go-modules FOD NOT REALISED/d
preview-only-input	s|to_build=\$(vendor_freshness_uncached_fods "\$fods")|to_build=$(printf '%s\\n' "$dryrun_out" \| grep -E -- '-go-modules\\.drv$' \| sort -u \|\| true)|
reported-fod-reported-twice	s|if grep -qxF -- "\$name" <<<"\$reported"; then|if false; then|
EOF
fi
rm -rf "$vf_mut_dir"

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "❌ $TEST_FAILURES fixture test(s) FAILED"
  exit 1
fi
echo "✅ all vendor-freshness fixture tests passed"
