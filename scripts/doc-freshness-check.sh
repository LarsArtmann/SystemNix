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

# Module count (non-underscore .nix files in services/ only — desktop counted separately)
SERVICE_MODULES=$(find modules/nixos/services -maxdepth 1 -name '*.nix' ! -name '_*' 2>/dev/null | wc -l)
DESKTOP_MODULES=$(find modules/nixos/desktop -maxdepth 1 -name '*.nix' ! -name '_*' 2>/dev/null | wc -l)

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
check_count "README service module count" "$SERVICE_MODULES" "$README_MODULES" "README.md"

README_GATUS=$(grep -oP '\d+(?= health checks)' README.md 2>/dev/null | head -1 || echo "N/A")
check_count "README Gatus count" "$GATUS_COUNT" "$README_GATUS" "README.md"

README_SCRIPTS=$(grep -oP '\d+(?= operational scripts)' README.md 2>/dev/null | head -1 || echo "N/A")
check_count "README script count" "$SCRIPT_COUNT" "$README_SCRIPTS" "README.md"

README_PKGS=$(grep -oP '\d+(?= custom package)' README.md 2>/dev/null | head -1 || echo "N/A")
check_count "README package count" "$PKG_COUNT" "$README_PKGS" "README.md"

# Check FEATURES.md
echo ""
echo "--- FEATURES.md ---"
FEATURES_GATUS=$(grep -oP '\d+(?= health check)' FEATURES.md 2>/dev/null | head -1 || echo "N/A")
if [ "$FEATURES_GATUS" != "N/A" ]; then
  check_count "FEATURES Gatus count" "$GATUS_COUNT" "$FEATURES_GATUS" "FEATURES.md"
else
  echo "OK: FEATURES has no health-check count (skip)"
fi

# Check CHANGELOG.md (only [Unreleased] section)
echo ""
echo "--- CHANGELOG.md ---"
UNRELEASED_GATUS=$(sed -n '/## \[Unreleased\]/,/## \[/p' CHANGELOG.md 2>/dev/null | grep -oP '\d+(?= endpoints)' | tail -1 || echo "N/A")
if [ "$UNRELEASED_GATUS" != "N/A" ]; then
  check_count "CHANGELOG [Unreleased] Gatus count" "$GATUS_COUNT" "$UNRELEASED_GATUS" "CHANGELOG.md"
else
  echo "OK: CHANGELOG [Unreleased] has no endpoint count (skip)"
fi

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "FAILED: $FAIL doc count(s) are stale. Update the files listed above."
  exit 1
fi
echo "All documentation counts are current."
