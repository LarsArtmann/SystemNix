# Status: Kith CRM × Pocket ID native OIDC — implementation completion session

**When:** 2026-10-10 02:31 CEST · **Scope:** the resuming session 01:33→02:31 (continuation of `2026-10-10_01-33_crm-pocketid-native-oidc-wiring-session.md`) + self-critique of that work. Nothing else researched.

**One-line:** native Pocket ID OIDC is implemented, wired, eval-proven and test-green in BOTH repos — everything except the owner-gated push→deploy→live-e2e chain. One real design gap found by self-review (boot-race ⇒ silent passkey-only after reboots), detailed in §d3/§e.

---

## a) FULLY DONE

1. **`internal/identity/identity.go` — provider construction.** `oauth2provider.New(ctx, …)` with eager OIDC discovery; `ServiceConfig.OAuth2` wired through a nil-INTERFACE variable (avoids the typed-nil-pointer trap where `svc.OAuth2 != nil` lies); `handlerCfg` gained `OAuth2SuccessURL: "/"` (else the callback strands the browser on a JSON body), `OAuth2ErrorURL: "/login"`, and `OAuthRateLimit` 10/min/IP beside the existing register/webauthn caps. Error path joins with proper `closeFailure` cleanup of readDB + sqlite stack.
2. **`cmd/crm-server/main.go` — operator surface.** Flags `-oidc-issuer/-oidc-client-id/-oidc-redirect-url`; secret read from `CRM_OIDC_CLIENT_SECRET` env only (never argv — ps/history leak class, mirrors the row-291 doctrine); `serverConfig.oidcOptions()`: all-empty ⇒ nil (passkey-only), PARTIAL ⇒ loud error naming the missing inputs (a typo must not masquerade as "Pocket ID down"), full ⇒ options; degrade-on-unreachable-issuer (log Error + passkey-only retry); posture logging without the secret.
3. **`go.mod`.** `require github.com/larsartmann/cqrs-htmx/usermgmt/oauth2/v4 v4.12.0`; **added the missing `schema/v4` dev-replace** — root cause of the `go build ./...` break (`undefined: schema.EventSchema`): the local replaced `system` module needs the untagged local schema, while crm resolved schema from the module cache at an older tag; tidy aligned siblings (identity-model, metaengine, stack, system, templ-components v1.20.1→v1.21.0) with the local replace graphs.
4. **crm full suite green** (`go build ./...`, `go vet`, `go test ./...` exit 0), including fixing `TestLibraryClassesFresh` by running the sanctioned `scripts/regen-ui.sh` in the devshell (my tidy lifted templ-components to v1.21.0, staling the class-list artifacts).
5. **Five new tests.** `internal/identity/oauth2_test.go`: login page renders the provider button; `/auth/oauth/pocket-id/begin` redirects to the IdP with `client_id` + `code_challenge` + `state` (PKCE contract, fake discovery IdP); unreachable-issuer construction fails with a wrapped error; passkey-only page renders NO OAuth route. `cmd/crm-server`: `TestOidcOptionsValidation` (nil / partial-fails-loudly / full).
6. **crm flake pins bumped to PUSHED tips** — cqrs-htmx `98b6fead→0dfa7e50`, go-cqrs-lite `8e1d011d→498f5c0c`; `nix flake lock` re-locked via GitHub fetches (revs proven pushed).
7. **SystemNix `crm.nix` wiring.** Registry `oidc` entry (clientId `crm`, launchURL, callback `https://crm.${domain}/auth/oauth/pocket-id/callback`, pkceEnabled) → auto-fans into `pocket-id-config.provision.extraOidcClients`; `crm-oidc-env` bridge (exact cv-oidc-env pattern: `LoadCredential client-secrets/crm` → `/var/lib/crm-oidc/client-secret.env` 0600, exits 0 WITHOUT writing when the secret is absent); ExecStart `-oidc-*` flags gated on `pocketIdProvisioned`; `EnvironmentFile` mkForce-extend (missing file = warning, not start failure).
8. **`scripts/deploy.sh` restart block** — is-active-gated `crm-oidc-env` + `crm-server` restart (satisfies the deploy-restart-audit converger gate `.*-oidc-env$`; daemon-gated like geometrikks because the bridge is wantedBy-indirect). `shellcheck -S warning` clean; `bash -n` clean.
9. **vendorHash shim re-pinned with PROOF, not hope** — first-hand FOD build (`git+file:///home/lars/projects/crm#default`) got `t1CRZVb6uS3V6PYQvev/WR0i/yvJKgl+MAy89Srx0Is=` at tip `9df0c4a`; then rebuilt the FULL package through the identical `overrideAttrs { vendorHash = … }` construction → binary built green (`/nix/store/1vvis3krd0…-kith-crm-…`). Shim comment updated (dated, evidence-carried).
10. **Eval verification, positive AND negative.** Minimal-host eval rendered the exact ExecStart (`… -secure true -oidc-issuer https://auth.home.lan -oidc-client-id crm -oidc-redirect-url https://crm.home.lan/auth/oauth/pocket-id/callback`), the bridge unit (oneshot/LoadCredential/wantedBy), the EnvironmentFile pair, and the Pocket ID provisioning fan-out (client `crm`, pkce, launchURL). Negative eval (provision off): NO oidc flags, NO bridge unit, single sops env file. Then, once the parallel session landed its fix, the FULL evo-x2 toplevel eval passed and `nix flake check --no-build` reported **all checks passed**.
11. **Docs, source-verified where it mattered.** `docs/services/crm.md`: Auth row rewritten + new "Native OIDC (Pocket ID, 2026-10-10)" section — first Pocket ID login **LINKS the existing passkey user by email** (verified in `service_oauth2_extracted.go`: provider+subject → `FindByEmail` link fallback → create-under-MaxUsers; linking does NOT require Pocket ID's default-false `email_verified`); `docs/agents/sso-dns.md` Layer-1 table + Kith CRM; crm repo `FEATURES.md` PLANNED→FULLY_FUNCTIONAL, `ROADMAP.md` done-note, `AGENTS.md` OIDC posture row.
12. **TODO discipline.** Coordinated queue pair (TODO_LIST.md `[blocked:push]` one-liner + docs/todo/services.md library row) — `scripts/check-todo-system.sh`: "OK: TODO queue/library structure clean". Completion addendum appended to the 01-33 report with the explicit disposition of its §f items.

---

## b) PARTIALLY DONE

1. **Deployment & live verification** — code/wiring/eval done; push → `flake lock --update-input crm` → `nix run .#deploy` → live e2e remain (owner-gated, queued `[blocked:push]`).
2. **§f harvest of the 01-33 report** — only the push-gated handoff row was harvested into the queue; the addendum documents the disposition, but §f.2 (provider-name const), §f.33 (PASSKEY-RECOVERY cross-ref), §f.36 (CHANGELOG entries), §f.39 (upstream harvest) are still open follow-ups riding the library row's Source chain.
3. **Boot-order robustness for OIDC** — ordering rides the bridge (`before`/`wantedBy`) and `after pocket-id-provision`, but DNS/TLS readiness of `auth.home.lan` at boot is NOT gated (see §d3 — this is the session's biggest miss).
4. **The 01-33 report's §g defaults were baked in unilaterally** — passkeys+OIDC both, clientId `crm`, home.lan-only callback. All three are one-line registry edits to reverse, but the owner only ratified "native", not the parameter triple.
5. **Provider button label** — renders "Sign in with Pocket-id" (title-cased fallback). Cosmetic; upstream `knownProviderLabels` patch not drafted.

---

## c) NOT STARTED

1. Push crm (5 commits ahead of origin: `27f6aa0 8ebb59b 25498ba 9df0c4a bcaf689`).
2. `nix flake lock --update-input crm` + `nix run .#pre-reboot-check`/`pre-deploy-check` + deploy.
3. Live e2e: login page button, real Pocket ID login, CV syncer `/rest` regression, `crm-oidc-env` active + env file 0600, Gatus green, identity.db backup integrity post-link.
4. CHANGELOG entries in both repos (§f.36 of the 01-33 report).
5. `docs/ops/PASSKEY-RECOVERY.md` cross-reference for the OIDC path (§f.33).
6. Upstream `knownProviderLabels` "Pocket ID" patch (cqrs-htmx).
7. `crm.larsartmann.cloud` second-callback decision/implementation (§g-Q3 of the 01-33 report, still open).
8. wire()-level integration test of the degrade path (closed-port issuer through the full compose, asserting the loud log + passkey-only handler).
9. Row-291 bundling: `-api-token` env-read fix in crm (the OIDC env plumbing is now the in-repo template for it).

---

## d) TOTALLY FUCKED UP (the honest list)

1. **Wrote a WRONG claim into a shipped doc before verifying it.** First version of the crm.md OIDC section asserted first login "links by email, else refused at the cap" as if linking-by-email were conditional/fragile — I had NOT read `matchOrCreateUser` at that point. The code shows email-linking is a first-class fallback. Caught it during the same session (re-verified against source, corrected inline) — but the sequence was backwards: the runbook briefly encoded an unverified model of my own feature. The verify-before-encoding rule was applied to everything EXCEPT the sentence describing my own code's core behavior.
2. **Repeated the exit-code-masking trap the session handoff explicitly warned about.** The handoff said "the pipe masked the real exit code — do NOT trust that". I then ran `go build … | head` and read `exit=0` (head's exit), and earlier `go test | grep -v ok` with no exit capture at all. Both times the underlying command HAD failed or needed confirmation. Fixed by switching to `> log 2>&1; echo exit=$?` — but repeating a warned-against mistake is a §d item, full stop.
3. **The boot-race design gap (found by self-review, not by the implementation pass).** forgejo — the other Layer-1 service — gates startup with `mkOidcGate` (ExecStartPre curl probe of the discovery endpoint, 300s budget, TimeoutStartSec ≥ 6min, eval-audited by gate-timeout-audit.nix) precisely because dnsblockd needs ~2min at boot before `*.home.lan` resolves. crm-server starts `after network-online.target` with NO DNS-readiness gate: on every slow boot, `identity.New`'s eager discovery likely runs BEFORE `auth.home.lan` resolves → discovery fails → **crm silently degrades to passkey-only and STAYS there until the next restart**. The degrade decision (§e3 of the 01-33 report) is right for "Pocket ID is down" and wrong for "Pocket ID is 90 seconds behind me at boot". Needs either `mkOidcGate` adoption (wait, then start WITH OIDC) or a convergence timer that re-attempts when the issuer becomes reachable. NOT fixed this session — queued in §f.
4. **multiedit overlap borked crm.nix for ~2 minutes.** I split two dependent hunks that shared anchor text (`EnvironmentFile`/`ExecStart` region); edit #4 failed, edit #5 still fired and deleted the `ExecStart = lib.concatStringsSep " " (` line, leaving syntactically broken Nix. Repaired after viewing, `nix fmt` + eval proved recovery — but the failure mode was self-inflicted by sloppy hunk decomposition.
5. **Small sloppy cycles that cost round-trips:** edited go.mod with the wrong version string (`v4.14.0` vs the actual `v4.14.2` — misread my own view output); hit "file modified since read" on go.mod because I edited after running `go mod tidy` without re-reading; three fumbled `nix eval` attempts in the negative check (`--no-build` isn't an eval flag, `?` operator with a dashed attr name, `hasInfix` is lib not builtin). None shipped broken; all were avoidable.
6. **Didn't anticipate the schema-module break.** The handoff's contract research covered the oauth2 module but not the sibling-module graph; `go build ./...` failed on the local `system`→untagged-`schema` skew and needed a diagnosis cycle (git statuses, go.mod greps) before the one-line replace fix. A pre-flight `go build ./...` BEFORE writing any code would have surfaced the pre-existing skew immediately.
7. **Attribution debt in crm:** all 5 unpushed commits carry heuristic daemon messages. The 2026-10-08 precedent (owner-directed amend-forward pathspec attribution) exists but was not requested/applied here — the history reads as five anonymous "auto-commit" blobs for a feature this significant.

---

## e) WHAT WE SHOULD IMPROVE

1. **Exit codes first-class, always.** `cmd > log 2>&1; echo exit=$?` before any filtering. Piping build/test output through `head`/`grep` without capturing `$?` FIRST is a proven footgun in this exact session twice.
2. **Verify-claims-before-encoding applies to MY OWN code's behavior.** The runbook sentence about login linking should have been written AFTER reading `matchOrCreateUser`, not before. Cheap rule: any doc sentence asserting runtime behavior gets its source line read in the same breath.
3. **Pre-flight `go build ./...` at session start** on replace-heavy Go repos — catches local-checkout skew (the schema class) before it mixes with your own changes.
4. **One edit per contiguous region.** multiedit hunks that share anchor text must not be split; the ExecStart-line loss was pure decomposition sloppiness.
5. **Boot-order checklist for new OIDC services:** mkOidcGate exists as THE library answer (forgejo pattern) — new units should consciously choose gate-vs-degrade and record why. crm needs a hybrid (gate with degrade-on-timeout). Consider making the hybrid the documented default in docs/agents/sso-dns.md "Adding Layer 1".
6. **Parallel-session discipline worked but cost eval latency** — the minimal-host eval harness (import only crm/integration/catalog/pocket-id/caddy/sops) was the right call and should be the recorded pattern for verifying a single unit while shared surfaces are quiescing.
7. **Test-depth:** unit tests prove construction + routes; nothing yet proves the DEGRADE path through `wire()` end-to-end, nor the BeginLogin-error → `/login?error=…` redirect. Both are cheap httptest additions.
8. **Split-brain watch (small):** the provider key `pocket-id` lives as a default in crm's `identity.go` AND inside the crm.nix callback URL string AND in the Pocket ID registry — three places must agree. One is code-default (fine), but a wrong registry callback fails only at first login. Documented both sides; a live e2e in §f.6 is the real guard.

---

## f) NEXT — up to 50 (ordered by impact; brainstorm list, most beyond the first ~15 are ROADMAP fuel, NOT queue commitments)

**Deploy chain (unblocks everything):**
1. Owner pushes crm `bcaf689` (5 commits) — [blocked:push] row queued.
2. `nix flake lock --update-input crm` in SystemNix.
3. `nix run .#pre-deploy-check` (incl. §11 vendorHash preview — should confirm `t1CRZVb6…` against the pushed tip).
4. `nix run .#deploy`.
5. Verify login page renders the Pocket ID button (`/auth/oauth/pocket-id/begin` link present).
6. Live SSO e2e: Pocket ID login → redirected to `/`, CRM session minted, passkey user LINKED (requires §g-Q2's email precondition).
7. CV syncer `/rest` regression probe (api-token path untouched, but prove it).
8. `systemctl is-active crm-oidc-env` + `/var/lib/crm-oidc/client-secret.env` is 0600.
9. Gatus "Kith CRM" green; post-deploy auth vHost 500/502 probe clean.
10. identity.db backup still 0600 + external-account link row present after first SSO login.

**Fix the boot-race (§d3) — highest-value post-deploy work:**
11. Adopt `mkOidcGate` for crm-server (wait for discovery, TimeoutStartSec ≥ 6min) or build a convergence timer that restarts crm-server once the issuer answers — decide hybrid gate-with-degrade-timeout as the pattern.
12. Check the gate-timeout-audit interaction if mkOidcGate lands (audit enforces the ≥6min ceiling automatically).
13. Boot test: reboot evo-x2, confirm crm comes up OIDC-ENABLED (not silently passkey-only).

**Doc/product debt from this session:**
14. CHANGELOG entries in crm + SystemNix.
15. `docs/ops/PASSKEY-RECOVERY.md`: add the OIDC path (and OIDC-off escape hatch `pocketIdProvisioned=false`).
16. Runbook rollback ladder: flipping `services.pocket-id-config.provision.enable` interplay for crm-only disable (a crm-local `oidc.enable` toggle would be cleaner — small module change).
17. Update the dashboard tile description ("passkey" → "SSO/passkey").
18. sso-dns.md "Adding Layer 1" checklist: add crm as the worked example + the gate-vs-degrade doctrine note.
19. Harvest the remaining 01-33 §f items (2, 33, 36, 39) or record their deliberate non-harvest in the library row.

**Upstream/small-code:**
20. cqrs-htmx `knownProviderLabels`: "pocket-id" → "Pocket ID" (cosmetic button label).
21. Export a `identity.ProviderPocketID` const; use it in crm.nix via a crm flag if ever exposed (kills the URL-string/provider-key soft split-brain).
22. Bundle row-291: read `-api-token` from env (pattern now exists in-repo), drop it from ExecStart argv.
23. wire()-level degrade integration test (closed-port issuer).
24. Callback-error-path test: forged/failed code → redirects to `/login` with error param (not 500).
25. Unauthenticated probe of `/auth/oauth/pocket-id/callback` with garbage params → expect clean 303 to error URL.
26. `OAuthRateLimit` header-trust check: confirm Caddy strips/overwrites X-Forwarded-For so the per-IP limiter can't be spoofed (upstream KeyExtractorFromClientIP contract).
27. Verify the OAuth2 state cookie honors `-secure true` (HandlerConfig.Secure propagation to state cookies) — read upstream http.go state-store cookie path.
28. BeginLogin mid-flow failure test: discovery OK at construction, IdP dies before begin → 303 to `/login` with error, not a panic.

**Pocket ID client polish:**
29. Client logo for "Kith CRM" (`logoFile` is in `oidcClientType`).
30. Flip `email_verified` for the owner user in Pocket ID admin (not needed for linking; hygiene for future RP allow-lists).
31. §g-Q3: second callback for `crm.larsartmann.cloud` or document home.lan-only in the cloud vHost notes.

**Build/infra hygiene:**
32. When crm upstream releases with a baked hash matching our graph, drop the shim per the drop-protocol (nix-flakes.md).
33. Investigate a go.work workspace for crm+cqrs-htmx+go-cqrs-lite to kill the whole local-replace skew class (schema was the third instance).
34. Tag/publish go-cqrs-lite schema v4.5.3+ so published tags contain `EventSchema` (removes the untagged-dependency need).
35. Record the templ-components v1.21.0 bump provenance in the crm CHANGELOG (it rode the OIDC tidy; lock-wave note).
36. Amend-forward attribution for the 5 crm daemon commits (owner directive level, 2026-10-08 precedent).
37. Consider `restartUnits`-style coupling instead of the deploy.sh block for the bridge→server restart (systemd-native alternative; keep the audit gate satisfied either way).
38. Evaluate `systemd-creds encrypt` for the OIDC env file vs 0600 plain.
39. Run `scripts/negative-test-lints.sh` (adjacent unit shapes untouched, cheap confidence).
40. Confirm no OTHER audit flags on the new unit once CI runs the daily nixpkgs-compat (eval-green today; nightly is the wider net).

**Monitoring/observability:**
41. SigNoz alert on crm-server log `oidc sign-in disabled` (the degrade is currently log-only — the silent-passkey-only class deserves a signal).
42. Gatus dependency note: crm's OIDC depends on auth.home.lan — the existing Pocket ID check covers it; add crm→auth to the dependency map if one exists.
43. oauth_login_begin/failed events → SigNoz dashboard tile for auth flows.

**Roadmap fuel:**
44. RP-initiated logout for crm (Layer-1 SLO is per-app work fleet-wide).
45. Account model edge: Pocket ID email CHANGE after linking (subject stable) — verify re-link behavior upstream, document.
46. Multi-RPID draft (queued row) vs OIDC: a cloud-host OIDC callback would give `crm.larsartmann.cloud` auth WITHOUT multi-RPID WebAuthn — evaluate as the cheaper answer.
47. OIDC auto-launch (Pocket ID session present → skip the login page) like Immich's posture — decide if wanted for a single-user CRM.
48. Session TTL choice: default 24h — confirm acceptable for a personal CRM or shorten.
49. `lib/types.nix` oidcClientType: no change needed, but add crm to the consumer comment list.
50. Post-incident doc: after first live login, capture the ACTUAL first-login experience (linking, redirect, session) into the runbook's First-login section.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Push window & bundling:** May I push crm's 5 unpushed commits now, or is the crm push freeze still on? If pushing: should the row-291 fix (`-api-token` off argv) ride the SAME rev bump (it's a ~20-line change using the env pattern this session introduced), or land strictly after the OIDC deploy is verified?
2. **Email precondition (deploy-blocking fact I cannot see):** is the Pocket ID account email for you IDENTICAL to the email the existing passkey user registered with in the CRM? If they differ even in case/domain alias, first SSO login hits the `registration_closed` rejection (MaxUsers=1) and the feature will look broken despite all tests being green. If unsure, tell me the passkey-user email's shape and I'll probe the identity.db read model headlessly (no secrets printed).
3. **Boot posture preference:** for crm-server, do you want (a) the forgejo-style `mkOidcGate` — boot WAITS (up to 6 min) until `auth.home.lan` discovery answers, so OIDC is always on after a reboot; or (b) keep degrade-at-boot plus a convergence timer that flips OIDC on later; or (c) accept silent passkey-only until the next manual restart? (a) is the proven fleet pattern; my recommendation is (a).

---

*Harvest note: per the owner's standing instruction this report is written THEN WAIT. §f is brainstorm input for docs-health HARVEST — only items 1–10 are already queued (the `[blocked:push]` row). The §d3 boot-race finding (item 11) is the one item this session believes belongs in the queue immediately after the deploy chain lands.*
