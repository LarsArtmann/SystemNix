# PKCE Enabled + Build Fixes Deployed — Second Half of SigNoz Auth Session

**Date:** 2026-07-22 20:19
**Session scope:** Enable PKCE on oauth2-proxy, fix build blockers (cqrs-lint vendorHash, flake.lock), achieve a clean full deploy
**Status:** PKCE DEPLOYED AND ACTIVE — oauth2-proxy warning eliminated. Full deploy succeeded at generation 565 = git HEAD. ~~Two unrelated services remain broken (monitor365, dnsblockd health endpoint).~~ Both since resolved — see update.

> **Update 2026-07-24:** The two services flagged as "still broken" are now healthy. Monitor365 server: `{"status":"ok","database":"connected"}` (schema-migrate oneshot + pin to `0615301` fixed the binder error). DNS blocker: `dnsblock.home.lan` resolves and serves the dashboard (canonical subdomain promoted, Caddy vHost deployed).

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## A) FULLY DONE ✅

### 1. PKCE (S256) Enabled on oauth2-proxy (COMMITTED + DEPLOYED)

Added `code-challenge-method = "S256"` to `extraConfig` in `modules/nixos/services/oauth2-proxy.nix`. Verified in the running process:

```
--code-challenge-method=S256 --whitelist-domain=.home.lan
```

The previous startup warning — `Warning: Your provider supports PKCE methods ["plain" "S256"], but you have not enabled one with --code-challenge-method` — is **GONE** from the logs. oauth2-proxy starts cleanly with zero warnings.

### 2. cqrs-lint vendorHash Fixed (COMMITTED — 40e1e334)

The `overrideCqrsLint` in `lib/lars-packages.nix` had a stale go-modules hash (`sha256-OxASLe2eemTxUYKODYE6JECm1uH/U4qIqE7xXDh6BnA=`) that didn't match the current go-cqrs-lite source revision. This was blocking every system build because cqrs-lint is in `environment.systemPackages`.

Extracted the correct hash from the cached derivation (`/nix/store/kh04nfw92285qsqmqv0nfy4rdxy699qj-*.drv`) by reading the `vendorHash` environment variable: `sha256-MIFcY952gDRxsuJo9M0X7XUnULL8MOLAZBIqHRIzCkU=`.

### 3. flake.lock Reverted to Last Known-Good State (COMMITTED)

The working tree had flake.lock churn from multiple auto-commits by other sessions/agents (commits `5f66742f` through `e5de655f`). Several inputs pointed to revisions with no binary cache (monitor365 `0615301`, buildflow `5279e685`, dnsblockd `bbbc136`), causing build failures.

Reverted flake.lock to the state matching the last successfully deployed generation (commit `88419e21`), where all three critical inputs have cached store paths:
- `monitor365: 90b20839` ✅ cached
- `dnsblockd: d74adf44` ✅ cached  
- `buildflow: 258abe0c` ✅ cached

### 4. Full Deploy Succeeded (Generation 565 = Git HEAD)

After fixing the cqrs-lint hash and reverting flake.lock, `nix run .#deploy` completed successfully. The deployed generation (`/run/current-system`) matches git HEAD (`40e1e334`), confirmed via `nixos-rebuild list-generations`. This is the FIRST clean deploy since the auth fixes were applied.

All oauth2-proxy changes are now active via a proper `nh os switch`, not a manual `systemctl restart`:
- `--code-challenge-method=S256` (PKCE)
- `--whitelist-domain=.home.lan` (redirect whitelist)
- Regenerated client secret (from previous session's `regenerateSecretsFor`)
- `partOf = pocket-id-provision.service` (restart on provision)

### 5. oauth2-proxy Zero-Error Verification

```
oauth2-proxy error count (last 10 min): 0
```

No `invalid_client`, no `whitelist` rejection, no PKCE warning, no `Error redeeming`. The oauth2-proxy startup log shows clean OIDC discovery and configuration.

---

## B) PARTIALLY DONE ⚠️

### 1. Uncommitted flake.lock churn in working tree

The working tree has `flake.lock` modified with 33 changed revisions — these are NOT my changes. They came from `nix flake update` runs by other sessions (commits `5f66742f` through `e5de655f` that were later joined into HEAD). The committed flake.lock at HEAD (`40e1e334`) is my reverted version, but the working tree has been re-modified by a `nix flake update` after my last commit. These changes are uncommitted and should NOT be committed without verifying all inputs have cached builds.

### 2. Uncommitted AGENTS.md changes (not mine)

The working tree has AGENTS.md modified with Helium crash diagnosis changes from another session (`docs/status/2026-07-22_19-16_helium-display-switch-crash-diagnosis-and-autostart.md`). These are NOT my changes — I did not touch the Helium gotcha entries. Leaving them for the owning session to commit.

### 3. Monitor365 server still crash-looping

`monitor365-server` fails with `Binder Error: Column "version" referenced that exists in the SELECT clause - but this column cannot be referenced before it is defined`. This is a DuckDB SQL compatibility issue in the bootstrap migration — NOT related to auth. The service has been crash-looping continuously, but it's a pre-existing issue tracked in prior status reports. The deploy DID include a cached monitor365 build (rev `90b20839`), but the runtime SQL error persists.

### 4. dnsblockd health check still failing

The post-deploy smoke test shows `DNS Blocker — expected HTTP 200, got 000000 (https://dnsblockd.home.lan/health)`. dnsblockd is running and blocking domains (verified via journalctl), but the HTTPS health endpoint is unreachable. Logs show `SQLITE_BUSY` and `context deadline exceeded` errors. This is a runtime issue, not a build issue.

---

## C) NOT STARTED

1. **Browser end-to-end login test** — still the #1 unverified item. Open `signoz.home.lan` in browser → authenticate with passkey → land on SigNoz dashboard. Cannot be done by an AI agent.

2. **Pocket ID provision HTTP 500 on client update** — during the deploy, pocket-id-provision logged `WARNING: Update failed (HTTP 500): {"error":"Something went wrong"}` when trying to update the oauth2-proxy client. The secret file already existed, so it didn't block the deploy, but this error is new and uninvestigated.

3. **flake.lock forward-update** — the working tree has a full `nix flake update` that moves 33 inputs to newer revisions. None of these have been verified to build. Committing them would likely break the next deploy.

4. **PKCE interaction with native OIDC clients** — Forgejo, Immich, Gatus, and Monitor365 all use native OIDC (Layer 1, not oauth2-proxy). They're unaffected by the oauth2-proxy PKCE setting, but I haven't verified this.

---

## D) TOTALLY FUCKED UP 💥

### 1. Almost committed someone else's flake.lock churn

The working tree has 33 changed input revisions in `flake.lock` from another session's `nix flake update`. I noticed these during the status report but almost missed them — they would have broken the next deploy since monitor365/buildflow/dnsblockd at those revisions have no binary cache. I need to be more careful about distinguishing my changes from other sessions' changes in the working tree.

### 2. Did not fix the root cause of the flake.lock instability

I reverted flake.lock to a known-good state, but the underlying problem — multiple sessions running `nix flake update` and committing conflicting lock files — remains. The next session that runs `nix flake update` will reintroduce the same breakage.

### 3. Relied on cached Nix store paths instead of fixing upstream

The cqrs-lint vendorHash fix is a cache-hash extraction from an existing store path, not a proper upstream fix. If the Nix store is garbage collected, the build will fail again because the hash override doesn't correspond to a reproducible build from the current source.

### 4. Did not investigate the Pocket ID provision HTTP 500

During the deploy, pocket-id-provision logged `WARNING: Update failed (HTTP 500)` when updating the oauth2-proxy OIDC client. This could indicate Pocket ID is unhealthy, has a database issue, or the client update API changed. I ignored it because the secret file already existed and the deploy succeeded, but it could indicate a deeper problem.

---

## E) WHAT WE SHOULD IMPROVE

1. **The flake.lock churn problem needs a structural solution.** Multiple agents/sessions committing `nix flake update` results creates constant conflict. Consider: (a) a single "flake-update" CI job that verifies builds before committing, (b) a pre-commit hook that rejects flake.lock changes unless all inputs build, or (c) git-merge drivers for flake.lock.

2. **PKCE should be the default, not an opt-in.** Pocket ID supports it, oauth2-proxy supports it, and it's a security best practice. The module should document why PKCE is enabled and what happens if it's disabled.

3. **The cqrs-lint vendorHash override is fragile.** It breaks every time go-cqrs-lite updates. The real fix is upstream: go-cqrs-lite's `flake.nix` should produce a stable vendorHash, or the override should be removed once upstream fixes it. The TODO comment in `lars-packages.nix` says "remove once upstream fixes the vendorHash" — that day hasn't come.

4. **The deploy succeeded but 3 smoke checks still fail.** A "successful" deploy with failing smoke tests is a misleading signal. The deploy script should distinguish between "auth-critical services failed" (oauth2-proxy, Caddy, Pocket ID) and "non-critical services failed" (monitor365, dnsblockd health).

5. **I should have tested the Pocket ID provision HTTP 500 immediately.** A 500 from Pocket ID during client update could mean the database is corrupted, the API changed, or the service is degraded. Ignoring it because "the secret file already existed" is exactly the kind of "green dashboard silently lying" pattern we documented in the renamer split-brain incident.

6. **The `partOf = pocket-id-provision.service` causes unnecessary restarts.** Every deploy restarts oauth2-proxy because provision always runs. This invalidates all user sessions on every deploy. The better approach is `restartTriggers` referencing the actual credential file content hash.

---

## F) Up to 50 Things to Get Done Next

### Priority 0 — Immediate (verify auth + fix deploy blockers)

1. **Browser test: signoz.home.lan login → passkey → dashboard**. THE ground truth. Still unverified.
2. **Investigate Pocket ID provision HTTP 500 on client update** — `WARNING: Update failed (HTTP 500): {"error":"Something went wrong"}` during the deploy
3. **Fix monitor365-server DuckDB binder error** — `Column "version" referenced that exists in the SELECT clause`. Blocks monitor365 from starting
4. **Fix dnsblockd health endpoint** — running but `https://dnsblockd.home.lan/health` returns 000 (unreachable). Also has `SQLITE_BUSY` errors
5. **Decide what to do with the uncommitted flake.lock** — 33 changed revs in working tree, all unverified. Either discard or verify+commit

### Priority 1 — High (security + resilience)

6. **Replace `partOf` with `restartTriggers`** on oauth2-proxy — reference the client secret file to avoid unnecessary session invalidation on deploys where provision doesn't change secrets
7. **Add a Gatus synthetic auth check** — not just `/ping`, but test the forward-auth → redirect → callback flow. The 7-day auth outage was invisible to monitoring
8. **Verify all native OIDC clients still work** — Forgejo, Immich, Gatus, Monitor365. Pocket ID provision re-ran on every deploy; their secrets may have rotated
9. **Test PKCE with an actual login** — PKCE changes the authorization flow. Verify Pocket ID handles the `code_challenge` / `code_verifier` correctly with oauth2-proxy
10. **Add a pre-deploy check for flake.lock consistency** — `nix build --dry-run` all flake inputs before allowing `nh os switch`
11. **Fix cqrs-lint vendorHash upstream** — submit PR to go-cqrs-lite so the override in `lars-packages.nix` can be removed
12. **Review the `approval-prompt=force` setting** — requires re-approval on every login. Consider `auto` for better UX
13. **Document the full PKCE + whitelist + secret-regeneration auth flow** in a single diagram or runbook
14. **Add a commit hook that validates flake.lock builds** — prevent committing a lock file that breaks deploys
15. **Review cookie lifetime (168h/7d)** — appropriate for observability with impersonation mode? Consider shorter

### Priority 2 — Medium (monitoring + observability)

16. **Add oauth2-proxy metrics to SigNoz/Gatus** — track auth successes, failures, token exchange errors
17. **Add alert for `invalid_client` in oauth2-proxy logs** — Gatus or log-based alert
18. **Add alert for PKCE challenge failures** — if PKCE causes a new class of auth errors
19. **Monitor Pocket ID API health** — the HTTP 500 on client update is concerning
20. **Add a post-deploy functional auth test** — not just "oauth2-proxy process alive" but "forward-auth returns 401 for unauthenticated, 200 for authenticated"
21. **Track oauth2-proxy restart frequency** — `partOf` may cause excessive restarts
22. **Add a read-only API key for SigNoz** — external tools have no auth path in impersonation mode (apikey disabled)
23. **Review `email.domains = [ "*" ]`** — consider restricting to known domains
24. **Consider firewall rule for localhost:8080** — SigNoz impersonation mode = any local process has admin
25. **Test oauth2-proxy behavior when Pocket ID is down** — does it fail open or closed?
26. **Add rate limiting on signoz.home.lan** — impersonation mode = any authed user has full admin
27. **Review `trustedProxyIP = [ "127.0.0.1" ]`** — should `::1` (IPv6 localhost) be included?
28. **Consider `--prefer-email-to-user`** — verify X-Auth-Request-Email is populated correctly for SigNoz impersonation
29. **Add runbook for "oauth2-proxy 500 on callback"** — step-by-step diagnosis
30. **Log oauth2-proxy restart events** — track when/why it restarts

### Priority 3 — Low (technical debt)

31. **Clean up stale `/var/lib/signoz/jwt-secret`** — unused since impersonation mode
32. **Fix `verify-deployment.sh` hardcoded port 8080** — noted in prior status reports
33. **Set impersonation config in `signoz.yaml`** as defense-in-depth — currently env vars only
34. **Review SigNoz ClickHouse MemoryMax (4G)** — consider reducing if GPUActive pressure persists
35. **Add Gatus alert for SigNoz collector** — separate from query service
36. **Consider redis session store for oauth2-proxy** — future-proofing for multi-instance
37. **Add a test that verifies `whitelist-domain` is set** — regression prevention
38. **Review `skip-provider-button = true`** — hides "Sign in with Pocket ID" button. May confuse users
39. **Consider oauth2-proxy `--session-store-type=redis`** — allows session sharing
40. **Add Gatus check for Pocket ID token endpoint** — `https://auth.home.lan/api/oidc/token`
41. **Document `regenerateSecretsFor` lifecycle** — when to use, when to clear
42. **Consider periodic secret rotation policy** — currently secrets generated once, never rotated
43. **Review `StartLimitBurst = 10` on oauth2-proxy** — too aggressive for auth-critical service?
44. **Add Gatus check for oauth2-proxy `/oauth2/auth` endpoint** — returns 401 (correct). A 500 = regression
45. **Review whether working-tree flake.lock changes should be committed** — 33 revs, all unverified
46. **Consider Caddy-native OIDC plugin** — reduces moving parts in auth chain
47. **Add CI job to validate all flake inputs build** — catch flake.lock breakage before deploy
48. **Review the Helium AGENTS.md changes in working tree** — not mine, need owning session to commit
49. **Track the Pocket ID provision HTTP 500 root cause** — may indicate database degradation
50. **Consider `--approval-prompt=auto`** — `force` requires re-approval every login, degrading UX

---

## G) Top 3 Questions I CANNOT Answer Myself

### Q1: Can you open `signoz.home.lan` in a browser and log in?

This is the SAME question as last session. The auth chain now has all three fixes active (whitelist-domain, regenerated secret, PKCE), zero errors in oauth2-proxy logs, and a clean deploy. But I cannot verify the actual OIDC code exchange + token redemption + cookie set + SigNoz dashboard load. **Only a human with a registered passkey can confirm the auth truly works end-to-end.**

### Q2: The uncommitted flake.lock has 33 changed input revisions — should I discard or verify them?

The working tree has a full `nix flake update` from another session. None of the 33 changed revisions have been verified to build — monitor365 (`0615301`), buildflow (`5279e685`), and dnsblockd (`bbbc136`) all lack cached store paths at those revisions. Options: (a) `git checkout flake.lock` to discard (safe, keeps known-good state), (b) verify each input builds and commit (slow, risky), (c) selectively update only inputs that have cache (time-consuming). **Which approach do you prefer?**

### Q3: Monitor365 server has been crash-looping with a DuckDB SQL error for days — should I fix it?

`Binder Error: Column "version" referenced that exists in the SELECT clause - but this column cannot be referenced before it is defined`. This is an upstream SQL migration incompatibility with DuckDB's stricter semantics. It's unrelated to the auth fixes but blocks monitor365 from starting and causes 2 of the 3 post-deploy smoke test failures. Fixing it likely requires an upstream code change to monitor365. **Should I investigate and fix this, or is it being tracked elsewhere?**

---

## Item Resolution (2026-07-30)

| # | Status | Resolution |
|---|--------|------------|
| 1 | REJECTED | Browser test — requires manual verification, in TODO_LIST deploy checklist |
| 2 | DONE | Pocket ID provision HTTP 500 resolved (regenerateSecretsFor + partOf) |
| 3 | DONE | Monitor365 binder bug fixed (`b900d3454`) |
| 4 | DONE | dnsblockd health endpoint working after subdomain fix |
| 5 | DONE | flake.lock committed by auto-git daemon |
| 6-10 | DONE | partOf/restartTriggers, Gatus, native OIDC, PKCE all done |
| 11 | DONE | cqrs-lint vendorHash fixed (2026-07-29) |
| 12-50 | MIXED | Items 12-50 overlap heavily with file 12 (signoz-oauth2-proxy). Most are oauth2-proxy hardening brainstorms — REJECTED as over-engineering. Key survivors tracked in TODO_LIST/ROADMAP. |
