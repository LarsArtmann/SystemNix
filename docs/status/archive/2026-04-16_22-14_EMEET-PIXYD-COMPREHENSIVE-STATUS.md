# EMEET-PIXYD — Comprehensive Status Report

**Date:** 2026-04-16 22:14 CEST
**Branch:** `master` (up to date with `origin/master` — divergence resolved!)
**Tests:** ALL PASSING — 111 tests across 2 packages (`go test ./...` — 1.5s)
**Build:** CLEAN (`go build ./...`)
**Codebase:** 5,442 lines across 8 Go files + 1 templ template
**branching-flow Quality Score:** 74.4/100 (Fair) — 10 high severity, 26 medium

---

## A) FULLY DONE

| #  | Item                                                       | Commit(s)            | Details                                                                                                                                                                                                                                                                                 |
| -- | ---------------------------------------------------------- | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | Phantom types `CameraState`/`AudioMode`                    | `c4bb97d`, `79585c4` | Moved from bare `string` to `pixy.CameraState`/`pixy.AudioMode` with `Valid()`, `Parse()`, `Next()` methods                                                                                                                                                                             |
| 2  | Error wrapping throughout daemon                           | `8aaf20a`            | All error paths now wrap with `fmt.Errorf("context: %w", err)`                                                                                                                                                                                                                          |
| 3  | Exact-root routing fix                                     | `304b70c`            | `GET /` → `GET /{$}` to prevent subtree wildcard matching ALL paths                                                                                                                                                                                                                     |
| 4  | Zero-alloc `FieldsSeq` iteration                           | `304b70c`            | `strings.Fields()` → `strings.FieldsSeq()` in hot paths                                                                                                                                                                                                                                 |
| 5  | Comprehensive integration test suite                       | Multiple             | 97 integration tests covering web routes, socket commands, status parsing, method enforcement                                                                                                                                                                                           |
| 6  | PTZ handler consolidation                                  | `bc1e9a2`            | Pan/tilt/zoom merged into single `handlePTZ` with `{axis}` path param                                                                                                                                                                                                                   |
| 7  | `requireDevice` helper extraction                          | `99cbc5b`            | Eliminates repeated device-check boilerplate                                                                                                                                                                                                                                            |
| 8  | Test daemon helpers                                        | `c4c548e`, `e0cc1fc` | `testDaemonBase`/`testDaemonNoDevice`/`testDaemonWithDevice` reduce test duplication                                                                                                                                                                                                    |
| 9  | `shortSocketDir` for macOS                                 | `304b70c`            | Unix socket paths < 104 chars using `/tmp/pxd-*`                                                                                                                                                                                                                                        |
| 10 | Full offline status format                                 | `0aa0d36`            | `getStatus()` returns all fields even when offline                                                                                                                                                                                                                                      |
| 11 | PID ancestry for camera-in-use detection                   | `f09c0dd`            | Checks `/proc/{pid}/stat` ppid chain instead of comm name                                                                                                                                                                                                                               |
| 12 | `go:fix` inline migrations                                 | `fd3954b`            | Modern Go idioms (`any` instead of `interface{}`, etc.)                                                                                                                                                                                                                                 |
| 13 | golangci-lint config consolidation                         | `304b70c`            | `.golangci.yml` with 80+ linters, proper exclusions                                                                                                                                                                                                                                     |
| 14 | `webStatus` uses typed `pixy.CameraState`/`pixy.AudioMode` | `f7f8412`            | Template struct no longer uses bare strings                                                                                                                                                                                                                                             |
| 15 | `parseWebStatus` uses typed parse functions                | `f7f8412`            | Calls `ParseCameraState`/`ParseAudioMode` instead of raw string assignment                                                                                                                                                                                                              |
| 16 | **Unit tests for `internal/pixy` package**                 | `7d46137`            | **14 table-driven tests** covering `CameraState.Valid`, `AudioMode.Valid/Next`, `ParseAudioMode` (including `org`→`original` mapping), `ParseCameraState`, `DefaultState`, `DefaultConfig`, `Config` path methods, `SetDeadline`, `SendCommand` (dial failure + end-to-end echo server) |
| 17 | **Error context in `v4l2Get`**                             | `5c48fb2`            | `v4l2Get %s on %s: %w` now includes `ctrl` and `dev` in error message                                                                                                                                                                                                                   |
| 18 | **Error context in `hidSendRecv` open**                    | `5c48fb2`            | `open hidraw %s: %w` now includes `hidrawDev` path                                                                                                                                                                                                                                      |
| 19 | **`context.Context` propagation in `SendCommand`**         | `d36271d`            | `pixy.SendCommand` now accepts `ctx context.Context` as first parameter, propagates to `DialContext` instead of `context.Background()`                                                                                                                                                  |
| 20 | **PTZ constants extraction**                               | `24d892f`            | Magic strings/numbers extracted to `ptzAxisPan`/`ptzTilt`/`ptzZoom`, `ptzPanMin`/`ptzPanMax`/etc., `inCallYes`                                                                                                                                                                          |
| 21 | **Variable naming improvements**                           | `24d892f`            | `ok` → `hasDevice`, `ok` → `flushOk` in handlers for clarity                                                                                                                                                                                                                            |
| 22 | **Type-safe CameraState/AudioMode in webStatus**           | `f7f8412`            | `webStatus.Camera` is now `pixy.CameraState`, `webStatus.Audio` is `pixy.AudioMode`                                                                                                                                                                                                     |
| 23 | **Command handler extraction**                             | `9c62a31`            | Extracted `handleTrack`, `handleIdle`, `handlePrivacy`, `handleTogglePrivacy`, `handleAudio`, `handleGesture`, `handleCenter`, `handlePTZCommand`, `handleDevice` from the monolith switch                                                                                              |
| 24 | **Auto-on/auto-off consolidation**                         | `aabec84`            | Merged `auto-on`/`auto-off` into `handleAuto` with bool param, DRY'd test assertions                                                                                                                                                                                                    |
| 25 | **Response constants**                                     | `9c62a31`            | Centralized magic response strings: `responseTrackingOn`, `responseAutoOn`, etc.                                                                                                                                                                                                        |
| 26 | **Git divergence resolved**                                | Rebase + push        | Previous corrupt remote commits (`79585c4`, `38bdc1b`) were properly resolved — local now matches remote                                                                                                                                                                                |

---

## B) PARTIALLY DONE

| # | Item                       | Status                                                | What's Missing                                                                                                                                                          |
| - | -------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | Error context in HID paths | Open error fixed (`5c48fb2`), write error has context | `hidSend` errors at lines 296, 316 still missing `hidrawDev` context per branching-flow. `queryHIDState` at lines 566, 573, 579, 586 has 4 high-severity context losses |
| 2 | Streaming MJPEG handler    | Works, monolithic                                     | `extractJPEGFrame` is unexported, untestable, lives in `handlers.go` alongside HTTP logic                                                                               |
| 3 | Command registry pattern   | Handlers extracted to named functions                 | Still dispatched from `handleCommand` switch — not yet a `map[string]handlerFunc` registry                                                                              |

---

## C) NOT STARTED

| #  | Item                                            | Impact | Effort | Notes                                                                                            |
| -- | ----------------------------------------------- | ------ | ------ | ------------------------------------------------------------------------------------------------ |
| 1  | Move `webStatus` to `internal/pixy`             | Medium | 10min  | Struct currently lives in `templates.templ` — should be canonical in shared package              |
| 2  | `sync.RWMutex` for status reads                 | Medium | 5min   | `getWebStatus()`, `getWebStatusWithPTZ()` only read state — `sync.Mutex` blocks concurrent reads |
| 3  | `errors.Is`/`errors.As` support                 | Medium | 5min   | Sentinel errors exist but callers use string matching                                            |
| 4  | `String()` methods on `CameraState`/`AudioMode` | Low    | 3min   | Go best practice for fmt printing                                                                |
| 5  | Move `WaybarOutput` to `State` struct           | Low    | 5min   | Method belongs on data type, not daemon                                                          |
| 6  | Bool→string helpers for `getStatus()`           | Low    | 5min   | Repeated `inCallStr`/`autoStr` pattern                                                           |
| 7  | Extract `Debouncer` type from `autoManage`      | Low    | 8min   | Debounce counter logic is inline in daemon                                                       |
| 8  | HTTP request timeout middleware                 | Low    | 3min   | No request-level timeout on web server                                                           |
| 9  | Graceful shutdown in `listenUnix`               | Medium | 8min   | Accept loop doesn't respect context for shutdown                                                 |
| 10 | Brand `SourceID` type for PipeWire              | Low    | 10min  | `string` used for PipeWire source IDs — branching-flow flags 1 strong-id violation               |
| 11 | Brand `PID` type for process IDs                | Low    | 5min   | `int` used for PIDs — branching-flow flags 2 strong-id violations                                |
| 12 | Update `README.md`                              | Low    | 8min   | Currently placeholder ("A Go project.")                                                          |
| 13 | Update `CHANGELOG.md`                           | Low    | 5min   | Not tracking recent improvements                                                                 |
| 14 | CI pipeline (`.github/workflows/ci.yml`)        | High   | 15min  | No CI — broken formatting was pushed to master in the past                                       |
| 15 | `go vet` + `staticcheck` in pre-commit          | Medium | 5min   | Quality gate missing                                                                             |
| 16 | Table-driven tests for `handleCommand`          | Medium | 10min  | Test all commands systematically                                                                 |
| 17 | Fuzz test `parseWebStatus`                      | Low    | 8min   | Exercise with random input                                                                       |
| 18 | Add `-version` flag to CLI                      | Low    | 3min   | Standard daemon feature                                                                          |
| 19 | Fix remaining branching-flow context losses     | High   | 15min  | 10 high-severity: `hidSend`/`queryHIDState` missing `hidrawDev` context                          |
| 20 | Phantom types for string parameters             | Low    | 20min  | branching-flow found 52 violations (27 critical) — command strings, device paths, etc.           |

---

## D) TOTALLY FUCKED UP

| # | Item                                     | What Happened                                                           | Current State                                           | Root Cause                                                           |
| - | ---------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------- |
| 1 | ~~Remote commits `79585c4` + `38bdc1b`~~ | ~~`handlers.go` and `integration_test.go` reformatted to single lines~~ | **RESOLVED** — local matches remote, clean working tree | Automated formatter ran without verification; no CI gate to catch it |

**Previous session's #1 critical issue is now resolved.** The corrupt commits have been properly rebased/merged. `git status` shows clean tree, local and remote are in sync.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **`internal/pixy` error context** — branching-flow scores `sendCommand` errors at 80/100 (lost socketPath/cmd context). Wrap: `fmt.Errorf("sendCommand dial %s for %q: %w", socketPath, cmd, err)`.
2. **`queryHIDState` error quality** — branching-flow scores 30-60/100 on lines 566-586. The function loses `hidrawDev`, `extract`, and `zero` context across multiple error paths. This is the lowest-scoring function in the codebase.
3. **`webStatus` struct location** — defined in `templates.templ` (line 9), used in `handlers.go`. Should be in `internal/pixy` for canonical definition shared by both packages.
4. **`sync.Mutex` → `sync.RWMutex`** — status reads (`getWebStatus`, `getWebStatusWithPTZ`) are read-only but block each other under `sync.Mutex`.

### Quality Gates

5. **No CI pipeline** — broken formatting was pushed to master in the past. A simple `gofmt -d . && go test ./...` gate in `.github/workflows/ci.yml` would prevent this.
6. **`README.md` is placeholder** — says "A Go project." with `go get github.com/username/.`. Should describe the daemon's purpose, architecture, and usage.

### branching-flow Findings

7. **10 high-severity context losses** — all in `main.go`, all related to `hidrawDev` variable being lost in error wrapping. Functions: `hidSend` (2), `hidSendRecv` (4), `queryHIDState` (4).
8. **26 medium-severity context losses** — `sendCommand` losing `socketPath`/`cmd`, `setDeviceState` losing `setter`, `SetDeadline` losing `timeout`.
9. **52 phantom type violations** (27 critical) — bare `string` used for command names, device paths, mode names, axis names. Most are in test code and internal switch statements.
10. **3 strong-id violations** (low) — `PID` as `int` (×2), `SourceID` as `string` (×1).
11. **1 bool-blindness violation** (medium) — `webStatus` has 4 bool fields that could be bitflags.

---

## F) Top 25 Next Actions (Sorted by Impact/Effort)

| Priority | Task                                                                                        | Impact | Effort | Category     |
| -------- | ------------------------------------------------------------------------------------------- | ------ | ------ | ------------ |
| 1        | **Fix `queryHIDState` error context** — wrap with `hidrawDev` at lines 566-586              | High   | 5min   | Errors       |
| 2        | **Fix `hidSend` error context** — wrap with `hidrawDev` at lines 296, 316                   | High   | 3min   | Errors       |
| 3        | **Add `.github/workflows/ci.yml`** — gofmt + test + lint on push                            | High   | 15min  | CI           |
| 4        | **Replace `sync.Mutex` with `sync.RWMutex`** for status reads                               | Medium | 5min   | Performance  |
| 5        | **Move `webStatus` to `internal/pixy`** — canonical struct definition                       | Medium | 10min  | Types        |
| 6        | **Fix `SendCommand` error wrapping** — include `socketPath`/`cmd` in dial/write/read errors | Medium | 5min   | Errors       |
| 7        | **Add `String()` methods** to `CameraState`/`AudioMode`                                     | Low    | 3min   | Types        |
| 8        | **Bool→string helpers** for `getStatus()` (`inCallStr`/`autoStr`)                           | Low    | 5min   | Cleanup      |
| 9        | **Move `WaybarOutput`** method from `Daemon` to `State`                                     | Low    | 5min   | Architecture |
| 10       | **Graceful shutdown** in `listenUnix` accept loop                                           | Medium | 8min   | Robustness   |
| 11       | **HTTP request timeout middleware** for web server                                          | Low    | 3min   | Robustness   |
| 12       | **Extract `Debouncer` type** from `autoManage` debounce logic                               | Low    | 8min   | Architecture |
| 13       | **Extract `extractJPEGFrame`** to `internal/pixy` for testability                           | Medium | 8min   | Architecture |
| 14       | **Deduplicate `getStatus()` / `getWebStatus()`** logic                                      | Medium | 8min   | Cleanup      |
| 15       | **Convert command registry** from switch to `map[string]handlerFunc`                        | Medium | 12min  | Architecture |
| 16       | **Add `errors.Is` support** for sentinel error checking                                     | Medium | 5min   | Errors       |
| 17       | **Brand `SourceID` type** for PipeWire source IDs                                           | Low    | 10min  | Types        |
| 18       | **Brand `PID` type** for process IDs                                                        | Low    | 5min   | Types        |
| 19       | **Update `README.md`** with actual project description                                      | Low    | 8min   | Docs         |
| 20       | **Update `CHANGELOG.md`** with recent improvements                                          | Low    | 5min   | Docs         |
| 21       | **Add `go vet` + `staticcheck`** to pre-commit hooks                                        | Medium | 5min   | Quality      |
| 22       | **Table-driven tests for `handleCommand`** — test all commands systematically               | Medium | 10min  | Tests        |
| 23       | **Fuzz test `parseWebStatus`** — exercise with random input                                 | Low    | 8min   | Tests        |
| 24       | **Add `-version` flag** to CLI                                                              | Low    | 3min   | UX           |
| 25       | **Fix remaining branching-flow phantom type violations**                                    | Low    | 20min  | Types        |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Should the `webStatus` struct move to `internal/pixy` or stay in `templates.templ`?**

Moving it to `internal/pixy` makes it the canonical definition shared by `handlers.go` and the template. But it means `templates.templ` must import from `internal/pixy`, and `templ generate` needs to be re-run. The struct currently has 4 bool fields that branching-flow flags as "bool-blindness" — should we also convert to bitflags at the same time?

This is an architectural decision: keep the template self-contained (current pattern) vs. centralize the type definition (cleaner for shared use). I recommend moving it but want confirmation before touching the templ-generated code.

---

## Session Summary

**Previous session** (ending ~20:51): Analysis only. Identified all improvements, wrote status report.

**This session** (starting ~20:51): Executed 8 commits with real improvements:

1. `24d892f` — Extract PTZ constants, improve variable naming
2. `a378105` — Add `*.tmp` to `.gitignore`
3. `7d46137` — **14 unit tests** for `internal/pixy` package (was 0)
4. `5c48fb2` — Fix `v4l2Get` + `hidSendRecv` error context
5. `f7f8412` — Type-safe `CameraState`/`AudioMode` in `webStatus`
6. `d36271d` — `context.Context` propagation in `SendCommand`
7. `aabec84` — Consolidate auto-on/auto-off handlers, DRY test assertions
8. `9c62a31` — Extract command handlers, centralize response constants

**Net delta:** +567 lines, −257 lines. Test count: ~97 → 111. All passing.
