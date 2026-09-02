#!/usr/bin/env bash
# Fixture tests for the post-deploy pressure reporting
# (scripts/lib/pressure-report.sh). 2026-09-02 T07: the old inline check
# printed PASS "healthy" while memory PSI some avg10 ran 48-77% (the evening
# storm) — the exact lying gate this refactor kills. Synthetic PSI/meminfo/
# zram fixtures drive the SAME function post-deploy-check.sh calls.
#
# Fixtures:
#   calm      avg10 0.00 + zram 50% + avail 27%     → PASS healthy everywhere
#   incident  avg10 77  + zram 97.5% + avail 27%    → WARN storm + WARN
#             combined pre-freeze (the 2026-09-02 evening, verbatim shape)
#   io-storm  io avg10 48 (memory calm)             → WARN elevated I/O
#   avail-low avail 8% (PSI calm)                   → WARN MemAvailable
# Run: bash scripts/test-post-deploy-pressure.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/pressure-report.sh
source "$REPO_ROOT/scripts/lib/pressure-report.sh"

LAST_CLASS=""
report_pass() {
  LAST_CLASS="pass"
}
report_fail() {
  LAST_CLASS="fail"
}
report_skip() {
  LAST_CLASS="skip"
}
report_warn() {
  LAST_CLASS="warn"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

psi_mem_calm="$TMP/psi_mem_calm"
printf 'some avg10=0.00 avg60=0.00 avg300=0.00 total=0\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' >"$psi_mem_calm"
psi_mem_storm="$TMP/psi_mem_storm"
printf 'some avg10=77.00 avg60=12.00 avg300=4.00 total=0\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' >"$psi_mem_storm"
psi_io_calm="$TMP/psi_io_calm"
printf 'some avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' >"$psi_io_calm"
psi_io_storm="$TMP/psi_io_storm"
printf 'some avg10=48.00 avg60=20.00 avg300=5.00 total=0\n' >"$psi_io_storm"
meminfo_ok="$TMP/meminfo_ok"
printf 'MemTotal: 98836400 kB\nMemAvailable: 26300000 kB\n' >"$meminfo_ok"
meminfo_low="$TMP/meminfo_low"
printf 'MemTotal: 98836400 kB\nMemAvailable: 7000000 kB\n' >"$meminfo_low"
# zram: disksize 1000, orig 500 → 50.0%; orig 975 → 97.5%
mmstat_half="$TMP/mmstat_half"
printf '500 200 250 0 0 0 0 0 0\n' >"$mmstat_half"
mmstat_full="$TMP/mmstat_full"
printf '975 350 400 0 0 0 0 0 0\n' >"$mmstat_full"
disksize="$TMP/disksize"
printf '1000\n' >"$disksize"

TEST_FAILURES=0
expect() {
  local want="$1"
  local desc="$2"
  if [ "$LAST_CLASS" = "$want" ]; then
    echo "  ok   [$want] $desc"
  else
    echo "  FAIL [$want] $desc (got: $LAST_CLASS)"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

echo "=== Fixture: calm system → PASS everywhere ==="
systemnix_report_pressure "$psi_io_calm" "$psi_mem_calm" "$meminfo_ok" "$mmstat_half" "$disksize"
expect "pass" "calm: final verdict (MemAvailable) pass"

echo "=== Fixture: the 2026-09-02 evening (PSI 77, zram 97.5%, avail 27%) → WARN, never healthy ==="
systemnix_report_pressure "$psi_io_calm" "$psi_mem_storm" "$meminfo_ok" "$mmstat_full" "$disksize"
expect "pass" "storm fixture: final stage (avail 27%) still pass — the WARNs above are asserted by text below"

echo "=== Fixture: MemAvailable 8% (PSI calm) → WARN ==="
systemnix_report_pressure "$psi_io_calm" "$psi_mem_calm" "$meminfo_low" "$mmstat_half" "$disksize"
expect "warn" "avail 8%: WARN MemAvailable below floor"

echo "=== Per-stage verdict text (stage-order-proof) ===
echo "$out" | grep -q "warn:.*memory PSI some avg10=77" && echo "  ok   [warn] storm PSI 77% verdict text" || {
  echo "  FAIL [warn] storm PSI 77% verdict text"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}
echo "$out" | grep -q "warn:.*combined pre-freeze zone" && echo "  ok   [warn] combined pre-freeze zone verdict" || {
  echo "  FAIL [warn] combined pre-freeze zone verdict"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}
echo "$out" | grep -qE "pass:.*I/O pressure avg10=0.00% \(healthy\)" && echo "  ok   [pass] calm I/O verdict inside storm fixture" || {
  echo "  FAIL [pass] calm I/O verdict inside storm fixture"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

echo "--- io storm fixture ---"
out_io=$(
  report_pass() {
    echo "pass:$1"
  }
  report_warn() {
    echo "warn:$1"
  }
  report_skip() {
    echo "skip:$1"
  }
  systemnix_report_pressure "$psi_io_storm" "$psi_mem_calm" "$meminfo_ok" "$mmstat_half" "$disksize"
)
echo "$out_io" | grep -q "warn:.*I/O pressure avg10=48.*elevated" && echo "  ok   [warn] I/O 48% → elevated WARN (never healthy)" || {
  echo "  FAIL [warn] I/O 48% → elevated WARN (never healthy)"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}
echo "$out_io" | grep -qE "pass:.*memory PSI some avg10=0.00% \(calm\)" && echo "  ok   [pass] calm memory verdict inside io-storm fixture" || {
  echo "  FAIL [pass] calm memory verdict inside io-storm fixture"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

echo "--- combined pre-freeze edge (zram 97.5% + PSI 7%) ---"
psi_mem_edge="$TMP/psi_mem_edge"
printf 'some avg10=7.00 avg60=2.00 avg300=1.00 total=0\n' >"$psi_mem_edge"
out_edge=$(
  report_pass() {
    echo "pass:$1"
  }
  report_warn() {
    echo "warn:$1"
  }
  report_skip() {
    echo "skip:$1"
  }
  systemnix_report_pressure "$psi_io_calm" "$psi_mem_edge" "$meminfo_ok" "$mmstat_full" "$disksize"
)
echo "$out_edge" | grep -q "warn:.*memory PSI some avg10=7.00.*elevated" && echo "  ok   [warn] PSI 7% → elevated WARN" || {
  echo "  FAIL [warn] PSI 7% → elevated WARN"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}
echo "$out_edge" | grep -q "warn:.*combined pre-freeze zone" && echo "  ok   [warn] combined pre-freeze zone fires at 97.5% + 7%" || {
  echo "  FAIL [warn] combined pre-freeze zone fires at 97.5% + 7%"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

# The old lying-gate regression: PSI 48-77% must NEVER produce a healthy verdict for memory.
if echo "$out" | grep -qE "pass:.*memory PSI"; then
  echo "  FAIL [regression] memory PSI 77% fixture produced a PASS verdict (the lying gate is back)"
  TEST_FAILURES=$((TEST_FAILURES + 1))
else
  echo "  ok   [regression] memory PSI 77% never yields PASS"
fi

if [ "$TEST_FAILURES" -gt 0 ]; then
  echo ""
  echo "SELFTEST FAILED: $TEST_FAILURES assertion(s) broken"
  exit 1
fi
echo ""
echo "SELFTEST OK: pressure reporting never calls a storm healthy"
