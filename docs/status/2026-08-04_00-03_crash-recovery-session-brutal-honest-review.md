# Crash Recovery Session — Brutal Honest Review

**Date:** 2026-08-04 00:03  
**Session start:** 2026-08-03 ~22:20 (previous session)  
**Trigger:** System crashed at 22:03 Aug 3 from WDT reset (memory exhaustion)  
**Root cause (found in previous session):** `builtins.toString null` → `""` made user-1000.slice memory cap silently vanish

---

## Executive Summary

**NOTHING IS DEPLOYED. The system is still vulnerable to the same crash.** The entire session was spent chasing an endless cascade of upstream Go build failures. The critical fix (`boot.nix` user-1000 slice hardcoding) has been committed for over 90 minutes but cannot deploy because the full system build keeps breaking on different Go packages.

This is a failure of prioritization. The most critical fix (memory cap) should have been deployed first, potentially with a minimal build or even a manual `systemctl set-property` hotfix, while the upstream issues were resolved in parallel.

---

## a) FULLY DONE

1. **BTRFS snapshot inventory** — Found 3 root snapshots: `@.20260801T2300`, `@.20260802T2300`, `@.20260803T2300`. The Aug 2 snapshot is the safest pre-crash checkpoint.
2. **Data damage assessment** — Verified ALL readable databases (dnsblockd, signoz, crush-daily, colord, qmd, crush) pass `PRAGMA integrity_check`. Only DiscordSync DB is corrupt (can't access without root — owned by `discordsync` user).
3. **Key discovery: destructive v1 script was NEVER deployed or run** — The live ExecStartPre only has `wait-dns`. The DiscordSync DB is corrupt from the crash, NOT deleted by any script. BTRFS snapshots contain a healthy pre-crash copy.
4. **Enhanced dbHeal script with BTRFS snapshot recovery** — Recovery cascade now: `integrity_check` → `sqlite3 .recover` → **BTRFS snapshot CoW clone** (newest healthy snapshot) → fresh DB. Uses `cp --reflink=always` for zero-space instant clone. Committed in `2ab71ac4`.
5. **monitor365 upstream fix** — Stripped `[lints] workspace = true` from vendored `libspa-sys/Cargo.toml` and `pipewire-sys/Cargo.toml` (regression — was previously fixed in `d125048de` but regenerated vendor patches reintroduced it). Pushed as `e64fba72d`.
6. **cqrs-lint upstream fixes (5 commits across go-cqrs-lite):**
   - `7d33173e` — Seeded go.sum with published go-finding v1.4.1 hashes
   - `4f713ccd` — Restored v1.4.1 version (was zero pseudo-version from `b9ba2814` go.sum refresh)
   - `0b470f11` — Synced go.mod and go.sum with flake input versions (go-output/escape v0.35.0 → v0.36.0, removed unused golang.org/x/exp)
   - `b6247b80` — Resolved all 18 golangci-lint issues (auto-commit daemon)
   - Multiple vendorHash updates
7. **Shellcheck fix** — Changed `ls -1d` to `find -maxdepth 1` in dbHeal script (SC2012)

---

## b) PARTIALLY DONE

1. **Full system build** — cqrs-lint builds successfully. monitor365 libspa-sys fixed. But **buildflow** (another go-cqrs-lite package) now has a vendorHash mismatch. The build cascade keeps revealing the next broken hash.
2. **DiscordSync DB recovery** — The dbHeal script is written and committed but NOT deployed. The live DB is corrupt and in `start-limit-hit`. BTRFS snapshots have a healthy copy but recovery requires either (a) deploying the dbHeal script, or (b) manual root intervention.
3. **flake.lock updates** — monitor365 and go-cqrs-lite inputs updated to latest commits. But each update sometimes changes vendorHash again, creating a cycle.

---

## c) NOT STARTED

1. ~~**Deploy** — `nix run .#deploy` has not been attempted this session (it was attempted 3x in the previous session, all failed).~~ done at `4372f51d` (deployed Aug 4)
2. ~~**Verify memory cap is live** — `/sys/fs/cgroup/user.slice/user-1000.slice/memory.max` currently shows `max` (unlimited). Needs to show `68719476736` (64G).~~ done at `4372f51d`
3. ~~**Post-deploy smoke test** — Not run because nothing deployed.~~ done at `4372f51d`
4. ~~**Manual DiscordSync DB recovery** — Could be done NOW via root: `sqlite3 .recover` from the corrupt DB, or `cp --reflink=always` from the BTRFS snapshot.~~ done at `4372f51d` (db-heal auto-recovery deployed)
5. ~~**AGENTS.md documentation** — The BTRFS snapshot recovery cascade and the cqrs-lint go.sum/mkPreparedSource interplay are NOT documented yet.~~ done (documented in AGENTS.md gotchas)
6. **system.slice memory cap** — No MemoryMax on system.slice exists. Only per-service limits + the (broken) user slice cap. A system-wide cap could prevent future cascades.

---

## d) TOTALLY FUCKED UP

1. **Spent the ENTIRE session on build failures instead of deploying the critical fix.** The user-1000.slice memory cap is a 1-line fix in `boot.nix`. It could have been applied as a manual `systemctl set-property user-1000.slice MemoryMax=64G MemoryHigh=56G` hotfix IMMEDIATELY, making the system safe while upstream build issues were resolved. I never considered this.

2. **Chased build failures one at a time instead of batch-testing.** The AGENTS.md already documents: "before a full system build, batch-test individual Go packages: `nix build .#crush-daily .#library-policy .#cqrs-lint ...`". I ignored this advice and kept hitting them serially in the full system build.

3. **Auto-commit daemon races wasted multiple cycles.** Pushed commits, BuildFlow pre-commit took 30-150s, daemon pushed new commits during that window, `git push` failed with "cannot lock ref HEAD". Had to rebase/retry multiple times. Should have used `--no-verify` or pushed with `GIT_CONFIG_GLOBAL=/dev/null` to skip hooks.

4. **Didn't ask the user to run sudo commands.** I'm blocked from `sudo`/`systemctl`. The user could have:
   - Manually set the memory cap via `systemctl set-property`
   - Manually recovered the DiscordSync DB
   - Manually checked the BTRFS snapshot DB integrity
   I never asked.

5. **Previous session's v1 DB recovery script was destructive.** While it was never deployed, the fact that it was written and committed (`7191c79e`) — deleting the corrupt DB as first resort instead of attempting recovery — is a data safety failure. The user correctly called this out.

---

## e) WHAT WE SHOULD IMPROVE

1. **Deploy critical fixes FIRST, resolve build issues in parallel.** A 1-line memory cap fix should not wait behind a multi-hour upstream Go build cascade.
2. **Use `systemctl set-property` as an immediate hotfix** for cgroup memory limits — doesn't require a rebuild.
3. **Batch-test all Go packages before attempting a full system build** — already documented in AGENTS.md but not followed.
4. **Ask the user to run sudo/systemctl commands earlier** when blocked by tool restrictions.
5. **Consider a Nix-level overlay or patch** for upstream build issues instead of fixing upstream repos — faster iteration, no push race.
6. **The `mkPreparedSource` + zero pseudo-version pattern is a recurring trap.** Every go.sum refresh normalizes versions to `v0.0.0-00010101000000-000000000000`, which breaks Nix builds. This needs a permanent fix (either in mkPreparedSource or a pre-commit guard).
7. **Auto-commit daemon + BuildFlow pre-commit = push race.** Need `git push --no-verify` for rapid iteration or disable BuildFlow for operational commits.
8. **BTRFS snapshot recovery should be a general pattern**, not just DiscordSync-specific. Any SQLite-using service could benefit.
9. **system.slice needs a memory cap.** The user slice was supposed to be capped at 64G but wasn't. Even with the fix, there's no system-wide safety net for system services collectively consuming all RAM.

---

## f) Up to 50 Things to Get Done Next

### Critical (BLOCKING — system is unsafe)
1. ~~Fix buildflow vendorHash mismatch (last build blocker)~~ done at `4372f51d` (resolved Aug 4)
2. ~~Build the full system: `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`~~ done at `4372f51d`
3. ~~Deploy: `nix run .#deploy`~~ done at `4372f51d` (deployed Aug 4)
4. ~~Verify memory cap: `cat /sys/fs/cgroup/user.slice/user-1000.slice/memory.max` must show `68719476736`~~ done at `4372f51d`
5. ~~Verify DiscordSync dbHeal runs: `journalctl -u discordsync -f`~~ done at `4372f51d` (db-heal active)
6. ~~Run post-deploy smoke test~~ done at `4372f51d`

### Immediate Hotfix (can do NOW, no build needed)
7. Ask user to run: `sudo systemctl set-property user-1000.slice MemoryMax=64G MemoryHigh=56G` — immediate protection
8. Ask user to manually recover DiscordSync DB from BTRFS snapshot: `sudo cp --reflink=always /mnt/btrfs-root/.snapshots/@.20260802T2300/var/lib/discordsync/discordsync.db /var/lib/discordsync/discordsync.db`
9. Ask user to verify snapshot DB integrity: `sudo sqlite3 /mnt/btrfs-root/.snapshots/@.20260802T2300/var/lib/discordsync/discordsync.db "PRAGMA integrity_check;"`
10. Ask user to reset DiscordSync start-limit: `sudo systemctl reset-failed discordsync && sudo systemctl start discordsync`

### Build Resilience
11. Batch-test ALL Go packages: `nix build .#cqrs-lint .#buildflow .#crush-daily .#library-policy .#monitor365-server`
12. Add a CI check that catches vendorHash drift before full system build
13. Add pre-commit guard in go-cqrs-lite: reject zero pseudo-versions in go.mod
14. Consider `--no-verify` or `GIT_CONFIG_KEY_0=core.hooksPath` for operational pushes during crash recovery
15. Document the mkPreparedSource + zero pseudo-version trap in go-cqrs-lite AGENTS.md

### Data Safety
16. Verify Docker containerd bbolt DB health (known crash corruption risk, needs root)
17. Verify monitor365 DuckDB health (needs root — `.wal` file presence indicates unclean shutdown)
18. Check if any user data in `/home/lars` was lost or corrupted by the crash
19. Verify Immich database health (PostgreSQL in Docker, needs root)
20. Check ClickHouse (SigNoz) for corruption after crash
21. Verify Pocket ID database health
22. Check Forgejo Gitea database health
23. Run `btrfs scrub status /` to check for filesystem-level corruption from the crash

### Monitoring & Prevention
24. Add Gatus alert for `user-1000.slice` memory.max == max (detect silent cap removal)
25. Add eval-time assertion in boot.nix: `assert config.users.users.lars.uid != null` (fail-fast instead of silent `""`)
26. Add system.slice MemoryMax (e.g., 80G) as defense-in-depth
27. Consider adding ` systemd.oomd.SystemSwapUsedLimit` for system-wide OOM protection
28. Add Gatus alert when any service is in `start-limit-hit` state for >5 min
29. Monitor BTRFS snapshot freshness after crash (ensure btrbk resumes)
30. Add a pre-deploy check that verifies the deployed generation matches `nix eval` output

### Documentation
31. Document BTRFS snapshot recovery cascade pattern in AGENTS.md
32. Document cqrs-lint mkPreparedSource + go.sum interplay
33. Document the `builtins.toString null` → `""` Nix anti-pattern as a general gotcha
34. Update the existing WDT crash status reports with current deployment status
35. Document that auto-commit daemon races with BuildFlow pre-commit hooks

### DiscordSync Hardening
36. Consider adding `RestartSec=30` to DiscordSync to reduce crash-loop CPU burn
37. Add a Gatus alert specifically for DiscordSync DB corruption (check log for "pager.rs" panic)
38. Consider periodic SQLite integrity_check cron for all service databases
39. Document the Turso sync pager corruption pattern and recovery procedure

### System Resilience
40. Review ALL systemd slices for missing memory caps (not just user-1000)
41. Check if `systemd-oomd` config needs tuning after the crash (PSI thresholds)
42. Verify the hardware watchdog (sp5100-tco) timeout is appropriate (currently 60s)
43. Consider adding `kernel.panic_on_oops=1` to prevent silent kernel issues from cascading
44. Review MGLRU settings (`min_ttl_ms`) — may need tuning after crash analysis
45. Check if zram swap configuration needs adjustment (was 100% full during crash)

### Process Improvements
46. Create a "crash recovery runbook" with prioritized steps for future WDT resets
47. Add a `nix run .#emergency-memory-cap` script that applies the hotfix without rebuild
48. Consider a read-only "golden generation" that's known-good for emergency rollback
49. Add monitoring for deployed-vs-evaluated generation mismatch
50. Review whether the auto-commit daemon should pause during active deploy sessions

---

## g) Questions I CANNOT Answer Myself

1. **Can you run `sudo systemctl set-property user-1000.slice MemoryMax=64G MemoryHigh=56G` right now?** This is an immediate hotfix that doesn't require a rebuild. The system is currently running with NO user memory cap — the same condition that caused the crash. This should have been done 90 minutes ago.

2. **Can you manually recover the DiscordSync DB from the BTRFS snapshot?** The Aug 2 23:00 snapshot at `/mnt/btrfs-root/.snapshots/@.20260802T2300/var/lib/discordsync/` likely has a healthy copy. Commands: verify integrity → CoW clone → reset failed state → start service. I can't run these because I'm blocked from `sudo`.

3. **Should I temporarily skip the buildflow/cqrs-lint packages to deploy the critical boot.nix fix faster?** If we can build with `--option build-check` or temporarily disable non-critical packages, the memory cap fix could deploy immediately while the Go build issues are resolved separately. The alternative is continuing to chase the vendorHash cascade, which has already consumed the entire session.

---

## Timeline

| Time | Event |
|------|-------|
| 22:03 | System crashed (WDT reset from memory exhaustion) |
| ~22:20 | Previous session: root cause found, boot.nix fix committed |
| ~22:30 | Previous session: v1 destructive DB recovery committed |
| ~22:33 | Previous session: AGENTS.md docs committed |
| ~22:40-22:52 | Previous session: flake inputs updated, 3 deploy attempts failed |
| **This session starts** | |
| ~23:15 | BTRFS snapshot inventory completed |
| ~23:20 | All readable databases verified healthy |
| ~23:25 | Key discovery: v1 script never deployed, DB is corrupt NOT deleted |
| ~23:30 | Enhanced dbHeal with BTRFS snapshot recovery committed |
| ~23:30 | Shellcheck SC2012 fix (ls → find) |
| ~23:33 | monitor365 libspa-sys [lints] fix pushed upstream |
| ~23:35 | cqrs-lint vendorHash mismatch #1 |
| ~23:40 | cqrs-lint go.sum seeded with go-finding v1.4.1 |
| ~23:45 | cqrs-lint zero pseudo-version fix |
| ~23:50 | cqrs-lint go-output/escape version sync |
| ~23:55 | cqrs-lint vendorHash mismatch #2 |
| ~00:00 | cqrs-lint finally builds; buildflow vendorHash mismatch revealed |
| **00:03** | **Status report written. NOTHING DEPLOYED.** |

---

## Live System State (as of 00:03)

| Check | Value | Status |
|-------|-------|--------|
| `user-1000.slice memory.max` | `max` | **BROKEN — same as crash condition** |
| Deployed generation | `...20260801.148bab9` | **STALE — from Aug 1** |
| Evaluated generation | `...20260802.6438090` | **MISMATCH — never deployed** |
| DiscordSync | `start-limit-hit` | **DOWN — corrupt DB** |
| monitor365 libspa-sys | Fixed upstream | **NOT DEPLOYED** |
| cqrs-lint go.sum | Fixed upstream | **NOT DEPLOYED** |
| buildflow vendorHash | **MISMATCH** | **BLOCKING** |

**The system that crashed is functionally identical to the system running now.** The fix exists in source but has not reached the running system.
