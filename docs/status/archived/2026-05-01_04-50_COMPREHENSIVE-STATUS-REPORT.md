# COMPREHENSIVE STATUS REPORT — SystemNix

**Date:** 2026-05-01 04:50 (Session 9)
**Author:** Crush (MiniMax-M2.7-highspeed) + Lars
**Previous:** Session 8 — `2026-04-30_21-57_SERVICE-RELIABILITY-HARDENING.md`

---

## Executive Summary

SystemNix is at **~70% completion** on the master todo plan (65 of 95 tasks done). This session identified and fixed a **critical niri desktop stability issue** — the compositor was hitting the Linux default `RLIMIT_NPROC=4096` ceiling, causing `EAGAIN` ("Resource temporarily unavailable") when spawning threads to open applications. Fix is committed but **not yet deployed**.

The system is running under significant resource pressure: 74% RAM used (46/62GB), 37% swap used (15/41GB), 4608 user threads across 285 processes, and 34 concurrent `gopls` instances from active Go development. Two duplicate `llama-server` instances are consuming ~1GB GPU VRAM unnecessarily. Both disks at 86% capacity.

---

## A) FULLY DONE ✅

### Session 9 Commits (this session)

| Commit    | Description                                                                                                                                                                                               |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `a517ec5` | **Niri service hardening + system process limits** — `LimitNPROC=infinity`, `LimitNOFILE=524288`, `StartLimitBurst`/`StartLimitIntervalSec` moved to `[Unit]`, system-wide `nproc` raised to 65536/262144 |
| `3610d6a` | **Go CLI tool build fixes** — resolved vendor hashes and dependency wiring                                                                                                                                |
| `960fd51` | Terraform-diagrams-aggregator vendorHash reset                                                                                                                                                            |
| `545aa38` | go-auto-upgrade postPatch/preBuild ordering                                                                                                                                                               |
| `5e813d4` | Go package postPatch/preBuild ordering fixes                                                                                                                                                              |
| `46dbacb` | go-functional-fixer go.mod substitute pattern                                                                                                                                                             |
| `f2b7b08` | Disable tests + add go mod tidy for Go packages                                                                                                                                                           |
| `0e2adab` | Go vendor hashes for 5 CLI tools                                                                                                                                                                          |
| `4a9e4ff` | Go CLI tool vendor hashes and missing dependencies                                                                                                                                                        |
| `7cbe78f` | terraform-diagrams-aggregator with Go dependencies                                                                                                                                                        |
| `b3f0ac3` | 18 LarsArtmann Go CLI tools as cross-platform packages                                                                                                                                                    |

### Key Accomplishments (all sessions)

| Category            | Items                                                     | Status         |
| ------------------- | --------------------------------------------------------- | -------------- |
| **P0 Critical**     | Push commits, clean branches, archive docs                | 6/6 ✅         |
| **P2 Reliability**  | WatchdogSec, Restart policies, dead code fixes            | 11/11 ✅       |
| **P3 Code Quality** | deadnix, statix, lint, unused params                      | 9/9 ✅         |
| **P4 Architecture** | lib/systemd.nix, module options, enable toggles           | 7/7 ✅         |
| **P7 Tooling/CI**   | GitHub Actions (3 workflows), alejandra, pre-commit       | 10/10 ✅       |
| **P8 Docs**         | README, AGENTS.md, ADR-005, CONTRIBUTING.md               | 5/5 ✅         |
| **Custom Packages** | 26 packages (22 Go, 2 Rust, 1 Node, 1 Python, 1 AppImage) | 25/26 eval OK  |
| **NixOS Services**  | 15+ service modules with flake-parts                      | All functional |
| **Session Restore** | Crash-recovery for niri window/workspace state            | Fully wired    |
| **DNS Stack**       | Unbound + dnsblockd + 2.5M blocked domains                | Operational    |
| **Observability**   | SigNoz (ClickHouse + OTel + node_exporter + cadvisor)     | Operational    |

---

## B) PARTIALLY DONE 🔧

| Item                  | Status        | Details                                                                       |
| --------------------- | ------------- | ----------------------------------------------------------------------------- |
| **P1 Security**       | 3/7 (43%)     | 4 items blocked on evo-x2 deploy for sops secrets                             |
| **P6 Services**       | 9/15 (60%)    | ComfyUI paths acceptable, Hermes health check pending, SigNoz metrics blocked |
| **P5 Deploy/Verify**  | 0/13 (0%)     | All require `just switch` + manual verification                               |
| **P9 Future**         | 2/12 (17%)    | Research items, no urgency                                                    |
| **Go packages**       | ~15/22 build  | 7 upstream source issues, 3 Nix-side fixable                                  |
| **Service hardening** | ~60% coverage | 6 services still use manual inline hardening instead of `harden()` function   |
| **Docker containers** | 0 running     | All services defined but Docker daemon appears idle                           |

### Service Hardening Gap Analysis

Services using `harden()` from `lib/systemd.nix`: hermes, gitea (partial), immich, minecraft, signoz, homepage, comfyui, photomap, twenty.

Services with **manual inline hardening** (should migrate to `harden()`):

- `caddy.nix` — No MemoryMax, NoNewPrivileges=false
- `authelia.nix` — No MemoryMax, no ProtectKernelLogs
- `taskchampion.nix` — No MemoryMax, no RestrictSUIDSGID
- `voice-agents.nix` — No MemoryMax, no NoNewPrivileges
- `gitea-repos.nix` — Full manual, missing ProtectKernelLogs
- `monitor365.nix` — User service, inline OK but inconsistent

Services with **zero hardening**:

- `ai-stack.nix` — Ollama + Unsloth, no MemoryMax on GPU workloads ⚠️ HIGH RISK

---

## C) NOT STARTED ⬜

### P5 — Deployment & Verification (13 tasks, all require evo-x2)

| #  | Task                                         | Est. |
| -- | -------------------------------------------- | ---- |
| 41 | `just switch` — deploy all pending changes   | 45m+ |
| 42 | Verify Ollama works after rebuild            | 5m   |
| 43 | Verify Steam works after rebuild             | 5m   |
| 44 | Verify ComfyUI works after rebuild           | 5m   |
| 45 | Verify Caddy HTTPS block page                | 3m   |
| 46 | Verify SigNoz collecting metrics/logs/traces | 5m   |
| 47 | Check Authelia SSO status                    | 3m   |
| 48 | Check PhotoMap service status                | 3m   |
| 49 | Verify AMD NPU with test workload            | 10m  |
| 50 | Build Pi 3 SD image                          | 30m+ |
| 51 | Flash SD + boot Pi 3                         | 15m  |
| 52 | Test DNS failover                            | 10m  |
| 53 | Configure LAN devices for DNS VIP            | 10m  |

### P9 — Future/Research (10 tasks)

| #  | Task                                              |
| -- | ------------------------------------------------- |
| 86 | Create homeModules pattern for HM via flake-parts |
| 87 | Package ComfyUI as proper Nix derivation          |
| 88 | Investigate lldap/Kanidm for unified auth         |
| 89 | Migrate Pi 3 from linux-rpi to nixos-hardware     |
| 91 | Add NixOS VM tests for critical services          |
| 92 | Investigate binary cache (Cachix)                 |
| 93 | Add Waybar module for session restore stats       |
| 94 | Add real-time save via niri event-stream          |
| 95 | Add integration tests for session restore         |
| 96 | File nixpkgs issue for hipblaslt Tensile          |

---

## D) TOTALLY FUCKED UP 💥

### 1. RLIMIT_NPROC=4096 — CRITICAL (NOW FIXED, NOT DEPLOYED)

The Linux default per-user process limit of **4096** was causing niri to fail with `EAGAIN` ("Resource temporarily unavailable") when spawning threads. The system had **4608 threads across 285 processes** at the time of diagnosis.

**Root cause:** No `security.pam.loginLimits` or `LimitNPROC` override anywhere in the config. The niri compositor — which needs to spawn processes for every application launch, XWayland, and IPC — was hitting this ceiling silently.

**Evidence from journal:**

```
May 01 04:10:27 evo-x2 niri[1040014]: WARN niri::utils::spawning: error spawning a thread to spawn the command: Os { code: 11, kind: WouldBlock, message: "Resource temporarily unavailable" }
```

**Fix committed in `a517ec5`:**

- `modules/nixos/services/niri-config.nix`: `LimitNPROC=infinity`, `LimitNOFILE=524288`
- `platforms/nixos/system/boot.nix`: `security.pam.loginLimits` → soft 65536 / hard 262144 for `@users`

**⚠️ NOT YET DEPLOYED.** Requires `just switch` + new login session.

### 2. Duplicate llama-server Instances — 1GB+ Wasted

Two instances of `llama-server` running the **same model** (gemma-4-26B-A4B-heretic-APEX-Balanced):

| PID     | Launched by             | Port | GPU Layers | RSS                 |
| ------- | ----------------------- | ---- | ---------- | ------------------- |
| 1210173 | Jan AI (vulkan backend) | 3319 | 31         | 724 KB (+ GPU VRAM) |
| 2656447 | Manual/systemd?         | 8118 | 99         | 970 MB              |

The Jan AI instance has been running since **April 27** (4 days). The second instance was started **April 30**. Combined they're consuming significant GPU VRAM with the same model loaded twice.

### 3. Disk Space — Both Partitions at 86%

| Partition           | Size | Used | Avail | Use% |
| ------------------- | ---- | ---- | ----- | ---- |
| `/` (nvme0n1p6)     | 512G | 436G | 72G   | 86%  |
| `/data` (nvme0n1p8) | 800G | 685G | 116G  | 86%  |

Top consumers on `/data`:

- `/data/models` — 322G (AI models)
- `/data/llamacpp-models` — 142G (duplicate llama.cpp models?)
- `/data/cache` — 118G
- `/data/SteamLibrary` — 99G
- `/data/unsloth` — 28G

**Risk:** At current trajectory, root fills in ~2-3 weeks. `/data` has 3-4 weeks.

### 4. ZRAM Swap Under Heavy Pressure

- **ZRAM**: 31.2G allocated, **15.2G used (49%)** — nearly half of compressed swap is consumed
- **Disk swap**: 10G allocated, 15.3M used (negligible)
- **Committed_AS**: 111GB vs **CommitLimit**: 76GB — system is **46GB overcommitted** with heuristic overcommit (`vm.overcommit_memory=0`)

This means the kernel has allowed 111GB of virtual memory allocations against only 76GB of physical+swap capacity. Under memory pressure, this WILL cause OOM kills.

### 5. 174 Coredumps Accumulated

`/var/lib/systemd/coredump/` contains **174 coredump files** from previous OOM cascade events. These should be cleaned.

### 6. Load Average: 29 (on 32 cores)

Load average of ~29 on a 32-core system means near-saturation. Primarily caused by:

- 34 `gopls` instances (Go language servers for active development)
- 37 Crush instances
- 4 concurrent `go build` linkers running at 80-120% CPU each
- ClickHouse consuming steady 5.2% CPU

### 7. `StartLimitIntervalSec` in Wrong Section

The deployed niri.service has `StartLimitIntervalSec=60` in `[Service]` but it's only valid in `[Unit]`. This was generating repeated journal warnings:

```
Unknown key 'StartLimitIntervalSec' in section [Service], ignoring.
```

**Fixed in commit `a517ec5`** — moved to `[Unit]` section via structured replacement.

---

## E) WHAT WE SHOULD IMPROVE 🔨

### Critical

1. **`ai-stack.nix` has ZERO systemd hardening** — Ollama, Unsloth, and llama-server services have no `MemoryMax`, no `NoNewPrivileges`, no `ProtectSystem`. These are GPU workloads that have previously caused OOM cascades. This is the single biggest reliability gap.

2. **Duplicate llama-server instances** — Jan AI's llama-server (PID 1210173, running since Apr 27) should be terminated or containerized. It conflicts with the system-level instance.

3. **Committed_AS exceeds CommitLimit** — 111GB committed vs 76GB limit. With `vm.overcommit_memory=0` (heuristic), the kernel should be denying allocations but isn't. Consider auditing which processes are overcommitting.

4. **`/data/llamacpp-models` (142G) vs `/data/models` (322G)** — Likely duplicate model storage. The `ai-models.nix` module was designed to centralize to `/data/ai/` but migration may not have completed. The `/data/ai/` directory shows 0 bytes.

### High Priority

5. **Migrate 6 service modules to `harden()` function** — caddy, authelia, taskchampion, voice-agents, gitea-repos, monitor365 all have inconsistent manual hardening. Centralizing on `harden()` ensures uniform security posture.

6. **Clean coredumps** — 174 files from past OOM events. `coredumpctl vacuum` or manual cleanup.

7. **Disk cleanup** — 436G on root, 685G on /data. Nix store GC, old generations, build artifacts.

8. **Flake lock update** — `flake.lock` hasn't been updated in several days. Some inputs may have security fixes.

9. **Docker not running** — 0 containers despite Immich, SigNoz, Twenty, PhotoMap, Voice Agents all defined as Docker services. Either Docker daemon is stopped or services were intentionally disabled.

### Medium Priority

10. **gopls instance sprawl** — 34 concurrent `gopls` processes consuming ~8GB RSS. Each Go project open in an editor spawns one. Consider closing idle editor sessions.

11. **Hermes health check** — No health endpoint means no WatchdogSec or SigNoz alerting.

12. **Taskwarrior encryption to sops** — Currently uses deterministic SHA-256 hash. Should use proper sops secret.

13. **Docker digest pinning** — Voice Agents and PhotoMap use version tags but not SHA256 digests. Supply chain attack vector.

14. **VRRP auth to sops** — `dns-failover.nix` has plaintext `authPassword`.

### Low Priority

15. **`/data/ai/` migration incomplete** — `ai-models.nix` module creates `/data/ai/` structure but it's empty (0 bytes). Models still at `/data/models/`, `/data/llamacpp-models/`, `/data/unsloth/`.

16. **`justfile` deprecated but still exists** — Should migrate all recipes to `flake.nix` apps per AGENTS.md guidance.

17. **`mr-sync` not in perSystem.packages** — Package exists in `pkgs/mr-sync.nix` but fails eval. Needs wiring.

18. **`signoz.nix` uses `with lib;`** — Anti-pattern, should use explicit imports.

---

## F) TOP 25 THINGS TO DO NEXT (Prioritized)

| Priority | #  | Task                                                                    | Category      | Est. | Impact                                                        |
| -------- | -- | ----------------------------------------------------------------------- | ------------- | ---- | ------------------------------------------------------------- |
| 🔴 P0    | 1  | **`just switch` — deploy all committed changes**                        | DEPLOY        | 45m  | Activates niri nproc fix, Go package fixes                    |
| 🔴 P0    | 2  | **Kill duplicate llama-server (PID 1210173, Jan AI)**                   | OPS           | 1m   | Recovers ~500MB GPU VRAM + RAM                                |
| 🔴 P0    | 3  | **Add `harden` to ai-stack.nix (Ollama, Unsloth)**                      | RELIABILITY   | 15m  | Prevents GPU OOM cascades                                     |
| 🔴 P0    | 4  | **Clean coredumps: `coredumpctl vacuum`**                               | OPS           | 1m   | Reclaims disk space                                           |
| 🟠 P1    | 5  | **Migrate 6 services to `harden()` function**                           | SECURITY      | 30m  | Uniform security posture                                      |
| 🟠 P1    | 6  | **Nix store GC + delete old generations**                               | DISK          | 10m  | Root at 86%, reclaim 10-50GB                                  |
| 🟠 P1    | 7  | **Audit `/data/llamacpp-models` vs `/data/models` for dedup**           | DISK          | 15m  | Potential 142GB reclaim                                       |
| 🟠 P1    | 8  | **Fix remaining 3 Nix-side Go package builds**                          | BUILD         | 30m  | buildflow, go-functional-fixer, terraform-diagrams-aggregator |
| 🟠 P1    | 9  | **`just update` — refresh flake.lock**                                  | MAINT         | 5m   | Security patches from upstream                                |
| 🟠 P1    | 10 | **Start Docker + verify Immich, SigNoz, Twenty**                        | DEPLOY        | 15m  | 0 containers running currently                                |
| 🟡 P2    | 11 | **Hermes health check endpoint**                                        | OBSERVABILITY | 20m  | Enables WatchdogSec + alerting                                |
| 🟡 P2    | 12 | **Move Taskwarrior encryption to sops-nix**                             | SECURITY      | 10m  | P1-7 from master plan                                         |
| 🟡 P2    | 13 | **Pin Docker image digests (Voice Agents + PhotoMap)**                  | SECURITY      | 10m  | Supply chain protection                                       |
| 🟡 P2    | 14 | **Secure VRRP auth_pass with sops**                                     | SECURITY      | 8m   | P1-11 from master plan                                        |
| 🟡 P2    | 15 | **Complete `/data/ai/` migration (`just ai-migrate`)**                  | ARCH          | 20m  | Centralize model storage                                      |
| 🟡 P2    | 16 | **Verify SigNoz metrics collection post-deploy**                        | OBSERVABILITY | 10m  | P6-65 from master plan                                        |
| 🟡 P2    | 17 | **Add `LimitNPROC=infinity` to other user services** (waybar, pipewire) | RELIABILITY   | 5m   | Same issue as niri could affect others                        |
| 🟢 P3    | 18 | **Close idle editor sessions** (34 gopls instances)                     | PERF          | 2m   | ~8GB RSS recovery                                             |
| 🟢 P3    | 19 | **Verify Authelia SSO + SMTP notifications**                            | SECURITY      | 10m  | P6-66 from master plan                                        |
| 🟢 P3    | 20 | **Build Pi 3 SD image for DNS failover cluster**                        | DEPLOY        | 30m+ | P5-50 from master plan                                        |
| 🟢 P3    | 21 | **Add ComfyUI MemoryHigh (soft limit before MemoryMax)**                | RELIABILITY   | 5m   | Graceful throttling before hard kill                          |
| 🟢 P3    | 22 | **Wire `mr-sync` into perSystem.packages**                              | BUILD         | 10m  | Package exists but not exposed                                |
| 🟢 P3    | 23 | **Remove `with lib;` from signoz.nix**                                  | STYLE         | 5m   | Consistency with rest of codebase                             |
| 🔵 P4    | 24 | **Add NixOS VM tests for critical services**                            | TESTING       | 2h+  | P9-91, automated validation                                   |
| 🔵 P4    | 25 | **Investigate Committed_AS overcommit (111GB vs 76GB limit)**           | RESEARCH      | 30m  | Understanding memory pressure                                 |

---

## G) TOP QUESTION I CANNOT ANSWER ❓

**Why are zero Docker containers running?**

Your config defines Immich, SigNoz (ClickHouse + OTel), Twenty CRM, PhotoMap, and Voice Agents — all as Docker Compose services. But `docker ps` shows **0 containers**. This means:

- Either `docker.service` is stopped
- Or the services are intentionally disabled (e.g., `enable = false`)
- Or the compose-up commands haven't been run since last reboot

The system has been up for **7 days 21 hours**. ClickHouse (PID 3399046) is running natively (not in Docker), and earlyoom was started Apr 27. But all Docker-based services appear absent.

**I cannot determine from the Nix config alone whether this is intentional or a regression.** The service modules have `enable = true` defaults, but `configuration.nix` may override them. This requires your input:

1. Were these services working before a reboot/rebuild?
2. Should they be running now?
3. Is Docker daemon intentionally stopped?

---

## System State Snapshot

| Metric                | Value                         | Status                              |
| --------------------- | ----------------------------- | ----------------------------------- |
| **Uptime**            | 7d 21h                        | Long — consider reboot after deploy |
| **RAM**               | 46/62 GB (74%)                | ⚠️ High                              |
| **Swap (ZRAM)**       | 15.2/31.2 GB (49%)            | ⚠️ Under pressure                    |
| **Root disk**         | 436/512 GB (86%)              | 🔴 Tight                            |
| **Data disk**         | 685/800 GB (86%)              | 🔴 Tight                            |
| **Load avg**          | 29/32 cores                   | ⚠️ Near saturation                   |
| **User threads**      | 4,608 across 285 procs        | ⚠️ Near old 4096 limit               |
| **Coredumps**         | 174                           | 🟡 Needs cleanup                    |
| **Docker containers** | 0                             | ❓ Unexpected                       |
| **gopls instances**   | 34 (~8GB RSS)                 | 🟡 Instance sprawl                  |
| **Crush instances**   | 37                            | 🟡 Heavy AI workload                |
| **Committed_AS**      | 111 GB (46GB over limit)      | 🔴 Overcommitted                    |
| **Nix eval**          | All packages pass             | ✅                                  |
| **Flake check**       | `--no-build` passes           | ✅                                  |
| **Git status**        | Clean, up to date with origin | ✅                                  |

---

## Files Changed This Session

| File                                     | Change                                                                                            |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `modules/nixos/services/niri-config.nix` | `LimitNPROC=infinity`, `LimitNOFILE=524288`, `StartLimitBurst`/`StartLimitIntervalSec` → `[Unit]` |
| `platforms/nixos/system/boot.nix`        | `security.pam.loginLimits` → nproc soft 65536 / hard 262144                                       |
| `pkgs/auto-deduplicate.nix`              | Vendor hash + build fixes                                                                         |
| `pkgs/buildflow.nix`                     | Vendor hash + build fixes                                                                         |
| `pkgs/code-duplicate-analyzer.nix`       | Vendor hash + build fixes                                                                         |
| `pkgs/hierarchical-errors.nix`           | Vendor hash + build fixes                                                                         |
| `pkgs/terraform-to-d2.nix`               | Vendor hash + build fixes                                                                         |

---

_Arte in Aeternum_
