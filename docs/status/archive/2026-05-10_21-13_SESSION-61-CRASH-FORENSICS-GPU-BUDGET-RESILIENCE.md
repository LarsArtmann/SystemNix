# SystemNix Status Report — Session 61

**Date:** 2026-05-10, 21:13 CEST
**Session:** #61 — Crash Forensics Deep-Dive, GPU Budget Architecture, Resilience Hardening
**Host:** evo-x2 (NixOS, x86_64-linux, AMD Ryzen AI Max+ 395, 128 GB RAM, 64 GB VRAM iGPU)
**Branch:** master, pushed to origin
**Commit Base:** `9ac7d18e` (docs: GPU budget update)
**Validation:** `nix flake check` PASSES, all pre-commit hooks green
**Uptime:** 1h 03m (system rebooted after OOM storm at 19:56)

---

## Executive Summary

Session 61 was triggered by a **critical GPU memory exhaustion incident** that crashed the entire desktop at 19:56 CEST, followed by a **17-minute crash cascade** (20:29–20:46). The session performed deep crash forensics, identified the root cause (Ollama dual-runner OOM), and implemented architectural fixes across GPU memory management, service resilience, and documentation.

**4 commits landed.** The GPU memory budget is now properly architected with per-service fractions instead of a dangerous system-wide 95% cap. The awww-daemon crash loop is mitigated. The system is stable but **has not been rebooted since the fixes were committed** — `just switch` is needed to deploy.

---

## System State (as of 21:13 CEST)

| Metric | Value | Status |
|--------|-------|--------|
| **RAM** | 36G / 62G used (58%) | ⚠️ Elevated — 9.0G swap used (residual from OOM) |
| **Swap** | 9.0G / 25G used (zram: 9G, disk: 0) | ⚠️ High — should drain with reboot |
| **GPU VRAM** | 64 GiB total (68,719,476,736 bytes) | ✅ Healthy |
| **Root disk** | 447G / 512G (90%) | ⚠️ Near capacity — 74G Nix store |
| **/data disk** | 681G / 1.0T (67%) | ✅ Healthy |
| **Coredumps** | 52 entries, 1.3G on disk | ⚠️ MaxUse=2G holding, but messy |
| **Load** | 8.58 / 9.36 / 10.76 | ⚠️ Elevated — Ollama just ran models |
| **Journal errors (1h)** | 3,118 | ⚠️ Mostly polkit-agent-helper (crash cascade artifacts) |
| **Docker** | 11 containers running | ✅ All healthy |
| **Ollama models** | 0 loaded | ✅ Clean (models evicted after crash) |
| **Nix store** | 74G | ⚠️ GC recommended |

### Active Docker Containers
| Container | Status |
|-----------|--------|
| whisper-asr | Up ~1h |
| mnfst-manifest-1 | Up ~1h (healthy) |
| mnfst-postgres-1 | Up ~1h (healthy) |
| twenty-server-1 | Up ~1h (healthy) |
| twenty-worker-1 | Up ~1h |
| twenty-db-1 | Up ~1h (healthy) |
| twenty-redis-1 | Up ~1h (healthy) |
| openseo-openseo-1 | Up ~1h |
| deer-flow-nginx | Up ~1h |
| deer-flow-gateway | Up ~1h |
| deer-flow-frontend | Up ~1h |

### /data Storage Breakdown
| Path | Size | Contents |
|------|------|----------|
| /data/models/ | 376G | Legacy AI models (pre-migration) |
| /data/llamacpp-models/ | 142G | LLaMA.cpp standalone models |
| /data/SteamLibrary/ | 99G | Steam games |
| /data/ai/ | 80G | Centralized AI model storage |
| /data/unsloth/ | 28G | Unsloth Studio workspace |
| /data/ollama/ | 151M | Ollama model blobs |

---

## Incident Report: 2026-05-10 GPU Memory Crisis

### Incident 1: OOM Storm (19:56 CEST)

**Root cause:** Ollama loaded two model runners simultaneously (gemma4 + sha256-2e35…) at 19:55:07. Each runner had `per_process_memory_fraction:0.95` = 95% of 73 GiB GPU = **138 GiB demand on 73 GiB pool**.

**Timeline:**
1. `19:55:07` — Ollama starts two runners, logs: `gpu memory available="72.7 GiB" free="73.1 GiB"`
2. `19:56:00` — `amdgpu: [drm] *ERROR* Not enough memory for command submission!` (3×)
3. `19:56:02` — Two kitty instances dump core (SIGABRT) — GPU context lost
4. `19:56:27` — **niri crashes** (SIGABRT) — compositor gone
5. `19:56:33` — Kernel: `36.3 GiB in ttm_pool_alloc_page` — GPU memory pool saturated
6. `19:56:33–37` — OOM killer: helium (1.5 TB vmm!), electron, blueman, systemd-coredump, fish, pipewire, **user systemd**, next-server (13 processes killed)
7. `19:58:02` — `user@1000.service` killed — entire user session destroyed
8. `20:03` — SDDM restarts session

**Impact:** Complete desktop loss, all user processes killed, 13+ processes OOM'd, session recovery required SDDM re-login.

### Incident 2: Crash Cascade (20:29–20:46)

**Root cause:** Niri crashed again (second GPU event) → awww-daemon has no Wayland display → `unwrap()` panic → `Restart=always` causes **15 consecutive crashes** at ~70s intervals.

**Timeline:**
1. `20:29:55` — Two kitty instances dump core
2. `20:29:57` — helium crashes (SIGTRAP + 3× SIGSEGV), niri crashes (SIGABRT)
3. `20:29:58–20:46:42` — awww-daemon: 15× SIGABRT, all `unwrap_failed` in `main()`
4. Each cycle also kills: waybar, cliphist, xdg-desktop-portal-gtk, niri-flake-polkit
5. `~20:47` — Cascade stops, system stabilizes

**Total coredumps:** 24 across 5 processes (awww-daemon: 15, kitty: 4, helium: 4, niri: 1, Xorg: 1)

### Why the Old 95% Cap Was Catastrophic

```
GPU available: 72.7 GiB
Ollama runner 1 × 0.95 = 69.1 GiB  ← alone is fine
Ollama runner 2 × 0.95 = 69.1 GiB  ← total: 138.2 GiB on 72.7 GiB GPU!
+ System-wide env var: every process also gets 0.95 cap
+ ComfyUI: 0.95 cap when enabled
= Guaranteed OOM when any two GPU consumers run simultaneously
```

---

## a) FULLY DONE

### Session 61 — Crash Forensics & GPU Architecture (this session)

| # | Work | Commit | Impact |
|---|------|--------|--------|
| 1 | **Ollama GPU fraction: 0.95→0.45** — prevents dual-runner OOM (2×0.45=0.90 total) | `4b641e93` | Critical — eliminates root cause |
| 2 | **ComfyUI GPU fraction: 0.95→0.50** — Ollama(45%)+ComfyUI(50%)=95% when both active | `4b641e93` | High — prevents contention |
| 3 | **Remove system-wide PYTORCH_CUDA_ALLOC_CONF** — was giving every process 95% GPU cap | `4b641e93` | High — stops implicit GPU claiming |
| 4 | **awww-daemon Wayland check** — ExecStartPre exits 1 if WAYLAND_DISPLAY not set | `23acb090` | Medium — prevents crash loop |
| 5 | **awww-daemon StartLimitBurst: 5/120s→3/300s** — stops 15-crash loops | `23acb090` | Medium — limits cascade damage |
| 6 | **awww-daemon hardening** — NoNewPrivileges, ProtectClock, ProtectHostname, LockPersonality | `93c63a97` | Low — defense in depth |
| 7 | **AGENTS.md GPU budget docs** — per-service fraction table, design decisions, incident docs | `9ac7d18e` | Medium — prevents regression |
| 8 | **Known Issues: 2 new entries** — Ollama dual-runner OOM + awww crash loop | `9ac7d18e` | Medium — institutional memory |

### GPU Memory Budget (New Architecture)

| Service | Fraction | Cap on 73 GiB GPU | Rationale |
|---------|----------|-------------------|-----------|
| Ollama (per runner) | 0.45 | ~33 GiB | Two runners × 0.45 = 90%, leaves 7 GiB for niri |
| ComfyUI | 0.50 | ~36 GiB | Ollama(45%) + ComfyUI(50%) = 95% concurrent |
| gpu-python | 0.95 (configurable) | ~69 GiB | Solo GPU use only; override with `GPU_MEM_FRACTION=0.8` |

### Sessions 54–60 — Carried-Forward Completed Work

| # | Work | Session |
|---|------|---------|
| 9 | Port DRY sprint — eliminated all hardcoded ports | 54 |
| 10 | Boot performance sprint — 22s boot delay eliminated | 51 |
| 11 | OpenSEO deployment — full service module | 52 |
| 12 | Shared lib adoption — all 22 service modules migrated | 55 |
| 13 | Boot diagnostics + desktop fixes | 55 |
| 14 | DNS IPv6 outage fix — `do-ip6 = false` everywhere | 57 |
| 15 | WiFi enablement — NetworkManager + iwd backend | 57 |
| 16 | Dual-WAN with MPTCP | 58 |
| 17 | GPU memory crisis response — TTM ceiling raised | 59 |
| 18 | Architecture relocation sprint — 7 file moves | 60 |

---

## b) PARTIALLY DONE

| Work | What's Done | What's Missing |
|------|-------------|----------------|
| **GPU fixes deployment** | All changes committed and pushed | `just switch` not yet run — changes are NOT live |
| **Coredump cleanup** | Verified `MaxUse=2G` config working | 52 coredumps (1.3G) remain from today — will age out naturally |
| **awww-daemon resilience** | Wayland check + tight burst limits + hardening | Upstream `unwrap()` panic in awww 0.12.0 not fixed (not our code) |
| **Root disk space** | Identified 74G Nix store as main consumer | GC not run — `just clean` needed |
| **Legacy model storage** | `/data/ai/` centralized dir created | `/data/models/` (376G) and `/data/llamacpp-models/` (142G) not migrated |

---

## c) NOT STARTED

| # | Work | Priority | Why |
|---|------|----------|-----|
| 1 | **Deploy session 61 fixes** (`just switch`) | CRITICAL | GPU fixes are NOT live — Ollama still running old 95% cap |
| 2 | **System reboot** | HIGH | 9.0G swap residual from OOM, clean slate needed |
| 3 | **AI model migration** (`just ai-migrate`) | MEDIUM | 376G at `/data/models/` + 142G at `/data/llamacpp-models/` not moved to `/data/ai/` |
| 4 | **Nix store GC** (`just clean`) | MEDIUM | 74G Nix store, root disk at 90% |
| 5 | **DNS failover cluster** — Pi 3 provisioning | LOW | Module exists, hardware not provisioned |
| 6 | **dbus-broker duplicate warnings** — 37 errors/hr | LOW | Cosmetic — duplicate D-Bus service files in system-path |
| 7 | **ComfyUI off by default** — currently `enable = false` but has GPU fraction set | N/A | Pre-configured for when needed |
| 8 | **Monitor Ollama model loading** — detect dual-runner scenarios | LOW | Would benefit from alerting |
| 9 | **niri DRM health warnings** — `Error::DeviceMissing` spamming every 500ms | LOW | Non-fatal but noisy |
| 10 | **dawrin (macOS) platform** — no changes this session | N/A | All work was NixOS-specific |

---

## d) TOTALLY FUCKED UP

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | **Root disk at 90% (447G/512G)** | 🔴 CRITICAL | 74G Nix store + 518G total system. No cleanup run in days. GC is urgent. |
| 2 | **Ollama model list empty** | 🟡 MEDIUM | All models evicted after crash. Need to re-pull commonly used models. |
| 3 | **Swap at 9.0G with no active swap source** (zram carrying all of it) | 🟡 MEDIUM | Residual from OOM. zram is fast but wastes RAM. Reboot needed. |
| 4 | **3,118 journal errors in last hour** | 🟡 MEDIUM | Mostly polkit-agent-helper and dbus-broker duplicates. Not alarming but noisy. |
| 5 | **Legacy /data/models/ (376G) coexists with /data/ai/models/** | 🟠 HIGH | Wastes 376G on /data. Migration planned but not done. DO NOT rm — use `just ai-migrate`. |
| 6 | **Fixes NOT deployed** — changes are in git only, not running system | 🔴 CRITICAL | `just switch` required immediately. |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture & Design

1. **Per-service GPU budget enforcement is manual** — Fractions are set per-service in Nix configs, but there's no runtime guard preventing a user from running `ollama run model1 & ollama run model2` and exceeding the budget. Consider: a GPU resource manager script that checks current allocation before starting new workloads.

2. **No alerting on GPU memory exhaustion** — The amdgpu DRM errors appeared in kernel logs but nothing surfaced them. Gatus monitors HTTP endpoints but not GPU health. Consider: a node_exporter textfile collector or custom Gatus endpoint that checks `mem_info_vram_used` vs `mem_info_vram_total`.

3. **awww-daemon upstream bug unreported** — The `unwrap()` panic on missing Wayland display is an upstream awww 0.12.0 bug. Our ExecStartPre is a workaround, not a fix. Should file an upstream issue requesting graceful error handling.

4. **Coredump MaxUse=2G too generous** — 15 awww-daemon coredumps at 38KB each is fine, but niri and helium coredumps are 7–28MB each. During a real GPU hang, niri dumps 28.5MB each. If the system loops, this fills fast. Consider: lower to 1G or add `Compress=yes` (if not default).

5. **Root disk has no auto-cleanup** — 90% full with no automatic nix-collect-garbage. Consider: add a `nix.gc` timer or expand the existing `default.nix` module's Nix GC to also collect old generations.

6. **StartLimitBurst patterns inconsistent** — Services use varying burst/interval values (3/60, 3/300, 5/120, 5/600) with no documented rationale. Consider: standardize into `serviceTypes` in `lib/types.nix`.

### Operational

7. **`just switch` not run after critical fixes** — We committed GPU fixes but didn't deploy. The running system still has 0.95 fraction. This is a process gap: after committing critical fixes, deploy immediately.

8. **No incident runbook** — When the GPU OOMs and niri crashes, there's no documented recovery procedure. The `niri-drm-healthcheck` timer handles DRM zombie state, but the full OOM recovery flow (kill AI workloads → wait for GPU drain → restart compositor) isn't documented.

9. **Polkit authentication agent crash loop** — During the crash cascade, `niri-flake-polkit.service` crashed repeatedly ("no Qt platform plugin"). This is a non-critical service but it generates noise. Consider: add StartLimitBurst or make it PartOf graphical-session properly.

### Type Model Improvements

10. **`serviceTypes` could include StartLimitBurst presets** — Currently `lib/types.nix` provides `systemdServiceIdentity` and `servicePort`. Adding `startLimitPolicy` with named presets (e.g., `aggressive` for 3/60, `conservative` for 3/300, `relaxed` for 5/600) would standardize burst limits across all services.

11. **GPU memory budget could be a module option** — Instead of scattering `per_process_memory_fraction` across multiple files, create `services.gpu-budget` with options for each consumer's fraction. The module would validate that the sum doesn't exceed a safe threshold.

---

## f) TOP 25 THINGS TO DO NEXT

### Immediate (do now)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **`just switch`** — deploy all GPU + awww fixes | CRITICAL | 5 min |
| 2 | **Reboot** — clear 9G swap residual, start clean | HIGH | 2 min |
| 3 | **`just clean`** — Nix GC, root disk at 90% | HIGH | 10 min |

### High Priority (this week)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 4 | **Pull commonly-used Ollama models** back | HIGH | 5 min |
| 5 | **Run `just ai-migrate`** — move 376G legacy models → /data/ai/ | HIGH | 30 min |
| 6 | **Add GPU memory monitoring** to Gatus (VRAM used/total) | HIGH | 30 min |
| 7 | **Create incident runbook** for GPU OOM recovery | MEDIUM | 15 min |
| 8 | **File upstream bug** for awww-daemon unwrap() panic | MEDIUM | 10 min |

### Medium Priority (next 2 weeks)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 9 | **Standardize StartLimitBurst** into `lib/types.nix` presets | MEDIUM | 1h |
| 10 | **Add `nix.gc` automatic timer** for root disk management | MEDIUM | 30 min |
| 11 | **Lower coredump MaxUse** to 1G (from 2G) | LOW | 5 min |
| 12 | **Fix polkit-agent crash loop** — add StartLimitBurst or PartOf | MEDIUM | 15 min |
| 13 | **Clean up dbus-broker duplicate service files** | LOW | 30 min |
| 14 | **Create GPU budget module** with validation (`services.gpu-budget`) | MEDIUM | 2h |
| 15 | **Monitor Ollama concurrent runners** — alert when >1 active | MEDIUM | 1h |

### Lower Priority (backlog)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 16 | **Provision Pi 3** for DNS failover cluster | HIGH (resilience) | 2h (hardware) |
| 17 | **Review niri DRM health warnings** (Error::DeviceMissing spam) | LOW | 1h |
| 18 | **Review /data/llamacpp-models/** (142G) — migrate or deduplicate with /data/ai/models/gguf/ | MEDIUM | 1h |
| 19 | **Audit all user services** for missing hardening (like awww was) | MEDIUM | 2h |
| 20 | **Add `Compress=yes`** to coredump config | LOW | 5 min |
| 21 | **Test GPU budget under load** — run Ollama + ComfyUI simultaneously | HIGH (validation) | 30 min |
| 22 | **Review Darwin platform** — no changes in 3 sessions | LOW | 1h |
| 23 | **Create Gatus endpoint for swap usage** (9G swap = warning) | LOW | 15 min |
| 24 | **Document `OLLAMA_NUM_PARALLEL`** interaction with GPU budget | LOW | 10 min |
| 25 | **Evaluate amdgpu TTM pool limit** — currently 112G ceiling from session 59 | LOW | 30 min |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why did Ollama start two model runners simultaneously at 19:55:07?**

The logs show:
```
19:53:35 — ollama POST /api/generate (6.8s response — inference on one model)
19:55:07 — "starting runner" (gemma4: token IDs...)
19:55:08 — "starting runner" (--model sha256-2e35...) ← SECOND runner, same second
```

I cannot determine from the logs alone whether:
- Was this a **single API request** that triggered two model loads (e.g., tool-calling / multi-model pipeline)?
- Was it **two concurrent requests** from two different clients (e.g., Crush + Hermes)?
- Was it an **OLLAMA_NUM_PARALLEL=2** side-effect where the scheduler split into separate runners?
- Was one a **keep-alive reload** of an existing model?

The `OLLAMA_NUM_PARALLEL=2` setting controls concurrent *batches* within a single runner, not multiple runners. Two separate runners means two separate `ollama runner` processes — this is the multi-model scenario. But I can't tell from the GIN logs alone what triggered it.

**Action needed:** Check Ollama's access logs or the application that made the API calls to determine if this was intentional multi-model usage or a scheduling bug. This matters because our new 0.45 fraction assumes two runners could exist — but if three could ever exist (0.45×3=135%), we'd still OOM.

---

## Git State

```
Branch: master (pushed to origin)
HEAD: 9ac7d18e docs: update GPU memory budget and document dual-runner OOM incident
Dirty: flake.lock (updated by flake check — not committed)
Untracked: none
```

### Today's Commits (2026-05-10)

| Time | Commit | Description |
|------|--------|-------------|
| ~15:21 | `d5e7e350` | fix(dns-blocker): disable IPv6 in Unbound |
| ~15:21 | `b69e5928` | fix(justfile): add validate recipe |
| ~15:21 | `431d44de` | fix(nix): lower connect-timeout |
| ~15:21 | `b69e5928` | fix(dns): harden DNS monitoring |
| ~15:21 | `d5e7e350` | feat(nixos/networking): enable NetworkManager for WiFi |
| ~18:19 | `a121b268` | docs(status): session 58 |
| ~18:19 | `a8320c2a` | feat(scripts): add mptcp-endpoint-manager |
| ~18:19 | `aeb456a3` | fix(scripts): fix route-health-monitor regex |
| ~18:19 | `d2823cb3` | feat(networking): add dual-wan module |
| ~18:19 | `a295f383` | fix(dual-wan): correct serviceDefaults usage |
| ~18:19 | `25b1fa84` | fix(dual-wan): add missing path |
| ~20:52 | `ed57c383` | docs(status): session 59 |
| ~20:52 | `95101f3d` | docs(agents): document lib/default.nix pattern |
| ~20:52 | `7d8b2e1d` | refactor(lib): add default.nix single import |
| ~20:52 | `b98f99a0` | refactor(modules): migrate 22 modules to lib/default.nix |
| ~20:52 | `b9b02659` | refactor(scripts): extract shared lib.sh |
| ~20:52 | `2eddaf47` | refactor(taskchampion): extract port option |
| ~20:52 | `2e185493` | refactor: migrate deprecated dotfiles |
| ~21:05 | `16d194ae` | docs(status): session 60 |
| ~21:05 | `d88d80ca` | refactor(nixos/dns-blocker): migrate to flake-parts |
| ~21:05 | `5da2a843` | chore(flake.lock): update lockfile |
| ~21:05 | `62d5de0f` | perf(gpu): raise GTT/TTM ceiling to 112GB |
| ~21:05 | `42e28ca0` | fix(gpu): reduce PyTorch fraction from 95% to 45% |
| ~21:10 | `4b641e93` | fix(gpu): lower per-process memory fractions (root cause) |
| ~21:10 | `23acb090` | fix(awww): prevent crash loop |
| ~21:11 | `93c63a97` | harden(awww): add sandboxing |
| ~21:12 | `9ac7d18e` | docs: GPU budget + incident docs |

**27 commits today** across sessions 57–61.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Commits this session | 4 |
| Files changed | 4 (ai-stack.nix, comfyui.nix, niri-wrapped.nix, AGENTS.md) |
| Lines changed | +27 / -12 |
| Coredumps analyzed | 24 |
| Root causes identified | 2 (Ollama dual-runner OOM, awww unwrap panic) |
| Services hardened | 1 (awww-daemon) |
| Services fixed | 2 (Ollama GPU cap, awww-daemon crash loop) |
| Incidents documented | 2 new Known Issues |
| Time to root cause | ~10 min (Ollama logs), ~5 min (awww stack trace) |
| Uncommitted changes | `flake.lock` (updated by flake check) |
