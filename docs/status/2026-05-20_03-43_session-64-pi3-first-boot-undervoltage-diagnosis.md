# Session 64 — Pi 3 DNS Node: First Boot & Undervoltage Diagnosis

**Date:** 2026-05-20 03:43 CEST
**Session Focus:** Raspberry Pi 3 DNS failover node — first boot attempt, undervoltage diagnosis
**Status:** Pi 3 partially boots but is unstable due to undervoltage

---

## Executive Summary

The Raspberry Pi 3 DNS failover node (`rpi3-dns`) has been built, flashed to SD card, and physically powered on for the first time. The Pi bootstraps enough to register on the network (ARP entry with Raspberry Pi Foundation MAC `b8:27:eb:4e:4f:53` at `192.168.1.151`), but SSH and ping are unreachable. The **root cause is undervoltage** — the red PWR LED is off, indicating the Pi is not receiving stable 5V. The Pi likely hangs during first-boot partition expansion or SSH key generation due to insufficient power. A proper 5V 2.5A+ power supply is needed before deployment can proceed.

---

## a) FULLY DONE

| Item | Details | Commit |
|------|---------|--------|
| Shared DNS resolver module | `platforms/common/dns-resolver.nix` — eliminates config drift between evo-x2 and rpi3-dns. Enforces `nameservers = ["127.0.0.1"]`, `do-ip6 = false`, DNSSEC, prefetch, qname-minimisation | `e69fe17e` |
| SSH key centralization | All keys in `nix-ssh-config` repo, referenced via `sshKeys.lars` + `sshKeys.lars-evo-x2` in rpi3 config | `daf242d8` |
| rpi3-dns NixOS image build | `nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage` — 3.4 GiB SD image with unbound + keepalived | Session 57 |
| SD card flash | Written to `/dev/mmcblk0` (after fixing device node that was a regular file) | Session 57 |
| USB stick hardware verification | SanDisk Ultra Fit 128GB verified genuine via f3probe + f3write/f3read + badblocks 4-pass | Session 54 |
| Unsloth Studio removal | ~200 lines of PyTorch ROCm setup removed from ai-stack.nix, ai-models.nix, AGENTS.md, FEATURES.md, README.md, docs, justfile | Session 57 |
| Forgejo migration | Complete Gitea → Forgejo migration: admin password, runner token, WatchdogSec fix, health check update, Caddy subdomain rename | Sessions 58-61 |
| Vendor hash cascade fix | All 13 overlay packages building after upstream `go-output` changes propagated | Session 63 |
| Dual-platform build fix | `nix flake update` broke both Darwin and NixOS — resolved | Session 62 |
| Lockfile deduplication | 10-16 GB evaluation memory saved by consolidating flake-utils, treefmt-nix, nixpkgs follows chains | Session 47 |
| DNS config drift fix | `resolvconf` reordering bug — only `["127.0.0.1"]` is safe, not `["127.0.0.1" "9.9.9.9"]` | Session 57 |

---

## b) PARTIALLY DONE

| Item | Status | Blocker |
|------|--------|---------|
| **Pi 3 DNS node deployment** | Image built + flashed + powered on. ARP proves Pi reaches network (`b8:27:eb:4e:4f:53` at `.151`). But SSH/ping unreachable — undervoltage causes hangs. | **Needs 5V 2.5A+ PSU** |
| **VRRP failover testing** | Module configured (evo-x2 priority 100, Pi 3 priority 50, VIP `192.168.1.53`). Keepalived runs on evo-x2. Pi 3 config ready but can't test until Pi is stable. | Blocked on PSU |
| **sops-nix for Pi 3** | VRRP auth password (`DNSClusterVRRP-evox2`) still in plaintext via `pkgs.writeText`. Planned migration to sops after Pi SSH host key extraction. | Blocked on SSH access |
| **Gatus monitoring for Pi 3** | Plan to add unbound health check endpoint for `192.168.1.151` in `gatus-config.nix`. | Blocked on stable Pi |
| **ai-models.nix huggingface bug** | Pre-existing attribute error from Unsloth removal — `huggingface` attribute referenced but no longer defined in paths attrset. Needs fix before next `just switch` on evo-x2. | Not yet fixed |

---

## c) NOT STARTED

| Item | Priority | Notes |
|------|----------|-------|
| Fix ai-models.nix `huggingface` attribute error | **HIGH** | Will break `just switch` on evo-x2 if not fixed |
| Extract Pi 3 SSH host key for sops-nix | Medium | Needs SSH access first |
| Migrate VRRP auth from plaintext to sops | Medium | Depends on sops setup |
| Add Pi 3 unbound health check to Gatus | Medium | Monitoring gap |
| Update AGENTS.md Pi 3 status to "Deployed" | Low | After successful SSH |
| Pi 3 USB boot migration | Low | Optional — SD card works fine |
| Pi 3 DNS blocklist parity check | Low | Verify same blocklist count as evo-x2 |

---

## d) TOTALLY FUCKED UP

| Item | What Happened | Impact | Fix |
|------|---------------|--------|-----|
| **`/dev/mmcblk0` was a regular file** | Device node was a regular file (3.3 GB), not block special. All `dd` writes silently went to a file. Hours wasted on "No space left on device" errors. | 3+ hours of failed flash attempts | `rm /dev/mmcblk0 && mknod /dev/mmcblk0 b 179 32` |
| **Pi 3 undervoltage** | No red PWR LED on Pi 3. Power supply can't deliver stable 5V 2.5A+. Pi bootstraps to network (ARP visible) then hangs under load. | Deployment blocked entirely | Need proper 5V 2.5A+ PSU with short thick cable |
| **Pi 3 USB boot impossibility** | Original Pi 3B (not 3B+) does NOT support USB boot without OTP programming. Wasted time trying USB stick boot — no green ACT light. | Wasted ~1 hour | Use SD card (now doing this) |
| **WiFi interface naming bug** | `wlan0` vs `wlp195s0` mismatch made dual-WAN scripts silent no-ops since inception. Both `route-health-monitor` and `mptcp-endpoint-manager` never worked. | Dual-WAN was non-functional until discovered | Fixed to `wlan0` everywhere |
| **`resolvconf` nameserver reordering** | `nameservers = ["127.0.0.1" "9.9.9.9"]` caused resolvconf to place Quad9 first when WAN flaps, bypassing unbound entirely. | DNS queries bypassed local resolver | Fixed to `["127.0.0.1"]` only |

---

## e) WHAT WE SHOULD IMPROVE

1. **Power supply verification** — Should have verified PSU specs before deployment attempt. The missing red PWR LED is the definitive diagnostic.
2. **Pi 3 hardware capabilities** — Should have checked USB boot support for the specific Pi 3 model (3B vs 3B+) upfront.
3. **Block device validation** — Should have run `stat /dev/mmcblk0` before every `dd` write. The regular-file device node wasted hours.
4. **First boot expectations** — Should have set expectations: first boot with partition expansion on 128GB SD takes 5-10 minutes even with good power.
5. **ICMP in firewall** — Pi 3 firewall doesn't allow ICMP. Could add it for diagnostics: `allowedICMPTypes = [ "echo-request" ]`.
6. **Console access plan** — Should have planned HDMI + keyboard access for first boot debugging.
7. **Pre-flight checklist** — Before next deployment attempt, should have: (a) verified PSU specs, (b) connected HDMI, (c) had keyboard ready, (d) added ICMP to firewall.

---

## f) Top 25 Things to Get Done Next

### Immediate (Blocks Everything)

1. **Get a 5V 2.5A+ power supply** for Pi 3 — official Raspberry Pi PSU or equivalent
2. **Get a short, thick micro-USB cable** — minimize voltage drop
3. **Fix ai-models.nix huggingface attribute error** — will break next `just switch` on evo-x2

### Pi 3 Deployment (Once PSU arrives)

4. **Power on Pi 3 with proper PSU**, wait 5-10 min for first boot
5. **Verify SSH access**: `ssh root@192.168.1.151` from both machines
6. **Verify unbound DNS**: `dig google.com @192.168.1.151` from evo-x2
7. **Verify keepalived VRRP**: `systemctl status keepalived` on Pi 3 (BACKUP, priority 50)
8. **Verify blocklist parity**: compare unbound stats between evo-x2 and Pi 3
9. **Test failover**: stop unbound on evo-x2, verify VIP `192.168.1.53` migrates to Pi 3
10. **Test failback**: restart unbound on evo-x2, verify VIP returns

### Security & Monitoring

11. **Extract Pi 3 SSH host key**: `ssh-keyscan 192.168.1.151`
12. **Add Pi 3 age identity to `.sops.yaml`** for sops-nix
13. **Migrate VRRP auth password to sops-nix** — remove plaintext `pkgs.writeText`
14. **Add Pi 3 unbound health check to Gatus** — `gatus-config.nix`
15. **Add Pi 3 ICMP to firewall** for monitoring: `networking.firewall.allowedICMPTypes`
16. **Add Pi 3 to router DNS forwarding** — point to VIP `192.168.1.53` as secondary

### Codebase Cleanup

17. **Fix ai-models.nix** — remove `huggingface` references from Unsloth removal
18. **Update AGENTS.md** — Pi 3 status from "Planned" to "Deployed" + add gotchas
19. **Add Pi 3 deployment docs** — PSU requirements, first boot expectations
20. **Update FEATURES.md** — DNS failover cluster status

### Infrastructure Improvements

21. **Test full failover scenario**: unplug evo-x2 ethernet, verify Pi 3 takes over DNS
22. **Configure DHCP option 6** on router — advertise VIP `192.168.1.53` as DNS server
23. **Add rpi3-dns to SigNoz monitoring** — node_exporter on Pi 3 (if memory allows)
24. **Test VRRP split-brain scenario** — both nodes think they're MASTER
25. **Document recovery procedures** — what to do when Pi 3 dies, VIP flaps, etc.

---

## g) Top #1 Question I Cannot Answer Myself

**What power supply are you using for the Pi 3, and do you have a proper 5V 2.5A+ PSU available (or can acquire one)?**

The missing red PWR LED is definitive proof of undervoltage. The Pi 3B needs a genuine 5V 2.5A supply — most phone chargers and USB ports can't deliver this. The official Raspberry Pi PSU (5.1V 2.5A) is ~€10. Until this is resolved, no amount of software changes will make the Pi stable.

---

## Session Timeline

| Time | Event |
|------|-------|
| ~20:00 | SD card inserted into Pi 3, ethernet connected, power on |
| ~20:01 | Green ACT LED blinks (kernel booting) |
| ~20:03 | MacBook pings start — 100% packet loss for 4+ minutes |
| ~20:05 | Second ping attempt from MacBook — still 100% loss |
| ~20:07 | Third ping attempt continues — no response |
| ~20:10 | Diagnostic from evo-x2: ARP shows `b8:27:eb:4e:4f:53` at `.151` (STALE) |
| ~20:10 | nmap scan: only evo-x2 (.150) visible, Pi not responding |
| ~20:12 | SSH attempts from both evo-x2 and MacBook fail — "No route to host" / "Connection timed out" |
| ~20:15 | Confirmed: green ACT LED solid (boot complete), red PWR LED OFF (undervoltage) |
| ~20:16 | **Diagnosis: undervoltage** — Pi bootstraps to network then hangs under load |
| 03:43 | Status report written |

---

## Technical Details

### ARP Evidence (Pi was briefly alive)
```
192.168.1.151 dev eno1 lladdr b8:27:eb:4e:4f:53 STALE
```
- `b8:27:eb` = Raspberry Pi Foundation OUI (confirmed real hardware)
- `STALE` = entry exists but no recent response (Pi stopped responding)

### Pi 3 Power Requirements
| Spec | Required | Observed |
|------|----------|----------|
| Voltage | 5.0V | Unknown (no multimeter) |
| Current | 2.5A+ | Insufficient (PWR LED off) |
| Red PWR LED | Should be solid ON | **OFF** = undervoltage |
| Green ACT LED | Blinks during boot, solid when idle | Solid (boot completed) |
| Ethernet link | LEDs on port | Green/amber present |

### Pi 3 Network Config (from `platforms/nixos/rpi3/default.nix`)
```nix
networking = {
  hostName = "rpi3-dns";
  useDHCP = false;
  interfaces.eth0.ipv4.addresses = [{ address = "192.168.1.151"; prefixLength = 24; }];
  defaultGateway = "192.168.1.1";
  firewall.allowedTCPPorts = [22 53];
  firewall.allowedUDPPorts = [53];
};
```

### Services Expected on Pi 3
| Service | Status | Config |
|---------|--------|--------|
| unbound | Unknown (can't reach) | DNS resolver with 25 blocklists, 2.5M+ domains |
| keepalived | Unknown (can't reach) | VRRP BACKUP, priority 50, VIP 192.168.1.53 |
| sshd | Unknown (can't reach) | Port 22, root login with SSH keys only |

---

## Files Modified This Session

*None — no code changes. Only diagnostic work and this status report.*

---

## Build Status

| Target | Status |
|--------|--------|
| `nixosConfigurations.evo-x2` | ✅ Last built session 63 |
| `nixosConfigurations.rpi3-dns` | ✅ Image built, flashed to SD card |
| `darwinConfigurations.Lars-MacBook-Air` | ✅ Last built session 62 |
| Overlay packages (13/13) | ✅ All building per session 63 |

---

_Arte in Aeternum_
