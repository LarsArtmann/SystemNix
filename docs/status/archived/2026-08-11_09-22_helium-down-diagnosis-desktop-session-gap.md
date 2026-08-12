# Status Report: 2026-08-11 09:22 — Helium Down Diagnosis & Desktop Session Gap

**Session scope:** Diagnosing "Why is Helium down?!?" — root cause analysis of inactive `helium.service`.

> **Correction (2026-08-11 09:35):** The recommendation below to enable SDDM auto-login was wrong. The user clarified that SSH-only operation is intentional and must remain valid. The correct fix was implemented in a follow-up report: session-aware monitoring that distinguishes "intentionally headless" from "desktop died". See `2026-08-11_09-35_niri-headless-vs-desktop-died-alerting.md`.

---

## a) FULLY DONE

1. **Helium service diagnosis** — Root cause identified: `helium.service` is inactive because `graphical-session.target` never activated, because niri compositor never started, because SDDM is sitting at the greeter on tty2 waiting for physical login. No auto-login configured. Full evidence chain documented with 8+ independent checks.

2. **Eliminated all other Helium crash modes** — Verified each known failure mode from AGENTS.md gotchas and ruled them out:
   - `helium-launch` binary EXISTS at the store path in the service file (`/nix/store/af1mx5j2pw37x9ca4gjcjz60456j40wy-helium-launch/bin/helium-launch`) — not a stale path
   - `helium` package exists in nix store (`4y35kqs4cakab5bj80z8prmfcr7r08hk-helium-0.15.3.1`)
   - No zombie Helium process matching `helium --ozone-platform-hint` — zero-output death not the cause
   - No `start-limit-hit` — service is `inactive (dead)`, not `failed`
   - Journal shows zero entries — service was never invoked, not crashed
   - `graphical-session.target.wants/` correctly contains `helium.service` — wiring is correct

3. **Niri installation verification** — Confirmed niri binary, systemd user units, and `graphical-session.target` are all properly installed in `/etc/systemd/user/`. The niri package (`niri-unstable-2026-08-02-feb3e43`) has correct bundled units. The configuration is sound — the issue is operational (no one logged in), not configuration.

4. **Deploy freshness check** — Last deploy at 07:23 today, boot at 16:28 yesterday. System was deployed but never had a graphical session since boot.

---

## b) PARTIALLY DONE

1. **SDDM auto-login** — Identified that `display-manager.nix` does NOT configure auto-login (`services.displayManager.autoLogin`). The config only sets `defaultSession = "niri"`. ~~The recommended fix was to enable auto-login; this was rejected by the user~~. The user clarified that SSH-only operation is intentional, so the real fix is session-aware monitoring (implemented in the follow-up report).

2. **Load average investigation** — Noted load average of 35-46 with `browser-history-server` at 100% CPU and PMA at 70%. Did not investigate further — out of scope for the Helium diagnosis, but flagged as a concern.

---

## c) NOT STARTED

1. ~~SDDM auto-login implementation~~ — Not applicable. User rejected auto-login; monitoring fix implemented instead.
2. **Post-deploy verification for desktop services** — The pre/post-deploy checks (`scripts/pre-deploy-check.sh`, `scripts/post-deploy-check.sh`) do not verify graphical session activation. A post-deploy check that detects "no graphical session active after deploy" would have caught this immediately.
3. **Gatus monitoring for niri/Helium liveness** — `niri-health-metrics` collects `niri_running` as a Prometheus metric, but no Gatus alert fires when niri is down for an extended period. The metric exists but the alert doesn't.
4. **Session-start notification** — No mechanism alerts the user (e.g., via Discord) when the system reboots and no graphical session starts within N minutes.

---

## d) TOTALLY FUCKED UP

1. ~~No auto-login on a single-user desktop~~ — *Correction:* auto-login is intentionally disabled. The real gap is that monitoring could not distinguish "no one logged in" from "desktop crashed while logged in". That is fixed in the follow-up report.

2. **No alerting for "desktop is down"** — Gatus monitors 79+ endpoints but NONE of them detect "niri compositor is down" or "graphical session never started." The `niri_running` metric is collected to a textfile but no Gatus endpoint checks it. The system can be in a headless state for 17+ hours (as demonstrated this session) with zero alerts. Monitor365 even logs "no DISPLAY or WAYLAND_DISPLAY found" every 2 seconds — a clear signal — but it's just a WARN log, not an alert.

3. **`systemctl` blocked by Crush tool constraints** — Could not run `systemctl --user status` or `journalctl --user` directly. Had to infer state indirectly via `pgrep`, `loginctl`, `ls` on config paths, and `journalctl` (system-level only). This worked but was slower and less precise than reading the actual service status output. The `journalctl --user` queries returned "No entries" which was actually diagnostic (service never started), but having the raw `systemctl --user status` output would have been faster.

---

## e) WHAT WE SHOULD IMPROVE

1. ~~Add SDDM auto-login~~ — Rejected. Single-user desktop should remain capable of SSH-only/headless operation.

2. **Add Gatus alert for niri liveness** — ~~The `niri_running` Prometheus metric already exists. Add a Gatus endpoint that checks `pat(*niri_running 1*)` on the node-exporter metrics endpoint with a Discord alert. If niri is down for >10 minutes after boot, alert.~~ Implemented in follow-up: session-aware alerts for `niri_desktop_died` and `niri_crash_loop`, plus a non-alerting debug check for `niri_graphical_session`.

3. **Add post-deploy check for graphical session** — `post-deploy-check.sh` should verify that `graphical-session.target` is active when deploying to a desktop system. If not, warn (not fail — headless deploys are valid).

4. **Add boot-time graphical session watchdog** — A systemd timer that checks 5 minutes after boot: is `graphical-session.target` active? If not, send a Discord alert. This would have caught the 17-hour headless state immediately.

5. **Investigate `browser-history-server` 100% CPU** — This is a new service (recently deployed) running at 100% CPU. Could be a crash loop, a bad query, or a migration that's stuck. Needs investigation.

6. **Load average 35-46 is abnormal** — Even with heavy services, this suggests multiple processes are CPU-bound simultaneously. PMA at 70% + browser-history at 100% + 10+ Crush instances is a recipe for WDT crashes on this hardware.

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

> **Note:** Items below were harvested into TODO_LIST.md / ROADMAP.md where actionable. Done items are struck through.

### Critical (do first)

1. ~~Enable SDDM auto-login for user `lars` in `display-manager.nix` — prevents headless state after every reboot~~ — Rejected by user; implement session-aware monitoring instead (done in follow-up report)
2. ~~**Add Gatus alert on `niri_running` metric**~~ done at `ae02f5a6` (replaced with session-aware `niri_desktop_died`) — Discord alert when niri is down >10 min
3. ~~**Investigate `browser-history-server` 100% CPU**~~ done at `a1223f22` (root-caused to SQLite DSN crash loop) — new service, possibly stuck in a loop
4. **Investigate load average 35-46** — abnormally high, WDT crash risk on QLC NAND hardware
5. **Add post-deploy check for `graphical-session.target`** — warn if desktop system has no graphical session after deploy

### High priority

6. **Add boot-time graphical session watchdog timer** — alert via Discord if no graphical session within 5 min of boot
7. **Review PMA CPU/memory** — 70% CPU, 6.7% MEM (6.6 GB RSS) — check if `MemoryHigh=6G` / `CPUQuota=200%` limits from the 2026-08-09 fix are still in effect
8. **Check if PMA `isNothingToCommit()` upstream fix** was deployed — the AGENTS.md notes the fix but commit `3ef0f26a` says "re-enable PMA after upstream build fixes"
9. **Review 10+ concurrent Crush instances** — 10+ `crush -y` processes consuming 5-16% CPU each. Are these all intentional? Could be orphaned sessions.
10. **Add Gatus alert for Helium liveness** — check `pgrep helium` or a process metric, not just the service (service can be "active" while browser is hung)

### Medium priority

11. **Document "no SDDM auto-login" gotcha in AGENTS.md** — under Desktop section, note that auto-login is intentionally enabled/disabled and why
12. **Add `niri-session-manager` to post-deploy restart list** — `deploy.sh` restarts 8 provisioner oneshots; should also restart niri-session-manager if graphical session exists
13. **Review Monitor365 WARN spam** — "no DISPLAY or WAYLAND_DISPLAY found" logged every 2s is noisy; should log once and suppress until session starts
14. **Add disk space check for coredumps** — AGENTS.md mentions Helium/clickhouse/nix coredumps; verify coredump handling is configured
15. **Verify `display-watchdog` behavior when no session** — it correctly says "display idle/DPMS-off is normal" but could it auto-trigger SDDM login?

### Low priority

16. **Add `graphical-session.target` status to system-health metrics** — expose as Prometheus metric for historical tracking
17. **Consider `sddm-autologin` security tradeoff** — document that full-disk-encryption (if any) still requires password, so auto-login is safe
18. **Review SDDM Catppuccin theme** — verify it renders correctly on the physical display (can't verify remotely)
19. **Add niri session crash recovery** — if niri crashes 3x in 60s (StartLimitBurst=3), send Discord alert before giving up
20. **Review `niri-drm-healthcheck` timer** — it runs every 60s but can't start niri if SDDM hasn't logged in; clarify its role in recovery
21. **Add HOME-reading services check** — services that need `$HOME` should use `%h` specifier; verify all `graphical-session.target.wants` services comply
22. **Check `dms.service` startup dependency** — DMS is in `graphical-session.target.wants`; if graphical session never starts, DMS never starts, desktop shell is invisible
23. **Review `swayidle` / `sway-audio-idle-inhibit`** — both in `graphical-session.target.wants`; verify they don't interfere with auto-login
24. **Add SSH MOTD warning when no graphical session** — when user SSHs in and `graphical-session.target` is inactive, print a warning
25. **Consider `loginctl unlock-sessions` after auto-login** — ensure SDDM auto-login doesn't leave sessions locked

### Documentation

26. **Update AGENTS.md with auto-login decision** — document whether auto-login is enabled and the rationale
27. **Add "graphical session down" runbook to docs/** — step-by-step: check SDDM, check niri, check graphical-session.target, check auto-login
28. **Document the `systemctl` tool constraint** — note in AGENTS.md that Crush can't run `systemctl`/`journalctl --user` and the diagnostic workaround
29. **Add desktop service dependency graph to docs/** — SDDM → niri → graphical-session.target → [helium, dms, swayidle, sway-audio-idle-inhibit, ssh-suspend-guard]
30. **Update CHANGELOG.md** — add entry for "diagnosed Helium down: root cause was no graphical session due to missing SDDM auto-login"

### Monitoring gaps

31. **Add Gatus endpoint for `graphical_session_active` metric** — new metric in system-health collector
32. **Add Gatus endpoint for `sddm_greeter_active`** — detect when SDDM is stuck at greeter
33. **Add Gatus endpoint for `desktop_services_down_count`** — count of `graphical-session.target.wants` services that are inactive
34. **Review all 79 Gatus endpoints** — verify none of them indirectly detect desktop session health (e.g., Dozzle, Homepage access from browser)
35. **Add Prometheus alert for `niri_drm_errors_30s > 0`** — metric exists but no alert
36. **Add Prometheus alert for `niri_restarts_10m > 3`** — metric exists but no alert

### Hardening

37. **Add `niri-session-manager` Gatus health check** — verify the session manager is running when graphical session is expected
38. **Verify `helium.service` `StartLimitBurst=10` is appropriate** — 10 restarts in 300s; with auto-login, this should be sufficient
39. **Add `helium-launch` timeout for stuck pgrep loop** — currently waits indefinitely; add a max wait of 120s then force-launch
40. **Review `helium.service` `PartOf=graphical-session.target`** — when graphical session stops, helium stops; verify this is desired vs. letting it survive session restarts

### Future

41. **Consider Wayland session auto-restart on crash** — if niri crashes and `graphical-session.target` stops, auto-restart the session without requiring SDDM re-login
42. **Evaluate `greetd` as SDDM replacement** — simpler, auto-login native, fewer dependencies
43. **Add `niri validate` to pre-deploy check** — verify niri config compiles before deploying
44. **Add desktop smoke test to VM tests** — `tests/default.nix` should test that niri starts in a VM with a virtual display
45. **Review all `graphical-session.target.wants` services** — are any of them unnecessary or causing startup races?
46. **Add `systemctl --user is-active` wrapper to scripts** — since Crush can't run systemctl, add a script that outputs graphical session status
47. **Consider headless detection in `pre-deploy-check.sh`** — if no graphical session, skip desktop-related checks
48. **Add `sops` secret for SDDM auto-login password** — if auto-login needs a password (it shouldn't with PAM, but verify)
49. **Review SDDM `defaultSession = "niri"`** — verify the session name matches the `.desktop` file in wayland-sessions
50. **Add `niri-session-manager` status to Homepage dashboard** — show graphical session health on the homelab dashboard

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. ~~Should I enable SDDM auto-login for user `lars`?~~ — **Answered:** Rejected. The user explicitly wants SSH-only/headless operation to remain valid. The implemented fix is session-aware monitoring that distinguishes "intentionally headless" from "desktop died".

2. **Is the machine currently at the SDDM login screen on the physical display, or is the display connected at all?** — The display-watchdog says "display idle/DPMS-off is normal" for the login screen, but I can't tell if a monitor is physically connected and showing the greeter, or if the machine is running headless with no display attached. This affects whether you can just walk over and log in vs. needing to connect a display first.

3. **Are the 10+ concurrent `crush -y` processes intentional?** — I see 10+ Crush instances across various pts sessions (pts/3, pts/4, pts/5, pts/7, pts/8, pts/10, pts/12, pts/23, pts/24, pts/26), some running since Aug 10. Are these all active work sessions, or are some orphaned/leaked processes that should be killed? They're collectively consuming significant CPU and contributing to the load average of 35+.

---

## Session Summary

**Time spent:** ~15 minutes
**Files read:** `niri-wrapped.nix`, `niri-config.nix`, `display-manager.nix`, `configuration.nix` (grep), `base.nix` (grep)
**Tools used:** 18 bash commands, 3 view, 1 grep, 2 write
**Root cause:** No SDDM auto-login → no graphical session after reboot → Helium never starts
**Severity:** Operational (not a code bug) — configuration gap
**Fix needed:** Enable SDDM auto-login + add monitoring for graphical session liveness
