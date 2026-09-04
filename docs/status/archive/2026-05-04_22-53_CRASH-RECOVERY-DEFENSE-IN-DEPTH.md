# SystemNix — Comprehensive Status Report

**Date:** 2026-05-04 22:53 CEST | **Session:** 23 | **Uptime:** 17 min (post hard-crash reboot)
**Branch:** master | **Host:** evo-x2 (AMD Ryzen AI Max+ 395, 128GB, NixOS)

---

## Executive Summary

System required a **hard power cut** because Hermes's `anime-comic-pipeline` (PyTorch + AMD ROCm/HIP) SIGSEGV'd in `libamdhip64.so`, hanging the GPU driver and freezing the entire desktop with zero recovery options. This session diagnosed the root cause and implemented **6 layers of defense-in-depth** crash recovery. Build validated. Changes pending `just switch`.

---

## a) FULLY DONE

### Crash Recovery Defense-in-Depth (this session)

All 6 layers implemented in `platforms/nixos/system/boot.nix`:

| # | Layer                    | Setting                       | Effect                                                             |
| - | ------------------------ | ----------------------------- | ------------------------------------------------------------------ |
| 1 | Keyboard recovery        | `kernel.sysrq = 1`            | Alt+SysRq+REISUB emergency reboot now works (was `16` = sync-only) |
| 2 | Kernel panic auto-reboot | `kernel.panic = 30`           | Reboots 30s after panic (was `0` = hang forever)                   |
| 3 | Soft lockup panic        | `kernel.softlockup_panic = 1` | Reboots on CPU stuck in kernel with interrupts disabled            |
| 4 | Hung task panic          | `kernel.hung_task_panic = 1`  | Reboots after 120s of tasks stuck in D state                       |
| 5 | Hardware watchdog        | `watchdogd` (SP5100 TCO)      | Hard reset if completely unresponsive for 30s (pet every 10s)      |
| 6 | GPU self-recovery        | `amdgpu.gpu_recovery=1`       | Driver attempts GPU reset on hang instead of staying dead          |

Also: `kernel.watchdog_thresh = 20` (raised from 10 to avoid GPU compute false positives), `vm.panic_on_oom = 0` (earlyoom handles OOM, don't double-panic).

### Awww Wallpaper Daemon Hardening (this session)

- Relaxed restart limits: `StartLimitBurst = 5` (from 10), `StartLimitIntervalSec = 120` (from 60)
- Replaced `BindsTo` → `Wants` for wallpaper-setter (BindsTo killed it when daemon restarted)
- Increased retry loops: 30 → 60 attempts, `RestartSec = 5s` (from 3s)

### AGENTS.md Updated

- Documented GPU hang recovery in Known Issues table
- All 6 defense layers described with reference to `boot.nix`

### Master TODO Plan Progress: 65% (62/95 tasks)

| Category         | Done | Total | %    |
| ---------------- | ---- | ----- | ---- |
| P0 CRITICAL      | 6    | 6     | 100% |
| P1 SECURITY      | 3    | 7     | 43%  |
| P2 RELIABILITY   | 11   | 11    | 100% |
| P3 CODE QUALITY  | 9    | 9     | 100% |
| P4 ARCHITECTURE  | 7    | 7     | 100% |
| P5 DEPLOY/VERIFY | 0    | 13    | 0%   |
| P6 SERVICES      | 9    | 15    | 60%  |
| P7 TOOLING/CI    | 10   | 10    | 100% |
| P8 DOCS          | 5    | 5     | 100% |
| P9 FUTURE        | 2    | 12    | 17%  |

### Recent Sessions (last 2 weeks)

| Session | What                                                                  |
| ------- | --------------------------------------------------------------------- |
| 22      | jscpd promoted to system package, full code audit                     |
| 21      | systemd watchdog massacre fix, deep cleanup/architecture improvements |
| 20      | Go overlay removal, niri script extraction, justfile ghost cleanup    |
| 19      | DNS privacy overhaul — recursive resolution, root hints               |
| 18      | Rust target cleanup hardening, disk monitor                           |
| 15-17   | Dead code audit, flake migration (path: → git+ssh:), Pareto planning  |
| 13-14   | Post-reboot service recovery, systemd hardening standardization       |
| 10-12   | Go tool packaging (18 CLI tools), build fixes, emeet-pixyd extraction |

---

## b) PARTIALLY DONE

### Hermes AI Gateway

- **Working:** System service, sops secrets, restart policy, GPU access, state migration, Xiaomi MiMo provider
- **Missing:** Health check endpoint (#62), full key_env migration (#63), MemoryMax=4G (may be too low for PyTorch/ROCm workloads)

### SigNoz Observability

- **Working:** Full stack (ClickHouse + OTel Collector + Query Service), node_exporter, cAdvisor, journald receiver
- **Missing:** Metric endpoint verification for 10 services (#65), Authelia SMTP notifications (#66)

### Niri Session Save/Restore

- **Working:** 60s timer saves windows/workspaces/kitty state, restores on startup with workspace-aware placement
- **Missing:** Real-time save via niri event-stream (#94), integration tests (#95), Waybar stats module (#93)

### DNS Infrastructure

- **Working:** Unbound recursive resolver, 2.5M+ blocked domains, dnsblockd block page, `.home.lan` records
- **Missing:** Pi 3 failover node not provisioned, VRRP auth in plaintext (#11)

---

## c) NOT STARTED

| Task                                                                        | Priority | Why Not Started                        |
| --------------------------------------------------------------------------- | -------- | -------------------------------------- |
| P5: Deploy all pending changes to evo-x2                                    | HIGH     | Requires `just switch` — user decision |
| P5: Verify Ollama/Steam/ComfyUI/Caddy/SigNoz/Authelia/PhotoMap post-rebuild | HIGH     | Blocked on `just switch`               |
| P5: Build Pi 3 SD image + flash + boot                                      | MEDIUM   | Hardware not provisioned               |
| P1: Move Taskwarrior encryption to sops (#7)                                | MEDIUM   | Needs evo-x2 for sops secret creation  |
| P1: Pin Docker digests for Voice Agents + PhotoMap (#9, #10)                | MEDIUM   | Needs evo-x2 to pull SHA256 digests    |
| P1: Secure VRRP auth_pass with sops (#11)                                   | MEDIUM   | Needs evo-x2 for sops secret           |
| P6: Hermes health check endpoint (#62)                                      | LOW      | Needs Hermes upstream changes          |
| P6: SigNoz missing metrics (#65)                                            | LOW      | Needs metric endpoint verification     |
| P6: Authelia SMTP notifications (#66)                                       | LOW      | Needs SMTP credentials                 |
| P9: All 10 future/research tasks (#86-96)                                   | LOW      | Future planning items                  |

---

## d) TOTALLY FUCKED UP

### Root Partition 88% Full (512GB)

`/` is at 433G/512G — only **62GB free**. `/nix/store` alone is 92GB. This is the **#1 infrastructure risk**. Old generations, docker images, and build artifacts are consuming space.

### Hermes anime-comic-pipeline GPU Crash

Hermes's PyTorch/ROCm pipeline SIGSEGV'd in `libamdhip64.so` → GPU driver hang → full desktop freeze → hard power cut. The fix is defense-in-depth (done), but the **root cause** (unstable PyTorch + ROCm + HIP stack on Strix Halo) is NOT fixed. It will crash again.

### AMD GPU Metrics Broken

`amdgpu.prom` has empty `node_amdgpu_gpu_busy_percent` value — `node_exporter` errors on every scrape cycle (every 30s). The metrics collector script is outputting malformed data.

### ClamAV Freshclam Failed

`clamav-freshclam.service` is in failed state. Virus database updater not running.

### Whisper ASR Container Crash-Looping

Docker container `whisper-asr` is `Restarting (2) 5 seconds ago` — stuck in a crash loop.

### Memory Pressure After Reboot (17 min uptime)

Already at **60GB/62GB used** with **25GB swap consumed**. That's extreme for a fresh boot. Hermes + PyTorch + ROCm are likely the culprits. The `MemoryMax = 4G` on hermes service may not cover the anime-comic-pipeline venv which loads PyTorch + ROCm libraries.

### service-health-check.service Failed

Health check service itself is failing — ironic and means service degradation goes undetected.

---

## e) WHAT WE SHOULD IMPROVE

1. **Root disk space** — 88% is a ticking time bomb. Need generation cleanup (`nix-collect-garbage -d`), docker image pruning, and possibly moving more data to `/data`.
2. **Hermes MemoryMax** — 4G may be insufficient for PyTorch/ROCm workloads. The anime-comic-pipeline venv loads massive GPU libraries. Should monitor actual usage and adjust.
3. **GPU isolation** — Niri (compositor) and Hermes (compute) share the same GPU. No cgroup device isolation. If compute crashes the GPU, the desktop dies. Consider cgroup device whitelisting or running heavy compute in a container with limited GPU access.
4. **Hermes crash resilience** — The anime-comic-pipeline should catch SIGSEGV gracefully or be sandboxed so a crash doesn't take down the GPU driver.
5. **AMD GPU metrics** — Fix the `amdgpu.prom` textfile collector. Every 30s it logs an error and provides no GPU utilization data to SigNoz.
6. **Monitoring gaps** — `service-health-check.service` is failed. If health checks don't run, service degradation is invisible. Fix the checker.
7. **Watchdogd meminfo critical = 0.98** — Reboots at 98% RAM. With earlyoom at 10% free threshold, there's overlap. earlyoom should catch it first, but the ordering should be verified.
8. **No TODO_LIST.md** — Master plan lives in `docs/status/MASTER_TODO_PLAN.md` but there's no top-level TODO_LIST.md. The todo-list-builder skill could generate one.
9. **Docker container health** — whisper-asr crash-looping. Should have OnFailure notification or at least alerting via the health check service.
10. **ClamAV** — Either fix freshclam or remove it. A failed service is worse than no service (it trains you to ignore failures).

---

## f) Top 25 Things We Should Get Done Next

| #  | Task                                                                    | Priority | Est. | Impact                                      |
| -- | ----------------------------------------------------------------------- | -------- | ---- | ------------------------------------------- |
| 1  | `just switch` — deploy crash recovery + all pending changes             | P0       | 45m  | **All fixes are code-only until deployed**  |
| 2  | Nix generation cleanup — `nix-collect-garbage -d` + docker system prune | P0       | 15m  | Recover 50-100GB on root partition          |
| 3  | Fix AMD GPU metrics (`amdgpu.prom` empty value)                         | P1       | 15m  | Stop 30s error spam, restore GPU monitoring |
| 4  | Fix `service-health-check.service`                                      | P1       | 10m  | Restore service degradation detection       |
| 5  | Investigate whisper-asr crash loop                                      | P1       | 15m  | Stop container restart spam                 |
| 6  | Fix or remove clamav-freshclam                                          | P1       | 5m   | Eliminate failed service noise              |
| 7  | Increase Hermes MemoryMax from 4G → 8G (PyTorch/ROCm)                   | P1       | 5m   | Prevent OOM kills during ML workloads       |
| 8  | Verify crash recovery works: test SysRq, watchdogd status               | P1       | 10m  | Confirm the entire reason for this session  |
| 9  | Pin Docker image digests for Voice Agents + PhotoMap (#9, #10)          | P1       | 10m  | Supply chain security                       |
| 10 | Move Taskwarrior encryption secret to sops (#7)                         | P1       | 10m  | Remove hardcoded secrets                    |
| 11 | Secure VRRP auth_pass with sops (#11)                                   | P1       | 10m  | Remove plaintext passwords                  |
| 12 | Verify Ollama works post-rebuild (#42)                                  | P2       | 5m   | Core AI infrastructure                      |
| 13 | Verify ComfyUI works post-rebuild (#44)                                 | P2       | 5m   | Image generation                            |
| 14 | Verify SigNoz collecting metrics/logs/traces (#46)                      | P2       | 5m   | Observability                               |
| 15 | Verify Caddy HTTPS block page (#45)                                     | P2       | 3m   | DNS stack integrity                         |
| 16 | Check PhotoMap service status (#48)                                     | P2       | 3m   | Photo management                            |
| 17 | Add Hermes health check endpoint (#62)                                  | P2       | 30m  | Service reliability                         |
| 18 | Add SigNoz missing metrics for 10 services (#65)                        | P2       | 60m  | Full observability coverage                 |
| 19 | Build Pi 3 SD image (#50)                                               | P2       | 30m+ | DNS failover cluster                        |
| 20 | Fix root partition sizing — move more to /data                          | P2       | 30m  | Long-term disk health                       |
| 21 | Create TODO_LIST.md from all docs                                       | P3       | 15m  | Project tracking                            |
| 22 | Add real-time niri session save via event-stream (#94)                  | P3       | 60m  | Better crash recovery                       |
| 23 | Investigate GPU compute/display isolation (cgroups)                     | P3       | 120m | Prevent GPU crash cascading                 |
| 24 | Add Waybar module for session restore stats (#93)                       | P3       | 30m  | Desktop UX                                  |
| 25 | Investigate binary cache (Cachix) for faster rebuilds (#92)             | P3       | 60m  | Developer experience                        |

---

## g) Top #1 Question I Cannot Figure Out Myself

**What was running in Hermes's `anime-comic-pipeline` venv at 21:24 that triggered the GPU SIGSEGV?**

The coredump shows: PID 1688183, `/home/hermes/venvs/anime-comic-pipeline/bin/python3`, crash in `libamdhip64.so` (AMD HIP runtime). The stack trace references ROCm's HIP memory management. But:

- Was this an automated cron job? A user-triggered command? A background task?
- Is this pipeline stable on Strix Halo, or does it crash regularly?
- Should it have GPU access at all, or should it be sandboxed?

The coredump file is **missing** (`coredumpctl info` shows "missing"), so I can't get the full stack trace. Without knowing what triggered it, we can't prevent the next crash — we can only recover from it (which we've now done).

---

## System Health Snapshot

```
Uptime:     17 minutes (post hard-crash reboot)
Nix check:  PASS
Niri:       Running
Memory:     60G/62G used (96%) — 25G swap used ← CRITICAL
Root disk:  88% used (62G free) ← WARNING
Data disk:  74% used (210G free)
Failed:     clamav-freshclam.service, service-health-check.service
Containers: whisper-asr crash-looping, twenty-* healthy
GPU:        Metrics broken (amdgpu.prom empty value)
Watchdog:   NOT YET ACTIVE (pending just switch)
SysRq:      NOT YET ACTIVE (pending just switch)
```

---

## Changed Files (this session)

| File                                        | Changes                                                                  |
| ------------------------------------------- | ------------------------------------------------------------------------ |
| `platforms/nixos/system/boot.nix`           | +28 lines: kernel crash recovery sysctls, watchdogd, amdgpu.gpu_recovery |
| `platforms/nixos/programs/niri-wrapped.nix` | Awww daemon: relaxed restart limits, BindsTo→Wants, retry increases      |
| `AGENTS.md`                                 | GPU hang recovery documented in Known Issues                             |
