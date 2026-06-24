# Session 79: EMEET PIXY — Camera Always Offline (Root Cause Found & Fix Written)

**Date:** 2026-05-12 06:40
**Severity:** Critical — webcam has NEVER worked since initial commit
**Status:** Fix written in emeet-pixyd, NOT yet pushed/tested/deployed

---

## Executive Summary

The EMEET PIXY webcam daemon has been running in `camera=offline` state since **day one** (initial commit `5ed956b`, 2026-04-30). The camera is physically connected and recognized by the kernel (`/dev/video0`, `/dev/hidraw8`), but the daemon's `probeVideo4linux()` function reads a sysfs path that has **never existed** on any Linux system, causing the video device to never be detected.

This means: **the entire EMEET PIXY integration — auto-tracking, noise cancellation, privacy mode, call detection, Waybar status — has never functioned.**

---

## a) FULLY DONE

1. **Root cause identified** — `probeVideo4linux()` in `probe.go` reads `/sys/class/video4linux/<dev>/device/id/vendor` and `/device/id/product`. On real hardware, `device` is a symlink to the USB *interface* directory, which does NOT contain an `id/` subdirectory. The `idVendor`/`idProduct` files only exist at the USB *device* level (parent directory). This means the probe silently fails on every iteration, `videoDev` is always empty, and the daemon reports `camera=offline`.

2. **Fix written in emeet-pixyd repo** (`/tmp/emeet-pixyd-review/`):
   - `probe.go`: Replaced broken `device/id/vendor` + `device/id/product` reads with `device/uevent` → parse `PRODUCT=328f/c0/2004` line. This matches the actual kernel sysfs structure and mirrors the working `probeHidraw()` pattern (which already uses uevent).
   - `main_test.go`: Updated all test fakes to create `device/uevent` files instead of `device/id/vendor`+`device/id/product`. Fixed `fakeVideoDev` struct (removed `vendor` field, `product` now holds uevent `PRODUCT=` value). Updated all 8 test cases.

3. **Additional issues documented:**
   - **OOM kill (2026-05-06 18:15)**: Kernel OOM killer killed emeet-pixyd during the GPU OOM cascade incident. The daemon recovered via `Restart=on-failure` but was offline for ~3 seconds.
   - **Web UI port conflict (2026-05-06 06:39)**: `bind: address already in use` on port 8090 after boot — something else briefly held the port during the previous boot's unclean shutdown.
   - **No WatchdogSec**: The daemon implements `sd_notify()` (`READY=1`, `WATCHDOG=1`, `STOPPING=1`) but the NixOS module doesn't set `WatchdogSec`. This is a missed health check opportunity.
   - **No OOMScoreAdjust**: The daemon has no OOM protection. During GPU memory exhaustion, it gets killed alongside user apps.

---

## b) PARTIALLY DONE

1. **emeet-pixyd fix** — Code changes are written and saved in `/tmp/emeet-pixyd-review/` but:
   - NOT compiled/verified (templ generated files are missing in the shallow clone, blocking `go test`)
   - NOT committed to the emeet-pixyd repo
   - NOT pushed to GitHub
   - NOT updated in SystemNix flake.lock
   - NOT deployed to evo-x2

---

## c) NOT STARTED

1. **Push emeet-pixyd fix** — Commit + push to `LarsArtmann/emeet-pixyd` master
2. **Update SystemNix flake input** — `nix flake lock --update-input emeet-pixyd`
3. **Deploy to evo-x2** — `just switch` and verify camera detection
4. **Add WatchdogSec** to NixOS module (emeet-pixyd supports sd_notify)
5. **Add OOMScoreAdjust** to NixOS module (protect against GPU OOM cascades)
6. **Verify waybar camera indicator** — should now show actual state instead of `---`
7. **Test auto-tracking on call** — verify the full call detection → tracking → privacy cycle
8. **Test `emeet-pixy status`** CLI command
9. **Test web UI** at `http://127.0.0.1:8090`
10. **Update AGENTS.md** — the EMEET PIXY section says "auto-activation" but it's never worked; update after verification

---

## d) TOTALLY FUCKED UP

1. **The entire EMEET PIXY integration has been non-functional since day one.** The bug was in the very first commit (`5ed956b`, `Extract device probing logic from main.go into probe.go`). The original `probeVideo4linux()` always read a non-existent sysfs path. The test suite validated against a fake sysfs structure (`device/id/vendor`) that doesn't exist on real hardware — tests passed, code never worked.

2. **15 daemon restarts across 10 boots** — every single one reported `camera=offline`. Not a single `found PIXY device` log line in the entire journal history.

3. **The daemon's saved state is lying**: `/run/emeet-pixyd/state.json` shows `{"camera":"privacy","audio":"nc","gesture":false,"inCall":false,"autoMode":"off"}` — but the camera was never detected. The `privacy` state was loaded from a previous session's save, not from actual hardware detection. On first boot with no state file, it would show `offline`.

4. **Waybar camera indicator has been showing `---` (offline) for weeks** without anyone noticing it was a real problem.

---

## e) WHAT WE SHOULD IMPROVE

1. **Integration tests need real sysfs mocking** — The test fake created `device/id/vendor` which doesn't exist. Tests should validate against the ACTUAL kernel sysfs structure. A `TestProbeVideo4linux_RealSysfs` test that skips if `/sys/class/video4linux/video0` doesn't exist would have caught this instantly.

2. **No health alerting for emeet-pixyd** — Gatus monitors 26+ endpoints but none check if the webcam daemon is functional. A simple check: `emeet-pixy status` should return non-offline state.

3. **The NixOS module should log probe failures at WARN level** — Currently, `probeVideo4linux` silently returns `""` on every read error. Adding `slog.Warn("video4linux probe: failed to read uevent", "path", ueventFile, "error", uErr)` would have made this obvious in logs.

4. **systemd service status in Gatus** — Add an endpoint or script check that verifies `emeet-pixyd` reports a non-offline state when the camera is physically connected.

5. **OOM protection for user services** — User services are vulnerable to GPU OOM cascades. Consider `OOMScoreAdjust=-100` for emeet-pixyd (not as critical as niri's `-1000`, but it should survive better than default 0).

---

## f) Top #25 Things We Should Get Done Next

### Immediate (Session 79 continuation)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | Generate templ files + run `go test` in emeet-pixyd | Verify fix | 5 min |
| 2 | Commit + push emeet-pixyd probe fix | Unblock deploy | 2 min |
| 3 | Update flake.lock in SystemNix | Pull fix | 1 min |
| 4 | Deploy `just switch` on evo-x2 | Fix takes effect | 5 min |
| 5 | Verify camera detection: `emeet-pixy status` | Confirm fix | 1 min |
| 6 | Test call auto-tracking cycle | End-to-end validation | 5 min |

### NixOS Module Improvements (emeet-pixyd upstream)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 7 | Add `WatchdogSec=30` to NixOS module | Crash detection | 1 min |
| 8 | Add `OOMScoreAdjust=-100` to NixOS module | OOM survival | 1 min |
| 9 | Add probe failure WARN logging in `probeVideo4linux` | Observability | 5 min |
| 10 | Add `Type=notify` to NixOS module (daemon already calls sd_notify) | Correctness | 1 min |

### Monitoring & Alerting

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 11 | Add Gatus check for emeet-pixyd status | Alerting | 10 min |
| 12 | Add SigNoz/journald log alert for "camera=offline" persistence | Proactive detection | 15 min |
| 13 | Add waybar tooltip showing last probe result | UX observability | 10 min |

### Integration Test Hardening

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 14 | Add `TestProbeVideo4linux_RealSysfs` (skip if no device) | Prevent regression | 10 min |
| 15 | Add `TestProbeVideo4linux_UeventProductFormat` edge cases | Robustness | 5 min |
| 16 | Add `TestHasPixyProduct` unit tests (new function) | Coverage | 5 min |
| 17 | Add NixOS VM test for emeet-pixyd module | Integration testing | 30 min |

### Documentation & Cleanup

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 18 | Update AGENTS.md emeet-pixy section with fix details | Knowledge | 5 min |
| 19 | Add ADR for uevent-based probing vs sysfs id files | Record decision | 10 min |
| 20 | Update emeet-pixyd CHANGELOG.md | Changelog | 2 min |

### Broader Lessons

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 21 | Audit other probe functions for similar sysfs path bugs | Preventive | 15 min |
| 22 | Review all hardware-related NixOS modules for similar issues | Preventive | 30 min |
| 23 | Add `just cam-status` to daily health check | Workflow | 2 min |
| 24 | Verify Ollama GPU OOM defense is still effective post-incident | Safety | 10 min |
| 25 | Check if other user services need OOMScoreAdjust | Hardening | 15 min |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should I add `Type=notify` to the emeet-pixyd NixOS module service definition?**

The daemon already calls `sd_notify("READY=1")`, `sd_notify("WATCHDOG=1")`, and `sd_notify("STOPPING=1")` via `github.com/coreos/go-systemd/v22/daemon`. Currently the module uses `Type=simple`. Changing to `Type=notify` means systemd will wait for the `READY=1` notification before considering the service started, which is more correct — but it requires also setting `WatchdogSec` (otherwise the watchdog calls are no-ops). I believe we should do this (items 7+10 above), but I'm noting it because it's a semantic change in service startup behavior.

---

## Technical Details

### The Bug

```
probeVideo4linux reads:  /sys/class/video4linux/video0/device/id/vendor
                         /sys/class/video4linux/video0/device/id/product

Actual sysfs structure:
  /sys/class/video4linux/video0/device  →  ../../../3-4:1.0  (USB interface)
  /sys/class/video4linux/video0/device/device  →  DOES NOT EXIST

What exists:
  /sys/class/video4linux/video0/device/uevent  →  PRODUCT=328f/c0/2004  ✅
  /sys/devices/.../usb3/3-4/idVendor  →  328f  (at USB device level, not interface)
```

### The Fix

Before (broken):
```go
vendorFile := fmt.Sprintf("%s/%s/device/id/vendor", sysfsPath, name)
productFile := fmt.Sprintf("%s/%s/device/id/product", sysfsPath, name)
// reads from files that don't exist → always fails → camera=offline forever
```

After (working):
```go
ueventFile := fmt.Sprintf("%s/%s/device/uevent", sysfsPath, name)
ueventData, uErr := os.ReadFile(ueventFile)
if hasPixyProduct(ueventData) { return videoPath }
// reads PRODUCT=328f/c0/2004 from uevent → matches → camera detected
```

### Timeline

| Date | Event |
|------|-------|
| 2026-04-30 | Initial commit with broken `probeVideo4linux` — camera never worked |
| 2026-05-06 06:39 | Web UI port conflict on boot (address already in use) |
| 2026-05-06 18:15 | OOM killed during GPU OOM cascade incident |
| 2026-05-08 11:38 | auto mode changed from `full` → `tracking-only` (but still offline) |
| 2026-05-10 | Multiple reboots for GPU incident debugging |
| 2026-05-11 22:41 | Current boot — still `camera=offline` |
| 2026-05-12 06:40 | Root cause identified and fix written |

---

## Files Changed (emeet-pixyd, NOT YET COMMITTED)

| File | Change |
|------|--------|
| `probe.go` | Replace `device/id/vendor`+`device/id/product` with `device/uevent` + new `hasPixyProduct()` |
| `main_test.go` | Rewrite fakeVideoDev struct, createFakeVideo4linux helper, all 8 probe test cases |

## Files Changed (SystemNix)

None — all changes are in the external emeet-pixyd repo. SystemNix needs only a flake.lock update after the upstream fix is pushed.

---

_Arte in Aeternum_
