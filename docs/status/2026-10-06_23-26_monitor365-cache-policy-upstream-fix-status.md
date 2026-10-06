# Status Report — monitor365 Cache Policy Upstream Fix (Caddy Caching Session)

**Date:** 2026-10-06 23:26 CEST
**Session scope:** Caddy caching question → upstream monitor365 fix → SystemNix deploy-gated removal queue
**Trigger:** User: "Monitor365 SPA entry-point override should be fixed upstream ~/projects/monitor365/!"
**Format note:** `.md` per explicit user instruction (skill default is HTML; override flagged in the closing message)

---

## TL;DR

The monitor365 server now owns its `/ui` cache policy upstream (entry points `no-cache, no-store, must-revalidate`, trunk-hashed assets `immutable`, everything else revalidates) — verified by 6 new tests + 610/610 server suite + clippy/fmt green. SystemNix still carries the Caddy `@noCache` override (correctly, per land-replacement-before-removing): it becomes redundant only after **push → lock bump → deploy**, and that removal chain is queued as `[blocked:deploy]`. Two coverage gaps were discovered and queued: the `/ds/` + `/ds-static/` surfaces get no upstream headers, and buildflow's format step did not apply rustfmt.

---

## a) FULLY DONE

| # | Work | Evidence |
| - | ---- | -------- |
| 1 | **Caddy caching-influence question answered** — 3 mechanisms: global set-if-absent `?Cache-Control "no-cache"` (`commonConfig`), monitor365 SPA entry-point force-override, `encode zstd gzip`; no server-side caching, no CDN | `modules/nixos/services/caddy.nix:85`, `:512-517`, `:87` |
| 2 | **Upstream cache policy implemented** — `wasm_spa_service()` wraps the trunk dist in a `Cache-Control` middleware (axum `from_fn` inside a `Router::fallback_service`, the shape that satisfies `nest_service`'s `Future: Send` bound); 3-tier policy table + fail-safe 16-hex hash detector (`_bg` wasm-bindgen suffix stripped) | `monitor365/crates/server/src/ui.rs` (whole file rewritten, ~85 lines) |
| 3 | **Policy proven by tests** — 6 new tests: entry-point policy on `/`, `/index.html`, `/bootstrap.js`; immutable on real dist hash names (`.js` + `.css`); unhashed vendor revalidates; **SPA fallback carries entry-point policy** (the MIME-bug class); trunk naming edge cases (15/17 hex, `leaflet-shim`, `chart.umd.min`, nohash); pure policy table | `monitor365/crates/server/src/tests/ui_cache_tests.rs`, 6/6 PASS |
| 4 | **Full server suite green** — 610/610 `monitor365-server` lib tests, no regressions | nextest, 10.7 s |
| 5 | **Lint/format gates green** — `cargo clippy -p monitor365-server --all-targets -- -D warnings` clean (after `needless_pass_by_value` → `&str` and `needless_borrow` fixes); `cargo fmt --all --check` clean (after manual `cargo fmt`; see §e.3) | clippy Finished, FMT_OK |
| 6 | **Repo-own invariants pass** — `check-agents-invariants.sh` ✅, `check-file-sizes.sh 500` ✅ (ui.rs ~85, tests ~110) | live run 23:2x |
| 7 | **CHANGELOG entry landed** under `[Unreleased]/Added` — describes the policy, the bug class, and the fail-safe direction; follows the repo's coverage conventions | `monitor365/CHANGELOG.md` |
| 8 | **SystemNix runbook "Caching" section** — documents the `?` default semantics, the monitor override's origin (`faae52ac`), and the redundancy-in-waiting state | `docs/services/caddy.md` § Caching |
| 9 | **Removal chain queued** — one `[blocked:deploy]` item with the full chain (push → `nix flake lock --update-input monitor365` → deploy → delete `@noCache` block → live header verify naming WHICH surface owns the header) | `docs/todo/services.md` tail |
| 10 | **Override annotated in place** — caddy.nix comment now says the upstream server sends identical headers and names the tracking doc, so the next reader doesn't "fix" the duplication blind | `modules/nixos/services/caddy.nix:512-520` |
| 11 | **Eval green** — `nix flake check --no-build`: all checks passed (expected aarch64-darwin skip only) | live run |
| 12 | **Daemon-race discipline held** — both daemon commits verified `git show --stat` clean: monitor365 `72efa84b4` = exactly my 2 files; SystemNix `2cb0279f` = exactly my 3 files (22 insertions); the one uncommitted residue (unused-`mut` fix) diff-reviewed before letting it ride | git evidence above |
| 13 | **SystemNix consumption mapped** — flake input `monitor365 = github:LarsArtmann/monitor365?ref=master` (`flake.nix:249-250`), so the fix flows via lock update after push; no path-override surprises | `SystemNix/flake.nix` |
| 14 | **Two direct §f follow-ups self-harvested at authoring time** (per TODO-system discipline): `/ds/` coverage gap → `docs/todo/upstream.md`, buildflow rustfmt gap → `docs/todo/pipeline.md`; `check-todo-system.sh` structure clean | both libraries, validator OK |

## b) PARTIALLY DONE

1. **The upstream fix is landed but UNPUSHED** (daemon HEAD `72efa84b4` + the `mut`-fix residue the daemon will sweep). Until push: SystemNix lock can't move, deploy can't happen, prod still serves via the Caddy override. Functionally correct today (override does the job for entry points), but the **immutable-asset win is not live** — hashed `/ui/*.js|.wasm|.css` still revalidate every load (they did before this session too; no regression, just unrealized improvement).
2. **"Server owns its cache policy" is only ~80% true upstream** — the middleware covers the `/ui` nest only. `/ds-static/app.css` + `/ds-static/data-star.js` (own routes, `datastar/templates.rs:33,37,380`) and every `/ds/` server-rendered page still send NO header and lean on the Caddy `?no-cache` default. Queued as `[ready]` in `docs/todo/upstream.md`. (Not broken — the proxy backstop is exactly what it's for — but the doctrine "servers own their headers" is not yet fleet-true for this repo.)
3. **Verification depth** — everything proven is eval/unit-level. Zero live-probe evidence exists: no `curl -sI https://monitor.home.lan/ui/bootstrap.js` baseline was captured BEFORE the change (missed opportunity; the queued post-deploy verify covers after, but the before/after pair would have proven the delta end-to-end). The Caddy-side claims rest on module reading, not live headers.
4. **buildflow format run** — 27 steps green BUT the Rust formatting diffs survived it (see §e.3), and the `buf` step failed on a pre-existing `catalog/` protobufjs issue (not mine, not triaged).

## c) NOT STARTED

1. **Push monitor365 master** — user/owner-gated (agent pushes forbidden). Note the repo also carries older daemon batches unpushed (`9cfaed9d6` swept 25 files) — push cadence is the owner's call.
2. **SystemNix flake.lock update** (`--update-input monitor365`) — blocked on 1.
3. **Deploy** (`nix run .#deploy`) — blocked on 2; also gated on the known deploy-pressure situation.
4. **Post-deploy live verification** — the queued recipe: `curl -sI .../ui/bootstrap.js` shows the upstream header surviving (not the Caddy one), hashed assets show `immutable`, hard-refresh kills the stale-bootstrap MIME class.
5. **Caddy `@noCache` block removal** — blocked on 4.
6. **`/ds/` + `/ds-static/` upstream header extension** — queued `[ready]`, not started (belongs to a monitor365 session).
7. **e2e smoke header assertions** — part of the same queued row, not started.
8. **`/ui` visual-baseline re-run** — headers don't change pixels, so deliberately skipped; a cheap sanity re-run is available if wanted (chromium-heavy, not done).

## d) TOTALLY FUCKED UP

Nothing destroyed state or shipped broken — but four honest misses, in descending severity:

1. **First implementation didn't compile: `impl Service` return hid the `Future: Send` proof** from `nest_service` (E0277). I wrapped a `ServiceBuilder` composition in an opaque `impl Service<...>` return, which axum's `nest_service` bound (`T::Future: Send + 'static`) can't see through. The axum-idiomatic shape — `Router::new().fallback_service(composed)` — should have been the first choice since it carries the concrete type. Cost: one full compile cycle (~2 min).
2. **The `_bg.wasm` naming was in my own test fixtures and I still missed it in v1** — I listed the real dist inventory (`monitor365-server-ui-9a3929bc7ab9dbe9_bg.wasm`) at research time, then wrote the hash regex without the wasm-bindgen suffix rule. The test caught it immediately (that's the system working), but the miss was avoidable: I had the data.
3. **Trusted `buildflow format` as "formatting done" without an immediate `--check`** — bundled the check into a later combined command and discovered rustfmt diffs had survived the 27-step run. The buildflow skill's own doctrine ("don't trust a green step that scanned zero files") applies: verify the surface you care about right after the gate runs.
4. **Two avoidable clippy round-trips** (`needless_pass_by_value` on `String` param, `unused_mut` on a by-value-consumed service) — both were visible at write time; they cost two extra gate cycles each.

## e) WHAT WE SHOULD IMPROVE

1. **Axum middleware composition reflex:** for `nest_service`, wrap in a `Router` (concrete type, bounds checkable at the call site), never return bare `impl Service` compositions. Candidate lesson for `references/lessons.md` (crush-config) — cross-project Rust pattern.
2. **Fixture-first test design:** when a filename convention drives logic, write the positive/negative test list FROM THE REAL INVENTORY before writing the matcher.
3. **buildflow rustfmt coverage gap (queued, `docs/todo/pipeline.md`):** `buildflow format` did not apply rustfmt in monitor365. Either a provider is missing/disabled for this repo shape (dprint.json present) or the step scanned nothing. Diagnose with `buildflow --dry-run --verbose`; fix upstream in BuildFlow if provider gap.
4. **Live-baseline before change:** capture prod headers (`curl -sI`) before designing a fix that replaces proxy behavior — the before/after pair is the cheapest possible end-to-end proof and was skipped.
5. **Runbook provenance at creation time:** the `@noCache` override existed since `faae52ac` with only an inline comment; the runbook (which now has § Caching) never recorded it until this session. Special-case vHost blocks should get a runbook sentence when they're born.
6. **Run the new repo's own gate suite when landing there** — I ran file-sizes + invariants only at report time; the session-end checklist (`scripts/session-end-checklist.sh`) was never run in monitor365.

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Brainstorm, not commitments — immediate chain first, then domain follow-ups, then ROADMAP fuel. Direct follow-ups already harvested to the todo libraries are marked 📌.

**The deploy chain (this fix goes live)**
1. 📌 Push monitor365 master (owner) — also sweeps the older unpushed daemon batches (`9cfaed9d6` et al.)
2. `nix flake lock --update-input monitor365` in SystemNix
3. `nix run .#deploy` (pressure-gated)
4. Live header verify: `/ui/bootstrap.js` carries the upstream header (naming which surface owns it), hashed `/ui/*` shows `immutable`
5. Delete the Caddy `@noCache` block + `nix flake check --no-build`
6. Capture the before/after header pair as evidence in the close-out (satisfies the verify-which-entity rule with real traffic)

**monitor365 upstream follow-ups**
7. 📌 Extend cache policy to `/ds/` pages + `/ds-static/app.css|data-star.js`
8. 📌 Add `Cache-Control` assertions to the e2e smoke suite (bootstrap.js + one hashed asset)
9. Add the same assertions to the NixOS VM test (`nix/tests/server.nix`) so deployment packaging is covered
10. Decide+document `manifest.json`/`favicon.svg` policy (currently revalidate; fine — write it down)
11. HEAD-request coverage for the policy tests
12. `FEATURES.md` row for the cache policy (honest inventory)
13. ADR-043 candidate: "servers own their cache headers; proxies only backstop"
14. Audit remaining LarsArtmann servers for the same class (server sends no cache headers, proxy patches per-vHost): browser-history, health-dashboard, CV, indexer-web
15. Verify Immich actually emits its `immutable` headers through Caddy (the `?` default's preservation path — never live-verified)
16. Research: does trunk pin a stable hash length (16) — if it ever changes, the fail-safe degrades to no-cache silently (acceptable, but worth a debug log line upstream)
17. ServeDir conditional-request audit: today 304s ride Last-Modified only; ETags would tighten revalidation cost (research)
18. `/swagger-ui` (debug builds) cache policy — cosmetic
19. Consider `debug` log line when a response gets no recognized class (drift alarm for new asset kinds)

**SystemNix side**
20. Post-deploy-check smoke step: entry-point `Cache-Control` presence for `monitor.home.lan` (pattern exists for auth vHosts)
21. Gatus regression tripwire: condition asserting `/ui/bootstrap.js` response carries `no-cache` (catches a future monitor365 regression from the proxy side)
22. Sweep remaining hand-written vHosts for per-vHost header patches that belong upstream (paperless `/admin` 403 is a security block, fine; anything else?)
23. Cross-link `docs/services/caddy.md` § Caching from the AGENTS.md knowledge-routing row (SSO/Caddy) so future sessions read it first
24. The 82 unharvested §f-bearing status reports (pre-existing backlog, flagged again by `check-todo-system.sh`) — docs-health HARVEST pass

**Tooling / process**
25. 📌 Diagnose buildflow format's rustfmt coverage gap (dry-run verbose; fix in BuildFlow repo or skip_step with rationale)
26. Triage the pre-existing buildflow `buf` failure (`catalog/` protobufjs descriptor warnings) — fix or `skip_steps` with rationale
27. Run monitor365's `scripts/session-end-checklist.sh` for the cache-policy session (repo's own gate)
28. Candidate lesson for crush-config `references/lessons.md`: "impl-Trait service returns hide Future: Send — wrap axum compositions in Router for nest_service" (needs commit in crush-config repo)
29. Daemon-commit hygiene on monitor365: several large heuristic batches unpushed — decide push cadence policy for fleet repos
30. Same proxy-defaults-lean class check for the CV site and dash (static vHosts get `?no-cache` — intended?)

**Adjacent (same vHost surface, could ride the same deploy)**
31. The already-queued "name the backend that compresses media" probe (Accept-Encoding direct-to-backend)
32. The already-queued Server-Timing `>+` semantics test + runbook recipe
33. The already-queued Caddy 2.11.4→2.11.7 encode re-verify watch item
34. Re-verify `?Cache-Control` interplay with `encode` once immutable assets land (immutable + compression = fine, but document)

**ROADMAP fuel (not actionable today)**
35. Fleet doctrine ADR: "origin servers own freshness; Caddy's `?` default exists only for backends that never learned" — write once, reference forever
36. monitor365: HTTP caching design for `/realtime` SSE (should stay uncacheable — assert, don't assume)
37. monitor365: consider `Cache-Control: private` on authenticated surfaces (tenant-scoped `/ds/` pages behind JWT — today they're only protected by the proxy default)
38. PWA/service-worker future: if it lands, the policy table needs a `sw.js` entry (update ADR then)
39. Trunk hashed-font option: hash `/ui/fonts/*` upstream someday → then immutable applies
40. Consider `stale-while-revalidate` on the immutable class for instant SPA loads (browser support is good; measure first)
41. monitor365 release/tag after push (CI dark — manual tag per the billing TODO)
42. Split-brain guard: a test asserting the Caddy comment and the upstream policy stay in sync is impossible cross-repo — instead, the removal item (§f.5) IS the guard; don't build more
43. Post-removal: delete the caddy.nix redundancy comment in the same commit as the block (one artifact, not two)
44. Consider `Clear-Site-Data` debugging header on a debug-only route (MIME-class incident response tooling; probably YAGNI)
45. Document the UI_DIST_PATH env contract in the runbook/docs (today it's discoverable only from source)
46. Add `is_content_hashed` cases for query-string-bearing paths (`?v=`) — today the middleware sees stripped paths, but a regression test would pin it
47. Evaluate `Vary: Accept-Encoding` presence on encoded responses (correctness hygiene, Caddy's encode sets it — verify)
48. SigNoz: alert if `/ui` 404 rate spikes (the SPA-fallback masking class has an observability angle: fallback hits are 200s, real misses invisible)
49. monitor365 TODO_LIST: the "quiet-day heartbeat" browser-history-style items — unrelated to this session, already tracked; skip
50. Retro item: the session took ~2.5h wall for a ~150-line change — most of it gate cycles; the compile-fail miss (§d.1) and fmt churn (§e.3) are the two cuttable loops next time

*(Items without 📌 are brainstorm; harvest routing happens per docs-health rules — the two direct gaps are already in their libraries.)*

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Push cadence for monitor365:** should master go out now (this fix + the older 25-file daemon batches ride together), or do you want to batch it with the CI-re-enable work? The SystemNix chain (lock bump → deploy → Caddy override removal) is fully blocked on this.
2. **Doctrine scope:** is "servers own their cache headers, Caddy only backstops" meant fleet-wide (browser-history, health-dashboard, CV, indexer-web all lean on the `?no-cache` default today), or is monitor365 the only surface where immutable assets matter enough to bother?
3. **`/ds/` coverage intent:** should the server-rendered `/ds/` pages get upstream `no-store` headers too (they're tenant-scoped HTML behind JWT — arguably `private, no-store` is more correct than the proxy's blanket `no-cache`), or is the proxy backstop the accepted permanent state for that surface?

---

**Evidence appendix:** monitor365 daemon HEAD `72efa84b4` (ui.rs + ui_cache_tests.rs; final `mut` fix uncommitted residue, diff-reviewed); SystemNix daemon HEAD `2cb0279f` (caddy.md +18, todo/services.md +1, caddy.nix +3); follow-up rows appended to `docs/todo/upstream.md` + `docs/todo/pipeline.md`; validators: `check-todo-system.sh` OK, `nix flake check --no-build` OK, monitor365 invariants + file-sizes OK, nextest 610/610, clippy/fmt clean.
