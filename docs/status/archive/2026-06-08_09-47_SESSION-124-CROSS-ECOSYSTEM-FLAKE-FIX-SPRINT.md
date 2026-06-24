# Session 124 — Cross-Ecosystem Flake Fix Sprint & Build Audit

**Date:** 2026-06-08 09:47
**Session Duration:** ~2.5 hours
**Status:** PARTIAL SUCCESS — `nix flake update` works; `nh os boot` blocked by pre-existing issues

---

## Executive Summary

The user attempted `nix flake update -v && nh os boot . -v` which failed due to **8 upstream private repos** with broken `flake.nix` files. All 8 were identified, fixed, committed, and pushed. `nix flake update` now succeeds. However, `nh os boot` still fails due to **two pre-existing build issues** that existed before this session.

---

## A) FULLY DONE ✅

### 1. Fixed 8 Upstream Repositories (all pushed to master/fork)

| Repo | Commit | Root Cause | Fix |
|------|--------|------------|-----|
| `art-dupl` | `9772d8b` | Duplicate `checks.build` (dot-notation + attrset) | Merged into single `checks` attrset |
| `branching-flow` | `70d2a53` | `goPkg` undefined + `checks.format` outside `perSystem` | Added `goPkg = pkgs.go_1_26`, moved checks into perSystem |
| `crush-config` | `c031f05` | Duplicate `checks` + `nixfmt.enable` (wrong path) | Consolidated checks, fixed to `programs.nixfmt.enable`, removed invalid `self` arg |
| `go-structure-linter` | `b32aa65` | `goPkg` undefined + duplicate checks | Used `pkgs.go_1_26` directly, merged checks |
| `golangci-lint-auto-configure` | `014c3f6` | `checks.format/checks.build` outside `perSystem` | Moved into perSystem checks attrset |
| `mr-sync` | `6de046b` | `goPkg` undefined + duplicate checks + `_prev` overlay bug | Fixed all three |
| `todo-list-ai` | `5e9705e` | `checks.format` outside `perSystem` + `nixfmt.enable` | Removed external checks, fixed treefmt path |
| `treefmt-full-flake` | `d286160` | `checks.format` referencing undefined `self` | Removed (treefmt `flakeCheck` auto-creates it) |

### 2. Three Recurring Anti-Patterns Identified

These 8 repos shared only 3 root causes:

1. **`checks` outside `perSystem`** — `config` and `self` are perSystem-scoped in flake-parts, not module-scoped. Writing `checks.format = config.treefmt.build.check self;` at module level fails.
2. **Duplicate `checks` definitions** — Using dot-notation (`checks.format = ...; checks.build = ...;`) followed by an attrset (`checks = { build = ...; };`) causes "attribute already defined".
3. **`goPkg` undefined** — Referenced in `mkPreparedSource` or devShells but never declared.

### 3. SystemNix `nix flake update` Succeeds

All inputs evaluate cleanly. `nix flake check --no-build` passes.

### 4. Tracked `crush-daily.yaml` Secret

`platforms/nixos/secrets/crush-daily.yaml` was untracked (blocked by `.gitignore` `secrets*` pattern). Force-added with `git add -f`.

### 5. Staged Discordsync Integration (Pre-existing Work)

The following were already on-disk but uncommitted from a prior session:
- `flake.nix`: discordsync flake input
- `modules/nixos/services/discordsync.nix`: NixOS module
- `modules/nixos/services/sops.nix`: discordsync secrets + env template

---

## B) PARTIALLY DONE ⚠️

### `nh os boot` — Blocked by Pre-existing Issues

The build fails but **these failures existed BEFORE this session's changes** (verified by stashing flake.lock and testing old lock):

| Issue | Root Cause | Severity |
|-------|-----------|----------|
| `project-meta` inconsistent vendoring | `project-discovery-sdk` bumped v0.4.0→v0.5.1 upstream, vendor/modules.txt stale | **BLOCKING** |
| sops manifest validation | `openai_api_key` not found in `hermes.yaml` secret | **BLOCKING** (old lock too) |

Both are pre-existing and unrelated to the 8 flake fixes.

---

## C) NOT STARTED ⬜

1. **Fix project-meta vendoring** — requires updating `project-discovery-sdk` subModules in project-meta's mkPreparedSource, then regenerating vendorHash
2. **Fix hermes sops secret** — `openai_api_key` missing from encrypted hermes.yaml
3. **Wire discordsync into configuration.nix** — module exists but not enabled
4. **Verify discordsync actually builds** — overlay added but not tested
5. **Create discordsync sops secret file** — `platforms/nixos/secrets/discordsync.yaml` doesn't exist yet

---

## D) TOTALLY FUCKED UP 💥

### 1. Eight Repos Broken Simultaneously

All 8 private LarsArtmann repos had broken `flake.nix` files that prevented `nix flake update`. This means no successful flake update has been possible since these repos were last modified. The root cause is a systematic pattern: someone (likely an AI assistant across sessions) added `checks` outside `perSystem` or duplicated them, and `goPkg` was referenced but never defined.

### 2. Secret File Never Tracked

`platforms/nixos/secrets/crush-daily.yaml` was created in commit `480dcb74` but never `git add -f`'d past the gitignore. This means the **old lock was also broken** — the sops module references a file that doesn't exist in git.

### 3. Pre-existing Build Has Been Broken For A While

Both old and new flake.lock fail `nh os boot`. The system hasn't had a clean build in at least 2+ days.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### 1. Prevent `checks` Outside `perSystem`
Add a lint check or CI gate that catches `checks.*` defined at module level in flake-parts. Pattern: `checks\.format|checks\.build` outside a `perSystem` block.

### 2. Standardize `goPkg` Pattern
Create a shared helper or convention: `goPkg = pkgs.go_1_26;` should always be defined in `perSystem`'s `let` block, not at module level. Document in AGENTS.md or a shared template.

### 3. treefmt `programs.*` Namespace
The correct path is `programs.nixfmt.enable`, not `nixfmt.enable`. Multiple repos had this wrong. Consider a lint or template.

### 4. Gitignore vs Sops Secrets
The `secrets*` pattern in `.gitignore` blocks `platforms/nixos/secrets/`. Either:
- Add `!platforms/nixos/secrets/` exception, or
- Document that sops files need `git add -f`

### 5. CI for Private Repos
None of these breakages would have been caught by CI since the repos lack CI pipelines that run `nix flake check`. Adding `checks = { build = ...; format = ...; }` to each repo helps but only if CI runs.

### 6. Dep Cache / Vendor Hash Automation
The `project-discovery-sdk` vendoring issue shows that when upstream Go deps change, the Nix vendorHash becomes stale silently. Consider a daily/weekly CI job that sets `vendorHash = ""` and checks if the build still works.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical (Build Blocking)

1. **Fix project-meta vendoring** — `project-discovery-sdk` v0.4.0→v0.5.1 mismatch. Update `subModules` in project-meta's mkPreparedSource, regenerate vendorHash.
2. **Fix hermes sops secret** — Add `openai_api_key` to `platforms/nixos/secrets/hermes.yaml` (or remove from sops config if key no longer needed).
3. **Deploy with `nh os boot`** — Once the above two are fixed, redeploy.

### Discordsync Integration

4. **Create `discordsync.yaml` sops secret** — Encrypt Discord token, Turso URL, Turso auth token.
5. **Enable discordsync in `configuration.nix`** — `services.discordsync.enable = true;`
6. **Test discordsync overlay builds** — Verify `pkgs.discordsync` resolves.
7. **Verify discordsync service starts** — After deploy, check `systemctl status discordsync`.

### Build Reliability

8. **Add `!platforms/nixos/secrets/` to `.gitignore`** — Prevent future untracked-secret surprises.
9. **Add CI `nix flake check` to all 8 fixed repos** — Prevent regressions.
10. **Standardize `goPkg` in all Go repo flakes** — Convention: always `let goPkg = pkgs.go_1_26; in` inside perSystem.
11. **Audit remaining private repos for same patterns** — Check all `git+ssh://` inputs for checks/goPkg issues proactively.
12. **Add `programs.nixfmt.enable` lint** — Catch `nixfmt.enable` without `programs.` prefix.

### Service Health

13. **Verify all services running after deploy** — `systemctl --failed` check.
14. **Check gatus health endpoints** — All services should report healthy.
15. **Verify sops secrets decrypted correctly** — Check sops manifest validation.
16. **Test DNS resolution** — Unbound + dnsblockd should be functional.
17. **Verify GPU headroom** — OLLAMA_GPU_OVERHEAD still set, niri stable.

### Darwin Parity

18. **Test `nix flake check` on Darwin** — Ensure fixed repos don't break macOS eval.
19. **Check Darwin disk space** — 256GB SSD at 90%+ full, flake.lock update may need cleanup first.
20. **Run `nix-collect-garbage` on Darwin** — Preemptively free space.

### Documentation & Process

21. **Update AGENTS.md** — Add gotcha about `checks` outside `perSystem`, `programs.nixfmt` prefix, `goPkg` convention.
22. **Archive old status reports** — `docs/status/` has 350+ files, many very old. Consider pruning.
23. **Create ADR for flake-parts perSystem scoping** — Document what's available where.
24. **Template `flake.nix` for new Go repos** — Prevent these patterns from recurring.
25. **Schedule weekly `nix flake update` dry-run** — Catch upstream breakage early.

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT

**Is `project-discovery-sdk` supposed to be bumped from v0.4.0 to v0.5.1 in project-meta's go.mod?**

The vendor inconsistency shows `project-discovery-sdk` at v0.4.0 in vendor but v0.5.1 in go.mod. I cannot determine whether:
- Someone updated `go.mod` to v0.5.1 intentionally and forgot `go mod vendor`, OR
- The `mkPreparedSource` `subModules` list needs updating for new v0.5.1 submodules (e.g., `cache`, `enrichment/repoinfo`)

This requires domain knowledge about what changed in project-discovery-sdk between those versions.

---

## Files Changed This Session

### SystemNix (staged, not yet committed)
- `flake.lock` — Updated all inputs
- `flake.nix` — Added discordsync input (from prior session)
- `modules/nixos/services/sops.nix` — Added discordsync secrets (from prior session)
- `modules/nixos/services/discordsync.nix` — New NixOS module (from prior session, untracked)
- `platforms/nixos/secrets/crush-daily.yaml` — New sops secret (force-added)

### External Repos (all committed and pushed)
- `art-dupl`, `branching-flow`, `crush-config`, `go-structure-linter`, `golangci-lint-auto-configure`, `mr-sync`, `todo-list-ai`, `treefmt-full-flake`

---

## Build Verification

```
$ nix flake check --no-build
all checks passed!

$ nix flake update
(success — all inputs updated)

$ nh os boot
FAILS — project-meta vendoring + sops manifest (pre-existing)
```
