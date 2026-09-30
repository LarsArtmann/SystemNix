#!/usr/bin/env bash
# Print a flake.lock node for a root input, handling the string-root quirk:
# the lock's top-level "root" is a NODE KEY STRING, not a mapping, so the
# node for input X is nodes[<root-key>.inputs.X] — never a bare
# nodes[<input>] read (which silently shows the WRONG node when an input
# name collides with a node key, the nixpkgs_2 / go-nix-helpers class).
#
# Usage: scripts/flake-lock-node.sh <input> [lockfile]   (lockfile default: ./flake.lock)
#
# Prints the node JSON; exit 1 (with a message on stderr) when the input is
# missing from the root inputs mapping or the lock file is absent.
set -euo pipefail

input="${1:?usage: flake-lock-node.sh <input> [flake.lock]}"
lock="${2:-flake.lock}"
[ -f "$lock" ] || { echo "flake.lock not found: $lock" >&2; exit 1; }

node_key=$(jq -r --arg i "$input" '.root as $r | .nodes[$r].inputs[$i] // empty' "$lock")
if [ -z "$node_key" ]; then
  echo "input '$input' not found in $lock root inputs (check the spelling; root inputs mapping is the source of truth)" >&2
  exit 1
fi

jq --arg k "$node_key" '.nodes[$k]' "$lock"
