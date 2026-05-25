# OOM Strategy Deep-Dive: Why Your PC Can't Manage Memory

**Date:** 2026-05-25
**System:** evo-x2 — AMD Strix Halo, 128 GB unified RAM, NixOS
**Scope:** Root-cause analysis of OOM unreliability + actionable multi-layer defense strategy

---

## The Short Answer

Your system has **three independent memory consumers** (CPU processes, GPU via GTT, ZRAM swap) that **no single tool can see all at once**. The kernel OOM killer is blind until it's too late. earlyoom sees CPU RAM but not GPU allocations. systemd-oomd sees cgroup pressure but not GPU either. nvtop double-counts GTT+VRAM. None of them communicate.

The fix is a **layered defense**: per-service `MemoryMax` cgroup limits (already mostly done) + earlyoom as global backstop + systemd-oomd for PSI-based pressure kills + correct thresholds for unified memory.

---

## 1. Why the Kernel OOM Killer Can't Save You

The Linux kernel OOM killer is a **last-resort mechanism**, not a memory manager. Here's why it fails on this system:

### 1a. It Only Fires After Memory Is EXHAUSTED

The kernel doesn't invoke the OOM killer until:
1. An allocation fails
2. Direct reclaim (freeing page cache) fails
3. Swapping fails (or no swap left)
4. All reclaim attempts exhausted

On a 128 GB system, this means **the system is already thrashing** when the killer activates. The OOM killer is the ambulance at the bottom of the cliff.

### 1b. 2–15 Second Latency

The kill process:
1. Scan all processes (O(n) — hundreds of processes on this system)
2. Calculate `oom_badness()` for each (RSS + swap + page tables + oom_score_adj)
3. Select highest-scoring process
4. Send SIGKILL
5. **OOM Reaper thread waits 2s, then reaps across 10 retries** — total 2–15s

During those seconds, the system is unresponsive. On a desktop with a compositor (niri), this means **frozen display, no input, user thinks it's crashed**.

### 1c. Heuristics Are Wrong for AI Workloads

The kernel picks the process with the highest `oom_score`:
- Ollama at 30 GB gets score ~234 (30/128 * 1000)
- A random Python script at 2 GB gets score ~15
- **But the Python script might be the one that triggered the allocation**

The kernel also defaults to `oom_kill_allocating_task=0` (you have this set), meaning it kills the **biggest hog**, not the process that caused the allocation. This is usually correct, but it means the kernel can kill the wrong process if the hog is legitimate (e.g., Ollama running an important inference).

### 1d. No Rate-of-Change Awareness

The kernel sees absolute levels, not velocity. Ollama loading a 30 GB model allocates ~10 GB/sec. The kernel's watermarks are checked per-allocation, but by the time the low watermark is hit, another 5 GB has been allocated. The OOM killer fires **after** the damage, not before.

---

## 2. Why earlyoom Struggles on Unified Memory

earlyoom is a **significant improvement** over the kernel OOM killer — it's faster (polls at up to 10 Hz vs kernel's per-allocation check) and more configurable. But it has fundamental limitations on this system:

### 2a. It Uses `/proc/meminfo` — Which Misses GPU Allocations

earlyoom reads `MemAvailable` from `/proc/meminfo`. On unified memory systems:

| Memory Consumer | Visible in MemAvailable? | earlyoom Aware? |
|----------------|--------------------------|-----------------|
| CPU process RSS | Yes | Yes |
| Page cache | Yes (reclaimable) | Yes |
| GPU allocations (amdgpu VRAM) | Partially | Partially |
| GPU allocations (GTT-mapped) | **No** | **No** |
| TTM page pool | Reclaimable (shrinker) | Indirectly |
| ZRAM compressed swap | As swap, not RAM | Yes |

**GTT (Graphics Translation Table)** allocations allow the GPU to map system RAM into GPU address space. When Ollama allocates 30 GB for a model via ROCm, that memory is:
- Physically consumed from the 128 GB pool
- **Not visible in `MemAvailable`** — GTT-mapped pages are kernel-internal
- earlyoom thinks the system has more free memory than it actually does

This means earlyoom's `freeMemThreshold = 10%` (~12.8 GB) is calculated against a **fictional** MemAvailable that doesn't account for GPU allocations.

### 2b. AND Logic With Swap Is Counterproductive

earlyoom requires **both** `MemAvailable < threshold` AND `SwapFree < threshold`. Your config:
- `freeMemThreshold = 10` — kill when <12.8 GB free
- `freeSwapThreshold = 10` — kill when <1.28 GB swap free (ZRAM is 12.8 GB)

With `vm.swappiness = 1`, the kernel barely uses swap. So swap stays at ~90% free, meaning **the swap condition is almost never met**, and earlyoom almost never triggers — even when RAM is critically low.

Wait — actually this is worse. earlyoom requires BOTH to be below threshold. If swap is mostly free (which it is with swappiness=1), then earlyoom **will never kill anything** even when RAM is at 2% free.

**UPDATE:** Re-reading earlyoom docs more carefully — the AND logic means it acts when **both** conditions are true. With swappiness=1, swap stays free, so the swap condition is met (free > threshold). This means earlyoom acts based primarily on the memory condition. Actually no — both must be BELOW threshold. If swap is 90% free, SwapFreePercent is 90, which is NOT below 10. So **earlyoom is effectively disabled** because swap never drops below 10%.

### 2c. Process Selection Is Regex-Based, Not Context-Aware

`--prefer` / `--avoid` are process name regexes. They can't distinguish:
- Hermes (critical AI agent) vs a random Python script
- Ollama doing legitimate inference vs Ollama loading a 3rd model it shouldn't
- Jan AI spawning new `llama-server` processes every 1-3 min (each ~1.2 GB)

---

## 3. The nvtop 176 GiB Mystery

nvtop shows **176 GiB** on a 128 GB system because it **adds VRAM + GTT**:

```
nvtop total = VRAM heap size + GTT heap size
           = ~48 GB VRAM + ~128 GB GTT = ~176 GiB
```

For **integrated GPUs** (APUs like Strix Halo), nvtop detects `AMDGPU_IDS_FLAGS_FUSION` set, and switches to showing `vram.total_heap_size + gtt.total_heap_size`. This is because APUs don't have dedicated VRAM — they use system RAM for both.

**This is not a bug** — it's showing the total GPU-addressable memory space. But it's misleading because VRAM and GTT overlap (they're both backed by the same 128 GB physical RAM). The "used" column double-counts memory that's mapped via both VRAM and GTT simultaneously.

**What's actually happening on your system:**
- `amdgpu.gttsize=114688` (112 GB) — max GTT address space
- `amdgpu.ttm.pages_limit=29360128` (~112 GB) — TTM page pool limit
- Physical VRAM region carved from system RAM by firmware: ~48 GB
- These overlap. nvtop adds them. Hence 176 GiB.

---

## 4. Your Current Defense Layers (And Their Gaps)

### Layer 1: Per-Service MemoryMax (cgroup limits) — **BEST DEFENSE, MOSTLY DONE**

This is your strongest protection. When a service hits its `MemoryMax`, the **kernel's cgroup OOM killer** fires immediately — no scan, no heuristics, no 15-second delay. It's per-cgroup, so it only kills the offending service.

**How it works:**
1. `MemoryHigh = "80%"` — kernel throttles the service (makes it slow, reclaim memory)
2. `MemoryMax = "32G"` — hard ceiling. Kernel kills the service if it exceeds this.

**Audit results:**

| Status | Count | Services |
|--------|-------|----------|
| Has MemoryMax | 33 | All hardened services |
| NO MemoryMax — long-running | 3 | **pocket-id**, **monitor365-agent**, **monitor365-server** |
| NO MemoryMax — oneshot/OK | 5 | signoz-provision, forgejo-generate-token, immich-db-backup, whisper-asr-pull, docker |

**Top memory consumers and their limits:**

| Service | MemoryMax | Purpose |
|---------|-----------|---------|
| ollama | 32 GB | LLM inference (ROCm) |
| hermes | 24 GB | AI agent (PyTorch + ROCm) |
| clickhouse | 4 GB | SigNoz metrics DB |
| immich-ml | 4 GB | Photo ML |
| minecraft | 4 GB | Game server |
| whisper-asr | 8 GB | Voice transcription |
| Everything else | 512 MB | Standard services |

**GAP: The combined MemoryMax of just ollama (32G) + hermes (24G) = 56 GB. That's 44% of total RAM. If both hit their limits simultaneously, systemd kills them both — but their combined steady-state usage can still crowd out the desktop.**

### Layer 2: earlyoom — **CURRENTLY EFFECTIVELY DISABLED**

Due to the AND-logic swap threshold issue (see §2b), earlyoom likely **never triggers** on this system. ZRAM swap stays mostly free (swappiness=1), so `SwapFreePercent` never drops below 10%.

### Layer 3: ZRAM — **12.8 GB Compressed Emergency Buffer**

- `memoryPercent = 10` → ~12.8 GB virtual swap device
- Compressed at ~2:1 ratio → effective ~25 GB emergency headroom
- `swappiness = 1` → kernel avoids using it until dire need
- **Problem:** If earlyoom never triggers (see above), this buffer fills silently and then the kernel OOM killer fires — the slow path

### Layer 4: watchdogd — **Last Resort: Hard Reboot**

- Reboots at 98% RAM usage
- 30-second timeout
- This is the nuclear option — it works but you lose everything

### Layer 5: systemd-oomd — **NOT CONFIGURED**

NixOS enables the daemon by default (`systemd.oomd.enable = true`) but **no slices are monitored** (`enableRootSlice`, `enableSystemSlice`, `enableUserSlices` are all `false`). It's running but doing nothing.

---

## 5. Recommended Multi-Layer Strategy

### Principle: Defense in Depth

```
Layer 5 (innermost): Per-service MemoryMax cgroup limits    → Kills specific service instantly
Layer 4:             systemd-oomd PSI monitoring             → Kills services under pressure, per-slice
Layer 3:             earlyoom global backstop                → Kills biggest process when system is low
Layer 2:             ZRAM compressed swap                    → Emergency buffer, buys time
Layer 1 (outermost): watchdogd hard reboot                   → Nuclear option, system unresponsive
```

### 5a. Fix earlyoom — Make It Actually Work

**Problem:** `freeSwapThreshold = 10` + `swappiness = 1` + ZRAM = swap never fills = earlyoom never triggers.

**Fix:** Set `freeSwapThreshold` high enough that the condition is met (swap is "below" this = swap has been used). Actually — re-reading earlyoom's logic: it triggers when **both** MemAvailable < threshold AND SwapFree < threshold. With swap mostly free, SwapFree > threshold, so the AND fails.

Two options:
- **Option A (recommended):** Ignore swap entirely. Set `freeSwapThreshold = 100` (swap is always "below" 100%, so the condition is always met, effectively making it RAM-only).
- **Option B:** Lower the memory threshold and accept that earlyoom only fires on RAM.

Also consider absolute thresholds instead of percentages:
- `freeMemThreshold` is percentage-based
- Can use `-M` flag for absolute KiB: e.g., kill when < 8 GB free (more predictable)

**Config change:**
```nix
earlyoom = {
  enable = true;
  freeMemThreshold = 5;        # Kill at 5% free (~6.4 GB) — was 10%
  freeSwapThreshold = 100;     # Ignore swap — was 10%, effectively disabled earlyoom
  enableNotifications = true;
  extraArgs = [
    "-M $((8 * 1024 * 1024))"  # Also set absolute: kill when < 8 GiB free
    "--avoid" "^(systemd|sshd|dbus-broker|systemd-logind|systemd-udevd|systemd-journald|niri|waybar|kitty|fish|pipewire|pipewire-pulse|wireplumber|swayidle|dunst)$"
    "--prefer" "^(gopls|ollama|llama-server|python3|python|node|java|chrome|chromium|helium|electron|vtsls|tsserver|rust-analyzer|generate_happy_girl|cargo|clang|go)$"
  ];
};
```

### 5b. Enable systemd-oomd for Slice-Level Protection

systemd-oomd monitors **Pressure Stall Information (PSI)** — a kernel-provided metric that measures how much time processes spend waiting for memory. Unlike earlyoom's absolute thresholds, PSI detects **memory starvation** even when there's technically free RAM (e.g., GPU ate most of it).

**Config:**
```nix
systemd.oomd = {
  enable = true;
  enableRootSlice = true;      # Monitor overall system memory pressure
  enableSystemSlice = true;    # Monitor system.slice (most services)
  enableUserSlices = true;     # Monitor user.slice (desktop, niri, etc.)
};
```

This adds per-slice PSI monitoring:
- If `system.slice` experiences >60% memory pressure for 20s → kill something in that slice
- If `user.slice` experiences >50% memory pressure for 20s → kill something in that slice
- PSI is **reactive to actual memory starvation**, not just free memory levels

**Key advantage over earlyoom:** PSI reflects reality even when GTT allocations hide from MemAvailable. If the GPU consumed 80 GB and processes are stalling on memory, PSI will spike regardless of what MemAvailable says.

### 5c. Add MemoryMax to Unguarded Services

Three long-running services have no memory limits:

```nix
# pocket-id — identity provider, should be small
systemd.services.pocket-id.serviceConfig =
  serviceDefaults {} // harden { MemoryMax = "512M"; };

# monitor365 — user services, add hardenUser
systemd.user.services.monitor365.serviceConfig =
  serviceDefaultsUser {} // hardenUser { MemoryMax = "256M"; };
systemd.user.services.monitor365-server.serviceConfig =
  serviceDefaultsUser {} // hardenUser { MemoryMax = "256M"; };
```

### 5d. Consider Reducing GPU Memory Overhead

Current config:
```
OLLAMA_GPU_OVERHEAD = 8589934592  # 8 GB reserved for compositor
PYTORCH_CUDA_ALLOC_CONF = "per_process_memory_fraction:0.45"
```

If Ollama's `MemoryMax = 32G` and GPU overhead is 8 GB, that's 40 GB for Ollama alone. With hermes at 24 GB, that's 64 GB — half the system — just for AI services.

**Consider:**
- Reducing `OLLAMA_GPU_OVERHEAD` to 4 GB (4 GB is generous for niri + waybar)
- Or reducing `MemoryMax` for ollama to 28 GB (still huge)

### 5e. Keep Existing Protections

These are already correct:
- `vm.overcommit_memory = 0` — heuristic overcommit (prevents wild allocation)
- `vm.min_free_kbytes = 2097152` — 2 GB reserved for kernel/GPU
- `vm.swappiness = 1` — minimal swap usage
- OOMScoreAdjust on critical services (-1000 for sshd, -500 for journald/dbus/logind/udevd)
- ZRAM at 10% — compressed emergency buffer
- watchdogd — hard reboot at 98% RAM

---

## 6. Why unified Memory Makes Everything Harder

On a traditional system with a discrete GPU:
- CPU RAM = 128 GB, GPU VRAM = 24 GB (separate pools)
- Memory pressure is unambiguous — either CPU is low or GPU is low
- earlyoom/MemAvailable accurately reflects CPU state

On Strix Halo with unified memory:
- CPU and GPU share the same 128 GB physical pool
- GPU allocations via GTT are **invisible** to `/proc/meminfo`
- TTM page pool pages are **reclaimable** but show as free in MemAvailable
- The kernel can evict TTM pages under pressure, but only if it knows to — and earlyoom doesn't trigger the eviction path

**The fundamental gap:** No userspace tool has a complete view of memory usage. The closest thing is PSI, which measures the *effect* of memory pressure (process stalling) rather than trying to measure the *cause* (how much memory is free).

---

## 7. Summary of Recommended Changes

| Change | File | Impact |
|--------|------|--------|
| Fix earlyoom swap threshold | `boot.nix` | earlyoom actually triggers now |
| Add `-M` absolute threshold | `boot.nix` | More predictable kill point |
| Enable systemd-oomd slices | `configuration.nix` | PSI-based pressure kills |
| Add MemoryMax to pocket-id | `pocket-id.nix` | Unbounded service → bounded |
| Add MemoryMax to monitor365 | `monitor365.nix` | Unbounded services → bounded |
| Reduce OLLAMA_GPU_OVERHEAD | `ai-stack.nix` | 8 GB → 4 GB compositor reserve |

None of these are breaking changes — they're additive safety layers. The `MemoryMax` cgroup limits (Layer 5) remain the primary defense, as they're instant and per-service.

---

## 8. The nvtop 176 GiB Explained (TL;DR)

```
Physical RAM:                        128 GiB
├─ Firmware reserved:                ~1 GiB
├─ Kernel + structures:              ~3 GiB
├─ vm.min_free_kbytes:               2 GiB
├─ VRAM region (firmware carveout):  ~48 GiB
└─ Available for CPU + GPU dynamic:  ~74 GiB

nvtop shows: VRAM (48 GiB) + GTT (128 GiB max) = 176 GiB
             ^^^^^^^^         ^^^^^^^^^^^^^^^
             same physical    addressable space limit,
             RAM backing      not pre-allocated
```

The GTT size is an **address space limit**, not a memory allocation. nvtop treats it as "total GPU memory" because on discrete GPUs, VRAM is a fixed pool. On APUs, this double-counts. The actual physical consumption is always ≤ 128 GiB.

To see real memory usage per process including GPU: `radeontop` or `/sys/class/drm/card*/device/mem_info_vram_used`.
