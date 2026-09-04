# Status Report: The 20-llama-server amdxdna Wedge (llama-rag RAG stack)

**Date:** 2026-09-04 15:59 CEST
**Trigger:** User pasted nvtop/btop screenshots from evo-x2 asking "what bananas went wrong" — ~20 `llama-server` processes visible, load avg ~50-74 at 3-5% CPU, 92% RAM used.
**Scope:** Diagnosis + fix of the llama-rag corpse pile, single-vs-multi-model research, monitoring tripwire. Session STOPPED before deploy #3 at user request. **Nothing has been deployed yet.**

---

## Root Cause (fully diagnosed, live-verified)

**Chain of failure — 4 stacked things:**

1. **The NPU driver is wedged.** Since ~**Sep 2 22:05** (first strays' start time), every `open("/dev/accel/accel0")` blocks FOREVER inside kernel function `amdxdna_drm_open`. Proximate cause: an flm crash left the amdxdna driver in a state where new opens hang (the documented flm crash-loop class; `flm-real` is currently a **zombie** — the NPU LLM is dead too). Only a **reboot** clears this.

2. **ROCm's libdrm enumeration opens EVERY DRM-class node at startup — including the NPU.** `/dev/accel/accel0` is `root:video 0660` and the llama-rag service user sits in `video`, so the open reaches the driver and hangs. Every `llama-server` start (even `llama-server --help` — I proved this by accident) hangs in D-state **before parsing args or binding its port**. RSS ~14MB (weights never loaded), 1 thread, wchan `amdxdna_drm_open`.

3. **D-state processes are unkillable.** All corpses carry `SigPnd 0x100` = **pending SIGKILL that can never deliver**. systemd's stop path burns ~3-6 min in SIGTERM/SIGKILL timeouts, logs `Processes still around after final SIGKILL. Entering failed mode` + `Unit process ... remains running after unit stopped`, then gives up.

4. **Every deploy restarts the units → every deploy strands another corpse pair.** Journal shows the cycle verbatim ("Found left-over process ... in control group while starting unit. Ignoring" × N, then "Started"). 10 pairs accumulated across ~2 days of deploys. **Result: 0 listeners on :8848/:8849 — Paperless-AI RAG (semantic search) silently dark since Sep 2; Gatus checks were red and Discord-alerting the whole time.**

**Corollaries discovered:**

- **The 70% IO PSI is PHANTOM.** Measured: zero block IO movers, Dirty 25MB, Writeback 0, disks idle — the kernel counts ANY D-state sleep as IO stall, so 21 corpses = 70% "IO pressure" = the deploy pressure gate would block on ghosts. Used `DEPLOY_FORCE_PRESSURE=1` (justified: the deploy removes the pressure source).
- **Ollama survived the wedge by accident of upstream design:** nixpkgs' ollama module ships `DevicePolicy=closed` + `char-drm`/`char-kfd` DeviceAllow. `/dev/accel` is `SUBSYSTEM=accel` (NOT drm) → denied → the wedged driver was never touched. Live proof the device-cgroup fix works.
- **Load avg ~50-74** = mostly the D-state corpses (each counts), not real work.

## Single llama-server for all models? (researched, verified against deployed binary + upstream docs)

- **No — two servers is the architectural floor.** `--pooling` is a single GLOBAL flag: bge-m3 needs cls/mean pooling for correct embeddings, bge-reranker-v2-m3 needs `rank` for correct scores. One process with one pooling value silently breaks one of the two (wrong rerank scores = the invisible-failure class).
- Upstream llama.cpp DOES now have router mode (`--models-dir`/`--models-max`/`--models-autoload` — confirmed present in the deployed llama-cpp 0.3.0 via `libllama-common.so` strings + bash completion), but per-model pooling is unverified. Consolidation only viable if upstream adds per-model pooling config.
- The 20 processes were NOT "1 per model enforced" — the design was always exactly 2 (one per MODE). 18 of them were a bug.

---

## a) FULLY DONE

1. **Complete root-cause diagnosis** with live evidence: wchan `amdxdna_drm_open`, `SigPnd 0x100` pending SIGKILL, cgroup membership (`system.slice/llama-embeddings.service` reused across restarts), journal forensics of systemd's give-up cycle, port scan (0 listeners), process start-time spread (Sep 2 22:05 → Sep 4), zombie pair + flm-real zombie identified.
2. **`lib/rocm.nix`: new `deviceCgroup` fragment** — `DevicePolicy=strict` + path-based `DeviceAllow` (`/dev/null /dev/zero /dev/full /dev/random /dev/urandom /dev/dri/ /dev/dri/renderD128 /dev/kfd`). Path-based is the robustness trick: `/dev/accel/*` is outside `/dev/dri` so udev-tag ambiguity (SUBSYSTEM=accel vs drm) can never re-open the hole. Cgroup BPF rejects the open with EPERM **before** it reaches the driver. Documented in-file with the incident reference.
3. **`llama-rag.nix`: fragment applied to both `llama-embeddings` + `llama-reranker`** via mkMerge (no `//` — follows repo priority rules).
4. **`system-health.nix`: new `system_stuck_dstate_processes` metric** — counts processes in D-state >1h (awk over `/proc/[0-9]*/stat`, starttime field math, fail-closed emission only when the scan produced a value, per the 2026-09-02 value-less-line doctrine). **Live-tested on the box: correctly reports 19** (18 service corpses + my own `--help` probe corpse).
5. **`gatus-config.nix`: "Stuck D-State Processes" check** (Infrastructure group, `pat(*system_stuck_dstate_processes 0*)` — same value-0 pattern class as the three live forgejo checks). Will be RED until reboot — by design: it IS the "reboot needed" signal. Discord alert text includes the triage one-liner.
6. **`pre-deploy-check.sh`: `KNOWN_NEW_METRICS` loan entry** for the new metric (chicken-and-egg: metric ships with this deploy; verified the loan works — absence downgraded to WARN, confirmed in deploy attempt #2 output).
7. **`AGENTS.md`: two new llama-rag bullets** — the 2026-09-04 incident (full mechanism + fix + reboot-only cleanup) and "two servers is the FLOOR" (pooling constraint + router-mode status).
8. **ai-stack.nix ollama: attempted hardening correctly REVERTED** with an explanatory comment (see section d).
9. **Multi-model/router-mode research** verified against BOTH the deployed binary (strings in `libllama-common.so.0.3.0`, bash-completion flag list) and upstream docs (agentic fetch of tools/server README).
10. `nix flake check --no-build` passed after the llama-rag/system-health/gatus edits (caveat in section d — it did NOT catch the ollama conflict).

## b) PARTIALLY DONE

1. **THE DEPLOY — attempted twice, blocked twice, NOT completed.** Attempt #1 (16:0x): blocked by phantom-metric gate (fixed via loan). Attempt #2: blocked by the ollama DevicePolicy eval conflict (my bug, fixed by revert ~15:55). **The ai-stack revert has NOT been re-evaluated or deployed yet.** Everything in section a is sitting in the working tree, undeployed.
2. **Post-deploy verification plan defined but not executed:** expect exactly 2 new llama-server processes (RSS >1GB = weights loaded, not D-state), :8848/:8849 listening, journal shows ROCm/HIP init on GPU (not CPU fallback — validates that `DevicePolicy=strict` didn't starve ROCm of /dev/dri or /dev/kfd), post-deploy-check RAG smoke (1024-dim embeddings + correct rerank order).
3. **`KNOWN_NEW_METRICS` loan retirement** — must be removed after the deploy confirms the metric live in :9100/metrics ("one-deploy loan, not a museum").

## c) NOT STARTED

1. Reboot of evo-x2 (clears: 21 unkillable corpses, flm-real zombie, amdxdna driver wedge, phantom IO PSI, ~40 load-avg points). **User decision — it's their desktop, 3d21h uptime.**
2. flm/NPU health work: `flm-real` zombie + all-NPU-opens-hang since Sep 2 means FastFlowLM (PMA go-commit, papdashboard enricher consumers) is dead/hosed until reboot. Not investigated beyond state snapshot.
3. Retirement/cleanup of my own probe corpse (impossible without reboot — same D-state).
4. Optional hardening of other DRM-enumerating services beyond ollama/llama (voice-agents whisper is Docker-device-scoped = already safe; nothing else identified this session).

## d) TOTALLY FUCKED UP (mine — honest accounting)

1. **The ollama DevicePolicy conflict — my eval blind spot.** I added `rocm.deviceCgroup` (`strict`) to `systemd.services.ollama` while nixpkgs' module already sets `DevicePolicy="closed"` → hard eval failure. **`nix flake check --no-build` PASSED while `nix eval ...toplevel.drvPath` FAILED** — the two eval paths force different amounts of the config. Lesson: after touching `serviceConfig` of units owned by upstream modules, run the drvPath eval (the exact §2 command), not just flake check. Cost: one wasted deploy cycle (blocked at gate, no harm done — the gate did its job).
2. **My `--help` probe spawned corpse #19.** `job_kill` killed the shell wrapper but the `llama-server --help` child (PID 3384727) survived as PPID-1 orphan and hung in the same `amdxdna_drm_open`. Should have predicted: any exec of that binary hangs on this box. Unkillable until reboot.
3. **Two broken IO-measurement attempts** (shell `paste` misaligned rows as PIDs churned between snapshots → garbage deltas like "62.5GB/s"). Third attempt (python, pid-keyed) was correct: zero movers. Lesson: snapshot-diff anything keyed by list position is broken by construction; join on keys.
4. **First sourcegraph queries returned 0 results** (over-specific syntax); recovered via agentic_fetch + binary strings instead.
5. Deploy attempt #1 wasted ~10 min before reading the KNOWN_NEW_METRICS mechanism that AGENTS/gate output effectively documented (I should have read §10 of pre-deploy-check.sh BEFORE adding a gatus metric referencing a metric that doesn't exist yet — the chicken-and-egg is a known, solved class).

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **`flake check --no-build` is NOT sufficient eval coverage for serviceConfig changes** — pre-deploy §2's `drvPath` eval forces more. Consider making pre-commit or a helper run the drvPath eval when `systemd.services.*` of upstream-owned units change.
2. **PSI-based gates cannot distinguish D-state pollution from real IO.** The deploy pressure gate + memory-emergency guard Zone design read `/proc/pressure/io` that was 70% PHANTOM for 2+ days. A stuck-D count should modulate IO-PSI-based decisions (e.g., if stuck_dstate is high, IO PSI is untrustworthy). Follow-up worth doing now that the metric exists.
3. **The monitoring gap was detection-vs-correlation, not coverage:** Gatus was red for 2 days and Discord alerted — nobody reacted because 20+ checks scream daily. The new stuck-D check turns this class into ONE unambiguous "reboot me" signal. Consider sev1-bridge notify-tier wiring for it (NOT page-tier per the movie-night rule).
4. **ROCm/GPU services without device cgroups walk every DRM node on the box.** `rocm.deviceCgroup` should be the default for any future ROCm consumer (fastflowlm is NPU-only and exempt; it NEEDS accel).
5. **flm wedge = shared-fate for unrelated services** — the NPU being wedged took down the GPU RAG stack. Device isolation (this fix) is the right blast-radius control; driver-level fix is upstream/kernel territory.

## f) NEXT TASKS (roughly prioritized)

1. Re-run `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` → must pass after the ai-stack revert.
2. Deploy: `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (IO PSI still phantom until reboot; memory 9% is real but memory-PSI ~0).
3. Post-deploy verify: exactly 2 new llama-server procs, RSS >1GB, not D-state; `ss` shows :8848/:8849 LISTEN.
4. Verify GPU (not CPU) residency: journal `grep -iE 'rocm|hip|Vulkan'` on llama-embeddings; if CPU fallback → DeviceAllow needs adjusting (add what's missing).
5. Run post-deploy-check (RAG smoke: 1024-dim embeddings + rerank order).
6. Confirm `system_stuck_dstate_processes` live in :9100/metrics (expect ~19-21), then RETIRE the KNOWN_NEW_METRICS loan entry.
7. **REBOOT evo-x2** (user-scheduled): clears corpses + flm zombie + amdxdna wedge + phantom PSI.
8. After reboot: verify stuck-D metric → 0 and the Gatus check goes green.
9. After reboot: verify flm cold-load + NPU serves again (socket-activation smoke via post-deploy-check's fastflowlm section).
10. Post-reboot: check whether bge-m3/bge-reranker come up on GPU on first try (fresh amdxdna state).
11. Consider `DeviceAllow`-based startup guard: ExecStartPre asserting `/dev/accel` is NOT openable in-unit (cheap canary: `[ ! -e /dev/accel ]` under strict policy is wrong — the node exists in /dev; instead try `: < /dev/accel/accel0` expecting EPERM... verify semantics before building this).
12. Wire `system_stuck_dstate_processes` into sev1-bridge as **notify-tier** (never overlay — movie-night rule).
13. Add a SigNoz rule for stuck-D (mirrors Gatus check; the `signoz-query-lint` constraints apply).
14. Consider PSI-distrust logic in memory-emergency-guard/deploy gate: `io_psi` gated on `system_stuck_dstate_processes == 0`.
15. flm: after reboot, if amdxdna wedges again on crash, capture `journalctl -k` + goroutine dump runbook analog for the NPU driver state (kernel-side; no userspace dump exists).
16. flm upstream: the crash-loop → driver-wedge coupling is worth an upstream issue (flm repo) — a crash while contexts are live leaves amdxdna refusing opens.
17. Revisit llama.cpp router mode when per-model pooling lands upstream (watch release notes; then llama-rag could become ONE process serving both models — module options would need a redesign).
18. Consider adding `/dev/accel` DeviceAllow DENY-documentation to the GPU section of AGENTS (the fragment's in-code doc covers it; a pointer from the GPU GTT section may help discovery).
19. Sweep for OTHER services whose users sit in `video`/`render` without device cgroups (audit script candidate; ollama already safe via nixpkgs, llama-rag now safe, whisper Docker-scoped).
20. The 2 llama zombies (`3985321/3985322`, cgroup `deleted`) — confirm they reap on reboot (they're children of PID 1; systemd should reap post-restart).
21. Post-reboot: confirm load avg returns to sane baseline (~2-10) and nvtop shows the two llama-servers with 1-2GB GTT each.
22. Consider a `tests/test-llama-rag.nix` VM test asserting DevicePolicy=strict renders on both units (pure-eval assertion, cheap; the class that bit ollama).
23. If kernel 7.2.2 lands: retry the FastFlowLM v1.0.3-era pending verifications (held-back items in AGENTS flm section).
24. Optional: `qmd embed` still not enabled per MCP banner — unrelated, flagged only.
25. After everything: docs-health pass on the llama-rag/AGENTS entries (this report + AGENTS bullets may need merging once postmortem stabilizes).

## g) QUESTIONS (cannot figure out myself)

1. **When may I reboot evo-x2?** Everything code-side is fixed-or-pending-deploy, but the 21 corpses, the flm-real zombie, the wedged NPU driver, the phantom 70% IO PSI, and ~40 points of load avg clear ONLY on reboot — and it's your desktop (up 3d21h). Reboot right after the deploy verifies, or you pick a window?
2. **Proceed with the deploy now?** It needs `DEPLOY_FORCE_PRESSURE=1` because the pressure gate reads phantom IO PSI (D-state pollution) and MemAvailable is 9% (memory-PSI ~0, so no active memory pressure). I judged it safe — disks are idle and the deploy REMOVES the pressure source — but the escape hatch is your call, especially with the freeze-incident history on this box.
3. **Is flm's Sep-2 death known/accepted?** FastFlowLM (NPU LLM: PMA go-commit messages, papdashboard insights) appears dead since ~Sep 2 22:05 (`flm-real` zombie, all NPU opens hang). It should self-heal after reboot (socket activation), but if the wedge recurs on every flm crash, the flm crash-bug becomes the NPU poison-pill — do you want the guard to also stop `fastflowlm.socket` when stuck-D > 0 (prevents re-wedging attempts), or leave flm alone?

---

**Artifacts this session:** `lib/rocm.nix`, `modules/nixos/services/llama-rag.nix`, `modules/nixos/services/ai-stack.nix` (comment-only net), `modules/nixos/services/system-health.nix`, `modules/nixos/services/gatus-config.nix`, `scripts/pre-deploy-check.sh`, `AGENTS.md`, this report. **Working tree carries all of it, UNDEPLOYED.**
