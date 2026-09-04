# InboxClean OAuth `invalid_grant` incident — diagnosis, upstream hardening, live status

**Date:** 2026-09-04 19:57 CEST
**Scope:** inbox.home.lan "Failed to Load Labels" outage; upstream InboxClean fixes; SystemNix docs
**Status:** ROOT CAUSE FIXED IN CODE (upstream, untagged) — LIVE OUTAGE STILL OPEN (re-auth pending, user-bound)

---

## Incident summary

- `/labels` at inbox.home.lan failed with `oauth2: "invalid_grant" "Token has been expired or revoked."` for account `main`; the card mislabeled it "transient — wait and try again".
- `inboxclean-sync.service` failed exit 75 (TEMPFAIL) every 30 min since 08:04 (16+ OnFailure Discord alerts); `/health` reported `main: connected` the whole time (phantom green — token-file presence, not validity).
- **Root cause:** the InboxClean OAuth client sits in Google "Testing" publishing status → Google expires refresh tokens **exactly 7 days after issuance**. main issued Aug 28 04:54 (fish history) → died between 07:34 (last good sync) and 08:04 Sep 04. work issued Aug 29 ~19:00 → **dies ~Sep 05 19:00**. Same mechanism already documented for google-sync.
- Live at report time: `token.json` mtime 07:34 Sep 04 (still dead, no re-auth yet), `token-work.json` mtime 19:50 (work alive, ~24h to its own 7-day stamp). Latest sync failure 19:35.

## a) FULLY DONE

1. **Diagnosis, evidence-complete:** journal timeline (sync green 07:34 → first invalid_grant 08:04), cursor forensics (main frozen at 5152620, work advancing to 5153902), issuance timestamps from fish history → 7-day Testing-mode expiry confirmed with high confidence.
2. **Phantom-green root-caused:** `/health` `connected` = client-object presence; `reconnectDefaultInterval` design read; Gatus checks audited (assert only `[STATUS] == 200` + latency — no body assertion to break).
3. **Upstream fix — classification:** `classifyTokenRefreshError` (internal/gmail/auth.go) — `invalid_grant` → Rejection `gmail.token_revoked` (exit 1, actionable), everything else stays Transient `gmail.token_refresh`.
4. **Upstream fix — passthrough guard:** `classifyAPIError` passes already-classified non-transient errors through unchanged; wrapping would have demoted the Rejection back to retry advice.
5. **Upstream fix — honest /health:** per-account grant probe (`Client.VerifyAuth`, `AuthRevoked`), substatuses `connected` / `auth_expired` / `degraded` / `not_connected`; revoked grant triggers one backoff-gated reconnect so a re-authed token heals the dashboard without restart/deploy.
6. **Upstream fix — UX copy:** registered `gmail.token_revoked` template (What/Why/Fix incl. the 7-day Testing-status explanation + the exact re-auth command shape); `gmail.token_refresh` Why corrected.
7. **Tests:** 3 new files (auth_token_refresh_test.go, errors_test.go, health_auth_test.go) — includes an end-to-end httptest round-trip through the real oauth2 refresh path proving the public `*oauth2.RetrieveError` reaches the classifier, plus health recovery/degradation/throttle/no-prober pins.
8. **Verification:** full `go test ./...` green; `go vet` clean; gofmt/golines clean on all touched files; golangci-lint **zero issues in touched files** (20 pre-existing issues elsewhere, not mine — listed separately).
9. **Docs upstream:** InboxClean `AGENTS.md` (Error Handling incident note) + `docs/ARCHITECTURE.md` family table row (`gmail.token_revoked`).
10. **Docs SystemNix:** AGENTS.md InboxClean section bullet (7-day expiry, fix order, monitoring lies) — daemon-committed `818cf43d`; module runbook header (re-auth-on-expiry procedure) — daemon-committed `95959fbd`.
11. **Safety checks done:** sync-loop per-account error collection verified (dead main cannot starve work's sync); `setupErrorClassification` confirmed in `main()` (web cards get templates); Gatus compatibility confirmed; `getClient` single-caller verified before signature change.
12. **Concurrent-session handling:** SystemNix tree switched to `forgejo-hermes-agent` mid-session by another session — adapted (read-only `git show master:` for Gatus config), no SystemNix code touched.

## b) PARTIALLY DONE

1. **The actual outage fix:** the 3-step runbook (GCP Production switch → re-auth main → re-auth work) was delivered but NOT executed — user-bound (sudo + browser). Main dark ~12.5h at report time; work expires ~Sep 05 19:00.
2. **Fix #3 of my offer (alert dedup):** assessed, deliberately deferred — the shared `onFailure` helper lives in the SystemNix tree currently owned by another session's branch. Design options documented (see questions).
3. **Upstream delivery:** code committed locally by the auto-commit daemon (mixing with another session's paperless-metadata doc in `872c083`) — **not pushed, not tagged**, so SystemNix can't consume it yet.
4. **Live verification of my earlier promise** ("tell me when done, I'll verify /health + labels + sync") — blocked on the re-auth; verification commands ready.
5. **CI-grade verification upstream:** go test/vet/lint/fmt done; `nix flake check`, art-dupl, and the repo's own flake apps not run (low risk — no templ files touched).

## c) NOT STARTED

1. Push + tag upstream release; CHANGELOG/release notes for the exit 75→1 behavior change.
2. SystemNix flake bump (`inboxclean` input; expect a go-modules FOD hash refresh — CV-source-churn lesson) + deploy + post-deploy smoke.
3. New Gatus check asserting the `/health` gmail substatus (anchored `pat` on `auth_expired`, fail-visible) + post-deploy-check §10 update for the new substatus strings.
4. OnFailure alert dedup (see b2).
5. Investigation: **identical-sync-output anomaly** — at 07:04 and 07:34 Sep 04, main and work printed IDENTICAL cursors and message IDs (impossible for two accounts; suspected shared-state or logging bug). Noticed mid-session, never investigated. Also the unexplained Sep 02 00:49 dual-account transient blip (self-healed next run).
6. Google-client fleet audit: verify google-sync's client is actually "In production" (same death class would kill the 1.9 TB Drive mirror silently); inventory any other Google OAuth consumers.
7. AGENTS.md breadcrumb "fix shipped upstream in <rev>" once tagged; TODO_LIST harvest (docs-health).
8. Paperless papersync degradation check: confirm the 12.5h outage produced warnings only (no ledger damage, no upload loss).
9. `docs/services/inboxclean-sops-tokens.md` is still DRAFT/unwired — formally accept-or-reject the sops-token idea.

## d) TOTALLY FUCKED UP

1. **The service is still broken.** An entire session on this incident and `main` is on hour ~12.5 of darkness because the actual fix is three user commands that haven't been run. The hardening I shipped does nothing for the live outage until re-auth + (later) a tagged deploy.
2. **False-start root cause:** the first journal sweep suggested both tokens died Sep 02 (the 00:49 blip) — contradicted by token mtimes one step later. Cost one extra analysis round; the Sep 02 blip remains unexplained.
3. **Dropped thread:** the identical-sync-output anomaly (c5) was noticed at 07:04/07:34 and then silently abandoned instead of being flagged as an open bug immediately.
4. **Edit hygiene:** two failed multiedits + one build failure from mixing up the contents of two new test files; one edit-rejected-during-race on the SystemNix module (concurrent session had moved the tree). All recovered, but sloppy.
5. **Daemon commit mixing:** my upstream fix commits share commits with another session's unrelated doc (`872c083`) — pathspec-commit discipline (AGENTS.md rule) applies to daemons too, but I didn't isolate my work before the daemon swept it.
6. **Urgency framing:** I buried the work-account deadline (Sep 05 ~19:00) in prose instead of paging it as a hard deadline with a countdown.

## e) WHAT WE SHOULD IMPROVE

- **Handoff of user-bound steps:** irreversible-criticality steps (production flip, re-auth) deserve a top-of-message block with deadline + exact commands, repeated every message until done — not buried in a long report.
- **Health checks must probe, not trust presence** — now fixed upstream; apply the same audit question to every "connected"-style status in the stack (cv, discordsync, paperless tokens).
- **Error classification doctrine:** "transient" must mean *retryable*; permanent auth failures need their own family + actionable Fix text — upstream now models this; watch for the same mislabeling elsewhere (e.g. Pocket ID secret desyncs were historically "transient"-flavored too).
- **Alert dedup** for timer-driven failures (1 alert per incident, not per tick) — design decision pending (questions).
- **Concurrent-session discipline:** check `git branch --show-current` + `git status` BEFORE writing to a shared tree, and re-check after long analysis gaps; prefer pathspec commits when daemons are loose.
- **Open-anomaly ledger:** anomalies noticed mid-investigation (identical outputs, Sep 02 blip) should land in the status report immediately, not stay in working memory.

## f) NEXT TASKS (prioritized, ≤50)

**Immediate — outage closure (user, deadline Sep 05 ~19:00 for work)**
1. GCP Console → OAuth consent screen → Publishing status → "In production" (InboxClean's project).
2. Re-auth `main` (runbook command; browser on evo-x2 desktop).
3. Re-auth `work` (same, with `INBOXCLEAN_CONFIG` env + `--account work`).
4. I verify: token mtimes, sync green ×3 cycles, `/health` all connected, `/labels` renders, papersync uploads resume.
5. Confirm OnFailure Discord spam stops.

**Upstream InboxClean (needs your push/tag approval)**
6. Push master; tag patch release; release notes (exit 75→1 change, new /health substatuses).
7. Flake bump in SystemNix (`inboxclean` input; refresh go-modules hash), deploy, smoke.
8. Add render-path test: error card for `gmail.token_revoked` renders the registered Fix (not transient copy).
9. Integration test: web `/sync/run` surfaces the revoked card for a dead account while others sync.
10. Unit test: `errors.Join` of mixed-account outcomes exits 1 via `HandleErrorWithContext`.
11. Test: papersync stays warning-only when one account's grant is revoked.
12. Document the /health substatus contract + probe cost (refresh only on expired access token) in the module header/docs.
13. Investigate identical-sync-output anomaly (c5) — suspected shared cursor/state or logging bug; add regression test.
14. Root-cause the Sep 02 00:49 dual-account blip (or file as unexplained-transient with evidence).
15. Consider optional `?probe=deep` force-refresh param on /health (bounded, for diagnostics).
16. Consider min re-probe interval for a dead grant (bound token-endpoint calls while unhealthy).
17. Reduce persistingTokenSource lock-held network refresh (mutex currently spans the HTTP call).
18. Clean up the 20 pre-existing golangci issues in untouched files (separate pass).
19. Add `--account <name>` (from error context) into the token_revoked Fix text.
20. README/setup guide: warn new users about Testing-mode 7-day expiry.

**SystemNix integration (after tag)**
21. AGENTS.md breadcrumb: fix shipped upstream in <rev>.
22. New Gatus check "InboxClean OAuth Grants" (body-assert absence of `auth_expired`; anchored pat rules).
23. post-deploy-check.sh: /health substatus probe (auth_expired = FAIL, degraded = WARN).
24. Verify §10 lowercase-field exclusions don't swallow the new substatus strings.
25. Alert dedup implementation (design per question 3).
26. Re-check sync unit start-limit semantics under the new exit-1 classification.
27. Audit google-sync OAuth client publishing status (silent Drive-mirror death risk).
28. Inventory every Google OAuth consumer in the stack + their publishing status.
29. Verify papersync ledger integrity after the outage (b7).
30. Verify inboxclean.db pool backup freshness via backup-coordination.
31. Formally accept-or-reject the sops-token draft (docs/services/inboxclean-sops-tokens.md).
32. Verify my two master doc commits (`818cf43d`, `95959fbd`) survived the branch dance; rebase docs if needed.
33. This status report file itself may land on `forgejo-hermes-agent` via the daemon — refile to master after merge if so.
34. docs-health pass: harvest this report into TODO_LIST/FEATURES.
35. Add "check /health substatus first" triage note to the module runbook.

**Hygiene / prevention**
36. Standardize an "anomaly ledger" section for status reports (from e).
37. Codify the probe-don't-trust-presence audit for all service health endpoints.
38. Pre-deploy check: grep for `pat(*connected*)`-class phantom assertions fleet-wide.
39. Consider per-account token-expiry forecasting metric (days-to-7d-stamp while Testing status persists).
40. Consider moving InboxClean alerts through PapDashboard for lifecycle dedup + insight enrichment.
41. Review daemon commit isolation (pathspec commits) — raise as a process fix.
42. Add the re-auth runbook to a docs/services/inboxclean.md (currently only module header).
43. Upstream: expose account name in token-file context of every auth error (partially there).
44. Upstream: health reconnect-heal should log when it revives an account (observability).
45. SystemNix: verify no other unit greps `exit_code=75`/`status=75` semantics that just changed.
46. Sweep for other "transient"-mislabeled permanent failures in LarsArtmann services (CV, discordsync).
47. Upstream: consider idle backoff of the sync timer while a grant is revoked (reduce noise at the source).
48. Write the incident into docs/gotchas-archive.md (full narrative, once closed).
49. Update crush/qmd knowledge base with the incident summary for future sessions.
50. Post-incident review in 7 days: confirm no recurrence after Production flip (the real test).

## g) QUESTIONS (cannot self-answer)

1. **Did you already flip the OAuth consent screen to "In production" — and is the InboxClean client in the SAME GCP project as google-sync?** If separate projects, I want to verify google-sync's status too (same 7-day death class would kill the Drive mirror silently).
2. **May I push + tag the InboxClean fix now, and should the SystemNix flake bump ride solo or batch with the pending bank-sync/dnsblockd bumps?**
3. **Alert dedup design:** (a) stateful dedup guard in the shared SystemNix `onFailure` helper (benefits every service, touches shared lib), or (b) route timer-service alerts through PapDashboard's existing (sourceApp, title) lifecycle dedup?

---

*Report by the InboxClean incident session; live state re-verified at write time (main still dead, work alive).*
