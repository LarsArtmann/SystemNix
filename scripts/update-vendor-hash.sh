#!/usr/bin/env bash
# update-vendor-hash.sh — Fix vendorHash for Go projects using buildGoModule
#
# Usage:
#   ./update-vendor-hash.sh                    # Fix all projects
#   ./update-vendor-hash.sh <project>          # Fix one project
#   ./update-vendor-hash.sh --check            # Check only, don't fix
#
# Strategy: Iteratively run `nix build`, capture the "got:" hash from the
#           error, and update the SPECIFIC stale hash in the nix file.
#           Repeats until the build succeeds or a non-hash error occurs.
#           Handles files with multiple different vendorHash values.

set -euo pipefail

PROJECTS_ROOT="/home/lars/projects"
CHECK_ONLY=false
TARGET_PROJECT=""

for arg in "$@"; do
  case "$arg" in
  --check) CHECK_ONLY=true ;;
  *) TARGET_PROJECT="$arg" ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

declare -A PROJECT_FILES=(
  [GmbH]="flake.nix"
  [vision - review - agent]="flake.nix"
  [go - plugin - mvp]="flake.nix"
  [project - dependency - graph]="flake.nix"
  [artmann - technologies - website]="flake.nix"
  [go - website - template]="flake.nix"
  [PapDashboard]="flake.nix"
  [standard - bug - tracking - schema]="flake.nix"
  [lean - business - plan]="flake.nix"
  [testing]="flake.nix"
  [docs - organizer]="flake.nix"
  [golangci - lint - auto - configure]="flake.nix"
  [KeyCountdown]="flake.nix"
  [projects - management - automation]="flake.nix"
  [buildflow]="flake.nix"
  [BuildFlow]="flake.nix"
  [go - structure - linter]="flake.nix"
  [art - dupl]="flake.nix"
  [branching - flow]="flake.nix"
  [go - auto - upgrade]="flake.nix"
  [Standup - Killer]="flake.nix"
  [hierarchical - errors]="flake.nix"
  [library - policy]="nix/packages/default.nix"
  [SwettySwipperWeb]="flake.nix"
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

  local has_hash
  has_hash=$(grep -c 'vendorHash\s*=\s*"sha256-' "$full_nix_path" || true)
  if [ "$has_hash" -eq 0 ]; then
    echo -e "${YELLOW}SKIP${NC} $project — no hardcoded vendorHash"
    return 1
  fi

  echo -n -e "  ${project} ... "

  local fixed_count=0
  local max_iterations=10
  local iteration=0

  while [ "$iteration" -lt "$max_iterations" ]; do
    iteration=$((iteration + 1))

    local build_output
    local build_rc=0
    build_output=$(nix build "$project_dir" --no-link 2>&1) || build_rc=$?

    if [ "$build_rc" -eq 0 ]; then
      if [ "$fixed_count" -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
      else
        echo -e "${GREEN}FIXED${NC} (${fixed_count} hash(es) updated)"
      fi
      return 0
    fi

    local got_hash
    got_hash=$(echo "$build_output" | grep -oP 'got:\s+\Ksha256-[a-zA-Z0-9+/=]+' | head -1)

    if [ -z "$got_hash" ]; then
      local error_line
      error_line=$(echo "$build_output" | grep "error:" | grep -v "Cannot build" | grep -v "Build failed" | head -1 | cut -c1-120)
      if [ -z "$error_line" ]; then
        error_line=$(echo "$build_output" | tail -3 | head -1 | cut -c1-120)
      fi
      echo -e "${RED}BUILD ERROR${NC} — $error_line"
      return 1
    fi

    if [ "$CHECK_ONLY" = true ]; then
      echo -e "${RED}STALE${NC} — needs: $got_hash"
      return 1
    fi

    local specified_hash
    specified_hash=$(echo "$build_output" | grep -oP 'specified:\s+\Ksha256-[a-zA-Z0-9+/=]+' | head -1)

    if [ -n "$specified_hash" ]; then
      sed -i "s|vendorHash = \"$specified_hash\";|vendorHash = \"$got_hash\";|" "$full_nix_path"
      fixed_count=$((fixed_count + 1))
    else
      echo -e "${RED}ERROR${NC} — got hash but couldn't find specified hash"
      return 1
    fi
  done

  echo -e "${RED}ERROR${NC} — max iterations reached"
  return 1
}

echo "=== vendorHash Update Tool ==="
echo ""

if [ -n "$TARGET_PROJECT" ]; then
  if [ -n "${PROJECT_FILES[$TARGET_PROJECT]+x}" ]; then
    update_vendor_hash "$TARGET_PROJECT" "${PROJECT_FILES[$TARGET_PROJECT]}"
  else
    echo "Unknown project: $TARGET_PROJECT"
    echo "Known projects: ${!PROJECT_FILES[*]}"
    exit 1
  fi
else
  ok=0
  broken=0

  # Sort projects for consistent output
  for project in $(echo "${!PROJECT_FILES[@]}" | tr ' ' '\n' | sort); do
    nix_file="${PROJECT_FILES[$project]}"
    if update_vendor_hash "$project" "$nix_file"; then
      ok=$((ok + 1))
    else
      broken=$((broken + 1))
    fi
  done

  echo ""
  echo "=== Summary ==="
  echo "  OK/Fixed: $ok"
  echo "  Errors: $broken"
fi
