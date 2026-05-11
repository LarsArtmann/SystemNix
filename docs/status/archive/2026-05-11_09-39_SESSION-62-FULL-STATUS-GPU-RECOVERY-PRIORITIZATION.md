# SystemNix Status Report — Session 62

**Date:** 2026-05-11, 09:39 CEST
**Session:** #62 — Full Comprehensive Status Audit, GPU Driver Recovery, System Prioritization
**Host:** evo-x2 (NixOS, x86_64-linux, AMD Ryzen AI Max+ 395, 128 GB RAM, ~73 GiB iGPU VRAM)
**Branch:** master, clean working tree
**Commit Base:** `a5322e87` (session 61 — crash forensics, GPU budget architecture)
**Validation:** `nix flake check` PASSES, `just test-fast` all checks pass
**Uptime:** 13h 28m (system booted 2026-05-10 ~20:10, no reboot since GPU OOM incident)

---

## Executive Summary

SystemNix is in a **degraded state** following a GPU memory exhaustion event ~13 hours ago. The amdgpu driver is wedged — niri has been SIGKILL'd 638+ times by the DRM healthcheck timer because the GPU cannot recover without a reboot. The monitor (LG 4K on DP-2) shows `connected` but `disabled` + `dpms: Off`.

**The codebase is healthy** — all 109 Nix files pass syntax validation, 14,126 lines of declarative config with 40 service modules, 10 custom packages, 11 scripts, and 94 justfile recipes. The AGENTS.md documentation is comprehensive (735 lines). The architecture is solid with shared lib helpers, per-service GPU fractions, and consistent module patterns.

**The immediate problem:** A reboot is needed to reset the amdgpu driver. But before that, we must ensure niri is prioritized over Ollama so this never happens again.

---

## System State (as of 09:39 CEST)

| Metric | Value | Status |
|--------|-------|--------|
| **RAM** | 19.1G / 62G used (31%) | ✅ Healthy (most cached) |
| **Swap** | zram active | ✅ Normal |
| **GPU VRAM** | 73 GiB total | 🔴 WEDGED — driver state broken since 20:29 yesterday |
| **Root disk** | 462G / 512G (93%) | 🔴 Critical — 50G free, Nix store is massive |
| **/data disk** | 687G / 1.0T (68%) | ✅ Healthy |
| **Load** | 3.83 / 8.31 / 18.66 (falling) | ⚠️ Elevated — settling from GPU chaos |
| **Niri** | Restart count 638+ | 🔴 CRASH LOOP — killed every ~67s by DRM healthcheck |
| **Display (DP-2)** | connected, disabled, dpms: Off | 🔴 NO OUTPUT — monitor sleeping |
| **Docker** | 11 containers running | ✅ All healthy |
| **Nix flake check** | PASS | ✅ |
| **just test-fast** | PASS | ✅ |

### Active Docker Containers
| Container | Status |
|-----------|--------|
| whisper-asr | Up 13h |
| mnfst-manifest-1 | Up 13h (healthy) |
| twenty-server-1 | Up 13h (healthy) |
| twenty-worker-1 | Up 13h |
| twenty-db-1 | Up 13h (healthy) |
| twenty-redis-1 | Up 13h (healthy) |
| mnfst-postgres-1 | Up 13h (healthy) |
| openseo-openseo-1 | Up 13h |
| deer-flow-nginx | Up 13h |
| deer-flow-gateway | Up 13h |
| deer-flow-frontend | Up 13h |

### Enabled NixOS Services (40 modules)

**Infrastructure:** caddy, gitea, gitea-repos, immich, authelia-config, sops-config, display-manager, dns-blocker, fail2ban, ssh-server, smartd, fstrim, udisks2
**Monitoring:** signoz, gatus-config, monitoring-tools, disk-monitor
**AI Stack:** ai-models, ai-stack (ollama), comfyui, voice-agents (whisper + livekit)
**Applications:** homepage, taskchampion, hermes, manifest, openseo, twenty, minecraft
**Desktop:** niri-desktop, niri-session-manager, audio, multi-wm, chromium-policies, steam
**Hardware:** amd-gpu, amd-npu, bluetooth, emeet-pixy
**Security:** security-hardening
**Network:** dual-wan, dns-failover

**Disabled:** photomap (podman config permission issue), monitor365 (high RAM usage)

### Codebase Stats

| Metric | Count |
|--------|-------|
| Nix files | 109 |
| Lines of Nix code | 14,126 |
| Service modules | 40 |
| Custom packages (pkgs/) | 10 |
| Scripts | 11 |
| Shared lib helpers | 4 (systemd.nix, service-defaults.nix, types.nix, rocm.nix) |
| ADR documents | 4 |
| Status reports | 19 (5.5 MB) |
| Justfile recipes | ~94 |
| AGENTS.md lines | 735 |
| Flake inputs | 35+ |

---

## a) FULLY DONE ✅

### Architecture & Patterns
1. **lib/default.nix single-import pattern** — All 22+ service modules migrated to `inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;`
2. **Shared systemd hardening** — `harden {}` used by all services, `serviceDefaults {}` by 17 modules
3. **flake-parts service module architecture** — All 40 services are self-contained flake-parts modules with their own options
4. **Caddy port references** — All 12 reverse-proxied services use `config.services.<name>.port` — zero hardcoded ports
5. **Centralized AI model storage** — `/data/ai/` with `services.ai-models.paths` attrset, all AI services reference it
6. **Per-service GPU memory fractions** — Ollama 0.45/runner, ComfyUI 0.50, gpu-python 0.95
7. **Catppuccin Mocha everywhere** — Consistent theme across all apps, terminals, bars, login screen

### Services
8. **SigNoz observability** — Full pipeline: node_exporter → cAdvisor → OTel Collector → ClickHouse → Query Service
9. **Gatus health checks** — 17 endpoints monitored, SQLite storage, systemd hardened
10. **DNS blocking** — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream
11. **Caddy reverse proxy** — TLS via sops, all services behind `*.home.lan`
12. **Gitea** — Git hosting + GitHub mirror sync (2 repos)
13. **Immich** — Photo/video management
14. **Taskwarrior + TaskChampion** — Cross-platform sync with deterministic client IDs, zero manual setup
15. **Hermes AI gateway** — Discord bot, cron scheduler, sops secrets
16. **OpenSEO** — Self-hosted SEO suite with DataForSEO
17. **Twenty CRM** — Running via docker-compose
18. **Manifest** — Smart LLM router for AI agents
19. **EMEET PIXY** — Auto face tracking, noise cancellation, Waybar integration, systemd watchdog
20. **Wallpaper self-healing** — awww-daemon + awww-wallpaper with PartOf restart propagation
21. **Niri session manager** — Automatic window save/restore
22. **ComfyUI** — Persistent AI image generation
23. **Whisper ASR** — Voice-to-text via Docker
24. **Deer Flow** — Running via docker-compose

### Security
25. **sops-nix** — All secrets age-encrypted, managed declaratively
26. **SSH hardening** — No password auth, key-only, fail2ban
27. **Security hardening module** — Kernel params, sysctl, USBguard, etc.
28. **DNS-over-TLS** — Quad9 upstream
29. **Authelia** — SSO forward auth for web services
30. **Firewall** — Configured in networking.nix

### Documentation
31. **AGENTS.md** — 735 lines, covers architecture, patterns, gotchas, commands, known issues
32. **4 ADRs** — go-output submodules, GPU headroom, BindsTo vs Wants, PartOf vs BindsTo
33. **19 status reports** — Full history from session 45-62
34. **Improvement plan** — Tiered execution plan from session 58

### Cross-Platform
35. **macOS (Darwin)** — Working nix-darwin config with shared overlays, Home Manager
36. **~80% shared config** — common/home-base.nix, common/programs/, common/packages/
37. **Darwin d2 overlay** — Stubs Linux-only deps so d2 builds on macOS

---

## b) PARTIALLY DONE ⚠️

| # | Item | Status | Details |
|---|------|--------|---------|
| 1 | **GPU crash resilience** | 60% | Per-service fractions done. But: no cgroup-based GPU priority for niri, DRM healthcheck causes crash loops instead of recovery, no auto-reboot on wedged GPU |
| 2 | **DNS failover cluster** | 40% | Module written, config ready. Pi 3 hardware not provisioned. Keepalived VRRP untested. |
| 3 | **earlyoom config** | 70% | niri in `--avoid` list, Ollama in `--prefer` list. But OOMScoreAdjust for niri is -900 (should be -1000), ollama has no OOMScoreAdjust override |
| 4 | **Boot performance** | 50% | Analyzed, documented. No real optimization done. evo-x2 still boots slow. |
| 5 | **Nix store cleanup** | 30% | `just clean` exists but root disk is 93% full (462G/512G). Auto-GC configured but store keeps growing. |
| 6 | **Deer Flow integration** | 20% | Running in Docker but no NixOS module, no Caddy vhost, no sops secrets. Completely manual. |
| 7 | **Module test coverage** | 10% | `just test-fast` checks Nix syntax only. No VM tests, no service start validation, no integration tests. |
| 8 | **MPTCP dual-WAN** | 50% | Module written and enabled. WiFi works. But untested with actual second WAN — no real failover validation. |
| 9 | **Photomap** | 30% | Module exists but disabled (podman config permission issue). Not behind Caddy. |

---

## c) NOT STARTED 📋

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 1 | **niri GPU cgroup priority** — Guarantee compositor gets GPU time over AI workloads | Critical | Medium |
| 2 | **Auto-reboot on GPU wedge** — Detect amdgpu stuck state, reboot automatically | High | Low |
| 3 | **NixOS VM tests** — Test that services actually start, ports bind, caddy routes work | High | High |
| 4 | **Features.md / TODO_LIST.md** — No formal feature inventory exists | Medium | Low |
| 5 | **Secrets rotation** — No automated key rotation for sops, SSH, or service tokens | Medium | Medium |
| 6 | **Backup automation** — No automated backup for Gitea, Immich DB, or config state | Medium | Medium |
| 7 | **Pi 3 provisioning** — Hardware exists, no SD image built or deployed | Medium | Low |
| 8 | **IPv6 proper support** — Currently disabled everywhere (Unbound, DNS). Should be fixed properly. | Low | Medium |
| 9 | **Darwin full parity** — macOS lacks many NixOS-specific services/config | Low | High |
| 10 | **docs/ cleanup** — 60+ top-level docs files, many outdated. Should archive. | Low | Low |
| 11 | **Pre-commit hooks** — `pre-commit-run` exists but no validation of shell scripts or Nix formatting in CI | Low | Low |

---

## d) TOTALLY FUCKED UP 💥

| # | Issue | Severity | Root Cause |
|---|-------|----------|------------|
| 1 | **🔴 GPU DRIVER WEDGED** | Critical | amdgpu OOM at 20:29 yesterday. Driver stuck in broken state. Niri SIGKILL'd 638 times. Monitor gets NO signal. **Requires reboot.** |
| 2 | **🔴 Root disk 93% full** | Critical | 462G/512G used. Only 37G free. Nix store is massive. Risk of build failures and system instability. |
| 3 | **🔴 DRM healthcheck makes things worse** | High | `niri-drm-healthcheck.timer` runs every 60s, SIGKILLs niri when GPU is wedged → restart loop. Should detect "GPU truly wedged" and trigger reboot instead of kill loop. |
| 4 | **🔴 No GPU priority for niri** | Critical | When Ollama/ComfyUI eat GPU memory, niri starves. AMD iGPU has no MPS-style scheduling. Only mitigation is memory fractions, which aren't enough when driver state corrupts. |
| 5 | **⚠️ Ollama has no OOMScoreAdjust** | Medium | Ollama's `MemoryMax = "32G"` limits RAM but not GPU VRAM. No `OOMScoreAdjust = 500` to make it first to die. earlyoom prefers it (`--prefer`), but kernel OOM won't distinguish. |
| 6 | **⚠️ Ollama still has MemoryMax=32G** | Medium | The per-runner `per_process_memory_fraction:0.45` caps GPU at ~33G. But systemd `MemoryMax=32G` caps system RAM. Two runners × 33G GPU + 32G RAM = 130G demand on a 73G GPU / 64G RAM machine. The `MemoryMax` should be lower or dynamic. |
| 7 | **⚠️ load average peaked at 33.70** | Medium | System was under extreme load from niri restart storm. 19 user sessions active. Should auto-remediate. |

---

## e) WHAT WE SHOULD IMPROVE 🏗️

### Critical (do before anything else)
1. **Reboot the machine** — amdgpu driver is wedged, no userspace fix possible
2. **Niri GPU priority** — systemd `OOMScoreAdjust=-1000` for niri (currently -900), `OOMScoreAdjust=500` for Ollama
3. **Stop DRM healthcheck crash loop** — Add "GPU truly wedged" detection → trigger system reboot, not just SIGKILL niri
4. **Nix store cleanup** — `nix-collect-garbage -d`, clean Docker, remove old generations. Root at 93% is dangerous.

### High Priority
5. **Ollama MemoryMax review** — Lower from 32G or make it dynamic based on loaded models
6. **Cgroup v2 GPU controller** — If amdgpu supports it, put Ollama/ComfyUI in a cgroup with GPU memory limits
7. **Auto-reboot on GPU hang** — Extend `gpu-recovery.sh` to detect unrecoverable state and trigger reboot
8. **Backup automation** — At minimum: Gitea repos, Immich DB, sops keys. Schedule via `scheduled-tasks.nix`

### Medium Priority
9. **NixOS VM tests** — Start with critical services (caddy, unbound, ollama)
10. **docs/ cleanup** — Archive 60+ top-level docs, keep only active references
11. **Pi 3 DNS failover** — Build SD image, deploy, test VRRP failover
12. **Deer Flow NixOS module** — Wrap Docker compose in proper flake-parts module
13. **Photomap fix** — Resolve podman permission issue, re-enable

### Architecture Improvements
14. **Reduce flake.nix complexity** — 798 lines is too large. Extract input groups into separate files.
15. **Consolidate legacy/** — ActivityWatch, iTerm2 profiles, Chrome plugins — archive or integrate properly
16. **Template for new services** — Generate boilerplate module + caddy + gatus + homepage wiring

---

## f) Top 25 Things We Should Get Done Next

### Tier 1: Stop the Bleeding (do NOW)
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Reboot evo-x2** to fix wedged amdgpu driver | 5min | Critical — restores desktop |
| 2 | **Raise niri OOMScoreAdjust to -1000** in niri-config.nix | 2min | Critical — kernel OOM spares compositor |
| 3 | **Add OOMScoreAdjust=500 to Ollama** in ai-stack.nix | 2min | Critical — Ollama dies first under memory pressure |
| 4 | **Fix DRM healthcheck** to detect wedged GPU → reboot instead of SIGKILL loop | 30min | High — prevents 638-restart crash cascades |
| 5 | **Nix store cleanup** — `nix-collect-garbage -d`, remove old generations, clean Docker | 15min | High — root at 93% is dangerous |

### Tier 2: Hardening (do this session)
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | **Add auto-reboot on GPU hang** to gpu-recovery.sh | 30min | High — prevents manual intervention |
| 7 | **Review Ollama MemoryMax** — lower to 24G or add per-runner RAM accounting | 15min | High — prevents RAM+GPU double exhaustion |
| 8 | **Add earlyoom memory threshold for GPU** — if amdgpu reports errors, kill Ollama first | 20min | Medium — proactive defense |
| 9 | **Limit Ollama concurrent models** — set `OLLAMA_MAX_LOADED_MODELS=1` | 2min | High — prevents dual-runner OOM permanently |

### Tier 3: Infrastructure (do this week)
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10 | **Pi 3 DNS failover deployment** — build image, flash, test VRRP | 2hr | High — DNS HA |
| 11 | **Backup automation** — Gitea repos, Immich DB, sops keys via scheduled-tasks.nix | 2hr | High — disaster recovery |
| 12 | **docs/ cleanup** — archive 60+ stale docs, keep active references only | 1hr | Medium — reduces noise |
| 13 | **NixOS VM test for caddy** — verify reverse proxy routes work at build time | 2hr | Medium — catches config errors |
| 14 | **Deer Flow NixOS module** — wrap Docker compose in flake-parts module | 1hr | Medium — declarative management |

### Tier 4: Quality (do this month)
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 15 | **Photomap fix and re-enable** — resolve podman permissions | 1hr | Medium — photo exploration |
| 16 | **Secrets rotation automation** — sops key rotation, service token refresh | 3hr | Medium — security hygiene |
| 17 | **Create FEATURES.md** — formal feature inventory with status indicators | 1hr | Medium — project tracking |
| 18 | **Reduce flake.nix to <400 lines** — extract input groups, module lists | 2hr | Medium — maintainability |
| 19 | **Add shellcheck to justfile** — `just validate-scripts` recipe | 30min | Low — catches script bugs |
| 20 | **IPv6 proper fix** — enable where needed, disable only where broken | 2hr | Low — network correctness |

### Tier 5: Nice to Have
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 21 | **NixOS module template** — generate boilerplate for new services | 2hr | Low — developer velocity |
| 22 | **Consolidate legacy/** — archive or properly integrate old dotfiles | 1hr | Low — cleanliness |
| 23 | **Darwin parity** — bring macOS config closer to NixOS feature set | 4hr+ | Low — cross-platform consistency |
| 24 | **Integrate shell tests into just test** — test-home-manager.sh, test-shell-aliases.sh | 30min | Low — single validation command |
| 25 | **Monitor365 re-enable** — investigate RAM usage, optimize or tune thresholds | 1hr | Low — device monitoring |

---

## g) My Top #1 Question

**How should we architect GPU memory protection for niri on an AMD APU without MPS-style scheduling?**

The core problem: On AMD Ryzen AI Max+ 395, the iGPU (73 GiB VRAM) is shared between the compositor (niri) and AI workloads (Ollama, ComfyUI). When AI workloads exhaust VRAM, amdgpu driver hangs → niri crashes → entire desktop dies. We already have per-process memory fractions (0.45 per Ollama runner), but:
- These are *hints*, not hard limits — Ollama can still exceed them during model loading
- The amdgpu driver doesn't enforce them at the kernel level
- When two runners load simultaneously, the fractions don't prevent total exhaustion

Options I'm uncertain about:
1. **cgroup v2 GPU memory controller** — Does `memory.gpu.*` actually work for amdgpu on Linux 6.x? Can we set a hard VRAM limit per cgroup?
2. **ollama max loaded models = 1** — Simple but limits parallel inference. Is the parallelism worth the crash risk?
3. **systemd `IOWeight` / `CPUWeight`** — Doesn't help with VRAM allocation specifically
4. **Start Ollama after niri** with a delay — Fragile, doesn't prevent VRAM exhaustion later

What's the RIGHT architectural approach here?

---

## Recent Session History (Sessions 57-62)

| Session | Date | Focus |
|---------|------|-------|
| 57 | May 8 | DNS IPv6 outage fix, monitoring hardening |
| 58 | May 10 | WiFi enablement, MPTCP dual-WAN, DNS panic |
| 59 | May 10 | GPU memory crisis, crash forensics, full audit |
| 60 | May 10 | Architecture relocation sprint, full system audit |
| 61 | May 10 | Crash forensics, GPU budget architecture, resilience hardening |
| **62** | **May 11** | **Full status audit, GPU driver recovery, system prioritization** |

## Commits Since Session 61

| Commit | Description |
|--------|-------------|
| `a5322e87` | docs(status): session 61 — crash forensics, GPU budget architecture, resilience hardening |
| `c7c0f6af` | chore(flake.lock): update homebrew-cask input lock |
| `9ac7d18e` | docs: update GPU memory budget and document dual-runner OOM incident |

**No code changes since session 61.** The system has been running (or crashing) with the same configuration for ~12 hours.
