# Session 81: Disabled Overlays Re-enabled + GPU Recovery Dead Code Cleanup

**Date:** 2026-05-24 00:38 CEST
**Scope:** SystemNix + 4 upstream Go repos
**Status:** ✅ All 4 disabled Go overlays fixed and re-enabled; gpu-recovery dead code removed

---

## Executive Summary

All 4 disabled Go package overlays (`buildflow`, `go-structure-linter`, `library-policy`, `projects-management-automation`) have been fixed in their upstream repos and re-enabled in SystemNix. Additionally, the orphaned `gpu-recovery.sh` script was deleted and `display-watchdog.sh` was updated to reboot directly instead of calling the defunct `gpu-recovery.service`.

**Upstream repos require commits + pushes before `just switch` will succeed** — SystemNix's `flake.lock` will need updating via `nix flake lock --update-input <repo>` for each.

---

## A) FULLY DONE

### 1. GPU Recovery Dead Code Cleanup

| Change | File | Detail |
|--------|------|--------|
| ✅ Deleted | `scripts/gpu-recovery.sh` | 119 lines removed — orphaned since session 78 |
| ✅ Updated | `scripts/display-watchdog.sh` | Replaced `gpu-recovery.service` calls with direct `systemctl reboot` (lines 101-104, 113-116) |

The `gpu-recovery.service` systemd unit was already removed from niri-config.nix in session 78. The script and watchdog references were the last remaining dead code.

### 2. buildflow — Re-enabled

- **Root cause:** Stale vendorHash. No actual build error.
- **Fix:** Updated vendorHash to `sha256-G293jWVweZnR15bdPiXbSuhe7ffs72Mi/GEPfEGxcEM=`
- **Upstream changes:** None needed — builds cleanly at current HEAD
- **SystemNix changes:** Uncommmented overlay in `overlays/shared.nix`, re-added to `base.nix` and devShell

### 3. go-structure-linter — Re-enabled

- **Root cause:** `requireDeps` in flake.nix added `go-branded-id v0.1.0` but go.mod already had `v0.3.0`, creating a duplicate conflicting require
- **Fix (upstream):** Removed `go-branded-id v0.1.0` from `requireDeps` (it's already in go.mod at the correct version), updated vendorHash to `sha256-BfHABJAHErFY8slMYjeYPPRzs9LGnVy+HOjBLI50hMk=`
- **SystemNix changes:** Added `go-error-family` follows to go-structure-linter input, uncommented overlay

### 4. library-policy — Re-enabled

- **Root cause:** go.mod had `replace github.com/larsartmann/go-finding => /home/lars/projects/go-finding` (absolute path) and no `mkPreparedSource` usage
- **Fix (upstream):**
  - Copied `mkPreparedSource.nix` from buildflow repo
  - Added `go-finding` as flake input
  - Rewrote `nix/packages/default.nix` to use prepared source with local dep injection
  - Strips the absolute-path replace in `postPatchExtra`
  - Removes broken `.pre-commit-config.yaml` symlink
  - New vendorHash: `sha256-+7F8k2b1JLy6CEgJstZl/vQLpFKB4ICi5p94OQa4feo=`
- **SystemNix changes:** Added `go-finding.follows` to library-policy input, uncommented overlay

### 5. projects-management-automation — Re-enabled

- **Root cause:** `github.com/larsartmann/branching-flow/pkg/stats` imported but not declared in go.mod (resolved only via `go.work` locally). Missing from both flake inputs and `_local_deps`.
- **Fix (upstream):**
  - Added `branching-flow`, `go-error-family`, `go-finding` as flake inputs
  - Added all 3 to `deps` map in `mkPreparedSource`
  - Added `requireDeps = {}` (empty — go.mod already declares them)
  - Added `overrideModAttrs` with `go mod tidy` to resolve transitive deps
  - Added `postPatchExtra` to strip local replace for branching-flow
  - Updated go.mod to properly declare `branching-flow v0.1.0`, `go-error-family v0.1.1`, `samber/mo v1.16.0`
  - New vendorHash: `sha256-wiGmT6ibqaR1afYday12whPQXU1hTwbndA8nPpMCER0=`
- **SystemNix changes:** Added `branching-flow`, `go-error-family`, `go-finding` follows to PMA input, added `go-error-family` as top-level shared input, uncommented overlay

### 6. SystemNix Flake Wiring

| File | Change |
|------|--------|
| `flake.nix` | Added `go-error-family` shared input (line 231-234) |
| `flake.nix` | Added `go-finding.follows` to library-policy input |
| `flake.nix` | Added `go-error-family.follows` to go-structure-linter input |
| `flake.nix` | Added `branching-flow`, `go-error-family`, `go-finding` follows to PMA input |
| `flake.nix` | Re-enabled all 4 packages in devShell |
| `overlays/shared.nix` | Uncommented all 4 overlays, updated vendor hashes |
| `platforms/common/packages/base.nix` | Uncommented all 4 packages |

### 7. Validation

- `just test-fast` — ✅ All checks passed
- Individual repo builds verified:
  - `buildflow` — ✅ `nix build .#default` succeeds
  - `go-structure-linter` — ✅ builds with new vendorHash
  - `library-policy` — ✅ `./result/bin/library-policy --version` works
  - `projects-management-automation` — ✅ `./result/bin/projects-management-automation --version` works

---

## B) PARTIALLY DONE

### Upstream Repo Commits (NOT YET COMMITTED/PUSHED)

| Repo | Modified Files | Status |
|------|---------------|--------|
| `go-structure-linter` | `flake.nix` | ⚠️ Uncommitted — needs commit + push |
| `library-policy` | `flake.nix`, `flake.lock`, `mkPreparedSource.nix`, `nix/packages/default.nix` | ⚠️ Uncommitted — needs commit + push |
| `projects-management-automation` | `flake.nix`, `flake.lock`, `go.mod`, `go.sum` | ⚠️ Uncommitted — needs commit + push |
| `buildflow` | None | ✅ No changes needed |

### SystemNix flake.lock Update

- ⚠️ **NOT YET DONE** — `nix flake lock` needs updating for the 3 changed repos before `just switch` will work
- The `flake.lock` currently has a stale `library-policy` entry (from the `go-finding` follows addition) but needs updates for go-structure-linter and PMA

---

## C) NOT STARTED

| Item | Description |
|------|-------------|
| `just switch` deployment | Cannot proceed until upstream repos are committed + pushed + flake.lock updated |
| Smoke testing all 4 binaries on evo-x2 | Verify the packages work correctly in the NixOS environment |
| `go-structure-linter` devShell | Uses `go_1_26` but should use `go` (standardize) |
| `library-policy` versioning | Needs `ldflags` for version injection like other repos |
| PMA `branching-flow` publish | `pkg/stats` only exists locally — should publish to make `go get` work without `replace` |

---

## D) TOTALLY FUCKED UP / FAILED APPROACHES

### PMA: `go mod tidy` in `postPatchExtra` (mkPreparedSource)

Failed 3 times:
1. **No HOME in sandbox** → `mkdir /homeless-shelter: permission denied`
2. **No DNS in sandbox** → `lookup proxy.golang.org: connection refused`
3. **Go cache dir** → `GOCACHE`/`GOMODCACHE` needed explicit setup

**Lesson:** Never run `go mod tidy` in `mkPreparedSource.postPatchExtra` — the Nix sandbox blocks network and filesystem access. Use `overrideModAttrs` in `buildGoModule` instead, or pre-compute the go.sum offline.

### PMA: `preBuild = "go mod vendor"` in main derivation

Failed with `GOPROXY=off` — can't download modules in the main build derivation.

### PMA: `subModules` for non-Go-submodule directories

Tried `subModules = { "github.com/larsartmann/branching-flow" = [ "pkg/stats" ]; }` which generates `replace` directives pointing to `_local_deps/branching-flow/pkg/stats/go.mod` — but `pkg/stats` has no `go.mod` (it's part of the main module, not a Go submodule).

**Lesson:** `subModules` in `mkPreparedSource` is ONLY for directories with their own `go.mod` files (Go workspace sub-modules). Regular package directories within a module don't need sub-module entries.

### PMA: `GOFLAGS = "-mod=mod"` to bypass vendor consistency

`buildGoModule` in nixpkgs passes `-mod=vendor` explicitly, overriding `GOFLAGS`. The vendor consistency check is enforced by the Go compiler, not by an env var.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Process

1. **`branching-flow/pkg/stats` should be a proper published module** — Currently only resolves via `go.work` locally or `_local_deps` in Nix. Publishing a version with `pkg/stats` would eliminate the `requireDeps` + `overrideModAttrs` hack in PMA.

2. **`mkPreparedSource` should support `go mod tidy` natively** — Add a `tidy = true` option that handles `HOME`/`GOCACHE` setup automatically. Many repos with complex dep graphs need this.

3. **Centralize `mkPreparedSource.nix`** — Currently copy-pasted into each repo. Should be a shared flake input (like `flake-utils` or `treefmt-nix`).

4. **CI for Go repos** — None of the 4 repos have CI that validates the Nix build. A simple `nix build .#default` in GitHub Actions would catch breakage before it reaches SystemNix.

5. **`library-policy` build tags are wrong** — `buildTags = ["goexperiment.goroutineleakprofile" ...]` passes these as `-tags` to Go, but they're experiment flags that should be in `GOEXPERIMENT` env var. Works by accident because Go silently ignores unknown build tags.

6. **Vendor hash management** — No automated way to detect stale vendor hashes. A `nix build` CI check would catch this.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical (blocking deployment)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | Commit + push changes in `go-structure-linter` | 2 min | Blocks flake.lock update |
| 2 | Commit + push changes in `library-policy` | 2 min | Blocks flake.lock update |
| 3 | Commit + push changes in `projects-management-automation` | 2 min | Blocks flake.lock update |
| 4 | `nix flake lock --update-input` for all 3 repos | 2 min | Gets new versions into flake.lock |
| 5 | `just switch` on evo-x2 | 5 min | Deploy everything |

### High Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 6 | Smoke test all 4 binaries: `buildflow --help`, `go-structure-linter --help`, etc. | 5 min | Verify they actually work |
| 7 | Publish `branching-flow` with `pkg/stats` as proper Go module | 15 min | Eliminates PMA `overrideModAttrs` hack |
| 8 | Remove `overrideModAttrs` from PMA after branching-flow publish | 5 min | Clean up the tidy workaround |
| 9 | Add `go-error-family` follows to branching-flow input in SystemNix | 2 min | Completeness — branching-flow depends on it |
| 10 | Centralize `mkPreparedSource.nix` into a shared flake input | 30 min | Stop copy-pasting between repos |

### Medium Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 11 | Fix `library-policy` buildTags → use `env.GOEXPERIMENT` instead | 10 min | Build tags are wrong, works by accident |
| 12 | Add version `ldflags` to `library-policy` production build | 5 min | All other repos have it |
| 13 | Standardize Go version in devShells (`go` vs `go_1_26`) | 10 min | Inconsistent across repos |
| 14 | Add `golangci-lint` + `go-error-family` follows to `go-structure-linter` input | 2 min | Completeness |
| 15 | Audit all Go repos for stale `_local_deps` / vendor hash issues | 30 min | Proactive maintenance |
| 16 | Clean up `docs/status/` — 100+ files, should archive old ones | 15 min | Clutter |
| 17 | Delete `GOFLAGS = "-mod=mod"` from PMA if still there | 1 min | Dead config |

### Lower Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 18 | Add GitHub Actions CI to all Go repos (nix build check) | 1 hr | Catch breakage early |
| 19 | `nix flake check` on all repos | 10 min | Validate all repos |
| 20 | Create `just update-vendor-hash` recipe for Go repos | 15 min | Automate the vendor hash update cycle |
| 21 | Update `AGENTS.md` with new mkPreparedSource patterns | 10 min | Documentation |
| 22 | Review `display-watchdog.sh` for other dead code | 10 min | May have other stale references |
| 23 | Check if `niri-drm-healthcheck.sh` still references gpu-recovery | 5 min | Consistency |
| 24 | Run `just test` (full build) on SystemNix | 20 min | More thorough than test-fast |
| 25 | Archive `docs/status/` files older than 2 weeks | 10 min | Housekeeping |

---

## G) TOP #1 QUESTION

**Should `mkPreparedSource.nix` be extracted into its own shared flake input (e.g., `github.com/LarsArtmann/nix-go-helpers`) instead of being copy-pasted into every Go repo?**

This is currently copy-pasted into: `buildflow`, `go-structure-linter`, `library-policy`, `projects-management-automation` (and likely others). Every time the helper changes, it needs manual syncing across repos. A shared flake input would:
- Eliminate drift between copies
- Allow updating all repos with one `nix flake lock --update-input`
- Enable testing changes once instead of N times

But it adds another level of indirection and a new repo to maintain.

---

## Files Changed (SystemNix)

| File | Action | Lines |
|------|--------|-------|
| `scripts/gpu-recovery.sh` | DELETED | -119 |
| `scripts/display-watchdog.sh` | MODIFIED | -8 +4 |
| `flake.nix` | MODIFIED | +13 -5 |
| `overlays/shared.nix` | MODIFIED | +4 -8 |
| `platforms/common/packages/base.nix` | MODIFIED | +4 -4 |
| `flake.lock` | MODIFIED | library-policy entry updated |

**Total: +17 -140 net**

---

## Files Changed (Upstream — Uncommitted)

### go-structure-linter
| File | Change |
|------|--------|
| `flake.nix` | Removed `go-branded-id v0.1.0` from `requireDeps`, updated vendorHash |

### library-policy
| File | Change |
|------|--------|
| `flake.nix` | Added `go-finding` input, wired to `nix/packages` |
| `mkPreparedSource.nix` | NEW — copied from buildflow |
| `nix/packages/default.nix` | Rewritten to use `mkPreparedSource` with `go-finding` dep |
| `flake.lock` | Updated with go-finding |

### projects-management-automation
| File | Change |
|------|--------|
| `flake.nix` | Added `branching-flow`, `go-error-family`, `go-finding` inputs; added to deps/requireDeps; added `overrideModAttrs`; updated vendorHash |
| `flake.lock` | Updated with new inputs |
| `go.mod` | Added `branching-flow v0.1.0`, `go-error-family v0.1.1`, `samber/mo v1.16.0` |
| `go.sum` | Updated with transitive deps from branching-flow |
