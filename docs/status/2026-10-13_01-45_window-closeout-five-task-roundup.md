# Window Close-Out — Five-Task Roundup (2026-10-11 watch fires → 2026-10-13 freeze-27 autopsy)

**Written:** 2026-10-13 01:45 CEST · **Reporter task:** `000001a132640f4915ce6f7e217b00000000`
**Window:** tasks completing 2026-10-11 02:29 → 2026-10-13 00:48 (plus in-passing commits through 1d297b0e)
**Method:** every closeout report read first; every landed claim re-verified against the tree (commits, scripts, checks, TODO/CHANGELOG surfaces). Queue journal (`/mnt/pool/services/tq/tq.db`, 11,495 facts) queried directly for band-drift facts.

---

## a) FULLY DONE

1. **/data watch, 17th + 18th fires (tasks `…a12417…` and `…a12876…`) — self-gated no-ops, correctly closed.** Both closed as bookkeeping-only no-ops under the row's 24h self-gate: the 17th probed `df` 867G/155G free + `du` ai 535G + SteamLibrary 107G + gcs-staging 24G (byte-identical to the 15th's baseline); the 18th re-probed at `du -sb` byte grain — **all three trees byte-identical**, df moved DOWN 1.68 GB (consistent with the known df-vs-du skew class). Neither re-stamped the capped row; both landed footer-bearing evidence commits (3816a6fb empty-record, ce09e79f). The watch row (TODO_LIST:32) stays open `[watch]` by design — correct terminal state, not incomplete work.
2. **Hot-db vehicle defects re-dispatch (task `…a1288c…`) — closed as verified no-op; queue surface healed.** The 4 defects landed 2026-09-30 with the warm-prepare/cutover/finalize rewrite, but the TODO_LIST queue row had stayed open (the exact two-surface drift class). This dispatch live-verified all four in `scripts/migrate-hot-db.sh` (first-run `mkdir -p` :217, finalize verify :271-275, `DRY_RUN` guards :126/:226/:248, per-service stop-sets :82), confirmed the fixture (`checks.migrate-hot-db-fixture`, flake/parts/checks/fixtures-migrations.nix:115), and ticked the queue row with evidence (commit 89410ee9). Verified in this pass: TODO_LIST:121 carries the strikethrough + script line numbers.
3. **Census memory-collector durability ring (task `…a12db75…`) — genuinely DONE, in-tree verified.** `scripts/system-health-census-ring.sh` (append-whole-block, rotate-last-N=720 ≈24h at 2-min cadence, corrupt-ring self-heal, SIGKILL-corpse tolerance) is wired in `modules/nixos/services/system-health.nix:49,867` to append each census block BEFORE the `.prom` publish, ring path never a `.prom`. The one broken leg (selftest `#!/usr/bin/env bash` vs sandbox) was fixed via shebang `sed` in flake/parts/checks/selftests.nix:120-131; `checks.census-ring-selftest` builds green. Both queue surfaces ticked (TODO_LIST:167 + stability.md). Close-out commit 262ede9e footer-bearing.
4. **Freeze-#27 autopsy (task `…a1323f9…`) — DONE with real forensic yield.** Boot -2 journal pulled before vacuum (evidence: docs/status/tasks/2026-10-13_00-37_freeze-27-autopsy-evidence.md). Verdict: chronic whole-boot IO storm + thermal amplifier; death by IO-livelock hard cut, NOT memory (37 Zone-6 trips #2635→#2671, zero OOM, 95–98 °C for hours, cut mid-normal-traffic with counter continuity). Landed artifacts verified: the autopsy report, freeze-#28 evidence preserved pre-vacuum (3a7a26a9), the #28 entry in docs/agents/stability.md hardware-instability list (0c099241), unit-level IO attribution closed (854e5ed8), and **10 follow-up rows self-harvested into TODO_LIST.md + domain libraries at authoring time** (8a70fe57, 5bf6128d, 1d297b0e) — including the owner-blocked desktop-state question (TODO_LIST:144) and the new journal-census.sh + vacuum-audit + tq-harvest-IO rows (:145,:146,:147,:160,:161).

## b) PARTIALLY DONE

1. **Census ring: deployed behavior is statically co-verified only.** Nothing on evo-x2 has run the new wiring — it rides the next deploy, which sits behind the standing cooling-inspection gate. Live verify + Gatus staleness check + post-deploy assert are queued (TODO_LIST:345-347). The "720 blocks ≈ 24h" claim assumes a 2-min cadence that was not grepped from the timer (queued :168).
2. **The freeze-#27 close-out's own ask had an owner-gated leg** (desktop state at the 11:07:59 cut) — correctly split into a `[blocked:user]` row (:144) rather than covered by the `[x]`.
3. **Window hygiene, partially honored:** the 17th's pre-commit bypass justification was reasoned-not-pasted; the 18th inherited that bypass precedent without firsthand gate output (both honestly recorded in their close-outs; the codification row exists at TODO_LIST:853).

## c) NOT STARTED (window skipped, still open)

- The storage follow-up battery the watch fires keep pointing at: the ~85% /data alarm (:34), ai +76G growth attribution (:37), df-vs-du ~175G gap (:47), machine-readable du -sb baseline (:39), gcs-staging evidence+decision (:31/:40).
- The chronic pre-commit gate backlog: **105 unharvested §f-bearing reports** (check-todo-system run live this pass — up from 101 at the hot-db dispatch), the gate escape hatch (:683), the batch triage (:852), the sweep (:42).
- The structural queue fixes: queue-side watch self-gate enforcement (:43), log-only disposition (:44), dispatch-contract template conflict (:56), stamp-vs-fire semantics (:856), re-fire-loop dedup gate (:606).
- Everything behind the deploy gate: the ring wiring, the observability battery (:344), storage-history §14/§19 legs, Pocket-ID auto-rotation apply-mode flip.

## d) TOTALLY FUCKED UP

1. **Paid no-op dispatch burn is now systemic, not incidental.** The /data watch produced 3+ consecutive paid no-op dispatches (16th–18th) inside ~2 h under a 24h self-gate that only the agent side honors. Each fire costs a full dispatch cycle + close-out report. The queue-side fix is queued (:43) but undispatched — every day it waits mints more of these.
2. **The pre-commit TODO gate has been red so long that `--no-verify` is the de-facto docs-commit path.** The hot-db close-out proved the worst consequence: a bypassing commit rode through with **zero** lint legs (gitleaks, deadnix, statix, alejandra) executed. 105 unharvested reports and climbing (101 → 105 across this window). The working protections are being disabled by the broken one's redness.
3. **The freeze-#27 session nearly shipped a WRONG SEV1 verdict** (grep-keyword pattern matched nix-gc store paths; the real 4037-count active line was buried under a `head -10` cut) — caught and corrected pre-commit, but the class (keyword grep + truncated summary as a census) produced the journal-census.sh row (:161). One more instance of "assert WHICH entity served it".
4. **Dead-lettered queue work persists** (5 DLQ tasks, TODO_LIST:553/557) with one new escalation since (the exit-128 sweep window dead-lettering finished-session reports, :565). Band-drift facts: **zero `task.reprioritized` facts exist in the live journal** — the fact type is not emitted at all (see h).
5. **The freeze evidence lineage is split-brained** across docs/agents/stability.md (#1–#7 + #28), docs/todo/stability.md (#8–#27 autopsy sections), and docs/status/tasks/ — the #28 entry cites #27's closure in a todo row, not the doctrine list. Question queued for the owner (below).

## e) WHAT WE SHOULD IMPROVE

1. **Enforce the watch self-gate at harvest time, not agent time** (skip fires <24h past a no-drift stamp) — converts paid no-ops into zero-cost skips. Queue-side, one feature in the harvester.
2. **Give the pre-commit hook a leg-scoped skip** (`CHECK_TODO_SYSTEM=skip` honoring only the TODO leg) so bypassing the red gate stops disabling the working legs; selftest the skip path like the other check-todo legs (:683).
3. **Standardize the alert-state census method** (`-t <syslog-identifier>` + full `sort | uniq -c`, no head) via `scripts/journal-census.sh` so autopsies stop re-deriving grep patterns (:161).
4. **Emit `task.reprioritized` journal facts in go-taskqueue** — the ADR-0015 accountability section of every window report is currently unfilled by construction; verified this pass that the live facts table carries no such type. Queued below.
5. **Both-surface tick discipline at close-out time** (the hot-db re-dispatch burned a paid cycle on a row the original close-out should have ticked); the re-fire protocol already codifies the verification — add the mechanical tick.
6. **A one-off batch harvest of the 105 unharvested §f reports** (oldest-first, domain-batched, or bulk-annotate pre-2026-10-01 as harvested-obsolete) — the single highest-leverage gate-greening move (:42/:819/:1149 all point here; dedupe them when dispatching).

## f) UP TO 50 NEXT THINGS (highest-value first; dedup-checked against the live queue)

Already-queued rows this window re-validated as top priority (do NOT re-mint): /data 85% alarm (:34) · ai +76G attribution (:37) · df-vs-du gap (:47) · unharvested sweep (:42) · gate escape hatch (:683) · gate batch triage (:852) · queue-side self-gate (:43) · log-only disposition (:44) · contract-template conflict (:56) · stamp-vs-fire semantics (:856) · re-fire dedup gate (:606) · ring live-verify (:345) · ring staleness check (:346) · ring post-deploy leg (:347) · cadence verify (:168) · monitoring pointer (:169) · journal-census.sh (:161) · vacuum audit (:160) · tq harvest IO discipline (:145) · inboxclean-web hardening (:146) · desktop-state snapshot collector (:147) · DLQ triage (:553) · DLQ disposition (:557) · exit-128 window root-cause (:565). New/spot-checked items below:

1. **[queued this pass]** Emit `task.reprioritized` facts from the prioritize/sweeper paths in go-taskqueue (ADR-0015) — see TODO append.
2. **Freeze-lineage backfill decision** — owner question, queued BLOCKED this pass.
3. Hot-db wave follow-ups still open from the same library: OnFailure catch-up for dump legs, PATH-stub scaffolding, VM-test rebuild (PSI-gated <20%).
4. `/data/tmp-crush-test` (380M) regenerable-scratch verify + trash; `/data/tmp-bench` + `/data/cache` empty-by-design verify (hot-db close-out §f.11-12).
5. Boot-1 (freeze-#28) open forensics: name the system.slice 60–93 GB/10-min writer; identify the overnight adj −1000 build spawner; the 12:32–13:04 systemd-inhibit retry actor.
6. Post-crash hardware-check leg for the 2026-10-12 13:05 boot (LAN-NIC, DAS mount, boot-mirror sync) — one read-only pass, nobody closed it.
7. Boot-mirror NVRAM reversion #2 (2026-10-12 decode negative): if a re-activation is planned, run the post-boot re-decode protocol (docs/agents/systemd.md).
8. Ring disk-budget + selftest edge cases: keep=1 boundary, concurrent-append atomicity note (census close-out §f.9-11).
9. Generalize the ring pattern to other census families sharing the ingest path (thermal/IO) — same starvation class (census §f.7).
10. SigNoz/rules note: ring is local-only, never scraped — prevent a future "fix" expositing the log (census §f.6).
11. Verify whether the 1030–1114 lines/min journal rate at boot -2's cut is normal or the livelock's leading edge (calm-boot baseline comparison).
12. OOM score policy: cgroup-level ceiling for adj −1000 build scopes so the desktop stops being the softest target (freeze-28 entry's misfire lesson).
13. Pre-notify signal spec for <60s killers (SEV1 notify tier is functionally invisible there — freeze-28's notify reached the owner 15 s before death).
14. "Executed-and-ineffective" guard metric (trips with zero io.stat delta) so the action-split case becomes a queryable series.
15. Gatus freshness check on journal disk usage vs vacuum threshold (evidence-about-to-age-out early warning).
16. Sweep `docs/status/2026-10-12_13-15_freeze-28-crash-diagnosis-session-status.md` §f items 5–11 for live rows — §f.5/§f.6/§f.10/§f.11 verified MISSING this pass by the freeze-27 session; confirm each now has one (rows :145/:146 family may cover part).
17. Per-fire no-op report consolidation convention (:1132) — applies to the /data watch lineage too (17+ close-out files for one row).
18. Retire-or-re-gate the manual /data watch row once the alarm deploys green (:51) — keep visible; it is the exit for the whole no-op-burn class.
19. `node_textfile_scrape_error=1` root-cause (:1139) — note the ring must NEVER join the rejected-.prom class; its never-.prom tripwire is the guard.
20. Census-ring backfill tooling: one-liner to render last-N ring blocks into an autopsy report after a starvation window.

Items 21–50: the live backlog (TODO_LIST.md, 1165 lines, ~280 unchecked rows) already enumerates the rest by domain library; nothing else in this window's scope outranks the above.

## g) QUESTIONS FOR THE OWNER

1. **Freeze-lineage policy:** should freezes #8–#27 get condensed entries in docs/agents/stability.md's hardware-instability list (currently #1–#7 + #28, a 20-freeze hole the #28 entry is bolted onto), or is todo-library ownership intentional with only a pointer block added? Backfill is mechanical but touches doctrine-file voice.
2. **Ring retention sizing:** bump keep from 720 (~24h) to ~1440 blocks so the forensic window spans the 26–27h boots the freeze family actually produces? Cost is trivial; only the owner can size the window (row :168 dispatches the verify either way).
3. **Queue-side watch-gate policy (re-asked, escalated by a 3rd consecutive paid no-op):** should the tq pool skip harvesting watch rows whose last no-drift stamp is <24h old (:43)? If the footer-bearing audit trail is worth the dispatches, say so and the row closes as wontfix.

## h) BAND DRIFT

**None recorded.** The live queue journal (`/mnt/pool/services/tq/tq.db`, facts table, 11,495 facts across `task.enqueued/claimed/requeued/completed/released/failed/dead-lettered/cancelled/question-asked/cancel-requested`) contains **zero `task.reprioritized` facts** — the type is not emitted by this tq build (the known gap the hot-db close-out flagged as go-taskqueue work). `tq facts --type task.reprioritized` returns empty against every reachable db. No priority move in this window is therefore journal-explainable; the accountability ledger needs the emit-fact fix (queued this pass) before this section can ever carry data.

---

**Docs-health pass notes (this file's authoring):** CHANGELOG.md gained Unreleased entries for the census ring and the freeze-27/28 autopsy batch (verified in-tree before writing). TODO_LIST.md gained 2 items (the (f).1/(f).2 pair, dedup-checked against all ~280 open rows). No archives performed: all five closeout reports are live-cited by ticked or open queue rows (evidence citations), so moving them to docs/status/archived/ would break citations; the two `[watch]` rows they serve remain open by design. Live gate state at authoring: `scripts/check-todo-system.sh` → structure OK, **105 unharvested §f reports** (chronic; see d.2).
