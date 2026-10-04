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
#
# The sourcer MUST define before calling vendor_freshness_run_gate:
#   VENDOR_FRESHNESS_PASS / VENDOR_FRESHNESS_WARN / VENDOR_FRESHNESS_FAIL
#   — reporting callbacks (offsite-borg-smoke OB_PASS pattern; stubs in
#   tests). The gate runs under the caller's `set -euo pipefail`, so every
#   fallible command is ||-guarded internally.

# Print the go-modules FOD .drv paths a dry-run preview says would be built.
# Anchor on the .drv suffix: "will be copied" sections list store OUTPUTS
# (no .drv), and a copied FOD output is proof of a valid hash, not a risk.
vendor_freshness_extract_fods() {
  local output="$1"
  printf '%s\n' "$output" | grep -E -- '-go-modules\.drv$' || true
}

# True (exit 0) when the dry-run itself failed to eval — the section then
# degrades to a WARN instead of a phantom-green pass.
vendor_freshness_dryrun_errored() {
  printf '%s\n' "$1" | grep -q '^error:'
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

# The §11 gate flow: preview the deploy build, real-build any uncached
# go-modules FODs, and report pass/warn/fail through the callbacks.
vendor_freshness_run_gate() {
  local dryrun_out fods fod_count build_log build_exit build_output got_hash
  dryrun_out=$(nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --dry-run 2>&1 || true)
  if vendor_freshness_dryrun_errored "$dryrun_out"; then
    "$VENDOR_FRESHNESS_WARN" "toplevel --dry-run eval failed — vendorHash preview degraded (§1 flake check owns the eval error)"
    return 0
  fi
  fods=$(vendor_freshness_extract_fods "$dryrun_out")
  if [ -z "$fods" ]; then
    "$VENDOR_FRESHNESS_PASS" "all deploy go-modules FODs cached — vendorHash proven by prior builds"
    return 0
  fi
  fod_count=$(printf '%s\n' "$fods" | wc -l)
  build_log=$(mktemp)
  build_exit=0
  # shellcheck disable=SC2086  # drv paths are whitespace-free store paths
  nix build $fods --keep-going >"$build_log" 2>&1 || build_exit=$?
  if [ "$build_exit" -eq 0 ]; then
    "$VENDOR_FRESHNESS_PASS" "$fod_count uncached go-modules FOD(s) built clean — vendorHash valid, cache warm for the deploy build"
  else
    build_output=$(cat "$build_log")
    case "$(vendor_freshness_classify_build "$build_output" "$build_exit")" in
    mismatch)
      got_hash=$(vendor_freshness_parse_got_hash "$build_output")
      "$VENDOR_FRESHNESS_FAIL" "vendorHash STALE — FOD hash mismatch (the deploy build would die here): ${got_hash:-got-hash unparsed, full error follows}; fix via \`buildflow -s nix-hash-fix --fix\`, never paste by hand"
      if [ -z "$got_hash" ]; then
        printf '%s\n' "$build_output" | tail -n 5 | sed 's/^/      /'
      fi
      ;;
    *)
      "$VENDOR_FRESHNESS_FAIL" "go-modules FOD build FAILED (non-hash error) — the deploy build would fail the same way; last lines:"
      printf '%s\n' "$build_output" | tail -n 5 | sed 's/^/      /'
      ;;
    esac
  fi
  rm -f "$build_log"
}
