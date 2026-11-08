#!/usr/bin/env bash
# Regression fixtures for the pool-smart-metrics collector (the script body
# of systemd.services.pool-smart-metrics in modules/nixos/services/
# pool-smart-metrics.nix). The original harness lived in /tmp on
# 2026-09-12 and died with the tmpfs (the /tmp-volatility class); this
# promotes the four cases into the repo:
#
#   healthy        both drives PASSED, zero counters, cool temps, clean prom
#   mutated        run-1 baseline state, run-2 counters grow →
#                  media_flag/media_increased/gsense_increased/temp_over,
#                  FAILED health flips health_ok + all_healthy
#   unprivileged   smartctl answers with an empty attribute table → the
#                  fail-closed branch (scrape_errors 1, all_healthy 0)
#   absent-drive   device missing → present 0; ALL absent leaves
#                  all_healthy untouched (the whole-DAS contract: the Pool
#                  Mounted check owns that outage)
#
# The collector body is EXTRACTED from the staged module copy (the same
# file the system builds from, never a hand-copied twin): the Nix
# indented-string escapes are unescaped and the three Nix interpolations
# (textfileDir, tempThresholdCelsius, drives list) are substituted with
# fixture seams. smartctl rides PATH as a stub.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="${1:-$here/../modules/nixos/services/pool-smart-metrics.nix}"

PASS_CNT=0
FAIL_CNT=0
ok() { PASS_CNT=$((PASS_CNT + 1)); }
bad() {
  echo "FAIL: $1" >&2
  FAIL_CNT=$((FAIL_CNT + 1))
}
assert_metric() { # assert_metric <desc> <prom-file> <metric-line-regex>
  if grep -qE "$3" "$2" 2>/dev/null; then ok; else bad "$1: /$3/ not found in $(basename "$2")"; fi
}
assert_absent() { # assert_absent <desc> <prom-file> <metric-line-regex>
  if grep -qE "$3" "$2" 2>/dev/null; then bad "$1: /$3/ unexpectedly present in $(basename "$2")"; else ok; fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Extract + render the collector body from the module ──────────────────
if [ ! -r "$MODULE" ]; then
  bad "module not readable at $MODULE"
  echo "pool-smart collector fixtures: $PASS_CNT passed, $FAIL_CNT failed"
  exit 1
fi
start="$(grep -n "script = ''$" "$MODULE" | head -1 | cut -d: -f1)"
if [ -z "$start" ]; then
  bad "script body start marker not found in module"
  echo "pool-smart collector fixtures: $PASS_CNT passed, $FAIL_CNT failed"
  exit 1
fi
end="$(tail -n +"$((start + 1))" "$MODULE" | grep -n -m1 "^ *'';$" | cut -d: -f1)"
if [ -z "$end" ]; then
  bad "script body end marker ('';) not found in module"
  echo "pool-smart collector fixtures: $PASS_CNT passed, $FAIL_CNT failed"
  exit 1
fi
end=$((start + end))
sed -n "$((start + 1)),$((end - 1))p" "$MODULE" >"$WORK/body.raw"

# Unescape the Nix indented-string forms: ''${ → ${ first, then '' → '.
cat >"$WORK/unescape.sed" <<'SED'
s/''\${/${/g
s/''/'/g
SED
sed -f "$WORK/unescape.sed" "$WORK/body.raw" >"$WORK/body.bash"

render_case() { # render_case <out.sh> <devroot> <textfile-dir>
  sed -e "s|\${textfileDir}|$3|g" \
    -e 's|${toString cfg.tempThresholdCelsius}|50|g' \
    -e "s|\${lib.escapeShellArgs cfg.drives}|\"$2/disk/by-id/ata-TOSHIBA_MG08ACA16TE_Z61BAAKS\" \"$2/disk/by-id/ata-TOSHIBA_MG08ACA16TE_Z61BAB2M\"|g" \
    "$WORK/body.bash" >"$1"
  bash -n "$1" || bad "rendered collector fails bash -n"
}

# ── Stub smartctl + fixture drive world ──────────────────────────────────
DEVS="$WORK/devs"
mkdir -p "$DEVS/disk/by-id" "$WORK/bin"
D1="$DEVS/disk/by-id/ata-TOSHIBA_MG08ACA16TE_Z61BAAKS"
D2="$DEVS/disk/by-id/ata-TOSHIBA_MG08ACA16TE_Z61BAB2M"
attr_table() { # attr_table <realloc> <gsense> <temp> — real smartctl -A shape
  cat <<EOF
smartctl 7.4 (build 5210)
Serial Number: SERIALPLACE
  9 Power_On_Hours          0x0012  100  100  000    Old_age Always   -       42114
  5 Reallocated_Sector_Ct   0x0033  100  100  010    Pre-fail Always   -       $1
191 G-Sense_Error_Rate      0x0022  100  100  000    Old_age Always   -       $2
194 Temperature_Celsius     0x0022  067  050  000    Old_age Always   -       $3/61
196 Reallocated_Event_Count 0x0032  100  100  016    Old_age Always   -       0
197 Current_Pending_Sector  0x0022  100  100  000    Old_age Always   -       0
198 Offline_Uncorrectable   0x0008  100  100  000    Old_age Offline  -       0
199 UDMA_CRC_Error_Count    0x000a  100  100  000    Old_age Always   -       0
220 Disk_Shift              0x0000  100  100  000    Old_age Always   -       0
EOF
}
REAL_BASH="$(command -v bash)"
cat >"$WORK/bin/smartctl" <<EOF
#!$REAL_BASH
# smartctl stub: per-drive fixture files answer -H/-A; a .smartfail marker
# (or a missing drive) simulates the unprivileged/bridge-swallowed shape.
mode="\$3"
dev="\$4"
if [ -f "\$dev.smartfail" ]; then
  exit 1
fi
case "\$mode" in
-H)
  if [ -f "\$dev.healthfail" ]; then
    echo "SMART Health Status: FAILED!"
  else
    echo "SMART Health Status: OK"
    echo "PASSED"
  fi
  ;;
-A)
  cat "\$dev.attr" 2>/dev/null
  ;;
esac
exit 0
EOF
chmod +x "$WORK/bin/smartctl"
reset_fixtures() { # healthy two-drive world
  rm -f "$D1" "$D2" "$D1".smartfail "$D2".smartfail "$D1".healthfail "$D2".healthfail
  : >"$D1"
  : >"$D2"
  attr_table 0 0 30 >"$D1.attr"
  attr_table 0 0 32 >"$D2.attr"
}

run_collector() { # run_collector <rendered-script> <state-dir> <textfile-dir>
  mkdir -p "$2" "$3"
  PATH="$WORK/bin:$PATH" STATE_DIRECTORY="$2" bash "$1" >/dev/null 2>"$WORK/stderr"
}

# ── Case 1: healthy ──────────────────────────────────────────────────────
reset_fixtures
render_case "$WORK/case-healthy.sh" "$DEVS" "$WORK/textfile-healthy"
run_collector "$WORK/case-healthy.sh" "$WORK/state-healthy" "$WORK/textfile-healthy"
PROM="$WORK/textfile-healthy/pool-smart.prom"
assert_metric "healthy: publish name" "$PROM" '^pool_smart_drives_present 2$'
assert_metric "healthy: all_healthy 1" "$PROM" '^pool_smart_all_healthy 1$'
assert_metric "healthy: scrape_errors 0" "$PROM" '^pool_smart_scrape_errors 0$'
assert_metric "healthy: media_flag 0" "$PROM" '^pool_smart_media_flag 0$'
assert_metric "healthy: media_increased 0" "$PROM" '^pool_smart_media_increased 0$'
assert_metric "healthy: gsense_increased 0" "$PROM" '^pool_smart_gsense_increased 0$'
assert_metric "healthy: temp_over 0" "$PROM" '^pool_smart_temp_over 0$'
assert_metric "healthy: per-drive present" "$PROM" '^pool_smart_present\{serial="Z61BAAKS"\} 1$'
assert_metric "healthy: temperature" "$PROM" '^pool_smart_temperature_celsius\{serial="Z61BAB2M"\} 32$'
assert_metric "healthy: attribute raw" "$PROM" '^pool_smart_attribute_raw\{serial="Z61BAAKS",attr="gsense"\} 0$'
assert_metric "healthy: state written" "$WORK/state-healthy/state" '^Z61BAAKS reallocated 0$'

# ── Case 2: mutated (rides run-1 state) ─────────────────────────────────
# Run 1 re-baselines a CLEAN world for D1; D2 keeps run-1 state from the
# healthy case? No — clean slate: run 1 healthy, run 2 mutates.
rm -rf "$WORK/state-mutated"
mkdir -p "$WORK/state-mutated" "$WORK/textfile-mutated"
reset_fixtures
render_case "$WORK/case-mutated.sh" "$DEVS" "$WORK/textfile-mutated"
run_collector "$WORK/case-mutated.sh" "$WORK/state-mutated" "$WORK/textfile-mutated"
assert_metric "mutated run1: media_increased 0" "$WORK/textfile-mutated/pool-smart.prom" '^pool_smart_media_increased 0$'
# Run 2: reallocated grows, gsense grows, temp over threshold, D2 health FAILS.
attr_table 4 1 55 >"$D1.attr"
: >"$D2.healthfail"
run_collector "$WORK/case-mutated.sh" "$WORK/state-mutated" "$WORK/textfile-mutated"
PROM="$WORK/textfile-mutated/pool-smart.prom"
assert_metric "mutated: media_flag 1" "$PROM" '^pool_smart_media_flag 1$'
assert_metric "mutated: media_increased 1" "$PROM" '^pool_smart_media_increased 1$'
assert_metric "mutated: gsense_increased 1" "$PROM" '^pool_smart_gsense_increased 1$'
assert_metric "mutated: temp_over 1" "$PROM" '^pool_smart_temp_over 1$'
assert_metric "mutated: FAILED health flips health_ok" "$PROM" '^pool_smart_health_ok\{serial="Z61BAB2M"\} 0$'
assert_metric "mutated: all_healthy 0" "$PROM" '^pool_smart_all_healthy 0$'
assert_metric "mutated: grown counter state" "$WORK/state-mutated/state" '^Z61BAAKS reallocated 4$'

# ── Case 3: unprivileged (bridge swallows the attribute table) ──────────
reset_fixtures
: >"$D1.smartfail"
render_case "$WORK/case-unpriv.sh" "$DEVS" "$WORK/textfile-unpriv"
run_collector "$WORK/case-unpriv.sh" "$WORK/state-unpriv" "$WORK/textfile-unpriv"
PROM="$WORK/textfile-unpriv/pool-smart.prom"
assert_metric "unprivileged: scrape_errors 1" "$PROM" '^pool_smart_scrape_errors 1$'
assert_metric "unprivileged: all_healthy 0" "$PROM" '^pool_smart_all_healthy 0$'
assert_metric "unprivileged: healthy sibling untouched" "$PROM" '^pool_smart_health_ok\{serial="Z61BAB2M"\} 1$'

# ── Case 4: absent drive / whole-DAS outage ─────────────────────────────
render_case "$WORK/case-absent.sh" "$DEVS" "$WORK/textfile-absent"
# One absent: counted out, sibling still scored.
reset_fixtures
rm -f "$D1"
run_collector "$WORK/case-absent.sh" "$WORK/state-absent" "$WORK/textfile-absent"
PROM="$WORK/textfile-absent/pool-smart.prom"
assert_metric "absent: one drive counts" "$PROM" '^pool_smart_drives_present 1$'
assert_metric "absent: missing drive present 0" "$PROM" '^pool_smart_present\{serial="Z61BAAKS"\} 0$'
assert_metric "absent: sibling still healthy" "$PROM" '^pool_smart_all_healthy 1$'
# ALL absent: all_healthy stays untouched at 1 (Pool Mounted owns the outage).
rm -f "$D2" "$D2.attr"
run_collector "$WORK/case-absent.sh" "$WORK/state-absent" "$WORK/textfile-absent"
PROM="$WORK/textfile-absent/pool-smart.prom"
assert_metric "whole-DAS: drives_present 0" "$PROM" '^pool_smart_drives_present 0$'
assert_metric "whole-DAS: all_healthy untouched at 1" "$PROM" '^pool_smart_all_healthy 1$'

echo "pool-smart collector fixtures: $PASS_CNT passed, $FAIL_CNT failed"
if [ "$FAIL_CNT" -gt 0 ]; then exit 1; fi
exit 0
