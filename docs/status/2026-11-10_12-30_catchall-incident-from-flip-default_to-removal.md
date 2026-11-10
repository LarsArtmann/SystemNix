# Status — [CATCHALL] application incident: From-flip, default_to removal, storm forensics

**Session:** 2026-11-10 ~11:45–13:00 CET · **Trigger:** owner paste of the
UBDS application email (`From noreply@larsartmann.cloud`, `To
applications@artmann.tech`, subject `[CATCHALL] Application: Cloud
Architect - Azure – Lars Artmann`, 02:33) + the two complaints: *"No reply?
Why don't you just send it from applications@artmann.tech?"* and *"The email
that was sent to the catchall was NOT readable - I only saw the plain
text."*

## a. What the forensics found (all journal/postfix-verified)

| # | Finding | Evidence |
| - | ------- | -------- |
| a.1 | **The UBDS application never reached UBDS.** The posting carries no contact email; the 2026-11-09/10-night `default_to = applications@artmann.tech` "fallback" (added to silence 28 ErrNoRecipient sendErrors) made the funnel mail the owner's OWN catchall and fold the row `applied`. | `cv.nix:612` pre-fix; postfix: 165 deliveries `to=<applications@artmann.tech>` today, each ~144 KB (CV PDF attached — the PDFs DID ride) |
| a.2 | **A bulk-approve send storm ran 00:15→~03:00.** An automated `POST /api/pipeline/approve-above` (Python-urllib, 127.0.0.1, 00:15:43 — the owner-directed 4th timer step, CV funnel.md line 51) bulk-granted the accumulated approval queue; `send_on_approve` + unbounded `go sendApprovedAsync` fan-out → 727 `MarkApplicationSent` dispatches, CPU 127 %, sqlite insert context-deadlines, **535 "send succeeded but recording failed"** events. | `journalctl -u cv-server` 00:15–03:00; counts by rg over the journal |
| a.3 | **~20 real recruiters received the same application 2–3×** (recording failure ⇒ approval stayed armed ⇒ sweep/manager retried; restarts re-armed via boot replay). Postfix recipients show ×3 clusters (talentacquisition@theverygroup.com, careers@estuary.dev, …). | postfix `to=<…>` uniq -c per recipient |
| a.4 | **The Resend daily quota was exhausted by the storm** — my 11:57 acceptance probe for the new From died `550 You have reached your daily email sending quota` at END OF DATA, **after MAIL FROM was accepted**. Queue is EMPTY now (postqueue -j); the bleed is capped for today by the quota itself. | postfix journal 11:57:06 |
| a.5 | `[CATCHALL]` subject prefix is NOT composed by CV (`DefaultSubject` = `Application: <role> – <name>` exactly); it is added downstream on the receiving/routing side (Google-side routing/catch-all tag — consistent with the [CATCHALL] subjects in the paperless bench corpus). Not chased further; no fix needed. | CV repo grep (zero hits); paperless bench subjects |
| a.6 | 11:02 anomaly (unattributed): one 1.4 KB mail `MAIL FROM applications@larsartmann.cloud` → julia.barth@constaff.com — NOT the CV smtp path (config from is noreply@; no CV code references that address). Most likely a parallel session's manual reply/follow-up. Flagged, not investigated further. | postfix 11:02:06 |

## b. Fixes landed this session

| # | Fix | Where | State |
| - | --- | ----- | ----- |
| b.1 | **From = applications@artmann.tech** (owner's explicit ask). Transport verified as far as the quota allows: DNS verification records LIVE (domains repo `resend_artmann_tech`: DKIM TXT + rsend/send CNAMEs + links, dig-verified), MAIL FROM accepted by the relay; the end-of-DATA 250 proof owes the quota-reset re-probe (TODO). If Resend ever rejects at DATA, sends defer and the Gatus "Mail Relay Queue" check fires — the designed signal. | SystemNix `cv.nix` `smtp.from`; committed (daemon carrier bdf610bdd) | deployed pending c.1 |
| b.2 | **`default_to` removed — permanently.** Owner ruling: an application NEVER mails the operator's own address; email-less postings fail safe with ErrNoRecipient (the pre-2026-11-09 contract, CV funnel.md line 51: "portal-form postings stay manual by structure"). Comment in cv.nix forbids re-adding it. | SystemNix `cv.nix` | deployed pending c.1 |
| b.3 | **HTML alternative MIME part** — every application mail becomes `multipart/mixed { multipart/alternative { text/plain, text/html }, pdf }`; HTML derived from the letter (escape + `<p>`/`<br>`, inline font/line-height only), optional `BodyHTML` override field on SendRequest. Fixes "only saw the plain text". | CV repo `career-pipeline/sender/smtp_sender.go` + 4 new tests | committed locally; ships with b.5 |
| b.4 | **Duplicate-resend hardening** — (1) `AutoSend.unrecorded` in-process guard: a transport success whose recording failed can never be re-sent by this process (blocked with "dedupe manually" contract, pinned by 2 tests); (2) process-wide send semaphore cap 2 in `sendApprovedAsync` (kills the concurrent-render → sqlite-deadline cascade that manufactured the 535 unrecorded sends). | CV repo `autosend.go` + `auto_apply_handler.go` | committed locally; ships with b.5 |
| b.5 | **CV code wave deploy leg** — push LarsArtmann/CV master (20 ahead of origin, owner-gated) → `nix flake lock --update-input cv` → vendorHash → deploy. | TODO rows in both surfaces | blocked:push |

Gates run: sender/applyflow/handlers go test suites green (handlers except
the PRE-EXISTING `TestEquivalence_PipelineDashboardPage` golden failure —
verified failing on clean HEAD during a stash window, a sibling's committed
dashboard change without its golden; not mine, not blind-fixed).
`buildflow --build-mode fast`: my legs green; the 2 failed steps
(`govalid-generate` + twin) are the sibling's in-flight templ v0.3.1100
drift — 3 consecutive runs, pre-existing. The stash-pop race with that
sibling's WIP (event_rehydrate wave) was resolved keep-HEAD-go.mods /
restore-their-sources; their files verified intact on disk.

## c. Deploy state

| # | Step | State |
| - | ---- | ----- |
| c.1 | Config wave deploy | REFUSED by the deploy lock — a sibling's `nh os switch` was already running (PID 1693773, lock `/tmp/.systemnix-deploy.lock`). Their switch, if evaluated after commit bdf610bdd (~12:2x), carries my cv.nix change; verification queued: rendered cv config in the new generation must show `from: applications@artmann.tech` + no `default_to`. If absent → re-run `nix run .#deploy`. |
| c.2 | Post-deploy probes | (1) rendered config check (c.1); (2) quota-reset From-acceptance probe (TODO row); (3) watch the next cv-scan pass (18:xx) for ErrNoRecipient sendErrors = the fail-safe working. |

## d. Damage ledger (owner-visible)

- 165 applications self-mailed to applications@artmann.tech (folded `applied`
  with `SentTo` = own address; replies structurally impossible — the owner's
  core complaint). Re-dispatch row queued (TODO).
- ~20 recruiters × 2–3 duplicate application mails from
  noreply@larsartmann.cloud (~144 KB, PDF attached) between 02:32–03:00.
- Resend daily quota exhausted (outbound mail from the relay capped for the
  rest of 2026-11-10).
- 1228 deferrals during the storm (retries; queue drained empty).

## e. Open owner legs

1. **O1 (unchanged, pre-existing row):** Google-side forward
   applications@artmann.tech → applications@larsartmann.cloud — still the
   missing leg for the REPLY LOOP (the owner reads replies at Google either
   way now that From = applications@artmann.tech).
2. **Push order** for b.5 (CV code wave) — say push and it ships.
3. Optional: apologies/dedupe contact for the ~20 duplicate-mailed
   recruiters (owner judgment; a `[decision]` if wanted).

## f. Direct follow-ups — ALL harvested

1. Quota-reset acceptance probe → TODO_LIST + services.md (ready) ✔
2. 165-row re-dispatch (recipient re-extraction / portal-apply routing /
   recruiter dedupe) → TODO_LIST + services.md (ready) ✔
3. CV code wave push + lock bump + vendorHash + deploy → TODO_LIST +
   services.md (blocked:push) ✔
4. Runbook updated: docs/services/cv.md "Continuous funnel automation"
   gained the step-4 incident contract ✔

## g. Attribution notes

- Shared-tree races this session: daemon committed my CV-repo waves
  (carriers 67a87f27a, e5989fdc0, 8e2f7d4cc — verified to contain exactly my
  5 files); one stash-pop conflict with a sibling's event_rehydrate WIP
  resolved without data loss; SystemNix cv.nix rode carrier bdf610bdd; a
  sibling's deploy lock-refused mine (by design).
- The `approve-above` automation itself is owner-directed (2026-11-09,
  funnel.md line 51) — the storm was the ACCUMULATED drain (670 approvals)
  meeting an unbounded dispatcher plus the default_to misconfiguration; the
  semaphore + guard + default_to removal close that class.
