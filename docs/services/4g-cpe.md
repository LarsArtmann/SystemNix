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
| OpenWrt path | `ramips/mt76x8`, profile `mediatek_mt7628an-eval-board` — **image BUILT + verified 2026-10-30** (25.12.6, 5.50 MiB, spare 1.06 MiB; mwan3 excluded by budget). See "OpenWrt flash session" below |

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

**Recovery (needs the owner's hands; now step A1 of the OpenWrt flash session below):** hold the
physical factory-reset button ~10 s → box returns to `admin/admin` → (if the flash is deferred)
re-apply T0 with the scripts in
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

## OpenWrt flash session (staged 2026-10-30 — image READY, owner-gated)

Owner directive 2026-10-30: OpenWrt on this box. The plan's UART-first tail (F20–F28) is re-scoped:
brick-insurance dump comes from the vendor **telnet shell** after the reset (pre-rotation
telnet+`admin/admin` worked, F09), and the target DTS was verified to use ONE combined firmware
partition — `mt7628an_mediatek_mt7628an-eval-board.dts` (openwrt-25.12): u-boot@`0x0`/0x30000,
u-boot-env@0x30000, factory@0x40000 (read-only, wmac eeprom), `denx,uimage` firmware@0x50000 size
0x7b0000 — matching the vendor map exactly. UART = Phase C last resort only.

**Artifacts** (`/data/backups/router-audit-2026-10-29/openwrt-25.12.6/`, SHA256SUMS.txt beside):

- `openwrt-25.12.6-ramips-mt76x8-mediatek_mt7628an-eval-board-squashfs-sysupgrade.bin` —
  5,767,474 B (5.50 MiB, cap 6.56 MiB), built from the official imagebuilder (tarball
  sha256-verified) + `PACKAGES="kmod-usb-net-cdc-ether kmod-usb-net-qmi-wwan kmod-usb-serial
  kmod-usb-serial-option uqmi"` (EC200A modem stack); squashfs @ 0x20677B, core end 0x5C1979
  (vendor `backup`@0x7e0000 untouched by the write)
- FILES overlay baked in: LAN static `192.168.1.254`, `dhcp.lan.ignore=1` (cannot race the
  Compal), hostname `cpe-4g`, dropbear key = evo-x2 `id_ed25519.pub`, root password (store-first:
  `~/.config/router-credentials/cpe-openwrt.txt`). mwan3 NOT included (budget) — lean failover
  script instead, later.
- Working copies: `~/.cache/router-review/openwrt/` (`build-image.sh`, `split-uimage.py`,
  `dump-receiver.sh`)

**Ladder — owner hands needed ONCE (~15 min):**

- **A (primary) — vendor-shell dump + flash:** ① owner holds reset ~10 s (box running) →
  `admin/admin` @ `.254` → ② agent: web snapshot + telnet shell probe (`cat /proc/mtd; id; ls
  /sbin/sysupgrade`) → ③ **GATE: dump EVERY mtd** over `nc` to `dump-receiver.sh` (:34567), sizes
  verified against the MTD map + sha256 ×2, archived to /data — NO write before this passes →
  ④ push image via nc (:34568) into `/tmp` (60 MB ramfs), sha256 both sides → ⑤ write per live
  `/proc/mtd`: combined `firmware` mtd present → `mtd write /tmp/openwrt.bin firmware`;
  split kernel/rootfs only → seam write (seam = vendor kernel-mtd size; the invariant is
  contiguous-from-0x50000 — the denx,uimage split is dynamic, internal boundaries irrelevant);
  `sysupgrade -n -F` only if mtd write is unavailable → ⑥ reboot → verify at
  `ssh root@192.168.1.254`: `uci show network.lan` (.254) + `dhcp.lan` (ignore=1), hostname,
  `wifi status` (mt7603 radio), `lsusb` → `2c7c:6005` (EC200A), LuCI `http://192.168.1.254`.
  NO T2 config yet. Post-flash hygiene is inherent: no telnetd, unique root pw, SSH key first.
- **B (no shell) — u-boot recovery probe:** owner unplugs, HOLDS reset, plugs in, keeps holding
  ~10 s; agent watches ARP/HTTP/TFTP for the recovery loader. WARNING: MT7628 u-boot recovery
  often listens at `192.168.1.1` — collides with the Compal gateway → bench-isolate first
  (direct cable / isolated switch port), never on the live LAN.
- **C (last resort) — UART:** 3.3 V adapter + case open; serial console + `sf read` dump if A·B
  fail (boot-loop / restricted-CLI scenarios).
- **Rollback:** A's dump + reverse seam write restores vendor firmware byte-for-byte; u-boot and
  factory partitions are never written in any phase. With u-boot intact, a failed flash is always
  recoverable via B/C.
