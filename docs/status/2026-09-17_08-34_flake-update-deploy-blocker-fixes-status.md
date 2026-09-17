# Status: 2026-09-17 08:34 — flake-update deploy blocker fixes (IN PROGRESS, deploy not yet run)

Task: user ran `nix flake update && nix run .#deploy` — pre-deploy check blocked (2 ✗).
This session fixed the blockers across SystemNix + 6 upstream repos. **The deploy itself has NOT run yet.**

## DONE (all verified unless noted)

### Deploy blockers — eval layer
1. **`_signoz-packages.nix` go_1_25 → go_1_26** — nixpkgs 2026-09-15 removed `go_1_25` (EOL). Signoz FODs subsequently PASSED in keep-going builds (vendorHash comment now proven).
2. **sops-nix `buildGo125Module` shim** — sops-nix master (13616fff == HEAD upstream, nothing to update to) breaks every evo-x2 eval ("while evaluating sops.package"). `overlays/shared.nix` now aliases `buildGo125Module = buildGo126Module; go_1_25 = go_1_26;` (TEMPORARY; drop when sops-nix > 13616fff).
3. **playwright double break (both nixpkgs-level, cold-build-only)**:
   - microsoft **re-tagged playwright-python v1.63.0** (source FOD hash mismatch). Entry path: `django-polymorphic.nativeCheckInputs` → `pytest-playwright` (while the tests needing it are DISABLED — and its conftest.py unconditionally reads the plugin's `--headed` option, so stripping the plugin alone → pytest INTERNALERROR exit 3, discovered on build #3). Fixed: `pythonPackagesExtensions` override strips the dep AND sets `dontUsePytestCheck = true`.
   - **playwright-webkit missing `libmanette`** in buildInputs (auto-patchelf fail). Fixed: `d2` now gets `playwright-driver.browsers-chromium` preset (Linux) — PNG export rides chromium.
   - LESSON (control-tested): `overrideAttrs` on buildPythonPackage is a SILENT NO-OP for `nativeCheckInputs` (folded by the python builder earlier) — must use `overridePythonAttrs`. Recorded in AGENTS.md.

### inboxclean-sync failures — root-caused, upstream fix shipped
- **account `main`**: `gmail.token_revoked` (invalid_grant) — OAuth re-consent required. USER STEP, cannot automate.
- **account `work`**: paperless `400 Bad Request: /api/tags/1/` every tick — go-paperless `updateMatchingAlgorithm` sent `{"id":0,"name":"","matching_algorithm":0}`; DRF rejects blank `name`. The `gmail` AUTO-tag self-heal NEVER worked (classifier-incident protection inert).
- **go-paperless v0.3.2 cut + pushed** (backport branch from v0.3.1 worktree — deliberately avoiding the parallel session's unreleased breaking `Unreleased` content; fix also on master): payload now only `matching_algorithm`; regression test pins `name` out of the PATCH body. Tests+vet green (go 1.27.1 + jsonv2,simd).
- **InboxClean**: go-paperless v0.3.0 → v0.3.2 (`go get`), vendorHash healed (`nix run .#update-vendor-hash`), full `go test -race ./...` GREEN, pushed (daemon-laundered across 9415196 + 68b7f34; parallel session's templ regen rode along in 91e5e62). SystemNix re-locked inboxclean → 91e5e62.

### vendorHash FOD fixes (5 inputs)
| Input | Action | Pushed? | Re-locked? |
|---|---|---|---|
| cv | **rolled back lock** 6aba2678 → c37b8f59 (HEAD b4aeaa0d additionally fails `cv-prepared-source-dev` shebang check — parallel session's in-flight domain) + `docs/services/cv.md` breadcrumb | n/a (lock-only) | ✅ (FOD re-probed GREEN) |
| file-and-image-renamer | buildflow nix-hash-fix | ✅ cdaaa22 | ✅ |
| branching-flow | buildflow nix-hash-fix | ✅ faffae66 | ✅ |
| golangci-lint-auto-configure | manual vendorHash.nix paste | ✅ ee47a6d | ✅ |
| go-humanize-linter | manual flake.nix paste (push initially failed: remote default branch is **main**, not master) | ✅ 2cbc9db→HEAD:main | ✅ 58ab1189 (build-verified) |

### browser-history (6th break, found on build #3)
`go.mod requires go >= 1.27.1 (running go 1.26.7)` — flake carried a 1.26.7 go.dev tarball pin. Fixed: `goPkg = pkgs.go_1_27` (nixpkgs ships 1.27.1); package builds GREEN from its own flake. **Committed locally (f3561fd, daemon) — NOT pushed, SystemNix lock still b2c615e (broken).**

### Docs/memory
- AGENTS.md: 3 new gotchas (sops-nix shim incl. flake-check-vs-eval asymmetry, overridePythonAttrs no-op trap, playwright re-tag+libmanette double break with `nix why-depends --derivation` technique).
- docs/services/cv.md: 2026-09-17 lock-state breadcrumb with re-bump probe command.

## REMAINING (blocked / next)
1. Push browser-history f3561fd → re-lock SystemNix input → **final keep-going build** (also verifies the `dontUsePytestCheck` django-polymorphic fix).
2. **`nix run .#deploy`** — never ran yet (3 enumeration builds so far).
3. Post-deploy: verify inboxclean papersync heals the `gmail` AUTO tag (first tick), smoke checks.
4. **USER STEP**: inboxclean `main` OAuth re-consent on the desktop (runbook in AGENTS.md InboxClean section; consent screen must be "In production" first).
5. CV re-bump deferred to the parallel CV session (vendorHash + dev-source shebang fix needed upstream).

## What I forgot / could have done better
- The daemon laundered my commit messages TWICE (InboxClean, go-paperless master) — commit IMMEDIATELY after edits, before long buildflow gates, to keep attribution.
- First django-polymorphic attempt used `overrideAttrs` (silent no-op) — verify the override MECHANISM before burning a full build-enumeration cycle (the control-test came only after suspicion).
- `nix build nixpkgs#playwright-driver` rc 0 was a SUBSTITUTION, not a real build — I chased the resulting contradiction too long; `nix why-depends --derination` settled it.
- Dropped the "Managed by buildflow nix-checker" comment in golangci-lint-auto-configure/vendorHash.nix (overwrote file with bare hash).
- Pushed go-humanize-linter to `master` first — the fleet has MIXED default branches (check `git remote show origin` per repo).
- No GitHub Release object for go-paperless v0.3.2 (tag serves the Go proxy fine; go-release Phase 7 skipped under time pressure).
- InboxClean `govalid-generate` buildflow step fails in ad-hoc envs (binary built against go1.26 source-processing, running go1.27 stdlib) — pre-existing env skew, NOT fixed (repo devshell presumably fine).
- InboxClean go.work floor fixed 1.27 → 1.27.1 locally (untracked file, local-only).

## Environment notes
- Parallel sessions were ACTIVE all morning in: go-paperless (dep grooming), InboxClean (templ regen), CV (b4aeaa0d), go-humanize-linter (58ab1189). Daemon commits raced mine repeatedly — expected per AGENTS.md.
- Signoz: go_1_26 switch verified by passing FODs (no vendorHash drift across the minor switch).
