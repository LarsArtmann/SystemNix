# Window Closeout — Five Pipeline/Protocol Tasks (2026-09-27 → 2026-09-28)

**Written:** 2026-09-28 20:24 CEST (`date`-derived; collision check `ls docs/status/ | grep task-000001a0e9364cfb` → none; this is a window closeout, not a task report)
**Window:** 5 dispatched tasks, commits `c69319f5`…`da1554c7` (2026-09-27 09:33 → 2026-09-28 20:03), plus the intervening work commits each task landed (`a7b1e2ea`, `9d936718`, `1d755a1a`, `dc988a98`, `534389b5`, `e2d3ef7d`, `13dd17bd`)
**Queue context:** tq pool, SystemNix repo. No `task.reprioritized` facts in the journal for this window (see §h).

---

## Executive summary

A pure documentation-and-pipeline-hardening window. All five tasks landed what they were dispatched to do, every landing carries its `Task-Queue-ID` footer, and every queue surface (TODO_LIST row + `docs/todo/pipeline.md` library row) closed `[x]` with matching DONE notes — no drift detected on any of the five. The window's theme is the verify-gate failure chain: classify environmental gate deaths upstream (go-taskqueue `VerifyGateError`), give agents a triage runbook (CONTRIBUTING), and stop docs-only commits from paying the environmental-flap tax at all (pre-commit docs-only skip). One task (the classification) turned out to be a no-op RE-DISPATCH against already-landed work — and that run earned its keep anyway by discovering the landing was **unpushed** (7 commits ahead of origin), which is now the window's top open item.

---

## a) FULLY DONE (verified, not just claimed)

| # | Item | Evidence |
|---|------|----------|
| a1 | **Re-dispatch verification protocol extended with clauses (a) + (b), both landings, one change** — SystemNix `docs/CONTRIBUTING.md` gained the step-3 sweep-scope requirement, the step-2 loud-probe rule, and the clause-(a) SOURCE-LEVEL-delivery paragraph; the crush-config lesson (`~/projects/crush-config`, commit `6f70200` THERE) mirrored all three. The two live "ships to every host" delivery narratives (CHANGELOG protocol entry + TODO_LIST row-56 DONE note) were re-annotated SOURCE-LEVEL in the same change | SystemNix `e2d3ef7d` (4 files, PATHSPEC-scoped, full pre-commit gate green at io PSI avg60 ~78%); closeout `docs/status/2026-09-27_09-33_task-000001a0e1b7b580f18a2c0308d59c9de220.md` §a1-a7; both queue rows `[x]` with the sweep scope stated (first live execution of clause (b)) |
| a2 | **Status-report file hygiene codified** — new "Verification conventions" block in CONTRIBUTING: filename timestamps MEASURED via `date +%Y-%m-%d_%H-%M`, `ls docs/status/ | grep task-<ID>` collision check before creating, bump-minutes-never-overwrite on collision; convention-first (guard script deliberately skipped per the row's own stance) | SystemNix `13dd17bd` (footer-bearing, 4 files, full hook green incl. a real amend re-run); closeout `docs/status/2026-09-27_10-18_task-000001a0e1d32d1561aa2ef250e6ddbfb805.md` §a1-5; `scripts/check-todo-system.sh` + `nix flake check --no-build` green |
| a3 | **tq verify-gate failure classification (VerifyGateError) landed upstream in go-taskqueue** — `internal/executor/verifygate.go` (167 lines) + tests + agent/status/worker wiring + facade parity; 5 new tests; landing commit `449d72ac`. Independently RE-VERIFIED this window by a no-op re-dispatch run: `VerifyGate` executor tests + `TestVerifyGateRequeuesWithoutAttemptBurn` re-run green (~0.2s each) at upstream HEAD `ad5dacdc`; re-verification evidence appended to the pipeline row | SystemNix `dc988a98` (footer-bearing, 1-line append); closeout `docs/status/2026-09-28_19-21_task-000001a0e8c3db5b909989d9e9986ef542c1.md` §a1-7. **Delivery caveat in §b1** |
| a4 | **Gate triage runbook paragraph landed in CONTRIBUTING "Verification"** — four ordered probes (/run/binfmt existence + heal + durable-fix probe → clean-HEAD baseline worktree → nix-daemon restart → IO pressure vs the ~30-min verify budget), "only all-clean ⇒ INTRODUCED" conclusion rule, cross-references the classification row | SystemNix `a7b1e2ea`; closeout `docs/status/2026-09-28_19-42_task-000001a0e91641b90a686a7d49dce9506f94.md` §a1-3; both surfaces closed, full gate green |
| a5 | **Pre-commit docs-only flake-leg skip landed** — early-exit guard in `.githooks/pre-commit` before the flake leg: docs-only staged diff (all `.md`/`.html`/`.txt`; extension-less files conservatively force the leg; DELETED `.nix` paths still force it via no-`--diff-filter`) skips the eval. Classification unit-tested 5 paths; `bash -n` clean; gitleaks/whitespace/todo-system legs untouched; revisit caveat recorded in the hook comment | SystemNix `9d936718`; closeout `docs/status/2026-09-28_20-03_task-000001a0e928914c50f825a4a2c3513109fa.md` §a1-6; the landing commit itself passed the FULL hook (correct — it contains a non-docs path) |
| a6 | **Queue hygiene held across the window** — all 5 tasks closed both surfaces (`TODO_LIST.md` + `docs/todo/pipeline.md`) with DONE notes; the window's own follow-ups self-harvested at authoring time (rows for the docs-only-skip regression test + E2E fire, the go-taskqueue push `[blocked:push]` row in `docs/todo/upstream.md`, and the post-push consumption row in TODO_LIST §upstream) — no obligations left only in reports | TODO_LIST rows 58-62 `[x]` (verified by grep this closeout), rows 206-207 (post-push chain), pipeline.md classification re-verification note (`dc988a98`), upstream.md `[blocked:push]` row |

## b) PARTIALLY DONE

| # | Item | State | Remaining |
|---|------|-------|-----------|
| b1 | **THE go-taskqueue classification is UNPUSHED** — `~/projects/go-taskqueue` is 7 commits ahead of origin, including `449d72ac`. The deployed `tq` binary (flake input follows origin) cannot classify anything yet, so production verify gates STILL burn attempts on environmental failures; a local crash could also lose the work | Source-landed, tested, row-closed; delivery blocked | Push (owner/push-gated, `[blocked:push]` row in upstream.md) → `nix flake lock --update-input go-taskqueue` → redeploy `tq-agent-pool` → `tq --version` stamps the rev (TODO_LIST:207). **Highest-leverage open item of the window** |
| b2 | **Docs-only skip regression coverage is throwaway-only** — the 5-path classification test ran in `/tmp`, not persisted; no E2E live-fire of the skip log line through a real docs-only commit | Guard landed and logic-tested | Both follow-ups already harvested as TODO_LIST rows (persisted regression test + `--allow-empty` E2E fire) |
| b3 | **The triage runbook is prose, not executable, and probes an UNREPAIRED wound** — `/run/binfmt` durable fix (boot ordering + `preferStaticEmulators`) is in-tree but UNDEPLOYED (host still boots gen 797-era automount anchoring), so runbook probe 1 fires at every reboot until the owner deploy lands | Runbook landed; root causes owned by the `[blocked:deploy]` pipeline row | Durable-fix deploy + post-reboot gate proof (tracked) |
| b4 | **Lesson delivery to hosts (clause (a)'s own subject)** — the protocol clauses + fire-1 lesson exist SOURCE-LEVEL in crush-config (`6f70200`); the SystemNix lock still pins crush-config `031c7c48` and the installed `~/.config/crush/references/lessons.md` carries NEITHER | Owner-gated (deploy authority + input bump) | crush-config input bump + owner deploy (standing `[blocked:user]` row) |

## c) NOT STARTED (backlog the window skipped; none was any task's ask)

- The broader pre-commit fast-path row (pipeline.md:60 — which legs run on CODE diffs) — deliberately out of scope of the narrower flake-leg skip.
- Queue dedup preflight implementation (pipeline.md:157) — the window produced two MORE no-op/re-fire datapoints (the classification re-dispatch; the 4×-refired fix-ticket history cited in CHANGELOG) but no implementation.
- Daemon-race policy codification (pipeline.md:166) — window sessions all landed race-free (PATHSPEC + foreground + show-stat exclusivity checks), adding clean datapoints only.
- Shellcheck coverage for extensionless hooks (`.githooks/*`) — noticed by the 20-03 session, queued as a row.
- All runtime-zero storage/stability backlog (Phase-2 hot-DB waves, offsite-borg go-live, deploy authority) — untouched, correctly: this window was queue/pipeline-layer.

## d) TOTALLY FUCKED UP (regressions, broken gates, debt introduced — across the window)

| # | What | Severity | Disposition |
|---|------|----------|-------------|
| d1 | **"Landed upstream" DONE notes masked an unpushed state** — both classification surfaces said "landed upstream" while the checkout was 7 ahead of origin; only a `git status -sb` run out of report-writing diligence found it. Every consumer (deployed tq, flake lock, other machines) is still on pre-classification behavior | Medium (operational, not data) | Convention fix queued this closeout: "landed upstream" DONE notes must state push state or carry a push follow-up row (new TODO item) |
| d2 | **One full pre-commit gate wasted on a 73-char subject** — the classification re-dispatch's first commit died on the NEW commit-msg hook AFTER the multi-minute flake leg had already run; the hook orders cheap-to-expensive backwards, and this was on a 1-line docs diff — the exact cost the docs-only skip (landed hours later) exists to kill | Low (time) | Mitigated by a5 for docs commits; gate-ordering fix queued (new TODO item: move the length check to the top of commit-msg) |
| d3 | **No-op re-dispatch burned a full dispatch cycle** — the classification task was already closed at HEAD when re-dispatched; the run was salvaged into a genuine verification + the §b1 discovery, but the pre-dispatch satisfied-check that would have answered "why does this dispatch exist" in one command is STILL unimplemented (3rd documented instance) | Low | Tracked (pipeline.md pre-dispatch check row); this window adds evidence, not a fix |
| d4 | **Blind-splice edit discipline lapse** — the re-verification row append was written via scripted splice and committed without viewing the resulting line (caught by self-review; diff stat confirmed shape) | Low | Process note in the 19-21 closeout §d3; no repo damage |
| d5 | **Nothing is broken in the tree** — every gate that ran this window finished green; `nix flake check --no-build` green at each landing; no daemon races (zero sweeps this window), no failed units introduced, no reverts. The window's failures are all process-shaped, not artifact-shaped | — | — |

## e) WHAT WE SHOULD IMPROVE

1. **Order commit-gate legs cheap-to-expensive.** The commit-msg length check needs no repo context and should run before anything multi-minute. One-line move in `.githooks/commit-msg`; combined with the docs-only skip it makes docs landings ~instant.
2. **Make push-state part of the closure contract for upstream-landing rows.** "Landed upstream" without a push verb is ambiguous (d1). Cheapest form: DONE notes say "landed upstream (pushed)" or carry/point at the `[blocked:push]` row.
3. **Land the pre-dispatch satisfied-check.** One footer-grep before dispatch kills the no-op re-dispatch class; three documented instances now. Queue-side (go-taskqueue repo) work, not SystemNix.
4. **Persist hook-guard regression tests at landing time.** The docs-only skip shipped with a /tmp-only test; the repo doctrine (negative-test hook guards like flake checks) was applied late. The harvested rows (TODO_LIST 406/407) close this — but the convention should be "no new hook leg without its persisted fixture".
5. **Cross-link sibling protocol docs.** The classification row and the runbook paragraph reference each other's rows but not each other's reports; a future docs pass should add mutual links and decide the canonical surface (CONTRIBUTING vs `docs/services/tq.md`).
6. **Pin the verify-budget figure to its config source.** The runbook's "~30 min (measured 2026-09-25)" will silently age; reference the queue's actual `verify_timeout` once its location is confirmed.

## f) NEXT THINGS (top items; harvested into TODO_LIST where new — see the Close-out section for what was appended)

1. **PUSH go-taskqueue master** (7 ahead, incl. `449d72ac`) — owner/push-gated; unblocks the entire classification delivery chain (queued `[blocked:push]`, upstream.md).
2. Post-push: re-lock + verify FOD/package + redeploy `tq-agent-pool` + `tq --version` stamp (queued, TODO_LIST:207).
3. Post-push smoke: first REAL firing of the classification — synthetic gate-dead requeues without attempt-burn; annotate the pipeline row (NEW this closeout).
4. Persisted regression test for the docs-only skip guard (queued, TODO_LIST:406).
5. E2E-fire the docs-only skip through a real commit (queued, TODO_LIST:407).
6. Move the commit-msg subject-length check to the top of the hook (NEW this closeout).
7. "Landed upstream ⇒ state push state" closure convention (NEW this closeout).
8. Durable `/run/binfmt` fix deploy + post-reboot gate proof (queued `[blocked:deploy]`; the runbook is load-bearing until then).
9. Queue dedup preflight (queued, pipeline.md:157) — the window's no-op re-dispatch is instance #3.
10. Pre-dispatch satisfied-check implementation (queued, pipeline.md) — same class, queue-side.
11. Shellcheck coverage for extensionless `.githooks/*` (queued).
12. crush-config input bump + owner deploy (installs lessons + clauses; queued `[blocked:user]`).
13. Decide the triage runbook's canonical home + executable-vs-prose stance (NEW blocked questions this closeout).

(Stopped deliberately: everything else in flight is owned by existing tracked rows; padding would duplicate the libraries.)

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Push policy for go-taskqueue:** the classification is 7 commits ahead of origin and production queue behavior depends on it — is push owner-gated for the tq pool repo, or may queue workers push LarsArtmann repos once their own gates are green? (The `[blocked:push]` row cannot be unblocked without this.)
2. **Should the verify-gate triage runbook become executable** (`scripts/verify-gate-triage.sh`, four probes → one verdict), or is the upstream `VerifyGateError` classification considered sufficient, making a repo-side script redundant by design?
3. **What is the authoritative verify-budget source of truth** (the runbook cites "~30 min, measured 2026-09-25") — where does the dispatch payload set `verify_timeout`, and is 30 min still current? (Second-order: should the runbook live in CONTRIBUTING or `docs/services/tq.md`?)

## h) BAND DRIFT

**None recorded.** The tq journal holds ZERO `task.reprioritized` facts for the window span (2026-09-27 09:00 → 2026-09-28 21:00) — verified via `tq facts -type task.reprioritized` (0 facts) and a window-span scan (only claimed/completed/failed/requeued/enqueued/dead/cancelled types present). Priority movement this window happened via the normal harvest/enqueue path (the post-push chain rows filed at the 19-21 closeout), not via explicit reprioritization events, so there is nothing to account for under ADR-0015.

---

**Self-check:** every claim above cites a commit, file, journal query, or closeout report from this window or verified at closeout time (queue-row greps, `tq facts` type census, CHANGELOG coverage grep, TODO_LIST 406/407 + 206/207 presence, upstream.md `[blocked:push]` row). §b1 is the load-bearing discovery — verified live via the 19-21 closeout's `git status -sb` evidence and the upstream.md row it created. No unrelated research performed.
