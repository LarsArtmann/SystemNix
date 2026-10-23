#!/usr/bin/env bash
# test-redact-argv.sh — selftest for scripts/redact-argv.sh (house doctrine:
# repo scripts that gate safety get a negative/self test; the 2026-10-22/23
# transcript-leak class this redactor exists for must never regress silently).
#
# Pins three behaviors:
#   MUST mask:  flag-with-value (--jwt-secret X, -api-token=X, --API-Key X),
#               env-style assignment (JWT_SECRET=X)
#   MUST pass:  keyword-free argv (--config /etc/x.json, paths, ports)
#   ACCEPTED:   conservative over-mask (--max-tokens 4096 masks — documented
#               doctrine: over-masking is safe, under-masking is the incident)
#
# Usage:
#   bash scripts/test-redact-argv.sh   # exit 0 = redaction shapes hold
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REDACTOR="$REPO_ROOT/scripts/redact-argv.sh"

if [ ! -x "$REDACTOR" ]; then
  echo "SELFTEST FAIL: $REDACTOR missing or not executable"
  exit 1
fi

rc=0

must_mask() {
  local input="$1" expect_subst="$2"
  local out
  out="$(printf '%s\n' "$input" | "$REDACTOR")"
  if [ "$out" = "$expect_subst" ]; then
    echo "PASS mask: $input"
  else
    echo "FAIL mask: input '$input'"
    echo "      expected: $expect_subst"
    echo "      got:      $out"
    rc=1
  fi
}

must_contain_no() {
  # The raw secret value must NOT survive anywhere in the output line.
  local input="$1" secret="$2"
  local out
  out="$(printf '%s\n' "$input" | "$REDACTOR")"
  if printf '%s' "$out" | grep -qF "$secret"; then
    echo "FAIL leak: '$secret' survived redaction of '$input' -> '$out'"
    rc=1
  else
    echo "PASS no-leak: $input"
  fi
}

must_pass_through() {
  local input="$1"
  local out
  out="$(printf '%s\n' "$input" | "$REDACTOR")"
  if [ "$out" = "$input" ]; then
    echo "PASS untouched: $input"
  else
    echo "FAIL untouched: '$input' became '$out'"
    rc=1
  fi
}

# --- MUST mask (the two live-observed incident shapes first) ---
must_mask \
  "/nix/store/…-monitor365/bin/monitor365 serve --jwt-secret deadbeefcafe0123" \
  "/nix/store/…-monitor365/bin/monitor365 serve --jwt-secret=REDACTED"
must_mask \
  "/nix/store/…-crm/bin/crm sync -api-token ghp_abc123def456" \
  "/nix/store/…-crm/bin/crm sync -api-token=REDACTED"
must_mask \
  "app --API-Key zzz-secret-zzz" \
  "app --API-Key=REDACTED"
must_mask \
  "env JWT_SECRET=superraw env MONITOR365_TOKEN=raw2 app" \
  "env JWT_SECRET=REDACTED env MONITOR365_TOKEN=REDACTED app"
must_mask "app --password hunter2" "app --password=REDACTED"
must_mask "app --db-connection-password=pg://x" "app --db-connection-password=REDACTED"

# --- MUST NOT mask (keyword-free argv passes byte-identical) ---
must_pass_through "flm serve /data/ai/models/foo.gguf --port 52625"
must_pass_through "caddy run --config /etc/caddy/caddy.json --adapter caddyfile"
must_pass_through "/run/current-system/sw/bin/ssh -N -D 1080 host"

# --- ACCEPTED conservative over-mask (documented doctrine, pinned so a
#     future "smarter" pattern change is a deliberate decision, not drift) ---
must_mask "llama-server --max-tokens 4096" "llama-server --max-tokens=REDACTED"

# --- Leak sweep: none of the raw probe values may survive anywhere ---
must_contain_no "crm -api-token ghp_abc123def456" "ghp_abc123def456"
must_contain_no "monitor365 --jwt-secret deadbeefcafe0123 --port 3001" "deadbeefcafe0123"

if [ "$rc" -eq 0 ]; then
  echo "redact-argv selftest: ALL SHAPES HOLD"
else
  echo "redact-argv selftest: FAILURES ABOVE"
fi
exit "$rc"
