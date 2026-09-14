#!/usr/bin/env bash

# Flake Consolidation Plan

# Purpose: Resolve multiple flake.nix confusion

echo "🔧 Nix Flake Consolidation Plan"
echo "================================"
echo ""

echo "📋 Current Issues Identified:"
echo " 1. Multiple flake.nix files causing confusion"
echo " 2. Home Manager disabled in root (but used by justfile)"
echo " 3. Failed cross-platform attempt needs cleanup"
echo " 4. Different URL schemes (SSH vs HTTPS)"
echo ""

echo "🎯 Recommended Actions:"
echo ""

echo "📊 STEP 1: Choose Primary Configuration"
echo " Option A: Use root flake.nix (current justfile target)"
echo " Pros: Already integrated with justfile"
echo " Cons: More complex, Home Manager disabled"
echo ""
echo " Option B: Use dotfiles/nix/flake.nix (simpler)"
echo " Pros: Simpler, Home Manager enabled"
echo " Cons: Requires justfile update"
echo ""

echo "🧹 STEP 2: Cleanup Tasks"
echo " - Remove flake.cross-platform.failed"
echo " - Decide on SSH vs HTTPS URLs"
echo " - Enable Home Manager in chosen flake"
echo " - Consolidate features as needed"
echo ""

echo "🔄 STEP 3: Synchronization"
echo " - Merge desired features from both files"
echo " - Update justfile if changing primary flake"
echo " - Test configuration thoroughly"
echo ""

echo "💡 My Recommendation:"
echo " Use the root flake.nix (Option A) because:"
echo " - It's already integrated with your workflow"
echo " - Has advanced Ghost Systems features"
echo " - Just needs Home Manager enabled"
echo ""
