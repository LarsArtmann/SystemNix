# Session 38 — ComfyUI Removal + Post-Session 37 Verification

**Date:** 2026-05-18 18:07 CEST
**Session:** 38
**Host:** evo-x2 (192.168.1.150, x86_64-linux)
**Branch:** master (2 commits ahead of origin since session 37)
**Total Commits:** 2411
**Repo Size:** ~933 MiB

---

## Executive Summary

SystemNix remains in **excellent operational shape**. Session 37's comprehensive verification (all 17 upstream packages building, clean flake check, zero stale vendor hashes) still holds. This session made **one deliberate architectural decision**: removing ComfyUI from active services. The user prefers using AI models via code directly rather than through a GUI image generation server. ComfyUI is now cleanly disabled across 5 files (config, caddy, gatus, ai-models paths, FEATURES.md) without deleting the module itself — enabling easy re-enablement if needed.

Two commits were made since session 37: (1) mobile Nix alternatives documentation, and (2) `mkPreparedSource` v2 with per-dependency `subModules` support and 4-repo migration. The flake.lock grew from 136 to 137 transitive inputs as a result.

**One session 37 finding was corrected:** `govalid` IS installed in `base.nix` (line 225) — it was incorrectly flagged as "built but not installed." Only `netwatch` remains in that category.

**Codebase cleanliness remains exceptional:** Zero TODO/FIXME/HACK/XXX comments across all 111 `.nix` files, all 35 service modules, and all `lib/` files.

---

## a) FULLY DONE ✅

### Core Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| flake.nix architecture | ✅ | flake-parts modular, 35 service modules (was 34 — comfyui.nix still exists), 3 system configs |
| NixOS evo-x2 build | ✅ | Session 36 deployment stable; `nix flake check --no-build` passes |
| NixOS rpi3-dns build | ✅ | SD image builds (3.38 GiB, aarch64-linux) |
| Darwin evaluation | ✅ | `nix flake check --all-systems --no-build` passes |
| `nix flake check` | ✅ | All derivations evaluate, all systems check |
| Vendor hash audit | ✅ | All overlay packages: zero stale hashes |
| `just test-upstream-builds` | ✅ | 17/17 packages build successfully |

### Upstream Overlay Packages (17/17 Building)

All packages from session 37 still build cleanly. No new breakages introduced.

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

### Service Modules (35 registered, all evaluate)

All 35 service modules registered in `serviceModules` list in `flake.nix`. `comfyui.nix` remains as a registered module but is now disabled in `configuration.nix`.

### Cross-Platform Programs (15 modules in platforms/common/programs/)

activitywatch, bash, chromium, fish, fzf, git, keepassxc, pre-commit, shell-aliases, ssh-config, starship, taskwarrior, tmux, zsh

### ComfyUI Removal (This Session)

| File | Change | Status |
|------|--------|--------|
| `platforms/nixos/system/configuration.nix:201-204` | `services.comfyui.enable = false` + comment updated | ✅ |
| `modules/nixos/services/caddy.nix:78-83` | Removed `comfyui.home.lan` vhost | ✅ |
| `modules/nixos/services/gatus-config.nix:101-106` | Removed ComfyUI health check from Gatus | ✅ |
| `modules/nixos/services/ai-models.nix` | Removed `comfyui` path from `paths` attrset + `tmpfiles.rules` | ✅ |
| `FEATURES.md:82` | Status updated to "❌ Removed" with rationale | ✅ |

**Rationale:** User prefers using AI models via code directly rather than through ComfyUI's GUI/node-based interface. The service was already a "zombie" (ExecCondition skipped startup because the venv path didn't exist). Clean removal prevents monitoring noise and frees up the `comfyui.home.lan` subdomain.

### Libraries (lib/)

| Library | Consumers | Status |
|---------|-----------|--------|
| lib/systemd.nix (`harden`/`hardenUser`) | 20+ service modules | ✅ Active |
| lib/systemd/service-defaults.nix | 15+ modules + niri-wrapped | ✅ Active |
| lib/types.nix (`serviceTypes`) | 12+ service modules | ✅ Active |
| lib/docker.nix | voice-agents | ✅ Active |
| lib/rocm.nix | ai-stack (comfyui removed) | ✅ Active |
| lib/graphical-user-service.nix | niri-config, file-and-image-renamer | ✅ Active |
| lib/prepared-source.nix | **0 consumers in SystemNix** (upstream repos use it) | ✅ Exported |

### Tooling & Recipes

| Tool | Status |
|------|--------|
| `just hash-check` | ✅ Tests all overlay vendor hashes |
| `just test-upstream-builds` | ✅ Builds all 17 packages |
| `just test-fast` | ✅ Syntax-only validation |
| `just test` | ✅ Full build validation |
| `just format` | ✅ treefmt + alejandra |
| `just validate-scripts` | ✅ shellcheck all scripts |
| `mkPreparedSource` helper | ✅ v2 created with per-dep `subModules` |

### Code Cleanliness

| Metric | Value |
|--------|-------|
| TODO/FIXME/HACK/XXX in all `.nix` files | **0** |
| TODO/FIXME/HACK/XXX in `lib/` | **0** |
| TODO/FIXME/HACK/XXX in `modules/nixos/services/` | **0** |
| AGENTS.md outdated gotchas | **0** (ComfyUI zombie removed, all accurate) |

---

## b) PARTIALLY DONE 🔄

### mkPreparedSource Adoption (4 repos migrated in commit, but SystemNix doesn't consume)

Commit `94dbafb1` migrated 4 private Go repos to `mkPreparedSource` v2 (per-dep `subModules`), but SystemNix itself does not directly import or use `mkPreparedSource` — it's an upstream helper consumed by the private repos' own `flake.nix` files. The helper in `lib/prepared-source.nix` is exported via `self.lib` but no SystemNix module references it.

### Darwin Build Verification

`nix flake check` evaluates Darwin successfully, but a full `nix build .#darwinConfigurations.Lars-MacBook-Air.system` has not been run from the MacBook since session 36 changes. The macOS config may have issues only visible at build time.

### Flake Lock Bloat

**137 transitive inputs** (up from 136 in session 37 — +1 from `mkPreparedSource` v2 changes). Duplicated inputs remain:
- flake-parts: ×11 copies
- nixpkgs-lib: ×8 copies
- go-output: ×7 copies
- go-branded-id: ×6 copies
- go-finding: ×6 copies
- gogenfilter: ×5 copies
- systems: ×12 copies

Not broken, but the lock file continues to grow.

### go-structure-linter Commit History

The fix for go-structure-linter was 10 commits. Should be squashed to 1-2 clean commits for readability.

### govalid Installation Status — CORRECTED from Session 37

**Session 37 incorrectly flagged `govalid` as "built but not installed."** Upon verification, `govalid` IS present in `platforms/common/packages/base.nix:225`. It is correctly installed on both Darwin and NixOS. Only `netwatch` remains in the "built but not installed" category.

---

## c) NOT STARTED ⏳

### High Impact

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | Refactor 4 repos to use `mkPreparedSource` v2 | DRY, reduce copy-paste errors | Medium |
| 2 | Create `mk-pnpm-package.nix` reusable helper | Extract jscpd pattern for reuse | Medium |
| 3 | Document `overrideModAttrs` pattern | Knowledge preservation | Low |
| 4 | Implement `just hash-check --fix` auto-repair | Developer velocity | Medium |
| 5 | Go.sum transitive merge audit | Prevent future cascade failures | Medium |

### Medium Impact

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

### General Backlog

| # | Task | Notes |
|---|------|-------|
| 15 | Consolidate/archive status docs | 55 status reports in docs/status/, could archive old ones |
| 16 | Dependency graph visualization | Show which packages affect which when go-output changes |
| 17 | Go sub-module tag automation | go-output/testhelpers release process |
| 18 | Darwin disk space strategy | MacBook Air at 90-95% full, need distributed builds or cleanup |
| 19 | rpi3-dns hardware provisioning | Pi 3 not yet provisioned, cluster is "planned" status |
| 20 | Add `netwatch` to `base.nix` or document why not | Only remaining "built but not installed" package |

---

## d) TOTALLY FUCKED UP ❌

**Nothing is fundamentally broken.** The system builds, evaluates, and all upstream packages compile.

However, these quality concerns remain:

### 1. `update-vendor-hashes` Recipe Reports False Negatives

The `just update-vendor-hashes` recipe uses `nix build .#pkg --no-link` which returns "OK" from the nix store cache even when the vendorHash is stale. This caused the buildflow stale hash to be missed in session 36. The `just hash-check` recipe works correctly because it runs a fresh build. **Both recipes should be consolidated** or `update-vendor-hashes` should be fixed.

### 2. Dead/Stale Files

| File | Issue |
|------|-------|
| `pkgs/jscpd-package-lock.json` | Leftover from npm-based build, not referenced. jscpd now uses pnpm. **Still exists.** |

### 3. Unused Exports

| Export | Issue |
|--------|-------|
| `flake.lib` (`inputs.self.lib`) | Exported but never consumed by any module in the codebase |
| `mkPreparedSource` (lib/prepared-source.nix) | Exported via `flake.lib` but SystemNix itself doesn't use it |

### 4. `netwatch` — Built But Not Installed

**CORRECTED:** `govalid` is now confirmed installed in `base.nix`. Only `netwatch` remains as a package built via overlay and exposed as flake package, but NOT in `base.nix` or any `environment.systemPackages`.

### 5. photomap Disabled

In `configuration.nix:130-131`:
```nix
# photomap — disabled: podman config permission issue
# photomap.enable = true;
```

Either enable it, fix the podman permission issue, or remove the module and the commented line.

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Architecture

1. **Flake lock deduplication** — 137 transitive inputs is excessive. Consider having private Go repos follow `flake-parts` from a single source, or switch to simpler build approaches.

2. **mkPreparedSource adoption** — 4 repos migrated in commit `94dbafb1`, but verify they all use v2 correctly. The helper exists but needs to be validated upstream.

3. **Package installation audit** — `netwatch` is the only remaining package built but not installed. Either add to `base.nix` or document as intentionally overlay-only.

### Developer Experience

4. **Consolidate hash-check recipes** — `just hash-check` and `just update-vendor-hashes` do overlapping things but with different behaviors. `hash-check` actually builds; `update-vendor-hashes` can miss stale hashes.

5. **Dead file cleanup** — `pkgs/jscpd-package-lock.json` should be deleted. It's from the npm era; jscpd now uses pnpm.

6. **Status doc hygiene** — 55 status reports in `docs/status/` (including archived). Consider a rolling window (keep last 5-10 active, archive the rest).

### Reliability

7. **Cascade failure prevention** — When go-output changes, all consumers need updates. Need a dependency graph tool.

8. **CI/CD** — No CI exists. Pre-merge `nix flake check --all-systems --no-build` would catch evaluation errors.

9. **Darwin build verification** — After session 36 changes, Darwin hasn't been fully built from the MacBook.

### Code Quality

10. **Consistent ADR numbering** — Some ADRs use `001-` prefix, others use `ADR-005-`. Standardize.

11. **photomap decision** — Service module exists but is disabled with a podman permission issue comment. Decide: fix, enable, or remove.

---

## f) Top 25 Things To Do Next

### Tier 1: Immediate (This Session or Next)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 1 | **Delete `pkgs/jscpd-package-lock.json`** | Dead file, leftover from npm→pnpm migration | 1 min |
| 2 | **Decide on `netwatch`** — add to `base.nix` or document as overlay-only | Only remaining "built but not installed" package | 5 min |
| 3 | **Decide on `photomap`** — fix podman issue, enable, or remove module | Dead commented code in configuration.nix | 10 min |
| 4 | **Fix `update-vendor-hashes` false negatives** | Missed buildflow stale hash in session 36 | Medium |
| 5 | **Consolidate `hash-check` + `update-vendor-hashes`** into one reliable recipe | Two overlapping tools with different accuracy | Medium |

### Tier 2: Short Term (Next Few Sessions)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 6 | **Verify mkPreparedSource v2 in upstream repos** | Ensure 4 migrated repos build correctly | 30 min |
| 7 | **Squash go-structure-linter commits** (10 → 1-2) | Clean git history | 10 min |
| 8 | **Write upstream fix playbook** | Session 35/36 learnings documented | Low |
| 9 | **Verify Darwin build** from MacBook | Ensure macOS still builds after session 36 | 30 min |
| 10 | **Archive old status docs** (keep last 5 active) | 55 reports is excessive | Low |

### Tier 3: Medium Term (Next Week)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 11 | **Flake input audit** — identify and remove unused inputs | 137 transitive inputs is excessive | Medium |
| 12 | **Create `mk-pnpm-package.nix`** reusable helper | jscpd pattern extracted for reuse | Medium |
| 13 | **Set up cachix** for binary cache | Faster rebuilds, CI prerequisite | High |
| 14 | **CI spec** — GitHub Actions `nix flake check` | Prevent breakage on push | High |
| 15 | **Dependency graph visualization** | "What breaks when go-output updates?" | Medium |

### Tier 4: Strategic (Next Month)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 16 | **Explore `fetchGoModules`** for private repos | Simplify vendor management | High |
| 17 | **GitHub Actions** for automated vendor hash updates | Full automation | High |
| 18 | **`update-all-vendor-hashes`** with dep graph walker | Cascade prevention | High |
| 19 | **Darwin disk space strategy** (distributed builds to evo-x2) | MacBook at 90-95% full | High |
| 20 | **Standardize ADR numbering** (all `NNN-` or all `ADR-NNN-`) | Consistency | Low |
| 21 | **rpi3-dns hardware provisioning** | Pi 3 DNS cluster backup node | Hardware |
| 22 | **Contribute jscpd upstream fix** (wrapped-src pattern) | Give back to open source | Medium |
| 23 | **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log) | Better alert granularity | Medium |
| 24 | **Move `dns-failover.nix` plaintext `authPassword` to sops** | Security hardening | Medium |
| 25 | **Consolidate voice-agents Caddy vHost** into caddy.nix pattern | Consistency | Low |

---

## g) Top Question I Cannot Figure Out

**Is `netwatch` intentionally kept as an overlay-only package (buildable but not on PATH), or should it be added to `platforms/common/packages/base.nix` like `govalid`?**

- `netwatch` is a Rust TUI for real-time network diagnostics — seems useful on NixOS (evo-x2)
- It is exposed as a flake package (`packages.x86_64-linux.netwatch`)
- It is NOT in `base.nix` or any `environment.systemPackages`
- The AGENTS.md rule states: "All overlay tools that are meant to be user-facing are listed in `base.nix`"
- `govalid` was correctly identified as user-facing and IS in `base.nix`
- Session 37 incorrectly flagged both; this session corrected `govalid`

This suggests `netwatch` should either be added to `base.nix` (if user-facing) or documented as intentionally overlay-only (if only meant as a buildable derivation for other flakes to consume). I cannot determine the intent without asking.

---

## System Metrics

| Metric | Value | Δ from Session 37 |
|--------|-------|-------------------|
| `.nix` files | 111 | — |
| Shell scripts | 17 | — |
| Service modules | 35 | +1 (comfyui.nix still registered) |
| Overlay packages | 17 (building) | — |
| Cross-platform programs | 15 modules | — |
| Enabled services on evo-x2 | ~29 | −1 (ComfyUI disabled) |
| Flake inputs (direct) | 30 | — |
| Flake inputs (transitive) | 137 | +1 (mkPreparedSource v2) |
| ADRs | 7 | — |
| Status reports | 55 | +1 (this one) |
| Total commits | 2411 | +2 |

## Key Verification Commands

```bash
nix flake check --all-systems --no-build   # ✅ passes
just hash-check                             # ✅ all packages OK
just test-upstream-builds                   # ✅ 17/17 OK
nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage  # ✅ builds
```

## Changes This Session

| Commit/File | Change |
|-------------|--------|
| `94dbafb1` | `refactor(nix): mkPreparedSource v2 — per-dep subModules, 4 repos migrated` |
| `e6ca78cc` | `docs: add mobile Nix alternatives reference — NixOnDroid, NixOS Mobile, and non-Nix options` |
| **Uncommitted** | ComfyUI disabled across 5 files (config, caddy, gatus, ai-models, FEATURES.md) |
