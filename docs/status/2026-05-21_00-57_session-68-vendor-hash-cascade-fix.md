# Session 68 — Flake Update vendorHash Cascade Fix

**Date:** 2026-05-21 00:57
**Trigger:** `nix flake update && nh os boot .` failed with 15 errors
**Status:** ✅ BUILD PASSES — file-and-image-renamer temporarily disabled

---

## Root Cause

`nix flake update` pulled newer versions of Go repos whose `vendorHash` values became stale under the current nixpkgs Go 1.26.2 toolchain. Additionally, `file-and-image-renamer` upstream added `charm.land/fantasy@v0.25.0` which requires Go 1.26.3 — not yet available in nixpkgs-unstable.

---

## a) FULLY DONE

| Item | Detail |
|------|--------|
| **vendorHash cascade fix** | Updated 6 vendorHash overrides in `overlays/shared.nix` and `overlays/linux.nix` |
| **Upstream vendorHash pushes** | Fixed vendorHash in: dnsblockd, mr-sync, go-structure-linter, buildflow, projects-management-automation |
| **file-and-image-renamer go.mod** | Pushed fix to lower `go 1.26.3` → `go 1.26` in upstream, then reverted when we realized the dependency (`charm.land/fantasy`) itself requires 1.26.3 |
| **file-and-image-renamer disabled** | Set `enable = false` in `configuration.nix` with clear comment explaining why |
| **flake.lock updated** | 16 input updates (branching-flow, buildflow, cmdguard, dnsblockd, emeet-pixyd, file-and-image-renamer, go-auto-upgrade, go-branded-id, go-output, go-structure-linter, golangci-lint-auto-configure, hierarchical-errors, mr-sync, nix-ssh-config, projects-management-automation, system-path) |
| **NixOS build passes** | `nh os boot .` succeeds cleanly, no warnings |
| **hostPlatform warning** | Gone — was from older nixpkgs, no action needed |

## b) PARTIALLY DONE

| Item | Status | Remaining |
|------|--------|-----------|
| **Upstream vendorHash accuracy** | Pushed hashes to 5 repos, but 2 (buildflow, PMA) had wrong hashes because standalone builds produce different hashes than SystemNix's nixpkgs instance. Corrected on second push. | Upstream repos have correct hashes now but `hierarchical-errors` upstream has a stale hash that SystemNix overrides correctly |

## c) NOT STARTED

| Item | Priority | Notes |
|------|----------|-------|
| **Re-enable file-and-image-renamer** | HIGH — blocked | Requires nixpkgs-unstable to include Go ≥ 1.26.3 (already in nixpkgs master, pending channel merge) |
| **Remove vendorHash overrides from SystemNix** | MEDIUM | The `overrideAttrs` vendorHash pattern works but creates dual-maintenance (hash in both upstream repo and SystemNix overlay). Ideally upstream repos are the single source of truth |
| **Darwin build verification** | LOW | Only tested NixOS (evo-x2). Darwin (Lars-MacBook-Air) not tested |

## d) TOTALLY FUCKED UP (Mistakes Made)

| Mistake | Impact | Lesson |
|---------|--------|--------|
| **Tried goOverlay (Go 1.26.3 bump via overlay)** | Caused infinite recursion during full NixOS build | Overriding `go_1_26` in an overlay triggers re-evaluation of all Go-dependent packages, causing cyclic dependency resolution. Do NOT override the Go compiler in overlays |
| **Tried buildGoModule from-source for file-and-image-renamer** | Also caused infinite recursion (via perSystem pkgs) | Building Go packages from source within overlays that are also used by `perSystem` creates evaluation cycles |
| **Wasted time on wrong approach** | Spent ~30 min iterating vendorHash="" discovery builds before realizing `overrideAttrs` DOES propagate vendorHash to go-modules | The AGENTS.md "Common Build Failures" table already documents the vendorHash mismatch pattern. Should have followed it directly |
| **Pushed wrong vendorHash to buildflow & PMA** | Two upstream repos got wrong hashes (built standalone vs in SystemNix context) | Vendor hashes are nixpkgs-context-dependent. Always compute them in the actual SystemNix build, not standalone |
| **Committed file-and-image-renamer go.mod changes unnecessarily** | Pushed `go 1.26.3 → go 1.26` then reverted to `go 1.26.3` | Should have checked the transitive dependency (`charm.land/fantasy`) first before touching go.mod |

## e) WHAT WE SHOULD IMPROVE

1. **Single-source vendorHash** — The dual-maintenance of vendorHash (upstream repo + SystemNix overlay override) is fragile. Either:
   - Remove all vendorHash overrides from SystemNix and rely entirely on upstream repos (requires all repos to be kept in sync)
   - Or accept the current pattern but document it clearly
2. **Go version pinning strategy** — When upstream deps require a newer Go than nixpkgs-unstable provides, we have no clean workaround. Consider pinning nixpkgs to a specific commit rather than the rolling channel
3. **Automated vendorHash discovery** — The `justfile` has a `vendor-hash-update` recipe but it only works for one package at a time. Should have a bulk update command
4. **Build before push** — Should always run `just test-fast` or `nh os boot .` before committing flake.lock updates

## f) Top 25 Things to Get Done Next

| # | Task | Impact | Effort | Status |
|---|------|--------|--------|--------|
| 1 | Re-enable file-and-image-renamer when nixpkgs-unstable gets Go 1.26.3 | HIGH | 1 min | Blocked |
| 2 | Monitor nixpkgs-unstable channel for Go 1.26.3 inclusion | HIGH | 0 | Waiting |
| 3 | Remove vendorHash overrides from SystemNix overlays (make upstream single source of truth) | HIGH | 30 min | Not started |
| 4 | Fix hierarchical-errors upstream vendorHash (currently stale, SystemNix overrides it) | MEDIUM | 5 min | Not started |
| 5 | Verify Darwin build passes with these changes | MEDIUM | 10 min | Not started |
| 6 | Add `just bulk-vendor-hash-update` recipe for mass vendorHash fixes | MEDIUM | 20 min | Not started |
| 7 | Consider pinning nixpkgs to a specific commit instead of rolling channel | MEDIUM | 15 min | Not started |
| 8 | Update AGENTS.md with lesson: overrideAttrs vendorHash DOES propagate to go-modules | MEDIUM | 5 min | Not started |
| 9 | Update AGENTS.md with lesson: goOverlay (overriding go_1_26 in overlay) causes infinite recursion | MEDIUM | 5 min | Not started |
| 10 | Audit all Go repos for go.mod Go version requirements vs nixpkgs Go version | MEDIUM | 15 min | Not started |
| 11 | Add CI check that `nix flake update` still builds | MEDIUM | 30 min | Not started |
| 12 | Fix emeet-pixyd templ version warning (generator older than go.mod) | LOW | 5 min | Not started |
| 13 | Clean up file-and-image-renamer upstream git history (wip commit, revert commit) | LOW | 5 min | Not started |
| 14 | Remove the dead `goOverlay` definition from overlays/default.nix (was added then abandoned) | LOW | 1 min | DONE (already reverted) |
| 15 | Consider `follows` pattern for Go toolchain across all private repos | LOW | 20 min | Not started |
| 16 | Test rpi3-dns configuration still builds | LOW | 10 min | Not started |
| 17 | Review SigNoz build time after nixpkgs update (Go 1.25 → 1.26) | LOW | 5 min | Not started |
| 18 | Check if any other services broke from the nixpkgs-unstable update | MEDIUM | 15 min | Not started |
| 19 | Update AGENTS.md "Common Build Failures" table with Go version mismatch pattern | LOW | 5 min | Not started |
| 20 | Create GitHub issue on file-and-image-renamer tracking Go 1.26.3 blocker | LOW | 3 min | Not started |
| 21 | Review nixpkgs-unstable channel progression (how often does Go get updated?) | LOW | 5 min | Not started |
| 22 | Check if `nix flake update` deprecation warnings need addressing (`--update-input`) | LOW | 5 min | Not started |
| 23 | Investigate if `nix flake update` (without `--update-input`) works better | LOW | 2 min | Not started |
| 24 | Consider adding `nixpkgs` input test: `nix eval '.#nixosConfigurations.evo-x2.pkgs.go.version'` | LOW | 5 min | Not started |
| 25 | Review if any new nixpkgs-unstable packages need `allowBroken = true` toggling | LOW | 5 min | Not started |

## g) Top #1 Question I Cannot Figure Out Myself

**Why do vendorHash values differ when building a Go repo standalone vs building within SystemNix's nixpkgs instance?**

Both use `nixpkgs.follows = "nixpkgs"` so they should use the same nixpkgs — yet buildflow's vendorHash was `sha256-FrEm...` when built standalone but `sha256-Lk0T...` when built in SystemNix. This suggests something in SystemNix's overlays (NUR, shared overlays, or the overlay order) affects the Go module vendor hash computation. This needs investigation to avoid the "push wrong hash to upstream, then fix it" cycle.

---

## Files Changed

| File | Change |
|------|--------|
| `flake.lock` | 16 input updates (Go repos + transitive deps) |
| `overlays/shared.nix` | Updated vendorHash for mr-sync, buildflow, go-structure-linter, projects-management-automation |
| `overlays/linux.nix` | Added vendorHash override for dnsblockd |
| `platforms/nixos/system/configuration.nix` | Disabled file-and-image-renamer (Go 1.26.3 blocker) |

## vendorHash Override Summary

| Package | Old Hash | New Hash | Changed? |
|---------|----------|----------|----------|
| dnsblockd | (none) | `sha256-Vd9wjU...` | YES — added |
| hierarchical-errors | `sha256-imjTsc...` | `sha256-imjTsc...` | NO — unchanged |
| mr-sync | `sha256-ewYNWI...` | `sha256-AXdOv7...` | YES |
| buildflow | `sha256-W63V4g...` | `sha256-Lk0TCW...` | YES |
| go-structure-linter | `sha256-rG/Riw...` | `sha256-yUsGT...` | YES |
| projects-management-automation | `sha256-lv0xp2...` | `sha256-SHqeKn...` | YES |
| file-and-image-renamer | `sha256-FdABe/...` | (unchanged) | Service disabled |
