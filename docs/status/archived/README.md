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
