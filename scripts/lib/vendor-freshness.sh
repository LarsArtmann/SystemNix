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
# commit (deploy.sh line ~435). Any *-go-modules.drv listed there is an
# uncached FOD the deploy build will attempt; a stale vendorHash fails
# exactly there — after ~12 minutes of unrelated building. The gate builds
# those FODs now: clean = vendorHash proven + cache warm; mismatch = the
# August-2026 deploy-killer caught in seconds with the got-hash in hand.
# Cached FODs never appear in the preview — prior success is the proof.
#
# Captured output shapes (verbatim, see test fixtures):
#   uncached dry-run: "these N derivations will be built:" then
#     "  /nix/store/<hash>-<pkg>-<rev>-go-modules.drv" lines
#   cached dry-run:   nix notices only, no .drv lines
#   FOD mismatch:     "error: hash mismatch in fixed-output derivation" +
#     "         specified: sha256-…" + "            got:    sha256-…"
#   FOD clean build:  exit 0
#   dry-run eval fail: "error:" headline, the message on the indented lines
#
# Verdict binding (2026-10-09/10 class): the preview and the FOD builds
# evaluate ONE exact tree. A shared multi-agent tree can mutate mid-gate
# (the 2026-10-09 22:31 "10 built clean" pass was voided by a mid-gate
# mutation; the deploy 5 min later died on an 11th FOD the preview never
# saw), and a stale pass is unauditable after the fact. run_gate therefore
# pins the eval-relevant tree state before its nix work, re-checks it
# before EVERY verdict, FAILs loud on change, and stamps each message
# with the short rev (+* when dirty) the verdict was computed against.
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
#   fallible command is ||-guarded internally.

# Print the go-modules FOD .drv paths a dry-run preview says would be built.
# Anchor on the .drv suffix: "will be copied" sections list store OUTPUTS
# (no .drv), and a copied FOD output is proof of a valid hash, not a risk.
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

# True when a dry-run output carries its plan ("these N derivations will be
# built", "these N paths will be fetched"): positive evidence the preview
# completed. A fully-cached preview prints nix notices only.
vendor_freshness_dryrun_has_plan() {
  printf '%s\n' "$1" | grep -Eq 'will be (built|fetched|copied|substituted)'
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

# The §11 gate flow: preview the deploy build, real-build any uncached
# go-modules FODs, and report pass/fail through the callbacks.
vendor_freshness_run_gate() {
  local dryrun_out dryrun_rc fods fod_count build_log build_exit build_output got_hash moved
  local pin_before pin_after stamp noise_note
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
  fods=$(vendor_freshness_extract_fods "$dryrun_out")
  if [ -z "$fods" ]; then
    pin_after=$(vendor_freshness_tree_pin)
    if vendor_freshness_tree_changed "$pin_before" "$pin_after"; then
      "$VENDOR_FRESHNESS_FAIL" "eval-relevant tree MUTATED during §11 ($(vendor_freshness_tree_stamp "$pin_before") → $(vendor_freshness_tree_stamp "$pin_after")) — 'all cached' is void for the new tree; re-run §11"
      return 0
    fi
    "$VENDOR_FRESHNESS_PASS" "all deploy go-modules FODs cached — vendorHash proven by prior builds [tree $stamp$noise_note]"
    return 0
  fi
  fod_count=$(printf '%s\n' "$fods" | wc -l)
  build_log=$(mktemp)
  build_exit=0
  # shellcheck disable=SC2086  # drv paths are whitespace-free store paths
  nix build $fods --keep-going >"$build_log" 2>&1 || build_exit=$?
  pin_after=$(vendor_freshness_tree_pin)
  if vendor_freshness_tree_changed "$pin_before" "$pin_after"; then
    "$VENDOR_FRESHNESS_FAIL" "eval-relevant tree MUTATED during §11 ($(vendor_freshness_tree_stamp "$pin_before") → $(vendor_freshness_tree_stamp "$pin_after")) — the FOD verdict is void for the new tree; re-run §11"
    rm -f "$build_log"
    return 0
  fi
  if [ "$build_exit" -eq 0 ]; then
    "$VENDOR_FRESHNESS_PASS" "$fod_count uncached go-modules FOD(s) built clean — vendorHash valid, cache warm for the deploy build [tree $stamp$noise_note]"
  else
    build_output=$(cat "$build_log")
    case "$(vendor_freshness_classify_build "$build_output" "$build_exit")" in
    mismatch)
      got_hash=$(vendor_freshness_parse_got_hash "$build_output")
      "$VENDOR_FRESHNESS_FAIL" "vendorHash STALE — FOD hash mismatch (the deploy build would die here): ${got_hash:-got-hash unparsed, full error follows}; fix via \`buildflow -s nix-hash-fix --fix\`, never paste by hand [tree $stamp]"
      if [ -z "$got_hash" ]; then
        printf '%s\n' "$build_output" | tail -n 5 | sed 's/^/      /'
      fi
      ;;
    *)
      "$VENDOR_FRESHNESS_FAIL" "go-modules FOD build FAILED (non-hash error) — the deploy build would fail the same way; last lines: [tree $stamp]"
      printf '%s\n' "$build_output" | tail -n 5 | sed 's/^/      /'
      ;;
    esac
  fi
  rm -f "$build_log"
}
