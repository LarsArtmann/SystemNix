# SystemNix — Session 97 Final: Vendor Hash Fixes, Dependency Cascade, Architecture Blocker

**Date:** 2026-05-27 10:52 CEST
**Host:** evo-x2 (AMD Ryzen AI MAX+ 395 w/ Radeon 8060S, 64 GiB unified DDR5)
**Previous:** Session 96 (OOM hardening, build parallelism fix)
**Duration:** ~2 hours

---

## A) Fully Done ✅

### 1. library-policy — FIXED and VERIFIED

| Item | Detail |
|------|--------|
| **Problem** | `go: inconsistent vendoring` — `overrideModAttrs` with `go mod tidy` produced vendor/modules.txt mismatch |
| **Root cause** | `mkPreparedSource` adds `replace` directives to go.mod. `overrideModAttrs` ran `go mod tidy` in go-modules derivation (with network), adjusting indirect deps. Main build used un-tidied go.mod → mismatch |
| **Fix** | Removed `overrideModAttrs = _: { preBuild = "go mod tidy"; }`, updated vendorHash |
| **Commit** | `7798f9e` (library-policy) |
| **Build status** | ✅ `nix build .#library-policy --rebuild` passes |

### 2. mr-sync — FIXED and VERIFIED

| Item | Detail |
|------|--------|
| **Problem** | Two issues: (a) go-output pin at `rev=518b300` (pre-v0.5.0, missing `TableDataBase`), (b) missing submodules, (c) nonexistent `sort` submodule |
| **Fix** | Updated go-output pin to v0.6.0 (`rev=be1a3ec`), added `delimited`/`markup`/`plantuml`/`serialization` submodules, removed `sort`, updated vendorHash |
| **Commits** | `3a6c589`, `76abcde`, `90b8edd` (mr-sync) |
| **Build status** | ✅ `nix build .#mr-sync --rebuild` passes |

### 3. project-discovery-sdk — FIXED and PUSHED

| Item | Detail |
|------|--------|
| **Problem** | `detection/registry.go` imported `go-composable-business-types/programminglanguage` — a package deleted in `c9bda50` |
| **Fix** | Inlined language normalization aliases directly in `detection/registry.go` (trivial `strings.ToLower` + alias map) |
| **Commit** | `e6a1652` (project-discovery-sdk) |

### 4. AGENTS.md — UPDATED

- **Versioning convention**: Softened from "NEVER use self.rev" to context-dependent: `self.rev` is fine for internal overlays; hardcoded semver for published packages only
- **overrideModAttrs anti-pattern**: Documented why `overrideModAttrs = _: { preBuild = "go mod tidy"; }` breaks on dep changes, with correct pattern and exception for complex repos
- **Commit** | `87a5a093` (SystemNix)

### 5. SystemNix flake.lock — UPDATED and PUSHED

Updated inputs: `library-policy`, `mr-sync`, `project-discovery-sdk`, `projects-management-automation`, `branching-flow`, `go-finding`, `homebrew-cask`, `nur`, `systems`

All pushed to master (3 commits: `cacd9ec9`, `87a5a093`, `4400c74c`).

---

## B) Partially Done 🟡

### 1. projects-management-automation — STILL BROKEN 🔴

**Status:** Root cause fully understood, fix options documented, but implementation blocked by architecture.

**The Problem (3-layer):**

1. `mkPreparedSource` adds `replace` directives for submodule packages (`detection`, `discovery`, `delimited`, `markup`, `serialization`)
2. `overrideModAttrs = _: { preBuild = "go mod tidy"; }` runs in go-modules derivation, producing vendor/ with these submodules
3. Main build's go.mod doesn't explicitly `require` these submodules → `go: inconsistent vendoring`

**Why I couldn't fix it:**

| Approach tried | Result |
|----------------|--------|
| Remove `overrideModAttrs` | go-modules derivation fails: "updates to go.mod needed" |
| Add `preBuild = "go mod tidy"` to main build | Fails: no network in sandbox |
| Add `preBuild = "go mod vendor"` to main build | Fails: go.mod needs tidy first |
| Add explicit `require` lines to go.mod locally | Fails: submodules have no git tags → `go mod tidy` can't resolve `detection/v0.0.0` |
| `proxyVendor = true` | Didn't bypass the consistency check |
| `GOFLAGS = "-mod=mod"` | `buildGoModule` overrides it |

**What was partially done:**
- Added `project-discovery-sdk` submodules (`detection`, `discovery`) to `subModules` in PMA flake.nix ✅
- Added missing `go-output` submodules (`delimited`, `markup`, `plantuml`, `serialization`) ✅
- Removed nonexistent `sort` submodule ✅
- Updated `project-discovery-sdk` lock to `e6a1652` (programminglanguage fix) ✅
- Bumped `go-git/v5`, `x/crypto`, `x/exp` in go.mod ✅
- Updated vendorHash ✅

**But the build still fails** because the 5 submodule packages are in vendor/ but not in go.mod.

**Fix options for future sessions:**

1. **Publish git tags** for submodules: `git tag detection/v0.0.0 && git push origin detection/v0.0.0` (for each submodule in `project-discovery-sdk` and `go-output`). Then `require` lines can be added to go.mod.
2. **Redesign `mkPreparedSource`** to auto-generate require lines for submodules (deep change to `go-nix-helpers`)
3. **Patch `buildGoModule`** to not check vendor consistency when `proxyVendor = true` (upstream nixpkgs change)

---

## C) Not Started

| # | Item | Why not |
|---|------|---------|
| 1 | Auto-detect submodules in `mkPreparedSource` | Requires `go-nix-helpers` redesign |
| 2 | Add validation to `mkPreparedSource` | Same |
| 3 | Deduplicate 6× `go-nix-helpers` inputs | Needs `follows` in each consumer repo |
| 4 | CI check for overlay package builds | New infrastructure |
| 5 | `just check-vendor` recipe | Tooling improvement |

---

## D) Totally Fucked Up 💥

### 1. PMA — 4 hours of attempts, still broken

Every approach I tried hit a wall. The fundamental issue is that Go's `buildGoModule` design assumes go.mod and vendor/ are in sync, but `mkPreparedSource` + `overrideModAttrs` creates a situation where they can't be. The submodule dependency chain (PMA → project-discovery-sdk/detection → go-composable-business-types) only works via `replace` directives, and `replace`-resolved packages don't get explicit `require` lines in go.mod.

### 2. Reverted mr-sync + branching-flow version changes

I blindly changed `self.rev` to `"0.1.0"` following the AGENTS.md convention without thinking. User correctly challenged this — `self.rev` is honest and auto-updating for internal tools. Reverted both. This was a pure waste of 2 commits per repo.

### 3. Made 3 intermediate commits on mr-sync

The `vendorHash` kept changing because the local nixpkgs context differs from SystemNix's nixpkgs. Had to set `""`, build locally, push, update SystemNix lock, build from SystemNix, get the correct hash, push again. Should have started from SystemNix context.

---

## E) What We Should Improve

### Process

1. **Always build from SystemNix context first** — vendorHash is nixpkgs-dependent. Don't waste time with local builds.
2. **Think before following conventions blindly** — the `self.rev` revert was avoidable
3. **PMA is a canary** — any repo with `mkPreparedSource` + `overrideModAttrs` + submodules has this ticking time bomb. Document which repos are safe.

### Architecture

4. **`mkPreparedSource` should auto-add `require` lines for submodules** — after adding `replace` directives, scan for imports and add matching `require` lines so `go mod tidy` isn't needed
5. **`go-nix-helpers` should validate submodule coverage** — fail fast with a clear error if a submodule is accessed but not in `subModules`
6. **Consider tagging all Go submodules** — even `v0.0.0` tags make them resolvable without `replace`

---

## F) Top 25 Next Actions

| # | Action | Impact | Effort | Status |
|---|--------|--------|--------|--------|
| 1 | Publish git tags for `project-discovery-sdk` submodules (`detection/v0.0.0`, `discovery/v0.0.0`) | 🔴 Unblocks PMA | 5 min | Not started |
| 2 | Publish git tags for `go-output` submodules (`delimited/v0.0.0`, `markup/v0.0.0`, `serialization/v0.0.0`) | 🔴 Unblocks PMA | 5 min | Not started |
| 3 | Add explicit `require` lines in PMA go.mod for submodules + update vendorHash | 🔴 Unblocks PMA | 10 min | Not started |
| 4 | Remove `overrideModAttrs` from PMA after tags fix | 🔴 Unblocks PMA | 2 min | Not started |
| 5 | Verify PMA builds in SystemNix after above | 🔴 Unblocks system | 5 min | Not started |
| 6 | Auto-detect submodules in `mkPreparedSource` (scan for `go.mod` in deps) | 🟡 Prevention | 30 min | Not started |
| 7 | Add validation to `mkPreparedSource` (check replace coverage) | 🟡 Prevention | 20 min | Not started |
| 8 | Deduplicate `go-nix-helpers` inputs (use `follows`) | 🟡 Cleanup | 20 min | Not started |
| 9 | Remove `sort` from go-output subModules in all repos that still have it | 🟡 Correctness | 10 min | Not started |
| 10 | Fix `file-and-image-renamer` stale vendorHash | 🟡 Pre-existing | 5 min | Not started |
| 11 | Audit `go-filewatcher` for `go mod tidy` in apps | 🟡 Correctness | 5 min | Not started |
| 12 | Centralize go-output version across all consumers | 🟢 Consistency | 15 min | Not started |
| 13 | Add CI check: `nix build` for each overlay package | 🟢 Prevention | 30 min | Not started |
| 14 | Add `just check-vendor` recipe to SystemNix | 🟢 Tooling | 10 min | Not started |
| 15 | Fix mr-sync vendorHash nixpkgs-context dependency | 🟢 Robustness | 15 min | Not started |
| 16 | Review `go-finding` self.rev version usage (appears twice in flake.nix) | 🟢 Correctness | 5 min | Not started |
| 17 | Tag all Go submodule repos with `v0.0.0` as standard practice | 🟢 Prevention | 30 min | Not started |
| 18 | Consider `gomod2nix` as alternative to manual vendorHash | 🟢 Future | 60 min | Not started |
| 19 | Document safe overrideModAttrs patterns (art-dupl dummy module) in AGENTS.md | 🟢 Documentation | 5 min | Not started |
| 20 | Check if `gogenfilter` subModules are needed in any consumer | 🟢 Correctness | 10 min | Not started |
| 21 | Update PMA flake.lock for latest project-discovery-sdk after tags | 🟢 Hygiene | 2 min | Not started |
| 22 | Review all repos for `go-output` pin consistency (`ref=master` vs pinned rev) | 🟢 Consistency | 10 min | Not started |
| 23 | Add `gogenfilter` submodule tags if it has sub-packages | 🟢 Prevention | 5 min | Not started |
| 24 | Consider `go.work` based Nix build instead of mkPreparedSource | 🟢 Future | 120 min | Not started |
| 25 | Create ADR for mkPreparedSource + buildGoModule + submodules architecture | 🟢 Documentation | 15 min | Not started |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Is publishing `v0.0.0` git tags for Go submodules (detection, discovery, delimited, markup, serialization) the right approach, or should we redesign `mkPreparedSource` instead?**

Tagging is the quick fix (5 minutes) and follows Go's standard submodule versioning. But it creates a maintenance burden: every submodule needs a tag before PMA can use it. The `mkPreparedSource` redesign is more robust (auto-generates require lines after adding replaces) but touches shared infrastructure. Both solve the problem. Which direction?

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Repos modified | 4 (library-policy, mr-sync, project-discovery-sdk, SystemNix) |
| Commits across all repos | 10 |
| Packages fixed | 2 (library-policy, mr-sync) |
| Packages still broken | 1 (projects-management-automation) |
| New issues found | 1 (submodule git tags missing) |
| Convention violations fixed then reverted | 2 (mr-sync, branching-flow) |
| AGENTS.md sections added | 2 (versioning, overrideModAttrs anti-pattern) |
| Build verifications | 3 (library-policy ✅, mr-sync ✅, test-fast ✅) |
