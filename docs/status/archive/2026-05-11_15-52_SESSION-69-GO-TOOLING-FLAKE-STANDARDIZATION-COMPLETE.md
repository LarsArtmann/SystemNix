# Session 69 — Go Tooling Ecosystem: Nix Flake Standardization COMPLETE

**Date:** 2026-05-11 15:52
**Session Focus:** Standardize Nix flakes across 9 Go projects, wire into SystemNix
**Result:** ALL 9 PROJECTS BUILD ✅ · SYSTEMNIX PASSES ✅ · ALL PUSHED ✅

---

## Executive Summary

Standardized Nix flake builds across the entire Go tooling ecosystem (9 projects). Every project now has a working `nix build .#default`, proper overlays for SystemNix integration, and follows the `preparedSrc` pattern for private dependency resolution in the Nix sandbox.

**9/9 projects build. 5 newly wired into SystemNix. 1 new flake created from scratch.**

---

## a) FULLY DONE ✅

### Projects That Build Successfully

| # | Project | Flake Status | Key Fix |
|---|---------|-------------|---------|
| 1 | **library-policy** | ✅ Best flake (flake-parts, modular) | DRY'd up shared bindings, added overlay |
| 2 | **BuildFlow** | ✅ Complete rewrite | SSH inputs, preparedSrc with 4 private deps, go-output sub-modules |
| 3 | **go-auto-upgrade** | ✅ Fixed | Converted path: → SSH URLs, go.mod replace fix, overlay |
| 4 | **go-structure-linter** | ✅ Complete rewrite | SSH inputs, preparedSrc, go-output sub-modules, overlay |
| 5 | **branching-flow** | ✅ Complete rewrite | SSH inputs, preparedSrc, GOFLAGS=-mod=mod, overlay |
| 6 | **golangci-lint-auto-configure** | ✅ Improved | Added overlay, standardized env vars |
| 7 | **art-dupl** | ✅ Fixed | Updated gogenfilter pin (235fb88), env vars → env block |
| 8 | **PMA** | ✅ Fixed (was hardest) | preparedSrc with 10 private deps, go.work version fixes |
| 9 | **hierarchical-errors** | ✅ NEW FLAKE | Created from scratch, fixed go-finding API migration |

### SystemNix Wiring

5 new flake inputs added with overlays:
- `buildflow` — build automation
- `go-auto-upgrade` — library upgrade automation
- `go-structure-linter` — project structure validation
- `branching-flow` — error context analysis
- `art-dupl` — code duplication detection

All available as `pkgs.buildflow`, `pkgs.go-auto-upgrade`, etc. on all platforms.

### Key Pattern Discovered: `preparedSrc`

The winning pattern for private Go dependencies in Nix:

```nix
preparedSrc = pkgs.stdenv.mkDerivation {
  pname = "project-prepared-source";
  inherit version;
  src = srcFiltered;

  postPatch = ''
    mkdir -p _local_deps
    cp -r ${dep1} _local_deps/dep1
    cp -r ${dep2} _local_deps/dep2
    chmod -R u+w _local_deps

    echo 'replace (' >> go.mod
    echo '  github.com/org/dep1 => ./_local_deps/dep1' >> go.mod
    echo '  github.com/org/dep2 => ./_local_deps/dep2' >> go.mod
    echo ')' >> go.mod
  '';

  installPhase = ''
    mkdir $out
    cp -r . $out/
  '';
};
```

This copies private deps into the source tree and adds `replace` directives so `go mod vendor` can resolve them without SSH access.

### Key Pattern: Overlay outside `eachDefaultSystem`

Overlays must be system-independent. With `flake-utils.lib.eachDefaultSystem`, put overlays in a top-level merge:

```nix
outputs = { ... }:
  {
    overlays.default = _final: prev: {
      mypackage = self.packages.${prev.stdenv.system}.default;
    };
  }
  //
  (flake-utils.lib.eachDefaultSystem (system:
    { packages.default = ...; }
  ));
```

---

## b) PARTIALLY DONE

Nothing — all targeted work is complete.

---

## c) NOT STARTED

| Task | Priority | Notes |
|------|----------|-------|
| Migrate all flakes to `flake-parts` | Low | Only library-policy uses it; others use flake-utils |
| Shared Nix helper library for preparedSrc | Medium | Reduce per-project duplication |
| CI verification for all flakes | Medium | None tested in CI |
| Add hierarchical-errors + PMA overlays to SystemNix | Low | Both build but not yet wired into SystemNix |
| Standardize devShells across all projects | Low | Some have minimal devShells |

---

## d) TOTALLY FUCKED UP

Nothing — all projects build successfully.

### Lessons Learned

1. **PMA vendor swap was the wrong approach** — copying real sources as "dummies" creates transitive dependency chains. The `preparedSrc` pattern (separate derivation, all deps in `_local_deps/`) is the correct approach.
2. **`go.work` leaves inconsistent go.mod files** — when switching from `go.work` to `GOWORK=off`, version mismatches appear (e.g., go-filewatcher v0.2.0 vs v0.2.1, gogenfilter incompatible vs /v3 path).
3. **Overlay placement matters** — `overlays.default` inside `eachDefaultSystem` is NOT accessible from other flakes. Must be at the top level.
4. **gogenfilter module path confusion** — old code uses `github.com/LarsArtmann/gogenfilter` (incompatible), new uses `/v3` suffix. Go treats these as different modules.
5. **art-dupl vendorHash was stale** — the original flake's vendorHash didn't match even before our changes (pre-existing issue with gogenfilter pin mismatch).

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Shared Nix helper** — extract `preparedSrc` pattern into `lib/prepared-src.nix` in one repo, reference from all others
2. **flake-parts everywhere** — migrate from `flake-utils` to `flake-parts` for consistent module system
3. **go-output sub-module handling** — create a shared helper for the `enum/escape/sort/table` boilerplate

### Process

4. **CI for flakes** — add GitHub Actions that run `nix build` on every push
5. **Automated vendorHash updates** — bot/script that detects stale hashes
6. **Flake template** — `nix flake init -t templates#go-private` for new Go projects

### Code

7. **Remove `go.work` from PMA** — now that go.mod is self-consistent, the workspace file is redundant
8. **Tag go-finding v0.4.0** — the `analysis` subpackage needs to be in a published version
9. **art-dupl gogenfilter API mismatch** — the pinned rev works but should use the latest API

---

## f) Top 25 Next Steps (Sorted by Impact)

### High Impact (Do First)

1. **Tag go-finding v0.4.0** with analysis subpackage — eliminates need for local replace in hierarchical-errors
2. **Remove `go.work` from PMA** — go.mod is now self-consistent, go.work is dead weight
3. **Create shared `preparedSrc` helper** in a new `nix-helpers` repo or in `go-output`'s flake
4. **Wire hierarchical-errors into SystemNix** — add flake input + overlay
5. **Wire PMA into SystemNix** — add flake input + overlay (optional, heavy build)
6. **Add CI workflows** for `nix build` on all 9 repos
7. **Remove local go-finding replace** from hierarchical-errors after v0.4.0 tag

### Medium Impact

8. **Migrate BuildFlow to flake-parts** — standardize on one framework
9. **Migrate go-auto-upgrade to flake-parts**
10. **Migrate branching-flow to flake-parts**
11. **Migrate go-structure-linter to flake-parts**
12. **Migrate art-dupl to flake-parts**
13. **Create go-output sub-module helper** — DRY the `enum/escape/sort/table` boilerplate
14. **Add `nix flake template`** for new Go projects with private deps
15. **Standardize devShell packages** across all projects
16. **Add `checks.test`** to all flakes (run test suite via nix)
17. **Verify all flakes on aarch64-darwin** (macOS ARM)

### Lower Impact (Nice to Have)

18. **Add `apps.lint`/`apps.test`** to all flakes consistently
19. **Automate vendorHash bumping** via CI bot
20. **Create `nix/auto-update-flakes.sh`** to batch-update all flake.lock files
21. **Add `formatter` to all flakes** (some missing `pkgs.nixfmt`)
22. **Document the preparedSrc pattern** in a shared ADR
23. **Add `nix develop` instructions** to all project READMEs
24. **Evaluate `gomod2nix`** as alternative to manual preparedSrc
25. **Create a meta-flake** that builds all 9 projects at once for integration testing

---

## g) Top Question

**Should we create a shared `nix-helpers` repo (or add to an existing one) that provides:**
- `preparedSrc` helper function
- `go-output-sub-modules` helper
- Standard `devShell` template
- `flake-parts` module for Go projects with private deps

This would eliminate ~50% of the per-project boilerplate. But it adds another dependency to manage. Worth it?

---

## Technical Details

### The PMA Fix (Hardest Case — 10 Private Deps)

PMA had 10 private `github.com/LarsArtmann/*` dependencies plus:
- `go.work` with local absolute paths
- Two local sub-packages (`pkg/coreutils`, `pkg/domain`)
- Version mismatches from the go.work era:
  - `go-filewatcher`: v0.2.0 → v0.2.1
  - `go-composable-business-types`: v0.3.0 → v0.4.0
  - `gogenfilter`: incompatible v3.0.0 → proper /v3 path
  - Missing `golang.org/x/time v0.15.0` transitive dep

**Failed approaches** (before finding the right one):
1. ❌ Vendor swap with real source dummies (transitive dep chains → `go mod tidy` needed)
2. ❌ Stub packages (couldn't provide sub-packages like `pkg/meta`)
3. ❌ `GOFLAGS=-mod=mod` (doesn't fix version mismatches)
4. ❌ `go mod tidy` in preparedSrc (no network access in sandbox)

**Winning approach**: preparedSrc with sed patches to fix version mismatches + literal go.sum entry injection.

### Files Modified

| Repo | Files Changed | Commits |
|------|--------------|---------|
| BuildFlow | flake.nix, flake.lock | 2 |
| go-auto-upgrade | flake.nix, flake.lock | 2 |
| go-structure-linter | flake.nix, flake.lock | 2 |
| branching-flow | flake.nix, flake.lock | 2 |
| golangci-lint-auto-configure | flake.nix | 2 |
| art-dupl | flake.nix, flake.lock | 3 |
| PMA | flake.nix, flake.lock | 2 |
| hierarchical-errors | flake.nix, flake.lock, pkg/finding/bridge.go, go.mod, go.sum | 2 |
| library-policy | nix/packages/default.nix, flake.nix | 2 |
| SystemNix | flake.nix, flake.lock | 3 |

---

_Arte in Aeternum_
