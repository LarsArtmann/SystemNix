# AMD GPU telemetry upstream research — nvtop + kernel fdinfo

**Session:** 2026-10-29 evening → 2026-10-30 03-2x
**Trigger:** owner asked why nvtop shows nothing of the GPU usage we probed live, then escalated to "research upstream issues and figure out how we can help"
**Outcome:** two ready-to-send upstream artifacts (drafts in `docs/drafts/`), zero files needing a deploy, three todo rows recorded

## §a What we established (all live-verified on evo-x2)

Box state during probes: kernel 7.2.10, AMD Radeon 8060S Graphics (gfx1151 / Strix Halo), GTT 10.4/120 GiB used, GPU consumers = llama.cpp ROCm servers (bge-m3 :8848, bge-reranker :8849 under `hermes`, qwen3.6-35B :8850), nsfw-classifier-go-rocm :8104, plus the Wayland display stack.

1. **nvtop 3.3.2 per-process memory is vram-only** — on this APU that is the 1 GiB BIOS carveout, so every process shows ~0: llama bge-m3 1,925,120 B vs 808,752 KiB GTT in its fdinfo; nsfw 8,138,752 B vs 4,510,756 KiB. The GPU-wide bar is correct (11.4 GiB) because the iGPU vram+gtt bar sum landed pre-3.3.2 (`16e0f1d8`, 2025-12-13).
2. **Per-process GPU% is 0 for everyone in 3.3.2**, and even on master ROCm processes report `gpu_usage: null`: amdgpu fdinfo has no engine data for KFD/HIP compute (§c).
3. **Master already fixes per-process memory** — built master `71094a9` locally (cmake + libdrm via `LD_LIBRARY_PATH`, note: dlopen of `libdrm_amdgpu.so.1`, the `-dev` output lacks runtime symlinks) and verified live: llama 819,884,032 B, nsfw 4,627,083,264 B. The fix chain: `d3f91f78` (2026-07-13, count GTT per-process), `fbd4fe52` (2026-09-19, iGPU-only, PR #492), `eafc5ec7` (2026-09-19, KFD topology arch). **All unreleased** — latest release is 3.3.2 (tag `76890233`, 2026-02-08).
4. **KFD engine-invisibility proven with a verified workload** (`~/.cache/amdgpu-upstream/probe3.sh`): POST 412 tokens to bge-m3 :8848 → response 21,849 B with `"embedding"` field; `gpu_busy_percent` 99-100% for ~7 s then 0-2%; llama utime delta only 5 ticks (~50 ms — GPU-bound, CPU useless as proxy); `grep drm-engine` over the process's fdinfo = **0 lines, before/during/after**. Contrast: compositor (niri) fdinfo accumulates `drm-engine-gfx` (12.2 s engine time across an ~8 s wall window, parallel queues per fd). Mechanism (source-read, inference flagged as such): mainline `amdgpu_show_fdinfo()` feeds `drm-engine-*` from `amdgpu_ctx_mgr_usage()` — DRM contexts; KFD queues don't appear to feed it.

## §b Upstream landscape (researched)

- **Kernel:** Alex Deucher (AMD) started "Accelerator/GPU top" on amd-gfx 2026-02-05 proposing unprivileged `/proc/<pid>/drm/stat` (root: `CADnq5_MTX8CifP25UvE5kdMbCYxgK+A+KGdd-_Ef1m4VYv+WRQ@mail.gmail.com`). Umio-Yasuno (amdgpu_top) explicitly named the KFD/ROCm engine-utilization gap; Maxime Schmitt (nvtop author) said he cannot test ROCm. 9 messages, quiet since Feb 9. No patch series exists. Our data (§a.4) is exactly the missing evidence, from exactly the hardware class they lack.
- **nvtop:** issue #399 (GTT) closed by PR #428 (Mario Limonciello/AMD, merged 2026-01-16, APU vram+gtt BAR sum). Per-process GTT fixes from Jul/Sep unreleased; no release-request issue exists (searched open+closed). Distro packages (nixpkgs, Ubuntu PPA) all ship 3.3.2.

## §c Deliverables (drafts, owner-gated)

- `docs/drafts/2026-10-29_nvtop-release-request-apu-fixes.md` — release-request issue for Syllo/nvtop; checker passed (0 FAIL / 0 WARN); banner + checkbox for owner review.
- `docs/drafts/2026-10-29_amd-gfx-accelerator-gpu-top-reply.md` — plain-text mail reply to the thread with the §a.4 data + tester offer; To/In-Reply-To headers included; send via reply-all on the lore message.

Both are unsolicited AI-run filings → owner must review/send (verify-before-filing gates passed: source-read for every cited commit/file, live evidence attached, no existing duplicate found).

## §d Explored and deliberately NOT pursued

- Kernel-side patch for KFD engine accounting — way beyond session scope; the thread reply + tester offer is the right entry.
- nvtop PR — the code gap we found (vram-only per-process) is already fixed on master; nothing to patch, only to release.
- nixpkgs nvtop bump — blocked on the release existing (that's what the issue asks for).

## §e Residual findings

- `gpu_busy_percent` read 99-100% during the v2 window while the llama process consumed no CPU — we did NOT claim an idle-artifact: attribution of that window's busy-ness is unproven (other consumers may have been active). Counter-evidence exists too (busy dropped to 0-2% right after the verified workload finished). Not filed anywhere; re-probe before ever claiming an APU busy-counter artifact.
- llama-chat-side services cycle pids mid-experiment (3290688 → 4161668 → 731372 for :8850; 694380 → 1953501 for :8848) — probes must re-resolve pids at start and verify liveness at end (`llama_still_alive` check added to probe3.sh).
- nvtop master dlopen needs `libdrm_amdgpu.so.1` at runtime; building via `nix-shell -p cmake ncurses libdrm pkg-config gcc systemd` works, running needs `LD_LIBRARY_PATH` pointing at the non-dev libdrm output.

## §f Follow-ups (self-harvested at authoring)

1. **Send the amd-gfx thread reply** → `[blocked:user]` row in docs/todo/upstream.md (owner sends mail; agents never send).
2. **File the nvtop release-request issue** → `[blocked:user]` row in docs/todo/upstream.md (owner posts; gh create command included in the row).
3. **Package nvtop master `71094a9` locally so the desktop gets correct APU numbers now** → `[ready]` row: TODO_LIST.md (desktop section) + docs/todo/desktop.md library entry; deploy needed before it takes effect (noted in row).
4. **Watch the thread + nvtop releases for movement** → folded into rows 1-2's LIFT conditions (drop SystemNix stopgap once 3.4.0 ships and lands in nixpkgs).
