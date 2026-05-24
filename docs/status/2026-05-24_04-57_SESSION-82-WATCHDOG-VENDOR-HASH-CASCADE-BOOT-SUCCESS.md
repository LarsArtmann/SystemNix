Session 82: Watchdog Auto-Reboot Removed + Vendor Hash Cascade Fix + Successful Boot

Date: 2026-05-24 04:57 CEST
Scope: SystemNix + 7 upstream Go repos
Status: ✅ `nh os boot` succeeded — configuration added to bootloader

---

## Executive Summary

Session 82 started with a simple request to remove auto-reboot from `display-watchdog.sh`. It escalated into a cascading vendor hash fix across 7 Go repos when `nh os boot` failed with stale vendor hashes in buildflow, mr-sync, go-structure-linter, branching-flow, and golangci-lint-auto-configure. A root cause was discovered in go-filewatcher (module path `/v2` vs `v0.x.x` tags) which blocked PMA from building.

**Final result:** All 10 Go packages build, `nh os boot` succeeded, configuration is in bootloader awaiting reboot.

---

## A) FULLY DONE

### 1. Display Watchdog — Auto-Reboot Removed

| Change | File | Detail |
|--------|------|--------|
| ✅ Removed | `scripts/display-watchdog.sh` | Both `systemctl reboot` calls removed (lines 101-104, 112-115) |
| ✅ Updated | `scripts/display-watchdog.sh` | Messages changed to `CRITICAL: ... Manual intervention required.` |
| ✅ Fixed | `scripts/display-watchdog.sh` | Comment updated: "trigger GPU recovery" → "log critical alert" |

### 2. go-filewatcher Module Path Fix (Root Cause)

| Change | Repo | Detail |
|--------|------|--------|
| ✅ Fixed | `go-filewatcher` | Removed `/v2` from module path — module declared `/v2` but published `v0.x.x` tags |
| ✅ Updated | `go-filewatcher` | All 7 Go files updated: `go-filewatcher/v2` → `go-filewatcher` |
| ✅ Pushed | `go-filewatcher@f086f14` | `fix: remove /v2 from module path — align with v0.x.x tags` |

**Impact:** This was blocking PMA from building in the Nix sandbox. Go's semver enforcement rejects `/v2` modules with `v0.x.x` versions.

### 3. Vendor Hash Cascade — All Fixed

| Repo | Old Hash | New Hash | Status |
|------|----------|----------|--------|
| buildflow | `sha256-G293jWV...` | `sha256-Jsi00lEl...` | ✅ Pushed to overlay |
| mr-sync | `sha256-K/dPpkbg...` | `sha256-T2IVldw0...` | ✅ Pushed to overlay |
| go-structure-linter | `sha256-BfHABJAH...` | `sha256-nfbz9ZOv...` | ✅ Pushed to overlay |
| hierarchical-errors | `sha256-Q9i+2iW0...` | unchanged | ✅ Was already correct |
| branching-flow | `sha256-VAAOnRaE...` | `sha256-ORJwNCRS...` | ✅ Fixed upstream + pushed |
| golangci-lint-auto-configure | `sha256-PXItwurN...` | `sha256-VeOlYERM...` | ✅ Fixed upstream + pushed |
| projects-management-automation | (override removed) | N/A | ✅ Repo's own hash now correct |
| library-policy | N/A | N/A | ✅ No vendor hash needed |
| art-dupl | N/A | N/A | ✅ No vendor hash needed |
| go-auto-upgrade | N/A | N/A | ✅ No vendor hash needed |

### 4. Dead Code Cleanup

| Change | File | Detail |
|--------|------|--------|
| ✅ Removed | PMA `flake.nix` | `GOFLAGS = "-mod=mod"` — dead config, ignored by buildGoModule |
| ✅ Removed | branching-flow `flake.nix` | Same dead GOFLAGS in `overrideModAttrs` |
| ✅ Audited | `scripts/niri-drm-healthcheck.sh` | Zero gpu-recovery references — clean |

### 5. Go Version Standardization

| Repo | Change |
|------|--------|
| go-structure-linter | `go_1_26` → `go` in devShell |
| branching-flow | `go_1_26` → `go` in devShell + buildGoModule override + mkPreparedSource |

**Rationale:** `pkgs.go` in nixpkgs-unstable is already 1.26.2. Using `go` tracks nixpkgs automatically.

### 6. library-policy buildTags Fix (Confirmed from prior session)

| Change | Detail |
|--------|--------|
| ✅ Committed in `library-policy@8b6d8d5` | `buildTags = ["goexperiment.goroutineleakprofile" ...]` → `buildTags = []` + `env.GOEXPERIMENT = "goroutineleakprofile,jsonv2,simd"` |

### 7. SystemNix Flake Lock Updates

| Input | Old Rev | New Rev |
|-------|---------|---------|
| branching-flow | `24ecb98` | `48c2b88` |
| golangci-lint-auto-configure | `89f8a53` | `1f69efc` |
| projects-management-automation | `1d03ed8` | `63dcf91` |

### 8. Validation

- `just test-fast` — ✅ All checks passed (0 non-existent input warnings!)
- `nix build .#<all 10 Go packages>` — ✅ All build
- `nh os boot .` — ✅ Configuration added to bootloader

### 9. Boot Diff Highlights

```
UPDATED: yazi 26.1.22 → 26.5.6, zed-editor 1.2.6 → 1.3.5
ADDED:   Swap-Usage-Critical alert rule, etc-environment.d/50-systemd-path.conf, libaec 1.1.6
REMOVED: gpu-recovery, unit-gpu-recovery.service (dead code)
SIZE:    40.6 GiB → 40.7 GiB (+54.7 MiB)
```

---

## B) PARTIALLY DONE

### Upstream Uncommitted Changes

| Repo | Files | Status | Risk |
|------|-------|--------|------|
| buildflow | `flake.nix` (vendorHash), `TODO_LIST.md` | ⚠️ Uncommitted | Low — vendorHash matches current SystemNix overlay |
| go-filewatcher | `flake.lock` (nixpkgs drift) | ⚠️ Uncommitted | Low — cosmetic |
| go-structure-linter | `internal/rules/.gitignore` | ⚠️ Uncommitted | Low — unrelated |
| library-policy | 5 test files | ⚠️ Staged but uncommitted | Low — test refactoring |

### SystemNix Unpushed

4 commits ahead of origin/master:

```
e7b591c5 fix(watchdog): remove auto-reboot — user controls reboots + session 82 cleanup
5f21660f fix(buildflow): update stale vendorHash for current flake.lock revision
e5ed623f fix(overlays): update all stale vendor hashes + fix go-filewatcher /v2 mismatch
a65bbdc2 chore(flake.lock): update branching-flow to fix vendor hash
150ed288 chore(flake.lock): update golangci-lint-auto-configure for vendor hash fix
```

---

## C) NOT STARTED

| # | Item | Description |
|---|------|-------------|
| 1 | Reboot to activate | Configuration is in bootloader, needs reboot |
| 2 | Smoke test all 10 Go binaries on evo-x2 | Verify they work in the NixOS env |
| 3 | Push SystemNix to origin | 4 commits unpushed |
| 4 | Commit buildflow's vendorHash update | Matches overlay but repo's own hash is stale |
| 5 | Publish `branching-flow/pkg/stats` as proper Go module | Eliminates PMA `overrideModAttrs` hack |
| 6 | Centralize `mkPreparedSource.nix` into shared flake input | Copy-pasted into 5+ repos |
| 7 | Add `go-error-family` follows to branching-flow input | branching-flow depends on it |
| 8 | Fix `boot.zfs.forceImportRoot` warning in rpi3-dns | Silences eval warning |
| 9 | Add version ldflags to library-policy production build | Other repos have it |
| 10 | Archive old `docs/status/` files | 113+ files |
| 11 | Audit all scripts for `systemctl reboot` calls | User rejected auto-reboot pattern |

---

## D) TOTALLY FUCKED UP / FAILED APPROACHES

### 1. "Stale vendor hashes only affect buildflow"

**Wrong.** The flake.lock update (`de3183dd`) pulled new revisions for ALL inputs simultaneously. This cascaded into 5 different packages having stale vendor hashes: buildflow, mr-sync, go-structure-linter, branching-flow, and golangci-lint-auto-configure. Each failure was discovered only after fixing the previous one.

**Lesson:** After a `flake.lock` bulk update, rebuild ALL Go packages before attempting `nh os boot`. The `just test-fast` (syntax-only check) does NOT catch vendor hash mismatches.

### 2. "mkPackageOverlay vendorHash override is always needed"

**Wrong for packages with correct upstream hashes.** PMA's overlay had a vendorHash override that was actually making things WORSE — overriding the correct hash from PMA's own flake with a stale one. Removed the override entirely; PMA builds fine with its own hash.

**Lesson:** Only add `vendorHash` overrides in the SystemNix overlay when the upstream repo's hash is demonstrably wrong. Default to `{}` (no override).

### 3. go-filewatcher /v2 module path (2 hours of debugging)

The error `module github.com/larsartmann/go-filewatcher/v2: version "v0.3.0" invalid: should be v2, not v0` was the final manifestation. The root cause chain:

1. go-filewatcher's `go.mod` declared `module github.com/larsartmann/go-filewatcher/v2`
2. But published `v0.x.x` tags (not `v2.x.x`)
3. PMA's `go.mod` required `v0.3.0` (without `/v2`)
4. Locally worked because `go.work` resolved everything
5. Nix sandbox (`GOWORK=off`) hit the mismatch

Tried: updating dep key to `/v2`, updating PMA go.mod to `/v2`, sed postPatch — all failed because Go enforces semver strictly. Final fix: remove `/v2` from go-filewatcher's module path entirely.

**Lesson:** Go module paths with `/v2+` suffix MUST have matching `v2+` version tags. If you publish `v0.x.x` tags, don't use `/v2` in the module path.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Process

1. **Post-flake-lock-update validation is missing** — After `nix flake lock --update-input` (especially bulk updates), there's no automated check that all Go packages still build. Need a `just verify-packages` recipe that builds all Go overlays.

2. **Vendor hash drift detection** — No automated way to detect stale vendor hashes. The `just test-fast` only checks syntax. A CI job or pre-commit hook that runs `nix build .#<package>` for each Go overlay would catch this.

3. **mkPackageOverlay should default to no vendorHash override** — The overlay pattern `mkPackageOverlay X "X" {vendorHash = "..."}` creates a second source of truth for the hash. If the upstream repo already has the correct hash, the override is harmful. Only override when the upstream is broken.

4. **`mkPreparedSource.nix` duplication** — Still copy-pasted into 5+ repos. Still should be a shared flake input.

5. **go-filewatcher versioning was wrong for months** — The `/v2` module path with `v0.x.x` tags means every consumer was silently broken in Nix but worked locally via `go.work`. CI would have caught this immediately.

6. **GOFLAGS = "-mod=mod" cargo-cult** — Appeared in PMA and branching-flow. Does nothing in buildGoModule. Should be audited across all repos.

7. **No auto-reboot in ANY script** — User explicitly rejected this pattern. Need to audit all remaining scripts for `systemctl reboot` calls (display-watchdog was the main offender, but others may exist).

---

## F) TOP 25 THINGS TO DO NEXT

### Critical (activation)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | Reboot evo-x2 to activate new configuration | 2 min | Everything is in bootloader |
| 2 | Smoke test all 10 Go binaries after reboot | 5 min | Verify they work |
| 3 | Push SystemNix to origin | 1 min | 4 commits unpushed |

### High Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 4 | Commit buildflow vendorHash update + push | 2 min | Repo's own hash is stale |
| 5 | Audit ALL scripts for `systemctl reboot` | 5 min | User rejected auto-reboot pattern |
| 6 | Add `just verify-packages` recipe | 10 min | Catch stale vendor hashes after flake.lock updates |
| 7 | Fix `boot.zfs.forceImportRoot` warning | 2 min | Silences eval warning |
| 8 | Commit go-structure-linter changes + push | 2 min | go_1_26 → go standardization |
| 9 | Push library-policy test changes | 2 min | Uncommitted test refactoring |

### Medium Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 10 | Centralize `mkPreparedSource.nix` into shared flake input | 30 min | Stop copy-pasting between 5+ repos |
| 11 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA overrideModAttrs hack |
| 12 | Add `go-error-family` follows to branching-flow input | 2 min | branching-flow depends on it |
| 13 | Add version ldflags to library-policy production build | 5 min | All other repos have it |
| 14 | Audit all Go repos for stale GOFLAGS / go_1_26 | 15 min | Dead config cleanup |
| 15 | Clean up `docs/status/` — 113+ files | 15 min | Clutter |

### Lower Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 16 | Add GitHub Actions CI to all Go repos | 1 hr | Catch build breakage early |
| 17 | `nix flake check` on all repos | 10 min | Validate all repos |
| 18 | Create `just update-vendor-hash` recipe | 15 min | Automate vendor hash cycle |
| 19 | Delete `result` symlink in buildflow repo | 1 min | Build artifact in repo root |
| 20 | Run `just test` (full build) on SystemNix | 20 min | More thorough than test-fast |
| 21 | Archive `docs/status/` files older than 2 weeks | 10 min | Housekeeping |
| 22 | Update AGENTS.md with no-auto-reboot rule | 5 min | Documentation |
| 23 | Check go-filewatcher consumers for /v2 imports | 10 min | May affect other repos |
| 24 | Add pre-push hook to verify Go packages build | 15 min | Prevent stale hashes |
| 25 | Create D2 architecture diagram of Go dep graph | 20 min | Visualize dependency chain |

---

## G) TOP #1 QUESTION

**Should `just verify-packages` (or a pre-push hook) build all Go packages after every `flake.lock` update?**

This session had 5 sequential vendor hash failures, each discovered only after fixing the previous one. The pattern:
1. `flake.lock` bulk update → stale hash in package A
2. Fix A, rebuild → stale hash in package B (different drv, same root cause)
3. Fix B, rebuild → stale hash in package C
4. ...

A single verification step after `nix flake lock` changes would catch ALL stale hashes in one pass. But building 10 Go packages takes ~5 minutes. Worth the CI cost?

---

## Files Changed (SystemNix — 5 commits, unpushed)

| Commit | Files | Detail |
|--------|-------|--------|
| `e7b591c5` | `scripts/display-watchdog.sh`, `docs/status/` | Auto-reboot removed + session 82 status report |
| `5f21660f` | `overlays/shared.nix` | buildflow vendorHash updated |
| `e5ed623f` | `overlays/shared.nix`, `flake.lock` | All vendor hashes + go-filewatcher fix + PMA flake.lock |
| `a65bbdc2` | `flake.lock` | branching-flow update |
| `150ed288` | `flake.lock` | golangci-lint-auto-configure update |

## Files Changed (Upstream — pushed)

| Repo | Commit | Detail |
|------|--------|--------|
| go-filewatcher | `f086f14` | Remove /v2 from module path |
| projects-management-automation | `63dcf91b` | Update go-filewatcher in flake.lock |
| branching-flow | `48c2b88` | Update vendorHash + nixpkgs bump |
| golangci-lint-auto-configure | `1f69efc` | Update vendorHash |

## Files Changed (Upstream — uncommitted)

| Repo | Files | Detail |
|------|-------|--------|
| buildflow | `flake.nix` (vendorHash), `TODO_LIST.md` | vendorHash matches overlay but repo's own copy is stale |
| go-filewatcher | `flake.lock` | nixpkgs drift |
| go-structure-linter | `internal/rules/.gitignore` | Unrelated |
| library-policy | 5 test files | Test refactoring |

---

## Deployment Status

```
✅ nh os boot succeeded — configuration in bootloader
⏳ Reboot required to activate
⏳ Push SystemNix to origin (4 commits)
```
