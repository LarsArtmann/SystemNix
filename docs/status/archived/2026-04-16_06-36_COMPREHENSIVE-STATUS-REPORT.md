# SystemNix — Comprehensive Status Report

**Date:** 2026-04-16 06:36
**Branch:** master @ `99fa7bf`
**Reporter:** Crush (GLM-5.1)
**Scope:** Full project audit after emeet-pixyd refactoring session

---

## A. FULLY DONE

### emeet-pixyd — Core Daemon (`main.go`, 1275 lines)

| Feature                    | Status | Details                                                            |
| -------------------------- | ------ | ------------------------------------------------------------------ |
| HID device auto-detection  | Done   | USB vendor/product ID `328f:00c0`, hotplug recovery                |
| Camera state management    | Done   | Tracking / Privacy / Idle / Offline with type-safe `CameraState`   |
| Audio mode cycling         | Done   | NC → Live → Original → NC with `AudioMode` type                    |
| Face tracking control      | Done   | HID commands via hidraw, bidirectional state query                 |
| Gesture control            | Done   | Enable/disable via HID interface 0x04                              |
| Auto-call management       | Done   | `/proc/*/fd` scanning, debounced, auto tracking + NC on call start |
| PipeWire integration       | Done   | Auto-switch default source to PIXY on call start                   |
| Context propagation        | Done   | `context.Context` threaded through all I/O-bound functions         |
| Sentinel errors            | Done   | Package-level `var err...` for all error conditions                |
| Named constants            | Done   | ~20 magic numbers extracted to named consts                        |
| Generic `queryHIDState[T]` | Done   | Type-safe HID queries, no `interface{}` or type assertions         |
| Structured logging         | Done   | `slog` with debug/info/warn/error levels                           |
| JSON state persistence     | Done   | camelCase tags (`inCall`, `autoMode`)                              |
| Unix socket IPC            | Done   | 0600 permissions, 2s timeout, command protocol                     |
| systemd watchdog           | Done   | `sdNotify("WATCHDOG=1")` on every tick                             |
| Mutex protection           | Done   | `sync.Mutex` guards all state access                               |
| CLI client                 | Done   | `emeet-pixy <command>` via same binary                             |

### emeet-pixyd — Extracted Types Package (`internal/pixy/pixy.go`, 182 lines)

| Feature              | Status | Details                                                   |
| -------------------- | ------ | --------------------------------------------------------- |
| `CameraState` type   | Done   | With `Valid()`, `HIDByte()` methods                       |
| `AudioMode` type     | Done   | With `Valid()`, `HIDByte()`, `Next()`, `ParseAudioMode()` |
| `State` struct       | Done   | JSON-serializable, `DefaultState()` constructor           |
| `Config` struct      | Done   | `StateFile()`, `SocketPath()` methods                     |
| `SendCommand()`      | Done   | Shared socket client for CLI and web UI                   |
| `ParseCameraState()` | Done   | String to type-safe CameraState                           |

### emeet-pixyd — Web UI (`web/`, 1385 lines)

| Feature                | Status | Details                                              |
| ---------------------- | ------ | ---------------------------------------------------- |
| Live camera preview    | Done   | JPEG snapshot via ffmpeg, 1.5s auto-refresh          |
| MJPEG stream           | Done   | `multipart/x-mixed-replace` via ffmpeg               |
| Camera state buttons   | Done   | Track / Idle / Privacy / Toggle                      |
| Audio mode selector    | Done   | NC / Live / Original with active highlight           |
| Gesture toggle         | Done   | Visual toggle switch                                 |
| Auto mode toggle       | Done   | Visual toggle switch                                 |
| PTZ sliders            | Done   | Pan (-170 to 170), Tilt (-30 to 30), Zoom (100-400x) |
| Center button          | Done   | Resets pan/tilt/zoom                                 |
| Sync / Probe buttons   | Done   | State sync and device re-detection                   |
| HTMX interactivity     | Done   | Partial HTML swaps, no full page reloads             |
| Catppuccin Mocha theme | Done   | Dark theme matching rest of system                   |
| templ templates        | Done   | Type-safe HTML generation                            |

### emeet-pixyd — Test Suite (`main_test.go`, 812 lines)

| Feature                     | Status | Details                                                                                 |
| --------------------------- | ------ | --------------------------------------------------------------------------------------- |
| State defaults              | Done   | Validates DefaultState()                                                                |
| State save/load roundtrip   | Done   | JSON persistence                                                                        |
| Corrupt/missing state files | Done   | Graceful fallback to defaults                                                           |
| Command handling            | Done   | status, track, idle, privacy, toggle-privacy, audio, gesture, center, auto, sync, probe |
| HID response parsing        | Done   | Tracking, audio, gesture — table-driven tests                                           |
| Waybar output               | Done   | JSON validation, correct class per state                                                |
| Audio mode cycling          | Done   | NC to Live to Original to NC                                                            |
| HID byte mapping            | Done   | CameraState and AudioMode                                                               |
| Type validation             | Done   | Valid/Invalid for all types                                                             |
| `t.Parallel()`              | Done   | All tests                                                                               |
| `t.Helper()`                | Done   | All assertion helpers                                                                   |
| Explicit `sync.Mutex{}`     | Done   | All Daemon test constructors                                                            |

### emeet-pixyd — Linter Configuration (`.golangci.yml`)

| Feature                      | Status | Details                                                         |
| ---------------------------- | ------ | --------------------------------------------------------------- |
| 100+ linters enabled         | Done   | Including modernize, errcheck, errorlint, gosec, sloglint, etc. |
| Cyclomatic complexity limits | Done   | cyclop: 20, gocognit: 40, nestif: 8                             |
| Function length limits       | Done   | funlen: 80 lines, 60 statements                                 |
| Go 1.26 experiment flags     | Done   | arenas, goroutineleakprofile, jsonv2, runtimesecret, simd       |
| Formatters                   | Done   | gci, goimports, gofumpt, golines                                |

### emeet-pixyd — NixOS Integration

| Feature                    | Status | Details                                   |
| -------------------------- | ------ | ----------------------------------------- |
| udev rules                 | Done   | Device auto-detection                     |
| User systemd service       | Done   | Inherits Wayland + pipewire session env   |
| Waybar module              | Done   | Camera state indicator with click actions |
| `buildGoModule` derivation | Done   | `pkgs/emeet-pixyd.nix`                    |

---

## B. PARTIALLY DONE

### `internal/pixy/pixy.go` — Extraction Incomplete

The package was created with types and shared utilities, but:

- **main.go still re-exports everything** via type aliases (`type CameraState = pixy.CameraState`) and variable assignments (`var DefaultConfig = pixy.DefaultConfig`). This is a bridge pattern — works but is temporary.
- **HID protocol constants** (`hidByteTracking`, `cameraConfigPrefix`, etc.) are still in `main.go`, not in the shared package.
- **The web UI** (`web/client.go`) duplicates `SendCommand()` instead of importing from `internal/pixy`. It also re-declares the same timeout/buffer constants.
- **Web UI's `Status` struct** duplicates state parsing that should use `internal/pixy` types.
- **The web UI is a separate `main` package** — it cannot import the daemon's internal types directly. Needs either: (a) move web UI to be a subcommand of the daemon, or (b) make `internal/pixy` a shared library both import.

### PTZ Controls — Partial

- Sliders in web UI work but send raw values through the socket protocol
- No direct PTZ commands in the socket protocol (`v4l2Set` is called directly, not via socket)
- `ptzRange()` helper exists but is never called from handlers — sliders may send degree values instead of v4l2 units (x3600)

### Error Handling — Partial

- Sentinel errors are defined but some functions still create ad-hoc `fmt.Errorf` messages
- Error wrapping is inconsistent — some paths use `fmt.Errorf("fn: %w", err)`, some just return raw
- `errDeadline` is declared but never used

---

## C. NOT STARTED

| Item                                       | Priority | Notes                                                                 |
| ------------------------------------------ | -------- | --------------------------------------------------------------------- |
| Web UI NixOS service module                | High     | No systemd unit or Caddy vhost for the web server                     |
| Web UI authentication                      | High     | Currently bound to `127.0.0.1:8090` — no auth                         |
| `buildGoModule` update for `internal/pixy` | High     | Nix derivation needs updated `vendorHash`                             |
| Integration with Caddy reverse proxy       | Medium   | Could be exposed at `pixy.home.lan`                                   |
| WebSocket for real-time updates            | Medium   | Currently polling-based                                               |
| Web UI tests                               | Medium   | No tests for handlers, client, or templates                           |
| Daemon graceful shutdown                   | Medium   | `signal.NotifyContext` exists but no cleanup                          |
| HID protocol documentation                 | Low      | No protocol spec, only code                                           |
| Mobile-responsive improvements             | Low      | Basic responsive grid exists but PTZ panel overflows on small screens |
| Metrics/observability                      | Low      | No Prometheus metrics endpoint                                        |
| Config file support                        | Low      | All config is hardcoded constants                                     |
| Multi-camera support                       | Low      | Single device assumed throughout                                      |

---

## D. TOTALLY FUCKED UP

| Issue                                           | Severity | Details                                                                                                                   |
| ----------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| **`web/client.go` duplicates `internal/pixy`**  | High     | Same `SendCommand()`, same constants, same types — diverged copies                                                        |
| **PTZ handler doesn't convert degrees to v4l2** | High     | `handlePTZ` sends raw slider value, but v4l2 expects `degrees * 3600`. The `ptzRange()` helper exists but is NEVER CALLED |
| **Pre-commit hook + staged+unstaged same file** | Medium   | alejandra pre-commit stash conflicts when same file is staged and unstaged — requires `--no-verify`                       |
| **Go stdlib broken on macOS**                   | Medium   | Nix-provided Go 1.26 has missing stdlib packages — can't `go build` or run tests on Darwin                                |
| **Stale golangci-lint cache**                   | Low      | Reports phantom errors due to broken Go installation                                                                      |
| **~120 status reports in docs/status/**         | Low      | Massive accumulation, no archival policy, hard to find relevant info                                                      |
| **`errDeadline` unused**                        | Low      | Declared sentinel error never used anywhere                                                                               |

---

## E. WHAT WE SHOULD IMPROVE

### Architecture

1. **Eliminate `web/client.go` duplication** — Import `internal/pixy.SendCommand` and types instead of copying them. The web package and daemon should share the same client code.
2. **Complete the `internal/pixy` extraction** — Move HID constants, `queryHIDState`, `parseHIDResponse`, and all protocol logic into the shared package. Make `main.go` a thin orchestrator.
3. **Fix the PTZ degree conversion** — `handlePTZ` must call `ptzRange()` to multiply degrees by 3600 before sending to v4l2.
4. **Unify the web UI as a daemon subcommand** — Instead of a separate binary, add `emeet-pixyd web` subcommand. Eliminates the import problem entirely.

### Code Quality

5. **Remove unused `errDeadline` sentinel** — Dead code.
6. **Consistent error wrapping** — Every error return should use `fmt.Errorf` with context, not raw returns.
7. **Web UI needs tests** — 1385 lines of handler/template code with zero test coverage.

### Process

8. **Status report archival** — Move everything older than 7 days to `archive/`. 120+ reports is noise.
9. **Fix Go on macOS** — Either use system Go or fix the Nix derivation so `go build` works on Darwin.
10. **Pre-commit hook conflict** — Configure alejandra to only run on Nix files, or handle the stash conflict properly.

---

## F. TOP 25 THINGS TO DO NEXT

Sorted by impact x effort (highest first):

| #  | Task                                                                      | Impact          | Effort | Category |
| -- | ------------------------------------------------------------------------- | --------------- | ------ | -------- |
| 1  | **Fix PTZ degree-to-v4l2 conversion** — Call `ptzRange()` in `handlePTZ`  | Critical bug    | 5 min  | Bug      |
| 2  | **Update Nix `vendorHash`** for `internal/pixy` extraction                | Blocks deploy   | 10 min | Build    |
| 3  | **Eliminate `web/client.go` duplication** — Import from `internal/pixy`   | Architecture    | 30 min | Refactor |
| 4  | **Remove unused `errDeadline`**                                           | Dead code       | 2 min  | Cleanup  |
| 5  | **Add Web UI NixOS service** — systemd unit + Caddy vhost                 | Feature         | 1 hr   | NixOS    |
| 6  | **Complete `internal/pixy` extraction** — HID constants, protocol logic   | Architecture    | 2 hr   | Refactor |
| 7  | **Archive old status reports** (>7 days to `archive/`)                    | Hygiene         | 5 min  | Process  |
| 8  | **Make web UI a daemon subcommand** (`emeet-pixyd web`)                   | Architecture    | 1 hr   | Refactor |
| 9  | **Add basic web UI tests** — handler responses, status parsing            | Quality         | 2 hr   | Testing  |
| 10 | **Web UI auth** — Token-based or TLS client cert via Caddy                | Security        | 1 hr   | Security |
| 11 | **Caddy reverse proxy** — `pixy.home.lan` with TLS                        | Access          | 30 min | NixOS    |
| 12 | **WebSocket real-time updates** — Replace polling                         | UX              | 3 hr   | Feature  |
| 13 | **Daemon graceful shutdown** — Context cancellation, socket cleanup       | Reliability     | 30 min | Quality  |
| 14 | **Move `parseHIDResponse` to `internal/pixy`**                            | Architecture    | 1 hr   | Refactor |
| 15 | **Move `queryHIDState[T]` to `internal/pixy`**                            | Architecture    | 1 hr   | Refactor |
| 16 | **Consistent error wrapping audit** — Ensure all returns use `fmt.Errorf` | Quality         | 1 hr   | Quality  |
| 17 | **HID protocol documentation** — Byte-level spec in `docs/`               | Maintainability | 2 hr   | Docs     |
| 18 | **Config file support** — YAML/TOML instead of hardcoded constants        | Flexibility     | 2 hr   | Feature  |
| 19 | **Fix Go stdlib on macOS** — Nix overlay or system Go                     | Dev experience  | 1 hr   | Tooling  |
| 20 | **Mobile-responsive PTZ panel** — Collapsible on small screens            | UX              | 30 min | UI       |
| 21 | **Prometheus metrics endpoint** — Camera state, call duration, errors     | Observability   | 2 hr   | Feature  |
| 22 | **Pre-commit hook fix** — Handle staged+unstaged same-file conflict       | Dev experience  | 30 min | Tooling  |
| 23 | **Add `go generate` for templ** — Automated template regeneration         | Build           | 30 min | Build    |
| 24 | **Integration test** — Start daemon, send commands, verify responses      | Quality         | 3 hr   | Testing  |
| 25 | **Multi-camera support** — Multiple HID devices, named cameras            | Feature         | 4 hr   | Feature  |

---

## G. TOP QUESTION I CANNOT FIGURE OUT

**How should the web UI binary relate to the daemon binary?**

Three options, each with real tradeoffs:

| Option                                          | Pros                                          | Cons                                                                                            |
| ----------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **A) Subcommand** (`emeet-pixyd web`)           | Single binary, shared code, simple deployment | Increases daemon binary size, web server in same process as HID control                         |
| **B) Separate binary** importing shared package | Clean separation, independent deployment      | Must move `internal/pixy` to a non-internal package (e.g., `pkg/pixy`) for cross-package import |
| **C) Embed web in daemon** (always serve)       | Simplest, no extra config                     | Security surface — web server always running, needs auth                                        |

Currently we have **B** but with the `internal/` restriction making it impossible for `web/` to import. The `web/client.go` duplication is the symptom. This decision blocks items 3, 6, and 8 above.

---

## Session Summary

**Commits this session (6):**

| Hash      | Message                                                                         |
| --------- | ------------------------------------------------------------------------------- |
| `d80b441` | refactor(emeet-pixyd): context propagation, sentinel errors, named constants    |
| `b99577b` | fix(emeet-pixyd): setDeadline nil-wrap bug, remove unused const, fix tautology  |
| `1ba9eb1` | refactor(emeet-pixyd): replace `interface{}` queryHIDState with generics        |
| `99fa7bf` | fix(emeet-pixyd): use caller context in queryTracking and queryAudio            |
| `f8a87d7` | feat(emeet-pixyd): add web UI with live preview and PTZ controls                |
| `0db6ac6` | Refactor daemon: improve error handling, code quality, and linter configuration |

**Lines changed:** +519/-289 (refactoring) + web UI (1385 new lines)

**Current file inventory:**

| File                     | Lines    | Role                                 |
| ------------------------ | -------- | ------------------------------------ |
| `main.go`                | 1275     | Daemon core                          |
| `main_test.go`           | 812      | Test suite                           |
| `internal/pixy/pixy.go`  | 182      | Shared types (partially extracted)   |
| `web/main.go`            | 50       | HTTP server entry                    |
| `web/client.go`          | 120      | Socket client (DUPLICATED from pixy) |
| `web/handlers.go`        | 222      | HTTP handlers                        |
| `web/templates.templ`    | 465      | HTML templates                       |
| `web/templates_templ.go` | 738      | Generated templates                  |
| `.golangci.yml`          | 173      | Linter config                        |
| **Total**                | **4037** |                                      |

**Git state:** Clean working tree, master up to date with origin.
