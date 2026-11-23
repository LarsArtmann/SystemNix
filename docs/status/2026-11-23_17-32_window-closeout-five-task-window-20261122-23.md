# Window closeout — five-task window 2026-11-22 → 2026-11-23 (reviewfix · forgejo prune signal · %3N stamps · Overview Gatus coverage)

**Window:** 2026-11-22 08:32 CET (reviewfix task created) → 2026-11-23 16:50 CET (batch 4 completed)
**Task IDs:** 000001a2022ba9d94b065ee78aa400000000 · 000001a2039e845629f2188beb0a00000000 · 000001a204035b622c57bfc006a600000000 · 000001a205c8d363003c4f7bb5f900000000 · 000001a208e36b699ad48b68574300000000
**Dedup check at dispatch:** no earlier window report names any of these task IDs or the commits 23df5f0da/73365dc4f — the 2026-11-22 window reports (15-46 closeout + four reverifies) cover the monitor365 five-task set. Fresh full pass, no same-window hit.
**Closeout report pre-read:** docs/status/tasks/2026-11-23_16-24_task-000001a208e36b699ad48b68574300000000.md (task 5's own self-review — read first per contract)
**Queue-DB read:** task payloads read from /mnt/pool/services/tq/tq.db (read-only) — the dispatch listing shows only each batch's item 1; every task in this window was actually a FIVE-ITEM batch (25 dispatched items total, 24 agent-actionable + 1 review finding).

## a) FULLY DONE

All five tasks reached `completed` in the queue (timestamps from tq.db, CET). Verification below is this session's own greps/probes against HEAD and the LIVE system, not a transcription of the tasks' self-reports.

**1. Review-fix task 000001a2022ba9d94 (completed 11-22 15:14:45) — the finding IS fixed in tree.**
- Finding (low): monitor365-server composed `serviceConfig` as a continuation-line `// ioTier.heavyDB` shallow merge, deviating from the documented `lib.mkMerge` pattern (lib/default.nix:509, docs/agents/systemd.md) — future `mkDefault`/`mkForce` priorities inside an ioTier fragment would be silently clobbered. Anchor text `// ioTier.heavyDB;`; rejected change commit afecf20d6f (2026-11-22 06:23, the monitor365 storm-wedge isolation).
- Verified fixed: `rg '// ioTier' modules/` → zero hits; the mkMerge form is live at modules/nixos/services/monitor365.nix:612-634 and :1079-1096; fix commit **1f1517f8e** (2026-11-22 15:35:10, "fix(services): stop ioTier precedence loss and world-readable identity DB"). The same commit also fixed a world-readable summit-planner identity.db (`UMask=0077`) — a bonus beyond the finding.
- **Attribution defect, see §d.1:** 1f1517f8e carries NO Task-Queue-ID footer, its message narrates the mic-monitor/media-atlas closeouts (not the review ticket), and its commit time (15:35:10) POSTDATES the task's recorded completion (15:14:45). The fix→ticket link exists only through this report.

**2. Batch 000001a2039e8456 (5-item services batch, completed 11-22 17:04:18):**
- **Forgejo mirror-health prune-notice signal — LANDED AND NOW VERIFIED LIVE.** Collector emits `forgejo_mirror_health_prune_candidates` (modules/nixos/services/_forgejo-scripts.nix:1602), Gatus presence anchor + "Forgejo Dead Mirror Candidates" check (modules/nixos/services/forgejo.nix:1816), fixture legs (flake/parts/checks/fixtures-forgejo.nix:449/460, asserting both the 0 and 1 renderings). Code rode daemon commit f0f45a573 (11-22 16:10); docs/tick commit 23df5f0da (11-22 16:35, footer). **This pass verified it live on evo-x2:** the node-exporter textfile carries `forgejo_mirror_health_prune_candidates 0` + `forgejo_mirror_health_scrape_errors 0`, and the RUNNING gatus config (store path 4bswlf1wq…) carries the anchor at line 2740. Row 539 ticked this pass.
- **bank-sync verdict-only SCA classification** — landed on bank-sync master (bab992ad), per docs/todo/services.md:349; deploy still gated by the durable 67dd64526 pin (the deployed daemon still runs a31024c7, so the fix is NOT yet live — correctly rowed as pending, not claimed shipped).
- Items 3–5 were `[blocked:user]` and stayed owner-gated by design: sync-token re-paste (see tick below — premise verified dead this pass), 4 orphaned setup PATs (count still 4), stale `gitea.db` fossil trash.

**3. Batch 000001a204035b (5-item forgejo/catalog batch, completed 11-23 01:21:11):**
- **architecture-catalog VM test** (tests/test-architecture-catalog.nix, footer commit 73365dc4f 11-23 01:01) — real-unit end-to-end legs; CAUGHT a real module bug: same-second sync runs collided on the generation stamp and `mv` nested the incoming tree inside the existing generation, silently keeping old content served. Module fix (`stamp="$(date +%Y%m%d-%H%M%S%3N)"`) rode daemon commit 1b885edc7 (11-22 20:27) with the rationale comment inline. Test-commit and fix-commit ordering is inverted across daemon sweeps (fix hit master ~4.5 h before the test commit that documents catching it) — content correct, narrative order artifactual (§d.2).
- **%3N stamps verified live** (batch 3's item 1, row 540 ticked DONE 11-23 with live evidence: ms-suffixed generation dirs, `current` flipping hourly, live store-path grep). Re-confirmed this pass: `ls /var/lib/architecture-catalog/generations | tail` → 20261123-170000288 / 180000096 / 190000103; `current` → generations/20261123-190000103.
- **setup-forgejo.sh loud-fail on empty FJ_SHA** — hub commit 9f71d41 (11-22 17:12), row 547 ticked (cross-repo work, correctly ticked with `repo:` evidence).
- **Forgejo + architecture-catalog runbook capture** — row 545 ticked DONE 11-22.
- **Fixture-from-live discipline** — hub commit 32b4d51 (11-22 17:17, "capture live Forgejo API payload fixtures").
- Item 1 (verify prune signal post-deploy) was NOT verifiable at session time — no deploy carrying 23df5f0da had fired (the 00:48 attempt was pressure-refused). The session completed with that item honestly pending; the batch's boilerplate "Outcome: every item landed" over-claims (§d.5). Closed by THIS pass's live verification.

**4. Batch 000001a205c8d363 (5-item batch, completed 11-23 15:46:18):**
- **Runner job-lifecycle observability** — `log.level = "debug"` with the source-verified rationale (forgejo.nix:100-112; commits 005722287 footer + ca374713b daemon). Row 551's close-out also killed the journal-volume fear analytically (empty-fetch rounds log NOTHING even at debug; volume is job-proportional). **Live this pass:** the runner journal shows `level=debug` gc/poller lines since the 19:30 restart; the deploy-gated residual (step Run/Success/Failure lines during a REAL CI job) is still pending — no CI job has run since the restart (2 grep hits, both startup lines).
- **Label-drift eval selftest** — commit aa61e386a (11-23 02:44, "eval selftest pinning runner label semantics").
- **Overview outage row closed with recorded root cause** — a7ab7124e (15:19); the PMA runtime-dir kill-chain fix (c10d80f7d) confirmed live 46 days post-fix (:8083 → 200 direct AND through Caddy).
- **crush-daily report-gap row closed** — 47d51e511 (15:25, footer): Go rewrite carries `--no-event-dates` backfill (verified in locked rev), flake app swapped to the Go binary, Python deleted, all 21 gap dates backfilled (305-672 KB each).

**5. Batch 000001a208e36b699 (5-item services batch, completed 11-23 16:50:36)** — per its own closeout (docs/status/tasks/2026-11-23_16-24_…, read first per contract), independently re-verified here:
- **Overview vHost Gatus probe — LIVE NOW.** Tree-side at session end; tonight's deploys carried it: the RUNNING gatus config line 3363 (`name: Overview vHost`, title-anchored body pat + status/latency conditions). The 2026-10-07 "outage invisible to every standing monitor" class is now covered. README endpoint count re-stamped 314→315 by the batch.
- **post-deploy-check polkit slot-ownership leg** — landed (bus-socket guard → graphical-session gate → gdbus GetNameOwner + owning-PID PASS line), branch-verified; PASS branch still mock-proven only (needs a graphical session).
- **docs/services/dms.md runbook** created + routed from docs/agents/desktop.md; **Oct 3 polkit requester dig closed evidence-dead** with an exhaustive absence sweep; **polkit prompt render** stays owner-gated ([blocked:user], correctly re-tagged so deploy waves stop dispatching it).
- The batch's false premise ("zero overview entries … live-verified by grep") was corrected on ALL surfaces — including the durable rule in docs/agents/monitoring.md (dc4978dbd) that coverage greps must include the owning module.

**Deploy state at report time (this session's own probes):** two deploys fired DURING this reporting session — 19:09 (code=0, 548 s) and 19:19 (code=3, 669 s, post-switch; see §d.3). The live system carries the whole wave: Overview vHost check, prune-signal anchor, %3N stamps, runner debug. Live generation dirs advance hourly; sync green.

## b) PARTIALLY DONE

1. **Row 810 ("Deploy the 2026-11-23 wave … verify Overview vHost live … polkit leg in full context")**: the deploy precondition is now MET (two deploys fired; Overview vHost LIVE in the running gatus config), but the row's remaining asks — green first gatus results for the new endpoint and one FULL post-deploy-check battery run exercising the polkit leg in script context — are still open. Left unchecked (honest); next battery run closes it.
2. **Polkit slot-ownership leg PASS branch** — mock-proven only; live proof waits for the next graphical login (rows 552/1192 own it).
3. **bank-sync bab992ad** — deployed daemon still a31024c7; float+deploy gated by the 67dd64526 pin (services.md:349 owns it). Code landed, effect not live.
4. **Runner-debug CI-job residual** (row 551's deploy-gated leg) — debug lines confirmed live, but the step-lifecycle proof needs one real CI job post-deploy. Watch-grade; no new row (the ticked row carries the residual text).
5. **Forgejo prune candidates value is 0 live** — the signal exists and anchors, but has never yet rendered a nonzero value in prod; the fixture legs prove the 1-rendering, prod proof waits for the first real prune event.

## c) NOT STARTED

1. Nothing dispatched in this window was silently skipped: all 25 items either landed (verified above) or were `[blocked:user]`-tagged and stayed owner-gated by design (PAT deletion, gitea.db fossil, polkit prompt render — all have existing rows).
2. The standing backlog (3,486 unchecked TODO_LIST rows at pass time) was untouched by design — the window's batches worked only their own items plus the follow-ups they harvested.
3. The 03:56 deploy's exit-3 regression signal (forgejo-runner smoke, storm-downgraded) was never formally adjudicated — it self-resolved (the 19:09 battery re-ran green; the runner is healthy and declared at 19:30), but no closing note exists anywhere. Recorded in §f.

## d) TOTALLY FUCKED UP

1. **The reviewfix ticket's fix is git-untraceable.** The fix (1f1517f8e) carries no `Task-Queue-ID` footer, its commit message narrates a DIFFERENT session's closeouts (mic-monitor + media-atlas reports ride the same commit), and its commit time postdates the ticket's recorded completion by 21 minutes. The queue's own re-dispatch check ("grep git log for your footer") can never connect this fix to this ticket. Either the verdict was recorded before the fix commit landed, or a different session authored the fix — git cannot tell. A re-fired identical finding would re-derive from scratch.
2. **Daemon sweeps inverted the fix/test order and mangled the narrative.** The %3N module fix landed (1b885edc7, 11-22 20:27) ~4.5 h BEFORE the VM-test commit that "caught" the bug (73365dc4f, 11-23 01:01). Content is correct; the commit-message story ("test caught it, fixed same commit-generation") describes intent, not what master's history shows. Four daemon commits carried the VM test's code across the evening (c89318221/1b885edc7/b2a660865/16f1fbad8) — the same shape the 16-24 closeout flagged as §d.4.
3. **Two of tonight's three deploys exited 3 on NEW-smoke-failure regression signals.** 03:56 (forgejo-runner, under an active IO storm — storm-downgraded, later green) and 19:19 (Bank-Sync, Quotaboard API/health :8791, SearXNG — "NEW failures vs baseline", exit 3). This pass re-probed at ~20:05: SearXNG :8889 → 200 and bank-sync :8097/metrics → 200 (transient post-switch settle — the 2026-10-25 "smoke FAILs quoting just-restarted units are stale" class), but **quotaboard :8791 is STILL connection-refused** — a standing failure that the battery cannot distinguish from expected-down because quotaboard is a homeModules USER service (quickshell.nix:29) and the box is in an SSH-only period. The smoke baseline has no concept of session-scoped user services. Row appended (§f.1).
4. **The checkpoint-skeleton ritual was defeated by the daemon.** My skeleton report was committed by a daemon sweep (b8e2cb82d, 17:34:38) two minutes after write; my own follow-up pathspec commit then found "nothing to commit". The file survived (recoverability held by luck of the 10-min cadence), but the contract's "commit immediately" needs write+commit in ONE tool batch — the assistant-turn boundary between write and commit was the daemon's window.
5. **Batch boilerplate over-claims completion.** Every batch payload's outcome text reads "Outcome: every item landed, verified, committed" — mechanically appended even when an item was knowingly pending (batch 2's item 1 rode the next deploy). The honest per-item state lived only in the TODO rows; the queue's own record over-states. A close-out convention that states per-item disposition (landed / blocked-on-deploy / owner-gated) would prevent a future dedup pass from trusting the boilerplate.
6. **Living-docs lag:** none of batch 1–4's user-visible features (prune signal, %3N stamp fix, runner debug visibility, label selftest, Overview vHost coverage, polkit leg, dms runbook) had a CHANGELOG entry until this pass added one. FEATURES.md needed no change (its forgejo row already reflects mirror-health reality).

## e) WHAT WE SHOULD IMPROVE

1. **Reviewfix sessions must stamp their fix commit with their own ticket footer** — the prompt already instructs it; it was not followed, and the queue's completion derivation did not notice (verdict-file completion ≠ git-state completion). Codify + consider deriving reviewfix completion from the fix commit's existence. (Row appended.)
2. **Write+commit in one tool batch for checkpoint files** — the skeleton contract's value depends on beating the 10-min daemon; any assistant-turn gap is a race loss. Same discipline as the tick-and-commit rule, extended to checkpoint commits.
3. **Deploy smoke needs a session-scoped-service concept** — user services (quotaboard via homeModules) generate NEW-failure exit-3 regression signals that mean nothing during SSH-only periods, and each one costs a full deploy-cycle of investigation. Either gate such checks on the graphical session or baseline them per-session-state. (Folded into the quotaboard row.)
4. **Batch close-outs should state per-item dispositions**, not "every item landed" — the queue derives history from these; boilerplate that over-claims becomes false history the moment one item waits on a deploy.
5. **Cross-repo batch items should cite the landed commit id in the tick** — batch 2's hub-side items did this well (9f71d41, 32b4d51); keep that as the standard for `repo:`-flavored work.
6. **The dispatch-time dedup check worked** — this window overlapped heavily with five 2026-11-22 window reports (monitor365 set) and zero of this window's five task IDs appeared in any of them; the check correctly routed this to a full pass. Keep running it first.

## f) NEXT (honest, dedup-checked — 5 appended to TODO_LIST, cap 10)

Appended this pass (5 of 10 cap, all dedup-checked):
1. **Diagnose standing quotaboard :8791 refusal + decide the deploy-smoke treatment of session-scoped user services** (§d.3; SearXNG/bank-sync confirmed transient, quotaboard standing) → docs/todo/desktop.md.
2. **Reviewfix footer-attribution rule** (§d.1) → docs/todo/pipeline.md.
3. **[BLOCKED] Attribute tonight's 19:09/19:19 deploys** (owner-fired or session-fired) → docs/todo/pipeline.md.
4. **[BLOCKED] Prune-candidates paging policy** (presence-only anchor vs paging on sustained nonzero) → docs/todo/monitoring.md.
5. **[BLOCKED] Is quotaboard expected-down during SSH-only periods?** (owner usage pattern decides whether the smoke check or the service wiring is wrong) → docs/todo/desktop.md.

Existing rows that own the window's natural follow-ups (deduped, NOT re-queued):
6. Row 810: green first results for Overview vHost + one full battery run of the polkit leg (deploy now fired; the verify is unblocked).
7. Row 320: Gatus missed-page adjudication timebox + explicit `storage.retention` decision.
8. Row 811: post-deploy-check generic `--sections` filter (the polkit leg's full-context run becomes cheap).
9. Rows 1191/1192 + 552: settings.json HM-management verification; first real-session polkit PASS proof (folds the prompt-render visit).
10. services.md:349: bank-sync float+deploy behind the 67dd64526 pin (bab992ad goes live there).
11. desktop.md:67/68: polkit prompt render (owner visit); Oct 3 requester row dies permanently on the owner's "no".
12. services.md: PAT deletion (count still 4) + gitea.db fossil trash — both owner-gated.
13. First real prune event: watch `forgejo_mirror_health_prune_candidates` render nonzero with `prune candidate:` journal names (watch-grade; the fixture legs already prove the rendering).
14. Adjudicate-in-passing: the 03:56 exit-3 (forgejo-runner, storm) self-resolved by the 19:09 green battery — no row warranted; noted here as the closing record.
15. Runner-debug CI-job residual: one real CI job post-restart proves the step-lifecycle lines (row 551's ticked residual carries it; no new row).
16. Row 551's sibling: nothing else deploy-gated remains from these batches — every landed change is now LIVE (verified §a).

(Stopping at 16 — the window's own follow-ups are largely already rowed by the four batch sessions; padding further would mint duplicates.)

## g) QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Were tonight's 19:09 (exit 0) and 19:19 (exit 3) deploys fired by you, or by an agent session?** Both carried the monitoring wave; the 19:19 exit-3 regression signal is unadjudicated, and deploy-vs-executor attribution changes how the quotaboard finding gets handled.
2. **Should sustained nonzero `forgejo_mirror_health_prune_candidates` page?** The new signal is presence-anchored and advisory by design (a prune leaves the fetch fresh). If a prune storm should wake you, the Gatus check needs a value threshold; if not, the advisory value + 6h cadence stands.
3. **Is quotaboard expected to be down when no graphical session is running?** It is a homeModules user service; if you only ever see it inside a desktop session, the deploy smoke check (not the service) is what needs fixing — if you expect it up always, the service wiring needs a look.

## h) BAND DRIFT

**None recorded.** Fresh read this session: `tq facts --db /mnt/pool/services/tq/tq.db --type task.reprioritized` → `(0 facts)`. Sixth consecutive independent read with the same result (the five 2026-11-22 window reports each re-read it fresh too).

## Harvest ledger (TODO_LIST appends: 5 of 10 cap)

| # | TODO_LIST row | Library twin |
|---|---------------|--------------|
| 1 | Diagnose standing quotaboard :8791 refusal + smoke treatment of session-scoped user services [ready] | docs/todo/desktop.md |
| 2 | Reviewfix sessions must footer their fix commit (attribution rule) [ready] | docs/todo/pipeline.md |
| 3 | Attribute tonight's 19:09/19:19 deploys — BLOCKED: owner or session? | docs/todo/pipeline.md |
| 4 | Prune-candidates paging policy — BLOCKED: page on sustained nonzero? | docs/todo/monitoring.md |
| 5 | Quotaboard expected-down during SSH-only periods? — BLOCKED: owner usage pattern | docs/todo/desktop.md |

Ticks this pass (evidence-backed, the only other allowed edit): TODO_LIST:539 (prune signal verified live), TODO_LIST:538 (token re-paste verified-superseded — see below).

## Re-verification notes recorded this pass

- **Row 539 ticked:** metric live (`forgejo_mirror_health_prune_candidates 0`, `forgejo_mirror_health_scrape_errors 0` in /var/lib/prometheus-node-exporter/textfile_collectors/forgejo_mirror_health.prom), presence anchor live in the running gatus.yaml, hourly sync green.
- **Row 538 ticked (verified-superseded):** zero HTTP-401s in the retained sync journal (2026-11-15 → 11-23; the single `401` grep hit is the writer PID substring `2247[401]`), hourly pulls healthy through 19:00 today (300 M pulled, "Finished"), and the sops token file is untouched since 2026-10-12 (1893e7b23) yet AUTHENTICATES — the orphan premise never materialized; no paste is needed.
- The lone discrepancy found against earlier claims: none — every ticked claim re-verified. The two §d defects are process-level (attribution, narrative order), not content errors.
