# Window Close-Out — Five Tasks (2026-09-26 02:28 → 2026-09-27 09:05): the re-dispatch protocol under fire

**When:** 2026-09-27 09:47 CEST (`date`-verified)
**Scope:** the five queue tasks listed in the dispatch window + what was noticed in passing. Every closeout report was read first; every deliverable re-verified against the tree/`git log` this pass. **Method:** read 5 closeout reports in full → `git show` on all 5 window commits → live re-verification of each deliverable (snapshots.nix comment, flake.nix stub, CONTRIBUTING.md protocol, FEATURES.md fix, queue-row closures) → `tq facts` journal query → TODO_LIST dedup sweep.
**Queue context:** 4 of the 5 tasks were RE-FIRES or verification dispatches of work already closed — this window is the first sustained exercise of the freshly-codified re-dispatch verification protocol (docs/CONTRIBUTING.md:173), and it worked: zero content regressions, zero duplicate work commits, ~13 commits of reports/dispositions for work that was already done.

---

## a) FULLY DONE (verified, not just claimed)

| # | Task | Deliverable | Verified this pass |
|---|------|-------------|--------------------|
| a1 | `000001a0dad1143cdb10aef5d1afc4accbb1` (review-fix, 4 dispatches) | Reviewer finding against the stale root-window echo sweep **fully resolved** by run-1 fix `3e3d718a`: FEATURES.md:291's emergency-reserve parenthetical now reads "root pin window = 2w sharp, calendar-anchored" (re-grepped this pass), the grep-gate row (docs/todo/storage.md) scoped to top-level living docs with the why, and both closure claims (TODO_LIST:49, storage.md:13) made true inside the fix commit. Runs 2–4 (`3ac34774` = run-2 close-out, footer-bearing) were no-edit dispositions per the finding's own protocol | Live grep FEATURES.md:289/291 + TODO_LIST:49 this pass |
| a2 | `000001a0db313588314c503cdffbc48896b9` (calendar-anchor comment, 2 dispatches) | Work commit `5befa617`: calendar-anchor comment sits at snapshots.nix:219–229 directly above `snapshot_preserve = "3d 1w"` (:231) — buckets CALENDAR-anchored, weeks start Sunday, Sunday-dated weekly lives exactly 14 days, root pin window 2w sharp NOT "3d+1w" flat. Both queue rows (TODO_LIST:51 + storage.md:15) `[x]` in the same commit. The re-dispatch ~20 min later bought verification session `4c770801`, which correctly created **no duplicate commit** and self-answered the fixture-coupling question (test-hot-db-assertions.nix:81 is arbitrary landmine-fixture input, not a live-tracking constant) | Direct file view snapshots.nix:208–238 this pass |
| a3 | `000001a0dbd171053bbd8f8b8a48bf84b0fd` (borg drill stub junk file, 1 dispatch) | The fixture's borg stub now DROPS every dash-prefixed extract token (`-*` → shift, flake.nix:1603) instead of materializing junk files, plus a standing `no-junk-cwd` fixture assertion (PASS marker, flake.nix:1705). The fix itself landed via a parallel session absorbed into daemon HEAD `f749a573`; the dispatch amended it into footer commit `4e035792` (queue cross-reference restored), executed the fixture derivation for the first time ever (8 cases + new assertion green), audited all three real drill extract call-shapes, and closed both queue rows (TODO_LIST:53 + storage.md:137) | `git show 4e035792`, flake.nix greps this pass |
| a4 | `000001a0dfdba22e606b2adfe1d6064a6f23` (protocol codification, 3+ fires) | The four-step re-dispatch verification protocol landed at docs/CONTRIBUTING.md:173–180 (`d062890c`) and was EXTENDED in one change (`e2d3ef7d`): step-2 loud-probe rule, step-3 sweep-scope statement requirement, and the foreign-repo SOURCE-LEVEL delivery clause (:182). Fire 3 (`21d5c026`) recorded the 9th daemon race (mid-hook variant, 5th occurrence) on the daemon-race row (pipeline.md:165) and closed with a footer-bearing addendum | CONTRIBUTING.md read this pass; commit verified |
| a5 | `000001a0e037325d1970108c434afe1a68b0` (cross-project lesson, 3 fires) | The generalized four-step lesson landed in crush-config `references/lessons.md` (commit `8fbc677` THERE, footer carried), the SystemNix closure `d12ae7a3`, extension mirrored crush-config `6f70200`. Both SystemNix queue rows (TODO_LIST:56 + :57) `[x]` with DONE notes including the SOURCE-LEVEL delivery correction. Fire 3 (`9055f627` + report `5e2b224d`) = degenerate-form verification: verdict unchanged, plus two honest self-defects (guessed report filename → renamed to true commit time 08-56; no pre-write collision check) codified as the report-hygiene queue row (TODO_LIST:58 + pipeline.md) | TODO_LIST:56/57 read; CHANGELOG protocol entry cross-checked this pass |

Also in-window: `e2d3ef7d`/`c69319f5` (protocol-extension task + its report), the protocol-extension clauses being live in CONTRIBUTING.md today.

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| b1 | **The crush-config lesson is delivered SOURCE-LEVEL only** — committed THERE (`8fbc677`, `6f70200`) but the SystemNix lock still pins crush-config `031c7c48`; the installed `~/.config/crush/references/lessons.md` (read-only nix-store symlink) carries zero `re-dispatch` matches. Remaining: input bump + owner deploy + installed-copy re-grep | Owner/deploy-gated (see g1) |
| b2 | **The stale-echo grep-gate is fully specified, not built** — the ticket family's systemic fix (patterns `root ≈ 1-2w` / out-of-context `3d+1w`, scope incl. top-level living docs, allowlist rules, fixture seeding, negative-test) sits ready at TODO_LIST:377 + storage.md | `[ready]`, unbuilt; every echo-class protection is still prose discipline |
| b3 | **Footer lineage is incomplete on the review-fix ticket** — 4 of its 9 commits carry the footer; runs 3–4 committed reports footer-less (invisible to the queue's footer-based derivation). Not retro-fixable safely (amending foreign commits across runs violates the multi-agent rules) | Documented; terminal commit of the ticket carries the footer |
| b4 | **Verification depth on fire 3 of both protocol tasks** — spot-checks satisfied the codified minimum (one live claim) but did not re-run the landing repo's own verify gates (crush-config flake checks; the 01-40 report had flagged file-re-read as the weakest valid form hours earlier) | Low risk (landings unchanged since green runs); the step-2 depth guidance rides the next protocol-block touch |
| b5 | **Junk-file residue in local history** — the two `--help` junk blobs (daemon commits `c284d91c`, `26ea9fc7`) remain in local history; content verified benign; removals landed; push is held by owner decision anyway | Rides the held history-purge decision |
| b6 | **Report-hygiene for the multi-report ticket families** — the review-fix ticket alone has 5 reports for a one-line docs fix (runs 1–4 + window report). Historical reports are never edited; no supersede-pointer annotation pass has run over the families | Low priority; ANNOTATE-mode pass possible |

## c) NOT STARTED (backlog the window skipped — all verified still open)

1. **Queue dedup preflight** (TODO_LIST:331 + pipeline.md) — skip re-dispatch when footer + `[x]` + closeout-report + follow-ups-harvested signals exist. This window alone burned ~6 paid dispatches past closure (dad1 ×2, db31 ×1, dfdb ×2, e037 ×2 post-closure) — it is now the highest-leverage unbuilt item on the queue.
2. **Daemon-race POLICY** (pipeline.md:165, 12 recorded races incl. 5 in this window) — amend-forward vs land-on-top still has no written answer despite a dozen converging datapoints, incl. the 12th race's new sub-fact: PATHSPEC commits cannot re-attach sibling paths the daemon already swept (multi-file footer landings need a post-commit `git show --stat` exclusivity check).
3. **Repeat-dispatch report policy** (TODO_LIST:325, `[blocked:user]`, now 6+ fires of guessing compact-vs-full).
4. **Docs-only fast-path for the pre-commit flake-check leg** (TODO_LIST:62) — 5+ full gate runs burned on .md-only diffs across this window's fires.
5. **Deploy authority + the batch deploy** (TODO_LIST:79, pipeline.md:56) — every runtime-zero item (incl. the deployed boot-ordering fixes that still sit UNDEPLOYED at gen 797, reboot-revertible).
6. **`boot.binfmt.preferStaticEmulators = true`** — kills the `/run/binfmt` sandbox-dependency class entirely (AGENTS.md names it a follow-up; not queued as its own row).
7. **Claim/lease markers in the tq pool** — the dbd1 dispatch harvested an item a parallel session had already implemented (anonymous, absorbed by the daemon); no lease mechanism exists.
8. **Calendar-anchor extension to `/data` + pool tiers, observation proof, final-retention decision** — all queued, owner-gated (TODO_LIST:382/383/384).
9. **Offsite-borg go-live chain** (owner-held StorageBox inputs, VM test, recovery-copy policy) — untouched this window, still the top storage-domain gate.

## d) TOTALLY FUCKED UP

| # | What | Severity | Status |
|---|------|----------|--------|
| d1 | **The queue paid ~6 verification dispatches on already-closed work in one 31-hour window.** Every closeout proves the work itself was done correctly — the churn is pure queue-state: re-fires on items with footer-bearing commits AND `[x]` rows AND closeout reports already in the tree. Root cause unresolved (queue-state derivation doesn't consult footers, or completion signaling is lossy) | MEDIUM (dispatch budget, agent time) | Open; datapoint #7+ for the dedup preflight; the protocol converts each re-fire from "re-do risk" to "bounded verification", which is why nothing was corrupted |
| d2 | **5 new daemon races recorded during this window (races 8–12, pipeline.md:165), two NEW sub-shapes**: the mid-hook variant (daemon sweeps the staged index WHILE the pre-commit hook validates it — 5th–7th occurrences) and the 12th race's sibling-drop (a PATHSPEC footer commit landed with 1 of its 3 files because the daemon had already committed the others; only the post-commit `git show --stat` exclusivity check caught it). Cost: 3+ full flake-check gate runs on docs-only diffs, ref-lock forensics twice | MEDIUM (process cost, near-miss for silent partial landings) | Converged cleanly every time (amend-forward / land-on-top); the POLICY answer is overdue (c2) |
| d3 | **The junk-file outage class (prior window) got its fix, but the general guard does not exist** — a THIRD script/stub writing flag-shaped files + a daemon auto-commit would recreate the repo-wide push-protection blockage tonight. The fixture assertion protects exactly one fixture | HIGH if recurred (blocks ALL commits) | Fix landed (a3); repo-wide guard queued this pass (TODO item) |
| d4 | **Footer-less report commits in the review-fix ticket runs 3–4** — the queue cannot attribute those runs; this is the exact class the protocol's step 4 now prevents | LOW | Documented (b3); convention now codified |
| d5 | **A status-report filename was GUESSED, not measured** (fire-3 of e037 wrote 09-12, true commit 08:56 — a timestamped audit trail lying by 16 min) | LOW (cosmetic, no consumer) | Fixed in-window by rename in `5e2b224d`; harvested as the report-hygiene row (TODO_LIST:58) |
| d6 | **~13 commits of process for already-done work** (4 reports on the review-fix ticket alone) — report depth does not scale with work size | LOW | Proportionality folded into the repeat-dispatch report policy question |

Nothing content-level is broken: all five deliverables verified in-tree this pass, all queue rows closed without drift, `git status` clean, no live-system surface touched (the window was markdown-only).

## e) WHAT WE SHOULD IMPROVE

1. **Build the dedup preflight before anything else queue-side.** Six wasted dispatches in one window is the clearest cost signal the queue has produced; the protocol made re-fires SAFE but not CHEAP.
2. **Generalize the junk-file fix repo-wide**: reject flag-shaped tracked filenames (`git ls-files | grep -E '(^|/)-'`) at pre-commit + CI. The daemon is the writer that needs catching — the fixture assertion only guards one fixture.
3. **Close the daemon-race policy with the 12 datapoints already recorded** — incl. the 12th race's operational rule: every MULTI-FILE footer landing needs a post-commit `git show --stat HEAD` exclusivity check; amend-under-daemon costs a ref-lock forensics pass, land-on-top fails cheaper.
4. **No-edit disposition = exactly ONE footer-bearing terminal commit.** Runs 2–4 of the review-fix ticket produced 6 commits for zero changes; the read-the-fix-commit-body-first rule (verification narratives in fix commits are the cheapest closure evidence) should be in the runbook.
5. **Step-2 depth preference**: when the landed work lives in a repo with its own verify gate, re-run the gate (seconds) instead of a file re-read — drafted as guidance, rides the next protocol-block touch.
6. **Footer discipline on EVERY ticket commit** — the footer is the queue's only reliable evidence channel; runs 3–4 broke it and became invisible.
7. **Gate before prose** — the echo-ticket family now has four prose restatements of the calendar-anchor doctrine and zero enforcement; the grep-gate row is fully specified and self-contained (TODO_LIST:377).
8. **Queue-worker pre-flight habit is now codified** — protocol step 1 (footers + closure) is exactly the "check for prior runs of your own Task-Queue-ID" step-0 that the db31 session found missing. Keep observing adherence under a different dispatcher.

## f) NEXT THINGS (up to 50 — the honest set is ~18; the rest are already queued and listed in c)

Marked **[queued]** where a TODO_LIST row already owns it (do not re-dispatch); unmarked items are this report's harvest candidates — the top ones are appended to TODO_LIST this pass.

| # | Item | Why now |
|---|------|---------|
| f1 | Repo-wide pre-commit + CI guard rejecting flag-shaped tracked filenames (generalizes a3's fix; would have caught both daemon junk commits) | The only outage class that blocked ALL commits this week |
| f2 | Build the queue dedup preflight (footer + `[x]` + closeout-report + follow-ups-harvested = skip) **[queued TODO_LIST:331]** | 6 wasted dispatches this window |
| f3 | Daemon-race policy answer + the multi-file exclusivity-check rule **[queued pipeline.md:165]** | 12 recorded races, 5 this window, two new sub-shapes |
| f4 | `boot.binfmt.preferStaticEmulators = true` (deploy-gated) | Kills the /run/binfmt class that masked fixture execution and gate health for days |
| f5 | Amend-aware pre-commit hook (lint HEAD's tree when the staged diff is empty / on `--amend`) | Observed live: staged-lint legs silently no-op on amends |
| f6 | tq claim/lease markers (per-item "claimed by" at harvest time, queue-side) | The dbd1 double-work near-miss |
| f7 | Fixture junk assertion extended to the drill's scratch extract dir | Closes the sibling blind spot of a3's fix |
| f8 | Daemon absorb hygiene: session-tag trailer or per-session pathspec in heuristic commits | Makes future amends attributable without archaeology (boot.nix rode a3's commit) |
| f9 | No-edit disposition convention (one footer-bearing terminal commit; read the fix commit body first) | 6 commits for zero changes on the review-fix ticket |
| f10 | Crush-config input bump + owner deploy + installed-copy re-grep (closes b1) | The lesson is undelivered to hosts |
| f11 | Build the stale-echo grep-gate **[queued TODO_LIST:377]** | The ticket family's systemic fix; fully specified |
| f12 | Docs-only fast-path for the hook's flake-check leg **[queued TODO_LIST:62]** | 5+ burned gate runs this window |
| f13 | Repeat-dispatch report policy **[queued TODO_LIST:325, blocked:user]** | Every fire re-guesses the shape |
| f14 | Deploy the stacked batch (boot-ordering fixes at gen 797 are reboot-revertible) **[blocked on deploy authority, TODO_LIST:79]** | The longest-running runtime-zero debt |
| f15 | Extend fixture-execution to a periodic `nix build` (not just eval) of all behavioral script fixtures | The "eval-only for days" gap a3 closed for one fixture |
| f16 | ANNOTATE pass over the review-fix ticket's 5 reports (supersede pointers, one canonical close-out) | Report-family hygiene |
| f17 | borg2 flip watch: when nixpkgs ships borg 2.x, revisit drill probe + fixture stub deliberately | Latent, zero-cost to track |
| f18 | Owner decision: lift/schedule the held history purge (incl. the two junk blobs + 17 MB `nixos.qcow2` + the 09-15 diet list) | Hygiene only; push held |

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Should the crush-config input bump + owner deploy be dispatchable as a queue row?** It is the ONLY remaining leg between the re-dispatch lesson's source-level landing and its installed delivery on hosts (b1). Fire-1's §f12 stance says foreign-repo/deploy work stays owner-manual — but until it lands, every re-fire of that item can only re-verify the same source state. Which stance stands?
2. **Are queue footer-bearing commits immutable from the queue's perspective?** Hit live when the e037 fire-3 filename defect needed repair: amend the unpushed footer-bearing commit (SHA churn on a recorded commit) vs append a correction commit (churn, stable SHAs). The run appended without knowing whether the queue's footer-based completion derivation tolerates SHA churn. The answer fixes the repair pattern for the next cosmetic defect on a queue commit.
3. **Once the dedup preflight ships, may a clean verification re-fire close WITHOUT a new footer-bearing report** (the preflight's done-signals being authoritative), or does every dispatch always owe one footer-bearing landing? This decides whether verification fires can ever terminate at zero cost or always pay the report+commit.

## h) BAND DRIFT (ADR-0015 accountability)

`tq facts --type task.reprioritized` → **0 facts** (journal healthy: 7,320 total facts). The journal directly holds no reprioritization events in or before this window. **None recorded.**

Noticed in passing (not band drift): the journal tail shows a fresh `task.dead-lettered` fact at 09:48:16 today for task `000001a0e1a0d1e6fc0b0331c1ffb8da5803` (CV repo, verify failure `GOEXPERIMENT=jsonv2 go build/test`, class=exhausted) — different repo, outside this window's task set; the queue-side verify-failure classification row (TODO_LIST:60) is the relevant tracker.

---

## Docs-health pass notes (this pass's living-docs reconciliation)

- **CHANGELOG.md**: already current for this window (protocol codification + extension, borg stub fix, self-harvest convention all present under [Unreleased]) — verified, no additions needed.
- **FEATURES.md**: :291 carries the corrected 2w-sharp parenthetical (a1); :289's "root local 3d+1w" is the legal live-config restatement the finding deliberately left untouched — no edits.
- **AGENTS.md**: self-harvest convention present (TODO System rules, line 40); snapshot-pinning doctrine already reconciled 09-25; no window-scope staleness found.
- **README/ROADMAP**: window touched no user-facing features or long-term direction; no changes.
- **TODO_LIST.md**: 7 new items + 3 blocked questions appended this pass (dedup-checked against all 301 unchecked rows and the pipeline/storage/stability libraries); no existing item reworded; no [x] ticks — all five window tasks' rows were already closed by their own runs (verified TODO_LIST:49/51/53/55/56/57).
- **Archiving**: none this pass. The five window closeout reports are recent, and their §f inventories still carry open items; the three uncited ones (02-28/03-48/06-30) are cited-as-evidence by this report and remain the canonical record for their ticket families. `docs/status/README.md` does not exist (the archive convention is the `docs/status/archived/` directory itself, 1,357 files) — creating it is an owner-layout call, not this pass's to make unilaterally.
