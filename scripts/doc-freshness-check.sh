#!/usr/bin/env bash
# Verifies documentation freshness against code state.
# Checks: module count, Gatus endpoint count, script count, service count.
# Exit non-zero if any doc count is stale.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

FAIL=0

check_count() {
  local label="$1" expected="$2" doc_value="$3" file="$4"
  if [ "$expected" != "$doc_value" ]; then
    echo "FAIL: $label — docs say $doc_value, actual is $expected (in $file)"
    FAIL=$((FAIL + 1))
  else
    echo "OK: $label ($expected)"
  fi
}

# Module count (non-underscore .nix files in services/ + desktop/)
MODULE_COUNT=$(find modules/nixos/services modules/nixos/desktop -name '*.nix' ! -name '_*' 2>/dev/null | wc -l)

# Gatus endpoints
GATUS_COUNT=$(grep -c 'name =' modules/nixos/services/gatus-config.nix 2>/dev/null || echo 0)

# Scripts
SCRIPT_COUNT=$(find scripts -maxdepth 1 -type f 2>/dev/null | wc -l)

# Custom packages
PKG_COUNT=$(find pkgs -maxdepth 1 -name '*.nix' 2>/dev/null | wc -l)

echo "=== Documentation Freshness Check ==="
echo ""

# Check README.md
echo "--- README.md ---"
README_MODULES=$(grep -oP '\d+(?= NixOS service modules)' README.md 2>/dev/null | head -1 || echo "N/A")
check_count "README module count" "$MODULE_COUNT" "$README_MODULES" "README.md"

README_GATUS=$(grep -oP '\d+(?= health checks)' README.md 2>/dev/null | head -1 || echo "N/A")
check_count "README Gatus count" "$GATUS_COUNT" "$README_GATUS" "README.md"

README_SCRIPTS=$(grep -oP '\d+(?= operational scripts)' README.md 2>/dev/null | head -1 || echo "N/A")
check_count "README script count" "$SCRIPT_COUNT" "$README_SCRIPTS" "README.md"

README_PKGS=$(grep -oP '\d+(?= custom package)' README.md 2>/dev/null | head -1 || echo "N/A")
check_count "README package count" "$PKG_COUNT" "$README_PKGS" "README.md"

# Check FEATURES.md
echo ""
echo "--- FEATURES.md ---"
FEATURES_GATUS=$(grep -oP '\d+(?= Gatus)' FEATURES.md 2>/dev/null | head -1 || echo "N/A")
check_count "FEATURES Gatus count" "$GATUS_COUNT" "$FEATURES_GATUS" "FEATURES.md"

# Check CHANGELOG.md
echo ""
echo "--- CHANGELOG.md ---"
CHANGELOG_GATUS=$(grep -oP '\d+(?= endpoints)' CHANGELOG.md 2>/dev/null | tail -1 || echo "N/A")
check_count "CHANGELOG Gatus count" "$GATUS_COUNT" "$CHANGELOG_GATUS" "CHANGELOG.md"

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "FAILED: $FAIL doc count(s) are stale. Update the files listed above."
  exit 1
fi
echo "All documentation counts are current."
