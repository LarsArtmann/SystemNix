#!/usr/bin/env bash
# Fixture tests for the shadow-split deploy gate (pre-deploy §18).
#
# The gate runs the same code fixtures and production execute — the lib is
# NOT sourced here because the gate is a standalone script (§15 pattern):
# these fixtures invoke scripts/shadow-split-gate.sh itself and assert its
# verdict stream + exit codes. The wave-6 signature (empty subvol over a
# non-empty data shadow) MUST fail; every degradation path (unreadable
# probes, missing subvol, absent hot root) must WARN, never fail — the
# gate's authority comes from provable signatures, not from suspicion.
#
# Fixtures prove each branch:
#   fresh shadow absent                 -> PASS, rc 0
#   fresh shadow empty dir              -> PASS, rc 0
#   data empty subvol over live shadow  -> FAIL (wave-6 signature), rc 1
#   cache empty subvol over live shadow -> WARN only, rc 0
#   prepared copy >= 25% of shadow      -> PASS, rc 0
#   PG_VERSION missing in subvol        -> FAIL, rc 1
#   PG_VERSION present both sides       -> PASS, rc 0
#   subvol < 25% of shadow              -> WARN, rc 0
#   subvol dir missing                  -> WARN, rc 0
#   projects (STRICT) missing subvol    -> FAIL, rc 1 (nofail mount: §18 is
#                                          the only pre-switch protection)
#   projects empty subvol over shadow   -> FAIL (wave-6 signature), rc 1
#   projects prepared copy / parity     -> PASS rc 0 / WARN rc 0
#   shadow unreadable (EACCES)          -> WARN, rc 0
#   no entries at all                   -> PASS, rc 0
# Run: bash scripts/test-predeploy-shadow-split.sh
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GATE="$REPO_ROOT/scripts/shadow-split-gate.sh"

TEST_FAILURES=0
CASE_N=0

expect() {
  local want_desc="$1" got="$2" want="$3"
  CASE_N=$((CASE_N + 1))
  if [ "$got" = "$want" ]; then
    echo "  ok   [case $CASE_N] $want_desc"
  else
    echo "  FAIL [case $CASE_N] $want_desc (want: $want, got: $got)"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

run_case() {
  # $1 label · $2 shadow-prep command · $3 subvol-prep command · $4 entry JSON
  local label="$1" shadow_prep="$2" subvol_prep="$3" json="$4"
  local tmp out rc
  tmp=$(mktemp -d)
  mkdir -p "$tmp/shadow" "$tmp/hot"
  (cd "$tmp" && eval "$shadow_prep") || {
    echo "  FAIL [setup] $label: shadow prep failed"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    rm -rf "$tmp"
    return 0
  }
  (cd "$tmp" && eval "$subvol_prep") || {
    echo "  FAIL [setup] $label: subvol prep failed"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    rm -rf "$tmp"
    return 0
  }
  out=$(SS_PRIV="" SS_SHADOW_ROOT="$tmp/shadow" SS_HOT_ROOT="$tmp/hot" \
    SS_ENTRIES_JSON="$json" bash "$GATE" 2>&1)
  rc=$?
  printf '%s\n' "$out" | sed 's/^/       /' | sed -n '1,12p'
  chmod -R u+rwX "$tmp" 2>/dev/null || true
  rm -rf "$tmp"
  VerdictRC="$rc"
  VerdictOut="$out"
}

JSON_DATA_EMPTY='{"ucEnable":true,"uc":[],"hdbEnable":true,"hdb":{"mydb":{"path":"/srv/mydb","cow":false,"unit":"mydb.service"}}}'
JSON_CACHE_EMPTY='{"ucEnable":true,"uc":{"x":{"subvol":"users/t/cache/x","mountPoint":"/srv/x"}},"hdbEnable":false,"hdb":{}}'
JSON_PREPARED='{"ucEnable":false,"uc":[],"hdbEnable":true,"hdb":{"pg":{"path":"/var/lib/postgresql","cow":false,"unit":"postgresql.service"}}}'
JSON_NODATA='{"ucEnable":false,"uc":[],"hdbEnable":false,"hdb":{}}'
JSON_PROJECTS='{"ucEnable":false,"uc":[],"hdbEnable":false,"hdb":{},"projectsMount":true}'

echo "shadow-split gate fixtures"

# 1. fresh: shadow absent entirely
run_case "fresh shadow absent" "true" "true" "$JSON_DATA_EMPTY"
expect "rc 0 (pass)" "$VerdictRC" "0"

# 2. fresh: shadow exists but empty
run_case "fresh shadow empty dir" "mkdir -p shadow/srv" "true" "$JSON_DATA_EMPTY"
expect "rc 0 (pass)" "$VerdictRC" "0"

# 3. wave-6 signature: data class, empty subvol over non-empty shadow
run_case "data empty subvol FAIL" \
  "mkdir -p shadow/srv/mydb && dd if=/dev/zero of=shadow/srv/mydb/base bs=1k count=10 2>/dev/null" \
  "mkdir -p hot/hot/mydb" \
  "$JSON_DATA_EMPTY"
expect "rc 1 (fail)" "$VerdictRC" "1"
expect "FAIL verdict emitted" "$(printf '%s' "$VerdictOut" | grep -c '^FAIL:' || true)" "1"
expect "wave-6 named in verdict" "$(printf '%s' "$VerdictOut" | grep -c 'WAVE-6 SIGNATURE' || true)" "1"

# 4. cache class empty subvol: WARN not FAIL
run_case "cache empty subvol WARN" \
  "mkdir -p shadow/srv/x && printf data > shadow/srv/x/f1" \
  "mkdir -p hot/users/t/cache/x" \
  "$JSON_CACHE_EMPTY"
expect "rc 0 (warn-only)" "$VerdictRC" "0"
expect "WARN verdict emitted" "$(printf '%s' "$VerdictOut" | grep -c '^WARN:' || true)" "1"

# 5. prepared copy: subvol >= 25% of shadow
run_case "prepared copy PASS" \
  "mkdir -p shadow/varlib/17 && dd if=/dev/zero of=shadow/varlib/17/base bs=1k count=100 2>/dev/null" \
  "mkdir -p hot/pg/17 && dd if=/dev/zero of=hot/pg/17/base bs=1k count=50 2>/dev/null" \
  "$JSON_PREPARED"
expect "rc 0 (pass)" "$VerdictRC" "0"

# 6. PG_VERSION in shadow, absent in subvol -> FAIL even when subvol non-empty
run_case "PG_VERSION missing FAIL" \
  "mkdir -p shadow/var/lib/postgresql/17 && dd if=/dev/zero of=shadow/var/lib/postgresql/17/base bs=1k count=100 2>/dev/null && printf '15' > shadow/var/lib/postgresql/PG_VERSION" \
  "mkdir -p hot/hot/pg/17 && dd if=/dev/zero of=hot/hot/pg/17/base bs=1k count=50 2>/dev/null" \
  "$JSON_PREPARED"
expect "rc 1 (fail)" "$VerdictRC" "1"
expect "PG_VERSION verdict" "$(printf '%s' "$VerdictOut" | grep -c 'PG_VERSION' || true)" "1"

# 7. PG_VERSION both sides -> PASS
run_case "PG_VERSION both PASS" \
  "mkdir -p shadow/var/lib/postgresql/17 && dd if=/dev/zero of=shadow/var/lib/postgresql/17/base bs=1k count=100 2>/dev/null && printf '15' > shadow/var/lib/postgresql/PG_VERSION" \
  "mkdir -p hot/hot/pg/17 && dd if=/dev/zero of=hot/hot/pg/17/base bs=1k count=50 2>/dev/null && printf '15' > hot/hot/pg/PG_VERSION" \
  "$JSON_PREPARED"
expect "rc 0 (pass)" "$VerdictRC" "0"

# 8. parity band: subvol far smaller than shadow -> WARN
run_case "parity gross mismatch WARN" \
  "mkdir -p shadow/var/lib/postgresql/17 && dd if=/dev/zero of=shadow/var/lib/postgresql/17/base bs=1k count=1000 2>/dev/null" \
  "mkdir -p hot/hot/pg/17 && dd if=/dev/zero of=hot/hot/pg/17/base bs=1k count=10 2>/dev/null" \
  "$JSON_PREPARED"
expect "rc 0 (warn-only)" "$VerdictRC" "0"
expect "parity WARN emitted" "$(printf '%s' "$VerdictOut" | grep -c '<25% of shadow' || true)" "1"

# 9. subvol dir missing -> WARN (mount fails fast+loud, half-provisioned)
run_case "subvol missing WARN" \
  "mkdir -p shadow/srv/mydb && dd if=/dev/zero of=shadow/srv/mydb/base bs=1k count=10 2>/dev/null" \
  "true" \
  "$JSON_DATA_EMPTY"
expect "rc 0 (warn-only)" "$VerdictRC" "0"
expect "missing-subvol WARN emitted" "$(printf '%s' "$VerdictOut" | grep -c 'MISSING' || true)" "1"

# 10. shadow unreadable -> degraded WARN, never fail
run_case "shadow unreadable WARN" \
  "mkdir -p shadow/srv/mydb && dd if=/dev/zero of=shadow/srv/mydb/base bs=1k count=10 2>/dev/null && chmod 000 shadow/srv/mydb" \
  "mkdir -p hot/hot/mydb && dd if=/dev/zero of=hot/hot/mydb/base bs=1k count=5 2>/dev/null" \
  "$JSON_DATA_EMPTY"
expect "rc 0 (degraded warn)" "$VerdictRC" "0"
expect "unreadable WARN emitted" "$(printf '%s' "$VerdictOut" | grep -c 'unreadable' || true)" "1"

# 11. no entries at all
run_case "no entries PASS" "true" "true" "$JSON_NODATA"
expect "rc 0 (pass)" "$VerdictRC" "0"
expect "no-entry verdict" "$(printf '%s' "$VerdictOut" | grep -c 'nothing to shadow-split' || true)" "1"

# 12. projects (STRICT, nofail mount): empty subvol over populated shadow
#     -> FAIL — the wave-6 signature for the 2026-10-28 projects subvol.
run_case "projects empty subvol FAIL" \
  "mkdir -p shadow/home/lars/projects/SystemNix && printf x > shadow/home/lars/projects/SystemNix/README.md" \
  "mkdir -p hot/users/lars/projects" \
  "$JSON_PROJECTS"
expect "rc 1 (fail)" "$VerdictRC" "1"
expect "projects wave-6 FAIL" "$(printf '%s' "$VerdictOut" | grep -c 'WAVE-6 SIGNATURE' || true)" "1"

# 13. projects STRICT: subvol dir entirely missing -> FAIL (nofail mount,
#     activation will not fail — §18 is the only pre-switch protection).
run_case "projects missing subvol FAIL (strict)" \
  "mkdir -p shadow/home/lars/projects/SystemNix && printf x > shadow/home/lars/projects/SystemNix/README.md" \
  "true" \
  "$JSON_PROJECTS"
expect "rc 1 (fail)" "$VerdictRC" "1"
expect "strict missing-subvol FAIL" "$(printf '%s' "$VerdictOut" | grep -c 'STRICT entry' || true)" "1"

# 14. projects prepared copy (>= 25% of shadow) -> PASS.
run_case "projects prepared PASS" \
  "mkdir -p shadow/home/lars/projects/r && dd if=/dev/zero of=shadow/home/lars/projects/r/data bs=1k count=100 2>/dev/null" \
  "mkdir -p hot/users/lars/projects/r && dd if=/dev/zero of=hot/users/lars/projects/r/data bs=1k count=50 2>/dev/null" \
  "$JSON_PROJECTS"
expect "rc 0 (pass)" "$VerdictRC" "0"

# 15. projects parity band: subvol far smaller than shadow -> WARN only.
run_case "projects parity WARN" \
  "mkdir -p shadow/home/lars/projects/r && dd if=/dev/zero of=shadow/home/lars/projects/r/data bs=1k count=1000 2>/dev/null" \
  "mkdir -p hot/users/lars/projects/r && dd if=/dev/zero of=hot/users/lars/projects/r/data bs=1k count=10 2>/dev/null" \
  "$JSON_PROJECTS"
expect "rc 0 (warn-only)" "$VerdictRC" "0"
expect "projects parity WARN" "$(printf '%s' "$VerdictOut" | grep -c '<25% of shadow' || true)" "1"

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "❌ $TEST_FAILURES fixture assertion(s) failed"
  exit 1
fi
echo "✅ all shadow-split gate fixtures green ($CASE_N cases)"
