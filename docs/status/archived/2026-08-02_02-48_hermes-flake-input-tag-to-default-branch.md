# Hermes-Agent Flake Input: Tag → Default Branch + Caching Diagnosis

**Date:** 2026-08-02 02:48 CEST
**Session scope:** Investigated why `hermes-agent` never caches, then switched the flake input from a pinned tag to default-branch tracking.

---


## Context

User asked why `hermes-agent-0.19.0` never gets cached. The investigation revealed three compounding reasons, then pivoted to fixing the flake input URL from a pinned tag (`v2026.7.20`) to default-branch tracking (bare `github:NousResearch/hermes-agent`).

---

## a) FULLY DONE

1. **Diagnosed the caching failure (3 root causes):**
   - **Not pushed to Attic:** The `monitor365` Attic cache only receives what Forgejo Actions CI builds and pushes (mkLarsPackages outputs in the Monitor365 repo). Nobody runs `attic push` against `hermes-agent`. No CI workflow for it exists in SystemNix.
   - **Local `override` breaks substitutability:** `hermes.nix:31-52` calls `base.hermes-agent.override { extraDependencyGroups = [ ...18 groups... ]; }`. This changes the dependency closure → different store hash. Even if cache.nixos.org or NousResearch's own cache had `hermes-agent`, it would have a *different* hash. Nix only substitutes exact-derivation matches.
   - **Not in nixpkgs:** `hermes-agent` (NousResearch) is NOT packaged in nixpkgs. The only `hermes` in nixpkgs is `hermes-nvim` (unrelated Neovim plugin). Distributed exclusively via flakes (official `github:NousResearch/hermes-agent` or community `github:0xrsydn/nix-hermes-agent`).

2. **Documented `extraDependencyGroups`:** Explained how the override parameter works — maps to `pyproject.toml` `[project.optional-dependencies]` keys via uv2nix's `mkVirtualEnv`. Upstream always installs `["all"]` (core features), then appends whatever groups you pass. SystemNix adds 18 provider/integration extras (anthropic, messaging, firecrawl, edge-tts, fal, etc.) without which hermes can't reach any LLM or chat platform.

3. **Changed flake input from tag to default branch:**
   - `flake.nix:152`: `github:NousResearch/hermes-agent/v2026.7.20` → `github:NousResearch/hermes-agent`
   - Ran `nix flake update hermes-agent` → resolved to commit `3f497e2` (2026-08-02)
   - Transitive deps also updated: `pyproject-nix`, `uv2nix`, `pyproject-build-systems`
   - **Bumped version:** `hermes-agent-0.19.0` → `hermes-agent-0.19.1`

4. **Verified eval:** `nix eval` of `systemd.services.hermes.serviceConfig.ExecStart` succeeds → `/nix/store/34g1xr1wqf65hsm5wj2bar6vsvm5vmli-hermes-agent-0.19.1/bin/hermes gateway run --replace`

---

## b) PARTIALLY DONE

1. **Flake input change is uncommitted.** The edit + lock update are in the working tree but not committed. An auto-git daemon may commit them.

2. **AGENTS.md not updated.** The Hermes section lists `pip extras: messaging, anthropic, firecrawl, edge-tts, fal, exa` (6 items) but the actual `extraDependencyGroups` override has **18 groups**. This list is stale and should be updated or removed (it's not load-bearing — the source of truth is `hermes.nix`).

---

## c) NOT STARTED

1. **Attic push for the hermes closure.** The actual caching fix (pushing the built closure to the Attic cache) was discussed but not implemented:
   ```bash
   nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel
   attic push monitor365 $(nix path-info .#nixosConfigurations.evo-x2.config.system.build.toplevel --recursive)
   ```

2. **Attic push automation in deploy script.** Consider adding an `attic push` step to `deploy.sh` or `post-deploy-check` so the closure stays cached automatically after deploys.

3. **Attic cache configuration.** The `platforms/nixos/secrets/attic.yaml` sops secret file does NOT exist yet — this blocks full system eval (`error: Path 'platforms/nixos/secrets/attic.yaml' does not exist in Git repository`). This is a pre-existing issue (step 2 of the attic setup docs — manual creation required), not caused by this session's changes.

4. **Full build verification.** Only `nix eval` was run, not `nix build`. The 0.19.0 → 0.19.1 bump + updated uv2nix/pyproject-nix transitives could introduce build failures (FOD hash mismatches, API changes). A `nix build` or deploy is needed to confirm.

---

## d) TOTALLY FUCKED UP

1. **Forgot to write the status report.** The user explicitly asked for a full status report written to a file. I made the code change, verified eval, then responded with a 2-line summary — completely skipping the report. The user had to prompt "My file?" to get me back on track. This is a failure of task completion — I treated the edit as the deliverable instead of the report.

2. **Wrong initial reasoning on tag vs master.** I argued the tag was better for "reproducibility and stability," citing risks of `master` pulling broken commits. The user corrected me in one line: **"flake.lock exists!"** — the lock file pins the exact commit hash regardless of the URL `ref`. My reasoning was flat-out wrong. The `ref` only controls what `nix flake update` resolves to next; it has zero effect on reproducibility between updates. I should have known this from the start.

3. **Used `ref=master` without checking the default branch.** I assumed the default branch was `master`. It's `main`. Got a `422: No commit found for SHA: master` error and had to retry. Should have used the bare URL (`github:NousResearch/hermes-agent`) from the start — Nix resolves the default branch automatically.

---

## e) WHAT WE SHOULD IMPROVE

1. **Stop over-arguing for tags on third-party inputs.** `flake.lock` IS the reproducibility mechanism. Tags add a release-boundary semantic for `nix flake update` but don't improve reproducibility. For Tier 2 Nix projects (like hermes-agent), tracking default branch is fine — the lock file protects you.

2. **Check default branch names before guessing.** A bare flake URL (`github:owner/repo` with no `ref`) always resolves to the default branch. Prefer this over guessing `master` vs `main`.

3. **Verify changes with the right eval target.** `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` fails on the pre-existing `attic.yaml` missing-secret issue. Eval the specific service (`systemd.services.hermes.serviceConfig.ExecStart`) to isolate the change under test from unrelated failures.

4. **Keep AGENTS.md in sync with override lists.** The hermes `extraDependencyGroups` list grew from 6 to 18 items without an AGENTS.md update. Either keep the doc current or remove the partial list (point to the source file instead).

5. **Deliver what was asked, not what I think is the deliverable.** When the user says "write a status report," the report IS the deliverable — not the code change that preceded it.

---

## f) NEXT TASKS (UP TO 50)

### Immediate (this session's loose ends)
1. Commit the `flake.nix` + `flake.lock` hermes-agent change
2. Update AGENTS.md hermes section: fix stale `extraDependencyGroups` list (6 → 18 groups, or remove the list)
3. Run `nix build` on hermes-agent to verify 0.19.1 builds cleanly (not just evals)
4. Add a gotcha to AGENTS.md: hermes-agent is not in nixpkgs; flake input tracks default branch; flake.lock pins exact commit

### Caching (the original problem)
5. Create the `platforms/nixos/secrets/attic.yaml` sops secret file (RS256 key) — unblocks full system eval
6. Complete attic setup steps 4-9 from `docs/setup/nix-binary-cache-setup.md`
7. Push the hermes closure to Attic after first successful build
8. Add `attic push` step to `deploy.sh` (push system closure after successful deploy)
9. Consider attic push of per-package closures (not just full system) for faster substitution
10. Evaluate whether the 20 GB attic storage cap + 7-day retention is sufficient for the hermes closure size

### Hermes packaging
11. Audit whether all 18 `extraDependencyGroups` are actually needed (some may be unused — e.g., `dingtalk`, `feishu` if those platforms aren't used)
12. Check if `voice` extra works on evo-x2 (AGENTS.md says it has "complex native deps")
13. Check if `matrix` extra works (AGENTS.md says it "needs python-olm, Linux-only" — evo-x2 is Linux, so it should)
14. Consider whether `azure-identity` / `bedrock` extras are needed (cloud providers that may not be configured)
15. Verify hermes 0.19.1 changelog for breaking changes vs 0.19.0

### Attic cache hardening
16. Verify attic GC actually reaps paths on restart (the size-guard caveat in `attic.nix:162-167`)
17. Add Gatus health check for attic (`GET /` — already configured, verify it works post-deploy)
18. Monitor attic disk usage after first push (20 GB cap on /data partition)
19. Consider whether attic should be on the /data BTRFS partition (current) vs a dedicated subvolume
20. Add attic to the backup-coordination module if the cache metadata (SQLite) needs backup

### Documentation
21. Document the hermes caching strategy in AGENTS.md once attic push is operational
22. Add hermes-agent to the "not in nixpkgs" gotcha table
23. Update `docs/setup/nix-binary-cache-setup.md` if the workflow changes
24. Consider a `docs/services/hermes.md` with the packaging architecture (uv2nix, extraDependencyGroups, override pattern)

### Monitoring
25. Add a Gatus check for the hermes gateway service (if one doesn't exist)
26. Verify hermes OTel tracing endpoint format (Python: `http://localhost:4318` with scheme)
27. Check if hermes 0.19.1 has new health endpoints worth monitoring

### Flake hygiene
28. Audit all other third-party flake inputs for unnecessary tag pins (same logic as hermes)
29. Check if `wallpapers-src` (flake=false, ref=master) should track default branch
30. Verify `nix flake update --all` doesn't break after the hermes change
31. Consider `nix flake update` cadence — is there a schedule or is it ad-hoc?

### Build verification
32. Run `nix flake check --no-build` to validate syntax across all modules
33. Run the pre-deploy check (`nix run .#pre-deploy-check`) once attic.yaml exists
34. Deploy and run post-deploy smoke test for hermes
35. Monitor hermes service startup after deploy (it has heavy Python deps)

### AGENTS.md maintenance
36. Reconcile the hermes "Active pip extras" line with the actual 18 groups
37. Add the `flake.lock` reproducibility lesson to the gotcha table
38. Document that hermes-agent uses uv2nix (not buildPythonApplication) — different caching characteristics
39. Note that hermes override breaks substitutability (the fundamental caching issue)

### Future considerations
40. Consider vendoring hermes-agent into nixpkgs (upstream PR) for cache.nixos.org substitution
41. Evaluate the community flake `github:0xrsydn/nix-hermes-agent` as an alternative
42. Consider a scheduled `nix flake update hermes-agent` + auto-build CI job
43. Add hermes closure size to the system-health monitoring (it's a large Python venv)
44. Check if hermes has a `nixosModules.default` we should consume (Monitor365 pattern) instead of the hand-rolled module
45. Audit hermes.nix for the "Consuming LarsArtmann Flakes" pattern compliance (it's third-party, not LarsArtmann, but the overlay pattern is similar)
46. Verify the `patchedOverlay` in hermes.nix is still needed (upstream may have changed the override API)
47. Check if hermes 0.19.1 changed the `extraDependencyGroups` parameter name or semantics
48. Consider pinning hermes-agent to a specific commit if 0.19.1 introduces regressions
49. Review whether the 18 extras create unnecessary build time (each adds Python deps to resolve/build)
50. Document the hermes build time impact on deploy (likely 10-30 min without cache)

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Which of the 18 `extraDependencyGroups` are you actually using?** Several (dingtalk, feishu, azure-identity, bedrock, modal, daytona, parallel-web) may be for platforms/providers you don't have configured. Removing unused extras would shrink the closure, speed up builds, and reduce the caching burden. I can't tell from the Nix config alone which integrations are active — the sops secrets only cover 6 API keys (discord, glm, minimax, xiaomi, fal, firecrawl).

2. **Should I commit the flake change now, or do you want to build-test 0.19.1 first?** The change evals clean but hasn't been built. If 0.19.1 has a build regression (FOD hash mismatch from the updated uv2nix/pyproject-nix), you'd want to know before committing. Alternatively, commit now and let the deploy catch it — the lock file makes rollback trivial (`git checkout flake.lock`).

3. **Do you want attic push automation in `deploy.sh`, or will you push manually?** Auto-pushing the full system closure after every deploy guarantees the cache stays warm, but adds deploy time (pushing ~N GB of store paths). Manual push gives you control over when the cache is populated. I don't know your deploy frequency or bandwidth constraints well enough to recommend.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
