# Cross-Repo TODO Sweep — 13 LarsArtmann Apps Items

**Date:** 2026-09-02 21:25
**Session scope:** Execute the "LarsArtmann Apps" TODO_LIST block (13 items) end-to-end: research → execute → verify per item.
**Repos touched:** CreditReformBilanzampel, Kernovia, CV, picoclaw, erraudit, projects-management-automation, crush-daily, niri-session-manager (cloned fresh), standard-bug-tracking-schema, KeyCountdown, browser-history, DiscordSync, dnsblockd, cqrs-htmx, SystemNix, go-nix-helpers (read-only), project-discovery-sdk, project-discovery-daemon.
**Working style note:** many repos are shared with parallel sessions and auto-commit daemons. Attribution below separates MY commits from daemon-swept landings. I pushed tags only where the task required propagation (item 1); branch pushes were left to owners EXCEPT CV (explicit precedent from the 08-29 session).

---

## TL;DR

- **10 of 13 items DONE and verified**, 1 root-caused but interrupted mid-fix (golangci-lint-auto-configure), 2 NOT STARTED (hermes, BuildFlow).
- The vendor-hash CI task snowballed into the biggest finding: **every gate I added caught real breakage immediately** — CV, erraudit, PMA, and crush-daily masters were ALL unbuildable via Nix when I arrived. Four distinct root causes fixed: live vendorHash staleness (CV), toolchain-floor-vs-stale-nixpkgs-fetch (erraudit/PMA/crush-daily), the **gobwas/glob v1.0.0 breaking release** (project-discovery-sdk — compiled against the removed `glob.Glob` interface), and a **templ-components flake-input-vs-go.mod split brain** in crush-daily (goldens passed locally, failed only under Nix).
- Unplanned upstream work forced by that chain: project-discovery-sdk v0.21.1 + `domain/v0.21.1` submodule tag, project-discovery-daemon extracted-module migration in PMA + daemon v0.1.1.
- **Org-wide blocker discovered: GitHub Actions CI is dead across the ecosystem** (billing failures; workflows disabled_manually). All my workflow edits are locally verified but CI-unverified until billing is fixed.
- **Machine-level finding:** the nix daemon serves STALE source for already-locked revs (same nixpkgs rev evals go 1.26.5 via PMA, 1.26.7 via SystemNix — different store paths). No sudo here, so three repos carry goTarball pins at 1.26.7 as the documented content-addressed workaround. Drop-day re-run needs a `nix-daemon` restart.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **Tag CreditReformBilanzampel + Kernovia DSN fixes** | CRB `v0.1.0` @ `b1e5e701` (first tag ever; captures modernc DSN pragma fix), Kernovia `v0.6.0` @ `c5673676` (captures DSN fix bundled in `d139446d`, 1225 commits after the stale `v0.5.0-watermill`). Both annotated + pushed. Neither is consumed by SystemNix → no input bumps needed. |
| 2 | **CV: CI `nix build .#cv` gate + AGENTS.md lessons** | Explicit build step added to the `nix-check` job (timeout 15→20min); two AGENTS.md lessons (vendorHash-from-SOURCE-churn model; templ worktree/clone trap) + CI bullet updated. **The gate caught a LIVE regression within the hour**: CV master was unbuildable (module set shifted by new `templ-components/errorpage` + `go-error-family` imports with zero dep-file changes). Worktree-verified got-hash fix `sha256-iI0Nlo+88TXkA0anlap5gi2iPuIT2X2D5O5oY5wHQk8=`, committed `7dee7292`, pushed. My edits landed via daemon `1d97de40`. |
| 3 | **picoclaw: modernc.org/sqlite v1.48.0 → v1.56.0** | `e644c213` (bump + dropped the no-op `_foreign_keys=on` DSN param — both call sites enforce FK via explicit PRAGMA; sqlite engine 3.53.3 verified via scratch-module smoke test). Plus `e08c55a5`: fixed **11 pre-existing test-compile errors** (same-scope `:=` redeclarations from the `58ea580e` modernization sweep) across 10 test files — the suite could not even compile at HEAD before this. NOT pushed (repo was already ahead 3 with another session's unpushed work; now ahead 5). |
| 4 | **vendor-hash drift CI: erraudit, PMA, crush-daily** | erraudit: `checks.vendor-hash` FOD fast-gate in flake.nix + explicit `nix build .#default` step in the nix-check job. PMA: "Build Nix package" step in nix-ci.yml (`97a7e71e`; `nix run .#build` is a devshell go build and never realizes the FOD). crush-daily: already had `nix build .#default` in ci.yml (verified, no change needed). All three master trees then repaired to GREEN (see TL;DR + item 4 details below). |
| 5 | **niri-session-manager: restore-storm fixes (the P1 headline)** | Cloned the repo. Four fixes in `src/main.rs`: (1) boot-scoped restore gate — kernel `boot_id` recorded in a restore-marker file after successful restore, restore skipped on same-boot process restart (kills the Restart=always storm); (2) save-side dedupe of single-instance apps by pid (stops the every-15-min growth loop); (3) stateless-terminal guard — `terminal_state: null` windows are dropped with a warning instead of restoring empty shells; (4) `--max-restore-windows` cap (default 100) + same-app >10 poisoned-session warning + skip-listed apps no longer persisted. 3 new unit tests, **60 tests pass**, clippy clean, `nix build .#default` green (after refreshing the lock past a pre-existing crates.io download-endpoint 403). Released `v0.4.0` (`f082000`), pushed main + tag. SystemNix flake.lock bumped to `f0820009`; `nix flake check --no-build` — all checks passed. |
| 6 | **Roll out go-nix-helpers `eca72e1` across consumers** | Skill loaded. Enumerated **41 consumers**. Baseline: 33 already at `58f7257`, dnsblockd at `eca72e1` (target satisfied) → **4 behind**: standard-bug-tracking-schema, KeyCountdown, browser-history, DiscordSync. All 4 bumped to `58f7257` and `nix flake check --no-build` verified. standard-bug-tracking-schema tripped the NEW templ-committed check (40 ungenerated files — the check working as designed): removed the `*_templ.go` gitignore rule, committed the 25,847-line generated set (`7f0f2fe2`, branch `m5-adapters`) → all checks passed. DiscordSync required the pin itself to move (see d-2). |
| 7 | **dnsblockd: OTEL cardinality** | Turned out ALREADY FIXED upstream: every metric label is bounded (domains bucketed via `domain_category`; `oidc_failure_reason` is 4 literals; `health.Source` is the configured blocklist set). `dns.domain`/`dns.client_ip` survive only as SPAN attributes (exempt — span attrs never create metric series). Regression test `TestMetricsCardinality_NoHighCardinalityLabels` PASSES; internal/otel + internal/tracking suites green. The stale SystemNix `dns-blocker.nix` comment ("Fix upstream by dropping high-cardinality labels") corrected to record the upstream fix + the surviving SQLite-write rationale for GOMEMLIMIT. Eval OK. |
| 8 | **cqrs-htmx/browser-history: registration-lock polish** | cqrs-htmx `4216636f`: (1) **friendly 403** — `writeDispatchError` and the OAuth2 callback path now emit "New sign-ups are closed on this server. If you should have access, ask the administrator to add you, then sign in with your existing account." instead of the raw sentinel text; machine code + request ID still included; test asserts the body text AND that the machine code does not leak; full usermgmt suite green. (2) **Mutex-limitation docs** on `ServiceConfig.MaxUsers` (per-process gate; N replicas can transiently admit N extra users; landed via daemon `928fcdac`). browser-history (daemon `7bdb88a`): **`browser_history_user_count`** Prometheus gauge (`api/metrics.go`, once-guarded registration with pointer-swapped callback so multi-server tests don't double-register), wired in `server.go`, `TestUserCountGaugeExposedOnMetrics` passes. |
| 9 | **DiscordSync: chattr ExecStartPre + IO-baseline test flake** | chattr: upstream ALREADY repaired 2026-08-05 (`0e72e7b1`: writeShellApplication wrapper + `+` privileged prefix) — the SystemNix `discordsync.nix` comment claiming "upstream ships a broken chattr" was stale; corrected (the mkForce drop now documents its real reason: DNS-gate replacement). IO flake: `TestIOBaseline_DiskWriteBytes` required strictly positive `/proc/self/io` write_bytes deltas, which read zero on tmpfs `/tmp` (this box) or under fully-coalesced writeback → unmeasurable runs now SKIP with the reason (`cd9ea239`); test passes `-count=3`, vet clean. |

**Repos left intentionally unpushed** (mixed-authority daemon commits + parallel-session WIP): picoclaw (ahead 5), PMA (ahead 7), erraudit (ahead 1, a 106-file daemon commit), browser-history (ahead 1), cqrs-htmx (ahead, includes `4216636f`), DiscordSync branch (2 of my commits + their WIP), standard-bug-tracking-schema (ahead 2). See g-3.

---

## b) PARTIALLY DONE

### golangci-lint-auto-configure: incomplete vendoring — ROOT-CAUSED, FIX NOT APPLIED

- Reproduced `nix build .#default` failure and extracted the real error (my first log grep missed it): **`pkg/report/report_templ.go:11:2: module lookup disabled by GOPROXY=off`** — the PACKAGE build fails resolving imports FROM templ-generated files.
- Diagnosis (high confidence, not yet fixed/verified): `go.mod`/`go.sum` were tidied WITHOUT the generated `*_templ.go` present (they're not tracked), so the requirements the generated files import are missing from go.mod; Nix regenerates templ at build, then the offline build cannot resolve → the classic templ-tidy trap (CV now generates templ BEFORE tidy in its tidy-drift job for exactly this reason).
- Fix path (next session, ~15 min): run `templ generate`, `go mod tidy` (GOEXPERIMENT=jsonv2), commit go.mod/go.sum AND the generated files (also satisfies `checks.templ-committed`), re-`nix build`, then re-enable the line in `lib/lars-packages.nix`.
- Note: the disabled comment says "local deps (gogenfilter)" — gogenfilter IS correctly declared in deps; the comment's diagnosis was wrong.

### SystemNix TODO_LIST.md resolution markers — NOT YET ANNOTATED

Per the docs-health doctrine, the ~9 completed rows in TODO_LIST.md ("LarsArtmann Apps" block) should get inline `~~item~~ → DONE <date> (`hash`)` markers. I spent the session executing; the markers are pending (see f-11). The stale-comment fixes I DID write back (CV AGENTS, dns-blocker.nix, discordsync.nix) are the exception.

---

## c) NOT STARTED

| Item | Blocker / note |
|------|----------------|
| **hermes**: auto-create dirs on first run; own state migration; sane OLLAMA defaults; PID-file locking | Repo not local (`~/projects/hermes` absent); would need cloning + locating the upstream source of the SystemNix `hermes` flake input. Pure upstream Python work, nothing blocking. |
| **BuildFlow**: pre-commit needs missing devShell binaries | Repo local but ahead 16 with a parallel session's auto-committed work (dirty `modules/dbstore/step_outputs.go`). Needed a dedicated investigation session; not begun. |

---

## d) TOTALLY FUCKED UP

1. **`nix build .#cv ... | tail -5` masked a FAILED build and I echoed "NIX BUILD CV OK"** — the exact `cmd | tail hides the exit code` trap CV's own AGENTS.md documents. I only caught it because I cross-checked `result/bin` timestamps against the drv name. Cost: one wasted verification cycle and a temporary false claim. Rule re-learned: verdict probes must be `if nix build …; then echo GREEN; fi` — never pipelines.
2. **DiscordSync rollout misread (the deep one):** my baseline read the lock via `root.inputs` mapping correctly, but after `nix flake lock --update-input go-nix-helpers` "succeeded", I verified against the WRONG evidence — a stale DETACHED node (`go-nix-helpers_4` @ `58f7257`) that root never references — while root still resolved `go-nix-helpers` @ `7c18d972`. Then burned ~5 confused commands (jq `//` fallback expressions reading different nodes between HEAD and worktree) on the contradiction before root-causing with a python JSON walk. Actual cause: the input is **hard-pinned by rev in the URL path** (`url = "github:…?rev=7c18d972…"`), so `--update-input` can NEVER move it — and it fails silently. Fix was a one-line pin bump (`94f7e95b`). Lesson for the ecosystem: `--update-input` against rev-pinned inputs is a silent no-op; there is no warning.
3. **Dirty-tree hash measurement (crush-daily):** I set `vendorHash.nix` from the DIRTY worktree (parallel session's go.mod WIP), then built a clean-HEAD worktree to verify — and forgot I had deliberately written the OLD hash into that worktree for measurement, so the "green check" ran with the old hash and failed confusingly. Turned out the FOD hash is identical for both states so the committed value was correct — but I got there by luck-adjacent iteration, not method. Clean-HEAD measurement should have been the FIRST step.
4. **My verification scaffolding leaked test junk into picoclaw** (`pkg/cron/.tmp-*`, `test_cron_*.json` from `go test ./...`) — trashed immediately, but running the full suite from a shared dirty tree without anticipating artifact droppings was sloppy. Also `/tmp/sqlitesmoke`, `/tmp/*.log` scratch files remain (harmless, uncleaned).
5. **Pre-existing, not caused by me, but Ioperated around it all session — broken CLI hygiene in MY shell:** my early commands used `grep -B8 "..." | head` pipelines that truncated decisive error output (golangci FOD error invisible for an hour of session time; CV first-build verdict masked per d-1). The last golangci log tail (captured with plain `tail`) immediately revealed the root cause. Tail/grep truncation cost real diagnosis time three separate times this session.

---

## e) WHAT WE SHOULD IMPROVE

1. **CI billing is the ecosystem's single point of failure.** erraudit + crush-daily Actions fail "recent account payments have failed or your spending limit needs to be increased"; PMA + crush-daily + erraudit workflows are `disabled_manually`. Everything I shipped today is CI-UNVERIFIED until this is fixed. Local gates are strong (and caught 4 real breakages), but the push-time safety net is dark.
2. **The stale nix-daemon fetch cache cost ~an hour of misdirection** (same-rev-different-store-path divergence). A single `sudo systemctl restart nix-daemon` unlocks the clean drop-day (removing the three 1.26.7 tarball pins) — and would prevent the next session from re-deriving this.
3. **Drop-day doctrine needs a "verify the compiler the FOD will actually use" step.** Dropping `goTarballVersion` made go-standard fall back to the (stale-fetched) nixpkgs go 1.26.5 — the drop LOOKED correct by doctrine but regressed the build. The eval probe `f.inputs.nixpkgs.legacyPackages.<system>.go_1_26.version` per-consumer is the missing pre-drop check.
4. **Rev-pinned flake inputs defeat `--update-input` silently.** Deserves either an eval-time guard in go-nix-helpers/flake tooling or an AGENTS lesson (F2-analog for flake locks).
5. **Patch-stage discipline worked but is laborious** (erraudit ci.yml, DiscordSync flake.lock). On daemon-managed repos, checking `git status` BEFORE planning pathspec commits avoids the ceremony — the daemon usually sweeps first anyway. Do the status check first, not last.
6. **Prefixed submodule tags are an unwritten convention** (project-discovery-sdk): my plain `v0.21.1` tag served only the root module; submodule consumers needed `domain/v0.21.1`. I discovered it via proxy 404s + `unknown revision domain/v0.21.1`. Document per-repo or tool the release.
7. **Fresh-tag proxy propagation (15-60 min) has no bypass except GOPRIVATE scoped-direct fetch** — worked, but deserves a one-liner in the ecosystem docs next to the vendorHash lessons.
8. **Golden tests + floating flake inputs = sandbox-only failures.** crush-daily's split brain (go.mod v1.8.4 vs input `ref=master`) produced tests that pass everywhere except Nix. The fix (pin the input in lockstep with go.mod) should be the documented default for golden-tested repos; consider an eval-time assertion pairing input pins with go.mod requires.
9. **Latent test failures exposed by my compile fixes need owners:** picoclaw's pkg/config security-yaml (likely the parallel session's WIP), BM25 ranking, and the edit/shell/codex tool tests failed only AFTER I repaired compilation — they were invisible at HEAD. Triage before someone mistakes them for regressions from the sqlite bump.
10. **TODO_LIST hygiene:** completed rows must get inline resolution markers at completion time, not batched (my own violation this session; the docs-health AUDIT pass would flag all 9 rows as stale-unmarked).

---

## f) Up to 50 Things We Should Get Done Next

**Immediate (this week, mostly user-side or quick):**
1. **golangci-lint-auto-configure**: apply the templ-tidy fix (generate → tidy → commit go.mod/go.sum + generated files → build → re-enable in `lib/lars-packages.nix`).
2. **Restart nix-daemon** (sudo, quiet moment) → re-run drop-day: remove the 1.26.7 `goTarballVersion` pins from PMA, crush-daily, erraudit; verify `nix build` per repo.
3. **Fix GitHub Actions billing** (or migrate to self-hosted) → re-enable the disabled workflows (crush-daily `CI`, PMA `Nix CI`, erraudit full set + the others disabled_manually).
4. **Push the unpushed repos** (see g-3 for the policy question): picoclaw, PMA, erraudit, browser-history, cqrs-htmx, DiscordSync branch, standard-bug-tracking-schema.
5. **Annotate TODO_LIST** rows with resolution markers (9 rows) + purge executed rows to CHANGELOG per docs-health doctrine.
6. **Deploy SystemNix** (`nix run .#deploy`) to ship niri-session-manager v0.4.0; watch the first boot log for the restore-marker behavior + the config-hardening TODO (item 100).
7. **Tag cqrs-htmx** (friendly-403 commit) + bump browser-history's go.mod/flake + SystemNix input so the friendly message actually DEPLOYS (right now deployed browser-history builds against the old cqrs-htmx).
8. **Verify CV's new CI run end-to-end** (the push happened; confirm the nix-check build step is green on GitHub once billing allows).
9. **Clean scratch**: `/tmp/sqlitesmoke`, `/tmp/nsm-*.log`, `/tmp/gla.log`, `/tmp/ds_head.lock`, `/tmp/myhunk*.patch`, `/tmp/want.html`, `/tmp/got.html`, `/tmp/*-section.txt`.
10. **project-discovery-sdk**: remove the accidentally-committed `result/`, `result-1/`, `result-daemon/` nix outputs (rode the daemon's 56-file sweep `4d94613`) + gitignore them.
11. **project-discovery-sdk**: decide whether to cut the remaining submodule tags at the v0.21.1 tree (cache/detection/etc. still at v0.21.0) — mixed-version consumers are valid but messy.
12. **crush-daily**: the parallel session's uncommitted go.mod dep bump breaks 6 golden tests under the pinned templ-components v1.8.4 — owner must regenerate goldens or revert the dep; coordinate before their next commit poisons master.

**Short-term:**
13. Kernovia `database.go`: add `journal_mode`/`foreign_keys` pragmas (deferred items 16-17 from the 08-14 DSN audit doc).
14. Kernovia: verify v0.6.0 tree actually builds/tests (I tagged HEAD without a build gate — the tag captures landed work, but the repo was untested this session).
15. CreditReformBilanzampel: mattn→modernc driver migration (doc item 13) + `connection.go` DSN tests (item 14) + move the `v0.1.0` entry into CHANGELOG (I tagged without a CHANGELOG version section).
16. Sweep the OTHER ~33 go-standard consumers for the same two gaps I closed in erraudit/PMA (FOD-fast `checks.vendor-hash` + explicit `nix build` CI step) — most likely lack one or both.
17. picoclaw: triage the exposed latent failures (config security-yaml, BM25 ranking, edit/shell/codex tool tests) — assign owners; check whether picoclaw CI runs `go test` (the suite was broken at HEAD, so CI was either red or absent).
18. picoclaw: verify whether SystemNix or anything consumes picoclaw (if so, the sqlite bump + ahead-5 state has deployment implications).
19. niri-session-manager: add GitHub Actions (cargo test/clippy/nix build) — the repo had no visible CI when I cloned it.
20. niri-session-manager: post-deploy live verification of the restore gate (reboot → confirm "skipping restore (marker)" in journal); confirm the existing poisoned `session.json` self-heals via save-side dedupe.
21. niri-session-manager: implement TODO item 100 config hardening (gcr-prompter + transient app-ids into `[skip_apps]`, eval-time guard for `single_instance_apps`, `restartTriggers` on config.toml).
22. DiscordSync: coordinate landing the parallel session's branch (`nix/aa56b582-vendorhash` still holds dirty flake-parts/nixpkgs lock bumps + go.mod/go.sum WIP on top of my two commits).
23. erraudit: my gates ride the 106-file daemon commit `71a23d4` — write the CHANGELOG/attribution note so the vendorHash fix (75XKbh) is discoverable.
24. erraudit: confirm the root-nixpkgs lock bump (0e251e24→34ab99075) doesn't desync SystemNix's erraudit input subtree (full `nix flake lock` on SystemNix).
25. browser-history: decide whether `browser_history_user_count` gets a Gatus/SigNoz watch (the TODO asked for the metric only; an alert on count>MaxUsers would catch gate bypasses).
26. cqrs-htmx + browser-history: record the friendly-403 + gauge work in their CHANGELOGs (both repos keep one).
27. hermes: clone + execute the 4 items (auto-create dirs, state migration, OLLAMA defaults, PID locking).
28. BuildFlow: pre-commit missing devShell binaries (mind the ahead-16 parallel state).
29. standard-bug-tracking-schema: add a CI drift guard so the 40 now-tracked `*_templ.go` files stay fresh (`templ generate` + `git diff --exit-code`).
30. SystemNix: full `nix flake check --no-build` at a quiescent moment (my dns-blocker.nix + discordsync.nix comment edits eval-checked individually; a whole-config check hasn't run since the nsm lock bump).
31. SystemNix: reconcile SystemNix's own goTarball story with the new per-repo pins (AGENTS says "still carrying now-droppable overrides: browser-history, papdashboard, crush-daily, PMA" — crush-daily + PMA now pinned at 1.26.7, not droppable until daemon restart).
32. go-nix-helpers: add the "rev-pinned input silently defeats --update-input" lesson to its AGENTS (or an eval-time warning in the flake tooling).
33. go-ecosystem-upgrade skill: add failure modes — "prefixed submodule tag required for nested modules" and "rev-pinned input no-ops update" to the catalog (user-owned skill; propose upstream).
34. project-discovery-daemon: tag the pre-existing ahead-1 commit lineage properly (v0.1.1 included it; verify origin/master == local after push).
35. CV: consider tag-pinning its `go-cqrs-lite?ref=master` floating input (the float churned CV's lock twice this month).
36. CV: add the "build gate caught live vendorHash staleness on 2026-09-02" event to its CHANGELOG as the gate's proof-of-value.
37. dnsblockd: the :9090 stats-API wedge root cause remains unknown — SIGQUIT runbook stays armed for the next wedge (unchanged, tracked).
38. dnsblockd: re-check the GOMEMLIMIT comment claim ("synchronous SQLite tracking writes") after the upstream telemetry refactor — the metric half was fixed; the SQLite half may also be stale.
39. picoclaw: decide whether the `goolm`-tagged matrix channel tests run in CI (`-tags goolm` needed; default `go test ./...` skips them).
40. SystemNix AGENTS: record the "daemon stale-fetch makes same-rev evals diverge" machine finding + the per-consumer go-version eval probe (e-3).
41. SystemNix AGENTS: record "vendorHash must be measured against clean HEAD" (d-3).
42. PMA: after nix-daemon restart + pin removal, re-run `nix build` AND `internal/discovery` tests (my migration's verification was against the pinned toolchain).
43. erraudit: sweep other go-standard repos for uncommitted `*_templ.go` BEFORE the templ-committed check lands via future go-nix-helpers bumps (standard-bug-tracking-schema was caught today; who's next?).
44. KeyCountdown + browser-history: their go-nix-helpers bumps landed via daemon — spot-verify a `nix build` on each (I only eval-checked).
45. Confirm every repo I touched has its working tree in the state its owner expects (several had untracked or dirty files I deliberately preserved — document in each repo if they have status docs).
46. Consider a tiny `scripts/eco-status.sh` that reports per-repo: branch, ahead/behind, dirty count, last daemon commit — today's attribution work was manual.
47. The `/tmp` measurement files from the golden diff (want/got html) would make a good fixture for a crush-daily regression note — salvage or delete (f-9 covers deletion).
48. Go-proxy propagation wait (15-60 min) bit me twice (sdk domain tag, daemon v0.1.1) — if more ecosystem releases land today, re-verify `go list -m` before consumer bumps.
49. Re-check that DiscordSync's `domain` migration isn't ALSO needed by other PMA-sibling consumers of `project-discovery-sdk/daemon` (grep ~/projects for the old import path — I only fixed PMA).
50. Update the SystemNix "LarsArtmann Apps" TODO_LIST section header count once markers land (10 done of 13 → section may deserve archival per the archive canon).

---

## g) Questions I cannot figure out myself (max 3)

1. **GitHub Actions billing:** erraudit and crush-daily CI died with "recent account payments have failed or your spending limit needs to be increased", and PMA's + crush-daily's Nix workflows are `disabled_manually`. Do you want to fix billing / raise the limit (and then I re-enable the workflows), or should the affected repos migrate to self-hosted runners like PMA's (which never picked up a job — is that runner even registered anywhere)?

2. **nix-daemon restart:** the machine-level stale fetch cache (same locked rev → different store trees, go 1.26.5 vs 1.26.7) is the root blocker for a clean drop-day on PMA/crush-daily/erraudit. May I schedule `sudo systemctl restart nix-daemon` with you at a quiet moment (no builds/flm resident), or do you want to run it yourself? Anything depending on the pinned go 1.26.6-era behavior I should know about before the pins come off?

3. **Push policy for mixed-authority repos:** seven repos now sit ahead of origin with my work interleaved with parallel sessions' committed-but-unpushed work (picoclaw +5, PMA +7, erraudit +1×106-files, browser-history +1, cqrs-htmx +2, DiscordSync branch +2, standard-bug-tracking-schema +2). Push as-is (publishing the other sessions' landed work with mine), leave each for its owning session, or a repo-by-repo list of what you want pushed?

---

_Arte in Aeternum_
