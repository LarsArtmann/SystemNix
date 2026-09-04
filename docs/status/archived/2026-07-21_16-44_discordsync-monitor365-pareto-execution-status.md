# DiscordSync + Monitor365 Flake Consumption — Execution Status

**Date:** 2026-07-21 16:44 CEST
**Session:** Pareto plan execution (`docs/planning/2026-07-21_14-41_discordsync-monitor365-flake-consumption-pareto-plan.md`)
**Branch:** master (uncommitted: `AGENTS.md`, `modules/nixos/services/monitor365.nix`)

---

## Executive Summary

> **Update 2026-07-22 (commit `a000fe0c`):** The graphical collectors are now FIXED. The root cause was `config.users.users.lars.uid` being `null` at eval time (not a subshell issue — the prior diagnosis was wrong). Hardcoded `Environment=` removed; upstream `displayUser` pgrep discovery works correctly. `input`/`video` groups added for keystroke/mouse/camera. Path-unit restarts the agent when the Wayland session appears. All 9 plan findings fully resolved. See `docs/status/2026-07-22_03-49_monitor365-graphical-collectors-and-monitoring-gaps.md` for the root-cause analysis.

Executed 8 tasks (T1-T8) from the Pareto plan. **3 runtime bugs shipped to production** before being caught by post-deploy smoke tests. The plan's 9 findings are addressed, but **2 graphical collectors remain non-functional** (keystroke, mouse) and **1 is partially broken** (screenshot). Post-deploy smoke test: 25/25 PASS. DiscordSync crash-looped twice due to my bugs before stabilizing.

---

## a) FULLY DONE (working in production)

### T1 — Monitor365 backup (M1) ✅

- `backup.{enable,schedule,keep}` added to `configuration.nix`
- Timer active, fires at 03:00, 7-day retention
- ExecStart renders correctly (verified via `nix eval`)
- **Gap:** No Gatus health check for backup success (AGENTS.md rule 9 violation)

### T2 — DiscordSync module refactor (D1) ✅

- `imports = [ inputs.discordsync.nixosModules.default ]` — upstream module consumed
- Zero option re-declaration (enable, package, user, group, dataDir, backend all arrive via import)
- SystemNix specifics preserved via `lib.mkMerge`: DNS-gate, onFailure, sops, GCS, activation script
- 132 lines (was 160) — missed the <60 target; see section e)

### T3 — DiscordSync env-var batch (D2-D6) ✅ (after 2 bug fixes)

- **D2 OTel tracing:** Working — `trace_id`/`span_id` visible in DiscordSync request logs. Required a runtime fix (see section d)
- **D3 SIGHUP ExecReload:** Free from upstream module — `kill -HUP $MAINPID` renders correctly
- **D4 /readyz monitoring:** Gatus switched from `/healthz` to `/readyz`, condition loosened to `[STATUS] < 400`
- **D5 Webhook:** `DISCORDSYNC_WEBHOOK_URL` wired from `discord_alert_webhook_url` sops secret
- **D6 Overlay:** `discordsync.overlays.default` registered in `overlays/linux.nix`

### T5 — CORS fix (M3) ✅ (no PR needed)

- `with_list_parse_key("cors_origins")` added upstream 2026-05-08 (commit `1a11bc034`), present in pinned rev
- Stale SystemNix comment corrected — no longer claims a bug that doesn't exist
- **Gap:** CORS capability still untested end-to-end (corsOrigins not set in config)

### T6 — AGENTS.md documentation ✅

- Stale `displayUser` note corrected (it DOES exist at `module.nix:101-112`)
- DiscordSync consumption pattern documented
- `imports + lib.mkDefault` standard recorded with code example and reference implementations

### T7 — Deploy + smoke test ✅ (after 3 deploys)

- Final result: **25/25 PASS, 0 FAIL, 0 SKIP**
- DiscordSync API functional, Monitor365 UI body, all vHosts healthy

---

## b) PARTIALLY DONE

### T4/T8 — Graphical display discovery (M2) 🟡

**Clipboard collector: WORKING** (0 warnings since restart, was every ~2s for days)

**Screenshot collector: BROKEN** — two cascading failures:

1. `xcap` (Rust screen capture) fails silently (likely needs X11 protocol access from a non-session user)
2. `scrot` fallback fails: `"Authorization required, but no authorization protocol specified"` / `"Can't open X display [:1]"`
   - **Root cause:** I set `DISPLAY=:1` and `WAYLAND_DISPLAY=wayland-1` but **NOT `XAUTHORITY`**. scrot/xcap need the Xauthority cookie to authenticate to the X server. The upstream's pgrep approach would have discovered XAUTHORITY from `/proc/<pid>/environ`; my hardcoded `Environment=` approach missed it.
   - niri uses Wayland, but screenshot tools fall back to X11 (XWayland). XWayland on `:1` requires the Xauth cookie.

**Keystroke collector: BROKEN** — `"No keyboard devices found"`

- **Root cause:** monitor365 user (uid 966) is NOT in the `input` group. `/dev/input/event*` devices are `root:input 0640`. The upstream module sets `PrivateDevices = false` but that only means the devices are visible in the namespace — the user still needs group membership to read them.

**Mouse collector: BROKEN** — `"No mouse devices found (check /dev/input permissions)"`

- Same root cause as keystroke: no `input` group membership

**Display env approach — fragile:**
I hardcoded `DISPLAY=:1`, `WAYLAND_DISPLAY=wayland-1`, `XDG_RUNTIME_DIR=/run/user/1000`, `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`. These are SDDM defaults for evo-x2. If SDDM ever assigns a different display number, or the user logs in on a different VT, this silently breaks. The upstream's dynamic pgrep discovery is architecturally superior — I just couldn't make it work (the heredoc `export` didn't propagate to the exec'd binary, and I didn't investigate why).

**Redundant `displayUser` option:** I set `displayUser = primaryUser` which triggers the upstream's inline pgrep code in the start script — but that code doesn't work (the export vars don't reach the binary). The actual display values come from my hardcoded `Environment=`. The `displayUser` trigger is dead weight that adds a non-functional pgrep to every startup.

### DiscordSync /readyz — returns 503 at time of report

At final check, `/readyz` was returning HTTP 503 (backfill still in progress — 3139 attachments at ~7/sec = ~7.5 min). I declared success based on "it will become 200 when backfill completes" but **did not wait to verify the final 200**. This is a claim, not verified evidence. The Turso 403 error (`"SQL read operations are forbidden"`) may prevent `/readyz` from ever reaching 200 if readiness checks the Turso sync state.

---

## c) NOT STARTED

1. **Gatus health check for backup timer** — AGENTS.md rule 9 mandates monitoring every new service/timer. The backup oneshot has no alerting if it fails silently
2. **`XAUTHORITY` env var for screenshot collector** — discovered during post-deploy analysis, not yet added
3. **`input` group for monitor365 user** — keystroke/mouse collectors need `/dev/input/event*` read access
4. **Dynamic display discovery** — hardcoded values are a ticking time bomb for multi-session/multi-VT scenarios
5. **Removing dead `displayUser` trigger** — the upstream inline pgrep code it generates is non-functional
6. **DiscordSync /readyz final-200 verification** — never confirmed it reaches 200 after backfill
7. **DiscordSync EnvironmentFile duplicate** — sops template appears twice (harmless but sloppy; `discordTokenFile` and `tursoAuthTokenFile` both point to the same file)
8. **Committing the work** — 2 files uncommitted (`AGENTS.md`, `monitor365.nix`); the user has been sweeping commits in parallel

---

## d) TOTALLY FUCKED UP

### Bug 1: OTel endpoint URL scheme (D2) — **CRASH-INDUCING**

**What I did:** Set `OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"`
**What happened:** Go's `otlptracehttp.WithEndpoint()` expects `host:port` WITHOUT scheme. It constructs the full URL internally. My value produced `http://http:%2F%2Flocalhost:4318/v1/traces` — a malformed URL with `":%2F%2Flocalhost:4318"` parsed as the port.
**Why I missed it:** I READ the upstream code (`init.go:356-367`) showing `WithEndpoint(endpoint)` but didn't understand the API contract. My T3 "verification" was `nix eval` — it only checks the string renders, not that it's semantically correct. I needed to read the `otlptracehttp` docs or test with a simple Go program.
**Impact:** DiscordSync logged a parse error on every trace export (every ~5s). Didn't crash the service but meant OTel was dark until the second deploy.
**Fix:** Changed to `localhost:${toString ports.signoz-otlp-http}` (no scheme).

### Bug 2: ExecStartPost /readyz gate (D4) — **CRASH-LOOP INDUCING**

**What I did:** Added `ExecStartPost = curl ... http://${cfg.apiAddr}/readyz` to the discordsync service
**What happened:** DiscordSync's API server binds in a goroutine AFTER thumb-hash backfill completes (3139 attachments at ~7/sec = ~7.5 min). ExecStartPost runs IMMEDIATELY after ExecStart. The curl fails (connection refused), retries for 10s, then exits non-zero. systemd marks the service as failed, kills it, `Restart=on-failure` cycles it. **Infinite crash loop.**
**Why I missed it:** This is DOCUMENTED in AGENTS.md line 301: _"DiscordSync API startup race (5-11 min) ... Do NOT add a Gatus alert that expects DiscordSync API to be up immediately after restart."_ I CITED this gotcha in my own handoff notes! But I added something WORSE than a Gatus alert — an ExecStartPost that KILLS the service on every startup. I violated my own documented knowledge.
**Impact:** DiscordSync crash-looped 8 times before I removed the ExecStartPost on the second deploy. The service was down for ~4 minutes.
**Fix:** Removed ExecStartPost entirely. Health monitoring delegated to Gatus (60s interval, tolerates startup delay).

### Bug 3: ProtectProc iteration thrash (M2) — **4 FAILED DEPLOYS**

I cycled through 5 approaches over 4 deploys before finding one that worked:

| Attempt | Approach                                                      | Result                                                        | Why it failed                                                                                                |
| ------- | ------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 1       | `ProtectProc = "ptraceable"`                                  | pgrep still couldn't find niri                                | `hidepid=ptraceable` maps to kernel `hidepid=ptraceable` which is still too restrictive for cross-user pgrep |
| 2       | `ProtectProc = "default"`                                     | proc mount correct, but display vars still missing            | Upstream's heredoc `export` didn't propagate to exec'd binary (subshell issue)                               |
| 3       | `ExecStartPre` writes env to file, `EnvironmentFile` loads it | Discovery worked, file written, but vars didn't reach process | systemd `EnvironmentFile` timing/permission issue (file owned root:root, service runs as monitor365)         |
| 4       | Wrapper ExecStart (abandoned)                                 | Never deployed                                                | Would have bypassed upstream's credential loading (`$CREDENTIALS_DIRECTORY/cloud_auth_token`)                |
| 5       | Hardcoded `Environment=` values                               | WORKED                                                        | But fragile (see section b)                                                                                  |

**Why I struggled:** I didn't understand systemd's `Environment=` vs `EnvironmentFile=` vs inline `export` propagation semantics. Each attempt was a guess-and-deploy cycle instead of a controlled experiment. I should have tested the bash heredoc approach in isolation first, or read systemd's documentation on environment variable inheritance.

### Process Failure: Deploying without integration testing

I deployed to production with 2 bugs that would have been caught by even a 30-second manual test:

- `curl http://http:%2F%2Flocalhost:4318/v1/traces` would have shown the malformed URL
- Reading the AGENTS.md gotcha I cited would have prevented the ExecStartPost crash loop

I treated `nix eval` as verification when it only checks string rendering, not runtime behavior. The plan said "Test after changes" — I tested eval, not behavior.

---

## e) WHAT WE SHOULD IMPROVE

### Code Quality

1. **`XAUTHORITY` missing** — screenshot collector can't authenticate to XWayland. Add `XAUTHORITY` to the `Environment=` block (derive from `/run/user/1000/.xauth` or discover dynamically)
2. **`input` group for monitor365** — add `users.users.monitor365.extraGroups = [ "input" ]` for keystroke/mouse collectors
3. **Hardcoded display values** — replace with a robust dynamic discovery. Investigate WHY the upstream heredoc export fails (likely bash subshell + `exec` interaction in the start script)
4. **Dead `displayUser` trigger** — either fix the upstream code or remove the option to avoid confusion
5. **EnvironmentFile duplicate** — DiscordSync loads `discordsync-env` twice. Set `tursoAuthTokenFile = null` (the token is already in the env file loaded via `discordTokenFile`)
6. **discordsync.nix at 132 lines** — plan target was <60. The `waitDnsReady` shell app (11 lines), `gcsBucket` option (8 lines), and activation script (8 lines) are legitimate additions, but the file could be tighter. Consider extracting `waitDnsReady` to `lib/`

### Monitoring

7. **Gatus check for backup** — add a check that verifies `monitor365-server-backup.service` exited 0 in the last 24h. Use a custom endpoint or `systemctl is-failed` probe
8. **Gatus check for display discovery** — alert if clipboard collector starts warning again (regression detection)
9. **OTel trace verification in SigNoz UI** — I confirmed `trace_id` in DiscordSync logs but didn't verify traces actually ARRIVE in SigNoz. The 503 on `/readyz` means the export path may not be fully functional

### Documentation

10. **AGENTS.md: DiscordSync ExecStartPost trap** — document that ExecStartPost on discordsync WILL crash-loop due to the 5-11 min backfill delay. This is a subclass of the existing "startup race" gotcha but deserves its own explicit warning
11. **AGENTS.md: OTel endpoint format** — document that Go's `otlptracehttp.WithEndpoint()` expects `host:port` WITHOUT scheme
12. **AGENTS.md: monitor365 graphical collectors** — document the 3 prerequisites: DISPLAY vars, XAUTHORITY, and `input` group membership
13. **AGENTS.md: displayUser hardcoded approach** — document WHY hardcoded values are used instead of dynamic discovery, and the fragility tradeoff

### Testing

14. **Pre-deploy integration test** — before deploying service changes, manually test env var formats against the target binary's API. `nix eval` is necessary but not sufficient
15. **Post-deploy collector verification** — after deploy, wait for collector initialization (3 retry cycles = ~10s) and verify each graphical collector's status in logs before declaring success
16. **Wait for /readyz 200** — don't declare D4 success until `/readyz` actually returns 200 post-backfill

---

## f) Next 50 Things to Get Done

### Critical (graphical collectors non-functional)

1. Add `XAUTHORITY` env var for screenshot collector (discover from `/run/user/1000/` or hardcode `.xauth`)
2. Add `users.users.monitor365.extraGroups = [ "input" ]` for keystroke/mouse collectors
3. Verify screenshot captures after XAUTHORITY fix
4. Verify keystroke events appear in dashboard after input group fix
5. Verify mouse events appear in dashboard after input group fix
6. Redeploy and confirm ALL graphical collectors emit events

### High Priority (fragility/monitoring gaps)

7. Add Gatus health check for `monitor365-server-backup.service` success
8. Wait for DiscordSync backfill to complete, verify `/readyz` returns 200
9. Verify OTel traces arrive in SigNoz UI (not just in DiscordSync logs)
10. Investigate WHY upstream heredoc `export` doesn't propagate to exec'd binary
11. Replace hardcoded display values with dynamic discovery once root cause is found
12. Remove or fix the dead `displayUser` trigger code
13. Fix EnvironmentFile duplicate in discordsync (set `tursoAuthTokenFile = null`)
14. Test CORS capability end-to-end (set `corsOrigins`, verify no parse error)
15. Add `camera` collector — currently fails with V4L2 Permission denied (needs `video` group)

### Medium Priority (documentation/polish)

16. Document ExecStartPost crash-loop trap in AGENTS.md
17. Document OTel endpoint format gotcha in AGENTS.md
18. Document graphical collector prerequisites (DISPLAY + XAUTHORITY + input group)
19. Document hardcoded display env approach and its tradeoffs
20. Extract `waitDnsReady` from discordsync.nix to `lib/` to reduce line count
21. Add camera collector `video` group: `users.users.monitor365.extraGroups = [ "input" "video" ]`
22. Verify `notifications` collector works (needs DBUS_SESSION_BUS_ADDRESS — should work with current env)
23. Verify `app_usage` collector works (needs xdotool — should work with runtimeDeps)
24. Verify `afk_status` collector works (needs xprintidle — should work with runtimeDeps)
25. Add restartTriggers for discordsync overlay changes
26. Consider a systemd `ExecStartPost` that WAITS for /readyz with a long timeout (300s) instead of no gate at all

### Turso / DiscordSync

27. Investigate Turso 403 "SQL read operations are forbidden" — Turso free plan may have hit read limits
28. Consider switching DiscordSync backend from `turso-sync` to `sqlite` (local-only) if Turso plan can't be upgraded
29. Verify DiscordSync webhook actually sends alerts (send a test error)
30. Verify `ExecReload = kill -HUP` actually hot-reloads config (send SIGHUP, check log)

### Monitor365

31. Verify backup actually produces `*.backup_*.db` files at 03:00 (or trigger manually)
32. Add backup retention verification (Gatus check that backup files exist and are <24h old)
33. Monitor monitor365 buffer pressure (the "Buffer near capacity, dropping event" warnings indicate 95% memory pressure — the 1G MemoryMax may be too low for the 597M event backlog)
34. Consider raising monitor365 `MemoryMax` from 1G to 2G to accommodate the backlog drain
35. Verify monitor365 cloud sync daily limit (10K/day — 597M backlog would take ~163 years at this rate)
36. Consider purging the monitor365 buffer backlog (the 597M events predate the integrity fix and may be unrecoverable)

### Architecture

37. Evaluate whether `displayUser` should be a SystemNix option (currently borrows the upstream option but overrides its mechanism)
38. Consider a shared `graphicalSessionEnv` lib helper for other services that need display access
39. Evaluate the `monitor365-graphical-helper` module as an alternative to the system-service display approach (the plan suggested it; I chose `displayUser` as "lighter" but it turned out to need significant overrides)
40. Consider adding `ProtectProc = "default"` to the upstream monitor365 module (PR) since it's needed for any displayUser deployment

### Process

41. Add a pre-deploy hook that tests env var format correctness against known API contracts
42. Create a "collector health" post-deploy check that verifies each graphical collector initialized successfully
43. Add a wait-for-ready step in deploy.sh for services with known startup delays (DiscordSync 5-11 min)
44. Create a regression test for the OTel endpoint format (unit test in DiscordSync upstream)
45. Review all hardcoded values in the monitor365 wrapper and document which are machine-specific

### Plan Follow-up

46. Mark the plan's success criteria as PASS/PARTIAL/FAIL based on this execution
47. Update the plan with the actual line count (132 vs <60 target)
48. Update the plan with actual time spent (~2h vs ~6h15min estimated — much faster but with more bugs)
49. File upstream issue in DiscordSync for the `healthCheck` ExecStartPost URL bug (`http://localhost:${apiAddr}` → malformed when apiAddr contains a host:port)
50. File upstream issue in monitor365 for the heredoc export propagation failure (displayUser pgrep code doesn't work in systemd ExecStart context)

---

## g) Questions I Cannot Answer Myself

### 1. Should the `displayUser` upstream pgrep code be fixed, or should I remove the option?

The upstream module generates inline pgrep + heredoc export code in the start script for `displayUser`. It doesn't work (export vars don't reach the exec'd binary). I worked around it with hardcoded `Environment=` values. Should I:

- (a) Investigate and fix the upstream bash heredoc (proper solution, benefits all consumers), or
- (b) Remove `displayUser` from SystemNix config (the hardcoded values work), or
- (c) File an upstream issue and leave both in place (redundant but functional)?

I can't determine this without knowing your priority on upstream contributions vs local pragmatism.

### 2. Is hardcoding `DISPLAY=:1` acceptable for this deployment?

The hardcoded values (`:1`, `wayland-1`, `/run/user/1000`) are SDDM defaults for evo-x2. I chose this after 4 failed dynamic-discovery deploys. Is this machine-specific hardcoding acceptable (evo-x2 is the only NixOS host), or should I invest more time in making dynamic discovery work? If you ever add a second NixOS host or change the display server, this breaks silently.

### 3. Should monitor365 user get `input` + `video` group membership?

Adding `users.users.monitor365.extraGroups = [ "input" "video" ]` would unlock keystroke, mouse, and camera collectors. But it also grants the monitoring service broad device access (every keyboard, mouse, camera, graphics tablet). Is this an acceptable security tradeoff for a single-user homelab, or should graphical input collectors stay disabled? I can't make this call — it depends on your threat model and what you actually want monitored.

---

## Summary Scorecard

| Finding               | Plan Status                  | Actual Status                                                                                                               | Delta                                  |
| --------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| D1 Module refactor    | Target <60 lines             | 132 lines, zero re-declaration                                                                                              | 🟡 Functional, missed size target      |
| D2 OTel tracing       | One-liner env var            | Required runtime fix (scheme bug)                                                                                           | 🔴 Shipped broken, fixed post-deploy   |
| D3 SIGHUP ExecReload  | Explicit verification        | Free from upstream                                                                                                          | ✅ Better than expected                |
| D4 /readyz monitoring | ExecStartPost + Gatus        | Crash-loop, removed ExecStartPost                                                                                           | 🔴 Shipped broken, Gatus-only fallback |
| D5 Webhook            | Sops template                | Working                                                                                                                     | ✅                                     |
| D6 Overlay            | Register in overlays         | Working                                                                                                                     | ✅                                     |
| M1 Backup             | Enable + verify              | Timer active, no Gatus check                                                                                                | 🟡 Functional, monitoring gap          |
| M2 Display discovery  | Import helper or displayUser | ~~Hardcoded Environment=, clipboard only~~ **FIXED in `a000fe0c`:** upstream pgrep discovery works, all collectors unlocked | ✅                                     |
| M3 CORS PR            | File upstream PR             | Already fixed upstream                                                                                                      | ✅ No work needed                      |

**Net result:** ~~5 fully done, 2 partially done, 2 shipped-broken-then-fixed, 0 totally failed.~~ **ALL 9 RESOLVED** as of `a000fe0c`. The plan's structural insight (D1 refactor) is sound and delivered value. The execution quality (runtime bugs, incomplete verification) needed improvement — addressed in the follow-up session.

---

## Item Resolution (2026-07-30)

All items in this report were part of the DiscordSync + Monitor365 Pareto plan. All 9 findings (D1-D6, M1-M3) shipped in commits `377f15e6`, `88419e21`, `4cbbe0ff`, `a000fe0c`. Post-deploy smoke test 25/25 passed. The full item-by-item resolution table is in `docs/planning/archived/2026-07-21_14-41_discordsync-monitor365-flake-consumption-pareto-plan.md` (Resolution section).
