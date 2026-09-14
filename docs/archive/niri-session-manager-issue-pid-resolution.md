# Feature: Resolve terminal window PIDs to actual process commands for accurate restore

## Problem

When restoring a session, windows are spawned by their `app_id` (e.g. `kitty`, `foot`). For terminals, this always opens a bare shell — losing whatever was running inside (e.g. `btop`, `nvim`, a `ssh` session, a project-specific build command).

This is listed as a TODO in the README: "Use PID to fetch the actual process command."

## Proposed Solution

During **save**, walk `/proc` for each terminal window's PID to capture the child process command + CWD (skipping intermediate shells like fish/bash/zsh). During **restore**, re-spawn the terminal with the recovered command:

```
kitty --directory /path/to/project -e sh -c "nvim; exec fish"
```

When no child process is found (user just has a shell running), it spawns a bare terminal as it does today.

## Working Proof of Concept

I have a working bash implementation in my NixOS config that does exactly this:

- **Save** (walks `/proc` for kitty windows, captures child command + CWD): [niri-session-save.sh](https://github.com/LarsArtmann/SystemNix/blob/master/scripts/niri-session-save.sh)
- **Restore** (re-spawns kitty with recovered command + CWD): [niri-session-restore.sh](https://github.com/LarsArtmann/SystemNix/blob/master/scripts/niri-session-restore.sh)
