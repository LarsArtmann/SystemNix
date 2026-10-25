# OpenSEO go-live prep → registry wave: 4 blind vHosts registered, GSC/AI flags pending owner keys

**Session:** 2026-10-25 ~18:00–19:35 · single agent (crush) · evo-x2 working tree
**Trigger:** owner asked "We still have OpenSEO right? What do we need to set up so it works for real?" then "let's do it all together".
**Owner answers taken mid-session (question tool):** enable BOTH GSC + AI · §g.2 YES ("subdomain != null ⇒ must be on dashboard") · §g.3 pocket-id = oversight, register it.
**Parallel session ACTIVE throughout:** the Caddy edge-OTel Pareto plan was marked EXECUTING (65d60f3a6) and its OTel/tracing work rode into caddy.nix + shared daemon commits alongside mine. `flake.lock` float at close is THEIRS, untouched by me.

---

## a) FULLY DONE (verifiably)

1. **OpenSEO live-state audit (start of session).** Service confirmed running: vite preview listening 127.0.0.1:3002, workerd (D1/KV emulation) up, openseo-0.1.1 store build. Enabled in configuration.nix:986. Base app healthy — but running HOLLOW: `googleSearchConsole.enable` and `aiFeatures.enable` both unset; sops `openseo.yaml` holds exactly one key (`dataforseo_api_key`).
2. **Env contract verified from the app's own source** (store build, src/env.d.ts + src/lib/auth.ts): `DATAFORSEO_API_KEY` required; `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`/`BETTER_AUTH_SECRET` (≥32 chars, required in self-hosted when GSC enabled); `OPENROUTER_API_KEY` optional; `BETTER_AUTH_URL` NOT needed in `local_noauth` (placeholder used). Module wiring in sops.nix matches this contract exactly — nothing to fix there.
3. **Catalog-coverage row closed** (§f.9 of the 09:46 report): `catalog-platform.nix` already carries `seo`→openseo:3002 and `tasks`→taskchampion. Answered + marked `[x]` in BOTH surfaces.
4. **The full §g registration wave** (the session's main work): all four blind vHosts now have `services.integration` entries with subdomains —
   - `openseo` (seo) + `taskchampion-sync-server` (tasks): NEW in-module entries (module heads gained the `options` arg for the `options ? services.integration` guard).
   - `pocket-id` (auth) + `dnsblockd` (dnsblock): existing entries extended.
   - All four carry `vHost.layer = "none"` → the registry generates NO vHost (no `//`-merge override) → the hand-written vHosts stay canonical: GSC callback forward-auth exemption (path-scoped, unreachable by the registry renderer), pocket-id's oauth2/pocket-id split, dns redirect pair. dnsblockd's dashboard-facing name is `dnsblock`; the DoH endpoint pair-mate stays blind.
5. **Tile migration, 4 built-ins removed** (papdashboard.nix): Pocket ID + DNS Blocker out of Infrastructure, Taskwarrior + OpenSEO out of Productivity (group shell kept per the "kept even when empty" convention); registry homepages carry identical names/icons/descriptions/checkUrl. This was MANDATORY, not cosmetic: the Immich/Forgejo precedent in-file says the floated PapDashboard binary refuses duplicate names per group (start-limit-hit).
6. **Gatus check migration**: OpenSEO's hand-written mkHttpCheck removed from gatus-config.nix, re-declared in the entry (`path = "/"`, 5m, `[STATUS] == 200` + `[RESPONSE_TIME] < 2000`, Discord alert). Twenty CRM precedent followed. Taskchampion's tcp check deliberately stays hand-written (registry checks fan out through mkHttpCheck — HTTP-only).
7. **caddy.nix blind table 8→4** (alerts/logs/dnsblockd/paperless), every remaining row re-justified with dated comments.
8. **Verification battery — all green:**
   - `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` → GREEN (forces every eval-time assertion: vHost⇒registry, tile-coverage, contradictoryOptOuts, dns-local consistency, ghost sweep). Pre-existing catalog warning correctly no longer lists seo/tasks/auth/dnsblock.
   - `CASES=tilecoverage,vhostregistry` negative tests → **5/5 PASS** (controls pristine-eval + tile-stripped fires + icon-stripped warns + optout-with-tile fires + vhostregistry blind-vhost fires). The harness's pristine copy = my final code state.
   - Hook-identical statix (per-file, errfmt) → zero findings on all 7 touched .nix files; deadnix clean; `nix fmt -- <12 files>` → 0 changed (canonical).
   - `check-todo-system.sh` → "OK: TODO queue/library structure clean" (the 128-unharvested WARN is pre-existing, fleet-wide, other sessions' reports).
9. **Docs + queue hygiene**: TODO_LIST.md + docs/todo/services.md registration rows `[x]`-closed in both surfaces with full close-out notes; tile watch row extended to cover the 4 migrated tiles; docs/services/openseo.md monitoring section rewritten for registry ownership; docs/services/caddy.md gate paragraph updated (8→4); CHANGELOG entry landed. §f direct follow-ups self-harvested into both surfaces at authoring time (4 new rows, see §c/§f).
10. **Daemon-race handling per policy**: parallel session's work interleaved in caddy.nix and daemon commits (b93270de6, 130fbfa3a, 3347fb579, 3c10b84b3, 56206667f — my files + their OTel additions swept together). Verified `git show --stat` contents, did NOT amend (their work is inside; amending would absorb it), re-read before every re-edit after two mod-time races on TODO surfaces.

## b) PARTIALLY DONE (honest gaps)

1. **OpenSEO GSC redirect_uri construction is UNVERIFIED — and it gates the owner's next physical step.** I verified the env contract and the route (`/api/gsc/oauth/callback` in routeTree.gen.ts, GSC scope `webmasters.readonly`), and that better-auth's local_noauth baseURL is a placeholder "never read by GSC token minting". But I did NOT find WHERE the OAuth `redirect_uri` string sent to Google is built. If it derives from the localhost placeholder instead of the request host, the registered `https://seo.home.lan/api/gsc/oauth/callback` mismatches and the whole OAuth round-trip fails AFTER the owner has done the Google-side work. **Queued [ready] as the FIRST next task** (both surfaces) — grep the store src for the redirect param construction before the owner touches Google Cloud Console. Mitigation if placeholder-derived: set `BETTER_AUTH_URL=https://seo.home.lan` in the module env (the hosted-mode schema accepts https).
2. **Rendered-output parity never proven.** I proved EVAL green (assertions) and mutation gates fire, but never diffed what the fan-outs RENDER: the gatus endpoint list (is the OpenSEO check actually present with the right alert?), the rendered tile list (right groups, zero duplicates), `/etc/caddy/vhost-layers`, system-health extraMonitoredServices. Eval-green ≠ rendered-right. **Queued [ready]** with the exact 5-step proof, including `nix build .#checks.x86_64-linux.integration-registry` — the dedicated check derivation that I cited from the 09:46 report but never actually ran myself.
3. **`nix flake check --no-build` not run this session** (full-tree syntax gate incl. rpi3-dns + the paperless-assertion non-evo-x2 caddy contexts). Justified at the time by PSI (~55% avg60) + the active parallel session (a full check absorbs THEIR in-flight state), but the rpi3-dns §f.8 inertness row stays open and the VM-test interplay with my new `options`-guarded entries is eval-unverified. Deploy validation will run the full gate anyway.
4. **Tile GROUP ORDER changes and I shipped them unverified**: registry extraTiles APPEND to groups (Pocket ID/DNS Blocker move from front to END of Infrastructure; Taskwarrior/OpenSEO land in Productivity in attr-iteration order — likely openseo before taskchampion, i.e. order swapped vs. today). Cosmetic, but I asserted "acceptable" without proving the render order or asking. Folded into the §g question list.
5. **Backup story flagged but not built**: `/var/lib/openseo/.wrangler` (D1 SQLite rank history) and taskchampion sync data are UNBACKED-UP. Assessment queued [ready]; adoption gated on the owner's retention answer (§g.3 below).

## c) NOT STARTED (deliberate or blocked)

1. **The actual "for real" flip: `googleSearchConsole.enable` + `aiFeatures.enable` → deploy → post-deploy verify.** BLOCKED on owner-entered sops keys (google_client_id, google_client_secret, better_auth_secret, openrouter_api_key into `openseo.yaml`, interactive sops only). Flipping early = `openseo-validate` refuses startup → crash-loop (startLimitBurst 5). Full instructions delivered in-session; now ALSO queued `[blocked:user]` in both surfaces so it survives the session.
2. **Owner-side secret prerequisites**: Google Cloud OAuth client (Search Console API enabled, consent screen in TESTING mode with the account as test user, redirect URI exactly `https://seo.home.lan/api/gsc/oauth/callback`), OpenRouter key, `openssl rand -base64 32` for better_auth_secret. I cannot do any of these (secret values are owner-held, hard rule).
3. **§g.1 (§16 monogram-tile BLOCK severity)** — untouched, still `[decision]`, not this session's scope.
4. **Paperless blind-row removal** — gated on its own native-OIDC registry move; left blind with justification.
5. **The 128 unharvested §f-bearing reports WARN** — pre-existing fleet-wide harvest debt, not touched (would be a separate docs-health sweep).
6. **ai-meter openrouter re-add** — same key that unlocks openseo aiFeatures would let the 2026-10-17-dropped openrouter copy return; owner-held trigger, recipe in ai-meter.md. Mentioned, not queued (already recorded there).

## d) TOTALLY FUCKED UP (radical honesty — all caught in-session, none shipped broken)

1. **Typed `rg -rn <pattern>` — the EXACT trap AGENTS.md has warned about since 2026-10-23 (third documented strike on this host), and the hook blocked it.** I re-read that rule in AGENTS.md at session start and still typed the -r form out of grep muscle memory. The hook saved me; memory discipline didn't. Cost: one blocked call, zero corruption.
2. **~5 wasted tool calls fighting tooling instead of reading the hook.** Ad-hoc `nixpkgs#statix` (which AGENTS.md explicitly warns differs from the pinned version), then JSON parse failures, then per-file loops — all before reading `.githooks/pre-commit` lines 299–324 which gave me the EXACT blessed invocation (`statix check -o errfmt "$f" | grep -v ':E:0:'`). Reading the hook first = zero waste. Also risk: ad-hoc statix could flag things the pinned one doesn't → phantom work.
3. **question tool failed twice in a row** (sent the batch without `choices` arrays, twice). Two round-trips burned asking the owner nothing. Sloppy tool use, no ambiguity in my defense.
4. **Two edit-tool mod-time race failures** on the TODO surfaces (parallel session). Not a fault — but my first reaction was a blind retry; the correct re-read-before-edit discipline was applied only after the tool refused. The refusal IS the safety net working.
5. **Minor false economy**: I nearly ran full `nix flake check` during the 85 °C/55% PSI window (would have been the heaviest possible eval at the worst moment). Caught it pre-flight via the PSI doctrine, but the instinct to "just run the big gate" was wrong twice.

## e) WHAT WE SHOULD IMPROVE (process, not bugs)

1. **Registry fan-out changes need a RENDERED-output proof step, not just eval.** The eval-time assertions prove invariants; they don't prove the rendered gatus endpoints/tiles/vhost-layers. A tiny `checks.*` derivation (or a script like the negative-test harness) that evals `config.services.gatus.settings.endpoints` + rendered tiles and asserts expectations would make the parity proof mechanical. This session's §b.2 row is the manual version; tooling it.
2. **Duplicate-tile class should be eval-detectable, not memory-detectable.** The PapDashboard duplicate-name-per-group crash was only known from the Immich/Forgejo incident note in papdashboard.nix. An eval-time check — built-in tile href/name matching a registry subdomain that also declares a homepage → WARNING naming both — would have made the migration mandatory-by-tooling instead of mandatory-by-archaeology. (The 2026-10-25 tile-coverage session already built the pattern for tile-coverage; this is the ownership twin.)
3. **Before ANY owner-side external-setup step, verify the consuming side's exact contract from source** (here: the redirect_uri construction). The owner's time is the scarcest resource; one source-grep would have de-risked their Google Cloud work. Generalizes: every "owner does X in an external console" step gets an agent-side contract-verification task FIRST.
4. **Read the repo's own lint/hook invocation BEFORE reaching for ad-hoc tool runs** — the hook file is the canonical spec for how the pinned linters are meant to run (this is the tool-level twin of "never run an ad-hoc formatter").
5. **Interrupt-heavy eval sessions**: the PSI/temp pre-flight worked (caught 85 °C, moderated scope) — keep doing it, and consider batching the cheap assertions first (targeted `config.assertions` eval) before any toplevel eval so a failure costs seconds, not minutes.
6. **Daemon shared-commit hygiene held** (stat-verified, no amend over foreign work) — the policy works; keep flagging foreign tree growth to the owner immediately as I did.

## f) NEXT TASKS (honest count 14 direct + 16 ideas = 30; not padded to 50 — the rest would be fiction)

**Direct follow-ups of THIS session (1–9 already harvested to both surfaces where actionable):**

| # | Task | Priority | Size | Type |
|---|------|----------|------|------|
| 1 | **Verify OpenSEO GSC redirect_uri construction from app source** (placeholder vs request-host; fix = BETTER_AUTH_URL env if needed) — BEFORE owner's Google setup | High | S | Feature |
| 2 | **Rendered-output parity proof** (gatus endpoints, tiles, vhost-layers, system-health, integration-registry check derivation) | High | M | Quality |
| 3 | **Flip GSC+AI flags → deploy → post-deploy verify** (after owner keys; PSI-calm window; anchor discipline; §16 + tile eyeball) | High | M | Feature |
| 4 | **Assess openseo D1 backup entry** (+ taskchampion sync data) — pocket-id sqlite pattern; adoption gated on §g.3 answer | Medium | S | Quality |
| 5 | **Full `nix flake check --no-build` at quiescence** — closes the rpi3-dns §f.8 row + exercises non-evo-x2 caddy contexts with my `options`-guarded entries | Medium | S | Quality |
| 6 | **Post-deploy tile eyeball** — 4 migrated tiles + dots (rides the existing watch row; listed here for completeness) | Medium | S | Verify |
| 7 | **Post-enable memory watch** — MemoryMax 2G vs actual openseo RSS once GSC sync + SAM run (the llama-chat 410M silent-throttle class; memory-watermark audit only checks MemoryHigh/MemoryMax coherence) | Medium | S | Watch |
| 8 | **Secrets-runbook key census after key entry** — verify openseo.yaml holds exactly 5 keys (dataforseo + 4), grep plaintext key names only | Low | S | Verify |
| 9 | **ai-meter openrouter re-add option** — once openrouter_api_key exists, the dropped ai-meter openrouter copy can return (recipe in ai-meter.md; owner decides) | Low | S | Decision |

**Ideas / improvements (not harvested — vague or owner-gated; would go to ROADMAP/library on request):**

| # | Idea | Note |
|---|------|------|
| 10 | Eval-time duplicate-tile-ownership lint (built-in tile vs registry homepage collision → warning) | §e.2; mechanical fix for a memory-only guard |
| 11 | Rendered-fan-out parity check derivation (mechanize §b.2) | §e.1 |
| 12 | Registry tile ordering support (explicit group position) | Only if owner cares about order (§g.2 answer) |
| 13 | DataForSEO quota/usage monitoring (app ships `scripts/dataforseo-account-usage.ts`; textfile-collector or gatus check for balance) | Prevents silent rank-tracking death on exhausted credits |
| 14 | GSC token-rotation hazard doc — stored GSC tokens are encrypted keyed by better_auth_secret; rotating that secret orphanizes every connected site | belongs in docs/agents/secrets.md + openseo.md |
| 15 | OpenSEO upstream watch row (v0.1.1 → next; pnpm-hash churn class on every bump) | upstream.md |
| 16 | SigNoz rule: openseo unit restart loop (gatus covers down; restart-thrash is a different signal) | monitoring.md |
| 17 | io-tier re-check for openseo after enable (GSC sync adds writes; audit already lists the unit) | storage.md |
| 18 | §16 monogram-tile severity decision (§g.1 of the 07:40 report — still open, owner-gated) | decision |
| 19 | Paperless blind-row → registry move (their own gated workstream) | services.md |
| 20 | Native-OIDC expansion for OpenSEO (2026-06-29 planning doc names it; Layer 1 someday) | ROADMAP material |
| 21 | Fleet-wide unharvested-reports sweep (128 WARN) | docs-health session |
| 22 | OpenSEO mainProgram/meta polish (won't-implement precedent exists for niche meta — only if something consumes it) | probably never |
| 23 | gatus RESP_TIME 2000ms on vite preview cold boot — first-boot false-alert risk; consider startUp grace or looser first-window | micro |
| 24 | VM-test leg proving the `options ? services.integration` guard on fixture-only hosts | test hygiene |
| 25 | Better AUTH story audit: enumerate all services with external-only auth (local_noauth class) and their auth-layer docs freshness | audit |

**Explicitly NOT queued (deliberately):** ROADMAP-grade native-OIDC and ordering machinery (vague/long-term per TODO system rules); the meta/polish nits (won't-implement precedent); anything the owner's §g answers below decide.

## g) QUESTIONS I CANNOT ANSWER MYSELF (3)

1. **Tile group order:** registry fan-out appends tiles to the END of their group — Pocket ID and DNS Blocker will move from the FRONT of Infrastructure to the end, and Taskwarrior/OpenSEO may swap relative order (attr-iteration). Acceptable, or should I build explicit ordering into the registry homepage schema (new machinery, M size)?
2. **OpenSEO backup:** `/var/lib/openseo/.wrangler` (rank/keyword history) is unbacked-up. If the D1 state is worth keeping, want the pocket-id-pattern daily sqlite backup entry (and at what retention), or is SEO history disposable by design? Same question for taskchampion sync data.
3. **If Google refuses the `home.lan` redirect URI even in Testing mode:** fall back to a real subdomain under `artmann.tech` (DNS + Caddy vHost + OAuth client + ALLOWED_HOST change — I can prep all of it), or abandon GSC integration? (DataForSEO keyword data would still work either way; GSC adds Search-Console-native perf data.)

---
*Verification evidence: evo-x2 toplevel drv `9jp62fdhr355hvffp3cin2d52f2z0r5w…` green 19:0x; negative-test-lints 5/5 PASS (case log `~/.cache/negative-test-lints/cases.log`); statix per-file errfmt clean ×7; `nix fmt --` 0 changed ×12; check-todo-system OK; check_local smoke of the RUNNING service pre-registered (3002/html 200, post-deploy-check.sh:448 unchanged and still valid).*
