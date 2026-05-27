# Session 98: Full Vendor Hash Cascade Resolution — PMA Unblocked

**Date:** 2026-05-27 11:33
**Session:** 98 (continuation of 97)
**Status:** PMA build fixed, all three Go packages verified, pushed to production

---

## Executive Summary

Session 98 completed the work Session 97 couldn't: **all three Go packages (library-policy, mr-sync, projects-management-automation) now build successfully from SystemNix**. The PMA blocker was resolved by fixing two separate issues:
1. `output.SortBy` deleted from go-output v0.6.0 → defined local `SccSortBy` type
2. `output.MarshalYAML` moved to `serialization` submodule → updated import

---

## A) FULLY DONE ✅

### 1. library-policy
- **Commit:** `7798f9e` (pushed)
- **Fix:** Removed `overrideModAttrs = _: { preBuild = "go mod tidy"; }`, updated vendorHash
- **File:** `nix/packages/default.nix`
- **Status:** Builds from SystemNix ✅

### 2. mr-sync
- **Commits:** `3a6c589`, `76abcde`, `90b8edd` (all pushed)
- **Fixes:** Updated go-output pin to v0.6.0, added missing submodules, removed nonexistent `sort` submodule, reverted to `self.rev` versioning
- **Files:** `flake.nix`, `package.nix`
- **Status:** Builds from SystemNix ✅

### 3. project-discovery-sdk
- **Commit:** `e6a1652` (pushed)
- **Fix:** Inlined language normalization aliases (deleted `programminglanguage` package dependency)
- **File:** `detection/registry.go`
- **Status:** Builds from SystemNix ✅

### 4. projects-management-automation (PMA)
- **Commits:** `560f37bd..4e6756f4` (12 commits, all pushed)
- **Fixes (Session 97):**
  - Updated flake.nix with correct go-output submodules
  - Added project-discovery-sdk submodules (`detection`, `discovery`)
  - Bumped go-git, x/crypto, x/exp versions
  - Added `postPatchExtra` sed commands to normalize submodule versions
  - Adapted to project-discovery-sdk `Git`/`Remote` sub-struct refactor
- **Fixes (Session 98):**
  - Defined local `SccSortBy` type (replacing deleted `output.SortBy`)
  - Updated `scc_parsing.go` to use local type
  - Updated `scc_test.go` references
  - Fixed `output.MarshalYAML` → `serialization.MarshalYAML`
- **Files:** `flake.nix`, `internal/discovery/sdk_discoverer.go`, `internal/application/commands/scc.go`, `scc_parsing.go`, `scc_test.go`, `stats_output.go`
- **Status:** Builds from SystemNix ✅

### 5. SystemNix
- **Commits:** `cacd9ec9`, `87a5a093`, `4400c74c`, `69168656`, `d3f189f9` (all pushed)
- **Updates:** flake.lock updated for all affected repos, AGENTS.md documented anti-patterns
- **Status:** `just test-fast` passes ✅, `nix build` of all 3 packages passes ✅

### 6. AGENTS.md Documentation
- **Commit:** `87a5a093` (pushed)
- **Added:** `overrideModAttrs` anti-pattern explanation with correct pattern
- **Added:** Context-dependent versioning convention (`self.rev` for internal, semver for published)

---

## B) PARTIALLY DONE ⚠️

### 1. PMA `overrideModAttrs` Still Present
- `flake.nix:222` still has `overrideModAttrs = _: { preBuild = "go mod tidy"; }`
- The AGENTS.md documents this as an anti-pattern with an exception for complex `_local_deps`
- **Why it's still there:** The `postPatchExtra` sed commands inject `require` lines for submodules, but `go mod tidy` is still needed to resolve `go.sum` entries for those injected requires
- **Proper fix:** Publish git tags for all go-output and project-discovery-sdk submodules, then add explicit `require` lines in go.mod directly (not via sed)

### 2. PMA `go.work` Version Mismatch
- `go.work` says `go 1.26.2` but all modules use `go 1.26.3`
- This causes golangci-lint to fail in PMA's pre-commit hook
- **Not blocking Nix builds** (go.work is not used in Nix), but blocks local development tooling

### 3. go-output Submodule Version Inconsistency
- 9 submodules still at `go 1.26.2` in go.mod while root is `go 1.26.3`
- Not blocking builds but inconsistent

---

## C) NOT STARTED 📋

### Infrastructure
- `/data` BTRFS toplevel → `@data` subvolume migration (documented in AGENTS.md)
- Jan AI llama-server memory leak monitoring (no cgroup limits)
- Pocket ID bootstrap on fresh deploy (documented but manual)

### Code Quality
- PMA has 120 TODO comments (pre-commit hook failure)
- PMA `stats_output.go` exceeds 350-line file size limit (480 lines)
- go-output has submodule version inconsistencies
- `file-and-image-renamer` still has `overrideModAttrs` anti-pattern

### Architecture
- `mkPreparedSource` redesign to auto-generate `require` lines (eliminates need for `overrideModAttrs` + `postPatchExtra`)
- Git tags for go-output and project-discovery-sdk submodules
- Consolidate PMA's 12+ `_local_deps` into a simpler dependency model

---

## D) TOTALLY FUCKED UP 💥

### Nothing Is Fucked
All three packages build. SystemNix is green. No data loss, no broken services.

The only ongoing pain point is the PMA build configuration complexity — 12 private deps, 8+ submodule packages, sed-based go.mod patching, and `overrideModAttrs` as a necessary evil. It works, but it's fragile.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Immediate (Next Session)

1. **Fix PMA go.work version**: `go 1.26.2` → `go 1.26.3` (1-line fix, unblocks local linting)
2. **Fix go-output submodule go.mod versions**: Bump 9 submodules from `go 1.26.2` → `go 1.26.3`
3. **Publish git tags for go-output submodules**: `delimited/v0.0.0`, `markup/v0.0.0`, `serialization/v0.0.0`, `plantuml/v0.0.0`, `enum/v0.0.0`, etc.
4. **Publish git tags for project-discovery-sdk submodules**: `detection/v0.0.0`, `discovery/v0.0.0`
5. **Remove PMA `overrideModAttrs` and `postPatchExtra`**: Once tags exist, add explicit `require` lines to go.mod directly

### Medium-Term

6. **Redesign `mkPreparedSource`**: Auto-generate `require` lines when adding `replace` directives, eliminating the entire sed/overrideModAttrs dance
7. **Centralize vendorHash management**: Create a script or Nix helper that auto-discovers correct vendorHashes
8. **File-and-image-renamer**: Fix the `overrideModAttrs` anti-pattern there too
9. **PMA `stats_output.go` refactor**: Split 480-line file into smaller focused files
10. **Resolve PMA's 120 TODO comments**: Triage and address

### Architecture

11. **Submodule tagging strategy**: Automate git tags for Go submodules in CI
12. **PMA dependency consolidation**: Evaluate if all 12 `_local_deps` are truly needed
13. **BuildFlow pre-commit hook**: Fix go.work version detection to auto-bump

---

## F) TOP 25 THINGS WE SHOULD GET DONE NEXT

### Tier 1: Quick Wins (5 min each, high impact)

| # | Task | Impact |
|---|------|--------|
| 1 | Fix PMA go.work: `go 1.26.2` → `go 1.26.3` | Unblocks local golangci-lint |
| 2 | Fix go-output submodule go.mod versions (9 files) | Consistency |
| 3 | Verify `just switch` works on evo-x2 after all updates | Production readiness |
| 4 | Update PMA flake.lock for go-output latest (after submodule version fixes) | Stay current |

### Tier 2: Medium Effort (30 min each, architectural improvement)

| # | Task | Impact |
|---|------|--------|
| 5 | Publish git tags for go-output submodules | Eliminates PMA sed hack |
| 6 | Publish git tags for project-discovery-sdk submodules | Same |
| 7 | Remove PMA `overrideModAttrs` + `postPatchExtra` after tags | Cleaner build |
| 8 | Fix file-and-image-renamer `overrideModAttrs` | Consistency |
| 9 | Split PMA `stats_output.go` (480 → 2-3 files) | Code quality |
| 10 | Redesign `mkPreparedSource` to auto-generate `require` lines | Eliminates entire class of bugs |

### Tier 3: Testing & Verification

| # | Task | Impact |
|---|------|--------|
| 11 | Run PMA test suite locally (`go test ./...`) | Verify nothing broke |
| 12 | Run PMA BDD tests (`ginkgo -r`) | Verify nothing broke |
| 13 | Build ALL SystemNix Go packages (`nix build .#<each>`) | Comprehensive check |
| 14 | Run `just test` on SystemNix (full build validation) | Production readiness |

### Tier 4: Documentation & Maintenance

| # | Task | Impact |
|---|------|--------|
| 15 | Update PMA AGENTS.md with current build state | Knowledge preservation |
| 16 | Update go-output AGENTS.md with submodule tagging strategy | Knowledge preservation |
| 17 | Create `mkPreparedSource` design doc for redesign | Architecture clarity |
| 18 | Document the full dependency graph of private Go repos | System understanding |

### Tier 5: Long-Term Architecture

| # | Task | Impact |
|---|------|--------|
| 19 | Automate git submodule tagging in CI (go-output, project-discovery-sdk) | Prevents future drift |
| 20 | Evaluate PMA dependency consolidation (12 → fewer) | Simplification |
| 21 | Consider Go workspace mode for all private deps | Alternative to `_local_deps` |
| 22 | Migrate `/data` BTRFS to `@data` subvolume (snapshots!) | Data safety |
| 23 | Set up Jan AI memory leak monitoring | Resource management |
| 24 | Resolve PMA 120 TODO comments | Technical debt |
| 25 | Create automated vendorHash update script | Developer experience |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why does PMA still need `overrideModAttrs = _: { preBuild = "go mod tidy"; }` even after the `postPatchExtra` sed commands inject explicit `require` lines?**

The sed commands add lines like:
```go
github.com/larsartmann/go-output/delimited v0.0.0 // indirect
github.com/larsartmann/go-output/serialization v0.0.0 // indirect
```

But without `go mod tidy`, the `go.sum` file doesn't have the corresponding checksum entries for these synthetic `v0.0.0` versions. Since `buildGoModule` runs with `-mod=vendor`, it needs both the `vendor/modules.txt` AND the `go.sum` to be consistent.

**Possible answer:** The `v0.0.0` versions in the `require` lines don't match any actual git tag — they're synthetic. The `replace` directives (from `mkPreparedSource`) point to `_local_deps/` paths, which DO have the code, but `go mod tidy` is needed to populate `go.sum` with the correct hashes for those local paths. Without tidy, the go.sum is incomplete.

**If someone published real git tags** (e.g., `go-output/delimited v0.0.0` as an actual annotated tag on the go-output repo), then the `replace` directive would resolve the version AND the hash would be deterministic. The `require` line would reference a real version, and `go.sum` would be populated by the go-modules derivation without needing tidy.

**But I'm not sure** if this is the complete explanation, or if there's a simpler way to make it work. The `mkPreparedSource` redesign (#10 above) would answer this definitively.

---

## Session Timeline

| Time | Event |
|------|-------|
| 11:26 | Session 98 starts — PMA build fails with `output.SortBy` undefined |
| 11:27 | Research: SortBy deleted in go-output v0.6.0 dead code cleanup, MarshalYAML moved to serialization submodule |
| 11:28 | Define local `SccSortBy` type in scc.go — application-specific, not a library concern |
| 11:29 | Fix scc_parsing.go, scc_test.go, stats_output.go |
| 11:30 | `nix build .#default` in PMA — SUCCESS |
| 11:31 | Commit + push PMA (`4e6756f4`) |
| 11:32 | Update SystemNix flake.lock, build all 3 packages — SUCCESS |
| 11:33 | Commit + push SystemNix (`d3f189f9`) |
| 11:33 | Status report written |

---

## Key Insight

The root cause of the entire 2-session saga was **go-output v0.6.0 breaking changes** that cascaded through the dependency tree:
1. `SortBy` type deleted (dead code cleanup) → PMA SCC feature broke
2. `MarshalYAML` moved to submodule → PMA stats output broke
3. `TableDataBase` added in v0.6.0 → mr-sync broke (needed submodule update)
4. `programminglanguage` package deleted → project-discovery-sdk broke
5. `Git`/`Remote` fields reorganized → PMA discovery broke

**Lesson:** When a shared library does major cleanup, audit ALL consumers for:
- Types used from the root package that may have been deleted
- Functions moved to submodules
- Submodule API changes that affect imports
