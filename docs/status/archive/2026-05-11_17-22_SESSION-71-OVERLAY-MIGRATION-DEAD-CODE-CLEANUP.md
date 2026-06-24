# Session 71 — Overlay Migration, Dead Code Cleanup, hierarchical-errors Onboarded

**Date:** 2026-05-11 17:22
**Scope:** SystemNix dead code removal, upstream flake migration, new project wiring
**System:** evo-x2 (NixOS) — 80% root disk, 78% /data disk

---

## Executive Summary

Migrated `golangci-lint-auto-configure` and `mr-sync` from local `pkgs/` definitions to upstream flake input overlays, removing 105 lines of duplicate package code. Wired `hierarchical-errors` as a new flake input. Fixed stale `vendorHash` in mr-sync upstream. The ecosystem now has **10 Go tooling projects** wired as flake inputs with overlays — up from 5 at session 69. `pkgs/` reduced from 9 to 7 local packages.

**Critical finding:** The session 70 status doc contained an inaccuracy — it claimed `pkgs/golangci-lint-auto-configure.nix` and `pkgs/mr-sync.nix` were "dead code" because "upstream overlays already exist and are used." In reality, both were still actively built from local `-src` inputs. The migration to upstream flakes had not yet happened. This session performed the actual migration.

---

## a) FULLY DONE ✅

### Overlay Migration (3 projects migrated)

| Project | Before | After | Change |
|---------|--------|-------|--------|
| golangci-lint-auto-configure | Local `pkgs/*.nix` + `-src` inputs (2) | Full flake input + bridge overlay | Removed 82 lines, 2 inputs → 1 |
| mr-sync | Local `pkgs/*.nix` + `-src` input | Full flake input + bridge overlay | Removed 23 lines, 1 input → 1 |
| hierarchical-errors | Not wired | Full flake input + bridge overlay | Added as new package |

### Upstream Fix

| Project | Fix | Status |
|---------|-----|--------|
| mr-sync | Stale `vendorHash` in `package.nix` → updated to `sha256-5NUJF/ugm9RLzgfM2TZRrlNVO8d2u9/IMWlWIk+Su1k=` | ✅ Fixed & builds |

### Documentation Updated

- `AGENTS.md` — Updated overlay lists, flake inputs table, architecture tree
- `pkgs/README.md` — Removed entries for migrated packages, updated note about overlay-provided tools

### Validation

- `just test-fast` passes on both `x86_64-linux` and `aarch64-darwin`
- All 3 new/modified packages evaluate correctly (meta.description verified)
- No stale references to removed inputs in any `.nix` file
- Lock file cleaned: `golangci-lint-auto-configure-src`, `go-finding-src`, `mr-sync-src` removed

### Monitoring Stack (from session 70, confirmed healthy)

- **SigNoz**: 8 alert rules, Discord notifications wired
- **Gatus**: 22 health-check endpoints, SQLite storage
- **node_exporter + cAdvisor**: system + container metrics
- **19/20 systemd services** have `onFailure` notifications wired
- **niri-config.nix**: gpu-recovery hardened with `harden {}` + `serviceDefaults {}`

### Go Tooling Ecosystem (10/10 wired in SystemNix)

| Project | Flake Input | Overlay | Package Exposed |
|---------|-------------|---------|-----------------|
| library-policy | ✅ | ✅ upstream | ✅ |
| BuildFlow | ✅ | ✅ upstream | ✅ |
| go-auto-upgrade | ✅ | ✅ upstream | ✅ |
| go-structure-linter | ✅ | ✅ upstream | ✅ |
| branching-flow | ✅ | ✅ upstream | ✅ |
| art-dupl | ✅ | ✅ upstream | ✅ |
| golangci-lint-auto-configure | ✅ | ✅ bridge | ✅ |
| mr-sync | ✅ | ✅ bridge | ✅ |
| hierarchical-errors | ✅ | ✅ bridge | ✅ |
| todo-list-ai | ✅ | ✅ hybrid (hash patch) | ✅ |

### SystemNix Infrastructure Totals

| Metric | Count |
|--------|-------|
| NixOS service modules | 35 |
| Flake inputs | 40 |
| Local packages in `pkgs/` | 7 |
| Upstream overlay packages | 10 |
| Total packages exposed | 20 (14 shared + 6 Linux-only) |
| nixosModules exposed | 34 |
| lib/ shared helpers | 4 (systemd, service-defaults, types, rocm) |
| Common program modules | 14 |
| Lock file nodes | 115 |

---

## b) PARTIALLY DONE

### golangci-lint-auto-configure Overlay Bug

The upstream `flake.nix` defines `overlays.default` inside `flake-utils.lib.eachDefaultSystem`, which creates per-system overlay keys (`overlays.x86_64-linux.default`, `overlays.aarch64-darwin.default`) instead of a single `overlays.default`. This is a known issue with `eachDefaultSystem` + overlays.

**Workaround:** SystemNix uses bridge overlays (`golangciLintAutoConfigureOverlay`, `mrSyncOverlay`) that reference `packages.${system}.default` directly. These are thin 3-line wrappers.

**Status:** Works perfectly. Upstream bug is cosmetic — the overlay function is identical across systems. Just awkward API.

### todo-list-ai Overlay Patches

SystemNix's `todoListAiOverlay` patches upstream's stale `outputHash` for bun deps. This is a workaround — the upstream flake should fix their hash. The overlay rebuilds deps with a corrected hash and patches shebangs.

**Status:** Functional but fragile — every todo-list-ai update may require a hash update.

---

## c) NOT STARTED

### Upstream Flakes That Need Fixing (before SystemNix can delegate)

| Project | Issue | Fix Needed | Effort |
|---------|-------|-----------|--------|
| **file-and-image-renamer** | Has a `flake.nix` but it fails: private deps fetched via HTTPS (no SSH), no preparedSrc | Add SSH inputs + preparedSrc pattern like BuildFlow | Medium |
| **monitor365** | Has a `flake.nix` but it fails: `linux/videodev2.h` not found (missing `libv4l` build dep) | Add `buildInputs = [ pkgs.libv4l ]` or similar | Low |
| **todo-list-ai** | SystemNix patches upstream's stale bun hash | Upstream should fix `outputHash` in their flake | Low |
| **golangci-lint-auto-configure** | `overlays.default` inside `eachDefaultSystem` → per-system keys | Move overlay outside `eachDefaultSystem` | Low |

### Not Wired into SystemNix Yet

| Project | Why Not | Priority |
|---------|--------|----------|
| PMA | Not cloned locally; heavy (10 private deps); no urgent server need | Low |
| go-finding | Library only, used as transitive dep via replace directives | Low |

### Wishlist (Unchanged from Session 70)

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

**Nothing is fucked up.** Everything builds and evaluates. Both platforms pass `just test-fast`.

### Session 70 Status Doc Inaccuracy

The session 70 status doc (`2026-05-11_16-14_SESSION-70-FULL-ECOSYSTEM-STATUS-POST-STANDARDIZATION.md`) incorrectly stated:

> Two `pkgs/` files are **dead code** — the upstream projects now have their own flakes with overlays that SystemNix already uses

This was **not true**. Both packages were actively built from local `pkgs/` files using `-src` inputs. The upstream flakes existed but SystemNix had not been switched to use them. This session performed the actual migration.

**Lesson:** Always verify claims by checking the actual code, not just the documentation.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Fix golangci-lint-auto-configure upstream overlay** — move outside `eachDefaultSystem` so `overlays.default` works properly
2. **Fix file-and-image-renamer flake** — add SSH inputs + preparedSrc, then switch SystemNix to use overlay
3. **Fix monitor365 flake** — add missing `libv4l` build dep, then switch SystemNix to use overlay
4. **Extract `preparedSrc` helper** — into a shared lib or new `nix-helpers` repo
5. **Remove `go-output-submodules.nix`** — once file-and-image-renamer moves upstream, this helper becomes dead code in SystemNix
6. **Consolidate bridge overlays** — 3 projects now use thin bridge overlays; could be a single helper function

### Process

7. **CI for all flakes** — GitHub Actions running `nix build` on push
8. **Automated vendorHash bumping** — detect stale hashes in CI
9. **Flake template** — `nix flake init -t templates#go-private` for new Go projects
10. **Verify status doc accuracy** — cross-check claims against actual code before writing

### SystemNix Specific

11. **Disk usage at 80%** — root partition getting full, `just clean` recommended
12. **PMA not wired** — easy to add once cloned, just flake input + overlay
13. **go-finding as input** — trivial, useful for hierarchical-errors independence

---

## f) Top #25 Next Steps (Sorted by Impact × Effort)

### Tier 1: Quick Wins (High Impact, Low Effort)

1. **Run `just clean`** — root disk at 80%, reclaim space from old generations/closures
2. **Fix golangci-lint-auto-configure overlay** — move outside `eachDefaultSystem` (3-line change in upstream)
3. **Tag go-finding v0.4.0** — publish the analysis/ subpackage, eliminating local replace in hierarchical-errors
4. **Remove local go-finding replace from hierarchical-errors** — after v0.4.0 tag
5. **Remove `go.work` from PMA** — go.mod is self-consistent now, workspace file is dead weight
6. **Wire PMA into SystemNix** — add flake input + overlay (once cloned)
7. **Wire go-finding as standalone input** — useful for hierarchical-errors independence
8. **Create shared bridge-overlay helper** — one function for the 3 bridge overlays (golangci-lint-auto-configure, mr-sync, hierarchical-errors)

### Tier 2: Medium Effort, High Value

9. **Fix file-and-image-renamer flake** — add SSH inputs + preparedSrc (like BuildFlow)
10. **Fix monitor365 flake** — add `libv4l`/`linuxHeaders` build dep
11. **Switch SystemNix to file-and-image-renamer overlay** — once upstream flake works; removes 3 source inputs + `go-output-submodules.nix`
12. **Switch SystemNix to monitor365 overlay** — once upstream flake works; removes 1 source input
13. **Create shared `preparedSrc` helper** — eliminate 50% boilerplate across 9 Go flakes
14. **Create go-output sub-module helper** — DRY the enum/escape/sort/table pattern
15. **Add CI workflow** — GitHub Actions `nix build` for all Go repos
16. **Fix todo-list-ai upstream hash** — stop requiring local hash patching

### Tier 3: Standardization

17. **Migrate golangci-lint-auto-configure to flake-parts** — consistent module system
18. **Migrate BuildFlow to flake-parts** — consistent module system
19. **Migrate go-auto-upgrade to flake-parts**
20. **Migrate branching-flow to flake-parts**
21. **Migrate art-dupl to flake-parts**
22. **Create `nix flake template`** for new Go projects with private deps
23. **Add `checks.test`** to all flakes (run test suite via nix)
24. **Verify all flakes on aarch64-darwin** (macOS ARM)
25. **Create meta-flake** that builds all 10 projects at once for integration testing

---

## g) Top #1 Question

**Should the 3 bridge overlays be consolidated into a single helper function?**

Currently `golangciLintAutoConfigureOverlay`, `mrSyncOverlay`, and `hierarchicalErrorsOverlay` are identical 3-line wrappers that all follow the same pattern:

```nix
overlayName = _final: prev: {
  package-name = flake-input.packages.${prev.stdenv.system}.default;
};
```

With 3 instances this is tolerable. But if we're adding PMA, go-finding, and eventually file-and-image-renamer + monitor365 (5+ bridge overlays), a single helper would eliminate repetition:

```nix
bridgeOverlay = flakeInput: pkgName: _final: prev: {
  ${pkgName} = flakeInput.packages.${prev.stdenv.system}.default;
};
```

**Tradeoff:** More abstraction vs. DRY. The existing pattern (each overlay is 3 lines) is arguably clearer than a helper function. But 7+ identical wrappers is a code smell.

---

## Commits This Session

| Commit | Description |
|--------|-------------|
| `a6cd7555` | `fix(monitoring): wire onFailure to 9 services, fix flake overlay references` |
| `3dac3f9d` | `chore(deps): migrate golangci-lint-auto-configure and mr-sync to flake overlays` |

## System Health

| Metric | Value | Status |
|--------|-------|--------|
| Root disk (`/`) | 80% used (101 GB free) | ⚠️ Watch |
| Data disk (`/data`) | 78% used (232 GB free) | ✅ OK |
| Go projects wired | 10/10 | ✅ |
| Go projects building via overlay | 10/10 | ✅ |
| SystemNix `test-fast` | Passes (both platforms) | ✅ |
| Dead `pkgs/` files | 0 | ✅ Clean |
| Dead flake inputs | 0 | ✅ Clean |
| Flakes needing upstream fix | 3 (file-and-image-renamer, monitor365, todo-list-ai) | 🔧 In progress |
| Upstream overlay bugs | 1 (golangci-lint-auto-configure eachDefaultSystem) | 🔧 Low priority |

---

_Arte in Aeternum_
