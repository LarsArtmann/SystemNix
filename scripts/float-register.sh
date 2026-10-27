#!/usr/bin/env bash
# Auto-register floated flake inputs: the lock-float gate's ceremony in one
# command, so `nix flake update && nix run .#deploy` just works.
#
# The gate (lib/lock-float-audit.nix) throws on ANY eval while flake.lock
# carries revs the registry (flake/expected-locks.nix) does not know — which
# made every blanket `nix flake update` require a manual three-step ceremony
# (regenerate → prove → commit together) before ANY eval/deploy could run.
# In a tree with continuous parallel updates that ceremony fired several
# times per hour (2026-10-25 float marathon, owner: "I hate this fake update
# locking"). This script IS that ceremony:
#
#   1. drift check (registry vs lock) — no drift → instant exit 0
#   2. regenerate the registry body from flake.lock (header rederive cmd)
#   3. prove: keep-going toplevel build, log to ~/.cache/lockfloat/
#   4a. green  → commit flake.lock + registry TOGETHER (audit-log message)
#   4b. red    → revert the registry rows (entry-snapshot rewrite, NOT
#                `git restore`, which no-ops after a daemon sweep), print
#                roots + unpushed-session hints, exit 1
#                (never commit an unproven float, never delete rows to green)
#
# Safety: the lock is fingerprinted (sha256) before the proof; if it moved
# during the build (another parallel `nix flake update`), abort loud instead
# of committing rows that were never proven.
#
# Run:            scripts/float-register.sh [--selftest]
# Deploy hook:    deploy.sh calls this automatically (FLOAT_REGISTER=0 opts out)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

LOCK="flake.lock"
REGISTRY="flake/expected-locks.nix"
LOGDIR="$HOME/.cache/lockfloat"
PROOF_ATTR="nixosConfigurations.evo-x2.config.system.build.toplevel"

mkdir -p "$LOGDIR"
stamp() { date +%Y%m%d-%H%M%S; }

regen_body() {
  {
    jq -r '.nodes.root.inputs|to_entries[]|select(.value|type=="string")|"\(.key)\t\(.value)"' < "$LOCK"
  } | while IFS=$'\t' read -r name nk; do
    rev=$(jq -r --arg nk "$nk" '.nodes[$nk].locked.rev? // empty' < "$LOCK")
    [ -n "$rev" ] && printf '  %s = "%s";\n' "$name" "$rev"
  done
}

registry_rows() {
  grep -E '^  [a-zA-Z0-9_.-]+ = "[0-9a-f]{40}";$' "$REGISTRY" || true
}

# For each drifted input with a sibling checkout under
# $FLOAT_REGISTER_CHECKOUT_ROOT (default ~/projects): if that checkout's HEAD
# is N commits AHEAD of the rev flake.lock just floated to, the float pulled
# the REMOTE tip while local unpushed work sits on top — the tree may
# reference options/features the locked rev cannot provide (2026-10-27
# monitor365 class: evo-x2 eval died on drain_filter/compaction options that
# existed only 16 unpushed commits ahead of the locked rev). Name the likely
# in-flight session instead of leaving a bare option error.
unpushed_hints() {
  local lock="$1" drifted="$2"
  local root="${FLOAT_REGISTER_CHECKOUT_ROOT:-$HOME/projects}"
  jq -r '.nodes.root.inputs|to_entries[]|select(.value|type=="string")|"\(.key)\t\(.value)"' < "$lock" \
    | while IFS=$'\t' read -r name nk; do
        case " $drifted " in
          *" $name "*) ;;
          *) continue ;;
        esac
        rev=$(jq -r --arg nk "$nk" '.nodes[$nk].locked.rev? // empty' < "$lock")
        [ -n "$rev" ] || continue
        dir="$root/$name"
        git -C "$dir" cat-file -e "${rev}^{commit}" 2>/dev/null || continue
        git -C "$dir" merge-base --is-ancestor "$rev" HEAD 2>/dev/null || continue
        n=$(git -C "$dir" rev-list --count "$rev..HEAD" 2>/dev/null) || continue
        [ "${n:-0}" -gt 0 ] 2>/dev/null || continue
        printf '  input %s: locked %s but %s is +%s commits ahead (unpushed local work — the locked rev cannot provide what the tree expects)\n' \
          "$name" "${rev:0:7}" "$dir" "$n"
      done
}

fr_selftest() {
  local scratch root base tip lock out failures=0
  scratch=$(mktemp -d)
  root="$scratch/projects"
  mkdir -p "$root/alpha" "$root/beta"
  git -C "$root/alpha" init -q -b master
  git -C "$root/alpha" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  base=$(git -C "$root/alpha" rev-parse HEAD)
  git -C "$root/alpha" -c user.name=t -c user.email=t@t commit -q --allow-empty -m wip
  tip=$(git -C "$root/alpha" rev-parse HEAD)
  lock="$scratch/lock.json"
  mklock() {
    printf '{"nodes":{"root":{"inputs":{"alpha":"n1"}},"n1":{"locked":{"rev":"%s"}}}}' "$1" > "$lock"
  }
  mklock "$base"
  out=$(FLOAT_REGISTER_CHECKOUT_ROOT="$root" unpushed_hints "$lock" "alpha")
  case "$out" in
    *"alpha: locked ${base:0:7} but"*"+1 commits ahead"*) echo "PASS: ahead checkout yields hint" ;;
    *) echo "FAIL: expected ahead-hint, got: $out"; failures=$((failures + 1)) ;;
  esac
  mklock "$tip"
  out=$(FLOAT_REGISTER_CHECKOUT_ROOT="$root" unpushed_hints "$lock" "alpha")
  if [ -z "$out" ]; then echo "PASS: tip-locked checkout silent"; else echo "FAIL: expected silence, got: $out"; failures=$((failures + 1)); fi
  printf '{"nodes":{"root":{"inputs":{"beta":"n1"}},"n1":{"locked":{"rev":"%s"}}}}' "$(printf '%040d' 0)" > "$lock"
  out=$(FLOAT_REGISTER_CHECKOUT_ROOT="$root" unpushed_hints "$lock" "beta" 2>/dev/null)
  if [ -z "$out" ]; then echo "PASS: non-git dir silent"; else echo "FAIL: expected silence, got: $out"; failures=$((failures + 1)); fi
  mklock "$base"
  out=$(FLOAT_REGISTER_CHECKOUT_ROOT="$root" unpushed_hints "$lock" "")
  if [ -z "$out" ]; then echo "PASS: undrifted input silent"; else echo "FAIL: expected silence, got: $out"; failures=$((failures + 1)); fi
  rm -rf "$scratch"
  if [ "$failures" -gt 0 ]; then
    printf '\n%d selftest assertion(s) failed\n' "$failures" >&2
    return 1
  fi
  printf '\nall selftest assertions passed\n'
}

case "${1:-}" in
  --selftest)
    fr_selftest
    exit $?
    ;;
  "") ;;
  *)
    printf 'usage: %s [--selftest]\n' "$0" >&2
    exit 2
    ;;
esac

# ── 1. drift check ────────────────────────────────────────────────────────
before=$(regen_body)
current=$(registry_rows)
if [ "$before" = "$current" ]; then
  echo "float-register: no drift — registry matches flake.lock"
  exit 0
fi

echo "float-register: drift detected —"
diff <(printf '%s\n' "$current") <(printf '%s\n' "$before") || true
# `|| true` is load-bearing under set -o pipefail: diff exits 1 on any
# difference, and an unguarded pipeline here killed the ceremony right
# after the drift print (regen + proof never ran; live 2026-10-27).
drifted=$(
  { diff <(printf '%s\n' "$current") <(printf '%s\n' "$before") || true; } \
    | { grep '^>' || true; } | sed -E 's/^> +([a-zA-Z0-9_.-]+) =.*/\1/' | tr '\n' ' ' | sed 's/ $//'
)
rows_before="$LOGDIR/reg-rows-before-$(stamp)"
printf '%s\n' "$current" > "$rows_before"

# ── 2. regenerate the registry (body only; header + braces preserved) ─────
hdr=$(grep -n -m1 '^{$' "$REGISTRY" | cut -d: -f1)
if [ -z "$hdr" ]; then
  echo "✗ cannot find the opening brace in $REGISTRY — refusing to touch it"
  exit 2
fi
{
  head -n "$hdr" "$REGISTRY"
  printf '%s\n' "$before"
  echo '}'
} > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"

# ── 3. prove (the gate passes now; the build is the proof) ────────────────
lock_sha_before=$(sha256sum "$LOCK" | cut -d' ' -f1)
proof_log="$LOGDIR/float-proof-$(stamp).log"
echo "float-register: proving ($PROOF_ATTR --keep-going; log: $proof_log)"
rc=0
nix build ".#$PROOF_ATTR" --keep-going --no-link > "$proof_log" 2>&1 || rc=$?
echo "rc=$rc" >> "$proof_log"

# ── 4. commit on green, revert on red ─────────────────────────────────────
if [ "$rc" != "0" ]; then
  # Revert by REWRITING the pre-ceremony rows, not `git restore`: restore
  # pulls from the index and silently no-ops when the auto-commit daemon
  # swept the regenerated (unproven) rows mid-proof (live 2026-10-27: daemon
  # commit bcaa65167 shipped unproven rows and the later restore changed
  # nothing, leaving the registry claiming a float that never proved).
  # Rewriting from the entry snapshot re-arms drift so the next deploy
  # re-runs the ceremony.
  hdr_now=$(grep -n -m1 '^{$' "$REGISTRY" | cut -d: -f1)
  if [ -n "$hdr_now" ]; then
    {
      head -n "$hdr_now" "$REGISTRY"
      cat "$rows_before"
      echo '}'
    } > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  else
    git restore -- "$REGISTRY"
  fi
  echo "✗ float-register: proof RED (rc=$rc) — registry rows REVERTED, nothing committed."
  echo "  Roots (fix upstream-first, or pin that input back):"
  grep -E 'error:|hash mismatch|got:|specified:|builder for .* failed' "$proof_log" | head -20
  hints=$(unpushed_hints "$LOCK" "$drifted")
  if [ -n "$hints" ]; then
    echo "  Unpushed local work among the drifted inputs (in-flight sibling sessions?):"
    printf '%s\n' "$hints"
  fi
  exit 1
fi

lock_sha_after=$(sha256sum "$LOCK" | cut -d' ' -f1)
if [ "$lock_sha_before" != "$lock_sha_after" ]; then
  git restore -- "$REGISTRY"
  echo "✗ float-register: flake.lock MOVED during the proof (parallel update) — registry rows reverted."
  echo "  Re-run this script against the settled lock; never commit rows that were not proven."
  exit 3
fi

msg_file=$(mktemp)
{
  echo "float: register ${drifted:-inputs} (auto-proof rc=0)"
  echo
  echo "flake.lock + expected-locks regenerated and proven together by"
  echo "scripts/float-register.sh (keep-going log: $proof_log)."
} > "$msg_file"
git add "$LOCK" "$REGISTRY"
if ! git commit -F "$msg_file" -- "$LOCK" "$REGISTRY"; then
  rm -f "$msg_file"
  # Daemon-race: the auto-commit daemon batches continuously and may have
  # swept the pair while the proof was running (live 2026-10-25: heuristic
  # commit landed mid-proof, our pathspec commit found nothing). Success
  # condition: the tree is clean AND the registry still matches the lock.
  now_body=$(regen_body)
  now_reg=$(grep -E '^  [a-zA-Z0-9_.-]+ = "[0-9a-f]{40}";$' "$REGISTRY" || true)
  if [ "$now_body" = "$now_reg" ] && git diff --quiet -- "$LOCK" "$REGISTRY"; then
    echo "✓ float-register: the auto-commit daemon landed the pair during the proof — content verified, nothing to do"
    exit 0
  fi
  echo "✗ float-register: commit failed AND content mismatch — inspect $LOCK/$REGISTRY manually"
  exit 4
fi
rm -f "$msg_file"
echo "✓ float-register: registered [${drifted:-}] and committed lock+registry together"
