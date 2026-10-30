# ISP gateway (Compal DMC7002KLG) — Agent Notes

> The cable modem/router at `192.168.1.1` (Vodafone Station, DOCSIS 3.0, FW 2.9.13).
> Full audit: `docs/reviews/2026-10-29_19-40_router-configuration-review.md`; plan:
> `docs/planning/2026-10-29_22-18_SUPERB-4g-failover-then-openwrt-pareto-plan.md`.

## Inventory

| | |
| --- | --- |
| Model | Compal **DMC7002KLG** (Vodafone Station v2 class), FW **2.9.13**, DOCSIS 3.0 8x4, BPI+ |
| Address | `192.168.1.1/24` (static LAN; repo pins this — `local-network.nix`, `wifi-failover-watch.sh`) |
| Admin | HTTP only (no TLS listener), realm `Horizon`, user `admin`. **Password rotated 2026-10-30** — value in `~/.config/router-credentials/gateway-admin.txt` (0600, off-repo; move to password manager) |
| WAN | DHCP from ISP, public `89.65.239.240/22`, lease 7d |
| Radios | 5 GHz SSID `UPC504705697` (7 clients) + 2.4 GHz `UPC244705697`, WPA2, DFS ch 52 on 5 GHz |

## State after the 2026-10-30 hardening session

| Setting | Before | After | Verification |
| --- | --- | --- | --- |
| DHCP pool | `.10` size 244 (`.10–.253`) | `.10` size **43** (`.10–.52`) | BasicLAN.asp read-back `value=43` |
| DHCP DNS1/DNS2 | `193.47.158.254/.255` (Vodafone) | **unchangeable — fields are firmware-inert** (see traps) | 3 value classes tested, all ignored |
| WPS 2.4 GHz | Enable 1 | **Enable 0** | page JSON blob `"WPS":{...,"Enable":"0"` |
| WPS 5 GHz | Enable 1 | **Enable 0** | same, on the 5 GHz page |
| Port scan detection | off | **on** | `cbPortScanDetection checked` |
| Admin password | `admin/admin` | 24-char random (stored off-repo) | old auth → 401, new → 200 |
| Firewall | on, WAN Blocking on, no forwards/DMZ, UPnP off | unchanged (kept) | AdvancedFirewall.asp |

- **Why pool 43, not the plan's 90:** the lease table proves **hash-style (scattered) allocation** (`.16 .29 .62 .122 .136 .161 .218 .241` — never sequential), so a `.10–.99` pool can hand `.53` (the dnsblockd VRRP virtual IP) to ANY new client, not just the 44th. `.10–.52` excludes `.53/.100/.150/.151/.200` structurally. The plan §7.1's "keeps .53 free" claim is only true at size ≤43 — plan erratum, recorded here.
- Existing out-of-pool leases (`.62 .122 .161 .191`…) are honored on renew (standard DHCP REQUEST-ACK) and churn into `.10–.52` as clients re-DISCOVER. New leases already land in-pool (`.34 .45` observed).
- **D4 (clients resolve via dnsblockd) is NOT deliverable via this device** — see traps. It lands at T2 when the CPE's DHCP (writable DNS fields) serves the house.

## Traps (all discovered live 2026-10-30)

1. **goform write contract — POST EVERY form field including selects.** The server answers `200 + "Error converting one or more entries"` when ANY form control is missing from the POST — e.g. `BasicLAN.asp` needs the hidden-in-plain-sight select `BasicLANDHCPServer=1` even though it never changes. Enumerate `<input|select|textarea>` on the page and post the complete set.
2. **curl POSTs need a PREEMPTIVE `Authorization: Basic …` header** (`-H`). Plain `-u` reliably 401s on POSTs (fine on GETs).
3. **The LAN DNS fields are decorative on FW 2.9.13.** `BasicLANDNSServer1/2` are accepted (302) and silently ignored — private AND public test values never applied. DNS-to-clients is ISP/TR-069-managed. Do not re-attempt; D4 rides the CPE at T2.
4. **Some pages need an action-enum field the JS sets on save**: WPS forms require `Wireless{24GHz,5GHz}WPSApplyAction=3` (from `wireless*SaveAction()`).
5. **Config backup download (`/goform/SystemBackup`) is curl-hostile** — 8 variants (urlencoded/multipart/browser-faithful python/hidden fields/UA) all fail; multipart reaches the parser but errors. The owner's browser presumably works: click Backup on `SystemBackup.asp` (optional 6–12 char encryption password) and store the file off-repo. Rollback insurance today = the cached page set (`/data/backups/router-audit-2026-10-29/`) + the before/after table above.
6. **`verifyMinMax` lives in `util.js:437`** — it CLAMPS (`parseInt<min → min; >max → max`), it does not reject. Pool min 1, max `254 - start_octet`; lease min 30 s.
7. **State hides in per-page JSON blobs** (`var wifi24G = {…}`) — the WPS/security current values are read from the blob, not from `selected` attributes (selects render unselected; JS applies blob state).
8. The 2.4 GHz WPS page's blob contains a SECOND WPS object (`Enable:1`) belonging to the inactive guest-SSID slot (`SSID "---"`) — inert, no broadcast. Not an exposure.
9. **ISP TR-069 can silently revert anything here** (WPS, DNS, pool). There is no local drift detection yet — queued (todo/services.md). Re-check the after-table above if a "fixed" setting misbehaves.

## Operational runbook

- Pages: `Status{System,Basic,Upstream,Downstream,MtaStatus,Ping,Traceroute}.asp`, `Basic{Internet,LAN,DHCP,HomeNetwork}.asp`, `Advanced{Options,Firewall,IPFilters,MACFilters,PortFilters,PortTriggers,Forwarding,DMZHost}.asp`, `Wireless{24GHz,5GHz}{Radio,Security,AccessControl,WPS,Advanced}.asp`, `System{Password,Backup,Restore,FactoryDefault,LocalLog,RemoteLogging}.asp`. No bridge/modem-mode page exists (24-page census).
- Lease table: `BasicDHCP.asp`. Syslog: `SystemLocalLog.asp`.
- Changing the admin password: `SystemPassword.asp` → `/goform/SystemPassword` fields `OldPassword`, `Password`, `PasswordReEnter` (+ `SelectLanguage`, `LogoutApplyAction=` empty). Store the new value FIRST (see `~/.cache/router-review/exec/gw-f44.sh` for the working pattern).
- **PSK rotation (pending, owner window):** `Wireless{24GHz,5GHz}Security.asp` — the form requires the passphrase round-tripped (`Wireless*SecurityWPAPPassphrase/Retype`) and the current PSK is NOT served by the page, so the owner must type/provide it. Merge with the AES-only change: `Wireless*SecurityWPAPEncryption` value `1` = AES (0 TKIP, 2 TKIP+AES), `WPAPAuth` 1 = WPA2.
- The device **does not reboot** for pool/DHCP/WPS changes (runtime apply; uptime carried over). `showRebootAlert()` on DNS edits is aspirational — DNS never applies (trap 3).
