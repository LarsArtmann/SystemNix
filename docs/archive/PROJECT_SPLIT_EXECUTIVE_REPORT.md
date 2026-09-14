# Project Split Executive Report: SystemNix

## Date: 2026-02-15

## Overview

This report outlines a proposed strategic split of the existing `SystemNix` project into multiple, more focused and manageable sub-projects. The current `SystemNix` repository serves as a monolithic configuration for both macOS (nix-darwin) and NixOS, encompassing core Nix logic, platform-specific configurations, dotfiles, utility scripts, and extensive documentation. While comprehensive, its monolithic nature can lead to increased complexity, slower development cycles, and challenges in maintaining clear boundaries.

The proposed split aims to enhance modularity, reduce cognitive load, improve maintainability, and facilitate independent development and testing of distinct system components.

## Current Project Scope (Monolithic `SystemNix`)

The existing `SystemNix` project broadly includes:

- Core Nix flake and build system (`flake.nix`, `justfile`)
- Cross-platform Nix modules (`platforms/common/`)
- Platform-specific Nix configurations (`platforms/darwin/`, `platforms/nixos/`)
- System and user dotfiles (`dotfiles/`)
- A large collection of utility and maintenance scripts (`scripts/`)
- Custom Nix packages (`pkgs/`)
- Comprehensive documentation (`docs/`)
- Development tooling and CI/CD configurations (`.github/`, `.githooks/`)

## Proposed Project Split

The `SystemNix` project can be logically decomposed into the following six highly focused projects:

### 1. `NixSystemCore`

- **Purpose**: To house the foundational Nix system components, providing a reusable and independent base for all declarative system configurations.
- **Contents**:
  - `flake.nix` (main entry point)
  - `justfile` (primary task runner)
  - `platforms/common/` (all cross-platform Nix modules and shared logic)
  - `pkgs/` (custom Nix packages that are general purpose)
  - `dotfiles/nix/core/` (core type safety and validation system)
- **Dependencies**: None (it is the base).
- **Rationale**: Establishes a clean, reusable Nix framework that other platform-specific configurations can depend on.

### 2. `NixDarwinConfig`

- **Purpose**: To manage all Nix configurations specifically tailored for macOS (nix-darwin).
- **Contents**:
  - `platforms/darwin/` (macOS-specific system and Home Manager configurations)
  - Relevant macOS-specific files from the original `dotfiles/nix/`
- **Dependencies**: Depends on `NixSystemCore`.
- **Rationale**: Isolates macOS-specific concerns, enabling faster iteration and reducing impact on other platforms.

### 3. `NixOSConfig`

- **Purpose**: To manage all Nix configurations specifically tailored for NixOS (Linux).
- **Contents**:
  - `platforms/nixos/` (NixOS-specific system and Home Manager configurations, including desktop environments like Hyprland)
  - Relevant NixOS-specific files from the original `dotfiles/nixos/`
- **Dependencies**: Depends on `NixSystemCore`.
- **Rationale**: Isolates NixOS-specific concerns, allowing for dedicated development and testing for the Linux environment.

### 4. `SystemDotfiles`

- **Purpose**: To centralize and manage user-level configuration files (dotfiles) for various applications and tools, independent of the core Nix system.
- **Contents**:
  - The contents of the current `dotfiles/` directory (e.g., `.zshrc.modular`, `ublock-origin/`, `sublime-text/`, `.ssh/`, `.config/waybar/`, `activitywatch/`)
  - These dotfiles could be symlinked or managed by Home Manager modules from `NixDarwinConfig` or `NixOSConfig`.
- **Dependencies**: Can be standalone, or integrated via platform-specific Nix configurations.
- **Rationale**: Decouples application configurations from system-level Nix management, making them potentially reusable in non-Nix environments or with different Nix setups.

### 5. `SystemScripts`

- **Purpose**: To host all general-purpose utility, maintenance, and development scripts.
- **Contents**:
  - The entire `scripts/` directory, potentially reorganized into logical subdirectories (e.g., `dev-tools/`, `maintenance/`, `benchmarks/`, `health-checks/`).
- **Dependencies**: May interact with `NixSystemCore` via `nix-shell` or similar mechanisms for environment setup.
- **Rationale**: Enables independent versioning, development, and improvement of scripts, making them a reusable toolkit separate from the system configuration.

### 6. `SystemDocs`

- **Purpose**: To provide a dedicated repository for all project documentation.
- **Contents**:
  - The entire `docs/` directory, including architecture records, troubleshooting guides, status reports, and planning documents.
- **Dependencies**: None.
- **Rationale**: Improves documentation discoverability, allows for independent tooling (e.g., static site generators), and separates informational content from executable code.

## Benefits of the Split

- **Improved Modularity**: Each project has a clear, singular responsibility.
- **Reduced Complexity**: Smaller codebases are easier to navigate and understand for developers.
- **Faster Iteration**: Changes in one area (e.g., NixOS desktop environment) do not necessitate recompiling or re-evaluating unrelated components (e.g., macOS security settings).
- **Enhanced Reusability**: Core components and generic dotfiles/scripts become more easily shareable.
- **Clearer Development Focus**: Teams or individuals can concentrate on specific areas without being overwhelmed by the entire system.
- **Decoupled Release Cycles**: Projects can be versioned and released independently.
- **Easier Onboarding**: New contributors can start with a smaller, more focused codebase.

## Conclusion

This proposed project split provides a strategic roadmap for evolving `SystemNix` into a more modular, maintainable, and scalable collection of declarative system configuration projects. By isolating concerns into focused repositories, we can unlock significant benefits in terms of development efficiency, code quality, and overall project governance. The transition would involve careful migration of files and adjustment of Nix import paths, but the long-term advantages would outweigh the initial effort.
