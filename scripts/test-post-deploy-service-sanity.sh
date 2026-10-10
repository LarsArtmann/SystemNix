#!/usr/bin/env bash
# Fixture selftest for scripts/lib/service-sanity-sweep.sh (post-deploy
# §18): synthetic cgroup cpu.stat trees + injected journal input through the
# SAME function post-deploy-check.sh sources — a hotloop must FAIL, an
# exempt unit must not, a calm fleet must PASS, and the DiscordSync numbers
# (121% CPU / 640 lines-min) must trip both legs. Exits non-zero on the
# first violated expectation. Wired as checks.<system>.post-deploy-service-sanity-selftest.
set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/service-sanity-sweep.sh"
# shellcheck source=lib/service-sanity-sweep.sh disable=SC1091
source "$LIB"

VERDICTS=()
report_pass() { VERDICTS+=("PASS $*"); }
report_warn() { VERDICTS+=("WARN $*"); }
report_skip() { VERDICTS+=("SKIP $*"); }
report_fail() { VERDICTS+=("FAIL $*"); }

fail() {
  echo "SELFTEST FAIL: $*"
  exit 1
}
expect_kinds() {
  local want="$1"
  [ "${#VERDICTS[@]}" -eq 2 ] || fail "expected exactly 2 verdicts ($want), got ${#VERDICTS[@]}: ${VERDICTS[*]:-none}"
  local joined="${VERDICTS[*]}"
  grep -qE "$want" <<<"$joined" || fail "verdicts '$joined' lack pattern '$want'"
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

mk_unit() { # mk_unit <slice> <name> <usage_usec>
  mkdir -p "$1/$2"
  printf 'usage_usec %s\nnr_periods 0\nnr_throttled 0\n' "$3" >"$1/$2/cpu.stat"
}

# 1. calm fleet + calm journal -> two PASS verdicts
mk_unit "$scratch/calm" a.service 1000
mk_unit "$scratch/calm" b.service 1000
printf '{"_SYSTEMD_UNIT":"a.service","MESSAGE":"ok"}\n' >"$scratch/calm.jsonl"
VERDICTS=()
SANITY_JOURNAL_CMD="cat $scratch/calm.jsonl" systemnix_service_sanity_sweep "$scratch/calm" 0 100 300
expect_kinds "PASS.*no service above 100%|PASS.*no service above 300"

# 2. hot CPU (the DiscordSync shape: >100% of one core sustained) -> CPU FAIL naming unit and %
# usage delta 1_500_000 usec over 1s sample = 150% of one core.
mk_unit "$scratch/hot" discordsync.service 0
(
  sleep 0.3
  printf 'usage_usec 1500000\nnr_periods 0\nnr_throttled 0\n' >"$scratch/hot/discordsync.service/cpu.stat"
) &
VERDICTS=()
SANITY_JOURNAL_CMD="cat $scratch/calm.jsonl" systemnix_service_sanity_sweep "$scratch/hot" 1 100 300
expect_kinds "FAIL.*discordsync\.service=150%CPU"

# 3. exempt unit hot on CPU -> CPU PASS (exempt honored), journal still checked
mk_unit "$scratch/exempt" clickhouse.service 0
(
  sleep 0.3
  printf 'usage_usec 9000000\nnr_periods 0\nnr_throttled 0\n' >"$scratch/exempt/clickhouse.service/cpu.stat"
) &
VERDICTS=()
SANITY_JOURNAL_CMD="cat $scratch/calm.jsonl" systemnix_service_sanity_sweep "$scratch/exempt" 1 100 300
expect_kinds "PASS Service Sanity CPU"

# 4. journal hot (DiscordSync 640 lines/min over 10m = 6400 lines) -> journal FAIL with rate
mk_unit "$scratch/jhot" discordsync.service 1000
: >"$scratch/hot.jsonl"
for _ in $(seq 1 64); do
  printf '{"_SYSTEMD_UNIT":"discordsync.service","MESSAGE":"reconcileGCSURLs"}\n' >>"$scratch/hot.jsonl"
done
VERDICTS=()
# 64 lines over a 10m window = 6/min: healthy. Make it exceed: budget 5/min -> 64 > 50 trips.
SANITY_JOURNAL_CMD="cat $scratch/hot.jsonl" systemnix_service_sanity_sweep "$scratch/jhot" 0 100 5
expect_kinds "FAIL.*discordsync\.service=6/min"

# 5. empty journal walk -> WARN (unreadable surface must never read as green)
VERDICTS=()
SANITY_JOURNAL_CMD="cat /dev/null" systemnix_service_sanity_sweep "$scratch/calm" 0
expect_kinds "WARN Service Sanity journal"

# 6. missing slice dir -> SKIP
VERDICTS=()
systemnix_service_sanity_sweep "$scratch/does-not-exist" 1
[ "${#VERDICTS[@]}" -eq 1 ] || fail "missing-dir: expected 1 verdict, got ${#VERDICTS[@]}"
[[ ${VERDICTS[0]} == SKIP* ]] || fail "missing-dir: expected SKIP, got ${VERDICTS[0]}"

echo "post-deploy-service-sanity selftest: all fixtures green"
