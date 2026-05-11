# Session 76 — Dual-WAN Bug Fix & Internet Connectivity Diagnosis

**Date:** 2026-05-11 23:14 CEST
**Focus:** Diagnose and fix evo-x2 internet connectivity failure

---

## Executive Summary

Lars reported `lars@192.168.1.150` had no internet. Diagnosed via SSH-based diagnostic script. Internet had recovered by time of investigation (likely after reboot at 22:41), but uncovered a **critical bug**: dual-WAN WiFi interface name mismatch (`wlp195s0` → `wlan0`).

---

## a) Fully Done

1. **WiFi interface name mismatch fixed** — `modules/nixos/services/dual-wan.nix`
   - Default `wifiInterface` was `wlp195s0` (predictable naming from `wpa_supplicant`)
   - Actual device is `wlan0` (because `iwd` backend uses different naming)
   - Both `route-health-monitor` and `mptcp-endpoint-manager` were querying a non-existent interface
   - They were **effectively no-ops** — running but doing nothing useful
   - Fix: changed default to `wlan0` to match `iwd` backend

2. **Internet diagnostic script created** — `scripts/internet-diagnostic.sh`
   - Comprehensive connectivity check (interfaces, routes, gateway, DNS, dual-WAN, MPTCP)
   - Color-coded output with actionable diagnosis summary
   - Emergency fix instructions included in output
   - Updated WiFi interface grep pattern to match `wl*` (covers wlan0, wlp*, etc.)

3. **Root cause analysis of original outage** (from git history)
   - Commit `d2823cb3` documents identical symptoms: "route-health-monitor regex bug + resolvconf reordering + router WAN temporarily down"
   - Commit `93e18cf6` (today) re-added `9.9.9.9` fallback — this was previously removed because resolvconf reorders it before `127.0.0.1`
   - The `nameservers = ["127.0.0.1" "9.9.9.9"]` regression may contribute to future outages

4. **Diagnostic findings from evo-x2** (23:11 CEST)
   - `eno1`: UP, `192.168.1.150/24` ✓
   - Gateway `192.168.1.1`: reachable ✓
   - External IPs (8.8.8.8, 1.1.1.1, 9.9.9.9): all reachable ✓
   - DNS: Unbound + Quad9 both resolve ✓
   - `wlan0`: connected to `Kittyspot` (DHCP `10.79.119.35/24`, gateway `10.79.119.24`) ✓
   - MPTCP: eno1 + wlan0 endpoints registered ✓
   - Route health monitor: active, warmed up ✓

---

## b) Partially Done

1. **Dual-WAN module correctness** — interface name fixed, but:
   - Need to `just switch` on evo-x2 to apply
   - Should verify ECMP actually works after fix (test with WiFi connected)
   - Route health monitor logs show no ECMP decisions ever made (because it never detected WiFi)

2. **resolvconf ordering risk** — identified but not addressed:
   - `nameservers = ["127.0.0.1" "9.9.9.9"]` may get reordered by resolvconf
   - If `9.9.9.9` is tried first when WAN is down, DNS fails
   - Previous fix removed 9.9.9.9 entirely; current code re-introduced the risk

---

## c) Not Started

1. **Verify dual-WAN ECMP failover actually works** — needs WiFi + ethernet both active + `just switch`
2. **Test route-health-monitor ECMP decision-making** — with corrected `wlan0` interface
3. **Validate mptcp-endpoint-manager** — should now correctly detect wlan0 IP changes
4. **resolvconf ordering fix** — consider `nameservers = ["127.0.0.1"]` only (as d2823cb3 intended)
5. **Provision Pi 3** for DNS failover cluster (from TODO_LIST.md Priority 4)
6. **nix-colors integration** — ~6h migration of 17+ hardcoded colors
7. **Deploy Dozzle** — Docker container log tailing at `logs.home.lan`
8. **Move `dns-failover.nix` plaintext `authPassword` to sops**
9. **Consolidate voice-agents Caddy vHost** into caddy.nix pattern
10. **SigNoz channel routing** (critical→Discord, warning→log)

---

## d) Totally Fucked Up

1. **Dual-WAN was a silent no-op since inception** — `wlp195s0` never existed on evo-x2 (iwd uses `wlan0`). The entire MPTCP + ECMP dual-WAN feature has been running in name only. Zero ECMP route decisions were ever made. Zero WiFi endpoints were ever managed. The `route-health-monitor` logged "warming up" then nothing because it couldn't find WiFi gateway.

2. **resolvconf 9.9.9.9 regression** — Commit `93e18cf6` (today) re-introduced the exact issue that commit `d2823cb3` fixed. The 9.9.9.9 fallback is dangerous because resolvconf reorders nameservers, potentially putting the external resolver first when WAN is down.

---

## e) What We Should Improve

1. **Auto-detect WiFi interface** instead of hardcoding — query `nmcli` or `/sys/class/net/*/wireless` at service start
2. **Add smoke tests to dual-wan module** — verify `WIFI_IF` exists before starting services
3. **Remove 9.9.9.9 from nameservers** — go back to `["127.0.0.1"]` only; unbound handles upstream resolution
4. **Add `ExecStartPre` validation** to both dual-WAN services — fail fast if interface doesn't exist
5. **Create `just internet-diagnostic` recipe** — wire the new diagnostic script into justfile
6. **Add dual-WAN section to AGENTS.md** — document the wifiInterface=iwd naming gotcha
7. **Health monitoring gap** — Gatus should check ECMP route state, not just individual services

---

## f) Top 25 Things to Do Next

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | `just switch` on evo-x2 to apply dual-WAN fix | Critical | 5min |
| 2 | Verify ECMP failover works with WiFi + ethernet | Critical | 15min |
| 3 | Remove 9.9.9.9 from `nameservers` (resolvconf regression) | High | 2min |
| 4 | Add `just internet-diagnostic` recipe to justfile | Medium | 2min |
| 5 | Add `ExecStartPre` interface validation to dual-WAN services | High | 15min |
| 6 | Auto-detect WiFi interface name instead of hardcoding | High | 30min |
| 7 | Add dual-WAN gotcha to AGENTS.md | Medium | 5min |
| 8 | Deploy to evo-x2 + verify all services (TODO P1) | Critical | 30min |
| 9 | Test Discord alert channel via SigNoz | High | 10min |
| 10 | Add per-threshold SigNoz channel routing | Medium | 1h |
| 11 | Move `dns-failover.nix` authPassword to sops | Medium | 30min |
| 12 | Consolidate voice-agents Caddy vHost | Low | 30min |
| 13 | Provision Pi 3 for DNS failover cluster | High | 2h |
| 14 | Wire Pi 3 as secondary DNS in dns-failover.nix | High | 1h |
| 15 | nix-colors integration (~17 hardcoded colors) | Low | 6h |
| 16 | Deploy Dozzle for Docker log tailing | Low | 2h |
| 17 | Compute real `vendorHash` for BuildFlow | Medium | 30min |
| 18 | Compute real `vendorHash` for PMA | Medium | 30min |
| 19 | Convert go-auto-upgrade `path:` inputs to SSH URLs | Low | 30min |
| 20 | Create shared flake-parts Go template | Low | 4h |
| 21 | Create `flake.nix` for hierarchical-errors | Low | 1h |
| 22 | Remove unused UDP 853 from firewall (DoQ disabled) | Low | 2min |
| 23 | Add Gatus ECMP route health endpoint | Medium | 30min |
| 24 | Add route-health-monitor journal logging verification | Low | 15min |
| 25 | Clean up diagnostic script — add to justfile dns-diagnostics | Low | 10min |

---

## g) Top #1 Question I Cannot Answer

**Is `Kittyspot` (the WiFi network on evo-x2) a mobile hotspot with its own internet?**

The diagnostic shows evo-x2's `wlan0` is connected to `Kittyspot` with gateway `10.79.119.24` (different subnet from the LAN `192.168.1.0/24`). This looks like a phone hotspot. The entire dual-WAN architecture assumes **two independent internet paths** — but if `Kittyspot` is a phone hotspot that's not always available, the ECMP failover could split traffic to a dead path when the phone leaves. I need to know:

- Is `Kittyspot` a permanent secondary WAN or a transient hotspot?
- Should the dual-WAN module handle WiFi networks that appear/disappear?

If it's transient, `dual-wan.enable` should probably be `false` and we should rely on eno1-only with MPTCP available as a manual fallback.

---

## Files Changed

| File | Change |
|------|--------|
| `modules/nixos/services/dual-wan.nix` | Fix WiFi interface default: `wlp195s0` → `wlan0` |
| `scripts/internet-diagnostic.sh` | New: comprehensive internet connectivity diagnostic script |

## Diagnostic Output (from evo-x2 at 23:11 CEST)

```
eno1: UP, 192.168.1.150/24, gateway 192.168.1.1 reachable
wlan0: connected to Kittyspot (10.79.119.35/24, gw 10.79.119.24)
MPTCP: eno1 (192.168.1.150) + wlan0 (10.79.119.35) endpoints registered
External IPs: 8.8.8.8 ✓ 1.1.1.1 ✓ 9.9.9.9 ✓
DNS: Unbound ✓ Quad9 ✓
Route health monitor: active (no ECMP decisions logged — was querying wrong interface)
```

## Internet Status

**Working as of 23:11 CEST.** The original outage was likely caused by:
1. Router WAN/ISP temporary disruption
2. resolvconf reordering 9.9.9.9 before 127.0.0.1 (no local DNS resolution)
3. Reboot at 22:41 resolved the transient issue
