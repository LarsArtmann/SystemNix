# Status Report — Review-Fix: TODO Harvest Library Pairing (self-review)

Task-Queue-ID (fix dispatch): `000001a0ef4039417bc0974a175500000000` — review finding against the 2026-09-29 23-20 re-dispatch session's harvest (commit `7e203ff9`).
Session window: 2026-09-30 ~04:30–05:45. Scope: EXACTLY the reviewer finding; this report is the post-fix self-review the owner requested.

## Executive Summary

The reviewer found that the 2026-09-29 self-harvest landed two TODO_LIST queue one-liners pointing at `docs/todo/pipeline.md` without the matching library entries — a direct violation of the AGENTS.md no-drift rule, committed by a session whose own commit message cited "library/queue parity per the no-drift rule" for the stability.md half. This session verified every premise of the finding before acting, appended the two missing `[ready]` entries to the pipeline library, passed the repo's TODO-structure gate, and landed a clean pathspec commit (`3ee63f6d`) carrying exactly one Task-Queue-ID footer (the fix ticket's). The fix is DONE and verified. The deeper finding of this run: the drift class is invisible to every automated gate — `check-todo-system.sh` validates structure (titles, dead library FILE links), not entry pairing; only human review caught it. Two follow-ups harvested at authoring (f1/f2).

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| 1 | **Finding premises verified before acting** — commit `7e203ff9` exists (`git cat-file -e` → EXISTS, no re-anchor needed); both queue rows present (TODO_LIST.md:384-385, worker-facing dispatch-contract row §e1 + footer-less-daemon `[x]`-row sweep row §e2); all three finding greps (`23-20_task`, `worker-facing`, `Sweep TODO_LIST`) returned ZERO hits in pipeline.md | pre-edit greps in session log |
| 2 | **Both matching `[ready]` entries appended to `docs/todo/pipeline.md`** (now lines 200-201, end-of-file Backlog-harvest convention matching the same-night 23-13 precedent) — house format (bold ask + em-dash detail + `**Source:**` pointer), same asks as the queue rows, supplementary section pointers verified against the report (§e1/§b1 and §e2/§d2) | `docs/todo/pipeline.md:200-201` |
| 3 | **Repo TODO gate green** — `bash scripts/check-todo-system.sh` → "OK: TODO queue/library structure clean" | session log |
| 4 | **Parallel-session discipline held** — TODO_LIST.md carried a foreign uncommitted row (papdashboard post-push chain, upstream section); inspected (`git diff`), confirmed not mine, EXCLUDED via PATHSPEC commit per the multi-agent rule | `git diff TODO_LIST.md` pre-commit |
| 5 | **Clean landing** — commit `3ee63f6d`: exactly 1 file (`docs/todo/pipeline.md`, +2), subject 65 chars (≤72 hook cap), pre-commit gates green (gitleaks, trailing whitespace, docs-only fast path skips the nix eval), exactly ONE Task-Queue-ID footer (the fix ticket's — no duplicate lineage footer) | `git show --stat 3ee63f6d` |
| 6 | **Post-commit verification** — show-stat exclusivity (nothing foreign swept in), footer grep count = 1 | session log |
| 7 | **No scope creep** — the original task's queue rows (TODO_LIST.md:384-385) left open (they ARE the future work); TODO_LIST.md not touched by this fix (the rows were already correct — only the library half was missing) | `git show 3ee63f6d --stat` |

## b) PARTIALLY DONE

| # | Item | Gap |
| - | ---- | --- |
| 1 | **Drift-class sweep** — the reviewer caught ONE instance (the 23-20 harvest). I did NOT sweep TODO_LIST's other sections for additional queue rows lacking library entries — outside the finding's "EXACTLY this finding" contract, but the class may have more instances and nothing but review catches them | harvested as f1 (landed) |
| 2 | **Gate gap identified, not closed** — `check-todo-system.sh` passed both before the fix would have been needed and after; it checks title-less rows and dead library FILE links, never entry-level pairing. I identified the gap and did not extend the script (out of fix scope) | harvested as f2 (landed) |

## c) NOT STARTED (all deliberate)

| # | Item | Why |
| - | ---- | --- |
| 1 | Annotation of the original 23-20 report (`docs/status/2026-09-29_23-20_task-000001a0eaf255cff90e3b85a22accf257e2.md`) noting the library half landed later in `3ee63f6d` | DELIBERATE SKIP: the report never CLAIMED library entries landed (its commit message lists only "TODO_LIST: 2 new pipeline rows" + stability.md edits), so there is no false claim to correct; correct-in-place-vs-append-only for published reports is an OPEN owner decision row in pipeline.md. Reopened as owner question g1 |
| 2 | Anything beyond the finding | Contract: "Fix EXACTLY this finding — no unrelated changes, no drive-by refactors" |

## d) TOTALLY FUCKED UP

1. **The original harvest miss was MY earlier work, and it knew better.** Commit `7e203ff9`'s own message cites "library/queue parity per the no-drift rule" for the stability.md half — the session applied the rule one bullet later and omitted the pipeline.md half in the SAME change. The session's own report §e3 even names pair-discipline as the lesson: written, not applied. Root cause: the self-harvest checklist treated each row's TODO_LIST landing as completion, never cross-checking the library file the row points at. Cost: one review round-trip + one fix dispatch.
2. **This session: one wasted probe** — `xxd` is not on this box's PATH (od -c fallback). Cosmetic, caught immediately.
3. No repo damage this session: no reverts, no foreign-file sweeps, no daemon race (foreground pathspec commit immediately after staging).

## e) WHAT WE SHOULD IMPROVE

1. **A mechanical last step for every self-harvest:** after landing queue rows, `grep -c "<Source-report-filename>" <linked-library-file>` — zero hits means the library half is missing. Ten seconds, would have caught this pre-review. This is the micro-fix; f2 makes it a gate.
2. **The drift class is gate-invisible today.** `check-todo-system.sh` validates link/file liveness and row titles; entry pairing between queue and library is enforced only by review. The same class of finding can recur for any harvest that lands rows in a hurry (and the daemon cannot fix what it never checks).
3. **Review-fix runs inherit the original task's harvest obligations implicitly.** The AGENTS.md authoring-time self-harvest rule applies to the ORIGINAL landing; nothing in the fix-run contract names it, so the fix depended on the reviewer reciting the rule back. Fine as process — but the f2 gate would make it structural.

## f) Up to 50 things we should get done next

From THIS run's scope only (no unrelated research). Direct follow-ups f1/f2 landed at authoring per the AGENTS.md rule (queue row + matching pipeline.md library entry, both in one change — the discipline this whole finding was about).

1. **[ready] Queue↔library ENTRY drift sweep** — for every TODO_LIST queue row, grep its linked library file for the row's Source report filename; zero hits = the same drift class the reviewer caught (check-todo-system.sh only validates file-level link liveness). File or fix every mismatch found. **LANDED: TODO_LIST pipeline section + docs/todo/pipeline.md (HARVESTED at authoring).**
2. **[ready] Extend `scripts/check-todo-system.sh` with entry-pairing check** — a queue row's `(Source: <report> §x)` must correspond to ≥1 entry in the linked library citing the same Source report; warn/fail on misses (allowlist for legitimate queue-only rows if any exist). Makes the no-drift rule mechanical instead of review-dependent. **LANDED: TODO_LIST pipeline section + docs/todo/pipeline.md (HARVESTED at authoring).**
3. **[deliberate skip, recorded]** Annotate the 23-20 report with the later-landed library half — owner decision (g1), pending the open correct-in-place-vs-append-only row; not agent-actionable until decided.

## g) Questions for the owner (cannot be resolved from the repo)

1. **Annotate or leave?** The 23-20 report made no false claim (it never said library entries landed), but a reader following its harvest today finds only the queue half until they hit `3ee63f6d`. Annotate correct-in-place with a one-line "library half landed in `3ee63f6d` (review finding)", or leave published reports untouched? This is the same call as the OPEN decision row "correct-in-place vs append-only for published status reports" (pipeline.md, from the 2026-09-13 02-29 report §g.2).
2. **Gate hardness for the entry-pairing check (f2):** hard pre-commit failure (blocks commits, like gitleaks) or warning-grade/review-time (like the stray-unit lint proposal)? Same tradeoff class as the open "Enforcement vs norm for self-harvest markers" decision row (pipeline.md, from the 2026-09-29 01-10 report §f2/§g1) — your verdict there can fold this one in.
