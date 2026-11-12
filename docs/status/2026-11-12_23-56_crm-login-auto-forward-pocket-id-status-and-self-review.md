# Kith CRM login auto-forward to Pocket ID — session status + self-review

**Date:** 2026-11-12 23:56 CET · **Repo:** crm (`~/projects/crm`, this session ran from the SystemNix session) · **Commits:** `43f9e64` (docs, pathspec), code swept into daemon commits `4f68d68` + `2783f7c`

**Trigger:** the owner pasted the CRM sign-in screen — "Kith CRM / Sign in to your account / Sign in with Pocket-id / Auto forward to PockedId!" — read as the feature ask: in the `-passkeys=false` posture Pocket ID is the ONLY sign-in method, so the chooser page is one dead click; make a bare `/login` go straight to Pocket ID. No auto-forward text existed anywhere in the repo (grep-verified), so the feature-request reading was the only consistent one — but it was never explicitly confirmed (see §d.1).

## What was built

`identity.LoginHandler` (internal/identity/identity.go:424): wraps the bundle login page. Bare GET/HEAD with **no query** → 303 to `/auth/oauth/<provider>/begin` (path computed by `soleProviderBeginPath`, identity.go:265, active only when `DisablePasskeys && OAuth2 booted`). **Any query** (`?error=…` — the OAuth2 callback's error return, verified against cqrs-htmx usermgmt `oauth2_http.go:93` which lands errors at `/login?error=…` — plus `?manual=1`) renders the interactive page unchanged: the query escape is what keeps OAuth error returns out of a redirect loop. Passkeys-on and passkey-only postures keep the bare page. Wired at cmd/crm-server/main.go:650 in place of `ident.Login`.

## a) FULLY DONE

1. **Feature implemented + wired** — identity.go (`LoginHandler`, `soleProviderBeginPath`), main.go mux. No templ changes needed.
2. **Tests updated + green** — passkeys_bdd_test.go: three new specs (bare GET → 303 + Location pin; `?manual=1` interactive button-only page; `?error=access_denied` interactive no-loop); mux now mounts `LoginHandler()`; the Describe comment states the new contract. cmd/crm-server/main_test.go: `TestWirePasskeysOffServesOIDCOnlyLogin` rewritten for the wiring-level contract (bare GET 303 → begin; `?manual=1` 200 + button, no passkey string; gate + settings legs unchanged). `newIdentityServer` helper (oauth2_test.go) mounts the wrapper so plain tests exercise the production form. `go test` green in both packages.
3. **Gates** — `go build ./...` + `go vet` clean; buildflow dev battery: 71 steps success; `golangci-lint` re-run exit 0 after fixing its one finding in my code (cyclop: `New` hit 14 > 12 from the added branch — fixed by extracting `soleProviderBeginPath`); `test-race` green; `nix-build` green (incl. `.#kith-crm`). Findings reported by other tools were pre-existing families in files I did not touch (art-dupl 163, bandit 357, go-auto-upgrade 60 — all documented dispositions in crm AGENTS.md).
4. **Docs** — crm FEATURES.md FULLY_FUNCTIONAL row (auto-forward contract + evidence), crm AGENTS.md decisions-table row "Login auto-forward (11-12)", crm CHANGELOG `[Unreleased]` Added entry. Committed as `43f9e64` (pathspec: AGENTS/CHANGELOG/FEATURES only).
5. **HEAD-verify of daemon-swept code** — `git show` confirmed identity.go/main.go/passkeys_bdd_test.go content landed intact in `4f68d68` + `2783f7c` per the 10-23 HEAD-VERIFY rule.

## b) PARTIALLY DONE

1. **The feature is not live.** Everything above is local-only until crm master is pushed, the SystemNix `crm` lock input is bumped, and a deploy lands (§c.1). "Working" currently means gated tests + nix build, not prod behavior.
2. **One end-to-end green buildflow run never happened.** The dev battery exited 69 with `test-race` + `nix-build` starved (15m load 47.24 — the parallel session's builds); both steps re-run individually green, but the battery as a whole was never green in one pass.
3. **Edge coverage implemented but untested:** HEAD-method auto-forward, authenticated-user bare GET /login (now round-trips through Pocket ID back to `/` instead of whatever the library did — behavior change unverified), and the OAuth-begin rate limiter interplay (auto-forward funnels every anonymous pageview into `/auth/oauth/…/begin`; the 10/min OAuth limiter is now on the hot path — a refresh-mash could 429 where the old page just re-rendered).

## c) NOT STARTED

1. **Deploy chain** — push crm master (`43f9e64` + riders) → SystemNix: bump the `crm` flake input to the pushed rev (go.mod/go.sum untouched, so the go-modules vendorHash should carry; only the source hash moves with the lock) → `nix run .#deploy` → anchor check (`readlink /run/current-system` == newest `system-N-link`).
2. **Live post-deploy verification** — bare `https://crm.home.lan/login` probe expecting 303 → `auth.home.lan` authorize URL (openssl s_client probe per the agent probe set), plus the §20 OIDC-readiness battery leg.
3. **SystemNix queue row** for the deploy chain (`[blocked:push]`, docs/todo/services.md) — **deliberately not harvested at authoring time**: the owner instructed report-then-WAIT, so queue edits await the go-ahead (recorded here per the self-harvest rule).
4. **Pattern propagation** — whether other Layer-1 native-OIDC services (CV, Browser History, Paperless, Gatus, Forgejo per docs/agents/sso-dns.md) should adopt the same bare-login auto-forward. Not researched (out of session scope), not decided.
5. **Visible manual-sign-in escape** — with auto-forward live, the chooser page is reachable ONLY at `/login?manual=1` (invisible knowledge). Whether the forwarded page should carry a small "Sign in manually" link is unstarted/undecided.

## d) TOTALLY FUCKED UP

Nothing. No data damage, no live-system mutation, no broken gates, no foreign work harmed. Honest near-misses, in order of severity:

1. **Built from a five-word paste without confirming the reading or probing the live page.** The repo doctrine ("probe the LIVE state first"; reversible-change-confidence) makes this acceptable for a reversible local code change, but a 10-second live probe of `crm.home.lan/login` before building would have pinned the baseline UX the owner actually saw, and one explicit line ("reading this as: make /login auto-forward — building it") would have surfaced a misread before any code existed. If the paste actually meant something else (e.g. reporting a Pocket-ID-side typo), this session built an unrequested feature.
2. **The feature's code rides heuristic daemon commit titles.** `4f68d68`/`2783f7c` are "auto-commit (heuristic)" carrying my identity.go/main.go/tests mixed with the parallel session's status reports, templ regen, and TODO_LIST rows. Amending would have absorbed the other session's files (forbidden), so the searchable description of the change lives only in the `43f9e64` body and the docs rows. History archaeology for this feature requires knowing that.
3. **Attribution gap in my final chat message:** I flagged the templ regen + status reports as foreign riders but missed crm TODO_LIST.md (+17 lines, parallel session) in `2783f7c`. Shared-tree attribution should have been complete.
4. **Cyclop overflow shipped before the gate caught it.** Adding `if + &&` to a function already at the complexity ceiling without counting branches cost one refactor loop. Minor, but predictable.

## e) WHAT WE SHOULD IMPROVE

1. **Live-probe before building** when a session's spec is a pasted UI fragment — one openssl probe beats code-reading-only confidence (repo doctrine: never assert capability from a doc claim alone).
2. **State the interpretation in one line, then execute** — cheapest possible misread insurance for ambiguous pastes.
3. **Count branches before adding them to gate-sensitive functions** (cyclop ≤ 12 here) — extract-first instead of fix-after-lint.
4. **Complete foreign-file attribution** in every final message on a shared tree (list EVERY non-mine file in any commit my work rode).
5. **Self-harvest follow-ups at authoring time** even when the owner will answer later — the rule exists precisely so open work never lives only in a chat message; the WAIT instruction should defer execution, not the queue row. (This report records the deferral explicitly instead.)
6. **Land one green end-to-end battery** before declaring a session gated-clean when steps were starved and re-run individually.

## f) NEXT TASKS (session-derived, no unrelated research)

Deploy chain (owner-gated):
1. Push crm master (owner decision — push-gated).
2. SystemNix: bump `crm` lock input to the pushed rev; verify the go-modules vendorHash carries (go.mod untouched) — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` enumeration first.
3. `nix run .#deploy`; verify anchor per the 2026-10-14 discipline.
4. Live probe: bare `GET https://crm.home.lan/login` → 303 → `auth.home.lan` (openssl s_client, LAN IP).
5. Re-run the §20 Kith OIDC-readiness post-deploy leg.
6. Add the SystemNix `[blocked:push]` queue row for this chain (pending owner go; self-harvest deferred per §c.3).

Robustness/tests (crm):
7. HEAD `/login` auto-forward test (implemented, untested).
8. Authenticated-user bare GET `/login` behavior: decide intended semantics (silent `/` vs IdP round-trip) and pin it.
9. OAuth-begin rate-limiter × auto-forward interplay: confirm a 429 lands somewhere non-looping (`?error=`-shaped or JSON), add a test or document.
10. Consider Gate() short-circuit to the begin route in the sole-provider posture (drops the `/login` hop) — needs the same query-escape care; candidate simplification, not committed.
11. One full green `buildflow --build-mode dev` run when the box is quiet.

UX/scope (owner decisions):
12. Visible "Sign in manually" escape link on the forwarded page, or `?manual=1` suffices (§c.5).
13. Auto-forward adoption for other sole-OIDC services, or Kith-only (§c.4).
14. Pocket ID session lifetime: confirm an existing Pocket ID session makes the auto-forward a zero-click re-entry (otherwise it saves exactly one click).
15. crm CHANGELOG release cut when this batch ships (entry currently sits in `[Unreleased]`).

Repo hygiene noticed during gates (pre-existing, not this session's):
16. `err113` lint noise in `cmd/crm-reset-projections/main.go` (3 dynamic-error findings + 1 mnd) — reported every run, gate-excluded; fix at source or suppress with a reason per the scanner doctrine.
17. `go-licenses` warning resolving `../cqrs-htmx/loginpage` as a host (`lookup ..: no such host`) inside the nix-run env — triage whether it matters for the license report completeness.
18. crm TODO_LIST.md +17 lines rode `2783f7c` from the parallel session — verify attribution when that session reports (not mine to judge now).
19. Parallel session's 17-file `*_templ.go` regen (`b167d58`) — confirm their close-out lands it deliberately (not mine to revert; flagged per shared-tree rules).

## g) QUESTIONS FOR THE OWNER

1. **Deploy now or hold?** Push crm master + bump the SystemNix `crm` lock + deploy the auto-forward tonight, or batch it with the next deploy window?
2. **Chooser-page fate:** with auto-forward live, the button page exists only at `/login?manual=1` and nothing advertises it. Acceptable for a single-user CRM, or do you want a visible fallback link rendered somewhere?
3. **Scope:** is Kith the only sign-in surface you want auto-forwarding to Pocket ID, or should the same bare-login pattern be evaluated for the other Layer-1 native-OIDC services (CV, Browser History, Paperless, Gatus, Forgejo)?
