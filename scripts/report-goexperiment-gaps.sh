#!/usr/bin/env bash
# Report LarsArtmann Go repos that import encoding/json/v2 but do not set
# GOEXPERIMENT=jsonv2 in any Nix file — their devShells are BROKEN for any
# contributor without a machine-global GOEXPERIMENT (verified on go1.26.5:
# importing encoding/json/v2 without the flag is a hard build error:
# "build constraints exclude all Go files").
#
# Also lists repos that do NOT import json/v2 — those compile flag-less today.
# Adding the flag there too is OPTIONAL cache unification for other machines;
# on evo-x2 the machine-global GOEXPERIMENT already unifies the cache key.
#
# Usage: scripts/report-goexperiment-gaps.sh [projects-dir]
# Exit 0 always (report tool, not a gate).

set -euo pipefail

PROJECTS_DIR="${1:-$HOME/projects}"

broken=()
unified=()

for dir in "$PROJECTS_DIR"/*/; do
  repo=$(basename "$dir")
  [ -f "$dir/go.mod" ] || continue

  # Imports json/v2 in non-test, non-vendor source?
  imports_v2=$(grep -rl --include='*.go' --exclude-dir=vendor --exclude-dir=node_modules \
    'encoding/json/v2' "$dir" 2>/dev/null | grep -v '_test\.go$' | head -1 || true)

  # Flag set in any nix file (flake.nix or nix/ dir)?
  has_flag=$(grep -rl 'GOEXPERIMENT' "$dir/flake.nix" "$dir/nix" 2>/dev/null | head -1 || true)

  if [ -n "$imports_v2" ]; then
    if [ -z "$has_flag" ]; then
      broken+=("$repo")
    fi
  else
    if [ -z "$has_flag" ]; then
      unified+=("$repo")
    fi
  fi
done

echo "=== BROKEN: import encoding/json/v2 but set GOEXPERIMENT nowhere in nix (${#broken[@]}) ==="
printf '  %s\n' "${broken[@]-<none>}"
echo
echo "=== Flag-less (no json/v2 import; optional unification for other machines) (${#unified[@]}) ==="
printf '  %s\n' "${unified[@]-<none>}"
echo
echo "Fix pattern (dnsblockd is the reference): nix/devshell/default.nix +"
echo 'nix/packages/default.nix env.GOEXPERIMENT = "jsonv2";'
