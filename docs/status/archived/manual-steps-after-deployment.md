# Manual Steps Required After Nix Deployment

> **[docs-health 2026-09-21] OBSOLETE + ARCHIVED** — no dated steps here remain valid: the security casks it lists (blockblock/oversight/knockknock/dnd) are no longer in `platforms/darwin/default.nix`, `scripts/activitywatch-config.sh` does not exist, and the `dotfiles/nix` path is gone. Kept only as a historical checklist shape.

## Overview
~~~~ obsolete — see banner (all referenced artifacts removed).
While Nix manages most configuration declaratively, some steps require manual user interaction for security and system integrity reasons.

## ⚠️ CRITICAL STEPS

### 1. Security Tools Installation **[REQUIRED]**

**Status:** ❌ Security tools NOT installed despite being in homebrew.nix

**Issue:** Nix deployment timed out and security tools were not installed.

**Manual Action Required:**

```bash
# Verify current status
brew list --cask | grep -E "(blockblock|oversight|knockknock|dnd)"

# If missing, re-run deployment (requires manual intervention for system activation)
cd dotfiles/nix
sudo darwin-rebuild switch --flake .

# OR install individually if Nix continues to fail
brew install --cask blockblock
brew install --cask oversight
brew install --cask knockknock
brew install --cask dnd
```

**Verification:**

```bash
ls /Applications/ | grep -iE "(block|sight|knock|dnd)"
```

### 2. Fish Shell Activation **[OPTIONAL BUT RECOMMENDED]**

**Status:** ❌ ZSH still active (72ms), Fish available but not default

**Current Performance:**

- ZSH: 72ms (current default)
- Fish: 334ms (available but slow - performance regression!)

**Recommendation:** **KEEP ZSH** until Fish performance issue is resolved.

**If you want to activate Fish anyway:**

```bash
chsh -s /run/current-system/sw/bin/fish
# Logout and login to apply
```

## 🔧 CONFIGURATION STEPS

### 3. Security Tools Configuration **[REQUIRED AFTER INSTALLATION]**

#### BlockBlock Configuration

1. Open BlockBlock from Applications
2. Grant required permissions in System Preferences > Security & Privacy
3. Configure monitoring preferences:
   - Enable startup monitoring
   - Set notification preferences
   - Review baseline scan results

#### Oversight Configuration

1. Launch Oversight
2. Grant microphone/camera monitoring permissions
3. Configure notification settings
4. Test with camera/microphone app

#### KnockKnock Baseline Scan

1. Open KnockKnock
2. Run initial full system scan
3. Review and approve legitimate persistent items
4. Save baseline for future comparisons

#### DnD (Do Not Disturb) Setup

1. Launch DnD
2. Configure protected directories
3. Set notification preferences
4. Test with file operations

### 4. ActivityWatch Optimization **[OPTIONAL]**

**Status:** ✅ Installed and configured

**Manual Optimization:**

```bash
# Run optimization script
./scripts/activitywatch-config.sh optimize

# Check status
./scripts/activitywatch-config.sh status
```

### 5. Performance Monitoring Setup **[RECOMMENDED]**

**Status:** ❌ Performance directory not properly set up

**Setup Performance Monitoring:**

```bash
# Create performance data directory
mkdir -p ./performance-data

# Run baseline performance test
./shell-performance-benchmark.sh

# Set up regular monitoring (optional)
echo "0 9 * * 1 $(pwd)/shell-performance-benchmark.sh" | crontab -
```

## 🔍 VERIFICATION STEPS

### Run Deployment Verification

```bash
./scripts/deployment-verify.sh
```

**Expected Results:**

- All packages should be ✅ PASS
- Security tools should be ✅ PASS after manual installation
- Shell performance should be acceptable
- All config files should exist

### Quick System Check

```bash
# Check shell
echo "Current shell: $SHELL"

# Check security tools
ls /Applications/ | grep -iE "(block|sight|knock|dnd)"

# Check Nix packages
which fish carapace starship hyperfine jq gh

# Check Homebrew integration
brew --version && brew list --cask | head -5
```

## 📋 TROUBLESHOOTING

### If Nix Deployment Keeps Timing Out

1. **Never force quit** - let it complete naturally
2. Check system resources with Activity Monitor
3. Restart and try `just switch` again
4. If persistent issues, try individual package installation

### If Security Tools Don't Install

1. Check available disk space
2. Verify internet connection
3. Try manual Homebrew installation
4. Check System Preferences > Security & Privacy for blocks

### If Fish Performance Is Poor

1. **Stay with ZSH** (currently faster at 72ms)
2. Investigate Fish configuration issues
3. Check for conflicting shell configurations
4. Consider Fish version downgrade

### If Services Don't Start

1. Check macOS permissions in System Preferences
2. Try manual application launch
3. Check Console.app for error messages
4. Restart required for some system-level changes

## 📊 MONITORING AND MAINTENANCE

### Regular Checks (Weekly)

```bash
# System verification
./scripts/deployment-verify.sh

# Performance monitoring
./shell-performance-benchmark.sh

# Security tool status
./scripts/security-tools-status.sh  # TODO: Create this script
```

### Updates

```bash
# Update Nix packages
just update && just switch

# Update Homebrew packages
brew update && brew upgrade
```

## 🚨 CRITICAL NOTES

1. **Security tools are ESSENTIAL** - Don't skip installation
2. **Performance regression exists** - Fish slower than expected
3. **ZSH currently faster** than Fish (opposite of expectations)
4. **Manual steps cannot be automated** for security reasons
5. **Always verify deployment** with verification script

## 📖 REFERENCE

- Fish Performance Issue: `docs/fish-performance-issue.md`
- Shell Activation Guide: `docs/fish-shell-activation.md`
- Performance Analysis: `docs/learnings/2025-07-15_12-59-terminal-performance-session.md`
- Verification Script: `scripts/deployment-verify.sh`
