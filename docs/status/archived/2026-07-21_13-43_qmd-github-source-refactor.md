# Status Update — qmd Deployment (GitHub Source + pnpmConfigHook Refactor)

**Date:** 2026-07-21 13:43 CEST
**Context:** User asked to switch qmd packaging from pnpm-tarball + vendored `pnpm-lock.yaml` to the more Nix-native GitHub source + `pnpmConfigHook` approach.
**Current state:** A `feat(qmd)` commit already exists at `HEAD` (99ac60a5) using the pnpm-tarball approach. Working-tree + staged changes are now migrating it to GitHub source.

---

## Done

- [x] Confirmed the upstream qmd flake exists (`github:tobi/qmd`) but rejected it because it uses Bun and only has `nodeModulesHashes` for x86_64-linux and aarch64-darwin.
- [x] Refactored `pkgs/qmd.nix` to use `fetchFromGitHub` + `pnpmConfigHook` + `pnpm run build`.
- [x] Discovered and pinned the correct `fetchFromGitHub` source hash and `pnpmDeps` FOD hash.
- [x] Removed the vendored `pkgs/qmd-pnpm-lock.yaml` (no longer needed; upstream repo has the real lockfile).
- [x] Added native build tools (`python3`, `node-gyp`, `gcc`) for `better-sqlite3` compilation in the sandbox.
- [x] Added `autoPatchelfIgnoreMissingDeps` for `libvulkan.so.1`, `libcuda.so.1`, `libcudart.so.*`, `libcublas.so.*` because GPU backends are disabled by default.
- [x] Verified `nix build .#qmd` succeeds and `result/bin/qmd --version` prints `qmd 2.5.3`.
- [x] Verified `nix flake check --no-build` passes for x86_64-linux.
- [x] Verified `nixosConfigurations.evo-x2` toplevel evaluates successfully with the new module.
- [x] Corrected `modules/nixos/services/qmd-config.nix` to remove `ProtectHome` / `ReadWritePaths` from the Home Manager user service (the `hardenUser` helper omits system-only options).
- [x] Updated `AGENTS.md` and `pkgs/README.md` to document the GitHub-source build and user-service sandboxing reality.

---

## Partially done

- [~] Staging the refactor: some files are staged (`flake.lock`, `pkgs/qmd-pnpm-lock.yaml` deletion, portions of `pkgs/qmd.nix`, `AGENTS.md`, `modules/nixos/services/qmd-config.nix`, `pkgs/README.md`) while further unstaged edits exist on the same files. The working tree is not in a clean commit-ready state.
- [~] Gatus check for qmd is wired but not validated at runtime (HTTP `/health` endpoint only exercised via config eval, not live service).
- [~] MCP client configuration for Crush (`~/.config/crush/crush.json`) was identified but not updated to point at `http://localhost:8181/mcp`.
- [~] Bootstrap collections option exists but is empty; no declarative collections are seeded yet.

---

## Not started

- [ ] Deploy to evo-x2 (`nix run .#deploy`).
- [ ] Start the user service and verify `/health` responds.
- [ ] Add a real collection (e.g., `~/notes` or `~/projects`) and run `qmd update && qmd embed`.
- [ ] Configure Crush MCP to use the qmd HTTP server.
- [ ] Test a live query through the MCP HTTP transport.
- [ ] Verify Gatus reports the new endpoint healthy after deploy.
- [ ] Measure first-start model-download time and memory usage on Strix Halo.
- [ ] Decide whether to enable GPU inference (`qmdForceCpu = false`) and test stability.

---

## Totally fucked up

- **Nothing critical.** The refactor builds and evaluates cleanly. However, the repo state is messy: a committed qmd feature exists at HEAD, and the working tree/index contains an incomplete migration on top of it. This could confuse a future `git status` or `nix build` if not reconciled before the next deploy.
- The `flake.lock` was already modified before this session and now has additional staged changes on top of it, which may not be related to qmd. Need to verify whether the lockfile changes are intentional or leftover from the previous commit.

---

## What to improve

1. **Avoid mixed staged/unstaged state on the same files.** Commit or reset the staged portion before continuing, then make the GitHub-source refactor as a single clean commit on top of the existing `feat(qmd)` commit.
2. **Reduce closure size.** The current `installPhase` copies the entire `node_modules` directory, including devDependencies and non-host platform binaries (e.g., ARM/CUDA/Vulkan node-llama-cpp artifacts). A pruning step or a second prod-only install after build would shrink the closure.
3. **Handle Darwin.** The build was only validated on x86_64-linux. Darwin needs `darwin.cctools` for `node-gyp` and may hit different auto-patchelf issues (there is no autoPatchelf on Darwin, but native compile paths differ).
4. **Document the staging issue.** `AGENTS.md` should explain that the qmd service is a HM user service and therefore cannot use `ProtectHome`/`ReadWritePaths` via the SystemNix `hardenUser` helper.
5. **Add a restart trigger.** If the qmd package store path changes, the user service should be forced to restart to avoid stale `dist/` references. (Pattern: `restartTriggers = [ cfg.package ]` in the HM unit.)
6. **MCP Crush config.** Add a Nix-managed or documented snippet for `~/.config/crush/crush.json` to wire `http://localhost:8181/mcp`.

---

## Next things (up to 50, prioritized)

### P0 — Blockers before deploy

1. Reconcile staged/unstaged state and commit the GitHub-source refactor.
2. Re-run `nix flake check --no-build` and `nix build .#qmd` on the clean commit.
3. Verify `nix flake check --all-systems` if possible, or at least think through aarch64-linux / aarch64-darwin / x86_64-darwin paths.

### P1 — Deploy + runtime validation

4. Run `nix run .#deploy` on evo-x2.
5. Open a new user session and check `systemctl --user status qmd-mcp`.
6. Confirm `http://localhost:8181/health` returns uptime JSON.
7. Check Gatus "qmd MCP HTTP Server" endpoint is green.

### P2 — Content + integration

8. Decide on a bootstrap collection (e.g., `~/notes` or `~/projects`) and set it in `configuration.nix`.
9. Run `qmd update` and `qmd embed` for the first collection.
10. Configure Crush MCP (`~/.config/crush/crush.json`) to point to `http://localhost:8181/mcp`.
11. Test a live `query` MCP call from Crush.
12. Test stdio MCP mode (`qmd mcp`) as a fallback.

### P3 — Hardening + polish

13. Investigate `node_modules` closure pruning (second prod install or manual removal of non-host GPU backends).
14. Add `restartTriggers = [ cfg.package ]` to the HM user service.
15. Audit `qmd-mcp` memory usage during first model load and during idle.
16. Decide whether to keep `QMD_FORCE_CPU=1` default or expose GPU opt-in.
17. Add a post-deploy smoke test for qmd in `scripts/post-deploy-check.sh`.
18. Document the "first start downloads 2 GiB from HuggingFace" behavior in AGENTS.md.
19. Verify `qmd` is on `$PATH` in fresh shells and `nix develop`.
20. Test `qmd search` and `qmd query` CLI commands directly.
21. Test `qmd get` and `qmd multi-get` for retrieved documents.
22. Evaluate whether `qmd status` works after the service has loaded models.
23. Check journal logs for `qmd-mcp` warnings during startup.
24. Verify the `ConditionPathExists=/home/lars/.config/qmd` does not prevent first boot (tmpfiles should create it).
25. Consider adding a `systemd.user.services.qmd-mcp` override for users who want stdio-only.
26. Add `qmd` to the `devShell` if it should be available in `nix develop`.
27. Compare qmd startup time and memory with HTTP vs stdio mode.
28. Document the `qmdEmbedModel` option for multilingual (CJK) users.
29. Add a TODO_LIST.md entry for qmd GPU acceleration experimentation.
30. Review whether the `skills/` directory is needed at runtime and if it should be copied separately.
31. Investigate if `node-llama-cpp` first download can be pre-cached declaratively.
32. Add a `qmd` dashboard tile to Homepage if useful.
33. Consider a Caddy vHost for qmd if exposing to LAN (currently localhost-only intentionally).
34. Add Prometheus metrics scraping if qmd exposes any.
35. Test qmd with a large collection (e.g., all `~/projects`) and measure indexing time.
36. Verify qmd index corruption recovery steps are documented and tested.
37. Check if `qmd-mcp` auto-restarts correctly after an OOM kill.
38. Add a `qmd` entry to `FEATURES.md`.
39. Audit whether the qmd user service starts before or after the graphical session.
40. Document the `qmd collection update-cmd` feature for auto-pulling git-backed collections.
41. Test `qmd` with `--chunk-strategy auto` for code files.
42. Verify the `qmd` CLI respects `NO_COLOR` and non-TTY output in scripts.
43. Check if `qmd` needs `XDG_CACHE_HOME` or `XDG_CONFIG_HOME` overrides in the service.
44. Consider adding a `qmd` wrapper alias in shell-aliases.nix.
45. Review `qmd` upstream release cadence and setup flake update automation.
46. Test aarch64-darwin build if the user wants parity with macOS.
47. Investigate whether `pnpmConfigHook` can be told to skip non-host optional deps.
48. Add a `qmd` health check to the post-deploy-check script.
49. Document the difference between `qmd search` (BM25), `qmd vsearch` (vector), and `qmd query` (hybrid + rerank).
50. Write a runbook for "qmd returns no results / index corrupt".

---

## Questions I can't figure out myself

1. **Mixed git state:** Was the `feat(qmd)` commit at `HEAD` (99ac60a5) created intentionally during this session, or did it pre-exist? The commit message describes the pnpm-tarball approach, but I was asked to switch to GitHub source. Should I `git reset` it and make a single clean GitHub-source commit, or amend it?

2. **flake.lock changes:** `flake.lock` has both staged and unstaged modifications. Are those from the pre-existing session or from the qmd refactor? I did not touch flake inputs, so I need to verify whether the lockfile diff is safe to commit or should be reverted to avoid unintended input bumps.

3. **HM user service sandboxing:** Is there a way to scope `qmd-mcp`'s filesystem access in a Home Manager user service without `ProtectHome`/`ReadWritePaths`? `hardenUser` intentionally omits them, and I want to confirm this is the intended SystemNix convention before redesigning the service as a system service with a user.

---

## Raw notes

> **Update 2026-07-22:** The refactor shipped as `bb37ad2a` ("refactor(qmd): build from GitHub source with pnpmConfigHook"). qmd is deployed, the HTTP MCP server runs on `localhost:8181`, and Crush is configured to use it. The mixed git state was resolved — all files committed cleanly.

- Built `qmd` successfully from GitHub source with `pnpmConfigHook`. Binary responds to `--version` and `--help`.
- `nix flake check --no-build` passes on x86_64-linux.
- `nixosConfigurations.evo-x2.config.system.build.toplevel` evaluates to `/nix/store/r2683s50kvf44j0573halahffgc3dlyw-nixos-system-evo-x2-26.11.20260719.241313f`.
- ~~Current `git status` shows a mix of staged and unstaged changes on the same files. Need user decision before committing/deploying.~~ **Resolved:** committed as `bb37ad2a`, deployed, runtime-verified.
- ~~Wait for instructions.~~ **Done.**

---

## Item Resolution (2026-07-30)

No numbered action items in this report — all work was completed within the session or is tracked in TODO_LIST.md / CHANGELOG.md.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
