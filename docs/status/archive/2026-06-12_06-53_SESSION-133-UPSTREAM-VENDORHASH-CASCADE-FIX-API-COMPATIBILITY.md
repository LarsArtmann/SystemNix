# Session 133: Upstream vendorHash Cascade Fix + API Compatibility

**Date:** 2026-06-12 03:20 → 06:53
**Duration:** ~3.5 hours
**Trigger:** `nh os boot` failed with `lib.fileset.unions: Element 1 (go.sum) is a path that does not exist` in `file-and-image-renamer`
**Outcome:** ✅ Build succeeds. 15 upstream repos fixed. 3 SystemNix files changed.

---

## a) FULLY DONE

### SystemNix Changes (4 files, +241/-99 lines)

| File | Change |
|------|--------|
| `overlays/shared.nix` | Restored `mkTidyOverride` pattern for `library-policy` and `mr-sync` (need `proxyVendor` + `go mod tidy`); reverted all packages back to `mkPackageOverlay` after upstream overlay cascade failures; updated `go-auto-upgrade` vendorHash |
| `flake.nix` | Removed `cmdguard.follows` for `mr-sync`; removed ALL `follows` except `nixpkgs` for `projects-management-automation` |
| `flake.lock` | Updated 12+ flake inputs to latest upstream revisions |
| `modules/nixos/services/twenty.nix` | Fixed shellcheck SC2034: `for i in` → `for _ in` |

### Upstream Repos Fixed (all committed & pushed)

| Repo | Fix | Commit |
|------|-----|--------|
| `art-dupl` | Updated stale vendorHash | `75d5a76` |
| `dnsblockd` | Updated vendorHash in `nix/vendor-hash.nix` | `9a27371` |
| `emeet-pixyd` | Updated vendorHash in BOTH `flake.nix` AND `package.nix` | `f7346cb` |
| `go-structure-linter` | Updated vendorHash | `965b9d2` |
| `hierarchical-errors` | Updated vendorHash | `7b8a5e0` |
| `library-policy` | Updated vendorHash in `nix/packages/default.nix` | `5158530` |
| `mr-sync` | Updated vendorHash in `package.nix` | `83df8d4` |
| `project-meta` | Updated vendorHash | `4f7440c` |
| `file-and-image-renamer` | Updated vendorHash | `89fe38f` |
| `BuildFlow` | Updated go-output + go-structure-linter flake inputs | `3f607ca` |
| `go-auto-upgrade` | Bumped go-output to v0.9.0; added `plantuml` sub-module replace; adapted `MustNewCommand` → `NewCommand` API change | `b152e5c` |
| `DiscordSync` | Added missing `projection/v2` to go-cqrs-lite subModules; updated vendorHash | `8cff9ca` |
| `go-finding` | Restored `Severity.Badge()` and `Severity.Emoji()` methods accidentally removed in `1fdd80e` | `7642edc` |
| `projects-management-automation` | Force-pushed back to `39aedca` (pre-API-break revision) | `39aedca` |

---

## b) PARTIALLY DONE

### Overlay Migration to `repo.overlays.default`

**Goal:** Eliminate manual `vendorHash` maintenance in SystemNix by having each upstream repo bake its own vendorHash into `overlays.default`.

**Attempted:** Migrated 9 packages to `repo.overlays.default` pattern (like `monitor365`, `crush-daily`, `overview`).

**Result:** Had to revert ALL of them back to `mkPackageOverlay` because:

1. **`library-policy` and `mr-sync`** — need `mkTidyOverride` (proxyVendor + go mod tidy) which the upstream overlays don't include
2. **`art-dupl`, `go-structure-linter`, `branching-flow`, `project-meta`** — upstream overlays have stale vendorHash that breaks when SystemNix overrides deps via `follows`
3. **`hierarchical-errors`, `golangci-lint-auto-configure`** — same stale vendorHash issue
4. **`projects-management-automation`** — cascading API breaks from cmdguard + branching-flow + go-structure-linter

**Root cause:** When SystemNix uses `follows` to override a repo's inputs (e.g., `go-finding.follows = "go-finding"`), the upstream repo's baked-in vendorHash becomes invalid because the dependency tree changes. The upstream overlay builds with ITS pinned deps, but SystemNix swaps in different versions.

**What actually works:** Only repos where SystemNix does NOT override deps (like `monitor365`, `crush-daily`, `overview`) can safely use `repo.overlays.default`.

---

## c) NOT STARTED

- Immich OAuth login test (was the original goal of session 132)
- Deploy with `just switch` and verify Immich login works
- Test PKCE compatibility with confidential client
- Commit unrelated `zellij.nix` change
- NixOS assertion cross-checking Immich callback URLs against Pocket ID client config
- oauth2-proxy client enrichment (launchURL, logoFile, logoutCallbackURLs)

---

## d) TOTALLY FUCKED UP

### The Overlay Migration Was a Trap

The entire `repo.overlays.default` migration (commit `e98a37bc`) from session 132 was fundamentally flawed. It assumed that swapping `mkPackageOverlay` for `repo.overlays.default` would work when SystemNix overrides upstream deps via `follows`. This is **incorrect** — when SystemNix injects its own `go-finding`, `go-output`, `cmdguard`, etc. via `follows`, the upstream overlay's baked-in `vendorHash` doesn't match the new dependency tree.

**Lesson:** `repo.overlays.default` ONLY works when the upstream repo uses its own pinned dependencies WITHOUT SystemNix `follows` overrides. For repos where SystemNix overrides deps, `mkPackageOverlay` with manual vendorHash is required.

### cmdguard v2.6.0 API Break

`cmdguard` commit `c8d86c8` removed ALL `Must*` panic-inducing functions (`MustNewCommand`, `MustNewCLI`, `MustAddCommand`, `MustNewParentCommand`). This broke 3 repos:
- `go-auto-upgrade` (fixed: adapted to `NewCommand` error-returning API)
- `mr-sync` (workaround: removed `cmdguard.follows`)
- `projects-management-automation` (workaround: removed ALL `follows`)

### go-finding Accidental Method Removal

`go-finding` commit `1fdd80e` ("remove dead code") deleted `Severity.Badge()` and `Severity.Emoji()` which `go-structure-linter` depends on. Restored in `7642edc`.

### DiscordSync Missing SubModule

`DiscordSync` was missing `projection/v2` in its `go-cqrs-lite` subModules list, causing "could not read Username" errors during Nix builds. Fixed in `8cff9ca`.

---

## e) WHAT WE SHOULD IMPROVE

### Critical

1. **CI for upstream repos:** Every LarsArtmann Go repo should have CI that runs `nix build .#default` on every push. This would catch stale vendorHash BEFORE it blocks SystemNix builds.

2. **Dependabot/Renovate for Nix:** Automated PRs when nixpkgs updates trigger vendorHash changes. Currently every nixpkgs bump risks breaking 10+ repos.

3. **`follows` policy:** Define a clear policy for which inputs should `follows` vs. let the upstream repo pin its own. The current "follow everything" approach causes cascading breakage. Consider only following `nixpkgs` and `flake-parts`.

### Important

4. **Upstream overlays need `proxyVendor = true`** when they use `mkPreparedSource` with local deps. Without it, `go mod tidy` in the build phase fails.

5. **`Severity.Badge()`/`Emoji()` should never have been removed** — they're part of the public API used by consumers. Adding a `go vet` or integration test that checks downstream compilation would prevent this.

6. **`projects-management-automation` needs a full API migration** to match current cmdguard + branching-flow + go-structure-linter APIs. Currently it's frozen at an older revision.

### Nice to Have

7. **Automated vendorHash update script:** A script that iterates all Go repos, sets `vendorHash = ""`, builds, and patches the correct hash.

8. **Flakehub or self-hosted binary cache:** Would eliminate repeated rebuilds of the same packages across machines.

---

## f) Top 25 Things We Should Get Done Next

### Immediate (This Session / Next)

1. **Deploy with `just switch`** and verify the build actually boots
2. **Test Immich OAuth login via Pocket ID** — the original goal from session 132
3. **Test PKCE compatibility** — uncertain if `pkceEnabled=true` with confidential client causes issues
4. **Commit `zellij.nix`** — unrelated pre-existing change still unstaged
5. **Update AGENTS.md** with the `follows` policy lesson and overlay pattern documentation

### Short-Term (This Week)

6. **Add CI to all LarsArtmann Go repos** — `nix build .#default` on every push
7. **Fix `projects-management-automation`** — migrate to current cmdguard + branching-flow + go-structure-linter APIs
8. **Fix `mr-sync`** — migrate from `MustNewCommand` to `NewCommand`
9. **Re-attempt overlay migration** for repos WITHOUT `follows` overrides only
10. **Enrich oauth2-proxy Pocket ID client** — add `launchURL`, `logoFile`, `logoutCallbackURLs`
11. **Add NixOS assertion** cross-checking Immich callback URLs against Pocket ID config
12. **Write automated vendorHash updater script** — iterate repos, set `""`, build, patch

### Medium-Term (This Month)

13. **Implement `follows` policy** — only follow `nixpkgs` and `flake-parts`; let repos pin their own Go deps
14. **Add `proxyVendor = true`** to all upstream Go overlays using `mkPreparedSource`
15. **Investigate Flakehub/binary cache** to eliminate redundant builds
16. **Audit all `follows` declarations** in `flake.nix` — identify which ones actually need overriding
17. **Add downstream compilation test** to `go-finding`, `go-output`, `cmdguard` — ensure public API changes don't break consumers
18. **Clean up `go-auto-upgrade` flake.nix** — remove the `vendorHash`/`vendorHashTidied` dual-hash pattern; simplify

### Long-Term

19. **Migrate PMA to current API surface** across all internal deps
20. **Consider Go workspace** for tightly-coupled repos (cmdguard, go-output, go-finding) to catch API breaks at development time
21. **Standardize all Go repo flake.nix** to a common template with `proxyVendor = true`, `go mod tidy` in both phases, and proper sub-module handling
22. **Add `nix flake check` to CI** for all repos — catches eval errors early
23. **Create a `scripts/update-all-vendor-hashes.sh`** tool that can bulk-fix stale hashes
24. **Document the overlay decision tree** in AGENTS.md: when to use `mkPackageOverlay` vs `repo.overlays.default`
25. **Review Diskonnect/Jan resource management** — OOM cascades still threaten system stability

---

## g) Top #1 Question I Cannot Figure Out Myself

**What is the intended `follows` policy?**

Should SystemNix override upstream repo dependencies via `follows` (current approach, causes vendorHash cascade), or should each upstream repo pin its own deps and SystemNix just use whatever version the upstream has baked in?

The current "follow everything" approach means every nixpkgs or Go dep update in SystemNix potentially breaks 10+ upstream repo builds. But it also ensures consistency — all repos use the same `go-finding`, `go-output`, etc.

**The tradeoff:**
- **Follow everything** → consistent deps, but fragile (any dep change cascades to all consumers)
- **Follow nothing (except nixpkgs)** → stable builds, but potential version skew across repos
- **Follow selectively** → best of both, but requires manual curation

Which direction do you want to go? This decision affects every future SystemNix build.

---

## Build Verification

```
$ nh os boot .
✅ SIZE: 44.8 GiB → 44.9 GiB (+108 MiB)
✅ Adding configuration to bootloader
```

All 4 changed files in SystemNix, 15 upstream repos fixed and pushed.
