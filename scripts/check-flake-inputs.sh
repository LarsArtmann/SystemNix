#!/usr/bin/env bash
# Flake input hygiene audit: checks for ref=master inputs and GOTOOLCHAIN=auto.
#
# ref=master inputs hurt reproducibility — a flake update can pull breaking
# changes at any time. Prefer pinned refs (e.g. ref="v1.2.3" or a specific branch).
# GOTOOLCHAIN=auto breaks sandbox purity by downloading a Go toolchain at build time.
#
# Usage: ./scripts/check-flake-inputs.sh
# Exit codes: 0 = clean, 1 = violations found
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

WARN_COUNT=0
FAIL_COUNT=0

echo "=== Flake Input Hygiene Audit ==="
echo ""

# 1. Check for ref=master (WARNING — 32 existing inputs, don't block)
echo "1. ref=master inputs (reproducibility risk)"
MASTER_REFS=$(grep -n 'ref\s*=\s*"master"' flake.nix 2>/dev/null || true)
if [ -n "$MASTER_REFS" ]; then
  COUNT=$(echo "$MASTER_REFS" | wc -l)
  echo "  ⚠ Found $COUNT input(s) on ref=\"master\" — consider pinning to a release branch or tag"
  echo "$MASTER_REFS" | while read -r line; do
    echo "    $line"
  done
  WARN_COUNT=$((WARN_COUNT + COUNT))
else
  echo '  ✓ No ref="master" inputs'
fi

# 2. Check for GOTOOLCHAIN=auto (FAIL — breaks sandbox purity)
echo ""
echo "2. GOTOOLCHAIN=auto (sandbox purity violation)"
GOTOOLCHAIN_AUTO=$(grep -rn 'GOTOOLCHAIN.*auto' --include="*.nix" . 2>/dev/null | grep -v 'GOTOOLCHAIN.*off' || true)
if [ -n "$GOTOOLCHAIN_AUTO" ]; then
  echo "  ✗ Found GOTOOLCHAIN=auto — this downloads a Go toolchain at build time, breaking sandbox purity"
  echo "$GOTOOLCHAIN_AUTO" | while read -r line; do
    echo "    $line"
  done
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  ✓ No GOTOOLCHAIN=auto found"
fi

# Summary
echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "❌ FAIL: $FAIL_COUNT hard violation(s), $WARN_COUNT warning(s)"
  exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
  echo "⚠ $WARN_COUNT warning(s) (non-blocking)"
  exit 0
else
  echo "✅ All checks passed"
  exit 0
fi
