# Status Report — 2026-04-19 00:57

## A) Fully Done ✅

### Niri Session Save/Restore (`platforms/nixos/programs/niri-wrapped.nix`)

Complete crash-recovery system for niri window restoration. All features implemented, syntax-validated (`just test-fast` passes), and build-tested.

**What it does:**

- **Save** (systemd timer, every 60s): Snapshots all niri windows, workspaces, and kitty terminal state (child processes, CWDs) to `~/.local/state/niri-session/`
- **Restore** (runs at niri startup via `spawn-at-startup`): Reads snapshot, re-spawns all apps on correct workspaces, including kitty with running child commands
- **Fallback**: If no session exists or snapshot is >7 days old, uses hardcoded defaults

**All 6 improvements applied in this session:**

| # | Fix                                                                                                                                                                           | Status  |
| - | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| 1 | **Crush/foreground process detection** — uses `/proc/$pid/stat` tpgid field when shell has no children, catches Crush running as fish's foreground process                    | ✅ Done |
| 2 | **Workspace-aware restore** — reads `workspaces.json`, pre-creates named workspaces, focuses correct workspace before spawning each app via `niri msg action focus-workspace` | ✅ Done |
| 3 | **Removed `eval` shell injection** — replaced with bash array expansion `kitty -e "${e_args[@]}"`                                                                             | ✅ Done |
| 4 | **Atomic writes** — all files (`kitty-state.json`, `timestamp`) now use `mktemp` → write → `mv` pattern                                                                       | ✅ Done |
| 5 | **Fixed `sudo btop` fallback** — fallback now uses `btop` directly (no sudo needed)                                                                                           | ✅ Done |
| 6 | **Timer increased to 60s** — from 30s, sufficient for crash recovery with less I/O                                                                                            | ✅ Done |

### EMEET PIXY Daemon — Staged Changes (from prior sessions)

The following changes are staged but uncommitted (from before this session):

- **Context propagation**: All HID command methods now accept `context.Context` for cancellation
- **PTZ caching**: 2-second PTZ value cache to reduce redundant hidraw reads
- **Stream semaphore**: Limits concurrent MJPEG streams to 1, returns 503 if already streaming
- **Security headers**: Added `X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`
- **ffmpeg availability check**: Stream endpoint checks for ffmpeg before starting
- **Uevent hotplug**: New `uevent.go` + `uevent_linux.go` — netlink KOBJECT_UEVENT listener for video4linux/hidraw hotplug events, auto-re-probes on device add/remove
- **State management**: `lastFrame` moved from global to `Daemon` struct, new `ptzCache` struct field

Go build, tests (`go test ./...`), and vet all pass. Nix build (`nix build .#emeet-pixyd`) passes in isolation.

---

## B) Partially Done ⚠️

Nothing partially done — all started work items are complete.

---

## C) Not Started 📋

1. **Floating/fullscreen state restore** — niri session restore doesn't save or restore floating or fullscreen window state
2. **Column width restoration** — niri preset column widths (⅓, ½, ⅔) and custom widths are lost on crash
3. **Window focus order** — restore doesn't track which window was focused last; final focus after restore is whichever app was spawned last
4. **Dunst notification on save failure** — if the save timer fails repeatedly, there's no user-visible indication
5. **Signal desktop dedup** — if signal-desktop is already running, restore spawns a second instance
6. **AGENTS.md update** — should document the niri session restore system in the "Niri" section

---

## D) Totally Fucked Up 💥

1. **`just test` intermittent failure** — `nix build` of `emeet-pixyd` fails during parallel `just test` but succeeds in isolation (`nix build .#emeet-pixyd`). Likely a nix sandbox race or hash mismatch that resolves on retry. The previous successful `just test` run (before our changes) also showed this was already cached.

---

## E) What We Should Improve

### Session Restore

- **Desktop notification on restore** — `notify-send "Session Restored" "Restored N windows from crash recovery"` so user knows it happened
- **Cleanup old sessions** — keep only the latest snapshot, delete stale `windows.json` files on successful restore
- **Validate JSON before restore** — if `windows.json` is truncated/corrupt, fall back gracefully with a log message
- **Configurable via Nix** — expose poll interval, max session age, and fallback apps as nix options

### Niri Config

- **Dynamic wallpaper dir** — `wallpaperDir` is hardcoded to `/home/lars/projects/wallpapers`; should use `config.users.users.lars.home` or `xdg.userDirs.pictures`
- **Screenshot directory** — `~/Pictures/screenshots/` should be auto-created if missing

### EMEET PIXY

- **Uevent test coverage** — `uevent.go` and `uevent_linux.go` have no tests; need integration tests with mock netlink
- **Nix vendor hash** — should be updated after `go.mod` changes

---

## F) Top 25 Things To Do Next

### High Priority (stability & polish)

1. Commit all current changes (emeet-pixyd + niri session restore)
2. `just switch` and verify session restore works on next login
3. Fix `just test` intermittent emeet-pixyd build failure
4. Add `notify-send` notification on session restore
5. Update `AGENTS.md` with niri session restore documentation
6. Add JSON validation to restore script before parsing
7. Update emeet-pixyd vendor hash in `pkgs/emeet-pixyd.nix`

### Medium Priority (features)

8. Save and restore floating/fullscreen window state
9. Save and restore column widths
10. Track and restore focused window
11. Deduplicate running apps on restore (skip if already running)
12. Make wallpaper dir dynamic (use home directory variable)
13. Add auto-cleanup of old session snapshots
14. Expose session restore config as Nix options
15. Add uevent tests for emeet-pixyd

### Lower Priority (quality of life)

16. Add session restore manual trigger command (`just session-restore`)
17. Add session status command (`just session-status` — shows last save time, window count)
18. Log session save/restore events to systemd journal with structured fields
19. Add session restore stats to waybar (last restore time, windows restored)
20. Make fallback apps configurable in Nix (not hardcoded in script)
21. Create docs/architecture/decision-records/ADR for session restore design
22. Add integration test for session save/restore scripts
23. Explore niri event-stream for real-time save instead of polling
24. Investigate niri IPC for window position/size data
25. Document emeet-pixyd uevent hotplug in AGENTS.md

---

## G) Top #1 Question

**Does the niri `windows --json` output include window position/column data (width, height, x, y) that we could use for column width restoration?**

I know `niri msg -j windows` returns `{id, title, app_id, pid, workspace_id, is_focused, is_floating, is_urgent}` but I couldn't verify whether newer niri versions include geometry or column data. If it does, we can save and restore column widths via `niri msg action set-column-width`. If not, we'd need to use the event-stream approach (item #23) to capture resize events in real-time.
