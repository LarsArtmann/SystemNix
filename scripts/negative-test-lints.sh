#!/usr/bin/env bash
# negative-test-lints.sh — nix-native negative tests for the trap-lint checks.
#
# Never trust an exit-0 check you wrote without proving it FAILS on the
# historical bug shape (binary-coverage-selftest in flake.nix is the in-tree
# precedent; this script generalizes it to the grep-over-source lints whose
# fixtures cannot live in-tree because the checks point at REAL files).
#
# Method (the round-2 harness of 2026-08-27, persisted):
#   1. Copy the git-tracked file set (working-tree contents) into a temp dir
#      WITHOUT .git — a plain-directory flake sees ALL files, no
#      tracked-files filtering, so mutations always take effect.
#   2. Apply ONE text mutation (append / sed) per case.
#   3. `nix build --impure` the check derivation FROM THE COPY and assert:
#        expect=fail  → build fails AND the log contains the lint's FAIL
#                       marker (an eval error does NOT count — that would be
#                       the mutation caught by accident, not by the lint)
#        expect=pass  → build succeeds (comment-immunity controls)
#
# Scope per run: green control on the pristine copy for every check touched,
# then every mutation. Runtime is eval-bound (~15-60s per case, warm cache).
#
# Usage:
#   bash scripts/negative-test-lints.sh            # all cases
#   CASES=gatus bash scripts/negative-test-lints.sh   # filter by case group
#   KEEP=1   bash scripts/negative-test-lints.sh    # keep workdir on exit
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM="$(uname -m)-linux"
WORK="$(mktemp -d /tmp/negative-test-lints.XXXXXX)"
[ "${KEEP:-0}" = "1" ] || trap 'rm -rf "$WORK"' EXIT

FILTER="${CASES:-}"

passed=0
failed=0

say() { printf '%s\n' "$*"; }

# make_copy <name> — git-tracked set with working-tree contents, no .git.
make_copy() {
  local dir="$WORK/$1"
  mkdir -p "$dir"
  (cd "$REPO_ROOT" && git ls-files -z | rsync -a --files-from=- --from0 . "$dir/")
  printf '%s' "$dir"
}

# build_check <dir> <check> — builds <dir>'s check; logs to stdout+stderr.
build_check() {
  local dir="$1" check="$2"
  nix build --impure -L --no-link --print-out-paths \
    --expr "(builtins.getFlake \"path:$dir\").checks.$SYSTEM.$check" 2>&1
}

# run_case <group> <name> <check> <expect: fail|pass> <marker-regex> <mutation...>
# Mutation words: append:<file>:<line> | sed:<file>:<expr>
run_case() {
  local group="$1" name="$2" check="$3" expect="$4" marker="$5"
  shift 5

  if [ -n "$FILTER" ] && [[ ",$FILTER," != *",$group,"* ]]; then
    return 0
  fi

  local dir
  dir=$(make_copy "$group-$name")

  local mut
  for mut in "$@"; do
    case "$mut" in
    append:*)
      local f="${mut#append:}"
      f="${dir}/${f%%:*}"
      local line="${mut#append:*:}"
      printf '%s\n' "$line" >>"$f"
      ;;
    sed:*)
      local rest="${mut#sed:}"
      local f="${rest%%:*}"
      local expr="${rest#*:}"
      sed -i "$expr" "$dir/$f"
      ;;
    *)
      say "HARNESS BUG: unknown mutation [$mut]"
      failed=$((failed + 1))
      return 0
      ;;
    esac
  done

  local out status=0
  out=$(build_check "$dir" "$check") || status=$?

  case "$expect" in
  fail)
    if [ "$status" -eq 0 ]; then
      say "FAIL [$group/$name]: mutation PASSED the $check build — phantom-green lint (marker: $marker)"
      failed=$((failed + 1))
    elif ! grep -qE "$marker" <<<"$out"; then
      say "FAIL [$group/$name]: build failed but marker '$marker' absent — caught by EVAL accident, not the lint:"
      grep -m3 'error:' <<<"$out" | sed 's/^/    /'
      failed=$((failed + 1))
    else
      say "PASS [$group/$name]: $check failed with the expected marker"
      passed=$((passed + 1))
    fi
    ;;
  pass)
    if [ "$status" -eq 0 ]; then
      say "PASS [$group/$name]: $check correctly stayed green"
      passed=$((passed + 1))
    else
      say "FAIL [$group/$name]: $check should have stayed green but failed:"
      grep -m3 -E 'error:|FAIL' <<<"$out" | sed 's/^/    /'
      failed=$((failed + 1))
    fi
    ;;
  esac
}

SIGNALERTS="modules/nixos/services/_signoz-alerts.nix"

# ── green controls: pristine copy, every touched check must build ──
if [ -z "$FILTER" ] || [[ ",$FILTER," == *,controls,* ]]; then
  for check in signoz-query-lint gatus-pattern-lint module-shape-lint binary-coverage-lint; do
    dir=$(make_copy "pristine-$check")
    out=$(build_check "$dir" "$check") || status=$? || true
    status=${status:-0}
    if [ "$status" -eq 0 ]; then
      say "PASS [controls]: $check green on pristine copy"
      passed=$((passed + 1))
    else
      say "FAIL [controls]: $check does not build on the pristine copy — fix the tree first:"
      grep -m3 -E 'error:|FAIL' <<<"$out" | sed 's/^/    /'
      failed=$((failed + 1))
    fi
    unset status
  done
fi

# ── signoz-query-lint: the 4 trap classes + comment immunity ──
run_case signoz job-matcher signoz-query-lint fail 'job= label matcher' \
  "append:$SIGNALERTS:EVIL_MUTATION job=\"gatus\""
run_case signoz histogram-underscore signoz-query-lint fail 'underscore histogram suffix' \
  "append:$SIGNALERTS:EVIL_MUTATION dnsblockd_dns_resolve_duration_ms_sum"
run_case signoz bare-up-selector signoz-query-lint fail 'bare up\{service_name=\.\.\.\} selector' \
  "append:$SIGNALERTS:EVIL_MUTATION up{service_name=\"dnsblockd\"} < 1"
run_case signoz dead-metric signoz-query-lint fail "dead metric '" \
  "append:$SIGNALERTS:EVIL_MUTATION node_amdgpu_gpu_temp_celsius"
run_case signoz comment-ignored signoz-query-lint pass '' \
  "append:$SIGNALERTS:# EVIL_MUTATION job=\"gatus\" (commented — must be ignored)"

# ── gatus-pattern-lint: the 4 trap classes ──
# gatus-config.nix is an auto-discovered flake-parts wrapper and IS parsed
# during checks eval (VM-test module merging) — mutations must stay valid
# nix. Each replaces a `let`-body comment line with an equivalent let
# binding carrying the trap (unique anchor: the YAML-field NOTE).
run_case gatus regex-chars gatus-pattern-lint fail 'regex-only chars' \
  'sed:modules/nixos/services/gatus-config.nix:s|# NOTE: the YAML field is .*|evilPattern = "pat(*metric_z?)";|'
run_case gatus phantom-one gatus-pattern-lint fail 'bare pat\(\*<metric> 1\*\)' \
  'sed:modules/nixos/services/gatus-config.nix:s|# NOTE: the YAML field is .*|evilPattern = "pat(*metric_z 1*)";|'
run_case gatus literal-backslash-n gatus-pattern-lint fail 'literal backslash-n' \
  'sed:modules/nixos/services/gatus-config.nix:s|# NOTE: the YAML field is .*|evilPattern = "pat(*m \\\\n*)";|'
# NB (backslash accounting, the trap IS the test): the sed replacement above
# carries FOUR backslashes -> sed emits TWO into the file -> double-quoted
# nix evals them to ONE literal backslash + n = the broken runtime shape the
# trap must catch. A single file backslash would be the CORRECT form.
run_case gatus lowercase-method gatus-pattern-lint fail 'lowercase HTTP method' \
  'sed:modules/nixos/services/gatus-config.nix:s|# NOTE: the YAML field is .*|evilMethod.method = "post";|'

# ── module-shape-lint: wrapper renamed away from the filename ──
# (A bare module ALSO breaks flake eval with a worse message — renaming the
# wrapper key keeps eval valid so the LINT is what fires.)
run_case shape renamed-wrapper module-shape-lint fail 'does not declare flake\.nixosModules' \
  'sed:modules/nixos/services/caddy.nix:s|flake\.nixosModules\.caddy|flake.nixosModules.caddy-mutant|'

# ── binary-coverage-lint: awk usage without a provider ──
# (_-prefixed = skipped by module auto-discovery, so eval never sees it; the
# scanner walks modules/ regardless — exactly the gap this lint guards.)
run_case coverage awk-without-gawk binary-coverage-lint fail "execs 'awk'" \
  "append:modules/nixos/services/_evil-coverage-fixture.nix:{ config, ... }: { systemd.services.evil.serviceConfig.ExecStart = \"/bin/sh -c 'df | awk NR==1'\"; }"

say ""
say "=== negative-test-lints: $passed passed, $failed failed ==="
[ "$failed" -eq 0 ]
