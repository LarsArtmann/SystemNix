# SELF-REVIEW + COMPREHENSIVE STATUS: Priority-4 Code-Quality Batch (dep-audit CI, nullglob sweep, negative-test harness)

**Date:** 2026-09-02 21:00 CEST · **Session:** ~16:30–19:20 work + this review · **Predecessor:** `2026-09-02_19-00_priority4-dep-audit-ci-nullglob-sweep-negative-harness.md`
**Mode:** self-review demanded post-completion. Based on THIS session's run only.

---

## a) FULLY DONE (with the evidence)

1. **`audit-go-deps.sh` wired into CI** — `.github/workflows/go-deps-audit.yml` (push paths flake.lock/flake.nix/script/workflow + nightly 04:30 UTC + `workflow_dispatch`; private-input auth block copied from nix-check.yml; `PROJECTS_DIR` pinned to an empty dir = deterministic clone-less mode).
   - Robustness fix 1: failed upstream lookups (network/private-repo-over-https) now record `remote-failed` and downgrade to WARN-UNKNOWN instead of false ERROR-MISSING.
   - Robustness fix 2 (my own bug, caught by my unit tests BEFORE wiring): `$(resolve_tag …)` subshells dropped the TAG_SRC bookkeeping — restructured to a global-out contract (`RESOLVE_TAG_COMMIT`/`RESOLVE_TAG_SRC`, no command substitution at the call site). 6/6 unit tests.
   - Full no-clones CI simulation on the real tree: **exit 0, 0 errors, 460 INFO-UNPINNED, 1750 WARN-UNKNOWN** — the hard class (ERROR-MISSING) is provably zero on a healthy lock, and the private-repo probe confirmed semantics (reachable repo + genuinely missing tag stays a REAL error).
2. **nullglob audit + persisted sweep** — all 22 `runCommand` occurrences across 9 files swept: ZERO command-position-var hits (classes A/B), one advisory (the now-guarded `for m in $metrics`), all glob loops guarded. `scripts/audit-shell-nullglob.sh` (FAIL on crisp classes A/B incl. `if/then/else/elif/do/eval` command positions and the `''${var}` nix-escaped form; WARN on judgment classes C/D) — **negative-tested against the exact historical incident line**, wired into `.githooks/pre-commit` + `nix-check.yml`. Hardening: signoz-query-lint fails LOUD on an empty dead-metrics blocklist.
3. **Negative-test harness persisted** — `scripts/negative-test-lints.sh`: git-tracked-set copy → git-less flake source (plain-dir = all files visible, no tracked-files filtering) → one incident-shaped mutation → `nix build --impure` the REAL check derivation → assert the lint's own FAIL marker (eval errors do NOT count as catches). **15/15 PASS, run twice** (pre- and post-format). **First run caught a REAL lint weakness:** module-shape-lint's `\b` accepted renamed wrappers (`flake.nixosModules.caddy-mutant =` satisfied `caddy\b`) — fixed with a `=`-anchored declaration grep, verified green-over-tree / red-over-mutant.
4. **Harvest** — TODO_LIST Priority-4 closed with a shipped-note, CHANGELOG (1 Added, 1 Fixed), AGENTS.md (Prevention Layers table rows + nullglob gotcha extension), the 19-00 report.
5. **Gates at session end:** `nix flake check --no-build` green ×2 (pre/post-format), `nix fmt --no-update-lock-file -- --ci` TRUE exit 0 (re-run with proper exit capture after the first run reformatted 4 files), shellcheck clean on all three scripts, pre-commit hook `bash -n` clean.

## b) PARTIALLY DONE (honest scope edges)

1. **CI wiring is code-complete but never executed ON CI** — the workflow's first real run is tonight's 04:30 schedule (or the next daemon commit touching flake.lock). Untested on a real runner: runtime (nix eval fetches ~30 input trees cold), disk headroom, and YAML validity beyond my manual reading. I even made (and caught) a checkout-SHA typo in it — the file was never machine-validated (no actionlint/yamllint run).
2. **Pre-commit hook live-fire untested** — `.githooks/pre-commit` edit is syntax-checked and the sweep runs standalone, but no commit passed through the hook in-session (the daemon commits bypass/do-not-bypass hooks — unverified which). The next human commit is the real test.
3. **Clone-mode full run post-refactor not executed** — only no-clones mode ran end-to-end. The clone paths are unit-tested (T5) but the 1569-OK local baseline from 05-30 was never re-confirmed against the refactored script.
4. **`.pre-commit-config.yaml` coexists with the active `core.hooksPath=.githooks`** — my hook went to the ACTIVE path, but the framework config file (gitleaks/deadnix/trailing-whitespace…) describes a PARALLEL hook set whose execution status is unverified. Potential split-brain config, not investigated this session.

## c) NOT STARTED (deliberate or missed)

1. `negative-test-lints.sh` as a CI job — deliberate (needs private-input keys, ~10 min runtime; local-first decision documented). Pending owner Q2 below.
2. Workflow linting (actionlint) — missed, not deliberate; cheap and should have been step 1 after writing the YAML.
3. A harness mutation case for the NEW empty-blocklist guard (`deadMetrics = []` must FAIL) — the guard I added has no negative test of its own.
4. Harness mutation for the binary-coverage python3 trap — covered by the in-tree selftest, so parity-only.

## d) TOTALLY FUCKED UP (all caught before or shortly after shipping — but they were mine)

1. **The "12 runCommand bodies" count was wrong and SHIPPED into three docs** (TODO_LIST, CHANGELOG, 19-00 report). True count: 22 occurrences across 9 files — I undercounted by excluding overlays/shared.nix and the selftest's inner fixtures, then never re-verified my own arithmetic. Caught only in THIS self-review. Exactly the class I was hired to prevent: an unverified number stated as fact in three places.
2. **Pipe-masked fmt exit** — my first formatter check read `$?` after `| tail` and printed "fmt-exit=0" while fmt had ACTUALLY FAILED with unexpected changes. This is the documented `| tail`-eats-the-exit-code anti-pattern from the 08-27 session (AGENTS.md). I caught it because the "4 changed files" line contradicted the 0 — but I nearly reported the tree formatter-clean on the strength of a tail exit code.
3. **Subshell bookkeeping bug in my own fix** — the remote-failed downgrade would have silently never fired (`$(resolve_tag …)` drops variable writes). Caught by unit tests because I wrote them BEFORE wiring; had I wired first, CI would carry an invisible no-op.
4. **First sweep draft missed `if $var`** — command-position prefixes were `^`/`;`/`&&`/`||`/`|`, but the historical incident line was `if $strip "$f" | …`. Caught only because I replayed the ORIGINAL incident text verbatim instead of a synthetic variant. A detector negative-tested against a lookalike, not the artifact, is half-tested.
5. **Harness iteration waste (2 rounds on gatus):** (i) appended garbage to gatus-config.nix broke EVAL — the file is an auto-discovered wrapper whose parse is forced during checks eval; (ii) the backslash-n mutation used the WRONG SHAPE (one file-backslash = the correct form; the trap is two). Both now encoded as harness comments.
6. **`$1: unbound variable`** — a `\\$1` inside a double-quoted bash call-site expanded `$1` at invocation (set -u killed it). Quoting layers in mutation fixtures are treacherous; the fix (single-quoted arg, no `$` in fixture) is trivial in hindsight.

## e) WHAT WE SHOULD IMPROVE

1. **Verify every number before it enters docs** — the 12-vs-22 count is the third instance this repo has of summary-vs-reality drift (the "3 copies" stale count in the 05-30 session, "port 0" claims). Rule: a count in a report is a CLAIM; recompute it with one command at write time.
2. **Machine-validate CI YAML the moment it's written** — actionlint (or at least yamllint) belongs in the workflow-authoring loop, not in NEXT.
3. **Line-number drift in `audit-shell-nullglob.sh`** — reported line numbers index the comment-stripped stream, not the real file; a human greps the reported number and lands somewhere else. Keep original numbering (grep the raw file, filter matches by line-type).
4. **An exemption mechanism for advisory WARNs** — the `$metrics` C-warn prints on every run forever; warn-noise trains blindness. Support a trailing `# nullglob-ok: <reason>` marker.
5. **Share the pristine copy across harness controls** — 4 identical rsync copies per run; one copy, four check builds.
6. **Resolve the pre-commit split-brain question** (`.pre-commit-config.yaml` vs `.githooks/`) — one of them is dead config pretending to be a safety layer.
7. **The pipe-exit discipline needs to be MY reflex, not a memory** — echo-through-pipe cost this repo real pain twice now; always `cmd > file; echo $?` or `set -o pipefail` in the READING shell.
8. **Clean scratch** — /tmp/audit-fns.sh, /tmp/nullglob-evil, /tmp/fakeclone2, /tmp/gcfg-test.nix, /tmp/gatus-drv.json, /tmp/trap-test.nix, /tmp/fmt-out.txt left behind.

## f) NEXT (ranked, session-derived)

1. actionlint both workflow files (new go-deps-audit.yml + the nix-check.yml edit) — 10 min, closes b.1's YAML risk.
2. Watch/trigger the first real `go-deps-audit.yml` run; record runtime, disk, verdict mix (baseline for the nightly).
3. Live-fire the pre-commit hook (next human commit) — confirm the nullglob sweep executes and passes.
4. Full `audit-go-deps.sh` run in LOCAL-CLONES mode post-refactor; re-confirm the 1569-OK-class baseline and that WARN-DIVERGED still ~46.
5. Add the empty-blocklist mutation case to the harness (`deadMetrics = []` → FAIL "blocklist is empty").
6. Investigate `.pre-commit-config.yaml`: dead config (delete) or active second system (reconcile) — decide and document.
7. Fix line-number reporting in `audit-shell-nullglob.sh` (real-file lines).
8. Add `# nullglob-ok` exemption support to the sweep; annotate the guarded `$metrics` line.
9. Harness: share one pristine copy across controls.
10. CI job for `negative-test-lints.sh` (pending Q2).
11. module-shape-lint: cover attrset-form wrappers (`flake.nixosModules = { x = …; }`) — currently invisible.
12. First-run observation of the daemon-commit→workflow-trigger path: does every daemon flake.lock bump spawn an audit run? If too noisy, narrow the paths filter.
13. Add actionlint to CI itself (workflow-lint step) so future YAML typos die at PR.
14. `deadMetrics = []` as a deliberate harness case ALSO proves the guard's marker text stays stable.
15. binary-coverage python3 trap harness case (parity with the in-tree selftest).
16. Document the two new scripts in docs/CONTRIBUTING.md's verification-commands section (if the pointer belongs there).
17. The 2 WARN-UNKNOWN clones-freshness items (buildflow `ac84f0fceddf`, `6966285d1255`) — pre-existing from 05-30, still unfetched.
18. Consider caching the audit's `nix eval` OUTPATHS locally (speed only).
19. Sweep the sweep: run `audit-shell-nullglob.sh` against ITS OWN class-D logic (it contains for-loops with globs — self-apply or document exemption).
20. Harness: distinguish eval-failure from lint-failure in the failure message even when the marker matches (belt for future marker drift).
21. Re-check cron interplay: flake-update Mon 06:00 UTC vs go-deps-audit daily 04:30 UTC — Monday double-run is fine, but confirm neither is rate-limited by GH.
22. The formatter churn on `sops.nix`/`flake.nix` (concurrent sessions' unformatted commits) — a pre-commit fmt hook for `.nix` would have caught it at THEIR commit time (does .githooks run alejandra? verify).
23. Add `KEEP=1` harness runs to a docs/services runbook page for the two audit scripts.
24. Consider `workflow_dispatch` input to run the dep audit against a specific PR ref for triage.
25. Track the nightly's WARN-UNKNOWN count over time (a rising count = inputs drifting from go.mod promises — the original drift signal, now CI-visible).

## g) QUESTIONS (cannot figure out myself)

1. **WARN-DIVERGED policy (the original 05-30 Q1, still open):** the 46 diverged requires keep compiling against rebased go-cqrs-lite trees. My default keeps them ADVISORY forever. Do you want a baseline file (allowed-divergences list) so NEW divergences fail CI, or is advisory permanent?
2. **May `negative-test-lints.sh` run in CI** (~10 min + private-input deploy keys per run, or e.g. weekly-only schedule), or does it stay a local/pre-push tool?
3. **The formatter reformatted concurrent-session files in my tree** (`sops.nix`, `flake.nix` churn — content-identical, CI-required). Ride along in the daemon's next batch commit, or do you want that attributed separately?

---

**WAITING for instructions.** No further work will be started until answers/direction arrive.
