# Status Report: project-meta flake follows cleanup & self-review

**Date:** 2026-08-11 10:27 CEST
**Session focus:** Fix Nix flake evaluation error caused by stale `project-meta` flake input follows overrides.
**Working tree:** `flake.nix` modified (2 deletions); no other changes.
**Head commit:** `e1c085a0` — `chore(flake): refresh nixpkgs and convert go-nix-helpers to a flake input`

---

## a) FULLY DONE

1. **Removed stale `systems` and `treefmt-nix` follows overrides from `project-meta` flake input.**
   - Upstream `project-meta` migrated to `go-nix-helpers.flakeModules.go-standard` and no longer declares `systems` or `treefmt-nix` as direct inputs.
   - SystemNix was still overriding them, producing:
     - `warning: input 'project-meta' has an override for a non-existent input 'systems'`
     - `warning: input 'project-meta' has an override for a non-existent input 'treefmt-nix'`
   - **Evidence:** `git diff` shows removal of those two lines from `flake.nix`.

2. **Verified flake evaluation is clean.**
   - `nix flake check --no-build` → `all checks passed!`
   - `nix build '.#nixosConfigurations.evo-x2.config.system.build.toplevel' --dry-run` → evaluates and lists system derivations without input-related warnings or errors.

3. **Ran formatter.**
   - `nix fmt` → formatted 1 file, 0 changed (no formatting drift introduced).

4. **Refreshed lock for `project-meta`.**
   - `nix flake lock --update-input project-meta` completed without errors; lock file did not materially change because the resolved input graph already matched the corrected flake.nix.

---

## b) PARTIALLY DONE

1. **Identifying other potentially stale follows overrides across LarsArtmann Go tool inputs.**
   - `project-meta` was the only input producing warnings during this session, but the same migration pattern (`go-standard` flake module dropping direct `systems`/`treefmt-nix`) could apply to other inputs: `library-policy`, `crush-daily`, `mr-sync`, `branching-flow`, `overview`, `discordsync`, `browser-history`, `md-go-validator`, `go-structure-linter`, `go-cqrs-lite`.
   - **What works:** No current warnings or errors from these inputs.
   - **What remains:** Proactive audit to catch the next one before it breaks evaluation. Not done.
   - **Blocker:** None; just scope.
   - **Estimated effort:** Small (15–30 min to run `nix flake check` while removing each follows pair, but could cascade if upstreams differ).

2. **Confirming `project-meta` actually produces a usable binary.**
   - `flake.nix` evaluates it via `lib/lars-packages.nix` (`flakePkg inputs.project-meta`).
   - **What works:** Derivation evaluates (`/nix/store/...-meta-95f9051...drv`).
   - **What remains:** Did not run `nix build .#project-meta` or verify `/nix/store/.../bin/` contents.
   - **Blocker:** None.
   - **Estimated effort:** Small (5 min).

---

## c) NOT STARTED

1. **Apply the same follows-cleanup pattern to other migrated inputs.**
   - Only done reactively for `project-meta`. Others will break one-by-one as their upstreams migrate to `go-standard` unless audited.

2. **Build and smoke-test the `project-meta` package.**
   - Historical issue: `project-meta` was previously a silent build failure (missing from system closure). Evaluating the derivation is not enough.

3. **Run a full `nix run .#deploy` or equivalent activation.**
   - Only `--dry-run` was used. The actual rebuild/activation was not performed.

4. **Pin `go-nix-helpers` to a tag or explicit rev.**
   - It currently tracks `master` and is a build-time library consumed by many Go tools. AGENTS.md history notes this is a reproducibility risk.

5. **Improve the `go-nix-helpers` flake input comment.**
   - Current comment explains *why* it must remain a flake, but does not explain *that* upstream `project-meta` (and potentially others) consume `flakeModules.go-standard` from it. Could be clearer.

6. **Add a lint check that fails on stale follows overrides.**
   - Could be a small `nix flake check` pre-step or a script that greps `flake.nix` against `nix flake metadata` input lists.

7. **Update `TODO_LIST.md` / `ROADMAP.md` from this report.**
   - This report contains harvestable items for `docs-health` HARVEST mode.

---

## d) TOTALLY FUCKED UP!

1. **The stale follows overrides were committed and left in place.**
   - Severity: Low (warnings only, not a hard error). However, it is a process gap: upstream `project-meta` migrated, SystemNix did not update its follows list, and the warnings were tolerated until explicitly addressed.
   - Root cause: No automated check catches `non-existent input` warnings from `nix flake check`. The previous commit focused on converting `go-nix-helpers` back to a flake input and did not prune the now-obsolete `project-meta` follows.
   - Mitigation: Manual cleanup done. Add a lint/grep guard to prevent recurrence (see section f).

2. **I did not verify the actual artifact of the change.**
   - Severity: Low. I confirmed evaluation but not that `project-meta` builds and exposes a binary. This is the same class of bug that was flagged in earlier sessions (`project-meta` silent build failure).
   - Root cause: Scoped the session to fixing the evaluation warning and stopped at `--dry-run`.
   - Mitigation: Build the package explicitly next (see section f).

3. **Pre-existing unrelated evaluation warnings remain.**
   - `evaluation warning: 'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'`
   - `evaluation warning: 'hostPlatform' has been renamed to/replaced by 'stdenv.hostPlatform'`
   - `evaluation warning: zfs.latestCompatibleLinuxPackages is deprecated...`
   - `evaluation warning: boot.zfs.forceImportRoot is using the default value of true...`
   - `warning: The check omitted these incompatible systems: aarch64-darwin`
   - Severity: Low-to-Medium. Not caused by this session, but they pollute the signal-to-noise ratio of `nix flake check` and make it harder to spot real problems.
   - Root cause: Nixpkgs API drift and ZFS defaults.
   - Mitigation: None applied; out of scope for this session.

---

## e) WHAT WE SHOULD IMPROVE

1. **Automated stale-follows detection.**
   - `nix flake metadata --json` exposes the actual input graph. A small script could compare declared `inputs.X.inputs.*.follows` against the upstream flake's actual inputs and warn or fail in CI.
   - Impact: Prevents the exact `non-existent input` warning class from recurring across the large number of LarsArtmann Go tool inputs.

2. **Convert the `go-nix-helpers` input comment into a small doc block.**
   - Current comment at `flake.nix:267-268` is good but terse. It should mention that downstream consumers (`project-meta`, and potentially others) use `inputs.go-nix-helpers.flakeModules.go-standard`, which is why it cannot be `flake = false` even though it is also a Go library source.
   - Impact: Future agents/maintainers will not re-introduce `flake = false` to "save lock space."

3. **Pin `go-nix-helpers` to a tag or explicit rev with a comment.**
   - It is a build-time library; master drift can silently break `mkPreparedSource` behavior for all downstream Go packages. AGENTS.md history already flagged this in 2026-08-06.
   - Impact: Reproducibility. Avoids emergency vendorHash cascade fixes after a `nix flake update`.

4. **Always build the package after fixing its flake input.**
   - Evaluation success is not build success. The `project-meta` history specifically includes a "silent build failure" class. The verification step should include `nix build .#project-meta` and `ls -l result/bin/`.
   - Impact: Catches silent build/binary regressions immediately.

5. **Create a shared helper for LarsArtmann Go tool inputs that hides boilerplate follows.**
   - Many inputs repeat the same `nixpkgs`, `go-nix-helpers`, `flake-parts`, `treefmt-nix`, `systems` follows. A small function could reduce duplication and make future migrations easier.
   - Impact: Less manual churn when upstreams drop inputs.

6. **Add a flake check or pre-commit hook that fails on any `warning: input '...' has an override for a non-existent input`.**
   - These are currently warnings. Treating them as errors in CI would force cleanup at the same time upstreams migrate.
   - Impact: Zero tolerance for stale follows.

---

## f) Top 50 things we should get done next

(Ordered by impact, scoped to observations from this session. Items beyond ~25 are roadmap fuel, not immediate commitments.)

1. **Build and smoke-test `project-meta` binary.** — Impact: High / Effort: S / Category: Quality — Verify the silent-build-failure class is truly gone.
2. **Audit other LarsArtmann Go tool inputs for stale `systems`/`treefmt-nix` follows.** — Impact: High / Effort: M / Category: Cleanup — Prevent the next evaluation warning cascade.
3. **Add CI/pre-commit guard that fails on `non-existent input` warnings.** — Impact: High / Effort: M / Category: Quality
4. **Pin `go-nix-helpers` to a tag or explicit rev.** — Impact: High / Effort: S / Category: Quality
5. **Expand `flake.nix` comment for `go-nix-helpers` to explain downstream `flakeModules.go-standard` consumption.** — Impact: Medium / Effort: S / Category: Documentation
6. **Run full `nix run .#deploy` on evo-x2 to activate the cleaned flake.** — Impact: Medium / Effort: M / Category: Deployment
7. **Run `nix build` for all `larsPackages` after this change.** — Impact: Medium / Effort: M / Category: Quality — Catches cascading vendorHash issues.
8. **Harvest this report into `TODO_LIST.md` via `docs-health` HARVEST.** — Impact: Medium / Effort: S / Category: Documentation
9. **Replace repetitive follows boilerplate in `flake.nix` with a helper function.** — Impact: Medium / Effort: M / Category: Cleanup
10. **Address `system` → `stdenv.hostPlatform.system` deprecation warnings.** — Impact: Medium / Effort: S / Category: Cleanup
11. **Address `hostPlatform` → `stdenv.hostPlatform` deprecation warnings.** — Impact: Medium / Effort: S / Category: Cleanup
12. **Address `zfs.latestCompatibleLinuxPackages` deprecation warning.** — Impact: Medium / Effort: S / Category: Cleanup
13. **Explicitly set `boot.zfs.forceImportRoot` to silence warning.** — Impact: Low / Effort: S / Category: Cleanup
14. **Investigate whether `aarch64-darwin` can be re-included in `nix flake check`.** — Impact: Low / Effort: M / Category: Quality
15. **Verify `project-meta` upstream flake input graph is stable (no new dropped inputs).** — Impact: Medium / Effort: S / Category: Quality
16. **Add `nix flake lock --update-input project-meta` result to the commit if lock did change.** — Impact: Low / Effort: S / Category: Documentation — Already no-op, but document why.
17. **Review `go-nix-helpers` `flakeModules.go-standard` migration status across all consumers.** — Impact: Medium / Effort: M / Category: Cleanup
18. **Create a small test derivation that asserts `project-meta` has a non-empty `bin/` directory.** — Impact: Medium / Effort: M / Category: Quality
19. **Check if `project-meta` should be added to `environment.systemPackages` explicitly or remains via `larsPackages`.** — Impact: Low / Effort: S / Category: Cleanup
20. **Document the `project-meta` migration from manual follows to `go-standard` module in `CHANGELOG.md`.** — Impact: Low / Effort: S / Category: Documentation
21. **Consider whether `library-policy` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
22. **Consider whether `crush-daily` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
23. **Consider whether `mr-sync` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
24. **Consider whether `overview` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
25. **Consider whether `discordsync` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
26. **Consider whether `browser-history` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
27. **Consider whether `md-go-validator` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
28. **Consider whether `go-structure-linter` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
29. **Consider whether `go-cqrs-lite` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
30. **Consider whether `branching-flow` has already migrated and needs same cleanup.** — Impact: Medium / Effort: S / Category: Cleanup
31. **Add a `flake.nix` input lint to the `nix-check.yml` GitHub workflow.** — Impact: Medium / Effort: M / Category: Quality
32. **Update `docs/CONTRIBUTING.md` with the follows-override hygiene rule.** — Impact: Low / Effort: S / Category: Documentation
33. **Review the `flake.lock` churn caused by `go-nix-helpers` re-entering as a flake.** — Impact: Low / Effort: S / Category: Cleanup
34. **Check `darwin` configuration evaluation after the `go-nix-helpers` conversion.** — Impact: Medium / Effort: M / Category: Quality
35. **Check `rpi3-dns` configuration evaluation after the `go-nix-helpers` conversion.** — Impact: Low / Effort: M / Category: Quality
36. **Add a test that evaluates `nixosConfigurations.evo-x2.config.system.build.toplevel` in CI.** — Impact: High / Effort: M / Category: Quality
37. **Add a test that evaluates `darwinConfigurations.Lars-MacBook-Air.config.system.build.toplevel` in CI.** — Impact: Medium / Effort: M / Category: Quality
38. **Verify `nix flake check --all-systems` is practical or permanently omit Darwin.** — Impact: Low / Effort: M / Category: Quality
39. **Update `AGENTS.md` Go private repo / `go-nix-helpers` guidance if pinning changes.** — Impact: Low / Effort: S / Category: Documentation
40. **Look at whether `project-meta` should be tagged for reproducibility instead of tracking master.** — Impact: Low / Effort: S / Category: Quality
41. **Check if `git-hooks` input introduced by `project-meta` migration needs following in SystemNix.** — Impact: Low / Effort: S / Category: Cleanup
42. **Check if `project-meta` now pulls `git-hooks` and whether that creates duplicate lock entries.** — Impact: Low / Effort: S / Category: Cleanup
43. **Evaluate whether `go-nix-helpers` can be consumed as a flakeModule by SystemNix itself to reduce boilerplate.** — Impact: Low / Effort: L / Category: Feature
44. **Create an ADR or note in `docs/gotchas-archive.md` about the `go-nix-helpers` flake vs. non-flake toggle.** — Impact: Low / Effort: S / Category: Documentation
45. **Schedule a monthly audit of stale follows overrides.** — Impact: Low / Effort: S / Category: Process
46. **Consider pinning all LarsArtmann Go tool inputs to tags instead of master.** — Impact: Medium / Effort: L / Category: Quality
47. **Review whether `flake = false` Go libraries in `flake.nix` can be moved to a separate section to clarify they are not flake inputs.** — Impact: Low / Effort: S / Category: Cleanup
48. **Document the `nix flake lock --update-input X` no-op behavior when lock is already consistent.** — Impact: Low / Effort: S / Category: Documentation
49. **Add a `nix flake check` timing note to the status report template for future sessions.** — Impact: Low / Effort: S / Category: Process
50. **Harvest items 1–10 into `TODO_LIST.md` immediately.** — Impact: Medium / Effort: S / Category: Process

---

## g) Questions I cannot answer myself

1. **Should I proactively audit and clean up the other LarsArtmann Go tool inputs (`library-policy`, `crush-daily`, `mr-sync`, `overview`, `discordsync`, `browser-history`, etc.) for the same `systems`/`treefmt-nix` follows-override staleness right now, or only react when they produce warnings?**
   I can check whether they *currently* warn, but I cannot decide the project's preferred maintenance posture (aggressive cleanup vs. reactive).

2. **Do you want `project-meta` to be explicitly added to `environment.systemPackages` or is it sufficient that it flows through `larsPackages` / `specialArgs`?**
   Historical status reports noted `project-meta` was missing from the system closure. I did not verify this in the current tree; the answer depends on whether the package is intended as a user-facing CLI on evo-x2 and macOS.

3. **Should `go-nix-helpers` be pinned to an explicit rev or a tag, and if so, which one?**
   AGENTS.md history notes it has no release tags and that tracking master is a reproducibility risk. I cannot determine the correct version or whether tagging should happen upstream first.

---

## Verification log from this session

```text
$ nix flake check --no-build
all checks passed!
warning: The check omitted these incompatible systems: aarch64-darwin

$ nix build '.#nixosConfigurations.evo-x2.config.system.build.toplevel' --dry-run
… listed system derivations without input warnings/errors …

$ nix fmt
formatted 1 files (0 changed) in 2m58.691s

$ git diff --stat
 flake.nix | 2 --
 1 file changed, 2 deletions(-)
```

---

*Report written at 2026-08-11 10:27 CEST. Next step: harvest items 1–10 into `TODO_LIST.md` if session continues.*
