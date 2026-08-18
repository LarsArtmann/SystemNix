# FastFlowLM Socat Proxy Rework — Cold-Load E2E Exposed a Dead Endpoint (2026-08-18)

**Session window:** ~12:45–14:30 (resumed from `2026-08-17_22-55_fastflowlm-203-exec-fix-and-deploy-recovery.md`)
**Status:** deploy #2 activated (exit-4 wrap, units live); a THIRD bug (systemd 261 template-naming rule) found and fixed in deploy #3 — **activation blocked by a wedged switch-to-configuration holding `/run/nixos/switch-to-configuration.lock`** (see addendum §h)

---

## Headline

The P0 cold-load E2E test — the one thing yesterday's session never did — **immediately found that the deployed `:52625` endpoint was completely dead**: `systemd-socket-proxyd` does not exist in nixpkgs' systemd build, so the proxy ExecStart'd a phantom binary → exit 127 → start-limit-hit → systemd **deactivated the public socket**. Every client got connection-refused. All liveness checks stayed green. The architecture shipped yesterday could never have worked; a second bug (HTTP probe churn against flm's hard 10-connection limit) compounded it. Both are fixed via an `Accept=true` inetd-style socket + per-connection socat bridge; the fix is deploying right now.

## a) FULLY DONE (verified this session)

1. **Recon & state re-verification** — socket was LISTENING (0xCD91), backend idle by design, journal showed zero connections since 06:57 boot, RAM ample (68 GB available), load settled (23 vs yesterday's 85+). Confirmed the "deliberate commit" concern from yesterday is **already resolved**: `fbc60ed5` (00:57, later session) carries the module fix; `e5edf0bd` the package fix.
2. **P0 cold-load E2E executed (12:47:36)** — first real connection through `:52625` ever. Socket→proxy→backend activation chain fired correctly; model loading began from `/data/ai/models/fastflowlm/models/Qwen3.6-35B-A3B-NPU2`; flm bound `:52626` at 12:48:32. **This test is what exposed both bugs below — the runtime proof yesterday's report flagged as the top gap paid off immediately.**
3. **Root-caused Bug A (fatal): `systemd-socket-proxyd` absent from nixpkgs** — verified against EVERY systemd 261.1 store output on the machine (the binary is not built by nixpkgs at all). The proxy unit's `ExecStart` line 13 referenced `/nix/store/mc90…-systemd-261.1/bin/systemd-socket-proxyd: No such file or directory` → exit 127 ×5 → `start-limit-hit` → socket deactivated → **:52625 refused connections for ~5 hours (12:48→now) with zero alerts** (Gatus must not probe the port by design; nothing else watched it).
4. **Root-caused Bug B: probe churn vs flm's hard 10-connection limit** — the wait-gate's 1 s HTTP curl probes during the ~55 s window where flm has bound :52626 but not yet accepting piled up as dead queued connections; flm logged `Connection limit reached (10), rejecting new connection` and reset the genuine client request (`ConnectionResetError 104` at 75.9 s).
5. **Architecture rework (modules/nixos/services/fastflowlm.nix)** — replaced socket-proxyd entirely:
   - Socket: `Accept = true` (inetd-style; systemd itself accepts, spawns one per-connection template instance, client fd wired to fd 0/1), `MaxConnections = 8` (below flm's hard 10). Template originally named `fastflowlm-proxy@.service` with `Service = "fastflowlm-proxy@.service"` — **wrong: see §h bug C, renamed to `fastflowlm@.service` with `Service=` removed**.
   - Per-connection unit: waits for `:52626` **TCP accept** via `/dev/tcp` probes (each refused probe closes instantly, consumes no flm slot), then `exec socat - TCP:127.0.0.1:52626`. **The kernel listen backlog is now the cold-load hold — zero HTTP polling.**
   - `idleCheck` stops `'fastflowlm@*.service'` + backend (socket still never stopped); MemoryMax 64M on the bridge unit; `inherit (pkgs) systemd` removed (unused).
6. **Fixed a blocking eval bug in the concurrent session's uncommitted change** — `smartd.startLimitIntervalSec = "10min"` is a type error (NixOS option is int/seconds) that aborted the whole toplevel eval. Changed to `600` — surgical, intent-preserving, documented.
7. **Eval + option-placement verification** — initial `accept = true` at socket top level doesn't exist as an option; moved into `socketConfig.Accept`. Full toplevel eval passes; `nix fmt` clean.
8. **`system_service_state_failed` removed from `KNOWN_NEW_METRICS`** (pre-deploy-check.sh) — metric confirmed live yesterday 22:54; the temporary deploy bypass is gone, with a comment recording the removal.
9. **New post-deploy-check smoke: FastFlowLM full E2E through :52625** — `curl --max-time 240 /v1/models` through the public socket, asserting `"data"` in the body, enable-gated with SKIP for absent units. **This is the check that would have caught today's dead endpoint within one deploy instead of 5 hours.** Gatus still must NOT probe the port (connection = keepalive); the deploy-time smoke is the sole functional gate.
10. **Deploy #1 (12:55–13:10) ran the full gate stack** — pre-deploy check #12 correctly warned on the not-yet-built `fastflowlm-proxy-conn` store path; all 171 ExecStart lines scanned. It was **BLOCKED by a phantom metric that was not mine** (see d), which brings us to:

## b) PARTIALLY DONE

1. **Deploy #2 of the reworked architecture** — pre-deploy passed after adding two legitimate bypasses; **currently activating** (`/tmp/deploy-flm3.log`, PATHS 4113→4114). Activation result, post-switch steps (provisioner restarts, buildcache-usb-recovery, buildcache-gc), and the new E2E smoke all **unverified at report time**.
2. **Cross-session KNOWN_NEW_METRICS bypasses added** — `niri_zombie` (emitter tracked in niri-config.nix, riding this deploy) and `btrfs_health_critical` (emitter tracked in btrfs-health.nix, riding this deploy). Both go live with this deploy; **both entries must be removed after verifying the metrics are live** — same discipline as item a8.
3. **Runtime verification of the new architecture** — cold load through the socat bridge, chat completion, idle-TTL stop, re-activation: all **pending deploy completion**. Backend from the 12:47 test was still running at deploy time, so the first post-deploy connection may hit a warm backend — a true cold-load E2E needs the idle-stop first.

## c) NOT STARTED

1. Post-deploy verification suite: `nix run .#post-deploy-check` (now includes the fastflowlm E2E smoke).
2. Idle-TTL lifecycle test (backend stops after 1h idle, socket persists, next connection re-activates — with socat bridge this time).
3. Verification that `niri_zombie` + `btrfs_health_critical` are live in `/metrics` → remove both from `KNOWN_NEW_METRICS`.
4. Gatus FastFlowLM endpoints green-state check.
5. Deliberate commit of the socat rework (auto-daemon will otherwise bury it).
6. AGENTS.md fastflowlm section rewrite (socat architecture, nixpkgs socket-proxyd absence, flm 10-connection limit).
7. Annotate yesterday's status report + planning doc banner + TODO_LIST:185 — all three still claim "socket activation via systemd-socket-proxyd", which is now false.
8. CHANGELOG entry.
9. `systemd-analyze security fastflowlm-proxy@` review of the new template unit.
10. PMA `OPENAI_BASE_URL` wire-up verification (carried over from yesterday).
11. After 48h stable: retire hand install (`~/.local/share/fastflowlm/`, `~/.local/bin/flm`, `.bashrc` exports).
12. Investigation of yesterday's deploy #2 `Signal(9)` (journal window 16:20–16:40) — untouched.

## d) TOTALLY FUCKED UP (own goals, honestly listed)

1. **Deploy #1 wasted a full build+gate cycle on a predictable blocker.** I added the `niri_zombie` bypass preemptively but **did not grep the target config for OTHER new Gatus metrics from the concurrent session's tracked changes** — `btrfs_health_critical` failed the exact same check one cycle later. I treated the symptom I had seen instead of the class: *any* tracked-but-undeployed emitter + its Gatus check will fail pre-deploy. Cost: ~15 min and one aborted deploy.
2. **My first E2E log check went blind for ~75 s** — I `sleep 20`'d, then a `sleep 75` got auto-backgrounded by the shell timeout, so the first failure evidence arrived via a background-job round trip. Minor, but it's the same "don't pipe/block on long waits" lesson from yesterday: the E2E script already wrote to `/tmp/flm_e2e.log`; I should have polled it with short sleeps from the start.
3. **Yesterday's session (and the 00:57 session) shipped an architecture nobody had ever connected to once** — five review passes, a docs-health EXECUTED banner, a checked-off TODO, and a full deploy report all blessed a design whose proxy binary does not exist in nixpkgs. I inherited that state; the lesson is mine too: **"verified at rest" (units on disk, socket listening) was reported as done while the endpoint was provably dead.** The single honest test — one connection — was deferred as "P0 next" and everything green stayed green.
4. **Initial Nix option mistake** — `accept = true` placed at socket top level (option doesn't exist; caught by eval). Two-minute fix, zero user impact, but it's a wrong-first-guess I should have checked against the option list before writing.

## e) WHAT WE SHOULD IMPROVE (process, this session)

1. **Pre-deploy phantom-metric check should auto-classify "tracked emitter in this build"** — the failure mode is mechanical: new Gatus `pat()` metric + emitter in the to-be-deployed tree = goes-live-with-deploy. The script could diff target-config metric names against the running `/metrics` and auto-warn instead of hard-failing on every cross-session ride-along. Today cost two manual bypass edits; it will recur every time two sessions share this repo.
2. **The deploy-time E2E smoke pins the model — make that explicit policy.** Every `nix run .#deploy` now cold-loads a 13.6 GB model for up to `keepAlive` (1h). Correct trade (silent dead endpoints are worse), but it should be a documented decision, not an emergent one — and idle-stop timing matters if deploys cluster.
3. **Two concurrent sessions are editing one repo and riding each other's WIP into production.** Worked out today (both ride-alongs were coherent tracked changes), but nothing structural prevents a half-finished tracked change from deploying. Consider: deploy only from committed state, or a session banner in AGENTS.md declaring "repo in use".
4. **"Endpoint-level" checks for every public port we own** — Gatus can't probe :52625 by design, which left it unwatched for hours. The post-deploy smoke closes the gap at deploy time; an idle-safe alternative (e.g. a metric emitted by the socket unit's connection counter) could close it continuously.
5. **nixpkgs gap worth reporting upstream** — `systemd-socket-proxyd` is a standard systemd component that nixpkgs simply doesn't build. An upstream issue (nixpkgs) would fix this for everyone; the socat design is arguably better here anyway, but the absence deserves to be known.

## f) NEXT TASKS (prioritized, up to 50)

**P0 — verify the deploy in flight**
1. Confirm deploy #2 activation result (exit 0 vs exit-4-wrapped failure); read `/tmp/deploy-flm3.log`.
2. Run/inspect `nix run .#post-deploy-check` — expect the new "FastFlowLM — /v1/models through socket-activated :52625" PASS.
3. True cold-load E2E through the socat bridge: idle-stop the backend first (`systemctl stop fastflowlm.service`), then `python3 /tmp/flm_e2e.py` — verify TCP-backlog holding (client connects, waits ~55–180 s, gets `/v1/models`), no connection-limit churn in journal.
4. Chat completion + decode rate measurement (yesterday's script already does this).
5. Idle-TTL lifecycle: verify `fastflowlm-idle` stops `'fastflowlm-proxy@*'` + backend after 1h quiet, socket still LISTENING (0xCD91), next connection re-activates end-to-end.
6. Verify `niri_zombie` and `btrfs_health_critical` now live in the textfile collectors → **remove both from `KNOWN_NEW_METRICS`** (and re-run pre-deploy-check).
7. Verify Gatus FastFlowLM endpoints green; confirm the new Niri Zombie + BTRFS checks green too.

**P1 — hygiene & attribution**
8. Deliberate commit: "fix(fastflowlm): replace nonexistent systemd-socket-proxyd with Accept=true socat bridge" (+ smoke check + metric-bypass cleanup + smartd int fix).
9. Rewrite AGENTS.md fastflowlm section: as-built socat architecture, no-boot-autostart, StateDirectory HOME, idle-never-stops-socket, MaxConnections=8 rationale, post-deploy E2E smoke, check #12.
10. Add AGENTS.md gotchas: (a) nixpkgs systemd lacks systemd-socket-proxyd — never ExecStart it; (b) flm's hard 10-connection limit — never HTTP-probe it during cold load; (c) socket start-limit-hit deactivates the socket itself (endpoint death invisible to liveness checks).
11. Annotate `docs/status/2026-08-17_22-55_…md` inline: the a)7 "deployed and active" claims described a dead endpoint; link this report.
12. Correct planning doc banner (`2026-08-15_19-22_…`) and TODO_LIST:185 wording: socket-proxyd → socat as-built.
13. CHANGELOG entry for the rework.
14. docs-health HARVEST pass over the 2026-08-17 report (items 1–7 of its P0 are now done/superseded).
15. File nixpkgs issue: request `systemd-socket-proxyd` build (or document the gap locally forever).

**P2 — hardening & carried-over work**
16. Pre-deploy-check: auto-classify phantom metrics whose emitter exists in the target tree (see e1).
17. `systemd-analyze security fastflowlm-proxy@.service` — review the template unit's hardening (64M cap, harden {}).
18. Concurrency test: 8+ parallel clients through :52625 (MaxConnections vs flm's 10 — does PMA's worker pattern risk queuing?).
19. deploy.sh PATH self-hardening (yesterday's e2, still open).
20. Pre-deploy load/PSI gate (yesterday's e3, still open).
21. Investigate yesterday's deploy #2 `Signal(9)` (16:20–16:40 journal window).
22. PMA `OPENAI_BASE_URL=http://127.0.0.1:52625/v1` end-to-end: verify go-commit ≥ v0.8.0 generates commit messages via the local model.
23. Consider `warmCalendar` pre-load option if cold load proves annoying (original planning §7).
24. Consider a socket-connection-count metric (continuous endpoint liveness without keepalive — see e4).
25. Update `~/projects/anime-comic-pipeline/docs/npu-fastflowlm-llm-server.md` to the systemd path (after stability).
26. After 48h stable: retire `~/.local/share/fastflowlm/`, `~/.local/bin/flm`, `.bashrc` LD_LIBRARY_PATH exports (AGENTS.md instruction).
27. VM test for socket-activation wiring class (Accept=true + template + socat) — the static checks cannot catch it.
28. Sweep remaining `systemd-socket-proxyd` references repo-wide (docs, comments) for staleness.

## g) QUESTIONS (cannot determine myself)

1. **Cross-session deploy policy:** another session is actively editing this repo (niri, gatus, btrfs-health, session-boot-audit — all uncommitted). My deploys inevitably carry their tracked WIP into production (it worked today, but by luck of coherence, not process). Should deploys require a committed tree, should we coordinate a "repo in use" banner, or is ride-along-by-default acceptable?
2. **Idle-TTL verification timing:** the honest lifecycle test needs 1h of idle (or a temporary `keepAlive = "5min"` + another deploy while the other session works). Wait the natural hour, or take the redeploy?
3. **The deploy-time E2E smoke now cold-pins the 13.6 GB model on every deploy** (connection restarts the keepAlive clock). Acceptable as permanent policy, or should it be throttled (e.g. skip when the endpoint answered within the last N hours)?

---

## h) ADDENDUM 14:20 — deploy #2 result, Bug C (template naming), and the wedged-stc deploy outage

1. **Deploy #2 DID activate** (13:43–13:44, exit-4 wrap: `data-to-pool-migration` + `browser-history-agent` failed at switch time — the latter self-heals on its timer). Socket re-armed, socat + template deployed. Note: this activation was actually the **concurrent session's deploy** of the same tree (store `z816788k…`); my own deploy #2 (`855k5chwls…`) had activated cleanly at ~13:13. Two sessions built and switched the same uncommitted tree within 30 min — question g1 is no longer hypothetical.
2. **Bug C (found live): systemd 261 derives the Accept=true connection unit from the SOCKET's name, and `Service=` overrides on accepting sockets are unsupported.** Symptom: connection → `Failed to load connection service unit: No such file or directory` → socket result `resources` → client reset. Verified in v261.1 `src/core/socket.c`: `socket_verify()` refuses `Service=` when it resolves ("Explicit service configuration for accepting socket units not supported"), and a template value like `fastflowlm-proxy@.service` can't load as a unit → silently IGNORED ("missing the instance name, ignoring") → `socket_load_service_unit()` builds `fastflowlm@<conn>.service` from the socket prefix → no such template → ENOENT. **Fix: template MUST be named `<socket>@.service` — renamed to `fastflowlm@`, dropped `Service=`.** Also removed `fastflowlm-proxy@` from `idleCheck`'s stop glob. E2E through the fixed name still pending (see 4).
3. **Deploy #3 (renamed template) built clean but could not activate: exit 11 "Could not acquire lock".** Root cause: nixpkgs' new Rust `switch-to-configuration` flocks `/run/nixos/switch-to-configuration.lock`; the 13:43 stc completed ALL work at 13:44:08 (report printed, current-system advanced, all unit jobs done — verified in journals) then **wedged forever** (missed dbus JobRemoved signal is the prime suspect — the binary registers match rules for exactly that), holding the flock. Every subsequent deploy machine-wide dies exit 11 until that PID is killed or reboot. **Remediation shipped:** deploy.sh now detects a >30-min-old stc holding the lock, prints the recovery command, and aborts (opt-in auto-kill via `DEPLOY_KILL_WEDGED_STC=1` — killing root processes on an age heuristic stays a human decision). Current wedged PID: **3351300**.
4. **State at 14:30:** `:52625` has **no listener at all** — a failed per-connection spawn puts the SOCKET unit into `result 'resources'` FAILED state (13:50:57, my E2E attempt) and socket units do not auto-restart. Deploy #3's activation restarts the socket (its unit file changed via the `Service=` removal), restoring LISTEN with the correctly-named template. Until then the endpoint is fully down (PMA falls back to heuristic commits — non-fatal). All non-activation work done: metrics `niri_zombie`/`btrfs_health_critical` verified live + removed from `KNOWN_NEW_METRICS` (btrfs one reads **1 — true positive**, unallocated 4% < 5% threshold), post-deploy-check run (45 PASS / 2 known FAILs: the fastflowlm smoke correctly reporting the dead endpoint; Pocket ID SQLITE_BUSY ×2/30min — transient IO-load class, no panic), docs annotated, AGENTS.md rewritten, deliberate commit `c6f91f33`.
5. **Idle-TTL STOP half verified live (13:53:25):** backend ran 1h5m since the 12:47 connection, ≥1h without `TCP connection established` → `fastflowlm-idle` stopped it cleanly (26 GB RAM freed; later 5-min ticks are correct no-ops). The RE-ACTIVATION half is pending deploy #3 (same code path as the E2E).

---

**Bottom line:** yesterday's "deployed and verified" endpoint was dead on arrival — the never-run E2E test found it in 60 seconds, plus two more latent bugs (probe churn; systemd's Accept=true naming rule). One sudo action (`kill 3351300`) stands between the fixed architecture and its activation.
