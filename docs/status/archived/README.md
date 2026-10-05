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
