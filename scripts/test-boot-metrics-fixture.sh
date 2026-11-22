#!/usr/bin/env bash
# Fixture for the boot-metrics-emit transaction_open OPEN path (2026-10-17
# TODO row: the gauge's entire purpose is the mid-refusal emission, but only
# the closed path was ever live-verified). Runs the REAL rendered unit script
# against a stubbed systemd-analyze/systemctl in a scratch textfile dir —
# never touches /var/lib or the live host.
#
# Usage (heavy-eval opt-in; CI runs it via checks.bootmetrics-openpath-selftest
# which renders the script through Nix):
#   SCRIPT_PATH=<rendered boot-metrics-emit script> bash scripts/test-boot-metrics-fixture.sh
#   CASES=bootmetrics bash scripts/negative-test-lints.sh   # same, via eval
#
# Legs:
#   1. open  — refusing stub → transaction_open 1 + positive age, scrape_errors 0
#   2. closed — answering stub → transaction_open 0 + age 0 + phase/total metrics
#   3. control — open_age_secs definition stripped (the 2026-10-18 127 class) →
#      refusing stub kills the script and NO textfile lands (regression proof)
set -euo pipefail

SCRIPT="${SCRIPT_PATH:?SCRIPT_PATH=<rendered boot-metrics-emit script> required}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUB="$WORK/stub"
mkdir -p "$STUB"

# Shebang resolved to the RUNNING bash: the nix build sandbox has no
# /usr/bin/env, so a literal env shebang dies silently (empty stub output
# read as a converged transaction). The fixture script itself must likewise
# be invoked by an absolute bash (checks pass ${pkgs.bash}/bin/bash).
BASH_BIN="$(command -v bash)"

{ printf '#!%s\n' "$BASH_BIN"; cat <<'STUBEOF'
if [ "${STUB_BOOT_STATE:-open}" = open ]; then
  echo "Bootup is not yet finished (org.freedesktop.systemd1.Manager.Finished not signaled)" >&2
  exit 1
fi
echo "Startup finished in 1.000s (firmware) + 1.000s (loader) + 1.000s (kernel) + 1.000s (initrd) + 2.500s (userspace) = 6.500s"
STUBEOF
} >"$STUB/systemd-analyze"
chmod +x "$STUB/systemd-analyze"

{ printf '#!%s\n' "$BASH_BIN"; cat <<'STUBEOF'
if [ "${1:-}" = show ] && [ "${2:-}" = graphical.target ]; then
  echo "ActiveEnterTimestampMonotonic=123000000"
  exit 0
fi
echo "stub: unexpected systemctl call: $*" >&2
exit 64
STUBEOF
} >"$STUB/systemctl"
chmod +x "$STUB/systemctl"

run_variant() {
  # $1 = variant name; $2 = extra sed program (optional)
  local variant="$1" extra="${2:-}"
  local dir="$WORK/$variant"
  mkdir -p "$dir/collectors"
  sed -e 's|/nix/store/[a-z0-9]*-systemd[^/ ]*/bin/systemd-analyze|'"$STUB"'/systemd-analyze|g' \
    -e 's|/var/lib/prometheus-node-exporter/textfile_collectors|'"$dir/collectors"'|g' \
    -e 's|/proc/uptime|'"$dir/uptime"'|g' \
    ${extra:+-e "$extra"} \
    "$SCRIPT" >"$dir/emit.sh"
  chmod +x "$dir/emit.sh"
  printf '1000.40 12345\n' >"$dir/uptime"
  set +e
  PATH="$STUB:$PATH" STUB_BOOT_STATE="${STUB_BOOT_STATE:-open}" \
    bash "$dir/emit.sh" >"$dir/stdout.log" 2>"$dir/stderr.log"
  printf '%s\n' "$?" >"$dir/rc"
  set -e
}

fail() {
  echo "FAIL [bootmetrics]: $1" >&2
  if [ -n "${BOOTMETRICS_DEBUG:-}" ] && [ -f "$WORK/open/collectors/boot-metrics.prom" ]; then
    echo "--- open prom ---" >&2
    cat "$WORK/open/collectors/boot-metrics.prom" >&2
    echo "--- open stderr ---" >&2
    cat "$WORK/open/stderr.log" >&2
    echo "--- emit.sh probe line ---" >&2
    grep -n "systemd-analyze" "$WORK/open/emit.sh" | head -3 >&2
  fi
  exit 1
}

# ── Leg 1: OPEN path (systemd-analyze refuses) ──
STUB_BOOT_STATE=open run_variant open
prom="$WORK/open/collectors/boot-metrics.prom"
[ -f "$prom" ] || fail "open variant wrote no boot-metrics.prom"
grep -q '^transaction_open 1$' "$prom" || fail "open variant: transaction_open 1 missing"
grep -Eq '^transaction_open_seconds_past_graphical [0-9]+$' "$prom" \
  || fail "open variant: age gauge missing/non-numeric"
grep -q '^transaction_open_seconds_past_graphical 877$' "$prom" \
  || fail "open variant: age math wrong (uptime 1000.40 - monotonic 123s = 877)"
grep -q '^boot_metrics_scrape_errors 0$' "$prom" \
  || fail "open variant: refusal misclassified as scrape error"
grep -q "boot transaction still open" "$WORK/open/stderr.log" \
  || fail "open variant: refusal log line missing"

# ── Leg 2: CLOSED path (systemd-analyze answers) ──
STUB_BOOT_STATE=closed run_variant closed
prom="$WORK/closed/collectors/boot-metrics.prom"
[ -f "$prom" ] || fail "closed variant wrote no boot-metrics.prom"
grep -q '^transaction_open 0$' "$prom" || fail "closed variant: transaction_open 0 missing"
grep -q '^transaction_open_seconds_past_graphical 0$' "$prom" \
  || fail "closed variant: age must be 0 once finished"
grep -q '^boot_phase_duration_seconds{phase="userspace"} 2.500$' "$prom" \
  || fail "closed variant: userspace phase metric missing/misparsed"
grep -q '^boot_total_duration_seconds 6.500$' "$prom" \
  || fail "closed variant: total duration missing/misparsed"

# ── Leg 3: CONTROL — open_age_secs stripped (the 2026-10-18 127 class) ──
STUB_BOOT_STATE=open run_variant control \
  '/^open_age_secs() [{]$/,/^}$/d'
grep -qve '^0$' "$WORK/control/rc" \
  || fail "control: stripped variant ran clean (rc=$(<"$WORK/control/rc")) — regression net is gone"
[ ! -f "$WORK/control/collectors/boot-metrics.prom" ] \
  || fail "control: stripped variant still wrote a textfile (the 127-class kill did not fire)"

echo "PASS [bootmetrics]: open-path, closed-path, and 127-control legs green"
