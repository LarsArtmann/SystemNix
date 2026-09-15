# Paperless Dashboards from Nix — Implementation Status

**Date:** 2026-09-15 19:15 CEST
**Task:** Set up Paperless-ngx dashboards (https://paperless.home.lan/dashboard) declaratively from Nix, comprehensively, step-by-step, verified.
**Phase:** Implementation ~90% complete and committed (by the auto-commit daemon). VM test FAILED with a diagnosed, well-understood bug — fix designed, not yet applied. Deploy blocked by an UNRELATED parallel-session issue.

---

## a) FULLY DONE (this session, all committed)

### 1. Research — 100% closed (was ~95%)

Every prior open research item was closed at source level:

- **`drf_create_token` stdout format** (the last open item): located DRF 3.17.1 in the store (`/nix/store/n76lhn0km1d0m9xp5wf3i4xrkpv79bw9-python3.14-djangorestframework-3.17.1/.../drf_create_token.py:44`): stdout is `Generated token <40-hex-key> for user <username>` — the key must be EXTRACTED (`grep -oE '[0-9a-f]{40}'`), not assumed to be the whole output. The script implements exactly that plus a `^[0-9a-f]{40}$` validation.
- **`harden{}` RestrictAddressFamilies**: NOT set by `harden` at all (lib/systemd/service-defaults.nix:41 documents it as service-specific) → systemd defaults allow AF_INET → curl-to-localhost is fine under the sandbox.
- **Serializer contracts re-verified in paperless 3.1.3 source**: `SavedViewSerializer.fields` (name/icon/sort_field/sort_reverse/filter_rules/...), `SavedViewFilterRuleSerializer` = `["rule_type", "value"]` (snake_case, tag value = id as string), v9 legacy visibility path (`to_internal_value` keeps `show_on_dashboard`/`show_in_sidebar` when version < 10; `create()`/`update()` call the ADDITIVE `_update_legacy_visibility_preferences` merge into `UiSettings.saved_views.dashboard_views_visible_ids`), `AcceptHeaderVersioning` with `DEFAULT_VERSION=10`, `ALLOWED_VERSIONS=["9","10"]` → header `Accept: application/json; version=9`.
- **Icon enum extracted** from `SavedView.Icon` (56 values, including the non-obvious `globe2`/`wallet2`) — now an eval-time `types.enum`.
- **Tag names are NOT unique at DB level** (tree tags, `documents/models.py`) — the script resolves name→id with exact-match-first-hit via jq (deterministic).
- **`ui_settings` GET shape**: `{"user": ..., "settings": {...}, "permissions": ...}` — the in-provisioner assertion path `.settings.saved_views.dashboard_views_visible_ids` is correct.
- **`/api/config/` viewset**: `IsAuthenticated + DjangoModelPermissions`, POST 405, PATCH works with a superuser token → `appTitle` uses the admin token specifically.
- **nixpkgs module options verified** at the pinned rev: `services.paperless.manage` (readOnly package, wrapper `cd`s into dataDir and self-sudo's to `cfg.user` when needed) and `services.paperless.user` (default "paperless").
- **`deploy-restart-audit.nix` requirements** read in full: unit name matching `.*-provision$` MUST appear in deploy.sh (satisfied); `restartTriggers` on oneshot+RemainAfterExit are dead config → deliberately NOT set (improvement over the earlier design).

### 2. Implementation — `modules/nixos/services/paperless.nix`

- **New options namespace `services.paperless-dashboard`**: `enable` (default false, opt-in like every house service), `owner` (nullOr str; null = auto-resolve single SocialAccount-linked SSO user, fallback `admin`), `appTitle` (nullOr str; PATCH `/api/config/` with admin token), `savedViews` (submodule list: name, icon (enum-validated), showOnDashboard/showInSidebar (default true), sortField ("added"), sortReverse (true), filterRules = {ruleType (ints 0-49), tagName (runtime-resolved), value (literal)}).
- **Default views**: "Gmail Archive" (envelope, has-tag `gmail`) + "Encrypted (needs attention)" (exclamation-triangle, has-tag `encrypted`). Unresolvable tags drop the rule with a WARN; a view with zero resolvable rules is SKIPPED (a rule-less view would show ALL documents).
- **Eval-time assertions** (in a top-level `mkMerge`, outside the `mkIf`): enable → `services.paperless.enable`; no duplicate view names (create-only keys on the name).
- **`paperless-dashboard-provision` oneshot**: after/wants/wantedBy `paperless-web.service` (indirect unit → dedicated deploy.sh block), `User = cfg.user` (peer-auth for manage), `StateDirectory = paperless-dashboard` (0700), `harden { ProtectSystem = "strict"; }` + `serviceOneshotDefaults`, startLimit 5/300, onFailure routed, TimeoutStartSec 3min, curl health-gate preStart (30×2s polling the login page), `path = [ coreutils curl gnugrep jq ]`.
- **Script flow**: owner resolution (`paperless-manage shell < ownerResolverPy`, degrade-to-admin) → idempotent `drf_create_token` (token extracted, validated, rewritten as a curl `--header @file` — never in argv/env/journal, `trap rm` cleanup) → GET existing saved views + tags map → create-only loop with v9 headers → **end-to-end assertion** that every THIS-run-created view id appears in `dashboard_views_visible_ids` (phantom-green killer) → optional appTitle (WARN-never-fatal) → journal summary line.

### 3. Wiring

- **`scripts/deploy.sh`**: dedicated is-active-gated restart block for `paperless-dashboard-provision.service`, placed directly after the OIDC-bridge block (converges against the freshly restarted web; satisfies deploy-restart-audit).
- **`platforms/nixos/system/configuration.nix`**: `services.paperless-dashboard.enable = true;` with a pointer comment.

### 4. VM test extension — `tests/test-paperless.nix` steps 9-12 (+ header + node config enable)

Boot run (fallback owner + both views skipped), tag seeding via token-authed API, re-run (created + skipped paths + ui_settings membership via `jq -e index()`), idempotency (already-exists + count==1 + empty state dir). **The test did its job — it caught the one real bug (see d).**

### 5. Verification completed

- `nix-instantiate --parse` on all touched files: OK.
- Targeted evals (extendModules on evo-x2): unit EXISTS when enabled (`User=paperless`, `Type=oneshot`, `StateDirectory=paperless-dashboard`, `after/wantedBy=paperless-web`), unit ABSENT when disabled (opt-in works).
- **Negative test 1 VERIFIED**: minimal eval (nixpkgs paperless + integration.nix + my module, dashboard enabled, paperless disabled) → `services.paperless-dashboard.enable requires services.paperless.enable = true` fires (probed via eval-config.nix; the documented integration co-import requirement was rediscovered and honored).
- Formatting: repo formatter applied (`nix fmt` legitimately re-indented the whole mkIf-wrapped body — the 1248-line diff in paperless.nix is indentation, not content change); `-- --ci` now clean (0 changed).
- `bash -n scripts/deploy.sh`: OK.

### 6. Documentation (partially — see b)

`docs/services/paperless.md`: full **"Declarative dashboards (saved views)"** section added (mechanism, v9-vs-v10 rationale, owner resolution, create-only semantics incl. how to change/remove a view, add-a-view snippet, verification command).

---

## b) PARTIALLY DONE

1. **AGENTS.md updates — NOT started**: paperless bullet needs the dashboard provisioner note + the 3.1.1→3.1.3 version drift fix. Deliberately deferred until the VM test is green (docs should describe verified behavior).
2. **flake check**: passes for ALL of my surface (the earlier `lib.implies` error was fixed — `lib.implies` does not exist in this nixpkgs pin, inlined as `(!dcfg.enable || cfg.enable)`). The FULL `nix flake check --no-build` currently fails on an UNRELATED parallel-session issue (see d2).
3. **Duplicate-name assertion negative test — INCONCLUSIVE**: the second probe (two views both named "X") returned an EMPTY failed-assertion list, contradicting the sibling probe that fired minutes earlier under identical base modules. Suspect probe-expression or eval-cache artifact (the known eval-cache trap, AGENTS.md). MUST be re-run before trusting that assertion; do not assume it works.

---

## c) NOT STARTED

1. **The VM-test bug fix** (see d1 — designed, zero lines written).
2. **VM test re-run** after the fix.
3. **Deploy** (`nix run .#deploy`) — currently blocked by d2 anyway.
4. **Live verification** (provisioner journal, resolved owner, created views on the real dashboard, SSO user mapping answer, gmail/encrypted tag existence ground truth).
5. **AGENTS.md bullet + version drift fix.**
6. Backlog items from the capability report (f-list 13-50) — untouched, unchanged priorities.

---

## d) FAILURES / BLOCKERS (both diagnosed, neither fixed)

### d1. VM test FAILED — paperless's own system checks WRITE to the data dir

`nix build .#checks.x86_64-linux.paperless` ran the full VM; steps 1-8 passed; the new step 9 failed. Journal forensics:

- Owner resolver at boot printed the correct fallback line, but `drf_create_token` then DIED with `OSError: [Errno 30] Read-only file system: '/var/lib/paperless/__paperless_write_test_1470__'`.
- Root cause: EVERY `paperless-manage` command runs Django's system checks first, and paperless ships a custom `paths_check` (`src/paperless/checks.py:35`) that open(O_WRONLY)s a probe file IN `PAPERLESS_DATA_DIR`. Under the provisioner's `harden { ProtectSystem = "strict"; }` the dataDir is read-only → the check aborts the command BEFORE `handle()` ever runs (the same would have happened for `manage shell`; its stderr was swallowed by the degrade-to-admin path — the "resolver failed" fallback was actually THIS).
- The unit then failed with my (misleading) "token mint failed ... (user missing?)" message — the user existed; the manage wrapper failed on the write-check.
- **Designed fix (not applied): pass `--skip-checks` to BOTH manage invocations** (`drf_create_token ... --skip-checks`, `shell --skip-checks`) — a standard Django BaseCommand base flag that disables system checks; the provisioner's commands are read-only (token mint writes via the postgres socket, not the fs). This keeps the sandbox fully strict (alternative rejected: `ReadWritePaths = [dataDir]` would widen the sandbox AND drag in mount-gating-audit coupling on evo-x2's /mnt/pool dataDir). Also improve the mint-failure message to mention the traceback.

### d2. FULL flake check + deploy blocked by a PARALLEL SESSION (not mine)

`sops-key-audit: secret 'cv_evaluation_citizenships' is declared but its key is MISSING from platforms/nixos/secrets/cv.yaml`. The declaration lives in `modules/nixos/services/sops.nix:370` (parallel session's work, daemon-committed at 17:53-18:27 today — sops.nix/cv files were being modified while I worked). Adding the key needs an interactive `sudo sops` edit (tool-blocked in this session anyway). Every evo-x2 toplevel BUILD (i.e. the deploy) will fail on this assertion until that session lands the key. Not my work to complete — flagged, not touched.

### d3. Formatter wrote 4 files I never touched (incident, contained)

`nix fmt --no-update-lock-file -- --ci` turned out to WRITE (treefmt --ci formats and fails-on-change rather than check-only): besides reformatting my paperless.nix (legitimate — the mkMerge re-indentation), it formatted 4 files a parallel session had left unformatted (`nix-email.nix`, `sops.nix`, `test-crush-config.nix`, `test-nix-email.nix`). Their content was already in the tree (daemon-committed); the formatter only normalized style. Not reverted (never revert others' work); the daemon swept it. Lesson: in this repo, `-- --ci` is NOT side-effect-free — check `git status` after every run.

---

## e) IMPROVEMENTS (session-level lessons)

1. **The VM test caught exactly the class it was built for** — a sandbox/write interaction invisible to every eval probe (the extendModules evals were all green). Never trust eval-only verification for units that exec wrapped binaries.
2. **Wrapped app CLIs can carry hidden write side effects in "harmless" commands** (Django system checks). When a unit runs an app's manage CLI under a strict sandbox, `--skip-checks`-style escape hatches or a smoke run belong in the FIRST iteration, not after the test reds.
3. **`nix fmt -- --ci` in this repo WRITES** — treat it as a mutating command: parallel-session awareness required before every invocation.
4. My token-mint error message blamed the wrong cause ("user missing?") — error messages for wrapped commands should point at the traceback, not guess one failure mode.
5. The capability report's design held up almost unchanged; the only design deltas discovered during implementation were `lib.implies` (absent), no restartTriggers (dead config per audit), and d1.

---

## f) NEXT STEPS (in order; resume here)

1. **Fix d1**: add `--skip-checks` to both manage invocations in `paperless-dashboard-provision` script + improve the mint-failure message.
2. **Re-run** `nix build .#checks.x86_64-linux.paperless` → green through step 12.
3. **Re-run the duplicate-name assertion probe** (clean expr, no prefix filtering; if it still does not fire, debug the assertion before proceeding).
4. **Re-run `nix flake check --no-build`** — will stay red on `cv_evaluation_citizenships` until the parallel session lands their cv.yaml key; everything ELSE must be green.
5. AGENTS.md: paperless bullet (dashboard provisioner + create-only semantics + deploy.sh convergence) + 3.1.1→3.1.3 drift fix.
6. **Deploy + live verify** once d2 clears: `nix run .#deploy`, then `journalctl -u paperless-dashboard-provision.service -o cat` (owner resolution, created/skipped counts), dashboard renders the widgets under the real SSO session, record which user SSO maps to (answers open question 1).
7. Then the remaining backlog (capability report items 13+).

---

## g) OPEN QUESTIONS (unchanged from the capability report, still unanswered)

1. Which user does the Pocket ID SSO session map to (break-glass `admin` vs a distinct auto-signup user)? Auto-resolution handles either; an explicit `owner` pins it once known.
2. Are the tag names really `gmail` and `encrypted`, and are there more views wanted beyond the two defaults? (Runtime resolution + WARN makes wrong names safe; the journal will tell.)
3. appTitle scope (currently unset/null = untouched) + deploy timing approval.
