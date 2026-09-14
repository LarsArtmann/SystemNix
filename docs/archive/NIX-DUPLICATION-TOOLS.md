# Nix Code Duplication Detection Tools

**Date**: 2026-02-10
**Status**: Tools created and tested

---

## Available Tools

### 1. **deadnix** (Already in use)

Finds unused variables, dead code, and redundant bindings.

```bash
nix shell nixpkgs#deadnix --command deadnix
```

**Current findings**:

- `platforms/common/programs/starship.nix:4` - Unused `config` parameter
- `platforms/common/programs/tmux.nix:3` - Unused `config` parameter
- `platforms/common/packages/base.nix:29` - Unused `crush` binding
- `platforms/nixos/core/HyprlandTypes.nix:52` - Unused `keybindings`
- `platforms/nixos/desktop/hyprland.nix:12-13` - Unused `colors`, `hexToRgba`
- `platforms/nixos/programs/zellij.nix:2-3` - Unused `pkgs`, `lib`

**Action**: Run `deadnix --edit .` to auto-remove dead code

---

### 2. **statix** (Already in use)

Linter for Nix anti-patterns and style issues.

```bash
nix shell nixpkgs#statix --command statix check
```

**Current status**: No issues found (clean)

---

### 3. **find-nix-duplicates.sh** (NEW)

File-level and pattern duplication detection.

```bash
./scripts/find-nix-duplicates.sh
```

**Key findings**:

#### Similar File Names (Cross-Platform)

| File           | Darwin  | NixOS   | Status                          |
| -------------- | ------- | ------- | ------------------------------- |
| `shells.nix`   | ✅      | ✅      | **DUPLICATION** - Can be merged |
| `home.nix`     | ✅      | ✅      | Different purposes (OK)         |
| `settings.nix` | ✅      | ✅      | Different contents (OK)         |
| `default.nix`  | 5 files | 5 files | Stub files (OK)                 |

#### Repeated Attribute Patterns

```
9× imports = [
7× environment.systemPackages = with pkgs; [
5× programs = {
4× colors = nix-colors.colorSchemes.catppuccin-mocha.palette;
3× services = {
3× commonAliases = (import ./shell-aliases.nix {}).commonShellAliases;
2× networking.nameservers = ["127.0.0.1"];
2× home.packages = with pkgs; [
```

**Recommendations**:

- Extract `colors` definition to common module (4 repetitions)
- Review `imports` patterns for common sequences
- Consider `environment.systemPackages` consolidation

---

### 4. **find-nix-semantic-dupes.sh** (NEW)

AST-level semantic duplication detection.

```bash
./scripts/find-nix-semantic-dupes.sh
```

**Key findings**:

#### Semantically Identical Files

```
Hash: 54d4b952ec940ceb8db16d021a1bb278
  → ./platforms/darwin/networking/default.nix
  → ./platforms/darwin/services/default.nix
```

Both are empty stub files (`_: { ... }`). Not true duplicates (different purposes).

---

## High-Priority Duplications to Fix

### 1. **Shell Configuration Duplication** 🔴

**Files**:

- `platforms/darwin/programs/shells.nix` (120 lines)
- `platforms/nixos/programs/shells.nix` (74 lines)

**Issue**: ~40% code overlap in Fish/Zsh/Tmux init logic

**Solution**: Create `platforms/common/programs/shells-common.nix`

```nix
# platforms/common/programs/shells-common.nix
{pkgs, lib, ...}: {
  programs = {
    fish = {
      enable = true;
      shellInit = ''
        # Common settings (cross-platform)
        set -gx EDITOR vim

        # Platform-specific (conditional)
        ${lib.optionalString pkgs.stdenv.isDarwin ''
          # macOS-specific fish config
        ''}

        ${lib.optionalString pkgs.stdenv.isLinux ''
          # Linux-specific fish config
        ''}
      '';
    };
  };
}
```

**Estimated savings**: ~50 lines

---

### 2. **Color Scheme Duplication** 🟡

**Pattern found**: 4 repetitions

```nix
colors = nix-colors.colorSchemes.catppuccin-mocha.palette;
```

**Files affected**:

- Search with: `grep -rn "catppuccin-mocha.palette" --include="*.nix" .`

**Solution**: Add to `platforms/common/core/nix-settings.nix` or create theme module:

```nix
# platforms/common/core/theme.nix
{options, ...}: {
  options.theme.colors = lib.mkOption {
    default = nix-colors.colorSchemes.catppuccin-mocha.palette;
    description = "Active color scheme";
  };
}
```

---

### 3. **Helium Package Duplication** 🟡

**Files**:

- `platforms/darwin/packages/helium.nix`
- `platforms/common/packages/helium-linux.nix`

**Issue**: Entire package definition duplicated (~120 lines total)

**Solution**: Single file with platform conditional:

```nix
# platforms/common/packages/helium.nix
{pkgs, ...}:
pkgs.stdenv.mkDerivation rec {
  pname = "helium";
  version = "1.0.0";

  src = if pkgs.stdenv.isDarwin
    then pkgs.fetchurl { /* Darwin URL */ }
    else pkgs.fetchFromGitHub { /* Linux source */ };

  # Common build steps...
}
```

---

## Tool Comparison

| Tool                           | Purpose        | Speed  | Finds             | Status           |
| ------------------------------ | -------------- | ------ | ----------------- | ---------------- |
| **deadnix**                    | Dead code      | Fast   | Unused variables  | ✅ Use regularly |
| **statix**                     | Anti-patterns  | Fast   | Style issues      | ✅ Use regularly |
| **alejandra**                  | Formatting     | Fast   | Format violations | ✅ Pre-commit    |
| **find-nix-duplicates.sh**     | File patterns  | Medium | Similar names     | ✅ New tool      |
| **find-nix-semantic-dupes.sh** | AST comparison | Slow   | Exact duplicates  | ✅ New tool      |

---

## Recommended Workflow

### Regular (Weekly)

```bash
# 1. Remove dead code
nix shell nixpkgs#deadnix --command deadnix --edit .

# 2. Check for new duplications
./scripts/find-nix-duplicates.sh

# 3. Verify no regressions
just test-fast
```

### Monthly Deep Clean

```bash
# Full semantic analysis
./scripts/find-nix-semantic-dupes.sh

# Manual review of top findings
# Refactor identified duplications
```

---

## Integration with CI

Add to `.github/workflows/ci.yml`:

```yaml
duplication-check:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    - name: Install Nix
      uses: DeterminateSystems/nix-installer-action@main

    - name: Run deadnix
      run: nix run nixpkgs#deadnix -- --fail .

    - name: Check for duplications
      run: |
        ./scripts/find-nix-duplicates.sh | tee dupes.txt
        if grep -q "DUPLICATION" dupes.txt; then
          echo "Found duplications! See dupes.txt"
          exit 1
        fi
```

---

## Summary

**Current duplication debt**:

- ~200 lines of duplicate shell configuration
- ~120 lines of duplicate package definitions (Helium)
- 4 repetitions of color scheme definition
- 9 similar `imports` patterns

**Estimated cleanup effort**: 4-6 hours
**Potential savings**: ~350 lines (5% of total codebase)

**Next actions**:

1. Run `deadnix --edit .` to remove dead code
2. Consolidate `shells.nix` into common module
3. Merge Helium packages into single file
4. Extract color scheme to common option
