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

## Part 2 — Secondary router `192.168.1.254` (4G CPE, vendor LuCI build)

Credential `admin/admin` works over LuCI and over the ubus JSON-RPC endpoint. All settings below were read from the
device's own CBI endpoints (`/cgi-bin/luci/admin/...`).

### 2.1 Identity

| Item | Value |
| --- | --- |
| Address | `192.168.1.254/24`, MAC `9C:E5:49:61:91:78` (IEEE RA "anonymous" MA-L ⇒ no vendor attribution) |
| UI | LuCI, title `4G-LTE`, copyright 2022, **Firmware 1.0.273-20240928-115300** (built 2024-09-28) |
| Userland | LuCI build `git-24.271.34822-f9d19ca` (OpenWrt 24.10 generation) — **vendor fork, not upstream OpenWrt** |
| Radios | **2.4 GHz only**, single radio (menu offers only "Wireless 2.4G") |
| Services | 80 LuCI, 22 dropbear, **23 telnet**; 443 refused |
| Clock | Europe/Berlin, correct (`2026-10-29 19:49`) |
| Firmware update | manual file upload only (`/admin/system/upgrade`) — no upstream OpenWrt image unless the SoC is a supported target |
| 4G | **"SIM Detached"** — no SIM, so no cellular backup exists today |

### 2.2 Settings inventory

| Area | State |
| --- | --- |
| LAN/WAN switch | **LAN mode** — the WAN/LAN port is configured as LAN, so the box is a plain client on the 192.168.1.0/24 segment and routes nothing |
| LAN | 192.168.1.254/24 |
| DHCP server | **Enabled** (`dhcp.lan.ignore=0`, toggle on) — pool `.101–.200` (start 101, limit 100), lease 12 h |
| DHCP DNS | **`10.43.255.55`** (corporate/on-prem resolver, unreachable here) + `9.9.9.9` |
| Static lease | `192.168.1.100` → `local-nixos0` |
| **Remote Web** | **ENABLED** (`filter.remoteweb.enabled=1`, toggle-on) with `Listen Port = 1` |
| **Port forwards** | **7 rules, all to `192.168.1.100`**: TCP 22, TCP 443, TCP 6443, TCP+UDP 41641 (tailscale), TCP+UDP 9500/9501/9502 (Longhorn) — names `ssh-onprem-0`, `onprem-0-k8s`, `onprem-0-tailscale`, `onprem-0-Longhorn[-webhooks]` |
| DMZ | off |
| MAC / IP / domain filters | all **Disabled** |
| PPTP/L2TP client | off, no fields set |
| QoS / DDNS / WiFi schedule / TTL override | all off; static routes: none |
| Watchdog (ping check) | **ON** — target `@dns`, ICMP, interval 10 s, period 60 s |
| Watchcat | **ON** — "reboot on internet connection lost", period **6 h**, ping `8.8.8.8` every 3 s, forced reboot delay 30 s |
| IPv6 (LAN) | **Dynamic IP (SLAAC/DHCPv6)** — enabled |
| Admin account | `admin` / `admin` |
| Wi-Fi | SSID **`Europol \| Law enforcement`** (broadcast), WPA2 confirmed by over-the-air scan; 0 clients; WPS is a one-shot PBC button (no persistent WPS toggle) |
| Wireless Repeater (WISP) | idle, no upstream configured |

### 2.3 Findings

**Critical — this box is one cable away from being internet-exposed with default credentials**

1. **Remote Web (WAN-side web admin) is enabled**, on a device whose only admin credential is `admin/admin`. Today the
   WAN port is in LAN mode and no upstream forwards to it, so it is not reachable from the internet — but the moment it is
   switched to WAN mode with a working 4G SIM (or placed behind a port forward), the LuCI login is published to the
   internet with a default password. *Fix before any WAN: Remote Web → off, admin password → strong.*
2. **Seven stale port forwards to `192.168.1.100`** publish SSH, the k8s API (6443), HTTPS, tailscale and Longhorn
   (9500–9502) the instant a WAN appears. They are leftovers from when this box was the internet-facing router of an
   on-prem cluster (`local-nixos0` static lease, `10.43.255.55` corporate DNS). *Fix: delete all 7.*
3. **Two DHCP servers are configured on one L2 segment.** The gateway serves `.10–.253`; this box is configured to serve
   `.101–.200` (toggle on, `ignore=0`) while its port is in LAN mode. Whichever answers first wins, and a client that
   leases from this box gets gateway `.254` (no WAN, in LAN mode) and DNS `10.43.255.55` (unroutable) — i.e. exactly the
   "connected but no internet" symptom. *Fix: DHCP server off until the box is actually the router.*
4. **Telnet (23) is exposed.** A login prompt answers, but `admin/admin` is rejected and the connection drops, so no shell
   was obtained — irrelevant, a plaintext daemon that serves nothing is pure attack surface. *Fix: disable telnetd.*
5. **Watchcat will reboot the box every 6 h while it has no internet.** Fine as a last-resort watchdog once the box is
   the live router; a self-reboot loop generator while it is being commissioned. Revisit after the SIM is in.

**Medium / low**

6. DHCP DNS `10.43.255.55` + `9.9.9.9` are wrong for this network (must be `192.168.1.150`/`.151`, see Part 1 finding 3).
7. Static lease for `local-nixos0` at `.100` — the address this repo's gatus checks assume for a different host.
8. IPv6 is enabled on the LAN; on a 4G uplink that is a second, often more permissive, path to the internet — decide
   deliberately (disable, or make sure the IPv6 firewall input policy is restrictive).
9. The **wireless settings page is broken** (`/admin/network/wireless/config` throws a Lua dispatcher error:
   `bad argument #2 to 'get' (string expected, got nil)`). SSID/PSK changes must go through SSH/uci until the firmware is
   replaced or updated.
10. TTL override is off — if the mobile plan does tethering detection, a 4G backup will be shaped/blocked; the page exists
    for exactly that (IPv4 TTL / IPv6 HL).
11. Firmware 1.0.273 is from 2024-09-28; no in-place upstream OpenWrt path is confirmed (SoC unknown).

---

## Part 3 — Architecture: what should actually carry the LAN?

**The decisive fact: the 4G box is 2.4 GHz-only with a single radio and a budget SoC, while the ISP gateway currently
serves 7 clients on 5 GHz.** Making the 4G box the primary router therefore trades the whole household's Wi-Fi for a
failover path. Three coherent designs, in order of what they cost:

| Option | Shape | Cost / trade-off |
| --- | --- | --- |
| **1 — 4G as the router, ISP box keeps only modem + Wi-Fi AP duty** (closest to the original idea) | 4G box takes `192.168.1.1`, owns DHCP + DNS; ISP box LAN moves to a second subnet (e.g. `192.168.0.1`) and stays the Wi-Fi AP | Works and needs no ISP action, **but** the ISP box's Wi-Fi clients then sit in the 4G box's LAN while the ISP box still does NAT for the 4G box's WAN — a triangular path, and 2.4 GHz-only clients on the 4G radio if the ISP radio is ever turned off. All LAN traffic passes a budget SoC. |
| **2 — Failover at the server, keep the ISP gateway as-is** | Nothing changes for the LAN; evo-x2 already has `wifi-failover-watch` (deletes the pinned `default via 192.168.1.1` on carrier loss and lets the Wi-Fi fallback route take over) | Zero risk to the household, **but** only evo-x2 survives a cable outage; phones, TV and the MacBook do not. This is the cheapest real backup and it already exists. |
| **3 — A proper OpenWrt router with 5 GHz + the 4G CPE as its second WAN** | Buy/reuse a 5 GHz-capable OpenWrt device as the router; the 4G CPE becomes either a USB/modem or an `mwan3` member | The only shape that gives whole-house failover without degrading Wi-Fi. Requires hardware; the 4G CPE's own 4G modem may not be extractable, in which case it stays the second WAN via its LAN port. |

**Hard constraints from this repo, whichever shape wins**

- `networking.local.gateway = 192.168.1.1` (`platforms/nixos/system/local-network.nix`) and
  `scripts/wifi-failover-watch.sh` pins `default via 192.168.1.1 dev eno1` → **the new primary must hold `192.168.1.1`**,
  or both the NixOS config and the failover daemon need editing in the same change.
- The new primary's DHCP must serve `.10–.99` and advertise **DNS `192.168.1.150` / `.151`** — that retires Part 1
  findings 3 and 4 in one step.
- **Never two DHCP servers on one segment.** During any cutover: disable one, move the box, then enable the other.
- The ISP box has **no bridge/modem-only page** (Part 1.3, all 24 pages enumerated), so "Vodafone box as pure modem" needs
  the ISP to flip it; otherwise NAT-behind-NAT is the honest fallback.
- No inbound exposure is needed (services are reached over Tailscale/Netbird), so **no DMZ is required on either box** —
  keep both WANs closed.

---

## Recommended sequencing

**Stage 0 — stop the bleeding on the 4G box (no topology change, ~5 min)**
Remote Web off · delete the 7 forwards · DHCP server off · admin password changed · telnet disabled.
*Verify:* `/admin/network/remoteweb` toggle-off, forwards table empty, DHCP toggle off, telnet refuses.

**Stage 1 — make the ISP gateway correct (Part 1 fixes, ~10 min)**
WPS off both bands · DHCP pool `.10`/size 90 · DHCP DNS `.150`/`.151` · 2.4 GHz encryption AES-only · port scan detection on.
*Verify:* `nmcli dev wifi list` still shows the SSIDs as WPA2, a client renew shows the new DNS, leases land in `.10–.99`.

**Stage 2 — decide the topology (owner call, this is the Part 3 table)**
Option 2 is free and immediate; Option 1 needs the LAN/DHCP re-plan above; Option 3 needs hardware.

**Stage 3 — commission the 4G backup**
SIM + APN (currently "SIM Detached") · TTL override if the carrier shapes tethering · watchcat period reviewed ·
failover drill: unplug the coax, confirm uplink switches, plug back in.

**Stage 4 — hygiene**
Identify `192.168.1.16` · resolve the Pixel-6 `.29` record · add the router to the monitoring/todo docs.

---

## Part 4 — Option 1 end-state spec (4G CPE as primary router, ISP box as modem + link)

Chosen 2026-10-29. **Nothing in this part has been applied.**

### 4.1 The consequence that shapes everything

A router cannot have its WAN and its LAN in the same subnet. Today **both** boxes sit in `192.168.1.0/24` and the Compal
is the household AP. Once the CPE is the router, the Compal's LAN is by definition the CPE's *upstream* segment — so the
Compal's Wi-Fi would land on the modem side: no LAN services (`*.home.lan`), and no 4G failover when the cable dies.
That is exactly the goal, so **the Compal's radios must be turned off** and the household Wi-Fi must be served from the
CPE (2.4 GHz only) or from a new 5 GHz AP plugged into the CPE's LAN.

| Wi-Fi choice | Consequence |
| --- | --- |
| **A** — CPE 2.4 GHz only (free) | Whole house fails over, but every client drops to a single 2.4 GHz radio on a budget SoC |
| **B** — add a 5 GHz OpenWrt AP on the CPE's LAN port (recommended) | Whole house fails over and keeps 5 GHz; ~30–60 € hardware, one extra device to document |
| **C** — leave the Compal's 5 GHz on | Fast internet for 5 GHz clients, but they lose LAN services and never fail over. Not recommended — it splits the house into two networks |

### 4.2 Address plan

| Segment | Device | Address | Notes |
| --- | --- | --- | --- |
| Modem ↔ router link | Compal DMC7002KLG LAN | `192.168.0.1/24`, DHCP **on**, pool `.2` limit `1`, DNS irrelevant | Only the CPE's WAN port lives here |
| Modem ↔ router link | CPE WAN (wired) | DHCP client → `192.168.0.2` | Primary uplink |
| Modem ↔ router link | CPE 4G | LTE | Automatic backup, preferred-source = wired |
| House LAN | CPE LAN / Wi-Fi | **`192.168.1.1/24`** | Unchanged from the repo's `networking.local.gateway` |
| House LAN | CPE DHCP | **start `.10`, limit `90`** ⇒ `.10–.99` | Keeps `.53/.100/.150/.151/.200` free |
| House LAN | CPE DHCP DNS | **`192.168.1.150`, `192.168.1.151`** | Retires Part 1 findings 3 + 4 |
| House LAN | Compal Wi-Fi | **off** | Consequence 4.1 |
| House LAN | evo-x2 / rpi3 | static `.150` / `.151` | No repo change needed — gateway stays `.1` |
| House LAN | CPE static route | `192.168.0.0/24 via 192.168.0.1` | Keeps the modem's admin UI reachable from the LAN |

No DMZ and no port forwards on either box: inbound is not needed (services ride Tailscale/Netbird).

### 4.3 Steps

**Stage A — preparation, no outage**

1. Compal: SYSTEM → Backup, download the encrypted config (store off-repo; treat as sensitive).
2. CPE: photograph the label → SoC, RAM, LAN port count. Needed for the throughput go/no-go and to know whether an
   upstream OpenWrt image could ever replace this firmware.
3. CPE Stage-0 hardening: Remote Web off, delete the 7 forwards, telnetd off, admin password changed.
4. *Verify:* `/admin/network/remoteweb` toggle off; forwards table empty; `bash -c 'exec 3<>/dev/tcp/192.168.1.254/23'` refused.

**Stage B — build the future LAN while the old one still runs, no outage**

5. CPE: DHCP server **off** (`ignore=1`) — this alone stops today's two-DHCP race.
6. CPE: DHCP DNS → `.150`/`.151`; DHCP range `.10`/`90` (stored for later).
7. CPE: Wi-Fi per choice A/B/C (SSID/PSK changes need SSH/uci — the LuCI wireless page is broken).
8. *Verify:* no second DHCP server on the segment; CPE still reachable at `.254`.

**Stage C — cutover (~10 min outage, single sit-down)**

9. Compal: DHCP off for now; LAN IP → `192.168.0.1` (this reboots the gateway, ~2 min).
10. Recable: Compal LAN1 → CPE **WAN** port; CPE **LAN** port → the house switch that evo-x2 sits on.
11. CPE: switch the WAN/LAN port to **WAN mode**; LAN → `192.168.1.1`; enable DHCP `.10–.99` with DNS `.150`/`.151`.
12. Compal: re-enable DHCP with pool `.2` limit `1`; turn both radios off.
13. CPE: add the static route from 4.2.
14. *Verify:* `ping 192.168.1.1`; `getent hosts home.lan`; `nix flake check --no-build` (narinfo path proves DNS+TCP);
    a fresh DHCP client gets `.10–.99` with DNS `.150`; `nmcli dev wifi list` shows only the CPE SSID; gatus green.
15. **Throughput gate:** `iperf3` through the CPE (evo-x2 ↔ another LAN host). If wired NAT is materially below the cable
    plan, roll back to the Compal (`192.168.1.1`) — the rollback is steps 9–12 in reverse with the CPE back in LAN mode.

**Stage D — 4G backup (only after C succeeds)**

16. SIM inserted (currently "SIM Detached"), APN set, verify registration and a data path.
17. TTL override on if the carrier shapes tethering (IPv4 TTL 65 / IPv6 HL 64 is the usual evasion value — check the
    tariff first; some carriers police it).
18. Watchcat: period 6 h is a self-reboot generator if both uplinks are down. Decide: keep (last-resort) or raise.
19. Failover drill: unplug the coax → confirm the LAN moves to 4G and comes back when the coax returns. Record the
    failover and failback times.

**Stage E — hygiene**

20. Identify `192.168.1.16`; reconcile the `.29` Pixel-6 record (Part 1.5).
21. Document the new topology in `docs/services/` + the todo domain library; add the CPE to monitoring.

### 4.4 Repo impact

- **No NixOS change required**: `networking.local.gateway = 192.168.1.1` and `scripts/wifi-failover-watch.sh`'s pinned
  `default via 192.168.1.1 dev eno1` both keep working, because the CPE takes `.1`.
- `services.dns-blocker.devices` still lists `lan-router` at `192.168.1.1` — that entry now describes the CPE; it should
  be renamed (and the Compal's `192.168.0.1` added) in the same change that documents the new topology.
- `docs/todo/services.md`'s `dhcp_lease_file` note ("no DHCP server here") stays true for evo-x2, but the *LAN* now has a
  DHCP server whose leases live on the CPE — worth a runbook line.

### 4.5 Rollback

Every stage is reversible without touching the repo: Compal back to `192.168.1.1` + DHCP `.10/244` + radios on, CPE back
to LAN mode with DHCP off. The server's static config never changes, so no NixOS rebuild is ever part of a rollback.

### 2.4 Hardware (harvested from `/admin/system/status/syslog`)

| Item | Value |
| --- | --- |
| SoC | **MediaTek MT7628AN ver:1 eco:2** (MIPS 24KEc, 580 MHz) |
| RAM | **60,708 KiB ≈ 64 MB** |
| Flash | **8 MB** SPI (`spi32766.0`, 6 MTD partitions) |
| Partition layout | `u-boot` 0x0–0x30000 · `u-boot-env` 0x30000–0x40000 · **`factory` 0x40000–0x50000** · `kernel` 0x50000–0x1893d0 · `rootfs` 0x1893d0–0x7e0000 · `rootfs_data` 0x6e0000–0x7e0000 (**1 MB overlay**) · `backup` · `bdinfo` |
| Kernel | **4.4.140**, built 2024-09-28 by `abu@openwrt`, GCC 5.4.0 (LEDE 17.01-era BSP) — EOL since 2018 |
| Kernel cmdline | `console=ttyS0,115200 rootfstype=squashfs,jffs2` ⇒ serial console exists |
| 4G module | **Quectel** over USB: `GSM modem (1-port)` → ttyUSB0/1/2 plus `cdc_ether` netdev (EC25-class) |
| Wi-Fi | vendor proprietary `MT7628 AP Driver 4.1.0.0` (`ra0`); **no PCIe card** — 2.4 GHz is a hardware ceiling |

**Consequences for "run our own software on it":**

- Upstream OpenWrt target `ramips/mt76x8` covers MT7628AN broadly, so a real image is very likely flashable — the standard
  8 MB layout (`factory` at 0x40000, `firmware` at 0x50000) is the same one used by the WE-826/KuWFi/ZBT CPE family.
- **8 MB flash is the binding constraint**: ~1 MB free overlay today. Fine for routing (mwan3, firewall, WireGuard,
  node_exporter); **not** for anything Go-sized.
- **`factory` must be dumped before any flash** (radio calibration), and the whole 8 MB should be imaged first; the UART
  on ttyS0 @115200 is the recovery path if u-boot's TFTP/web recovery is unreachable.
- **dnsblockd does not belong on this box** (64 MB RAM, 8 MB flash, 580 MHz vs a Go binary + blocklists + SQLite). It
  already runs on evo-x2 + rpi3-dns behind the VRRP VIP; the CPE's job is DHCP with DNS `.150`/`.151`, NAT, failover,
  firewall, exporter.
