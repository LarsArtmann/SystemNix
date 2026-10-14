# Window Closeout (RE-FIRE) — five-task roundup 2026-10-13 → 2026-10-14, re-verified 2026-10-15

Written 2026-10-15 00:40 CEST. Scope: the completed window of five queue tasks, re-dispatched to the done-prompt role. **This window was already closed out once**: `docs/status/2026-10-14_05-03_window-closeout-20261013-14-five-task-roundup.md` (commit `7333beb3`) covers the exact same five task IDs. Per the re-dispatch verification protocol (docs/CONTRIBUTING.md), this report does NOT re-derive that closeout — it verifies its claims against the live tree, records the delta since (nothing landed on these five tasks between 2026-10-14 05:03 and this pass), and closes the loop on the prior report's own follow-up obligations. Not a whole-project inventory; the 2026-10-14-evening sessions (geometrikks, templ pin, dnsblockd hot-db wave, crowdsec stage 1) are separate windows and out of scope.

## The window's tasks (re-verified)

| Task | Ask | Verdict (this pass) |
| --- | --- | --- |
| `000001a132640f21` | [blocked:user] Freeze #27 owner desktop question | Correctly-blocked close stands (commit `1d297b0e`, closeout report on disk). Desktop-state snapshot collector + crush.db session-pinning follow-ups still open unchecked rows. |
| `000001a1327f85c6` | [ready] Pre-vacuum evidence gate | LANDED and verified: `scripts/pre-vacuum-evidence-gate.sh` present, `checks.pre-vacuum-gate-selftest` pinned in `flake/parts/checks/selftests.nix`, queue row ticked (TODO_LIST:154) with the 11-boot backfill narrative. **Never exercised live on evo-x2** — TODO_LIST:289 still open. |
| `000001a132c43023` | [ready] inboxclean-web Handler-timeout canary | LANDED after the build-broken false start (`bbae5884` → fix `dc3ad6e7`): `modules/nixos/services/inboxclean-canary.nix` present, closeout `8be4a563`. Live verification still `[blocked:deploy]`; batch-ID footer-record row still open (TODO_LIST:595). |
| `000001a13771626a` | [ready] Deploy-gate iostat/top-cgroup crosscheck on PSI refusal | LANDED and verified: `scripts/io-psi-crosscheck.sh` present, `checks.io-psi-crosscheck-selftest` (+ deploy.sh wiring tripwire) in selftests.nix, queue row ticked (TODO_LIST:144), ghostty io_uring phantom verdict recorded in `docs/agents/stability.md`. |
| `000001a137e9fb10` | [ready] SEV1 notify-tier steady-state alert fatigue | DESIGN-only close stands (`aa7b3a75`, closeout `99d215b6`); implementation row open (TODO_LIST:1235); owner threshold/breadth decision row open (docs/todo/stability.md:248). |

## a) FULLY DONE (re-verified, not re-claimed)

1. All five tasks' deliverables exist in the tree exactly as the 2026-10-14 05:03 closeout claimed: three scripts, two flake-check selftests (4 selftest references in `flake/parts/checks/selftests.nix`), the canary module, the sev1 library row, and four closeout/evidence reports on disk. No claim in the prior report was found false on this pass.
2. The two queue-surface ticks (pre-vacuum gate, io-psi crosscheck) are present in `TODO_LIST.md` with evidence narratives, not bare ticks.
3. `CHANGELOG.md` carries entries for all four shipped items (pre-vacuum gate §15, io-psi crosscheck + phantom verdict, canary with its build-failure honesty, sev1 latch design) — the living docs absorbed this window correctly.

## b) PARTIALLY DONE (unchanged since the prior closeout; these are the live residuals)

1. **Chronic-latch implementation** — design ready, zero code (TODO_LIST:1235); sev1 still spams steady-state notify today.
2. **Canary live verification** — built, fixed, never deployed (blocked:deploy row).
3. **Pre-vacuum gate live exercise** — fixture-tested, never run against the real box (TODO_LIST:289).
4. **inboxclean-web /health cached path** — upstream `2ee3860` tested and unpushed; pickup row `[blocked:push]` (docs/todo/stability.md:199).
5. **Freeze-#27 death-minute ranking** — actors attributed, no single verdict yet.
6. **§f.30 phantom citation** — resolve-or-correct row open (TODO_LIST:594); the stale pointer still sits in the closed sev1-fatigue rows (TODO_LIST:169).

## c) NOT STARTED

Nothing new was started on these five tasks between the prior closeout (2026-10-14 05:03) and this pass — the window's queue is fully parked on its residuals. The `task.reprioritized` journal-facts upstream row remains unstarted, so band-drift sections stay structurally empty (§h).

## d) TOTALLY FUCKED UP (this pass's findings, on top of the prior report's §d)

1. **The done-prompt itself re-fired for an already-closed window.** The 2026-10-14 05:03 report closed these exact five task IDs; this dispatch repeated it. Cost: one paid dispatch that produced verification + delta only. Root cause candidate: the queue's done-prompt trigger did not consult the existing window-closeout report (or the tasks' footer-greppable closeouts) before re-enqueueing. Worth a harvest-gate rule: a done-prompt for a window whose task IDs all have footer commits AND a `*_window-closeout_*` report already in docs/status/ is a no-op close, not a re-write.
2. **Near-duplicate queue rows for the reprioritized-facts ask**: TODO_LIST:583 (minted 2026-09-29) and TODO_LIST:1219 (minted 2026-10-13) are the same upstream ask — the second fire mints paid no-op dispatches until one is ticked as duplicate. Queued below (fix item; ticks are the only allowed edit to existing rows).
3. **The prior report's §g.3 claim ("pending-deploy-train priority QUEUED") did not land** — no deploy-train-priority row exists on either queue surface (grep-verified this pass). A close-out claimed a queue write that never happened; the question is queued below as BLOCKED.
4. Prior report's own defects (canary eval-green/build-red ship, missing closeouts on 2 of 5 tasks, WARN-only DRIFT compounding ~20 rows + ~105 unharvested §f reports) all remain unremediated — their queue rows are live and untouched, not forgotten.

## e) WHAT WE SHOULD IMPROVE

1. **Done-prompt windows need a re-fire guard**: check for an existing `window-closeout` report covering the window's task IDs before dispatching the done-prompt (see §d1).
2. **Close-outs must queue-verify their own writes**: the prior report said "QUEUED" for §g.3 and never wrote the row — the same assert-WHICH-surface class as the 2026-09-29 rule. A trailing `rg` of the claimed row would have caught it in seconds.
3. The prior report's improvement items (closeout-report discipline, build-the-drv verification, per-unit decomposition beside aggregate gate signals, design-as-library-row, gate-don't-plead) all remain valid — they are queued rows; no re-mint here.
4. Keep the re-dispatch protocol at the top of done-prompt sessions: this pass's only real work (delta verification, §d discoveries) came from reading the predecessor report FIRST instead of re-deriving.

## f) NEXT THINGS (dedup-checked; everything else from the prior report's §f list is already live rows — not re-minted)

Appended to TODO_LIST.md this pass:
1. **Dedupe the two `task.reprioritized` upstream rows** (TODO_LIST:583 + :1219 — same ask, second mint 2026-10-13) — tick the older as duplicate-of-newer per protocol, keeping one dispatch lane.
2. **Done-prompt re-fire guard**: harvest-gate/doc-side rule that a window with existing closeout report + footer commits closes as a verified no-op.
3. **Exercise the pre-vacuum gate live** — already queued (TODO_LIST:289), listed here as the highest-value unverifiable-gate item, NOT re-added.
4. Owner deploy-train priority question — appended as BLOCKED (§g).

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Pending-deploy train priority**: five verified-in-tree changes await the next evo-x2 deploy (canary fix `dc3ad6e7`, io-psi-crosscheck, pre-vacuum §15, tq-pool PSI gate, census ring; chronic-latch once built). Any ordering/deadline constraint, or next-quiet-window as usual? (Re-asked: the prior closeout claimed this was queued but no row exists — now it is, as BLOCKED.)
2. **InboxClean master push** — covered by the existing `[blocked:user]` row (docs/todo/stability.md:249); not re-minted.
3. **Sev1 chronic-latch threshold/breadth** — covered by the existing `[decision]` row (docs/todo/stability.md:248); not re-minted.

## h) BAND DRIFT (ADR-0015)

**None recorded.** `tq facts --type task.reprioritized` re-verified this pass against the live tq.db: zero facts of that type (the type is not emitted by the current go-taskqueue build — 11,495+ facts, zero reprioritized). The upstream fix rows are TODO_LIST:583/:1219 (see §d2 — themselves duplicated); until the fact type ships, this section is unfilled by construction in every window closeout.
