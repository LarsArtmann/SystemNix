# Email-Native Dedup Verdict + Transport Identity — Self-Review Status

**Date:** 2026-11-11 00:58 CET · **Session:** continuation of the 2026-11-10 23:30 at-most-once close-out
**Trigger:** owner challenges, verbatim spirit — (1) "the ADR at docs/adr/2026-11-10_at-most-once-send-claims.md is also not right; Doesn't modern E-Mail have any way to prevent multiple duplicates?!" (2) "So Message-ID COULD HAVE HELPT as well as Resend (our upstream!) and we fucked it all up?" (3) READ/UNDERSTAND/RESEARCH/REFLECT → execute step-by-step until done.
**Scope of this report:** this session's run only (ADR repair, primary-source verdict, transport hardening). The claims-wave implementation itself was last session's; its state is carried only where this session touched it.

---

## §0 The verdict this session delivered (all primary-source verified)

| Net | Storm verdict | Evidence |
| --- | --- | --- |
| SMTP (RFC 5321 §6.1) | Duplicates **by design**: retransmission after a lost final `250` is required client behavior; spec only says receivers "MUST seek to minimize the time required to respond to the final `<CRLF>.<CRLF>`"; §3.5.4 even warns mail systems SHOULD NOT attempt MTA-side dedup tricks | rfc-editor.org/rfc5321.txt grepped raw; RFC 1047 (1988) is the canonical analysis RFC 5321 itself cites |
| Message-ID (RFC 5322 §3.6.4) | **Identification/threading only.** Uniqueness is a sender obligation; no receiver dedup obligation exists anywhere. "Could have helped" only cosmetically (undocumented Gmail-class collapsing) — and **saves zero quota** (quota burns at submission) | rfc-editor.org/rfc/rfc5322.txt §3.6.4 raw; the search sweep found NO Google/Microsoft documentation of receiver dedup — the absence is the finding |
| Sieve `duplicate` (RFC 7352) | The only standardized dedup — optional, per-mailbox, expiry-windowed MDA filtering on receivers we don't own | rfc-editor.org/rfc/rfc7352.txt (via verification sweep) |
| **Resend idempotency keys** | **The real miss, ours.** Shipped **2025-05-07** (engineering blog, raw-fetched: JSON-LD `datePublished`) — 17 months before our SMTP transport went live (2026-10-17). `Idempotency-Key` HTTP / `Resend-Idempotency-Key` SMTP header, 24h retention, ≤256 chars; same-key-different-payload rejected `invalid_idempotent_request` = fail-closed. One stable header per application would have collapsed/rejected every same-day storm re-send AND protected the quota | resend.com/docs/dashboard/emails/idempotency-keys + /blog/engineering-idempotency-keys raw-fetched and grepped |
| Root cause (re-confirmed) | None of the nets caused/prevented anything: durable "sent" state landed only AFTER transport → every recording failure re-armed. Sender-side durable claims are the only forever-guarantee | prior session's wave, undeployed |

**Conclusion encoded into the ADR:** no protocol or provider layer offers a per-recipient at-most-once contract; the invariant can only live in the sender's durable state.

---

## a) FULLY DONE (this session, verified)

1. **ADR repaired and completed** — `docs/adr/2026-11-10_at-most-once-send-claims.md`: (i) the mangled `approval.consumed`/`application.sent` parenthetical (sibling-session working-tree damage) restored; (ii) NEW "Alternatives Considered: Email-Native Dedup Does Not Exist" section with the verified table; (iii) launch-date + quota-burn sharpening; (iv) consequences bullet flipped to LANDED. Commits: authored `9a2cb8bbf`; later edits rode daemon carriers `b71d9df02`/`04cbda39f` (content needles verified at HEAD).
2. **Primary-source verification battery** — every external claim in the ADR was verified against raw bytes (RFC texts downloaded + grepped; Resend docs/blog fetched + grepped; `postconf header_checks`/`always_add_missing_headers` live on this box = empty/no → custom headers pass the local relay untouched). No summarizer-only claims were encoded (the one Gmail-class sentence is explicitly labeled undocumented best-effort).
3. **Transport hardening implemented and green** — `outboundMessageIdentity(appID, to)` in `career-pipeline/sender/smtp_sender.go`: one stable 64-bit sha256 identity per (application, recipient) now backs (i) the Message-ID `<cvapp.<identity>@<from-domain>>`, (ii) the `Resend-Idempotency-Key: cvapp/<identity>` MIME header, (iii) BOTH MIME boundaries (`cvapp-`/`cvapp-alt-` prefixed — the nested multipart/alternative boundary was a second entropy source found mid-test). Code rode carrier `40a399451`; docs in `e1b26cbc2`.
4. **Tests** — `TestOutboundMessageIdentity_StableAndDiscriminating`, `TestNewOutboundMessageID_Format` (rewritten for determinism), `TestBuildMimeMessage_CarriesMessageIDHeader` (+ key assertion), `TestBuildMimeMessage_ReComposedMessageIsByteIdentical` (the storm pin: re-composition → byte-identical). Suites: sender green, full career-pipeline module **GO-EXIT=0** (incl. eventstore parity batteries), applyflow `TestFlow_Storm...` green, root workspace build green, pre-commit hooks green (vet + build all modules); test-count guard auto-healed at **4106** (+2, exactly the new pins).
5. **Docs surfaces closed** — CV CHANGELOG wave bullet; CV TODO row annotated (CODE LANDED; E2E leg open); this report self-harvests its §f (new consolidated residue row in CV TODO_LIST: byte-identity verify/soften, header-visibility observation, Date-header check, agentmail parity).
6. **Push-state discovery flagged** — CV master incl. `be687de00` (claims wave) and this wave is **on origin** — pushed by daemon/owner, NOT by this session; discovered passively when a pathspec commit found the tree clean and in-sync. **Prod still runs the old at-least-once code** — the SystemNix deploy chain never ran.

## b) PARTIALLY DONE

1. **"Byte-identical message" claim** — pinned at the MIME layer for identical inputs (`buildMimeMessage` twice, same req). NOT verified for real re-sends whose ATTACHMENTS are re-rendered (Typst PDFs may embed timestamps → different bytes → Resend same-key-different-payload REJECTION — still fail-closed, still blocked, but not the cached-response path). Verification/softening rowed (CV TODO residue row item 1).
2. **E2E proof of the Resend header through postfix→Resend** — designed, blocked twice-over: Resend quota (resets CET morning 2026-11-11) and no deploy (owner-gated).
3. **ADR Gmail-class sentence** — honest but secondary-source-backed (verification sweep confirmed NO primary documentation exists; the doc says "undocumented, best-effort, uncontractual").

## c) NOT STARTED (in scope, owner-gated or out of this session's directive)

1. SystemNix deploy chain (flake lock `--update-input cv` → vendorHash fix → pressure-gated deploy → post-deploy claim verification).
2. Apology note (Q2) and the 165-row re-dispatch ruling (Q3).
3. Resend quota-reset acceptance probe (queued [ready], runnable CET morning).
4. agentmail transport idempotency parity (decision rowed, not designed).

## d) TOTALLY FUCKED UP

1. **(Inherited, re-confirmed with numbers)** The send path was built on an upstream whose capability surface was never scanned: Resend idempotency existed **17 months** before transport go-live, free, one header — and the original ADR shipped without even considering the question. It took the owner's challenge, not engineering discipline, to run the analysis.
2. **(Fresh, this session, mine)** The CHANGELOG/ADR say a re-composed application produces a **byte-identical message** — stronger than the evidence: the pin covers identical MIME inputs; attachment-render determinism is unverified. The doc claim out-ran the proof. Rowed for verify-or-soften; a one-line wording fix if Typst renders are nondeterministic.
3. **(Process, this session)** Discovered composition entropy **piecemeal**: wrote the byte-identity pin assuming only Message-ID mattered, then burned two test iterations discovering first the outer MIME boundary, then the nested alternative boundary. A 30-second entropy audit of the composition path (IDs, boundaries, clocks, render bytes) would have caught both — and would ALSO have flagged the attachment-render question before it shipped into the CHANGELOG.
4. **(Process, this session)** The 23:30 report's Q1 presupposed "CV 20 commits ahead, not pushed" — by session start that was already false (push happened). I caught it mid-commit (reactively), not at session start (proactively). The AGENTS owner-question rule says live-verify predicates; I did it late.

## e) WHAT WE SHOULD IMPROVE

1. **Capability-scan rule for every transport/provider integration** — at build time, scan and record (in the owning ADR): idempotency/retry semantics, rate/quota limits, dedup mechanisms, suppression lists. The Resend miss would have been structurally impossible under this rule. Candidate home: CV AGENTS.md / funnel.md trap register.
2. **Entropy audit before any determinism claim** — enumerate every nondeterministic input (random IDs, MIME boundaries, clocks, render timestamps) BEFORE writing "byte-identical" anywhere; the counterexample belongs inline in the claim.
3. **Inherited-question predicate checks at session START** — any session inheriting owner questions re-verifies their presuppositions (push state, lock revs, service state) before first action, not at first commit failure.
4. **Doc claims carry their verification perimeter** — "byte-identical (given stable attachment bytes; render determinism unverified)" beats a bare superlative.

## f) Next (ranked; not padded to 50 — these are the real ones)

1. Soften-or-verify the byte-identity claim: render the same application twice, byte-diff the attachments (rowed, CV TODO residue item 1).
2. E2E probe after quota reset + deploy: header accepted through postfix→Resend; second same-key submission collapsed or `invalid_idempotent_request`; whether the DELIVERED mail still carries the key header (rowed, residue item 2).
3. SystemNix deploy chain — owner-gated (Q1 remainder).
4. Apology decision (Q2) — draft ready on ruling; send only AFTER deploy.
5. Q3 ruling: ledger-wins (165 rows portal-only) vs deliberate operator override path.
6. Resend quota-reset acceptance probe (queued [ready] in both SystemNix surfaces).
7. Claim-resolution operator tooling + AMBIGUOUS journal triage UX (rowed 23:30).
8. `NormalizeRoleKey` token-order canonicalization + parity test (rowed, report §e.2).
9. Cross-process ledger race (two processes, same pair, no stream conflict) — store-level unique-index backstop candidate (rowed).
10. Live `application.submitted` ledger occupancy (portal-manual + auto-send one-process double-mail window) (rowed).
11. `Date` header check: `buildMimeMessage` emits none and postfix (`always_add_missing_headers = no`) won't add one — verify Resend stamps it; missing Date is a classic spam signal (rowed, residue item 3).
12. agentmail transport idempotency parity decision (rowed, residue item 4).
13. Capability-scan rule codified (e.1).
14. Targeted `go test -race` over claim/identity tests (rowed 23:30 §f).
15. Attribution record for carrier `40a399451` (code rode daemon carrier; CV attribution machinery).
16. Post-deploy: cv-scan watch + `2026-11-10_17-55-57.log` final-line verify (rowed 23:30 §f).
17. Resend quota observability: postfix 550-quota deferral metric → Gatus (rowed in SystemNix services.md).
18. Foreign gate-reds to owning sessions (ateam cookie.go — since fixed by sibling; templ-runtime drift) — flag only.
19. Sibling-owned lanes noticed, not touched: catch-all stranding aliases (noreply@/applications@ → applications@larsartmann.cloud), Google-forward test R1-series (their reports own them).
20. Consider surfacing the stable identity in the dashboard/tile triage (`SendClaimed()` list) once E2E lands.

## g) Owner questions (cannot be figured out myself)

1. **Deploy now?** Prod still runs the at-least-once code. Say the word and the chain runs: SystemNix `nix flake lock --update-input cv` → vendorHash (`buildflow -s nix-hash-fix --fix`) → pressure-gated deploy → post-deploy claim verification. (The push leg of the old Q1 is moot — origin already has everything, pushed outside this session.)
2. **Apology (Q2):** one short note per affected recruiter from applications@artmann.tech after deploy (my recommendation — also repairs sender reputation), or let it rest?
3. **Q3 × ledger conflict:** re-sending the 165 self-mailed rows "where a real contact email exists" will be REFUSED by the new ledger for companies whose recruiter already got storm mails — (a) ledger wins → those rows go portal-only/lost (my recommendation), or (b) build a deliberate operator override (retrack/"reapply" semantics)?

---

**Carriers/commits this session:** CV `9a2cb8bbf` (authored, ADR analysis), `b71d9df02`/`04cbda39f` (daemon carriers, ADR sharpening — needles verified), `40a399451` (daemon carrier, smtp_sender.go + test), `e1b26cbc2` (authored, CHANGELOG/TODO/ADR LANDED). SystemNix: this report (+ CV TODO residue row via pathspec).
**Suites at close:** career-pipeline GO-EXIT=0; sender green incl. 5 identity/determinism pins; applyflow storm pin green; root build green; hooks green; test-count 4106 healed.
