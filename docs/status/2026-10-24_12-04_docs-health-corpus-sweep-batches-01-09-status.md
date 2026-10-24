# Status: Docs-Health 2026-0* Corpus Sweep — Batches 01–09 Applied, Archive Wave Started

**Session date:** 2026-10-24, started ~07:25, report written 12:04
**Task:** user dispatch — "View ALL `**/2026-0*` files! Execute the docs-health SKILL! PROPERLY! SUPERBLY" (re-fire of the 2026-10-19 dispatch; owning row TODO_LIST:783 → docs/todo/pipeline.md:582; owning plan `docs/planning/2026-10-19_05-06_SUPERB-docs-health-corpus-completion.md`, tombstone EXECUTING `e37dde0c2`)
**State in one line:** the tracked Sept corpus (batches 6–20 = 294 reports) is FULLY annotated — 1,918 per-item verdicts applied across 9 classifier batches with a validated pipeline; the TODO queue was pruned of all 249 `[x]` rows; the archive wave moved its first 2 fully-resolved files through every gate; living-docs verify + non-status triage application + final gates remain.

## a) FULLY DONE

1. **Skill + references loaded in full** (SKILL.md body, doc-ownership, harvest-guide, verify-checklist, health-report-format, resolving-items) before any mutation.
2. **Tombstone written FIRST** (`e37dde0c2`, committed immediately) — the twin-executor guard; also normalized the plan header to `**Created:**` so `scripts/plan-marker.sh` accepts it.
3. **Toolchain verified**: `annotate.go self-test` green (markers + rows guards + prose strikes + atomic dry-run + repair/mangle/normalize legs).
4. **TODO_LIST `[x]` prune (249 rows)** — count-before-claim (208 claimed by the plan, 249 live), titles + pre-prune line numbers preserved verbatim in the consolidated CHANGELOG bullet (2026-10-06 precedent, 90-row form); `check-todo-system.sh` structure-clean after ~~(the 82 unharvested-§f WARNs are all 2026-10 wave — out of scope, stays queued)~~ **corrected 2026-10-24 (16-43 plan T1 census): the 82 measured at the prune was transient — daemon `f12302830` archived `2026-09-30_07-42_architecture-catalog-golive-prep-continuation.md` at 11:49, before this report committed; the stable composition is 81 = 22 Sept stragglers + 59 Oct (NOT all-October) — routed into the wave seed, stays queued**. Daemon-swept commit amended into `36057309a` after verifying it contained exactly my two files.
5. **Pipeline built and proven** (the session's reusable product): classifier-agent prompt (read-only evidence rules, wrong-done warning, verbatim-snippet contract) → transcription to `~/.cache/docshealth/` → `validate-verdicts.sh` (my new validator: path check, snippet relocation ±6 lines, item-shape check, already-struck skip, kind legality, v-verdict evidence/noun-overlap check) → evidence-prefix retag (v→w for moot/decided-against/superseded) → `annotate.go repair` (dry-run first) → `check-rows` per batch → pathspec commit. 9 batches end-to-end.
6. **Batches 01–09 annotated**: b01 250 · b02 246 · b03 227 · b04 219 · b05 234 · b06 250 · b07 161 · b08 176 · b09 150 (+5 for the 07-42 owner-sequence) = **1,918 verdicts applied**; 38 agent rows dropped by the validator (SNIPNOMATCH/BADPATH/NOOVERLAP — fabricated-or-drifted verdicts fell out conservatively), 2 hand-adjudicated drops ~~(contradictory `w`-with-"still open"-evidence rows in b03/b09 left bare)~~ **(re-adjudicated 2026-10-24 T2: the bare residue was NOT contradictory-w rows — it was (a) 01-14:93, a `v` NOOVERLAP line-targeting error (evidence answered row 38, not row 37 — row 37 now struck v on owners-frontmatter evidence), and (b) 13-34:143, a `v` BADPATH filename-typo drop (now struck v — runbook carries options/probes/memo); plus a THIRD defect found: 05-55:23 carried an evidence-free `w` strike with an embedded 0x02 byte — evidence restored from b03-raw (system-796)**. September corpus: **292 of 327 files now carry inline resolutions** (was 48 at session start).
7. **Adjudication sampling held**: 4 evidence citations spot-checked live in b01 (upstream.md:89, backup-coordination.nix:77, configuration.nix:471, storage.md:42 — all confirmed); partial-table check-rows states sampled as genuine opens (16-45 rows 3–8, 17-28 rows 33/36).
8. **Archive wave, first slice**: 14 candidates → citation sweep (10 stay: cited by live `**Source:**` surfaces; path-stable rule) → 07-42's owner-sequence items verdicted (go-live proven) → `check-rows` COMPLETE gate BEFORE `git mv` (the 2026-10-15 21:00 lesson) → completeness grep (both carry `~~`) → **2 archived** (`2026-09-19_16-16`, `2026-09-30_07-42`) → `check-doc-links.sh` OK (1457 files in archived/).
9. **Non-status 2026-0\* classified** (52 files, one agent pass): 17 EXECUTED plans, 8 SUPERSEDED (incl. the 07-09 pareto trio and three self-bannered disk snapshots), 24 REFERENCE-KEEP, 4 ACTIVE (less-code-more-system, dynamic-service-mesh, netbird rollout + brainstorm, immich PR pending) — application of stamps/moves is the remaining leg.
10. **Session gates**: `check-todo-system.sh` OK, `check-doc-links.sh` OK, annotate self-test green, all 9 batch commits pathspec-clean.

## b) PARTIALLY DONE

| # | Item | Works | Missing | Blocker |
| --- | --- | --- | --- | --- |
| b1 | **Living docs verify (plan T9)** | TODO_LIST pruned; CHANGELOG prune bullet landed | README/FEATURES computed counts, ROADMAP Theme-1 staleness, AGENTS endurance pass — none run | session length; queued (f.9) |
| b2 | **Non-status triage application** | 52-file classification table in hand, evidence-cited | SUPERSEDED banners/stamps not written; EXECUTED planning docs not `git mv`'d to `docs/planning/archived/` | queued (f.10) |
| b3 | **HARVEST of batch open-inventories** | by design, tracked items stayed bare; `check-todo-system` shows zero unharvested Sept §f reports | explicit dedupe ledger for the agents' OPENS summaries (most map to already-tracked rows) | queued (f.11) |
| b4 | **Corpus-wide check-rows final sweep** | per-batch gates ran; partials sampled genuine | one final enumeration of ALL partial tables across the 294 files | queued (f.12) |
| b5 | **Owning-row close-out** | TODO_LIST:783 + pipeline.md:582 still carry "remaining: ~300 reports" stale text | row re-point to the actual state (Sept done, 2026-10 wave next) | waiting for the final legs so the row closes once |

## c) NOT STARTED

1. `nix flake check --no-build` (the quality gate; docsonly edits so far — still owed by contract).
2. README.md / FEATURES.md count re-derivation (the 2026-10-06 §f.5 debt the plan inherits).
3. ROADMAP.md Theme-1 stale-framing pass.
4. AGENTS.md spot pass (size/paths/gotchas — GPU section updated by others this month; the docs-health dimensions un-run).
5. docs-health AUDIT output: the two-score inline health report (Accuracy/Fitness, as-found math) — deferred to the closeout after the remaining legs.
6. The 2026-10 root wave (442 reports) + tasks/ (57) — deliberately out of scope (tracked row default #1).
7. qmd re-index after the mass moves (plan M17 leg).

## d) TOTALLY FUCKED UP (caught, all)

1. **I injected a fabricated row into my own b01 transcription** — a `..._placeholder` line that exists nowhere in the agent output landed in the TSV I hand-transcribed. The validator dropped it (BADPATH) exactly as designed, but the transcription bottleneck is the pipeline's weakest link: the error source was ME, not the agent. (Improvement e.1.)
2. **Retag-by-prefix sed** (v→w on moot/decided-against/superseded evidence) ran after validation, not before — a prefix my regex missed ("superseded by disable→re-enable") stayed `v`, landing slightly inconsistent with the strict w-semantics; corpus-consistent with batch-00's landed form, but the rule should have been in the agent prompt, not my post-hoc regex (e.2).
3. **Citation sweep used 29-char filename prefixes** — task-id twins (03-49/04-57 share an id) can cross-match; the failure mode is conservative (keep-in-place), but the sweep should match full filenames (e.3).
4. **Cross-report references to the 2 archived files now have stale paths** (4 historical status reports cite `docs/status/<name>`). Accepted per precedent (archived/ is discoverable), but I did not annotate those 4 citing files with a moved-pointer note — cheap, skipped, should have been on the checklist.
5. **No corpus-wide final check-rows enumeration** — I verified per-batch and sampled; the "everything works" claim in the TL;DR of my batches rests on 9 runs + 2 samples, not one exhaustive pass (b4).
6. **The plan's T6 default said prune 208 rows; 249 existed** — the plan number was 5 days stale at execution; count-before-claim caught it, but the plan itself was not re-verified on redispatch (the re-dispatch protocol's step-0, applied to the plan I was executing).

## e) WHAT WE SHOULD IMPROVE

1. **Kill the transcription leg** — have the classifier output written to disk by a relay with write access (or a writable sub-agent), removing the hand-copy class entirely; the validator stays as the net. This session: ~1,900 lines hand-transcribed; one corruption (d.1) per ~470 lines.
2. **Encode verdict-kind semantics in the agent prompt** (decided-against/moot/superseded → `w` AT EMISSION), deleting the post-hoc sed retag and its edge cases.
3. **Citation sweeps match full filenames**, never prefixes — twin task-ids make prefix matching ambiguous.
4. **Archive checklist gains one step**: after `git mv`, grep OTHER status reports for the moved name and add a moved-pointer note to each citing file (4 cheap edits this pass).
5. **The docs-health skill could adopt** my `validate-verdicts.sh` (snippet relocation + wrong-evidence noun-overlap filter) — it operationalizes the groundwork §e.2/§e.3 lessons as a reusable gate.
6. **Plan redispatch step-0**: re-count the plan's load-bearing numbers (row counts, file counts) before executing a plan older than a few days — the 208-vs-249 gap.

## f) NEXT — ordered, P0 first

**Harvest state: every item below is either (i) already tracked on the owning row TODO_LIST:783 / pipeline.md:582 / the 2026-10-19 plan's own task table — the re-dispatch continues there (marked [tracked]); or (ii) deliberately not harvested because it is a skill/tooling change owned by crush-config, not this repo (marked [crush-config]); or (iii) an owner question (§g). No new queue rows were minted mid-report to avoid racing the final close-out re-point.**

1. Run `nix flake check --no-build` (c.1) — [tracked, plan T10.1]
2. Final corpus-wide `check-rows` enumeration over all 294 files; triage any PARTIAL beyond sampled opens (b4) — [tracked]
3. Apply the non-status triage: SUPERSEDED banners + `git mv` the 17 EXECUTED planning docs to `docs/planning/archived/`, keep 24 REFERENCE + 4 ACTIVE in place, one-line manifest (b2) — [tracked, plan M9/M10]
4. Add moved-pointer notes to the 4 reports citing the 2 archived files (d.4) — [tracked]
5. HARVEST dedupe ledger: reconcile the agents' per-file OPENS inventories against TODO_LIST/docs/todo; route anything untracked (b3) — [tracked, plan T8]
6. README/FEATURES computed counts re-derivation + stamp (c.2) — [tracked, plan T9.1–9.3]
7. ROADMAP Theme-1 staleness pass (c.3) — [tracked, plan T9.4]
8. AGENTS.md docs-health dimensions pass (size/paths/endurance) (c.4) — [tracked, plan T9.5]
9. CHANGELOG entry for this sweep (count-before-claim form) + the two-score docs-health AUDIT report inline (c.5) — [tracked, plan T10.3]
10. Close-out: re-point/close TODO_LIST:783 + pipeline.md:582 on BOTH surfaces; flip the plan tombstone EXECUTING→EXECUTED; this report's §d/e lessons → CHANGELOG narrative (b5) — [tracked, plan T10.4]
11. qmd re-index after all moves (c.7) — [tracked, plan M17]
12. 2026-10 root wave (442) + tasks/ (57): same pipeline, root/tasks variants — [tracked, "next in line" on the owning row]
13. Validator upstreaming: offer `validate-verdicts.sh` + prompt contract to the docs-health skill (e.5) — [crush-config, owner-gated]
14. Transcription-relay replacement (e.1) — [crush-config, owner-gated]

**Beyond #14 nothing new was surfaced by this session that is not already tracked** — the corpus's open asks were verified as already-routed (that is why they stayed bare); inventing filler would dilute the list.

## g) QUESTIONS (cannot answer myself)

1. **Archive policy for cited-but-resolved reports:** 10 of my 14 archive candidates are fully resolved but cited as `**Source:**` pointers by TODO_LIST / docs/todo / CHANGELOG. Current default (predecessor-consistent): cited files stay in `docs/status/` root. Alternative: archive them anyway and let historical citations resolve through `archived/`. This decides the fate of hundreds of files once the 2026-10 wave sweeps — which policy do you want encoded?
2. **2026-10 wave sequencing:** the tracked row says "next in line", but the SUPERB masterplan v2 sprints are actively dispatching. Should the 442+57 October reports ride after the current masterplan sprints, or interleave now?
3. **Zero-strike closure-shape files** (e.g. `2026-09-26_04-11`): fully resolved, zero numbered items, so the canon's "≥1 strikethrough to archive" gate mechanically blocks archiving without adding an artificial strike. May I extend the convention (header banner form for zero-item closure reports), or keep holding such files in place?

---

## Appendix: evidence

- Batches: `~/.cache/docshealth/b0{1..9}-{raw,spec,drops,checkrows}.[tsv|log]` (raw agent output → validator spec → drops with reasons → per-batch check-rows)
- Commits: `e37dde0c2` (tombstone) · `36057309a` (249-row prune) · 9 × `docs(status): annotate batch-0N corpus verdicts` · daemon `f12302830` (archive moves)
- Archive: `docs/status/archived/{2026-09-19_16-16…,2026-09-30_07-42…}`; `check-doc-links.sh` OK post-move
- Gates this session: annotate self-test green; `check-todo-system.sh` OK (structure) + ~~WARN 82 (all 2026-10 wave, out of scope)~~ **WARN 82 corrected 2026-10-24 (T1): 81 stable = 22 Sept + 59 Oct, see census in 16-43 plan §T1**; `check-doc-links.sh` OK; `nix flake check --no-build` PENDING (f.1)
- Plan marker: `docs/planning/2026-10-19_05-06_SUPERB-docs-health-corpus-completion.md` line 5 — EXECUTING (instance docs-health redispatch-1024, 2026-10-24 07:29, HEAD `e9627a7bd`)
