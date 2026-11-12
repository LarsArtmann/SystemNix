# Send-Hardening Closure — Full Session Status (a–g)

**Instance:** send-hardening-closure session, 2026-11-11 01:55 → 09:20 CET (owner
directive: execute the SUPERB plan until done; three owner turns mid-session:
G2 = rest, G3 = model mistakes, deploy-unblock = force).

**Headline: the at-most-once hardening chain is LIVE in prod** — the 07:33 sibling
deploy switched gen-999 at 07:49 carrying `cv-300bb9e` (verified from the running
generation's cv deriver), which contains EVERYTHING this workstream built:
durable send claims + cross-app (project, recipient) ledger, the transport
identity nets (deterministic Message-ID, `Resend-Idempotency-Key`, deterministic
MIME boundaries), role-key canonicalization, cross-process claim arbitration,
live submission occupancy, and the `cv claims` triage verb. The 09:14
owner-authorized confirmation deploy is in flight.

## §0 Verdict table

| Item | Verdict | Evidence |
| ---- | ------- | -------- |
| Chain deployed + live | **LIVE** | gen-999 = `cv-300bb9e` (deriver `ysz76q9k…-cv-300bb9e.drv`); cv rehydrated 07:49:50 — 47,975 events, 10,775 applications, queue 693 (the ledger folded ALL historical sends: the ~51 storm pairs are retroactively occupied) |
| Shadow-append warns (961-class) | **ZERO** | `journalctl -u cv-server` since 23:00 yesterday: 0 matches, incl. post-restart |
| T7 byte-identity | **VERIFIED deterministic — no softening** | typst-pdf path (`Flow.RenderVariantPDF`); wall-clock BANNED (docDate constant, parity-tested); `TestGolden_TypstPDF_{EN,DE,ReweDE}` byte-for-byte ×2 in-process + vs committed goldens |
| T11 role-key canonicalization | **LANDED + LIVE** | tokens sorted ("Azure Cloud Architect" ≡ "Cloud Architect Azure"); axes-first fold re-keys history at replay; parity + refusal tests |
| T12 cross-process arbitration | **LANDED + LIVE** | post-append scan, deterministic tiebreak, loser self-releases; `TestApprovalTracker_CrossProcessClaimRace_ArbitrationReleasesLoser` (caught my inverted tiebreak — fixed) |
| T13 live submission occupancy | **LANDED + LIVE** | `RecordSubmission` occupies immediately (axes from the handler's tracker); mutation-verified test |
| T8 `cv claims` verb | **LANDED + LIVE** | list / `--release --reason` / `--confirm-sent`; 9 tests; runbook recipe in `docs/services/cv.md`; deviation from plan documented (single-verb shape — cmdguard parents share flag structs) |
| G3 mistake modeling | **LANDED (post-999, rides next deploy)** | `application.misrouted` event + `RecordMisroute` command + `cv misroute` verb; all 5 ratchets; end-to-end re-drive test; ADR "Mistake Modeling" section |
| G2 apology | **DECIDED: rest** | draft + 51-recipient list archived `~/.cache/send-hardening/` (first-hand postfix-journal extraction; earlier "~71" overcounted) |
| T2 quota probe | **EXECUTED — verdict INVERTED (see d.1)** | postfix accepts locally, **Resend 550: artmann.tech domain NOT verified** — outbound is NOT restored; owner g-1 action with live evidence. Re-probed 2026-11-12 23:18 CET (residue continuation): **STILL 550**; larsartmann.cloud contrast-proven working the same minute (20/20 flushed held mails `status=sent` via the generic-map from-address) |
| T3 E2E idempotency | **SEND-SIDE DONE, blocked at Resend** | same-key probe pair relayed; both bounced on the unverified domain before any key logic could engage |
| T16 race pass | **CLEAN** | `-race` over eventstore/sender/applyflow: zero findings |
| T14 agentmail parity / T15 capability-scan rule | **LANDED** | ADR sections + CV AGENTS.md trap entry |
| T10.2 storm-night deploy log | **VERIFIED** | reached `deploy exited code=0 at 19:12:35 after 4598s` |

## a) Fully done

1. **The deploy chain up to and including the live switch** (T1): drv-equality
   pre-check → CV pushes (`5fce3e296`…`300bb9e77`, every landing file-verified
   after daemon-carrier races) → upstream vendorHash re-pin (graph-rag wave) →
   consumer-side cv.nix shim tracking the through-our-graph hash (`ZfCh3W9k…`) →
   lock pinned cv@`300bb9e77` + registry in sync → **toplevel keep-going proof
   GREEN** (float4; float3 caught the stale FOD first-hand) → gen-999 live →
   T1.8 journal verification green. The 09:14 confirmation deploy is running.
2. **All seven code tasks** (T7-T16 minus T9/T18, see c): tests green, lint
   clean on every touched package (devshell golangci, 0 issues), CHANGELOG rows
   per house canon, eventmap regenerated, daemon-carrier landings verified
   per-file at HEAD.
3. **G3 answered with landed code, not prose**: `application.misrouted`
   (reason enum catchall/wrong-recipient/non-delivery; explicit misrouted
   address; evidence note) — fold demotes EXACTLY-applied → ready (AppliedAt
   cleared, `[misroute]` note), ledger vacates the never-delivered pair
   (owner-checked: a correction can never strip a sibling's occupancy),
   reply-classed applications never demote. `cv misroute` is the operator verb.
   The 165-row triage becomes per-row corrections with evidence; rows where a
   REAL recruiter was contacted keep permanent occupancy.
4. **Surface reconciliation** (T17 for landed work): CV row 1985 items 1+4
   ticked; SystemNix rows 1083/3445 (tooling + occupancy) ticked in BOTH
   surfaces; quota-probe rows annotated with the corrected verdict; ship-rows
   1082/3444 close with the live switch (tick rides the confirmation deploy's
   anchor check).
5. **T10.4 flags filed, not touched** (foreign reds): portalapply godoclint ×2 +
   predeclared ×1; `internal/cli/ateam/cookie.go` unused import (already rowed);
   `scripts/portal-probe/portal-probe` 8.8 MB tracked binary churning in the
   CV worktree; root-module pre-existing lint (nolintlint ×1 + wrapcheck ×79)
   that blocked proper devshell commits of the last wave.

## b) Partially done

1. **Confirmation deploy** (in flight): anchor check (process tree gone, gen by
   NUMBER) + full battery still owed; smoke-baseline noise from the sibling's
   07:33 exit-3 (crm-server 201% CPU, node-exporter 599/min journal,
   forgejo-runner/SearXNG/tq smoke NEW-fails) may surface again — foreign
   domains, flagged not mine.
2. **T3**: send-side executed (pair relayed, journal-verified); the collapse /
   header-visibility / Date-header verdicts are impossible until Resend
   accepts mail from the domain again.
3. **T18 dashboard claim-triage**: event summaries + badges for the new events
   landed in code; the live dashboard render check rides the next deploy
   (gen-999 predates the misroute wave; claims-era summaries shipped in 999).

## c) Not started (honest)

1. **T5 execution** — the 165-row misroute triage itself (tooling landed;
   per-row `cv misroute` with evidence is a batch job against the store, best
   run when the Resend domain is re-verified so re-drives can actually send).
2. **T6 held-queue release** (after T5; `postsuper -H` needs the owner or a
   deploy-carried oneshot — sudo is dead in agent shells this session class).
3. **T9 quota observability** — deliberately held back (SystemNix module edits
   during the float/deploy churn would have voided every proof battery).

## d) Totally fucked up (nothing catastrophic; the honest list)

1. **The T2 first-read was WRONG for ~5 minutes**: I read postfix's local 250
   acceptance as "quota RESOLVED" and even fired the T3 pair on that premise;
   the journal check inverted it (Resend 550 domain-unverified at end-of-DATA).
   The plan's T2.2 branch anticipated exactly this; I initially reported the
   wrong branch. Caught by asserting WHICH hop the evidence covers — the rule
   bites again. Rows carry the corrected verdict.
2. **Inverted tiebreak shipped-then-caught** in T12 (the loop `continue`d on
   the WINNING competitor): caught by the failing race test before any commit —
   the test doing exactly its job, but the first version was wrong.
3. **A `pkg`/`pkgs` typo** in the shim edit (caught by my own re-read before
   eval could break; fixed via edit-tool).
4. **The float3 proof cycle (~20 min)** burned on a predictable FOD re-stale
   (`ZfCh3W9k…` after my code waves) — the documented source-churn class; the
   shim treadmill is the surface, the annotation records it.
5. **Carrier-heavy history**: the daemon won ~6 commit races tonight; every
   landing was verified per-file at HEAD afterward, but properly-messaged
   commits are the minority of the wave (the documented daemon-race pattern;
   the root-module pre-existing lint also blocked devshell commits — flagged
   in a.5).
6. **The misroute wave (G3) landed AFTER the final lock pin** — gen-999 does
   NOT carry `cv misroute` (it carries everything else). Sequencing lesson in
   e.3; one more pin+proof+deploy owes.

## e) What we should improve

1. **Transport verdicts read the JOURNAL hop, not the client's 250** — the
   postfix client acceptance is local truth only; end-of-DATA at the upstream
   relay is the verdict (d.1, second occurrence of the "which entity served
   it" class).
2. **The IO-PSI phantom blocked the deploy for hours while the discriminating
   evidence was one command away** (disks 1.1% busy, memory healthy, ghostty
   scopes at 100% io.pressure). Candidate row: teach the pressure gate to
   auto-classify the phantom (idle disks + zero D-state + per-cgroup
   ghostty-at-100) and WARN-and-pass instead of refuse — owner call, it
   weakens a freeze gate.
3. **Code waves sequence BEFORE the final lock pin** — the G3 implementation
   should have preceded float4; the re-pin+proof treadmill is the cost of
   getting this wrong (b.3 in d.6).

## f) Next (self-harvested — every item rowed or riding existing rows)

1. Confirmation-deploy anchor check + tick ship-rows 1082/3444 (in flight).
2. Re-pin cv to the misroute-wave tip + float proof + next deploy (ships
   `cv misroute` + the wave's tests) — rides the next natural deploy window.
3. **OWNER (g-1, live 550 evidence attached): re-add/verify artmann.tech in
   the Resend dashboard** (DNS records live, domains repo `resend_artmann_tech`)
   → re-run the T2 probe expecting `status=sent` → T3 receive-side verdicts
   (same-key collapse, header visibility, Date header).
4. T5 execution: per-row `cv misroute` over the 165 [CATCHALL] rows with
   evidence; T6 held-queue release after.
5. T9 quota observability (post-deploy window — module edits are safe again
   once the confirmation deploy anchors).
6. T18 dashboard render check (claims-era summaries in 999; misroute summaries
   next deploy).
7. Apology artifacts (`~/.cache/send-hardening/{apology-draft,storm-recipients}.txt`)
   keep-or-trash per owner taste (G2 = rest).

## g) Owner questions (all three answered in-session, restated)

- **G2 = rest** — no apology sent; draft + recipient list archived.
- **G3 = model mistakes** — landed as `application.misrouted` + `cv misroute`
  (full ADR section); the 165-row triage executes per-row with evidence.
- **Deploy force = authorized** — the confirmation deploy ran under
  `DEPLOY_FORCE_PRESSURE=1` through the ghostty IO-PSI phantom (disks 1.1%,
  memory healthy — the discrimination evidence is in the deploy log).
