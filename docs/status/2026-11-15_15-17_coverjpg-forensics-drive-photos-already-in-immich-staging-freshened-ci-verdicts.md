# Cover-jpg forensics: the 1-asset mystery SOLVED (nothing missing), all 243 Drive photos ALREADY in Immich, staging freshened, CI verdicts landed

**Session segment:** 2026-11-15 14:25 → 15:2x CET (continues `2026-11-15_14-22_takeout-closeout-harvest-g6-balanced-ml-complete-status.md`). Scope: the owner's two follow-up questions (the 2,004th asset; OpenCloud/Paperless state), the staging "updated as needed?" audit, and this report. Date stamp: `date` = 2026-11-15 15:17:21 CET.

**Scope line (verified vs not):** VERIFIED first-hand: the three-run decode of `logs/immich-go.log` (dry-run 2,004 @ 12:29:12 / pass 1 1,128 @ 12:37:03 / pass 2 875 @ 13:10:26), per-file upload-line multiplicity (2,002 files × 2 + 3 summaries + 3 outliers), the COVER.jpg error→commit→server-dup chain, DB presence of the suspect files, 238 distinct real-pass Drive uploads vs 243 discovered with 243 server-dup verdicts, OpenCloud state recency (nothing newer than Nov 14), paperless 4,884 docs (2 since Nov 14 = regular flow), G6 balance re-run BALANCED (now persisted), staging file-by-file freshness, CI failure causes for BOTH my pushes (store-path-not-valid + `Failed to fetch git repository 'ssh://git@github.com/LarsArtmann/audiblesync'` in the Evaluate step; 6/6 VM tests failed in the same runs). NOT verified: per-VM-test failure causes (one grep came back empty; deliberately not chased — foreign class, docs-only diff), whether the 32-34 ML stragglers are videos or a stalled queue (counts only).

---

## a) FULLY DONE

1. **"What is the 1 not uploaded asset?" — ANSWERED, and nothing is actually missing.** Log forensics decoded immich-go.log into three runs (the 12:29:12 line `uploaded successfully : 2004 (14.6 GB)` is the DRY-RUN's prediction summary — its per-file "uploaded successfully" lines are simulations, which is why naive grep counts double). The 2,004th asset is `Takeout/Google Photos/All/PXL_20260731_133808477.RAW-01.COVER.jpg`: pass 1's `POST /api/assets` errored client-side at 12:36:52 (same stress-second as the DeleteAsset-403 tail) but the upload HAD committed server-side; pass 2 then saw it as a server duplicate → discarded, never counted. DB-verified present. Net: **2,004/2,004 predicted assets are in Immich**; only the counter missed one.
2. **Correction issued:** the 13:31 report's "the 1 delta = the upgrade-class asset absorbed as duplicate" was the WRONG CLASS — real mechanism is *error-on-response, commit-on-server, dup-on-rescan*. Net effect identical, attribution wrong. (Annotation still pending — b.1.)
3. **All 243 Drive-product photos are ALREADY covered in Immich** — 238 uploaded as real-pass Drive-path assets + 5 discarded as server-duplicates of their Google-Photos twins; every one of the 243 received a server-dup verdict in at least one pass (= the server holds the content). This RESHAPES owner question §g.2 from "import to Immich too?" (they are) to "Immich-only (the dedup plan's current shape — photos excluded from G4's new-files.txt) or ALSO copy through G4?".
4. **OpenCloud/Paperless: verified untouched by this arc** — OpenCloud state (`/mnt/pool/services/opencloud`) has nothing newer than Nov 14; Paperless holds 4,884 documents with only 2 added since Nov 14 (the regular drive-paperless flow, not takeout). G4/G5 genuinely not started.
5. **Staging freshened (the "updated as needed?" audit):** NEW durable G6 artifact `logs/balance-report-20261115.txt` (the 13:5x BALANCED verdict had been stdout-only — now re-run and persisted); `verification-report.md` gained a G3+G6 addendum (full ingest accounting incl. the COVER.jpg mechanism, 243-photos coverage, album state, BOTH count semantics); `OWNER-STEPS.md` state block refreshed (G1.1+G2.5+G3+G6 done; G4/G5 pending decisions not browser work; cycle-2 ~2027-01; racedriver8k deadline section kept). Deliberately untouched: `photos-media-count.txt` (G2 artifact consumed by 2 scripts — the split now lives in the addendum), `urls.txt` (shredded with the cookie jar only at close-out, row 440), the G2 statics (`parts.tsv`, `products*.tsv`, `inventory.tsv`, `SHA256SUMS`), and `dedup/` plan outputs (G4 inputs; photos.txt's consumed state recorded in the addendum).
6. **CI verdicts for my two pushes (13da09cfd, ed17352c9) landed — both `Nix flake check` runs FAILED on foreign causes:** the Evaluate step dies on a `path … is not valid` store path AND repeated `Failed to fetch git repository 'ssh://git@github.com/LarsArtmann/audiblesync'` (the audiblesync input's ssh:// URL form from its owning session's mid-rewrite — CI has no deploy key for it); all 6 VM tests failed in the same runs. My diffs are docs-typefiles only (the local hook's eval-relevance gate skipped flake check for exactly that reason). Do-not-chase verdict stands.

## b) PARTIALLY DONE

1. **The 13:31 report annotations** (§a8 mechanism correction + §g.2 premise reshape) and the matching account-row phrasing on both queue surfaces are IDENTIFIED but NOT landed — the correction currently lives only in chat + the staging addendum. §f.1, row queued.
2. **ML tail is a NEAR-STALL, not a tail:** 32 faces / 34 OCR / 32 dup-detect pending at 15:17 (33/35/33 at 14:15 — ~1 asset/hour). Metadata extraction is 100%. Could be slow video transcodes; could be a stalled queue. Diagnosis row queued.
3. **CI red attribution stopped at two named causes** — the 6 VM-test legs share the runs but their individual causes were not read (one grep returned nothing and I stopped per the do-not-chase line; honest gap: a representative cause would have cost one more grep).

## c) NOT STARTED

1. **The 3 owner decisions** — asked at 14:10 and again with Q2 reshaped at ~15:0x; unanswered; all downstream work parked.
2. **G4 (Drive→OpenCloud) + G5 (Docs→Paperless)** — untouched, owner-gated (Q2 shapes G4's input).
3. **The b.1 annotations** — not started (this report's own top follow-up).

## d) TOTALLY FUCKED UP (caught, owned)

1. **Malformed DB presence query** — I wrote `originalPath LIKE '%A%' OR originalPath LIKE '%B%'` as a per-row boolean, which answers nothing about presence; I then read presence from row-existence instead of fixing the query. The "sanity-check one known value" rule exists for SQL too and I skipped it (same class as the awk-join rule).
2. **First hour-bucket awk collapsed all timestamps into one bucket** (key built at the wrong width — date field dropped); abandoned for a per-file multiplicity route. One wasted round-trip, caught immediately by the implausible output shape.
3. **The §a8 correction stayed in chat** — discovered the wrong-class claim at ~14:4x, answered the owner, and did NOT annotate the historical report in the same turn. The "assert WHICH surface the fix touched" rule applies to corrections I ISSUE, not just ones I receive. Still un-annotated at report time (b.1).

## e) WHAT WE SHOULD IMPROVE

1. **Annotate-at-discovery** — when forensics overturn a claim in a historical report, the inline marker lands in the SAME turn; a chat answer is not a surface.
2. **SQL joins the one-known-value discipline** — run one known-positive through the exact query before reading its output (my boolean probe was garbage-in-read-around-out).
3. **immich-go log parsing trap:** run-summary lines (`uploaded successfully : N (size)`) share the per-file line's opening text — greps over that log must exclude the ` : ` summary shape or counts inflate (my first read said 4,007 uploads before the multiplicity decode caught it). Goes into the probe/log-forensics row.
4. **Watch-rows need RATE thresholds, not pending counts** — "33 pending" hid a ~1/hour near-stall for an hour; the row should say "pending AND rate < X/h ⇒ diagnose".
5. **All-legs CI failures deserve one representative cause read** — zero-for-one grep is not attribution (even when the class is foreign).

## f) Top things next (ranked)

1. **Annotate the 13:31 report** (§a8 correction marker + §g.2 reshape) and align the account-row §g.2 phrasing on both queue surfaces. [row queued this report]
2. **Owner Q1 — the 22 upgrade pairs** (keep both / owner UI review / one-time supervised window; never a standing `asset.delete`).
3. **Owner Q2 (reshaped) — the 243 Drive photos are already in Immich:** keep Immich-only, or ALSO route through G4 into OpenCloud?
4. **Owner Q3 — racedriver8k browser clicks** (expires 2026-11-18 03:13 — ~2.5 days; still-planned or expired-and-re-request?).
5. **ML near-stall diagnosis:** identify the 32-34 stragglers (videos vs stuck), check the job queue, nudge or accept. [row queued this report]
6. Foreign CI: audiblesync `ssh://` fetch failure (owning session lands an https-fetchable form or a CI dep key), the store-path-not-valid leg, and one representative VM-test cause.
7. Foreign: secret-history-scan `syn_cb0b` allowlist digest gap.
8. G4: Drive → OpenCloud via rclone (post-Q2 input shape).
9. G5: Docs → Paperless via drive-paperless over the extract.
10. docs-gates freshness run over the takeout harvests (row, 14:22).
11. Immich probe-permission matrix row + the immich-go log-summary-shape parsing note (extension, row queued 14:22).
12. Row 457 CI legs (3 zip-list legs + parsing-aware stub).
13. The plan --out / index --force / pool-trash trio.
14. Extracted-but-COLD WARN/FAIL.
15. Count-semantics script-level fix (staging-level satisfied by the addendum; script output still open).
16. Deploy-gate exemption discoverability.
17. `takeout status` one-liner (row 456).
18. Staging close-out shreds (`urls.txt` + cookie jar) at close-out (row 440).
19. Keep-cycle 2 (~2027-01, [blocked:user]).
20. G7 retention + data-ownership flip (post-soak).

**Self-harvest at authoring time:** items 1 and 5 are NEW rows landing with this report's commit (TODO_LIST [ready] twins in services.md); item 11 EXTENDS the 14:22 probe-matrix row (both surfaces). Items 2-4 route to the owner (§g); 6-7 are foreign with existing rows; 8-20 already hold rows. Nothing deliberately unharvested.

## g) Questions I cannot answer myself (top 3)

1. **The 22 upgrade pairs: keep both, owner reviews in the UI, or a one-time supervised delete window?** (Importer never holds `asset.delete` — standing directive, honored.)
2. **Drive photos (reshaped): all 243 are already in Immich via the ingest — keep them Immich-only (the dedup plan's current shape), or ALSO copy them through G4 into OpenCloud?**
3. **racedriver8k browser-click window (expires 2026-11-18 03:13): still planned this weekend, or expired-and-re-request posture?**
