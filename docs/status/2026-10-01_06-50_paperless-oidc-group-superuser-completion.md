# Status: Paperless SSO → superuser (Pocket ID groups) — COMPLETION session

**Date:** 2026-10-01 06:50 CEST
**Session model:** Crush (resumption of the 03:37 session)
**Trunk at report time:** `4c3702f2` (my edits are daemon-swept; tree carries FOREIGN dirty files — see §b4)
**Scope of THIS session:** finish the incomplete work of `docs/status/2026-10-01_03-37_paperless-oidc-group-superuser-mapping.md` — tests, docs, CHANGELOG, harvest, verification gates. The **feature itself was already committed** (`deab8469`) by the prior/parallel session; I did NOT re-implement it.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **VM test now asserts the OIDC role mapping.** Three real assertions in `tests/test-paperless.nix`: `PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS_CLAIM=groups`, `…_SYNC_SUPERUSER_GROUP=paperless-admins`, `…_SYNC_STAFF_GROUP=paperless-admins` (read from `systemctl show paperless-web --property=Environment`), plus a grep of the bridge env file for the provider `"groups"` scope. | `tests/test-paperless.nix:227-229,266` |
| a2 | **`checks.x86_64-linux.paperless` is GREEN.** Full `runNixOSTest` VM run passes end-to-end. | `nix build .#checks.x86_64-linux.paperless --no-link` → EXIT=0 |
| a3 | **Two PRE-EXISTING test bugs fixed (the test had been red since `851fb1d6`).** (1) `jq` was never in the VM root PATH → steps 10-13 unreachable; added `environment.systemPackages = [ pkgs.jq ]`. (2) Step 13 asserted `Persistent=yes`, but Nix renders `Persistent=true` on disk (systemd normalizes only at runtime); corrected. | `tests/test-paperless.nix:139,361`; rendered unit `/nix/store/44dh7bz…-unit-paperless-db-backup.timer` shows `Persistent=true` |
| a4 | **Eval drift guard** in `paperless.nix`: if `oidcEnabled && oidcProvisionEnabled`, the mapped `oidcAdminGroup` MUST be declared in `services.pocket-id-config.provision.userGroups`. | `modules/nixos/services/paperless.nix:380-392` |
| a5 | **Drift guard proven NON-VACUOUS.** A throwaway `extendModules` that force-emptied the group made `builtins.all (x: x.assertion) config.assertions` return `false` (the guard fired). | `nix eval --impure … extendModules { userGroups = mkForce []; }` → `false` |
| a6 | **Runbook section** `docs/services/paperless.md`: settings table, single-source note, FAIL-CLOSED semantics + transient-manual-flag warning, and the first-login gap. | `docs/services/paperless.md` (new "Roles → superuser/staff via Pocket ID groups" §) |
| a7 | **Fleet fact** in `docs/agents/sso-dns.md`: Pocket ID emits `groups` only with the `groups` scope (sibling to the `email_verified` fact). | `docs/agents/sso-dns.md:44` |
| a8 | **CHANGELOG** Unreleased/Added entry (behavioural + deploy-required). | `CHANGELOG.md` |
| a9 | **TODO harvest** (queue row + library rows + status-report harvest log). | `TODO_LIST.md` (services §), `docs/todo/services.md` (5 rows), append to the 03:37 report |
| a10 | **First-login gap verified from pinned source** (not assumed): allauth auto-signup path fires only `user_signed_up`, `social_account_added` fires only on `connect()`, and paperless connects only `social_account_updated`. | allauth 65.19.3 `internal/flows/signup.py` (`process_signup`→`complete_signup`), `models.py:241/355`, paperless `apps.py` |
| a11 | **Verification gates all green**: `nix flake check --no-build`, evo-x2 toplevel BUILD, toplevel `drvPath` eval, repo `treefmt` (0 changed), `scripts/check-todo-system.sh` (structure clean). | see §a11 commands in §d/e |

---

## b) PARTIALLY DONE

| # | Item | State | Missing |
|---|------|-------|---------|
| b1 | **Live deploy + runtime verification** | NOT RUN — blocked (§g1). | `nix run .#deploy` (owner-run; sandbox forbids sudo) then: journal "membership synced", token `groups:["paperless-admins"]`, passkey promotion, demotion path. The feature is **undeployed** as of this report. |
| b2 | **First-login gap** | Documented + source-verified (a6/a10). | Not closed. Closing needs a small Django app connecting `user_signed_up` → paperless's handler — the custom glue the design deliberately avoids. |
| b3 | **VM coverage for provisioner Step 4** | Only "the rendered script CONTAINS `paperless-admins`" would be checkable — and even that failed because the VM's option-only mock has NO provisioner unit. Assertion removed; replaced by the eval drift guard (a4). | A mock Pocket ID HTTP server to exercise create / idempotent re-run / authoritative PUT / fail-loud missing member (queued as `[ready]`). |
| b4 | **Concurrency attribution** | Diagnosed again this session. | The tree at report time holds FOREIGN dirty files — `CHANGELOG.md`, `FEATURES.md`, `TODO_LIST.md`, `docs/services/bank-sync.md`, `docs/todo/services.md`, `modules/nixos/services/bank-sync.nix`, `sops.nix`, `configuration.nix`, `tests/test-bank-sync-paperless.nix`, and a **staged deletion** `platforms/nixos/secrets/bank-sync-paperless.yaml` — all from a parallel bank-sync session, NOT mine. My edits are committed (clean). |

---

## c) NOT STARTED

- **c1** Live post-deploy verification of the mapping (b1) — the whole point of "works automatically".
- **c2** Break-glass reconciliation: the sops `admin` account vs the new SSO superuser path (interaction untested).
- **c3** Group-reuse decision: per-service `paperless-admins` vs a shared `admins` group.
- **c4** Member-identity option: currently derived from `provision.adminUser.username`; not configurable.
- **c5** Audit other Pocket ID clients for whether they should request `groups`.
- **c6** Gatus / post-deploy smoke asserting *promotion* (not just that the login page renders).
- **c7** Idempotency proof of `pocket-id-provision` Step 4 across repeated deploys (group-exists path).
- **c8** `nix eval` parity check for `aarch64-darwin` (paperless disabled) with the new assertion — not run.

---

## d) TOTALLY FUCKED UP

| # | Screw-up | Impact | Correct behaviour (AGENTS) |
|---|----------|--------|----------------------------|
| d1 | **Ran a STANDALONE store alejandra (`4.0.0`, not the repo formatter) on my two .nix files.** It reformatted the ENTIRE files (paperless.nix: 2012 lines changed). | Huge spurious diff; would have polluted history. | Use `.#formatter.$sys`'s treefmt ONLY (the pre-commit hook does exactly this). Recovered via `git restore` to HEAD; then confirmed the repo treefmt reports **0 changed**. |
| d2 | **Wrote a VM assertion that could never pass**: grepped `systemctl cat pocket-id-provision.service` for `paperless-admins`. | Wasted a full VM test cycle (~3 min). | The test imports only an option-mock, not `pocket-id.nix`, so no unit exists. Verify the OBJECT exists before asserting on its contents. |
| d3 | **Did not baseline the VM test before adding assertions.** It had been red since `851fb1d6` (missing `jq`). | Three separate red test cycles to peel `jq` → `Persistent=yes` → green. | "TEST AFTER CHANGES" means run the SUITE FIRST to know the baseline, then your change. |
| d4 | **No content-pin at session start.** HEAD churned ~5 times and the daemon swept my edits mid-flight. | Attribution fog; only diagnosed later. | "Content-pin BEFORE every write" (Session Discipline) as the *first* command. |
| d5 | **Edited `docs/status/2026-10-01_03-37_*.md` (a prior session's report) in place** to add a follow-up + harvest log. | Acceptable (append-only ANNOTATE), but I did not explicitly flag it as an annotation. | Use the docs-health ANNOTATE pattern and say so; never rewrite others' reports. |

---

## e) WHAT WE SHOULD IMPROVE

1. **Baseline the test suite BEFORE editing it.** A red-on-arrival test turns your change's signal into noise.
2. **Only the repo formatter formats.** `.#formatter.<system>` (treefmt) is the single source; any standalone alejandra is a second formatter with a different style (this is literally documented in the pre-commit hook at `.githooks/pre-commit:319-327`).
3. **Assert on objects that exist in the eval scope.** The VM's option-only mock pattern is a trap for unit-content assertions.
4. **Prefer eval-time guards** (like a4) over VM-script greps when the property is static — cheaper, faster, and it can't be "unreachable".
5. **Content-pin reflex**, then work.
6. **Name the foreign dirty files immediately** (b4) — I named them, but late again.
7. **Hand the deploy over with the exact verification commands**, not a vague "deploy it".
8. **When a test asserts a rendered-value spelling (`yes` vs `true`), check the ACTUAL rendered unit** — the Nix→systemd boolean rendering is a known trap.

---

## f) UP TO 50 THINGS TO GET DONE NEXT

1. `nix run .#deploy` (owner-run) — the feature is undeployed.
2. Verify `pocket-id-provision` journal: "Group 'paperless-admins' membership synced".
3. API-verify the group exists with member `lars`.
4. Decode an ID token / userinfo → `groups:["paperless-admins"]` present.
5. Passkey login → confirm `lars` promoted (journal `paperless.auth` role sync).
6. Demotion test: remove `lars` from the group, log in, confirm demotion.
7. Add a post-deploy smoke asserting *promotion*, not just the login page.
8. Mock Pocket ID HTTP server for the VM test (Step 4 end-to-end).
9. Negative VM test: declared member missing → provision unit exits non-zero.
10. Negative VM test: empty `memberUsernames` → `PUT {userIds: []}`, no crash.
11. Decide whether to close the first-login gap (custom Django app) or accept two logins.
12. Make the group member identity a first-class option.
13. Decide per-service `paperless-admins` vs shared `admins`.
14. Reconcile the sops `admin` break-glass with the SSO superuser path.
15. Audit other Pocket ID clients for the `groups` scope.
16. Fix `tests/test-restic-app-dumps.nix:127` (`Persistent=yes` → `Persistent=true`) — same latent bug.
17. Grep the whole `tests/` tree for other `Persistent=yes` / Nix-boolean-spelling assumptions.
18. Grep `tests/` for micro-tools used in testScripts but absent from the VM PATH (the `jq` class).
19. Add a CI leg that actually runs the makeTest VM tests (many are "PSI-gated" and never run).
20. Run `nix eval` parity for `aarch64-darwin` with the new assertion.
21. Add an eval assertion that the group is declared IFF `paperless.enable && oidcProvisionEnabled`.
22. Confirm the claim name (`group.name`) equals the Django `SUPERUSER_GROUP` literal (single-source check).
23. Consider `PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS=true` + Django groups for finer mapping.
24. Document `PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS` for non-admin users.
25. Add a "how to add another admin" runbook recipe (group member, no manual DB).
26. Verify the `groups` scope addition does not disturb email/`email_verified` claims.
27. Verify it does not break the existing Gatus login-body assertion.
28. Re-run the post-deploy SSO-button smoke after deploy.
29. Verify `pocket-id-provision` idempotency across repeated deploys.
30. Confirm `restartTriggers` include the new script path (it does via `lib.getExe provisionScript`).
31. Re-run shellcheck on the generated provisioner after any future edit.
32. Add group data to `pocket-id-backup` scope awareness.
33. Reviewer pass on the fail-closed choice (product decision).
34. Reviewer pass on `options ? services.pocket-id-config` merge-safety under `mkIf`.
35. Consider a sticky/break-glass superuser that survives an IdP hiccup.
36. Warn more loudly that manual `is_superuser=True` is transient.
37. Add a UI-visible confirmation (admin badge) as a promo smoke.
38. Decide LDAP/sync-driven membership later.
39. Document session-age/reauth interaction with role sync.
40. Harvest this report's §f into the queue/library (docs-health HARVEST).
41. Correct the "verified on evo-x2" claim in the 03:37 report to cite the eval surfaces.
42. Add an eval guard against group-name drift between SCOPE, env, and declaration.
43. Move the role-mapping settings into a small typed submodule (data-model hygiene).
44. Add a `docs/services/pocket-id.md` runbook (it has none) covering `provision.userGroups`.
45. Add the Step-4 mechanism to `docs/agents/integration-registry.md`.
46. Consider a generic `groups`-claim helper option for other relying parties.
47. Add a CHANGELOG "behavioural" sub-entry explicitly for fail-closed demotion if not already clear.
48. Retire the manual superuser step from any runbook still naming it.
49. Coordinate/serialize with the parallel bank-sync session (b4) before any deploy.
50. Post-session sweep: confirm no foreign files were left by me.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy authority & concurrency.** A parallel bank-sync session has the tree dirty (incl. a STAGED deletion of `platforms/nixos/secrets/bank-sync-paperless.yaml`). Is it safe for you to run `nix run .#deploy` now, or should we wait until that session finishes / commits? (I cannot deploy — sudo is forbidden in my sandbox.)
2. **Fail-closed demotion — keep it?** Once deployed, `lars` is superuser ONLY while a member of `paperless-admins`; a missing/empty claim DEMOTES on login and silently overwrites any manual `is_superuser=True`. Keep fail-closed, or add a sticky/break-glass superuser?
3. **First-login gap — close it?** A brand-new SSO user is promoted on the SECOND login (upstream allauth/paperless behavior). Accept/document it, or should I add a small Django app connecting `user_signed_up` to paperless's role handler (custom glue, second source of truth)?

---

## Verification commands (this session)

```
nix eval  .#nixosConfigurations.evo-x2.config.services.pocket-id-config.provision.userGroups --json   # → [{name="paperless-admins",…}]
nix eval  --json --apply 'c: c.config.services.paperless.settings' .#nixosConfigurations.evo-x2        # → 3× PAPERLESS_SOCIAL_ACCOUNT_SYNC_*
nix eval  --json .#nixosConfigurations.evo-x2.config.assertions --apply 'a: builtins.all (x: x.assertion) a'   # → true
nix eval  --impure … extendModules { provision.userGroups = mkForce []; }                              # → false (guard fires)
nix build .#checks.x86_64-linux.paperless --no-link                                                    # → EXIT 0 (VM test GREEN)
nix flake check --no-build                                                                             # → all checks passed
nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --no-link                          # → EXIT 0
$(nix build .#formatter.x86_64-linux --print-out-paths --no-link)/bin/treefmt <my files>               # → 0 changed
bash scripts/check-todo-system.sh                                                                      # → structure clean
```

---

*Session artifacts:* feature pre-existing in `deab8469`; test/assertion/docs/harvest edits landed in daemon commits (tree clean for my files at `4c3702f2`). Report format: **Markdown** (user-requested override; the status-report skill's default is HTML).
