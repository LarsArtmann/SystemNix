# SystemNix Status Report — Hermes Recovery & Activation Pending

**Date:** 2026-04-28 10:38 CEST
**Host:** evo-x2 (NixOS 26.05 unstable, x86_64-linux)
**Branch:** master @ `5b43bd0`
**Author:** Crush (GLM-4.5-Air)

---

## Executive Summary

Hermes Gateway service is **offline** since 2026-04-27 ~20:46 CEST (~14 hours). Root cause identified and fix committed, but **activation has not completed** — the NixOS switch is blocked by stale rebuild processes from the previous interrupted session. Those processes have now exited, but the new unit has not been activated yet. A single `just switch` is needed.

---

## A) FULLY DONE

1. **Root cause diagnosed** — Hermes failing with `Failed to set up mount namespacing: /home/hermes/.hermes: No such file or directory` (exit code 226/NAMESPACE). The `harden` function's `ReadWritePaths` included `oldStateDir` which pointed to a nonexistent path.

2. **Fix committed** (`7de84f3`) — Removed `oldStateDir` from `ReadWritePaths` in `hermes.nix:174`. Now only `cfg.stateDir` (`/var/lib/hermes`) is in the sandbox write paths.

3. **Docker-prune conflict resolved** (`25091dd`) — Added `lib` to scheduled-tasks.nix function args and used `lib.mkForce` on `description`, `timerConfig`, and `serviceConfig` to override nixpkgs' `virtualisation.docker` module's conflicting `docker-prune` definitions.

4. **Old state dir path corrected** (`a4fca6f`) — Changed `oldStateDir` from `/home/${cfg.user}/.hermes` to `/home/.hermes` (though this dir doesn't exist either — moot since it's now removed from ReadWritePaths).

5. **AI model storage centralization** (`86f434e`, `0a2aa0c`, `5b43bd0`) — New `ai-models.nix` module + migration tools in justfile.

6. **Immich watchdog fix** (`0c4d21f`) — Increased watchdog timeout and set HOME env var.

7. **Timer hardening session complete** (`452b4ae` through `25091dd`) — All systemd timers hardened with `RandomizedDelaySec`, `OnFailure` notifications, consistent `Persistent=true`.

---

## B) PARTIALLY DONE

1. **Hermes service recovery** — Fix committed and built successfully (17 derivations, 1m32s), but **activation failed twice** due to NixOS activation lock held by stale processes from the previous interrupted session. Those processes have now exited. **Needs `just switch` to activate.**

2. **`oldStateDir` migration logic** — The migration script (`hermes-migrate-state`) still references `oldStateDir = "/home/.hermes"` which doesn't exist. The script handles this gracefully (exits 0), but the variable and migration code are now dead code since:
   - The old dir doesn't exist
   - It's no longer in `ReadWritePaths`
   - Consider removing `oldStateDir` entirely in a cleanup commit

---

## C) NOT STARTED

1. **Verify Hermes actually starts** after activation — needs `just switch` then `just hermes-status`
2. **Check Hermes runtime health** — verify Discord bot connects, config loads, no env issues
3. **Clean up dead `oldStateDir` code** in hermes.nix
4. **DNS failover cluster** — Pi 3 hardware not provisioned (per AGENTS.md)
5. **SigNoz dashboard** for Hermes service monitoring
6. **Raspberry Pi 3 NixOS image** build and deployment

---

## D) TOTALLY FUCKED UP

1. **Hermes has been offline ~14 hours** — Fix was committed ~21:52 CEST on Apr 27, but activation never completed because the previous session's `nh os boot` process hung holding the NixOS activation lock. Two retry attempts in the new session also hit the lock. The stale processes (`sudo ... switch-to-configuration test`, PIDs 927676/927678/927679) are now gone but the new configuration was never activated. The service is still running with the **old broken unit** that references the nonexistent `/home/hermes/.hermes` path.

2. **Session continuity failure** — The previous session got too long and was interrupted, leaving orphaned activation processes. This is a pattern that should be addressed (see improvements below).

---

## E) WHAT WE SHOULD IMPROVE

1. **Activation lock detection** — `nh os switch` should detect and report stale activation locks with actionable guidance (e.g., "kill PIDs X, Y, Z and retry"). Currently just says "Could not acquire lock".

2. **Session handoff protocol** — When sessions get interrupted mid-activation, there should be a way to detect and resume. Consider a `just switch-status` command that checks for stale locks.

3. **Remove dead migration code** — `oldStateDir` and the `hermes-migrate-state` ExecStartPre are now dead weight. The migration already happened (or the dir never existed). Clean it up.

4. **Service health checks in justfile** — `just switch` should optionally run a post-activation health check on critical services (hermes, caddy, immich, etc.) and report failures.

5. **Hermes watchdog/notification** — Add an `OnFailure` notification for hermes.service (we hardened timers but didn't add failure notifications to the hermes unit itself). A 14-hour silent outage is unacceptable.

6. **NixOS activation lockfile** — Understand where systemd/nixos stores the activation lock and add a `just unlock` or `just switch-force` that can clear stale locks.

---

## F) Top 25 Things We Should Get Done Next

| #  | Priority | Task                                                   | Why                                 |
| -- | -------- | ------------------------------------------------------ | ----------------------------------- |
| 1  | **P0**   | Run `just switch` to activate Hermes fix               | Service offline 14h                 |
| 2  | **P0**   | Verify Hermes is running: `just hermes-status`         | Confirm fix worked                  |
| 3  | **P0**   | Run `nh os boot .` to make fix survive reboot          | switch is test-only                 |
| 4  | **P1**   | Add `OnFailure` notification to hermes.service         | Prevent silent outages              |
| 5  | **P1**   | Remove dead `oldStateDir` code from hermes.nix         | Cleanup, reduce confusion           |
| 6  | **P1**   | Add `just switch-status` command to detect stale locks | Operational improvement             |
| 7  | **P1**   | Run AI model migration: `just ai-migrate`              | Centralize AI storage to /data/ai/  |
| 8  | **P2**   | Verify all services healthy: `just health`             | Post-activation check               |
| 9  | **P2**   | Check Immich service post-watchdog fix                 | Verify 0c4d21f works                |
| 10 | **P2**   | Add Hermes health check to justfile                    | `just hermes-health` for deep check |
| 11 | **P2**   | Review SigNoz dashboards for Hermes                    | Observability gap                   |
| 12 | **P2**   | Test `just dns-diagnostics`                            | DNS stack validation                |
| 13 | **P3**   | Raspberry Pi 3 provisioning for DNS failover           | HA DNS                              |
| 14 | **P3**   | Add Hermes to homepage dashboard                       | Service visibility                  |
| 15 | **P3**   | Audit all service modules for ReadWritePaths issues    | Prevent class of bugs               |
| 16 | **P3**   | Add nix flake check to CI/CD                           | Catch build conflicts early         |
| 17 | **P3**   | Document the activation lock issue                     | Knowledge base                      |
| 18 | **P3**   | Review all `lib.mkForce` uses in scheduled-tasks.nix   | Ensure no unintended overrides      |
| 19 | **P4**   | Set up automated service monitoring alerts             | Proactive detection                 |
| 20 | **P4**   | Create Hermes backup/restore procedure                 | Disaster recovery                   |
| 21 | **P4**   | Review and update AGENTS.md with Hermes fix learnings  | Knowledge persistence               |
| 22 | **P4**   | Audit all systemd hardening configs                    | Systematic review                   |
| 23 | **P4**   | Add `just rollback` documentation                      | Recovery procedures                 |
| 24 | **P4**   | Review flake.lock for outdated inputs                  | Maintenance                         |
| 25 | **P4**   | Clean up temp build results in /tmp/nh-os*             | Disk space                          |

---

## G) Top Question I Cannot Figure Out Myself

**Does `/var/lib/hermes/` actually have valid Hermes config and secrets?** The service has been in a restart loop since the NAMESPACE failure. Before that, it was presumably working. But I cannot verify:

- Whether `/var/lib/hermes/config.yaml` exists and is valid
- Whether `/var/lib/hermes/.env` has the correct API keys (sops template merge)
- Whether the sops secrets (`hermes.yaml`) are properly decrypted
- Whether the Hermes binary from the flake input is functional

If any of these are broken, fixing the NAMESPACE issue will just reveal the next failure. The user should check `just hermes-logs` immediately after activation succeeds.

---

## Current System State

| Component       | Status                       | Notes                                             |
| --------------- | ---------------------------- | ------------------------------------------------- |
| Hermes Gateway  | **FAILED** (start-limit-hit) | Offline 14h, fix committed but not activated      |
| NixOS Config    | Built, not activated         | `5b43bd0` on disk, running system is older        |
| Stale Processes | **GONE**                     | PIDs 927676-927679 have exited                    |
| Activation Lock | **CLEAR**                    | Ready for `just switch`                           |
| Git             | Clean, pushed                | All changes committed and pushed to origin/master |

## Immediate Action Required

```bash
just switch                  # Activate the fix (will restart hermes)
just hermes-status           # Verify hermes is running
nh os boot .                 # Persist to boot
just hermes-logs             # Check for any runtime errors
```
