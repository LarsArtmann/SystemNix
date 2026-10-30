# Status — amdgpu/nvtop upstream research session + brutal self-review

**Session window:** 2026-10-29 ~22:2x → 2026-10-30 03:51
**Scope:** only THIS session's work (owner ask: "research upstream issues and figure out how we can help making them better for us and/or all Linux AMD users", then the close-out demand). Parallel sessions' tree activity (crush-0990, stalwart, ci-unblock, router-audit, pim-sync reports 22:35-23:55) is NOT mine and is not assessed here.
**Note:** `brutal-self-review` skill's HTML-report default was superseded by the owner's explicit `docs/status/*.md` instruction (user format request wins per skill contract).

---

## a) FULLY DONE

1. **Live GPU-consumer inventory** (the original question "who is using the iGPU and for what"): /proc fd-scan + GTT/VRAM sysfs + ss — ROCm compute (bge-m3 :8848, bge-reranker :8849 under `hermes`, qwen3.6 :8850, nsfw-classifier :8104) vs display stack (niri/quickshell/Xwayland/helium+VAAPI/electron/ghostty/nvtop).
2. **Root cause of "nvtop shows nothing"** — three stacked, live-verified reasons: (1) 3.3.2 per-process memory = vram-only (1 GiB carveout; llama 1.9 MB vs 808,752 KiB GTT in fdinfo — exact number match), (2) no engine-util data for the processes in question (see the §d correction below), (3) `hermes`-owned processes invisible to unprivileged fdinfo reads.
3. **Per-process GTT one-liner** (fdinfo `drm-memory-gtt` awk-sum) — delivered and sanity-checked live.
4. **Upstream landscape mapped** (source + issue-tracker level): nvtop #399 → PR #428 (Mario Limonciello/AMD, merged 2026-01-16, BAR-only fix); per-process GTT fixes `d3f91f78` (2026-07-13) + `fbd4fe52` (2026-09-19) + `eafc5ec7` (KFD arch) all UNRELEASED (latest tag 3.3.2, `76890233`, 2026-02-08); no existing release-request issue (open+closed searched). Kernel: mainline `amdgpu_show_fdinfo()` emits `drm-engine-*` only when `amdgpu_ctx_mgr_usage()` is nonzero; Alex Deucher's "Accelerator/GPU top" thread (2026-02-05, 9 messages, quiet since Feb 9) covers unprivileged per-process stats, with Umio-Yasuno naming the exact KFD gap and nvtop's author stating he can't test ROCm; no patches exist.
5. **nvtop master built and live-verified on this box** (clone at `~/.cache/amdgpu-upstream/nvtop`, `71094a9`): per-process memory correct (llama 819,884,032 B, nsfw 4,627,083,264 B). Runtime gotchas captured (dlopen `libdrm_amdgpu.so.1`, non-dev libdrm output on `LD_LIBRARY_PATH`, binary at `build/src/nvtop`).
6. **KFD-invisibility experiment, verified form** (`~/.cache/amdgpu-upstream/probe3.sh`): 412-token embedding → 21,849 B response with `"embedding"` field, `gpu_busy_percent` 99-100% for ~7 s then 0-2%, utime delta 5 ticks, **zero `drm-engine-*` lines before/during/after**.
7. **Two filing-ready drafts** (verify-before-filing gates + voice checker passed): `docs/drafts/2026-10-29_nvtop-release-request-apu-fixes.md` (checker 0 FAIL / 0 WARN) and `docs/drafts/2026-10-29_amd-gfx-accelerator-gpu-top-reply.md` (To/In-Reply-To headers set).
8. **Repo records**: status report `docs/status/2026-10-30_03-24_amdgpu-telemetry-upstream-research.md`; 2 `[blocked:user]` rows (upstream.md), 1 `[ready]` row (desktop.md + TODO_LIST queue); `check-todo-system.sh` clean.

## b) PARTIALLY DONE

1. **Kernel mechanism claim**: "KFD queues don't feed `amdgpu_ctx_mgr_usage()`" is a source-read inference from the DRM side, flagged as such in the draft — NOT verified at the KFD level (no kfd source read, no trace of where kfd accounting would land).
2. **Master's per-process GPU% delta-util path**: source-read yes (`extract_gpuinfo.c` `gpu_cycles`/`sample_delta`), live verification NO — every DRM-context process was idle during the snapshots; I never observed a nonzero per-process gpu_usage on master.
3. **`gpu_busy_percent` APU reliability**: evidence is contradictory (100% flat through the v2 window with llama CPU-idle; dropped to 0-2% the moment the verified workload finished). Correctly NOT filed anywhere; also correctly NOT claimed as an artifact. Unresolved.
4. **llama service pid churn**: observed 3× (:8850 3290688→4161668→731372; :8848 694380→1953501), recorded as a residual finding in the 03-24 report §e — root cause NOT investigated, todo row filed only in THIS close-out (see §f.2).

## c) NOT STARTED (by design — owner-gated or queued)

1. Sending the amd-gfx mail reply (`[blocked:user]`).
2. Filing the nvtop release-request issue (`[blocked:user]`).
3. Packaging nvtop master locally (`[ready]`, needs a deploy).
4. Writing today's durable GPU-monitoring facts (nvtop vram-only-on-APU, fdinfo probing technique, KFD gap) into `docs/agents/monitoring.md` — MISSED during the session (memory-update protocol violation), harvested to §f.1 now.
5. Watching the thread / nvtop releases for movement (folded into the two filing rows' LIFT conditions).

## d) TOTALLY FUCKED UP / corrections to the record

1. **Early absolute claim, later falsified**: I told the owner "amdgpu fdinfo exports no per-process engine-utilization fields at all" and "per-process GPU% is 0 for everyone". That generalization came from grepping ONE process (an ROCm llama) plus a head-truncated field dump. It is WRONG in general: DRM-context processes (niri, helium) DO accumulate `drm-engine-*` ns, and master computes delta utilization from them. The durable record (03-24 report, drafts) carries the corrected, scoped claim (KFD/ROCm-specific gap). This chat's earlier messages do not, and cannot be edited — this section is the named correction surface.
2. **Experiment v1 premise flaw**: first generation probe sent the response to `/dev/null` — nothing verified the workload ran — and the qwen server's pid churned mid-run, freezing utime. I almost had a "during compute" claim with no compute proof. Caught on reflection, rerun twice until verified.
3. **Experiment v2 curl failure**: curl worked in `bash -c` but failed inside the heredoc-created script ("No such file or directory" on the `-o` target). Root cause NEVER established — my "the guard likely parsed the heredoc text" explanation to the owner is an UNVERIFIED hypothesis, stated as likely. The workaround (write-tool file + clean invocation) works; the diagnosis doesn't exist.
4. **Unverified claim in the "why is amdgpu dog shit" answer**: "rocm-smi shows garbage/zero on APUs" was voiced from prior knowledge, never checked on this box. Inbound-claim discipline violated in a low-stakes context; not corrected anywhere durable until now.
5. **Memory-update protocol miss**: today's durable, reusable findings went only into a status report, not into `docs/agents/monitoring.md` where GPU monitoring knowledge lives. A future session would have to rediscover everything.

## e) WHAT WE SHOULD IMPROVE

1. **Design probes with verification from attempt #1**: capture + assert the workload's effect (response body, utime delta, liveness) in v1, not after two failed rounds.
2. **Never generalize driver capability from one process's fdinfo** — sample a graphics-context process AND a compute process before any "driver exports X" sentence.
3. **Resolve failed-tooling root causes or mark them unknown** — "likely the guard" without a check is a fabricated-premise seed for a later session.
4. **Durable-knowledge reflex**: any technique that survived verification (the fdinfo GTT one-liner, nvtop gotchas) goes to the owning `docs/agents/*.md` in the same session.
5. **The qwen-generation probe via :8850 is unreliable by construction** (ensure-churn); :8848 with pid re-resolution + liveness assert is the pattern to keep (probe3.sh is the keeper).

## f) What we should get done next (session-scoped, impact-sorted; items 1-8 are harvested, 9+ are brainstorm/ROADMAP fuel)

1. **[ready] Persist today's GPU-monitoring facts into `docs/agents/monitoring.md`** — nvtop 3.3.2 vram-only per-process on APUs; per-process GTT via fdinfo; KFD/ROCm engine gap; nvtop master build recipe + gotchas. HARVESTED → `docs/todo/monitoring.md` + queue.
2. **[ready] Investigate the llama-server pid churn (:8850 three pids, :8848 two, within hours)** — ensure-churn by design or crash-loop? HARVESTED → `docs/todo/ai-stack.md` + queue.
3. [blocked:user] Send the amd-gfx thread reply (draft ready) — already filed upstream.md.
4. [blocked:user] Post the nvtop release-request issue (draft ready) — already filed upstream.md.
5. [ready] Package nvtop master `71094a9` locally (pkgs/ fetchFromGitHub + platforms swap; deploy needed; drop at nixpkgs ≥3.4.0) — already filed desktop.md + queue.
6. [ready] Live-verify master nvtop's per-process GPU% on a busy DRM-context process (play a video in helium / heavy scroll while snapshotting) — closes §b.2.
7. [verify-then-file] Read KFD source (`amdgpu_ctx_mgr_usage` callers / kfd queue accounting) to upgrade the draft's "happy to be corrected" inference into a mechanism claim before the mail goes out — strengthens the reply's credibility.
8. [ready] Scriptify the fdinfo per-process GTT probe (`scripts/gpu-fdinfo-gtt.sh` with redact-argv discipline) so the one-liner stops living in chat logs.
9. [watch] After 3.4.0 ships: bump nixpkgs nvtop, drop the local package, close the desktop.md row.
10. [watch] If the thread produces a patch series (`/proc/<pid>/drm/stat` or KFD engine accounting): test on gfx1151 immediately (tester offer already made).
11. [verify-then-file] Check whether `rocm-smi`/`amd-smi` on this box actually expose per-pid GTT on APUs before ever repeating the "shows garbage" claim.
12. [decision] Does the owner want a one-time grant for agent-posted upstream filings (mail + GitHub issue) or keep review-and-send-per-item?
13. [ready] Re-run probe3.sh at a quiet hour to firm up the gpu_busy idle-vs-busy contrast table (sets §b.3 straight either way).
14. [ready] Add `llama_still_alive`-style post-asserts as a standard pattern note for workload probes into the monitoring doc (folds into item 1's edit).
15. [ready] Confirm nvtop master's snapshot (`-s`) shows the hermes reranker under `sudo nvtop` (expected: yes) — completes the visibility matrix (lars/hermes × memory/util).
16. [ready] Document the "3.3.2 vs master" diff as a pinned upstream reference in the desktop.md row's body (exact commit list already in the 03-24 report — one-line backfill).
17. [blocked:deploy] Land whatever nvtop packaging decision (item 5) in the next deploy window; smoke = `nvtop -s` shows llama ≥700 MiB.
18. [ready] Capture `uname -r`/kernel rev into the drafts as a one-liner env block (drafts cite 7.2.10 prose-only today — the kernel moves under us).
19. [watch] Gatus/SigNoz angle: per-process GTT is now measurable — decide whether any alert (e.g. "nsfw-classifier GTT > X") is worth wiring; else record as deliberately-not-wanted.
20. [ready] Add the fdinfo double-count caveat (shared buffers counted per-fd) as a comment wherever the one-liner lands (item 8).
21. [ready] Sweep `~/.cache/amdgpu-upstream/` — keep probe3.sh + the clone, trash gen-probe.sh/gen-probe2.sh (stale failed attempts; provenance confusion risk).
22. [ready] Move probe3.sh to a durable location (scripts/ or docs/agents example) — it currently lives in volatile `~/.cache` (the /tmp-lesson applies to ~/.cache too for anything we cite in reports).
23. [watch] amd-gfx thread: if no movement in ~4 weeks after our reply, consider a dri-devel cross-post (owner decision at that point).
24. [ready] Backfill the qwen :8850 model-alias drift risk noticed during probing (`--alias qwen3.6-35b-a3b-aggressive` + `--chat-template-kwargs` inline JSON in argv) into ai-stack docs if not already there.
25. [ready] nvtop release issue: after filing, subscribe + capture the maintainer reply into the upstream.md row (keeps the LIFT condition current).
26. [ready] Verify the drafts' claim "no existing release-request issue" once more at post time (Gate 5 is point-in-time).
27. [ready] Cross-check `docs/agents/monitoring.md` GPU section for any stale claims the session's findings falsify (e.g. anything asserting nvtop correctness on APUs).
28. [ready] Add "which processes hold kfd" to the runbook: `fuser`-style fd scan pattern (from this session's first tool call) into the monitoring doc alongside item 1.
29. [watch] Kernel 7.2.10 vs AGENTS.md's 7.2.2 reference — one stale doc line; trivial fix on sight next time the GPU section is touched (owner-permissioned trivial-fix rule applies).
30. [ready] Check whether nixpkgs has nvtop update PRs in flight before filing the release request (avoid asking for a release a nixpkgs PR already tracks) — pre-post check folded into item 4's row.
31. [ready] If item 7 confirms the mechanism, add a kernel-side follow-up row: propose KFD engine-ns in fdinfo as a concrete ask with a sketch (only after the reply lands, to avoid two-channel proposals).
32. [ready] Teach `scripts/redact-argv.sh` usage into the probe script pattern (probe3.sh echoes pids only — verify no argv leakage if reused for other services).
33. [ready] Consider `btop` GPU module parity check (btop ships amdgpu support; does IT show GTT per-process?) — if yes, a cheaper local answer than the nvtop package; verify before claiming.
34. [ready] nvtop master build recipe → make it a one-command script next to the clone (item 22's durable home).
35. [ready] Docs: add the "one process ≠ driver capability" lesson to `docs/CONTRIBUTING.md` verification discipline section (cross-project candidate for lessons.md via owner commit).

(35 items; 1-8 harvested below, 9+ brainstorm-grade — routing rigor applies per the status-report skill's larger-N rule.)

## g) Questions I cannot answer myself

1. **Which mail identity should the amd-gfx reply carry** (`lars@larsartmann.de` placeholder is in the draft) — and do you want to send it yourself or grant a one-time agent window (question 3 in §f.12 folded here)?
2. **Is the llama-server pid churn (:8850/:8848 cycling pids all evening) intended ensure-converge behavior or a live crash-loop you already know about?** If intended, item 2 downgrades to a doc note; if not, it jumps the queue as a service-health finding.
3. **Do you want the local nvtop-master package at all**, or is 3.3.2's bar + the fdinfo one-liner good enough until upstream releases (items 5/17/9 collapse if "wait for 3.4.0")?

---

**Self-harvest ledger (house rule: §f follow-ups land at authoring time):** items 1 → `docs/todo/monitoring.md` + TODO_LIST monitoring section; item 2 → `docs/todo/ai-stack.md` + TODO_LIST ai-stack section; items 3-5 → already filed upstream.md/desktop.md in the 03-24 report turn; items 6-8 → deliberately NOT harvested yet (each needs its premise re-verified live before queueing: busy DRM workload availability, KFD source study scope, script-proliferation decision); items 9+ → brainstorm, not committed work.
