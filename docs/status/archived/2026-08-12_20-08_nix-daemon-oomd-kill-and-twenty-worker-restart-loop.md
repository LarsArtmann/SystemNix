# Status: nix-daemon oomd Kill + Twenty Worker Restart Loop

**Date:** 2026-08-12 20:08 CEST
**Session focus:** Diagnosing and fixing nix-daemon outage + Twenty worker crash loop

---

## Incident Summary

User attempted `nix flake update browser-history` and `nh os switch` — both failed with `cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Connection refused`. The nix-daemon was completely dead.

---

## a) FULLY DONE

### 1. Root Cause Diagnosis: nix-daemon killed by systemd-oomd

**Evidence chain:**
- `journalctl -u nix-daemon` showed: `Main process exited, code=killed, status=9/KILL` repeated rapidly, then `Failed with result 'start-limit-hit'`
- `journalctl -u systemd-oomd` showed the exact kill decision:
  ```
  Marked /system.slice/nix-daemon.service for killing due to memory pressure
  for /system.slice being 65.15% > 50.00% for > 20s with reclaim activity
  nix-daemon.service: systemd-oomd killed 20 process(es) in this unit.
  ```
- nix-daemon was the top memory consumer under `/system.slice` (875MB current, 4.8G peak during builds)
- A leftover `cp` process (PID 372146) from a previous nix-daemon cgroup was noted in logs but was already gone — red herring
- nix-daemon is **socket-activated**: every pending nix command re-triggers the socket → starts daemon → oomd kills it → rapid restarts → `start-limit-hit` → daemon permanently dead

### 2. Fix: nix-daemon oomd exemption + kernel OOM protection

**File:** `platforms/nixos/system/networking.nix`

Added two directives to nix-daemon's serviceConfig:
- `ManagedOOMPreference = "omit"` — systemd-oomd will NEVER select nix-daemon for killing
- `OOMScoreAdjust = -1000` — kernel OOM killer scores nix-daemon at -1000 (absolute lowest priority; only killed when system is completely exhausted with no other victims)

These are the maximum protections available. Same `ManagedOOMPreference` pattern as PMA (`projects-management-automation.nix`).

### 3. Monitoring: nix-daemon added to system-health + Gatus

**File:** `modules/nixos/services/system-health.nix`
- Added `"nix-daemon"` to `monitoredServices` default list (emits `system_service_active`, `system_service_start_limit_hit`, `system_service_nrestarts` metrics)

**File:** `modules/nixos/services/gatus-config.nix`
- Added Gatus health check "Nix Daemon" — checks both `system_service_active{service="nix-daemon"} 1` AND `system_service_start_limit_hit{service="nix-daemon"} 0`
- Discord alert with recovery instructions: `sudo systemctl reset-failed nix-daemon && sudo systemctl start nix-daemon`
- 1-minute interval (critical infrastructure)

This outage previously went **completely undetected** — no alerting existed for nix-daemon state.

### 4. Root Cause Diagnosis: Twenty worker 235-restart crash loop

**Evidence chain:**
- `docker inspect twenty-worker-1`: `RestartCount: 235` (initially 136, grew to 235 during our session)
- `docker events`: every die event shows `exitCode=137` (SIGKILL) with `execDuration=14-15s`
- `docker inspect`: `OOMKilled: false` — Docker's own OOM handler did NOT kill it
- Container ID `344a51c7de5f` matched the exact scope systemd-oomd was repeatedly killing:
  ```
  Marked /system.slice/docker-344a51c7de5f72319a6544f4a94ab369b9a45884b5e6d37a7863d3ed2c413063.scope
    for killing due to memory pressure for /system.slice being 87.18% > 50.00%
  ```
- Worker at 856MB RSS — largest Docker container, largest memory consumer under `/system.slice` after nix-daemon
- Restart loop was self-perpetuating: kill → `restart: always` → Node.js/NestJS init burst (loads 50+ modules) → pressure spike → oomd kills again → repeat every ~15s

### 5. Fix: Twenty worker memory limits

**File:** `modules/nixos/services/twenty.nix`

Added to the worker container in docker-compose:
- `mem_limit = "2g"` — hard 2G cgroup ceiling
- `memswap_limit = "2g"` — no swap (mem+swap = 2G, so swap = 0)
- `NODE_OPTIONS = "--max-old-space-size=1536"` — V8 GC runs aggressively at 1.5G heap, keeping RSS lower so the worker is less likely to be oomd's top candidate

### 6. Documentation: AGENTS.md updated

Added two entries to the Non-Obvious Gotchas section:
- **Systemd section**: "systemd-oomd kills nix-daemon during builds (2026-08-12 outage)" — full root cause, fix, recovery command
- **Docker section**: "systemd-oomd kills Docker containers under system-slice pressure (Twenty worker)" — exitCode=137 pattern, Docker OOMKilled=false misleading behavior, mem_limit + NODE_OPTIONS fix

---

## b) PARTIALLY DONE

### Docker container memory limits — only worker done

Only `twenty-worker-1` got `mem_limit`/`memswap_limit`. Current memory snapshot:

| Container | Memory | Limit? | Restart count |
|-----------|--------|--------|---------------|
| twenty-worker-1 | 856MB | **2G (new)** | 235 |
| twenty-server-1 | 529MB | **NONE** | 0 |
| twenty-db-1 | 31MB | **NONE** | 0 |
| twenty-redis-1 | 13MB | **NONE** | 0 |
| mnfst-manifest-1 | unknown | **NONE** | 0 |
| mnfst-postgres-1 | unknown | **NONE** | 0 |
| dozzle | unknown | **NONE** | 0 |

Every Docker container without a `mem_limit` is a potential oomd victim and a potential unbounded memory consumer. The worker was just the first to get killed because it's the biggest.

### oomd pressure threshold tuning — not evaluated

The current oomd config (`boot.nix`): `DefaultMemoryPressureLimit = 50%`, `DefaultMemoryPressureDurationSec = 20s`. This is already tighter than NixOS defaults (80%). The question of whether 50%/20s is too aggressive was not evaluated — it may be killing legitimate burst workloads (builds, model loads) that would self-resolve in 30-60s.

---

## c) NOT STARTED

- **No `nix flake check --no-build`** — nix-daemon was down the entire session, so no Nix evaluation was possible. All changes are **unverified** at the Nix syntax/eval level.
- **No deploy** — changes are in the working tree but not deployed. User needs to restart nix-daemon first, then deploy.
- **Manifest container unhealthy** — `mnfst-manifest-1 Up 39 minutes (unhealthy)` was visible in `docker ps` output and completely ignored. Unknown root cause.
- **Twenty worker memory leak investigation** — 856MB for a Node.js background worker processing BullMQ jobs is high. Could be a memory leak in Twenty's worker code, or just NestJS module overhead (50+ InstanceLoader modules loaded). Not investigated.
- **No Docker container restart monitoring in Gatus** — Docker container restart counts are not exported as Prometheus metrics or checked by Gatus. The 235-restart loop would have gone unnoticed (only Docker's internal `RestartCount` tracked it).
- **systemd-oomd kill event alerting** — There is no Gatus alert for "oomd killed a service." The oomd journal entries are only visible after the fact. A metric like `system_oomd_kills_total` would catch all future oomd kill events proactively.

---

## d) TOTALLY FUCKED UP

### Nothing is catastrophically broken, but:

- **We never told the user to restart nix-daemon prominently enough.** The recovery command was buried in a code block in the middle of the first response. The user likely still has a dead nix-daemon. **Recovery command:**
  ```bash
  sudo systemctl reset-failed nix-daemon.service && sudo systemctl start nix-daemon.service
  ```

- **The Twenty worker fix may not fully stop the restart loop.** `mem_limit` caps Docker's own OOM, but systemd-oomd kills based on PSI pressure at the system-slice level. If the worker (even capped at 2G) is still the top consumer when system pressure exceeds 50%, oomd will still kill it. The `NODE_OPTIONS` heap cap is the more important fix (lower RSS = less likely to be oomd's top candidate), but it's not guaranteed. The only guaranteed fix would be `ManagedOOMPreference=omit` on the Docker scope, which CANNOT be set from NixOS because Docker creates transient scope units.

- **The 235 restart count is still climbing.** As of the end of this session, the worker was still being killed and restarting every ~15s. Our fix is in the Nix config but NOT deployed (nix-daemon is down). The worker will keep crash-looping until a deploy applies the new compose file with `mem_limit`.

---

## e) WHAT WE SHOULD IMPROVE

1. **Always prominently surface recovery commands.** The nix-daemon recovery command should have been the FIRST thing in the response, not buried mid-paragraph.
2. **Verify changes when possible.** We couldn't eval-check because nix-daemon was down, but we should have explicitly flagged this as "unverified — check after restart."
3. **Consider ALL Docker containers for mem_limit.** Every unbounded container is a future oomd victim. The `mkDockerServiceFactory` in `lib/docker.nix` sets `MemoryMax` on the SYSTEMD service (capping the docker-compose parent process), but individual container limits must be set in the compose file.
4. **Add oomd kill event monitoring.** A textfile collector that counts `oomd killed` journal entries per unit would catch ALL future oomd kills, not just the specific services we manually added to Gatus.
5. **Docker container restart monitoring.** A collector that runs `docker inspect --format '{{.RestartCount}}'` for all containers and emits Prometheus metrics would have caught the 235-restart loop immediately.
6. **Evaluate oomd pressure threshold.** 50%/20s may be too tight for a system that regularly runs nix builds + Docker + AI workloads. The threshold was tuned for the 2026-06-19 Helium leak, but builds are legitimate burst pressure.
7. **The nix-daemon socket activation + start-limit interaction is a design flaw.** Socket activation re-triggers on every pending connection, causing rapid restarts. Consider increasing `StartLimitBurst`/`StartLimitIntervalSec` specifically for nix-daemon (via `unitConfig`, NOT `serviceConfig` — see the StartLimitBurst gotcha).

---

## f) Up to 50 Things to Get Done Next
> **Note:** Items below were harvested into TODO_LIST.md / ROADMAP.md where actionable. Done items are struck through.


### Critical (blocks all Nix operations)
1. ~~**Restart nix-daemon** — `sudo systemctl reset-failed nix-daemon.service && sudo systemctl start nix-daemon.service`~~ done — recovered; nix operations working since
2. ~~**Run `nix flake check --no-build`** — verify all changes from this session eval cleanly~~ done — passes on every deploy since
3. ~~**Deploy** — `nix run .#deploy` to apply nix-daemon oomd exemption, Gatus monitoring, and Twenty worker mem_limit~~ done at `505ac4de` (deployed via subsequent sessions)
4. ~~**Verify Twenty worker stops crash-looping** after deploy — check `docker inspect twenty-worker-1 --format '{{.RestartCount}}'` is stable~~ done (pending post-reboot confirmation) — mem limits live, oomd raised to 60%/30s (`17731861`), docker restart monitoring live (`9b6590bf`)

### Monitoring Gaps
5. ~~Add `system_oomd_kills_total` metric — textfile collector grepping `journalctl -u systemd-oomd --grep "killed"` per unit~~ done at `9b6590bf` (`system_oomd_kills_total`/`_recent`/`_alert`; grep pattern verified live: `"Marked.*for killing"`)
6. ~~Add Docker container restart count collector — `docker inspect --format '{{.RestartCount}}'` for all containers → Prometheus metrics~~ done at `9b6590bf`
7. ~~Add Gatus alert on Docker container restart count > threshold (e.g., > 10 in 1h)~~ done at `9b6590bf` ("Docker Container Restarts" alert)
8. ~~Add Gatus alert for `system_oomd_kills_total` increasing (oomd killed ANYTHING)~~ done at `9b6590bf` ("OOMD Kills" alert)
9. **Add `mnfst-manifest-1` health monitoring — it's currently `(unhealthy)` and nobody noticed**
10. **Consider a Gatus check for nix-daemon socket connectivity (not just metrics-based liveness)**

### Docker Memory Limits
11. ~~Add `mem_limit` + `memswap_limit` to twenty-server-1 (529MB, #2 consumer)~~ done at `8ad493c9` (1g + 768M heap)
12. ~~Add `mem_limit` + `memswap_limit` to twenty-db-1 (PostgreSQL — should have a defined limit)~~ done (2g)
13. ~~Add `mem_limit` + `memswap_limit` to twenty-redis-1~~ done (256m)
14. ~~Add `mem_limit` + `memswap_limit` to mnfst-manifest-1~~ done at `7afab3f8` (1g + memswap 1g)
15. ~~Add `mem_limit` + `memswap_limit` to mnfst-postgres-1~~ done at `7afab3f8` (1g + 1g)
16. ~~Add `mem_limit` + `memswap_limit` to dozzle~~ done at `7afab3f8` (256m + log rotation)
17. ~~Audit ALL Docker services in SystemNix for missing container-level memory limits~~ done — all Docker containers on evo-x2 bounded (`2026-08-14_09-14` report)
18. **Consider adding `mem_limit` support to `mkDockerServiceFactory` as a per-container option**

### oomd / Memory Pressure
19. ~~Evaluate raising `DefaultMemoryPressureLimit` from 50% to 60-70% — builds are legitimate burst pressure~~ done at `17731861` (60%)
20. ~~Evaluate raising `DefaultMemoryPressureDurationSec` from 20s to 30s — give bursts time to self-resolve~~ done at `17731861` (30s; activation pending reboot)
21. Audit ALL services under `/system.slice` for `ManagedOOMPreference` — which ones should be exempt vs killable?
22. Consider per-slice oomd config instead of system-wide — separate Docker containers into their own slice with different pressure thresholds
23. Investigate `ManagedOOMPreference=omit` via Docker label or runtime config for critical containers
24. Add `MemoryHigh` (soft throttle) to nix-daemon to encourage reclaim before hard limits
25. Review the `user-1000.slice` MemoryHigh=80G / MemoryMax=90G — is this still appropriate?

### nix-daemon Resilience
26. Add `StartLimitBurst`/`StartLimitIntervalSec` to nix-daemon via `unitConfig` (NOT serviceConfig) — give it more restart attempts before giving up
27. Consider `RestartSec = "2s"` on nix-daemon to slow the restart loop slightly (avoid start-limit-hit from rapid socket re-trigger)
28. Add nix-daemon socket file existence check to pre-deploy-check.sh
29. Add nix-daemon connectivity test to post-deploy-check.sh (`nix ping store` or `nix doctor`)

### Twenty CRM
30. Investigate why Twenty worker uses 856MB — is this normal NestJS overhead or a memory leak?
31. Check if Twenty has a memory leak issue reported upstream (github.com/twentyhq/twenty)
32. Consider `NODE_OPTIONS = "--max-old-space-size=1024"` (1G instead of 1.5G) if the worker doesn't need it
33. Check if Twenty server (529MB) also needs a NODE_OPTIONS heap cap
34. Investigate the `martmull-app-to-remove` 404 warning in worker logs — failed app upgrade check
35. Review Twenty v2.7.3 changelog for known memory issues

### Manifest
36. Investigate `mnfst-manifest-1` unhealthy status — root cause unknown
37. Add Manifest health check to Gatus if not already present

### System Health
38. Review the `harden()` function — should `ManagedOOMPreference` be a default for critical services?
39. Consider adding `OOMScoreAdjust` to `serviceDefaults` for all services (default 500 = killable, override to -1000 for critical)
40. Review all services with `ManagedOOMPreference = "omit"` — too many exemptions defeat oomd's purpose
41. Add a "critical services" list to system-health that gets `OOMScoreAdjust = -1000` automatically

### Code Quality
42. The `lib/docker.nix` `mkDockerService` should support per-container `mem_limit` in the compose service definition
43. Consider a `mkDockerServiceFactory` option for `defaultMemLimit` that applies to all containers in a compose stack
44. Add an eval-time assertion that warns when a Docker service has containers without `mem_limit`

### Testing
45. Write a VM test for nix-daemon oomd exemption — verify oomd doesn't kill it under pressure
46. Write a VM test for Docker container memory limits — verify `mem_limit` is applied
47. Add a test that verifies Gatus alerts fire when `system_service_start_limit_hit` is 1

### Documentation
48. Document the oomd kill → socket activation → start-limit-hit chain in `docs/gotchas-archive.md` with full incident narrative
49. Add a "memory pressure incident response" runbook to docs/
50. Update `docs/CONTRIBUTING.md` with guidance on when to add `ManagedOOMPreference` and `OOMScoreAdjust`

---

## g) Questions (cannot determine without user input)

### 1. Is nix-daemon still down?
All our changes are undeployed because nix-daemon was down the entire session. Have you restarted it? If not: `sudo systemctl reset-failed nix-daemon.service && sudo systemctl start nix-daemon.service`. Without this, nothing we changed can be built, verified, or deployed.

### 2. Should we raise the oomd pressure threshold?
The 50%/20s threshold is tight — it killed both nix-daemon (mid-build) and the Twenty worker (steady-state). Options:
- **Keep 50%/20s** — aggressive, protects the desktop, kills services frequently
- **Raise to 60%/30s** — gives builds and Node.js init bursts more time to settle
- **Per-slice** — different thresholds for system.slice vs user.slice vs a new docker.slice

This is a judgment call about risk tolerance that I can't make for you.

### 3. Should the Twenty worker be exempt from oomd entirely?
The `mem_limit + NODE_OPTIONS` fix reduces the worker's memory footprint, but doesn't guarantee oomd won't kill it. The only guaranteed protection (`ManagedOOMPreference=omit`) can't be set on Docker transient scopes from NixOS. Alternatives:
- **Accept occasional kills** — worker is stateless, `restart: always` recovers it (just not every 15s)
- **Move Docker to a dedicated slice** with its own oomd config (significant refactoring)
- **Disable oomd for system.slice** and rely only on per-service MemoryMax (less safe)

---

## Files Changed This Session

| File | Change |
|------|--------|
| `platforms/nixos/system/networking.nix` | `ManagedOOMPreference = "omit"` + `OOMScoreAdjust = -1000` on nix-daemon |
| `modules/nixos/services/system-health.nix` | Added `"nix-daemon"` to monitoredServices |
| `modules/nixos/services/gatus-config.nix` | Added "Nix Daemon" Gatus health check (active + start-limit-hit, 1m interval, Discord alert) |
| `modules/nixos/services/twenty.nix` | Added `mem_limit`, `memswap_limit`, `NODE_OPTIONS` to worker container |
| `AGENTS.md` | Added 2 gotchas: nix-daemon oomd kill + Docker container oomd kill pattern |

**Verification status: UNVERIFIED** — nix-daemon was down the entire session. All changes need `nix flake check --no-build` after daemon restart.
