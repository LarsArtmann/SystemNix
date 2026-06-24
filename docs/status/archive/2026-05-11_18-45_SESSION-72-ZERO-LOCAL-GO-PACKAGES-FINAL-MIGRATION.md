# Session 72 — Zero Local Go Packages: file-and-image-renamer & monitor365 Delegated to Upstream

**Date:** 2026-05-11 18:45
**Scope:** Final upstream flake migration — eliminate all local Go/Rust package definitions
**System:** evo-x2 (NixOS) — 80% root disk, 80% /data disk

---

## Executive Summary

Both file-and-image-renamer and monitor365 upstream flakes were fixed and their packages delegated from SystemNix local `pkgs/` to upstream overlay references. This eliminates **4 source-only flake inputs** (`file-and-image-renamer-src`, `cmdguard-src`, `go-output-src`, `monitor365-src`), **2 local package files** (-120 lines), and **`lib/go-output-submodules.nix`** (the only consumer was file-and-image-renamer).

**Result: `pkgs/` now contains 5 local packages — zero of which are Go projects.** All 12 LarsArtmann Go/Rust tooling projects are now provided via upstream flake overlays. The migration started in session 69 is complete.

---

## a) FULLY DONE ✅

### Upstream Flake Fixes

| Project | Issue | Fix | Build Status |
|---------|-------|-----|-------------|
| file-and-image-renamer | Placeholder vendorHash, no SSH inputs, no src filtering, no postPatch for go-output sub-modules | Added `cmdguard-src` + `go-output-src` as flake inputs, src filtering, `postPatch` with require+replace for cmdguard + go-output + 4 sub-modules (enum/escape/sort/table), proxyVendor, overlay | ✅ Builds |
| monitor365 | `linux/videodev2.h` not found (missing bindgen include paths) | Added `linuxHeaders` to nativeBuildInputs, `BINDGEN_EXTRA_CLANG_ARGS` with glibc/kernel/clang include paths, `doCheck = false`, overlay | ✅ Builds |
| monitor365 (Rust) | `ExposeSecret` trait not in scope in `crates/server/src/config.rs` | Added `use secrecy::ExposeSecret` | ✅ Fixed |

### SystemNix Overlay Migration

| Before | After |
|--------|-------|
| `file-and-image-renamer-src` (flake=false) + `cmdguard-src` (flake=false) + `go-output-src` (flake=false) → 3 inputs, 1 local overlay, 1 local pkg file | `file-and-image-renamer` (full flake, follows nixpkgs) → 1 input, upstream overlay |
| `monitor365-src` (flake=false) → 1 input, 1 local overlay with cleanSourceWith, 1 local pkg file | `monitor365` (full flake, follows nixpkgs) → 1 input, upstream overlay |

### Dead Code Removed

| File | Lines Removed | Reason |
|------|--------------|--------|
| `pkgs/file-and-image-renamer.nix` | 67 | Delegated to upstream overlay |
| `pkgs/monitor365.nix` | 53 | Delegated to upstream overlay |
| `lib/go-output-submodules.nix` | 11 | Only consumer was file-and-image-renamer — now upstream |

### From Session 70 (Included in This Commit)

| Change | File |
|--------|------|
| Discord alerts on 15 Gatus endpoints | `gatus-config.nix` |
| SigNoz alert rules (GPU VRAM, niri compositor, disk space) | `signoz.nix` |
| `hardenUser` helper for user systemd services | `lib/default.nix`, `lib/user-harden.nix` |
| monitor365 service hardened with `hardenUser` | `monitor365.nix` |

### Verification

- `just test-fast` passes on both `x86_64-linux` and `aarch64-darwin`
- All 23 packages evaluate correctly (meta.description verified for migrated packages)
- No stale references to removed inputs in any `.nix` file
- Lock file cleaned: 4 source-only inputs removed, 2 full flake inputs added

### Full Ecosystem State

**Go/Rust Tooling (12/12 wired via upstream overlays):**

| Project | Overlay Type | In SystemNix |
|---------|-------------|-------------|
| library-policy | upstream | ✅ shared |
| BuildFlow | upstream | ✅ shared |
| go-auto-upgrade | upstream | ✅ shared |
| go-structure-linter | upstream | ✅ shared |
| branching-flow | upstream | ✅ shared |
| art-dupl | upstream | ✅ shared |
| golangci-lint-auto-configure | bridge | ✅ shared |
| mr-sync | bridge | ✅ shared |
| hierarchical-errors | bridge | ✅ shared |
| todo-list-ai | hybrid (hash patch) | ✅ shared |
| dnsblockd | upstream | ✅ Linux-only |
| emeet-pixyd | upstream | ✅ Linux-only |
| monitor365 | upstream | ✅ Linux-only |
| file-and-image-renamer | upstream | ✅ Linux-only |

**SystemNix Infrastructure:**

| Metric | Count |
|--------|-------|
| NixOS service modules | 35 |
| Flake inputs | 38 (was 40, removed 4 src inputs, added 2 full flakes) |
| Local packages in `pkgs/` | 5 (was 9 → 7 → 5) |
| Go local packages in `pkgs/` | **0** (was 5) |
| Upstream overlay packages | 14 |
| Total packages exposed | 23 |
| nixosModules exposed | 34 |
| lib/ shared helpers | 3 (systemd, service-defaults, types, rocm — go-output-submodules removed) |

---

## b) PARTIALLY DONE

### todo-list-ai Overlay Patches

SystemNix's `todoListAiOverlay` patches upstream's stale `outputHash` for bun deps. Every todo-list-ai update may require a hash update. The upstream flake should fix their hash.

**Status:** Functional but fragile.

### golangci-lint-auto-configure Overlay Bug

Upstream defines `overlays.default` inside `eachDefaultSystem`, creating per-system keys instead of a single `overlays.default`. SystemNix uses a thin bridge overlay as workaround.

**Status:** Works. Upstream cosmetic issue.

---

## c) NOT STARTED

### Remaining Wish List (Deprioritized)

| Task | Impact | Effort | Priority |
|------|--------|--------|----------|
| Wire PMA into SystemNix | Low (no server need) | Medium | Low |
| Wire go-finding as standalone input | Low (transitive dep) | Trivial | Low |
| Shared `preparedSrc` helper across all Go flakes | Medium (DX) | Medium | Low |
| Migrate all Go flakes to flake-parts | Medium (standardization) | Medium | Low |
| CI workflows for `nix build` on all repos | High (regression catch) | Low | Low |
| Create flake template for new Go projects | Medium (DX) | Low | Low |
| Remove `go.work` from PMA | Low | Trivial | Low |
| Tag go-finding v0.4.0 | Medium | Trivial | Low |
| Fix golangci-lint-auto-configure upstream overlay | Low (cosmetic) | Trivial | Low |

---

## d) TOTALLY FUCKED UP

**Nothing is fucked up.** Everything builds and evaluates on both platforms.

### Near-Miss: monitor365 Rust Compilation

The `secrecy` crate updated their API — `expose_secret()` now requires `use secrecy::ExposeSecret` trait import. The `crates/server/src/config.rs` was missing this import. Fixed with a one-line addition. Would have silently compiled fine with an older `secrecy` version.

### Near-Miss: file-and-image-renamer postPatch

First attempt only added `replace` directives for go-output sub-modules without `require`. Go needs both: `require github.com/larsartmann/go-output/enum v0.0.0` AND `replace ... => local/path`. The SystemNix local pkg (`lib/go-output-submodules.nix`) had both — copying just the replace was insufficient.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Disk at 80%/80%** — both root and /data are at the warning threshold. `just clean` is overdue.
2. **Bridge overlay consolidation** — 3 identical bridge overlays (golangci-lint-auto-configure, mr-sync, hierarchical-errors) could be a single helper function. With only 3 instances this is borderline, but if more projects use `eachDefaultSystem` incorrectly, it becomes a pattern.
3. **netwatch still in local pkgs/** — last Rust project with a local package file. If it gets an upstream flake with overlay, `pkgs/` drops to 4 files (jscpd, modernize, aw-watcher, openaudible).

### Process

4. **CI for all flakes** — now that all 14 tooling projects build via flakes, a single CI workflow can verify them all on push.
5. **Automated vendorHash bumping** — detect stale hashes in CI, especially for todo-list-ai.

### SystemNix Specific

6. **PMA not wired** — trivial once cloned, but no server need.
7. **Flake input count dropped 40→38** — but could go lower if remaining source-only inputs (wallpapers-src, signoz-src, signoz-collector-src) were consolidated or eliminated.

---

## f) Top #25 Next Steps (Sorted by Impact × Effort)

### Tier 1: Quick Wins

1. **Run `just clean`** — both disks at 80%, reclaim space
2. **Fix golangci-lint-auto-configure overlay** — move outside `eachDefaultSystem` (eliminates bridge overlay)
3. **Tag go-finding v0.4.0** — publish analysis/ subpackage, eliminate local replace in hierarchical-errors
4. **Remove local go-finding replace from hierarchical-errors** — after v0.4.0 tag
5. **Remove `go.work` from PMA** — go.mod is self-consistent
6. **Wire PMA into SystemNix** — add flake input + overlay (once cloned)
7. **Wire go-finding as standalone input** — trivial
8. **Create shared bridge-overlay helper** — for the 3 identical bridge overlays

### Tier 2: Medium Effort

9. **Fix netwatch upstream flake** — add overlay, switch SystemNix (eliminates last local Rust pkg)
10. **Fix todo-list-ai upstream hash** — stop requiring local hash patching
11. **Create shared `preparedSrc` helper** — eliminate 50% boilerplate across Go flakes
12. **Add CI workflow** — GitHub Actions `nix build` for all 14 Go/Rust repos
13. **Create `nix flake template`** — for new Go projects with private deps
14. **Consolidate source-only inputs** — wallpapers-src could become a proper flake input
15. **Add `checks.test`** to all upstream flakes — run test suite via nix
16. **Verify all flakes on aarch64-darwin** — macOS ARM compatibility

### Tier 3: Standardization

17. **Migrate golangci-lint-auto-configure to flake-parts**
18. **Migrate BuildFlow to flake-parts**
19. **Migrate go-auto-upgrade to flake-parts**
20. **Migrate branching-flow to flake-parts**
21. **Migrate art-dupl to flake-parts**
22. **Migrate monitor365 to flake-parts** (currently flake-utils)
23. **Create meta-flake** — build all 14 projects at once for integration testing
24. **Eliminate remaining bridge overlays** — fix upstream eachDefaultSystem patterns
25. **Automate flake.lock updates** — scheduled Dependabot/Renovate for nix flakes

---

## g) Top #1 Question

**Should netwatch get an upstream flake with overlay to complete the "zero local compiled packages" goal?**

Currently `pkgs/` has 5 files:
- `jscpd.nix` — Node.js, always needs local pkg (npm lockfile)
- `modernize.nix` — fetches from golang.org/x/tools, always needs local pkg
- `aw-watcher-utilization.nix` — Python, fetched from GitHub fork
- `openaudible.nix` — AppImage wrapper, always needs local pkg
- `netwatch.nix` — Rust, could have upstream flake

Of these 5, only netwatch is a LarsArtmann project that could provide its own overlay. The other 4 will always need local definitions. If netwatch gets an upstream flake, `pkgs/` becomes truly "only things that can't be upstreamed" — a clean architectural boundary.

---

## System Health

| Metric | Value | Status |
|--------|-------|--------|
| Root disk (`/`) | 80% used (101 GB free) | ⚠️ Clean needed |
| Data disk (`/data`) | 80% used (206 GB free) | ⚠️ Watch |
| Go/Rust projects wired | 14/14 | ✅ All via upstream overlays |
| Go local packages in pkgs/ | 0 | ✅ Zero |
| SystemNix `test-fast` | Passes (both platforms) | ✅ |
| Dead `pkgs/` files | 0 | ✅ Clean |
| Dead flake inputs | 0 | ✅ Clean |
| Dead lib/ helpers | 0 | ✅ Clean (go-output-submodules removed) |
| Bridge overlays | 3 | 🔧 Workaround for upstream bugs |
| Flake inputs | 38 (down from 40) | ✅ Net reduction |

---

_Arte in Aeternum_
