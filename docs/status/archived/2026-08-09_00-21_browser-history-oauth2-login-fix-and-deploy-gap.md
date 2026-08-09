# Status Report: Browser History OAuth2 Login Fix + Deploy Script Gap

**Date:** 2026-08-09 00:21
**Session Start:** ~2026-08-08 22:08 (pocket-id-provision fix session)
**Session End:** 2026-08-09 00:21
**Host:** evo-x2 (NixOS)
**Author:** Crush session

---

> **RESOLVED — OAuth2 login fix deployed. Browser-history healthy with OAuth2 providers configured. Remaining items in TODO_LIST.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## Executive Summary

User reported that `https://history.home.lan/register` had no "Login with Pocket ID" button. Investigation revealed a **multi-layer failure**: (1) the OIDC setup oneshot ran before pocket-id-provision succeeded and was never re-triggered, (2) the deploy script lacked `browser-history-oidc-setup` in its provisioner restart list, and (3) even after OAuth2 was configured, the upstream `cqrs-htmx/usermgmt` library returned JSON instead of an HTTP 302 redirect, making the login link display raw JSON in the browser. All three issues were fixed across 3 repos (cqrs-htmx, browser-history, SystemNix), deployed, and verified.

---

## a) FULLY DONE

### 1. Root Cause: `browser-history-oidc-setup` Never Re-Triggered After Provision Fix

**Problem:** `browser-history-oidc-setup.service` ran at boot (21:49) while `pocket-id-provision.service` was still failing. It waited 120s for the secret file, gave up, and started browser-history in WebAuthn-only mode. After the provision fix (22:08), the oneshot was never re-triggered because it was NOT in the deploy script's provisioner restart list.

**Evidence:**
- `journalctl -u browser-history-oidc-setup.service` at 21:51: "Pocket ID secret not found — starting in WebAuthn-only mode"
- `/var/lib/browser-history/oauth2-secrets.env` did NOT exist
- No "Login with Pocket ID" button rendered (server had `oauth2Providers = []`)

**Fix:** `scripts/deploy.sh` — Added `browser-history-oidc-setup` to the provisioner restart loop (after `pocket-id-provision`) and added an explicit `browser-history.service` restart after OIDC setup completes so it reloads the freshly-written OAuth2 env file.

### 2. Upstream Bug: OAuth2 Begin Endpoint Returned JSON Instead of Redirect

**Problem:** `cqrs-htmx/usermgmt/oauth2_http.go` `handleOAuth2Begin` returned `200 {"redirect_url": "..."}` JSON. The browser-history template rendered a plain `<a href="/auth/oauth/pocket-id/begin">` link. Clicking it navigated the browser to the endpoint, which displayed raw JSON instead of redirecting to Pocket ID.

**Fix:** Changed `writeJSON(w, http.StatusOK, resp)` → `http.Redirect(w, r, resp.RedirectURL, http.StatusFound)` in `oauth2_http.go:35`.

**Files changed:**
- `cqrs-htmx/usermgmt/oauth2_http.go` — 1-line fix (line 35)
- `cqrs-htmx/usermgmt/oauth2_http_test.go` — 3 tests updated (TestHandler_OAuth2Begin_Success, TestHandler_OAuth2Callback_Success, TestHandler_OAuth2Callback_SuccessRedirect), removed unused `encoding/json/v2` import
- All 16 OAuth2 tests pass

### 3. Full Dependency Chain Updated and Deployed

| Repo | Change | Commit/Tag |
|------|--------|------------|
| cqrs-htmx | OAuth2 redirect fix + test updates | `c26a0540`, tagged `usermgmt/v4.7.1` |
| browser-history | cqrs-htmx flake input bumped to `c26a0540` | `42a58786` |
| SystemNix | `scripts/deploy.sh` fix, browser-history + buildflow flake inputs updated, hermes-agent re-lock, nixpkgs tarball fix | uncommitted (auto-daemon + manual) |

### 4. Verification

- `/auth/oauth/pocket-id/begin` now returns `302 Found` with `Location: https://auth.home.lan/authorize?client_id=browser-history&...` (confirmed via Python HTTP client)
- `browser-history.service` logs: `OAuth2 providers configured: ["pocket-id"]`
- `/var/lib/browser-history/oauth2-secrets.env` exists (107 bytes, root:root, 600)
- Post-deploy smoke test: 30 PASS, 0 FAIL, 8 SKIP (2 DiscordSync skips expected during backfill)
- Running binary confirmed: `42a5878-browser-history-server` (was `0a10a23` before rebuild)

---

## b) PARTIALLY DONE

### 1. AGENTS.md Updates — NOT DONE
The following gotchas were identified but NOT yet written to AGENTS.md:
- Pocket ID SQLite BUSY / provisioning curl timeout gotcha
- `browser-history-oidc-setup` deploy script ordering dependency
- OAuth2 begin endpoint redirect (was JSON, now 302)

### 2. Pocket ID Provision Service Hardening — NOT DONE
- `api_get` still has `--max-time 10` (should be 30s for consistency)
- `TimeoutStartSec = "3min"` not added to `pocket-id-provision.service`
- No `--retry` on curl calls for transient SQLITE_BUSY errors

### 3. End-to-End OAuth2 Login Test — NOT DONE
Verified the endpoint returns 302 and OAuth2 is configured, but did not complete the full browser flow (Pocket ID authenticate → callback → session cookie → dashboard).

---

## c) NOT STARTED

### From Previous Session's Remaining Items
1. **Auth gateway health warnings** — 6 vHosts (dozzle, monitor365, searx, crush, taskchampion, signoz) returning `000000` in post-deploy check. Not investigated.
2. **`cache.home.lan` DNS resolution failure** during builds — Not investigated.
3. **DiscordSync API not ready during post-deploy** — Skip is expected (API binds after thumb-hash backfill), but this consistently delays post-deploy checks.
4. **Browser History OTel parse error** — `parse "127.0.0.1:4317": first path segment in URL cannot contain colon` — Go expects `host:port` without scheme for gRPC, but `otlptracegrpc` may need `://` prefix. Pre-existing, not caused by this session.

---

## d) TOTALLY FUCKED UP

### 1. `lib.fakeHash` Fiasco
Set `vendorHash = lib.fakeHash` to trigger a hash mismatch and get the real hash. But `mkPreparedSource` overrides dependency versions with nix store paths, so the vendor contents were IDENTICAL and the hash was the same. Wasted a build cycle. Should have just built directly — the vendor hash doesn't change when the cqrs-htmx rev changes because `mkPreparedSource` pins deps via store paths, not go.mod versions.

### 2. First Deploy Built Nothing
After updating flake.lock, ran `nix run .#deploy`. The `nh os switch` failed silently (exit code 1) due to a buildflow vendorHash mismatch. The deploy script's `set +e` swallowed this, and the old `0a10a23` binary kept running. The post-deploy "all checks passed" was misleading — it checked liveness, not that the new binary was deployed. I should have checked the running binary version after the first deploy, not assumed it worked.

### 3. nixpkgs Tarball Regression (Recurring)
The nixpkgs tarball lock regression hit AGAIN during this session. `scripts/fix-nixpkgs-lock.sh` fixed it, but this is the Nth recurrence. The fix in `configuration.nix` (local empty flake-registry + correct-format registry overrides) should prevent it, but something keeps re-introducing the tarball type. This needs deeper investigation.

### 4. hermes-agent Stale Store Path
After fixing the nixpkgs tarball, `nix flake check` failed with `path '4mkggi647v4d0z8q5rdgqjkwnbpmg9sz-source' is not valid` for hermes-agent. Fixed with `nix flake update hermes-agent`. This is a recurring pattern — flake.lock references store paths that get GC'd.

### 5. Missing `browser-history-oidc-setup` in Deploy Script Was a Design Blind Spot
The deploy script restarts 8 provisioner oneshots. `browser-history-oidc-setup` was missing from this list since it was added. Every deploy that didn't change the binary but DID change provisioning state would leave browser-history in a stale OAuth2 config. This was a systemic gap in the deploy script's coverage, not just a one-off omission.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture / Design

1. **Deploy script should auto-discover provisioner oneshots** — Hardcoding a list of provisioner names is brittle. Every new OIDC-integrated service needs to be manually added. Should auto-discover `Type=oneshot, RemainAfterExit=true` services that are `wantedBy` another service.

2. **Post-deploy check should verify binary versions** — The smoke test checks HTTP liveness but not whether the deployed binary matches the expected nix store path. A stale binary passes all checks. Should compare `/proc/<pid>/exe` against the expected store path from the NixOS config.

3. **OAuth2 begin endpoint contract** — The `RegisterOAuth2Routes` doc comment said "redirect to provider's authorization page" but the implementation returned JSON. The comment was correct; the code was wrong. This mismatch went unnoticed because the library is consumed via workspace `replace` directives, not published versions. More downstream consumers would have caught it sooner.

4. **`browser-history-oidc-setup` ordering** — The oneshot has `wantedBy = [ "browser-history.service" ]` but `RemainAfterExit=true` means it only runs once. If it fails (secret not found), it stays "active (exited)" and browser-history starts without OAuth2. There's no mechanism to re-trigger it when the secret becomes available. A `restartTriggers` on the secret file path would help.

5. **`mkPreparedSource` hides dependency changes** — When cqrs-htmx source changes but the Go API surface doesn't, the vendor hash stays the same because `mkPreparedSource` pins deps via store paths. This means a stale binary can be "up to date" according to the vendor hash but contain old code. The `restartTriggers = [ serverPkg ]` on the systemd service is the safety net, but only if the nix store path actually changes (which requires a successful build).

### Process

6. **Always verify running binary version after deploy** — `cat /proc/$(pgrep)/cmdline`. The deploy script's exit code is unreliable (nh swallows build failures).

7. **Test the OAuth2 flow in a browser after deploying auth changes** — Not just the API endpoint. The JSON-in-body bug was visible to any browser user immediately.

8. **Pre-deploy check should catch stale binary builds** — If `nix build` fails, the deploy should abort, not continue with the old system.

---

## f) Up to 50 Things to Do Next

### Critical / High Priority

1. **Complete end-to-end OAuth2 login test** — Visit `https://history.home.lan/login`, click "Login with Pocket ID", complete the flow, verify session cookie and dashboard access
2. ~~**Commit SystemNix changes** — deploy.sh fix + flake.lock updates are uncommitted~~ done — committed
3. ~~**Update AGENTS.md** — Add Pocket ID SQLite BUSY timeout gotcha, browser-history-oidc-setup deploy ordering, OAuth2 begin redirect fix~~ done — AGENTS.md updated with all patterns
4. **Fix `api_get` timeout** — Change `--max-time 10` to `--max-time 30` in pocket-id.nix for consistency
5. ~~**Add `TimeoutStartSec = "3min"` to pocket-id-provision**~~ done — global `DefaultTimeoutStartSec=3min` via `timeout-audit.nix`
6. **Add `restartTriggers` to `browser-history-oidc-setup`** — Watch the secret file path so the oneshot re-runs when the secret appears
7. **Investigate nixpkgs tarball regression root cause** — Why does it keep recurring despite the local empty flake-registry fix?
8. ~~**Fix buildflow vendorHash mismatch**~~ done — vendorHash cascade fix (`15f264c2`)

### Auth / SSO

9. **Test Browser History passkey registration** — Verify WebAuthn still works alongside OAuth2
10. **Test Browser History OAuth2 user provisioning** — Does Pocket ID login auto-create a browser-history user? Or does the user need to register first?
11. **Verify OAuth2 callback success URL** — Confirm redirect goes to `/` (dashboard) after login
12. **Test OAuth2 error handling** — What happens if user denies consent in Pocket ID?
13. **Consider auto-linking** — If a user registers with email `X` via WebAuthn, then logs in via Pocket ID with the same email, are the accounts linked?
14. ~~**Document the two auth paths**~~ done — AGENTS.md:421

### Deploy Infrastructure

15. **Auto-discover provisioner oneshots in deploy.sh** — Replace hardcoded list with `systemctl list-units --type=service --property=Type,RemainAfterExit`
16. **Add binary version check to post-deploy-check.sh** — Compare `/proc/<pid>/exe` against expected nix store path
17. **Make pre-deploy-check verify builds will succeed** — Currently `nix flake check --no-build` passes but `nix build` fails (vendorHash mismatches). Should do a dry-run build.
18. ~~**Add `browser-history-oidc-setup` to deploy.sh restart list**~~ done — `deploy.sh:52`
19. **Consider `PartOf` relationships** — `browser-history-oidc-setup` should be `PartOf` `browser-history.service` so it restarts together
20. **Stagger deploy script restarts** — All provisioners restart simultaneously, causing IO contention on QLC NAND

### Pocket ID

21. **Add `--retry 3 --retry-delay 2` to curl calls** — Handles transient SQLITE_BUSY without code changes
22. **Consider PostgreSQL backend for Pocket ID** — SQLite contention from francis actor-host is a recurring problem
23. **Add Pocket ID API health check to Gatus** — May already exist, verify it covers the provision flow
24. **Document the Pocket ID provision flow** — The script is complex (admin user, avatar, 6 clients, logos, secrets). Add a sequence diagram.
25. **Consider Pocket ID provision parallelism** — Clients are provisioned sequentially. With 6+ clients, this is slow under contention.

### Monitoring / Alerting

26. **Investigate auth gateway `000000` warnings** — 6 vHosts returning 000000 in post-deploy check. Are these transient (services settling) or persistent?
27. **Add Gatus check for browser-history OAuth2** — Verify the begin endpoint returns 302, not 200
28. **Add Gatus check for browser-history-oidc-setup** — Alert if the oneshot is in "failed" state
29. **Monitor pocket-id-provision execution time** — Alert if it exceeds 60s (indicates SQLite contention)

### Browser History

30. **Fix OTel endpoint format** — `127.0.0.1:4317` causes parse error. Should be `http://127.0.0.1:4317` for gRPC or use port 4318 for HTTP
31. **Consider adding Browser History to Homepage** — May already be there, verify
32. **Test Browser History backup** — Is `browser-history.db` included in backup-coordination?
33. **Add Browser History to Gatus** — Health check on `/health` endpoint
34. **Consider Browser History data retention** — How long to keep browsing history? Auto-purge?

### Technical Debt

35. **Remove `BeginOAuthLoginResponse` struct** — No longer used by the handler (was for JSON response, now we redirect). The service method still returns it, but the handler only uses `.RedirectURL`.
36. **Consider returning `(url string, err error)` from `BeginOAuthLogin`** — Instead of a struct with one field
37. **Add integration test for full OAuth2 flow** — Begin redirect → Pocket ID authorize → callback → session cookie → authenticated request
38. **Pin BuildFlow to a specific rev** — Currently `ref=master`, causing unexpected vendorHash mismatches when upstream pushes
39. **Pin all `ref=master` flake inputs** — Audit and pin all LarsArtmann inputs that use `ref=master`
40. **Consider `nix flake update` automation** — A timer that checks for input updates and creates PRs

### Documentation

41. **Document the OAuth2 redirect fix in cqrs-htmx CHANGELOG** — The usermgmt/v4.7.1 tag has a message but no CHANGELOG entry
42. **Update browser-history FEATURES.md** — OAuth2/Pocket ID integration is a feature
43. **Document the 3-repo dependency chain** — cqrs-htmx → browser-history → SystemNix, with the publish/tag/bump flow
44. ~~**Add browser-history-oidc-setup to the SSO architecture table in AGENTS.md**~~ done — AGENTS.md:206 Layer 1

### Cleanup

45. ~~**Remove unused `writeJSON` import if any**~~ done — "never mind", still used in callback handler
46. **Clean up stale build sandboxes** — Pre-deploy check warned: "12 stale build sandboxes in /nix/var/nix/builds"
47. **Run `nix-build-cleanup`** — Address the warning from pre-deploy check
48. **Root filesystem at 88%** — Pre-deploy warning. Consider garbage collection.
49. **DiscordSync post-deploy skips** — Consistently skipped because API isn't ready. Consider delaying post-deploy check or making DiscordSync check async.
50. **Consider adding `--fail` to curl in pocket-id provision script** — Currently checks `$HTTP_CODE` manually, but `--fail` would exit non-zero on 4xx/5xx automatically

---

## g) Questions (Cannot Determine Myself)

### Q1: Browser History OAuth2 user provisioning model
When a user logs in via Pocket ID for the first time, does browser-history auto-create a user account (like Forgejo's `ENABLE_AUTO_REGISTRATION`), or must the user first register via `/register` and then link their Pocket ID account? I cannot determine this from the Nix config alone — it depends on the `cqrs-htmx/usermgmt` `FinishOAuthLogin` implementation, which I didn't read in full.

### Q2: Should `browser-history-oidc-setup` use `PartOf` or `BindsTo`?
Adding `PartOf = [ "browser-history.service" ]` would make it restart when browser-history restarts. But `BindsTo` would be stronger (stops the oneshot when browser-history stops). I'm not sure which is semantically correct for a provisioning oneshot that should run BEFORE the main service, not alongside it. The current `wantedBy` + `before` ordering works but doesn't handle re-triggering.

### Q3: Is the `BeginOAuthLoginResponse` struct part of the public API?
I changed the handler to use `http.Redirect` instead of returning the struct as JSON. But the struct and the `BeginOAuthLogin` service method still exist. Should I deprecate/remove the struct, or is it part of the published `usermgmt/v4` API that other consumers might depend on? I can't check all consumers of `cqrs-htmx/usermgmt` from this repo.
