# Guard Expansion Round 2 — Mount-Gating, Gatus Coverage, Deploy-Restart Audits

**Session:** 2026-09-14, ~17:55–19:20 CEST (continuation of `2026-09-14_17-49` brutal-self-review backlog)
**Prompt:** "READ, UNDERSTAND, RESEARCH, REFLECT. Break this down into multiple actionable steps. Execute and Verify them one step at a time. Repeat until done."
**Outcome:** 3 NEW eval-time guards landed (mount-gating, gatus-coverage, deploy-restart) with 22 negative-test cases; the cv known-red FIXED (pre-commit full-check leg re-armed); **5 live bugs found and fixed** by the new guards; FULL build-mode `nix flake check` EXIT 0 for the first time since 2026-09-13. **Deploy NOT completed — blocked twice (details in d/e).**

---

## a) FULLY DONE

| # | Deliverable | Evidence |
|---|---|---|
| 1 | **cv VM fixture fixed** — `tests/test-cv.nix` seeds `CV_OIDC_CLIENT_SECRET` in the mock env; researched upstream first: validation rejects empty secret when `oidc.enabled` (`config_validate.go:448`), discovery is LAZY (`OIDCFlow.ensureProvider` on first /admin use) so no auth.home.lan contact in the VM | `nix build .#checks.x86_64-linux.cv` → `vm-test-run-cv` **PASSED** (full VM run, exit 0) |
| 2 | **`mount-gating-audit.nix`** — every `ReadWritePaths` under `/mnt/` must be gated by `RequiresMountsFor` (ancestor OR descendant form — atticd-storage-dir shape) or `ConditionPathIsMountPoint`; `ConditionPathIsDirectory` deliberately rejected (shadow-dir masking bug). `/data` out of scope (fixed internal partition — never the incident class) | 9-case negative test builds+passes; hand-probed firing on evo-x2 `extendModules`; evo-x2 assertions 0 failed |
| 3 | **2 LIVE BUGS fixed by guard #2**: `bank-sync-canary` (wrote report to pool dataDir with ZERO gating — added storage-dir after/wants + `RequiresMountsFor`) and `immich-db-backup` (pg_dump to pool mediaLocation ungated — added `RequiresMountsFor`) — both the 226/contamination class, found by the probe BEFORE the audit shipped | probe output + fixes in `bank-sync.nix` / `immich.nix` |
| 4 | **`gatus-coverage-audit.nix`** — two directions over RESOLVED config: (A) every in-use registered port (unit Exec*/Environment text ∩ registry) must appear in a gatus URL; (B) every LOOPBACK gatus URL must carry a registered port (external upstreams like `tcp://dot.mullvad.net:853` exempt — that finding is why the loopback restriction exists). Gated on `services.gatus.enable` | 7-case negative test passes; hand-probe on extended evo-x2 fires + base config clean |
| 5 | **Justified adjacent allowlists**: `fastflowlm.nix` (:52625/:52626 — MUST-NOT-probe, slot-churn incident 2026-08-18; liveness via system-health metrics) and `systemd-graph.nix` (monitored via `https://graph.home.lan` vHost — port never in a URL) | both modules, with justification comments at the definition sites |
| 6 | **`deploy-restart-audit.nix`** — reads `scripts/deploy.sh` AT EVAL TIME and requires every converger-pattern oneshot (`-storage-dir/-backup-dir/-dirs/-provision/-setup/-bootstrap/-oidc-secret/-oidc-env/-migrate`) AND every oneshot+RemainAfterExit+restartTriggers unit (inert by construction) to appear in the script; default allowlist for 4 upstream units (postfix-setup, postgresql-setup, systemd-tmpfiles-resetup, resolvconf) | 6-case negative test passes; evo-x2 0 failed |
| 7 | **2 LIVE BUGS fixed by guard #6**: `cv-oidc-env` (the 2026-09-13 OIDC bridge) was in NO deploy.sh restart list — the dnsblockd desync class waiting to happen → added dedicated is-active-gated restart block (it's INDIRECTLY enabled, `wantedBy=cv-server.service`, so the provisioner loop's `is-enabled` gate would skip it); `signoz-clickhouse-log-ttl` carried INERT restartTriggers → removed (partOf=clickhouse + daily timer do the real convergence) | `scripts/deploy.sh` new block; `signoz.nix` trigger removal with comment |
| 8 | **Port-audit refinements**: flag-form trailing boundary tightened to non-alnum (`--port=8100abc` no longer extracts); `word:NNN` FP class PINNED in tests (`DELAY:300` fires = documented limitation, `DELAY:3000` benign collision); header claim softened from "never a false alarm" to honest | 4 new test cases, all pass; evo-x2 still clean |
| 9 | **harden-lifecycle test extended** — all 12 blocklisted keys now individually negative-tested (7 new cases: ExecStartEx, ExecStopPost, ExecStopEx, ExecReload, ExecCondition, RemainAfterExit, plus the original set) | derivation builds+passes |
| 10 | **Legacy CI port-grep DECIDED (was open question 3)**: KEPT as the source-level net for non-unit forms (Caddy/compose/script literals — documented non-goals of the eval audit), with a header comment pointing at the eval audit as the owner of unit-wired ports | `.github/workflows/nix-check.yml` |
| 11 | **Docs**: `docs/CONTRIBUTING.md` — full guard inventory table + "Adding a new guard" 6-step runbook (probe-first, /tmp probes, bare-attrset shape, pathspec git add, hand-probe-new-cases, adjacent allowlists) + fixed its OWN stale `//`-merge example in the Systemd Hardening section (the exact anti-pattern `audit-serviceconfig-merge.sh` rejects); `AGENTS.md` — prevention table row extended, cv-known-red bullet flipped to FIXED + eval-cache pass-branch trap documented, 2 gotcha bullets annotated with their enforcing guards | committed (daemon batch) |
| 12 | **Verification battery ALL GREEN**: `nix flake check --no-build` PASS (0 errors); **FULL build-mode `nix flake check` EXIT 0** (every VM test + lint derivation built and ran — first full green since 2026-09-13); `nix fmt --no-update-lock-file -- --ci` clean; targeted VM tests green (cv, bank-sync-paperless, paperless, signoz-query-lint); static scanners (merge-audit selftest, nullglob, textfile-tmp, yaml) green; deadnix nit fixed | session log below |
| 13 | **Pre-deploy step 5 guard-collision fixed** — its source grep for `harden { Type =` literals now excludes `./tests/` (negative-test fixtures DELIBERATELY carry the bad shapes; the eval throw makes them impossible in real modules) | `scripts/pre-deploy-check.sh` |

## b) PARTIALLY DONE

- **DEPLOY — BLOCKED TWICE, NOT COMPLETED.** Attempt 1: pre-deploy step 5 tripped on my own harden-lifecycle test literals (fixed, see a#13). Attempt 2: pre-deploy **123→124 passed, 0 failed**, but the memory-pressure gate correctly refused — `I/O PSI avg10 45% WITH disk busy 101%` = REAL storm. Root cause chain: my own full-check build writeback + the auto-commit daemon's NOW-UN-PHANTOMED pre-commit hook (the cv fix means every daemon commit triggers a FULL build-mode flake check = VM-test builds!) + 1-3 qemu VM tests from parallel sessions (observed live, escalating avg300 to 86%). I armed a conservative poll-then-deploy loop (qemu=0 AND diskbusy<800ms) — it never found a quiet window in 20 min; **killed it** before writing this report. All changes remain undeployed but committed.
- **mkIf-false option-existence trap**: setting the audit allowlist inside `fastflowlm.nix`/`systemd-graph.nix` broke `checks.x86_64-linux.paperless` (options-only fastflowlm import) — fixed by importing the audit module in that ONE test. Only the currently-failing surface was fixed; any FUTURE test importing those modules must do the same (documented in the test comment, not yet a convention note in AGENTS.md).
- **AGENTS.md prevention-table sweep (backlog #42)**: eval-time row updated; the Pre-commit row does not yet mention that the hook's flake-check leg is now build-mode-with-teeth.

## c) NOT STARTED (remaining from the standing backlog — not researched this session)

1. P1 #12: shape-audit window-refire detector (`OnUnitActiveSec` < `startLimitIntervalSec`).
2. P1 #13: HM-side `$HOME` check (export a small HM module reusing class-4 logic).
3. P1 #15: allowlist-justification-comment lint (grep-based).
4. P2 #19–40 (untouched): WatchdogSec/sd_notify, startLimit ownership tag, onFailure audit, ioTier coverage, sops-owner audit, gate-clone audit, Caddy vHost lint, Homepage tile lint, DNS subdomain cross-ref, backup-coordination cross-ref, version-pin audit, readFile-on-package-output lint, uid-toString lint, `with pkgs;` ban, WorkingDirectory lint, journalctl `--since`+`timeout` lint, awk-over-glob lint, `*_scrape_errors` gauge lint, CI `--keep-going` discipline, gatus `[RESPONSE_TIME]` lint, signoz forward assertion.
5. P3 #50: `nix run .#audit-probe` alias app (probe files still go to /tmp manually).
6. Shared-helper extraction: the unit-text port scanner is now duplicated in `port-registry-audit.nix` + `gatus-coverage-audit.nix` (~30 lines × 2).

## d) TOTALLY FUCKED UP (all caught by layers, zero user-visible damage)

1. **`->` instead of `:` in a lambda** (`ancestor: path -> …`) — parses as logical implication, `undefined variable 'path'`. Caught by build.
2. **POSIX ERE violations TWICE in one regex**: `https?` (POSIX ERE has no `?` quantifier) then `\[` (undefined escape — glibc rejects). Nix builtins use POSIX ERE, not PCRE; cost two build cycles on `gatus-coverage-audit`.
3. **Redundant gatus mock module** — collided with nixpkgs' own `services.gatus` options (every nixosSystem eval carries the real module). Dropped.
4. **Bare-attrset vs lambda import shape AGAIN**: `(import …gatus-coverage-audit.nix { })` — the same wrong-form class as last session's wrapper-shape miss. Second repeat of this exact mistake.
5. **mkIf-false option-existence trap missed at DESIGN time** — my "evo-x2 evals clean" verification only covered the host toplevel, NOT the flake's per-check evals; `nix flake check --no-build` caught the paperless break. Lesson: a cross-module option set changes the import requirements of EVERY eval surface that touches the setting module.
6. **Guard-vs-guard collision**: extending harden-lifecycle tests tripped pre-deploy step 5's source grep. Predictable in hindsight — any source-level check eventually sees negative-test fixtures. Fixed with a tests/ exclusion + comment.
7. **deadnix unused-lambda arg shipped** (`_n: svc`) — caught by the full check's deadnix leg.
8. **6 files not nixfmt-style at write time AGAIN** — the identical prior-session lesson, repeated (`--ci` found 6 changed).
9. **Deployed-into-my-own-writeback sequencing error**: measured 0ms disks BEFORE my background full-check finished draining, declared safe, launched deploy — the gate then measured the real writeback (101% busy). Should have waited for my OWN jobs to quiesce first.

## e) WHAT WE SHOULD IMPROVE

1. **The daemon's pre-commit hook is now a heavyweight builder.** With cv green, every auto-commit runs FULL build-mode flake check (VM tests). Observed live: sustained 40-86% IO PSI from hook-triggered builds + parallel-session qemu churn — the deploy gate refused because of it. This is the strongest gate we have, but on this IO-fragile box it makes every daemon commit an IO event. Needs an explicit decision (question 2).
2. **Parallel-session contention is now the deploy bottleneck.** 2-3 concurrent qemu VM tests from other sessions + hook builds = no quiet windows for ~20 min. The `heavy-job` wrapper exists; the hook does not use it.
3. **Verify ALL eval surfaces, not just the host toplevel**, when a change touches cross-module option setting — checks/*.nix eval against minimal module sets with different import graphs.
4. **Write POSIX-ERA Nix regexes**: no `?`, no `\[`; only `\\.`-class escapes. A 10-second mental lint before writing `builtins.match` would have saved two cycles.
5. **Format at write time** — second consecutive session where `--ci` found 6 unformatted files. The runbook says it; the fingers don't do it.
6. **`deploy-restart-audit` reads `scripts/deploy.sh` via a repo-relative path** — fine internally and for direct-file imports (VM tests), but the exported `nixosModules.deploy-restart-audit` would FAIL in a foreign flake lacking that path. Acceptable today (internal-only); document if ever published.
7. **Negative-test fixtures polluting source-level checks** is now a designed-in pattern (tests deliberately carry bad literals) — every future source-level lint needs the same `^\./tests/` exclusion thinko as pre-deploy step 5.

## f) NEXT — up to 50 (Pareto order; c-items folded in)

1. **Deploy evo-x2** — retry in a quiet window or per owner decision (everything is committed; eval-time-only + 5 unit-file changes: bank-sync-canary, immich-db-backup, cv deploy.sh block is script-side, signoz trigger removal, systemd-graph/fastflowlm allowlist options are inert).
2. Daemon pre-commit throughput decision + implementation (hook → `--no-build` + scheduled full check, or `heavy-job`-wrap, or `--no-verify` for daemon commits).
3. Post-deploy verification of the 5 live fixes: `systemctl cat bank-sync-canary immich-db-backup | grep RequiresMountsFor`, cv-oidc-env restart block fires once.
4. shape-audit class-2 extension: window-refire detector (OnUnitActiveSec vs startLimitIntervalSec).
5. HM-side `$HOME` audit module (quickshell/home.nix import surface).
6. Allowlist-justification-comment lint (pre-commit grep).
7. mkIf-false option-existence convention note in AGENTS.md (adjacent allowlists require the audit module import in minimal evals — test-paperless is the reference fix).
8. AGENTS.md pre-commit row: note the hook's flake-check leg is build-mode since cv green.
9. Extract shared unit-text port-scan helper into `lib/` (2 duplicates today).
10. `nix run .#audit-probe` alias (retire /tmp probe files).
11. journalctl `--since`+`timeout` lint (sev1 page class).
12. awk-over-glob static lint (vanished-input class; regression test exists, lint doesn't).
13. `*_scrape_errors` gauge-presence lint for textfile collectors.
14. Caddy vHost lint: `protectedVHost`/`proxyTo`/`${commonConfig}` conventions.
15. DNS subdomain cross-ref: every Caddy vHost name in `dnsLocal.localSubdomains`.
16. Homepage tile `lib.optional`-on-enable lint.
17. backup-coordination coverage cross-ref (every `/mnt/pool/backups/*` writer registered).
18. sops secret OWNER audit extension (DynamicUser consumers must use template/LoadCredential).
19. Gate-clone audit (hand-rolled `-wait-dns`/`-wait-oidc` beyond the 3 known).
20. `onFailure` presence audit for repo-owned simple services.
21. ioTier coverage audit (DB/AI services must declare a tier).
22. startLimit ownership tag (`systemnix` attrset on our units) → presence audit.
23. WatchdogSec-without-sd_notify flag for `Type=notify` services we own.
24. `with pkgs;` ban (statix rule or grep guard).
25. `builtins.readFile`-on-package-OUTPUT source lint (niri trap class).
26. `toString`-on-uid source lint.
27. WorkingDirectory-under-/var/lib-without-StateDirectory lint.
28. Version-pin audit for `github:`-type inputs without `?ref=`.
29. gatus `[RESPONSE_TIME]` coverage lint for user-facing endpoints.
30. SigNoz coverage forward assertion (registry entries for disabled services).
31. CI `--keep-going` discipline when red (enumerate dominoes).
32. `docs/services/*.md` sweeps for the 5 live fixes (bank-sync/immich/cv runbooks mention the new gating).
33. TODO_LIST refresh: strike completed backlog items (P0 1-6, 8-10, P1 11/14/17-18, P3 42-44 mostly done).
34. Consider VM-test coverage for the cv-oidc-env bridge block (deploy.sh blocks are untested by nature — at least a docs note).
35. Re-probe gatus coverage quarterly OR wire the audit's offender count into a metric (currently eval-time-only visibility).
36. systemd-graph: consider a backend-port liveness check in ADDITION to the vHost check (would let the allowlist entry retire).
37. The `resolvconf` default-allowlist entry: revisit if nixpkgs ever fixes its inert restartTriggers.
38. Full-history secret scan: add `CV_OIDC_CLIENT_SECRET`-style env keys? (No — mock values only; skip unless a real secret pattern appears.)
39. Evaluate whether `mount-gating-audit` should cover `/data` after all (ollama currently ungated there — decided NO this session; revisit if /data ever goes removable).
40. Session-boot-audit style negative-test for the mkIf-false trap itself (a fixture module setting an allowlist without the audit imported → eval fails → test asserts the ERROR message) — turns the trap into a documented, executable lesson.
41–50. Reserved: P2 items already enumerated in `2026-09-14_17-49` §f #19-40 not duplicated above — that report remains the master backlog; this session completed its P0 #1-10 and P1 #11/14/17-18 equivalents.

## g) QUESTIONS (cannot determine from the repo)

1. **Deploy**: retry now with `DEPLOY_FORCE_PRESSURE=1` (pre-deploy itself is 124-pass/0-fail; the pressure is parallel-session VM churn + hook builds, and the change set is eval-time-only + 5 small unit-file edits), wait for a natural quiet window, or leave it to the parallel session's next deploy?
2. **The daemon's pre-commit hook now builds VM tests on every auto-commit** (cv fix un-phantomed it — this is the gate working, but it turned every daemon commit into an IO storm contributor on a box that froze 3× from IO). Keep full-check-per-commit, switch the hook to `--no-build` + a scheduled/heavy-job full check, or exempt daemon commits with `--no-verify`?
3. **Allowlist doctrine** (carried from last session, now 3 more sites): adjacency at the definition site (current — fastflowlm/systemd-graph/forgejo-repos set their own entries) vs centralizing all audit allowlists in `configuration.nix`? Adjacency couples better but leaks the mkIf-false import requirement into every consumer (test-paperless).

---

## Verification state at session end

- `nix flake check --no-build`: **PASS** (0 errors, deadnix fix verified after)
- **FULL `nix flake check` (build mode): EXIT 0** — all VM tests + all lint derivations green (first full green since the cv red landed 2026-09-13)
- New/extended negative tests (4 files, 29 cases total): all build+pass; mount-gating + gatus-coverage hand-probed firing on extended evo-x2
- `nix fmt --no-update-lock-file -- --ci`: clean (after the formatter fixed my 6 files)
- Static scanners: merge-audit (172 files, fail=0 + selftest), nullglob, textfile-tmp, workflow yaml — green
- Deploy: **NOT executed** (blocked at the pressure gate; pre-deploy leg itself 124 passed / 0 failed after the step-5 fix)
- Tree: fully committed (daemon batched as `chore: auto-commit` — per-task attribution lost again, same known limitation)

## Live findings this session fixed (the guards earning their keep immediately)

| Finding | Guard | Fix |
|---|---|---|
| `bank-sync-canary` ungated pool writes | mount-gating-audit probe | storage-dir ordering + RequiresMountsFor |
| `immich-db-backup` ungated pool writes | mount-gating-audit probe | RequiresMountsFor |
| `cv-oidc-env` absent from ALL deploy.sh restart mechanisms | deploy-restart-audit probe | dedicated is-active-gated block (indirect unit) |
| `signoz-clickhouse-log-ttl` inert restartTriggers | deploy-restart-audit probe | removed (partOf + timer converge) |
| `cv` VM fixture missing `CV_OIDC_CLIENT_SECRET` | (manual, from backlog P0 #1) | seeded; lazy discovery verified in CV source |
