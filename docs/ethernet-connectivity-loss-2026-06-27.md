# Ethernet Connectivity Loss on evo-x2 (2026-06-27)

## Symptom

evo-x2 stopped connecting to the internet via ethernet cable.

## Investigation

Reviewed the last ~20 git commits. **None of them touched networking** — they were DiscordSync reactivation, Gatus/Homepage monitoring tiles, BTRFS health guards, verbose boot logging, oneshot-service refactors, and flake lock bumps.

The ethernet problem traced back to the **existing `dual-wan` configuration**, which was enabled at `platforms/nixos/system/configuration.nix:223` (`dual-wan.enable = true`).

## Root Cause Analysis

The `dual-wan` module (`modules/nixos/services/dual-wan.nix`) activates the `route-health-monitor` systemd service (`scripts/route-health-monitor.sh`), which runs an **infinite loop every 2 seconds** (`CHECK_INTERVAL=2`) and **replaces the default route** based on live ISP health checks.

Identified failure modes:

1. **Evicts the eno1 default route on transient failures.** If `check_isp_internet()` (a `curl --interface eno1 http://1.1.1.1` with a 2-second timeout) fails **twice** in a row (`FAILOVER_THRESHOLD=2`, i.e. 4 seconds), the monitor moves the default gateway entirely off eno1 onto WiFi (`set_route_single "$WIFI_GW" "$WIFI_IF"`).

2. **Overrides NixOS's static default gateway.** The script runs `ip route replace default ...` with ECMP nexthops or a single WiFi route, clobbering whatever NixOS configured at activation time.

3. **Sticky failover state.** `detect_initial_mode` (`route-health-monitor.sh:107-129`) reads the existing route table on restart/reboot and adopts whatever mode it finds — including `wifi-only`. The `FAILBACK_THRESHOLD=5` consecutive successes required to restore eno1 may never be met if the check probe is unreliable, leaving the system pinned to WiFi indefinitely.

4. **No carrier/link validation.** `detect_wifi_gateway` only checks WiFi state. The script treats "1.1.1.1 didn't answer in 2s" identically to "ethernet cable unplugged" — a design flaw that causes failover even when the ethernet link is perfectly healthy.

## Fix Attempted

Set `dual-wan.enable = false` in `platforms/nixos/system/configuration.nix`.

### First deploy failed

Ran `nh os switch` with `--offline`. Got:

```
Error:
0: Activation (test) failed
1: Activating configuration (exit status ExitStatus(Exited(4)))
```

Exit code 4 = a systemd unit failed to activate/reload during `switch-to-configuration`.

**Diagnosis of the activation failure:**

- `nh` swallowed the per-unit error detail.
- `--offline` only affects the build/fetch phase — it cannot help with activation failures and suppresses eval-time error messages. **Do not use `--offline` for debugging activation failures.**
- Initially suspected `route-health-monitor` / `mptcp-endpoint-manager` services refusing to stop during activation, but `systemctl status mptcp-endpoint-manager.service` returned **"not found"** — the unit was never actually running in the booted generation. This ruled out the dual-wan services as the cause of exit code 4.
- The exact failing unit was never identified because `nh` hid it.

### Resolution

**A reboot fixed it.** After rebooting, the ethernet connection worked again.

The most likely explanation: the booted generation was stale/inconsistent with the source config (dual-wan services referenced units that didn't exist in the running system). The reboot brought the running system into sync with the new generation, clearing whatever transient activation conflict caused exit code 4.

## What is `mptcp-endpoint-manager`?

One of two systemd services defined by the `dual-wan` module (`modules/nixos/services/dual-wan.nix:132-157`).

- **Purpose:** Adds static MPTCP endpoints on boot so the kernel knows which local IPs/interfaces can form MPTCP subflows. MPTCP (Multipath TCP) lets a single TCP connection send packets over both ethernet and WiFi simultaneously for redundancy.
- **What it runs:** `scripts/mptcp-endpoint-manager.sh startup` — calls `ip mptcp endpoint add` to register `eno1`'s IP and the WiFi interface as MPTCP endpoints.
- **Type:** `oneshot, RemainAfterExit=true` — runs once, then systemd considers it "active" forever.

## Lessons Learned

| Lesson | Detail |
|--------|--------|
| `--offline` hides errors | Only use for the build/fetch phase. Suppresses eval-time errors needed to diagnose activation failures. |
| `nh` swallows unit-level activation errors | Run `sudo /run/current-system/bin/switch-to-configuration test` directly to see the failing unit by name. |
| Reboot resolves stale-generation conflicts | If the running system is out of sync with source config (units referenced but never started), a reboot resyncs cleanly. |
| `route-health-monitor` is aggressive | 2s probe timeout + 2-failure threshold = 4s to failover off a healthy ethernet link. Needs carrier validation before declaring ISP dead. |
| `detect_initial_mode` preserves broken state | Failover state is sticky across restarts. If failback threshold isn't met, system stays on WiFi indefinitely. |

## Current State

- `dual-wan.enable = false` in `platforms/nixos/system/configuration.nix`
- Ethernet connectivity restored after reboot
- The `dual-wan` module and its scripts remain in the repo but are inactive

## Diagnostic Commands (for future reference)

```bash
# Check current default route
ip route show default

# Check dual-wan service status
systemctl status route-health-monitor.service mptcp-endpoint-manager.service

# View monitor logs
journalctl -u route-health-monitor -n 50 --no-pager

# See exact failing unit during activation (nh hides this)
sudo /run/current-system/bin/switch-to-configuration test 2>&1 | tail -30

# Check for failed units
systemctl --failed

# What generation is actually booted?
readlink /run/current-system
nixos-version
```
