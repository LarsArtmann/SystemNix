#!/usr/bin/env bash
# update-vendor-hash.sh — Fix vendorHash for Go projects using buildGoModule
#
# Usage:
#   ./update-vendor-hash.sh                    # Fix all projects
#   ./update-vendor-hash.sh <project>          # Fix one project
#   ./update-vendor-hash.sh --check            # Check only, don't fix
#
# Strategy: Run `nix build`, capture the "got:" hash from the error,
#           then update the flake.nix (or nix/packages/default.nix) with sed.

set -euo pipefail

PROJECTS_ROOT="/home/lars/projects"
CHECK_ONLY=false
TARGET_PROJECT=""

# Parse args
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    *) TARGET_PROJECT="$arg" ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Projects with buildGoModule and hardcoded vendorHash
# Format: "project_name:nix_file_relative_to_project_root"
declare -A PROJECT_FILES=(
  [GmbH]="flake.nix"
  [vision-review-agent]="flake.nix"
  [go-plugin-mvp]="flake.nix"
  [project-dependency-graph]="flake.nix"
  [artmann-technologies-website]="flake.nix"
  [go-website-template]="flake.nix"
  [PapDashboard]="flake.nix"
  [standard-bug-tracking-schema]="flake.nix"
  [lean-business-plan]="flake.nix"
  [testing]="flake.nix"
  [docs-organizer]="flake.nix"
  [golangci-lint-auto-configure]="flake.nix"
  [KeyCountdown]="flake.nix"
  [projects-management-automation]="flake.nix"
  [buildflow]="flake.nix"
  [BuildFlow]="flake.nix"
  [go-structure-linter]="flake.nix"
  [art-dupl]="flake.nix"
  [branching-flow]="flake.nix"
  [go-auto-upgrade]="flake.nix"
  [Standup-Killer]="flake.nix"
  [hierarchical-errors]="flake.nix"
  [library-policy]="nix/packages/default.nix"
)

update_vendor_hash() {
  local project="$1"
  local nix_file="$2"
  local project_dir="$PROJECTS_ROOT/$project"
  local full_nix_path="$project_dir/$nix_file"

  if [ ! -d "$project_dir" ]; then
    echo -e "${YELLOW}SKIP${NC} $project — directory not found"
    return 1
  fi

  if [ ! -f "$full_nix_path" ]; then
    echo -e "${YELLOW}SKIP${NC} $project — $nix_file not found"
    return 1
  fi

  # Find current vendorHash in the file
  local current_hash
  current_hash=$(grep -oP 'vendorHash\s*=\s*"\Ksha256-[a-zA-Z0-9+/=]+' "$full_nix_path" | head -1)

  if [ -z "$current_hash" ]; then
    echo -e "${YELLOW}SKIP${NC} $project — no hardcoded vendorHash in $nix_file"
    return 1
  fi

  echo -n -e "  ${project} ... "

  # Try building — capture output for hash mismatch
  local build_output
  local build_rc=0
  build_output=$(nix build "$project_dir" --no-link 2>&1) || build_rc=$?

  # Check if build succeeded (hash is already correct)
  if [ "$build_rc" -eq 0 ] && ! echo "$build_output" | grep -q "hash mismatch"; then
    if ! echo "$build_output" | grep -q "got:"; then
      echo -e "${GREEN}OK${NC} (hash is current)"
      return 0
    fi
  fi

  # Extract the correct hash from the error
  local got_hash
  got_hash=$(echo "$build_output" | grep -oP 'got:\s+\Ksha256-[a-zA-Z0-9+/=]+' | head -1)

  if [ -z "$got_hash" ]; then
    # Some other error
    local error_line
    error_line=$(echo "$build_output" | grep "error:" | head -1 | cut -c1-100)
    echo -e "${RED}BUILD ERROR${NC} — $error_line"
    return 1
  fi

  if [ "$got_hash" = "$current_hash" ]; then
    echo -e "${GREEN}OK${NC}"
    return 0
  fi

  if [ "$CHECK_ONLY" = true ]; then
    echo -e "${RED}STALE${NC} — needs: $got_hash"
    return 1
  fi

  # Update the hash in the file
  # Use | as sed delimiter to avoid conflicts with base64 characters
  sed -i "s|vendorHash = \"$current_hash\";|vendorHash = \"$got_hash\";|g" "$full_nix_path"

  echo -e "${GREEN}FIXED${NC} — $current_hash → $got_hash"
  return 0
}

# Main
echo "=== vendorHash Update Tool ==="
echo ""

if [ -n "$TARGET_PROJECT" ]; then
  # Single project mode
  if [ -n "${PROJECT_FILES[$TARGET_PROJECT]+x}" ]; then
    update_vendor_hash "$TARGET_PROJECT" "${PROJECT_FILES[$TARGET_PROJECT]}"
  else
    echo "Unknown project: $TARGET_PROJECT"
    echo "Known projects: ${!PROJECT_FILES[*]}"
    exit 1
  fi
else
  # All projects
  fixed=0
  broken=0
  ok=0
  skipped=0

  for project in "${!PROJECT_FILES[@]}"; do
    nix_file="${PROJECT_FILES[$project]}"
    if update_vendor_hash "$project" "$nix_file"; then
      # Check if it was actually fixed vs already ok
      ((ok++)) || true
    else
      ((broken++)) || true
    fi
  done

  echo ""
  echo "=== Summary ==="
  echo "  OK: $ok"
  echo "  Broken/Errors: $broken"
fi
