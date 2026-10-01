# Status: Paperless SSO → superuser via Pocket ID `groups` claim

**Date:** 2026-10-01 03:37 CEST
**Session model:** Crush `hf:deepseek-ai/DeepSeek-V4.1-Flash`
**Trunk at report time:** `d5ec0c8a` (auto-commit churn; feature landed in `deab8469`)
**Scope of this session:** answer _"why doesn't SystemNix auto-make the Pocket ID user a Paperless superuser, and can we use OIDC roles/scopes to do it safely and automatically?"_ — then implement it.

---

## 0. What the user asked (verbatim arc)

1. _"why did SystemNix not do that automatically via PocketID?"_ — after manually running
   `paperless-manage shell -c "…update(is_superuser=True)"`.
2. _"It somehow needs to work automatically for me; in a safe way."_
3. _"OIDC has roles or scopes or not?"_ — probing the mechanism.

---

## a) FULLY DONE

| #  | Item                                                                                                                                                                                                                                                                                                                                                    | Evidence                                                                                                                                                                                                                                           |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| a1 | **Root-caused the gap (source-verified).** OIDC `groups` claim is emitted by Pocket ID **only when the client requests the `groups` scope**; paperless 3.1.3 already ships the role-mapping capability that nothing had wired.                                                                                                                          | `claims_service.go:157` (`if slices.Contains(scopes, "groups")`); `client.go:86` (`groups` in allowed scopes); allauth `oauth2/provider.py:79` (`scope = settings.get("SCOPE", …)`); paperless `signals.py:82-101`; settings `__init__.py:347-351` |
| a2 | **Pocket ID declarative user groups (new capability).** `services.pocket-id-config.provision.userGroups` (`name`, `friendlyName`, `memberUsernames`); provisioner Step 4 creates each group and **authoritatively** syncs membership via `PUT /user-groups/{id}/users`; a declared member that resolves to no Pocket ID user **fails the unit loudly**. | `modules/nixos/services/pocket-id.nix` (option ~L397, Step 4 ~L315 in commit `deab8469`)                                                                                                                                                           |
| a3 | **Paperless role mapping wired.** `groups` appended to provider `SCOPE`; `PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS_CLAIM=groups`, `…_SYNC_SUPERUSER_GROUP=paperless-admins`, `…_SYNC_STAFF_GROUP=paperless-admins`; group `paperless-admins` declared in Pocket ID, members = the Pocket ID admin identity.                                                 | `modules/nixos/services/paperless.nix:67,100,535-537,1132`                                                                                                                                                                                         |
| a4 | **Eval-verified on `evo-x2`.**                                                                                                                                                                                                                                                                                                                          | `provision.userGroups = [{"friendlyName":"Paperless Administrators","memberUsernames":["lars"],"name":"paperless-admins"}]`; settings expose the three `SYNC_*` vars (re-confirmed after the parallel commits — still intact)                      |
| a5 | **Generated provisioner build-verified.** Realised the writeShellApplication derivation (shellcheck runs at build) + `bash -n`.                                                                                                                                                                                                                         | `nix-store --realise …-pocket-id-provision.drv` succeeded; `bash -n …/bin/pocket-id-provision` → SYNTAX OK; `grep` confirms the `paperless-admins` group block                                                                                     |
| a6 | **Answered the user's question** with a source-cited mechanism table and the safe/automatic design (fail-closed mapping).                                                                                                                                                                                                                               | this session's prior message                                                                                                                                                                                                                       |

**Design property that makes it "safe":** the mapping is **fail-closed** — paperless `signals.py:83` sets `is_superuser = <group> in <claim>` on every login, so a missing/empty claim **demotes**. A broken IdP can never leave stale privilege behind.

---

## b) PARTIALLY DONE

| #  | Item                        | State                                                                                                                                                                                                                           | Missing                                                                                                                                                                                                                                                         |
| -- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| b1 | **Tests**                   | A mock only — another session committed `3e85cf1a fix test: mock pocket-id group-mapping options in paperless VM eval` (mock leaves for `provision.userGroups` + `provision.adminUser.username` in `tests/test-paperless.nix`). | **Zero assertions** for the new behaviour: no check that `groups` is in the provider `SCOPE`, no check that the `SYNC_*` env vars render, no check that the group is created/membership synced. `grep` for `SYNC_SUPERUSER/STAFF/GROUPS` in the test → nothing. |
| b2 | **End-to-end verification** | Static + generation only (eval, build, `bash -n`).                                                                                                                                                                              | No `runNixOSTest` execution, **no live deploy**, **no real Pocket ID API round-trip**, **no actual passkey-login probe** confirming promotion/demotion.                                                                                                         |
| b3 | **Docs**                    | none.                                                                                                                                                                                                                           | `docs/services/paperless.md`, `docs/agents/sso-dns.md`, `CHANGELOG.md` do not mention the group mapping (grep empty).                                                                                                                                           |
| b4 | **Concurrency attribution** | Diagnosed mid-session.                                                                                                                                                                                                          | Not yet resolved: is the other session still active? Should I stand down?                                                                                                                                                                                       |

---

## c) NOT STARTED

- **c1** `docs/services/paperless.md` — document the `paperless-admins` group, the `groups` scope dependency, and **fail-closed demotion** semantics (this will surprise the user: the manual `is_superuser=True` is overwritten on next login).
- **c2** `docs/agents/sso-dns.md` — record the fleet-wide fact: _Pocket ID emits `groups` only with the `groups` scope_ (sibling to the existing `email_verified` scopes fact at L42).
- **c3** `CHANGELOG.md` entry for the new capability + the Paperless mapping.
- **c4** `TODO_LIST.md` + `docs/todo/*` harvest rows for the leftover obligations (test assertions, docs, deploy+verify). AGENTS requires status reports to self-harvest §f at authoring time.
- **c5** Deploy (`nix run .#deploy`) and post-deploy live verification (group created, `groups` claim present in the token, `lars` promoted on login).
- **c6** Gatus / post-deploy smoke for the role mapping (e.g. login-page body already asserts the SSO button; a _role_ assertion does not exist).
- **c7** Reconcile the sops-`admin` break-glass account vs the new SSO superuser path (interaction untested).
- **c8** Remove/soften the manual `update(is_superuser=True)` habit — it now fights the declarative sync.
- **c9** Reusable-group decision: `paperless-admins` is single-service; a shared `admins` group was not considered.
- **c10** Audit: no other relying party consumes `groups` yet, despite the geometry allow-list literature mentioning a groups fallback.

---

## d) TOTALLY FUCKED UP

| #  | Screw-up                                                                                                                                                                                                                                                                             | Impact                                                                                                                                                                                                  | Correct behaviour (AGENTS)                                                                                                         |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| d1 | **I wrote to a shared tree without content-pinning first.** I read each file's relevant context, but never ran `git rev-parse HEAD` + `git status --short` + `git log --stat` before editing.                                                                                        | My edits were **absorbed into a parallel session's commit `deab8469`**; I nearly duplicated a feature another agent was writing. Branch HEAD then churned through five auto-commits during the session. | "Content-pin BEFORE every write" (Session Discipline).                                                                             |
| d2 | **First answer asserted an absence that was wrong-incomplete.** I told the user "OIDC gives identity, not privileges … nothing maps a Pocket ID group to `is_superuser`" and offered a **custom oneshot** as option 1 — before checking whether paperless already ships the mapping. | Wasted a user turn; recommended a worse (custom-code) solution when a declarative, standard one existed in the pinned version.                                                                          | Verify library/config **capabilities** before asserting they don't exist. I only did the source verification on the _second_ turn. |
| d3 | **Did not detect the concurrent session until deep into the task.** The test file mock (mtime 03:03) and the mr-sync status doc were authored by another session; I only noticed after `git status` surprised me.                                                                    | Risk of racing another writer on `tests/test-paperless.nix`; my "verified on evo-x2" claim silently co-verified files I didn't author.                                                                  | "When the tree grows changes you didn't author, flag it to the user immediately."                                                  |
| d4 | **No test ran.** I claimed verification but only did eval + a derivation build. A feature touching login/authorization shipped with **no executable proof**.                                                                                                                         | High-confidence-but-unproven change on the auth path.                                                                                                                                                   | "TEST AFTER CHANGES."                                                                                                              |
| d5 | **Behavioural surprise not surfaced early.** Fail-closed demotion means the user's _manual_ superuser evaporates on next login. I documented it in the final message but not as a first-class warning when proposing the design.                                                     | User could be confused/locked out of admin ops after deploy.                                                                                                                                            | Lead with user-visible consequences.                                                                                               |

---

## e) WHAT WE SHOULD IMPROVE

1. **Content-pin ritual, enforced by reflex:** `git rev-parse HEAD && git status --short` as the _first_ command of any edit session on this repo, not the tenth.
2. **Capability-first research:** for "why doesn't X do Y", check X's own settings/changelog/source **before** proposing custom glue. The pinned paperless version already had the answer.
3. **Treat the auto-commit daemon + parallel sessions as the default** (AGENTS says so twice). Assume HEAD will move 3-5 times per session; re-read before every edit.
4. **Ship tests with the change**, not the mock only. A mock with no assertion is _worse_ than nothing — it looks like coverage.
5. **Docs in the same commit** as the behaviour (runbook + sso fact + CHANGELOG). Leave no grep-empty surface.
6. **Single source of truth for the group name** is good (achieved via `oidcAdminGroup`); extend the same discipline to the _member identity_ and to multi-service reuse.
7. **Surface fail-closed semantics as a warning**, and consider a sticky break-glass (sops `admin`) documented as the demotion safety net.
8. **Verify the delivery layer, not the intent:** assert the _token contains `groups`_, not just that the scope string is in the file.
9. **Don't leave an untracked status report + dirty foreign files** at session end without naming them to the user (I named them, late).

---

## f) UP TO 50 THINGS TO GET DONE NEXT

1. Add VM-test assertions: `groups` in the provider `SCOPE` (grep the bridged env file).
2. Add VM-test assertion: `PAPERLESS_SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP=paperless-admins` in the unit env.
3. Add VM-test assertion: `PAPERLESS_SOCIAL_ACCOUNT_SYNC_STAFF_GROUP=paperless-admins`.
4. Add VM-test assertion: `PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS_CLAIM=groups`.
5. Add a mock Pocket ID API server to assert Step 4 creates the group + syncs membership.
6. Add a negative test: declared member missing → provision unit exits non-zero (fail-loud).
7. Add a negative test: empty `memberUsernames` → `PUT … {userIds: []}` (converges to empty, no crash).
8. Run `nix run .#test` / the paperless `runNixOSTest` and record the result.
9. Run `nix flake check --no-build` for the whole tree in a quiet window.
10. `nix run .#deploy` and confirm `pocket-id-provision` journal shows "Group 'paperless-admins' membership synced".
11. After deploy, `curl`/API-verify the group exists with member `lars`.
12. After deploy, decode an ID token (or userinfo) and confirm `groups:["paperless-admins"]` is present.
13. Log in via passkey and confirm paperless promoted `lars` (journal `paperless.auth` role-sync line).
14. Test the demotion path: remove `lars` from the group, log in, confirm demotion (documents fail-closed).
15. Document `docs/services/paperless.md`: the group, the scope dependency, fail-closed demotion.
16. Document `docs/agents/sso-dns.md`: Pocket ID emits `groups` only with the `groups` scope.
17. Add `CHANGELOG.md` entry (new Pocket ID userGroups capability + Paperless mapping).
18. Harvest §f rows into `TODO_LIST.md` + `docs/todo/services.md` (test/doc/deploy obligations).
19. Decide group reuse: per-service `paperless-admins` vs a shared `admins` group.
20. Reconcile sops-`admin` break-glass with the SSO superuser path in the runbook.
21. Consider a `paperless-superuser` Gatus/post-deploy smoke (assert promotion, not just login).
22. Make the member identity configurable (option) rather than deriving from the Pocket ID admin user.
23. Add an eval assertion that `paperless-admins` is declared iff `paperless.enable && oidcProvisionEnabled`.
24. Add an eval assertion that the group name has no drift across scope/env/declaration (single-source check).
25. Confirm `group.name`'s claim value == the Django `SUPERUSER_GROUP` literal (both `paperless-admins`).
26. Consider `PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS=true` + Django groups for finer per-role mapping.
27. Document the first-login gap: allauth fires `social_account_added` (not `_updated`) on first login, so promotion lands on the **second** login (`models.py:241` vs `:355`).
28. Decide whether to close the first-login gap (tiny app connecting `social_account_added`, or accept two logins).
29. Consider `requiresReauthentication`/session-age interaction with role sync.
30. Audit other Pocket ID clients for whether they should request the `groups` scope.
31. Investigate using `PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS` for non-admin users.
32. Record the mechanism in `docs/agents/secrets.md`? (no — not secret-related; skip)
33. Add a runbook "how to add another admin" (add member to group, no manual DB).
34. Warn/document that manual `is_superuser=True` is transient now.
35. Consider a UI-visible confirmation (paperless admin shows superuser badge) as smoke.
36. Verify `email_verified` interaction: OIDC allow-lists elsewhere; ensure `groups` scope addition doesn't change email claims.
37. Ensure the `groups` scope doesn't break any existing Gatus login-body assertion.
38. Re-run the post-deploy SSO-button smoke after deploy.
39. Verify `pocket-id-provision` idempotency across repeated deploys (group exists path).
40. Confirm the provision unit's `restartTriggers` includes the new script path (it does via `lib.getExe provisionScript`).
41. Check shellcheck allows my generated bash (done) — re-run after any future edit.
42. Add the group to `pocket-id-backup` scope awareness (groups table is backed up).
43. Decide if group membership should be LDAP/sync-driven later.
44. Reviewer pass on the fail-closed choice (product decision).
45. Reviewer pass on `options ? services.pocket-id-config` merge-safety under `mkIf cfg.enable`.
46. Verify the same module evals for `aarch64-darwin` (paperless disabled) without the new option erroring.
47. Add a CHANGELOG "breaking/behavioural" note for fail-closed demotion.
48. Add a `docs/todo/services.md` item to retire the manual superuser step from any runbook.
49. Serialize/coordinate with the parallel Crush session (see question g1).
50. Post-session: confirm no foreign dirty files were left by me (`tests/test-dns-blocker-render.nix`, `scripts/check-todo-system.sh` are **not mine**).

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Is another Crush session active on this repo right now?** (It committed `deab8469` — which swept in my edits — plus `3e85cf1a`, and left `tests/test-dns-blocker-render.nix` / `scripts/check-todo-system.sh` dirty.) Should I **serialize** (stand down until it finishes) or continue and risk racing it on `tests/test-paperless.nix`?
2. **Fail-closed demotion — acceptable?** Once deployed, `lars` is superuser **only while in `paperless-admins`**; a missing/empty claim **demotes on login**, silently overwriting your manual `is_superuser=True`. Keep fail-closed, or do you want a **sticky/break-glass** superuser that survives an IdP hiccup?
3. **Deploy + verify now, or leave it to the other session?** The feature is committed but **undeployed and untested** (no VM run, no live round-trip). Should I drive `nix run .#deploy` + live verification + tests + docs, or hold?

---

_Session artifacts:_ feature in `deab8469`; test mock in `3e85cf1a`; my session's files verified clean in the tree at `d5ec0c8a`.

---

## Follow-up session (2026-10-01, same day) — §b/§c closed

The incomplete work above is now done. Commits are daemon-swept (tree clean at `edab9ea5`).

| §  | Item                                          | Outcome                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| -- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| b1 | Tests                                         | `tests/test-paperless.nix` gained three real assertions: provider `SCOPE` carries `"groups"` (greps the bridge env file), and `PAPERLESS_SOCIAL_ACCOUNT_SYNC_{GROUPS_CLAIM,SUPERUSER_GROUP,STAFF_GROUP}` render into the unit env. Plus an **eval drift guard** in `paperless.nix` (`config.assertions`): the mapped `oidcAdminGroup` must be declared in `provision.userGroups` — proven non-vacuous by an `extendModules` run that force-emptied the group and saw the assertion fire `false`. |
| b1 | **Pre-existing test bugs (found running it)** | (1) `jq` was never in the VM PATH → steps 10-13 had been unreachable since `851fb1d6`; added `environment.systemPackages = [ pkgs.jq ]`. (2) Step 13 asserted `Persistent=yes`, but Nix renders `Persistent=true` on disk; corrected. `nix build .#checks.x86_64-linux.paperless` is now **GREEN**. (Sibling bug remains in `tests/test-restic-app-dumps.nix:127`, same `Persistent=yes` text — not touched, flagged.)                                                                           |
| c1 | `docs/services/paperless.md`                  | New "Roles → superuser/staff via Pocket ID groups" section: settings table, single-source note, FAIL-CLOSED semantics, transient-manual-flag warning, and the first-login gap.                                                                                                                                                                                                                                                                                                                   |
| c2 | `docs/agents/sso-dns.md`                      | New fleet fact (sibling to `email_verified`): Pocket ID emits `groups` **only** with the `groups` scope.                                                                                                                                                                                                                                                                                                                                                                                         |
| c3 | `CHANGELOG.md`                                | Unreleased/Added entry (behavioural note + deploy-required).                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| c4 | Harvest                                       | §f.5-7 → one `[ready]` queue row + library row (mock Pocket ID API test); §f.10-14 → `[blocked:deploy]` row; §f.27-28 + §f.19/22 → `[decision]` rows. TODO_LIST.md + docs/todo/services.md edited together.                                                                                                                                                                                                                                                                                      |
| —  | First-login gap                               | Verified from source (`allauth/.../flows/signup.py` `process_signup` → `complete_signup` fires only `user_signed_up`; `models.py:355` fires `social_account_updated` only on the EXISTING-account lookup). Confirmed real; documented, not fixed (fixing needs custom Django glue the design deliberately avoids).                                                                                                                                                                               |
| c5 | Deploy + live verify                          | **Owner-run** (`nix run .#deploy` needs sudo; agent sandbox forbids). Full system build verified instead.                                                                                                                                                                                                                                                                                                                                                                                        |

### Harvest log (§f → surfaces)

- §f.1-4 → DONE (VM assertions).
- §f.5-7 → queue row + `docs/todo/services.md` `[ready]`.
- §f.8-9 → DONE (VM test run green; flake check green).
- §f.10-14 → `docs/todo/services.md` `[blocked:deploy]`.
- §f.15-18 → DONE (docs + CHANGELOG + this harvest).
- §f.19-28 → `docs/todo/services.md` `[decision]` rows.
- §f.29-50 → either done, folded into the rows above, or deliberately out of scope (e.g. §f.42 backup scope is unchanged by group data, §f.46 eval-parity is covered by the drift assertion's `options ?`-guard).
