# Session 64: GMKtec BIOS Discovery — Power Ceiling Actionable Path

**Date:** 2026-05-11 10:57 CEST
**Uptime:** 14h46m | **Load:** 4.77, 9.45, 10.13 | **Kernel:** 7.0.1
**Root disk:** 90% (54G free) | **Data disk:** 67% (339G free) | **RAM:** 21G/62G used
**Git:** clean, 2 commits ahead of origin/master

---

## Executive Summary

Breakthrough on the power ceiling investigation: GMKtec's official download page reveals a **`251028b` image (2025-10-28)** — 11 days newer than our current BIOS **v1.11 (2025-10-17)**. This likely contains an updated BIOS with potential power/TDP improvements.

**Critical problem:** GMKtec does NOT provide standalone BIOS updates. The `251028b` download is an **85 GB full Windows disk image** that would wipe NixOS. We need to extract just the BIOS `.cap` file from it.

---

## a) FULLY DONE

### Session 63 Work (committed, not yet deployed)

All committed in previous session, awaiting `just switch`:

- **`boot.nix`**: `amd_pstate=guided` → `amd_pstate=performance` + `powerManagement.cpuFreqGovernor = "performance"`
- **`ai-stack.nix`**: Ollama `MAX_LOADED_MODELS=1`, `GPU_OVERHEAD=8GiB`, `OOMScoreAdjust=500`
- **`niri-config.nix`**: niri `OOMScoreAdjust` -900 → -1000
- **`gpu-recovery.sh`**: All fatal paths now auto-reboot instead of leaving system hung
- **`niri-drm-healthcheck.sh`**: Consecutive failure thresholding (3 checks) with state file
- **`AGENTS.md`**: 130W power ceiling documented in Known Issues

### GMKtec BIOS Discovery (this session)

- Found official GMKtec Drivers & Software page with EVO-X2 downloads
- Identified all available EVO-X2 software versions:

| Version | Date | Type | Notes |
|---------|------|------|-------|
| `251028b` | 2025-10-28 | Full Windows image (with LLM) | 85 GB, **newest** |
| `250623b` | 2025-06-23 | Full Windows image (no LLM) | Older |
| Ubuntu | 24.04.3 | Full Ubuntu image | Supports 96G VRAM allocation |

- **Our BIOS: v1.11 (2025-10-17) — 11 days OLDER than `251028b`**
- No standalone `.cap` BIOS file available from GMKtec
- EVO-X2 Ubuntu image also available (24.04.3) — may contain BIOS updates too

---

## b) PARTIALLY DONE

### BIOS Power Limit Investigation

- ✅ Confirmed `AmdSetup` EFI var exists (AMD CBS compiled into BIOS)
- ✅ Hex-dumped EFI variables, found structured data but no obvious PPT values
- ✅ Identified `251028b` as newer software package
- ❌ NOT extracted BIOS from the 85 GB image
- ❌ NOT rebooted into BIOS to check AMD CBS/AMD PBS menus
- ❌ NOT contacted GMKtec support for standalone BIOS file
- ❌ NOT tried Ctrl+F1/Ctrl+F2 hidden menu access in BIOS setup

---

## c) NOT STARTED

1. **Extract BIOS `.cap` from `251028b` image** — Need to download 85 GB image on another machine, mount/extract, find the AMI `.cap` file
2. **Flash newer BIOS** — Once extracted, flash via BIOS setup (F2 → AFUWFlash or built-in flash utility)
3. **Check BIOS AMD CBS menus** — Reboot into setup, navigate Advanced → AMD CBS → SMU Common Options
4. **Try hidden BIOS menu keys** — Ctrl+F1, Ctrl+F2, Win+F2 in Advanced tab
5. **Contact GMKtec support** — Request standalone BIOS + PPT control info
6. **Deploy session 63 changes** — `just switch` still needs to be run
7. **DNS failover cluster** — Pi 3 hardware not provisioned
8. **Root disk cleanup** — 90% usage, needs attention

---

## d) TOTALLY FUCKED UP

### Nothing new this session.

However, the overall situation with GMKtec is frustrating:
- **No standalone BIOS updates** — Only full 85 GB Windows images. This is hostile to anyone not running Windows.
- **No BIOS changelog** — No way to know if `251028b` even includes power limit changes
- **No documentation** — No BIOS manual, no AMD CBS menu documentation, no developer resources

---

## e) WHAT WE SHOULD IMPROVE

### Critical

1. **Root disk at 90%** — `just clean` + check `/var/lib/systemd/coredump/` + `nix-collect-garbage -d`
2. **Download `251028b` image** — On another machine with enough disk space, extract the BIOS `.cap`
3. **Reboot into BIOS NOW** — Check AMD CBS menus before any update. 5 minutes of work that could unlock PPT control

### Important

4. **Contact GMKtec support** — Ask for: (a) standalone BIOS file, (b) AMD CBS PPT access, (c) BIOS changelog
5. **Deploy pending changes** — `just switch` to apply session 63's amd_pstate + Ollama + GPU recovery changes
6. **Verify Ollama stability** after `MAX_LOADED_MODELS=1` is deployed

### Nice to Have

7. **Extract BIOS from Ubuntu image** — Smaller download than Windows, may contain same BIOS
8. **Write EFI variable analysis script** — Systematic AMI IFR parsing for future BIOS option discovery
9. **Monitor GMKtec forum/community** — Other EVO-X2 owners may have already extracted/modified BIOS

---

## f) Top #25 Things We Should Get Done Next

| # | Priority | Task | Effort |
|---|----------|------|--------|
| 1 | P0 | **Reboot into BIOS → check AMD CBS/AMD PBS menus for PPT/TDP controls** | 10min |
| 2 | P0 | **Try Ctrl+F1 / Ctrl+F2 in BIOS Advanced tab to reveal hidden AMD menus** | 2min |
| 3 | P0 | **Root disk cleanup** — `just clean`, coredumps, nix-collect-garbage | 15min |
| 4 | P0 | **Download `251028b` image on another machine** (85 GB) | 2hr+ |
| 5 | P1 | **Extract BIOS `.cap` file from `251028b` image** | 30min |
| 6 | P1 | **Flash newer BIOS** via BIOS setup if `.cap` extracted successfully | 15min |
| 7 | P1 | **Contact GMKtec support** for standalone BIOS + PPT access | 20min |
| 8 | P1 | **`just switch`** to deploy session 63 changes | 30min |
| 9 | P1 | **Verify Ollama stability** under load with MAX_LOADED_MODELS=1 | 30min |
| 10 | P1 | **Test GPU recovery** — simulate DRM zombie, verify auto-reboot flow | 20min |
| 11 | P2 | Move niri-drm-healthcheck state file from `/tmp` to `/var/lib` | 5min |
| 12 | P2 | **Check EVO-X2 Ubuntu image** for BIOS `.cap` (smaller download) | 1hr |
| 3 | P2 | Add power estimation to waybar (RAPL energy_uj delta) | 30min |
| 14 | P2 | Provision Pi 3 for DNS failover cluster | 2hr |
| 15 | P2 | Audit all 17 gatus health check endpoints | 15min |
| 16 | P2 | Verify SigNoz metrics ingestion from all exporters | 15min |
| 17 | P2 | Add disk monitoring alerts (90% root, 67% data) | 20min |
| 18 | P3 | Search GMKtec forum/community for EVO-X2 BIOS modding info | 30min |
| 19 | P3 | Write AMI IFR parser script for EFI variable analysis | 1hr |
| 20 | P3 | Test dual-WAN failover (mptcp-endpoint-manager) | 1hr |
| 21 | P3 | Check if `251028b` BIOS unlocks platform profiles for Linux | 10min |
| 22 | P3 | Review awww-daemon sandboxing completeness | 15min |
| 23 | P3 | Investigate AMD Curve Optimizer support on Strix Halo | 30min |
| 24 | P4 | Add waybar CPU package power estimate module | 30min |
| 25 | P4 | Test full system recovery: GPU hang → auto-reboot → session restore | 30min |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Does the `251028b` GMKtec EVO-X2 software image contain an updated BIOS with PPT/TDP controls, and can we extract just the BIOS `.cap` file without wiping NixOS?**

I know the image exists and is 85 GB. I know AMI BIOS images always contain a `.cap` file. But I cannot:
- Download the image (85 GB, DNS blocked on this machine)
- Verify the BIOS version inside it
- Know if GMKtec changed any power settings between v1.11 and whatever `251028b` includes
- Extract the `.cap` without someone running Windows or mounting the image

The user needs to download the image on another machine and extract the BIOS file. This is the single most impactful action to potentially raise the 130W ceiling.

---

## Uncommitted Changes

**None.** Working tree is clean. All session 63 changes are committed.

2 commits ahead of origin/master:
- `99495f22` feat(power): switch amd_pstate to performance, document 130W ceiling
- `0056a683` fix(gpu): harden recovery scripts, stabilize Ollama

## Deploy Status

| Change | Committed | Deployed | Tested |
|--------|-----------|----------|--------|
| amd_pstate=performance | ✅ | ❌ | ❌ |
| Performance governor | ✅ | ❌ | ❌ |
| Ollama MAX_LOADED_MODELS=1 | ✅ | ❌ | ❌ |
| Ollama GPU_OVERHEAD=8GiB | ✅ | ❌ | ❌ |
| Ollama OOMScoreAdjust=500 | ✅ | ❌ | ❌ |
| Niri OOMScoreAdjust=-1000 | ✅ | ❌ | ❌ |
| GPU recovery auto-reboot | ✅ | ❌ | ❌ |
| DRM healthcheck thresholding | ✅ | ❌ | ❌ |
| AGENTS.md 130W documentation | ✅ | ✅ (docs) | ✅ |
