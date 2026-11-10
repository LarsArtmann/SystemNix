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

1. **Config-wave deploy** — attempted twice, correctly REFUSED both times by the deploy lock (a sibling session's `nh os switch` ran ~12:2x→13:0x, generation system-996 landed; my commit bdf610bdd missed their eval window — verified their deployed `cv-config.yaml` still carries `from: noreply@…` + `default_to`). **Third attempt 15:5x (wait-loop had cleared: LOCK-FREE, QUIET-POLLS=3/3) was REFUSED by the deploy ENTRY I/O-pressure gate — the correct outcome under the freeze-prevention doctrine.** Addendum (16:15): a live IO-PSI storm was and is running — `some avg10` 45→56% sustained, guard Zone-6 trip #8772 at 16:08:51 with an EMPTY pausable tree. Attribution (sanctioned S-0035 probe set, stability.md): per-pid 6s delta showed NO writer >4.1 MB/s; cgroup 10s delta named **nix-daemon at 20.9 MB/s** (~2.4 KB avg IO = small-IO build churn at 87% Samsung util) — drivers are SIBLING build batteries (a `buildflow --fix --build-mode=full` run + `nix build .#checks.…format` + `.#checks.…telephony-voicemail`), not mine, not touchable (attribution-first/report-only doctrine). Per the freeze-#5 rule (queue the deploy when Zone 6 tripped within the hour — never race dips), the deploy is QUEUED behind the storm: a gated auto-refire loop is armed (fires only on 2×60s consecutive `avg10<20` + zero Zone-6 trips in 60 min + lock free; deploy.sh's own entry gates backstop it). **Not deployed as of 16:15; config wave still not live.**
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
2. **Duplicate-mailed recruiters:** ~71 real recipients got duplicate applications (up to 4× worst case, e.g. app-285 → product-jobs@neoshare.com at 00:41/01:44/02:35/06:52 — per the 16:20 addendum's journal counts) from `noreply@larsartmann.cloud`. Do you want a short apology/clarification note sent (from the new applications@ address), or let it rest silently?
3. **The 165 self-mailed rows:** where a posting HAS a real contact email, re-send properly (risking another contact attempt at companies that already received up-to-4× duplicates), or mark them lost and only pursue the portal-apply channel going forward?

---

**State at 13:29:** background wait-loop (lock + quiescence) RUNNING; deploy not yet fired; everything else per sections a–c. **Now waiting for instructions.**

**Addendum 16:15:** wait-loop cleared → deploy attempt #3 REFUSED by the ENTRY I/O-pressure gate (live Zone-6 storm, trip #8772; attribution: sibling nix build batteries at 20.9 MB/s small-IO churn). Deploy QUEUED behind the storm behind a gated auto-refire loop (avg10<20 ×2 + no Zone-6 trip 60 min + lock free). Still waiting for instructions on §g 1–3; the refire loop is the ONLY action that will run without them.

**Addendum 16:20 (parallel verification session — post-report send waves + queue disarm):**
- The storm did NOT stop at 03:00: journal "application sent" per hour today = 00h:13, 01h:51, 02h:474, 03h:54, 06h:135 (06:23 tick incl. real send app-10383), 12h:399 (gen996 switch restart boot-replay 12:37–12:53), 14h:9, 15h:159 (14:58–15:28 sweep) — **day total 1,294 sends, ~71 to real recipients, duplicates up to 4×** (app-285 → product-jobs@neoshare.com at 00:41/01:44/02:35/06:52), 961 `application.sent` shadow-append version_conflict warns and climbing (the recording-failure class — fixes committed, undeployed). The §a forensics table (00:15–03:00) and the "~20 double-mailed recruiters" count understate the day; §g2/§g3 should carry the 4× worst case.
- **Queue disarm 16:08–16:14:** postfix was STOPPED briefly (freeze during assessment), then the 20 deferred requests (recipients ONLY noreply@larsartmann.cloud + applications@artmann.tech — no recruiter mail) were `postsuper -h ALL deferred` HELD and postfix restarted active. The held entries cannot flush at the Resend quota reset; release deliberately (`postsuper -H ALL held`) only after the deploy verifies and the §g3 re-dispatch decision is made. Gatus Mail Relay Queue metrics carry a ~6-min postfix-down notch from the freeze. Additionally armed: transient timer `cv-queue-flush-guard.timer` (00:30 CET, 12×30min) re-holds the deferred queue ONLY while `/run/current-system` still points at the gen996 store path — belt-and-suspenders against the quota-reset flush if the float-register-blocked deploys (15:28/15:39/15:51 attempts all exit 12 on the hermes/go-humanize-linter broken floats) do not land before ~01:00. `systemctl stop cv-queue-flush-guard.timer` disarms it.
- **Live-unit verification correction (feeds the 05:01 CV handover's claims):** the cv-scan 4th step IS deployed and live on gen996 — `systemctl cat cv-scan.service | grep approve-above` FALSE-NEGATIVES because ExecStart is a store-path script (`/nix/store/g9fwpwzkmqif9xmcfgljjs115icp61nb-cv-scan`); grep the script itself. The 12:23 tick failed only because the gen996 switch restarted cv-server mid-tick (60s reachability wait expired; transient, next tick 18:23).
- Also killed: the orphaned `commit-task.sh --self-test` CPU loop pair (go-taskqueue, stuck since Nov 9 08:48 in a deleted /tmp scratch repo, ~2 cores for 29h).

**Addendum 19:00 — CONFIG WAVE IS LIVE (carried by the sibling's 17:55 deploy, not my loop).** My gated refire loop timed out 17:46 (storm held avg10 78%) and is retired — purpose fulfilled by the sibling's fourth `DEPLOY_FORCE_PRESSURE=1` attempt (17:33/17:37/17:47 died code=12 on the broken floats; 17:55 reached activation of `3yhv8kp5…-nixos-system-evo-x2-…f9a75f4`, which carries my cv.nix commit bdf610bdd). Evidence:

1. `/var/lib/cv/config.yaml` → `qyvjcjnxs…-cv-config.yaml` (flipped from `505w5f0a…`): `from: applications@artmann.tech`, `reply_to: applications@artmann.tech`, **no `default_to` key**.
2. Functional proof — first post-deploy auto-apply pass (18:26): `queued=5 sent=0 sendErrors=223`, every error the fail-safe `posting has no contact email and pipeline.autoapply.default_to is unset` — the pre-2026-11-09 contract restored in prod, ZERO self-mails composed.
3. Anchor verdict DEFERRED, not failed: at 18:5x the activation was legitimately still mid-flight (`nh os switch` + `switch-to-configuration test` alive ~55 min; ListJobs shows the transaction queued behind `post-crash-calm-gate.service`, which by design holds late starts until PSI calm — into a storm that keeps tripping Zone 6). The profile pointing at system-996 content is the EXPECTED mid-flight snapshot (the `nix-env --set` lands late, 2026-10-23 procedure). Post-completion check owed: `readlink /run/current-system` == newest `system-N-link`; divergence after the tree empties = the exit-14 UNANCHORED class → repair per the 2026-10-14 procedure (sudo).
4. The held queue (16:20 addendum's disarm) remains correctly held — the flush-guard's gen996 condition is now stale in the SAFE direction (current-system has moved past gen996's store path, but held mail never auto-releases; release stays the deliberate `postsuper -H` after §g3).

Remaining session state: waiting for §g 1–3; quota-reset probe row queued for the next CET morning.
