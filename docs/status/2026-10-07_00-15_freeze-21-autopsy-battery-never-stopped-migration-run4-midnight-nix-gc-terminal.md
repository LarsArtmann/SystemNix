# Freeze #21 Autopsy — the Battery that Never Stopped, Migration Run #4, and the Midnight nix-gc as Terminal Trigger (2026-10-07)

**Session:** 2026-10-07 00:04 → ~00:20 — trigger: user "Why did we crashed this time? DEEP RESEARCH + root cause report". Read-only forensics (journal boot -1 + guard state + live cgroup/PSI probes); NO live process stops (drivers are interactive build sessions — freeze-20 §c.1 policy held). Autopsy of the 00:00:59 cut (#21 = boot -1, 21:52:21 → 00:00:59, 2 h 08 m 38 s) + live review of boot 0.

**Sibling context:** freeze #20 autopsy (`22-18` — its §Live regime closed with "Freeze #21 will form if the build battery continues stacking"; the battery continued for 2 h 08 m), freeze #19 autopsy (`21-25` — the migration class), rust-cache-ssd-split (`20-18`), boot-speed research still UNDEPLOYED. **SEVENTH consecutive cut predicted by its predecessor's autopsy with zero owner-leg execution between** (#14→#15→#16/17→#18→#19→#20→#21).

## Verdict

**Freeze #21 = three stacked layers, one of them NEW:**

1. **CHRONIC — the freeze-20-predicted build battery ran the ENTIRE boot.** Guard Zone 6 (IO PSI) tripped **13 consecutive times, #2112 (21:54:50, 2.5 min after boot) → #2124 (23:56:57)**, the ~10-min cadence never broke once in 2 h 08 m. The boot never had a single clean guard window. Top-IO attribution the whole way: `nix-daemon` +9–15 GB per 10-min window, system.slice up to +30.7 GB/window (the freeze-20 §Evidence-13 battery: go test/vet, cargo/duckdb, go mod tidy, buildflow, LSP indexing).
2. **PROXIMATE — rust-cache migration run #4 launched at 23:30:38** (4th un-gated launch of `migrate-rust-cache.sh`; the entry-gate row was queued at 21:25 by the freeze-19 autopsy and STILL does not exist as code). sudo journal: mount of the SanDisk sdc1 btrfs at `/mnt/rust-cache` + `mkdir sccache cargo rust` + chown, from `PWD=/home/lars/projects/SystemNix` (session-14.scope). `session-14` then did **+32.4 GB and +35.4 GB in the two following 10-min windows** (trips #2122/#2123) while sdc device-unallocated drained 201.4 → 189.6 GB (≈10 MB/s sustained writes). **The read side is the collision: `SOURCES="/mnt/buildcache"` (scripts/migrate-rust-cache.sh:28) — sdb ext4 is the SAME USB disk the build battery reads its go/cargo caches from.** One USB disk served rsync full-speed reads AND build-cache reads simultaneously.
3. **TERMINAL — the SCHEDULED midnight nix-gc fired at 00:00:00 exactly** (`nix.gc.dates = "daily"` → OnCalendar=daily = 00:00:00, platforms/common/nix-settings.nix:53-56,64). Its ExecStartPre `btrfsGcGuard` PASSED — the gate is **space-only** (5 GiB unallocated floor + metadata >90 % block; btrfs-health.nix:693-706): device-unallocated 4 % (35.8 GB), metadata 70 %. **Zero IO-pressure awareness.** The GC then removed profile generations 801/800 and logged **9,463 store-path deletions in 59 seconds** (btrfs unlink + delayed-ref metadata churn on a 96 %-full QLC root) while IO PSI had sat at zone-6 trip levels for 2+ hours. SEV1 notify fired 00:00:54; journal cut mid-deletion 00:00:59.

Death discriminators: hard cut, no ceremony (last lines are `nix-gc-start: deleting …` + a cv health log; no shutdown/Stopping sequence; a truncated `*.journal~` on read); kernel-clean (0 OOM, 0 real MCE — only the boot-time "MCE decoding enabled" line, 0 BTRFS errors); `/var/crash` empty (livelock class produces no kdump); NOT mid-deploy (0 switch-to-configuration lines in the death window); guard counter continuity held 6th consecutive cut (#2124 → #2125). Thermal participation MINOR: exactly one ENTER (21:54:50, k10temp 97 °C → amd_pstate guided, same second as trip #2112), no EXIT logged — vs #19's four ENTER windows; the chronic cooling deficit was an early amplifier, not the killer.

**The structural headline: nothing on this box refuses heavy work while the guard is tripped.** Interactive builds (battery), maintenance scripts (migration), and now a SCHEDULED SYSTEM JOB (nix-gc) all entered freely into a box that had been at IO-trip levels for hours. The GC is the first cut where the terminal trigger was the system's own midnight automation — it does not even have an owner to warn.

## Evidence

| # | Finding | Evidence |
|---|---------|----------|
| 1 | #21 hard cut, no ceremony | boot -1 (21:52:21 → 00:00:59, 2 h 08 m 38 s) ends mid-activity (`nix-gc-start: deleting '/nix/store/…-windows-strings-0.5.1'`, cv health 200 OK at 00:00:59); no shutdown/Stopping lines; boot 0 starts 00:02:52; journal read warns `system@00065cc9…journal~ is truncated, ignoring file` |
| 2 | Whole-boot zone-6 storm — 13 consecutive trips | trips #2112 (21:54:50) → #2124 (23:56:57), ~600 s cadence, all "zone 6"; top-io windows 22:04–23:26: system.slice +13.4–30.7 GB, nix-daemon +9.6–15.4 GB per window |
| 3 | First trip 2.5 min into boot + thermal ENTER same second | #2112 at 21:54:50; `thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided … k10temp=97C` 21:54:50; zero further ENTER lines in the boot |
| 4 | Migration run #4 at 23:30:38 | sudo[3418651/54/10/13]: `mkdir -p /mnt/rust-cache` + `mount -o noatime,compress=zstd:1 … ata-SanDisk_SDSSDA240G_174244451713-part1 /mnt/rust-cache` + `mkdir … sccache cargo rust` + chown lars — PWD=/home/lars/projects/SystemNix; kernel: `BTRFS: device label rust-cache … scanned by mount`; storage-collector: sdc1 added 23:31:34 at 19.5/240 GB (8 %) |
| 5 | Migration IO quantified | trips #2122 (23:36:47) / #2123 (23:46:52): `session-14.scope +32411 MB` / `+35397 MB` per 10-min window; sdc device-unallocated 201.38 GB (23:41) → 189.57 GB (00:00) ≈ 10 MB/s sustained writes, metadata % climbing 19→23 % |
| 6 | Read-side collision by construction | `SOURCES="/mnt/buildcache"` + `rsync -a --delete "$src/" "$dst/"` (scripts/migrate-rust-cache.sh:28,92); /mnt/buildcache = /dev/sdb1 ext4 (live /proc/mounts) = the battery's go/cargo cache disk — USB-to-USB rsync over one shared source disk |
| 7 | TERMINAL: midnight GC onset→cut = 59 s | `Starting Nix Garbage Collector...` 00:00:00; `removing profile version 801/800`; `finding garbage collector roots...`; 9,463 `deleting` lines 00:00:00→00:00:59; last journal line 00:00:59 mid-deletion |
| 8 | GC admission = space-only, passed while storming | `btrfs-gc-guard: OK — device-unallocated=4% (35815161856 bytes) metadata=70%` at 00:00:00; guard code = 5 GiB unalloc floor + metadata >90 % block only (btrfs-health.nix:693-706); dates="daily" = OnCalendar 00:00:00 (platforms/common/nix-settings.nix:53-64) |
| 9 | Kernel-clean, no vmcore, not mid-deploy | boot -1 kernel: 0 OOM-kill, 0 MCE (beyond boot-line), 0 BTRFS errors, 0 I/O error; /var/crash absent; 0 switch-to-configuration/activating lines 23:50→00:01 |
| 10 | Guard continuity + blindness | #2124 (23:56:57) → #2125 (boot 0, 00:07:06) — counter intact; all 13 trips acted only on `ioChurnUnits` (flm/btrbk/churn) — rsync, nix-daemon, go-licenses/govulncheck/vulnix, nix-gc all invisible (freeze-6/#20 structural gap, 13 trips changed nothing) |
| 11 | SEV1 fired 5 s pre-cut | `sev1-bridge-check: SEV1 active (1 condition(s), severity=notify): MEMORY EMERGENCY GUARD TRIPPED` 00:00:54 (notify tier — policy held) |
| 12 | Crash-loop amplifier: interrupted GC re-fired into recovery boot | boot 0: nix-gc 00:03:35→00:09:05 (5 m 30 s wall, 1 m 53 s CPU, **9 GB read + 2.5 GB written**, 3.1 GB peak RSS) — guard trip #2125 (00:07:06) landed INSIDE the GC window |
| 13 | Root fs standing risk | QLC root at 4 % device-unallocated (35.8 GB) / metadata 70 % at GC time — passes the space gate but leaves near-zero btrfs slack for mass-unlink metadata churn |

## Live regime at authoring (boot 0, 00:10–00:15)

- **Freeze #22 formed partway and is decaying — watch it.** At 00:10:35: IO PSI some avg10 **71.73** / avg60 74.97, **full avg10 61.91 / avg60 67.35** (full-stall territory — worse than #20's death signature of full avg10 0.22), loadavg 7.5→12.2 rising; by 00:14:03: some avg10 48.30 / full avg10 24.75, loadavg **61.66** (1-min, decaying spike; instantaneous R=3, D=2 kworkers `flush-btrfs-1`/`events_unbound` = GC writeback), battery procs exiting.
- Drivers of the spike: ANOTHER build battery — 4× `go-licenses report ./...` (150–183 % CPU each), 2× `nix run nixpkgs#govulncheck` + govulncheck, `vulnix` in D-state on /home/lars/projects/browser-history, `nix fmt .`, 2× `go generate ./...`, 8+ crush sessions — the BuildFlow pre-commit/build leg class again (freeze-15/18/20 battery, violation #6 of the written no-heavy-builds gate).
- **Migration did NOT re-fire on boot 0** (no `/mnt/rust-cache` in /proc/mounts — sdc unmounted; converge-on-rerun holds).
- No containment executed (interactive-session policy, freeze-20 §c.1): if IO PSI some avg10 re-crosses ~80 % with the battery rebuilding, the calculus changes.

## a) FULLY DONE

1. Full #21 autopsy with all portable discriminators answered (Evidence table): hard cut, kernel-clean, not-mid-deploy, counter continuity, livelock class, thermal participation quantified (1 ENTER) rather than assumed.
2. Named the terminal trigger to the second (GC onset 00:00:00 → cut 00:00:59) and quantified its burst (9,463 deletions; 9 GB read/2.5 GB written proven by the boot-0 completed run of the same job).
3. Identified migration run #4 with its exact launch evidence (sudo mount lines, PWD, session scope) and quantified its IO (32–35 GB/window, 10 MB/s sustained to sdc, 201→189 GB unallocated).
4. Named the read-side collision (sdb serving both rsync source reads and the battery's build caches) from the script source + live mounts — mechanism, not trend.
5. Verified the GC admission-gap claim against the code (btrfs-health.nix:693-706 space-only) before queueing the fix row.
6. Live boot-0 review with two PSI probes 3.5 min apart (spike + decay) and D-state attribution.
7. TODO harvest at authoring: 2 rows extended, 1 new row routed (§f), both surfaces (queue + stability library).

## b) NOTICED, NOT DIAGNOSED

1. WHO launched migration run #4 at 23:30:38 from session-14 (PWD=/home/lars/projects/SystemNix) — owner vs. agent is owner-only knowledge (§g.1); 4th launch, 2 h after run #3 killed the box.
2. The exact composition of the 22:00–23:30 battery windows (nix-daemon +9–15 GB/window) — attributed to the freeze-20 §Evidence-13 driver set by continuity, not re-derived per-process (pids gone with the boot).
3. sdb's own saturation telemetry during 23:30–00:00 (wbt throttle/blk_mq_get_tag counts) — the #19/#20 choke signature was not re-probed live; inferred from class + PSI.
4. Whether the GC would have been terminal WITHOUT the migration (box survived 2 h of battery + 26 min of battery+migration overlap; counterfactual unprovable in a livelock).

## c) DELIBERATELY NOT DONE

1. No live SIGSTOPs on boot 0 — drivers are interactive builds owned by active terminals (freeze-20 §c.1 policy: wedged build locks exceed the value while the spike decays; re-evaluate at some avg10 ≥ ~80 %).
2. No deploy, no module edits mid-storm (the freeze-#4/#5 death recipe; also the very rule the new rows would encode).
3. No whole-journal export of the 9,463 deleted paths — the count suffices for the verdict; the full list is in the boot -1 journal on demand.
4. No `[blocked:user]` cooling-row bump — one ENTER vs #19's four windows; would dilute the row's signal.

## d) SELF-CRITICISM

1. Two whole-boot `journalctl -b -1 | grep` pipes ran during a live tripped boot — freeze-20 §d.2's exact lesson, repeated within one day (mitigated: the rest were windowed; the discipline must be absolute).
2. The session-14 grep first matched sessions 140-144 (`session-14` prefix) and could have mis-attributed — fixed by anchor `\.` re-grep; assert the mechanism includes the EXACT scope name.
3. Initial live read at 00:10 said "load 7-12, battery running"; the 00:14 probe caught loadavg 61 — the spike would have been under-reported had I stopped at one probe. Two probes minimum while a recovery boot is inside its first 15 min.

## e) WHAT WE SHOULD IMPROVE

1. **Scheduled midnight jobs need the SAME admission gate as everything else — this is the new cut class.** `nix-gc` (and its siblings `nix-build-cleanup`, balance timers — all midnight-family, btrfs-health.nix) pass a space-only guard while IO PSI sits at trip levels for hours. A skipped GC night is free; the gate should abort/reschedule on "zone-6 trip within last N minutes OR PSI some avg10 ≥ threshold". The GC has no owner to warn — only a gate can stop it.
2. **The migrate-* entry gate is now 4 launches and 3 crashed boxes old** (#19, #20, #21 all migration-present; runs #1/#2 → #19, #3 → #20, #4 → #21). A queue row cannot contain a live crash loop — the gate must EXIST before the next `nix run .#migrate-*` invocation; treat every migrate-* script as ARMED until then.
3. **The no-heavy-builds enforcement leg (row 96) is the highest-leverage unresolved row in the repo**: the battery class has now killed #15(?), #18, #20, #21 and recurred on this boot 0 (go-licenses/govulncheck/vulnix, violation #6). Mirror deploy.sh's zone6_recent gate onto `nix build/flake check` + buildflow entry.
4. **Interrupted-GC refire into recovery boots is a named crash-loop amplifier** (Evidence 12): the daily timer re-ran the GC into a tripped boot 43 s after login-greet. The IO-admission gate (e.1) covers this too — same fix, two surfaces.
5. Root QLC at 4 % unallocated passed the space gate — the 5 GiB floor is about to become the常态 normal case; schedule reclaim or raise the floor's semantics (percent-based) before it does.

## f) NEXT THINGS (self-harvested at authoring; routed per TODO rules)

1. **[ready] IO-pressure admission gate for midnight maintenance jobs (nix-gc / nix-build-cleanup / balance timers)** — NEW row (queue + stability library). **Source:** this report §e.1/§e.4, Evidence 7/8/12.
2. **[ready] Entry gate + serialization for migrate-* maintenance scripts** — standing row EXTENDED with run #4/#21 (fourth launch, terminal-window overlap with battery+GC). **Source:** this report §e.2, Evidence 4-6.
3. **[ready] No-heavy-builds gate enforcement leg** — standing row EXTENDED with #21 + boot-0 violation #6 (go-licenses/govulncheck/vulnix battery at trip #2125). **Source:** this report §e.3, Live regime.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Who launched migration run #4 at 23:30:38 from session-14** (PWD=/home/lars/projects/SystemNix)? Fourth launch of a script whose two previous launches each killed the box the same day — owner discipline vs. agent guardrail determines the fix's shape (same question open from freeze-20 §g.1 for run #3/session-62).
2. **Who owns the boot-0 browser-history battery** (go-licenses/govulncheck/vulnix/nix fmt)? It drove IO PSI full avg10 to 62 % at 00:10 while the re-fired GC ran — the freeze-22 recipe. Ctrl-C now or confirm it finished.
3. Still open from freeze-20: the calm-window deploy of the boot-speed restructure (gen 828 carries the hermes boot-scan amplifier).

**Standing state at report close:** freeze #21 autopsied (IO-livelock class; chronic = whole-boot build battery at 13 consecutive zone-6 trips; proximate = migration run #4 with sdb read-side collision; terminal = scheduled midnight nix-gc, 59 s from onset to cut, 9,463-path deletion burst on a 96 %-full QLC root; thermal minor, 1 ENTER); guard counter continuity intact (#2124→#2125); crash-loop amplifier observed live (interrupted GC re-fired into recovery boot, trip #2125 inside its window); boot 0 spiked (loadavg 61.66, IO PSI full avg10 61.9) on a second build battery + re-fired GC and was decaying at 00:14; migration NOT re-fired (sdc unmounted); entry-gate and no-heavy-builds rows remain UNIMPLEMENTED as code — the seventh consecutive predecessor-predicted cut.

_Arte in Aeternum_
