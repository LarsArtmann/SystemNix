# Session 35 — Comprehensive Execution Plan

**Date:** 2026-05-17 22:30 CEST
**Scope:** All TODOs from session 35 status report, decomposed into ≤12min tasks

---

## Legend

| Column | Meaning |
|--------|---------|
| **ID** | Task identifier (phase + number) |
| **Phase** | P0=critical/blocking, P1=high-value, P2=improvement, P3=nice-to-have |
| **Task** | What to do |
| **Effort** | Estimated time (max 12 min each) |
| **Impact** | What it unlocks |
| **Repo** | Where the work happens |

---

## Phase 1: P0 — Unblock Full Build & Deploy (3 tasks, ~25 min)

| ID | Task | Effort | Impact | Repo |
|----|------|--------|--------|------|
| 1.1 | Investigate `projects-management-automation` upstream — check `go-composable-business-types` repo for `programminglanguage` sub-module. If missing, check if it's a new feature not yet released. If it's a premature merge, pin flake input to last working rev (`git log --all` to find it) | 10m | Unblocks `nh os boot` | SystemNix + pma |
| 1.2 | Apply the pma fix (pin rev or add missing module) to `flake.nix` input, update `flake.lock`, verify `nix build '.#packages.x86_64-linux.projects-management-automation'` passes | 10m | Unblocks all downstream | SystemNix |
| 1.3 | Run `nh os boot .` to verify full NixOS build succeeds. Then `just switch` to deploy to evo-x2 | 5m | Deploys ALL 6 fixes | SystemNix |

---

## Phase 2: P1 — Immediate Hygiene & Verification (7 tasks, ~60 min)

| ID | Task | Effort | Impact | Repo |
|----|------|--------|--------|------|
| 2.1 | Configure GitHub `access-tokens` in `~/.config/nix/nix.conf` (or `extra-options` in nix settings) to avoid API 403 rate limits during `nix flake update`. Use `gh auth token` to get the token. | 5m | Reliable flake updates | SystemNix |
| 2.2 | Verify Darwin (`aarch64-darwin`) build: `nix build '.#packages.aarch64-darwin.todo-list-ai' '.#packages.aarch64-darwin.go-structure-linter' '.#packages.aarch64-darwin.mr-sync' --no-link`. Run from MacBook or use `--system` flag. | 10m | Cross-platform confidence | SystemNix |
| 2.3 | Review rpi3-dns build: `nix build '.#nixosConfigurations.rpi3-dns.config.system.build.toplevel' --no-link` | 5m | DNS cluster health | SystemNix |
| 2.4 | Update AGENTS.md in SystemNix with session 35 lessons: (1) `overrideModAttrs` + `go mod tidy` pattern for go-modules, (2) transitive go.sum merging when using `_local_deps`, (3) jscpd wrapped-src pattern for pnpm | 10m | Better future sessions | SystemNix |
| 2.5 | Squash go-structure-linter's 10 fix commits: `git reset --soft <first-fix-commit~1>` then `git commit` with clean message documenting the full fix (replace directive + go.sum merge + overrideModAttrs + vendorHash) | 10m | Clean git history | go-structure-linter |
| 2.6 | Audit all Go overlay repos for stale `vendorHash`: for each of `library-policy`, `hierarchical-errors`, `golangci-lint-auto-configure`, `art-dupl`, `go-auto-upgrade`, `dnsblockd`, `file-and-image-renamer` — check if `vendorHash` matches current go.sum by running `nix build '.#packages.x86_64-linux.<name>' --no-link` | 12m | Prevent future breakage | SystemNix |
| 2.7 | Create `just update-vendor-hashes` recipe in justfile: iterates all Go overlay packages, sets empty vendorHash, builds, extracts `got:` hash, writes back. Add to `AGENTS.md` and justfile. | 8m | One-command hash updates | SystemNix |

---

## Phase 3: P2 — Automation & Standardization (14 tasks, ~110 min)

| ID | Task | Effort | Impact | Repo |
|----|------|--------|--------|------|
| 3.1 | Create `lib/prepared-source.nix` helper: `mkPreparedSource { deps = [{ name = "go-output"; input = go-output; pkg = "github.com/larsartmann/go-output"; subModules = ["enum" "escape" "sort" "table"]; }]; src = ./.; }` — generates the `_local_deps` + replace directives boilerplate | 12m | DRY across 6+ repos | SystemNix lib/ |
| 3.2 | Apply `mkPreparedSource` to `go-structure-linter/flake.nix` — replace manual postPatch with helper call. Verify build passes. | 8m | Standardized pattern | go-structure-linter |
| 3.3 | Apply `mkPreparedSource` to `branching-flow/flake.nix`. Verify build. | 5m | Standardized pattern | branching-flow |
| 3.4 | Apply `mkPreparedSource` to `mr-sync/flake.nix`. Verify build. | 5m | Standardized pattern | mr-sync |
| 3.5 | Apply `mkPreparedSource` to `projects-management-automation/flake.nix`. Verify build. Note: this repo has 9 deps + sed patches — helper must support `extraPostPatch`. | 10m | Standardized pattern | pma |
| 3.6 | Add `overrideModAttrs` with `go mod tidy` to branching-flow, mr-sync, and pma flake.nix files (same pattern as go-structure-linter). Prevents future go.sum drift. | 10m | Prevents go.sum issues | multiple |
| 3.7 | Investigate `fetchBundlerDeps` or alternative for `todo-list-ai` in `overlays/shared.nix`. Check if bun's lockfile can be fetched without a fixed-output hash. Document findings. | 10m | Less fragile bun builds | SystemNix |
| 3.8 | Extract jscpd's wrapped-src pattern into `pkgs/mk-pnpm-package.nix` helper: takes `src`, `lockfile`, and produces a package with correct `fetchPnpmDeps` and installPhase. | 10m | Reusable pnpm pattern | SystemNix |
| 3.9 | Write ADR for `_local_deps` pattern: when to use (private deps), how to maintain transitive go.sum, the `overrideModAttrs` + `go mod tidy` pattern. File: `docs/adr/ADR-xxx-local-deps-pattern.md`. | 8m | Documentation | SystemNix |
| 3.10 | Add `just test-upstream-builds` recipe: builds ALL overlay packages for current system. `nix build '.#packages.x86_64-linux.*' --no-link` equivalent. | 5m | Pre-deploy validation | SystemNix |
| 3.11 | Investigate `gomod2nix` for automatic vendor hash management. Check nixpkgs or nur for existing package. Test on one repo. If viable, document adoption path. | 10m | Automated go deps | SystemNix |
| 3.12 | Investigate BuildFlow `--quick` flag for hash-only changes. Check if BuildFlow already supports skip patterns. If not, create issue in BuildFlow repo. | 8m | Faster upstream fixes | buildflow |
| 3.13 | Proactive go.sum audit: for each repo with `_local_deps` (go-structure-linter, branching-flow, mr-sync, pma), verify go.sum includes all transitive deps from locked local dep versions. Script it: compare `go.sum` against `git show <rev>:go.sum` for each dep. | 12m | Prevent future go.sum issues | multiple |
| 3.14 | Create `just hash-check` improvement: currently checks overlay packages. Extend to also check that vendorHash is not stale by attempting a build with empty hash and comparing. Add `--fix` flag. | 10m | Automated hash validation | SystemNix |

---

## Phase 4: P3 — Long-term Improvements (11 tasks, ~100 min)

| ID | Task | Effort | Impact | Repo |
|----|------|--------|--------|------|
| 4.1 | Create `docs/contributing/UPSTREAM-FIX-PLAYBOOK.md`: step-by-step guide for fixing upstream build failures. Include: (1) identify failing package, (2) check if vendorHash issue, (3) empty hash technique, (4) `_local_deps` replace directive debugging, (5) go.sum transitive merging. Reference go-structure-linter 10-commit journey as case study. | 10m | Knowledge transfer | SystemNix |
| 4.2 | Document the go-structure-linter 10-step debug journey as a case study in `docs/case-studies/go-structure-linter-fix.md`. Include the full timeline of approaches and why each failed. | 10m | Learning resource | SystemNix |
| 4.3 | Set up Cachix binary cache for private LarsArtmann repos. Create cachix cache, configure `nix.settings.substituters` in flake.nix, push initial builds. | 10m | Faster builds | SystemNix |
| 4.4 | Design CI/CD pipeline spec: GitHub Actions workflow that runs `nix flake check --all-systems` + `nix build` for all overlay packages on every push. Document in `docs/ci/`. | 10m | Catch failures early | SystemNix |
| 4.5 | Review all 38 flake inputs for stale/unused dependencies. Check which inputs haven't been updated in 30+ days. Flag inputs that could be consolidated or removed. | 10m | Dependency hygiene | SystemNix |
| 4.6 | Investigate `fetchGoModules` / `goModulesHook` in nixpkgs for better vendor hash management. Check nixpkgs pkgs/build-support/go/ for newer alternatives to `buildGoModule`. | 8m | Better tooling | SystemNix |
| 4.7 | Create `just update-all-vendor-hashes` recipe: script that (1) runs `nix flake update`, (2) for each Go package, sets empty vendorHash, (3) builds all, (4) extracts correct hashes, (5) writes back, (6) commits. | 12m | Fully automated updates | SystemNix |
| 4.8 | Refactor `overlays/shared.nix` `todoListAiFixedHash` — check if bun 1.3.11 supports `--no-save` or deterministic installs that don't need a fixed hash. If yes, remove the hash entirely. | 8m | Less fragile | SystemNix |
| 4.9 | Add GitHub Actions workflow file `.github/workflows/build.yml`: triggers on push, runs `nix flake check` + builds all overlay packages. Use `nix-shell` or `cachix/install-nix-action`. | 10m | CI/CD | SystemNix |
| 4.10 | Review `pkgs/jscpd.nix` — check if nixpkgs has a newer version of jscpd that can be used directly instead of custom packaging. If yes, remove local package and use nixpkgs. | 5m | Less maintenance | SystemNix |
| 4.11 | Clean up `docs/status/` — move all files except latest 5 to `archive/` subdirectory. Add `.gitkeep` to archive. Update justfile if needed. | 7m | Clean repo | SystemNix |

---

## Summary Statistics

| Phase | Tasks | Total Time | Status |
|-------|-------|------------|--------|
| P0 — Critical | 3 | ~25 min | 🔴 Must do NOW |
| P1 — High Value | 7 | ~60 min | 🟡 Do this session |
| P2 — Improvement | 14 | ~110 min | 🟢 Do this week |
| P3 — Nice-to-have | 11 | ~100 min | 🔵 Backlog |
| **Total** | **35** | **~295 min** | |

## Dependency Graph

```
1.1 → 1.2 → 1.3 (P0 chain — unblocks everything)
2.1 (independent — GitHub token)
2.2, 2.3 (independent — verification)
2.4 (after 1.3 — needs deployed state)
2.5 (independent — git cleanup)
2.6 → 2.7 (audit first, then automate)
3.1 → 3.2, 3.3, 3.4, 3.5 (helper first, then adopt)
3.6 (independent — after 3.1 pattern is proven)
3.7, 3.8, 3.11, 3.12 (independent investigations)
3.9, 3.10, 3.13, 3.14 (independent — after 2.7)
4.x (all independent — backlog)
```

## Recommended Execution Order

1. **1.1** → **1.2** → **1.3** (unblock build)
2. **2.1** (GitHub token — quick win)
3. **2.6** → **2.7** (audit + automate vendor hashes)
4. **2.5** (clean git history)
5. **3.1** → **3.2** → **3.3** → **3.4** → **3.5** (standardize preparedSrc)
6. **3.6** (add go mod tidy everywhere)
7. **2.4** (update AGENTS.md)
8. **2.2**, **2.3** (verify other platforms)
9. **3.7–3.14** (pick and choose, all independent)
10. **4.x** (backlog — schedule as time permits)
