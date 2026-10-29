# Router audit + OpenWrt feasibility, session status

**Date:** 2026-10-29 21:31 CET · **HEAD at authoring:** `1b8634ee7` · **Branch:** master
**Session shape:** read-only audit of two network devices (ISP cable gateway + a 4G CPE), one research question
(OpenWrt feasibility), zero configuration changes applied (owner instruction: plan first).
**Primary deliverable:** `docs/reviews/2026-10-29_19-40_router-configuration-review.md` (356 lines, Parts 1 to 4), committed
by the auto-commit daemon as `694a55996` with a heuristic message.

> Harvest note: the §f list below is **deliberately NOT harvested** into `TODO_LIST.md` / `docs/todo/*.md` in this pass.
> The owner asked for a report and then to wait for instructions, so the dispatch queue stays untouched on purpose.
> Harvesting is item F1 and needs a go-ahead.

---

## a) FULLY DONE

| # | Work | Evidence |
| --- | --- | --- |
| a1 | Identified the ISP gateway: **Compal DMC7002KLG** ("Vodafone Station"/Horizon class, `UPC WebApp`), firmware **2.9.13**, DOCSIS 3.0, BPI+ enabled | `StatusSystem.asp` scrape |
| a2 | Enumerated **all 24 UI pages** of the gateway and extracted every setting (WAN, LAN, DHCP, wireless x2 bands, firewall, forwarding, filters, DMZ, system, logs) | `~/.cache/router-review/*.html` |
| a3 | Verified DOCSIS health: **8 downstream** channels (706 to 762 MHz, 256QAM, SNR 38.9 to 39.1 dB, 9.4 to 9.9 dBmV) and **4 upstream** (64QAM @ 5120 ksym, 37.7 to 37.8 dBmV). Log shows only T3/T4 ranging noise on 10-02 and 10-19 | `StatusUpstream/StatusDownstream` |
| a4 | Proved auth is enforced on the gateway: **401 without credentials on every page**, including `SystemFactoryDefault.asp`, `StatusPing.asp`, `StatusTraceroute.asp` | `unauth.sh` sweep |
| a5 | LAN port scan of the gateway: **only port 80 open** (22/23/443/7547/1900/8080/8443 closed) | `scan.py` |
| a6 | Found the gateway's DHCP hands out **Vodafone DNS** (193.47.158.254/255), so every DHCP client bypasses dnsblockd | `BasicLAN.asp` |
| a7 | Found the gateway's DHCP pool **.10 to .253 swallows every static address in this repo** (.53 VRRP VIP, .100, .150, .151, .200) and the firmware has no reservations | pool size 244 read from the page |
| a8 | Found **WPS enabled with the PIN method on both bands**, **TKIP+AES on 2.4 GHz**, PMF off on 2.4, 8-char PSKs (different per band, compared by hash only), 5 GHz pinned to **DFS channel 52 @ 80 MHz** | JSON blobs embedded in the wireless pages |
| a9 | Confirmed the gateway has **no bridge / modem-only page** anywhere in the 24-page UI (this kills the "ISP box as pure modem" plan without an ISP ticket) | full menu enumeration |
| a10 | Identified the second device: **192.168.1.254**, vendor LuCI fork, banner `4G-LTE`, firmware **1.0.273-20240928-115300** | HTTP fingerprint + `/admin/system/upgrade` |
| a11 | Authenticated to it with `admin/admin` over **LuCI cookie session** and over the **ubus JSON-RPC** endpoint (session obtained, but `acls:{}` so `system.board` / `system.info` were denied) | `ubus.sh`, `luci.sh` |
| a12 | Enumerated **26 CBI config endpoints** and extracted LAN, DHCP (general + static lease), DMZ, 7 port forwards, IP/MAC/domain filters, DDNS, QoS, TTL, PPTP/L2TP, remote web, routes, IPv6, watchdog, watchcat, WPS, WiFi schedule, timezone, password, upgrade, backup | `~/.cache/router-review/api/*` |
| a13 | Found **Remote Web (WAN-side admin) ENABLED** on a box whose only credential is `admin/admin` | `filter.remoteweb.enabled=1`, toggle-on |
| a14 | Extracted all **7 stale port forwards**, every one to `192.168.1.100`: TCP 22, 443, 6443, TCP+UDP 41641 (tailscale), 9500/9501/9502 (Longhorn) | `fw2.py` grouping by cfg id |
| a15 | Found **two DHCP servers configured on one L2 segment** (gateway .10 to .253; CPE .101 to .200 with `ignore=0`), the CPE's advertising an unroutable DNS (10.43.255.55) and gateway `.254` (no WAN in LAN mode) | `s_services_dhcp_config_general.html` |
| a16 | Found **Watchcat ON, reboot on 6 h without internet**, Watchdog ON (`@dns`, 10 s interval), **telnet 23 open** (root/admin rejected; `admin` authenticates but the shell dies on a missing home dir) | `services_watchcat`, `tn.py`/`tn3.py` |
| a17 | Found the CPE's **wireless config page is broken** (Lua dispatcher: `bad argument #2 to 'get' (string expected, got nil)`), so SSID/PSK changes need SSH/uci | `/admin/network/wireless/config` 500 |
| a18 | Verified the CPE's Wi-Fi **over the air** with `nmcli`: SSID **`Europol \| Law enforcement`**, **WPA2**, channel 2, 0 clients | `nmcli dev wifi list` |
| a19 | Identified the CPE's **hardware** from its own syslog: **MT7628AN ver:1 eco:2**, **60,708 KiB RAM**, **8 MB SPI flash**, **6 MTD partitions** (`factory` at 0x40000, 1 MB overlay), **kernel 4.4.140** (LEDE 17.01 BSP, built 2024-09-28, GCC 5.4), UART on `ttyS0,115200`, **Quectel** 4G module (3x AT ttyUSB + cdc_ether), **no PCIe card** | `q_system_status_syslog.html` (165 KB) |
| a20 | Answered the owner's OpenWrt question with hard evidence: flashing upstream is feasible (`ramips/mt76x8`), 8 MB flash is the binding constraint, and dnsblockd does not belong on this hardware | report Part 2.4 |
| a21 | Cross-checked the devices against this repo: `networking.local.gateway = 192.168.1.1` (`platforms/nixos/system/local-network.nix:15`), the pinned `default via 192.168.1.1 dev eno1` in `scripts/wifi-failover-watch.sh:26`, and the dnsblockd device registry | report Part 1.5 / Part 4.4 |
| a22 | Found two record discrepancies: **`.29` still holds a live lease with the Pixel-6 randomized MAC** that `docs/services/dnsblockd.md` retired as decommissioned 2026-10-01, and **`.16`** (`44:AA:F5:…`, CommScope gateway-class OUI) is an unidentified device | DHCP lease snapshot + registry grep |
| a23 | Researched the platform's CVE history (CVE-2019-13025 CVSS 9.8 unauth RCE, CVE-2019-17499 8.8, 2016 SEARCH-LAB findings incl. unauth factory reset) and the OUI vendors | report §1.4 |
| a24 | Wrote Parts 1 to 4 of the deliverable: gateway inventory + findings, CPE inventory + findings, architecture options, and the **Option 1 end-state spec with a staged execution plan and rollback** | `docs/reviews/2026-10-29_19-40_router-configuration-review.md` |

---

## b) PARTIALLY DONE

| # | Work | What is missing |
| --- | --- | --- |
| b1 | "Review **all** settings" of the CPE | ~70 % covered. Missing: **firewall zones and rules** (no page in this fork's UI), **wireless SSID/PSK/mode** (page 500s), **installed packages**, **modem/APN profile** (SIM absent), **runtime DHCP state** (config only). All need a shell, which I never obtained |
| b2 | The two-DHCP finding | Proved from **stored config** (`ignore=0` + toggle-on), not from runtime evidence. The CPE's own syslog (165 KB, already downloaded) was never grepped for `dnsmasq` leases/ACKs |
| b3 | Hardware identity | SoC/RAM/flash/kernel confirmed. **`board_name` / product string still unknown**, which is what decides whether upstream carries an exact device entry or only a generic image |
| b4 | Root cause of "4G router has no internet" | Explained plausibly (two DHCP servers + unroutable DNS + LAN-mode port), not proven end-to-end from a failing client |
| b5 | Report location | Landed in `docs/reviews/` (owner hinted `docs/reports/`). Needs a decision on the canonical folder |
| b6 | §f harvesting into `TODO_LIST.md` + domain libraries | Deliberately skipped, awaiting instructions (repo rule satisfied by this explicit note) |
| b7 | Stage 2 plan | Written and approved in shape (Option 1 = CPE as router), but the Wi-Fi sub-decision (A/B/C) is open and it changes 3 steps of the spec |

---

## c) NOT STARTED

| # | Work |
| --- | --- |
| c1 | **Stage 0** (CPE bleed-stop): Remote Web off, delete the 7 forwards, DHCP server off, telnet off, new admin password |
| c2 | **Stage 1** (gateway correctness): WPS off both bands, pool 244 to 90, DHCP DNS to `.150`/`.151`, 2.4 GHz AES-only, port scan detection on |
| c3 | Compal admin password + new PSKs (needs owner-supplied values) |
| c4 | **Pre-flash evidence pass** on the CPE: full 8 MB dump, `factory` partition copy, u-boot TFTP/web recovery probe, `board_name` |
| c5 | Any actual OpenWrt flash / ImmortalWrt evaluation |
| c6 | 4G commissioning: SIM, APN, registration, data path, TTL override decision |
| c7 | Failover drill (unplug coax, measure failover and failback) |
| c8 | Identifying `192.168.1.16`; reconciling the `.29` Pixel-6 record |
| c9 | Monitoring: the CPE is in no gatus check, no textfile collector, no SigNoz rule |
| c10 | Topology documentation under `docs/services/` (no runbook for either device exists) |

---

## d) TOTALLY FUCKED UP

Honest list, worst first.

| # | Failure | Cost / state |
| --- | --- | --- |
| d1 | **Wrote the first report to `~/.cache/router-review/`** instead of the repo. Owner reaction: "why the fuck do you write that to `~/.cache`". Then **guessed `docs/reviews/`** when the owner said `docs/reports/` | One wasted round trip, a second guess still unconfirmed, and the owner had to police file placement twice |
| d2 | **`docs/reports/` does not exist** in this repo (`docs/reviews/`, `docs/status/`, `docs/audits/`, `docs/security/` do). I did not surface that conflict, I silently substituted a folder | The deliverable may sit in the wrong place indefinitely |
| d3 | **Chased the wrong access path for the CPE for ~15 tool calls.** Tried ubus `system.board`/`system.info` (denied by empty ACLs), then SSH with host-key algorithm workarounds (3 attempts, handshake never completed), then telnet logins as `admin` and `root`. The answer was sitting in a **plain LuCI status tab** (`/admin/system/status/syslog`) the whole time | Hardware ID took far longer than it should; and I still have no shell |
| d4 | **Downloaded a 165 KB syslog and used it exactly once** (boot lines for the SoC). Never grepped it for `dnsmasq`, `firewall`, Wi-Fi, WAN-mode or modem evidence that would have converted several "configured" findings into "runtime-proven" ones | The strongest finding (two DHCP servers) rests on config, not on logs |
| d5 | **Told the owner the CPE was "not serving DHCP on the 192.168.1.0/24 segment"**, then found `dhcp.lan.ignore=0` and had to contradict myself in the next message | A wrong statement was published mid-session |
| d6 | **Claimed the CPE had no working clock / no NTP** from an HTTP `Date:` header (2026-03-07), then found a correct Europe/Berlin clock in the timezone page and never resolved the contradiction | Unexplained inconsistency left in the record |
| d7 | **Flip-flopped the telnet verdict twice** (exposed and usable, then rejected, then "authenticates but the shell dies") | Reader cannot tell what the actual state is from the transcript alone |
| d8 | **Architecture recommendation churned**: first "bridge mode is the ask", then "DMZ is recommended", then "no DMZ is needed at all" once Tailscale/Netbird made inbound unnecessary | Correct answer at the end, two wrong intermediate recommendations on the record |
| d9 | **Truncated my own report file at Part 2** to rewrite Parts 2 and 3, discarding the original Part 2 draft (recoverable only from git history `694a55996`) | Sloppy editing pattern, no functional loss |
| d10 | **Let the auto-commit daemon write the commit message** for the deliverable (heuristic "auto-commit 1 changed file(s)") | The single most substantive artifact of the session has a useless commit message |
| d11 | **Left all evidence in `~/.cache/router-review/`**: probe scripts, 40+ HTML/JSON dumps, the 165 KB syslog. Not backed up, not in the repo, and cache is exactly as volatile as `/tmp` for practical purposes | Reproducing the audit costs another full pass |
| d12 | **No verification matrix.** Findings are not mapped to the artifact or command that proves each one, so a reviewer cannot re-check a claim without redoing the probe | Weakens every finding to "trust me" |
| d13 | **Never asked for the physical label** even after concluding the model string matters, and burned a question slot on a login instead | One cheap question would have short-circuited d3 |
| d14 | **Applied nothing**, correct per instruction, but that leaves an **internet-facing admin toggle ON, 7 forwards armed and two DHCP servers racing** on a device the owner intends to put online | Open risk on the owner's desk |

---

## e) WHAT WE SHOULD IMPROVE

### What I forgot

1. **The syslog.** It was the single richest artifact on the device and I used 1 % of it.
2. **The verification matrix.** Every claim needs a "proved by <artifact>" column.
3. **Archiving evidence into the repo** (or at least a tar under a durable path) before the session ends.
4. **Asking for the label** and for the Wi-Fi sub-decision at the moment I knew they mattered.
5. **Confirming the report's destination folder** instead of guessing twice.
6. **Runtime over config**: leases, logs, counters. I repeatedly reported "configured as X" as if it were "is X".
7. **The gateway's own firewall semantics** (fragments, port-scan detection) were read but never explained as risk, only listed.
8. **A rollback rehearsed on paper only.** The plan says "reverse steps 9 to 12" but nobody has walked it.

### What I could have done better

9. Probe order: status tabs and syslog **before** ubus/SSH/telnet. Device-native read paths beat credential workarounds every time.
10. One structured extraction script instead of a dozen ad-hoc greps that each had to be debugged (unquoted `value=`, `<div>` nesting, `select` selected-detection).
11. Write the deliverable in the repo from the first draft, and let the cache hold only throwaway probes.
12. Publish corrected statements as corrections, not as new contradictory claims.
13. Ask the 3 unanswerable questions **early**, not at the end after burning effort on workarounds.
14. Distinguish "this device class has CVEs" from "this firmware is affected", I did label it as a family history, keep that discipline.
15. Use `git commit -- <path>` with a real message for the deliverable rather than letting the daemon sweep it.

### What we could still improve (systemic)

16. A `docs/services/router.md` and `docs/services/4g-cpe.md` runbook pair. Neither device has one, and both have state worth recording (addresses, credentials location, quirks, traps).
17. Put the CPE in monitoring before it carries traffic: gatus TCP check on 192.168.1.254:80 is free.
18. A repeatable audit script for these CPEs (endpoint list + field parser) instead of a fresh scrape per session.
19. Encode the "two DHCP servers on one segment" class as a checklist item for any network change in this house.
20. Decide the DNS-client policy explicitly: `docs/todo/services.md:98` records the search-domain decision but the *resolver* question for non-NixOS clients has no row.

---

## f) UP TO 50 THINGS TO GET DONE NEXT

Ordered roughly by risk-reduction per minute.

### CPE bleed-stop (do first, no topology change)

1. Remote Web off on the CPE (`/admin/network/remoteweb`, toggle to off).
2. Delete all 7 port forwards to `192.168.1.100`.
3. Turn the CPE's DHCP server off (`dhcp.lan.ignore=1`) to end the two-DHCP race today.
4. Change the CPE's admin password (and note that LuCI login and the system *nix account appear to differ: `root`/`admin` was rejected on telnet).
5. Disable telnetd (dropbear already present).
6. Verify each of 1 to 5 from the device (toggle state read-back, refused connection), not from the form echo.

### Pre-flash evidence (before touching OpenWrt)

7. Obtain the model/product string from the label and the LAN port count.
8. Get a 3.3 V USB-TTL adapter and confirm the UART pins on the board.
9. Dump the **entire 8 MB flash** over UART or via an authenticated read path.
10. Copy the **`factory`** partition (0x40000 to 0x50000) separately and store two copies.
11. Record `u-boot` version and check for TFTP/web recovery on the bootloader.
12. Capture the u-boot environment (`u-boot-env`, 0x30000) to learn the bootcmd and any recovery hook.
13. Identify the exact Quectel module model (EC25 variant) and its USB IDs.
14. Test whether upstream `ramips/mt76x8` already has this board (search by the label's model string).
15. If unsupported, evaluate ImmortalWrt for the same SoC family.
16. Write a brick-recovery runbook (TFTP filename, IP, u-boot key timing) before flashing.
17. Decide image size budget: 8 MB total, ~1 MB overlay today; measure a trimmed 24.10 build.

### Gateway correctness

18. WPS off on both bands.
19. DHCP pool size 244 to 90 (`.10` to `.99`), keeping `.53`, `.100`, `.150`, `.151`, `.200` free.
20. DHCP DNS to `192.168.1.150` / `192.168.1.151`.
21. 2.4 GHz encryption to AES-only.
22. Enable port scan detection (fragments optional; trial it).
23. Change the `admin/admin` password to a unique 16+ char value.
24. Replace both 8-char PSKs with 20+ char values.
25. Optional: move 5 GHz off DFS channel 52 to 36 to 48.
26. Optional: 2.4 GHz to 20 MHz (0 clients today).
27. Optional: point remote syslog at `192.168.1.150:514` after a receiver exists.
28. Record a config backup (encrypted) off-repo before any change.

### Topology (Option 1, approved in shape)

29. Resolve the Wi-Fi sub-decision (A: CPE 2.4 only, B: add a 5 GHz AP, C: split network).
30. If B: spec a 5 GHz OpenWrt-capable AP and put it on the CPE LAN port.
31. Re-plan addresses exactly as report Part 4.2 (`192.168.0.0/24` modem link, `192.168.1.0/24` house).
32. Throughput gate: `iperf3` through the CPE **before** committing the cutover (MT7628 NAT is the risk).
33. Pre-stage the Compal's second-subnet config so the cutover is one sit-down.
34. Add the CPE static route `192.168.0.0/24 via 192.168.0.1` so the modem UI stays reachable.
35. Rehearse rollback (report Part 4.5) on paper, then in the real cutover window.
36. Re-point nothing in NixOS (gateway stays `.1`), but re-run `nix flake check --no-build` after the cutover to prove DNS+TCP.
37. Rename the dnsblockd registry entry `lan-router` (`192.168.1.1`) once the CPE owns that address; add the Compal at `192.168.0.1`.

### 4G commissioning

38. Insert a SIM; confirm registration and a data path.
39. Configure the APN profile.
40. Decide TTL override (IPv4 TTL 65 / IPv6 HL 64) based on the tariff's tethering policy.
41. Review Watchcat (6 h reboot) and Watchdog (`@dns`, 10 s) now that a second uplink exists.
42. Consider disabling LAN IPv6 until the v6 firewall posture is reviewed.
43. Run the failover drill: kill the coax, time the switch, restore, time the failback.

### Docs, monitoring, hygiene

44. Write `docs/services/router.md` (gateway) and `docs/services/4g-cpe.md` (CPE) runbooks.
45. Harvest §f into `TODO_LIST.md` plus the matching `docs/todo/*.md` libraries (F1, needs approval).
46. Add gatus checks: `tcp://192.168.1.254:80`, and post-cutover `tcp://192.168.1.1:80`.
47. Identify `192.168.1.16` (CommScope OUI, no open ports, not in the device registry).
48. Reconcile the `.29` / Pixel-6 decommission record in `docs/services/dnsblockd.md`.
49. Archive this session's evidence (probe scripts + dumps) under a durable path, or delete it deliberately.
50. Write the repeatable CPE audit script (endpoint list + field parser) so the next review is one command.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **What model and product string is on the 4G CPE's label, and how many LAN ports does it have?** I cannot read
   physical hardware, and the firmware exposes no `board_name`. This decides whether upstream OpenWrt has an exact
   device entry (safe flash) or only a generic mt76x8 image (needs the full recovery path first), and it decides the
   cabling in report Part 4.3 step 10.
2. **Which Wi-Fi path (A, B or C)?** The CPE is 2.4 GHz-only with no PCIe slot, so "CPE as router" costs the household
   5 GHz unless a dedicated AP is added. A = CPE 2.4 only, free but slower. B = add a 5 GHz AP on the CPE LAN,
   recommended, needs hardware. C = leave the Compal's radios on, fast for 5 GHz clients but they lose LAN services and
   never fail over. I can measure and implement any of the three, I cannot price your preference.
3. **Where do you want deliverables, and do you want §f harvested now?** `docs/reports/` does not exist in this repo
   (`docs/reviews/`, `docs/status/`, `docs/audits/` do); the review sits in `docs/reviews/`. And the dispatch queue is
   untouched by design. Tell me the folder and whether to harvest items 1 to 50, and I will do both in one pass.

---

## Evidence artifacts (all in `~/.cache/router-review/`, NOT durable)

| Artifact | What it proves |
| --- | --- |
| `probe.sh`, `fetch.sh`, `head_plain.txt`, `index.html` | gateway identity, `WWW-Authenticate: Basic realm="Horizon"` |
| `Status*.html`, `Basic*.html`, `Advanced*.html`, `Wireless*.html`, `System*.html` (24 pages) | every gateway setting quoted in report Part 1 |
| `unauth.sh` | 401 on all sensitive pages |
| `scan.py` output | only port 80 open on the gateway |
| `dhcp_now.html`, `dhcp_now2.html` | two lease snapshots (device inventory, `.29` renewal) |
| `luci_home.html`, `lu_admin_panel.html`, `lu_admin_setup_*.html` | CPE menu surface, firmware version |
| `api/*` (26 files), `s_*`, `p_*`, `q_*` | every CPE setting quoted in report Part 2 |
| `q_system_status_syslog.html` (165 KB) | hardware: MT7628AN, 60,708K RAM, 8 MB flash, partitions, kernel 4.4.140, Quectel |
| `fw2.py` output | the 7 forwards with protocol, external and internal ports |
| `rsh`, `tn.py`, `tn3.py`, `ubus.sh` | failed shell attempts (dropbear host-key mismatch, telnet auth quirks) |
| `backup.bin` (9,522 B) | vendor-encrypted config archive, not parseable |
| `ROUTER-REVIEW-2026-10-29.md` | the first draft, superseded by the in-repo report |
