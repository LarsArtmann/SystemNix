#!/usr/bin/env bash
# Turn a failed FOD enumeration into a ready-to-apply hash patch (2026-10-23).
#
# The problem this solves: when nixpkgs (or an input) moves, MANY fixed-output
# derivations re-stale at once. The 2026-10-23 recovery hit ten of them across
# four waves; each one was a manual cycle of "build fails -> read specified and
# got -> find the literal -> paste". With one mismatch that is fine. With ten it
# is an hour of typing and a guaranteed transcription error (a hand-pasted hash
# is exactly the class of mistake that costs a second full build).
#
# The input is the log from the documented enumeration command:
#
#   nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel \
#     --keep-going --no-link --print-build-logs > /tmp/toplevel.log 2>&1
#
# Nix prints, per stale FOD:
#
#   error: hash mismatch in fixed-output derivation '/nix/store/…-foo-go-modules.drv':
#            specified: sha256-J7gNXzrVQ4cPdAXBHTjwu7mvvHZskDsFYIURJuoBIEM=
#               got:    sha256-EQe80wmzlsTM1PjjLKcsOPW/oEXJG4mV3dsJhR9+ZOE=
#
# This script extracts every (specified, got) pair, locates each `specified`
# literal in tracked *.nix sources, and prints a unified diff. `--apply` writes
# the replacements (then you re-run the same enumeration to confirm).
#
# Deliberately NOT automated: choosing which literal to change when one value
# appears on several surfaces with DIFFERENT intent. The report lists every
# site per hash so the reviewer sees the blast radius; a bare `--apply` is only
# safe when each hash maps to the sites you expect.
#
# Usage:
#   fod-hash-diff.sh <build-log>            report + diff preview
#   fod-hash-diff.sh <build-log> --apply    write the replacements
#   fod-hash-diff.sh --selftest             fixture assertions
#
# Exit codes: 0 = nothing stale (or applied); 1 = stale hashes reported;
#             2 = usage/input error.
set -euo pipefail

REPO_ROOT=${FHD_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Emit "drv<TAB>specified<TAB>got" per stale FOD. Reads the log on stdin.
fhd_pairs() {
  awk '
    /hash mismatch in fixed-output derivation/ {
      drv = $0
      sub(/^.*derivation .\//, "", drv)
      sub(/\.drv.:.*$/, "", drv)
      sub(/^nix\/store\/[a-z0-9]+-/, "", drv)
      want = 1
      next
    }
    want && /specified:/ {
      spec = $2
      if (spec == "") spec = $NF
      next
    }
    want && /got:/ {
      got = $2
      if (got == "") got = $NF
      print drv "\t" spec "\t" got
      want = 0
      next
    }
  '
}

# Site list for one literal across tracked/working *.nix sources. Empty
# (exit 0) when no file carries it: under `set -e -o pipefail` the bare
# grep's exit 1 once aborted the whole run right after the pair's header —
# the upstream-hash note never printed and every LATER pair went unreported
# and unapplied (2026-11-27: journal ended a two-stale report silently).
fhd_sites() {
  local literal=$1
  { grep -rlF --include='*.nix' -- "$literal" "$REPO_ROOT" 2>/dev/null || true; } |
    sed "s#^$REPO_ROOT/##" | sort
}

# Replace one literal in one file. `|` is a safe sed delimiter here: base64
# carries no `|`, `&`, or backslash. Full-line comments are LEFT ALONE: shim
# blocks routinely record "specified X vs got Y" as history, and rewriting that
# would destroy the evidence trail (the 2026-10-23 shim comments are exactly
# that shape). Inline trailing comments still get rewritten, which is rare
# enough to accept rather than to parse Nix.
fhd_apply() {
  local file=$1 spec=$2 got=$3
  sed -i "/^[[:space:]]*#/!s|${spec}|${got}|g" "$file"
}

# Subset of fhd_sites with at least one NON-comment occurrence — i.e. the
# files where a replacement actually changes build behaviour.
#
# No `… | grep -q` here: under pipefail `grep -q` exits on the first match,
# the producer dies of SIGPIPE (141) as soon as it has more to write than
# the pipe buffer holds, and a FOUND match reads as a miss. 2026-11-27 live:
# tq-agent-pool.nix's shim line was reported "comment only, not rewritten"
# and a --apply would have left it stale. Read the filtered lines to EOF
# instead.
fhd_live_sites() {
  local literal=$1 f hits
  while IFS= read -r f; do
    [[ -n $f ]] || continue
    hits=$(grep -vE '^[[:space:]]*#' "$REPO_ROOT/$f" | grep -F -- "$literal" || true)
    if [[ -n $hits ]]; then
      printf '%s\n' "$f"
    fi
  done < <(fhd_sites "$literal")
}

fhd_selftest() {
  local failures=0 tmp
  check() {
    local label=$1 got=$2 want=$3
    if [[ $got == "$want" ]]; then
      printf 'ok   %s\n' "$label"
    else
      printf 'FAIL %s (got %q want %q)\n' "$label" "$got" "$want"
      failures=$((failures + 1))
    fi
  }

  tmp=$(mktemp -d)
  cat >"$tmp/log" <<'FIXTURE'
building '/nix/store/aaaa-foo-go-modules.drv'...
error: hash mismatch in fixed-output derivation '/nix/store/j8x1zkp1zhhcnyhv6pxhmbhhkmxzdkhv-cqrs-lint-a7a033c53fe2b60dfa5876a5efe685625e1bb21f-go-modules.drv':
         specified: sha256-J7gNXzrVQ4cPdAXBHTjwu7mvvHZskDsFYIURJuoBIEM=
            got:    sha256-EQe80wmzlsTM1PjjLKcsOPW/oEXJG4mV3dsJhR9+ZOE=
error: Cannot build '/nix/store/fa2gy8j0hlf6r5m6ach4arj6svh9af38-cqrs-lint-a7a033c53fe2b60dfa5876a5efe685625e1bb21f.drv'.
error: hash mismatch in fixed-output derivation '/nix/store/bbbb-bar-pnpm-deps.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
FIXTURE

  local pairs count
  pairs=$(fhd_pairs <"$tmp/log")
  count=$(printf '%s\n' "$pairs" | wc -l | tr -d ' ')
  check "two pairs extracted" "$count" "2"
  check "first drv name" "$(printf '%s\n' "$pairs" | head -1 | cut -f1)" \
    "cqrs-lint-a7a033c53fe2b60dfa5876a5efe685625e1bb21f-go-modules"
  check "first specified" "$(printf '%s\n' "$pairs" | head -1 | cut -f2)" \
    "sha256-J7gNXzrVQ4cPdAXBHTjwu7mvvHZskDsFYIURJuoBIEM="
  check "first got" "$(printf '%s\n' "$pairs" | head -1 | cut -f3)" \
    "sha256-EQe80wmzlsTM1PjjLKcsOPW/oEXJG4mV3dsJhR9+ZOE="
  check "second got" "$(printf '%s\n' "$pairs" | tail -1 | cut -f3)" \
    "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="

  # A log with no mismatches must yield zero pairs (not a phantom entry).
  printf 'building ok\n' >"$tmp/clean"
  check "clean log yields nothing" "$(fhd_pairs <"$tmp/clean" | wc -l | tr -d ' ')" "0"

  # Site classification: a literal in real code is live; the same literal only
  # in a full-line comment is history, and must NOT be rewritten.
  local saved_root=$REPO_ROOT
  mkdir -p "$tmp/tree"
  cat >"$tmp/tree/live-site.nix" <<'FIXTURE'
{
  vendorHash = "sha256-HASHLIVEHASHLIVEHASHLIVEHASHLIVEHASHLIVEHASH=";
}
FIXTURE
  cat >"$tmp/tree/comment-site.nix" <<'FIXTURE'
{
  # specified sha256-HASHONLYHASHONLYHASHONLYHASHONLYHASHONLYHASH= vs got next
  vendorHash = "sha256-OTHEROTHEROTHEROTHEROTHEROTHEROTHEROTHEROTHER=";
}
FIXTURE
  REPO_ROOT=$tmp/tree
  check "live literal located" "$(fhd_live_sites 'sha256-HASHLIVEHASHLIVEHASHLIVEHASHLIVEHASHLIVEHASH=' | tr '\n' ' ')" "live-site.nix "
  check "comment-only literal is not live" "$(fhd_live_sites 'sha256-HASHONLYHASHONLYHASHONLYHASHONLYHASHONLYHASH=' | wc -l | tr -d ' ')" "0"
  check "comment-only literal is still reported as a site" "$(fhd_sites 'sha256-HASHONLYHASHONLYHASHONLYHASHONLYHASHONLYHASH=' | tr '\n' ' ')" "comment-site.nix "

  # Race regression (2026-11-27): a live literal EARLY in a file that has
  # more non-comment lines after it than a pipe buffer holds. Under
  # `producer | grep -q` + pipefail the match was found and still read as
  # a miss (producer SIGPIPE 141; 20/20 runs on this fixture): a live shim
  # reported "comment only" and skipped by --apply. The padding must be
  # NON-comment lines — comments are what the producer filters out.
  local pad_live='sha256-PADLIVEPADLIVEPADLIVEPADLIVEPADLIVEPADLIVE='
  {
    printf '{\n  vendorHash = "%s=";\n  padding = [\n' "$pad_live"
    for ((pad = 0; pad < 3000; pad++)); do
      printf '    "padding-padding-padding-padding-padding-padding-padding-padding-padding"\n'
    done
    printf '  ];\n}\n'
  } >"$tmp/tree/padded-site.nix"
  REPO_ROOT=$tmp/tree
  check "early live literal in a large file is live (SIGPIPE race)" \
    "$(fhd_live_sites "$pad_live" | tr '\n' ' ')" "padded-site.nix "
  fhd_apply "$tmp/tree/padded-site.nix" "$pad_live" 'sha256-REPLACED='
  check "apply rewrites the early live literal in a large file" \
    "$(grep -cF 'sha256-REPLACED=' "$tmp/tree/padded-site.nix")" "1"
  REPO_ROOT=$saved_root
  fhd_apply "$tmp/tree/comment-site.nix" 'sha256-HASHONLYHASHONLYHASHONLYHASHONLYHASHONLYHASH=' 'sha256-REPLACED='
  check "apply leaves the comment intact" \
    "$(grep -cF 'sha256-HASHONLYHASHONLYHASHONLYHASHONLYHASHONLYHASH=' "$tmp/tree/comment-site.nix")" "1"
  REPO_ROOT=$saved_root

  # End to end (2026-11-27): an UPSTREAM-only stale hash (no *.nix site) is
  # reported, never fatal — the pair after it must still be reported and,
  # under --apply, rewritten. Before the fix the bare grep's exit 1 aborted
  # the run on the first pair.
  cat >"$tmp/tree/e2e-live.nix" <<'FIXTURE'
{
  vendorHash = "sha256-E2ELIVEE2ELIVEE2ELIVEE2ELIVEE2ELIVEE2ELIVEE=";
}
FIXTURE
  cat >"$tmp/e2e.log" <<'FIXTURE'
error: hash mismatch in fixed-output derivation '/nix/store/cccc-e2e-upstream-go-modules.drv':
         specified: sha256-E2EUPSTRE2EUPSTRE2EUPSTRE2EUPSTRE2EUPSTR=
            got:    sha256-E2EUPGOTE2EUPGOTE2EUPGOTE2EUPGOTE2EUPGOTXX=
error: hash mismatch in fixed-output derivation '/nix/store/dddd-e2e-live-go-modules.drv':
         specified: sha256-E2ELIVEE2ELIVEE2ELIVEE2ELIVEE2ELIVEE2ELIVEE=
            got:    sha256-E2ELIVEGOTE2ELIVEGOTE2ELIVEGOTE2ELIVEGOT=
FIXTURE
  if FHD_ROOT="$tmp/tree" "$BASH" "$0" "$tmp/e2e.log" --apply >"$tmp/e2e.out" 2>&1; then
    e2e_rc=0
  else
    e2e_rc=$?
  fi
  check "upstream-only stale hash is not fatal (apply mode exits 0)" "$e2e_rc" "0"
  check "upstream-only stale hash is explained" \
    "$(grep -c 'no \*.nix site carries this literal' "$tmp/e2e.out")" "1"
  check "the pair after an upstream-only hash is still applied" \
    "$(grep -c 'applied to 1 file' "$tmp/e2e.out")" "1"
  check "the live site after an upstream-only hash is rewritten" \
    "$(grep -cF 'sha256-E2ELIVEGOTE2ELIVEGOTE2ELIVEGOTE2ELIVEGOT=' "$tmp/tree/e2e-live.nix")" "1"

  rm -rf "$tmp"

  # NOTE: no live-tree assertion here on purpose. The fixtures above cover the
  # parser and the classification contract; asserting on THIS repo's shim
  # inventory would couple the test to a moving target and cannot run from the
  # sandboxed flake check (the script is copied away from the repo root).

  if ((failures > 0)); then
    printf '\n%d selftest assertion(s) failed\n' "$failures" >&2
    return 1
  fi
  printf '\nall selftest assertions passed\n'
}

case "${1:-}" in
--selftest)
  fhd_selftest
  exit $?
  ;;
"" | -h | --help)
  printf 'usage: %s <build-log> [--apply]\n       %s --selftest\n' "$0" "$0" >&2
  exit 2
  ;;
esac

LOG=$1
APPLY=${2:-}
[[ -f $LOG ]] || {
  echo "error: build log '$LOG' not found" >&2
  exit 2
}

pairs=$(fhd_pairs <"$LOG")
if [[ -z $pairs ]]; then
  printf "${GREEN}No stale fixed-output hashes in %s — nothing to do.${NC}\n" "$LOG"
  exit 0
fi

stale=0
while IFS=$'\t' read -r drv spec got; do
  [[ -n $spec && -n $got ]] || continue
  stale=$((stale + 1))
  printf "\n${YELLOW}%s${NC}\n" "$drv"
  printf '  specified: %s\n  got      : %s\n' "$spec" "$got"
  sites=$(fhd_sites "$spec")
  live=$(fhd_live_sites "$spec")
  if [[ -z $sites ]]; then
    printf "  ${RED}no *.nix site carries this literal${NC} — it comes from an UPSTREAM flake (paste the got value there, or add a consumer shim)\n"
  else
    printf '  sites:\n'
    while IFS= read -r f; do
      [[ -n $f ]] || continue
      if grep -qxF -- "$f" <<<"$live"; then
        printf '    %s\n' "$f"
      else
        printf '    %s  (comment only, not rewritten)\n' "$f"
      fi
    done <<<"$sites"
    if [[ -z $live ]]; then
      printf "  ${YELLOW}all sites are comments — the literal is stale only in prose; nothing to apply${NC}\n"
    elif [[ $APPLY == "--apply" ]]; then
      while IFS= read -r f; do
        [[ -n $f ]] || continue
        fhd_apply "$REPO_ROOT/$f" "$spec" "$got"
      done <<<"$live"
      printf "  ${GREEN}applied to %d file(s)${NC}\n" "$(printf '%s\n' "$live" | wc -l | tr -d ' ')"
    fi
  fi
done <<<"$pairs"

printf '\n%d stale fixed-output derivation(s)\n' "$stale"
if [[ $APPLY == "--apply" ]]; then
  printf "${GREEN}Replacements written. Re-run the same --keep-going enumeration to confirm.${NC}\n"
  exit 0
fi
printf "Re-run with --apply to write them, or paste the got values by hand where the intent differs per site.\n"
exit 1
