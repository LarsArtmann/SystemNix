# Nix Darwin Rebuild Troubleshooting Status

**Date**: 2025-12-29 01:25 UTC
**System**: macOS Sequoia (aarch64-darwin)
**Nix Version**: 2.31.2
**Configuration**: nix-darwin flake-based

---

## Executive Summary

### Overall Status: 🔶 PARTIALLY DONE

**Progress Made**:

- ✅ Identified root cause: Wayland packages being evaluated on Darwin
- ✅ Fixed evaluation errors by creating platform-specific packages
- ✅ Build now starts successfully (was failing at eval phase)
- ⏸️ Build process runs but does NOT complete
- ❌ Unknown specific error blocking completion

**Critical Blocker**:

- Cannot identify actual build failure reason
- Build runs in background, error capture is difficult
- Need to see specific error message to proceed

---

## ✅ FULLY DONE

### 1. Root Cause Identification

**Problem**: Wayland packages (`wl-clipboard`, `wayland`) being evaluated on `aarch64-darwin`

**Status**: FIXED ✅

- Identified that `micro-full` includes Wayland dependencies
- Discovered `ghost-wallpaper` module had unguarded Wayland config
- Found `helium.nix` was pulling in Wayland buildInputs even on Darwin

### 2. Platform-Specific Package Separation

**Problem**: Single `helium.nix` file trying to serve both platforms

**Status**: FIXED ✅

- Created `helium-darwin.nix` (macOS-only, no Wayland deps)
- Created `helium-linux.nix` (Linux-only, includes Wayland)
- Modified `base.nix` to conditionally import correct package

### 3. Ghost-Wallpaper Module Fix

**Problem**: Module evaluated Wayland options on all platforms

**Status**: FIXED ✅

- Added guard: `mkIf (!pkgs.stdenv.isDarwin && config.wayland.windowManager.hyprland.enable)`
- Wayland config now only evaluates on Linux with Hyprland

### 4. Problematic Packages Identified

**Status**: IDENTIFIED ✅

| Package      | Problem                                      | Status   |
| ------------ | -------------------------------------------- | -------- |
| `micro-full` | Contains `wl-clipboard` (Wayland) dependency | Disabled |
| `cliphist`   | Wayland clipboard manager                    | Disabled |
| `helium.nix` | Single package for both platforms            | Split    |

### 5. Nix Settings Cleanup

**Status**: FIXED ✅

**Issues Fixed**:

- Removed duplicate `substituters` entries (cache.nixos.org was duplicated)
- Removed duplicate `trusted-public-keys`
- Removed conflicting `impure-host-deps` that were breaking build

**Changes Made**:

- Set `sandbox = false` to match working generation 205
- Removed all custom `impure-host-deps` paths
- Removed all custom `extra-sandbox-paths`
- Simplified to minimal working configuration

### 6. Sandbox Configuration

**Status**: ADJUSTED ✅

- Disabled sandbox to match known-good configuration
- Will re-enable incrementally once build succeeds

### 7. Build Evaluation Fixed

**Status**: FIXED ✅

- Build now starts successfully
- 64 derivations queued for building
- No more "Package 'wayland-1.24.0' is not available" errors

---

## 🔶 PARTIALLY DONE

### 1. darwin-rebuild Build Process

**Current State**:

- ✅ **Evaluation Phase**: Works perfectly
  - No more Wayland errors
  - No more platform incompatibility errors
  - Configuration validates successfully

- ✅ **Build Start**: Initiates correctly
  - 64 derivations queued
  - Build process begins
  - Go compilation observed (packages being built)

- ⏸️ **Build Execution**: Runs for several minutes
  - Packages compile successfully
  - Progress is visible in process list
  - But never completes

- ❌ **Build Completion**: FAILS
  - Error: "builder failed with exit code 1"
  - Specific error unknown
  - Build log not easily accessible

---

## ❌ NOT STARTED

1. Complete successful `darwin-rebuild build` (identify and fix remaining error)
2. Run `darwin-rebuild switch` to activate new generation
3. Re-enable temporarily disabled packages (`micro-full`, `cliphist`, GUI packages)
4. Test system after activation
5. Clean up git history (multiple "temp" commits)
6. Create working rollback strategy
7. Enable sandbox (test with proper configuration or relaxed mode)
8. Document all changes with rationale
9. Set up continuous integration testing
10. Create backup of working configuration

---

## 💀 TOTALLY FUCKED UP

### 1. Git Repository State

**Problem**: Repository is cluttered with "temp" commits

**Impact**:

- Hard to track what's actually fixed vs experimental
- Difficult to rollback to specific working state
- Unprofessional git history

**Fix Needed**: Squash all "temp" commits before finalizing

### 2. Scorched Earth Approach

**Problem**: Disabled EVERYTHING to get build to start

**Impact**:

- Lost track of what packages are actually needed
- Ad-hoc fixes instead of systematic approach
- May have broken working configurations

**Risk**: System may be missing essential packages when finally activated

### 3. No Error Visibility

**Problem**: Build runs in background, can't see actual failure reason

**Impact**:

- Can't diagnose specific error
- Trial-and-error approach is inefficient
- Wasting time on blind fixes

**Fix Needed**: Capture full build output in file, don't background

### 4. No Systematic Fix

**Problem**: Ad-hoc fixes instead of proper platform package management

**Impact**:

- Not scalable
- Will encounter same issues with new packages
- No clear pattern for future debugging

**Fix Needed**: Create systematic approach for platform-specific packages

### 5. Broken Rollback

**Problem**: No clear path back to working state if this fails

**Impact**:

- Risk of breaking current working generation
- No safety net
- Downtime if new build fails

**Fix Needed**: Keep generation 205 as known-good backup

---

## 📈 WHAT WE SHOULD IMPROVE

### 1. Systematic Platform Separation

**Current State**: Ad-hoc fixes per package

**Needed**:

- Clear system for marking Linux-only vs Darwin-only packages
- Automated validation that Darwin-only config doesn't reference Linux packages
- Standardized pattern for platform-specific imports

### 2. Clean Git History

**Current State**: Multiple "temp" experimental commits

**Needed**:

- Squash all temp commits into logical feature commits
- Write clear commit messages with rationale
- Tag working configurations

### 3. Better Error Tracking

**Current State**: Build output lost in background execution

**Needed**:

- Always capture build output to file
- Use `--keep-failed` flag
- Parse errors systematically

### 4. Incremental Testing

**Current State**: Disabled everything, enabling one by one blindly

**Needed**:

- Fix ONE thing at a time
- Test after each change
- Verify build still works before next change

### 5. Working Rollback Strategy

**Current State**: No systematic rollback plan

**Needed**:

- Always keep known-good generation accessible
- Document rollback commands
- Test rollback procedure

### 6. Error Message Capture

**Current State**: "builder failed with exit code 1" is all we see

**Needed**:

- System should show actual compilation/linking error
- Parse and surface meaningful error messages
- Link to troubleshooting documentation

---

## 🚀 TOP #25 NEXT THINGS TO DO

### Immediate Priority (1-10)

1. **[BLOCKING]** Get actual darwin-rebuild error from build output
2. **[BLOCKING]** Fix that specific error (whatever it is)
3. Re-enable `micro-full` with platform guards or find alternative
4. Re-enable `cliphist` (Darwin-compatible version or alternative)
5. Re-enable Helium browser (Darwin version already created)
6. Re-enable Google Chrome (if still desired)
7. Complete `darwin-rebuild build` successfully
8. Run `darwin-rebuild switch` to activate new generation
9. Test system after activation (CLI tools, applications)
10. Fix post-activation issues (if any)

### Medium Priority (11-17)

11. Enable sandbox (test with proper configuration or relaxed mode)
12. Squash git commits (clean up "temp" commits)
13. Document all changes with rationale (docs/changes.md)
14. Create backup of working configuration
15. Set up rollback procedure and document it
16. Verify all CLI tools work (git, fish, starship, etc.)
17. Test GUI applications (Chrome, Helium, etc.)

### Lower Priority (18-25)

18. Verify system paths (nix-darwin expected paths)
19. Check GC settings (garbage collection configuration)
20. Optimize disk usage (清理 old generations)
21. Set up auto-update mechanism
22. Create troubleshooting guide for future issues
23. Test on fresh macOS installation (if possible)
24. Share configuration with community
25. Plan future compatibility (macOS 16+, nix-darwin versions)

---

## ❓ TOP #1 QUESTION I CANNOT FIGURE OUT

**Question**: WHY does darwin-rebuild keep failing even after we've removed all obvious Wayland/Platform-specific evaluation errors?

**Details**:

- Build evaluation now works (was failing before with Wayland errors) ✅
- Build process starts and runs for several minutes ✅
- But it still fails with "builder failed with exit code 1" ❌
- **We don't know what's actually failing**:
  - Is it compilation error?
  - Is it linking error?
  - Is it missing dependency?
  - Is it configuration error?

**Why This is Critical**:

- Cannot fix the actual error without knowing what it is
- Trial-and-error approach is wasting time
- Need ACTUAL error message to proceed

**Investigation Needed**:

- Capture full build output (not just tail)
- Check build logs in `/nix/var/log/nix/`
- Use `--show-trace` to see full stack
- Check for specific failing derivation
- Examine failed build directories

---

## Technical Details

### System Information

```bash
OS: macOS Sequoia (15.x)
Architecture: aarch64-darwin
Nix Version: 2.31.2
nix-darwin Version: 26.05
Home Manager Version: Latest in flake
```

### Known Working Configuration

**Generation**: 205
**Sandbox**: Disabled
**Settings**: Minimal defaults
**Status**: Bootable and functional

### Current Issues

1. Build starts but doesn't complete
2. Unknown error during build phase
3. Cannot easily capture build output
4. Background execution complicates debugging

### Files Modified

- `platforms/common/packages/helium-darwin.nix` (created)
- `platforms/common/packages/helium-linux.nix` (created)
- `platforms/common/packages/helium.nix` (deleted)
- `platforms/common/packages/base.nix` (modified)
- `platforms/common/modules/ghost-wallpaper.nix` (modified)
- `platforms/darwin/nix/settings.nix` (simplified)

---

## Next Actions

### BLOCKING: Get Build Error

```bash
# Capture full output
darwin-rebuild build --flake ./. --show-trace --print-build-logs 2>&1 | tee /tmp/darwin-build-full.log

# Check failed builds
ls -la /nix/var/nix/builds/ | grep -i failed

# Examine build logs
find /nix/var/log/nix -name "*.log" -exec tail -100 {} \;
```

### Once Error is Known

1. Fix the specific error
2. Test build again
3. Repeat until successful
4. Activate with `darwin-rebuild switch`
5. Verify system functionality

---

**Report Generated**: 2025-12-29 01:25 UTC
**Status**: 🟡 IN PROGRESS - Awaiting build error diagnosis
