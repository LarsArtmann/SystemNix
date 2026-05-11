#!/usr/bin/env bash
# Comprehensive diagnostic script for NixOS Home Manager errors

set -euo pipefail

FLAKE_HOST="${FLAKE_HOST:-$(hostname)}"
FLAKE_REF=".#${FLAKE_HOST}"
echo "🔍 NixOS Home Manager Diagnostic Tool"
echo "====================================="
echo "Machine: $(hostname)"
echo "Date: $(date)"
echo ""

# Function to check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    echo "❌ This script should be run as a regular user, not root"
    exit 1
  fi
}

# Function to check if running on NixOS
check_nixos() {
  if [[ ! -f /etc/NIXOS ]]; then
    echo "❌ This script is designed to run on NixOS"
    exit 1
  fi
  echo "✅ Running on NixOS"
}

# Function to check Home Manager status
check_home_manager() {
  echo ""
  echo "🔍 Checking Home Manager status..."

  # Check if home-manager is installed
  if ! command -v home-manager &>/dev/null; then
    echo "❌ home-manager command not found"
    return 1
  fi

  echo "✅ home-manager is installed"
  echo "Version: $(home-manager --version)"

  # Check Home Manager generations
  if [[ -d /nix/var/nix/profiles/per-user/$USER/home-manager ]]; then
    echo "✅ Home Manager profile exists"
    echo "Generations: $(nix-env --list-generations --profile /nix/var/nix/profiles/per-user/$USER/home-manager | wc -l)"
  else
    echo "⚠️  No Home Manager generations found"
  fi
}

# Function to test flake configuration
test_flake() {
  echo ""
  echo "🔍 Testing flake configuration..."

  if [[ ! -f flake.nix ]]; then
    echo "❌ flake.nix not found in current directory"
    return 1
  fi

  echo "✅ flake.nix found"

  # Test flake check
  echo "Running nix flake check..."
  if nix flake check --quiet; then
    echo "✅ nix flake check passed"
  else
    echo "❌ nix flake check failed"
    return 1
  fi
}

# Function to test NixOS configuration build
test_nixos_config() {
  echo ""
  echo "🔍 Testing NixOS configuration build..."

  # Test nixos-rebuild check
  echo "Running nixos-rebuild check..."
  if sudo nixos-rebuild check --flake "$FLAKE_REF" --show-trace; then
    echo "✅ nixos-rebuild check passed"
  else
    echo "❌ nixos-rebuild check failed"
    echo ""
    echo "🔧 Trying to get more detailed error information..."
    sudo nixos-rebuild build --flake "$FLAKE_REF" --show-trace 2>&1 | head -50
    return 1
  fi
}

# Function to check for common issues
check_common_issues() {
  echo ""
  echo "🔍 Checking for common issues..."

  # Check for corrupted profiles
  if [[ -L ~/.nix-profile ]] && [[ ! -e ~/.nix-profile ]]; then
    echo "⚠️  Broken .nix-profile symlink detected"
    echo "Run: nix-store --repair ~/.nix-profile"
  fi

  # Check for free space
  echo "Available disk space:"
  df -h / | tail -1

  # Check for nix daemon issues
  if ! pgrep nix-daemon >/dev/null; then
    echo "⚠️  nix-daemon is not running"
  fi
}

# Function to provide remediation steps
provide_remediation() {
  echo ""
  echo "🔧 Remediation Steps"
  echo "==================="
  echo ""
  echo "If tests failed, try these steps in order:"
  echo ""
  echo "1. Clean up Nix store:"
  echo "   sudo nix-collect-garbage -d"
  echo ""
  echo "2. Fix broken Home Manager profile:"
  echo "   nix-env --delete-generations old --profile /nix/var/nix/profiles/per-user/$USER/home-manager"
  echo ""
  echo "3. Rebuild configuration:"
  echo "   sudo nixos-rebuild switch --flake $FLAKE_REF"
  echo ""
  echo "4. If still failing, try cleaning the Nix store:"
  echo "   sudo nix-collect-garbage -d"
  echo "   sudo nix-store --optimise"
  echo "   sudo nixos-rebuild switch --flake $FLAKE_REF"
}

# Main execution
main() {
  check_root
  check_nixos
  check_home_manager
  test_flake
  test_nixos_config
  check_common_issues

  echo ""
  echo "✅ All diagnostics passed!"
  echo "You can safely run: sudo nixos-rebuild switch --flake $FLAKE_REF"
}

# Run with error handling
if main; then
  exit 0
else
  provide_remediation
  exit 1
fi
