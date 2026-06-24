# Session 55 — Full Ecosystem Build Fix: 13/13 Overlay Packages Building

**Date:** 2026-05-19 04:56 CEST
**Platform:** Linux (evo-x2, x86_64)
**Nix:** 2.34.6 | **Channel:** 26.05 (unstable)
**Disk:** 86% used (72G free of 512G), /data 81% (198G free of 1T)

---

## Executive Summary

Fixed the remaining 5 broken overlay packages. All **13/13** overlay packages now build successfully. The root causes were: stale vendor hashes from upstream go-output dependency changes, a stale cached art-dupl derivation referencing old gogenfilter v2 API, and a fundamental go-auto-upgrade preparedSrc bug with malformed go.mod manipulation.

---

## a) FULLY DONE

### 1. art-dupl — Stale Derivation Cache Cleared

- **Root cause:** Cached `.drv` referenced old source `c05a4d1` with `gogenfilter` (v2), but `flake.lock` already had `bf8e4fc` (fork branch with v3 migration). Nix was reusing the stale cached derivation.
- **Fix:** Deleted stale store paths via `nix store delete`, forcing re-fetch of correct source.
- **Status:** ✅ Builds successfully with gogenfilter v3 + local `FilterStats`

### 2. go-auto-upgrade — preparedSrc go.mod Fix

- **Root cause:** `preparedSrc` used raw `echo >> go.mod` to add `require` and `replace` directives, creating:
  - Duplicate `require` entries for already-indirect deps (go-branded-id, go-output sub-modules)
  - Missing `testhelpers` sub-module from go-output replace list
  - Inconsistent go.mod/go.sum that needed `go mod tidy` but couldn't run it in sandboxed preparedSrc
- **Fix (upstream commit `64db2da`):**
  - Replaced `echo >> go.mod` with `go mod edit -replace=...` (produces clean go.mod)
  - Added `testhelpers` to go-output sub-module replace list
  - Added `go` to preparedSrc `nativeBuildInputs` for `go mod edit`
  - Added `preBuild = "go mod tidy"` to main build (vendor mode allows tidy without network)
  - Removed redundant `require` directives (replace alone is sufficient for indirect deps)
  - Updated `vendorHash` to `sha256-bz1EA7Tf3R7PQENdrLYpdjBAEOhgdmP1B0pyI0GWTWA=`
- **Status:** ✅ Builds successfully

### 3. buildflow — vendorHash Update

- **Root cause:** go-output source changed upstream, invalidating vendor hash
- **Fix (upstream commit `03596a4`):** Updated `vendorHash` to `sha256-ny13ZsTHWVAiKR5Rwq4wgN/rkugTDrZkEAseCp8yMDo=`
- **Status:** ✅ Builds successfully

### 4. todo-list-ai — node_modules Hash Update

- **Root cause:** Upstream `package.json` or `bun.lock` changed, invalidating fixed-output hash for `node_modules`
- **Fix:** Updated `todoListAiFixedHash` in `overlays/shared.nix` to `sha256-LBN8P0SNnPSbJ7VnupopreSpblyLRi8ffn+XJ8D6rck=`
- **Status:** ✅ Builds successfully

### 5. mr-sync, dnsblockd, monitor365, library-policy, etc. — Already Building

These packages built correctly once stale cached derivations were cleared during the session. No code changes needed.

---

## Build Matrix (ALL 13/13 ✅)

| Package | Status | Notes |
|---------|--------|-------|
| art-dupl | ✅ | Cache cleared, gogenfilter v3 |
| go-auto-upgrade | ✅ | Upstream preparedSrc fix |
| mr-sync | ✅ | Builds fine (was stale cache) |
| buildflow | ✅ | Upstream vendorHash update |
| library-policy | ✅ | |
| dnsblockd | ✅ | |
| monitor365 | ✅ | |
| go-structure-linter | ✅ | |
| hierarchical-errors | ✅ | |
| branching-flow | ✅ | |
| file-and-image-renamer | ✅ | |
| golangci-lint-auto-configure | ✅ | |
| todo-list-ai | ✅ | node_modules hash update |

---

## b) PARTIALLY DONE

### art-dupl Fork → Master Merge

- art-dupl fixes still on `fork` branch, not merged to upstream `master`
- The `flake.nix` input uses `ref = "fork"` — works but is technical debt
- Requires upstream merge and then updating flake.nix to `ref = "master"`

### 3 Pre-existing BDD Test Failures in art-dupl

- `bdd/stats_command_test.go` — 3 tests fail (stats output format issue, unrelated to v3 migration)
- These existed before this session's work

---

## c) NOT STARTED

### NixOS System Build Verification

- Individual packages all build, but full `nixosConfigurations.evo-x2` build not tested yet
- `just test-fast` (syntax check) not run yet

### go-auto-upgrade Upstream Refactor

- The `preparedSrc` still uses manual `go mod edit` commands instead of `mkPreparedSource.nix` helper
- Should migrate to the shared `mkPreparedSource` pattern (like mr-sync, buildflow, etc.)

### DNS Failover Cluster (Pi 3)

- Pi 3 hardware not yet provisioned
- Module exists (`modules/nixos/services/dns-failover.nix`) but untested

---

## d) TOTALLY FUCKED UP

### Nothing catastrophic this session!

The only "waste" was attempting multiple approaches for go-auto-upgrade before finding the correct one:
1. ❌ Tried `goAutoUpgradeOverlay` in SystemNix `overlays/shared.nix` (can't override preparedSrc installPhase with network)
2. ❌ Tried `go mod tidy` in preparedSrc installPhase (no DNS in Nix sandbox)
3. ❌ Tried removing `require` directives only (still fails because testhelpers missing)
4. ✅ Finally: `go mod edit -replace` + `testhelpers` + `preBuild go mod tidy` in main build

The `overlays/shared.nix` was reverted to its clean state (no goAutoUpgradeOverlay hack needed).

---

## e) WHAT WE SHOULD IMPROVE

1. **Automated vendorHash freshness check** — CI should detect stale hashes before merge
2. **go-auto-upgrade should use `mkPreparedSource`** — eliminates the entire class of go.mod manipulation bugs
3. **art-dupl fork → master merge** — eliminate the `ref = "fork"` technical debt
4. **`just test` should build ALL overlay packages** — not just NixOS config syntax
5. **Stale derivation detection** — `nix store delete` of old `.drv` files should be part of `just clean`
6. **Lockfile node count monitoring** — currently at 72 nodes; track over time

---

## f) Top #25 Things to Get Done Next

| # | Priority | Task | Impact |
|---|----------|------|--------|
| 1 | P0 | Run `just switch` to deploy the 13/13 build fix to evo-x2 | Build finally works |
| 2 | P0 | Run `just test-fast` to validate full NixOS config evaluates | CI gate |
| 3 | P1 | Merge art-dupl `fork` → `master`, update `flake.nix` to `ref = "master"` | Tech debt |
| 4 | P1 | Migrate go-auto-upgrade to `mkPreparedSource.nix` pattern | Prevent go.mod bugs |
| 5 | P1 | Add overlay package build check to `just test` recipe | Catch stale hashes early |
| 6 | P1 | Fix 3 art-dupl BDD test failures in stats_command_test.go | Test quality |
| 7 | P1 | Provision Pi 3 for DNS failover cluster | HA DNS |
| 8 | P2 | Add automated vendorHash staleness detection to CI | Prevention |
| 9 | P2 | Clean up stale Nix store paths (`just clean` improvements) | Disk space |
| 10 | P2 | Run `just health` for full system health check | Monitoring |
| 11 | P2 | Verify Forgejo push mirrors are working post-migration | Backup |
| 12 | P2 | Set up Gatus alerts for all newly fixed services | Observability |
| 13 | P2 | Review and update AGENTS.md with go-auto-upgrade preparedSrc pattern | Documentation |
| 14 | P2 | Test full `nixosConfigurations.evo-x2` build (not just packages) | Complete validation |
| 15 | P2 | Check disk space and run `just clean` if needed (86% used) | Maintenance |
| 16 | P3 | Investigate `hostPlatform` deprecation warning in eval | Warning cleanup |
| 17 | P3 | Add `usb-diagnostic.sh` to tracked scripts or remove it | Cleanup |
| 18 | P3 | Review hermes-agent npmDeps hash staleness | Build reliability |
| 19 | P3 | Consider distributed builds to evo-x2 for Darwin (90-95% disk) | Cross-platform |
| 20 | P3 | Add lockfile node count to `just check` output | Monitoring |
| 21 | P3 | Investigate projects-management-automation eval issue (attribute not found) | Completeness |
| 22 | P4 | Create `mkPreparedSource` as a shared flake input across all repos | DRY |
| 23 | P4 | Add `go mod tidy` pre-commit hook to all Go repos | Prevention |
| 24 | P4 | Document the `_local_deps` pattern in a shared Go template reference | Documentation |
| 25 | P4 | Consider nixpkgs `hostPlatform` → `stdenv.hostPlatform` migration | Deprecation |

---

## g) Top #1 Question I Cannot Figure Out Myself

**How should `go mod tidy` work in `buildGoModule` with `proxyVendor = true` and `overrideModAttrs`?**

The current pattern is:
1. `overrideModAttrs.preBuild = "go mod tidy"` runs in the go-modules derivation (has network)
2. Go-modules produces vendor directory
3. Main build copies vendor and builds

But the main build's go.mod/go.sum (from preparedSrc) doesn't match the tidied version. With `proxyVendor = true`, nix constructs vendor from go-modules output, but the main build still uses the original go.mod. The `go mod tidy` in `preBuild` of the main build works because `-mod=vendor` allows tidy without network when vendor exists.

**Is this the intended pattern, or is there a cleaner way?** The `mkPreparedSource` helper in mr-sync/buildflow avoids this by only adding `replace` directives (no `require`), so go.mod stays consistent. But go-auto-upgrade needed `go mod edit` because of sub-modules that weren't in go.mod. If we migrate to `mkPreparedSource`, would it handle the testhelpers case?

---

## Files Changed

| File | Change |
|------|--------|
| `flake.lock` | Updated `go-auto-upgrade` → `64db2da`, `buildflow` → `03596a4` |
| `overlays/shared.nix` | Updated `todoListAiFixedHash` to `sha256-LBN8P0S...` |

## Upstream Commits Pushed

| Repo | Commit | Description |
|------|--------|-------------|
| go-auto-upgrade | `64db2da` | fix(flake): use go mod edit for replace directives and add testhelpers |
| BuildFlow | `03596a4` | chore(flake): update vendorHash for go-output dependency changes |
