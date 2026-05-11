# Session 65: Full Comprehensive Status — GPU Defense Deployed, System Awaiting Reboot

**Date:** 2026-05-11 10:58 CEST
**Uptime:** 14h50m | **Load:** 4.77, 9.45, 10.13 | **Kernel:** 7.0.1 (stable is 7.0.6)
**Root disk:** 90% (54G free, was 93% before cleanup) | **Data disk:** 67% (339G free)
**GPU VRAM:** 49 GiB / 64 GiB used (driver still wedged from OOM ~15h ago)
**RAM:** 21G/62G | **Git:** clean, 3 commits ahead of origin/master

---

## Executive Summary

Since the GPU OOM crash incident on 2026-05-10 (~15 hours ago), we have:

1. **Diagnosed the root cause**: Ollama loaded two model runners simultaneously, each at 95% GPU memory fraction = 138 GiB demand on 73 GiB GPU → amdgpu exhaustion → niri SIGABRT → cascading OOM kills
2. **Researched the full hardware/software stack**: 320-line deep dive into AMD Ryzen AI Max+ 395 (Strix Halo) SoC, GPU memory architecture, Linux 7 kernel, AMDGPU driver, Ollama internals
3. **Implemented multi-layer GPU defense**: `OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_GPU_OVERHEAD=8GiB`, OOM priority tuning, DRM healthcheck rewrite, GPU recovery auto-reboot
4. **Investigated the 130W power ceiling**: GMKtec firmware PPT limit, no OS override possible, newer BIOS image identified but not yet extracted
5. **Switched to amd_pstate=performance** to maximize CPU utilization within the 130W ceiling

**Current state**: All changes are committed and verified (`just test-fast` passes). **Nothing is deployed** — `just switch` has not been run. The amdgpu driver remains wedged from the original OOM incident. A system reboot is required to clear the GPU state and deploy all changes.

---

## a) FULLY DONE (37 items)

### GPU OOM Defense (Sessions 61-63, all committed)

| # | Item | File | Commit |
|---|------|------|--------|
| 1 | `OLLAMA_MAX_LOADED_MODELS=1` — prevents dual-runner OOM | `ai-stack.nix` | `0056a683` |
| 2 | `OLLAMA_GPU_OVERHEAD=8589934592` (8 GiB reserved for compositor) | `ai-stack.nix` | `0056a683` |
| 3 | `OOMScoreAdjust=500` on Ollama — OOM killer prefers killing Ollama | `ai-stack.nix` | `0056a683` |
| 4 | `OOMScoreAdjust=-1000` on niri — maximum OOM protection (was -900) | `niri-config.nix` | `0056a683` |
| 5 | DRM healthcheck: consecutive failure thresholding (3 strikes) | `niri-drm-healthcheck.sh` | `0056a683` |
| 6 | GPU recovery: auto-reboot on all unrecoverable states | `gpu-recovery.sh` | `0056a683` |
| 7 | GPU recovery: 5s post-niri-start verification window (was 3s) | `gpu-recovery.sh` | `0056a683` |
| 8 | DRM healthcheck: state file auto-reset when errors clear | `niri-drm-healthcheck.sh` | `0056a683` |

### Power & Performance (Sessions 63-64, all committed)

| # | Item | File | Commit |
|---|------|------|--------|
| 9 | `amd_pstate=guided` → `amd_pstate=performance` | `boot.nix` | `99495f22` |
| 10 | `powerManagement.cpuFreqGovernor = "performance"` | `boot.nix` | `99495f22` |
| 11 | 130W power ceiling documented in Known Issues | `AGENTS.md` | `3577431a` |
| 12 | Power ceiling root cause analysis (firmware PPT, no OS override) | `docs/status/` | `99495f22` |
| 13 | GMKtec BIOS version audit (v1.11, newer `251028b` exists) | `docs/status/` | `f519fcb3` |

### Research & Documentation (Sessions 61-64, all committed)

| # | Item | File | Lines |
|---|------|------|-------|
| 14 | Strix Halo + Linux 7 GPU architecture deep dive | `docs/research/2026-05-11_STRIX-HALO-LINUX7-GPU-ARCHITECTURE-DEEP-DIVE.md` | 320 |
| 15 | Session 61: Crash forensics + GPU budget | `docs/status/2026-05-10_21-13_SESSION-61-CRASH-FORENSICS-GPU-BUDGET-RESILIENCE.md` | — |
| 16 | Session 62: Full status + GPU recovery prioritization | `docs/status/2026-05-11_09-39_SESSION-62-FULL-STATUS-GPU-RECOVERY-PRIORITIZATION.md` | 299 |
| 17 | Session 63: Power ceiling + GPU recovery + Ollama stability | `docs/status/2026-05-11_10-49_SESSION-63-POWER-CEILING-GPU-RECOVERY-OLLAMA-STABILITY.md` | 177 |
| 18 | Session 64: GMKtec BIOS discovery | `docs/status/2026-05-11_10-57_SESSION-64-GMKTEC-BIOS-DISCOVERY-POWER-CEILING-PATH.md` | 174 |
| 19 | AGENTS.md updated with GPU defense details | `AGENTS.md` | +26 lines |
| 20 | AGENTS.md updated with DRM healthcheck + GPU recovery section | `AGENTS.md` | new section |

### Previously Completed (Sessions 58-60)

| # | Item | Status |
|---|------|--------|
| 21 | Ollama `per_process_memory_fraction` lowered from 0.95 → 0.45 | Committed & deployed |
| 22 | System-wide `PYTORCH_CUDA_ALLOC_CONF` session variable removed | Committed & deployed |
| 23 | Earlyoom config: niri in `--avoid`, Ollama in `--prefer` | Committed & deployed |
| 24 | GPU recovery script created (unbind/rebind amdgpu) | Committed & deployed |
| 25 | DRM healthcheck timer (60s) created | Committed & deployed |
| 26 | awww-daemon crash loop prevention (ExecStartPre Wayland check, StartLimitBurst=3) | Committed & deployed |
| 27 | awww-daemon basic sandboxing | Committed & deployed |
| 28 | `amdgpu.gttsize=112` kernel parameter | Committed & deployed |
| 29 | Kernel hardening: `sysrq=1`, `panic=30`, `softlockup_panic=1`, `hung_task_panic=1` | Committed & deployed |
| 30 | `amdgpu.gpu_recovery=1` kernel parameter | Committed & deployed |
| 31 | watchdogd SP5100 TCO configuration | Committed & deployed |
| 32 | Helium `--restore-last-session --disable-session-crashed-bubble` | Committed & deployed |
| 33 | DNS IPv6 outage fix (unbound `do-ip6=false`) | Committed & deployed |
| 34 | Architecture relocation (modules → proper flake-parts) | Committed & deployed |
| 35 | Script arithmetic normalization | Committed & deployed |
| 36 | `OLLAMA_NUM_PARALLEL` reduced from 4 → 2 | Committed & deployed |
| 37 | `OLLAMA_KV_CACHE_TYPE=q8_0` for memory efficiency | Committed & deployed |

---

## b) PARTIALLY DONE (7 items)

| # | Item | What's Done | What's Missing |
|---|------|-------------|----------------|
| 1 | **Deploy all GPU defense changes** | Committed, `test-fast` passes | `just switch` not run — **requires reboot first** |
| 2 | **GPU driver recovery** | gpu-recovery.sh rewritten with auto-reboot | Amdgpu still wedged, reboot needed to clear |
| 3 | **BIOS power ceiling investigation** | Root cause found (firmware PPT), newer BIOS identified (`251028b`) | Not extracted, not flashed, BIOS menus not checked |
| 4 | **Root disk cleanup** | `just clean` freed 2.5 GiB (93% → 90%) | Still at 90%, coredumps not cleaned, old generations remain |
| 5 | **DRM healthcheck state file** | Implemented with `/tmp/` path | Should move to `/var/lib/` for persistence across tmpfiles resets |
| 6 | **Kernel update (7.0.1 → 7.0.6)** | Identified as needed (Dirty Frag vulnerability) | Not updated — requires nixpkgs input update + rebuild |
| 7 | **DNS failover cluster** | Module written (`dns-failover.nix`), Pi 3 image config in flake.nix | Pi 3 hardware not provisioned |

---

## c) NOT STARTED (13 items)

| # | Item | Priority | Effort |
|---|------|----------|--------|
| 1 | Reboot system to deploy all changes and clear wedged GPU | P0 | 5min |
| 2 | `just switch` after reboot | P0 | 30min |
| 3 | Verify Ollama stability under load with MAX_LOADED_MODELS=1 | P1 | 30min |
| 4 | Test GPU recovery auto-reboot flow (simulate DRM zombie) | P1 | 20min |
| 5 | Reboot into BIOS → check AMD CBS/AMD PBS menus for PPT | P1 | 10min |
| 6 | Try Ctrl+F1 in BIOS Advanced tab for hidden menus | P1 | 2min |
| 7 | Download `251028b` image on another machine (85 GB) | P2 | 2hr+ |
| 8 | Extract BIOS `.cap` from `251028b` image | P2 | 30min |
| 9 | Contact GMKtec support for standalone BIOS | P2 | 20min |
| 10 | Move healthcheck state file from `/tmp` to `/var/lib` | P2 | 5min |
| 11 | Update nixpkgs input for kernel 7.0.6 (Dirty Frag fix) | P2 | 15min |
| 12 | Add power estimation to waybar (RAPL energy_uj delta) | P3 | 30min |
| 13 | Write AMI IFR parser for EFI variable analysis | P4 | 1hr |

---

## d) TOTALLY FUCKED UP (4 items)

### 1. System has been in degraded state for 15+ hours

The amdgpu driver has been wedged since the OOM incident on 2026-05-10. Niri has been killed 638+ times. The monitor gets no signal. **We've been writing code on a machine with a broken GPU for over half a day.** This should have been fixed with a reboot hours ago instead of continuing to write code.

### 2. 3 commits ahead of origin/master — nothing deployed

All the GPU defense work (MAX_LOADED_MODELS, GPU_OVERHEAD, OOMScoreAdjust, healthcheck rewrite, auto-reboot) is committed but NOT deployed. If the machine rebooted right now, it would boot into the OLD configuration without any of these protections. The OOM could happen again immediately.

### 3. GMKtec BIOS situation

No standalone BIOS updates. Only 85 GB Windows images. No changelog. No documentation. No way to know if `251028b` even changes power limits. This is a vendor problem we can't solve without their cooperation or reverse engineering their image.

### 4. Root disk at 90% despite cleanup

`just clean` only freed 2.5 GiB. 90% is still dangerously high for a machine that does full NixOS rebuilds regularly. Coredumps, old Docker images, and stale build artifacts are likely consuming significant space.

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Reboot FIRST, code SECOND** — The GPU was wedged for 15+ hours while we wrote research docs and code. We should have rebooted immediately after diagnosing the crash, then done the code changes on a healthy system.

2. **Deploy immediately after committing** — There's a 15-hour gap between "fix committed" and "fix deployed." This defeats the purpose of the fix. If the OOM happens again before deploy, we're back to square one.

3. **Root disk monitoring** — 90% should have triggered alerts weeks ago. We need automated monitoring (gatus + SigNoz alert).

4. **Session continuity** — Sessions 58-65 (8 sessions) have been dealing with the same GPU OOM incident. Better initial diagnosis could have compressed this into 2-3 sessions.

### Technical Improvements

5. **Ollama GPU monitoring** — We have no visibility into Ollama's GPU usage. Should add a Prometheus exporter or log parser to SigNoz.

6. **Per-process GPU memory tracking** — `/sys/class/drm/card1/device/mem_info_*` only shows aggregate VRAM. We need per-process tracking (potentially via ROCm SMI or custom script).

7. **GPU memory pressure alerts** — When VRAM usage exceeds 85%, trigger an alert before OOM.

8. **Niri crash rate alerting** — If niri restarts >5 times in 10 minutes, something is very wrong. Should trigger immediate investigation.

9. **DRM healthcheck state persistence** — `/tmp/` is cleared on reboot (which defeats the purpose). Move to `/var/lib/niri-drm-healthcheck/state`.

10. **Kernel update cadence** — Running 7.0.1 when 7.0.6 is available is a 5-version gap. Dirty Frag CVE may be unfixed. Should establish a regular nixpkgs update cadence.

---

## f) Top #25 Things We Should Get Done Next

| # | Priority | Task | Effort | Impact |
|---|----------|------|--------|--------|
| 1 | **P0** | **Reboot the system** to clear wedged amdgpu driver | 5min | Unblocks everything |
| 2 | **P0** | **`just switch`** to deploy all GPU defense changes | 30min | Activates protections |
| 3 | **P0** | **Verify niri starts cleanly** after reboot + deploy | 5min | Confirms recovery |
| 4 | **P1** | **Test Ollama with MAX_LOADED_MODELS=1** — load a model, verify only one runner | 15min | Validates fix |
| 5 | **P1** | **Test GPU recovery auto-reboot** — simulate DRM zombie | 20min | Validates safety net |
| 6 | **P1** | **Reboot into BIOS → check AMD CBS menus** for PPT/TDP controls | 10min | Could unlock power ceiling |
| 7 | **P1** | **Try Ctrl+F1 in BIOS Advanced tab** for hidden AMD menus | 2min | Could reveal PPT options |
| 8 | **P1** | **Root disk deep cleanup** — `/var/lib/systemd/coredump/`, docker system prune, old logs | 30min | Prevents build failures |
| 9 | **P1** | **Push to origin** — 3 commits behind remote | 1min | Safety backup |
| 10 | **P2** | **Update nixpkgs** for kernel 7.0.6 (Dirty Frag CVE fix) | 15min | Security |
| 11 | **P2** | **Move healthcheck state file** from `/tmp/` to `/var/lib/` | 5min | Correctness |
| 12 | **P2** | **Add Ollama GPU monitoring** to SigNoz (VRAM usage, runner count) | 1hr | Observability |
| 13 | **P2** | **Add niri crash rate alerting** to SigNoz or gatus | 30min | Early warning |
| 14 | **P2** | **Add disk space monitoring** to gatus (90% root threshold) | 15min | Proactive |
| 15 | **P2** | **Download `251028b` image** on another machine (85 GB) | 2hr+ | BIOS upgrade path |
| 16 | **P2** | **Contact GMKtec support** for standalone BIOS + PPT info | 20min | BIOS path |
| 17 | **P2** | **Provision Pi 3** for DNS failover cluster | 2hr | HA DNS |
| 18 | **P3** | **Extract BIOS `.cap` from `251028b`** image | 30min | BIOS upgrade |
| 19 | **P3** | **Add power estimation widget** to waybar | 30min | Visibility |
| 20 | **P3** | **Test dual-WAN failover** (mptcp-endpoint-manager) | 1hr | Network resilience |
| 21 | **P3** | **Audit all 17 gatus health check endpoints** | 15min | Monitoring accuracy |
| 22 | **P3** | **Add GPU memory pressure alert** (VRAM > 85%) | 30min | Preventive |
| 23 | **P3** | **Review awww-daemon sandboxing** completeness | 15min | Security |
| 24 | **P4** | **Write AMI IFR parser** for EFI variable analysis | 1hr | BIOS exploration |
| 25 | **P4** | **Test full recovery chain**: GPU hang → auto-reboot → session restore → niri healthy | 30min | End-to-end validation |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should I reboot the system NOW to deploy the GPU defense changes and clear the wedged amdgpu driver?**

I've been working on a system with a broken GPU for 15 hours. All the fixes are committed but not deployed. The machine needs:
1. A reboot to clear the wedged amdgpu driver state
2. `just switch` to deploy OLLAMA_MAX_LOADED_MODELS=1, GPU_OVERHEAD, OOMScoreAdjust, and the rewritten recovery scripts

But I cannot reboot because:
- You may have active work in other terminals
- Docker containers may have in-flight operations
- The session state (niri windows) will be lost
- You may want to review the changes first

**This is the single highest-impact action available.** Every minute we delay, the system runs without GPU OOM protection and with a wedged driver.

---

## System Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Root disk | 90% (54G free) | Warning |
| Data disk | 67% (339G free) | OK |
| GPU VRAM | 49 GiB / 64 GiB used | Wedged |
| RAM | 21G / 62G | OK |
| Load avg | 4.77, 9.45, 10.13 | Elevated (recovering) |
| Kernel | 7.0.1 | Outdated (7.0.6 available) |
| Uptime | 14h50m | Since last OOM crash |
| Nix files | 109 files, 14,134 LOC | — |
| Service modules | 35 | — |
| Custom packages | 9 | — |
| Scripts | 11 | — |
| Docker containers | 11 running | — |
| Commits ahead | 3 | Unpushed |

## Deploy Status

| Change | Committed | Deployed | Tested |
|--------|-----------|----------|--------|
| OLLAMA_MAX_LOADED_MODELS=1 | ✅ | ❌ | ❌ |
| OLLAMA_GPU_OVERHEAD=8GiB | ✅ | ❌ | ❌ |
| Ollama OOMScoreAdjust=500 | ✅ | ❌ | ❌ |
| Niri OOMScoreAdjust=-1000 | ✅ | ❌ | ❌ |
| GPU recovery auto-reboot | ✅ | ❌ | ❌ |
| DRM healthcheck thresholding | ✅ | ❌ | ❌ |
| amd_pstate=performance | ✅ | ❌ | ❌ |
| Performance governor | ✅ | ❌ | ❌ |
| AGENTS.md GPU defense docs | ✅ | ✅ (docs) | ✅ |
| AGENTS.md DRM healthcheck section | ✅ | ✅ (docs) | ✅ |
| Strix Halo research doc | ✅ | ✅ (docs) | ✅ |

## Git Log (last 10 commits)

```
f519fcb3 docs(status): session 64 — GMKtec BIOS discovery, actionable power ceiling path
0056a683 fix(gpu): harden recovery scripts and stabilize Ollama against dual-runner OOM
99495f22 feat(power): switch amd_pstate to performance mode, document 130W hardware ceiling
628fa63f docs(research): deep dive into Strix Halo + Linux 7 + GPU memory protection
3577431a docs(boot): switch amd_pstate to performance mode, document 130W hardware ceiling
a9c8ecd5 docs(status): session 62 — full system status, GPU driver recovery, prioritization
554010b0 fix(scripts): normalize arithmetic expression spacing and tmpfiles indentation
a5322e87 docs(status): session 61 — crash forensics, GPU budget architecture, resilience hardening
c7c0f6af chore(flake.lock): update homebrew-cask input lock
9ac7d18e docs: update GPU memory budget and document dual-runner OOM incident
```
