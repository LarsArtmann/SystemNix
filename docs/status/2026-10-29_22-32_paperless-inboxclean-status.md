# Status: Paperless-ngx + InboxClean — scoped two-service snapshot

**Session:** 2026-10-29 22:30–22:3x · live-probed (busctl unit states, ss, journalctl, paperless_tasks.prom, pgrep redacted) + docs/todo sweep. Scope: the user asked "Paperless-ngx and InboxClean — for the past, how are we doing?" No tree or config changes.

**Live unit verdict at probe time (22:3x):**

| Unit | State | Note |
| --- | --- | --- |
| paperless-web / -consumer / -task-queue / -gpt / -gpt-token | active | core stack green; gpt pinned 0.28.0 |
| paperless-db-backup | inactive | timer oneshot, normal |
| paperless-exporter | inactive | stale failed state, no journal — open triage row |
| inboxclean-web | active | `/` and `/health` 200 in 20–70 ms live; slow-query WARNs (sync_state 818 ms, corpus read model 4.2 s) under load |
| inboxclean-sync | **failed** | every 30-min tick: "Failed with result 'timeout'" (21:58, 22:28 today); 2026-10-27 triage attributed `gmail.token_revoked` — app-level pre-kill log pull still owed |
| inboxclean-indexer-web / -canary-metrics | inactive | canary timer-led; indexer not enabled |

---

## a) FULLY DONE

**Paperless**
- Core stack + SSO-only login (Pocket ID, since 2026-09-02) stable; break-glass semantics proven.
- Scanner intake (Brother ADS-1800W → consume dir) end-to-end with campaign instrumentation (2026-10-19).
- bank-sync→paperless archival automated (runtime DRF token mint, placeholder sops file deleted, 2026-10-01).
- InboxClean→Paperless attachment archiving (papersync) live since 2026-09-02.
- Pocket ID `paperless-admins` group→superuser mapping (2026-10-01), fail-closed, eval-asserted.
- Decision-model bench built + run (2026-10-27): receipts+invoices 38/38 across arms; corrected text arm 34/38 = 90% (encrypted scored on Noul only).
- paperless-triage confidence gate P1: implementation + **VM test GREEN 2026-10-29** (attempt 19) after catching 3 paperless-3.3.1 API contract bugs (incl. the `?name=`-is-not-a-filter trap that would have no-opped the T6 heal).
- T6 accounting-entity drift: declarative `ensureTags`/`ensureCustomFields` heal LANDED, VM-proven.

**InboxClean**
- inboxclean-web live and responsive right now (this morning's 502 class resolved; the 2026-10-25 stop-without-start unit is serving).
- io.max `IOReadBandwidthMax` 20 MB/s by-id cap LANDED in tree (c4c72e6f9/d1ff5fbd5) — the storm-mitigation leg.
- OAuth honesty chain fixed upstream (auth dead-grant fall-through 1540a56, /health 8s budget + 60s verdict cache c4d62a3, banner d23c48a) — tested, sitting unpushed.
- inboxclean-canary collector build-fixed (dc3ad6e7) after the `''''` quote-escape build failure; negative-tested.
- 2026-10-04 re-consent ceremony proven live (corpus 0→617, successful refresh).

## b) PARTIALLY DONE

**Paperless**
- Decision-triage gate: green in tree, **DEPLOY PENDING** — blocked 2026-10-29 at the deploy entry gate by IO-PSI corpse pile; re-fire under quiescence. Post-deploy smoke list lives in paperless.md §Decision-triage gate.
- T6 live heal + `journalctl -u paperless-dashboard-provision | grep ensured` verification: rides the same deploy.
- Accounting-extraction runbook vs live DB reconciliation: heal landed; live probe found faktura tag + Invoice number/Issue date fields + gpt-auto pipeline ABSENT (SUPERB-restore suspicion) — reconcile after deploy.
- Embeddings through ai-meter (`:8107/v1/llama-embeddings`): queued [ready], rides next deploy (owner single-endpoint direction 2026-10-27).
- paperless-gpt: invoice leg LIVE; statement leg + declarative field definitions user-gated.
- Drive→Paperless: ALL module work landed (fixture, timers, Immich leg); ONE user flip from go-live (OAuth "In production" + rclone authorize ×3 + sops fill + `google-sync.enable`).
- Pocket ID group mapping deploy+live-verify legs: [blocked:deploy].

**InboxClean**
- Storm-hardening: cap landed; the **reconnect-backoff + bounded-aggregation-queries** legs (the freeze-#27/#28 driver work: 1.5 GB DB rescanned ~38×/h, `/`-poller identification) still [ready]/unlanded.
- Upstream push train: 3+ tested commits unpushed (auth honesty, /health cache, banner, dead-grant chain) — `[blocked:user]` push permission.
- 2026-10-20/21 stability batch (inboxclean-web 1G MemoryMax raise etc.): deployed or riding the pending train per the stability rows.

## c) NOT STARTED (still open)

**Paperless**: training milestone (blocked on failed-task cleanup); drive-paperless journal+walk scalability pass (O(journal) trap); VM test with real DRF for drive-paperless; token-mint boot resilience; STATE_DIRECTORY colon-list hardening (paperless.nix:927/1028); consume-dir readability guard; T13 Caddy Basic-auth block ([decision], owner); Qonto receipts credentials ([blocked:user]).

**InboxClean**: per-account `auth_expired` Gatus check ([decision], owner — `main` sat dead 26 days with zero remote signal last time); CRM feed go-live (plumbed both ends, connected nowhere, zero `/api` hits ever); year-2611 corpus date-parse upstream filing; `scripts/inboxclean-paperless.sh` as flake app + fixture test; gmail-verdict-cache regression test; templ CLI pin ≥ go.mod (must go UP to 0.3.1081).

## d) TOTALLY FUCKED UP (broken live, right now)

**Paperless**
1. **RAG dark and rotting**: `paperless_llmindex_last_success_age_seconds` = 2,582,421 s ≈ **29.9 days**; `llm_index` failed 32 unacked (also today 08:03/08:05/14:24: FLM 500 "input (548/794/758 tokens) too large, batch 512" — the known ai-stack starvation row, unfixed); 480 llm_index journal lines today; pending queue 11. The known "metric may be phantom" caveat does NOT apply anymore — journal confirms fresh failures.
2. **Inbox backlog 1,595 docs** unprocessed (consume pipeline starved behind the llm_index failures + auto workflow disabled after two burn incidents).
3. **Collation mismatch** (DB created on glibc 2.42, OS now 2.44) still unfixed — silent index-corruption drift window, one ALTER away since 2026-10-06.
4. paperless-exporter stale failed state, last-good unknown (in the 12-unit failed batch, untriaged).

**InboxClean**
1. **inboxclean-sync red on every tick** (30-min cadence): 2026-10-27 root-cause `gmail.token_revoked` / `invalid_grant` retryable=false on BOTH accounts; today's failures render as 5-min **timeout** kills — the app-level log pull before the kill is the open triage leg. Fix = owner ceremony: flip OAuth consent screen to **"In production"** FIRST, then `inboxclean auth` per account. This is the **third occurrence** of the Testing-mode 7-day bomb class (2026-09-04, 2026-10-14, 2026-10-27) and the structural cause (consent screen status) is still unconfirmed-fixed.
2. **Gmail sync is dark** until re-consent: statement archiving/decryption and the `gmail` tag self-heal PATCH all ride the sync tick — nothing new lands in Paperless from Gmail meanwhile.

## e) WHAT WE SHOULD IMPROVE

- Stop letting the same three failure classes page-by-rediscovery: the FLM 512-token batch starvation, the Testing-mode OAuth bomb, and the collation warning each have a queued row but no owner cadence — they recur faster than they are harvested.
- The pending-deploy train (triage gate + T6 heal + io.max + tile coverage + embeddings rewire) is now ~7 verified-in-tree changes deep; every storm day adds integration risk at switch time. A calm-window deploy closes 5 rows at once.
- inboxclean slow-query WARNs (4.2 s read-model) under calm load foreshadow the next storm — the bounded-query leg should not wait for freeze #29.
- Failed-paperless-tasks alerting exists (collector + Gatus) but nothing routes it to a human action — 32 failed llm_index sat unacknowledged again.

## f) TOP NEXT ACTIONS (highest impact first)

1. **Owner: InboxClean re-consent ceremony** — flip Google OAuth consent screen to "In production", then `inboxclean auth` (main + work) interactively. Un-darks Gmail sync, archiving, and closes the 7-day bomb class. `[blocked:user]`, docs/services/inboxclean.md runbook.
2. **Fire the pending deploy under quiescence** — carries paperless-triage go-live + T6 heal + inboxclean io.max + tile coverage + embeddings rewire in one switch; then run the per-service post-deploy batteries (paperless.md §Decision-triage gate list).
3. **Fix the FLM embedding starvation** (ai-stack row: raise physical batch / chunk llm_index inputs) — un-darkens RAG and unblocks the 1,595-doc backlog drain.
4. **`ALTER DATABASE paperless REFRESH COLLATION VERSION`** — one command, closes the index-corruption window (sudo psql via the paperless DB, 2026-10-06 row).
5. **Pull inboxclean-sync app logs before the 5-min kill** and confirm whether the current timeout flavor is the token_revoked stall or a separate wedge (decides TimeoutStartSec tightness vs re-consent urgency).
6. Clean + triage the unacked failed tasks (32 llm_index / 4 sanity / 1 mail_fetch) before the classifier training milestone.
7. Push InboxClean master (3+ tested commits incl. the /health cached-handler fix that measurably fed freeze-#28) — owner push-gate answer.
8. Triage paperless-exporter last-good (stale failed, no journal, 6h+).
9. Drive→Paperless go-live flip (user-gated, one flip, everything else landed).
10. paperless-triage P2 shadow bench + the owner cloud-API policy decision (egress + spend) to unblock the cloud-Jev arm.

## g) TOP QUESTION I CANNOT ANSWER MYSELF

**InboxClean upstream master is 3+ tested commits ahead with fixes whose absence measurably fed two freezes (the scan-per-probe /health handler and the phantom "already authenticated!") — can it be pushed now?** Agents never push; every InboxClean hardening row (verdict-cache test, templ pin, banner) is queued "rides next push" and the push itself is the single gate. If yes, I will push, bump the flake lock, and fold it into the pending deploy train.
