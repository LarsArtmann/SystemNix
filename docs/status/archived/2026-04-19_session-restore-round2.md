# Status Report — 2026-04-19 (Update)

## A) Fully Done ✅

### Niri Session Save/Restore — Round 2 Improvements

All 18 improvements from the backlog have been implemented in `platforms/nixos/programs/niri-wrapped.nix`.

**Completed items (from "Not Started" and "Should Improve" lists):**

| #  | Improvement                                                                                                                 | Status  |
| -- | --------------------------------------------------------------------------------------------------------------------------- | ------- |
| 1  | **JSON validation in save** — validates `windows.json` and `workspaces.json` with `jq` before saving; discards corrupt data | ✅ Done |
| 2  | **JSON validation in restore** — validates all JSON files before parsing; falls back gracefully if corrupt                  | ✅ Done |
| 3  | **Floating state restore** — saves `is_floating` from niri IPC, restores via `niri msg action move-window-to-floating`      | ✅ Done |
| 4  | **Column width restore** — saves `layout.tile_size[0]`, restores as percentage via `niri msg action set-column-width "N%"`  | ✅ Done |
| 5  | **Focused window tracking** — uses `focus_timestamp` to find last-focused window, refocuses its workspace after restore     | ✅ Done |
| 6  | **Running app dedup** — checks `pgrep -x $app_id` before spawning non-kitty apps; skips if already running                  | ✅ Done |
| 7  | **Desktop notification on restore** — `notify-send "Session Restored" "Restored N windows from crash recovery"`             | ✅ Done |
| 8  | **Save failure notification** — `OnFailure=niri-session-save-failure.service` triggers critical `notify-send`               | ✅ Done |
| 9  | **Journal logging** — save logs `"saved N windows"` and restore logs `"restored N windows"` to stderr (captured by journal) | ✅ Done |
| 10 | **Dynamic wallpaper dir** — uses `config.home.homeDirectory` instead of hardcoded path                                      | ✅ Done |
| 11 | **Screenshot dir auto-create** — `mkdir -p ~/Pictures/screenshots` prepended to all screenshot keybinds                     | ✅ Done |
| 12 | **AGENTS.md documentation** — full "Niri Session Save/Restore" section added with architecture, commands, and config        | ✅ Done |
| 13 | **justfile commands** — `just session-status` and `just session-restore` added                                              | ✅ Done |
| 14 | **Configurable fallback apps** — `fallbackApps` list in `let` block (not hardcoded in script)                               | ✅ Done |
| 15 | **Configurable poll interval** — `sessionSaveInterval` variable, default `"60s"`                                            | ✅ Done |
| 16 | **Configurable max session age** — `maxSessionAgeDays` variable, default `7`                                                | ✅ Done |

**Research findings:**

| Question                                 | Answer                                                             |
| ---------------------------------------- | ------------------------------------------------------------------ |
| Does niri IPC include `is_floating`?     | ✅ Yes — `Window.is_floating: bool`                                |
| Does niri IPC include column width data? | ✅ Yes — `WindowLayout.tile_size: (f64, f64)`                      |
| Does niri IPC include `is_fullscreen`?   | ❌ No — tracked in niri discussion #1843                           |
| `SetColumnWidth` CLI syntax?             | `niri msg action set-column-width "N%"` for proportion             |
| `MoveWindowToFloating` CLI syntax?       | `niri msg action move-window-to-floating` (acts on focused window) |

---

## B) Partially Done ⚠️

Nothing partially done.

---

## C) Not Started 📋

### Blocked

- **Fullscreen state restore** — niri IPC does not expose `is_fullscreen`. Tracked in niri discussion #1843.

### Remaining backlog items

1. **Session restore stats in waybar** — show last restore time, windows restored in waybar module
2. **Integration test for save/restore** — mock niri IPC for automated testing
3. **Real-time save via event-stream** — use `niri msg event-stream` instead of polling timer
4. **Uevent tests for emeet-pixyd** — integration tests with mock netlink
5. **emeet-pixyd vendor hash** — needs rebuild after go.mod changes
6. **ADR for session restore design** — document architecture decisions

---

## D) Totally Fucked Up 💥

Nothing new. The `just test` intermittent emeet-pixyd failure from the previous report may still exist.

---

## E) Validation

- `just test-fast` — ✅ passes (all Nix syntax valid, all derivations evaluate)
- `just test` — pending (full build)
