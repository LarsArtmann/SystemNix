# Freeze #34–#36 — three watchdog hard cuts in 34 h: the thermal deficit now meets the guard's own "deficit-masking" criterion

**Date:** 2026-10-27 10:38 CET (investigation started 16 min after the cut)
**Trigger:** owner — "I think we just crashed earlier, why"
**Scope:** the cut at 2026-10-27 10:03:11 plus the two undocumented predecessors it completes (2026-10-25 22:22:13, 2026-10-26 22:53:58).
**Live state at authoring:** boot `3caf5548` (10:04:43), gen-955 anchored (`readlink /run/current-system` == `system-955-link`, verified 10:38:29), Tctl 97–99.2 °C, acpitz 91–99 °C, PPT 73–114 W at load 47–142, journal 7.8 G / 8 G.

## Verdict (short)

The box did **not** panic, OOM-freeze or lose power to the EC: it **hung hard enough that `watchdogd` stopped petting the SP5100 TCO timer for 30 s, and the hardware watchdog reset it.** The kernel of the boot after every retained cut says so verbatim: `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired`.

The hang formed on two stacked, independently-verified legs:

1. **A standing cooling deficit.** Boot `b803d718` entered the deep-throttle rung **452 times in 11 h 07 m — one cycle every ~89 s — every one of them at k10temp 95–98 °C.** That satisfies the thermal guard's own written effectiveness criterion (`docs/services/thermal-pstate-guard.md` §"Post-deploy effectiveness criterion"): ≥95 °C samples persisting across a whole boot *with `deep_throttled == 1`* means the guard is **deficit-masking, not mitigating**, and "the physical cooling inspection is the only remaining fix".
2. **An IO/CPU starvation storm.** Guard zone-6 trip `#4446` (09:46:21) attributed **+1,324,574 MB of `system.slice` reads in one trip window** (1.3 TB), trip `#4447` (09:57:09) another 83 GB; the USB buildcache SSD (`sdb`, 8:16) sat at **100 % io_ticks with ~7 MB/s of writes**; a kernel `sync` was reported **waiting on writeback completion for >188 s** twice in the final minute; zram was 83 % full; **≥17 owner SSH PTYs were active in the final 30 minutes** (17 unique `pts/N` devices in the dying boot's journal) and 7 concurrent `crush -y` processes were measured at autopsy time (16 by 11:40).

Neither leg is new. What is new is the **proof of the reset mechanism** — previous reports called this family "instant EC power cut" (freezes #8–#14). The watchdog register shows the cut is the *designed last-resort WDT*, which means the box was **unschedulable, not merely hot**.

## a. Evidence

### a.1 Reset mechanism: hardware watchdog, not panic, not EC

| Probe | Result | Source |
| --- | --- | --- |
| Kernel reset reason, boot 0 | `Previous system reset reason [0x02000800]: hardware watchdog timer expired` | `journalctl -b 0 -k` |
| Same line on boots -1, -2, -4 (every retained boot) | identical `0x02000800` | `journalctl -b <n> -k` |
| pstore panic record | **none** — `systemd-pstore` skipped with `ConditionDirectoryNotEmpty=/sys/fs/pstore` unmet | `journalctl -b 0` |
| Panic/oops in the dying boot | none (the 4 "panic" hits in the evidence pull are the `nmi_watchdog=panic` / `softlockup_panic=1` **cmdline** tokens) | evidence pull census |
| Shutdown ceremony (system manager) | **none** — journal ends mid-traffic on a healthy `nsfw /readyz 200` at 10:03:11; the only `Reached target Shutdown` lines belong to *user* managers (`systemd[209501]` 09:51:33, `systemd[359915]` 09:54:45) | `journalctl -b -1` |
| wtmp | every session ends `- crash`; the only `shutdown` record in wtmp is Oct 17 12:10 | `last -x` |
| Watchdog config | `watchdogd`: 30 s timeout, 10 s pet; boot.nix documents the deliberate tradeoff vs `hung_task_timeout_secs=120` — "the WDT always wins, so hung_task_panic=1 never fires → no pstore dump" | `platforms/nixos/system/boot.nix:578-600` |

Consequence: a 30 s missed kick = the whole system (including PID 1 and watchdogd) was not scheduled for 30 s. `nmi_watchdog=panic` + `softlockup_panic=1` produce a pstore record for *per-CPU* lockups; there is none, so this was a **system-wide** starvation, not a single-core lockup.

**Rival hypothesis eliminated — watchdogd itself was healthy.** In the dying boot `watchdogd` started exactly once (22:55:47, `watchdogd v4.1`, `/dev/watchdog: SP5100 TCO timer, capabilities 0x8180 - set-timeout, safe-exit, kick`) with **zero restarts, zero errors and no stop** through 11 h of uptime (`journalctl -b -1 -u watchdogd`, `grep -c Started` = 1). A dead or wedged *daemon* would produce the same WDT fire without any system hang; that path is closed. The driver also reports the last reset cause as `0x0020 - card-reset`.

**No vmcore either:** `crashkernel=128M` + `kexec_crash_loaded=1`, yet `/var/crash` does not exist — kdump never captured anything, consistent with "no panic" (a capture creates the directory).

**What this evidence can and cannot prove.** The `0x02000800` register is read on **all six retained boots**, so it is not control-tested: on its own it could be sticky. Likewise, EFI-pstore survival across a hard reset is firmware-dependent, so "pstore empty" weakens rather than disproves a panic. The verdict rests on the **convergence** of five independent signals: healthy watchdogd + its 30 s/10 s contract + no shutdown ceremony + wtmp `crash` + no panic artifacts (pstore, vmcore, BUG/oops). That convergence is what excludes panic, OOM-freeze and an EC power cut; no single line does.

### a.2 Cut #36 — 2026-10-27 10:03:11 (boot `b803d718`, Oct 26 22:55:34 → cut, 11 h 07 m 37 s)

- **Thermal:** 452 × `DEEP THROTTLE ENTER` (60 % max-freq cap), last at **10:02:26 @ 98 °C**, 45 s before the cut; `DEEP THROTTLE DROP` (restore to full clocks, "cool band reached") **10:02:37** — 34 s before the cut. The guard's sawtooth (cap → dip below 95 °C → release → re-heat) means effective protection is intermittent.
- **IO:** guard actions `#4446` 09:46:21 — `top io since last trip: system.slice/io.stat +1324574MB, user.slice +30438MB, user.slice/user-1000.slice +23830MB`; `#4447` 09:57:09 — `system.slice +83325MB`.
- **Writeback hang:** `INFO: The task sync:606478 has been waiting for writeback completion for more than 188 seconds` at 10:02:14 and 10:02:52.
- **Memory:** zram 82–83 % full (56.0 GB / 66.7 GB) 09:59–10:01; two MEMCG OOMs earlier in the boot (08:34:02, 08:48:31, `oom_memcg=/system.slice/tq-agent-pool.service`, `task=nix`) — **none in the death window**. SEV1 latched with three conditions through the last 15 min: `MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP`.
- **Not mid-deploy:** newest deploy log is `2026-10-27_09-44-59.log`; no `nh os switch` in flight at the cut; gen-955 anchored before and after.
- **Collateral at authoring:** `/var/log/journal` at **7.9 G of 8 G** — both cuts' journals were one vacuum away from being lost.

### a.3 Cuts #34 / #35 — backfilled (first documentation)

| # | Cut | Boot window | Stack | Thermal at/near death |
| --- | --- | --- | --- | --- |
| #34 | 2026-10-25 22:22:13 | `27580a79`, Oct 25 04:33:12 → cut, 17 h 49 m | 89 zone-6 guard actions; 5 OOM invocations; last line `emeet-pixyd /metrics` | **637 × `DEEP THROTTLE ENTER`** (one per ~101 s) + 2 rung-1 ENTER; last deep ENTER 22:20:49 (81 s pre-cut) |
| #35 | 2026-10-26 22:53:58 | `ce19a826`, Oct 25 22:23:41 → cut, 24 h 30 m | 33 guard actions (31 zone-6); 27 OOM lines; 3,173 guard log lines; last line `smartd` SanDisk 194 `69→68 °C` | **343 × `DEEP THROTTLE ENTER`** + 3 rung-1 ENTER; last deep ENTER 22:45:27 (8.5 min pre-cut) |

Both terminate with the same discriminators as #36: mid-traffic journal end, no ceremony, no panic, watchdog reset reason on the following boot. Evidence: `docs/status/tasks/2026-10-27_09-24_boot-b803d718-evidence-pull.md`, `docs/status/tasks/2026-10-27_09-37_boot-ce19a826-evidence-pull.md` (boot `27580a79` already guarded by `2026-10-25_14-08_remedy-map-turn-self-review-full-status.md`).

### a.4 The thermal leg is now a measured, criterion-level failure

- #36: **452 deep-throttle cycles / 11 h**, every ENTER at 95–98 °C → the runbook's own test ("≥95 °C samples persisting across a whole boot even with `deep_throttled == 1`") is met on a whole boot, not a window.
- #34/#35: deep-throttle entries within minutes of the cut as well.
- Live at authoring (10:33–10:38): **Tctl 99.2 °C / acpitz 99.0 °C / PPT 114 W at load 72**, then 97.0 °C; `sensors` still exposes **zero fan RPM** (no fan hwmon chip) — the same smoking gun recorded on 2026-10-03.
- The cooling-inspection row (`docs/todo/stability.md:117`) is `[blocked:user]` and this adds **baits 15, 16, 17**.

### a.5 Tooling defect found while measuring (fix queued, not applied)

`scripts/boot-evidence-pull.sh` — the canonical autopsy tool — counts thermally with `bep_grep_thermal() { grep -F 'THERMAL THROTTLE' ... }`. The thermal guard emits **four** strings: `THERMAL THROTTLE ENTER|EXIT` (rung 1, enters `guided` once and stays) and `DEEP THROTTLE ENTER|DROP` (rung 2, the actual heat-load cycle). The census therefore reported **`thermal-THROTTLE-lines: 1`** for a boot that logged **452 `DEEP THROTTLE ENTER` and 452 `DEEP THROTTLE DROP`** (verified: `journalctl -b -1 | grep -c`, rung 1 = 1 ENTER / 0 EXIT). Any autopsy reader — including older freeze entries phrased "thermal minor (1 ENTER)" — would call this boot thermally quiet. It is the exact phantom-green shape this repo hunts elsewhere; the census must count rung 2 separately.

## b. What it was NOT

- **Not a panic / BUG / oops** — no lines, no pstore record, no vmcore.
- **Not a global OOM** in the death window — the last OOM is 14 h earlier (08:48), memcg-constrained.
- **Not an EC thermal power cut** — this family's resetter is the WDT (see a.1); the thermal deficit is the *enabler* (clock starvation at 95–99 °C), not the switch.
- **Not a deploy accident** — no deploy in flight, gen-955 anchored before and after (verified twice).
- **Not journal corruption** — journald was healthy to the last line and reported a clean 5.6 ms flush at the previous boot boundary.

## c. Live risk at authoring (the box is in the same regime)

- Tctl 97–99.2 °C sustained; thermal guard in `guided`, currently at full clocks (`scaling_max_freq` 5,187,500 = cpuinfo max).
- Load 141–316 (1-min) with **1,792–3,951 tasks** and 7 concurrent `crush` sessions; CPU PSI `some avg10` peaked at **98.94 %** — the same starvation shape that starves watchdogd.
- `sdb` (USB buildcache) at **100 % io_ticks, ~7 MB/s writes**; SMART 194 on the SanDisk was 68–69 °C in the #35 death minute — an SSD at that temperature under sustained writes is a second thermal problem.
- zram 8.1 GiB of 62 GiB used, MemAvailable 72 GiB (memory is not the current leg).
- **Additional finding (defect, not crime):** `monitor365` (uid 966) spawns `dmesg` every 60 s; the unit's empty `CapabilityBoundingSet` + seccomp denies `klogctl` (syscall 103) → `signal 31/SYS` → a **31 KB coredump every minute** (`/var/lib/systemd/coredump`), ~44 MB/day of churn plus journal noise. It also masks real `dmesg`-related signals in every autopsy.

## d. Actions taken this session

1. Pulled evidence for **both** unguarded boots before the vacuum: `b803d718` and `ce19a826` (`scripts/boot-evidence-pull.sh`); journal was at 7.8–7.9 G / 8 G. `scripts/pre-vacuum-evidence-gate.sh` → **pass** (one remaining "unpulled but unreferenced" warning is now resolved by the `ce19a826` pull).
2. Verified the deploy anchor after the hard cut: `current-system == system-955-link` — no repair needed.
3. Classified the crash from five independent discriminators (reset register, pstore, wtmp, ceremony absence, watchdog config) instead of assuming the family's older "EC cut" phrasing.
4. Documented freezes #34/#35/#36 (`docs/agents/stability.md`), extended the cooling row with baits 15–17 and the deficit-masking verdict, extended the shed-load row with the 452-cycle measurement, and queued the monitor365 `dmesg` loop.

## e. Doctrine deltas

- **"Instant cut, no ceremony" is not the same as "EC power cut".** Read the next boot's `Previous system reset reason` before naming the mechanism: `0x02000800` = hardware watchdog → the box hung; a true EC/PSU cut leaves a different (or no) reason and usually a shorter POST gap. Future autopsies cite the register.
- **The thermal guard's effectiveness criterion is a boot-level test, not a spot check.** #36 is the first boot that *fails* it cleanly (452 cycles, all ≥95 °C). Treat `thermal_pstate_guard_deep_trips_total` per boot as the deficit metric — a five-digit counter delta in one boot is the physical-fix alarm, not a tuning knob.
- **A watchdog reset is evidence of starvation *duration* (≥30 s unscheduled), not of a single culprit.** Screen-starvation and IO-starvation both starve PID 1; both were present.

## f. Follow-ups (harvested)

1. **`[blocked:user]` cooling inspection** — baits 15–17 appended to `docs/todo/stability.md:117`; criterion-level deficit proven; no heavy builds/flake checks until inspected (this session deliberately ran NO `nix build` / `nix flake check`).
2. **`[ready]` shed-load escalation rung** — evidence extended on `docs/todo/stability.md:238`: cap-to-60 % cycles 452×/boot, so the third rung must *remove load*, not merely lower clocks.
3. **Deep-cap release hysteresis** — folded into the **`[ready]`** restore-hysteresis row (`docs/todo/stability.md:239`, implementation is agent-actionable; only the deploy stays gated on the cooling window): `DEEP THROTTLE DROP` fires at the **middle** band (below 95 °C), producing a re-heat sawtooth every ~89 s; release should require the low band (80 °C) or a hold window. Both rungs need the same fix.
4. **`[ready]` monitor365 `dmesg` SIGSYS loop** — new row in `docs/todo/services.md` (§ after the monitor365-server wedge row): decide drop-the-collector vs `CAP_SYSLOG` + `syslog(2)` + `dmesg_restrict=0`; today it burns a coredump a minute.
5. **`[decision]` interactive-load admission** — NOT minted: already carried by the build-battery admission row (`docs/todo/stability.md:135`) and the `[decision]` session-gating row; this cut adds one more datapoint (≥17 SSH PTYs in the death window, 7→16 concurrent `crush -y` across the session).
6. **`[watch]` USB buildcache SSD** — new row in `docs/todo/storage.md`: 100 % busy at 7 MB/s and 68–69 °C SMART in the death minute; route builds to the Samsung `tlc` scratch or cap concurrent builders on `sdb`.
