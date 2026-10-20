# Scanner campaign day one: wrap-up, path-chain answer, and ingest-side findings (2026-10-19 23:20 CEST)

**Segment covered:** 11:13 → 23:20 CEST on 2026-10-19, i.e. everything after `docs/status/2026-10-19_11-13_scanner-watch-silent-death-and-loop-hardening.md`. The work in this window was three questions answered from live state and the deployed source ("where do the files first go?", "can Paperless fix rotations?", and the day's own evidence sweep), plus the day-one operational record of the fixed watcher. No new code shipped in this window — which is itself the most important fact in this report, because the software ran for 12.3 hours without supervision and without a single guard firing.

**Format note (skill override):** the `status-report` skill mandates a styled HTML dashboard; the request named `docs/status/<YYYY-MM-DD_HH-MM_WELL-NAMED>.md`, so this is Markdown per the explicit instruction. Flagged, not silently propagated.

| Field | Value |
| --- | --- |
| Report time | 2026-10-19 23:20 CEST (Monday) |
| Host / repo | evo-x2, `/home/lars/projects/SystemNix` (master, tree clean) |
| Watcher | PID **1250077**, started **10:59:35**, still alive at 23:20 — **12.3 h uptime** |
| Watcher output | **54 captures → 75 documents** delivered since the restart (57 delivery events); last capture **12:10:44** |
| Guard activations since restart | **0** (no frame drops, no `/Count` rejections, no delivery failures) |
| Paperless ingest today | **144 documents**, ids **1000436 → 1000579** |
| Consume dir now | **0 files** (peak 16 files / 264 MB at 12:18) |
| Last repo commit | `890bae631` (~11:20) — nothing else touched this tree in 12 h |

---

## a) FULLY DONE

1. **Answered "where do the files first go?" from live state, end to end.** Nothing reaches Paperless from the scanner directly; the chain is (1) `~/.cache/scan-to-paperless/raw/batch-XXXXXX/frame-NNNN.pnm` — raw PNM straight from `scanimage` in a per-poll `mktemp` dir; (2) `~/.cache/scan-to-paperless/out/<prefix>-<ts>-NN.pdf|png` — the converted product; (3) `/mnt/pool/services/paperless/consume/` — handoff by `cp` + `chmod 0644`, after which the staged copy is deleted; (4) Paperless itself: scratch → `media/documents/{originals,archive}` → `index/` + `llm_index/`. Confirmed against module config (all state under `dataDir=/mnt/pool/services/paperless`) and live perms (`media/documents` = `711 paperless:paperless`, so the agent cannot read it — permission-blind by design).
2. **Found and reported a live ingest stall while answering that question — the day's second silent failure.** At 12:18 consume held **16 files / 264 MB** (40.6 MB, 28.9 MB, 27.9 MB sheets) with `pending_total` 23, and the journal showed **both celery workers pinned retrying `/embeddings`**: `openai.OpenAIError: Error code: 500 — 'input (777 tokens) is too large to process. increase the physical batch size (current batch size: 512)'`. Nothing reported it; the queue looked healthy while the consumers spun. It drained to **0 files by 12:36** on its own.
3. **Answered "can Paperless self-fix rotations?" from the deployed 3.3.1 source, not from docs.** Live env sets only `PAPERLESS_OCR_LANGUAGE=deu+eng`; the rest are defaults: `OCR_MODE=auto`, `OCR_DESKEW=true`, `OCR_ROTATE_PAGES=true`, `OCR_ROTATE_PAGES_THRESHOLD=12.0°`, `ARCHIVE_FILE_GENERATION=auto`, `OCR_OUTPUT_TYPE=pdfa`. `paperless/parsers/tesseract.py:312-318` passes `--deskew` and `--rotate-pages --rotate-pages-threshold 12` to ocrmypdf whenever OCR runs, and the OSD data it needs is present (`osd.traineddata` + `deu.traineddata` in the deployed tesseract 5.5.3). Answer: **yes for pages it OCRs**, with three silent no-op paths (text-layer PDFs skip ocrmypdf entirely at `tesseract.py:569`; existing-text pages are `skip_text`; OSD needs text so blank backs and text-poor strips are never rotated) and one storage nuance (rotation lands in the **archive** PDF; the stored **original** keeps the delivered orientation).
4. **The fixed watcher ran 12.3 h unattended with zero guard activations.** 54 captures → **75 documents** (57 delivery events, several batches of 2–8); the empty-streak counter reached **#7756** (idle since ~12:16, ~5.1 s/poll, consistent with the 4 s empty sleep plus a failed attempt's overhead) with no restart, no crash, no STOP flag.
5. **Staging stayed bounded across the whole day** — `raw` **4.0 KB** (one in-flight dir), `out` **0**, `skipped` **0**, `watch.log` **140 KB**; two GC runs total. Compare with the same directory reaching 2.0 GB in two hours before the fix: the lifecycle change is now proven under real load, not just by a single reclaim.
6. **The blank-face reorder paid for itself.** At least ten logged reorders (`[reordered: blank face moved to page 2]`) — e.g. 11:46:35/37/40 on a 3-sheet batch, 12:04:29, and 12:10:15/24/47 — each one a document whose first scanned face was blank/uninformative and whose content face was promoted to page 1. Without it those documents would have shipped content on page 2.
7. **API/behaviour audit of the failures that did occur, and it is richer than "the scanner is flaky".** Day census from `watch.log`: **332 × rc=4** (seating), **2 × rc=6** (`Batch terminated, 0 pages scanned` — SANE JAMMED), **5 × rc=1** (`scanimage: open of device brother5:bus6;dev1 failed: Invalid argument`), and **1 × rc=139** at 12:15:06 (`timeout: the monitored command dumped core` — `scanimage` **segfaulted**). The burst ran 12:15:06 → 12:15:44 and then **cleared itself**: the next polls returned rc=7 with no replug and no intervention.
8. **Verified the SIGSEGV did not litter the repo.** No `core*` in the tree, `git status` clean; `systemd-coredump` holds only quickshell cores from 2026-10-18. The watcher's cwd is the repo, so this was worth checking rather than assuming.
9. **Confirmed the device is currently healthy and idle:** `scanimage -L` → `brother5:bus6;dev1` present, `/sys/bus/usb/devices/6-1` present, ADF drained.
10. **Scoped today's ingest by source.** The 17:xx hour's 9 documents did **not** come from the scanner (`Consuming Invoice-HKWNX8GV-0002.pdf`, `Finaldunning-Debtist-2604-3274-2821.pdf`, `image00X.png`, `Bild.jpg`, `190263`, `190268`) — the scanner's last capture was 12:10:44, so those arrived through the email/API/drive paths. The split corroborates: the watcher log sums to **120 documents** delivered across all of today's runs, against **144** consumed documents in the journal — so ~24 of the day's documents never touched the scanner, and the campaign total should be quoted as 120 (scanner) rather than 144 (everything). Useful because it separates "campaign intake" from the rest of the day's ingestion instead of letting one number cover both.
11. **Two operator questions answered with evidence instead of assertion** (the rotation answer cites file:line; the path answer cites the module's `dataDir` and live perms), and both answers produced findings the questions did not ask for (the ingest stall; the silent no-op paths).
12. **Harvest hygiene closed on an old hole and extended by today's findings**: the missing `monitoring.md` entry behind the consume-staleness queue row was created, the `llm_index` and FAILED-backlog rows gained today's second reading, the training-milestone row gained the day-one KPI numbers, the USB `[watch]` row gained the failure census, and four new rows were added (rotation verification, FLM batch size, phantom-metric self-check, driver-failure census). `check-todo-system.sh` → `OK: TODO queue/library structure clean`, `check-doc-links.sh` → `OK`.

---

## b) PARTIALLY DONE

1. **Rotation capability: code-verified, never exercised.** The claim I gave you is sourced from the deployed parser, not from an observation — no 180°/90° page has ever been pushed through this pipeline. The three no-op paths mean a naive test could also "pass" while proving nothing, so the test must check the archive **and** the original. Open: feed one inverted + one 90° page and record what each becomes. (S)
2. **The rc mislabel fix is still not applied — and today proved its cost 8 more times.** At 12:15:06 the log told you "rc=4 = paper at the feeder with the pick rollers not yet engaged — push the sheet in until it stops" for an rc=139 **segfault**, and again for five rc=1 **device-open failures** in the next 38 s. The user-facing advice was wrong for every one of those. The one-line branch is queued and unbuilt. (S)
3. **The ingest-side stall is diagnosed, not fixed, and not probed.** Root cause is the FLM embedding batch contract (512-token physical batch vs callers sending 522–806 tokens), amplified by an openai client that retries a non-retryable condition and pins both workers. Nothing yet: not the FLM change, not the caller-side guard, not a consume-staleness probe. (M)
4. **The phantom metric is now proven broken but still unplugged.** `paperless_llmindex_last_success_age_seconds` advanced **+43805 s across 44100 s of real time** (1673701 at 11:05 → 1717506 at 23:20), i.e. the gauge moves with the wall clock while its "last success" stays pinned ≈**19.9 days** back (≈2026-09-30 02:4x). It is a permanent false "RAG dark" that would also mask a real RAG outage. Diagnosed; not fixed, not silenced. (S)
5. **Organization debt is now quantified and untreated: `paperless_inbox_count` 336 → 421 in twelve hours.** 144 documents entered today; zero correspondents, types or tags were assigned. Intake ran at full speed while the sorting half of your actual goal (entity / type / date, plus the ASN) ran at zero. (L, blocked on (g).)
6. **The watcher is still a bare user process with no restart, no journal and an unbounded log.** Today it behaved; a reboot would have ended the campaign silently, and 12.3 h of log growth (140 KB) is still unbounded. (M)
7. **The RC=139/RC=1 classes are catalogued but not counted anywhere.** No metric, no threshold, no runbook line — a rising rate would be absorbed by retries exactly as today's 332 rc=4s were. (S)
8. **The 40 MB sheets changed the arithmetic on the scan-profile decision, which is still undecided.** Today's products ranged from 6.8 MB to **40.6 MB** per sheet; at that size ~1900 remaining documents is ~30–50 GB of media and proportionally longer OCR. The True-Gray/200-dpi decision was already queued; it now has a deadline (before the bulk run, not after). (S)
9. **My own earlier harvest had a pairing hole.** The queue row "Alert on consume-dir depth/staleness" pointed at `docs/todo/monitoring.md`, but that file had no such entry — the structure checker validates report citations, not row-to-entry pairing, so it stayed green. Found and fixed today; the checker gap remains. (S)
10. **`nix flake check` still not run for this session's changes** (script + docs only, no `.nix` touched), and the wrapper still has no automated test. (S / M)

---

## c) NOT STARTED

1. Watch as a systemd unit (`Restart=always`, journal, boot start, rotation) — carried, now with 12.3 h of uptime as an argument for permanence.
2. Consume-directory staleness/depth probe and the consume readability guard for non-wrapper producers.
3. Operator feedback channel (notification on delivered / failed / device gone) — carried; today's two silent failures are the third and fourth instance of the same need.
4. rc-conditional WARN text.
5. `llm_index` age metric repair + the generalized "metric that cannot move" detector.
6. Triage of the FAILED-task backlog (**76** now, was 75 at 11:05; train_classifier still 31).
7. Training milestone + day-one corpus curation (144 documents, including the test scans from this morning).
8. Numbering ledger + ASN patching + sorting dashboard — blocked on (g).
9. `DATE_ORDER=DMY` date-extraction and FLM classification spot-checks on real receipts.
10. Scan-profile decision (300 dpi colour vs True Gray / lower dpi).
11. Raw-frame retention policy.
12. Batch manifest (delivery-time JSON ledger).
13. PNG structural assert in receipts mode (PDFs have `/Count`; PNGs have nothing).
14. stdout/loop-exit audit across `scripts/` (the 10:01 bug class, unchecked elsewhere).
15. `status` campaign line.
16. Post-campaign storage/export watch.
17. USB recovery unit (root-side), still only if it recurs.
18. Sleep/power policy check for an overnight campaign: the watcher polls every ~4 s forever; nothing measures whether that has any cost or risk overnight.
19. Rotation behavioural test (new today).
20. FLM embedding batch-size fix (new today).

---

## d) TOTALLY FUCKED UP

1. **A metric that cannot move was treated as data for a day.** `paperless_llmindex_last_success_age_seconds` advances one second per second off a fixed stale row (arithmetic above). Severity: it is a permanent alert either way — false "RAG dark" today, and a real RAG outage would be invisible behind it. Root cause: the collector's query was never validated against the DB. This is the phantom-metric class precisely: plausible, live-updating, structurally incapable of being right.
2. **Operator-facing advice was wrong for 8 consecutive failures in 38 seconds.** rc=139 (segfault) and rc=1 (device could not be opened) both printed the rc=4 seating cure. Severity: the operator is told to push paper into a device whose driver just crashed; that is how paper gets jammed or torn. Root cause: an inherited unconditional cause string that I copied forward and flagged but did not fix — my own report earlier today called this the top defect and it is still shipped.
3. **A second silent pipeline failure occurred the same day as the first, in a different layer.** The consume directory filled to 264 MB with both workers spinning in an embedding retry loop, and **nothing** reported it for ~15 minutes. Severity: had the input sizes matched the batch, the stall would have been total and equally silent. Root cause: no probe on the directory, and a retry loop treating a deterministic 500 as transient.
4. **Twelve hours of intake produced zero organization.** 144 documents ingested, `paperless_inbox_count` up 85, no correspondent/type/tag assignment. Severity: the campaign's value is in the sorting, and the corpus of unsorted documents is now large enough that manual triage is a real cost — plus the classifier will train on unlabeled data unless it is cleaned first. Root cause: intake was made excellent and the organizing half was never built (blocked on my three questions, which I should have escalated harder).
5. **The device stack crashed mid-campaign (SIGSEGV) and the only record is a log line.** Severity: unknown frequency, no counters, no alert, no runbook entry; a crash could equally have produced a partial or corrupt sheet and only the page-count guard would have noticed (it did not fire — no delivery was lost today).
6. **A 12.3 h run with zero guard activations is evidence about the guards, not coverage of them.** Every failure path I wrote this morning is still untested by machine: the day proved the *happy* path at scale and left the guards exactly as unverified as when I wrote them. Severity: the next incident will again be found by a human.
7. **My harvest pointed at a library entry that did not exist** (the consume-staleness row), and both checkers passed. Severity: low per instance, but it is the drift class the TODO system exists to prevent, and the gate has a hole for it.
8. **I answered a capability question ("can Paperless fix rotations?") without ever testing the capability.** Severity: the answer is only as good as the source read; if `ocrmypdf`'s `--rotate-pages` were disabled in the pinned build's wrapper, my answer would still have looked authoritative. The pattern — verifying code instead of observing behaviour — is the same one that produced the 09:44 report's page-count embarrassment.

---

## e) WHAT WE SHOULD IMPROVE

1. **Branch every machine-emitted cause on the actual code.** One unconditional sentence produced 8 wrong instructions today and a documented near-miss this morning (rc=6 mislabeled as rc=4). Rule: a log line may name a cause only for the code it just measured.
2. **Treat "the metric updated" as a hypothesis, not evidence.** A gauge can update and still be wrong; the test is whether it *can* move in response to the thing it claims to measure. Add the class gate (§f) and, until then, sanity-check any "last success" gauge against a second source when you read it.
3. **Probe the directories, not just the services.** Both of today's silent failures (dead loop, starved consumers) would have been caught by a probe on an *artifact* (a stale consume dir, a stalled log) rather than on a unit's `ActiveState`. Prefer artifact probes: they catch wedged-but-active.
4. **Make retry-ability a decision, not a default.** A deterministic 500 ("input too large") must not retry with backoff inside a worker that other tasks need. Distinguish transient (connection, 5xx-with-retry-after) from deterministic (validation, size) at the client.
5. **Do not scale intake past the ability to organize.** `paperless_inbox_count` is the campaign's organization-debt KPI; intake without sorting converts a physical pile into a digital pile. Set the budget: no more bulk feeding until the first N documents are labeled and the classifier trains.
6. **Count soft failures.** 332 successful retries is not "no problem" — it is a 332-event signal about the feeder/device interaction, and today nobody could see it without grepping. Instrument the rate.
7. **Report long-run evidence, not just a single demo.** The strongest proof for this morning's fix arrived at 23:20, twelve hours later, and only because I went looking. Make "how long did it run unattended, with how many guard activations" part of every daemon fix's close-out.
8. **Escalate blocking questions harder.** Three owner questions have blocked the organizing layer across two sessions; the cost of the block is now measurable (421 unsorted documents). State the cost, not just the question.
9. **Verify behaviour for capability claims, or label them.** Code-reading produced a correct answer today, but the class of claim ("capability X works") should carry an observation or an explicit "unverified" tag.
10. **Close the harvest-pairing checker hole** — validate that each queue row's domain-library target actually contains a matching entry, not merely that the cited report is referenced somewhere.
11. **Escape the recursive "queued but unbuilt" loop for the top three items.** The rc fix, the notification, and the systemd unit have been queued by me twice and are each under an hour of work; queueing is not progress.
12. **Keep the physical checklist next to the machine.** The 332 rc=4 events are an operator-ergonomics problem (seating small receipts), and a one-page laminated procedure beats any log line.

---

## f) Up to 50 things to get done next

Legend: **Impact** C/H/M/L · **Effort** S/M/L · **Category**. Ticked = already queued (queue row + library entry exist); un-ticked = harvested by this report or explicitly recorded as not-harvested.

**Top of the list (each under an hour, all previously queued, none built)**

1. ☐ **Apply the rc-conditional WARN fix** (4 = seating, 6 = jam, 1 = device open, 124 = hang, 139 = crash, else raw stderr) — 8 live mislabels today. · C · S · Bug *(queued; highest urgency now)*
2. ☐ **Operator notification for delivered / failed / device-gone.** · C · S · Feature *(queued)*
3. ☐ **Systemd unit for the watcher** (`Restart=always`, journal, boot start, rotation). · C · M · Quality *(queued)*
4. ☑ **Consume-directory staleness/depth probe** (library entry created today after the pairing hole). · H · S · Feature
5. ☑ **FLM embedding batch-size fix / caller-side size guard** (ai-stack.md row harvested today). · H · M · Bug
6. ☑ **Repair the pinned `llm_index` age metric + add the phantom-metric self-check.** · H · S · Bug
7. ☑ **Triage the 76 unacked FAILED tasks** (train_classifier 31, llm_index 22, consume_file 15). · H · M · Cleanup
8. ☑ **Verify auto-rotation behaviourally** (inverted + 90° page; archive vs original). · H · S · Quality

**Organizing the corpus (the user's actual goal)**

9. ☑ **Training milestone + hourly train-classifier green.** · H · M · Feature
10. ☑ **Curate day-one's 144 documents** (keep/merge/delete the test scans) before training. · H · M · Cleanup
11. ☑ **Numbering ledger + ASN + dashboard** — blocked on three answers. · H · L · Feature
12. ☐ **Set an intake budget tied to `paperless_inbox_count`** (e.g. stop bulk feeding above N unsorted) and surface the count in `status`. · M · S · Quality *(new)*
13. ☐ **Label the first 50–100 documents by hand now**, while the corpus is still small — the classifier needs examples and the ledger needs entities. · H · M · Feature *(new; the concrete first move for item 9)*

**Ingest + device robustness**

14. ☑ **Driver-level failure-mode census** (rc=139/rc=1/rc=6) and a visible rate. · M · S · Quality
15. ☑ **Scan-profile decision before the bulk run** (now with 40 MB/sheet data). · H · S · Feature
16. ☑ **Raw-frame retention policy.** · M · S · Quality
17. ☑ **Batch manifest (delivery-time JSON ledger).** · M · M · Feature
18. ☑ **PNG structural assert in receipts mode.** · M · S · Quality
19. ☑ **Wrapper selftest/fixture for the guards.** · H · M · Quality
20. ☑ **Loop-exit / fatal-cp audit across `scripts/`.** · H · S · Quality
21. ☐ **Record the day-one throughput baseline properly** (documents/hour by source, scanner vs other paths) so the remaining ~1900 documents can be planned rather than guessed. · M · S · Quality *(new)*
22. ☐ **Check the overnight cost of a 4 s poll loop** (CPU wake-ups, journal/log growth, power) before leaving it running for days. · L · S · Quality *(new)*
23. ☑ **USB recovery unit** if the drop-off class recurs. · M · M · Feature
24. ☐ **Decide whether an idle watcher should back off** (4 s → 30 s after N idle polls) — harmless today, but it is 7756 wake-ups overnight for nothing. · L · S · Quality *(new)*
25. ☐ **Add a `--once`/`--bounded` mode** so a fixed number of sheets can be scanned without a kill, useful for tests and for the behavioural rotation check. · M · S · Feature *(new)*

**Observability**

26. ☑ **Consume readability guard for non-wrapper producers.** · H · S · Bug
27. ☑ **Alert when the FAILED backlog reaches a human.** · H · S · Feature
28. ☐ **Probe the other consumed directories** (drive-paperless drop, inboxclean) with the same staleness shape. · M · S · Quality *(new — generalization of the consume probe)*
29. ☐ **Add a "watcher alive" signal that is not `pgrep`** (a heartbeat textfile metric the whole monitoring stack can see). · H · S · Feature *(new)*
30. ☐ **Track ingest *lag* (delivery timestamp → doc id) as a metric**, so "the pipeline is slow" is visible before it becomes a 264 MB backlog. · M · M · Feature *(new)*
31. ☑ **Audit alerting for paperless-family producer death.** · M · S · Quality

**Paperless-side quality**

32. ☑ **Re-enable paperless-gpt-auto** with the corrected filter. · M · M · Bug
    **CORRECTION (2026-10-20 02:55, live post-state probe):** the filter was
    NEVER rebuilt — workflow 1000003 still carried `filter_has_any_document_types=[Bill]`
    with NO tag gate when re-enabled, and it matched UNTYPED campaign receipts
    all afternoon/evening while flm was guard-down, burning **70 documents to
    `paperless-gpt-failed`** (gpt journal: 210 auto-processing attempts, 0
    successes). The workflow was re-disabled 02:45 and all 70 tags bulk-cleaned
    via `POST /api/documents/bulk_edit/` `modify_tags`/`parameters.remove_tags`
    (the legacy `remove_tag`+`parameter` shape 400s "tag not specified" on
    3.3.1). Full evidence + recovery: docs/services/paperless.md §Accounting
    field extraction trap 2 + docs/todo/services.md row "Re-enable (or rebuild
    tag-gated)". The claim-vs-live-state gap here is the exact class the
    commit-message evidence rule exists for.
33. ☑ **`pol` in OCR_LANGUAGE** for the Polish share. · M · M · Feature
34. ☑ **Date-extraction + FLM classification spot-checks.** · H · M · Quality
35. ☑ **Post-restore SSO login round-trip.** · M · S · Quality
36. ☑ **Diagnose bank-sync-paperless.** · H · M · Bug
37. ☑ **Token-mint boot resilience.** · M · M · Quality
38. ☐ **Confirm the 40 MB sheets are single documents, not accidental stack scans** — a 40 MB / 2-page colour sheet is plausible, but if the ADF multifeed (inactive detection) merged sheets into one job, the pairing is wrong. Check the two largest products' page counts. · M · S · Bug *(new, and worth doing before the bulk run)*
39. ☐ **Re-check `paperless_inbox_count` semantics** — 421 documents carrying the inbox tag: confirm that is campaign intake and not a stale tag that ingest should clear. · M · S · Quality *(new)*

**Docs / process**

40. ☑ **Scanner docs remainder** (blank-face reorder, USB evidence, bad-scan protocol, storage doctrine). · M · S · Docs
41. ☐ **Runbook: rc→action table including 1/6/139 and the "device may need a replug" ladder.** · H · S · Docs *(new)*
42. ☐ **Runbook: write the verified rotation semantics** (archive vs original, the three no-op paths) once item 8 confirms them. · M · S · Docs *(new)*
43. ☐ **Gotchas archive: the four-day's defects as narrative** (die-in-loop, unconditional cause string, unreadable consume file, empty-dir accumulation, pinned metric). · M · S · Docs *(new)*
44. ☐ **Close the harvest-pairing checker hole** (row → library entry validity, not just report citation). · M · S · Quality *(new)*
45. ☐ **Contributor rule: "no `exit` inside a long-running loop" + "branch machine causes on measured codes".** · M · S · Docs *(new)*

**Housekeeping / low priority**

46. ☐ **Delete or rebind the stale `trash`/`skipped` dirs' policy** (currently empty; confirm nothing ever needs manual retrieval). · L · S · Cleanup *(new)*
47. ☐ **Write down where the wrappers' logs live and how to rotate them by hand** until the unit exists. · L · S · Docs *(new)*
48. ☐ **Confirm the two "not from the scanner" ingest paths at 17:xx** (which producer wrote the Invoice/Finaldunning/image files) — attribution matters for the 144-document total. · L · S · Quality *(new)*
49. ☐ **Re-check `bank-sync` markers after the day's restarts**, since the suite ran uninterrupted for 12 h. · L · S · Quality *(new)*
50. ☐ **Decide the fate of the 3 earlier test documents** (1000436 checklist/Biedronka, the reordered-before-fix set) — they are training noise. · L · S · Cleanup *(new)*

### Harvest status of this section

- **Already queued (no new row):** 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 15, 16, 17, 18, 19, 20, 23, 26, 27, 31, 32, 33, 34, 35, 36, 37, 40.
- **Harvested by this report (queue row + domain library):** 5, 6, 8, 14 (the four new queue rows added at authoring), plus library-row updates for 7, 9 and the training-KPI numbers. Items 12, 13, 21, 22, 24, 25, 28, 29, 30, 38, 39, 41, 42, 43, 44, 45 are recorded here as **deliberately not harvested yet** — they are either sub-parts of a harvested item (13 → 9, 38 → 15, 41/42 → 40), ROADMAP-grade (22, 24, 25, 29, 30, 46, 47), or need a decision first (12, 28, 39, 48, 49, 50). Do not dispatch them by default; promote deliberately.
- **Correction to a prior harvest:** item 4's library entry was missing entirely (the queue row existed and both checkers were green anyway) — created today, hole recorded in §d.7.

---

## g) Questions I cannot answer myself

1. **The campaign's defining unknowns, still unanswered and now expensive:** (a) is the intake number **auto-assigned in scan order** or **pre-written on the back** of each document; (b) is the entity list a **supplied list**, **Kith CRM**, or **free-form text I normalize**; (c) do you want the mapping as **Paperless saved views only** or as a **printable re-shelve table**? The cost of the block is now measurable: **421 documents sit in the inbox with no correspondent, type or tag**, and every further document increases the manual work.
2. **Did today stop, or pause?** The scanner went idle at ~12:16 (last capture 12:10:44) and nine documents arrived at 17:xx from other paths. I cannot tell whether you finished deliberately, hit a seating/device problem, or switched intake routes — and it changes what I do next: leave the watcher running overnight (with no restart-on-reboot and no alert if it dies), shut it down cleanly, or convert it to a systemd unit tonight.
3. **What is the scan profile for the remaining ~1900 documents?** Today produced 40.6 MB, 28.9 MB, 27.9 MB and 9.1 MB sheets at 300 dpi 24-bit colour. At that rate the corpus lands at roughly 30–50 GB of media plus proportionally heavier OCR (and today's evidence shows the ingest side is the fragile part). True Gray cuts that ~3x with, I believe, no reading loss for text — but only you can say whether colour matters for your receipts or for anything you might print/export later, so I will not flip it unilaterally before the bulk run.
