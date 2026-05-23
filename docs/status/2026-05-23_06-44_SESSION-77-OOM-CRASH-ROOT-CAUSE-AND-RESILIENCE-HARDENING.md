# Session 77 — OOM Crash Root Cause Analysis + System Resilience Hardening

**Date:** 2026-05-23 06:44 CEST
**Boot:** 1h 4m ago (since 05:40)
**Trigger:** System OOM crash at ~05:39 CEST, hard reboot required

---

## Executive Summary

The system experienced a catastrophic OOM crash caused by **21 Node.js processes consuming 11.3 GB RAM** across Homepage/SigNoz/Twenty builds. earlyoom's `--prefer` list included `helium`, causing it to kill **helium's GPU processes** (not node) first. This corrupted the AMD DRM/KMS pipeline while niri was still running, producing a **black display that never recovered**. Both watchdogs (niri-drm-healthcheck and display-watchdog) had blind spots that prevented detection. A hard reboot was required.

**This session:** Root-caused the crash, fixed earlyoom targeting, rewrote both watchdogs, increased swap headroom.

---

## a) FULLY DONE ✅

### 1. OOM Crash Root Cause Analysis

Complete forensic timeline reconstructed from `journalctl -b -1`:

| Time | Event |
|------|-------|
| May 22 07:00 | Swap at 1.23% (164 MiB free of 13 GiB) |
| May 22 13:00 | Swap at 0.03% (4 MiB free) — running on fumes |
| May 23 02:35 | First earlyoom kill wave (helium renderers, ~30 MiB each) |
| May 23 05:11:52 | **Main crash:** mem avail 3132 MiB (9.6%), swap 0 MiB (0%) |
| 05:11:52-55 | earlyoom kills 22 helium processes (2.3 GB total) |
| 05:13:06 | earlyoom finally kills node processes (11.3 GB total) — too late |
| 05:13:29 | Memory hits 6.34% (1892 MiB) — SIGKILL territory |
| 05:13-05:39 | niri alive, display dead, both watchdogs blind. System unusable. |
| 05:39:11 | Last journal entry before hard reboot |

**Root cause math:**
- Helium (killed first, wrong): oom_score 1168 + prefer bonus 300 = **1468** (195 MiB)
- Node (killed 74s later): oom_score 975 + prefer bonus 300 = **1275** (1026 MiB)
- `helium` was in `--prefer` list → got +300 → died before node

### 2. earlyoom Config Fix — Remove helium from `--prefer`

**File:** `platforms/nixos/system/boot.nix:177`
- Removed `helium` from `--prefer` regex
- Now: node keeps +300 bonus (1275) > helium without bonus (1168) → **node dies first**
- node (11 GB) >> helium (2.3 GB) — correct victim ordering

### 3. display-watchdog.sh Rewrite — Detect dead display while niri runs

**File:** `scripts/display-watchdog.sh`

| Before | After |
|--------|-------|
| `pgrep -x niri && exit 0` — skips if niri alive | Checks DRM `enabled`/`dpms` regardless of niri state |
| Only handled "niri dead + display dead" | Handles BOTH scenarios: niri alive/dead + display dead |
| `systemctl --user restart niri` (fails from system context) | `systemctl --user -M "${PRIMARY_USER:-lars}@" restart niri` |

**Recovery ladder (new):**
1. niri alive + display dead → restart niri (re-acquire DRM master)
2. niri dead + display dead → restart display-manager (SDDM)
3. After 3 consecutive failures → GPU recovery (driver rebind)
4. GPU recovery fails → system reboot

### 4. niri-drm-healthcheck.sh Rewrite — Check actual DRM state

**File:** `scripts/niri-drm-healthcheck.sh`

| Before | After |
|--------|-------|
| Only grepped niri journal for "Permission denied\|DeviceMissing" | Checks `/sys/class/drm/card*/enabled` + `dpms` state |
| Missed GPU pipeline corruption entirely | Detects `enabled=disabled + dpms=Off` while niri runs |
| Single state counter (threshold 3) | Two independent state counters: display (threshold 2) + journal (threshold 3) |
| Buggy shared state variables | Fixed: separate `read_count`/`write_count` functions per state file |

**Display threshold is lower (2 vs 3)** because GPU corruption only gets worse with time — faster response needed.

### 5. ZRAM Swap Increase — 5% → 10%

**File:** `platforms/nixos/system/boot.nix:198`
- Before: 5% = ~6.4 GiB virtual device
- After: 10% = ~12.8 GiB virtual device
- Rationale: system ran for 16h at swap 0% before crash — 6.4 GiB was insufficient

### 6. niri-config.nix — Pass PRIMARY_USER env var

**File:** `modules/nixos/services/niri-config.nix:129`
- Added `Environment = "PRIMARY_USER=${config.users.primaryUser}"`
- Required by display-watchdog for `systemctl --user -M` from system service context

### 7. Homepage Memory Constraints

**Commit:** `87109b85 perf(homepage): add memory constraints to prevent unbounded Node.js growth`
- Added MemoryMax/Docker resource limits to Homepage container
- Prevents the 21-node-process 11GB scenario from recurring

---

## b) PARTIALLY DONE 🔶

### gopls Memory Pressure (13 instances, ~9.7 GiB total)

- gopls is now #1 in earlyoom `--prefer` list (correct)
- **But:** 13 gopls processes consuming 9.7 GiB is still unsustainable on a 62 GiB system
- **Missing:** per-gopls instance memory limits (e.g., `GOMEMLIMIT` env var or systemd scope)
- Current RSS breakdown: 1.6 GiB (largest) down to 275 MiB (smallest)

### service-health-check Recurring Failures

- Failing every ~15 minutes with exit-code
- Has been failing since at least session 76
- **Not investigated** — low priority compared to OOM crash, but needs diagnosis

---

## c) NOT STARTED ⬜

### From TODO_LIST.md (Session 75/76)

| Priority | Task | Status |
|----------|------|--------|
| P0 | Configure secondary LLM provider (OpenRouter/OpenAI) as GLM-5.1 fallback | ⬜ |
| P0 | Hermes git remote access (SSH deploy key) | ⬜ |
| P1 | Verify hermes tools work at runtime (no ImportError) | ⬜ |
| P1 | Check SigNoz provision logs, test Discord alert channel | ⬜ |
| P2 | Add per-threshold SigNoz channel routing | ⬜ |
| P2 | Consolidate voice-agents Caddy vHost into caddy.nix pattern | ⬜ |
| P3 | nix-colors integration (~6h) | ⬜ |
| P3 | Deploy Dozzle at `logs.home.lan` | ⬜ |
| P3 | Create `just status` command | ⬜ |
| P4 | Provision Pi 3 for DNS failover cluster | ⬜ |
| P5 | Flake inputs audit (47 inputs, some stale) | ⬜ |

### New from This Session

| Task | Status |
|------|--------|
| Add `GOMEMLIMIT` to gopls instances | ⬜ |
| Investigate service-health-check failures | ⬜ |
| Add memory/swap alerting to Gatus/SigNoz | ⬜ |
| Test display-watchdog + niri-drm-healthcheck changes with `just switch` | ⬜ |

---

## d) TOTALLY FUCKED UP 💀

### The OOM Crash (May 23, ~05:39 CEST)

**What happened:**
1. 21 Node.js processes accumulated 11.3 GB RAM across Homepage/SigNoz/Twenty Docker builds
2. Swap exhausted (0% free) for 16+ hours before crash
3. earlyoom killed helium GPU processes instead of node (wrong victim due to `--prefer` list)
4. Killing GPU processes corrupted AMD DRM/KMS state → black display
5. niri process survived but display never recovered
6. Both watchdogs had blind spots: display-watchdog skipped when niri alive; drm-healthcheck only checked journal logs
7. System was unusable for 26+ minutes before hard reboot

**What was broken:**
- earlyoom targeting: `helium` in `--prefer` → wrong process killed first ✅ FIXED
- display-watchdog: `pgrep -x niri && exit 0` → blind to dead display with alive niri ✅ FIXED
- niri-drm-healthcheck: only grepped journal → missed GPU pipeline corruption ✅ FIXED
- ZRAM swap: 6.4 GiB insufficient → doubled to 12.8 GiB ✅ FIXED
- Homepage node: no memory limits → added Docker constraints ✅ FIXED

### gopls Memory Hemorrhage (Ongoing)

- **13 instances consuming 9.7 GiB** — largest single memory consumer on the system
- Each gopls instance spawns for every Go project open in editor
- No `GOMEMLIMIT` or per-instance memory caps
- Now #1 in earlyoom `--prefer` (will be killed first under OOM) but does NOT solve the root cause

---

## e) WHAT WE SHOULD IMPROVE 📈

### Critical

1. **gopls instance memory limits** — Set `GOMEMLIMIT=1GiB` per gopls instance. 13 × 1 GiB = 13 GiB cap vs current 9.7 GiB uncontrolled. Prevents runaway.
2. **Memory/swap alerting** — Gatus/SigNoz should alert at 80% memory usage, not wait for earlyoom at 10%. We had 16 hours of swap exhaustion with no notification.
3. **Node.js build process controls** — Homepage/SigNoz/Twenty Docker builds spawn unlimited node processes. Need per-container MemoryMax and potentially pnpm/npm build parallelism limits.
4. **service-health-check failures** — Failing every 15 min since session 76. Needs diagnosis.

### Architecture

5. **Consolidate watchdog state management** — Three scripts (niri-drm-healthcheck, display-watchdog, gpu-recovery) each have their own state persistence pattern. Extract to shared `lib/watchdog-state.sh`.
6. **Test display recovery chain** — We've never actually tested that `systemctl --user -M lars@ restart niri` works from the display-watchdog system service context. Needs verification.
7. **Watchdog metrics** — niri-health-metrics only counts DRM journal errors. Should also track display dead/alive state and recovery attempts.

### Operational

8. **Boot time still 3m 54s** — initrd takes 1m44s (TPM timeout?). Serial8250 fix helped but not enough.
9. **Disk at 84% (85 GiB free)** — Down from 90% after GC but trending up. Need automated cleanup.
10. **Flake inputs audit** — 47 inputs, some stale. Needs periodic review.

---

## f) Top #25 Things We Should Get Done Next

| # | Priority | Task | Est. Time | Impact |
|---|----------|------|-----------|--------|
| 1 | **P0** | Deploy all changes with `just switch` and verify watchdogs work | 30 min | Prevents repeat crash |
| 2 | **P0** | Add `GOMEMLIMIT=1GiB` env var to gopls via Nix config | 15 min | Caps gopls at 13 GiB max |
| 3 | **P0** | Add memory/swap alerting to Gatus (alert at 80% mem, 50% swap) | 30 min | 16h early warning instead of 0 |
| 4 | **P0** | Test display-watchdog actually restarts niri from system context | 10 min | Verifies fix works |
| 5 | **P0** | Investigate service-health-check failures (every 15 min) | 20 min | Stops alert spam |
| 6 | **P1** | Configure secondary LLM provider for Hermes (OpenRouter/OpenAI) | 30 min | Hermes resilience |
| 7 | **P1** | Verify hermes Python deps work at runtime (no ImportError) | 15 min | Confirms session 75 work |
| 8 | **P1** | Add Docker MemoryMax limits to SigNoz/Twenty containers (not just Homepage) | 20 min | Prevents node process proliferation |
| 9 | **P1** | Hermes git remote access (SSH deploy key) | 30 min | Hermes can pull repos |
| 10 | **P1** | Consolidate watchdog state management into shared lib | 45 min | DRY, less bugs |
| 11 | **P1** | Add display-state metrics to niri-health-metrics | 20 min | Observability |
| 12 | **P2** | Check SigNoz provision logs, test Discord alert channel | 30 min | Alerting verification |
| 13 | **P2** | Add per-threshold SigNoz channel routing | 45 min | Better alert triage |
| 14 | **P2** | Consolidate voice-agents Caddy vHost into caddy.nix pattern | 30 min | Architecture cleanup |
| 15 | **P2** | Deploy Dozzle at `logs.home.lan` | 45 min | Real-time Docker log viewing |
| 16 | **P2** | Create `just status` command | 30 min | Operational convenience |
| 17 | **P2** | Investigate boot time: 1m44s initrd is still slow | 60 min | Faster reboots |
| 18 | **P2** | Automated disk cleanup (nix-store GC, Docker images) | 30 min | Prevents disk fill |
| 19 | **P3** | nix-colors integration | 6h | Theme consistency |
| 20 | **P3** | Flake inputs audit (47 inputs) | 2h | Dependency hygiene |
| 21 | **P3** | Provision Pi 3 for DNS failover cluster | 4h | DNS resilience |
| 22 | **P3** | Extract watchdog state lib to `lib/watchdog-state.sh` | 30 min | Code reuse |
| 23 | **P3** | Add earlyoom post-kill hook (`-N` flag) for logging victims | 30 min | OOM forensics |
| 24 | **P4** | OpenSEO domain tracking deployment | 1h | Business value |
| 25 | **P4** | Investigate `vm.swappiness=1` — maybe too aggressive for OOM scenarios | 30 min | Swap behavior tuning |

---

## g) My Top #1 Question

**Can you actually run `just switch` right now to deploy all these changes?**

The changes are committed and validated (`just test-fast` passes), but they're NOT deployed yet. Specifically:

1. **ZRAM 5% → 10%** requires reboot to take effect (can't resize zram online)
2. **display-watchdog + niri-drm-healthcheck** rewrites need `just switch` to activate
3. **earlyoom prefer list change** needs `just switch` to take effect

The system is currently running with the OLD watchdogs that have the blind spots. If another OOM event happens before deploy, we'd get the same black screen. However, deploying requires a `just switch` + reboot (for ZRAM), and you're actively using the machine (load average 13, 19 users, gopls heavy).

**Should I schedule the deploy, or do you want to continue working and deploy later?**

---

## System Metrics (Current)

| Metric | Value | Status |
|--------|-------|--------|
| Uptime | 1h 4m | 🟢 Fresh boot |
| RAM | 46/62 GiB (74%) | 🟡 Heavy |
| Swap | 7.6/13 GiB (58%) | 🟡 High |
| Disk | 412/512 GiB (84%) | 🟡 Trending up |
| Boot | ~4 min | 🟡 |
| Load | 13.02 | 🔴 High |
| gopls | 13 procs, ~9.7 GiB | 🔴 Top consumer |
| crush | 17 procs, ~1.8 GiB | 🟡 |
| llama-server | 1 proc, ~1 GiB | 🟢 |
| helium | 17 procs, ~1.7 GiB | 🟢 |
| niri | Running, display enabled | 🟢 |
| Display | connected, enabled, dpms=On | 🟢 |
| earlyoom | Active (old config, not deployed yet) | 🟡 |
| DRM watchdogs | Old blind-spot versions running | 🔴 |

---

## Commits This Session

| Commit | Description |
|--------|-------------|
| `87109b85` | perf(homepage): add memory constraints to prevent unbounded Node.js growth |
| `c67277f3` | perf(boot): increase ZRAM swap from 5% to 10% of RAM |
| `b6ce680f` | fix(display-watchdog): pass PRIMARY_USER env var to display-watchdog service |
| `08c267ce` | fix(display-watchdog): use systemd --machine mode for --user service restart |
| `9f6c418b` | chore(deps): update flake.lock + fix earlyoom prefer list + rewrite watchdogs |
| `f757cc0b` | perf(boot): add gopls to OOM killer prefer list as primary victim |

---

_Arte in Aeternum_
