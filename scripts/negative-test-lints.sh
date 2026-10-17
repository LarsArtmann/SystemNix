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
    jq:*)
      # JSON surgery for pretty-printed files (flake.lock): a sed on compact
      # key:value text silently no-ops there — the 2026-10-14 inputpin legs
      # premise-check caught exactly that. Same no-op detection as sed.
      local rest="${mut#jq:}"
      local f="${rest%%:*}"
      local filter="${rest#*:}"
      local premut
      premut=$(mktemp)
      if ! cp -- "$dir/$f" "$premut" 2>/dev/null; then
        say "HARNESS BUG: jq target missing: $f"
        rm -f "$premut"
        return 1
      fi
      if ! jq -e "$filter" "$dir/$f" >"$dir/$f.jqout" 2>/dev/null; then
        say "HARNESS BUG: jq mutation failed (filter invalid): $filter on $f"
        rm -f "$premut" "$dir/$f.jqout"
        return 1
      fi
      mv "$dir/$f.jqout" "$dir/$f"
      if cmp -s -- "$premut" "$dir/$f"; then
        say "HARNESS BUG: jq mutation was a NO-OP (filter matched nothing): $filter on $f"
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

# build_config_path <dir> <attr-path> — realize a config attribute whose
# value is a store path or a string with derivation context. The
# papdashboard icon BUILD gate's enforcement surface: PAP_ICONS_DIR carries
# the dashboardIcons derivation in its string context (the unit-env
# reference that makes the gate unskippable on a real deploy), so realizing
# it builds the pack copy and surfaces the missing-icon error.
build_config_path() {
  local dir="$1" attr="$2"
  nix build --impure -L --no-link --print-out-paths \
    --expr "(builtins.getFlake \"path:$dir\").nixosConfigurations.\"evo-x2\".$attr" 2>&1
}

# build_case <group> <name> <attr-path> <expect: fail|pass> <marker> <mutation...>
# Same contract as run_case/eval_case, but the enforcement surface is
# BUILDING a config attribute (a derivation whose failure IS the gate).
build_case() {
  local group="$1" name="$2" attr="$3" expect="$4" marker="$5"
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
  out=$(build_config_path "$dir" "$attr") || status=$?

  case "$expect" in
  fail)
    if [ "$status" -eq 0 ]; then
      say "FAIL [$group/$name]: mutation PASSED the $attr build — phantom-green gate (marker: $marker)"
      failed=$((failed + 1))
    elif ! grep -qE "$marker" <<<"$out"; then
      say "FAIL [$group/$name]: build failed but marker '$marker' absent — caught by EVAL accident, not the gate:"
      grep -m3 'error:' <<<"$out" | sed 's/^/    /'
      failed=$((failed + 1))
    else
      say "PASS [$group/$name]: $attr build failed with the expected marker"
      passed=$((passed + 1))
    fi
    ;;
  pass)
    if [ "$status" -eq 0 ]; then
      say "PASS [$group/$name]: $attr build correctly stayed green"
      passed=$((passed + 1))
    else
      say "FAIL [$group/$name]: $attr build should have stayed green but failed:"
      grep -m3 -E 'error:|FAIL' <<<"$out" | sed 's/^/    /'
      failed=$((failed + 1))
    fi
    ;;
  esac
}

# ── green controls: pristine copy, every touched check must build ──
if [ -z "$FILTER" ] || [[ ",$FILTER," == *,controls,* ]]; then
  for check in signoz-query-lint gatus-pattern-lint module-shape-lint binary-coverage-lint dead-guard-lint with-pkgs-lint gitleaks-coverage-selftest scrub-exit-contract bridge-exit-contract; do
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
# CASES=memory / CASES=inputpin so the audit's group never runs without
# its control.
if [ -z "$FILTER" ] || [[ ",$FILTER," == *,controls,* ]] || [[ ",$FILTER," == *,memory,* ]] || [[ ",$FILTER," == *,inputpin,* ]]; then
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

# Build control for build_case (same discipline as the eval control): the
# PAP_ICONS_DIR pack copy must build green on the pristine copy. Also pulled
# in by CASES=tileicons so the group never runs without its control.
if [ -z "$FILTER" ] || [[ ",$FILTER," == *,controls,* ]] || [[ ",$FILTER," == *,tileicons,* ]]; then
  dir=$(make_copy "pristine-pap-icons")
  out=$(build_config_path "$dir" "config.systemd.services.papdashboard.environment.PAP_ICONS_DIR") || status=$? || true
  status=${status:-0}
  if [ "$status" -eq 0 ]; then
    say "PASS [controls]: PAP_ICONS_DIR pack copy builds green on pristine copy"
    passed=$((passed + 1))
  else
    say "FAIL [controls]: PAP_ICONS_DIR does not build on the pristine copy — fix the tree first:"
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

# ── with-pkgs-lint: the shadow trap + exemption/comment immunity ──
# The 2026-10-14 sweep removed all module/platform sites; the mutation
# re-introduces the exact shape the convention bans. Anchored on a module
# comment line so the mutation stays valid nix (append puts it inside the
# wrapper attrset as a stray expression — use sed on a comment instead).
run_case withpkgs bare-with-pkgs with-pkgs-lint fail "explicit pkgs. prefixes required" \
  'sed:modules/nixos/services/monitor365.nix:s|# Wired into the systemd service PATH by the upstream module.|# Wired into the systemd service PATH by the upstream module.\n      evilInputs = with pkgs; [ curl ];|'
run_case withpkgs with-pkgs-lib with-pkgs-lint fail "explicit pkgs. prefixes required" \
  'sed:modules/nixos/services/monitor365.nix:s|# Wired into the systemd service PATH by the upstream module.|# Wired into the systemd service PATH by the upstream module.\n      evilMeta = with pkgs.lib; { x = 1; };|'
run_case withpkgs exempt-ok with-pkgs-lint pass '' \
  'sed:modules/nixos/services/monitor365.nix:s|# Wired into the systemd service PATH by the upstream module.|# Wired into the systemd service PATH by the upstream module.\n      evilExempt = with pkgs; [ curl ]; # with-pkgs-ok|'

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

# ── flake-input-pin-audit: hardcoded version pins in input URLs ──
# Eval guard in flake.nix allEvalGuards (no check derivation) — the
# toplevel eval IS the enforcement surface. Each mutation pins BOTH the
# declaration and the matching lock original: an original/declaration
# mismatch would force a re-resolution (network) and the resulting eval
# error would be an accident-catch, not the audit firing.
# Leg 1: incident shape of the 2026-10-14 rollback-pin class — a clean
# ?ref=master input flips to a 40-hex path rev.
eval_case inputpin sha-path-pin fail 'go-taskqueue: hard REV pin' \
  'sed:flake.nix:s|github:LarsArtmann/go-taskqueue?ref=master|github:LarsArtmann/go-taskqueue/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|' \
  'jq:flake.lock:.nodes["go-taskqueue"].original = {"owner":"LarsArtmann","repo":"go-taskqueue","rev":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","type":"github"}'
# Leg 2: the lift-forcing teeth — bank-sync's documented ceiling pin is
# lifted in BOTH surfaces while its allowlist row remains; the stale row
# must fail eval (never let the allowlist rot silently).
eval_case inputpin lifted-pin-stale-allowlist fail 'matches no live pin' \
  'sed:flake.nix:s|github:LarsArtmann/bank-sync/67dd64526e5a55d86ff40ab49ce4a07794922962|github:LarsArtmann/bank-sync?ref=refs/heads/master|' \
  'jq:flake.lock:.nodes["bank-sync"].original = {"owner":"LarsArtmann","ref":"refs/heads/master","repo":"bank-sync","type":"github"}'

# ── papdashboard tile-icon gates: the 2026-10-17 "logos went dark" class ──
# The module ships two gates; each leg mutates ONE tile icon in the
# built-in group defaults (the first group tile, pocket-id.png) and proves
# the matching gate fires.
# Gate 1 (FORM, eval assertion): a legacy homepage-era mdi-* name must
# throw the assertion that names the tile — the exact shape that survived
# the 2026-09-18 homepage merge unnoticed.
eval_case tileicons legacy-mdi-icon fail 'tile icon\(s\) must be a dashboard-icons pack file name' \
  'sed:modules/nixos/services/papdashboard.nix:s|"pocket-id.png"|"mdi-sitemap"|'
# Gate 2 (EXISTS, build gate): a FORM-VALID name the pack does not carry
# must pass the eval and fail the dashboardIcons copy — realized through
# PAP_ICONS_DIR's string context (the unit-env reference that makes the
# gate unskippable on a real deploy).
build_case tileicons pack-missing-icon 'config.systemd.services.papdashboard.environment.PAP_ICONS_DIR' fail "is not in the dashboard-icons pack" \
  'sed:modules/nixos/services/papdashboard.nix:s|"pocket-id.png"|"pocket-id-not-in-any-pack.png"|'

# ── pastebot-parity-audit: the clipboard/snippets picker surface ──
# Assertion audit (modules/nixos/desktop/pastebot-parity-audit.nix) — the
# enforcement surface is the toplevel eval. Three legs mirroring the real
# regression classes: bind KEY lost, bind REPINTED (key present, command
# drifted — subtler than absence), and plugin registration dropped.
# Leg 1: rename the snippets bind key — the picker entrypoint vanishes.
eval_case pastebot bind-key-lost fail 'pastebot-parity-audit: niri bind' \
  'sed:platforms/nixos/desktop/niri-wrapped.nix:s|"Mod+Shift+C".action.spawn = \[|"Mod+Shift+X".action.spawn = [|'
# Leg 2: keep the key, repoint the spawn at the calculator trigger —
# presence-only guards would pass; the audit pins the full command.
eval_case pastebot bind-repointed fail 'pastebot-parity-audit: niri bind' \
  'sed:platforms/nixos/desktop/niri-wrapped.nix:s|^            ":s"$|            "="|'
# Leg 3: disable the dms-paste module (the home module registers the
# plugin) — the ':s' trigger dies while the Mod+Shift+C bind still points
# at it; only the plugin assertion catches this shape.
eval_case pastebot plugin-dropped fail 'pastebot-parity-audit: the paste-snippets DMS launcher plugin' \
  'sed:platforms/nixos/desktop/quickshell.nix:s|programs.dms-paste.enable = true;|programs.dms-paste.enable = false;|'

# ── boot-mirror-path-trigger: the 2026-10-17 gen-922 stale-boot class ──
# The check (selftests.nix) pins the rendered path-unit trigger + the
# wants-not-requires posture. Each mutation recreates one regression shape
# and proves the matching leg fires. Mutations keep eval valid so the
# CHECK's guard fires (not an eval accident).
# Leg 1: the raw-stc bypass itself — the watcher pointed at a dead dir
# (any gen-install outside deploy.sh leaves the Samsung ESP stale).
run_case bootmirror watcher-dropped boot-mirror-path-trigger fail 'PathChanged must watch /boot/loader/entries' \
  'sed:platforms/nixos/system/boot-mirror.nix:s|"/boot/loader/entries"|"/boot/loader/entriez"|'
# Leg 2: the condition-skip posture — a trigger with an unmounted Samsung
# must condition-skip, never fail (this would boot-break nofail's promise).
run_case bootmirror condition-dropped boot-mirror-path-trigger fail 'must condition-skip, never fail' \
  'sed:platforms/nixos/system/boot-mirror.nix:s|ConditionPathIsMountPoint = mirrorPath;|ConditionPathIsMountPoint = "/boot";|'
# Leg 3: the nofail half of wants-not-requires — a detached Samsung must
# degrade, never block boot.
run_case bootmirror nofail-dropped boot-mirror-path-trigger fail 'must stay nofail' \
  'sed:platforms/nixos/system/boot-mirror.nix:s|"nofail"|"nofail-mutated"|'

say ""

# ── systemd-shape-audit class 7: unbounded boot-blocking oneshots ──
# The 2026-10-17 infinite-boot class (netbird-evox2-login held the boot
# transaction 55+ min). Mutation: rename a bounds-module list entry so a
# foreign-rendered unit (cpufreq) loses its floor — the audit must throw.
# The serviceOneshotDefaults mkDefault floor's own coverage is pinned by
# the ~25 helper-using units that would fire the same assertion if the
# lib default were dropped (any one of them suffices as the marker).
eval_case shapeaudit oneshot-unbounded fail 'boot-blocking Type=oneshot unit\(s\) with unbounded TimeoutStartSec' \
  'sed:modules/nixos/services/boot-oneshot-bounds.nix:s|      "cpufreq"|      "cpufreq-renamed"|'
# ── systemd-shape-audit class 8: OnFailure nested inside serviceConfig ──
# The visionreviewd no-op class (journal-proven "Unknown key 'OnFailure' in
# section [Service], ignoring" every boot, 2026-10-17). Mutation: push the
# landed unit-level onFailure back into serviceConfig — the audit must throw.
eval_case shapeaudit onfailure-in-serviceconfig fail 'OnFailure nested inside serviceConfig' \
  'sed:modules/nixos/services/visionreviewd.nix:s|systemd.services.visionreviewd.onFailure = onFailure;|systemd.services.visionreviewd.serviceConfig.OnFailure = onFailure;|'

# ── io-tier-coverage-audit: boot-gated units must carry an IO tier ──
# The llama-chat/compsize class (untiered bulk boot I/O on the QLC). Leg 1
# strips a landed tier from a boot-gated unit (boot-mirror-sync); leg 2
# removes an allowlist entry (gatus — steady daemon, justified exemption).
# Both must throw the audit marker; the legs also prove the audit module is
# imported by evo-x2 auto-discovery (an absent module would let both PASS).
eval_case iotier tier-stripped fail 'boot-gated unit\(s\) without an IO tier' \
  'sed:platforms/nixos/system/boot-mirror.nix:s|      (ioTier.background)|      # tier stripped for negative test|'
eval_case iotier allowlist-entry-removed fail 'boot-gated unit\(s\) without an IO tier' \
  'sed:modules/nixos/services/io-tier-coverage-audit.nix:s|            "gatus"|            # "gatus" removed for negative test|'
say "=== negative-test-lints: $passed passed, $failed failed ==="
[ "$failed" -eq 0 ]
