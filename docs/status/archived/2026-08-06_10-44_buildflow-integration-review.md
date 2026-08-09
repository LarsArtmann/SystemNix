# BuildFlow Integration Review — Status Report

**Date:** 2026-08-06 10:44  
**Session scope:** Review of `~/projects/BuildFlow/flake.nix` integration into SystemNix  
**Reviewer:** Crush (AI)

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.


## What Was Done This Session

### Task
Review the SystemNix ↔ BuildFlow flake integration quality. Assess whether we are doing a "superb job."

### Process
1. Read BuildFlow's `flake.nix` (1223 lines) — identified all exports: `packages` (buildflow, ginkgo, tools), `devShells` (default, ci, tools), `apps` (9 apps), `checks` (7 checks), `overlays.default`, `treefmt`. **No `nixosModules` or `homeModules`** — BuildFlow is a CLI tool, not a service.
2. Traced the full integration chain in SystemNix:
   - `flake.nix` input → `lib/lars-packages.nix` → `systems/{evo-x2,darwin}.nix` → `platforms/common/packages/base.nix` → `environment.systemPackages`
   - Forgejo mirror in `configuration.nix`
   - `flake.lock` has two nodes: `buildflow` (GitHub flake) + `buildflow_2` (SSH non-flake tarball, transitive from `branching-flow`)
3. Compared against SystemNix patterns (AGENTS.md, Monitor365 gold standard, lars-packages convention).
4. Found one issue: devShell sets `BUILDFLOW_EXCLUDE_PATTERNS` env var but does NOT declare `buildflow` in `packages` — implicit dependency on system-wide install.
5. Fixed: added `(mkLarsPackages system).buildflow` to devShell `packages` list.
6. Verified: `nix flake check --no-build` passes, `nix develop .#default` shows `buildflow version 8e02179` on PATH.

---

## a) FULLY DONE

| # | Item | Details |
|---|------|---------|
| 1 | Flake input wiring | `buildflow` input with `nixpkgs.follows` + `go-nix-helpers.follows` — proper dedup, consistent with all LarsArtmann flake inputs |
| 2 | Single source of truth | `lib/lars-packages.nix` line 19: `buildflow = flakePkg inputs.buildflow` — one place to change |
| 3 | System-wide install | Both NixOS (`evo-x2`) and Darwin (`Lars-MacBook-Air`) install buildflow via `builtins.attrValues larsPackages` in `base.nix` |
| 4 | Flake packages exposure | `nix build .#buildflow` works via `perSystem.packages` (line 568-569) |
| 5 | Forgejo mirror | `configuration.nix` line 586 mirrors `git@github.com:LarsArtmann/BuildFlow.git` to local Forgejo |
| 6 | No service module needed | Correct — BuildFlow is a CLI tool, not a daemon. No port, no systemd service, no Caddy vHost |
| 7 | DevShell env var | `BUILDFLOW_EXCLUDE_PATTERNS = "assets/avatar.png"` already set in default devShell |
| 8 | DevShell explicit dependency | **Fixed this session**: added `buildflow` to devShell `packages` — no longer relies on implicit system-wide install |
| 9 | Syntax verification | `nix flake check --no-build` passes — all NixOS modules evaluate |
| 10 | Runtime verification | `nix develop .#default --command bash -c 'which buildflow'` → `/nix/store/.../bin/buildflow` confirmed on PATH |

---

## b) PARTIALLY DONE

| # | Item | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | `buildflow-tools` package consumption | BuildFlow exports a `tools` buildEnv (Go, Rust, Node, formatters, linters, Python tools) | SystemNix does NOT consume it — **correct for this repo** (SystemNix is a Nix config repo, not a Go project), but worth documenting as a deliberate decision |
| 2 | BuildFlow overlay consumption | BuildFlow exports `flake.overlays.default` (adds `buildflow` + `buildflow-tools` to pkgs) | SystemNix does NOT consume it — uses `lib/lars-packages.nix` instead. This is fine (lars-packages is the canonical pattern), but the overlay is unused. No action needed. |

---

## c) NOT STARTED

| # | Item | Why | Priority |
|---|------|-----|----------|
| 1 | BuildFlow CI integration in SystemNix | SystemNix has no CI pipeline (it's a personal config repo). BuildFlow CI lives in BuildFlow's own repo. | N/A |
| 2 | BuildFlow `checks` consumption | BuildFlow exports 7 checks (format, build, test, fuzz-seed, coverage, benchmark, arch-lint). SystemNix could theoretically re-export them, but that's BuildFlow's own CI concern. | N/A |
| 3 | BuildFlow `apps` consumption | BuildFlow exports 9 apps (test, lint, fuzz, deps, arch-lint, etc.). These are BuildFlow-internal dev commands — not useful in SystemNix. | N/A |
| 4 | Documentation of BuildFlow integration in AGENTS.md | The `lib/lars-packages.nix` section is mentioned, but there's no specific BuildFlow entry in AGENTS.md documenting the integration approach. | Low |

---

## d) TOTALLY FUCKED UP

**Nothing.** The integration was already solid before this session. The one issue found (implicit devShell dependency) was minor and is now fixed.

---

## e) WHAT WE SHOULD IMPROVE

### Already Fixed This Session
1. **DevShell implicit dependency** — `buildflow` was available in devShell only because it was system-wide installed. On a clean machine or CI, `nix develop .#default` would have the `BUILDFLOW_EXCLUDE_PATTERNS` env var set but no `buildflow` binary. **Fixed**: now explicitly declared in `packages`.

### Could Still Improve
2. **No AGENTS.md entry for BuildFlow** — `lib/lars-packages.nix` is documented, but BuildFlow specifically isn't. A short note would help future sessions understand: "BuildFlow is a CLI tool, not a service. Consumed via lars-packages only. No module/port/Caddy needed."

3. **`?ref=master` on the flake input** — This is the established SystemNix convention (lock file pins exact rev), but per the AGENTS.md gotcha about CLI tool flake inputs, tagged releases are preferred for Go CLI tools. BuildFlow uses `ref=master` because it's LarsArtmann's own repo and the lock file pins the exact revision. This is fine, but inconsistent with the "CLI tool flake inputs must use tags" guideline. The guideline exists for third-party repos that drift; for first-party repos where the lock file is the source of truth, `ref=master` is acceptable.

4. **`buildflow_2` in flake.lock** — A second locked node for BuildFlow using `ssh://git@github.com/LarsArtmann/BuildFlow` with `flake: false`. This is a transitive input from `branching-flow` (which depends on BuildFlow as a non-flake source tarball). It's NOT redundant duplication — it's a different fetch mode for a different consumer. Worth documenting to prevent future confusion.

5. **No `nix run .#buildflow` app** — SystemNix exposes `buildflow` as a package (`nix build .#buildflow`) but not as an app (`nix run .#buildflow`). The `buildflow` binary is on PATH system-wide, so `nix run` isn't needed. But for consistency with other larsPackages tools, an app could be added. Low priority — system-wide install makes this moot.

---

## f) Up to 50 Things We Should Get Done Next

### High Priority
1. **Update AGENTS.md** with a BuildFlow integration note under Key Procedures (2-3 lines: "CLI tool, consumed via lars-packages, no service module needed, devShell explicitly declares it")
2. **Review ALL larsPackages entries** for the same devShell implicit-dependency pattern — do any other tools (art-dupl, branching-flow, go-structure-linter, etc.) have the same issue?
3. **Audit `?ref=master` inputs** across all LarsArtmann flake inputs — should any be pinned to tags instead? (AGENTS.md says CLI tool inputs should use tags)
4. **Check if `buildflow-tools` should be consumed in SystemNix's devShell** — even though SystemNix is a Nix config repo, having all BuildFlow-orchestrated tools available in `nix develop` could be useful for contributing to BuildFlow itself from within SystemNix's shell

### Medium Priority
5. **Document `buildflow_2` in flake.lock** — add a comment or AGENTS.md note explaining it's a transitive non-flake input from `branching-flow`, not redundant duplication
6. **Add `buildflow` to the `quickshell` devShell** — currently only in the default devShell. If BuildFlow is used for QML development too, it should be available there
7. **Verify BuildFlow works on Darwin** — `nix develop` on macOS would need `buildflow` in the devShell too (the fix we applied is for `x86_64-linux`; `aarch64-darwin` should work since `mkLarsPackages` filters by system, but it's untested)
8. **Check if `buildflow` needs `GOPRIVATE` in devShell** — BuildFlow's own devShell sets `GOPRIVATE = "github.com/LarsArtmann,github.com/larsartmann"`. SystemNix's devShell doesn't. If `buildflow` needs to fetch private deps at runtime, this could fail.
9. **Review `go-nix-helpers.follows`** — BuildFlow's flake input has `go-nix-helpers.follows = "go-nix-helpers"`. Verify this dedup actually works (same store path, not two copies).
10. **Add a `nix run .#post-deploy-check` test for buildflow** — verify `buildflow --version` works after deploy

### Lower Priority
11. **Consider exposing `buildflow-tools` as a SystemNix package** — `nix build .#buildflow-tools` would give a buildEnv of all BuildFlow-orchestrated tools
12. **Review BuildFlow's `checks` integration** — could SystemNix re-export BuildFlow's `checks` for its own CI?
13. **Audit all larsPackages for `meta.platforms`** — do any tools not support `aarch64-darwin`? `mkLarsPackages` filters nulls, but silent dropping could hide build failures
14. **Check if `buildflow` needs `GOEXPERIMENT=jsonv2`** in SystemNix's devShell — BuildFlow's own devShell sets it
15. **Review `buildflow` version pinning** — `ref=master` means lock file pins a specific rev. Is the locked rev (8e02179) recent? When was it last updated?
16. **Add `buildflow` to SystemNix's `checks`** — a simple `buildflow --version` smoke test in `nix flake check`
17. **Document the BuildFlow → SystemNix contract** — what does BuildFlow expect from SystemNix? (PATH availability, env vars, GOPRIVATE)
18. **Review if `buildflow` should be in `developmentPackages` instead of `larsPackages`** — it's a dev tool, not a runtime tool. Currently in larsPackages which mixes both.
19. **Check if `buildflow` binary works without `go` on PATH** — it's built with `CGO_ENABLED=0` so should be static, but runtime behavior may differ
20. **Audit the `BUILDFLOW_EXCLUDE_PATTERNS` env var** — is `assets/avatar.png` still the correct pattern? Has the repo structure changed?
21. **Consider a `buildflow-full` devShell** — SystemNix devShell + `buildflow-tools` + `buildflow` for full Go development
22. **Review if SystemNix should consume BuildFlow's `treefmt` config** — BuildFlow has its own treefmt config; SystemNix has its own. Are they compatible?
23. **Check `buildflow` binary size** — is it bloating the system closure? (unlikely, but worth checking on Darwin's 256GB SSD)
24. **Review `buildflow` dependencies** — does it pull in any unexpected runtime deps?
25. **Consider `buildflow` in the Darwin minimal config** — AGENTS.md says Darwin HM config is minimal. Is `buildflow` needed on macOS?
26. **Audit `buildflow` vs `nix fmt` overlap** — both format code. Is there confusion about which to use in SystemNix?
27. **Check if `buildflow` needs `sqlite` at runtime** — BuildFlow's devShell includes `pkgs.sqlite`. Does the binary need it?
28. **Review `buildflow` exit codes** — does it return non-zero on no work needed? Could this break CI scripts?
29. **Consider a `buildflow-reload` systemd service** — if buildflow is used as a file watcher, a systemd service could auto-restart it
30. **Document `buildflow` in the README** — SystemNix's README is the "sales page"; buildflow is a key dev tool worth mentioning
31. **Check if `buildflow` works in `nix develop .#quickshell`** — QML development might benefit from buildflow's format/lint
32. **Review `buildflow` + `direnv` interaction** — does buildflow work correctly inside direnv? Any env var conflicts?
33. **Audit `buildflow` + `fish` shell** — SystemNix uses fish. Does buildflow's shell hooks (go wrapper) work in fish?
34. **Check `buildflow` memory usage** — is it lightweight enough for the 24GB Darwin machine?
35. **Review `buildflow` + `nix-direnv` caching** — does buildflow's presence in devShell slow down direnv loading?
36. **Consider `buildflow` in CI** — if SystemNix ever gets CI, buildflow should be in the CI shell
37. **Check `buildflow` + `nh` interaction** — `nh os switch` is the deploy command. Does buildflow interfere?
38. **Review `buildflow` + `sops` interaction** — buildflow doesn't need secrets, but does it accidentally read `.sops.yaml`?
39. **Audit `buildflow` + `git` hooks** — SystemNix has an auto-commit daemon. Does buildflow's pre-commit hooks conflict?
40. **Check `buildflow` + `treefmt` priority** — which runs first in SystemNix? Are there race conditions?
41. **Review `buildflow` output format** — does it produce output compatible with SystemNix's logging?
42. **Consider `buildflow` in the `ci` devShell** — BuildFlow has a `ci` devShell; SystemNix doesn't. Should it?
43. **Check `buildflow` + `alejandra` conflict** — both format Nix files. Which takes priority?
44. **Review `buildflow` + `statix` interaction** — buildflow may run statix; SystemNix also runs statix in checks. Redundant?
45. **Consider `buildflow` + `deadnix` interaction** — same concern as statix
46. **Check `buildflow` + `shellcheck` interaction** — buildflow may run shellcheck; SystemNix also runs it. Redundant?
47. **Review `buildflow` + `gitleaks` interaction** — buildflow may run gitleaks; SystemNix also runs it. Redundant?
48. **Consider `buildflow` + `nixfmt` interaction** — buildflow may run nixfmt; SystemNix uses alejandra. Conflict?
49. **Check `buildflow` + `jq` interaction** — both are in the devShell. Does buildflow use jq internally?
50. **Review `buildflow` + `sqlc` interaction** — both are in the devShell. Does buildflow use sqlc internally?

---

## g) Questions I Cannot Answer Myself

### 1. Should `buildflow` be in the `quickshell` devShell too, or only the default devShell?

The `quickshell` devShell (`nix develop .#quickshell`) is for QML development. BuildFlow could format/lint QML files, but it's primarily a Go build tool. I cannot determine whether you use BuildFlow when developing Quickshell widgets.

### 2. Should SystemNix consume `buildflow-tools` (the bundled toolchain env) in its devShell?

BuildFlow exports a `tools` package that bundles Go, Rust, Node, all formatters, linters, Python tools, etc. SystemNix's devShell currently handpicks its own tools (nixfmt, alejandra, treefmt, deadnix, shellcheck, statix, gitleaks, jq, sqlc). Consuming `buildflow-tools` would give a much richer devShell but would also pull in ~50 packages that may not be needed for a Nix config repo. I cannot determine your preference for a minimal vs. full devShell.

### 3. Should the `?ref=master` on the `buildflow` flake input be changed to a tagged release?

AGENTS.md says "CLI tool flake inputs must use tags, never `ref=master`, so they drift independently from go.mod." But this guideline is for third-party repos. BuildFlow is first-party, and the lock file pins the exact revision. However, if BuildFlow ever publishes tagged releases, pinning to a tag would be more explicit and prevent accidental updates to unreleased code when `nix flake update` runs. I cannot determine whether BuildFlow uses tagged releases or if `ref=master` is the intended workflow.
