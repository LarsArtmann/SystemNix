# Session Status: Priority-4 Code-Quality Batch — dep-audit CI wiring + nullglob sweep + negative-test harness

**Date:** 2026-09-02 ~19:00 · **Scope:** the three remaining "Priority 4: Code Quality" TODO_LIST items. Point-in-time snapshot.

**TL;DR:** 3/3 items done and verified. The negative-test harness's FIRST full run caught a REAL weakness in `module-shape-lint` (renamed wrappers passed the `\b` grep) — fixed same session. The dep-audit CI wiring exposed and fixed a false-red class (failed upstream lookups masquerading as ERROR-MISSING) plus a subshell bookkeeping bug my own unit tests caught before it shipped.

---

## a) FULLY DONE

### 1. `audit-go-deps.sh` wired into CI — `.github/workflows/go-deps-audit.yml`

- **Triggers:** push (paths: `flake.lock`, `flake.nix`, the script, the workflow), nightly schedule (04:30, offset from the Monday flake-update job), `workflow_dispatch`. Same private-input auth block as `nix-check.yml` (the audit's `nix eval` of input outPaths forces every private tree).
- **CI shape:** `PROJECTS_DIR` points at an empty dir — no local clones, tag resolution rides anonymous `git ls-remote` (deliberate, deterministic).
- **Owner Q1-Q3 (2026-08-22 05-30 report, never answered) resolved by documented safe defaults** in the workflow header: Q1 WARN-DIVERGED stays ADVISORY (exit 0) — nothing blocks without an owner decision; Q2 CI not pre-deploy (minutes per run; deploys must not pay what CI covers nightly + on every lock push); Q3 fetch-free (WARN-UNKNOWN stays; on CI there are no clones to be stale).
- **Two robustness fixes the wiring forced** (both verified):
  1. **Failed lookup ≠ missing tag.** On clone-less CI every tag resolution goes through anonymous ls-remote; a network blip or a PRIVATE repo (404 by design over https) previously reported `ERROR-MISSING` → exit 1 → false red. `resolve_tag` now records the lookup source (`clone` / `remote` / `remote-failed`); `remote-failed` downgrades to `WARN-UNKNOWN (network/private repo over https)`. A genuine tag-not-found on a REACHABLE repo still ERROR-MISSINGs.
  2. **Subshell bookkeeping bug in fix 1** — caught by unit tests BEFORE it shipped: `reqcommit=$(resolve_tag …)` runs the function in a subshell, so its `TAG_SRC` writes never reached the main shell — the downgrade would have NEVER fired (invisible for exactly the private-repo case it was built for). Restructured to a global-out contract (`RESOLVE_TAG_COMMIT`/`RESOLVE_TAG_SRC`, called WITHOUT command substitution), with a comment documenting the trap. 6 unit tests pass: peel preference, public ls-remote, remote-failed downgrade, cache-keeps-src, true-missing-tag stays "remote", clone path.

### 2. nullglob audit of ALL runCommand checks — CLEAN + persisted sweep + one hardening

- **Inventory:** 22 `runCommand` occurrences across 9 files (flake.nix 11 — 8 checks + the selftest's inner evil/good-tree fixtures; dns-blocker ×2; overlays/shared ×2; systemd-graph; test-attic; test-oauth2-proxy ×2; test-niri-session-config, test-session-boot-audit, test-tmp-cleaner-audit — the latter three trivial `touch $out` stubs). Count corrected in the 21-00 self-review (originally miscounted as 12).
- **Sweep classes:** (A) unquoted command-position shell var — **ZERO hits** (the tree is clean; the v1 fix's `stream()` function indirection holds everywhere); (B) `$( $var` indirection — zero; (C) unquoted for-in list — ONE: signoz-query-lint's `for m in $metrics` (empty-var silent-skip vector — hardened); (D) glob for-loops — all guarded (`[ -e ]`/`|| continue`) or fixture data.
- **Hardening:** signoz-query-lint now FAILS LOUD on an empty dead-metrics blocklist (an emptied `deadMetrics` would previously disable trap 4 silently).
- **Persisted:** `scripts/audit-shell-nullglob.sh` — FAIL (exit 1) on crisp classes A/B (incl. `if $var …`, `then $var …`, `eval $var`, `''${var}` nix-escaped form), WARN on judgment classes C/D (comment-stripped, 3-line guard look-ahead, `bash -c` fixture + `$(find …)` exemptions). **Negative-tested against the exact incident shape** (`if $strip "$f" | grep …` — the FIRST sweep draft missed it because the var followed `if`, not `^`/`;`; caught by re-testing the historical bug, which is the whole point). Wired into `.githooks/pre-commit` + `nix-check.yml`.

### 3. Negative-test harness persisted — `scripts/negative-test-lints.sh` — 15/15 PASS, caught a real lint bug

- **Method:** copy the git-tracked set (working-tree contents) to a temp dir WITHOUT `.git` — a plain-directory flake sees ALL files (no tracked-files filtering, mutations always take effect); apply ONE incident-shaped mutation; `nix build --impure` the REAL check derivation from the copy; assert the lint's own FAIL marker appears (an eval error does NOT count — that's the mutation caught by accident, not by the lint). Green controls build all 4 checks on the pristine copy first.
- **15 cases:** 4 green controls + signoz ×5 (job= matcher, `metric_sum`, bare `up{service_name=}`, dead metric, comment-immunity PASS control) + gatus ×4 (`pat(?`, bare `pat(*m 1*)`, literal `\\n`, lowercase method) + module-shape ×1 + binary-coverage ×1. **ALL PASS.**
- **REAL BUG CAUGHT (the harness's first full run):** `module-shape-lint`'s wrapper grep `flake\.nixosModules\.${name}\b` accepts RENAMED wrappers — `flake.nixosModules.caddy-mutant =` satisfies the `caddy\b` grep because `-` is a word boundary; a module renamed away from its filename (breaking auto-discovery of the real name) passed the lint. Fixed: anchored on the declaration (`flake\.nixosModules\.${name}[[:space:]]*=`), green over the real tree, red over the mutant.
- **Two harness lessons encoded as comments:** (1) gatus-config.nix is an auto-discovered wrapper — its PARSE is forced during checks eval (VM-test module merging), so appended garbage broke eval instead of tripping the lint; mutations must stay valid nix (sed-replace a `let`-body comment with a binding). (2) The literal-backslash-n trap shape is TWO file backslashes (`\\n` in a double-quoted nix string evals to one literal `\` + n); a single file `\n` is the CORRECT form — the first mutation used the wrong shape and correctly stayed unflagged.

## b) Docs harvested

TODO_LIST Priority-4 → shipped-note summary line. CHANGELOG: 1 Added (batch), 1 Fixed (module-shape anchor). AGENTS.md: Prevention Layers table (pre-commit + CI rows), nullglob gotcha extended with the harness + sweep pointers.

## c) Verification ledger

- `audit-go-deps.sh`: shellcheck clean, bash -n clean, 6/6 unit tests (isolated function extraction), full no-clones CI-simulation run — see run transcript (WARN-UNKNOWN downgrades visible for private repos, exit 0).
- `audit-shell-nullglob.sh`: shellcheck clean; repo run = 1 known advisory; evil-tree run FAILs exit 1 with class A+B hits.
- `negative-test-lints.sh`: shellcheck clean; 15/15 (controls green, 10 mutations caught with markers, 1 comment-control correctly green).
- `nix flake check --no-build`: green over the flake.nix edits (empty-blocklist guard + module-shape anchor).
- `module-shape-lint` built green on the real tree BEFORE and AFTER the anchor tightening.

## d) What I would do differently

- The first nullglob sweep missed `if $var` because I anchored on the wrong command-position prefixes — re-testing against the HISTORICAL incident text (not a synthetic variant) is what exposed it. Rule: a detector's negative test should replay the original bug verbatim.
- `resolve_tag`'s subshell bug was introduced by MY fix and caught by MY unit tests — the unit-test-before-wiring step earned its keep; wiring first would have shipped an invisible no-op downgrade.
- The gatus mutations cost two iterations (eval-parse, then backslash shape). Both failure modes are now encoded in harness comments so the next maintainer doesn't re-derive them.

## e) NEXT

1. Watch the first scheduled `go-deps-audit.yml` run (tonight 04:30 UTC) — the full no-clones CI-simulation run on this tree: **exit 0, 0 errors, 460 unpinned, 1750 WARN-UNKNOWN** (every ancestry check degrades without clones — the CI-mode signal is the ERROR-MISSING count plus the verdict mix in the log; OK verdicts are ~0 because master-rev pins rarely equal tag commits). A private-repo probe confirmed https ls-remote to go-cqrs-lite itself succeeds (repo readable) — `remote-failed` only fires on actual lookup failure (verified with a nonexistent repo).
2. Consider `negative-test-lints.sh` as a CI job (needs the private-input auth block; runtime ~10 min) — deliberately NOT wired now (local + pre-commit-adjacent use first).
3. module-shape-lint: the `=`-anchor assumes dotted-form declarations; an attrset-form wrapper (`flake.nixosModules = { x = …; }`) is invisible to it (pre-existing, all modules use dotted form).
4. The 2 WARN-UNKNOWN clones-freshness items (buildflow `ac84f0fceddf`, `6966285d1255`, from the 05-30 report) remain — unchanged by this session.
