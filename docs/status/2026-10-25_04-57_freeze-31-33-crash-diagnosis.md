# Freeze #31–#33 Crash Diagnosis — Chronic 4.6-Day Zone-6 Storm, 41 h Guided Throttle, Freq-Restore 5 s Before the Cut

**Date:** 2026-10-25 04:57 CEST · **Asked:** "Why did we crash this time?" · **Boot:** `3e5c8af5` (full `3e5c8af5e510418da04191e52ed034b4`), Oct 20 14:58:11 → Oct 25 04:31:30 (**4 d 13.5 h**), kernel 7.2.10, system `26.11.20261015.fe13242` (no deploy during the whole boot — storm-gated the entire time)
**Evidence:** `docs/status/tasks/2026-10-25_03-40_boot-3e5c8af5-evidence-pull.md` (canonical pull at 7.9G/8G journal pressure — vacuum-imminent race won) + `…_daecca67…`/`…_002c519e…` pulls for #31/#32. Parallel sessions live during autopsy: monitor365 DuckDB session (04:50 report) + auto-commit daemon.

---

## Verdict

**Freeze #33 (Oct 25 04:31:30): the chronic-storm family with all three legs stacked at the end — (1) a WHOLE-BOOT zone-6 IO PSI storm (trips #3797 → #4290, 493 trips at ~10-min cadence across 4.6 days, IO PSI some avg60 40–62 %, disk 100 % in every final trip), (2) thermal: 30 guided ENTER cycles 95–99 °C Oct 20–23, final ENTER Oct 23 11:25:08 at 98 °C that NEVER exited — 41.3 h in guided — with `DEEP THROTTLE DROP: scaling_max_freq restored (cool band reached)` at 04:31:25, FIVE SECONDS before the cut, and (3) a late memory leg (MemAvailable 44 → 29.6 % across the final hour, zram 81 %, sev1 latched from 03:42).** Journal cut mid-traffic at 04:31:30, zero shutdown ceremony, no pstore, no vmcore — the livelock-family discriminators. Guard counter continuity across the cut: #4290 → boot-0 #4291. The freq-restore-at-−5 s is the freeze-#8-class instant-cut trigger shape (load collapse → cool band → clocks restored → first work on restored clocks under a standing cooling deficit → trip), though an IO-livelock terminal at avg60 62 % cannot be excluded as co-mechanism; the death window is thermally unsampled between guard ticks.

Also verified and documented for the first time: **two previously-unenumerated hard cuts — freeze #31 (Oct 18 03:03, boot `daecca67`, 2 h 21 m; died IN guided — 98 °C ENTER 01:05:50 never exited) and freeze #32 (Oct 20 14:40:30, boot `002c519e`, 2 d 11.6 h; 107 OOM lines + 8,697 guard lines; thermal EXITED 22 min pre-cut at 65 °C — not counted as a thermal bait)**. Boot `-2` (Oct 20 14:42→14:56) ended WITH ceremony = owner reboot, not a crash. Numbering caveat: the Oct 15–18 journal window is vacuumed; #31 is the first VERIFIABLE cut after #30 — any cuts inside Oct 15–18 are unenumerable.

## a) Death window (Oct 25 03:00 → 04:31:30), verified

1. **Zone-6 escalation:** trips #4284 (03:28, avg60 42.0 %) → #4285 (03:38, 59.7 %) → #4286 (03:50, 66.7 %) → #4287 (04:01) → #4288 (04:09) → #4289 (04:19, user.slice +36.6 GB/window) → #4290 (04:29:54, avg60 59.8 %, disk 100 %, MemAvail 29.6 %); final heartbeat 04:31:15 (avg60 61.92 %, disk 100 %, MemAvail 29.9 %); **cut 15 s later**. Every action executed + ineffective (the #24/#25/#26/#28 executed-ineffective case, 4th+ structural proof).
2. **Death-hour IO attribution (guard self-attribution):** `monitor365-server` +38–40 GB per 10-min window (03:38/03:50 trips) — root-caused by the PARALLEL session (04:50 report): DuckDB pool wedge under io PSI, 25 GB DB, backup OOM at 03:01 (1.8 GiB figment default vs 25 GB), fixes in-tree `5555a89ec` UNDEPLOYED. `nix-daemon` +17–25 GB; `user.slice` +29–37 GB late (agent sessions); `tq-agent-pool` the whole-boot chronic driver Oct 20–21 (+150–270 GB windows, row-16 class).
3. **Thermal timeline:** 30 ENTER/EXIT cycles Oct 20–23 (95–99 °C); final ENTER Oct 23 11:25:08 (98 °C) — no transition for 41.3 h (died in guided, the freeze-#29 signature); 04:31:25 DEEP THROTTLE DROP (cool band, freq restored) → cut 04:31:30.
4. **Memory leg:** 16 memcg OOMs whole-boot (all tq-agent-pool nix builds, Oct 23–24 — known class); zram 81 % (54.1/66.7 GB) + MemAvail 29.9 % at death — degraded, NOT the terminal cliff (the freeze-#28 5-10 % class this is not).
5. **Death-minute oddities:** TWO `dmesg` coredumps (klogctl SIGSEGV) at ~04:30:30 + 04:31:29 — **uid 966 = `monitor365` service user (getent-verified in the 05-48 self-review; the 04-57 draft wrongly guessed "systemd-coredump context")**: monitor365's own diagnostic `dmesg` calls were segfaulting at the death minute, deepening the monitor365 wedge attribution; `nsfw-classifier` restart #7 cold-loading its ONNX skin-segmenter → ROCm at the death second (04:31:30) — it had restart-looped 7× since 03:00 (Go exit-code crashes), each restart = ~7 GB RSS + model-file read + GPU init on a 100 %-busy QLC (amplifier, not trigger); `tq-agent-pool` was maintenance-entry-gate REFUSED at 04:30:35/04:31:05 (load-shedding worked — not a driver); InboxClean backup failed 04:30:30 (resource exhaustion signature).
6. **Boot-0 (recovery) re-arm — LIVE RISK at report time:** trip #4291 within minutes (counter continuity confirmed); IO PSI some avg60 64–72 % at T+10–15 min; CPU PSI some avg60 80 % (load 27 → 69.8); **k10temp 98 °C at 04:50:25 with DEEP THROTTLE ENTER (60 % cap)** under a Gradle/Go build battery (compile 600/400/250 %, java 152 %) + `hermes-db-health` sqlite integrity_check + ownership `find` (the freeze-6 recovery-reader class, running ungated at T+5 min into the storm) + cold page cache. This is the freeze-#18/#25 re-arm shape.

## b) Freeze #31/#32 backfill (from the two new evidence pulls)

- **#31 (Oct 18 03:03:38, boot `daecca67`, Oct 18 00:42→03:03):** last lines = tq requeue WARN + niri INFO mid-activity, zero ceremony → hard cut. Thermal ENTER 01:05:50 (98 °C) never exited → **died in guided (cooling-row bait #13)**. 347 guard lines in 2 h 21 m.
- **#32 (Oct 20 14:40:30, boot `002c519e`, Oct 18 03:05→Oct 20 14:40):** last line storage-collector INFO (zram 80 %, pool metadata 97 %), zero ceremony → hard cut. 107 OOM lines + 8,697 guard lines = the heaviest memory leg of the three; final thermal ENTER 13:54:13 (97 °C) EXITED 14:18:40 (65 °C) — 22 min cool before the cut → **not counted as thermal bait** (the #20/#28 precedent: mechanism absent at death).

## c) Why it crashed — the causal stack

1. **Standing physical cooling deficit (root, owner-gated, un-inspected since freeze #8):** every thermal-participating cut since #16 throttled through it. Tonight: 41 h in guided + freq-restore 5 s pre-cut = bait #14.
2. **Chronic IO storm with guard-external drivers:** the guard's churn/sacrifice lists do not contain monitor365-server (DuckDB wedge — fix in-tree, undeployed), nix-daemon build bursts, or user-slice session batteries; flm-sacrifice actions executed and changed nothing (again). The storm persisted 4.6 days at 10-min trip cadence — the box lived in the pre-freeze zone the entire boot.
3. **Recovery-boot amplifier (live now):** build battery + ungated hermes-db-health + cold cache re-arming boot 0 to 98 °C / PSI 72/80 within 17 min. If nothing pauses, freeze #34 is minutes-to-hours away by every precedent in the family.

## d) Owner actions requested (ordered, now)

1. **PAUSE the build battery** (Gradle/Go/java sessions, owner-user) — boot 0 is at 98 °C under deep throttle with the guard already tripping (#4291+). No deploys, no flake check, no toplevel attempts (the standing no-heavy-builds gate).
2. **Physical cooling inspection** — 14 baits now. Dust/fans/paste/vents; the standing [blocked:user] row.
3. **fsck the buildcache USB SSD (sdb):** boot-0 mount FAILED — `JBD2: journal reset failed` + `EXT4-fs (sdb1): error loading journal` (crash-damaged journal; mount timed out + killed). `sudo fsck.ext4 -f /dev/disk/by-id/<sdb-id>-part1` at the next calm window; the fstrim row's sdb policy decision rides along.
4. **Let the recovery settle:** hermes-db-health will converge next boot; tq stays gate-refused by design. Deploy the monitor365 fix batch (`5555a89ec`) only at a calm window — it removes a named death-hour reader.

## e) What worked

- maintenance-entry-gate refused tq-agent-pool all through the death window AND boot 0 (load-shed by design, first live proof under a real death approach).
- Guard telemetry + trip self-attribution named every death-hour reader; counter continuity held across the cut; evidence pulled ahead of the 8G vacuum (three boots preserved).
- Boot -2/-3/-4 boundary reads distinguished owner reboots from hard cuts (ceremony discriminator).

## f) NEXT (self-harvested)

1. [ready] **Boot-admission gate for `hermes-db-health`** (maintenance-entry-gate band or IO PSI condition) — it ran ungated at T+5 min into a 60 %+ PSI recovery storm (freeze-6 rule (a) still has no enforcement). → TODO_LIST queue + `docs/todo/stability.md` (extends the stampede-control row).
2. [decision] **Storm-aware restart gating for cold-load-heavy services (`nsfw-classifier`)** — 7 crash-restarts × (ONNX read + ~7 GB + ROCm init) in the death window amplified the cliff; RestartSec/backoff or a PSI-band condition for units whose cold start is itself a storm event. → `docs/todo/stability.md`.
3. [blocked:user] **fsck sdb buildcache (ext4 journal damage)** — owner hands; rides d)3. → `docs/todo/stability.md`.
4. Row updates (this commit): tq-guard-coverage row (4th whole-boot chronic appearance), stampede row (live ungated hermes instance), cooling row (baits #13/#14 minted, #32 not counted — mechanism absent at death).
5. monitor365 attribution: **deliberately not harvested** — owned by the live parallel session's 04:50 report (DuckDB wedge + fix batch `5555a89ec`, undeployed).

## g) Open questions (owner)

1. Confirm the ~04:31 power event was a button/reset cycle (no NVRAM watchdog reason pulled — pstore empty; wtmp would distinguish owner-cycle vs spontaneous, sudo-gated).
2. The `dmesg`/klogctl SIGSEGV pair in the final 65 s — hardware-canary oddity or userspace symptom? Watch item only; no action proposed without a recurrence.
