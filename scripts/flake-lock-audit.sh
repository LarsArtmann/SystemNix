#!/usr/bin/env bash
# Running-vs-lock rev audit (2026-10-23).
#
# Answers ONE question the pre-deploy battery never asked: is the system that
# is actually RUNNING built from the nixpkgs rev this tree pins?
#
# Why it exists: the 2026-10-23 deploy recovery burned four hours on hash
# whack-a-mole before anyone ran `readlink /run/current-system`. The running
# generation had been built from nixpkgs fe13242 while the tree pinned the
# 2026-10-20 tip 02c087f3 — one line of comparison would have pointed at the
# rollback route immediately instead of ten CLI cycles later. Every hash
# measured against the wrong builder graph looks like a random regression.
#
# Also reports the git rev the running system was built from vs HEAD. That is
# INFORMATIONAL (an uncommitted tree or an ahead-of-deploy HEAD is normal);
# only the nixpkgs mismatch changes the exit code.
#
# Usage:
#   scripts/flake-lock-audit.sh              exit 1 on nixpkgs mismatch
#   scripts/flake-lock-audit.sh --advisory   always exit 0 (pre-deploy section)
#   scripts/flake-lock-audit.sh --selftest   fixture assertions, no live probes
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

nla_short() { printf '%s' "${1:0:7}"; }

# Field from a nixos-version --json document on stdin.
nla_json_field() { jq -r --arg f "$1" '.[$f] // ""'; }

# nixpkgs rev the lock's ROOT resolves to. `nodes.nixpkgs` may be an ORPHAN
# at a different rev (the 2026-10-23 split brain), so always resolve through
# root.inputs — the same rule lib/flake-input-pin-audit.nix surface 3 enforces.
nla_locked_nixpkgs() {
  jq -r '.nodes[.nodes[.root].inputs.nixpkgs].locked.rev // ""' <"$1/flake.lock"
}

# Emit a comparison verdict: `match` | `mismatch` | `unknown`.
nla_verdict() {
  local running=$1 locked=$2
  if [[ -z $running || -z $locked ]]; then
    printf 'unknown'
  elif [[ $running == "$locked" ]]; then
    printf 'match'
  else
    printf 'mismatch'
  fi
}

nla_selftest() {
  local failures=0
  check() {
    local label=$1 got=$2 want=$3
    if [[ $got == "$want" ]]; then
      printf 'ok   %s\n' "$label"
    else
      printf 'FAIL %s (got %q want %q)\n' "$label" "$got" "$want"
      failures=$((failures + 1))
    fi
  }
  check "short rev" "$(nla_short fe13242281a67641c0102cdb1087f0ebe586c7df)" "fe13242"
  check "match verdict" "$(nla_verdict abc123 abc123)" "match"
  check "mismatch verdict" "$(nla_verdict fe13242 02c087f3)" "mismatch"
  check "unknown when running empty" "$(nla_verdict "" abc123)" "unknown"
  check "unknown when locked empty" "$(nla_verdict abc123 "")" "unknown"
  check "json field" "$(printf '%s' '{"nixpkgsRevision":"fe13242"}' | nla_json_field nixpkgsRevision)" "fe13242"
  check "json field absent" "$(printf '%s' '{}' | nla_json_field nixpkgsRevision)" ""
  if ((failures > 0)); then
    printf '\n%d selftest assertion(s) failed\n' "$failures" >&2
    return 1
  fi
  printf '\nall selftest assertions passed\n'
}

ADVISORY=0
case "${1:-}" in
--selftest)
  nla_selftest
  exit $?
  ;;
--advisory) ADVISORY=1 ;;
"") ;;
*)
  printf 'usage: %s [--advisory|--selftest]\n' "$0" >&2
  exit 2
  ;;
esac

if [[ ! -e /run/current-system ]]; then
  echo "flake-lock-audit: /run/current-system absent (not a NixOS host?) — skipping."
  exit 0
fi

NIXOS_VERSION_BIN=/run/current-system/sw/bin/nixos-version
if [[ ! -x $NIXOS_VERSION_BIN ]]; then
  echo "flake-lock-audit: $NIXOS_VERSION_BIN missing — cannot read the running rev; skipping."
  exit 0
fi

running_json=$("$NIXOS_VERSION_BIN" --json 2>/dev/null || printf '{}')
running_nixpkgs=$(printf '%s' "$running_json" | nla_json_field nixpkgsRevision)
running_repo=$(printf '%s' "$running_json" | nla_json_field configurationRevision)
locked_nixpkgs=$(nla_locked_nixpkgs "$REPO_ROOT")

head_repo=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf '')

echo "running vs pinned (running-vs-lock audit):"
printf '  nixpkgs  running: %s\n' "${running_nixpkgs:-unknown}"
printf '  nixpkgs  pinned : %s\n' "${locked_nixpkgs:-unknown}"
printf '  git      running: %s\n' "${running_repo:-unknown}"
printf '  git      HEAD   : %s\n' "${head_repo:-unknown}"

if [[ -n $running_repo && -n $head_repo && $running_repo != "$head_repo" ]]; then
  printf "${YELLOW}  note: the running system was built from %s, HEAD is %s — normal when commits landed after the last deploy.${NC}\n" \
    "$(nla_short "$running_repo")" "$(nla_short "$head_repo")"
fi

verdict=$(nla_verdict "$running_nixpkgs" "$locked_nixpkgs")
case "$verdict" in
match)
  printf "${GREEN}  VERDICT: running nixpkgs == pinned nixpkgs (%s) — hash probes measure the right builder graph.${NC}\n" \
    "$(nla_short "$running_nixpkgs")"
  exit 0
  ;;
mismatch)
  printf "${RED}  VERDICT: MISMATCH — running %s, pinned %s.${NC}\n" \
    "$(nla_short "$running_nixpkgs")" "$(nla_short "$locked_nixpkgs")"
  printf "${RED}  Any FOD/vendorHash probe you take in this tree measures the PINNED graph,${NC}\n"
  printf "${RED}  not the one the live system was built with. Expect hash whack-a-mole until${NC}\n"
  printf "${RED}  you decide which graph is canonical (roll the pin back, or deploy forward).${NC}\n"
  if ((ADVISORY == 1)); then
    echo "  (advisory mode — not blocking)"
    exit 0
  fi
  exit 1
  ;;
*)
  echo "  VERDICT: unknown — could not read one of the revs; not treating as a failure."
  exit 0
  ;;
esac
