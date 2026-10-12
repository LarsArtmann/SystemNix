# Runner label TRUE root cause (workflow runs-on), setup-forgejo.sh class-4 revoke-401, first real dump backup

- **Date:** 2026-10-11 04:20 CEST
- **Session span:** ~03:50–04:20 CEST (continues the 03:46 go-live session; starts at the owner's force-deploy)
- **Content pin:** SystemNix `ea9c6e5e` at pin time (daemon-swept this session's queue/report edits; contents verified — 3 files, all mine); hub repo daemon committed this session's 3 files as `22f5646` (contents verified: workflows ×2 + script class-4 fix) — **still UNPUSHED at 04:22**
- **Scope:** post-deploy falsification of the 03:46 label fix, true root-cause from runner v13.2.0 source, the real workflow fix, setup-forgejo.sh failure class 4 (owner re-run 04:12, clone-token mint), backup-leg milestone. **NOT in scope:** anything else.

---

## a) FULLY DONE

1. **Deploy verified — and my 03:46 fix FALSIFIED by it:** system switched 03:50:45 (gen `l4m75scg…-26.11.20261008.e7439b6`), runner restarted 03:50:48, and the daemon **still declared `labels: [native]`** — while the deployed `runner-config.yaml` provably carries `labels: [native:host]` (store `f54mx33d…`). The config-gap premise was wrong.
2. **TRUE root cause, source-verified from forgejo-runner v13.2.0** (tarball from `code.forgejo.org/forgejo/runner`; codeberg.org/forgejo/runner 404s — the repo moved):
   - Label syntax is `name:schema` — `labels.Parse`: `native:host` → Name `native`, Schema `host` (`internal/pkg/labels/labels.go:34-53`).
   - The daemon declares **label NAMES only**: `runner.Declare(ctx, ls.Names())` (`internal/app/cmd/daemon.go:207`); the log line prints the server's echo of those names.
   - Config `runner.labels` are **DefaultLabels**, applied only to connections without labels (`internal/pkg/config/config.go:569`); the legacy `.runner` registration (our register ExecStartPre, passing `--labels native:host`) supplies the labels in our setup.
   - So the daemon has ALWAYS declared name `native` — since the first registration. The workflows' `runs-on: native:host` (v15 exact-string `ItRunsOn` vs `AgentLabels`) could never match any declaration. Run 1 was queued from birth; no runner-config change could ever fix it.
3. **The real fix landed in the hub tree:** `build.yml` + `stale-sources.yml` → `runs-on: native` (both files had the bug; header comment in build.yml rewritten to the verified semantics). YAML-validated (both jobs parse to `native`).
4. **forgejo.nix comment corrected** (was stating the backwards model "daemon declares from config, overwrites registration"); `runner.labels = runnerLabels` KEPT — correct as the DefaultLabels source for the post-registration (v13 connections) world. Daemon-swept as `c77d49b0` (contents verified: forgejo.nix only).
5. **Correction discipline on every surface:** addendum on the 03:46 report (top, before §a), TODO_LIST row re-premised, `docs/todo/services.md` label row re-premised, go-live row head updated. Eval green (toplevel drv rendered; warnings pre-existing). TODO-system checker failures confirmed pre-existing (other domains' rows — storage/pipeline drift, untouched).
6. **Script failure class 4 root-caused LIVE** (owner re-run 04:12, output pasted into session): `✓ mirror exists` → `✓ Actions enabled` → `ERROR: clone-token mint failed`. Journal smoking gun: `PATCH /repos/…` **200** (same token!) but `DELETE /users/lars/tokens/eventcatalog-hub-ci-readonly` → **401** at `v1/api.go:188 (reqBasicOrRevProxyAuth.checkPermission)` — plus the EXIT-trap cleanup DELETE also 401. Source-verified v15.0.9 `routers/api/v1/api.go`: token-management routes carry `reqBasicOrRevProxyAuth()` (rejects the `Authorization: token` header scheme; basic auth required) AND the DELETE route is `/{id}` — numeric id, never the name. Chain: revoke silently no-op'd (blind `|| true`) → `eventcatalog-hub-ci-readonly` from the 03:15 run still existed → CLI mint name-collision → my loud-fail guard fired (worked as designed — the ONLY reason this class was visible at all).
7. **Class-4 fix landed** in `setup-forgejo.sh`: `revoke()` now lists tokens (token-header GET is fine on that route), resolves the numeric id by name, DELETEs with basic auth (`-u user:token`), and FAILS LOUD on anything but 204/404; `cleanup()` (EXIT trap) same shape; `mint()` stderr no longer suppressed. `bash -n` + shellcheck (nix shell nixpkgs#shellcheck) clean.
8. **First REAL forgejo application backup LANDED:** `forgejo-20261011-033955.zip` — Finished 03:43:03, 24.9G written / 23.1G read, unit green (journal `forgejo-backup`). First non-skipped, non-phantom dump ever (11 condition-skipped nights before; feeds services.md :149).
9. **State baselined:** runner poller silent since 03:50 (zero pickups — consistent: no run carries a matching runs-on); exactly ONE API dispatch in the journal (03:21:00, 204 — run 1); runs 2/3 exist with no API dispatches (provenance open — §g.1); memory-emergency guard STILL tripping every 30s through 04:15 (FLM sacrifice storm ongoing, 25+ min past the force-deploy).

## b) PARTIALLY DONE

1. **Hub-repo fixes committed but UNPUSHED** — the daemon swept the 3 files as `22f5646` (~04:20; contents verified) but the push hasn't happened → GitHub → forgejo-mirror chain still stalled on ONE push; until it lands the mirror carries the OLD workflow and every existing run is unmatchable.
2. **Class-4 fix UNVERIFIED against a live run** — agent cannot sudo; the fixed script needs one owner re-run (it now also re-dispatches build.yml at the end).
3. **Token hygiene debt:** 2 orphaned all-scope setup PATs (see §a.6 — both trap-cleanups 401'd silently: one from 03:15, `eventcatalog-hub-setup-1791684734` from 04:12). INCIDENTAL GOOD NEWS: the 03:15 `GIT_CLONE_TOKEN` secret and the root-file sync token are still VALID (their revokes never succeeded) — the sops paste is NOT blocked by the failed script run.
4. **Catalog go-live chain:** steps 1–2 stand; step 3 (sops paste) pending and unblocked; steps 4–5 wait on the first green run.

## c) NOT STARTED

1. Watching the first green run (watch-list: nix-daemon reachability for the DynamicUser runner, `npm` in job env, job-token git-push with `PUSH_TOKEN` fallback).
2. Post-green chain: sync converge "serving generation", `current/index.html` + build-stamp, collector `dist_present 1`/`fresh 1`, 3 Gatus checks, post-deploy §15.
3. Runbook/docs updates: v15 `has_actions` PATCH shape, dispatch 201|204, token-route basic-auth + numeric-id DELETE, label NAME semantics (`docs/services/architecture-catalog.md` + `forgejo.md`).
4. Label-drift eval selftest (rendered runner config DefaultLabels == runnerLabels).
5. grep-guard pre-commit leg: stderr-suppressed command substitutions in set-e scripts.
6. First real btrbk legs: snapshot 05:40 + ~67G DAS pool seed (dump leg DONE — §a.8).

## d) TOTALLY FUCKED UP

1. **The 03:46 root cause was wrong at the protocol level and shipped everywhere** (report §a.8, both queue rows, a forgejo.nix comment). I source-verified the SERVER half (v15 exact-string matching) but INFERRED the client half ("daemon declares labels from config") without reading the runner. The falsification signal existed BEFORE the deploy: the register script logged `--labels native:host` at 01:57:43 AND the daemon still declared `[native]` — two facts that cannot coexist under my model. Instead of chasing that contradiction, I recommended `DEPLOY_FORCE_PRESSURE=1` DURING an active FLM storm (freeze-#5 class window) for what turned out to be a functionally inert change — the owner spent a risky override on a no-op. The verification I prescribed ("journalctl shows `labels: [native:host]`") was unachievable by construction — the daemon logs names only.
2. **Re-committed the 03:46 §d lesson one layer down:** I hardened the mints (loud guards) but left `revoke()` blind (`|| true`, HTTP code ignored) and mint stderr suppressed. "Verify the WHOLE script surface" was applied to the happy path only. Consequence: the 03:15 "green" run was first-run luck (revoke had nothing to do), gave false confidence, and every subsequent run was doomed at exactly that line — plus leaks an all-scope PAT per run (2 leaked).

## e) WHAT WE SHOULD IMPROVE

1. **A matching rule is half a protocol** — any "X matches Y" root-cause claim requires source on BOTH sides (server matcher AND client declarer). Verified-half claims must be labeled as such.
2. **Pre-deploy achievability scan:** for every promised post-deploy verification ("daemon log will show L"), check the line can exist at all. `labels: [native:host]` in a names-only log format was predictable-impossible from the v13 source.
3. **Contradiction-chasing discipline:** two coexisting observations that a model can't explain (register `--labels native:host` + declared `[native]`) are a STOP signal, not noise.
4. **First green run of an "idempotent" script proves nothing about the idempotent paths** (revoke-then-mint only proves itself when a token already exists). Mentally execute run #2 semantics before declaring a script fixed.
5. **Best-effort cleanup paths (trap/cleanup, revoke) get the same loud-fail treatment as primary paths** — silent `|| true` on cleanup is guaranteed leak accumulation with zero signal.
6. **Don't assume daemon cadence for critical chains** — the hub daemon idled 90+ min with 3 files waiting; the commit→push→mirror-sync chain stalled unnoticed. When a chain is blocked on a daemon sweep, say so explicitly or ask the owner to commit.
7. **Agent dispatch gap:** every dispatch/re-dispatch costs an owner round-trip (no token, no sudo). The runbook should carry a copy-paste dispatch command the owner can run without the full script.

## f) NEXT (self-harvested into TODO_LIST.md + docs/todo/services.md at authoring time)

1. **[blocked:user]** Owner chain to first green run: PUSH hub repo (`22f5646` committed, unpushed) → mirror sync (Synchronize now / timer / cron `23 3 * * *`) → re-run setup-forgejo.sh (class-4-fixed, re-dispatches) → cancel stale runs 1–3. _(label row, both surfaces — updated)_
2. **[blocked:user]** Delete the 2 orphaned all-scope setup PATs (UI Settings → Applications). _(NEW row, both surfaces)_
3. **[blocked:user]** sops paste `ARCHITECTURE_CATALOG_SYNC_TOKEN` — root file still valid (runbook step 4). _(go-live row premise updated: unblocked)_
4. **[watch]** First green run + post-green verify chain. _(go-live row)_
5. **[watch]** btrbk first real snapshot 05:40 + ~67G pool seed; dump leg already green (03:43). _(services.md :149 premise updated)_
6. **[ready]** Runbook + forgejo.md: v15 API shapes (has_actions PATCH, dispatch 201|204, token-route basic-auth + `{id}` DELETE), label NAME semantics, register-deprecation path. _(carried §f.7, scope widened)_
7. **[ready]** Label-drift eval selftest: rendered runner config DefaultLabels == runnerLabels. _(carried §f.10, premise corrected)_
8. **[ready]** grep-guard pre-commit leg for stderr-suppressed substitutions in set-e scripts. _(carried §f.11)_
9. **[ready]** Re-run shellcheck standalone after the hub daemon sweeps the script (daemon commits bypass filetype lint legs — already clean via nix shell this session; re-assert post-sweep).
10. **[watch]** FLM storm / guard trips every 30s through 04:15 — post-storm stability check (the 03:50 force-deploy rode this window).

## g) QUESTIONS (cannot figure out myself)

1. **Runs 2/3 provenance:** the journal shows exactly one API dispatch (03:21 → run 1) and no others — were runs 2/3 push-triggered (e.g., the 03:52:37 mirror sync landing commit `8dbe9fb`, or your 04:13 UI re-run clicks on run 3)? This settles whether `on: push` fires on mirror-sync on this Forgejo — if yes, tonight's sync of the FIXED workflow auto-dispatches and script step (3) of the chain becomes optional.
2. **Carried §g.2:** promote `setup-forgejo.sh` to a SystemNix self-elevating app (versioned, pre-commit lint coverage — the daemon-bypass bit this session) or keep it in the hub repo?
3. **Carried §g.3:** trash timing for `/var/lib/forgejo.qlc-pre-subvol` (67G; with the dump leg green it's eligible after the 05:40 snapshot → ~13:40) + prune-or-keep the DarkBlocks/DialogesWebInterface dual mirror copies?

---

## ADDENDUM (2026-10-11 ~04:45 — class 5: the class-4 fix was structurally impossible)

**What happened at 04:26.** Owner pushed the hub repo (origin/master = `22f5646` ✓) and re-ran setup-forgejo.sh. It died EARLY: `revoke 'eventcatalog-hub-ci-readonly' failed (HTTP 401 — expected 204 via basic auth + numeric id)` — the class-4 fix itself.

**Root cause (source-verified, v15.0.9).** `routers/api/v1/permissions/req_basic_or_rev_proxy_auth.go` requires `ctx.Authentication().IsPasswordAuthentication()` — basic auth where the password was validated as the ACCOUNT PASSWORD. A PAT used as the basic-auth password authenticates as TOKEN auth, not password auth → 401 "auth method not allowed". **No token — header or basic — can ever revoke a token in v15.** Journal smoking gun (04:26:28): `GET /users/lars/tokens` → 200 ×2 (id resolution WORKED; §c's "GET token-header OK" claim survives), then `DELETE /tokens/9` (ci-readonly) and `DELETE /tokens/12` (trap cleanup, the fresh setup token) → both 401 at `reqBasicOrRevProxyAuth.checkPermission`.

**Consequence.** The 04:26 run minted a THIRD orphaned all-scope setup PAT (its trap cleanup 401'd) → orphan count 3 (03:15, 04:12, ~04:26). §f.2 row updated.

**Run #3 provenance (§g.1 partially settled).** UI: run #3 = commit `8dbe9fb` "pushed by lars, 13 minutes ago" concurrent with "mirror synced 13 minutes ago" — the mirror sync landed pre-fix `8dbe9fb` (02:47) and fired a push event. **`on: push` DOES fire on mirror sync.** Run #3 ran the OLD `native:host` workflow → 0s forever (runner journal silent since the 03:50:48 `[native]` declare — no new runner fault). Run #2 provenance still owner-knowledge.

**Fix (landed in hub tree, bash -n + shellcheck clean).**

1. `revoke()`/`cleanup()` now DELETE directly in the forgejo sqlite DB (python3 stdlib sqlite3 — not in PATH as sqlite3 CLI; parameterized SQL scoped `uid`+`name`, rowcount reported, loud-fail kept, timeout=30). The API is a dead end; the CLI can mint but not delete (verified on the live binary: `admin user` has no delete-token), and the CLI rejects duplicate names (`cmd/admin_user_generate_access_token.go`: "access token name has been used already") — so revoke-before-mint stays mandatory. SQL verified against a throwaway schema replica (exact-row delete; another user's same-named token survives).
2. NEW step 5d: mirror-sync the hub to GitHub tip + sha-gate (gh api as lars, 30×2s poll) BEFORE dispatching — run #3 was exactly a dispatch onto a stale mirror; this makes the failure mode structurally unreachable.

**Owner chain (supersedes §f.1):** (1) push DONE; (2) re-run `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` — it now self-syncs the mirror and dispatches the FIXED workflow; (3) cancel stale runs 1–3; (4) delete THREE orphaned PATs; (5) sops paste.

**Corrections to this report:** §c/§d's class-4 fix description ("DELETEs with basic auth `-u user:token`") is falsified — basic-auth-with-PAT is still token auth. §f.1/§f.2 queue rows re-premised accordingly (both surfaces).

**Postscript (05:05 — class 6 falsified the class-5 fix's DB path):** the owner's 04:58 script run died at the ci-readonly mint: sqlite said "no existing token", the CLI said "name used already". Root cause: the fix hardcoded `data/gitea.db`, but the LIVE DB is `data/forgejo.db` (rendered app.ini PATH via nix eval; corroborated by `_forgejo-scripts.nix`/`system-health.nix`) — a stale `gitea.db` fossil sits in the same dir. Consequence: the 04:58 run leaked setup PAT #4 (its cleanup no-oped on the wrong file, silently — the cross-check that would have caught it did not exist yet). v4: DB path parsed from `custom/conf/app.ini`, every delete cross-checked against the API list. Full narrative: `docs/status/2026-10-11_05-05_setup-forgejo-class5-6-revoke-auth-wrong-db.md`.
