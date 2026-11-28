#!/usr/bin/env bash
# Selftest for scripts/lib/signoz-dashboards-drift.sh (post-deploy-check.sh).
#
# Drives the SAME library the checker sources over fixture dashboards and a
# fixture reader in place of the SigNoz API:
#   identical      every live spec equals its file (key order aside) -> PASS
#   edited         one live spec differs                           -> FAIL names it
#   not-served     a file the API does not serve                  -> FAIL names it
#   no-slug        a file without a slug                          -> FAIL names it
#   api-silent     the API answers nothing                        -> SKIP
#   no-files       no dashboard files at all                      -> SKIP
# plus a wiring pin: post-deploy-check.sh must still source the library and
# call the function (a re-inline orphans the legs loudly).
#
# usage: test-post-deploy-signoz-dashboards.sh [path/to/post-deploy-check.sh]
set -uo pipefail

lib="$(dirname "${BASH_SOURCE[0]}")/lib/signoz-dashboards-drift.sh"
checker="${1:-$(dirname "${BASH_SOURCE[0]}")/post-deploy-check.sh}"
# shellcheck source=lib/signoz-dashboards-drift.sh disable=SC1091
source "$lib"

# The fixture reader: the list of dashboards and one file per dashboard id.
FIXTURES="$(mktemp -d)"
trap 'rm -rf "$FIXTURES"' EXIT
fixture_get() {
  case "$1" in
  "/api/v2/dashboards?limit=100&offset=0") cat "$FIXTURES/list.json" ;;
  /api/v2/dashboards/*) cat "$FIXTURES/live${1#/api/v2/dashboards/}.json" ;;
  *) return 1 ;;
  esac
}

PASS=0
FAIL=0
SKIP=0
LAST=""
report_pass() {
  PASS=$((PASS + 1))
  LAST="PASS $1"
}
report_fail() {
  FAIL=$((FAIL + 1))
  LAST="FAIL $1"
}
report_skip() {
  SKIP=$((SKIP + 1))
  LAST="SKIP $1"
}
record_fail() { :; }

passed=0
failed=0

# expect <name> <verdict: PASS|FAIL|SKIP> <needle> [dashboards_dir]
expect() {
  local name="$1" verdict="$2" needle="$3" dir="${4:-$FIXTURES/files}"
  PASS=0 FAIL=0 SKIP=0 LAST=""
  systemnix_signoz_dashboards_drift "$dir" fixture_get >/dev/null 2>&1
  # PASS, FAIL and SKIP counters joined: one verdict of the wanted kind, no other.
  local want
  case "$verdict" in
  PASS) want="100" ;;
  FAIL) want="010" ;;
  SKIP) want="001" ;;
  esac
  if [ "$PASS$FAIL$SKIP" = "$want" ] && grep -qF -- "$needle" <<<"$LAST"; then
    passed=$((passed + 1))
    echo "ok   $name"
  else
    failed=$((failed + 1))
    echo "FAIL $name: wanted one $verdict mentioning '$needle', got [$LAST] (PASS=$PASS FAIL=$FAIL SKIP=$SKIP)"
  fi
}

# dashboard_file <dir> <slug> <panel-title>: what the deploy ships.
dashboard_file() {
  jq -n --arg slug "$2" --arg title "$3" '{name: $slug, tags: [{key: "owner", value: "systemnix"}], spec: {display: {name: $title}, panels: {}, layouts: [], duration: "3h", refreshInterval: "", links: []}}' >"$1/$2.json"
}

# dashboard_live <id> <slug> <title>: the API's answer for one dashboard,
# its keys in another order than the file's (the server sorts nothing for us).
dashboard_live() {
  jq -n --arg id "$1" --arg slug "$2" --arg title "$3" '{status: "success", data: {id: $id, name: $slug, createdAt: "2026-11-01T00:00:00Z", updatedAt: "2026-11-02T00:00:00Z", spec: {links: [], refreshInterval: "", duration: "3h", layouts: [], panels: {}, display: {name: $title}}, tags: [{value: "systemnix", key: "owner"}]}}' >"$FIXTURES/live$1.json"
}

dashboard_list() {
  jq -n --argjson entries "$1" '{data: {dashboards: $entries}}' >"$FIXTURES/list.json"
}

# ---- three files: one identical, one edited by hand, one not served ----
mkdir -p "$FIXTURES/files"
dashboard_file "$FIXTURES/files" systemnix-one "One"
dashboard_file "$FIXTURES/files" systemnix-two "Two"
dashboard_file "$FIXTURES/files" systemnix-three "Three"
dashboard_live id-1 systemnix-one "One"
dashboard_live id-3 systemnix-three "Three, edited by hand"
dashboard_list '[{"id": "id-3", "name": "systemnix-three"}, {"id": "id-1", "name": "systemnix-one"}]'
expect "not served" FAIL "systemnix-two(not provisioned)"
expect "edited names the dashboard" FAIL " systemnix-three "

# ---- identical: the third is served again, the second is restored ----
dashboard_live id-2 systemnix-two "Two"
dashboard_live id-3 systemnix-three "Three"
dashboard_list '[{"id": "id-3", "name": "systemnix-three"}, {"id": "id-2", "name": "systemnix-two"}, {"id": "id-1", "name": "systemnix-one"}]'
expect "identical, key order aside" PASS "3 of 3 live dashboards equal their files"

# ---- a file without a slug ----
printf '{"tags": [], "spec": {"display": {"name": "No slug"}}}\n' >"$FIXTURES/files/systemnix-broken.json"
expect "no slug" FAIL "systemnix-broken.json(no slug)"
rm "$FIXTURES/files/systemnix-broken.json"

# ---- the API answers nothing, or with an error: a SKIP, never a FAIL ----
mv "$FIXTURES/list.json" "$FIXTURES/list.kept"
expect "api silent" SKIP "API did not answer"
printf '{"status": "error", "error": "unauthorized"}\n' >"$FIXTURES/list.json"
expect "api answers an error" SKIP "API did not answer"
# ---- the API serves no dashboard at all while files exist: a FAIL ----
dashboard_list '[]'
expect "nothing served" FAIL "systemnix-one(not provisioned)"
mv "$FIXTURES/list.kept" "$FIXTURES/list.json"

# ---- no dashboard files at all ----
expect "no files" SKIP "no dashboard files" "$FIXTURES/none"

# ---- wiring pin ----
if grep -q 'lib/signoz-dashboards-drift.sh' "$checker" && grep -q 'systemnix_signoz_dashboards_drift' "$checker"; then
  passed=$((passed + 1))
  echo "ok   post-deploy-check.sh sources the library and calls it"
else
  failed=$((failed + 1))
  echo "FAIL post-deploy-check.sh no longer sources scripts/lib/signoz-dashboards-drift.sh or calls systemnix_signoz_dashboards_drift"
fi

echo "post-deploy signoz dashboards selftest: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
