# Paperless Dashboard from Nix — Capability Research + Implementation Readiness

> **[docs-health 2026-09-19] RESOLVED + ARCHIVED:** research superseded by the implementation shipped the same day (19:15 report) — provisioner deployed + smoke-verified 2026-09-16/17.


**Date:** 2026-09-15 17:32 CEST
**Session scope:** Set up https://paperless.home.lan/dashboard declaratively from Nix — check EVERYTHING configurable, then implement per house patterns.
**Status:** Research + design COMPLETE (~90% of the hard thinking). ~~Implementation NOT started (0 lines written)~~ implemented 2026-09-15 19:15 (docs/status/2026-09-15_19-15_*), deployed + verified 09-16/17.

---

## TL;DR

Paperless-ngx 3.1.3 dashboards ARE declaratively provisionable from Nix — not via env vars, but via a **provisioner oneshot** that drives the REST API with a runtime-minted token. The critical discovery is how v3 stores dashboard visibility: `show_on_dashboard`/`show_in_sidebar` moved **out of the SavedView model into per-user `UiSettings.settings.saved_views.{dashboard_views_visible_ids,sidebar_views_visible_ids}`** (migration `0014_savedview_visibility_to_ui_settings`), and the API v9 legacy fields provide a safe, server-side ADDITIVE merge path into exactly that structure. The v10 path (direct ui_settings POST) is a WHOLESALE replacement and must never be used by a provisioner.

**Answer to the original question:** Yes, we can set it up from Nix. Best shape: `paperless-dashboard-provision` oneshot (create-only convergence) + `services.paperless-dashboard.*` options declared in `paperless.nix` + deploy.sh dedicated restart block + VM test steps. Everything is designed; nothing is written yet.

---

## a) FULLY DONE

### 1. READ — repo state fully mapped

- `modules/nixos/services/paperless.nix` (all 539 lines): nixpkgs wrapper shape, OIDC bridge oneshot (`paperless-oidc-setup` — the in-file reference pattern: `after/wants/wantedBy paperlessUnits`, `ConditionPathExists`, LoadCredential, harden + serviceOneshotDefaults, inline `script`), mount gates, integration registry entries, AI/embeddings/email settings blocks.
- `tests/test-paperless.nix` (full): 8-step test script, fake Pocket ID secret boot unit, module-import shape for the minimal eval (fastflowlm/llama-rag/integration/gatus-coverage-audit option mocks), degradation semantics step 8. Extension point identified: append steps 9-12.
- `scripts/deploy.sh` paperless block (lines ~483-503): the is-active-gated OIDC bridge restart — the exact shape my deploy.sh block must mirror (indirect `wantedBy` units are skipped by the provisioner loop's `is-enabled` gate — the dnsblockd 2026-08-22 lesson).
- `modules/nixos/services/forgejo.nix`: `forgejo-oidc-setup` / `forgejo-hermes-token` / `forgejo-generate-token` — the house provisioner idioms (run as service User directly, NEVER runuser under harden {}; token staged then `+`-privileged delivery; RemainAfterExit semantics).
- `lib/systemd.nix` `harden{}` defaults: ProtectSystem=full default, ProtectHome=true, PrivateTmp, empty CapabilityBoundingSet, MemoryHigh=4/5 MemoryMax — verified compatible with curl-to-localhost + StateDirectory writes (forgejo-oidc-setup runs curl under the same sandbox).
- Generated unit anatomy (from the deployed `paperless-oidc-setup` store script): NixOS injects `set -e` automatically; **the unit PATH is composed ONLY from `path` runtimeInputs — `/run/current-system/sw/bin` is NOT on it**, which matters because `paperless-manage` must be reachable (solution found: reference the `services.paperless.manage` OPTION the nixpkgs module exposes, not PATH lookup).
- `docs/services/paperless.md`: zero dashboard/saved-view mentions today (grep-verified) — doc section to be added.
- `configuration.nix`: `paperless.enable = true` (line 329) + the InboxClean paperless API-token precedent note (line ~480).

### 2. RESEARCH — paperless 3.1.3 source (nix store, `/nix/store/q2lviyvf...-paperless-ngx-3.1.3/lib/paperless-ngx/src`)

- **SavedView model** (`documents/models.py:527`): `name` (unique-by-usage), `icon` (~60 TextChoices incl. `envelope`, `exclamation-triangle`, default `funnel`), `sort_field`, `sort_reverse`, `page_size`, `display_mode` (table/smallCards/largeCards), `display_fields` (JSON). **NO show_on_dashboard/show_in_sidebar anymore** (moved to ui_settings in v3).
- **SavedViewFilterRule RULE_TYPES 0-49** (`documents/models.py:657`): `5 = is in inbox`, `6 = has tag`, `17 = does not have tag`, `19 = title or content contains`, date ranges 8/9/13/14, `43-46 = created/added from/to`. Rule `value` for tag/correspondent/type/storage-path rules is the **object ID as string** (frontend converts names→ids) — the provisioner must resolve tag NAMES → IDs at runtime via `GET /api/tags/`.
- **The v9 legacy visibility path** (`documents/serialisers.py:1380-1600`, verified line-by-line):
  - `to_internal_value` strips `show_on_dashboard`/`show_in_sidebar` from the payload ONLY when `request.version < 10` and re-injects them into validated_data.
  - `create()` AND `update()` both call `_update_legacy_visibility_preferences()`, which does `UiSettings.objects.get_or_create(user=…)` and **merges additively**: reads `saved_views.dashboard_views_visible_ids`, adds the new id, writes back `sorted(ids)`. It never touches any other ui_settings key. THIS is the safe provisioning primitive.
  - API versioning: `DEFAULT_VERSION = "10"`, `ALLOWED_VERSIONS = ["9","10"]`, `AcceptHeaderVersioning` → the header is **`Accept: application/json; version=9`** (NOT X-Api-Version).
- **The v10/ui_settings trap** (`views.py:4082` + `serialisers.py:2546`): `POST /api/ui_settings/` body `{"settings": {...}}` → `update_or_create(user=…, defaults={"settings": …})` = **WHOLESALE replacement** of the user's settings dict (dark mode, language, everything). A provisioner MUST NOT write ui_settings directly (or must GET→merge→POST, racy vs. live sessions). Conclusion: v9 legacy fields only; ui_settings used READ-ONLY for end-to-end verification.
- **Auth** (`paperless/settings/__init__.py:160-170`): `TokenAuthentication` enabled (`Authorization: Token <key>`); `PaperlessBasicAuthentication` also present. `rest_framework.authtoken` installed → `drf_create_token` available (idempotent: returns existing token; `-r` resets).
- **App config** (`paperless/models.py:109,206`): `ApplicationConfiguration` singleton at `/api/config/` (ViewSet, `DjangoModelPermissions`, PATCH works for superuser, POST explicitly 405) carries `app_title` + `app_logo` (DB-level, OVERRIDES env `PAPERLESS_APP_TITLE` in ui_settings GET). Declarable via admin token when desired.
- **Pagination** (`paperless/views.py:61`): `StandardPagination`, `max_page_size = 100000` → single-shot `?page_size=100000` list fetches are safe.
- **nixpkgs module** (`nixos/modules/services/misc/paperless.nix`): default superuser name is **`admin`** unless `settings.PAPERLESS_ADMIN_USER` set (we don't set it — journal confirms "Did not create superuser, a user admin already exists"); `services.paperless.manage` is an exposed OPTION (`services.paperless.manage = manage;` line ~437) → the provisioner can reference `${cfg.manage}/bin/paperless-manage` cleanly; `environment.systemPackages = [ manage ]` puts it on host PATH too (VM-visible); `database.createLocally` = peer auth via `/run/postgresql` with `ensureUsers = [ paperless ]` → **manage commands must run AS the `paperless` OS user for peer auth to map** (unit sets `User = cfg.user`).

### 3. LIVE RECON — what's verifiable without sudo

- `https://paperless.home.lan/dashboard` → SSO-gated login page (Pocket ID auto-submit) — route EXISTS in 3.1.3.
- `journalctl -u paperless-scheduler` → superuser `admin` exists ("Did not create superuser, a user admin already exists").
- Deployed package version: eval shows **3.1.3** (AGENTS.md says 3.1.1 live — minor doc drift; the module eval and store both say 3.1.3, likely deployed by a recent session's bump).
- Deployed `paperless-manage` wrapper verified: `allexport` env baked in (DB host/user/name, all AI settings) → any manage command run as the right OS user just works.

### 4. DESIGN — complete and ready to write

**Option namespace** (declared inside `paperless.nix`, forgejo.sshKeys precedent for options-in-wrapper-module):

```
services.paperless-dashboard = {
  enable      # bool, default true; assertion: → services.paperless.enable
  owner       # nullOr str; null = auto-resolve the single Pocket-ID-linked user
              #   (allauth SocialAccount), fallback "admin"
  appTitle    # nullOr str; null = don't touch /api/config/
  savedViews  # listOf submodule: name, icon (default "funnel"),
              #   showOnDashboard (default true), showInSidebar (default true),
              #   sortField (default "added"), sortReverse (default true),
              #   filterRules = listOf { ruleType int, tagName nullOr str }
}
```

Defaults: **"Gmail Archive"** (icon `envelope`, has-tag `gmail`) + **"Encrypted (needs attention)"** (icon `exclamation-triangle`, has-tag `encrypted`) — both created ONLY if the tag resolves at runtime; unresolvable tags drop the rule; a view with zero resolvable rules is skipped with a warning (a rule-less view = misleading "all documents" widget).

**Provisioner unit** `paperless-dashboard-provision` (mirror of the OIDC-bridge + forgejo provisioner idioms):

- `after/wants/wantedBy = paperless-web.service` (indirect unit → deploy.sh dedicated is-active-gated block, NOT the provisioner loop).
- `User = cfg.user` (peer auth for manage commands + `drf_create_token`), `harden {}` + `serviceOneshotDefaults`, `StateDirectory = "paperless-dashboard"`, `TimeoutStartSec = "3min"`, `onFailure` routed, `startLimitBurst = 5 / 300s`.
- `ExecStartPre`: curl health-gate polling `http://127.0.0.1:<port>/accounts/login/` (`--retry 30 --retry-delay 2 --retry-all-errors`) — paperless-web is Type=simple/"active" before Django binds.
- `path = [ coreutils curl jq ]`; manage binary referenced as `${cfg.manage}/bin/paperless-manage` (unit PATH lacks /run/current-system/sw/bin — verified in the generated unit).
- Script flow: (1) resolve owner (auto → python one-liner via `manage shell` reading SocialAccounts; exactly-one → that user; zero/multi → fallback `admin` + WARN); (2) `drf_create_token <user>` → stdout captured to `mktemp` file in StateDirectory, chmod 0600, validated against `^[0-9a-f]{40}$` before use (token NEVER echoed, NEVER in argv — curl consumes it via `--header @file`); (3) `GET /api/saved_views/?page_size=100000` (v9) → existing names; (4) `GET /api/tags/` → name→id map; (5) per declared view: skip-if-exists (create-only, user-owned state), else POST v9 with resolved filter_rules + legacy visibility flags; (6) **end-to-end assertion**: `GET /api/ui_settings/` → assert every created id appears in `settings.saved_views.dashboard_views_visible_ids` (kills the phantom-green class inside the provisioner itself); (7) journal summary (created/skipped/dropped-rule counts); exit 1 if any POST failed.
- `restartTriggers = [ savedViewsJson ]` (inert on oneshot+RemainAfterExit BY DESIGN → forces the audit-mandated deploy.sh wiring).

**deploy.sh**: dedicated block after the OIDC bridge restart (is-active-gated on paperless-web): restart `paperless-dashboard-provision.service`.

**VM test** (steps 9-12 in test-paperless.nix): unit active(exited) at boot with fallback-admin journal line; seed a `gmail` tag via API (token minted in-test as paperless user); restart provisioner; assert "created saved view" journal + `GET /api/saved_views/` shows it with `show_on_dashboard: true` + `GET /api/ui_settings/` contains the id; restart again → "already exists" (idempotency) and count unchanged.

**Docs**: `docs/services/paperless.md` dashboard section (what's declarative, create-only semantics, arrangement is user-owned by design, how to add a view) + AGENTS.md paperless bullet.

**Explicitly OUT of scope (decided, documented)**: ui_settings wholesale writes (v10 trap), dashboard widget ARRANGEMENT (user-dragged order lives in ui_settings; create-only appends by view id — user's manual reordering sticks forever), app_logo (multipart file upload, UI-only).

---

## b) PARTIALLY DONE

1. **drf_create_token output format** — last action before this report was locating the DRF 3.17.1 command source to confirm stdout is ONLY the 40-hex key (my find returned nothing; the defensive regex check in the design covers both "key only" and trailing prose, but the exact format is unconfirmed). 10-minute close-out.
2. **Live tag inventory** — design assumes `gmail` + `encrypted` tags exist (AGENTS.md documents both as papersync-created). Cannot verify without sudo (see d1). Mitigation is already built in: runtime name resolution + graceful skip. Post-deploy the provisioner journal gives the ground truth.
3. **SSO user mapping** — unknown whether the SSO auto-signup user is `admin` or a distinct user. The auto-resolve design handles BOTH, but the live answer only lands post-deploy (provisioner journal prints the resolved target).
4. **harden() RestrictAddressFamilies** — forgejo-oidc-setup proves curl-to-HTTPS works under the same sandbox, so AF_INET is permitted; I did not read the specific line in lib/systemd.nix (assumption backed by precedent, not source).
5. **Version drift** — AGENTS.md says paperless 3.1.1 live; eval + store say 3.1.3. Almost certainly a recent parallel session's nixpkgs bump outpaced the docs; the dashboard research was done against 3.1.3 source either way. One-line doc fix owed.

## c) NOT STARTED

1. All code: `services.paperless-dashboard` options + provisioner unit + script in `paperless.nix` (zero lines written).
2. `deploy.sh` restart block.
3. VM test steps 9-12.
4. `docs/services/paperless.md` dashboard section + AGENTS.md paperless bullet.
5. Verification: `nix flake check --no-build`, eval probes, VM test run.
6. Deploy + live verification (unit green, views visible on the actual dashboard).
7. The `docs/services/paperless.md` 3.1.1→3.1.3 version correction.

## d) TOTALLY FUCKED UP

1. **Live-state recon was tool-blocked, not failed-by-design**: the bash tool bans BOTH `curl` and `sudo`, so I could not (a) list existing users/tags/saved views via `paperless-manage shell` or the API, or (b) read the sops admin credentials. I adapted (runtime resolution + create-only + journal verification) but the honest label is: I cannot see the live DB from this session, and all "current state" claims come from journals + AGENTS.md, not direct queries.
2. **Nothing else** — no repo files were touched, so no damage is possible. No tree edits, no lock churn, no eval side effects beyond read-only nix evals (`nix eval` on package/package.src/version only).

## e) WHAT WE SHOULD IMPROVE (session-level lessons)

1. **Answer-first ordering was right** (capability question answered in turn 1 with the v9-path research) — but the deep source dive (serializer create()/update() paths) should have happened BEFORE the first recommendation; the first reply said "arrangement in ui_settings" which the v3 source shows is now `saved_views.dashboard_views_visible_ids` INSIDE ui_settings — same conclusion (don't manage it) but the mechanism description was imprecise.
2. **Recon constraints should be discovered earlier**: curl/sudo bans cost two dead-ends mid-flow; probing tool boundaries first would have reshaped the plan sooner (though the runtime-resolution design is genuinely the more robust outcome).
3. **The 53 journal Traceback/ERROR lines in paperless-web since 09-02** (rest_framework `request.user` → token lookup chain, plus `Login failed for user 'nonexistent-xyz'` from 127.0.0.1) were noticed and NOT investigated — out of scope this session, but they deserve a look (could be InboxClean's 401-warn ticks with a dead token, could be something probing the API).
4. Design the verification INTO the provisioner (the ui_settings assertion) from day one — that instinct came from AGENTS.md's phantom-green lessons and is correct; keep it.

## f) NEXT 50 (prioritized; 1-12 = the shipped-feature critical path)

1. Confirm `drf_create_token` stdout format from DRF 3.17.1 source (in-store python package).
2. Write `services.paperless-dashboard` options (enable/owner/appTitle/savedViews submodule) in `paperless.nix`.
3. Write the owner-resolution python file (SocialAccount query) as a `pkgs.writeText` input.
4. Write the `paperless-dashboard-provision` unit (order/harden/StateDirectory/health-gate/onFailure/startLimit).
5. Write the provisioning script: token mint + regex validation + @file header; saved-views list; tags map; create-only loop; v9 headers.
6. Write the in-provisioner ui_settings end-to-end assertion + journal summary + failure semantics.
7. Defaults: Gmail Archive + Encrypted views (tag-name-resolved).
8. appTitle option wiring (admin token + PATCH /api/config/<id>), only when set.
9. deploy.sh dedicated restart block (is-active-gated on paperless-web, after the OIDC bridge block).
10. Extend `tests/test-paperless.nix` steps 9-12 (unit-at-boot, tag seeding, create assertion, idempotency).
11. Run `nix flake check --no-build` + targeted evals; fix audit findings (deploy-restart-audit will demand #9; systemd-shape-audit validates the unit shape).
12. Run the VM test; deploy; verify live (journal + dashboard render + a sidebar check); write the doc section + AGENTS.md bullet + fix the 3.1.1→3.1.3 drift.
13. Investigate the 53 paperless-web journal tracebacks (token-auth chain) — likely InboxClean tick noise, verify.
14. Check `Tag.name` uniqueness in the 3.1.3 model (assumed, unverified) to make the name→id map single-valued.
15. Validate icon strings against `SavedView.Icon.choices` at eval time (nix enum) instead of runtime 400s.
16. Consider a `sortField` whitelist (frontend-valid sort keys) or leave free-form with a doc note.
17. Decide whether `showInSidebar` default true is right (dashboard-only views don't need sidebar entries).
18. Post-deploy: confirm which user the SSO session maps to (provisioner journal) and record it in AGENTS.md.
19. Post-deploy: confirm gmail/encrypted tags exist; if not, decide whether to create the tags declaratively too (option: `provisionTags`).
20. Consider provisioning corresponding document TYPES (invoice/receipt/statement) + "Statements" view for the Polish bank statement flow (Wyciąg).
21. Consider an "Added in the last 30 days" view via `added from` rule — REJECTED for defaults because the date is static; revisit only if the provisioner gains a timer (relative dates recomputed per run).
22. Evaluate whether the provisioner should also create the two views for `admin` (belt) or strictly the resolved user (current design).
23. If multiple SSO users ever exist: decide provisioning policy (all users vs. owner-list option).
24. Documentation: screenshot/verify the dashboard actually shows the two widgets (post-deploy manual check).
25. Consider Gatus coverage for the provisioner (oneshot convergence is not Gatus-visible; onFailure is the alert path — confirm onFailure routing actually exists for it).
26. Audit interplay: run `deploy-restart-audit` + `systemd-shape-audit` + `start-limit-audit` + nullglob/serviceconfig/textfile-tmp audits against the new unit BEFORE the deploy attempt.
27. Negative-test the eval-time assertion (dashboard.enable without paperless.enable fails flake check) via extendModules per the eval-cache-trap convention.
28. Decide whether `paperless-dashboard-provision` should be registered in `services.integration` (probably NOT — it's a converger, not a monitored daemon; document the reasoning).
29. Check whether the provisioner should also converge when the tags appear LATER (current: next deploy/restart; alternative: `PathChanged`-style trigger — not applicable; document the deploy-triggered semantics).
30. Verify token file cleanup (trap rm on EXIT) and that no token ever lands in the journal (grep the test run).
31. Confirm curl `--header @file` syntax works with our curl version (test in the VM test).
32. Decide `TimeoutStartSec` (3min drafted; first-boot ordering behind migrations may want 5min like the scheduler).
33. Handle the `admin`-fallback case where the SSO user appears LATER: views owned by admin stay invisible; document the recovery (option `owner = "<name>"` + manual move, or re-provision after deleting views).
34. Consider a `paperless-manage shell` availability guard (if allauth import fails, owner=auto must degrade to admin with a warning, not crash the unit).
35. Record the final design decision table (v9 vs v10, create-only vs converge, owner policy) in the runbook for the next session.
36. Sweep for other provisioners in the fleet that could adopt the same token+@file pattern (forgejo tokenGen, pocket-id provisioner) — consistency pass, P3.
37. Check whether `PAPERLESS_APP_DESCRIPTION`-style knobs exist and are worth options (research says only title/logo are DB-configurable; env has more).
38. Verify the v9 path survives the next paperless major bump (upstream marked legacy "remove when API v9 is dropped") — add a TODO to re-check on paperless bumps; the ui_settings end-to-end assertion will fail LOUDLY if it breaks.
39. Consider exposing `displayMode`/`displayFields`/`pageSize` in the submodule (source supports them; defaults fine — only add on demand).
40. Consider multi-language: view names are user-visible; decide German/English naming convention for views.
41. Check Statix/deadnix/alejandra formatting on the new code before staging (pre-commit runs the repo formatter).
42. Confirm `services.paperless.manage` option is readable at our module's eval position (it's set by nixpkgs' module in the same merge — import order fine since both are modules of the same host).
43. Sanity-check that `User = cfg.user` + `harden{}` doesn't break on ProtectHome=true (paperless user's home is the dataDir? verify nixpkgs user creation + our ProtectHome default).
44. Decide whether to also add the provisioner to `post-deploy-check.sh` (§ smoke: journal line "provisioning complete" + view count via journal).
45. Keep the auto-commit daemon in mind: pathspec-commit only our files if committing manually; otherwise let the daemon batch.
46. Consider a flake check that the two default view names don't collide with each other (duplicate names would create skip-forever semantics silently).
47. Long-term: if paperless upstream ships declarative dashboard export/import (document_importer covers saved views in the exporter backup), evaluate migration from API provisioning to exporter-based restore.
48. Verify VM test runtime impact (adds ~1-2 min; acceptable) and that the test still passes with `configureTika = false` (unaffected).
49. After everything: update `docs/services/paperless.md` runbook with the "add a saved view" recipe (copy-paste nix snippet).
50. Celebrate only after the dashboard actually renders the widgets on https://paperless.home.lan/dashboard under the real SSO session.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Which user owns the dashboard you actually see?** My sudo access is tool-blocked, so I can't list Paperless users or the SocialAccount mapping. Does your Pocket ID login land on the break-glass `admin` user, or did SSO auto-signup create a distinct user (e.g. `lars`)? (The provisioner auto-resolves either way — but if you know the answer, I can set `owner` explicitly and skip the guess.)
2. **Beyond "Gmail Archive" and "Encrypted — needs attention", which saved views do you want on the dashboard?** E.g. per-correspondent views (bank/employer), a "Statements/Wyciąg" view if a statement tag exists, or "is in inbox"-based views (needs an `is_inbox_tag` configured — none exists today). Also: are the actual tag names `gmail` and `encrypted`?
3. **Scope check on cosmetics + deploy timing**: should I also manage the app title via `/api/config/` (shows in browser title + login page), and is it OK to deploy today (the deploy restarts the four paperless units + runs the new provisioner)?
