# Takeout resumption: ML queue-loss diagnosis closed, 13:31 report annotated, Oct-29 failure population surfaced

**Session:** 2026-11-17 09:14 → 15:36 CET (with a ~6h mid-session idle; see d2). Scope: the resumption briefing's two queued rows (annotate-13:31, ML near-stall diagnosis) plus everything the diagnosis surfaced. Standing directives honored throughout: no G4/G5 starts, no `asset.delete`, no foreign-CI chasing, WAIT posture at session end. All DB/journal/API evidence in this report was gathered first-hand this session.

**Scope line (verified vs not):** VERIFIED first-hand: takeout ML pending counts (frozen 32/34/32 across 42h), global throughput (zero faces/OCR/dup completions since 2026-11-15 23:00:33 UTC), straggler identity (37 assets: 35 motion-photo components + 2 motion videos, paths pulled from postgres), file magic bytes (5 sampled), preview existence on disk (3 sampled), ML service liveness (10 ms ping), system-config job concurrency, both API keys' scope verdicts (401/403), server restart timeline (journal), thumbnail-error population join (1,425 distinct asset ids → 1,418+6 assets from 2026-10-29 + 1 takeout motion video), two-midnight error-burst distribution. NOT verified: what sent the ML worker its SIGINT at Nov 16 00:05:44 (row queued), whether the 2 videos and the preview-less straggler decode after a force-run, the 2,009-vs-2,007 window-count delta (row queued), CI verdict on this session's commits (unpushed per no-push rule).

---

## a) FULLY DONE

1. **Resume verification** — all three arc commits intact (`13da09cfd`, `ed17352c9`, `2f9c7d05a`); both queued rows still open (overnight sessions closed OTHER takeout rows — the 5/5 batch, rename-loop wrapper, intake gate); foreign in-flight files (`takeout-intake.sh`, `selftests.nix`) identified and stood off; worked tree touches limited to my three files + the staging OWNER-STEPS.md.
2. **ML near-stall diagnosis — CLOSED with a definitive verdict** (the session's core, overturning the "~1 asset/hour" framing):
   - The takeout pending counts were FROZEN at faces=32 / ocr=34 / dup=32 — identical to the 15:17 measurements 42h earlier.
   - Globally, the last faces/OCR/dup completions were 2026-11-15 23:00:33 UTC (Nov 16 00:00:33 CET); **zero ML completions system-wide for ~41h** at measurement, with **zero ML-job error lines anywhere** — the jobs are not failing, they are not being dispatched.
   - The ML service is healthy (gunicorn on :3003, ping 10 ms), job concurrency non-zero (ocr 2, faceDetection 3), both systemd units active; a server restart today 15:12 (parallel session's deploy) bootstrapped cleanly and **did not re-seed the queues** (35 min post-restart: still zero).
   - This Immich v3.3.6 schema has NO pg_boss/job tables — the queues are in-memory; a lost backlog is not re-scanned from `asset_job_status` NULLs. Verdict: **in-memory queue backlog loss**.
   - The 37 stragglers = 35 Pixel motion-photo components (`.RAW-01.COVER.jpg` / `.RAW-02.ORIGINAL.dng`) + 2 motion videos. NOT video-transcode-bound, NOT the CRC-corruption class (magic bytes valid on 5 samples: JPEG `ffd8ffe1`, DNG `49492a00`, MP4 `0000001c`), and 2 of 3 sampled already have previews on disk — **dispatch loss, not decode failure**. Motion-photo components otherwise pass ML at scale (1,710/1,740 in-window ok).
   - The agent-side nudge does not exist: `/api/jobs` is admin-only and both on-box keys are non-admin (takeout-import 401, media-atlas 403). Remedy = 30-second owner force-run (admin UI → Jobs → start Face Detection + OCR + Duplicate Detection) — recorded in the staging OWNER-STEPS.md and the watch row.
3. **Annotate-13:31 landed** — three inline `[ANNOTATED 2026-11-17]` markers: §a8 full form (mechanism correction: error-on-response/commit-on-server/dup-on-rescan, net 2,004/2,004 identical), §g.2 full form (premise reshaped: all 243 Drive photos already in Immich; live question is Immich-only vs ALSO-G4), §f.3 pointer form (same stale premise); both account rows (TODO_LIST + services.md) re-phrased to "already in Immich — Immich-only vs ALSO-G4". Row ticked on both surfaces.
4. **New failure class surfaced and queued** — 1,425 distinct assets fail `AssetGenerateThumbnails` with "Input file contains unsupported image format" in nightly midnight bursts (verified at BOTH Nov 16 00:00:03-20 and Nov 17 00:00:03-06; 2,850 handler-error lines over the window); postgres join: 1,418 IMAGE + 6 VIDEO from a **2026-10-29 import** + 1 takeout motion video. The same population carries the ~1,456 pre-existing faces/OCR/dup pendings (same queue-loss mechanism). Pre-dates the takeout entirely. Row queued on both surfaces.
5. **Staging OWNER-STEPS.md** — new "30-second owner step" section for the force-run, placed above the racedriver8k section.
6. **All of the above landed in git** — daemon race split the delivery (see d6): `9d8128e62` (daemon, carried the report annotations + services.md alongside a foreign planning doc) + `99d012bb7` (mine, TODO_LIST). Content grep-verified at HEAD after both (3 markers, 7+8 DONE/DIAGNOSED matches, both new rows, both account-row rephrases present exactly once per surface).

## b) PARTIALLY DONE

1. **ML tail resolution** — diagnosed and the remedy recorded, but the force-run itself is owner-gated; the watch row stays open until the 37 stragglers are verified drained (post-force-run probe: the same psql pending-count query).
2. **Queue-stop root cause** — the stop TIME (00:00:33 CET), the nearest event (gunicorn ML worker graceful recycle 00:05:44), and the non-re-seeding are established; WHAT sent the SIGINT and whether it is causal or coincident is NOT (row queued this session, §f6).
3. **CI verdict on this session's commits** — `99d012bb7` et al. are unpushed per the no-push rule; no CI signal exists for them (and master CI is red on foreign causes anyway).

## c) NOT STARTED

1. **G4 (Drive → OpenCloud)** — owner-gated; input shape depends on the 243-photos decision (Q4/§f4).
2. **G5 (Docs → Paperless)** — owner-gated.
3. **racedriver8k browser clicks** — owner-gated; **~11.5h left** at report time (expires 2026-11-18 03:13).
4. **immich.md runbook documentation** of the queue-loss failure mode + the postgres probe set that diagnoses it (row queued this session, §f7).
5. **Takeout-window count delta explanation** (2,009 vs 2,007; row queued, §f8).

## d) TOTALLY FUCKED UP (caught, repaired, owned)

1. **The "CRC-corruption class" hypothesis was WRONG and nearly shipped.** The stragglers' names (motion-photo components, the takeout's known CRC class was adjacent in recent commits) made the attribution feel right; the magic-byte probe overturned it — all sampled files are structurally valid. Corrected before any row text carried it. Lesson: name-class similarity is not evidence.
2. **~6h of stale-clock work.** The session's first `date` read 09:14; the session then idled and resumed ~15:12 — and I kept working with the 09:14 clock implicitly in hand until journal timestamps "contradicted" it. The racedriver8k urgency was understated by ~6h in my interim reasoning (caught before anything shipped). The briefing's "run `date` FIRST on resume" needs to apply to EVERY resume boundary, not just session start.
3. **The prior reports' "videos last" framing was wrong** — 35 of 37 stragglers are images. Inherited assumption, corrected by the type breakdown.
4. **Causal-adjacency overreach (caught mid-draft)** — I initially leaned on "the worker recycle killed the queue"; only temporal adjacency is proven (last completion 00:00:33, recycle 00:05:44, 5 min apart). The shipped row text says "backlog was lost" without attributing the trigger; the root-cause row (§f6) owns the open question.
5. **Four harness stumbles, each caught in the same call or the next:** a psql CTE that does not persist across statements (relation-not-found); an unclosed shell quote that killed a probe loop; `VAR=x python3` passing an argv not an env var; the edit tool's mtime-drift hard-fail on services.md (fresh view-tool read fixed it — the documented trap, hit exactly as briefed).
6. **Daemon race split my commit again** — the pre-commit hook ran long, the daemon committed 2 of my 3 files (plus a foreign planning doc) as `9d8128e62` before my `99d012bb7` landed with the third. An amend-forward would have absorbed the foreign file (the 2026-11-15 fragmentation trap) — left split, grep-verified content instead. Correct per policy, but the split delivery cost a verification pass.

## e) WHAT WE SHOULD IMPROVE

1. **Re-run `date` at every turn boundary in deadline-watch sessions** (d2) — cheap, and the alternative is a 6h-blind urgency math.
2. **Explain count deltas before shipping rows** — I measured 2,009 window assets vs the watch row's 2,007 and hand-waved "close enough"; one GROUP BY settles it and the row now carries an unexplained 2-asset shadow (queued).
3. **Verify assumed distributions at capture time** — the "Nov 16 midnight twin" of the error storm was assumed from the Nov 17 tail and only verified for this report (both confirmed; had it not been, the shipped row text would have been wrong).
4. **Separate temporal adjacency from causation explicitly in verdicts** — the diagnosis text now models this (verdict = loss; trigger = unknown/queued), keep the discipline.
5. **Codify the Immich ML probe set** — three cheap psql queries (max per-job timestamps; since-restart completion filters; pending-by-type/filename) found in minutes what two prior reports' "watch the tail" could not; they belong in the runbook with the queue-loss failure mode (row queued).

## f) Top things next (ranked)

1. **[owner, ~11.5h] racedriver8k browser clicks** before 2026-11-18 03:13 (steps: staging OWNER-STEPS.md) — or decide expiry → re-request posture.
2. **[owner, 30 s] Immich admin UI → Jobs → start Face Detection + OCR + Duplicate Detection** (OWNER-STEPS.md new section) — drains the 37 stragglers.
3. **[owner, standing] The 22 upgrade pairs** — keep both / UI review / one-time supervised delete window.
4. **[owner, standing] 243 Drive photos** — Immich-only (current plan shape) or ALSO through G4.
5. **[queued this session]** Diagnose the Oct-29 thumbnail-failure population (1,425 assets; nightly error storm; ~1,456 ML pendings ride on it).
6. **[queued this session]** Root-cause the ML queue-stop trigger (Nov 16 00:00-00:06: SIGINT source; logrotate/deploy/gunicorn correlation).
7. **[queued this session]** immich.md runbook: queue-loss failure mode + postgres probe set + force-run remedy + key-scope matrix cross-ref.
8. **[queued this session]** Explain the 2,009-vs-2,007 takeout-window count delta; correct the watch row figure at close.
9. **[tracked, watch row]** After the force-run: verify the 37 stragglers drain (same psql pending query), then close the ML-tail watch row.
10. **[tracked]** Probe-permission matrix row for immich.md (services.md:1190) — this session added two more data points (media-atlas 403, /api/queues routes exist).
11. **[standing]** Push this session's commits when permitted; collect CI verdicts.
12. **[standing]** Keep-cycle-2 reminder (~2027-01, owner-gated channel).
13. **[foreign]** CI red on master (audiblesync ssh:// fetch, store-path-invalid, VM tests, syn_cb0b scan gap) — owning sessions' domain; do not chase.
14. **[standing]** G4 input shape (new-files.txt) final depends on item 4.

Self-harvest note: §f items 5-8 are NEW direct follow-ups of this report — rows 6, 7, 8 land in TODO_LIST.md + docs/todo/services.md at authoring time (item 5 was already queued during the session, both surfaces); items 9-14 were already tracked elsewhere or are owner/foreign-gated and are deliberately not re-queued.

## g) Questions I cannot answer myself (top 3)

1. **racedriver8k (expires 2026-11-18 03:13, ~11.5h):** are you clicking the 23 links tonight, or should the fleet flip to expired-and-re-request posture? Only you can pass the rart wall; the decision re-scores every `[blocked:user]` row on that account.
2. **Will you run the 30-second Immich Jobs start (Face Detection / OCR / Duplicate Detection)?** And separately: should an admin-scoped API key ever be provisioned for agent-side queue nudges, or is job control deliberately owner-only? (Both current keys are non-admin; I did not attempt to create one.)
3. **The 22 upgrade pairs (standing since the 13:31 report):** keep both, owner UI review, or a one-time supervised delete window? The importer stays `asset.delete`-less either way.
