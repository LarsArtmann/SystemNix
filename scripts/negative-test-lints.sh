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

  apply_mutations "$dir" "$@" || {
    failed=$((failed + 1))
    return 0
  }

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

# apply_mutations <dir> <mutation...> — shared by run_case (check builds) and
# eval_case (NixOS assertion audits). Returns 1 on harness bugs (bad target,
# invalid sed, unknown form) so the caller counts one failed case.
apply_mutations() {
  local dir="$1"
  shift
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
      local premut
      premut=$(mktemp)
      # A silent sed failure (missing file) OR a no-op sed (expr matched
      # nothing — exit 0!) leaves the copy UNMUTATED and the case reports
      # the lint phantom-green (the gatus anchor-decay class, 2026-09-15).
      # Detect BOTH: sed errors loudly, and a byte-identical file after a
      # substitution expr means nothing matched.
      if ! cp -- "$dir/$f" "$premut" 2>/dev/null; then
        say "HARNESS BUG: sed target missing: $f"
        rm -f "$premut"
        return 1
      fi
      if ! sed -i "$expr" "$dir/$f" 2>/dev/null; then
        say "HARNESS BUG: sed mutation failed (expr invalid): $expr on $f"
        rm -f "$premut"
        return 1
      fi
      if cmp -s -- "$premut" "$dir/$f"; then
        say "HARNESS BUG: sed mutation was a NO-OP (expr matched nothing): $expr on $f"
        rm -f "$premut"
        return 1
      fi
      rm -f "$premut"
      ;;
    *)
      say "HARNESS BUG: unknown mutation [$mut]"
      return 1
      ;;
    esac
  done
}

# eval_toplevel <dir> — the enforcement surface of the NixOS ASSERTION
# audits (they have no check derivation): the evo-x2 toplevel eval, which
# `nix flake check` forces via its nixosConfigurations evaluation. stdout +
# stderr — the assertion throw text is what the marker greps.
eval_toplevel() {
  local dir="$1"
  nix eval --impure --raw --expr "(builtins.getFlake \"path:$dir\").nixosConfigurations.\"evo-x2\".config.system.build.toplevel" 2>&1
}

# eval_case <group> <name> <expect: fail|pass> <marker> <mutation...> —
# same contract as run_case, but against the toplevel eval instead of a
# check build. ~2min/case (full NixOS eval) — filter groups with CASES=.
eval_case() {
  local group="$1" name="$2" expect="$3" marker="$4"
  shift 4

  if [ -n "$FILTER" ] && [[ ",$FILTER," != *",$group,"* ]]; then
    return 0
  fi

  local dir
  dir=$(make_copy "$group-$name")
  apply_mutations "$dir" "$@" || {
    failed=$((failed + 1))
    return 0
  }

  local out status=0
  out=$(eval_toplevel "$dir") || status=$?

  case "$expect" in
  fail)
    if [ "$status" -eq 0 ]; then
      say "FAIL [$group/$name]: mutation PASSED the toplevel eval — audit did not fire (marker: $marker)"
      failed=$((failed + 1))
    elif ! grep -qE "$marker" <<<"$out"; then
      say "FAIL [$group/$name]: eval failed but marker '$marker' absent — caught by EVAL accident, not the audit:"
      grep -m3 'error:' <<<"$out" | sed 's/^/    /'
      failed=$((failed + 1))
    else
      say "PASS [$group/$name]: toplevel eval threw the audit marker"
      passed=$((passed + 1))
    fi
    ;;
  pass)
    if [ "$status" -eq 0 ]; then
      say "PASS [$group/$name]: toplevel eval correctly stayed green"
      passed=$((passed + 1))
    else
      say "FAIL [$group/$name]: toplevel eval should have stayed green but threw:"
      grep -m3 -E 'error:' <<<"$out" | sed 's/^/    /'
      failed=$((failed + 1))
    fi
    ;;
  esac
}

SIGNALERTS="modules/nixos/services/_signoz-alerts.nix"

# ── green controls: pristine copy, every touched check must build ──
if [ -z "$FILTER" ] || [[ ",$FILTER," == *,controls,* ]]; then
  for check in signoz-query-lint gatus-pattern-lint module-shape-lint binary-coverage-lint dead-guard-lint gitleaks-coverage-selftest scrub-exit-contract bridge-exit-contract; do
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

# Eval control for the assertion audits: their enforcement surface IS the
# toplevel eval, so the pristine copy must eval green. Also pulled in by
# CASES=memory so the audit's group never runs without its control.
if [ -z "$FILTER" ] || [[ ",$FILTER," == *,controls,* ]] || [[ ",$FILTER," == *,memory,* ]]; then
  dir=$(make_copy "pristine-toplevel-eval")
  out=$(eval_toplevel "$dir") || status=$? || true
  status=${status:-0}
  if [ "$status" -eq 0 ]; then
    say "PASS [controls]: evo-x2 toplevel eval green on pristine copy"
    passed=$((passed + 1))
  else
    say "FAIL [controls]: evo-x2 toplevel eval fails on the pristine copy — fix the tree first:"
    grep -m3 -E 'error:' <<<"$out" | sed 's/^/    /'
    failed=$((failed + 1))
  fi
  unset status
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
# Dashboard layout overlap (2026-09-16 incident shape): a panel moved onto an
# occupied grid cell must fail the lint the same way the SigNoz v2 validator
# 400s the provisioner. The mutation shifts a row-y so its rectangles collide.
run_case signoz dashboard-overlap signoz-query-lint fail 'dashboard layout overlap' \
  'sed:modules/nixos/services/dashboards/overview.json:s/"y": 24,/"y": 19,/'

# ── gatus-pattern-lint: the 4 trap classes ──
# gatus-config.nix is an auto-discovered flake-parts wrapper and IS parsed
# during checks eval (VM-test module merging) — mutations must stay valid
# nix. Each replaces a `let`-body binding line with an equivalent let
# binding carrying the trap. Anchor note: the 2026-09-15 registry migration
# rewrote gatus-config.nix and SILENTLY no-op'd the old sed anchor (the
# harness reported the lint phantom-green); the nodePort let-binding is the
# current stable anchor — refresh it if this failure class reappears.
# (Anchor rules learned 2026-09-15: it MUST be a comment INSIDE the let body
# — a definition line breaks downstream references (undefined variable), a
# header comment sits outside the attrset (syntax error).)
run_case gatus regex-chars gatus-pattern-lint fail 'regex-only chars' \
  'sed:modules/nixos/services/gatus-config.nix:s|# Smart alerting: append a PapDashboard ingest alert .type .custom.. to|evilPattern = "pat(*metric_z?)";|'
run_case gatus phantom-one gatus-pattern-lint fail 'bare pat\(\*<metric> 1\*\)' \
  'sed:modules/nixos/services/gatus-config.nix:s|# Smart alerting: append a PapDashboard ingest alert .type .custom.. to|evilPattern = "pat(*metric_z 1*)";|'
run_case gatus literal-backslash-n gatus-pattern-lint fail 'literal backslash-n' \
  'sed:modules/nixos/services/gatus-config.nix:s|# Smart alerting: append a PapDashboard ingest alert .type .custom.. to|evilPattern = "pat(*m \\\\n*)";|'
# NB (backslash accounting, the trap IS the test): the sed replacement above
# carries FOUR backslashes -> sed emits TWO into the file -> double-quoted
# nix evals them to ONE literal backslash + n = the broken runtime shape the
# trap must catch. A single file backslash would be the CORRECT form.
run_case gatus lowercase-method gatus-pattern-lint fail 'lowercase HTTP method' \
  'sed:modules/nixos/services/gatus-config.nix:s|# Smart alerting: append a PapDashboard ingest alert .type .custom.. to|evilMethod.method = "post";|'

# ── scrub-exit-contract: the freeze-7 fix must resist drift ──
# Eval-guard class (offsite-borg-positive-render shape): the guard fires as
# a throwIfNot eval error, so the FAIL marker IS the guard's own message.
run_case scrub exit-widened scrub-exit-contract fail 'SuccessExitStatus != \[ 1 \]' \
  'sed:platforms/nixos/system/snapshots.nix:s|SuccessExitStatus = \[ 1 \];|SuccessExitStatus = [ 1 3 ];|'
run_case scrub catchup-restored scrub-exit-contract fail 'Persistent must be false' \
  'sed:platforms/nixos/system/snapshots.nix:s|Persistent = lib.mkForce false;|Persistent = lib.mkForce true;|'

# ── bridge-exit-contract: the 2026-10-07 deploy-exit-4 fix must resist drift ──
# Eval-guard class (scrub-exit-contract shape): the guard fires as a throwIfNot
# eval error, so the FAIL marker IS the guard's own message. fastflowlm@ is
# enumerated in the check; llama-vlm-<name>@ is DERIVED from the module's
# servers attrset — one widening mutation per leg proves both paths.
run_case bridge fastflowlm-widened bridge-exit-contract fail 'SuccessExitStatus != \[ 143 \]' \
  'sed:modules/nixos/services/fastflowlm.nix:s|SuccessExitStatus = \[ 143 \];|SuccessExitStatus = [ 143 1 ];|'
run_case bridge vlm-widened bridge-exit-contract fail 'SuccessExitStatus != \[ 143 \]' \
  'sed:modules/nixos/services/llama-vlm.nix:s|SuccessExitStatus = \[ 143 \];|SuccessExitStatus = [ 143 1 ];|'
# Absent-list variant (2026-10-08): the queue contract said "widened OR absent
# must fail" — deleting the line leaves valid nix (empty line inside the
# attrset) so the eval GUARD fires, not a syntax accident; the merged default
# ([ ]) != [ 143 ] produces the same marker as the widened case.
run_case bridge fastflowlm-absent bridge-exit-contract fail 'SuccessExitStatus != \[ 143 \]' \
  'sed:modules/nixos/services/fastflowlm.nix:s|SuccessExitStatus = \[ 143 \];||'

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

# ── gitleaks-coverage-selftest: the coverage claims are live invariants ──
# The selftest scans tests/fixtures/gitleaks/ against the real repo config.
# Mutations must produce shapes NO default rule catches (generic-api-key
# masks single-rule drift on high-entropy values — proven by the first
# harness run), so drift mutations also collapse entropy; the corrupt
# mutation swaps in a genuinely detectable token shape.
# Fixture mutations operate on the @HEX40@ TEMPLATE form (2026-09-15: the
# literal token shapes moved to templates — GitHub push protection
# pattern-matches raw blobs and ignores gitleaks allowlists, so no
# rule-matching literal may be tracked; scripts/audit-push-protection-literals.sh
# rejects them). Mutations run BEFORE the check's template expansion.
run_case gitleaks square-fixture-drift gitleaks-coverage-selftest fail 'did NOT detect' \
  'sed:tests/fixtures/gitleaks/positive-square.txt:s|sq0atp-@HEX40@|sq0atpX-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|'
run_case gitleaks sourcegraph-fixture-drift gitleaks-coverage-selftest fail 'did NOT detect' \
  'sed:tests/fixtures/gitleaks/positive-sourcegraph.txt:s|sgp_@HEX40@|sgpX_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|'
run_case gitleaks negative-fixture-corrupt gitleaks-coverage-selftest fail 'tripped gitleaks' \
  'sed:tests/fixtures/gitleaks/negative-bare-hex.txt:s|@HEX40@|sq0atp-@HEX40@|'

# ── dead-guard-lint: capture-then-guard under errexit ──
# The evil shape is a capture without `|| true` followed by a -z guard — the
# exact website-deploy-monitor bug. The exempt twin carries `# dead-guard-ok`
# and must stay green. _-prefixed file: skipped by module auto-discovery, so
# only the lint sees it (eval is unaffected).
run_case deadguard evil-capture-guard dead-guard-lint fail 'DEAD GUARD' \
  'append:modules/nixos/services/_evil-dead-guard.nix:x=$(curl --silent http://x.example)' \
  'append:modules/nixos/services/_evil-dead-guard.nix:if [ -z "$x" ]; then exit 0; fi'
run_case deadguard exempt-capture-guard dead-guard-lint pass 'never-match-marker' \
  'append:modules/nixos/services/_evil-dead-guard.nix:x=$(curl --silent http://x.example) # dead-guard-ok' \
  'append:modules/nixos/services/_evil-dead-guard.nix:if [ -z "$x" ]; then exit 0; fi'

# ── memory-watermark-audit: the llama-chat 410M throttle trap ──
# Assertion audit, no check derivation — enforced through the toplevel eval.
# The mutation recreates the 2026-10-08 shape in FINAL-config terms: an
# explicit sub-watermark riding an outside ceiling. The audit reads the
# merged unit (not the call site), so ANY author-divergence shape must fire.
eval_case memory llama-chat-trap fail 'memory-watermark-audit' \
  'sed:modules/nixos/services/llama-chat.nix:s|(harden { MemoryMax = cfg.memoryMax; })|{ MemoryMax = cfg.memoryMax; MemoryHigh = "4G"; }|'

# HM scope of the same audit: it also reads
# config.home-manager.users.*.systemd.user.services (Service accessor).
# Inject an incoherent pair into the REAL HM config; the toplevel eval
# must throw with the same marker — proves the HM leg actually fires
# (zero live HM memory knobs, so a mutation is the only way to exercise it).
eval_case memory hm-user-trap fail 'memory-watermark-audit' \
  'sed:platforms/nixos/users/home.nix:s|systemd.user.services.go-cqrs-nightly-bench = {|systemd.user.services.go-cqrs-nightly-bench.Service = { MemoryMax = "1G"; MemoryHigh = "1M"; }; systemd.user.services.go-cqrs-nightly-bench = {|'

say ""
say "=== negative-test-lints: $passed passed, $failed failed ==="
[ "$failed" -eq 0 ]
