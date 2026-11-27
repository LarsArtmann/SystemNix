# shellcheck shell=bash
# Shared go-modules FOD verdict helpers for the pre-deploy §11 gate.
# Sourced (NEVER executed) by scripts/pre-deploy-check.sh and
# scripts/test-pre-deploy-vendor.sh — the FAIL verdict blocks deploys, so
# the parsers are fixture-tested against REAL captured nix output
# (2026-10-04, evo-x2). The §11 they replace hardcoded 6 package names and
# grepped for output nix never produces ("would build"): it warned
# "unable to determine status" on every single run from 2026-08-08 onward
# and said nothing about bank-sync, the one package that then hard-failed
# the build (2026-08-22).
#
# The oracle: `nixosConfigurations.evo-x2.config.system.build.toplevel
# --dry-run` is the EXACT preview of what `nh os switch` builds on this
# commit (deploy.sh line ~435). The toplevel's derivation closure holds
# every *-go-modules.drv a compile step of the deploy build consults; a
# stale vendorHash fails there, after ~12 minutes of unrelated building.
# The gate realises and proves the whole set now: clean = vendorHash
# proven + cache warm; mismatch = the August-2026 deploy-killer caught in
# seconds with the got-hash in hand.
#
# rc 0 is not a build (2026-11-27): until that day the preview leg ran
# `nix build <drv> --keep-going` on the .drv paths the dry-run lists. On
# this nix that installable is the .drv FILE, which is already valid, so
# the command returned 0 in about a second and touched nothing. Every
# "N uncached FODs built clean" line since 2026-10-04 described outputs
# that were never built (docs/status/2026-11-27_17-07_deploy-stale-cached-
# fod-fix-landed-section11-leg1-hollow-status.md, section d-1). Two rules
# follow. The verb that realises is `nix-store --realise`. And a verdict
# is read off the store's own record of each output afterwards (is it
# valid, and which derivation built it), never off an exit code.
#
# Captured output shapes (verbatim, see test fixtures):
#   uncached dry-run: "these N derivations will be built:" then
#     "  /nix/store/<hash>-<pkg>-<rev>-go-modules.drv" lines
#   cached dry-run:   nix notices only, no .drv lines
#   realising build:  "this derivation will be built:",
#                     "building '/nix/store/…-go-modules.drv'...", then
#                     rc 0 and the output paths; under --keep-going one
#                     mismatch block per stale FOD and rc 1
#   FOD mismatch:     "error: hash mismatch in fixed-output derivation" +
#     "         specified: sha256-…" + "            got:    sha256-…"
#   dry-run eval fail: "error:" headline, the message on the indented lines
#
# Verdict binding (2026-10-09/10 class): the preview and the FOD builds
# evaluate ONE exact tree. A shared multi-agent tree can mutate mid-gate
# (the 2026-10-09 22:31 "10 built clean" pass was voided by a mid-gate
# mutation; the deploy 5 min later died on an 11th FOD the preview never
# saw), and a stale pass is unauditable after the fact. run_gate therefore
# pins the eval-relevant tree state before its nix work, re-checks it
# after every leg, FAILs loud on change, and stamps each message with
# the short rev (+* when dirty) the verdict was computed against.
#
# Preview-failure contract (2026-11-25, the 01:35 library-policy deploy): a
# dry-run that cannot eval used to degrade to a context-free WARN, so the
# deploy build then carried an UNPROVEN vendorHash set and died ~17 min in.
# A failed preview now FAILs loud with the raw output tail. Only the
# known-benign nix error classes (see vendor_freshness_real_errors) are
# read past, because infrastructure noise must never block the deploy that
# repairs it.
#
# The sourcer MUST define before calling vendor_freshness_run_gate:
#   VENDOR_FRESHNESS_PASS / VENDOR_FRESHNESS_FAIL
#   — reporting callbacks (offsite-borg-smoke OB_PASS pattern; stubs in
#   tests). There is no WARN verdict: the gate either proves the FOD set or
#   blocks. The gate runs under the caller's `set -euo pipefail`, so every
#   fallible command is ||-guarded internally. A `grep -q` at the end of a
#   pipe is NOT a verdict under pipefail: it exits on the first match and
#   the producer dies of SIGPIPE (141), turning a found match into a false
#   negative whenever the producer has more to write (the 2026-11-27
#   fod-hash-diff.sh live-site race). Read to EOF here, or use a
#   here-string.
#
# ---- One enumeration, two legs (2026-11-27) ----
# A fixed-output store path is keyed by the hash that is SPECIFIED, not by
# the content the builder produces. When a lock float moves a package's
# source but the vendorHash literal stays, the output path is unchanged,
# nix hands back the OLD module tree, no builder runs, no mismatch is ever
# printed, and the deploy dies at compile time ("reading …/@v/<ver>.mod:
# no such file"). The preview cannot see it: the path is valid, so nothing
# is "to be built". Per cached FOD the oracle is the store's own record:
#   output not valid         LEG 1 realises it now (build or fetch)
#   deriver == current drv   PROVEN — this exact derivation built it
#   anything else            REUSED — `nix-store --realise --check <drv>`
#                            rebuilds and re-checks outputHash even though
#                            the path is already valid
# Plain `--realise` and `nix build --rebuild` are no-ops on a valid path
# (live 2026-11-27: rc 0, empty log, while `--check` on the same drv
# printed the mismatch 15 s later). Check mode never re-registers the
# output, so the recorded deriver stays the OLD drv for the life of the
# path: a PASS is kept as a receipt keyed by the drv hash. A receipt is
# bound to one exact derivation (src, go.sum, toolchain, specified hash),
# so it cannot go stale while that drv is in the closure; a changed
# derivation has a new name and is re-verified on sight.
# Both legs walk the same closure list. Nothing depends on how the dry-run
# classes a FOD: an output the deploy build would only FETCH is consulted
# by compile steps exactly like one it would build, and a fetched
# stale-hash path is the same trap as a cached one.

# Print the go-modules FOD .drv paths a dry-run preview says would be built.
# Anchor on the .drv suffix: "will be copied" sections list store OUTPUTS
# (no .drv), and a copied FOD output is proof of a valid hash, not a risk.
# The same extractor serves the derivation closure of `nix-store -qR`.
vendor_freshness_extract_fods() {
  local output="$1"
  printf '%s\n' "$output" | grep -E -- '-go-modules\.drv$' || true
}

# Known-benign nix error classes, the vocabulary of pre-deploy check #1
# (scripts/pre-deploy-check.sh, whose inline awk is this filter's twin;
# a new class goes into BOTH):
#   - "is not valid": eval-time path checks that --no-build cannot satisfy.
#   - "unable to download 'https://.../<hash>.narinfo'": substituter
#     unreachability. Nix prints it as `error:` even when it falls back to
#     building locally: infrastructure noise, never a preview fault.
#
# Print only the REAL error lines of a nix output: every `error:` line
# whose block carries no known-benign class. Nix >= 2.26 prints multi-line
# errors as a bare `error:` headline with the message on the indented lines
# below, so line-level filtering cannot see the pair: a headline is benign
# when any line before the next headline matches a benign class (the
# check-#1 block-attribution rule, 2026-09-15).
vendor_freshness_real_errors() {
  printf '%s\n' "$1" | awk '
    {
      lines[NR] = $0
      if ($0 ~ /^[[:space:]]*error:$/) { headline = NR; next }
      if (headline && $0 ~ /is not valid|unable to download .*\.narinfo/) {
        benign[headline] = 1
      }
    }
    END {
      for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /^[[:space:]]*error:$/) {
          if (!(i in benign)) print lines[i]
        } else if (lines[i] ~ /error:/ && lines[i] !~ /is not valid|unable to download .*\.narinfo/) {
          print lines[i]
        }
      }
    }
  '
}

# True when a dry-run output carries its plan ("these N derivations will
# be built", "these N paths will be fetched"): positive evidence the preview
# completed. A fully-cached preview prints nix notices only.
vendor_freshness_dryrun_has_plan() {
  printf '%s\n' "$1" | grep -Eq 'will be (built|fetched|copied|substituted)'
}

# True when the preview builds at least one derivation locally. Only then
# can a stale cached FOD bite (a compile step runs); a preview that only
# substitutes, or prints no plan, consults no FOD.
vendor_freshness_dryrun_builds() {
  case "$1" in
  *"will be built"*) return 0 ;;
  *) return 1 ;;
  esac
}

# The toplevel .drv a building preview lists (empty when the preview does
# not carry it — then the caller falls back to an eval).
vendor_freshness_top_drv_from_dryrun() {
  awk '/\/[a-z0-9]+-nixos-system-evo-x2-[^\/]*\.drv$/ { print $1; exit }' <<<"$1"
}

# True (exit 0) when the dry-run FAILED to produce a preview: a real
# (non-benign) error line, or a non-zero exit that printed no plan (fail
# closed: a fault nix could not attribute still voids the preview). `$2` is
# the dry-run's exit status; absent means 0.
vendor_freshness_dryrun_errored() {
  local output="$1" rc="${2:-0}"
  if [ -n "$(vendor_freshness_real_errors "$output")" ]; then
    return 0
  fi
  if [ "$rc" -ne 0 ] && ! vendor_freshness_dryrun_has_plan "$output"; then
    return 0
  fi
  return 1
}

# Number of `error:` headline/single lines in a nix output, all classes.
vendor_freshness_error_line_count() {
  printf '%s\n' "$1" | grep -c '^[[:space:]]*error:' || true
}

# Verdict suffix for a preview that carried benign-class error lines (""
# when none), so the operator sees that noise was read and set aside.
vendor_freshness_noise_note() {
  local total real
  total=$(vendor_freshness_error_line_count "$1")
  real=$(vendor_freshness_real_errors "$1" | grep -c . || true)
  if [ "$((total - real))" -gt 0 ]; then
    printf ' (%s benign nix error line(s) ignored)' "$((total - real))"
  fi
}

# Indented tail of a failed dry-run's raw output: a verdict is never
# context-free (a bare `error:` is only a headline; the message lives on
# the lines below it).
vendor_freshness_print_raw_tail() {
  printf '%s\n' "$1" | tail -n 12 | sed 's/^/      /'
}

# Extract the got-hash from a FOD hash-mismatch failure (the exact value
# nix-hash-fix consumes). Empty when the failure has no mismatch block.
vendor_freshness_parse_got_hash() {
  local output="$1"
  printf '%s\n' "$output" | grep -E '^[[:space:]]+got:[[:space:]]+sha256-' | head -n 1 | awk '{print $2}' || true
}

# One "<drv name><TAB>specified<TAB>got" line per stale FOD in a nix
# output — the format scripts/fod-hash-diff.sh reads, so a §11 log is a
# batch-repair input as-is. A keep-going build stops scheduling after the
# first failure only for DEPENDENTS; independent stale FODs all fail, and
# reporting the first got-hash alone re-creates the domino.
vendor_freshness_mismatch_pairs() {
  awk '
    /hash mismatch in fixed-output derivation/ {
      drv = $0
      sub(/^.*derivation .\//, "", drv)
      sub(/\.drv.:.*$/, "", drv)
      sub(/^nix\/store\/[a-z0-9]+-/, "", drv)
      want = 1
      next
    }
    want && /specified:/ { specified = $NF; next }
    want && /got:/ { print drv "\t" specified "\t" $NF; want = 0 }
  ' <<<"$1"
}

# Verdict for a real FOD build attempt: "ok" (exit 0), "mismatch" (the
# vendorHash-stale deploy-killer), or "error" (any other failure — the
# deploy build would die the same way, so it still blocks).
vendor_freshness_classify_build() {
  local output="$1" exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    printf 'ok'
  elif printf '%s\n' "$output" | grep -q 'hash mismatch in fixed-output derivation'; then
    printf 'mismatch'
  else
    printf 'error'
  fi
}

# Cached-state verdict for one go-modules FOD of the toplevel closure:
# "uncached" (its output path is not valid — the preview leg owns it),
# "proven" (the store names THIS drv as the deriver), or "reused" (valid,
# but another derivation produced it — unproven until re-verified).
# `$1` is what `nix-store -q --deriver` printed, `$2` its exit status,
# `$3` the drv the closure holds.
vendor_freshness_classify_cached() {
  local deriver="$1" deriver_rc="$2" drv="$3"
  if [ "$deriver_rc" -ne 0 ]; then
    printf 'uncached'
  elif [ "$deriver" = "$drv" ]; then
    printf 'proven'
  else
    printf 'reused'
  fi
}

# Derivation name without the store hash ("<pkg>-go-modules") — the form
# nix's mismatch block and scripts/fod-hash-diff.sh report.
vendor_freshness_drv_name() {
  local base="${1##*/}"
  base=${base#*-}
  printf '%s' "${base%.drv}"
}

# Receipt store: one marker per FOD whose check-mode rebuild PASSED, named
# by the drv hash and holding the drv path. Overridable by the sourcer
# BEFORE run_gate (the fixture tests point it at a scratch dir).
VENDOR_FRESHNESS_RECEIPT_DIR="${VENDOR_FRESHNESS_RECEIPT_DIR:-${XDG_CACHE_HOME:-${HOME:-/nonexistent}/.cache}/systemnix/fod-check-receipts}"

vendor_freshness_receipt_file() {
  local base="${1##*/}"
  printf '%s/%s' "$VENDOR_FRESHNESS_RECEIPT_DIR" "${base%%-*}"
}

# True when a receipt records a check-mode PASS for exactly this drv.
vendor_freshness_receipt_valid() {
  local file
  file=$(vendor_freshness_receipt_file "$1")
  [ -s "$file" ] && [ "$(cat "$file" 2>/dev/null)" = "$1" ]
}

# Record a check-mode PASS. Best effort: an unwritable store only costs a
# re-verification on the next run, never a false verdict.
vendor_freshness_receipt_write() {
  local file
  file=$(vendor_freshness_receipt_file "$1")
  {
    mkdir -p "$VENDOR_FRESHNESS_RECEIPT_DIR" &&
      printf '%s\n' "$1" >"$file"
  } 2>/dev/null || true
}

# Drop receipts whose drv is not in `$1` (the drv list of the last fully
# enumerated closure): GC'd derivations, or packages that left the config.
# A receipt is only ever an optimisation, so losing one costs one rebuild.
# Only plain 32-char hash names holding a drv path are ever removed.
vendor_freshness_receipt_prune() {
  local keep="$1" file name drv
  [ -d "$VENDOR_FRESHNESS_RECEIPT_DIR" ] || return 0
  for file in "$VENDOR_FRESHNESS_RECEIPT_DIR"/*; do
    [ -f "$file" ] || continue
    name=${file##*/}
    [[ $name =~ ^[a-z0-9]{32}$ ]] || continue
    drv=$(head -n 1 "$file" 2>/dev/null || true)
    [[ $drv == /nix/store/*.drv ]] || continue
    if ! grep -qxF -- "$drv" <<<"$keep"; then rm -f "$file"; fi
  done
}

# First output path of a derivation. `nix-store -q --outputs` lists one
# path per output and a go-modules FOD has exactly one. Prints nothing and
# returns 1 when the query fails or the derivation has no output, so no
# caller under `set -e` reads an empty string as a store path.
vendor_freshness_drv_output() {
  local outs
  outs=$(nix-store -q --outputs "$1" 2>/dev/null) || return 1
  [ -n "$outs" ] || return 1
  printf '%s' "${outs%%$'\n'*}"
}

# Print the go-modules FODs of `$1` (a drv list) whose output path is not
# valid: what the deploy build would build or fetch itself, so what leg 1
# realises ahead of it. A drv whose output cannot be resolved is left out
# here; the audit reports it.
vendor_freshness_uncached_fods() {
  local drv out
  while IFS= read -r drv; do
    [ -n "$drv" ] || continue
    out=$(vendor_freshness_drv_output "$drv") || continue
    nix-store -q --deriver "$out" >/dev/null 2>&1 || printf '%s\n' "$drv"
  done <<<"$1"
  return 0
}

# Audit the go-modules FODs of `$1` (the toplevel closure's drv list)
# against the store's own record. `$2` names, one per line in the form
# scripts/fod-hash-diff.sh reports, the FODs whose failed build leg 1
# already reported; while such an output is still not valid it is skipped
# here, so one failure stays one FAIL. Progress lines go to stdout; every
# stale, unrealised or unverifiable FOD is reported through
# VENDOR_FRESHNESS_FAIL with its verbatim nix block; the counts land in
# VENDOR_FRESHNESS_AUDIT_SUMMARY ("proven= receipted= verified= failed=").
vendor_freshness_audit_fods() {
  local fods="$1" reported="$2"
  local drv out_rc=0 out deriver deriver_rc state name
  local proven=0 receipted=0 verified=0 failed=0
  local check_output check_rc got_hash
  while IFS= read -r drv; do
    [ -n "$drv" ] || continue
    name=$(vendor_freshness_drv_name "$drv")
    out_rc=0
    out=$(vendor_freshness_drv_output "$drv") || out_rc=$?
    if [ "$out_rc" -ne 0 ]; then
      failed=$((failed + 1))
      "$VENDOR_FRESHNESS_FAIL" "cannot resolve the output path of $name (nix-store -q --outputs failed): its state is unknown, refusing to deploy blind"
      continue
    fi
    deriver_rc=0
    deriver=$(nix-store -q --deriver "$out" 2>/dev/null) || deriver_rc=$?
    state=$(vendor_freshness_classify_cached "$deriver" "$deriver_rc" "$drv")
    case "$state" in
    proven)
      proven=$((proven + 1))
      ;;
    uncached)
      if grep -qxF -- "$name" <<<"$reported"; then
        continue
      fi
      failed=$((failed + 1))
      "$VENDOR_FRESHNESS_FAIL" "go-modules FOD NOT REALISED: $name: its output path $out is still not valid after the gate's \`nix-store --realise\`, so nothing has proven its vendorHash and the deploy build would build or fetch it unproven. A realise that returns success without building is the 2026-10-04 to 2026-11-27 hollow-leg class; refusing to deploy blind"
      ;;
    reused)
      if vendor_freshness_receipt_valid "$drv"; then
        receipted=$((receipted + 1))
        continue
      fi
      printf '      re-verifying FOD (the store names another derivation as its builder): %s\n' "$name"
      check_rc=0
      check_output=$(nix-store --realise --check "$drv" 2>&1 </dev/null) || check_rc=$?
      case "$(vendor_freshness_classify_build "$check_output" "$check_rc")" in
      ok)
        verified=$((verified + 1))
        vendor_freshness_receipt_write "$drv"
        printf '      ✓ re-verified: %s\n' "$name"
        ;;
      mismatch)
        failed=$((failed + 1))
        got_hash=$(vendor_freshness_parse_got_hash "$check_output")
        "$VENDOR_FRESHNESS_FAIL" "vendorHash STALE on a REUSED FOD: $name: its store path is keyed by the specified hash, so nix served the module tree another derivation built (an older one, or a substituter's) and no mismatch is printed at deploy; the build dies at compile time instead. got ${got_hash:-<unparsed>}. Batch-repair with \`scripts/fod-hash-diff.sh <this log> --apply\` (upstream repos: \`buildflow -s nix-hash-fix --fix\`), never paste by hand"
        printf '%s\n' "$check_output" | grep -A 2 'hash mismatch in fixed-output derivation' | sed 's/^/      /'
        ;;
      *)
        failed=$((failed + 1))
        "$VENDOR_FRESHNESS_FAIL" "go-modules FOD re-verify FAILED (non-hash error): $name; the deploy build would fail the same way; last lines:"
        printf '%s\n' "$check_output" | tail -n 5 | sed 's/^/      /'
        ;;
      esac
      ;;
    esac
  done <<<"$fods" || true
  vendor_freshness_receipt_prune "$fods"
  VENDOR_FRESHNESS_AUDIT_SUMMARY="proven=$proven receipted=$receipted verified=$verified failed=$failed"
}

# Eval-relevant paths a §11 verdict is bound to (word-split; overridable
# by the sourcer BEFORE run_gate). Content changes here — committed or
# working-tree — invalidate the verdict because the preview and the FOD
# builds each evaluated one exact tree.
# shellcheck disable=SC2034  # expanded unquoted inside the helpers
VENDOR_FRESHNESS_EVAL_PATHS="${VENDOR_FRESHNESS_EVAL_PATHS:-flake.nix flake.lock flake lib modules overlays pkgs platforms systems}"

# Snapshot the eval-relevant tree state: "<rev> <clean|<sha256>|- >".
# no-git/- when git is unavailable (sandboxed selftests); the change
# detector treats unresolvable comparisons fail-closed.
vendor_freshness_tree_pin() {
  local rev st digest
  if rev=$(git rev-parse HEAD 2>/dev/null); then
    # shellcheck disable=SC2086  # intentional word-split of path list
    st=$(git status --porcelain -- $VENDOR_FRESHNESS_EVAL_PATHS 2>/dev/null | sort)
    if [ -n "$st" ]; then
      digest=$(printf '%s' "$st" | sha256sum | cut -d' ' -f1)
    else
      digest=clean
    fi
  else
    rev=no-git
    digest="-"
  fi
  printf '%s %s' "$rev" "$digest"
}

# Human stamp for a pin: short rev, '*' when the eval paths carry
# uncommitted changes, plain "no-git" outside a repo.
vendor_freshness_tree_stamp() {
  local suffix=""
  case "${1#* }" in
  clean | -) ;;
  *) suffix='*' ;;
  esac
  printf '%s%s' "$(printf '%s' "${1%% *}" | cut -c1-7)" "$suffix"
}

# rc 0 = the eval-relevant tree changed between the pins (a §11 verdict
# computed against pin 1 is void for pin 2's tree). Fail-closed: a rev
# move whose eval-path delta cannot be resolved (no git, bad revs) or a
# same-rev content-digest change both report changed.
vendor_freshness_tree_changed() {
  local rev_before rev_after
  rev_before=${1%% *}
  rev_after=${2%% *}
  [ "$1" = "$2" ] && return 1
  if [ "$rev_before" = "$rev_after" ]; then
    return 0
  fi
  # Rev moved with identical digest: trip only when the commits between
  # touch an eval path; unresolvable = fail closed.
  # shellcheck disable=SC2086  # intentional word-split of path list
  git diff --name-only --exit-code "$rev_before" "$rev_after" -- $VENDOR_FRESHNESS_EVAL_PATHS >/dev/null 2>&1 && return 1
  return 0
}

# The §11 gate flow, two legs over ONE pinned tree and ONE enumeration of
# the toplevel's derivation closure:
#   1. realise every go-modules FOD whose output is not valid, which is
#      what the deploy build would build or fetch itself, so a stale
#      vendorHash fails here with every got-hash in hand;
#   2. audit the whole set against the store's own record: an output the
#      store attributes to the current drv is proven, any other valid one
#      is re-verified in check mode, and one still not valid after a
#      "successful" realise FAILs (rc 0 is not a build).
# Every stale FOD is one FAIL with its got-hash, so one run enumerates the
# whole wave; then pass/fail goes through the callbacks.
vendor_freshness_run_gate() {
  local dryrun_out dryrun_rc closure closure_rc fods to_build fod_count
  local build_log build_exit build_output moved
  local pin_before pin_after stamp noise_note top_drv top_drv_rc=0 summary leg_failed desc
  local pair_drv pair_spec pair_got pair_count reported
  local audit_failed audit_proven audit_receipted audit_verified audit_total
  local audit_summary_re
  VENDOR_FRESHNESS_AUDIT_SUMMARY=""
  pin_before=$(vendor_freshness_tree_pin)
  stamp=$(vendor_freshness_tree_stamp "$pin_before")
  dryrun_rc=0
  dryrun_out=$(nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --dry-run 2>&1) || dryrun_rc=$?
  if vendor_freshness_dryrun_errored "$dryrun_out" "$dryrun_rc"; then
    moved=""
    pin_after=$(vendor_freshness_tree_pin)
    if vendor_freshness_tree_changed "$pin_before" "$pin_after"; then
      moved="; eval-relevant tree moved during the dry-run: $(vendor_freshness_tree_stamp "$pin_before") → $(vendor_freshness_tree_stamp "$pin_after") (a parallel session's edit is the likely cause)"
    fi
    "$VENDOR_FRESHNESS_FAIL" "toplevel --dry-run FAILED (exit $dryrun_rc) [tree $stamp$moved] — vendorHash preview unavailable, refusing to deploy blind: without this preview a stale vendorHash only dies ~12 min into the deploy build (2026-11-25 01:35, library-policy). Re-run once the raw error below is fixed or the tree settles. Raw output tail follows:"
    vendor_freshness_print_raw_tail "$dryrun_out"
    return 0
  fi
  noise_note=$(vendor_freshness_noise_note "$dryrun_out")
  if ! vendor_freshness_dryrun_builds "$dryrun_out"; then
    "$VENDOR_FRESHNESS_PASS" "vendorHash valid — nothing to build locally (the preview substitutes or is fully cached, so no compile consults a FOD) [tree $stamp$noise_note]"
    return 0
  fi
  leg_failed=0

  # Both legs walk the toplevel's derivation closure, so they need its drv.
  top_drv=$(vendor_freshness_top_drv_from_dryrun "$dryrun_out")
  if [ -z "$top_drv" ]; then
    top_drv=$(nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath 2>/dev/null) || top_drv_rc=$?
  fi
  if [ "$top_drv_rc" -ne 0 ] || ! [[ $top_drv =~ ^/nix/store/[a-z0-9]+-[^/]+\.drv$ ]]; then
    "$VENDOR_FRESHNESS_FAIL" "cannot resolve the toplevel derivation (drvPath lookup exit $top_drv_rc) [tree $stamp] — the FOD gate is unavailable, refusing to deploy blind: a stale CACHED FOD is invisible to the preview and dies at compile time"
    return 0
  fi
  closure_rc=0
  closure=$(nix-store -qR "$top_drv" 2>&1) || closure_rc=$?
  if [ "$closure_rc" -ne 0 ]; then
    "$VENDOR_FRESHNESS_FAIL" "cannot enumerate the toplevel derivation closure (nix-store -qR exit $closure_rc) — the FOD gate is unavailable, refusing to deploy blind. Raw output tail follows:"
    vendor_freshness_print_raw_tail "$closure"
    return 0
  fi
  fods=$(vendor_freshness_extract_fods "$closure" | sort -u)

  # Leg 1: realise what the deploy build would build or fetch itself.
  to_build=$(vendor_freshness_uncached_fods "$fods")
  fod_count=0
  build_exit=0
  reported=""
  if [ -n "$to_build" ]; then
    fod_count=$(printf '%s\n' "$to_build" | wc -l)
    build_log=$(mktemp)
    build_exit=0
    # `nix build <drv>` returns 0 without touching the output (lib header):
    # the verb that builds or fetches is `nix-store --realise`. Its exit
    # status alone is still no verdict; leg 2 reads the store afterwards.
    # shellcheck disable=SC2086  # drv paths are whitespace-free store paths
    nix-store --realise --keep-going $to_build >"$build_log" 2>&1 || build_exit=$?
    pin_after=$(vendor_freshness_tree_pin)
    if vendor_freshness_tree_changed "$pin_before" "$pin_after"; then
      "$VENDOR_FRESHNESS_FAIL" "eval-relevant tree MUTATED during §11 ($(vendor_freshness_tree_stamp "$pin_before") → $(vendor_freshness_tree_stamp "$pin_after")) — the FOD verdict is void for the new tree; re-run §11"
      rm -f "$build_log"
      return 0
    fi
    if [ "$build_exit" -eq 0 ]; then
      rm -f "$build_log"
    else
      leg_failed=1
      build_output=$(cat "$build_log")
      rm -f "$build_log"
      case "$(vendor_freshness_classify_build "$build_output" "$build_exit")" in
      mismatch)
        # One FAIL per stale FOD, each with its OWN got-hash: a
        # keep-going build fails every independent stale FOD, and quoting
        # only the first re-creates the one-domino-per-deploy cycle.
        printf '%s\n' "$build_output" | grep -A 2 'hash mismatch in fixed-output derivation' | sed 's/^/      /'
        pair_count=0
        while IFS=$'\t' read -r pair_drv pair_spec pair_got; do
          [ -n "$pair_drv" ] || continue
          pair_count=$((pair_count + 1))
          "$VENDOR_FRESHNESS_FAIL" "vendorHash STALE — FOD hash mismatch in $pair_drv: specified $pair_spec, got ${pair_got:-<unparsed>} (the deploy build would die here). Batch-repair with \`scripts/fod-hash-diff.sh <this log> --apply\` (upstream repos: \`buildflow -s nix-hash-fix --fix\`), never paste by hand [tree $stamp]"
        done <<<"$(vendor_freshness_mismatch_pairs "$build_output")" || true
        if [ "$pair_count" -eq 0 ]; then
          "$VENDOR_FRESHNESS_FAIL" "vendorHash STALE — FOD hash mismatch (the deploy build would die here; got-hash unparsed, raw tail follows) [tree $stamp]"
          printf '%s\n' "$build_output" | tail -n 5 | sed 's/^/      /'
        fi
        # Leg 2 skips these while they stay invalid: one failure, one FAIL.
        reported=$(vendor_freshness_mismatch_pairs "$build_output" | cut -f1)
        ;;
      *)
        "$VENDOR_FRESHNESS_FAIL" "go-modules FOD build FAILED (non-hash error) — the deploy build would fail the same way; last lines: [tree $stamp]"
        printf '%s\n' "$build_output" | tail -n 5 | sed 's/^/      /'
        ;;
      esac
    fi
  fi

  # Leg 2: the store's own record of every FOD of the closure.
  summary=""
  vendor_freshness_audit_fods "$fods" "$reported"
  pin_after=$(vendor_freshness_tree_pin)
  if vendor_freshness_tree_changed "$pin_before" "$pin_after"; then
    leg_failed=1
    "$VENDOR_FRESHNESS_FAIL" "eval-relevant tree MUTATED during §11 ($(vendor_freshness_tree_stamp "$pin_before") → $(vendor_freshness_tree_stamp "$pin_after")) — the FOD verdict is void for the new tree; re-run §11"
  fi
  audit_summary_re='^proven=([0-9]+) receipted=([0-9]+) verified=([0-9]+) failed=([0-9]+)$'
  if [[ $VENDOR_FRESHNESS_AUDIT_SUMMARY =~ $audit_summary_re ]]; then
    audit_proven=${BASH_REMATCH[1]}
    audit_receipted=${BASH_REMATCH[2]}
    audit_verified=${BASH_REMATCH[3]}
    audit_failed=${BASH_REMATCH[4]}
    audit_total=$((audit_proven + audit_receipted + audit_verified + audit_failed))
    if [ "$audit_total" -gt 0 ]; then
      summary="$((audit_proven + audit_receipted + audit_verified)) go-modules FOD(s) of the closure verified ($audit_proven by deriver identity, $audit_verified re-verified by check-mode rebuild, $audit_receipted by prior receipt)"
    fi
  else
    audit_failed=1
    "$VENDOR_FRESHNESS_FAIL" "FOD audit returned an unreadable summary ('$VENDOR_FRESHNESS_AUDIT_SUMMARY') — refusing to deploy blind [tree $stamp]"
  fi
  [ "$audit_failed" -eq 0 ] || leg_failed=1

  if [ "$leg_failed" -ne 0 ]; then
    return 0
  fi
  desc=""
  if [ "$fod_count" -gt 0 ]; then
    desc="$fod_count go-modules FOD(s) realised (built or fetched now, output paths valid) + "
  fi
  if [ -n "$summary" ]; then
    desc="$desc$summary"
  else
    desc="no go-modules FOD in the build"
  fi
  "$VENDOR_FRESHNESS_PASS" "vendorHash valid — $desc [tree $stamp$noise_note]"
  return 0
}
