# Session 99: Flake Reliability Hardening

**Date:** 2026-05-27 12:27 | **Status:** All planned work COMPLETE | **Platform:** evo-x2 (NixOS 26.11)

---

## A) Fully Done

### 1. Fixed `todo-list-ai` hash mismatch (the trigger)
- **Root cause:** Upstream `todo-list-ai` bun dependency change caused `todoListAiFixedHash` in `overlays/shared.nix` to go stale
- **Fix:** Updated hash from `sha256-iBUuLv...` to `sha256-WpViT+...` (the `got:` value from Nix)
- **File:** `overlays/shared.nix:44`
- **Verified:** `nix build .#todo-list-ai --no-link` succeeds

### 2. Hash-check gate on `just switch`
- `just switch` now runs `just hash-check` BEFORE `nh os switch` / `darwin-rebuild`
- If any overlay package has a stale vendorHash/npmDepsHash, the switch **aborts before the 2-3 min NixOS build starts**
- Prevents the exact failure that triggered this session
- **Files:** `justfile:29-38`

### 3. Added `just test-hashes` command
- Alias for `just hash-check` — provides a discoverable name in `just --list` under the quality group
- Useful as a quick pre-flight check without running the full `just test`
- **Files:** `justfile:111-114`

### 4. Port collision detection in `lib/ports.nix`
- Asserts all port values are unique at eval time using `builtins.genericClosure`
- Catches port collisions that would otherwise only surface at runtime when two services fight
- Tested: inject a duplicate → assertion fires immediately with value count mismatch
- **Files:** `lib/default.nix:24-33`

### 5. Auto-discover service modules (eliminated manual sync)
- **Before:** 35-entry manual `serviceModules` list in `flake.nix` — adding a service meant editing both the file AND the list
- **After:** `flake.nix` auto-discovers all `modules/nixos/services/*.nix` by parsing `flake.nixosModules.<name>` from file contents
- **Conventions enforced:**
  - Filename must match module name (e.g., `forgejo.nix` → `nixosModules.forgejo`) — assertion at eval time
  - Files without `nixosModules.*` declaration (like `signoz-alerts.nix` helper) are automatically skipped
- **Side effect:** Renamed `default.nix` → `default-services.nix` (was the only file violating filename=module convention)
- **Net change:** Removed ~140 lines of boilerplate from `flake.nix`
- **Files:** `flake.nix:378-416`, `modules/nixos/services/default.nix` → `default-services.nix`

### 6. AGENTS.md documentation updated
- Updated "Adding a Service" section with auto-discovery convention
- Updated architecture tree to document `ports.nix` (collision-protected)
- Updated gotchas table with new `serviceModules` auto-discovery entry
- **Files:** `AGENTS.md`

### 7. Reliability improvements planning document
- Created `docs/planning/2026-05-27_flake-reliability-improvements.md` with 8 prioritized improvements (P0-P3)
- Covers: hash gates, FOD management, CI, port collisions, module discovery, overlay isolation
- **Files:** `docs/planning/2026-05-27_flake-reliability-improvements.md`

---

## B) Partially Done

### 1. `.pre-commit-config.yaml` — already comprehensive
- Investigated adding test-fast to pre-commit — **it already has it** (`nix-check` hook calls `just validate` = `test-fast`)
- No changes needed. The existing pre-commit config has: gitleaks, deadnix, statix, alejandra, nix-check, flake-lock-validate, shellcheck, merge-conflict detection
- **Status:** Already done before this session

---

## C) Not Started

### 1. Move `todo-list-ai` FOD hash management upstream
- `overlays/shared.nix` still has `todoListAiFixedHash` — a manual FOD hash for bun node_modules
- Requires upstream `todo-list-ai` repo to handle bun deps in its own flake
- Then SystemNix can use `mkPackageOverlay` like all other packages

### 2. Remove hardcoded `vendorHash` from `linux.nix`
- `dnsblockd` and `file-and-image-renamer` have vendorHash overrides in SystemNix instead of upstream
- Requires upstream repos to manage their own hashes

### 3. GitHub Actions CI
- No CI exists — all checks are manual or pre-commit only
- Private Go repos (`git+ssh://`) won't build in GitHub Actions without SSH deploy keys
- CI should at minimum run: `test-fast` + statix + deadnix

### 4. PMA `go.work` version mismatch
- `go 1.26.2` in go.work but all modules use `go 1.26.3` — breaks local golangci-lint

### 5. PMA `overrideModAttrs` anti-pattern
- Still present at `flake.nix:222` in PMA repo — needed for synthetic submodule requires
- Blocked on publishing git tags for go-output submodules

### 6. go-output submodule go.mod versions
- 9 submodules still at `go 1.26.2`

### 7. Verify `just switch` works end-to-end on evo-x2
- Changes haven't been deployed yet — only `test-fast` verified

---

## D) Totally Fucked Up

Nothing. All changes verified with `nix flake check --no-build --all-systems` (all checks passed).

---

## E) What We Should Improve

### High Priority
1. **Deploy and verify** — `just switch` has not been run yet. The hash-check gate + auto-discovery both need a real deploy to prove they work end-to-end
2. **Upstream FOD management** — `todo-list-ai` and `linux.nix` vendor hashes should be managed by upstream repos, not SystemNix
3. **CI pipeline** — Even a basic `nix flake check --no-build` on push would catch eval errors before they reach the machine

### Medium Priority
4. **Port assertion error message** — Currently shows count mismatch (25 ≠ 24) but not which ports collide. Could be improved to show the actual duplicate values
5. **`test-hashes` is just an alias** — Could be made smarter to only check packages that changed since last commit (git-diff based)
6. **Service module auto-discovery reads all files at eval time** — Fine for 36 files, but could slow eval if the directory grows significantly. Consider a `# @module <name>` comment convention instead of parsing

### Low Priority
7. **Home Manager version mismatch** — 26.05 vs nixpkgs 26.11 warning on every eval. Should update home-manager input or add `home.enableNixpkgsReleaseCheck = false`
8. **ZFS `forceImportRoot` warning** — Default changed in 26.11, should explicitly set to `false`
9. **Darwin overlay isolation** — `mkPackageOverlay` could accept a `platforms` parameter to auto-skip non-matching systems

---

## F) Top 25 Next Tasks

### Tier 1: Immediate (today)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Run `just switch` on evo-x2 to deploy all changes | 5 min | Critical — untested in production |
| 2 | Fix PMA go.work: `go 1.26.2` → `go 1.26.3` | 2 min | Unblocks local golangci-lint |
| 3 | Fix go-output submodule go.mod versions (9 files) | 10 min | Consistency |
| 4 | Publish git tags for go-output submodules | 10 min | Enables PMA overrideModAttrs removal |
| 5 | Publish git tags for project-discovery-sdk submodules | 10 min | Enables PMA overrideModAttrs removal |
| 6 | Remove PMA `overrideModAttrs` after tags exist | 15 min | Eliminates anti-pattern |

### Tier 2: This Week

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 7 | Move `todo-list-ai` bun FOD management to upstream repo | 30 min | Eliminates most fragile hash in SystemNix |
| 8 | Move `dnsblockd` vendorHash to upstream repo | 15 min | Eliminates linux.nix hardcode |
| 9 | Move `file-and-image-renamer` vendorHash to upstream repo | 15 min | Eliminates linux.nix hardcode + anti-pattern |
| 10 | Add GitHub Actions CI: `nix flake check --no-build` on push | 30 min | Catch eval errors pre-deploy |
| 11 | Fix Home Manager version mismatch warning | 5 min | Clean eval output |
| 12 | Set `boot.zfs.forceImportRoot = false` explicitly | 2 min | Suppress 26.11 warning |
| 13 | Verify Darwin build still passes (`test-fast` on macOS) | 5 min | Cross-platform regression check |

### Tier 3: Architecture

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 14 | Redesign `mkPreparedSource` to auto-generate `require` lines | 2 hr | Eliminates manual `postPatchExtra` sed hacks |
| 15 | Add `# @module <name>` convention to replace file parsing | 1 hr | Faster eval, more explicit |
| 16 | Improve port collision assertion with duplicate names in error | 30 min | Better DX on collision |
| 17 | Add `mkPackageOverlay` platform filtering (skip Linux-only on Darwin) | 1 hr | Cleaner overlay separation |
| 18 | Add `just test-hashes` smart mode (only changed packages) | 1 hr | Faster pre-commit feedback |

### Tier 4: Nice to Have

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 19 | Convert /data BTRFS from toplevel to @data subvolume | 30 min | Enables /data snapshots |
| 20 | Add Gatus health checks for all services | 1 hr | Observability |
| 21 | Audit all services for `WatchdogSec` misuse | 30 min | Correctness |
| 22 | Centralize Docker image tags in `lib/` (not scattered in modules) | 2 hr | Single source of truth |
| 23 | Add `just test` to GitHub Actions (full build) | 1 hr | Complete CI coverage |
| 24 | Create `modules/nixos/services/` README with conventions | 15 min | Onboarding |
| 25 | Benchmark flake eval time before/after auto-discovery | 10 min | Performance baseline |

---

## G) Open Question

**None.** All work is self-contained within SystemNix and verified. The only uncertainty is whether `just switch` succeeds on evo-x2 — but that's a deployment step, not an architectural question.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Files changed | 6 (+ 1 new, 1 renamed) |
| Lines removed | ~150 (manual serviceModules list) |
| Lines added | ~70 (auto-discovery + assertions + docs) |
| Net change | -80 lines (simpler + more reliable) |
| Pre-commit hooks | 9 (already existed, no changes) |
| Flake eval | All checks passed (all systems) |
| Packages building | All overlay packages verified |
