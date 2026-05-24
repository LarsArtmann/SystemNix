#!/usr/bin/env bash
# Show current versions of all LarsArtmann packages tracked in SystemNix
set -euo pipefail

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# All LarsArtmann packages with their flake input names
# Format: "package_name:input_name:version_source"
# version_source is how to find the version: "nix" (from nix eval) or "file:relative/path:line_pattern"
packages=(
  "dnsblockd:dnsblockd"
  "emeet-pixyd:emeet-pixyd"
  "monitor365:monitor365"
  "file-and-image-renamer:file-and-image-renamer"
  "library-policy:library-policy"
  "hierarchical-errors:hierarchical-errors"
  "golangci-lint-auto-configure:golangci-lint-auto-configure"
  "mr-sync:mr-sync"
  "buildflow:buildflow"
  "go-auto-upgrade:go-auto-upgrade"
  "go-structure-linter:go-structure-linter"
  "branching-flow:branching-flow"
  "art-dupl:art-dupl"
  "projects-management-automation:projects-management-automation"
  "todo-list-ai:todo-list-ai"
  "crush-config:crush-config"
)

# Detect platform
if [[ "$(uname)" == "Darwin" ]]; then
  eval_attr="nixosConfigurations" # won't work on Darwin for most
  system="aarch64-darwin"
else
  eval_attr="nixosConfigurations.evo-x2.pkgs"
  system="x86_64-linux"
fi

printf "%-40s %-12s %-12s\n" "PACKAGE" "VERSION" "LOCKED REV"
printf "%-40s %-12s %-12s\n" "$(printf '%.0s-' {1..40})" "$(printf '%.0s-' {1..12})" "$(printf '%.0s-' {1..12})"

for entry in "${packages[@]}"; do
  IFS=':' read -r pkg input <<<"$entry"

  # Get version from nix eval (skip non-package inputs like crush-config)
  ver=$(nix eval --json ".#${eval_attr}.${pkg}.version" 2>/dev/null | tr -d '"' || echo "")
  [ -z "$ver" ] && ver="(config)"

  # Get locked rev from flake.lock
  rev=$(python3 -c "
import json, sys
try:
    lock = json.load(open('flake.lock'))
    r = lock['nodes'].get('$input', {}).get('locked', {}).get('rev', 'N/A')
    print(r[:12])
except:
    print('N/A')
" 2>/dev/null || echo "N/A")

  printf "%-40s %-12s %-12s\n" "$pkg" "$ver" "$rev"
done
