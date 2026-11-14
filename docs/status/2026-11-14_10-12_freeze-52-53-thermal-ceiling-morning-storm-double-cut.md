# Freeze #52 + #53 — thermal-ceiling morning agent storm, double cut (Nov 14, 09:20 + 09:27)

**Verdict: Branch C (chronic storm), thermal-led double cut.** The 7-day boot `309f2cb8` (freeze-#51 recovery) died instantly at 09:20:19 mid-traffic after a morning of stacked load — sustained 95–99 °C k10temp ceiling (chronic ALL boot: 3594 throttle ENTERs since Nov 7 01:11), a ramping IO storm (psi-wait-gate holding llama-vlm-cap for 750 s to the death line), and EIGHT failed deploy attempts (03:02→09:43, exit 1/12, none activated). The 6-minute recovery boot `aaffd03f` re-armed the fleet and died identically at 09:27:13 (textbook #48 never-cooled class). Boot 0 `abaf0f51` re-stormed too (98 °C, IO PSI avg10 80% at 09:50) and survived to authoring time ONLY because the guard stack kept refusing — **freeze-#54 risk is live and unresolved at T+42 min.** Reset mechanisms DECODED from the next boots' kernel reset-reason lines: **#52 = software warm reset (`0x00080800`, "software wrote 0x6 to reset control register 0xCF9" — the kernel panic-reboot path on a lockup with `nmi_watchdog=panic`/`softlockup_panic=1`; NOT the hardware WDT, explains the 59 s gap), #53 = hardware watchdog expired (`0x02000800`, matching the 159 s cut→boot gap and the 151–160 s #49/#50 signature).**

## §a Timeline (CET, Nov 14)

| Time | Event | Evidence |
| --- | --- | --- |
| Nov 7 01:11:19 | First DEEP THROTTLE ENTER of boot `309f2cb8` — 4.6 min post-boot @ 98 °C; the boot NEVER cooled (3594 ENTERs over 7 d 8 h; 74 on Nov 13 alone) | `journalctl -b -2 \| grep "DEEP THROTTLE ENTER"` |
| 03:02–07:31 | Deploy attempts 1–4 (03:02:52, 03:03:32, 07:18:34 exit-1@33s, 07:31:56 exit-1@0s) | `/var/log/systemnix-deploys/2026-11-14_0*.log` |
| 07:35–07:54 | Deploy 5 vetoed exit-12 (2 s); deploy 6 (07:38:24) built 958 s → nh exit 1. Log embeds the tq-daemon agent-batch dispatch (autonomous `crush run` on TODO_LIST ai-stack items) — the agent fleet was live fuel | same dir, 07-38-24 log |
| 07:59–09:14 | Parallel session reports land (llama-cpp attribution 07:59; task-queue closeout 08:42; audiblesync deploy-blocked triage 08:43; refire 09:14) | `docs/status/2026-11-14_*` |
| ~09:07:30 | IO storm onset: psi-wait-gate starts holding llama-vlm-cap (check 26/750 s by 09:20:00, WAIT to the death line — gate WORKED, #50 class) | `journalctl -b -2 \| grep psi-wait-gate \| tail` |
| 09:07:52 + 09:12:55 | Gatus **CPU Thermal Alert TRIGGERED** (Discord sent) — its description names this exact pattern: *"thermal freeze lineage #8/#9/#11/#12 — 98–99°C before the instant cuts"* | `journalctl -b -2 --since 09:00 \| grep "Thermal Alert"` |
| 09:20:07 | Last DEEP THROTTLE ENTER @ 99 °C | boot -2 journal |
| 09:20:17 | Final DEEP THROTTLE DROP ("cool band reached") — **2 s before the cut** (the freeze-#8 instant-cut trigger shape; #33 had 5 s) | same |
| 09:20:19 | **CUT #52** — journal stops mid-traffic (discordsync/file-renamer health 200s, crm polling); zero shutdown ceremony, no pstore record | `journalctl -b -2 \| tail` |
| 09:21:18 | Boot -1 `aaffd03f` first entry (cut→boot gap **59 s**); its kernel log decodes the reset: **`0x00080800` — "software wrote 0x6 to reset control register 0xCF9"** = software warm reset, the panic-reboot path (`nmi_watchdog=panic` + `softlockup_panic=1` on the cmdline) | `journalctl --list-boots`; `journalctl -b -1 -k \| grep "reset reason"` |
| 09:21:26 + 09:21:41 | post-crash-calm-gate REFUSE ×2 (memory-guard trip 1 min prior; then IO PSI avg10 56.17%) — gate WORKED | `journalctl -b -1 \| grep calm-gate` |
| 09:23 | A task-queue session (riding across the cut) authors the 09:23 window-closeout report | `docs/status/2026-11-14_09-23_*` |
| 09:27:12 | calm-gate REFUSE #3 (IO PSI avg10 67.35%); guard trip #9852 logged | boot -1 journal |
| 09:27:13 | **CUT #53** — same instant-cut shape, 5 m 55 s into the boot | `journalctl -b -1 \| tail` |
| 09:29:52 | Boot 0 `abaf0f51` first entry (gap **159 s**); its kernel log decodes cut #53: **`0x02000800` — "hardware watchdog timer expired"** (the 90 s-WDT era, #49/#50 class) | `journalctl --list-boots`; `journalctl -b 0 -k \| grep "reset reason"` |
| 09:30:06–09:30:51 | calm-gate REFUSE ×3 more (memory-trip window; PSI 46.9/58.6/55.5%); psi-wait-gate admits llama-vlm-cap only at PSI 13.86 | boot 0 journal |
| 09:43:43 | Deploy 8 starts; **FAILS exit 1 at 10:08:35 after 1492 s** ("nh os switch FAILED — config NOT activated") — this is the double `nix flake check --no-build` + rustc load observed at 09:50 | `/var/log/systemnix-deploys/2026-11-14_09-43-43.log` |
| ~10:09 | Boot 0 still at ceiling: k10temp 98 °C, acpitz 98 °C, IO PSI avg60 65%, trips #9853→#9864, 17 ENTERs | live probes |

## §b Freeze #52 — boot `309f2cb8` (freeze-#51 recovery, 7 d 8 h 14 m)

| Metric | Value |
| --- | --- |
| Window | Nov 7 01:06:40 → Nov 14 09:20:19 |
| Guard trips | **2031 (#7821→#9851), ALL no-match** — guard structurally powerless the entire boot (#50 class: 0 pauses, 0 sacrifices) |
| DEEP THROTTLE ENTERs | **3594** (first 01:11:19 Nov 7 @ 98 °C — never-cooled; last 09:20:07 Nov 14 @ 99 °C; final DROP 2 s pre-cut) |
| OOM | 3 invocations (Nov 11 07:20 nix; Nov 13 00:35 nix; Nov 13 02:17 GC-marker-11) — **none in the death window**; hung_task = 0 |
| trips/h | 11.5 (inside the 1.3–11.7 chronic storm band, #39 row) |
| Reset mechanism | **DECODED: software warm reset `0x00080800` (0x6 → 0xCF9)** — boot -1's kernel `x86/amd: Previous system reset reason` line; the kernel panic-reboot path on a lockup (hard/soft lockup under `nmi_watchdog=panic`/`softlockup_panic=1` at the thermal ceiling), NOT the hardware WDT (59 s gap < 90 s floor) and NOT a power cut; pstore captured nothing (console record armed but empty — the family's standing no-panic-record pattern) |

Death-minute composition: the morning stacked (1) the tq autonomous agent fleet, (2) eight deploy attempts each burning 15–25 min of eval/build CPU at the ceiling, (3) crm-server's by-phone read storm (see §c), (4) the standing amplifier fleet held correctly by psi-wait-gate — onto a boot that had cycled the thermal governor every ~3 min for a week.

## §c New amplifier measured: crm-server by-phone read storm

Boot 0's 09:46:26Z forensic bundle (`/var/tmp/io-psi-forensics-20261114T084622Z/top-io-procs.txt`) ranks **crm-server #1 with 62.96 GB read_bytes in ~17 min (≈63 MB/s sustained)** — on a boot with no other explanation (the endpoint answers in 350–900 µs; the by-phone poll runs 2×/s, so ~500 KB read per request ≈ an uncached scan per poll). The existing `crm-by-phone-storm-alarm` fires on 5xx/latency only — **read volume is invisible to it**. cvagent answered /health 503 all morning (downstream leg of the same stack).

## §d Boot 0 live state at authoring (10:12, T+42 min)

- k10temp **98 °C**, acpitz **98 °C**; IO PSI avg10 52% / avg60 65% (peak avg10 80.54% at ~09:50); 17 ENTERs, trips #9853→#9864
- Deploy 8 failed exit 1 (10:08:35) — **anchor INTACT**: `/run/current-system` == `system-1006-link` == `xfbd8lvr…` (Nov 7 build `26.11.20261107.f4a03c0`; NO activation since Nov 7 — every 2026-11-14 attempt died pre-switch, so the evening tree remains PENDING deploy)
- Guard stack performing: calm-gate refused the fleet 4×; psi-wait-gate admitted llama-vlm-cap only under PSI 14; the deploy pressure gates produced today's exit-12 + exit-1 refusals — **this is why boot 0 outlived boot -1**

## §e What worked / what didn't

| Layer | Verdict |
| --- | --- |
| psi-wait-gate (llama-vlm-cap held 750 s to the death line) | WORKED (#50 repeat) |
| post-crash-calm-gate (boot -1 ×3, boot 0 ×4 refusals) | WORKED |
| Deploy pressure/tier-2 gates (8 attempts, 0 activations, anchor intact) | WORKED as veto — but see §f.2: nothing stops a session from RE-FIRING a 25-min build at 98 °C |
| CPU Thermal Alert (fired 12 min pre-cut, Discord) | WORKED as warning — nothing consumes it as an entry gate |
| memory-emergency-guard | 2031 no-match trips — structurally powerless against TTY/agent-session drivers (known #50 finding, unchanged) |
| pstore | EMPTY (no panic record — consistent with instant-cut family) |

## §f Follow-ups (self-harvested into TODO_LIST.md + docs/todo/stability.md at authoring time)

- **[f.1] crm-server by-phone read-volume storm** (§c) — [ready] row: root-cause the ~500 KB/request read amplification (crm repo cache/index fix) + extend the alarm to read volume. **Harvested** → TODO_LIST + stability.md.
- **[f.2] deploy-build thermal entry gate** — [ready] row: refuse NEW deploy attempts (exit-12 class, pre-build) while k10temp sits in the ≥95 °C sustained band (thermal-pstate-guard's 6-hot-tick shape); 8 attempts burned 15–25 min each at the ceiling today, all failed anyway. **Harvested** → TODO_LIST + stability.md.
- **[f.3] freeze-#52 reset mechanism** — **ANSWERED at authoring time**: boot -1's kernel line `x86/amd: Previous system reset reason [0x00080800]: software wrote 0x6 to reset control register 0xCF9` = software warm reset (panic-reboot path on a lockup); #53 decoded `0x02000800` hardware WDT. No row minted. NOTE the near-miss: an earlier 5-line-truncated kernel grep in this same session read as "no reset-reason line" — the line exists; head-truncation almost shipped a false claim.

## Evidence

- Boot IDs: -2 `309f2cb8fd714ef8a71f90a493523b07`, -1 `aaffd03f86ca421f98007f8389594743`, 0 `abaf0f511515482ba85ec05b7adf3492` (full IDs — `journalctl -b -N` needs them)
- Greps + derived counts: `~/.cache/freeze52/boot2-evidence.txt`, `~/.cache/freeze52/oom-lines.txt`
- Live forensic bundles (boot 0 only; **boot -2's 081933Z bundle was wiped with /var/tmp at the #52 reboot** — the #50 lost-bundle class recurring, expect the WARN): `/var/tmp/io-psi-forensics-20261114T08{3220,3450,4622}Z/`
- Deploy logs: `/var/log/systemnix-deploys/2026-11-14_{03-02-52,03-03-32,07-18-34,07-31-56,07-35-06,07-38-24,08-58-03,09-43-43}.log`
- Canonical numbers + reproduction commands: `docs/status/tasks/2026-11-14_10-12_boot-309f2cb8-evidence-pull.md`
