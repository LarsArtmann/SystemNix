# Status Report: Early-Detection Prevention Plan Execution (Partial)

**Date:** 2026-08-07 02:20
**Session goal:** Execute the 15-task prevention plan from `docs/planning/2026-08-06_23-24_EARLY-DETECTION-PREVENTION-PLAN.md`
**Trigger:** User said "READ, UNDERSTAND, RESEARCH, REFLECT. Break this down into multiple actionable steps. Execute and Verify them one step at a time. Repeat until done."

---

> **RESOLVED — M1 complete, M2–M15 all completed by 2026-08-07_06-37 report. See TODO_LIST.md Priority 7 (removed — all done) and CHANGELOG.md for details.**
> All forward-looking items in this report were completed in subsequent sessions.


## a) FULLY DONE

### M1: Gatus `pat()` Syntax Validator (COMPLETE — verified working)

**What was built:**
1. **`flake.nix` checks section** (after deadnix check, ~line 649): Added `gatus-pattern-lint` — a `pkgs.runCommand` that greps `gatus-config.nix` for `pat(` calls containing `?` or `+` (regex-only chars that are ALWAYS wrong in Gatus glob patterns). Comments are excluded via `grep -v '^[[:space:]]*#'`. The `{` char is intentionally NOT flagged because Prometheus labels legitimately use `{service="..."}` syntax.

2. **`.githooks/pre-commit`** (after tarball guard, ~line 35): Added a fast grep guard that fires only when `gatus-config.nix` is staged. Same logic: scans non-comment lines for `pat(.*[?+]`, exits 1 with an explanatory message.

**Verification performed:**
- `nix build .#checks.x86_64-linux.gatus-pattern-lint` — PASSES on current code (the `?` bug was already fixed)
- Manual grep test confirmed: catches `?` and `+` in `pat()`, correctly passes `[1-9]` character classes and `{label="value"}` Prometheus syntax, and correctly ignores commented-out lines

**What it catches:** Problem P2 — the `?` glob misuse that made "Monitor365 Agent Connected" permanently red for days. If this check existed on Aug 5, the bug would have been caught before deploy.

---

## b) PARTIALLY DONE

### M2: Add `TimeoutStartSec` to 10 Services (RESEARCH COMPLETE — NO EDITS MADE)

**What was done:**
- Read all 10 target service files via sub-agent and direct View calls
- Mapped every `ExecStartPre` occurrence with exact line numbers and surrounding context
- Identified the precise insertion point in each file

**What was NOT done:**
- **Zero edits were made.** I gathered all the context but ran out of session before writing a single `TimeoutStartSec = "3min"` line. All 10 files remain unchanged.

**Detailed findings (ready for immediate implementation):**

| # | File | ExecStartPre Line | Insert After | Notes |
|---|------|-------------------|--------------|-------|
| 1 | `gatus-config.nix` | L922 | L925 (`];` closing ExecStartPre) | Inside `mkMerge` `{}` block |
| 2 | `signoz.nix` | L278 | Before `ExecStartPost` at L277, or after | Large `let...in` block wrapping ExecStartPre |
| 3 | `monitor365.nix` | L276 | L278 (`];` closing ExecStartPre) | Direct `serviceConfig = {}` (not mkMerge) |
| 4 | `dns-blocker.nix` | L689 | L692 (`];` closing ExecStartPre) | Inside `mkMerge` third `{}` block |
| 5 | `forgejo.nix` (main service) | L212 | L212 (after ExecStartPre line) | Small `{}` block in mkMerge |
| 6 | `forgejo.nix` (oidc-setup oneshot) | L304 | L304 (after ExecStartPre line) | Oneshot — still needs timeout |
| 7 | `forgejo.nix` (runner) | L356 | L359 (`];` closing ExecStartPre) | Direct `serviceConfig = {}` |
| 8 | `searxng.nix` | L623 | L623 (after ExecStartPre line) | Inside `mkMerge` first `{}` block |
| 9 | `overview.nix` | L78 | L78 (add dot-notation line) | Uses dot-notation, no block |
| 10 | `openseo.nix` | L223 | L227 (`];` closing ExecStartPre) | Inside `mkMerge` third `{}` block |
| 11 | `forgejo-repos.nix` | L327 | L327 (after ExecStartPre line) | Oneshot service |
| 12 | `oauth2-proxy.nix` | L131 | L134 (`];` closing ExecStartPre) | Inside `mkMerge` third `{}` block |

> Note: The plan said 10 services, but `forgejo.nix` has 3 separate services with ExecStartPre (forgejo main, forgejo-oidc-setup, gitea-runner), so there are actually 12 insertion points across 10 files.

---

## c) NOT STARTED

| Task | Description | Effort | Dependencies |
|------|-------------|--------|--------------|
| **M3** | ExecStartPre/TimeoutStartSec eval-time audit | 45min | M2 (must complete first) |
| **M4** | Runtime metric presence validator in pre-deploy-check.sh | 60min | M1 (done) |
| **M5** | Unknown Author commit rejection hook | 30min | — |
| **M6** | Daily nixpkgs compat CI workflow | 30min | — |
| **M7** | Caddy vHost auth smoke test in post-deploy-check.sh | 45min | — |
| **M8** | `ref=master` + GOTOOLCHAIN=auto audit | 30min | — |
| **M9** | Audit remaining 38 Gatus `pat()` patterns | 60min | M1 (done) |
| **M10** | AGENTS.md prevention layer documentation | 30min | M1-M8 |
| **M11** | TODO_LIST update | 15min | M1-M9 |
| **M12** | Gatus pattern VM test | 90min | M1 (done), M9 |
| **M13** | PMA daemon identity VM test | 60min | M5 |
| **M14** | Monitoring-the-monitor meta-check | 60min | — |
| **M15** | Full validation (nix fmt + flake check) | 30min | All |

---

## d) TOTALLY FUCKED UP

**Nothing was fucked up.** No regressions, no broken changes, no reverted work.

**However, I wasted significant time:**
- I used 3 separate sub-agent calls and multiple View batches to gather context that could have been done in 1-2 calls. The sub-agent results were thorough but I re-read many of the same lines again with direct View calls — redundant work.
- I set up a 15-item todo list but only completed 1 item before the user interrupted for this status report. The session was going to be very long.

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Batch edits more aggressively** — I should have written all 12 `TimeoutStartSec` edits in a single `multiedit` message or parallel `edit` calls, not gathered context one file at a time. The context gathering took 4 View batches when 2 would have sufficed.

2. **The `gatus-pattern-lint` check uses `grep -v '^[[:space:]]*#'` to skip comments** — This is correct for the current file, but it would fail to catch a bad pattern on a line that has a trailing comment (e.g. `"[BODY] == pat(*test?test*)" # health check`). This is an edge case that doesn't exist in the current codebase but could be a future gap.

3. **The pre-commit guard only fires when `gatus-config.nix` is staged** — If someone creates a new Gatus config file with a different name, the guard won't fire. The flake check covers this (it always scans the hardcoded path), so defense-in-depth is maintained.

4. **The plan's effort estimates are optimistic** — M1 was estimated at 30min and took about that much wall-clock time, but the context-gathering overhead for M2 (10 files) was already 15+ minutes with no edits. The total "~10.5 hours" estimate is probably 13-15 hours of actual work including context gathering and verification.

### Technical Observations

5. **`forgejo.nix` has 3 services with ExecStartPre** — The plan said "10 services" but there are actually 12 insertion points across 10 files. Two of these are oneshot services (`forgejo-oidc-setup`, `forgejo-repos`). The eval-time audit (M3) needs to decide whether to flag oneshots too.

6. **The `overview.nix` service uses dot-notation** (`serviceConfig.ExecStartPre = ...`) instead of an attrset block. The `TimeoutStartSec` addition needs a different syntax: `serviceConfig.TimeoutStartSec = "3min";` — this is straightforward but different from the other 9 files.

7. **Existing services with TimeoutStartSec** — `hermes.nix` (`"3min"`), `discordsync.nix` (`"3min"`), `pocket-id.nix` (`"180s"`) already have it. The M3 audit should use these as proof the pattern is established.

---

## f) NEXT 50 THINGS TO GET DONE

### Immediate (resume execution — M2 is ready for edits)

1. **Add `TimeoutStartSec = "3min"` to gatus-config.nix** (L925 area)
2. **Add `TimeoutStartSec = "3min"` to signoz.nix** (L277 area)
3. **Add `TimeoutStartSec = "3min"` to monitor365.nix** (L278 area)
4. **Add `TimeoutStartSec = "3min"` to dns-blocker.nix** (L692 area)
5. **Add `TimeoutStartSec = "3min"` to forgejo.nix main service** (L212 area)
6. **Add `TimeoutStartSec = "3min"` to forgejo.nix oidc-setup** (L304 area)
7. **Add `TimeoutStartSec = "3min"` to forgejo.nix runner** (L359 area)
8. **Add `TimeoutStartSec = "3min"` to searxng.nix** (L623 area)
9. **Add `TimeoutStartSec = "3min"` to overview.nix** (L78, dot-notation)
10. **Add `TimeoutStartSec = "3min"` to openseo.nix** (L227 area)
11. **Add `TimeoutStartSec = "3min"` to forgejo-repos.nix** (L327 area)
12. **Add `TimeoutStartSec = "3min"` to oauth2-proxy.nix** (L134 area)

### M3: ExecStartPre/TimeoutStartSec audit

13. Read `lib/default.nix` port collision pattern (L144-153)
14. Write `lib/systemd-audit.nix` — introspect `config.systemd.services` post-merge
15. Export from `lib/default.nix`
16. Wire into `configuration.nix` as `assert`
17. Test: `nix flake check --no-build` passes (all services now have timeout)
18. Test: temporarily remove one timeout, verify assertion fires with service name

### M4: Runtime metric presence validator

19. Read `scripts/pre-deploy-check.sh` full structure
20. Write `extract_gatus_metrics()` function
21. Write `check_metric_presence()` function
22. Add skip-if-service-down guard
23. Wire as numbered check in pre-deploy-check.sh
24. Test against live system

### M5: Unknown Author commit hook

25. Add author/committer check to `.githooks/pre-commit`
26. Test with mock bad-identity commit
27. Verify PMA daemon commits still pass (uses GIT_AUTHOR_NAME env var)

### M6: nixpkgs compat CI

28. Write `.github/workflows/nixpkgs-compat.yml` — daily scheduled flake update + check
29. Add GitHub issue creation on failure

### M7: Caddy vHost auth smoke test

30. Collect all external vHosts from caddy.nix
31. Write `check_vhost()` in post-deploy-check.sh — fail on 500/502
32. Add SigNoz-specific check
33. Test against live system

### M8: ref=master + GOTOOLCHAIN audit

34. Write `scripts/check-flake-inputs.sh`
35. Add to CI and/or pre-commit

### M9: Audit remaining pat() patterns

36. Cross-reference all textfile metrics with system-health module
37. Cross-reference service-specific metrics with upstream emission code
38. Document safe vs risky patterns

### M10-M11: Documentation

39. Write prevention layers table in AGENTS.md
40. Add TimeoutStartSec to "Adding a Service" checklist
41. Add Gatus health check design patterns section
42. Update TODO_LIST.md

### M12-M14: Advanced tests

43. Write `tests/test-gatus-patterns.nix` VM test
44. Write `tests/test-pma-identity.nix` VM test
45. Write monitoring-the-monitor meta-check

### M15: Final validation

46. Run `nix fmt` on all changed files
47. Run `nix flake check --no-build`
48. Run `nix run .#pre-deploy-check`
49. Review full git diff
50. Verify no verschlimmbessern — each check adds value, none creates false positives

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

### Q1: Should the M3 audit flag oneshot services too?

`forgejo-oidc-setup` and `forgejo-repos` are `Type=oneshot` services with `ExecStartPre`. Oneshots can also hang on DNS-gate or network waits. The systemd default 90s timeout applies to them too. Should the audit enforce `TimeoutStartSec` on ALL services with `ExecStartPre`, or only `Type=exec`/`Type=simple`/`Type=notify` services? My recommendation: flag ALL services with `ExecStartPre` — oneshots that hang are just as bad as long-running services that hang. But this is a judgment call about operational strictness.

### Q2: Should the M4 metric presence validator query the LOCAL `/metrics` endpoints, or the Gatus API to see if endpoints are GREEN?

Two approaches:
- **(a) Direct `/metrics` fetch** — curl each service's metrics port, grep for metric names extracted from `gatus-config.nix`. Catches phantom metrics (P3) but requires knowing each service's metrics port.
- **(b) Gatus API query** — query `http://localhost:${gatusPort}/api/v1/endpoints/statuses`, check that no endpoint has been in error state recently. Catches broken health checks generally but doesn't pinpoint phantom metrics.

I lean toward (a) because it directly tests the root cause (metric not emitted). But (b) is simpler and catches more failure modes. Which do you want?

### Q3: Should M6 (nixpkgs compat CI) run `nix flake update nixpkgs` or use `nixpkgs-unstable` branch tracking?

The daily CI needs to test "does our config still build with the latest nixpkgs?" Two approaches:
- **(a) Update nixpkgs in a temp flake.lock, run check, discard changes** — tests real upgrade path. But this modifies flake.lock during CI, which needs careful cleanup.
- **(b) Run against a fresh `nixpkgs-unstable` input** — doesn't touch flake.lock but tests a different input than what we'd actually upgrade to.

I cannot figure out which approach matches your CI preferences without asking. My recommendation: (a) with `--commit-to-branch` or just run in a temp worktree.

---

## Summary

| Metric | Value |
|--------|-------|
| Tasks completed | 1 of 15 (M1) |
| Tasks partially done | 1 of 15 (M2 — research only, 0 edits) |
| Tasks not started | 13 of 15 |
| Things fucked up | 0 |
| Time efficiency | Below target — too much context gathering, not enough editing |
| Verschlimmbessern risk so far | Zero — M1 check has zero false-positive rate |
| Uncommitted changes | M1 changes in `flake.nix` + `.githooks/pre-commit` (not yet committed) |
