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
  # overlays/ shapes the pkgs instance (flake.nix "overlays = import ./overlays
  # inputs") — an overlay edit moves the toplevel drv. 2026-11-10 live catch:
  # the taskchampion-overlay LIFT commit rode this gap — the pre-commit hook
  # judged overlays/linux.nix eval-irrelevant and skipped its flake-check leg.
  # (§11's VENDOR_FRESHNESS_EVAL_PATHS already listed overlays/; this array
  # was the odd one out.)
  overlays
  # systems/ = the thin host assemblies (flake.nix "assembled in
  # systems/*.nix") — a host-file edit moves that host's toplevel drv.
  # Found 2026-11-10 evening while a sibling's systems/evo-x2.nix edit
  # was in flight: both consumers were blind to it.
  systems
  # scripts/lib/buildcache-reap-names.sh is the one file outside the directory
  # roots whose CONTENT can fail a --no-build eval: lib/buildcache-cache-names.nix
  # readFile+regex PARSES it and throws on a missing/malformed assignment
  # (added 2026-11-03 when the pre-commit eval-relevance skip started keying on
  # this array). Other scripts/*.sh are only readFile'd raw — content moves
  # drvPaths (never realized by --no-build); their ABSENCE is what throws, and
  # deletion/rename consumers catch that with --diff-filter=DR, not this list.
  scripts/lib/buildcache-reap-names.sh
)
