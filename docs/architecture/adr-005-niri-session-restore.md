# ADR-005: Niri Session Save/Restore Design

## Status

**Accepted** - Revisit if niri gains native session management

## Date

2026-04-26

## Context

### Problem Statement

Niri (scrollable-tiling Wayland compositor) does not persist window/workspace state across restarts. When niri crashes or the system reboots, all window positions, workspace assignments, and floating state are lost. Users must manually reopen and reposition every application.

### Alternatives Considered

| Approach                        | Pros                                            | Cons                                                            |
| ------------------------------- | ----------------------------------------------- | --------------------------------------------------------------- |
| **Periodic snapshots (chosen)** | Simple, predictable, no event-stream dependency | Up to N seconds of data loss (configurable interval)            |
| **Real-time event listener**    | Zero data loss                                  | Requires parsing niri event-stream; fragile if listener crashes |
| **Manual save/restore only**    | No background overhead                          | User must remember to save; useless for crash recovery          |
| **Desktop file session**        | Standard XDG approach                           | Doesn't capture runtime state (floating, column widths, focus)  |

## Decision

Implement periodic snapshot-based session save/restore using systemd timer + niri IPC.

### Architecture

**Save** (systemd timer, default 60s interval):

1. Snapshot `niri msg -j windows` → `windows.json` (app_id, pid, workspace_id, is_floating, tile_size, focus_timestamp)
2. Snapshot `niri msg -j workspaces` → `workspaces.json` (workspace names + IDs)
3. Walk `/proc` tree for each kitty window → `kitty-state.json` (PID, args, CWD, child process)
4. Write `timestamp` file with current epoch

**Restore** (runs at niri startup via `spawn-at-startup`):

1. Validate all JSON files (graceful fallback if corrupt)
2. Check session age — if >7 days, use hardcoded fallback apps
3. Pre-create named workspaces from snapshot
4. Spawn each app on correct workspace via `niri msg action spawn-at-focused`
5. Restore floating state via `niri msg action move-window-to-floating`
6. Restore column widths via `SetColumnWidth` (proportion from tile_size / output_width)
7. Re-focus last-active window using focus_timestamp
8. Skip already-running non-kitty apps (dedup via pgrep)

### Configuration

All parameters are NixOS module options:

| Option                | Default        | Description                        |
| --------------------- | -------------- | ---------------------------------- |
| `sessionSaveInterval` | `"60s"`        | systemd timer interval             |
| `maxSessionAgeDays`   | `7`            | Max age before fallback            |
| `fallbackApps`        | hardcoded list | Apps to launch if no valid session |

### State Storage

```
~/.local/state/niri-session/
├── windows.json      # Window metadata from niri IPC
├── workspaces.json   # Workspace names and IDs
├── kitty-state.json  # Per-kitty: PID, args, CWD, child process
└── timestamp         # Epoch seconds of last save
```

## Consequences

### Positive

- Crash recovery: windows restored automatically after niri restart
- Workspace-aware: apps return to correct virtual desktop
- Preserves floating state and column widths
- Deduplication prevents duplicate windows
- JSON validation prevents corrupt state from breaking restore
- Configurable via NixOS module options
- Fallback for stale sessions (>7 days)

### Negative

- Up to 60s data loss window (configurable)
- Kitty terminal state recovery depends on `/proc` tree walking
- Non-kitty apps restored without internal state (just relaunched)
- Save timer runs continuously (minimal overhead)

### Risks

- niri IPC changes could break window/workspace queries (mitigated by JSON validation)
- `/proc` tree structure varies by kernel version
- Restore race condition if apps start too fast (mitigated by deduplication)
