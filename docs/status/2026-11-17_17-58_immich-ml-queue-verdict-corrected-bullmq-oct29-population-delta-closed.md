# Immich ML queue verdict corrected (BullMQ drained, not in-memory loss), Oct-29 population root-caused, delta closed — evening session

**Session:** 2026-11-17 17:45 → 17:58 CET. Scope: the resumption briefing's ready rows (queue-stop root cause, Oct-29 thumbnail population, runbook codification, count delta) after the owner's "execute the steps" directive. No owner-gated actions touched (force-run, deletes, G4/G5, keys). Standing constraints honored: capture-once journal pulls (live IO storm, avg300 ~70%), no heavy evals, foreign files stood off.

**Scope line (verified vs not):** VERIFIED first-hand: ML live state (pendings still 32/34/32, global max timestamps still Nov 15 23:00:33 UTC — no force-run yet, 0 completions since the 15:12 restart); the BullMQ queue architecture (error stack traces reference bullmq@5.81.5; redis 127.0.0.1:6379 holds `immich_bull:*`, 57 keys); event-stream tails for 5 queues + id counters + failed zsets + the one surviving job hash; the midnight window journals (server 17,191 lines captured once, PID1 1,125 lines, ML unit); logrotate timing; ML worker recycle history since Nov 10; the Oct-29 population identity (11,647 discordsync external-library assets, one 184 ms burst 2026-10-29 23:00:05 UTC; nightly-scan cadence proven by the 2 Nov-15 strays); magic bytes + HTML titles of 16 sampled failing files (RedGifs "Blocked", redd.it "Domain Blocked", 2× ID3-MP3-as-.mpeg, ftypdash/ftypisom MP4s); the window-count delta (GROUP BY originalPath: 2,005 uploads + 2 encodes + 2 discordsync = 2,009); straggler previews/visibility (timeline + preview files present); the v3.3.6 source chain for the sweep remedy (queue.service.start → `AssetDetectFacesQueueAll{force}` → NULL-streams with preview/visibility filters). NOT verified: whether the takeout 32's upload-time enqueues were skipped or lost pre-midnight (no journal/queue evidence survives either way — the sweep covers them regardless); post-force-run drain (owner step not yet run); CI verdict on this session's commits (unpushed per no-push rule).

## a) FULLY DONE

1. **Queue-stop root cause — CLOSED, verdict CORRECTED: nothing stopped; the queues DRAINED** — every ML queue's BullMQ event tail is `completed` → `drained` at 23:00:30/33/35 UTC Nov 15 (matching the DB max timestamps to the second); zero jobs added since 23:00:23 UTC (faceDetection id counter frozen at 17197); Redis never restarted/flushed (3.3.3-era keys intact). The 00:05:44 worker SIGINT is a ROUTINE post-midnight-burst recycle (same ~00:05:1x pattern Nov 10 + Nov 14). The 15:36 report's "in-memory queue backlog loss" was wrong on mechanism: queues are BullMQ-on-Redis; the pendings were NEVER enqueued (preview gates) — nothing was lost from a live queue.
2. **Oct-29 thumbnail-failure population — CLOSED** — the import is the discordsync external library's bulk scan (11,647 attachments, 184 ms burst); the 1,425 failing "assets" are HTML block pages (RedGifs/redd.it) the discord fetcher saved under advertised .jpg/.png names, plus 4 MP3s-as-.mpeg and 2-3 dash MP4s. Immich's decoder correctly rejects them; the nightly 00:00 CET storm is the library scan re-queueing preview-less assets (expected while they exist). Cleanup decision queued as [blocked:user] (delete / fix fetcher / accept noise).
3. **Remedy source-verified** — admin Jobs START → `queue.service.start()` → QueueAll sweeps re-enqueue exactly the `asset_job_status` NULLs (force=false filters to preview-bearing + visible assets — sufficient for the takeout 32/34/32; force=true would also drag the 1,425 broken files). OWNER-STEPS.md updated with corrected mechanism + expectations (the ~1,456 discordsync pendings will NOT drain on a plain start — by design).
4. **Runbook codified** — two bullets in docs/services/immich.md: "Job queues are BullMQ-on-Redis" (failure mode + sweep semantics + restart-never-reseeds, with supersedes note) and "Queue/ML probe set" (psql/redis-cli/journal probes, gotchas, noise baselines, key-scope verdicts). Also closed the older probe-permission-matrix row (folded in).
5. **Count delta — CLOSED** — 2,009 window = 2,005 takeout uploads + 2 immich-generated motion-video encodes (the watch row's 2,007 = takeout proper) + 2 discordsync scan strays; the later 2,008 reading is JOIN lossiness (one encode lacks an asset_job_status row), not a deletion. Corrected figure shipped into the watch row.
6. **All four queued rows ticked on both surfaces** + the prior session's wrong verdict corrected on every surface that carried it (15:36 report: 2 ANNOTATED markers; ticked diagnosis rows in TODO_LIST + services.md; watch row's DIAGNOSED note extended with CORRECTED).

## b) PARTIALLY DONE

1. **ML tail resolution** — the remedy is now source-verified and expectations are set, but the force-run itself remains owner-gated; the watch row stays open for the post-run drain probe (32→0 faces/ocr/dup scoped to the takeout window).
2. **The takeout 32's enqueue miss** — established that they have previews + timeline visibility (a non-forced sweep WOULD pick them up; none ever ran), but WHY their upload-time per-asset jobs never enqueued is not recoverable from surviving evidence; documented honestly rather than invented.

## c) NOT STARTED

1. Owner-gated everything: the Jobs force-run, the discordsync cleanup decision, racedriver8k browser clicks, G4/G5, admin-key provisioning, the 22 upgrade pairs, the 243-Drive-photos G4-shape question.

## d) TOTALLY FUCKED UP (brutal)

1. **Schema guessing before schema discovery** — two failed psql round-trips (`assets` → singular `asset`; `deviceId` → gone in v3.3) before the obvious information_schema query. First-principles rule violated: discover, don't recall.
2. **The id-list quoting fight** — `paste -sd"','"` (paste cycles -d characters — wrong tool semantics), then a printf/argv-mangled IN-list, then a GROUP BY 1 label bug; three avoidable round-trips before the scratch-file + `string_to_array` form that the runuser-can't-read-homes rule already pointed at.
3. **Guard-assumption drift** — assumed SUDO_OK ⇒ systemctl readable; this session's yolo guard blocks statically-dangerous names anyway. Recovered via the repo module grep, but the assumption was untested.

## e) WHAT WE SHOULD IMPROVE

1. For unknown DB schemas: information_schema FIRST, one round-trip, then business queries.
2. For >100-id SQL sets: scratch file + stdin pipe is the canonical form here (postgres user cannot read user homes; argv quoting is a trap) — now proven twice.
3. Queue telemetry beats process forensics: one `XREVRANGE` per queue settled in seconds what two sessions of journal/DB correlation could not — when a system has an event log, read the event log first.

## f) NEXT

1. **[owner-gated verify]** After the owner runs the Jobs START (3 queues, plain, NOT force): re-run the window pending query (expect 32→0/34→0/32→0), then close the watch row (services.md, the [watch] ML-tail row) with the corrected window figure (2,007 takeout proper).
2. **[blocked:user]** discordsync cleanup decision (new row, services.md): delete the 1,425 bogus files + assets / fix the fetcher's content-type validation / accept the nightly noise.
3. **[carried]** racedriver8k browser clicks — expires 2026-11-18 03:13 CET (~9h left at session end); past it, the posture question (re-request) becomes live.
4. **[carried, owner]** 22 upgrade pairs; 243 Drive photos Immich-only vs ALSO-G4 (G4's input shape depends on it).

Self-harvest note: item 1 is the existing watch row's verification leg (not re-queued); item 2 IS the new [blocked:user] row (queued this session, services.md); items 3-4 are owner questions already tracked in staging OWNER-STEPS.md / prior reports — deliberately not re-queued.

## g) Questions I can NOT figure out myself

1. **Will you run the 30-second Jobs START?** (immich.home.lan → Administration → Jobs → start Face Detection, OCR, Duplicate Detection — plain start; do NOT force.) It is the only path to drain the takeout ML tail; expectations are written in the staging OWNER-STEPS.md.
2. **discordsync cleanup (new):** delete the 1,425 HTML-garbage files + their Immich assets (agent-executable once you say go — the delete path needs a supervised window since no key carries `asset.delete`), fix the fetcher upstream, or accept the nightly retry storm?
3. **racedriver8k (carried, deadline 03:13 CET tonight):** browser clicks now, or flip to expired-and-re-request?
4. **Carried:** the 22 upgrade pairs (keep both / UI review / supervised delete window?) and the 243 Drive photos (Immich-only vs ALSO-G4 — G4's input shape waits on this).

---

*Reported 2026-11-17 17:58 CET. Commits local-only per no-push rule. Waiting for instructions on all owner-gated items.*
