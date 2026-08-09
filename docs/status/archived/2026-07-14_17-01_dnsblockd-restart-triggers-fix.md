# Status Report: 2026-07-14 17:01 — dnsblockd restartTriggers Fix

## Summary

The gen 516 deploy (unbound→dnsblockd migration with master-tracked dnsblockd) failed because `dnsblockd.service` was **never restarted** during activation — it appeared in neither the stop, restart, nor start unit lists. The old dnsblockd process (v0.2.0, HTTP-only, no `:53` listener) kept running while unbound was stopped, leaving port 53 with no listener. Every DNS-dependent service cascaded to `connection refused on 127.0.0.1:53`. Fix: added `restartTriggers` to `dns-blocker.nix` so ANY config or binary change forces a service restart via NixOS's `X-Restart-Triggers` mechanism.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## a) FULLY DONE

1. **Root cause identified from deploy log.** The `nh os switch` activation output showed `dnsblockd.service` absent from ALL activation lists (stop/restart/start), while `unbound.service` was in the stop list. The old dnsblockd process (running the v0.2.0 binary, HTTP block-page only) was never terminated. Nothing served `:53`. Evidence: discordsync logs show `dial tcp: lookup discord.com on 127.0.0.1:53: read: connection refused`.

2. **Module fix applied.** `modules/nixos/services/dns-blocker.nix`:
   - Added `restartTriggers = [ dnsblockdConfigFile pkgs.dnsblockd ]` to the `dnsblockd` systemd service
   - Moved `dnsblockdConfigFile`, `caCert`, `caKey` bindings from inner `serviceConfig` let-scope to outer module let-scope so both `restartTriggers` (unit-level) and `ExecStart` (service-level) can reference them
   - The `restartTriggers` mechanism embeds a hash of the referenced store paths into the unit file as `X-Restart-Triggers`. When the YAML config content or the dnsblockd binary changes, the hash differs between old and new unit files, forcing `switch-to-configuration` to restart the service — even in cases where it would otherwise miss the change

3. **AGENTS.md gotchas table updated.** Added entry documenting the stale-process DNS outage and the `restartTriggers` fix.

4. **Validated.** `nix flake check --no-build` passes. `nix fmt` applied (33 files formatted, including this module).

5. **Config-change coverage verified.** The `dnsblockdConfigFile` YAML embeds store paths for `processedBlocklist` (mapping.json), `categoriesJSON`, and all `blocklistPaths` (fetchurl derivations). When ANY of these change, the YAML content changes → its store path changes → `restartTriggers` hash changes → forced restart. No additional triggers needed.

---

## b) PARTIALLY DONE

1. **Fix is NOT deployed.** The `restartTriggers` change is in the working tree but not committed or deployed. The system is currently on a rolled-back generation (unbound restored). The next deploy will include this fix.

2. **Root cause investigation was incomplete.** I identified WHAT happened (dnsblockd not restarted) and applied the canonical fix (`restartTriggers`), but I did NOT fully determine WHY `switch-to-configuration` failed to detect the unit file change. The ExecStart line in the unit file DID change (binary store path `ad14663` → `4fa21f8`), which should have triggered a restart. Possible explanations I did not investigate:
   - The unit file derivation hash comparison in `switch-to-configuration` has an edge case
   - dnsblockd was running from an OLDER generation (not the one being replaced), so the diff didn't include it
   - The `test` action (vs `switch`) has different restart semantics
   - The start-limit-hit state blocked the restart (AGENTS.md documents this: `switch-to-configuration exit code 4`)

3. **Only `nix flake check --no-build` was run.** I did NOT run `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` for full evaluation, nor attempt a build.

---

## c) NOT STARTED

1. **Deploy with the fix.** `nix run .#deploy` has not been attempted.
2. **Post-deploy DNS verification.** No `dig`/`getent` smoke tests run.
3. **Post-deploy-check.** Not run (system is on rolled-back generation).
4. **Audit of OTHER services for missing `restartTriggers`.** If dnsblockd had this problem, other services with embedded config files (passed via ExecStart `-c ${configFile}`) may have the same latent risk. Candidates not yet audited:
   - `hermes.nix` — YAML config passed to ExecStart
   - `manifest.nix` — config file
   - `openseo.nix` — wrangler config
   - `gatus-config.nix` — YAML config
   - `homepage.nix` — YAML settings/services/widgets
   - `crush-daily.nix` — config file
   - `caddy.nix` — Caddyfile (though Caddy has its own reload mechanism)
5. **Commit.** Changes are uncommitted.

---

## d) TOTALLY FUCKED UP

1. **I did not verify my root cause theory before applying the fix.** I jumped from "dnsblockd wasn't restarted" directly to "add restartTriggers" without investigating WHY switch-to-configuration missed it. The `restartTriggers` fix is correct and defensive, but it's a band-aid if the underlying issue is something like "start-limit-hit blocks all restarts" (which AGENTS.md already documents as a known problem with a different fix: `systemctl reset-failed`). If that's the actual root cause, `restartTriggers` won't help — the restart will still be blocked.

2. **I did not consider that the deploy script (`deploy.sh`) already runs `systemctl reset-failed` before activation.** The deploy log shows the user ran `nh os switch` directly (bypassing `deploy.sh`), which means the `reset-failed` step was skipped. If dnsblockd was in a start-limit-hit state from a previous crash-loop, `nh os switch` would fail to restart it — but `nix run .#deploy` would have succeeded. The fix might be as simple as "always use deploy.sh, not nh directly."

3. **I reformatted 33 files with `nix fmt`.** While the format changes are correct, they pollute the diff for this specific fix. A focused contributor would format ONLY the file they changed, not the entire repo. The `nix fmt` run reformatted HTML docs, test files, and other unrelated files that were already dirty in the working tree.

---

## e) WHAT WE SHOULD IMPROVE

1. **Investigate the ACTUAL root cause before applying fixes.** The deploy log shows `switch-to-configuration test` — the `test` action, not `switch`. NixOS's `switch-to-configuration` script has different behavior for `test` vs `switch`. In `test` mode, it may not restart services that are already running, even if their unit file changed. This could be the real explanation. I should have read the NixOS `switch-to-configuration.pl` source to understand the difference.

2. **Always recommend `nix run .#deploy` over `nh os switch`.** The deploy script has pre-deploy checks, `systemctl reset-failed`, and post-deploy smoke tests. The user's deploy used `nh os switch` directly, bypassing all of these. The AGENTS.md already says "Use flake commands — `nix run .#deploy`, never raw `nixos-rebuild`/`darwin-rebuild`" but doesn't mention `nh os switch` as a bypass.

3. **Add a DNS smoke test to pre-deploy-check.** The pre-deploy-check script catches boot-breaking issues but doesn't verify functional DNS. A check like `getent hosts google.com` before and after deploy would catch DNS outages immediately.

4. **Audit all services with embedded config files for `restartTriggers`.** This is a systemic risk, not just dnsblockd. Every service that passes a generated config file via `ExecStart = "... -c ${configFile}"` has the same latent risk if `switch-to-configuration` doesn't detect the unit file change.

5. **Consider whether `restartTriggers` is the right tool vs `reloadIfChanged`.** `restartTriggers` forces a full restart (downtime). For DNS, even a brief restart window matters. `reloadIfChanged` + an `ExecReload=` would allow zero-downtime config changes. But dnsblockd may not support SIGHUP/reload — needs upstream verification.

6. **The comment I wrote in the module is too verbose.** Per the project conventions, comments should explain WHY not WHAT, and be concise. The 4-line comment block explaining the restartTriggers rationale could be 1-2 lines.

---

## f) Up to 50 Things We Should Get Done Next

### Tier 0: BLOCKING — Before next deploy

| #   | Task                                                                                                 | Effort   | Why                                                |
| --- | ---------------------------------------------------------------------------------------------------- | -------- | -------------------------------------------------- |
| 1   | Commit the `restartTriggers` fix + AGENTS.md update                                                  | 1min     | Preserve work                                      |
| 2   | Run `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` to verify full eval | 30s      | Catch eval errors `flake check` misses             |
| 3   | Deploy with `nix run .#deploy` (NOT `nh os switch`)                                                  | 10-20min | Uses deploy.sh with reset-failed + pre/post checks |
| 4   | Verify dnsblockd logs show "DNS server initialized" after deploy                                     | 30s      | Confirm resolver started                           |
| 5   | `dig @127.0.0.1 google.com` → resolves                                                               | 30s      | Verify recursion                                   |
| 6   | `dig @127.0.0.1 forgejo.home.lan` → server IP                                                        | 30s      | Verify local records                               |
| 7   | `dig @127.0.0.1 unknown.home.lan` → NXDOMAIN                                                         | 30s      | Verify zone boundary                               |
| 8   | `dig @127.0.0.1 doubleclick.net` → block IP                                                          | 30s      | Verify blocklist                                   |
| 9   | Verify oauth2-proxy starts (exit code 0)                                                             | 30s      | Cascade resolved                                   |
| 10  | Verify discordsync starts (exit code 0)                                                              | 30s      | Cascade resolved                                   |
| 11  | Run `nix run .#post-deploy-check`                                                                    | 1min     | Functional verification                            |
| 12  | Check Gatus DNS health check passes                                                                  | 30s      | Monitoring                                         |

### Tier 1: Root cause investigation

| #   | Task                                                                                                                   | Effort | Why                                                          |
| --- | ---------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------------------------------------------ |
| 13  | Read NixOS `switch-to-configuration.pl` — understand `test` vs `switch` restart behavior                               | 30min  | Determine if `nh os switch` is the real culprit              |
| 14  | Check if dnsblockd was in start-limit-hit state during the failed deploy                                               | 10min  | If so, `reset-failed` is the real fix, not `restartTriggers` |
| 15  | Test: deploy with `nix run .#deploy` (which runs `reset-failed`) and see if dnsblockd restarts WITHOUT restartTriggers | 10min  | Isolate whether `restartTriggers` is actually needed         |
| 16  | Document in AGENTS.md: `nh os switch` bypasses deploy.sh safety nets                                                   | 5min   | Prevention                                                   |

### Tier 2: Systemic hardening

| #   | Task                                                                                                           | Effort | Why                 |
| --- | -------------------------------------------------------------------------------------------------------------- | ------ | ------------------- |
| 17  | Audit all services with `ExecStart = "... -c ${configFile}"` pattern for missing `restartTriggers`             | 1h     | Systemic risk       |
| 18  | Add `restartTriggers` to `hermes.nix` if missing                                                               | 5min   | Same latent risk    |
| 19  | Add `restartTriggers` to `manifest.nix` if missing                                                             | 5min   | Same                |
| 20  | Add `restartTriggers` to `gatus-config.nix` if missing                                                         | 5min   | Same                |
| 21  | Add `restartTriggers` to `homepage.nix` if missing                                                             | 5min   | Same                |
| 22  | Add `restartTriggers` to `crush-daily.nix` if missing                                                          | 5min   | Same                |
| 23  | Consider a pre-commit hook that warns when a service has `${configFile}` in ExecStart but no `restartTriggers` | 1h     | Automated detection |
| 24  | Verify `openseo.nix` and `monitor365.nix` have proper restart behavior                                         | 15min  | Same class of risk  |

### Tier 3: DNS monitoring & verification

| #   | Task                                                                                                     | Effort | Why                                   |
| --- | -------------------------------------------------------------------------------------------------------- | ------ | ------------------------------------- |
| 25  | Add DNS resolution check to `pre-deploy-check.sh`: `getent hosts google.com`                             | 10min  | Pre-deploy DNS validation             |
| 26  | Add DNS resolution check to `post-deploy-check`: `getent hosts google.com && getent hosts auth.home.lan` | 10min  | Post-deploy DNS validation            |
| 27  | Verify Gatus has a DNS health check (TCP :53 or actual query)                                            | 15min  | Proactive DNS monitoring              |
| 28  | Add Gatus DNS check with Discord alert for DNS resolution failure                                        | 15min  | "Every new service MUST be monitored" |
| 29  | Update Grafana `dns.json` dashboard — stale unbound PromQL queries                                       | 30min  | Empty panels                          |
| 30  | Verify dnsblockd exposes Prometheus metrics with DNS-specific counters                                   | 15min  | Observability                         |

### Tier 4: Migration follow-up

| #   | Task                                                                                       | Effort | Why                                   |
| --- | ------------------------------------------------------------------------------------------ | ------ | ------------------------------------- |
| 31  | Verify wildcard `*.home.lan` record works with dnsblockd's sdns resolver                   | 5min   | Migration doc flagged this as #1 risk |
| 32  | Verify rpi3-dns dnsblockd input tracks master (not tags)                                   | 5min   | Same tag-pin bug could exist          |
| 33  | Clean up stale `unbound.conf` output arg from `dnsblockd process` build step               | 15min  | Dead code                             |
| 34  | Write dnsblockd DNS VM test (replaces removed unbound test)                                | 2-3h   | Test coverage                         |
| 35  | Verify DNSSEC works end-to-end (`dig +dnssec` for a signed domain)                         | 5min   | Security feature verification         |
| 36  | Monitor dnsblockd memory usage — sdns resolver + 2.5M blocklist entries under 1G MemoryMax | 1h     | OOM prevention                        |

### Tier 5: Process improvements

| #   | Task                                                                                    | Effort | Why                               |
| --- | --------------------------------------------------------------------------------------- | ------ | --------------------------------- |
| 37  | Add `nh os switch` to the "never use" list in AGENTS.md alongside raw `nixos-rebuild`   | 5min   | It bypasses deploy.sh safety nets |
| 38  | Consider making `deploy.sh` the ONLY entrypoint — alias or wrapper that blocks raw `nh` | 30min  | Enforcement                       |
| 39  | Add DNS smoke test to deploy.sh activation phase (before declaring success)             | 30min  | Catch DNS outage during deploy    |
| 40  | Document recovery procedure: `nixos-rebuild switch --flake .#evo-x2 --sudo --rollback`  | 5min   | Already used, just document it    |

### Tier 6: Code quality

| #   | Task                                                                                                | Effort | Why                                                               |
| --- | --------------------------------------------------------------------------------------------------- | ------ | ----------------------------------------------------------------- |
| 41  | Shorten the verbose comment block in `dns-blocker.nix` to 1-2 lines                                 | 2min   | Convention compliance                                             |
| 42  | Consider `reloadIfChanged` + `ExecReload` instead of `restartTriggers` if dnsblockd supports SIGHUP | 30min  | Zero-downtime config reload                                       |
| 43  | Verify the `restartTriggers` don't cause unnecessary restarts on EVERY deploy (false positives)     | 15min  | Config file store path should be stable if content doesn't change |
| 44  | Move the `caCert`/`caKey` sops path references back to inner scope if possible (less coupling)      | 10min  | Minimal scope                                                     |

### Tier 7: Future

| #   | Task                                                                                        | Effort | Why                                  |
| --- | ------------------------------------------------------------------------------------------- | ------ | ------------------------------------ |
| 45  | Add upstream dnsblockd validation: fail loudly if `dns_enabled: true` but binary lacks sdns | 1h     | Silent ignore caused original outage |
| 46  | Add `nix flake check` assertion: no LarsArtmann private repos pinned to tags                | 30min  | Prevent tag-pin staleness            |
| 47  | Consider DoT/DoH listener in dnsblockd config                                               | 5min   | Encrypted DNS transport              |
| 48  | Add DNS failover test (stop dnsblockd on evo-x2, verify rpi3 takes over via VRRP)           | 10min  | HA verification                      |
| 49  | Add per-client DNS statistics dashboard                                                     | 2h     | Network visibility                   |
| 50  | Consider secondary `nameserver` in `/etc/resolv.conf` for resilience                        | 5min   | Single point of failure              |

---

## g) Top 2 Questions I Cannot Answer Myself

### Q1: Was `restartTriggers` actually the right fix, or was the real problem `nh os switch` bypassing `reset-failed`?

The deploy log shows the user ran `nh os switch` (not `nix run .#deploy`). The `deploy.sh` script runs `systemctl reset-failed` before activation to clear start-limit counters. AGENTS.md documents that services in `start-limit-hit` state block ALL deploys when using raw `nh`. If dnsblockd was crash-looping from a previous generation (e.g., v0.2.0 binary crashing because it couldn't bind :53 while unbound held it), it would be in start-limit-hit state, and `nh os switch` would silently skip restarting it. In that case, `restartTriggers` won't help — the restart will still be blocked by the start-limit.

**To verify:** Deploy with `nix run .#deploy` (which runs `reset-failed`) and observe whether dnsblockd restarts correctly even without the `restartTriggers` change. If it does, the real fix is "never use `nh os switch` directly" — but `restartTriggers` is still good defense-in-depth.

### Q2: Why did `switch-to-configuration` not detect the dnsblockd unit file change?

The nvd diff shows `[C.] dnsblockd ad14663 -> 4fa21f8` — the package changed. The ExecStart line in the unit file embeds the full store path (`/nix/store/xxx-dnsblockd-4fa21f8.../bin/dnsblockd`), so the unit file content MUST have changed. NixOS's `switch-to-configuration` compares old and new unit files by content hash and restarts services whose unit files differ. Yet dnsblockd appeared in NONE of the activation lists. I cannot explain this without reading the actual old and new unit files or the `switch-to-configuration.pl` source code. The `restartTriggers` mechanism works around this by adding an explicit `X-Restart-Triggers` hash, but understanding WHY the normal change detection failed would reveal whether this is a one-off edge case or a systemic NixOS bug affecting other services.
