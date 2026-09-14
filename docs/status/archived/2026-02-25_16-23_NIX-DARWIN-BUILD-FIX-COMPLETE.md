# Nix-Darwin Build Fix Complete

**Date:** 2026-02-25 16:23
**Status:** Resolved
**Priority:** Critical

---

## Executive Summary

Successfully resolved nix-darwin build failure caused by nixpkgs updating golangci-lint to use `buildGo126Module`. The fix has been committed and applied to the system.

---

## Problem

```
error: function 'anonymous lambda' called with unexpected argument 'buildGo125Module'
Did you mean buildGo126Module?
```

**Root Cause:** nixpkgs updated golangci-lint package to expect `buildGo126Module` instead of `buildGo125Module`.

---

## Solution

**File:** `platforms/darwin/default.nix` (line 83)

```diff
- buildGo125Module = prev.buildGoModule.override {inherit (final) go;};
+ buildGo126Module = prev.buildGoModule.override {inherit (final) go;};
```

---

## Build Results

**Completed Successfully:**

- 15 derivations built
- System configuration applied
- Home Manager activated
- LaunchAgents reloaded
- Homebrew bundle complete (headlamp)

**Packages Rebuilt:**

- terraform-1.14.5
- yq-go-4.52.4
- otel-tui-v0.7.1
- tsgolint-0.11.5
- kubectl-1.35.0
- pre-commit-4.5.1
- buf-1.64.0
- oxlint-1.49.0
- python3.13-gftools-0.9.991
- jetbrains-mono-2.304

---

## Commit

```
5e82151 fix(darwin): resolve nix-darwin build failure with golangci-lint Go module builder mismatch
```

**Files Changed:**

- `platforms/darwin/default.nix` - buildGo125Module → buildGo126Module
- `docs/status/2026-02-25_15-04_NIX-DARWIN-BUILD-FIX-GO-MODULE-BUILDER-MISMATCH.md` - Status report

---

## Current System State

| Component      | Version                            |
| -------------- | ---------------------------------- |
| Go             | 1.26rc2 (from previous generation) |
| golangci-lint  | 2.8.0 (built with go1.26rc2)       |
| darwin-rebuild | 26.05.3bfa436                      |

**Note:** Go 1.26.0 stable is configured but may require new shell session to reflect updated version.

---

## Architecture Context

### Go Overlay Pattern

1. **flake.nix:** Defines `go = pkgs.go_1_26` and `buildGo126Module` wrapper
2. **platforms/darwin/default.nix:** Per-package overrides for golangci-lint
3. **Result:** All Go tools built with consistent Go 1.26 version

### Why Per-Package Overrides?

nixpkgs packages explicitly specify their builder (e.g., `buildGo126Module`). Simply overriding `go` globally doesn't affect packages that hardcode their builder. Each package needing the custom Go version must be overridden individually.

---

## Lessons Learned

1. **nixpkgs Go builder names are versioned** - They change when nixpkgs updates
2. **`nh` tool issues** - `nh darwin build . --verbose` hangs; use direct `nix build` or `just switch`
3. **Build verification order:** `nix eval` → `nix build --no-link` → `just switch`

---

## Follow-up Tasks

- [ ] Verify `go version` shows 1.26.0 (may need new shell)
- [ ] Verify `golangci-lint version` shows Go 1.26.0
- [ ] Check NixOS evo-x2 config for similar issue
- [ ] Run `just health` for full system validation

---

_Generated: 2026-02-25 16:23_
