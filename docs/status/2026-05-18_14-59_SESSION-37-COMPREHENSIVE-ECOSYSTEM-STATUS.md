# Session 37 — Comprehensive Ecosystem Status Report

**Date:** 2026-05-18 14:59 CEST
**Session:** 37
**Host:** evo-x2 (192.168.1.150, x86_64-linux)
**Branch:** master (1 commit ahead of origin)
**Total Commits:** 2409
**Repo Size:** 933 MiB

---

## Executive Summary

SystemNix is in **excellent shape**. All 17 upstream overlay packages build cleanly. Both NixOS configurations (evo-x2 + rpi3-dns) evaluate and build successfully. The Darwin (macOS) configuration evaluates cleanly via `nix flake check`. The session 35/36 cascade of build failures (7 packages broken by go-output/go-branded-id dependency chain) is fully resolved and deployed. Vendor hash audit (just completed) confirms zero stale hashes. The codebase has zero TODO/FIXME/HACK comments, clean flake check, and consistent architecture patterns.

**One real concern:** The flake.lock has grown to **136 transitive inputs** (duplicated flake-parts ×11, nixpkgs-lib ×8, go-output ×7, go-branded-id ×6, go-finding ×6, gogenfilter ×5, systems ×12). This is a downstream consequence of each private Go repo having its own `flake.nix` with independent flake-parts/nixpkgs-lib dependencies. Not broken, but bloated.

---

## a) FULLY DONE ✅

### Core Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| flake.nix architecture | ✅ | flake-parts modular, 34 service modules, 3 system configs |
| NixOS evo-x2 build | ✅ | `nh os boot` deployed successfully (session 36) |
| NixOS rpi3-dns build | ✅ | SD image builds (3.38 GiB, aarch64-linux) |
| Darwin evaluation | ✅ | `nix flake check --all-systems --no-build` passes |
| `nix flake check` | ✅ | All derivations evaluate, all systems check |
| Vendor hash audit | ✅ | All 14 overlay packages: zero stale hashes |
| `just test-upstream-builds` | ✅ | 17/17 packages build successfully |

### Upstream Overlay Packages (17/17 Building)

| Package | Overlay | Status |
|---------|---------|--------|
| library-policy | mkPackageOverlay (shared) | ✅ |
| hierarchical-errors | mkPackageOverlay (shared) | ✅ |
| golangci-lint-auto-configure | mkPackageOverlay (shared) | ✅ |
| mr-sync | mkPackageOverlay (shared) | ✅ |
| buildflow | mkPackageOverlay (shared) | ✅ |
| go-auto-upgrade | mkPackageOverlay (shared) | ✅ |
| go-structure-linter | mkPackageOverlay (shared) | ✅ |
| branching-flow | mkPackageOverlay (shared) | ✅ |
| art-dupl | mkPackageOverlay (shared) | ✅ |
| projects-management-automation | mkPackageOverlay (shared) | ✅ |
| dnsblockd | overlays.default (linux) | ✅ |
| file-and-image-renamer | overlays.default (linux) | ✅ |
| emeet-pixyd | overlays.default (linux) | ✅ |
| monitor365 | overlays.default (linux) | ✅ |
| todo-list-ai | custom bun overlay (shared) | ✅ |
| jscpd | custom pnpm overlay (shared) | ✅ |
| aw-watcher-utilization | callPackage (shared) | ✅ |

### Service Modules (34 registered, all evaluate)

All 34 service modules registered in `serviceModules` list in flake.nix. Each is a self-contained flake-parts module with own options under `services.<name>`.

### Libraries (lib/)

| Library | Consumers | Status |
|---------|-----------|--------|
| lib/systemd.nix (`harden`/`hardenUser`) | 20+ service modules | ✅ Active |
| lib/systemd/service-defaults.nix | 15+ modules + niri-wrapped | ✅ Active |
| lib/types.nix (`serviceTypes`) | 12+ service modules | ✅ Active |
| lib/docker.nix | voice-agents | ✅ Active |
| lib/rocm.nix | ai-stack, comfyui | ✅ Active |
| lib/graphical-user-service.nix | niri-config, file-and-image-renamer | ✅ Active |
| lib/prepared-source.nix | **0 consumers** | ⚠️ Exported but unused |

### Cross-Platform Programs (15 modules in platforms/common/programs/)

activitywatch, bash, chromium, fish, fzf, git, keepassxc, pre-commit, shell-aliases, ssh-config, starship, taskwarrior, tmux, zsh

### Tooling & Recipes

| Tool | Status |
|------|--------|
| `just hash-check` | ✅ Tests all overlay vendor hashes |
| `just test-upstream-builds` | ✅ Builds all 17 packages |
| `just update-vendor-hashes` | ✅ Auto-discovers stale hashes (has cache limitation) |
| `just test-fast` | ✅ Syntax-only validation |
| `just test` | ✅ Full build validation |
| `just format` | ✅ treefmt + alejandra |
| `just validate-scripts` | ✅ shellcheck all scripts |
| `mkPreparedSource` helper | ✅ Created (lib/prepared-source.nix) |
| ADR-005 (local deps pattern) | ✅ Written |

### Session 36 Completion

All 7 upstream build failures from session 35 resolved:
- go-structure-linter: go-branded-id replace + go.sum merge
- hierarchical-errors: stale vendorHash
- branching-flow: stale vendorHash
- jscpd: stale pnpm hash + lockfile rewrite
- projects-management-automation: deleted SDK dependency
- buildflow: cascading stale vendorHash from go-output update
- todo-list-ai: stale npmDepsHash

---

## b) PARTIALLY DONE 🔄

### mkPreparedSource Adoption (0/4 repos)

The `mkPreparedSource` helper was created in `lib/prepared-source.nix` but **no repos have adopted it yet**. Four repos still have hand-written `preparedSrc` blocks:
1. go-structure-linter
2. branching-flow
3. mr-sync
4. projects-management-automation

### Darwin Build Verification

`nix flake check` evaluates Darwin successfully, but a full `nix build .#darwinConfigurations.Lars-MacBook-Air.system` has not been run from the MacBook since session 36 changes. The macOS config may have issues only visible at build time.

### Flake Lock Bloat

136 transitive inputs in flake.lock. Many are duplicated across private Go repos:
- flake-parts: ×11 copies
- nixpkgs-lib: ×8 copies
- go-output: ×7 copies (transitive from private Go repos)
- go-branded-id: ×6 copies
- go-finding: ×6 copies
- gogenfilter: ×5 copies
- systems: ×12 copies

This is because each private Go repo has its own `flake.nix` with `flake-parts` and `nixpkgs-lib` as dependencies. When SystemNix imports them all, the lock file accumulates duplicates. Not broken, but the lock file is unnecessarily large.

### go-structure-linter Commit History

The fix for go-structure-linter was 10 commits. Should be squashed to 1-2 clean commits for readability.

---

## c) NOT STARTED ⏳

### High Impact (Phase 3 from Session 35 Plan)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | Refactor 4 repos to use `mkPreparedSource` | DRY, reduce copy-paste errors | Medium |
| 2 | Create `mk-pnpm-package.nix` reusable helper | Extract jscpd pattern for reuse | Medium |
| 3 | Document `overrideModAttrs` pattern | Knowledge preservation | Low |
| 4 | Implement `just hash-check --fix` auto-repair | Developer velocity | Medium |
| 5 | Go.sum transitive merge audit | Prevent future cascade failures | Medium |

### Medium Impact (Phase 4 from Session 35 Plan)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 6 | Write upstream fix playbook | Prevent repeated debugging | Low |
| 7 | Write session 35/36 case study | Institutional knowledge | Low |
| 8 | Set up cachix for faster rebuilds | Build speed | High |
| 9 | CI spec for pre-merge validation | Prevent breakage | High |
| 10 | Flake input audit (unused/stale inputs) | Lock file cleanup | Medium |
| 11 | Explore `fetchGoModules` for private repos | Simplify vendor management | High |
| 12 | `update-all-vendor-hashes` recipe with dep graph | Cascade prevention | High |
| 13 | Refactor `todoListAiFixedHash` pattern | Consistency | Low |
| 14 | GitHub Actions for automated vendor hash updates | Automation | High |
| 15 | Contribute jscpd upstream fix | Give back to open source | Medium |

### Not Started (General Backlog)

| # | Task | Notes |
|---|------|-------|
| 16 | Consolidate/archive status docs | 10+ status reports in docs/status/, could archive old ones |
| 17 | Dependency graph visualization | Show which packages affect which when go-output changes |
| 18 | Go sub-module tag automation | go-output/testhelpers release process |
| 19 | Darwin disk space strategy | MacBook Air at 90-95% full, need distributed builds or cleanup |
| 20 | rpi3-dns hardware provisioning | Pi 3 not yet provisioned, cluster is "planned" status |

---

## d) TOTALLY FUCKED UP ❌

**Nothing is fundamentally broken.** The system builds, deploys, and runs.

However, there are **quality concerns** worth calling out:

### 1. `update-vendor-hashes` Recipe Reports false negatives

The `just update-vendor-hashes` recipe uses `nix build .#pkg --no-link` which returns "OK" from the nix store cache even when the vendorHash is stale. This caused the buildflow stale hash to be missed in session 36. The `just hash-check` recipe works correctly because it runs a fresh build. **Both recipes should be consolidated** or `update-vendor-hashes` should be fixed.

### 2. Dead/Stale Files

| File | Issue |
|------|-------|
| `pkgs/jscpd-package-lock.json` | Leftover from npm-based build, not referenced. jscpd now uses pnpm. |

### 3. Unused Exports

| Export | Issue |
|--------|-------|
| `flake.lib` (`inputs.self.lib`) | Exported but never consumed by any module in the codebase |
| `mkPreparedSource` (lib/prepared-source.nix) | Exported via `flake.lib` but no repo uses it yet |

### 4. Packages Built But Not Installed

| Package | Issue |
|---------|-------|
| `netwatch` | Built via overlay, exposed as flake package, but NOT in `base.nix` or any `environment.systemPackages` |
| `govalid` | Built via overlay, exposed as flake package, but NOT in `base.nix` or any `environment.systemPackages` |

These packages exist in the nix store as buildable derivations but are not on any user's PATH. Either add to `base.nix` or remove from overlays if not needed.

### 5. photomap Disabled

In `configuration.nix:131`: `# photomap.enable = true;` — commented out. Either enable it or remove the line and the service module.

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Architecture

1. **Flake lock deduplication** — 136 transitive inputs is excessive. Consider having private Go repos follow `nixpkgs` (they already do), but also have them follow `flake-parts` from a single source. Or switch private repos to simpler build approaches (e.g., `buildGoModule` directly without flake-parts overhead).

2. **mkPreparedSource adoption** — 4 repos still have hand-written preparedSrc. The helper exists but needs upstream repo migration.

3. **Package installation audit** — `netwatch` and `govalid` are built but not installed. This is wasted build time and confusing for discoverability. Rule: if it's in overlays, it should be in `base.nix` (or documented why not).

### Developer Experience

4. **Consolidate hash-check recipes** — `just hash-check` and `just update-vendor-hashes` do overlapping things but with different behaviors. `hash-check` actually builds, `update-vendor-hashes` can miss stale hashes. Should be one recipe that always works.

5. **Dead file cleanup** — `pkgs/jscpd-package-lock.json` should be deleted. It's from the npm era, jscpd now uses pnpm.

6. **Status doc hygiene** — 10 status reports in `docs/status/` plus older ones in `archive/`. Consider a rolling window (keep last 5, archive the rest).

### Reliability

7. **Cascade failure prevention** — When go-output changes, all consumers need updates. Need a dependency graph tool that answers: "I updated go-output — which packages need vendor hash bumps?"

8. **CI/CD** — No CI exists. Pre-merge `nix flake check --all-systems --no-build` would catch evaluation errors before they reach master.

9. **Darwin build verification** — After session 36 changes, Darwin hasn't been fully built. Should be part of the CI pipeline.

### Code Quality

10. **Consistent ADR numbering** — Some ADRs use `001-` prefix, others use `ADR-005-`. Standardize to one format.

11. **photomap decision** — Service module exists but is disabled. Decide: enable it, or remove the module and the commented line.

---

## f) Top 25 Things To Do Next

### Tier 1: Immediate (This Session or Next)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 1 | **Delete `pkgs/jscpd-package-lock.json`** | Dead file, leftover from npm→pnpm migration | 1 min |
| 2 | **Add `netwatch` and `govalid` to `base.nix`** (or document why not) | Built but not installed = confusing | 5 min |
| 3 | **Decide on `photomap`** — enable or remove | Dead commented code in configuration.nix | 5 min |
| 4 | **Fix `update-vendor-hashes` false negatives** | Missed buildflow stale hash in session 36 | Medium |
| 5 | **Consolidate `hash-check` + `update-vendor-hashes`** into one reliable recipe | Two overlapping tools with different accuracy | Medium |

### Tier 2: Short Term (Next Few Sessions)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 6 | **Refactor go-structure-linter** to use `mkPreparedSource` | DRY, reduce copy-paste | Medium |
| 7 | **Refactor branching-flow** to use `mkPreparedSource` | DRY | Medium |
| 8 | **Refactor mr-sync** to use `mkPreparedSource` | DRY | Medium |
| 9 | **Refactor projects-management-automation** to use `mkPreparedSource` | DRY | Medium |
| 10 | **Squash go-structure-linter** commits (10 → 1-2) | Clean git history | 10 min |
| 11 | **Write upstream fix playbook** | Session 35/36 learnings documented | Low |
| 12 | **Verify Darwin build** from MacBook | Ensure macOS still builds after session 36 | 30 min |

### Tier 3: Medium Term (Next Week)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 13 | **Flake input audit** — identify and remove unused inputs | 136 transitive inputs is excessive | Medium |
| 14 | **Create `mk-pnpm-package.nix`** reusable helper | jscpd pattern extracted for reuse | Medium |
| 15 | **Set up cachix** for binary cache | Faster rebuilds, CI prerequisite | High |
| 16 | **CI spec** — GitHub Actions `nix flake check` | Prevent breakage on push | High |
| 17 | **Dependency graph visualization** | "What breaks when go-output updates?" | Medium |

### Tier 4: Strategic (Next Month)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 18 | **Explore `fetchGoModules`** for private repos | Simplify vendor management | High |
| 19 | **GitHub Actions** for automated vendor hash updates | Full automation | High |
| 20 | **`update-all-vendor-hashes`** with dep graph walker | Cascade prevention | High |
| 21 | **Darwin disk space strategy** (distributed builds to evo-x2) | MacBook at 90-95% full | High |
| 22 | **Standardize ADR numbering** (all `NNN-` or all `ADR-NNN-`) | Consistency | Low |
| 23 | **Archive old status docs** | 10+ reports, keep last 5 | Low |
| 24 | **rpi3-dns hardware provisioning** | Pi 3 DNS cluster backup node | Hardware |
| 25 | **Contribute jscpd upstream fix** (wrapped-src pattern) | Give back to open source | Medium |

---

## g) Top Question I Cannot Figure Out

**Should `netwatch` and `govalid` be added to `base.nix` (making them available on PATH for all users), or are they intentionally overlay-only (buildable but not installed)?**

- `netwatch` is a Rust TUI for real-time network diagnostics — seems useful on NixOS (evo-x2)
- `govalid` is a Go struct validation code generator — seems like a dev tool that should be available
- Both are exposed as flake packages (`packages.x86_64-linux.*`)
- Neither is in `base.nix` or any `environment.systemPackages`
- The AGENTS.md says: "All overlay tools that are meant to be user-facing are listed in `base.nix`"

This suggests they should either be added to `base.nix` or documented as intentionally overlay-only. I can't determine the intent without asking.

---

## System Metrics

| Metric | Value |
|--------|-------|
| `.nix` files | 111 |
| Shell scripts | 17 |
| Service modules | 34 |
| Overlay packages | 17 (building) |
| Cross-platform programs | 15 modules |
| Enabled services on evo-x2 | ~30 |
| Flake inputs (direct) | 30 |
| Flake inputs (transitive) | 136 |
| ADRs | 7 |
| Status reports | 10 (+ this one) |
| Planning docs | 30+ |
| Total commits | 2409 |

## Key Verification Commands

```bash
nix flake check --all-systems --no-build   # ✅ passes
just hash-check                             # ✅ all 14 packages OK
just test-upstream-builds                   # ✅ 17/17 OK
nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage  # ✅ builds
```
