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
#   4b. red    → revert the registry rows, print roots, exit 1
#                (never commit an unproven float, never delete rows to green)
#
# Safety: the lock is fingerprinted (sha256) before the proof; if it moved
# during the build (another parallel `nix flake update`), abort loud instead
# of committing rows that were never proven.
#
# Run:            scripts/float-register.sh
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

# ── 1. drift check ────────────────────────────────────────────────────────
before=$(regen_body)
current=$(grep -E '^  [a-zA-Z0-9_.-]+ = "[0-9a-f]{40}";$' "$REGISTRY" || true)
if [ "$before" = "$current" ]; then
  echo "float-register: no drift — registry matches flake.lock"
  exit 0
fi

echo "float-register: drift detected —"
diff <(printf '%s\n' "$current") <(printf '%s\n' "$before") || true

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
  git restore -- "$REGISTRY"
  echo "✗ float-register: proof RED (rc=$rc) — registry rows REVERTED, nothing committed."
  echo "  Roots (fix upstream-first, or pin that input back):"
  grep -E 'error:|hash mismatch|got:|specified:|builder for .* failed' "$proof_log" | head -20
  exit 1
fi

lock_sha_after=$(sha256sum "$LOCK" | cut -d' ' -f1)
if [ "$lock_sha_before" != "$lock_sha_after" ]; then
  git restore -- "$REGISTRY"
  echo "✗ float-register: flake.lock MOVED during the proof (parallel update) — registry rows reverted."
  echo "  Re-run this script against the settled lock; never commit rows that were not proven."
  exit 3
fi

drifted=$(diff <(printf '%s\n' "$current") <(printf '%s\n' "$before") | grep '^>' | sed -E 's/^> +([a-zA-Z0-9_.-]+) =.*/\1/' | tr '\n' ' ' | sed 's/ $//')
msg_file=$(mktemp)
{
  echo "float: register ${drifted:-inputs} (auto-proof rc=0)"
  echo
  echo "flake.lock + expected-locks regenerated and proven together by"
  echo "scripts/float-register.sh (keep-going log: $proof_log)."
} > "$msg_file"
git add "$LOCK" "$REGISTRY"
git commit -F "$msg_file" -- "$LOCK" "$REGISTRY"
rm -f "$msg_file"
echo "✓ float-register: registered [${drifted:-}] and committed lock+registry together"
