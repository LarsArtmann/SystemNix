# Session 36 — PR Plan Committed, Fork Implementation In Progress

**Date:** 2026-05-06 04:47
**Branch:** master (SystemNix), feat/terminal-state-recovery (fork)
**Previous session:** 35 (niri session migration, GPU recovery)

---

## Executive Summary

Session 35 migrated niri session save/restore from custom bash to `niri-session-manager`. This session (36) committed the PR plan for terminal state recovery to the fork repo at `/home/lars/forks/niri-session-manager/`. The fork has **uncommitted partial implementation** (170 lines changed in `main.rs`, 127-line `src/proc.rs`) from a previous session that was never committed. SystemNix itself is clean — only `flake.lock` upstream drift.

---

## A) FULLY DONE ✓

### 1. SystemNix — Niri Session Manager Migration (Session 35)

Committed in 2 clean commits:

- `ff0237a` — GPU driver recovery system (gpu-recovery.sh, niri-config.nix refactor)
- `cdac51a` — Session migration + all docs (11 files, -284 lines bash, +8 lines Nix)

`just test-fast` passes. All linters (statix, deadnix, alejandra, gitleaks) pass.

### 2. Fork — PR Plan Written & Committed

`/home/lars/forks/niri-session-manager/PR-PLAN.md` on branch `feat/terminal-state-recovery`:

- Full implementation plan: `SavedWindow` struct, `proc.rs` module, TOML config
- Backward-compatible JSON format design
- Edge case analysis (shell nesting, **atexit**, non-Linux)
- Shell detection algorithm
- POC references to our bash scripts
- Committed as `c686352`

### 3. Fork — Upstream Repo State Analyzed

Full source read of `niri-session-manager` main.rs (488 lines):

- `Window` from niri_ipc already has `pid` — **discarded** in `WindowWithoutTitle`
- Spawn via `Action::Spawn { command }` — just needs richer command array
- Save stores `session.json` to `$XDG_DATA_HOME/niri-session-manager/`
- Restore polls for new window by `app_id` match every 500ms, then `MoveWindowToWorkspace`

### 4. SystemNix — Documentation Complete

| Doc                                                 | Status                                          |
| --------------------------------------------------- | ----------------------------------------------- |
| `docs/niri-session-migration.md`                    | Full comparison matrix + tradeoff analysis      |
| `docs/niri-session-manager-issue-pid-resolution.md` | Issue draft (blocked: issues disabled upstream) |
| `docs/status/2026-05-06_03-57_SESSION-35-*.md`      | Previous session status                         |
| AGENTS.md                                           | Updated for niri-session-manager                |

---

## B) PARTIALLY DONE

### 1. Fork — Terminal State Recovery Implementation

**Uncommitted work exists** at `/home/lars/forks/niri-session-manager/`:

| File          | Lines            | Status                                 |
| ------------- | ---------------- | -------------------------------------- |
| `src/main.rs` | +170/-34 changed | Uncommitted — partially implemented    |
| `src/proc.rs` | 127 lines new    | Untracked — Linux /proc reading module |

This is from a **previous session** that was never committed. Contents unknown until reviewed.

### 2. SystemNix — Not Deployed Yet

`just switch` has **not been run** on evo-x2 since the migration. The new niri-session-manager service is enabled in config but not deployed.

### 3. Upstream Contribution Path

- Issues **disabled** on `MTeaHead/niri-session-manager`
- Discussions **disabled**
- PR #2 (workspace name fix) still open/unmerged since July 2025
- Our fork: `git@github.com:LarsArtmann/niri-session-manager.git`
- PR plan committed but **implementation not reviewed or tested**

---

## C) NOT STARTED

1. **Deploy to evo-x2** — `just switch` to apply niri-session-manager
2. **Create TOML config** — `~/.config/niri-session-manager/config.toml` with app mappings
3. **Test session restore** on evo-x2 after deploy
4. **Review uncommitted fork code** — the 170+127 lines of partial implementation
5. **Test fork implementation** — build and test on evo-x2
6. **Open PR upstream** — once implementation is complete and tested
7. **Clean old session data** — `~/.local/state/niri-session/` orphaned after deploy
8. **Make TOML config declarative** via Home Manager `xdg.configFile`
9. **Consider fmuehlis fork** for workspace name fix until PR #2 merges

---

## D) TOTALLY FUCKED UP

1. **Uncommitted implementation in fork** — There are 170 lines of uncommitted changes to `main.rs` and a 127-line untracked `src/proc.rs` in the fork repo. This work was done in a previous session and never committed. We don't know the quality or correctness until reviewed. This is a git hygiene failure.

2. **Flake lock drift** — `flake.lock` in SystemNix has upstream changes (dnsblockd, file-and-image-renamer) that are unstaged. Not broken, but dirty.

3. **PR #2 still unmerged** — The workspace placement fix has been open since July 2025. We're running with the known bug (windows spawning on random workspaces) until it merges or we switch to the fork.

4. **No TOML config** — niri-session-manager will create a default config on first run, but it won't have our app mappings (signal → signal-desktop). The first deploy will have wrong app launching.

5. **Old session data will be orphaned** — `~/.local/state/niri-session/` with our bash script data will sit there forever after migration. No cleanup plan.

---

## E) WHAT WE SHOULD IMPROVE

1. **Review and commit the fork implementation** — The uncommitted 170+127 lines need to be reviewed, cleaned up, and properly committed with a good message. If they're garbage, trash them and start fresh from the PR plan.

2. **Build a test matrix** — We should test the fork implementation with: kitty+btop, kitty+nvim, kitty+ssh, bare kitty, foot, and non-terminal apps. Document results.

3. **Declarative TOML config** — The niri-session-manager config should be managed by Home Manager, not a runtime-generated file. This ensures reproducibility.

4. **Workspace placement** — Until PR #2 merges, we should evaluate using `fmuehlis/niri-session-manager` as our flake input. The workspace bug is real and affects daily use.

5. **Integration testing** — After deploy, we should do a full crash-recovery test: save session → kill niri → verify restore. Document what works and what doesn't.

6. **Commit hygiene in fork** — The fork repo should follow the same standards as SystemNix. Uncommitted work is unacceptable.

---

## F) TOP 25 THINGS TO GET DONE NEXT

| #   | Priority | Task                                                                         | Where     | Effort |
| --- | -------- | ---------------------------------------------------------------------------- | --------- | ------ |
| 1   | **P0**   | Review uncommitted fork implementation (main.rs +170/-34, proc.rs 127 lines) | fork      | 30min  |
| 2   | **P0**   | Commit or trash the fork implementation based on review                      | fork      | 5min   |
| 3   | **P0**   | Deploy SystemNix to evo-x2 with `just switch`                                | SystemNix | 5min   |
| 4   | **P0**   | Create TOML config with app mappings (signal→signal-desktop)                 | SystemNix | 10min  |
| 5   | **P0**   | Test session restore works after deploy                                      | SystemNix | 10min  |
| 6   | **P1**   | Build fork on evo-x2: `nix build` in fork repo                               | fork      | 10min  |
| 7   | **P1**   | Test fork terminal state recovery end-to-end                                 | fork      | 30min  |
| 8   | **P1**   | Stage flake.lock changes in SystemNix                                        | SystemNix | 2min   |
| 9   | **P1**   | Evaluate fmuehlis fork for workspace fix (PR #2)                             | SystemNix | 15min  |
| 10  | **P2**   | Clean old session data `~/.local/state/niri-session/`                        | SystemNix | 2min   |
| 11  | **P2**   | Make TOML config declarative via Home Manager                                | SystemNix | 15min  |
| 12  | **P2**   | Test crash recovery: kill niri, verify restore                               | SystemNix | 10min  |
| 13  | **P2**   | Add `single_instance_apps` and `skip_apps` to TOML config                    | SystemNix | 5min   |
| 14  | **P2**   | Verify backup rotation works after first save interval                       | SystemNix | 5min   |
| 15  | **P3**   | Complete fork implementation if review found it incomplete                   | fork      | 2-4h   |
| 16  | **P3**   | Test GPU recovery script (niri-drm-healthcheck → gpu-recovery)               | SystemNix | 15min  |
| 17  | **P3**   | Add window rules for floating state (old scripts did this)                   | SystemNix | 15min  |
| 18  | **P3**   | Run `just test` (full build validation)                                      | SystemNix | 30min+ |
| 19  | **P4**   | Comment on PR #2 about our interest in workspace fix                         | fork      | 5min   |
| 20  | **P4**   | Run `just format` on SystemNix                                               | SystemNix | 2min   |
| 21  | **P4**   | Update AGENTS.md with deploy results                                         | SystemNix | 10min  |
| 22  | **P4**   | Test niri crash recovery end-to-end on evo-x2                                | SystemNix | 10min  |
| 23  | **P5**   | Review `docs/tonybtw-things-to-consider.md` for actionable items             | SystemNix | 30min  |
| 24  | **P5**   | Update `docs/niri-session-migration.md` with real deploy results             | SystemNix | 10min  |
| 25  | **P5**   | Open PR upstream once fork implementation is tested                          | fork      | 15min  |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**What is the quality of the uncommitted fork implementation (170 lines in main.rs + 127 lines in proc.rs)?**

I did not write this code in this session. It exists in the fork working tree from a previous session but was never committed. I need your input:

- Should I review it, clean it up, and commit it? (It may be a head start.)
- Should I trash it and implement fresh from the PR plan? (Cleaner, but more work.)
- Should I just review and report back before deciding?

The answer determines whether task #1 takes 5 minutes or 2+ hours.

---

## Repository State

### SystemNix (`~/projects/SystemNix`)

| Branch | Status                         | Commits ahead     |
| ------ | ------------------------------ | ----------------- |
| master | 1 unstaged change (flake.lock) | 2 ahead of origin |

Recent commits:

```
cdac51a feat(session): migrate from custom bash scripts to niri-session-manager
ff0237a feat(niri): add GPU driver recovery system for DRM corruption
733b6d3 docs(security): add sudo vs doas vs run0 comprehensive analysis
```

### Fork (`~/forks/niri-session-manager`)

| Branch                       | Status                                                     |
| ---------------------------- | ---------------------------------------------------------- |
| feat/terminal-state-recovery | 1 uncommitted change (main.rs), 1 untracked file (proc.rs) |

Recent commits:

```
c686352 docs: add PR plan for terminal state recovery via /proc PID resolution
2d9ae35 bump version (upstream)
```

---

_ Status report generated by Crush — Session 36_
