# Window Closeout — five-task roundup, 2026-10-13 → 2026-10-14

Written 2026-10-14 05:03 CEST. Scope: the completed window of five queue tasks (IDs below), verified against git history, closeout reports, and the live tree. Predecessor of the same shape: `docs/status/2026-10-13_01-45_window-closeout-five-task-roundup.md`. Not a whole-project inventory.

## The window's tasks

| Task | Ask | Verdict |
| --- | --- | --- |
| `000001a132640f21` | [blocked:user] Freeze #27 owner desktop question | CLOSED-correctly-blocked (commit `1d297b0e`, closeout report exists) |
| `000001a1327f85c6` | [ready] Pre-vacuum evidence gate | LANDED, deploy-blocking (`31e10874` + backfill `03d72f61`; **no closeout report authored** — §d) |
| `000001a132c43023` | [ready] inboxclean-web Handler-timeout canary | LANDED after one build-broken false start (commits `bbae5884`→fix `dc3ad6e7`, closeout `8be4a563`; live verification `[blocked:deploy]`) |
| `000001a13771626a` | [ready] Deploy-gate iostat/top-cgroup crosscheck on PSI refusal | LANDED (`2fa02c2c`; **no closeout report authored** — §d) |
| `000001a137e9fb10` | [ready] SEV1 notify-tier steady-state alert fatigue | DESIGN SHIPPED, implementation queued (`aa7b3a75` + closeout `99d215b6`) |

## a) FULLY DONE (verified)

1. **Pre-vacuum journal evidence gate (task `…a1327f85c6`)** — `scripts/pre-vacuum-evidence-gate.sh` (REFUSE = exit 1 when a boot still on disk has no committed `docs/status/` evidence citing its boot id AND an open stability row cites its window; hex-boundary id8 match to avoid git-SHA false positives; vacuum-clock printout), wired as **pre-deploy-check §15 so deploys BLOCK**, fixture-tested by `checks.pre-vacuum-gate-selftest` (`flake/parts/checks/selftests.nix`), documented in `docs/agents/stability.md:38`. The companion `scripts/boot-evidence-pull.sh` was parameterized (commit `03d72f61`, which also removed a stray 4,810-line `docs/status/tasks/cf3f49dc-existing.md` scratch file). All 11 then-exposed boots (Oct 5–10, incl. boot -3 `ee5791b9`) were backfilled: `docs/status/tasks/2026-10-13_02-30_boot-evidence-backfill-oct05-10.md`. The protection is now enforced, not procedural — the exact gap the freeze-#28 evidence pull only won by dispatch luck.
2. **Deploy-gate device-truth crosscheck (task `…a13771626a`)** — `scripts/io-psi-crosscheck.sh` (282 lines: per-device %util from a 1 s io_ticks snapshot pair + top-3 stalled cgroups ranked by per-cgroup `io.pressure some avg10`, root cgroup excluded, env-overridable, exit-0 best-effort) wired into deploy.sh's io-PSI refusal on BOTH sub-branches; `checks.io-psi-crosscheck-selftest` includes a tripwire that deploy.sh still calls it. Bonus: the follow-up session root-caused the triggering signature — the 2026-10-13 21:5x refusal (PSI some avg10 53–65% with every device ≤0.4% util) is **ghostty's io_uring CQ-waiters**: `io_cqring_wait` sleeps TASK_INTERRUPTIBLE with `in_iowait=1` and PSI charges TSK_IOWAIT regardless, so idle ghostty cgroups book ~100% io PSI with empty io.stat and zero D-state. Full verdict + classification shortcuts in `docs/agents/stability.md:31` and `docs/status/2026-10-14_02-10_io-psi-idle-disk-phantom-verdict.md`.
3. **Freeze #27 owner question correctly dispositioned (task `…a132640f21`)** — the row closed as genuinely blocked (journal exhausted: all services healthy at the 11:07:59 cut; display-watchdog logged a dpms-off login screen 10:58–11:07), NOT silently ticked; both queue surfaces annotated with the BLOCKED reason (commit `1d297b0e`, closeout `docs/status/tasks/2026-10-13_01-22_task-000001a132640f21ff8f7f35197300000000.md`). Follow-ups it minted (desktop-state snapshot collector, session-1386 crush.db pinning) are live unchecked rows.
4. **inboxclean-web Handler-timeout canary (task `…a132c43023`) — code complete** — `inboxclean-canary` collector (timer + journal-grep → `inboxclean_web_health_handler_timeouts{window="10m"}` textfile metric + SigNoz/gatus consumption), closeout report `docs/status/tasks/2026-10-13_03-52_task-000001a132c430236f25728f840700000000.md` (commit `8be4a563`). The initial module NEVER BUILT (`''''` → odd quote count → bash unterminated string, eval stayed green); the same-day fix `dc3ad6e7` (`""` empty-pattern form) is build-verified and branch-tested. Live verification is correctly `[blocked:deploy]` (TODO_LIST:1186).
5. **SEV1 chronic-storm latch proposal (task `…a137e9fb10`)** — implementation-ready design authored in `docs/todo/stability.md`: ACTIVE→CHRONIC state machine (30-min same-set threshold, owner-overridable module option), one warn-banner escalation on transition, new-condition/page-tier break-throughs, hourly single-line digest, explicit CHRONIC→CLEARED, `state=chronic` alert-file token, `sev1_chronic_active{condition}` textfile gauge, VM-test spec. Motivating evidence (4037/4044 bridge runs notifying across 11+ h) verified in `docs/status/tasks/2026-10-13_00-37_freeze-27-autopsy-evidence.md`. Fatigue row closed on both surfaces, `check-todo-system.sh` clean for the touched rows (commit `aa7b3a75`, closeout `99d215b6`). The implementation row is queued (TODO_LIST "Implement the sev1 chronic-storm latch").
6. **Adjacent in-window landings noticed in passing (other sessions/daemon, recorded here for cross-referencing):** tq-agent-pool PSI start gate + disk accounting (`2af8cf11`), io-psi-forensics power-cut-safe bundles + self-prune (`953f31a8`), memory-guard fsync trip-identity (`d9528f18`), nix-heavy-builds gate (`40e41469`), thermal-pstate-guard extension (`215fe338`), SIGSTOP standing rule (`296dd162`).

## b) PARTIALLY DONE

1. **Canary live verification** — collector built + fixed but NOT deployed to evo-x2; the `[blocked:deploy]` row (TODO_LIST:1186) owns the deploy-then-verify ladder, including the expected first-scrape burst=1.
2. **Sev1 chronic latch** — design only; the channel still spams steady-state notify today. Implementation, VM tests, gauge/SigNoz consumption, deploy, and the freeze-#27 census re-run all open (closeout §c).
3. **Freeze-#27 causal verdict** — actors named (unit attribution closed earlier), but the ranked "what pushed it over the edge in the death minute" weighing (interactive churn vs tq rescan vs thermal) is still open.
4. **inboxclean-web initial IMAP disconnect cause** (~07:46 Oct 11) — the reconnect storm is attributed, the trigger is not.

## c) NOT STARTED

1. Chronic-latch implementation + tests + deploy (design ready, zero code).
2. tq harvest-tick skip-cursor fix — lives in go-taskqueue, unstarted (SystemNix-side PSI gate landed; the pre-spawn gate upstream row is queued).
3. tq upstream `task.reprioritized` journal facts — still unstarted, so §h below remains unfilled by construction.
4. Desktop-state snapshot collector, session-1386 crush.db pinning — queued, untouched this window.
5. Two of the five window tasks shipped **no closeout report** (`…a1327f85c6`, `…a13771626a`) — the work landed, the self-review step was skipped.

## d) TOTALLY FUCKED UP

1. **The canary shipped build-broken for hours under an eval-green close-out** (`bbae5884`: `''''` in a Nix indented string → bash unterminated quote; only the build's `bash -n` phase caught it, and only when someone later built the drv). The eval-only verification pattern is now a known class with queued guards (commit/CI build-changed-drvs leg, `'''`-pattern audit, nix-flakes quote-rendering doc — all queued TODO rows). This is the window's worst defect: a paid dispatch whose deliverable did not run.
2. **Missing closeout reports on 2 of 5 tasks** (`…a1327f85c6`, `…a13771626a`) — the queue's own convention (closeout report = the task's full self-review) was met with commit footers only; §f follow-ups from those tasks were harvested ad hoc (some were, e.g. the trip-line top-5 idea from `…a132640f21`'s report) but the self-review ledger has holes.
3. **An unresolvable "§f.30" citation propagated** into the closed sev1-fatigue rows in both surfaces (closeout `…a137e9fb10` §d.1 admits it) — the evidence core is real, the pointer is phantom; a future reader burns a search. Resolve-or-correct row queued below.
4. **check-todo-system DRIFT is WARN-only while the backlog compounds** — ~20 firing DRIFT rows + ~105 UNHARVESTED §f reports at the 2026-10-14 run; the gate exits 0 either way (triage row queued).
5. **Canary `scrape_errors` is fail-open dead code** (`|| count=0` swallows journalctl failures — sandbox-proven, queued row).
6. Nothing at the data-loss level; no regressions to working gates found in this pass.

## e) WHAT WE SHOULD IMPROVE

1. **Closeout-report discipline is now the weakest link** — commits land, self-reviews don't. The tq prompt already asks for it; consider making the report path part of the verdict record (tq could warn when a closed `[ready]` item has a footer commit but no `docs/status/tasks/` file).
2. **Build-the-drv verification for any new/changed script-bearing module** — eval-green is proven insufficient twice over now (canary quote bug; the writeShellApplication class). The queued CI/pre-commit legs should land together, not separately.
3. **The device-truth crosscheck pattern generalizes**: any gate that prints a single aggregate signal (PSI, memory watermark, disk %) should print the per-unit/per-device decomposition beside it — this window's crosscheck converted a 2-day phantom-storm mystery into a one-line classification shortcut.
4. **Design-as-library-row worked again** (sev1 latch) — proposal authored implementation-ready made the follow-up dispatchable in one append; keep for `[decision]`-flavored items.
5. **Pre-vacuum gate proved the "gate, don't plead" pattern**: three autopsies were won-or-lost on timing until a check refused. Same upgrade path for the evidence-file MANIFEST idea (boot UUID + journalctl command line per evidence file).

## f) NEXT THINGS

Candidates below were dedup-checked against the open queue; the surviving ones were appended to TODO_LIST.md (8 new rows):

1. Resolve-or-correct the unresolvable "§f.30" citation in the closed sev1-fatigue rows (queue + pipeline library). — QUEUED
2. Footer-record commit for the canary item-1 close (batch `000001a132c43023…`, cite `bbae5884`) so footer-grep batch derivation is complete. — QUEUED
3. tq tick log line: add duration + items-scanned so future IO windows are attributable without journal math. — QUEUED (upstream)
4. Extend memory-guard trip lines to top-5 child-unit IO deltas (kill the slice-depth blindness). — QUEUED
5. Freeze-#27 death-minute ranking: weigh the three attributed actors against the thermal series → single verdict. — QUEUED
6. Exercise the pre-vacuum gate live on evo-x2 (run `scripts/pre-vacuum-evidence-gate.sh`, capture verdict + vacuum clock; confirm the backfilled boots satisfy it). — QUEUED
7. Owner answers → blocked rows (chronic-latch thresholds/suppression breadth; InboxClean push permission). — QUEUED as BLOCKED items
8. Already-queued tracks that OWN the biggest open work (do not re-mint): sev1 latch implementation; canary deploy-verify; check-todo-system DRIFT triage; tq pre-spawn PSI gate upstream; niri DeviceMissing root cause; inboxclean IO hardening; tq harvest rescan; queue-hygiene footer guard; `task.reprioritized` facts.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **InboxClean master push** — 3 tested commits sit unpushed (the `/health` cached-handler fix among them); every hour unpushed, evo-x2 keeps running the scan-per-probe health handler that fed the freeze-#28 storm. May it be pushed?
2. **Sev1 chronic-latch tuning** — is 30-min-to-CHRONIC + hourly digest the right steady-state experience, and should CHRONIC silence BOTH the Discord bridge leg and the desktop notification, or only the bridge?
3. **Pending-deploy train priority** — five verified-in-tree changes await the next evo-x2 deploy (canary fix `dc3ad6e7`, io-psi-crosscheck, pre-vacuum §15, tq-pool PSI gate, chronic-latch once built). Any ordering/deadline constraint, or next-quiet-window as usual?

## h) BAND DRIFT (ADR-0015)

**None recorded.** `tq facts list` contains ZERO `task.reprioritized` events (re-verified this session; the fact type is not emitted by the current go-taskqueue build). The standing upstream row asking for `task.reprioritized` journal facts (docs/todo/upstream.md, Source: the 2026-10-13 window closeout §h) remains the accountability fix — until it lands, every closeout's band-drift section is unfilled by construction, and priority moves are only recoverable anecdotally from queue-row edit history.
