# setup-forgejo.sh classes 5+6: token-revoke auth dead end + wrong DB file — fixed, awaiting owner re-run

Date: 2026-10-11 04:30–05:05 CEST. Continuation of the eventcatalog-hub CI chain (prior: `2026-10-11_04-20_*` + addendum + postscript). Session trigger: the owner's 04:26 script run died at `revoke 'eventcatalog-hub-ci-readonly' failed (HTTP 401 — expected 204 via basic auth + numeric id)` — my own class-4 fix failing.

## a) FULLY DONE

1. **Class-5 root cause (source + journal verified):** v15.0.9 `routers/api/v1/permissions/req_basic_or_rev_proxy_auth.go` requires `ctx.Authentication().IsPasswordAuthentication()` — a PAT authenticates as TOKEN auth whether sent as header OR as the basic-auth password → 401 "auth method not allowed". **No token can ever revoke a token in v15.** Journal smoking gun 04:26:28: `GET /users/lars/tokens` 200 ×2 (id resolution worked — the 04-20 report's "GET token-header OK" claim survives), `DELETE /tokens/9` (ci-readonly) + `/tokens/12` (trap cleanup) both 401 at `reqBasicOrRevProxyAuth.checkPermission`. The class-4 fix was structurally impossible.
2. **CLI facts verified (live binary + source):** `forgejo admin user` has NO token-delete (create/list/change-password/delete/generate-access-token/must-change-password/reset-mfa); `generate-access-token` rejects duplicate names (`cmd/admin_user_generate_access_token.go`: "access token name has been used already") → revoke-before-mint is mandatory → the sqlite DB is the only leak-free revoke primitive.
3. **Script v3 (04:37, daemon-swept `18058a7`, owner-pushed — GitHub master = `18058a7` verified via `gh api`):** sqlite-backed `revoke()`/`cleanup()` (python3 stdlib, parameterized, scoped `uid`+`name`, rowcount reported, loud-fail), `api_body()` helper, NEW step 5d: hub mirror-sync to GitHub tip + sha-gate (gh api as lars, 30×2s poll) before dispatch — run #3 was exactly a dispatch onto the stale mirror. bash -n + shellcheck clean; DELETE SQL replica-tested (exact-row delete, another user's same-named token survives).
4. **Run #3 provenance settled (owner question §g.1 from 04-20):** run #3 = commit `8dbe9fb` "pushed by lars" concurrent with the mirror sync 13 min prior — **`on: push` DOES fire on mirror sync**; it ran the PRE-fix `native:host` workflow → 0s forever. Runner healthy: journal shows `[native]` declare 03:50:48 + poller up, zero pickups = label-stuck, no new runner fault. Run #2 provenance still owner-knowledge.
5. **Class-6 root cause (05:00, rendered-config verified):** the 04:58 owner run died at the ci-readonly mint — sqlite "no existing token" vs CLI "name used already". Two different databases: I hardcoded `data/gitea.db`; the LIVE DB is **`data/forgejo.db`** (`nix eval .#…settings.database` → `PATH: /var/lib/forgejo/data/forgejo.db`; corroborated by `_forgejo-scripts.nix` (`FORGEJO_DB` default), `system-health.nix` (`nPath`), monitoring runbook). A stale `gitea.db` fossil sits in the same dir with real tables — my DELETE no-oped against it, and the trap cleanup silently no-oped too → **setup PAT #4 leaked (04:58)**.
6. **Script v4 (05:03, this tree):** DB path PARSED from `$WORK_DIR/custom/conf/app.ini` `[database] PATH` (relative → resolved against WORK_DIR; fallback convention `data/forgejo.db`; `-f` gate with loud error) — never hardcoded again; **API cross-check after every delete**: revoke aborts loudly if the API still lists the token (wrong-file deletes can never pass silently); cleanup cross-check is non-fatal but names the leftover; `SETUP_NAME`-unset guard in the trap. bash -n + shellcheck clean; awk parser fixture-tested (absolute + relative PATH, section-scoped — a `[log] PATH` does not match).
7. **Surfaces corrected (correction discipline):** 04-20 report got the class-5 ADDENDUM + class-6 postscript; TODO_LIST label row + orphan row re-premised (twice — once per class); services.md label row + orphan row + go-live row head; citation globs (`2026-10-11_04-20_*`) replaced with exact filenames → the 04-20 and 03-46 reports now count as harvested (unharvested backlog 103 → 101; remainder pre-existing, other domains).

## b) PARTIALLY DONE

1. **Owner chain to first green run** — push DONE (GitHub master = `18058a7` carries the runs-on fix; the v4 script still needs a daemon sweep + push). Script re-run attempted twice by owner (04:26 → class 5, 04:58 → class 6), both failed pre-dispatch — no new runs created, no state besides PAT #4.
2. **Script v4 verification** — statically verified (syntax, shellcheck, awk/SQL fixtures) but NOT run against live forgejo (agent has no sudo/token); the sha-gate's gh-api-as-root-via-runuser path relies on the proven `runuser -u lars -- gh auth token` precedent; python3+stdlib confirmed on PATH as the owner shell sees it.
3. **`on: push` auto-dispatch consequence** — tonight's/next mirror sync of the FIXED workflow will auto-dispatch build.yml (push event), possibly BEFORE the owner re-runs the script. That run should be picked up (runs-on: native = declared name). Verify pickup then; the script's own dispatch becomes the second data point.

## c) NOT STARTED

1. First green CI run + `dist` branch + the watch-list (nix-daemon reachability for the DynamicUser runner, npm in job env, job-token git-push with PUSH_TOKEN fallback).
2. Post-green chain: sync converge "serving generation", `current/index.html` + build-stamp, collector `dist_present 1`/`fresh 1`, 3 Gatus checks, post-deploy §15.
3. Owner steps: cancel stale runs 1–3, delete the 4 orphaned all-scope setup PATs (UI), sops-paste `ARCHITECTURE_CATALOG_SYNC_TOKEN` (03:15 root-file token still valid).
4. Carried §f items from 04-20: runbook capture (v15 token-API auth semantics + label semantics — now also the forgejo.db/gitea.db fossil + revoke-via-sqlite pattern), label-drift eval selftest, stderr-suppression grep-guard pre-commit leg, script promotion decision, post-storm memory-guard check, btrbk 05:40 snapshot/pool-seed watch.

## d) TOTALLY FUCKED UP

1. **Class 4 (prior session, mine):** verified the ROUTE (`api.go` combo middleware) but never followed into the middleware package — shipped a fix whose auth mechanism I had not source-verified. Exactly the "half-verified protocol claim" pattern this repo keeps flagging.
2. **Class 6 (this session, mine):** I hardcoded `data/gitea.db` from Gitea ecosystem convention — while THREE in-repo references (`_forgejo-scripts.nix`, `system-health.nix`, monitoring-runbook) and one `nix eval` away from the rendered app.ini all said `forgejo.db`. I verified the table/columns from source but NOT the file path. Cost: owner run #4 wasted, setup PAT #4 leaked, and — worse — my class-5 "loud-fail" cleanup silently no-oped (rowcount 0 on a stale file reads as success), proving that without the API cross-check, "loud" only covered python errors, not wrong-target writes.
3. **Minor:** my first reply this session asserted run #3 "ran on the PRE-fix workflow" from push-state inference before checking commit dates (it held up, but the git-dates check should have come first); and the initial owner-chain summary said "awaiting PUSH only" off stale session state (the daemon had since committed `18058a7`).

## e) WHAT WE SHOULD IMPROVE

1. **Never hardcode infrastructure state in owner-run scripts — resolve from the rendered/live source** (app.ini, systemd unit, nix eval). Every hardcode is a stale-convention landmine (gitea.db, FORGEJO_BIN before it).
2. **Write-back verification for destructive/administrative writes:** a DELETE that "succeeds" must be verified against the service's OWN view (the API cross-check pattern now in the script). Silent 0-row success is indistinguishable from wrong target.
3. **Self-diagnosing scripts:** the script cannot be agent-tested (no sudo) — so each new failure class must make the NEXT failure of its kind self-identifying in the owner's terminal output (this session added: api-vs-db cross-check, sha-gate with both shas printed, DB-path parse error naming the app.ini).
4. **Follow the middleware, not the route:** when source-verifying an API contract, verify the full chain (route → permission middleware → auth method semantics), not the route line.
5. **Fossils that shadow live state get trashed on discovery** (queued: the gitea.db relic inside the LIVE subvol's data dir).
6. **The harvest checker's literal-filename match** silently flagged glob-cited reports as unharvested — citations should use exact filenames OR the checker should accept basename-prefix globs (scanner-side fix per lint doctrine; 101-report pre-existing backlog).
7. **Fixture coverage for setup-forgejo.sh** — the repo already has the `forgejo-scripts-fixture` stubbed-harness pattern; this script is now on failure class 6 and each class costs an owner round-trip. Promotion to SystemNix (carried decision) would buy it lint + fixture legs.

## f) NEXT (self-harvested into TODO_LIST.md + docs/todo/services.md)

1. **[blocked:user]** Owner chain: push hub after the daemon sweeps v4 → re-run `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` → cancel stale runs 1–3. *(label row updated)*
2. **[blocked:user]** Delete the 4 orphaned all-scope setup PATs. *(orphan row updated)*
3. **[blocked:user]** Trash the stale `/var/lib/forgejo/data/gitea.db` fossil (sudo confirm unreferenced first). *(NEW row)*
4. **[blocked:user]** sops paste `ARCHITECTURE_CATALOG_SYNC_TOKEN` (root file still valid). *(go-live row)*
5. **[watch]** Verify runner pickup on the first post-sync push-event run (auto-dispatch) or the script's dispatch; then green + `dist` + watch-list. *(go-live row)*
6. **[watch]** Post-green chain: sync converge, collector, 3 Gatus checks, post-deploy §15. *(go-live row)*
7. **[ready]** Runbook `docs/services/forgejo.md` + architecture-catalog runbook: v15 token-API auth semantics (`IsPasswordAuthentication`), revoke-via-sqlite pattern + API cross-check, forgejo.db-vs-gitea.db fossil, label name semantics, `on: push`-fires-on-mirror-sync. *(carried, scope widened ×2)*
8. **[ready]** Label-drift eval selftest (carried) / grep-guard pre-commit leg (carried).
9. **[decision]** Promote setup-forgejo.sh to a SystemNix app with fixture coverage vs keep in hub (carried §g.2).
10. **[watch]** btrbk first snapshot + ~67G pool seed (05:40 window) — update services.md :149 premise when verified (carried §f.5).
11. **[ready]** Harvest checker: accept basename-prefix globs or emit an authoring-time hint (101-report backlog gate; scanner-side fix). *(NEW — pipeline domain)*
12. **[watch]** Re-run shellcheck standalone after the daemon sweeps v4 (daemon commits bypass filetype lint legs — clean pre-sweep this session).

## g) QUESTIONS (cannot figure out myself)

1. **Run #2 provenance (carried):** build.yml #2 (42 min before the UI view, workflow_dispatch on `7d37b9c6eb`, actor lars) — your manual UI re-dispatch? Settles whether any dispatch path exists besides script+UI+push.
2. **Carried §g.2:** promote `setup-forgejo.sh` into SystemNix (versioned, pre-commit lint + fixture legs — it is now on failure class 6, one owner round-trip per class) or keep it in the hub repo?
3. **Carried §g.3:** trash timing for `/var/lib/forgejo.qlc-pre-subvol` (67G; eligible after the 05:40 btrbk snapshot → ~13:40) and prune-or-keep the DarkBlocks/DialogesWebInterface dual mirror copies?

*Session closed in WAITING FOR INSTRUCTIONS state; owner chain documented in TODO_LIST.md :315-:*.*
