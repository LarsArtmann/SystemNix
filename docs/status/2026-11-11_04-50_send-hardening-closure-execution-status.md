# Send-Hardening Closure — Execution Status (2026-11-11 04:50 CET)

**Instance:** the send-hardening-closure session (owner directive: execute the SUPERB
plan until done). **Plan:** `docs/planning/2026-11-11_01-10_SUPERB-send-hardening-closure-pareto-plan.md`
(tombstoned EXECUTING at `cf9fb4a22`). **Scope:** T1–T18.

## Verdict table

| Task | State | Evidence |
| ---- | ----- | -------- |
| T7 byte-identity verify | **DONE — DETERMINISTIC, no softening** | Send path renders via `typst-pdf` (`Flow.RenderVariantPDF`); wall-clock BANNED (PDF dates derive from the `docDate` constant, parity-tested vs cv.typ); `TestGolden_TypstPDF_{EN,DE,ReweDE}` byte-for-byte green ×2 in-process AND vs committed goldens (104269/107367/107361 bytes both runs). ADR annotated ("Attachment renders close the byte-identity loop") |
| T8 claim tooling | **DONE — `cv claims` verb** (deviation: single-verb + `--confirm-sent` instead of `resend` subcommand — cmdguard parents require shared flag structs; the confirm-sent/release pair IS the operator decision) | CV `b684a00c3`+carriers: bare=list (age/axes/recipient, --json), `--release <app> --reason` (verified non-delivery → approved, sweep re-drives), `--confirm-sent <app>` (records send + consumes approval, pair occupied forever); store-direct under the CLI-wide lease contract (exit 16 while server owns store); 9 tests; SystemNix `docs/services/cv.md` triage recipe landed |
| T11 role-key canonicalization | **DONE** | `NormalizeRoleKey` sorts tokens ("Azure Cloud Architect" ≡ "Cloud Architect Azure"); ledger fold derives claim keys AXES-FIRST from payload company+role under CURRENT normalization (future key-space changes re-key all history at replay); no prod claim events exist (undeployed) so the move re-keys nothing live; parity + refusal + negative-control tests green |
| T12 cross-process arbitration | **DONE** | Post-append arbitration scan over committed `send.claimed` events (serialized appends + committed reads = double-miss structurally impossible); loser (later ts; ties → lower appID) self-releases with audit reason, `ErrClaimArbitratedAway` refuses the send; failed scan fails closed (claim parks); `TestApprovalTracker_CrossProcessClaimRace_ArbitrationReleasesLoser` (caught an inverted tiebreak live — fixed) |
| T13 live submission occupancy | **DONE — mutation-verified** | `RecordSubmission` occupies the ledger immediately (`OccupySubmitted`, axes from the handler's tracker, nil-guarded for tracker-only wirings); `TestAutoSend_LiveSubmissionOccupancy_CrossApplicationRefused` fails with the hook disabled (mutation-tested), passes through the server's real single-graph wiring |
| T14 agentmail parity memo | **DONE** | ADR "AgentMail Parity" section: ledger-level guarantee already transport-agnostic; transport nets gated on a capability scan of the AgentMail API before wiring; unverified provider capabilities never asserted |
| T15 capability-scan rule | **DONE** | ADR "Provider Capability-Scan Rule" + CV AGENTS.md Traps entry ("Provider Capability Scan"): every transport/provider integration records idempotency/retry/quota/dedup semantics in its owning ADR at build time, primary-sourced + dated; review-blocked without the table. (The plan's "ADR template note" is moot — no template file exists; the AGENTS.md trap IS the enforcement surface) |
| T16 targeted race pass | **DONE — CLEAN** | `go test -race` over eventstore (92.5s) + sender + applyflow claim/storm tests: zero findings |
| T1 deploy | **PROOF-GREEN, awaiting pressure window** (details below) | Lock pins cv@`300bb9e77` (the complete chain); registry in sync; toplevel keep-going proof GREEN (float4, `float-proof-20261111-042752.log` + the green round); IO PSI 68–76% for 40+ min (a sibling's pbx-aarch64 toplevel build) refuses the pressure-gated deploy |
| T2 quota probe | **QUEUED — ~07:00 CET** (quota reset) | Row live in both surfaces |
| T3 E2E idempotency proof | **BLOCKED on T1+T2** | Probe design in 00-58 §b.2 |
| T4 apology | **DRAFT READY for G2** | 51 distinct real recipients extracted FIRST-HAND from the postfix journal (full 2026-11-10, self-addresses excluded; saved `~/.cache/send-hardening/storm-recipients.txt`) — NOTE: earlier reports said "~71", the wire says 51 distinct recruiters (the 71 likely counted applications/companies, not recipients); draft at `~/.cache/send-hardening/apology-draft.md` |
| T5 165-row triage | **GATED on G3** | Ledger refuses re-sends to already-stormed recruiters by design — the re-dispatch/override question is the owner's |
| T6 held queue | **after T5** | 20 held self-mails verified earlier |
| T9 quota observability | **NOT STARTED** (SystemNix module edits held back until the deploy lands — quiescence discipline) | Rowed |
| T10 watches | **T10.2 DONE** (17-55-57 log reached `deploy exited code=0 at 19:12:35 after 4598s`); T10.1/10.3/10.4 below | — |
| T17 surface reconciliation | **DONE for landed work** | CV TODO row 1985 items 1+4 ticked (evidence cited); SystemNix rows 1083/3445 ticked in BOTH surfaces (`2badaf660`); ship-rows 1082/3444 tick AT DEPLOY |
| T18 dashboard verify | **after deploy** | — |

## T1 deploy state (the 1%)

Everything up to the switch is DONE and proven:

1. `cv` pushed through `300bb9e77` (+ daemon carriers); SystemNix lock pins exactly
   that rev; `flake/expected-locks.nix` in sync (lock-float gate green).
2. Upstream vendorHash re-pinned once (graph-rag v0.5.0 wave, got-hash `78uA13…` at
   `5fce3e296`, FOD-proven first-hand); the consumer-side cv.nix shim tracks the
   through-our-graph hash (`ZfCh3W9k…` at `300bb9e77`, first-hand from
   `float-proof-20261111-042752.log`) — the two graphs legitimately diverge, the
   shim is the documented surface.
3. Toplevel keep-going proof GREEN twice (float3 caught the stale FOD; float4 green
   after the shim update; the daemon landed lock+registry pairs mid-proof,
   content-verified by float-register each time).
4. Deploy BLOCKED only by the pressure gate: IO PSI 68–76% for 40+ min (sibling's
   `pbx-aarch64` toplevel build, pid 2900897). A background poll watches for
   PSI < 20%. `nix run .#deploy` → anchor check (full process tree gone, gen by
   NUMBER) → `scripts/post-deploy-check.sh` + journal verification
   (`send.claimed` live, `ApprovedPendingSend` excludes claims, shadow-append
   warns stopped) remain.

## Foreign-wave interactions (attributed, not mine)

- A sibling's **fleet pin-lift wave** (48bba022b) raced this session all night:
  registry/lock churn, two transiently-broken FODs (golangci-lint-auto-configure,
  discordsync — their shims landed 03:40–03:51), and an incomplete lift ritual
  (allowlist row removed while the `?rev=` URL stayed — eval broken tree-wide for
  ~6 min) that resolved itself when the sibling re-registered the row with fresh
  tip-probe evidence. No action needed from this session beyond waiting out the
  ceremonies.
- **Latent lint debt surfaced and fixed** (this workstream's own daemon-carrier
  bypasses, per the documented trap): smtp_sender wrapcheck ×2 (SetBoundary
  wrapped), catalog funlen (SendClaimed/SendReleased compacted, EventApproved
  summary shortened). CV devshell `golangci-lint`: 0 issues on all touched packages.
- **Flagged to owning sessions (T10.4, not touched):** portalapply godoclint ×2 +
  predeclared ×1 (sibling's module); `internal/cli/ateam/cookie.go` unused import
  (already rowed 23:30 §f17); `scripts/portal-probe/portal-probe` binary churns in
  the CV worktree (8.8 MB tracked binary rebuilt by the sibling's runs).
- **Carrier attribution (T10.3):** the transport-identity code rode daemon carrier
  `40a399451` (previous session); tonight's T11/T12/T13 waves rode carriers
  `2bc5b6a27`/`d4a50b1f7`/`240037c4c` + properly-messaged commits `2c25d0a39`/
  `300bb9e77`; every landing verified per-file at HEAD (the daemon-race
  discipline).

## Owner gates (G2/G3 restated; G1 = go was granted by the directive)

- **G2 (apology):** draft above; 51 recipients; send ONLY after deploy + quota
  reset (morning). Send or let it rest?
- **G3 (165-row re-dispatch):** (a) ledger wins → mark portal-only/lost
  (recommended), or (b) build a deliberate `Reapply` override command.
- Morning legs for the next session: T2 quota probe (~07:00 CET), T3 E2E proof,
  T4/T5 per gates, T6 held-queue release, T9 quota observability (after deploy),
  T18 dashboard verify, ship-row ticks 1082/3444.
