#!/usr/bin/env bash
# Fixture selftest for scripts/lib/integration-manifest-loader.sh (the T4.3
# standing legs). Pins the DEGRADE + DRIFT contract of the manifest bridge:
#   leg 1: absent manifest       → WARN + MANIFEST_OK=false + empty ports
#   leg 2: malformed JSON        → WARN (unparseable class)
#   leg 3: empty-ports stub      → drift WARN from m_port, rc 1
#   leg 4: real generation manifest (arg 1) → ports resolve, budget raised
# Never trust a degrade path that was only proven once live — the battery
# output changes every run; this fixture pins the CONTRACT.
set -euo pipefail

LOADER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/integration-manifest-loader.sh"
REAL_MANIFEST="${1:-}"
# Plain mktemp (TMPDIR-based): this file also runs inside the nix build
# sandbox, where HOME does not exist (homeless-shelter) — the standing
# integration-manifest-loader-selftest check executes it.
WORK="$(mktemp -d manifest-loader-selftest.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
note() { printf '%s\n' "$*"; }
ok() {
  pass=$((pass + 1))
  note "PASS: $*"
}
bad() {
  fail=$((fail + 1))
  note "FAIL: $*"
}

# fresh_shell <manifest-env> — source the loader in a clean bash with stubs,
# then OPTIONALLY evaluate an extra probe snippet; prints probed values.
fresh_shell() {
  local env_manifest="$1" probe="${2:-}"
  bash -c "
    set -euo pipefail
    report_warn() { echo \"WARN: \$*\"; }
    VHOST_PROBE_TIMEOUT=20
    export SYSTEMNIX_MANIFEST='$env_manifest'
    source '$LOADER'
    ${probe}
  " 2>&1
}

# --- leg 1: absent manifest --------------------------------------------------
out="$(fresh_shell /nonexistent-manifest-selftest 'echo "ok=$MANIFEST_OK p=$PORT_POCKET_ID"')"
grep -q "WARN: integration manifest .* absent or unparseable" <<<"$out" &&
  ok "leg1 absent manifest WARNs" || bad "leg1 no WARN on absent manifest: $out"
grep -q "ok=false p=$" <<<"$out" &&
  ok "leg1 ports degrade empty" || bad "leg1 ports not empty: $out"

# --- leg 2: malformed JSON -----------------------------------------------------
printf 'not json{' >"$WORK/malformed.json"
out="$(fresh_shell "$WORK/malformed.json" 'echo "ok=$MANIFEST_OK"')"
grep -q "WARN: integration manifest .* absent or unparseable" <<<"$out" &&
  ok "leg2 malformed JSON WARNs (unparseable class)" || bad "leg2 malformed JSON not caught: $out"

# --- leg 3: empty-ports stub → drift WARN --------------------------------------
printf '{"domain":"home.lan","ports":{},"services":{}}' >"$WORK/empty-ports.json"
out="$(fresh_shell "$WORK/empty-ports.json" 'm_port pocket-id || echo "rc=$?"')"
grep -q "WARN: manifest drift: port 'pocket-id' not in the registry" <<<"$out" &&
  ok "leg3 unknown port drift-WARNs" || bad "leg3 no drift WARN: $out"
grep -q "rc=1" <<<"$out" &&
  ok "leg3 m_port returns rc 1 on unknown name" || bad "leg3 m_port resolved an unknown name: $out"

# --- leg 4: real generation manifest ------------------------------------------
if [ -n "$REAL_MANIFEST" ] && [ -r "$REAL_MANIFEST" ]; then
  out="$(fresh_shell "$REAL_MANIFEST" 'echo "p=$PORT_POCKET_ID budget=$VHOST_PROBE_TIMEOUT m=$PORT_M365_METRICS"')"
  grep -q "p=1411" <<<"$out" &&
    ok "leg4 real manifest resolves pocket-id=1411" || bad "leg4 pocket-id wrong: $out"
  grep -q "m=9421" <<<"$out" &&
    ok "leg4 real manifest resolves monitor365-metrics=9421" || bad "leg4 monitor365-metrics wrong: $out"
  grep -qE "budget=(20|30)" <<<"$out" &&
    ok "leg4 budget stays at floor or raises (got $(grep -oE 'budget=[0-9]+' <<<"$out"))" ||
    bad "leg4 budget nonsensical: $out"
else
  note "SKIP: leg4 (no real manifest passed — pass a built integration-manifest path as arg 1)"
fi

note "=== integration-manifest-loader-selftest: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
