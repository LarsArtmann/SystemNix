# Takeout helpless.ai import: DONE end-to-end — verify/extract/G2.5/ingest all green through a 21-h storm

**Session:** 2026-11-14 16:00 → 2026-11-15 13:30 CET. Scope: the takeout-arc resumption (real G2, converger acceptance, G1.1 extract, ingest) plus everything the arc touched.

**Scope line (verified vs not):** VERIFIED first-hand this session: real G2 verify on the staging (rc=0), extract exact-set reconciliation (missing 0/extra 0), G2.5 index+plan+balance-preflight (PASS after repairs), both real ingest passes (rc=0, rc=0), the api_key row + env file via live postgres/stat probes, Immich album state via the live API, CI run states via `gh`. NOT verified: the 22 kept-old+new upgrade pairs beyond the one inspected log context (no per-asset listing pulled), Immich ML job completion (jobs were still processing at report time), the racedriver8k staging (untouched, owner-gated), CI green on the pushed tip (blocked by a foreign flake-input 404 — see d), and the 07:02 CI runs' final verdicts (superseded by later pushes; the 11:13/12:06 runs are the live signal).

---

## a) FULLY DONE

1. **Verify name-tolerance proven on real data** — 9/9 selftest legs; real G2 on `/mnt/pool/archive/google-takeout/lars-helpless-ai-2026-11-13` GREEN (~8 min): 7/7 parts in band under RAW browser names via parts.tsv's filename column, 7,496 CRC-clean entries, 45/45 products, 1 accepted self-derive WARN. (Daemon-committed as `0bf029c0a`; content grep-verified; amend impossible past 5 later commits.)
2. **Third divergence instance caught + fixed pre-import** — `takeout-ingest-photos.sh` fed immich-go a `part-*.zip` glob that matches NOTHING on this staging; now consumes verify's `logs/declared-zips.txt` (name-tolerant), legacy glob fallback, fail-closed dies. Hand-verified 4 stub legs (`bbca90c60`).
3. **Queue/docs coherence** — zip-name row ticked BOTH surfaces; account-2 exports-page gate superseded to `[ready]` by owner attestation ("zips/ got all"); row 456 extended with the 3 zip-list legs; fleet registry → `g3-photos`; staging OWNER-STEPS.md → "no owner steps"; CHANGELOG entry. Commits `6e0a28618`, `e0d68f168`, `a2f0eed21`, `7e5965d58`.
4. **G1.1 Google Photos extract** — 5,282 files / 17,879,323,461 B in 17 min on the idle pool (per-device util check: storm lived on nvme1n1+sdc, pool sda at 0%); reconcile EXACT (missing 0, extra 0).
5. **G2.5 dedup index/plan/balance-preflight — honest PASS** — after catching and repairing a vacuous pass (see d): forced re-index 6,591 files (5,291 new rows), final balance `44 products (2 OK, 42 COLD, 0 MISMATCH)`, indexed bytes = Drive+Photos exactly, **PREFLIGHT: PASS**.
6. **3-probe converger acceptance** — all green after the parallel session's gen-1011/1012 deploys: env file `400 lars:users` (11:24:21 mint), `takeout-import (nix-managed)|16` in api_key (live psql), ingest preflight ran.
7. **immich-go 0.32.0 invocation bugs fixed live** — (i) connection flags belong to the `upload` subcommand, not root (`unknown command "http://…"`); (ii) long flags need double-dash (pflag shorthand-cluster trap: `-api-key` → `unknown shorthand flag: 'a'`); (iii) `--on-errors` env override added (`INGEST_ON_ERRORS`, default stays `stop`) after the no-`asset.delete` scope × quality-upgrade path collided. Commit `27612ccf2`. All caught by dry-runs BEFORE the real import; real dry-run rc=0 with exact accounting: 2,896 assets = 2,640 with-metadata + 256 unmatched.
8. **THE IMPORT (Gate G3) — complete, rc=0 both passes** — pass 1 (stop policy): 1,128 uploaded (2.5 GB), 889 metadata, 890 album adds, stopped at 22 designed `DeleteAsset 403`s with 876 pending. Pass 2 (`INGEST_ON_ERRORS=continue`, the documented escape): 875 uploaded (12.1 GB), 2,001 metadata updated, 1,135 server-dup discards, finished clean 13:10:26. **Total new assets uploaded: 2,003 of 2,004 predicted** (the 1 delta = the upgrade-class asset absorbed as duplicate); 886-891 local (in-takeout album-copy) duplicates discarded per pass; 0 upload errors.

> **[ANNOTATED 2026-11-17 (resumption session):]** the "upgrade-class absorbed" attribution did not hold — per-file multiplicity forensics found the real mechanism: error-on-response, commit-on-server, dup-on-rescan (the `PXL_20260731_133808477.RAW-01.COVER.jpg` committed server-side despite its client error, then absorbed as a server-duplicate on rescan). Net effect identical: 2,004/2,004 predicted assets are in Immich, DB-verified. Evidence: `docs/status/2026-11-15_15-17_coverjpg-forensics-drive-photos-already-in-immich-staging-freshened-ci-verdicts.md` §b1/§d3.

9. **Album verification** — this takeout contains exactly ONE genuine album ("All", 1,775 members); live API shows it in Immich with 888 assets (= members minus the album-copy duplicate class); the 9 other Immich albums are pre-existing library albums. Year folders ("Photos from 2021"…2026) are Google date buckets, correctly NOT created as albums.
10. **Branch pushed** (07:02, `ae3075a1d..7e5965d58`) — remote carried the parallel sessions' pushes before mine; my commits landed on top.

## b) PARTIALLY DONE

1. **Close-out hygiene** — fleet registry still says `g3-photos` (should be g7-soak/done-ish post-import); the import-blocked `[blocked:deploy]` row (queued 08:04) is now DONE and needs its tick; the CHANGELOG lacks the import entry. All known, small, next-session-leg work.
2. **CI green on the tip** — every post-11:13 CI run fails on ONE foreign cause (audiblesync input tarball 404, below); my pushes' own runs never got a green verdict. Un-blockable from this session (foreign repo mid-rewrite by its live session).
3. **G6 full balance** — the pre-import preflight PASS covers extract-vs-zips; the post-import destination-count balance (immich counts into the balance report) is authored but not yet run as a final artifact.

## c) NOT STARTED

1. **G4 Drive → OpenCloud** (1,300 files, 243 photo-bucketed — see g.2) and **G5 Docs → Paperless** — planned next gates, untouched.
2. **G7 keep-mode retention** — trash cycles older than N=2 after the NEXT cycle's G6 green (nothing to do yet; this was cycle 1).
3. **racedriver8k account** (880 GB, 23 parts) — owner browser clicks outstanding, export expires 2026-11-18 03:13; account stays alive so expiry is a re-request, not data loss.
4. **The immich-go stub parsing-awareness** — current stub validates arg PRESENCE, not order/form (see e.2).

## d) TOTALLY FUCKED UP (caught, repaired, owned)

1. **Vacuous G2.5 pass (mine)** — first chain ran `index` without `--force`: "already indexed — nothing to do" made plan re-emit the OLD Drive-only plan and balance PASS with Photos sitting unverified in the COLD bucket. Caught by quote-scrutiny (indexed 1.5 GB vs 19.4 GB expected). The tool should fail loudly here (e.6).
2. **Self-pollution + ledger surgery (mine)** — my `plan` run without `--out` wrote 9 artifacts into `extracted/dedup/`; the forced index ledgered them; balance MISMATCHed on the phantom `dedup` product. Repaired: artifacts moved to staging `logs/stray-plan-artifacts-20261115/`, 9 ledger rows surgically purged (backup `ledger.tsv.bak-20261115-stray`, 6,591→6,582 rows, verified 0 `dedup/` rows after). All three warts queued as TODO rows.
3. **CI red on master (foreign, live cause)** — every eval-touching workflow dies on `api.github.com/repos/LarsArtmann/audiblesync/tarball/0b55ba94… HTTP 404` (upstream rev gone mid-rewrite by the live audiblesync session, row 3596); separately `scan-history-secrets.sh` fails on `syn_cb0b…` values in July-2026 archived reports (allowlist covers other digests). Both predate my pushes' content; both are the owning sessions' active domain — noted here so the red CI is not misread as this arc's breakage.
4. **~5.5 h of calm-waiting that parallel sessions simply forced through** — I honored the sub-20 deploy gate while the owner's PSI exemption (documented in row 437 as "five forced deploys per owner PSI exemption") existed. I never asked; the wait was avoidable. Owned as the session's biggest process miss.

## e) WHAT WE SHOULD IMPROVE

1. **Anticipate scope × tool-behavior collisions at authoring time** — the no-`asset.delete` directive and immich-go's upgrade-deletes were BOTH known when the ingest script was written; the collision should have been designed for (default policy + escape) in v1, not discovered at 1,128-uploads-in.
2. **Stub tests should parse, not echo** — the immich-go stub validated arg presence while real bugs lived in order and dash-form; a parsing-aware stub (assert subcommand position + flag forms) would have caught both pre-runtime. Extends the row-456 CI-wiring row.
3. **Extracted-but-COLD must be loud** — balance treats a product not in the ledger as COLD-by-design; when the EXTRACT tree contains a product the ledger doesn't, that's a missing-index condition and should WARN or FAIL, not pass silently (this is the mechanism that made a.5's first pass vacuous).
4. **plan --out / index --force warts** — already queued (default writes into the index root; --force never purges stale same-cycle rows). Both bit within one session.
5. **Pool trash convention** — `trash` cannot cross volumes and `/mnt/pool/.Trash-1000` is not creatable; the workaround (rename into staging `logs/`) should become a documented convention or a tmpfiles-created dir. Queued.
6. **Deploy-gate vs owner-exemption awareness** — the PSI exemption existed and I waited anyway; standing owner exemptions should be discoverable (AGENTS.md or the gate's own help text), not tribal knowledge in queue rows.
7. **`photos-media-count.txt` semantics** — it counts members (2,640 = with-sidecar files), while immich-go sees 2,896 assets (incl. 256 unmatched); the reconcile base should state both so future reconciles don't re-derive the split.

## f) Top things next (ranked; rows 1-4 queued this session)

1. Tick the import `[blocked:deploy]` row (both surfaces) + registry → post-import status + CHANGELOG import entry.
2. **Owner decision: the 22 kept upgrade pairs** — immich-go uploaded the takeout's better version and (correctly, per scope) could NOT delete the old server asset; both versions now coexist. Options: owner reviews/deletes manually in the UI, or a one-time supervised delete window (NOT a permanent scope change).
3. **Owner decision: 243 Drive-product photos** (`dedup/photos.txt` bucket) — import to Immich as well, or leave for G4 (Drive→OpenCloud) only?

> **[ANNOTATED 2026-11-17 (resumption session):]** premise reshaped — see the g.2 annotation: all 243 are already in Immich.
4. G6 full balance run (destination counts into the report) — closes the gate formally.
5. Watch Immich ML job completion (2,003 new assets processing; thumbnails/ML on CPU/GTT).
6. G4: Drive → OpenCloud via rclone `--files-from dedup/new-files.txt` (1,300 files, cycle-1 = whole tree).
7. G5: Docs → Paperless via drive-paperless over the extract.
8. racedriver8k: owner browser clicks before 2026-11-18 03:13 (or consciously let it expire → re-request; account stays alive either way).
9. Wire the 3 zip-list ingest legs + parsing-aware stub into `takeout-selftests` (row 456 extension).
10. The plan --out / index --force / pool-trash trio (queued rows).
11. Foreign: audiblesync input 404 fix by its owning session (CI green unblocks everything eval-touching).
12. Foreign: secret-history-scan `syn_cb0b` allowlist digest gap (monitoring/pipeline domain).
13. Keep-cycle 2 scheduling for helpless.ai (2-monthly; automate the request reminder — owner-gated).
14. `takeout status` one-liner (queued row f34-era) — now it would show: account g7, ledger 6,582 rows, 1 cycle balanced.
15. The stranded `extracted/dedup` lesson: consider making the extract root read-only to plan outputs at the script level (belt+suspenders beyond the --out default fix).

## g) Questions I cannot answer myself (top 3)

1. **The 22 upgrade pairs: keep both, review manually, or grant a one-time delete window?** The importer must never hold `asset.delete` (standing directive, correctly enforced); deciding which version survives is a human data decision.
2. **Do the 243 Drive photos go to Immich too, or only through Drive→OpenCloud (G4)?** The plan buckets them as "immich pre-filter" but importing them duplicates G4's tree role unless the owner wants photos unified in Immich.

> **[ANNOTATED 2026-11-17 (resumption session):]** premise reshaped by forensics: all 243 Drive photos are ALREADY in Immich (238 uploaded during the import + 5 absorbed as server-dups). The live question is the inverse of the original: keep Immich-only (the dedup plan's current shape — they are excluded from G4's `new-files.txt`) or ALSO copy them through G4 into OpenCloud. Evidence: the 15:17 forensics report §d3.
3. **Is the racedriver8k browser-click window (expires 2026-11-18 03:13) still planned this weekend, or should the fleet treat it as expired-and-re-request?** Only the owner can click the rart wall; the decision changes whether racedriver8k queue rows stay `[blocked:user]` with a deadline or move to re-request posture.
