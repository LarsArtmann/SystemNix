# Status: InboxClean `main` re-consent + lazy-reconnect slug-bug session

- **Date:** 2026-10-04, window ~07:26 → 08:40 CEST
- **Scope:** the `post-deploy-check` WARN `InboxClean - Gmail main 'auth_expired'` → re-consent ceremony support → live root-cause of a NEW upstream bug (`/health` never healing after re-consent) → upstream fix + regression tests → all doc/TODO surfaces → harvest.
- **Point-in-time end state (08:35):** `/health` = `main: connected`, `work: connected`, `gmail_aggregate: ok`, corpus 1,705 indexed (main 1,680), projections ready, dead letters 0. Web uptime 252s (owner restart 08:31:24). One sync tick verified green (08:19, pre-restart).
- **INTEGRITY NOTE (written 08:4x):** this report was authored once already and the file VANISHED from the worktree minutes later (not in git history, stash, or trash) — the parallel session's own report (`2026-10-04_08-32_llama-rag-soak-unblock-session.md`) shows the same `AD` staged-then-deleted signature. A concurrent sweeper is hitting `docs/status/`; if this file is again missing, re-check with the parallel session before assuming agent error.

---

## a) FULLY DONE

1. **`main` Gmail re-consent (the original WARN)** — owner ran the runbook ceremony (`inboxclean auth --account main`, browser consent, "Authentication successful!" 07:45). Grant proven live three independent ways: sync tick 08:19 pulled real mail + ran Paperless archiving for `main` (50 msgs scanned, duplicate-rejection working); corpus indexing resumed (main 0→617→1,680); a successful Google token refresh rewrote `token.json` 07:52:29.
2. **Web restart unblock** — owner restarted `inboxclean-web` 08:31; `/health` flipped to `main: connected`, `gmail_aggregate: ok` (startup builds clients fresh from token files, bypassing the broken reconnect path).
3. **Root cause of the stale `auth_expired` — FOUND, PROVEN, FIXED upstream** (`~/projects/InboxClean`, commit `e9735c7`): the health-driven lazy reconnect passes `AccountID.String()` = `"Account:main"` (the `accountBrand.Name()` prefix) while the production closure (`cmd/inboxclean/web.go:106`) matches plain config names (`"main"`) → every reconnect died on unknown-account, **logged only at Debug**, so a freshly minted token never healed `/health`. Proof chain: new regression test `TestHealthReconnectReceivesPlainSlugName` written FIRST and shown FAILING on unfixed HEAD (got `not_connected`, closure received the prefixed name), then PASSING after the fix (server.go now passes `Name.Get()` at both call sites + the write-loop). Fix surfaced by reading the deployed path end-to-end: probe code (`server.go:447` `gmailAccountStatus`) → `tryReconnect` (Debug-only failure log, confirmed absent from journal) → reconnect closure → config merge (`Accounts()` = env main + TOML extras) → `go-branded-id` `String()` implementation.
4. **The two contract tests pinning the OLD contract migrated** — `TestTryReconnectSuccessClearsBackoff` + `TestAccountsConcurrentAccess` (accounts_concurrency_test.go) moved from `.String()` to `.Get()`; `internal/web` fully green under `-race`; `golangci-lint` 0 issues (the BuildFlow hook failure was a cold-cache timeout, re-verified clean at 8m).
5. **The `--account work` exit-75 mystery explained** — the user's command used the runbook's step-2 env form, which lacks `INBOXCLEAN_CONFIG` (the 2026-08-29 trap class, documented at header step 3). No action needed: `work` was never revoked.
6. **All doc surfaces closed/updated (queue ↔ library ↔ runbook ↔ CHANGELOG, no drift)**: TODO_LIST post-re-consent residue row (kept open, post-state accurate); `docs/todo/services.md` big row rewritten (re-consent DONE + residue) + the 2026-10-01 re-consent row closed; the `inboxclean-sync FAILED` investigation queue row closed (root cause = the revoked grant, its own candidate class); `docs/todo/upstream.md` deploy row extended with `e9735c7`; runbooks corrected in BOTH `modules/nixos/services/inboxclean.nix` header (broken self-heal claim + step-2 MAIN-ONLY annotation) and `docs/services/inboxclean.md`; CHANGELOG entry landed.
7. **Harvest done at authoring time** — two new agent-actionable `[ready]` items landed as queue one-liners + library rows (stale WARN text in post-deploy-check.sh; `.githooks/pre-commit` daemon-sweep reporting); three upstream follow-ups appended to `docs/todo/upstream.md` (hygiene row); `scripts/check-todo-system.sh` structure check: OK, and this report passes the harvest-coverage lint (86 standing UNHARVESTED, unchanged).
8. **SystemNix eval green** after the runbook edits (`nix flake check --no-build`, only the expected aarch64-darwin warning).
9. **On-sight fixes during this report pass**: the step-2 MAIN-ONLY annotation (the exact trap that cost the user a failed attempt — the runbook's step 2 never warned) and the stale "six pre-existing test failures" claim in upstream.md (re-checked: those six are FIXED; current reds are different, see §b).

## b) PARTIALLY DONE

1. **The upstream fix chain stops at "committed locally"** — `e9735c7` (+ the earlier `1540a56`, `d23c48a`) are unpushed; `flake.lock` still pins `01d2c5e`; until push → lock bump → deploy, EVERY re-auth needs a manual `systemctl restart inboxclean-web` and `/health` self-heal stays broken in prod. Push is owner-gated (agents never push).
2. **Sync verification: one tick, not three** — the 08:19 tick was green PRE-restart; the first POST-restart tick had not fired by report time (30-min cadence, next ~08:49). Cursor-unfreeze past 5152620 not yet directly observed in the journal.
3. **InboxClean test suite is green where I touched, red where I didn't** — `internal/web` green (incl. race), `cmd/inboxclean` green; `internal/categorize` `TestExecutor_LabelActionEventsEndToEnd` FAILS reproducibly and `internal/emailcqrs` `TestRebuildProjection_MultipleStreams` is FLAKY (failed once, passed on rerun) — both pre-existing (categorize does not import web), unowned, and they keep the "red suite masks regressions" hazard alive. The upstream.md hygiene row's old "SIX pre-existing failures" claim is corrected (those six are fixed; these two are the current reds).
4. **The silent 07:52:29 actor is unidentified** — `token.json` was rewritten by a SUCCESSFUL Google refresh and corpus jumped 25→642 with ZERO journal lines, while the accounts-path reconnect was provably erroring. Suspected the dashboard "Sync now" / corpus builder path (builds its own clients from token files), never confirmed — recorded as an upstream audit-blind-spot item.
5. **The failed `work` auth attempt left no cleanup need** — but it exposed that the CLI's exit-75 error says nothing about `INBOXCLEAN_CONFIG`; error-message improvement queued upstream (§f #15), not fixed (unpushed chain anyway).

## c) NOT STARTED (owned by this session's findings, deliberately not begun)

1. **Cloud Console "In production" confirmation** — user-only; THE gating fact for whether the new `main` token survives past ~2026-10-11. Cannot be probed from the box.
2. **Push + `nix flake lock --update-input inboxclean` + deploy of the fix chain** — owner push gate.
3. **Post-deploy verification pass** for the fix chain (incl. the new "self-heals WITHOUT restart" assertion) — blocked on (2).
4. **`gmail`-tag demote PATCH re-check** — pre-existing Paperless `client_error` under the connected `work` account; the re-consent may not fix it; needs one journal read after the next archiving tick.
5. **Per-account `auth_expired` Gatus check** — the existing `[decision]` row (services.md); this session made it MORE relevant (`gmail_aggregate` + per-account map are now machine-readable upstream), still unstarted.
6. **Upstream observability items** (WARN-level reconnect failures, silent-actor hunt, cold-cache lint timeout, categorize/emailcqrs reds, doctor auth-state surface) — appended to upstream.md hygiene row, none started.

## d) TOTALLY FUCKED UP

_(no data loss or prod damage this session — but five honest self-inflicted/environmental failures)_

1. **I relayed an unverified doc claim as fact, and it was wrong.** My first answer told the user the deployed build "self-heals ~30s" — quoted from the runbook header without a live probe. Reality: the deployed build's heal path is the very bug this session fixed. Cost: a false expectation for the user and ~15 minutes of debugging predicated on "it should have healed by now". Verification-class lesson: assert behavior from probes, never from documentation (queued for crush-config `references/lessons.md`, §f #20-21).
2. **The "verified pre-existing via stash" baseline was methodologically VOID** — `git stash` had nothing to stash because the auto-commit daemon had already committed my changes; my "baseline" run executed WITH the fix. The conclusion still holds (categorize/emailcqrs do not import `internal/web` — dependency isolation), but the evidence step was broken. Caught in-flight; flagged here so nobody cites the stash run.
3. **Three daemon-race collisions in one session** (InboxClean `8a038e9`+`ba04da4`, SystemNix `6b8f2dcd`+`ff52d3d9`, plus my pathspec commit losing its staged set mid-hook → `Ready to commit!` + exit 1). Recovery correct every time (verify `git show --stat`, squash via soft-reset / land-on-top, verify HEAD carries final content). The misleading all-green hook output is queued as a hook fix (§f #9). Squashed `e9735c7` is properly messaged — no history damage.
4. **THIS REPORT FILE VANISHED after its first write** — authored at 08:32, gone from the worktree minutes later (absent from git history, stash, AND trash); the parallel session's own report shows the identical `AD` staged-then-deleted signature. Rewritten with this integrity note. If a `docs/status/` sweeper script is running in a parallel session, it needs a guard against eating other sessions' fresh reports (cross-session hazard, not mine alone).
5. **Two edit round-trips burned on view-decoration artifacts** (copied `|`-prefixed line numbers into old_string for `inboxclean.nix`; trusted the view's truncated tail for services.md row 34). Recovered on retry with exact bytes; pure inefficiency.

## e) WHAT WE SHOULD IMPROVE

1. **Reconnect/auth heal failures must not log at Debug in prod** — the slug mismatch was invisible for its entire lifetime at default level (upstream WARN-after-N, queued).
2. **Silent prod writes are audit-blind spots** — a Google-side token refresh + 617-email corpus write with zero identifiable journal lines should not be possible (queued upstream).
3. **`branded.ID.String()` is a display method, not an identity round-trip** — the brand-prefix surprise will bite other LarsArtmann repos using `go-branded-id` as map/closure keys across config boundaries; document in the library README or add a lint (queued as lesson).
4. **Test closures that ignore their inputs mask prod contracts** — the reconnect tests passed for months while prod never matched; every callback contract needs at least one prod-SHAPED test (partially landed via the new regression test).
5. **Runbook env-command forms should be copy-paste-proof** — the step-2/step-3 env split has bitten twice (2026-08-29, 2026-10-04); generalize the paperless.md derive-env-from-unit pattern (queued as polish).
6. **Health-check message text rots** — post-deploy-check's WARN still instructs enabling an already-enabled service; check messages embedding config premises should name the config file (queued).
7. **Pre-commit hook output must explain its verdict** — green text + exit 1 teaches nothing; detect the daemon-sweep case explicitly (queued).
8. **Red upstream suites keep masking regressions** — categorize (hard fail) + emailcqrs (flaky) tax every InboxClean session (queued upstream).
9. **Concurrent-session report sweeps need a guard** — see §d4; a `docs/status/` cleanup must never touch files younger than N minutes or owned by a live session.

## f) Up to 50 things to get done next

_Session-scoped, impact-ordered. Dispositions per the TODO contract: **[landed]** = queued this session; **[not-harvested: reason]**._

1. Confirm Cloud Console OAuth consent screen is "In production" — else new `main` token dies ~2026-10-11 and this incident recurs weekly. **[landed]** (residue row).
2. Push InboxClean `1540a56` + `d23c48a` + `e9735c7` (owner; agents never push). **[landed]** (upstream.md deploy row).
3. `nix flake lock --update-input inboxclean` + `nix run .#deploy`. **[landed]** (same row).
4. Post-deploy verify: re-auth → `/health` heals WITHOUT restart; sync cursor advances; `gmail_aggregate` JSON-path checks unaffected. **[landed]** (same row).
5. Watch 2-3 more `inboxclean-sync` ticks green post-restart; confirm cursor > 5152620 in the journal. **[landed]** (residue row).
6. Re-check the `gmail`-tag demote PATCH (Paperless `client_error` under `work`, pre-dates re-consent). **[landed]** (residue row).
7. Adopt `gmail_aggregate` + per-account `services.gmail.<slug>` into Gatus JSON-path checks — close the "one dead account pages nobody" class. **[not-harvested: existing `[decision]` row owns it — case strengthened, not duplicated]**
8. Rewrite the stale WARN text in `scripts/post-deploy-check.sh` (~:760). **[landed]** (TODO_LIST + services.md).
9. `.githooks/pre-commit`: detect daemon-swept staged sets (empty staged diff + moved HEAD) instead of green text + exit 1. **[landed]** (TODO_LIST + pipeline.md).
10. Upstream: log reconnect failures at WARN after N consecutive attempts. **[landed]** (upstream.md hygiene).
11. Upstream: identify the silent 07:52:29 token-write/corpus-jump actor. **[landed]** (upstream.md hygiene).
12. Upstream: raise golangci-lint timeout for cold caches. **[landed]** (upstream.md hygiene).
13. Upstream: fix `internal/categorize` `TestExecutor_LabelActionEventsEndToEnd`. **[landed]** (upstream.md hygiene).
14. Upstream: deflake `internal/emailcqrs` `TestRebuildProjection_MultipleStreams`. **[landed]** (upstream.md hygiene).
15. Upstream: exit-75 error should HINT the missing `INBOXCLEAN_CONFIG`. **[landed]** (upstream.md hygiene).
16. Upstream: convert the remaining name-ignoring reconnect test closures to prod-shaped contracts. **[not-harvested: fold into next upstream test pass]**
17. Runbook: collapse the three auth env-command forms into one derive-from-unit block. **[not-harvested: step-2 annotation landed; consolidation is polish — revisit on next runbook touch]**
18. Upstream: `inboxclean doctor` should surface per-account auth state. **[not-harvested: ROADMAP fuel — new capability]**
19. Upstream: `corpus_accounts.*.provider_total` always `"unknown"` — populate or drop. **[not-harvested: cosmetic observability]**
20. Record the `branded.ID.String()` brand-prefix trap as a cross-project lesson (crush-config `references/lessons.md`, by commit). **[not-harvested: owner-gated crush-config commit]**
21. Same for "doc-quoted behavior claims need a live probe" (2026-09-18 gate class sibling). **[not-harvested: same as #20]**
22. Verify probe quota angle: `VerifyAuth` hits Google every probe while a grant is dead (~114ms per ~30s per dead account) — confirm the TTL-cache row covers the dead-grant case. **[not-harvested: folded into the upstream TTL-cache row's contract gate]**
23. After deploy: remove the interim "restart after re-auth" advisories from the inboxclean runbooks (01d2c5e-only bug). **[not-harvested: the deploy row's "update docs in the same pass" owns it]**
24. Watch the foreign session's live worktree edits (`niri-config.nix`, `pool-recovery.nix`, `post-deploy-check.sh`, staged llama-rag report) — do not co-verify or sweep. **[not-harvested: multi-agent discipline — flagged, not owned here]**
25. Investigate the `docs/status/` report-vanishing sweeper (§d4) — find what deleted two fresh reports this morning and guard it. **[landed]** (recorded in this report's integrity note + §e9; if the sweeper is a foreign session's script, its session owns the fix).
26. Adjacent-open, resurfaced: Paperless decrypt-password go-live + API-token rotation (existing `[blocked:user]` rows) — archiving for `main` is live again, so the decrypt password is the next archiving gap. **[not-harvested: rows exist]**

_(27-50 intentionally unused — everything beyond #26 is already queued elsewhere or would be fabricated scope; 26 real session-derived items beat 50 padded ones.)_

## g) Questions I cannot answer myself

1. **Did you flip the Google Cloud OAuth consent screen to "In production" BEFORE re-consenting `main`?** I cannot see the Cloud Console. If it was still "Testing" at 07:45, the new token carries the 7-day bomb and dies ~2026-10-11 — this row re-fires and the flip becomes step 1 next time.
2. **Did you click "Sync now" (or any dashboard action) around 07:52?** Something in the web process refreshed `main`'s token (07:52:29 write) and indexed 617 emails with zero journal lines while the accounts-path reconnect was provably broken. If you clicked the button, mystery solved; if not, an unidentified component writes auth state silently and I'd file that upstream with your answer as evidence.
3. **Push now or ride the next deploy train?** The upstream fix chain (`e9735c7` et al.) is complete and tested but sits behind your push. If you push today I'll bump the lock + verify the deploy same-day; if it rides the next natural deploy, the "restart after re-auth" workaround stays load-bearing and the runbook advisories stay in place.

---

**Verification appendix:** regression test failed-first proof (unfixed HEAD: `--- FAIL ... got "not_connected"`); `internal/web` `-race` green; golangci-lint 0 issues; `nix flake check --no-build` green; `check-todo-system.sh` structure OK + this report passes harvest lint; sync tick 08:19 green; `/health` 08:35 connected/ok. Revs: InboxClean fix `e9735c7` (local, unpushed), deployed build `01d2c5e`, squash base `9bcea8d`; SystemNix surfaces landed via daemon commits `6b8f2dcd`/`ff52d3d9` + worktree.
