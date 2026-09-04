# SystemNix — Session 42: GPU Headroom for Niri, Full Project Status

**Date:** 2026-05-06 12:46 CEST
**Branch:** master (up to date with origin/master)
**Session:** 42 (continuation of 24h+ continuous work since May 5)

---

## Uncommitted Changes (2 files)

| File        | Lines | Description                                                                                      |
| ----------- | ----- | ------------------------------------------------------------------------------------------------ |
| `AGENTS.md` | +11   | New "GPU Compute Headroom for Niri" section documenting the per_process_memory_fraction strategy |
| `justfile`  | +13   | `gpu-python` just command + PYTORCH_CUDA_ALLOC_CONF in `ai-status` output                        |

**Note:** The actual GPU limiting changes to `ai-stack.nix` and `comfyui.nix` are already committed in 3 atomic commits (see Session Timeline).

---

## Session 42 Work Summary

### Problem

AI workloads (Ollama, ComfyUI, ad-hoc PyTorch scripts) running at 100% iGPU utilization caused niri (Wayland compositor) to become laggy and unresponsive. AMD APUs have no MPS-style GPU compute scheduler or priority mechanism.

### Investigation

- Checked `pp_power_profile_mode` — not available on APUs
- Checked power cap sysfs — not available on APUs
- Checked PP Overdrive — intentionally disabled (causes GPU hangs per ADR)
- Confirmed DPM is forced to `high` performance (correct for AI workloads)
- Verified `per_process_memory_fraction` works on ROCm via PyTorch's `PYTORCH_CUDA_ALLOC_CONF`

### Approach (3 iterations)

1. **First attempt (WRONG):** Added `CPUWeight=50` systemd slice for AI services → rejected because the problem is GPU starvation, not CPU
2. **Second attempt (reverted):** Removed all CPU-focused changes
3. **Final approach (correct):** GPU memory fraction limiting via `PYTORCH_CUDA_ALLOC_CONF=per_process_memory_fraction:0.95`

### Changes Committed

| Commit    | Files                         | Description                                                                                                                                                                               |
| --------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `79a36ad` | `ai-stack.nix`, `comfyui.nix` | Added systemd slice with CPUWeight=50 (WRONG approach)                                                                                                                                    |
| `07c5aa2` | `ai-stack.nix`, `comfyui.nix` | Reverted CPU slice changes                                                                                                                                                                |
| `d9a2b87` | `ai-stack.nix`, `comfyui.nix` | Added `PYTORCH_CUDA_ALLOC_CONF=per_process_memory_fraction:0.95` to Ollama env, ComfyUI env, system-wide session vars, reduced `OLLAMA_NUM_PARALLEL` from 4→2, added `gpu-python` wrapper |

### What the GPU limiting does

- **`PYTORCH_CUDA_ALLOC_CONF=per_process_memory_fraction:0.95`** — Caps PyTorch's memory allocator to 95% of visible VRAM, leaving 5% free for niri's rendering pipeline
- **`OLLAMA_NUM_PARALLEL=2`** (was 4) — Fewer concurrent GPU compute batches means more idle gaps where niri can submit rendering work
- **`gpu-python` wrapper** — Convenience command for ad-hoc Python scripts: `gpu-python script.py` or `GPU_MEM_FRACTION=0.8 gpu-python script.py`
- **System-wide session variable** — All PyTorch processes in the user session inherit the 95% cap

### Limitation

AMD APUs lack GPU compute scheduling priority (unlike NVIDIA MPS). The memory fraction approach is the best available tool without PP Overdrive (disabled due to GPU hangs). If niri still lags, the fraction can be lowered to 0.90 or 0.85.

---

## a) FULLY DONE ✅

### Infrastructure & Core

- **Cross-platform Nix flake** — Single flake, two systems (Darwin + NixOS), 80% shared via `platforms/common/`
- **flake-parts modular architecture** — 29 NixOS service modules, all using `lib/types.nix`, `lib/systemd.nix`, `lib/systemd/service-defaults.nix`
- **Shared overlays** — NUR, aw-watcher, todo-list-ai, golangci-lint-auto-configure, mr-sync, library-policy (cross-platform); openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer (Linux-only)
- **All `path:` inputs eliminated** — Fully portable flake, all private repos via `git+ssh://`
- **Formatter** — treefmt + alejandra via `treefmt-full-flake`, `just format` works
- **Flake checks** — statix, deadnix, eval checks pass: `just test-fast` → all checks passed

### NixOS Services (evo-x2)

- **Docker** — Always-on, overlay2, `/data/docker`, weekly auto-prune
- **Caddy reverse proxy** — TLS via sops certs, forward auth via Authelia, 10+ virtual hosts, metrics
- **SOPS secrets** — Age-encrypted via SSH host key, 4 sops files, auto-restart per secret
- **Authelia SSO** — OIDC provider, TOTP + WebAuthn 2FA, file-based auth, brute-force protection
- **Gitea** — SQLite, LFS, weekly dumps, GitHub mirror, Actions runner (Docker + native)
- **Homepage Dashboard** — Catppuccin Mocha theme, 5 categories, resource widgets
- **Immich** — PostgreSQL + Redis + ML, OAuth via Authelia, daily DB backup, GPU for ML
- **SigNoz** — Full observability: traces/metrics/logs, ClickHouse, OTel Collector, node_exporter, cadvisor, 7 alert rules, dashboard provisioning
- **TaskChampion** — Port 10222, TLS via Caddy, no forward auth, deterministic client IDs
- **Minecraft** — JDK 25, ZGC, LAN-only firewall, Prism Launcher client
- **Ollama** — ROCm GPU, flash attention, **2 parallel** (reduced from 4), q8_0 KV, 1h keep-alive, **95% GPU memory cap**
- **ComfyUI** — ROCm GPU, bf16, OOMScoreAdjust=-100, **95% GPU memory cap**
- **Hermes AI gateway** — v2026.4.30, Discord bot, cron, sops secrets, 4G memory limit, USR1 reload, SQLite auto-recovery (committed, NOT deployed)
- **Manifest LLM router** — Docker Compose (app + postgres), sops secrets, daily DB backup, Caddy reverse proxy, CORS origin fix (committed, NOT deployed)
- **File & Image Renamer** — Watches Desktop, ZAI API, hardened sandbox
- **Monitor365** — Device monitoring agent, ActivityWatch integration
- **DNS blocker** — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream

### Desktop (NixOS)

- **Niri compositor** — niri-unstable, XWayland satellite, patched BindsTo→Wants, OOMScoreAdjust=-900
- **SDDM** — SilentSDDM, Catppuccin Mocha theme
- **PipeWire** — ALSA + PulseAudio + JACK compat, rtkit realtime
- **Waybar** — Thermal zone fix (no hardcoded hwmon), security status indicator
- **EMEET PIXY webcam** — Full Go daemon, auto-tracking, call detection, Waybar integration, HID state querying
- **Niri session manager** — Window save/restore, TOML app mappings, backup rotation
- **Security hardening** — fail2ban, ClamAV, polkit, GNOME Keyring, 30+ security tools
- **Steam gaming** — extest, protontricks, gamemode, gamescope, mangohud
- **Wallpaper self-healing** — awww-daemon + awww-wallpaper with PartOf restart propagation
- **Helium browser** — Restore tabs on launch via wrapper flags

### Cross-Platform (Darwin + NixOS)

- **Home Manager** — 14 shared program modules: fish, zsh, bash, starship, git, tmux, fzf, taskwarrior, keepassxc, pre-commit, shell-aliases, ssh-config, chromium, activitywatch
- **Taskwarrior** — TaskChampion sync, deterministic client IDs, Catppuccin Mocha colors, `just task-*` commands
- **Git config** — External `nix-ssh-config` flake input
- **Crush config** — Deployed via flake input + Home Manager on both platforms
- **Catppuccin Mocha theme** — Universal: all apps, terminals, bars, login screen

### GPU Management (NEW this session)

- **PyTorch GPU memory fraction** — 95% cap system-wide via `PYTORCH_CUDA_ALLOC_CONF`
- **Ollama parallelism reduction** — 4→2 concurrent requests
- **`gpu-python` wrapper** — Convenience command for ad-hoc GPU scripts with configurable fraction

### Documentation & Quality

- **AGENTS.md** — Comprehensive project guide with architecture, patterns, gotchas, commands
- **FEATURES.md** — Brutally honest feature inventory with status indicators
- **`just` commands** — 60+ recipes organized by category, all documented
- **Shared lib helpers** — `lib/systemd.nix` (harden), `lib/systemd/service-defaults.nix`, `lib/types.nix`, `lib/rocm.nix`

---

## b) PARTIALLY DONE ⚠️

| Item                          | Status | What's Missing                                                                                                                                                                                                                                                    |
| ----------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **GPU headroom for niri**     | ⚠️      | Changes committed and build passes. **NOT deployed yet** — needs `just switch`. Also: `per_process_memory_fraction` caps memory allocation but does NOT directly limit compute utilization. If niri still lags under 95%, may need to lower further (0.90, 0.85). |
| **Manifest LLM router**       | ⚠️      | `CORS_ORIGIN` fix committed but NOT deployed. Rate limiting warning ("could not determine client IP") — upstream Manifest doesn't expose `trustedProxies` config.                                                                                                 |
| **Hermes v2026.4.30 upgrade** | ⚠️      | Pinned to release tag, new vendor hash, SQLite auto-recovery added — committed but NOT deployed                                                                                                                                                                   |
| **DNS failover cluster**      | ⚠️      | Module exists (`dns-failover.nix`), Keepalived VRRP config written — Pi 3 hardware not provisioned                                                                                                                                                                |
| **Voice agents**              | ⚠️      | LiveKit + Whisper module exists, Docker ROCm — may need verification after last deploy                                                                                                                                                                            |
| **PhotoMap AI**               | 🔧     | Module exists, disabled in config                                                                                                                                                                                                                                 |
| **Twenty CRM**                | 🔧     | Module exists, Docker Compose, sops secrets — unclear if actively deployed                                                                                                                                                                                        |
| **Unsloth Studio**            | 🔧     | Module exists, disabled by default                                                                                                                                                                                                                                |
| **Multi-WM (Sway)**           | 🔧     | Module exists, disabled in config                                                                                                                                                                                                                                 |
| **AMD NPU driver**            | ⚠️      | `nix-amd-npu` input present, but XDNA driver support is experimental                                                                                                                                                                                              |
| **Raspberry Pi 3 image**      | 📋     | `nixosConfigurations.rpi3-dns` defined in flake — hardware not provisioned                                                                                                                                                                                        |

---

## c) NOT STARTED 📋

1. **Pi 3 DNS backup node** — Hardware provisioning + SD image flash + network config
2. **Gatus health checks** — Draft module started, not completed
3. **Papermark document sharing** — Research done, not implemented
4. **Private cloud planning** — Directory exists with README, no implementation
5. **ecapture integration** — Assessment done, not implemented
6. **mitmproxy + ActivityWatch integration** — Research done, not implemented
7. **Reticulum network** — Assessment done, not implemented
8. **Qubes-in-NixOS** — Research done, not implemented
9. **YouTube frontend alternatives** — Research done, not implemented
10. **Coroot/deepflow evaluation** — Reports written, no implementation
11. **ActivityWatch URL tracking** — Investigated, not implemented
12. **Nix colors integration** — Research done, currently using Catppuccin directly
13. **Technitium DNS migration** — Full evaluation + guides written, not migrated (staying with Unbound)
14. **GolangCI-lint auto-configure** — Package in `pkgs/`, not wired as CI step
15. **mr-sync** — Package in `pkgs/`, no cron or systemd timer for auto-sync
16. **Actual GPU compute throttling** — `per_process_memory_fraction` is memory-only. True compute queue limiting (NVIDIA MPS equivalent) doesn't exist for AMD. Would need kernel-level AMD HSA queue priority support.

---

## d) TOTALLY FUCKED UP 💥

| Item                         | Severity | Details                                                                                                                                                                                                                                                                                                                                                  |
| ---------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **GPU compute scheduling**   | Medium   | AMD APUs have NO GPU compute priority mechanism. `per_process_memory_fraction` limits memory, not compute cycles. If AI workloads saturate the compute units, niri WILL still lag. The 95% memory cap + reduced parallelism are mitigations, not a fix. True fix requires AMD HSA/ROCm queue priority support at the kernel level — doesn't exist today. |
| **Manifest rate limiting**   | Low      | Better Auth can't determine client IP because Docker bridge strips origin info. Manifest doesn't expose `trustedProxies` config — upstream limitation.                                                                                                                                                                                                   |
| **amdgpu driver crash loop** | Medium   | Hermes anime-comic-pipeline (PyTorch/ROCm) can SIGSEGV → GPU driver hang → desktop frozen. Defense in depth: sysrq, panic=30, watchdogd, gpu_recovery=1. Upstream AMD driver bug. PP Overdrive disabled because it made this WORSE.                                                                                                                      |
| **awww-daemon BrokenPipe**   | Low      | Upstream awww 0.12.0 panics on BrokenPipe during suspend/output hotplug. `Restart=always` + `PartOf` propagation covers it.                                                                                                                                                                                                                              |
| **watchdogd nixpkgs module** | Low      | `device` and `reset-reason` sections generate invalid config (unquoted paths). Workaround: omit both. Upstream nixpkgs bug.                                                                                                                                                                                                                              |

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Session 42 Learnings

1. **AMD GPU compute scheduling gap** — Document this as a known limitation. When someone asks "limit GPU to 95%", the answer for AMD APUs is: you can't directly. Memory fraction + reduced parallelism are the best approximations.
2. **Wrong approach detected quickly** — CPUWeight/slice approach was wrong but committed. Should have investigated first, committed after. Lesson: research BEFORE committing when the approach is uncertain.

### Architecture & Code Quality

3. **Archive the 280+ stale status reports** — `docs/status/` has 17 active + 280+ archived. Prune to last 30 days.
4. **Archive stale docs** — `docs/` has 80+ top-level .md files. Organize into `docs/research/`.
5. **File Manifest upstream issue** — Request `trustedProxies` in Better Auth config.
6. **Gatus health checks** — Replace ad-hoc monitoring. Module draft exists.
7. **Service dependency graph** — D2 diagram of service dependencies.
8. **CI pipeline** — `nix-check.yml` exists but doesn't run on PRs. Add Darwin build check.
9. **Module option documentation** — Many `options` lack `description`.
10. **Shared `port` type pattern** — All services should use `lib/types.nix` consistently.
11. **Impermanence / root-on-tmpfs** — Evaluate tmpfs root for evo-x2.
12. **Automated DNS blocklist updates** — Weekly CI job or timer.

### Reliability

13. **Deploy the pending changes** — 3 commits (GPU limiting, Hermes upgrade, Manifest CORS) are committed but NOT deployed.
14. **Gitea backup verification** — Backups run but never tested for restore.
15. **SOPS secret rotation** — Never rotated since initial setup.
16. **Disaster recovery playbook** — No tested procedure for full rebuild.
17. **SigNoz alert notifications** — Alerts defined, no notification channel.
18. **System snapshot testing** — BTRFS + Timeshift never tested restore.

### Darwin-specific

19. **macOS ActivityWatch** — Utilization watcher exists but macOS issues remain.
20. **Darwin build time** — Could optimize with binary cache.
21. **Homebrew management** — `nix-homebrew` exists but packages not fully managed.

---

## f) Top 25 Things We Should Get Done Next

### Priority 1: Deploy & Verify (IMMEDIATE — do this now)

| # | Task                                                                                                           | Impact | Effort |
| - | -------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 1 | **`just switch`** — Deploy GPU limiting + Hermes upgrade + Manifest CORS (3 commits pending)                   | High   | Low    |
| 2 | **Verify niri responsiveness under AI load** — Run Ollama inference while using desktop, confirm 95% cap helps | High   | Low    |
| 3 | **Verify Manifest sign-in** after CORS_ORIGIN deploy                                                           | High   | Low    |
| 4 | **Verify Hermes auto-recovery** — test SQLite malformed DB handling                                            | Medium | Low    |
| 5 | **Run `just health`** — full cross-platform health check                                                       | Medium | Low    |

### Priority 2: GPU & Desktop Reliability

| # | Task                                                                                                          | Impact | Effort |
| - | ------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 6 | **Lower GPU fraction if still laggy** — If 0.95 isn't enough, try 0.90 or 0.85                                | High   | Low    |
| 7 | **Benchmark niri latency** — Measure frame times with/without AI workloads before/after the change            | Medium | Medium |
| 8 | **Research AMD HSA queue priority** — Check if ROCm 6.4+ or kernel 6.12+ adds compute queue priority for APUs | Medium | Medium |
| 9 | **Monitor GPU utilization** — Add `gpu_busy_percent` to SigNoz metrics via node_exporter textfile collector   | Medium | Low    |

### Priority 3: Observability & Reliability

| #  | Task                                                                | Impact | Effort |
| -- | ------------------------------------------------------------------- | ------ | ------ |
| 10 | **Configure SigNoz alert notifications** — webhook or email channel | High   | Medium |
| 11 | **Gatus health checks** — finish module, deploy for all services    | High   | Medium |
| 12 | **Gitea backup restore test** — verify weekly dumps are valid       | High   | Low    |
| 13 | **Disaster recovery playbook** — document full rebuild procedure    | Medium | Medium |
| 14 | **BTRFS snapshot restore test** — verify Timeshift works            | Medium | Low    |
| 15 | **SOPS secret rotation plan** — document and schedule               | Medium | Medium |

### Priority 4: Architecture & Code Quality

| #  | Task                                                                          | Impact | Effort |
| -- | ----------------------------------------------------------------------------- | ------ | ------ |
| 16 | **Archive stale status reports** — move everything > 14 days to `archive/`    | Low    | Low    |
| 17 | **Organize `docs/` top-level** — move research/evaluation to `docs/research/` | Low    | Low    |
| 18 | **File Manifest upstream issue** — request `trustedProxies` config            | Medium | Low    |
| 19 | **Service dependency graph** — visualize with D2 diagram                      | Medium | Medium |
| 20 | **Add module option descriptions** — ensure all `options` have `description`  | Low    | Medium |

### Priority 5: Infrastructure & New Features

| #  | Task                                                                       | Impact | Effort |
| -- | -------------------------------------------------------------------------- | ------ | ------ |
| 21 | **Automated DNS blocklist updates** — weekly timer or CI job               | Medium | Low    |
| 22 | **Pi 3 provisioning** — flash SD, boot, verify DNS failover                | High   | High   |
| 23 | **Voice agents verification** — confirm LiveKit + Whisper works end-to-end | Medium | Medium |
| 24 | **Twenty CRM deployment verification** — confirm or remove module          | Low    | Low    |
| 25 | **mr-sync auto-sync timer** — wire as weekly systemd timer                 | Low    | Low    |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Is the 95% GPU memory fraction actually sufficient to prevent niri lag under heavy AI workloads?**

The `per_process_memory_fraction:0.95` caps PyTorch's memory allocator but does NOT limit GPU compute queue depth or compute unit utilization. The iGPU has shared compute units between niri (rendering) and AI workloads (matrix multiplication). If all compute units are saturated with AI kernels, niri's rendering submissions will queue and cause frame drops regardless of memory headroom.

The `OLLAMA_NUM_PARALLEL=2` reduction helps (fewer concurrent kernels = more scheduling gaps), but this is indirect. There's no way to test this without actually deploying and running a heavy inference workload while using the desktop.

**What I need from you:**

1. After `just switch`, run a heavy Ollama inference (large model, long prompt)
2. While it's running, try using niri (switch workspaces, move windows, scroll in browser)
3. Report if it's better, same, or worse than before
4. If still laggy, I can lower the fraction to 0.90 or 0.85

---

## Session Timeline (May 5–6, 2026)

| Session | Time      | What Happened                                                                    |
| ------- | --------- | -------------------------------------------------------------------------------- |
| 28      | 12:27     | Build fix chain, deployment                                                      |
| 28b     | 12:30     | Reliability hardening, Waybar health, Gitea                                      |
| 29      | 17:54     | Self-review, architecture cleanup                                                |
| 30      | 20:37     | Manifest LLM router integration (initial)                                        |
| 31      | 21:19     | Justfile overhaul, self-review                                                   |
| 32      | 21:34     | Full system status                                                               |
| 33      | 23:31     | Deploy, GC, Caddy fix                                                            |
| 34      | 23:30     | Brutal self-review execution sprint                                              |
| 34b     | 23:54     | Full system status, Manifest secrets                                             |
| 35      | 03:57     | Niri session migration, GPU recovery                                             |
| 36      | 04:47     | Fork PR plan (partial implementation)                                            |
| 37      | 07:10     | DNS reproducibility, Manifest hardening                                          |
| 38      | 07:54     | Watchdog fix, Manifest healthcheck, SOPS dedup                                   |
| 39      | 08:41     | Helium session restore, Rofi plugins, Waybar                                     |
| 40      | 10:30     | File-renamer API key fix, SOPS revert, deploy prep                               |
| 41      | 12:17     | Manifest CORS fix, Hermes v2026.4.30 upgrade, full status                        |
| **42**  | **12:46** | **GPU headroom for niri (memory fraction + parallelism reduction), full status** |

---

## System Metrics

| Metric                      | Value                                        |
| --------------------------- | -------------------------------------------- |
| Root filesystem             | 88% used (62G free of 512G)                  |
| /data filesystem            | 76% used (193G free of 800G)                 |
| RAM                         | 19G used / 62G total (42G available)         |
| Swap                        | 14G used / 41G total (26G free)              |
| GPU busy                    | 1% (idle)                                    |
| GPU VRAM                    | 1.8G used / 64G total                        |
| Load average                | 1.28, 2.24, 3.57                             |
| Uptime                      | 6h 2m                                        |
| NixOS service modules       | 29                                           |
| Custom packages (pkgs/)     | 13                                           |
| Flake inputs                | 32                                           |
| Shared Home Manager modules | 14                                           |
| `just` recipes              | 60+                                          |
| Uncommitted files           | 2 (AGENTS.md, justfile)                      |
| Pending deploy commits      | 3 (GPU limit, Hermes upgrade, Manifest CORS) |
| Build status                | ✅ Passing (nh os build succeeded)           |

---

_Session 42 — Waiting for instructions._
