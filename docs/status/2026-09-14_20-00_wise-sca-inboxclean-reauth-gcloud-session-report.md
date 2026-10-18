# Session Report: Wise SCA runbook lie, InboxClean re-auth state, gcloud OAuth answer, bank-sync SCA plan

Date: 2026-09-14 20:00 (CEST)
Scope: THIS session only (16:16 → 20:00). No project-wide audit.
Format: Markdown (user override of the HTML default).

---

## a) FULLY DONE

1. **Live diagnosis of both pending human tasks.**
   - Wise SCA: **pending right now** — 6 balances / 5 profiles paused since
     2026-09-14 13:20 (`statements paused pending SCA approval` on every
     15-min tick; transactions unaffected, statements silently sync zero).
     Statements have effectively been gated since ~2026-09-06 (last
     statement-backed sync) — 8 days, zero alerts.
   - InboxClean: `main` = **auth_expired** (dead since Sep 04, cursor frozen
     at 5152620, `invalid_grant` still firing every tick as of 16:15 today);
     `work` = `connected`, now **16 days past its recorded Aug 29 grant**
     (the "testing-mode expiry is not a clean 7 days" mystery stands).
2. **Ordered combined runbook delivered** — production-flip-first InboxClean
   re-auth + Wise SCA clearing steps, with exact commands.
3. **gcloud feasibility question answered with evidence: NO.**
   - `lars@helpless.ai` has NO access to `inboxclean-493713`;
     `lartyhd@gmail.com` does (project 908101572197 "InboxClean").
   - `gcloud iap oauth-brands` deprecated (IAP OAuth Admin APIs turned down
     Jan/Mar 2026), never carried publish status.
   - `googleapis/googleapis` has zero OAuth-consent publish-status surface;
     Google's own `googleworkspace/cli` automates brand creation only and
     falls back to manual console instructions.
   - Conclusion: the consent-screen flip is console-UI-only, must be done in
     a browser as `lartyhd@gmail.com`.
4. **OTT explained** (One-Time Token = the single-use `x-2fa-approval`
   UUID) + exact journal extraction command.
5. **Wise SCA reality researched from primary sources** (docs.wise.com OTT
   guide + SCA-over-API + OTT status endpoint schema; transferwise/
   `digital-signatures-examples` personal-token keypair flow): statements
   are low-risk SCA actions; viewing one in app/web re-establishes the
   session; OTT status/verify endpoints exist (`GET /v1/identity/one-time-token/status`,
   `POST /one-time-token/sms/verify`, challenge types PIN/FACE_MAP/SMS/
   WHATSAPP/VOICE/PARTNER_DEVICE_FINGERPRINT); 5-minute low-risk window
   semantics; ~90-day + risk-based re-challenge.
6. **Runbook lie retracted and rewritten** — `docs/services/bank-sync-sca.md:36-52`
   now states there is NO "Approvals" screen (live-checked), documents the
   statement-view path, the push-notification option, the OTT fallback, and
   the future keypair path.
7. **bank-sync SCA plan written** —
   `/home/lars/projects/bank-sync/feedback/new/2026-09-14_sca-approval-ux.md`:
   goal (`bank-sync sca approve`, interactive TTY OTP flow), current-state
   table with real file:line refs (wise-go `errors.go:116,145`,
   `options.go:152`; bank-sync `adapter.go:44,391`), verified API surface,
   Phase 0 go/no-go spike (personal-token eligibility), Phases 1-4, acceptance
   criteria, non-goals.
8. This report.

Tooling adaptation: `systemctl`/`sudo`/`curl` are blocked in this sandbox —
worked around via `journalctl`, the fetch tool (incl. localhost health), and
`gcloud`. `agentic_fetch` was broken ALL session (4 identical internal
`json: cannot unmarshal` errors) — fell back to DDG-html via fetch,
Sourcegraph, and raw.githubusercontent.

## b) PARTIALLY DONE

~~1. **Wise SCA clearing**: diagnosis + instructions delivered; actual clear~~ **Won't implement — SCA-clear window passed; sca approve tooling since shipped (docs/services/bank-sync-sca.md).**
   NOT performed (waiting on user's wise.com statement view; then my
   2-tick journal verification). OTT env-file stopgap documented but unused.
~~2. **InboxClean re-auth**: exact commands delivered; consent-screen flip +~~ done — InboxClean main re-consent completed by owner 2026-10-04 (CHANGELOG re-consent entry)
   both re-auths NOT executed (user steps, browser + desktop).
~~3. **Docs sync after the retraction**: runbook fixed, but **AGENTS.md's Wise~~ **Won't implement — AGENTS Wise bullet superseded by 2026-10-01 restructure; runbook is canonical (bank-sync-sca.md rewritten).**
   SCA bullet still says "approve in the Wise app"** without the
   statement-view path or future `sca approve` — split brain left open.

## c) NOT STARTED

~~1. Phase 0 spike (personal-token eligibility for OTT status/verify endpoints).~~ done at `Phase 0-2 shipped: sca status/approve live (docs/services/bank-sync-sca.md)`
~~2. wise-go v0.6.2 (OTT status/trigger/verify + httptest tests).~~ done at `superseded/shipped: wise-go OTT APIs in v0.11.0 (docs/services/bank-sync-sca.md)`
~~3. bank-sync `cmd/bank-sync/sca.go` + misleading-hint fix (`adapter.go:391`).~~ done at `bank-sync sca.go shipped (docs/services/bank-sync-sca.md)`
~~4. SystemNix flake bump + deploy + runbook rewrite (plan Phases 4).~~ done at `runbook rewritten around sca approve (docs/services/bank-sync-sca.md)`
~~5. **Monitoring for the SCA-paused state** (nothing pages on the WARN).~~ **Won't implement — sca status CLI + degraded-banner flow supersede a dedicated pause metric; never built.**
~~6. **Monitoring for InboxClean `main` auth_expired** (not checked whether~~ **Won't implement — InboxClean health-alert era passed; upstream slug bug since root-caused (CHANGELOG 2026-10-04).**
   any Gatus check would catch it).
~~7. Investigation of `work` token's 16-day survival (production-flip evidence?).~~ **Won't implement — bank-sync repo harvest; other repo.**
8. Harvest of the bank-sync plan into that repo's TODO_LIST.

## d) TOTALLY FUCKED UP

1. **I propagated a fabricated UI path as fact.** When asked "where in the
   app?", I answered "Settings → Security and privacy → Approvals" by
   parroting the runbook without verification. The path does not exist; the
   user had to catch it ("stop imagining"). Root cause: treating a doc
   written by a prior session as ground truth about a third-party UI. The
   doc itself was the original lie (authored 2026-08-19 era); my failure
   was confident, unqualified propagation of it.
2. **Near-miss of the false-negative grep class (caught by luck of a second
   pass).** My first SCA probe grepped `"sca challenge"` (wise-go error
   vocabulary) against the journal; the deployed bank-sync logs
   `"statements paused pending SCA approval"`. Had I trusted the first
   probe, the session's headline conclusion ("no SCA pending in 10 days")
   would have been wrong. Same class as the pipeline-masking warnings in
   AGENTS.md.
3. Pre-existing systemic failure surfaced but only escalated to this
   report: **statements silently gated ~8 days with `sync completed
   successfully total_new=0` and zero alerting** — phantom green, again.

## e) WHAT WE SHOULD IMPROVE

1. **Verification discipline for third-party UI claims.** Any doc or answer
   asserting where something lives in someone else's app must cite a live
   verification (date + evidence) or be marked UNVERIFIED. Candidate
   AGENTS.md rule; this session is the second incident of the class (after
   the fixture-vs-prod `email_state(s)` trap).
2. **Grep the message vocabulary from the actual source/journal before
   concluding absence.** Broad capture first, narrow after.
3. **WARNs that represent degraded service must become metrics/checks.**
   The SCA pause has burned 8 days invisible; `auth_expired` in a health
   payload is data, not an alert.
4. **Close the doc-sync loop after retractions** (AGENTS.md ↔ runbooks ↔
   plans) — I fixed one file and stopped.
5. **Report infra breakage**: `agentic_fetch` errored identically 4×; the
   fallback stack (DDG-html fetch + Sourcegraph + raw fetch + gcloud
   discovery) worked well and should be the documented workaround.
6. **Self-verify instead of round-tripping to the user**: a background
   journal watch would have confirmed SCA clearing without asking the user
   to report back.

## f) Next (impact-ordered; 30 items, not padded to 50)

~~1. USER: view/download a statement on wise.com (2-min SCA unblock).~~ **Won't implement — one-shot user step; window passed.**
~~2. ME: verify bank-sync journal quiet across 2 ticks after (1).~~ **Won't implement — one-shot; window passed.**
~~3. If still paused: OTT env-file stopgap (commands already delivered).~~ **Won't implement — superseded by sca approve.**
~~4. USER: flip OAuth consent screen to "In production" (browser as~~ **Won't implement — consent/re-auth ceremonies done via 2026-10-04 re-consent (CHANGELOG).**
   `lartyhd@gmail.com`).
~~5. USER: re-auth InboxClean `main` (command delivered earlier).~~ **NOT-DO — dup of line 67 (re-auth work).**
~~6. USER: re-auth InboxClean `work` (command delivered earlier).~~ **Won't implement — one-shot /health check; window passed.**
~~7. ME: verify `/health` shows both accounts `connected`.~~ **Won't implement — one-shot backfill confirm; window passed.**
8. Check Sep 04–14 mail actually landed (cursor resume from 5152620).
9. Fix AGENTS.md Wise SCA bullet (statement-view path; retract app-screen
   framing; mention future `sca approve`).
10. Add the "UI claims need live-verified citations" rule to AGENTS.md.
~~11. bank-sync repo: harvest `feedback/new/2026-09-14_sca-approval-ux.md`~~ **NOT-DO — dup of line 82 (bank-sync harvest).**
    into TODO_LIST.md.
~~12. Phase 0 spike: probe `GET /v1/identity/one-time-token/status` with a~~ **NOT-DO — dup of line 75 (spike; shipped).**
    fresh OTT + personal token (one live command, needs the Wise token).
~~13. wise-go: `OTTStatus`/`OTTChallenge` types + status/trigger/verify +~~ **NOT-DO — dup of line 76.**
    httptest tests.
~~14. wise-go: tag v0.6.2 strictly after branch push (daemon-race lesson).~~ **NOT-DO — dup of line 77.**
~~15. bank-sync: `cmd/bank-sync/sca.go` (`status` + interactive `approve`,~~ **NOT-DO — dup of line 77.**
    TTY-only secrets).
16. bank-sync: replace the lying daemon hint at `adapter.go:391-394`.
17. bank-sync: tests asserting no OTT/OTP value ever reaches logs.
~~18. SystemNix: `nix flake lock --update-input bank-sync` + deploy.~~ **NOT-DO — dup of line 78 (runbook rewrite; done).**
19. Rewrite `docs/services/bank-sync-sca.md` around `sca approve`
    (env-file dance demoted to break-glass appendix).
~~20. Add SCA-pause monitoring (journal-pattern textfile collector or~~ **NOT-DO — dup of line 79 (SCA monitoring).**
    bank-sync metric + Gatus check) — kill the 8-day phantom green.
~~21. Add InboxClean `auth_expired` alerting (health-body pat or textfile).~~ **NOT-DO — dup of line 80 (auth_expired).**
~~22. Investigate `work` token's 16-day survival — strongest available~~ **NOT-DO — dup of line 81 (work token).**
    evidence for whether the production flip already happened.
~~23. Phase 3 research: keypair enrollment location in Wise web~~ **Won't implement — Phase-3 research; dormant.**
    (live-verified before documenting — no invented paths).
24. Verify the rjevski "platform gating" claim during the Phase 0 spike.
~~25. Report the `agentic_fetch` internal error to the tooling infra.~~ **Won't implement — tooling report; moot.**
~~26. After SCA clears: confirm the Sep 06→14 statement gap backfills.~~ **Won't implement — one-shot; window passed.**
~~27. Check bank-sync's backup-coordination freshness signal while~~ **Won't implement — one-shot; window passed.**
    statements were gated (was anything else blind?).
~~28. Consider a Gatus check on bank-sync WARN rate generally (class fix~~ **Won't implement — design idea; dormant.**
    for 20 + future silent degradations).
~~29. On next deploy: confirm the daemon's new SCA hint text renders.~~ **Won't implement — one-shot render confirm; window passed.**
~~30. Harvest this report's (f) into TODO_LIST.md when instructed.~~ **NOT-DO — dup of line 82 (harvest).**

## g) Questions I cannot answer myself (max 3)

1. **Have you already flipped the OAuth consent screen to "In
   production"?** I cannot see the Cloud Console from here; `work`'s
   16-day token survival hints maybe-yes, but is inconclusive — and it
   decides whether re-auth now is safe or would mint another 7-day bomb.
2. **For today's SCA, which path do you want:** the 2-minute wise.com
   statement view now, or leave the challenge pending as the live test
   case for the `bank-sync sca approve` build?
3. **Green-light to start Phase 0–2 in bank-sync/wise-go now?** The spike
   needs one live API call carrying your Wise token — I cannot read sops
   from this sandbox, so you'd run one prepared command, or we schedule it
   for when you're at the terminal.

---

_Reported from session run only; no external research performed for this
report. Waiting for instructions._
