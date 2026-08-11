# 2026-08-11 14:49 — Browser History Crash Loop → WDT Reset: Full Incident Status

## TL;DR

The system crashed (WDT reset) at ~13:26 CEST due to uncontrolled crash loops in
browser-history server + agent generating cascading memory/IO pressure. The
SystemNix-side crash-loop backoff fix is **committed and ready** but **NOT YET
DEPLOYED** — the deploy has failed 6 times due to a cascade of stale Go
`vendorHash` mismatches across 5 LarsArtmann repos. The deploy is **one build
away** from succeeding.

---

## a) FULLY DONE

1. **Root-caused the WDT crash** — Uncontrolled crash loops in browser-history
   server (`Error: server.create_user_service`, restart counter 160+) and agent
   (72 failures, each reading 19,700 browser entries from SQLite). Memory
   pressure hit 95% (Monitor365 buffer warnings, journald cache flushes). Kernel
   froze → sp5100-tco WDT reset. Same pattern as 2026-08-09 PMA crash.

2. **SystemNix browser-history.nix crash-loop backoff** — Committed in
   `a1223f22`. Server: `RestartSec=2min`, `StartLimitBurst=3`,
   `StartLimitIntervalSec=600s`. Agent: `RestartSec=5min`,
   `StartLimitBurst=2`, `StartLimitIntervalSec=1800s`. Added `LOG_LEVEL=debug`.

3. **Pre-deploy-check phantom metric allowlist** — Committed in `a1223f22`.
   Added `niri_running` and `system_memory_events_any_high` to
   `KNOWN_NEW_METRICS` (both absent immediately after reboot, appear within
   minutes).

4. **Upstream debug logging added** — `cmd/browser-history-server/main.go` in
   `/home/lars/projects/browser-history` now logs `logger.Error("server startup
   failed", "err", err, "errType", fmt.Sprintf("%T", err), "cause",
   errors.Unwrap(err))` before `HandleError`. This reveals the hidden `.Cause()`
   chain that `errorfamily.HandleError`'s CLI renderer suppresses. **Not yet
   committed/pushed** (go.work broken locally, can't build to verify).

5. **5 stale vendorHash fixes pushed** across LarsArtmann repos:
   - `go-cqrs-lite` — `ee335502` (cqrs-lint vendorHash)
   - `erraudit` (aka hierarchical-errors) — `5ab1994`
   - `DiscordSync` — `c432b20c`
   - `golangci-lint-auto-configure` — `a30a465`
   - `project-meta` — `01e212f`

6. **All 5 flake inputs updated** in SystemNix `flake.lock` to the fixed
   commits.

7. **Initial status report written** — `docs/status/2026-08-11_14-12_browser-history-crash-loop-wdt.md`

---

## b) PARTIALLY DONE

1. **Deploy** — 6 attempts. First 5 failed on stale vendorHash mismatches
   (cqrs-lint → erraudit → DiscordSync → golangci-lint-auto-configure +
   project-meta). 6th attempt failed because golangci-lint-auto-configure has a
   deeper build issue (incomplete vendoring with local deps — `GOPROXY=off`
   during build phase, `_local_deps/gogenfilter` not vendored). Workaround:
   temporarily disabled in `lib/lars-packages.nix` (uncommitted). 6th deploy was
   retrying when interrupted.

2. **Upstream browser-history root cause** — Identified that
   `usermgmt.NewService()` → `NewEventSourcedSetup()` → `startProjectionHost()`
   fails during projection journal replay. The cqrs-htmx v4.7.2 bump (commit
   `c63f118`, Aug 10) likely changed projection error handling. The error
   renderer hides the actual cause. Debug logging added locally but not
   committed.

3. **golangci-lint-auto-configure** — vendorHash fixed but build still fails
   (GOPROXY=off + missing local dep vendoring). Needs upstream investigation.
   Temporarily disabled in lars-packages.nix to unblock deploy.

---

## c) NOT STARTED

1. **System-wide crash-loop circuit breaker** — A generic mechanism to prevent
   ANY single service crash loop from freezing the kernel. Current approach is
   per-service manual backoff. Need either: systemd-global rate limiting, a
   system-health watchdog that detects crash loops and force-stops them, or
   cgroup-level memory pressure protection.

2. **AGENTS.md update** — No gotcha/incident entry added yet for this crash.

3. **Post-deploy verification** — Can't verify what we haven't deployed.

4. **Browser-history server bug fix** — Root cause inside cqrs-htmx v4.7.2
   projection replay not identified. Need the debug log output from a running
   server to see the actual error cause.

5. **Browser-history `go.work` repair** — Local workspace references a broken
   cqrs-htmx checkout. Can't build locally to test the debug logging change.

---

## d) TOTALLY FUCKED UP

1. **Whack-a-mole deploy strategy** — Fixed vendorHashes one at a time across 5
   repos, each requiring a separate deploy attempt. Should have batch-checked
   ALL packages first (`nix build .#pkg` for each in `lars-packages.nix`) before
   attempting the first deploy. Did this on attempt 5 but only after 4 failed
   deploys wasted ~15 minutes of build time.

2. **golangci-lint-auto-configure vendorHash** — Updated the hash but the build
   was actually broken for a different reason (incomplete local dep vendoring).
   The new hash passed the FOD check but the build phase failed. Should have
   done `nix build .#golangci-lint-auto-configure` BEFORE pushing and updating
   the flake input.

3. **Browser-history upstream edit not buildable** — Added `errors` and `fmt`
   imports + `logger.Error` call to `main.go` but can't verify it compiles
   (go.work broken). The edit sits in the working tree uncommitted. If it
   doesn't compile, it'll block the next browser-history deploy.

4. **Didn't revert the `lars-packages.nix` disable** — The
   `golangci-lint-auto-configure` disable is uncommitted in the working tree.
   It was a temporary measure to unblock deploy but was never cleaned up.

---

## e) WHAT WE SHOULD IMPROVE

1. **Batch vendorHash validation** — Before ANY deploy, run
   `nix build .#<pkg>` for every package in `lars-packages.nix`. This catches
   ALL stale vendorHashes in ~2 min instead of discovering them one at a time
   during full system builds that take 5+ min each.

2. **CI on LarsArtmann repos should validate vendorHash** — When a Go dependency
   shifts (e.g. cqrs-htmx publishes a new tag), all downstream repos' vendorHashes
   go stale simultaneously. Each repo's CI should have a daily check that
   `nix build` succeeds, catching this before it reaches SystemNix.

3. **System-wide crash-loop protection** — The per-service manual backoff
   approach doesn't scale. The system needs a GENERIC crash-loop circuit breaker:
   a systemd timer or system-health check that detects services in
   `start-limit-hit` or rapid-restart state and force-stops them (or throttles
   them further) before they generate enough IO pressure to freeze the kernel.

4. **errorfamily.HandleError should log the cause chain** — The CLI renderer
   intentionally hides the technical cause for user-friendliness, but this makes
   debugging impossible. It should log the full cause chain at `debug` or `error`
   level before rendering the CLI message.

5. **Go workspace (go.work) hygiene** — The browser-history repo's go.work points
   to a broken local cqrs-htmx checkout. This prevented local builds and forced
   all debugging through nix builds (which are slow). The workspace should either
   be repaired or removed (rely on published deps).

6. **Deploy should auto-fix stale vendorHashes** — When a vendorHash mismatch
   fails the build, the deploy script could offer to automatically set
   `vendorHash = ""`, rebuild, capture the `got:` hash, and update the source.
   This is a well-known Nix workflow.

7. **Consider `nixpkgs-review` or `nix flake check --all-systems`** before
   deploys to catch more issues upfront.

---

## f) NEXT TASKS (up to 50)

### Critical (block deploy)
1. Finish deploy attempt 6 (was interrupted mid-build)
2. If deploy fails on another stale vendorHash, fix it and retry
3. Verify browser-history server and agent are NOT crash-looping after deploy
4. Verify the `LOG_LEVEL=debug` output appears in journalctl

### High priority (fix the actual bug)
5. Read the debug log output from browser-history server to identify the real
   error cause behind `server.create_user_service`
6. Fix the upstream browser-history/cqrs-htmx projection replay bug
7. Build and push the browser-history debug logging change (repair go.work first)
8. Bump browser-history flake input after the fix
9. Re-deploy with the upstream fix
10. Remove `LOG_LEVEL=debug` once the bug is fixed (or keep it — it's useful)

### SystemNix hardening
11. Add a system-wide crash-loop circuit breaker (systemd or system-health module)
12. Add Gatus alert for any service with `system_service_nrestarts` > 10 in 1h
13. Add Gatus alert for `system_service_start_limit_hit` on any service
14. Update AGENTS.md with this incident (gotcha table + non-obvious gotchas section)
15. Revert the temporary `golangci-lint-auto-configure` disable in lars-packages.nix
16. Fix golangci-lint-auto-configure upstream (local dep vendoring issue)
17. Re-enable golangci-lint-auto-configure after fix
18. Add a `nix build .#<each-pkg>` pre-deploy check for all lars-packages
19. Add BTRFS emergency reserve check to post-deploy (verify file exists)

### Upstream repos
20. Fix browser-history `go.work` (broken cqrs-htmx local replace)
21. Add errorfamily feature request: log cause chain before CLI render
22. Add CI check to each LarsArtmann Go repo: daily `nix build` vendorHash validation
23. Consider `vendorHash = lib.fakeHash` pattern for faster iteration

### Monitoring
24. Add Monitor365 buffer pressure to post-deploy check
25. Add PSI memory pressure trend to Gatus (not just threshold)
26. Add system-wide restart-rate metric (total restarts/min across all services)
27. Add Gatus alert for total system restart rate > 20/min

### Documentation
28. Write `docs/gotchas-archive.md` entry for this crash (full narrative)
29. Update `docs/crash-analysis-2026-08-09.md` with cross-reference to this crash
30. Update FEATURES.md if any feature status changed
31. Add `docs/vendorHash-batch-fix-procedure.md` runbook

### Technical debt
32. Clean up stale `flake.lock` entries (inputs no longer used)
33. Audit all LarsArtmann Go repos for stale vendorHashes (one-time batch fix)
34. Consider Attic cache for LarsArtmann Go package builds
35. Add `nix flake check` to pre-commit hook if not already present

### Lower priority
36. Consider systemd `RestartPreventExitStatus=69` for browser-history (exit 69 = UNAVAILABLE)
37. Add browser-history integration test (start server, verify no crash)
38. Add cqrs-htmx projection replay test for unknown event types
39. Consider MemoryMax increase for browser-history server (currently 384MiB GOMEMLIMIT)
40. Review all services with `RestartSec < 30s` for crash-loop risk
41. Add system-health metric for total cgroup memory pressure events
42. Consider `systemd.oomd` configuration for proactive memory management
43. Review zram swap config (15GiB swap, only 3.7MiB used — may need tuning)
44. Add Gatus endpoint for browser-history once the server is stable
45. Consider disabling browser-history-agent on evo-x2 (co-located with server)
46. Add deploy notification to Discord (success/failure)
47. Add pre-deploy disk space check (NVMe QLC SLC cache health)
48. Consider `nh os switch --dry-run` step before actual deploy
49. Review all `Type=oneshot` services for crash-loop risk
50. Add `docs/deploy-troubleshooting.md` runbook

---

## g) QUESTIONS (cannot figure out myself)

1. **Should I disable browser-history entirely (both server + agent) until the
   upstream cqrs-htmx projection bug is fixed?** The crash-loop backoff will
   prevent WDT resets, but the service will still be non-functional (crashing
   every 2 min). Disabling it entirely eliminates all risk but loses browser
   history sync until the bug is fixed.

2. **Is there a known issue with cqrs-htmx v4.7.2 and shared SQLite event
   stores?** The browser-history server uses a single SQLite DB as the event
   store for BOTH visit events AND user management events. The usermgmt
   projection replay processes ALL events in the journal, including visit events
   it doesn't understand. Was this tested in cqrs-htmx, or should browser-history
   use separate event stores?

3. **The auto-git daemon committed my browser-history.nix changes before I was
   done (commit `a1223f22`). Should I worry about the `lib/lars-packages.nix`
   disable of golangci-lint-auto-configure being committed too, or will the
   daemon leave uncommitted working tree changes alone?** The disable is a
   temporary workaround that should be reverted once the upstream build issue is
   fixed.
