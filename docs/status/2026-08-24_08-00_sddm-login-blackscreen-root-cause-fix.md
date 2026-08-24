# Status Report — 2026-08-24 08:00: SDDM Login Black-Screen Root Cause & Fix

_Session scope: single-session snapshot. Everything below derives from today's
niri-login investigation on evo-x2 plus defects observed in passing. No new
research beyond this session's work._

---

## Executive Summary

**Every SDDM login bounced back to the greeter (black screens → login).**
Root cause found, reproduced, fixed, and verified synthetically: the
buildcache SanDisk SSD is **physically absent** while its automount stays
armed; the fish `00-go-cache-guard.fish` (added 2026-08-22) probed
`GOCACHE`/`GOMODCACHE`/`GOLANGCI_LINT_CACHE` with **unbounded `mkdir -p`** on
that dead automount — 4 probes × 10 s kernel device-timeout = ~40 s of
uninterruptible sleep inside `fish --login`, so `niri-session` never ran.
The `display-watchdog` then correctly restarted SDDM at ~20 s ("dead display
+ wayland session + no niri") — infinite login loop since 2026-08-22.

Fix deployed live (SIGKILL-bounded probes, login chain now 3.1 s) and made
declarative in SystemNix. **Real graphical login by the user is not yet
confirmed.** The missing SSD is still an open hardware problem, and it
exposes more unpatched paths than the ones I fixed (see b/e/f).

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **Root cause identified with full causal chain** | automount ambush → fish conf.d guard → 4×10 s D-state → niri never starts → watchdog kills SDDM. Matches journal at both failed logins (06:34:44, 06:38:45) |
| 2 | **Live fix on host**: `~/.config/fish/conf.d/00-go-cache-guard.fish` probes now `timeout --signal=KILL 1` | SIGTERM cannot interrupt autofs waits (TASK_KILLABLE); SIGKILL lands at the 1 s bound — verified by strace |
| 3 | **End-to-end verification of the exact SDDM chain** (`wayland-session` → `fish --login` → `niri-session`) with dead-mount env vars: **3.1 s** (was 40+) | repro ran the real store-path scripts under a synthetic SDDM env |
| 4 | **Declarative ownership in SystemNix**: guard added as `xdg.configFile."fish/conf.d/00-go-cache-guard.fish"` in `platforms/nixos/users/home.nix` | `nix flake check --no-build` passes (all checks) |
| 5 | **Incident documentation**: `docs/troubleshooting/2026-08-24-sddm-login-blackscreen-dead-buildcache.md` | symptom, chain, fix, lessons, open items |
| 6 | **Test-state cleanup**: zombie headless niri stopped, user-manager env scrubbed (`XDG_SESSION_ID`, WAYLAND_DISPLAY, NIRI_SOCKET, GOCACHE…), /tmp repro + login-trap artifacts removed, `niri.service` inactive, manager env clean | verified via `systemctl --user` + `pgrep` |
| 7 | Ruled out the custom `niri.service` override, `ConditionEnvironment=XDG_SESSION_ID`, D-Bus user bus, PAM env, hm-session-vars chain, systemd user units, sddm wrapper — all proven healthy | synthetic repro started real niri when env was right |

## b) PARTIALLY DONE

| # | Item | What's missing |
|---|------|----------------|
| 1 | **Guard covers only 4 of 9 dead-mount vars.** hm-session-vars exports `CARGO_HOME`, `PIP_CACHE_DIR`, `SCCACHE_DIR`, `npm_config_cache`, `PLAYWRIGHT_BROWSERS_PATH` to `/mnt/buildcache/*` too — none probed/redirected. Rust/pip/npm/playwright usage will hit the same 10 s ambush or fail | extend `__go_cache_redirect` list |
| 2 | **Real login not confirmed.** Fix verified synthetically only; the definitive test is the user logging in at SDDM | user action |
| 3 | **HM takeover not exercised.** The hand-edited file and the new `xdg.configFile` carry identical content, but `nixos-rebuild switch` hasn't run — symlink-vs-file transition unverified | run switch, check for conflict/backups |
| 4 | **Symlink ambush remains**: `~/.cache/go-build`, `~/.cache/go`, `~/.cache/goimports`, `~/.local/share/pnpm/store` → `/mnt/buildcache/*`. Any tool resolving defaults (not env) still blocks 10 s per access | guard should detect dead mount and note/relink |
| 5 | **Monitoring gap partially mapped**: noticed Gatus "Niri Compositor" + "Niri Graphical Session" endpoints returned `success=true` **during** the broken logins (false negatives), while nothing alerts on buildcache SSD absence | fix queries / add endpoints |

## c) NOT STARTED

1. display-watchdog hardening — it killed two **legitimate** logins mid-startup (06:34:44, 06:38:45). With 3.1 s logins the race window shrinks, but any slow login (cold cache, disk pressure) can still be shot at ~20 s. Needs a post-session-creation grace window.
2. Alerting on buildcache SSD/automount absence (smartd silently tolerates by design; gatus "Build Cache SSD" endpoint failing but that's it).
3. Login-chain smoke test (time-bounded `fish --login -c true`) as a flake check or canary timer — this bug class had zero automated detection.
4. Eval-time lint extending `session-boot-audit.nix` philosophy to shell startup: flag unbounded FS probes in conf.d on `/mnt`.
5. `~/tmp` cache-growth cap/GC for redirected caches (they now write to the QLC NVMe the SSD was protecting).
6. Gatus false-negative fix for the two niri endpoints.
7. ADR for the "login-shell startup black-screen" class (distinct from the 2026-08-18 systemd-graph class already documented).
8. TODO_LIST/ROADMAP harvest of this report (docs-health HARVEST).

## d) TOTALLY FUCKED UP!

| # | Failure | Impact | Status |
|---|---------|--------|--------|
| 1 | **My synthetic repro started a REAL headless niri** (first run didn't intercept `systemctl --user --wait start niri.service`); it spammed `Error::DeviceMissing` and would have blocked the next login with "A niri session is already running" — the exact zombie class this system guards against | could have reproduced the 2026-08-18 black-screen on top of the current one | cleaned up same minute; later repros intercepted the call |
| 2 | **Wrong-shell repro**: assumed zsh; user's login shell is **fish**. The zsh repro "passed", briefly misleading the diagnosis. `getent passwd lars` would have cost 1 s | wasted a diagnostic round | caught when the full chain errored on `/run/current-system/sw/bin/zsh: No such file` |
| 3 | **First "fix" didn't actually fix**: `timeout 1` (SIGTERM) fired at 1 s but `mkdir` stayed in D-state until the kernel's 10 s timeout — my interim verification under-measured (outer `timeout 30` masked it). Second strace exposed it; `--signal=KILL` is the real fix | interim false "done" claim | corrected; final fix re-verified |
| 4 | **Login-trap theater**: armed a background watcher, told the user "waiting for your next login attempt", never used it | wasted effort, false expectation | killed during cleanup |
| 5 | **Observations under strace lied** (automount failure cached → fast-fail), delaying the repro of the hang | minor time loss | worked around with untraced timing runs |
| 6 | **User-manager state pollution** during testing (env vars imported into PID 1345) | transient risk to production session | fully scrubbed |

## e) WHAT WE SHOULD IMPROVE!

1. **Check the login shell before debugging a login shell.** `getent passwd` first, always.
2. **`timeout --signal=KILL` for any probe touching a mount point** — SIGTERM bounds nothing on autofs. Extract to shared lib.
3. **Never let a repro issue real `systemctl --user` calls** — shim every systemctl/dbus binary in the PATH of any session repro. (The shim pattern worked brilliantly on retries 2+.)
4. **The watchdog that "recovered" was masking the real failure** — aggressive recovery converted a 40 s hang into a login loop and destroyed the evidence each time. Recovery actions should log a pointer to what they interrupted (session age at kill time).
5. **Health endpoints must test the user-visible outcome** ("can you log in"), not a proxy ("unit exists"). Two endpoints green while login was hard-down.
6. **Session env exported at build time is a mount-health dependency** — hm-session-vars made every future login hostage to one USB SSD. Cache env belongs in a layer that can resolve at runtime (direnv/PAM) or must degrade safely.
7. **10 s device-timeout is too patient for login-critical automounts.** Cache-only mount: 2 s would have shrunk the ambush 5×.
8. **This failure was invisible in every log** — `wayland-session.log` empty, no niri journal, success=true monitoring. A pre-exec stage-logging wrapper for SDDM sessions would have named the hang in minutes, not an hour.

## f) Up to 50 things to do next

**P0 — immediate:**
1. User performs a real SDDM login → confirm niri comes up (the only missing verification)
2. Replug/power-cycle the JMicron JMS567 enclosure (known flapper, 9 disconnects 2026-08-16) or replace the SanDisk SSD; verify automount re-resolves via by-id (module is device-bound — should self-heal)
3. Run `nixos-rebuild switch` with the new home.nix; verify HM takes over the guard file without conflict (identical content → clean swap expected; check for `.backup` artifacts)
4. Extend guard to `CARGO_HOME`, `PIP_CACHE_DIR`, `SCCACHE_DIR`, `npm_config_cache`, `PLAYWRIGHT_BROWSERS_PATH` (same dead-mount ambush, currently unredirected)

**P1 — hardening (this failure class):**
5. display-watchdog: 60 s grace window after any new Class=user wayland session before DM restart is allowed
6. display-watchdog: consult `niri.service` activation state (via `systemctl --user -M`) before declaring "no niri" — pgrep-only misses starting/failed states
7. Gatus: alert on buildcache automount absent/failed (distinct from usage metrics)
8. Gatus: "login black-hole" endpoint — session of type wayland exists > 30 s while niri.service inactive
9. Fix Gatus false negatives: "Niri Compositor" + "Niri Graphical Session" green during hard-down login
10. flake check or canary timer: `fish --login -c true` must finish < 5 s
11. Eval-time lint: no unbounded `mkdir`/`stat`/`touch` on `/mnt/*` in fish conf.d (companion to session-boot-audit)
12. Reduce `x-systemd.device-timeout` on buildcache to ~2 s; add `x-systemd.idle-timeout` to unmount when idle
13. Guard: when redirect triggers, also `test -L` the `~/.cache/go*` symlinks and warn (they still ambush env-less tools)
14. Extract `timeout --signal=KILL` probe helper into shared shell lib; reuse in direnv cache hook too
15. SDDM session pre-exec wrapper that logs each startup stage with timestamps (next hang = instant diagnosis)
16. ADR: "login-shell startup black-screen" class, cross-ref 2026-08-18 systemd-graph class + both incident docs
17. `niri-session-manager.service`: add `ConditionEnvironment=XDG_SESSION_ID` defense-in-depth (matches niri.service)
18. Quiet the 60 s `niri-drm-healthcheck` "skipped, unmet condition" journal spam (3 managers × every minute)

**P2 — buildcache absence operating mode:**
19. Size cap / GC for redirected caches in `~/tmp` (currently unbounded on the QLC NVMe the design protects)
20. Decide long-term fallback: `~/tmp` (NVMe) vs `/mnt/pool` (Toshibas) vs replace SSD — needs user input
21. buildcache.nix: document an "absent drive" operating mode (what works, what redirects, what alerts)
22. Guard fallback dir configurable per-host (darwin shares fish config)
23. Verify `uv`/`pnpm`/`playwright` actual behavior against dead mount paths (not just env presence)
24. smartd: confirm NVMe + Toshibas still fully monitored with one SanDisk absent
25. Gatus "Build Cache SSD" + "Pool Mounted" endpoints failing — triage (pool may just be slow at boot)

**P3 — noticed in passing (unrelated to login, from journal/gatus during this session):**
26. `btrfs-compsize.service` failed with timeout (start operation timed out, 2× in logs) — investigate
27. Immich endpoint failing (gatus success=false)
28. Paperless endpoint failing
29. Bank-Sync + Bank-Sync Sync Health failing (2 endpoints)
30. DiscordSync failing (3 endpoints: main, legacy DLQ, Turso sync)
31. Browser History endpoint failing
32. SDDM silent theme: missing `flags/us.png` + hunspell `en_US` dictionary warnings (cosmetic)
33. `gkr-pam: unable to locate daemon control file` at every login (gnome-keyring unlock works anyway — pre-start race, harmless but noisy)
34. SDDM "Could not setup default cursor" at greeter start (cosmetic)
35. amdgpu early-import `Error::DeviceMissing` spam from my headless niri — confirm none persisted after cleanup

**P4 — debt/quality:**
36. HARVEST this report's (f) into TODO_LIST/ROADMAP (docs-health)
37. Sweep bash/zsh profiles for equivalent unbounded probes (guard is fish-only)
38. Consider moving cache env out of hm-sessionVariables into direnv/runtime layer (mount-health decoupling — big change, needs design)
39. niri overlay pin `2026-08-02` — evaluate bump
40. Verify auto-commit daemon picked up: home.nix edit, troubleshooting doc, this report
41. Add "time from session-create to niri active" metric to niri-health-metrics
42. Audit other x-systemd.automount mounts for login-env references (any automount referenced by exported env is the same trap)
43. USB enclosure health monitor: JMicron 152d:0567 link flap alerting (udev rule exists for recovery; no alerting)
44. `TMUX_TMPDIR` expression in hm-session-vars renders oddly — cosmetic cleanup
45. Check `docs/status` naming conventions vs this file (skill default is HTML; this report is Markdown per explicit user request)
46. Replay the 06:34 first login attempt in the incident doc — it predates the 06:38 one I documented; same cause, worth one line
47. Consider ConditionEnvironment on the healthcheck **timer** (not just service) to stop evaluating it pre-login
48. `config.fish` carapace cache write path `$XDG_CACHE_HOME/fish-init` — fine on NVMe, but add to the login-smoke-test scope (it runs at login too, pre-guard order matters)
49. Verify conf.d ordering guarantee: `00-` prefix must keep the guard before any conf.d file that uses Go (uv.env.fish is `uv`, alphabetically after `00-` — OK today, fragile tomorrow)
50. Post-switch: diff HM-generated fish files against pre-switch to confirm zero drift beyond the guard

## g) Questions I cannot answer myself

1. **Is the buildcache enclosure unplugged on purpose (maintenance), or did it flap/die?** Decides whether I prepare a permanent NVMe/pool cache relocation vs. wait for the SSD to return.
2. **Did you actually log in graphically after my fix?** I could only verify the chain synthetically — a real confirmation (or failure) is the last piece of evidence.
3. **Should the display-watchdog keep its aggressive 20 s recovery, or take the 60 s login-grace hardening?** Aggressive recovery traded diagnosability for uptime this incident; the grace window prevents shooting slow logins but delays real dead-display recovery by up to a minute.

---

_Report written per explicit user instruction as Markdown (status-report skill default is HTML; override flagged). Base: this session only._
