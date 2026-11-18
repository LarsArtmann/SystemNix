# qmd iGPU Root Cause + Vulkan Fix — Full Status

**Date:** 2026-11-18 06:42 CET (session started 2026-11-17 ~20:00, ran past midnight)
**Session scope:** "Why does qmd spike CPU?" → "why no iGPU/NPU?" → root cause → **working fix landed in tree, built, verified** → docs/TODO reconciliation.
**HEAD at authoring:** 98dfd8643 (daemon commit carrying this session's tree changes) — `master [ahead 1]`, unpushed.

---

## Root cause (the answer, 4 stacked layers — all live-probed)

qmd's GGUF inference goes through node-llama-cpp, whose Linux backends are CPU / CUDA / Vulkan — **no ROCm, and no NPU backend exists in llama.cpp at all** (XDNA architecturally impossible; never a config issue). The only iGPU path is Vulkan, which failed 4 ways, every one swallowed silently (NDEBUG → `silent=true` in `ggml_backend_load_best`):

1. **Broken prebuilt artifact** — `libggml-vulkan.so` fatals on dlopen: `undefined symbol: ggml_backend_score`. The backend loader dlsyms that symbol per plugin; CPU plugins export it, the vulkan plugin does not. **Broken in latest 3.22.3 too** (tarball-probed) — bumping qmd's pin would NOT have fixed the iGPU.
2. **Wrapper library path** — the upstream flake wrapper pins `LD_LIBRARY_PATH` to sqlite + glibc-2.42 + gcc with **no `libvulkan.so.1`**.
3. **glibc trap** — RADV (system mesa) pulls `libLLVM.so.21.1` requiring **GLIBC_2.44**; bun ran inside the wrapper's glibc-2.42 process → ICD chain couldn't load → zero devices.
4. **Fork trap** — node-llama-cpp's compat test forks `process.execPath` directly, so the loader fix must live INSIDE the bun ELF (an `ld.so bun` wrapper fixes only the parent; forked children kept the 2.42 PT_INTERP → GLIBC_PRIVATE mismatch).

## The fix (landed, daemon commit 98dfd8643, pre-deploy)

**`pkgs/qmd-gpu.nix`** (105 lines, full evidence header): copies the qmd lib tree (flake input untouched, no vendorHash churn), patches `libggml-vulkan.so` with a `-nostdlib` score shim via `patchelf --add-needed $ORIGIN/...`, ships a bun copy with `--set-interpreter` = system glibc loader, extends `LD_LIBRARY_PATH` (system glibc first + vulkan-loader + upstream's sqlite/gcc kept), pins `VK_DRIVER_FILES` to the RADV ICD, replicates the upstream wrapper's mcp log-quieting line verbatim, keeps bin name `qmd` (crushrc MCP spawns `qmd mcp`).
**Wired:** `flake/parts/packages.nix` exposes `packages.x86_64-linux.qmd-gpu` (isLinux block); `configuration.nix` consumes it in place of the raw input package.

## Verification evidence chain

| Gate | Result |
| --- | --- |
| Binding probe (store addon, patched plugin dir) | `loaded Vulkan backend`, `GPU: vulkan` |
| Real qmd vsearch (prototype tree) | 0 fallback warnings; old run warned `no GPU acceleration` |
| Real qmd embed (prototype tree, `--timeout 2`) | `gpu_busy_percent` spikes 31/45/22/27% (idle 1-2%); host CPU ≈ 0 during inference; 0 CPU-fallback warnings |
| Built package artifact | wrapper paths correct; shim present; bun PT_INTERP = `glibc-2.44-57/lib/ld-linux-x86-64.so.2` |
| Built package end-to-end vsearch | **0 fallback warnings** (qmd's warning fires iff `llama.gpu === false`), search completed |
| `binsDir` runtime-relative resolution from copied tree | verified (package copy self-resolves) |
| nixpkgs vulkan-loader default ICD discovery | verified (no `VK_DRIVER_FILES` needed; kept explicit anyway — boot-mirror box) |
| Latest upstream 3.22.3 vulkan tarball | same missing export → bump ≠ fix (upstream ask stays) |
| ai-meter visibility | qmd = in-process GGUF, zero OpenAI-compatible HTTP → invisible to the ai-meter proxy by construction (not a metering gap) |
| Bonus | system `uname` works again under the new env (old wrapper's glibc-2.42 LDL broke 2.43-built PATH binaries) |

**Known verification nuance:** the built binary finishes a vsearch so fast that per-process `/proc` map sampling raced it; built-binary GPU proof = qmd's own fallback-warning gate + the identical-mechanism embed probe on the prototype. A `gpu_busy` snapshot from the BUILT binary during a real embed is a listed follow-up.

## a) FULLY DONE

1. 4-layer root cause, each layer live-probed and reproducible (dlopen repro, LD_DEBUG traces, readelf dynsym A/B, loader-source reading, tarball probes).
2. NPU verdict: architecturally impossible for llama.cpp/qmd (no XDNA backend).
3. ai-meter verdict: qmd invisible by construction (in-process, no HTTP) — documented.
4. Working prototype: patched plugin + system-loader bun → `GPU: vulkan`; embed gpu_busy 45% vs idle 1-2%, CPU ~0.
5. `pkgs/qmd-gpu.nix` — the proper fix (copy + patch + wrapper), upstream-tolerant (bun path / LDL / mcp line parsed from the upstream wrapper at build time).
6. Flake exposure (`packages.qmd-gpu`, isLinux block, darwin-leg safe) + `configuration.nix` swap.
7. Package built: `/nix/store/3a3f9mw5wli60vxc41vvqmss17fq5ics-qmd-2.8.3-gpu`.
8. Built-artifact verification: wrapper/shim/interpreter all correct; end-to-end vsearch clean (0 fallback warnings).
9. `docs/agents/shell-devtools.md` qmd section rewritten twice (root cause → landed-fix state; current text reflects the FIX).
10. `docs/todo/upstream.md` qmd row: full evidence + 3.22.3 + ai-meter notes + **SITE FIX LANDED** annotation; upstream ask unchanged.
11. Upstream-bug strength test: 3.22.3 latest confirmed broken (pre-empts "just bump" advice).
12. Git forensics: session files landed in 98dfd8643; foreign `flake.lock` float (3 rev moves) rode the same daemon commit — documented, NOT amended (daemon-race policy: amend would absorb foreign content).
13. Two false-lead corrections retracted same-session (timeout-death false success; 32-bit loader pick) — final evidence chain is clean.

## b) PARTIALLY DONE

1. **GPU snapshot from the BUILT binary specifically** — search too fast to sample; embed-time `gpu_busy` capture pending (mechanism already proven on the identical prototype path).
2. **MCP path live test** — wrapper replicates the mcp env line, but a fresh Crush session (`qmd mcp`) on the DEPLOYED system is untested (needs deploy + session restart anyway).
3. **`qmd doctor`** — should now pass its device probe (it crashed pre-fix); not re-run on the built package.
4. **Status-report self-harvest** — §f items below are deliberately NOT harvested into TODO_LIST.md/domain libraries yet: the owner asked for the list to triage ("WAIT FOR INSTRUCTIONS"). Each will land as a queue/library row or an explicit not-harvested verdict after triage.
5. **CV corpus embed backlog** — 1781 docs (62%) still lack embeddings; now GPU-cheap to backfill but not run.

## c) NOT STARTED

1. **Deploy** — generation carrying the swapped systemPackages (quiescence-gated; master ahead-1 with a foreign flake.lock float riding the commit — vet before push).
2. Post-deploy: fresh Crush session MCP smoke (`qmd mcp` search).
3. CPU→GPU embed wall-time comparison on the CV corpus (the user-visible win metric).
4. Upstream issue drafting (verify-before-filing gate → github-voice → owner review → post; row exists `[blocked:user]`).
5. CHANGELOG.md entry for the qmd-gpu landing.
6. Store hygiene: prototype artifacts in `~/.cache` (qmd-tree-copy, qmd-vk-fixed, nlc3223 tarball, score-shim files ≈ 120 MB+100 MB) — trash after report sign-off.

## d) TOTALLY FUCKED UP (honest ledger)

1. **Status report not written on first request** — the forensics ran but the file didn't; you had to prompt twice. Process failure, fixed now.
2. **False-success reading** — the first "no warnings" vsearch was actually `timeout` dying on the poisoned LD_LIBRARY_PATH (grep matched nothing; rc misread). Caught by re-running with `env` inside `timeout`; cost ~10 min.
3. **32-bit loader detour** — picked `vulkan-loader-1.4.357` (i386) first: `wrong ELF class: ELFCLASS32`; the store had two loaders and I didn't check ELF class upfront.
4. **Tracked-files trap** — first `nix build` died on untracked `pkgs/qmd-gpu.nix` despite AGENTS.md documenting exactly this; `git add` BEFORE eval is the rule, now re-burned in.
5. **Two derivation syntax stumbles** — `${kept}` leaking into Nix-level code (my own predicted hazard!) and a `''`-escape subtlety; fixed with pure shell branching; `nix-instantiate --parse` pre-check would have caught both cheaply.
6. **LD_DEBUG re-runs** — violated capture-once-then-grep twice (heavy-eval discipline applies to traces too).
7. **Wrong-direction theory persistence** — spent several probes on the glibc-2.42/RADV symbol-floor theory after it was disproven (RADV max GLIBC_2.38); the REAL link was libLLVM's 2.44 floor one hop further down. Should have chased the loader trace immediately after the shim changed the failure mode.

## e) WHAT WE SHOULD IMPROVE

1. **Write the status report when asked** — forensics first is fine, but the file should land in the same turn.
2. **Evidence-first verification** — prefer the program's own gates (qmd's fallback warning, ggml's loaded-backend log) over racing `/proc` samples on fast processes.
3. **Parse-check Nix before build** — `nix-instantiate --parse pkgs/*.nix` is free and catches string-escape hazards.
4. **ELF-class / interpreter checks upfront** when picking loader artifacts from a multi-arch store.
5. **Keep TODO library rows synced the moment a premise changes** (the upstream row said "wrapper lands with a working backend" — the shim IS one; noted late).
6. **Prototype → package faster**: the prototype proved every layer; the package only needed to re-encode it — next time wire the derivation WHILE the last probes run.
7. **Guard the shared `result` symlink**: leaf-package builds should `--out-link` a named link (e.g. `result-qmd-gpu`) instead of clobbering/reading the generic `result` other sessions use.

## f) NEXT — HARVESTED 2026-11-18 ~07:5x per owner go (queue + domain files carry all open rows; ledger below)

**Executed in-session:** 1 float vetted (cvagent + go-nix-helpers owner-input FORWARD floats — policy-clean, no third-party pins touched) · 19 CHANGELOG entry · 20 shell-devtools cross-link · 22 this harvest · 23 prototypes trashed (~1.5G: qmd-tree-copy 1.3G + qmd-vk-fixed 77M + nlc3223 73M + shim/logs; real `~/.cache/qmd` state untouched) · 39 gotchas-archive row · 42 resolved (foreign CHANGELOG edit committed in 68cdfca51) · 45 no secrets typed ✓

**No-op verdicts (verified):** 21 — no 2026-11-17/18 status report mentions qmd besides this one (nothing to cross-link) · 35 — sole node-llama-cpp consumer on the box is the qmd wiring itself (configuration.nix; no other crushrc/service touches it) · 36 — bun copy is incompressible (original 794M apparent ≈ 792.9M physical; gpu build +96M same story; compress=zstd correctly no-ops on binaries) · 41 — repo-root `result` now points at a FRESH cv-go-modules drv (rebuilt 07:36 by another session, actively in use — foreign, left alone) · 44 — no pin needed, GC collects the two vulkan-loader paths

**Deliberately skipped:** 2 push — never-push-without-explicit-ask stands; deploy needs no push (owner can push the wave when ready)

**Deploy & verify (the fix's last mile)**
1. Vet the foreign flake.lock float in 98dfd8643 (3 rev moves — identify inputs, find the owning session) before push.
2. Push `master` (ahead 1) — push-gated on owner.
3. Deploy the qmd-gpu generation via the quiescent path (`scripts/deploy-when-quiescent.sh`).
4. Post-deploy: fresh Crush session → qmd MCP search → confirm iGPU.
5. Capture `gpu_busy_percent` + vulkan-maps snapshot from the BUILT binary during a real embed (close b.1).
6. Backfill CV embeddings: `qmd embed` (1781 docs, 62%) — record wall-time vs the 2026-11-17 CPU baseline.
7. Re-run `qmd doctor` on the deployed system (device probe should pass now).
8. Test the escape hatches on the deployed wrapper: `QMD_FORCE_CPU=1` and `QMD_LLAMA_GPU=vulkan` both behave.
9. Full hybrid `qmd query` (expansion + embed + rerank, all three models) on GPU.
10. `qmd status` after backfill — confirm the 62% missing-embeddings gap closed.

**Upstream (the artifact bug is theirs)**
11. Draft the withcatai/node-llama-cpp issue: linux-x64-vulkan prebuilt missing `ggml_backend_score` (3.20.0 AND 3.22.3 evidence, readelf A/B, dlopen repro) — verify-before-filing gate first.
12. Draft the tobi/qmd issue: silent CPU fallback hides GPU failure (NDEBUG silent=true) — ask for a loud fallback warning + doctor surfacing `NoBinaryFoundError`.
13. Report the qmd flake wrapper's missing `libvulkan.so.1` in LD_LIBRARY_PATH (with evidence).
14. Report the wrapper's pinned glibc-2.42 breaking PATH binaries on newer-glibc hosts (the `uname` GLIBC_2.43 error).
15. Watch row: node-llama-cpp releases > 3.22.3 — re-probe the vulkan plugin export; qmd bump re-runs the package-header gates.
16. Watch: llama.cpp tag-scheme change (b10361 → v0.9.0 in 3.22.3) — next qmd bump shifts core versions; re-verify.
17. Decide: node-llama-cpp localBuild (cmake Vulkan) as a cleaner long-term site fix vs the shim (decision row).
18. Verify-before-filing the whole upstream batch in one pass (shared evidence appendix).

**Docs & bookkeeping**
19. CHANGELOG.md entry: qmd-gpu landing (root cause one-liner + commit).
20. Cross-link this report from `docs/agents/shell-devtools.md` qmd section (evidence pointer).
21. Cross-link this report as the resolution in any 2026-11-17 status-report rows that noted qmd CPU spikes.
22. Self-harvest THIS report's §f items into TODO_LIST.md + domain libraries after your triage (per TODO-system rules).
23. Trash prototype artifacts (`~/.cache/qmd-tree-copy`, `qmd-vk-fixed`, `nlc3223`, score-shim files) — ~220 MB.
24. Consider a derivation self-test gate: assert the patched `.so` carries the score-shim NEEDED + shim exports the symbol (check, not hope).
25. Document the `--out-link` convention for leaf builds (e.7 institutionalized).

**Hardening / nice-to-have (qmd-adjacent)**
26. Raise `QMD_EMBED_PARALLELISM` on iGPU — safe throughput test.
27. Tune `QMD_EMBED_CONTEXT_SIZE` ceiling on the iGPU (GTT-backed; watch memory.events).
28. Confirm idle MCP sessions hold no GPU memory (GTT residency check post-deploy).
29. Index SystemNix itself as a qmd collection (now GPU-cheap) — owner call.
30. Confirm no metering gap: ai-meter scope is API-proxy only — policy sign-off that local GGUF compute stays unmetered.
31. Add qmd-gpu build to a pre-deploy batch surface (quick-go-style) so upstream qmd bumps fail fast on re-hash/patch drift.
32. Package-header gate re-run as a check: `QMD_LLAMA_GPU=vulkan qmd vsearch` clean after ANY qmd input bump (automatable in checks/).
33. Consider `lib.mkBefore`-style doc note in cv.md: CV session's qmd MCP now rides the wrapper (post-deploy).
34. Check whether fastflowlm (NPU runtime) could ever serve qmd's models (brainstorm; likely no — different model format path).
35. Sweep for other node-llama-cpp consumers on the box with the same silent-CPU bug (grep crush services/ai-stack).
36. Confirm BTRFS compression on the ~100 MB bun copy (store bloat check — compress=zstd handles it; verify ratio).
37. Add `qmd-gpu` version to `qmd --version` output parity check (crush models doctrine: assert WHICH entity serves).
38. Cross-check the CV session's qmd usage post-deploy (its embeds should stop spiking 13 cores — textfile/PSI evidence).
39. File-site: record the 4-layer root-cause chain in `docs/gotchas-archive.md` (incident narrative class).
40. Evaluate `qmd pull --progress` behavior under the wrapper (model downloads still work).

**Session-hygiene debt (noticed, in passing)**
41. The stale repo-root `result → erraudit drv` symlink (foreign session's) — coordinating cleanup, not mine to trash.
42. CHANGELOG.md carries an UNCOMMITTED foreign edit right now (visible in git status) — other session mid-work; do not touch.
43. Re-run `nix flake check --no-build --all-systems` on the quiescent final tree (my files are commit-covered; one clean confirmation post-triage).
44. Pin-cache audit: the two vulkan-loader store paths in /nix/store (1.4.350 from a closure, 1.4.357 32-bit) — GC will collect; no pin needed.
45. Re-check fish_history hygiene rules were honored this session (no secrets typed — qmd work is secret-free ✓).

## g) QUESTIONS FOR YOU (cannot self-answer)

1. **ai-meter policy:** local GGUF inference (qmd embed/search/rerank) is invisible to ai-meter by construction — zero API spend, pure local compute. Should local model usage be metered AT ALL (GPU-seconds / docs embedded), or is ai-meter API-proxy-only by design?
2. **Collections scope:** CV is the only indexed collection. With embed now on iGPU, which repos should qmd index (SystemNix itself? go-aichat / cqrs fleet? docs trees)?
3. **Deploy & push timing:** master is ahead-1 and my commit carries a foreign `flake.lock` float (3 input revs, not mine). Deploy the qmd-gpu generation now through the quiescent path, or ride the next deploy wave — and do you want the float attributed/vetted before push?

---

*Evidence commands for every claim are in the session transcript; the artifact-level gates are also encoded in `pkgs/qmd-gpu.nix`'s header (re-run after any upstream qmd bump).*
