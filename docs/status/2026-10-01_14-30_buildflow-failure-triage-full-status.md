# Status Report — BuildFlow Failure Triage Session (2026-10-01 14:30 CEST)

**Session scope:** one `buildflow --fix --build-mode=full --budget 5m` run on SystemNix master (`6d05b91e`) failed with 3 exit-gating steps (`lychee`, `nix-build`, `ruff-check-fix`); this session triaged and fixed them. Scope deliberately limited to the run's findings — no other systems researched.

**Tree state at close:** clean working tree; 2 unpushed commits (`52567448` = my 5 fix files, daemon heuristic commit containing ONLY my files; `0a12995b` = another session's docs commit, left untouched). evo-x2 toplevel evals green post-fix.

---

## a) FULLY DONE

1. **`ruff-check-fix` step green** — all 20 ruff findings resolved:
   - Real code fixes: `scripts/ucr-mirror-encode.py` — UP022 `stdout/stderr=PIPE` → `capture_output=True` (line 42); F841 unused `epoch_ms` assignment removed (line 86). `scripts/ucr-rag.py` — E741 ambiguous `l` renamed to `line` (lines 123-127).
   - E501 long-lines in `scripts/pixel6-contacts.py` (5) and `scripts/ucr-web-archive.py` (15) are embedded single-line HTML/CSS/JS templates inside Python strings — fixed via scoped `[lint.per-file-ignores]` E501 entries in `ruff.toml` (targeted per-file, NOT a global line-length relaxation).
   - Verified: `buildflow -s ruff-check-fix` ✔ 1/1 (4.5s); direct `ruff check scripts/` — "All checks passed".
2. **`shellcheck` warning-level findings fixed** — SC2148 (added `# shellcheck shell=bash` directive to `scripts/lib/precommit-eval-cache.sh`); SC2155 (split declare-and-assign of `MIGRATE_ROOT_UID` in `scripts/test-migrate-hot-db.sh`). Verified: `buildflow -s shellcheck` ✔ 1/1 (13.8s); `scripts/test-migrate-hot-db.sh` selftest re-run — all 22 PASS assertions green (important since the SC2155 fix touched a live test script).
3. **`deadnix` finding closed** — unused lambda arg in `platforms/nixos/system/journal-hot.nix` was auto-fixed during the buildflow run itself; re-verified clean + evo-x2 toplevel eval OK.
4. **`nix-checker` 107-findings backlog triaged and classified** (full breakdown in §e): 47 `hardcoded-hash` (info — the tool's own finding text says "expected for fetchurl/fetchgit; update intentionally"), 48 `inline-hash-suggestion` (style), 1 `fake-hash` (the intentional `sha256-AAAA…` placeholder at `templates/go-flake-parts/flake.nix:80`, part of the template's REPLACE_ME pattern), 11 `port-collision` (test fixtures `tests/test-*.nix` + `rpi3`/`dns-blocker-config` — real ports already eval-gated by `port-registry-audit.nix`). None are exit-gating; none were churned.
5. **Daemon-race discipline held** — content-pinned before writing; verified the daemon commit `52567448` staged exactly my 5 files and nothing from parallel sessions.

## b) PARTIALLY DONE

1. **`lychee` step** — NOT a code fix; it was killed at 4m29s scanning 2227 files with zero output (spawn/hang timeout). The failure class is infrastructure/budget, but I did not rerun it with a larger `--max-time` to confirm it passes — the pass-state is UNVERIFIED.
2. **`nix-build` step** — killed at 5m budget (OOM or timeout). I verified the cheaper surrogate (`nix eval` of the evo-x2 toplevel drv + `nix flake check` passed inside the same buildflow run) but did NOT run a full toplevel BUILD to prove the FOD/vendorHash surface is healthy. The original run's `nix-hash-fix` legs all reported ✔ before the kill, which is encouraging but not a build.
3. **gomod-freshness WARN** (`signal: killed` during per-module scan) — same 5-minute-budget kill class; not investigated beyond classification.
4. **Shellcheck info-level residue** — my stricter local `nix shell nixpkgs#shellcheck` run surfaced ~30 info findings (SC2015 `&& ||` chains in `test-migrate-hot-db.sh`, SC2012, SC2329) that BuildFlow's shellcheck leg does not gate. Left alone deliberately (test-idiom `ok`/`fail` chains), but they are unaddressed findings, not clean.

## c) NOT STARTED

1. **9 unavailable tools** — BuildFlow health check warned `prettier`, `ruff`, `dprint`, `lychee`, `vulnix`, `interrogate` (+3 more) are not in the project devShell and run via `nix run nixpkgs#<tool>` WITHOUT project deps. Each run emits a WARN "add X to devShells.default". Zero of these devShell additions were made.
2. **`nix-checker` fake-hash template FP** — no suppression/exclusion mechanism was added for `templates/go-flake-parts/flake.nix:80`; it will re-fire every run.
3. **`nix-checker` port-collision FPs on test fixtures** — same: no per-path exclusion for `tests/test-*.nix` fixtures was configured.
4. **Budget reconfiguration** — nothing was done about the root cause of the `nix-build`/`lychee`/gomod-freshness kills: a 5-minute `--budget/--max-time` on a tree where flake-check alone takes ~143s and nix-build ~103s BEFORE the FOD builds start.
5. **Self-harvest of this report's §f** — see the addendum below (per AGENTS self-harvest rule, the direct follow-ups were queued at authoring time).

## d) TOTALLY FUCKED UP

Nothing in this session is "fucked up" — no data loss, no broken surfaces, no misattributed commits. Two honest misses though:

1. **First-pass edit failures wasted 3 tool calls** — I ran `edit` calls after reading the files only via `sed` in a bash pipe; the harness correctly refused ("you must read the file first"). Should have used `view` up front. Process friction, zero damage.
2. **Verification asymmetry** — the two cheapest-to-verify residuals (a longer-budget lychee rerun, a backgrounded toplevel build) were left unverified while I classified instead. The close-out therefore answers "are the lint findings fixed?" (fully) but only "are the timeout steps healthy?" (partially, by proxy evidence).

## e) WHAT WE SHOULD IMPROVE

1. **BuildFlow budget is structurally too small for this repo** — nix-flake-check alone ~143s + nix-build ~103s within a 5m budget guarantees the FOD builds and lychee never get a fair shot. Either raise the default for this repo (`.buildflow.yml`) or run heavy steps with per-step timeouts.
2. **`nix-checker` needs an ignore/exclude surface** — 100+ of 107 findings are self-declared "expected" (pinned hashes) or intentional (template placeholder, test-fixture ports). Without an allowlist (like `port-registry-audit.allowPorts`), every run reports a scary permanent backlog that trains everyone to ignore the tool.
3. **devShell completeness** — 9 tools falling back to dep-less `nix run nixpkgs#<tool>` is both noisy and subtly wrong (formatter runs without project config deps). One `devShells.default` edit kills 9 WARNs.
4. **E501-vs-embedded-HTML tension is now policy, not accident** — the per-file-ignores in `ruff.toml` should be documented in the two scripts' headers so the next author doesn't "fix" the ignores back.
5. **My edit-tool discipline** — read via `view` before editing, always; `sed`-through-bash doesn't count.

## f) NEXT — 50 things to get done (brainstorm; §f.1-6 are this report's own follow-ups, harvested at authoring)

**This session's direct follow-ups (harvested → `docs/todo/pipeline.md` + `TODO_LIST.md`):**

1. Rerun lychee with a ≥15m budget to get a real pass/fail (2227 files; current 4.5m kill proves nothing).
2. Run a full toplevel `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` (heavy-job wrapped / quiet-IO window) to clear the nix-build kill verdict.
3. Add `prettier`, `ruff`, `dprint`, `lychee`, `vulnix`, `interrogate` (+ the other 3 from `buildflow doctor`) to `devShells.default` — kills 9 WARNs and the dep-less fallback class.
4. Give `nix-checker` an ignore/exclude config (fake-hash template exemption; test-fixture port exemption; "expected pinned hash" downgrade) — model on `port-registry-audit.allowPorts`.
5. Raise/segment the BuildFlow budget for SystemNix (flake-check 143s + build 103s baseline makes `--budget 5m` structurally unfair).
6. Investigate the gomod-freshness `signal: killed` (same budget class, but confirm it's not an env problem: the error text says "environment broken").

**Pipeline/CI (most are BuildFlow-upstream candidates):**
7. Fix the false-positive `nix-checker` port-collision rows for `rpi3/default.nix:91-92` + `dns-blocker-config.nix:39-40` (verify they ARE false positives before suppressing — I classified from file paths, not content).
8. BuildFlow: shellcheck step should ignore its own runtime nix "Using saved setting" stderr lines (they appear as findings in the report).
9. BuildFlow: vulnix reports 66 findings incl. CVE-2021-28794 on ShellCheck 0.11.0 (9.8 critical) — almost certainly a wrong-CVE mapping; verify and report upstream.
10. BuildFlow: eval-cache SQLite "is busy" errors on parallel `nix run` steps — serialize or lock.
11. BuildFlow: nix-build OOM kill should be distinguished from timeout in the failure message (it currently guesses).
12. Cache hit rate 0% (0 hits / 18 misses) — investigate why BuildFlow's cache never hits on this repo.
13. "DISCOVERY DEGRADED: only packages.default was built" — wire the nix targets discovery so checks get built.
14. Fix the gomod-freshness doctor step (`infrastructure:doctor.gomod_tidy` killed) or exclude it until the budget is fixed.
15. `tool interrogate is not installed` — install it or exclude the step permanently.
16. Dead `--exclude` guidance: if nix-hash-fix keeps failing after the budget fix, wire `skip_steps` in `.buildflow.yml` instead of warnings.
17. Consider splitting the buildflow full run into a fast lane (lint/fmt, <5m) and a slow lane (builds, unbounded) so one run never mixes both.

**Repo hygiene noticed in passing (unverified beyond observation):**
18. `scripts/ucr-mirror-encode.py` `run()` still swallows stderr on success paths — consider logging when returncode != 0 without `log_err`.
19. `scripts/test-migrate-hot-db.sh` SC2329 `assert_contains` is defined but never invoked — delete or use it.
20. `scripts/lib/precommit-eval-cache.sh` SC2012 (`ls`-parsing in the retention loop) — switch to `find -printf` for robustness.
21. The ~30 SC2015 info findings in `test-migrate-hot-db.sh` — either a `# shellcheck disable=SC2015` block with justification or refactor the `ok`/`fail` idiom.
22. Document the new `ruff.toml` per-file-ignores rationale in headers of the two HTML-embedding scripts.
23. Evict or finish `docs/planning/2026-09-30_09-30_two-day-todo-master-plan.html` churn (it was mid-edit by a sibling session at 12:27 — concurrency noise source).
24. BuildFlow 9-tool WARN text says "add to devShells.default" — verify AFTER item 3 that the WARNs disappear (don't trust the fix, probe it).
25. Run `buildflow doctor` and resolve whatever the remaining health-check failures are beyond the 9 missing binaries.

**Skipped-by-config tools worth a lane (gitleaks, codespell, markdown-lint skipped in `full` mode):**
26. Schedule the 3 skipped tools as a periodic (daily/weekly) lane so they aren't silently never-run.
27. vulnix 66 findings: triage into real-action vs nixpkgs-wait; a `.buildflow.yml` warnings_budget entry exists for markdown-lint/bandit but not vulnix.

**Report-process items (meta):**
28. This report's §f must be harvested (done for 1-6; items 7-27 are candidates for routing review — most are pipeline-domain `[ready]` or upstream `[blocked:push]`).
29. Past reports (2026-10-01_13-41, _13-42, _13-43) are same-day and unannotated — cheap ANNOTATE pass if their follow-ups were closed elsewhere.
30. The 2026-09-23 binary-shadow report's golines residual is deploy-gated — collapses when the next deploy lands (tracked in pipeline.md:148 already).

**Longer-term (ROADMAP fuel):**
31. Nix eval-cache contention solution (shared SQLite lock or per-step cache keys).
32. A pre-deploy buildflow lane wired into `scripts/pre-deploy-check.sh`.
33. BuildFlow HTML summary dashboard (it has the finding JSON already).
34. Trend tracking: 0%-cache-hit-rate and finding-count history per run.
35. Upstream the `capture_output`/E741-class fixes are trivial — but check whether BuildFlow's `ruff-check-fix` repair could auto-fix UP022 (it's fix-gated behind `--unsafe-fixes` today).
36. Set `line-length` per-language in ruff for embedded-HTML files instead of per-file ignores (ruff supports it? verify — if not, upstream request).
37. Pin the `nix run nixpkgs#ruff` version used by BuildFlow so findings don't drift with nixpkgs bumps.
38. Add a BuildFlow step that verifies the devShell actually contains every tool the config references (fail the config drift, not warn).
39. Document in AGENTS.md → Build & Deploy: the 5m-budget trap and the correct invocation for full runs.
40. Add `templates/go-flake-parts/flake.nix` to a buildflow exclude list AND a test that the template still evals (placeholder hashes fail eval-at-build, by design, but a `nix flake check` on the template dir would catch template rot).
41. Shellcheck: add `scripts/lib/*.sh` shell directive check to the pre-commit lint (SC2148-class slipped in because the file is sourced, not executed).
42. Verify the `nix-checker` "hardcoded hash" findings in `platforms/common/dns-blocklists.nix` (46 rows, the biggest single-file cluster) are actually fetch hashes and not something weirder — one file, one look.
43. Quickshell hash rows (2) — same one-look verification.
44. BuildFlow: after my fixes, confirm the auto-fix summary counts shrink (ruff should go 1-fixed→0, shfmt 12→stable).
45. shfmt reformatted `das-link-recovery-check.sh` (12 fixes) — spot-check the diff wasn't a semantic change (the `case` re-indent looked cosmetic but verify).
46. Re-run the FULL buildflow once after items 1-6 land and record the before/after table.
47. Consider `--format finding --output` archiving per run for the audit trail (reports currently live only in terminal scrollback).
48. Check whether the flake-update step (276s!) can skip inputs that didn't move (biggest single step in the run).
49. `discordsync/cqrs-htmx` was ADDED and `buildflow/systems` REMOVED by the auto flake-update — sanity-review that lock diff for surprises beyond the routine bumps.
50. Ask BuildFlow upstream for a `--dry-run` plan mode (show what would run/skip before spending 5 minutes).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Budget intent:** Is the 5-minute `--budget/--max-time` on the full buildflow run your deliberate fast-feedback choice (in which case the fix is a separate slow lane), or legacy default that I should raise in `.buildflow.yml` for this repo?
2. **lychee scope:** Should lychee scan all 2227 files every run, or should it be scoped to `docs/` + README (fast, meaningful) with a weekly full sweep — i.e., is full-tree link checking even wanted per-run?
3. **Template placeholder:** Is the `sha256-AAAA…` vendorHash placeholder in `templates/go-flake-parts/flake.nix` consumed/copied by agents (meaning it must stay literal), or can I switch it to a form nix-checker won't flag (e.g. `lib.fakeSha256`)?

---

_Point-in-time snapshot. §f.1-6 harvested into `TODO_LIST.md` + `docs/todo/pipeline.md` at authoring time (2026-10-01)._
