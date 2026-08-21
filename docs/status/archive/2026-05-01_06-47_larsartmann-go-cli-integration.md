# Status Report: LarsArtmann Go CLI Tool Integration

**Date:** 2026-05-01 06:47
**Session Duration:** ~3 hours
**Commits:** 4 (a517ec5, 2ad9010, c2db1b4, db38e2b)

---

## Executive Summary

Integrated 16 LarsArtmann Go CLI tools into SystemNix as cross-platform Nix overlays. Created a shared `mkGoTool` builder and centralized `go-replaces` dependency map to eliminate per-package boilerplate. **8 of 16 packages build successfully.** The remaining 8 are blocked by upstream bugs (3), `go mod tidy` requirements (3), and internal Go module resolution issues (2).

---

## A) FULLY DONE ✓

### Infrastructure (production-ready)

| Component               | Path                       | Description                                                                                                                                                   |
| ----------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mkGoTool` builder      | `pkgs/lib/mk-go-tool.nix`  | Shared `buildGoModule` wrapper: `proxyVendor`, `GOPRIVATE`, `GONOSUMCHECK`, replace management, `cleanGoSource`                                               |
| `go-replaces` map       | `pkgs/lib/go-replaces.nix` | Centralized module→Nix-store path mapping for ALL 25+ LarsArtmann Go modules                                                                                  |
| `cleanGoSource` helper  | `flake.nix:441`            | Source filter excluding `.git`, `node_modules`, `vendor`, `.md`, `.html`, `.svg`, `go.work`                                                                   |
| `larsGoToolsOverlay`    | `flake.nix:463`            | Single overlay replacing 16 individual overlays                                                                                                               |
| 16 package files        | `pkgs/*.nix`               | Each ~10 lines using `mkGoTool`                                                                                                                               |
| 16 flake inputs         | `flake.nix:146-243`        | `path:` sources for all projects                                                                                                                              |
| 9 shared lib inputs     | `flake.nix:146-243`        | `go-output`, `go-finding`, `cmdguard`, `go-branded-id`, `go-commit`, `go-filewatcher`, `project-discovery-sdk`, `gogenfilter`, `go-composable-business-types` |
| `packages` exposure     | `flake.nix perSystem`      | All 16 tools in `packages` attrset                                                                                                                            |
| `sharedOverlays` wiring | `flake.nix`                | Available on both macOS and NixOS                                                                                                                             |

### Building Packages (8/16)

| Package             | Binary                                                                 | Description                                                  |
| ------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------ |
| art-dupl            | `art-dupl`                                                             | Fast, type-safe code duplication detector                    |
| branching-flow      | `branching-flow`, `enum-cleanup`, `enum-detector`, `gitignore-checker` | Code quality analyzer (error context, type safety, patterns) |
| go-auto-upgrade     | `go-auto-upgrade`                                                      | Automated Go library migration tool                          |
| go-structure-linter | `go-structure-linter`                                                  | Go project structure validator                               |
| hierarchical-errors | `hierarchical-errors`                                                  | Error handling pattern analyzer                              |
| library-policy      | `library-policy`                                                       | Banned/vulnerable library detector                           |
| md-go-validator     | `md-go-validator`                                                      | Markdown code block validator (6 languages)                  |
| project-meta        | `meta`                                                                 | Per-project metadata management                              |

---

## B) PARTIALLY DONE

### Vendor hashes correct but build fails (8/16)

| Package                       | Error                | Root Cause                                 | Fix Effort |
| ----------------------------- | -------------------- | ------------------------------------------ | ---------- |
| auto-deduplicate              | `go mod tidy` needed | go.mod inconsistent after replace patching | Medium     |
| go-functional-fixer           | `go mod tidy` needed | go.mod inconsistent after replace patching | Medium     |
| terraform-diagrams-aggregator | `go mod tidy` needed | go.mod inconsistent after replace patching | Medium     |

### Needs upstream fix (3/16)

| Package                 | Error                                     | Root Cause                                                                      |
| ----------------------- | ----------------------------------------- | ------------------------------------------------------------------------------- |
| code-duplicate-analyzer | `no new variables on left side of :=`     | **Upstream compilation bug** in `cmd/code-duplicate-analyzer/config.go:294,298` |
| template-readme         | `no new variables on left side of :=`     | **Upstream compilation bug** in `pkg/validation/v3_validator.go:266,272,341`    |
| terraform-to-d2         | Missing `go-composable-business-types/id` | **Upstream**: local `go-composable-business-types` source missing `id/` package |

### Internal module resolution issues (2/16)

| Package                        | Error                                                  | Root Cause                                                 |
| ------------------------------ | ------------------------------------------------------ | ---------------------------------------------------------- |
| buildflow                      | `does not contain package .../modules/binary-checker`  | Internal Go workspace modules not resolving in Nix sandbox |
| projects-management-automation | `does not contain package .../pkg/coreutils/constants` | Same — internal workspace packages                         |

---

## C) NOT STARTED

| Task                              | Why                                                 |
| --------------------------------- | --------------------------------------------------- |
| Add tools to user PATH            | Need to add to `platforms/common/packages/base.nix` |
| Update AGENTS.md                  | Document new integrations, mkGoTool architecture    |
| Add `just` commands for new tools | Convenience commands like `just art-dupl`           |
| Test on macOS (aarch64-darwin)    | Only tested on x86_64-linux                         |
| Investigate `gomod2nix`           | Could auto-manage vendor hashes                     |
| Test `nix run .#<tool>`           | Verify run command works                            |
| Add CI checks for new packages    | Prevent regressions                                 |

---

## D) TOTALLY FUCKED UP

| Issue                         | Severity | Description                                                                                                                                                                                                                                                        |
| ----------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `go mod tidy` in FOD          | High     | `buildGoModule`'s go-modules fixed-output derivation runs BEFORE `preBuild`, so `go mod tidy` in `preBuild` doesn't affect vendor hash calculation. This means packages needing tidy can never match vendor hashes unless tidy is run during the go-modules phase. |
| Self-replace in `go-replaces` | Medium   | Originally included project's own module in `go-replaces`, causing Go to redirect the main module to itself. Fixed with sed removal, but was a significant time sink.                                                                                              |
| Transitive dep hell           | High     | Each project's `go.mod` transitively depends on other LarsArtmann libs. Had to map ALL transitive dependencies and provide them as Nix store replaces. The `go-replaces` approach solves this centrally but adds complexity.                                       |
| Case-sensitive module paths   | Medium   | Go module paths use mixed case (`github.com/LarsArtmann/` vs `github.com/larsartmann/`). `go-replaces` needed to handle both variants.                                                                                                                             |
| Internal Go workspace modules | Medium   | BuildFlow and PMA use Go workspace-internal modules (`./modules/...`, `./pkg/...`). These fail to resolve in the Nix sandbox despite correct replace directives. Root cause unclear.                                                                               |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **`gomod2nix`** — Well-established tool that auto-generates Nix derivations from go.mod. Would eliminate manual `vendorHash` management entirely. Evaluating this could save hours of hash debugging.
2. **`modPostBuild` hook** — nixpkgs `buildGoModule` supports `modPostBuild` which runs inside the go-modules FOD. This is where `go mod tidy` should go for the 3 packages that need it.
3. **`GOPROXY=off` with `GOFLAGS=-mod=mod`** — Alternative approach: disable Go module proxy entirely and rely only on replace directives. Would avoid all SSH/auth issues.
4. **Remove `GOPRIVATE`/`GONOSUMCHECK` from mkGoTool** — If ALL LarsArtmann deps have replace directives, Go never needs to reach GitHub, making these env vars unnecessary. Currently they're safety nets.
5. **Per-package `postPatch` for internal modules** — BuildFlow and PMA might need their internal module replaces explicitly preserved via per-package `postPatch` that runs AFTER the shared sed.

### Process

6. **Build one package end-to-end before wiring all 16** — Would have caught the self-replace and transitive dep issues much earlier.
7. **Use `nix build .#pkg 2>&1 | grep "got:"` pattern from the start** — Faster than manually setting hashes.
8. **Test with `--print-out-paths`** — The `--rebuild` flag requires previous builds and caused confusion.

---

## F) Top 25 Next Steps (sorted by impact × effort)

### Immediate — Unblock 3 more packages (2-3 hours)

| # | Task                                                                                                          | Impact      | Effort |
| - | ------------------------------------------------------------------------------------------------------------- | ----------- | ------ |
| 1 | Add `go mod tidy` via `modPostBuild` for auto-deduplicate, go-functional-fixer, terraform-diagrams-aggregator | +3 packages | Low    |
| 2 | Fix code-duplicate-analyzer upstream (`:=` → `=` in config.go:294,298)                                        | +1 package  | Low    |
| 3 | Fix template-readme upstream (`:=` → `=` in v3_validator.go:266,272,341)                                      | +1 package  | Low    |
| 4 | Investigate buildflow internal module resolution (debug with `ls` in build phase)                             | +1 package  | Medium |
| 5 | Investigate PMA internal module resolution                                                                    | +1 package  | Medium |

### Short-term — Make tools usable (1-2 hours)

| #  | Task                                                            | Impact | Effort |
| -- | --------------------------------------------------------------- | ------ | ------ |
| 6  | Add all 8 working tools to `platforms/common/packages/base.nix` | High   | Low    |
| 7  | Update AGENTS.md with mkGoTool architecture and new tools       | High   | Low    |
| 8  | Test all tools on macOS (aarch64-darwin)                        | Medium | Low    |
| 9  | Add `just` commands for each tool                               | Medium | Low    |
| 10 | Verify `nix run .#<tool>` works for all 8                       | Low    | Low    |

### Medium-term — Architecture improvements (3-5 hours)

| #  | Task                                                                  | Impact | Effort |
| -- | --------------------------------------------------------------------- | ------ | ------ |
| 11 | Evaluate `gomod2nix` as replacement for manual vendor hash management | High   | Medium |
| 12 | Add `modPostBuild` support to `mkGoTool` for tidy-needing packages    | Medium | Low    |
| 13 | Investigate `GOPROXY=off` approach to eliminate SSH issues            | High   | Medium |
| 14 | Add health check script that builds all tools and reports status      | Medium | Low    |
| 15 | Create a test derivation that runs each tool with `--help`            | Medium | Low    |

### Long-term — Robustness (2-4 hours)

| #  | Task                                                               | Impact     | Effort |
| -- | ------------------------------------------------------------------ | ---------- | ------ |
| 16 | Fix terraform-to-d2 upstream (update go-composable-business-types) | +1 package | Medium |
| 17 | Add `flake check` CI that validates all packages build             | High       | Medium |
| 18 | Investigate Go workspace support in nixpkgs `buildGoModule`        | Medium     | Medium |
| 19 | Extract `pkgs/lib/` into a reusable flake for other repos          | Low        | Medium |
| 20 | Add `nix run .#tool` apps for each tool                            | Low        | Low    |

### Cleanup (1 hour)

| #  | Task                                                                       | Impact | Effort |
| -- | -------------------------------------------------------------------------- | ------ | ------ |
| 21 | Remove unused `writeText` from package files (if any remain)               | Low    | Low    |
| 22 | Verify `golangci-lint-auto-configure` still builds (uses separate overlay) | Low    | Low    |
| 23 | Clean up any remaining `GIT_CONFIG_GLOBAL` references                      | Low    | Low    |
| 24 | Add `meta.mainProgram` verification                                        | Low    | Low    |
| 25 | Document the `go-replaces` update workflow for adding new tools            | Medium | Low    |

---

## G) Top #1 Question

**How should we handle `go mod tidy` inside the `buildGoModule` go-modules fixed-output derivation?**

The `modPostBuild` attribute in nixpkgs `buildGoModule` allows running commands inside the go-modules FOD (which has network access). This is where `go mod tidy` should go for the 3 failing packages. But `modPostBuild` is not currently exposed in our `mkGoTool` helper. Should I:

1. Add `modPostBuild` support to `mkGoTool` and enable it per-package?
2. Run `go mod tidy` in each project's source tree before building (fix go.sum upstream)?
3. Use `gomod2nix` which handles this automatically?

Option 2 (fix upstream go.sum) is the cleanest — a one-time `go mod tidy` in each project with the correct replaces would produce a consistent go.sum that Nix can use without tidy.

---

## Commits This Session

```
a517ec5 feat(niri,boot): harden niri service stability and raise system process limits
2ad9010 feat(pkgs): add shared library abstractions and refactor Go tool packages
c2db1b4 refactor(pkgs): extract mkGoTool shared builder and consolidate 16 Go CLI packages
db38e2b fix(pkgs): update vendor hashes and fix self-replace issue in mkGoTool
```

## Files Changed

| File                                      | Change                                                                                                     |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `flake.nix`                               | +16 path inputs, +9 lib inputs, `cleanGoSource`, `larsGoToolsOverlay`, `mkGoToolFor`, `go-replaces` wiring |
| `pkgs/lib/mk-go-tool.nix`                 | NEW — shared Go tool builder                                                                               |
| `pkgs/lib/go-replaces.nix`                | NEW — centralized replace directive map                                                                    |
| `pkgs/art-dupl.nix`                       | Rewritten with mkGoTool                                                                                    |
| `pkgs/auto-deduplicate.nix`               | Rewritten with mkGoTool                                                                                    |
| `pkgs/branching-flow.nix`                 | Rewritten with mkGoTool                                                                                    |
| `pkgs/buildflow.nix`                      | Rewritten with mkGoTool                                                                                    |
| `pkgs/code-duplicate-analyzer.nix`        | Rewritten with mkGoTool                                                                                    |
| `pkgs/go-auto-upgrade.nix`                | Rewritten with mkGoTool                                                                                    |
| `pkgs/go-functional-fixer.nix`            | Rewritten with mkGoTool                                                                                    |
| `pkgs/go-structure-linter.nix`            | Rewritten with mkGoTool                                                                                    |
| `pkgs/hierarchical-errors.nix`            | Rewritten with mkGoTool                                                                                    |
| `pkgs/library-policy.nix`                 | Rewritten with mkGoTool                                                                                    |
| `pkgs/md-go-validator.nix`                | Rewritten with mkGoTool                                                                                    |
| `pkgs/project-meta.nix`                   | Rewritten with mkGoTool                                                                                    |
| `pkgs/projects-management-automation.nix` | Rewritten with mkGoTool                                                                                    |
| `pkgs/template-readme.nix`                | Rewritten with mkGoTool                                                                                    |
| `pkgs/terraform-diagrams-aggregator.nix`  | Rewritten with mkGoTool                                                                                    |
| `pkgs/terraform-to-d2.nix`                | Rewritten with mkGoTool                                                                                    |
| `scripts/health-check.sh`                 | Modified (pre-existing change)                                                                             |
