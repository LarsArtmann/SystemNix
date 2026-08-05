#!/usr/bin/env bash
# Restore the flake.lock nixpkgs node to github type.
#
# The Nix global registry rewrites github:NixOS/nixpkgs/nixos-unstable to a
# channels.nixos.org tarball during `nix flake update`. The tarball pointer can
# be stale by months and breaks the eval-time nixpkgsTarballGuard in flake.nix.
#
# This script reliably converts the node back to github type in one command.
# It does NOT depend on the system registry (which --override-input and
# --no-use-registries fail to bypass).
#
# Usage:
#   fix-nixpkgs-lock.sh            # pin to the currently-locked rev (no cascade)
#   fix-nixpkgs-lock.sh --latest   # update to newest nixos-unstable
#
# Exit codes: 0 = fixed or already correct, 1 = error.
set -euo pipefail

FLAKE_LOCK="flake.lock"

if [[ ! -f "$FLAKE_LOCK" ]]; then
  echo "error: $FLAKE_LOCK not found (run from the flake root)" >&2
  exit 1
fi

current_type="$(jq -r '.nodes.nixpkgs.original.type // "missing"' "$FLAKE_LOCK")"
if [[ "$current_type" == "github" ]]; then
  echo "nixpkgs node is already github type — nothing to do."
  exit 0
fi

echo "nixpkgs node is \"$current_type\" (expected github). Fixing..."

if [[ "${1:-}" == "--latest" ]]; then
  ref="github:NixOS/nixpkgs/nixos-unstable"
  echo "Fetching latest nixos-unstable metadata..."
else
  current_rev="$(jq -r '.nodes.nixpkgs.locked.rev // empty' "$FLAKE_LOCK")"
  if [[ -z "$current_rev" ]]; then
    echo "error: cannot determine current rev from $FLAKE_LOCK (use --latest)" >&2
    exit 1
  fi
  ref="github:NixOS/nixpkgs/${current_rev}"
  echo "Pinning to current rev ${current_rev} (no dependency cascade)..."
fi

# nix flake prefetch resolves an explicit github: URL WITHOUT registry
# interception and returns complete original/locked metadata + hash.
prefetch_json="$(nix flake prefetch "$ref" --json)"
original="$(jq -c '.original' <<<"$prefetch_json")"
locked="$(jq -c '.locked + {narHash: .hash}' <<<"$prefetch_json")"

jq --argjson orig "$original" --argjson lock "$locked" \
  '.nodes.nixpkgs.original = $orig | .nodes.nixpkgs.locked = $lock' \
  "$FLAKE_LOCK" > "${FLAKE_LOCK}.tmp" && mv "${FLAKE_LOCK}.tmp" "$FLAKE_LOCK"

new_rev="$(jq -r '.nodes.nixpkgs.locked.rev' "$FLAKE_LOCK")"
echo "nixpkgs node is now github type at rev ${new_rev}."

# Re-lock dependents so inputs that follow nixpkgs stay consistent. This uses
# --no-use-registries defensively; the nixpkgs node is already github-typed so
# it will not be rewritten.
echo "Re-locking dependent inputs..."
nix flake lock --no-use-registries 2>/dev/null || true

echo "Verifying evaluation..."
if nix flake check --no-build >/dev/null 2>&1; then
  echo "OK: nix flake check --no-build passes."
else
  echo "warning: nix flake check --no-build failed — inspect remaining issues." >&2
  nix flake check --no-build 2>&1 | tail -5 >&2 || true
fi
