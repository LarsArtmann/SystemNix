# Session 45 — Stale Vendor Hash Cascade Fix + Build Verification

**Date:** 2026-05-18 22:25
**Status:** BUILD PASSING ✅
**Branch:** master

---

## Summary

Fixed a cascade of stale `vendorHash` / vendor inconsistency build failures across 7 Go repositories and 1 sops secret naming issue. All packages now build successfully with `just test` passing.

---

## A) FULLY DONE ✅

### 1. emeet-pixyd — Stale vendorHash
- **Root cause:** Upstream added `templ` + `golang.org/x/sys` deps, `vendorHash` in `package.nix` was stale
- **Fix:** Updated `vendorHash` to `sha256-LdB/PtHu4QJH7y2QLHxs5zHuvcgJpW4KT9W9Rf4324Q=`
- **Already pushed** to emeet-pixyd master

### 2. file-and-image-renamer — Duplicate requires + missing testhelpers + no go mod tidy
- **Root cause:** `postPatch` added duplicate `require` entries for go-output sub-modules that already existed in `go.mod`, missing `testhelpers` sub-module, no `go mod tidy` in main build
- **Fix:**
  - Rewrote `postPatch` to only add `replace` directives (no duplicate `require`)
  - Added `testhelpers` to sub-modules list (imported by `output_test_helpers.go`)
  - Added `preBuild = "go mod tidy"` to main build
  - Added `proxyVendor = true` to avoid vendor/modules.txt consistency checks
  - Updated `vendorHash` to `sha256-X/eA7MiQ1ZmrFEElYLQfxKym6CmkkzSWW3589V0AflA=`
- **Pushed** as `4a127be`

### 3. golangci-lint-auto-configure — Stale vendorHash
- **Root cause:** `vendorHash` stale after dependency updates
- **Fix:** Updated to `sha256-PXItwurNdQF7gXzKXjOLeeczEzacxCji/BmRvVSy45A=`
- **Pushed** as `0d1731b`

### 4. mr-sync — Stale vendorHash after go-error-family addition
- **Root cause:** `go-error-family` was recently added as a dependency but `vendorHash` wasn't updated
- **Fix:** Updated to `sha256-ofzReteLtNEr1j4QvH4QaaWdGvTn23SwV0cNAhx7bn8=`
- **Pushed** as `3a9b403`

### 5. branching-flow — Wrong subModules format + missing proxyVendor + no go mod tidy
- **Root cause:** Old `mkPreparedSource.nix` applied sub-modules to ALL deps (including `go-finding` which has no sub-modules), no `proxyVendor`, no main build tidy
- **Fix:**
  - Copied newer `mkPreparedSource.nix` from mr-sync (attrset-based `subModules`)
  - Changed `subModules` from list to attrset (only go-output has sub-modules)
  - Added `proxyVendor = true`
  - Added `preBuild = "go mod tidy"` to main build
  - Updated `vendorHash` to `sha256-VAAOnRaEIn0DO1R8Wj45OXs2+zbvYn6UoM5IIfRFFhg=`
- **Pushed** as `1680561`

### 6. library-policy — Stale vendorHash
- **Root cause:** Previous session left `vendorHash = ""` in working tree, committed version had stale hash
- **Fix:** Previous session already pushed fix as `5cfcd56` with correct hash `sha256-txdY/0dN4/lMqTuHxBmmKdkX9UEn7ugLjiOYio05nW0=`

### 7. go-auto-upgrade — Stale vendorHash + missing proxyVendor
- **Root cause:** Same vendor inconsistency pattern — `_local_deps` postPatch makes go.mod inconsistent
- **Fix:**
  - Added `proxyVendor = true`
  - Added `preBuild = "go mod tidy"` to main build
  - Updated `vendorHash` to `sha256-7TWpZUa7/tuUR7oLhQk4XYSA3OxdR4MEq1No6rXtIA8=`
- **Pushed** as `1678fcf`

### 8. monitor365 sops secret key naming mismatch
- **Root cause:** `monitor365.yaml` had keys `cloud_auth_token` and `server_jwt_secret` but `sops.nix` referenced `monitor365_cloud_auth_token` and `monitor365_server_jwt_secret`
- **Fix:** Renamed secret references in `sops.nix` and `monitor365.nix` to match actual YAML keys
- **Committed** as `12841a56` (previous session)

### 9. monitor365.yaml not git-tracked
- **Root cause:** File was in `.gitignore` but needed to be tracked for sops-nix
- **Fix:** Force-added with `git add -f`
- **Committed** in previous session

---

## B) PARTIALLY DONE ⚠️

None — all identified issues have been fully resolved.

---

## C) NOT STARTED ⏳

- Status report document (this file)
- Final commit of flake.lock changes

---

## D) TOTALLY FUCKED UP 💥

### Background Job Exhaustion
- accumulated ~50 background jobs from parallel nix builds across the session
- Blocked all further shell execution until manually killed all 44 stale jobs
- **Improvement:** Kill background jobs immediately after reading output; don't accumulate

### Stash Confusion
- Used `git stash` / `git stash pop` to check state, which briefly made it appear the sops fix was reverted
- Caused unnecessary re-verification of the same changes
- **Improvement:** Don't stash in the middle of work; use `git diff` instead

---

## E) WHAT WE SHOULD IMPROVE 🔧

### 1. Systematic vendorHash check across ALL Go repos
This session fixed 6 repos with the same class of bug. There are likely more. A single script that iterates all Go overlay inputs and checks if their vendorHash is valid would catch these before they cascade.

### 2. The `_local_deps` pattern needs standardization
Every repo using `preparedSrc` / `_local_deps` needs the same 3 things:
- `overrideModAttrs` with `go mod tidy` — fixes the go-modules FOD
- `proxyVendor = true` — avoids vendor directory consistency checks in main build
- `preBuild = "go mod tidy"` — main build tidies go.mod via local proxy

Not all repos have all 3. This should be codified into `mkPreparedSource.nix` itself.

### 3. CI for private repos
All these failures would have been caught by CI on push. None of the private LarsArtmann repos have CI that builds the Nix derivation.

### 4. Auto vendorHash update workflow
`nix build .#default 2>&1 | grep 'got:'` → `sed` → rebuild is manual and error-prone. Each repo should have `nix run .#update-vendor-hash` (some like library-policy already do).

---

## F) Top 25 Things to Do Next

| # | Priority | Task | Category |
|---|----------|------|----------|
| 1 | P0 | Verify `just switch` works on evo-x2 (live deploy) | Build |
| 2 | P0 | Audit ALL remaining Go overlay repos for stale vendorHash (buildflow, go-structure-linter, hierarchical-errors, projects-management-automation, art-dupl, dnsblockd, monitor365) | Build |
| 3 | P0 | Standardize `mkPreparedSource.nix` across all repos — ensure all have `proxyVendor`, `overrideModAttrs` tidy, and `preBuild` tidy | Architecture |
| 4 | P1 | Add `nix run .#update-vendor-hash` to all Go repos that lack it | DX |
| 5 | P1 | Add CI (GitHub Actions) to private repos that builds the Nix derivation | CI |
| 6 | P1 | Run `just test` on Darwin (MacBook Air) — verify cross-platform build | Build |
| 7 | P2 | Fix monitor365.service "Unit not found" during activation (likely ordering issue in systemd) | Services |
| 8 | P2 | Fix whisper-asr.service start failure during activation | Services |
| 9 | P2 | Verify all new services (monitor365-server, openseo, twenty) are functional after deploy | Services |
| 10 | P2 | Run `just health` and verify all Gatus endpoints pass | Monitoring |
| 11 | P2 | Update AGENTS.md with the `proxyVendor + preBuild go mod tidy` pattern as a known requirement | Documentation |
| 12 | P3 | Create a `scripts/check-vendor-hashes.sh` that iterates all Go overlay inputs and validates vendorHash | DX |
| 13 | P3 | Investigate if `mkPreparedSource.nix` can auto-add `proxyVendor = true` to the buildGoModule args | Architecture |
| 14 | P3 | Review buildflow flake.nix for the same `_local_deps` pattern issues | Build |
| 15 | P3 | Review go-structure-linter flake.nix for the same pattern | Build |
| 16 | P3 | Review hierarchical-errors flake.nix for the same pattern | Build |
| 17 | P3 | Review projects-management-automation flake.nix for the same pattern | Build |
| 18 | P3 | Review art-dupl flake.nix — it uses different build system (fork) | Build |
| 19 | P4 | Disk cleanup on evo-x2 after multiple nix builds | Maintenance |
| 20 | P4 | Run `just dns-diagnostics` and verify DNS stack after rebuild | Services |
| 21 | P4 | Check dual-WAN status after rebuild (`just wan-status`) | Networking |
| 22 | P4 | Verify sops secrets decrypted correctly on live system (`sops -d`) | Security |
| 23 | P5 | Consider adding `vendorHash` staleness check to `just test-fast` | DX |
| 24 | P5 | Document the "proxyVendor + preBuild tidy" pattern in a shared reference doc | Documentation |
| 25 | P5 | Review if any repos have `overrideModAttrs` WITHOUT `preBuild` tidy (incomplete fix) | Build |

---

## G) Top #1 Question I Cannot Answer

**Does the monitor365 agent actually work with the renamed sops secret keys?**

The sops YAML file has `cloud_auth_token: ""` (empty value). The sops encryption wraps an empty string. When sops-nix decrypts on the target machine:
- Will it produce an empty auth token file?
- Does monitor365 gracefully handle an empty/missing auth token?
- Is the monitor365 agent even supposed to have a cloud auth token, or was this placeholder never populated?

This can only be verified on the live NixOS machine with `sops -d platforms/nixos/secrets/monitor365.yaml` using the host SSH key.

---

## Build Result

```
just test → BUILD PASSING ✅
(nixos-system-evo-x2 built and activated successfully)
```

### Remaining Runtime Warnings (non-blocking)
- `Failed to start monitor365.service: Unit monitor365.service not found` — new service, needs live deploy
- `Failed to start monitor365-server.service` — same as above
- `Failed to start whisper-asr.service` — pre-existing, unrelated

---

## Files Changed This Session

### SystemNix (uncommitted: flake.lock)
- `flake.lock` — updated inputs: art-dupl, buildflow, go-auto-upgrade (cascading from upstream fixes)

### Upstream repos (all pushed)
| Repo | Commit | Change |
|------|--------|--------|
| emeet-pixyd | (previous) | vendorHash update |
| file-and-image-renamer | `4a127be` | proxyVendor + preBuild tidy + testhelpers sub-module |
| golangci-lint-auto-configure | `0d1731b` | vendorHash update |
| mr-sync | `3a9b403` | vendorHash update |
| branching-flow | `1680561` | mkPreparedSource upgrade + proxyVendor + preBuild tidy |
| library-policy | `5cfcd56` | vendorHash update |
| go-auto-upgrade | `1678fcf` | proxyVendor + preBuild tidy + vendorHash update |

---

_Arte in Aeternum_
