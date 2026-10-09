# Archived Reports

Flat, append-only archive of resolved point-in-time documents. Nothing here is
"current" — every file carries a resolution banner and inline strikethrough
annotations (the `[docs-health <date>] RESOLVED + ARCHIVED` convention) or was
superseded by a named successor.

**Counts (2026-09-21 docs-health sweep):** 1,352 files here (status reports +
operations runbooks), 42 in [`docs/planning/archived/`](../../planning/archived/)
(executed/superseded plans). 236 dated reports/plans remain unarchived by
design — they still carry open work.

## What gets archived

- **Status reports** whose every item is verifiably resolved (done, superseded,
  or pure point-in-time forensics) — classified by the docs-health skill's
  ARCHIVE/ANNOTATE/OPEN-CARRIER pass, most recently 2026-09-19 (34 files) and
  2026-09-21 (status: nodejs-slim shim, boot-mirror rc3, signoz pair bump;
  planning: 20 plans + 2 operations docs).
- **Planning docs** that are fully executed or explicitly superseded — the
  `docs/planning/archived/` sibling.
- **Operations runbooks** for one-shot, already-executed procedures.

## Conventions

- Moves are `git mv` (history preserved); living-doc references are repointed
  in the same change — dangling pointers to this directory are a bug.
- Historical narrative is never rewritten: resolutions are added as banners +
  `~~inline strikethrough~~ done at <hash/evidence>` markers.
- `CHANGELOG.md` is append-only and deliberately NOT repointed when files move
  here (frozen-historical path references).

## Finding things

1. `grep -l <topic> docs/status/archived/` — full-text search is the primary tool.
2. `git log --follow docs/status/archived/<file>` — pre-archive history.
3. Open work never lives here: check [`../../todo/`](../../todo/) libraries and
   [`TODO_LIST.md`](../../../TODO_LIST.md) first.

## Bulk-archive manifest — 2026-10-03 (docs-health pass, window closeout)

10 files moved from `docs/status/` — all no-op re-fire verification reports of fix ticket `000001a0fada084de720013c96a300000000` (reviewer finding on `5844537b`'s false provenance claim; finding was already applied at `4eb7fc12`/`b26c11b7`). Classification: **ARCHIVE** — every item is a pure point-in-time re-verification reaching the identical "finding CLOSED as already-applied" verdict; the reports carry their own in-body resolution and a `RESOLVED + ARCHIVED` banner. Files: `2026-10-02_{06-41,06-57,07-12,07-23,07-44,07-57,08-07,08-18,08-59,re-fire9}_task-000001a0fada….md`. Deciding reason: uncited by any live doc (checked TODO_LIST.md, docs/todo/*, CHANGELOG.md, AGENTS/README/ROADMAP/FEATURES); the cited siblings (06-25, 07-35, 08-30, 08-31) stay in place. Canonical narrative: `docs/status/2026-10-03_01-15_window-closeout-reap-single-sourcing-lineage-and-fix-tickets.md` §d/§e.

## Bulk-archive manifest — 2026-10-05 (docs-health pass, 7-task window close-out)

2 files moved from `docs/status/` — both verified no-op re-dispatch reports of reviewer-fix tickets whose findings were already healed by earlier lineage: `2026-10-03_05-47_task-000001a0fed8b75…` (splice-finding; fixed by `86a38abe`) and `2026-10-03_14-21_task-000001a0fed8bb32…` (tail-relocation finding; fixed by `192a9309`→`15168c12`). Classification: **ARCHIVE** — pure point-in-time re-verification, identical "already healed" verdict, each carrying a `RESOLVED + ARCHIVED` banner; uncited by any live doc at archive time. Deciding reason per file: zero references (grep over TODO_LIST.md, docs/todo/*, CHANGELOG.md, AGENTS/README/ROADMAP/FEATURES). Canonical narrative: `docs/status/2026-10-05_09-58_window-closeout-reviewfix-nop-pruneverify-parityguard-batch.md` §a.1–2.

## Bulk-archive manifest — 2026-10-06 (docs-health full-corpus sweep)

23 files archived — 20 from `docs/status/`, 3 from `docs/planning/` — by the 2026-10-06 docs-health AUDIT (~620 dated files classified across status/planning/research/reviews/brainstorming/troubleshooting). Every archived file was verified **UNCITED** by `TODO_LIST.md`, `docs/todo/*`, and the living docs at archive time (cited siblings — movie-window 19-43, freeze-13/14/15 autopsies, eval-warning-sweep, two pipeline-cited re-fire records — stayed in place). Classification: **ARCHIVE** — every file is a pure point-in-time record with every item resolved in-body; each gained a `RESOLVED + ARCHIVED` banner + one inline strikethrough at archive time.

- **Re-fire / re-dispatch no-op verification records (verdict stands, zero new asks):**
- 2026-09-25_05-14_task-000001a0d686… (fully-executed codification log)
- 2026-09-26_01-35_task-000001a0da95… (no-edit closure re-verification, run 2)
- 2026-09-26_01-49_task-000001a0dad1… (no-edit re-verification closeout)
- 2026-09-26_01-59_task-000001a0da95… (no-edit closure verification)
- 2026-09-26_04-44_task-000001a0db75… (re-dispatch verification; follow-ups harvested in-body)
- 2026-09-26_05-21_task-000001a0db75… (hermes re-fire verification + citation fix)
- 2026-09-27_01-18_task-000001a0dfdb… (fire-2 compact re-fire verification)
- 2026-09-27_01-46_task-000001a0dfdb… (fire-3 compact re-fire verification)
- 2026-09-27_08-56_task-000001a0e037… (fire-3 degenerate re-fire verification)
- 2026-09-29_03-39_task-000001a0ea69… (duplicate-dispatch independent re-verification)
- 2026-10-02_08-01_task-000001a0f97e… (re-fire 7 protocol results; sweep healed)
- 2026-10-02_08-12_task-000001a0f97e… (re-fire 8 verification record)
- 2026-10-02_08-22_task-000001a0f97e… (four-step re-fire verification record)
- 2026-10-02_08-30_task-000001a0fada… (pure no-op re-verification; finding already applied)
- 2026-10-03_01-41_task-000001a0fea1… (re-fire verification; trash task confirmed done)
- 2026-10-03_07-35_task-000001a0fed8bb32… (fire-5 tail relocation executed, class closed)
- 2026-10-03_task-000001a0fed8bb32…_tail-relocation-nop (verified no-op adjudication)
- 2026-10-05_01-22_task-000001a108f0f4cb… (parity fire-1 re-dispatch verification)
- 2026-10-05_02-45_task-000001a108f0f4cb… (parity fire-3, evidence-only)
- 2026-10-05_07-43_task-000001a108f0f4cb… (parity re-fire #6, verification-only)
- **Planning:** `2026-05-11_dozzle-evaluation.md` (ADOPTED — deployed live since ≤2026-08-31); `2026-01-12_19-09-NIX-ANTI-PATTERNS-PHASE-3-4-{EXECUTION-PLAN,DETAILED-TASKS}.md` (executed 100% per the archived 2026-01-13 completion report).

Counts after this sweep: 1,390 files here, 45 in `docs/planning/archived/`.

**Gate-drift finding (2026-10-06):** the strict completeness gate (`grep -rLn '~~' <archived-dir>/` prints nothing) is violated at scale — ~1,056 files here + 18 in planning/archived carry banner-only resolutions without strikethroughs (the 2026-10-03/10-05 sweeps established banner-only as de-facto practice for narrative reports). Queued for the owner: relax the gate to "banner OR strikethrough" or schedule a mechanical backfill (docs/todo/pipeline.md).
