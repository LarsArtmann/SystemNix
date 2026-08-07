# Helium Video 3 FPS Diagnosis — Self-Review

**Date:** 2026-08-07 05:32
**Trigger:** User reported Helium browser streaming video at ~3 FPS
**Status:** Root cause NOT fully resolved. Initial fix is valid but addresses the WRONG layer.

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

## What I Got Wrong

### 1. WRONG ROOT CAUSE (CRITICAL)

**I diagnosed "renderer backgrounding / occlusion throttling" as the cause of 3 FPS video.**

The user is watching the video ON SCREEN — the Helium window is VISIBLE on their TV (DP-2, 4K). The window is not backgrounded. It is not occluded. It is not scrolled out of view. It is not a background tab.

**Renderer backgrounding and occlusion throttling only affect windows Chromium considers "non-foreground".** A visible window on a connected display is foreground. My entire root cause analysis was wrong for the user's actual scenario.

The anti-throttling flags are still nice-to-have (they fix background tab video), but they will NOT fix visible-window 3 FPS.

### 2. Never Verified VA-API Is Actually Used BY Chromium

I verified VA-API works at the **system level** (`vainfo` succeeds). I did NOT verify that **Chromium/Helium is actually using VA-API for video decode**. These are completely different things:

- System VA-API = the driver and hardware can do hardware decode
- Chromium VA-API = Chromium's GPU process is actually routing video through VA-API

Chromium can silently fall back to software decode even when VA-API is available at the system level. Common causes:
- GPU blocklist (even with `--ignore-gpu-blocklist`, some features have separate enable/disable logic)
- Missing or incorrect feature flags for the specific codec (VP9, AV1)
- Sandbox blocking access to `/dev/dri/renderD128`
- GL backend mismatch (needs EGL on Wayland)
- `VaapiIgnoreDriverChecks` not being honored in Chromium 151

**I never checked `chrome://gpu` or `chrome://media-internals`** — these would immediately show whether hardware decode is active. I cannot check them from CLI, but I should have told the user to check them.

### 3. Ignored CPU Contention

The system showed **load average 6.51** with **73.6% user CPU** — multiple `rustc` processes consuming 80-254% CPU each. If video decode is falling back to software, this CPU contention would absolutely cause 3 FPS on high-resolution video.

I noted the CPU state but never connected it to the video problem.

### 4. Didn't Investigate Multi-Monitor / TV-Specific Issues

Two 4K displays are connected:
- DP-1: 3840x2160 (monitor)
- DP-2: up to 4096x2160 (TV)

The video is on the TV. Possible TV-specific issues I didn't investigate:
- Refresh rate mismatch (TV might be at 30Hz while compositor expects 60Hz)
- HDR / color space conversion overhead
- Cross-monitor compositing path (GPU might be doing expensive cross-GPU copies)
- HDCP negotiation overhead for DRM content on TV output

### 5. Didn't Check What the User Is Actually Watching

I don't know:
- What streaming service (Netflix? YouTube? Plex? local file?)
- What codec (H264? VP9? AV1?)
- What resolution (1080p? 4K?)
- Whether it's DRM-protected (Widevine path may bypass VA-API entirely)
- Whether it's the "often" that matters — is it ALWAYS 3 FPS or only under load?

### 6. Didn't Deploy or Test

The fix is committed (auto-git daemon, commit `9f72a422`) but **NOT deployed**. The running Helium process still has the OLD flags. I never ran `nix run .#deploy` or verified the fix at runtime.

### 7. AGENTS.md Version Is Stale

I updated the gotcha for video throttling but didn't fix the stale version:
- AGENTS.md says "Helium is Chromium 150"
- Actual version: **Chromium 151.0.7922.75** (Helium 0.15.2.1)

---

## Status Breakdown

### a) FULLY DONE

| Item | Details |
|------|---------|
| Anti-throttling flags added | 4 flags added to `base.nix`, committed as `9f72a422`, `nix flake check` passes |
| System-level VA-API verified | Mesa 26.1.6, radeonsi, full codec support confirmed |
| GPU pressure ruled out | GPU at 0% busy, 7% VRAM at time of check |
| AGENTS.md gotcha added | "Helium video throttling (3 FPS)" entry at line 375 |
| Research documented | Chromium source-level analysis of throttling mechanisms |

### b) PARTIALLY DONE

| Item | What's done | What's missing |
|------|-------------|----------------|
| Root cause diagnosis | Identified throttling flags were missing | Did NOT identify the ACTUAL root cause (likely software decode fallback or compositing issue on visible window) |
| Helium flag audit | Found and added anti-throttling flags | Did NOT verify VA-API is actually used by Chromium at runtime |
| Documentation | Added gotcha entry | AGENTS.md version still says "Chromium 150" (actual: 151) |

### c) NOT STARTED

| Item |
|------|
| Deploy the fix (`nix run .#deploy`) |
| Verify VA-API is actually used by Chromium (need `chrome://gpu` or GPU log analysis) |
| Check if video decode falls back to software under CPU contention |
| Investigate TV-specific rendering path (DP-2, 4K, refresh rate, HDR) |
| Check what codec/resolution/DRM the user's streams use |
| Test with `chrome://media-internals` to see actual decode path |
| Consider whether `--enable-gpu-rasterization` should be re-evaluated given this is a VIDEO problem |
| Check if `--use-gl=egl` or `--use-angle=gl` is needed for VA-API on Wayland |

### d) TOTALLY FUCKED UP

| Item | Why |
|------|-----|
| **Root cause misdiagnosis** | I told the user the root cause was renderer backgrounding/throttling. It's NOT — the window is visible on screen. The anti-throttling flags are a nice-to-have, not the fix. |
| **Never verified the fix** | I never deployed or tested. The user is still at 3 FPS. |
| **Didn't check the obvious thing** | "Is Chromium actually using hardware decode?" is the FIRST question for "why is video slow?" — I never checked it. |

### e) WHAT WE SHOULD IMPROVE

1. **Always verify claims at runtime, not just config level.** "VA-API works at system level" ≠ "Chromium uses VA-API." These are separate verification steps.
2. **Ask what the user is actually experiencing** before diving into source-code research. "What are you watching? What codec? Always or sometimes?" would have redirected the investigation immediately.
3. **Check `chrome://gpu` FIRST.** It's the single most diagnostic tool for Chromium video issues. I should have told the user to open it immediately.
4. **Consider CPU contention.** Load average 6.51 with rustc compiling is a red flag for software-decode video.
5. **The AGENTS.md "Chromium 150" entry should be parameterized or auto-detected** — it's already stale.

### f) NEXT 50 THINGS TO DO

#### Root Cause (P0 — Do These First)

1. **Tell the user to open `chrome://gpu`** and check "Video Decode" status — is it "Hardware accelerated" or "Software only"?
2. **Tell the user to open `chrome://media-internals`** while playing the video — check the "Player Properties" for `video_decoder` value
3. **Check Chromium GPU log** at `~/.config/net.imput.helium/gpucache/` for VA-API errors
4. **Verify `--ignore-gpu-blocklist` is actually working** — check `chrome://gpu` "Problems" section
5. **Check if software decode is the fallback** — monitor renderer CPU% during video playback (if >50% on one core, it's software decode)
6. **Test with a known-good VP9/AV1 test video** (e.g. https://test-videos.co.uk or YouTube AV1 test)
7. **Deploy the current fix** (`nix run .#deploy`) — the anti-throttling flags are still beneficial

#### VA-API Deep Investigation (P1)

8. **Check if `--use-gl=egl` is needed** — Wayland requires EGL for VA-API; Chromium might default to a different GL backend
9. **Check if `--use-angle=gl` or `--use-angle=vulkan` affects VA-API** — ANGLE backend choice impacts decode path
10. **Verify `/dev/dri/renderD128` is accessible** from Chromium's sandbox — check `ls -la /dev/dri/`
11. **Check if `LIBVA_DRIVER_NAME=radeonsi` is set** in Helium's environment
12. **Test VA-API decode directly** with `mpv --hwdec=vaapi <video_url>` to confirm GPU decode works for the same content
13. **Check if Chromium 151 changed VA-API flag names again** — the last rename was at Chromium 131; verify no further renames
14. **Consider adding `--enable-features=VaapiVideoDecodeLinuxGL`** (old name) alongside the new names as belt-and-suspenders
15. **Check `chrome://device-log`** for GPU sandbox or VA-API initialization failures

#### GPU Rasterization Re-Evaluation (P1)

16. **Re-evaluate `--enable-gpu-rasterization`** — it was disabled for GPUActive memory pressure, but VIDEO playback may need it. Test with it enabled and measure GPUActive impact.
17. **Benchmark video playback WITH and WITHOUT GPU rasterization** — measure FPS, CPU, GPUActive
18. **Consider `--enable-gpu-rasterization` only affects page compositing, not video decode** — clarify the actual relationship
19. **Check if `--disable-software-rasterizer` would force GPU path** — might help or might break everything

#### Multi-Monitor / TV Investigation (P1)

20. **Check TV refresh rate** — is DP-2 at 30Hz, 60Hz, or variable? `cat /sys/class/drm/card1-DP-2/modes`
21. **Check for HDR/SDR mismatch** — is the TV expecting HDR content while compositor outputs SDR?
22. **Test video on DP-1 (monitor) vs DP-2 (TV)** — is it display-specific?
23. **Check niri output configuration** — what scale/transform is applied to DP-2?
24. **Check if VRR (Variable Refresh Rate) is enabled** — FreeSync on TV can cause frame timing issues
25. **Check HDMI/DP cable bandwidth** — 4K@60Hz needs DP 1.2+ or HDMI 2.0+; cable might be limited

#### DRM / Widevine Investigation (P1)

26. **Check if the user watches DRM content** (Netflix, Max, Disney+) — Widevine path may bypass VA-API
27. **Verify Widevine CDM version** — `ls -la /nix/store/*widevine*/` and check compatibility
28. **Check if L1 vs L3 Widevine affects decode path** — L1 uses hardware path, L3 uses software
29. **Test with a non-DRM video** (YouTube, local file) to isolate DRM as a variable
30. **Check if Helium's ungoogled-chromium base has VA-API patches that conflict** — upstream Chromium VA-API support may differ

#### System Resource Investigation (P2)

31. **Monitor CPU usage during video playback** — is the renderer process at 100% CPU? (software decode indicator)
32. **Check memory bandwidth saturation** — Strix Halo unified memory; heavy CPU + GPU traffic competes
33. **Profile with `perf top`** during video playback — see if `vaapi` or `vpx`/`av1` software decoder symbols appear
34. **Check if Ollama model loading causes intermittent GPU memory pressure** — models loading/unloading could starve video decode
35. **Monitor `gpu_busy_percent` during video playback** — should be elevated if VA-API is active

#### Configuration Improvements (P2)

36. **Fix AGENTS.md stale version** — "Chromium 150" → "Chromium 151" or make it version-agnostic
37. **Add `chrome://gpu` verification step** to `post-deploy-check.sh` for Helium
38. **Consider a Helium-specific GPU diagnostic script** that checks VA-API status from CLI
39. **Port `--disable-background-media-suspend` to Brave/Darwin config** — it's missing there too
40. **Add `LIBVA_DRIVER_NAME=radeonsi` to Helium wrapper environment** if not inherited
41. **Consider `--enable-features=DefaultEnableGpuRasterization`** as a targeted feature flag instead of the command-line switch
42. **Check if `--canvas-oop-rasterization` affects video compositing** — out-of-process rasterization might help or hurt

#### Documentation (P3)

43. **Document the VA-API verification procedure** in AGENTS.md — how to check if Chromium is actually using hardware decode
44. **Add `chrome://gpu` and `chrome://media-internals` to the Helium troubleshooting guide**
45. **Document the GPU rasterization trade-off** more precisely — when to enable/disable based on workload
46. **Create a Helium video performance debugging runbook** in `docs/`
47. **Update FEATURES.md** — "VAAPI hardware accel" should note "verify at runtime with chrome://gpu"

#### Prevention (P3)

48. **Add a Gatus check for VA-API availability** — `vainfo` exit code as health signal
49. **Add a pre-deploy check** that validates Helium wrapper includes VA-API flags
50. **Consider a periodic GPU decode benchmark** — run a short video test and alert if FPS drops below threshold

### g) Questions I CANNOT Answer Myself

1. **What are you watching and how?** — Which streaming service or video source? What resolution? Is it DRM-protected (Netflix/Max/Disney+)? Is it ALWAYS 3 FPS or only when the system is busy (compiling, Ollama loaded)? This single answer would eliminate half the hypotheses above.

2. **Can you open `chrome://gpu` in Helium and tell me what "Video Decode" says?** — Specifically, under "Graphics Feature Status", is "Video Decode" showing "Green: Hardware accelerated" or "Yellow/Red: Software only, hardware acceleration unavailable"? Also check if there are any entries in the "Problems Detected" section. This is THE diagnostic that tells us if VA-API is actually working inside Chromium. I cannot open a GUI browser from the CLI.

3. **Is the 3 FPS on the TV (DP-2) specifically, or also on the main monitor (DP-1)?** — If you drag the Helium window to the other screen, does it improve? This would isolate whether it's a display-specific compositing issue vs. a decode issue. I can see two 4K outputs are connected but can't determine which one has the problem or whether it's display-agnostic.

---

## Files Changed This Session

| File | Change | Committed |
|------|--------|-----------|
| `platforms/common/packages/base.nix` | +4 anti-throttling flags + comment block | Yes (`9f72a422`) |
| `AGENTS.md` | +1 gotcha entry for video throttling | Yes (`9f72a422`) |

## Files NOT Changed (But Should Be)

| File | What's needed |
|------|---------------|
| `AGENTS.md:377` | "Chromium 150" → "Chromium 151" (stale version) |
| `platforms/common/programs/chromium.nix` | Add `--disable-background-media-suspend` to Brave/Darwin config for parity |

---

## TL;DR

I added 4 anti-throttling flags that are nice-to-have for background tabs. But the user's problem is 3 FPS on a **visible** window, which means the real root cause is almost certainly **Chromium not using VA-API hardware decode** (software decode fallback under CPU contention). I never verified whether VA-API is actually engaged inside Chromium — only that it works at the system level. The fix needs to be deployed, and the user needs to check `chrome://gpu` to tell us if hardware decode is active.
