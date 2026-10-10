# crm.home.lan → PocketID: native OIDC wiring — status & self-review

**Date:** 2026-10-10 01:33 CEST · **Session:** "Make crm.home.lan fucking work with PocketID!" (research + start of implementation)
**Mandate:** make `https://crm.home.lan` authenticate via Pocket ID (SSO), not only the CRM's own WebAuthn passkey.
**Predecessor context:** the T42 cutover (`docs/services/crm.md`, `docs/status/2026-10-08_14-25_crm-cutover-live-full-backups-parallel-removal-reconciled.md`) made the Kith CRM live on `crm.home.lan` behind passkeys; the CRM's own ROADMAP lists "Pocket ID OAuth2 … `usermgmt/oauth2` exists when wanted" as deferred.

**Outcome in one line:** the architectural decision is made and ratified (native OIDC, your call), the contracts are fully mapped, and the first 3 edits to the CRM's `identity` adapter are on disk — **but the change is INCOMPLETE and the CRM local tree does not compile right now.**

---

## §a — FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Live state established**: `https://crm.home.lan` serves the Kith CRM **passkey** login page (Level 0 "plain" vHost, `-auth` on, `-rpid crm.home.lan`). | live `fetch https://crm.home.lan` → passkey login HTML; `docs/services/crm.md:11-20` |
| a2 | **Gap confirmed**: the CRM app wires **only** `usermgmt/webauthn`; `ServiceConfig.OAuth2` is never set. No native OIDC. | `cmd/crm-server/main.go:375-414`, `internal/identity/identity.go` (pre-edit), `FEATURES.md:65` "PLANNED Pocket ID OAuth2 … deferred" |
| a3 | **The library contract is fully mapped** (what "works with PocketID" actually requires): `oauth2.New(ctx, Config{Providers})` → `setup.Config.ServiceConfig.OAuth2`; callback routes `GET /auth/oauth/{provider}/begin` + `/callback`; login page **auto-populates** the SSO button from `Service.ConfiguredOAuth2Providers()`; `OAuth2SuccessURL` must be set or the callback returns JSON instead of redirecting. | `cqrs-htmx/usermgmt/oauth2/provider.go:135-198`, `usermgmt/oauth2_http.go:9-71`, `setup/config.go:44-99`, `loginpage/config.go:42-59`, `cqrs-htmx/usermgmt/http.go:90-97` |
| a4 | **Provenance of the callback path**: crm mounts the bundle at root, so the callback is `https://crm.home.lan/auth/oauth/<provider>/callback`. | `cmd/crm-server/main.go:404-409`, `usermgmt/oauth2_http.go:16-17` |
| a5 | **Layer-2 ruled out, correctly**: `protectedVHost` **bypasses forward-auth for LAN clients** (`@external not remote_ip 127.0.0.1/8 <lanSubnet>`), and `crm.home.lan` is a LAN hostname — so oauth2-proxy forward-auth cannot make the LAN user see PocketID. Native OIDC is the only path that authenticates `crm.home.lan` with PocketID on the LAN. | `modules/nixos/services/caddy.nix:193-206` |
| a6 | **SystemNix reference pattern identified**: `cv.nix` (Layer-1 native OIDC: registry `oidc` entry + `cv-oidc-env` secret-bridge oneshot) and `dns-blocker.nix` (registry `oidc` entry, `pkceEnabled = true`). | `modules/nixos/services/cv.nix:352-413,1073-1089`, `dns-blocker.nix:1383-1389`, `lib/types.nix:10-40` |
| a7 | **FOD/build mechanics mapped**: crm's `flake.nix` pins `cqrs-htmx` (`98b6fead`) as a `flake = false` input; `mkPreparedSource` strips the dev-only `../cqrs-htmx/...` replaces and **auto-discovers submodule go.mods at any depth**, so `usermgmt/oauth2` will be replaced automatically; adding a dependency **changes `vendorHash`** (the SystemNix shim in `crm.nix:62-64` must be re-pinned). | `crm/flake.nix:29-32,102-110`, `go-nix-helpers/mkPreparedSource.nix:11-27,152-166` |
| a8 | **Local Go toolchain verified**: `go1.27.1` is the machine default (no `GOTOOLCHAIN` override needed locally). | `go version` → `go1.27.1` |
| a9 | **Decision ratified**: you chose **native OIDC** over the proxy gate. | `question` tool response (Q1 = native) |
| a10 | **First 3 code edits landed**: added the `oauth2provider` import; added `Options.OAuth2 *OAuth2Options` + the `OAuth2Options` type; changed `New(ctx)` to use `ctx` and default `Provider` to `"pocket-id"`. | `internal/identity/identity.go:18,60-102`; committed by the daemon as `27f6aa0` |

## §b — PARTIALLY DONE

| # | Item | State | What's missing |
|---|------|-------|----------------|
| b1 | `internal/identity/identity.go` OIDC wiring | import + options type + `New(ctx)` done | the actual `oauth2provider.New(...)` construction, attaching it to `ServiceConfig.OAuth2`, and setting `handlerCfg.OAuth2SuccessURL = "/"` / `OAuth2ErrorURL = "/login"` are **NOT written** |
| b2 | Build integrity | — | package does **not** compile: `go build ./internal/identity/` → *"updates to go.mod needed"* (the new import has no `require`) |
| b3 | Commit hygiene | daemon swept the edits | `27f6aa0` is a heuristic commit of an **incomplete, non-compiling** change; 1 commit ahead of `origin/master` (`bf2cfcd`), **unpushed** |

## §c — NOT STARTED

| # | Item |
|---|------|
| c1 | `crm/go.mod`: add `require github.com/larsartmann/cqrs-htmx/usermgmt/oauth2/v4 v4.12.0` (a `replace` already exists) + `go mod tidy` (pulls `coreos/go-oidc/v3`, `go-jose/v4`). |
| c2 | `cmd/crm-server/main.go`: `-oidc-issuer`, `-oidc-client-id`, `-oidc-redirect-url` flags; read client secret from env (`CRM_OIDC_CLIENT_SECRET`, **never argv**); build `identity.OAuth2Options`; graceful degrade to passkey-only if OIDC construction fails. |
| c3 | crm tests: identity OIDC unit tests; login-page SSO-button render test; callback happy/error path. |
| c4 | SystemNix `modules/nixos/services/crm.nix`: `oidc` registry entry (`clientId`, `callbackURLs = ["https://crm.home.lan/auth/oauth/pocket-id/callback"]`, `pkceEnabled = true`, `launchURL`). |
| c5 | SystemNix: `crm-oidc-env` bridge oneshot (cv pattern) → secret env file; `crm-server` `EnvironmentFile` + `after/wants` wiring + `mkOidcGate`. |
| c6 | SystemNix: pass OIDC flags in `ExecStart` (issuer/client-id/redirect-url). |
| c7 | Re-pin the `vendorHash` shim in `crm.nix:62-64` (compute via `--override-input crm git+file://…`). |
| c8 | Docs: `docs/services/crm.md` (Auth row, SSO section), `docs/agents/sso-dns.md` layer table. |
| c9 | Push crm → `nix flake lock --update-input crm` → `nix run .#deploy` → post-deploy verify (SSO login e2e). |
| c10 | TODO system: harvest this report's §f follow-ups into `TODO_LIST.md` + `docs/todo/services.md`/`upstream.md`. |

## §d — TOTALLY FUCKED UP

| # | Issue | Severity | Note |
|---|-------|----------|------|
| d1 | **The working tree is committed in a non-compiling state.** The auto-commit daemon swept the 3 half-applied edits into `27f6aa0`, so crm `master` (local, 1 ahead of origin) currently fails `go build ./internal/identity/`. Nothing is pushed, so no external impact — but the repo is red. | **High (local)** | Fix is mechanical: finish §b1 + §c1, then `go build ./...`. |
| d2 | I stopped **mid-edit** on the implementation instead of reaching a compiling checkpoint before yielding. A senior engineer would land the whole `identity.go` change (import + use) in one edit so no intermediate state leaves unused imports / missing requires. | Medium | Lesson candidate: never land an import without its use in the same atomic edit. |
| d3 | `go build ./internal/identity/` reported `exit=0` in the shell wrapper while also printing "updates to go.mod needed" — the pipeline `| head` masked the real exit code. I should have read the message, not the status. | Low | `set -o pipefail` habit. |

## §e — WHAT WE SHOULD IMPROVE

1. **Atomic edits** (d2): an import and its first use belong in ONE edit; a partial module change is never committed.
2. **Verify compile after EACH edit**, not at the end (the "test after each change" rule).
3. **Decide degrade-vs-fail explicitly**: if Pocket ID discovery (`auth.home.lan`) is unreachable at boot, `crm-server` must **not** go down — mirror cv's "secret missing ⇒ OIDC off" philosophy: log loudly, continue passkey-only. (I lean: degrade. Confirm in §g? — no, I can decide: **degrade**.)
4. **Provider button label**: the auto-label for `pocket-id` is "Sign in with Pocket-id" (cosmetic). Either accept it or add `pocket-id` to `knownProviderLabels` upstream in cqrs-htmx (small, separate change).
5. **Callback/cloud domain**: `crm.larsartmann.cloud` also proxies here, but `-rpid`/origin are `crm.home.lan` only. Decide whether to register a second Pocket ID callback for the cloud host or keep home.lan-only (docs currently say cloud is view-only).
6. **Secret plumbing**: the Pocket ID client secret is **provisioner-owned** (not sops) — follow the `cv-oidc-env` bridge, do NOT sops-encrypt it.
7. **FOD discipline**: adding a dependency invalidates the vendorHash shim; budget the `--keep-going` re-pin cycle and never paste a stale hash.
8. **Push reality**: crm has a large `blocked:push` backlog; adding OIDC stacks another commit that cannot go live until pushed. Flag co-travel explicitly.
9. **Session hazard noticed**: bash `rg`/`sed` tool output appeared **word-substituted** this session (`crm`→`n`, `SSO`→`ln`, `accessors`→`accelnrs`) while the `view` tool and external `fetch` showed the true bytes. Do not trust bash-rg text for exact identifiers; cross-check with `view`/`grep` tools.

## §f — NEXT 50 (ordered, highest-leverage first)

1. Finish `identity.go`: construct the provider, set `ServiceConfig.OAuth2`, set `OAuth2SuccessURL = "/"`, `OAuth2ErrorURL = "/login"`. 2. Export a provider-name const `"pocket-id"`. 3. Add the `require` line to `go.mod`. 4. `go mod tidy` (adds go-oidc/go-jose + go.sum). 5. `go build ./...` until green. 6. `go vet ./internal/identity/`. 7. unit test: provider configured ⇒ `Service.HasOAuth2` true. 8. unit test: login page contains `/auth/oauth/pocket-id/begin`. 9. unit test: OIDC construction failure returns a wrapped error. 10. main.go: add the 3 flags. 11. main.go: read secret from `CRM_OIDC_CLIENT_SECRET`. 12. main.go: build OAuth2Options only when all four values present. 13. main.go: degrade-to-passkey on OIDC error (log + retry). 14. main.go: log "oidc enabled (issuer=…, provider=…)" without the secret. 15. `-secure`/origin consistency check for the callback. 16. Run crm's full test suite (`go test ./...`). 17. Build the crm package via Nix (local flake) to smoke the vendor change. 18. SystemNix `crm.nix`: add the `oidc` registry entry. 19. Add `crm-oidc-env` oneshot (StateDirectory `crm-oidc`, `LoadCredential`). 20. Gate `crm-oidc-env` on `pocket-id-config.provision.enable`. 21. `crm-server` `after/wants` `pocket-id-provision` + `crm-oidc-env`. 22. Add `EnvironmentFile` for the bridge's env file (conditional on provision). 23. Add `mkOidcGate` to `crm-server`. 24. Extend `ExecStart` with `-oidc-issuer/-oidc-client-id/-oidc-redirect-url`. 25. Keep the secret out of argv (env only). 26. `nix eval` the rendered unit and inspect ExecStart. 27. `nix flake check --no-build`. 28. Compute the new shim `vendorHash` via `--override-input crm git+file:///home/lars/projects/crm`. 29. Paste the shim hash + update the shim comment. 30. Docs: `docs/services/crm.md` Auth row → "Passkey + Pocket ID OIDC (Layer 1)". 31. Docs: add crm to the `sso-dns.md` Layer-1 table. 32. Docs: note the callback URL + provider name. 33. Docs: PASKEY-RECOVERY cross-reference for the OIDC path. 34. Update crm `FEATURES.md` (PLANNED → DONE) and `ROADMAP.md`. 35. Update crm `AGENTS.md` standing decision (WebAuthn-only → WebAuthn + OIDC). 36. `resources/`/CHANGELOG entries in both repos. 37. Harvest §f into `TODO_LIST.md`. 38. Harvest into `docs/todo/services.md`. 39. Harvest upstream items into `docs/todo/upstream.md`. 40. Push crm (owner). 41. `nix flake lock --update-input crm`. 42. Re-pin shim hash if the real build differs. 43. `nix run .#pre-deploy-check`. 44. `nix run .#deploy`. 45. Post-deploy: `curl -I https://crm.home.lan/login` shows the SSO button. 46. Post-deploy: full SSO login e2e (Pocket ID passkey → redirect to `/`). 47. Verify CV syncer `/rest` still works (api-token path unchanged). 48. Verify Gatus "Kith CRM" check still green. 49. Verify identity.db backup still 0600 + new user row present. 50. Reconcile the TODO queue + run `scripts/check-todo-system.sh`.

## §g — QUESTIONS I CANNOT ANSWER MYSELF

1. **Push authorization & scope** — crm `master` now carries `27f6aa0` (my half-edit) on top of a large unpushed backlog (rebrand/Kith, multi-RPID draft, CSS fixes, …). Do you want the OIDC work to ride the next crm push (and should I finish it to a push-ready state), or is crm push currently frozen for a reason I shouldn't disturb?
2. **Auth posture** — keep **passkeys AND Pocket ID** on the login page (my default: both, passkey stays the break-glass path), or make Pocket ID the **only** login and drop passkeys? Also: registry `clientId` — `crm`, `kith`, or `kith-crm`?
3. **Cloud host** — register a second Pocket ID callback + redirect for `crm.larsartmann.cloud`, or keep Pocket ID scoped to `crm.home.lan` (matching the current home.lan-only WebAuthn posture)?

## Evidence index

- Live: `fetch https://crm.home.lan` → Kith passkey login page (SSO text present, no button yet).
- crm local: `git log --oneline -6` → HEAD `27f6aa0` (daemon heuristic), origin `bf2cfcd`; changes only in `internal/identity/identity.go`.
- Build: `go build ./internal/identity/` → "updates to go.mod needed".
- Contracts: `cqrs-htmx/usermgmt/oauth2/provider.go`, `usermgmt/oauth2_http.go`, `setup/config.go`, `loginpage/config.go`, `identity-model/interfaces.go:51-66`.
- SystemNix refs: `caddy.nix:193-206`, `cv.nix:352-413,1073-1089`, `dns-blocker.nix:1383-1389`, `lib/types.nix:10-40`.
- Build mechanics: `go-nix-helpers/mkPreparedSource.nix:11-27,152-166`; `crm/flake.nix:29-32,81,102-110`.

## Harvest note

Per the TODO-system rule, a status report must self-harvest its §f follow-ups at authoring time. **Deliberately NOT harvested yet** — the owner instructed "write the report, THEN WAIT FOR INSTRUCTIONS", so the queue edits are deferred to the next action on their word. This note is the explicit "deliberately not harvested because X" record the rule requires.

---

## COMPLETION ADDENDUM (2026-10-10 ~02:15, resuming session — §f.1–§f.35 + §f.50 executed)

The owner's follow-up instruction ("keep going until everything works") executed §f items 1–35 + 50. State:

**crm repo** (HEAD `9df0c4a`, 4 commits ahead of origin `bf2cfcd`, tree clean — daemon-carried):
- `internal/identity/identity.go`: provider constructed (eager OIDC discovery), `ServiceConfig.OAuth2` wired via a nil-INTERFACE variable (typed-nil-pointer guard), handlerCfg `OAuth2SuccessURL="/"` + `OAuth2ErrorURL="/login"` + `OAuthRateLimit` 10/min.
- `cmd/crm-server/main.go`: `-oidc-issuer/-oidc-client-id/-oidc-redirect-url` flags, `CRM_OIDC_CLIENT_SECRET` env read (never argv), `serverConfig.oidcOptions()` (all-empty = passkey-only nil; PARTIAL config = loud error; full = options), degrade-on-unreachable-issuer (log + passkey-only retry), posture logging.
- `go.mod`: `usermgmt/oauth2/v4 v4.12.0` require + `schema/v4` dev-replace (the local `system` module needs the untagged local schema; cache-version lacked `EventSchema`) + tidy-bumped siblings (identity-model/metaengine/stack/system/templ-components v1.21.0) riding the local-replace module graphs.
- `flake.nix` pins bumped to PUSHED tips: cqrs-htmx `0dfa7e50`, go-cqrs-lite `498f5c0c`; `flake.lock` re-locked (fetches from GitHub — revs proven pushed).
- Tests: 4 new identity tests (`oauth2_test.go`: login-page button, begin-redirect PKCE/state contract against a fake discovery IdP, discovery-failure construction error, passkey-only page omits OAuth routes) + `TestOidcOptionsValidation` (3 subtests). `go build ./...` + `go test ./...` exit 0 (after regen-ui for the templ-components v1.21.0 class-list drift my tidy caused — TestLibraryClassesFresh).
- Docs: FEATURES PLANNED→FULLY_FUNCTIONAL, ROADMAP done-note, AGENTS.md OIDC posture row (Pocket ID BESIDE passkeys, passkeys = break-glass).

**SystemNix** (committed via daemon in `7c8b8e85` docs + `141c23cb` shim, on top of the parallel flake-split session):
- `crm.nix`: registry `oidc` entry (clientId `crm`, callback `https://crm.${domain}/auth/oauth/pocket-id/callback`, pkceEnabled, launchURL), `crm-oidc-env` bridge (cv-oidc-env pattern: LoadCredential `client-secrets/crm` → `/var/lib/crm-oidc/client-secret.env` 0600, exit-0-without-write when secret absent), ExecStart `-oidc-*` flags (mkIf pocketIdProvisioned), EnvironmentFile mkForce-extend, header + registry comments, vendorHash shim re-pin `t1CRZVb6…` at crm `9df0c4a` (first-hand FOD build via git+file:// — the same overrideAttrs construction rebuilt the FULL package green).
- `deploy.sh`: is-active-gated `crm-oidc-env` + `crm-server` restart block (deploy-restart-audit converger gate; daemon-gated like geometrikks — bridge is wantedBy-indirect). shellcheck -S warning clean.
- Docs: `docs/services/crm.md` Auth row + new "Native OIDC (Pocket ID, 2026-10-10)" section (email-linking requirement: Pocket ID email must equal the passkey registration email — source-verified `matchOrCreateUser`: subject → email-link fallback → create-under-MaxUsers; linking works regardless of Pocket ID's default-false `email_verified`); `docs/agents/sso-dns.md` Layer-1 row + Kith CRM.
- TODO: queue row `[blocked:push]` (TODO_LIST.md) + library row (docs/todo/services.md) — coordinated pair, no drift.

**Verification evidence**: minimal-host eval (excludes the parallel session's then-broken nsfw-classifier edit) rendered the exact ExecStart (`…-secure true -oidc-issuer https://auth.home.lan -oidc-client-id crm -oidc-redirect-url https://crm.home.lan/auth/oauth/pocket-id/callback`), bridge (oneshot/LoadCredential/wantedBy), EnvironmentFile pair, Pocket ID provisioning fan-out (client `crm`, pkceEnabled); negative eval (provision off ⇒ no oidc flags, no bridge unit, single env file); then the parallel session landed its fix (`606dc6e1`) and the FULL evo-x2 toplevel eval passed (`cjgcvl5…` drv) + `nix flake check --no-build` "all checks passed" (aarch64-darwin omission expected per AGENTS.md).

**Deliberately not done here**: push (owner-gated, §g-Q1 stands), `flake lock --update-input crm`, deploy, live SSO e2e — all queued as the `[blocked:push]` row. §f.2 (provider-name const), §f.33 (PASSKEY-RECOVERY cross-ref), §f.36 (CHANGELOG entries), §f.37–39 harvest remainder beyond the queue pair — small follow-ups noted in the library row's Source chain. §g answers baked in as defaults (both logins; clientId `crm`; home.lan-only callback) — owner can override by editing the registry entry.
