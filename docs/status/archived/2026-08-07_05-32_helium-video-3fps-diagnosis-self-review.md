# Helium Video 3 FPS Diagnosis — Self-Review

**Date:** 2026-08-07 05:32
**Trigger:** User reported Helium browser streaming video at ~3 FPS
**Status:** TWO root causes identified. Anti-throttling flags fix (DONE). Disk I/O saturation from dev builds (NOT FIXED).

---

## THE REAL ROOT CAUSE: Disk I/O Saturation

### The Smoking Gun

After writing the initial report, I checked I/O pressure and found **catastrophic disk contention**:

| Metric                         | Value               | Severity                                      |
| ------------------------------ | ------------------- | --------------------------------------------- |
| `/proc/pressure/io` some avg10 | **98.98%**          | CRITICAL — nearly all tasks stalled on I/O    |
| `/proc/pressure/io` full avg10 | **86.32%**          | CRITICAL — ALL tasks stalled 86% of the time  |
| `%iowait`                      | **88-89%**          | CPU spending almost all time waiting for disk |
| NVMe utilization               | **80%**             | Saturated                                     |
| NVMe read throughput           | **244 MB/s**        | Massive                                       |
| NVMe write throughput          | **102 MB/s**        | Massive                                       |
| Write latency (w_await)        | **10-30ms**         | Elevated for QLC NAND (normal <5ms)           |
| Swap used                      | **13.6 GB / 16 GB** | High — zram under pressure                    |

### What's Causing It

**`cargo-nextest run -p monitor365-server`** — a Rust test build is running RIGHT NOW, with:

- Multiple `rustc` processes at 100-254% CPU each
- Linker (`mold`) linking hundreds of dependency rlibs simultaneously
- `sccache` caching compiled artifacts
- All reading from and writing to the same BTRFS filesystem on QLC NAND

Additional cumulative I/O offenders:

- `projects-manage` (PMA daemon): 15.6 GB read
- `aw-server` (ActivityWatch): 12.3 GB read
- Multiple `crush` instances: 8867 MB, 3915 MB, 3197 MB, 2431 MB+ each
- Multiple `fish` shells: 9629 MB, 4185 MB, 1131 MB each

### Why This Causes 3 FPS Video

The NVMe is saturated. Even with hardware video decode working perfectly, the video player needs to:

1. **Read video data from disk** (cached pages, browser cache, Widevine CDM files)
2. **Write decoded frames to GPU memory** (via DMA-BUF)
3. **Buffer ahead** for smooth playback

When I/O pressure is at 99%, the video player's I/O requests get queued behind hundreds of rustc/mold/sccache I/O operations. The buffer starves. The frame rate drops. On QLC NAND, the write amplification compounds this — every `rustc` write causes BTRFS CoW churn that floods the I/O queue.

**This is the same QLC NAND BTRFS CoW churn pattern documented in AGENTS.md** — the one that caused 58 WDT resets. The daily `fstrim` + `commit=300` mitigated the crash mode, but the fundamental I/O contention problem remains when heavy builds run concurrently with media playback.

### The Fix Direction (NOT YET IMPLEMENTED)

1. **cgroup I/O throttling for development processes** — limit `cargo`, `rustc`, `go`, `nix` builds to e.g. 50% of NVMe bandwidth, leaving headroom for media
2. **`ionice` for builds** — set development builds to `ionice -c 3` (idle class) so media I/O preempts them
3. **Separate build cache filesystem** — the Rust `target/` dirs already live on ext4 (`/rust-cache`), but `sccache` and nix store reads still hit BTRFS on the main NVMe
4. **Media playback I/O boost** — give Helium's cgroup elevated I/O priority via `IOWeight` in systemd

---

## What I Did

### Investigation Steps (Good)

1. Read the full Helium wrapper config (`platforms/common/packages/base.nix`)
2. Verified VA-API works at the system level:
   - Mesa 26.1.6, radeonsi driver, AMD Radeon 8060S (Strix Halo)
   - Full decode support: H264, HEVC, HEVC10, VP9, AV1, JPEG
   - VA-API driver loads successfully (`va_openDriver() returns 0`)
3. Checked GPU state: 0% busy, 7% VRAM (2.6/34 GB) — not under pressure
4. Confirmed Helium version: **0.15.2.1 (Chromium 151.0.7922.75)** — NOT Chromium 150 as AGENTS.md claims
5. Researched Chromium anti-throttling flags via Chromium source code analysis
6. Verified `nix flake check --no-build` passes

### Fix Applied (Valid but WRONG LAYER)

Added 4 anti-throttling flags to `platforms/common/packages/base.nix:78-81`:

```
--disable-background-timer-throttling
--disable-backgrounding-occluded-windows
--disable-renderer-backgrounding
--disable-background-media-suspend
```

These flags ARE beneficial for background tab video playback. They are NOT the root cause of 3 FPS on a visible window.

---

## What I Forgot (Self-Critique)

### 1. FIRST DIAGNOSIS WAS WRONG (Anti-Throttling Flags)

I diagnosed "renderer backgrounding / occlusion throttling" as the cause of 3 FPS video. The window is visible — those flags are nice-to-have, NOT the root cause.

### 2. REAL ROOT CAUSE FOUND LATE: Disk I/O Saturation

After writing the initial report, the user prompted me to investigate disk I/O. The system is at **99% I/O pressure** due to a concurrent Rust build. This starves video buffering. This is the ACTUAL primary root cause.

**I should have checked `/proc/pressure/io` as the FIRST diagnostic step.** It takes 1 command and instantly reveals if the system is I/O-bound.

### 3. Never Verified VA-API Is Actually Used BY Chromium

System-level VA-API working ≠ Chromium using it. I never checked `chrome://gpu` or the GPU process internals. Still unverified.

---

## Status Breakdown

### a) FULLY DONE

| Item                         | Details                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------- |
| Anti-throttling flags added  | 4 flags added to `base.nix`, committed as `9f72a422`, `nix flake check` passes                    |
| System-level VA-API verified | Mesa 26.1.6, radeonsi, full codec support confirmed                                               |
| GPU pressure ruled out       | GPU at 0% busy, 7% VRAM at time of check                                                          |
| AGENTS.md gotcha added       | "Helium video throttling (3 FPS)" entry at line 375                                               |
| Research documented          | Chromium source-level analysis of throttling mechanisms                                           |
| I/O pressure diagnosed       | `/proc/pressure/io` at 99% — root cause identified                                                |
| I/O offenders identified     | `cargo-nextest` / `rustc` / `mold` saturating NVMe; PMA, aw-server, crush as cumulative offenders |

### b) PARTIALLY DONE

| Item                 | What's done                                                                                                       | What's missing                                                                      |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Root cause diagnosis | TWO causes found: (1) missing anti-throttling flags [fixed in config], (2) I/O saturation from builds [not fixed] | Haven't implemented I/O throttling for builds; haven't deployed anti-throttling fix |
| Helium flag audit    | Found and added anti-throttling flags                                                                             | Did NOT verify VA-API is actually used by Chromium at runtime                       |
| Documentation        | Added gotcha entry                                                                                                | AGENTS.md version still says "Chromium 150" (actual: 151)                           |

### c) NOT STARTED

| Item                                                                                 |
| ------------------------------------------------------------------------------------ |
| Deploy the anti-throttling fix (`nix run .#deploy`)                                  |
| Implement cgroup I/O throttling for dev builds (`cargo`, `rustc`, `go`, `nix`)       |
| Give Helium elevated I/O priority via systemd `IOWeight`                             |
| Verify VA-API is actually used by Chromium (need `chrome://gpu` or GPU log analysis) |
| Check if video decode falls back to software under CPU contention                    |
| Investigate TV-specific rendering path (DP-2, 4K, refresh rate, HDR)                 |
| Consider whether `--enable-gpu-rasterization` should be re-evaluated                 |
| Check if `--use-gl=egl` or `--use-angle=gl` is needed for VA-API on Wayland          |

### d) TOTALLY FUCKED UP

| Item                                               | Why                                                                                                                                                                     |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Initial root cause was wrong**                   | Diagnosed throttling flags when the real cause was disk I/O saturation. Should have checked `/proc/pressure/io` FIRST.                                                  |
| **Never deployed or tested**                       | The fix is committed but NOT deployed. The user is still at 3 FPS.                                                                                                      |
| **Didn't check the obvious system-level resource** | I/O pressure is the #1 cause of media stuttering on this QLC NAND machine. I have 58 WDT resets documented from the same I/O pattern. Should have been the first check. |

### e) WHAT WE SHOULD IMPROVE

1. **Check `/proc/pressure/{io,mem,cpu}` as the FIRST diagnostic step** for any performance complaint. One command, instant signal.
2. **Implement cgroup I/O throttling for development builds.** This machine runs heavy Rust/Go/Nix builds concurrently with media consumption. Without I/O isolation, they will ALWAYS conflict on this QLC NAND.
3. **Give Helium (and any media app) elevated I/O priority.** Systemd `IOWeight=1000` or equivalent for the Helium cgroup.
4. **Consider `ionice -c 3` wrappers for `cargo`, `go test`, `nix build`.** Idle I/O class means media I/O always preempts build I/O.
5. **The AGENTS.md already documents this exact I/O pattern** (58 WDT resets from QLC CoW churn). The daily fstrim + commit=300 prevented crashes but did NOT solve the I/O contention problem for interactive use.

### f) NEXT 50 THINGS TO DO

#### I/O Contention Fix (P0 — Root Cause #2)

1. **Implement systemd cgroup I/O throttling** for dev build processes — limit `cargo`/`rustc`/`go`/`nix` to e.g. 50% of NVMe I/O bandwidth
2. **Give Helium `IOWeight=1000`** in its systemd user service — media playback gets highest I/O priority
3. **Create `ionice` wrapper functions** in `lib/default.nix` for dev commands (`cargo`, `go test`, `nix build`, etc.) — set them to idle or best-effort low priority
   ~~4. **Add I/O pressure monitoring** to `system-health` textfile collector — record `/proc/pressure/io` values as Prometheus metrics~~ done — PSI I/O stall monitoring in system-health.nix (CHANGELOG)
   ~~5. **Add Gatus alert** when I/O pressure avg10 > 80% for >5 min — early warning before user notices stuttering~~ done — Gatus "I/O Stall Rate" alert (CHANGELOG)
4. **Consider a "media mode" systemd target** that throttles background services when media is playing
5. **Move `sccache` cache to `/rust-cache` (ext4)** — it currently hits BTRFS for every cache lookup
6. **Check if `CARGO_TARGET_DIR` can be moved to a tmpfs or ext4** for the monitor365 build
7. **Profile the exact I/O pattern** — is it reads (rlib linking) or writes (object files) that saturate?
8. **Consider `nvme ionice` or `blkio` cgroup limits** at the kernel level

#### Deploy and Verify (P0)

~~11. **Deploy the anti-throttling fix** (`nix run .#deploy`) — it's committed but not running~~ done — flags deployed in base.nix
12. **Tell user to check `chrome://gpu`** — verify "Video Decode" is "Hardware accelerated"
13. **Tell user to check `chrome://media-internals`** while playing video — verify `video_decoder` value
14. **Test video playback during a build** after deploying I/O throttling — measure FPS improvement

#### VA-API Verification (P1)

15. **Check GPU process log** at `~/.config/net.imput.helium/gpucache/` for VA-API errors
16. **Verify `--ignore-gpu-blocklist` is working** — check `chrome://gpu` "Problems" section
17. **Check if `LIBVA_DRIVER_NAME=radeonsi` needs to be in Helium's environment**
18. **Test VA-API decode with `mpv --hwdec=vaapi`** to confirm GPU decode for same content
19. **Verify Chromium 151 hasn't changed VA-API flag names again**
20. **Check `chrome://device-log`** for GPU sandbox or VA-API init failures

#### GPU Rasterization (P1)

21. **Re-evaluate `--enable-gpu-rasterization`** — disabled for GPUActive pressure, but video compositing may benefit
22. **Benchmark video WITH and WITHOUT GPU rasterization** — measure FPS, CPU, GPUActive
23. **Consider `--enable-features=DefaultEnableGpuRasterization`** as a targeted flag

#### Multi-Monitor (P1)

24. **Check TV refresh rate** — `cat /sys/class/drm/card1-DP-2/modes`
25. **Test video on DP-1 vs DP-2** — isolate display-specific issues
26. **Check niri output configuration** for DP-2 scale/transform
27. **Check if VRR causes frame timing issues** on TV
28. **Check HDR/SDR mismatch** on TV output

#### System Resource (P2)

29. **Monitor renderer CPU% during video** — if >50%, software decode fallback
30. **Check memory bandwidth saturation** — Strix Halo unified memory contention
31. **Profile with `perf top`** during video — look for `vaapi` vs `vpx`/`av1` software symbols
32. **Monitor `gpu_busy_percent`** during playback — should be elevated if VA-API active
33. **Check swap pressure** — 13.6 GB swap used, zram may be causing additional I/O

#### Config Improvements (P2)

34. **Fix AGENTS.md stale version** — "Chromium 150" → "Chromium 151"
35. **Port `--disable-background-media-suspend` to Brave/Darwin** config
36. **Add `LIBVA_DRIVER_NAME=radeonsi` to Helium wrapper** environment if needed
37. **Add I/O pressure check** to `post-deploy-check.sh`
38. **Consider `--canvas-oop-rasterization`** for video compositing path

#### Documentation (P3)

39. **Document I/O pressure as primary cause** of media stuttering on this hardware
40. **Add `/proc/pressure/io` check** to AGENTS.md troubleshooting section
41. **Document cgroup I/O throttling setup** in AGENTS.md
42. **Create a Helium video debugging runbook** in `docs/`
43. **Update FEATURES.md** with anti-throttling note

#### Prevention (P3)

~~44. **Add Gatus check for I/O pressure** — alert when avg10 > 80%~~ done — same as item 5 (Gatus "I/O Stall Rate")
45. **Add pre-deploy check** validating Helium wrapper includes VA-API flags
46. **Add periodic GPU decode benchmark** — alert if FPS drops below threshold
47. **Consider automated build throttling** — detect media playback and throttle builds
48. **Monitor zram swap I/O** — high swap I/O on top of build I/O compounds the problem
49. **Consider increasing zram swap size** or adding a swapfile on ext4 to reduce BTRFS-backed swap I/O
50. **Profile disk I/O during typical workday** — identify recurring I/O storms from scheduled tasks (btrbk, nix-gc, fstrim, backup jobs)

### g) Questions I CANNOT Answer Myself

1. **What are you watching and is it ALWAYS 3 FPS or only when the system is busy?** — If it's only during builds/compilation, then I/O contention is confirmed as the sole cause and VA-API may be working fine. If it's ALWAYS 3 FPS even when the system is idle, then we have a deeper video decode/compositing problem. I can see the system is under massive I/O load right now, but I don't know if the 3 FPS happens only under load or always.

2. **Can you open `chrome://gpu` in Helium and tell me what "Video Decode" says under "Graphics Feature Status"?** — "Hardware accelerated" (green) vs "Software only" (yellow/red) tells us definitively whether VA-API is working inside Chromium. Also check the "Problems Detected" section for any GPU blocklist entries. I cannot open a GUI browser from the CLI.

3. **Should I implement cgroup I/O throttling for development builds now, or is the current build a one-off?** — If heavy builds (cargo, nix build) run regularly while you consume media, then permanent I/O throttling is the right fix. If this was a one-time build, the fix may be unnecessary. I can see `projects-manage-automation` is configured to run builds, suggesting this is recurring, but I need confirmation that media + builds running concurrently is a regular use case.

---

## Files Changed This Session

| File                                 | Change                                   | Committed        |
| ------------------------------------ | ---------------------------------------- | ---------------- |
| `platforms/common/packages/base.nix` | +4 anti-throttling flags + comment block | Yes (`9f72a422`) |
| `AGENTS.md`                          | +1 gotcha entry for video throttling     | Yes (`9f72a422`) |

## Files NOT Changed (But Should Be)

| File                                     | What's needed                                                              |
| ---------------------------------------- | -------------------------------------------------------------------------- |
| `AGENTS.md:377`                          | "Chromium 150" → "Chromium 151" (stale version)                            |
| `platforms/common/programs/chromium.nix` | Add `--disable-background-media-suspend` to Brave/Darwin config for parity |

---

## TL;DR

**TWO root causes found:**

1. **Disk I/O saturation (PRIMARY)** — A concurrent `cargo-nextest` Rust build is saturating the NVMe at 80-99% I/O pressure. Video buffering starves. This is the same QLC NAND CoW churn pattern that caused 58 WDT resets. Fix: cgroup I/O throttling for dev builds + elevated I/O priority for Helium.

~~2. **Missing anti-throttling flags (SECONDARY)** — Added 4 flags for background-tab video. Nice-to-have, committed but NOT deployed. Was my initial (wrong) diagnosis.~~ done — 4 flags deployed in base.nix

**What I got wrong:** I should have checked `/proc/pressure/io` FIRST. One command would have revealed the 99% I/O pressure immediately. Instead I spent time researching Chromium source code for throttling flags that only affect background tabs.

**Still unverified:** Whether VA-API hardware decode is actually working inside Chromium (only verified at system level via `vainfo`). Need user to check `chrome://gpu`.

**Fix NOT deployed.** User is still at 3 FPS.

---

> **PARTIALLY RESOLVED —** The 4 anti-throttle flags were deployed (items 11, TL;DR-2). PSI I/O monitoring + Gatus alert added (items 4, 5, 44). **But the PRIMARY root cause (cgroup I/O throttling for dev builds, items 1-3, 6-10) was NEVER implemented** — it remains in ROADMAP.md Theme 3. VA-API Chromium verification (items 12-20) was never done. Most investigation items (21-50) remain open.
