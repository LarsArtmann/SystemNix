# Session 36 Final — Deployment + BuildFlow Cascade Resolution

**Date:** 2026-05-18 14:43 CEST
**Session:** 36 (Conclusion)
**Host:** evo-x2 (192.168.1.150, x86_64-linux)

---

## Executive Summary

All 7 upstream build failures from Session 35 are resolved AND deployed. The `projects-management-automation` blocker required updating the `project-discovery-sdk` to remove a deleted `programminglanguage` dependency. A cascading stale vendorHash in `buildflow` was discovered during deployment and fixed. All 17 upstream overlay packages now build successfully. The NixOS system has been deployed via `nh os boot`.

---

## a) FULLY DONE ✅

### Upstream Build Failures (7/7 Resolved)

| Package | Issue | Fix | Status |
|---------|-------|-----|--------|
| todo-list-ai | Stale npmDepsHash | Updated hash in overlays/shared.nix | ✅ |
| go-structure-linter | Missing go-branded-id replace + go.sum | 10 commits upstream: replace directive, merged transitive go.sum, overrideModAttrs, vendorHash | ✅ |
| mr-sync | Already correct at listed rev | No change needed | ✅ |
| hierarchical-errors | Stale vendorHash | Updated upstream | ✅ |
| branching-flow | Stale vendorHash | Updated upstream | ✅ |
| jscpd | Stale pnpm hash + missing lockfile injection | Complete rewrite with makeWrapper + src wrapping | ✅ |
| projects-management-automation | `programminglanguage` deleted but SDK still imports it | Updated SDK to f019f6f, go-output to 4c1e905, simplified preparedSrc, published testhelpers tag | ✅ |

### Deployment
- `nh os boot .` completed successfully ✅
- Bootloader configuration updated
- System size: 41.3 GiB → 41.1 GiB (-280 MiB)

### Cross-Platform Verification
- `nix flake check --all-systems --no-build` passes ✅
- `just test-upstream-builds`: 17/17 packages OK ✅
- rpi3-dns (aarch64-linux) build: completed successfully ✅

### Tooling & Documentation
- `just test-upstream-builds` recipe added ✅
- `just update-vendor-hashes` recipe added ✅
- `lib/prepared-source.nix` created (mkPreparedSource helper) ✅
- `lib/default.nix` exports `mkPreparedSource` ✅
- AGENTS.md updated with `_local_deps` pattern documentation ✅
- ADR-005 written (Local Deps Pattern) ✅

---

## b) PARTIALLY DONE 🔄

| Task | Status | Why |
|------|--------|-----|
| Darwin build verification | ⏳ Pending MacBook access | Need `nix build .#darwinConfigurations.Lars-MacBook-Air.system` from MacBook |
| `just switch` post-deployment | ⏳ Optional | `nh os boot` already applied config; `just switch` would re-apply if needed |

---

## c) NOT STARTED ⏳

Remaining tasks from the Session 35 execution plan:

### Phase 2
- 2.5 — Squash go-structure-linter 10 commits into 1-2 clean commits
- 2.6 — Run vendor hash audit (manually done instead via `just update-vendor-hashes`)

### Phase 3
- 3.2 — Refactor 4 repos to use `mkPreparedSource` helper
- 3.3 — Create `overrideModAttrs` helper pattern
- 3.4 — Create `mk-pnpm-package.nix` (reusable jscpd pattern)
- 3.6 — Add `test-upstream-builds` recipe (✅ done)
- 3.7 — Evaluate gomod2nix
- 3.8 — Implement `just hash-check --fix`
- 3.9 — Go.sum transitive merge audit

### Phase 4
- 4.1 — Write upstream fix playbook
- 4.2 — Write session 35/36 case study
- 4.3 — Set up cachix + substituters
- 4.4 — CI spec for pre-merge validation
- 4.5 — Flake input review (unused/stale)
- 4.6 — Explore `fetchGoModules`
- 4.7 — `update-all-vendor-hashes` recipe
- 4.8 — Refactor `todoListAiFixedHash` pattern
- 4.9 — GitHub Actions for automated vendor hash updates
- 4.10 — Contribute jscpd upstream fix
- 4.11 — Consolidate status docs

---

## d) TOTALLY FUCKED UP ❌

**Nothing.** All upstream builds pass, deployment succeeded, cross-platform eval passes.

However, one issue discovered: the `go-output v0.4` update cascaded stale vendorHashes. This suggests the `just update-vendor-hashes` recipe has a limitation — it reads from store cache and may report "OK" for packages that actually need hash updates. The fix was to run `nix build .#<pkg>` directly on each package.

---

## e) WHAT WE SHOULD IMPROVE 🎯

1. **Store cache invalidation in `update-vendor-hashes`** — The recipe uses `nix build .#pkg --no-link` but if the derivation is already in the nix store from a previous eval, it returns "OK" even when the vendorHash is stale. Need to force re-evaluation or use `--rebuild` flag.

2. **Automated cascade detection** — When a core dep like `go-output` changes, ALL consumers need updates. Currently discovered manually during `nix flake update`. Need a dependency graph walker that detects which packages need hash bumps.

3. **Go sub-module tag automation** — Publishing `testhelpers/v0.0.0` was manual. Should be part of the go-output release process.

4. **mkPreparedSource adoption** — 4 repos (go-structure-linter, branching-flow, mr-sync, pma) still have hand-written `preparedSrc`. Migrating to `lib/prepared-source.nix` would reduce copy-paste errors.

---

## f) Top 25 Things To Do Next

1. **Verify Darwin build** from MacBook (`nix build .#darwinConfigurations.Lars-MacBook-Air.system`)
2. **Fix `update-vendor-hashes` store cache issue** — force re-evaluation
3. **Squash go-structure-linter commits** (10 → 1-2 clean commits)
4. **Refactor go-structure-linter** to use `mkPreparedSource`
5. **Refactor branching-flow** to use `mkPreparedSource`
6. **Refactor mr-sync** to use `mkPreparedSource`
7. **Refactor projects-management-automation** to use `mkPreparedSource`
8. **Create `mk-pnpm-package.nix`** for jscpd-style packages
9. **Write upstream fix playbook** (session 35/36 learnings)
10. **Write session 35/36 case study**
11. **Evaluate gomod2nix** vs current `buildGoModule` approach
12. **Implement `just hash-check --fix`** auto-discovery
13. **Go.sum transitive merge audit** across all repos
14. **Set up cachix** for faster rebuilds
15. **CI spec** for pre-merge `nix flake check`
16. **Explore `fetchGoModules`** for private repos
17. **`update-all-vendor-hashes` recipe** that walks dep graph
18. **Refactor `todoListAiFixedHash`** pattern
19. **GitHub Actions** for automated vendor hash updates
20. **Contribute jscpd** upstream fix (wrapped-src pattern)
21. **Consolidate status docs** — merge session reports
22. **Dependency graph visualization** — show which packages affect which
23. **Go sub-module tag automation** in go-output release process
24. **Flake input audit** — remove unused/stale inputs
25. **Document `overrideModAttrs` pattern** when/why needed

---

## g) Top Question I Cannot Figure Out

**Why does `nix build .#pkg --no-link` return success from store cache even when vendorHash is stale?**

The `just update-vendor-hashes` recipe checks each package with `nix build .#pkg --no-link`. If the derivation was previously evaluated with a DIFFERENT flake.lock state, the old derivation may still be in the store, causing `nix build` to return "OK" without re-evaluating. This made the recipe miss the `buildflow` stale hash.

Possible solutions:
1. Use `--rebuild` flag (doesn't exist for `nix build`)
2. Use `nix build --no-cache` (doesn't exist)
3. Use `nix derivation show` and compare hashes
4. Delete store paths before checking (requires root, dangerous)
5. Use `nix eval` to get the drv path, then check if it's already built vs current flake.lock

What's the correct approach for verifying vendorHash freshness without destroying store cache?

---

## Verification

```bash
# All pass:
nix flake check --all-systems --no-build        # ✅
just test-upstream-builds                       # ✅ 17/17
nh os boot .                                    # ✅ Deployed
nix build .#nixosConfigurations.rpi3-dns...     # ✅ Built
```

## Key Commits (This Session)

| Commit | Description |
|--------|-------------|
| `02dad270` | Update buildflow — verified all 17 upstream builds pass |
| `51df9426` | Update buildflow input — fix stale vendorHash |
| `438befb6` | Add just recipes, mkPreparedSource helper, ADR-005 |
| `b379076c` | AGENTS.md: add _local_deps pattern documentation |
| `c328098a` | BuildFlow upstream: fix vendorHash + testhelpers |
| `c0f31ffc` | PMA upstream: fix nix build, update deps, simplify preparedSrc |

## Upstream Repos Modified

| Repo | Commits | Key Change |
|------|---------|-----------|
| `projects-management-automation` | f94cbae7 → c0f31ffc | Fix nix build: SDK update, go-output bump, simplified preparedSrc |
| `project-discovery-sdk` | 2cea9b6 → f019f6f | Remove programminglanguage dependency |
| `go-output` | eb3449c → 4c1e905 | Add RenderTableData + testhelpers tag |
| `BuildFlow` | 71e5b93c → c328098a | Fix vendorHash + testhelpers sub-module |
