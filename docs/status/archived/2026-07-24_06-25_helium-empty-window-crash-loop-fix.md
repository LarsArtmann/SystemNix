# Status Report: Helium Empty-Window Crash Loop

**Date:** 2026-07-24 06:25
**Session scope:** Single incident — empty Chrome (Helium) windows spawning in a loop
**Status:** ~~Fix written, NOT yet deployed~~ **Deployed** — `helium-launch` wrapper is live in the comprehensive audit deploy (generation built 2026-07-24 18:14). The wrapper pgrep-checks for an existing main process before launching, preventing the empty-window loop while preserving zero-output auto-restart.

---


## The Incident

At ~05:56 today, `helium.service` entered a crash loop that spawned **11 empty browser windows in 36 seconds** before systemd's start-limit-hit killed it at 05:56:59. The user saw rapid empty windows opening.

### Root Cause (confirmed via journalctl + ps)

1. A Helium main process (PID 3851712, started Jul 23 03:53) was **still alive** — it survived whatever triggered `graphical-session.target` to restart
2. `helium.service` (HM user service in `niri-wrapped.nix`) has `Restart = "always"` — this is intentional, to auto-recover from the zero-output client death bug (documented in AGENTS.md)
3. On restart, the new `helium` invocation detected the **existing running session** and printed `Opening in existing browser session`
4. This opens an **empty window** in the existing session, then the new process **exits 0** (clean exit — it handed off to the existing instance)
5. `Restart = "always"` treats a clean exit as a failure → restarts → spawns another empty window → exits 0 → restart → **infinite loop**
6. `StartLimitBurst = 10` / `StartLimitIntervalSec = 300` finally stopped it after 11 restarts

### The smoking gun (journalctl)

```
05:56:23 Started Helium browser.
05:56:23 Opening in existing browser session.   ← handoff, exits 0
05:56:28 Scheduled restart job, restart counter is at 5.  ← Restart=always
05:56:33 ...counter is at 6
...repeats...
05:56:59 Start request repeated too quickly.
05:56:59 Failed with result 'start-limit-hit'.
```

---

## a) FULLY DONE

1. **Root cause diagnosed** — identified the "opening in existing browser session" + `Restart=always` feedback loop via `journalctl --user` and `ps aux`
2. **Fix implemented** — `helium-launch` wrapper script (`niri-wrapped.nix:62-77`) that `pgrep`s for an existing main process (`helium --ozone-platform-hint`) and sleeps in a loop until it dies before launching fresh
3. **pgrep pattern verified live** — confirmed it matches exactly 1 process (the main browser PID 3851712), NOT the renderer subprocesses (which have `--type=renderer` and lack `--ozone-platform-hint`)
4. **Syntax validated** — `nix flake check --no-build` passes (all checks passed)
5. **AGENTS.md documented** — added gotcha row "helium.service empty-window crash loop (FIXED 2026-07-24)" with root cause, fix, and the `helium-launch` wrapper reference

## b) PARTIALLY DONE

1. **Fix is NOT deployed** — written and syntax-checked, but the user needs `nix run .#deploy` for it to take effect. The running system still has the OLD `ExecStart` (bare `env -u QT_STYLE_OVERRIDE helium`)
2. **The crash loop self-stopped** (start-limit-hit), but `helium.service` is currently in `failed` state — it will NOT auto-recover until either a deploy (which runs `systemctl --user reset-failed`, confirmed in `deploy.sh:11`) or a manual `systemctl --user reset-failed helium.service`

## c) NOT STARTED

1. **Deeper root cause: why did helium survive graphical-session restart?** — The service has `PartOf = [ "graphical-session.target" ]`, which means systemd SHOULD stop helium when graphical-session stops. But PID 3851712 survived from Jul 23. Either: (a) `PartOf` didn't propagate the stop, (b) helium ignored SIGTERM and systemd didn't escalate to SIGKILL fast enough, or (c) graphical-session never actually stopped and something else restarted `helium.service`. **Not investigated.** My fix is a band-aid on the restart-loop symptom.
2. **Timeout on the wait loop** — the `helium-launch` wrapper has no timeout. If a helium process is stuck in a zombie/hung state but never dies, the wrapper waits forever and the service appears "active (running)" with no browser launching. A timeout (e.g. 300s) with forced exit would be more robust.
3. **Audit of other services for the same bug class** — any `Restart=always` service launching a binary that "opens in existing session" and exits 0. Likely unique to browsers, but not verified.

## d) TOTALLY FUCKED UP

Nothing catastrophic. But these are real mistakes:

1. **I didn't give the user an emergency stop command.** The user was seeing windows open RIGHT NOW. The loop self-stopped, but if it hadn't, I should have immediately said: `systemctl --user stop helium.service` to kill it. I jumped to diagnosis instead of triage.
2. **I didn't flag the immediate state clearly enough.** After my fix, the service is in `start-limit-hit` / `failed` state. The user's helium auto-restart is currently DEAD until deploy or manual reset. I buried this in the last line.
3. **AGENTS.md table padding** — the row I added has excessive trailing whitespace to match the table format, but I didn't verify it renders cleanly. Minor but sloppy.

## e) WHAT WE SHOULD IMPROVE

1. **Add a timeout to `helium-launch`** — wait at most N seconds for existing instance to die, then launch anyway (or give up). Prevents infinite hang on zombie processes.
2. **Investigate why `PartOf = [ "graphical-session.target" ]` didn't stop helium** — this is the actual root cause. If PartOf worked correctly, the service wouldn't restart while the old process lived. Possible fixes: `BindsTo` instead of `PartOf` (but AGENTS.md warns `BindsTo` kills niri on deploy), or a `TimeoutStopSec` + `KillSignal` escalation.
3. **Consider `ExecStartPre` guard instead of wrapper** — a cleaner pattern: use `ExecStartPre` to wait for the old process to die (or kill it), then `ExecStart` launches helium directly. Keeps the ExecStart line clean.
4. **Consider whether the zero-output auto-restart is even worth this complexity** — the original purpose was recovering from display hotplug crashes. An alternative: don't auto-restart, let the user relaunch manually. Fewer moving parts.

## f) Next Actions (related to this session)

1. **Deploy the fix** — `nix run .#deploy` (also clears the start-limit via `deploy.sh:11`)
2. **Add timeout to `helium-launch` wrapper** — prevent infinite hang
3. **Investigate PartOf propagation failure** — why did helium survive graphical-session restart?
4. **Test the fix post-deploy** — simulate: kill helium main process, confirm service restarts cleanly; OR restart graphical-session while helium runs, confirm no empty-window loop
5. **Audit other `Restart=always` HM services** — for the same "exits 0 on handoff" bug class
6. **Consider `KillMode = mixed` + `TimeoutStopSec`** on helium.service to ensure clean shutdown on graphical-session stop
7. **Clean up AGENTS.md table padding** if it renders poorly
8. **Add a Gatus/system-health metric** for helium.service start-limit-hit state (the `system-health` module already tracks systemd service states — verify helium is covered)

---

## Self-Critique Summary

The diagnosis was fast and correct. The fix is pragmatic and consistent with existing patterns (`ssh-suspend-guard` in the same file uses the same poll-loop style). But I **failed at triage** — I should have led with "run this to stop it NOW" before diving into diagnosis. The user was actively watching windows spawn. I also didn't clearly communicate that the auto-restart is currently dead until deploy. The fix itself is a band-aid; the deeper PartOf question is uninvestigated.

---

## Item Resolution (2026-07-30)

Helium empty-window fix. DONE: helium-launch wrapper deployed, pgrep-check prevents empty-window loop. All 3 items resolved.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
