# Status — closeout of the ai-stack/reviewer-fix five-task window (2026-11-14 08:06 → 2026-11-15 23:30)

**Authored:** 2026-11-16 ~03:0x CET, task 000001a1e168d2b32f8ac8f25e8700000000 (done-prompt).
**Dispatch-time dedup:** no same-window report exists — grep over docs/status/README.md + docs/status/*.md found only the tasks' own closeout reports naming these five task IDs (the 2026-11-15 14-21 reverification covers the PREVIOUS window's set: 000001a1d5d871… et al). Full derivation pass.
**Method:** all five closeout reports read in full first; every headline landing re-grepped at HEAD; gates re-evaled; queue rows cross-checked for the "claimed vs landed" class this window turned out to own.

**The window's five tasks:**

| Task               | What                                                                                                                                                                     | Landing (verified at HEAD)                                                                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 000001a1d8cbc255   | Research-doc follow-ups (3-item ai-stack batch)                                                                                                                          | GREEN — 254246429, d99ab169f, 9081d2bac (+ daemon 54351154b); closeout 30fb44a26                                                                                             |
| 000001a1d902b185   | Reviewer fix: dangling status-report citation in re-embed design doc                                                                                                     | GREEN — 1f04026ba; phantom filename zero-references at HEAD                                                                                                                  |
| 000001a1d902afe126 | 5-item ai-stack/pipeline batch (research-index mechanize [skipped-as-done], #19482 watch re-probe, planning→research sweep ×8 files, llmUpstream verify, F08 annotation) | GREEN — 2805fa39a, 1e1b39e8a, fb8ad28ac, 3c1d5014d, edfa4aa04; closeout 131a0a36b                                                                                            |
| 000001a1d902b168   | Reviewer fix: demand-profile Method-note correction                                                                                                                      | GREEN — 9688d2a3c; CORRECTION note live in the report at HEAD; closeout 7f48518f7                                                                                            |
| 000001a1d902b18b   | Reviewer fix: RestartSteps regression gate                                                                                                                               | MIXED — gate real and verified (pre-existing via dead session's daemon commit fa78a834c), but the ticket's own closeout carries TWO claims that are FALSE at HEAD (see §d.1) |

---

## a) FULLY DONE

1. **Task 1 (research-doc follow-ups) — all three premises closed, verified at HEAD.**
   - `docs/research/2026-11-05_ai-deployment-research.md` exists in its new home with a real README index row (docs/research/README.md:50, refresh trigger present).
   - Queue row TODO_LIST.md:426 + library row docs/todo/ai-stack.md:18 both ticked with the full three-part closure (no drift between surfaces).
   - The systemd-262 live verification and demand-premise answer are recorded in both surfaces.
2. **Task 2 (dangling citation fix, 1f04026ba)** — `grep -rn "docs/status/2026-11-14_06-15_ai-demand-profile-and-write-attribution" docs/planning/ docs/todo/` returns ZERO at HEAD: the phantom merged-filename citation is fully gone from the re-embed design doc; the real two report files exist. Footer-bearing commit; closeout ae3075a1d.
3. **Task 3 (5-item batch) — all five items closed, each verified:**
   - Item 1 (mechanize research-index) correctly SKIPPED as already done: `flake/parts/checks/research-index.nix` exists (forward+reverse legs, lines 61-65), pre-existing via daemon 12f604ca7; **I re-evaled the gate at HEAD tonight: GREEN** (`/nix/store/kcsh6kx7…-research-index.drv` — byte-identical drv to the batch session's own run, corpus unchanged since).
   - Item 2 (watch #19482): RE-PROBE evidence present in TODO_LIST.md:436 (#19482 OPEN, fix-candidate PR #31886 OPEN/unmerged since 11-12, staleness trigger recorded).
   - Item 3 (planning→research sweep): all 8 moved files confirmed present under docs/research/ at HEAD (rustfs, go-cache-ssd2, btrfs-subvolumes-analysis, systemd-appd, crowdsec-study, wazuh-review, nix-colors-research, contacts html); README indexed at 47 rows; the mid-batch annotation correction (14→20 repoints) honestly recorded in the tick (TODO_LIST.md:437).
   - Item 4 (llmUpstream verify): ticked with three-leg evidence (TODO_LIST.md:438) — zero tree overrides, zero fastflowlm assignments in history, AUTO-FOLLOW makes a live flm lane eval-impossible.
   - Item 5 (F08 annotation): header note live in docs/status/2026-11-14_07-59_llama-cpp-spin-upstream-attribution.md:5-6.
   - Sort-fix fix-on-sight (edfa4aa04): the dated oauth2 row moved to its section top.
4. **Task 4 (method-note correction, 9688d2a3c)** — the CORRECTION (2026-11-15) note is live at docs/status/2026-11-14_06-15_ai-demand-profile.md:5-10; the false "full retained window" phrasing has ZERO remaining occurrences; the admitting closeout's §d.1 (docs/status/tasks/2026-11-14_07-04…:83) carries the FIXED annotation. Both citing surfaces re-read — they quote verdicts and paths only, still true post-correction. Closeout 7f48518f7.
5. **Task 5 (RestartSteps gate) — the gate itself is real and verified at HEAD:**
   - `checks.crash-loop-backoff-contract` exists (flake/parts/checks/selftests.nix:1566-1594) pinning RestartSteps=5 + RestartMaxDelaySec="15min" on all three named units via the extendModules throwaway pattern.
   - The three `CASES=backoff` mutation legs exist in scripts/negative-test-lints.sh:1007-1011 (rag-steps-dropped, rag-maxdelay-dropped, nsfw-pair-dropped).
   - The pinned settings live in the modules (llama-rag.nix:94-95, nsfw-classifier.nix:172-173).
   - The b18b session correctly did NOT re-author the existing gate (authored by a dead session via daemon commit fa78a834c, 2026-11-15 21:23) — it verified end-to-end and claimed attribution instead. The multi-agent discipline held.
   - The gate's build + negative legs were run live by that session (nix build out-path + 3/3 mutations tripping) — evidence in its closeout §c.
6. **Queue hygiene of the window's own harvests:** 11 of the 12 queue rows the window's sessions appended are present and correctly stateful at HEAD (2 pre-ticked by their own sessions, watch row carrying two dated probes). The one missing row is §d.1 below.

## b) PARTIALLY DONE

1. **Task 5's attribution is half-landed.** The gate verification + the closeout report exist, but the ticket has ZERO footer commits in history (the closeout rode footless daemon commits 37970ec2c + fe89b837b) and the two attribution surfaces it names (§d.4 annotation, follow-up queue row) never landed — details in §d.1. What exists: the gate, the CASES legs, the report file.
2. **Task 4's correction is honest about the past but unverified about the present** (its own §b.2): the corrected note still asserts the 2026-10-17→11-08 span, while samples_v4's ~30d TTL floor advances daily — the 10-17 edge may already be gone. The queued re-profile row (TODO_LIST.md:3685) owns the live floor check as its step 1. The finding is fixed as prescribed; the evidence base is LABELED, not repaired.
3. **Task 3's sweep completeness corners** (its own §b.2): `docs/planning/private-cloud-planning/` contents never read (queued, TODO_LIST.md:3684) and the 2025-era corpus (17 files) classified by filename/date without deep reads (queued, :3680).
4. **The #19482 watch** is inherently open (upstream-dependent); evidence fresh as of 11-15, landing trigger (#31886 merge or #19482 closure) unfired. Intended end-state for a `[watch]` row, not "done".
5. **Research README cosmetics:** the batch's 9 new rows are unpadded vs the legacy hand-aligned tables (batch §b.3, below the value bar; the date-backfill row I minted — see §f — folds the mechanical sort check in).
6. **Task 1's local-confirmation leg** (mmap-vs-`--no-mmap` A/B on the 23G model) remains owner-gated in the soak row — the upstream attribution is a fingerprint match, not a local proof (the tick text says so explicitly).

## c) NOT STARTED

1. **Nothing from the five tasks' own scope was skipped** — all items closed or intentionally parked as above.
2. **The ai-stack follow-up backlog the window minted but did not dispatch** sits unchecked and correctly queued: Vulkan-row cross-link (TODO_LIST.md:430), `--no-mmap` flag acceptance check (:431), ROCm 7.2.4 spin-fix presence [decision] (:432), llama.cpp issue citations in runbooks (:433). All agent-executable; none started.
3. **The pipeline-domain queue from the batch's §f** (7 rows, :3678-3684) + the b185 link-check extension (:3652) — all untouched this window (they were minted at its very end).
4. **3382 unchecked queue rows** repo-wide as of this pass — the window's own ledger, not a gap: this window dispatched 5 and minted 12.

## d) TOTALLY FUCKED UP

1. **The RestartSteps fix ticket (b18b) shipped TWO claimed-but-absent artifacts — the worst finding of this pass:**
   - Its closeout §e states the original batch closeout's §d.4 "is annotated inline with this fix". FALSE at HEAD: the 07-04 report carries no trace of fa78a834c/crash-loop-backoff-contract anywhere, and no commit touched that file after 7f48518f7 (which was the b168 ticket's §d.1 annotation). The claimed annotation never existed.
   - Its closeout §d states the fastflowlm/llama-vlm/llama-chat contract gap was "Queued as ONE new unchecked TODO_LIST row plus the matching docs/todo/ai-stack.md library row". FALSE at HEAD: neither file carries the row, and `git log -S 'crash-loop-backoff-contract'` over both files is empty — the row was never written. The coverage gap it discovered (three units carrying the same unpinned backoff settings, llama-vlm LIVE) therefore remains UNGUARDED and UNTRACKED until my re-mint tonight.
   - Both false claims now carry inline corrections in the b18b closeout file (annotated this pass, docs-health ANNOTATE doctrine), and the missing row is re-minted as a TODO_LIST row.
2. **Task 5's closeout has zero footer commits.** Its report rode footless daemon commits (37970ec2c 23:31 + fe89b837b 23:33) — so `git log --grep <TQID>` finds no attribution commit for the ticket at all. The queue marked it complete via the verdict channel, but the repo-side derivation contract ("a fire must make its own footer-bearing commit") is violated. Same class as the existing TODO_LIST.md:47 footer-gap row; now with a concrete third instance.
3. **Task 3's amend-overreach destroyed its own item-5 footer commit mid-batch** (closeout §d.1): a hook-rejected sort-fix triggered the "fix with --amend" hint, the amend ate HEAD (still item-5's commit) because HEAD's identity was never checked; repaired via reflog + two pathspec commits (3c1d5014d + edfa4aa04), never pushed, no data loss — but the repair sat unverified until closeout time instead of running the git.md history-rewrite checklist at repair time.
4. **Task 3 raced the daemon four times on one item** (§d.3): one mega-batch commit (all moves + repoints + index) against a ~5-10 min daemon cadence produced three sweeps (6fd78febc, ebc3337b7, d0a5f7465) plus a soft-reset squash and a hook rejection. All repairs verified clean (stat-verified 3×), but the cadence was self-inflicted.
5. **Task 3 repeated the source report's own documented lesson** (§d.4): the 11-05 mv left "internal relative links not re-checked" debt in writing, and item 3's mv initially shipped the identical gap (closed late in its closeout; one relative link, resolves).
6. **Task 3's policy flip left falsified queue annotations for an hour** (§d.2): it wrote "status keeps historical mentions" rationale into two queue rows, the Living-docs hook overruled the policy mid-commit, and the stale rationale sat in both surfaces until the closeout corrected them.
7. **Task 1's bulk diff rode a footless daemon commit** (54351154b, known from its own closeout §d.1): the footer commit 254246429 carries only the final tick; the queue-to-diff attribution for item 1's real work is degraded. Its §f.42 hunk-review row is still open (TODO_LIST.md:434).
8. **Task 4 shipped a present-tense range claim verified only as of 11-14** (§d.2 of its closeout) — a correction that replaces one unverified claim with another; mitigated by the re-profile row but the fix commit itself carried it.
9. **No repo-level regressions found.** Both new gates eval green (research-index re-evaled tonight; crash-loop-backoff-contract built green by its session), the sweep's moves are complete and indexed, and the tree is clean. The damage in this window is attribution-integrity damage, not functional damage.

## e) WHAT WE SHOULD IMPROVE

1. **Closeout receipt-greps (minted as a row):** any claim a closeout makes about its own writes — "queued row X", "annotated file Y", "footer commit Z" — gets a post-commit grep receipt (TODO_LIST for the row text, the annotated file for the annotation, `git log --grep <TQID>` for the footer) recorded in the closeout before the session ends. The b18b ticket's three misses were all one `grep` away. This generalizes the repo's "assert WHICH surface the fix touched" rule from corrections to claims.
2. **Fix-ticket sessions must budget for death mid-write.** The RestartSteps gate itself was authored by a session that died between edit and commit — its work survived only because the daemon swept it and a LATER session grepped recent daemon commits before re-authoring. That pre-check (git log over the last day of daemon commits for the fix's shape) saved a duplicate gate and should be the named first step of every "fix this finding" dispatch — it worked by improvisation this window; make it protocol.
3. **One logical unit = one edit→add→commit pass** under daemon fire (Task 3's §e.3, worth repeating until it sticks): mega-batches guarantee sweeps. This window's own done-prompt hit the same wall twice (skeleton + append split across two daemon commits; one amend raced a third sweep) — squashed cleanly via `reset --soft` + pathspec commit, but the two-races-in-one-commit pattern confirms ~5 min is the practical commit quantum on this tree.
4. **Verify queue-row landings in the SAME tool call as the append** (`cat >> TODO_LIST.md << 'EOF' … EOF && grep -c` on the row's key phrase): appends and their receipts should be atomic, not adjacent.
5. **The verify-and-tick loop only fires when a reviewer ticket lands.** Row 3614 (the three-unit negative test) sat UNCHECKED for ~24 h while its gate landed and was verified — discovered only because the b18b fix ticket happened to verify it. A docs-health pass (like this one) should spot-check unchecked rows against the last day's daemon commits; I ticked 3614 this pass with evidence.
6. **Corrections carry their own freshness burden** (Task 4's §e.2): a dated CORRECTION note must be true AT ITS DATE — retention-window claims need the live floor-check in the same edit. Until the re-profile row runs, the corrected demand-profile report's range is honest-but-possibly-stale.
7. **Fingerprint-match ticks must name their epistemic class** (Task 1's §e.6) — the ATTRIBUTED tick does this correctly; keep it as the template for research-derived ticks.
8. **Dead sessions' daemon commits are an unindexed work ledger.** fa78a834c (the gate) and 12f604ca7 (the research-index check) both carried real, correct, reviewer-prescribed work with zero attribution until later sessions reconstructed provenance. A one-line index (date, files, inferred intent) appended to docs/status/README.md's live-pool section when a session dies would make the next session's attribution archaeology a read instead of a rebuild.

## f) Up to 50 next things (top items → TODO_LIST; the rest report-only)

Queued this pass (6 new + 1 evidence tick, dedup-checked):

1. Extend `checks.crash-loop-backoff-contract` to fastflowlm/llama-vlm/llama-chat (the never-landed b18b row, re-minted). → TODO_LIST ✓
2. Restore b18b's two claimed-but-absent attribution surfaces (§d.4 annotation + a footer-bearing commit). → TODO_LIST ✓
3. Closeout receipt rule (post-commit greps for own-write claims). → TODO_LIST ✓
4. Research README date backfill + sort-order gate leg. → TODO_LIST ✓
5. docs/archive relative-link sweep (NIX-COLORS siblings). → TODO_LIST ✓
6. llama-chat AUTO-FOLLOW × paperless-gpt coupling design verify. → TODO_LIST ✓
7. (tick) Row 3614 — the three-unit negative test it asks for landed and was verified; ticked with evidence this pass. ✓

Report-only (not queued, with reasons):
8. Probe #31886's review activity + draft state on the next watch-row touch — already written into the watch row's trigger (:436); no new row.
9. Fold `docs/services/paperless.md`'s llmUpstream section to the full story the verify established — services.md:102's existing runbook-reconcile row covers it; glance on next dispatch.
10. After the contract gate extends (row 1): rerun the full `CASES=backoff` battery + add the three new mutation legs in one pass — fold into row 1's scope, not a separate dispatch.
11. When §f.4's sort leg lands: the batch's sort-fix (edfa4aa04) becomes the gate's first regression case — note it in that row's scope.
12. The F08 errata list's third surface (batch §f.44: whether a canonical numbered errata list exists) — fold into the next research README touch.
13. research README "AI-stack" section (cosmetic, source report §f.21) — below the value bar while the corpus is 3 AI files; revisit at 5.
14. `2025-11-15_14-10-nix-architecture-refactoring-plan.md` SUPERSEDED/OPEN annotations (batch §f.19) — subsumed by the 2025-corpus triage row (:3680).
15. Disk-layout mega-HTML disposition (batch §f.8) — already an owner question in its closeout §g.1; do not double-route.
16. D2 diagram pairs in planning (batch §f.20) — same disposition question as 15, lower stakes; ride the planning-index row when it lands.
17. `checks.research-index` count canary (batch §f.29): the gate prints the count — confirm 47 updates on the next corpus change. Free; no row.
18. The unpinned-vlm contract gap (row 1) should also be named in docs/agents/systemd.md's RestartSteps context on its next touch — one sentence, ride-along.
19. Watch-row probe-log retro-fit (queued already :3682) — the llama.cpp row is the first candidate; nothing new.
20-50. Held: the remaining batch-§f items are already queued or explicitly owner-gated (its §f.48-50 housekeeping is done/no-op); minting rows for them would re-fire paid dispatches on dedup-verified dupes — the exact loop TODO_LIST.md:47 documents.

## g) Questions only the owner can answer

1. **Do you want the unpinned backoff trio (fastflowlm/llama-vlm/llama-chat) under the crash-loop contract gate at all?** The b18b finding scoped the gate to three units; the extension row I re-minted assumes yes. If the answer is "gate only LIVE units" the row shrinks to llama-vlm; if "gate everything with the settings", it stays as minted. One word unblocks it.
2. **Ratify the closeout receipt rule (§e.1) as queue doctrine?** It is minted as a `[ready]` row; if you'd rather enforce it structurally (e.g. tq refusing a verdict whose report claims queue appends that don't grep), that's a queue-side change in another repo (repo: tq) — say which surface owns it.
3. **The demand-profile report: re-run into a bounded canonical report after the day-filter root cause, or is the honest CORRECTION note the permanent disposition?** (b168 closeout §g.1, unchanged by this pass — it gates whether TODO_LIST.md:3685 is must-do or retires.)

## h) BAND DRIFT (ADR-0015)

**None recorded — and not live-verifiable from this shell.** `tq facts` returns 0 facts and the journal is unreadable from dispatched shells (TQ_DB stripped from the environment), the design limit documented and corrected in docs/status/2026-11-15_14-21_task-queue-window-reverification.md (which downgraded the earlier "verified live" band-drift claim to design-limited). No `task.reprioritized` facts are recorded anywhere in-repo either (grep over docs/ returns none for this window's task IDs). Per ADR-0015 accountability: no priority move in this window is explainable because none is knowable from here — the queue's own journal is the only authority, and it is out of the sandbox's reach. If any task in this window was re-prioritized between dispatch and completion, that fact lives only in the TQ_DB this session cannot read.

---

## Docs-health pass notes (this pass's own ledger)

- **Annotated:** docs/status/tasks/2026-11-15_23-30_task-000001a1d902b18b2c9f049faa4900000000.md — inline CORRECTED note on the two false attribution claims (§d.1), citing this report.
- **Ticked:** TODO_LIST.md:3614 (evidence-backed, gate verified at HEAD by b18b §c + re-verified in this pass's greps).
- **CHANGELOG.md:** one consolidated entry added for the window's durable artifacts (research-index gate, 8-file sweep, backoff contract gate, both reviewer doc-fixes) — none of it was recorded before this pass.
- **FEATURES.md:** the "Eval-time guard modules" row extended with both new gates (dated, commit-cited).
- **README.md / ROADMAP.md / AGENTS.md:** verified untouched-by-this-window's-changes — no user-facing README claims, no routed long-term ideas minted, no AGENTS.md contradictions found; the process lessons route to pipeline rows (§e.1/§e.2), not AGENTS.md edits.
- **Archive moves:** none — all five closeout reports are actively referenced by TODO_LIST Source pointers and carry open inherited items (watch row, re-profile row); archiving would orphan the pointers.
- **Corpus scope:** docs/status/ holds 50+ reports for 11-14/15 alone; this pass read in full the five task closeouts + the two window-report index entries + README.md (docs/status/), and re-grepped the span's other reports for this window's task IDs (dedup check). Deeper corpus annotation was not warranted: no other 11-14/15 report references this window's artifacts with stale claims.
