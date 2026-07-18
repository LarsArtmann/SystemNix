# Session 11: golangci-lint-auto-configure Integration & Go CLI Tool Audit

**Date:** 2026-05-01 04:14
**Focus:** Integrate golangci-lint-auto-configure, audit all 18 Go CLI tool packages

---

## Summary

Integrated `golangci-lint-auto-configure` as a cross-platform Nix package, then performed a deep audit of all 18 recently-added Go CLI tool packages. Discovered significant build failures across the fleet.

---

## a) FULLY DONE ✅

### golangci-lint-auto-configure Integration (PRIMARY TASK)

- **Package:** `pkgs/golangci-lint-auto-configure.nix` — full `buildGoModule` derivation
- **Flake inputs:** `golangci-lint-auto-configure-src` + `go-finding-src` as local path inputs
- **Overlay:** `golangciLintAutoConfigureOverlay` in shared overlays (both Darwin + NixOS)
- **Installed:** In `platforms/common/packages/base.nix` developmentPackages
- **Justfile:** `lint-configure` and `lint-configure-version` recipes
- **Build:** ✅ Passes on both `x86_64-linux` and `aarch64-darwin`
- **CLI tested:** `--version` ✅, `configure --detect --dry-run` ✅, `analyze` ✅
- **Hardening:** `env.GOWORK = "off"`, `proxyVendor = true`, `CGO_ENABLED = 0`

### Infrastructure Improvements

- **`cleanGoSource` helper:** Fixed `prev.lib` → `nixpkgs.lib` (was broken outside overlay scope), added `.md`, `go.work`, `go.work.sum` filtering
- **Vendor hash fixes:** Resolved placeholder hashes for `branching-flow`, `go-auto-upgrade`, `go-functional-fixer`, `go-structure-linter`, `md-go-validator`, `art-dupl`, `auto-deduplicate`, `buildflow`, `code-duplicate-analyzer`, `hierarchical-errors`, `terraform-to-d2`
- **Dependency wiring:** Fixed `hierarchical-errors` missing `go-branded-id` + `gogenfilter` replace directives

### AGENTS.md Updated

- Architecture tree: added `golangci-lint-auto-configure.nix`
- Flake inputs table: added `golangci-lint-auto-configure-src` + `go-finding-src`
- Essential commands: added `lint-configure` and `lint-configure-version`

---

## b) PARTIALLY DONE 🔧

### Go CLI Tool Fleet (18 packages total)

| Status          | Count | Packages                                                                                                                        |
| --------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------- |
| ✅ Build passes | 7     | `art-dupl`, `branching-flow`, `go-structure-linter`, `hierarchical-errors`, `library-policy`, `md-go-validator`, `project-meta` |
| ❌ Build fails  | 10    | See section d)                                                                                                                  |
| ⚠️ Not exposed  | 1     | `mr-sync` (overlay exists but not in perSystem.packages)                                                                        |

---

## c) NOT STARTED 📋

1. Fix the 10 failing Go CLI tool packages (upstream source issues, not Nix issues)
2. Add `mr-sync` to perSystem.packages output
3. Install remaining Go CLI tools in base.nix (only `golangci-lint-auto-configure` + `mr-sync` installed)
4. `go-finding-src` as a shared utility — consider extracting a shared `go-dependencies.nix` lib
5. Shared Go package template to reduce boilerplate across 18 packages

---

## d) TOTALLY FUCKED UP 💥

### 10 Go CLI Tools That FAIL to Build

| Package                          | Root Cause                                                                                     | Fix Location                     |
| -------------------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------- |
| `auto-deduplicate`               | `go mod tidy` needed — upstream go.mod out of sync                                             | Upstream `auto-deduplicate` repo |
| `buildflow`                      | Missing subpackage `modules/binary-checker` — upstream code removed but go.mod references it   | Upstream `buildflow` repo        |
| `code-duplicate-analyzer`        | `go mod tidy` needed — upstream go.mod out of sync                                             | Upstream repo                    |
| `go-auto-upgrade`                | Test failure `internal/migrators/jsonv1tov2`                                                   | Upstream repo                    |
| `go-functional-fixer`            | Missing subpackage `libs/go-functional-fixer/doubleerror-linter`                               | Upstream repo                    |
| `projects-management-automation` | Cannot fetch `gogenfilter@v0.2.0` via SSH in sandbox — needs `GOPRIVATE` + `GIT_CONFIG_GLOBAL` | Package `.nix` file              |
| `template-readme`                | Compilation error: `no new variables on left side of :=`                                       | Upstream repo                    |
| `terraform-diagrams-aggregator`  | Vendor hash mismatch — upstream deps changed                                                   | Package `.nix` file              |
| `terraform-to-d2`                | `go mod tidy` needed — upstream go.mod out of sync                                             | Upstream repo                    |
| `mr-sync`                        | Not exposed in `perSystem.packages` at all                                                     | `flake.nix`                      |

**Key insight:** 7 of 10 failures are **upstream source issues** (stale go.mod, missing packages, test failures, compilation errors). Only 3 are fixable in our Nix packaging:

- `projects-management-automation`: needs `GOPRIVATE` + `GIT_CONFIG_GLOBAL` (like `art-dupl` pattern)
- `terraform-diagrams-aggregator`: needs vendor hash update
- `mr-sync`: just needs to be added to packages output

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Shared Go dependency inputs** — `go-finding-src`, `cmdguard-src`, `go-output-src` repeated across 18 packages. Extract to `lib/go-deps.nix`
2. **Package template** — 18 near-identical `.nix` files. Create a `mkGoPackage` helper function
3. **`cleanGoSource` in flake.nix** — Helper function in the `let` block is 500+ lines from the overlays that use it. Move to `lib/`
4. **Missing `GOWORK=off`** on packages using `go-finding-src` — only `golangci-lint-auto-configure` has it (4 others don't, but currently build fine)
5. **Pre-commit hook `go.mod`** — Staged `go.mod` at repo root that shouldn't be there

### Type Models / Patterns

6. **buildGoModule pattern consistency** — Some packages use `subPackages`, some don't. Some use `ldflags`, some don't. Inconsistent.
7. **Source filter duplication** — Each package defines its own `lib.cleanSourceWith` filter. Should use `cleanGoSource` from flake.nix or a shared lib.
8. **Version management** — All tools use `version = "0.0.0"` except `golangci-lint-auto-configure` which uses `"0.1.0"`. Should derive from git tags or use consistent pattern.

### Observability

9. **No CI for Go CLI tool builds** — These packages can silently break. Need `nix build` checks.
10. **Build status not tracked** — Should add a justfile recipe `just go-tools-check` that builds all and reports status.

---

## f) Top 25 Things We Should Do Next (sorted by impact / effort)

| #   | Task                                                            | Impact | Effort            | Type        |
| --- | --------------------------------------------------------------- | ------ | ----------------- | ----------- |
| 1   | Remove staged `go.mod` from repo root                           | High   | Tiny              | Fix         |
| 2   | Add `mr-sync` to perSystem.packages                             | High   | Tiny              | Fix         |
| 3   | Fix `projects-management-automation` GOPRIVATE/GIT_CONFIG       | Medium | Small             | Fix         |
| 4   | Fix `terraform-diagrams-aggregator` vendor hash                 | Medium | Tiny              | Fix         |
| 5   | Add `just go-tools-check` recipe to build all Go tools          | High   | Small             | Feature     |
| 6   | Create `mkGoPackage` helper to reduce 18-file boilerplate       | High   | Medium            | Refactor    |
| 7   | Extract `cleanGoSource` to `lib/go-source.nix`                  | Medium | Small             | Refactor    |
| 8   | Extract shared Go dep inputs to `lib/go-deps.nix`               | Medium | Small             | Refactor    |
| 9   | Fix `go mod tidy` in upstream `auto-deduplicate` repo           | Medium | Small (upstream)  | External    |
| 10  | Fix `go mod tidy` in upstream `code-duplicate-analyzer` repo    | Medium | Small (upstream)  | External    |
| 11  | Fix `go mod tidy` in upstream `terraform-to-d2` repo            | Medium | Small (upstream)  | External    |
| 12  | Fix missing subpackage in upstream `buildflow` repo             | Medium | Medium (upstream) | External    |
| 13  | Fix missing subpackage in upstream `go-functional-fixer` repo   | Medium | Medium (upstream) | External    |
| 14  | Fix compilation error in upstream `template-readme` repo        | Medium | Medium (upstream) | External    |
| 15  | Fix test failure in upstream `go-auto-upgrade` repo             | Medium | Medium (upstream) | External    |
| 16  | Add `GOWORK=off` to all 4 packages using `go-finding-src`       | Low    | Tiny              | Defensive   |
| 17  | Standardize `version` across all Go packages                    | Low    | Small             | Consistency |
| 18  | Add Go CLI tools to CI checks (nix build matrix)                | High   | Medium            | CI          |
| 19  | Install more Go CLI tools in base.nix based on utility          | Medium | Small             | Feature     |
| 20  | Add `just go-tool-versions` recipe showing all Go tool versions | Low    | Small             | Feature     |
| 21  | Consolidate overlay definitions in flake.nix (600+ lines)       | High   | Large             | Refactor    |
| 22  | Consider Go workspace for local development                     | Low    | Medium            | DevEx       |
| 23  | Add `.golangci.yml` to SystemNix repo for Go files              | Low    | Tiny              | Quality     |
| 24  | Document which Go CLI tools are installed vs available          | Medium | Tiny              | Docs        |
| 25  | Add `nixci` or `nix flake check` with actual builds             | High   | Large             | CI          |

---

## g) Top #1 Question

**Why is there a `go.mod` staged at the repo root?**

```
A  go.mod   (module github.com/LarsArtmann/SystemNix / go 1.26.2)
```

SystemNix is a Nix configuration repo, not a Go project. This file appeared in the staged changes from the concurrent session. I suspect it was auto-generated by a Go tool or IDE but shouldn't be committed. Can you confirm whether this should be removed?

---

## Commits This Session

| Hash      | Message                                                                 |
| --------- | ----------------------------------------------------------------------- |
| `4a9e4ff` | `fix(pkgs): resolve Go CLI tool vendor hashes and missing dependencies` |

## Pre-existing Staged Changes (from concurrent session, not yet committed)

- `.gitignore` — added `/SystemNix` build artifact
- `go.mod` — new file at repo root (likely should NOT be committed)
- Vendor hash fixes for: `auto-deduplicate`, `buildflow`, `code-duplicate-analyzer`, `hierarchical-errors`, `terraform-to-d2`
