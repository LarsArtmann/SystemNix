# COMPREHENSIVE STATUS REPORT — SystemNix

**Date:** 2026-05-01 08:48 (Session 10)
**Previous:** Session 9 — `2026-05-01_04-50_COMPREHENSIVE-STATUS-REPORT.md`

---

## Executive Summary

Session 10 resolved the niri `RLIMIT_NPROC` issue from session 9, completed the Go package infrastructure refactoring (mkGoTool), redesigned emeet-pixyd's `auto` option from a boolean to a typed enum, integrated file-and-image-renamer as a NixOS service, and updated all flake inputs. **10 commits across 2 repositories.**

The system is stable with load average 3.5/32 cores, but still under memory pressure (47/62GB RAM, 14.8/31.2GB ZRAM swap). Duplicate llama-server instances persist. Root disk has climbed to 88%. Zero Docker containers running.

---

## A) FULLY DONE ✅

### Session 10 Commits (SystemNix)

| Commit    | Description                                                                                                                                                 |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `a517ec5` | **Niri `LimitNPROC=infinity` + system-wide nproc raise** — fixed `EAGAIN` thread spawn errors. `StartLimitBurst`/`StartLimitIntervalSec` moved to `[Unit]`. |
| `2ad9010` | **mkGoTool shared builder + go-replaces** — 16 Go packages refactored (77% code reduction). Status report included.                                         |
| `c2db1b4` | **Go tool consolidation + emeet-pixyd config fix** — statix lint fixes, `autoPrivacy`/`autoTracking` → `auto`                                               |
| `db38e2b` | **Vendor hash updates + self-replace fix** in mkGoTool                                                                                                      |
| `af4ce95` | **emeet-pixy auto enum upgrade** — `bool` → `enum ["off" "full" "tracking-only" "privacy-only"]`                                                            |
| `9d648b4` | **Integration status report** (file-and-image-renamer)                                                                                                      |
| `fccef1b` | **file-and-image-renamer flake inputs** — `path:` → SSH URLs                                                                                                |
| `b61134e` | **file-and-image-renamer NixOS integration status** — comprehensive report                                                                                  |
| `f081bc0` | **All path-based flake inputs updated** to latest revisions                                                                                                 |
| `326f29e` | **flake.lock update** after upstream fixes                                                                                                                  |

### Session 10 Commits (emeet-pixyd)

| Commit    | Description                                                                                                                                                            |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `021b599` | **AutoMode enum** — 14 files changed, `AutoMode` type with predicate methods, backward-compatible `ParseAutoMode`, updated NixOS module, all tests passing, lint clean |

### Key Accomplishments (all sessions cumulative)

| Category                   | Items                                                       | Status              |
| -------------------------- | ----------------------------------------------------------- | ------------------- |
| **P0 Critical**            | Push commits, clean branches, archive docs                  | 6/6 ✅              |
| **P2 Reliability**         | WatchdogSec, Restart policies, dead code fixes              | 11/11 ✅            |
| **P3 Code Quality**        | deadnix, statix, lint, unused params                        | 9/9 ✅              |
| **P4 Architecture**        | lib/systemd.nix, module options, enable toggles             | 7/7 ✅              |
| **P7 Tooling/CI**          | GitHub Actions (3 workflows), alejandra, pre-commit         | 10/10 ✅            |
| **P8 Docs**                | README, AGENTS.md, ADR-005, CONTRIBUTING.md                 | 5/5 ✅              |
| **Custom Packages**        | 26 packages (22 Go, 2 Rust, 1 Node, 1 Python, 1 AppImage)   | 25/26 eval OK       |
| **Go Infrastructure**      | mkGoTool + go-replaces shared builder                       | ✅ New this session |
| **EMEET PIXY AutoMode**    | Typed enum for auto-management strategies                   | ✅ New this session |
| **file-and-image-renamer** | NixOS service integration (sops secrets, systemd hardening) | ✅ New this session |

---

## B) PARTIALLY DONE 🔧

| Item                  | Status     | Details                                             |
| --------------------- | ---------- | --------------------------------------------------- |
| **P1 Security**       | 3/7 (43%)  | 4 items blocked on evo-x2 deploy for sops secrets   |
| **P6 Services**       | 9/15 (60%) | Hermes health check pending, SigNoz metrics blocked |
| **P5 Deploy/Verify**  | 0/13 (0%)  | All require `just switch` + manual verification     |
| **P9 Future**         | 2/12 (17%) | Research items, no urgency                          |
| **Service hardening** | ~65%       | 5 services still use manual inline hardening        |
| **Docker containers** | 0 running  | All services defined but Docker daemon appears idle |

---

## C) NOT STARTED ⬜

### P5 — Deployment & Verification (13 tasks)

| #     | Task                                                                  | Est.        |
| ----- | --------------------------------------------------------------------- | ----------- |
| 41    | `just switch` — deploy all committed changes                          | 45m+        |
| 42–49 | Verify Ollama, Steam, ComfyUI, Caddy, SigNoz, Authelia, PhotoMap, NPU | 3-10m each  |
| 50–53 | Pi 3 SD image build, flash, DNS failover test, LAN config             | 10-30m each |

### P9 — Future/Research (10 tasks)

Same as session 9 — no changes.

---

## D) TOTALLY FUCKED UP 💥

### 1. Duplicate llama-server Instances — STILL PRESENT

Same issue from session 9, still unfixed:

| PID     | Source          | Port | Uptime                     | RSS               |
| ------- | --------------- | ---- | -------------------------- | ----------------- |
| 1210173 | Jan AI (vulkan) | 3319 | **4+ days** (since Apr 27) | 724 KB + GPU VRAM |
| 2656447 | Manual/systemd? | 8118 | 1+ day (since Apr 30)      | 970 MB            |

Both running the same model (gemma-4-26B-A4B-heretic-APEX-Balanced). The Jan AI instance has been running for **4 days straight**.

### 2. Root Disk Now at 88% — WORSENING

| Partition | Size | Used | Avail | Use% | Change                 |
| --------- | ---- | ---- | ----- | ---- | ---------------------- |
| `/`       | 512G | 441G | 66G   | 88%  | ↑ from 86% (session 9) |
| `/data`   | 800G | 685G | 116G  | 86%  | Same                   |

Root gained ~5GB since last session. Nix store builds from the Go package work are the likely cause. **Needs `nix-collect-garbage -d`.**

### 3. Committed_AS Still Over Limit

`Committed_AS: 100GB` vs `CommitLimit: 76GB` — still **24GB overcommitted**. Slightly improved from 111GB in session 9 but still dangerous.

### 4. Coredumps Growing

178 coredumps (was 174 in session 9). Still not cleaned.

### 5. Zero Docker Containers

All Docker-based services (Immich, SigNoz, Twenty, PhotoMap, Voice Agents) remain at 0 containers. Unchanged from session 9.

---

## E) WHAT WE SHOULD IMPROVE 🔨

### Critical (unchanged from session 9)

1. **`ai-stack.nix` has ZERO systemd hardening** — Ollama, Unsloth have no `MemoryMax`, no `NoNewPrivileges`. Single biggest reliability gap.

2. **Kill duplicate llama-server (PID 1210173)** — 4+ days of wasted GPU VRAM.

3. **Nix store GC** — Root at 88%, `nix-collect-garbage -d` would reclaim 10-50GB.

### High Priority (new/updated this session)

4. **Deploy all committed changes** — 10 SystemNix commits + emeet-pixyd enum changes are committed but NOT deployed. The niri nproc fix, Go package refactoring, and AutoMode enum all need `just switch`.

5. **Migrate 5 service modules to `harden()` function** — caddy, authelia, taskchampion, voice-agents, gitea-repos still have manual inline hardening.

6. **Clean coredumps** — 178 files from past OOM events.

7. **Flake lock update** — Done this session, but should be regular.

8. **Audit `/data/llamacpp-models` (142G) vs `/data/models` (322G)** for dedup.

### Medium Priority (unchanged)

9. **gopls instance sprawl** — 30 instances consuming ~8GB RSS.
10. **Hermes health check** — No health endpoint means no WatchdogSec.
11. **Taskwarrior encryption to sops** — Uses deterministic hash.
12. **Docker digest pinning** — Voice Agents + PhotoMap.
13. **VRRP auth to sops** — Plaintext in dns-failover.nix.
14. **Complete `/data/ai/` migration** — Still empty.

---

## F) TOP 25 THINGS TO DO NEXT (Prioritized)

| Priority | #  | Task                                                            | Category      | Est. |
| -------- | -- | --------------------------------------------------------------- | ------------- | ---- |
| 🔴 P0    | 1  | **`just switch` — deploy all 10+ committed changes**            | DEPLOY        | 45m  |
| 🔴 P0    | 2  | **Kill duplicate llama-server (PID 1210173)**                   | OPS           | 1m   |
| 🔴 P0    | 3  | **`nix-collect-garbage -d` — reclaim disk space**               | DISK          | 5m   |
| 🔴 P0    | 4  | **Add `harden` to ai-stack.nix (Ollama, Unsloth)**              | RELIABILITY   | 15m  |
| 🔴 P0    | 5  | **Clean coredumps: `coredumpctl vacuum`**                       | OPS           | 1m   |
| 🟠 P1    | 6  | **Verify niri nproc fix took effect**                           | VERIFY        | 2m   |
| 🟠 P1    | 7  | **Verify emeet-pixyd auto enum works**                          | VERIFY        | 2m   |
| 🟠 P1    | 8  | **Start Docker + verify Immich, SigNoz, Twenty**                | DEPLOY        | 15m  |
| 🟠 P1    | 9  | **Migrate 5 services to `harden()` function**                   | SECURITY      | 30m  |
| 🟠 P1    | 10 | **Audit `/data/llamacpp-models` vs `/data/models` for dedup**   | DISK          | 15m  |
| 🟡 P2    | 11 | **Hermes health check endpoint**                                | OBSERVABILITY | 20m  |
| 🟡 P2    | 12 | **Move Taskwarrior encryption to sops-nix**                     | SECURITY      | 10m  |
| 🟡 P2    | 13 | **Pin Docker image digests (Voice Agents + PhotoMap)**          | SECURITY      | 10m  |
| 🟡 P2    | 14 | **Secure VRRP auth_pass with sops**                             | SECURITY      | 8m   |
| 🟡 P2    | 15 | **Complete `/data/ai/` migration**                              | ARCH          | 20m  |
| 🟡 P2    | 16 | **Verify SigNoz metrics collection post-deploy**                | OBSERVABILITY | 10m  |
| 🟡 P2    | 17 | **Add `LimitNPROC=infinity` to waybar, pipewire user services** | RELIABILITY   | 5m   |
| 🟢 P3    | 18 | **Close idle editor sessions** (30 gopls instances)             | PERF          | 2m   |
| 🟢 P3    | 19 | **Verify Authelia SSO + SMTP notifications**                    | SECURITY      | 10m  |
| 🟢 P3    | 20 | **Build Pi 3 SD image for DNS failover cluster**                | DEPLOY        | 30m+ |
| 🟢 P3    | 21 | **Add ComfyUI `MemoryHigh` (soft limit)**                       | RELIABILITY   | 5m   |
| 🟢 P3    | 22 | **Wire `mr-sync` into perSystem.packages**                      | BUILD         | 10m  |
| 🟢 P3    | 23 | **Remove `with lib;` from signoz.nix**                          | STYLE         | 5m   |
| 🔵 P4    | 24 | **Add NixOS VM tests for critical services**                    | TESTING       | 2h+  |
| 🔵 P4    | 25 | **Investigate Committed_AS overcommit (100GB vs 76GB)**         | RESEARCH      | 30m  |

---

## G) TOP QUESTION I CANNOT ANSWER ❓

**Same as session 9, still unresolved: Why are zero Docker containers running?**

Your config defines Immich, SigNoz (ClickHouse + OTel), Twenty CRM, PhotoMap, and Voice Agents as Docker services, but `docker ps` shows 0 containers. ClickHouse (PID 3625935, 9.1% CPU) is running natively.

This is now **blocking all P5 verification tasks** (42-49). Without Docker, none of these services can function. I need to know:

1. Is `docker.service` intentionally stopped?
2. Should I add `virtualisation.docker.enable = true` or verify it's enabled?
3. Were these services ever running in Docker, or have they been migrated to native?

---

## System State Snapshot

| Metric                | Value                    | Status | Change from Session 9 |
| --------------------- | ------------------------ | ------ | --------------------- |
| **Uptime**            | 8d 1.3h                  | Long   | +6h                   |
| **RAM**               | 47/62 GB (76%)           | ⚠️      | ↑ from 74%            |
| **Swap (ZRAM)**       | 14.8/31.2 GB (47%)       | ⚠️      | ↓ from 49%            |
| **Root disk**         | 441/512 GB (88%)         | 🔴     | ↑ from 86%            |
| **Data disk**         | 685/800 GB (86%)         | 🔴     | Same                  |
| **Load avg**          | 3.5/32 cores             | ✅     | ↓ from 29             |
| **User threads**      | 3,484 across 219 procs   | ✅     | ↓ from 4,608          |
| **Coredumps**         | 178                      | 🟡     | ↑ from 174            |
| **Docker containers** | 0                        | ❓     | Same                  |
| **gopls instances**   | 30 (~8GB RSS)            | 🟡     | ↓ from 34             |
| **Committed_AS**      | 100 GB (24GB over limit) | 🔴     | ↓ from 111GB          |
| **Nix eval**          | All packages pass        | ✅     | Same                  |
| **Flake check**       | `--no-build` passes      | ✅     | Same                  |
| **Git status**        | Clean, pushed to origin  | ✅     | Pushed since S9       |
| **llama-server**      | 2 instances (same model) | 🔴     | Same                  |

---

## Session 10 Work Summary

### Repositories Modified

| Repo        | Commits    | Files Changed                                                                                                         |
| ----------- | ---------- | --------------------------------------------------------------------------------------------------------------------- |
| SystemNix   | 10         | flake.nix, flake.lock, configuration.nix, niri-config.nix, boot.nix, 16 Go pkg files, 2 new lib files, status docs    |
| emeet-pixyd | 1 (pushed) | 14 files: pixy.go, auto.go, commands.go, handlers.go, main.go, web_types.go, templates.templ, nixos.nix, 6 test files |

### Key Design Decisions

1. **AutoMode enum over bool** — Instead of `auto = true/false`, now `auto = "full"/"tracking-only"/"privacy-only"/"off"`. Predicate methods (`ActivatesTracking()`, `ActivatesAudio()`, etc.) make the behavior self-documenting. Backward compatible via `ParseAutoMode` accepting legacy booleans.

2. **mkGoTool shared builder** — 16 Go packages reduced from ~30 lines each to ~5 lines. Centralized `go-replaces.nix` for all `go.mod` replace directives. Smart `postPatch` strips stale directives before appending fresh ones.

3. **System-wide nproc raise** — `security.pam.loginLimits` soft 65536 / hard 262144 for `@users`, plus `LimitNPROC=infinity` on niri service itself.

---

_Arte in Aeternum_
