# Takeout import CLOSE-OUT: harvest + registry + G6 BALANCED + ML complete — session self-review

**Session:** 2026-11-15 ~13:50 → 14:22 CET. Continuation of the takeout arc (predecessor: `docs/status/2026-11-15_13-31_takeout-import-done-verify-extract-g25-ingest-green.md`). Scope: everything between "report written" and "report closed out" — todo reconciliation, harvest, registry flip, CHANGELOG, G6 full balance, ML-job verification, push + CI verdicts, plus the self-review the owner demanded.

**Scope line (verified vs not):** VERIFIED first-hand this session: the 13:31 report's committed state (daemon `99cb0d656`, 74 lines intact); `27612ccf2` dangling with content-identical reachable twin `eef635818` (empty diff vs HEAD); reachability of ALL 10 arc commits vs `origin/master` (10/10 OK — no other abandoned twins); G6 full balance BALANCED (live run, full table); ML-job state via postgres (`asset_job_status`); the secret-scan failure cause (run-log grep: `syn_cb0b` July-archive hits, zero hits in my content); registry row shape post-edit (7 columns). NOT verified: the `Nix flake check` verdict on my push (still in_progress at 14:20, 14+ min in a queue of parallel-session runs — expected foreign-red either way); docs-gates freshness gate on my harvest (NOT run — process-claimed only, row queued); faces/OCR final-tail completion (33/35 assets pending at 14:15, converging).

---

## a) FULLY DONE

1. **Live-state verification on resume** — report was daemon-committed intact (`99cb0d656`); tree clean; `master` in sync. Discovered `27612ccf2` ("ingest-photos flag fixes") DANGLING — reachable from no branch — and proved its content survived: `eef635818`, same subject, `git diff 27612ccf2 HEAD -- scripts/takeout-ingest-photos.sh` empty. Nothing lost; reflog residue only.
2. **G6 full balance — BALANCED** — live run over the staging: Google Photos 5,282 files / 17,879,323,461 B OK and Drive 1,300 / 1,528,919,192 B OK byte-exact vs the zips; 42 products COLD (not extracted, by design); `RESULT: BALANCED`. Gate G6 closed formally for cycle 1.
3. **ML/jobs verification on the new assets** — via postgres (`asset_job_status`): metadata extraction **100%** (0 pending at 14:15; was 2,006/2,007 at 13:5x), faces recognized 1,974, OCR 1,972, duplicates 1,974 of 2,007 — tail converging, no stuck queue. The 2,007-vs-2,003 window delta EXPLAINED: all 2,007 rows share one `ownerId`, `libraryId` NULL (immich-go upload path) — the +4 sits inside the predecessor report's 886–891 album-copy-duplicate uncertainty band (pass-1 dups were an estimate; 4 of them were inserted rather than server-deduped). No foreign uploads.
4. **Full harvest of the 13:31 report §f/e** — import `[blocked:deploy]` row ticked BOTH surfaces (TODO_LIST + services.md) with DONE verdict + evidence; account-#2 rows updated on both surfaces (remaining = G4+G5, owner-gated); 6 rows added/extended: extracted-but-COLD WARN/FAIL (new, TODO_LIST+services.md), reconcile-base count semantics (new, both), deploy-gate exemption discoverability (new, TODO_LIST+pipeline.md), keep-cycle-2 reminder (new, [blocked:user], services.md), parsing-aware-stub leg (extension on row 457 + twin), read-only-extract-root belt+suspenders (extension on row 3646 + twin).
5. **Registry flip** — `scripts/takeout-accounts.tsv`: helpless.ai `g3-photos` → **`g4-files`** (honest next gate; G4/G5 remain), note rewritten to the post-import state; 7-column TSV shape verified post-edit.
6. **CHANGELOG entry** — the import narrative (gates, counts, the 403-collision scope honoring, fixes with SHAs) appended at the top of the entries block.
7. **Commits + push** — `13da09cfd` (4 files) + daemon `773a976a3` (TODO_LIST.md, swept mid-race — contents verified with `git show`: exactly my 5 edits, no foreign files); pushed; reachability sweep 10/10 arc commits OK.
8. **CI foreign-cause verification** — my push's `Secret history scan` failure log-grepped: every HIT is the KNOWN `syn_cb0b` July-2026 archived-report class (+ a `.gitleaks.toml` fixture blob) — zero hits in anything this arc authored. The red is inherited, not introduced.

## b) PARTIALLY DONE

1. **CI green verdict on the tip** — `Nix flake check` on `13da09cfd` still in_progress at session end (14:20; queued behind two parallel-session runs of 14–19 min each). Expected blockers are foreign regardless (audiblesync/storage-collector FOD class per the live sessions' rows); my diff is docs-typefiles only (the hook's eval-relevance gate skipped flake check locally for exactly that reason).
2. **docs-gates freshness gate** — my harvest followed the HARVEST procedure but the judge (`docs-gates freshness`) was NOT run to prove it; the pre-commit `check-todo-system.sh` link check passed (weaker gate). Row queued below.
3. **ML final tail** — faces/OCR/dup-detect at ~98.3% (33–35 assets pending). Converging on its own; watch row queued so a stalled queue gets noticed, not assumed.

## c) NOT STARTED

1. **The 3 owner decisions** (§g below) — presented at 14:10, unanswered at report time; everything downstream of them (upgrade-pair cleanup, 243-photos routing, racedriver8k posture) is parked.
2. **G4 Drive→OpenCloud + G5 Docs→Paperless** — owner-gated sequencing (§g.2 shapes G4's input set); untouched.
3. **Keep-cycle 2 for helpless.ai** (~2027-01-10) — row landed `[blocked:user]`; nothing to do now.
4. **G7 keep-mode retention** (trash cycles older than N=2) — requires cycle 2's G6 first; nothing to do.

## d) TOTALLY FUCKED UP (caught, owned)

1. **Self-inflicted daemon split-commit** — my first commit attempt died on the 77-char house subject limit (three prior sessions hit the same wall), and the retry's round-trip handed the daemon the window to sweep TODO_LIST.md into a heuristic commit (`773a976a3`). The pre-commit `git log -1` peek rule for TODO-touching commits exists EXACTLY for this and I did not run it. Mitigated post-hoc: `git show --stat` verified the daemon commit carried only my file, and HEAD-tree greps confirmed all 5 edits — but the close-out is split across two commits and the repair-by-amend path was forfeited for nothing.
2. **Schema-blind postgres probes** — two failed queries (`assets` → `asset`; then `deviceId` doesn't exist) before listing tables/columns first. The "sanity-check one known value through the same pipeline" discipline was applied to the NUMBERS but not to the SCHEMA; each failure was a cheap round-trip that a 1-second `\dt` equivalent would have prevented.
3. **Permission-model-blind API probe** — `/api/jobs` with the takeout key → 401: the key's 16-permission scope was KNOWN and the jobs endpoint's admin requirement was not checked before probing. The postgres fallback was correct; the wasted probe was avoidable (this is the "assert WHICH entity serves it" class applied to auth).

## e) WHAT WE SHOULD IMPROVE

1. **Count the commit subject BEFORE committing** — 4th subject-length rejection in three sessions. The hook helpfully prints the fix; the discipline is counting first (`echo -n` the subject, or keep subjects under ~60 by construction).
2. **Schema-first DB probing** — list tables/columns, then query. One `information_schema` read replaces N failed guesses; the arc already paid this once (July-era) and again today.
3. **Check the permission model before scoped-key API probes** — the immich runbook should carry a probe-permission matrix (which endpoints the 16-perm key can hit vs which need admin); row queued.
4. **Run the docs-gates judge after harvest, don't claim rigor** — "harvested per docs-health rigor" without `docs-gates freshness .` is a process claim, not a verdict. Row queued; run it on the next harvest-touching pass.
5. **When a dangling commit is DISCOVERED, complete the checklist immediately** — I verified the twin's content parity at discovery (~14:00) but ran the full 10-commit reachability sweep only at self-review time (14:2x). The sweep is one loop; it belongs to the discovery moment, not the review.

## f) Top things next (ranked)

1. **Owner Q1 — the 22 upgrade pairs** (keep both / owner UI review / one-time supervised delete window; NEVER a standing `asset.delete` grant).
2. **Owner Q2 — the 243 Drive-product photos** (Immich too vs G4-only).
3. **Owner Q3 — racedriver8k click window** (expires 2026-11-18 03:13; still-planned vs expired-and-re-request).
4. `Nix flake check` verdict on `13da09cfd` once the queue drains (foreign-red expected: storage-collector FOD / audiblesync class — do not chase; owning sessions' rows).
5. docs-gates freshness run over this harvest (row queued this session, TODO_LIST + pipeline.md).
6. Immich runbook probe-permission matrix (row queued, TODO_LIST + services.md).
7. ML final-tail watch: faces/OCR/dup-detect → 2,007/2,007 ([watch] row queued, services.md).
8. G4: Drive → OpenCloud via rclone `--files-from dedup/new-files.txt` (1,300 files; input set depends on Q2).
9. G5: Docs → Paperless via drive-paperless over the extract.
10. Foreign: audiblesync input 404 + storage-collector FOD (CI/deploy unblock — owning sessions).
11. Foreign: secret-history-scan `syn_cb0b` allowlist digest gap (monitoring/pipeline domain).
12. Wire the 3 zip-list ingest legs + parsing-aware stub into `takeout-selftests` (row 457 extension).
13. The plan --out / index --force / pool-trash trio (rows 3646–3648).
14. Extracted-but-COLD WARN/FAIL (new row this session).
15. Reconcile-base count semantics (new row this session).
16. Deploy-gate exemption discoverability (new row this session).
17. `takeout status` one-liner (row 456).
18. Staging debris cleanup after G2 green (row 440) + G7 retention + data-ownership flip (post-soak, row 111).

**Self-harvest at authoring time:** items 5–7 are NEW rows landing with this report's commit (TODO_LIST: docs-gates verify + immich probe matrix [ready] with library twins; services.md: ML-tail [watch], library-only). Items 1–3 route to the owner (§g); 4, 10, 11 are foreign/live rows that exist (audiblesync row 3596-era, storage-collector, scan-gap rows); 8–9, 12–18 already hold rows cited above. Nothing in §f is deliberately unharvested.

## g) Questions I cannot answer myself (top 3)

1. **The 22 upgrade pairs: keep both, owner reviews in the UI, or a one-time supervised delete window?** The importer must never hold `asset.delete` (standing directive, honored); which version survives is a human data decision.
2. **Do the 243 Drive-product photos go to Immich too, or only through G4 (Drive→OpenCloud)?** This decides G4's input set (`dedup/new-files.txt` minus photos or as-is).
3. **Is the racedriver8k browser-click window (expires 2026-11-18 03:13) still planned, or expired-and-re-request?** Decides whether its queue rows stay `[blocked:user]` with a deadline or flip to re-request posture (account stays alive either way — no data loss).
