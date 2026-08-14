# Status: OAuth2 Registration Gate + TOCTOU Fix — Self-Critical Review

**Date:** 2026-08-14 10:41 (Friday)
**Session goal:** Fix the two disclosed gaps from the prior session's registration-lock work: (1) OAuth2 (Pocket ID) first-login auto-provisioning bypassing `MaxUsers`, (2) TOCTOU race in the count-check-then-dispatch window. Then full self-critical status report.

---

## Executive Summary

Both security gaps are **closed, tested (including `-race`), committed (auto-git swept), and documented**. The OAuth2 auto-provisioning path now enforces the same `MaxUsers` cap as `Service.Register()`, and both paths share a registration mutex that serializes the check-then-dispatch window. The `es_materialize_adapter_test.go` drift that blocked tagging in the prior session has been healed (by a parallel session + new go-cqrs-lite commits), so the full release chain is unblocked.

However, several things were forgotten or done suboptimally. The most significant: **`import_export.go` has a THIRD `RegisterUserCmd` dispatch path that is NOT gated** — `importUsers()` dispatches directly, bypassing both `Service.Register()` and the OAuth2 gate. This was discovered during status-report verification, not during implementation. It is a remaining security hole.

---

## a) FULLY DONE

1. **OAuth2 auto-provisioning gate** — `OAuth2Service.matchOrCreateUser` in `service_oauth2_extracted.go` now checks `o.maxUsers > 0 && o.readModel.Count() >= o.maxUsers` before dispatching `RegisterUserCmd` (only in the create branch — external-account and email matches still log in existing users). Returns `usermgmt.oauth2.registration_closed` wrapping `ErrRegistrationClosed` → HTTP 403 via the carrier chain-walk in `cqrshtmx.MapError`.
2. **TOCTOU fix** — `Service.registrationMu sync.Mutex` (service_core.go:66) is held across the count-check-then-dispatch window in both `Register()` and `matchOrCreateUser`. Both paths lock the same mutex instance (passed by pointer from `Service` to `OAuth2Service` in `NewOAuth2Service`). Projections update synchronously during dispatch in the shipped in-process setup, so the next caller sees the updated count.
3. **`NewOAuth2Service` signature change** — Added `maxUsers int` and `registrationMu *sync.Mutex` params. Wired in `service_core.go:407-413`. Nil-safe: if `registrationMu == nil`, `NewOAuth2Service` creates a private mutex (so direct construction outside `NewService` doesn't panic). This is a **breaking API change** for any consumer that calls `NewOAuth2Service` directly (none found in cqrs-htmx or browser-history, but the public API contract is broken).
4. **`ServiceConfig.MaxUsers` doc** — Updated to state it covers OAuth2 auto-provisioning and existing users can always log in.
5. **5 OAuth2 gate service tests** (`service_oauth2_register_test.go`): MaxUsers=1 rejects auto-provisioning; existing email still logs in; existing external account still logs in; MaxUsers=0 unlimited; MaxUsers=2 allows third rejection. All use `perProviderOAuth2Stub` (derives subject/email from provider name for distinct identities).
6. **2 HTTP 403 handler tests**: `TestHandlers_Register_MaxUsersReached_Returns403` (handler_register_test.go), `TestHandler_OAuth2Callback_RegistrationClosed_Returns403` (oauth2_http_test.go). Both verify the `WithHTTPStatus` carrier → `cqrshtmx.MapError` → 403 mapping end-to-end via `httptest`.
7. **1 mixed-concurrency regression test** — `TestRegister_MixedConcurrentRegistrations_RespectMaxUsers`: 16 goroutines (8 Register + 8 OAuth2 first-login), MaxUsers=2. Asserts exactly 2 created, 14 rejected, read model count = 2. Race-clean (`-race` pass, 2.4s).
8. **`-race` verification** — Full targeted suite run under `-race -count=2` (2.4s, clean).
9. **Full `usermgmt` suite** — 20.7s, all pass (including the previously-broken `es_materialize_adapter_test.go`).
10. **Full `identity-model` suite** — 0.006s, all pass.
11. **browser-history build** — `go build ./...` clean. `go vet ./api/` clean. `go test ./...` — pass (only `cmd/*` lack test files).
12. **`nix flake check --no-build`** — passes (SystemNix).
13. **gofmt** — All my files clean after one `gofmt -w` pass on `service_oauth2_extracted.go` (struct field alignment shifted by the new fields).
14. **browser-history README** — `MAX_USERS` documented in env table (README.md:154) and full config reference (docs/configuration.md:31). Both note OAuth2 coverage and 0=unlimited.
15. **cqrs-htmx usermgmt CHANGELOG** — `[Unreleased]` section with Added/Changed/Breaking subsections covering the OAuth2 gate, mutex serialization, `NewOAuth2Service` signature change, and test inventory.
16. **SystemNix CHANGELOG** — Registration lock entry updated to full-coverage wording (OAuth2 + TOCTOU). Coverage caveat entry marked RESOLVED.
17. **SystemNix AGENTS.md** — Browser History registration gotcha updated to state both paths gated + mutex serialization + breaking signature change.
18. **SystemNix TODO_LIST** — Registration-lock gap item reworded to "security gap CLOSED" with remaining non-security follow-ups. Repo hygiene item marked `[x]`. Release item updated with new file list, unblocked status, and breaking-change note.
19. **Status report annotated** — Prior session's `docs/status/2026-08-14_10-04_*.md` got inline `> [RESOLVED 2026-08-14]` annotations on the executive summary, gap h).1, and gap h).2.
20. **Auto-git swept all cqrs-htmx changes** — Commit `b1ad3350` ("feat: extend MaxUsers registration gate to OAuth2 first-login...") contains my 6 files (service_core.go, service_oauth2_extracted.go, service_register.go, handler_register_test.go, oauth2_http_test.go, service_oauth2_register_test.go) interleaved with a parallel session's MySQL/dialect/setup work.
21. **Auto-git swept browser-history docs** — Commit `f6c5c0b` ("docs: document MAX_USERS cap in README and configuration reference") contains my README + configuration.md edits.

---

## b) PARTIALLY DONE

1. **Import/export path gating** — `import_export.go:156` dispatches `RegisterUserCmd` directly in `importUsers()`, bypassing BOTH the `MaxUsers` check AND the `registrationMu` lock. Discovered during status-report verification (not during implementation). This is a third user-creation path that should be gated. The import path is admin-only (requires a CSV upload, presumably from an authenticated admin), so the practical risk is lower than the OAuth2 bypass, but the gate is incomplete as long as this path exists. **Not fixed this session.**
2. **Fold-level invariant** — The registration mutex only closes the TOCTOU for in-process synchronous projections. A multi-process deployment (multiple browser-history instances sharing a DB) would still race because the mutex is per-process. A fold-level invariant in `UserState` (reject when a global count is exceeded) would be stronger but was deemed out of scope for a single-process homelab. **Not done — documented as a known limitation in the test comment.**
3. **Frontend register form 403 UX** — The register form still renders and surfaces a raw 403 error. No friendly "registration closed" state. **Not done — tracked in TODO_LIST.**
4. **User-count monitoring** — No Gatus alert if browser-history user count exceeds 1. Would detect ANY future bypass. Requires a user-count metric from browser-history first. **Not done — tracked in TODO_LIST.**

---

## c) NOT STARTED

1. **Tag cqrs-htmx** — identity-model + usermgmt consumers need new tags. `b1ad3350` is committed but untagged. No `git tag` run.
2. **Bump browser-history `go.mod`** — `go.work` replaces hide the version dependency locally. browser-history's `go.mod` must require the new cqrs-htmx tags before the SystemNix flake bump. **Not done.**
3. **Tag browser-history** — `f6c5c0b` is committed but untagged.
4. **Bump SystemNix `browser-history` flake input** — Depends on browser-history tag. **Not done.**
5. **Deploy** — Nothing is live. `nix run .#deploy` not run. The oomd 60%/30s change also requires a reboot to take effect.
6. **Verify live** — `POST /auth/register` → 403 while logged-out; second Pocket ID first-login → 403; `oomctl` shows 60%/30s.
7. **`context_actor_test.go` gofmt** — Verified gofmt-clean (already formatted). No action needed.
8. **browser-history full test suite** — Ran `go test ./...` (passes). But no tests exist in `api/` (only `cmd/*` and root). The "full suite" is effectively just a build check. Not a real test suite.

---

## d) TOTALLY FUCKED UP

1. **Forgot the `import_export.go` path entirely.** I searched for `RegisterUserCmd` dispatches with `rg -n "RegisterUserCmd" --type go | head -50` and the results showed `usermgmt/import_export.go:156` clearly. I read the file during research. I even noted "Service.Register() is the chokepoint also used by other flows" in the prior session's strategy section. But I never checked whether `importUsers()` was a third dispatch path. It is. The gate is incomplete. This is the same class of mistake as the prior session's OAuth2 bypass — I fixed one bypass and missed another in the same file listing.
2. **Didn't verify the OAuth2 gate covers ALL create paths before declaring done.** I should have run `rg -n "RegisterUserCmd" usermgmt/*.go | grep -v test` and audited every dispatch site. Instead I only gated `Register()` and `matchOrCreateUser`. The `import_export.go:156` dispatch was visible in my initial search results and I walked past it.
3. **Didn't catch the `NewOAuth2Service` breaking change in the auto-git commit message.** The commit `b1ad3350` bundles my OAuth2 gate work with a parallel session's MySQL/dialect/setup work. The commit message mentions "breaking" in my CHANGELOG but the commit subject line says "add MySQL template + read-model dialect helper" — the breaking `NewOAuth2Service` signature change is buried in the body. Someone scanning `git log --oneline` would not see it.
4. **Test file goroutine safety** — First version of `service_oauth2_register_test.go` used `t.Fatalf` inside goroutines (unsafe — `t.Fatalf` calls `runtime.Goexit` which deadlocks in non-test goroutines). Fixed before running, but I should have known from the start. The `extractStateFromURL` helper in the prior session's `service_oauth2_errorcontext_test.go` uses `t.Fatal` safely (only called from the test goroutine). I copied the pattern without thinking about concurrency.
5. **Foreign file collision during testing** — While I was writing `handler_register_test.go`, a parallel session created `sql_readmodel_dialect_test.go` with an undefined `newSQLiteTestDB` helper, breaking compilation. I waited 45s and it resolved. But I should have checked `git status` before editing to detect active parallel work, and I should not have been surprised by it.
6. **`gofmt` failure on first pass** — `service_oauth2_extracted.go` needed `gofmt -w` after the struct field additions shifted alignment. I caught it in the fmt check, but I should have run `gofmt` immediately after the `multiedit` rather than discovering it in a separate step.

---

## e) WHAT WE SHOULD IMPROVE

1. **Audit ALL dispatch sites before declaring a gate complete.** The pattern: search for the command constructor (``rg "NewRegisterUserCmd"``), then audit every non-test dispatch site. I did the search but didn't audit. This is the #1 process failure.
2. **Run `gofmt` after every `multiedit`.** Struct field additions shift alignment. Don't wait for a separate fmt-check step.
3. **Check `git status` before editing in a multi-agent environment.** The auto-git daemon + parallel sessions mean the working tree changes under you. `git status` before `edit` would have caught the foreign `sql_readmodel_dialect_test.go` before it broke my build.
4. **Don't trust the prior session's gap analysis.** The prior session said "OAuth2 bypass is the biggest gap" and listed the known gaps. I fixed those and stopped. I should have re-run the dispatch-site search myself instead of trusting the prior analysis was complete.
5. **The registration mutex is per-process, not per-system.** For a homelab with one browser-history instance, this is fine. But the API contract (`ServiceConfig.MaxUsers`) doesn't document this limitation. A multi-process deployment would need a DB-level lock or a fold invariant. This should be documented in the `MaxUsers` field comment.
6. **`NewOAuth2Service` nil-mutex fallback is a silent degradation.** If someone constructs `OAuth2Service` directly with `registrationMu = nil`, the gate becomes advisory (per-process mutex with no sharing with `Service.Register`). This is documented in the function comment but there's no warning log. Consider `slog.Warn` when `registrationMu == nil && maxUsers > 0`.
7. **The auto-git daemon bundles unrelated work into single commits.** My OAuth2 gate (security fix) is in the same commit as MySQL templates and dialect helpers (feature work). This makes `git bisect` and rollback harder. Not my daemon to fix, but worth flagging.
8. **No integration test for the `ErrRegistrationClosed` → HTTP 403 mapping in the OAuth2 error-redirect path.** The `TestHandler_OAuth2Callback_RegistrationClosed_Returns403` test verifies the default (no `OAuth2ErrorURL`) path. But when `OAuth2ErrorURL` is configured, the handler redirects (302) instead of returning 403 directly. The 403 status is lost in the redirect. This may be intentional (the error page can show the message), but it means the HTTP status code is not 403 in that configuration. **Not tested.**
9. **The `perProviderOAuth2Stub` test stub derives email from provider name.** This means `github` → `github@oauth.test`. But the real `testOAuth2Provider` stub (in `oauth2_stub_test.go`) always returns `oauth@test.com`. If someone adds a test that mixes both stubs, the email collision will cause unexpected linking instead of creation. The stubs should be unified or documented as incompatible.
10. **The concurrency test (`TestRegister_MixedConcurrentRegistrations_RespectMaxUsers`) uses MaxUsers=2 with 16 workers.** This is a good smoke test but doesn't stress the actual race window. A more targeted test would use MaxUsers=1 and pre-seed the read model to count=0, then fire many concurrent first-registrations. The current test with MaxUsers=2 has a wider window (2 slots) and may not catch a narrow race.

---

## f) UP TO 50 THINGS TO DO NEXT

### Security (Priority 1)
1. **Gate `import_export.go:156`** — Add `MaxUsers` check + `registrationMu` lock to `importUsers()`. This is the remaining security hole. 15-min fix.
2. **Audit for any other `RegisterUserCmd` dispatch sites** — Run `rg "NewRegisterUserCmd" usermgmt/*.go | grep -v test` and verify every site is gated. Currently: `service_register.go:92` (gated), `service_oauth2_extracted.go:262` (gated), `import_export.go:156` (NOT gated). Are there others?
3. **Document the per-process mutex limitation** in `ServiceConfig.MaxUsers` field comment — "only effective for single-process deployments; multi-process requires a DB-level lock or fold invariant."
4. **Add `slog.Warn` when `NewOAuth2Service` gets `registrationMu == nil && maxUsers > 0`** — silent degradation to advisory-only gate.

### Release & Deploy (Priority 2)
5. **Tag cqrs-htmx** — `git tag identity-model/v4.X.0 usermgmt/v4.X.0 b1ad3350` (determine version bump: minor for new feature, or patch — the breaking `NewOAuth2Service` change argues for minor).
6. **Bump browser-history `go.mod`** — Require the new cqrs-htmx tags. Run `cd /home/lars/projects/browser-history && go get github.com/larsartmann/cqrs-htmx/usermgmt/v4@<new-tag> && go mod tidy`.
7. **Tag browser-history** — After go.mod bump.
8. **Bump SystemNix `browser-history` flake input** — `nix flake lock --update-input browser-history`.
9. **Deploy** — `nix run .#deploy`.
10. **Reboot evo-x2** — Activates oomd 60%/30s + the already-pending nixpkgs registry override.
11. **Verify live** — `POST /auth/register` → 403 while logged-out; second Pocket ID first-login → 403; `oomctl` shows 60%/30s; watch `system_oomd_kills_total`.

### Test Coverage (Priority 3)
12. **Test OAuth2 error-redirect path with `OAuth2ErrorURL` configured** — Verify the 403 status is preserved (or intentionally lost) when `OAuth2ErrorURL` is set. `TestHandler_OAuth2Callback_RegistrationClosed_ErrorRedirect`.
13. **Add concurrency test with MaxUsers=1** — Narrower window, more targeted race detection. Pre-seed count=0, fire 16 concurrent first-registrations, assert exactly 1 created.
14. **Add test for `importUsers` gate** (once gated) — `TestService_ImportUsers_MaxUsersReached`.
15. **Add test for `NewOAuth2Service` with nil mutex + maxUsers > 0** — Verify it doesn't panic, logs a warning, and the gate is advisory-only.
16. **Unify or document test stub incompatibility** — `perProviderOAuth2Stub` vs `testOAuth2Provider` — different email schemes. Either merge or add a comment.

### Documentation (Priority 4)
17. **Document `MAX_USERS` in browser-history `docs/deployment-nixos.md`** — The NixOS deployment guide should show the env var in the environment file example.
18. **Add `NewOAuth2Service` migration note** — The breaking signature change needs a migration note for any consumer that calls it directly (none found, but the public API is broken).
19. **Update browser-history `docs/architecture-diagram.md`** if it shows the auth flow — the registration gate should be visible.
20. **Add a "security boundaries" section to browser-history docs** — Document what `MAX_USERS` covers (Register, OAuth2 auto-provision, import) and what it doesn't (multi-process, fold-level).

### Monitoring (Priority 5)
21. **Add a browser-history user-count metric** — Expose `browser_history_user_count` in `/metrics`. Then Gatus can alert if it exceeds `MAX_USERS`.
22. **Add Gatus check for `browser_history_user_count > 1`** — Detects any bypass.
23. **Add Gatus check for `browser_history_registration_rejected_total`** — Counter metric on 403 responses. Detects bypass attempts.

### oomd (Priority 6)
24. **Verify oomd 60%/30s after reboot** — `oomctl` output, `systemd-oomd` journal.
25. **Monitor `system_oomd_kills_total` for 24h** — dnsblockd kill rate should drop from 730x/day.
26. **Monitor Twenty worker `RestartCount`** — Should stabilize after oomd threshold raise.
27. **Consider `ManagedOOMSwap = "auto"` on user slice** — If swap pressure is also a factor.

### Code Quality (Priority 7)
28. **Run `nix run .#lint` on cqrs-htmx after the parallel session's work settles** — The lint failures I saw were pre-existing cross-module drift; verify they don't include my files.
29. **Run `golangci-lint` on browser-history** — Never run in the prior session.
30. **Verify `go vet` on cqrs-htmx `usermgmt/` after all parallel work settles** — The `sql_readmodel_dialect_test.go` collision showed the tree can be temporarily broken.
31. **Run `nix flake check --no-build` on SystemNix after the flake input bump** — Verify the new browser-history tag doesn't break the build.

### Frontend (Priority 8)
32. **Add "registration closed" state to browser-history register form** — When the API returns 403, show a friendly message instead of a raw error.
33. **Hide the register form entirely when `MAX_USERS=1` and a user exists** — Requires a "can I register?" endpoint or a frontend check.

### Architecture (Priority 9)
34. **Consider a fold-level registration invariant** — `decideRegisterUser` in `es_decide.go` could reject when a global count is exceeded. This would be the strongest guarantee (impossible state). Requires a cross-aggregate query in the decide function, which is architecturally unusual in CQRS (deciders should be pure functions of aggregate state + command). May need a saga or a pre-dispatch check in the command handler.
35. **Consider a DB-level unique constraint on user count** — Not straightforward in an event-sourced system, but a projection-level check (reject in the materializer) would be a backstop.
36. **Document the registration gate's threat model** — What it protects against (LAN-open registration, OAuth2 bypass) and what it doesn't (admin import, multi-process race, fold-level bypass).

### Operational (Priority 10)
37. **Add browser-history DB backup to `backup-coordination`** — `/var/lib/browser-history/data.db` is not backed up.
38. **Fix browser-history `expires_at` session reaper error** — Every 5 min: `no such column: expires_at`. Migration gap.
39. **Fix browser-history `CheckpointStore` upstream** — Server replays ALL events on startup (4-min projection drain).
40. **Fix browser-history OTel endpoint URL scheme** — `otlptracegrpc` with `127.0.0.1:4317` (missing `http://` scheme).
41. **Annotate superseded status reports** — `2026-08-12_20-08_nix-daemon-oomd-kill-and-twenty-worker-restart-loop.md` (resolved by oomd 60%/30s once rebooted).

### Cleanup (Priority 11)
42. **Remove the `perProviderOAuth2Stub` if `testOAuth2Provider` can be parameterized** — Reduce test stub duplication.
43. **Move `stateFromRedirectURL` to a shared test helper** — It duplicates `extractStateFromURL` from `service_oauth2_errorcontext_test.go`.
44. **Verify `context_actor_test.go` is gofmt-clean** — Verified this session (already formatted). Close the TODO item.
45. **Run `gofmt -w` on the entire `usermgmt/` package** — After all parallel work settles, to catch any remaining formatting drift.
46. **Add `import_export.go` to the `NewOAuth2Service` consumer audit** — Verify it doesn't construct its own `OAuth2Service` (it doesn't, but the pattern should be documented).
47. **Review the auto-git commit `b1ad3350` for completeness** — Verify all 6 of my files are in the commit and nothing was lost.
48. **Review the auto-git commit `b1ad3350` for foreign contamination** — Verify the MySQL/dialect/setup work in the same commit doesn't break anything I depend on.
49. **Add a CI check for ungated `RegisterUserCmd` dispatch sites** — A linter rule that flags `dispatcher.Dispatch(ctx, NewRegisterUserCmd(...))` outside `Service.Register()` / `OAuth2Service.matchOrCreateUser` / `importUsers()` (once gated).
50. **Celebrate** — The OAuth2 bypass + TOCTOU were real security gaps. They're closed. The import path is the remaining hole. Ship it.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Should `importUsers()` (the CSV import path) also be gated by `MaxUsers`?** It's an admin-only path (requires authentication + CSV upload), so the practical risk is lower than the OAuth2 bypass. But the gate is incomplete as long as it's ungated. Options: (a) gate it the same way (reject import when count >= maxUsers), (b) gate it but allow importing users that replace existing ones (import = replace, not add), (c) leave it ungated because it's admin-only and the admin is trusted. I cannot know your trust model for admin operations.

2. **Patch or minor version bump for the cqrs-htmx tag?** The `NewOAuth2Service` signature change is breaking for any direct consumer. SemVer says breaking = major (v5). But this is a homelab with one consumer (browser-history) that I also control, and the function is rarely called directly (consumers use `NewService`). Options: (a) minor bump (v4.8.0) with a migration note, (b) patch bump (v4.7.1) treating the signature change as internal, (c) major bump (v5.0.0) following strict SemVer. I cannot know your versioning philosophy for this ecosystem.

3. **Should I gate the import path NOW (before the status report is done) or wait for your decision?** I discovered the `import_export.go` bypass during this status report. It's a 15-minute fix (same pattern as the other two paths). But you said "DO NOT RESEARCH OTHER STUFF UNRELATED TO WHAT YOU DID. Just report based on this current sessions run and what you noticed." — so I'm reporting it, not fixing it. Should I fix it before the release chain (tag/bump/deploy) or is it acceptable to ship with the import path ungated for now?

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Files changed (cqrs-htmx) | 6 (service_core.go, service_oauth2_extracted.go, service_register.go, handler_register_test.go, oauth2_http_test.go, service_oauth2_register_test.go) + CHANGELOG.md |
| Files changed (browser-history) | 2 (README.md, docs/configuration.md) |
| Files changed (SystemNix) | 4 (CHANGELOG.md, TODO_LIST.md, AGENTS.md, status report annotation) |
| Tests added | 8 (5 service, 2 handler, 1 concurrency) |
| Test suites run | usermgmt (20.7s), identity-model (0.006s), browser-history (pass), `-race` (2.4s), `nix flake check --no-build` (pass) |
| Commits (auto-git) | cqrs-htmx `b1ad3350`, browser-history `f6c5c0b` |
| Security gaps closed | 2 (OAuth2 bypass, TOCTOU) |
| Security gaps remaining | 1 (`import_export.go` bypass) |
| Questions to user | 3 |
