# 2026-08-11 WDT Crash — Browser History Crash Loop

## Crash Summary

**Boot -1** (11:18–13:26 CEST) ended with a hard WDT reset. ~2h uptime.
Root cause: **uncontrolled crash loops** in browser-history server + agent generated
cascading memory/IO pressure that froze the kernel.

## Root Cause Chain

1. **browser-history.server crash-loops** — `Error: server.create_user_service`
   (exit 69). Upstream bug: `usermgmt.NewService()` → `NewEventSourcedSetup()` →
   `startProjectionHost()` fails during projection replay. Began after cqrs-htmx
   v4.7.2 bump (commit `c63f118`, Aug 10). The error cause is hidden by
   `errorfamily.HandleError`'s CLI renderer (prints surface code + family default
   message, NOT the `.Cause()` chain). Server restart counter was at **160+**
   in boot -1.
2. **browser-history-agent crash-loops** — `Type=oneshot`, `Restart=on-failure`,
   restarts every ~18s when server unreachable (502). Each spawn reads **19,700
   browser entries** from SQLite (helium: 19035, firefox: 696). **72 failures**
   logged in boot -1.
3. Both loops burned CPU, memory, and IO continuously.
4. System-wide memory pressure hit **95%** (Monitor365 buffer warnings,
   `systemd-journald: Under memory pressure, flushing caches`).
5. Kernel freeze → **sp5100-tco WDT reset**. No OOM-kill, no panic logged —
   page-cache pressure, not anonymous memory.
6. Same pattern as 2026-08-09 PMA crash-loop crash.

## Fixes Applied

### SystemNix: browser-history.nix — crash-loop backoff

- **Server**: `RestartSec = 2min`, `StartLimitBurst = 3`, `StartLimitIntervalSec = 600`
  (was 5s / 3 / 300s from upstream module). Added `LOG_LEVEL=debug` for diagnosis.
- **Agent**: `RestartSec = 5min`, `StartLimitBurst = 2`, `StartLimitIntervalSec = 1800`
  (was 10s / 3 / 300s). Confirmed health gate (`ExecStartPre`) present in eval
  (was absent from STALE deployed unit — config was never deployed after the
  co-located ordering block was added).

### SystemNix: pre-deploy-check.sh — phantom metric allowlist

- Added `niri_running` and `system_memory_events_any_high` to
  `KNOWN_NEW_METRICS`. Both are absent immediately after reboot (emitting
  services haven't run yet) but appear within minutes.

### Pending (BLOCKED)

- **Upstream fix**: `server.create_user_service` root cause not yet identified.
  Error renderer hides the `.Cause()` chain. Debug logging added to
  `cmd/browser-history-server/main.go` (`logger.Error` before `HandleError`)
  but not yet built/pushed (go.work broken locally). The cqrs-htmx v4.7.2 bump
  likely changed projection error handling for unknown event types during
  journal replay (shared SQLite event store contains browser visit events that
  usermgmt projections may not handle).
- **Upstream go-cqrs-lite**: cqrs-lint vendorHash updated and committed but
  **push failed** (pre-commit CI pipeline rejected — 3 workflow steps failed).
  This blocks the SystemNix flake input update → blocks deploy.
- **Deploy**: BLOCKED on go-cqrs-lite push. Once unblocked:
  1. Push go-cqrs-lite
  2. `nix flake update go-cqrs-lite`
  3. `nix run .#deploy`
  4. Watch server debug logs for the actual error cause

## Remaining Work

1. ~~Push go-cqrs-lite vendorHash fix~~ done (fix pre-commit CI failures)
2. ~~Update SystemNix flake input for go-cqrs-lite~~ done
3. ~~Deploy SystemNix crash-loop backoff~~ done at `a941f88d`
4. ~~Debug server crash from LOG_LEVEL=debug output~~ done (root-caused to SQLite DSN mismatch)
5. ~~Fix upstream browser-history crash~~ done at `a1223f22`
6. Add system-wide crash-loop circuit breaker
7. Update AGENTS.md with this incident
