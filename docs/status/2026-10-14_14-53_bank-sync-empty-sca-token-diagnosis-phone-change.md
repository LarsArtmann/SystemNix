# Status Report — bank-sync `empty_sca_token` outage diagnosis (Wise phone-change class)

**Session date:** 2026-10-14 13:35–14:53 CEST
**Author:** Crush agent session (diagnosis + docs + queue maintenance)
**Scope:** ONLY this session's work and what it noticed. No other domains researched.
**Commit:** `2900aeda` (4 files, +50/−2, on `master`, ahead 4 of origin, unpushed by policy)

---

## TL;DR

The user changed their Wise phone number (~2026-10-09 20:2x). Since **2026-10-09 20:31:23** Wise has answered every statement request with a 403 carrying the `x-2fa-approval-result` verdict header but **no `x-2fa-approval` one-time token (OTT)**. bank-sync's transfers fallback deliberately refuses loudly on a token-less challenge (`bank.empty_sca_token`), so every cycle hard-fails instead of degrading: **20/20 balances, 132 consecutive failed cycles, 5 days** as of diagnosis. The dashboard approval flow cannot start either (its probe needs an OTT; Wise issues none). This is **not fixable server-side** — the runbook now documents the wise.com re-arm steps; the actual unblock is owner hands on wise.com (web statement challenge → dashboard OTP with the new number → backfill).

The session also exposed a **monitoring blind spot**: `bank_sync_sca_approval_pending` stayed **0** for the entire 5-day total statement outage (the gauge counts ApprovalBlocked verdicts, which require a token — a token-less challenge errors out instead), so the SCA Gatus check stayed GREEN and only the sustained-failure check paged, ~33h late. Queued as a bank-sync fix.

---

## Timeline (all times CEST unless marked Z)

| When | What |
| --- | --- |
| 2026-09-30 | SCA re-armed (90-day class); OTP undeliverable — Wise held a **wrong phone number** (terminal root cause found 2026-10-07 session) |
| 2026-10-08 18:19Z | Last known statement-backed window boundary (`from:` in today's error context) |
| 2026-10-09 20:19:21 | Last healthy-degraded sync cycle (transfers fallback OK, `approval_token_issued=false`, PID 501752) |
| 2026-10-09 20:30:59 | Clean systemd restart of bank-sync (the user's phone-change window) |
| 2026-10-09 20:31:23 | **First `bank.empty_sca_token`** — first sync after restart, all balances, new PID 1598206 |
| 2026-10-12/13 | (Adjacent, pre-session) go-cqrs-lite re-pin crash-loop class; rollback deployed 10-13 14:53 |
| 2026-10-14 02:00 | Durable `?rev=` pin of bank-sync input at `67dd64526` deployed (system-881) — daemon correct since |
| 2026-10-14 13:29 | User's dashboard attempts: "sca panel probe" + "sca send probe" both ERROR `empty_sca_token` (request_ids `6acf677f…`/`6acf6781…`) |
| 2026-10-14 13:35–14:45 | This session: full log read, source verification, live /metrics, runbook + queue updates, commit `2900aeda` |

---

## a) FULLY DONE (evidence attached)

1. **Root-cause diagnosis of the 5-day outage** — Wise issues no OTT after the phone change; verified three ways:
   - Journal: onset exactly at the first sync after the 20:30:59 restart (2026-10-09 20:31:23), persisted across **3 different daemon binaries** (1598206 → 10-13 rollback → current 3845279) — conclusively external.
   - Source: `bank-sync internal/bank/wise/adapter.go:384-388` → `internal/bank/sca_token.go:21` (`NewSCAApprovalToken("")` → `bank.empty_sca_token`), fallback refusal is deliberate design; wise-go v0.13.0 `errors.go` `isSCAChallenge` fires on **either** 2FA header → SCAChallengeError with empty token is a real Wise response shape.
   - Live `/metrics` (python urllib probe): `bank_sync_sync_consecutive_failures{wise} 132`, `bank_sync_sync_sustained_failure 1`, `bank_sync_sca_approval_pending 0` (the gap, see d.3).
2. **Runbook addendum** — `docs/services/bank-sync-sca.md`: new section "Failure mode — registered phone changed or unreachable → `bank.empty_sca_token` everywhere" (both phone classes, `sca send` journal forensic, backfill-refused-is-expected, 5-step remedy) + renewal-procedure **Step 0** prerequisite question. Committed `2900aeda`.
3. **Gotcha bullet** — `docs/services/bank-sync.md`: the no-OTT class, distinct from regional-restriction and wrong-number classes, with monitoring note. Committed `2900aeda`.
4. **Queue maintenance, no drift** — `docs/todo/services.md`: stale 2026-10-07 wrong-phone row evolved to the current post-change state (5 user steps); runbook-gap row from the Oct-7 session **closed as DONE**; new `[ready]` row for the sentinel classification fix. `TODO_LIST.md` queue one-liner added under `### services`. Committed `2900aeda`. `scripts/check-todo-system.sh`: **"OK: TODO queue/library structure clean"**.
5. **Service health verified live** — daemon up (PID 3845279), running the durably-pinned rev `67dd64526` (the re-float-immune `?rev=` pin is in flake.nix, lock confirmed), listening `127.0.0.1:8097`, `banksync.home.lan` resolves. No deploy needed or performed this session.
6. **Commit hygiene under the daemon race** — the auto-commit daemon swept my 3 doc files into `b7d2fb13`; verified via `git show --stat` that it contained exactly my files (no foreign files absorbed), then amended forward into properly-messaged `2900aeda` including the then-dirty `TODO_LIST.md`. Tree clean after.
7. **Cleanup** — throwaway `/tmp/wise-sca-probe.sh` trashed; working tree clean (`git status --short` = 0 lines).

## b) PARTIALLY DONE

1. **THE FIX — bank-sync working again.**
   - Works: complete diagnosis; remedy documented in the runbook; queue rows current; service running on the correct pinned rev.
   - Remains: the actual unblock is **owner hands**: (1) wise.com login confirms the new number receives codes, (2) wise.com: view a statement → complete the WEB challenge (re-arms OTT issuance), (3) dashboard → Approve now → Send code → OTP → auto-sync, (4) backfill the 10-09→approval statement gap, (5) one post-approval restart clears the restart-cumulative error counter.
   - Blocker: owner only (wise.com + the phone). Effort: **S** (~5 minutes of user time once started).
2. **Sentinel classification fix (verdict-only 403s keep `sca_approval_pending` at 0).**
   - Works: fully specified fix shape queued (blocked-unapprovable verdict → gauge set → degraded-not-failing where safe → surface the non-secret verdict value).
   - Remains: implementation on bank-sync master (nothing written yet), then the deploy chain.
   - Blocker: deploy-gated by the durable `67dd64526` pin (re-bump blocked on go-cqrs-lite stream-key compatibility — upstream.md row). Effort: **M** code + **L** deploy chain.
3. **Gatus live-state verification for the 4 bank-sync checks.**
   - Works: I read `/metrics` directly (the truth source); module config known.
   - Remains: verify the four checks' rendered Gatus state (status API is OIDC-gated; row 376 already queued for this).
   - Blocker: OIDC-gated status API from an agent session. Effort: **S**.
4. **Raw-verdict confirmation (what exactly does `x-2fa-approval-result` say?).**
   - Works: a sudo-scoped probe script was drafted (`/tmp`, later trashed) that would print the verdict header + OTT-presence boolean, masking the OTT.
   - Remains: it never RAN — `/run/secrets` is root-only, the rendered template is bank-sync-user 0400, and `sudo` is banned for agent shells. The verdict value is still UNKNOWN.
   - Blocker: agent-side privilege boundary (hard). Effort: **S** for the owner (runbook's `sca status` covers it).

## c) NOT STARTED

1. **Post-approval verification battery** — sentinel flip, streak reset, gatus green ×2, backfill row count, errors_total cleared, FX totals render (leg (d) of the sentinel row). Waits entirely on b.1. Priority: **the** next agent task once the user approves.
2. **Implementation of the verdict-only-403 classification** (b.2) — queued, zero code written.
3. **Pre-commit fast-guard honesty fix** — the hook's nixpkgs guard conflates "nix eval failed" with "lock regressed" (see d.2). Self-harvested during authoring: queue row added to `docs/todo/pipeline.md` + `TODO_LIST.md` (see Self-harvest disposition).
4. **105 unharvested §f-bearing status reports** — `check-todo-system.sh` WARN backlog (docs-health HARVEST sweep). Noticed this session; untouched; pre-existing.
5. **Oct-7 session leftovers noticed but not touched** (all already queued): incident narrative in bank-sync.md once fixed (`blocked` on the user fix); 5 leaked `bank-sync demo` test instances cleanup; upstream pre-send obfuscated-phone-hint (`blocked:push`); python-urllib /metrics recipe fold into monitoring runbook.

## d) TOTALLY FUCKED UP (radical honesty)

1. **My first edit to `docs/services/bank-sync.md` clobbered the timestamps bullet.** I passed the *header portion* of an existing bullet as `old_string` and my new bullet as `new_string` — the replacement destroyed the original bullet's opening (its tail "— Wise demands …" dangled after my text on one line). Caught by a `sed` inspection immediately after (the tool result looked wrong), repaired in the next edit, final state re-verified (both bullets intact, tail line verified via `rev|cut`). **Lesson:** for prose bullets, `old_string` must include the ENTIRE bullet or a fully unique anchor, and `new_string` must re-include everything replaced. A reviewer-free path to this bug is one more unchecked "looks fine" away — the repair was verified, but only because I inspected.
2. **The pre-commit hook's nixpkgs guard lies when nix is unavailable/gated.** My amend failed with "nixpkgs flake.lock regression … The global Nix registry rewrote nixpkgs to a tarball" — **false**: the tree's lock is fine (`original.type: github`, verified by direct JSON read). Real cause: the nix **heavy gate** (freeze-storm protection, active from a prior session's trip) refused the guard's `nix eval`, the hook swallows stderr (`2>/dev/null`), empty output → `"unknown"` → wrong error message pointing me at "fix flake.lock". I nearly went lock-hunting for a non-existent regression. Resolved correctly (diagnosed the gate via `/proc/pressure/io`, used the documented `NIX_HEAVY_GATE_FORCE=1` escape with written justification — docs-only amend, io avg10 52% < the 80% storm line, no build in the hook path) — but the hook's failure mode is a bug: **a gated/unavailable nix must not be reported as a lock regression.** Self-harvested (c.3).
3. **The sentinel blind spot (system-level, pre-existing, now diagnosed + queued):** a **total 5-day statement outage** kept `bank_sync_sca_approval_pending` at **0** and the SCA Gatus check **GREEN** the whole time. The gauge's contract ("latest cycle left any balance blocked on a Wise SCA approval") only covers ApprovalBlocked verdicts; the token-less class errors out instead, and the only signal was `sync_sustained_failure` — 33h late and non-specific. This is exactly the phantom-green class the 2026-10-07 sentinel work was built to kill, surviving one layer deeper.
4. **The causal attribution has a hole I must name:** the phone-change → no-OTT chain is inferred from **timing** (last healthy-degraded sync 20:19:21, restart 20:30:59, first failure 20:31:23, user's own statement that they changed the number) plus the code-path analysis — **not** from the verdict header value, which was never observed (d/b.4). If the number was actually changed at a different time than the restart window, the attribution weakens (though the no-OTT state itself is fact, and the re-arm remedy applies regardless).

## e) WHAT WE SHOULD IMPROVE

1. **Hook error honesty (the d.2 class):** any hook leg that shells out with stderr swallowed converts an infra refusal (heavy gate, missing binary, env drift) into a false domain-specific error. Fix the nixpkgs guard to distinguish rc≠0 from content and print the stderr tail; then sweep ALL pre-commit legs for the same pattern. Impact: saves the next agent from a phantom lock-hunt (this one cost ~3 tool calls and could have cost a lock "fix").
2. **Heavy-gate ↔ hook interplay:** the gate's refusal text is good, but its cooperation model assumes the caller surfaces it. Hooks that discard stderr break the contract. A tiny `scripts/lib` helper ("run nix, on gate-refusal print its message and skip with SKIP (not FAIL)") would fix the class once.
3. **Sentinel semantics need a third state:** approval-pending today means "token in hand, waiting for the human". The token-less state ("blocked and UNAPPROVABLE") is operationally more urgent and currently invisible. Either widen the verdict contract or add `bank_sync_sca_blocked_unapprovable`. (Folded into the queued fix shape.)
4. **Surface the verdict, not just the bool:** `x-2fa-approval-result` is a non-secret verdict code that would have made this class self-diagnosing from the journal alone. The OTT is secret; the verdict is not. Fix shape (c) of the queued row.
5. **Runbook lag:** the SCA error template's own Fix line ("Trigger a fresh challenge by viewing a statement on wise.com") has been correct in the binary since 2026-10-08/09 — but the runbook didn't connect it to the phone-change class until today. Runbooks lag failure modes by weeks (Oct-7 gap → closed today). The closing move each time: when a session diagnoses a NEW failure class, the runbook section lands in the SAME commit as the diagnosis (done today — keep doing it).
6. **Agent privilege boundary documentation:** this session burned calls discovering (again) that service envs are unreadable to agents (`/run/secrets` root-only, rendered templates user-0400, `sudo` banned). The AGENTS "verified live-probe set" section should state it explicitly: "service envs are NOT agent-readable; use /metrics + journal only; secret-bearing probes are owner-run". Self-harvested (c.3 second row).
7. **My own edit discipline (d.1):** bullet-level edits get whole-bullet `old_string`s; anything else risks exactly this clobber. No new tooling needed — a personal rule.

## f) NEXT TASKS (ranked; "up to 50" treated as a cap — 30 real items beat 50 padded ones)

Legend: **Status** = `already-queued` (row exists — do NOT double-queue), `new→harvested` (queued during this report's authoring), `roadmap-fuel` (deliberately not queued — needs refinement/owner appetite), `user-gated`.

| # | Task | Impact | Effort | Category | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | Owner: wise.com re-arm (web statement challenge) → dashboard Approve now → OTP → auto-sync | Critical | S | Ops | user-gated (library row owns the 5 steps) |
| 2 | Owner: run the degraded-banner backfill after approval (restores 10-09→approval deposits) | Critical | S | Ops | user-gated |
| 3 | Owner: one bank-sync restart after approval (clears restart-cumulative `bank_sync_sync_errors_total` for the deploy smoke) | High | S | Ops | user-gated |
| 4 | Agent: post-approval verify battery — sentinel 0, streak reset, both Gatus checks green, backfill rows landed, FX totals render | Critical | S–M | Quality | waits on #1–3 (c.1) |
| 5 | Implement verdict-only-403 → blocked-unapprovable verdict (sets pending gauge; degraded-not-failing where safe; surface verdict value) on bank-sync master | High | M | Bug | already-queued (today, services.md + queue) |
| 6 | Deploy chain for #5 — rides the go-cqrs-lite stream-key re-bump unblock (`67dd64526` pin lift) | High | L | Bug | already-queued (upstream.md) |
| 7 | Pre-commit nixpkgs fast-guard: distinguish nix-failure (gate/unavailable) from lock regression; print stderr tail; SKIP not FAIL on gate refusal | Medium | S | Quality | **new→harvested** (pipeline.md + queue, this report) |
| 8 | Sweep ALL pre-commit legs for stderr-swallowed infra refusals (the d.2 class, not just the nixpkgs guard) | Medium | M | Quality | **new→harvested** (same row as #7) |
| 9 | AGENTS.md agent-probe note: service envs are NOT agent-readable; /metrics + journal only; secret-bearing probes are owner-run | Low | S | Documentation | **new→harvested** (pipeline.md + queue, this report) |
| 10 | Verify live Gatus state for the 4 bank-sync checks (status API OIDC-gated; recorded-verdict pattern) | Medium | S | Quality | already-queued (row 376) |
| 11 | Surface `x-2fa-approval-result` (non-secret) in SCA rejection contexts so the class is self-diagnosing from journals | Medium | S | Feature | already-queued (folded into #5 shape (c)) |
| 12 | Decide: separate `bank_sync_sca_blocked_unapprovable` gauge vs widened pending-gauge contract (design call with #5) | Medium | M | Feature | roadmap-fuel (design successor of #5) |
| 13 | Resolve the 105 unharvested §f status reports (docs-health HARVEST sweep) | Medium | L | Cleanup | noticed this session; pre-existing backlog |
| 14 | Clean the 5 leaked `bank-sync demo` test instances (random ports, /tmp go-build exes) | Low | S | Cleanup | already-queued (services.md) |
| 15 | Record the full incident narrative (dates, obfuscated-number evidence, resolution) in bank-sync.md once resolved | Low | S | Documentation | already-queued (waits on #1) |
| 16 | Upstream bank-sync: pre-send obfuscated phone hint on the approval panel (would have cut the Oct-7 session to one turn) | Medium | M | Feature | already-queued (blocked:push) |
| 17 | Fold the python-urllib `/metrics` probe recipe into the monitoring runbook durably | Low | S | Documentation | already-queued (monitoring.md row) |
| 18 | Window `bank_sync_sync_errors_total` by restart epoch or rate (restart-cumulative counter keeps deploy smoke red post-approval) | Medium | M | Quality | already-queued (services.md) |
| 19 | bank-sync-paperless post-deploy smoke probe (mint + archival oneshots) | Medium | S | Quality | already-queued (services.md) |
| 20 | bank-sync→Paperless archival post-deploy verify (Persistent catch-up run) | Medium | S | Verification | already-queued (blocked:deploy) |
| 21 | Backfill-button UX: the degraded banner was mis-clicked as the approval surface (Oct-7) — separate/relabel the two CTAs | Low | S | Feature | roadmap-fuel (upstream UX) |
| 22 | `sca status`: default-filtered mode (token line behind an opt-in flag) so non-owner surfaces can run it without OTT-leak risk | Medium | S | Feature | not harvested — CLI contract change needs owner call |
| 23 | Dashboard probe copy: distinguish "no challenge issued" (unapprovable) from "challenge pending" (approvable) | Medium | S | Feature | roadmap-fuel (pairs with #5/#11) |
| 24 | Runbook: explicit detection signature for the THIRD class (plain 403 with NO 2FA headers = regional restriction) as its own subsection | Low | S | Documentation | roadmap-fuel (runbook polish) |
| 25 | Alert enrichment: sustained-failure Discord push could attach the SCA runbook link + the failure-class hint | Low | M | Feature | roadmap-fuel |
| 26 | go-cqrs-lite stream-key compatibility restoration (unblocks #6 and the whole bank-sync bump chain) | High | L | Bug | already-queued (upstream.md) |
| 27 | Re-bump rehearsal note: expected preflight exit-65 signature + preflight expectations for the eventual pin lift | Medium | S | Documentation | roadmap-fuel (rides #26) |
| 28 | Challenge-count observability (618 cumulative challenges noted Oct-7) — a Wise-side anomaly signal | Low | M | Feature | roadmap-fuel |
| 29 | Verify SSE dashboard repaint under a REAL approval (the repaint claim has never been observed live) | Low | S | Quality | roadmap-fuel (natural part of #4) |
| 30 | Backfill idempotence check post-approval (run twice; second run must land 0 rows) | Low | S | Quality | roadmap-fuel (natural part of #4) |

**Self-harvest disposition (per the AGENTS.md authoring rule):** items #7, #8, #9 landed in `docs/todo/pipeline.md` + `TODO_LIST.md` during authoring. Deliberately NOT harvested: #12, #21–25, #27–30 (roadmap-fuel: unrefined ideas or natural parts of already-queued work — per harvest anti-patterns), #22 (owner call on CLI contract), #1–3 (user-gated; library row 374 owns them — queue items would mis-dispatch agents).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Did you complete the wise.com re-arm and dashboard approval — and did the code actually arrive at your NEW number?** And was the change self-service in the app, or did Wise Support require ID verification? (If Support was involved, the account may sit in a partial state that explains a persistent no-OTT even after re-arm — that would change the remedy. Everything downstream — backfill, restart, the #4 verify battery — unblocks on this.)
2. **What phone number did Wise hold BEFORE the change — fully dead (ported away), or still receiving?** The 2026-10-07 session left exactly this question open; it decides whether the Sep-30→Oct-9 window has side effects worth treating (e.g., Wise-side fraud holds from repeated undeliverable codes).
3. **Should the break-glass OTT path (`EnvironmentFile = -/var/lib/bank-sync-sca/token.env` on the unit) stay at all?** It has been dead weight since the dashboard flow landed 2026-09-16, and this incident proved the glass it breaks is unreachable without owner hands anyway. Keep as disaster rope, or remove as config surface? (Policy call — the fact it's still wired I verified in `bank-sync.nix`.)

---

## Environment notes (for the next session)

- Heavy gate was ACTIVE at commit time (prior session's trip, <60 min window). IO PSI avg10 was 52% (below the 80% storm line). The amend used the documented FORCE escape with written justification.
- `git status` clean at authoring end; `master` ahead 4 of origin, unpushed (policy: never push unless asked).
- `/tmp/wise-sca-probe.sh` was trashed; no stray artifacts left.
