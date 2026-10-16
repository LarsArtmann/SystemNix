# Status Report: Deploy Unblock — erraudit Shim, FLM Port Squatter, Unanchored-Switch Repair, Storm Doctrines

**Session window:** 2026-10-16 ~23:03–23:48 CEST · **Host:** evo-x2 · **Branch:** master (shared tree, parallel session active)
**Author:** Crush session (deploy-unblock dispatch, two user pastes: failed FOD build → failed activation)

---

## 0. One-paragraph summary

The user's deploy was blocked twice. First by a **stale erraudit vendorHash shim** (master float `bb57433 → 100ce1c` invalidated `sKya91ES…`); fixed in-tree (`lib/lars-packages.nix` re-pinned to the first-hand got hash `ICUaudG…`), toplevel keep-going green. Second, the user ran `nh os switch` directly (bypassing `deploy.sh` gates) during an **active zone-6 I/O storm**: activation exited 4 on `fastflowlm.service` EADDRINUSE :52626. Root cause: a **pre-reservation ephemeral squatter** (papdashboard's node_exporter keep-alive connection, established before this morning's `ip_local_reserved_ports` fix landed) + a **60 s TIME_WAIT** after eviction. During repair I discovered the switch was **UNANCHORED** (nh activated in `test` mode; profile never bumped) — repaired per AGENTS.md protocol, boot-mirror re-synced, `pre-reboot-check` = **SAFE TO REBOOT** (22 ✓ / 0 ✗). fastflowlm is deliberately DOWN by guard doctrine (storm active, restore cap 3/3 spent). Four other failed units were dated and are **not** deploy damage.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| A1 | **erraudit vendorHash shim re-pinned** — lock float `bb57433 → 100ce1c` re-staled the shim; re-pinned to first-hand got hash `sha256-ICUaudG+K7ZayDgCN/91zXG7ZIEyWSUfkHjgN6HCL6A=` with class comment | `lib/lars-packages.nix:125-136`; `nix build .#erraudit` green (`0g99ifbdsi…-erraudit-100ce1c`) |
| A2 | **Full toplevel keep-going enumeration green** — the one-pass proof that no OTHER FOD broke (the deploy's 20 errors were all downstream of the single erraudit FOD) | exit 0; toplevel `bjidbq9pd8…` printed |
| A3 | **Deploy exited-4 root cause identified with live evidence** — `flm bind: Address already in use` :52626; ESTAB pair `127.0.0.1:52626 ↔ 127.0.0.1:9100` owned by papdashboard (dynamic user 64374, PID 1901, started 2026-10-15 23:29:41 — i.e. **before** the 08:30 reservation deploy); sysctl live (`52625-52626`) | journal 23:10:05/09/17; `/proc/net/tcp` inode 133430908; `sysctl net.ipv4.ip_local_reserved_ports` |
| A4 | **Port freed and bind proven good** — papdashboard restarted (evicted the pre-reservation conn), waited out the 60 s TIME_WAIT, `flm-real` bound :52626, unit `active`, model loading | journal 23:26:36 "Loading model: …/Qwen3.6-35B-A3B-NPU2"; `ss -ltnp users:(("flm-real",pid=3047364,fd=6))` |
| A5 | **UNANCHORED switch detected and repaired** — nh ran `switch-to-configuration test` (sets `/run/current-system`, never bumps the profile): `current-system` = `1zn3j4kl…` vs profile `system-914-link` = OLD `6z2v0d3l…`. Repaired: `sudo nix build --no-link --profile …system $CS` + `switch-to-configuration boot` | readlink match post-repair: `1zn3j4kl…` == `system-914-link` → ANCHORED |
| A6 | **Boot-mirror re-synced after repair** — `pre-reboot-check` §11 flagged "mirror tree DIFFERS from /boot"; `boot-mirror-sync` restart → "OK — 50 entries, 249M mirrored"; re-run green | `bootctl` copy lines 23:32:01; check §11 ✓ "mirror tree identical to /boot" |
| A7 | **`nix run .#pre-reboot-check` = SAFE TO REBOOT** — 22 passed, 0 failed, 3 advisories (failed units, known) | audit output 23:32 |
| A8 | **fastflowlm returned to guard ownership** — my mid-storm backend start reverted (`systemctl stop 'fastflowlm@*.service' fastflowlm.service`); socket DOWN, restore cap spent → flm lifecycle is the guard's again | unit `inactive/inactive`; guard trips #3387/#3388/#3389 (23:02/23:12/23:22) |
| A9 | **All four failed units dated and attributed** — none deploy-caused (detail in §d/c below) | journal timestamps 23:14:42 / 23:16:04 / 23:16:35 / 23:29:23 |
| A10 | **erraudit live on PATH at the deployed rev** | `erraudit version 7d60fff` via `/run/current-system/sw/bin/erraudit` |

---

## b) PARTIALLY DONE

| # | Item | Done | Missing |
|---|------|------|---------|
| B1 | **FLM end-to-end traversal after the port fix** | Backend bind + LISTEN proven at the real port (the A4 fix's unproven leg from the morning report is now half-closed) | NO request traversed socket 52625 → bridge → backend this session: the socket was guard-stopped at 23:10 and stayed down. The 08-30 report's B2 leg remains open until one client request crosses under a calm window |
| B2 | **This report's §f follow-ups** | Listed below | NOT harvested into `TODO_LIST.md` / domain libraries — deliberately deferred: the owner instruction for this session was "report, then WAIT", and a parallel session holds dirty edits on shared surfaces (`flake.nix`, `TODO_LIST.md` adjacency). Harvest must not ride foreign staged work; queued for owner go-ahead (AGENTS.md allows an explicit "deliberately not harvested because X" record — this is it) |
| B3 | **Storm state at close** | Measured and reported (I/O PSI some avg60 ≈ 67 %, top reader inboxclean-web) | Storm driver NOT investigated: inboxclean-web reads ~21 GB/10 min while its sync token is revoked — plausible runaway, unverified, owner question raised (§g) |
| B4 | **CHANGELOG / runbook documentation of the two new class facts** | Captured in this report | `docs/services/fastflowlm.md` (TIME_WAIT-after-eviction subclass) and CHANGELOG entry for the anchor-repair + port-squatter repair not yet written; deferred with B2 |

---

## c) NOT STARTED

| # | Item | Owner | Why it surfaced this session |
|---|------|-------|------------------------------|
| C1 | inboxclean Gmail re-consent (`gmail.token_revoked`, `invalid_grant` at 23:14:42) | **owner** | failed unit sweep |
| C2 | geometrikks PBX public-key install (the morning report's third, owner-gated leg: `Permission denied (publickey)`, banner proves reachability) | **owner** | failed unit sweep |
| C3 | flm socket restore when PSI < 20 (`sudo systemctl start fastflowlm.socket`; date-keyed cap auto-rearms 2026-10-17) | owner/next session | guard doctrine close-out |
| C4 | Upstream erraudit `vendorHash.nix` paste + push (hash churned LzoxcvFT → sKya91ES → ICUaudG in ~36 h; upstream still stale at every probed rev) | blocked:push (existing row `docs/todo/upstream.md:13`) | this session's fix |
| C5 | CI-restoration sweep for the private master-tracking inputs (the structural cure for the entire shim-churn class; erraudit verified CI-less 2026-10-15) | existing queue row | re-evidenced by this session |
| C6 | forgejo-avatar-sync: don't exit-fatal on a single flaky org-avatar 404 (7/8 in-sync; mirrors 433 repos 0 failed — pure monitor noise as wired today) | agent, small | failed unit sweep |
| C7 | service-health-check cascade noise: it lists inherited failures (failed because inboxclean-sync failed) — consider classifying upstream-vs-local so the monitor's exit reflects ITS scope | agent, small | failed unit sweep |
| C8 | Storm driver triage: inboxclean-web 21 GB/10 min sustained read loop | open — needs owner answer (§g Q1) | PSI table |
| C9 | docs sweep of stale rev citations (`100ce1c` now appears in my shim comment; `7d60fff` is the deployed rev — the lock moved twice during the session) | agent, small | rev-staleness class, `docs/todo/pipeline.md:446` |

---

## d) TOTALLY FUCKED UP (and near-misses — honest list)

1. **I started flm mid-storm without checking the guard first (process fuckup, recovered).** The guard's zone-6 trips (23:02/23:12/23:22) were sitting in the SAME journal window I was reading for the EADDRINUSE diagnosis — one command away. I ran `systemctl start fastflowlm.service` inside the repair script, mmap'd a 21.6 GB model into page cache during an active I/O storm, and then had to stop it again. The correct order was: read guard trip state → leave flm down → document the bind proof as sufficient. Cost: one wasted model load + avoidable page-cache pressure during a storm.
2. **The deploy itself was UNANCHORED for ~20 minutes** (not my command — `nh os switch` ran `switch-to-configuration test`, which never bumps the profile — but I initially closed out the first fix without catching it; the anchor check happened only because AGENTS.md's deploy-anchor discipline forced the readlink after the user's SECOND paste). A reboot in that window would have silently reverted the erraudit fix. This is the exit-14 class, third occurrence.
3. **Two wasted repair round trips on permissions.** First attempt: plain `systemctl` in a script → polkit denial (no interactive auth). The right first move was the `sudo -n` probe — passwordless sudo was available all along (nh had already elevated non-interactively at 23:10). ~4 minutes burned re-deriving what `nh`'s own success already proved.
4. **TIME_WAIT blind spot.** I checked "is the port free" 3 s after the papdashboard restart, saw it free, started flm 8 s later — still inside the evicted connection's 60 s TIME_WAIT → second EADDRINUSE. The morning report (2026-10-16_08-30) documented this EXACT port + connection; I re-derived the holder from `/proc` forensics instead of re-reading the same-day report first (Session-Discipline pre-read violation). `ss -K` (root, kills the socket) would have made the 65 s wait unnecessary.
5. **Rev-drift in my own close-out.** My first fix summary asserted the shim was measured at `100ce1c`; by the time the user deployed, the lock had moved again to `7d60fff` (parallel session's re-lock). The build stayed green (identical go-module graph), but I reported a rev I hadn't re-verified at deploy time — the exact "pasted error output was already rev-stale" class I should have internalized from `docs/todo/pipeline.md:446`.
6. **Nothing is currently broken** — final state: ANCHORED, mirror synced, reboot-safe, flm correctly down, shim green. The items above are honest process failures, not open breakage.

---

## e) WHAT WE SHOULD IMPROVE

1. **Repair-script preflight: guard/SEV1 state BEFORE any service start.** One `journalctl -u memory-emergency-guard --since -30min` should be a fixed first line of any flm-related repair. Candidate: a line in `docs/services/fastflowlm.md` runbook ("before touching flm units, read guard state").
2. **The queued pre-bind forensics row (`docs/todo/stability.md:101`) should cover TIME_WAIT too** — journal `/proc/net/tcp` state 06 rows (not just ESTAB holders), and note the `ss -K` eviction shortcut. Today's second failure mode would have been a 5-second diagnosis instead of a discovery.
3. **nh-direct deploys bypass deploy.sh gates** — the PSI dip gates that would have refused (or at least warned about) this storm-window switch never ran. Options: document "nh direct = gates off" in AGENTS.md Build section, or add a post-switch anchor+n-hint probe. Owner call (§g Q3).
4. **Agent repair path should be documented**: `sudo -n` is passwordless on this host; the polkit-interactive path is a dead end for agent shells. One AGENTS.md agent-shell bullet saves every future session the two wasted attempts I made.
5. **flm shim churn is structural, not accidental**: 3 re-pins in 36 h on a master-tracking, CI-less upstream. The CI-restoration sweep (C5) is the only durable fix; until then each shim comment should record the 2-day median lifetime to set expectations.
6. **`fastflowlm@*` bridge clients hammer the socket on cold start** — 30 accepts in 22 s at 23:10 before the guard killed it. Every client retry loop multiplies the cold-load storm. Worth a queue row: client backoff audit (relates to existing `docs/todo/services.md:56` consumer-timeout row).
7. **Status-report discipline**: this report deliberately stays session-scoped per instruction; the cross-session storm narrative (guard trips, cap policy) belongs to the 08-30 report lineage — annotate, don't fork.

---

## f) Up to 50 things to get done next (brainstorm, impact-sorted; **NOT harvested yet** — see B2)

**Deploy/anchor integrity (highest impact — prevents silent reverts)**
1. Add a post-switch anchor probe to the deploy close-out habit (readlink equality assert) — mechanize if `nh` keeps being used directly.
2. Decide nh-vs-deploy.sh policy for storm-window deploys (owner, §g Q3).
3. Annotate `docs/agents/systemd.md` anchor section with the nh-test-mode mechanism (test never bumps profile).
4. Add "guard-state preflight" line to the fastflowlm runbook (e1).
5. Upgrade `stability.md:101` forensics row: TIME_WAIT (state 06) + `ss -K` eviction shortcut (e2).
6. Verify flm E2E traversal once under a calm window (closes B1 + the 08-30 report's B2).
7. Re-verify restore-cap behavior at date rollover: does the guard auto-restore on 2026-10-17 without manual start?
8. Capture whether the guard's restore path starts the SOCKET (not just backend) — read the module's restore leg; if restore only covers backend, that's a design gap vs the "socket IS the re-activation path" doctrine.
9. Storm driver triage: inboxclean-web 21 GB/10 min (C8, §g Q1).
10. If inboxclean-web is a runaway: stop/scale it, then confirm PSI < 20 within one check cycle.

**Failed-unit follow-ups (small, high signal)**
11. inboxclean Gmail re-consent (C1, owner).
12. geometrikks PBX pubkey install (C2, owner) — then confirm one clean `geometrikks-log-pull-pbx` run.
13. forgejo-avatar-sync: 1-flaky-target → exit 0 with warning (C6).
14. service-health-check: scope-its-own-failures classification (C7).
15. After all four clear: `systemctl --failed` should be empty — record the first quiet sweep.

**vendorHash / FOD class**
16. Upstream erraudit vendorHash paste + push at current master (C4, blocked:push).
17. CI-restoration sweep execution for master-tracking inputs (C5) — erraudit first (verified CI-less).
18. Re-probe the other 2026-10-15 fleet shims (golangci, go-auto-upgrade, …) — the same overnight float class that hit erraudit likely moved them too; one `--keep-going` pass enumerates.
19. §f.1 of the 2026-10-14 report (toplevel `--keep-going` after master-flips) — effectively re-proven by A2 today; annotate that row done.
20. Lock-node orphan watch (`erraudit_3` re-key churn) — count drift on next blanket wave (existing watch row).
21. lars-packages.nix header one-liner: shim-form note (existing queued row, 5 min).
22. Median-lifetime note in flakePkgShim class comment (e5).
23. Pre-deploy FOD rev-staleness guard (existing pipeline.md:446 row) — today's #5 near-miss is more evidence.

**Storm resilience**
24. Cap-policy decisions (existing stability.md:115/116 rows): boot reset? notify-with-command? — tonight's 3/3-spent-during-deploy is fresh evidence.
25. Log the 23:02–23:3x storm (trips #3387-3389, cap spend, deploy collision) into the guard's trip-history/CHANGELOG lineage.
26. Consider DEPLOY_FORCE gates honoring a "storm-active" refusal message that names the guard unit (operator education at 02:00).
27. Client backoff audit for flm consumers (e6 / services.md:56).
28. `fastflowlm.socket` Accepted:30-in-22 s — identify the hammering client from the 23:10 window (bridge unit name `fastflowlm@27-…` names the peer ports).

**Docs hygiene (annotate-only, cheap)**
29. Sweep `docs/services/*.md` stale rev refs incl. the new `100ce1c`/`7d60fff` pair (C9).
30. CHANGELOG entry for this session (anchor repair + port-squatter + TIME_WAIT subclass) (B4).
31. fastflowlm.md: TIME_WAIT-after-eviction subclass note (B4).
32. AGENTS.md agent-shell bullet: `sudo -n` works, polkit-interactive never will (e4).
33. AGENTS.md Build section: nh-direct warning (e3) — pending Q3 answer.

**Adjacent observations from this session (flag-only)**
34. Parallel session's dms-paste extraction (flake.nix input + evo-x2 wiring + quickshell.nix + deleted `pkgs/dms-plugins/systemnix-snippets/*`) was in my build path — it BUILT green in this deploy (1zn3j4kl), i.e. cross-verified, but it's their commit to message/verify.
35. eval warnings still queued (stdenv.isLinux ×4, `'system'` rename, 21 catalog-less subdomains — pipeline.md:299).
36. man-paths python 3.13/3.14 double-install collision warnings (13 colliding subpaths in today's build log) — one python3 env should win.
37. fastflowlm/xrt libxrt collision warnings (system-path build log) — existing services.md row 31.
38. `nixpkgs-llama-rag` / `paperless-gpt-src` / `qmd` pins still standing (pin-audit trace) — existing lift conditions.
39. flm "New version detected! v1.0.2 → v1.0.9" upstream banner — package bump decision for the owner (model set + NPU behavior may change; freeze-#5 lesson says soak-test first).
40. `sv1-bridge`/`sev1-bridge.service` + `thermal-pstate-guard.service` new units from the parallel session — unverified by me beyond "started clean"; their owner session should smoke them.
41. The 23:10 flm cold-start was interrupted mid-load by the guard — check for orphaned/partial model mmap state on next start (flm's own restart handles it, but the idle-check + guard interplay on a HALF-loaded model is untested).
42. Guard action cooldown (600 s) vs trip log noise: 3 trips/30 min with heartbeats — the log-to-signal ratio during storms is poor; consider rate-limited trip logging.
43. `restores-20261016` file discipline: cap spent at 23:21 — confirm the capped-log epoch matches (it does: 1792183309); no action, recorded for the cap-policy row.
44. Sibling of #8: after tonight, verify `churn-rearm.count`/`restored.count` behavior across the date boundary.
45. Consider a `docs/status/` annotation on the 08-30 report: its A4 fix is now proven under real eviction pressure (this session), B2 still open.
46. `forgejo-github-sync` CHANGED-unit-files advisory from pre-reboot-check §9 — deploy.sh reset-failed handles it; verify on next deploy that exit stays 0.
47. `inboxclean-sync` failure may relate to the web server's read storm (#9): if re-consent doesn't calm the IO, the loop is elsewhere (search index?).
48. flake.lock input `erraudit` original still shows the tag-ref form in node `erraudit` (orphan) — existing lock-hygiene watch, no new action.
49. When flm returns: one `GET /v1/models` through :52625 as the standard cheap traversal probe (never a completion — probe-pins-model doctrine).
50. Schedule the next deploy for a PSI<20 window so §11 FOD preview + anchor probe + mirror sync all run inside `deploy.sh`'s gated path, not raw nh.

*(Items 34-44 are flags from this session's build/runtime logs; several duplicate existing queue rows — HARVEST should dedupe against `docs/todo/{pipeline,services,stability,upstream,monitoring}.md` before anything lands in `TODO_LIST.md`.)*

---

## g) Questions I can NOT figure out myself

1. **inboxclean-web is the storm's top I/O reader (~21 GB per 10-min window, sustained for 30+ min) while its sync token is revoked.** Did you intentionally trigger something in the InboxClean web UI (a re-index, migration, bulk export), or is this an unexpected loop I have your permission to stop/restart? This decides between "wait it out" and "act".
2. **Do you want fastflowlm back up tonight, or left to the guard/date-keyed cap?** Cap is spent (3/3, resets 2026-10-17); once PSI < 20 the manual restore is `sudo systemctl start fastflowlm.socket`. Related standing decision (`docs/todo/stability.md:116`): should the restore budget reset at boot?
3. **Was tonight's raw `nh os switch` (bypassing `deploy.sh` PSI gates during an active storm) an intentional override** — and should the deploy-anchor + guard-preflight checks be added as a documented "if you must use nh directly" ritual, or do you want to keep nh-direct for gates-off deploys as-is?

---

## Environment snapshot at authoring

- `readlink /run/current-system` == `system-914-link` == `1zn3j4kls04d0v82ak8nb2gkym3jpxxl…` (ANCHORED)
- `pre-reboot-check`: SAFE TO REBOOT (22 ✓ / 3 ⚠ / 0 ✗), mirror identical
- erraudit on PATH: version `7d60fff`; lock nodes: `erraudit_3` = `100ce1c…` at fix time, deployed build rev `7d60fff` (lock moved again mid-session, dep graph identical)
- I/O PSI some avg60 ≈ 67 % (storm ACTIVE at close); memory PSI ≈ 2 % (healthy)
- fastflowlm.service / fastflowlm.socket: inactive (guard doctrine, cap 3/3 spent)
- Failed units: forgejo-github-sync, geometrikks-log-pull-pbx, inboxclean-sync, service-health-check (all attributed, none deploy-caused)
- Tree state: my only edit is `lib/lars-packages.nix` (uncommitted; auto-commit daemon will sweep). Parallel session holds dirty edits: `flake.nix`, `systems/evo-x2.nix`, `platforms/nixos/desktop/quickshell.nix`, `modules/nixos/desktop/pastebot-parity-audit.nix`, `scripts/negative-test-lints.sh`, deleted `pkgs/dms-plugins/systemnix-snippets/*`

**HARVEST NOTE (per AGENTS.md self-harvest rule):** §f items are deliberately **not** harvested into `TODO_LIST.md`/domain libraries at authoring time — the dispatch instruction for this report was "report, then WAIT", and the shared `TODO_LIST.md` surface sits adjacent to a parallel session's uncommitted work; harvesting now would either ride foreign staged files or force a mid-storm pathspec commit. Harvest on owner go-ahead.
