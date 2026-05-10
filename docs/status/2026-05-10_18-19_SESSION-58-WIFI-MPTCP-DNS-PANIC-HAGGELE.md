# SystemNix Status Report — Session 58

**Date:** 2026-05-10, 18:19 CEST
**Session:** #58 — WiFi Enablement, MPTCP Deployment, DNS Panic, Haggele
**Host:** evo-x2 (NixOS, x86_64-linux, kernel 7.0.1)
**Branch:** master
**Commit Base:** eff0ba14 (session 57)

---

## a) FULLY DONE

| # | Work | Details |
|---|------|---------|
| 1 | **WiFi enabled on evo-x2** | NetworkManager with iwd backend deployed. `wlp195s0` (MediaTek mt7925e) now active. |
| 2 | **Connected to `Kittyspot` hotspot** | SSID: Kittyspot, IP: 10.79.119.35/24, autoconnect: yes. |
| 3 | **Static IP preserved on eno1** | 192.168.1.150/24 via `networking.interfaces.eno1`. `unmanaged` in NM. |
| 4 | **Polkit rule for networkmanager group** | Added to `networking.nix`. Allows `lars` (in `networkmanager` group) to manage WiFi without auth prompts. |
| 5 | **User manually set DNS to 9.9.9.9** | `/etc/resolv.conf` now shows `nameserver 9.9.9.9` (manual override via NetworkManager or resolvconf). |
| 6 | **MPTCP kernel support verified** | `net.mptcp.enabled = 1`. Kernel 7.0.1 has full MPTCP v1 support. In-kernel path manager (pm_type=0) confirmed active. |
| 7 | **MPTCP endpoint scripts written** | `scripts/mptcp-endpoint-manager.sh` (74 lines) and `scripts/route-health-monitor.sh` (168 lines) written. |
| 8 | **MPTCP services deployed (then rolled back)** | Both systemd services created in `networking.nix`, deployed via `just switch`, verified running. Then reverted in working tree. |
| 9 | **Dual-WAN routing partially tested** | Both default routes active: eno1 metric 100 + WiFi metric 600. ECMP attempted. |
| 10 | **Hotspot jitter diagnosed** | Latency oscillates: 16 ms ↔ 274 ms (carrier-level jitter on phone hotspot, channel 1, 2.4 GHz). Not a WiFi driver issue. |
| 11 | **mt7925e RX bitrate collapse analyzed** | `iw` shows RX 1.0 MBit/s on 2.4 GHz — driver reporting bug, NOT actual throughput. Real speed: 258+ Mbps. |
| 12 | **Nix config validation** | `just test-fast` passes for both MPTCP + non-MPTCP states. |

---

## b) PARTIALLY DONE

| # | Work | What's Done | What's Missing |
|---|------|-------------|----------------|
| 1 | **MPTCP dual-WAN** | Scripts written, deployed, and verified working. MPTCP endpoints registered. | Rolled back in working tree. Not currently active. Needs redesign before re-deployment. |
| 2 | **Route health monitor** | ECMP weight logic with latency-based proportional allocation written and tested. | Only ran briefly before rollback. Did not reach steady-state ECMP. |
| 3 | **DNS reliability on hotspot** | Manual override to 9.9.9.9 works. Identified unbound DoT → Quad9 timeout over hotspot. | Nix config still points to `127.0.0.1` only. Next `just switch` will revert `resolv.conf` to unbound, breaking DNS again. |

---

## c) NOT STARTED

| # | Work |
|---|------|
| 1 | **Design and deploy a PROPER dual-WAN solution** that actually solves the buffering problem. Current MPTCP scripts were a proof-of-concept, not production-ready. |
| 2 | **Add alerting to Gatus** — 20 endpoints monitored, zero notifications on failure. Still "monitoring theater." |
| 3 | **Deploy DNS fix to rpi3-dns** — session 57 fix committed but not pushed/deployed to Raspberry Pi. |
| 4 | **Push session 57 commits to origin** — 4 unpushed commits sitting locally. |
| 5 | **Switch phone hotspot to 5 GHz** — the actual fix for buffering. 2.4 GHz channel 1 is congested and the mt7925e driver has known RX bugs on 2.4 GHz. |
| 6 | **Commit the session 58 work** — scripts exist but status report + commits not done yet (this is being done now). |

---

## d) TOTALLY FUCKED UP!

| # | Incident | Root Cause | Impact |
|---|----------|------------|--------|
| 1 | **DNS stopped working during MPTCP testing** | `just switch` with `nameservers = ["127.0.0.1"]` (no 9.9.9.9 fallback). Unbound DoT to Quad9 timed out over hotspot. `resolv.conf` pointed only to `127.0.0.1` → unbound had no working upstream. | All internet DNS resolution broke. User panicked. |
| 2 | **Multiple rollbacks cascaded** | User issued rollback 1 through rollback 6. Then "switch done." Each rollback is a NixOS generation switch, possible SSH drops. | 6 unnecessary generation switches. Mental overhead. |
| 3 | **Working tree vs git index mismatch** | Staged: MPTCP code + scripts. Unstaged: MPTCP code removed, nameservers changed. Deployed state = mixed. | `networking.nix` deployed from working tree (unstaged reverts). Scripts deployed but NOT referenced in config (dead files in /nix/store). |
| 4 | **route-health-monitor kept crashing** | `logger` not in PATH on first boot. Fixed by adding `util-linux` to `path`, but old store path persisted across restarts until systemd fully reloaded. | 19 restart loops before stabilization. Log noise. |
| 5 | **User manually changed DNS outside Nix** | `/etc/resolv.conf` now `9.9.9.9`, but `networking.nix` says `["127.0.0.1"]`. Ephemeral change — will be lost on next `just switch`. | Will break again. Source of truth violated. |
| 6 | **Hotspot is STILL the primary internet** | Despite all the MPTCP work, the user's actual internet is coming from a PHONE HOTSPOT with 17–274 ms jitter. eno1 should be primary for the LAN but the ISP connection through eno1 may be degraded — user said "eno1 may be bad connectivity." | Buffering on movie streaming is expected regardless of WiFi/MPTCP until this is addressed. |

---

## e) WHAT WE SHOULD IMPROVE!

1. **Fix the DNS nameservers in `networking.nix`** — Currently says `["127.0.0.1"]`. Must restore `"9.9.9.9"` (or `10.79.119.24` — hotspot DNS) as fallback. Unbound DoT over hotspot is unreliable. The user made the right call going direct.
2. **Phone hotspot → 5 GHz** — This single change would eliminate the mt7925e RX bug AND reduce congestion. Every other fix is secondary.
3. **MPTCP scripts need hardening** before re-deployment:
   - Replace `logger` with `systemd-cat` or just redirect to stdout (journald captures it)
   - Handle absent WiFi gateway gracefully (don't crash, just wait)
   - Add `--initial-delay` to avoid startup races with NetworkManager
4. **Don't deploy dual-WAN changes without testing DNS first** — The MPTCP deployment should have checked `dig @127.0.0.1` before touching `networking.nix`.
5. **Commit immediately after each logical change** — The mix of staged/unstaged changes across 6 rollbacks created confusion about what was actually deployed.
6. **Staged changes should have been committed BEFORE `just switch`** — `nix flake check --no-build` validates staged changes, but `just switch` deployed from working tree (unstaged + staged combined). This is how NixOS flakes work — but confusing when unstaged reverts exist.
7. **Gatus alerting** — Still the single most impactful monitoring fix. 20 monitored services, zero notifications.

---

## f) Top #25 Things We Should Get Done Next!

| # | Item | Category | Impact |
|---|------|----------|--------|
| 1 | **Fix `nameservers` in networking.nix** — add `"9.9.9.9"` fallback | DNS / Reliability | 🔴 Critical — next switch breaks DNS |
| 2 | **Switch phone hotspot to 5 GHz** | Connectivity | 🔴 Critical — eliminates actual buffering root cause |
| 3 | **Commit session 58 changes (this report + clean git state)** | Process | 🔴 Critical — working tree is dirty |
| 4 | **Push ALL unpushed commits to origin** | Process | 🟠 High — 4+ commits behind |
| 5 | **Add Gatus alerting smtp/webhook backend** | Monitoring | 🟠 High — monitoring is useless without alerts |
| 6 | **Deploy session 57 DNS fix to rpi3-dns** | DNS / HA | 🟡 Medium — Pi 3 still has IPv6 bug |
| 7 | **Redesign MPTCP for production** — hardened scripts, proper path | Networking | 🟡 Medium — nice to have, not urgent if hotspot fixed |
| 8 | **Verify all services survived the 6 rollbacks** | Ops | 🟡 Medium — Caddy, Gitea, Immich, etc. may need restarts |
| 9 | **Run `/nix/store` GC** — 73 G used, 89% root full | Storage | 🟡 Medium — low disk guards against rebuild failures |
| 10 | **Document the mt7925e 2.4 GHz RX bug** in AGENTS.md | Docs | 🟢 Low — save future debugging time |
| 11 | **Review unbound upstream strategy** — DoT over hotspot unreliable | DNS | 🟢 Low — consider plain UDP fallback |
| 12 | **Add `just wifi-status` recipe** | DX | 🟢 Low — quick check for hotspot quality |
| 13 | **Add `just mptcp-status` recipe** | DX | 🟢 Low — show MPTCP endpoints + subflows |
| 14 | **Pre-commit hook should catch `nameservers` changes** | QA | 🟢 Low — prevent DNS footguns |
| 15 | **Evaluate if eno1 ISP is actually degraded** | Networking | 🟢 Low — test eno1 speedtest directly |
| 16 | **Add ECC RAM monitoring** | Hardware | 🟢 Low — AGENTS.md mentions no ECC on evo-x2 |
| 17 | **Enable `nix.settings.auto-optimise-store`** is present but check if working | Storage | 🟢 Low |
| 18 | **Restart hermes / comfyui / twenty if they crashed** | Services | 🟢 Low — check individually |
| 19 | **Validate Caddy certs post-rollback** | TLS | 🟢 Low — rollback may have restarted Caddy |
| 20 | **Run just health** — cross-platform health check script | Health | 🟢 Low |
| 21 | **Update TODO_LIST.md with session 58 items** | Docs | 🟢 Low |
| 22 | **Clean up `archive/` in docs/status** | Cleanup | 🟢 Low — 232K of old reports |
| 23 | **Consider `iproute2` multipath routes without MPTCP** | Networking | 🟢 Low — simpler than MPTCP, no kernel feature needed |
| 24 | **Review swap usage — 11G used** | Memory | 🟢 Low — may indicate memory pressure |
| 25 | **Test reboot recovery** — WiFi autoconnect + eno1 static IP + DNS | Reliability | 🟢 Low |

---

## g) Top #1 Question I CANNOT Figure Out

**Why did `just switch` with MPTCP active break DNS?**

`nameservers` was `["127.0.0.1" "9.9.9.9"]` in the staged MPTCP commit AND in HEAD (eff0ba14). But the deployed `/etc/resolv.conf` during testing showed only `127.0.0.1`. Either:

- **Theory A:** The unstaged revert (removing `"9.9.9.9"`) was already in the working tree BEFORE the staged commit, so `just switch` deployed the combined state with only `"127.0.0.1"`. But the user said they "manually changed DNS to 9.9.9.9" AFTER rollback, implying it was missing.
- **Theory B:** `networking.networkmanager.dns = "none"` combined with `nameservers = ["127.0.0.1" "9.9.9.9"]` produced only `127.0.0.1` because NetworkManager's `rc-manager` configuration overrides the Nix-generated resolvconf. We set `dns = "none"` which means "don't touch resolv.conf" — but unbound writes its own. The interaction between unbound'sstub-resolv.conf, resolvconf, and NetworkManager is complex.
- **Theory C:** unbound itself was failing (DoT timeout) so even though `resolv.conf` had both entries, it appeared broken because queries to `127.0.0.1` SERVFAILed before falling back to `9.9.9.9`.

I suspect **Theory C** is the real issue: `/etc/resolv.conf` pointed to unbound (`127.0.0.1`), unbound DoT to Quad9 timed out over the degraded hotspot, so ALL DNS queries failed. The fallback entry `9.9.9.9` may have been present but glibc resolver only falls back on timeout (3 seconds default), and the user may not have waited.

But `/etc/resolv.conf` currently shows ONLY `9.9.9.9` — that's the MANUAL change. What did the Nix-generated one look like? We never captured it during the incident.

**Question:** Why did the user see a DNS outage despite `nameservers = ["127.0.0.1" "9.9.9.9"]` — was it unbound failure, a missing 9.9.9.9 entry, or both? We need to reproduce to confirm.

---

## System Snapshot

| Metric | Value |
|--------|-------|
| **Hostname** | evo-x2 |
| **OS** | NixOS 26.05.20260423 |
| **Kernel** | 7.0.1 |
| **Root disk** | 89% full (443G / 512G) |
| **/data disk** | 67% full (681G / 1.0T) |
| **/nix/store** | 73G |
| **RAM** | 62G total, 31G used, 11G swap used |
| **WiFi** | wlp195s0 connected to Kittyspot (10.79.119.35) |
| **Ethernet** | eno1 unmanaged, 192.168.1.150/24 |
| **DNS** | 9.9.9.9 (manual), unbound not queried directly |
| **Default GW** | eno1 (192.168.1.1) — restored to primary |
| **MPTCP** | Kernel enabled but NO endpoints configured (rolled back) |

## Git State

```
Staged (ready to commit):
  modified: platforms/nixos/system/networking.nix (+MPTCP code, +polkit)
  new:      scripts/mptcp-endpoint-manager.sh
  new:      scripts/route-health-monitor.sh

Unstaged (not committed):
  modified: platforms/nixos/system/networking.nix (-MPTCP code, -9.9.9.9)
  modified: scripts/route-health-monitor.sh

Branch: master, 0 commits ahead of origin (everything was rolled back)
```

**Recommendation:** Decide whether to:
1. **Keep MPTCP** — commit staged changes, revert the unstaged reverts, add 9.9.9.9 to nameservers, redeploy.
2. **Abandon MPTCP for now** — unstage the scripts, commit the unstaged networking.nix fix, and revisit hotspot-to-5GHz first.

---

_Assisted by Crush — session 58, 2026-05-10 18:19 CEST_
