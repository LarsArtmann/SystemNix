#!/usr/bin/env bash
# Automated Shell Alias Test Script
# Verifies ADR-002 cross-shell alias implementation
# Usage: ./scripts/test-shell-aliases.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define expected aliases
COMMON_ALIASES=("l" "t" "gs" "gd" "ga" "gc" "gp" "gl")
DARWIN_ALIASES=("nixup" "nixbuild" "nixcheck")

# Shell config file paths
ZSH_CONFIG="$HOME/.config/zsh/.zshrc"
BASH_CONFIG="$HOME/.bashrc"
BASH_ALT_CONFIG="$HOME/.bash_profile"

# Test result storage
FISH_COMMON=0
FISH_DARWIN=0
ZSH_COMMON=0
ZSH_DARWIN=0
BASH_COMMON=0
BASH_DARWIN=0

# Function to check alias in config file (simple substring match)
check_alias_config() {
  local shell="$1"
  local config_file="$2"
  local alias_name="$3"

  if [[ ! -f $config_file ]]; then
    echo -e "${RED}✖${NC} $shell: $alias_name - Config file not found"
    return 1
  fi

  # Simple substring check: look for alias name in file
  if grep -q "alias.*$alias_name" "$config_file" 2>/dev/null; then
    # Extract actual command from config
    local actual_command
    actual_command=$(grep "alias.*$alias_name" "$config_file" 2>/dev/null | head -1 | sed "s/.*$alias_name=//" | tr -d "'" | tr -d '"')
    echo -e "${GREEN}✓${NC} $shell: $alias_name - $actual_command"
    return 0
  else
    echo -e "${RED}✖${NC} $shell: $alias_name - Not found in config"
    return 1
  fi
}

# Function to check alias interactively (Fish only)
check_alias_interactive() {
  local shell="$1"
  local alias_name="$2"

  if command -v fish &>/dev/null; then
    local output
    output=$(fish -i -c "type $alias_name" 2>&1)

    # Check if alias is defined (as function)
    if echo "$output" | grep -q "is a function"; then
      echo -e "${GREEN}✓${NC} $shell: $alias_name - Defined"
      return 0
    else
      echo -e "${RED}✖${NC} $shell: $alias_name - Not defined"
      return 1
    fi
  else
    echo -e "${YELLOW}⊘${NC} $shell: $alias_name - Shell not installed"
    return 2
  fi
}

# Function to print test results summary
print_summary() {
  echo ""
  echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE} Shell Alias Test Summary${NC}"
  echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
  echo ""

  # Fish results
  echo -e "${BLUE}🐟 Fish Shell${NC}"
  echo "  Common Aliases: $FISH_COMMON/8 passing"
  echo "  Darwin Aliases: $FISH_DARWIN/3 passing"
  echo ""

  # Zsh results
  echo -e "${BLUE}🅼️  Zsh Shell${NC}"
  echo "  Common Aliases: $ZSH_COMMON/8 passing"
  echo "  Darwin Aliases: $ZSH_DARWIN/3 passing"
  echo ""

  # Bash results
  echo -e "${BLUE}🅱️  Bash Shell${NC}"
  echo "  Common Aliases: $BASH_COMMON/8 passing"
  echo "  Darwin Aliases: $BASH_DARWIN/3 passing"
  echo ""

  # Overall status
  local total=$((FISH_COMMON + ZSH_COMMON + BASH_COMMON + FISH_DARWIN + ZSH_DARWIN + BASH_DARWIN))
  local max=$((8 * 3 + 3 * 3)) # 8 common * 3 shells + 3 darwin * 3 shells (fish + zsh + bash)
  local percentage=$((total * 100 / max))
  echo -e "${BLUE}Overall Status${NC}"
  if [[ $percentage -ge 90 ]]; then
    echo -e "  ${GREEN}✓ EXCELLENT${NC} - $total/$max aliases passing ($percentage%)"
  elif [[ $percentage -ge 70 ]]; then
    echo -e "  ${YELLOW}⊘ GOOD${NC} - $total/$max aliases passing ($percentage%)"
  else
    echo -e "  ${RED}✖ NEEDS WORK${NC} - $total/$max aliases passing ($percentage%)"
  fi
  echo ""
}

# Function to run tests
run_tests() {
  echo -e "${BLUE}Starting shell alias tests...${NC}"
  echo ""

  # Test Fish (always use interactive test since Fish stores as functions)
  echo -e "${BLUE}Testing Fish (interactive)...${NC}"
  for alias_name in "${COMMON_ALIASES[@]}"; do
    if check_alias_interactive "Fish" "$alias_name"; then
      FISH_COMMON=$((FISH_COMMON + 1))
    fi
  done

  for alias_name in "${DARWIN_ALIASES[@]}"; do
    if check_alias_interactive "Fish" "$alias_name"; then
      FISH_DARWIN=$((FISH_DARWIN + 1))
    fi
  done
  echo ""

  # Test Zsh
  echo -e "${BLUE}Testing Zsh...${NC}"
  for alias_name in "${COMMON_ALIASES[@]}"; do
    if check_alias_config "Zsh" "$ZSH_CONFIG" "$alias_name"; then
      ZSH_COMMON=$((ZSH_COMMON + 1))
    fi
  done

  for alias_name in "${DARWIN_ALIASES[@]}"; do
    if check_alias_config "Zsh" "$ZSH_CONFIG" "$alias_name"; then
      ZSH_DARWIN=$((ZSH_DARWIN + 1))
    fi
  done
  echo ""

  # Test Bash
  echo -e "${BLUE}Testing Bash...${NC}"
  local bash_config="$BASH_CONFIG"
  if [[ ! -f $bash_config ]]; then
    bash_config="$BASH_ALT_CONFIG"
  fi

  for alias_name in "${COMMON_ALIASES[@]}"; do
    if check_alias_config "Bash" "$bash_config" "$alias_name"; then
      BASH_COMMON=$((BASH_COMMON + 1))
    fi
  done

  for alias_name in "${DARWIN_ALIASES[@]}"; do
    if check_alias_config "Bash" "$bash_config" "$alias_name"; then
      BASH_DARWIN=$((BASH_DARWIN + 1))
    fi
  done
  echo ""

  # Print summary
  print_summary
}

# Run tests
run_tests

# Exit with appropriate code
if [[ $FISH_COMMON -lt 8 ]] || [[ $ZSH_COMMON -lt 8 ]] || [[ $BASH_COMMON -lt 8 ]]; then
  exit 1
fi

exit 0
