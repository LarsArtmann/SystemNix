# Session status: /admin/ 403 fix (SUPER_ADMIN_EMAILS) + OAuth/OIDC utilization deep-dive

**Scope of this report — what it VERIFIED and how:** unit-env absence via the deployed unit file (`readlink -f /etc/systemd/system/browser-history.service` + grep); code paths at BOTH deployed `9daaa80` and lock `98cfec0` via `git show <rev>:<path>`; owner email present in the live read model via the pool-backup copy (`users_view`, 9 rows, `lars@larsartmann.cloud`); zero super-admin journal lines over 7 days; live `/admin/` traffic at 00:31 (assets 200, page 403, user `01M000JA6…` — the data owner) via `journalctl`; OAuth audit claims via 6/6 replayed verify commands (appendix of the deep-dive). **What it did NOT verify:** the fix is NOT live (deploy blocked — see b1); the runtime grant never executed; the ReadModel→FindByEmail keep-first link under `USE_SQLITE_READ_MODEL=true` (premise risk, flagged); the deep-dive was never rendered in a browser (no headless browser available — screenshot skipped honestly); the pool-backup permission drift on the Nov 5 file was observed but not root-caused (root-owned dir, agent is permission-blind on the new file).

Session arc: (1) diagnose `https://history.home.lan/admin/` → 403 "Your role does not allow this action"; (2) fix + docs; (3) owner question "Do we leverage OAuth to the max?" → full library-deep-dive of `cqrs-htmx/usermgmt/oauth2` as consumed by browser-history.

---

## a) FULLY DONE

1. **Admin-403 root cause, multi-source verified:** the adminui panel admits only `super_admin`/`admin` in the global domain; the only grant path is the startup reconcile (`api/admin_panel.go` `reconcileSuperAdmins`: `SUPER_ADMIN_EMAILS` → FindByEmail → in-memory casbin, re-applied after every projection drain); the deployed unit carries NO such env (env-only upstream — `api/config.go` parses it, `nix/server-module.nix` never wires it) → empty list = silent no-op = 403 for everyone. Journal confirmed zero grant lines in 7 days while the owner's session hit `/admin/-/` assets 200 at 00:31.
2. **Fix landed in tree:** `modules/nixos/services/browser-history.nix` unit env `SUPER_ADMIN_EMAILS=${config.services.browser-history-agent.tokenUserEmail}` (owner identity single-sourced, machineId doctrine; `lib.optionals`-guarded so null stays safe). Format canonical (`nix fmt -- <path>`: 0 changed). Rode daemon commit `5bd7e63cb` (+14 lines on the module).
3. **Effectivity analysis:** deployed binary `9daaa80` and lock `98cfec0` BOTH parse the env (verified in their `api/config.go` blobs); lock is a descendant of deployed, so the next successful deploy ships a binary that understands the var.
4. **Docs trail:** runbook `/admin/` gate bullet (with the post-deploy verification recipe), upstream row + paired queue one-liner for the missing `superAdminEmails` module option; `scripts/check-todo-system.sh`: "TODO queue/library structure clean".
5. **OAuth/OIDC deep-dive (owner question), full skill process:** `docs/research/2026-11-06_oauth2-oidc-deep-dive.html` — 25 capabilities inventoried, 4 N/A with reasons, score 57/100 (moderate): 11 fully leveraged, 2 partial, 7 missed, 1 misused. Headline findings (all evidence-cited in the report):
   - **Misused:** browser-history is the ONLY fleet OIDC client without `pkceEnabled = true` (8 siblings set it; paperless even eval-asserts it) — the module's always-sent S256 challenge is advisory until the IdP enforces the verifier.
   - **Missed (top):** groups→RBAC unused — module never requests the `groups` scope nor carries the claim; admin membership is a deploy-coupled env var; `FinishLoginWithToken` (raw verified ID token) is today's escape hatch.
   - **Missed:** `merge-duplicate-users` ships in the DEPLOYED binary (present at both revs) and has never run against prod — the runbook's "count stays 9 until upstream ships delete" claim was STALE (corrected in the runbook this session).
   - **Missed:** deployed v4.12.0 vs locked v4.13.0 vs upstream Unreleased security pair (OIDC nonce round-trip + `empty_subject` rejection).
   - **Missed:** RP-initiated logout (local-only clear today; `logoutCallbackURLs` provision field unused), step-up re-auth (`requiresReauthentication` unused fleet-wide — natural fit for /admin/).
6. **Verify block replayed 6/6 green** (S256 always-on; pkceEnabled 8-siblings-vs-0; groups 0 hits in module; v4.12.0 deployed pin; merge CLI at deployed rev; RP-logout 0 hits). Index row added to `docs/research/README.md`; durable verdict distilled into the runbook (OAuth audit bullet, 2026-11-06).

## b) PARTIALLY DONE

**POSTSCRIPT 2026-11-06 ~02:40 (supersedes parts of b1/f1/f2):** the sibling float-recovery session landed its closeout at 02:15 (`2026-11-06_02-15_float-gate-green-closeout-owner-gates.md`): float gate CLOSED (proofs #8 green, #9/#10 no-drift, lock+registry pair committed), monitor365 fixed upstream (`164e159a4` pushed), ~14 root classes fixed/pinned. **The deploy is explicitly an OWNER GATE there (§e D2, "deploys are owner-timed")** — my session's auto-deploy watcher (armed before that closeout existed) was therefore NOT allowed to fire and has exited without deploying; the deploy decision belongs to the owner, with the exact commands + post-deploy recipe already in this report (b2/§f.6). Also live-confirmed tonight: the mkSqliteBackupUnit sidecar/mode diagnosis reproduced exactly on the 02:15 run (`browser-history-db-2026-11-06.sqlite` 0600 + `hLE0Dt-{shm,wal}` sidecars).

1. **THE OWNER-VISIBLE OUTCOME: the 403 is still live.** The fix rides the next successful deploy, which is blocked by a concurrent session's blanket `flake.lock` float — float-register proofs RED at 23:15 and 00:05 (27 failed unit-dep roots, incl. monitor365-prepared-source FOD + stalwart + home-manager deps), and `flake.lock`/`flake.nix`/`flake/expected-locks.nix` are being edited in the tree RIGHT NOW (01:0x). I did not touch the lock (concurrent-session discipline; the float owner must land or revert it).
2. **Post-deploy verification recipe written, unexecutable until deploy:** journal must show `admin: super admin granted` (email + user_id) after the drain — the line NAMES which user got the grant, which is also the catch for b3; then the owner's existing session renders `/admin/` (no re-login; the authorizer reads casbin live).
3. **Premise risk unverified:** which read model backs `Service.ReadModel().FindByEmail` under `USE_SQLITE_READ_MODEL=true` (keep-first → data owner `01M000JA6…` is the runbook narrative, not re-verified in source this session). If the reconcile resolved a zombie dupe instead, the grant lands on the wrong user — the journal user_id check in b2 is the decisive catcher.
   **VERIFIED 2026-11-06 ~01:2x (postscript):** `Service.ReadModel()` returns the in-memory ES model unconditionally (`service_lifecycle.go:102` — `*UserReadModel`; the sqlite setup wraps the same type as a projection, sqlite_setup.go:75), and deployed browser-history 9daaa80 pins usermgmt v4.18.0 which POSTDATES the keep-first fix `492e473e` (guards verified in es_readmodel.go:116-118 + 213-215). `FindByEmail("lars@larsartmann.cloud")` therefore resolves keep-first to `01M000JA6…` (2026-08-14, the data owner). Premise risk closed; §f.7 done.
4. **Upstream `superAdminEmails` module option:** queued (upstream.md + queue), not implemented.
5. **Deep-dive done-bar:** gate leg unmet (SystemNix gate is RED at HEAD — the float; noted honestly in the report's done-bar callout); screenshot leg unmet (no headless browser on PATH; chromium via nix = a storm-class heavy download, skipped deliberately).

## c) NOT STARTED

1. `pkceEnabled = true` on the browser-history Pocket ID client (top opportunity, one line, harvested).
2. oauth2 tag upstream + browser-history bump (nonce + empty_subject pair; harvested).
3. `merge-duplicate-users` prod stop-window + gatus baseline 9→1 (harvested, owner-gated).
4. RP-initiated logout wiring (upstream ask + consumer work).
5. groups→RBAC (short: WithToken + fail-closed mapping; long: upstream userInfo + provisioner scope field).
6. `requiresReauthentication` step-up for /admin/ (dedicated admin client or upstream prompt=login).
7. VM-test regression step asserting the SUPER_ADMIN_EMAILS env wiring.
8. post-deploy-check leg: fail loudly on `super admin email not registered` (email-drift class).
9. Eval-time lint idea: warn on `browser-history.enable && oauth-only && no admin emails`.
10. Deep-dive screenshot (blocked on a headless browser).

## d) TOTALLY FUCKED UP

1. **`rg -r` trap, three strikes in one session:** hook-blocked once (`rg -rn`), then I MANAGED TO DO IT AGAIN with `rg … -r ''` which silently mangled the SUPER_ADMIN grep display (caught by re-reading the file), and then typed `rg -rn` a THIRD time later (hook blocked again). The AGENTS.md documents this exact trap (2026-10-23, two corrupted sessions) and the hook literally told me the rule mid-session. Unforgivable repetition; the only mitigation is never typing `-r` after `rg` again.
2. **The original complaint is unfixed from the owner's chair:** two work products (fix + audit) landed in-tree, but the answer to "why 403" is still "you'll keep seeing it" until a deploy another session's broken lock is blocking. Session output ≠ user outcome; the report says so plainly.
3. **First-pass HTML quality was sloppy:** one multiedit consumed the proposal section header (versions section captured the proposal body), a duplicate `versions` section survived an intermediate edit, and the version table was planned but dropped from its first insertion — all caught by my structural checks (section/div/anchor balance, id uniqueness) and fixed, but each was a self-inflicted wound the template discipline exists to prevent.
4. **A multiedit hit a "modified since read" ghost** (mtime newer than my view, no edits landed, content unchanged) — cost a retry loop. Symptom of editing a hot tree while a daemon + sibling session are live; re-read-then-retry was the right recovery but the first attempt was wasted.
5. **First DB-copy attempt left a 0-byte artifact** (glob `cp` with stderr swallowed died on the unreadable newest backup); recovered by explicit-file copy — and the copy still sits un-deleted in `~/.cache/bh-admin/` (205 MB, mode 600).

## e) WHAT WE SHOULD IMPROVE

1. **Pre-flight shared-surface eval at session start** — a single `nix eval …drvPath` before ANY fix would have surfaced the float-blocked deploy state in minute one instead of after the edit, and shaped expectations/reporting accordingly.
2. **Verify premise chains or mark them visibly** — the ReadModel keep-first link was load-bearing for "the grant lands on the right user" and went unverified; it should have been either pinned in source or listed as an explicit premise risk in the first close-out (it was, but only in this report).
3. **Runtime proof over code-read confidence for security-gate claims** — the repro-harness recipe (deployed binary + scratch port + env) could have PROVEN env→grant→200 before the deploy existed; code-reading felt sufficient and wasn't.
4. **Flag foreign-tree discoveries the moment they're seen** — the 10 sibling files riding daemon commit `5bd7e63cb` were noticed at final verification, not when first observed; the user should hear about foreign files when they appear, not in a closing summary.
5. **HTML reports: verify structure after EVERY insertion, not at the end** — the section/header splice errors compounded across four edits before the balance check ran; per-block checks would have caught each at birth.
6. **Treat the hook as the last line of defense, not the first** — blocked-command lessons must change typing behavior immediately, not after a second strike.

## f) NEXT THINGS (brainstorm-grade, impact-ordered groups; harvest status in the ledger below)

**Deploy & verify chain (blocked by the float, rides one deploy):**
1. Land or revert the blanket `flake.lock` float (sibling session actively editing `flake.lock`/`flake.nix`/`flake/expected-locks.nix` at 01:0x; 27 roots incl. monitor365 FOD, stalwart, HM deps).
2. Fix the monitor365-prepared-source root (`rm: cannot remove Cargo.lock: Permission denied` inside the FOD).
3. Deploy evo-x2 once the tree is landable (carries the SUPER_ADMIN_EMAILS fix + everything already queued in-tree: fastflowlm removal, quotaboard wiring, tier-2 veto, cvagent timeout, papdashboard self-heal, monitor365 tmpfiles, zed rename…).
4. Anchor discipline: newest `system-N-link` by NUMBER vs `readlink /run/current-system`; `pre-reboot-check` if rebooting.
5. Post-deploy battery + `mutation-smoke.sh` triple probe (health-answers, agent tick, users gauge).
6. **The admin close-out:** journal `admin: super admin granted` naming `lars@larsartmann.cloud` + the EXACT user_id (WHICH-user assertion — catches b3), then owner renders `/admin/`.
7. Verify ReadModel keep-first under SQL mode (b3) — one source read + a scratch-DB probe.

**OAuth audit follow-ups (the report's priority matrix):**
8. `pkceEnabled = true` on the browser-history client (P20; one line).
9. Tag oauth2 upstream + bump browser-history (nonce + empty_subject; P16).
10. `merge-duplicate-users` owner stop-window per its runbook, then gatus baseline 9→1 (P12).
11. groups→RBAC: short-term `FinishLoginWithToken` + fail-closed mapping; long-term upstream userInfo+scopes (P10).
12. RP-initiated logout (P9).
13. Request `Scopes` explicitly instead of the silent default (P8).
14. Step-up re-auth client for /admin/ (P6).
15. Audit-bridge depth verification (P6).

**Fix hardening:**
16. Upstream `superAdminEmails` module option (queued this session).
17. Float-forward the wrapper env twin via an `options ?` guard once the option lands.
18. VM-test step asserting the env wiring.
19. post-deploy-check leg: red on `super admin email not registered`.
20. Eval-time lint: warn `enable && oauth-only && no admin emails`.
21. Upstream observability ask: log (don't silently no-op) when SUPER_ADMIN_EMAILS is empty — this session's diagnosis cost came from the silence.
22. Upstream ask: reconcileSuperAdmins should log the RESOLVED user_id at WARN when it is not the keep-first/oldest user (duplicate-resolution drift class, b3).

**Fleet/docs hygiene:**
23. Pool-backup permission drift: Nov 5 backup is root-only while Oct ≤23 are world-readable — root-cause (dbBackup unit change?) and refresh the runbook's "world-readable" live-probe recipe.
24. Delete `~/.cache/bh-admin/dbcopy.sqlite` after the deploy verification window.
25. Attribute the 10 foreign service-module files that rode daemon commit `5bd7e63cb` (bank-sync/crm/discordsync/inboxclean/journal-backup/journal-serve/mr-sync/papdashboard/PMA/visionreviewd) to their session; confirm intentional.
26. The pre-existing 188 unharvested-§f WARN pile — schedule a docs-health pass (my session added zero new unharvested rows).
27. MAX_USERS=1 vs 9 existing rows: document the gate-vs-grandfathered-rows semantics in the runbook.
28. adminui Tenants page empty-state check (fresh tenancy model renders).
29. Does adminui now expose a DeleteUser surface? If yes, close the runbook claim + services.md row 87 residue.
30. `merge-duplicate-users` man-page/README mention (browser-history 2026-10-11 open item 28).

**Upstream filing (verify-before-filing first):**
31. oauth2 release ask (nonce + empty_subject — item 9's upstream half).
32. File the reconcile-empty-list log ask (item 21).
33. File groups→userInfo upstream issue (item 11's upstream half).
34. File RP-logout upstream ask (item 12's upstream half).

**Monitoring:**
35. Admin-403-rate signal (SigNoz rule or gatus) — today's RBAC-misconfig class was invisible to every monitor for weeks.
36. Post-deploy admin-grant canary (item 19's check-shaped twin).
37. `browser_history_users` baseline automation after the merge run (literal→derived).

**Roadmap-grade (deliberately not queued):**
38. `oidcClientType.scopes` provision schema field (needs Pocket ID client-scope API support in the provisioner).
39. SessionTTL configurability (24h hardcoded at server.go:470).
40. Multi-provider posture decision: keep or delete the google/github slots.
41. OIDC back-channel logout (upstream module feature).
42. Fleet-wide: wire RP-logout for ALL Layer-1 apps (sso-dns.md:50 "per-app work not currently done").

## g) QUESTIONS (cannot self-answer)

1. **Float ownership:** the blanket `flake.lock` float session is editing `flake.lock`/`flake.nix`/`flake/expected-locks.nix` RIGHT NOW (live `nix build . -L` + `stalwart_1_0` builds). Is it yours/expected to land? Do I WAIT, or take over the rescue (fix the monitor365 root, re-run float-register) once it goes idle?
2. **Admin identity end-state:** keep `SUPER_ADMIN_EMAILS` (single-sourced from tokenUserEmail) as the permanent mechanism, or move to IdP-group RBAC (audit finding 2) so admin membership lives in Pocket ID? The answer decides whether items 11/16-17 are worth their upstream cost.
3. **Upstream execution timing:** shall I implement + push the browser-history-side items NOW (pkceEnabled is SystemNix-only; the oauth2 tag/bump and the module option live upstream) so they ride the same eventual deploy — or dispatch them through the queue in a later pass?

## Harvest ledger (self-harvest at authoring, per the status-report mandate)

**Harvested NOW (TODO_LIST.md one-liner + domain library row, both edited):**
- `pkceEnabled = true` → services.md (+ queue)
- oauth2 tag+bump (nonce/empty_subject) → upstream.md (+ queue)
- `merge-duplicate-users` stop-window [blocked:user] → services.md (+ queue)
- Pool-backup permission drift → services.md (+ queue)
- Post-deploy admin-grant canary + admin-403 signal → monitoring.md (+ queue)
- Reconcile-empty-list + resolved-user_id logging asks → upstream.md (+ queue)

**Deliberately NOT harvested (reasons):**
- Items 1-7 (deploy chain): a single pending deploy event already owned by the existing stability.md row ("Re-run the pending deploy when io PSI < 20") + the runbook's /admin/ bullet — queueing a duplicate split-brains the deploy intent.
- Items 14, 16-17: ride the already-queued superAdminEmails option row (this session's earlier harvest); a second row would drift from it.
- Items 30, 40, 41-42: browser-history-repo-internal or ROADMAP-grade; belong in that repo's docs (30 is cited in its own 2026-10-11 report), not SystemNix's queue.
- Items 38-39: ROADMAP fuel per the status-report skill (larger-N items are a brainstorm, not commitments).
- Item 10 (screenshot) and 24 (dbcopy cleanup): one-off micro-tasks recorded here; queueing them is noise.
