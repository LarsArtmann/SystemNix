# Helium Config Overhaul — Brutal Self-Audit

**Date:** 2026-07-09 08:48
**Session scope:** Helium browser wrapper config in `platforms/common/packages/base.nix`
**Changed files:** `platforms/common/packages/base.nix`, `AGENTS.md`

---


## What Was Done

### The Task

User asked "How can we improve our Helium config?" — then asked for deeper research, breakdown, execution, and verification.

### Research Completed (4 areas)

1. **Helium identity:** Helium is a Chromium 150 fork (ungoogled-chromium base), NOT Electron. Built by imputnet. Includes built-in uBO fork, anti-fingerprinting, DuckDuckGo-style !bangs. The Nix flake (`helium-browser-nix-flake`) already wraps the binary with makeWrapper (6 flags on Linux: `--ozone-platform-hint=auto`, `--enable-features=WaylandWindowDecorations`, `--disable-component-update`, `--simulate-outdated-no-au`, `--check-for-update-interval=0`, `--disable-background-networking`).

2. **Chromium Wayland flags:** Chrome 140+ defaults to Wayland. `--ozone-platform-hint=auto` is correct (graceful X11 fallback). `WaylandWindowDecorations` needed for CSD on compositors without SSD (GNOME/Mutter). Niri strips all decorations, so relevance is questionable.

3. **AMD VA-API flags:** `VaapiVideoDecodeLinuxGL` was renamed to `AcceleratedVideoDecodeLinuxGL` in Chromium 131+. `VaapiVideoEncoder` → `AcceleratedVideoEncoder`. The name `AcceleratedVideoDecoder` (no suffix) was NEVER a valid feature — it was silently ignored by Chromium. For AMD: also need `VaapiIgnoreDriverChecks` and `UseMultiPlaneFormatForHardwareVideo`.

4. **Memory management flags:** `--renderer-process-limit=N` caps renderer processes. `--process-per-site` consolidates same-site tabs (security tradeoff). `--enable-low-end-device-mode` forces 512MB memory cap + RGB565 color (too extreme for desktop). Tab discarding / Memory Saver is the modern approach — Chromium proactively deactivates inactive tabs. `--disable-backgrounding-occluded-windows` and `--disable-renderer-backgrounding` PREVENT this lifecycle management, keeping all tabs fully active.

---

## a) FULLY DONE

| #   | Item                                       | Details                                                                                                                                                                                                                                                           |
| --- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Double-wrap bug identified                 | SystemNix wrapped the upstream makeWrapper script (`$heliumPackage/bin/helium`), not the real binary (`$heliumPackage/opt/helium/helium`). Two `--enable-features` switches → Chromium's `GetSwitchValueASCII` returns only the last value → silent feature loss. |
| 2   | Double-wrap bug fixed                      | Rewrote wrapper to `makeWrapper $out/opt/helium/helium $out/bin/helium` — wrapping the real binary directly. All flags now in a single makeWrapper layer.                                                                                                         |
| 3   | Invalid feature names corrected            | Removed `AcceleratedVideoDecoder` (never existed). Renamed `VaapiVideoEncoder` → `AcceleratedVideoEncoder`. Added `AcceleratedVideoDecodeLinuxGL`, `AcceleratedVideoDecodeLinuxZeroCopyGL`, `VaapiIgnoreDriverChecks`, `UseMultiPlaneFormatForHardwareVideo`.     |
| 4   | Backgrounding-disable flags removed        | `--disable-backgrounding-occluded-windows` and `--disable-renderer-backgrounding` deleted. These prevented Chromium's tab lifecycle management, contributing to the 2026-06-19 OOM cascade (66h unbounded renderer growth).                                       |
| 5   | Upstream privacy flags merged              | `--disable-component-update`, `--simulate-outdated-no-au`, `--check-for-update-interval=0`, `--disable-background-networking` added to the single wrapper (previously only in the upstream wrapper layer that was being double-wrapped).                          |
| 6   | LD_LIBRARY_PATH replicated                 | Upstream wrapper set `--prefix LD_LIBRARY_PATH` for libGL, libvdpau, libva, pipewire, alsa-lib, libpulseaudio. Replicated in the new single wrapper since we no longer pass through the upstream wrapper.                                                         |
| 7   | `--ozone-platform-hint=auto` made explicit | Was in upstream wrapper but lost to the double-wrap collision. Now explicit.                                                                                                                                                                                      |
| 8   | `--enable-gpu-rasterization` added         | Offloads rasterization to GPU, reducing CPU memory buffers.                                                                                                                                                                                                       |
| 9   | `nix flake check --no-build` passes        | All modules, packages, and checks eval successfully.                                                                                                                                                                                                              |
| 10  | AGENTS.md updated                          | 4 new entries: double-wrap collision, VA-API renames, backgrounding flags, Helium identity.                                                                                                                                                                       |

---

## b) PARTIALLY DONE

| #   | Item                  | What's done                                | What's missing                                                                                                                                                                                   |
| --- | --------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Flake validation      | `--no-build` eval check passes             | **No actual build test.** Never ran `nix build` or eval of the full toplevel. The wrapper might fail at build time (e.g., `$out/opt/helium/helium` path might not exist after symlinkJoin + cp). |
| 2   | AGENTS.md update      | 4 new entries added                        | The existing "Helium crash on display hotplug" entry (line 205) still mentions `--enable-zero-copy` as crash-amplifying — but we KEPT `--enable-zero-copy`. No cross-reference added.            |
| 3   | Feature flag research | Identified correct names for Chromium 131+ | Did not verify whether Helium (Chromium 150) actually recognizes all flags. Some may have been removed or renamed again between 131 and 150.                                                     |
| 4   | Wayland migration     | `--ozone-platform-hint=auto` added         | `WaylandWindowDecorations` feature was DROPPED from the merged `--enable-features` line with no documented reason. This was in the upstream wrapper.                                             |

---

## c) NOT STARTED

| #   | Item                                     | Impact                                                                                                                                                                                                                                                                                                    |
| --- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Deploy + runtime verification**        | Zero runtime testing. We don't know if the wrapper actually works, if Wayland activates, if VA-API decodes, if the real binary path is correct.                                                                                                                                                           |
| 2   | **VA-API verification**                  | No `vainfo` check, no `chrome://gpu` check, no DevTools Media tab verification. We're assuming the flags work.                                                                                                                                                                                            |
| 3   | **Memory impact measurement**            | Removed backgrounding-disable flags but have no before/after memory measurement. Can't verify the OOM mitigation actually helps.                                                                                                                                                                          |
| 4   | **`nix fmt`**                            | Never ran treefmt/alejandra on the changed files.                                                                                                                                                                                                                                                         |
| 5   | **Disk cache to tmpfs**                  | ArchWiki recommends `--disk-cache-dir="$XDG_RUNTIME_DIR/chromium-cache"`. Reduces disk writes and speeds up browsing. Not configured.                                                                                                                                                                     |
| 6   | **KeePassXC native messaging**           | FEATURES.md says "Browser integration, Chromium + Helium native messaging manifests" but we didn't verify the native messaging host is wired to the new wrapper path.                                                                                                                                     |
| 7   | **macOS Helium flags**                   | The `heliumWrapped` returns raw `heliumPackage` on Darwin (no wrapping). macOS Helium runs with upstream flags only — none of SystemNix's VAAPI/GPU/session flags apply (some are Linux-only, but privacy flags like `--disable-background-networking` are cross-platform).                               |
| 8   | **`browser-policies.nix` interaction**   | `programs.chromium` is enabled with forced extensions (ytShortsBlocker, OneTab). Helium is ungoogled-chromium — unclear if `programs.chromium` policies apply to it. They likely DON'T (the NixOS module targets the `chromium` package, not Helium). This means Helium may be missing forced extensions. |
| 9   | **Helium Memory Saver configuration**    | Chromium has enterprise policies (`HighEfficiencyModeEnabled`, `MemorySaverModeSavings`) for Memory saver. Could set `Maximum` mode via policy for aggressive tab discarding on the memory-constrained Strix Halo system. Not configured.                                                                 |
| 10  | **Gatus monitoring for browser session** | No health check for "is the desktop session alive and is Helium running."                                                                                                                                                                                                                                 |

---

## d) TOTALLY FUCKED UP / RISKY DECISIONS

### 1. Silently dropped `WaylandWindowDecorations`

**What happened:** The upstream wrapper had `--enable-features=WaylandWindowDecorations`. When I merged all flags into a single `--enable-features` line, I included our VAAPI flags but DROPPED `WaylandWindowDecorations` without documenting why.

**Impact:** Unknown. Niri strips decorations, so it may be irrelevant. But I made an undocumented decision that could affect window appearance. This violates the "document tradeoffs" principle.

**Severity:** Low-Medium. Needs explicit decision: include or document exclusion.

### 2. Added `--enable-gpu-rasterization` without considering GPUActive pressure

**What happened:** I added `--enable-gpu-rasterization` because the research said it's "recommended for AMD."

**The problem:** evo-x2 has **51+ GiB GPUActive (55% of visible RAM) with GPUReclaim=0**. GPU rasterization moves MORE work to the GPU — which means MORE GTT buffer objects, MORE GPUActive memory. On a system already drowning in GPU memory pressure, this could make things WORSE.

**Severity:** Medium-High. This was a thoughtless copy-paste from generic AMD advice without considering the Strix Halo unified memory crisis. Should probably be REMOVED or at minimum tested with memory monitoring.

### 3. Kept `--enable-zero-copy` despite AGENTS.md calling it crash-amplifying

**What happened:** AGENTS.md line 205 explicitly states: "Amplified by `--enable-zero-copy` (DMA-BUFs invalidated on connector change, no software fallback)." I kept the flag.

**Impact:** `--enable-zero-copy` was identified as a contributing factor to the display hotplug crash. The `--disable-gpu-watchdog` mitigates the kill, but the root cause (DMA-BUF invalidation on connector change) persists.

**Severity:** Medium. Should be tested — does removing `--enable-zero-copy` prevent the hotplug crash entirely, making `--disable-gpu-watchdog` unnecessary?

### 4. `--simulate-outdated-no-au` quoting is fragile

**What happened:** The flag `--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'` has embedded single quotes inside a makeWrapper `--add-flags` string in a Nix string in a bash heredoc. Three layers of quoting.

**Risk:** If the single quotes don't survive makeWrapper's argument parsing, the flag could be split into multiple arguments or silently mangled. No way to know without runtime testing.

**Severity:** Low. Worst case: the "outdated" banner appears. Not functional impact.

### 5. No build verification at all

**What happened:** Only ran `nix flake check --no-build`. Never built the package.

**Risk:** The `makeWrapper $out/opt/helium/helium $out/bin/helium` line assumes the real binary exists at that path after the `cp -a ${heliumPackage}/opt $out/opt` step. If the upstream package structure differs (e.g., binary is at a different path), the build fails. The old code used `wrapProgram $out/bin/helium` which operated on the existing (copied) wrapper script — a known-good path.

**Severity:** High. Could be a build-breaking change that only surfaces at deploy time.

---

## e) WHAT WE SHOULD IMPROVE (on the Helium config specifically)

### High Priority

1. **Build the actual package** — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` (eval only) or at minimum `nix build` the heliumWrapped derivation to verify the wrapper path is correct.

2. **Remove `--enable-gpu-rasterization`** — It increases GPU memory pressure on a system where GPUActive already consumes 55% of visible RAM. Generic AMD advice doesn't apply to Strix Halo's unified memory architecture.

3. **Test removing `--enable-zero-copy`** — This was flagged as crash-amplifying in AGENTS.md. If removing it prevents the hotplug crash, `--disable-gpu-watchdog` may become unnecessary too (and we regain GPU hang detection).

4. **Explicitly decide on `WaylandWindowDecorations`** — Either include it or add a code comment explaining why it's excluded for niri.

5. **Run `nix fmt`** — Format the changed files.

6. **Deploy + verify** — Actually run the wrapper, check `chrome://gpu` for VA-API status, check `chrome://version` for Wayland mode and active flags.

### Medium Priority

7. **Add `--disk-cache-dir` to tmpfs** — Reduces NVMe writes (QLC NAND longevity) and speeds up browsing. Use `$XDG_RUNTIME_DIR/helium-cache`.

8. **Configure Memory Saver via enterprise policy** — Set `HighEfficiencyModeEnabled = true` and `MemorySaverModeSavings = 2 (Maximum)` via Chromium policy. Aggressive tab discarding is exactly what this memory-constrained system needs.

9. **Verify KeePassXC native messaging** — The native messaging host JSON must point to the correct binary path. If the wrapper path changed, KeePassXC browser integration may be broken.

10. **Add `--disable-features=UseChromeOSDirectVideoDecoder`** — Some AMD configs need this as a fallback if VA-API doesn't work. Keep in back pocket.

11. **Verify `browser-policies.nix` applies to Helium** — `programs.chromium` targets the chromium package. Helium may need a separate policy file at `/etc/helium/policies/managed/`.

12. **Consider `--process-per-site`** — evo-x2 has 42 Helium processes / 4.5 GiB. Site consolidation would reduce process overhead at the cost of isolation. Given the memory pressure, this tradeoff may be worth it.

### Low Priority

13. **Add `--gtk-version=4`** — Fixes input method issues on Wayland. May not matter if no IME is used.

14. **Add `--enable-wayland-ime`** — If Fcitx5 or any IME is ever added.

15. **Consider touchpad gesture flags** — `TouchpadOverscrollHistoryNavigation` is default in Chromium 148+. Helium is 150, so this should already be on. Verify.

16. **macOS Helium wrapping** — Add a macOS makeWrapper branch for cross-platform privacy flags.

---

## f) Up to 50 Things to Get Done Next

### Helium-specific (immediate)

1. Build the heliumWrapped derivation to verify the wrapper path works
2. Remove `--enable-gpu-rasterization` (GPUActive pressure)
3. Test `--enable-zero-copy` removal (hotplug crash root cause)
4. Explicitly include or exclude `WaylandWindowDecorations` with documentation
5. Run `nix fmt` on changed files
6. Deploy to evo-x2 and verify runtime
7. Verify VA-API: open `chrome://gpu`, check "Video Decode" status
8. Verify Wayland: open `chrome://version`, check "Platform" line
9. Verify all flags: open `chrome://version`, check "Command-line Switches" section
10. Measure memory before/after: `smem -P helium` before deploy vs after
11. Add `--disk-cache-dir` pointing to `$XDG_RUNTIME_DIR/helium-cache`
12. Configure Memory Saver enterprise policy (Maximum mode)
13. Verify KeePassXC native messaging host path
14. Test display hotplug (unplug monitor, plug back in) — does Helium survive?
15. Test DRM playback (Netflix/YouTube Premium) — does Widevine work?
16. Check if `browser-policies.nix` policies apply to Helium
17. If not, create `/etc/helium/policies/managed/` policy file
18. Add macOS wrapping branch for privacy flags
19. Consider `--process-per-site` for memory reduction
20. Add Helium flag documentation comment block in the wrapper

### System-wide (noticed during this session)

21. The 51+ GiB GPUActive / GPUReclaim=0 crisis is STILL unaddressed at root — TTM pool `pages_limit = 112 GiB` exceeds visible RAM. This is the #1 system stability risk.
22. `amd-gpu.nix` sets `MESA_VK_WSI_PRESENT_MODE=immediate` globally — AGENTS.md says this "worsens the race window for any Vulkan app during hotplug." Should this be scoped to specific apps only?
23. `power_dpm_force_performance_level=high` udev rule forces max GPU clocks always — increases power draw and heat. Consider `auto` for desktop workloads.
24. No GPU memory limit for Helium specifically — could add a systemd slice or cgroup for the browser process tree.
25. zram swap at 100% full — the system is chronically swapping. Consider increasing zram size or adding a physical swap device.
26. `browser-policies.nix` only has 2 extensions (ytShortsBlocker, OneTab) — Helium has a built-in uBO fork, but policies don't configure it.
27. The `home.nix` desktop entry has `exec = "env -u QT_STYLE_OVERRIDE helium %U"` — the `QT_STYLE_OVERRIDE` unset is for KeePassXC theming. Verify this doesn't interfere with Helium's Qt integration (the upstream package lists Qt6 buildInputs).
28. No Helium-specific Gatus alert — if the browser crashes repeatedly, there's no monitoring to detect it (OOM cascade precursor).
29. The `heliumPackage` attribute resolution tries `.default` then `.helium` — verify which exists in the current flake lock.
30. Update the existing "Helium crash on display hotplug" AGENTS.md entry to cross-reference the backgrounding flag removal.

### Documentation / process

31. Document the full flag rationale in a comment block in base.nix
32. Add a `docs/services/helium.md` service doc with flag explanations and troubleshooting
33. Update FEATURES.md Helium line to reflect the new flags
34. Add a pre-deploy check that verifies the helium wrapper binary path exists
35. Add a post-deploy check that verifies Helium starts and reports Wayland mode
36. Document the makeWrapper quoting rules for flags with spaces/quotes
37. Consider extracting Helium flags into a lib helper (like `harden` for systemd)
38. Create a NixOS test that builds and launches Helium headless
39. Add a statix/deadnix check specifically for the base.nix wrapper
40. Track Helium version updates — when it bumps Chromium version, re-verify flag names

### Broader system improvements (tangential)

41. TTM pool size override — reduce from 112 GiB to something sane (32-48 GiB)
42. MGLRU tuning — experiment with `min_ttl_ms` values
43. oomd configuration — add Helium-specific OOM score adjustment
44. Consider `systemd-oomd` `SwapUsedLimit` lower than 90% given chronic pressure
45. Add Prometheus alert for GPUActive > 60 GiB
46. Add Prometheus alert for zram swap > 90%
47. BTRFS `discard=async` removal — TODO_LIST Priority 0, still pending
48. Review all `--ignore-gpu-blocklist` consumers (Helium, any others?)
49. Consider Wayland `linux-drm-syncobj-c1` protocol for tearing reduction
50. Audit all Chromium-based apps (Helium, Electron apps) for Wayland flag consistency

---

## g) Top 2 Questions I Cannot Answer Myself

### Q1: Does `$out/opt/helium/helium` exist as the real binary after the symlinkJoin + cp step?

**Why I can't answer:** The upstream flake installs the binary at `$out/opt/helium/helium` in its `installPhase`. SystemNix does `cp -a ${heliumPackage}/opt $out/opt` which copies this. But I never BUILT the derivation — `nix flake check --no-build` only evaluates. The `makeWrapper` command could fail if the path is wrong.

**What I need:** Run `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` (eval) or build the heliumWrapped derivation directly and inspect the output path. OR deploy and see if it works.

### Q2: Should `--enable-gpu-rasterization` stay or go given the GPUActive crisis?

**Why I can't answer:** This is a judgment call that requires runtime data. GPU rasterization reduces CPU memory usage but increases GPU memory usage. On Strix Halo with unified memory, "GPU memory" IS "system memory" (via GTT buffer objects). So the question is: does GPU rasterization create more GPUActive pressure than it saves in CPU memory? I don't have the data to answer this — it requires before/after `GPUActive` measurements under identical workloads.

**What I need:** Deploy with the flag, measure GPUActive under a fixed browsing workload (e.g., 10 tabs open for 30 min), then deploy WITHOUT the flag and repeat. Compare `/proc/meminfo` GPUActive values.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
