# Status report — llama-chat moved to the iGPU: HIP build verified under the unit sandbox

**Session window:** 2026-11-28 ~02:20-03:25 CET, boot 0737ecd7, interactive session (not a tq task).
**Ask:** owner answer "YES!" (2026-11-27) to "change SystemNix to build llama.cpp with ROCm/HIP and move the models onto the iGPU", under the standing directive "ALL AI models should be ran on iGPU or NPU and NEVER on the CPU". Trigger: the browser-history summary 500 of 2026-11-27 (`/summary` timed out at 600 s while the CPU llama-chat processed a 5,190-token prompt at 5-18 tok/s).
**Scope line — what this report VERIFIED (all from commands run in THIS session):** the HIP build's identity and store presence; the small-model and 23 GB chat-model soaks under a `systemd-run` sandbox mirroring the deployed ROCm units; every speed number in the table; the cgroup-vs-GTT accounting reading; the idle-check failure (journal + store path + source); the red-green proof of the new test; the evo-x2 toplevel eval. NOT verified: anything on the deployed generation — **no deploy happened** (see §Not done).

## Verdict

The flip is **built, verified and in the tree, not deployed**. `services.llama-chat.accelerator = "igpu"` is set in `configuration.nix`; the next `nix run .#deploy` switches the 23.4 GB chat model from 12 CPU threads to the Radeon 8060S. Nothing needs to be built for it: the HIP build was already in the system closure.

Three findings the owner did not have when saying yes:

1. **"Support for this APU is untested" was wrong** (my own wording in the question). This host ran the ROCm llama.cpp path for months: the embeddings server is on the pinned HIP 0.3.0 build right now, and the wedge that made llama-chat CPU (freeze #5) was already attributed upstream on 2026-11-14 to the mmap load path (llama.cpp #19482). The 1.0.0 build leaves that path on iGPUs (`--load-mode auto` → `none`), which is what changed.
2. **The iGPU residency is invisible to the cgroup.** The soak unit's cgroup peaked at **5.2 GB while ~27 GB sat in GTT**. `MemoryMax`/`MemoryHigh`, `memory.events` and every cgroup-based reading under-report the unit by the weight size, and the GTT copy is pinned — a memory cliff cannot evict it. During the soak, with two foreign nix evals at 44 GB, `MemAvailable` fell to 5.3 GB; I stopped the soak for that reason and it recovered to 30 GB at once.
3. **A live production bug, unrelated to the GPU:** every idle check stopped its backend. `llama-chat` unloaded at 02:57:39 mid-request; the same check governs both llama-vlm backends. Fixed in the tree (§Findings 3).

## What was run

| Step | Command / evidence | Result |
| ---- | ------------------ | ------ |
| HIP build already present | `llama-server-rocm` → `/nix/store/1qgjmvkrsp11003m9k0wsvkj6lrszshv-llama-cpp-1.0.0`; `libggml-hip.so` in `bin/`; rocblas/hipblas 7.2.4; drv targets include `gfx1151` | no build needed |
| GPU identity | `gfx_target_version 110501`, `STRXLGEN`, 80 SIMDs, card `1002:1586` | native gfx1151 |
| Small model, unit-shaped sandbox | `sudo ./scripts/llama-rag-soak.sh --server <hip> --model bge-m3.gguf --minutes 1 --port 18849 --force --as-user lars` | **PASS VERDICT** (23 samples, 0-1 ticks/sample, health 200) |
| Chat model, same sandbox | harness `--mode chat`, `--as-user lars --memory-max 48G`, flags `--jinja -ngl all -lv 4` on the default 4 slots | loaded in **2m29s**: `load_mode = none`, `offloaded 41/41 layers`, `ROCm0 model buffer size = 22056.09 MiB`, `KV 160 MiB`; 125 samples health=200, idle CPU between probes |
| Inference probes against the soak server | `/completion` + `/v1/chat/completions`, 1.2k and 6.1k-token prompts | table below |
| Host-level eval | `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` at `98a16648` + this change | rc=0, no new llama-chat warning |
| Rendered production unit | targeted `nix eval` of `systemd.services.llama-chat` | ExecStart = HIP build + `--gpu-layers all --load-mode none --parallel 1`, `SupplementaryGroups = ["render"]`, `DevicePolicy = strict`, HSA env |
| New regression test | `nix build .#checks.x86_64-linux.llama-chat-accelerator` | green; red-proof: neutering `rocm.deviceCgroup` fails exactly the 3 device cases, restored byte-identical |

## Measured (io PSI some 28-60% throughout — storm-window numbers)

| Probe | CPU (before) | iGPU (after) |
| ----- | ------------ | ------------ |
| Prompt processing | 5-18 tok/s under IO pressure (the 2026-11-27 incident); calm-box figure never measured | **831 → 1,230 tok/s** (1,213 tokens, warm-up then steady), **1,245 tok/s** (6,120 tokens in 4.9 s) |
| Generation | ~17 tok/s (2026-10-08, calm) | **53-56 tok/s** |
| 6k-prompt chat request, 200 output tokens | did not finish in 10 min on 2026-11-27 | **8.8 s** wall, no `<think>` block |
| 4 parallel chat requests (1.2k prompts, 160 output tokens) | interleaved on 12 threads | all 4 done in **9.4 s**, default 4 slots — no request-time wedge |
| Cold load, 23.4 GB | ~8 min (02:37→02:44 the same night, storm) | **2m29s** |

A CPU baseline on the live unit the same night was attempted and **failed for a reason that is itself a finding**: the idle check killed the backend mid-request (§Findings 3), so the "before" column rests on the 2026-10-08 and 2026-11-27 records, not on a paired measurement.

## Findings

1. **`--load-mode auto` resolves to `none` on this iGPU** — source (`ggml-cuda.cu`: `mmap_support = device type != IGPU`; HIP is generated from that file) and journal (`load_mode = none`) agree. The module pins `--load-mode none` so the escape does not ride on HIP's integrated flag. One warning stays: `Flash Attention over K/V rows is assigned to device CPU` — FA is off on the HIP path for this model; the non-FA kernels ran at the speeds above.
2. **GTT is not charged to the cgroup** (evidence in the verdict). The AGENTS.md GPU sentence "the hard bound is always the service cgroup MemoryMax" is false for GTT and is corrected there.
3. **Idle-check regression, live in the deployed generation.** `_llama-idle-activity.nix` exported the bare `writeShellApplication` derivation; the callers splice it as `if ${templateActivity} ...`; executing a store directory fails with `Is a directory` (exit 126), the `if` takes its false branch and the script reaches `systemctl stop`. Journal 02:57:39: `line 34: /nix/store/py7wqi619z6n9aswrg0aqc8iwh6qbrmv-template-activity-since: Is a directory` → `Stopping llama-chat ...` → `Failed with result 'exit-code'`. Effects: the 60-min keep-alive is never honored (backend down at the first check ≥10 min after start without a live bridge), an in-flight request died, and each reload is a 23.4 GB cold load. Fix: the helper exports `lib.getExe …` (callers unchanged, llama-vlm included); pinned by the new test. Not deployed.
4. **The soak harness had never produced a verdict.** `get_pid` grepped `systemd-cgls` output for the full binary path; `systemd-cgls` truncates long command lines to `llama-…`, so every real run exited "process never appeared" 30 s after a load that had already succeeded (seen live twice before the fix: `model loaded` at 0.08 s, harness exit 1). Fixed via `systemctl show -p MainPID`; added `--mode chat`, `--server-arg[=]`, `--warmup-max`, `--memory-max`, `--as-user`.
5. **Flash conclusion of the 2026-11-25 wedge class on this build:** 4 concurrent requests completed; the production unit still pins `--parallel 1` because that probe ran once, for 9 s.

## Changes (all swept into daemon heuristic commits; none committed by hand)

| File | Change |
| ---- | ------ |
| `modules/nixos/services/llama-chat.nix` | `accelerator` (`cpu` \| `igpu`, default `cpu`), `gpuLayers`; package default follows the accelerator; iGPU unit = render group + `rocm.deviceCgroup` + HSA/LD_LIBRARY_PATH env + `--gpu-layers all --load-mode none --parallel 1`; header narrative rewritten; `memoryMax` description states the GTT blind spot |
| `modules/nixos/services/_llama-idle-activity.nix` | export the executable path (Findings 3) |
| `lib/rocm.nix`, `modules/nixos/services/ai-stack.nix` | `llamaCppHip` single-sourced (one derivation for the system wrapper and the unit) |
| `platforms/nixos/system/configuration.nix` | `llama-chat.accelerator = "igpu"` + rationale |
| `scripts/llama-rag-soak.sh` | harness fix + chat mode (Findings 4) |
| `tests/test-llama-chat-accelerator.nix`, `tests/default.nix` | new render test (18 cases) |
| `docs/services/llama-chat.md`, `AGENTS.md`, `docs/todo/ai-stack.md`, `CHANGELOG.md` | runbook, GPU-section correction, queue rows, entry |

## Not done (deliberate)

- **Deploy.** Two reasons: the deploy gates were shut all session (io PSI some 35-60% against the 20% house bar; two foreign `nix` evals at 20+ GB RSS; the tree churning under other sessions), and finding 2 is a stability trade the owner has not seen. The flip is one line to remove if the answer is "not yet".
- **Post-deploy verification on the REAL unit** (the repo's own gate: ≥15 min CPU-time deltas + functional probes + the idle TTL actually holding). Cannot run before a deploy.
- **llama-vlm** (gemma-4-E4B verdicts, qwen3-vl-8b captions) stays CPU. Same mechanism, not soaked.
- **`nixpkgs-llama-rag` unpin** (embeddings on the 1.0.0 HIP build instead of the pinned 0.3.0). The small-model soak passed, but the pin's lift condition is "re-verified live under the real units", which needs a deploy.
- Full `nix flake check --no-build --all-systems`, `buildflow`, VM tests — not run (box load; the evo-x2 toplevel eval and the new check were the targeted gates).
- Vulkan backend: not evaluated. It was the queued "wedge-free" route; the HIP route passed, so it is no longer needed for llama-chat.

## Mistakes and corrections

- My question to the owner said support was "untested" and the earlier browser-history report said "nothing is on a GPU with this build" — true for llama-chat's binary only; the embeddings server and two hermes-spawned duplicates run HIP builds. Corrected in Findings.
- The soak window was cut by me at sample 125 of the harness (no final PASS line) to release 27 GB of pinned GTT while `MemAvailable` sat at 5.3 GB.
- Two harness attempts failed on my own new options before they worked (`--supplementary-groups` is not a `systemd-run` flag; `--server-arg=VALUE` was documented before it was parsed).
- The new test went red four times for scaffolding reasons (module stub shape, missing `services.integration`, `psi-wait-gate` living in the overlay, `toJSON` on DeviceAllow entries) before its first real verdict.

## Follow-ups (harvested into `docs/todo/ai-stack.md`; queue rows only where `[ready]`)

- Post-deploy watch of the iGPU unit (blocked on the deploy).
- Owner decision: make `llama-chat.service` a memory-relief stop target for the memory-emergency-guard, given the cgroup blind spot.
- llama-vlm iGPU flip behind the same sandbox soak (`[ready]`).
- Lift `--parallel 1` after a longer concurrency soak on the real unit.
- Drop `nixpkgs-llama-rag` once the 1.0.0 build is proven under the real embeddings unit.
- Re-scope the Vulkan experiment row: no longer the only route.
