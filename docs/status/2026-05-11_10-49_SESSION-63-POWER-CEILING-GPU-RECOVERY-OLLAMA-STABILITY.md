# Session 63: Power Ceiling Investigation, GPU Recovery Hardening, Ollama Stability

**Date:** 2026-05-11 10:49 CEST
**Uptime:** 14h39m | **Load:** 32.55, 23.88, 13.46 | **Kernel:** 7.0.1
**Root disk:** 90% (54G free) | **Data disk:** 68% (338G free) | **RAM:** 20G/62G used

---

## Executive Summary

Three distinct workstreams this session:

1. **Power ceiling deep-dive** — Investigated why the Ryzen AI Max+ 395 caps at ~130W. Conclusion: GMKtec firmware PPT limit, no OS override possible with current tools. Switched `amd_pstate=guided` → `amd_pstate=performance` to maximize utilization within the ceiling.

2. **GPU recovery script hardening** — `gpu-recovery.sh` and `niri-drm-healthcheck.sh` received significant resilience improvements: automatic reboot on unrecoverable GPU state, consecutive-failure thresholding, elimination of crash loops from repeated SIGKILL.

3. **Ollama stability tuning** — Added `OLLAMA_MAX_LOADED_MODELS=1` and `OLLAMA_GPU_OVERHEAD=8GiB` to prevent dual-runner GPU OOM, set `OOMScoreAdjust=500` so Ollama is preferentially killed before critical services.

---

## a) FULLY DONE

### Power Ceiling Investigation (boot.nix + AGENTS.md)

- **Deep hardware audit** of GMKtec NucBox EVO-X2: DMI, EFI vars, AMD P-State, RAPL, thermal zones, cooling devices, CPPC, platform profiles
- **Conclusion documented**: ~130W is firmware-enforced PPT. Every OS-level override path blocked:
  - `ryzenadj`: No `ryzen_smu` for Strix Halo, `/dev/mem` fails
  - RAPL: No constraint files exposed
  - Platform profile: GMKtec BIOS doesn't expose ACPI profiles
  - GPU overdrive: Disabled due to instability (documented)
- **`amd_pstate=guided` → `amd_pstate=performance`** in `boot.nix` — removes firmware frequency management, keeps cores at max under load
- **`powerManagement.cpuFreqGovernor = "performance"`** added to `boot.nix` — permanent performance governor
- **AGENTS.md updated** with 130W power ceiling in Known Issues table
- **Build verified**: `just test-fast` passes

### GPU Recovery Script Hardening (scripts/)

**`gpu-recovery.sh`** — Full rewrite of error handling:
- All fatal error paths now call `reboot_system()` instead of `exit 1`
- GPU rebind failure → automatic system reboot (no more hung state requiring manual intervention)
- DRM device not returning after 30s → automatic reboot
- Niri still has DRM errors after recovery → automatic reboot
- Post-niri-start sleep increased from 3s to 5s for more reliable DRM acquisition

**`niri-drm-healthcheck.sh`** — Consecutive failure tracking:
- State file `/tmp/niri-drm-healthcheck.state` tracks consecutive failure count
- Only triggers `gpu-recovery.service` after 3 consecutive checks with ≥10 DRM errors
- Prevents crash loop: old behavior SIGKILLed niri repeatedly when GPU was truly wedged
- Auto-resets state file when niri stops or DRM errors clear
- Falls back to `systemctl reboot` if `gpu-recovery.service` itself fails

### Ollama Stability (ai-stack.nix)

- `OLLAMA_MAX_LOADED_MODELS=1` — prevents loading two model runners simultaneously (root cause of the dual-runner OOM incident from session 59)
- `OLLAMA_GPU_OVERHEAD=8589934592` (8GiB) — reserves GPU memory for non-model use, prevents amdgpu exhaustion
- `OOMScoreAdjust=500` — makes Ollama a preferred OOM kill target (positive = more likely to be killed), protecting niri/waybar/pipewire which have `OOMScoreAdjust=-500`

### Niri OOM Protection (niri-config.nix)

- `OOMScoreAdjust` changed from `-900` to `-1000` — maximum protection for the Wayland compositor, matching sshd's protection level

---

## b) PARTIALLY DONE

### BIOS Power Limit Investigation

- Dumped and analyzed `AmdSetup` and `Setup` EFI variables (1526 bytes and 234 bytes respectively)
- Found structured data at offsets 0x70-0xBF in AmdSetup but no obvious PPT/TDP values in the expected ranges
- **NOT DONE**: User has not yet rebooted into BIOS to check AMD CBS/AMD PBS menus for:
  - `SMU Common Options → PPT Limit`
  - `SMU Common Options → STAPM Limit`
  - `cTDP` settings
  - Hidden AMD overclocking menus
- **NOT DONE**: Haven't checked GMKtec website for BIOS updates (DNS blocked on this machine). Current: **EVO-X2 v1.11 (2025-10-17)**

---

## c) NOT STARTED

1. **DNS failover cluster** — Pi 3 hardware not yet provisioned, module exists but unused
2. **BIOS update check** — Need to visit gmktec.com from another device
3. **ryzen_smu Strix Halo support** — Upstream effort, nothing we can do locally
4. **Gitea GitHub mirror** — Configured but mirror sync status unknown
5. **Full disk cleanup** — Root disk at 90% (54G free), needs Nix GC and coredump cleanup

---

## d) TOTALLY FUCKED UP

### Nothing catastrophically broken this session.

However, **root disk at 90%** is concerning. With `systemd.coredump.extraConfig MaxUse=2G` and `journald SystemMaxUse=4G` in place, growth should be bounded, but the margin is thin for a system that generates multi-GB core dumps from AI crashes.

---

## e) WHAT WE SHOULD IMPROVE

### Critical

1. **Root disk at 90%** — Schedule a cleanup: `just clean`, check `/var/lib/systemd/coredump/`, remove old generations with `nix-collect-garbage -d`
2. **BIOS power settings** — User MUST reboot into BIOS and check AMD CBS menus. This is the single highest-leverage action for increasing the 130W ceiling.
3. **GMKtec BIOS update check** — Visit gmktec.com on another device to see if v1.12+ exists with exposed power controls

### Important

4. **Ollama MAX_LOADED_MODELS=1** — This limits to one model at a time. If you need two models loaded simultaneously (e.g., embedding + chat), this will cause model swapping. Consider raising to 2 if GPU memory allows after the overhead reservation.
5. **GPU recovery auto-reboot** — The scripts now reboot on unrecoverable GPU state. This is correct behavior but means a GPU hang causes ~60s downtime (watchdog timeout + boot + session restore). Verify this is acceptable.
6. **niri-drm-healthcheck state file in /tmp** — Will be lost on reboot (intentional — fresh start after reboot). But if systemd cleans /tmp during runtime, could cause false negatives. Consider `/var/lib/niri-drm-healthcheck.state` instead.

### Nice to Have

7. **EFI variable analysis tooling** — We manually hex-dumped EFI vars. A proper AMI IFR parser would make BIOS option discovery systematic.
8. **Power monitoring dashboard** — No RAPL constraint files means no Grafana/waybar power readout. Could use `cat /sys/class/powercap/intel-rapl:0/energy_uj` delta for basic power estimation.

---

## f) Top #25 Things We Should Get Done Next

| # | Priority | Task | Effort |
|---|----------|------|--------|
| 1 | P0 | **Reboot into BIOS → check AMD CBS for PPT/TDP/cTDP controls** | 10min |
| 2 | P0 | **Check gmktec.com for EVO-X2 BIOS update** (use another device) | 5min |
| 3 | P0 | **Root disk cleanup** — `just clean`, check coredumps, nix-collect-garbage | 15min |
| 4 | P1 | Run `just switch` to apply amd_pstate=performance + Ollama stability changes | 30min |
| 5 | P1 | Verify Ollama stability under load with new MAX_LOADED_MODELS=1 setting | 30min |
| 6 | P1 | Test GPU recovery flow — simulate DRM zombie and verify auto-reboot | 20min |
| 7 | P1 | Move niri-drm-healthcheck state file from /tmp to /var/lib | 5min |
| 8 | P1 | Provison Pi 3 for DNS failover cluster | 2hr |
| 9 | P2 | Add power estimation to waybar (RAPL energy_uj delta) | 30min |
| 10 | P2 | Check Ollama model swapping behavior with MAX_LOADED_MODELS=1 | 20min |
| 11 | P2 | Audit all 17 gatus health check endpoints for accuracy | 15min |
| 12 | P2 | Verify SigNoz is ingesting metrics from all exporters | 15min |
| 13 | P2 | Check Gitea GitHub mirror sync status | 10min |
| 14 | P2 | Add disk monitoring alerts (current: 90% root, 68% data) | 20min |
| 15 | P2 | Review and clean up old status reports in docs/status/ | 10min |
| 16 | P3 | Investigate amd_pstate EPP (Energy Performance Preference) support | 20min |
| 17 | P3 | Write EFI variable analysis script for future BIOS option discovery | 1hr |
| 18 | P3 | Document GMKtec BIOS hidden menu access procedure | 30min |
| 19 | P3 | Add BTRFS snapshot health check to disk-monitor module | 30min |
| 20 | P3 | Test dual-WAN failover (mptcp-endpoint-manager) | 1hr |
| 21 | P3 | Review awww-daemon sandboxing completeness | 15min |
| 22 | P3 | Check if niri-session-manager handles GPU recovery reboots correctly | 15min |
| 23 | P4 | Investigate whether Strix Halo supports AMD Curve Optimizer | 30min |
| 24 | P4 | Add waybar module showing current CPU package power estimate | 30min |
| 25 | P4 | Test full system recovery: GPU hang → auto-reboot → session restore | 30min |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Does the GMKtec EVO-X2 BIOS (AMI v1.11) have AMD CBS (Common BIOS Settings) menus with PPT/TDP/cTDP controls, and are they accessible or hidden?**

I cannot answer this without physically entering the BIOS setup. The EFI variable analysis shows `AmdSetup` and `AMD_PBS_SETUP` variables exist (meaning AMD CBS/PBS modules are compiled into the BIOS), but I cannot determine whether GMKtec has hidden these menu entries from the setup UI. On many AMI BIOS implementations, pressing Ctrl+F1 or Ctrl+F2 in the Advanced tab reveals hidden AMD menus. This is the single most important unknown — if PPT is adjustable in BIOS, we can raise the 130W ceiling today.

---

## Uncommitted Changes (on disk, not yet committed)

| File | Change | Status |
|------|--------|--------|
| `platforms/nixos/system/boot.nix` | `amd_pstate=guided` → `amd_pstate=performance`, added `powerManagement.cpuFreqGovernor` | Ready to commit |
| `AGENTS.md` | Added 130W power ceiling to Known Issues | Ready to commit |
| `modules/nixos/services/ai-stack.nix` | Ollama stability: MAX_LOADED_MODELS, GPU_OVERHEAD, OOMScoreAdjust | Ready to commit |
| `modules/nixos/services/niri-config.nix` | niri OOMScoreAdjust -900 → -1000 | Ready to commit |
| `scripts/gpu-recovery.sh` | Auto-reboot on unrecoverable GPU state | Ready to commit |
| `scripts/niri-drm-healthcheck.sh` | Consecutive failure thresholding, state file tracking | Ready to commit |

## Recent Commits (this session and previous)

| Commit | Description |
|--------|-------------|
| `628fa63f` | Deep dive research doc: Strix Halo + Linux 7 + GPU memory protection |
| `3577431a` | Switch amd_pstate to performance, document 130W ceiling |
| `a9c8ecd5` | Session 62 status report |
| `554010b0` | Normalize arithmetic expression spacing |
| `a5322e87` | Session 61 status report |
