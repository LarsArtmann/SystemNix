# STATUS — [CATCHALL] incident session: From-flip, default_to removal, send-storm forensics & hardening

**Session:** 2026-11-10 11:45–13:29 CET (report at 13:29) · **Session type:** ad-hoc owner escalation (pasted UBDS email) → incident + fix session
**Trigger:** owner paste of the 02:33 UBDS application email (`From noreply@larsartmann.cloud` → `To applications@artmann.tech`, subject `[CATCHALL] Application: Cloud Architect - Azure – Lars Artmann`) with: *"No reply? Why don't you just send it from applications@artmann.tech?"* then *"1. Why did you send this email to applications@artmann.tech and not to the real project owners?! 2. The email that was sent to the catchall was NOT readable - I only saw the plain text."*

**Companion artifacts:** detailed incident report → `docs/status/2026-11-10_12-30_catchall-incident-from-flip-default_to-removal.md` (this file is the session-wide status the owner asked for; the 12-30 file is the technical evidence chain — both are current).

---

## a) FULLY DONE (verified)

1. **Full incident forensics** (all journal/postfix/dig-verified, table in the 12-30 report):
   - The UBDS application never reached UBDS — posting has no contact email; the `default_to = applications@artmann.tech` fallback (added 2026-11-09/10-night to silence 28 ErrNoRecipient sendErrors) made the funnel mail the owner's own catchall and fold the row `applied`. **165 such self-mailed applications** today.
   - **Send storm 00:15→~03:00:** the owner-directed 4th timer step (`POST /api/pipeline/approve-above?min=2.9`, automated, Python-urllib) bulk-granted ~670 accumulated approvals; unbounded `go sendApprovedAsync` fan-out → 727 `MarkApplicationSent`, CPU 127 %, sqlite insert deadlines, **535 "send succeeded but recording failed"** → sweeps/manager retried → **~20 real recruiters received the same application 2–3×**.
   - **Resend daily quota exhausted** by the storm (my 11:57 probe: MAIL FROM accepted, then `550 You have reached your daily email sending quota` at end-of-DATA). Postfix queue EMPTY since (bleed capped for today by the quota itself).
   - `[CATCHALL]` subject prefix is NOT composed by CV (zero repo hits; `DefaultSubject` = `Application: <role> – <name>`) — added on the receiving/routing side (Google-side routing tag; consistent with paperless-bench corpus subjects). No fix needed.
   - PDFs DID ride the mails (~144 KB each) — complaint #2 was the missing HTML rendering, not a lost attachment.
2. **SystemNix config wave (committed; rides the next deploy):**
   - `cv.nix smtp.from = "applications@artmann.tech"` — owner's explicit ask. Transport verified as far as the quota allows: DNS verification records LIVE (domains repo `resend_artmann_tech`: DKIM TXT + rsend/send CNAMEs + links, dig-verified), MAIL FROM accepted by the relay; end-of-DATA 250 proof owed after quota reset. Failure mode if unverified: defer-queue + Gatus "Mail Relay Queue" check (the designed signal).
   - **`default_to` removed permanently** (owner ruling recorded in cv.nix comment: an application NEVER mails the operator's own address; email-less postings fail safe with ErrNoRecipient; portal rows wait for `cv portal-apply`).
   - Eval-verified: `settings.pipeline.smtp.from = applications@artmann.tech`, autoapply renders WITHOUT default_to. Formatted with the scoped pinned formatter.
3. **CV repo code wave (committed locally; ships after owner-gated push):**
   - **HTML alternative MIME part** — `SMTPSender` now builds `multipart/mixed { multipart/alternative { text/plain, text/html }, attachments }`; HTML derived from the plain letter (escaped, `<p>`/`<br>`, inline font/line-height only) or verbatim from the new `SendRequest.BodyHTML` field. Fixes "only saw the plain text". 4 new tests incl. escaping/override/empty-body pins.
   - **Duplicate-resend guard** — `AutoSend.unrecorded` in-process map: a transport success whose recording failed can never be re-sent by this process (blocked with "dedupe manually" contract). 2 new tests.
   - **Send fan-out cap** — process-wide `approveSendSlots` semaphore (cap 2) in `sendApprovedAsync`: kills the concurrent-Typst-render → sqlite-deadline cascade that manufactured the 535 unrecorded sends. Documented in funnel.md as a trap line.
   - Gates: sender/applyflow/handlers suites GREEN; `buildflow --build-mode fast`: my legs green.
4. **Docs (all landed):** cv.md runbook step-4 incident contract; 3 TODO rows in BOTH surfaces (TODO_LIST queue + services.md library — no drift); CV funnel.md 2 new trap lines; CV CHANGELOG entry; full incident report (12-30).

## b) PARTIALLY DONE

1. **Config-wave deploy** — attempted twice, correctly REFUSED both times by the deploy lock (a sibling session's `nh os switch` ran ~12:2x→13:0x, generation system-996 landed; my commit bdf610bdd missed their eval window — verified their deployed `cv-config.yaml` still carries `from: noreply@…` + `default_to`). A background wait-loop (lock-free → 3×60s quiescence polls) is RUNNING now; deploy fires after it clears. **Not deployed as of 13:29.**
2. **From-flip end-to-end proof** — MAIL FROM accepted; the end-of-DATA 250 verdict is blocked on the Resend daily quota reset (probe row queued).
3. **CV code wave reach-prod** — commits live locally (daemon carriers 67a87f27a, e5989fdc0, 8e2f7d4cc — verified to contain exactly my 5 files); origin push + `nix flake lock --update-input cv` + vendorHash + deploy = owner-gated (blocked:push row).

## c) NOT STARTED (deliberately)

- Re-dispatch of the 165 self-mailed rows (row queued; needs dashboard/API + dedupe against the ~20 already-duplicated recruiters).
- Anything about the 11:02 unattributed mail (`MAIL FROM applications@larsartmann.cloud` → julia.barth@constaff.com, 1.4 KB — not the CV smtp path; flagged, most likely a parallel session's manual reply; NOT investigated per "no unrelated research").
- The sibling-owned pre-existing reds (see d): golden + govalid — deliberately not touched.

## d) TOTALLY FUCKED UP (my mistakes this session, all recovered)

1. **`perl -0pi` file-header strip destroyed the original `autosend_double_send_test.go`** (regex `.*?` with /s matched from file start — deleted package+imports+all original tests). Recovered via `git restore` — but the daemon had committed my intermediate state, so restore resurrected a first-draft test block → duplicate declarations → fixed with a targeted range-delete. Net: file verified correct, tests green. Lesson: never strip-to-anchor with greedy /s patterns on shared files mid-daemon-window; edit-by-edit instead.
2. **`git stash` raced the sibling's WIP** on the shared CV tree: my stash swept their dirty `event_rehydrate` wave + 7 go.mod files; the pop conflicted (UU ×7). Resolved keep-HEAD-go.mods / restore-their-sources; their files verified intact on disk. Lesson: on this tree, `git stash` is a weapon — status-pin immediately before and never stash when the tree holds foreign dirt.
3. **Test helper took 3 iterations** (line-by-line base64 decode → header-after-CTE section bug → preamble segment bug). Should have written the part-decoder properly the first time.
4. **`multipart.NewWriter(nil)` nil-writer flaw** in my first builder draft — caught at build, fixed with an explicit buffer.
5. **Misread 528 postfix `from=` lines vs 234 `status=sent` as a pending queue backlog** — actually per-retry re-activations; `postqueue -j` proved the queue EMPTY. Corrected before it changed any decision.
6. **Probe side-effect:** my quota probe's bounce generated a DSN to `applications@artmann.tech` that itself bounced at Resend (`550 Invalid from` — null-sender DSNs rejected). One noise mail in the owner's inbox class; cosmetic, known class.

## e) WHAT WE SHOULD IMPROVE (systemic, from this incident)

1. **Exactly-once sends need an outbox pattern** (record-send-intent BEFORE transport). My semaphore + guard remove the observed failure mode; a crash between transport and record still re-sends after restart. The at-least-once design is documented intent — but the storm proved its cost under bulk load.
2. **`approve-above` needs its own drain-burst bound** (e.g. max grants per pass, like `max_per_pass=5` caps tailoring). The staleness cap only covers OLD grants; a fresh bulk grant fired everything at once.
3. **Resend quota is invisible** — the storm silently ate the day's quota; a Gatus check / textfile metric on postfix `550 …quota` deferrals would have surfaced it immediately.
4. **Config keys that fake success are a class** — `default_to` turned "fail safe with a typed error" into "mark applied + mail myself". The repo now forbids it in a comment; an eval-time guard (reject any default_to that matches own domains) would make it mechanical.
5. **Deploy lock contention is the norm on this tree now** — my two refused deploys were CORRECT behavior, but the config wave still isn't live 1h after commit. The wait-loop pattern should be the standard, not improvisation.
6. **20-commits-ahead origin drift on CV** means prod runs an old binary whenever the push is owner-gated — the HTML fix exists in code but cannot reach prod until pushed. Consider a standing push policy for fix-waves.

## f) NEXT (session-derived, ranked)

1. Fire the deploy when the wait-loop clears (job running); verify deployed `cv-config.yaml`: `from: applications@artmann.tech`, no `default_to`.
2. Post-deploy: restart-verify cv-server boots clean on the new config; watch the 18:xx cv-scan pass for ErrNoRecipient sendErrors (= fail-safe working).
3. Quota-reset From-acceptance probe (row queued).
4. Owner push order → CV master push → `nix flake lock --update-input cv` → vendorHash (`buildflow -s nix-hash-fix --fix` if FOD trips) → deploy → verify HTML alternative on a live send.
5. Re-dispatch the 165 [CATCHALL] rows (re-extract recipients; dedupe vs already-mailed recruiters; portal rows → `cv portal-apply` queue).
6. Owner decision: contact the ~20 duplicate-mailed recruiters or let it rest.
7. O1 Google forward applications@artmann.tech → applications@larsartmann.cloud (pre-existing blocked:user row — the reply loop still needs it).
8. Storm alerting: the HighErrorRate/HighCPU alerts fired INSIDE cv-server only — route the auto-send recording-failure ERROR to the OnFailure/Discord channel.
9. approve-above batch cap (config + handler bound).
10. Outbox/exactly-once design for the send path (ADR-level).
11. Resend quota observability (postfix 550-quota deferral metric → Gatus).
12. Eval-time guard: `default_to` must never match an own domain (mechanize the ruling).
13. Recipient-extraction gap check: sample postings that ErrNoRecipient — some likely carry contact emails the regex misses (the "send to the REAL owners" ask).
14. UBDS row specifically: confirm portal vs email; route to portal-apply or a real address.
15. Sibling-owned reds (not mine): `TestEquivalence_PipelineDashboardPage` golden update; govalid-generate templ v0.3.1100 drift (3 consecutive buildflow runs).
16. Attribute the 11:02 `applications@larsartmann.cloud` mail (one pgrep/journal sweep when convenient).
17. Confirm the [CATCHALL] prefix source definitively (Google admin routing rule) — one owner glance.
18. Semaphore configurability: promote cap 2 to config if drains feel slow.
19. Unit test for the semaphore itself (currently covered indirectly by handler suites).
20. CV origin-drift watchdog (local master vs origin/master delta → warn).
21. Post-deploy smoke addition: rendered cv config asserts (from-address, no default_to) — cheap greps in post-deploy-check.sh.
22. CRM mirror: the 165 self-mailed rows created opportunities keyed to a dead SentTo — clean the Kith board during re-dispatch.
23. DSN null-sender bounces at Resend (cosmetic; consider postfix `bounce_notice_recipient` tuning or ignore).
24. The storm's 1228 deferrals skewed mail-relay metrics today — sanity-check the Gatus Mail Relay Queue check recovered.
25. Session-hygiene: this session ran three background jobs; confirm all are reaped after the deploy fires.

## g) QUESTIONS (cannot figure out myself)

1. **Push order:** may I `git push` LarsArtmann/CV master (20 commits ahead — my send-hardening wave + ~15 sibling/daemon commits incl. the templ-drift era) and then run the cv lock-bump + vendorHash + deploy chain? The HTML-mail fix and the duplicate-resend guard cannot reach prod without it.
2. **Duplicate-mailed recruiters:** ~20 real recipients got the same application 2–3× from `noreply@larsartmann.cloud` between 02:32–03:00. Do you want a short apology/clarification note sent (from the new applications@ address), or let it rest silently?
3. **The 165 self-mailed rows:** where a posting HAS a real contact email, re-send properly (risking a second contact attempt at companies that already received duplicates), or mark them lost and only pursue the portal-apply channel going forward?

---

**State at 13:29:** background wait-loop (lock + quiescence) RUNNING; deploy not yet fired; everything else per sections a–c. **Now waiting for instructions.**
