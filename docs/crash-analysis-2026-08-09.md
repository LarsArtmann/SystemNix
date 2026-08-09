# Crash Analysis: 2026-08-09 03:05 + 05:47 CEST — PMA Page-Cache Death-Loop + WDT Reset

**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395 "Strix Halo", 128 GB unified RAM)
**Date:** 2026-08-09
**Crash 1:** Boot -2 ended at 03:05:03 CEST (uptime ~16h)
**Crash 2:** Boot -1 ended at 05:47:29 CEST (uptime ~2h40m)
**Current boot:** 0, started 05:49:27 CEST

---

## TL;DR

The `projects-management-automation` (PMA) daemon entered a commit-failure death-loop that consumed **91% CPU** and pinned its cgroup at the **16 GB MemoryMax ceiling** with **27,312 memory boundary hits**. PMA reads 260+ git repos during discovery, charging ~16 GB of page cache against its cgroup. When the cgroup hits MemoryMax, the kernel reclaims page cache (instead of killing — `oom_kill=0`), PMA immediately re-reads the repos, hits the max again, and thrashes indefinitely. This thrashing generates sustained memory pressure across the entire system (PSI at 95% for minutes), which eventually freezes the kernel, triggering the **sp5100-tco hardware watchdog timer** reset.

This is the **third distinct crash root cause** on evo-x2 (previous: 2026-06-15 and 2026-06-26, both BTRFS metadata exhaustion). This crash is unrelated to BTRFS — it is a **service-level memory thrashing** problem.

---

## Evidence Chain

### 1. Hardware Watchdog Confirmed Both Resets

```
# Current boot (boot 0) kernel log:
x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired
```

Both crashes were hard system freezes (no OOM kill, no kernel panic logged, journal cuts off abruptly). The sp5100-tco watchdog fired after the kernel froze.

### 2. Memory Pressure at 95% for Minutes Before Each Crash

Monitor365 logged sustained 95% memory pressure continuously before both crashes:

```
# Boot -2 (crash 1), 02:55–03:05 — every ~30 seconds:
WARN  Buffer near capacity — N events dropped since last summary to prevent OOM, pressure_pct: "95"

# Boot -1 (crash 2), 05:47 — same pattern:
WARN  Buffer near capacity — 143 events dropped since last summary to prevent OOM, pressure_pct: "95"
```

Gatus also fired a Discord alert at 05:47:23: `Memory Pressure` endpoint `success=false`.

### 3. PMA Was the Dominant Memory + CPU Consumer

**Current boot (post-recovery), still in death-loop:**

```
$ ps aux --sort=-%mem | head -3
USER   PID   %CPU  %MEM   RSS      COMMAND
lars   1466  91.2  7.6   7551068  projects-management-automation service start

$ systemd-cgtop -m -n 1 --batch
system.slice/projects-management-automation.service   15.9G   ← at the 16G ceiling
```

**CPU:** 91.2% sustained — a death-loop of commit failures and retries.

**Memory cgroup events (the smoking gun):**

```
$ cat /sys/fs/cgroup/system.slice/projects-management-automation.service/memory.events
low 0
high 0
max 27312       ← 27,312 boundary hits at MemoryMax
oom 0           ← never OOM-killed
oom_kill 0      ← never killed — page cache is "reclaimable"
```

### 4. The Commit Failure Loop

PMA logs show continuous commit failures with immediate retries — thousands per hour:

```
# Boot -2: 4,089 PMA log entries in the hour before crash 1
# Boot -1: 3,242 PMA log entries in the hour before crash 2

# Typical failure patterns:
ERRO commit failed component=service project=/home/lars/projects/SystemNix
  error=Oops: commit failed: stage all in /home/lars/projects/SystemNix: get status: EOF

ERRO commit failed component=service project=/home/lars/projects/nsfw-classifier
  error=Oops: commit not successful: cannot create empty commit: clean working tree
```

The `get status: EOF` error is caused by page-cache eviction under memory pressure — go-git file operations fail when the kernel reclaims pages mid-read.

---

## Root Cause Analysis

### The Death-Loop Mechanism

```
┌─────────────────────────────────────────────────────────┐
│  PMA Discovery: reads 260+ git repos                    │
│  → ~16 GB of file page cache charged to cgroup          │
│  → cgroup hits MemoryMax (16G)                          │
│                                                         │
│  Kernel response: reclaim page cache (not kill)         │
│  → PMA re-reads evicted pages for next operation        │
│  → cgroup hits MemoryMax again                          │
│  → Repeat forever (27,312+ iterations logged)           │
│                                                         │
│  Meanwhile: commit failures trigger immediate retries   │
│  → LLM API calls (MiniMax) on every retry              │
│  → 91% CPU sustained                                   │
│  → I/O pressure compounds memory pressure               │
│                                                         │
│  System-wide effect:                                    │
│  → Memory PSI hits 95%                                  │
│  → Other services stall (Monitor365 drops events)       │
│  → Kernel thrashes on global reclaim                    │
│  → Complete freeze → WDT reset                          │
└─────────────────────────────────────────────────────────┘
```

### Why systemd-oomd Didn't Save It

PMA's 16 GB is almost entirely **page cache** (file-backed, reclaimable memory), not anonymous memory. The cgroup v2 OOM killer distinguishes between:

- **Anonymous memory** (heap, stacks) → OOM-killed when MemoryMax exceeded
- **Page cache** (file-backed) → reclaimed (pages evicted from cache) rather than killing

Since PMA's memory is page cache, the kernel chose reclaim over kill every time (`oom_kill=0`). But reclaim + PMA's immediate re-read creates a thrashing loop that's **worse than a kill** — it burns CPU and I/O indefinitely instead of cleanly restarting the process.

### Why Two Crashes in ~3 Hours

After crash 1, the system rebooted (boot -1 at 03:08). PMA auto-started, re-entered the death-loop within minutes, and crashed the system again at 05:47 — only ~2.5 hours of uptime. The second crash had the same root cause with identical symptoms.

### Current State: Still Looping

As of boot 0 (06:00 CEST), PMA is **actively in the death-loop** at 91% CPU and 15.9G/16G memory. **It will crash the system again** unless stopped or mitigated.

---

## Contributing Factors

| Factor | Impact | Detail |
|--------|--------|--------|
| **MemoryMax too high (16G)** | Prevents OOM kill | 16G allows page cache to fill without triggering a kill. The process RSS is only ~7.5 GB; the rest is page cache. |
| **No MemoryHigh set** | No throttling | Without `MemoryHigh` < `MemoryMax`, the kernel doesn't throttle allocations before hitting the hard limit. |
| **PMA has no commit backoff** | Immediate retry on failure | Commit failures (`empty commit`, `EOF`, `clean working tree`) are retried immediately — no exponential backoff. |
| **systemd-oomd not killing page-cache thrashers** | Design limitation | cgroup v2 OOM kill prefers reclaim over kill for file-backed memory. |
| **Total system memory budget** | Compounding pressure | ClickHouse (2.1G), Monitor365 (1.6G), Docker/Twenty (2G+), nix-daemon (5.8G) + PMA (16G) = 28G+ system slice alone. With page cache (46G), the 94G usable RAM is insufficient under PMA thrashing. |
| **`PMA_COMMITTER_WORKERS=4`** | Still too many | Reduced from default 8, but 4 concurrent git+LLM workers still generate enough I/O to compound the thrashing. |

---

## Comparison to Previous Crashes

| Crash | Date | Root Cause | Trigger | Mechanism |
|-------|------|------------|---------|-----------|
| #1 | 2026-06-15 | BTRFS metadata exhaustion | Manual `btrfs balance` + `nix-collect-garbage` | Metadata ENOSPC → I/O park → WDT |
| #2 | 2026-06-26 | BTRFS metadata exhaustion | Automated `nix-gc` timer | Same: metadata ENOSPC → WDT |
| **#3a** | **2026-08-09 03:05** | **PMA page-cache death-loop** | **PMA commit failure + no backoff** | **Memory thrash → PSI 95% → freeze → WDT** |
| **#3b** | **2026-08-09 05:47** | **PMA page-cache death-loop** | **Auto-restart after crash 1** | **Same: PMA re-entered loop → WDT** |

All three share the same final pathway: kernel freeze → sp5100-tco WDT reset. But the root causes are completely different — this crash is **not** a BTRFS problem.

---

## Immediate Mitigation

### Option A: Stop PMA (immediate stabilization)

```bash
sudo systemctl stop projects-management-automation.service
sudo systemctl disable projects-management-automation.service  # prevent auto-restart on reboot
```

This stops the death-loop immediately and stabilizes the system. PMA's auto-commits will pause.

### Option B: Lower MemoryMax + Set MemoryHigh (cgroup kill instead of thrash)

Reduce MemoryMax so the cgroup OOM killer fires quickly (killing PMA and letting systemd restart it cleanly), and set MemoryHigh to throttle before the hard limit:

```nix
# modules/nixos/services/projects-management-automation.nix
systemd.services.projects-management-automation.serviceConfig = {
  Type = lib.mkForce "exec";
  WatchdogSec = lib.mkForce "0";
  MemoryMax = lib.mkForce "8G";       # was 16G — too high for page-cache thrashing
  MemoryHigh = lib.mkForce "6G";      # throttle at 6G before hitting the wall
};
```

With MemoryMax=8G, the cgroup will hit max much sooner, and with less page cache to reclaim, the kernel is more likely to OOM-kill PMA (clean restart) rather than thrash.

### Option C: Fix the upstream bug (long-term)

The real fix is in the PMA daemon (`/home/lars/projects/projects-management-automation`):
1. **Add exponential backoff** on commit failures — don't retry immediately
2. **Don't retry on "empty commit" / "clean working tree"** — these are not recoverable errors
3. **Limit page cache growth** — close git repos after discovery, don't keep them mapped

---

## Prevention Recommendations

1. **Gatus alert on PMA CPU > 50% sustained** — the 91% death-loop should alert before it crashes the system
2. **Gatus alert on PMA memory.events `max` > 1000/min** — cgroup boundary thrashing is the early warning signal
3. **Reduce PMA MemoryMax to 8G + add MemoryHigh=6G** — force clean OOM-kill-restart instead of infinite thrash
4. **Fix PMA upstream commit backoff** — the death-loop is the root cause; memory limits are a band-aid
5. **Consider `MemorySwapMax=0`** — prevent PMA page cache from pushing other processes into swap
6. **Evaluate whether PMA needs to read all 260 repos on every cycle** — incremental discovery would dramatically reduce page cache pressure
