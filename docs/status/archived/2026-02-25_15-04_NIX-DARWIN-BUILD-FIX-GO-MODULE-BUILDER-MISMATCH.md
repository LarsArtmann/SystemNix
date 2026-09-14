# nix-darwin Build Fix: Go Module Builder Version Mismatch

**Date:** 2026-02-25 15:04
**Status:** Build In Progress
**Priority:** Critical
**Session Continuation:** Yes (previous session exceeded context limit)

---

## Executive Summary

Fixed nix-darwin build failure caused by nixpkgs updating golangci-lint to expect `buildGo126Module` instead of `buildGo125Module`. The build is currently running in background (Shell ID: 007).

---

## Problem Statement

### Error Encountered

```
error: function 'anonymous lambda' called with unexpected argument 'buildGo125Module'
Did you mean buildGo126Module?
```

### Root Cause

- nixpkgs golangci-lint package was updated to use `buildGo126Module` (Go 1.26)
- Our overlay in `platforms/darwin/default.nix` was still passing `buildGo125Module`
- This caused a function argument mismatch during evaluation

### Timeline

1. **Previous session:** Go 1.26.0 stable was successfully integrated
2. **Flake update:** nixpkgs updated, changing golangci-lint's expected builder
3. **Build failure:** `buildGo125Module` argument no longer accepted
4. **Fix applied:** Changed to `buildGo126Module`

---

## Solution

### File Modified

**`platforms/darwin/default.nix`** (lines 80-86)

```diff
 (final: prev: {
   # Override golangci-lint to use Go 1.26 instead of default Go version
-  # golangci-lint uses buildGo125Module by default, we need to use our Go version
   golangci-lint = prev.golangci-lint.override {
-    buildGo125Module = prev.buildGoModule.override {inherit (final) go;};
+    buildGo126Module = prev.buildGoModule.override {inherit (final) go;};
   };
 })
```

### Why This Works

- golangci-lint in nixpkgs now expects `buildGo126Module` as its builder argument
- We override that builder to use our custom Go 1.26 package
- This ensures golangci-lint is built with our overridden Go version, not nixpkgs default

---

## Build Status

### Current State

- **Background Shell:** 007
- **Command:** `just switch` (darwin-rebuild switch --flake ./ --print-build-logs)
- **Status:** Running - building system configuration
- **Progress:** Evaluation passed, building derivations

### Packages Confirmed Building with Go 1.26

From previous build attempt (Shell 006):

| Package                  | Version | Status   |
| ------------------------ | ------- | -------- |
| carapace                 | 1.6.0   | Building |
| docker-compose           | 5.0.2   | Building |
| esbuild                  | 0.27.2  | Building |
| gh                       | 2.87.2  | Building |
| gofumpt                  | 0.9.2   | Building |
| golangci-lint-langserver | 0.0.12  | Building |
| k9s                      | 0.50.18 | Building |

### Build Statistics (from Shell 006)

- **Derivations to build:** 72
- **Paths to fetch:** 223 (~895 MiB download, ~4.6 GiB unpacked)

---

## Current System State

### Go Version (Active)

```
go version go1.26rc2 darwin/arm64
```

**Note:** Still showing rc2 from previous generation. After switch completes, should show 1.26.0.

### golangci-lint Version (Active)

```
golangci-lint has version 2.8.0 built with go1.26rc2
```

### Git Status

```
Changes not staged for commit:
	modified:   platforms/darwin/default.nix
```

**Commit needed after build succeeds.**

---

## Architecture Context

### Go Overlay Pattern

The project uses a layered overlay approach for Go version management:

1. **flake.nix:** Defines `go = pkgs.go_1_26` and `buildGo126Module` wrapper
2. **platforms/darwin/default.nix:** Per-package overrides for tools that need custom builders
3. **Result:** All Go tools built with consistent Go 1.26 version

### Why Per-Package Overrides?

- nixpkgs packages explicitly specify which builder they need (e.g., `buildGo126Module`)
- Simply overriding `go` globally doesn't affect packages that hardcode their builder
- Each package that needs the custom Go version must be overridden individually

### Files with Go Overlay Configuration

| File                              | Purpose                               |
| --------------------------------- | ------------------------------------- |
| `flake.nix:109`                   | `buildGo126Module` for darwin         |
| `flake.nix:163`                   | `buildGo126Module` for evo-x2 (NixOS) |
| `platforms/darwin/default.nix:83` | golangci-lint override                |

---

## Lessons Learned

### 1. nixpkgs Go Builder Names Are Versioned

- `buildGo125Module` → Go 1.25.x
- `buildGo126Module` → Go 1.26.x
- These names change when nixpkgs updates

### 2. `nh` Tool Issues

- `nh darwin build . --verbose` hangs with no output
- Workaround: Use direct `nix build` commands
- May be a buffering or initialization issue with nh 4.2.0

### 3. Build Verification Steps

1. `nix eval` - Quick syntax check
2. `nix build --no-link --print-build-logs` - Full build with output
3. `just switch` - Apply to system

---

## Remaining Tasks

### Immediate (After Build Completes)

- [ ] Verify build success
- [ ] Run `just switch` to apply
- [ ] Verify `go version` shows 1.26.0
- [ ] Verify `golangci-lint version` shows Go 1.26.0
- [ ] Commit the fix

### Follow-up

- [ ] Check NixOS evo-x2 config for same issue
- [ ] Run `just health` for full system validation
- [ ] Push commit to remote
- [ ] Update old docs referencing `buildGo125Module`

---

## Related Documentation

- `docs/status/2026-02-08_04-33_GO-1.26rc3-UPGRADE-CONFIGURATION-COMPLETE.md` - Previous Go upgrade
- `docs/status/2026-01-26_08-10_GO-VERSION-ALIGNMENT-AND-BUILD-FIX-COMPREHENSIVE-STATUS.md` - Original Go overlay architecture
- `AGENTS.md` - Project guidelines and patterns

---

## Technical Details

### Error Message (Full)

```
error: function 'anonymous lambda' called with unexpected argument 'buildGo125Module'
Did you mean buildGo126Module?
```

### Commands That Worked

```bash
# Quick evaluation check
nix eval .#darwinConfigurations.Lars-MacBook-Air.config.system.build.toplevel --json

# Build with visible output
nix build .#darwinConfigurations.Lars-MacBook-Air.config.system.build.toplevel --print-build-logs

# Apply to system (currently running)
just switch
```

### Commands That Failed/Hung

```bash
# Hung for 5+ minutes with no output
nh darwin build . --verbose
```

---

## Session Context

This is a continuation of a previous session that exceeded context limits. The original request was simply "FIX!" referring to the nix-darwin build failure.

**Previous Session Summary:**

- Task: Fix nix-darwin build failure
- Progress: Fix applied, build started
- Status: Build actively downloading and compiling packages

---

_Generated: 2026-02-25 15:04_
