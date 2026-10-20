# Status — Drive-corpus session brutal self-review + full inventory (2026-10-20 13:42 CEST)

**Scope:** THIS session only (resume → Drive zip triage → full-history import → 40 statements archived → Wave-6 restore unit → closeout). Companion reports: `2026-10-20_10-30_drive-corpus-live-40-statements-archived.md` (the what), this one is the what-I-got-wrong.

## a) FULLY DONE

1. Drive zip triaged end-to-end (1222 files): 40 statement PDFs, full-history OFX per org (the `_0.xls` are Wise, not Qonto — discovered by inspection), attachments/receipts/Wolt identified and routed.
2. `ofx_to_qonto_csv.py` converter with hard gates (refuses unless all 132 fragment rows UUID-bridge via timestamp-to-minute + abs amount); rehearsed on a throwaway DB BEFORE live import (104+28 fragments, 859+89 full, idempotent rerun, distinct IDs == counts).
3. Full history LIVE: Tech 963 rows 2023-01-04→2025-02-24, Holding 117 rows 2022-12-07→2025-02-05, 0 errors, dashboard verified both balances (pages, amounts, MEMO-joined descriptions).
4. 40 monthly statement PDFs archived in Paperless with per-file metadata; journal-verified `verified 40` + `qonto-statements-paperless.done` marker.
5. `services.paperless-db-restore` oneshot landed (schema-missing + dump-sanity + marker guards, before all four paperless units); guard-proven live (correctly refused post-manual-restore); enable flag dropped, option kept.
6. Corpus + converter in bank-sync repo (0ccc3a9b, pushed). SystemNix pushed through 6ea935109. Runbook, P0-row follow-up, two ready follow-up rows, plan doc, closeout report all landed.

## b) PARTIALLY DONE

1. **Rehearsal discipline:** applied to the IMPORT path and (after two live failures) to the upload loop — but the initial rewrite shipped unrehearsed (see d1).
2. **Commit-message provenance:** every content change is in git with a correct diff, but several of my messages lost the daemon race; one foreign commit (81d95d9a8) still carries a dnsblockd title over 3 mixed files.

## c) NOT STARTED (queued as ready rows or standing)

1. qonto_archive attachments (~1000 files) + receipts folders bulk archival (ready row).
2. Wise XLS activity imports (1078+121 rows) + Wise 2024 mt940/PDF statements (ready row).
3. Wave-6 root-cause: why ONLY paperless emptied (standing watch row).
4. Qonto Business API creds for live receipts sync (owner, unchanged).

## d) TOTALLY FUCKED UP

1. **Two unit-script bugs reached LIVE activations because I rewrote the upload unit without rehearsing it** — the exact lesson this arc had already taught (the import WAS rehearsed). (i) `${base%%-*}` strips at the first hyphen → month="2023" → validation refused all 40 (09:13). (ii) the loop's `base` shadowed the paperless API base URL → curl resolved a PDF filename as a host after iteration 1 (09:52). Both journal-diagnosed, fixed, rehearsed with REAL bash, green on the third deploy.
2. **My first rehearsal was a green lie:** run under mvdan/sh, which silently lacks `read -d` — it "passed" with **0 files processed**. I caught the suspicious 0, but the lesson stands: a rehearsal must treat empty input as failure, and must run under the shell systemd will actually use (`/run/current-system/sw/bin/bash`).
3. **Resumed on stale state and built a moot restore:** I probed paperless logs with a window ENDING at the previous session's 06:02 failure and never asked "what happened AFTER 06:02?" — the owner had restored manually at 07:31. One fresh `journalctl -u paperless-web -n 20` (or reading the then-updated P0 row before planning) would have saved a deploy cycle, the enable flag churn, and the restore-unit detour (the guard made it harmless, not free).
4. **Git races degraded history hygiene:** lost the message race 4x; one mis-aimed `git commit --amend` relabeled a foreign dnsblockd commit, and restoring its message accidentally swept 3 foreign files into it. I should have stopped amending after the first race and verified `git log -1` immediately before every amend.

## e) WHAT WE SHOULD IMPROVE

1. **Rehearse the EXACT generated unit script**: extract from /nix/store after eval, run against repo-visible fixtures with the system bash, assert non-empty input. Turn this into `scripts/rehearse-unit-script.sh` so it is one command, not a discipline.
2. **Resume protocol:** re-derive CURRENT state from live journals and freshly-read rows before planning — a stale snapshot is a plan-warping bug, not a convenience.
3. Unit-script shell hygiene: loop-local variables get a prefix (e.g. `st_`); never `base`/`path`-shaped names that helpers close over. Rehearsals assert fixture count > 0.
4. Nix indented-string tripwires (already learned, now twice-burned): no `''` in comments, `-d $'\0'` not `-d ''`, `types.str` for host paths. Eval after EVERY module edit, not batched.
5. On daemon-race repos: single fast stage+commit per change; if raced, amend ONLY after re-verifying HEAD content; never amend twice blind.

## f) NEXT (session-scoped backlog, impact-ordered)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | qonto_archive attachments bulk archival (statement-upload pattern, filename-derived metadata, ~1000 files) | 🔴 receipts archived w/o creds | M |
| 2 | receipts/ + reciepts/ folders same pass (60 files, Sparkasse/wise/caya) | 🔴 | S |
| 3 | Wise XLS converter (extrame/xls reads them) + wise importer: AT 1078 rows | 🟠 second bank fully served | M |
| 4 | Same for AH 121 rows | 🟠 | S |
| 5 | Wise 2024 mt940 statements import (EUR/USD/PLN × orgs) | 🟠 | M |
| 6 | Wise PDF statements archival to Paperless (18 files) | 🟠 | S |
| 7 | Wave-6 root-cause: why only paperless emptied (racing ensure/initdb?) | 🟠 subvol trust | M |
| 8 | Post-restore collation-version check (todo row :31 — did the restore clear the warning?) | 🟡 | S |
| 9 | Independent API spot-check of the 40 archived statements (title/created/correspondent — currently self-attested by the unit's count query) | 🟡 | S |
| 10 | Dashboard "Total transactions 859/89" default-window counter vs 963/117 — document or fix the cosmetic | 🟡 | S |
| 11 | Owner decision: keep or delete the 2 span-CSV extract docs in Paperless (superseded by monthly PDFs) | 🟡 | owner |
| 12 | Triage stray Drive files: `preuve-*.pdf`, mail-agreement PDF, Wolt timesheets/invoices (22) | ⚪ | S |
| 13 | Document Drive-extract retention: `~/Downloads/drive-extract-20261019/` (269MB) is load-bearing for tasks 1-2 — move somewhere durable or note it | 🟡 | S |
| 14 | Clean /tmp scratch (rehearsal DB+env, xls2qonto, bank-sync-bin, drive-files.txt) | ⚪ | S |
| 15 | `ofx_to_qonto_csv.py` regression/golden test in the repo (gates exist; no automated test) | 🟡 | S |
| 16 | Cross-validate OFX conversion against the QIF/STA exports (row counts + date ranges as a checksum) | 🟡 | S |
| 17 | Dispose/dedupe the double `.sta` exports per org (same data as OFX) | ⚪ | S |
| 18 | Native OFX importer in bank-sync (Go) to replace the python converter long-term | ⚪ | M |
| 19 | Native Wise-XLS importer in bank-sync | ⚪ | M |
| 20 | Paperless saved view "Qonto Statements" (declarative, paperless-dashboard pattern) | 🟡 | S |
| 21 | Verify nightly paperless document_exporter picked up the 42 new docs (DR completeness) | 🟡 | S |
| 22 | Verify btrbk-pool snapshots cover the staged qonto-import statements tree | 🟡 | S |
| 23 | Post-import gatus Bank-Sync checks + rev-drift tripwire state | 🟡 | S |
| 24 | Coverage banner ("statement-backed coverage —") semantics for CLI imports — should the coverage model know the import span? | 🟡 | M |
| 25 | bank-sync repo docs (runbooks/README) still describe the fragment corpus — update for full corpus | 🟡 | S |
| 26 | AGENTS/07-gotchas-sync.md: OFX-FITID vs CSV-UUID namespace + bridge-key lesson | 🟡 | S |
| 27 | AGENTS/11-rituals.md: "rehearse the exact generated unit script" tripwire | 🔴 prevents d1 class | S |
| 28 | Smoke baseline refresh: 7→8 FAIL flip during my deploys (caddy timeout, nsfw-classifier, prometheus journal-rate under storm) — re-baseline when calm | 🟡 | S |
| 29 | Daemon-race coordination: propose convention (daemon skips freshly-staged pathspecs, or sessions commit within N seconds of staging) | 🟡 | S |
| 30 | Standing: pma forward relock, 12 vendorHash shim drops, Monitor365 smoke triage (foreign) | ⚪ | watch |

## g) TOP 3 QUESTIONS (cannot be answered from the box)

1. **Paperless representation:** keep or delete the two span-CSV extract documents now that the 40 monthly PDFs supersede them? (Deletion is a data decision I won't make unilaterally.)
2. **Attachment corpus:** archive ALL ~1000 qonto_archive files (PDFs AND PNG receipts) plus the receipts/ folders into Paperless, or a subset (e.g. PDFs only)? Related: the 230MB corpus lives only in `~/Downloads` — should the non-git portion (attachments, Wolt, strays) move to a durable pool location, and where?
3. **Wise corpus:** import the Wise XLS/mt940 history into bank-sync now (same mission shape as Qonto), and should Wise statements also flow to Paperless via the same unit pattern — or is Wise exclusively API-synced going forward, making file imports redundant overlap?
