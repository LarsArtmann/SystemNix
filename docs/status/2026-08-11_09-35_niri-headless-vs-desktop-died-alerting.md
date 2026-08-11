# Status Report: 2026-08-11 09:35 — Niri Headless vs Desktop-Died Alerting

**Session scope:** Implementing "intentionally headless" vs "desktop died" distinction for niri monitoring, replacing the naive `niri_running` alert that fired false positives when the user was SSH-only.

---

## a) FULLY DONE

1. **Niri health metrics overhaul** (`modules/nixos/desktop/niri-config.nix:158-210`) — Rewrote the `niri-health-metrics` script to emit 3 new metrics alongside the existing 3:
   - `niri_graphical_session` — 1 if user has a wayland/x11 session (via `loginctl list-sessions` + `show-session`, same pattern as `display-watchdog.sh:83-99`)
   - `niri_desktop_died` — 1 if `graphical_session == 1 && niri_running == 0` (the real alert condition)
   - `niri_crash_loop` — 1 if `niri_restarts_10m >= 3` (matches niri's `StartLimitBurst=3`)
   - Existing metrics preserved: `niri_running`, `niri_restarts_10m`, `niri_drm_errors_30s`

2. **Gatus alert replacement** (`modules/nixos/services/gatus-config.nix:603-635`) — Replaced the single naive "Niri Compositor" alert (which fired on any `niri_running` absence) with 3 checks:
   - **"Niri Compositor"** — liveness only (metrics collection working, `[BODY] == pat(*niri_running*)`, no alert)
   - **"Niri Desktop Died"** — alerts on `niri_desktop_died 0` absence (i.e. `niri_desktop_died 1`) — niri crashed while user has a graphical session
   - **"Niri Crash Loop"** — alerts on `niri_crash_loop 0` absence — niri restarting 3+ times in 10 min

3. **Eval verification** — `nix eval` confirms both the metrics script and Gatus endpoints produce correct output. `nix flake check --no-build` passes all checks.

4. **AGENTS.md documentation** (`AGENTS.md:68`) — Added "Intentionally headless vs desktop died" entry to the Gatus Health Check Design Patterns section, documenting the new metric semantics and the `loginctl`-based session detection approach.

5. **Initial diagnosis from prior session** — Fully diagnosed Helium down: root cause was no graphical session (SDDM at greeter, no auto-login). Correctly identified the real gap: monitoring couldn't distinguish "intentionally headless" from "desktop died." This session implemented the fix.

---

## b) PARTIALLY DONE

1. **Status report from prior session** (`docs/status/2026-08-11_09-22_helium-down-diagnosis-desktop-session-gap.md`) — Contains the full diagnosis and 50-item todo list. The auto-login recommendation in that report was **wrong** — the user clarified they sometimes want SSH-only operation without the desktop. The report should be amended but hasn't been yet.

2. **AGENTS.md Helium gotcha** — The existing gotcha says "Helium zero-output death — When all outputs disconnect, Helium exits cleanly. `Restart=always` + `RestartSec=5`." This is still correct but doesn't mention that Helium won't start at all without `graphical-session.target` (which requires SDDM login). Minor gap — the new monitoring entry covers the alerting side but not the service dependency chain.

---

## c) NOT STARTED

1. **Deploy** — Changes are written and eval-verified but NOT deployed. The new metrics won't take effect until `nix run .#deploy`.
2. **Runtime verification** — Cannot verify the new metrics actually appear in `/metrics` output until deploy. The `niri_desktop_died` and `niri_crash_loop` metrics are computed in bash and emitted unconditionally (value 0 or 1), so they should always be present — but phantom metric rules say "verify at runtime." This is a bash script writing to a textfile collector, not a Rust lazy serializer, so phantom metrics shouldn't apply, but verification is still needed.
3. **Gatus pattern lint** — The `gatus-pattern-lint` flake check passed, but I didn't explicitly verify the new `pat(*niri_desktop_died 0*)` and `pat(*niri_crash_loop 0*)` patterns pass the linter. They should — no `?` or `+` characters — but explicit confirmation would be best practice.
4. **Pre-deploy check update** — `scripts/pre-deploy-check.sh` doesn't verify niri metrics presence. The new metrics should be added to the metric presence validation section (section 10).
5. **Post-deploy check** — `scripts/post-deploy-check.sh` doesn't check desktop session state. A warning when deploying to a desktop system with no graphical session would be useful.

---

## d) TOTALLY FUCKED UP

1. **Wrong recommendation in prior status report** — The 09:22 report recommended SDDM auto-login as the #1 fix. The user explicitly pushed back: "sometimes I just do not want to use my PC directly but only via ssh or the web." Auto-login would force the desktop to start on every boot, defeating the SSH-only workflow. The correct fix was monitoring that distinguishes intentional headless from desktop crash — which is what we implemented this session. The prior report should be amended to strike the auto-login recommendation.

2. **Didn't check if `loginctl` is in the `niri-health-metrics` runtimeInputs** — The script uses `loginctl` but the `runtimeInputs` list is `[ procps systemd gawk coreutils ]`. `loginctl` comes from `systemd` package, so it IS covered. But I didn't explicitly verify this — I assumed it from the existing `systemd` dependency. If `loginctl` were in a separate package (it's not — it's part of `systemd`), the script would silently fail (`2>/dev/null` on the loginctl calls) and `graphical_session` would always be 0, meaning `desktop_died` would never fire. This is a correctness risk that should be verified post-deploy.

3. **Didn't add `niri_graphical_session` to a Gatus visible check** — There's no Gatus endpoint that exposes whether `niri_graphical_session` is 1 or 0. This metric is only used internally to compute `desktop_died`. If the loginctl detection breaks silently (see point 2), there's no way to see from Gatus that `graphical_session` is stuck at 0. A "Niri Graphical Session" info-only check (no alert) would make the detection visible and debuggable.

---

## e) WHAT WE SHOULD IMPROVE

1. **Add a debug visibility metric to Gatus** — Expose `niri_graphical_session` as a non-alerting Gatus check so we can see whether the loginctl detection is working. Without this, a silent loginctl failure is invisible.

2. **Test the loginctl detection path** — After deploy, manually verify: (a) `loginctl list-sessions` output when SSH-only (should show no wayland/x11 sessions), (b) same when logged in via SDDM (should show wayland session), (c) the metrics file at `/var/lib/prometheus-node-exporter/textfile_collectors/niri.prom` contains correct values in both states.

3. **Consider `niri_desktop_died` grace period** — Currently, if niri crashes and `Restart=always` kicks in within 2s, the 30s metrics collection interval might catch the brief `niri_running=0` window and set `desktop_died=1` even though niri auto-recovered. A grace period (e.g. "niri not running for 2+ consecutive checks = 60s") would prevent flapping. The `niri_crash_loop` metric already handles the "repeated crashes" case.

4. **Separate "desktop died" from "desktop never started"** — `niri_desktop_died` fires when `graphical_session == 1 && niri_running == 0`. But if the user logs in via SDDM and niri fails to start (start-limit-hit), `graphical_session` is 1 (loginctl shows wayland) but niri is 0. This IS a valid alert condition, but the alert message says "crashed" when it should say "not running." Minor wording issue.

5. **Remove the old "Niri Compositor" liveness check** — It still has `[BODY] == pat(*niri_running*)` with no alert. This is now redundant with the "Niri Desktop Died" check. Keeping it as a pure liveness check (metrics collection working) has value, but the `niri_running` presence check is redundant — if the metrics file exists at all, `niri_running` will be in it (value 0 or 1). The check could be simplified to just `[STATUS] == 200`.

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

### Critical (deploy & verify)

1. **Deploy the changes** — `nix run .#deploy` to activate the new metrics and Gatus checks
2. **Verify metrics at runtime** — `cat /var/lib/prometheus-node-exporter/textfile_collectors/niri.prom` after deploy; confirm all 6 metrics present
3. **Verify `loginctl` detection** — When SSH-only: `niri_graphical_session` should be 0, `niri_desktop_died` should be 0 (no alert). When logged in: `niri_graphical_session` should be 1
4. **Verify Gatus sees the new endpoints** — Check Gatus UI for "Niri Desktop Died" and "Niri Crash Loop" endpoints
5. **Amend the 09:22 status report** — Strike the SDDM auto-login recommendation; add correction noting the user's SSH-only workflow

### High priority

6. **Add "Niri Graphical Session" debug check to Gatus** — Non-alerting check on `niri_graphical_session` metric for visibility
7. **Add `niri_desktop_died` and `niri_crash_loop` to pre-deploy-check.sh** — Section 10 metric presence validation
8. **Add grace period to `niri_desktop_died`** — Require 2+ consecutive checks (60s) of `niri_running == 0` before setting `desktop_died=1`, to avoid flapping during niri auto-restart
9. **Investigate `browser-history-server` 100% CPU** — Flagged in prior session, still uninvestigated
10. **Investigate load average 35-46** — Still abnormally high, WDT crash risk

### Monitoring improvements

11. **Add Gatus check for `niri_drm_errors_30s`** — Alert when DRM errors > 0 for 2+ consecutive checks
12. **Add Gatus check for `niri_restarts_10m`** — Info metric, alert only if > 0 but < 3 (single restart, not crash loop)
13. **Add Helium process liveness to metrics** — `helium_running` metric (pgrep for `helium --ozone-platform-hint`), with `desktop_died` semantics (only alert if graphical session active)
14. **Add DMS process liveness to metrics** — `dms_running` metric, same pattern
15. **Add `graphical_session_active` to system-health module** — Generic metric for graphical session state, not niri-specific
16. **Add desktop services summary metric** — `desktop_services_down_count` = count of `graphical-session.target.wants` services that are inactive when graphical session is active
17. **Add SDDM greeter state metric** — `sddm_greeter_active` = 1 if SDDM is at login screen (no user session), for monitoring boot state
18. **Add boot-to-graphical-session timer** — Metric tracking seconds from boot to first graphical session activation
19. **Add Discord alert for "graphical session started but niri failed to start within 60s"** — More specific than "desktop died"
20. **Add Gatus endpoint group "Desktop"** — Separate desktop-related checks from "Monitoring" group for clarity

### Script improvements

21. **Add `loginctl` to `runtimeInputs` explicitly** — It's covered by `systemd` but explicit is better than implicit
22. **Add error handling for `loginctl` failure** — If `loginctl` fails, log a warning and set `graphical_session=0` (fail safe — no false alert)
23. **Add `niri_desktop_died` state persistence** — Like `niri-drm-healthcheck.sh`, use a state file to track consecutive `niri_running=0` checks and only set `desktop_died=1` after N consecutive failures
24. **Refactor loginctl session detection into a shared helper** — Both `display-watchdog.sh` and `niri-health-metrics` now have the same ~15 lines of loginctl code. Extract to a shared script or lib function
25. **Add `jq` to runtimeInputs** — Consider using `jq` for more robust loginctl JSON output parsing (if loginctl supports JSON output)

### Documentation

26. **Update AGENTS.md "Desktop" section** — Add note about the graphical-session dependency chain: SDDM login → graphical-session.target → [helium, dms, swayidle, sway-audio-idle-inhibit]
27. **Add "Intentionally headless" runbook to docs/** — How to operate SSH-only, what to expect, what alerts should NOT fire
28. **Add "Desktop died" runbook to docs/** — Step-by-step: check loginctl, check niri journal, check DRM state, restart niri
29. **Update CHANGELOG.md** — Add entry for the headless vs desktop-died monitoring distinction
30. **Document the 6 niri metrics in AGENTS.md** — Full metric inventory with semantics and alert conditions
31. **Update FEATURES.md** — Add "Niri desktop-died detection" to the monitoring features table

### Testing

32. **Add VM test for niri-health-metrics** — Test that the script produces correct output when niri is running and not running
33. **Add VM test for loginctl detection** — Mock loginctl sessions and verify `graphical_session` is set correctly
34. **Add VM test for Gatus endpoint configuration** — Verify the 3 niri Gatus endpoints are configured correctly
35. **Test `niri_desktop_died` doesn't fire on boot** — After boot with no login, metrics should show `desktop_died=0`
36. **Test `niri_desktop_died` fires after session start + niri kill** — Start session, kill niri, verify `desktop_died=1` within 60s

### Architecture

37. **Consider a generic "session-aware alerting" pattern** — The `loginctl` session detection is now used in 2 scripts. Formalize as a helper that other metrics scripts can use
38. **Evaluate moving niri metrics to a proper Prometheus exporter** — Instead of bash textfile, consider a lightweight Go/Rust exporter that can track state across invocations (grace periods, consecutive counts)
39. **Consider systemd unit state as an alternative to pgrep** — `systemctl --user is-active niri.service` is more authoritative than `pgrep -x niri`
40. **Add `graphical-session.target` state to system-health module** — Currently niri-specific; a generic `graphical_session_active` metric in system-health would serve all desktop services

### Security & reliability

41. **Verify `loginctl` works from the `niri-health-metrics` service context** — The service runs as root with `harden {}`, which includes `ProtectSystem`. Does `loginctl` need DBus access that might be restricted?
42. **Add `loginctl` to `ReadWritePaths` or `PrivateTmp`** — Verify the service has enough permissions to run loginctl
43. **Check if `ProtectSystem=full` blocks loginctl** — The `niri-health-metrics` service uses `harden { MemoryMax = "1G"; ReadWritePaths = [...]; }` which sets `ProtectSystem=full`. loginctl needs `/run/systemd` or `/run/dbus` access — verify this isn't blocked
44. **Add fallback if loginctl is unavailable** — If loginctl fails (missing binary, DBus error), the script should fail safe: `graphical_session=0` (no false alert)
45. **Review `niri-health-metrics` timer interval** — 30s is good for alerting but may be too frequent for a script that calls `journalctl --grep` (IO-heavy). Consider 60s.

### Future enhancements

46. **Add "desktop session duration" metric** — Track how long the graphical session has been active
47. **Add "desktop services startup time" metric** — Time from graphical-session.target activation to all wants services active
48. **Consider Pushover/Discord notification on session state change** — Not just on failure, but on state transitions (headless → desktop, desktop → headless)
49. **Add `niri_session_state` enum metric** — 0=headless, 1=greeter, 2=starting, 3=running, 4=crashed, 5=crash-looping
50. **Add "last graphical session" timestamp metric** — When was the last time a graphical session was active, for debugging "was the desktop ever up today?"

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Should I deploy now, or do you want to review the changes first?** — The changes are eval-verified and `nix flake check --no-build` passes, but deploying will restart `niri-health-metrics` (via `restartTriggers`) and Gatus. I can't deploy without your approval since `nix run .#deploy` requires sudo and builds the full system.

2. **Do you want the `niri_desktop_died` grace period (item 8), or is immediate alerting preferred?** — Without a grace period, a 2-second niri restart window caught by the 30s metrics interval could cause a false alert. With a grace period (2 consecutive checks = 60s delay), real crashes are reported 60s slower. I can't assess your alert noise tolerance vs detection speed preference.

3. **Should I amend the 09:22 status report to strike the auto-login recommendation, or leave it as-is for historical accuracy?** — The report contains a wrong recommendation (auto-login). Striking it with a correction note preserves history while preventing future readers from acting on it. Leaving it preserves the raw session state but could mislead. I can't decide your documentation philosophy.

---

## Session Summary

**Time spent:** ~20 minutes (including prior diagnosis session)
**Files modified:** `modules/nixos/desktop/niri-config.nix`, `modules/nixos/services/gatus-config.nix`, `AGENTS.md`
**Files created:** `docs/status/2026-08-11_09-22_helium-down-diagnosis-desktop-session-gap.md` (prior), this report
**Key decision:** User clarified that "intentionally headless" is a valid state — monitoring must distinguish it from "desktop died"
**Implementation:** `loginctl` session detection (same pattern as `display-watchdog.sh`) → `niri_graphical_session` metric → `niri_desktop_died` computed flag → Gatus alert only when desktop died, not when headless
**Verification:** `nix eval` passes, `nix flake check --no-build` passes, Gatus endpoint config verified via eval
**Not yet done:** Deploy, runtime verification, grace period, debug visibility metric
