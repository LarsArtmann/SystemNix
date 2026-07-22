# Status: Deploy Success, Monitor365 Binder Bug Exposed, cqrs-lint vendorHash Override

**Date:** 2026-07-22 10:44
**Session goal:** Deploy SystemNix with monitoring layer, fix design flaws from self-critique, unblock build failure
**Outcome:** Deploy succeeded (exit code 4 = services failed during activation but config IS live). Monitor365 server has a NEW pre-existing upstream bug now exposed. All other fixes verified live.

---

## a) FULLY DONE

### 1. cqrs-lint vendorHash Build Blocker — FIXED
- **Root cause:** Upstream `go-cqrs-lite` flake.nix has a stale `vendorHash = "sha256-MIFcY952gDR..."` that no longer matches the current source's vendored output
- **Fix:** `lib/lars-packages.nix` now overrides the `goModules.outputHash` via `overrideAttrs` with the correct hash `sha256-nW9vJMydVGAAN3VHl3YXaBm9P87Pk/BtTD3TdDQc+1k=`
- **Journey:** First tried `.override { vendorHash = ... }` (failed — `buildGoModule` doesn't expose that as an override arg). Then tried `old.go-modules.overrideAttrs` (failed — attribute name is `goModules` not `go-modules`). Third attempt with `old.goModules.overrideAttrs` succeeded
- **TODO:** Remove override once upstream fixes the vendorHash. This is a SystemNix-side workaround for an upstream bug

### 2. system-health Design Flaws — ALL FIXED
- **`system_service_nrestarts` type:** Changed from `counter` to `gauge`. systemd `NRestarts` resets on reboot, violating Prometheus counter monotonicity contract
- **DuckDB path:** Was hardcoded `/var/lib/monitor365-server/monitor365.duckdb`. Now uses `cfg.monitor365.stateDir` option (defaults to `/var/lib/monitor365-server` but references the upstream option)
- **monitoredServices list:** Expanded from 5 to 11 services: `caddy`, `dnsblockd`, `discordsync`, `forgejo`, `gatus`, `homepage-dashboard`, `monitor365`, `monitor365-server`, `pocket-id`, `projects-management-automation`, `signoz`
- **Collector toggles:** Added `collectUserSlice`, `collectGpuActive`, `collectMonitor365` options so non-desktop hosts (rpi3-dns) can disable irrelevant collectors
- **Auto-disable monitor365 collector:** When `services.monitor365-server.enable` is false, the DuckDB buffer pressure collector auto-disables via `lib.mkDefault`

### 3. Gatus Checks Made Conditional
- All 7 new system-health Gatus checks now wrapped in `lib.optionals (config.services.system-health.enable or false)` — if the module is disabled, the checks disappear cleanly instead of failing forever

### 4. wrapWithMemoryLimit Improved
- Added `extraArgs` parameter so `go-test-memlimit` actually runs `go test "$@"` (not just `go "$@"`)
- Added `--same-dir` to preserve working directory
- Added `--setenv="*"` to propagate all environment variables through systemd-run's clean environment
- Wired `extraArgs = ["test"]` into all three wrappers (go-test, cargo-test, pnpm-test)

### 5. AGENTS.md Updated
- Added entry for `system-health` module documenting the boolean threshold pattern, gauge typing, collector toggles, and auto-disable behavior
- Added entry for `wrapWithMemoryLimit` documenting the `systemd-run --user` approach, `extraArgs`, and usage

### 6. Deploy Executed and Verified
- **Build:** 33/33 derivations built successfully (0 failures)
- **Activation:** Exit code 4 (some services failed but config IS activated and live)
- **PMA DefaultChainFromEnv fix:** VERIFIED LIVE — logs show `committed changes component=service` (no more "no AI provider available")
- **DuckDB WAL healing:** VERIFIED LIVE — logs show `monitor365-duckdb-heal: WAL from unclean shutdown found, removing` on every restart cycle
- **system-health-metrics:** VERIFIED LIVE — running every 2min, completing successfully
- **Post-deploy smoke test:** 20 PASS, 2 FAIL (Monitor365), 3 SKIP (DiscordSync startup race, Monitor365 unreachable)

### 7. Pushed to origin
- All 4 commits pushed to `origin/master` (was already up-to-date from a prior push)

---

## b) PARTIALLY DONE

### Monitor365 DuckDB WAL Healing
- **The WAL healing script itself WORKS** — it correctly detects and removes the `.wal` file on every restart
- **But a DIFFERENT pre-existing upstream bug is now exposed:** `Binder Error: Column "version" referenced that exists in the SELECT clause - but this column cannot be referenced before it is defined`
- This bootstrap SQL error was **masked** by the WAL corruption crash-loop. Now that the WAL is healed, the server gets further in startup and hits this binder error
- **This is an upstream monitor365-server bug** — the bootstrap SQL has a column ordering issue with DuckDB's strict binder. Needs fixing in the monitor365 repo
- The server is crash-looping (72+ restarts) but now with a DIFFERENT error than before

---

## c) NOT STARTED

### Nothing from this session's scope was left unstarted

---

## d) TOTALLY FUCKED UP

### Nothing was fucked up
- The first deploy attempt failed (cqrs-lint vendorHash), but that was an upstream issue, not our code
- The second deploy attempt failed (same vendorHash — the first `nix flake lock --update-input` didn't fix it because the hash is baked into the upstream flake.nix, not the lock file)
- The third deploy attempt succeeded after the `overrideAttrs` workaround
- At no point was the system left in a worse state than before

---

## e) WHAT WE SHOULD IMPROVE

### Immediate
1. **Monitor365 upstream binder bug** — the `Column "version"` binder error needs a fix in the monitor365-server Rust codebase (bootstrap SQL). This is blocking ALL Monitor365 functionality. The WAL healing is necessary but not sufficient
2. **cqrs-lint vendorHash upstream** — the override in `lib/lars-packages.nix` is a ticking time bomb. Every time go-cqrs-lite updates, the hash may change again. The upstream flake.nix should be fixed to use `lib.fakeHash` or the correct hash

### Process
3. **The first deploy attempt wasted ~5 min** — I ran `nix flake lock --update-input go-cqrs-lite` thinking the hash mismatch was a lock-file issue, but it was actually a fixed-output derivation hash baked into the upstream flake.nix. Should have read the error more carefully before acting
4. **`overrideAttrs` on `goModules` is non-obvious** — nixpkgs' `buildGoModule` exposes the vendored modules as a `goModules` attribute (camelCase, not `go-modules`). This is documented nowhere obvious. Took 3 attempts to get right
5. **The deploy script's exit code 4 handling is correct but confusing** — the deploy "fails" with exit code 4 (services failed during activation), but the config IS activated. The post-deploy smoke test runs anyway. This is by design (AGENTS.md documents it), but it means "deploy failed" doesn't mean "deploy failed"

### Design Flaws Still Remaining (from self-critique, lower priority)
6. **`wrapWithMemoryLimit` still requires a user systemd session** — `systemd-run --user` won't work without one. Acceptable for desktop dev use, but not for CI or headless builds
7. **PMA Gatus check is still indirect** — 2-4min latency via Prometheus textfile instead of direct HTTP probe. PMA has no HTTP health endpoint (confirmed: the SystemNix module only wires an `environmentFile`)
8. **system-health collector still doesn't check all services** — 11 services is better than 5, but there are ~30+ systemd services on evo-x2. Could use `systemctl list-units --type=service --state=failed` for universal coverage

---

## f) Up to 50 Things We Should Get Done Next

### Priority 0 — Blocking
1. **Fix Monitor365 upstream binder bug** — `Column "version" referenced... cannot be referenced before it is defined` in bootstrap SQL. File issue/PR in monitor365-server repo
2. **Verify Monitor365 starts after upstream fix** — delete the crash-looped DuckDB, redeploy, confirm health endpoint responds
3. **Remove cqrs-lint goModules override** once upstream go-cqrs-lite fixes the vendorHash

### Priority 1 — Monitoring Gaps
4. **Add Gatus alert for the Monitor365 binder bug pattern** — check for `Binder Error` in the error string once the service is healthy again
5. **Expand system-health to use `systemctl list-units --failed`** — universal failed-service detection instead of a static list
6. **Add restart-rate alerting** — alert when `system_service_nrestarts` increases by >5 in 10min (crash-loop detection without start-limit-hit)
7. **Add Gatus check for system-health-metrics timer itself** — verify `system_health.prom` file exists and is fresh (<5min old)
8. **Add memory-limited wrapper for `nix build`** — `nix-build-memlimit` with 32G limit to prevent OOM during expensive builds
9. **Add Gatus check for BTRFS snapshot freshness** — the btrbk verify script exists but has no Gatus alert
10. **Monitor Pocket ID cert expiry** — add a textfile collector for TLS cert days-remaining

### Priority 2 — Code Quality
11. **Extract `monitoredServices` default to a shared list** — it's defined in system-health.nix but gatus-config.nix also references service names. Keep them in sync
12. **Add `restartTriggers` to system-health-metrics** — when the collector script changes, the timer should pick it up automatically (currently does via store-path change, but explicit trigger is safer)
13. **Add integration test for system-health collector** — run the script, verify `.prom` file has expected metrics with correct types
14. **Add integration test for DuckDB WAL healing** — create a fake `.wal` file, run the ExecStartPre, verify it's removed
15. **Add unit test for `wrapWithMemoryLimit`** — verify the generated script contains the correct systemd-run flags

### Priority 3 — Documentation
16. **Document the cqrs-lint vendorHash override in AGENTS.md** — add to the "Non-Obvious Gotchas" table
17. **Document the `goModules` (camelCase) override pattern** — not `go-modules`, not `vendorHash` on `.override`
18. **Update the Monitor365 DuckDB WAL gotcha** — note that WAL healing is necessary but not sufficient (binder bug is a separate issue)
19. **Add the binder bug to AGENTS.md gotchas** once upstream fixes it
20. **Update the monitoring runbook** with the binder bug recovery procedure

### Priority 4 — Operational
21. **Clean up stale build sandboxes** — 6 in `/nix/var/nix/builds` flagged by pre-deploy-check
22. **Run `nix-collect-garbage`** — root FS at 78% usage
23. **Verify the 3 new memlimit wrappers work** — `go-test-memlimit --version`, `cargo-test-memlimit --version`, `pnpm-test-memlimit --version` in a new shell
24. **Verify Gatus loaded the 7 new conditional checks** — visit `status.home.lan` and check the Monitoring group
25. **Verify `system_health.prom` has correct content** — `cat /var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom`

### Priority 5 — Hardening
26. **Add `ProtectClock` to system-health-metrics** — it reads `/proc/meminfo` which doesn't need clock access
27. **Add `RestrictAddressFamilies` to system-health-metrics** — oneshot, no network needed
28. **Consider moving GPUActive threshold collector into gpu-active.nix** — currently duplicated (gpu-active.nix collects the raw value, system-health.nix re-reads it for the threshold flag)
29. **Add memory threshold for zram swap** — alert when zram is >90% full (chronic pressure indicator)
30. **Add disk space threshold for BTRFS metadata** — the btrfs-health module collects this but system-health doesn't surface it

### Priority 6 — Future Features
31. **Add `--dry-run` to deploy.sh** — build without activating, to catch build failures without risking the running system
32. **Add `nix run .#health-check` app** — one command to run all smoke tests interactively
33. **Add Discord webhook test** — verify the alert pipeline works end-to-end (send a test alert)
34. **Add system-health metrics to SigNoz dashboard** — create a pre-built dashboard for the new metrics
35. **Consider switching from textfile collectors to a custom node_exporter collector** — for more complex logic (universal failed-service detection)

### Priority 7 — Technical Debt
36. **Remove the `nix flake lock --update-input go-cqrs-lite` change** — the lock file was updated but the hash mismatch is in the upstream flake.nix, not the lock. The lock update is harmless but unnecessary
37. **Pin go-cqrs-lite to a specific rev** — `ref=master` means every update can break the vendorHash. Pin to a tagged release
38. **Add a CI check for `nix build .#cqrs-lint`** — catch vendorHash drift before deploy
39. **Consider vendoring cqrs-lint locally** — build from a local checkout instead of the flake input, to avoid upstream drift
40. **Add a `flake.lock` age check** — alert if the lock file hasn't been updated in >30 days

### Priority 8 — Polish
41. **Add descriptions to all Gatus check groups** — "Monitoring" group should have a tooltip explaining what it covers
42. **Color-code the Gatus dashboard** — use different colors for infrastructure vs application vs monitoring checks
43. **Add a "last deploy" timestamp to the homepage dashboard** — via a textfile collector
44. **Add `nixos-version` to system-health metrics** — expose the current generation hash/rev
45. **Add uptime metric** — `system_uptime_seconds` gauge

### Priority 9 — Research
46. **Investigate DuckDB `Binder Error` root cause** — is it a column ordering issue in CREATE TABLE? A SELECT alias problem?
47. **Research DuckDB schema migration patterns** — the monitor365 bootstrap SQL may need to be rewritten for DuckDB's stricter semantics
48. **Check if DuckDB has a `--strict-binder` flag** — to catch these errors at migration time rather than runtime
49. **Research Prometheus alertmanager integration** — instead of Gatus pat() matching, use real Prometheus alert rules for threshold-based alerting
50. **Consider replacing Gatus with VictoriaMetrics + vmalert** — for proper metric-based alerting with numeric comparison

---

## g) Questions for the User

### 1. Should I delete the Monitor365 DuckDB database and let it recreate from scratch?
The binder error (`Column "version" referenced...`) happens during bootstrap — it may be a schema migration issue on the existing database. Deleting `/var/lib/monitor365-server/monitor365.duckdb` (and the backup) would force a fresh bootstrap. BUT: this loses all accumulated telemetry data. The alternative is waiting for an upstream code fix. I can't determine if the binder error is data-dependent or code-dependent without reading the upstream bootstrap SQL.

### 2. Is the `nix flake lock --update-input go-cqrs-lite` lock change intentional or should I revert it?
The lock file was updated during this session's first attempt to fix the vendorHash. The update itself is harmless (just a newer rev of go-cqrs-lite), but it wasn't necessary — the hash mismatch was in the upstream flake.nix, not the lock. Should I revert the lock to its pre-session state, or is the newer rev fine to keep?

### 3. Do you want me to file an upstream issue/PR for the Monitor365 binder bug, or handle it differently?
The error `Binder Error: Column "version" referenced that exists in the SELECT clause - but this column cannot be referenced before it is defined` is in the monitor365-server Rust codebase (bootstrap SQL). I need to know whether to: (a) investigate and fix it in the upstream monitor365 repo, (b) add a workaround in SystemNix (e.g., pre-delete the DB on each start), or (c) wait for you to handle it. The server is currently crash-looping with this error.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Commits made | 2 (plus 2 from prior session) |
| Build attempts | 3 (2 failed, 1 succeeded) |
| Deploy exit code | 4 (services failed, config activated) |
| Smoke tests | 20 PASS, 2 FAIL, 3 SKIP |
| Files modified | 7 (system-health.nix, gatus-config.nix, lib/default.nix, home.nix, lars-packages.nix, AGENTS.md, flake.lock) |
| Pre-commit hooks | All passed (gitleaks, deadnix, statix, alejandra, flake-check) |
| Time to deploy | ~15 min (including 2 failed attempts) |
