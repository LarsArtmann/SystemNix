# Scanner campaign: silent watch death, loop hardening, staging reclaim (2026-10-19 11:13 CEST)

**Scope of this report:** the session that started with "The scanner is scanning nothing......." — i.e. the diagnosis of the dead watch loop, the wrapper hardening that came out of it, the two documents it ingested while I worked, the staging reclaim, and the late discovery of an unreadable file that had been stuck in the consume directory for 2 h 21 min. Everything below is evidence-backed from this session's live probes; items I did not verify are labelled as such.

**Format note (skill override):** the `status-report` skill mandates a styled HTML dashboard; the request named `docs/status/<YYYY-MM-DD_HH-MM_WELL-NAMED>.md`, so this report is Markdown per the explicit instruction. Flagged, not silently propagated.

| Field | Value |
| --- | --- |
| Report time | 2026-10-19 11:13 CEST (Monday) |
| Host / repo | evo-x2, `/home/lars/projects/SystemNix` (flake, master) |
| Session trigger | user: "The scanner is scanning nothing......." |
| Prior report | `docs/status/2026-10-19_09-44_scanner-campaign-live-instrumentation-and-integrity-corrections.md` |
| Watcher PID | 1250077 (`bash ./scripts/scan-to-paperless.sh watch`, started 10:59:35) |
| Docs ingested today | 59 (ids 1000436 → 1000494; one more in flight from the 11:13 sheet) |
| Session commits | `147dac81f`, `8b2e88658`, `a2b8d477b`, `7ff334590`, `21f807c4e` (all daemon-swept, heuristic messages) |

---

## a) FULLY DONE

1. **Root cause of "the scanner is scanning nothing" found and fixed.** The watch process died at **10:01:36** because `deliver_out()` called `die` on a failed `cp`, and `die` is an explicit `exit 1` — so a transient conversion/copy failure terminated the whole daemon. Paper fed for the following 50 min went nowhere. Evidence: `watch.log` last lines before the gap (`ERROR: failed copying doc-20261019-093207-01.pdf into consume`), then no log output until the 10:59:35 restart.
2. **The trigger of that failure was a USB drop-off, not the copy.** Kernel: `usb 6-1: USB disconnect, device number 11` at **10:01:36**; `scanimage` blocked in the kernel from 09:32 → 10:01 (29 min), `timeout` returned **rc=124**, and the single staged frame was a **31-byte header-only PNM** (`frame-0001.pnm`), which `magick` refused (`negative or zero image size`). Device reappeared only on a physical replug at **10:50:42** (`new SuperSpeed USB device number 13`, `Product: ADS-1800W`, serial `E83229M4X114379`).
3. **The batch path can no longer exit the process.** `fail()` (reports, returns 0) replaced every in-loop `die`; explicit `return 1` marks failure; only pre-flight errors (missing dependency, missing consume dir, bad args, STAGING outside `$HOME/.cache`) still `die`. `scripts/scan-to-paperless.sh` (434 lines) — commit `147dac81f` (186 insertions / 29 deletions), extended by `8b2e88658`.
4. **Truncated frames are trimmed, not fed to ImageMagick.** `verify_frames()` keeps the longest valid prefix (magic `P6` **and** size > 1024 B — a real 300 dpi smallest-doc frame measures 25.6 MB) and drops the rest as suspect, so a stalled 20-sheet load still delivers the sheets that did scan. First unusable frame breaks the loop by design (everything after it is suspect).
5. **Every produced document is verified before it reaches consume.** `verify_product()` asserts non-empty, magic is not `P6` (the mime Paperless rejects), and for PDFs that `grep -a -o "/Count [0-9]*"` equals the expected page count — **2** per duplex sheet, **1** for the odd-frame fallback. Calibrated on live data before shipping: all **47** staged products read `/Count 2`, a synthetic 1-image PDF reads `/Count 1`, so the assert has teeth without `ghostscript` (still absent).
6. **rc=124 (timeout) has its own branch.** It names the timeout, probes `scanimage -L`, then tells the operator either "still on the bus — check the ADF" or "GONE from the bus — unplug/replug the USB cable", drops the batch and keeps polling after 10 s. `timeout -k 20 300` also escalates TERM→KILL.
7. **Staging has a lifecycle; 2.5 GB reclaimed on first run.** Each batch dir is removed the moment it is done with (the **1014** empty idle-poll dirs were the real bloat), delivered products leave `out/`, and startup sweeps anything older than `STALE_MIN=60` min. Live: `gc: reclaimed 1014 stale raw batch dir(s)` + `gc: removed 47 stale staged product(s)` (10:59:35) → `raw` 2.0 GB → 8.0 KB, `out` 467 MB / 47 files → 0 files.
8. **A 2 h 21 min stuck file was found and unstuck.** `/mnt/pool/services/paperless/consume/signal-2026-10-01-06-25-30-372_002.jpg` was mode **600** `lars:paperless` — the consumer runs as another user, so it was skipped silently and forever (no journal line for it all morning). `chmod 0644` → ingested as doc **1000493** in 10 s; the wrapper now `chmod 0644`s every delivery so it cannot recur from its own path.
9. **Live end-to-end proof after the fix.** Watcher restarted 10:59:35; picked up the sheet already sitting in the ADF in **4 s** (10:59:39 capture → 10:59:42 delivered → doc **1000494**), then a second sheet at **11:13:40** (→ `doc-20261019-111336-01.pdf`, 8.6 MB, in consume and being consumed at report time). Post-restart window contains **zero** WARN/rc=4 lines; `idle: ADF empty rc=7` streak advancing normally (#151 at 11:12:40).
10. **rc=4 semantics corrected in machine output.** The old watcher's WARN asserted the unverified cause ("half-seated sheets flap the sensor"); the loop now states the observation ("paper at the feeder with the pick rollers not yet engaged — push the sheet in until it stops") and that reading is in the script header too.
11. **Runbook brought current.** `docs/services/scanner.md` (72 lines) gained a "Watch durability & staging lifecycle (2026-10-19 10:01 incident)" section (the death chain, every guard, the restart recipe, the unbounded device-hang caveat), the per-file readability trap as consume-write-path layer 3, and the corrected rc=4 paragraph. Commit `8b2e88658`.
12. **CHANGELOG + FEATURES updated** in the same commit: a new top CHANGELOG entry (silent 50-min death, guards, 2.5 GB reclaim, live verification) and the scanner row now states the durability/verification/GC/permission capabilities.
13. **Queue and library kept in sync, verified.** Three rows closed as DONE in `docs/todo/services.md` (staging GC, PDF verification, rc=4 wording) and pruned from `TODO_LIST.md`; ~20 rows added/updated across `TODO_LIST.md`, `docs/todo/{services,monitoring,storage}.md`. `scripts/check-todo-system.sh` → `OK: TODO queue/library structure clean`; `scripts/check-doc-links.sh` → `OK: no broken relative links or anchors`. Commits `a2b8d477b`, `7ff334590`, `21f807c4e`.
14. **Two deferred campaign reports harvested** (the "WAIT FOR INSTRUCTIONS" deferral expired when the campaign resumed): `docs/status/2026-10-19_02-16_brother-ads1800w-paperless-intake-status.md` (38 items) and `docs/status/2026-10-19_07-23_scanner-consume-pipeline-status.md` (25 items) each got an inline dated triage block — done / answered / harvested-now / deliberately-not-harvested-with-reason. Effect on the checker: unharvested §f reports 70 → 68. Commit `21f807c4e`.
15. **Lint clean on the changed script, run standalone** (the daemon bypasses pre-commit legs): `bash -n` + `nix develop . -c shellcheck scripts/scan-to-paperless.sh` both green.
16. **Live metric facts captured for the campaign's benefit** (not previously reported anywhere): `paperless_tasks_failed_unack_total 75` (train_classifier 31 / llm_index 22 / consume_file 15 / bulk_update 4 / sanity_check 3) and `paperless_llmindex_last_success_age_seconds 1673701` (≈19 d) — harvested as rows, see (d).

---

## b) PARTIALLY DONE

1. **The watcher is still not a systemd unit.** It is a detached `setsid nohup` user process: survives logout, dies on reboot, no journal integration, unbounded log (52 KB and growing), and — the point — **no automatic restart and no alert if it exits**. The in-process guards now make the specific 10:01 death impossible, but any *other* unexpected exit is equally invisible. Remaining: unit + `Restart=always` + rotation + a signal. (M — the script work is done; the unit shape is the rest.)
2. **Delivery-side permissions are guarded only on the wrapper's own path.** I fixed the instance (chmod on the stuck file) and the wrapper's delivery, but the *producer* that wrote a mode-600 file into consume is untouched — a future manual copy or phone-photo drop can go silently stuck exactly the same way. A consume-dir-level guard (tmpfiles/path unit enforcing 0644, or a root `+` sweep) is still open. (S)
3. **Nothing alerts on that class or on ingest staleness.** No Gatus check, textfile collector, or rule covers consume depth/age, so the 2 h 21 min stuck file was invisible; likewise the 75 unacknowledged FAILED tasks sat unread. Both need a probe + route to a channel a human reads. (M)
4. **Page-count verification covers PDFs only.** `verify_product` checks non-PNM/non-empty for PNG products (receipts mode) but there is no equivalent structural check (e.g. dimensions) for them; receipts mode was not exercised at all in this session. (S)
5. **The rc explanation is unconditional.** My WARN appends "rc=4 = paper at the feeder with the pick rollers not yet engaged" to *every* non-4 code. Live counter-example in the old log: three failures at 09:04:28–09:04:35 with **rc=6** (SANE `JAMMED`) were labelled with the rc=4 explanation. I inherited the flaw and did not fix it. (S)
6. **Docs refresh is a remainder, not complete.** Still missing from `scanner.md`: the blank-face reorder rule, the USB-stability evidence (two enumerations this boot, `power/control=on`), the bad-scan protocol (delete in UI → re-feed; a re-scan is never byte-identical so dedup will NOT catch it), and the physical-storage doctrine. (S)
7. **The campaign's own corpus curation is untouched.** Today's ~59 test documents (checklists, KBA, Biedronka, Signal photo, the reordered-before-fix ones) are in Paperless as-is — keep/merge/delete and the deletion of the bad scans is still pending, and it is the prerequisite for a clean training run. (M)
8. **The numbering/ASN layer is designed but unstarted** — and still blocked on three owner answers (see (g)). (L)
9. **bank-sync-paperless is still undiagnosed** (every upload rejected `rejection:paperless.client_error`; the token mint succeeds on restart, the main unit logs nothing further). Not touched this session. (M)
10. **`nix flake check` was not run this session.** No `.nix` file changed (script + docs only) and `check-todo-system.sh`/`check-doc-links.sh` were green, but the repo's own eval gate was not exercised after these edits. (S)

---

## c) NOT STARTED

1. **Watch as a systemd unit** — designed in the queue row, no file written.
2. **Consume-dir readability enforcement** at the directory level.
3. **Consume-dir staleness/depth alerting** (Gatus or textfile + rule).
4. **Wrapper selftest/fixture** — no automated test exists for the guards I just wrote (truncated frame, `/Count` mismatch, deliver failure, rc=124). The repo has both a selftest and a negative-test harness; neither covers this script.
5. **Operator feedback channel** — desktop notification (or equivalent) on "delivered doc → id" / "device gone, replug" / "batch failed". Today the only signal is a log line the operator must go read, which is exactly how 50 min of paper vanished.
6. **Ingest-confirmation loop** (delivered → parse doc id from the journal → ledger → only then clean staging).
7. **Numbering ledger + ASN patching + sorting dashboard** — blocked, see (g).
8. **OCR language evaluation (`pol`)** for the Polish receipt share.
9. **Training milestone** (correspondents/tags → AUTO → Train Classifier) plus the cleanup of the 31-deep `train_classifier` failure backlog it depends on.
10. **First-batch content checks**: `DATE_ORDER=DMY` date extraction on real receipts, FLM classification sanity on short no-correspondent receipts.
11. **Post-campaign storage watch** (exporter + restic windows; media growth ≈ 18 GB at the current profile).
12. **Scanner docs: bad-scan protocol + physical-storage doctrine** (accession order, range-labeled boxes, thermal decay).
13. **Carrier Sheet decision**, **PIXMA provenance check**, **transport decision record** (USB vs WiFi) — all queued, none acted on.
14. **USB-drop-off recovery unit** (root-side rebind/authorized toggle) — only if it recurs.
15. **Camera-based fallback for sub-minimum slips** (a phone photo into consume) — informal practice, never formalized.

---

## d) TOTALLY FUCKED UP

1. **A copy failure killed the scanner daemon and nothing noticed for 50 minutes.** Severity: blocked the entire campaign (the user's own words: "the scanner is scanning nothing"). Root cause: `die` (explicit `exit 1`) inside the watch loop's delivery function — a logical error in a script I wrote earlier the same morning, i.e. my own defect, caught only because the operator was watching. Mitigation shipped; the durable mitigation (restart + alert) is still not in place. **This is the single most important lesson of the session: a long-running loop must not have any exit path, and a long-running loop must be supervised by something that restarts it.**
2. **A wrong "causes" string was promoted into the operator-facing log** (the rc=4 explanation) and, worse, it was attached to codes that were not 4 — the live log shows three `rc=6` JAMMED failures at 09:04 printed with the rc=4 cure. Severity: misleads the operator during exactly the physical-fault moment when they need the right instruction. Root cause: inherited unconditional wording; the fix (branch on the code) is one line and still open.
3. **A file sat unread in the consume directory for 2 h 21 min and NOTHING reported it.** Severity: silent document loss (the scan existed, was believed filed, and was invisible to every check). Root cause: mode 600 written by a producer that is not the wrapper, consumed by a different user, with no staleness probe on the directory. The instance is fixed; the class is not.
4. **The collector claims the RAG index is 19 days dark while the task log shows 39 successes this morning.** Severity: an alert driving off a wrong number is a phantom-metric bug — either a false "RAG dark" page or a false green. Root cause unknown — the query behind `paperless_llmindex_last_success_age_seconds` was never validated against the live DB. Not fixed.
5. **75 unacknowledged FAILED paperless tasks, 31 of them `train_classifier`.** Severity: the training milestone — the thing that makes the 2000-doc corpus self-sorting — starts from a failure backlog, and no human was ever told these existed. Root cause: the metric is collected but not routed to anything a person reads (or is routed somewhere ignored). Not fixed.
6. **The wrapper verified its inputs and never its outputs — until this session.** Severity: silent corruption class (a truncated frame produced an error, but a structurally wrong PDF would have shipped). Root cause: I wrote a verifier for frames and assumed the converter was infallible. Fixed now for PDFs, half-fixed for PNGs.
7. **The staging directory grew to 2.5 GB in ~2 h because the loop created a directory per poll and removed none.** 1014 of 1015 directories were empty idle-poll artifacts. Severity: unbounded growth on a long campaign (a multi-day run would have consumed the cache filesystem). Fixed; first run reclaimed it all.
8. **Nothing here was tested by an automated test.** All eight defects were found by a human noticing or by me reading logs. The repo has a selftest harness and a negative-test harness; this script has neither. That is the structural failure behind all the others.

---

## e) WHAT WE SHOULD IMPROVE

1. **Long-running loops need a supervision contract, not just better error handling.** Concretely: every daemon-shaped script in `scripts/` should be either a systemd unit with `Restart=always` or explicitly documented as interactive-only. The 10:01 death cost ~50 min of operator time that a `Restart=on-failure` would have cost 2 s of. (Impact: high; fix: convert.)
2. **Never let a loop's "give up" path be `exit`.** Adopt as a review rule for this repo: inside any `while true` loop, `die`/`exit` is forbidden; failure helpers must report and return. My guards now do this; the rule is not written anywhere.
3. **Verify the artifact, not the pipeline stage you control.** The frame check felt like verification and proved nothing about the output. Adopt: for every producer script, assert one property of the *delivered artifact* (magic bytes, page count, row count) before claiming success.
4. **Machine output states observations; theories go to prose.** This is the second appearance of the same failure (the previous report flagged it for rc=4, and I still shipped an unconditional cause string). Make it a lint-able habit: no causal claim in a log line without a live probe in the same session.
5. **A file in a watched directory is not ingested until the consumer says so.** "Delivered" and "consumed" are different states; the ledger loop (doc-id confirmation) is the general fix, and the permission chmod is the narrow one.
6. **Silence is the enemy signal.** Three separate silent failures this session (dead loop, stuck file, unread FAILED backlog). Every one of them was detectable by a probe that does not exist. Prefer adding a probe over adding a feature.
7. **Staging discipline by construction:** create-on-demand, delete-on-use, and a startup sweep — never "we'll clean it later". The `mktemp -d` per poll was the mistake; the fix was not "GC harder" but "don't accumulate".
8. **Directory-level permissions are a producer contract.** If several producers write into one consumed directory, enforce the mode on the directory (setgid + default ACL) rather than trusting each producer.
9. **Stop inheriting wording you have not verified** — the rc=6/rc=4 mislabel came from a previous session's text that I copied forward without checking the codes' mapping. Cheap check, real cost when wrong.
10. **Do not let a status report's deferral outlive its condition.** Two reports carried "deliberately deferred pending WAIT FOR INSTRUCTIONS" for 63 items, and the condition expired when the campaign resumed; the deferral note was never re-read. (Impact: harvest debt; fix: annotate at the moment the condition changes.)
11. **The metric-to-human path needs an owner.** The collector emits 75 failures and a 19-day "RAG dark" — one of them is wrong and nobody is paged. Assign per-metric ownership or delete the metric.
12. **Carry a "physical vs software" distinction in the runbook.** The rc=4 storm (66 consecutive retries at 08:42) was physical seating, not a code fault; operators triage faster with a one-page physical checklist than with log reading.

---

## f) Up to 50 things to get done next

Legend: **Impact** C/H/M/L · **Effort** S/M/L · **Category** Bug/Feature/Quality/Cleanup/Docs. Ticked items are **already queued** (queue row + domain library), so harvesting them again would duplicate; the un-ticked ones are the direct follow-ups of this report and are harvested at the end of it.

**Immediate (unblocks the campaign today)**

1. ☐ **Make the rc explanation conditional on the actual code** — `rc=4` gets the pick-roller text, `rc=6` gets "jammed: open the ADF and clear the sheet", everything else gets the raw stderr line only. · C · S · Bug *(new)*
2. ☐ **Surface watch events to the operator (desktop notification)** — delivered (with doc name), batch failed, device gone/replug needed. The only current signal is a log line, which is precisely how 50 min of paper disappeared. · C · S · Feature *(new)*
3. ☑ **Systemd unit for the watch** (`Restart=always`, journal, boot start, log rotation) — already queued; priority raised this session. · C · M · Quality
4. ☑ **Consume-dir readability guard for non-wrapper producers** (tmpfiles/path-unit mode enforcement). · H · S · Bug
5. ☑ **Alert on consume-dir depth/staleness** (>15 min = red). · H · S · Feature
6. ☑ **Triage the 75 unacknowledged FAILED tasks** (train_classifier 31 first). · H · M · Cleanup
7. ☑ **Verify/compose the `paperless_llmindex_last_success_age_seconds` query** (19 d vs 39 successes today). · H · S · Bug
8. ☑ **Wire the FAILED-backlog metric to a channel that gets read.** · H · S · Feature

**This session's guards need tests (structural)**

9. ☐ **Write a fixture/selftest for the wrapper's guards** — stub `scanimage`, feed a truncated PNM, assert the batch is trimmed and delivered; assert a `/Count` mismatch blocks delivery; assert a copy failure does **not** end the loop (run the loop for 3 iterations and exit 0). Modelled on `scripts/negative-test-lints.sh` + the `CASES=` harness convention. · H · M · Quality *(new)*
10. ☐ **Add the wrapper to `shellcheck`/pre-commit coverage explicitly** rather than relying on the standalone run, given the daemon bypasses staged-path legs. · M · S · Quality *(new — plausibly covered by the existing "standalone lint re-run for daemon-swept files" row; verify before creating a row)*
11. ☑ **Ingest-confirmation loop** (delivered → doc id from journal → ledger → then clean staging). · H · M · Feature
12. ☐ **Assert PNG products structurally in receipts mode** (dimensions > 0 via `magick identify`), matching the PDF `/Count` assert. · M · S · Quality *(new)*

**Paperless health found while working**

13. ☑ **Train-classifier milestone** + keep the hourly task green. · H · M · Feature
14. ☑ **First-batch date extraction (`DATE_ORDER=DMY`) + FLM classification sanity** on real receipts. · H · M · Quality
15. ☑ **Re-enable paperless-gpt-auto** after rebuilding its filter (`filter_has_tags=[Accounting]`). · M · M · Bug
16. ☑ **Post-restore SSO login round-trip** (auth_user restored, OIDC never exercised). · M · S · Quality
17. ☑ **Diagnose bank-sync-paperless** (`paperless.client_error` on every upload). · H · M · Bug
18. ☑ **Token-mint boot resilience** (mints fail against a degraded DB and stay failed for hours). · M · M · Quality
19. ☑ **`pol` in OCR_LANGUAGE** for the Polish corpus (check tesseract-pol + re-OCR cost first). · M · M · Feature
20. ☐ **Verify the `consume_file` failures individually** — 15 unacknowledged failures may be Wave-6 window artifacts and are the only ones that could indicate lost documents. · M · S · Cleanup *(new)*
21. ☐ **Sanity-check `paperless_inbox_count 336`** against the 59 docs ingested today — is the inbox tag being cleared on ingest, or is the campaign accumulating unprocessed backlog? · M · S · Quality *(new)*

**Evidence + docs**

22. ☑ **Scanner docs remainder** — blank-face reorder, USB-stability evidence, bad-scan protocol, physical-storage doctrine. · M · S · Docs
23. ☐ **Runbook: add the rc→code mapping table** (0/4/6/7/124 with the operator action for each). · H · S · Docs *(new)*
24. ☐ **Runbook: add the device-hang recovery procedure** (replug first, then `scanimage -L`; the wrapper's rc=124 branch prints the same decision tree). · M · S · Docs *(new — partially covered by row 22; keep separate because it is a procedure, not prose)*
25. ☐ **Runbook: record today's measured product size** (9.1 MB / 2-page sheet at 300 dpi colour; 8.6 MB for the 11:13 sheet) next to the throughput figures. · M · S · Docs *(new)*
26. ☑ **Carrier Sheet decision** for sub-50.8 × 70 mm slips. · L · S · Feature
27. ☑ **Transport decision record** (USB chosen, WiFi deferred). · L · S · Docs
28. ☑ **Canon PIXMA provenance check** in the networking.nix comment. · L · S · Docs
29. ☐ **Correct the "2.5 GB" figure in today's CHANGELOG/runbook if you prefer raw-vs-total framing** — CHANGELOG says "2.0 GB of raw frames + 467 MB of products"; the log says 1014 dirs / 2.0 GB used. · L · S · Docs *(new, nit)*

**Campaign operations**

30. ☑ **Curate today's ~59 test documents** (keep/merge/delete; remove the reordered-before-fix and bad scans) before training. · H · M · Cleanup *(this is the queued corpus-curation item; not yet started)*
31. ☑ **Scan-profile decision** (300 dpi colour vs True Gray, with the faint-thermal acceptance test). · H · S · Feature
32. ☑ **Post-campaign exporter/restic/media-growth watch**. · M · S · Quality
33. ☐ **Decide the raw-frame retention policy** — GC now deletes PNM frames 60 min after use; if they are evidence (or a re-convert opportunity), they need an archival path instead. · M · S · Quality *(new; also raised in (g))*
34. ☐ **Add a rescan/re-feed procedure for the campaign** (delete in UI → re-feed → hash dedup will NOT catch it) and put it on the memory-side of the runbook. · M · S · Docs *(new; overlaps row 22 — fold in there if you prefer fewer rows)*
35. ☐ **Instrument per-batch timing** (frames/sec + convert/deliver split) so throughput claims are measured, not estimated. · L · S · Quality *(new)*
36. ☐ **Batch-level manifest** (one JSON line per delivered doc: file, doc-id, frame count, blank flags, hash) as the ledger's substrate. · M · M · Feature *(new — the numbering layer will need it)*

**Infrastructure / robustness**

37. ☐ **Root-side USB recovery unit** for the drop-off class (rebind or authorized-toggle after the device vanishes), only if it recurs. · M · M · Feature *(new; the existing row is a `[watch]`, this is the candidate fix)*
38. ☐ **Log rotation** for `watch.log` (grows unbounded; 52 KB in 15 min of idle). Folded into row 3's unit, called out separately because it applies even before the unit exists. · M · S · Cleanup *(new)*
39. ☑ **Eval-time lint for chmod/chown in non-`+` preStarts of hardened units** (pipeline.md row from the 09-44 harvest). · M · M · Quality
40. ☐ **Generalize the "watched directory" probe**: any directory a consumer drains should have a staleness check — paperless consume is the first, but the same shape exists for the drive-paperless and inboxclean pipelines. · M · M · Quality *(new)*
41. ☐ **Audit for other loops in `scripts/` with an `exit` inside `while true`** — the 10:01 bug class is not unique to this script; a 5-minute grep-and-read pass would either clear the repo or find the next incident. · H · S · Quality *(new, cheap, high value)*
42. ☐ **Audit for other scripts that treat a `cp` failure as fatal** in a long-running context. · M · S · Quality *(new — same pass as 41)*

**Observability of the campaign itself**

43. ☐ **A "campaign dashboard" line** (docs scanned today, failures, staging size, last ingest) printed by `scan-to-paperless.sh status`, so the operator has one command instead of four. · M · S · Feature *(new)*
44. ☐ **Feed scan counts into the existing monitoring stack** (docs/hour) so a stall is visible on a graph rather than inferred. · L · M · Feature *(new)*

**Process**

45. ☐ **Write the "no exit inside a loop" review rule into the repo's contributor docs.** · M · S · Docs *(new)*
46. ☐ **Annotate the deferral-condition expiry** as a docs-health habit (the two reports' notes sat stale; see e.10). · M · S · Docs *(new)*
47. ☐ **Add the four this-session defects to the gotchas archive** (die-in-loop, unconditional rc cause string, mode-600 consume file, empty-dir accumulation) so they survive as narrative, not just as rows. · M · S · Docs *(new)*
48. ☐ **Ask the parallel Wave-6 session to confirm whether its 05:04 root-cause work touched the paperless consumer's duplicate/ingest paths** before the campaign accelerates — my session assumed its ownership and did not improvise around it. · M · S · Quality *(new)*
49. ☐ **Decide whether `DELETE_DUPLICATES=true` stays through the campaign** — already answered once (keep), but the first genuinely duplicated document will re-open it; make the answer visible at the point of doubt (runbook + `status` output both mention it today). · L · S · Docs *(new, low)*
50. ☐ **Remove the stale `.cache/scan-to-paperless/{prev-frame-*.jpg,preview.jpg,b.png,r.png,t.pdf}` scratch files** left over from the exploratory session (incidental clutter in a directory that is now lifecycle-managed). · L · S · Cleanup *(new)*

### Harvest status of this section

- **Already queued (no new row needed):** 3, 4, 5, 6, 7, 8, 11, 13, 14, 15, 16, 17, 18, 19, 22, 26, 27, 28, 30, 31, 32, 39.
- **Harvested as part of this report:** 1, 2, 9, 12, 23, 33, 36, 41, 43, 50 (the direct, dispatch-grade follow-ups) — routed to `TODO_LIST.md` + `docs/todo/services.md` / `docs/todo/monitoring.md` / `docs/todo/pipeline.md` with `**Source:**` pointing here.
- **Deliberately NOT harvested (recorded here, per the TODO-system rule):** 10 (covered by the existing standalone-lint row — verify before creating anything), 20, 21, 24, 25, 29, 34, 35, 37, 38, 40, 42, 44, 45, 46, 47, 48, 49 — these are either sub-parts of a harvested item, ROADMAP-grade ideas, or low-value nits. They are not commitments; do not dispatch them by default.

---

## g) Questions I cannot answer myself

1. **The numbering layer's three unknowns (still the campaign's actual end goal, still blocking):** (a) is the intake number **auto-assigned in scan order** or **pre-written on the back of each document**? (b) is the working entity list a **supplied list**, **Kith CRM**, or **free-form text I normalize**? (c) do you want the mapping surfaced as **Paperless saved views only**, or as a **local printable re-shelve table**? I cannot infer any of the three from the repo, and building the wrong one costs a full rewrite of the ASN/ledger layer.
2. **Raw-frame retention:** I deleted 2.0 GB of staged PNM frames via the new startup GC, on the assumption that a delivered PDF is the record. If those frames are evidence (or a re-convert opportunity after a profile change), tell me and I will switch the policy to archive-before-delete rather than a 60-minute sweep.
3. **How loud should the operator signal be?** Options: a desktop notification per delivered document, a single "campaign stalled / device gone" alert only, or a printed physical checklist next to the scanner. I cannot tell whether this morning's 50-minute loss happened because you were not looking at the log, or because you were looking at the machine and the machine told you nothing.

---

## Appendix: the incident chain (evidence, verbatim)

| Time | Evidence | Meaning |
| --- | --- | --- |
| 09:32:07 | `ts=$(date …)` printed into the later product name `doc-20261019-093207-01.pdf` | the fatal scan began |
| 09:37:07 | `scanimage: received signal 15` then `trying to stop scanner` | `timeout` fired 300 s in |
| 09:32 → 10:01 | no log output at all (29 min) | `scanimage` blocked in the kernel (D-state on the USB URB) |
| 10:01:36 | `usb 6-1: USB disconnect, device number 11` + `scanimage: sane_start: Invalid argument` + `Batch terminated, 1 page scanned` | device dropped off the bus; the URB was released |
| 10:01:36 | `frame-0001.pnm` = **31 bytes**, `magick: negative or zero image size` | header-only PNM from the aborted scan |
| 10:01:36 | `cp: cannot stat '…/doc-20261019-093207-01.pdf'` → `ERROR: failed copying … (ACL/group write?)` → **process exit** | the fatal `die` |
| 10:01 → 10:50 | zero log lines; watch PID gone | **50 min of paper fed into nothing** |
| 10:50:42 | `new SuperSpeed USB device number 13 … Product: ADS-1800W SerialNumber E83229M4X114379` | user replug restored the device |
| 10:59:35 | `gc: reclaimed 1014 stale raw batch dir(s)` / `removed 47 stale staged product(s)` / `WATCH mode start` | fixed wrapper live |
| 10:59:39–42 | `2 frame(s) captured` → `delivered 1 document(s)` → doc **1000494** | end-to-end proof |
| 11:13:40–42 | `2 frame(s) captured` → `delivered 1 document(s)` (`doc-20261019-111336-01.pdf`) | second proof, while this report was being written |

*Cross-check command:* `sed -n '349,$p' ~/.cache/scan-to-paperless/watch.log` (line 349 is the 10:59:35 restart marker).
