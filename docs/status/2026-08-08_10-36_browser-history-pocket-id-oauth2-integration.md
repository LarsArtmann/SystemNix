# Status Report — 2026-08-08 10:36

## Browser-History Pocket ID OAuth2/OIDC SSO Integration

---

## A) FULLY DONE

### Browser-History Go Code (upstream repo)

1. **Pocket ID OAuth2 provider** added to `api/oauth2.go` — registers `pocket-id` provider using OIDC discovery (`IssuerURL`), callback at `/auth/oauth/pocket-id/callback`. Committed in `4eb0007`.
2. **Config fields** added to `api/config.go` — `OAUTH2_POCKET_ID_CLIENT_ID`, `OAUTH2_POCKET_ID_CLIENT_SECRET`, `OAUTH2_POCKET_ID_ISSUER`. `hasOAuth2Provider()` extended to include Pocket ID. Committed in `4eb0007`.
3. **Provider label** `"pocket-id" → "Pocket ID"` added to `oauth2ProviderLabel()` in `api/oauth2.go`. Committed in `4eb0007`.
4. **Test coverage** — `TestOAuth2ProviderLabel/pocket-id` added to `api/oauth2_test.go`. All OAuth2 tests pass. Committed in `4eb0007`.
5. **Upstream NixOS module** (`nix/server-module.nix`) — `oauth2.pocketId.{clientId,issuer}` options added, env vars wired, assertion updated, envFile example updated. Committed in `4eb0007`.
6. **vendorHash bump** — Updated from `sha256-Wcj1...` to `sha256-8P/d...` to match the shifted dep graph. Committed in `6fb09a6`.
7. **Standalone build verified** — `nix build .#browser-history-server` produces a working binary (tested, server starts on :8080).
8. **Tests pass** — `go test ./api/... -run "TestOAuth2" -v` and full `go test ./api/...` both green.

### SystemNix Integration

9. **Pocket ID OIDC client registered** in `pocket-id.nix` — `browser-history` client with callback `https://history.${domain}/auth/oauth/pocket-id/callback`, launchURL `https://history.${domain}`. Committed in `2bf7029f`.
10. **SystemNix browser-history.nix rewritten** — Conditional Pocket ID integration via `pocketIdEnabled` flag. When Pocket ID is enabled on the host, browser-history gets:
    - OAuth2 env vars (`OAUTH2_REDIRECT_BASE`, `OAUTH2_POCKET_ID_ISSUER`, `SSL_CERT_FILE`)
    - `browser-history-oidc-setup.service` oneshot that bridges the Pocket ID client secret into `${dataDir}/oauth2-secrets.env`
    - Ordering: `after` pocket-id + provision + oidc-setup, `wants` oidc-setup
    - Graceful degradation: missing secret → WebAuthn-only mode
    Committed in `35ddbbbf`.
11. **Caddy comment updated** — Reflects dual-auth reality (WebAuthn + OAuth2/OIDC). Committed in `35ddbbbf`.
12. **Nix syntax validation** — `nix-instantiate --parse` passes on all 3 modified files.
13. **`nix flake check --no-build`** passed BEFORE the nixpkgs tarball regression hit.

---

## B) PARTIALLY DONE

### Deployment — BLOCKED by nixpkgs tarball regression

14. **SystemNix flake.lock** was updated (`39801923`) to point browser-history at `eff518c`, but a subsequent `nix flake update` rewrote nixpkgs from `type: github` to `type: tarball` — the documented global registry regression (AGENTS.md gotcha: "nixpkgs tarball lock regression"). `nix flake check --no-build` now fails with `nixpkgs flake.lock regression: original type is "tarball", expected "github"`.
15. **No deploy has happened.** The fix is `bash scripts/fix-nixpkgs-lock.sh` (documented recovery script), but this requires running outside this environment (sudo/systemctl blocked).
16. **browser-history flake.lock pins `eff518c`** but 7 newer commits exist on master (up to `3f8830c`), including the vendorHash fix (`6fb09a6`), additional CSRF/OAuth2 tests (`ac8415a`), and middleware refactors. These 7 commits are **not pushed** to origin and **not in SystemNix's flake.lock**.
17. **browser-history commits not pushed** — 7 commits (`6fb09a6` through `3f8830c`) are local-only. `git push origin master` is needed before SystemNix can reference them.

---

## C) NOT STARTED

18. **End-to-end Pocket ID login test** — No browser test of the actual OAuth2 → Pocket ID → callback → session flow.
19. **Gatus health check for OAuth2 callback** — No monitoring of the `/auth/oauth/pocket-id/callback` endpoint.
20. **Homepage tile for browser-history** — Not checked if one exists or needs updating with SSO context.
21. **Backup coordination** — browser-history's SQLite DB not in `backup-coordination`.
22. **DNS local subdomain** — Need to verify `history.home.lan` is in `dnsLocal.localSubdomains` (dnsblockd gotcha: wildcard doesn't resolve).
23. **AGENTS.md update** — SystemNix AGENTS.md SSO table should add browser-history as a Layer 1 native OAuth2 service.
24. **browser-history AGENTS.md** — Should document the `pocketId` option pattern and `SSL_CERT_FILE` requirement.

---

## D) TOTALLY FUCKED UP

25. **nixpkgs tarball regression (AGAIN)** — The global registry regression struck during `nix flake update` to bump browser-history. The flake.lock now has `nixpkgs.original.type = "tarball"`, breaking all evaluation. Recovery: `bash scripts/fix-nixpkgs-lock.sh`. This is the same documented gotcha from the Aug 6 incident. The eval-time guard in flake.nix (`nixpkgsTarballGuard`) correctly caught it, but only AFTER the damage was done. The `nix.settings.flake-registry` fix in `configuration.nix` was supposed to prevent this, but the auto-commit daemon's `nix flake update` may have bypassed it.

26. **7 unpushed browser-history commits** — I pushed `4eb0007` but subsequent commits (`6fb09a6` vendorHash fix, `eff518c` refactor, `ac8415a` tests, etc.) accumulated locally without a second push. SystemNix's flake.lock references `eff518c` which IS pushed, but the vendorHash fix at `6fb09a6` is NOT pushed — meaning a standalone SystemNix build would fail with a vendorHash mismatch unless the browser-history repo is updated.

27. **vendorHash mismatch was expected but not pre-checked** — I should have run `nix build .#browser-history-server` BEFORE committing the Go changes, then updated vendorHash in the same commit. Instead, the build failed on first try, requiring a second commit cycle. This repeats the exact mistake documented in the prior session's "What Could Have Been Done Better" section.

---

## E) WHAT WE SHOULD IMPROVE

### Process

28. **Always build locally before committing** — The vendorHash mismatch was predictable. Run `nix build .#browser-history-server` after any Go code change, then update vendorHash in the same commit. This was called out in the prior session and I repeated it.
29. **Push immediately after commit** — The 7 unpushed commits in browser-history would have caused a silent build failure in SystemNix. Push every commit or at least every logical unit before moving to the next repo.
30. **Pre-flight `nix flake check --no-build` after flake.lock updates** — The tarball regression is only visible via flake check. Any `nix flake update` should be immediately followed by `nix flake check --no-build` to catch this.
31. **The nixpkgs tarball regression needs a permanent fix** — The `configuration.nix` local empty registry + correct-format overrides were supposed to prevent this. They clearly didn't survive the auto-commit daemon's `nix flake update`. Investigate whether the daemon runs with different Nix settings than the interactive shell.

### Architecture

32. **`SSL_CERT_FILE` should be a SystemNix-wide convention** — The oauth2-proxy module already sets it, browser-history now sets it. Every Go service that makes outbound HTTPS calls to internal TLS endpoints needs this. Consider adding it to the `harden` helper or a `serviceDefaults` variant.
33. **Secret bridging pattern should be a library helper** — The `browser-history-oidc-setup.service` follows the exact same pattern as `forgejo-oidc-setup.service`: read Pocket ID secret file → write EnvironmentFile. This is the 3rd service doing this (Forgejo, Gatus via LoadCredential, now browser-history). A `mkPocketIdEnvFile` helper would eliminate the boilerplate.
34. **The oneshot writes to `${dataDir}/oauth2-secrets.env` as root** — The browser-history service runs via DynamicUser in the upstream module, but SystemNix doesn't set DynamicUser. The file is `chmod 600` owned by root. Need to verify the service can actually read it under SystemNix's hardening (no `User=` set means it runs as root, so this works — but it's not ideal from a security perspective).

---

## F) NEXT STEPS (Up to 50)

### Immediate — Blocking Deploy

1. **Push browser-history commits** — `cd /home/lars/projects/browser-history && git push origin master`
2. **Fix nixpkgs tarball regression** — `bash scripts/fix-nixpkgs-lock.sh` in SystemNix
3. **Update SystemNix flake.lock** for browser-history to latest HEAD (`3f8830c`) after push
4. **Run `nix flake check --no-build`** to confirm regression is resolved
5. **Deploy** — `nix run .#deploy` or `nh os switch .`
6. **Verify `browser-history-oidc-setup.service`** completed — `systemctl status browser-history-oidc-setup.service`
7. **Verify browser-history sees Pocket ID** — Check env vars: `systemctl show browser-history --property=Environment`
8. **Verify `/register` page shows "Login with Pocket ID" button** — `curl -sk https://history.home.lan/register | grep -i pocket`
9. **Test actual OAuth2 flow** — Open browser → `https://history.home.lan/register` → click "Pocket ID" → complete passkey at `auth.home.lan` → verify redirect back with session

### Short-term — Hardening & Monitoring

10. **Add Gatus health check** for browser-history OAuth2 endpoint in `gatus-config.nix`
11. **Verify `history.home.lan` is in `dnsLocal.localSubdomains`** — DNS resolution check
12. **Add browser-history to Homepage dashboard** if not already there
13. **Add browser-history SQLite DB to backup-coordination** in `configuration.nix`
14. **Update SystemNix AGENTS.md SSO table** — browser-history is now Layer 1 native OAuth2
15. **Update SystemNix AGENTS.md browser-history section** — Document Pocket ID integration, secret bridging, SSL_CERT_FILE
16. **Add `restartTriggers` on `browser-history-oidc-setup.service`** — So secret changes trigger reprovisioning
17. **Lock registration after first user** — `POST /auth/register` is still open to anyone on LAN (carried over from prior session)
18. **Deploy browser-history agent** — Server has no data source yet
19. **Test WebAuthn alongside OAuth2** — Verify both auth methods coexist without conflicts

### Medium-term — Code Quality

20. **Extract `mkPocketIdEnvFile` helper** — Library function for the Forgejo/Gatus/browser-history secret-bridging pattern
21. **Make `SSL_CERT_FILE` a SystemNix convention** — Add to `serviceDefaults` or a `goServiceDefaults` variant
22. **Fix BuildFlow pre-commit hook** — biome/nixfmt not in PATH outside devshell (carried over)
23. **Add integration test for OAuth2 callback flow** — Currently only unit tests exist (Google path untested due to network)
24. **Investigate `PrivateTmp = lib.mkForce false` for Caddy** — Root-cause fix instead of restart band-aid (carried over)
25. **Make deploy.sh Caddy restart conditional** on config change (carried over)
26. **Consider PKCE for browser-history OIDC client** — Currently `pkceEnabled = false`; PKCE is defense-in-depth even for confidential clients
27. **Add CSRF protection audit for OAuth2 callbacks** — Verify the OAuth2 callback can't be used for CSRF (state parameter validation)
28. **Add rate limiting on OAuth2 begin/callback endpoints** — Prevent login flood attacks

### Long-term — Architecture

29. **Coordinated Single Logout (SLO)** — browser-history OAuth2 sessions don't participate in Pocket ID RP-initiated logout
30. **Token refresh strategy** — Verify what happens when the OAuth2 session token expires (does the user get re-prompted?)
31. **Multi-user support** — What happens when two different Pocket ID users log in? Separate browser-history accounts?
32. **Pocket ID user provisioning** — Does browser-history auto-create users on first OAuth2 login, or do they need pre-registration?
33. **Consider adding browser-history OIDC client logo** — Pocket ID supports `logoFile`; would improve the SSO launcher UI
34. **Monitor OIDC discovery health** — browser-history does OIDC discovery at startup; if `auth.home.lan` is down, the server may fail to start

### Documentation

35. **Document `publicDeps` pattern** in browser-history AGENTS.md (carried over from prior session)
36. **Update browser-history README** with Pocket ID setup instructions
37. **Update browser-history FEATURES.md** — OAuth2/OIDC SSO is now a feature
38. **Update browser-history CHANGELOG.md** — The `[Unreleased]` section has uncommitted changes
39. **Add architecture diagram** for the dual-auth (WebAuthn + OAuth2) flow
40. **Document the `SSL_CERT_FILE` requirement** for any Go service doing internal TLS calls on NixOS
41. **Add OIDC troubleshooting guide** — What to check when "Login with Pocket ID" fails

### Testing & Verification

42. **Test OIDC discovery failure mode** — What happens when browser-history starts before Pocket ID is ready?
43. **Test secret rotation** — What happens when Pocket ID rotates the client secret?
44. **Test graceful degradation** — Verify WebAuthn-only mode actually works when Pocket ID is disabled
45. **Add NixOS VM test** for browser-history + Pocket ID integration
46. **Test concurrent OAuth2 logins** — Race conditions in user creation?
47. **Verify `SSL_CERT_FILE` is actually needed** — Does Go on NixOS really not find `/etc/ssl/certs/ca-certificates.crt` without it?

### Security

48. **Audit OAuth2 scopes** — What scopes does Pocket ID send? Is browser-history requesting minimal scopes?
49. **Verify session token security** — Are OAuth2-created sessions subject to the same 24h TTL + reaper as WebAuthn sessions?
50. **Pen-test the OAuth2 callback** — Can an attacker replay a callback URL? Is the state parameter validated?

---

## G) QUESTIONS (Things I Cannot Figure Out Myself)

### Q1: Does browser-history auto-create users on first OAuth2 login?

The `usermgmt.NewService` with `OAuth2` provider handles the OAuth2 flow, but I don't know if it auto-provisions a new user record when a Pocket ID user logs in for the first time, or if it requires the user to pre-exist (like Monitor365's "No JIT SSO provisioning" gotcha). This determines whether the OAuth2 login "just works" or needs a pre-provisioning step. The answer is in the `cqrs-htmx/usermgmt/oauth2/v4` library code which I haven't read.

### Q2: Should the browser-history OIDC client use PKCE?

The Forgejo and Gatus clients don't use PKCE (they're confidential clients with server-side secrets). browser-history is also a confidential client. But the oauth2prov library's Google path already uses PKCE internally. Should the Pocket ID client declaration in `pocket-id.nix` set `pkceEnabled = true` for defense-in-depth? I don't know if the oauth2prov library sends PKCE only when the server requires it, or always.

### Q3: The nixpkgs tarball regression keeps recurring despite the documented fix — is the auto-commit daemon bypassing the local empty registry?

The AGENTS.md documents a fix (`nix.settings.flake-registry` → local empty JSON + correct-format system registry overrides). It was "verified" as working on Aug 6. But it broke again today during this session. The most likely explanation is that the auto-commit daemon runs `nix flake update` with different Nix settings than the interactive shell (perhaps it doesn't use the same `nix.conf`). I can't verify this without checking the daemon's runtime environment, which requires sudo to inspect the systemd unit.
