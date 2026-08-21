# Status: llama-cpp ROCm MFMA Flag No-Op Discovery & Fix

**Date:** 2026-08-02 03:06
**Session Scope:** Investigating why `llama-cpp` ROCm builds take 30+ min from source, discovering the local override was a no-op, fixing it, and writing a skill proposal.
**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395 / Strix Halo / gfx1150 / RDNA 3.5)

---

## Executive Summary

The `llama-cpp-rocwmma` derivation in `modules/nixos/services/ai-stack.nix` had an `overrideAttrs` adding `-DGGML_HIP_MMQ_MFMA=ON`. This flag was a **complete no-op on Strix Halo (gfx1150 / RDNA 3.5)** — it only affects CDNA datacenter GPUs (MI100/200/300/350), defaults to ON upstream already, and RDNA 3.5 uses WMMA (not MFMA) which is always enabled via compiler builtins. The override existed for months, causing 30+ minute local source builds on every nixpkgs bump because the changed derivation hash never matched `cache.nixos.org` — for zero functional benefit. Removed the override, added a 14-line warning comment, marked the TODO done, and wrote a skill proposal capturing the epistemic lesson.

---

## a) FULLY DONE

1. **Root cause investigation of `llama-cpp` uncached builds** — Traced the full mechanism: `overrideAttrs` changes store hash → no cache hit → 30 min source build. Then traced the flag itself through upstream source code: `GGML_HIP_MMQ_MFMA` → `GGML_HIP_NO_MMQ_MFMA` compile definition → `#if defined(CDNA)` architecture guard → `AMD_MFMA_AVAILABLE` macro. Confirmed gfx1150 (RDNA 3.5) does NOT define `CDNA`, so the flag has zero effect on this hardware.

2. **Removed the no-op `overrideAttrs`** — `modules/nixos/services/ai-stack.nix` lines 18-26. Replaced `(pkgs.llama-cpp.override { rocmSupport = true; }).overrideAttrs (...)` with plain `pkgs.llama-cpp.override { rocmSupport = true; }`. This may allow binary cache hits from Hydra if the ROCm variant is on the jobset.

3. **Added a 14-line warning comment** — Explains exactly why the flag must never be re-added: (1) defaults to ON upstream, (2) only affects CDNA, (3) RDNA uses WMMA, (4) the override only broke caching. Placed directly at the derivation site so any future agent/human sees it immediately.

4. **Marked TODO_LIST item as resolved** — `TODO_LIST.md` line 52, changed from `[ ]` to `[x]` with explanation of why the flag is a no-op and why upstreaming it is unnecessary.

5. **Searched nixpkgs for existing PRs/issues** — Confirmed zero existing PRs or issues for `GGML_HIP_MMQ_MFMA` exposure in `llama-cpp`. The closest was PR #427944 (rocmPackages bump) which noted the OPPOSITE problem — MFMA instructions failing on older GPUs.

6. **Wrote skill proposal** — `/home/lars/projects/SKILLS/docs/feedback/new/verify-before-filing.md`. After harsh feedback on the first draft (too bloated, narrative-heavy), rewrote it completely with proper skill frontmatter, 5 verification gates, generalized anti-patterns, and a boxed concrete example. Positioned as the outbound complement to the existing `verify-external-claims` skill.

---

## b) PARTIALLY DONE

1. **Drafted a nixpkgs GitHub Issue** (then ABANDONED) — Wrote a polished, ready-to-file issue proposing `rocmMfmaSupport` as a package option. It was technically wrong — the flag is a no-op on RDNA hardware. The issue was NOT filed (correctly), but time was spent drafting and polishing it before the root cause was discovered. The lesson from this failure fed into the skill proposal.

2. **Eval verification of the fix** — The full `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` fails due to a PRE-EXISTING error (missing `platforms/nixos/secrets/attic.yaml` from uncommitted Attic work, not from this session's changes). Verified the `ai-stack` module config evaluates correctly via a targeted eval of `ollama.serviceConfig.MemoryMax` (returned `32G` as expected). The derivation change itself is trivial (removing an overrideAttrs), so eval risk is near zero.

---

## c) NOT STARTED

1. **Verifying whether `pkgs.llama-cpp.override { rocmSupport = true; }` is actually cached on Hydra** — The override removal may or may not result in cache hits. If nixpkgs doesn't build the ROCm variant on their Hydra jobset, it'll still build from source — just without the spurious hash change. Need to check `hydra.nixos.org` for the `llama-cpp` ROCm job, or just deploy and observe.

2. **Deploying the fix** — The change is uncommitted. Needs `nix run .#deploy` to take effect. The build may still take time on first deploy (if the ROCm variant isn't cached), but subsequent nixpkgs bumps should benefit if Hydra has it.

3. **Committing the changes** — Files modified but not committed: `modules/nixos/services/ai-stack.nix`, `TODO_LIST.md`. The skill proposal is in a separate repo (`/home/lars/projects/SKILLS/`).

---

## d) TOTALLY FUCKED UP

1. **Drafted a wrong GitHub Issue with full confidence** — I wrote a polished, well-structured nixpkgs issue proposing `rocmMfmaSupport` as a package option, complete with code examples and impact analysis. It was **completely wrong** — the flag is a no-op on RDNA 3.5. If the user hadn't asked "can nix figure out if it's supported automatically?", I would have happily filed it, embarrassing the user and wasting nixpkgs maintainers' time. The issue was technically plausible (formatting was excellent, reasoning seemed sound) but the core premise was never verified against the actual upstream source code until the user pushed back.

2. **Wrote a mediocre first skill proposal** — The first draft of `verify-before-filing.md` was a bloated narrative retelling of the session, not a proper skill. It lacked frontmatter, had no verification gates, was overly specific to the llama-cpp case, and read like a blog post. Only after the user called it out ("Is this the best proposal you can write????") was it rewritten properly with the skill format, generalized gates, and sharp thesis.

3. **Did not verify the override BEFORE drafting the issue** — The entire failure chain: I should have traced `GGML_HIP_MMQ_MFMA` through the upstream source code BEFORE assuming it was necessary and drafting an issue. Instead, I drafted first and verified second. The verification happened only because the user asked a probing question. This is the exact anti-pattern the new skill is designed to prevent — and I committed it myself.

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Verify overrides before assuming they're needed** — Every `overrideAttrs` / `override` in the config should be audited: does it actually change runtime behavior? Does the flag reach code that executes on the target platform? The `llama-cpp` override existed for months unchallenged because "someone added it for a reason." Inherited overrides (especially AI-generated) are the highest-risk class.

2. **Audit all custom overrides in the codebase** — There may be other no-op overrides silently breaking binary caching or adding build time. A systematic audit of every `overrideAttrs` in `modules/`, `pkgs/`, and `overlays/` would catch them. The `nix-review` skill exists for exactly this.

3. **Never draft an upstream issue without tracing the feature to source first** — The skill proposal captures this, but it needs to be internalized: "plausible and well-formatted" is not "correct." Always verify against primary source (source code, not docs/blog posts) before proposing changes to external projects.

4. **Check Hydra jobset coverage for expensive builds** — SystemNix has several packages that build from source (ROCm, CUDA, Rust with native deps). Knowing which are Hydra-cached vs. always-local would help prioritize optimization effort. The `nixos-unstable` vs `nixpkgs-unstable` gotcha in AGENTS.md already documents this class of problem.

### Documentation Improvements

5. **AGENTS.md gotcha entry** — Should add an entry documenting the `GGML_HIP_MMQ_MFMA` no-op discovery, similar to other gotcha rows. This prevents any future agent from re-adding the flag.

6. **The `-rocwmma` naming is now misleading** — The derivation is still called `llama-cpp-rocwmma` but it's just `llama-cpp` with ROCm support (no special WMMA flag — WMMA is always on for RDNA). The name implies a custom WMMA build, which it isn't. Could rename to just use `pkgs.llama-cpp.override { rocmSupport = true; }` inline.

---

## f) Up to 50 Things We Should Get Done Next

### Immediate (this session's fallout)

1. Deploy the `ai-stack.nix` fix (`nix run .#deploy`) and verify whether `llama-cpp` ROCm now gets cache hits
2. Commit the `ai-stack.nix` + `TODO_LIST.md` changes
3. Add an AGENTS.md gotcha entry for the `GGML_HIP_MMQ_MFMA` no-op
4. Rename `llama-cpp-rocwmma` to something accurate (or inline it) since it's no longer a custom WMMA build
5. Verify on `hydra.nixos.org` whether `llama-cpp` with `rocmSupport = true` is actually cached

### Override Audit (high value — catch more no-ops like this)

6. Audit every `overrideAttrs` in `modules/` for no-op flags
7. Audit every `overrideAttrs` in `pkgs/` for unnecessary changes that break caching
8. Audit every `overrideAttrs` in `overlays/` for the same
9. Check the `monitor365SwaggerUiFixOverlay` in `overlays/linux.nix` — is it still needed?
10. Check `catppuccin-gtk.override { python3 = prev.python312; }` — is Python 3.14 still an issue on unstable?
11. Check `homepage-dashboard.override { enableLocalIcons = true; }` — verify still needed
12. Run the `nix-review` skill on the full flake for a comprehensive `.nix` audit

### Binary Cache / Build Performance

13. Verify the Attic cache is actually wired as a substituter (the `/etc/nix/nix.conf` from this session showed it's NOT in the substituters list yet)
14. Check if Attic is pushing built paths automatically after builds
15. Audit which SystemNix packages build from source >5min and aren't Hydra-cached
16. Consider adding a `nix run .#cache-warm` command that pushes expensive-to-build derivations to Attic
17. Check if `ollama-rocm` (used by the ai-stack) is Hydra-cached on `nixos-unstable`

### Skill Proposal Follow-up

18. Review the `verify-before-filing.md` skill proposal after a cooling-off period
19. Consider whether it should be a global skill or project-specific
20. Check if there's overlap/duplication with the existing `verify-external-claims` skill
21. Add the skill to the crush skills directory if approved
22. Write a test scenario for the skill (a real upstream issue to evaluate against)

### Upstream Engagement (if verified needed)

23. File a nixpkgs issue/PR to clarify `llama-cpp` ROCm documentation (WMMA vs MFMA) — NOT to add the flag, but to document that RDNA users don't need it
24. Check if other nixpkgs packages have similar MFMA/WMMA confusion

### General Codebase Health

25. Run `nix flake check --no-build` after committing to verify no syntax errors
26. Check for other instances of "flags added because they sound faster" pattern
27. Review the `lib/rocm.nix` helper — are all the env vars still needed?
28. Verify `HSA_OVERRIDE_GFX_VERSION = "11.5.1"` is still correct for Strix Halo
29. Check if `OLLAMA_GPU_OVERHEAD = 8589934592` (8 GiB) is still the right value

---

## g) Questions I CANNOT Answer Myself

1. **Should I commit the `ai-stack.nix` + `TODO_LIST.md` changes now, or wait until the Attic cache work (missing `attic.yaml`) is resolved so the full eval passes cleanly?** — The eval failure is pre-existing and unrelated, but committing on a broken eval feels risky.

2. **Do you want me to deploy this immediately (`nix run .#deploy`), or do you want to review the change first?** — The first deploy after removing the override may still build from source (if the ROCm variant isn't cached), so it could take 30 min.

3. **Should the `verify-before-filing` skill proposal also cover INTERNAL issues/PRs (within your own repos), or strictly external projects?** — The failure pattern (unverified diagnosis → wrong issue) applies to both, but the social cost is different (internal is lower stakes).

---

_Created and Reviewed by Lars Artmann with the help of GLM-5.2 via Z.ai and Crush_

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
