# CSS Outage: browser-history + crm.home.lan — Three Stacked Root Causes, Both Fixed Live

**Date:** 2026-10-08 ~14:00–16:45 · **Scope:** `history.home.lan`, `crm.home.lan` (both unstyled in the browser) · **Verdict:** FIXED and live-verified (both vHosts serve real Tailwind with zero uncovered page classes).

## f. Follow-ups

Harvested at authoring time (see the queue rows + domain entries cited below):

1. **cqrs-htmx local drift** — the local checkout is 224 commits past origin/master; crm local builds fail with `go: updates to go.mod needed` because local `setup` needs go-appkit v0.8.0 while crm's committed go.mod pins v0.7.0 (replace-based dev loop). Needs a cqrs-htmx push/tag round + crm go.mod refresh → [docs/todo/upstream.md](../todo/upstream.md) + [TODO_LIST.md](../../TODO_LIST.md).
2. **crm pre-existing test failures** (proven NOT caused by this session's changes: reproduced at fe9da49 in an archived worktree): `TestAlertRoleContract` (pinned contract vs drifted local library) and `TestImportCompaniesSkipsDomainDuplicates` (order-dependent flake: fails in full-suite run, green standalone `-count=3`) → [docs/todo/services.md](../todo/services.md) + [TODO_LIST.md](../../TODO_LIST.md).
3. **Consumer-CSS class-coverage guard** — two incidents today share one class: the shipped stylesheet silently missing classes (stub embed; invisible nested-module globs). Queue a build/VM-time assertion that every class on the served login page resolves in the shipped stylesheet (the python probe from this session is the seed) → [docs/todo/pipeline.md](../todo/pipeline.md) + [TODO_LIST.md](../../TODO_LIST.md).
4. **Upstream filing: nested-module @source contract** — templ-components' nested modules (utils/icons/errorpage/htmx) are invisible to root-module-dir `@source` globs; consumers' build-css scripts silently scan nothing. File upstream (verify-before-filing applies) → [docs/todo/upstream.md](../todo/upstream.md) + [TODO_LIST.md](../../TODO_LIST.md).

Deliberately NOT harvested: the deploy-gate pressure override (the gate worked exactly as designed; override used with a fully cached toplevel, no build load added); bh-repo CHANGELOG row (the fix commit message carries the evidence; bh's history is daemon-commit norm).

## What the user saw

Both `history.home.lan` and `crm.home.lan` rendered completely unstyled: raw utility-class soup, no colors, no layout.

## Root causes — three separate bugs, stacked

| # | Service               | Layer                   | Root cause                                                                                                                                                                                                                                                                                                                                                                | Evidence                                                                                                                                     |
| - | --------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | browser-history       | Build input             | SystemNix's lock pinned bh `4360688`, whose committed `api/static/styles.css` was a 1,448-byte stub — a Tailwind build that matched zero classes. The binary embeds the committed file verbatim (`//go:embed static`), and the Nix derivation only runs `templ generate`, never rebuilding CSS.                                                                           | `git show 4360688:api/static/styles.css \| wc -c` = 1448; live `/static/styles.css` = exactly those bytes                                    |
| 2 | crm.home.lan          | App code (3 stacked)    | (a) `internal/identity/identity.go` never set `LoginCSSPath` → cqrs-htmx default `/app.css`; (b) no route serves `/app.css` → the root handler answered it with the login HTML (18 KB `text/html`); (c) even pointed at the right file, `/static/` was mounted inside the auth gate → unauthenticated CSS requests 303'd back to `/login`.                                | live probe: `/app.css` → login HTML; scratch-run: `/static/app.min.css` → 303                                                                |
| 3 | both (shared library) | Class-inventory tooling | The Tailwind scan sets never saw classes living in **nested Go modules**: cqrs-htmx's `loginpage` package and templ-components' `utils` module (`svg/spinner.templ` holds `opacity-25/75`). Root-module cache dirs exclude nested-module files entirely, so `@source $TEMPL_DIR/utils/**` globs silently match nothing. crm's inventory also missed the loginpage module. | `ls $GOMODCACHE/templ-components@v1.20.1/utils` → missing; `go list -m -f '{{.Dir}}' templ-components/utils` → separate dir WITH the classes |

## Fixes

- **browser-history upstream** (`a7ac76d` — parallel session's full-CSS regeneration consumed via lock bump; `21456b5` — this session): `api/build-css.sh` now resolves the four nested modules (`errorpage htmx icons utils`) via `go list -m -f '{{.Dir}}'` and `@source`s their real directories (fail-loud instead of silent no-match). `styles.css` 1,448 → 88,805 → 106,183 bytes.
- **crm upstream** (`2bb5d8f`, one squashed commit): (a) `LoginCSSPath: "/static/app.min.css?v=" + web.AssetVersion()` in the setup config; (b) `GET /static/` mounted outside the auth wrap in `MountInto`; (c) `gen-library-classes.sh` extended to append the cqrs-htmx loginpage AND templ-components utils module sources into the committed inventory; (d) regenerated `library-classes.txt` + `app.min.css` (90,271 → 90,955 bytes) + 13 templ-codegen artifacts (byte-equity gate green).
- **SystemNix**: `nix flake update browser-history crm` → bh `4360688→a7ac76d→21456b5`, crm `fe9da49→2bb5d8f`; toplevel builds clean both waves (no vendorHash breakage — Go module graphs unchanged).

## Deploy + verification

- Deploy 1 (~14:0x, gen with bh `a7ac76d` + crm `2bb5d8f`): deploy gate blocked on a real I/O storm (PSI 55–75%, five concurrent agent build storms — crash-#3 precursor class); waited, then `DEPLOY_FORCE_PRESSURE=1` with the toplevel fully cached (no build load added; switch is metadata + two tiny service restarts). Smoke: 119 PASS / 14 baseline FAILs (advisory).
- Deploy 2 (~16:3x, bh `21456b5`): same posture, smoke 119 PASS / 13 baseline FAILs (advisory, baseline-matched).
- **Live probes (final):**
  - `https://crm.home.lan/login` → `/static/app.min.css?v=c042466b` → 200, `text/css`, 90,955 B — 130 page classes: 128 styled + 2 `lp-*` JS hooks, **MISSING=[]**
  - `https://history.home.lan/` → `/static/styles.css` → 200, `text/css`, 106,183 B — 146 page classes: 143 styled + 3 hooks, **MISSING=[]**
- Scratch-run verification pre-deploy (crm binary, fresh identity DB, loopback): href resolves 200 text/css; port-collision trap noted — the first "still broken" probe was answered by a ZOMBIE server from an earlier scratch run holding the port (assert WHICH entity served it).

## Method notes (for the next CSS incident)

1. Fetch RAW bytes (python urllib) — the fetch-tool strips `<head>`, which initially made the head look missing.
2. Coverage probe: extract every `class="…"` token from the served page, tailwind-escape (`:`→`\:` etc.), match `.class{` / `:` / `,` / `>` in the CSS; `lp-*` = JS hooks needing no CSS.
3. `-mod=mod` builds in crm dirty go.mod/go.sum (local-replace drift) — restore immediately; never commit that churn upstream.
4. The auto-commit daemon swept in-flight fix files three times (crm identity.go, server.go + go.mod churn; SystemNix lock) — each was verified with `git show --stat` and squashed/amended-forward into properly-messaged commits BEFORE push; go.mod/go.sum churn reverted out of the fix commits.
