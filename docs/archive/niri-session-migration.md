# Niri Session Save/Restore: Migration Research

**Date:** 2026-05-05
**Status:** Decision pending — migrate to `niri-session-manager` (accept terminal state loss for now)

---

## Context

SystemNix has a custom bash-based niri session save/restore system. The goal is to evaluate whether existing tools can replace it, and document the tradeoffs.

---

## Current Implementation (Custom Bash)

### Files

| File                                        | Purpose                                        |
| ------------------------------------------- | ---------------------------------------------- |
| `scripts/niri-session-save.sh`              | Periodic snapshot of niri state (60s timer)    |
| `scripts/niri-session-restore.sh`           | Restore windows on niri startup                |
| `platforms/nixos/programs/niri-wrapped.nix` | NixOS module wiring scripts + systemd services |

### What it does

- **Save** (systemd timer, configurable interval default 60s): Snapshots all niri windows, workspaces, and kitty terminal state to `~/.local/state/niri-session/`
- **Restore** (runs at niri startup via `spawn-at-startup`): Reads snapshot, re-spawns apps on correct workspaces with column widths, floating state, and focus order
- **Fallback**: If no session exists or snapshot is >7 days old, uses hardcoded default apps

### Saved data

| File               | Source                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `windows.json`     | `niri msg -j windows` — app_id, pid, workspace_id, is_floating, tile_size, focus_timestamp |
| `workspaces.json`  | `niri msg -j workspaces` — workspace names + IDs                                           |
| `kitty-state.json` | Per-kitty-window: PID, args, CWD, child process command + CWD (walks `/proc` tree)         |
| `timestamp`        | Epoch seconds of last save                                                                 |

### Restore features

- Workspace-aware: pre-creates named workspaces, spawns each app on correct workspace
- Floating state: restores `is_floating` via `move-window-to-floating`
- Column widths: restores via `SetColumnWidth` with proportion from `tile_size / output_width`
- Focus order: uses `focus_timestamp` to refocus the last-active window
- Deduplication: skips non-kitty apps already running (via `pgrep`)
- JSON validation: validates all JSON files before parsing
- Notification: `notify-send` on successful restore
- Save failure: `OnFailure` triggers critical desktop notification

### Module options (`services.niri-session`)

| Option                | Default                                                                  | Purpose                 |
| --------------------- | ------------------------------------------------------------------------ | ----------------------- |
| `sessionSaveInterval` | `"60s"`                                                                  | Timer interval          |
| `maxSessionAgeDays`   | `7`                                                                      | Max age before fallback |
| `fallbackApps`        | kitty, kitty -e btop, kitty -e nvtop, amdgpu_top, helium, signal-desktop | Fallback apps           |

### Weaknesses ("meh")

1. **Bash scripts** — fragile `/proc` walking, `pgrep -P` tree traversal up to 20 levels, `sleep 0.5` race-condition hacks instead of event-driven IPC
2. **No actual PID→command resolution** — the kitty `/proc` hack works but is inherently racy and incomplete
3. **60s timer is aggressive** — writing JSON every minute for rarely-changing layouts
4. **Dedup via `pgrep -x`** — racey; apps like Signal take seconds to appear in `pgrep`
5. **Hardcoded app mapping** (`signal` → `signal-desktop`) instead of a configurable mapping table
6. **No backup rotation** — single snapshot, no history
7. **Signal → signal-desktop** mapping hardcoded in bash case statement
8. **sleep-based timing** throughout restore — race conditions between spawn and niri IPC queries

---

## Existing Alternatives

### 1. [niri-session-manager](https://github.com/MTeaHead/niri-session-manager) (Rust)

**Stars:** 65 | **License:** GPL-3.0 | **Language:** Rust | **NixOS module:** Yes

The most mature and actively maintained solution. Rust binary with proper NixOS flake module.

**Features:**

- Periodic session saving with configurable interval
- Automatic session restoration on startup
- Backup management with configurable retention
- Graceful handling of window spawn failures
- Configurable retry logic for session restoration
- Custom app launch command mapping via TOML configuration
- `single_instance_apps` config section
- `skip_apps` config section
- `app_mappings` for app ID → command remapping

**CLI options:**

```
--save-interval <MINUTES>     How often to save the session (default: 15)
--max-backup-count <COUNT>    Number of backup files to keep (default: 5)
--spawn-timeout <SECONDS>     How long to wait for windows to spawn (default: 5)
--retry-attempts <COUNT>      Number of restore attempts (default: 3)
--retry-delay <SECONDS>       Delay between retry attempts (default: 2)
```

**Config example (`$XDG_CONFIG_HOME/niri-session-manager/config.toml`):**

```toml
[single_instance_apps]
apps = ["firefox", "zen"]

[skip_apps]
apps = ["discord", "slack"]

[app_mappings]
# flatpak remapping
"vesktop" = ["flatpak", "run", "dev.vencord.Vesktop"]
"com.mitchellh.ghostty" = ["ghostty"]
"org.wezfurlong.wezterm" = ["wezterm"]
"firefox-custom" = ["firefox", "--profile", "default-release"]
```

**NixOS integration:**

```nix
niri-session-manager.nixosModules.niri-session-manager
# Then:
services.niri-session-manager.enable = true;
services.niri-session-manager.settings = {
  save-interval = 30;
  max-backup-count = 3;
};
```

**Storage:**

- Session: `$XDG_DATA_HOME/niri-session-manager/session.json`
- Backups: `$XDG_DATA_HOME/niri-session-manager/session-{timestamp}.bak`
- Config: `$XDG_CONFIG_HOME/niri-session-manager/config.toml`

**TODO (from their README):**

- Use PID to fetch the actual process command

**Future (when IPC supports it):**

- Grab window size and further details for better placement when restoring windows

**Open PR: [PR #2](https://github.com/MTeaHead/niri-session-manager/pull/2)** — "Use workspace idx/name and output to restore windows instead of workspace id"

- **Author:** fmuehlis
- **Status:** Open, assigned to MTeaHead, mergeable (clean merge state)
- **Created:** 2025-07-26
- **Changes:** +77/-26 across 3 files
- **What it does:** Fixes windows being spawned on random workspaces by using workspace name/index + output instead of unstable workspace IDs. Bumps niri-ipc dependency for `MoveWindowToMonitor` support.
- **Note:** This is currently a "proof of concept" draft — author wants feedback before refining.

---

### 2. [nirinit](https://github.com/amaanq/nirinit) (404/abandoned)

Repository is gone. Was listed on awesome-niri as a "Session manager that automatically saves and restores your window layout." No longer available.

---

### 3. [swaytreesave](https://github.com/fabienjuif/swaytreesave) (Rust)

**Language:** Rust | **Multi-compositor:** sway, i3, niri

CLI tool to save and load compositor tree/layout. Named layouts, workspace-specific restore, dry-run.

**Features:**

- Save and load your sway/niri tree (layout)
- Named layouts (`--name`)
- Workspace-specific load (`--workspace`)
- Exec/timeout/retry customization per item
- Dry-run mode
- Multi-compositor support (sway, i3, niri)
- `--compositor niri` flag

**No NixOS module** — cargo install only.

---

## Comparison Matrix

| Feature                     | Our Bash Scripts       | niri-session-manager        | swaytreesave     |
| --------------------------- | ---------------------- | --------------------------- | ---------------- |
| **Language**                | Bash                   | Rust                        | Rust             |
| **NixOS module**            | Yes (custom)           | Yes (upstream)              | No               |
| **Periodic save**           | Yes (60s timer)        | Yes (15min default)         | Manual only      |
| **Auto-restore on startup** | Yes (spawn-at-startup) | Yes                         | Manual only      |
| **Workspace placement**     | Yes (by name/ID)       | Yes (by ID, PR #2 fixes)    | Yes (by name)    |
| **Floating state restore**  | Yes                    | No                          | No               |
| **Column width restore**    | Yes                    | No                          | No               |
| **Focus order restore**     | Yes (focus_timestamp)  | No                          | No               |
| **Kitty CWD recovery**      | Yes (/proc walking)    | No                          | No               |
| **Kitty child command**     | Yes (/proc tree walk)  | No                          | No               |
| **App ID→command mapping**  | Hardcoded (bash case)  | TOML config                 | YAML config      |
| **Single-instance dedup**   | pgrep -x (racey)       | Configurable                | Configurable     |
| **Skip apps**               | No                     | Yes (config)                | No               |
| **Backup rotation**         | No                     | Yes (configurable count)    | Named layouts    |
| **Retry logic**             | No                     | Yes (configurable attempts) | Yes (per-item)   |
| **Spawn timeout**           | sleep 0.5 (hardcoded)  | Configurable                | Configurable     |
| **Named layouts**           | No                     | No                          | Yes              |
| **Multi-compositor**        | niri only              | niri only                   | sway + i3 + niri |

---

## Decision: Migrate to niri-session-manager

**Chosen path:** Migrate to `niri-session-manager`, accept losing terminal state recovery for now.

### What we gain

- Proper Rust IPC instead of fragile bash + `/proc` walking
- TOML-based app ID mapping (no more hardcoded `signal` → `signal-desktop`)
- Backup rotation with configurable retention
- Retry logic with configurable attempts/delay
- `single_instance_apps` + `skip_apps` config sections
- Upstream NixOS module — less custom code to maintain
- Active community (65 stars, 3 forks)

### What we lose (temporarily)

- **Kitty CWD/child command recovery** — the `/proc` tree walking that re-spawns kitty with the correct working directory and child process (btop, nvim, etc.)
- **Floating state restore** — `move-window-to-floating` after spawn
- **Column width restore** — `SetColumnWidth` proportion calculation
- **Focus order** — `focus_timestamp`-based last-window refocus

### Mitigation

- Floating state: handled by niri `window-rules` (already configured in niri-wrapped.nix for pavucontrol, floating class, etc.)
- Column width: handled by niri `window-rules` with `default-column-width` per app
- Kitty CWD: niri-session-manager has "Use PID to fetch the actual process command" on their TODO — future contribution opportunity
- Focus order: minor convenience loss

### Future contribution opportunity

The kitty terminal state recovery logic (walking `/proc` to find child process command + CWD) is unique to our implementation. Porting this into `niri-session-manager` as an upstream contribution would give the community proper terminal state recovery in Rust, without the bash fragility. This aligns with their existing TODO item.

---

## Migration Plan

1. Add `niri-session-manager` as flake input
2. Wire into NixOS configuration (upstream NixOS module)
3. Remove old session scripts and systemd services from `niri-wrapped.nix`
4. Remove `scripts/niri-session-save.sh` and `scripts/niri-session-restore.sh`
5. Update justfile session commands
6. Update `AGENTS.md` documentation
7. Configure TOML app mappings for our apps (signal → signal-desktop, etc.)
