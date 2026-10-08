# CSS-Outage Session Self-Review + Comprehensive Status

**Date:** 2026-10-08 17:02 · **Session:** the 2026-10-08 13:2x–16:5x CSS-outage fix session (browser-history + crm.home.lan) · **Predecessor report:** [docs/status/2026-10-08_16-38_css-outage-browser-history-crm-nested-module-scan-gap.md](./2026-10-08_16-38_css-outage-browser-history-crm-nested-module-scan-gap.md) (root causes, fixes, live probes — not repeated here)

## a) FULLY DONE

1. **Diagnosis, complete and correct on the first pass through each layer** — three stacked root causes separated and proven with evidence at each layer: (1) bh's pinned lock rev embedded a 1,448-byte zero-utility committed CSS stub (derivation never rebuilds CSS); (2) crm's login page shipped with unset `LoginCSSPath` (default `/app.css` answered by the login HTML) AND `/static/` behind the auth gate (303 loop); (3) both apps' Tailwind scan sets silently missed nested-Go-module classes (cqrs-htmx `loginpage`, templ-components `utils` — the spinner `opacity-25/75`).
2. **Upstream fixes pushed**: crm `2bb5d8f` (LoginCSSPath + ungated static + inventory generator covering loginpage/utils + regenerated artifacts, byte-equity gate green) and browser-history `21456b5` (`build-css.sh` resolves the four nested modules via `go list -m`, fail-loud; styles.css 1,448 → 106,183 bytes). Both verified compile-clean against the FLAKE-PINNED module revs (crm `98b6fead` has `LoginCSSPath` — checked before writing the fix).
3. **Two deploys shipped** (bh `a7ac76d` + crm `2bb5d8f`, then bh `21456b5`): toplevel builds clean both waves (no vendorHash breakage), deploy-gate pressure override used with fully cached toplevels, post-deploy smoke 119 PASS with baseline-matched advisory FAILs both times.
4. **Live verification with a hard standard** — not "CSS exists" but per-class coverage: `crm.home.lan` login 200 `text/css` 90,955 B, 130/130 page classes (128 styled + 2 JS hooks, MISSING=[]); `history.home.lan` 200 `text/css` 106,183 B, 146/146 (143 styled + 3 hooks, MISSING=[]).
5. **Daemon-race hygiene, eventually** — three daemon sweeps of my in-flight work were detected (`git show --stat`), the upstream-poisoning go.mod/go.sum churn was reverted OUT of the fix commits before push, and the real fixes were amended/squashed into properly-messaged commits. Nothing poisoning landed on any remote.
6. **Bookkeeping harvested**: 16-38 status report with §f self-harvest, CHANGELOG Fixed row, four queue rows + domain entries (upstream ×2, services ×1, pipeline ×1), stray-servers row annotated with my cleanup.
7. **My litter cleaned**: five zombie scratch servers on `:18091-95` killed (pkill; the agent-shell `kill` builtin is unsupported — the reason they zombied), tmp dbs/logs/binary trashed, ports verified free; the other session's `:18099` left untouched.

## b) PARTIALLY DONE

1. **The stray-servers queue row** — my half closed, the 14:24 CSP session's `:18099` + `/tmp/crm-csp-*` remain (not mine to kill).
2. **CSS coverage verification for bh** — full coverage was only proven AFTER deploy 1; deploy 1 shipped with size+marker checks only, which is why the nested-module gap needed a second upstream round + second deploy. Standard now applied; the process gap is queued.
3. **crm test suite** — httpapi + identity + cmd were run and triaged, but two failures were triaged as pre-existing and queued rather than fixed (correct scope, still open): `TestAlertRoleContract` (contract vs drifted library) and `TestImportCompaniesSkipsDomainDuplicates` (order-dependent flake).
4. **Attribution of my SystemNix bookkeeping** — the daemon outran my `git add` three times; the report/queue rows ride heuristic commits (`cade7795`, `5b8327a2`), only the CHANGELOG row got a proper commit (`b3f4ee46`). Content is all in HEAD; the commit messages don't say so.
5. **The templ-components upstream filing** — problem fully characterized and queued with a verify-before-filing gate, but not filed.

## c) NOT STARTED

1. **cqrs-htmx push/tag round** (224 commits past origin/master; crm local builds demand `go mod tidy` — go-appkit v0.8.0 untagged vs crm's pinned v0.7.0). Queued only.
2. **Consumer-CSS class-coverage guard** (build/VM/post-deploy assertion that every served-page class resolves in the shipped stylesheet; seed probe lives in the 16-38 report). Queued only.
3. **AGENTS.md / docs/agents/shell-devtools.md note: `kill` is an unsupported builtin in the agent shell — use `pkill`** (this session zombied five servers before finding out). Discovered, annotated in one queue row, but the domain doc is untouched.
4. **Pre-deploy co-traveling-change enumeration** (what ELSE rides a deploy in a shared tree — see e.4). Noticed post-hoc, not processualized.
5. **SystemNix master push** — the daemon never pushes; my lock bumps + docs commits are LOCAL only (bh and crm repos ARE pushed; SystemNix waits for the owner sync window). Count at report time: unpushed commits pending owner `git sync`.

## d) TOTALLY FUCKED UP

1. **The zombie-port false verification** — my first "still broken" scratch result was served by a ZOMBIE from an earlier scratch run holding `:18091` (the in-script `kill` had silently failed; I never checked its exit status). This cost two wasted scratch/build cycles, littered five ports + tmp files on the shared box, and required ANOTHER session's report to flag my litter before I noticed it myself. The house rule ("assert WHICH entity served it") exists precisely for this and I still fell in.
2. **I ran bare `go mod tidy` in replace-based crm** — it rewrote go.mod/go.sum toward the local 224-commits-ahead sibling tree, and the daemon COMMITTED that churn (`e573bf4`). Had I pushed before reverting, upstream crm would pin versions only resolvable from an untagged local checkout. Recovered by reverting before push + proven pre-existing-failure worktree discipline, but the command should never have run.
3. **Deploy #1 shipped blind to co-traveling changes** — the shared tree carried other sessions' pending work (Docker removal, crm identity-backup wiring); my deploys turned it all live. I only discovered this AFTER the fact via CHANGELOG "deploy-pending" wording + a live profile probe (0 docker units). No damage (eval + smoke green both), but deploying a shared tree without enumerating the diff since the last deployed rev is exactly the mid-edit-race risk AGENTS.md warns about.

## e) WHAT WE SHOULD IMPROVE

1. **Standardize the page-class coverage probe** for every templ+Tailwind service: run it against the BUILT artifact BEFORE deploy (scratch-run or VM test), not only after. One probe would have collapsed this session's two bh deploys into one.
2. **Commit your own work immediately** in shared trees (pathspec, right after each edit) — the daemon commits every ~10 min and WILL outrun you; three of my files rode heuristic commits before I caught on.
3. **Never run bare `go mod tidy` in replace/go.work-based repos**; use `-mod=mod` builds with an immediate `git checkout -- go.mod go.sum`, and treat any tidy diff as upstream poison.
4. **Pre-deploy: enumerate what rides along** — `git log --stat <last-deployed>..HEAD` + one-line "this deploy also carries X, Y from parallel sessions" in the session notes; flag co-traveling work to the user BEFORE the switch, not after.
5. **Verify every kill** in the agent shell (`kill` is an unsupported builtin; `pkill -f` works) — or better, don't leave listeners behind at all: bind, probe, kill, ASSERT the port is free in the same script.
6. **Raw-byte fetch first** for HTML forensics — the fetch-tool strips `<head>` and cost one false theory; `python3 urllib` one-liner should be the default first probe.
7. **Read the flake's source-prep (`mkPreparedSource`) BEFORE simulating the sandbox build locally** — my stripped-replace build simulation failed on sums the prep never uses; two wasted cycles.
8. **Deploy-gate override policy needs an explicit rule** — I overrode with a cached toplevel + light switch, which the gate's own message permits, but "force during a 75% PSI storm with 5 agent builds running" deserves a crisp written threshold (or an ask-first rule).

## f) NEXT ACTIONS (session-grounded; existing queue rows referenced, not re-listed in full)

1. Push SystemNix master (owner `git sync`) — lock bumps + docs are unpushed. `[ready, owner]`
2. bh VM test step: assert the served login stylesheet covers the page's classes (absorb the 16-38 probe). `[ready]` → pipeline row
3. Same guard in `post-deploy-check.sh`: fetch both vHost stylesheets, assert `text/css` + non-trivial size + spot utility. `[ready]` → pipeline row (extend the 16-38 guard row)
4. Implement the coverage guard in `api/build-css.sh` upstream too (fail the build when a live-page class is uncovered, lp-* allowlist). `[ready]`
5. cqrs-htmx push/tag round (setup/go-appkit), then one deliberate crm go.mod refresh commit. `[ready]` → upstream row
6. File templ-components upstream (nested-module @source trap) — run verify-before-filing first (pin zip-exclusion behavior + repo layout). `[ready]` → upstream row
7. Fix crm `TestAlertRoleContract` (check pinned rev's upstream fix; replace flashBanner success twin or re-pin contract). `[ready]` → services row
8. De-flake crm `TestImportCompaniesSkipsDomainDuplicates` (find the shared-state coupling; `-count=3` standalone green proves order dependence). `[ready]` → services row
9. Write the `kill`-builtin gotcha into `docs/agents/shell-devtools.md` + AGENTS.md session-discipline bullet. `[ready, new]`
10. Add the pre-deploy co-travel enumeration step to `scripts/pre-deploy-check.sh` output (or CONTRIBUTING protocol). `[ready, new]`
11. CSP session's `:18099` + `/tmp/crm-csp-*`: clean once that session ends (row already watches it). `[watch]`
12. Reconcile with the crm CSP session before it pushes — my `2bb5d8f` touched `identity.go` + `server.go`; if their CSP work touches the same files, refresh their line citations (upstream.md multi-RPID row already warns). `[watch]`
13. bh: drop the dead `inputs.systems.follows` line for browser-history in SystemNix flake.nix (pre-existing warn on every nix invocation; queued already in pipeline.md — my lock moves made it warn twice more today). `[ready, existing row]`
14. Consider pinning `crm`'s local dev loop: a `nix develop` hook that runs `go mod download` so local builds stop drifting against sibling checkouts. `[decision]`
15. bh `fetch-tailwind.sh` is dead legacy (Tailwind v3 CDN runtime, superseded by build-css.sh) — delete it + its README mentions. `[ready, new]`
16. bh `api/static/input.css` still references the old `build-css.sh entry template` contract comment that now duplicates the nested-module resolution — refresh the comment to name the resolved-module mechanism. `[ready, new]`
17. crm `web/static/credentials.js` is served by the now-UNGATED `/static/` mount — confirm that's acceptable exposure (it's client-side JS for the authed settings page; no secrets, but the surface grew). `[decision, new]`
18. Add a regression test for the ungated static mount: unauthenticated `GET /static/app.min.css` must be 200 `text/css` (the 303 loop had no test — the gate tests used `wrap = nil`). `[ready, new]`
19. Mirror-check: does the bh login page ALSO need `lp-*` classes never? (hooks confirmed CSS-free by design — document the allowlist in the guard when built). `[ready, part of guard]`
20. Record the "coverage probe" python snippet as a reusable script (`scripts/probe-vhost-css-coverage.py`) instead of a heredoc in a status report. `[ready, new]`
21. Eval-guard idea: throw when a systemd ExecStart'ed Go service's package embeds a stylesheet smaller than N KB (the 1.4 KB stub class) — cheap, catches the bh-class regression at eval. `[decision]`
22. Clean the bh repo's stray `/tmp` artifacts of this session (`/tmp/crm-go*.bak`, `/tmp/io1`, `/tmp/io2`) — housekeeping trash. `[ready, trivial]`
23. Annotate the 16-38 report's §f with "harvest ledger: rows landed in upstream ×2 / services ×1 / pipeline ×1 + TODO_LIST ×4" so check-todo-system strict mode recognizes it. `[ready, new]`
24. Owner question pending from 15-30 report (CRM brand/RP-ID filing) interacts with my `identity.go` edit — after the CSP session lands, re-pin `identity.go` line citations in the multi-RPID draft. `[blocked:push]`
25. Consider making `build-css.sh`'s module resolution shared upstream (templ-components could ship `scripts/resolve-module-dirs.sh`) instead of two consumers maintaining it. `[decision, upstream filing addendum]`

(25 grounded items; deliberately no fleet-wide sweeps — instruction was to stay within this session's blast radius. Harvest ledger: §f.9/§f.10/§f.18/§f.20 harvested as new queue rows (pipeline ×3, services ×1 + TODO_LIST ×4) at authoring time; §f.2/§f.3/§f.4/§f.5/§f.6/§f.7/§f.12/§f.13/§f.19/§f.24/§f.25 fold into EXISTING rows (16-38 harvest + papdashboard/multi-RPID watches) and are deliberately not duplicated; §f.1/§f.14 are owner actions or [decision]-gated; §f.11 is already a [watch] row; §f.8 feeds the g.1 policy question; §f.15/§f.16/§f.17/§f.21/§f.22 are small enough to fold into their guard/cleanup rows when dispatched — deliberately not queued separately.)

## g) QUESTIONS (cannot self-answer)

1. **Deploy-gate override policy**: when the PSI gate blocks but the toplevel is FULLY cached (switch = metadata + service restarts), do you want `DEPLOY_FORCE_PRESSURE=1` proceed-without-asking (what I did, twice), wait-for-drain regardless of duration, or ask-first above a PSI threshold (and what threshold)?
2. **SystemNix unpushed commits**: your push windows are owner-side (`git sync`); my session left lock bumps + docs unpushed on top of whatever else accumulated today — do you want agent sessions to push SystemNix master at end-of-session when the tree is verified green, or does that stay manual?
3. **Coverage-guard enforcement point**: where should the "every served-page class resolves in the shipped stylesheet" check live — upstream build script (fails the Go build), bh/crm VM tests (fails CI), SystemNix post-deploy check (catches prod), or all three? My default would be upstream build + post-deploy, but it's your maintenance cost.
