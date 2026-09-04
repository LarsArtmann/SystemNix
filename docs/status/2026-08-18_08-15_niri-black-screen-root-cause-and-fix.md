# Niri Black Screen on Login + Mystery Power-Off: Root Cause and Fix

> **KEPT LIVE (2026-09-02, user §g.1 decision):** incident forensic record with enduring provenance — archive rule is "numbered action items all closed"; records with zero forward items stay in docs/status/.

**Date:** 2026-08-18 ~08:15
**Trigger:** User questions — (1) why did we shut down/crash? (2) why does logging into niri give a black screen and the monitor powers off?

**Session arc in one line:** Journal forensics traced both symptoms to ONE root cause — a headless zombie niri started by the user-manager boot transaction via a `Wants=graphical-session.target` pull-in — fixed it at three layers (pull-in removal, start condition, restart semantics) plus two watchdog bugs found on the way, verified everything eval/build/behaviorally except the final deploy (user command).

---

## 1. Answers

### Q1: Why did we shut down / crash?

**A forced power-off, not a kernel crash.** Evidence:

- Previous boot's journal ends at **03:30:58 mid-activity** (niri `DeviceMissing` spam, coredumps processing). No shutdown sequence at all — no `systemd: Stopping…`, no `Reached target Shutdown/Power-Off`, no unmounts.
- Current boot's kernel reports reset reason `[0x00200800]: ACPI power state transition occurred` = a plain power-off.
- watchdogd reset cause `0x0000 - unknown`; `/sys/fs/pstore` empty (no panic record); sp5100 TCO initialized fresh — no watchdog bite.
- Context: the desktop had been dead since boot 20:27 (see Q2). The user worked from the MacBook over SSH all evening (status reports written 02:48), attempted console interaction around 03:26 (polkit auth prompts for `ssh-suspend-guard` spamming the dead display), and the box went dark at 03:30. Most consistent reconstruction: **power button hold on an unusable desktop.**

### Q2: Why is niri login a black screen and the monitor shuts off?

**SDDM's `niri-session` aborts because a zombie niri is already running.** Full chain, verified from journals + `systemd-analyze --user dump` + unit files:

1. `Linger=yes` for `lars` → the user manager (`user@1000.service`) starts at **boot**, before SDDM exists.
2. Its `default.target` transaction includes `activitywatch.target` → `aw-watcher-window-wayland.service`, which had **`Wants=graphical-session.target`** (added long ago to work around an ordering quirk).
3. `Wants=` pulls `graphical-session.target` into the boot transaction (it is `RefuseManualStart` only against manual starts, not dependencies).
4. `graphical-session.target.wants/` contains `niri-session-manager.service` (**`Requires=niri.service`**) and `focus-new-windows.service` (`Wants=niri.service`) → **niri.service starts at 06:57:57, 27 s before SDDM**.
5. That niri has no seat/VT/session → "session is not active", `error doing early import: Error::DeviceMissing` spam, **zero outputs** (verified live: `niri msg outputs` → `{}`).
6. User logs in at SDDM → `niri-session` script checks `systemctl --user -q is-active niri.service` → active → **"A niri session is already running." exit 1** (`sddm-helper exited with 1` in the journal at both 20:27:52 and 06:58:47) → VT1 stays black → monitor DPMS-offs ("shuts down").
7. Amplifier: `niri-drm-healthcheck` (user timer, 60 s) sees connected display + `enabled=disabled` + `dpms=Off` while niri runs → restarts niri every 2 checks → **the observed 2-minute churn** (session-manager SIGTERMs, DMS exit-255 crashes, helium SIGTRAP coredumps — all collateral, not causes).

Corroborating bugs found on the way:

- `display-watchdog`'s login-screen guard was dead: it parses `loginctl list-sessions` with `awk`, but `gawk` was never in `runtimeInputs` → `awk: command not found` every 30 s in the journal → guard always read "no graphical session".
- `niri-drm-healthcheck.sh` had the known `writeShellApplication` pipefail trap: `wc -l || echo 0` produced `"0\n0"` → `[: integer expected` when journalctl fails (e.g. for the SDDM user's manager instance of the same unit).
- Headless-niri incidents also explain the 03:26 polkit prompt storm (`niri-flake-polkit` SEGV-ing on the gtk2-less QML dialog is a separate cosmetic issue; the prompts only appear because SSH-sourced polkit requests route to the graphical agent).

## 2. Fixes (all in this session, staged)

| # | File                                                          | Change                                                                                                                                                                                                                                                                                                                                            | Layer                                                  |
| - | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| 1 | `platforms/common/programs/activitywatch.nix`                 | Removed `Wants=graphical-session.target` from the aw-watcher unit (comment now forbids re-adding it, with incident reference); gate wrapper default timeout 60 s → **0 = wait indefinitely** (a lingering boot has no socket until the user logs in — hours later; failing would trip StartLimitBurst and kill the watcher for the whole session) | Removes the boot pull-in edge — the root cause         |
| 2 | `modules/nixos/desktop/niri-config.nix` (niri.service mkUnit) | Added **`ConditionEnvironment=XDG_SESSION_ID`** — the manager env only carries it after a real SDDM login ran `import-environment` (NixOS's session wrapper imports it), so a lingering/SSH context can never start the compositor                                                                                                                | Defense-in-depth against any future pull-in regression |
| 3 | `modules/nixos/desktop/niri-config.nix` (niri.service mkUnit) | `Restart=always` → **`Restart=on-failure`** — a clean niri exit IS logout; `always` respawned a headless niri after logout, which would block the NEXT login the same way. Crashes (signals/nonzero) still auto-restart                                                                                                                           | Closes the logout→respawn variant of the same bug      |
| 4 | `scripts/niri-drm-healthcheck.sh`                             | Added the same login-screen guard as `display-watchdog.sh` (loginctl Class=user + Type=wayland/x11, no awk needed): never restart niri when no user graphical session exists — a restarted headless niri is just as headless. Fixed the `wc -l                                                                                                    |                                                        |
| 5 | `modules/nixos/desktop/niri-config.nix` (displayWatchdog)     | Added `gawk` to `runtimeInputs` — the login-screen guard's `awk` was missing, making the watchdog permanently believe it was at a login screen                                                                                                                                                                                                    | Repairs a silently-broken guard                        |

Also: `AGENTS.md` gotcha entry added under "Desktop".

## 3. Verification done

- `nix flake check --no-build` → **exit 0**.
- Eval'd the real generated units from `nixosConfigurations.evo-x2`:
  - aw-watcher: `Unit.Wants` absent; `After`/`PartOf` intact.
  - `niri.service`: `ConditionEnvironment=XDG_SESSION_ID` + `Restart=on-failure` present.
- Both scripts built through `writeShellApplication` (shellcheck in checkPhase) → success.
- Behavioral tests of the healthcheck against the **live zombie niri** on this machine, with stubbed `loginctl`/`journalctl` and stubbed restart — deterministic across 5 cases:
  1. wayland session present + real dead DP-1 → counts 1/2, no restart yet;
  2. same, second run → threshold hit → restart invoked (stubbed);
  3. tty-only sessions → guard message, no action;
  4. `loginctl` failing → fail-safe no action;
  5. real loginctl + live current state (SSH-only) → guard message, no action. (Pre-fix, this exact live state was the 2-minute restart loop.)
- Caught and fixed a bug in my own first guard draft during testing (`IFS= read -r sid _rest` disables word splitting — the whole line landed in `sid`). This is why we test.

## 4. NOT done / handover

~~1. **Deploy** — user command (`nix run .#deploy`). Post-deploy checklist:~~ done — deployed 2026-08-18 15:00 session; desktop recovered, no zombie recurrence since
   - reboot, then BEFORE logging in: `pgrep -x niri` → empty (no zombie at login screen);
   - login at SDDM → desktop appears within seconds; `journalctl --user -u niri -b --since -2min` shows outputs enabled, no `DeviceMissing` spam;
   - `loginctl show-session <id> -p Type` → wayland; `niri msg outputs` lists DP-1;
   - no `niri-drm-healthcheck` restart lines every 2 min;
   - aw-watcher attaches after login (gate execs once a wayland socket exists).
~~2. **Live cleanup of the current zombie** — needs systemctl (blocked in this session); the deploy + reboot supersedes it.~~ done — superseded by the reboot; zombie gone
~~3. Follow-ups (not blocking): `niri-drm-healthcheck.timer` also arms for the SDDM greeter's user manager (global NixOS user unit) — harmless post-guard, but scoping it to graphical users would remove noise; consider a VM test simulating linger+SDDM login to lock this class in CI; `niri-flake-polkit` QML dialog crash ("module gtk2 is not installed") is cosmetic but crash-loops (restart counter 40) and deserves its own fix.~~ mostly done — polkit gtk2→adwaita/fusion fixed same day (15:00 session); eval guard shipped as `session-boot-audit.nix`; the linger+SDDM VM test remains open in TODO_LIST
4. Linger for `lars` is user-set (not in the repo) and intentionally left alone — the fix makes lingering safe.

## 5. Reflection

The `Wants=graphical-session.target` was added to fix an ordering nit (comment: "without it, After= is ignored…"), and the blast radius stayed invisible for weeks because the drm-healthcheck kept churning the zombie fast enough to look like "niri crashes a lot" instead of "niri should never have been running". Three independent layers now have to fail before this class recurs.

## Appendix (2026-08-18 13:00 session — self-review execution)

**Assumption loop CLOSED (§b.3 of the self-review).** The `ConditionEnvironment=XDG_SESSION_ID` fix is now fact-backed, not hypothesis:

1. `niri-session` (store path `9z4zv37h…`, `bin/niri-session` line 36) runs `systemctl --user import-environment` with **no arguments** — the entire client environment is imported into the user manager — BEFORE line 47 starts `niri.service`.
2. pam_systemd sets `XDG_SESSION_ID` in every real session's process environment — live-proven on this box: an SSH session's own shell env carries `XDG_SESSION_ID=12`, while the user manager (PID 1375) does NOT have it (grep count 0), and the live zombie niri's env lacks it.
3. Therefore: real SDDM login → pam sets the var → niri-session imports it → the condition passes. Linger boot → no import ever ran → the condition fails → no zombie. The "one-line revert" documented in §b.3 should NOT be needed.

**Regression dated (§d.5 of the self-review).** `git log -p --follow` on `platforms/common/programs/activitywatch.nix`: the fatal `Wants = lib.mkAfter ["graphical-session.target"]` entered in **`6ea92969` — 2026-08-15 00:59, "fix(activitywatch): make wayland watcher survive real boots"**. Every SDDM login after that deploy (Aug 15 → Aug 18) hit the black screen; the fix commit was itself an ordering-nit fix whose blast radius stayed invisible for 3 days.

**Follow-ups executed in the 13:00 session** (details in CHANGELOG `[Unreleased]` and TODO_LIST §2.5): eval-time `session-boot-audit` guard (negative-tested against the exact historical bug), healthcheck `ConditionEnvironment` scoping, `niri_zombie` Gatus tripwire, niri-session-manager fail-loud choice documented at `configuration.nix:320`, Qt6 gtk2 polkit root-cause fix, browser-history-agent restart-race fix, crush-daily SIGSYS fix, BTRFS metadata-pressure alert (live CRITICAL unalloc=4% was a phantom green), and the 01:50 btrbk `/data` csum-corruption forensics appended to the TODO_LIST P0 entry (already tracked by the 2026-08-17 corruption master plan).
