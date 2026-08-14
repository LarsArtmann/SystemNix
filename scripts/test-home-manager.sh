#!/usr/bin/env bash

set -euo pipefail

# Home Manager Verification Script
# Tests Home Manager integration after deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🧪 Testing Home Manager Integration..."
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test counters
# Test 1: Starship is installed
echo ""
echo "1️⃣  Starship Prompt"
if command -v starship &>/dev/null; then
  version=$(starship --version 2>&1 || echo "UNKNOWN")
  echo "  ✅ Starship installed: $version"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))

  # Check Starship config
  if [ -f ~/.config/starship.toml ]; then
    echo "  ✅ Starship config exists: ~/.config/starship.toml"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Check for expected settings
    if grep -q "add_newline = false" ~/.config/starship.toml 2>/dev/null; then
      echo "  ✅ Starship setting: add_newline = false"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo "  ⚠️  Starship setting: add_newline not found (may be using different config)"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
  else
    echo "  ⚠️  Starship config not found: ~/.config/starship.toml"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
  fi
else
  echo "  ❌ Starship not found"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

# Test 2: Fish shell
echo ""
echo "2️⃣  Fish Shell"
if [[ $SHELL == *"fish"* ]]; then
  echo "  ✅ Fish shell active: $SHELL"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))

  # Check Fish version
  if command -v fish &>/dev/null; then
    version=$(fish --version 2>&1 || echo "UNKNOWN")
    echo "  ✅ Fish version: $version"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Check Fish config
    if [ -f ~/.config/fish/config.fish ]; then
      echo "  ✅ Fish config exists: ~/.config/fish/config.fish"
      TESTS_PASSED=$((TESTS_PASSED + 1))
      TESTS_TOTAL=$((TESTS_TOTAL + 1))

      # Check for common aliases
      if grep -q "alias l" ~/.config/fish/config.fish 2>/dev/null; then
        echo "  ✅ Fish alias: l configured"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        echo "  ⚠️  Fish alias: l not found"
      fi
      TESTS_TOTAL=$((TESTS_TOTAL + 1))

      if grep -q "alias t" ~/.config/fish/config.fish 2>/dev/null; then
        echo "  ✅ Fish alias: t configured"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        echo "  ⚠️  Fish alias: t not found"
      fi
      TESTS_TOTAL=$((TESTS_TOTAL + 1))

      # Check for platform-specific aliases
      if [ "$(uname)" == "Darwin" ]; then
        # macOS
        if grep -q "alias nixup.*darwin-rebuild" ~/.config/fish/config.fish 2>/dev/null; then
          echo "  ✅ Fish alias: nixup (darwin-rebuild) configured"
          TESTS_PASSED=$((TESTS_PASSED + 1))
        else
          echo "  ⚠️  Fish alias: nixup not found or not darwin-rebuild"
        fi
      else
        # Linux/NixOS
        if grep -q "alias nixup.*nixos-rebuild" ~/.config/fish/config.fish 2>/dev/null; then
          echo "  ✅ Fish alias: nixup (nixos-rebuild) configured"
          TESTS_PASSED=$((TESTS_PASSED + 1))
        else
          echo "  ⚠️  Fish alias: nixup not found or not nixos-rebuild"
        fi
      fi
      TESTS_TOTAL=$((TESTS_TOTAL + 1))
    else
      echo "  ⚠️  Fish config not found: ~/.config/fish/config.fish"
      TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
  else
    echo "  ❌ Fish command not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
  fi
else
  echo "  ⚠️  Fish shell not active: $SHELL (expected: fish)"
  echo "  ℹ️  Note: This test is run from $SHELL, not Fish shell"
  echo "  ℹ️  Note: To test Fish shell, run this script from Fish: fish scripts/test-home-manager.sh"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

# Test 3: Environment Variables
echo ""
echo "3️⃣  Environment Variables"

if [ "${EDITOR:-}" == "micro" ]; then
  echo "  ✅ EDITOR set correctly: ${EDITOR:-}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  ⚠️  EDITOR not set correctly: ${EDITOR:-} (expected: micro)"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

if [ "${LANG:-}" == "en_GB.UTF-8" ]; then
  echo "  ✅ LANG set correctly: ${LANG:-}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  ⚠️  LANG not set correctly: ${LANG:-} (expected: en_GB.UTF-8)"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

if [ "${LC_ALL:-}" == "en_GB.UTF-8" ]; then
  echo "  ✅ LC_ALL set correctly: ${LC_ALL:-}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  ⚠️  LC_ALL not set correctly: ${LC_ALL:-} (expected: en_GB.UTF-8)"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Check PATH additions
path_has() {
  local path="$1"
  echo "$PATH" | tr ':' '\n' | grep -q "$path"
}

if path_has ~/.local/bin; then
  echo "  ✅ PATH includes: ~/.local/bin"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  ⚠️  PATH missing: ~/.local/bin"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

if path_has ~/go/bin; then
  echo "  ✅ PATH includes: ~/go/bin"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  ⚠️  PATH missing: ~/go/bin"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

if path_has ~/.bun/bin; then
  echo "  ✅ PATH includes: ~/.bun/bin"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  ⚠️  PATH missing: ~/.bun/bin"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 4: Tmux
echo ""
echo "4️⃣  Tmux"
if command -v tmux &>/dev/null; then
  version=$(tmux -V 2>&1 || echo "UNKNOWN")
  echo "  ✅ Tmux installed: $version"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))

  # Check Tmux config
  if [ -f ~/.config/tmux/tmux.conf ]; then
    echo "  ✅ Tmux config exists: ~/.config/tmux/tmux.conf"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Check for expected settings
    if grep -q "base-index 1" ~/.config/tmux/tmux.conf 2>/dev/null; then
      echo "  ✅ Tmux setting: base-index 1"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo "  ⚠️  Tmux setting: base-index not found (may be using default)"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if grep -q "clock24 on" ~/.config/tmux/tmux.conf 2>/dev/null; then
      echo "  ✅ Tmux setting: clock24 on"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo "  ⚠️  Tmux setting: clock24 not found (may be using default)"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if grep -q "mouse on" ~/.config/tmux/tmux.conf 2>/dev/null; then
      echo "  ✅ Tmux setting: mouse on"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo "  ⚠️  Tmux setting: mouse not found (may be using default)"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
  else
    echo "  ⚠️  Tmux config not found: ~/.config/tmux/tmux.conf"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
  fi
else
  echo "  ❌ Tmux not found"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total Tests: $TESTS_TOTAL"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
else
  echo "  Failed: $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}🎉 All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests failed!${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Restart shell: exec fish"
  echo "  2. Reload config: source ~/.config/fish/config.fish"
  echo "  3. Check deployment guide: docs/verification/HOME-MANAGER-DEPLOYMENT-GUIDE.md"
  exit 1
fi
