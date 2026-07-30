# Status: cqrs-lint Fixed — Multi-Layer Stale Lock + Upstream cmdguard v4 Migration

**Date:** 2026-07-29 14:56
**Session goal:** Fix `cqrs-lint = null` in `lars-packages.nix` (stale go-cqrs-lite flake.lock entry)
**Result:** ✅ cqrs-lint 0.2.2 builds from SystemNix flake

---

## What Was Done

### Root Cause (3 Layers Deep)

The TODO item described the symptom ("stale flake.lock with SSH URL") but the actual root cause was three compounding issues:

1. **Stale flake.lock orphan node** — `go-cqrs-lite` (no suffix) had `flake: false` + SSH URL + rev `92d87145` (ancient). nix would NOT update it via `nix flake lock --update-input` or `--override-input` or `--refresh` — the node persisted across every standard command. The real flake input was resolved via `go-cqrs-lite_3` (a proper flake at rev `05d12c05`), but the orphan's existence meant `flakePkg inputs.go-cqrs-lite` returned null because SystemNix's root input (`go-cqrs-lite`) pointed at the orphan via `crush-daily.inputs.go-cqrs-lite = go-cqrs-lite`.

2. **cmdguard v3→v4 upstream break** — go-cqrs-lite's `cmd/cqrs-lint/*.go` files imported `github.com/larsartmann/cmdguard/v3/pkg/cmdguard/v3`, but the cmdguard repo had migrated to v4 (`module github.com/larsartmann/cmdguard/v4`, package at `pkg/cmdguard/v4/`). The v3 package path no longer existed. This was a real upstream code bug — not a lock issue.

3. **go.mod / vendorHash inconsistency** — mkPreparedSource replaces LarsArtmann deps with `ref=master` flake:false sources, but `cmd/cqrs-lint/go.mod` pinned tagged versions (e.g. `cmdguard/v4 v4.0.0`). When a master source has newer indirect deps than the pinned tag, `go mod vendor` inside the Nix sandbox rejects the inconsistency with "updates to go.mod needed; to update it: go mod tidy". Fix: commit a tidied go.mod that includes all indirect deps from the master sources.

### Changes Made

**Upstream go-cqrs-lite (pushed to master — `e0855503..05d12c05`):**
- Migrated all 4 `.go` files: `cmdguard/v3/pkg/cmdguard/v3` → `cmdguard/v4/pkg/cmdguard/v4`
- Updated `cmd/cqrs-lint/go.mod`: `cmdguard/v3 v3.1.0` → `cmdguard/v4 v4.0.0`
- Updated `flake.nix` deps map: `"github.com/larsartmann/cmdguard/v3"` → `"github.com/larsartmann/cmdguard/v4"`
- Ran `go mod tidy` with local replaces matching mkPreparedSource's deps to capture correct indirect deps
- Updated `vendorHash` to `sha256-9dhkwiLSyXXiMByZ+GxWhSTVGLm4Dvl799N3yXUKSKs=`
- All cqrs-lint tests pass (12 packages, 0 failures)

**SystemNix (committed — `664f575c`, `0969f025`, `94b115d9`):**
- `lib/lars-packages.nix`: `cqrs-lint = null` → `cqrs-lint = inputs.go-cqrs-lite.packages.${system}.cqrs-lint or null`
- `flake.lock`: `go-cqrs-lite_3` updated to rev `05d12c05cfa0a062909b3c0d37eeedc11bdfe940` (the fixed upstream commit)
- `TODO_LIST.md`: task marked done with root cause summary

### Verification

| Check | Result |
|-------|--------|
| `nix flake check --no-build` | ✅ all checks passed |
| `nix build .#cqrs-lint` | ✅ `cqrs-lint 0.2.2` |
| `nix eval .#cqrs-lint.meta.name` | ✅ `cqrs-lint-05d12c05cfa0a062909b3c0d37eeedc11bdfe940` |
| cqrs-lint in systemPackages | ✅ count = 1 |
| Upstream `go test ./...` | ✅ 12 packages pass |

---

## a) FULLY DONE

1. ✅ Diagnosed the 3-layer root cause (stale lock orphan + cmdguard v4 migration + go.mod inconsistency)
2. ✅ Fixed upstream go-cqrs-lite: cmdguard v3→v4 imports, go.mod, go.sum, vendorHash
3. ✅ Verified upstream build + tests pass
4. ✅ Pushed upstream changes to GitHub
5. ✅ Updated SystemNix flake.lock (`go-cqrs-lite_3`) to the fixed commit
6. ✅ Re-enabled cqrs-lint in `lars-packages.nix`
7. ✅ Verified `nix build .#cqrs-lint` produces working binary (`0.2.2`)
8. ✅ Verified `nix flake check --no-build` passes
9. ✅ Verified cqrs-lint is in `environment.systemPackages` (count=1)
10. ✅ Updated TODO_LIST.md

---

## b) PARTIALLY DONE

1. ⚠️ **Orphan flake.lock nodes NOT cleaned up.** There are 4 `go-cqrs-lite` nodes in flake.lock:
   - `go-cqrs-lite` (flake=false, rev `92d87145`, SSH URL) — referenced by `crush-daily.inputs.go-cqrs-lite`. **STALE** but actively used by crush-daily as a Go module source. Not a bug per se, but confusing.
   - `go-cqrs-lite_2` (flake=false, rev `da745368`) — referenced by `discordsync.inputs.go-cqrs-lite`. Pinned rev.
   - `go-cqrs-lite_3` (flake=true, rev `05d12c05`) — referenced by `root.inputs.go-cqrs-lite`. **The correct one.**
   - `go-cqrs-lite_4` (flake=false, rev `92d87145`, SSH URL) — referenced by `overview.inputs.go-cqrs-lite`. **STALE** same as `go-cqrs-lite`.

   These 4 nodes exist because crush-daily, discordsync, and overview each define their own `go-cqrs-lite` input as `flake=false` (Go module source) at different revs, while the root SystemNix input is a proper flake. This is the source of all the confusion. Consolidating would require adding `go-cqrs-lite.follows = "go-cqrs-lite"` to those sub-flakes — but that's risky because they use it as a source dep and vendorHash depends on the exact rev.

2. ⚠️ **AGENTS.md not updated.** The cqrs-lint gotcha entries (lines referencing `cqrs-lint samber-do-auditlog version drift`, the old `cmdguard/v3/pkg/cmdguard/v3` path issue, the "temporarily disabled" notes) are now stale. They should document the v3→v4 migration and the go.mod tidying pattern.

---

## c) NOT STARTED

1. ❌ **Deploy to evo-x2** — `nix run .#deploy` not run. cqrs-lint is committed but not activated on the live system.
2. ❌ **Post-deploy verification** — `nix run .#post-deploy-check` not run.
3. ❌ **Darwin verification** — cqrs-lint builds on x86_64-linux but NOT verified on aarch64-darwin (Lars-MacBook-Air). It's pure Go (`CGO_ENABLED=0`, `platforms.unix`) so should work, but untested.
4. ❌ **devShell inclusion** — cqrs-lint is in `environment.systemPackages` but not in `devShells.default` for explicit dev-tool visibility.

---

## d) TOTALLY FUCKED UP

1. 🔴 **Wasted enormous time on flake.lock lock surgery attempts.** I tried `nix flake lock --update-input`, `--override-input`, `--refresh`, node deletion + regeneration, and manual JSON surgery at least 5-6 times before understanding that nix deduplicates nodes by repo identity and copies `flake:false` from sibling nodes (go-cqrs-lite_2, _4). I should have traced the full node reference graph FIRST before any surgery.

2. 🔴 **The `postPatch` / `overrideModAttrs` `go mod tidy` detour.** I spent multiple build cycles trying to get `go mod tidy` to run inside the Nix sandbox (`GOCACHE`, `HOME`, network access issues) before realizing the correct fix was to commit a pre-tidied go.mod upstream. This was a wrong approach that cost ~3 build cycles.

3. 🔴 **cmdguard v4.0.0 pin detour.** I tried pinning cmdguard to v4.0.0 in go-cqrs-lite's flake.nix to match go.mod, then discovered ALL deps would need pinning (not just cmdguard), then reverted. Should have immediately gone to "tidy go.mod with local replaces" as the first approach.

4. 🔴 **Pushed intermediate broken commits to go-cqrs-lite master.** The auto-commit daemon pushed commits with wrong vendorHash values before I arrived at the correct one. The final commit (`05d12c05`) is correct, but intermediate pushes polluted the history.

---

## e) WHAT WE SHOULD IMPROVE

1. **Trace the full node reference graph BEFORE any lock surgery.** `python3 -c` scripts that map all nodes + references take 10 seconds and would have revealed `go-cqrs-lite_3` (the correct flake node) immediately, saving 30+ minutes of futile `nix flake lock` attempts.

2. **Commit tidied go.mod upstream as the FIRST fix, not the last.** The mkPreparedSource `ref=master` vs go.mod pinned-tag mismatch is a known pattern. Running `go mod tidy` with local replaces is the correct fix — should have been step 1.

3. **Never run `go mod tidy` inside a Nix sandbox.** It needs network + HOME + GOCACHE. Pre-tidy the go.mod in the source repo instead.

4. **The auto-commit daemon pushed multiple wrong vendorHash values to go-cqrs-lite master.** Each `lib.fakeHash` → build → extract hash → edit cycle created a commit. Should have computed the hash offline first or committed only after verification.

5. **The 4 separate `go-cqrs-lite` flake.lock nodes are a maintenance hazard.** Every consumer (root, crush-daily, discordsync, overview) defines its own go-cqrs-lite input at a different rev. A consolidation strategy (follows or shared pinning) would prevent future stale-lock confusion.

6. **The flake.nix comment about `go-cqrs-lite` says "Go dep inputs are NOT followed" but doesn't explain the 4-node lock explosion.** A comment documenting WHY root is a flake while consumers use it as `flake=false` source would save future debugging.

---

## f) Next Tasks (Up to 50)

### Immediate (this session's unfinished work)
1. **Deploy to evo-x2** — `nix run .#deploy` to activate cqrs-lint on the live system
2. **Run post-deploy-check** — `nix run .#post-deploy-check` to verify no silent failures
3. **Update AGENTS.md** — Replace stale cqrs-lint gotchas (samber-do-auditlog v0.5.0 pin, cmdguard/v3 path, "temporarily disabled" notes) with the v4 migration + go.mod tidying pattern
4. **Verify `cqrs-lint --version` in a new shell** on evo-x2 after deploy

### Consolidation & Cleanup
5. **Audit all 4 go-cqrs-lite lock nodes** — determine if crush-daily/discordsync/overview can use `follows` to reduce to 1 node
6. **Consider consolidating go-cqrs-lite consumers** to a single pinned rev across all SystemNix sub-flakes
7. **Clean up orphan `go-cqrs-lite` node** (flake=false, SSH URL, rev 92d87145) if crush-daily can follow root instead
8. **Add `go-cqrs-lite.follows` to crush-daily** in SystemNix flake.nix if safe (test vendorHash doesn't break)
9. **Add `go-cqrs-lite.follows` to overview** in SystemNix flake.nix if safe
10. **Document the 4-node pattern** in flake.nix comments near the go-cqrs-lite input definition

### cqrs-lint Usage
11. **Add cqrs-lint to `devShells.default`** for explicit dev-tool visibility
12. **Run cqrs-lint against go-cqrs-lite itself** — dogfood the linter on its own codebase
13. **Run cqrs-lint against SystemNix Go services** (discordsync, crush-daily, etc.) — validate real-world usage
14. **Verify cqrs-lint builds on aarch64-darwin** (Lars-MacBook-Air)
15. **Consider adding cqrs-lint to CI** — `nix build .#cqrs-lint` as a gate

### Upstream go-cqrs-lite
16. **Squash intermediate broken commits** or accept them as history (the final state is correct)
17. **Add a post-build assertion** to `packages.cqrs-lint` — `test -x $out/bin/cqrs-lint` to catch silent empty builds
18. **Consider adding `packages.cqrs-gen`** to the flake (same pattern as cqrs-lint)
19. **Update go-cqrs-lite AGENTS.md** with the cmdguard v4 migration and go.mod tidying pattern
20. **Add CI for cqrs-lint vendorHash drift** — catch upstream dep changes before they break SystemNix builds

### Lock & Dependency Hygiene
21. **Run `nix flake lock --refresh` on all SystemNix inputs** to catch other stale SSH-URL nodes
22. **Audit all `flake=false` inputs** for staleness (same pattern as go-cqrs-lite orphan)
23. **Check if the `git insteadOf` rule** (`url.git@github.com:.insteadof=https://github.com/`) causes other lock issues
24. **Consider removing the `insteadOf` rule** if it's not needed (all repos are public or have access-tokens)
25. **Add a pre-commit or CI check** that catches `cqrs-lint = null` regressions

### Monitoring & Operations
26. **Verify cqrs-lint doesn't break the evo-x2 closure size** significantly
27. **Run `nix path-info -r .#cqrs-lint` to check closure size**
28. **Monitor deploy for any start-limit-hit** or service restart issues

### Documentation
29. **Document the mkPreparedSource go.mod tidying pattern** as a reusable recipe
30. **Update docs/DOMAIN_LANGUAGE.md** if cqrs-lint concepts need domain definitions
31. **Add cqrs-lint to FEATURES.md** if it's a user-facing dev tool
32. **Update README.md** if cqrs-lint should be mentioned in dev tool setup

### Broader SystemNix
33. **Run `nix flake check --all-systems`** to verify Darwin evaluation too
34. **Check if any other LarsArtmann Go tools have the same cmdguard v3→v4 issue**
35. **Audit all Go tool flake inputs for `flake=false` orphan patterns**
36. **Consider a flake.lock linter** that detects orphan nodes + stale SSH URLs
37. **Review the auto-commit daemon's behavior** — it pushed broken intermediate vendorHash values
38. **Add a vendorHash CI check for all Go tool packages** in lars-packages.nix

### Testing
39. **Write a test that builds cqrs-lint from SystemNix** — catch regressions
40. **Write a test that cqrs-lint is in systemPackages** — catch `null` regressions
41. **Write a test that cqrs-lint version matches expected** — catch upstream drift
42. **Test cqrs-lint on a real go-cqrs-lite consumer project** — validate lint rules work

### Technical Debt
43. **The `go-cqrs-lite` flake.nix comment says "Go dep inputs are NOT followed"** — update with rationale for the 4-node pattern
44. **The cqrs-lint vendorHash is still fragile** — it breaks every time a transitive dep updates. Consider a more robust approach
45. **The `samber-do-auditlog` version drift gotcha in AGENTS.md** (lines 379) is now partially stale — the v0.5.0 pin was removed, v0.8.1 resolves transitively
46. **The "cqrs-lint temporarily disabled" notes in status docs** (2026-07-29_07-21, 2026-07-29_07-18, etc.) should be annotated as resolved
47. **Run `deadnix` on lars-packages.nix** — check for unused params after the cqrs-lint change
48. **Consider adding `restartTriggers` pattern** for any future cqrs-lint service usage
49. **Review if cqrs-lint needs to be in the quickshell devShell** for QML development
50. **Consider a `nix flake update` pass** to refresh all lock entries (many may be stale like go-cqrs-lite was)

---

## g) Questions

1. **Should I deploy now (`nix run .#deploy`)?** The cqrs-lint fix is committed and verified locally but NOT deployed to the live evo-x2 system. Deploying will activate cqrs-lint in systemPackages. There's always a small risk with deploys (service restarts, start-limit-hit). Do you want me to deploy, or will you do it yourself?

2. **Should the 4 go-cqrs-lite lock nodes be consolidated?** Root uses `go-cqrs-lite_3` (proper flake, rev `05d12c05`). crush-daily uses `go-cqrs-lite` (flake=false, stale rev `92d87145`). overview uses `go-cqrs-lite_4` (flake=false, same stale rev). discordsync uses `go-cqrs-lite_2` (flake=false, pinned rev `da745368`). Consolidating crush-daily and overview to follow root would eliminate the stale nodes, but risks vendorHash breakage in those consumers. Worth doing, or leave as-is?

3. **Should the stale `git insteadOf` rule be removed?** `url.git@github.com:.insteadof=https://github.com/` in global git config rewrites all HTTPS GitHub URLs to SSH. This caused nix to convert `github:` flake URLs to `ssh://git@github.com/` in lock entries (observed during this session). All LarsArtmann repos are public (except 4 in GOPRIVATE which use access-tokens). Removing the rule would prevent SSH-URL lock pollution but might affect other git workflows. Your call.

---

## Resolution (2026-07-30)

The cqrs-lint fix later **regressed** — commit `b0d76b68` wrongly reverted go-finding to a zero pseudo-version, breaking the build again. Re-fixed in `2026-07-29_22-01` (`649bcd5f` upstream). cqrs-lint v0.2.2 builds and is deployed. The go-cqrs-lite lock was cleaned (4 stale nodes consolidated in `2026-07-29_17-01`). The `git insteadOf` rule was removed (`2026-07-29_17-01`) then **restored on user demand** (`2026-07-30_15-53`, `502020e7`) — it remains in effect.
