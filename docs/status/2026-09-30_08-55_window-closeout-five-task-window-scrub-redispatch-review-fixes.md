# Window Closeout — five-task window: scrub-stop re-dispatch verification + scrub exit-1 close-out + three review-fix dispatches

**Date:** 2026-09-30 08:55 CEST (`date` measured at session start)
**Window tasks:**

| Task ID | What it was | Landing commit | Close-out report |
| --- | --- | --- | --- |
| `000001a0eaf255cff90e3b85a22accf257e2` | Scrub-stop-phantom re-dispatch (verification-only; fix pre-landed by daemon batches) | `7e203ff9` | `docs/status/2026-09-29_23-20_task-000001a0eaf255cff90e3b85a22accf257e2.md` |
| `000001a0ef17061c3d535dd0d65b00000000` | `btrfs-scrub@-`/`@data` exit-1 FAILED state close-out (re-verification only; fix landed `c7d4795b` earlier) | `2e6f579a` | `docs/status/2026-09-30_00-42_task-000001a0ef17061c3d535dd0d65b00000000.md` |
| `000001a0ef696dedbc174971daa200000000` | Review fix: 00-42 report's §f.7 contradicted its own §a.4 (+ stale line cite) | `d0fe7a01` | `docs/status/2026-09-30_01-15_task-000001a0ef696dedbc174971daa200000000.md` |
| `000001a0ef4039417bc0974a175500000000` | Review fix (2nd dispatch): re-land the 23-20 pipeline library pair deleted by daemon batch `d22ccd48` | `e0cb141a` | `docs/status/2026-09-30_08-05_task-000001a0ef4039417bc0974a175500000000.md` |
| `000001a0ef4039f5828be9fccc8600000000` | Review fix: 23-20 report lacked the re-dispatch protocol's sweep-scope statement | `027d2947` (fix `382ab696`) | `docs/status/2026-09-30_08-32_task-000001a0ef4039f5828be9fccc8600000000.md` |

**Window character:** ALL five landings are documentation-only (verified per-commit: `git show --stat` on every window commit touches only `docs/status/*`, `TODO_LIST.md`, `docs/todo/pipeline.md`). No code, config, or test change belongs to this window. The engineering underneath (scrub-stop churn-name fix, `SuccessExitStatus = [ 1 ]`) landed in the PRIOR window and was only verified here.

---

## a) FULLY DONE (verified this session)

1. **Scrub-stop-phantom re-dispatch closed with the missing queue cross-reference.** The underlying fix (guard churn list naming template instances `btrfs-scrub@-`/`@data`/`@mnt-pool` instead of the stray `btrfs-scrub--`-class unit files; re-arm excluding `btrfs-scrub@*`; dead scrubGuard deferral override moved onto the template) was confirmed in-tree at `modules/nixos/services/memory-emergency-guard.nix` and `platforms/nixos/system/snapshots.nix`; `nix flake check --no-build` green; commit `e8b2f3af` supplied the footer the queue's commit-based completion derivation was missing (`git log --grep=000001a0eaf255cff90e3b85a22accf257e2` now hits).
2. **Scrub exit-1 FAILED state closed with a corrected root cause.** The exit-1-after-"no errors found" at 2026-09-28 02:27 was MANUAL `sudo btrfs scrub cancel` from lars TTYs (pts/22+pts/20), not a guard malfunction; canceled scrub → CLI exit 1 (real errors exit 3). Fix `SuccessExitStatus = [ 1 ]` confirmed live at `platforms/nixos/system/snapshots.nix:522`; standing FAILED state cleared by the storm-closeout `reset-failed`; service-health no longer lists the units (live-probed by the 00-31 session, evidence carried in the 00-42 report §a.4). TODO_LIST row `[x]`-closed under the task ID.
3. **Review finding #1 fixed (self-contradicting report).** 00-42 report §f.7 relabeled RESOLVED ALREADY with its own §a.4 evidence; the stale `TODO_LIST:152` line cite replaced with a title + Source-anchor cite (commit `b344987b`). En route, the same rot class was found and fixed at 13 MORE sites in the sibling 00-31 report (all `TODO_LIST:<line>` cites → title-based).
4. **Review finding #2 fixed (silently reverted library pair).** The 23-20 harvest's two `docs/todo/pipeline.md` entries, deleted ~90 min after landing by daemon batch `d22ccd48` (which removed 21 open `[ ]` rows), were re-landed byte-identical (commit `0be59b83`); the other 19 victims were discovered and their restoration queued as a properly-paired row (`TODO_LIST.md:416` + `docs/todo/pipeline.md:191`). Recurrence root-caused via `git log -S` archaeology.
5. **Review finding #3 fixed (missing sweep-scope disclosure).** The 23-20 report's §b protocol row now STATES the sweep scope (item-derived, boundary named, un-swept Source-report §f items 1–10/13–15/17–20 enumerated) per the CONTRIBUTING re-dispatch protocol's 2026-09-27 clause (commit `382ab696`, +1/−1).
6. **Self-harvests landed.** The window's reports queued their own follow-ups: pipeline rows for the re-landed pair + d22ccd48 restore + daemon-race heal commands + task-ID dedup gate + report consolidation + sandbox systemctl allowlist (TODO_LIST.md:414-424, `docs/todo/pipeline.md:189-191` + tail); stability rows for the SuccessExitStatus sweep, btrfs-scrub exit contract docs, and deploy.sh reset-failed coverage.

## b) PARTIALLY DONE

1. **The d22ccd48 loss is closed only for the two re-landed entries** — the other ~19 deleted open rows remain missing from `docs/todo/pipeline.md` (restoration queued, TODO_LIST.md:416).
2. **The 23-20 report's honest "not dispositioned" §f scope is landed as a disclosure, not a disposition** — the full-table sweep of Source-report items 1–10/13–15/17–20 is queued (TODO_LIST pipeline, Source 08-32 §f1), not executed.
3. **The 23-20 report still describes pre-correction state** (its §c2/§f1 predate the RE-FIRE-3 manual-cancel root cause and the executed-green VM test) — the ANNOTATE pass is queued (Source 08-32 §f2), not run.
4. **Queue-idempotency discipline** — the re-dispatch protocol exists in CONTRIBUTING and was executed correctly by the 23-20 session, but its discoverability still depends on workers reading archived reports; the worker-facing contract pointer is queued, not landed.

## c) NOT STARTED (observed open; all already queued with live rows — listed for window completeness, not re-harvested)

- `btrfs-scrub@data` exit-3 policy decision (weekly re-FAIL while the 129,533 csum errors persist — next weekly window Oct 5 re-FAILs; every snapshots.nix churn before the /data repair exit-4s a deploy).
- Scrub timers `Persistent = false` + `After=` serialization (freeze-#7 remaining half).
- Stray-unit eval-time lint (the `btrfs-scrub--` class guard).
- `btrfs_scrub_last_completed` per-fs metric + Gatus staleness.
- /data corruption repair (T04–T08) — root cause of the persistent csum errors.
- The d22ccd48 detector rows (entry-pairing check, drift sweep — queued from the 05-41 session).

## d) TOTALLY FUCKED UP (window-attributable; blunt)

1. **The task queue re-dispatched completed work 3× in this window's lineage.** The 23-20 session was a full re-verification of an already-landed fix; the 00-42 session was a re-verification of a fix that had ALREADY been closed under the same task ID 11 minutes earlier (a third report under the ID family exists). Every occurrence cost a full worker dispatch. The dedup gate is queued but unlanded; today the only guard is a 10-second `git log --grep <task-id>` reflex that the 00-42 session itself did not perform.
2. **A landed review fix has no protection against silent later reversion.** Fix `3ee63f6d` (the library pair) was deleted by daemon batch `d22ccd48` ~90 minutes after the queue closed the task; every gate stayed green because all gates judge the diff at landing time. The reversion had NO owner until a human re-fired the finding. Second occurrence of the class in the family.
3. **The 00-42 report failed its own verification hygiene** (§f pending-work contradicting §a verified-done in the same file) — caught by the reviewer, not by the report's own brutal-self-critique pass. The §a-vs-§f consistency check is now a queued convention item.
4. **The line-number-cite habit was born, rotted twice, and propagated within one day** (152→154→107 across one finding's lifecycle; the sibling 00-31 report shipped with 13 such cites). Title-based cites are the proven fix (14 sites converted); the convention ban is queued.
5. **The auto-commit daemon raced TWO of the window's fix commits into footer-less heuristic commits** (`e35e635f`, `abba86d9` — the 4th+ documented instance), and **the pre-commit hook reported green success twice while validating an EMPTY staged set** (gitleaks passed vacuously, flake-check leg skipped). Both recoveries were manual (amend-forward + standalone gate re-runs); the hook's green-on-empty output is queued for hardening.
6. **Carried (not this window's doing, but visible throughout):** the same daemon batch `d22ccd48` that deleted the library pair deleted ~19 OTHER open backlog rows — the repo's todo library has zero deletion protection.

## e) WHAT WE SHOULD IMPROVE

1. **Report self-consistency gate:** before finishing ANY §a–§g report, cross-check every §f "next" item against the §a done-rows — mechanical, cheap, would have prevented the one rejected report outright (queued).
2. **Cite by title + Source anchor, never bare line number, into any actively-restructured file** — proven at 14 sites in this window (queued as a convention ban).
3. **Pair-discipline must extend to RE-LANDINGS:** a fix restoring drifted queue↔library pairs should sweep the sibling file for OTHER victims of the same deletion commit in the same change (the 05-41 fix re-added into a file that had lost 21 without noticing).
4. **"Landed" is not "still landed"** in a repo with an auto-commit daemon and parallel sessions — post-landing verification needs the queued entry-pairing detector, or every reversion costs a review round-trip + a re-dispatch.
5. **Minimize edit→commit latency for queue work:** the daemon race is deterministic given enough latency; `git add` + commit immediately after the edit, gates after (amend if a gate fails) — and check `git log -1 --stat` the moment "nothing to commit" appears.
6. **Make the hook honest about empty staged sets** — a green "All validation checks passed!" on zero staged files reads as a passed gate precisely in the daemon-race case where it matters most (queued, owner-gated design).
7. **Positive findings worth keeping:** the docs-only pre-commit fast path was sub-second and correct all window; the formatter memo (fmt-cached) worked as designed; PATHSPEC + `git show --stat` commit discipline kept every foreign hunk out of the footer-bearing commits; amend-forward recovered both daemon races cleanly.

## f) NEXT THINGS (window-derived; non-duplicates queued this session — see TODO_LIST for the live rows)

1. Land the §a-vs-§f report self-consistency check as a one-line CONTRIBUTING report convention (Source: 01-15 §e1).
2. Ban bare `TODO_LIST:<line>` cites from status reports; cite row title + Source anchor (Source: 01-15 §d2/§e2, proven at 14 sites).
3. Make the pre-commit hook honest on an EMPTY staged set (print "nothing staged — no legs ran") — design owner-gated (Source: 08-32 §e2/§d2 + §g2).
4. Add the 60-second same-class sibling sweep to the review-fix habit (grep the touched report family; fix on sight when trivial) (Source: 01-15 §e3).
5. Journal a guard cooldown-disclosure line when a churn-stop is skipped by action-cooldown — the 02:27 attribution ambiguity cost a corrected narrative (Source: 00-42 §f11).
6. Audit-label `btrfs scrub cancel` invocations (agent- vs operator-initiated breadcrumb) so forensics don't need pts archaeology next time (Source: 00-42 §f10).
7. Split the bundled stability.md "Guard/crash-forensics follow-ups" row into atomic rows (PSI-gate nix-gc, smartd liveness, is-active lint, crash2 cascade triage — violates one-ask-per-row) (Source: 23-20 §f15).
8. Restore the ~19 d22ccd48-deleted pipeline backlog rows (already queued this window — listed here as the highest-value open item the window surfaced).
9. Execute the queued disposition sweep of the 01-45 Source report's unswept §f items (most of it is bookkeeping; several items appear already landed).
10. Execute the queued ANNOTATE pass on the 23-20 report (superseded root cause, executed-green VM test, §f18 live-proof status).

(Beyond these, the standing stability/pipeline rows are the authoritative remainder — not duplicated here per the no-drift rule.)

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Daemon stale-tree guard:** should the auto-commit daemon refuse or flag batches where a tracked file LOSES open `[ ]`/library rows vs HEAD (the `d22ccd48` signature — a stale sibling tree swept in), or is review-time catching + the queued entry-pairing detector the accepted long-term design? Sub-question: should `docs/status/*` + TODO_LIST be excluded from the heuristic sweep unconditionally, or only while a Task-Queue-ID session is live (and how would the daemon know, cheaply)?
2. **Hook-on-empty semantics:** is the pre-commit hook's green "All validation checks passed!" on an EMPTY staged set an intended fast path or an oversight? Decides whether the fix is a warn-line or a distinct exit path.
3. **Review-fix re-verification:** should review-fix dispatches carry a standing commit-time re-grep of the finding's original premises (so a silent recurrence like `d22ccd48` is caught by the fixer), or is re-fire-on-finding the accepted loop despite costing one dispatch per occurrence?

## h) BAND DRIFT

**None recorded.** Queried the tq facts table for the window (2026-09-29 20:00 → 2026-09-30 08:55 local): fact types present were `task.claimed` (113), `task.requeued` (87), `task.enqueued` (22), `task.failed` (14), `task.completed` (11), `task.dead-lettered` (9) — **zero `task.reprioritized` facts** in the window. No priority moved, so nothing to account for under ADR-0015. (Side observation in passing: 9 dead-lettered tasks in ~13h is a high failure rate worth a look by whoever owns queue hygiene — out of scope here.)

---

## Docs-health pass notes (this session)

- All five window reports read; their §f follow-ups were self-harvested at authoring time (verified present in TODO_LIST + libraries). The 00-42 report's harvest log records its own deliberate-not-harvested reasons.
- **No archives this pass:** the window's reports all still carry open work referenced from TODO_LIST/library rows (Sources point at them); archiving would dangle pointers, violating the archived/README convention ("open work never lives here"). The 00-42 report itself queues consolidating the three same-ID-family reports — that is the right future archive vehicle.
- CHANGELOG: no entry added — the window shipped zero user-visible changes (docs-only; verified per-commit). The neighboring 2026-09-30 entries already cover the underlying engineering.
- AGENTS.md/README/FEATURES/ROADMAP: no stale claims introduced by this window (it changed no code/config); no reconciliation needed.
- 9 new items appended to TODO_LIST (6 pipeline incl. 3 owner-blocked, 3 stability); zero existing items edited (dedup check run first; no ticks — none of the window's work closed an existing open queue row that wasn't already `[x]`-closed by its own session).
