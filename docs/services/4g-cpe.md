# 4G CPE (MT7628AN LTE router) — Agent Notes

> The 4G router at `192.168.1.254`. Audit: `docs/reviews/2026-10-29_19-40_router-configuration-review.md`; plan:
> `docs/planning/2026-10-29_22-18_SUPERB-4g-failover-then-openwrt-pareto-plan.md` (this box becomes the house router `192.168.1.1` at T2).

## Inventory (proven from the device's own syslog)

| | |
| --- | --- |
| SoC / RAM / flash | MediaTek **MT7628AN** ver:1 eco:2, 580 MHz, **60,708 KiB RAM**, **8 MB SPI** (`spi32766.0`) |
| Firmware | vendor LuCI fork `1.0.273-20240928-115300` (title `4G-LTE`, theme build `git-24.271.34822`), kernel **4.4.140** (LEDE 17.01 BSP), built by `abu@openwrt` |
| LTE module | Quectel **EC200A-EU** (`AT+CGMR → EC200AEUV1HAR02A06M16`), USB `2c7c:6005`, CDC-Ethernet + 3 AT ports, module NAT on (`AT+QCFG="nat" → 1`). **No SIM** (`AT+CPIN? → +CME ERROR: 10`) |
| Wi-Fi | 2.4 GHz only (vendor `MT7628 AP Driver 4.1.0.0`, `ra0`), no PCIe — 5 GHz is a hardware ceiling. SSID `Europol \| Law enforcement` |
| Address / mode | `192.168.1.254`, wired port in **LAN mode** (no WAN interface exists) |
| MTD map | `u-boot` 0x0–0x30000 · `u-boot-env` 0x30000–0x40000 · **`factory` 0x40000–0x50000 (65,536 B, radio calibration)** · `kernel` 0x50000–0x1893d0 · `rootfs` 0x1893d0–0x7e0000 · `rootfs_data` 0x6e0000–0x7e0000 (1 MB overlay) · `backup` 0x7e0000–0x7f0000 · `bdinfo` 0x7f0000–0x800000. Kernel+squashfs ceiling **6,881,280 B = 6.56 MiB** |
| OpenWrt path | `ramips/mt76x8` generic; lean 24.10 ≈ 6.1 MiB fits (+0.46 spare), **+mwan3 ≈ 6.7 MiB does NOT fit** |

## CURRENT STATE (2026-10-30): config-hardened, administratively LOCKED

| Setting | State | Note |
| --- | --- | --- |
| Remote Web (WAN admin) | **OFF** | read-back `fa-toggle-off`, `enabled=0`; no extra ports open |
| Port forwards | **0** (was 7 armed to `192.168.1.100`: ssh-onprem-0 22, onprem-0-k8s 443+6443, onprem-0-tailscale 41641, onprem-0-Longhorn 9500/9501/9502) | rules recorded here for recreation if ever wanted |
| DHCP server | **OFF** (`ignore=1`) | was live `.101–.200` racing the gateway — it NAK'd client `.16` and ACK'd `motorola-edge-60` at `.136` with dead DNS `10.43.255.55` (the phone self-heals at next renew / Wi-Fi toggle) |
| Admin password | **rotated to an UNKNOWN random value** — see incident below | `admin/admin` rejected on web (403) AND telnet (`Login incorrect`) |
| telnetd (port 23) | still listening, **default credential dead** | no UI toggle exists in this fork; permanent fix = OpenWrt flash (F73) |
| Watchcat | enabled, 6 h no-internet self-reboot (baseline 19118 s/21600 s at 00:43) | keeps rebooting while no SIM; harmless |

### The lockout incident (honest record)

The password was rotated 2026-10-30 ~00:55 and VERIFIED live (old 403, new 302), but the script's
strict assertion aborted **before storing the generated value** — and this fork **validates the
old-password field** (`pw1`), so an in-session re-set was impossible. A remote "Reset to defaults"
(`/cgi-bin/luci/admin/system/reset`, POST `cbid.reset.1.reset=Perform reset`) returned 302 **twice
but never applied** (custom SSID still on air hours later, password unchanged). No other remote
recovery exists: ubus ACLs are empty, SSH dropbear never completes its handshake, telnet needs the
password, and no valid config backup exists (`backup.tar.gz` download produced an HTML error page;
`backup.bin` 9,522 B is vendor-encrypted, magic `d23a77c8d8633dc7`).

**Recovery (needs the owner's hands, rides the SIM-insertion visit):** hold the physical
factory-reset button ~10 s → box returns to `admin/admin` → re-apply T0 with the scripts in
`~/.cache/router-review/exec/` (mirrored in `/data/backups/router-audit-2026-10-29/`):
`remoteweb-off.sh`, `del-forwards.sh` (cfg ids in the script), `dhcp-off.sh`, then rotate the
password with the **store-first** pattern (`gw-f44.sh` shows the working method; the failed
pattern was store-AFTER-verify). All steps take ~10 min.

## Traps

1. **LuCI CBI form contract (multipart):** every POST needs `token` (fresh per GET), `timeclock=` empty, `cbi.submit=1`, the paired hidden `cbi.cbe.<sect>.<opt>=1` + `cbid.<sect>.<opt>=<value>` for toggles, and `cbi.apply=Save & Apply`. Read back by re-GETting the form.
2. **Table-row delete:** POST `cbi_state=del-section` + `cbi.rts.<table>.<cfgid>=Delete` (button name) to the page URL.
3. **The syslog page is the goldmine** — `/cgi-bin/luci/admin/system/status/syslog` serves the full plain-text log (hardware identity, AT-command results, dnsmasq runtime, watchcat counter). Check it BEFORE anything clever.
4. `/admin/network/wireless/config` returns **500** (Lua dispatcher bug). Wi-Fi reality comes over the air (`nmcli dev wifi list`).
5. Port 53 (dnsmasq DNS) and 22 (dropbear, broken handshake) are open alongside 23/80.
6. **Vendor config backup download is broken via HTTP** (returns an HTML error page, not the archive) — take backups by UART dump when it matters (C04/F24).

## Watchcat / watchdog

- Watchcat reboots the box after 6 h without internet (counter in syslog, +1 s per ~3 s line). With no SIM this cycles every ~6 h. Config: `/cgi-bin/luci/admin/services/watchcat` (`cbid.system.cfg0ae014.*`).
- `pingcheck` logs `Interface 'wan' not found` — expected in LAN mode; resolves when the port goes WAN (T2, F59).

## T2 cutover role (approved Option 1)

End-state: Compal LAN → `192.168.0.0/24` (modem duty, DHCP pool `.2` limit 1), CPE takes `192.168.1.1` with DHCP `.10–.99` advertising DNS `.150/.151` (CPE DHCP DNS fields are writable — unlike the Compal's), LTE as automatic backup. **Blocked on:** SIM (owner), label model + port count (owner), Wi-Fi path A/B/C (owner). See plan §7 for the minute-by-minute runbook.
