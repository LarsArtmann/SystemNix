# Paperless SSO-ONLY (password login eliminated) — round 2 — STATUS & SELF-REVIEW

**Session:** 2026-09-02, ~17:50–18:51 CEST (continues `2026-09-02_17-49_paperless-pocketid-oidc-layer1-self-review.md`, which this report supersedes where they overlap).
**Trigger:** user confirmed "PocketID login worked" (end-to-end passkey login = token exchange + auto-signup proven live) and directed: **"I do not like password logins"**.
**Repo state at close:** nothing committed by this session; tree still carries a concurrent session's work (mail-relay now also wires paperless outbound email — their bullet landed in the paperless AGENTS.md section mid-round).

---

## a) FULLY DONE (verified live)

1. **Paperless is SSO-ONLY — password login eliminated, live-verified through the real vHost:**
   - `paperless.nix` bridge (`paperless-oidc-setup`) now writes `PAPERLESS_DISABLE_REGULAR_LOGIN=true` + `PAPERLESS_REDIRECT_LOGIN_TO_SSO=true` into the SAME env file as the client secret.
   - **Auto-break-glass design:** the flags ride in the runtime env file only — bridge degraded (secret missing → condition-skip → file absent → optional `-` prefix) → the password form returns AUTOMATICALLY. SSO fully on or fully off; never a locked-out middle state. Proven in the VM (step 8) and documented as a no-redeploy root runbook in AGENTS.md (`rm …/client-secrets/paperless && systemctl restart paperless-oidc-setup paperless-web`).
   - Live checks: login page = Pocket ID provider form + JS auto-submit script (`getElementById`), **no `type="password"` input**; `/admin/*` → **403**.
2. **Django admin hole closed** — paperless docs confirm `DISABLE_REGULAR_LOGIN` does NOT cover the Django admin; Caddy now hard-blocks `handle /admin/*` in the paperless vHost (live 403). REST API password auth deliberately KEPT (mobile-app compatibility; flagged for decision).
3. **Monitoring rewritten to the true semantics** (see also d) for the catch):
   - Gatus "Paperless": `200` + `pat(*oidc/pocket-id*)` + `pat(*getElementById*)` + `!= pat(*type="password"*)` when Pocket ID is enabled (a password field reappearing = bridge degraded = break-glass serving — visible, non-silent); plain 200+body check otherwise.
   - `post-deploy-check.sh`: SSO-only branch set with an explicit outcome for every state (SSO pass / password-form-serving fail / provider-flow-missing fail / unreachable fail) — **this also fixes the silent-skip defect from round 1** (my earlier `is-active`-gated check could print nothing; the new block has no skip path).
4. **VM test extended + green** (`tests/test-paperless.nix`, all 8 steps): env file carries both flags; step 7 asserts the SSO-only page shape; step 8 now proves the password form (incl. `type="password"` input) returns after bridge degradation.
5. **Deployed clean** — no pressure-gate force needed this round (MemAvailable 20G); `nix flake check --no-build` green; formatter converged; smoke: `PASS Paperless — SSO-only login (Pocket ID auto-submit, no password form)`.
6. **AGENTS.md updated** — SSO-only decision, JS-redirect semantics, `/admin/` block, break-glass runbook, API caveat.

## b) PARTIALLY DONE

- **Gatus runtime state of the new conditions unverified** — pattern-lint passed at eval time and gatus restarted with the new config, but I did not confirm the live endpoint evaluates green (its API is OIDC-gated; the sqlite/DynamicUser path needs root). If a pattern misbehaves, the next red alert will say so.
- **pocket-id SQLITE_BUSY noise (active 18:18–18:31)** — recurring `database is locked` on LdapSync/ScimSync actor teardown + a 2.4s slow statement under the box's sustained I/O pressure. Pocket-id is SERVING (login flows work), but with paperless now depending on it as the ONLY login, this journal is the standing risk. Noticed, flagged, not diagnosed (documented collateral-under-pressure class; deploy-time smoke watches it, nothing continuous does).
- **Logout UX with SSO-only unverified** — with `REDIRECT_LOGIN_TO_SSO` + an alive Pocket ID session, paperless logout may bounce straight back in (Layer-1 apps don't do coordinated logout). Not tested (needs a browser).

## c) NOT STARTED (carried, other owners/domains)

- FastFlowLM `:52625` still down (memory-guard sacrifice under the ongoing pressure storm — by design, auto-restores; unconfirmed whether it restored).
- dnsblockd `:9090` stats-API timeout (round-1 thread; DNS :53 healthy; goroutine-dump runbook needs sudo).
- Deploy round-7 silent death root cause (round-1 thread).
- CV `/export/pdf` typst failure + PMA KNOWN_NEW_METRICS retirement (concurrent session).
- forgejo mirror journal-scan 30s-timeout performance (its fail-closed absence is now correctly classified, but the scan is still slow).

## d) TOTALLY FUCKED UP (honest ledger, this round)

1. **Built checks on ASSUMED semantics — again, one hour after writing that lesson down.** I implemented the SSO-only monitoring around a server-side 302 redirect. `PAPERLESS_REDIRECT_LOGIN_TO_SSO` is a **CLIENT-SIDE JavaScript auto-submit** (paperless's login template submits the first provider form via JS — stated verbatim in configuration.md, and the settings section was already in my fetched docs context). The VM test caught it (`AssertionError: …got: 200`), cost one VM round (~7 min) plus rewrites of gatus + smoke + test. Round-1 improvement item #1 ("verify tool semantics against primary docs before writing config") now has a same-session scar attached.
2. **Deployed the gatus condition change without a runtime green check** (see b) — lint ≠ live evaluation.
3. Minor: the first smoke rewrite churned against concurrent-session file modifications twice (whitespace/reformat races) — I re-read and re-applied each time, but I'm editing a live-shared tree faster than it stabilizes.

## e) WHAT WE SHOULD IMPROVE

1. **Read the full docs section of a setting the moment checks are designed around it** — not just the setting's name. The 302 fiction was avoidable in 60 seconds.
2. **Runtime-verify monitoring changes**: a changed gatus condition deserves a green confirmation (e.g. read gatus's sqlite like system-health does, or a one-shot post-deploy gatus-state probe) before declaring victory.
3. **pocket-id is now a SPOF for paperless access** — it deserves continuous degraded-but-alive detection (SQLITE_BUSY streak counter in the system-health textfile + alert), not just deploy-time smoke.
4. **Bare `/admin` (no trailing slash)** currently leaks only a 301-to-blocked-target (Django redirects to `/admin/` → 403) — effectively closed, but an exact `handle /admin` line would remove the redirect hop.
5. **Concurrent-session churn**: mid-round file modifications hit 3 of my edits; the tree needs a quiescent verification pass (evo-x2 eval + fmt) after their session lands.

## f) NEXT — tasks (new first, then carried)

**SSO-only closeout**
1. User: open paperless.home.lan in a fresh browser tab — confirm seamless auto-login straight to the dashboard.
2. User/agent: test LOGOUT behavior; decide if logout-then-instant-relogin is acceptable, or paperless session lifetime should shorten.
3. Verify gatus evaluates the new Paperless conditions green (gatus sqlite or one alert cycle).
4. Decide REST API password auth: keep (mobile app) or gate behind the OIDC path too.
5. If the mobile app matters: investigate paperless token/OIDC-headless auth for it before gating the API.
6. Add exact `handle /admin` (no-slash) to the Caddy block.
7. Rotate the sops `paperless_admin_password` (it was printed to a terminal earlier; now break-glass-only — cheap to rotate, cheap to keep).
**Reliability of the new SPOF**
8. Continuous pocket-id SQLITE_BUSY/streak monitoring (system-health textfile + gatus alert) — paperless has no second login.
9. Investigate the pocket-id slow statements (2.4s) — WAL/busy_timeout or the documented discordsync-collateral class under pressure.
10. Root-cause the box's sustained zram ~97% / MemAvailable ~8% window (census metrics) — it degraded flm, pocket-id, and deploy gates all session.
11. Confirm FastFlowLM socket auto-restored once pressure drained.
12. dnsblockd :9090 goroutine-dump runbook (needs sudo).
13. Root-cause deploy round-7's silent death (deploy.sh trap/logging).
14. Add gatus check: `node_textfile_scrape_error == 0` (round-1 item, still open).
15. Audit post-deploy-check's I/O-pressure "healthy" logic (printed healthy at avg10 48–77%).
**Carried (concurrent session / other)**
16. mail-relay go-live (placeholder secret) + paperless email wiring verification — their session.
17. CV typst `/export/pdf` failure — their session.
18. PMA KNOWN_NEW_METRICS retirement; bank-sync vendorHash override drop check; flake.lock intent check before any push.
19. forgejo journal-scan performance (narrower grep or cursor-based counting).
20. docs/services/paperless.md runbook (OIDC + SSO-only + break-glass + API caveats).
21. VM test: assert the pocket-id client registration shape (callback, pkce) at eval time.
22. Generalized emission-guard lint for textfile collectors (round-1 item).
23. Pre-deploy §10 branch unit tests with fixture scrape bodies (round-1 item).
24. Consider the same SSO-only treatment questions for other Layer-1 apps (gatus/forgejo/immich/browser-history still have local logins — user preference unknown).

## g) Questions I cannot answer myself

1. **Does the seamless flow + LOGOUT behave acceptably in your browser?** Fresh tab → straight into the dashboard? And when you log out of paperless, does it bounce you straight back in while the Pocket ID session is alive — is that OK, or do you want logout to actually end access (shorter paperless session / Pocket ID logout)?
2. **Do you use the paperless mobile app or any API client?** The REST API still accepts username/password (kept deliberately); if nothing needs it, I'll close that path too.
3. **Is the box's memory pressure (zram ~97% for hours, FastFlowLM sacrificed, pocket-id SQLITE_BUSY) something running intentionally** (e.g. the other session's builds), or should the next session hunt the 86G holder?
