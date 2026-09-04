# Browser-History Zero-Data Root Cause & Fix — Session Status Report

**Date:** 2026-09-04 17:48 CEST
**Scope:** This session only — the "ZERO data for the whole week" investigation on history.home.lan, the upstream + SystemNix fix chain, and what is still open.
**Status at handoff:** All code/config work DONE and gated green on both repos. **Deploy is blocked on exactly two user steps** (token mint + sops edit). No verification of the fix against the live system has happened yet, because nothing is deployed.

---

## TL;DR

The dashboard showed zero data for a week because browser-history's `/ingest` never attributed pushed visits to a user (no token→context injection, no `user_id` stamping), while the Aug 30 deploy brought multi-user dashboard scoping that filters every query to the logged-in user. The agent kept syncing successfully into an invisible void. Fixed upstream (`browser-history@9b2fe69`, pushed), wired in SystemNix (agent-only `bh_` sops template, lock bumped), full `nix flake check` green. Two unrelated parallel-session landmines (CV VM 226, gatus lint false positive) were found blocking the shared gates and fixed. The user must now mint a `bh_` token in the UI and add it to sops; then deploy + full-sync backfill.

---

## Root cause chain (as established this session)

1. `resolveAgentAuth` returns `nil` (no user) for the v1 env-var token path — the path SystemNix deployed.
2. **Deeper:** `agentBearerMiddleware` never injected a user into the request context for ANY token type (the browser chain's `ContextEnrichmentMiddleware` never runs on agent routes), and `ingestHandler` never stamped `user_id`. So even a `bh_` DB token would NOT have fixed visibility by itself.
3. Every agent visit stored `user_id=''` — invisible to any logged-in user once the multi-user scoping sweep (`7b48d82`/`41ea23f` Aug 29, deployed via lock `7f2ad91` Aug 30) scoped all read queries `AND user_id = '<session user>'`.
4. Journal proof the pipeline was otherwise healthy: `batch sent ... accepted=1` as recently as 2026-09-04 13:22, server health `ok`, 135k events in DB.
5. Bonus finding: the `/devices` page is **passkey devices**, not sync machines — zero there is expected for an OAuth2-provisioned account. Agent Tokens page empty is also expected pre-fix (no DB tokens existed).

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| Root cause traced to exact lines (middleware, ingest, projection payload flow) | `api/agent_middleware.go`, `api/ingest.go`, `projection/visit_projection.go:214`, `domain/aggregate/decider.go:71` |
| Upstream fix: DB-token owner injected into request context; `/ingest` stamps `vd.UserID`; env-token path stays anonymous by design | browser-history `9b2fe69` (pushed `fff1de5..9b2fe69`), files: `api/agent_middleware.go`, `api/ingest.go` |
| Regression tests pinning both directions (attribution + env-token anonymity) | `api/ingest_attribution_test.go` — both PASS; full `go test ./api/` green (minus pre-existing broken gauge test) |
| CHANGELOG entry (conventional commit, proper message) | browser-history `9b2fe69` |
| SystemNix agent token split: new `browser-history-agent-env` sops template + `browser_history_agent_db_token` secret; server keeps legacy env token as break-glass; CRITICAL trap documented (agent and server tokens MUST differ — env path short-circuits before the DB lookup) | `modules/nixos/services/sops.nix`, `modules/nixos/services/browser-history.nix` |
| VM test mocks updated for the new template/secret | `tests/test-browser-history.nix` |
| flake.lock bumped to fix rev `7f2ad91 → 9b2fe69` | `flake.lock` |
| Full `nix flake check` green (all VM tests, all modules, both hosts) | ran twice; final: "all checks passed" |
| AGENTS.md gotcha with complete root cause + runbook (incl. full-sync backfill mechanics and the token-must-differ trap) | SystemNix `AGENTS.md` Browser History section |
| Shared-gate unblock #1: `cv-backup-dir` 226/NAMESPACE on fresh pools — ReadWritePaths scoped to the mount root so the creator can create its own leaf | `modules/nixos/services/cv.nix`; `checks.x86_64-linux.cv` now green |
| Shared-gate unblock #2: binary-coverage-lint false positive (word "awk" in a Gatus alert *description* read as missing runtimeInput) — reworded the prose | `modules/nixos/services/gatus-config.nix` |
| `--full-sync` backfill mechanics verified (flag exists; deterministic visit IDs + `INSERT OR REPLACE` on `visits` PK `id` stamp rows in place; per-batch cursor advance makes it resumable/idempotent) | `cmd/browser-history-agent/config.go:64`, `storage/sqlite_store.go:40` |
| Diagnosis of the two empty pages the user hit (devices = passkeys, agent tokens = DB tokens only) | `api/devices.go`, `api/agent_token_handlers.go` |

## b) PARTIALLY DONE

1. **The fix itself** — fully built and gated, but **not deployed**. Host still runs the anonymous-ingest build. Deploy is gated on the user's sops step (activation fails while `browser_history_agent_db_token` is absent from the sops file).
2. **AGENTS.md browser-history section** — new CRITICAL bullet is correct, but the older "Agent token:" bullet still reads as an endorsement of the raw hex token ("works without DB-backed bh_ creation") without a deprecation pointer. Stale-adjacent.
3. **Backfill plan** — mechanics verified on paper (PK, dedup, cursor), but never executed; `ingestSeen` in-memory dedup interplay reasoned (fresh restart clears it) but not exercised end-to-end.
4. **Permission-Policy `attribution-reporting` warning** — verified at code level that neither Caddy (`geolocation/microphone/camera` only) nor browser-history/httputil send it; NOT verified at runtime (never fetched the live response headers), so the actual source is UNRESOLVED. My "browser-side noise" claim is code-verified but not runtime-proven.
5. **Verification of the session-user compatibility of token creation** — `createAgentToken` uses `requireUserIDFromCtx` (any authenticated session) in code, so a Pocket ID session should work; the doc comment claiming "valid WebAuthn session" looks stale. Not runtime-verified; the user is about to click this button.
6. **Concurrent-session hygiene** — flagged the ride-along commits (inboxclean.nix, hermes.nix, flake.nix from other sessions), but the daemon batched my files with theirs and the branch is 13 commits ahead of origin, unpushed (per rules — push is the user's call).

## c) NOT STARTED

1. Deploy of the SystemNix change to evo-x2.
2. One-time `--full-sync` backfill of historical visits under the new token.
3. Any post-deploy verification (journal attribution, dashboard data, Gatus/SigNoz health after the package bump).
4. Quantifying the extraction-volume problem (the agent's noise filter dropped 46/46 recent Helium rows; firefox raw=0). The Helium profile path I tried (`~/.config/helium/Default/History`) doesn't exist — the real path was never located; volume never measured.
5. Monitoring for this failure class (a "batch sent accepted=N but anonymous" detector — server counter or journal scrape — exists nowhere).
6. Orphan-row cleanup story: old `user_id=''` rows in domains (PK `(domain, user_id)`), sessions, and behavioral tables are left as invisible garbage after backfill; no SQL/runbook.
7. Whether the agent sends `/ingest/behavioural` at all, and whether behavioral data needs its own backfill (its rows are also userless from the broken period).
8. macOS agent onboarding (upstream repo even ships a `launchd/` dir — never looked at it).
9. Filing upstream issues: pre-existing `TestUserCountGaugeExposedOnMetrics` isolation bug (reproduced with 3 unrelated pre-existing test pairings); env-token-anonymous-under-multi-user operator warning; stale "WebAuthn session" doc comment.
10. The summary-cron question: upstream CHANGELOG says `startSummaryCron` refuses to start when `RequireAuth=true` — if SystemNix sets RequireAuth, summaries may be empty-by-design in prod. Never checked against our config.
11. Upstream release/tag (SystemNix tracks `?ref=master`, so not blocking — hygiene only).

## d) TOTALLY FUCKED UP (what I got wrong this session)

1. **The `git stash` mishap** (browser-history repo): ran `git stash` without checking `git stash list` first; it saved nothing ("No local changes to save" — the daemon had already committed my work), and `git stash pop` then resurrected a PRE-EXISTING stash (`buildflow-pre-commit`), producing merge conflicts in two test files I never touched. Recovery was clean (conflicts restored to HEAD; the old stash remains preserved in the stack), but this was a self-inflicted near-miss and a violation of "verify state before tree operations".
2. **Premature root-cause doc**: I wrote the first AGENTS.md CRITICAL bullet blaming the env-var token and prescribing "swap to a bh_ token" BEFORE discovering that ingest had no user stamping at all — meaning v1 of my own doc recommended a fix that would NOT have worked. A user following it would have swapped tokens and still seen zero. Corrected in-session, but the lesson stands: don't write root-cause docs before the chain is proven end-to-end.
3. **Dropped investigation threads without closing them**: the todo list from the early phase (quantify Helium extraction volume; empirically probe the Permissions-Policy header) was silently replaced mid-session when the user's new messages redirected the work — those items were never finished, never re-added, never explicitly parked. Wrong profile path (`~/.config/helium/...`) failed and I moved on.
4. **Overclaimed verification**: said "verified our stack sends no attribution-reporting" — true at config-grep level, but I presented it with more confidence than a runtime header check would warrant.
5. **Wasted a cycle on an unusable base-revision test**: `git worktree add /tmp/bh-base` failed `[setup failed]` because go.work carries relative `../cqrs-htmx` replaces — knowable in advance (it's even in AGENTS.md), so the experiment was avoidable.
6. **Blocked-commit churn**: my first commit attempt tripped the pre-commit flake-check gate on two problems from OTHER sessions' commits (gatus lint false positive; CV VM 226). Not my bugs, but I burned a full check cycle discovering them; a `nix build .#checks.x86_64-linux.{binary-coverage-lint,cv}` pre-flight before committing would have surfaced both in one pass.

## e) WHAT WE SHOULD IMPROVE

1. **Make attribution observable** — this class ("accepted but invisible") ran for a WEEK with everything green. Add a server-side anonymous-ingest counter and/or a SystemNix journal-based check: pushes accepted with no user ⇒ alert. Silent partial degradation is the recurring theme of this box.
2. **Prefer bh_ tokens everywhere; treat the env-var path as break-glass only** — and say so in upstream docs, not just our AGENTS.md.
3. **Fix the noise filter ergonomics** — hardcoded `DefaultFilterConfig` (popup <5s, reloads, hidden) with zero CLI flags dropped 100% of a recent Helium sample. Operators need flags (and sane defaults need re-validation against real data).
4. **Upstream test hygiene** — the user-count gauge test is a global-state landmine (`userCountSource` re-pointing + server lifetime); needs isolation or per-test registry.
5. **Verify claims at the layer they'll be consumed** — headers fetched, buttons clicked, DBs queried — before writing docs that others act on.
6. **Daemon-batched commits reduce attribution quality** — my fix chain is spread across `chore: auto-commit` messages on both repos; the only well-named commit is the upstream changelog one. For shared trees, pathspec-staging MY files and committing immediately beats racing the daemon.
7. **Backfill tooling should be a first-class runbook** (one sudo command, expected output, rollback), not a session's worth of reasoning.

## f) NEXT — up to 50 things to get done

**Blockers / immediate (1–6)**
1. USER: mint `bh_` token in Agent Tokens UI (label `evo-x2`, scope `write`).
2. USER: `sudo sops platforms/nixos/secrets/browser-history.yaml` from repo root; add `browser_history_agent_db_token: <bh_…>`.
3. Deploy SystemNix (`nix run .#deploy`).
4. Verify first post-deploy agent tick: journal shows batch accepted AND server has the new binary (`9b2fe69` store path).
5. Run one-time `--full-sync` backfill (exact unit ExecStart binary + env file; sudo one-liner).
6. Verify dashboard/summary/timeline now show data for the logged-in user.

**Verification hardening (7–14)**
7. Confirm `/agents/token` creation works from a Pocket ID (OAuth2) session; fix the stale "WebAuthn session" doc comment upstream if so.
8. Verify behavioral ingest: does the agent POST `/ingest/behavioural`? Are behavioral rows attributed post-fix? Do they need backfill?
9. Post-backfill orphan cleanup SQL for `user_id=''` rows in domains/sessions/behavioral tables (one-time, root) + runbook.
10. Check the summary-cron guard (`RequireAuth` + `startSummaryCron` refusal) — are summaries empty-by-design in prod?
11. Post-deploy: SigNoz browser-history spans still flowing (signoz-coverage registry intact after package bump).
12. Post-deploy: Gatus browser-history checks green; pre/post-deploy scripts pass.
13. Add a regression test for the full migration path: anonymous ingest → token swap → full-sync → visits attributed (upstream integration test).
14. Add a server metric `browser_history_anonymous_ingest_visits_total` + SystemNix alert — detector for this exact class.

**Upstream quality (15–24)**
15. File/fix upstream: `TestUserCountGaugeExposedOnMetrics` isolation bug (global gauge re-pointing).
16. Upstream: CLI flags for FilterConfig (`-filter-popups`, `-popup-threshold`, `-dedupe-reloads`, `-filter-hidden`, `-filter-gibberish`) instead of hardcoded defaults.
17. Upstream: re-validate filter defaults against real browsing data (how much legit history dies to the <5s popup rule?).
18. Upstream: operator warning in README/CHANGELOG — env-var token is anonymous under multi-user scoping; require `bh_` for anything user-facing.
19. Upstream: design decision — auto-claim orphan (`user_id=''`) visits to the first account that logs in (single-user deployments) vs. explicit backfill.
20. Upstream: agent `--full-sync` timeout strategy (10-min ctx may truncate very large profiles; document resume semantics).
21. Upstream: tag a release (v0.5.1) for the attribution fix.
22. Upstream AGENTS.md/README: document the attribution flow (middleware → ctx → ingest → projection).
23. Upstream: consider `upsert` semantics doc for `INSERT OR REPLACE` + user stamping (backfill reliance).
24. Upstream: fix the session probe race doc — the devices/agents naming confusion ("devices" page = passkeys) confused even the operator; consider renaming or cross-linking.

**SystemNix polish (25–33)**
25. Rewrite the stale "Agent token" AGENTS.md bullet to deprecate the raw hex path.
26. Decide: blank the server-side legacy env token after backfill is verified (single auth path) vs. keep as break-glass.
27. tests/test-browser-history.nix: add an agent-enabled node asserting the agent-env template wiring end-to-end.
28. Runbook doc (`docs/services/browser-history.md` if missing): token mint, sops step, backfill, verification, rollback.
29. Consider `sops --set` via stdin (`read -s`) helper script to make secret adds scriptable without history leaks.
30. Verify sops template `restartUnits` behavior for the agent (oneshot + timer: harmless or surprising?).
31. Check whether `browser-history-agent` belongs in deploy.sh post-switch restart lists (timer-driven — probably not; document why).
32. Pre-deploy-check §10: add presence assertion for the new anonymous-ingest metric once it exists.
33. Find and document the actual Helium profile path the agent discovers (my `~/.config/helium` guess was wrong).

**Volume & data quality (34–40)**
34. Quantify kept-vs-filtered visits per browser over a real week (blocked until visibility is fixed and data flows).
35. Investigate firefox `raw=0` — unused browser vs. wrong profile path.
36. Tune filter flags in SystemNix module options once upstream flags exist (SystemNix-side `extraArgs`/env).
37. Decide retention: do invisible orphan visits get purged upstream ever? If not, bound them.
38. Verify visit durations semantics (Chromium writes duration on close — sub-5s rule hits legit quick reads; measure distribution).
39. Check `ingestSeen` interaction with full-sync explicitly in a test (fresh-restart assumption reasoned, unproven).
40. Confirm `X-Machine-Id` (`evo-x2`) shows up correctly in the dashboard machine attribution post-fix.

**Multi-machine / future (41–45)**
41. macOS agent onboarding runbook (upstream `launchd/` dir — evaluate; darwin module in SystemNix).
42. Second `bh_` token for the Mac (same account, distinct label) — never share tokens across machines.
43. Decide browser scope on macOS (Safari extractor exists upstream — verify it works).
44. Plan devices page usage: register a passkey if passwordless-web fallback is wanted (user previously chose SSO-only; optional).
45. Consider per-machine tokens list on the dashboard (Agent Tokens page) — label hygiene (`evo-x2`, `macbook`).

**Session-process debt (46–50)**
46. Always `git stash list` before any stash operation; never blind-pop.
47. Finish or explicitly park todo items when the session pivots — dropped threads (volume, Permissions-Policy) cost a handoff gap.
48. Pre-flight `nix build .#checks.<relevant>` before committing into a shared gated tree.
49. Write root-cause docs only after the causal chain is proven at every link.
50. Re-read upstream doc comments that contradict implementation (the "WebAuthn session" comment) — stale comments are cheap traps.

## g) Questions I cannot answer myself

1. **The Permission-Policy warning**: in which DevTools context did you see it — the main document response of `history.home.lan`, or a subresource/iframe? (I can't see your browser; the exact request would pinpoint the source, since neither Caddy nor the app emits that feature.)
2. **Backfill scope/privacy**: should `--full-sync` re-push your ENTIRE local browser history to the server (that's what it does), or do you want a bounded window (e.g., last 90 days) — and is ~20k visits' worth of re-ingestion acceptable IO/size-wise?
3. **Browser scope & expectations**: which browsers/profiles should count as "the data" on evo-x2 (Helium only? Firefox? anything else), so volume tuning and filter defaults target what you actually use instead of spreading thin?
