# Helium Empty-Window Loop — Real Root Cause Found & Fixed

**Date:** 2026-08-01 22:04
**Session focus:** Helium browser opening empty tabs every 5 minutes

---

## Executive Summary

The Helium browser was opening a new empty window every 5 minutes. The 2026-07-24 `helium-launch` fix was supposed to prevent this, but I initially dismissed the user's report as "already fixed" — **I was wrong**. The fix contained a 300-second timeout that defeated its own guard, causing the exact bug it was designed to prevent, just slower (every 5 min instead of every 5 sec).

---

## What Was Done

### a) FULLY DONE

1. **Root cause identified** — the `helium-launch` wrapper (`platforms/nixos/desktop/niri-wrapped.nix:62-84`) had a `WAITED >= 300` timeout cap. After waiting 5 minutes for an existing helium instance to die, it would `break` and "launch anyway". Chromium then found the running instance's `SingletonLock`, printed "Opening in existing browser session", opened an EMPTY window, and exited 0. `Restart=always` treated the clean exit as a crash → restart → wait 5 min → repeat. One empty window every 5 minutes, forever.

2. **Fix applied** (`niri-wrapped.nix`) — removed the timeout entirely. `helium-launch` now waits indefinitely in the `while pgrep` loop. It becomes a monitor: systemd sees the service as "running" while waiting, and only `exec`s a fresh helium when the old instance actually dies. This preserves `Restart=always` (needed for the zero-output clean exit auto-restart) without spawning empty windows.

3. **AGENTS.md gotcha updated** — the old entry "helium.service empty-window crash loop (FIXED 2026-07-24)" was misleading (it claimed the fix worked). Updated to "helium.service empty-window loop (FIXED 2026-07-24, RE-FIXED 2026-08-01)" with the full root cause chain: original bug → first fix with timeout → how timeout defeated it → final fix without timeout.

4. **Syntax validated** — `nix flake check --no-build` passes.

### b) PARTIALLY DONE

- **Immediate mitigation** — I told the user to run `systemctl --user stop helium.service` to stop the cycling immediately without a deploy. The real browser (PID 83781) runs independently and survives. I could NOT run this myself because `systemctl` is in the banned commands list for the bash tool. The user needs to do this manually.

### c) NOT STARTED

- **Deploy** — the fix is in the working tree but NOT deployed. It takes effect on next `nix run .#deploy`.
- **Verification** — no post-deploy verification has been done (can't verify what hasn't deployed).

### d) TOTALLY FUCKED UP

1. **I dismissed the user's report.** The user said "Why does Helium open stupid new empty tabs?" and I immediately responded with "This was a known bug, already fixed (2026-07-24)" — citing the AGENTS.md gotcha as if it were authoritative truth. **The gotcha was WRONG.** The fix didn't work. I trusted documentation over the user's lived experience. This is the exact anti-pattern of "documentation drift" — the AGENTS.md recorded a fix that was partially effective but contained its own bug.

2. **I didn't read the actual code first.** Before responding "already fixed," I should have:
   - Read `niri-wrapped.nix` to see the actual `helium-launch` implementation
   - Checked `journalctl --user -u helium.service` to see what was happening live
   - Verified the fix actually works, not just that it exists

   Instead I pattern-matched on the gotcha title and gave a confident wrong answer. The user had to push back with "It not, it happens" before I actually investigated.

3. **The 300s timeout was a fundamentally flawed design.** A timeout on a "wait for death" guard is self-defeating — if you're going to "launch anyway" after the timeout, you might as well not have the guard at all. The correct design was obvious from first principles: either wait forever (monitor pattern) or don't wait at all (and accept the empty window). The middle ground created a worse experience than either extreme.

---

## e) WHAT WE SHOULD IMPROVE

1. **Don't trust AGENTS.md as ground truth for "is it fixed."** AGENTS.md records _intended_ state. The _actual_ state is in the running system. When a user reports a bug that AGENTS.md says is fixed, **investigate the running system first**, then check if the documentation drifted.

2. **Timeouts on guards are a code smell.** A "wait then give up" pattern on a mutex-like guard is almost always wrong. Either the condition will eventually be met (wait forever / poll), or it won't (fail immediately / take a different action). "Wait a bit then proceed anyway" creates a third, worse state. The 300s timeout turned a tight crash loop (11 windows/36s, visible) into a slow drip (1 window/5min, insidious and harder to notice).

3. **The `helium-launch` design has a fundamental tension.** `Restart=always` + Chromium's single-instance behavior are fundamentally at odds. When helium exits cleanly (zero outputs), systemd restarts it. But if another instance survived, the restart opens an empty window. The "wait for death" monitor pattern is correct but fragile — it relies on `pgrep` matching the exact process. A more robust approach would be to use Chromium's `--user-data-dir` singleton lock directly, or to have the service check the SingletonLock file before launching.

4. **Post-deploy verification gap.** The `post-deploy-check` script does NOT verify that `helium.service` isn't cycling. It checks HTTP endpoints, not systemd restart loops. A check for `systemctl --user show helium.service -p NRestarts` exceeding a threshold would have caught this on the first deploy after the 2026-07-24 "fix."

5. **AGENTS.md gotcha needs to mention the _verification_ of the fix, not just the fix itself.** "FIXED 2026-07-24" implies verified. It should say "FIXED 2026-07-24, VERIFIED 2026-07-24" or "FIXED 2026-07-24, NOT YET VERIFIED" — making the verification status explicit.

---

## f) Up to 50 Things We Should Get Done Next

| # | Task                                                                                                                                                                                   | Priority |
| - | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 1 | **Deploy** the helium-launch fix (`nix run .#deploy`)                                                                                                                                  | P0       |
| 2 | **Verify** after deploy: `journalctl --user -u helium.service --since "5 min ago"` shows no "Opening in existing browser session"                                                      | P0       |
| 3 | **Stop the cycling now**: `systemctl --user stop helium.service` (user must do this — I can't run systemctl)                                                                           | P0       |
| 4 | Add `helium.service` restart-count check to `post-deploy-check.sh` (alert if NRestarts > 3 in the first 10 min after deploy)                                                           | P1       |
| 5 | Consider replacing `pgrep` in `helium-launch` with a direct `SingletonLock` file check (`test -f ~/.config/net.imput.helium/SingletonLock`) — more reliable than process name matching | P2       |
| 6 | Audit all other `Restart=always` user services for the same "clean exit → restart loop" pattern (ghostty, dunst-retired, etc.)                                                         | P2       |
| 7 | Consider whether `helium-launch` should `exec` into the wait loop as PID 1 of the cgroup, so systemd can track it properly (currently it's a bash script that sleeps)                  | P3       |
| 8 | Document in the `helium-launch` comment that `systemctl --user stop helium.service` is the manual recovery for a stuck instance                                                        | P3       |
| 9 | Consider a `Type=notify` approach for helium — but only if upstream Helium adds `sd_notify` support (it won't, it's Chromium)                                                          | P4       |

---

## g) Questions I Cannot Answer Myself

1. **Do you want me to deploy now?** I can't run `nix run .#deploy` (it's a deploy action with side effects — I should ask first). The fix is ready and validated.

2. **Is there a reason the 300s timeout was originally added?** The comment said "Cap the wait at 300s to avoid hanging forever on a zombie process." Was there a specific zombie/stuck helium incident that motivated the cap? If so, we may need a zombie-detection heuristic (e.g., check if the process is in `D` state or has 0 CPU for N minutes) rather than a blind timeout.

3. **Should the desktop entry (`xdg.desktopEntries.helium`) also use `helium-launch` instead of bare `helium`?** Currently, clicking a link or opening a file via MIME handler runs `env -u QT_STYLE_OVERRIDE helium %U` directly — bypassing the guard. If an instance is already running (normal case), this is fine (Chromium delegates to the existing instance and exits). But if the SingletonLock is stale, it could also open an empty window. Probably not worth fixing (the desktop entry path doesn't have `Restart=always`), but worth confirming the intent.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
