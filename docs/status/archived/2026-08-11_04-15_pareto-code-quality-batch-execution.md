# Status Report: Pareto Plan Execution — Code Quality Batch

**Date:** 2026-08-11 04:15
**Session scope:** Executing actionable tasks from the 88-task Pareto plan (`docs/planning/2026-08-10_13-53_pareto-execution-plan.md`) that can be done without `sudo` or `git push`.
**Quality gate:** `nix flake check --no-build` — ALL PASS, `nix fmt` applied.

---

## What Did I Forget? What Could I Have Done Better?

### Critical Omissions

1. **No CHANGELOG entries for THIS session's changes.** I added a CHANGELOG entry for the *prior session's* ioTier fix (F24), but NONE of the ~11 changes I made this session got entries: GOMEMLIMIT on 2 services, memory.events monitoring, dead script deletions, ruff pre-commit, boot.nix ioTier conversion, CI port check fix, browser-history test, dms runtimeInputs, pocket-id retry. The CHANGELOG should be the first place these land.

2. **No AGENTS.md updates.** The memory.events death-loop detection pattern, the `dms` runtimeInputs fix, the CI port check regex improvements — all are non-obvious knowledge that belongs in AGENTS.md gotchas. I discovered them and moved on without recording.

3. **Browser-history VM test is eval-only.** `nix flake check --no-build` confirms the test *evaluates*, but I never ran `nix build .#checks.x86_64-linux.browser-history` to verify the VM actually boots and the test passes at runtime. Eval passing ≠ runtime passing.

4. **memory.events alert only monitors PMA.** The Gatus check hardcodes `service="projects-management-automation"`. The metric is collected for ALL monitored services, but only PMA gets a Gatus alert. The PMA death-loop was the *known* case, but any service could thrash. The alert should be generic or at least cover all services with MemoryMax set.

5. **memory.events cgroup path may be unreadable.** The system-health collector runs with `harden {}` which includes `ProtectSystem=strict`. Reading `/sys/fs/cgroup/system.slice/<svc>/memory.events` may fail under that sandbox. I didn't verify this. The collector has `ReadWritePaths = [ textfileDir ]` but cgroup v2 `/sys/fs/cgroup/` may need explicit `ReadOnlyPaths` access.

6. **crush-daily MemoryMax=1G is a guess.** The service previously had NO MemoryMax (uncapped). I added `1G` + `GOMEMLIMIT=768MiB` without checking actual memory usage. If crush-daily spawns AI calls that buffer large responses, 1G may be too low. Should verify after deploy.

7. **Did not audit other dead scripts.** I deleted `nvme-metrics.sh` and `niri-health.sh` but didn't check if `scripts/` has other unreferenced scripts.

8. **Did not run shellcheck on pre-commit hook changes.** The pre-commit hook runs shellcheck on `.sh` files, but `.githooks/pre-commit` itself is never shellchecked.

### Process Improvements

- **Run `nix flake check` after EACH change, not at the end.** I batched changes and ran a single check. If it failed, I'd have to bisect. Fortunately it only failed on the test file (git tracking + mock issues), which was easy to isolate.
- **Always write CHANGELOG entries in the same edit as the code change.** Not "later". Later never comes.
- **When adding monitoring metrics, verify the collector can actually read the data source** under its sandbox constraints.

---

## a) FULLY DONE (13 tasks)

| ID | Task | Evidence |
|----|------|----------|
| F24 | CHANGELOG entry for ioTier `//`→`mkMerge` fix | `CHANGELOG.md:141` |
| F46-F47 | memory.events death-loop metric + Gatus PMA alert | `system-health.nix`, `gatus-config.nix` |
| F56 | Delete dead `scripts/nvme-metrics.sh` | Trashed (unreferenced in Nix) |
| F57 | Delete dead `scripts/niri-health.sh` | Trashed (replaced by inline `niri-health-metrics` in niri-config.nix:150) |
| F58 | `ruff check` for Python files in pre-commit | `.githooks/pre-commit` |
| F61-F62 | GOMEMLIMIT on file-and-image-renamer (384MiB), crush-daily (768MiB) | 2 service files |
| F64-F66 | boot.nix sshd/dms/pipewire → `ioTier.*` | `platforms/nixos/system/boot.nix` |
| F33 | Pocket ID `api_get` retry (3x, 2s delay) | `pocket-id.nix:79` |
| F37 | CI port check false positives: 25→2 (92% reduction) | `.github/workflows/nix-check.yml` |
| F36 | Thread `inputs` through `tests/default.nix` | `flake.nix:678`, `tests/default.nix` |
| F69 | `dms` binary added to `dms-wallpaper-init` runtimeInputs | `niri-wrapped.nix:91` |
| F71-F72 | browser-history VM test created + registered | `tests/test-browser-history.nix` |

---

## b) PARTIALLY DONE

| Item | What's done | What's missing |
|------|-------------|----------------|
| **memory.events monitoring** | Metric collected for all monitored services, Gatus alert for PMA | Alert only covers PMA (should be all services with MemoryMax); cgroup path readability under `ProtectSystem=strict` UNVERIFIED |
| **CI port check** | False positives reduced 25→2 | 2 residual false positives remain (voice-agents Docker port mapping, pocket-id comment) |
| **ioTier consistency** | boot.nix sshd/dms/pipewire converted | fstrim/clamav already had ioTier via their modules; niri service config comes from upstream flake (can't convert); security-hardening.nix has no I/O config |
| **GOMEMLIMIT coverage** | Added to 2 more Go services (total: 8/10 Go services) | attic (Rust — N/A); go-cqrs-lite services not in SystemNix scope. Remaining Go services without GOMEMLIMIT: dns-blocker already has it (GOMEMLIMIT=1500MiB) |
| **Test infrastructure** | `inputs` threaded, browser-history test created | browser-history test eval-passes but UNTESTED at runtime; no CI workflow to run it automatically |

---

## c) NOT STARTED

| ID | Task | Why | Blocked by |
|----|------|-----|------------|
| F01-F03 | Push to remote | No `git push` without user approval | User decision |
| F04-F05 | Deploy + post-deploy check | `sudo` / `nix run .#deploy` | Requires user to run |
| F06-F12 | Verify services, ioTier, reboot, registry | Post-deploy verification | Requires deploy first |
| F09 | Reboot evo-x2 | `sudo systemctl reboot` | Requires user |
| F13-F20 | PMA + browser-history upstream fixes | Both upstream repos are CLEAN — the `isNothingToCommit()` TOCTOU fix and `ClientSecret != ""` guard were never written. These need to be CODED in the respective repos first. | Upstream development |
| F25-F26 | BTRFS scrub | `sudo btrfs scrub start -B /` | Requires user + 3h wait |
| F27 | Clean dnsblockd tracking DB | `sudo` | Requires user |
| F28 | Docker prune | `sudo docker system prune` | Requires user + data review |
| F29 | SMART monitoring | `sudo smartctl` | Requires user |
| F30 | ClickHouse backup | `clickhouse-client` | Requires running service |
| F31-F32 | Twenty CRM PG role | `sudo -u postgres` | Requires user + pg_dump first |

---

## d) TOTALLY FUCKED UP

### D1: CHANGELOG entries completely missing for 11 changes

**Severity:** Medium (release hygiene)
**Impact:** Anyone reading CHANGELOG.md to understand what changed in this batch will see NOTHING. The ioTier fix entry is there, but GOMEMLIMIT additions, memory.events monitoring, dead code deletion, CI fix, VM test, ioTier conversion, pocket-id retry, dms runtimeInputs — all invisible.
**Root cause:** I treated F24 (the prior session's CHANGELOG gap) as a one-off fix instead of applying the lesson to ALL my changes.
**Fix needed:** Add a single CHANGELOG batch entry covering all 11 changes.

### D2: memory.events collector may fail silently under sandbox

**Severity:** High (monitoring blind spot)
**Impact:** If `ProtectSystem=strict` blocks reading `/sys/fs/cgroup/system.slice/*/memory.events`, the metric will silently emit 0 for all services. Gatus will see `system_service_memory_events_high{...} 0` (healthy) even during an active death-loop. This is the EXACT phantom-metric anti-pattern documented in AGENTS.md.
**Root cause:** I wrote the collection code without checking sandbox constraints.
**Fix needed:** Either add `/sys/fs/cgroup` to `ReadOnlyPaths`, or verify the existing collector already reads from `/sys/fs/cgroup` (the user-slice memory check reads `systemctl show` which goes through DBus, not direct cgroup file access).

### D3: browser-history VM test is a paper tiger

**Severity:** Medium (false confidence)
**Impact:** The test eval-passes, giving the impression it provides coverage. But it has never been RUN. It may fail at runtime for reasons invisible to eval (missing Go binary, upstream module options that don't exist, DynamicUser permission issues).
**Root cause:** I declared "test created + passing eval" as DONE without running `nix build .#checks.x86_64-linux.browser-history`.
**Fix needed:** Run the test at runtime and fix whatever breaks.

### D4: Upstream fix assumptions were wrong

**Severity:** Medium (wasted planning)
**Impact:** The Pareto plan's Tier 3 (F13-F20, "20% that delivers 80%") assumes PMA and browser-history upstream repos have uncommitted fixes. They DON'T. Both repos are clean. The `isNothingToCommit()` TOCTOU fix and `ClientSecret != ""` guard were described in the prior session's report but never implemented.
**Root cause:** Prior session described fixes as planned/done without verifying they were committed. The Pareto plan inherited the assumption.
**Fix needed:** These fixes need to be WRITTEN in the upstream repos from scratch, or the SystemNix-side mitigations (PMA cgroup limits, browser-history OIDC routing) are the actual fix and the upstream items should be dropped.

---

## e) WHAT WE SHOULD IMPROVE

### Process
1. **CHANGELOG-first discipline** — Write the CHANGELOG entry in the same edit as the code change. Not "after all changes", not "at the end". Every. Single. Change.
2. **Runtime verification for tests** — A test that only eval-passes is NOT a test. Run `nix build .#checks.x86_64-linux.<name>` before declaring done.
3. **Sandbox audit for new collectors** — Before adding a metric source, verify the collector service can actually read that path under its hardening constraints.
4. **Dead code audit should be comprehensive** — Don't check one file and stop. Grep for ALL `.sh` files in `scripts/` and verify each is referenced.
5. **Generic monitoring over specific** — The memory.events alert hardcodes PMA. Design for the general case, configure for the specific.

### Technical
6. **memory.events alert should cover all services** with MemoryMax, not just PMA. The PMA death-loop was the trigger, but the pattern is universal.
7. **CI port check should use `lib/ports.nix` as allowlist** instead of regex blacklist. The current approach will always have false positives.
8. **crush-daily MemoryMax=1G needs post-deploy validation** — the service was previously uncapped. Verify it doesn't OOM-kill during AI API calls.

---

## f) Top 50 Things to Get Done Next

> **Note:** Items below were harvested into TODO_LIST.md / ROADMAP.md where actionable. Done items are struck through.

### Critical (data safety + activation)
1. ~~`git push origin master` — unpushed changes are at risk~~ done (0 unpushed commits as of 2026-08-12)
2. `nix run .#deploy` — activate ALL changes from this + prior sessions
3. `nix run .#post-deploy-check` — verify functional outcomes
4. `nix run .#verify-io-tiers` — verify BFQ I/O tier assignments
5. Reboot evo-x2 — activates nixpkgs tarball regression fix
6. Verify `nix registry list | grep tarball` is empty after reboot
7. Verify `systemctl --failed` is empty after reboot

### This session's debt (must fix before deploy is "clean")
8. ~~Add CHANGELOG entries for ALL 11 changes made this session~~ done
9. ~~Verify memory.events collector can read `/sys/fs/cgroup/` under `ProtectSystem=strict`~~ done
10. ~~Run browser-history VM test at runtime~~ done (`nix build .#checks.x86_64-linux.browser-history`)
11. ~~Make memory.events Gatus alert generic (all monitored services, not just PMA)~~ done
12. Verify crush-daily doesn't OOM-kill with new MemoryMax=1G
13. ~~Update AGENTS.md with memory.events monitoring pattern~~ done + dms runtimeInputs gotcha

### Upstream code fixes
14. ~~Write `isNothingToCommit()` TOCTOU fix in PMA repo~~ done (already existed at `committer.go:289`) (or confirm SystemNix cgroup limits are the actual fix)
15. ~~Write `ClientSecret != ""` guard in browser-history repo~~ done (already existed at `api/oauth2.go:64`) (or confirm OIDC routing is the actual fix)
16. Commit + push + tag PMA fix (if written)
17. Commit + push + tag browser-history fix (if written)
18. Bump PMA flake input after upstream fix
19. Bump browser-history flake input after upstream fix
20. Redeploy with bumped flakes

### Data integrity
21. `sudo btrfs scrub start -B /` — root FS never scrubbed
22. `sudo btrfs scrub start -B /data` — data FS scrub
23. `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db` — orphaned tracking DB
24. Review `docker system prune -a --volumes` safety
25. `sudo smartctl -a /dev/sda` and `/dev/sdb` — external drive health
26. ClickHouse backup before next SigNoz upgrade

### Monitoring gaps
27. Add Gatus alert for crush-daily memory.events (now that it has MemoryMax)
28. Add Gatus alert for file-and-image-renamer memory.events
29. Investigate node_exporter textfile phantom metrics (14 missing metrics → 14 RED Gatus checks)
30. GOMEMLIMIT runtime validation: verify Go GC stats for 8 services after deploy
31. SigNoz dashboard v2 migration (Perses v2 schema — 6 dashboards pending)
32. ~~Add CI workflow to run browser-history VM test automatically~~ done

### Infrastructure
33. Twenty CRM PostgreSQL role fix (`CREATE ROLE twenty`)
34. Off-site backup setup (Hetzner StorageBox + BorgBackup/restic) — #1 data loss risk
35. Caddy reload root-cause (PrivateTmp workaround vs restart — revisit)
36. Pocket ID provision: add retry to POST/PUT calls (not just GET)
37. Attic cache create + Forgejo runner integration
38. Fix port-uniqueness VM test (verify it actually tests something)

### Code quality
39. Audit ALL `scripts/*.sh` for dead/unreferenced scripts (comprehensive, not one-by-one)
40. ~~Add `shellcheck .githooks/pre-commit` to CI~~ done (the hook itself is never checked)
41. Add `GOTOOLCHAIN=local` to Go devShells (if any exist — verify)
42. Verify crush-daily-backfill.py SQL against actual CREATE TABLE schema
43. Fix `test-home-manager.sh` TESTS_TOTAL inflation (20+ increment sites)
44. Convert remaining raw I/O literals to ioTier.* (audit all modules)
45. Pin file-and-image-renamer 3 inputs from `ref=master` to tags
46. PMA `GenerateMessage` handler leak audit (upstream `defer Close()`)
47. Monitor365 DuckDB pool deadlock: add connection pool size metric
48. dnsblockd CA cert deployment automation (macOS script)
49. Deploy.sh backup retention — cleanup of `.bak` files older than 3 deploys
50. Create dep-audit script for LarsArtmann Go repos

---

## g) Questions I Cannot Figure Out Myself

### Q1: Are the PMA/browser-history upstream fixes actually needed?

Both upstream repos are clean. The prior session's report describes `isNothingToCommit()` (PMA) and `ClientSecret != ""` guard (browser-history) as fixes that were "sitting in working trees uncommitted" — but the working trees are empty. The SystemNix-side mitigations (PMA cgroup limits with `MemoryHigh=6G`/`MemoryMax=8G`/`CPUQuota=200%`, browser-history OIDC env-file routing) are deployed and seem to address the symptoms. **Are the upstream code fixes still needed, or are the SystemNix-side mitigations sufficient?** This determines whether F13-F20 are real work or should be dropped from the plan.

### Q2: Should I proceed to deploy + reboot, or wait?

The changes from this session + prior sessions are accumulated but NOT deployed. The system is running stale config. Deploying activates everything (BFQ tiers, PMA limits, GOMEMLIMIT, memory.events monitoring, etc.). Rebooting activates the tarball regression fix. **Do you want me to run `nix run .#deploy` + `nix run .#post-deploy-check` now, or do you want to review the changes first?** (Note: `deploy` requires `sudo` which I cannot do autonomously in this environment.)

### Q3: Is `crush-daily` safe to cap at MemoryMax=1G?

The service previously had NO MemoryMax (uncapped). It makes AI API calls (Gemini/GLM) and writes daily reports to SQLite. I set `MemoryMax=1G` + `GOMEMLIMIT=768MiB` following the 75% rule. But I have no data on actual memory usage. **Do you know if crush-daily has ever exceeded 1G, or is 1G plenty?** If it spikes during API response buffering, the OOM-kill + restart could cause silent data loss for that day's report.
