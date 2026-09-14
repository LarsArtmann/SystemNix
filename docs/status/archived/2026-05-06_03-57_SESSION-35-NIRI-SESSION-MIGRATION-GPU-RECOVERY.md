# Session 35 — Niri Session Manager Migration + GPU Recovery + Research

**Date:** 2026-05-06 03:57
**Branch:** master
**Previous session:** 34 (manifest secrets, DRM healthcheck, full system audit)

---

## Executive Summary

Migrated from custom bash-based niri session save/restore to the upstream `niri-session-manager` (Rust). Added GPU driver recovery system for DRM corruption. Conducted extensive research on niri session ecosystem, sudo/doas internals, and cybersecurity tooling. `just test-fast` passes clean.

---

## A) FULLY DONE ✓

### 1. Niri Session Manager Migration

Replaced ~300 lines of custom bash scripts with the upstream `niri-session-manager` Rust tool.

| What                | Details                                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------------------- |
| Added flake input   | `niri-session-manager` with `inputs.nixpkgs.follows`                                                  |
| Wired into NixOS    | `inputs.niri-session-manager.nixosModules.niri-session-manager` in flake.nix module list              |
| Enabled service     | `services.niri-session-manager.enable = true` in configuration.nix                                    |
| Removed old code    | 116 lines of session options/scripts/services from niri-wrapped.nix                                   |
| Removed old scripts | `scripts/niri-session-save.sh` (97 lines) and `scripts/niri-session-restore.sh` (202 lines) — trashed |
| Updated justfile    | `session-status` and `session-restore` point to new service                                           |
| Updated AGENTS.md   | New section for niri-session-manager, flake input table updated                                       |
| Validation          | `just test-fast` passes — all nixosModules, packages, configs evaluate                                |

**Files changed:** flake.nix, flake.lock, configuration.nix, niri-wrapped.nix, justfile, AGENTS.md

### 2. GPU Driver Recovery System

Added a proper GPU driver recovery mechanism for when niri's DRM state gets corrupted (OOM kills dbus-broker → niri loses DRM master → GPU driver state corrupted → simple niri restart doesn't fix it).

| What                      | Details                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| `scripts/gpu-recovery.sh` | Unbinds/rebinds amdgpu driver to reset DRM state without reboot                            |
| System service            | `systemd.services.gpu-recovery` (root-level, needed for driver rebind)                     |
| Updated DRM healthcheck   | `niri-drm-healthcheck.sh` now triggers `gpu-recovery.service` instead of just killing niri |
| Updated niri-config.nix   | Added gpuRecovery derivation + system service                                              |

### 3. Research & Documentation

| Document                                            | Purpose                                                                                                                              |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `docs/niri-session-migration.md`                    | Full comparison matrix of niri-session-manager vs our bash scripts vs swaytreesave, tradeoff analysis, PR #2 details, migration plan |
| `docs/niri-session-manager-issue-pid-resolution.md` | GitHub issue draft for PID-based terminal state recovery in niri-session-manager                                                     |
| `docs/sudo-vs-doas-analysis.md`                     | Updated with NixOS internal sudo dependency analysis (~25 modules hardcode `/run/wrappers/bin/sudo`)                                 |
| `docs/cybersecurity-tools-evo-x2.md`                | Cybersecurity tool recommendations for evo-x2                                                                                        |
| `docs/tonybtw-things-to-consider.md`                | Notes from tonybtw.com review                                                                                                        |

### 4. Niri Session Ecosystem Research

Researched all existing niri session save/restore tools:

| Tool                                                                     | Status                                            | Key Finding                                           |
| ------------------------------------------------------------------------ | ------------------------------------------------- | ----------------------------------------------------- |
| [niri-session-manager](https://github.com/MTeaHead/niri-session-manager) | **Chosen** — 65 stars, Rust, NixOS module, active | PID resolution on TODO, no terminal state             |
| [PR #2](https://github.com/MTeaHead/niri-session-manager/pull/2)         | Open, unmerged                                    | Fixes workspace placement by name/index instead of ID |
| [nirinit](https://github.com/amaanq/nirinit)                             | **Abandoned** (404)                               | Repository gone                                       |
| [swaytreesave](https://github.com/fabienjuif/swaytreesave)               | Active, multi-compositor                          | No NixOS module, manual-only save/restore             |

Read full source of niri-session-manager (`main.rs`, ~450 lines). Key findings:

- Uses `niri_ipc` async socket (not `niri msg` CLI)
- `Window` struct from niri_ipc already has `pid` — it's **discarded** in `WindowWithoutTitle`
- Spawn via `Action::Spawn { command }` — just needs richer command array for terminal state
- Issues **disabled** on repo — can't file the PID resolution issue

---

## B) PARTIALLY DONE

### 1. PID Resolution Issue for niri-session-manager

- Issue draft written (`docs/niri-session-manager-issue-pid-resolution.md`)
- Reviewed and refined with user
- **BLOCKED**: Issues and discussions are disabled on `MTeaHead/niri-session-manager`
- **Next step**: Comment on PR #2 or open a PR directly with the feature

### 2. TOML Config for niri-session-manager

- Service is enabled but **no TOML config created yet** at `~/.config/niri-session-manager/config.toml`
- Need app mappings: `signal` → `signal-desktop`, potentially flatpak remappings
- Will be created on first `just switch` (upstream creates default config)

---

## C) NOT STARTED

1. **Actually deploy to evo-x2** — `just switch` has not been run
2. **Create TOML config** with app mappings for our apps
3. **Test session restore** — verify it actually works after switch
4. **File PR or comment** on niri-session-manager for PID resolution
5. **Update migration doc** after first successful deploy

---

## D) TOTALLY FUCKED UP

Nothing catastrophically broken. However:

1. **Silent regression risk**: The old scripts restored kitty CWD/child commands. The new tool does not. Users who relied on crash recovery restoring their `btop`/`nvim` terminals will lose that until we contribute PID resolution upstream.

2. **`docs/tonybtw-things-to-consider.md`** and **`docs/cybersecurity-tools-evo-x2.md`** are untracked — need to be committed or excluded.

3. **`scripts/gpu-recovery.sh`** is staged but unrelated to session migration — should be in a separate commit.

---

## E) WHAT WE SHOULD IMPROVE

1. **niri-session-manager TOML config should be declarative** — Currently it's a runtime file. We should manage it via Home Manager `xdg.configFile` so it's version-controlled and reproducible.

2. **PR #2 is unmerged** — We're using upstream's workspace-id-based placement which has known bugs (windows on random workspaces). Should track PR #2 and potentially use the fork (`fmuehlis/niri-session-manager`) as our flake input until it merges.

3. **GPU recovery script is untested** — `gpu-recovery.sh` does driver unbind/rebind which is inherently risky. Needs real-world testing during an actual DRM corruption event.

4. **No fallback apps configured** — Old system had configurable fallback apps (kitty, btop, nvtop, etc.). niri-session-manager has no equivalent — if no session exists, it just saves current state and does nothing.

5. **Session data migration** — Old data at `~/.local/state/niri-session/` will be orphaned. Should clean up after first successful deploy.

6. **Commit hygiene** — Multiple unrelated changes (session migration, GPU recovery, docs research) are in the working tree together. Should be separate commits.

---

## F) TOP 25 THINGS TO GET DONE NEXT

| #  | Priority | Task                                                                                            | Effort       |
| -- | -------- | ----------------------------------------------------------------------------------------------- | ------------ |
| 1  | **P0**   | Deploy to evo-x2 with `just switch`                                                             | 5min         |
| 2  | **P0**   | Verify niri-session-manager actually restores windows                                           | 5min         |
| 3  | **P0**   | Create TOML config with app mappings (signal→signal-desktop, etc.)                              | 10min        |
| 4  | **P1**   | Make TOML config declarative via Home Manager `xdg.configFile`                                  | 15min        |
| 5  | **P1**   | Clean up old session data at `~/.local/state/niri-session/`                                     | 2min         |
| 6  | **P1**   | Test GPU recovery script during actual DRM corruption                                           | Event-driven |
| 7  | **P1**   | Consider using `fmuehlis/niri-session-manager` fork (has workspace name fix) until PR #2 merges | 10min        |
| 8  | **P2**   | File PR or comment on niri-session-manager for PID resolution                                   | 30min        |
| 9  | **P2**   | Port kitty /proc walking logic into niri-session-manager as Rust contribution                   | 2-4h         |
| 10 | **P2**   | Test `just session-status` and `just session-restore` after deploy                              | 5min         |
| 11 | **P2**   | Verify backup rotation works (check `~/.local/share/niri-session-manager/*.bak`)                | 5min         |
| 12 | **P3**   | Add `single_instance_apps` to TOML config (firefox, signal-desktop, etc.)                       | 5min         |
| 13 | **P3**   | Add `skip_apps` to TOML config (apps that shouldn't be restored)                                | 5min         |
| 14 | **P3**   | Update AGENTS.md to reflect GPU recovery system                                                 | 10min        |
| 15 | **P3**   | Test niri crash recovery end-to-end (kill niri, verify restore on restart)                      | 10min        |
| 16 | **P3**   | Review `docs/tonybtw-things-to-consider.md` for actionable items                                | 30min        |
| 17 | **P4**   | Commit `docs/cybersecurity-tools-evo-x2.md`                                                     | 2min         |
| 18 | **P4**   | Commit or trash `docs/tonybtw-things-to-consider.md`                                            | 2min         |
| 19 | **P4**   | Test DRM healthcheck + gpu-recovery integration                                                 | 15min        |
| 20 | **P4**   | Run `just format` on all changed files                                                          | 2min         |
| 21 | **P5**   | Update `docs/niri-session-migration.md` with deploy results                                     | 10min        |
| 22 | **P5**   | Consider window rules for floating state (old scripts did this, new tool doesn't)               | 15min        |
| 23 | **P5**   | Investigate niri IPC `MoveWindowToMonitor` from PR #2 for multi-monitor restore                 | 30min        |
| 24 | **P5**   | Audit all systemd user services for session integration (awww, swayidle, cliphist)              | 15min        |
| 25 | **P5**   | Run `just test` (full build validation) to verify everything compiles                           | 30min+       |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Should we use the `fmuehlis/niri-session-manager` fork as our flake input instead of `MTeaHead/niri-session-manager`?**

PR #2 (fmuehlis fork) fixes the workspace placement bug where windows spawn on random workspaces. It's been open since July 2025, assigned to MTeaHead, mergeable (clean state), but hasn't been merged. The upstream still has this known bug.

Using the fork would give us correct workspace restore immediately, but:

- It's a fork — could diverge or go stale
- If PR #2 merges, we'd need to switch back
- The fork hasn't been updated since July 2025 (same upstream bugs otherwise)

This is a product decision, not a technical one. I can't determine the right tradeoff without your input.

---

## Files Changed This Session

| File                                                | Status          | Lines                           |
| --------------------------------------------------- | --------------- | ------------------------------- |
| `flake.nix`                                         | Modified        | +8 (new input + module import)  |
| `flake.lock`                                        | Modified        | +88 (niri-session-manager lock) |
| `platforms/nixos/system/configuration.nix`          | Modified        | +1 (enable service)             |
| `platforms/nixos/programs/niri-wrapped.nix`         | Modified        | -116 (removed session code)     |
| `scripts/niri-session-save.sh`                      | Deleted         | -97                             |
| `scripts/niri-session-restore.sh`                   | Deleted         | -202                            |
| `scripts/gpu-recovery.sh`                           | New (staged)    | +86                             |
| `scripts/niri-drm-healthcheck.sh`                   | Modified        | Rewritten for gpu-recovery      |
| `modules/nixos/services/niri-config.nix`            | Modified        | +22 (gpu-recovery service)      |
| `justfile`                                          | Modified        | Session commands updated        |
| `AGENTS.md`                                         | Modified        | Session section rewritten       |
| `docs/niri-session-migration.md`                    | New             | Research doc                    |
| `docs/niri-session-manager-issue-pid-resolution.md` | New             | Issue draft                     |
| `docs/sudo-vs-doas-analysis.md`                     | Modified        | +50 NixOS sudo deps             |
| `docs/cybersecurity-tools-evo-x2.md`                | New (untracked) | Security tools                  |
| `docs/tonybtw-things-to-consider.md`                | New (untracked) | Notes                           |

**Net:** -284 lines of bash, +8 lines of Nix config. Much simpler.

---

_ Status report generated by Crush — Session 35_
