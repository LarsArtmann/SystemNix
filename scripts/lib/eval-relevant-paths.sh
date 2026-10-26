# shellcheck shell=bash
# Single shared definition of the "eval-relevant tree" — the paths whose
# on-disk mutation can change a NixOS flake eval. Two consumers:
#   1. deploy-when-quiescent.sh's heat-check (fire-permission watcher)
#   2. §11's tree-stamp in scripts/lib/vendor-freshness.sh (adoption
#      pending — swap its inline list for this array in a dedicated change;
#      a deploy-battle-tested script gets its own commit, not a rider).
# The root `flake.lock` was missed once (2026-10-25 19:26 fire) and cost a
# full deploy battery — root-level lock files MUST stay in this list.
# SC2034: consumed by the sourcing script via "${EVAL_RELEVANT_PATHS[@]}"
# (shellcheck analyzes libs in isolation and cannot see the consumer).
# shellcheck disable=SC2034
EVAL_RELEVANT_PATHS=(
  modules
  platforms
  flake.nix
  flake.lock
  flake
  lib
  pkgs
)
