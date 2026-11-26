#!/usr/bin/env bash
# Age of the STALEST loaded blocklist, and whether that is too old.
#
# WHY per list: dnsblockd loads ~22 lists whose store paths change only when
# someone moves a pin. Nix store files carry mtime = 1 (reproducibility), so
# a file's age says nothing; what is measurable is the first moment this
# observer saw each list's CURRENT path. A hash over the whole set (the first
# version of this gauge) resets whenever any one list moves, and the weekly
# blocklist-auto-update timer moves StevenBlack on its own, so a HaGeZi pin
# nobody bumps would never have tripped it (2026-11-26). One remembered
# moment per list closes that: a list that did not move keeps its age.
#
# Usage:
#   blocklist-freshness.sh --state-dir DIR --stale-after SECONDS --now EPOCH FILE...
#
# Prints "<oldest age in seconds> <stale 0|1>". With no FILE (tempAllowAll:
# blocking is deliberately off) it prints "-1 0" and touches no state.
# DIR/blocklist-since holds one "<md5 of path> <first-seen epoch> <name>"
# line per list, rewritten atomically on every run; lists that are gone
# simply drop out.
#
# `--now` is injected so the fixture selftest
# (scripts/test-blocklist-freshness.sh) can walk a clock.
set -euo pipefail

state_dir=""
stale_after=""
now=""
files=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  --state-dir | --stale-after | --now)
    [[ $# -ge 2 ]] || { echo "blocklist-freshness: $1 needs a value" >&2; exit 2; }
    case "$1" in
    --state-dir) state_dir="$2" ;;
    --stale-after) stale_after="$2" ;;
    --now) now="$2" ;;
    esac
    shift 2
    ;;
  --)
    shift
    while [[ $# -gt 0 ]]; do
      files+=("$1")
      shift
    done
    ;;
  -*) echo "blocklist-freshness: unknown option: $1" >&2; exit 2 ;;
  *) files+=("$1"); shift ;;
  esac
done

for required in "$state_dir" "$stale_after" "$now"; do
  [[ -n $required ]] || { echo "blocklist-freshness: --state-dir, --stale-after and --now are all required" >&2; exit 2; }
done
[[ $stale_after =~ ^[0-9]+$ && $now =~ ^[0-9]+$ ]] || {
  echo "blocklist-freshness: --stale-after and --now must be non-negative integers" >&2
  exit 2
}

if [[ ${#files[@]} -eq 0 ]]; then
  printf -- '-1 0\n'
  exit 0
fi

mkdir -p "$state_dir"
state="$state_dir/blocklist-since"

# First-seen moments already known, keyed by path hash. A malformed line is
# skipped: its list is then treated as seen for the first time (age 0), the
# same as after a fresh install.
declare -A first_seen=()
if [[ -r $state ]]; then
  while read -r hash since _; do
    if [[ $hash =~ ^[0-9a-f]{32}$ && $since =~ ^[0-9]+$ ]]; then
      first_seen["$hash"]="$since"
    fi
  done <"$state"
fi

oldest=0
new_state=""
for list_file in "${files[@]}"; do
  key="$(printf '%s' "$list_file" | md5sum | cut -d' ' -f1)"
  since="${first_seen[$key]:-}"
  if [[ ! $since =~ ^[0-9]+$ ]]; then
    since="$now"
  fi
  new_state+="$key $since $(basename "$list_file")"$'\n'
  age=$((now - since))
  if (( age > oldest )); then
    oldest=$age
  fi
done

staging="$state.tmp.$$"
printf '%s' "$new_state" >"$staging"
mv -f "$staging" "$state"

stale=0
if (( oldest > stale_after )); then
  stale=1
fi
printf '%s %s\n' "$oldest" "$stale"
