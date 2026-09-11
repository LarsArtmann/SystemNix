# Status Report — Miniflux OIDC `redirect_uri` Outage Fix

**Date:** 2026-09-11 14:19 CEST
**Session scope:** Single-issue fix session. `rss.home.lan` SSO login failed at the Pocket ID authorize step. Root-caused, fixed, deployed, live-verified.
**Repo state at end of session:** working tree carries the fix (auto-commit daemon owns commits — no manual commit per harness contract).

---

## Incident Summary

| Field | Value |
|---|---|
| Symptom | `The 'redirect_uri' parameter is required when using OpenID Connect 1.0` on `auth.home.lan/interaction/error`, reached from `https://rss.home.lan/` |
| User-visible impact | **Complete SSO login failure for Miniflux** since bring-up (2026-09-10) — nobody could ever log in via Pocket ID |
| Root cause | Miniflux does **NOT** derive the OIDC redirect URL from `BASE_URL`. Upstream `OAUTH2_REDIRECT_URL` defaults to an **empty string** (`internal/config/options.go`). The SystemNix module (and its comment in `pocket-id.nix`) claimed auto-derivation — a false premise encoded at bring-up |
| Failure chain | Login button → `/oauth2/oidc/redirect` → goth built `oauth2.Config` with `RedirectURL: ""` → authorize request to Pocket ID with **no** `redirect_uri` parameter → Pocket ID (correctly) rejects with the OIDC-spec error |
| Fix | Explicit `OAUTH2_REDIRECT_URL = "https://rss.<domain>/oauth2/oidc/callback"` in `modules/nixos/services/miniflux.nix` (byte-matches the registered Pocket ID callbackURL) |
| Verification | Eval check → deploy via `nix run .#deploy` → live header probe: `/oauth2/oidc/redirect` → 302 → `/authorize?...redirect_uri=...&code_challenge_method=S256...` → Pocket ID lands on `/interaction` (passkey screen), **not** the error page |

**Files changed:**
- `modules/nixos/services/miniflux.nix` — the fix + corrected comment
- `modules/nixos/services/pocket-id.nix` — corrected the false "derived from BASE_URL" comment
- `AGENTS.md` — Miniflux section bullet: the trap, the signature, the live-verified post-fix chain

---

## a) FULLY DONE

1. **Root cause identification** — proved from upstream source (`internal/oauth2/oidc.go`, `manager.go`, `options.go`) that `OAUTH2_REDIRECT_URL` defaults to empty; the module comment was a hallucinated assumption from the original bring-up session.
2. **The fix itself** — one-line config addition, correctly scoped inside the `enableOidc` optionalAttrs block, with a comment explaining WHY (upstream default is empty) and the byte-match requirement vs `pocket-id.nix callbackURLs`.
3. **Deployed live** — `nix run .#deploy` completed; smoke suite: 93 PASS / 7 FAIL / 6 SKIP / 3 WARN, with all 7 FAILs matching the pre-existing baseline (advisory exit, explicitly flagged as baseline).
4. **Live E2E verification (to the maximum reachable without a browser)** — captured the raw 302 Location header via Python (not the ambiguous fetch-tool body): `redirect_uri=https%3A%2F%2Frss.home.lan%2Foauth2%2Foidc%2Fcallback`, PKCE S256 present, state present. Probed the authorize URL directly against Pocket ID: HTTP 200 landing on `/interaction?interaction=<uuid>` — the passkey screen. The error is gone.
5. **Eval-time verification** — `nix eval .#nixosConfigurations.evo-x2.config.services.miniflux.config` shows the full env set including `OAUTH2_REDIRECT_URL`.
6. **Memory/AGENTS.md updated** — the lesson is written where the next session will read it, in the exact Miniflux section, with the live-verified evidence chain.
7. **Comment-drift corrected at both ends** — `pocket-id.nix` carried the same false derivation claim; both comments now state the empty-default fact and the byte-match invariant.

## b) PARTIALLY DONE

1. **End-to-end SSO login proof** — verified up to the Pocket ID interaction screen. The final passkey tap + auto-provisioned user landing back in Miniflux requires a browser + human passkey gesture. High confidence it now works (the rejected parameter was the only failure), but NOT proven by this session.
2. **First-login auto-provisioning** — `OAUTH2_USER_CREATION=1` should create the `lars` account on first SSO login; untested until the user actually logs in.
3. **The `disableLocalAuth` go-live gate** — the module's SSO-only option is explicitly gated on "one proven live SSO login". That proof now exists in ~90% (pending the human passkey tap), so the flip decision is ready but not made.
4. **Deploy-smoke baseline FAILs** — 7 checks failed before this session and still fail; I explicitly did NOT investigate them (out of scope per instruction), but they are recorded here for harvest.
5. **Regression protection** — the lesson lives in comments + AGENTS.md (documentation layer) but NOT in any enforcement layer (see c).

## c) NOT STARTED

1. **Eval-time assertion for the class** — the repo's own doctrine (5 prevention layers) demands this be caught at eval time: an assertion in `miniflux.nix` (or a shared OIDC audit) that `OAUTH2_REDIRECT_URL != ""` whenever `OAUTH2_PROVIDER = "oidc"`. A future session removing the line "because BASE_URL covers it" would silently resurrect the outage.
2. **VM-test regression step** — `tests/test-miniflux.nix` asserts the OAUTH2/LoadCredential wiring; it does NOT assert `OAUTH2_REDIRECT_URL` is non-empty on the unit. One line would close it.
3. **TODO_LIST harvest** — this report's section (f) items have not been routed into `TODO_LIST.md` / `ROADMAP.md` (docs-health HARVEST).
4. **Runbook check** — `docs/services/miniflux.md` was written at bring-up and may repeat the same false "derived from BASE_URL" claim; not checked this session.

## d) TOTALLY FUCKED UP

Nothing in this session is fucked up. Two session-level failures worth naming honestly:

1. **The original bring-up (2026-09-10, other session) shipped a false premise as a comment** — "The redirect URL is derived from BASE_URL upstream" — and the module passed `nix flake check`, eval, VM test, Gatus, and deploy smoke **while SSO was 100% broken**. Five prevention layers, none caught a wrong *assumption in a comment*. The Gatus "Miniflux Login Renders" check is green on the password form alone — it never exercises the OIDC begin-auth redirect. That is the real structural finding: **SSO success was never a verification target anywhere.**
2. **My own verification detour** — the `fetch` tool followed redirects and returned SvelteKit app shells twice (the error page and the interaction page render identically as HTML), costing two ambiguous round trips before I switched to a no-follow header probe. Lesson applied: when the response body is a SPA shell, only headers discriminate; go straight to the redirect chain.

## e) WHAT WE SHOULD IMPROVE

1. **Add an SSO-functional check, not a liveness check.** Every Layer-1 service's monitoring asserts "login page renders HTML" — none asserts "the OIDC begin-auth redirect is well-formed". A cheap generic Gatus check per OIDC service: probe `/oauth2/.../redirect` (or equivalent) and assert the Location header contains `redirect_uri=`. This class of outage (miniflux) would page in 60s instead of living invisibly for a day+.
2. **Never encode a library-behavior claim in a comment without a source link or a live probe.** The false comment cost the entire outage; a `# verified: <url>` convention (like the AGENTS.md "verified live" discipline) would force the check at write time.
3. **Byte-match invariant between `OAUTH2_REDIRECT_URL` and `pocket-id.nix callbackURLs` should be machine-checked** — both derive from the same `domain`, but a future path edit on one side only desyncs them into a redirect_uri-mismatch error (a *different* Pocket ID failure than today's).
4. **Discriminate SPA-shell responses in verification tooling** — body-based fetch verification is useless against SvelteKit/React frontends; header-level probes should be the default reflex (this is now the second repo lesson about probe fidelity: the python-urllib-follows-redirects trap, now the SPA-shell trap).

## f) UP TO 50 THINGS TO GET DONE NEXT

*Session-derived first; then repo-known items observed/noticed this session. Items 1–8 are direct descendants of this session; 9+ are harvest candidates. Most of 9+ are ROADMAP fuel, not commitments.*

**Direct from this session (P0/P1):**
1. User performs the live passkey SSO login at `https://rss.home.lan/` → proves the fix end-to-end (the ~10% gap).
2. Verify `OAUTH2_USER_CREATION` auto-provisioned the `lars` account (admin UI or DB) after first login.
3. Add eval-time assertion: `OAUTH2_PROVIDER = "oidc"` ⇒ `OAUTH2_REDIRECT_URL != ""` in `miniflux.nix` (negative-tested per repo doctrine).
4. Add `OAUTH2_REDIRECT_URL` non-empty assertion to `tests/test-miniflux.nix` unit-wiring step.
5. Check + correct `docs/services/miniflux.md` if it repeats the BASE_URL-derivation claim.
6. Generic Gatus "OIDC begin-auth well-formed" check pattern for Layer-1 services (miniflux first, then browser-history/paperless/gatus/forgejo).
7. Flip `services.miniflux.disableLocalAuth = true` after (1) proves SSO — the module's own go-live gate.
8. Docs-health HARVEST: route this report's items into `TODO_LIST.md`/`ROADMAP.md`.

**Noticed this session (P1/P2):**
9. Investigate the 7 baseline smoke-check FAILs (they predate this session; content not inspected — that itself is a blind spot in the baseline practice).
10. Investigate the quickshell journal error lines (1 in last hour, smoke WARN).
11. Establish whether elevated memory PSI some avg10=6.15% at smoke time is the new steady state or transient (smoke WARN, 5–20% band).
12. OWED REBOOT (pre-existing, adjacent-confirmed this session): flm :52626 corpse + D-state llama corpses still pinned from 2026-09-07; staged fastflowlm v1.0.3 go-live gates live on it.
13. Before that reboot: run `nix run .#pre-reboot-check` (doctrine) and confirm the miniflux fix is in the boot-default generation (the exit-4/un-anchored-generation class would silently revert it).
14. The 2026-09-07 store-flip stuck-boot follow-ups: verify `/nix/var/nix/gcroots/profiles` symlink repair survived, boot-rollback ladder closure-verified.

**Repo-known (P2, harvest into TODO_LIST as appropriate):**
15. SigNoz traces-coverage gaps: flip remaining `wiring = "upstream"` entries to enforced as instrumentation lands.
16. Turso decision (DiscordSync): user decision pending — upgrade plan or strip TURSO_* + drop the deliberately-red Gatus check.
17. mail-relay go-live: verify `larsartmann.cloud` in Resend (SPF/DKIM) → re-run the runbook test send; confirm pocket-id SMTP key byte-equals the relay key if the test still fails.
18. Hetzner StorageBox + BorgBackup offsite leg: implementation tracked in TODO_LIST, not started.
19. clickhouse-backup follow-up (telemetry has NO backup coverage — btrbk excludes it).
20. google-sync go-live user sequence (dormant; 5-step checklist in AGENTS.md).
21. CV `pipeline.evaluation.min_day_rate` owner decision (EUR/day floor; CV repo proposed 600).
22. `NIX_GITHUB_RO_TOKEN` secret in GitHub CI — 120+ dark CI runs until it exists.
23. tq-agent-pool: flip the interim `git+file` input to `github:...?ref=master` once go-taskqueue pushes.
24. dnsblockd upstream health-cache fix: push + tag + flake bump (unpushed working tree).
25. bank-sync statement_coverage fix: push + flake bump + deploy (committed locally, unpushed).
26. fastflowlm v1.0.3: after the owed reboot — live `flm serve` validation, Q4_K weight re-pull, or revert to v1.0.2.
27. Context7 key rotation (still-live leaked key; rotation is the real fix, purge is held).
28. History purge push decision unchanged (held indefinitely; rotation preferred).
29. `/data/models/llm/gemma-4-31b-abliterated-Q8_0.gguf` EIO-corrupt: delete/re-download decision.
30. Paperless old SQLite export recovery decision (user decision pending).
31. Immich mail notification admin-UI config (needs a mailbox decision).
32. Paperless inbound mail consumption (UI-configured, mailbox decision).
33. Hermes workspace layout decision (deferred; revisit trigger in TODO_LIST).
34. Hermes workspace layout trigger date check.
35. YubiKey PAM (u2f) for sudo/login — "worth considering later" item.
36. disko declarative disk-layout documentation (document-only; Samsung-flip-triggered).
37. Point some flake inputs at the Forgejo mirror infra (GitHub-outage immunity tradeoff decision).
38. `nix.settings.allowed-users = ["@wheel"]` — verified applicable, not applied.
39. Samsung 970 EVO Plus role assignment: design doc exists; deployment (64G XFS hot-DBs + BTRFS /nix) not started.
40. Docker data-root cleanup: ~88% pruneable garbage in `/data/docker` (2026-08-31 verified figure; may have changed).
41. PapDashboard corpse-aware restore skip for the memory-emergency-guard (P1 candidate in TODO_LIST Phase-1).
42. Jan: models already physically at `<data>/llamacpp/models` — verify the path guard no longer hides anything; jan-data-link activation self-audit.
43. Browser-history `importUsers()` CSV path still ungated by MAX_USERS (upstream ask).
44. go-output v0.37.1 re-tag request (never re-tag doctrine — upstream issue candidate; verify-before-filing applies).
45. `startLimitBurst`/`StartLimitIntervalSec`-in-serviceConfig eval-time guard (systemd gotcha has no enforcement yet).
46. README/docs sweep for other "derived from X" comments encoding unverified library behavior (class-wide comment audit, starting with Layer-1 OIDC services).
47. btrbk `/data` send EIO inode (TODO_LIST P0): corruption repair stance unchanged — keep failing until repaired.
48. Snapshot-pinning of the emergency reserve: revisit if chunk-unalloc drops near the 5G floor.
49. gatus-pattern-lint / pre-deploy §10: confirm no new pat() traps introduced anywhere by this session (clean — nothing added — but the habit of re-running after any gatus-adjacent edit stands).
50. Miniflux: consider adding `OAUTH2_SCOPES`/account-linking review after first real SSO login (miniflux links by username — confirm the provisioned username matches `lars` expectations).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Did the live SSO login succeed?** Can you open `https://rss.home.lan/`, click "Sign in with Pocket ID", complete the passkey, and land in the dashboard? (This is the only unverifiable-from-CLI step — it needs your browser + passkey. If it works, item 7's `disableLocalAuth` flip becomes safe.)
2. **Do you want the enforcement layers now (items 3+4) or is the documented lesson enough?** The repo doctrine says every class gets an eval-time guard + VM-test step; but this is a one-line config on a single service — I can argue either way and it's your call on guard-density.
3. **The 7 baseline smoke FAILs — known-and-accepted, or should they be the next session's target?** I deliberately didn't investigate them (scope discipline), but they were failing before this session and nothing in the baseline file tells me whether that's a decided stance or accumulated debt.

---

**Session verdict:** one false comment caused a total SSO outage that survived five prevention layers; the fix is one line, deployed and live-verified up to the human passkey step. The durable lesson is about verification targets, not about miniflux.
