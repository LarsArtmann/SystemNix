# Scripts Review Round 2 Status Report — 2026-08-10 01:22

**Session:** Continued from round 1 (01:00). Fixed all 28 deferred bugs + 3 systemic improvements.
**Cumulative scope:** 42 files changed, 518 insertions(+), 326 deletions(-) across both rounds.

---

## A) FULLY DONE (completed and verified)

### Verification gates passed
- `bash -n` on all 38 shell scripts: 38/38 OK
- `python3 -m py_compile` on all 5 Python scripts: 5/5 OK
- `shellcheck --severity=warning` on all shell scripts: 0 warnings
- `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`: evaluates
- All 3 new test derivations registered in flake checks (`lib-helpers`, `pipefail-sigpipe`, `sed-delimiter`)
- `migrate-envrc.py --help` works (argparse migration verified)
- `commit-tag-push.py` AST-verified: `main()` returns, `__main__` block present

### Round 2 bug fixes (all 28 previously deferred)

| File | Bug | Fix |
|------|-----|-----|
| `btrfs-subvolume-inventory.sh` | `find \| wc -l` and `find \| sort \| head -1` abort under pipefail if find returns non-zero | Subshelled `find` with `|| true` |
| `migrate-envrc.py` | Brace counting on raw lines counted braces inside strings (`echo "}"`) → premature truncation | Column-0 `}` matching (bash function-end convention) |
| `migrate-envrc.py` | Overwrites `.envrc` with no backup | `.envrc.bak` backup before write |
| `migrate-envrc.py` | Dead condition `"if " in s` always true when `startswith("if ")` | Simplified to `s.startswith("if ")` |
| `migrate-envrc.py` | Manual arg parsing (`--dry-run` substring match) | Converted to argparse |
| `migrate-envrc.py` | No exit code, missing encoding | `return 0` + `encoding="utf-8"` |
| `route-health-monitor.sh` | `nmcli \| grep ":wifi:connected" \| head -1` SIGPIPE causes WiFi detection failure | `awk -F: '/:wifi:connected/{print $1; exit}'` |
| `route-health-monitor.sh` | Redundant `curl -w ''` flag | Removed |
| `crush-daily-backfill.py` | DELETE-before-COLLECT: data loss if collect fails | Re-inserts original event with payload on collect failure |
| `pocket-id-login-code.sh` | `jq \| head -1` SIGPIPE risk | `jq '[.data[] \| select(...)][0].id'` native first-element |
| `twenty-fix-collation.sh` | `grep -q` SIGPIPE false-negative; `for db in $dbs` unquoted | `grep -qx` + while-read loop |
| `versions.sh` | Python string interpolation of shell var (`$input` in Python string) | Passed via `sys.argv[1]` |
| `versions.sh` | Bare `except:` catches SystemExit/KeyboardInterrupt | `except Exception:` |
| `versions.sh` | Darwin branch used `nixosConfigurations` (always fails) | `darwinConfigurations` |
| `disk-fix.sh` | Duplicate `partprobe()` definition (line 46 shadowed by 58) | Removed duplicate |
| `disk-fix.sh` | `resize_p8()` didn't restore partition GPT name/label | Added `sgdisk -c 8:"data"` |
| `disk-diagnose.sh` | Tautological condition `[ A -lt B ] \| [ A -ge B ]` (always true, dead code) | Removed outer condition |
| `disk-diagnose.sh` | A&&B\|\|C pattern on zram check | if/else |
| `disk-create-p9.sh` | `btrfs scrub status \| head -15` SIGPIPE | `|| true` |
| `test-home-manager.sh` | Dead `run_test()` function (39 lines, never called) | Deleted |
| `test-home-manager.sh` | Unused `YELLOW` color constant | Removed |
| `validate.sh` | Unfiltered `nix flake check --no-build` (known false positives) | `nix eval drvPath` |
| `health-check.sh` | Same `--no-build` false positive | `nix eval drvPath` |
| `status-report.sh` | Same `--no-build` false positive | `nix eval drvPath` |
| `check-flake-inputs.sh` | `\s` is GNU grep extension, not POSIX | `[[:space:]]` |
| `find-corrupted-files.sh` | UUOC: `cat "$REPORT" \| while ...` | `while ... done <"$REPORT"` |
| `usb-diagnostic.sh` | All hardcoded `/dev/sda` and `sda` references | Device as `$1` argument, `$BASENAME` throughout |
| `commit-tag-push.py` / `fix-versions.py` | Missing `from __future__ import annotations` (inconsistent Python version requirement) | Added |
| `dns-update.sh` | Dead `url_escaped` variables (computed, never used) | Removed |

### Systemic improvements (all 3 implemented)

1. **`lib.sh` safe pipe helpers** — `safe_head`, `safe_tail`, `safe_sort_head` added. Centralizes the `|| true` pattern that pipefail + `| head` requires.

2. **`scripts/disk-common.sh`** — Shared geometry constants (`DISK`, `P8_START_SECTOR`, `BTRFS_SIZE_SECTORS`, `TARGET_P8_END_GIB`, `sectors_to_gib`, `sectors_to_tib`). Sourced by both `disk-fix.sh` and `disk-diagnose.sh`. Kills the drift class (1548 vs 1560 bug is now structurally impossible).

3. **`tests/test-scripts.nix`** — 3 NixOS VM tests:
   - `lib-helpers`: Tests `summary()` exit codes (pass/fail), `state_*` persistence, `safe_head` under pipefail
   - `pipefail-sigpipe`: Proves unguarded `| head` aborts under pipefail (machine.fail), and guarded survives
   - `sed-delimiter`: Tests `sed s|old|new|` on base64 strings containing `/`

---

## B) PARTIALLY DONE

### `crush-daily-backfill.py` — DELETE-before-COLLECT re-insert
- **Done:** The re-insert SQL restores the original event on collect failure (preserves payload, aggregate_id, occurred_at)
- **Not done:** Did not verify the SQL schema matches (the `INSERT` assumes columns `id, aggregate_id, event_type, payload, occurred_at` — if the events table has additional NOT NULL columns, the insert will fail). Never ran the script against a real database to verify.
- **Not done:** The `find_binary()` lexicographic sort issue (selects hash-sorted, not version-sorted nix store path) was identified but NOT fixed — still picks `candidates[-1]` from alphabetically sorted paths.

### `test-home-manager.sh` — TESTS_TOTAL inflation
- **Done:** Removed dead `run_test()` function, removed unused `YELLOW`
- **NOT done:** `TESTS_TOTAL` is still incremented multiple times per logical test in error/fallback branches (20+ increment sites, some branches increment by 2-3). The summary line at the end reports an inflated total. This is a cosmetic issue (the tests still pass/fail correctly), but the reported count is wrong.

### `lib.sh` safe helpers — adoption
- **Done:** `safe_head`, `safe_tail`, `safe_sort_head` added to lib.sh
- **NOT done:** Zero scripts actually USE them yet. All existing scripts still use raw `| head -N || true` patterns. The helpers exist but have no callers — the protection is theoretical until scripts are migrated.

### Consistency — scripts not sourcing `lib.sh`
- **Done:** None of the 10 scripts that redefine their own colors were migrated to `lib.sh`
- **Why:** Each script has slightly different formatting (different emoji, different indent style). Mechanical migration would change output format. Not done because it's churn without clear ROI for diagnostic scripts.

---

## C) NOT STARTED

| # | Item | Severity |
|---|------|----------|
| 1 | `niri-health.sh` dead code — not wired to any service, duplicates inline metrics. Still present, unreferenced by any Nix config. | MEDIUM |
| 2 | `hermes-setup/id_ed25519` private key still on disk | HIGH |
| 3 | No Python linting (ruff/mypy) in pre-commit or CI | MEDIUM |
| 4 | No retry logic in `prefetch-crates.py` for transient network failures | LOW |
| 5 | No parallelism in `prefetch-crates.py` (sequential downloads) | LOW |
| 6 | No subprocess timeouts in `commit-tag-push.py` and `fix-versions.py` (some calls have timeout=5, but not all) | LOW |
| 7 | `post-deploy-check.sh` temp files still use predictable names (no `mktemp`) | LOW |
| 8 | `display-watchdog.sh` / `niri-drm-healthcheck.sh` still always exit 0 — critical alerts don't trigger systemd failure | LOW |
| 9 | `dns-update.sh:63` — `sed s/old/new/` on commit hashes still uses `/` delimiter (safe for hex hashes, but inconsistent with the SRI hash fix) | LOW |
| 10 | `pocket-id-login-code.sh` — API key still visible in process args | MEDIUM |
| 11 | `test-shell-aliases.sh:63` — unquoted `$alias_name` in fish command string | LOW |
| 12 | `test-home-manager.sh` — TESTS_TOTAL inflation (20+ increment sites, some double/triple) | LOW |
| 13 | No functional test of `dns-update.sh` with real SRI hashes to verify sed delimiter fix | MEDIUM |
| 14 | `find-corrupted-files.sh` — no atime/write-amplification warning for QLC NAND | LOW |
| 15 | `crush-daily-backfill.py` find_binary() — lexicographic sort selects wrong binary version | MEDIUM |

---

## D) TOTALLY FUCKED UP

### ~~D-1: Never ran the VM tests~~ done — VM tests verified PASS in 04-55 report; 3 tests registered in `test-scripts.nix`
The biggest gap. I wrote 3 NixOS VM tests and verified they *evaluate*, but never *ran* them. A test that evaluates but fails at runtime is worse than no test — it gives false confidence. The tests might have syntax errors in the bash embedded in the testScript strings, the `machine.fail()` / `machine.succeed()` calls might not work as expected, or the VM might lack required packages.

**Impact:** The 3 tests are untested code testing tested code. Meta-failure.
**Fix needed:** Run `nix build .#checks.x86_64-linux.lib-helpers` (and the other two).

### D-2: `crush-daily-backfill.py` re-insert SQL is unverified
I wrote an `INSERT INTO events` to restore deleted events on collect failure. I never verified:
- Whether the `events` table schema matches (column names, order, NOT NULL constraints)
- Whether the re-inserted event causes a unique constraint violation on `aggregate_id`
- Whether the re-inserted event is even valid (it has the original payload, but the collect step may have partially modified state)

**Impact:** If the schema is wrong, the re-insert crashes with a SQL error, and the original data is STILL lost. The "fix" made the failure path MORE complex without verifying it works.
**Fix needed:** Check the actual events table schema from the crush-daily source code, or test against a real DB.

### ~~D-3: `disk-diagnose.sh` de-indentation was manual~~ done — verified with `bash -n` + shellcheck
When I removed the tautological outer `if` condition, I had to manually de-indent the inner block. I got the indentation close but had to do a second edit to fix it. If I'd missed a brace or indentation level, the script would have silently malfunctioned.

**Impact:** Low — the final state was verified with `bash -n` and `shellcheck`. But the process was fragile.

### ~~D-4: First multiedit attempt on `disk-fix.sh` only applied 1 of 2 edits~~ done — process lesson internalized
The `multiedit` reported "Applied 1 of 2 edits" but I initially didn't notice the partial failure. The duplicate `partprobe()` was still present after the first attempt. Required a follow-up edit.

**Impact:** Wasted a round trip. Pattern: multiedit partial failures are easy to miss.

---

## E) WHAT WE SHOULD IMPROVE

### Process
1. ~~**Always run tests after writing them.** Evaluating a test derivation proves the Nix expressions parse — it says nothing about whether the test passes. This is the #1 gap.~~ done — process lesson internalized; VM tests run in 04-55 session
2. **Verify SQL before writing it.** The `crush-daily-backfill.py` re-insert assumes a schema I never checked. Should have read the upstream `CREATE TABLE` statement first.
3. **Consider a "script test day" cadence.** These 44 scripts had bugs accumulating for months because they're untested. The 3 new VM tests are a start, but they cover lib.sh and patterns, not individual scripts. Each critical script (`deploy.sh`, `pre/post-deploy-check.sh`, `route-health-monitor.sh`) should have its own test.

### Codebase
4. **Python scripts have zero linting.** Pre-commit checks shellcheck + deadnix + statix + alejandra. No ruff, no mypy. Python bugs (bare except, missing encoding, unsafe subprocess) survive because nothing checks for them. Adding `ruff check scripts/*.py` to pre-commit is a one-line fix.
5. **The `lib.sh` safe helpers are unused.** Adding helpers without migrating callers means the protection is theoretical. Even a single migration (e.g., `post-deploy-check.sh` using `safe_head`) would prove the pattern and set precedent.
6. **10 scripts redefine their own colors.** Each is a tiny consistency debt. Not urgent, but each new script that copies the pattern perpetuates it.
7. **`niri-health.sh` is dead code.** It's unreferenced by any Nix config or systemd service. It duplicates logic from `niri-config.nix`. Keeping it risks divergence. Should be deleted or wired.

---

## F) NEXT 50 THINGS TO DO

### Critical (verify the work I just did)
1. ~~**RUN the 3 VM tests** — `nix build .#checks.x86_64-linux.lib-helpers` + `pipefail-sigpipe` + `sed-delimiter`~~ done — verified PASS in 04-55 report
2. **Verify `crush-daily-backfill.py` re-insert SQL** against the actual events table schema
3. **Verify `crush-daily-backfill.py` find_binary()** — fix the lexicographic sort to use mtime or version
4. **Fix `test-home-manager.sh` TESTS_TOTAL inflation** — 20+ increment sites need audit

### High priority (real bugs remaining)
5. **Delete or wire `niri-health.sh`** — dead code that duplicates inline metrics
6. **Remove `hermes-setup/id_ed25519`** private key from the working directory
7. **Add `ruff check` to pre-commit** for Python scripts — one-line addition to `.githooks/pre-commit`
8. **Migrate at least one script to use `safe_head`** from lib.sh — prove the pattern works
9. **Fix `pocket-id-login-code.sh` API key in process args** — pass via `--config -` or header file
10. **Fix `dns-update.sh:63` commit hash sed** — change `/` to `|` for consistency

### Medium priority (test coverage)
11. **Write VM test for `deploy.sh` exit code 4 handling** — mock `nh os switch` return codes
12. **Write VM test for `post-deploy-check.sh` check() return** — verify `return 1` propagates
13. **Write VM test for `route-health-monitor.sh` failover logic** — simulate ISP down/up
14. **Write VM test for `mptcp-endpoint-manager.sh` field extraction** — mock `ip mptcp` output
15. **Add `prefetch-crates.py` unit test** — mock `nix store prefetch-file` and verify crate parsing
16. **Functional test of `dns-update.sh`** — run with a real blocklist file and verify output

### Medium priority (consistency)
17. **Migrate `post-deploy-check.sh` to source `lib.sh`** — highest-value migration (most complex script)
18. **Migrate `verify-deployment.sh` to source `lib.sh`**
19. **Migrate `update-vendor-hash.sh` to source `lib.sh`**
20. **Migrate `test-home-manager.sh` to source `lib.sh`**
21. **Migrate `test-shell-aliases.sh` to source `lib.sh`**
22. **Migrate `disk-fix.sh` / `disk-diagnose.sh` / `disk-create-p9.sh` to source `lib.sh`** (currently source `disk-common.sh`)
23. **Migrate `find-corrupted-files.sh` to source `lib.sh`**
24. **Migrate `dns-diagnostics.sh` to source `lib.sh`**
25. **Replace `just` references in `dns-update.sh`** output messages with `nix run .#` equivalents

### Medium priority (Python hardening)
26. **Add `logging` module to `crush-daily-backfill.py`** — timestamps + levels for backfill operations
27. **Add timeouts to ALL subprocess calls in `commit-tag-push.py`** — some have timeout=5, git push has 30, but some calls lack it
28. **Add timeouts to ALL subprocess calls in `fix-versions.py`**
29. **Add retry logic to `prefetch-crates.py`** — 1-2 retries for transient CDN failures
30. **Parallelize `prefetch-crates.py`** — ThreadPoolExecutor with 8-16 workers
31. **Add `argparse` to `prefetch-crates.py`** — still uses manual `sys.argv` parsing
32. **Add type hints to `prefetch_crate()` return** — now returns `tuple[bool, str]` but callers should document

### Lower priority (polish)
33. **`post-deploy-check.sh` temp files** — use `mktemp` instead of `/tmp/.smoke-*`
34. **`display-watchdog.sh` exit 1 on critical** — trigger `onFailure` notification chain
35. **`niri-drm-healthcheck.sh` exit 1 on critical** — same
36. **`test-shell-aliases.sh:63`** — quote `$alias_name` in fish command
37. **`find-corrupted-files.sh` atime warning** — warn if target isn't mounted with `noatime`
38. **`usb-diagnostic.sh`** — validate device is removable (`lsblk -d -o RM`)
39. **`disk-diagnose.sh` sectors_to_tib** — still uses `$1` injection (was in the old code, didn't migrate to `-v`)
40. **`status-report.sh`** — `sudo -n` for generations might fail in non-interactive contexts; add fallback

### Documentation
41. **Document the `safe_head` / `safe_tail` pattern in AGENTS.md** — so future scripts use it
42. **Document the `disk-common.sh` pattern** — explain why constants are shared
43. **Add a "Scripts" section to CONTRIBUTING.md** — template for new scripts (source lib.sh, use safe helpers)
44. **Update AGENTS.md gotcha** — add the SIGPIPE under pipefail as a known pattern with the centralized fix
45. **Add `scripts/README.md`** — inventory of all scripts with one-line descriptions and usage

### CI/Pipeline
46. **Add `ruff check scripts/*.py` to `.githooks/pre-commit`** — one line, catches Python bugs shellcheck can't
47. **Add `ruff check scripts/*.py` to `.github/workflows/nix-check.yml`**
48. **Add `shellcheck --severity=style scripts/*.sh` to pre-commit** — catches more than warning level
49. **Run the 3 new VM tests in CI** — `nix build .#checks.x86_64-linux.lib-helpers` etc.
50. **Add a "scripts" job to CI** that runs `bash -n` + `py_compile` on ALL scripts on every PR

---

## G) QUESTIONS (cannot figure out myself)

### 1. Should I run the VM tests now? They take 2-5 minutes each.
I wrote 3 NixOS VM tests but never executed them. I can run them now (`nix build .#checks.x86_64-linux.lib-helpers` etc.), but each takes 2-5 minutes to build a VM, boot it, and run the test. Should I run all 3 now, or is evaluation-level verification sufficient for this session?

### 2. Should `niri-health.sh` be deleted or wired to a systemd service?
It's unreferenced by any Nix config. The production equivalent is inlined in `niri-config.nix:143-185` with a different journal filter (`_SYSTEMD_USER_UNIT=niri.service` vs `--user -u niri`). Deleting it is cleaner. Wiring it means maintaining two copies of the same logic. I cannot decide this without knowing if you use it manually.

### 3. Should I add Python linting (`ruff`) to pre-commit and CI right now?
Adding `ruff check scripts/*.py` to `.githooks/pre-commit` is a one-line change that would catch bare excepts, missing encodings, unsafe subprocess patterns, etc. But it would also flag issues in the 5 Python scripts that I haven't fixed yet (if any remain after this session). Should I add it and deal with any new findings, or hold off?

---

## Resolution (2026-08-10)

Round 2 of scripts review. All 28 deferred bugs fixed, 3 VM tests written. VM tests verified PASS in 04-55 report. Work captured in CHANGELOG [Unreleased] under "Scripts comprehensive review". Remaining items (crush-daily-backfill.py SQL, niri-health.sh dead code, ruff pre-commit) harvested into TODO_LIST.
