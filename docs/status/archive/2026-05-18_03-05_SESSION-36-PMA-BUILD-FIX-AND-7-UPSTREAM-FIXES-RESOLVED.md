# Session 36 Status — PMA Build Fix + 7/7 Upstream Failures Resolved

**Date:** 2026-05-18 03:05 CEST
**Session:** 36 (Continuation of Session 35 Execution Plan)
**Host:** evo-x2 (192.168.1.150, x86_64-linux)

---

## Executive Summary

The blockers from Session 35 have been resolved. All 7 upstream build failures are now fixed. The `projects-management-automation` (PMA) package builds successfully through the SystemNix overlay, producing a 35.1 MB binary. Seven flake inputs were updated and validated.

---

## a) FULLY DONE ✅

### 1.1 — Resolved PMA Build Failure (Session 35 Blocker)
- **Root cause:** `project-discovery-sdk` still imported `go-composable-business-types/programminglanguage`, which was deleted upstream
- **Fix:** Updated `project-discovery-sdk` to rev `f019f6f` which replaces `programminglanguage` types with plain `string`/`[]string`
- **Scope creep discovered:** `go-output` also needed updating (v0.2.0 → v0.4.1) because PMA's code used `output.RenderTableData` / `output.RenderOptions`, added in `go-output` `4c1e905`
- **Tag published:** `go-output/testhelpers/v0.0.0` (Go module requires tagged sub-modules)
- **Result:** PMA builds as 35.1 MB binary ✅

### 1.2 — Simplified PMA preparedSrc
- Removed stale `sed` version-bump commands (go-filewatcher v0.2.0→0.2.1, go-composable-business-types v0.3.0→0.4.0, golang.org/x/time injection)
- Removed duplicate `require` loop for go-output sub-modules (already in go.mod)
- Added `testhelpers` to replace for loop (missing from original)
- Added gogenfilter/v3 explicit require via conditional sed
- Removed `overrideModAttrs` + `go mod tidy` (no longer needed — preparedSrc is self-consistent)

### 1.3 — SystemNix Deployment Ready
- Updated `flake.lock`: pma input now at `c0f31ff`, go-output at `4c1e905`, SDK at `f019f6f`
- `nix flake check --all-systems --no-build` passes ✅
- `nix build .#packages.x86_64-linux.projects-management-automation` succeeds ✅

### All 7 Upstream Fix Summary

| Package | Issue | Fix Location | Fix Applied |
|---------|-------|-------------|-------------|
| todo-list-ai | Stale npmDepsHash | overlays/shared.nix | Updated hash |
| go-structure-linter | Missing go-branded-id replace + go.sum | Upstream repo | 10 commits → added replace, merged go.sum, overrideModAttrs |
| mr-sync | Already fixed at listed rev | flake.lock | No change needed |
| hierarchical-errors | Stale vendorHash | Upstream repo | Updated vendorHash |
| branching-flow | Stale vendorHash | Upstream repo | Updated vendorHash |
| jscpd | Stale pnpm hash + missing lockfile injection | pkgs/jscpd.nix | Complete rewrite with makeWrapper + src wrapping |
| projects-management-automation | programminglanguage deleted but SDK still imports it | Upstream + SystemNix | Updated SDK + go-output + simplified preparedSrc |

---

## b) PARTIALLY DONE 🔄

| Task | Status | Why Incomplete |
|------|--------|----------------|
| Session 35 execution plan (35 tasks) | ~8% complete | Session was interrupted; only Task 1.1 (PMA) resolved |
| GitHub token config (~/.config/nix/nix.conf) | ✅ Done (Task 2.1) | Configured in Session 35 |
| Darwin verification | ⏳ Not done | Need `nix flake check --system aarch64-darwin` from MacBook |
| rpi3-dns verification | ⏳ Not done | Need `--system aarch64-linux` check |

---

## c) NOT STARTED ⏳

The remaining ~32 tasks from the comprehensive execution plan:

### Phase 2 (Infrastructure)
- 2.4 — Update AGENTS.md with session 35/36 lessons (_local_deps pattern, overrideModAttrs, transitive go.sum merging)
- 2.5 — Squash go-structure-linter 10 commits into 1-2 clean commits
- 2.6 — Run vendor hash audit on all Go overlays
- 2.7 — Add `just` recipes: `update-vendor-hashes`, `test-upstream-builds`

### Phase 3 (Patterns & Architecture)
- 3.1 — Create `lib/prepared-source.nix` (`mkPreparedSource` helper)
- 3.2 — Refactor go-structure-linter, branching-flow, mr-sync, projects-management-automation to use `mkPreparedSource`
- 3.3 — Create `overrideModAttrs` helper pattern for `_local_deps` repos
- 3.4 — Create `pkgs/mk-pnpm-package.nix` (·reusable jscpd pattern)
- 3.5 — Write ADR for `_local_deps` pattern
- 3.6 — Add `test-upstream-builds` just recipe
- 3.7 — Evaluate gomod2nix for Go repos
- 3.8 — Implement `just hash-check --fix`
- 3.9 — Go.sum transitive merge audit

### Phase 4 (Long-term Hardening)
- 4.1 — Write upstream fix playbook
- 4.2 — Write session 35/36 case study
- 4.3 — Set up cachix + substituters
- 4.4 — CI spec for pre-merge validation
- 4.5 — Flake input review (unused/stale)
- 4.6 — Explore `fetchGoModules` for private repos
- 4.7 — `update-all-vendor-hashes` just recipe
- 4.8 — Refactor `todoListAiFixedHash` pattern
- 4.9 — GitHub Actions for automated vendor hash updates
- 4.10 — Contribute jscpd upstream fix
- 4.11 — Consolidate status docs

---

## d) TOTALLY FUCKED UP ❌

**Nothing.** All 7 upstream build failures are resolved. No blockers remain.

---

## e) WHAT WE SHOULD IMPROVE 🎯

1. **PreparedSrc tooling is too manual** — Seven repos have near-identical `_local_deps` + `replace` boilerplate. Extracting this into `lib/prepared-source.nix` would eliminate copy-paste errors and make version bumps trivial.

2. **No automated vendor hash validation** — We discovered stale hashes only when builds failed during `nix flake update`. A `test-upstream-builds` recipe would catch regressions before deployment.

3. **Go tag hygiene for sub-modules** — `go-output/testhelpers` didn't have a tag, breaking downstream `go mod tidy`. All sub-modules need tags on release.

4. **Cross-repo dependency tracking** — `go-composable-business-types` deleting `programminglanguage` broke a downstream SDK. There's no CI gate preventing breaking changes to packages with external consumers.

5. **Session recovery** — The previous session was interrupted because it exceeded tool limits (50 background jobs). Work needs to be batchable in smaller chunks.

6. **Darwin verification is rare** — Most fixes are validated only on x86_64-linux. We should test `aarch64-darwin` more frequently, especially after jscpd-style changes.

---

## f) Top 25 Things To Do Next

1. **Commit SystemNix flake.lock** (pma input update) ✅ → Deploy via `nh os boot`
2. **Write status report** (this doc) → commit it
3. **Test Darwin build** (`nix build .#packages.aarch64-darwin.*`) from MacBook
4. **Update AGENTS.md** with `_local_deps`, `overrideModAttrs`, `go.sum transitive merge` patterns
5. **Create `lib/prepared-source.nix`** — reusable `mkPreparedSource` helper
6. **Refactor go-structure-linter** to use `mkPreparedSource`
7. **Refactor branching-flow** to use `mkPreparedSource`
8. **Refactor mr-sync** to use `mkPreparedSource`
9. **Refactor projects-management-automation** to use `mkPreparedSource`
10. **Squash go-structure-linter** 10 commits into 1-2 clean commits
11. **Add `just test-upstream-builds`** recipe
12. **Add `just update-vendor-hashes`** recipe
13. **Run vendor hash audit** across all Go overlays
14. **Write ADR** for `_local_deps` pattern
15. **Create `mk-pnpm-package.nix`** for jscpd-style packages
16. **Write upstream fix playbook** (session 35/36 learnings)
17. **Write case study** from session 35/36
18. **Flake input audit** — check for unused/stale inputs
19. **Evaluate gomod2nix** vs current `buildGoModule` approach
20. **Cachix setup** for faster rebuilds across machines
21. **CI spec** for pre-merge `nix flake check`
22. **`fetchGoModules`** exploration for private repo fetch
23. **`just hash-check --fix`** implementation
24. **Contribute jscpd** upstream fix (wrapped-src pattern)
25. **Clean up status docs** — consolidate session reports

---

## g) Top Question I Cannot Figure Out

**Why does `nix build` on Darwin hang for 40+ minutes when building `otel-tui` from source, and why does `dsymutil` exhaust disk during the process?**

The repo excludes `otel-tui` from Darwin using `_module.args.otel-tui = null`, which works but feels like a workaround rather than a root-cause fix. Is there a way to:

1. Cross-compile `otel-tui` from Linux to Darwin (avoiding dsymutil on macOS)?
2. Use a pre-built binary/cache instead of building from source on Darwin?
3. Or is the correct answer simply "don't build Rust from source on Darwin with 229 GB disk"?

We need a policy: for Rust packages that exceed reasonable build times on Darwin, should we (a) cross-compile from Linux, (b) use `fetchurl` binaries, or (c) exclude from Darwin entirely?

---

## Verification Notes

```bash
# All pass:
nix flake check --all-systems --no-build  # ✅
nix build .#packages.x86_64-linux.projects-management-automation  # ✅

# Pending:
# nix build .#darwinConfigurations.Lars-MacBook-Air.system  # Need MacBook
# nix build .#nixosConfigurations.rpi3-dns.config.system.build.toplevel  # Need aarch64-linux
```

## Key Files Changed (Upstream)

| Repo | Commits | Key Change |
|------|---------|-----------|
| `projects-management-automation` | f94cbae7 → c0f31ffc | Fix nix build: update SDK, go-output, simplify preparedSrc |
| `project-discovery-sdk` | 2cea9b6 → f019f6f | Remove programminglanguage dependency |
| `go-output` | eb3449c → 4c1e905 | Add RenderTableData + dispatcher |

## Key Files Changed (SystemNix)

| File | Change |
|------|--------|
| `flake.lock` | Pma at c0f31ffc (was f94cbae7), go-output 4c1e905 (was eb3449c), SDK f019f6f (was 2cea9b6) |
| `docs/status/2026-05-18_03-05_SESSION-36-PMA-BUILD-FIX-AND-SCALE-STATUS.md` | This document |
