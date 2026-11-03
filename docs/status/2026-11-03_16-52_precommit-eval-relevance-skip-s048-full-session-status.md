# Pre-commit eval-relevance skip (S-048) — full session status + self-review

**Session:** 2026-11-03, ~16:03–16:52 CET · **Trigger:** owner complaint — `2540799 nix flake check --no-build --all-systems … 20G` ("20 GB RAM for a Nix check is really fucking to much!")
**Baseline HEAD at start:** `0416cec8e` · **HEAD at report time:** `3c420968c` · **Box during session:** 110Gi/124Gi used, swap 46Gi→40Gi, mem PSI some avg60 ~6%

## Scope line — what this report verified vs did NOT

**Verified this session (command/artifact in parentheses):** the 22GB process was the pre-commit hook's flake-check leg spawned by a parallel session's `git commit` (`ps` parent chain → `bash .githooks/pre-commit` → `git commit 0416cec8e`); it completed green on its own (`/tmp/nix-check.log` 996 lines, "all checks passed!", 16:03); the new classification logic (fixture `scripts/test-precommit-eval-skip.sh`: 6 static + 12 dynamic cases green in-place AND in wiring shape); both mutation negatives caught (sed-mutated hooks, exit≠0 + correct T-assert named); fail-loud guard on lost lib (broken-lib run exits 1 with the loud message); shellcheck `--severity=warning` clean on all three touched shell files; `nix fmt -- flake/parts/checks/selftests.nix` → "0 changed"; sandbox check derivation green (`nix build .#checks.x86_64-linux.precommit-eval-skip-selftest` → `/nix/store/3wrpcrwl…-precommit-eval-skip-selftest`); tree-wide `--all-systems` eval green at the commits that carried `flake/parts/checks/selftests.nix` (the daemon's own hook runs on `e54b9a37b` + `3550341b8` — both landed); TODO-system checker rc=0 (`bash scripts/check-todo-system.sh`).

**NOT verified (and why):** no real commit has exercised the new SKIP branch live yet (every commit after my hook edit staged eval-relevant or predated it — the skip is fixture-proven only, G1–G4); CI (`nix-check.yml`, negative-tests nightly) unobserved — nothing pushed, per policy; the two OTHER consumers of `EVAL_RELEVANT_PATHS` (`deploy-when-quiescent.sh` heat-check, `vendor-freshness.sh` §11 adoption-pending) not re-verified after my array addition — direction is conservative-by-construction but unproven; peak-RSS of the canonical check not re-measured (the 22GB observation stands in); Darwin side untouched (n/a for a hook-leg change); papdashboard vendorHash + TODO_LIST/stability/upstream churn in the worktree is parallel-session work, examined only enough to not collide.

---

## Timeline

| Time | Event |
| --- | --- |
| 16:03 | Diagnosed PID 2540799: hook leg, 22GB RSS, 7min elapsed; parent = parallel session's commit; check completed green mid-diagnosis; no kill needed |
| 16:05–16:15 | Pre-reads: S-048 row (TODO_LIST:1610 / pipeline:547) = exact match; `precommit-eval-cache.sh` (NO verdict cache — documented); `eval-relevant-paths.sh` shared array; nix-flakes.md memory profile (~20GB known since 2026-10-12); docs-skip fixture + selftests.nix wiring pattern; buildflow skill loaded (hook is repo-owned; buildflow is one leg) |
| 16:20–16:32 | Implemented: array + reap-names, hook classification, new selftest (rename from test-precommit-docs-skip.sh), wiring + 2 mutation negatives, eval-cache comment, 6 doc surfaces, 3 row ticks |
| 16:32–16:47 | Verification loop; found and fixed 4 self-inflicted test bugs (details §d); shellcheck/fmt clean |
| 16:47–16:50 | Daemon swept finals (`3550341b8`); sandbox `nix build` of the check GREEN; parallel session `825b8a4aa` landed my row close-outs under a named message |
| 16:52 | This report |

---

## a) FULLY DONE

1. **Root cause diagnosed end-to-end** — not "nix is hungry" but: the 2026-09-28 docs-only skip predicate under-covered the non-eval set; `.githooks/*`, `scripts/*.sh`, `.github/*` staged diffs forced the ~20GB/4–7min `nix flake check --no-build --all-systems` walk on every such commit (2026-10-20 OOM-kill + today's 22GB run both this class).
2. **Fix landed and green** — `.githooks/pre-commit` skip predicate now keys on the SHARED `scripts/lib/eval-relevant-paths.sh` array (`modules platforms flake.nix flake.lock flake lib pkgs` + the eval-parsed `scripts/lib/buildcache-reap-names.sh`); docs-typefiles (.md/.html/.txt) carve out everywhere; ANY staged deletion/rename forces the walk (`--diff-filter=DR` — eval `readFile()`s non-parsed sources: content only moves drvPaths `--no-build` never realizes, absence throws). No verdict cache (deliberate — the repo's own documented safety model), no PSI gate (no repeat class left to gate; documented in the tick).
3. **`scripts/lib/eval-relevant-paths.sh` gained its missing eval-PARSED member** — `scripts/lib/buildcache-reap-names.sh` (regex-parsed with `throw` by `lib/buildcache-cache-names.nix`; was outside the array AND outside the parity leg's pathspec — a real under-coverage hole found by design-analysis before it bit).
4. **Selftest rebuilt** — `scripts/test-precommit-eval-skip.sh` (git-mv'd lineage from test-precommit-docs-skip.sh): 6 static asserts (T1 shared-array source anchored `^source…$`; T2 pathspec walks `"${EVAL_RELEVANT_PATHS[@]}"`; T3 pinned to the full `STAGED_STRUCTURAL=$(… --diff-filter=DR)` assignment line; T4 carve-out grep; T5 logged skip; T6 empty branch) + 12 dynamic fixture cases (G0 empty/`--allow-empty` shape → SKIP_EMPTY; G1 docs-only; G2 **today's exact 22GB shape** (.githooks/pre-commit + docs/todo/pipeline.md); G3 scripts/.sh + .github/.yml; G4 .md under eval roots; G5–G8 eval-root paths; G9 reap-names content edit; G10 deletion outside eval roots; G11 rename) + fail-loud guard on a lost/unset lib.
5. **Wired + sandbox-proven** — `checks.precommit-eval-skip-selftest` (flake/parts/checks/selftests.nix) copies test at `scripts/` depth (REPO_ROOT resolution), runs the fixture + BOTH mutation negatives (carve-out narrowing → T4; structural-leg drop → T3); `nix build` green.
6. **Docs all landed** — nix-flakes.md (memory-profile section: when the hook pays the walk; coverage section: the new predicate + why no verdict cache); AGENTS.md:166 stale "Do not add `--all-systems` to CI" corrected (CI has run it since 2026-09-28 — flagged drift, closed on sight); FEATURES.md:482 stale "no --all-systems" corrected; CONTRIBUTING.md selftest list renamed; `precommit-eval-cache.sh` safety-model comment updated to match reality again; CHANGELOG [Unreleased] entry.
7. **Rows closed on BOTH surfaces** — TODO_LIST:1610 + pipeline.md:547 (S-048) ticked with full close-out; pipeline.md:228 (empty-commit fixture row) ticked via G0. Verified present in HEAD (grep ×3 = 3).
8. **Race discipline held** — hook edited only in a verified hook-process-free window (bash reads scripts incrementally; a mid-flight edit corrupts the running instance); old test removed via `trash` after two `index.lock` refusals; no parallel-session file touched (papdashboard.nix vendorHash, nix-flakes.md TOC hunk, TODO/stability/upstream rows all left alone).

## b) PARTIALLY DONE

1. **S-048 ticked while one named risk is mitigated, not eliminated**: the FIRST eval-relevant commit after any change still pays the full ~20GB peak (tonight's box: 110Gi used + 40Gi swap). Frequency collapsed (every commit → only eval-relevant commits), the OOM tail remains.
2. **Live SKIP-branch proof owed** — fixture-proven only; the next real docs/scripts/`.githooks`-only commit is the first live exercise (watch for the "Eval-irrelevant staged diff … skipping" line).
3. **CI green unobserved** — shellcheck job + `nix-check.yml` + nightly negative-tests will hit my files on push; local shellcheck ran the same severity, but the run hasn't been watched.
4. **Other EVAL_RELEVANT_PATHS consumers not re-verified** — `deploy-when-quiescent.sh` (heat-check) and `vendor-freshness.sh` (§11 tree-stamp; array adoption still its own pending row) now see reap-names too. Conservative by construction; unproven at those sites.

## c) NOT STARTED (deliberate non-goals, documented in the tick + this report)

1. **Verdict/content-hash memo for the check leg** — rejected on the repo's own safety model (`precommit-eval-cache.sh`: a verdict cache trades phantom-green risk on the primary gate for a thin win); the premise that made it tempting ("every remaining run is eval-relevant") is now TRUE again by construction.
2. **PSI/memory gate** — rejected with it: no per-commit repeat class remains to gate; a storm-skip would re-open the "gate silently didn't run" class the repo explicitly rejects.
3. **vendor-freshness.sh §11 inline-list → array adoption** — pre-existing dedicated row, untouched by design ("a deploy-battle-tested script gets its own commit, not a rider").

## d) TOTALLY FUCKED UP (all caught BEFORE landing; none shipped — but first-pass quality was poor)

1. **Four bugs in my 130-line fixture, found only by executing it**: (1) G3 batched reap-names' initial `git add` into a SKIP case while reap-names was (correctly) now eval-relevant; (2) the wiring copied the test FLAT (`$scratch/test.sh`) → `REPO_ROOT` resolved to the mktemp PARENT → lib source failed silently → unset array → `"${ARR[@]}"` expands empty under bash5+`set -u` → `git diff -- … --` classifies EVERYTHING relevant. Caught only because I hand-simulated the runCommand body instead of trusting the in-place pass — luck-discipline, not design; (3) T3's assert matched the flag string ANYWHERE — the hook's comment mentions `--diff-filter=DR`, so the structural-drop mutation initially PASSED (the mutation negative did its job only after I pinned the assignment line); (4) the fail-loud guard was itself wrong TWICE — first `${#ARR[@]}` on an unset array is a `set -u` unbound error that if-conditions swallow to false (the exact trap class I was writing a guard against), fixed with the one set-u-safe probe (`${ARR[*]-missing}` default expansion).
2. **Process waste**: 4 edit attempts rejected for "must View first" (I grepped instead of Viewed — knew the rule); one multiedit failed on transcription typos (btrfs-probs/btrfs-progs, "those fire"/"they fire") — fixed by anchoring short unique substrings; the first quiescence poll burned 120s foreground before auto-backgrounding and never found quiet (parallel sessions commit continuously — should have been short-poll + immediate action from the start, which is what worked).
3. **Honest correction of my own todo bookkeeping**: the "kill the runaway process" task is marked completed — nothing was killed; the process finished green during diagnosis. The correct close-out is "moot: completed on its own", which I did not write at the time.

## e) WHAT WE SHOULD IMPROVE (self-review answers)

1. **What did you forget?** A session status report at the time (the user had to ask); live-proof of the skip branch; re-verifying the array's other consumers. Also: I initially designed a content-hash memo before READING that the repo had already rejected that class — reading `precommit-eval-cache.sh`'s safety model first would have saved a full design cycle.
2. **Stupid things we do anyway:** the pre-commit buildflow leg ran 4+ MINUTES on a docs-only commit tonight (over its own `--budget 150s`) — a second long leg of the same "hook too heavy" disease, unexamined here; daemon attribution stays blurry (my row close-outs rode a parallel session's named commit `825b8a4aa` — correct content, muddled authorship).
3. **What could you have done better?** Write the fixture FROM the wiring shape first (test at `$scratch/scripts/` depth), not the reverse; anchor static asserts to exact code lines from the start (mutation negatives exist precisely to teach this); run the fail-loud guard's failure mode BEFORE trusting it.
4. **What can you still improve?** The verification matrix ended good (in-place, wiring-shape, mutations, broken-lib, shellcheck, fmt, sandbox build, daemon-committed tree eval) — it should START as that matrix, not accrete through four failures.
5. **Did you lie?** No claim in the close-outs/CHANGELOG was false at write time; two in-flight claims were corrected mid-session before landing (the "kill" todo framing; the abbreviated live probe that printed a misleading "RUN" for an empty index — never published, re-derived in G0 instead).
6. **Ghost systems?** None created — the check is wired into `checks` and runs on every `nix flake check`; the predicate is wired into the hook that consumes it.
7. **Split brains?** No new ones: one shared path definition, three consumers. The `'\.(md|html|txt)$'` regex exists in hook + fixture-verbatim-copy — the repo's established fixture idiom, and T4 pins drift. The REAL pre-existing split brain is `vendor-freshness.sh`'s still-inline §11 list vs the shared array (its own pending row — my array change widened the gap by one member).
8. **Tests?** Stronger than the repo median now (static + dynamic + 2 mutation negatives + fail-loud), but the mutation negatives only became trustworthy after being caught being weak — proof they earn their place.
9. **Scope creep?** Contained: the FEATURES/AGENTS stale-claim fixes and the pipeline.md:228 row close were on-sight fixes inside the touched surface; the buildflow-leg observation is REPORTED, not touched.

## f) Up to 50 things next (session-scoped + what I noticed; direct follow-ups marked [harvested])

1. [harvested] **Live-proof the new SKIP branch**: watch the next docs/scripts-only commit for the "Eval-irrelevant staged diff … skipping" line; if it instead runs the walk, the predicate is wrong in production (fixture says it isn't).
2. [harvested] **Re-verify the other EVAL_RELEVANT_PATHS consumers** after the reap-names addition: `deploy-when-quiescent.sh` heat-check behavior + the §11 tree-stamp (vendor-freshness) — conservative by construction, prove it anyway.
3. [harvested] **Pre-commit buildflow leg ran 4+min on a docs-only commit** (`buildflow --build-mode pre-commit --staged-only --budget 150s`, observed 16:2x) — either the budget doesn't bind or steps stack past it; second "hook too heavy" disease, diagnose in the buildflow repo or gate the leg harder here.
4. Push (owner-gated) and watch the first CI run over these files (shellcheck job, nix-check `--all-systems`, nightly negative-tests).
5. `nix fmt -- --fail-on-change` sanity over the whole tree after the daemon's next sweep (formatting arbiter vs. parallel sessions' edits).
6. The hook still writes `/tmp/nix-check.log` + `/tmp/lock-build.log` — pre-existing volatile-tmpfs row already queued (scripts → `~/.cache`); now two files, same fix.
7. Consider whether the OOM tail needs more than frequency reduction (see question 1) — options: `systemd-run --scope -p MemoryMax=…` is WRONG for a 20GB-peaking eval (it would kill it); real options are per-system check splitting or accepting the tail.
8. `deploy-when-quiescent.sh` + `vendor-freshness.sh`: land the pending §11 array adoption (pre-existing row) — now one member wider.
9. The 168 unharvested §f-bearing reports WARN (standing checker output tonight) — a docs-health HARVEST pass is overdue project-wide (not this session's scope).
10. Box memory posture tonight (110Gi used, 40Gi swap held) predates this session — stability-domain, unchanged here, flagged only because the first eval-relevant commit will add 20GB on top.
11. Parallel-session work in flight at close: papdashboard vendorHash re-stale fix (unstaged), TODO/stability/upstream rows, `flake/expected-locks.nix` staged — untouched, listed so the next session doesn't "discover" them.
12. `precommit-eval-cache.sh` formatter memo and the new eval-relevance skip now share a doctrine page but not a lib file — fine (different mechanisms), but a future hook-refactor session could unify the "when does this leg skip" logging format.
13. The hook's shellcheck leg shells out `nix shell nixpkgs#shellcheck` per commit (latency + store churn) — pre-existing; a devshell-provided binary or memo could speed it (same disease family as items 3/6).
14. My ticked rows ride `825b8a4aa` (parallel session's named commit) — if the Task-Queue footer protocol expected MY session's ID on those closes, a follow-up verify row exists in the queue-checker's terms (it passed rc=0 tonight; nothing owed).

## g) Questions I cannot answer myself

1. **Is the remaining OOM tail acceptable?** After this fix, the ~20GB walk fires only on eval-relevant commits — but the FIRST such commit on a box sitting at 110Gi used + 40Gi swap still risks the 2026-10-20 kill class. Do you want (a) accept (frequency now low, CI backstops), or (b) a further split (e.g., run the two cheap host toplevel evals at commit time and defer the full `--all-systems` enumeration to CI only — weaker local gate, near-zero OOM risk)?
2. **Who owns the buildflow pre-commit leg overrun** (4+min on a docs-only commit, past its own 150s budget)? It's buildflow-repo territory (budget/step-timeout semantics) but the symptom lives in this hook — diagnose there, gate harder here, or leave it?
3. **Push now or leave to you?** Master holds this fix + parallel sessions' work unpushed; CI has never seen `precommit-eval-skip-selftest`. Default per policy: no push without your word. Confirm leave-as-is?

---

**Deliberately not harvested** (recorded here instead of the queue, per the self-harvest rule): items 4–14 are either owner-gated (push), pre-existing rows already queued elsewhere (items 6, 8, 9), observations of parallel-session work (10, 11), or judgment notes not actionable without a ruling (7, 12–14). Items 1–3 landed in TODO_LIST.md + docs/todo/pipeline.md at authoring time.
