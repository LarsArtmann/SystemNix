# Status — 2026-11-24 05-43 — "Why does history.home.lan claim 9 users" + cqrs-htmx merge asks

Session window: 2026-11-24 ~04:25 → 05:43 CET. Host `evo-x2`, HEAD at authoring time `cf5853c78` (SystemNix master = origin/master per local refs).
Scope: one user question (the 9-user count), one owner order (file the missing merge features upstream). No deploys, no service restarts, no prod writes.

---

## 0. The answer in one paragraph

`/admin/users` renders `len(Service.ReadModel().AllUsers())` (`adminui/handler_dashboard.go:97`), i.e. the row count of `users_view`. The live DB has **9 rows that are all the same human** (`lars@larsartmann.cloud`, identical display name, one shared Pocket-ID subject `88bec46e-57cd-41c3-b768-e1a9e00425fb`, zero credentials, no TOTP, email unverified), created 2026-08-14 → 2026-09-19 by the pre-lock OAuth2 auto-provisioning flow that minted a new user per login instead of linking by email. Only the oldest (`01M000JA6P0VR4Q1BNEPSJN3ME`) owns data: **6,932 visits** and the **1** `agent_tokens` row; bookmarks/downloads/omnibox rows are split only between that owner and the anonymous zero-id. `MAX_USERS=1` is live, so registration is closed and the residue can only be deleted or merged. The merge feature does not exist anywhere in `cqrs-htmx`; the admin panel does expose delete (contrary to the runbook's stale claim). Both missing features are now filed: **cqrs-htmx#46** (users) and **cqrs-htmx#47** (tenants).

---

## a) FULLY DONE (evidence attached)

1. **Root cause of the "9 users" count, source-verified.** Admin UI count = `len(AllUsers())` over the users read model (`adminui/handler_dashboard.go:97`, `adminui/handler_users.go:97`). No separate counter, no cache, no derived metric.
2. **Live DB inventory.** `sudo sqlite3 -readonly /var/lib/private/browser-history/data.db "select key,email,display_name,created_at,tombstoned from users_view order by created_at"` → 9 rows, all `lars@larsartmann.cloud`, `tombstoned=0`, dates 2026-08-14T11:29:55Z … 2026-09-19T14:09:56Z.
3. **Data-ownership proof.** `visits` grouped by `user_id`: only `01M000JA6…` = **6,932**. `agent_tokens`: only `01M000JA6…` = 1. `bookmarks`/`downloads`/`omnibox_inputs`: owner + zero-id only. Not one row under any of the 8 newer duplicates.
4. **Identity-equivalence proof (stronger than the runbook's claim).** Every one of the 9 rows carries the SAME `external_accounts[0].subject` (`88bec46e-…`, provider `pocket-id`), `credential_count 0`, `totp_enabled 0`, `email_verified 0`. So all nine streams are one identity, and for THIS group a delete would lose nothing.
5. **Live metric + config.** `GET http://127.0.0.1:8087/metrics` → `browser_history_users 9` (raw `/dev/tcp` probe, gatus and the collector see the same). Unit env: `MAX_USERS=1`, `SUPER_ADMIN_EMAILS=lars@larsartmann.cloud`. Deployed binary: `/nix/store/l2q25w64…-browser-history-server-fa68d88/bin/browser-history-server` (PID 104631).
6. **Deployed-surface verification at the pinned rev.** browser-history `flake.nix` pins cqrs-htmx `3c544dc9`. At that rev: `POST /users/{id}/delete` exists (`adminui/routes.go:207`), tenant create/suspend/reactivate/delete exist (`adminui/routes.go:240-257`), and `git grep -i merge 3c544dc9 -- usermgmt adminui identity-model` returns only license/json-merge noise — **no merge surface at the deployed rev or at master**.
7. **Merge absence mapped at every layer.** Aggregate/service surface is register / delete / change-email / change-display-name / credentials / TOTP / external link-unlink / platform roles / bots (`usermgmt/service_*.go`); adminui route table has no merge route; `identity-model` has no merge event; north-star: `rg -n -i merge usermgmt adminui identity-model` is empty.
8. **Tenant-side mechanics probed empirically** (not inferred): `usermgmt.DecideCreateTenant(id.NewStreamID(), "acme", "Acme")` on a zero state → **1 event, `err=<nil>`** (same name, different ID is legal); against a create+delete state (`TenantState{Name:"acme", Deleted:true}`) → **`[conflict:usermgmt.tenant.already_exists]`** (delete is terminal per stream) even though `FoldTenant` keeps `Name` and its own comment promises recreation. Panel derives the ID from the name (`adminui/handler_tenants.go:73`, `NewTenantID` = raw brand wrapper, no casefold), so a deleted/typo'd name is permanently unusable.
9. **Filed both upstream asks, verified landed.** [cqrs-htmx#46](https://github.com/LarsArtmann/cqrs-htmx/issues/46) (merge users, 5,036 chars) and [cqrs-htmx#47](https://github.com/LarsArtmann/cqrs-htmx/issues/47) (merge/rename tenants, 4,723 chars); `gh issue view` re-read both after filing (they exist, bodies intact).
10. **Voice-gated.** Both drafts ran `check-draft --kind body-issue --ai-drafted` → `0 FAIL, 0 WARN`. Drafts kept in-repo at `~/projects/cqrs-htmx/docs/drafts/2026-11-24_usermgmt-merge-duplicate-{users,tenants}.md` (committed by the daemon in `3eac9db0`).
11. **SystemNix doc truth fixes.** `docs/services/browser-history.md`: corrected "needs a DeleteUser admin surface upstream (service method exists, exposed nowhere)" (false — delete is exposed at the pinned rev) and the owner-ceremony step that repeated it, with the gatus re-baseline warning; one line-cite corrected (`routes.go:250` → `:207` at `3c544dc9`).
12. **Harvested.** `docs/todo/upstream.md` gained both filed asks (with the probe evidence and the fix recipe); `docs/todo/services.md` gained the delete-vs-merge decision row and the backup-permissions drift row.
13. **Gates.** `scripts/check-todo-system.sh` → `OK: TODO queue/library structure clean` (the 97 unharvested-§f WARN is the pre-existing report backlog, not this session).

## b) PARTIALLY DONE

1. **The page itself was never loaded authenticated.** The "9" is proven from the read model + the rendering code path, not from an authenticated `GET /admin/users` capture. Equivalent for this count (no filtering, no pagination of the total), but it is inference at one hop.
2. **Event-store level identity check.** The read-model `data` blob shows one shared subject and zero credentials; I did not replay/grep the `events` table for `CredentialAdded`/`ExternalAccountLinked` per stream to prove the streams themselves are empty of auth material.
3. **"Delete is lossless for these 8"** — inferred from the read model, not executed on a DB copy.
4. **Stale-claim sweep is one-sided.** SystemNix's copies are fixed; `~/projects/browser-history`'s own `docs/runbooks/merge-duplicate-users.md` (and its "never run against prod" assumption) was not read or corrected.
5. **Harvest stopped at SystemNix.** No row added to cqrs-htmx's own `TODO_LIST.md` for #46/#47 (that repo's convention).
6. **Why the count is 9 and not more/fewer** — I did not check the events journal for users created then deleted (a tombstoned stream would not show in `users_view`), so "exactly 9 ever existed" is unproven.

## c) NOT STARTED

1. Driving the count 9 → 1 (owner action: panel delete ×8 **or** wait for `MergeUsers`), plus the gatus literal re-baseline in the same change.
2. Any upstream implementation of `MergeUsers` / `MergeTenants` / `RenameTenant` (agents do not push; the issues carry the design checklist).
3. A duplicate-identity detector (query + metric + alert) so this class is visible without a human noticing a number.
4. A delete-path smoke on a copy DB proving keep-first lookup still resolves the owner and login survives.
5. Correcting the browser-history repo's own runbook claims.
6. cqrs-htmx TODO rows / milestone / labels for #46/#47.

## d) TOTALLY FUCKED UP

1. **Ran the deployed server binary by hand.** `…-browser-history-server-fa68d88/bin/browser-history-server --help` did not print help — it hung as if booting (background job 018), and I killed it. Verified afterwards: only the real PID (104631) exists, unit `active`, and the journal 04:50–05:15 has no ERROR/bind/`address already in use` lines. Still the wrong move: a service binary run as the unprivileged user could have bound 8087 or probed the state dir. Read subcommands from source or `strings`, never execute the artifact.
2. **Wrong line citation shipped in a doc edit, then fixed.** I first wrote `adminui/routes.go:250` as the pinned-rev location (that is master's line; at `3c544dc9` it is `:207`). Fixed in the same session, but the first version was wrong and reached the tree.
3. **Garbled first probe.** The initial node-exporter metric read was a pointless `printf … | bash -c '…'` chain that produced silence — an empty read presented as if it were a reading. Re-probed properly via `/dev/tcp` on :8087.
4. **Answered too late.** The "9 users" explanation was available after three DB queries; I kept going (binary subcommands, `--help`) instead of answering, and the user had to interrupt. Answer-first discipline failed.
5. **Hook trip.** `rg -ril` (a replace expression, not "recursive+line numbers") — the documented third strike of that trap on this host; burned a tool call.

## e) WHAT WE SHOULD IMPROVE

1. Answer the question asked at the first moment it is provable, then deepen. Investigation breadth is not a substitute for an answer.
2. Never execute an unknown binary out of the nix store when the same binary is a live service; read the source for its subcommands.
3. Verify UI numbers at the delivering layer when feasible (authenticated fetch), and when not feasible, say "inferred from source + read model" out loud in the answer.
4. Sweep every copy of a stale claim in one pass (SystemNix runbook, browser-history runbook, cqrs-htmx docs) — I fixed one copy and left the source repo untouched.
5. Cross-check runbook operational claims while you are standing in the evidence: I saw the 0600 root backup and did not connect it to the runbook's "world-readable" recipe until the report pass.
6. Keep the posted issue body and the in-repo draft mechanically identical; extracting with `tail -n +3` is fragile (a heading change silently shifts the body).
7. Use the todo tool for a multi-step investigation; the steps were held in prose only.
8. Shared-tree discipline paid off (re-verified content in `HEAD` after noticing `893edb689` is no longer an ancestor — a foreign history rewrite happened mid-session), but I should have pinned `HEAD` at session start and diffed it at the end.
9. Journal reads: capture-once-then-grep. I ran several overlapping `journalctl` windows instead of one capture.
10. The count could be exposed as a first-class signal (duplicate-email metric) instead of relying on an incidental number on a page.

## f) UP TO 50 THINGS TO GET DONE NEXT

Disposition note (TODO-system rule): the report's DIRECT follow-ups are harvested — the delete-vs-merge decision row and the backup-permissions drift row in `docs/todo/services.md`, and both filed asks in `docs/todo/upstream.md`. Items below marked **[owner]**, **[upstream]**, **[watch]** or **[idea]** are deliberately not queued: they need the owner's hand, need an upstream push/tag, are time-gated, or are ideas without a scheduled slot.

**browser-history user residue (the live 9)**

1. **[owner]** Decide delete-now vs wait-for-merge for the 8 zombie rows (they hold 0 credentials / 0 TOTP / 0 rows, so delete is loss-free for this group).
2. **[owner]** Take a fresh pool backup immediately before any delete, and record its name in the report.
3. Fresh `browser-history-db-*.sqlite` copy → run `merge-duplicate-users -db …` **dry run** and record its group/row counts against the 8 known ids.
4. **[owner]** Delete the 8 through `/admin/users` (each delete dispatches a real `user-deleted` event).
5. Re-baseline `browser_history_users 9` → `1` in `modules/nixos/services/browser-history.nix:859` in the SAME change as the delete.
6. Post-op: `browser_history_users 1`, `/health` answers, login resolves to `01M000JA6…`, dashboard renders 6,932 visits, `scripts/mutation-smoke.sh` green.
7. Prove the survivors' lookups: `FindByEmail`/`FindBySubject` still return the owner after the tombstones (keep-first regression test already exists; re-run it against a copy).
8. Add a permanent duplicate-email query to the runbook (one-line SQL) so the next owner sees the group instantly.
9. Add `browser_history_duplicate_identity_groups` (or similar) to the agent-metrics collector and alert on >0.
10. **[owner]** Confirm the "9" baseline number in gatus/gatus-dashboard docs is not repeated anywhere else (grep the literal outside browser-history.nix).
11. Correct the runbook's "world-readable" backup recipe to `sudo sqlite3 -readonly` (row filed).
12. Correct `docs/services/browser-history.md:15`'s "database has 5 users — pass -user-email" example; it is 9 today and the example will age again — phrase it as "more than one user".
13. Record in the runbook that the deployed binary is `fa68d88` / cqrs-htmx `3c544dc9` (the "CURRENT lock" note still says `87c6d4a`).
14. Read and correct `~/projects/browser-history/docs/runbooks/merge-duplicate-users.md` (their "count stays 9 until upstream ships delete" framing is stale; delete exists).
15. **[owner]** Decide whether the 8 deletes also retire the `merge-duplicate-users` CLI or keep it for future consumers.

**cqrs-htmx implementation (#46 users)**

16. **[upstream]** Write the failing test first: two users, one email, separate credentials → assert the desired post-merge shape.
17. **[upstream]** Define `UserMerged` payload (survivor, losers, reason, schema version) and add it to the event catalog.
18. **[upstream]** `decideMergeUsers` + fold support + replay safety (no resurrection of the loser).
19. **[upstream]** Tombstone loser streams with `MergedInto` (never a read-model-only delete — the browser-history CLI documents why).
20. **[upstream]** `MergedInto` on `users_view` + `FindByEmail`/`FindBySubject` follow the pointer; guarded evictions on later email changes.
21. **[upstream]** Credential merge (dedupe by credential id) and external-account merge (provider+subject; conflict = typed rejection naming both rows).
22. **[upstream]** TOTP merge rule (survivor wins; adopt loser's secret only when survivor has none) — and a test for each branch.
23. **[upstream]** Membership union per tenant via `AddMember`/`RemoveMember`, highest role wins; journal stays the record.
24. **[upstream]** Re-point bots + revoke loser sessions.
25. **[upstream]** `Service.MergeUsers` under the same lock discipline as registration (`registrationMu`-class) to avoid a lookup race.
26. **[upstream]** Publish `UserMerged` for consumers; document the consumer contract for re-pointing app-owned `user_id` columns.
27. **[upstream]** Admin UI: `POST /users/{id}/merge` with survivor picker + explicit confirm text naming what moves.
28. **[upstream]** Admin UI: duplicates report (same email / same external subject) with per-group counts and a one-click survivor choice.
29. **[upstream]** Audit entries for merges (today only some command classes reach the audit log; tenant lifecycle entries are absent entirely).
30. **[upstream]** A one-shot `merge-duplicate-users` admin CLI for existing residue (idempotent, dry-run default, — the shape browser-history already proved).
31. **[upstream]** Snapshot/state-shape bump if `UserState` gains merge fields; verify hydration from old journals.

**cqrs-htmx implementation (#47 tenants)**

32. **[upstream]** `RenameTenant` + `TenantRenamed` event (the typo path that does not destroy a roster).
33. **[upstream]** `MergeTenants` + `TenantMerged`: move memberships, tombstone losers with `MergedInto`, survivor name canonical.
34. **[upstream]** Resolve the recreate contradiction: either allow create on a tombstoned stream (what `identity-model/fold.go:311` promises) or delete that comment and surface terminality.
35. **[upstream]** Normalized-name uniqueness (trim + casefold) as an option, because the panel keys tenants by name.
36. **[upstream]** Decide the panel's tenant key strategy (name-derived ID vs opaque ID) — see question 3.
37. **[upstream]** Admin UI: merge action + duplicates report; create-form collision message that names the existing tenant instead of a bare `tenant.already_exists`.
38. **[upstream]** Tenant-attributed audit entries (already an open ask (h)(5)) so merges are auditable.

**Verification, observability, docs**

39. Add a post-deploy check leg asserting `browser_history_users` equals the runbook's documented baseline (catches silent re-registration and silent rollback).
40. **[watch]** SigNoz rule on duplicate-identity group count (reuse the users gauge pattern).
41. Reconcile the `664`/`595`/`4,959`/`6,932` visit-count numbers that appear across the runbook and status reports (a "counts are dated" ledger line).
42. Re-verify the `MAX_USERS=1` gate end-to-end after any delete (the registration gate's count check now sees 1, not 9).
43. Verify `/auth/import` still refuses unauthenticated after the delete (smoke already covers it; keep it green).
44. Add the deployed-rev pin to the runbook's truth-check ritual (it drifted from `87c6d4a` to `fa68d88` unnoticed).

**Process / hygiene**

45. Add a session-start pin: `git rev-parse HEAD` recorded in the report, re-checked at the end (a foreign rewrite landed mid-session).
46. Never run a store binary that is also a service; add it to the session rules.
47. Byte-compare filed issue bodies with their in-repo drafts (`gh issue view --json body` vs the draft) as a closing step.
48. Use `rg -n` (never `-r`) — the hook exists; the muscle memory does not yet.
49. Capture journal/log output once to a file, then grep the file (I ran several overlapping windows).
50. Keep one status-report habit: the answer paragraph first (§0), evidence after — so a reader (and the owner) gets the conclusion in ten seconds.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **The 8 zombie rows: delete now, or hold for `MergeUsers`?** Delete is provably lossless for this specific group (0 credentials, 0 TOTP, no owned rows) — but it sets the count baseline to 1 and needs the gatus literal changed in the same change, and it means the first real merge exercise waits for another incident. **ANSWERED 2026-11-24 (owner): HOLD — wait for the native `MergeUsers` in cqrs-htmx. The 8 rows stay, the count stays 9 by design, no deletion is performed.** Consequences: the `[blocked:user]` decision row in `docs/todo/services.md` became a `[blocked:push]` unblock ladder, and `docs/services/browser-history.md` (duplicate-identity row + consolidation runbook item 3) carries the decision of record.
2. **Merge contract for consumers: identity-only, or identity + a published event apps must handle?** My filed design publishes `UserMerged` so apps can re-point their own columns (browser-history's CLI is exactly that re-pointing, hand-rolled). The narrower contract keeps `usermgmt` purely identity and leaves every consumer to hand-roll forever. Both are defensible; the second is less code and more duplicated consumer work.
3. **Tenant keys: keep the panel's name-derived tenant ID (and enforce normalized-name uniqueness), or move the admin panel to opaque IDs?** Name-as-ID makes rename/merge impossible without churn and makes a deleted name permanently unusable; opaque IDs are rename-safe but change every existing tenant URL/ID and need a migration story for the deployments that already hold name-IDs.

---

_Session receipts: live DB probes (read-only sqlite via sudo), `GET :8087/metrics`, `gh issue view 46/47`, `git show 3c544dc9:adminui/routes.go`, `go run` decider probes from `~/.cache/bhmerge-probe/main.go`, `scripts/check-todo-system.sh`._
