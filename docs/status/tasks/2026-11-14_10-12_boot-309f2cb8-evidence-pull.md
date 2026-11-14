# Evidence pull — boots `309f2cb8` (freeze #52) + `aaffd03f` (freeze #53), Nov 14 2026

Companion to `docs/status/2026-11-14_10-12_freeze-52-53-thermal-ceiling-morning-storm-double-cut.md`.
All numbers below were measured this session (journal greps cached under `~/.cache/freeze52/`).

## Boot boundaries (`journalctl --list-boots`)

| Boot | Full ID | First entry | Last entry | Span |
| --- | --- | --- | --- | --- |
| -3 | `6d2a69e459d0481ba122847b1fc65a53` | Nov 6 05:58:59 | Nov 7 01:06:21 | freeze #51 (owner power cut) |
| -2 | `309f2cb8fd714ef8a71f90a493523b07` | Nov 7 01:06:40 | **Nov 14 09:20:19** | 7 d 8 h 14 m — **freeze #52** |
| -1 | `aaffd03f86ca421f98007f8389594743` | Nov 14 09:21:18 | **Nov 14 09:27:13** | 5 m 55 s — **freeze #53** |
| 0 | `abaf0f511515482ba85ec05b7adf3492` | Nov 14 09:29:52 | (live) | cut→boot gaps: **59 s** (#52), **159 s** (#53) |

## Freeze #52 measured facts (boot -2)

- Guard trips: 2031, first `trip #7821` (Nov 7 01:08:41) → last `trip #9851`; **all 2031 carry "NO eligible headless tree matched"**
- DEEP THROTTLE ENTERs: 3594; first Nov 7 01:11:19 @ 98 °C (4.6 min post-boot); last Nov 14 09:20:07 @ 99 °C; final DROP 09:20:17 (2 s pre-cut)
- OOM: 3 `invoked oom-killer` (Nov 11 07:20:07 nix; Nov 13 00:35:58 nix; Nov 13 02:17:56 GC-marker-11); 0 in the death window; hung_task 0
- psi-wait-gate final lines: `WAIT: llama-vlm-cap — IO PSI some avg10=42.42% >= 30% (check 26, 750s elapsed)` at 09:20:00 (storm onset ~09:07:30)
- Gatus CPU Thermal Alert TRIGGERED 09:07:52 + 09:12:55 (Discord)
- Last journal lines 09:20:19: discordsync/file-renamer `/health` 200s, crm-server polling — mid-traffic, zero ceremony
- pstore empty; **reset reason DECODED from boot -1's kernel log**: `x86/amd: Previous system reset reason [0x00080800]: software wrote 0x6 to reset control register 0xCF9` = software warm reset (panic-reboot path), NOT the hardware WDT

## Freeze #53 measured facts (boot -1)

- 1 guard trip (`trip #9852`); 0 ENTERs (died before the throttle band); calm-gate REFUSE 09:21:26 (memory-guard 1 min prior), 09:21:41 (PSI 56.17%), 09:27:12 (PSI 67.35%)
- Last journal lines 09:27:13: granian/paperless matching + celery OpenAI retry (retry 5/10) — mid-traffic
- **Reset reason (boot 0 kernel log): `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired`** — the 90 s-WDT era, matching the 159 s gap

## Boot 0 at T+40 min (10:09–10:12)

- Trips `#9853`→`#9864`; 17 ENTERs; k10temp 98 °C + acpitz 98 °C; IO PSI some avg10 52.23 / avg60 64.77
- Deploy 09:43:43 → `deploy exited code=1 at 2026-11-14 10:08:35 after 1492s`; anchor INTACT (`readlink /run/current-system` == `system-1006-link` == `xfbd8lvr…`, Nov 7 build)
- Top IO (bundle `io-psi-forensics-20261114T084622Z`): crm-server 62.96 GB reads (~17 min), systemd 55.9 GB, cvagent 23.4 GB, dnsblockd 15.2 GB

## Reproduction commands

```bash
journalctl --list-boots | tail -5
journalctl -b -2 --no-pager | grep -c "IO-PAUSE (trip #"          # 2031
journalctl -b -2 --no-pager | grep -c "NO eligible headless tree matched"  # 2031
journalctl -b -2 --no-pager | grep -c "DEEP THROTTLE ENTER"       # 3594
journalctl -b -2 --no-pager | grep "DEEP THROTTLE" | tail -4      # last ENTER/DROP pre-cut
journalctl -b -2 --since "2026-11-14 09:15" --no-pager | tail -30 # death window
journalctl -b -1 --no-pager | tail -5                             # cut #53
journalctl -b -1 -k --no-pager | grep -i "reset reason"           # 0x00080800 software CF9 (cut #52)
journalctl -b 0 -k --no-pager | grep -i "reset reason"           # 0x02000800 hardware WDT (cut #53)
ls /var/log/systemnix-deploys/ | grep 2026-11-14                  # 8 attempts
readlink /run/current-system; readlink /nix/var/nix/profiles/system-1006-link  # anchor
```

NOTE: pre-crash bundle `io-psi-forensics-20261114T081933Z` (journal-proven written 09:19:43 in boot -2) was wiped with /var/tmp at the #52 reboot — the freeze-#50 lost-bundle class, second occurrence.
