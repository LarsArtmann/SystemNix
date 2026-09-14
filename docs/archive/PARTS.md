# SystemNix Component Analysis: Reusable Libraries & SDKs

> **Analysis Date:** 2026-02-25
> **Project:** SystemNix - Cross-Platform Nix Configuration
> **Purpose:** Identify components suitable for extraction as reusable libraries/SDKs

---

## Executive Summary

SystemNix contains **6 components** with extraction potential. Analysis reveals:

| Component                  | Extraction Value | Complexity | Recommendation                   |
| -------------------------- | ---------------- | ---------- | -------------------------------- |
| Nix Type Safety System     | **High**         | Medium     | Extract as `nix-types-lib`       |
| Error Management Framework | **High**         | Low        | Extract as `nix-error-lib`       |
| Hyprland Type Safety       | Medium           | Low        | Extract as `nix-hyprland-types`  |
| Package Building Patterns  | Low              | Low        | Document patterns, don't extract |
| Cross-Shell Alias System   | Low              | Very Low   | Keep in Home Manager ecosystem   |
| System Scripts             | Medium           | Medium     | Extract as `nix-health-checker`  |

**Recommended Priority:** Error Management Framework → Type Safety System → Hyprland Types

---

## 1. Nix Type Safety System

**Location:** `platforms/common/core/{Types,Validation,State}.nix`

### Description

A comprehensive type safety framework for Nix configurations providing:

- **Type Definitions** (`Types.nix`): `ValidationLevel`, `Platform`, `PackageValidator`, `ValidationRule`, `SystemState`
- **Validation Functions** (`Validation.nix`): Platform validation (darwin/linux/aarch64/x86_64), license validation, dependency validation
- **State Management** (`State.nix`): Centralized path config, package config, validation functions

### Code Example

```nix
# Current usage in SystemNix
{lib, ...}: let
  inherit (import ./core/Types.nix {inherit lib;}) ValidationLevel Platform ValidationRule;
  inherit (import ./core/Validation.nix {inherit lib;}) validateDarwin validateLinux;
in {
  # Type-safe configuration
  system.validation = {
    level = "strict";  # Type-checked against ValidationLevel enum
    rules = [ ... ];   # Type-checked against ValidationRule
  };
}
```

### Alternatives

| Alternative                  | Description              | Limitations                                        |
| ---------------------------- | ------------------------ | -------------------------------------------------- |
| `nixpkgs.lib.types`          | Built-in Nix type system | Limited to basic types, no custom validation rules |
| `nix-schema`                 | JSON Schema for Nix      | External dependency, different paradigm            |
| Nix Flakes `nix flake check` | Built-in validation      | Runtime only, no compile-time type safety          |
| **None**                     | No standard exists       | This is a gap in the Nix ecosystem                 |

### Unique Value Proposition

1. **Compile-Time Safety**: Catches configuration errors before build, not during
2. **Composable Validation Rules**: `ValidationRule` type allows custom validators with `autoFix` capability
3. **Platform-Aware**: Built-in support for darwin/linux/aarch64/x86_64 validation
4. **Declarative Error Messages**: Type-safe error message generation with context enrichment
5. **System State Tracking**: `SystemState` type for performance tuning (maxConcurrentBuilds, buildTimeout)

### Extraction Recommendation

**Extract as:** `github.com/larsartmann/nix-types-lib`

**Structure:**

```
nix-types-lib/
├── flake.nix
├── lib/
│   ├── types.nix        # Core type definitions
│   ├── validation.nix   # Validation functions
│   ├── state.nix        # State management
│   └── default.nix      # Public API
├── tests/
│   └── validation.nix   # Property-based tests
└── README.md
```

**API Design:**

```nix
# Consumer usage
{lib, nix-types-lib, ...}: {
  imports = [ nix-types-lib.modules.default ];

  system.types = nix-types-lib.types;
  system.validation = nix-types-lib.validation;
}
```

---

## 2. Error Management Framework

**Location:** `platforms/common/errors/ErrorManagement.nix`

### Description

A type-safe error handling system with:

- **ErrorType Enum**: 12 error categories (validation, build, runtime, configuration, external, performance, dependency, platform, license, filesystem, network, rollback)
- **ErrorSeverity**: 5 levels (critical, high, medium, low, info)
- **ErrorCategory**: Type-safe category with auto-retry, rollbackable, notifyUser, logLevel, recoveryActions
- **ErrorHandler**: Centralized handler with context enrichment and recovery execution
- **ErrorCollector**: Batch error collection with analysis and reporting
- **ErrorMonitor**: Threshold-based alerting system

### Code Example

```nix
# Current usage
ErrorHandler {
  errorType = "build";
  errorCode = "compilation_failed";
  context = { packageName = "my-app"; };
  systemConfig = config;
}
# Returns: { error = {...}; log = {...}; recoveryActions = [...]; anyRecoverySuccessful = true/false; }

# Batch processing
ErrorCollector {
  errors = [error1 error2 error3];
  systemConfig = config;
}
# Returns: { errors = [...]; analysis = {...}; report = "markdown report"; }
```

### Alternatives

| Alternative                 | Description                          | Limitations                                |
| --------------------------- | ------------------------------------ | ------------------------------------------ |
| `builtins.throw`            | Native error throwing                | No categorization, no recovery actions     |
| `lib.assertMsg`             | Assertion with message               | Boolean only, no severity levels           |
| Nixpkgs `assert` statements | Basic assertions                     | No context enrichment, no batch processing |
| **None**                    | No structured error framework exists | **Major gap in Nix ecosystem**             |

### Unique Value Proposition

1. **Structured Error Types**: 12 predefined categories with consistent handling
2. **Recovery Actions**: Automatic recovery execution with success tracking
3. **Batch Processing**: `ErrorCollector` aggregates multiple errors with analysis
4. **Threshold Alerting**: `ErrorMonitor` triggers alerts based on error counts
5. **Context Enrichment**: Automatic timestamp, systemConfig, and recovery state tracking
6. **Report Generation**: Built-in markdown report generation for error summaries

### Extraction Recommendation

**Extract as:** `github.com/larsartmann/nix-error-lib`

**Priority: HIGH** - This fills a significant gap in the Nix ecosystem.

**Structure:**

```
nix-error-lib/
├── flake.nix
├── lib/
│   ├── types.nix         # ErrorType, ErrorSeverity, ErrorCategory
│   ├── handler.nix       # ErrorHandler
│   ├── collector.nix     # ErrorCollector
│   ├── monitor.nix       # ErrorMonitor
│   └── default.nix
├── examples/
│   └── basic-usage.nix
└── README.md
```

**API Design:**

```nix
# Consumer usage
{lib, nix-error-lib, ...}: {
  imports = [ nix-error-lib.modules.default ];

  # Access error handling
  system.errors = nix-error-lib;
}
```

---

## 3. Hyprland Type Safety Module

**Location:** `platforms/nixos/core/HyprlandTypes.nix`

### Description

Complete type definitions for Hyprland window manager configuration:

- **HyprlandConfig Type**: Full submodule with variables, monitor, workspaces, windowRules, keybindings, mouseBindings, general, decoration, animations, input, execOnce
- **Validation Function**: `validateHyprlandConfig` checks required variables, monitor format, workspace format, bezier curves
- **Helper Functions**: `mkKeybinding`, `mkWorkspace`, `mkWindowRule` for type-safe construction
- **Assertion Helpers**: `mkAssertion` for integration with Nix's assertion system
- **Nix Integration**: `toHyprlang` for converting Nix attrs to Hyprland config

### Code Example

```nix
# Current usage
{lib, hyprland-types, ...}: let
  inherit (hyprland-types) mkKeybinding mkWorkspace mkAssertion;
in {
  wayland.windowManager.hyprland = {
    settings = {
      "$mod" = "SUPER";
      bind = [
        (mkKeybinding "$mod" "Return" "exec, kitty")
      ];
    };
  };

  assertions = [ (mkAssertion config.wayland.windowManager.hyprland.settings) ];
}
```

### Alternatives

| Alternative                  | Description                   | Limitations                  |
| ---------------------------- | ----------------------------- | ---------------------------- |
| Home Manager Hyprland Module | Official Home Manager support | Basic options, no validation |
| nix-community/hyprland       | Flakes support                | Package only, no type safety |
| Manual Configuration         | Raw hyprland.conf             | No type safety, easy errors  |

### Unique Value Proposition

1. **Compile-Time Validation**: Catches invalid monitor/workspace formats before deployment
2. **Type-Safe Helpers**: `mkKeybinding` ensures correct format automatically
3. **Integrated Assertions**: Works with Nix's assertion system for deployment-time checks
4. **Complete Coverage**: All major Hyprland config sections typed
5. **Error Messages**: Human-readable error messages with emoji indicators

### Extraction Recommendation

**Extract as:** `github.com/larsartmann/nix-hyprland-types`

**Priority: MEDIUM** - Nice-to-have for Hyprland users.

**Note:** This is a domain-specific library with a smaller audience than the error/type systems.

---

## 4. Package Building Patterns

**Location:** `pkgs/`

### Description

Patterns for building custom Nix packages:

- **callPackage + fetchpatch Hybrid**: `pkgs/crush-patched/package.nix` demonstrates reproducible patch management from immutable GitHub URLs
- **Go 1.26 Overlay**: Custom overlay for Go 1.26rc2 via flake-parts
- **Binary Packaging**: `pkgs/superfile/default.nix` shows binary packaging pattern

### Code Example

```nix
# Pattern from crush-patched/package.nix
{ lib, buildGoModule, fetchurl, fetchpatch }:

buildGoModule rec {
  pname = "crush-patched";
  version = "v0.45.0";

  src = fetchurl {
    url = "https://github.com/charmbracelet/crush/archive/refs/tags/${version}.tar.gz";
    hash = "sha256:...";
  };

  patches = [
    # Immutable patch URLs - no local file corruption
    (fetchpatch {
      url = "https://github.com/charmbracelet/crush/commit/abc123.patch";
      hash = "sha256:...";
    })
  ];

  env = {
    GOEXPERIMENT = "greenteagc";
    CGO_ENABLED = "0";
  };
}
```

### Alternatives

| Alternative               | Description        | Limitations                        |
| ------------------------- | ------------------ | ---------------------------------- |
| `nixpkgs` `callPackage`   | Standard pattern   | Patches typically from local files |
| NUR (Nix User Repository) | Community packages | Shared repository, different goals |
| `flake-utils`             | Flake helpers      | Build patterns not included        |

### Value Assessment

**Extraction Value: LOW**

These are **patterns**, not libraries. The value is in documentation, not extraction:

1. **fetchpatch Pattern**: Documented approach for reproducible patches
2. **Go Overlay Pattern**: Documented approach for experimental Go versions
3. **Binary Packaging Pattern**: Documented approach for proprietary software

### Recommendation

**Do NOT extract.** Instead:

1. Create `docs/packaging-patterns.md` documenting these patterns
2. Contribute patterns to `nixpkgs` documentation if novel
3. Consider blog post or NixOS Discourse sharing

---

## 5. Cross-Shell Alias System

**Location:** `platforms/common/programs/shell-aliases.nix`

### Description

Define shell aliases once, use across Fish/Zsh/Bash:

```nix
_: {
  commonShellAliases = {
    l = "ls -laSh";
    t = "tree -h -L 2 -C --dirsfirst";
    gs = "git status";
    gd = "git diff";
  };
}
```

### Alternatives

| Alternative                  | Description            | Limitations          |
| ---------------------------- | ---------------------- | -------------------- |
| Home Manager `shellAliases`  | Built-in option        | Already using this   |
| `programs.bash.shellAliases` | Per-shell options      | Duplication required |
| POSIX aliases                | Manual `.aliases` file | No Nix integration   |

### Value Assessment

**Extraction Value: LOW**

This is a **thin wrapper** around Home Manager's existing `shellAliases` option. The implementation is ~20 lines.

### Recommendation

**Do NOT extract.** Keep within Home Manager ecosystem:

1. Home Manager already provides `shellAliases` for all shells
2. No additional value in wrapping further
3. Keep as internal convenience module

---

## 6. System Health Check Script

**Location:** `scripts/health-check.sh`

### Description

Comprehensive system health monitoring script with:

- **Resource Checks**: CPU, Memory, Disk usage with configurable thresholds
- **Shell Performance**: Startup time measurement
- **Nix Health**: Daemon status, configuration validity, store integrity
- **Development Tools**: Git, Go, Bun, Homebrew status
- **Network Connectivity**: Internet, DNS, specific service checks
- **Security Tools**: Little Snitch, LuLu, Secretive, SIP status
- **Alerting**: Console, log file, email, webhook notifications
- **Exit Codes**: 0 (healthy), 1 (alerts), 2 (warnings)

### Code Example

```bash
# Usage examples
./scripts/health-check.sh                           # Basic check
./scripts/health-check.sh --comprehensive           # Full analysis
./scripts/health-check.sh --alert --verbose         # Alerting mode
./scripts/health-check.sh --cpu-threshold 70        # Custom thresholds
./scripts/health-check.sh --alert-email admin@...   # Email alerts
./scripts/health-check.sh --alert-webhook https://... # Webhook alerts
```

### Alternatives

| Alternative    | Description           | Limitations                |
| -------------- | --------------------- | -------------------------- |
| `nix doctor`   | Nix-specific health   | Nix only, no system checks |
| `brew doctor`  | Homebrew health       | Homebrew only              |
| Nagios/Icinga  | Enterprise monitoring | Overkill for personal use  |
| Custom scripts | Ad-hoc solutions      | No standardization         |

### Unique Value Proposition

1. **Nix-Aware**: Understands Nix daemon, store, configuration
2. **Multi-Platform**: Works on macOS (Darwin) and Linux
3. **Configurable Thresholds**: CLI flags for all thresholds
4. **Multiple Alert Channels**: Console, log, email, webhook
5. **Comprehensive Coverage**: System, Nix, development tools, security
6. **Structured Output**: JSON-ready exit codes for automation

### Extraction Recommendation

**Extract as:** `github.com/larsartmann/nix-health-checker`

**Priority: MEDIUM**

**Structure:**

```
nix-health-checker/
├── flake.nix
├── scripts/
│   └── health-check.sh
├── modules/
│   └── default.nix      # NixOS/Home Manager integration
├── tests/
│   └── integration.bats
└── README.md
```

**API Design:**

```nix
# NixOS integration
{config, nix-health-checker, ...}: {
  imports = [ nix-health-checker.nixosModules.default ];

  services.nix-health-checker = {
    enable = true;
    schedule = "daily";
    thresholds = {
      cpu = 80;
      memory = 85;
      disk = 90;
    };
    alerts = {
      email = "admin@example.com";
      webhook = "https://hooks.slack.com/...";
    };
  };
}
```

---

## Extraction Roadmap

### Phase 1: High Priority (Immediate)

1. **nix-error-lib**
   - Extract `ErrorManagement.nix` → standalone flake
   - Add tests, documentation, examples
   - Publish to Flake Registry

2. **nix-types-lib**
   - Extract `Types.nix`, `Validation.nix`, `State.nix` → standalone flake
   - Add property-based tests
   - Document API thoroughly

### Phase 2: Medium Priority (Next Quarter)

3. **nix-health-checker**
   - Extract `health-check.sh` → standalone project
   - Add NixOS/Home Manager modules
   - Add Linux support (currently macOS-focused)

4. **nix-hyprland-types**
   - Extract `HyprlandTypes.nix` → standalone flake
   - Add more validation rules
   - Coordinate with Home Manager Hyprland module

### Phase 3: Documentation (Ongoing)

5. **Packaging Patterns**
   - Document in `docs/packaging-patterns.md`
   - Consider upstream contributions to nixpkgs

---

## Library Policy Compliance

Per `HOW_TO_GOLANG.md` principles (adapted for Nix):

| Principle                        | Application                                        |
| -------------------------------- | -------------------------------------------------- |
| **Type Safety First**            | All extracted libraries use strong types           |
| **Errors as Values**             | `nix-error-lib` provides structured error handling |
| **Composition Over Inheritance** | Libraries designed for composition                 |
| **Dogfooding First**             | SystemNix consumes its own extracted libraries     |
| **No Reinventing the Wheel**     | Only extract where no alternative exists           |

### What NOT to Extract

Following the "established libs > custom solutions" principle:

1. **Shell aliases**: Home Manager already provides this
2. **Package patterns**: Document, don't extract
3. **Standard Nix functions**: Don't wrap `lib.types` unnecessarily

---

## Conclusion

SystemNix contains valuable abstractions that could benefit the broader Nix ecosystem:

| Library            | Fills Ecosystem Gap | Extraction Effort | Community Value |
| ------------------ | ------------------- | ----------------- | --------------- |
| nix-error-lib      | **Yes**             | Low               | **High**        |
| nix-types-lib      | Partial             | Medium            | Medium          |
| nix-health-checker | Partial             | Medium            | Medium          |
| nix-hyprland-types | No                  | Low               | Low             |

**Recommendation:** Prioritize `nix-error-lib` extraction as it fills a significant gap in the Nix ecosystem with minimal effort. The error management framework provides structured error handling, recovery actions, and batch processing - capabilities that don't exist in any standard Nix library.
