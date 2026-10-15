# Window Closeout — five-task window 2026-10-13 → 2026-10-14 (fourth fire, full verification)

Written 2026-10-15 03:29 CEST. Dispatch `Task-Queue-ID: 000001a13800dfbb3ebd5b780df400000000`. This is the **FOURTH fire** of the same done-prompt: `docs/status/2026-10-14_05-03_window-closeout-20261013-14-five-task-roundup.md` (`7333beb3`) closed the window first, `2026-10-15_00-40_window-closeout-refire-20261013-14-five-task-roundup.md` (`402fdfd5`) re-verified second, `2026-10-15_00-54_window-closeout-refire2-five-task-roundup.md` (`a67b266b`) re-verified third. None of the three predecessor sessions ever recorded a tq verdict (see §Dispatch-chain forensics), so the queue kept re-firing. Per the re-dispatch verification protocol (docs/CONTRIBUTING.md), this pass does NOT re-derive the predecessors: every load-bearing claim below was re-verified against the live tree, git history, and the production tq journal this session, and the three predecessor reports' claims all held. Scope: the five completed window tasks + the dispatch chain itself; the 2026-10-14-evening and 2026-10-15 sessions (geometrikks, dnsblockd wave 2, crowdsec stage 1, migrate-* gating, btrfs-gc-guard IO admission) are separate windows, noticed in passing only.

## Dispatch-chain forensics (new this pass)

From the production journal (`tq facts --db /mnt/pool/services/tq/tq.db`, 12,008 facts):

| When (CEST) | Event | Why it matters |
| --- | --- | --- |
| 10-14 05:03 | First closeout report lands (`7333beb3`) | Work complete, but… |
| 10-14 05:36 | task requeued — **budget gate: 30/30 daily tasks** | Closeout never recorded; chain parked ~18 h on queue config |
| 10-14 23:59–10-15 00:25 | 3 more claim→requeue cycles (budget gate, provider rate-limit, preflight "uncommitted changes" from concurrent sessions' in-flight files) | Paid attempts burned before any agent work |
| 10-15 00:40 / 00:54 | Refire reports #2 and #3 land (`402fdfd5`, `a67b266b`) | Both sessions finished their reports… |
| 10-15 00:48 / 01:03 | task failed — **verify gate dead: `nix flake check --no-build` fails at the pre-attempt rev too** | End-of-session verification eats the completed closeout; no verdict → re-fire |
| 10-15 02:20–02:29 | 2 more attempts — preflight refusals (staged docs files from parallel sessions) | env-streak burned |
| 10-15 03:20 | This session claims | Fourth fire |

Root causes, ranked: (1) the queue's done-prompt trigger does not consult an existing `*_window-closeout_*` report before re-enqueueing (the re-fire guard, TODO_LIST:1280, queued but unimplemented — this chain is its third proof); (2) `.tq-verify` for SystemNix is `nix flake check --no-build`, which is **RED tree-wide at HEAD** (the hermes-agent lock FOD drift, TODO_LIST:23) — every SystemNix dispatch's verification currently fails regardless of the work's quality, and docs-only dispatches have no docs-scoped verify; (3) the daily budget (30) has no carve-out for verdict-recording dispatches.

## a) FULLY DONE (all re-verified this pass, not re-claimed)

1. **Pre-vacuum journal evidence gate (task `…a1327f85c6`)** — `scripts/pre-vacuum-evidence-gate.sh` on disk (7.0 KB), wired as pre-deploy-check §15 (deploy BLOCKS), fixture `checks.pre-vacuum-gate-selftest` pinned at `flake/parts/checks/selftests.nix:166`; work commit `31e10874` (footer verified). All 11 then-exposed boots (Oct 5–10, incl. boot -3) evidence-backfilled at 7.1G/8G vacuum pressure; gate ran green post-backfill. The §15 live pre-deploy exercise remains open (TODO_LIST:289) — that is a live-box exercise, not missing work.
2. **Deploy-gate device-truth crosscheck (task `…a13771626a`)** — `scripts/io-psi-crosscheck.sh` on disk (12.5 KB), fixture `checks.io-psi-crosscheck-selftest` pinned at `selftests.nix:194` incl. the deploy.sh wiring tripwire; work commit `2fa02c2c` (footer verified). Bonus root-cause of the triggering signature (ghostty io_uring `io_cqring_wait` charges PSI while idle) recorded in `docs/agents/stability.md` + `docs/status/2026-10-14_02-10_io-psi-idle-disk-phantom-verdict.md`.
3. **Freeze-#27 owner desktop question (task `…a132640f21`) correctly dispositioned BLOCKED** — closeout commit `1d297b0e` (footer verified), report on disk; both queue surfaces annotated; journal-exhausted + display-watchdog dpms-off-login-screen facts carried. Awaiting owner recollection, by design.
4. **inboxclean-web Handler-timeout canary (task `…a132c43023`) — code complete** — `modules/nixos/services/inboxclean-canary.nix` on disk (5.4 KB); the eval-green/build-red first landing `bbae5884` was build-fixed same-day (`dc3a d6e7` → `dc3ad6e7`, empty-pattern form, build + branch verified); footer-bearing closeout `8be4a563` retro-derives the batch. SigNoz rule + 2-min textfile collector specified and built.
5. **SEV1 chronic-storm latch proposal (task `…a137e9fb10`) — design shipped** — work `aa7b3a75` (implementation-ready library row in docs/todo/stability.md: ACTIVE→CHRONIC machine, transition-only channel, hourly digest, `sev1_chronic_active` gauge, VM-test spec), closeout `99d215b6` (footer verified). Motivating 4037/4044-run census verified in the 00-37 autopsy-evidence file.
6. **Living docs absorbed the window correctly** — CHANGELOG.md carries all four shipped items (verified lines 12, 13, 15, 16); all five queue ticks are evidence-backed on both surfaces; the three predecessor closeout reports' claims re-verified with zero false claims found across three passes.

## b) PARTIALLY DONE (the live residuals; all rows re-confirmed open this pass)

1. **Chronic-latch implementation** — design ready, zero code (TODO_LIST:1235); sev1 still spams steady-state notify today. Owner threshold/breadth decision queued (TODO_LIST:290 + stability.md).
2. **Canary live verification** — built + fixed, never deployed (`[blocked:deploy]` row; TODO_LIST:1186); also its `scrape_errors` fail-open dead code (TODO_LIST:1226) and the missing footer-record (TODO_LIST:595).
3. **Pre-vacuum gate §15 live exercise** — fixture-proven, never run against the real box's pre-deploy path (TODO_LIST:289).
4. **inboxclean-web cached /health** — upstream InboxClean `2ee3860` tested and UNPUSHED; pickup `[blocked:push]` (docs/todo/stability.md). Every day unpushed, evo-x2 keeps the scan-per-probe health handler that fed the freeze-#28 storm.
5. **Freeze-#27 death-minute ranking** — three actors attributed, no single "what pushed it over" verdict.
6. **§f.30 phantom citation** — still sits uncorrected in the closed sev1-fatigue rows (TODO_LIST:594).

## c) NOT STARTED

1. **`task.reprioritized` journal facts upstream** — still unstarted; §h below remains unfilled by construction. The two duplicate rows (TODO_LIST:583 + :1219) got their dedupe executed THIS pass (see Docs-health record) — one lane remains.
2. **tq harvest-tick skip-cursor fix** (go-taskqueue repo) — the 1605-item full rescan per tick, unstarted upstream.
3. **Desktop-state snapshot collector** + **session-1386 crush.db pinning** — queued from the freeze-#27 batch, untouched.
4. **Done-prompt re-fire guard (TODO_LIST:1280)** — queued, unimplemented; the class it prevents has now cost four fires.
5. **check-todo-system DRIFT triage** (~20 wrong-link rows + 100+ unharvested §f reports, TODO_LIST:44 + :1236) — untouched.

## d) TOTALLY FUCKED UP

1. **Four paid fires for one closeout, zero verdicts recorded.** Every failure mode was queue-mechanical, not work-quality: budget gate (2×), provider rate-limit (3×), preflight clean-tree refusals (5×, caused by concurrent sessions' in-flight files — expected on this shared tree), and the dead verify gate (3×, including one env-streak attempt-burn AFTER the report was already written). The chain is the strongest evidence yet for the queued re-fire guard and for a verdict-durability rule.
2. **`.tq-verify` = `nix flake check --no-build` is dead at HEAD** (hermes-agent lock FOD drift, TODO_LIST:23, red since 2026-10-14 eve). Until that one-line re-pin lands, EVERY SystemNix dispatch fails verification at session end — completed work is being discarded by the queue and re-fired. This is the single highest-leverage unblock in the repo right now.
3. **Prior-window defects remain the standing debt** (documented by predecessors, re-confirmed unremediated): the canary shipped eval-green/build-red for hours (the worst defect — a paid dispatch whose deliverable could not run); 2 of 5 window tasks shipped no closeout report; the §f.30 citation is phantom; DRIFT is WARN-only while the backlog compounds.
4. Nothing at the data-loss or wrong-verdict level this pass; no regressions to working gates found.

## e) WHAT WE SHOULD IMPROVE

1. **Implement the re-fire guard (TODO_LIST:1280) NOW** — its inputs (existing `*_window-closeout_*` report + footer commits for the window's task IDs) are trivially greppable; three paid no-op fires and counting.
2. **Fix TODO_LIST:23 (the hermes-agent re-pin) before anything else dispatches against SystemNix** — a tiny input re-pin that unblocks the verify gate for every future dispatch. Alternatively/additionally: give docs-only dispatches a docs-scoped verify (check-todo-system + link check) so a red Nix eval cannot void a docs closeout.
3. **Verdict durability: write `$TQ_RESULT_FILE` immediately after the report commit**, before end-of-session verification — a completed closeout must never depend on the verify gate's health.
4. **Budget headroom for done-prompt/verdict dispatches** (owner call — see §g1): the window's closeout was delayed ~18 h by the 30/30 budget gate.
5. **Predecessor-first verification works** — this pass's only new findings came from the dispatch-chain journal query, which no predecessor ran. Add "pull the task's own lifecycle from the journal" to the re-dispatch protocol's step 2 (live probe).

## f) NEXT THINGS

Dedup-checked against the live queue; everything below marked QUEUED is an existing open row (not re-minted). Newly appended this pass: items 1–3 (see Docs-health record).

1. **Fix the dead dispatch verify gate**: land TODO_LIST:23 (hermes-agent input re-pin, restores `nix flake check --no-build`) and/or scope `.tq-verify` for docs-only diffs to a docs-safe command. — APPENDED (highest leverage: every dispatch currently fails verification)
2. **Verdict durability rule for dispatch sessions**: write `$TQ_RESULT_FILE` right after the report commit; codify in docs/CONTRIBUTING.md next to the daemon-race policy. — APPENDED
3. **Owner: budget carve-out for done-prompt/verdict-recording dispatches?** — APPENDED as BLOCKED (§g1)
4. Implement the done-prompt re-fire guard. — QUEUED (TODO_LIST:1280; now four-fire proven)
5. Implement the sev1 chronic-storm latch. — QUEUED (TODO_LIST:1235) + owner threshold/breadth decision (TODO_LIST:290)
6. Deploy + live-verify the inboxclean canary (`[blocked:deploy]`, TODO_LIST:1186); fix its `scrape_errors` fail-open first (TODO_LIST:1226). — QUEUED
7. Exercise the pre-vacuum gate §15 live. — QUEUED (TODO_LIST:289)
8. Push InboxClean master (3 tested commits incl. the cached /health) + SystemNix pickup. — QUEUED `[blocked:push]` (owner)
9. Freeze-#27 death-minute ranked verdict. — QUEUED
10. Resolve-or-correct §f.30 (TODO_LIST:594); canary footer-record (TODO_LIST:595). — QUEUED
11. Triage the DRIFT + unharvested-§f backlog. — QUEUED (TODO_LIST:44, :1236)
12. Desktop-state snapshot collector; session-1386 crush.db pinning; niri DeviceMissing root cause; upstream niri WARN rate-limit. — QUEUED
13. tq upstream: harvest-tick cursor, pre-spawn PSI gate, `task.reprioritized` facts (one lane after this pass's dedupe). — QUEUED

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Should the daily budget (30 tasks) carve out headroom for done-prompt/verdict-recording dispatches?** This window's closeout was written four times and recorded zero verdicts, partly because the budget gate parked the chain ~18 h (05:36→23:59 Oct 14) after the first report landed. A reserved slot (or a higher closeout priority) would guarantee a finished window actually terminates. — APPENDED as BLOCKED
2. **Deploy-train priority** for the five verified-in-tree changes — already queued as the `[decision]` row TODO_LIST:1281; not re-minted.
3. **InboxClean master push** — already queued `[blocked:push]` (docs/todo/stability.md); not re-minted.

## h) BAND DRIFT (ADR-0015)

**None recorded.** Re-verified against the production journal this pass: `tq facts --db /mnt/pool/services/tq/tq.db` holds 12,008 facts with **zero** `task.reprioritized` events (a naive grep shows 3 hits, but each is a `task.requeued` line whose free-text payload quotes agent progress text containing the word — not a fact of that type). The upstream fix owns the accountability gap; its duplicate rows were consolidated this pass (TODO_LIST:583 ticked as duplicate of :1219, executing TODO_LIST:1279). Until the fact type ships upstream, priority moves are recoverable only anecdotally from queue-row edit history.

## Docs-health pass record (this pass's writes)

- **TODO_LIST.md**: ticked TODO_LIST:583 (`task.reprioritized` upstream ask) as DUPLICATE of :1219 — executes the queued dedupe row :1279; appended 3 new rows (§f items 1–3: verify-gate fix, verdict-durability rule, budget-carve-out question as BLOCKED). No other edits; no rewording.
- **FEATURES.md**: added 3 Monitoring rows for the window's verifiably-shipped tools (pre-vacuum evidence gate ✅, io-psi-crosscheck ✅, inboxclean-canary 📋 PLANNED — module exists, not yet deployed); header stamp updated.
- **CHANGELOG.md / README.md / ROADMAP.md / AGENTS.md**: no drift found vs this window (CHANGELOG already carries all four items — verified; README is end-user sales, window items are internal gates; ROADMAP's IO-telemetry ideas unaffected; AGENTS.md prevention table already lists §15 and docs/agents/stability.md absorbed the gate mechanics + phantom verdict).
- **Archives**: none qualified. The five per-task closeouts and the three predecessor window-closeout reports all carry open residuals or are cited as `Source:` by live queue rows (TODO_LIST:289 et al.) — "fully done and no longer referenced" fails for each.
