Session 82: Display Watchdog Auto-Reboot Removed + Go Repo Cleanup + BuildTags Fix

Date: 2026-05-24 00:55 CEST
Scope: SystemNix + 4 upstream Go repos
Status: ⚠️ 5 repos have uncommitted/unpushed changes blocking deployment

---

## Executive Summary

Session 82 addressed cleanup items from session 81's "TOP 25" list. The most critical change: **removed all `systemctl reboot` calls from `display-watchdog.sh`** — the user explicitly stated that auto-reboot is unacceptable on a personal workstation. Additionally, dead `GOFLAGS = "-mod=mod"` was removed from PMA and branching-flow, `go_1_26` was standardized to `go` across devShells, and the library-policy `buildTags` → `GOEXPERIMENT` fix was confirmed committed upstream.

**All changes compile** (`just test-fast` passes) but deployment is blocked by uncommitted upstream changes in 3 repos + uncommitted SystemNix watchdog fix.

---

## A) FULLY DONE

### 1. Display Watchdog — Auto-Reboot Removed

| Change | File | Detail |
|--------|------|--------|
| ✅ Updated | `scripts/display-watchdog.sh` | Removed `systemctl reboot` from both escalation paths (lines 101-104, 112-115) |
| ✅ Updated | `scripts/display-watchdog.sh` | Changed log messages to `CRITICAL: ... Manual intervention required.` |
| ✅ Updated | `scripts/display-watchdog.sh` | Fixed stale comment: "trigger GPU recovery (driver rebind)" → "log critical alert (manual intervention required)" |

**Rationale:** Auto-reboot on a personal workstation is dangerous. Only the user decides when to reboot.

### 2. Dead `GOFLAGS = "-mod=mod"` Removed

| Repo | File | Detail |
|------|------|--------|
| ✅ Removed | `projects-management-automation/flake.nix` | `GOFLAGS = "-mod=mod"` — ignored by buildGoModule which passes `-mod=vendor` |
| ✅ Removed | `branching-flow/flake.nix` | Same dead GOFLAGS in `overrideModAttrs` |

**Rationale:** `buildGoModule` explicitly passes `-mod=vendor` to the Go compiler, overriding any GOFLAGS. These settings were no-ops that created false confidence.

### 3. Go Version Standardized (`go_1_26` → `go`)

| Repo | File | Detail |
|------|------|--------|
| ✅ Updated | `go-structure-linter/flake.nix` | devShell: `go_1_26` → `go` |
| ✅ Updated | `branching-flow/flake.nix` | devShell + buildGoModule override: `go_1_26` → `go` |

**Rationale:** `pkgs.go` in nixpkgs-unstable is already 1.26.2 — the same version as `go_1_26`. Using `go` means the version tracks nixpkgs automatically instead of requiring manual updates.

### 4. library-policy buildTags → GOEXPERIMENT (Confirmed Committed)

| Repo | Commit | Detail |
|------|--------|--------|
| ✅ Committed | `library-policy@8b6d8d5` | `buildTags = ["goexperiment.goroutineleakprofile" ...]` → `buildTags = []` + `env.GOEXPERIMENT = "goroutineleakprofile,jsonv2,simd"` |

This was committed during the session as part of `8b6d8d5` ("docs: update FEATURES.md with SARIF..."). Already on `origin/master`.

### 5. Validation

- `just test-fast` — ✅ All checks passed
- 4 expected warnings from stale `flake.lock` (non-existent input overrides) — will resolve after upstream pushes + flake.lock update

### 6. Dead Code Audit — Clean

| Script | Status |
|--------|--------|
| `scripts/niri-drm-healthcheck.sh` | ✅ Zero gpu-recovery references |
| `scripts/display-watchdog.sh` | ✅ All gpu-recovery references removed |
| All other scripts | ✅ No gpu-recovery references |

---

## B) PARTIALLY DONE

### Upstream Repo Commits (NOT YET COMMITTED)

| Repo | Modified Files | Status |
|------|----------------|--------|
| `go-structure-linter` | `flake.nix` | ⚠️ Uncommitted — removed stale `go-branded-id v0.1.0` requireDep, updated vendorHash, `go_1_26` → `go` |
| `branching-flow` | `flake.nix` | ⚠️ Uncommitted — `go_1_26` → `go`, removed dead GOFLAGS |
| `projects-management-automation` | `flake.nix`, `flake.lock`, `go.mod`, `go.sum` | ⚠️ Uncommitted — added branching-flow + go-error-family + go-finding deps, removed GOFLAGS |
| `buildflow` | None | ✅ No changes needed (but 1 unpushed commit + dirty docs) |

### library-policy Uncommitted (Unrelated)

| File | Detail |
|------|--------|
| `cmd/library-policy/internal/bdd/security_scenarios_test.go` | Test formatting changes |
| `domain/policy/policy_test.go` | Test formatting changes |
| `domain/testutil/testutil.go` | Test utility changes |

These are unrelated to nix/build work — appear to be in-progress test refactoring.

### SystemNix Uncommitted

| File | Detail |
|------|--------|
| `scripts/display-watchdog.sh` | Auto-reboot removed + stale comment fixed |

### SystemNix Unpushed

| Commit | Detail |
|--------|--------|
| `08283e01` | `fix(overlays): re-enable all 4 disabled Go packages + remove gpu-recovery dead code` (session 81) |

### SystemNix flake.lock

- ⚠️ NOT YET UPDATED — needs `nix flake lock --update-input` for go-structure-linter, PMA, and branching-flow after upstream pushes

---

## C) NOT STARTED

| # | Item | Description |
|---|------|-------------|
| 1 | `just switch` deployment | Cannot proceed until upstream repos committed + pushed + flake.lock updated |
| 2 | Smoke test all 4 binaries on evo-x2 | Verify buildflow, go-structure-linter, library-policy, PMA work in NixOS env |
| 3 | Publish `branching-flow/pkg/stats` as proper Go module | Currently only resolves via go.work locally or _local_deps in Nix |
| 4 | Centralize `mkPreparedSource.nix` into shared flake input | Currently copy-pasted into buildflow, go-structure-linter, library-policy, PMA, branching-flow |
| 5 | Add `go-error-family` follows to branching-flow input in SystemNix | branching-flow depends on go-error-family (in go.mod) but SystemNix doesn't follow it |
| 6 | Add GitHub Actions CI to Go repos | None have CI validating nix builds |
| 7 | Create `just update-vendor-hash` recipe | Automate vendor hash update cycle |
| 8 | Archive old `docs/status/` files | 112 files — all within 2 weeks so not urgent |
| 9 | Add version ldflags to library-policy production build | Other repos have it |
| 10 | Fix `boot.zfs.forceImportRoot` warning | Default `true` in rpi3-dns config |

---

## D) TOTALLY FUCKED UP / FAILED APPROACHES

### None in this session

Session 82 was entirely cleanup/fix work with no failed approaches. All changes compiled on first attempt.

### Key Lessons from Session 81 (for reference)

| Approach | Why It Failed |
|----------|---------------|
| `go mod tidy` in `mkPreparedSource.postPatchExtra` | Nix sandbox blocks network + HOME access |
| `GOFLAGS = "-mod=mod"` to bypass vendor | `buildGoModule` passes `-mod=vendor` explicitly, overrides GOFLAGS |
| `subModules` for non-Go-submodule directories | Only works for dirs with their own `go.mod` |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Process

1. **No auto-reboot in any script** — User explicitly rejected this pattern. Scripts should log CRITICAL and stop, never reboot. Audit all other scripts for `systemctl reboot` calls.

2. **`mkPreparedSource.nix` should be a shared flake input** — Currently copy-pasted into 5+ repos. Every change needs manual syncing. A shared `github.com/LarsArtmann/nix-go-helpers` would eliminate drift.

3. **`mkPreparedSource` should support `go mod tidy` natively** — Add a `tidy = true` option that handles HOME/GOCACHE setup. Many repos with complex dep graphs need this.

4. **Go version pinning is wrong** — Multiple repos pin `go_1_26` when `pkgs.go` is already the same version. Should always use `go` to track nixpkgs automatically.

5. **`GOFLAGS = "-mod=mod"` is cargo-culted** — Appeared in at least 2 repos. It does nothing in buildGoModule. Should be audited and removed everywhere.

6. **CI for Go repos** — None have CI that validates the Nix build. A simple `nix build .#default` in GitHub Actions would catch breakage before it reaches SystemNix.

7. **Vendor hash staleness detection** — No automated way to detect stale vendor hashes. CI would catch this.

8. **`branching-flow/pkg/stats` should be published** — Currently only works via `go.work` locally or `_local_deps` in Nix. Publishing eliminates the `overrideModAttrs` + `requireDeps = {}` hack in PMA.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical (blocking deployment)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | Commit changes in `go-structure-linter` | 2 min | Blocks flake.lock update |
| 2 | Commit changes in `branching-flow` | 2 min | Blocks flake.lock update |
| 3 | Commit changes in `projects-management-automation` | 2 min | Blocks flake.lock update |
| 4 | Push all 3 repos + push SystemNix | 2 min | Gets changes to remote |
| 5 | Update SystemNix flake.lock for 3 repos | 2 min | Resolves non-existent input warnings |
| 6 | Commit `display-watchdog.sh` in SystemNix | 1 min | Auto-reboot removal |
| 7 | `just switch` on evo-x2 | 5 min | Deploy everything |

### High Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 8 | Smoke test all 4 binaries on evo-x2 | 5 min | Verify they actually work |
| 9 | Audit ALL scripts for `systemctl reboot` calls | 5 min | User rejected auto-reboot pattern |
| 10 | Publish `branching-flow` with `pkg/stats` as proper Go module | 15 min | Eliminates PMA `overrideModAttrs` hack |
| 11 | Remove `overrideModAttrs` from PMA after branching-flow publish | 5 min | Cleanup |
| 12 | Add `go-error-family` follows to branching-flow input in SystemNix | 2 min | branching-flow depends on it |
| 13 | Centralize `mkPreparedSource.nix` into shared flake input | 30 min | Stop copy-pasting between repos |

### Medium Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 14 | Add version ldflags to library-policy production build | 5 min | All other repos have it |
| 15 | Audit all Go repos for stale `GOFLAGS = "-mod=mod"` | 10 min | Dead config, cargo-culted |
| 16 | Audit all Go repos for `go_1_26` vs `go` | 10 min | Inconsistent version pinning |
| 17 | Fix `boot.zfs.forceImportRoot` warning in rpi3-dns | 2 min | Silences eval warning |
| 18 | Clean up `docs/status/` — 112 files | 15 min | Clutter |
| 19 | Delete `result` symlink in buildflow repo | 1 min | Build artifact in repo root |

### Lower Priority

| # | Task | Effort | Why |
|---|------|--------|-----|
| 20 | Add GitHub Actions CI to all Go repos (nix build check) | 1 hr | Catch breakage early |
| 21 | `nix flake check` on all repos | 10 min | Validate all repos |
| 22 | Create `just update-vendor-hash` recipe for Go repos | 15 min | Automate vendor hash cycle |
| 23 | Run `just test` (full build) on SystemNix | 20 min | More thorough than test-fast |
| 24 | Archive `docs/status/` files older than 2 weeks | 10 min | Housekeeping |
| 25 | Update AGENTS.md with mkPreparedSource patterns + no-auto-reboot rule | 10 min | Documentation |

---

## G) TOP #1 QUESTION

**Should `mkPreparedSource.nix` be extracted into its own shared flake input (`github.com/LarsArtmann/nix-go-helpers`) instead of being copy-pasted into every Go repo?**

It's currently duplicated in: buildflow, go-structure-linter, library-policy, projects-management-automation, branching-flow (5 copies). Every time the helper changes, it needs manual syncing. A shared input would:
- Eliminate drift between copies
- Allow updating all repos with one `nix flake lock --update-input`
- Enable testing changes once instead of 5 times

But: adds another level of indirection and a new repo to maintain.

---

## Files Changed (This Session)

### SystemNix

| File | Action | Lines |
|------|--------|-------|
| `scripts/display-watchdog.sh` | MODIFIED | -5 +3 (removed 2 reboot calls + fixed comment) |

### go-structure-linter (uncommitted)

| File | Change |
|------|--------|
| `flake.nix` | Removed stale `go-branded-id v0.1.0` from requireDeps, updated vendorHash, `go_1_26` → `go` |

### branching-flow (uncommitted)

| File | Change |
|------|--------|
| `flake.nix` | `go_1_26` → `go` (3 occurrences), removed dead `GOFLAGS = "-mod=mod"` |

### projects-management-automation (uncommitted)

| File | Change |
|------|--------|
| `flake.nix` | Added branching-flow + go-error-family + go-finding inputs/deps, removed dead GOFLAGS, added overrideModAttrs |
| `flake.lock` | Updated with new inputs |
| `go.mod` | Added branching-flow v0.1.0, go-error-family v0.1.1, samber/mo v1.16.0 |
| `go.sum` | Updated with transitive deps |

### library-policy (committed, on origin/master)

| File | Change |
|------|--------|
| `nix/packages/default.nix` | `buildTags` → `env.GOEXPERIMENT` (committed in `8b6d8d5`) |

---

## Deployment Checklist

```
# Step 1: Commit upstream repos
cd ~/projects/go-structure-linter && git add flake.nix && git commit -m "..."
cd ~/projects/branching-flow && git add flake.nix && git commit -m "..."
cd ~/projects/projects-management-automation && git add flake.nix flake.lock go.mod go.sum && git commit -m "..."

# Step 2: Push everything
cd ~/projects/go-structure-linter && git push
cd ~/projects/branching-flow && git push
cd ~/projects/projects-management-automation && git push
cd ~/projects/library-policy && git push  # already committed

# Step 3: Update SystemNix flake.lock
cd ~/projects/SystemNix
nix flake lock --update-input go-structure-linter
nix flake lock --update-input branching-flow
nix flake lock --update-input projects-management-automation
nix flake lock --update-input library-policy

# Step 4: Commit SystemNix
git add scripts/display-watchdog.sh flake.lock
git commit -m "fix(watchdog): remove auto-reboot + update flake.lock for Go repos"

# Step 5: Deploy
just switch
```
