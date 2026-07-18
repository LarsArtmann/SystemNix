# Status: utoipa-swagger-ui PermissionDenied Build Fix

**Date:** 2026-07-17 12:24
**Session focus:** Fix `monitor365` build failure caused by `utoipa-swagger-ui` v9.0.2 build script panicking with `PermissionDenied` in the Nix sandbox

---

## a) FULLY DONE

1. **Root cause identified and proven** — `utoipa-swagger-ui` v9.0.2's build script calls `std::fs::copy(nix_store_zip, OUT_DIR/zip)`. Rust's `fs::copy` propagates source file permissions. Nix store files are always 0444 (read-only) after fixup. Crane's `buildDepsOnly` runs `cargo check --release` THEN `cargo build --release`, executing the build script twice in the same `OUT_DIR`. The first run creates a 0444 zip copy; the second run's `fs::copy` tries to truncate the existing 0444 file → `EACCES` (PermissionDenied). Proven with a minimal Nix sandbox reproduction test that showed `fs::copy` succeeds once, copies 0444 perms, then fails on the second attempt.

2. **Fix implemented** — `monitor365SwaggerUiFixOverlay` in `overlays/linux.nix:67` overrides the deps `buildPhase` to `find target -path '*/utoipa-swagger-ui-*/out/*.zip' -delete` between `cargo check` and `cargo build`. The overlay also rebuilds `monitor365-server` (symlinkJoin) to use the fixed CLI.

3. **Build verified** — `monitor365-deps` built successfully (7m22s), `monitor365` package built successfully (3m09s). The `utoipa-swagger-ui v9.0.2` crate compiled without PermissionDenied during both `cargo check` and `cargo build` phases.

4. **System evaluation verified** — `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.outPath` succeeds. `nix flake check --no-build` passes all checks.

5. **AGENTS.md updated** — Replaced the stale `monitor365MoldFixOverlay` entry (overlay was removed upstream on 2026-07-15) with the new `monitor365SwaggerUiFixOverlay` documentation.

6. **Nix formatting applied** — `nix fmt` ran successfully, formatted 28 files (25 changed).

---

## b) PARTIALLY DONE

1. **Full system deploy** — The build was verified at the package level (`monitor365-deps` + `monitor365` + `monitor365-server` all build). The full `nix run .#deploy` was NOT run (it would take 1h+ and requires user oversight). The dry-run shows only 23 lightweight derivations remaining (system wiring, not Rust builds).

2. **Upstream fix** — The root cause is in the upstream `utoipa-swagger-ui` crate (it should `fs::remove_file` before `fs::copy`, or use `fs::read`+`fs::write` instead of `fs::copy`). No upstream issue was filed or PR submitted — this is a downstream workaround only.

---

## c) NOT STARTED

1. **Upstream issue/PR** for `utoipa-swagger-ui` — should file an issue or PR at https://github.com/juhaku/utoipa to fix the `fs::copy` permission propagation bug in the build script
2. **Upstream monitor365 fix** — monitor365's `flake.nix` could also work around this by setting `doCheck = false` in `buildDepsOnly` (skipping `cargo check` entirely, eliminating the double-execution)
3. **Post-deploy smoke test** — `nix run .#post-deploy-check` was not run (no deploy performed)
4. **Stale `flake.lock` changes** — `flake.lock` shows as modified in `git status` from a prior session; not investigated or reverted (not our change)

---

## d) TOTALLY FUCKED UP

1. **First fix attempt (writable zip via `runCommand` + `chmod 0644`)** — Created a `runCommand` that copied the zip and ran `chmod 0644` on it, hoping the copy destination would retain writable permissions. This was **fundamentally wrong**: Nix's fixup phase resets ALL store paths to 0444 regardless of what `chmod` does in the builder. The build failed identically. Wasted ~10 minutes and a full 6+ minute compilation cycle on this approach before realizing the error.

2. **`pocketIdUpgradeOverlay` accidentally replaced** — When editing `overlays/linux.nix` the first time, the `old_string` included the entire `pocketIdUpgradeOverlay` definition, and the `new_string` replaced it with a placeholder (`pocketIdUpgradeOverlay = ...; # existing code unchanged`). This would have broken Pocket ID builds. Caught immediately by re-reading the file and fixing with a second edit.

3. **Stale `monitor365MoldFixOverlay` documentation** — The AGENTS.md entry for `monitor365MoldFixOverlay` said "Do NOT remove this overlay" but the overlay was already removed on 2026-07-15 (upstream fixed it). This stale doc could have misled a future session into re-adding the removed overlay. Fixed by replacing with the new swagger-ui fix entry.

---

## e) WHAT WE SHOULD IMPROVE

1. **Test Nix sandbox assumptions before implementing** — The first fix attempt assumed `chmod 0644` in a `runCommand` would produce a writable nix store path. This is a fundamental Nix misconception. Should have tested whether nix store paths retain custom permissions BEFORE building a full 6-minute compilation on top of that assumption.

2. **Consider upstream fixes over downstream overlays** — The overlay approach creates permanent maintenance burden. Filing an upstream PR to `utoipa-swagger-ui` (use `fs::remove_file` before `fs::copy`, or `fs::read`+`fs::write`) would fix this for everyone and eliminate the need for the overlay. The monitor365 upstream could also set `doCheck = false` in `buildDepsOnly`.

3. **Overlay pattern duplication** — The `monitor365-server` symlinkJoin rebuild is now duplicated from the upstream flake. Every time the upstream changes the `postBuild` script, this overlay must be manually synced. This is fragile.

4. **The `find ... -delete` approach is brittle** — It hardcodes the `utoipa-swagger-ui-*/out/*.zip` path pattern. If the crate version changes or the build script renames the output, the find command silently does nothing and the build fails again. A more robust approach would be to `rm -rf` the entire `target/release/build/utoipa-swagger-ui-*/out/` directory.

5. **Full system deploy not verified** — The fix was verified at the package level but not deployed. There could be systemd service wiring issues or runtime problems that only surface on deploy.

---

## f) Up to 50 Things We Should Get Done Next

### Priority 0 — Immediate

1. **Deploy the fix** — Run `nix run .#deploy` and verify the system boots with the fixed monitor365
2. **Run `nix run .#post-deploy-check`** — Verify monitor365 is functional after deploy
3. **Verify monitor365-server binary works** — Check that `monitor365-server --version` runs and serves the UI on port 3001

### Priority 1 — Upstream Fixes

4. **File upstream issue at juhaku/utoipa** — Report the `fs::copy` PermissionDenied bug with the reproduction steps from this session
5. **Submit upstream PR to utoipa-swagger-ui** — Replace `fs::copy(file_path, zip_path).unwrap()` with `fs::remove_file(&zip_path).ok(); fs::copy(file_path, &zip_path).unwrap()` or use `fs::read`+`fs::write`
6. **File upstream issue/PR at LarsArtmann/monitor365** — Suggest setting `doCheck = false` in `buildDepsOnly` as a workaround until utoipa-swagger-ui is fixed
7. **Remove `monitor365SwaggerUiFixOverlay`** once upstream utoipa-swagger-ui is fixed and monitor365 updates its dependency

### Priority 2 — Documentation & Cleanup

8. **Update `docs/status/2026-07-15_23-03_dns-mold-go-overlay-hack-removal.md`** — It lists "AGENTS.md cleanup — mold linker gotcha still references the overlay fix" as outstanding work. This is now done (entry replaced with swagger-ui fix). Mark it as resolved.
9. **Audit other overlays for stale `monitor365MoldFixOverlay` references** — Search for any remaining references to the removed mold overlay in docs, scripts, or tests
10. **Add a pre-commit check for stale AGENTS.md entries** — Entries that reference removed overlays/code should be detected automatically

### Priority 3 — Build Hardening

11. **Make the `find -delete` more robust** — Replace `find target -path '*/utoipa-swagger-ui-*/out/*.zip' -delete` with `rm -rf target/release/build/utoipa-swagger-ui-*/out/` to handle version changes
12. **Add a CI check that builds monitor365-deps** — Catch build failures before deploy, not during
13. **Consider `--option build-fallback false` for deploys** — Prevent partial builds from leaving the system in a broken state
14. **Add `nix build .#packages.x86_64-linux.monitor365-server` to pre-deploy-check** — Verify the monitor365-server package builds before attempting a full deploy

### Priority 4 — General SystemNix Improvements (noticed during this session)

15. **Stale `flake.lock` changes** — `flake.lock` shows as modified in `git status` from a prior session. Investigate whether these changes are intentional or stale.
16. **HTML docs reformatted by `nix fmt`** — 25 HTML files were reformatted by treefmt. These are generated/styled docs that shouldn't be tracked by treefmt. Consider excluding `docs/**/*.html` from the treefmt config.
17. **`nix fmt` touched 28 files** — The formatter reformatted many unrelated files. The treefmt config should be scoped to only relevant file types.
18. **The `monitor365-ui` package is NOT rebuilt by the overlay** — The overlay only rebuilds `monitor365` (CLI) and `monitor365-server` (symlinkJoin). The `monitor365-ui` (WASM dashboard) is passed through from `prev`. This is correct (UI doesn't use swagger-ui), but should be documented.
19. **Consider `overrideAttrs` vs `mkForce`** — The overlay uses `overrideAttrs` on `cargoArtifacts` which replaces the entire `buildPhase`. If the upstream changes the buildPhase (adds hooks, env vars), the overlay will silently drop them. Using `mkForce` or a more surgical approach would be safer.
20. **Add the swagger-ui zip hash to a variable** — The `sha256-SBJE0IEgl7Efuu73n3HZQrFxYX+cn5UU5jrL4T5xzNw` hash is hardcoded in the upstream flake. If it changes, the overlay's `fetchurl` will break. Since the overlay no longer uses `fetchurl` (the `runCommand` approach was removed), this is moot — but worth noting if the approach changes back.

### Priority 5 — Broader Observations

21. **Crane's `buildDepsOnly` double-execution is a known footgun** — Any build script with side effects that aren't idempotent will break. Document this pattern for future Rust+Nix work.
22. **Rust's `fs::copy` permission propagation is surprising** — Most developers don't expect `fs::copy` to copy permissions. This is documented in the Rust std docs but rarely read. Add to the gotchas table.
23. **The overlay rebuilds `monitor365-server` identically to upstream** — This is fragile duplication. Consider a `lib.fixup` helper that patches a specific attribute of a symlinkJoin without re-specifying the entire thing.
24. **The `nix fmt` reformatted many HTML files** — This is noise in the git diff. These should be excluded from treefmt.
25. **Consider adding `utoipa-swagger-ui` to a `doCheck = false` list** — If monitor365 adds more crates with similar build script issues, a general `doCheck = false` in `buildDepsOnly` would prevent all of them at once.
26. **The `find ... -delete 2>/dev/null || true` silently swallows errors** — If the find command itself fails (not just "no matches"), the error is hidden. Consider a more explicit error handling approach.
27. **Test the fix with a clean nix store** — The current build may have cached some intermediate results. A `nix-store --gc` followed by a full rebuild would verify the fix works from scratch.
28. **Consider a `post-deploy-check` test for swagger-ui** — Verify that the `/api-docs/` or `/swagger-ui/` endpoint actually serves the swagger UI after deploy.
29. **Monitor the upstream utoipa-swagger-ui releases** — When a new version fixes this, update the overlay to remove the workaround.
30. **The `monitor365-server` symlinkJoin name uses `prev.monitor365-server.name`** — This means the name changes when the upstream version changes. Verify this doesn't break the NixOS module's `package` reference.
31. **The overlay is Linux-only** — It's in `overlays/linux.nix`, so macOS won't get it. Monitor365 is Linux-only in SystemNix, so this is correct, but document it.
32. **The `cleanSwaggerZips` variable uses `''` (double single-quotes)** — This is Nix string interpolation context. The `find` command is shell, not Nix. Verify there are no Nix interpolation issues (there aren't — `${cleanSwaggerZips}` is used in a `''` string in `buildPhase`).
33. **The build took ~11 minutes total** — 7m22s for deps + 3m09s for the package. This is acceptable but slow. Consider sccache or caching strategies.
34. **The `cargoArtifacts.overrideAttrs` replaces `buildPhase` entirely** — This means any upstream changes to the buildPhase (e.g., adding `cargoWithProfile test --no-run`) will be lost. Consider using `preBuild`/`postBuild` hooks instead.
35. **The fix is specific to `utoipa-swagger-ui`** — If another crate has a similar issue, the fix won't help. Consider a more general approach (e.g., `find target -name '*.zip' -path '*/out/*' -delete` to clean ALL zip copies).
36. **The overlay doesn't set `SWAGGER_UI_DOWNLOAD_URL`** — The upstream `commonArgs` sets this env var. The overlay only overrides `buildPhase`. Verify the env var is still set correctly (it is — `overrideAttrs` only changes `buildPhase`, not env vars).
37. **Consider documenting the crane double-execution pattern** — Add a note to AGENTS.md about crane's `buildDepsOnly` running `cargo check` + `cargo build` and the implications for non-idempotent build scripts.
38. **The `nix flake check --no-build` passes** — But this only checks syntax, not build correctness. Consider `nix flake check` (with build) for critical changes.
39. **The fix was verified with `nix build`** — But not with `nix run .#deploy`. The deploy script may have additional checks or ordering constraints.
40. **The `flake.lock` changes from a prior session are still present** — These should be investigated and either committed or reverted.
41. **The HTML doc reformatting is pure noise** — 25 files changed by `nix fmt` that have nothing to do with the fix. These should be excluded or reverted.
42. **Consider scoping `nix fmt` to only changed files** — `nix fmt` reformats the entire tree. For a surgical change, consider running `nix fmt` only on `overlays/linux.nix` and `AGENTS.md`.
43. **The `monitor365-server` overlay duplicates the upstream `postBuild` script** — If the upstream adds steps (e.g., setting env vars, creating additional symlinks), the overlay will be out of sync. Consider a more targeted override.
44. **The fix doesn't handle the `monitor365-cli-fast` variant** — The upstream flake has a `monitor365-cli-fast` with `fastCargoProfile`. This is not used by SystemNix, but if it ever is, it will need the same fix.
45. **Consider adding a comment in the upstream monitor365 flake** — Suggesting `doCheck = false` in `buildDepsOnly` as a workaround.
46. **The `find -delete` pattern is case-sensitive** — If the crate name changes case (unlikely but possible), the find won't match. Use `-iname` for robustness.
47. **The overlay is applied AFTER `monitor365.overlays.default`** — This is correct (overlay ordering: upstream first, then patches). Document this dependency.
48. **The `monitor365-server` rebuild uses `prev.monitor365-ui`** — This means if the UI package changes, the overlay won't pick it up. Should use `final.monitor365-ui` (but monitor365-ui doesn't need the fix, so `prev` is fine — it avoids an unnecessary rebuild).
49. **Consider a `lib.warnIf` or `assert` to detect when the overlay is no longer needed** — If the upstream utoipa-swagger-ui fixes the bug, the `find -delete` will be a no-op. Adding a warning when no files are found would help identify when the overlay can be removed.
50. **The session took ~2 hours** — Most of it was build wait time. Consider using `nix build --max-jobs` or distributed builds to speed up future iterations.

---

## g) Questions I Cannot Answer Myself

1. **Should I file the upstream issue/PR for utoipa-swagger-ui, or do you prefer to handle upstream monitor365 interactions yourself?** — You own the LarsArtmann/monitor365 repo, so you may have your own process for upstream contributions to dependencies.

2. **The `flake.lock` shows as modified from a prior session — should I investigate/revert those changes, or are they intentional?** — The git status at conversation start showed `M flake.lock`. I didn't touch it, but it's in the working tree. I need to know if these are your changes or stale.

3. **Should I deploy now (`nix run .#deploy`), or do you want to review the overlay changes first?** — The build is verified at the package level, but a full deploy takes 1h+ and switches the running system. I don't want to deploy without your explicit go-ahead.
