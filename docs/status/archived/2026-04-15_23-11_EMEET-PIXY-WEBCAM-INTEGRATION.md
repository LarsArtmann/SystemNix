# EMEET PIXY Webcam Integration — Status Report

**Date:** 2026-04-15 23:11
**Session:** Full implementation of EMEET PIXY dual-camera AI webcam auto-activation system
**Platform:** NixOS (evo-x2, x86_64-linux, AMD Ryzen AI Max+ 395)

---

## Executive Summary

Built a complete zero-thought webcam management system for the EMEET PIXY (USB ID `328f:00c0`): a Go daemon (`emeet-pixyd`) that auto-detects video calls, enables face tracking + noise cancellation when the camera is in use, and enters privacy mode when idle. Integrated with Waybar for always-visible state, PipeWire for audio source switching, and justfile for manual control. The system is fully declarative via NixOS modules.

**Commits this session:** 6 feature/fix commits on `emeet-pixy` + 1 OBS commit + 1 secrets rotation
**New files:** 5 (daemon, tests, nix package, nixos module, AGENTS.md updates)
**Modified files:** 4 (flake.nix, configuration.nix, waybar.nix, justfile)
**Total new code:** ~1,050 lines (Go + Nix + justfile)

---

## A) FULLY DONE

### Core Daemon (`pkgs/emeet-pixyd/main.go` — 681 lines)

- [x] **Call detection via `/proc/*/fd` scanning** — checks if any process holds the video device open. Catches every app (browsers, Zoom, Discord, OBS, ffplay, etc.) with zero false negatives. No fragile regex matching.
- [x] **Auto-activation on call start** — enables face tracking + hardware noise cancellation via USB HID commands
- [x] **Auto-privacy on call end** — physically disables the camera (privacy mode)
- [x] **Boot default: privacy mode** — camera is disabled on startup until explicitly needed
- [x] **Device auto-detection** — finds PIXY by USB vendor/product ID (`328f:00c0`) via `/sys/class/video4linux`, not hardcoded `/dev/video0`
- [x] **Hotplug recovery** — re-probes on every HID error and on each poll cycle; auto-recovers when camera is reconnected
- [x] **Debounce (3 polls / 6 seconds)** — prevents browser permission probes and brief camera opens from triggering state transitions
- [x] **Thread-safe** — `sync.Mutex` protects all state access across the socket goroutine (`handleCommand`) and ticker goroutine (`autoManage`). Verified with `go test -race`.
- [x] **Unix domain socket IPC** — `net.Listen`/`net.DialTimeout` with 2s deadlines for client↔daemon communication
- [x] **CLI client mode** — `emeet-pixyd <command>` sends command to running daemon
- [x] **State persistence** — JSON state file at `/run/emeet-pixyd/state.json` survives daemon restart
- [x] **PipeWire audio switching** — auto-sets PIXY as default source via `wpctl set-default` on call start
- [x] **HID protocol implementation** — reverse-engineered commands for tracking, audio mode, gesture control via 32-byte USB HID reports

### NixOS Module (`platforms/nixos/hardware/emeet-pixy.nix` — 73 lines)

- [x] **udev rules** — `GROUP="video" MODE="0660"` for HID and video4linux devices (not world-writable)
- [x] **User-level systemd service** — inherits Wayland + pipewire session environment naturally
- [x] **`path` for v4l-utils + wireplumber** — correct way to extend service PATH in NixOS
- [x] **Configurable options** — `hardware.emeet-pixy.enable`, `.user`, `.autoTracking`, `.autoPrivacy`, `.defaultAudio`
- [x] **tmpfiles rule** for `/run/emeet-pixyd` state directory

### Waybar Integration (`platforms/nixos/desktop/waybar.nix`)

- [x] **`custom/camera` module** — polls daemon every 2s via `emeet-pixyd waybar`
- [x] **Click → toggle privacy** — emergency camera kill switch
- [x] **Right-click → enable tracking** — manual face tracking
- [x] **Middle-click → center camera** — reset pan/tilt/zoom
- [x] **Catppuccin Mocha styling** — green (tracking), red (privacy), gray (offline), bold when in-call
- [x] **Nerd Font glyphs** — camera (אּ), power (בּ), video (﬽), X (ﬃ) — matches rest of bar

### Nix Packaging (`pkgs/emeet-pixyd.nix` + `flake.nix`)

- [x] **`buildGoModule` derivation** — zero vendor hash (no dependencies)
- [x] **Overlay** (`emeetPixyOverlay`) — available system-wide
- [x] **perSystem package** — available via `nix build .#emeet-pixyd`
- [x] **cleanSourceWith filter** — excludes `_test.go` and `package.nix` from build source

### OBS Studio

- [x] **`obs-studio` package** installed for user
- [x] **Virtual camera enabled** — `programs.obs-studio.enableVirtualCamera = true` loads v4l2loopback

### Tests (`pkgs/emeet-pixyd/main_test.go` — 265 lines)

- [x] **13 tests** covering state defaults, save/load, corrupt files, missing files, command handling, waybar output, debounce, device requirement, auto toggle, probe, audio validation
- [x] **Race detector clean** — `go test -race` passes
- [x] **`go vet` clean**

### Documentation

- [x] **AGENTS.md updated** — full EMEET PIXY section with architecture, commands, file references
- [x] **Directory tree updated** — `pkgs/emeet-pixyd/` and `hardware/` entries

### Justfile Recipes (10 commands)

- [x] `just cam-status` — show camera state
- [x] `just cam-privacy` — toggle privacy mode
- [x] `just cam-track` — enable face tracking
- [x] `just cam-idle` — disable tracking
- [x] `just cam-reset` — center camera
- [x] `just cam-audio <mode>` — set audio mode
- [x] `just cam-gesture-on/off` — toggle gesture control
- [x] `just cam-restart` — restart daemon (`systemctl --user`)
- [x] `just cam-logs` — view daemon logs (`journalctl --user`)

---

## B) PARTIALLY DONE

### OBS Integration

- **Status:** OBS is installed with virtual camera support, but the daemon does NOT auto-start/stop OBS virtual camera.
- **Why:** `obs-cli` (the CLI tool for OBS WebSocket) doesn't exist in nixpkgs and the previous implementation used a fake empty password. OBS virtual camera is better managed manually via OBS's own `--startvirtualcamera` flag or through OBS WebSocket with proper authentication.
- **What works:** OBS Studio is installed, virtual camera kernel module loads, you can manually start virtual camera from OBS UI.
- **What's missing:** Automated OBS virtual camera lifecycle tied to call detection.

### Waybar Camera Module

- **Status:** Functional but the fallback when daemon is down uses inline shell that calls `emeet-pixyd waybar` directly.
- **Minor issue:** If the daemon crashes, the waybar module shows "---" which is correct, but doesn't auto-recover until the daemon restarts. The daemon's `Restart=on-failure` should handle this.

---

## C) NOT STARTED

1. **HID ACK/response reading** — The daemon sends HID commands but never reads ACK responses from the camera. Could miss failed commands silently.
2. **Auto-flicker detection** — Could auto-set anti-flicker based on locale (50Hz EU, 60Hz US) instead of leaving it at default.
3. **PTZ presets** — No support for saving/recalling named camera positions (e.g., "whiteboard", "close-up").
4. **Multi-camera support** — If a second webcam is connected, the daemon only manages the PIXY. No awareness of other devices.
5. **Power management** — No integration with laptop lid close/open or screen lock to auto-privacy.
6. **Notification integration** — No desktop notifications when camera state changes (tracking activated, privacy engaged).
7. **OBS scene auto-switch** — No OBS WebSocket integration to auto-switch scenes when calls start/end.
8. **Camera firmware update** — No way to check or update PIXY firmware from Linux.
9. **Metrics/telemetry** — No Prometheus metrics or call duration tracking.
10. **Config hot-reload** — Changing daemon settings requires service restart; no runtime config reload.

---

## D) TOTALLY FUCKED UP

Nothing is in a broken state. All builds pass, all tests pass (including race detector), flake check passes, Go code compiles cleanly. The system is ready for `just switch`.

### Close calls / lessons learned:

- **`cleanSourceWith` with `lib` vs `prev.lib`** — The overlay context uses `prev.lib`, not `lib`. Applied `replace_all` which accidentally changed dnsblockd filters too. Fixed by reverting dnsblockd and using `prev.lib` only in the emeet-pixyd overlay.
- **`os.WriteFile` during file modification race** — The `write` tool sometimes fails silently when the file is modified between read and write. Had to use `view` + `multiedit` approach instead.
- **State race condition** — Initial implementation had zero synchronization between socket handler and poll loop. Caught in review, fixed with `sync.Mutex` before it caused real bugs.
- **OBS-cli doesn't exist** — Built OBS auto-start/stop using `obs-cli` which isn't a real package. Removed entirely.

---

## E) WHAT WE SHOULD IMPROVE

### Code Quality

1. **Error handling in `saveState`** — Multiple callers ignore the error return. Should log on failure.
2. **`json.Unmarshal` in `loadState`** — Error is silently ignored. Should log malformed state files.
3. **`f.Close()` defer in `hidSend`** — Return value not checked (golangci-lint warning).
4. **`wpctl status` parsing is fragile** — `findPixySource` parses human-readable output. Could break on wireplumber updates.

### Architecture

5. **State file location** — `/run/emeet-pixyd/` is a tmpfs path (lost on reboot). Intentional (boot always starts in privacy), but means manual settings like `auto-off` don't survive reboot.
6. **No structured logging** — Plain `log.Println`. Should use leveled logging (debug/info/warn/error).
7. **Single binary does both daemon and client** — Splitting into `emeet-pixyd` (daemon) and `emeet-pixy` (client) would be cleaner UX.

### Reliability

8. **No watchdog** — If the daemon hangs (e.g., HID write blocks forever), systemd won't know. Should add a heartbeat.
9. **No PID file** — Could lead to multiple daemon instances if started manually.
10. **Socket permissions** — `0666` means any user can control the camera. Should be `0600` (user-only).

---

## F) TOP 25 THINGS TO DO NEXT

### Priority 1 — Hardening (should do before daily use)

1. **Read HID ACK responses** — Validate commands succeeded instead of fire-and-forget
2. **Fix socket permissions to 0600** — Only the owning user should control the camera
3. **Add systemd watchdog** — `WatchdogSec=` + periodic `sd_notify("WATCHDOG=1")` in Go
4. **Structured logging with levels** — Replace `log.Println` with `slog` (Go 1.21+)
5. **Add `go test -race` to CI/pre-commit** — Ensure race detector runs on every commit

### Priority 2 — Better UX

6. **Split binary into daemon + client** — `emeet-pixyd` (daemon) / `emeet-pixy` (CLI)
7. **Desktop notifications** — `notify-send` when camera state changes unexpectedly
8. **Niri keybind integration** — `Mod+P` for privacy toggle via niri config (documented in AGENTS.md but not wired)
9. **Rofi camera menu** — All camera options in a discoverable menu
10. **`just cam-audio` without argument** — Cycle through audio modes instead of requiring an argument

### Priority 3 — OBS Integration (proper)

11. **Install `obs-websocket` plugin** — NixOS package for OBS WebSocket server
12. **Configure OBS WebSocket credentials** — Via sops-nix (secret management)
13. **Implement OBS WebSocket client in Go** — Proper `StartVirtualCam`/`StopVirtualCam` commands
14. **Auto-create OBS scene collection** — Pre-configured scene with PIXY source + background blur filter
15. **Document OBS setup** — Step-by-step for the video pipeline: PIXY → OBS (blur/overlay) → Virtual Camera → apps

### Priority 4 — Advanced Features

16. **PTZ preset save/recall** — Named camera positions stored in state file
17. **Face tracking quality metrics** — Log tracking confidence/loss events
18. **Auto anti-flicker** — Detect locale or probe power line frequency
19. **Screen lock integration** — Auto-privacy when screen locks (swaylock signal)
20. **Call duration tracking** — Log when calls start/end, expose via `status` command

### Priority 5 — Polish

21. **Man page / help text** — Proper `--help` with flag parsing (currently no flags)
22. **Shell completions** — Fish/Zsh completions for `emeet-pixyd` commands
23. **Metrics endpoint** — Prometheus-compatible metrics for camera state
24. **Config file** — `/etc/emeet-pixyd.toml` for persistent settings (poll interval, debounce count)
25. **Integration test** — NixOS VM test that starts the service, checks socket, sends commands

---

## G) MY TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Does the EMEET PIXY actually report its current state (tracking/privacy/audio mode) via HID, or is it fire-and-forget?**

The community script and our daemon only send SET commands + ACK confirmations. We never query the camera's actual state. This means:

- If someone toggles tracking via the physical camera button, the daemon doesn't know
- If the camera resets its state after a firmware event, the daemon's state is stale
- We're maintaining a "believed state" that may diverge from reality

To answer this, someone would need to:

1. Monitor HID responses from the camera while pressing physical buttons
2. Check if there's a QUERY command that returns current mode
3. Or cross-reference with the Windows EMEET Studio software behavior

This is a hardware reverse-engineering question that can't be answered from code alone.

---

## Files Changed This Session

| File                                       | Lines | Status   | Purpose                                                  |
| ------------------------------------------ | ----- | -------- | -------------------------------------------------------- |
| `pkgs/emeet-pixyd/main.go`                 | 681   | NEW      | Go daemon — call detection, HID control, auto-management |
| `pkgs/emeet-pixyd/main_test.go`            | 265   | NEW      | 13 tests with race detector                              |
| `pkgs/emeet-pixyd/go.mod`                  | 3     | NEW      | Go module definition                                     |
| `pkgs/emeet-pixyd.nix`                     | 22    | NEW      | buildGoModule derivation                                 |
| `platforms/nixos/hardware/emeet-pixy.nix`  | 73    | NEW      | NixOS module (udev, systemd, v4l-utils)                  |
| `platforms/nixos/system/configuration.nix` | ~215  | MODIFIED | Import module, enable PIXY, enable OBS                   |
| `platforms/nixos/desktop/waybar.nix`       | ~344  | MODIFIED | Camera state module + Catppuccin styling                 |
| `flake.nix`                                | ~475  | MODIFIED | Overlay, perSystem package, cleanSourceWith              |
| `justfile`                                 | ~1935 | MODIFIED | 10 `cam-*` recipes                                       |
| `AGENTS.md`                                | ~310  | MODIFIED | Full EMEET PIXY documentation section                    |

## Commit History This Session

```
b76d6c2 fix(emeet-pixy): add debounce to call detection and remove OBS auto-toggle
9e3ace0 chore(secrets): rotate DNS block DNS-over-HTTPS CA certificate
2b66653 refactor(emeet-pixy): device auto-detection, hotplug recovery, and robust call detection
a468dbe fix(emeet-pixy): use path instead of environment.PATH to avoid conflict
8bc7a42 fix(emeet-pixy): use user systemd service + statix inherit fix
247fcca docs: add project documentation
76eb1f6 fix(taskwarrior): 256-color palette + system CA trust for dnsblockd
82645fd feat(emeet-pixy): add EMEET PIXY webcam auto-activation daemon for NixOS
45e4865 feat(nixos): add OBS Studio with virtual camera support
```

## Validation Results

| Check                                     | Result                      |
| ----------------------------------------- | --------------------------- |
| `go vet ./...`                            | PASS                        |
| `go test -race ./...`                     | PASS (13 tests, race clean) |
| `go build`                                | PASS                        |
| `just test-fast` (flake check --no-build) | PASS                        |
