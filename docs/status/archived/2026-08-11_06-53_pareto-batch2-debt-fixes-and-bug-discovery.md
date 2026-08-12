# Status Report — Pareto Execution Batch 2: Debt Fixes + Upstream Verification + Bug Discovery

**Date:** 2026-08-11 06:53
**Session start:** ~04:15 (continued from prior session)
**Trigger:** User asked for self-review, comprehensive status update, and next steps

---

## A) FULLY DONE (this session)

### Debt Fixes From Prior Session Self-Review

| ID | Issue | Resolution | Verified? |
|----|-------|------------|-----------|
| D1 | CHANGELOG missing entries for 11 of 12 changes | Added entries across Added/Changed/Removed/Fixed sections covering: GOMEMLIMIT expansion, crush-daily cap, boot.nix ioTier conversion, Pocket ID retry, CI port check, PMA flake decoupling, test infrastructure, dead script deletion, ruff pre-commit, browser-history VM test, memory.events monitoring | Yes — grep verified all entries present |
| D2 | memory.events collector might fail silently under `ProtectSystem=strict` | **FALSE ALARM.** The service runs as root with `ProtectSystem=full` (not `strict`). `full` only mounts `/usr`/`/boot`/`/efi`/`/etc` read-only — `/sys/fs/cgroup` is NOT affected. Added documenting comment to the code | Yes — verified by reading `lib/systemd.nix` |
| D3 | browser-history VM test never run at runtime | Built + ran. First run: **FAILED** (curl exit 7 — Go server hadn't bound yet). Fixed: added `wait_for_open_port(8087, timeout=30)`. Second run: **PASSES** (25s, health 200) | Yes — `nix build .#checks.x86_64-linux.browser-history` exits 0, logs show `GET /health 200` |
| D4 | Upstream fixes assumed missing (both repos clean) | **BOTH FIXES ALREADY EXIST.** Prior session's `rg` searches were wrong. PMA `isNothingToCommit()` at `committer.go:289`, browser-history `ClientSecret` guard at `oauth2.go:64`. Both repos pushed to remote. PMA flake input already at HEAD. Browser-history flake input bumped 2 commits (`5c1a1b7` → `451fa4d`) | Yes — `git log`, `git rev-parse`, flake.lock verified |

### New Work Completed

1. **Generic memory.events Gatus alert** — Added `system_memory_events_any_high` summary metric to the collector (OR of all per-service flags). Gatus "Memory Events Thrash" check now monitors ALL services via the summary, not just PMA. Alert message tells you to grep the `.prom` file to identify which service
2. **ioTier expansion** — fstrim (`boot.nix`) and clamav-daemon (`security-hardening.nix`) converted from raw `IOSchedulingClass = "idle"` literals to `ioTier.maintenance`
3. **browser-history flake bump** — `451fa4d` (CSP-safe `.templ` templates + Tailwind v4 CSS refresh). Eval passes. vendorHash not broken (the 2 new commits are frontend-only)
4. **CI improvements** — browser-history VM test added to CI VM test matrix. Shellcheck CI job added (`--severity=error` on `scripts/*.sh` + `.githooks/*`)
5. **ruff.toml + Python cleanup** — Created `ruff.toml` (E/F/W/I/UP rules, ignoring DTZ/PLW for operational scripts). All 6 Python scripts cleaned: 3 auto-fixed (unused imports `sys`/`json`, f-strings without placeholders), 5 manual fixes (ambiguous `l` → `line` variables, unused `name` variable, line-length wraps)
6. **CRITICAL BUG FIX in crush-daily-backfill.py** — The INSERT into `events` table was missing two NOT NULL columns (`aggregate_type`, `version`) that have no defaults. The "restore original event" fallback (used when `crush collect` fails after deleting the original event) would crash with `NOT NULL constraint failed: events.aggregate_type`, permanently losing the deleted event. Only recoverable via the manual `backup_db()` backup. Fixed: SELECT, dict, and INSERT all now include `aggregate_type` and `version`
7. **AGENTS.md updated** — Added memory.events monitoring pattern (sandbox safety note, metric names, Gatus check) to the PMA death-loop gotcha. Added dms-wallpaper-init runtimeInputs gotcha

### Verification

- `nix flake check --no-build` — **ALL PASS**
- `nix fmt` — clean
- `ruff check scripts/*.py` — **ALL PASS**
- browser-history VM test — **PASSES** at runtime (25s, `/health` returns 200)

---

## B) PARTIALLY DONE

### Memory.events monitoring (partially done)

- **What works:** Collector scrapes `/sys/fs/cgroup/system.slice/<svc>/memory.events` for all monitored services. Emits per-service `system_service_memory_events_max`, `system_service_memory_events_high`, and summary `system_memory_events_any_high`. Gatus alerts on the summary metric.
- **What's missing:** The threshold (100) is a guess. PMA hit 27,312 before the crash, so 100 is sensitive enough. But it has NEVER BEEN DEPLOYED — there's zero runtime data on whether the collector actually works, whether the metrics show up in Prometheus, or whether the Gatus alert fires correctly.
- **What's also missing:** No per-service Gatus alerts. If `system_memory_events_any_high` fires, you have to manually grep the `.prom` file to find which service. This is documented in the alert message, but a per-service Gatus check would be more actionable.

### CI port check (partially done)

- **What works:** False positives reduced from 25 to 2 (92% reduction) by tightening the regex from `[^0-9]` to `[^0-9MiB]` and adding 10 exclusion terms + Docker connection-string filter.
- **What's still there:** 2 residual false positives (Docker container ports + a comment). These are `::warning::` not `::error::`, so they don't block CI — they're noise.

### ioTier conversion (partially done)

- **Converted:** sshd (`ioTier.interactive`), dms/pipewire (`ioTier.desktop`), fstrim (`ioTier.maintenance`), clamav-daemon (`ioTier.maintenance`).
- **Not converted:** nix-daemon in `networking.nix` (uses `mkForce` — would need `ioTier.build` to also use `mkForce`, which changes semantics). niri-config.nix has I/O settings embedded in a raw systemd unit string (can't use `ioTier.*` without refactoring). btrfs-health.nix services (balance, scrub) have NO I/O tier at all — they should arguably get `ioTier.maintenance`.

---

## C) NOT STARTED

These were in the 88-task Pareto plan but were not attempted this session (no sudo, no deploy, deferred by user choice):

| Task | Why Not Started |
|------|-----------------|
| **F01-F02: git push** | Requires user action. 27 files changed, all local. Auto-git daemon may commit. |
| **F04-F12: Deploy + reboot** | User said "no" to deploy. All changes are unactivated. |
| **F25-F29: BTRFS scrub, dnsblockd cleanup, /data fill, smartctl** | Requires sudo. |
| **F30: ClickHouse backup** | Requires deploy first. |
| **F31-F32: Twenty CRM PG role fix** | Requires sudo + deploy. |
| **F40-F42: Attic cache + CI token** | Requires deploy first. |
| **F43-F45: node_exporter textfile phantom metrics** | Requires deploy + runtime investigation. 14 Gatus checks may be permanently RED. Root cause unknown. |
| **F49-F55: SigNoz dashboard v2 rewrite** | 6 dashboards need Perses v2 schema rewrite. Deferred. |
| **F59: test-home-manager.sh TESTS_TOTAL inflation** | Audit 20+ increment sites. Not attempted. |
| **F68: deploy.sh backup retention** | Add cleanup of `.bak` files older than 3 deploys. Not attempted. |
| **F70: GOTOOLCHAIN=local on Go devShells** | Plan says "all Go devShells" but there are no Go devShells in this flake. Verified — task is N/A. |
| **F76-F80: Documentation freshness** | README, CONTRIBUTING, DOMAIN_LANGUAGE checks. Not attempted. |
| **F81-F88: Long-term/deferred** | ZFS native test, pool assessment, dep audit, dnsblockd CA cert. All deferred. |
| **F84: PMA GenerateMessage handler leak** | Upstream audit of `defer Close()` pattern. Not attempted. |
| **F85: file-and-image-renamer pin 3 inputs from ref=master to tags** | Not attempted. |
| **F86: Monitor365 DuckDB pool size metric** | Not attempted. |
| **F87: dep-audit script for LarsArtmann Go repos** | Not attempted. |
| **F88: dnsblockd CA cert deployment automation** | Not attempted. |

---

## D) TOTALLY FUCKED UP

### D-1: Prior session claimed upstream fixes were missing — they weren't

The prior session's self-review (status report `2026-08-11_04-15`) listed as finding D4: "Upstream fix assumptions were wrong (repos are clean)." It claimed `rg -l "isNothingToCommit"` returned nothing for PMA and `rg -l "ClientSecret"` returned nothing for browser-history.

**This was wrong.** Both functions exist:
- PMA: `isNothingToCommit()` at `pma-daemon/committer/committer.go:289-302` — fully implemented, tested (`committer_test.go:194-266`), with TOCTOU race comment block
- browser-history: Provider silently skipped when ClientID or ClientSecret is empty at `api/oauth2.go:44,53,64` — with test at `oauth2_test.go:79-80`

The prior session's `rg` searches likely failed due to wrong working directory, wrong search path, or typo. The Pareto plan (F13-F20) tasks were written based on this false finding. I wasted time investigating before discovering they already existed.

**Lesson:** `rg` returning nothing doesn't mean the code doesn't exist. Verify with `agent` tool (which searches properly) before claiming something is missing.

### D-2: The crush-daily-backfill.py bug was sitting there for the entire prior session

The prior session identified task F60 ("Verify crush-daily-backfill.py SQL — check INSERT against actual CREATE TABLE") but never executed it. If it had, it would have caught the missing `aggregate_type`/`version` columns — a **data-loss bug** in the restore-on-failure path.

I only caught it because the user asked me to "keep going until done" and I picked F60 as a quick win.

### D-3: The memory.events Gatus alert was PMA-only until this session

The prior session wrote `system_service_memory_events_high{service="projects-management-automation"}` — hardcoding PMA into the Gatus check. This means every other service's death-loop would go undetected. I fixed it this session with the `system_memory_events_any_high` summary metric, but this should have been caught in code review before committing.

### D-4: CHANGELOG discipline is STILL recursive

The prior session's finding D1 was "CHANGELOG entries missing for 11 of 12 changes." I fixed those 11 entries... and then immediately made 7 MORE changes (ioTier expansion, browser-history bump, CI improvements, ruff config, SQL bug fix) that initially had no CHANGELOG entries either. I caught this before finishing, but the pattern persists: **every batch of changes needs CHANGELOG entries, and "I'll add them later" never works.**

### D-5: ruff pre-commit hook was added but would have FAILED on existing code

The prior session added `ruff check` to `.githooks/pre-commit` but didn't create a `ruff.toml` and didn't verify that existing Python scripts pass. There were **8 ruff violations** across 4 scripts (unused imports, ambiguous variables, f-strings without placeholders, line-too-long). The first commit touching any `.py` file would have failed the pre-commit hook. I fixed this by creating `ruff.toml` and cleaning all 6 scripts.

---

## E) WHAT WE SHOULD IMPROVE

### Process

1. **Verify claims before encoding them into plans.** The Pareto plan's Tier 3 (F13-F20, 8 tasks) was entirely based on the false claim that upstream fixes were missing. A 5-minute verification would have saved the plan from including 8 phantom tasks.

2. **Run tests at runtime, not just eval.** The browser-history VM test eval-passed but failed at runtime (Go server hadn't bound the port). The `wait_for_open_port` fix was trivial, but the false confidence of "eval passes = test passes" is dangerous.

3. **CHANGELOG entries must be written IMMEDIATELY after each change, not batched at the end.** Batching leads to forgetting. The prior session forgot 11 entries. This session almost forgot 7 more.

4. **`rg` returning nothing is not proof of absence.** Use the `agent` tool for searches — it handles paths and patterns more reliably.

5. **Pre-commit hooks must be validated against existing code before being merged.** The ruff hook would have blocked the next commit.

### Architecture

6. **The memory.events monitoring is deploy-unverified.** It eval-passes, the metrics look right, but until it's deployed and we see actual values in Prometheus, we don't know if the collector works, if the thresholds are sane, or if the Gatus alert fires. Deploy is the critical validation step.

7. **Per-service Gatus alerts would be more actionable than a summary metric.** The current `system_memory_events_any_high` tells you SOMETHING is wrong, but you have to grep the `.prom` file to find WHAT. Adding per-service checks (like PMA, discordsync, browser-history) would be more useful — but also more verbose.

8. **The nix-daemon ioTier conversion is blocked by a semantic mismatch.** `ioTier.build` uses `mkDefault`, but `networking.nix` uses `mkForce`. Converting would either change the priority (potentially breaking something) or require adding `mkForce` variants to the ioTier definitions. This is a design smell — `ioTier` should probably offer both `mkDefault` and `mkForce` variants.

### Technical Debt

9. **14 Gatus checks are potentially permanently RED** (F14: phantom metrics). This has been flagged since the prior session but not investigated. Root cause unknown — could be node_exporter collector flags, textfile directory permissions, or metric format issues. Every day these stay RED is alert fatigue.

10. **Zero off-site backup.** All work — 27 changed files, the entire 2,927-commit history — is local-only. NVMe failure = total loss. This has been the #1 risk since 2026-06-25 and is still unresolved.

---

## F) UP TO 50 THINGS WE SHOULD GET DONE NEXT

### Critical (data loss / safety)

1. `git push origin master` — push all 27 changed files + accumulated commits
2. `nix run .#deploy` — activate all accumulated work from 2+ sessions
3. `nix run .#post-deploy-check` — verify functional outcomes post-deploy
4. `sudo systemctl reboot` — activate tarball regression fix (registry override)
5. Post-reboot: `nix registry list | grep tarball` — verify empty
6. Post-reboot: `systemctl --failed` — verify all services came back
7. Off-site backup setup (Hetzner StorageBox + restic/borg) — #1 data loss risk
8. BTRFS scrub on `/` — `sudo btrfs scrub start -B /` (never scrubbed, same NVMe)
9. BTRFS scrub on `/data` — `sudo btrfs scrub start -B /data`
10. ClickHouse backup before next SigNoz upgrade — `BACKUP DATABASE signoz TO Disk(...)`

### High Priority (broken things)

11. Root-cause 14 phantom metrics (F14) — 14 Gatus checks potentially permanently RED
12. Verify memory.events collector works at runtime post-deploy
13. Verify GOMEMLIMIT values are effective on all 8 Go services post-deploy (F23/F48)
14. Twenty CRM PG role fix — `CREATE ROLE twenty` + grants (app down since deploy)
15. Verify PMA not in cooldown loop post-deploy
16. Verify browser-history not crash-looping post-deploy
17. Clean orphaned dnsblockd tracking DB — `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db`
18. `docker system prune -a --volumes` on `/data` (review first)
19. `sudo smartctl -a /dev/sda /dev/sdb` — SMART health check on external drives

### Medium Priority (monitoring / infrastructure)

20. Per-service memory.events Gatus alerts (not just summary)
21. SigNoz dashboard v2 rewrite — `signoz-overview.json` (Perses v2 schema)
22. SigNoz dashboard v2 rewrite — `gpu.json`
23. SigNoz dashboard v2 rewrite — `dns.json`
24. SigNoz dashboard v2 rewrite — `docker.json`
25. SigNoz dashboard v2 rewrite — `caddy.json`
26. Verify SigNoz dashboard provisioning POSTs return 200
27. Attic cache create + CI token for build acceleration
28. Configure Forgejo runner to use Attic cache
29. Caddy reload root-cause fix (`PrivateTmp = lib.mkForce false`)
30. Smart monitoring for external drives (smartctl Gatus alert)
31. Monitor365 DuckDB pool size metric (F86)
32. PMA `GenerateMessage` handler leak audit (F84)

### Low Priority (code quality / consistency)

33. Convert nix-daemon to `ioTier.build` (blocked by mkForce/mkDefault mismatch)
34. Convert niri-config.nix embedded I/O settings (requires refactoring raw unit string)
35. Add `ioTier.maintenance` to btrfs-health.nix balance/scrub services
36. Pin file-and-image-renamer's 3 inputs from `ref=master` to tags (F85)
37. Fix `test-home-manager.sh` TESTS_TOTAL inflation (F59)
38. deploy.sh backup retention — cleanup `.bak` files older than 3 deploys (F68)
39. Fix remaining 2 CI port check false positives
40. Add CI workflow for all VM tests (currently only 4 of 8 run in CI)
41. Create dep-audit script for LarsArtmann Go repos (F87)
42. dnsblockd CA cert deployment automation for macOS (F88)

### Documentation

43. Check README.md for stale references to removed services
44. Check docs/CONTRIBUTING.md freshness
45. Verify docs/DOMAIN_LANGUAGE.md exists
46. Wire `scripts/doc-freshness-check.sh` into pre-commit or CI
47. Document prevention layers in CONTRIBUTING.md
48. Update browser-history AGENTS.md dependency table (v4.3 → v4.7.0 version drift)

### Verification

49. Verify crush-daily MemoryMax=1G is sufficient at runtime (user confirmed but never deployed)
50. Verify the 2 browser-history flake bump commits (CSP-safe templates) don't break the web UI at runtime

---

## G) Questions I CANNOT Answer Myself

### Q1: Should the memory.events threshold be per-service instead of a flat 100?

The flat threshold of 100 is applied to ALL monitored services. But different services have different memory patterns:
- **PMA** (260+ repos, page-cache heavy): 100 is appropriate (it hit 27,312 before crashing)
- **dnsblockd** (embedded DNS resolver, low memory): 100 might be too high — it might never fire even if something is wrong
- **SigNoz** (ClickHouse + OTel collector, memory-intensive): 100 might be too low — it might fire frequently under normal load

Should I make the threshold configurable per-service, or is a flat 100 sufficient for a homelab?

### Q2: The btrfs-health.nix balance/scrub services have NO I/O tier configured at all. Should I add `ioTier.maintenance`?

These services do heavy I/O (balance reshuffles data chunks, scrub reads the entire filesystem). Without an I/O tier, they run at the default BFQ class (BE/4), which means they compete with interactive services for I/O. Adding `ioTier.maintenance` (idle priority) would prevent them from causing I/O stalls during maintenance windows — but it would also make them slower.

Is the tradeoff acceptable, or should balance/scrub stay at default priority since they run at off-peak hours (Mon 04:00/05:00)?

### Q3: Should I add a `ruff format` step alongside `ruff check`?

Currently the pre-commit hook only runs `ruff check` (linting). Adding `ruff format` would auto-format Python code (like `alejandra` does for Nix). But there's no `ruff format` in the `nix fmt` treefmt config — Python formatting would only happen at commit time, not via `nix fmt`. This creates a split-brain where `nix fmt` doesn't format Python but pre-commit does.

Should I add `ruff` to the treefmt config (so `nix fmt` handles Python too), or keep it as pre-commit-only?
