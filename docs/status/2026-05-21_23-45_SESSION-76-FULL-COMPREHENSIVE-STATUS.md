# Session 76 — Full Comprehensive Status

**Date:** 2026-05-21 23:45 CEST
**Hostname:** evo-x2 | **Uptime:** 26 min | **Load:** 8.82, 9.90, 8.12
**Platform:** NixOS unstable (nixos-unstable) | **Kernel:** 7.x
**Branch:** master — **up to date with origin**

---

## Executive Summary

System rebooted ~26 min ago following a GPU crash (amdgpu unbind during OOM pressure, fixed in `236ca5ce`). Hermes Python dependencies expanded to include `firecrawl`, `edge-tts`, `fal`, `exa` — all 6 extras now pre-built in Nix sealed venv (deployed, no ImportError). Boot performance improved to **3m 54s** total but **initrd takes 1m 44s** (TPM + NVMe device wait — hardware-level, not fixable via Nix config). Userspace reached graphical.target in **1m 31s**. System is functional but under memory pressure: 13 gopls instances consuming ~6.6 GiB RSS, swap at 5.8/13 GiB. Nix store GC freed 7.5 GiB earlier today. Flake lock updated with 14 upstream inputs. All 35 service modules evaluate clean.

---

## A) FULLY DONE ✅

### Hermes Python Dependency Expansion (Session 75-76)
- **Problem:** Hermes tools (web_search, TTS, image gen) silently fail because pip is unavailable in Nix sealed venv
- **Fix:** Expanded `extraDependencyGroups` from `["messaging" "anthropic"]` to `["messaging" "anthropic" "firecrawl" "edge-tts" "fal" "exa"]`
- **New packages in sealed venv:** firecrawl-py, edge-tts, fal-client, exa-py (+ transitive deps)
- **Deployed:** Yes — running since 23:23, no ImportError in journal
- **Committed:** `480fca99`

### GPU Recovery Safety Fix (Session 75-76)
- **Problem:** `niri-drm-healthcheck` triggered `gpu-recovery.sh` which unbound amdgpu PCI device during OOM pressure → hard crash (no clean shutdown)
- **Root cause:** earlyoom killed helium at 23:18, niri-drm-healthcheck saw DRM errors, gpu-recovery tore down amdgpu driver → system died
- **Fix:** Replaced `gpu-recovery.service` call with `systemctl --user restart niri` in healthcheck script; disabled `gpu-recovery` service via `wantedBy = mkForce []`
- **Committed:** `236ca5ce`

### Flake Lock Update (Session 75)
- 14 inputs updated: BuildFlow, cmdguard, go-finding, go-output, gogenfilter, helium-browser-nix-flake, home-manager, homebrew-cask, niri-flake, niri-unstable, nixpkgs, NUR
- **Committed:** `480fca99`

### Nix Store GC (Session 75)
- 7,898 paths deleted, 7.5 GiB freed
- Automatic GC already configured (daily, `--delete-older-than 3d`)

### Boot Performance Stack (Sessions 71-74)
| Optimization | Before | After | Status |
|---|---|---|---|
| `/tmp` as tmpfs | 44.9s tmpfiles | 303ms | ✅ Deployed |
| Unbound preStart skip | ~4s | ~0s | ✅ Deployed |
| Hermes fast-path perms | ~18s | ~0s (fast-path) | ✅ Deployed |
| Service target restructuring | blocks multi-user | graphical.target | ✅ Deployed |
| ComfyUI module deletion | 112 lines | removed | ✅ Deployed |

### Boot time: 3m 54s (this boot)
- Firmware: 32s
- Loader: 4s
- Kernel: 2s
- **Initrd: 1m 44s** ← hardware (TPM + NVMe device timeout)
- **Userspace: 1m 31s** ← services starting sequentially

### Hermes Service Target Move (Session 73)
- Moved from `multi-user.target` → `graphical.target` — no longer blocks boot
- All Docker containers, signoz, homepage, dnsblockd also on `graphical.target`

### Documentation & TODO Updates
- `AGENTS.md` updated with expanded extraDependencyGroups documentation
- `TODO_LIST.md` fully refreshed with current state, sessions 73-76 work marked complete
- `nix.gc` auto-collection confirmed working (daily, 3-day threshold)

---

## B) PARTIALLY DONE 🔧

### Hermes Service
- **Fixed:** Discord adapter ✅, Anthropic ✅, firecrawl ✅, edge-tts ✅, fal ✅, exa ✅
- **Running:** Yes, PID 15006, started 23:23, consuming 180MB RSS
- **Known issue:** `origin` git remote not accessible from hermes sandbox — hermes tries to push to git but gets "fatal: 'origin' does not appear to be a git repository"
- **Known issue:** `sudo` blocked by systemd hardening (`NoNewPrivileges=yes`) — hermes cannot run systemctl/git operations requiring elevated access
- **Not yet tested:** Whether firecrawl/edge-tts/fal/exa tools actually work when invoked by hermes (only verified no ImportError at startup)

### Boot Performance
- Userspace improved from 2m+ → 1m 31s
- **But initrd takes 1m 44s** — dominated by TPM device timeout (`sys-devices-LNXSYSTM:00-LNXSYBUS:00-MSFT0101:00-tpm-tpm0.device` takes 1m 44s)
- Total boot 3m 54s — **not the expected 35s** from Session 74 status report (that estimate didn't account for initrd)

### TODO_LIST.md
- Updated for session 75 but may drift again quickly
- Several P2-P5 items from Session 73 status still unchecked

---

## C) NOT STARTED ⏳

### From TODO_LIST.md
- [ ] **Configure secondary LLM provider** for hermes (OpenRouter/OpenAI) as GLM-5.1 fallback
- [ ] **Hermes git remote access** — SSH deploy key for sandbox
- [ ] **Check SigNoz provision logs**: channel + rule creation, 4 new dashboards
- [ ] **Test Discord alert channel**: `POST /api/v1/channels/test`
- [ ] **Verify Gatus endpoints**: `status.home.lan` healthy
- [ ] **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log)
- [ ] **Consolidate voice-agents Caddy vHost** into caddy.nix pattern
- [ ] **nix-colors integration** — wire to Home Manager, migrate 17+ hardcoded colors (~6h)
- [ ] **Deploy Dozzle** — Docker container log tailing at `logs.home.lan`
- [ ] **Create `just status` command** for automated status report generation
- [ ] **Provision Pi 3** for DNS failover cluster
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix
- [ ] **Flake inputs audit** — 74 total inputs (lock file), some may be stale/unused
- [ ] **Convert go-auto-upgrade `path:` inputs to SSH URLs**
- [ ] **Create shared flake-parts template** (mkGoPackage, checks, devshells)
- [ ] **Add memory/swap alerting** to SigNoz/Gatus

---

## D) TOTALLY FUCKED UP 💀

### Memory Pressure — Ongoing
| Metric | Value | Status |
|---|---|---|
| **RAM used** | 46Gi / 62Gi (74%) | ⚠️ Heavy |
| **Swap used** | 5.8Gi / 13Gi (45%) | 🟡 Better than before |
| **Load avg** | 8.82 / 9.90 / 8.12 | 🟡 Moderate |
| **gopls instances** | 13 processes, ~6.6 GiB RSS | 🔴 Massive waste |
| **Disk** | 90% (53G free / 512G) | ⚠️ Needs attention |

**13 gopls instances** are the single biggest memory waste. Each consumes 300-830 MB RSS. This is caused by having many Go projects open simultaneously in editors. This directly contributed to the OOM crash that triggered the GPU recovery incident.

**deer-flow-frontend** Docker container consumes 1.4 GiB — unexpectedly large for a frontend container.

### Initrd Boot Delay — Unfixable?
The initrd takes **1m 44s** — almost entirely waiting for TPM device (`tpm0.device`) and serial port devices (`ttyS0-S3`). This is a hardware/firmware timeout that NixOS config cannot reduce. The actual NVMe device also takes 1m 44s because it waits behind the TPM.

### Disk at 90%
After GC freed 7.5 GiB, disk crept back up from 88% → 90%. 53 GiB free but with AI models, Docker images, and Nix store growing, this needs monitoring.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Critical
1. **gopls memory explosion** — 13 instances × ~500MB avg = 6.6 GiB wasted. Need to configure `gopls` memory limits or close unused editor sessions. This is the #1 cause of OOM pressure.
2. **Hermes sudo access** — `NoNewPrivileges=yes` in systemd hardening blocks hermes from running systemctl. Need to either relax hardening or provide an API-based mechanism.
3. **Hermes git deploy key** — `origin` remote unreachable from sandbox. Needs SSH key setup.
4. **Secondary LLM provider** — GLM-5.1 is SPOF for all hermes cron jobs. Fallback to OpenRouter or OpenAI needed.
5. **Disk growth monitoring** — 90% and climbing. Need automated alerting + regular GC.

### Architecture
6. **Initrd TPM timeout** — investigate if TPM can be disabled in BIOS or kernel params to eliminate 1m 44s initrd wait
7. **Docker container memory limits** — deer-flow-frontend using 1.4 GiB, openseo at 400 MiB/2 GiB limit. Audit all containers for appropriate limits.
8. **Hermes tool verification** — verify firecrawl/edge-tts/fal/exa actually work at runtime, not just import without error
9. **Service parallelism** — hermes takes 1m 17s to start, twenty 49s, manifest 48s. These are sequential on graphical.target. Investigate if some can start in parallel.

### Code Quality
10. **Flake inputs audit** — 74 inputs in lock file. Many may be stale (e.g., inputs for deleted services like ComfyUI).
11. **Status report automation** — should be a `just status` command, not manual
12. **`file-and-image-renamer`** — disabled due to Go 1.26.3 requirement. Needs upstream bump.

---

## F) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | P0 | **Configure gopls memory limits** or close unused editor sessions — 6.6 GiB waste causing OOM | 🔴 Critical | Low |
| 2 | P0 | **Verify hermes firecrawl/edge-tts/fal/exa tools work at runtime** — import != functional | High | Medium |
| 3 | P0 | **Configure secondary LLM provider** for hermes (OpenRouter/OpenAI fallback) | High | Medium |
| 4 | P1 | **Fix hermes git remote access** — SSH deploy key for sandbox | Medium | Medium |
| 5 | P1 | **Fix hermes sudo access** — relax NoNewPrivileges or provide alternative | Medium | Medium |
| 6 | P1 | **Investigate initrd TPM timeout** — can it be disabled in BIOS? 1m 44s wasted | High | Low |
| 7 | P1 | **Add memory/swap alerting** to SigNoz or Gatus | High | Medium |
| 8 | P1 | **Audit Docker container memory limits** — deer-flow-frontend at 1.4 GiB | Medium | Low |
| 9 | P1 | **Disk growth monitoring** — 90% and climbing, set up automated alert | Medium | Low |
| 10 | P2 | **Check SigNoz provision logs** — verify dashboards + rules created | Medium | Low |
| 11 | P2 | **Test Discord alert channel** | Medium | Low |
| 12 | P2 | **Verify Gatus endpoints** — status.home.lan healthy | Medium | Low |
| 13 | P2 | **Add SigNoz channel routing** (critical→Discord, warning→log) | Medium | Medium |
| 14 | P2 | **Consolidate voice-agents Caddy vHost** into caddy.nix pattern | Medium | Low |
| 15 | P2 | **Deploy Dozzle** at logs.home.lan for Docker log tailing | Medium | Low |
| 16 | P2 | **Provision Pi 3** for DNS failover cluster | High | High |
| 17 | P2 | **Wire Pi 3 as secondary DNS** | High | Medium |
| 18 | P3 | **Flake inputs audit** — 74 inputs, find stale ones | Low | Medium |
| 19 | P3 | **nix-colors integration** — migrate 17+ hardcoded colors | Low | High |
| 20 | P3 | **Create `just status` command** for automated reports | Low | Low |
| 21 | P3 | **Convert go-auto-upgrade `path:` inputs to SSH URLs** | Low | Low |
| 22 | P3 | **Create shared flake-parts template** (mkGoPackage, checks, devshells) | Medium | High |
| 23 | P3 | **`file-and-image-renamer`** — bump Go or find alternative | Low | Medium |
| 24 | P4 | **Service startup parallelism** — reduce 1m 31s userspace time | Medium | High |
| 25 | P4 | **Darwin config parity check** — ensure macOS config hasn't drifted | Low | Medium |

---

## G) TOP #1 QUESTION 🤔

**Can the TPM device timeout in initrd be disabled or reduced?**

The boot spends **1m 44s in initrd** — almost entirely waiting for `tpm0.device` and serial port devices (`ttyS0-S3`). This is the single largest component of boot time (45% of total). On a machine with full-disk encryption handled by LUKS (not TPM), the TPM device may not be needed at all.

Investigation needed:
1. Check if TPM is used for anything (SecureBoot, LUKS auto-unlock, measured boot): `systemd-cryptenroll --tpm2-device=list`
2. If unused, try `module_blacklist=tpm_tis,tpm_crb` in kernel params or disable TPM in BIOS
3. Serial ports (`ttyS0-S3`) can likely be disabled via BIOS or `module_blacklist=serial8250`
4. Potential savings: **~1m 40s** — bringing total boot to ~2m 10s

---

## System Vital Signs

| Metric | Value | Status |
|--------|-------|--------|
| **Root disk** | 90% (53G free / 512G) | ⚠️ Needs attention |
| **Memory** | 46Gi/62Gi (74%) | ⚠️ Heavy |
| **Swap** | 5.8Gi/13Gi (45%) | 🟡 Recovering |
| **Load avg** | 8.82 / 9.90 / 8.12 | 🟡 Moderate |
| **Uptime** | 26 min | ✅ Fresh boot |
| **gopls instances** | 13 processes, ~6.6 GiB | 🔴 Memory waste |
| **Build test** | `just test-fast` passes | ✅ |
| **.nix files** | 111 files, 14,833 lines | — |
| **Service modules** | 35 | — |
| **Flake inputs** | 74 (in lock file) | — |
| **Branch** | master, up to date with origin | ✅ |
| **Boot time** | 3m 54s (firmware 32s + initrd 1m44s + userspace 1m31s) | ⚠️ |

## Services Status

| Service | Status | Notes |
|---------|--------|-------|
| **Hermes** | 🟢 Running | 6 extras loaded, git origin unreachable, sudo blocked |
| **Caddy** | ✅ | Reverse proxy |
| **Forgejo** | ✅ | Git hosting |
| **Immich** | ✅ | Photo management |
| **Authelia** | ✅ | SSO/Auth |
| **Homepage** | ✅ | Dashboard |
| **SigNoz** | ✅ | Observability (ClickHouse 724MB) |
| **Twenty** | ✅ | CRM (server 427MB + worker 358MB) |
| **Voice Agents** | ✅ | Whisper-asr + Docker (68MB) |
| **Ollama** | ✅ | Local LLM |
| **ComfyUI** | ❌ Deleted | Module removed session 73 |
| **Photomap** | ❌ Disabled | — |
| **Minecraft** | ❌ Disabled | Server mode off |
| **TaskChampion** | ✅ | Task management |
| **Monitor365** | ✅ | Hardware monitoring |
| **DNS Blocker** | ✅ | Unbound-based (271MB) |
| **Dual WAN** | ✅ | Failover |
| **Gatus** | ✅ | Uptime monitoring |
| **Disk Monitor** | ✅ | NVMe health |
| **NVMe Health** | ✅ | SMART monitoring |
| **OpenSEO** | ✅ | Running (400MB/2GiB limit) |
| **Manifest** | ✅ | Running (110MB/1GiB limit) |
| **Deer Flow** | ✅ | Running (frontend 1.4GiB!) |
| **gpu-recovery** | ❌ Disabled | Replaced by niri restart (session 76) |
| **llama-server** | 🟡 User proc | Gemma 4 26B running, 978MB RSS |

## Boot Time Breakdown

```
firmware:    32.4s  (BIOS/UEFI)
loader:       3.9s  (systemd-boot)
kernel:       1.8s
initrd:     104.6s  ← TPM + NVMe device timeout
userspace:   91.5s  ← services (hermes 77s, twenty 49s, manifest 48s)
────────────────────
TOTAL:      234.1s  (3m 54s)
```

**Top userspace services:**
```
hermes.service        1m 17s  (Python startup + migration)
twenty.service           49s  (Docker compose)
manifest.service         48s  (Docker compose)
whisper-asr.service      39s  (Docker pull check)
openseo.service          37s  (Docker compose)
unbound.service          12s  (DNS resolver)
signoz.service            9s  (Go binary)
clickhouse.service        7s  (Database)
docker.service            5s  (Daemon)
```

## Commit History (May 21, sessions 75-76)

```
236ca5ce fix(niri): replace GPU driver unbind/rebind with simple niri restart
480fca99 feat(hermes): add firecrawl, edge-tts, fal, exa to extraDependencyGroups
3aec9687 docs(status): Session 75 FINAL — 16/16 repos versioned, building, automated
96ccf4db feat(versioning): bump all LarsArtmann packages + update overlays
2e33c967 docs(status): update Session 75 — 15/16 repos building
8ee7d57a feat(versioning): add just versions + auto-tag workflow + status report
26da7a88 docs(status): Session 74 — comprehensive status report
0192833b refactor(boot): mass-move user-facing services to graphical.target + delete ComfyUI
1b69709b docs(status): Session 73 — Hermes graphical.target fix
9d4bb569 docs(status): Session 73 — Hermes emergency fix
```
