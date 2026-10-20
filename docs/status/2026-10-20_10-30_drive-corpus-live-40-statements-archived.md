# Status — Drive corpus LIVE: full Qonto history served + 40 statements archived (2026-10-20 10:30 CEST)

**Trigger:** owner dropped the Google-Drive zip (`~/Downloads/drive-download-20261019T031901Z-1-001.zip`, 230MB, 1222 files) answering open question (a) + the standing "keep going until everything works" directive. Plan: `docs/planning/2026-10-19_06-15_SUPERB-drive-corpus-full-import-paperless-restore.md`.

## a) FULLY DONE

1. **Full Qonto history serves live.** The Drive set's real transaction exports are OFX (ORG QONTO; the `_0.xls` siblings turned out to be WISE activity exports). `bank-sync`'s `ofx_to_qonto_csv.py` converts them to the Qonto CSV schema, bridging all 132 fragment rows onto their original UUIDs (match key: local timestamp-to-the-minute + abs amount; OFX DTPOSTED is local wall-clock — verified against the Stripe 2023-03-15 row). Live import 2026-10-20 08:51: `imported=859 skipped=104` (tech) + `imported=89 skipped=28` (holding), 0 errors, rerun imports 0. Dashboard serves Tech 2023-01-04→2025-02-24 (963 rows, 20 pages) and Holding 2022-12-07→2025-02-05 (117 rows) with MEMO-enriched descriptions and correct money formatting.
2. **All 40 monthly statement PDFs archived in Paperless-ngx** with per-file metadata (title `Qonto Statement - <legal entity> - YYYY-MM`, created = first of month, correspondent Qonto, type Bank Statement, tags bank-sync+qonto): journal shows 40 uploads, `verified 40 Qonto statement documents`, marker `qonto-statements-paperless.done` (10:18). Rehearsed on a throwaway DB BEFORE live import (fragments 104+28, full 859+89, idempotent rerun, distinct IDs == row counts).
3. **Wave-6 restore unit landed and guard-proven.** Opt-in `services.paperless-db-restore` oneshot (schema-missing + dump-sanity + marker guards, ordered before all four paperless units). Its first activation correctly REFUSED — the owner had already run the manual pg_restore 2026-10-19 07:31 (journal: sudo dropdb/createdb/pg_restore from pts/27). Flag dropped after verification; option stays for future incidents.
4. Corpus landed in the bank-sync repo (commit 0ccc3a9b, pushed): 2 full CSVs + 40 PDFs + the converter with its gates documented.

## b) PARTIALLY DONE

1. Nothing of THIS mission. (Follow-up corpus rows queued in docs/todo/services.md.)

## c) NOT STARTED (queued, deliberately out of scope)

1. qonto_archive attachments (~1000 files) + receipts folders → Paperless bulk archival (no creds needed — ready row).
2. Wise XLS activity exports (1078+121 rows) + Wise 2024 mt940 statements → bank-sync import (ready row).
3. Qonto Business API creds for live receipts sync (owner, unchanged).

## d) TOTALLY FUCKED UP

1. **Two unit-script bugs shipped to LIVE activations because I rewrote the upload unit without rehearsing it** — violating the exact lesson this arc taught (the 04:03 stdout-pollution fix was preceded by an import rehearsal; the upload rewrite was not). (i) `${base%%-*}` strips at the FIRST hyphen → month = "2023", validation refused all 40 (09:13 failure). (ii) the loop's `base` variable shadowed the paperless API base URL → curl resolved a PDF filename as a host after iteration 1 (09:52 failure). Both found from the journal, fixed, and the FULL loop rehearsed with the system bash (`read -d` needs real bash — mvdan/sh can't reproduce unit semantics) before the third deploy landed green.
2. The auto-commit daemon won four races against my commits (one amend mislabeled a foreign dnsblockd commit; restored its message). Content never lost; message hygiene degraded. Lesson: on this box, stage+commit in ONE fast command, or amend the daemon's sweep afterward.

## e) WHAT WE SHOULD IMPROVE

1. **Every unit-script change gets a local rehearsal of the EXACT generated script** (extract from /nix/store, run against repo-visible fixtures with /run/current-system/sw/bin/bash) — two of this session's three activation failures were mechanically preventable.
2. Shell variable namespaces in unit scripts deserve a naming convention (loop-local vars prefixed, never `base`/`path`-shaped names that helpers close over).

## f) NEXT

| # | Task | Impact | Effort | Owner |
|---|------|--------|--------|-------|
| 1 | qonto_archive attachments + receipts bulk archival (statement-upload pattern, filename-derived metadata) | 🔴 completes receipts archival without creds | M | me |
| 2 | Wise XLS converter (extrame/xls reads them) + wise importer pass | 🟠 second bank fully served | M | me |
| 3 | Root-cause why ONLY paperless emptied in Wave 6 (standing P0 watch row) | 🟠 trust the subvol pattern | M | root/hot-db |
| 4 | Push SystemNix (this session's commits) | 🟡 | S | me (done at report close) |

## g) VERIFICATION LEDGER

- Import journal 08:51-08:52 (four `import completed` lines, 0 unexpected errors); idempotence re-proven on the throwaway DB pre-deploy.
- Dashboard: `/partials/transactions?balanceID=54255095370649615&provider=qonto` (page 1 of 20, newest 2025-02-24 transfer, amounts like `2 052.65`) and `balanceID=8342493570783497676` (117 rows, Stammkapitaleinlage era present).
- Upload journal 10:16-10:18: 40 `uploading ... (created YYYY-MM-01)` lines + `verified 40` + marker; unit `Finished`.
- Restore unit journal 08:54: `schema present - DB not empty, nothing to restore` (guard worked; no clobber).
- Batteries: `nix flake check --no-build` all green; toplevel eval green; 3 deploys (1 build-blocked by a foreign stale vendorHash — re-pinned with the first-hand got-hash; 2 activated).
