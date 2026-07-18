# EMEET-PIXYD — Comprehensive Status Report

**Date:** 2026-04-16 20:51 CEST
**Branch:** `master` (up to date with `origin/master` after fixing corrupted remote commits)
**Tests:** ALL PASSING (`go test ./...` — 1.456s)
**Build:** CLEAN (`go build ./...`)
**Codebase:** ~3,800 lines across 5 Go files + 1 templ template

---

## A) FULLY DONE

| Item                                                                 | Commit(s)                       | Details                                                                                                     |
| -------------------------------------------------------------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Phantom types `CameraState`/`AudioMode`                              | `c4bb97d`, `79585c4`            | Moved from bare `string` to `pixy.CameraState`/`pixy.AudioMode` with `Valid()`, `Parse()`, `Next()` methods |
| Error wrapping throughout daemon                                     | `8aaf20a`                       | All error paths now wrap with `fmt.Errorf("context: %w", err)`                                              |
| Exact-root routing fix                                               | `304b70c`                       | `GET /` → `GET /{$}` to prevent subtree wildcard matching ALL paths                                         |
| Zero-alloc `FieldsSeq` iteration                                     | `304b70c`                       | `strings.Fields()` → `strings.FieldsSeq()` in hot paths                                                     |
| Comprehensive integration test suite                                 | `ccb01cd`, `304b70c`, `0aa0d36` | 40+ integration tests covering web routes, socket commands, status parsing, method enforcement              |
| PTZ handler consolidation                                            | `bc1e9a2`                       | Pan/tilt/zoom merged into single `handlePTZ` with `{axis}` path param                                       |
| `requireDevice` helper extraction                                    | `99cbc5b`                       | Eliminates repeated device-check boilerplate                                                                |
| `testDaemonBase`/`testDaemonNoDevice`/`testDaemonWithDevice` helpers | `c4c548e`, `e0cc1fc`            | Reduces test daemon construction duplication                                                                |
| `shortSocketDir` for macOS                                           | `304b70c`                       | Unix socket paths < 104 chars using `/tmp/pxd-*`                                                            |
| Full offline status format                                           | `0aa0d36`                       | `getStatus()` returns all fields even when offline                                                          |
| PID ancestry for camera-in-use detection                             | `f09c0dd`                       | Checks `/proc/{pid}/stat` ppid chain instead of comm name                                                   |
| `go:fix` inline migrations                                           | `fd3954b`                       | Modern Go idioms (`any` instead of `interface{}`, etc.)                                                     |
| golangci-lint config consolidation                                   | `304b70c`                       | `.golangci.yaml` → `.golangci.yml` with 80+ linters, proper exclusions                                      |
| `webStatus` uses typed `pixy.CameraState`/`pixy.AudioMode`           | `79585c4`                       | Template struct no longer uses bare strings                                                                 |
| `parseWebStatus` uses typed parse functions                          | `79585c4`                       | Calls `ParseCameraState`/`ParseAudioMode` instead of raw string assignment                                  |

---

## B) PARTIALLY DONE

| Item                       | Status                                       | What's Missing                                                                                                               |
| -------------------------- | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `internal/pixy` package    | Types extracted, `SendCommand` moved         | **Zero test files** — `ParseAudioMode`, `ParseCameraState`, `Next()`, `Valid()`, `SendCommand` all untested at package level |
| Error context in HID paths | `hidSend` has context, `requireDevice` wraps | `hidSendRecv` open error (`main.go:332`) missing `hidrawDev` context; `v4l2Get` (`main.go:429`) missing `dev`/`ctrl` context |
| Streaming MJPEG handler    | Works but monolithic                         | `extractJPEGFrame` is unexported, untestable, lives in `handlers.go` alongside HTTP logic                                    |

---

## C) NOT STARTED

| Item                                                                    | Impact | Effort |
| ----------------------------------------------------------------------- | ------ | ------ |
| Unit tests for `internal/pixy` package                                  | High   | 10min  |
| Move `webStatus` to `internal/pixy` (eliminate template-level struct)   | Medium | 10min  |
| Command registry pattern (replace 140-line `handleCommand` switch)      | Medium | 12min  |
| `sync.RWMutex` for status reads                                         | Medium | 5min   |
| `context.Context` propagation in `sendCommand`                          | Medium | 3min   |
| `errors.Is`/`errors.As` support for sentinel errors                     | Medium | 5min   |
| `String()` methods on `CameraState`/`AudioMode`                         | Low    | 5min   |
| Move `WaybarOutput` to `State` struct                                   | Low    | 5min   |
| `getStatus()` helper for bool→string conversion (`inCallStr`/`autoStr`) | Low    | 5min   |
| Extract `Debouncer` type from `autoManage`                              | Low    | 8min   |
| HTTP request timeout middleware                                         | Low    | 3min   |
| Graceful shutdown in `listenUnix` (context-aware accept)                | Medium | 8min   |
| Brand `SourceID` type for PipeWire                                      | Low    | 10min  |
| Update `README.md` (currently placeholder)                              | Low    | 8min   |
| Update `CHANGELOG.md`                                                   | Low    | 5min   |
| CI pipeline (golangci-lint + test on push)                              | High   | 15min  |

---

## D) TOTALLY FUCKED UP

| Item                                 | What Happened                                                                                                                          | Root Cause                                                      | Fix Applied                                                                                                                                               |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Remote commits `79585c4` + `38bdc1b` | `handlers.go` and `integration_test.go` reformatted to **single lines** — `package mainimport (` instead of `package main\n\nimport (` | Likely automated formatter run without verification; no CI gate | Restored from `c4bb97d` (last known-good commit). **This WILL break again on next pull unless remote is force-pushed or the 2 bad commits are reverted.** |

---

## E) WHAT WE SHOULD IMPROVE

1. **No CI** — broken formatting was pushed to master and not caught. A simple `gofmt -d . && go test ./...` gate would prevent this.
2. **`internal/pixy/pixy.go` has zero tests** — this is the shared types package. `ParseAudioMode("org")` → `AudioOriginal` is only tested transitively via `main_test.go`.
3. **`getStatus()` and `getWebStatus()` duplicate logic** — both build status representations but with different structures and formats.
4. **`handleCommand` is a 140-line switch** — every new command requires editing this monolith. A command registry (map of name→handler) would be cleaner and testable in isolation.
5. **`sync.Mutex` used everywhere** — status reads (`getWebStatus`, `getWebStatusWithPTZ`) only read state. `sync.RWMutex` would allow concurrent reads.
6. **`sendCommand` ignores `context.Context`** — callers pass context but it's dropped in favor of `context.Background()`. Timeout/cancellation doesn't propagate.
7. **No graceful shutdown in `listenUnix`** — the accept loop doesn't respect the context parameter (only used for `net.ListenConfig`).
8. **`README.md` is a placeholder** — says "A Go project." with `go get github.com/username/.`.
9. **`webStatus` struct lives in `templates.templ`** — it should be in `internal/pixy` so both `handlers.go` and the template share the canonical definition.
10. **Remote branch has corrupt formatting** — commits `79585c4` and `38bdc1b` on origin/master will re-break files on any fresh clone or pull.

---

## F) Top 25 Next Actions (Sorted by Impact/Effort)

| Priority | Task                                                                                   | Impact   | Effort | Category     |
| -------- | -------------------------------------------------------------------------------------- | -------- | ------ | ------------ |
| 1        | **Fix/revert corrupt remote commits** `79585c4`+`38bdc1b` on origin                    | Critical | 2min   | Bug          |
| 2        | **Add `internal/pixy/pixy_test.go`** — unit tests for all exported functions           | High     | 10min  | Tests        |
| 3        | **Fix `v4l2Get` error context** — wrap with `dev` and `ctrl` (`main.go:429`)           | High     | 3min   | Errors       |
| 4        | **Fix `hidSendRecv` error context** — wrap open error with `hidrawDev` (`main.go:332`) | High     | 3min   | Errors       |
| 5        | **Propagate `context.Context` in `sendCommand`** instead of `context.Background()`     | Medium   | 3min   | Correctness  |
| 6        | **Replace `sync.Mutex` with `sync.RWMutex`** for status reads                          | Medium   | 5min   | Performance  |
| 7        | **Move `webStatus` to `internal/pixy`** — canonical struct definition                  | Medium   | 10min  | Types        |
| 8        | **Extract command registry** from `handleCommand` switch                               | Medium   | 12min  | Architecture |
| 9        | **Add graceful shutdown** to `listenUnix` accept loop                                  | Medium   | 8min   | Robustness   |
| 10       | **Extract `extractJPEGFrame`** to `internal/pixy` for testability                      | Medium   | 8min   | Architecture |
| 11       | **Add `errors.Is` support** for sentinel errors                                        | Medium   | 5min   | Errors       |
| 12       | **Deduplicate `getStatus()` / `getWebStatus()`** logic                                 | Medium   | 8min   | Cleanup      |
| 13       | **Add `String()` methods** to `CameraState`/`AudioMode`                                | Low      | 5min   | Types        |
| 14       | **Bool→string helpers** for `getStatus()` (`inCallStr`/`autoStr`)                      | Low      | 5min   | Cleanup      |
| 15       | **Move `WaybarOutput`** method from `Daemon` to `State`                                | Low      | 5min   | Architecture |
| 16       | **Extract `Debouncer` type** from `autoManage` debounce logic                          | Low      | 8min   | Architecture |
| 17       | **HTTP request timeout middleware** for web server                                     | Low      | 3min   | Robustness   |
| 18       | **Brand `SourceID` type** for PipeWire source IDs                                      | Low      | 10min  | Types        |
| 19       | **Update `README.md`** with actual project description                                 | Low      | 8min   | Docs         |
| 20       | **Update `CHANGELOG.md`** with recent improvements                                     | Low      | 5min   | Docs         |
| 21       | **Add `.github/workflows/ci.yml`** — gofmt + test + lint on push                       | High     | 15min  | CI           |
| 22       | **Add `go vet` + `staticcheck`** to pre-commit hooks                                   | Medium   | 5min   | Quality      |
| 23       | **Table-driven tests for `handleCommand`** — test all commands systematically          | Medium   | 10min  | Tests        |
| 24       | **Fuzz test `parseWebStatus`** — exercise with random input                            | Low      | 8min   | Tests        |
| 25       | **Add `-version` flag** to CLI                                                         | Low      | 3min   | UX           |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Should I force-push to `origin/master` to remove the 2 corrupt commits (`79585c4`, `38bdc1b`) that break `handlers.go` and `integration_test.go` formatting?**

The current local state is clean (restored from `c4bb97d`), but any future `git pull` will re-apply the corruption. Options:

- `git push --force-with-lease` to overwrite the bad commits
- Revert them formally (`git revert 79585c4 38bdc1b`)
- Do nothing and just keep fixing locally

This is a governance decision I cannot make autonomously — it affects the shared remote history.
