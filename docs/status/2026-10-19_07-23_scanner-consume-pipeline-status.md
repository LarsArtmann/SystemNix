# Status: Scanner→consume pipeline (part 2) — regression, recovery, and the Wave-6 wall

- **Date:** 2026-10-19 07:23 CEST
- **Session scope:** everything since `2026-10-19_02-16_brother-ads1800w-paperless-intake-status.md` — gen-930/933 deploys, first real scans, my consumer regression + fix, and the ingest blocker
- **Tree:** HEAD `d8c870e02`, clean; live gen **933** (`28hbqfq10…`), anchor OK; consumer **inactive** (restore step-1 presumably running), receipt `test-receipt-biedronka.png` still parked in consume
- **Format:** `.md` per the user's explicit standing demand (HTML-canonical override, same as the 02:16 report)
- **Multi-session context:** this session shared the tree/box with a parallel session running the Qonto arc + hot-db Wave-6 flip + docs-health groundwork. Where a failure is theirs, it's labeled theirs; where it's mine, §d says so bluntly.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **brscan5 chain live end-to-end** — `scanimage -L` lists `brother5:bus6;dev1` as Brother ADS-1800W; full option surface exposed (ADF left/center ±Duplex, Card Slot ±Duplex, 100–1200 dpi, AutoDocumentSize, AutoDeskew, SkipBlankPage) | live probes after gen-930 deploy; anchor discipline verified both deploys (930 at 04:45, 933 at 07:15) |
| a2 | **First real document scanned successfully** — Biedronka fiscal receipt (FAKTURA 7276F00581/1026, 86,84 PLN, 2026-10-18) captured **duplex in one pass**: side 1 = printed face, razor-sharp at 300 dpi, auto-cropped to 76×261 mm, deskewed; side 2 = POSNET watermark back | `~/scans/receipts/duplex-01/02.png` + ImageMagick stats (stddev 18.7% vs 7.1%) + viewed previews |
| a3 | **Orientation doctrine established** — printed side UP; frame 1 = printed face (arrives 180°-rotated, irrelevant: `OCR_ROTATE_PAGES` is on in paperless.nix:442-445) | duplex experiment, this session |
| a4 | **Consume-dir write path: solved twice over** — bridge: user-run `setfacl u:lars:rwx` (kernel-evaluated per access, no re-login needed; proven by my successful 05:07 drop); durable: consume dir `2775` + `lars` in `paperless` group, committed (`9e902add2` sweep), deployed in gen 933, **verified live**: dir is now `drwxrwsr-x+` | live `ls -ld` post-deploy |
| a5 | **My consumer regression: root-caused → fixed → deployed → verified** — see §d1 for the failure; the fix (`+"…"` root ExecStartPre, existence-guarded, inside the existing `serviceConfig` mkMerge) evals clean (`3dd6zrz1…`), deployed, and the consumer came back **active/running** with the unit file carrying exactly the intended ExecStartPre | busctl ActiveState + `/etc/systemd/system/paperless-consumer.service` grep + boot journal diff (`REMOVED unit-script-paperless-consumer-pre-start`) |
| a6 | **Blank-media mystery fully diagnosed** — the "empty-looking" scan was a genuinely blank sheet (printer output failed); the watermark-only "receipts" were the **blank leader of a POSNET roll** (watermark + "Termin ważności" are the fiscal pre-print; zero thermal print on top). Scanner exonerated with evidence in both cases | magick mean/stddev + viewed previews, this session |
| a7 | **Ingest blocker identified and root-caused without touching root** — consumer was picking the file up into a DB with **no tables**; traced to the parallel session's Wave-6 hot-db flip (their own 05:04 report documents it: cluster copied, `paperless` DB alone schema-empty, old data shadowed under the mount, DR dump 02:01 on pool, root-only recovery handed off) | `ProgrammingError: relation "documents_paperlesstask" does not exist` in consumer/task-queue journals + `docs/status/2026-10-19_05-04_qonto…` + postgres version/mount checks (17.11 both gens, `hot/postgres` subvol mounted) |

## b) PARTIALLY DONE

| # | Item | Missing |
|---|------|---------|
| b1 | **End-to-end ingest** — every link verified individually (drop ✓, consumer active ✓, watcher live ✓), but the final hop (file → DB → OCR → archive) is blocked by the Wave-6 empty DB; restore command block handed to the user at ~07:10; at report time the consumer is **inactive** — consistent with restore step 1 in progress | user runs the root restore; then I verify the full chain |
| b2 | **Duplicate policy for the campaign** — `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` silently drops byte-identical re-scans (jam-retry case!) — decision requested at 02:16 (§g3), still unanswered | owner decision |
| b3 | **Transport doctrine** — USB won de facto (it's wired and working); the researched WiFi SMB/SFTP route stays parked (one open risk: scanner's SMB negotiation version) | only if the user wants desk-side scanning |
| b4 | **Scanner knowledge capture** — no runbook (`docs/services/`), no FEATURES/CHANGELOG entries, no AGENTS.md routing line; the 02:16 report listed these (c2/c3/c6) and they remain undone | one authoring pass, post-restore |

## c) NOT STARTED

| # | Item |
|---|------|
| c1 | The 2000-receipt campaign itself (blocked on b1) |
| c2 | Scan-profile codification (300 dpi color, AutoDocumentSize, AutoDeskew; multifeed option is **inactive** in this mode combo — see §d4) |
| c3 | Training milestone (50–100 docs → tags/correspondents → AUTO → Train Classifier) |
| c4 | Ingest-capacity measurement (first timed batch → extrapolate 2000) |
| c5 | Carrier-sheet check for sub-50.8×70 mm slips |
| c6 | §f harvest into TODO_LIST/domain libs (deferred on "WAIT FOR INSTRUCTIONS", again — see Harvest note) |

## d) TOTALLY FUCKED UP

| # | Item | Honest accounting |
|---|------|-------------------|
| d1 | **I shipped a runtime-broken unit change that killed paperless-consumer for ~1.5 h.** My first consume-dir fix (`preStart = chmod 2775 …`) executed inside the sandboxed paperless-user preStart → `Operation not permitted` → exit 1 → 5 restarts → **start-limit-hit at 04:37, unit dead until the 06:14 fix deploy**. The repo documented this EXACT class and I authored it anyway: `bank-sync.nix:456-457` ("preStart runs as the service user — chown EPERMs") and the AGENTS hot-tier doctrine (own a `+`-prefixed root ExecStartPre for ownership changes). I even read bank-sync.nix this session and didn't apply its lesson to my own edit. Eval-green was worthless here — sandbox EPERM is invisible to eval — and I handed the user a deploy knowing I'd never exercised the hook path | found only because the ingest test failed; fix landed in the next deploy; the failure window overlapped the Wave-6 outage, muddying two incident timelines at once |
| d2 | **False inference from file mode**: seeing `drwxrwxr-x` post-setfacl, I concluded "my chmod ran" — wrong; `setfacl` rewrites the ACL mask which surfaces as group-writable bits. The journal said the opposite. State claims belong to the journal, not to `ls` archaeology | corrected within the same session, but the claim briefly stood |
| d3 | **MultifeedDetection=yes killed a poller cycle** — `scanimage -A` had explicitly listed the option as `[inactive]`; I scripted it anyway; every probe died on "attempted to set inactive option" for 15 min of window. Reading my own probe output was the whole skill | 15 min + one re-arm lost |
| d4 | **Two rounds of blank-media archaeology** — after the first watermark-only capture I should have named "this paper has no thermal print" and audited the media source; instead I scanned a second one (and chased orientation) before the pattern landed. The user's actual blocker (blank printer output, then blank roll leader) was visible after round one | minor, but it delayed the real question: is there anything PRINTED to scan |
| d5 | **Edit-tool race, twice** — the parallel session modified paperless.nix mid-edit (04:54); my edit attempt failed twice on stale-read before I re-Viewed and re-applied. Protocol worked, but my first attempt relied on a bash `sed` read instead of the View tool — the tool's read-tracking is the contract | no corruption; churn only |

## e) WHAT WE SHOULD IMPROVE

1. **Hardened-unit scripting rule (new, from d1):** before adding ANY preStart/script line to a unit that goes through `harden{}`/`mountGate`/`ioTier`, answer "as which user, inside which namespace, with which RW paths does this line execute?" — and prefer the existing `+`-prefixed root `ExecStartPre` pattern on sight. Candidate: an eval-time lint (chmod/chown/install inside a non-`+` preStart of a hardened unit → warn). Worth a pipeline.md row.
2. **Journal-before-inference:** state claims about unit/filesystem behavior get their evidence from `journalctl`/`busctl` first; file modes are hints, not proof (d2).
3. **Parse-your-own-probe:** when scripting `scanimage`, options marked `[inactive]` in `-A` output are unsettable — filter them out mechanically (d3).
4. **One-capture hypothesis discipline:** media-content anomalies get a named hypothesis after the first capture (d4) — same discipline as "a probe result that contradicts the invariant IS the verdict".
5. **Deploy-log literacy pays off:** the nh diff line (`REMOVED unit-script-paperless-consumer-pre-start`) was the fastest possible confirmation that the fix landed — reading the unit-level diff at switch time is now proven practice on this box.
6. **Storm deploys muddle attribution:** gen-932/933 went in under 83% PSI with DEPLOY_FORCE_PRESSURE=1; the smoke then mixed real regressions (Bank-Sync NEW, Monitor365 CB) with storm artifacts. The calm re-run is mandatory before anyone triages that list.
7. **What I'd tell the next session:** the consumer/ACL/scanner stack is READY; the only gate between here and the 2000-doc campaign is the Wave-6 restore (root) + one policy answer (b2).

**Harvest note:** per the standing "THEN WAIT FOR INSTRUCTIONS", §f is NOT harvested into TODO_LIST/domain libraries; deferral recorded here (TODO-system rule). The 02:16 report's deferral stands unharvested as well.

**DEFERRAL LIFTED + TRIAGED 2026-10-19 11:0x (scanner-campaign session):** the campaign resumed (the user reported the scanner "scanning nothing" — a dead watch loop, fixed the same session), so the deferral is spent. Triage of all 25 items:

- **Done:** #1–#6 (Wave-6 restore executed by the owner 07:21–07:31 and verified; post-restore chain green; duplicate policy answered = keep `DELETE_DUPLICATES=true`; first timed batch measured; scan profile codified in `scripts/scan-to-paperless.sh`; simplex/duplex-per-media confirmed — receipts simplex, invoices duplex).
- **Already covered by other rows (no duplicate created):** #7 calm-post-deploy smoke re-run (pipeline.md), #8 Monitor365 agent CB deadlock + #9 node_exporter/paperless-web journal spam (monitoring.md / stability.md rows from the parallel sessions), #11 nsfw-classifier CPU (stability.md/pipeline.md), #12 FastFlowLM `:52625` (monitoring.md "patch the socket's ActiveState" row).
- **Resolved by probe, not by work:** #10 "textfile collector rejects `paperless_tasks.prom` (value-less lines)" — re-read live at 11:05 2026-10-19: the file is well-formed (HELP/TYPE + samples only, fresh mtime), so the value-less-line emission did not survive the DB restore; the residual risk is a *second* occurrence going unnoticed, which the new monitoring.md FAILED-backlog row covers.
- **Harvested now:** #13 runbook → done via `docs/services/scanner.md` (remainder tracked in the queue); #14 FEATURES/CHANGELOG → done; #15 AGENTS routing line → declined, recorded in the queue row; #23 date-extraction spot-check → merged with the 02:16 §f20-21 row (services.md); #24 post-campaign export/restic → storage.md `[watch]`; #25 Canon PIXMA provenance → services.md `[ready]`.
- **Deliberately NOT harvested, with reason:** #16 candidate eval-time lint (chmod/chown in non-`+` preStart) — already a live pipeline.md row from the 09-44 harvest; #17–#20 training milestone / carrier sheet / PATCH-T separators / thermal-fade test — deduped into the 02:16 report's rows above so the same ask is not queued twice; #21 jam-recovery procedure → folded into the docs-refresh remainder row; #22 WiFi route → covered by the transport `[decision]` row.

---

## f) NEXT THINGS (impact-sorted; `[d]` dispatch-grade, `[r]` roadmap/decision; owner = this session unless marked)

1. `[d]` **[owner/root] Execute the Wave-6 restore** (command block handed off 07:10): stop paperless units → dropdb/createdb `paperless` → `pg_restore -d paperless /mnt/pool/backups/paperless/paperless-db-2026-10-19.dump` → start units. At report time the consumer reads **inactive** — restore appears in progress.
2. `[d]` **[me] Post-restore verification chain**: consumer back to active → waiting `test-receipt-biedronka.png` auto-ingested (it was dropped 05:07) → OCR deu+eng content present → document visible via API/UI → `paperless-gpt-token`, `paperless-dashboard-provision`, `bank-sync-paperless-token` self-heal (they failed on the empty DB).
3. `[d]` **[owner] Answer campaign duplicate policy** (b2): keep `DELETE_DUPLICATES=true` (jam-retry re-scans silently dropped) vs disable for the campaign window. Blocks bulk scanning.
4. `[d]` **[me] First timed batch** — 20 real receipts, measure consume→archive wall time (OCR deu+eng, 2 workers, FLM classify) → extrapolate 2000 (c4).
5. `[d]` **[me] Codify the scan profile** — wrapper script: `-d brother5:bus6;dev1 --mode '24bit Color[Fast]' --resolution 300 --source ADF(center) --AutoDocumentSize=yes --AutoDeskew=yes --batch=…`; drop into consume per doc; staging dir vs direct drop decided by b2.
6. `[d]` **[me] Duplex-or-simplex per media type** — receipts simplex (backs are watermark noise); invoices duplex. Test SkipBlankPage (also `[inactive]`-check first) for duplex invoice backs.
7. `[d]` **[owner] Calm-post-deploy smoke re-run** — 11 FAILs in the 06:19 run under 83% PSI; several (CV render STORM-SUSPECT, shell-startup WARN) are unverified; Bank-Sync sync_errors and Monitor365 CB-deadlock are the two that smell real.
8. `[d]` **[other-session/owner] Monitor365 agent CB deadlock** — auto-restart fired, agent still not connected (smoke FAIL); server reported 0 devices.
9. `[d]` **[other-session] node_exporter journal spam 506 lines/min** + `paperless-web 452/min` (the latter likely DB-error spam → expect self-heal post-restore; verify).
10. `[d]` **[other-session] textfile collector rejects `paperless_tasks.prom`** (value-less metric lines at :6/:12/:15 → whole file dropped → phantom-green risk for paperless alerts); post-restore, check whether the generator emits those lines only while the DB is empty.
11. `[d]` **[other-session] nsfw-classifier sustained 204% CPU** (§18 sanity FAIL) — hotloop class.
12. `[d]` **[other-session] FastFlowLM :52625 unreachable** post-deploy (EADDRINUSE corpse class was checked — not it; re-probe when calm).
13. `[r]` **Runbook: `docs/services/scanner.md`** (or paperless.md section): driver chain, profile, orientation doctrine, blank-media gotchas, ACL/group write path, jam/duplicate procedure (b4).
14. `[d]` **FEATURES.md + CHANGELOG entries** — brscan5 wiring, consume-dir group-writable fix, the regression + fix (honest incident line), scanner capability.
15. `[d]` **AGENTS.md routing line** — scanner questions → runbook (c3 of 02:16 report).
16. `[r]` **Candidate eval-time lint**: chmod/chown/install inside a non-`+` preStart of a hardened unit → warning (e1; the d1 class made structural).
17. `[r]` **Training milestone run** (c3) after the first ~50 real receipts: correspondents/tags → AUTO → Train Classifier → verify hourly task stays green (runbook documents the empty-vocabulary failure class).
18. `[r]` **Carrier sheet** for sub-50.8×70 mm slips (c5) — check the smallest receipts first.
19. `[r]` **PATCH-T separator workflow** — only if stack-scanning beats per-doc jobs for part of the campaign; sheets must be ordered.
20. `[r]` **Thermal-fade settings test** — one faint receipt at default vs contrast bump before bulk.
21. `[r]` **Jam-recovery procedure** into the runbook: what partial batches + re-feeds do under the chosen b2 policy.
22. `[r]` **(if WiFi ever wanted)** SMB-version probe or SFTP+pubkey destination; DNS/DHCP identity for the scanner; dnsblockd device-registry entry.
23. `[r]` **Date-extraction spot-check** on real receipts (`DATE_ORDER=DMY` set) after first batch.
24. `[r]` **Post-campaign pool/export note** — exporter + restic windows after bulk ingest; first post-campaign export must be green before victory is declared.
25. `[r]` **Canon PIXMA provenance** — is the original `hardware.sane.enable` reason still real? If dead, fix the stale comment (02:16 §e.2 carryover).

## g) QUESTIONS (cannot figure out myself)

1. **Wave-6 restore — who is running it?** At 07:23 the consumer is inactive, which matches restore step 1. If the owning session is executing it, I stand down and only verify afterward; if YOU are running my command block, say "done" and I verify. (Double-execution of dropdb/restore would be harmless-but-messy; coordination beats heroics.)
2. **RPO window bookkeeping:** between the 02:01 DR dump and the incident, did anything besides InboxClean's blocked uploads touch Paperless metadata that you care about? InboxClean auto-resumes (marker absent), so my default assumption is "nothing to replay" — confirm or correct.
3. **Duplicate policy for the campaign** (b2, carried from 02:16 §g3): keep `DELETE_DUPLICATES=true` (silent byte-identical drops, safe for jam-retries) or disable it for the campaign so every physical page is guaranteed archived and dedup happens by review?

---

*Report ends. WAITING FOR INSTRUCTIONS.*
