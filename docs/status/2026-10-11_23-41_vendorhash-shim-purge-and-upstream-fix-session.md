# Status: vendorHash shim purge + upstream fix session (2026-10-11, 23:41 CEST)

**Task (user directive):** "Go and fix all upstream and stop overlaying my projects vendorHash unless NECESSARY!" — triggered by `overlays/linux.nix` (exit 1).

**Scope found:** 7 ACTIVE vendorHash shims across 2 files — `overlays/linux.nix` (dnsblockd, discordsync, crush-daily+doCheck) and `lib/lars-packages.nix` (cqrs-lint/go-cqrs-lite, go-humanize-linter, md-go-validator, project-discovery-daemon).

---

## a) FULLY DONE

1. **crush-daily upstream: chromedp v0.19 test-API migration** (the real code work). 5 test files migrated (`ui_behavior_test.go`, `research_smoke_test.go`, `ui_dashboard_test.go`, `ui_focus_audit_test.go`, `ui_trends_test.go`): multi-action `Run(ctx, a, b, …)` → `Do(ctx, …)`, `Evaluate(js, &v)` → `v := Run(ctx, Evaluate[T](js))`, void evaluates/polls → `Evaluate[chromedp.Void]`/`Poll[chromedp.Void]`, `ListenTarget` → the new `chromedp.Console(ctx)` iterator (subscribe-before-navigate), `input.ModifierShift` → `kb.ModifierShift` (cdproto dropped the constants). Whole repo `go vet` + gofmt clean.
2. **crush-daily: REAL product bug found + fixed by the resurrected tests.** The error-page component now emits `rounded-2xl`/`shadow-sm`/`px-6`/`py-3.5`/`mt-8`/`mt-2.5`/`gap-y-3`/`sm:py-10`/`bg-gray-50/60`/`dark:bg-gray-900/40`/`dark:shadow-black/20` — NONE were in the compiled `app.css` (library module-cache classes Tailwind never scans — gotcha-72 class). Fix: +11 classes in `internal/ui/assets/tc-classes.txt`, `tailwindcss` recompile via `nix develop`, all 11 verified by fixed-string grep, 7 page goldens refreshed (diff is CSS-content only).
3. **crush-daily behavioral verification:** full `TestUI_` suite green against real chromium 154 (100 s run) after the CSS fix; before it, exactly ONE failure (`TestUI_ErrorPage_RendersStyled`, deterministic ×4) — the test doing precisely its job.
4. **crush-daily pushed: `a0faf6c`** ("Migrate UI tests to chromedp v0.19 API, restoring the browser-test gate"). Daemon had swept my in-flight work into 5 heuristic commits; consolidated via `git reset --soft a89f9c6` + one proper commit. BuildFlow fast gate: 45 steps, 0 failed (warnings only — pre-existing advisory findings).
5. **md-go-validator upstream FIXED + pushed `3f466de`** (uF0J63iQ → e+jOFi3m, first-hand got-hash from the keep-going enumeration; the shim's old value was RIGHT, upstream was stale). Toolchain leg obsoleted upstream — `package.nix` already builds via `(buildGoModule.override { go = go_1_27; })`. Dirty-tree FOD built green BEFORE push. Re-locked 5e70003 → 3f466de. GREEN in the final enumeration.
6. **project-discovery-daemon upstream FIXED + pushed** — took TWO rounds (see d): `fec79c1` (Mrn25ftf) then `ea6e8ce` (6ZDAkBBB, proper commit message, won the daemon race). Re-locked 1f9b57c → ea6e8ce.
7. **discordsync shim DROPPED** — bit-neutral: upstream `vendorHash.nix` at the locked rev d8f79909 bakes the shim's own `/NYfLmDMx…`. No upstream change needed. GREEN in enumeration.
8. **go-humanize-linter shim DROPPED** — bit-neutral: upstream at locked rev 7f9b7b19 == shim value `JrBhDyCx…`. GREEN in enumeration.
9. **dnsblockd shim DROPPED** (by a PARALLEL session mid-my-session, citing the user's own nh build log; I independently verified root node dnsblockd = 8b8e594d bakes `0koFfQq…` and it was GREEN in my enumeration). No conflict; their drop comment left untouched.
10. **cqrs-lint shim RE-ADDED as the documented NECESSARY exception** — proven got `7wijvzQm…` at the TRUE locked rev (f12a849b); upstream stale at f12a849b AND origin/master; repo mid-churn by a live session (4 unpushed master commits + a 164-file origin commit today) → pushing would have published someone else's in-flight work. GREEN in final enumeration with the shim. Full rationale in the comment block.
11. **crush-daily lock re-locked** 97e1fdde → a0faf6c (targeted `--update-input --refresh`; 4-line lock diff, no blanket churn). The crush-daily FOD built GREEN at a0faf6c — tests compile in the sandbox (browser tests self-skip by design), restoring the doCheck gate.

## b) PARTIALLY DONE

1. **Final verification build is STILL RUNNING** (`/tmp/toplevel-fix-20261011-final2.log`): 0 errors so far, pdd FOD at ea6e8ce actively building. EXIT verdict pending — this report is written while it runs.
2. **SystemNix tree state:** my edits (`overlays/linux.nix`, `lib/lars-packages.nix`, `flake.lock`) were daemon-swept into commit `ac4099bc` — I have NOT yet run the mandated `git show --stat` review of what that commit actually staged.
3. **Post-verification legs NOT run:** `nix flake check --no-build --all-systems`, formatter check on my edited files (`nix fmt --no-update-lock-file -- --ci`).
4. **docs/todo/upstream.md rows** for the cqrs-lint / md-go-validator / pdd shim cycles NOT updated (queue one-liners + library entries must not drift — pending).
5. **AGENTS.md / nix-flakes.md memory updates** NOT done (notable re-learnings: the orphan-node trap cost me a wrong premise TODAY even though it is documented; the "pdd does not follow our pins — its own flake.lock governs FOD content" finding).

## c) NOT STARTED

1. cqrs-lint paste-upstream → push → re-lock → re-drop cycle (blocked on the busy go-cqrs-lite repo; shim stays as NECESSARY).
2. The stale unmerged `origin/cqrs-lint-vendorhash-fix` branch (d84e4d6a4, from the 2026-09-13 era) — never investigated/merged/discarded.
3. Status-report self-harvest of §f follow-ups into `TODO_LIST.md` + domain libraries — **deliberately deferred**: user instructed "write the report, then WAIT FOR INSTRUCTIONS"; no tree edits beyond this report.

## d) TOTALLY FUCKED UP (own errors, all caught + corrected)

1. **Orphan-node trap, walked straight into it.** I jq'd `.nodes["go-cqrs-lite"]` (= 7142e43d) instead of walking `root.inputs` (= `go-cqrs-lite_7` = f12a849b) — the doc explicitly warns "the orphan can make a healthy lock look stale". First cqrs-lint drop comment carried a FALSE premise ("lock moved to 7142e43d, upstream re-pinned"). The enumeration's drv name (`cqrs-lint-f12a849b-…`) exposed it; comment rewritten truthfully.
2. **Evidence claims written BEFORE the evidence existed.** My first-round drop comments said "Build-verified from the lock in the 2026-10-11 keep-going enumeration" — that build hadn't run yet and then FAILED three of them. Violates the evidence-rule spirit; all three comments corrected to the real outcome.
3. **Daemon race lost twice on upstream commits:** md-go-validator `3f466de` and pdd `fec79c1` carry "chore: auto-commit (heuristic)" messages on ORIGIN now (my `git commit` found nothing to commit; the push shipped the daemon's commit). Amending pushed history = forbidden, so the message quality is lost there. pdd's second commit `ea6e8ce` won the race with a proper message.
4. **Skipped the full-suite baseline before touching crush-daily** (go-ecosystem-upgrade Phase 1 discipline). Three full-suite failures then needed a retro-baseline via a clean-HEAD worktree to classify — two were pre-existing (`TestLegacySnapshotRow_DecodesUnderNewStack`, `TestGenerator_Generate_GoldenFile`), one was mine (goldens embed CSS).
5. **Sloppy multiedit batch on ui_trends_test.go:** an ambiguous `old_string: ")"` failed, another edit landed at the wrong indentation, and the batch swallowed the `expr` binding — 3 correction rounds before compile. Should have used precise unique context from the start.
6. Small stuff: `go test -c` exit code masked by `| head` (misread a failing compile as exit 0); `rg -rn` misread as a replace flag produced scary false-alarm output; first edit bounced on the read-before-edit guard; `nix eval --no-link` is not a valid flag.
7. **pdd hash needed two upstream rounds** because I pasted the through-our-lock got-hash from rev 1f9b57c, then re-locked to HEAD where pdd's OWN moved flake.lock (it does NOT follow our pins) changed the FOD content. Wasted one push+relock+build cycle; second measurement (6ZDAkBBB) is context-stable and matches pdd's own CI.

## e) WHAT WE SHOULD IMPROVE

1. **Always resolve lock revs via `root.inputs` mapping, never bare node keys** — make it the reflex (the docs say it; today proved it again).
2. **Baseline before change** — run the consumer repo's full test suite BEFORE editing (Phase 1 of the ecosystem protocol exists because of today).
3. **Never write evidence claims ahead of the evidence** — comments/commits cite runs that EXISTED, or say "pending".
4. **In daemon-active repos, pathspec-commit immediately after each edit** — I lost two commit messages to the race; a `git commit -- <path>` seconds after the edit wins it.
5. **Check `follows` before predicting FOD hashes across a re-lock** — if the input doesn't follow our nixpkgs/go-nix-helpers, ITS OWN lock pins govern the FOD content; measure at the TARGET rev, not the old one.
6. **Never pipe exit codes through `head`** when the verdict matters.
7. The final2 build + flake check + fmt + daemon-commit review must complete before this session's tree state is called done (§b).

## f) NEXT (candidate queue, ~40)

1. Finish/verify the running toplevel build (final2 log) — confirm EXIT 0.
2. Review daemon commit `ac4099bc` contents (`git show --stat`) per multi-agent policy.
3. `nix flake check --no-build --all-systems`.
4. Formatter check on `overlays/linux.nix` + `lib/lars-packages.nix` (`nix fmt --no-update-lock-file -- --ci`).
5. Update `docs/todo/upstream.md`: close/re-pin the cqrs-lint cycle row (shim now NECESSARY-pinned at 7wijvzQm/f12a849b); add the md-go-validator + pdd "done" evidence.
6. Add the orphan-node + "input's own lock governs FOD" lessons to `docs/agents/nix-flakes.md` (sharpen the existing bullets with today's incidents).
7. Decide + execute cqrs-lint upstream fix once go-cqrs-lite quiets down (merge/refresh `origin/cqrs-lint-vendorhash-fix` vs fresh paste of 7wijvzQm), then drop the shim.
8. Fix crush-daily pre-existing failure #1: `TestLegacySnapshotRow_DecodesUnderNewStack` (rejection:report.not_collected on legacy snapshot decode).
9. Fix crush-daily pre-existing failure #2: `TestGenerator_Generate_GoldenFile` (report golden mismatch; `go test ./internal/report/ -update` after deciding whether drift is intended).
10. Resolve the crush-daily templ-components LOCKSTEP pin (flake input v1.19.4 vs go.mod errorpage v1.21.0 — documented trap in its flake.nix; bump both together + regenerate goldens).
11. Reconcile `docs/todo/upstream.md` art-dupl row (says "drop the shim" but lars-packages.nix shows it already dropped — stale queue row).
12. Re-check `nix/vendor-hash.nix` refreshers fleet-wide after the next nixpkgs wave (the recurring re-vendor class: 2026-10-03, 10-05, 10-07 waves all re-broke hashes).
13. Consider a static check that FAILS a drop-comment whose cited lock rev doesn't match `root.inputs` (premise-check automation for the queue-side rule).
14. Capture today's pdd "own-lock governs FOD" case into the fleet infra-follows item (strengthen the 387→454 regrowth argument).
15. go-cqrs-lite: push or discard the 4 unpushed local master commits (owner call — live session territory).
16. go-cqrs-lite: investigate the 164-file origin/master commit wave today (what landed; does cqrs-lint source drift again).
17. crush-daily: run the full `TestUI_` suite inside a nix check with chromium as checkInputs (today the browser gate compiles-only in the sandbox; behavior runs only on dev machines).
18. crush-daily: re-enable + verify `doCheck` end-to-end from SystemNix once (the final2 build proves compile; a documented note that sandbox skips browser tests would prevent future confusion).
19. md-go-validator: verify its own CI (if any) is green with e+jOFi3m under its own lock (contexts agreed this time, but pin drift will re-diverge them).
20. pdd: align its nixpkgs/go-nix-helpers pins via `follows` (kills the two-context hash divergence at the root — the fleet infra-follows item, pdd edition).
21. Same follows-alignment for the other 6 repos in today's inventory (discordsync, dnsblockd, crush-daily, go-humanize-linter, md-go-validator, go-cqrs-lite) — the deep-dup class fix.
22. Sweep for OTHER `.nodes["<input>]`-style reasoning in status reports/docs that may cite orphan revs (same class as my d1 mistake).
23. SystemNix: drop `file-and-image-renamer`-era stale drop-comments into a compact shim graveyard section (the comment blocks are growing unboundedly).
24. Consider a `lib/lars-packages.nix` selftest that greps for `overrideAttrs { vendorHash` and FAILS unless the comment carries a first-hand enumeration log path (make the NECESSARY bar mechanical).
25. niri libdisplay-info shim (overlays/linux.nix): check whether niri-flake dropped the 0.2 pinning yet (drop condition may be met).
26. clickhouseVersionPinOverlay: run its documented drop check (`nix eval nixpkgs#clickhouse.drvPath` vs pinned drv).
27. bunMemoryLimitOverlay + monitor365SwaggerUiFixOverlay: re-verify drop conditions (not vendorHash, but same file, same treadmill risk).
28. crush-daily: decide the `-update` policy for `UPDATE_GOLDENS` vs the report package's `-update` flag (two different golden mechanisms in one repo — unify).
29. crush-daily: fix `TestGenerator_Generate_GoldenFile` root cause or tag as known-red in its AGENTS.md (BuildFlow close-the-loop rule: it currently fails on clean master with nobody watching).
30. go-cqrs-lite: benchstat `rev = "master"` floating pin (existing [ready] row) — still open, bit us adjacent today.
31. Switch the root go-cqrs-lite input from git+ssh to github: (existing [ready] row, NAR-divergence vector).
32. Add a status-report convention: shim drop claims must cite `root.inputs`-resolved revs (write it into CONTRIBUTING or the todo-system rules).
33. Queue hygiene: the `[blocked:push]` label semantics vs today's owner-authorized pushes — docs need the "user directive overrides" case recorded.
34. Verify gitleaks/pre-commit ran on the daemon-swept commits (daemon commits bypass staged-path legs — re-run shellcheck/ruff-equivalents standalone for the touched repos per policy).
35. Consider `git config commit.gpgsign`/hook timing so the daemon's heuristic commits don't win races on repos where message quality matters.
36. nix-flakes.md: document `chromedp v0.19` migration pattern (Run→Do, typed Evaluate/Poll) — it will hit every Go repo using chromedp on the next bump wave.
37. Check which OTHER LarsArtmann repos pin chromedp (fleet exposure to the same compile break).
38. crush-daily: the two datastar/`zz_probe` style throwaway probes — confirm none remain (verified deleted; keep it that way in CI via a testdata lint?).
39. docs/agents/go-ecosystem.md: record the md-go-validator/pdd two-round hash lesson (measure at TARGET rev).
40. Post-final-build: update AGENTS.md routing table if any new doc file lands from this session.

## g) QUESTIONS FOR YOU (cannot figure out myself)

1. **Push authorization scope:** I pushed to crush-daily, md-go-validator, and project-discovery-daemon master under "fix all upstream". The standing queue policy says `[blocked:push]` / "agent sessions never push". Is today's direct-push authority (a) this task only, (b) standing for vendorHash fixes, or (c) standing for everything?
2. **go-cqrs-lite:** is the live session that churned it today (4 unpushed commits, 164-file origin wave) still active — and do you want me to coordinate/push the cqrs-lint vendorHash fix myself once it quiets, or leave that repo entirely to its owning session?
3. **crush-daily pre-existing reds:** `TestLegacySnapshotRow_DecodesUnderNewStack` (legacy-snapshot decode fails "report.not_collected") and `TestGenerator_Generate_GoldenFile` fail on clean master. Do you want them fixed as a follow-up dispatch (and if so, is the report-golden drift intended → just `-update`), or do they belong to a task/owner I should not touch?

---

**Verification state at authoring time:** final keep-going toplevel build RUNNING (0 errors so far, pdd FOD building); everything else in §a is first-hand verified this session. Parallel-session note: an unrelated nsfw-classifier status report appeared in the tree mid-session (not mine, untouched); my SystemNix edits were daemon-committed as `ac4099bc` (contents NOT yet reviewed — §b2).
