# Router Configuration Review — 2026-10-29

**Scope:** the ISP cable gateway at `192.168.1.1` and the secondary 4G router found at `192.168.1.254`.
**Method:** authenticated read-only enumeration of every UI page (24 on the gateway), LAN service scan, cross-check
against this repo's network assumptions. **No setting was modified.**

---

## Part 1 — ISP gateway `192.168.1.1`

### 1.1 Identity

| Item | Value |
| --- | --- |
| Vendor / model | Compal **DMC7002KLG** (Vodafone Station / "Horizon" class, `UPC WebApp` UI) |
| Firmware | **2.9.13**, DOCSIS 3.0, BPI+ "Security Enabled" |
| Serial / HFC MAC | `44AAF5D1FB6F` / `44:AA:F5:D1:FB:6F` |
| LAN / radio MACs | `44:AA:F5:D1:FB:73` / `44:AA:F5:D9:3F:4F` (2.4 GHz), `44:AA:F5:D9:3F:50` (5 GHz) |
| Uptime | 10 d 14:47 |
| WAN IPv4 | **89.65.239.240/22** — public, not CGNAT; lease expires 2026-11-03 22:45 |
| CM management IP | 10.236.218.187 (ISP side) |
| IPv6 | none — eno1 has only link-local + a netbird ULA, so no IPv6 PD and no v6 exposure |

### 1.2 DOCSIS signal — healthy

- Downstream: 8 bonded channels, 706–762 MHz, 256QAM, SNR **38.9–39.1 dB**, power 9.4–9.9 dBmV.
- Upstream: 4 channels, 34.3–54.4 MHz, 64QAM @ 5120 ksym, power **37.7–37.8 dBmV**.
- Event log: T3/T4 ranging timeouts on 10-02 and 10-19, one DHCP-RENEW warning on 10-28. No modem resets.

### 1.3 Settings inventory

| Area | State |
| --- | --- |
| Admin access | HTTP **only** (port 80), HTTP Basic auth, realm `Horizon`. All pages — including `SystemFactoryDefault.asp`, `StatusPing.asp` — return **401 without credentials** (verified). |
| Admin credential | **admin / admin** (factory default) |
| Password policy | minimum **5** characters |
| LAN | 192.168.1.1 / 255.255.255.0 |
| DHCP server | **Enabled** — start `.10`, **pool 244** ⇒ `192.168.1.10–.253`, lease 3600 s |
| DHCP DNS handed out | **193.47.158.254 / 193.47.158.255** (Vodafone resolvers) |
| DHCP reservations | none (firmware has no static-lease feature) |
| Home Network mode | standalone gateway (correct) |
| WAN config | automatic/DOCSIS only, no user-editable WAN options |
| **WAN Blocking** | **Enabled** |
| UPnP | **Disabled** |
| Multicast / IPSec / PPTP passthrough | off |
| Firewall protection | **Enabled** |
| Block fragmented IP packets | off |
| Port scan detection | off |
| Port forwarding / triggers / IP / MAC / port filters | **0 rules** |
| **DMZ host** | **empty ⇒ disabled** |
| 2.4 GHz | SSID `UPC244705697`, broadcast, WPA2-Personal, **TKIP+AES**, PMF **off**, WPS **on (PIN+PBC)**, ch 1 @ 40 MHz, 100 % power, 0 clients, MAC ACL off |
| 5 GHz | SSID `UPC504705697`, broadcast, WPA2-Personal, **AES**, PMF **on**, WPS **on (PIN+PBC)**, ch **52 (DFS) @ 80 MHz**, 100 % power, 7 clients, MAC ACL off |
| Pre-shared keys | 8 characters each band, different per band (compared by hash only; values not recorded) |
| Client isolation | off (both bands) |
| Remote syslog | Disabled (server 0.0.0.0, port 514) |
| Config backup | downloadable, "encrypted" with a 6–12 character password |
| Telephony (MTA) | provisioning FAIL at every stage, line on-hook ⇒ no voice service |
| Open LAN ports on the gateway | **80 only** (22/23/443/7547/1900/8080/8443 closed) |
| WAN-side admin port | no response on :80/:443 (hairpin unsupported, so inconclusive alone — consistent with WAN Blocking) |

### 1.4 Findings

**High**

1. **`admin/admin` on a firmware family with a documented unauth-RCE history** (CH7465LG: CVE-2019-13025 CVSS 9.8,
   CVE-2019-17499 8.8, plus 2016 SEARCH-LAB findings incl. unauthenticated factory reset). The same single credential pair
   also guards `SystemFactoryDefault.asp`. Any LAN device — guest laptop, compromised IoT, phone — gets full gateway control,
   i.e. DNS hijack or forward injection. *Fix: SYSTEM → Password, unique 16+ char passphrase.*
2. **WPS enabled with the PIN method on both bands.** PIN WPS is the classic bypass: it hands out the PSK regardless of
   PSK strength. *Fix: WIRELESS → 2.4 GHz WPS → Disable, repeat for 5 GHz.*
3. **DHCP clients bypass the home DNS stack entirely.** The gateway advertises Vodafone resolvers, so every DHCP client
   skips dnsblockd at 192.168.1.150/.151 — no blocklists, no split-horizon `*.home.lan`, no per-device query telemetry.
   Only evo-x2 and rpi3-dns (which own their `resolv.conf`) are filtered today.
   *Fix: BASIC → Local Area Network → DNS Server 1 = `192.168.1.150`, 2 = `192.168.1.151`.*

**Medium**

4. **The DHCP pool `192.168.1.10–.253` swallows every static address in this repo** — `.53` (VRRP DNS VIP), `.100`,
   `.150` (evo-x2), `.151` (rpi3-dns), `.200` (dnsblockd block IP). One roaming phone leased `.53` breaks VRRP; `.150`
   collides with the server. The firmware cannot reserve addresses. *Fix: pool size 244 → **90** (`.10–.99`).*
5. **8-character factory-strength PSKs.** Offline-crackable from a captured handshake. *Fix: 20+ char random per band.*
6. **2.4 GHz negotiates TKIP+AES.** TKIP is deprecated; mixed mode caps the cell at WPA1-era rates. The platform has no
   WPA3, so AES-only WPA2 is the correct ceiling. *Fix: 2.4 GHz Security → Encryption = AES.*
7. **Admin UI is plaintext HTTP with Basic auth** (base64 credentials on every request). No HTTPS listener exists on this
   firmware, so it cannot be fixed on-device — treat the LAN as the trust boundary.

**Low**

8. Port scan detection and fragmented-packet filtering are off (scan detection is free log signal; fragment blocking can
   break streaming/legacy gear).
9. 5 GHz pinned to **channel 52 (DFS)** @ 80 MHz — radar detection forces a 60 s+ outage and some clients refuse DFS.
10. 2.4 GHz at **40 MHz** with **0 associated clients** — 20 MHz (or radio off) is correct there.
11. Router logging is invisible to the lab: remote syslog off and nothing listens on udp/514 on evo-x2.
12. Config-backup "encryption" caps the password at 12 characters — treat any downloaded backup as sensitive.
13. Firmware **2.9.13 cannot be user-updated** (ISP/TR-069 push only; the UI has no update page). With zero forwards,
    DMZ off, UPnP off and WAN Blocking on, WAN exposure is minimal — that combination is the compensating control and
    must stay on.
14. **The UI has no bridge / modem-only mode page** — relevant to the gateway-replacement plan in Part 3.

### 1.5 Client inventory vs. this repo's records

| IP | MAC | Note |
| --- | --- | --- |
| .16 | `44:AA:F5:EB:F6:B7` | **Unidentified** — CommScope/Compal gateway-class OUI, no open ports, absent from the dnsblockd device registry. Identify or remove. |
| .29 | `2E:FD:A5:91:47:C8` | Matches the **Pixel 6** random MAC that `docs/services/dnsblockd.md` records as *decommissioned 2026-10-01* — yet it held a live renewed lease. Either the phone is back in use or the decommission note is wrong. |
| .62 | `00:E0:4C:68:04:00` | MacBook Air via USB Ethernet (matches registry `macbook`). |
| .122 | `AC:67:84:0C:8A:61` | Google device (Nest/Chromecast/Pixel), −44 dBm, 433 Mbit/s. |
| .136/.161/.218/.241 | locally-administered MACs | phones/laptops with MAC randomisation. |

### 1.6 Verified negatives

No port forwards, no DMZ, no triggers, no filters, UPnP off, WAN Blocking on, firewall on, auth enforced on every page
including the destructive ones, only port 80 open on the LAN, no IPv6 exposure, DOCSIS signal clean, standalone-gateway
mode correct, telephony correctly unprovisioned.

---

## Part 2 — Secondary router `192.168.1.254`

| Item | Value |
| --- | --- |
| Address | `192.168.1.254` (outside the gateway's pool), MAC `9C:E5:49:61:91:78` (OUI registered to IEEE RA ⇒ privacy-protected assignment) |
| UI | **LuCI** (`/cgi-bin/luci` → 403 login page), page title **`4G-LTE`** |
| LuCI build | `git-24.271.34822-f9d19ca` ⇒ **OpenWrt 24.10** generation, vendor-branded (Bootstrap theme, "setup.css") |
| Services | 80 (LuCI), **22 dropbear**, **23 telnet**, 443 refused |
| Clock | `Sat, 07 Mar 2026` while the true date is 2026-10-29 ⇒ **no NTP / no WAN** |
| HTTP hardening headers | `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection` — present |
| DHCP | not serving on the 192.168.1.0/24 segment (gateway leases are unaffected) |

Confirmed so far: it is not a "cheap Chinese firmware" in the vulnerable sense — it is a **LuCI build of OpenWrt 24.10**,
so the OpenWrt plan is already 80 % done. Two findings to act on once credentials exist:
**telnet is open** (should be off — dropbear already provides SSH) and the box has no working clock.

**Pending:** full settings review requires the login credential and the model/SoC (label or LuCI Status → Overview).

---

## Part 3 — Architecture proposal: OpenWrt primary + ISP box as modem + 4G failover

**Verdict: sound, but the "ISP box as pure modem" step is the one that cannot be done from the UI** — the DMC7002KLG has
no bridge/modem-only page (Part 1.3). Three workable shapes:

| Option | Shape | Trade-offs |
| --- | --- | --- |
| **A — DMZ (recommended)** | OpenWrt takes `192.168.1.1`, owns DHCP + DNS; gateway keeps its WAN and DMZ-hosts the OpenWrt WAN IP | No ISP ticket; double NAT (harmless for outbound; inbound lives entirely on the OpenWrt firewall); needs the gateway's own LAN IP moved (`192.168.1.1` → e.g. `.254`) so OpenWrt can hold `.1` |
| **B — ISP bridge** | Ask Vodafone to enable bridge; OpenWrt gets the public IPv4 | Cleanest routing; DOCSIS box keeps modem duty; depends on the ISP honoring it, and the 4G backup then needs its own default-route policy |
| **C — swap the gateway** | Own DOCSIS 3.0/3.1 modem (e.g. TC4400-class) + OpenWrt | Full control, no ISP firmware in the path; extra hardware, and the ISP may insist on their modem |

**Hard constraints from this repo, whichever option wins:**

- `networking.local.gateway = 192.168.1.1` (`platforms/nixos/system/local-network.nix`) and
  `scripts/wifi-failover-watch.sh` pins `default via 192.168.1.1 dev eno1` — so the **new primary must hold `192.168.1.1`**,
  otherwise every deploy-time network assumption and the failover daemon need editing.
- DHCP must move to the new primary: it should serve `.10–.99` and advertise **DNS 192.168.1.150/.151**, which retires
  findings 3 and 4 in one step.
- The OpenWrt box's NAT throughput is the open question: if the SoC is MT7628-class the wired uplink will cap well below
  the cable line. Confirm the model before committing.
- 4G failover = `mwan3` with the LTE interface in a lower-priority member group, plus a health probe against a
  known-good target; keep the wired member metric 1 / LTE metric 2 so failback is automatic.
- Do **not** run two DHCP servers on one segment during the cutover — move the gateway's DHCP to off before enabling it on
  OpenWrt.

---

## Recommended apply order

1. WPS off, both bands *(brief Wi-Fi restart)*.
2. Gateway LAN: pool size 244 → 90; DNS1/DNS2 → `.150`/`.151` *(gateway reboot, ~2 min)*.
3. 2.4 GHz encryption → AES-only.
4. Firewall → port scan detection on.
5. New admin password + new 20+ char PSKs *(owner-supplied values; all clients reconnect)*.
6. Identify `192.168.1.16`; reconcile the `.29` / Pixel-6 record.
7. Then the Part 3 cutover (DMZ recommended), plus: telnet off on the OpenWrt box, NTP configured.
