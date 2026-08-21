# BuildFlow GOEXPERIMENT=jsonv2 Fix — Silent Empty Binary Output

**Date:** 2026-07-08 08:45
**Session focus:** Diagnose and fix missing `buildflow` binary from PATH

---

## Executive Summary

`buildflow` was silently missing from the system PATH. The root cause was a layered chain: BuildFlow migrated to Go's experimental `encoding/json/v2` and `encoding/json/jsontext` packages (behind the `goexperiment.jsonv2` build constraint in Go 1.26.4), and the fix attempted to enable the experiment via `buildGoModule`'s `env` attr — but nixpkgs' `buildGoModule` silently drops unknown env vars. The result was an empty `/nix/store` output path: no binary, no error, just nothing. Fixed by moving `GOEXPERIMENT=jsonv2` to a `preBuild` shell export.

---

## a) FULLY DONE

1. **Diagnosed the missing buildflow binary** — `whereis buildflow` returned empty. Traced through the full chain: flake input → `lars-packages.nix` → `base.nix` systemPackages → nix eval confirmed buildflow IS in evaluated systemPackages → but `/run/current-system/sw/bin/buildflow` did not exist.

2. **Identified root cause via git archaeology** — Found commit `900b8712` (May 3) that removed 22 Go tool inputs including buildflow. But further investigation showed buildflow WAS re-added to `flake.nix` (line 296) and `lars-packages.nix` (line 17) with the new flake-input pattern (real flake inputs, not `flake = false` src + overlays). The flake input exists, `lars-packages.nix` references it, and it's in `flake.lock`. So the wiring was correct — the problem was the build itself.

3. **Found the build failure** — `nix log` on the buildflow derivation showed:

   ```
   imports encoding/json/jsontext: build constraints exclude all Go files
   imports encoding/json/v2: build constraints exclude all Go files
   FAIL github.com/larsartmann/buildflow/cmd/buildflow [setup failed]
   ```

   But `buildGoModule`'s `buildGoDir` function catches the "build constraints exclude all Go files" error and treats it as non-fatal (returns 0). So the build "succeeded" with exit code 0, but produced zero binaries.

4. **Identified the GOEXPERIMENT gap** — `encoding/json/v2` and `encoding/json/jsontext` exist in Go 1.26.4's stdlib but are behind `//go:build goexperiment.jsonv2`. They require `GOEXPERIMENT=jsonv2` to be set in the environment. BuildFlow's flake.nix had `env = { GOEXPERIMENT = "jsonv2"; }` in the `buildGoModule` call, but **nixpkgs' `buildGoModule` only forwards known Go env vars** (`CGO_ENABLED`, `GOWORK`, `GOFLAGS`, `GOTOOLCHAIN`, `GO111MODULE`, `GOARCH`, `GOOS`). Arbitrary env attrs like `GOEXPERIMENT` are silently dropped — they never reach the build sandbox.

5. **Fixed BuildFlow's flake.nix** — Moved `export GOEXPERIMENT=jsonv2` from `env {}` to the `preBuild` hook in both:
   - The `overrideModAttrs` preBuild (go-modules derivation — needed for `go mod tidy`)
   - The main `preBuild` (binary derivation — needed for `go build`)

   Committed as `0c3db8a` and pushed to `origin/master`.

6. **Fixed BuildFlow's pre-commit hook** — The `.git/hooks/pre-commit` runs `go build ./...` and `go vet ./...` across all workspace modules. Without `GOEXPERIMENT=jsonv2`, these fail on any module importing `encoding/json/v2`. Added `export GOEXPERIMENT=jsonv2` after `set -e`.

7. **Updated SystemNix flake.lock** — `nix flake lock --update-input buildflow` pulled revision `0c3db8a`. Committed as `8603e730`.

8. **Deployed to evo-x2** — `nix run .#deploy` showed `[A] buildflow 0c3db8a, +28.1 MiB` — buildflow ADDED to the system. Verified: `/run/current-system/sw/bin/buildflow --version` → `buildflow version 0c3db8a`.

---

## b) PARTIALLY DONE

1. **Other LarsArtmann Go tools with `env.GOEXPERIMENT` in buildGoModule** — BuildFlow's flake.nix has 5 new external tool packages (`branching-flow-bin`, `hierarchical-errors-bin`, `golangci-lint-auto-configure-bin`, `go-auto-upgrade-bin`, `oxlint-auto-configure-bin`) that use `env.GOPROXY` and `env.GOPRIVATE` in `buildGoModule`. These might also be silently dropped by nixpkgs, but none of them import `encoding/json/v2` so they may not need `GOEXPERIMENT`. However, `GOPROXY` and `GOPRIVATE` in `env` might also be dropped — needs verification. Their `vendorHash` is set to `lib.fakeHash`, so they haven't been built yet.

2. **BuildFlow uncommitted working tree changes** — The BuildFlow repo has 12 modified files and 2 untracked files that are NOT part of my commit. These are the user's in-progress work (nix-checker diagnosis/repair, vendor inconsistency, external analysis tools, nix_hash_fix). I left them untouched.

3. **Pre-commit hook template** — I patched `.git/hooks/pre-commit` directly, but this is an auto-generated hook (`buildflow precommit install`). The generator code should also be updated so re-installation doesn't lose the `GOEXPERIMENT` export. Not done.

---

## c) NOT STARTED

1. **SystemNix AGENTS.md update** — Should document the `buildGoModule` env attr gotcha: nixpkgs' `buildGoModule` silently drops unknown `env` attrs. Only known Go env vars are forwarded. Use `preBuild` `export` for anything else. This is a critical non-obvious gotcha that could bite any LarsArtmann Go tool package.

2. **BuildFlow AGENTS.md update** — Should document that `GOEXPERIMENT=jsonv2` is required for all Go commands (build, vet, test, mod tidy) because the codebase imports `encoding/json/v2` and `encoding/json/jsontext`.

3. **SystemNix pre-deploy-check** — The post-deploy smoke test failed with `bash: .../deploy/bin/post-deploy-check.sh: No such file or directory`. This is a separate bug in the deploy script (the `SCRIPT_DIR` issue mentioned in AGENTS.md). Not investigated.

4. **BuildFlow `go.mod` version** — The `go.mod` says `go 1.26.4` but uses experimental stdlib packages. When Go 1.27 ships, `encoding/json/v2` and `jsontext` may graduate from experiment to stable, and the `GOEXPERIMENT` flag may become unnecessary or even cause warnings. Should track and remove when appropriate.

5. **Other 21 Go tools removed in commit `900b8712`** — Only buildflow was re-added. The audit found 16 Go CLIs and 6 Go libraries were "built in overlays but never installed." Some may have been re-added individually by later commits, but this was not verified in this session.

---

## d) TOTALLY FUCKED UP

1. **The original `env` approach in BuildFlow's flake.nix** — Setting `GOEXPERIMENT = "jsonv2"` in `buildGoModule`'s `env` attr was a silent no-op. nixpkgs' `buildGoModule` only forwards a hardcoded set of Go env vars to the build sandbox. The `env` attr in `buildGoModule` is NOT the same as `mkShell`'s `env` or `runCommand`'s attributes — it's filtered. This produced a **silent empty binary** — the worst possible failure mode: no error, no crash, exit code 0, just nothing in `/nix/store`. The `buildGoDir` helper in nixpkgs catches "build constraints exclude all Go files" and treats it as non-fatal, so even the build "succeeded." This could have gone undetected for weeks.

2. **The deploy that "succeeded" before the fix** — The first `nix run .#deploy` in this session "succeeded" (exit 0, 0 failed units) but buildflow was NOT in the system closure. The empty store path was substituted and activated. The deploy script's post-deploy smoke test is supposed to catch this, but it was broken (`post-deploy-check.sh: No such file or directory`), so the silent failure went undetected.

---

## e) WHAT WE SHOULD IMPROVE

1. **`buildGoModule` env attr filtering is a critical gotcha** — nixpkgs should either forward all env attrs or fail loudly on unknown ones. Silent dropping is the worst behavior. Until upstream fixes this, all LarsArtmann `buildGoModule` calls should use `preBuild` `export` for non-standard Go env vars, not the `env` attr.

2. **`buildGoDir` silently swallows "build constraints exclude all" errors** — This nixpkgs function catches the exact error that indicates a completely broken build and treats it as non-fatal. This is by design (for packages with optional build tags), but it means a misconfigured `GOEXPERIMENT` produces a silent empty output instead of a build failure. There should be a post-build assertion that the output binary exists.

3. **Post-deploy smoke test is broken** — `post-deploy-check.sh` is not found at the expected path. This is a known issue (AGENTS.md mentions `SCRIPT_DIR` problems), but it means the safety net that should catch silent deployment failures is non-functional. This is how a missing binary went undetected.

4. **No binary-existence assertion after `buildGoModule`** — `buildGoModule` should verify that at least one binary was produced when `subPackages` is set. An empty `$out/bin/` after a "successful" build is always a bug.

5. **Pre-commit hook doesn't set GOEXPERIMENT** — BuildFlow's pre-commit hook runs `go build` and `go vet` without `GOEXPERIMENT=jsonv2`, causing every commit to fail on `encoding/json/v2` imports. Fixed manually in `.git/hooks/pre-commit`, but the generator should be updated.

6. **5 new `*-bin` packages in BuildFlow use `lib.fakeHash`** — These packages (`branching-flow-bin`, `hierarchical-errors-bin`, etc.) have `vendorHash = lib.fakeHash` and have never been built. They will fail on first real build attempt. Should compute real vendor hashes.

7. **5 new `*-bin` packages use `env.GOPROXY` and `env.GOPRIVATE`** — These env attrs are likely also silently dropped by `buildGoModule`, same as `GOEXPERIMENT` was. If these tools need proxy configuration, it should be done via `preBuild` export.

8. **`flake.lock` now has 5 new BuildFlow sub-inputs** — The SystemNix flake.lock grew by 6 new input nodes (branching-flow, go-auto-upgrade, golangci-lint-auto-configure, hierarchical-errors, oxlint-auto-configure). These are BuildFlow's own flake inputs being transitively locked. This adds resolution overhead but is correct behavior.

9. **AGENTS.md should document the GOEXPERIMENT requirement** — Both SystemNix and BuildFlow AGENTS.md files should note that `GOEXPERIMENT=jsonv2` is required for BuildFlow and any project using `encoding/json/v2`.

---

## f) Up to 50 Things to Get Done Next

| #  | Priority | Task                                                                                                                                                                                                       | Impact                         |
| -- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| 1  | P0       | **Fix `post-deploy-check.sh` path in deploy script** — smoke test is non-functional, silent failures go undetected                                                                                         | Critical safety net            |
| 2  | P0       | **Add binary-existence assertion to deploy smoke test** — verify `buildflow` and other critical binaries exist in `/run/current-system/sw/bin/` after deploy                                               | Catches silent empty outputs   |
| 3  | P0       | **Update SystemNix AGENTS.md** — document `buildGoModule` env attr filtering gotcha (only known Go env vars forwarded; use `preBuild` export for others)                                                   | Prevents repeat                |
| 4  | P0       | **Update BuildFlow AGENTS.md** — document `GOEXPERIMENT=jsonv2` requirement for all Go commands                                                                                                            | Prevents repeat                |
| 5  | P1       | **Compute real `vendorHash` for 5 new `*-bin` packages in BuildFlow** — currently `lib.fakeHash`, will fail on first build                                                                                 | Unblock external tool packages |
| 6  | P1       | **Verify `env.GOPROXY`/`env.GOPRIVATE` in 5 `*-bin` packages actually work** — likely silently dropped by `buildGoModule` same as `GOEXPERIMENT`                                                           | Prevents silent build failures |
| 7  | P1       | **Update BuildFlow pre-commit hook generator** — the `buildflow precommit install` command should include `export GOEXPERIMENT=jsonv2` in generated hooks                                                  | Prevents re-introduction       |
| 8  | P1       | **Commit remaining BuildFlow working tree changes** — 12 modified files (nix-checker, vendor inconsistency, external tools) are uncommitted user work                                                      | User decision                  |
| 9  | P1       | **Run `nix flake check --no-build` on SystemNix** — verify no eval regressions from the flake.lock update                                                                                                  | Validation                     |
| 10 | P1       | **Run `nix flake check --no-build` on BuildFlow** — verify no eval regressions from the flake.nix changes                                                                                                  | Validation                     |
| 11 | P2       | **Audit all `buildGoModule` calls in SystemNix and BuildFlow** — check for other `env` attrs that are silently dropped                                                                                     | Preventive                     |
| 12 | P2       | **Add a post-build check to SystemNix deploy** — verify that all packages in `larsPackages` produce non-empty `$out/bin/`                                                                                  | Defense in depth               |
| 13 | P2       | **Track Go 1.27 release** — when `encoding/json/v2` graduates from experiment, remove `GOEXPERIMENT` flag                                                                                                  | Future cleanup                 |
| 14 | P2       | **Verify all 13 `larsPackages` tools are actually installed** — run `nix-store --query --requisites /run/current-system` and check each tool's binary exists                                               | Catch other silent failures    |
| 15 | P2       | **Check if `go-auto-upgrade` builds** — it's in `lars-packages.nix` and was removed in `900b8712` but re-added later; verify it actually produces a binary                                                 | Same class of bug              |
| 16 | P2       | **Check if `library-policy` builds** — same concern as above                                                                                                                                               | Same class of bug              |
| 17 | P2       | **Check if `md-go-validator` builds** — same concern as above                                                                                                                                              | Same class of bug              |
| 18 | P2       | **Check if `project-meta` builds** — same concern                                                                                                                                                          | Same class of bug              |
| 19 | P2       | **Check if `projects-management-automation` builds** — same concern                                                                                                                                        | Same class of bug              |
| 20 | P2       | **Check if `go-structure-linter` builds** — same concern                                                                                                                                                   | Same class of bug              |
| 21 | P2       | **Check if `hierarchical-errors` builds** — same concern                                                                                                                                                   | Same class of bug              |
| 22 | P2       | **Document `buildGoDir` silent-swallow behavior in SystemNix AGENTS.md** — nixpkgs catches "build constraints exclude all Go files" and treats as non-fatal                                                | Awareness                      |
| 23 | P2       | **Add `GOEXPERIMENT=jsonv2` to SystemNix devShell** — if any SystemNix Go tool needs json/v2                                                                                                               | Preventive                     |
| 24 | P3       | **Consider a `goTools` overlay helper** — centralize `GOEXPERIMENT` and other env exports for all LarsArtmann Go tool `buildGoModule` calls                                                                | DRY                            |
| 25 | P3       | **Add a CI check that all `larsPackages` produce non-empty outputs** — catch silent build failures automatically                                                                                           | Automation                     |
| 26 | P3       | **Consider adding `GOEXPERIMENT` to `buildGoModule`'s known env vars upstream** — file a nixpkgs PR to forward `GOEXPERIMENT`                                                                              | Ecosystem improvement          |
| 27 | P3       | **Update BuildFlow `flake.nix` `*-bin` packages to use `preBuild` export for `GOPROXY`/`GOPRIVATE`** — same fix pattern as `GOEXPERIMENT`                                                                  | Preventive                     |
| 28 | P3       | **Add `go.mod` `toolchain` directive to BuildFlow** — explicitly pin the Go version to avoid mismatched toolchain downloads                                                                                | Reproducibility                |
| 29 | P3       | **Verify `nix fmt` passes on both repos** — treefmt + alejandra on SystemNix, BuildFlow's formatter on BuildFlow                                                                                           | Code quality                   |
| 30 | P3       | **Push SystemNix commit to origin** — `8603e730` is local-only; push when ready                                                                                                                            | Sync                           |
| 31 | P3       | **Consider `GOEXPERIMENT` in Standup-Killer** — Standup-Killer's `go.work` includes modules that may import json/v2; verify its build works                                                                | Cross-project                  |
| 32 | P3       | **Audit the 22 tools removed in commit `900b8712`** — verify which were re-added and which are still missing; determine if any should be restored                                                          | Completeness                   |
| 33 | P3       | **Add `GOEXPERIMENT=jsonv2` to `go.work` workspace `go` directive** — Go workspace may need experiment flag at workspace level                                                                             | Correctness                    |
| 34 | P3       | **Check if `templ` build tool needs `GOEXPERIMENT`** — templ generates Go code that might use json/v2                                                                                                      | Preventive                     |
| 35 | P4       | **Document the chicken-and-egg problem** — BuildFlow's pre-commit hook requires `buildflow` to be installed, but `buildflow` can't be installed until it builds; document the `--no-verify` bootstrap path | Onboarding                     |
| 36 | P4       | **Consider a `buildflow` health check in Gatus** — verify buildflow is installed and functional via a system-level check                                                                                   | Monitoring                     |
| 37 | P4       | **Review BuildFlow's `preparedSrc` and `mkPreparedSource`** — ensure GOEXPERIMENT is passed through the source preparation phase                                                                           | Correctness                    |
| 38 | P4       | **Check if `go mod tidy` in `preBuild` actually needs `GOEXPERIMENT`** — it might not, since tidy resolves modules not build tags                                                                          | Precision                      |
| 39 | P4       | **Consider nixpkgs `buildGoModule` `allowGoReference`** — not related to this fix but worth reviewing for LarsArtmann tools that need to reference Go's source                                             | Future                         |
| 40 | P4       | **Verify Darwin build of buildflow** — `lars-packages.nix` filters by system; check if buildflow builds on `aarch64-darwin`                                                                                | Cross-platform                 |

---

## g) Top 2 Questions

### 1. Should the 5 new `*-bin` packages in BuildFlow's flake.nix be committed and wired into SystemNix?

BuildFlow's working tree added 5 external LarsArtmann tool packages (`branching-flow-bin`, `hierarchical-errors-bin`, `golangci-lint-auto-configure-bin`, `go-auto-upgrade-bin`, `oxlint-auto-configure-bin`) with `vendorHash = lib.fakeHash`. These are NOT built yet and will fail on first attempt. Some of these tools (branching-flow, go-auto-upgrade, hierarchical-errors) are ALREADY in SystemNix's `lars-packages.nix` as separate flake inputs. Are these `*-bin` packages meant to replace the SystemNix-level wiring, or are they BuildFlow-internal devShell tools? If the former, there's a duplication; if the latter, the `fakeHash` needs to be resolved before they're useful.

### 2. Should we add a post-deploy binary existence check to catch silent empty `buildGoModule` outputs?

The root cause of this entire incident was a "successful" nix build that produced zero binaries — and a "successful" deploy that activated a system missing the binary. The post-deploy smoke test was supposed to catch this, but `post-deploy-check.sh` was broken. Should we (a) fix the existing `post-deploy-check.sh` path issue, (b) add a new assertion that verifies every package in `larsPackages` has a non-empty `$out/bin/`, or (c) both? The `buildGoDir` silent-swallow behavior means this class of bug will recur whenever a Go experiment flag or build tag is misconfigured.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
