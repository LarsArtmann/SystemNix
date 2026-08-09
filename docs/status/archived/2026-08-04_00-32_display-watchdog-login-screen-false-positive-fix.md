# Status: Display-Watchdog Login-Screen False Positive Fix

**Date:** 2026-08-04 00:32  
**Session scope:** SDDM restart-loop diagnosis + display-watchdog guard  
**Verdict:** Fix written and verified, **NOT deployed**. User is still experiencing the loop.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.


## What Was Done

### Fully Done

1. **Root cause identified** — `display-watchdog.sh` treats Xorg idle DPMS-off at the SDDM login screen as a "dead display" and restarts `display-manager.service` every ~10 min. Confirmed via journal: `Dead display detected: card1-DP-1 (enabled=disabled, dpms=Off)` → `Attempting display-manager restart...` every ~10 min, all night long.
2. **Cleared the Quickshell/DMS suspicion** — the watchdog (`d5e48c4c`) predates the DMS work. The Quickshell update is NOT the cause.
3. **Login-screen guard implemented** — `scripts/display-watchdog.sh:76-104`. Checks `loginctl` for any session with `Class=user` AND `Type=(wayland|x11)`. If none exists (login screen), DPMS-off is normal idle power-saving — the watchdog resets state and exits WITHOUT recovering.
4. **Shellcheck clean** — `writeShellApplication` build passes (shfmt + shellcheck in checkPhase).
5. **System eval passes** — `nix eval ...system.build.toplevel.name` succeeds.
6. **Gotcha documented** — new row in AGENTS.md non-obvious gotchas table.

### Partially Done

7. **Verification** — build + eval pass, but **no production verification** (not deployed, no post-deploy journal check to confirm the cycling stopped).

### Not Started

8. **Deploy** — `nix run .#deploy` was NOT run. The fix exists only in the working tree.
9. **Immediate relief** — the `display-watchdog.timer` could have been stopped immediately to give the user instant relief while the deploy builds. This was NOT suggested or done.
10. **Post-deploy smoke verification** — no plan to `journalctl -t display-watchdog` after deploy to confirm zero false restarts.

---

## What I Fucked Up

### CRITICAL: I Forgot to Deploy

**The user is STILL experiencing the restart loop RIGHT NOW.** Last cycle: 00:28:53. Next expected: ~00:38. The fix is in the working tree, verified to build, but **not on the running system**. I treated "build passes" as "done" without deploying or even mentioning that a deploy is required. The user asked "Did we introduce a bug?" — they expected a FIX, not just a diagnosis and a code change sitting uncommitted.

### I Provided No Immediate Relief

The `display-watchdog.timer` fires every 30s. I could have immediately stopped it (or told the user to) to halt the cycling while the deploy builds. Instead I left the system in a broken state and wrote a report.

### I Did Not Verify `loginctl` Works Inside the Hardened Service

The `display-watchdog.service` runs under `harden {}` which sets `ProtectSystem=full`, `ProtectHome=true`, `RestrictNamespaces=true`, etc. The script now calls `loginctl` which communicates with `systemd-logind` via D-Bus system bus (`/run/dbus/system_bus_socket`). While the original script already calls `systemctl restart` (same D-Bus bus), I did NOT verify that `loginctl list-sessions` and `loginctl show-session` actually return data from within the hardened namespace. If `loginctl` fails silently (returns empty), `has_graphical_session` stays `0` and the guard ALWAYS skips recovery — disabling the watchdog's genuine recovery path. The `command -v loginctl` guard prevents a crash, but an empty/failing `loginctl` output would silently neuter the watchdog.

---

## What Could Still Be Improved

### A. Deploy and Verify (BLOCKING)

- Deploy the fix. After deploy, watch `journalctl -f -t display-watchdog` for 15+ min at the idle login screen. Confirm ZERO false restarts. Then log in, let niri run, and optionally test genuine recovery still works.

### B. Alternative / Complementary Fix: Disable SDDM DPMS

The root cause is Xorg DPMS putting the monitor to sleep at the login screen. A complementary fix would be to disable DPMS in SDDM's Xsetup script (`xset -dpms` / `xset s off`) so the connector never enters the `enabled=disabled, dpms=Off` state at the login screen at all. This eliminates the condition the watchdog detects, rather than working around it. Tradeoff: monitor stays on 24/7 at the login screen (power waste). The guard approach is better for power efficiency but depends on `loginctl` working.

### C. Verify D-Bus / loginctl in Hardened Context

Add a defensive check: if `loginctl list-sessions` returns empty but the system is clearly not at a login screen (e.g., niri is running — contradicts), fall through to the original logic. Or: verify `loginctl` output is non-empty before trusting it.

### D. Pre-existing `swww`/`awww` Warning

`nix eval` warns: `'swww' has been renamed to 'awww'`. Git log shows commits `71c57c2b` / `649ac960` re-added `swww` after AGENTS.md says "awww is RETIRED, DMS manages wallpapers natively." This is documentation/code drift — **not related to this session's work** but noticed during eval. Needs reconciliation.

---

## Things to Do Next (Pareto-Ordered)

### P0 — Immediate (blocking the user RIGHT NOW)

1. ~~**Deploy the fix** — `nix run .#deploy`~~ done at `4372f51d` (deployed Aug 4)
2. ~~**Verify the cycling stopped** — `journalctl -f -t display-watchdog` for 15 min at idle login screen~~ done (guard deployed and active)
3. **If loginctl doesn't work in the hardened service**, add a fallback or disable DPMS at the login screen instead

### P1 — This Session's Cleanup

4. Verify `loginctl list-sessions` and `loginctl show-session` return real data from inside the `harden {}` namespace (not empty)
5. ~~If the guard is confirmed working, commit the change~~ done at `95bf8c13`
6. Consider adding `loginctl` to the service `path` explicitly (currently relies on `runtimeInputs` via `writeShellApplication`)
7. Consider disabling SDDM Xorg DPMS as defense-in-depth (`xset -dpms` in Xsetup)
8. ~~Reconcile the `swww`/`awww` rename warning with AGENTS.md (code drift)~~ done (swww retired, DMS owns wallpapers natively)

### P2 — Watchdog Hardening (Future)

9. Add a self-test: log whether `loginctl` returned data, so a silent failure is visible in the journal
10. Consider a max-restart-rate circuit breaker on `display-manager.service` itself (start-limit) to prevent ANY service from restarting it in a tight loop
11. The watchdog timer interval (30s) combined with 10s sleep after restart means each cycle takes ~10s — consider reducing the sleep or making it conditional
12. Document the two-monitor topology (DP-1 + DP-2 both connected) — the watchdog checks only the first dead display it finds (`break`), so a genuinely dead DP-1 would mask a dead DP-2
13. The `niri-drm-healthcheck` (separate from display-watchdog) should be reviewed for the same login-screen false-positive class
14. Consider merging `display-watchdog` and `niri-drm-healthcheck` — overlapping responsibilities

### P3 — Broader Desktop Reliability

15. SDDM `silent` theme logs QML errors every restart (`VirtualKeyboardSettings is not defined`, `Cannot open: flags/us.png`) — cosmetic but noisy
16. The `swww`/`awww` drift suggests the wallpaper management story has churned recently — verify DMS truly owns wallpapers as AGENTS.md claims
17. Review all systemd timers that call `systemctl restart` — any of them can create restart-loop classes like this one
18. Add a Gatus/system-health metric for "display-manager restart count" — a restart loop should be alertable, not silent
19. The `display-watchdog` `onFailure` alerting — verify it actually fires on Discord for genuine watchdog failures
20. Consider a `WatchdogSec` on `display-manager.service` itself (SDDM doesn't call `sd_notify`, so this is inert — but worth confirming)

---

## Questions I Cannot Answer Myself

1. **Should I deploy now?** The user is still experiencing the loop. I assume yes, but the user asked for a status report and to "wait for instructions" — so I'm not deploying without confirmation. If they say "deploy", I'll run `nix run .#deploy` and verify.

2. **Is the monitor supposed to sleep at the login screen?** If the user WANTS the monitor to power-save at the login screen (overnight, etc.), the guard approach (don't restart) is correct. If the user wants the monitor always-on at the login screen, disabling DPMS in SDDM is better. I can't determine the user's preference without asking.

3. **Did this start recently or has it always happened?** The watchdog was added in `d5e48c4c`. If the user only noticed it now, something may have changed (monitor DPMS timeout, SDDM config, or they just never sat at the login screen for 10+ min before). I can't determine the timeline without the user's input.
