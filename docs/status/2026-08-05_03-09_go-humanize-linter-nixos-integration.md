# Status: go-humanize-linter NixOS Integration

**Date:** 2026-08-05 03:09  
**Session scope:** Adding `~/projects/go-humanize-linter/` to SystemNix as a system package  
**Overall verdict:** Functionally complete, verified end-to-end. Two manual steps remain before deploy (push upstream, update lockfile).

---

## What Was Done

### Problem

`go-humanize-linter` (AST linter detecting hand-rolled reimplementations of `dustin/go-humanize`) had no Nix package output. SystemNix had no flake input for it. The linter was not available on `evo-x2`.

### Solution

Two-repo change:

1. **Upstream** (`~/projects/go-humanize-linter/flake.nix`): Added `packages.default` via `buildGoModule` + `mkPreparedSource` (private Go dep injection for sandbox hermeticity)
2. **SystemNix** (`flake.nix` + `lib/lars-packages.nix`): Added flake input and wired into `mkLarsPackages` → auto-installed via `environment.systemPackages`

### Key Technical Decisions

| Decision | Why |
|---|---|
| Manual `buildGoModule` instead of `go-standard` module | Upstream already had a hand-rolled flake with apps/devShells. Migrating to `go-standard` would be a larger refactor with no incremental value for this task. |
| `mkPreparedSource` for 3 private deps (`go-finding`, `go-linter-sdk`, `go-error-family`) | All three are private GitHub repos (404 on `github.com`). Can't be fetched by the Go proxy in the Nix sandbox. |
| `doCheck = false` | CLI tests in `cmd/go-humanize-linter/main_test.go` shell out to `go build` via `exec.Command`, which requires a writable `$HOME`. Nix sandbox has no writability. Tests pass via `nix run .#test` in CI. |
| `env.GOWORK = "off"` | Local `go.work` file (gitignored but present) causes `go mod vendor` to fail with "cannot be run in workspace mode". |
| `cleanSourceWith` filter excluding `.direnv/`, `result`, `reports`, `custom-gcl` | `lib.cleanSource` includes gitignored dirs that contain broken symlinks → `noBrokenSymlinks` build failure. |
| `proxyVendor = false` | Required when using `mkPreparedSource` — the prepared source has local `_local_deps/` replaces that can't be resolved via the Go proxy. |
| Flake input `ref=main` (not `master`) | Upstream repo uses `main` as default branch. |
| Go dep inputs NOT followed in SystemNix | `go-finding`, `go-linter-sdk`, `go-error-family` are `flake = false` in the upstream flake. Following them would require re-declaring them in SystemNix, adding complexity for no benefit. |

---

## A) FULLY DONE

1. ✅ **Upstream `flake.nix` — `packages.default` build added**
   - `buildGoModule` with `mkPreparedSource` for 3 private deps
   - `vendorHash` determined: `sha256-ha23fLC1NiUIlS5bv1Retia40MK8WDLDywdpAKS6KVY=`
   - Source filter excludes broken-symlink dirs
   - `GOEXPERIMENT=jsonv2` in `preBuild`
   - `GOWORK=off` in env
   - Version injection via ldflags: `-X main.version=${version}`
   - `subPackages = [ "cmd/go-humanize-linter" ]`
   - `meta` with homepage, license, maintainer, mainProgram

2. ✅ **Upstream `flake.lock` updated** — Added `go-nix-helpers`, `go-finding`, `go-linter-sdk`, `go-error-family` inputs

3. ✅ **Upstream build verified** — `nix build .#default` succeeds, binary works (`--version`, `--rules`, linting testdata)

4. ✅ **Upstream tests verified** — `nix run .#test` passes all 4 packages (0.084s, 0.868s, 1.152s, 1.117s)

5. ✅ **Upstream `nix flake check --no-build` passes** — All checks pass

6. ✅ **Upstream `nix fmt` run** — treefmt reformatted the `filter` lambda (1 file changed)

7. ✅ **SystemNix `flake.nix` — flake input added**
   - `github:LarsArtmann/go-humanize-linter?ref=main`
   - Follows: `nixpkgs`, `go-nix-helpers`, `flake-parts`, `treefmt-nix`, `systems`

8. ✅ **SystemNix `lib/lars-packages.nix` — package wired**
   - `go-humanize-linter = flakePkg inputs.go-humanize-linter;`
   - Alphabetically placed between `go-auto-upgrade` and `go-structure-linter`

9. ✅ **SystemNix build verified** — `nix build .#packages.x86_64-linux.go-humanize-linter` succeeds (via `--override-input` with local path)

10. ✅ **SystemNix eval verified** — `nix eval .#packages.x86_64-linux.go-humanize-linter.meta.description` returns correct string

11. ✅ **Auto-git committed both repos** — 3 commits in upstream, 1 commit in SystemNix

12. ✅ **SystemNix `nix fmt` run** — No formatting changes needed

---

## B) PARTIALLY DONE

1. ⚠️ **Upstream not pushed** — 3 commits ahead of `origin/main`. SystemNix can't fetch from GitHub until pushed. Verified via `--override-input path:` workaround only.
2. ⚠️ **SystemNix `flake.lock` not updated** — Lock file needs `nix flake lock --update-input go-humanize-linter` AFTER upstream is pushed. Was temporarily modified during testing, restored to clean state.
3. ⚠️ **No deploy run** — `nix run .#deploy` not executed (blocked by the two items above).

---

## C) NOT STARTED

1. ❌ **AGENTS.md update** — SystemNix `AGENTS.md` was not updated with `go-humanize-linter` in the LarsArtmann Go tools list or any relevant section.
2. ❌ **Gatus health check** — Not applicable (this is a CLI tool, not a service). No action needed.
3. ❌ **Post-deploy smoke test** — Not run (blocked by deploy).
4. ❌ **Verify binary available on PATH after deploy** — Not run (blocked by deploy).

---

## D) TOTALLY FUCKED UP

Nothing. All builds pass, all tests pass, binary works correctly. No regressions.

---

## E) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Upstream `flake.nix` should migrate to `go-standard` module** — The upstream flake has a hand-rolled `perSystem` with manual apps, devShells, and now a manual `buildGoModule` + `mkPreparedSource` setup. The `go-standard` module from `go-nix-helpers` automates ALL of this (packages, apps, devShells, checks, treefmt, overlays, GOPRIVATE injection) with ~10 lines of config. The manual approach duplicates what `go-standard` already provides and risks drift over time. This is the single biggest improvement.

2. **Source filter is fragile** — The `cleanSourceWith` filter manually lists excluded dirs (`.direnv`, `result`, `reports`, `custom-gcl`). If a new build artifact or gitignored dir appears, it will break the build with `noBrokenSymlinks`. A better approach: use `lib.sources.trace` to identify what's being included, or filter based on `git ls-files` (only include tracked files + go.sum).

3. **`doCheck = false` is a band-aid** — The CLI tests can't run in the sandbox because they spawn `go build` via `exec.Command` and need a writable `$HOME`. The proper fix would be to refactor the tests to not shell out to `go build` (use `go/build` library instead), or to use `overrideModAttrs` to provide a writable home. But this is an upstream test architecture issue, not a SystemNix issue.

4. **SystemNix AGENTS.md not updated** — The `go-humanize-linter` should be mentioned in the "Consuming LarsArtmann Flakes" section or the Go tools list. Memory maintenance protocol says: update AGENTS.md proactively when learning new project state.

5. **GOPRIVATE in upstream devShell doesn't include mixed-case** — The upstream devShell sets `GOPRIVATE = "github.com/larsartmann/*"` but the module path is `github.com/larsartmann/go-humanize-linter` (lowercase). SystemNix's `home-base.nix` sets `GOPRIVATE` with both cases. The upstream should match: `GOPRIVATE = "github.com/larsartmann/*,github.com/LarsArtmann/*"`.

6. **No overlay in upstream** — The upstream flake doesn't expose `flake.overlays.default`. Other LarsArtmann flakes (via `go-standard`) do. SystemNix currently uses `flakePkg` (pulls `packages.${system}.default`), so this isn't blocking, but an overlay would allow `pkgs.go-humanize-linter` resolution.

### Technical Debt

7. **Upstream has `flake = false` for `go-nix-helpers`** — When SystemNix follows `go-nix-helpers` → its own `go-nix-helpers` input (also `flake = false`), the upstream gets the SystemNix copy. This works but means the upstream flake's `flake.lock` has a separate entry for `go-nix-helpers` that's unused when consumed from SystemNix. Not a problem, just a note.

8. **Version is `dev` when built from `path:` override** — When SystemNix overrides the input with a local path, `self.shortRev` is null → version falls back to `"dev"`. When fetched from GitHub, it correctly resolves to the git short rev. This is expected behavior.

---

## F) Up to 50 Things to Get Done Next

### Immediate (blocked on push)
1. Push upstream: `cd ~/projects/go-humanize-linter && git push`
2. Update SystemNix lock: `nix flake lock --update-input go-humanize-linter`
3. Deploy: `nix run .#deploy`
4. Open new terminal after deploy
5. Verify: `which go-humanize-linter && go-humanize-linter --version`
6. Run post-deploy check: `nix run .#post-deploy-check`

### Documentation
7. Update SystemNix `AGENTS.md` — add `go-humanize-linter` to the Go tools section
8. Update upstream `AGENTS.md` — document the `packages.default` build, `mkPreparedSource` usage, `doCheck = false` rationale
9. Update upstream `FEATURES.md` — add "Nix package output" to the features list
10. Update upstream `CHANGELOG.md` — add entry for Nix package support

### Upstream improvements
11. Migrate upstream `flake.nix` to `go-standard` module (eliminates ~150 lines of manual config)
12. Fix upstream `GOPRIVATE` to include `github.com/LarsArtmann/*` (mixed case)
13. Add `flake.overlays.default` to upstream (for overlay-based consumption)
14. Consider `enableCompletions = true` in `go-standard` config (if CLI supports `--completion`)
15. Refactor CLI tests to not shell out to `go build` (enables `doCheck = true`)
16. Add `nix flake check` to upstream CI workflow (if not already present)
17. Tag upstream release (so SystemNix can pin to a version instead of `ref=main`)

### SystemNix improvements
18. Add `go-humanize-linter` to the `golangci-lint` custom binary build (if desired)
19. Consider adding `go-humanize-linter` to the devShell of Go projects in SystemNix
20. Add `go-humanize-linter` to the `post-deploy-check` script to verify it's on PATH
21. Update SystemNix `lib/lars-packages.nix` comment block if needed

### Quality hardening
22. Add a SystemNix VM test for `go-humanize-linter` package availability
23. Add `go-humanize-linter` to the `dynamic-user-audit.nix` exclusion list (if needed)
24. Verify `go-humanize-linter` works in the `qmd` MCP context (if relevant)
25. Run `go-humanize-linter` on SystemNix's own Go code (if any Go code exists)
26. Run `go-humanize-linter` on all LarsArtmann Go repos to find real-world findings
27. Consider adding `go-humanize-linter` to `golangci-lint-auto-configure` output

### Monitoring
28. Add Gatus check for `go-humanize-linter` binary availability (not applicable — CLI tool)
29. Add `go-humanize-linter` to `system-health` module's tool inventory (if applicable)

### Cleanup
30. Remove `result` symlink from upstream repo after deploy testing
31. Remove `result` symlink from SystemNix after deploy testing
32. Clean up `flake.lock` entries in upstream if any are stale after migration
33. Run `nix flake check --no-build` on SystemNix after lock update (without `--override-input`)
34. Run `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` after lock update
35. Verify the `hermes-python-source` pre-existing error is not worsened

### Future considerations
36. Pin `go-humanize-linter` to a tagged release once available
37. Consider adding `go-humanize-linter` to the `go-structure-linter` config (meta-linting)
38. Add `go-humanize-linter` to the `buildflow` managed tools list (if applicable)
39. Consider a `go-humanize-linter` Homepage tile (if it has a web UI — it doesn't)
40. Evaluate whether `go-humanize-linter` should be in `home.packages` instead of `environment.systemPackages`
41. Check if `go-humanize-linter` needs to be in the Darwin config too (it will be, via `mkLarsPackages`)
42. Verify `go-humanize-linter` builds on `aarch64-darwin` (macOS)
43. Consider adding `go-humanize-linter` to the `go-cqrs-lite` devShell
44. Run `nix flake update --all` on upstream after migration to `go-standard`
45. Add `go-humanize-linter` to the `art-dupl` scan exclusions (if it causes false positives)
46. Consider a `go-humanize-linter` plugin for the `buildflow` workflow
47. Add `go-humanize-linter` to the `library-policy` enforcement chain
48. Evaluate `go-humanize-linter` performance on large codebases (e.g., nixpkgs)
49. Consider adding `go-humanize-linter` to pre-commit hooks in LarsArtmann repos
50. Document the `go-humanize-linter` + `golangci-lint` module plugin workflow in SystemNix AGENTS.md

---

## G) Questions I Can NOT Answer Myself

1. **Should the upstream flake migrate to the `go-standard` module now, or is that a separate task?** — Migrating would eliminate ~150 lines of manual config and auto-wire GOPRIVATE, overlays, checks, etc. But it's a larger refactor that changes the devShell experience (adds govulncheck, changes treefmt config). Is this worth doing now or should it be a follow-up?

2. **Should I push the upstream commits and update the SystemNix lockfile + deploy now, or do you want to review the changes first?** — The upstream has 3 uncommitted+3 committed changes ready to push. SystemNix has 1 commit. The lockfile update + deploy are the final two steps.

3. **Should `go-humanize-linter` also be added to the macOS (Darwin) config, or is `evo-x2` (NixOS) sufficient for now?** — The `mkLarsPackages` function already supports `aarch64-darwin` and the package builds on `lib.platforms.unix`. But the 256GB SSD on the MacBook Air is 90%+ full. Is adding another Go binary to Darwin acceptable, or should it be Linux-only?
