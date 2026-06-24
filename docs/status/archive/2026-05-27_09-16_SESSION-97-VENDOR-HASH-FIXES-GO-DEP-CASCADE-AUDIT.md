# SystemNix — Session 97: Vendor Hash Fixes, Go Dependency Cascade, Architecture Audit

**Date:** 2026-05-27 09:16 CEST
**Host:** evo-x2 (AMD Ryzen AI MAX+ 395 w/ Radeon 8060S, 64 GiB unified DDR5)
**Previous:** Session 96 (OOM hardening, build parallelism fix)
**Trigger:** `nix log` on failed `library-policy` and `mr-sync` derivations — both broken by inconsistent vendoring

---

## Executive Summary

Two Go overlay packages (`library-policy`, `mr-sync`) were broken with `inconsistent vendoring` errors after dependency updates. Root cause: `overrideModAttrs` with `go mod tidy` created a mismatch between the go-modules derivation's vendor dir and the main build's go.mod. Fixed both, uncovered a **much larger pattern** of the same anti-pattern across 5 more repos, plus a broken `projects-management-automation` build (missing private dep submodule in sandbox).

**Verdict: 2 packages FIXED, 1 package BROKEN (pre-existing), 4 packages at RISK (same anti-pattern), 2 repos violate versioning convention.**

---

## A) Fully Done

### 1. library-policy — FIXED ✅

- **Problem:** `go: inconsistent vendoring` — `overrideModAttrs` with `go mod tidy` produced a vendor dir that didn't match the original go.mod
- **Root cause:** `mkPreparedSource` adds `replace` directives to go.mod. The go-modules derivation ran `go mod tidy` (adjusting indirect deps), but the main build used the un-tidied go.mod → vendor/modules.txt mismatch
- **Fix:** Removed `overrideModAttrs = _: { preBuild = "go mod tidy"; }`, updated vendorHash to `sha256-6dyHuISxFka708ozfFTslluS1BlC6QUVkVi+n6bNf5Q=`
- **Files:** `library-policy/nix/packages/default.nix`
- **Commits:** `7798f9e` (library-policy), pushed to master

### 2. mr-sync — FIXED ✅

- **Problem:** Two issues: (a) go-output pin at `rev=518b300` (pre-v0.5.0, missing `TableDataBase` type), (b) missing submodules in `subModules` list, (c) nonexistent `"sort"` submodule listed
- **Root cause:** go-output submodules (delimited, markup, serialization) now require `TableDataBase` from the parent module, which was only added in v0.6.0. The pin was 100+ commits behind.
- **Fix:**
  - Updated go-output pin from `rev=518b300` → `rev=be1a3ec` (v0.6.0)
  - Added missing submodules: `delimited`, `markup`, `plantuml`, `serialization`
  - Removed nonexistent `sort` submodule
  - Updated vendorHash to `sha256-0paVZH2nlrr8JZOJMYTXxwH9ZSeOkYV13dlHmE2P/RA=` (SystemNix nixpkgs context)
- **Files:** `mr-sync/flake.nix`, `mr-sync/package.nix`
- **Commits:** `3a6c589`, `76abcde` (mr-sync), pushed to master

### 3. SystemNix flake.lock — UPDATED ✅

- Updated inputs: `library-policy`, `mr-sync`, `go-finding`, `branching-flow`, `homebrew-cask`, `nur`, `systems`
- Both `library-policy` and `mr-sync` build successfully from SystemNix
- `just test-fast` passes (all NixOS modules eval correctly)

---

## B) Partially Done

### 1. projects-management-automation — STILL BROKEN 🔴 (Architecture issue)

- **Error:** `go: inconsistent vendoring` — submodules in vendor/ but not in go.mod
- **Root cause:** `mkPreparedSource` adds `replace` directives for `project-discovery-sdk/detection`, `project-discovery-sdk/discovery`, `go-output/delimited`, `go-output/markup`, `go-output/serialization`. The go-modules derivation (with `overrideModAttrs` + `go mod tidy`) produces vendor/ containing these submodules. The main build's go.mod doesn't explicitly require them → inconsistency.
- **Why it can't be fixed locally:** The submodules have no git tags on GitHub. Adding explicit `require` lines causes `go mod tidy` to fail locally (can't fetch `detection/v0.0.0`). The only way to make them work is via `replace` directives (which mkPreparedSource provides) + `go mod tidy` (which `overrideModAttrs` provides).
- **Fix options (future):**
  1. Publish git tags for submodules (`detection/v0.0.0`, `discovery/v0.0.0`, etc.)
  2. Redesign `mkPreparedSource` to produce a go.mod that doesn't need `go mod tidy`
  3. Use `proxyVendor = true` in PMA's buildGoModule (may avoid vendor consistency check)
- **Workaround:** PMA overlay is dead but `library-policy` and `mr-sync` build fine

---

## C) Not Started

See Section E/F below for prioritized backlog.

---

## D) Totally Fucked Up (Honest Assessment)

### 1. The `overrideModAttrs` + `go mod tidy` Anti-Pattern is Everywhere

**5 repos still have this ticking time bomb:**

| Repo | Lines with `overrideModAttrs`/`go mod tidy` | Risk Level |
|------|----------------------------------------------|------------|
| `art-dupl` | `overrideModAttrs`, `go mod tidy` in preBuild | 🔴 HIGH |
| `go-auto-upgrade` | `overrideModAttrs` + `go mod tidy` in both dev/prod | 🔴 HIGH |
| `file-and-image-renamer` | `overrideModAttrs` + `go mod tidy` | 🔴 HIGH |
| `projects-management-automation` | `overrideModAttrs = _: { preBuild = "go mod tidy"; }` | 🔴 HIGH |
| `go-filewatcher` | `go mod tidy` in apps | 🟡 MEDIUM |

**Why it's fucked:** Any `go.mod` change (version bump, new dep, indirect dep resolution change) will cause the SAME inconsistent vendoring error we just fixed. The `go mod tidy` in `overrideModAttrs` runs during go-modules derivation (with network), producing a different vendor/modules.txt than the main build sees (without network). It "works" only when the go.mod is already perfectly tidy — which breaks on the next `go get -u` or indirect dep resolution change.

### 2. `self.rev` as Version — Violates Project Convention

**2 repos use `self.rev or self.dirtyRev or "dev"` as version:**

| Repo | Current Version String | Should Be |
|------|------------------------|-----------|
| `mr-sync` | `76abcde52e262a...` (40-char git hash) | `"0.1.0"` or similar semver |
| `branching-flow` | `db2ba469089121d5...` (40-char git hash) | `"0.1.0"` or similar semver |

This violates the AGENTS.md convention and produces garbage package names.

### 3. Duplicate `go-nix-helpers` Flake Inputs

SystemNix flake.lock has **6 copies** of `go-nix-helpers` at the same rev (`8317854`):
- `go-nix-helpers`, `go-nix-helpers_2` through `go-nix-helpers_6`

Each consumer repo declares its own `go-nix-helpers` input with `flake = false`. These should use `follows` to deduplicate.

### 4. `mr-sync` vendorHash is nixpkgs-context-dependent

The vendorHash that works locally (with mr-sync's own nixpkgs) differs from what SystemNix's nixpkgs resolves. This means `mr-sync` CI and SystemNix builds can't agree on a single vendorHash. Root cause: `go_1_26` vs `pkgs.go` version difference, or different nixpkgs `buildGoModule` behavior.

---

## E) What We Should Improve

### Architecture & Process

1. **Kill `overrideModAttrs` + `go mod tidy` everywhere** — Replace with proper go.mod maintenance (run `go mod tidy` locally before committing, not during Nix build). This is THE systemic issue.

2. **Centralize go-output version across all consumers** — Currently pinned to 3 different revs (`be1a3ec`, `master`, repo-specific). Should follow a single ref and add all consumer repos to a shared update workflow.

3. **Add `subModules` for all Go multi-module deps** — `project-discovery-sdk` (detection, discovery, mr), `go-output` (all 9 submodules). `mkPreparedSource` only creates `replace` for root — sub-modules need explicit listing.

4. **Deduplicate `go-nix-helpers` inputs** — Use `follows` in each consumer repo's flake.nix so SystemNix has one copy, not 6.

5. **Fix versioning in mr-sync and branching-flow** — Replace `self.rev` with hardcoded semver per AGENTS.md convention.

### Type & Model Improvements

6. **`mkPreparedSource` should auto-detect submodules** — Instead of manual `subModules` lists (error-prone, easy to miss), scan `_local_deps/<dep>/` for subdirectories with `go.mod` files and auto-generate replace directives. This is a one-time improvement to `go-nix-helpers/mkPreparedSource.nix`.

7. **`mkPreparedSource` should validate deps** — Before building, check that all imports in `go.mod` that reference local deps have corresponding `replace` directives. Fail fast with a clear error message instead of "inconsistent vendoring" at build time.

8. **Vendor hash mismatch should be a warning, not a blocker** — Or at minimum, the error message should suggest the `got:` hash. (This is an upstream nixpkgs issue, but we could wrap `buildGoModule` to catch and report.)

---

## F) Top 25 Next Actions (Sorted by Impact × Ease)

| # | Action | Impact | Effort | Repo |
|---|--------|--------|--------|------|
| 1 | Fix PMA: add `project-discovery-sdk` submodules (`detection`, `discovery`, `mr`) to `subModules` | 🔴 Blocks system build | 5 min | pma |
| 2 | Fix PMA: update vendorHash after submodules fix | 🔴 Blocks system build | 3 min | pma |
| 3 | Remove `overrideModAttrs` from `art-dupl` + update vendorHash | 🔴 Time bomb | 5 min | art-dupl |
| 4 | Remove `overrideModAttrs` from `go-auto-upgrade` + update vendorHash | 🔴 Time bomb | 5 min | go-auto-upgrade |
| 5 | Remove `overrideModAttrs` from `file-and-image-renamer` + update vendorHash | 🔴 Time bomb | 5 min | file-and-image-renamer |
| 6 | Remove `overrideModAttrs` from `projects-management-automation` + update vendorHash | 🔴 Time bomb | 5 min | pma |
| 7 | Fix `mr-sync` version: replace `self.rev` with `"0.1.0"` | 🟡 Convention violation | 2 min | mr-sync |
| 8 | Fix `branching-flow` version: replace `self.rev` with `"0.1.0"` | 🟡 Convention violation | 2 min | branching-flow |
| 9 | Verify `go-filewatcher` doesn't need overrideModAttrs removal | 🟡 Potential | 5 min | go-filewatcher |
| 10 | Update PMA go-output submodules list (add `delimited`, `markup`, `serialization`, `plantuml`) | 🟡 Missing deps | 5 min | pma |
| 11 | Update go-output pins across all repos to v0.6.0 (be1a3ec) | 🟡 Consistency | 15 min | all |
| 12 | Add go-output `sort` → remove if nonexistent, verify all submodules | 🟡 Correctness | 5 min | per-repo |
| 13 | Commit SystemNix flake.lock changes | 🟡 Tracked | 1 min | SystemNix |
| 14 | Push SystemNix | 🟡 Deploy | 1 min | SystemNix |
| 15 | Auto-detect submodules in `mkPreparedSource` (scan for go.mod) | 🟢 Architecture | 30 min | go-nix-helpers |
| 16 | Add validation to `mkPreparedSource` (check replace directives) | 🟢 Architecture | 30 min | go-nix-helpers |
| 17 | Deduplicate `go-nix-helpers` inputs (use `follows`) | 🟢 Cleanup | 20 min | SystemNix + repos |
| 18 | Fix `mr-sync` vendorHash nixpkgs-context dependency | 🟢 Robustness | 15 min | mr-sync |
| 19 | Add CI check: `nix build` for each overlay package | 🟢 Prevention | 30 min | SystemNix |
| 20 | Audit all Go repos for `sort` submodule (doesn't exist in go-output) | 🟢 Correctness | 10 min | all |
| 21 | Update AGENTS.md with `overrideModAttrs` anti-pattern warning | 🟢 Documentation | 5 min | SystemNix |
| 22 | Add `just check-vendor` recipe to SystemNix justfile | 🟢 Tooling | 10 min | SystemNix |
| 23 | Check if `go-finding` submodules need listing in any consumer | 🟢 Correctness | 5 min | all |
| 24 | Review `go-output` pin strategy — should all repos use `?ref=master`? | 🟢 Strategy | 10 min | all |
| 25 | Consider `gomod2nix` as alternative to manual vendorHash management | 🟢 Future | 60 min | research |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Should `go-output` be pinned to a specific rev in every consumer repo, or should all repos use `?ref=master` and rely on flake.lock for reproducibility?**

Current state is inconsistent:
- `mr-sync`: pinned to `rev=be1a3ec` (v0.6.0)
- `pma`, `go-auto-upgrade`, `go-structure-linter`: `ref=master`
- `library-policy`, `art-dupl`, `dnsblockd`: inherited via go-finding or not directly using go-output

The AGENTS.md pattern uses `ref=master` for all private inputs. But pinning to a rev prevents accidental breakage from an upstream push. The tradeoff: pinning means manual rev bumps on every go-output release; `ref=master` means `nix flake lock --update-input` is sufficient but risks breakage.

**My recommendation:** Use `ref=master` everywhere (consistent with the established pattern) and rely on flake.lock for pinning. The `mr-sync` pin to `rev=be1a3ec` should be changed to `ref=master` + update flake.lock.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Repos modified | 2 (library-policy, mr-sync) |
| Commits pushed | 4 (library-policy: 1, mr-sync: 3) |
| Build failures fixed | 2 (library-policy, mr-sync) |
| Build failures remaining | 1 (projects-management-automation) |
| Anti-patterns found | 5 repos with `overrideModAttrs` + `go mod tidy` |
| Convention violations | 2 repos using `self.rev` as version |
| Duplicate flake inputs | 6 copies of `go-nix-helpers` |
| Total time | ~30 min |
