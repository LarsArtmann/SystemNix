# Session 70 — Full Ecosystem Status: Post-Standardization Audit

**Date:** 2026-05-11 16:14
**Scope:** Full SystemNix + Go tooling ecosystem health check
**System:** evo-x2 (NixOS) — 80% root disk, 73% /data disk

---

## Executive Summary

All 9 Go tooling projects build successfully. SystemNix passes `just test-fast`. The ecosystem is in its healthiest state ever — every LarsArtmann Go project has a working Nix flake with overlays. The audit identified **dead code** in SystemNix's `pkgs/` directory and two projects that need their upstream flakes fixed before SystemNix can delegate to them.

---

## a) FULLY DONE ✅

### Go Tooling Ecosystem (9/9 build)

| Project | Flake Type | Builds | Has Overlay | Wired in SystemNix |
|---------|-----------|--------|-------------|-------------------|
| library-policy | flake-parts | ✅ | ✅ | ✅ |
| BuildFlow | flake-utils + preparedSrc | ✅ | ✅ | ✅ |
| go-auto-upgrade | flake-utils + preparedSrc | ✅ | ✅ | ✅ |
| go-structure-linter | manual forAllSystems + preparedSrc | ✅ | ✅ | ✅ |
| branching-flow | flake-utils + preparedSrc | ✅ | ✅ | ✅ |
| golangci-lint-auto-configure | flake-utils + proxyVendor | ✅ | ✅ | ✅ |
| art-dupl | manual forAllSystems + vendor swap | ✅ | ✅ | ✅ |
| PMA | flake-utils + preparedSrc (10 deps) | ✅ | ✅ | ❌ (not wired yet) |
| hierarchical-errors | flake-utils + preparedSrc | ✅ | ✅ | ❌ (not wired yet) |

### SystemNix Infrastructure

- **35 NixOS service modules** (caddy, gitea, immich, signoz, gatus, etc.)
- **40 flake inputs** (5 new Go tooling inputs from session 69)
- **9 custom packages** in `pkgs/`
- **lib/ shared helpers**: systemd (39 files), types (23 files), rocm (4 files), go-output-submodules (1 file)
- **14 common program modules** shared between Darwin + NixOS
- `just test-fast` passes on both platforms

### Monitoring Stack

- SigNoz: full observability (traces/metrics/logs) with 8 alert rules
- Gatus: 22 health-check endpoints with SQLite storage
- node_exporter + cAdvisor: system + container metrics
- Discord notifications wired for SigNoz and Gatus
- GPU VRAM + niri compositor alert rules active

---

## b) PARTIALLY DONE

### Dead Code in SystemNix `pkgs/`

Two `pkgs/` files are **dead code** — the upstream projects now have their own flakes with overlays that SystemNix already uses:

| Dead `pkgs/` file | Redundant because | Status |
|-------------------|------------------|--------|
| `pkgs/golangci-lint-auto-configure.nix` | Upstream has overlay, SystemNix uses `golangci-lint-auto-configure.overlays.default` | ❌ Not removed yet |
| `pkgs/mr-sync.nix` | Upstream has overlay, SystemNix uses `mr-sync.overlays.default` | ❌ Not removed yet |

Corresponding dead flake inputs (`golangci-lint-auto-configure-src`, `go-finding-src`, `mr-sync-src`) are still declared but unused by the overlay path.

### todo-list-ai Overlay Patches

SystemNix's `todoListAiOverlay` patches upstream's stale `outputHash` for bun deps. This is a workaround — the upstream flake should fix their hash. The overlay rebuilds deps with a corrected hash and patches shebangs.

---

## c) NOT STARTED

### Upstream Flakes That Need Fixing (before SystemNix can delegate)

| Project | Issue | Fix Needed |
|---------|-------|-----------|
| **file-and-image-renamer** | Has a `flake.nix` but it fails: private deps fetched via HTTPS (no SSH), no preparedSrc | Add SSH inputs + preparedSrc pattern like BuildFlow |
| **monitor365** | Has a `flake.nix` but it fails: `linux/videodev2.h` not found (missing `libv4l` build dep) | Add `buildInputs = [ pkgs.libv4l ]` or similar |
| **todo-list-ai** | SystemNix patches upstream's stale bun hash | Upstream should fix `outputHash` in their flake |

### Not Wired into SystemNix Yet

| Project | Why Not | Priority |
|---------|--------|----------|
| PMA | Builds but heavy (10 private deps); no urgent need on server | Low |
| hierarchical-errors | Just got flake; trivial to wire | Medium |

### Wishlist

| Task | Impact | Effort |
|------|--------|--------|
| Shared `preparedSrc` helper across all Go flakes | High (eliminates 50% boilerplate) | Medium |
| Migrate all Go flakes to flake-parts | Medium (standardization) | Medium |
| CI workflows for `nix build` on all repos | High (catch regressions) | Low |
| Create flake template for new Go projects | Medium (DX improvement) | Low |
| Remove `go.work` from PMA | Low (go.mod is now self-consistent) | Low |
| Tag go-finding v0.4.0 (includes analysis/ subpackage) | Medium (eliminates local replace) | Low |

---

## d) TOTALLY FUCKED UP

**Nothing is fucked up.** Everything builds. This is the cleanest the ecosystem has been.

### Historical Lessons (from sessions 67-69)

1. **PMA vendor swap approach was wrong** — copying real sources as "dummies" creates transitive dependency chains. `preparedSrc` is the correct pattern.
2. **Overlay placement inside `eachDefaultSystem` doesn't work** — overlays must be at top level for cross-flake visibility.
3. **`go.work` leaves inconsistent go.mod** — version mismatches only surface when `GOWORK=off`.
4. **gogenfilter `/v3` vs incompatible** — two different Go modules, causes silent resolution failures.
5. **SigNoz `WatchdogSec` on non-notify services** — kills services that don't call `sd_notify()`.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Remove dead `pkgs/` files** — `golangci-lint-auto-configure.nix` and `mr-sync.nix` are shadowed by upstream overlays
2. **Fix file-and-image-renamer flake** — add SSH inputs + preparedSrc, then switch SystemNix to use overlay
3. **Fix monitor365 flake** — add missing `libv4l` build dep, then switch SystemNix to use overlay
4. **Extract `preparedSrc` helper** — into a shared lib or new `nix-helpers` repo
5. **Go-output sub-module helper** — DRY the `enum/escape/sort/table` boilerplate across 5+ projects

### Process

6. **CI for all flakes** — GitHub Actions running `nix build` on push
7. **Automated vendorHash bumping** — detect stale hashes in CI
8. **Flake template** — `nix flake init -t templates#go-private` for new Go projects

### SystemNix Specific

9. **Disk usage at 80%** — root partition getting full, consider cleanup (`just clean`)
10. **`go-output-submodules.nix` used by only 1 file** — `pkgs/file-and-image-renamer.nix`; once that moves upstream, the helper can be removed
11. **PMA + hierarchical-errors not wired** — easy to add, just flake inputs + overlays

---

## f) Top 25 Next Steps (Sorted by Impact × Effort)

### Tier 1: Quick Wins (High Impact, Low Effort)

1. **Remove dead `pkgs/golangci-lint-auto-configure.nix`** — upstream overlay already provides this
2. **Remove dead `pkgs/mr-sync.nix`** — upstream overlay already provides this
3. **Remove dead `golangci-lint-auto-configure-src` + `go-finding-src` flake inputs** — no longer needed
4. **Remove dead `mr-sync-src` flake input** — no longer needed
5. **Wire hierarchical-errors into SystemNix** — add flake input + overlay (1 line each)
6. **Wire PMA into SystemNix** — add flake input + overlay (1 line each)
7. **Remove `go.work` from PMA** — go.mod is self-consistent now, workspace file is dead weight
8. **Tag go-finding v0.4.0** — publish the analysis/ subpackage, eliminating local replace in hierarchical-errors
9. **Remove local go-finding replace from hierarchical-errors** — after v0.4.0 tag
10. **Run `just clean`** — root disk at 80%, reclaim space from old generations/closures

### Tier 2: Medium Effort, High Value

11. **Fix file-and-image-renamer flake** — add SSH inputs + preparedSrc (like BuildFlow)
12. **Fix monitor365 flake** — add `libv4l`/`linuxHeaders` build dep
13. **Switch SystemNix to file-and-image-renamer overlay** — once upstream flake works
14. **Switch SystemNix to monitor365 overlay** — once upstream flake works
15. **Create shared `preparedSrc` helper** — eliminate 50% boilerplate across 9 Go flakes
16. **Create go-output sub-module helper** — DRY the enum/escape/sort/table pattern
17. **Add CI workflow** — GitHub Actions `nix build` for all 9 Go repos

### Tier 3: Standardization

18. **Migrate BuildFlow to flake-parts** — consistent module system
19. **Migrate go-auto-upgrade to flake-parts**
20. **Migrate branching-flow to flake-parts**
21. **Migrate art-dupl to flake-parts**
22. **Create `nix flake template`** for new Go projects with private deps
23. **Add `checks.test`** to all flakes (run test suite via nix)
24. **Verify all flakes on aarch64-darwin** (macOS ARM)
25. **Create meta-flake** that builds all 9 projects at once for integration testing

---

## g) Top #1 Question

**Should `lib/go-output-submodules.nix` live in SystemNix or in `go-output`'s own flake?**

Currently this helper generates `require`+`replace` directives for go-output's 4 sub-modules (enum, escape, sort, table). It's used by `pkgs/file-and-image-renamer.nix` in SystemNix but is also needed by 7 other Go projects independently. If go-output exported this as a flake output (e.g., `go-output.lib.subModuleReplacements`), every consumer could use it without duplicating the sub-module list. But it would make go-output a required input even for projects that don't use it directly.

---

## System Health

| Metric | Value | Status |
|--------|-------|--------|
| Root disk (`/`) | 80% used (103 GB free) | ⚠️ Watch |
| Data disk (`/data`) | 73% used (280 GB free) | ✅ OK |
| Go projects building | 9/9 | ✅ |
| SystemNix `test-fast` | Passes | ✅ |
| Dead `pkgs/` files | 2 | ⚠️ Cleanup needed |
| Dead flake inputs | 3 (`*-src` for golangci-lint-auto-configure, go-finding, mr-sync) | ⚠️ Cleanup needed |
| Flakes needing upstream fix | 2 (file-and-image-renamer, monitor365) | 🔧 In progress |

---

_Arte in Aeternum_
