#!/usr/bin/env bash
# Fixture tests for scripts/lib/blocklist-freshness.sh, the per-list
# staleness gauge behind dnsblockd_blocklist_refresh_stale (emitted by the
# dnsblockd-otel-observer unit every 60 s, paged on by the Gatus check
# "DNS Blocker Blocklist Freshness").
#
# The script is RUN, never re-implemented (the metrics-gate lesson: a fixture
# that greps its own copy of the logic proves nothing), and the clock is
# injected through --now, so each leg is a complete walk:
#
#   no lists at all (tempAllowAll)                  -> -1 0, no state written
#   first sight                                     -> 0 0
#   30 days exactly                                 -> not stale (strictly older)
#   30 days + 1 s                                   -> stale
#   ONE list moves, the other does not              -> the still one keeps its
#                                                      age (the whole-set hash
#                                                      used to reset here)
#   every list moves                                -> 0 0, and a list that is
#                                                      no longer loaded is
#                                                      forgotten
#   listing order                                   -> irrelevant (max, not
#                                                      last-one-wins)
#   corrupted state file                            -> first sight again
#   a state line with a bad epoch                   -> that list starts over,
#                                                      the others keep theirs
#   bad arguments                                   -> exit 2, nothing written
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
subject="$here/lib/blocklist-freshness.sh"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
lists="$scratch/lists"
state="$scratch/state"
mkdir -p "$lists/gen-a" "$lists/gen-b" "$lists/other"

passed=0
fail() {
  echo "FAIL: $*" >&2
  exit 1
}
ok() {
  echo "  ok: $1"
  passed=$((passed + 1))
}

# expect <leg> <want output> <now> <files...>   (stale-after fixed at 30 days)
expect() {
  local leg="$1" want="$2" now="$3"
  shift 3
  local got
  got="$(bash "$subject" --state-dir "$state" --stale-after 2592000 --now "$now" "$@")" \
    || fail "$leg: unexpected non-zero exit"
  [[ $got == "$want" ]] || fail "$leg: got '$got', want '$want'"
  ok "$leg"
}

# expect-arg-error <leg> <args...>: exit 2 and no state file appears
expect_arg_error() {
  local leg="$1"
  shift
  local rc=0
  bash "$subject" "$@" >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 2 ]] || fail "$leg: exit $rc, want 2"
  [[ ! -e $state/blocklist-since ]] || fail "$leg: an invalid run wrote state"
  ok "$leg"
}

hagezi_a="$lists/gen-a/HaGeZi-ultimate"
sb_a="$lists/gen-a/StevenBlack-everything"
sb_b="$lists/gen-b/StevenBlack-everything"
touch "$hagezi_a" "$sb_a" "$sb_b"
t0=1700000000
day=86400

expect "no lists (tempAllowAll) answers -1 0 and writes no state" "-1 0" "$t0"
[[ ! -e $state ]] || fail "the empty run created a state dir"

expect "first sight is age 0" "0 0" "$t0" "$hagezi_a" "$sb_a"
[[ -f $state/blocklist-since ]] || fail "first sight wrote no state file"

expect "an unchanged pair keeps age 0 one second later" "1 0" "$((t0 + 1))" "$hagezi_a" "$sb_a"
expect "30 days exactly is not stale" "$((30 * day)) 0" "$((t0 + 30 * day))" "$hagezi_a" "$sb_a"
expect "30 days + 1 s is stale" "$((30 * day + 1)) 1" "$((t0 + 30 * day + 1))" "$hagezi_a" "$sb_a"

# The 2026-11-26 class: StevenBlack's weekly pin advance must not reset the
# age of a HaGeZi pin nobody bumps.
expect "one list moves, the stale list keeps its age" "$((30 * day + 1)) 1" "$((t0 + 30 * day + 1))" "$hagezi_a" "$sb_b"
expect "the moved list starts at 0; the stale one is still stale" "$((30 * day + 2)) 1" "$((t0 + 30 * day + 2))" "$hagezi_a" "$sb_b"
expect "every list moves: back to 0" "0 0" "$((t0 + 30 * day + 3))" "$lists/other/HaGeZi-ultimate" "$lists/other/StevenBlack-everything"

# A list that is no longer loaded drops out of the state (the gen-a paths
# above are gone), so the pair that just moved is the whole history now.
expect "argument order does not change the age" "2 0" "$((t0 + 30 * day + 5))" \
  "$lists/other/HaGeZi-ultimate" "$lists/other/StevenBlack-everything"
expect "... nor does the reversed order" "2 0" "$((t0 + 30 * day + 5))" \
  "$lists/other/StevenBlack-everything" "$lists/other/HaGeZi-ultimate"
grep -c ' ' "$state/blocklist-since" | grep -qx 2 || fail "a dropped list is still remembered: $(cat "$state/blocklist-since")"
ok "a list that is no longer loaded is forgotten"

rm -f "$state/blocklist-since"
printf 'garbage without any newline' >"$state/blocklist-since"
expect "a corrupted state file is a first sight" "0 0" "$t0" "$hagezi_a" "$sb_a"

expect "the clean state survives the next run" "7 0" "$((t0 + 7))" "$hagezi_a" "$sb_a"
hkey="$(md5sum <<<"$hagezi_a" | cut -d' ' -f1)"
skey="$(md5sum <<<"$sb_a" | cut -d' ' -f1)"
printf '%s %s HaGeZi-ultimate\n%s not-a-number StevenBlack-everything\n' "$hkey" "$t0" "$skey" >"$state/blocklist-since"
expect "a bad epoch restarts only its own list" "9 0" "$((t0 + 9))" "$hagezi_a" "$sb_a"

grep -q "^$skey $((t0 + 9)) StevenBlack-everything$" "$state/blocklist-since" \
  || fail "the restarted list did not get the injected now ($((t0 + 9))) as its first-seen moment"
ok "the restarted list is recorded with the current now"

expect_arg_error "a missing value is an argument error" --state-dir "$state" --stale-after 2592000 --now
expect_arg_error "a non-integer stale-after is an argument error" --state-dir "$state" --stale-after soon --now "$t0" "$hagezi_a"
expect_arg_error "an unknown option is an argument error" --state-dir "$state" --stale-after 2592000 --now "$t0" --turbo "$hagezi_a"

echo "dnsblockd blocklist freshness: $passed legs passed"
