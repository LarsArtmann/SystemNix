# Session 114 — WriteSARIF Upstream Fix Cascade, Buildflow Vendoring Blocked

**Date:** 2026-06-01 18:13
**Status:** 🟡 PARTIALLY DONE — upstream fixes complete, BuildFlow build blocked by vendoring inconsistency
**Impact:** 6 upstream repos changed, SystemNix build fails on `buildflow` package

---

## What Happened

A `nix flake update && nh os boot` failed with cascading `vendorHash` mismatches across multiple Go packages. Root cause: `go-finding` v0.4.3 (unreleased on master, ahead of v0.4.2 tag) changed `WriteSARIF(io.Writer)` to `WriteSARIF(context.Context, io.Writer)`. Three consumer repos hadn't been updated, causing compile errors in the Nix sandbox.

---

## a) FULLY DONE ✅

### 1. Released go-finding v0.4.3
- Tagged and pushed `v0.4.3` with the breaking `context.Context` parameter change
- Commit: `b4e5503` (master HEAD)

### 2. Fixed go-structure-linter (2 commits pushed)
- `79d590c` — Updated `WriteSARIF` call to pass `context.Background()`
- `527eb6f` — Added local replace directives for sub-modules (`modules/checks`, `modules/errorkit`, `modules/types`, `modules/utils`) in `postPatchExtra` in flake.nix, fixing the "private sub-modules can't resolve from GitHub HTTPS in Nix sandbox" issue at the source

### 3. Fixed go-auto-upgrade (1 commit pushed)
- `424c303` — Updated `WriteSARIF` call, added `context` import

### 4. Fixed branching-flow (1 commit pushed)
- `ac7a7c7` — Updated `WriteSARIF` call, added `context` import

### 5. Updated BuildFlow flake.lock (1 commit pushed)
- `d0bbf4ec` — Updated `go-structure-linter` input to latest master (with WriteSARIF fix + sub-module replaces)

### 6. Updated SystemNix flake.lock (committed)
- Updated inputs: `buildflow`, `branching-flow`, `go-auto-upgrade`, `go-structure-linter`, `homebrew-cask`, `projects-management-automation`

### 7. Updated all vendorHashes in SystemNix overlays (committed)
- `overlays/shared.nix` — All 8 Go package hashes updated
- `overlays/linux.nix` — `dnsblockd`, `emeet-pixyd` hashes updated

### 8. Simplified SystemNix buildflow overlay (committed)
- Removed the 45-line `patch-go-sum` hardcoded h1 hash block
- Removed GOPATH/GONOSUMDB/GOPRIVATE hacks
- Replaced with clean `overrideAttrs` with `vendorHash` + `goModules.outputHash` + `preBuild = "go mod tidy"`

---

## b) PARTIALLY DONE 🟡

### BuildFlow Nix build — overrideModAttrs vendoring inconsistency
- **What works:** go-modules derivation builds correctly with `go mod tidy` in `overrideModAttrs`
- **What fails:** Main build fails with "inconsistent vendoring" — `go-finding` v0.4.2 in go.mod vs v0.4.3 in vendor/modules.txt
- **Root cause:** `buildGoModule` phase 1 (go-modules) runs `go mod tidy` which upgrades go-finding to v0.4.3, producing vendor/ with v0.4.3. Phase 2 (main build) uses the original go.mod which still requires v0.4.2.
- **Attempted fixes (all failed):**
  1. `postPatch = "go mod tidy"` on main build — no network access in sandbox
  2. `GOFLAGS = "-mod=mod"` — Go still checks vendor/ consistency
  3. `postPatchExtra` in `mkPreparedSource` — runs before replace directives are added AND has no network
  4. `overrideAttrs` on `mkPreparedSource` result to append tidy after replaces — no network in regular derivations
- **Remaining uncommitted changes in BuildFlow repo:**
  - `flake.nix` — `vendorHash = ""` (placeholder), removed `postPatch` tidy attempt
  - `go.mod` / `go.sum` — updated `go-finding` to v0.4.3 locally

---

## c) NOT STARTED ⬜

1. **Commit and push BuildFlow** — local changes (flake.nix, go.mod, go.sum) not committed
2. **Resolve buildflow vendoring inconsistency** — the core blocker
3. **Full NixOS build verification** — blocked on buildflow
4. **AGENTS.md cleanup** — uncommitted AGENTS.md diff with minor doc improvements

---

## d) TOTALLY FUCKED UP 💥

### The buildflow `overrideModAttrs` + `go mod tidy` Anti-Pattern
This is EXACTLY the anti-pattern documented in AGENTS.md:

> `overrideModAttrs` runs `go mod tidy` in phase 1 only, producing vendor/modules.txt that doesn't match the un-tidied go.mod in phase 2 → "inconsistent vendoring" error.

The AGENTS.md says the exception is "repos with complex `_local_deps` setups" — but even for BuildFlow, the tidy changes the go-finding version, creating the mismatch.

### Multiple Failed Approaches
Went through 8+ iterations trying to fix buildflow:
1. SystemNix overlay: `sed` hacks for WriteSARIF — wrong layer, should fix upstream
2. SystemNix overlay: go-structure-linter sub-module overlay with replace directives — fought mkPreparedSource
3. SystemNix overlay: buildflow go-sum patching with hardcoded h1 hashes — fragile
4. BuildFlow: `postPatchExtra` in mkPreparedSource — no network
5. BuildFlow: `buildflowSrc = preparedSrc.overrideAttrs` — no network
6. BuildFlow: `GOFLAGS = "-mod=mod"` — doesn't bypass vendor consistency check
7. BuildFlow: `postPatch = "go mod tidy"` on main build — no network
8. BuildFlow: `overrideModAttrs` with tidy — inconsistent vendoring

---

## e) WHAT WE SHOULD IMPROVE

### 1. `mkPreparedSource` needs a `postReplaceExtra` hook
The `postPatchExtra` hook runs BEFORE replace directives are added. A `postReplaceExtra` hook (running AFTER replaces) would allow `go mod tidy` to run with all local deps available. But `mkPreparedSource` is a regular `mkDerivation` — no network. This won't work for deps that need network resolution (like `charm.land/bubbles`).

### 2. `mkPreparedSource` should produce a self-consistent go.mod/go.sum
After adding replace directives, the go.mod and go.sum may be inconsistent. The tool should either:
- Run `go mod tidy` (needs network — requires converting to fixed-output derivation)
- Or carefully patch go.sum to add all necessary entries without network

### 3. `buildGoModule` should support `overrideModAttrs` cleanly
The inconsistent vendoring problem is a well-known Nix limitation. The ideal fix is in nixpkgs' `buildGoModule` to support running the same tidy in both phases.

### 4. Don't break downstream consumers without updating them
The `go-finding` WriteSARIF change should have been a major version bump OR all consumers should have been updated in the same PR.

---

## f) Top 25 Things to Get Done Next

### Critical (build is broken)
1. **Fix buildflow vendoring inconsistency** — the #1 blocker
2. **Commit and push BuildFlow** changes (flake.nix, go.mod, go.sum)
3. **Update SystemNix flake.lock** for new buildflow
4. **Full NixOS build** — `nh os boot .`
5. **Commit SystemNix** with working build

### Important (correctness)
6. **Add `postReplaceExtra` to `mkPreparedSource`** in go-nix-helpers
7. **Make `mkPreparedSource` produce consistent go.mod/go.sum** — patch go.sum entries
8. **Update buildflow go.mod** to go-finding v0.4.3 + go-structure-linter with local replaces, run `go mod tidy` locally
9. **Remove `overrideModAttrs` from buildflow** once go.sum is pre-consistent
10. **Tag go-structure-linter v0.3.1** with the WriteSARIF fix + sub-module replaces

### Cleanup
11. **Commit AGENTS.md** improvements in SystemNix
12. **Remove buildflow's `overrideModAttrs` + `go mod tidy`** once source is pre-tidied
13. **Verify all Go packages build independently** after fixes
14. **Clean up BuildFlow's uncommitted go.mod/go.sum changes**
15. **Test `just test-fast`** passes

### Long-term improvements
16. **Add CI to go-finding** to prevent breaking downstream without version bump
17. **Create a "bump consumer" script** that updates all repos using go-finding
18. **Add integration test** in SystemNix that builds all Go packages
19. **Document the `_local_deps` vendoring pattern** in go-nix-helpers README
20. **Consider making `mkPreparedSource` a fixed-output derivation** for network access
21. **Audit all other Go repos** for WriteSARIF calls that need updating
22. **Add `go mod tidy` to pre-commit hooks** in all Go repos
23. **Simplify buildflow overlay** in SystemNix once upstream is self-consistent
24. **Review the `overrideModAttrs` anti-pattern documentation** in AGENTS.md for accuracy
25. **Consider a Nix flake check** that catches vendorHash mismatches before merge

---

## g) Top #1 Question I Cannot Figure Out Myself

**How to make BuildFlow's `go.mod`/`go.sum` consistent AFTER `mkPreparedSource` adds replace directives, WITHOUT network access?**

The core problem: `mkPreparedSource` adds local replace directives to go.mod (e.g., `github.com/LarsArtmann/go-structure-linter => ./_local_deps/go-structure-linter`). This creates go.mod entries that reference transitive deps not in go.sum. `go mod tidy` would fix it but needs network. `buildGoModule`'s `overrideModAttrs` has network but creates inconsistent vendoring between phases.

**Possible approaches I haven't tried:**
1. Make `mkPreparedSource` a fixed-output derivation (would have network)
2. Pre-compute and inject ALL go.sum entries needed after replace directives (fragile but works)
3. Patch `buildGoModule` in nixpkgs to support running tidy in both phases
4. Run `go mod tidy` locally with a script that simulates `mkPreparedSource` replace directives, commit the result

**Question for Lars:** Which approach do you prefer? Option 4 (local pre-tidy) is the simplest but requires running a script before each build. Option 1 (fixed-output mkPreparedSource) is cleanest but changes the shared helper.
