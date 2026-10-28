#!/usr/bin/env bash
# test-nix-admission-gate.sh — fixture selftest (stability plan F17).
# Covers: trip-recent refusal (both state sources), PSI-band refusal,
# calm passthrough, force escape (audit-logged), ungated subcommand
# passthrough, flake-check gating, and the no-real-nix fail-closed path.
# The REAL nix is stubbed with an echo so the test never builds anything.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/nix-admission-gate.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

fail() { echo "test-nix-admission-gate: FAIL: $*" >&2; exit 1; }

mkdir -p "$scratch/bin"
printf '#!/usr/bin/env bash\necho "REALNIX $*"\n' > "$scratch/bin/nix"
chmod +x "$scratch/bin/nix"

PROM="$scratch/guard.prom"
IOF="$scratch/io"
MEMF="$scratch/mem"
LASTTRIP="$scratch/last-trip"

# state setter: prom-line io_avg10 mem_avg10
state() {
  printf '%s\n' "$1" > "$PROM"
  printf 'some avg10=%s avg60=0.00 total=0\n' "$2" > "$IOF"
  printf 'some avg10=%s avg60=0.00 total=0\n' "$3" > "$MEMF"
}

# gate <force(0|1)> <args...> — runs the script against the current state
gate() {
  local force="$1"
  shift
  REAL_NIX="$scratch/bin/nix" \
    GUARD_PROM="$PROM" \
    PSI_IO_SRC="$IOF" \
    PSI_MEM_SRC="$MEMF" \
    AUDIT_LOG="$scratch/audit.log" \
    LAST_TRIP_SRC="$LASTTRIP" \
    ADMISSION_GATE_FORCE="$force" \
    bash "$script" "$@"
}

CALM='memory_emergency_guard_last_trip_recent 0'
TRIPPED='memory_emergency_guard_last_trip_recent 1'
: > "$scratch/audit.log"

# 1. Calm: gated subcommand passes through to the real nix.
state "$CALM" 2.5 1.0
out=$(gate 0 build .#foo 2>/dev/null) || fail "calm build refused: $out"
echo "$out" | rg -q 'REALNIX build .#foo' || fail "calm passthrough wrong: $out"

# 2. Trip-recent (metric source): refused with the condition named.
state "$TRIPPED" 2.5 1.0
if gate 0 build .#foo >/dev/null 2>"$scratch/err"; then
  fail "trip-recent build must refuse"
fi
rg -q 'guard tripped within' "$scratch/err" || fail "refusal must name the trip condition"

# 3. PSI band (io axis): refused.
state "$CALM" 35.0 1.0
gate 0 shell nixpkgs#foo >/dev/null 2>&1 && fail "io PSI band must refuse"

# 4. PSI band (memory axis): refused.
state "$CALM" 1.0 44.0
gate 0 develop >/dev/null 2>&1 && fail "memory PSI band must refuse"

# 5. flake check gated as a unit; nix eval passes free.
state "$CALM" 35.0 1.0
gate 0 flake check --no-build >/dev/null 2>&1 && fail "flake check under PSI band must refuse"
out=$(gate 0 eval .#foo 2>/dev/null) || fail "nix eval must pass free under band"
echo "$out" | rg -q 'REALNIX eval' || fail "eval passthrough wrong: $out"

# 6. Ungated subcommand passes even mid-storm (fmt stays possible).
state "$TRIPPED" 90.0 90.0
out=$(gate 0 fmt 2>/dev/null) || fail "ungated subcommand must pass during storm"
echo "$out" | rg -q 'REALNIX fmt' || fail "fmt passthrough wrong: $out"

# 7. Force escape: passes AND is audit-logged.
state "$TRIPPED" 55.0 1.0
out=$(gate 1 build .#foo 2>/dev/null) || fail "force must pass"
echo "$out" | rg -q 'REALNIX build' || fail "force passthrough wrong"
rg -q 'FORCED sub=build' "$scratch/audit.log" || fail "force must be audit-logged"

# 8. Refusals are audit-logged; the log carries no argv beyond the subcommand.
rg -q 'REFUSED sub=build' "$scratch/audit.log" || fail "refusal must be audit-logged"
if rg -q '#foo' "$scratch/audit.log"; then fail "audit log must not carry argv (secrets ride argv)"; fi

# 9. Fail-closed when the real nix cannot be resolved.
state "$CALM" 2.0 1.0
REAL_NIX=/nonexistent/nix GUARD_PROM="$PROM" PSI_IO_SRC="$IOF" PSI_MEM_SRC="$MEMF" \
  bash "$script" build >/dev/null 2>&1 && fail "unresolvable REAL_NIX must exit non-zero"

# 10. Trip-recent via the LAST-TRIP EPOCH source (metric calm, file 60s old).
state "$CALM" 2.0 1.0
now=$(date +%s)
echo $((now - 60)) > "$LASTTRIP"
gate 0 build >/dev/null 2>&1 && fail "fresh last-trip epoch must refuse even when the metric says calm"
rm -f "$LASTTRIP"

echo "test-nix-admission-gate: PASS (refusals, bands, passthroughs, force+audit, fail-closed)"
