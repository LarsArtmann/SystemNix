# Session 59 — GPU Memory Crisis, DNS Migration, Full System Audit

**Date:** 2026-05-10 20:52 CEST
**Host:** evo-x2 (AMD Ryzen AI Max+ 395, 128GB RAM, 64GB iGPU VRAM)
**Kernel:** Linux 7.0.1
**Uptime:** 41 minutes (3 crashes in last 24 hours)
**Branch:** master (clean working tree)

---

## Executive Summary

The system is in a **degraded state** with repeated GPU memory exhaustion crashes. The fix (GTT ceiling raise to 112GB) was committed in `62d5de0f` but **never deployed** — `just switch` was not run. Meanwhile, the DNS blocker migration to flake-parts architecture was completed. The awww-daemon wallpaper service is in a continuous crash loop. Multiple services have active issues. The system has 15,602 historical coredumps with 31 crashes today alone.

---

## a) FULLY DONE ✓

### DNS Blocker Migration to flake-parts (d88d80ca)
- Migrated from legacy `modules/` to flake-parts architecture
- New module: `modules/nixos/services/dns-blocker.nix`
- Self-contained module with `services.dns-blocker` options
- Unbound + dnsblockd integration preserved
- All 25 blocklists, 2.5M+ domains still blocked
- RPi3 config updated to use shared `local-network.nix` and blocklist logic

### GPU GTT/TTM Ceiling Fix (62d5de0f)
- Raised `amdgpu.gttsize` from 32GB → 112GB (114688 MB)
- Set `amdgpu.ttm.pages_limit` to 8388608 (32GB pages)
- **⚠️ COMMITTED BUT NOT DEPLOYED** — system still running with 32GB GTT

### Shared lib Refactoring Sprint (7d8b2e1d → b98f99a0)
- Created `lib/default.nix` single-import pattern
- Migrated all 22 service modules to use unified import
- `harden`, `serviceDefaults`, `serviceTypes` all accessible via one import
- Added `serviceDefaultsUser` variant for Home Manager user services

### Port DRY Sprint (0b8b5189 + related)
- Eliminated all hardcoded port references across Gatus, Homepage, SigNoz, Voice-Agents
- Every service now uses `config.services.<name>.port` in Caddy config

### Cross-Platform Programs (14 modules)
All functional and shared between Darwin + NixOS:
- fish, zsh, bash, starship, git, tmux, fzf, taskwarrior
- activitywatch, keepassxc, pre-commit, shell-aliases, ssh-config, chromium

### Core Infrastructure
- ✅ Niri scrollable-tiling compositor — working with SDDM
- ✅ Waybar — status bar with Catppuccin Mocha theme
- ✅ Caddy reverse proxy — TLS via sops for all `*.home.lan` domains
- ✅ Sops-nix — age-encrypted secrets via SSH host key
- ✅ Home Manager — cross-platform (nix-darwin + NixOS)
- ✅ flake-parts — 35+ service modules, modular architecture
- ✅ Taskwarrior 3 + TaskChampion sync — deterministic client IDs, zero manual setup
- ✅ SSH hardening — keys only, fail2ban, no root login
- ✅ BTRFS snapshots — Timeshift, zstd compression on root, zstd:3 on /data
- ✅ Nix GC timer — weekly cleanup
- ✅ Smartd — disk health monitoring with scheduled short/long tests
- ✅ EMEET PIXY webcam daemon — auto face tracking, audio switching, Waybar integration

### Service Stack (Enabled & Functional)
| Service | Port | Virtual Host | Status |
|---------|------|-------------|--------|
| Caddy | 2019 (metrics) | Reverse proxy | ✅ Running |
| Gitea | (config) | git.home.lan | ✅ Running |
| Immich | (config) | immich.home.lan | ✅ Running |
| Homepage | (config) | dash.home.lan | ✅ Running |
| Authelia | (config) | auth.home.lan | ✅ Running |
| TaskChampion | 10222 | tasks.home.lan | ✅ Running |
| SigNoz | 8080 | signoz.home.lan | ✅ Running |
| Hermes AI | — | Discord bot | ✅ Running |
| ComfyUI | (config) | comfyui.home.lan | ✅ Running |
| Gatus | (config) | status.home.lan | ✅ Running |
| OpenSEO | 3001 | seo.home.lan | ✅ Running |
| Manifest | (config) | manifest.home.lan | ✅ Running |
| Ollama | 11434 | ai.home.lan | ✅ Running |
| Whisper ASR | (config) | — | ✅ Running |
| LiveKit | (config) | — | ✅ Running |
| Twenty CRM | (config) | crm.home.lan | ✅ Running |
| Minecraft | 25565 | LAN only | ✅ Running |
| AI Models | — | Centralized /data/ai/ | ✅ Running |
| Dual-WAN | — | MPTCP + route health | ✅ Running |
| DNS Blocker | 53/443 | Unbound + dnsblockd | ✅ Running |
| SDDM + Niri | — | Display manager | ✅ Running |

---

## b) PARTIALLY DONE ⚠️

### GPU Memory Management
- **GTT ceiling fix committed but NOT deployed** — `just switch` never run
- `amdgpu.deepfl=1` is silently ignored: `amdgpu: unknown parameter 'deepfl' ignored`
- Running config still has `gttsize=32768` (32GB) instead of 112GB
- `PYTORCH_CUDA_ALLOC_CONF=per_process_memory_fraction:0.95` set but insufficient when GTT is the bottleneck

### RPi3 DNS Failover Cluster
- Config written in `platforms/nixos/rpi3/default.nix`
- Keepalived VRRP module created (`modules/nixos/services/dns-failover.nix`)
- **Pi 3 hardware not yet provisioned** — cluster exists in code only
- RPi3 image build: `nixosConfigurations.rpi3-dns` in flake.nix

### Darwin (macOS) Platform
- Basic config works: Home Manager, shared overlays, packages
- d2 overlay fix applied (524be5ab) — stubs Linux-only deps
- Missing: ActivityWatch launch agents status unknown, no Darwin-specific health checks

### awww-daemon Wallpaper System
- Self-healing architecture in code (PartOf + Restart=always)
- **BUT**: Currently in crash loop — 19 SIGABRT coredumps in 37 minutes
- Upstream awww 0.12.0 BrokenPipe bug at `daemon/src/main.rs:712:32`
- `Restart=always` keeps restarting but daemon never stabilizes

### PhotoMap
- Module exists (`modules/nixos/services/photomap.nix`)
- **Disabled**: podman config permission issue
- DNS records still present in some configs, removed from homepage

---

## c) NOT STARTED ○

1. **Pi 3 hardware provisioning** — DNS failover cluster is code-only
2. **Darwin nix-settings consolidation** — moved to `platforms/common/nix-settings.nix` but may need verification
3. **Polkit KDE agent fix** — `Qt platform plugin could not be initialized` errors on every authentication prompt
4. **ComfyUI CHDIR failure** — `comfyui-check-venv` service fails: `No such file or directory` for working directory
5. **Monitor365** — disabled due to high RAM usage, no fix attempted
6. **Watchdogd** — `device` and `reset-reason` settings broken upstream in nixpkgs, workaround applied but no resolution tracking
7. **pstore integration** — kernel parameters set (`pstore.backend=efi`, `pstore.record_console=true`) but no automated crash log collection/analysis
8. **NPU (AMD XDNA)** — driver loaded but no workloads configured
9. **IPv6** — globally disabled in DNS, no IPv6 connectivity plan
10. **Automated backup verification** — Timeshift configured but no restore testing
11. **Secrets rotation** — sops secrets have no rotation schedule
12. **Disaster recovery** — no tested bare-metal restore procedure
13. **Cross-platform testing** — Darwin changes not verified since session 56

---

## d) TOTALLY FUCKED UP 💥

### 1. GPU Memory Exhaustion — System-Killing Bug (ACTIVE NOW)

**Severity: CRITICAL — causes desktop freeze + reboot**

| Boot | Duration | GPU OOMs | Outcome |
|------|----------|----------|---------|
| -6 (May 6) | 16 min | 0 | Reboot (unknown cause) |
| -5 (May 6–8) | 2 days | 0 | Normal |
| -4 (May 8–9) | 18h | 0 | Normal |
| -3 (May 9) | 13h | 0 | Normal |
| -2 (May 9–10) | ~24h | 3 | **GPU OOM** → kitty SIGSEGV → niri killed → reboot |
| -1 (May 10) | **8 min** | 0 | Caddy watchdog timeout x3 → watchdog-fired reboot |
| 0 (May 10) | 41 min | 5 | **GPU OOM** again at 20:29 |

The 32GB GTT ceiling starves GPU clients when AI workloads allocate large buffers. With 128GB RAM and a 64GB VRAM iGPU, this is 25% of available memory. The fix is **committed but not deployed** — the single most critical action is `just switch`.

### 2. awww-daemon Crash Loop (ACTIVE NOW)

19 SIGABRT coredumps in 37 minutes. The daemon crashes every ~70 seconds. `Restart=always` masks the problem but generates continuous coredumps (37.9KB each). Known upstream bug in awww 0.12.0. Root cause: Wayland disconnect during GPU memory pressure exacerbates the BrokenPipe.

### 3. 15,602 Historical Coredumps

The system has accumulated 15,602 coredumps. This consumes disk space and indicates long-standing instability. Root causes: GPU OOMs (kitty, helium), awww-daemon BrokenPipe, Hermes anime-comic-pipeline SIGSEGV.

### 4. Root Filesystem 89% Full

```
/dev/nvme0n1p6  512G  442G   57G  89%  /
```

57GB free on root. Nix store, coredumps, and old generations are consuming space. `/data` is 69% used (325GB free) — healthy.

### 5. Swap Under Pressure

```
Mem:   62Gi total, 19Gi used, 42Gi available
Swap:  25Gi total, 9.4Gi used
```

9.4GB of swap used with 42GB RAM available suggests leftover memory pressure from previous GPU-related crashes. ZRAM (15.6GB) is 54% full.

### 6. `amdgpu.deepfl=1` Parameter Ignored

Every boot logs: `amdgpu: unknown parameter 'deepfl' ignored`. The parameter name is wrong for kernel 7.0.1 — either renamed or removed. Deep color support status unknown.

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Architecture & Code Quality
1. **Eliminate coredump accumulation** — add `systemd-tmpfiles` rule to auto-clean coredumps older than 7 days
2. **Fix `deepfl` parameter** — research correct amdgpu parameter for kernel 7.0.1 or remove it
3. **ComfyUI working directory** — fix the CHDIR failure in `comfyui-check-venv` service
4. **Polkit KDE agent** — fix Qt platform plugin initialization on Wayland
5. **Consolidate DNS blocklist logic** — RPi3 duplicates blocklist processing; extract to shared module
6. **Stale commented-out imports** — `configuration.nix` has 8 commented-out `# ../services/...` lines from pre-flake-parts migration
7. **Disk space monitoring** — root at 89% needs attention; add nix-store auto-optimization or generation cleanup

### Reliability & Observability
8. **Boot crash detection** — systemd service that detects if previous boot was < 5 min and alerts
9. **GPU memory monitoring** — expose GTT/VRAM usage to SigNoz/Gatus as health endpoint
10. **Automated deployment verification** — after `just switch`, verify critical services are running before declaring success
11. **Cross-platform CI** — at minimum, `nix flake check` on both Darwin and NixOS

### Security & Operations
12. **Secrets rotation schedule** — define and automate sops secret rotation
13. **Backup restore testing** — verify Timeshift restores work at least quarterly
14. **Bare-metal recovery docs** — document step-by-step restore from BTRFS snapshots + sops secrets

---

## f) Top 25 Things We Should Get Done Next

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | **P0** | **Deploy GTT fix**: `just switch` to activate 112GB GTT ceiling | System stability | 5 min |
| 2 | **P0** | **Fix awww-daemon crash loop** — upgrade to fixed version or add backoff | Desktop wallpaper | 30 min |
| 3 | **P0** | **Clean root filesystem** — `nix-collect-garbage -d`, remove old generations, clean coredumps | Disk space | 15 min |
| 4 | **P0** | **Fix `amdgpu.deepfl=1`** — find correct parameter or remove | Boot noise | 15 min |
| 5 | **P1** | Fix ComfyUI CHDIR failure — update working directory path | AI image generation | 20 min |
| 6 | **P1** | Fix Polkit KDE agent Qt platform plugin error | Authentication UX | 30 min |
| 7 | **P1** | Add coredump auto-cleanup tmpfiles rule | Disk hygiene | 10 min |
| 8 | **P1** | Verify Darwin build still works after recent changes | Cross-platform | 20 min |
| 9 | **P1** | Add GPU memory metrics to SigNoz/Gatus | Observability | 1h |
| 10 | **P1** | Clean up commented-out imports in configuration.nix | Code cleanliness | 5 min |
| 11 | **P2** | Extract shared DNS blocklist module (deduplicate RPi3 + evo-x2) | DRY | 2h |
| 12 | **P2** | Provision Pi 3 hardware for DNS failover cluster | HA DNS | 2h |
| 13 | **P2** | Add boot crash detection service (previous boot < 5 min alert) | Reliability | 1h |
| 14 | **P2** | Test bare-metal BTRFS restore procedure | Disaster recovery | 2h |
| 15 | **P2** | Implement secrets rotation schedule for sops | Security | 3h |
| 16 | **P2** | Enable NPU workloads with AMD XDNA driver | AI capability | 4h |
| 17 | **P2** | Add automated `nix flake check` to git pre-push hook | Quality gate | 30 min |
| 18 | **P2** | Fix Monitor365 RAM usage or find lighter alternative | Device monitoring | 2h |
| 19 | **P2** | Document bare-metal disaster recovery procedure | Operations | 2h |
| 20 | **P3** | Investigate pstore crash log collection automation | Forensics | 2h |
| 21 | **P3** | Add IPv6 connectivity plan and gradual rollout | Networking | 4h |
| 22 | **P3** | Verify Timeshift backup restore works end-to-end | Backup integrity | 1h |
| 23 | **P3** | Add cross-platform health check to justfile (Darwin + NixOS) | Operations | 1h |
| 24 | **P3** | Audit all 35+ flake-parts modules for consistent option patterns | Code quality | 3h |
| 25 | **P3** | Create automated deployment pipeline (build → test → switch) | DevOps | 4h |

---

## g) Top #1 Question I Cannot Answer Myself

**What triggered the GPU memory exhaustion on boot -2 (May 10, ~19:56)?**

The previous boots (-6 through -3) ran fine with 32GB GTT. Something changed around 19:56 on May 10 that saturated the GTT:
- Was an AI workload (Ollama inference, ComfyUI generation, Hermes pipeline) running?
- Did someone open many kitty terminals or GPU-accelerated applications simultaneously?
- Did a previous `just switch` or system update change GPU memory behavior?

The journal shows kitty, helium, Xwayland, and niri all leaked VM memory — but which process was the **initial consumer** that pushed GTT over 32GB? The kernel logs only show the cascade, not the root cause. Checking what Ollama models were loaded or what ComfyUI workflows were running at 19:56 would answer this.

---

## System Resources

```
Memory:   62GB total / 19GB used / 42GB available
Swap:     25GB total / 9.4GB used (8.5GB in ZRAM)
Root:     512GB / 442GB used / 57GB free (89%)
Data:     1.0TB / 699GB used / 325GB free (69%)
GPU VRAM: 64GB (65536M detected)
GPU GTT:  32GB (SHOULD BE 112GB — fix not deployed)
Load:     3.28 / 1.24 / 1.38
Uptime:   41 minutes
Boots:    10 boots in 11 days (too many reboots)
Coredumps: 15,602 total / 31 today
```

## Kernel Boot Parameters (Current)

```
amdgpu.deepfl=1          ← IGNORED by kernel 7.0.1
amdgpu.gttsize=32768     ← SHOULD BE 114688 (fix not deployed)
amdgpu.ttm.pages_limit=8388608
amdgpu.lockup_timeout=30000
amdgpu.gpu_recovery=1
amd_pstate=guided
amd_iommu=on
iommu.passthrough=0
pstore.backend=efi
pstore.record_console=true
pstore.max_reason=3
```

## Active Coredump Producers (Today)

| Process | Signal | Count | Cause |
|---------|--------|-------|-------|
| awww-daemon | SIGABRT | ~20+ | BrokenPipe crash loop (upstream 0.12.0 bug) |
| helium | SIGSEGV | 2 | GPU memory exhaustion → browser crash |
| Xorg | SIGABRT | 1 | GPU memory exhaustion → XWayland crash |

## Immediate Action Required

1. `just switch` — deploy the 112GB GTT fix (commit 62d5de0f)
2. Investigate awww-daemon crash loop — possibly fixed by GPU memory fix reducing pressure
3. Clean coredumps: `coredumpctl vacuum` or tmpfiles rule
4. Run `nix-collect-garbage -d` to free disk space on root
