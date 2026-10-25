# Status: Completed-TODO Prune, Queue + Libraries (2026-10-25 10-38 session)

**Scope:** single-task session — "Move all done TODOs from TODO_LIST.md and co to CHANGELOG.md" — plus the verification and correction tail it generated. Baseline `1a5b69b65`, bulk landed by the daemon as `a5246a013`, three corrective edits uncommitted at authoring time. **Format note:** the status-report skill's canonical output is a styled HTML dashboard; the operator's prompt explicitly demanded `.md` at this path — honored as the sanctioned override, flagged here per the skill's contract.

**One-paragraph verdict:** the core ask is fully done and mechanically verified (520 `[x]` rows moved to CHANGELOG, zero remaining, structural gate green), but the pass shipped with a wrong pre-edit safety claim ("removing rows can't affect the gate") that a post-hoc A/B dis proven — 58 WARN-class noise rows entered the gate output, were root-caused, recounted, and routed into the standing adjudication row. The pipeline that did the work needed four bug-fix cycles; nothing broken reached the repo, but the discipline gap is real and recorded below.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **520 done rows pruned**: 9 from `TODO_LIST.md`, 511 across all ten `docs/todo/*` libraries; `grep -c '^- \[x\]'` returns 0 on every touched file | git diff `a5246a013` (12 files, −555/+534 lines incl. CHANGELOG) |
| a2 | **CHANGELOG entry appended at top** per the 2026-10-24 prune precedent: contract citation, counts, the one multi-row carry (stability.md:283-293 boot-timing table), gate side-effect paragraph, then all 520 titles verbatim-truncated to 80 chars with file + pre-prune line, grouped under 11 file headers | `CHANGELOG.md:9` + 531 title lines |
| a3 | **Multi-line row integrity**: the only done row with indented continuation content (stability.md boot-phase-timing row + its 10-line table + residuals paragraph) moved atomically — no orphaned table fragments, no dangling prose (post-prune grep for the table's unique strings: 0 hits) | awk continuation-detection pass + diff inspection |
| a4 | **Pre-deletion safety checks ran**: code-fence scan (no `- [x]` inside fences across all 11 files) and continuation-line census before any scripted mutation | session tool output |
| a5 | **Structural gate green**: `scripts/check-todo-system.sh` exits 0, "TODO queue/library structure clean" — before and after the corrective edits | gate output, twice |
| a6 | **WARN delta root-caused, not guessed**: detached worktree at the TRUE baseline (`1a5b69b65`) vs post-prune tree; per-class diff: wrong-link 15→23, no-entry 60→76, unharvested 88→122; one pre-existing wrong-link WARN resolved by the prune; conclusion recorded in the CHANGELOG entry: the prune UNMASKED open-row drift that pruned `[x]` rows' Source citations had been masking | `git worktree add --detach` A/B + sorted WARN set diff |
| a7 | **Standing drift row recounted on BOTH surfaces** (no-drift rule honored): TODO_LIST.md:669 and docs/todo/pipeline.md:245 now carry 99 = 23 wrong-link + 76 no-entry, superseded-count note, and the retired completed-but-queue-open class | both files, uncommitted |
| a8 | **Daemon-commit contents verified before proceeding** (`git show --stat a5246a013`): exactly my 12 files + ONE foreign file (`tests/test-discordsync-immich-shape.nix`, parallel session's) — foreign work flagged to the user, never touched, never amended-over (the 2026-09-14 amend-absorbs-foreign-files trap avoided by NOT amending) | git show output |
| a9 | **No residue**: comparison worktree removed + pruned; scratch pipeline lives under `~/.cache/todopruned/` (sanctioned scratch space, not /tmp); nothing outside the 12 files + 2 recount rows changed that I authored | `git worktree list`, `git status` |

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| b1 | **Pairing-drift adjudication** — the 99 WARNs are now precisely counted and routed (row updated), but ZERO of the 99 are resolved; each needs per-row verification by design (the queued task forbids bulk-closing) | counted + routed, not fixed |
| b2 | **34 newly-citation-less §f reports** — identified as the unharvested WARN jump (88→122); whether each report's follow-ups are truly complete needs the per-report sweep; left WARN-class, unchanged owner-gated | identified, not swept |
| b3 | **Formatter-canonical status of the new markdown** — `nix fmt` deliberately skipped (justification: the 2026-10-24 prune entry's identical shape survives the formatter untouched, so my same-shape lines should too) — that is precedent-based reasoning, NOT a verified claim; no scoped `nix fmt --` run was made | reasoned, unverified |
| b4 | **Corrective-edit landing** — the 3 post-verification edits (CHANGELOG gate-note sentence + 2 recount rows) are uncommitted and will ride the next daemon heuristic sweep, which may batch them with the parallel session's hermes-script work (known daemon behavior; no pathspec commit made because the harness forbids commits without an explicit ask) | written, not landed |

## c) NOT STARTED

| # | Item | Why it surfaced |
|---|------|-----------------|
| c1 | AGENTS.md TODO-System note: "pruning library `[x]` rows unmasks pairing/harvest WARNs — expect, route, don't panic" | the session's one genuinely new, reusable gotcha; not yet written into AGENTS.md |
| c2 | Scriptified prune tooling (`scripts/prune-done-todos.sh` with `--dry-run` + gate-awareness) | this pass used a throwaway 4-file awk/sed pipeline in `~/.cache`; the next prune pass re-pays the full bug-fix cycle |
| c3 | Gate mechanism idea: the unharvested leg could treat a CHANGELOG mention as a valid citation (34 of the 122 unharvested WARNs are "cited only by rows now in CHANGELOG") | design only; touches gate semantics = owner decision |

## d) TOTALLY FUCKED UP

| # | What | Why it matters |
|---|------|----------------|
| d1 | **The pre-edit safety claim was wrong.** I told the user "Gate is structural-only; removing whole rows is safe" after reading the gate's header comments — but gate leg 3 (pairing) and leg 4 (harvest coverage) both key on library MENTIONS, and 511 of my deletions were library mentions. The repo's own rule ("spot-verify claims before acting"; "a 'verified' label must cover every fact asserted") was violated by exactly the class it names. Caught only because I ran a post-hoc A/B — right instrument, wrong time; it should have gated the edit, not audited it. | 58 WARN-noise rows shipped into the gate output and forced a recount pass + 3 corrective edits; the CHANGELOG entry's first draft even asserted "no queue↔library drift was introduced" before the analysis existed (self-corrected in the same entry, but the overconfident sentence got written at all) |
| d2 | **Four bug-fix cycles for a 30-line extraction pipeline**: (1) awk `NR` cumulative across files instead of `FNR` → phantom line numbers; (2) render.awk missing `FS="\t"` → every title collapsed to its first word; (3) sed truncation pattern keyed on the wrong column order → truncation silently never fired; (4) grouped headers rendered AFTER their titles instead of before. All four were caught in scratch-space verification — zero repo damage — but the annotate.go `--dry-run`-first discipline this repo already prescribes would have collapsed all four into one iteration | wasted ~4 tool cycles; a repeat-prone pattern if the pipeline is ever re-rolled by hand |
| d3 | **First WARN comparison ran against the wrong baseline.** I pinned `1a5b69b65` at session start but built the comparison worktree with `HEAD` — and the daemon had already moved HEAD to `b8be51f5e` mid-session, so the first 163→221 delta was computed against a tree that wasn't my baseline. Caught by reading the worktree output line ("HEAD is now at b8be51f5e"), re-run correctly at the pinned rev. In a daemon-active tree, `HEAD` is never a baseline | one invalid measurement briefly treated as a finding |
| d4 | **One aborted placeholder command** shipped as a real tool call (an over-clever one-line pipeline abandoned mid-thought that did nothing). Sloppy; the honest version is "switched to script files immediately" | pure waste, no damage |

Not fucked up, for the record: no data loss (prune is git-recoverable line-deletion), no secret touched, no foreign work reverted or amended, no `/tmp` usage, no unverified count left in a queue row (all three counts in the recount are live-derived this session).

## e) WHAT WE SHOULD IMPROVE

1. **Verify-then-claim ordering for edit safety**: before any bulk edit, run the gate/lint A/B (or read the full leg implementations, not headers). The A/B worktree pattern worked; it just ran one step late.
2. **Pin baselines by rev, never `HEAD`**, for any comparison in a tree with a live auto-commit daemon — the daemon moved HEAD twice during this one session.
3. **Dry-run-first as a reflex** for anything generated: the repo's annotate.go already models `--dry-run` + atomic write + verify; ad-hoc pipelines should inherit that shape (and ideally BE the script, see c2).
4. **Write the verified sentence only**: the CHANGELOG entry carried a correctness claim ("no drift introduced") one sentence ahead of the evidence, then needed an in-entry correction. Claims should wait for their verification pass or be visibly marked as preliminary.
5. **Prune-entry format is getting heavy**: +533 CHANGELOG lines per pass (249-title list last pass, 520 this pass). The verbatim list is maximally auditable but the cost scales with every future prune — a count + git-range + sample-titles format is the candidate evolution (owner decision, §g).
6. **Flag the format divergence proactively**: done here (header note) per the status-report skill's override contract — small thing, but the skill asked for it in the closing message and it belongs wherever the override happens.

## f) NEXT — up to 50, brainstorm-weighted (most are already-queued references, ROADMAP fuel, or explicitly not harvested)

Items 1-4 are this session's direct follow-ups; 1-2 already have (updated) queue rows, 3-4 were **newly queued during this report's authoring** (self-harvest rule). Items 5+ are session observations routed to existing rows or marked deliberately-not-harvested.

1. **Adjudicate the 99 queue↔library pairing WARNs** (23 wrong-link + 76 no-entry; per-row verify, then pair or close) — already queued, counts refreshed this session: TODO_LIST.md:669 + docs/todo/pipeline.md:245.
2. **Per-report sweep/marker decision for the 34 §f reports that lost their only citation** — feeds the standing unharvested-backlog row (TODO_LIST.md:668 / pipeline.md:246, which mandates live count re-derivation, never hardcoding); the +34 is a delta, not a new list to maintain.
3. **NEW [ready] row: AGENTS.md TODO-System gotcha note** (library `[x]` prunes unmask pairing/harvest WARNs) — queued this session into TODO_LIST.md + docs/todo/pipeline.md.
4. **NEW [ready] row: scriptify the prune pipeline** (`scripts/prune-done-todos.sh`, dry-run-first, gate-aware: run the WARN A/B before AND after) — queued this session, same two surfaces.
5. Gate-mechanism owner decision: should the unharvested leg accept CHANGELOG citations (would de-noise pruned-citation WARNs permanently)? — deliberately not harvested as a row: it is a gate-semantics change with no code probe behind it yet; belongs with the gate-hardness decision (05-41 §g2 precedent) and is referenced from item 3's row context instead.
6. After the daemon's next sweep: verify the 3 corrective edits landed un-mangled (`git show --stat`, then content-check the CHANGELOG gate-note sentence) — no row: next-session hygiene, listed here so it isn't lost.
7. Scoped `nix fmt -- CHANGELOG.md TODO_LIST.md docs/todo/*.md` at a PSI-calm window to close b3 (formatter-canonical or not, verified) — deliberately not harvested: single command, zero new information until run, foldable into any next docs pass.
8. Re-derive the unharvested count after any sweep (the row forbids hardcoding; this report's 122 is already stale the moment a report lands) — covered by existing row.
9. 2026-0\*→2026-10 wave corpus sweep (442+57 reports) — existing owner-gated `[decision]` row in docs/todo/pipeline.md; untouched this session by design.
10. `check-todo-system.sh` v2 legs (DONE-state pairing, stale-tag WARNs) — existing row (TODO_LIST.md:938 area); this session's recount strengthens the case for the `[x]`-pairing leg.
11. CHANGELOG prune-entry format evolution (count + git-range + sample titles vs full verbatim lists) — deliberately not harvested: pure owner tradeoff decision, no code work until decided (§g question 2).
12. Attribution/verification of the two foreign change-sets observed riding this session's commits (`tests/test-discordsync-immich-shape.nix` inside daemon commit a5246a013; uncommitted `scripts/test-hermes-{db-health,migrate-state}.sh` edits) — deliberately not harvested here: owned by the parallel session; verified-by-stranger work would violate the shared-tree attribution rule (flagged to operator, §g question 3).
13. The `-1` wrong-link WARN the prune incidentally resolved: nothing to do — recorded so the next A/B doesn't misread it as noise.
14. When the 99 WARNs hit zero: flip `CHECK_TODO_PAIRING` / `CHECK_TODO_HARVEST` to strict (owner gate-hardness decision, existing 05-41 §g2 lineage).
15. Consider a `features-drift`-style standing eval gate for the TODO system (e.g. fail on `[x]` rows surviving a pass boundary) — ROADMAP fuel: mechanism unclear (the queue is markdown, not eval), deliberately not harvested as a row.
16. If prune passes recur: prune BOTH surfaces in the same change (this pass did) and keep the recount-in-both-surfaces habit — doctrine note, candidate to fold into c1's AGENTS.md row.
17. Recount check: the "63 drifts" figure appeared in prose elsewhere? (this session grepped TODO_LIST + pipeline.md only; other docs may cite the stale 63) — deliberately not harvested: one `rg '63 queue'` away during any next docs touch; queueing a row for a grep is noise.

(17 real items; the remaining headroom to 50 is deliberately unused — the honest backlog here is 17, and padding to 50 would mint rows the queue contract explicitly bans: vague, unowned, or duplicates of existing ones.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Gate semantics (owner owns gate config):** should `check-todo-system.sh`'s unharvested leg treat a CHANGELOG mention as a valid citation — killing the 34 false "unharvested" WARNs this prune created and preventing the same noise after every future library prune — and once the 99 pairing WARNs are adjudicated to zero, do you want `CHECK_TODO_PAIRING=strict` / `CHECK_TODO_HARVEST=strict` flipped on as the default gate posture?
2. **Prune-entry format for future passes:** keep the full verbatim title list in CHANGELOG (+533 lines this pass, +249 last pass — maximally auditable, ever-growing) or switch future passes to count + git-range + sample titles with the full list living only in git history of the pruned files?
3. **Foreign work attribution:** the daemon swept a parallel session's `tests/test-discordsync-immich-shape.nix` change into my prune commit (a5246a013), and that session's `scripts/test-hermes-{db-health,migrate-state}.sh` edits sit uncommitted in the tree — should THIS session attribute/verify those changes, or do you want them left entirely to the owning session?

---

*Report authored 2026-10-25 10:38 CET; counts (520 rows, 99/122 WARNs) are live-derived this session against `a5246a013` + uncommitted tail. Waiting for instructions.*
